import 'package:supabase_flutter/supabase_flutter.dart';

class TaskCommentsRepository {
  final SupabaseClient _client = Supabase.instance.client;

  Future<Map<String, dynamic>> createComment({
    required String taskId,
    required String content,
  }) async {
    final user = _client.auth.currentUser;
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

  Future<List<Map<String, dynamic>>> listByTask(String taskId) async {
    try {
      final res = await _client
          .from('task_comments')
          .select('id, content, user_id, created_at, user_profile:profiles!task_comments_user_id_fkey(full_name, email, avatar_url)')
          .eq('task_id', taskId)
          .order('created_at', ascending: true);
      return List<Map<String, dynamic>>.from(res);
    } catch (e) {
      // Fallback when relationship between task_comments.user_id and profiles is not declared (PGRST200)
      final res = await _client
          .from('task_comments')
          .select('id, content, user_id, created_at')
          .eq('task_id', taskId)
          .order('created_at', ascending: true);
      final list = List<Map<String, dynamic>>.from(res);
      // Enrich with profiles in a second query so UI can still render names
      final ids = list.map((r) => r['user_id']).whereType<String>().toSet().toList();
      if (ids.isNotEmpty) {
        // Some versions of supabase_dart may not expose in_(); use filter with PostgREST 'in' operator
        final inList = ids.map((e) => '"$e"').join(',');
        final profs = await _client
            .from('profiles')
            .select('id, full_name, email, avatar_url')
            .filter('id', 'in', '($inList)');
        final byId = <String, Map<String, dynamic>>{ for (final p in profs) (p['id'] as String): Map<String, dynamic>.from(p) };
        for (final r in list) {
          final uid = r['user_id'] as String?;
          if (uid != null && byId.containsKey(uid)) {
            r['user_profile'] = {
              'full_name': byId[uid]!['full_name'],
              'email': byId[uid]!['email'],
              'avatar_url': byId[uid]!['avatar_url'],
            };
          }
        }
      }
      return list;
    }
  }

  Future<void> deleteComment(String id) async {
    await _client.from('task_comments').delete().eq('id', id);
  }

  Future<void> updateComment({required String id, required String content}) async {
    await _client.from('task_comments').update({'content': content}).eq('id', id);
  }
}

