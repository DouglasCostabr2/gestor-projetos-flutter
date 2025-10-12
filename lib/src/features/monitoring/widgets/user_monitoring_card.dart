import 'package:flutter/material.dart';
import '../../../../widgets/user_avatar_name.dart';
import '../../../../widgets/standard_dialog.dart';
import 'task_status_row.dart';
import '../../tasks/task_detail_page.dart';
import '../../../navigation/tab_manager_scope.dart';
import '../../../navigation/tab_item.dart';

/// Card de monitoramento de um usuário
/// Exibe informações sobre tasks e pagamentos
class UserMonitoringCard extends StatelessWidget {
  final Map<String, dynamic> user;
  final String Function(String) getRoleLabel;
  final String Function(int) formatMoney;

  const UserMonitoringCard({
    super.key,
    required this.user,
    required this.getRoleLabel,
    required this.formatMoney,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    // Obter pagamentos por moeda
    final confirmedByCurrency = user['payments_confirmed_by_currency'] as Map<String, int>? ?? {};
    final pendingByCurrency = user['payments_pending_by_currency'] as Map<String, int>? ?? {};

    // Contar tarefas
    final todoCount = user['tasks_todo'] as int;
    final inProgressCount = user['tasks_in_progress'] as int;
    final reviewCount = user['tasks_review'] as int;
    final waitingCount = user['tasks_waiting'] as int;
    final overdueCount = user['tasks_overdue'] as int;
    final completedCount = user['tasks_completed'] as int;

    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header com avatar e nome
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                UserAvatarName(
                  avatarUrl: user['avatar_url'] as String?,
                  name: user['full_name'] as String,
                  size: 24,
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: cs.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    getRoleLabel(user['role'] as String),
                    style: TextStyle(
                      fontSize: 11,
                      color: cs.onPrimaryContainer,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Tarefas
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // A fazer
                TaskStatusRow(
                  icon: Icons.list_alt,
                  iconColor: cs.onSurface,
                  label: 'A fazer',
                  count: todoCount,
                  onTap: todoCount > 0
                      ? () => _showTasksModal(
                            context,
                            'Tarefas a Fazer - ${user['full_name']}',
                            (user['tasks_todo_list'] as List?)?.cast<Map<String, dynamic>>() ?? [],
                          )
                      : null,
                ),
                // Em andamento
                TaskStatusRow(
                  icon: Icons.play_circle_outline,
                  iconColor: cs.onSurface,
                  label: 'Em andamento',
                  count: inProgressCount,
                  onTap: inProgressCount > 0
                      ? () => _showTasksModal(
                            context,
                            'Tarefas em Andamento - ${user['full_name']}',
                            (user['tasks_in_progress_list'] as List?)?.cast<Map<String, dynamic>>() ?? [],
                          )
                      : null,
                ),
                // Em revisão
                TaskStatusRow(
                  icon: Icons.rate_review_outlined,
                  iconColor: cs.primary,
                  label: 'Em revisão',
                  count: reviewCount,
                  countColor: cs.primary,
                  onTap: reviewCount > 0
                      ? () => _showTasksModal(
                            context,
                            'Tarefas em Revisão - ${user['full_name']}',
                            (user['tasks_review_list'] as List?)?.cast<Map<String, dynamic>>() ?? [],
                          )
                      : null,
                ),
                // Aguardando
                TaskStatusRow(
                  icon: Icons.hourglass_empty,
                  iconColor: Colors.orange.shade700,
                  label: 'Aguardando',
                  count: waitingCount,
                  countColor: Colors.orange.shade700,
                  onTap: waitingCount > 0
                      ? () => _showTasksModal(
                            context,
                            'Tarefas Aguardando - ${user['full_name']}',
                            (user['tasks_waiting_list'] as List?)?.cast<Map<String, dynamic>>() ?? [],
                          )
                      : null,
                ),
                // Atrasadas
                TaskStatusRow(
                  icon: Icons.warning_amber_rounded,
                  iconColor: cs.error,
                  label: 'Atrasadas',
                  count: overdueCount,
                  countColor: cs.error,
                  onTap: overdueCount > 0
                      ? () => _showTasksModal(
                            context,
                            'Tarefas Atrasadas - ${user['full_name']}',
                            (user['tasks_overdue_list'] as List?)?.cast<Map<String, dynamic>>() ?? [],
                          )
                      : null,
                ),
                // Cumpridas
                TaskStatusRow(
                  icon: Icons.check_circle_outline,
                  iconColor: cs.tertiary,
                  label: 'Cumpridas',
                  count: completedCount,
                  countColor: cs.tertiary,
                  onTap: completedCount > 0
                      ? () => _showTasksModal(
                            context,
                            'Tarefas Cumpridas - ${user['full_name']}',
                            (user['tasks_completed_list'] as List?)?.cast<Map<String, dynamic>>() ?? [],
                          )
                      : null,
                ),
              ],
            ),
          ),

          // Pagamentos (se houver)
          if (confirmedByCurrency.isNotEmpty || pendingByCurrency.isNotEmpty) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Pagamentos',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 8),
                  // Confirmados
                  if (confirmedByCurrency.isNotEmpty)
                    ...confirmedByCurrency.entries.map((entry) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          children: [
                            Icon(Icons.check_circle, size: 16, color: cs.tertiary),
                            const SizedBox(width: 8),
                            Text('Confirmado (${entry.key}):'),
                            const Spacer(),
                            Text(
                              formatMoney(entry.value),
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: cs.tertiary,
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  // Pendentes
                  if (pendingByCurrency.isNotEmpty)
                    ...pendingByCurrency.entries.map((entry) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          children: [
                            Icon(Icons.pending, size: 16, color: Colors.orange),
                            const SizedBox(width: 8),
                            Text('Pendente (${entry.key}):'),
                            const Spacer(),
                            Text(
                              formatMoney(entry.value),
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                color: Colors.orange,
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showTasksModal(BuildContext context, String title, List<Map<String, dynamic>> tasks) {
    // Capturar TabManager ANTES de abrir o dialog
    final tabManager = TabManagerScope.maybeOf(context);

    showDialog(
      context: context,
      builder: (dialogContext) => StandardDialog(
        title: title,
        width: StandardDialog.widthMedium,
        height: StandardDialog.heightMedium,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Fechar'),
          ),
        ],
        child: tasks.isEmpty
            ? const Center(child: Text('Nenhuma tarefa encontrada'))
            : ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: tasks.length,
                itemBuilder: (listContext, index) {
                  final task = tasks[index];
                  final taskTitle = task['title'] as String? ?? 'Sem título';
                  final taskStatus = task['status'] as String? ?? '';

                  // Ícone baseado no status
                  IconData icon;
                  Color iconColor;
                  switch (taskStatus) {
                    case 'completed':
                      icon = Icons.check_circle;
                      iconColor = Colors.green;
                      break;
                    case 'in_progress':
                      icon = Icons.play_circle;
                      iconColor = Colors.blue;
                      break;
                    case 'waiting':
                      icon = Icons.schedule;
                      iconColor = Colors.orange;
                      break;
                    case 'review':
                      icon = Icons.rate_review;
                      iconColor = Colors.purple;
                      break;
                    default:
                      icon = Icons.circle_outlined;
                      iconColor = Colors.grey;
                  }

                  return ListTile(
                    leading: Icon(icon, color: iconColor),
                    title: Text(taskTitle),
                    subtitle: Text(_getStatusLabel(taskStatus)),
                    trailing: const Icon(Icons.arrow_forward),
                    onTap: () {
                      Navigator.pop(dialogContext);

                      // Usar TabManager capturado ANTES do dialog
                      if (tabManager != null) {
                        final taskId = task['id'] as String;
                        final tabId = 'task_$taskId';

                        // Atualizar a aba atual com os detalhes da tarefa
                        final currentIndex = tabManager.currentIndex;
                        final updatedTab = TabItem(
                          id: tabId,
                          title: taskTitle,
                          icon: Icons.task,
                          page: TaskDetailPage(
                            key: ValueKey('task_$taskId'),
                            taskId: taskId,
                          ),
                          canClose: true,
                        );
                        tabManager.updateTab(currentIndex, updatedTab);
                      } else {
                        // Fallback para navegação tradicional se TabManager não estiver disponível
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => TaskDetailPage(taskId: task['id'] as String),
                          ),
                        );
                      }
                    },
                  );
                },
              ),
      ),
    );
  }

  String _getStatusLabel(String status) {
    switch (status) {
      case 'todo':
        return 'A fazer';
      case 'in_progress':
        return 'Em andamento';
      case 'review':
        return 'Em revisão';
      case 'waiting':
        return 'Aguardando';
      case 'completed':
        return 'Concluída';
      default:
        return status;
    }
  }
}

