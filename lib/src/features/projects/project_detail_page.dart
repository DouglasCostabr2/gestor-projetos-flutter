import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../state/app_state_scope.dart';
import '../../navigation/tab_manager_scope.dart';
import '../../navigation/tab_item.dart';
import '../shared/quick_forms.dart';
import 'package:my_business/ui/organisms/tables/dynamic_paginated_table.dart';
import 'package:my_business/modules/modules.dart';
import 'package:my_business/ui/organisms/tables/reusable_data_table.dart';
import 'package:my_business/ui/organisms/tables/table_search_filter_bar.dart';
import 'widgets/project_info_card_items.dart';
import 'widgets/task_table_helpers.dart';
import 'widgets/task_table_actions.dart';
import 'widgets/project_finance_tabs.dart';
import '../../utils/task_helpers.dart';
import '../../utils/table_comparators.dart';
import '../../utils/navigation_helpers.dart';
import 'project_form_dialog.dart';
import 'package:my_business/ui/atoms/buttons/buttons.dart';
import 'package:my_business/ui/atoms/loaders/loaders.dart';
import 'package:my_business/ui/organisms/cards/cards.dart';
import 'project_members_dialog.dart';
import '../../../constants/task_status.dart';
import 'projects_page.dart';
import 'package:my_business/ui/organisms/dialogs/dialogs.dart';
import 'package:my_business/ui/theme/ui_constants.dart';

class ProjectDetailPage extends StatefulWidget {
  final String projectId;
  const ProjectDetailPage({super.key, required this.projectId});

  @override
  State<ProjectDetailPage> createState() => _ProjectDetailPageState();
}

class _ProjectDetailPageState extends State<ProjectDetailPage> {
  // ========== CONSTANTES DE LAYOUT ==========
  static const double _tableHeight = 600.0;
  static const double _loadingHeight = 200.0;

  // ========== ESTADO ==========
  late Future<Map<String, dynamic>?> _projectFuture;
  List<Map<String, dynamic>> _tasks = [];
  List<Map<String, dynamic>> _filteredTasks = [];
  List<Map<String, dynamic>> _subTasks = [];
  List<Map<String, dynamic>> _filteredSubTasks = [];
  bool _tasksLoading = true;
  bool _subTasksLoading = true;
  final Set<String> _selectedTasks = <String>{};
  final Set<String> _selectedSubTasks = <String>{};
  bool _isFavorite = false;
  bool _favoriteLoading = false;

  // Busca e filtros para tasks
  String _searchQueryTasks = '';
  String _filterTypeTasks = 'none'; // none, status, priority, assignee
  String? _filterValueTasks;

  // Busca e filtros para subtasks
  String _searchQuerySubTasks = '';
  String _filterTypeSubTasks = 'none'; // none, status, priority, assignee
  String? _filterValueSubTasks;

  // Lista de usuários para o filtro de responsável
  List<Map<String, dynamic>> _allUsers = [];

  // Ordenação para tasks - padrão por "Criado" (coluna 5) decrescente
  int? _sortColumnIndexTasks = 5;
  bool _sortAscendingTasks = false;

  // Ordenação para subtasks - padrão por "Criado" (coluna 6) decrescente
  int? _sortColumnIndexSubTasks = 6;
  bool _sortAscendingSubTasks = false;

  @override
  void initState() {
    super.initState();
    _projectFuture = _loadProject();
    _reloadTasks();
    _reloadSubTasks();
    _loadFavoriteStatus();
  }

  Future<Map<String, dynamic>?> _loadProject() async {
    return await projectsModule.getProjectWithDetails(widget.projectId);
  }

  Future<void> _loadFavoriteStatus() async {
    try {
      final isFav = await favoritesModule.isFavorite(
        itemType: 'project',
        itemId: widget.projectId,
      );
      if (mounted) {
        setState(() => _isFavorite = isFav);
      }
    } catch (e) {
      // Ignorar erro (operação não crítica)
    }
  }

