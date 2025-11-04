import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../modules/modules.dart';
import '../../navigation/tab_manager_scope.dart';
import '../../navigation/tab_item.dart';
import '../projects/project_detail_page.dart';
import '../tasks/task_detail_page.dart';
import '../../../ui/organisms/tables/dynamic_paginated_table.dart';
import '../../../ui/organisms/tables/reusable_data_table.dart';
import '../../../ui/molecules/table_cells/table_cell_avatar.dart';
import '../../../ui/molecules/table_cells/table_cell_currency.dart';
import '../../../ui/molecules/table_cells/table_cell_due_date.dart';
import '../../../ui/molecules/table_cells/table_cell_updated_by.dart';
import '../../../ui/molecules/table_cells/responsible_cell.dart';
import '../projects/widgets/project_status_badge.dart';
import '../tasks/widgets/task_status_badge.dart';
import '../tasks/widgets/task_priority_badge.dart';
import '../../state/app_state_scope.dart';
import '../../../ui/atoms/buttons/icon_only_button.dart';
import '../../utils/task_helpers.dart';
import '../../../ui/theme/ui_constants.dart';
import '../../utils/table_comparators.dart';

/// Página inicial (Home) do aplicativo
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with SingleTickerProviderStateMixin {
  late Future<Map<String, List<Map<String, dynamic>>>> _favoritesFuture;
  late Future<List<Map<String, dynamic>>> _weekTasksFuture;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _favoritesFuture = _loadFavorites();
    _weekTasksFuture = _loadWeekTasks();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<Map<String, List<Map<String, dynamic>>>> _loadFavorites() async {
    try {
      final projects = await favoritesModule.getFavoriteProjects();

      // Buscar membros dos projetos (agora são adicionados automaticamente quando atribuídos a tasks)
      if (projects.isNotEmpty) {
        final projectIds = projects.map((p) => p['id'] as String).toList();

        final allMembersResponse = await Supabase.instance.client
            .from('project_members')
            .select('project_id, user_id, profiles:user_id(id, full_name, avatar_url)')
            .inFilter('project_id', projectIds);

        // Agrupar membros por projeto
        final membersByProject = <String, List<dynamic>>{};
        for (final member in allMembersResponse) {
          final projectId = member['project_id'] as String?;
          if (projectId != null) {
            membersByProject.putIfAbsent(projectId, () => []).add(member);
          }
        }

        // Adicionar membros aos projetos
        for (final project in projects) {
          final projectId = project['id'] as String;
          final members = membersByProject[projectId] ?? [];

          // Extrair profiles dos membros
          final people = members
              .map((m) => m['profiles'] as Map<String, dynamic>?)
              .whereType<Map<String, dynamic>>()
              .toList();

          project['team_members'] = people;
        }
      }

      final tasks = await favoritesModule.getFavoriteTasks();
      debugPrint('✅ Tarefas favoritas: ${tasks.length}');

      // Ordenar tarefas por data de criação (mais recente primeiro)
      tasks.sort((a, b) {
        final dateA = a['created_at'] != null ? DateTime.tryParse(a['created_at']) : null;
        final dateB = b['created_at'] != null ? DateTime.tryParse(b['created_at']) : null;
        if (dateA == null && dateB == null) return 0;
        if (dateA == null) return 1;
        if (dateB == null) return -1;
        return dateB.compareTo(dateA); // Ordem decrescente (mais recente primeiro)
      });

      final subtasks = await favoritesModule.getFavoriteSubTasks();
      debugPrint('➡️ Subtarefas favoritas: ${subtasks.length}');

      // Combinar tarefas e subtarefas em uma única lista
      final allTasks = [...tasks, ...subtasks];

      // Ordenar todas as tarefas por data de criação (mais recente primeiro)
      allTasks.sort((a, b) {
        final dateA = a['created_at'] != null ? DateTime.tryParse(a['created_at']) : null;
        final dateB = b['created_at'] != null ? DateTime.tryParse(b['created_at']) : null;
        if (dateA == null && dateB == null) return 0;
        if (dateA == null) return 1;
        if (dateB == null) return -1;
        return dateB.compareTo(dateA); // Ordem decrescente (mais recente primeiro)
      });

      // Enriquecer tarefas com perfis de responsáveis
      await enrichTasksWithAssignees(allTasks);

      return {
        'projects': projects,
        'tasks': allTasks,
      };
    } catch (e) {
      debugPrint('❌ Erro ao carregar favoritos: $e');
      return {
        'projects': [],
        'tasks': [],
      };
    }
  }

  /// Carrega tarefas atribuídas ao usuário que vencem nesta semana (segunda a domingo) + tarefas atrasadas
  Future<List<Map<String, dynamic>>> _loadWeekTasks() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) {
        debugPrint('❌ Usuário não autenticado');
        return [];
      }

      // Calcular início e fim da semana (segunda a domingo)
      final now = DateTime.now();
      final currentWeekday = now.weekday; // 1 = segunda, 7 = domingo

      // Início da semana (segunda-feira às 00:00:00)
      final startOfWeek = DateTime(now.year, now.month, now.day)
          .subtract(Duration(days: currentWeekday - 1));

      // Fim da semana (domingo às 23:59:59)
      final endOfWeek = startOfWeek
          .add(const Duration(days: 6, hours: 23, minutes: 59, seconds: 59));

      debugPrint('📅 Buscando tarefas da semana: ${startOfWeek.toIso8601String()} até ${endOfWeek.toIso8601String()}');

      // Buscar tarefas atribuídas ao usuário que vencem nesta semana OU estão atrasadas
      // Inclui tarefas onde o usuário está em assigned_to OU no array assignee_user_ids
      final response = await Supabase.instance.client
          .from('tasks')
          .select('''
            id,
            title,
            description,
            status,
            priority,
            due_date,
            created_at,
            updated_at,
            updated_by,
            completed_at,
            project_id,
            assigned_to,
            assignee_user_ids,
            parent_task_id,
            projects:project_id(id, name, client_id),
            assignee_profile:assigned_to(id, full_name, avatar_url),
            updated_by_profile:updated_by(id, full_name, avatar_url)
          ''')
          .or('assigned_to.eq.$userId,assignee_user_ids.cs.{$userId}') // Responsável principal OU múltiplos responsáveis
          .lte('due_date', endOfWeek.toIso8601String()) // Até o fim da semana (inclui atrasadas)
          .neq('status', 'completed') // Excluir tarefas concluídas
          .order('due_date', ascending: true);

      final allTasks = List<Map<String, dynamic>>.from(response);

      // Filtrar para incluir apenas: tarefas da semana + tarefas atrasadas
      final tasks = allTasks.where((task) {
        final dueDate = task['due_date'] != null ? DateTime.tryParse(task['due_date']) : null;
        if (dueDate == null) return false;

        // Incluir se estiver atrasada (antes do início da semana) OU dentro da semana
        return dueDate.isBefore(startOfWeek) ||
               (dueDate.isAfter(startOfWeek.subtract(const Duration(seconds: 1))) &&
                dueDate.isBefore(endOfWeek.add(const Duration(seconds: 1))));
      }).toList();

      debugPrint('✅ Tarefas da semana (incluindo atrasadas): ${tasks.length}');

      // Enriquecer tarefas com perfis de responsáveis
      await enrichTasksWithAssignees(tasks);

      return tasks;
    } catch (e) {
      debugPrint('❌ Erro ao carregar tarefas da semana: $e');
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, List<Map<String, dynamic>>>>(
      future: _favoritesFuture,
      builder: (context, favoritesSnapshot) {
        if (favoritesSnapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }

        final favorites = favoritesSnapshot.data ?? {
          'projects': [],
          'tasks': [],
        };

        final favoriteProjects = favorites['projects'] ?? [];
        final favoriteTasks = favorites['tasks'] ?? [];

        return FutureBuilder<List<Map<String, dynamic>>>(
          future: _weekTasksFuture,
          builder: (context, weekTasksSnapshot) {
            final weekTasks = weekTasksSnapshot.data ?? [];

            return SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Card de Tarefas da Semana
                    Container(
                  decoration: BoxDecoration(
                    color: UIConst.sectionBg,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: UIConst.sectionBorder,
                      width: 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header do Card
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: Row(
                          children: [
                            // Título
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Minhas Tarefas da Semana',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Inclui tarefas atrasadas e da semana atual',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Botão de mais opções
                            IconOnlyButton(
                              icon: Icons.more_horiz,
                              onPressed: () {},
                              iconSize: 20,
                              variant: IconButtonVariant.standard,
                            ),
                          ],
                        ),
                      ),

                      // Tabela de Tarefas da Semana
                      SizedBox(
                        height: 400,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: weekTasksSnapshot.connectionState != ConnectionState.done
                              ? const Center(child: CircularProgressIndicator())
                              : _buildWeekTasksTable(weekTasks),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Card de Favoritos
                Container(
                  decoration: BoxDecoration(
                    color: UIConst.sectionBg,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: UIConst.sectionBorder,
                      width: 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header do Card
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: Row(
                          children: [
                            // Título
                            const Expanded(
                              child: Text(
                                'Meus Favoritos',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            // Botão de mais opções
                            IconOnlyButton(
                              icon: Icons.more_horiz,
                              onPressed: () {},
                              iconSize: 20,
                              variant: IconButtonVariant.standard,
                            ),
                          ],
                        ),
                      ),

                      // Tabs
                      Container(
                        decoration: const BoxDecoration(
                          border: Border(
                            bottom: BorderSide(
                              color: Color(0xFF2D2D2D),
                              width: 1,
                            ),
                          ),
                        ),
                        child: TabBar(
                          controller: _tabController,
                          indicatorColor: Colors.white,
                          indicatorWeight: 2,
                          labelColor: Colors.white,
                          unselectedLabelColor: const Color(0xFF9AA0A6),
                          labelPadding: const EdgeInsets.only(right: 20),
                          padding: const EdgeInsets.only(left: 20),
                          isScrollable: true,
                          tabAlignment: TabAlignment.start,
                          tabs: const [
                            Tab(text: 'Tarefas'),
                            Tab(text: 'Projetos'),
                          ],
                        ),
                      ),

                      // Lista de Favoritos
                      SizedBox(
                        height: 400,
                        child: TabBarView(
                          controller: _tabController,
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 20),
                              child: _buildFavoritesList(context, favoriteTasks, 'task'),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 20),
                              child: _buildFavoritesList(context, favoriteProjects, 'project'),
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
        );
          },
        );
      },
    );
  }

  Widget _buildFavoritesList(
    BuildContext context,
    List<Map<String, dynamic>> items,
    String type,
  ) {
    if (items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.star_border,
                size: 48,
                color: Colors.grey.shade700,
              ),
              const SizedBox(height: 12),
              Text(
                'Nenhum favorito ainda',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Definir colunas e builders baseado no tipo
    switch (type) {
      case 'project':
        return _buildProjectsTable(items);
      case 'task':
      case 'subtask':
        return _buildTasksTable(items);
      default:
        return const SizedBox();
    }
  }

  Widget _buildProjectsTable(List<Map<String, dynamic>> projects) {
    final appState = AppStateScope.of(context);
    final canViewFinancial = appState.isAdmin || appState.isGestor || appState.isFinanceiro;

    // Colunas dinâmicas baseadas em permissão
    final columns = [
      const DataTableColumn(label: 'Nome', sortable: true, flex: 2),
      const DataTableColumn(label: 'Cliente', sortable: true),
      if (canViewFinancial) const DataTableColumn(label: 'Valor', sortable: true),
      const DataTableColumn(label: 'Status', sortable: true),
      const DataTableColumn(label: 'Membros', sortable: false),
      const DataTableColumn(label: 'Atualizado', sortable: true),
    ];

    // Cell builders dinâmicos baseados em permissão
    final cellBuilders = [
      (p) => Text(p['name'] ?? ''),
      (p) => TableCellAvatar(
        avatarUrl: p['clients']?['avatar_url'],
        name: p['clients']?['name'] ?? '-',
        size: 12,
      ),
      if (canViewFinancial)
        (p) => TableCellCurrency(
          valueCents: p['value_cents'],
          currencyCode: p['currency_code'] ?? 'BRL',
        ),
      (p) => ProjectStatusBadge(status: p['status'] ?? 'not_started'),
      (p) => ResponsibleCell(
        people: p['team_members'],
        singleAvatarSize: 20,
        multipleAvatarSize: 10,
      ),
      (p) => TableCellUpdatedBy(
        date: p['updated_at'],
        profile: p['updated_by_profile'],
      ),
    ];

    return DynamicPaginatedTable<Map<String, dynamic>>(
      items: projects,
      itemLabel: 'projeto(s)',
      selectedIds: const {},
      columns: columns,
      sortComparators: _getProjectSortComparators(canViewFinancial),
      cellBuilders: cellBuilders,
      getId: (p) => p['id'] as String,
      onRowTap: (p) => _openItem(context, p, 'project'),
      showCheckboxes: false,
    );
  }

  Widget _buildTasksTable(List<Map<String, dynamic>> tasks) {
    return DynamicPaginatedTable<Map<String, dynamic>>(
      items: tasks,
      itemLabel: 'tarefa(s)',
      selectedIds: const {},
      dimCompletedTasks: true,
      getStatus: (t) => t['status'] as String?,
      columns: const [
        DataTableColumn(label: 'Título', sortable: true, flex: 2),
        DataTableColumn(label: 'Projeto', sortable: true),
        DataTableColumn(label: 'Responsável', sortable: true),
        DataTableColumn(label: 'Status', sortable: true),
        DataTableColumn(label: 'Prioridade', sortable: true),
        DataTableColumn(label: 'Vencimento', sortable: true),
        DataTableColumn(label: 'Criado', sortable: true),
        DataTableColumn(label: 'Atualizado', sortable: true),
      ],
      sortComparators: _getTaskSortComparators(),
      externalSortColumnIndex: 6, // Coluna "Criado"
      externalSortAscending: false, // Ordem decrescente (mais recente primeiro)
      onSort: (columnIndex, ascending) {
        // Callback vazio para ativar controle externo de ordenação
        // A ordenação já foi aplicada nos dados antes de passar para a tabela
      },
      cellBuilders: [
        (t) => Text(t['title'] ?? ''),
        (t) => Text(t['projects']?['name'] ?? '-'),
        (t) => ResponsibleCell(
          people: t['assignees_list'],
          singleAvatarSize: 20,
          multipleAvatarSize: 10,
        ),
        (t) => TaskStatusBadge(status: t['status'] ?? 'todo'),
        (t) => TaskPriorityBadge(priority: t['priority'] ?? 'medium'),
        (t) => TableCellDueDate(
          dueDate: t['due_date'],
          status: t['status'],
        ),
        (t) {
          final createdAt = t['created_at'];
          if (createdAt == null) return const Text('-');
          final date = DateTime.tryParse(createdAt);
          if (date == null) return const Text('-');
          return Text(
            '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}',
            style: const TextStyle(fontSize: 12),
          );
        },
        (t) => TableCellUpdatedBy(
          date: t['updated_at'],
          profile: t['updated_by_profile'],
        ),
      ],
      getId: (t) => t['id'] as String,
      onRowTap: (t) {
        // Determinar o tipo baseado em parent_task_id
        final type = t['parent_task_id'] != null ? 'subtask' : 'task';
        _openItem(context, t, type);
      },
      showCheckboxes: false,
    );
  }

  Widget _buildWeekTasksTable(List<Map<String, dynamic>> tasks) {
    if (tasks.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.calendar_today,
                size: 48,
                color: Colors.grey.shade700,
              ),
              const SizedBox(height: 12),
              Text(
                'Nenhuma tarefa para esta semana',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return DynamicPaginatedTable<Map<String, dynamic>>(
      items: tasks,
      itemLabel: 'tarefa(s)',
      selectedIds: const {},
      dimCompletedTasks: true,
      getStatus: (t) => t['status'] as String?,
      columns: const [
        DataTableColumn(label: 'Título', sortable: true, flex: 2),
        DataTableColumn(label: 'Projeto', sortable: true),
        DataTableColumn(label: 'Responsável', sortable: true),
        DataTableColumn(label: 'Status', sortable: true),
        DataTableColumn(label: 'Prioridade', sortable: true),
        DataTableColumn(label: 'Vencimento', sortable: true),
        DataTableColumn(label: 'Atualizado', sortable: true),
      ],
      sortComparators: _getWeekTaskSortComparators(),
      externalSortColumnIndex: 5, // Coluna "Vencimento"
      externalSortAscending: true, // Ordem crescente (mais próximo primeiro)
      onSort: (columnIndex, ascending) {
        // Callback vazio para ativar controle externo de ordenação
      },
      cellBuilders: [
        (t) => Text(t['title'] ?? ''),
        (t) => Text(t['projects']?['name'] ?? '-'),
        (t) => ResponsibleCell(
          people: t['assignees_list'],
          singleAvatarSize: 20,
          multipleAvatarSize: 10,
        ),
        (t) => TaskStatusBadge(status: t['status'] ?? 'todo'),
        (t) => TaskPriorityBadge(priority: t['priority'] ?? 'medium'),
        (t) => TableCellDueDate(
          dueDate: t['due_date'],
          status: t['status'],
        ),
        (t) => TableCellUpdatedBy(
          date: t['updated_at'],
          profile: t['updated_by_profile'],
        ),
      ],
      getId: (t) => t['id'] as String,
      onRowTap: (t) {
        final type = t['parent_task_id'] != null ? 'subtask' : 'task';
        _openItem(context, t, type);
      },
      showCheckboxes: false,
    );
  }

  // Comparadores de ordenação para projetos
  List<int Function(Map<String, dynamic>, Map<String, dynamic>)> _getProjectSortComparators(bool canViewFinancial) {
    return [
      // Nome
      (a, b) => (a['name'] ?? '').toString().toLowerCase()
          .compareTo((b['name'] ?? '').toString().toLowerCase()),
      // Cliente
      (a, b) => (a['clients']?['name'] ?? '').toString().toLowerCase()
          .compareTo((b['clients']?['name'] ?? '').toString().toLowerCase()),
      // Valor (só se tiver permissão)
      if (canViewFinancial)
        (a, b) {
          final valueA = a['value_cents'] as int? ?? 0;
          final valueB = b['value_cents'] as int? ?? 0;
          return valueA.compareTo(valueB);
        },
      // Status
      (a, b) => (a['status'] ?? '').toString()
          .compareTo((b['status'] ?? '').toString()),
      // Pessoas (não ordenável)
      (a, b) => 0,
      // Atualizado
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

  // Comparadores de ordenação para tarefas
  List<int Function(Map<String, dynamic>, Map<String, dynamic>)> _getTaskSortComparators() {
    return [
      compareByTitle,
      compareByProjectName,
      compareByAssignee,
      compareByStatus,
      compareByPriority,
      compareByDueDate,
      compareByCreatedAt,
      compareByUpdatedAt,
    ];
  }

  // Comparadores de ordenação para tarefas da semana
  List<int Function(Map<String, dynamic>, Map<String, dynamic>)> _getWeekTaskSortComparators() {
    return [
      compareByTitle,
      compareByProjectName,
      compareByAssignee,
      compareByStatus,
      compareByPriority,
      compareByDueDate,
      compareByUpdatedAt,
    ];
  }

  void _openItem(BuildContext context, Map<String, dynamic> item, String type) {
    final tabManager = TabManagerScope.maybeOf(context);
    if (tabManager == null) return;

    final itemId = item['id'] as String;
    final currentTab = tabManager.currentTab;

    switch (type) {
      case 'project':
        final tab = TabItem(
          id: 'project_$itemId',
          title: item['name'] ?? 'Projeto',
          icon: Icons.folder,
          page: ProjectDetailPage(projectId: itemId),
          canClose: true,
          selectedMenuIndex: currentTab?.selectedMenuIndex ?? 0, // Preserva o índice do menu
        );
        tabManager.updateTab(tabManager.currentIndex, tab);
        break;
      case 'task':
      case 'subtask':
        final tab = TabItem(
          id: 'task_$itemId',
          title: item['title'] ?? 'Tarefa',
          icon: Icons.task,
          page: TaskDetailPage(taskId: itemId),
          canClose: true,
          selectedMenuIndex: currentTab?.selectedMenuIndex ?? 0, // Preserva o índice do menu
        );
        tabManager.updateTab(tabManager.currentIndex, tab);
        break;
    }
  }
}

