import 'package:flutter/material.dart';
import '../../state/app_state_scope.dart';
import '../../mixins/table_state_mixin.dart';
import '../../utils/table_utils.dart';
import '../../widgets/dynamic_paginated_table.dart';
import '../../../widgets/table_search_filter_bar.dart';
import '../../../widgets/reusable_data_table.dart';
import '../../../modules/modules.dart';
import 'widgets/project_status_badge.dart';
import '../../../constants/project_status.dart';

/// EXEMPLO DE REFATORAÇÃO usando TableStateMixin
/// 
/// Este arquivo demonstra como usar o TableStateMixin para simplificar
/// o gerenciamento de estado de tabelas.
/// 
/// ANTES: ~400 linhas de código com lógica duplicada
/// DEPOIS: ~150 linhas de código reutilizando o mixin
class ProjectsPageRefactoredExample extends StatefulWidget {
  const ProjectsPageRefactoredExample({super.key});

  @override
  State<ProjectsPageRefactoredExample> createState() => _ProjectsPageRefactoredExampleState();
}

class _ProjectsPageRefactoredExampleState extends State<ProjectsPageRefactoredExample>
    with TableStateMixin<Map<String, dynamic>> {
  
  // Lista de usuários para filtro
  List<Map<String, dynamic>> _allUsers = [];

  @override
  void initState() {
    super.initState();
    _initDependencies();
  }

  Future<void> _initDependencies() async {
    await loadData();
    await _loadUsers();
  }

  // ============================================================================
  // IMPLEMENTAÇÃO DOS MÉTODOS ABSTRATOS DO MIXIN
  // ============================================================================

  @override
  Future<List<Map<String, dynamic>>> fetchData() async {
    // Using projectsModule to fetch projects
    final response = await projectsModule.getProjects();
    return response;
  }

  @override
  List<String> get searchFields => ['name', 'clients.name'];

  @override
  List<int Function(Map<String, dynamic>, Map<String, dynamic>)> get sortComparators => [
    TableUtils.textComparator('name'),
    TableUtils.textComparator('clients.name'),
    TableUtils.numericComparator('value'),
    TableUtils.textComparator('status'),
    TableUtils.dateComparator('created_at'),
  ];

  @override
  bool applyCustomFilter(Map<String, dynamic> item) {
    // Se não há filtro selecionado, retorna true
    if (filterType == 'none' || filterValue == null || filterValue!.isEmpty) {
      return true;
    }

    switch (filterType) {
      case 'status':
        return item['status'] == filterValue;

      case 'client':
        return item['clients']?['name'] == filterValue;

      case 'value':
        final value = item['value'] as num?;
        if (value == null) return false;

        switch (filterValue) {
          case 'low':
            return value <= 1000;
          case 'medium':
            return value > 1000 && value <= 10000;
          case 'high':
            return value > 10000 && value <= 50000;
          case 'very_high':
            return value > 50000;
          default:
            return true;
        }

      case 'person':
        return item['owner_id'] == filterValue;

      default:
        return true;
    }
  }

  // ============================================================================
  // MÉTODOS AUXILIARES
  // ============================================================================

  Future<void> _loadUsers() async {
    try {
      final response = await usersModule.getAllProfiles();

      if (!mounted) return;
      setState(() {
        _allUsers = response;
      });
    } catch (e) {
      // Error loading users - silently fail for this example
      if (!mounted) return;
      setState(() {
        _allUsers = [];
      });
    }
  }

  List<String> _getFilterOptions() {
    switch (filterType) {
      case 'status':
        return ProjectStatus.values;
      case 'client':
        return getUniqueValues('clients.name');
      case 'value':
        return ['low', 'medium', 'high', 'very_high'];
      case 'person':
        return _allUsers.map((u) => u['id'] as String).toList();
      default:
        return [];
    }
  }

  String _getFilterLabel() {
    switch (filterType) {
      case 'status':
        return 'Status';
      case 'client':
        return 'Cliente';
      case 'value':
        return 'Faixa de valor';
      case 'person':
        return 'Pessoa';
      default:
        return '';
    }
  }

  String _getFilterValueLabel(String value) {
    switch (filterType) {
      case 'status':
        return ProjectStatus.getLabel(value);
      case 'value':
        switch (value) {
          case 'low':
            return 'Até R\$ 1.000';
          case 'medium':
            return 'R\$ 1.001 - R\$ 10.000';
          case 'high':
            return 'R\$ 10.001 - R\$ 50.000';
          case 'very_high':
            return 'Acima de R\$ 50.000';
          default:
            return value;
        }
      case 'person':
        final user = _allUsers.firstWhere(
          (u) => u['id'] == value,
          orElse: () => {'username': value},
        );
        return user['username'] as String? ?? value;
      default:
        return value;
    }
  }

  // ============================================================================
  // BUILD
  // ============================================================================

  @override
  Widget build(BuildContext context) {
    final appState = AppStateScope.of(context);
    final isLogged = authModule.currentUser != null;

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
                // Barra de busca e filtros
                TableSearchFilterBar(
                  searchHint: 'Buscar projeto (nome ou cliente...)',
                  onSearchChanged: updateSearchQuery,
                  filterType: filterType,
                  filterTypeLabel: 'Tipo de filtro',
                  filterTypeOptions: const [
                    FilterOption(value: 'none', label: 'Nenhum'),
                    FilterOption(value: 'status', label: 'Status'),
                    FilterOption(value: 'client', label: 'Cliente'),
                    FilterOption(value: 'value', label: 'Valor'),
                    FilterOption(value: 'person', label: 'Pessoa'),
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
                  bulkActions: (isLogged && appState.isAdminOrGestor)
                      ? [
                          BulkAction(
                            icon: Icons.delete,
                            label: 'Excluir selecionados',
                            color: Colors.red,
                            onPressed: () {
                              // Implementar exclusão em lote
                            },
                          ),
                        ]
                      : null,
                  actionButton: (isLogged && (appState.isAdmin || appState.isDesigner))
                      ? FilledButton.icon(
                          onPressed: () {
                            // Abrir formulário de novo projeto
                          },
                          icon: const Icon(Icons.add),
                          label: const Text('Novo Projeto'),
                        )
                      : null,
                ),

                const SizedBox(height: 16),

                // Tabela com paginação dinâmica
                Expanded(
                  child: DynamicPaginatedTable<Map<String, dynamic>>(
                    items: filteredData,
                    itemLabel: 'projeto(s)',
                    selectedIds: selectedIds,
                    onSelectionChanged: updateSelection,
                    columns: const [
                      DataTableColumn(label: 'Nome', sortable: true),
                      DataTableColumn(label: 'Cliente', sortable: true),
                      DataTableColumn(label: 'Valor', sortable: true),
                      DataTableColumn(label: 'Status', sortable: true),
                      DataTableColumn(label: 'Criado em', sortable: true),
                    ],
                    onSort: updateSorting,
                    externalSortColumnIndex: sortColumnIndex,
                    externalSortAscending: sortAscending,
                    sortComparators: sortComparators,
                    cellBuilders: [
                      (p) => Text(p['name'] ?? ''),
                      (p) => Text(p['clients']?['name'] ?? '-'),
                      (p) {
                        final value = p['value'] as num? ?? 0;
                        if (value == 0) return const Text('-');
                        return Text('R\$ ${value.toStringAsFixed(2)}');
                      },
                      (p) => ProjectStatusBadge(status: p['status'] ?? 'not_started'),
                      (p) {
                        final date = p['created_at'] != null
                            ? DateTime.tryParse(p['created_at'])
                            : null;
                        if (date == null) return const Text('-');
                        return Text('${date.day}/${date.month}/${date.year}');
                      },
                    ],
                    getId: (p) => p['id'] as String,
                    onRowTap: (p) {
                      // Navegar para detalhes
                    },
                    actions: [
                      DataTableAction<Map<String, dynamic>>(
                        icon: Icons.edit,
                        label: 'Editar',
                        onPressed: (p) {
                          // Editar projeto
                        },
                        showWhen: (p) => appState.isAdmin || appState.isDesigner,
                      ),
                    ],
                    isLoading: isLoading,
                    hasError: errorMessage != null,
                    errorWidget: Center(
                      child: Text('Erro: ${errorMessage ?? ""}'),
                    ),
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
      child: Row(
        children: [
          Text('Projetos', style: Theme.of(context).textTheme.titleLarge),
        ],
      ),
    );
  }
}