  Future<void> _toggleFavorite() async {
    setState(() => _favoriteLoading = true);
    try {
      final wasAdded = await favoritesModule.toggleFavorite(
        itemType: 'project',
        itemId: widget.projectId,
      );

      if (mounted) {
        setState(() {
          _isFavorite = wasAdded;
          _favoriteLoading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(wasAdded ? 'Projeto adicionado aos favoritos' : 'Projeto removido dos favoritos'),
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

  /// Constrói os cards de informações do projeto (similar ao design da task detail page)
  Widget _buildProjectInfoCards({
    required BuildContext context,
    required Map<String, dynamic> project,
  }) {
    final appState = AppStateScope.of(context);
    final canAccessClientPage = appState.isAdmin || appState.isGestor;

    // Card esquerdo: Nome do Projeto + Cliente + Status
    final leftCardItems = <InfoCardItem>[
      ProjectInfoCardItems.buildProjectNameItem(context, project),
      ProjectInfoCardItems.buildClientItem(
        context,
        project['client_id'] as String?,
        project['clients']?['name'] ?? '-',
        project['clients']?['avatar_url'] as String?,
        canNavigate: canAccessClientPage,
      ),
      ProjectInfoCardItems.buildStatusItem(context, project),
    ];

    // Card direito: Descrição
    final rightCardItems = <InfoCardItem>[
      ProjectInfoCardItems.buildDescriptionItem(context, project),
    ];

    return InfoCardsSection(
      leftCard: InfoCard(
        items: leftCardItems,
        minWidth: 120,
        minHeight: 104,
        totalItems: 4, // Forçar uso de Wrap (mesmo padrão da task detail page)
        debugEmoji: '📁',
        debugDescription: 'Nome do Projeto/Cliente/Status',
      ),
      rightCard: InfoCard(
        items: rightCardItems,
        minWidth: 120,
        minHeight: 104,
        totalItems: 4, // Forçar uso de Wrap (mesmo padrão da task detail page)
        debugEmoji: '📊',
        debugDescription: 'Descrição',
      ),
    );
  }

  Future<void> _reloadTasks() async {
    setState(() => _tasksLoading = true);

    // Atualizar prioridades baseado no prazo
    await tasksModule.updateTasksPriorityByDueDate();

    final res = await tasksModule.getProjectMainTasks(widget.projectId);
    final tasks = List<Map<String, dynamic>>.from(res);

    // Enriquecer tarefas com perfis de updated_by
    await enrichWithUpdatedByProfiles(tasks);

    // Enriquecer tarefas com perfis de responsáveis
    await enrichTasksWithAssignees(tasks);

    // Buscar todos os usuários para o filtro de responsável
    final usersRes = await fetchAllProfiles();

    if (!mounted) return;
    setState(() {
      _tasks = tasks;
      _allUsers = usersRes;
      _tasksLoading = false;
    });
    _applyFiltersTasks();
  }

  void _applyFiltersTasks() {
    setState(() {
      var filtered = List<Map<String, dynamic>>.from(_tasks);

      // Aplicar busca
      if (_searchQueryTasks.isNotEmpty) {
        final query = _searchQueryTasks.toLowerCase();
        filtered = filtered.where((task) {
          final title = (task['title'] ?? '').toString().toLowerCase();
          return title.contains(query);
        }).toList();
      }

      // Aplicar filtro selecionado
      if (_filterTypeTasks != 'none' && _filterValueTasks != null && _filterValueTasks!.isNotEmpty) {
        filtered = filtered.where((task) {
          switch (_filterTypeTasks) {
            case 'status':
              return task['status'] == _filterValueTasks;
            case 'priority':
              return task['priority'] == _filterValueTasks;
            case 'assignee':
              // Filtro por responsável (assigned_to)
              return task['assigned_to'] == _filterValueTasks;
            default:
              return true;
          }
        }).toList();
      }

      _filteredTasks = filtered;
      _applySortingTasks();
    });
  }

  void _applySortingTasks() {
    if (_sortColumnIndexTasks == null) return;

    final comparators = _getSortComparatorsTasks();
    if (_sortColumnIndexTasks! >= comparators.length) return;

    final comparator = comparators[_sortColumnIndexTasks!];

    _filteredTasks.sort((a, b) {
      final result = comparator(a, b);
      return _sortAscendingTasks ? result : -result;
    });
  }

  // ========== MÉTODOS GENÉRICOS PARA FILTROS ==========

  /// Retorna as opções de filtro baseado no tipo de filtro
  List<String> _getFilterOptions(String filterType) {
    switch (filterType) {
      case 'status':
        return TaskStatus.values;
      case 'priority':
        return ['low', 'medium', 'high', 'urgent'];
      case 'assignee':
        return _allUsers.map((u) => u['id'] as String).toList();
      case 'none':
        return [];
      default:
        return [];
    }
  }

  /// Retorna o label do filtro baseado no tipo
  String _getFilterLabel(String filterType) {
    switch (filterType) {
      case 'status':
        return 'Filtrar por status';
      case 'priority':
        return 'Filtrar por prioridade';
      case 'assignee':
        return 'Filtrar por responsável';
      case 'none':
        return 'Sem filtro';
      default:
        return 'Filtrar';
    }
  }

  /// Retorna o label do valor do filtro baseado no tipo e valor
  String _getFilterValueLabel(String filterType, String value) {
    switch (filterType) {
      case 'status':
        return TaskStatus.getLabel(value);
      case 'priority':
        switch (value) {
          case 'low':
            return 'Baixa';
          case 'medium':
            return 'Média';
          case 'high':
            return 'Alta';
          case 'urgent':
            return 'Urgente';
          default:
            return value;
        }
      case 'assignee':
        final user = _allUsers.firstWhere(
          (u) => u['id'] == value,
          orElse: () => {'full_name': value},
        );
        return user['full_name'] ?? value;
      default:
        return value;
    }
  }

  // Wrappers para Tasks (mantém compatibilidade)
  List<String> _getFilterOptionsTasks() => _getFilterOptions(_filterTypeTasks);
  String _getFilterLabelTasks() => _getFilterLabel(_filterTypeTasks);
  String _getFilterValueLabelTasks(String value) => _getFilterValueLabel(_filterTypeTasks, value);

  Future<void> _reloadSubTasks() async {
    setState(() => _subTasksLoading = true);

    // Atualizar prioridades baseado no prazo
    await tasksModule.updateTasksPriorityByDueDate();

    final res = await tasksModule.getProjectSubTasks(widget.projectId);
    final subTasks = List<Map<String, dynamic>>.from(res);

    // Enriquecer tarefas com perfis de updated_by
    await enrichWithUpdatedByProfiles(subTasks);

    // Enriquecer tarefas com perfis de responsáveis
    await enrichTasksWithAssignees(subTasks);

    if (!mounted) return;
    setState(() {
      _subTasks = subTasks;
      _subTasksLoading = false;
    });
    _applyFiltersSubTasks();
  }

  void _applyFiltersSubTasks() {
    setState(() {
      var filtered = List<Map<String, dynamic>>.from(_subTasks);

      // Aplicar busca
      if (_searchQuerySubTasks.isNotEmpty) {
        final query = _searchQuerySubTasks.toLowerCase();
        filtered = filtered.where((task) {
          final title = (task['title'] ?? '').toString().toLowerCase();
          return title.contains(query);
        }).toList();
      }

      // Aplicar filtro selecionado
      if (_filterTypeSubTasks != 'none' && _filterValueSubTasks != null && _filterValueSubTasks!.isNotEmpty) {
        filtered = filtered.where((task) {
          switch (_filterTypeSubTasks) {
            case 'status':
              return task['status'] == _filterValueSubTasks;
            case 'priority':
              return task['priority'] == _filterValueSubTasks;
            case 'assignee':
              // Filtro por responsável (assigned_to)
              return task['assigned_to'] == _filterValueSubTasks;
            default:
              return true;
          }
        }).toList();
      }

      _filteredSubTasks = filtered;
      _applySortingSubTasks();
    });
  }

  void _applySortingSubTasks() {
    if (_sortColumnIndexSubTasks == null) return;

    final comparators = _getSortComparatorsSubTasks();
    if (_sortColumnIndexSubTasks! >= comparators.length) return;

    final comparator = comparators[_sortColumnIndexSubTasks!];

    _filteredSubTasks.sort((a, b) {
      final result = comparator(a, b);
      return _sortAscendingSubTasks ? result : -result;
    });
  }

  // Wrappers para SubTasks (mantém compatibilidade)
  List<String> _getFilterOptionsSubTasks() => _getFilterOptions(_filterTypeSubTasks);
  String _getFilterLabelSubTasks() => _getFilterLabel(_filterTypeSubTasks);
  String _getFilterValueLabelSubTasks(String value) => _getFilterValueLabel(_filterTypeSubTasks, value);

  // ========== FUNÇÕES AUXILIARES PARA TASKS ==========

  // Exclusão em lote de tasks
  Future<void> _bulkDeleteTasks() async {
    final count = _selectedTasks.length;

    final confirm = await DialogHelper.show<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar exclusão'),
        content: Text('Deseja realmente excluir $count tarefa${count > 1 ? 's' : ''}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        for (final id in _selectedTasks) {
          await tasksModule.deleteTask(id);
        }

        if (!mounted) return;
        setState(() => _selectedTasks.clear());
        _reloadTasks();

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$count tarefa${count > 1 ? 's excluídas' : ' excluída'} com sucesso')),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao excluir tarefas: $e')),
        );
      }
    }
  }

