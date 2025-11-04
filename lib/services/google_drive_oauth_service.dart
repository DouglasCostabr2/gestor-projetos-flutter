import 'dart:async';
import 'dart:convert' as convert;
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:googleapis_auth/auth_io.dart' as auth;
import 'package:http/http.dart' as http;
import 'package:mime/mime.dart' as mime;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/google_oauth_config.dart';
import '../modules/modules.dart';
import '../modules/common/organization_context.dart';

/// Stores and retrieves OAuth tokens tied to current user using Supabase
class OAuthTokenStore {
  static SupabaseClient get _client => Supabase.instance.client;

  static Future<void> upsertToken({
    required String provider, // 'google'
    required String refreshToken,
    String? accessToken,
    DateTime? expiry,
  }) async {
    final user = authModule.currentUser;
    if (user == null) throw Exception('Usuário não autenticado');
    final payload = {
      'user_id': user.id,
      'provider': provider,
      'refresh_token': refreshToken,
      if (accessToken != null) 'access_token': accessToken,
      if (expiry != null) 'access_token_expiry': expiry.toUtc().toIso8601String(),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };

    try {
      debugPrint('GDrive OAuth: salvando token via upsert onConflict=user_id');
      await _client.from('user_oauth_tokens').upsert(payload, onConflict: 'user_id');
    } catch (e) {
      debugPrint('GDrive OAuth: upsert falhou ($e). Tentando update/insert...');
      // Fallback: update, se 0 linhas afetadas -> insert
      try {
        final updated = await _client
            .from('user_oauth_tokens')
            .update(payload)
            .eq('user_id', user.id);
        // Se updated é uma lista vazia, fazemos insert
        if (updated is List && updated.isEmpty) {
          await _client.from('user_oauth_tokens').insert(payload);
        }
      } catch (e2) {
        debugPrint('GDrive OAuth: update/insert também falhou: $e2');
        rethrow;
      }
    }
  }

  static Future<Map<String, dynamic>?> getToken(String provider) async {
    debugPrint('🔍 GDrive OAuth: buscando token pessoal para provider=$provider');
    final user = authModule.currentUser;
    if (user == null) {
      debugPrint('⚠️ GDrive OAuth: usuário não autenticado, não pode buscar token pessoal');
      return null;
    }
    try {
      final res = await _client
          .from('user_oauth_tokens')
          .select('*')
          .eq('user_id', user.id)
          .eq('provider', provider)
          .maybeSingle();
      debugPrint('✅ GDrive OAuth: token pessoal encontrado: ${res != null ? "SIM" : "NÃO"}');
      if (res != null) {
        debugPrint('   - has refresh_token: ${res['refresh_token'] != null}');
        debugPrint('   - has access_token: ${res['access_token'] != null}');
      }
      return res;
    } catch (e) {
      debugPrint('❌ GDrive OAuth: erro ao buscar token pessoal: $e');
      return null;
    }
  }

  /// Salva token compartilhado por organização
  /// Apenas admin/gestor podem salvar
  static Future<void> upsertSharedToken({
    required String provider,
    required String organizationId,
    required String refreshToken,
    String? accessToken,
    DateTime? expiry,
  }) async {
    final user = authModule.currentUser;
    if (user == null) throw Exception('Usuário não autenticado');

    final payload = {
      'provider': provider,
      'organization_id': organizationId,
      'refresh_token': refreshToken,
      if (accessToken != null) 'access_token': accessToken,
      if (expiry != null) 'access_token_expiry': expiry.toUtc().toIso8601String(),
      'connected_by': user.id,
      'connected_at': DateTime.now().toUtc().toIso8601String(),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };

    try {
      debugPrint('GDrive OAuth: salvando token compartilhado para org=$organizationId via upsert');
      await _client.from('shared_oauth_tokens').upsert(payload, onConflict: 'provider,organization_id');
    } catch (e) {
      debugPrint('GDrive OAuth: falha ao salvar token compartilhado: $e');
      rethrow;
    }
  }

  /// Busca token compartilhado da organização
  static Future<Map<String, dynamic>?> getSharedToken(String provider, String organizationId) async {
    try {
      debugPrint('🔍 GDrive OAuth: buscando token compartilhado para provider=$provider, org=$organizationId');
      final res = await _client
          .from('shared_oauth_tokens')
          .select('*')
          .eq('provider', provider)
          .eq('organization_id', organizationId)
          .maybeSingle();
      debugPrint('✅ GDrive OAuth: token compartilhado encontrado: ${res != null ? "SIM" : "NÃO"}');
      if (res != null) {
        debugPrint('   - has refresh_token: ${res['refresh_token'] != null}');
        debugPrint('   - has access_token: ${res['access_token'] != null}');
        debugPrint('   - connected_by: ${res['connected_by']}');
      }
      return res;
    } catch (e) {
      debugPrint('❌ GDrive OAuth: erro ao buscar token compartilhado: $e');
      return null;
    }
  }

  /// Verifica se existe token compartilhado para a organização
  static Future<bool> hasSharedToken(String provider, String organizationId) async {
    final token = await getSharedToken(provider, organizationId);
    return token != null && token['refresh_token'] != null;
  }

  /// Remove token compartilhado da organização (apenas admin/gestor)
  static Future<void> removeSharedToken(String provider, String organizationId) async {
    try {
      debugPrint('GDrive OAuth: removendo token compartilhado para org=$organizationId');
      await _client
          .from('shared_oauth_tokens')
          .delete()
          .eq('provider', provider)
          .eq('organization_id', organizationId);
    } catch (e) {
      debugPrint('GDrive OAuth: erro ao remover token compartilhado: $e');
      rethrow;
    }
  }
}

/// Public signal to indicate user consent is required
class ConsentRequired implements Exception {
  final String message;
  ConsentRequired([this.message = 'Consentimento necessário']);
  @override
  String toString() => message;
}

/// Google Drive OAuth + operations (folders, upload, delete)
class GoogleDriveOAuthService {
  GoogleDriveOAuthService();

  final auth.ClientId _clientId = auth.ClientId(
    GoogleOAuthConfig.clientId,
    GoogleOAuthConfig.clientSecret,
  );

  Uri? lastAuthUrl; // exposto para UI, se precisar exibir manualmente

  /// Returns an authenticated client if a refresh token is stored; otherwise throws [ConsentRequired]
  ///
  /// Uso:
  /// - Somente token compartilhado por organização (shared_oauth_tokens)
  /// - Sem fallback para token pessoal
  Future<auth.AuthClient> getAuthedClient() async {
    debugPrint('🔐🔐🔐 GDrive OAuth: getAuthedClient() chamado');

    // Obter organization_id do contexto
    final organizationId = OrganizationContext.currentOrganizationId;

    if (organizationId != null) {
      // 1. Tentar token compartilhado da organização primeiro
      debugPrint('🔍🔍🔍 GDrive OAuth: verificando token compartilhado para org=$organizationId...');
      final sharedToken = await OAuthTokenStore.getSharedToken('google', organizationId);
      debugPrint('🔍🔍🔍 GDrive OAuth: sharedToken obtido: ${sharedToken != null}');
      if (sharedToken != null && sharedToken['refresh_token'] != null) {
        debugPrint('✅✅✅ GDrive OAuth: usando token compartilhado da organização');
        final refreshToken = sharedToken['refresh_token'] as String;
        final creds = auth.AccessCredentials(
          auth.AccessToken('Bearer', sharedToken['access_token'] ?? '', DateTime.now().toUtc().subtract(const Duration(minutes: 1))),
          refreshToken,
          GoogleOAuthConfig.scopes,
        );

        final base = http.Client();
        try {
          debugPrint('🔄🔄🔄 GDrive OAuth: renovando token compartilhado...');
          final refreshed = await auth.refreshCredentials(_clientId, creds, base);
          debugPrint('🔄🔄🔄 GDrive OAuth: token renovado, atualizando no DB...');
          // Atualizar token compartilhado
          await OAuthTokenStore.upsertSharedToken(
            provider: 'google',
            organizationId: organizationId,
            refreshToken: refreshToken,
            accessToken: refreshed.accessToken.data,
            expiry: refreshed.accessToken.expiry,
          );
          debugPrint('✅✅✅ GDrive OAuth: token compartilhado renovado com sucesso');
          return auth.authenticatedClient(base, refreshed);
        } catch (e) {
          base.close();
          debugPrint('❌❌❌ GDrive OAuth: falha ao renovar token compartilhado: $e');
          throw ConsentRequired();
        }
      } else {
        debugPrint('⚠️⚠️⚠️ GDrive OAuth: nenhum token compartilhado encontrado para a organização');
      }
    } else {
      debugPrint('⚠️⚠️⚠️ GDrive OAuth: nenhuma organização ativa no contexto');
      throw ConsentRequired();
    }



    debugPrint('GDrive OAuth: nenhum token armazenado, solicitando consentimento');
    throw ConsentRequired();
  }

