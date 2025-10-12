import 'package:supabase_flutter/supabase_flutter.dart';
import '../../config/supabase_config.dart';
import '../auth/module.dart';
import 'contract.dart';

/// Implementação do contrato de comentários
class CommentsRepository implements CommentsContract {
  final SupabaseClient _client = SupabaseConfig.client;

  @override
  Future<Map<String, dynamic>> createComment({
    required String taskId,
    required String content,
  }) async {
    final user = authModule.currentUser;
    if (user == null) throw Exception('Usuário não autenticado');
    
    final res = await _client
        .from('task_comments')
        .insert({
          'task_id': taskId,
          'user_id': user.id,
          'content': content.trim(),
        })
        .select()
        .single();
    return Map<String, dynamic>.from(res);
  }

  @override
  Future<List<Map<String, dynamic>>> listByTask(String taskId) async {
    try {
      final res = await _client
          .from('task_comments')
          .select('id, content, user_id, created_at, profiles:user_id(full_name, email, avatar_url)')
          .eq('task_id', taskId)
          .order('created_at', ascending: true);
      return List<Map<String, dynamic>>.from(res);
    } catch (e) {
      // Fallback when relationship is not declared
      final res = await _client
          .from('task_comments')
          .select('id, content, user_id, created_at')
          .eq('task_id', taskId)
          .order('created_at', ascending: true);
      return List<Map<String, dynamic>>.from(res);
    }
  }

  @override
  Future<Map<String, dynamic>> updateComment({
    required String commentId,
    required String content,
  }) async {
    final res = await _client
        .from('task_comments')
        .update({'content': content.trim()})
        .eq('id', commentId)
        .select()
        .single();
    return Map<String, dynamic>.from(res);
  }

  @override
  Future<void> deleteComment(String commentId) async {
    await _client
        .from('task_comments')
        .delete()
        .eq('id', commentId);
  }
}

final CommentsContract commentsModule = CommentsRepository();