  // Comparadores para ordenação de tasks
  List<int Function(Map<String, dynamic>, Map<String, dynamic>)> _getSortComparatorsTasks() {
    return [
      compareByTitle,
      compareByStatus,
      compareByPriority,
      (a, b) => 0, // Responsável - não ordenável
      compareByDueDate,
      compareByCreatedAt,
      compareByUpdatedAt,
    ];
  }

  // ========== FUNÇÕES AUXILIARES PARA SUBTASKS ==========

  // Exclusão em lote de subtasks
  Future<void> _bulkDeleteSubTasks() async {
    final count = _selectedSubTasks.length;

    final confirm = await DialogHelper.show<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar exclusão'),
        content: Text('Deseja realmente excluir $count subtarefa${count > 1 ? 's' : ''}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        for (final id in _selectedSubTasks) {
          await tasksModule.deleteTask(id);
        }

        if (!mounted) return;
        setState(() => _selectedSubTasks.clear());
        _reloadSubTasks();

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$count subtarefa${count > 1 ? 's excluídas' : ' excluída'} com sucesso')),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao excluir subtarefas: $e')),
        );
      }
    }
  }

  /// Retorna comparadores de ordenação para a tabela de SubTasks
  /// Usa comparadores reutilizáveis de table_comparators.dart
  List<int Function(Map<String, dynamic>, Map<String, dynamic>)> _getSortComparatorsSubTasks() {
    return [
      compareByTitle,           // Título
      compareByStatus,          // Status
      compareByPriority,        // Prioridade
      compareByDueDate,         // Data de conclusão
      (a, b) => 0,              // Responsável (não ordenável)
      compareByCreatedAt,       // Criado em
      compareByUpdatedAt,       // Última atualização
    ];
  }

  /// Constrói skeleton loading para a página de detalhes do projeto
  Widget _buildProjectDetailSkeleton() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Título skeleton
          SkeletonLoader.text(width: 250),
          const SizedBox(height: 24),

          // Card de informações skeleton
          InfoCardSkeleton(itemCount: 6, minHeight: 120),
          const SizedBox(height: 24),

          // Tabs skeleton
          Row(
            children: [
              SkeletonLoader.box(width: 100, height: 40, borderRadius: 8),
              const SizedBox(width: 8),
              SkeletonLoader.box(width: 100, height: 40, borderRadius: 8),
              const SizedBox(width: 8),
              SkeletonLoader.box(width: 100, height: 40, borderRadius: 8),
            ],
          ),
          const SizedBox(height: 24),

          // Tabela skeleton
          Expanded(
            child: Column(
              children: List.generate(
                8,
                (index) => TableRowSkeleton(columnCount: 6, height: 52),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = AppStateScope.of(context);
    return FutureBuilder<Map<String, dynamic>?>(
              future: _projectFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return _buildProjectDetailSkeleton();
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Erro ao carregar projeto'));
                }
                final project = snapshot.data;
                if (project == null) {
                  return const Center(child: Text('Projeto não encontrado'));
                }

                // Envolve o conteúdo em Material para widgets que precisam dele
                return Material(
                  type: MaterialType.transparency,
                  child: _buildContent(context, appState, project),
                );
              },
            );
  }

  Widget _buildContent(BuildContext context, appState, Map<String, dynamic> project) {
    return LayoutBuilder(
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
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          IconOnlyButton(
                            icon: Icons.arrow_back,
                            tooltip: 'Voltar',
                            onPressed: () {
                              final tabManager = TabManagerScope.maybeOf(context);
                              if (tabManager != null) {
                                if (tabManager.canGoBack()) {
                                  // Se há histórico na aba, volta no histórico
                                  tabManager.goBack();
                                } else {
                                  // Se não há histórico, volta para a página de Projetos
                                  final currentTab = tabManager.currentTab;
                                  if (currentTab != null) {
                                    final projectsTab = TabItem(
                                      id: 'page_2', // ID da página de Projetos
                                      title: 'Projetos',
                                      icon: Icons.work,
                                      page: const ProjectsPage(),
                                      canClose: true,
                                      selectedMenuIndex: 2, // Índice do menu de Projetos
                                    );
                                    tabManager.updateTab(tabManager.currentIndex, projectsTab, saveToHistory: false);
                                  }
                                }
                              } else {
                                // Fallback para navegação tradicional
                                Navigator.of(context).pop();
                              }
                            },
                          ),
                          Expanded(
                            child: Text('Projeto',
                                style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w600)),
                          ),
                          const SizedBox(width: 12),
                          Builder(builder: (context) {
                            // Apenas Admin, Gestor e Financeiro podem ver os botões de Membros e Editar
                            final canAccessButtons = appState.isAdmin || appState.isGestor || appState.isFinanceiro;

                            if (!canAccessButtons) {
                              return const SizedBox.shrink();
                            }

                            final current = Supabase.instance.client.auth.currentUser;
                            final isOwner = current != null && project['owner_id'] == current.id;
                            final canManage = appState.isAdmin || isOwner;

                            // Usar novo sistema de permissões
                            final canEdit = appState.permissions.canEditProjects;

                            return Row(children: [
                              IconOnlyButton(
                                icon: Icons.group,
                                tooltip: 'Membros',
                                onPressed: canManage ? () async {
                                  await DialogHelper.show(
                                    context: context,
                                    builder: (context) => ProjectMembersDialog(
                                      projectId: (project['id'] as String),
                                      canManage: canManage,
                                    ),
                                  );
                                } : null,
                              ),
                              IconOnlyButton(
                                icon: Icons.edit,
                                tooltip: 'Editar',
                                onPressed: canEdit ? () async {
                                  final changed = await DialogHelper.show<bool>(
                                    context: context,
                                    builder: (context) => ProjectFormDialog(fixedClientId: project['client_id'] as String, initial: project),
                                  );
                                  if (changed == true && mounted) { setState(() { _projectFuture = _loadProject(); }); }
                                } : null,
                              ),
                            ]);
                          }),
                          // Botão de Favorito (disponível para todos os usuários)
                          IconOnlyButton(
                            icon: _isFavorite ? Icons.star : Icons.star_border,
                            tooltip: _isFavorite ? 'Remover dos favoritos' : 'Adicionar aos favoritos',
                            iconColor: _isFavorite ? UIConst.favoriteColor : null,
                            isLoading: _favoriteLoading,
                            onPressed: _toggleFavorite,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Cards de informações do projeto
                      _buildProjectInfoCards(
                        context: context,
                        project: project,
                      ),
                      const SizedBox(height: 16),

                      // Abas: Tarefas e Financeiro
                      DefaultTabController(
                        length: 2,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            TabBar(
                              tabs: const [
                                Tab(text: 'Tarefas'),
                                Tab(text: 'Financeiro'),
                              ],
                            ),
                            // Usar altura dinâmica baseada no conteúdo
                            SizedBox(
                              height: 1300, // Altura ajustada para 2 tabelas sem espaço extra
                              child: TabBarView(
                                children: [
                                  // Aba de Tarefas
                                  SingleChildScrollView(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const SizedBox(height: 16),
                                        // Tarefas do projeto
                                        Row(
                                          children: [
                                            Text('Tarefas do projeto', style: Theme.of(context).textTheme.titleMedium),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        if (_tasksLoading)
                                          const SizedBox(
                                            height: _loadingHeight,
                                            child: Center(child: CircularProgressIndicator()),
                                          )
                                        else
                                          SizedBox(
                                            height: _tableHeight,
                                            child: _buildTasksTable(appState),
                                          ),
                                        const SizedBox(height: 12),

                                        // Subtarefas do projeto
                                        Row(
                                          children: [
                                            Text('Subtarefas', style: Theme.of(context).textTheme.titleMedium),
                                            const Spacer(),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        if (_subTasksLoading)
                                          const SizedBox(
                                            height: _loadingHeight,
                                            child: Center(child: CircularProgressIndicator()),
                                          )
                                        else
                                          SizedBox(
                                            height: _tableHeight,
                                            child: _buildSubTasksTable(appState),
                                          ),
                                        const SizedBox(height: 16), // Espaçamento final
                                      ],
                                    ),
                                  ),

                                  // Aba Financeiro
                                  Padding(
                                    padding: const EdgeInsets.only(top: 16),
                                    child: ProjectFinanceTabs(
                                        projectId: widget.projectId,
                                        currencyCode: (project['currency_code'] as String?) ?? 'BRL',
                                      ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                          ),
                        ),
                      ),
                    );
                  },
                );
  }

  Widget _buildTasksTable(appState) {
    return Column(
      children: [
        // Barra de busca e filtros
        TableSearchFilterBar(
          searchHint: 'Buscar tarefa (título...)',
          onSearchChanged: (value) {
            _searchQueryTasks = value;
            _applyFiltersTasks();
          },
          filterType: _filterTypeTasks,
          filterTypeLabel: 'Tipo de filtro',
          filterTypeOptions: const [
            FilterOption(value: 'none', label: 'Nenhum'),
            FilterOption(value: 'status', label: 'Status'),
            FilterOption(value: 'priority', label: 'Prioridade'),
            FilterOption(value: 'assignee', label: 'Responsável'),
          ],
          onFilterTypeChanged: (value) {
            if (value != null) {
              setState(() {
                _filterTypeTasks = value;
                _filterValueTasks = null;
              });
              _applyFiltersTasks();
            }
          },
          filterValue: _filterValueTasks,
          filterValueLabel: _getFilterLabelTasks(),
          filterValueOptions: _getFilterOptionsTasks(),
          filterValueLabelBuilder: _getFilterValueLabelTasks,
          onFilterValueChanged: (value) {
            setState(() => _filterValueTasks = value?.isEmpty == true ? null : value);
            _applyFiltersTasks();
          },
          selectedCount: _selectedTasks.length,
          bulkActions: (appState.isAdmin || appState.isDesigner) ? [
            BulkAction(
              icon: Icons.delete,
              label: 'Excluir selecionados',
              color: Colors.red,
              onPressed: _bulkDeleteTasks,
            ),
          ] : null,
          actionButton: (appState.isAdmin || appState.isDesigner) ? FilledButton.icon(
            onPressed: () async {
              final created = await DialogHelper.show<bool>(
                context: context,
                builder: (context) => QuickTaskForm(projectId: widget.projectId),
              );
              if (created == true) {
                await _reloadTasks();
              }
            },
            icon: const Icon(Icons.add),
            label: const Text('Nova Tarefa'),
          ) : null,
        ),

        Expanded(
          child: DynamicPaginatedTable<Map<String, dynamic>>(
            items: _filteredTasks,
            itemLabel: 'tarefa(s)',
            selectedIds: _selectedTasks,
            onSelectionChanged: (ids) => setState(() => _selectedTasks
              ..clear()
              ..addAll(ids)),
            onSort: (columnIndex, ascending) {
              setState(() {
                _sortColumnIndexTasks = columnIndex;
                _sortAscendingTasks = ascending;
                _applySortingTasks();
              });
            },
            externalSortColumnIndex: _sortColumnIndexTasks,
            externalSortAscending: _sortAscendingTasks,
            isLoading: _tasksLoading,
            loadingWidget: const Center(child: CircularProgressIndicator()),
            emptyWidget: const Center(
              child: Text(
                'Nenhuma tarefa encontrada',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            ),
            dimCompletedTasks: true,
            getStatus: (t) => t['status'] as String?,
            columns: const [
              DataTableColumn(label: 'Título', sortable: true),
              DataTableColumn(label: 'Status', sortable: true),
              DataTableColumn(label: 'Prioridade', sortable: true),
              DataTableColumn(label: 'Vencimento', sortable: true),
              DataTableColumn(label: 'Responsável', sortable: false),
              DataTableColumn(label: 'Criado', sortable: true),
              DataTableColumn(label: 'Atualizado', sortable: true),
            ],
            sortComparators: _getSortComparatorsTasks(),
            cellBuilders: TaskTableHelpers.getTaskCellBuilders(),
      getId: (t) => t['id'] as String,
      onRowTap: (t) {
        final taskId = t['id'].toString();
        final taskTitle = t['title'] as String? ?? 'Tarefa';
        NavigationHelpers.navigateToTaskDetail(context, taskId, taskTitle);
      },
      actions: TaskTableActions.getTaskActions(
        context: context,
        projectId: widget.projectId,
        appState: appState,
        onTaskChanged: _reloadTasks,
      ),
          ),
        ),
      ],
    );
  }

  Widget _buildSubTasksTable(appState) {
    return Column(
      children: [
        // Barra de busca e filtros
        TableSearchFilterBar(
          searchHint: 'Buscar subtarefa (título...)',
          onSearchChanged: (value) {
            _searchQuerySubTasks = value;
            _applyFiltersSubTasks();
          },
          filterType: _filterTypeSubTasks,
          filterTypeLabel: 'Tipo de filtro',
          filterTypeOptions: const [
            FilterOption(value: 'none', label: 'Nenhum'),
            FilterOption(value: 'status', label: 'Status'),
            FilterOption(value: 'priority', label: 'Prioridade'),
            FilterOption(value: 'assignee', label: 'Responsável'),
          ],
          onFilterTypeChanged: (value) {
            if (value != null) {
              setState(() {
                _filterTypeSubTasks = value;
                _filterValueSubTasks = null;
              });
              _applyFiltersSubTasks();
            }
          },
          filterValue: _filterValueSubTasks,
          filterValueLabel: _getFilterLabelSubTasks(),
          filterValueOptions: _getFilterOptionsSubTasks(),
          filterValueLabelBuilder: _getFilterValueLabelSubTasks,
          onFilterValueChanged: (value) {
            setState(() => _filterValueSubTasks = value?.isEmpty == true ? null : value);
            _applyFiltersSubTasks();
          },
          selectedCount: _selectedSubTasks.length,
          bulkActions: (appState.isAdmin || appState.isDesigner) ? [
            BulkAction(
              icon: Icons.delete,
              label: 'Excluir selecionados',
              color: Colors.red,
              onPressed: _bulkDeleteSubTasks,
            ),
          ] : null,
        ),

        Expanded(
          child: DynamicPaginatedTable<Map<String, dynamic>>(
            items: _filteredSubTasks,
            itemLabel: 'subtarefa(s)',
            selectedIds: _selectedSubTasks,
            onSelectionChanged: (ids) => setState(() => _selectedSubTasks
              ..clear()
              ..addAll(ids)),
            onSort: (columnIndex, ascending) {
              setState(() {
                _sortColumnIndexSubTasks = columnIndex;
                _sortAscendingSubTasks = ascending;
                _applySortingSubTasks();
              });
            },
            externalSortColumnIndex: _sortColumnIndexSubTasks,
            externalSortAscending: _sortAscendingSubTasks,
            isLoading: _subTasksLoading,
            loadingWidget: const Center(child: CircularProgressIndicator()),
            emptyWidget: const Center(
              child: Text(
                'Nenhuma subtarefa encontrada',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            ),
            dimCompletedTasks: true,
            getStatus: (t) => t['status'] as String?,
            columns: const [
              DataTableColumn(label: 'Título', sortable: true),
              DataTableColumn(label: 'Status', sortable: true),
              DataTableColumn(label: 'Prioridade', sortable: true),
              DataTableColumn(label: 'Vencimento', sortable: true),
              DataTableColumn(label: 'Responsável', sortable: false),
                      DataTableColumn(label: 'Criado', sortable: true),
                      DataTableColumn(label: 'Atualizado', sortable: true),
                    ],
                    sortComparators: _getSortComparatorsSubTasks(),
                    cellBuilders: TaskTableHelpers.getSubTaskCellBuilders(_tasks),
      getId: (t) => t['id'] as String,
      onRowTap: (t) {
        final taskId = t['id'].toString();
        final taskTitle = t['title'] as String? ?? 'Subtarefa';
        NavigationHelpers.navigateToTaskDetail(context, taskId, taskTitle);
      },
      actions: TaskTableActions.getTaskActions(
        context: context,
        projectId: widget.projectId,
        appState: appState,
        onTaskChanged: _reloadSubTasks,
      ),
          ),
        ),
      ],
    );
  }
}


