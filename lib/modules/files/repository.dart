import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:googleapis_auth/auth_io.dart' as auth;
import 'package:googleapis/drive/v3.dart' as drive;
import '../../config/supabase_config.dart';
import '../../services/google_drive_oauth_service.dart';
import '../auth/module.dart';
import 'contract.dart';

/// Implementação do contrato de arquivos
class FilesRepository implements FilesContract {
  final SupabaseClient _client = SupabaseConfig.client;
  final GoogleDriveOAuthService _driveService = GoogleDriveOAuthService();

  @override
  Future<void> saveFile({
    required String taskId,
    required String filename,
    required int sizeBytes,
    required String? mimeType,
    required String driveFileId,
    required String? driveFileUrl,
    String? category,
    String? commentId,
  }) async {
    final user = authModule.currentUser;
    final data = <String, dynamic>{
      'task_id': taskId,
      'filename': filename,
      'size_bytes': sizeBytes,
      'mime_type': mimeType,
      'drive_file_id': driveFileId,
      'drive_file_url': driveFileUrl,
      'created_by': user?.id,
      if (category != null) 'category': category,
      if (commentId != null) 'comment_id': commentId,
    };

    try {
      await _client.from('task_files').insert(data);
    } catch (e) {
      final msg = e.toString();
      final looksLikeMissingCols =
          msg.contains("PGRST204") ||
          msg.contains("'category' column") ||
          msg.contains('category') ||
          msg.contains('comment_id');
      if (looksLikeMissingCols) {
        final fallback = Map<String, dynamic>.from(data)
          ..remove('category')
          ..remove('comment_id');
        await _client.from('task_files').insert(fallback);
      } else {
        rethrow;
      }
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getTaskFiles(String taskId) async {
    try {
      final response = await _client
          .from('task_files')
          .select('*')
          .eq('task_id', taskId)
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      return [];
    }
  }

  @override
  Future<void> deleteFile(String fileId) async {
    await _client
        .from('task_files')
        .delete()
        .eq('id', fileId);
  }

  @override
  Future<auth.AuthClient?> getGoogleDriveClient() async {
    return await _driveService.getAuthedClient();
  }

  @override
  Future<bool> hasGoogleDriveConnected() async {
    final user = authModule.currentUser;
    if (user == null) return false;

    try {
      final profile = await _client
          .from('profiles')
          .select('google_drive_refresh_token')
          .eq('id', user.id)
          .maybeSingle();

      final token = profile?['google_drive_refresh_token'] as String?;
      return token != null && token.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<void> saveGoogleDriveRefreshToken(String refreshToken) async {
    final user = authModule.currentUser;
    if (user == null) throw Exception('Usuário não autenticado');

    await _client
        .from('profiles')
        .update({'google_drive_refresh_token': refreshToken})
        .eq('id', user.id);
  }

  @override
  Future<void> uploadFilesToDrive({
    required String taskId,
    required String projectName,
    required List<MemoryUploadItem> items,
    required Function(int current, int total) onProgress,
  }) async {
    final client = await getGoogleDriveClient();
    if (client == null) {
      throw Exception('Google Drive não conectado');
    }

    final driveApi = drive.DriveApi(client);
    
    // Criar pasta do projeto se não existir
    final projectFolderId = await _findOrCreateFolder(driveApi, projectName, null);
    
    int current = 0;
    for (final item in items) {
      try {
        // Criar subpasta (Assets, Briefing, etc.)
        final subFolderId = await _findOrCreateFolder(driveApi, item.subfolderName, projectFolderId);
        
        // Upload do arquivo
        final media = drive.Media(Stream.value(item.bytes), item.bytes.length);
        final driveFile = drive.File()
          ..name = item.name
          ..parents = [subFolderId];

        final uploadedFile = await driveApi.files.create(
          driveFile,
          uploadMedia: media,
        );

        // Salvar no banco de dados
        await saveFile(
          taskId: taskId,
          filename: item.name,
          sizeBytes: item.bytes.length,
          mimeType: item.mimeType,
          driveFileId: uploadedFile.id!,
          driveFileUrl: uploadedFile.webViewLink,
          category: item.category,
        );

        current++;
        onProgress(current, items.length);
      } catch (e) {
        rethrow;
      }
    }
  }

  Future<String> _findOrCreateFolder(drive.DriveApi api, String folderName, String? parentId) async {
    // Buscar pasta existente
    final query = parentId != null
        ? "name='$folderName' and '$parentId' in parents and mimeType='application/vnd.google-apps.folder' and trashed=false"
        : "name='$folderName' and mimeType='application/vnd.google-apps.folder' and trashed=false";

    final fileList = await api.files.list(q: query, spaces: 'drive');
    
    if (fileList.files != null && fileList.files!.isNotEmpty) {
      return fileList.files!.first.id!;
    }

    // Criar nova pasta
    final folder = drive.File()
      ..name = folderName
      ..mimeType = 'application/vnd.google-apps.folder';
    
    if (parentId != null) {
      folder.parents = [parentId];
    }

    final createdFolder = await api.files.create(folder);
    return createdFolder.id!;
  }
}

final FilesContract filesModule = FilesRepository();

