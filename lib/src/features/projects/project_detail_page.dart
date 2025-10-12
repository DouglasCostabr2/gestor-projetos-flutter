import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:googleapis_auth/auth_io.dart' as auth;
import '../../state/app_state_scope.dart';
import '../../navigation/tab_manager_scope.dart';
import '../../navigation/tab_item.dart';
import '../shared/quick_forms.dart';
import '../../widgets/dynamic_paginated_table.dart';
import '../../../widgets/user_avatar_name.dart';
import '../../../widgets/standard_dialog.dart';
import '../tasks/task_detail_page.dart';
import '../tasks/widgets/task_status_badge.dart';
import '../tasks/widgets/task_priority_badge.dart';
import 'package:gestor_projetos_flutter/modules/modules.dart';
import '../../../widgets/reusable_data_table.dart';
import '../../../widgets/table_search_filter_bar.dart';
import 'widgets/project_status_badge.dart';
import '../../../services/google_drive_oauth_service.dart';
import 'widgets/project_finance_tabs.dart';
import 'project_form_dialog.dart';
import 'package:gestor_projetos_flutter/widgets/buttons/buttons.dart';
import 'project_members_dialog.dart';
import '../../../constants/task_status.dart';
import 'projects_page.dart';

class ProjectDetailPage extends StatefulWidget {
  final String projectId;
  const ProjectDetailPage({super.key, required this.projectId});

  @override
  State<ProjectDetailPage> createState() => _ProjectDetailPageState();
}

class _ProjectDetailPageState extends State<ProjectDetailPage> {
  late Future<Map<String, dynamic>?> _projectFuture;
  List<Map<String, dynamic>> _tasks = [];
  List<Map<String, dynamic>> _filteredTasks = [];
  List<Map<String, dynamic>> _subTasks = [];
  List<Map<String, dynamic>> _filteredSubTasks = [];
  bool _tasksLoading = true;
  bool _subTasksLoading = true;
  final Set<String> _selectedTasks = <String>{};
  final Set<String> _selectedSubTasks = <String>{};

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

  // Ordenação para tasks
  int? _sortColumnIndexTasks = 0;
  bool _sortAscendingTasks = true;

  // Ordenação para subtasks
  int? _sortColumnIndexSubTasks = 0;
  bool _sortAscendingSubTasks = true;

  @override
  void initState() {
    super.initState();
    _projectFuture = _loadProject();
    _reloadTasks();
    _reloadSubTasks();
  }

  Future<Map<String, dynamic>?> _loadProject() async {
    return await projectsModule.getProjectWithDetails(widget.projectId);
  }