  /// Loopback consent: abre navegador e fica escutando localhost; se falhar abre manualmente
  ///
  /// [saveAsShared] - Sempre true (somente token compartilhado por organização)
  /// [organizationId] - ID da organização (obrigatório)
  Future<auth.AuthClient> connectWithLoopback({
    void Function(Uri url, bool opened)? onAuthUrl,
    bool saveAsShared = false,
    String? organizationId,
  }) async {
    if (GoogleOAuthConfig.clientId.isEmpty || GoogleOAuthConfig.clientSecret.isEmpty) {
      throw Exception('Client ID/Secret não configurados (--dart-define)');
    }

    if (saveAsShared && organizationId == null) {
      throw Exception('organization_id é obrigatório quando saveAsShared=true');
    }
    if (!saveAsShared) {
      throw Exception('Somente conta compartilhada é suportada neste aplicativo (por organização).');
    }

    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final redirectUri = Uri.parse('http://127.0.0.1:${server.port}/oauth2redirect');
    debugPrint('GDrive OAuth: loopback iniciado em $redirectUri');

    final authParams = {
      'client_id': _clientId.identifier,
      'response_type': 'code',
      'redirect_uri': redirectUri.toString(),
      'scope': GoogleOAuthConfig.scopes.join(' '),
      'access_type': 'offline',
      'prompt': 'consent',
    };
    final authUrl = Uri(
      scheme: 'https',
      host: 'accounts.google.com',
      path: '/o/oauth2/v2/auth',
      queryParameters: authParams,
    );
    lastAuthUrl = authUrl;

    // Open browser (tentativa com fallback)
    var opened = await launchUrl(authUrl, mode: LaunchMode.externalApplication);
    onAuthUrl?.call(authUrl, opened);
    if (!opened) {
      opened = await launchUrl(authUrl, mode: LaunchMode.platformDefault);
      onAuthUrl?.call(authUrl, opened);
    }
    if (!opened) {
      debugPrint('GDrive OAuth: falha ao abrir navegador; URL: $authUrl');
      // Prosseguimos mesmo assim; o usuário pode copiar/colar manualmente a URL.
    } else {
      debugPrint('GDrive OAuth: navegador aberto em $authUrl');
    }

    String? authCode;
    String? authError;

    try {
      await for (final req in server) {
        final qp = req.uri.queryParameters;
        authCode = qp['code'];
        authError = qp['error'];
        debugPrint('GDrive OAuth: resposta recebida. code=${authCode != null}, error=$authError');
        // Respond to browser
        req.response.statusCode = 200;
        req.response.headers.set('Content-Type', 'text/html; charset=utf-8');
        req.response.write('<html><body><h3>Autorização recebida. Você pode fechar esta janela.</h3></body></html>');
        await req.response.close();
        break;
      }
    } finally {
      await server.close(force: true);
      debugPrint('GDrive OAuth: loopback encerrado');
    }

    if (authError != null) {
      throw Exception('Autorização negada: $authError');
    }
    if (authCode == null) {
      throw Exception('Nenhum código de autorização recebido');
    }

    // Exchange code for tokens
    final tokenRes = await http.post(
      Uri.parse('https://oauth2.googleapis.com/token'),
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: {
        'code': authCode,
        'client_id': _clientId.identifier,
        'client_secret': _clientId.secret ?? '',
        'redirect_uri': redirectUri.toString(),
        'grant_type': 'authorization_code',
      },
    );
    debugPrint('GDrive OAuth: token exchange status=${tokenRes.statusCode}');

    if (tokenRes.statusCode != 200) {
      throw Exception('Falha ao trocar código por tokens: ${tokenRes.statusCode} ${tokenRes.body}');
    }

    final data = tokenRes.body;
    final map = convert.jsonDecode(data) as Map<String, dynamic>;
    final accessToken = map['access_token'] as String;
    final expiresIn = (map['expires_in'] as num?)?.toInt() ?? 3600;
    final refreshToken = (map['refresh_token'] as String?) ?? '';
    debugPrint('GDrive OAuth: recebeu refreshToken=${refreshToken.isNotEmpty}');

    final creds = auth.AccessCredentials(
      auth.AccessToken('Bearer', accessToken, DateTime.now().toUtc().add(Duration(seconds: expiresIn))),
      refreshToken.isEmpty ? null : refreshToken,
      GoogleOAuthConfig.scopes,
    );

    // Salvar token (compartilhado ou pessoal)
    if (saveAsShared) {
      await OAuthTokenStore.upsertSharedToken(
        provider: 'google',
        organizationId: organizationId!,
        refreshToken: refreshToken,
        accessToken: creds.accessToken.data,
        expiry: creds.accessToken.expiry,
      );
      debugPrint('GDrive OAuth: token compartilhado salvo no Supabase para org=$organizationId');
    } else {
      throw Exception('Somente conta compartilhada é suportada neste aplicativo (por organização).');
    }

    final base = http.Client();
    return auth.authenticatedClient(base, creds);
  }

  /// Returns the connected account email (requires userinfo.email scope)
  Future<String?> getConnectedEmail() async {
    try {
      final client = await getAuthedClient();
      final resp = await client.get(Uri.parse('https://www.googleapis.com/oauth2/v2/userinfo?fields=email'));
      if (resp.statusCode == 200) {
        final m = convert.jsonDecode(resp.body) as Map<String, dynamic>;
        return m['email'] as String?;
      }
    } catch (e) {
      debugPrint('GDrive OAuth: falha ao obter email do usuário: $e');
    }
    return null;
  }

  Future<drive.DriveApi> _drive(auth.AuthClient client) async => drive.DriveApi(client);

  Future<String> _findOrCreateFolder(drive.DriveApi api, String name, {String? parentId}) async {
    final q = [
      "mimeType = 'application/vnd.google-apps.folder'",
      "name = '${_escape(name)}'",
      if (parentId != null) "'${_escape(parentId)}' in parents",
      'trashed = false',
    ].join(' and ');
    final res = await api.files.list(q: q, $fields: 'files(id,name)');
    if (res.files != null && res.files!.isNotEmpty) return res.files!.first.id!;

    final folder = drive.File()
      ..name = name
      ..mimeType = 'application/vnd.google-apps.folder'
      ..parents = parentId != null ? [parentId] : null;
    final created = await api.files.create(folder, $fields: 'id');
    return created.id!;
  }

  String _escape(String s) => s.replaceAll("'", "\\'");

  /// Helper para obter o nome da organização atual
  /// Se organizationName for fornecido, usa ele. Caso contrário, obtém do contexto.
  String _getOrganizationName(String? organizationName) {
    if (organizationName != null && organizationName.isNotEmpty) {
      return organizationName;
    }
    final orgName = OrganizationContext.currentOrganization?['name'] as String?;
    if (orgName == null || orgName.isEmpty) {
      throw Exception('Nenhuma organização ativa. Conecte-se a uma organização primeiro.');
    }
    return orgName;
  }

  Future<String> ensureRootFolder(auth.AuthClient client) async {
    final api = await _drive(client);
    return _findOrCreateFolder(api, 'Gestor de Projetos');
  }

  /// Cria estrutura: Gestor de Projetos/Organizações/
  Future<String> ensureOrganizationsFolder(auth.AuthClient client) async {
    final api = await _drive(client);
    final rootId = await ensureRootFolder(client);
    return _findOrCreateFolder(api, 'Organizações', parentId: rootId);
  }

  /// Cria estrutura: Gestor de Projetos/Organizações/{organizationName}/
  Future<String> ensureOrganizationFolder(auth.AuthClient client, String organizationName) async {
    final api = await _drive(client);
    final organizationsId = await ensureOrganizationsFolder(client);
    return _findOrCreateFolder(api, _sanitize(organizationName), parentId: organizationsId);
  }

  /// Cria estrutura: Gestor de Projetos/Organizações/{organizationName}/Clientes/
  Future<String> ensureClientsFolder(auth.AuthClient client, {String? organizationName}) async {
    final orgName = _getOrganizationName(organizationName);
    final api = await _drive(client);
    final orgId = await ensureOrganizationFolder(client, orgName);
    return _findOrCreateFolder(api, 'Clientes', parentId: orgId);
  }

  /// Cria estrutura: Gestor de Projetos/Organizações/{organizationName}/Clientes/{clientName}/
  Future<String> ensureClientFolder(auth.AuthClient client, String clientName, {String? organizationName}) async {
    final orgName = _getOrganizationName(organizationName);
    final api = await _drive(client);
    final clientsId = await ensureClientsFolder(client, organizationName: orgName);
    return _findOrCreateFolder(api, _sanitize(clientName), parentId: clientsId);
  }

  /// Cria estrutura: Gestor de Projetos/Organizações/{organizationName}/Clientes/{clientName}/{companyName}/
  Future<String> ensureCompanyFolder(auth.AuthClient client, String clientName, String companyName, {String? organizationName}) async {
    final orgName = _getOrganizationName(organizationName);
    final api = await _drive(client);
    final clientId = await ensureClientFolder(client, clientName, organizationName: orgName);
    return _findOrCreateFolder(api, _sanitize(companyName), parentId: clientId);
  }

  /// Cria estrutura: Gestor de Projetos/Organizações/{organizationName}/Clientes/{clientName}/{projectName}/
  /// Mantido para retrocompatibilidade (projetos sem empresa)
  Future<String> ensureProjectFolder(auth.AuthClient client, String clientName, String projectName, {String? organizationName}) async {
    final orgName = _getOrganizationName(organizationName);
    final api = await _drive(client);
    final clientId = await ensureClientFolder(client, clientName, organizationName: orgName);
    return _findOrCreateFolder(api, _sanitize(projectName), parentId: clientId);
  }

  /// Cria estrutura: Gestor de Projetos/Organizações/{organizationName}/Clientes/{clientName}/{companyName}/{projectName}/
  /// Use esta função quando o projeto tiver uma empresa associada
  Future<String> ensureProjectFolderWithCompany(auth.AuthClient client, String clientName, String companyName, String projectName, {String? organizationName}) async {
    final orgName = _getOrganizationName(organizationName);
    final api = await _drive(client);
    final companyId = await ensureCompanyFolder(client, clientName, companyName, organizationName: orgName);
    return _findOrCreateFolder(api, _sanitize(projectName), parentId: companyId);
  }

