import 'package:flutter/material.dart';
import '../../state/app_state_scope.dart';
import '../../navigation/route_observer.dart';
import 'package:my_business/ui/organisms/tables/reusable_data_table.dart';
import '../../../ui/organisms/dialogs/standard_dialog.dart';
import 'package:my_business/ui/organisms/tables/table_search_filter_bar.dart';
import '../../../modules/modules.dart';
import '../../mixins/table_state_mixin.dart';
import 'package:my_business/ui/organisms/tables/dynamic_paginated_table.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../utils/task_helpers.dart';
import '../../utils/table_comparators.dart';
import '../../utils/navigation_helpers.dart';
import '../projects/widgets/task_table_helpers.dart';


class TasksPage extends StatefulWidget {
  const TasksPage({super.key});

  @override
  State<TasksPage> createState() => _TasksPageState();
}

class _TasksPageState extends State<TasksPage>
    with TableStateMixin<Map<String, dynamic>>, RouteAware {

  @override
  void initState() {
    super.initState();
    // Configurar ordenação padrão por "Criado" (coluna 6) em ordem decrescente
    sortColumnIndex = 6;
    sortAscending = false;
    _initData();
  }

  Future<void> _initData() async {
    // Atualizar prioridades antes de carregar
    try {
      await tasksModule.updateTasksPriorityByDueDate();
    } catch (e) {
      // Error updating priorities - silently continue
    }
    await loadData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute) {
      routeObserver.subscribe(this, route);
    }
  }

  @override
  void dispose() {
    cancelSearchDebounce();
    routeObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  void didPopNext() {
    _initData();
  }

  // ============================================================================
  // IMPLEMENTAÇÃO DO MIXIN
  // ============================================================================

  @override
  Future<List<Map<String, dynamic>>> fetchData() async {
    final tasks = await tasksModule.getTasks(offset: 0, limit: 1000);

    // Enriquecer tarefas com perfis de responsáveis
    await enrichTasksWithAssignees(tasks);

    return tasks;
  }

  @override
  List<String> get searchFields => ['title', 'projects.name'];

  @override
  List<int Function(Map<String, dynamic>, Map<String, dynamic>)> get sortComparators => [
    compareByTitle,
    compareByProjectName,
    compareByStatus,
    compareByPriority,
    compareByDueDate,
    (a, b) => 0, // Responsável não ordenável
    compareByCreatedAt,
    compareByUpdatedAt,
  ];

  @override
  bool applyCustomFilter(Map<String, dynamic> item) {
    if (filterType == 'none' || filterValue == null || filterValue!.isEmpty) {
      return true;
    }

    switch (filterType) {
      case 'status':
        return item['status'] == filterValue;
      case 'priority':
        return item['priority'] == filterValue;
      case 'project':
        return item['projects']?['name'] == filterValue;
      default:
        return true;
    }
  }

  // ============================================================================
  // MÉTODOS AUXILIARES
  // ============================================================================

  Future<void> _bulkDelete() async {
    if (selectedIds.isEmpty) return;

    final messenger = ScaffoldMessenger.of(context);

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => ConfirmDialog(
        title: 'Confirmar Exclusão',
        message: 'Deseja realmente excluir ${selectedIds.length} tarefa(s) selecionada(s)?',
        confirmText: 'Excluir',
        isDestructive: true,
      ),
    );

    if (confirm != true) return;

    try {
      for (final id in selectedIds) {
        await tasksModule.deleteTask(id);
      }

      clearSelection();
      await reloadData();

      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('Tarefas excluídas com sucesso')),
      );
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('Erro ao excluir: $e')),
      );
    }
  }

  Future<void> _delete(String id, String title) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => ConfirmDialog(
        title: 'Confirmar Exclusão',
        message: 'Deseja realmente excluir a tarefa "$title"?',
        confirmText: 'Excluir',
        isDestructive: true,
      ),
    );

    if (confirm != true) return;

    await tasksModule.deleteTask(id);
    await reloadData();
  }

  List<String> _getFilterOptions() {
    switch (filterType) {
      case 'status':
        return ['pending', 'in_progress', 'completed', 'cancelled'];
      case 'priority':
        return ['low', 'medium', 'high', 'urgent'];
      case 'project':
        return getUniqueValues('projects.name');
      default:
        return [];
    }
  }

  String _getFilterLabel() {
    switch (filterType) {
      case 'status':
        return 'Filtrar por status';
      case 'priority':
        return 'Filtrar por prioridade';
      case 'project':
        return 'Filtrar por projeto';
      default:
        return 'Filtrar';
    }
  }

  String _getFilterValueLabel(String value) {
    switch (filterType) {
      case 'status':
        const statusLabels = {
          'pending': 'Pendente',
          'in_progress': 'Em Progresso',
          'completed': 'Concluída',
          'cancelled': 'Cancelada',
        };
        return statusLabels[value] ?? value;
      case 'priority':
        const priorityLabels = {
          'low': 'Baixa',
          'medium': 'Média',
          'high': 'Alta',
          'urgent': 'Urgente',
        };
        return priorityLabels[value] ?? value;
      default:
        return value;
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = AppStateScope.of(context);
    final permissions = appState.permissions;
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;

    return Column(
      children: [
        const _Header(),
        const Divider(height: 1),

        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TableSearchFilterBar(
                  searchHint: 'Buscar tarefa (título ou projeto...)',
                  onSearchChanged: updateSearchQueryDebounced,
                  filterType: filterType,
                  filterTypeLabel: 'Tipo de filtro',
                  filterTypeOptions: const [
                    FilterOption(value: 'none', label: 'Nenhum'),
                    FilterOption(value: 'status', label: 'Status'),
                    FilterOption(value: 'priority', label: 'Prioridade'),
                    FilterOption(value: 'project', label: 'Projeto'),
                  ],
                  onFilterTypeChanged: (value) {
                    if (value != null) updateFilterType(value);
                  },
                  filterValue: filterValue,
                  filterValueLabel: _getFilterLabel(),
                  filterValueOptions: _getFilterOptions(),
                  filterValueLabelBuilder: _getFilterValueLabel,
                  onFilterValueChanged: updateFilterValue,
                  selectedCount: selectedIds.length,
                  bulkActions: (() {
                    // Apenas admin e gestor podem excluir tasks em lote
                    return permissions.canDeleteTasks ? [
                      BulkAction(
                        icon: Icons.delete,
                        label: 'Excluir selecionadas',
                        color: Colors.red,
                        onPressed: _bulkDelete,
                      ),
                    ] : null;
                  })(),
                  actionButton: (() {
                    return permissions.canCreateTasks ? FilledButton.icon(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Funcionalidade de criar tarefa será implementada em breve'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      },
                      icon: const Icon(Icons.add),
                      label: const Text('Nova Tarefa'),
                    ) : null;
                  })(),
                ),

                const SizedBox(height: 16),

                Expanded(
                  child: DynamicPaginatedTable<Map<String, dynamic>>(
                    items: filteredData,
                    itemLabel: 'tarefa(s)',
                    selectedIds: selectedIds,
                    onSelectionChanged: updateSelection,
                    dimCompletedTasks: true,
                    getStatus: (t) => t['status'] as String?,
                    columns: const [
                      DataTableColumn(label: 'Título', sortable: true, flex: 2),
                      DataTableColumn(label: 'Projeto', sortable: true),
                      DataTableColumn(label: 'Status', sortable: true),
                      DataTableColumn(label: 'Prioridade', sortable: true),
                      DataTableColumn(label: 'Vencimento', sortable: true),
                      DataTableColumn(label: 'Responsável', sortable: false),
                      DataTableColumn(label: 'Criado', sortable: true),
                      DataTableColumn(label: 'Atualizado', sortable: true),
                    ],
                    cellBuilders: TaskTableHelpers.getTasksPageCellBuilders(),
                    getId: (t) => t['id'] as String,
                    onSort: updateSorting,
                    externalSortColumnIndex: sortColumnIndex,
                    externalSortAscending: sortAscending,
                    sortComparators: sortComparators,
                    onRowTap: (t) {
                      final taskId = t['id'].toString();
                      final taskTitle = t['title'] as String? ?? 'Tarefa';
                      NavigationHelpers.navigateToTaskDetail(context, taskId, taskTitle);
                    },
                    actions: [
                      DataTableAction(
                        icon: Icons.delete,
                        label: 'Excluir',
                        onPressed: (t) => _delete(t['id'] as String, t['title'] as String),
                        showWhen: (t) {
                          final taskCreatorId = t['created_by'] as String?;
                          return permissions.canDeleteTask(taskCreatorId, currentUserId);
                        },
                      ),
                    ],
                    isLoading: isLoading,
                    hasError: errorMessage != null,
                    errorWidget: Center(child: Text('Erro: ${errorMessage ?? ""}')),
                    emptyWidget: const Center(child: Text('Nenhuma tarefa encontrada')),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text('Tarefas', style: Theme.of(context).textTheme.titleLarge),
      ),
    );
  }
}
