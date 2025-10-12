import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../state/app_state_scope.dart';
import '../../navigation/tab_manager_scope.dart';
import '../../navigation/tab_item.dart';
import '../../../widgets/task_files_section.dart';
import '../../../widgets/final_project_section.dart';
import '../../../widgets/comments_section.dart';
import '../../../widgets/user_avatar_name.dart';
import '../../../widgets/custom_briefing_editor.dart';
import 'package:gestor_projetos_flutter/widgets/buttons/buttons.dart';
import '../shared/quick_forms.dart';
import 'widgets/subtasks_section.dart';
import 'widgets/task_status_field.dart';
import 'widgets/task_due_date_badge.dart';
import 'widgets/task_priority_badge.dart';
import '../../../modules/tasks/module.dart';
import '../projects/project_detail_page.dart';
import '../clients/client_detail_page.dart';

class TaskDetailPage extends StatefulWidget {
  final String taskId;
  const TaskDetailPage({super.key, required this.taskId});

  @override
  State<TaskDetailPage> createState() => _TaskDetailPageState();
}

class _TaskDetailPageState extends State<TaskDetailPage> {
  late Future<Map<String, dynamic>?> _taskFuture;

  @override
  void initState() {
    super.initState();
    _taskFuture = _loadTask();
  }

  Future<Map<String, dynamic>?> _loadTask() async {
    return await tasksModule.getTaskWithDetails(widget.taskId);
  }

  Future<void> _updateTask(Map<String, dynamic> updates, {String? parentTaskId}) async {
    // Usar o módulo para atualizar a tarefa (isso vai renomear a pasta no Google Drive se necessário)
    await tasksModule.updateTask(
      taskId: widget.taskId,
      title: updates['title'] as String?,
      description: updates['description'] as String?,
      assignedTo: updates['assigned_to'] as String?,
      status: updates['status'] as String?,
      priority: updates['priority'] as String?,
      dueDate: updates['due_date'] != null ? DateTime.parse(updates['due_date'] as String) : null,
    );

    // Se esta tarefa tem uma tarefa pai e o status foi alterado, atualizar o status da tarefa pai
    if (parentTaskId != null && updates.containsKey('status')) {
      try {
        await tasksModule.updateTaskStatus(parentTaskId);
        debugPrint('✅ Status da tarefa pai atualizado após mudança na subtarefa');
      } catch (e) {
        debugPrint('⚠️ Erro ao atualizar status da tarefa pai: $e');
      }
    }

    if (!mounted) return;
    setState(() {
      _taskFuture = _loadTask();
    });
  }

