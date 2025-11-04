import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../config/supabase_config.dart';
import '../auth/module.dart';
import 'contract.dart';

/// Implementação do contrato de rastreamento de tempo
/// 
/// IMPORTANTE: Esta classe é INTERNA ao módulo.
/// O mundo externo deve usar apenas o contrato TimeTrackingContract.
class TimeTrackingRepository implements TimeTrackingContract {
  final SupabaseClient _client = SupabaseConfig.client;

  @override
  Future<String> startTimeLog({
    required String taskId,
  }) async {
    final user = authModule.currentUser;
    if (user == null) throw Exception('Usuário não autenticado');

    try {
      // Verificar se o usuário é o responsável pela tarefa
      final task = await _client
          .from('tasks')
          .select('assigned_to, assignee_user_ids')
          .eq('id', taskId)
          .maybeSingle();

      if (task == null) {
        throw Exception('Tarefa não encontrada');
      }

      // Verificar se o usuário é responsável (assigned_to ou assignee_user_ids)
      final isAssignedTo = task['assigned_to'] == user.id;
      final assigneeUserIds = (task['assignee_user_ids'] as List<dynamic>?)?.cast<String>() ?? [];
      final isInAssigneeList = assigneeUserIds.contains(user.id);

      if (!isAssignedTo && !isInAssigneeList) {
        throw Exception('Apenas os responsáveis pela tarefa podem iniciar o cronômetro');
      }

      // Verificar se já existe uma sessão ativa para esta tarefa
      final activeLog = await getActiveTimeLog(taskId: taskId);
      if (activeLog != null) {
        throw Exception('Já existe uma sessão de tempo ativa para esta tarefa');
      }

      // Criar novo time_log
      final response = await _client
          .from('time_logs')
          .insert({
            'task_id': taskId,
            'user_id': user.id,
            'start_time': DateTime.now().toIso8601String(),
          })
          .select()
          .single();

      debugPrint('✅ Time log iniciado: ${response['id']}');
      return response['id'] as String;
    } catch (e) {
      debugPrint('❌ Erro ao iniciar time log: $e');
      rethrow;
    }
  }

  @override
  Future<Map<String, dynamic>> stopTimeLog({
    required String timeLogId,
    String? description,
  }) async {
    final user = authModule.currentUser;
    if (user == null) throw Exception('Usuário não autenticado');

    try {
      // Preparar dados de atualização
      final updateData = <String, dynamic>{
        'end_time': DateTime.now().toIso8601String(),
      };

      // Adicionar descrição se fornecida
      if (description != null && description.trim().isNotEmpty) {
        updateData['description'] = description.trim();
      }

      // Atualizar o time_log com end_time e descrição
      final response = await _client
          .from('time_logs')
          .update(updateData)
          .eq('id', timeLogId)
          .eq('user_id', user.id) // Garantir que só o dono pode parar
          .select()
          .single();

      debugPrint('✅ Time log finalizado: $timeLogId');
      debugPrint('⏱️  Duração: ${response['duration_seconds']} segundos');
      if (description != null && description.trim().isNotEmpty) {
        debugPrint('📝 Descrição: $description');
      }
      return Map<String, dynamic>.from(response);
    } catch (e) {
      debugPrint('❌ Erro ao finalizar time log: $e');
      rethrow;
    }
  }

