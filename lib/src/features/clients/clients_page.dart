import 'package:flutter/material.dart';
import '../../state/app_state_scope.dart';
import 'client_detail_page.dart';
import '../../navigation/route_observer.dart';
import '../../navigation/tab_manager_scope.dart';
import '../../navigation/tab_item.dart';
import 'package:my_business/ui/organisms/tables/reusable_data_table.dart';
import '../../../ui/organisms/dialogs/standard_dialog.dart';
import 'package:my_business/ui/organisms/tables/table_search_filter_bar.dart';
import 'package:my_business/ui/molecules/table_cells/table_cells.dart';
import 'widgets/client_form.dart';
import '../../../modules/modules.dart';
import '../../mixins/table_state_mixin.dart';
import '../../utils/table_utils.dart';
import 'package:my_business/ui/organisms/tables/dynamic_paginated_table.dart';
import 'package:my_business/ui/atoms/badges/status_badge.dart';
import 'package:my_business/constants/client_status.dart';


class ClientsPage extends StatefulWidget {
  const ClientsPage({super.key});

  @override
  State<ClientsPage> createState() => _ClientsPageState();
}

class _ClientsPageState extends State<ClientsPage>
    with TableStateMixin<Map<String, dynamic>>, RouteAware {

  @override
  void initState() {
    super.initState();
    loadData();
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
    reloadData();
  }

  // ============================================================================
  // IMPLEMENTAÇÃO DO MIXIN
  // ============================================================================

  @override
  Future<List<Map<String, dynamic>>> fetchData() async {
    final clients = await clientsModule.getClients();
    return clients;
  }

  @override
  List<String> get searchFields => ['name', 'email', 'phone'];

  @override
  List<int Function(Map<String, dynamic>, Map<String, dynamic>)> get sortComparators {
    return [
      TableUtils.textComparator('name'),
      TableUtils.textComparator('status'),
      TableUtils.textComparator('client_categories.name'),
      TableUtils.textComparator('country'),
      TableUtils.textComparator('state'),
      TableUtils.textComparator('city'),
      TableUtils.dateComparator('created_at'),
    ];
  }

  @override
  bool applyCustomFilter(Map<String, dynamic> item) {
    if (filterType == 'none' || filterValue == null || filterValue!.isEmpty) {
      return true;
    }

    switch (filterType) {
      case 'status':
        return item['status'] == filterValue;
      case 'country':
        return item['country'] == filterValue;
      case 'state':
        return item['state'] == filterValue;
      case 'city':
        return item['city'] == filterValue;
      case 'category':
        return item['client_categories']?['name'] == filterValue ||
               item['category'] == filterValue;
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
        message: 'Deseja realmente excluir ${selectedIds.length} cliente(s) selecionado(s)?',
        confirmText: 'Excluir',
        isDestructive: true,
      ),
    );

    if (confirm != true) return;

    try {
      for (final id in selectedIds) {
        await clientsModule.deleteClient(id);
      }

      clearSelection();
      await reloadData();

      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('Clientes excluídos com sucesso')),
      );
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('Erro ao excluir: $e')),
      );
    }
  }

  Future<void> _openForm({Map<String, dynamic>? initial}) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => ClientForm(initial: initial),
    );

    if (saved == true) {
      await reloadData();
    }
  }

  Future<void> _duplicate(Map<String, dynamic> client) async {
    final messenger = ScaffoldMessenger.of(context);

    try {
      final formData = Map<String, dynamic>.from(client);
      formData.remove('id');
      formData.remove('created_at');
      formData.remove('updated_at');
      formData.remove('client_categories');

      if (formData['name'] != null) {
        formData['name'] = '${formData['name']} (Cópia)';
      }

      await clientsModule.createClient(
        name: formData['name'] ?? '',
        email: formData['email'],
        phone: formData['phone'],
        company: formData['company'],
        address: formData['address'],
        city: formData['city'],
        state: formData['state'],
        zipCode: formData['zip_code'],
        country: formData['country'],
        website: formData['website'],
        notes: formData['notes'],
        status: formData['status'] ?? 'active',
        avatarUrl: formData['avatar_url'],
        categoryId: formData['category_id'],
      );

      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('Cliente duplicado com sucesso')),
      );
      await reloadData();
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('Erro ao duplicar: $e')),
      );
    }
  }

  Future<void> _delete(String id, String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => ConfirmDialog(
        title: 'Confirmar Exclusão',
        message: 'Deseja realmente excluir o cliente "$name"?',
        confirmText: 'Excluir',
        isDestructive: true,
      ),
    );

    if (confirm != true) return;

    await clientsModule.deleteClient(id);
    await reloadData();
  }

  List<String> _getFilterOptions() {
    switch (filterType) {
      case 'status':
        return ClientStatus.values;
      case 'country':
        return getUniqueValues('country');
      case 'state':
        return getUniqueValues('state');
      case 'city':
        return getUniqueValues('city');
      case 'category':
        final categories = allData
            .map((c) => c['client_categories']?['name'] as String? ?? c['category'] as String?)
            .whereType<String>()
            .where((c) => c.isNotEmpty)
            .toSet()
            .toList();
        categories.sort();
        return categories;
      default:
        return [];
    }
  }

  String _getFilterLabel() {
    switch (filterType) {
      case 'status':
        return 'Filtrar por status';
      case 'country':
        return 'Filtrar por país';
      case 'state':
        return 'Filtrar por estado';
      case 'city':
        return 'Filtrar por cidade';
      case 'category':
        return 'Filtrar por categoria';
      default:
        return 'Filtrar';
    }
  }

  String _getStatusDisplayName(String status) {
    return ClientStatus.getLabel(status);
  }



  @override
  Widget build(BuildContext context) {
    final appState = AppStateScope.of(context);

    // Verificar permissão: apenas Admin, Gestor e Financeiro
    if (!appState.isAdmin && !appState.isGestor && !appState.isFinanceiro) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.lock_outline,
                size: 64,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(height: 16),
              Text(
                'Acesso Negado',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'Apenas Administradores, Gestores e Financeiros podem acessar a página de Clientes.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
          ),
        ),
      );
    }

    // Usar novo sistema de permissões baseado em organização
    final permissions = appState.permissions;
    final canEdit = permissions.canEditClients;
    final canDelete = permissions.canDeleteClients;
    final canCreate = permissions.canCreateClients;
    final canDuplicate = permissions.canEditClients; // Duplicar requer mesma permissão que editar

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
                  searchHint: 'Buscar cliente (nome, email ou telefone...)',
                  onSearchChanged: updateSearchQueryDebounced,
                  filterType: filterType,
                  filterTypeLabel: 'Tipo de filtro',
                  filterTypeOptions: const [
                    FilterOption(value: 'none', label: 'Nenhum'),
                    FilterOption(value: 'status', label: 'Status'),
                    FilterOption(value: 'country', label: 'País'),
                    FilterOption(value: 'state', label: 'Estado'),
                    FilterOption(value: 'city', label: 'Cidade'),
                    FilterOption(value: 'category', label: 'Categoria'),
                  ],
                  onFilterTypeChanged: (value) {
                    if (value != null) updateFilterType(value);
                  },
                  filterValue: filterValue,
                  filterValueLabel: _getFilterLabel(),
                  filterValueOptions: _getFilterOptions(),
                  onFilterValueChanged: updateFilterValue,
                  filterValueLabelBuilder: filterType == 'status' ? _getStatusDisplayName : null,
                  selectedCount: selectedIds.length,
                  bulkActions: canDelete ? [
                    BulkAction(
                      icon: Icons.delete,
                      label: 'Excluir selecionados',
                      color: Colors.red,
                      onPressed: _bulkDelete,
                    ),
                  ] : null,
                  actionButton: canCreate ? FilledButton.icon(
                    onPressed: () => _openForm(),
                    icon: const Icon(Icons.add),
                    label: const Text('Novo Cliente'),
                  ) : null,
                ),

                const SizedBox(height: 16),

                // Tabela com paginação dinâmica
                Expanded(
                  child: DynamicPaginatedTable<Map<String, dynamic>>(
                    items: filteredData,
                    itemLabel: 'cliente(s)',
                    selectedIds: selectedIds,
                    onSelectionChanged: updateSelection,
                    columns: [
                      const DataTableColumn(label: 'Nome', sortable: true, flex: 2),
                      const DataTableColumn(label: 'Status', sortable: true, fixedWidth: 200),
                      const DataTableColumn(label: 'Categoria', sortable: true),
                      const DataTableColumn(label: 'País', sortable: true),
                      const DataTableColumn(label: 'Estado', sortable: true),
                      const DataTableColumn(label: 'Cidade', sortable: true),
                      const DataTableColumn(label: 'Criado', sortable: true),
                    ],
                    cellBuilders: [
                      // Nome com avatar
                      (c) => TableCellAvatar(
                        avatarUrl: c['avatar_url'],
                        name: c['name'] ?? '',
                        size: 12,
                        showInitial: true,
                      ),
                      // Status
                      (c) => StatusBadge(
                        status: c['status'] ?? 'nao_prospectado',
                      ),
                      // Categoria
                      (c) => Text(c['client_categories']?['name'] ?? c['category'] ?? '-'),
                      // País, Estado, Cidade
                      (c) => Text(c['country'] ?? '-'),
                      (c) => Text(c['state'] ?? '-'),
                      (c) => Text(c['city'] ?? '-'),
                      // Data de criação
                      (c) => TableCellDate(
                        date: c['created_at'],
                      ),
                    ],
                    getId: (c) => c['id'] as String,
                    onSort: updateSorting,
                    externalSortColumnIndex: sortColumnIndex,
                    externalSortAscending: sortAscending,
                    sortComparators: sortComparators,
                    onRowTap: (c) {
                      final tabManager = TabManagerScope.maybeOf(context);
                      if (tabManager != null) {
                        final clientId = c['id'].toString();
                        final clientName = c['name'] as String? ?? 'Cliente';
                        final tabId = 'client_$clientId';
                        final updatedTab = TabItem(
                          id: tabId,
                          title: clientName,
                          icon: Icons.person,
                          page: ClientDetailPage(
                            key: ValueKey(tabId),
                            clientId: clientId,
                          ),
                          canClose: true,
                        );
                        tabManager.updateTab(tabManager.currentIndex, updatedTab);
                      }
                    },
                    actions: [
                      if (canEdit)
                        DataTableAction(icon: Icons.edit, label: 'Editar', onPressed: (c) => _openForm(initial: c)),
                      if (canDuplicate)
                        DataTableAction(icon: Icons.content_copy, label: 'Duplicar', onPressed: _duplicate),
                      if (canDelete)
                        DataTableAction(icon: Icons.delete, label: 'Excluir', onPressed: (c) => _delete(c['id'] as String, c['name'] as String)),
                    ],
                    isLoading: isLoading,
                    hasError: errorMessage != null,
                    errorWidget: Center(child: Text('Erro: ${errorMessage ?? ""}')),
                    emptyWidget: const Center(child: Text('Nenhum cliente encontrado')),
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
        child: Text('Clientes', style: Theme.of(context).textTheme.titleLarge),
      ),
    );
  }
}

