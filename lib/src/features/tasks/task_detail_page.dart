import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../state/app_state_scope.dart';
import '../../navigation/tab_manager_scope.dart';
import '../../navigation/tab_item.dart';
import 'package:my_business/ui/organisms/sections/sections.dart';
import 'package:my_business/ui/organisms/editors/generic_block_editor.dart';
import 'package:my_business/ui/organisms/cards/cards.dart';
import 'package:my_business/ui/atoms/buttons/buttons.dart';
import 'package:my_business/ui/atoms/loaders/loaders.dart';
import 'package:my_business/ui/molecules/containers/containers.dart';
import '../shared/quick_forms.dart';
import 'widgets/subtasks_section.dart';
import 'widgets/task_info_card_items.dart';
import 'widgets/task_timer_widget.dart';
import 'widgets/task_time_history_widget.dart';
import '../../../modules/modules.dart';
import '../projects/project_detail_page.dart';
import 'package:my_business/ui/organisms/dialogs/dialogs.dart';
import '../../services/task_products_service.dart';

class TaskDetailPage extends StatefulWidget {
  final String taskId;
  final bool openTimerCard;
  const TaskDetailPage({
    super.key,
    required this.taskId,
    this.openTimerCard = false,
  });

  @override
  State<TaskDetailPage> createState() => _TaskDetailPageState();
}

class _TaskDetailPageState extends State<TaskDetailPage> {
  late Future<Map<String, dynamic>?> _taskFuture;
  bool _showTimerCard =
      false; // Estado para controlar visibilidade do card de Timer
  bool _isFavorite = false;
  bool _favoriteLoading = false;

  @override
  void initState() {
    super.initState();
    _taskFuture = _loadTask();
    // Abrir o card do timer se solicitado
    if (widget.openTimerCard) {
      _showTimerCard = true;
    }
    _loadFavoriteStatus();
  }

  Future<Map<String, dynamic>?> _loadTask() async {
    return await tasksModule.getTaskWithDetails(widget.taskId);
  }

  Future<void> _loadFavoriteStatus() async {
    try {
      // Primeiro, carregar a task para verificar se é subtarefa
      final task = await _taskFuture;
      final isSubTask = task?['parent_task_id'] != null;

      final isFav = await favoritesModule.isFavorite(
        itemType: isSubTask ? 'subtask' : 'task',
        itemId: widget.taskId,
      );
      if (mounted) {
        setState(() => _isFavorite = isFav);
      }
    } catch (e) {
      // Ignorar erro (operação não crítica)
    }
  }

  Future<void> _toggleFavorite(bool isSubTask) async {
    setState(() => _favoriteLoading = true);
    try {
      final wasAdded = await favoritesModule.toggleFavorite(
        itemType: isSubTask ? 'subtask' : 'task',
        itemId: widget.taskId,
      );

      if (mounted) {
        setState(() {
          _isFavorite = wasAdded;
          _favoriteLoading = false;
        });

        final itemName = isSubTask ? 'Subtarefa' : 'Tarefa';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(wasAdded
                ? '$itemName adicionada aos favoritos'
                : '$itemName removida dos favoritos'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _favoriteLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao atualizar favorito: $e')),
        );
      }
    }
  }

  Future<void> _handleStatusChange(String newStatus) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      // Buscar a tarefa atual para verificar se tem parent_task_id
      final currentTask = await _taskFuture;
      final parentTaskId = currentTask?['parent_task_id'] as String?;

      await tasksModule.updateTask(
        taskId: widget.taskId,
        status: newStatus,
      );

      // Se é uma subtarefa, atualizar o status da tarefa pai
      if (parentTaskId != null && parentTaskId.isNotEmpty) {
        try {
          await tasksModule.updateTaskStatus(parentTaskId);
        } catch (e) {
          // Ignorar erro (operação não crítica)
        }
      }

