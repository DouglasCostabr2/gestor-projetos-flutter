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
    final user = authModule.currentUser;
    if (user == null) return null;
    final res = await _client
        .from('user_oauth_tokens')
        .select('*')
        .eq('user_id', user.id)
        .eq('provider', provider)
        .maybeSingle();
    return res;
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
  Future<auth.AuthClient> getAuthedClient() async {
    final stored = await OAuthTokenStore.getToken('google');

    if (stored != null && stored['refresh_token'] != null) {
      final refreshToken = stored['refresh_token'] as String;
      final creds = auth.AccessCredentials(
        auth.AccessToken('Bearer', stored['access_token'] ?? '', DateTime.now().toUtc().subtract(const Duration(minutes: 1))),
        refreshToken,
        GoogleOAuthConfig.scopes,
      );

      final base = http.Client();
      try {
        final refreshed = await auth.refreshCredentials(_clientId, creds, base);
        await OAuthTokenStore.upsertToken(
          provider: 'google',
          refreshToken: refreshToken,
          accessToken: refreshed.accessToken.data,
          expiry: refreshed.accessToken.expiry,
        );
        return auth.authenticatedClient(base, refreshed);
      } catch (e) {
        base.close();
        debugPrint('GDrive OAuth: falha ao renovar token via refresh: $e');
        throw ConsentRequired();
      }
    }

    debugPrint('GDrive OAuth: nenhum token armazenado, solicitando consentimento');
    throw ConsentRequired();
  }

  /// Loopback consent: abre navegador e fica escutando localhost; se falhar abre manualmente
  Future<auth.AuthClient> connectWithLoopback({void Function(Uri url, bool opened)? onAuthUrl}) async {
    if (GoogleOAuthConfig.clientId.isEmpty || GoogleOAuthConfig.clientSecret.isEmpty) {
      throw Exception('Client ID/Secret não configurados (--dart-define)');
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

    await OAuthTokenStore.upsertToken(
      provider: 'google',
      refreshToken: refreshToken,
      accessToken: creds.accessToken.data,
      expiry: creds.accessToken.expiry,
    );
    debugPrint('GDrive OAuth: token salvo no Supabase');

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

  Future<String> ensureRootFolder(auth.AuthClient client) async {
    final api = await _drive(client);
    return _findOrCreateFolder(api, 'Gestor de Projetos');
  }

  Future<String> ensureClientsFolder(auth.AuthClient client) async {
    final api = await _drive(client);
    final rootId = await ensureRootFolder(client);
    return _findOrCreateFolder(api, 'Clientes', parentId: rootId);
  }

  Future<String> ensureClientFolder(auth.AuthClient client, String clientName) async {
    final api = await _drive(client);
    final clientsId = await ensureClientsFolder(client);
    return _findOrCreateFolder(api, _sanitize(clientName), parentId: clientsId);
  }

  Future<String> ensureCompanyFolder(auth.AuthClient client, String clientName, String companyName) async {
    final api = await _drive(client);
    final clientId = await ensureClientFolder(client, clientName);
    return _findOrCreateFolder(api, _sanitize(companyName), parentId: clientId);
  }

  /// Cria estrutura: Gestor de Projetos/{Cliente}/{Projeto}/
  /// Mantido para retrocompatibilidade (projetos sem empresa)
  Future<String> ensureProjectFolder(auth.AuthClient client, String clientName, String projectName) async {
    final api = await _drive(client);
    final clientId = await ensureClientFolder(client, clientName);
    return _findOrCreateFolder(api, _sanitize(projectName), parentId: clientId);
  }

  /// Cria estrutura: Gestor de Projetos/{Cliente}/{Empresa}/{Projeto}/
  /// Use esta função quando o projeto tiver uma empresa associada
  Future<String> ensureProjectFolderWithCompany(auth.AuthClient client, String clientName, String companyName, String projectName) async {
    final api = await _drive(client);
    final companyId = await ensureCompanyFolder(client, clientName, companyName);
    return _findOrCreateFolder(api, _sanitize(projectName), parentId: companyId);
  }

  Future<String> ensureTaskFolder(auth.AuthClient client, String clientName, String projectName, String taskName) async {
    final api = await _drive(client);
    final projectId = await ensureProjectFolder(client, clientName, projectName);
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

  /// Cria estrutura de tarefa com empresa: Gestor de Projetos/{Cliente}/{Empresa}/{Projeto}/{Tarefa}/
  Future<String> ensureTaskFolderWithCompany(auth.AuthClient client, String clientName, String companyName, String projectName, String taskName) async {
    final api = await _drive(client);
    final projectId = await ensureProjectFolderWithCompany(client, clientName, companyName, projectName);
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
  }) async {
    final api = await _drive(client);
    final projectId = await ensureProjectFolder(client, clientName, projectName);
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
  }) async {
    final api = await _drive(client);
    final projectId = await ensureProjectFolder(client, clientName, projectName);
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
  }) async {
    final api = await _drive(client);
    final taskFolder = await ensureTaskFolder(client, clientName, projectName, taskName);

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
  Future<UploadedDriveFile> uploadToProjectFolder({
    required auth.AuthClient client,
    required String clientName,
    required String projectName,
    required String filename,
    required List<int> bytes,
    String? mimeType,
  }) async {
    final api = await _drive(client);
    final projectFolder = await ensureProjectFolder(client, clientName, projectName);

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

  Future<String> ensureProjectSubfolder(auth.AuthClient client, String clientName, String projectName, String subfolderName, {String? companyName}) async {
    final api = await _drive(client);
    final projectId = companyName != null && companyName.isNotEmpty
        ? await ensureProjectFolderWithCompany(client, clientName, companyName, projectName)
        : await ensureProjectFolder(client, clientName, projectName);
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
  }) async {
    final api = await _drive(client);
    final taskFolder = companyName != null && companyName.isNotEmpty
        ? await ensureTaskFolderWithCompany(client, clientName, companyName, projectName, taskName)
        : await ensureTaskFolder(client, clientName, projectName, taskName);
    final sub = _sanitize(subfolderName);
    return _findOrCreateFolder(api, sub, parentId: taskFolder);
  }

  Future<String> ensureAssetsFolder(auth.AuthClient client, String clientName, String projectName, String taskName, {String? companyName}) {
    return ensureTaskSubfolder(client: client, clientName: clientName, projectName: projectName, taskName: taskName, subfolderName: 'Assets', companyName: companyName);
  }

  Future<String> ensureBriefingFolder(auth.AuthClient client, String clientName, String projectName, String taskName, {String? companyName}) {
    return ensureTaskSubfolder(client: client, clientName: clientName, projectName: projectName, taskName: taskName, subfolderName: 'Briefing', companyName: companyName);
  }

  Future<String> ensureCommentsFolder(auth.AuthClient client, String clientName, String projectName, String taskName, {String? companyName}) {
    return ensureTaskSubfolder(client: client, clientName: clientName, projectName: projectName, taskName: taskName, subfolderName: 'Comentarios', companyName: companyName);
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
  }) async {
    final api = await _drive(client);
    final subfolder = await ensureTaskSubfolder(
      client: client,
      clientName: clientName,
      projectName: projectName,
      taskName: taskName,
      subfolderName: subfolderName,
      companyName: companyName,
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
  }) async {
    final api = await _drive(client);

    // Primeiro, garantir que a pasta da tarefa principal existe
    final taskFolderId = companyName != null && companyName.isNotEmpty
        ? await ensureTaskFolderWithCompany(client, clientName, companyName, projectName, taskName)
        : await ensureTaskFolder(client, clientName, projectName, taskName);

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
}

class UploadedDriveFile {
  final String id;
  final String? publicViewUrl; // use https://drive.google.com/uc?export=view&id=FILE_ID
  final String? thumbnailLink;
  UploadedDriveFile({required this.id, this.publicViewUrl, this.thumbnailLink});
}
