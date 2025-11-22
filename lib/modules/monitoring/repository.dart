import 'package:supabase_flutter/supabase_flutter.dart';
import '../../config/supabase_config.dart';
import '../common/organization_context.dart';
import 'contract.dart';

/// Implementação do contrato de monitoramento
class MonitoringRepository implements MonitoringContract {
  final SupabaseClient _client = SupabaseConfig.client;

  @override
  Future<List<Map<String, dynamic>>> fetchMonitoringData() async {
    try {
      // Obter organization_id
      final orgId = OrganizationContext.currentOrganizationId;
      if (orgId == null) {
        return [];
      }


      // 1. Buscar membros ativos da organização usando RPC
      final membersData = await _client.rpc(
        'get_organization_members_with_profiles',
        params: {'org_id': orgId},
      );

      // Transformar para o formato esperado
      final profiles = <Map<String, dynamic>>[];
      for (final member in (membersData as List)) {
        final m = member as Map<String, dynamic>;
        profiles.add({
          'id': m['user_id'],
          'full_name': m['full_name'],
          'email': m['email'],
          'avatar_url': m['avatar_url'],
          'role': m['om_role'], // Usar role do organization_members
        });
      }


      // 2. Buscar TODAS as tasks da organização de uma vez com todos os campos necessários
      final allTasksData = await _client
          .from('tasks')
          .select('id, title, status, assigned_to, created_by, due_date, project_id, priority, description, organization_id')
          .eq('organization_id', orgId);

      // 3. Agregar dados
      final allTasks = List<Map<String, dynamic>>.from(allTasksData);
      final now = DateTime.now();

      for (final profile in profiles) {
        final userId = profile['id'] as String;

        // Contar tasks atribuídas
        final assignedTasks = allTasks.where((t) => t['assigned_to'] == userId).toList();

        // Filtrar tasks por status
        final todoTasks = assignedTasks.where((t) => t['status'] == 'todo').toList();
        final inProgressTasks = assignedTasks.where((t) => t['status'] == 'in_progress').toList();
        final reviewTasks = assignedTasks.where((t) => t['status'] == 'review').toList();
        final waitingTasks = assignedTasks.where((t) => t['status'] == 'waiting').toList();
        final completedTasks = assignedTasks.where((t) => t['status'] == 'completed').toList();

        // Filtrar atrasadas (não concluídas com prazo vencido)
        final overdueTasks = assignedTasks.where((t) {
          if (t['status'] == 'completed') return false;
          final dueDate = t['due_date'];
          if (dueDate == null) return false;
          try {
            return DateTime.parse(dueDate).isBefore(now);
          } catch (e) {
            return false;
          }
        }).toList();

        // Contar tasks criadas
        final createdTasks = allTasks.where((t) => t['created_by'] == userId).toList();
        final createdCount = createdTasks.length;

        profile['assigned_tasks_count'] = assignedTasks.length;
        profile['assigned_tasks_completed'] = completedTasks.length;
        profile['created_tasks_count'] = createdCount;
        profile['tasks_todo'] = todoTasks.length;
        profile['tasks_in_progress'] = inProgressTasks.length;
        profile['tasks_review'] = reviewTasks.length;
        profile['tasks_waiting'] = waitingTasks.length;
        profile['tasks_overdue'] = overdueTasks.length;
        profile['tasks_completed'] = completedTasks.length;

        // Adicionar listas de tarefas para os modais
        profile['tasks_todo_list'] = todoTasks;
        profile['tasks_in_progress_list'] = inProgressTasks;
        profile['tasks_review_list'] = reviewTasks;
        profile['tasks_waiting_list'] = waitingTasks;
        profile['tasks_overdue_list'] = overdueTasks;
        profile['tasks_completed_list'] = completedTasks;

        // Inicializar pagamentos vazios (serão preenchidos se necessário)
        profile['payments_confirmed_by_currency'] = <String, int>{};
        profile['payments_pending_by_currency'] = <String, int>{};
        profile['payments_confirmed_list_by_currency'] = <String, List<Map<String, dynamic>>>{};
        profile['payments_pending_list_by_currency'] = <String, List<Map<String, dynamic>>>{};
      }

      return profiles;
    } catch (e) {
      return [];
    }
  }

  @override
  Future<Map<String, dynamic>> getUserActivities(String userId) async {
    try {
      final assignedTasks = await _client
          .from('tasks')
          .select('*')
          .eq('assigned_to', userId)
          .order('created_at', ascending: false);

      final createdTasks = await _client
          .from('tasks')
          .select('*')
          .eq('created_by', userId)
          .order('created_at', ascending: false);

      return {
        'assigned_tasks': List<Map<String, dynamic>>.from(assignedTasks),
        'created_tasks': List<Map<String, dynamic>>.from(createdTasks),
      };
    } catch (e) {
      return {
        'assigned_tasks': [],
        'created_tasks': [],
      };
    }
  }

  @override
  Future<Map<String, dynamic>> getSystemStatistics() async {
    try {
      final totalUsers = await _client
          .from('profiles')
          .select('id')
          .count(CountOption.exact);

      final totalProjects = await _client
          .from('projects')
          .select('id')
          .count(CountOption.exact);

      final totalTasks = await _client
          .from('tasks')
          .select('id')
          .count(CountOption.exact);

      final completedTasks = await _client
          .from('tasks')
          .select('id')
          .eq('status', 'completed')
          .count(CountOption.exact);

      return {
        'total_users': totalUsers.count,
        'total_projects': totalProjects.count,
        'total_tasks': totalTasks.count,
        'completed_tasks': completedTasks.count,
      };
    } catch (e) {
      return {
        'total_users': 0,
        'total_projects': 0,
        'total_tasks': 0,
        'completed_tasks': 0,
      };
    }
  }

  @override
  List<Map<String, dynamic>> filterByRole(List<Map<String, dynamic>> users, String? role) {
    if (role == null || role.isEmpty || role == 'all') {
      return users;
    }
    return users.where((u) => u['role'] == role).toList();
  }

  @override
  List<Map<String, dynamic>> filterBySearch(List<Map<String, dynamic>> users, String query) {
    if (query.isEmpty) return users;
    final lowerQuery = query.toLowerCase();
    return users.where((u) {
      final name = (u['full_name'] as String? ?? '').toLowerCase();
      final email = (u['email'] as String? ?? '').toLowerCase();
      return name.contains(lowerQuery) || email.contains(lowerQuery);
    }).toList();
  }

  @override
  List<Map<String, dynamic>> sortUsers(List<Map<String, dynamic>> users, String sortBy) {
    final sorted = List<Map<String, dynamic>>.from(users);

    switch (sortBy) {
      case 'name':
        sorted.sort((a, b) => (a['full_name'] as String).compareTo(b['full_name'] as String));
        break;
      case 'pending_tasks':
        sorted.sort((a, b) {
          final aPending = (a['tasks_todo'] as int? ?? 0) + (a['tasks_in_progress'] as int? ?? 0) + (a['tasks_review'] as int? ?? 0);
          final bPending = (b['tasks_todo'] as int? ?? 0) + (b['tasks_in_progress'] as int? ?? 0) + (b['tasks_review'] as int? ?? 0);
          return bPending.compareTo(aPending); // Decrescente
        });
        break;
      case 'completed_tasks':
        sorted.sort((a, b) => (b['tasks_completed'] as int? ?? 0).compareTo(a['tasks_completed'] as int? ?? 0)); // Decrescente
        break;
      default:
        // Manter ordem original
        break;
    }

    return sorted;
  }
}

final MonitoringContract monitoringModule = MonitoringRepository();

