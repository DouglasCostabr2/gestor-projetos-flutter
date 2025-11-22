import 'dart:async';
import 'dart:convert' as convert;
import 'dart:io';

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
      await _client.from('user_oauth_tokens').upsert(payload, onConflict: 'user_id');
    } catch (e) {
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
        rethrow;
      }
    }
  }

  static Future<Map<String, dynamic>?> getToken(String provider) async {
    final user = authModule.currentUser;
    if (user == null) {
      return null;
    }
    try {
      final res = await _client
          .from('user_oauth_tokens')
          .select('*')
          .eq('user_id', user.id)
          .eq('provider', provider)
          .maybeSingle();
      if (res != null) {
      }
      return res;
    } catch (e) {
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
      await _client.from('shared_oauth_tokens').upsert(payload, onConflict: 'provider,organization_id');
    } catch (e) {
      rethrow;
    }
  }

  /// Busca token compartilhado da organização
  static Future<Map<String, dynamic>?> getSharedToken(String provider, String organizationId) async {
    try {
      final res = await _client
          .from('shared_oauth_tokens')
          .select('*')
          .eq('provider', provider)
          .eq('organization_id', organizationId)
          .maybeSingle();
      if (res != null) {
      }
      return res;
    } catch (e) {
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
      await _client
          .from('shared_oauth_tokens')
          .delete()
          .eq('provider', provider)
          .eq('organization_id', organizationId);
    } catch (e) {
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

    // Obter organization_id do contexto
    final organizationId = OrganizationContext.currentOrganizationId;

    if (organizationId != null) {
      // 1. Tentar token compartilhado da organização primeiro
      final sharedToken = await OAuthTokenStore.getSharedToken('google', organizationId);
      if (sharedToken != null && sharedToken['refresh_token'] != null) {
        final refreshToken = sharedToken['refresh_token'] as String;
        final creds = auth.AccessCredentials(
          auth.AccessToken('Bearer', sharedToken['access_token'] ?? '', DateTime.now().toUtc().subtract(const Duration(minutes: 1))),
          refreshToken,
          GoogleOAuthConfig.scopes,
        );

        final base = http.Client();
        try {
          final refreshed = await auth.refreshCredentials(_clientId, creds, base);
          // Atualizar token compartilhado
          await OAuthTokenStore.upsertSharedToken(
            provider: 'google',
            organizationId: organizationId,
            refreshToken: refreshToken,
            accessToken: refreshed.accessToken.data,
            expiry: refreshed.accessToken.expiry,
          );
          return auth.authenticatedClient(base, refreshed);
        } catch (e) {
          base.close();
          throw ConsentRequired();
        }
      } else {
      }
    } else {
      throw ConsentRequired();
    }



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
      // Prosseguimos mesmo assim; o usuário pode copiar/colar manualmente a URL.
    } else {
    }

    String? authCode;
    String? authError;

    try {
      await for (final req in server) {
        final qp = req.uri.queryParameters;
        authCode = qp['code'];
        authError = qp['error'];
        // Respond to browser
        req.response.statusCode = 200;
        req.response.headers.set('Content-Type', 'text/html; charset=utf-8');
        req.response.write('<html><body><h3>Autorização recebida. Você pode fechar esta janela.</h3></body></html>');
        await req.response.close();
        break;
      }
    } finally {
      await server.close(force: true);
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

    if (tokenRes.statusCode != 200) {
      throw Exception('Falha ao trocar código por tokens: ${tokenRes.statusCode} ${tokenRes.body}');
    }

    final data = tokenRes.body;
    final map = convert.jsonDecode(data) as Map<String, dynamic>;
    final accessToken = map['access_token'] as String;
    final expiresIn = (map['expires_in'] as num?)?.toInt() ?? 3600;
    final refreshToken = (map['refresh_token'] as String?) ?? '';

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
      // Ignorar erro (operação não crítica)
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

    final api = await _drive(client);

    final taskFolder = await ensureTaskFolder(client, clientName, projectName, taskName, organizationName: organizationName);

    final file = drive.File()
      ..name = filename
      ..parents = [taskFolder];

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
      // Ignorar erro (operação não crítica)
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

    final taskFolder = companyName != null && companyName.isNotEmpty
        ? await ensureTaskFolderWithCompany(client, clientName, companyName, projectName, taskName, organizationName: organizationName)
        : await ensureTaskFolder(client, clientName, projectName, taskName, organizationName: organizationName);
    final contentType = mimeType ?? mime.lookupMimeType(filename) ?? 'application/octet-stream';

    // PASSO 1: Iniciar sessão de upload resumable
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


    // PASSO 2: Enviar arquivo em chunks
    // Usar chunks de 10 MB para upload suave sem travar a UI
    const chunkSize = 10 * 1024 * 1024; // 10 MB por chunk
    int uploadedBytes = 0;


    while (uploadedBytes < bytes.length) {
      final end = (uploadedBytes + chunkSize < bytes.length)
          ? uploadedBytes + chunkSize
          : bytes.length;

      final chunk = bytes.sublist(uploadedBytes, end);
      final contentRange = 'bytes $uploadedBytes-${end - 1}/${bytes.length}';


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

        // Delay mínimo para permitir que a UI atualize
        await Future.delayed(const Duration(milliseconds: 1));
      } else if (chunkResponse.statusCode == 200 || chunkResponse.statusCode == 201) {
        // Upload completo!
        uploadedBytes = bytes.length;
        onProgress(1.0);

        final fileData = convert.jsonDecode(chunkResponse.body);
        final fileId = fileData['id'] as String;

        // PASSO 3: Tornar arquivo público
        try {
          final api = await _drive(client);
          await api.permissions.create(
            drive.Permission()
              ..type = 'anyone'
              ..role = 'reader',
            fileId,
          );
        } catch (e) {
          // Ignorar erro (operação não crítica)
        }

        // PASSO 4: Obter metadados
        final api = await _drive(client);
        final file = await api.files.get(fileId, $fields: 'id,thumbnailLink') as drive.File;
        final publicViewUrl = Uri.https('drive.google.com', '/uc', {'export': 'view', 'id': fileId}).toString();

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
      // Ignorar erro (operação não crítica)
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
    String? organizationName,
  }) async {
    final api = await _drive(client);
    final folderId = await ensureProjectSubfolder(client, clientName, projectName, subfolderName, companyName: companyName, organizationName: organizationName);

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
      // Ignorar erro (operação não crítica)
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
      // Ignorar erro (operação não crítica)
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
      // Ignorar erro (operação não crítica)
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


    // PASSO 2: Enviar arquivo em chunks
    // Usar chunks de 10 MB para upload suave sem travar a UI
    const chunkSize = 10 * 1024 * 1024; // 10 MB por chunk
    int uploadedBytes = 0;


    while (uploadedBytes < bytes.length) {
      final end = (uploadedBytes + chunkSize < bytes.length)
          ? uploadedBytes + chunkSize
          : bytes.length;

      final chunk = bytes.sublist(uploadedBytes, end);
      final contentRange = 'bytes $uploadedBytes-${end - 1}/${bytes.length}';


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

        // Delay mínimo para permitir que a UI atualize
        await Future.delayed(const Duration(milliseconds: 1));
      } else if (chunkResponse.statusCode == 200 || chunkResponse.statusCode == 201) {
        // Upload completo!
        uploadedBytes = bytes.length;
        onProgress?.call(1.0);

        final fileData = convert.jsonDecode(chunkResponse.body);
        final fileId = fileData['id'] as String;

        // PASSO 3: Tornar arquivo público
        try {
          final api = await _drive(client);
          await api.permissions.create(
            drive.Permission()
              ..type = 'anyone'
              ..role = 'reader',
            fileId,
          );
        } catch (e) {
          // Ignorar erro (operação não crítica)
        }

        // PASSO 4: Obter metadados
        final api = await _drive(client);
        final file = await api.files.get(fileId, $fields: 'id,thumbnailLink') as drive.File;
        final publicViewUrl = Uri.https('drive.google.com', '/uc', {'export': 'view', 'id': fileId}).toString();

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

  /// Busca um arquivo em uma subpasta do projeto
  /// Retorna o file ID se encontrado, null caso contrário
  Future<String?> findFileInProjectSubfolder({
    required auth.AuthClient client,
    required String clientName,
    required String projectName,
    required String subfolderName,
    required String filename,
    String? companyName,
  }) async {
    try {
      final api = await _drive(client);

      // Função auxiliar para buscar pasta
      Future<String?> findFolder(String name, {String? parentId}) async {
        final q = [
          "mimeType='application/vnd.google-apps.folder'",
          "name='$name'",
          "trashed=false",
          if (parentId != null) "'$parentId' in parents",
        ].join(' and ');

        final result = await api.files.list(q: q, spaces: 'drive', $fields: 'files(id, name)');
        return result.files?.isNotEmpty == true ? result.files!.first.id : null;
      }

      // Navegar pela estrutura de pastas
      final orgName = _getOrganizationName(null);
      final clientsFolderId = await ensureClientsFolder(client, organizationName: orgName);
      final clientFolderId = await findFolder(clientName, parentId: clientsFolderId);

      if (clientFolderId == null) {
        return null;
      }

      String? projectParentId = clientFolderId;

      // Se tiver empresa, buscar pasta da empresa
      if (companyName != null && companyName.isNotEmpty) {
        final companyFolderId = await findFolder(companyName, parentId: clientFolderId);
        if (companyFolderId == null) {
          return null;
        }
        projectParentId = companyFolderId;
      }

      // Buscar pasta do projeto
      final projectFolderId = await findFolder(projectName, parentId: projectParentId);
      if (projectFolderId == null) {
        return null;
      }

      // Buscar subpasta (ex: "Invoices")
      final subfolderId = await findFolder(subfolderName, parentId: projectFolderId);
      if (subfolderId == null) {
        return null;
      }

      // Buscar arquivo na subpasta
      final q = [
        "name='$filename'",
        "trashed=false",
        "'$subfolderId' in parents",
      ].join(' and ');

      final result = await api.files.list(q: q, spaces: 'drive', $fields: 'files(id, name)');

      if (result.files?.isNotEmpty == true) {
        return result.files!.first.id;
      }

      return null;
    } catch (e) {
      return null;
    }
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
        return;
      }
      final clientsId = await findFolder('Clientes', parentId: rootId);
      if (clientsId == null) {
        return;
      }
      final clientId = await findFolder(clientName, parentId: clientsId);
      if (clientId == null) {
        return;
      }

      String? parentId = clientId;

      // Se tem empresa, buscar a pasta da empresa
      if (companyName != null && companyName.isNotEmpty) {
        final companyId = await findFolder(companyName, parentId: clientId);
        if (companyId == null) {
          return;
        }
        parentId = companyId;
      }

      final projectId = await findFolder(projectName, parentId: parentId);
      if (projectId == null) {
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
        return;
      }

      await api.files.delete(taskFolderId);
    } catch (e) {
      // Ignorar erro (operação não crítica)
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
        return;
      }
      final clientId = await findFolder(clientName, parentId: rootId);
      if (clientId == null) {
        return;
      }
      final projectId = await findFolder(projectName, parentId: clientId);
      if (projectId == null) {
        return;
      }

      // Delete the entire project folder (this deletes all contents recursively)
      await api.files.delete(projectId);
    } catch (e) {
      // Ignorar erro (operação não crítica)
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
        return;
      }
      final clientsId = await findFolder('Clientes', parentId: rootId);
      if (clientsId == null) {
        return;
      }
      final clientId = await findFolder(clientName, parentId: clientsId);
      if (clientId == null) {
        return;
      }

      // Delete the entire client folder (this deletes all contents recursively)
      await api.files.delete(clientId);
    } catch (e) {
      // Ignorar erro (operação não crítica)
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
        return;
      }
      final clientsId = await findFolder('Clientes', parentId: rootId);
      if (clientsId == null) {
        return;
      }
      final clientId = await findFolder(clientName, parentId: clientsId);
      if (clientId == null) {
        return;
      }
      final companyId = await findFolder(companyName, parentId: clientId);
      if (companyId == null) {
        return;
      }

      // Delete the entire company folder (this deletes all contents recursively)
      await api.files.delete(companyId);
    } catch (e) {
      // Ignorar erro (operação não crítica)
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
        await api.files.delete(orgFolderId);
      } else {
      }
    } catch (e) {
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
        return;
      }
      final clientsId = await findFolder('Clientes', parentId: rootId);
      if (clientsId == null) {
        return;
      }
      final clientId = await findFolder(oldClientName, parentId: clientsId);
      if (clientId == null) {
        return;
      }

      // Rename the folder
      await api.files.update(
        drive.File()..name = _sanitize(newClientName),
        clientId,
      );
    } catch (e) {
      // Ignorar erro (operação não crítica)
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
        return;
      }
      final clientsId = await findFolder('Clientes', parentId: rootId);
      if (clientsId == null) {
        return;
      }
      final clientId = await findFolder(clientName, parentId: clientsId);
      if (clientId == null) {
        return;
      }
      final companyId = await findFolder(oldCompanyName, parentId: clientId);
      if (companyId == null) {
        return;
      }

      // Rename the folder
      await api.files.update(
        drive.File()..name = _sanitize(newCompanyName),
        companyId,
      );
    } catch (e) {
      // Ignorar erro (operação não crítica)
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
        return;
      }
      final clientsId = await findFolder('Clientes', parentId: rootId);
      if (clientsId == null) {
        return;
      }
      final clientId = await findFolder(clientName, parentId: clientsId);
      if (clientId == null) {
        return;
      }

      String? parentId = clientId;

      // Se tem empresa, buscar a pasta da empresa
      if (companyName != null && companyName.isNotEmpty) {
        final companyId = await findFolder(companyName, parentId: clientId);
        if (companyId == null) {
          return;
        }
        parentId = companyId;
      }

      final projectId = await findFolder(oldProjectName, parentId: parentId);
      if (projectId == null) {
        return;
      }

      // Rename the folder
      await api.files.update(
        drive.File()..name = _sanitize(newProjectName),
        projectId,
      );
    } catch (e) {
      // Ignorar erro (operação não crítica)
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
        return;
      }
      final clientsId = await findFolder('Clientes', parentId: rootId);
      if (clientsId == null) {
        return;
      }
      final clientId = await findFolder(clientName, parentId: clientsId);
      if (clientId == null) {
        return;
      }

      String? parentId = clientId;

      // Se tem empresa, buscar a pasta da empresa
      if (companyName != null && companyName.isNotEmpty) {
        final companyId = await findFolder(companyName, parentId: clientId);
        if (companyId == null) {
          return;
        }
        parentId = companyId;
      }

      final projectId = await findFolder(projectName, parentId: parentId);
      if (projectId == null) {
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
      // Ignorar erro (operação não crítica)
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
          renamedCount++;
        }
      }

      if (renamedCount > 0) {
      }
    } catch (e) {
      // Ignorar erro (operação não crítica)
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
        return;
      }

      // Buscar a pasta da subtarefa dentro da pasta "Subtask"
      final subTaskId = await findFolder(subTaskName, parentId: subtaskContainerId);
      if (subTaskId == null) {
        return;
      }

      await api.files.delete(subTaskId);
    } catch (e) {
      // Ignorar erro (operação não crítica)
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
        return;
      }
      final clientsId = await findFolder('Clientes', parentId: rootId);
      if (clientsId == null) {
        return;
      }
      final clientId = await findFolder(clientName, parentId: clientsId);
      if (clientId == null) {
        return;
      }

      String? parentId = clientId;

      if (companyName != null && companyName.isNotEmpty) {
        final companyId = await findFolder(companyName, parentId: clientId);
        if (companyId == null) {
          return;
        }
        parentId = companyId;
      }

      final projectId = await findFolder(projectName, parentId: parentId);
      if (projectId == null) {
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
        return;
      }

      final taskId = taskRes.files!.first.id!;

      // Buscar a pasta "Subtask" dentro da pasta da tarefa
      final subtaskContainerId = await findFolder('Subtask', parentId: taskId);
      if (subtaskContainerId == null) {
        return;
      }

      // Buscar a pasta da subtarefa dentro da pasta "Subtask"
      final subTaskId = await findFolder(oldSubTaskName, parentId: subtaskContainerId);
      if (subTaskId == null) {
        return;
      }

      // Renomear a pasta da subtarefa
      await api.files.update(
        drive.File()..name = _sanitize(newSubTaskName),
        subTaskId,
      );
    } catch (e) {
      // Ignorar erro (operação não crítica)
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

  // ============================================================================
  // DESIGN MATERIALS METHODS
  // ============================================================================

  /// Cria estrutura: Gestor de Projetos/Organizações/{Org}/Clientes/{Cliente}/{Empresa}/Design Materials/
  Future<String> ensureDesignMaterialsFolder(
    auth.AuthClient client,
    String clientName,
    String companyName, {
    String? organizationName,
  }) async {
    final orgName = _getOrganizationName(organizationName);
    final api = await _drive(client);
    final companyId = await ensureCompanyFolder(client, clientName, companyName, organizationName: orgName);
    return _findOrCreateFolder(api, 'Design Materials', parentId: companyId);
  }

  /// Cria uma pasta dentro de Design Materials
  /// Retorna o ID da pasta criada
  Future<String> createDesignMaterialsSubfolder({
    required auth.AuthClient client,
    required String clientName,
    required String companyName,
    required String folderName,
    String? parentFolderId,
    String? organizationName,
  }) async {
    final orgName = _getOrganizationName(organizationName);
    final api = await _drive(client);

    // Se não há parent, usar a pasta raiz de Design Materials
    final parentId = parentFolderId ?? await ensureDesignMaterialsFolder(client, clientName, companyName, organizationName: orgName);

    return _findOrCreateFolder(api, _sanitize(folderName), parentId: parentId);
  }

  /// Renomeia uma pasta de Design Materials no Google Drive
  Future<void> renameDesignMaterialsFolder({
    required auth.AuthClient client,
    required String folderId,
    required String newName,
  }) async {
    try {
      final api = await _drive(client);
      await api.files.update(
        drive.File()..name = _sanitize(newName),
        folderId,
      );
    } catch (e) {
      rethrow;
    }
  }

  /// Faz upload de um arquivo para uma pasta de Design Materials
  /// Usa upload resumable (em chunks) para arquivos grandes - MESMO SISTEMA DOS ASSETS
  Future<UploadedDriveFile> uploadToDesignMaterialsFolder({
    required auth.AuthClient client,
    required String folderId,
    required String filename,
    required List<int> bytes,
    String? mimeType,
    void Function(double progress)? onProgress,
  }) async {

    final contentType = mimeType ?? mime.lookupMimeType(filename) ?? 'application/octet-stream';

    // PASSO 1: Iniciar sessão de upload resumable
    final metadata = {
      'name': filename,
      'parents': [folderId],
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


    // PASSO 2: Enviar arquivo em chunks
    const chunkSize = 10 * 1024 * 1024; // 10 MB por chunk
    int uploadedBytes = 0;


    while (uploadedBytes < bytes.length) {
      final end = (uploadedBytes + chunkSize < bytes.length)
          ? uploadedBytes + chunkSize
          : bytes.length;

      final chunk = bytes.sublist(uploadedBytes, end);
      final contentRange = 'bytes $uploadedBytes-${end - 1}/${bytes.length}';

      final chunkResponse = await http.put(
        Uri.parse(uploadUrl),
        headers: {
          'Content-Type': contentType,
          'Content-Length': chunk.length.toString(),
          'Content-Range': contentRange,
        },
        body: chunk,
      );

      if (chunkResponse.statusCode == 308) {
        // Continuar enviando
        uploadedBytes = end;
        final progress = uploadedBytes / bytes.length;
        onProgress?.call(progress);
        await Future.delayed(const Duration(milliseconds: 1));
      } else if (chunkResponse.statusCode == 200 || chunkResponse.statusCode == 201) {
        // Upload completo!
        uploadedBytes = bytes.length;
        onProgress?.call(1.0);

        final fileData = convert.jsonDecode(chunkResponse.body);
        final fileId = fileData['id'] as String;

        // PASSO 3: Tornar arquivo público
        try {
          final api = await _drive(client);
          await api.permissions.create(
            drive.Permission()
              ..type = 'anyone'
              ..role = 'reader',
            fileId,
          );
        } catch (e) {
          // Ignorar erro (operação não crítica)
        }

        // PASSO 4: Obter metadados
        final api = await _drive(client);
        final file = await api.files.get(fileId, $fields: 'id,thumbnailLink') as drive.File;
        final publicViewUrl = Uri.https('drive.google.com', '/uc', {'export': 'view', 'id': fileId}).toString();

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

  /// Renomeia um arquivo de Design Materials no Google Drive
  Future<void> renameDesignMaterialsFile({
    required auth.AuthClient client,
    required String fileId,
    required String newName,
  }) async {
    try {
      final api = await _drive(client);
      await api.files.update(
        drive.File()..name = newName,
        fileId,
      );
    } catch (e) {
      rethrow;
    }
  }

  /// Deleta uma pasta de Design Materials no Google Drive
  Future<void> deleteDesignMaterialsFolder({
    required auth.AuthClient client,
    required String folderId,
  }) async {
    try {
      final api = await _drive(client);
      await api.files.delete(folderId);
    } catch (e) {
      rethrow;
    }
  }

  /// Deleta um arquivo de Design Materials no Google Drive
  Future<void> deleteDesignMaterialsFile({
    required auth.AuthClient client,
    required String fileId,
  }) async {
    try {
      final api = await _drive(client);
      await api.files.delete(fileId);
    } catch (e) {
      rethrow;
    }
  }
}

class UploadedDriveFile {
  final String id;
  final String? publicViewUrl; // use https://drive.google.com/uc?export=view&id=FILE_ID
  final String? thumbnailLink;
  UploadedDriveFile({required this.id, this.publicViewUrl, this.thumbnailLink});
}