  String _fmtDateShort(dynamic v) {
    DateTime? dt;
    if (v is DateTime) {
      dt = v;
    } else if (v is String) {
      dt = DateTime.tryParse(v);
    }
    if (dt == null) return '-';
    final d = dt.day.toString().padLeft(2, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final y = dt.year.toString();
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return '$d/$m/$y $hh:$mm';
  }

  Widget _projectStatusChip(BuildContext context, String status) {
    return ProjectStatusBadge(status: status);
  }

  Future<void> _reloadTasks() async {
    setState(() => _tasksLoading = true);

    // Atualizar prioridades baseado no prazo
    await tasksModule.updateTasksPriorityByDueDate();

    final res = await tasksModule.getProjectMainTasks(widget.projectId);

    // Buscar informações dos usuários que fizeram a última atualização
    final updatedByIds = res.map((t) => t['updated_by']).whereType<String>().toSet();
    Map<String, Map<String, dynamic>> usersMap = {};

    if (updatedByIds.isNotEmpty) {
      try {
        final users = await Supabase.instance.client
            .from('profiles')
            .select('id, full_name, email, avatar_url')
            .inFilter('id', updatedByIds.toList());

        for (final user in users) {
          usersMap[user['id']] = user;
        }
      } catch (e) {
        debugPrint('Erro ao buscar perfis de usuários: $e');
      }
    }

    // Adicionar informações do usuário aos dados
    final tasks = List<Map<String, dynamic>>.from(res);
    for (final task in tasks) {
      final updatedBy = task['updated_by'];
      if (updatedBy != null && usersMap.containsKey(updatedBy)) {
        task['updated_by_profile'] = usersMap[updatedBy];
      }
    }

    // Buscar todos os usuários para o filtro de responsável
    final usersRes = await Supabase.instance.client
        .from('profiles')
        .select('id, full_name, email, avatar_url')
        .order('full_name', ascending: true);

    if (!mounted) return;
    setState(() {
      _tasks = tasks;
      _allUsers = List<Map<String, dynamic>>.from(usersRes);
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

  List<String> _getFilterOptionsTasks() {
    switch (_filterTypeTasks) {
      case 'status':
        return TaskStatus.values;
      case 'priority':
        return ['low', 'medium', 'high', 'urgent'];
      case 'assignee':
        // Retorna IDs dos usuários
        return _allUsers.map((u) => u['id'] as String).toList();
      case 'none':
        return [];
      default:
        return [];
    }
  }

  String _getFilterLabelTasks() {
    switch (_filterTypeTasks) {
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

  String _getFilterValueLabelTasks(String value) {
    switch (_filterTypeTasks) {
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
        // Buscar o nome do usuário pelo ID
        final user = _allUsers.firstWhere(
          (u) => u['id'] == value,
          orElse: () => {'full_name': value},
        );
        return user['full_name'] ?? value;
      default:
        return value;
    }
  }

  Future<void> _reloadSubTasks() async {
    setState(() => _subTasksLoading = true);

    // Atualizar prioridades baseado no prazo
    await tasksModule.updateTasksPriorityByDueDate();

    final res = await tasksModule.getProjectSubTasks(widget.projectId);

    // Buscar informações dos usuários que fizeram a última atualização
    final updatedByIds = res.map((t) => t['updated_by']).whereType<String>().toSet();
    Map<String, Map<String, dynamic>> usersMap = {};

    if (updatedByIds.isNotEmpty) {
      try {
        final users = await Supabase.instance.client
            .from('profiles')
            .select('id, full_name, email, avatar_url')
            .inFilter('id', updatedByIds.toList());

        for (final user in users) {
          usersMap[user['id']] = user;
        }
      } catch (e) {
        debugPrint('Erro ao buscar perfis de usuários: $e');
      }
    }

    // Adicionar informações do usuário aos dados
    final subTasks = List<Map<String, dynamic>>.from(res);
    for (final task in subTasks) {
      final updatedBy = task['updated_by'];
      if (updatedBy != null && usersMap.containsKey(updatedBy)) {
        task['updated_by_profile'] = usersMap[updatedBy];
      }
    }

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

  List<String> _getFilterOptionsSubTasks() {
    switch (_filterTypeSubTasks) {
      case 'status':
        return TaskStatus.values;
      case 'priority':
        return ['low', 'medium', 'high', 'urgent'];
      case 'assignee':
        // Retorna IDs dos usuários
        return _allUsers.map((u) => u['id'] as String).toList();
      case 'none':
        return [];
      default:
        return [];
    }
  }

  String _getFilterLabelSubTasks() {
    switch (_filterTypeSubTasks) {
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

  String _getFilterValueLabelSubTasks(String value) {
    switch (_filterTypeSubTasks) {
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
        // Buscar o nome do usuário pelo ID
        final user = _allUsers.firstWhere(
          (u) => u['id'] == value,
          orElse: () => {'full_name': value},
        );
        return user['full_name'] ?? value;
      default:
        return value;
    }
  }

  // ========== FUNÇÕES AUXILIARES PARA TASKS ==========

  // Exclusão em lote de tasks
  Future<void> _bulkDeleteTasks() async {
    final count = _selectedTasks.length;

    final confirm = await showDialog<bool>(
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
      // Título
      (a, b) => (a['title'] ?? '').toString().toLowerCase()
          .compareTo((b['title'] ?? '').toString().toLowerCase()),
      // Status
      (a, b) => (a['status'] ?? '').toString()
          .compareTo((b['status'] ?? '').toString()),
      // Prioridade
      (a, b) {
        const priorities = {'low': 0, 'medium': 1, 'high': 2, 'urgent': 3};
        final priorityA = priorities[a['priority']] ?? 0;
        final priorityB = priorities[b['priority']] ?? 0;
        return priorityA.compareTo(priorityB);
      },
      // Responsável
      (a, b) => 0, // Não ordenável
      // Data de conclusão
      (a, b) {
        final dateA = a['due_date'] != null ? DateTime.tryParse(a['due_date']) : null;
        final dateB = b['due_date'] != null ? DateTime.tryParse(b['due_date']) : null;
        if (dateA == null && dateB == null) return 0;
        if (dateA == null) return 1;
        if (dateB == null) return -1;
        return dateA.compareTo(dateB);
      },
      // Criado em
      (a, b) {
        final dateA = a['created_at'] != null ? DateTime.tryParse(a['created_at']) : null;
        final dateB = b['created_at'] != null ? DateTime.tryParse(b['created_at']) : null;
        if (dateA == null && dateB == null) return 0;
        if (dateA == null) return 1;
        if (dateB == null) return -1;
        return dateA.compareTo(dateB);
      },
      // Última atualização
      (a, b) {
        final dateA = a['updated_at'] != null ? DateTime.tryParse(a['updated_at']) : null;
        final dateB = b['updated_at'] != null ? DateTime.tryParse(b['updated_at']) : null;
        if (dateA == null && dateB == null) return 0;
        if (dateA == null) return 1;
        if (dateB == null) return -1;
        return dateA.compareTo(dateB);
      },
    ];
  }

  // ========== FUNÇÕES AUXILIARES PARA SUBTASKS ==========

  // Exclusão em lote de subtasks
  Future<void> _bulkDeleteSubTasks() async {
    final count = _selectedSubTasks.length;

    final confirm = await showDialog<bool>(
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

  // Comparadores para ordenação de subtasks
  List<int Function(Map<String, dynamic>, Map<String, dynamic>)> _getSortComparatorsSubTasks() {
    return [
      // Título
      (a, b) => (a['title'] ?? '').toString().toLowerCase()
          .compareTo((b['title'] ?? '').toString().toLowerCase()),
      // Tarefa Principal (não ordenável)
      (a, b) => 0,
      // Status
      (a, b) => (a['status'] ?? '').toString()
          .compareTo((b['status'] ?? '').toString()),
      // Prioridade
      (a, b) {
        const priorities = {'low': 0, 'medium': 1, 'high': 2, 'urgent': 3};
        final priorityA = priorities[a['priority']] ?? 0;
        final priorityB = priorities[b['priority']] ?? 0;
        return priorityA.compareTo(priorityB);
      },
      // Data de conclusão
      (a, b) {
        final dateA = a['due_date'] != null ? DateTime.tryParse(a['due_date']) : null;
        final dateB = b['due_date'] != null ? DateTime.tryParse(b['due_date']) : null;
        if (dateA == null && dateB == null) return 0;
        if (dateA == null) return 1;
        if (dateB == null) return -1;
        return dateA.compareTo(dateB);
      },
      // Responsável (não ordenável)
      (a, b) => 0,
      // Criado em
      (a, b) {
        final dateA = a['created_at'] != null ? DateTime.tryParse(a['created_at']) : null;
        final dateB = b['created_at'] != null ? DateTime.tryParse(b['created_at']) : null;
        if (dateA == null && dateB == null) return 0;
        if (dateA == null) return 1;
        if (dateB == null) return -1;
        return dateA.compareTo(dateB);
      },
      // Última atualização
      (a, b) {
        final dateA = a['updated_at'] != null ? DateTime.tryParse(a['updated_at']) : null;
        final dateB = b['updated_at'] != null ? DateTime.tryParse(b['updated_at']) : null;
        if (dateA == null && dateB == null) return 0;
        if (dateA == null) return 1;
        if (dateB == null) return -1;
        return dateA.compareTo(dateB);
      },
    ];
  }

  @override
  Widget build(BuildContext context) {
    final appState = AppStateScope.of(context);
    return FutureBuilder<Map<String, dynamic>?>(
              future: _projectFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
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
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text((project['name'] ?? 'Projeto').toString(),
                                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w600)),
                                const SizedBox(height: 4),
                                Text(
                                  'Criado por ${((project['created_by_profile']?['full_name'] ?? project['created_by_profile']?['email'] ?? '-') as String)} em ${_fmtDateShort(project['created_at'])} • Atualizado por ${((project['updated_by_profile']?['full_name'] ?? project['updated_by_profile']?['email'] ?? '-') as String)} em ${_fmtDateShort(project['updated_at'])}',
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          _projectStatusChip(context, (project['status'] ?? 'active').toString()),
                          const SizedBox(width: 8),
                          Builder(builder: (context) {
                            final current = Supabase.instance.client.auth.currentUser;
                            final isOwner = current != null && project['owner_id'] == current.id;
                            final canManage = appState.isAdmin || isOwner;
                            final canEdit = appState.isAdmin || appState.isDesigner;
                            return Row(children: [
                              IconOnlyButton(
                                icon: Icons.group,
                                tooltip: 'Membros',
                                onPressed: canManage ? () async {
                                  await showDialog(
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
                                  final changed = await showDialog<bool>(
                                    context: context,
                                    builder: (context) => ProjectFormDialog(fixedClientId: project['client_id'] as String, initial: project),
                                  );
                                  if (changed == true && mounted) { setState(() { _projectFuture = _loadProject(); }); }
                                } : null,
                              ),
                            ]);
                          }),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Wrap(
                            spacing: 24,
                            runSpacing: 8,
                            children: [
                              _Info('Nome', project['name'] ?? ''),
                              _Info('Cliente', project['clients']?['name'] ?? '-'),
                              _Info('Status', (project['status'] ?? 'active').toString()),
                              _Info('Descrição', project['description'] ?? '-'),
                            ],
                          ),
                        ),
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
                            LayoutBuilder(
                              builder: (context, constraints) {
                                return SizedBox(
                                  height: 1700, // Altura suficiente para 2 tabelas + espaçamentos + controles de paginação
                                  child: TabBarView(
                                children: [
                                  // Aba de Tarefas
                                  Column(
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
                                          height: 200,
                                          child: Center(child: CircularProgressIndicator()),
                                        )
                                      else
                                        SizedBox(
                                          height: 600,
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
                                          height: 200,
                                          child: Center(child: CircularProgressIndicator()),
                                        )
                                      else
                                        SizedBox(
                                          height: 600,
                                          child: _buildSubTasksTable(appState),
                                        ),
                                    ],
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
                                );
                              },
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
              final created = await showDialog<bool>(
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
            columns: const [
              DataTableColumn(label: 'Título', sortable: true),
              DataTableColumn(label: 'Status', sortable: true),
              DataTableColumn(label: 'Prioridade', sortable: true),
              DataTableColumn(label: 'Data de Conclusão', sortable: true),
              DataTableColumn(label: 'Responsável', sortable: false),
              DataTableColumn(label: 'Criado em', sortable: true),
              DataTableColumn(label: 'Última Atualização', sortable: true),
            ],
            sortComparators: _getSortComparatorsTasks(),
      cellBuilders: [
        // Título
        (t) {
          final title = t['title'] ?? 'Sem título';
          final status = t['status'] as String?;

          // Se está aguardando, mostrar ícone
          if (tasksModule.isWaitingStatus(status)) {
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.hourglass_empty,
                  size: 16,
                  color: Colors.orange.shade700,
                ),
                const SizedBox(width: 6),
                Expanded(child: Text(title)),
              ],
            );
          }

          return Text(title);
        },

        // Status
        (t) {
          final status = t['status'] ?? 'todo';
          return TaskStatusBadge(status: status);
        },

        // Prioridade
        (t) {
          final priority = t['priority'] ?? 'medium';
          return TaskPriorityBadge(priority: priority);
        },

        // Data de Conclusão
        (t) {
          final dueDate = t['due_date'];
          if (dueDate == null) return const Text('-');
          try {
            final date = DateTime.parse(dueDate);
            return Text('${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}');
          } catch (e) {
            return const Text('-');
          }
        },

        // Responsável
        (t) {
          final assignee = t['profiles'] as Map<String, dynamic>?;
          if (assignee == null) return const Text('-');
          final assigneeName = assignee['full_name'] ?? assignee['email'] ?? '-';
          final avatarUrl = assignee['avatar_url'] as String?;
          return UserAvatarName(
            avatarUrl: avatarUrl,
            name: assigneeName as String,
            size: 20,
          );
        },

        // Criado em
        (t) {
          final createdAt = t['created_at'];
          if (createdAt == null) return const Text('-');
          try {
            final date = DateTime.parse(createdAt);
            return Text('${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}');
          } catch (e) {
            return const Text('-');
          }
        },

        // Última Atualização
        (t) {
          final updatedAt = t['updated_at'];
          final updatedByProfile = t['updated_by_profile'] as Map<String, dynamic>?;

          if (updatedAt == null) return const Text('-');

          try {
            final date = DateTime.parse(updatedAt);
            final dateStr = '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

            // Se não tem informação do usuário, mostra só a data
            if (updatedByProfile == null) {
              return Text(dateStr);
            }

            final userName = updatedByProfile['full_name'] as String? ?? updatedByProfile['email'] as String? ?? 'Usuário';
            final avatarUrl = updatedByProfile['avatar_url'] as String?;

            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(dateStr, style: const TextStyle(fontSize: 12)),
                const SizedBox(height: 4),
                UserAvatarName(
                  avatarUrl: avatarUrl,
                  name: userName,
                  size: 16,
                ),
              ],
            );
          } catch (e) {
            return const Text('-');
          }
        },
      ],
      getId: (t) => t['id'] as String,
      onRowTap: (t) {
        // Atualiza a aba atual com os detalhes da tarefa
        final tabManager = TabManagerScope.maybeOf(context);
        if (tabManager != null) {
          final taskId = t['id'].toString();
          final taskTitle = t['title'] as String? ?? 'Tarefa';
          final tabId = 'task_$taskId';

          // Atualiza a aba atual em vez de criar uma nova
          final currentIndex = tabManager.currentIndex;
          final currentTab = tabManager.currentTab;
          final updatedTab = TabItem(
            id: tabId,
            title: taskTitle,
            icon: Icons.task,
            page: TaskDetailPage(
              key: ValueKey('task_$taskId'),
              taskId: taskId,
            ),
            canClose: true,
            selectedMenuIndex: currentTab?.selectedMenuIndex ?? 0, // Preserva o índice do menu
          );
          tabManager.updateTab(currentIndex, updatedTab);
        }
      },
      actions: [
        DataTableAction<Map<String, dynamic>>(
          icon: Icons.edit,
          label: 'Editar',
          onPressed: (t) async {
            final currentId = Supabase.instance.client.auth.currentUser?.id;
            final canAdmin = appState.isAdmin;
            final canOwner = currentId != null && t['created_by'] == currentId;
            final canEdit = canAdmin || canOwner;

            if (!canEdit) return;

            final changed = await showDialog<bool>(
              context: context,
              builder: (context) => QuickTaskForm(projectId: widget.projectId, initial: t),
            );
            if (changed == true) _reloadTasks();
          },
        ),
        DataTableAction<Map<String, dynamic>>(
          icon: Icons.content_copy,
          label: 'Duplicar',
          onPressed: (t) async {
            final currentId = Supabase.instance.client.auth.currentUser?.id;
            final canAdmin = appState.isAdmin;
            final canEdit = canAdmin || t['assigned_to'] == currentId;

            if (!canEdit) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Você não tem permissão para duplicar esta task')),
              );
              return;
            }

            try {
              final formData = Map<String, dynamic>.from(t);
              formData.remove('id');
              formData.remove('created_at');
              formData.remove('updated_at');
              // Remover campos de relacionamento que vêm dos joins
              formData.remove('assignee_profile');
              formData.remove('assigned_to_profile');
              formData.remove('created_by_profile');
              formData.remove('updated_by_profile');
              formData.remove('creator_profile');
              formData.remove('projects');
              if (formData['title'] != null) {
                formData['title'] = '${formData['title']} (Cópia)';
              }

              // Garantir que project_id está presente
              formData['project_id'] = widget.projectId;

              await Supabase.instance.client.from('tasks').insert(formData);

              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Task duplicada com sucesso')),
                );
                _reloadTasks();
              }
            } catch (e) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Erro ao duplicar: $e')),
                );
              }
            }
          },
        ),
        DataTableAction<Map<String, dynamic>>(
          icon: Icons.delete,
          label: 'Excluir',
          onPressed: (t) async {
            final currentId = Supabase.instance.client.auth.currentUser?.id;
            final canAdmin = appState.isAdmin;
            final canOwner = currentId != null && t['created_by'] == currentId;
            final canDelete = canAdmin || canOwner;

            if (!canDelete) return;

            final ok = await showDialog<bool>(
              context: context,
              builder: (_) => ConfirmDialog(
                title: 'Excluir Tarefa',
                message: 'Tem certeza que deseja excluir esta tarefa?',
                confirmText: 'Excluir',
                isDestructive: true,
              ),
            );
            if (ok == true) {
              // Deletar do banco de dados
              await Supabase.instance.client
                  .from('tasks')
                  .delete()
                  .eq('id', t['id']);

              // Deletar pasta do Google Drive (best-effort)
              try {
                final clientName = (t['projects']?['clients']?['name'] ?? 'Cliente').toString();
                final projectName = (t['projects']?['name'] ?? 'Projeto').toString();
                final taskTitle = (t['title'] ?? 'Tarefa').toString();
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
                  debugPrint('✅ Pasta da tarefa deletada do Google Drive: $taskTitle');
                } else {
                  debugPrint('⚠️ Drive delete skipped: not authenticated');
                }
              } catch (e) {
                debugPrint('⚠️ Drive delete failed (ignored): $e');
              }

              if (mounted) _reloadTasks();
            }
          },
        ),
            ],
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
            columns: const [
              DataTableColumn(label: 'Título', sortable: true),
              DataTableColumn(label: 'Tarefa Principal', sortable: false),
              DataTableColumn(label: 'Status', sortable: true),
              DataTableColumn(label: 'Prioridade', sortable: true),
              DataTableColumn(label: 'Data de Conclusão', sortable: true),
              DataTableColumn(label: 'Responsável', sortable: false),
                      DataTableColumn(label: 'Criado em', sortable: true),
                      DataTableColumn(label: 'Última Atualização', sortable: true),
                    ],
                    sortComparators: _getSortComparatorsSubTasks(),
                    cellBuilders: [
        // Título
        (t) {
          final title = t['title'] ?? 'Sem título';
          final status = t['status'] as String?;

          // Se está aguardando, mostrar ícone
          if (tasksModule.isWaitingStatus(status)) {
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.hourglass_empty,
                  size: 16,
                  color: Colors.orange.shade700,
                ),
                const SizedBox(width: 6),
                Expanded(child: Text(title)),
              ],
            );
          }

          return Text(title);
        },

        // Tarefa Principal
        (t) {
          final parentTaskId = t['parent_task_id'];
          if (parentTaskId == null) return const Text('-');
          // Buscar o título da tarefa principal
          final parentTask = _tasks.firstWhere(
            (task) => task['id'] == parentTaskId,
            orElse: () => {'title': 'Tarefa não encontrada'},
          );
          return Text(parentTask['title'] ?? '-');
        },

        // Status
        (t) {
          final status = t['status'] ?? 'todo';
          return TaskStatusBadge(status: status);
        },

        // Prioridade
        (t) {
          final priority = t['priority'] ?? 'medium';
          return TaskPriorityBadge(priority: priority);
        },

        // Data de Conclusão
        (t) {
          final dueDate = t['due_date'];
          if (dueDate == null) return const Text('-');
          try {
            final date = DateTime.parse(dueDate);
            return Text('${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}');
          } catch (e) {
            return const Text('-');
          }
        },

        // Responsável
        (t) {
          final assignee = t['profiles'] as Map<String, dynamic>?;
          if (assignee == null) return const Text('-');
          final assigneeName = assignee['full_name'] ?? assignee['email'] ?? '-';
          final avatarUrl = assignee['avatar_url'] as String?;
          return UserAvatarName(
            avatarUrl: avatarUrl,
            name: assigneeName as String,
            size: 20,
          );
        },

        // Criado em
        (t) {
          final createdAt = t['created_at'];
          if (createdAt == null) return const Text('-');
          try {
            final date = DateTime.parse(createdAt);
            return Text('${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}');
          } catch (e) {
            return const Text('-');
          }
        },

        // Última Atualização
        (t) {
          final updatedAt = t['updated_at'];
          final updatedByProfile = t['updated_by_profile'] as Map<String, dynamic>?;

          if (updatedAt == null) return const Text('-');

          try {
            final date = DateTime.parse(updatedAt);
            final dateStr = '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

            // Se não tem informação do usuário, mostra só a data
            if (updatedByProfile == null) {
              return Text(dateStr);
            }

            final userName = updatedByProfile['full_name'] as String? ?? updatedByProfile['email'] as String? ?? 'Usuário';
            final avatarUrl = updatedByProfile['avatar_url'] as String?;

            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(dateStr, style: const TextStyle(fontSize: 12)),
                const SizedBox(height: 4),
                UserAvatarName(
                  avatarUrl: avatarUrl,
                  name: userName,
                  size: 16,
                ),
              ],
            );
          } catch (e) {
            return const Text('-');
          }
        },
      ],
      getId: (t) => t['id'] as String,
      onRowTap: (t) {
        // Atualiza a aba atual com os detalhes da subtarefa
        final tabManager = TabManagerScope.maybeOf(context);
        if (tabManager != null) {
          final taskId = t['id'].toString();
          final taskTitle = t['title'] as String? ?? 'Subtarefa';
          final tabId = 'task_$taskId';

          // Atualiza a aba atual em vez de criar uma nova
          final currentIndex = tabManager.currentIndex;
          final currentTab = tabManager.currentTab;
          final updatedTab = TabItem(
            id: tabId,
            title: taskTitle,
            icon: Icons.task,
            page: TaskDetailPage(
              key: ValueKey('task_$taskId'),
              taskId: taskId,
            ),
            canClose: true,
            selectedMenuIndex: currentTab?.selectedMenuIndex ?? 0, // Preserva o índice do menu
          );
          tabManager.updateTab(currentIndex, updatedTab);
        }
      },
            actions: [],
          ),
        ),
      ],
    );
  }
}

class _Info extends StatelessWidget {
  final String label;
  final String value;
  const _Info(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelSmall),
        const SizedBox(height: 4),
        Text(value, style: Theme.of(context).textTheme.bodyMedium),
      ],
    );
  }
}


