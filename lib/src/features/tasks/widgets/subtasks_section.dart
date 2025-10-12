import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:googleapis_auth/auth_io.dart' as auth;
import '../../shared/quick_forms.dart';
import '../../../../widgets/user_avatar_name.dart';
import '../../../../widgets/standard_dialog.dart';
import '../../../../services/google_drive_oauth_service.dart';
import '../task_detail_page.dart';
import 'task_due_date_badge.dart';
import 'task_status_badge.dart';
import 'package:gestor_projetos_flutter/widgets/buttons/buttons.dart';
import '../../../../modules/tasks/module.dart';

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
      final res = await Supabase.instance.client
          .from('tasks')
          .select('''
            id, title, status, priority, assigned_to, due_date, created_at, updated_at,
            assignee_profile:profiles!tasks_assigned_to_fkey(full_name, email, avatar_url)
          ''')
          .eq('parent_task_id', widget.taskId)
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _subTasks = List<Map<String, dynamic>>.from(res);
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
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
                  }

                  return InkWell(
                    onTap: () {
                      debugPrint('🔍 SubTasksSection: Clicou na subtask ${subTask['id']}');
                      debugPrint('🔍 SubTasksSection: onSubTaskTap callback = ${widget.onSubTaskTap}');

                      // Usar callback se disponível, senão usar Navigator.push
                      if (widget.onSubTaskTap != null) {
                        debugPrint('🔍 SubTasksSection: Usando callback');
                        final subTaskId = subTask['id'] as String;
                        final subTaskTitle = subTask['title'] as String? ?? 'Subtarefa';
                        debugPrint('🔍 SubTasksSection: Chamando callback com ID=$subTaskId, Title=$subTaskTitle');
                        widget.onSubTaskTap!(subTaskId, subTaskTitle);
                        debugPrint('🔍 SubTasksSection: Callback executado');
                      } else {
                        debugPrint('🔍 SubTasksSection: Usando Navigator.push (fallback)');
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
                                onPressed: () async {
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
                                },
                              ),
                              IconOnlyButton(
                                icon: Icons.delete,
                                iconSize: 20,
                                tooltip: 'Excluir',
                                onPressed: () async {
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
                                        debugPrint('✅ Pasta da subtarefa deletada do Google Drive: $taskTitle');
                                      } else {
                                        debugPrint('⚠️ Drive delete skipped: not authenticated');
                                      }
                                    } catch (e) {
                                      debugPrint('⚠️ Drive delete failed (ignored): $e');
                                    }

                                    // Atualizar status da tarefa pai
                                    try {
                                      await tasksModule.updateTaskStatus(widget.taskId);
                                      debugPrint('✅ Status da tarefa pai atualizado após exclusão de subtarefa');
                                    } catch (e) {
                                      debugPrint('⚠️ Erro ao atualizar status da tarefa pai: $e');
                                    }

                                    _loadSubTasks();
                                    widget.onSubTaskChanged?.call();
                                  }
                                },
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