  Future<String> ensureTaskFolder(auth.AuthClient client, String clientName, String projectName, String taskName, {String? organizationName}) async {
    final orgName = _getOrganizationName(organizationName);
    final api = await _drive(client);
    final projectId = await ensureProjectFolder(client, clientName, projectName, organizationName: orgName);
    final base = _sanitize(taskName);
    final withCheck = '$base ✅';
    // try to find either normal or checked folder first
    final q = [
      "mimeType = 'application/vnd.google-apps.folder'",
      "'${_escape(projectId)}' in parents",
      "(name = '${_escape(base)}' or name = '${_escape(withCheck)}')",
      'trashed = false',
    ].join(' and ');
    final res = await api.files.list(q: q, $fields: 'files(id,name)');
    if (res.files != null && res.files!.isNotEmpty) return res.files!.first.id!;
    return _findOrCreateFolder(api, base, parentId: projectId);
  }

  /// Cria estrutura de tarefa com empresa: Gestor de Projetos/Organizações/{Org}/Clientes/{Cliente}/{Empresa}/{Projeto}/{Tarefa}/
  Future<String> ensureTaskFolderWithCompany(auth.AuthClient client, String clientName, String companyName, String projectName, String taskName, {String? organizationName}) async {
    final orgName = _getOrganizationName(organizationName);
    final api = await _drive(client);
    final projectId = await ensureProjectFolderWithCompany(client, clientName, companyName, projectName, organizationName: orgName);
    final base = _sanitize(taskName);
    final withCheck = '$base ✅';
    // try to find either normal or checked folder first
    final q = [
      "mimeType = 'application/vnd.google-apps.folder'",
      "'${_escape(projectId)}' in parents",
      "(name = '${_escape(base)}' or name = '${_escape(withCheck)}')",
      'trashed = false',
    ].join(' and ');
    final res = await api.files.list(q: q, $fields: 'files(id,name)');
    if (res.files != null && res.files!.isNotEmpty) return res.files!.first.id!;
    return _findOrCreateFolder(api, base, parentId: projectId);
  }

  /// Add '✅' to the task folder name (idempotent). Creates if missing.
  Future<void> addCompletedBadgeToTaskFolder({
    required auth.AuthClient client,
    required String clientName,
    required String projectName,
    required String taskName,
    String? organizationName,
  }) async {
    final orgName = _getOrganizationName(organizationName);
    final api = await _drive(client);
    final projectId = await ensureProjectFolder(client, clientName, projectName, organizationName: orgName);
    final base = _sanitize(taskName);
    final withCheck = '$base ✅';

    final q = [
      "mimeType = 'application/vnd.google-apps.folder'",
      "'${_escape(projectId)}' in parents",
      "(name = '${_escape(base)}' or name = '${_escape(withCheck)}')",
      'trashed = false',
    ].join(' and ');
    final res = await api.files.list(q: q, $fields: 'files(id,name)');
    if (res.files != null && res.files!.isNotEmpty) {
      final folder = res.files!.first;
      if (folder.name != withCheck) {
        await api.files.update(drive.File()..name = withCheck, folder.id!);
      }
      return;
    }
    // Not found: create directly with check mark
    await api.files.create(drive.File()
      ..name = withCheck
      ..mimeType = 'application/vnd.google-apps.folder'
      ..parents = [projectId]);
  }

  /// Remove '✅' from the task folder name if present (idempotent)
  Future<void> removeCompletedBadgeFromTaskFolder({
    required auth.AuthClient client,
    required String clientName,
    required String projectName,
    required String taskName,
    String? organizationName,
  }) async {
    final orgName = _getOrganizationName(organizationName);
    final api = await _drive(client);
    final projectId = await ensureProjectFolder(client, clientName, projectName, organizationName: orgName);
    final base = _sanitize(taskName);
    final withCheck = '$base ✅';

    final q = [
      "mimeType = 'application/vnd.google-apps.folder'",
      "'${_escape(projectId)}' in parents",
      "(name = '${_escape(base)}' or name = '${_escape(withCheck)}')",
      'trashed = false',
    ].join(' and ');
    final res = await api.files.list(q: q, $fields: 'files(id,name)');
    if (res.files != null && res.files!.isNotEmpty) {
      final folder = res.files!.first;
      if (folder.name == withCheck) {
        await api.files.update(drive.File()..name = base, folder.id!);
      }
      return;
    }
    // Se não há pasta alguma, criamos sem check (mais seguro)
    await api.files.create(drive.File()
      ..name = base
      ..mimeType = 'application/vnd.google-apps.folder'
      ..parents = [projectId]);
  }

  String _sanitize(String name) {
    var s = name.trim();
    s = s.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    if (s.isEmpty) s = 'Sem nome';
    return s;
  }

  Future<UploadedDriveFile> uploadToTaskFolder({
    required auth.AuthClient client,
    required String clientName,
    required String projectName,
    required String taskName,
    required String filename,
    required List<int> bytes,
    String? mimeType,
    String? organizationName,
  }) async {
    debugPrint('🔵 [Drive] uploadToTaskFolder INICIADO');
    debugPrint('   📁 Cliente: $clientName');
    debugPrint('   📁 Projeto: $projectName');
    debugPrint('   📁 Tarefa: $taskName');
    debugPrint('   📄 Arquivo: $filename (${bytes.length} bytes)');

    debugPrint('🔵 [Drive] Obtendo API do Drive...');
    final api = await _drive(client);
    debugPrint('✅ [Drive] API obtida com sucesso');

    debugPrint('🔵 [Drive] Garantindo pasta da tarefa...');
    final taskFolder = await ensureTaskFolder(client, clientName, projectName, taskName, organizationName: organizationName);
    debugPrint('✅ [Drive] Pasta da tarefa: $taskFolder');

    debugPrint('🔵 [Drive] Criando objeto File...');
    final file = drive.File()
      ..name = filename
      ..parents = [taskFolder];
    debugPrint('✅ [Drive] Objeto File criado');

    final contentType = mimeType ?? mime.lookupMimeType(filename) ?? 'application/octet-stream';
    debugPrint('🔵 [Drive] Content-Type: $contentType');

    debugPrint('🔵 [Drive] Criando Media stream...');
    final media = drive.Media(Stream.value(bytes), bytes.length, contentType: contentType);
    debugPrint('✅ [Drive] Media stream criado');

    debugPrint('🔵 [Drive] Enviando arquivo para o Drive...');
    final created = await api.files.create(file, uploadMedia: media, $fields: 'id');
    debugPrint('✅ [Drive] Arquivo enviado! ID: ${created.id}');

    debugPrint('🔵 [Drive] Tornando arquivo público...');
    try {
      await api.permissions.create(
        drive.Permission()
          ..type = 'anyone'
          ..role = 'reader',
        created.id!,
      );
      debugPrint('✅ [Drive] Arquivo tornado público');
    } catch (e) {
      debugPrint('⚠️ [Drive] Falha ao tornar arquivo público: $e');
      debugPrint('Falha ao tornar arquivo público (link): $e');
    }

    debugPrint('🔵 [Drive] Obtendo metadados do arquivo...');
    final f = await api.files.get(created.id!, $fields: 'id,thumbnailLink') as drive.File;
    final id = f.id!;
    final publicViewUrl = Uri.https('drive.google.com', '/uc', {'export': 'view', 'id': id}).toString();
    debugPrint('✅ [Drive] Metadados obtidos');
    debugPrint('   🔗 URL pública: $publicViewUrl');

    debugPrint('✅ [Drive] uploadToTaskFolder CONCLUÍDO');
    return UploadedDriveFile(
      id: id,
      publicViewUrl: publicViewUrl,
      thumbnailLink: f.thumbnailLink,
    );
  }

