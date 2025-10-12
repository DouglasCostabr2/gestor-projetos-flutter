import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../state/app_state_scope.dart';
import 'client_detail_page.dart';
import '../../navigation/route_observer.dart';
import '../../navigation/tab_manager_scope.dart';
import '../../navigation/tab_item.dart';
import '../../../widgets/reusable_data_table.dart';
import '../../../widgets/standard_dialog.dart';
import '../../../widgets/table_search_filter_bar.dart';
import '../../../widgets/table_cells/table_cells.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'widgets/client_form.dart';
import '../../../modules/modules.dart';
import '../../mixins/table_state_mixin.dart';
import '../../utils/table_utils.dart';
import '../../widgets/dynamic_paginated_table.dart';


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
    return await clientsModule.getClients();
  }

  @override
  List<String> get searchFields => ['name', 'email', 'phone'];

  @override
  List<int Function(Map<String, dynamic>, Map<String, dynamic>)> get sortComparators {
    final appState = AppStateScope.of(context);
    final canViewSensitiveInfo = appState.isAdminOrGestor || appState.isFinanceiro;

    return [
      TableUtils.textComparator('name'),
      TableUtils.textComparator('client_categories.name'),
      if (canViewSensitiveInfo) TableUtils.textComparator('email'),
      if (canViewSensitiveInfo) (a, b) => 0, // Telefone não ordenável
      TableUtils.textComparator('country'),
      TableUtils.textComparator('state'),
      TableUtils.textComparator('city'),
    ];
  }

  @override
  bool applyCustomFilter(Map<String, dynamic> item) {
    if (filterType == 'none' || filterValue == null || filterValue!.isEmpty) {
      return true;
    }

    switch (filterType) {
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

  Future<void> _copyEmail(String? email) async {
    if (email == null || email.isEmpty) return;

    final messenger = ScaffoldMessenger.of(context);
    await Clipboard.setData(ClipboardData(text: email));

    if (!mounted) return;
    messenger.showSnackBar(
      SnackBar(content: Text('Email copiado: $email'), duration: const Duration(seconds: 2)),
    );
  }

  Future<void> _openWhatsApp(String? phone) async {
    if (phone == null || phone.isEmpty) return;

    final messenger = ScaffoldMessenger.of(context);
    final cleanPhone = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    final url = Uri.parse('https://wa.me/$cleanPhone');

    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('Não foi possível abrir o WhatsApp')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = AppStateScope.of(context);
    final canEdit = appState.isAdminOrGestor;
    final canViewSensitiveInfo = appState.isAdminOrGestor || appState.isFinanceiro;

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
                  selectedCount: selectedIds.length,
                  bulkActions: canEdit ? [
                    BulkAction(
                      icon: Icons.delete,
                      label: 'Excluir selecionados',
                      color: Colors.red,
                      onPressed: _bulkDelete,
                    ),
                  ] : null,
                  actionButton: canEdit ? FilledButton.icon(
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
                      const DataTableColumn(label: 'Categoria', sortable: true),
                      if (canViewSensitiveInfo) const DataTableColumn(label: 'Email', sortable: true),
                      if (canViewSensitiveInfo) const DataTableColumn(label: 'Telefone'),
                      const DataTableColumn(label: 'País', sortable: true),
                      const DataTableColumn(label: 'Estado', sortable: true),
                      const DataTableColumn(label: 'Cidade', sortable: true),
                    ],
                    cellBuilders: [
                      // Nome com avatar
                      (c) => TableCellAvatar(
                        avatarUrl: c['avatar_url'],
                        name: c['name'] ?? '',
                        size: 16,
                        showInitial: false,
                      ),
                      // Categoria
                      (c) => Text(c['client_categories']?['name'] ?? c['category'] ?? '-'),
                      // Email (se permitido)
                      if (canViewSensitiveInfo) (c) => InkWell(
                        onTap: () => _copyEmail(c['email']),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.email, size: 16, color: Colors.white),
                            const SizedBox(width: 8),
                            Flexible(child: Text(c['email'] ?? '-', style: const TextStyle(color: Colors.white, overflow: TextOverflow.ellipsis))),
                          ],
                        ),
                      ),
                      // Telefone (se permitido)
                      if (canViewSensitiveInfo) (c) => InkWell(
                        onTap: () => _openWhatsApp(c['phone']),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const FaIcon(FontAwesomeIcons.whatsapp, size: 16, color: Colors.white),
                            const SizedBox(width: 8),
                            Flexible(child: Text(c['phone'] ?? '-', style: const TextStyle(color: Colors.white, overflow: TextOverflow.ellipsis))),
                          ],
                        ),
                      ),
                      // País, Estado, Cidade
                      (c) => Text(c['country'] ?? '-'),
                      (c) => Text(c['state'] ?? '-'),
                      (c) => Text(c['city'] ?? '-'),
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
                        final updatedTab = TabItem(
                          id: 'client_$clientId',
                          title: clientName,
                          icon: Icons.person,
                          page: ClientDetailPage(clientId: clientId),
                          canClose: true,
                        );
                        tabManager.updateTab(tabManager.currentIndex, updatedTab);
                      }
                    },
                    actions: canEdit ? [
                      DataTableAction(icon: Icons.edit, label: 'Editar', onPressed: (c) => _openForm(initial: c)),
                      DataTableAction(icon: Icons.content_copy, label: 'Duplicar', onPressed: _duplicate),
                      DataTableAction(icon: Icons.delete, label: 'Excluir', onPressed: (c) => _delete(c['id'] as String, c['name'] as String)),
                    ] : [],
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

