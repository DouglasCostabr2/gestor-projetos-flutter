import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'google_drive_oauth_service.dart';

class TaskFilesRepository {
  final SupabaseClient _client = Supabase.instance.client;
  final GoogleDriveOAuthService _driveService = GoogleDriveOAuthService();

  Future<void> saveFile({
    required String taskId,
    required String filename,
    required int sizeBytes,
    required String? mimeType,
    required String driveFileId,
    required String? driveFileUrl,
    String? category, // e.g., 'final', 'briefing', 'assets', 'comment'
    String? commentId,
  }) async {
    final user = Supabase.instance.client.auth.currentUser;

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
      final looksLikeMissingCols = msg.contains("PGRST204") ||
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

  Future<List<Map<String, dynamic>>> listByTask(String taskId) async {
    try {
      final res = await _client
          .from('task_files')
          .select(
              'id, filename, mime_type, size_bytes, drive_file_id, drive_file_url, category, comment_id, created_by, created_at')
          .eq('task_id', taskId)
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(res);
    } catch (e) {
      final msg = e.toString();
      final looksLikeMissingCols = msg.contains('category') ||
          msg.contains('comment_id') ||
          msg.contains('PGRST204');
      if (looksLikeMissingCols) {
        final res = await _client
            .from('task_files')
            .select(
                'id, filename, mime_type, size_bytes, drive_file_id, drive_file_url, created_by, created_at')
            .eq('task_id', taskId)
            .order('created_at', ascending: false);
        return List<Map<String, dynamic>>.from(res);
      }
      rethrow;
    }
  }

  /// Lista arquivos anexados a um comentário específico
  Future<List<Map<String, dynamic>>> listByComment(String commentId) async {
    try {
      final res = await _client
          .from('task_files')
          .select(
              'id, filename, mime_type, size_bytes, drive_file_id, drive_file_url, category, comment_id, created_by, created_at')
          .eq('comment_id', commentId)
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(res);
    } catch (e) {
      return [];
    }
  }

  /// Returns only files that belong to the generic Assets section.
  /// Rules:
  /// - include rows where category is NULL (legacy) or category == 'assets'
  /// - exclude 'briefing', 'comment', 'final' and any other explicit categories
  /// - adds 'is_from_design_materials' flag by checking if drive_file_id exists in design_files table
  Future<List<Map<String, dynamic>>> listAssetsByTask(String taskId) async {
    try {
      final res = await _client
          .from('task_files')
          .select(
              'id, filename, mime_type, size_bytes, drive_file_id, drive_file_url, category, comment_id, created_by, created_at')
          .eq('task_id', taskId)
          .or('category.is.null,category.eq.assets')
          .order('created_at', ascending: false);

      final files = List<Map<String, dynamic>>.from(res);

      // Get all drive_file_ids to check in a single query
      final driveFileIds = files
          .map((f) => f['drive_file_id'] as String?)
          .where((id) => id != null && id.isNotEmpty)
          .toSet()
          .toList();

      // Check which drive_file_ids exist in design_files (single query)
      Set<String> designMaterialsIds = {};
      if (driveFileIds.isNotEmpty) {
        try {
          final dmFiles = await _client
              .from('design_files')
              .select('drive_file_id')
              .inFilter('drive_file_id', driveFileIds);

          designMaterialsIds = (dmFiles as List)
              .map((f) => f['drive_file_id'] as String)
              .toSet();
        } catch (e) {
          // Ignorar erro (operação não crítica)
        }
      }

      // Mark files that are from Design Materials
      for (final file in files) {
        final driveFileId = file['drive_file_id'] as String?;
        file['is_from_design_materials'] =
            driveFileId != null && designMaterialsIds.contains(driveFileId);
      }

      return files;
    } catch (e) {
      // Fallback for environments without the category column
      return await listByTask(taskId);
    }
  }

  /// Verifica se um arquivo existe no Google Drive
  Future<bool> _fileExistsInDrive(
      http.Client client, String driveFileId) async {
    try {
      final response = await client.get(
        Uri.parse(
            'https://www.googleapis.com/drive/v3/files/$driveFileId?fields=id,trashed'),
      );

      if (response.statusCode == 200) {
        // Arquivo existe, verificar se não está na lixeira
        final data = json.decode(response.body);
        return data['trashed'] != true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  /// Remove registros de arquivos que não existem mais no Google Drive
  Future<void> _cleanOrphanFiles(
      List<Map<String, dynamic>> files, http.Client? client) async {
    if (client == null || files.isEmpty) return;

    final orphanIds = <String>[];

    for (final file in files) {
      final driveFileId = file['drive_file_id'] as String?;
      if (driveFileId != null && driveFileId.isNotEmpty) {
        final exists = await _fileExistsInDrive(client, driveFileId);
        if (!exists) {
          orphanIds.add(file['id'] as String);
        }
      }
    }

    // Remove arquivos órfãos do banco de dados
    for (final id in orphanIds) {
      try {
        await delete(id);
      } catch (e) {
        // Ignora erros de exclusão
      }
    }
  }

  /// Returns only files that belong to the Final Project section.
  /// Validates that files still exist in Google Drive and removes orphan records.
  Future<List<Map<String, dynamic>>> listFinalByTask(String taskId) async {
    try {
      final res = await _client
          .from('task_files')
          .select(
              'id, filename, mime_type, size_bytes, drive_file_id, drive_file_url, category, comment_id, created_by, created_at')
          .eq('task_id', taskId)
          .eq('category', 'final')
          .order('created_at', ascending: false);

      final files = List<Map<String, dynamic>>.from(res);

      // Tenta obter cliente autenticado do Google Drive (silenciosamente)
      http.Client? client;
      try {
        client = await _driveService.getAuthedClient();
      } catch (e) {
        // Se não conseguir autenticar, retorna os arquivos sem validação
        return files;
      }

      // Se chegou aqui, client não é null
      // Valida e limpa arquivos órfãos
      await _cleanOrphanFiles(files, client);

      // Retorna apenas arquivos que ainda existem no Drive
      final validFiles = <Map<String, dynamic>>[];
      for (final file in files) {
        final driveFileId = file['drive_file_id'] as String?;
        if (driveFileId != null && driveFileId.isNotEmpty) {
          final exists = await _fileExistsInDrive(client, driveFileId);
          if (exists) {
            validFiles.add(file);
          }
        }
      }

      return validFiles;
    } catch (e) {
      return [];
    }
  }

  Future<void> delete(String id) async {
    await _client.from('task_files').delete().eq('id', id);
  }
}