  /// Upload usando Resumable Upload API do Google Drive (para arquivos grandes)
  /// Permite uploads de qualquer tamanho com progresso real e sem travar a UI
  Future<UploadedDriveFile> uploadToTaskFolderResumable({
    required auth.AuthClient client,
    required String clientName,
    required String projectName,
    required String taskName,
    required String filename,
    required List<int> bytes,
    String? mimeType,
    required Function(double progress) onProgress,
    String? organizationName,
    String? companyName,
  }) async {
    debugPrint('🔵 [Drive Resumable] Upload INICIADO');
    debugPrint('   📁 Cliente: $clientName');
    debugPrint('   📁 Projeto: $projectName');
    debugPrint('   📁 Tarefa: $taskName');
    debugPrint('   📄 Arquivo: $filename (${bytes.length} bytes)');

    final taskFolder = companyName != null && companyName.isNotEmpty
        ? await ensureTaskFolderWithCompany(client, clientName, companyName, projectName, taskName, organizationName: organizationName)
        : await ensureTaskFolder(client, clientName, projectName, taskName, organizationName: organizationName);
    final contentType = mimeType ?? mime.lookupMimeType(filename) ?? 'application/octet-stream';

    // PASSO 1: Iniciar sessão de upload resumable
    debugPrint('🔵 [Drive Resumable] Iniciando sessão de upload...');
    final metadata = {
      'name': filename,
      'parents': [taskFolder],
    };

    final initResponse = await http.post(
      Uri.parse('https://www.googleapis.com/upload/drive/v3/files?uploadType=resumable'),
      headers: {
        'Authorization': 'Bearer ${client.credentials.accessToken.data}',
        'Content-Type': 'application/json; charset=UTF-8',
        'X-Upload-Content-Type': contentType,
        'X-Upload-Content-Length': bytes.length.toString(),
      },
      body: convert.jsonEncode(metadata),
    );

    if (initResponse.statusCode != 200) {
      throw Exception('Falha ao iniciar upload resumable: ${initResponse.statusCode} - ${initResponse.body}');
    }

    final uploadUrl = initResponse.headers['location'];
    if (uploadUrl == null) {
      throw Exception('URL de upload não retornada');
    }

    debugPrint('✅ [Drive Resumable] Sessão iniciada. URL: $uploadUrl');

    // PASSO 2: Enviar arquivo em chunks
    // Usar chunks de 10 MB para upload suave sem travar a UI
    const chunkSize = 10 * 1024 * 1024; // 10 MB por chunk
    int uploadedBytes = 0;

    debugPrint('🔵 [Drive Resumable] Enviando arquivo em chunks de ${chunkSize ~/ 1024 ~/ 1024} MB...');

    while (uploadedBytes < bytes.length) {
      final end = (uploadedBytes + chunkSize < bytes.length)
          ? uploadedBytes + chunkSize
          : bytes.length;

      final chunk = bytes.sublist(uploadedBytes, end);
      final contentRange = 'bytes $uploadedBytes-${end - 1}/${bytes.length}';

      debugPrint('   📤 Enviando chunk: $contentRange');

      final chunkResponse = await http.put(
        Uri.parse(uploadUrl),
        headers: {
          'Content-Type': contentType,
          'Content-Length': chunk.length.toString(),
          'Content-Range': contentRange,
        },
        body: chunk,
      );

      // Status 308 = Resume Incomplete (continuar enviando)
      // Status 200 ou 201 = Upload completo
      if (chunkResponse.statusCode == 308) {
        // Continuar enviando
        uploadedBytes = end;
        final progress = uploadedBytes / bytes.length;
        onProgress(progress);
        debugPrint('   ✅ Chunk enviado. Progresso: ${(progress * 100).toStringAsFixed(1)}%');

        // Delay mínimo para permitir que a UI atualize
        await Future.delayed(const Duration(milliseconds: 1));
      } else if (chunkResponse.statusCode == 200 || chunkResponse.statusCode == 201) {
        // Upload completo!
        uploadedBytes = bytes.length;
        onProgress(1.0);
        debugPrint('✅ [Drive Resumable] Upload completo!');

        final fileData = convert.jsonDecode(chunkResponse.body);
        final fileId = fileData['id'] as String;

        // PASSO 3: Tornar arquivo público
        debugPrint('🔵 [Drive Resumable] Tornando arquivo público...');
        try {
          final api = await _drive(client);
          await api.permissions.create(
            drive.Permission()
              ..type = 'anyone'
              ..role = 'reader',
            fileId,
          );
          debugPrint('✅ [Drive Resumable] Arquivo tornado público');
        } catch (e) {
          debugPrint('⚠️ [Drive Resumable] Falha ao tornar público: $e');
        }

        // PASSO 4: Obter metadados
        debugPrint('🔵 [Drive Resumable] Obtendo metadados...');
        final api = await _drive(client);
        final file = await api.files.get(fileId, $fields: 'id,thumbnailLink') as drive.File;
        final publicViewUrl = Uri.https('drive.google.com', '/uc', {'export': 'view', 'id': fileId}).toString();

        debugPrint('✅ [Drive Resumable] Upload CONCLUÍDO');
        return UploadedDriveFile(
          id: fileId,
          publicViewUrl: publicViewUrl,
          thumbnailLink: file.thumbnailLink,
        );
      } else {
        throw Exception('Erro no upload do chunk: ${chunkResponse.statusCode} - ${chunkResponse.body}');
      }
    }

    throw Exception('Upload não foi concluído corretamente');
  }

  Future<UploadedDriveFile> uploadToProjectFolder({
    required auth.AuthClient client,
    required String clientName,
    required String projectName,
    required String filename,
    required List<int> bytes,
    String? mimeType,
    String? organizationName,
  }) async {
    final api = await _drive(client);
    final projectFolder = await ensureProjectFolder(client, clientName, projectName, organizationName: organizationName);

    final file = drive.File()
      ..name = filename
      ..parents = [projectFolder];

    final contentType = mimeType ?? mime.lookupMimeType(filename) ?? 'application/octet-stream';
    final media = drive.Media(Stream.value(bytes), bytes.length, contentType: contentType);

    final created = await api.files.create(file, uploadMedia: media, $fields: 'id');

    try {
      await api.permissions.create(
        drive.Permission()
          ..type = 'anyone'
          ..role = 'reader',
        created.id!,
      );
    } catch (e) {
      debugPrint('Falha ao tornar arquivo público (link): $e');
    }

    final f = await api.files.get(created.id!, $fields: 'id,thumbnailLink') as drive.File;
    final id = f.id!;
    final publicViewUrl = Uri.https('drive.google.com', '/uc', {'export': 'view', 'id': id}).toString();

    return UploadedDriveFile(
      id: id,
      publicViewUrl: publicViewUrl,
      thumbnailLink: f.thumbnailLink,
    );
  }

  Future<String> ensureProjectSubfolder(auth.AuthClient client, String clientName, String projectName, String subfolderName, {String? companyName, String? organizationName}) async {
    final orgName = _getOrganizationName(organizationName);
    final api = await _drive(client);
    final projectId = companyName != null && companyName.isNotEmpty
        ? await ensureProjectFolderWithCompany(client, clientName, companyName, projectName, organizationName: orgName)
        : await ensureProjectFolder(client, clientName, projectName, organizationName: orgName);
    return _findOrCreateFolder(api, _sanitize(subfolderName), parentId: projectId);
  }

  Future<UploadedDriveFile> uploadToProjectSubfolder({
    required auth.AuthClient client,
    required String clientName,
    required String projectName,
    required String subfolderName,
    required String filename,
    required List<int> bytes,
    String? mimeType,
    String? companyName,
  }) async {
    final api = await _drive(client);
    final folderId = await ensureProjectSubfolder(client, clientName, projectName, subfolderName, companyName: companyName);

    final file = drive.File()
      ..name = filename
      ..parents = [folderId];

    final contentType = mimeType ?? mime.lookupMimeType(filename) ?? 'application/octet-stream';
    final media = drive.Media(Stream.value(bytes), bytes.length, contentType: contentType);

    final created = await api.files.create(file, uploadMedia: media, $fields: 'id');

    try {
      await api.permissions.create(
        drive.Permission()
          ..type = 'anyone'
          ..role = 'reader',
        created.id!,
      );
    } catch (e) {
      debugPrint('Falha ao tornar arquivo público (link): $e');
    }

    final f = await api.files.get(created.id!, $fields: 'id,thumbnailLink') as drive.File;
    final id = f.id!;
    final publicViewUrl = Uri.https('drive.google.com', '/uc', {'export': 'view', 'id': id}).toString();

    return UploadedDriveFile(
      id: id,
      publicViewUrl: publicViewUrl,
      thumbnailLink: f.thumbnailLink,
    );
  }


  // ===== Catalog helpers =====
  Future<String> ensureCatalogFolder(auth.AuthClient client) async {
    final api = await _drive(client);
    final rootId = await ensureRootFolder(client);
    return _findOrCreateFolder(api, 'Catalogo', parentId: rootId);
  }

  Future<String> ensureCatalogSubfolder(auth.AuthClient client, String subfolder) async {
    final api = await _drive(client);
    final catId = await ensureCatalogFolder(client);
    return _findOrCreateFolder(api, _sanitize(subfolder), parentId: catId);
  }

  Future<UploadedDriveFile> uploadToCatalog({
    required auth.AuthClient client,
    required String subfolderName, // e.g., 'Produtos', 'Pacotes'
    required String filename,
    required List<int> bytes,
    String? mimeType,
  }) async {
    final api = await _drive(client);
    final folderId = await ensureCatalogSubfolder(client, subfolderName);

    final file = drive.File()
      ..name = filename
      ..parents = [folderId];

    final contentType = mimeType ?? mime.lookupMimeType(filename) ?? 'application/octet-stream';
    final media = drive.Media(Stream.value(bytes), bytes.length, contentType: contentType);

    final created = await api.files.create(file, uploadMedia: media, $fields: 'id');

    try {
      await api.permissions.create(
        drive.Permission()
          ..type = 'anyone'
          ..role = 'reader',
        created.id!,
      );
    } catch (e) {
      debugPrint('Falha ao tornar arquivo público (link): $e');
    }

    final f = await api.files.get(created.id!, $fields: 'id,thumbnailLink') as drive.File;
    final id = f.id!;
    final publicViewUrl = Uri.https('drive.google.com', '/uc', {'export': 'view', 'id': id}).toString();

    return UploadedDriveFile(
      id: id,
      publicViewUrl: publicViewUrl,
      thumbnailLink: f.thumbnailLink,
    );
  }

  Future<String> ensureTaskSubfolder({
    required auth.AuthClient client,
    required String clientName,
    required String projectName,
    required String taskName,
    required String subfolderName,
    String? companyName,
    String? organizationName,
  }) async {
    final orgName = _getOrganizationName(organizationName);
    final api = await _drive(client);
    final taskFolder = companyName != null && companyName.isNotEmpty
        ? await ensureTaskFolderWithCompany(client, clientName, companyName, projectName, taskName, organizationName: orgName)
        : await ensureTaskFolder(client, clientName, projectName, taskName, organizationName: orgName);
    final sub = _sanitize(subfolderName);
    return _findOrCreateFolder(api, sub, parentId: taskFolder);
  }

  Future<String> ensureAssetsFolder(auth.AuthClient client, String clientName, String projectName, String taskName, {String? companyName, String? organizationName}) {
    return ensureTaskSubfolder(client: client, clientName: clientName, projectName: projectName, taskName: taskName, subfolderName: 'Assets', companyName: companyName, organizationName: organizationName);
  }

