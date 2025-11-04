import 'package:flutter/foundation.dart';
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
    // Estratégia padrão: sem join no PostgREST (evita PGRST200), enriquecer perfis em lote
    try {
      final res = await _client
          .from('task_comments')
          .select('id, content, user_id, created_at, updated_at')
          .eq('task_id', taskId)
          .order('created_at', ascending: true);

      final list = List<Map<String, dynamic>>.from(res);

      // Coletar user_ids distintos
      final userIds = <String>{};
      for (final c in list) {
        final uid = c['user_id'];
        if (uid is String && uid.isNotEmpty) userIds.add(uid);
      }

      if (userIds.isEmpty) return list;

      try {
        final inList = userIds.map((e) => '"$e"').join(',');
        final profilesRes = await _client
            .from('profiles')
            .select('id, full_name, email, avatar_url')
            .filter('id', 'in', '($inList)');
        final profiles = List<Map<String, dynamic>>.from(profilesRes);
        final byId = <String, Map<String, dynamic>>{
          for (final p in profiles)
            if (p['id'] is String) (p['id'] as String): p,
        };
        for (final comment in list) {
          final uid = comment['user_id'];
          if (uid is String && byId.containsKey(uid)) {
            comment['user_profile'] = byId[uid];
          }
        }
      } catch (e) {
        debugPrint('⚠️ [Comments] Erro ao buscar perfis em lote: $e');
      }

      return list;
    } catch (e) {
      debugPrint('❌ [Comments] Falha ao listar comentários: $e');
      return [];
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