  @override
  Future<Map<String, dynamic>?> getActiveTimeLog({
    required String taskId,
  }) async {
    final user = authModule.currentUser;
    if (user == null) return null;

    try {
      final response = await _client
          .from('time_logs')
          .select()
          .eq('task_id', taskId)
          .eq('user_id', user.id)
          .isFilter('end_time', null)
          .maybeSingle();

      return response;
    } catch (e) {
      debugPrint('❌ Erro ao buscar time log ativo: $e');
      return null;
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getTaskTimeLogs({
    required String taskId,
  }) async {
    // Evitar join direto (PGRST200). Buscar logs e enriquecer perfis em lote.
    try {
      final response = await _client
          .from('time_logs')
          .select('id, task_id, user_id, start_time, end_time, duration_seconds, description, created_at, updated_at')
          .eq('task_id', taskId)
          .order('start_time', ascending: false);

      final logs = List<Map<String, dynamic>>.from(response);

      // Coletar user_ids distintos
      final userIds = <String>{};
      for (final log in logs) {
        final uid = log['user_id'];
        if (uid is String && uid.isNotEmpty) userIds.add(uid);
      }

      if (userIds.isEmpty) return logs;

      try {
        final profiles = await _client
            .from('profiles')
            .select('id, full_name, email, avatar_url')
            .inFilter('id', userIds.toList());

        final byId = <String, Map<String, dynamic>>{
          for (final p in profiles)
            if (p['id'] is String) (p['id'] as String): Map<String, dynamic>.from(p),
        };

        for (final log in logs) {
          final uid = log['user_id'];
          if (uid is String && byId.containsKey(uid)) {
            log['user'] = byId[uid];
          }
        }
      } catch (e) {
        debugPrint('⚠️ Erro ao enriquecer perfis em time_logs: $e');
      }

      return logs;
    } catch (e) {
      debugPrint('❌ Erro ao buscar time logs da tarefa: $e');
      return [];
    }
  }

  @override
  Future<int> getTotalTimeSpent({
    required String taskId,
  }) async {
    try {
      // Buscar o campo total_time_spent da tarefa
      final response = await _client
          .from('tasks')
          .select('total_time_spent')
          .eq('id', taskId)
          .maybeSingle();

      if (response == null) return 0;
      return response['total_time_spent'] as int? ?? 0;
    } catch (e) {
      debugPrint('❌ Erro ao buscar tempo total: $e');
      return 0;
    }
  }

  @override
  Future<void> deleteTimeLog({
    required String timeLogId,
  }) async {
    final user = authModule.currentUser;
    if (user == null) throw Exception('Usuário não autenticado');

    try {
      await _client
          .from('time_logs')
          .delete()
          .eq('id', timeLogId)
          .eq('user_id', user.id); // Garantir que só o dono pode deletar

      debugPrint('✅ Time log deletado: $timeLogId');
    } catch (e) {
      debugPrint('❌ Erro ao deletar time log: $e');
      rethrow;
    }
  }

  @override
  Future<Map<String, dynamic>> updateTimeLog({
    required String timeLogId,
    DateTime? startTime,
    DateTime? endTime,
    String? description,
  }) async {
    final user = authModule.currentUser;
    if (user == null) throw Exception('Usuário não autenticado');

    try {
      final updateData = <String, dynamic>{};

      if (startTime != null) {
        updateData['start_time'] = startTime.toIso8601String();
      }

      if (endTime != null) {
        updateData['end_time'] = endTime.toIso8601String();
      }

      if (description != null) {
        updateData['description'] = description.trim().isEmpty ? null : description.trim();
      }

      if (updateData.isEmpty) {
        throw Exception('Nenhum campo para atualizar');
      }

      final response = await _client
          .from('time_logs')
          .update(updateData)
          .eq('id', timeLogId)
          .eq('user_id', user.id) // Garantir que só o dono pode atualizar
          .select()
          .single();

      debugPrint('✅ Time log atualizado: $timeLogId');
      return Map<String, dynamic>.from(response);
    } catch (e) {
      debugPrint('❌ Erro ao atualizar time log: $e');
      rethrow;
    }
  }

  @override
  Future<Map<String, dynamic>> getUserTimeStats({
    required String userId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      var query = _client
          .from('time_logs')
          .select('duration_seconds, start_time')
          .eq('user_id', userId)
          .not('duration_seconds', 'is', null);

      if (startDate != null) {
        query = query.gte('start_time', startDate.toIso8601String());
      }

      if (endDate != null) {
        query = query.lte('start_time', endDate.toIso8601String());
      }

      final response = await query;
      final logs = List<Map<String, dynamic>>.from(response);

      if (logs.isEmpty) {
        return {
          'user_id': userId,
          'total_seconds': 0,
          'session_count': 0,
          'average_session_seconds': 0.0,
          'first_session': null,
          'last_session': null,
        };
      }

      final totalSeconds = logs.fold<int>(
        0,
        (sum, log) => sum + (log['duration_seconds'] as int? ?? 0),
      );

      final sessionCount = logs.length;
      final averageSessionSeconds = totalSeconds / sessionCount;

      // Ordenar por start_time para pegar primeira e última sessão
      logs.sort((a, b) {
        final dateA = DateTime.parse(a['start_time'] as String);
        final dateB = DateTime.parse(b['start_time'] as String);
        return dateA.compareTo(dateB);
      });

      return {
        'user_id': userId,
        'total_seconds': totalSeconds,
        'session_count': sessionCount,
        'average_session_seconds': averageSessionSeconds,
        'first_session': logs.first['start_time'],
        'last_session': logs.last['start_time'],
      };
    } catch (e) {
      debugPrint('❌ Erro ao buscar estatísticas de tempo: $e');
      return {
        'user_id': userId,
        'total_seconds': 0,
        'session_count': 0,
        'average_session_seconds': 0.0,
        'first_session': null,
        'last_session': null,
      };
    }
  }
}

/// Instância singleton do repositório de rastreamento de tempo
/// Esta é a ÚNICA instância que deve ser usada em todo o aplicativo
final TimeTrackingContract timeTrackingModule = TimeTrackingRepository();