  Future<String> ensureBriefingFolder(auth.AuthClient client, String clientName, String projectName, String taskName, {String? companyName, String? organizationName}) {
    return ensureTaskSubfolder(client: client, clientName: clientName, projectName: projectName, taskName: taskName, subfolderName: 'Briefing', companyName: companyName, organizationName: organizationName);
  }

  Future<String> ensureCommentsFolder(auth.AuthClient client, String clientName, String projectName, String taskName, {String? companyName, String? organizationName}) {
    return ensureTaskSubfolder(client: client, clientName: clientName, projectName: projectName, taskName: taskName, subfolderName: 'Comentarios', companyName: companyName, organizationName: organizationName);
  }

  Future<UploadedDriveFile> uploadToTaskSubfolder({
    required auth.AuthClient client,
    required String clientName,
    required String projectName,
    required String taskName,
    required String subfolderName,
    required String filename,
    required List<int> bytes,
    String? mimeType,
    String? companyName,
    String? organizationName,
  }) async {
    final api = await _drive(client);
    final subfolder = await ensureTaskSubfolder(
      client: client,
      clientName: clientName,
      projectName: projectName,
      taskName: taskName,
      subfolderName: subfolderName,
      companyName: companyName,
      organizationName: organizationName,
    );

    final file = drive.File()
      ..name = filename
      ..parents = [subfolder];

    final contentType = mimeType ?? mime.lookupMimeType(filename) ?? 'application/octet-stream';
    final media = drive.Media(Stream.value(bytes), bytes.length, contentType: contentType);

    final created = await api.files.create(file, uploadMedia: media, $fields: 'id');

    try {
      await api.permissions.create(
        drive.Permission()
          ..type = 'anyone'
          ..role = 'reader',
        created.id!,
      );
    } catch (e) {
      debugPrint('Falha ao tornar arquivo público (link): $e');
    }

    final f = await api.files.get(created.id!, $fields: 'id,thumbnailLink') as drive.File;
    final id = f.id!;
    final publicViewUrl = Uri.https('drive.google.com', '/uc', {'export': 'view', 'id': id}).toString();

    return UploadedDriveFile(
      id: id,
      publicViewUrl: publicViewUrl,
      thumbnailLink: f.thumbnailLink,
    );
  }

  /// Upload file to task subfolder using Resumable Upload API (for large files)
  Future<UploadedDriveFile> uploadToTaskSubfolderResumable({
    required auth.AuthClient client,
    required String clientName,
    required String projectName,
    required String taskName,
    required String subfolderName,
    required String filename,
    required List<int> bytes,
    String? mimeType,
    String? companyName,
    Function(double progress)? onProgress,
  }) async {
    debugPrint('🔵 [Drive Resumable Subfolder] Upload INICIADO');
    debugPrint('   📁 Cliente: $clientName');
    debugPrint('   📁 Projeto: $projectName');
    debugPrint('   📁 Tarefa: $taskName');
    debugPrint('   📁 Subpasta: $subfolderName');
    debugPrint('   📄 Arquivo: $filename (${bytes.length} bytes)');

    final subfolder = await ensureTaskSubfolder(
      client: client,
      clientName: clientName,
      projectName: projectName,
      taskName: taskName,
      subfolderName: subfolderName,
      companyName: companyName,
    );
    final contentType = mimeType ?? mime.lookupMimeType(filename) ?? 'application/octet-stream';

    // PASSO 1: Iniciar sessão de upload resumable
    debugPrint('🔵 [Drive Resumable Subfolder] Iniciando sessão de upload...');
    final metadata = {
      'name': filename,
      'parents': [subfolder],
    };

    final initResponse = await http.post(
      Uri.parse('https://www.googleapis.com/upload/drive/v3/files?uploadType=resumable'),
      headers: {
        'Authorization': 'Bearer ${client.credentials.accessToken.data}',
        'Content-Type': 'application/json; charset=UTF-8',
        'X-Upload-Content-Type': contentType,
        'X-Upload-Content-Length': bytes.length.toString(),
      },
      body: convert.jsonEncode(metadata),
    );

    if (initResponse.statusCode != 200) {
      throw Exception('Falha ao iniciar sessão de upload: ${initResponse.statusCode} - ${initResponse.body}');
    }

    final uploadUrl = initResponse.headers['location'];
    if (uploadUrl == null) {
      throw Exception('URL de upload não retornada');
    }

    debugPrint('✅ [Drive Resumable Subfolder] Sessão iniciada. URL: $uploadUrl');

    // PASSO 2: Enviar arquivo em chunks
    // Usar chunks de 10 MB para upload suave sem travar a UI
    const chunkSize = 10 * 1024 * 1024; // 10 MB por chunk
    int uploadedBytes = 0;

    debugPrint('🔵 [Drive Resumable Subfolder] Enviando arquivo em chunks de ${chunkSize ~/ 1024 ~/ 1024} MB...');

    while (uploadedBytes < bytes.length) {
      final end = (uploadedBytes + chunkSize < bytes.length)
          ? uploadedBytes + chunkSize
          : bytes.length;

      final chunk = bytes.sublist(uploadedBytes, end);
      final contentRange = 'bytes $uploadedBytes-${end - 1}/${bytes.length}';

      debugPrint('   📤 Enviando chunk: $contentRange');

      final chunkResponse = await http.put(
        Uri.parse(uploadUrl),
        headers: {
          'Content-Type': contentType,
          'Content-Length': chunk.length.toString(),
          'Content-Range': contentRange,
        },
        body: chunk,
      );

      // Status 308 = Resume Incomplete (continuar enviando)
      // Status 200 ou 201 = Upload completo
      if (chunkResponse.statusCode == 308) {
        // Continuar enviando
        uploadedBytes = end;
        final progress = uploadedBytes / bytes.length;
        onProgress?.call(progress);
        debugPrint('   ✅ Chunk enviado. Progresso: ${(progress * 100).toStringAsFixed(1)}%');

        // Delay mínimo para permitir que a UI atualize
        await Future.delayed(const Duration(milliseconds: 1));
      } else if (chunkResponse.statusCode == 200 || chunkResponse.statusCode == 201) {
        // Upload completo!
        uploadedBytes = bytes.length;
        onProgress?.call(1.0);
        debugPrint('✅ [Drive Resumable Subfolder] Upload completo!');

        final fileData = convert.jsonDecode(chunkResponse.body);
        final fileId = fileData['id'] as String;

        // PASSO 3: Tornar arquivo público
        debugPrint('🔵 [Drive Resumable Subfolder] Tornando arquivo público...');
        try {
          final api = await _drive(client);
          await api.permissions.create(
            drive.Permission()
              ..type = 'anyone'
              ..role = 'reader',
            fileId,
          );
          debugPrint('✅ [Drive Resumable Subfolder] Arquivo tornado público');
        } catch (e) {
          debugPrint('⚠️ [Drive Resumable Subfolder] Falha ao tornar público: $e');
        }

        // PASSO 4: Obter metadados
        debugPrint('🔵 [Drive Resumable Subfolder] Obtendo metadados...');
        final api = await _drive(client);
        final file = await api.files.get(fileId, $fields: 'id,thumbnailLink') as drive.File;
        final publicViewUrl = Uri.https('drive.google.com', '/uc', {'export': 'view', 'id': fileId}).toString();

        debugPrint('✅ [Drive Resumable Subfolder] Upload CONCLUÍDO');
        return UploadedDriveFile(
          id: fileId,
          publicViewUrl: publicViewUrl,
          thumbnailLink: file.thumbnailLink,
        );
      } else {
        throw Exception('Erro no upload do chunk: ${chunkResponse.statusCode} - ${chunkResponse.body}');
      }
    }

    throw Exception('Upload não foi concluído corretamente');
  }


  Future<void> deleteFile({
    required auth.AuthClient client,
    required String driveFileId,
  }) async {
    final api = await _drive(client);
    await api.files.delete(driveFileId);
  }

  // Best-effort deletion of the whole task folder and its contents
  Future<void> deleteTaskFolder({
    required auth.AuthClient client,
    required String clientName,
    required String projectName,
    required String taskName,
    String? companyName,
  }) async {
    try {
      final api = await _drive(client);

      Future<String?> findFolder(String name, {String? parentId}) async {
        final q = [
          "mimeType = 'application/vnd.google-apps.folder'",
          "name = '${_escape(_sanitize(name))}'",
          if (parentId != null) "'${_escape(parentId)}' in parents",
          'trashed = false',
        ].join(' and ');
        final res = await api.files.list(q: q, $fields: 'files(id,name)');
        if (res.files != null && res.files!.isNotEmpty) return res.files!.first.id!;
        return null;
      }

      final rootId = await findFolder('Gestor de Projetos');
      if (rootId == null) {
        debugPrint('Drive delete: root folder not found');
        return;
      }
      final clientsId = await findFolder('Clientes', parentId: rootId);
      if (clientsId == null) {
        debugPrint('Drive delete: Clientes folder not found');
        return;
      }
      final clientId = await findFolder(clientName, parentId: clientsId);
      if (clientId == null) {
        debugPrint('Drive delete: client folder not found');
        return;
      }

      String? parentId = clientId;

      // Se tem empresa, buscar a pasta da empresa
      if (companyName != null && companyName.isNotEmpty) {
        final companyId = await findFolder(companyName, parentId: clientId);
        if (companyId == null) {
          debugPrint('Drive delete: company folder not found');
          return;
        }
        parentId = companyId;
      }

      final projectId = await findFolder(projectName, parentId: parentId);
      if (projectId == null) {
        debugPrint('Drive delete: project folder not found');
        return;
      }

      final base = _sanitize(taskName);
      final withCheck = '$base ✅';
      // Find either folder variant
      String? taskFolderId;
      for (final name in [base, withCheck]) {
        taskFolderId = await findFolder(name, parentId: projectId);
        if (taskFolderId != null) break;
      }
      if (taskFolderId == null) {
        debugPrint('Drive delete: task folder not found');
        return;
      }

      await api.files.delete(taskFolderId);
      debugPrint('✅ Pasta da tarefa deletada do Google Drive: $taskName');
    } catch (e) {
      debugPrint('⚠️ Erro ao deletar pasta da tarefa no Google Drive: $e');
    }
  }