      if (mounted) {
        setState(() {
          _taskFuture = _loadTask();
        });
        messenger.showSnackBar(
          const SnackBar(content: Text('Status atualizado com sucesso!')),
        );
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text('Erro ao atualizar status: $e')),
        );
      }
    }
  }

  bool _canEdit(Map<String, dynamic> task) {
    final appState = AppStateScope.of(context);
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    final taskCreatorId = task['created_by'] as String?;
    return appState.permissions.canEditTask(taskCreatorId, currentUserId);
  }

  bool _canDelete(Map<String, dynamic> task) {
    final appState = AppStateScope.of(context);
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    final taskCreatorId = task['created_by'] as String?;
    return appState.permissions.canDeleteTask(taskCreatorId, currentUserId);
  }

  Widget _buildTaskInfoCards({
    required BuildContext context,
    required Map<String, dynamic> task,
    required String? projectId,
    required String projectName,
    required String? clientId,
    required String clientName,
    required String? clientAvatarUrl,
  }) {
    final appState = AppStateScope.of(context);
    // Apenas admin e gestor podem acessar a página de clientes
    final canAccessClientPage = appState.isAdmin || appState.isGestor;

    // Card esquerdo: informações básicas
    final leftCardItems = <InfoCardItem>[
      TaskInfoCardItems.buildTaskNameItem(context, task),
      TaskInfoCardItems.buildAssigneeItem(context, task),
      TaskInfoCardItems.buildProjectItem(context, projectId, projectName),
      TaskInfoCardItems.buildClientItem(
        context,
        clientId,
        clientName,
        clientAvatarUrl,
        canNavigate: canAccessClientPage,
      ),
    ];

    // Card direito: prioridade, vencimento, status, timer
    final rightCardItems = <InfoCardItem>[
      TaskInfoCardItems.buildPriorityItem(task),
      TaskInfoCardItems.buildDueDateItem(context, task),
      TaskInfoCardItems.buildStatusItem(
        context,
        task,
        widget.taskId,
        (newStatus) => _handleStatusChange(newStatus),
      ),
      TaskInfoCardItems.buildTimerItem(
        onTap: () {
          setState(() {
            _showTimerCard = !_showTimerCard;
          });
        },
      ),
    ];

    return InfoCardsSection(
      leftCard: InfoCard(
        items: leftCardItems,
        minWidth: 120,
        minHeight: 104,
        totalItems: 4,
        debugEmoji: '📝',
        debugDescription: 'Nome da Tarefa/Responsável',
        onSizeCalculated: (size) {
          // Callback já implementado no InfoCard
        },
      ),
      rightCard: InfoCard(
        items: rightCardItems,
        minWidth: 120,
        minHeight: 104,
        totalItems: 4,
        debugEmoji: '🔍',
        debugDescription: 'Prioridade/Vencimento/Status/Timer',
      ),
    );
  }

  Widget _buildTimerCard(BuildContext context, Map<String, dynamic> task) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF2A2A2A),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Timer Widget
          Padding(
            padding: const EdgeInsets.all(16),
            child: TaskTimerWidget(
              taskId: widget.taskId,
              assignedTo: task['assigned_to'] as String?,
              assigneeUserIds:
                  (task['assignee_user_ids'] as List<dynamic>?)?.cast<String>(),
            ),
          ),

          const Divider(
            color: Color(0xFF2A2A2A),
            height: 1,
          ),

          // Histórico de Tempo
          Padding(
            padding: const EdgeInsets.all(16),
            child: TaskTimeHistoryWidget(
              taskId: widget.taskId,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBriefingSection(
      BuildContext context, Map<String, dynamic> task) {
    final description = task['description'] as String?;
    final projectId = task['project_id'] as String?;

    // Mostrar card mesmo sem descrição se houver produtos vinculados
    final hasDescription = description != null && description.isNotEmpty;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SelectableContainer(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Produtos vinculados
              if (projectId != null) ...[
                _buildLinkedProductsSection(context, widget.taskId, projectId),
                const SizedBox(height: 16),
              ],

              // Título Briefing
              Text('Briefing', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),

              // Descrição/Briefing
              if (hasDescription)
                GenericBlockEditor(
                  initialJson: description,
                  enabled: false, // Read-only
                  showToolbar: false,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLinkedProductsSection(
      BuildContext context, String taskId, String projectId) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _loadLinkedProducts(taskId, projectId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(8.0),
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (snapshot.hasError) {
          return Text(
            'Erro ao carregar produtos: ${snapshot.error}',
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          );
        }

        final products = snapshot.data ?? [];

        if (products.isEmpty) {
          return const SizedBox.shrink();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.inventory_2_outlined,
                  size: 16,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Produtos Vinculados',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Column(
              children: products.map((product) {
                final label = product['label'] as String? ?? 'Produto';
                final packageName = product['packageName'] as String?;
                final comment = product['comment'] as String?;
                final thumbUrl = product['thumbUrl'] as String?;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: _buildProductChip(
                    context,
                    label: label,
                    packageName: packageName,
                    comment: comment,
                    thumbUrl: thumbUrl,
                  ),
                );
              }).toList(),
            ),
          ],
        );
      },
    );
  }

  Widget _buildProductChip(
    BuildContext context, {
    required String label,
    String? packageName,
    String? comment,
    String? thumbUrl,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          // Thumbnail
          if (thumbUrl != null && thumbUrl.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Image.network(
                thumbUrl,
                width: 48,
                height: 48,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Icon(
                  Icons.inventory_2_outlined,
                  size: 48,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            )
          else
            Icon(
              Icons.inventory_2_outlined,
              size: 48,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          const SizedBox(width: 16),

          // Label
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                ),
                if (comment != null && comment.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    comment,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.amber,
                        ),
                  ),
                ] else if (packageName != null && packageName.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    packageName,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<List<Map<String, dynamic>>> _loadLinkedProducts(
      String taskId, String projectId) async {
    return await TaskProductsService.loadLinkedProducts(taskId,
        projectId: projectId);
  }

  /// Constrói skeleton loading para a página de detalhes da task
  Widget _buildTaskDetailSkeleton() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Título skeleton
          SkeletonLoader.text(width: 200),
          const SizedBox(height: 24),

          // Dois cards skeleton lado a lado
          Row(
            children: [
              Expanded(
                child: InfoCardSkeleton(itemCount: 4, minHeight: 104),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: InfoCardSkeleton(itemCount: 4, minHeight: 104),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Seções skeleton
          SkeletonLoader.box(
              width: double.infinity, height: 200, borderRadius: 12),
          const SizedBox(height: 12),
          SkeletonLoader.box(
              width: double.infinity, height: 150, borderRadius: 12),
        ],
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
          return _buildTaskDetailSkeleton();
        }
        if (snapshot.hasError) {
          return Center(
              child: Text('Erro ao carregar tarefa: ${snapshot.error}'));
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
          child: CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    // Header
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        IconOnlyButton(
                          icon: Icons.arrow_back,
                          tooltip: 'Voltar',
                          onPressed: () {
                            final tabManager =
                                TabManagerScope.maybeOf(widgetContext);
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
                                    page:
                                        ProjectDetailPage(projectId: projectId),
                                    canClose: true,
                                    selectedMenuIndex:
                                        2, // Índice do menu de Projetos
                                  );
                                  tabManager.updateTab(
                                      tabManager.currentIndex, projectTab,
                                      saveToHistory: false);
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
                            task['parent_task_id'] != null
                                ? 'Subtarefa'
                                : 'Tarefa',
                            style: Theme.of(context)
                                .textTheme
                                .headlineSmall
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                        ),
                        // Botões de ação
                        if (_canEdit(task)) ...[
                          IconOnlyButton(
                            icon: Icons.edit,
                            tooltip: 'Editar',
                            onPressed: () async {
                              final changed = await DialogHelper.show<bool>(
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
                        if (_canDelete(task)) ...[
                          IconOnlyButton(
                            icon: Icons.delete,
                            tooltip: 'Excluir',
                            onPressed: () async {
                              final navigator = Navigator.of(context);
                              final confirmed = await DialogHelper.show<bool>(
                                context: context,
                                builder: (_) => AlertDialog(
                                  title: const Text('Excluir tarefa'),
                                  content: const Text(
                                      'Tem certeza que deseja excluir esta tarefa?'),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(context, false),
                                      child: const Text('Cancelar'),
                                    ),
                                    FilledButton(
                                      onPressed: () =>
                                          Navigator.pop(context, true),
                                      child: const Text('Excluir'),
                                    ),
                                  ],
                                ),
                              );
                              if (confirmed == true) {
                                await tasksModule.deleteTask(widget.taskId);
                                if (!mounted) return;
                                navigator.pop(true);
                              }
                            },
                          ),
                        ],
                        // Botão de Favorito (disponível para todos os usuários)
                        IconOnlyButton(
                          icon: _isFavorite ? Icons.star : Icons.star_border,
                          tooltip: _isFavorite
                              ? 'Remover dos favoritos'
                              : 'Adicionar aos favoritos',
                          iconColor:
                              _isFavorite ? const Color(0xFFFFD700) : null,
                          isLoading: _favoriteLoading,
                          onPressed: () =>
                              _toggleFavorite(task['parent_task_id'] != null),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // 2 Cards com informações da Task
                    _buildTaskInfoCards(
                      context: context,
                      task: task,
                      projectId: projectId,
                      projectName: projectName,
                      clientId: clientId,
                      clientName: clientName,
                      clientAvatarUrl: clientAvatarUrl,
                    ),
                    const SizedBox(height: 12),

                    // Card de Timer (exibido condicionalmente)
                    if (_showTimerCard) ...[
                      _buildTimerCard(context, task),
                      const SizedBox(height: 12),
                    ],

                    // Projeto Final
                    FinalProjectSection(
                      task: task,
                    ),
                    const SizedBox(height: 12),

                    // Briefing
                    _buildBriefingSection(context, task),
                    const SizedBox(height: 12),

                    // Arquivos da Task
                    TaskFilesSection(
                      task: task,
                      canUpload: appState.isAdmin || appState.isDesigner,
                      canDeleteOwn: appState.isAdmin ||
                          (Supabase.instance.client.auth.currentUser?.id ==
                              task['created_by']),
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
                        // Navegar para a subtask usando TabManager com o contexto correto
                        final tabManager =
                            TabManagerScope.maybeOf(widgetContext);

                        if (tabManager != null) {
                          final tabId = 'task_$subTaskId';
                          final currentIndex = tabManager.currentIndex;

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
                        } else {}
                      },
                    ),
                    const SizedBox(height: 12),
                  ]),
                ),
              ),
              // Comentários (Sliver)
              SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: CommentsSection(task: task),
              ),
            ],
          ),
        );
      },
    );
  }
}