  String _formatDateDDMMYY(String dateStr) {
    final dt = DateTime.tryParse(dateStr);
    if (dt == null) return '-';
    final d = dt.day.toString().padLeft(2, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final y = dt.year.toString(); // Ano completo com 4 dígitos
    return '$d/$m/$y';
  }

  Widget _buildBriefingSection(BuildContext context, Map<String, dynamic> task) {
    final description = task['description'] as String?;

    if (description == null || description.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Briefing', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            CustomBriefingEditor(
              initialJson: description,
              enabled: false, // Read-only
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = AppStateScope.of(context);
    // Salvar o contexto do widget para usar dentro do FutureBuilder
    final widgetContext = context;

    return FutureBuilder<Map<String, dynamic>?>(
              future: _taskFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Erro ao carregar tarefa: ${snapshot.error}'));
                }
                final task = snapshot.data;
                if (task == null) {
                  return const Center(child: Text('Tarefa não encontrada'));
                }

                final projectData = task['projects'] as Map<String, dynamic>?;
                final projectId = projectData?['id'] as String?;
                final projectName = projectData?['name'] ?? 'Projeto desconhecido';
                final clientData = projectData?['clients'] as Map<String, dynamic>?;
                final clientId = clientData?['id'] as String?;
                final clientName = clientData?['name'] ?? 'Cliente desconhecido';
                final clientAvatarUrl = clientData?['avatar_url'] as String?;

                // Envolve o conteúdo em Material para widgets que precisam dele
                return Material(
                  type: MaterialType.transparency,
                  child: LayoutBuilder(
                  builder: (context, constraints) {
                    return SingleChildScrollView(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: constraints.maxHeight,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Header
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  IconOnlyButton(
                                    icon: Icons.arrow_back,
                                    tooltip: 'Voltar',
                                    onPressed: () {
                                      final tabManager = TabManagerScope.maybeOf(widgetContext);
                                      if (tabManager != null) {
                                        if (tabManager.canGoBack()) {
                                          // Se há histórico na aba, volta no histórico
                                          tabManager.goBack();
                                        } else {
                                          // Se não há histórico, volta para a página do Projeto
                                          final projectId = task['project_id'] as String?;
                                          if (projectId != null) {
                                            final projectTab = TabItem(
                                              id: 'project_$projectId',
                                              title: 'Projeto',
                                              icon: Icons.folder,
                                              page: ProjectDetailPage(projectId: projectId),
                                              canClose: true,
                                              selectedMenuIndex: 2, // Índice do menu de Projetos
                                            );
                                            tabManager.updateTab(tabManager.currentIndex, projectTab, saveToHistory: false);
                                          }
                                        }
                                      } else {
                                        // Fallback para navegação tradicional
                                        Navigator.of(context).pop();
                                      }
                                    },
                                  ),
                                  Expanded(
                                    child: Text(
                                      task['parent_task_id'] != null ? 'Subtarefa' : 'Tarefa',
                                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                  // Botões de ação
                                  if (appState.isAdmin || appState.isDesigner || task['created_by'] == Supabase.instance.client.auth.currentUser?.id) ...[
                                    IconOnlyButton(
                                      icon: Icons.edit,
                                      tooltip: 'Editar',
                                      onPressed: () async {
                                        final changed = await showDialog<bool>(
                                          context: context,
                                          builder: (_) => QuickTaskForm(
                                            projectId: task['project_id'] as String,
                                            initial: task,
                                          ),
                                        );
                                        if (changed == true) {
                                          setState(() {
                                            _taskFuture = _loadTask();
                                          });
                                        }
                                      },
                                    ),
                                  ],
                                  if (appState.isAdmin || task['created_by'] == Supabase.instance.client.auth.currentUser?.id) ...[
                                    IconOnlyButton(
                                      icon: Icons.delete,
                                      tooltip: 'Excluir',
                                      onPressed: () async {
                                        final navigator = Navigator.of(context);
                                        final confirmed = await showDialog<bool>(
                                          context: context,
                                          builder: (_) => AlertDialog(
                                            title: const Text('Excluir tarefa'),
                                            content: const Text('Tem certeza que deseja excluir esta tarefa?'),
                                            actions: [
                                              TextButton(
                                                onPressed: () => Navigator.pop(context, false),
                                                child: const Text('Cancelar'),
                                              ),
                                              FilledButton(
                                                onPressed: () => Navigator.pop(context, true),
                                                child: const Text('Excluir'),
                                              ),
                                            ],
                                          ),
                                        );
                                        if (confirmed == true) {
                                          await Supabase.instance.client
                                              .from('tasks')
                                              .delete()
                                              .eq('id', widget.taskId);
                                          if (!mounted) return;
                                          navigator.pop(true);
                                        }
                                      },
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 16),

                              // Card com informações da Task
                              Card(
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.center,
                                    children: [
                                      // Nome da Task
                                      Expanded(
                                        flex: 2,
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text('Tarefa', style: Theme.of(context).textTheme.labelSmall),
                                            const SizedBox(height: 4),
                                            Text(
                                              task['title'] ?? 'Sem título',
                                              style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 16),

                                      // Responsável
                                      Expanded(
                                        flex: 2,
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text('Responsável', style: Theme.of(context).textTheme.labelSmall),
                                            const SizedBox(height: 4),
                                            Builder(
                                              builder: (context) {
                                                final assigneeId = task['assigned_to'] as String?;
                                                if (assigneeId == null) {
                                                  return Text('Não atribuído', style: Theme.of(context).textTheme.bodySmall);
                                                }

                                                // Usar os dados que já vêm da task
                                                final profile = task['assignee_profile'] as Map<String, dynamic>?;
                                                final name = (profile?['full_name'] ?? profile?['email'] ?? 'Usuário') as String;
                                                final avatarUrl = profile?['avatar_url'] as String?;

                                                return UserAvatarName(
                                                  avatarUrl: avatarUrl,
                                                  name: name,
                                                  size: 20,
                                                );
                                              },
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 16),

                                      // Projeto
                                      Expanded(
                                        flex: 2,
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text('Projeto', style: Theme.of(context).textTheme.labelSmall),
                                            const SizedBox(height: 4),
                                            if (projectId != null)
                                              GestureDetector(
                                                onTap: () {
                                                  // Atualiza a aba atual com os detalhes do projeto
                                                  final tabManager = TabManagerScope.maybeOf(context);
                                                  if (tabManager != null) {
                                                    final currentIndex = tabManager.currentIndex;
                                                    final updatedTab = TabItem(
                                                      id: 'project_$projectId',
                                                      title: projectName,
                                                      icon: Icons.folder,
                                                      page: ProjectDetailPage(projectId: projectId),
                                                      canClose: true,
                                                      selectedMenuIndex: 2, // Índice do menu de Projetos
                                                    );
                                                    tabManager.updateTab(currentIndex, updatedTab);
                                                  }
                                                },
                                                child: MouseRegion(
                                                  cursor: SystemMouseCursors.click,
                                                  child: Text(
                                                    projectName,
                                                    style: Theme.of(context).textTheme.bodySmall,
                                                    maxLines: 2,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                              )
                                            else
                                              Text(
                                                projectName,
                                                style: Theme.of(context).textTheme.bodySmall,
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 16),

                                      // Cliente
                                      Expanded(
                                        flex: 2,
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text('Cliente', style: Theme.of(context).textTheme.labelSmall),
                                            const SizedBox(height: 4),
                                            if (clientId != null)
                                              GestureDetector(
                                                onTap: () {
                                                  // Atualiza a aba atual com os detalhes do cliente
                                                  final tabManager = TabManagerScope.maybeOf(context);
                                                  if (tabManager != null) {
                                                    final currentIndex = tabManager.currentIndex;
                                                    final updatedTab = TabItem(
                                                      id: 'client_$clientId',
                                                      title: clientName,
                                                      icon: Icons.person,
                                                      page: ClientDetailPage(clientId: clientId),
                                                      canClose: true,
                                                      selectedMenuIndex: 1, // Índice do menu de Clientes
                                                    );
                                                    tabManager.updateTab(currentIndex, updatedTab);
                                                  }
                                                },
                                                child: MouseRegion(
                                                  cursor: SystemMouseCursors.click,
                                                  child: Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      if (clientAvatarUrl != null && clientAvatarUrl.isNotEmpty)
                                                        Padding(
                                                          padding: const EdgeInsets.only(right: 8),
                                                          child: CircleAvatar(
                                                            radius: 12,
                                                            backgroundImage: NetworkImage(clientAvatarUrl),
                                                          ),
                                                        ),
                                                      Flexible(
                                                        child: Text(
                                                          clientName,
                                                          style: Theme.of(context).textTheme.bodySmall,
                                                          maxLines: 2,
                                                          overflow: TextOverflow.ellipsis,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              )
                                            else
                                              Text(
                                                clientName,
                                                style: Theme.of(context).textTheme.bodySmall,
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 16),

                                      // Prioridade (apenas badge)
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text('Prioridade', style: Theme.of(context).textTheme.labelSmall),
                                          const SizedBox(height: 4),
                                          TaskPriorityBadge(priority: task['priority'] ?? 'medium'),
                                        ],
                                      ),
                                      const SizedBox(width: 16),

                                      // Data de conclusão (data + badge)
                                      Expanded(
                                        flex: 2,
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text('Data de conclusão', style: Theme.of(context).textTheme.labelSmall),
                                            const SizedBox(height: 4),
                                            if (task['due_date'] != null) ...[
                                              Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Text(
                                                    _formatDateDDMMYY(task['due_date'] as String),
                                                    style: Theme.of(context).textTheme.bodySmall,
                                                  ),
                                                  const SizedBox(width: 8),
                                                  TaskDueDateBadge(
                                                    dueDate: task['due_date'] as String,
                                                    status: task['status'] ?? 'todo',
                                                  ),
                                                ],
                                              ),
                                            ] else
                                              Text('Sem data de conclusão', style: Theme.of(context).textTheme.bodySmall),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 16),

                                      // Status (dropdown)
                                      Expanded(
                                        flex: 2,
                                        child: TaskStatusField(
                                          status: task['status'] ?? 'todo',
                                          taskId: widget.taskId,
                                          onStatusChanged: (status) async {
                                            await _updateTask(
                                              {'status': status},
                                              parentTaskId: task['parent_task_id'] as String?,
                                            );
                                          },
                                          enabled: appState.isAdmin || appState.isDesigner,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),

                              // Briefing
                              _buildBriefingSection(context, task),
                              const SizedBox(height: 12),

                              // Arquivos da Task
                              TaskFilesSection(
                                task: task,
                                canUpload: appState.isAdmin || appState.isDesigner,
                                canDeleteOwn: appState.isAdmin || (Supabase.instance.client.auth.currentUser?.id == task['created_by']),
                              ),
                              const SizedBox(height: 12),

                              // Projeto Final
                              FinalProjectSection(
                                task: task,
                              ),
                              const SizedBox(height: 12),

                              // Sub Tasks section
                              SubTasksSection(
                                taskId: widget.taskId,
                                taskTitle: task['title'] as String? ?? 'Tarefa',
                                projectId: task['project_id'] as String,
                                onSubTaskChanged: () {
                                  setState(() {
                                    _taskFuture = _loadTask();
                                  });
                                },
                                onSubTaskTap: (subTaskId, subTaskTitle) {
                                  debugPrint('🔍 TaskDetailPage: onSubTaskTap chamado com ID=$subTaskId, Title=$subTaskTitle');

                                  // Navegar para a subtask usando TabManager com o contexto correto
                                  final tabManager = TabManagerScope.maybeOf(widgetContext);
                                  debugPrint('🔍 TaskDetailPage: TabManager = $tabManager');

                                  if (tabManager != null) {
                                    final tabId = 'task_$subTaskId';
                                    final currentIndex = tabManager.currentIndex;
                                    debugPrint('🔍 TaskDetailPage: Atualizando aba $currentIndex para $tabId');

                                    final updatedTab = TabItem(
                                      id: tabId,
                                      title: subTaskTitle,
                                      icon: Icons.task,
                                      page: TaskDetailPage(
                                        key: ValueKey('task_$subTaskId'),
                                        taskId: subTaskId,
                                      ),
                                      canClose: true,
                                    );
                                    tabManager.updateTab(currentIndex, updatedTab);
                                    debugPrint('🔍 TaskDetailPage: Aba atualizada!');
                                  } else {
                                    debugPrint('⚠️ TaskDetailPage: TabManager é null!');
                                  }
                                },
                              ),
                              const SizedBox(height: 12),

                              // Comentários
                              CommentsSection(task: task),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                  ),
                );
              },
            );
  }
}