  /// Best-effort deletion of the whole project folder and its contents
  /// This will delete the project folder and ALL its contents including:
  /// - All task folders
  /// - Financeiro folder
  /// - All files within those folders
  Future<void> deleteProjectFolder({
    required auth.AuthClient client,
    required String clientName,
    required String projectName,
  }) async {
    try {
      final api = await _drive(client);

      Future<String?> findFolder(String name, {String? parentId}) async {
        final q = [
          "mimeType = 'application/vnd.google-apps.folder'",
          "name = '${_escape(_sanitize(name))}'",
          if (parentId != null) "'${_escape(parentId)}' in parents",
          'trashed = false',
        ].join(' and ');
        final res = await api.files.list(q: q, $fields: 'files(id,name)');
        if (res.files != null && res.files!.isNotEmpty) return res.files!.first.id!;
        return null;
      }

      final rootId = await findFolder('Gestor de Projetos');
      if (rootId == null) {
        debugPrint('Drive delete: root folder not found');
        return;
      }
      final clientId = await findFolder(clientName, parentId: rootId);
      if (clientId == null) {
        debugPrint('Drive delete: client folder not found');
        return;
      }
      final projectId = await findFolder(projectName, parentId: clientId);
      if (projectId == null) {
        debugPrint('Drive delete: project folder not found');
        return;
      }

      // Delete the entire project folder (this deletes all contents recursively)
      await api.files.delete(projectId);
      debugPrint('Drive delete: successfully deleted project folder: $projectName');
    } catch (e) {
      debugPrint('Drive delete: failed to delete project folder: $e');
    }
  }

  /// Best-effort deletion of the whole client folder and its contents
  /// This will delete the client folder and ALL its contents including:
  /// - All project folders
  /// - All task folders within projects
  /// - All files within those folders
  Future<void> deleteClientFolder({
    required auth.AuthClient client,
    required String clientName,
  }) async {
    try {
      final api = await _drive(client);

      Future<String?> findFolder(String name, {String? parentId}) async {
        final q = [
          "mimeType = 'application/vnd.google-apps.folder'",
          "name = '${_escape(_sanitize(name))}'",
          if (parentId != null) "'${_escape(parentId)}' in parents",
          'trashed = false',
        ].join(' and ');
        final res = await api.files.list(q: q, $fields: 'files(id,name)');
        if (res.files != null && res.files!.isNotEmpty) return res.files!.first.id!;
        return null;
      }

      final rootId = await findFolder('Gestor de Projetos');
      if (rootId == null) {
        debugPrint('Drive delete: root folder not found');
        return;
      }
      final clientsId = await findFolder('Clientes', parentId: rootId);
      if (clientsId == null) {
        debugPrint('Drive delete: Clientes folder not found');
        return;
      }
      final clientId = await findFolder(clientName, parentId: clientsId);
      if (clientId == null) {
        debugPrint('Drive delete: client folder not found');
        return;
      }

      // Delete the entire client folder (this deletes all contents recursively)
      await api.files.delete(clientId);
      debugPrint('Drive delete: successfully deleted client folder: $clientName');
    } catch (e) {
      debugPrint('Drive delete: failed to delete client folder: $e');
    }
  }

  /// Best-effort deletion of a company folder within a client folder
  /// This will delete the company folder and ALL its contents
  Future<void> deleteCompanyFolder({
    required auth.AuthClient client,
    required String clientName,
    required String companyName,
  }) async {
    try {
      final api = await _drive(client);

      Future<String?> findFolder(String name, {String? parentId}) async {
        final q = [
          "mimeType = 'application/vnd.google-apps.folder'",
          "name = '${_escape(_sanitize(name))}'",
          if (parentId != null) "'${_escape(parentId)}' in parents",
          'trashed = false',
        ].join(' and ');
        final res = await api.files.list(q: q, $fields: 'files(id,name)');
        if (res.files != null && res.files!.isNotEmpty) return res.files!.first.id!;
        return null;
      }

      final rootId = await findFolder('Gestor de Projetos');
      if (rootId == null) {
        debugPrint('Drive delete: root folder not found');
        return;
      }
      final clientsId = await findFolder('Clientes', parentId: rootId);
      if (clientsId == null) {
        debugPrint('Drive delete: Clientes folder not found');
        return;
      }
      final clientId = await findFolder(clientName, parentId: clientsId);
      if (clientId == null) {
        debugPrint('Drive delete: client folder not found');
        return;
      }
      final companyId = await findFolder(companyName, parentId: clientId);
      if (companyId == null) {
        debugPrint('Drive delete: company folder not found');
        return;
      }

      // Delete the entire company folder (this deletes all contents recursively)
      await api.files.delete(companyId);
      debugPrint('Drive delete: successfully deleted company folder: $companyName');
    } catch (e) {
      debugPrint('Drive delete: failed to delete company folder: $e');
    }
  }

  /// Deleta a pasta da organização no Google Drive
  /// Estrutura: Gestor de Projetos/Organizações/{organizationName}/
  /// Isso deletará recursivamente todos os clientes, projetos e tarefas da organização
  Future<void> deleteOrganizationFolder({
    required auth.AuthClient client,
    required String organizationName,
  }) async {
    try {
      debugPrint('🗑️ Deletando pasta da organização no Google Drive: $organizationName');
      final api = await _drive(client);

      // Buscar pasta "Organizações"
      final organizationsId = await ensureOrganizationsFolder(client);

      // Buscar pasta da organização dentro de "Organizações"
      final sanitizedOrgName = _sanitize(organizationName);
      final q = [
        "mimeType = 'application/vnd.google-apps.folder'",
        "name = '${_escape(sanitizedOrgName)}'",
        "'${_escape(organizationsId)}' in parents",
        'trashed = false',
      ].join(' and ');

      final res = await api.files.list(q: q, $fields: 'files(id,name)');

      if (res.files != null && res.files!.isNotEmpty) {
        final orgFolderId = res.files!.first.id!;
        debugPrint('   📁 Pasta encontrada: ${res.files!.first.name} (ID: $orgFolderId)');
        debugPrint('   🗑️ Deletando pasta recursivamente...');
        await api.files.delete(orgFolderId);
        debugPrint('   ✅ Pasta da organização deletada com sucesso');
      } else {
        debugPrint('   ⚠️ Pasta da organização não encontrada no Drive');
      }
    } catch (e) {
      debugPrint('⚠️ Erro ao deletar pasta da organização no Google Drive: $e');
      // Não propagar o erro para não bloquear a exclusão da organização
    }
  }

  // ============================================================================
  // RENAME FUNCTIONS
  // ============================================================================

  /// Rename a client folder in Google Drive
  Future<void> renameClientFolder({
    required auth.AuthClient client,
    required String oldClientName,
    required String newClientName,
  }) async {
    try {
      final api = await _drive(client);

      Future<String?> findFolder(String name, {String? parentId}) async {
        final q = [
          "mimeType = 'application/vnd.google-apps.folder'",
          "name = '${_escape(_sanitize(name))}'",
          if (parentId != null) "'${_escape(parentId)}' in parents",
          'trashed = false',
        ].join(' and ');
        final res = await api.files.list(q: q, $fields: 'files(id,name)');
        if (res.files != null && res.files!.isNotEmpty) return res.files!.first.id!;
        return null;
      }

      final rootId = await findFolder('Gestor de Projetos');
      if (rootId == null) {
        debugPrint('Drive rename: root folder not found');
        return;
      }
      final clientsId = await findFolder('Clientes', parentId: rootId);
      if (clientsId == null) {
        debugPrint('Drive rename: Clientes folder not found');
        return;
      }
      final clientId = await findFolder(oldClientName, parentId: clientsId);
      if (clientId == null) {
        debugPrint('Drive rename: client folder not found: $oldClientName');
        return;
      }

      // Rename the folder
      await api.files.update(
        drive.File()..name = _sanitize(newClientName),
        clientId,
      );
      debugPrint('✅ Pasta do cliente renomeada no Google Drive: $oldClientName -> $newClientName');
    } catch (e) {
      debugPrint('⚠️ Erro ao renomear pasta do cliente no Google Drive: $e');
    }
  }

  /// Rename a company folder in Google Drive
  Future<void> renameCompanyFolder({
    required auth.AuthClient client,
    required String clientName,
    required String oldCompanyName,
    required String newCompanyName,
  }) async {
    try {
      final api = await _drive(client);

      Future<String?> findFolder(String name, {String? parentId}) async {
        final q = [
          "mimeType = 'application/vnd.google-apps.folder'",
          "name = '${_escape(_sanitize(name))}'",
          if (parentId != null) "'${_escape(parentId)}' in parents",
          'trashed = false',
        ].join(' and ');
        final res = await api.files.list(q: q, $fields: 'files(id,name)');
        if (res.files != null && res.files!.isNotEmpty) return res.files!.first.id!;
        return null;
      }

      final rootId = await findFolder('Gestor de Projetos');
      if (rootId == null) {
        debugPrint('Drive rename: root folder not found');
        return;
      }
      final clientsId = await findFolder('Clientes', parentId: rootId);
      if (clientsId == null) {
        debugPrint('Drive rename: Clientes folder not found');
        return;
      }
      final clientId = await findFolder(clientName, parentId: clientsId);
      if (clientId == null) {
        debugPrint('Drive rename: client folder not found');
        return;
      }
      final companyId = await findFolder(oldCompanyName, parentId: clientId);
      if (companyId == null) {
        debugPrint('Drive rename: company folder not found: $oldCompanyName');
        return;
      }

      // Rename the folder
      await api.files.update(
        drive.File()..name = _sanitize(newCompanyName),
        companyId,
      );
      debugPrint('✅ Pasta da empresa renomeada no Google Drive: $oldCompanyName -> $newCompanyName');
    } catch (e) {
      debugPrint('⚠️ Erro ao renomear pasta da empresa no Google Drive: $e');
    }
  }

