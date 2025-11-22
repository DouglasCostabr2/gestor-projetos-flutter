import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:googleapis_auth/auth_io.dart' as auth;
import '../../shared/quick_forms.dart';
import 'package:my_business/ui/molecules/user_avatar_name.dart';
import 'package:my_business/ui/organisms/dialogs/dialogs.dart';
import '../../../../services/google_drive_oauth_service.dart';
import '../task_detail_page.dart';
import 'task_due_date_badge.dart';
import 'task_status_badge.dart';
import 'package:my_business/ui/atoms/buttons/buttons.dart';
import '../../../../modules/tasks/module.dart';
import '../../../state/app_state_scope.dart';

/// Widget para exibir e gerenciar sub tasks de uma task
class SubTasksSection extends StatefulWidget {
  final String taskId;
  final String taskTitle;
  final String projectId;
  final VoidCallback? onSubTaskChanged;
  final void Function(String subTaskId, String subTaskTitle)? onSubTaskTap;

  const SubTasksSection({
    super.key,
    required this.taskId,
    required this.taskTitle,
    required this.projectId,
    this.onSubTaskChanged,
    this.onSubTaskTap,
  });

  @override
  State<SubTasksSection> createState() => _SubTasksSectionState();
}

class _SubTasksSectionState extends State<SubTasksSection> {
  List<Map<String, dynamic>> _subTasks = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadSubTasks();
  }

  Future<void> _loadSubTasks() async {
    setState(() => _loading = true);
    try {
      // SEGURANÇA: Usar o módulo de tarefas que aplica filtros de acesso
      final res = await tasksModule.getTaskSubTasks(widget.taskId);

      if (mounted) {
        setState(() {
          _subTasks = res;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  bool _canEditSubTask(Map<String, dynamic> subTask) {
    final appState = AppStateScope.of(context);
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    // Admin pode editar qualquer subtask
    // Designers só podem editar subtasks que eles criaram
    // Outros roles podem editar subtasks que criaram
    return appState.isAdmin || subTask['created_by'] == currentUserId;
  }

  bool _canDeleteSubTask(Map<String, dynamic> subTask) {
    final appState = AppStateScope.of(context);
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    // Admin pode deletar qualquer subtask
    // Outros roles podem deletar subtasks que criaram
    return appState.isAdmin || subTask['created_by'] == currentUserId;
  }







  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.subdirectory_arrow_right, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Subtarefas',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Spacer(),
                FilledButton.icon(
                  onPressed: () async {
                    final created = await showDialog<bool>(
                      context: context,
                      builder: (context) => SubTaskFormDialog(
                        projectId: widget.projectId,
                        parentTaskId: widget.taskId,
                        parentTaskTitle: widget.taskTitle,
                      ),
                    );
                    if (created == true) {
                      _loadSubTasks();
                      widget.onSubTaskChanged?.call();
                    }
                  },
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Nova Subtarefa'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_loading)
              const Center(child: CircularProgressIndicator())
            else if (_subTasks.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('Nenhuma subtarefa criada'),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _subTasks.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final subTask = _subTasks[index];
                  final assignee = subTask['assignee_profile'] as Map<String, dynamic>?;
                  final assigneeName = assignee?['full_name'] ?? assignee?['email'] ?? 'Não atribuído';
                  final avatarUrl = assignee?['avatar_url'] as String?;
                  final status = subTask['status'] ?? 'todo';
                  final dueDate = subTask['due_date'];

                  String formattedDate = '-';
                  if (dueDate != null) {
                    try {
                      final dt = DateTime.parse(dueDate);
                      formattedDate = '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
                    } catch (_) {}
                    // Ignorar erro (operação não crítica)
                  }

                  return InkWell(
                    onTap: () {

                      // Usar callback se disponível, senão usar Navigator.push
                      if (widget.onSubTaskTap != null) {
                        final subTaskId = subTask['id'] as String;
                        final subTaskTitle = subTask['title'] as String? ?? 'Subtarefa';
                        widget.onSubTaskTap!(subTaskId, subTaskTitle);
                      } else {
                        // Fallback para navegação tradicional
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => TaskDetailPage(taskId: subTask['id'] as String),
                          ),
                        ).then((_) {
                          _loadSubTasks();
                          widget.onSubTaskChanged?.call();
                        });
                      }
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Row(
                        children: [
                          // Título da sub task
                          Expanded(
                            flex: 3,
                            child: Text(
                              subTask['title'] ?? 'Sem título',
                              style: Theme.of(context).textTheme.bodyMedium,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 16),

                          // Status
                          TaskStatusBadge(status: status),
                          const SizedBox(width: 16),

                          // Indicador de prazo
                          TaskDueDateBadge(
                            dueDate: dueDate,
                            status: status,
                          ),
                          const SizedBox(width: 12),

                          // Data de entrega
                          SizedBox(
                            width: 90,
                            child: Text(
                              formattedDate,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ),
                          const SizedBox(width: 16),

                          // Responsável
                          SizedBox(
                            width: 150,
                            child: UserAvatarName(
                              avatarUrl: avatarUrl,
                              name: assigneeName,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 16),

                          // Botões de ação
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconOnlyButton(
                                icon: Icons.edit,
                                iconSize: 20,
                                tooltip: 'Editar',
                                onPressed: _canEditSubTask(subTask) ? () async {
                                  final changed = await showDialog<bool>(
                                    context: context,
                                    builder: (context) => SubTaskFormDialog(
                                      projectId: widget.projectId,
                                      parentTaskId: widget.taskId,
                                      parentTaskTitle: widget.taskTitle,
                                      initial: subTask,
                                    ),
                                  );
                                  if (changed == true) {
                                    _loadSubTasks();
                                    widget.onSubTaskChanged?.call();
                                  }
                                } : null,
                              ),
                              IconOnlyButton(
                                icon: Icons.delete,
                                iconSize: 20,
                                tooltip: 'Excluir',
                                onPressed: _canDeleteSubTask(subTask) ? () async {
                                  final confirm = await showDialog<bool>(
                                    context: context,
                                    builder: (context) => ConfirmDialog(
                                      title: 'Excluir Subtarefa',
                                      message: 'Tem certeza que deseja excluir esta subtarefa?',
                                      confirmText: 'Excluir',
                                      isDestructive: true,
                                    ),
                                  );
                                  if (confirm == true) {
                                    // Deletar do banco de dados
                                    await Supabase.instance.client
                                        .from('tasks')
                                        .delete()
                                        .eq('id', subTask['id']);

                                    // Deletar pasta do Google Drive (best-effort)
                                    try {
                                      final clientName = (subTask['projects']?['clients']?['name'] ?? 'Cliente').toString();
                                      final projectName = (subTask['projects']?['name'] ?? 'Projeto').toString();
                                      final taskTitle = (subTask['title'] ?? 'Tarefa').toString();
                                      final drive = GoogleDriveOAuthService();
                                      auth.AuthClient? authed;
                                      try { authed = await drive.getAuthedClient(); } catch (_) {}
                                      if (authed != null) {
                                        await drive.deleteTaskFolder(
                                          client: authed,
                                          clientName: clientName,
                                          projectName: projectName,
                                          taskName: taskTitle,
                                        );
                                      } else {
                                      }
                                    } catch (e) {
                                      // Ignorar erro (operação não crítica)
                                    }

                                    // Atualizar status da tarefa pai
                                    try {
                                      await tasksModule.updateTaskStatus(widget.taskId);
                                    } catch (e) {
                                      // Ignorar erro (operação não crítica)
                                    }

                                    _loadSubTasks();
                                    widget.onSubTaskChanged?.call();
                                  }
                                } : null,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

