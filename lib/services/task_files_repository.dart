import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class TaskFilesRepository {
  final SupabaseClient _client = Supabase.instance.client;

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
    debugPrint('🟢 [TaskFilesRepo] saveFile INICIADO');
    debugPrint('   📋 Task ID: $taskId');
    debugPrint('   📄 Filename: $filename');
    debugPrint('   📦 Size: $sizeBytes bytes');
    debugPrint('   🏷️ Category: $category');

    final user = Supabase.instance.client.auth.currentUser;
    debugPrint('   👤 User ID: ${user?.id}');

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

    debugPrint('🟢 [TaskFilesRepo] Inserindo no Supabase...');
    try {
      await _client.from('task_files').insert(data);
      debugPrint('✅ [TaskFilesRepo] Arquivo salvo com sucesso no banco');
    } catch (e) {
      debugPrint('❌ [TaskFilesRepo] Erro ao inserir: $e');
      final msg = e.toString();
      final looksLikeMissingCols =
          msg.contains("PGRST204") ||
          msg.contains("'category' column") ||
          msg.contains('category') ||
          msg.contains('comment_id');
      if (looksLikeMissingCols) {
        debugPrint('⚠️ [TaskFilesRepo] Coluna ausente detectada, tentando fallback...');
        debugPrint('task_files: coluna ausente (category/comment_id). Aplicar migração. Tentando salvar sem essas colunas. Erro: $msg');
        final fallback = Map<String, dynamic>.from(data)
          ..remove('category')
          ..remove('comment_id');
        await _client.from('task_files').insert(fallback);
        debugPrint('✅ [TaskFilesRepo] Arquivo salvo com fallback (sem category/comment_id)');
      } else {
        debugPrint('❌ [TaskFilesRepo] Erro não relacionado a colunas, relançando...');
        rethrow;
      }
    }
    debugPrint('✅ [TaskFilesRepo] saveFile CONCLUÍDO');
  }

  Future<List<Map<String, dynamic>>> listByTask(String taskId) async {
    try {
      final res = await _client
          .from('task_files')
          .select('id, filename, mime_type, size_bytes, drive_file_id, drive_file_url, category, comment_id, created_by, created_at')
          .eq('task_id', taskId)
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(res);
    } catch (e) {
      final msg = e.toString();
      final looksLikeMissingCols = msg.contains('category') || msg.contains('comment_id') || msg.contains('PGRST204');
      if (looksLikeMissingCols) {
        debugPrint('task_files: coluna ausente ao listar. Fallback sem category/comment_id. Erro: $msg');
        final res = await _client
            .from('task_files')
            .select('id, filename, mime_type, size_bytes, drive_file_id, drive_file_url, created_by, created_at')
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
          .select('id, filename, mime_type, size_bytes, drive_file_id, drive_file_url, category, comment_id, created_by, created_at')
          .eq('comment_id', commentId)
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(res);
    } catch (e) {
      debugPrint('❌ Erro ao listar arquivos do comentário: $e');
      return [];
    }
  }

  /// Returns only files that belong to the generic Assets section.
  /// Rules:
  /// - include rows where category is NULL (legacy) or category == 'assets'
  /// - exclude 'briefing', 'comment', 'final' and any other explicit categories
  Future<List<Map<String, dynamic>>> listAssetsByTask(String taskId) async {
    try {
      final res = await _client
          .from('task_files')
          .select('id, filename, mime_type, size_bytes, drive_file_id, drive_file_url, category, comment_id, created_by, created_at')
          .eq('task_id', taskId)
          .or('category.is.null,category.eq.assets')
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(res);
    } catch (e) {
      // Fallback for environments without the category column
      debugPrint('listAssetsByTask fallback (maybe missing category column): $e');
      return await listByTask(taskId);
    }
  }

  /// Returns only files that belong to the Final Project section.
  Future<List<Map<String, dynamic>>> listFinalByTask(String taskId) async {
    try {
      final res = await _client
          .from('task_files')
          .select('id, filename, mime_type, size_bytes, drive_file_id, drive_file_url, category, comment_id, created_by, created_at')
          .eq('task_id', taskId)
          .eq('category', 'final')
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(res);
    } catch (e) {
      debugPrint('listFinalByTask error: $e');
      return [];
    }
  }

  Future<void> delete(String id) async {
    await _client.from('task_files').delete().eq('id', id);
  }
}