  /// Rename a project folder in Google Drive
  /// Works for both structures: with company and without company
  Future<void> renameProjectFolder({
    required auth.AuthClient client,
    required String clientName,
    required String oldProjectName,
    required String newProjectName,
    String? companyName,
  }) async {
    try {
      final api = await _drive(client);

      Future<String?> findFolder(String name, {String? parentId}) async {
        final q = [
          "mimeType = 'application/vnd.google-apps.folder'",
          "name = '${_escape(_sanitize(name))}'",
          if (parentId != null) "'${_escape(parentId)}' in parents",
          'trashed = false',
        ].join(' and ');
        final res = await api.files.list(q: q, $fields: 'files(id,name)');
        if (res.files != null && res.files!.isNotEmpty) return res.files!.first.id!;
        return null;
      }

      final rootId = await findFolder('Gestor de Projetos');
      if (rootId == null) {
        debugPrint('Drive rename: root folder not found');
        return;
      }
      final clientsId = await findFolder('Clientes', parentId: rootId);
      if (clientsId == null) {
        debugPrint('Drive rename: Clientes folder not found');
        return;
      }
      final clientId = await findFolder(clientName, parentId: clientsId);
      if (clientId == null) {
        debugPrint('Drive rename: client folder not found');
        return;
      }

      String? parentId = clientId;

      // Se tem empresa, buscar a pasta da empresa
      if (companyName != null && companyName.isNotEmpty) {
        final companyId = await findFolder(companyName, parentId: clientId);
        if (companyId == null) {
          debugPrint('Drive rename: company folder not found');
          return;
        }
        parentId = companyId;
      }

      final projectId = await findFolder(oldProjectName, parentId: parentId);
      if (projectId == null) {
        debugPrint('Drive rename: project folder not found: $oldProjectName');
        return;
      }

      // Rename the folder
      await api.files.update(
        drive.File()..name = _sanitize(newProjectName),
        projectId,
      );
      debugPrint('✅ Pasta do projeto renomeada no Google Drive: $oldProjectName -> $newProjectName');
    } catch (e) {
      debugPrint('⚠️ Erro ao renomear pasta do projeto no Google Drive: $e');
    }
  }

  /// Rename a task folder in Google Drive
  /// Works for both structures: with company and without company
  Future<void> renameTaskFolder({
    required auth.AuthClient client,
    required String clientName,
    required String projectName,
    required String oldTaskName,
    required String newTaskName,
    String? companyName,
  }) async {
    try {
      final api = await _drive(client);

      Future<String?> findFolder(String name, {String? parentId}) async {
        final q = [
          "mimeType = 'application/vnd.google-apps.folder'",
          "name = '${_escape(_sanitize(name))}'",
          if (parentId != null) "'${_escape(parentId)}' in parents",
          'trashed = false',
        ].join(' and ');
        final res = await api.files.list(q: q, $fields: 'files(id,name)');
        if (res.files != null && res.files!.isNotEmpty) return res.files!.first.id!;
        return null;
      }

      final rootId = await findFolder('Gestor de Projetos');
      if (rootId == null) {
        debugPrint('Drive rename: root folder not found');
        return;
      }
      final clientsId = await findFolder('Clientes', parentId: rootId);
      if (clientsId == null) {
        debugPrint('Drive rename: Clientes folder not found');
        return;
      }
      final clientId = await findFolder(clientName, parentId: clientsId);
      if (clientId == null) {
        debugPrint('Drive rename: client folder not found');
        return;
      }

      String? parentId = clientId;

      // Se tem empresa, buscar a pasta da empresa
      if (companyName != null && companyName.isNotEmpty) {
        final companyId = await findFolder(companyName, parentId: clientId);
        if (companyId == null) {
          debugPrint('Drive rename: company folder not found');
          return;
        }
        parentId = companyId;
      }

      final projectId = await findFolder(projectName, parentId: parentId);
      if (projectId == null) {
        debugPrint('Drive rename: project folder not found');
        return;
      }

      // Buscar a pasta da tarefa (pode ter ✅ no final)
      final oldTaskBase = _sanitize(oldTaskName);
      final oldTaskWithCheck = '$oldTaskBase ✅';

      final q = [
        "mimeType = 'application/vnd.google-apps.folder'",
        "'${_escape(projectId)}' in parents",
        "(name = '${_escape(oldTaskBase)}' or name = '${_escape(oldTaskWithCheck)}')",
        'trashed = false',
      ].join(' and ');
      final res = await api.files.list(q: q, $fields: 'files(id,name)');

      if (res.files == null || res.files!.isEmpty) {
        debugPrint('Drive rename: task folder not found: $oldTaskName');
        return;
      }

      final taskFolder = res.files!.first;
      final taskId = taskFolder.id!;
      final hadCheck = taskFolder.name == oldTaskWithCheck;

      // Rename the folder (mantém o ✅ se tinha)
      final newTaskBase = _sanitize(newTaskName);
      final newName = hadCheck ? '$newTaskBase ✅' : newTaskBase;

      await api.files.update(
        drive.File()..name = newName,
        taskId,
      );
      debugPrint('✅ Pasta da tarefa renomeada no Google Drive: $oldTaskName -> $newTaskName');

      // Renomear imagens do briefing dentro da pasta Briefing
      await _renameBriefingImages(
        api: api,
        taskFolderId: taskId,
        oldTaskName: oldTaskName,
        newTaskName: newTaskName,
        clientName: clientName,
        projectName: projectName,
      );
    } catch (e) {
      debugPrint('⚠️ Erro ao renomear pasta da tarefa no Google Drive: $e');
    }
  }

  /// Rename briefing images when task is renamed
  /// Format: Briefing-TaskName_ClientName-ProjectName-01.png
  Future<void> _renameBriefingImages({
    required drive.DriveApi api,
    required String taskFolderId,
    required String oldTaskName,
    required String newTaskName,
    required String clientName,
    required String projectName,
  }) async {
    try {
      // Buscar a pasta Briefing dentro da pasta da tarefa
      final briefingFolderQuery = [
        "mimeType = 'application/vnd.google-apps.folder'",
        "name = 'Briefing'",
        "'${_escape(taskFolderId)}' in parents",
        'trashed = false',
      ].join(' and ');

      final briefingFolderRes = await api.files.list(
        q: briefingFolderQuery,
        $fields: 'files(id,name)',
      );

      if (briefingFolderRes.files == null || briefingFolderRes.files!.isEmpty) {
        debugPrint('📁 Pasta Briefing não encontrada, nada a renomear');
        return;
      }

      final briefingFolderId = briefingFolderRes.files!.first.id!;

      // Buscar todas as imagens dentro da pasta Briefing que começam com "Briefing-{oldTaskName}_"
      final oldPrefix = 'Briefing-${_sanitize(oldTaskName)}_';
      final imagesQuery = [
        "mimeType contains 'image/'",
        "'${_escape(briefingFolderId)}' in parents",
        "name contains '${_escape(oldPrefix)}'",
        'trashed = false',
      ].join(' and ');

      final imagesRes = await api.files.list(
        q: imagesQuery,
        $fields: 'files(id,name)',
      );

      if (imagesRes.files == null || imagesRes.files!.isEmpty) {
        debugPrint('📷 Nenhuma imagem do briefing encontrada para renomear');
        return;
      }

      // Renomear cada imagem
      int renamedCount = 0;
      for (final image in imagesRes.files!) {
        final oldName = image.name!;

        // Substituir o nome da tarefa no nome do arquivo
        // Formato: Briefing-OldTaskName_ClientName-ProjectName-01.png
        // Para: Briefing-NewTaskName_ClientName-ProjectName-01.png
        final newName = oldName.replaceFirst(
          'Briefing-${_sanitize(oldTaskName)}_',
          'Briefing-${_sanitize(newTaskName)}_',
        );

        if (newName != oldName) {
          await api.files.update(
            drive.File()..name = newName,
            image.id!,
          );
          debugPrint('  📷 Imagem renomeada: $oldName -> $newName');
          renamedCount++;
        }
      }

      if (renamedCount > 0) {
        debugPrint('✅ $renamedCount imagem(ns) do briefing renomeada(s)');
      }
    } catch (e) {
      debugPrint('⚠️ Erro ao renomear imagens do briefing (ignorado): $e');
    }
  }

