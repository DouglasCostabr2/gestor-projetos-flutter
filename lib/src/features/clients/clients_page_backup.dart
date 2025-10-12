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
import 'package:url_launcher/url_launcher.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'widgets/client_form.dart';
import '../../../modules/modules.dart';
import '../../mixins/table_state_mixin.dart';
import '../../utils/table_utils.dart';


class ClientsPage extends StatefulWidget {
  const ClientsPage({super.key});

  @override
  State<ClientsPage> createState() => _ClientsPageState();
}

class _ClientsPageState extends State<ClientsPage>
    with RouteAware, TableStateMixin<Map<String, dynamic>> {

  // Pagination variables
  int _currentPage = 0;
  final int _itemsPerPage = 20;
  final Set<String> _selected = {};
  int? _sortColumnIndex = 0;
  bool _sortAscending = true;

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
    routeObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  void didPopNext() {
    // Called when returning from a detail page
    reloadData();
  }

  // ============================================================================
  // IMPLEMENTAÇÃO DO MIXIN
  // ============================================================================

  @override
  Future<List<Map<String, dynamic>>> fetchData() async {
    final res = await clientsModule.getClients();
    return res;
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
      // Criar cópia dos dados sem campos gerados automaticamente
      final formData = Map<String, dynamic>.from(client);
      formData.remove('id');
      formData.remove('created_at');
      formData.remove('updated_at');
      formData.remove('client_categories'); // Remover relação expandida

      // Adicionar sufixo ao nome
      if (formData['name'] != null) {
        formData['name'] = '${formData['name']} (Cópia)';
      }

      // Inserir no banco de dados usando o módulo de clientes
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
        // Para categoria, precisamos buscar tanto de client_categories.name quanto category
        final categories = allData
            .map((c) => c['client_categories']?['name'] as String? ?? c['category'] as String?)
            .whereType<String>()
            .where((c) => c.isNotEmpty)
            .toSet()
            .toList();
        categories.sort();
        return categories;
      case 'none':
        return [];
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
      case 'none':
        return 'Sem filtro';
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
      SnackBar(
        content: Text('Email copiado: $email'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _openWhatsApp(String? phone) async {
    if (phone == null || phone.isEmpty) return;

    final messenger = ScaffoldMessenger.of(context);

    // Remover caracteres não numéricos
    final cleanPhone = phone.replaceAll(RegExp(r'[^0-9+]'), '');

    // URL do WhatsApp
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

  // Pagination methods
  List<Map<String, dynamic>> _getPaginatedData() {
    final startIndex = _currentPage * _itemsPerPage;
    final endIndex = (startIndex + _itemsPerPage).clamp(0, filteredData.length);

    if (startIndex >= filteredData.length) return [];

    return filteredData.sublist(startIndex, endIndex);
  }

  int get _totalPages => (filteredData.length / _itemsPerPage).ceil();

  List<int Function(Map<String, dynamic>, Map<String, dynamic>)?> _getSortComparators() {
    final appState = AppStateScope.of(context);
    final canViewSensitiveInfo = appState.isAdminOrGestor || appState.isFinanceiro;

    return [
      TableUtils.textComparator('name'),
      TableUtils.textComparator('client_categories.name'),
      if (canViewSensitiveInfo) TableUtils.textComparator('email'),
      if (canViewSensitiveInfo) null, // Telefone não ordenável
      TableUtils.textComparator('country'),
      TableUtils.textComparator('state'),
      TableUtils.textComparator('city'),
    ];
  }

  void _applySorting() {
    if (_sortColumnIndex == null) return;

    final comparators = _getSortComparators();
    if (_sortColumnIndex! >= comparators.length) return;

    final comparator = comparators[_sortColumnIndex!];
    if (comparator == null) return;

    filteredData.sort((a, b) {
      final result = comparator(a, b);
      return _sortAscending ? result : -result;
    });
  }

  Widget _buildPaginationControls() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        border: Border.all(color: const Color(0xFF3E3E3E)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Mostrando ${_currentPage * _itemsPerPage + 1}-${((_currentPage + 1) * _itemsPerPage).clamp(0, filteredData.length)} de ${filteredData.length}',
            style: const TextStyle(color: Colors.white70),
          ),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: _currentPage > 0
                    ? () => setState(() => _currentPage--)
                    : null,
              ),
              Text(
                'Página ${_currentPage + 1} de ${_totalPages > 0 ? _totalPages : 1}',
                style: const TextStyle(color: Colors.white70),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: _currentPage < _totalPages - 1
                    ? () => setState(() => _currentPage++)
                    : null,
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = AppStateScope.of(context);
    final canEdit = appState.isAdminOrGestor;
    final canViewSensitiveInfo = appState.isAdminOrGestor || appState.isFinanceiro;

    return LayoutBuilder(
      builder: (context, constraints) {
        // Calcular altura disponível para a tabela
        // Subtraindo: header (~48px) + divider (1px) + padding (32px) + search bar (~80px) + pagination (~60px) + spacing (16px)
        final availableHeight = constraints.maxHeight - 237;

        return Column(
          children: [
            _Header(
              totalClients: allData.length,
              filteredClients: filteredData.length,
            ),
            const Divider(height: 1),

            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Barra de busca e filtros
                  TableSearchFilterBar(
              searchHint: 'Buscar cliente (nome, email ou telefone...)',
              onSearchChanged: (value) {
                searchQuery = value;
                applyFilters();
              },
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
                if (value != null) {
                  setState(() {
                    filterType = value;
                    filterValue = null;
                  });
                  applyFilters();
                }
              },
              filterValue: filterValue,
              filterValueLabel: _getFilterLabel(),
              filterValueOptions: _getFilterOptions(),
              onFilterValueChanged: (value) {
                setState(() => filterValue = value?.isEmpty == true ? null : value);
                applyFilters();
              },
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

                  // Área da tabela com altura dinâmica
                  SizedBox(
                    height: availableHeight,
                    child: Builder(builder: (context) {
                      if (isLoading) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (filteredData.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.search_off,
                                size: 64,
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                searchQuery.isNotEmpty || filterValue != null
                                    ? 'Nenhum cliente encontrado com os filtros aplicados'
                                    : 'Nenhum cliente cadastrado',
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      // Colunas dinâmicas baseadas em permissões
                      final columns = <DataTableColumn>[
                        const DataTableColumn(label: 'Nome', sortable: true, flex: 2),
                        const DataTableColumn(label: 'Categoria', sortable: true),
                        if (canViewSensitiveInfo) const DataTableColumn(label: 'Email', sortable: true),
                        if (canViewSensitiveInfo) const DataTableColumn(label: 'Telefone'),
                        const DataTableColumn(label: 'País', sortable: true),
                        const DataTableColumn(label: 'Estado', sortable: true),
                        const DataTableColumn(label: 'Cidade', sortable: true),
                      ];

                      // Cell builders dinâmicos baseados em permissões
                      final cellBuilders = <Widget Function(Map<String, dynamic>)>[
                        (c) => Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircleAvatar(
                              radius: 16,
                              backgroundImage: c['avatar_url'] != null
                                  ? NetworkImage(c['avatar_url'])
                                  : null,
                              child: c['avatar_url'] == null
                                  ? const Icon(Icons.person, size: 16)
                                  : null,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                c['name'] ?? '',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        (c) => Text(
                          c['client_categories']?['name'] ??
                          c['category'] ??
                          '-'
                        ),
                        if (canViewSensitiveInfo) (c) => InkWell(
                          onTap: () => _copyEmail(c['email']),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.email, size: 16, color: Colors.white),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  c['email'] ?? '-',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (canViewSensitiveInfo) (c) => InkWell(
                          onTap: () => _openWhatsApp(c['phone']),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const _WhatsAppIcon(size: 16, color: Colors.white),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  c['phone'] ?? '-',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    decoration: TextDecoration.none,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        (c) => Text(c['country'] ?? '-'),
                        (c) => Text(c['state'] ?? '-'),
                        (c) => Text(c['city'] ?? '-'),
                      ];

                      // Comparadores para ordenação
                      final sortComparators = _getSortComparators();

                      return Column(
                        children: [
                          Expanded(
                            child: ReusableDataTable<Map<String, dynamic>>(
                              items: _getPaginatedData(),
                              selectedIds: _selected,
                              onSelectionChanged: (ids) => setState(() => _selected
                                ..clear()
                                ..addAll(ids)),
                              columns: columns,
                              cellBuilders: cellBuilders,
                              sortComparators: sortComparators,
                              onSort: (columnIndex, ascending) {
                                setState(() {
                                  _sortColumnIndex = columnIndex;
                                  _sortAscending = ascending;
                                  _applySorting();
                                  _currentPage = 0;
                                });
                              },
                              externalSortColumnIndex: _sortColumnIndex,
                              externalSortAscending: _sortAscending,
                              getId: (c) => c['id'] as String,
                              onRowTap: (c) {
                                // Atualiza a aba atual com os detalhes do cliente
                                final tabManager = TabManagerScope.maybeOf(context);
                                if (tabManager != null) {
                                  final clientId = c['id'].toString();
                                  final clientName = c['name'] as String? ?? 'Cliente';
                                  final tabId = 'client_$clientId';

                                  // Atualiza a aba atual em vez de criar uma nova
                                  final currentIndex = tabManager.currentIndex;
                                  final updatedTab = TabItem(
                                    id: tabId,
                                    title: clientName,
                                    icon: Icons.person,
                                    page: ClientDetailPage(clientId: clientId),
                                    canClose: true,
                                  );
                                  tabManager.updateTab(currentIndex, updatedTab);
                                } else {
                                  // Fallback para navegação tradicional se TabManager não estiver disponível
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => ClientDetailPage(clientId: c['id'] as String),
                                    ),
                                  );
                                }
                              },
                              actions: canEdit ? [
                                DataTableAction(
                                  icon: Icons.edit,
                                  label: 'Editar',
                                  onPressed: (c) => _openForm(initial: c),
                                ),
                                DataTableAction(
                                  icon: Icons.content_copy,
                                  label: 'Duplicar',
                                  onPressed: (c) => _duplicate(c),
                                ),
                                DataTableAction(
                                  icon: Icons.delete,
                                  label: 'Excluir',
                                  onPressed: (c) => _delete(c['id'] as String, c['name'] as String),
                                ),
                              ] : [],
                            ),
                          ),
                          const SizedBox(height: 16),
                          _buildPaginationControls(),
                    ],
                  );
                }),
              ),
            ],
          ),
        ),
      ],
    );
      },
    );
  }
}

// Widget customizado para ícone do WhatsApp
class _WhatsAppIcon extends StatelessWidget {
  final double size;
  final Color color;

  const _WhatsAppIcon({
    this.size = 16,
    this.color = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return FaIcon(
      FontAwesomeIcons.whatsapp,
      size: size,
      color: color,
    );
  }
}

class _Header extends StatelessWidget {
  final int totalClients;
  final int filteredClients;

  const _Header({
    required this.totalClients,
    required this.filteredClients,
  });

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