  /// Ensure subtask folder exists inside parent task folder
  /// Structure: .../Task/Subtask/{SubTaskName}/
  Future<String> ensureSubTaskFolder(
    auth.AuthClient client,
    String clientName,
    String projectName,
    String taskName,
    String subTaskName, {
    String? companyName,
    String? organizationName,
  }) async {
    final orgName = _getOrganizationName(organizationName);
    final api = await _drive(client);

    // Primeiro, garantir que a pasta da tarefa principal existe
    final taskFolderId = companyName != null && companyName.isNotEmpty
        ? await ensureTaskFolderWithCompany(client, clientName, companyName, projectName, taskName, organizationName: orgName)
        : await ensureTaskFolder(client, clientName, projectName, taskName, organizationName: orgName);

    // Criar/buscar a pasta "Subtask" dentro da pasta da tarefa
    final subtaskContainerId = await _findOrCreateFolder(api, 'Subtask', parentId: taskFolderId);

    // Agora criar/buscar a pasta da subtarefa dentro da pasta "Subtask"
    final subTaskBase = _sanitize(subTaskName);
    final q = [
      "mimeType = 'application/vnd.google-apps.folder'",
      "name = '${_escape(subTaskBase)}'",
      "'${_escape(subtaskContainerId)}' in parents",
      'trashed = false',
    ].join(' and ');

    final res = await api.files.list(q: q, $fields: 'files(id,name)');
    if (res.files != null && res.files!.isNotEmpty) {
      return res.files!.first.id!;
    }

    return _findOrCreateFolder(api, subTaskBase, parentId: subtaskContainerId);
  }

  /// Upload file to subtask subfolder (Assets, Briefing, or Comentarios)
  Future<UploadedDriveFile> uploadToSubTaskSubfolder({
    required auth.AuthClient client,
    required String clientName,
    required String projectName,
    required String taskName,
    required String subTaskName,
    required String subfolderName,
    required String filename,
    required List<int> bytes,
    String? mimeType,
    String? companyName,
  }) async {
    final api = await _drive(client);
    final subTaskFolder = await ensureSubTaskFolder(
      client,
      clientName,
      projectName,
      taskName,
      subTaskName,
      companyName: companyName,
    );

    // Create/find subfolder (Assets, Briefing, or Comentarios)
    final subfolderId = await _findOrCreateFolder(api, subfolderName, parentId: subTaskFolder);

    final file = drive.File()
      ..name = filename
      ..parents = [subfolderId];

    final media = drive.Media(Stream.value(bytes), bytes.length);
    final uploaded = await api.files.create(file, uploadMedia: media);

    // Make file publicly readable
    await api.permissions.create(
      drive.Permission()
        ..type = 'anyone'
        ..role = 'reader',
      uploaded.id!,
    );

    final publicUrl = 'https://drive.google.com/uc?export=view&id=${uploaded.id}';
    return UploadedDriveFile(
      id: uploaded.id!,
      publicViewUrl: publicUrl,
      thumbnailLink: uploaded.thumbnailLink,
    );
  }

  /// Delete subtask folder from Google Drive
  /// Structure: .../Task/Subtask/{SubTaskName}/
  Future<void> deleteSubTaskFolder({
    required auth.AuthClient client,
    required String clientName,
    required String projectName,
    required String taskName,
    required String subTaskName,
    String? companyName,
  }) async {
    try {
      final api = await _drive(client);

      Future<String?> findFolder(String name, {String? parentId}) async {
        final q = [
          "mimeType = 'application/vnd.google-apps.folder'",
          "name = '${_escape(_sanitize(name))}'",
          if (parentId != null) "'${_escape(parentId)}' in parents",
          'trashed = false',
        ].join(' and ');
        final res = await api.files.list(q: q, $fields: 'files(id,name)');
        if (res.files != null && res.files!.isNotEmpty) return res.files!.first.id!;
        return null;
      }

      final rootId = await findFolder('Gestor de Projetos');
      if (rootId == null) return;

      final clientsId = await findFolder('Clientes', parentId: rootId);
      if (clientsId == null) return;

      final clientId = await findFolder(clientName, parentId: clientsId);
      if (clientId == null) return;

      String? parentId = clientId;

      if (companyName != null && companyName.isNotEmpty) {
        final companyId = await findFolder(companyName, parentId: clientId);
        if (companyId == null) return;
        parentId = companyId;
      }

      final projectId = await findFolder(projectName, parentId: parentId);
      if (projectId == null) return;

      // Buscar a pasta da tarefa principal (pode ter ✅)
      final taskBase = _sanitize(taskName);
      final taskWithCheck = '$taskBase ✅';
      final taskQuery = [
        "mimeType = 'application/vnd.google-apps.folder'",
        "'${_escape(projectId)}' in parents",
        "(name = '${_escape(taskBase)}' or name = '${_escape(taskWithCheck)}')",
        'trashed = false',
      ].join(' and ');
      final taskRes = await api.files.list(q: taskQuery, $fields: 'files(id,name)');
      if (taskRes.files == null || taskRes.files!.isEmpty) return;

      final taskId = taskRes.files!.first.id!;

      // Buscar a pasta "Subtask" dentro da pasta da tarefa
      final subtaskContainerId = await findFolder('Subtask', parentId: taskId);
      if (subtaskContainerId == null) {
        debugPrint('Drive delete: Subtask folder not found');
        return;
      }

      // Buscar a pasta da subtarefa dentro da pasta "Subtask"
      final subTaskId = await findFolder(subTaskName, parentId: subtaskContainerId);
      if (subTaskId == null) {
        debugPrint('Drive delete: subtask folder not found: $subTaskName');
        return;
      }

      await api.files.delete(subTaskId);
      debugPrint('✅ Pasta da subtarefa deletada do Google Drive: $subTaskName');
    } catch (e) {
      debugPrint('⚠️ Erro ao deletar pasta da subtarefa no Google Drive (ignorado): $e');
    }
  }

  /// Rename a subtask folder in Google Drive
  /// Structure: .../Task/Subtask/{SubTaskName}/
  Future<void> renameSubTaskFolder({
    required auth.AuthClient client,
    required String clientName,
    required String projectName,
    required String taskName,
    required String oldSubTaskName,
    required String newSubTaskName,
    String? companyName,
  }) async {
    try {
      final api = await _drive(client);

      Future<String?> findFolder(String name, {String? parentId}) async {
        final q = [
          "mimeType = 'application/vnd.google-apps.folder'",
          "name = '${_escape(_sanitize(name))}'",
          if (parentId != null) "'${_escape(parentId)}' in parents",
          'trashed = false',
        ].join(' and ');
        final res = await api.files.list(q: q, $fields: 'files(id,name)');
        if (res.files != null && res.files!.isNotEmpty) return res.files!.first.id!;
        return null;
      }

      final rootId = await findFolder('Gestor de Projetos');
      if (rootId == null) {
        debugPrint('Drive rename: root folder not found');
        return;
      }
      final clientsId = await findFolder('Clientes', parentId: rootId);
      if (clientsId == null) {
        debugPrint('Drive rename: Clientes folder not found');
        return;
      }
      final clientId = await findFolder(clientName, parentId: clientsId);
      if (clientId == null) {
        debugPrint('Drive rename: client folder not found');
        return;
      }

      String? parentId = clientId;

      if (companyName != null && companyName.isNotEmpty) {
        final companyId = await findFolder(companyName, parentId: clientId);
        if (companyId == null) {
          debugPrint('Drive rename: company folder not found');
          return;
        }
        parentId = companyId;
      }

      final projectId = await findFolder(projectName, parentId: parentId);
      if (projectId == null) {
        debugPrint('Drive rename: project folder not found');
        return;
      }

      // Buscar a pasta da tarefa principal (pode ter ✅)
      final taskBase = _sanitize(taskName);
      final taskWithCheck = '$taskBase ✅';
      final taskQuery = [
        "mimeType = 'application/vnd.google-apps.folder'",
        "'${_escape(projectId)}' in parents",
        "(name = '${_escape(taskBase)}' or name = '${_escape(taskWithCheck)}')",
        'trashed = false',
      ].join(' and ');
      final taskRes = await api.files.list(q: taskQuery, $fields: 'files(id,name)');
      if (taskRes.files == null || taskRes.files!.isEmpty) {
        debugPrint('Drive rename: task folder not found');
        return;
      }

      final taskId = taskRes.files!.first.id!;

      // Buscar a pasta "Subtask" dentro da pasta da tarefa
      final subtaskContainerId = await findFolder('Subtask', parentId: taskId);
      if (subtaskContainerId == null) {
        debugPrint('Drive rename: Subtask folder not found');
        return;
      }

      // Buscar a pasta da subtarefa dentro da pasta "Subtask"
      final subTaskId = await findFolder(oldSubTaskName, parentId: subtaskContainerId);
      if (subTaskId == null) {
        debugPrint('Drive rename: subtask folder not found: $oldSubTaskName');
        return;
      }

      // Renomear a pasta da subtarefa
      await api.files.update(
        drive.File()..name = _sanitize(newSubTaskName),
        subTaskId,
      );
      debugPrint('✅ Pasta da subtarefa renomeada no Google Drive: $oldSubTaskName -> $newSubTaskName');
    } catch (e) {
      debugPrint('⚠️ Erro ao renomear pasta da subtarefa no Google Drive: $e');
    }
  }

  /// Verifica se existe token compartilhado para a organização
  Future<bool> hasSharedToken(String organizationId) async {
    return await OAuthTokenStore.hasSharedToken('google', organizationId);
  }

  /// Obtém informações sobre o token compartilhado da organização (quem conectou, quando, etc.)
  Future<Map<String, dynamic>?> getSharedTokenInfo(String organizationId) async {
    return await OAuthTokenStore.getSharedToken('google', organizationId);
  }

  /// Remove token compartilhado da organização (apenas admin/gestor)
  Future<void> disconnectShared(String organizationId) async {
    await OAuthTokenStore.removeSharedToken('google', organizationId);
  }
}

class UploadedDriveFile {
  final String id;
  final String? publicViewUrl; // use https://drive.google.com/uc?export=view&id=FILE_ID
  final String? thumbnailLink;
  UploadedDriveFile({required this.id, this.publicViewUrl, this.thumbnailLink});
}
