import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../state/app_state_scope.dart';
import 'project_detail_page.dart';
import 'package:googleapis_auth/auth_io.dart' as auth;
import '../../../services/google_drive_oauth_service.dart';

import 'project_members_dialog.dart';

import 'project_form_dialog.dart';

import '../../navigation/route_observer.dart';
import '../../navigation/tab_manager_scope.dart';
import '../../navigation/tab_item.dart';
import 'package:my_business/ui/organisms/tables/reusable_data_table.dart';
import 'package:my_business/ui/organisms/tables/dynamic_paginated_table.dart';
import 'package:my_business/ui/organisms/tables/table_search_filter_bar.dart';
import 'package:my_business/ui/molecules/table_cells/table_cells.dart';
import '../../../modules/modules.dart';
import 'widgets/project_status_badge.dart';
import '../../../constants/project_status.dart';
import 'package:my_business/ui/organisms/dialogs/dialogs.dart';


class ProjectsPage extends StatefulWidget {
  const ProjectsPage({super.key});

  @override
  State<ProjectsPage> createState() => _ProjectsPageState();
}

class _ProjectsPageState extends State<ProjectsPage> with RouteAware {
  List<Map<String, dynamic>> _allData = [];
  List<Map<String, dynamic>> _filteredData = [];
  bool _loading = true;
  String? _error;

  final Set<String> _selected = <String>{};

  bool _depsInitialized = false;

  // Busca e filtros
  String _searchQuery = '';
  String _filterType = 'none'; // none, status, client, value, person
  String? _filterValue;

  // Lista de usuários para o filtro de pessoas
  List<Map<String, dynamic>> _allUsers = [];

  // Ordenação
  int? _sortColumnIndex = 0;
  bool _sortAscending = true; // Crescente por padrão (A→Z)

  // Debounce para busca
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    routeObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_depsInitialized) {
      _depsInitialized = true;
      final route = ModalRoute.of(context);
      if (route is PageRoute) {
        routeObserver.subscribe(this, route);
      }
    }
  }



  @override
  void didPopNext() {
    _reload();
  }

  Future<void> _reload() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      // OTIMIZAÇÃO: Carregar usuários e projetos em PARALELO
      final results = await Future.wait([
        usersModule.getAllProfiles(),
        projectsModule.getProjects(offset: 0, limit: 1000),
      ]);

      final usersRes = results[0];
      final projects = results[1];

      // OTIMIZAÇÃO: Buscar membros e tasks de TODOS os projetos em queries otimizadas
      final projectIds = projects.map((p) => p['id'] as String).toList();

      if (projectIds.isNotEmpty) {
        // Buscar membros dos projetos (adicionados automaticamente quando atribuídos a tasks)
        final allMembersResponse = await Supabase.instance.client
            .from('project_members')
            .select('project_id, user_id, profiles:user_id(id, full_name, avatar_url)')
            .inFilter('project_id', projectIds);

        // Buscar contagem de tasks por projeto
        final allTasksResponse = await Supabase.instance.client
            .from('tasks')
            .select('project_id')
            .inFilter('project_id', projectIds);

        // Agrupar membros por projeto
        final membersByProject = <String, List<dynamic>>{};
        for (final member in allMembersResponse) {
          final projectId = member['project_id'] as String?;
          if (projectId != null) {
            membersByProject.putIfAbsent(projectId, () => []).add(member);
          }
        }

        // Contar tasks por projeto
        final taskCountByProject = <String, int>{};
        for (final task in allTasksResponse) {
          final projectId = task['project_id'] as String?;
          if (projectId != null) {
            taskCountByProject[projectId] = (taskCountByProject[projectId] ?? 0) + 1;
          }
        }

        // Processar cada projeto
        for (final project in projects) {
          final projectId = project['id'] as String;
          final members = membersByProject[projectId] ?? [];

          // Extrair profiles dos membros
          final people = members
              .map((m) => m['profiles'] as Map<String, dynamic>?)
              .whereType<Map<String, dynamic>>()
              .toList();

          project['team_members'] = people;
          project['total_people'] = people.length;
          project['total_tasks'] = taskCountByProject[projectId] ?? 0;
        }
      }

      if (!mounted) return;
      setState(() {
        _allUsers = usersRes;
        _allData = projects;
        _filteredData = projects;
        _loading = false;
      });
      _applyFilters();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  // Método com debounce para busca
  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      setState(() {
        _searchQuery = value;
      });
      _applyFilters();
    });
  }

  void _applyFilters() {
    setState(() {
      var filtered = List<Map<String, dynamic>>.from(_allData);

      // Aplicar busca
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        filtered = filtered.where((project) {
          final name = (project['name'] ?? '').toString().toLowerCase();
          final clientName = (project['clients']?['name'] ?? '').toString().toLowerCase();
          return name.contains(query) || clientName.contains(query);
        }).toList();
      }

      // Aplicar filtro selecionado
      if (_filterType != 'none' && _filterValue != null && _filterValue!.isNotEmpty) {
        filtered = filtered.where((project) {
          switch (_filterType) {
            case 'status':
              return project['status'] == _filterValue;
            case 'client':
              return project['clients']?['name'] == _filterValue;
            case 'value':
              // Filtro por faixa de valor
              final value = project['value'] as num?;
              if (value == null) return false;

              switch (_filterValue) {
                case 'low': // Até R$ 1.000
                  return value <= 1000;
                case 'medium': // R$ 1.001 - R$ 10.000
                  return value > 1000 && value <= 10000;
                case 'high': // R$ 10.001 - R$ 50.000
                  return value > 10000 && value <= 50000;
                case 'very_high': // Acima de R$ 50.000
                  return value > 50000;
                default:
                  return true;
              }
            case 'person':
              // Filtro por pessoa (owner_id)
              return project['owner_id'] == _filterValue;
            default:
              return true;
          }
        }).toList();
      }

      _filteredData = filtered;
      _applySorting();
    });
  }

  void _applySorting() {
    if (_sortColumnIndex == null) return;

    final comparators = _getSortComparators();
    if (_sortColumnIndex! >= comparators.length) return;

    final comparator = comparators[_sortColumnIndex!];

    _filteredData.sort((a, b) {
      final result = comparator(a, b);
      return _sortAscending ? result : -result;
    });
  }

  List<String> _getUniqueClients() {
    final clients = _allData
        .map((p) => p['clients']?['name'] as String?)
        .whereType<String>()
        .where((c) => c.isNotEmpty)
        .toSet()
        .toList();
    clients.sort();
    return clients;
  }

  List<String> _getFilterOptions() {
    switch (_filterType) {
      case 'status':
        return ProjectStatus.values;
      case 'client':
        return _getUniqueClients();
      case 'value':
        return ['low', 'medium', 'high', 'very_high'];
      case 'person':
        // Retorna IDs dos usuários
        return _allUsers.map((u) => u['id'] as String).toList();
      case 'none':
        return [];
      default:
        return [];
    }
  }

  String _getFilterLabel() {
    switch (_filterType) {
      case 'status':
        return 'Filtrar por status';
      case 'client':
        return 'Filtrar por cliente';
      case 'value':
        return 'Filtrar por valor';
      case 'person':
        return 'Filtrar por pessoa';
      case 'none':
        return 'Sem filtro';
      default:
        return 'Filtrar';
    }
  }

  String _getFilterValueLabel(String value) {
    switch (_filterType) {
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


  Future<void> _openForm({Map<String, dynamic>? initial}) async {
    final changed = await DialogHelper.show<bool>(
      context: context,
      builder: (context) => ProjectFormDialog(initial: initial),
    );
    if (changed == true) {
      await _reload();
    }
  }

  Future<void> _duplicate(Map<String, dynamic> project) async {
    try {
      // Usando o módulo de projetos para criar
      await projectsModule.createProject(
        name: '${project['name'] ?? ''} (Cópia)',
        description: project['description'] ?? '',
        clientId: project['client_id'],
        companyId: project['company_id'],
        priority: project['priority'] ?? 'medium',
        status: project['status'] ?? 'active',
        currencyCode: project['currency_code'],
        startDate: project['start_date'] != null
            ? DateTime.tryParse(project['start_date'])
            : null,
        dueDate: project['due_date'] != null
            ? DateTime.tryParse(project['due_date'])
            : null,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Projeto duplicado com sucesso')),
        );
        await _reload();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao duplicar: $e')),
        );
      }
    }
  }

  Future<void> _deleteProjectAndDrive(Map<String, dynamic> project) async {
    final id = project['id'] as String;

    // 1) Delete from DB first usando o módulo de projetos
    await projectsModule.deleteProject(id);
    if (!mounted) return;

    // OTIMIZAÇÃO: Recarregar dados após deletar
    await _reload();

    // 2) Best-effort delete Drive folder; never block DB deletion
    try {
      final clientName = (project['clients']?['name'] ?? 'Cliente').toString();
      final projectName = (project['name'] ?? 'Projeto').toString();
      final drive = GoogleDriveOAuthService();
      auth.AuthClient? authed;
      try { authed = await drive.getAuthedClient(); } catch (_) {}
      if (authed != null) {
        await drive.deleteProjectFolder(
          client: authed,
          clientName: clientName,
          projectName: projectName,
        );
      } else {
      }
    } catch (e) {
      // Ignorar erro (operação não crítica)
    }
  }

  Future<void> _openMembers(Map<String, dynamic> project) async {
    // Usando o módulo de autenticação
    final current = authModule.currentUser;
    final isOwner = current != null && project['owner_id'] == current.id;
    final isAdmin = false; // Admin real pode ser verificado via profiles, mas mantemos simples na UI
    await DialogHelper.show(
      context: context,
      builder: (context) => ProjectMembersDialog(
        projectId: project['id'] as String,
        canManage: isOwner || isAdmin,
      ),
    );
  }

  // Exclusão em lote
  Future<void> _bulkDelete() async {
    final count = _selected.length;

    final confirm = await DialogHelper.show<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar exclusão'),
        content: Text('Deseja realmente excluir $count projeto${count > 1 ? 's' : ''}?'),
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
        // Excluir todos os projetos selecionados
        for (final id in _selected) {
          await projectsModule.deleteProject(id);
        }

        if (!mounted) return;

        // Limpar seleção
        setState(() => _selected.clear());

        // Recarregar dados
        await _reload();

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$count projeto${count > 1 ? 's excluídos' : ' excluído'} com sucesso'),
          ),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao excluir projetos: $e')),
        );
      }
    }
  }

  // Comparadores para ordenação
  List<int Function(Map<String, dynamic>, Map<String, dynamic>)> _getSortComparators() {
    return [
      // Nome
      (a, b) => (a['name'] ?? '').toString().toLowerCase()
          .compareTo((b['name'] ?? '').toString().toLowerCase()),
      // Cliente
      (a, b) => (a['clients']?['name'] ?? '').toString().toLowerCase()
          .compareTo((b['clients']?['name'] ?? '').toString().toLowerCase()),
      // Valor
      (a, b) {
        final valueA = a['value_cents'] as int? ?? 0;
        final valueB = b['value_cents'] as int? ?? 0;
        return valueA.compareTo(valueB);
      },
      // Status
      (a, b) => (a['status'] ?? '').toString()
          .compareTo((b['status'] ?? '').toString()),
      // Tasks
      (a, b) {
        final tasksA = (a['total_tasks'] as num? ?? 0).toInt();
        final tasksB = (b['total_tasks'] as num? ?? 0).toInt();
        return tasksA.compareTo(tasksB);
      },
      // Pessoas
      (a, b) {
        final peopleA = (a['total_people'] as num? ?? 0).toInt();
        final peopleB = (b['total_people'] as num? ?? 0).toInt();
        return peopleA.compareTo(peopleB);
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
      // Data de criação
      (a, b) {
        final dateA = a['created_at'] != null ? DateTime.tryParse(a['created_at']) : null;
        final dateB = b['created_at'] != null ? DateTime.tryParse(b['created_at']) : null;
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
    // Usando o módulo de autenticação
    final isLogged = authModule.currentUser != null;
    final userId = authModule.currentUser?.id;

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
                    onSearchChanged: _onSearchChanged,
                    filterType: _filterType,
                    filterTypeLabel: 'Tipo de filtro',
                    filterTypeOptions: const [
                      FilterOption(value: 'none', label: 'Nenhum'),
                      FilterOption(value: 'status', label: 'Status'),
                      FilterOption(value: 'client', label: 'Cliente'),
                      FilterOption(value: 'value', label: 'Valor'),
                      FilterOption(value: 'person', label: 'Pessoa'),
                    ],
                    onFilterTypeChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _filterType = value;
                          _filterValue = null;
                        });
                        _applyFilters();
                      }
                    },
                    filterValue: _filterValue,
                    filterValueLabel: _getFilterLabel(),
                    filterValueOptions: _getFilterOptions(),
                    filterValueLabelBuilder: _getFilterValueLabel,
                    onFilterValueChanged: (value) {
                      setState(() => _filterValue = value?.isEmpty == true ? null : value);
                      _applyFilters();
                    },
                    selectedCount: _selected.length,
                    bulkActions: (() {
                      if (!isLogged) return null;
                      final permissions = appState.permissions;
                      return permissions.canDeleteProjects ? [
                        BulkAction(
                          icon: Icons.delete,
                          label: 'Excluir selecionados',
                          color: Colors.red,
                          onPressed: _bulkDelete,
                        ),
                      ] : null;
                    })(),
                    actionButton: (() {
                      if (!isLogged) return null;
                      final permissions = appState.permissions;
                      return permissions.canCreateProjects ? FilledButton.icon(
                        onPressed: () => _openForm(),
                        icon: const Icon(Icons.add),
                        label: const Text('Novo Projeto'),
                      ) : null;
                    })(),
                  ),

                  const SizedBox(height: 16),

                  // Tabela com paginação dinâmica
                  Expanded(
                    child: DynamicPaginatedTable<Map<String, dynamic>>(
                      items: _filteredData,
                      itemLabel: 'projeto(s)',
                      selectedIds: _selected,
                      onSelectionChanged: (ids) => setState(() => _selected
                        ..clear()
                        ..addAll(ids)),
                      columns: const [
                        DataTableColumn(label: 'Nome', sortable: true),
                        DataTableColumn(label: 'Cliente', sortable: true),
                        DataTableColumn(label: 'Valor', sortable: true),
                        DataTableColumn(label: 'Status', sortable: true),
                        DataTableColumn(label: 'Tasks', sortable: true),
                        DataTableColumn(label: 'Membros', sortable: true),
                        DataTableColumn(label: 'Atualizado', sortable: true),
                        DataTableColumn(label: 'Criado', sortable: true),
                      ],
                      onSort: (columnIndex, ascending) {
                        setState(() {
                          _sortColumnIndex = columnIndex;
                          _sortAscending = ascending;
                          _applySorting();
                        });
                      },
                      externalSortColumnIndex: _sortColumnIndex,
                      externalSortAscending: _sortAscending,
                      sortComparators: _getSortComparators(),
                      cellBuilders: [
                        // Nome
                        (p) => Text(p['name'] ?? ''),
                        // Cliente
                        (p) => TableCellAvatar(
                          avatarUrl: p['clients']?['avatar_url'],
                          name: p['clients']?['name'] ?? '-',
                          size: 12,
                        ),
                        // Valor
                        (p) => TableCellCurrency(
                          valueCents: p['value_cents'],
                          currencyCode: p['currency_code'] ?? 'BRL',
                        ),
                        // Status
                        (p) => ProjectStatusBadge(status: p['status'] ?? 'not_started'),
                        // Tasks
                        (p) => TableCellCounter(
                          count: (p['total_tasks'] as num?)?.toInt(),
                          icon: Icons.task_alt,
                        ),
                        // Membros
                        (p) => ResponsibleCell(
                          people: p['team_members'],
                          singleAvatarSize: 20,
                          multipleAvatarSize: 10,
                        ),
                        // Última Atualização
                        (p) => TableCellUpdatedBy(
                          date: p['updated_at'],
                          profile: p['updated_by_profile'],
                          avatarSize: 10,
                        ),
                        // Criado em
                        (p) => TableCellDate(
                          date: p['created_at'],
                        ),
                      ],
                      getId: (p) => p['id'] as String,
                      onRowTap: (p) {
                        // Atualiza a aba atual com os detalhes do projeto
                        final tabManager = TabManagerScope.maybeOf(context);
                        if (tabManager != null) {
                          final projectId = p['id'].toString();
                          final projectName = p['name'] as String? ?? 'Projeto';
                          final tabId = 'project_$projectId';

                          // Atualiza a aba atual em vez de criar uma nova
                          final currentIndex = tabManager.currentIndex;
                          final currentTab = tabManager.currentTab;
                          final updatedTab = TabItem(
                            id: tabId,
                            title: projectName,
                            icon: Icons.folder,
                            page: ProjectDetailPage(
                              key: ValueKey(tabId),
                              projectId: projectId,
                            ),
                            canClose: true,
                            selectedMenuIndex: currentTab?.selectedMenuIndex ?? 0, // Preserva o índice do menu
                          );
                          tabManager.updateTab(currentIndex, updatedTab);
                        } else {
                          // Fallback para navegação tradicional se TabManager não estiver disponível
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ProjectDetailPage(projectId: p['id'] as String),
                            ),
                          );
                        }
                      },
                      actions: [
                        DataTableAction<Map<String, dynamic>>(
                          icon: Icons.group,
                          label: 'Membros',
                          onPressed: (p) => _openMembers(p),
                          showWhen: (p) {
                            final isOwner = userId != null && p['owner_id'] == userId;
                            return appState.isAdmin || isOwner;
                          },
                        ),
                        DataTableAction<Map<String, dynamic>>(
                          icon: Icons.edit,
                          label: 'Editar',
                          onPressed: (p) => _openForm(initial: p),
                          showWhen: (p) => appState.permissions.canEditProjects,
                        ),
                        DataTableAction<Map<String, dynamic>>(
                          icon: Icons.content_copy,
                          label: 'Duplicar',
                          onPressed: (p) => _duplicate(p),
                          showWhen: (p) => appState.permissions.canEditProjects,
                        ),
                        DataTableAction<Map<String, dynamic>>(
                          icon: Icons.delete,
                          label: 'Excluir',
                          onPressed: (p) => _deleteProjectAndDrive(p),
                          showWhen: (p) => appState.permissions.canDeleteProjects,
                        ),
                      ],
                      isLoading: _loading,
                      hasError: _error != null,
                      errorWidget: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text('Erro ao carregar projetos:\n\n${_error ?? ""}'),
                        ),
                      ),
                      emptyWidget: const Center(child: Text('Nenhum projeto encontrado')),
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

/* LEGACY REMOVED: _ProjectForm and _SelectCatalogItemDialog (now using ProjectFormDialog)

class _ProjectForm extends StatefulWidget {
  // ignore: unused_element_parameter
  final Map<String, dynamic>? initial;
  const _ProjectForm({this.initial}); // ignore: unused_element_parameter

  @override
  State<_ProjectForm> createState() => _ProjectFormState();
}

class _ProjectFormState extends State<_ProjectForm> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _desc = TextEditingController();
  final _valueText = TextEditingController();
  String _currencyCode = 'BRL'; // BRL | USD | EUR
  String? _clientId;
  bool _saving = false;
  List<Map<String, dynamic>> _clients = [];
  final List<_CostItem> _costs = [];

  // Catalog items linked to project with negotiated price
  final List<_CatalogItem> _catalogItems = [];

  @override
  void initState() {
    super.initState();
    final i = widget.initial;
    if (i != null) {
      _name.text = i['name'] ?? '';
      _desc.text = i['description'] ?? '';
      _clientId = i['client_id'] as String?;
      // Valores financeiros (se já existem):
      final vc = i['value_cents'] as int?;
      if (vc != null) _valueText.text = _formatCents(vc).replaceAll('.', ',');
      final cur = i['currency_code'] as String?;
      if (cur != null && ['BRL','USD','EUR'].contains(cur)) _currencyCode = cur;
      _loadAdditionalCosts(i['id'] as String);
      _loadCatalogItems(i['id'] as String);
    }
    _loadClients();
  }

  Future<void> _loadClients() async {
    final res = await Supabase.instance.client.from('clients').select('id, name');
    setState(() => _clients = List<Map<String, dynamic>>.from(res));
  }

  Future<void> _loadAdditionalCosts(String projectId) async {
    try {
      final rows = await Supabase.instance.client
          .from('project_additional_costs')
          .select('id, description, amount_cents')
          .eq('project_id', projectId);
      setState(() {
        _costs.clear();
        for (final r in rows as List<dynamic>) {
          final item = _CostItem();
          item.descController.text = (r as Map<String, dynamic>)['description'] ?? '';
          final cents = r['amount_cents'] as int? ?? 0;
          item.valueController.text = _formatCents(cents).replaceAll('.', ',');
          _costs.add(item);
        }
      });
    } catch (_) {}
    // Ignorar erro (operação não crítica)
  }

  Future<void> _loadCatalogItems(String projectId) async {
    try {
      final rows = await Supabase.instance.client
          .from('project_catalog_items')
          .select('kind, item_id, name, currency_code, unit_price_cents, quantity, position')
          .eq('project_id', projectId)
          .order('position', ascending: true, nullsFirst: true);
      setState(() {
        _catalogItems.clear();
        for (final r in rows as List<dynamic>) {
          final m = r as Map<String, dynamic>;
          _catalogItems.add(_CatalogItem(
            itemType: (m['kind'] as String?) ?? 'product',
            itemId: (m['item_id'] as String?) ?? '',
            name: (m['name'] as String?) ?? '-',
            currency: (m['currency_code'] as String?) ?? _currencyCode,
            priceCents: (m['unit_price_cents'] as int?) ?? 0,
            quantity: (m['quantity'] as int?) ?? 1,
          ));
        }
        if (_catalogItems.isNotEmpty) {
          _valueText.text = _formatCents(_catalogSumCents).replaceAll('.', ',');
        }
      });
    } catch (_) {}
    // Ignorar erro (operação não crítica)
  }

  int _parseMoneyToCents(String input) {
    final s = input.trim().isEmpty ? '0' : input.trim().replaceAll('.', '').replaceAll(',', '.');
    final v = double.tryParse(s) ?? 0.0;
    return (v * 100).round();
  }

  String _formatCents(int cents) {
    final sign = cents < 0 ? '-' : '';
    final v = (cents.abs() / 100.0);
    return '$sign${v.toStringAsFixed(2)}';
  }

  String _currencySymbol(String code) {
    switch (code) {
      case 'USD':
        return '\$';
      case 'EUR':
        return '€';
      default:
        return 'R\$';
    }
  }

  int get _projectValueCents => _parseMoneyToCents(_valueText.text);
  int get _additionalCents => _costs.fold<int>(0, (sum, c) => sum + _parseMoneyToCents(c.valueController.text));

  int get _catalogSumCents => _catalogItems.where((it) => it.currency == _currencyCode).fold<int>(0, (sum, it) => sum + (it.priceCents * it.quantity));
  int get _totalCents => _projectValueCents + _additionalCents; // Total do projeto continua separado dos itens

  @override
  void dispose() {
    _name.dispose();
    _desc.dispose();
    _valueText.dispose();
    for (final c in _costs) { c.dispose(); }
    for (final item in _catalogItems) { item.dispose(); }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final base = {
      'name': _name.text.trim(),
      'description': _desc.text.trim().isEmpty ? null : _desc.text.trim(),
      'client_id': _clientId,
      'owner_id': Supabase.instance.client.auth.currentUser!.id,
      'status': 'active',
      'currency_code': _currencyCode,
      'value_cents': _projectValueCents,
    };
    final messenger = ScaffoldMessenger.of(context);
    try {
      String projectId;
      if (widget.initial == null) {
        final payload = {
          ...base,
          'created_by': Supabase.instance.client.auth.currentUser!.id,
        };
        final inserted = await Supabase.instance.client
            .from('projects')
            .insert(payload)
            .select('id')
            .single();
        projectId = inserted['id'] as String;
      } else {
        projectId = widget.initial!['id'] as String;
        final payload = {
          ...base,
          'updated_by': Supabase.instance.client.auth.currentUser!.id,
          'updated_at': DateTime.now().toIso8601String(),
        };
        await Supabase.instance.client.from('projects').update(payload).eq('id', projectId);
        // Substitui custos adicionais atuais pelo que está no form
        await Supabase.instance.client.from('project_additional_costs').delete().eq('project_id', projectId);
        await Supabase.instance.client.from('project_catalog_items').delete().eq('project_id', projectId);
      }

      if (_costs.isNotEmpty) {
        final uid = Supabase.instance.client.auth.currentUser!.id;
        final rows = _costs
            .where((c) => c.descController.text.trim().isNotEmpty)
            .map((c) => {
                  'project_id': projectId,
                  'description': c.descController.text.trim(),
                  'amount_cents': _parseMoneyToCents(c.valueController.text),
                  'created_by': uid,
                })
            .toList();
        if (rows.isNotEmpty) {
          await Supabase.instance.client.from('project_additional_costs').insert(rows);
        }
      }

      if (_catalogItems.isNotEmpty) {
        final uid = Supabase.instance.client.auth.currentUser!.id;
        final rows = _catalogItems.asMap().entries.map((e) { final idx = e.key; final it = e.value; return {
          'project_id': projectId,
          'kind': it.itemType,
          'item_id': it.itemId,
          'name': it.name,
          'currency_code': it.currency,
          'unit_price_cents': it.priceCents,
          'quantity': it.quantity,
            'position': idx,
          'created_by': uid,
        }; }).toList();
        await Supabase.instance.client.from('project_catalog_items').insert(rows);
      }

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      messenger.showSnackBar(const SnackBar(content: Text('Erro ao salvar')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = AppStateScope.of(context);
    final canEditFinancial = appState.isAdminOrGestor || appState.isFinanceiro;

    return Dialog(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 720,
            maxHeight: MediaQuery.of(context).size.height * 0.85,
          ),
          child: Stack(children: [
            Positioned.fill(
              child: SingleChildScrollView(
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(widget.initial == null ? 'Novo Projeto' : 'Editar Projeto', style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _name,
                        decoration: const InputDecoration(labelText: 'Nome *'),
                        validator: (v) => v == null || v.trim().isEmpty ? 'Informe o nome' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(controller: _desc, decoration: const InputDecoration(labelText: 'Descrição')),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: _clientId,
                        items: _clients.map((c) => DropdownMenuItem(value: c['id'] as String, child: Text(c['name'] as String))).toList(),
                        onChanged: (v) => setState(() => _clientId = v),
                        decoration: const InputDecoration(labelText: 'Cliente'),
                      ),
                      const SizedBox(height: 16),

                      // Seção financeira
                      Text('Financeiro', style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 8),
                      Row(children: [
                        Expanded(
                          flex: 2,
                          child: GenericDropdownField<String>(
                            value: _currencyCode,
                            items: const [
                              DropdownItem(value: 'BRL', label: 'Real (BRL)'),
                              DropdownItem(value: 'USD', label: 'Dólar (USD)'),
                              DropdownItem(value: 'EUR', label: 'Euro (EUR)'),
                            ],
                            onChanged: canEditFinancial ? (v) {
                              final newCur = v ?? 'BRL';
                              if (newCur == _currencyCode) return;
                              setState(() {
                                _currencyCode = newCur;
                                if (_catalogItems.isNotEmpty) {
                                  _valueText.text = _formatCents(_catalogSumCents).replaceAll('.', ',');
                                }
                              });
                            } : null,
                            labelText: 'Moeda',
                            enabled: canEditFinancial,
                            openUpwards: true, // Abre para cima pois está no footer
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 3,
                          child: TextFormField(
                            controller: _valueText,
                            enabled: canEditFinancial,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: InputDecoration(
                              labelText: 'Valor do projeto',
                              prefixText: '${_currencySymbol(_currencyCode)} ',
                              helperText: 'Use vírgula ou ponto para decimais',
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                      ]),
                      if (_catalogItems.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                            AppStateScope.of(context).isAdmin || AppStateScope.of(context).isFinanceiro ? 'Soma itens do catálogo: ${_currencySymbol(_currencyCode)} ${_formatCents(_catalogSumCents).replaceAll('.', ',')}' : '',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                      ],

                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Text('Custos adicionais', style: Theme.of(context).textTheme.titleMedium),
                          const Spacer(),
                          if (canEditFinancial)
                            FilledButton.tonal(
                              onPressed: () => setState(() => _costs.add(_CostItem())),
                              child: const Text('Adicionar custo'),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ..._costs.asMap().entries.map((e) {
                        final idx = e.key;
                        final item = e.value;
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Row(children: [
                            Expanded(
                              flex: 4,
                              child: TextField(
                                controller: item.descController,
                                enabled: canEditFinancial,
                                decoration: const InputDecoration(labelText: 'Descrição'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 2,
                              child: TextField(
                                controller: item.valueController,
                                enabled: canEditFinancial,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                decoration: const InputDecoration(labelText: 'Valor'),
                                onChanged: (_) => setState(() {}),
                              ),
                            ),
                            if (canEditFinancial) ...[
                              const SizedBox(width: 8),
                              IconOnlyButton(
                                icon: Icons.delete_outline,
                                tooltip: 'Remover',
                                onPressed: () => setState(() {
                                  final removed = _costs.removeAt(idx);
                                  removed.dispose();
                                }),
                              ),
                            ],
                          ]),
                        );
                      }),

                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          'Total: ${_currencySymbol(_currencyCode)} ${_formatCents(_totalCents).replaceAll('.', ',')}',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Itens do Catálogo
                      Row(children: [
                        Text('Itens do Catálogo', style: Theme.of(context).textTheme.titleMedium),
                        const Spacer(),
                        FilledButton.tonal(
                          onPressed: () async {
                            final selected = await DialogHelper.show<_CatalogItem>(
                              context: context,
                              builder: (_) => _SelectCatalogItemDialog(currency: _currencyCode),
                            );
                            if (selected != null) {
                              setState(() {
                                final existing = _catalogItems.indexWhere((e) => e.itemType == selected.itemType && e.itemId == selected.itemId);
                                if (existing >= 0) {
                                  _catalogItems[existing] = _catalogItems[existing].copyWith(quantity: _catalogItems[existing].quantity + 1);
                                } else {
                                  _catalogItems.add(selected);
                                }
                                // Atualiza o valor do projeto com a soma dos itens (editável depois)
                                if (canEditFinancial && _catalogItems.isNotEmpty) {
                                  _valueText.text = _formatCents(_catalogSumCents).replaceAll('.', ',');
                                }
                              });
                            }
                          },
                          child: const Text('Adicionar do Catálogo'),
                        ),
                      ]),
                      const SizedBox(height: 8),
                      ReorderableDragList<_CatalogItem>(
                        items: _catalogItems,
                        enabled: true,
                        onReorder: (oldIndex, newIndex) {
                          setState(() {
                            if (newIndex > oldIndex) newIndex -= 1;
                            final item = _catalogItems.removeAt(oldIndex);
                            _catalogItems.insert(newIndex, item);
                          });
                        },
                        itemBuilder: (context, it, idx) {
                          final rowTotal = it.priceCents * it.quantity;
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Row(children: [
                              Expanded(flex: 5, child: Text('${it.name} (${it.itemType})')),
                              const SizedBox(width: 8),
                              Expanded(
                                flex: 2,
                                child: TextFormField(
                                  controller: it.priceController,
                                  enabled: canEditFinancial,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  textDirection: TextDirection.ltr,
                                  decoration: const InputDecoration(labelText: 'Preço'),
                                  onChanged: (v) {
                                    final cents = _parseMoneyToCents(v);
                                    it.updatePriceCents(cents);
                                    setState(() {
                                      if (canEditFinancial && _catalogItems.isNotEmpty) {
                                        _valueText.text = _formatCents(_catalogSumCents).replaceAll('.', ',');
                                      }
                                    });
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                flex: 2,
                                child: TextFormField(
                                  controller: it.quantityController,
                                  enabled: canEditFinancial,
                                  keyboardType: TextInputType.number,
                                  textDirection: TextDirection.ltr,
                                  decoration: const InputDecoration(labelText: 'Qtd'),
                                  onChanged: (v) {
                                    final q = int.tryParse(v) ?? 1;
                                    it.updateQuantity(q.clamp(1, 999));
                                    setState(() {
                                      if (canEditFinancial && _catalogItems.isNotEmpty) {
                                        _valueText.text = _formatCents(_catalogSumCents).replaceAll('.', ',');
                                      }
                                    });
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                              if (AppStateScope.of(context).isAdmin || AppStateScope.of(context).isFinanceiro)
                                Expanded(flex: 2, child: Text('${_currencySymbol(_currencyCode)} ${_formatCents(rowTotal).replaceAll('.', ',')}')),
                              const SizedBox(width: 8),
                              IconOnlyButton(
                                icon: Icons.delete_outline,
                                tooltip: 'Remover',
                                onPressed: () => setState(() {
                                  _catalogItems.removeAt(idx);
                                  if (canEditFinancial) {
                                    _valueText.text = _catalogItems.isEmpty
                                      ? _valueText.text
                                      : _formatCents(_catalogSumCents).replaceAll('.', ',');
                                  }
                                }),
                              ),
                            ]),
                          );
                        },
                        getKey: (it) => '${it.itemType}_${it.itemId}_${_catalogItems.indexOf(it)}',
                        emptyWidget: const Text('Nenhum item vinculado'),
                      ),

                      const SizedBox(height: 84),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                decoration: BoxDecoration(
                  // Match the dialog surface including surface tint/elevation overlay
                  color: ElevationOverlay.applySurfaceTint(
                    Theme.of(context).colorScheme.surface,
                    Theme.of(context).colorScheme.surfaceTint,
                    Theme.of(context).dialogTheme.elevation ?? 6.0,
                  ),
                  border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 8, offset: Offset(0, -2))],
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: SafeArea(
                  top: false,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(onPressed: _saving ? null : () => Navigator.pop(context), child: const Text('Cancelar')),
                      const SizedBox(width: 8),
                      FilledButton(onPressed: _saving ? null : _save, child: Text(_saving ? 'Salvando...' : 'Salvar')),
                    ],
                  ),
                ),
              ),
            ),
            if (_saving)
              Positioned.fill(
                child: AbsorbPointer(
                  child: ColoredBox(
                    color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.8),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const CircularProgressIndicator(),
                          const SizedBox(height: 12),
                          Text('Salvando...', style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ]),
        ),
      ),
    );
  }
}

class _CostItem {
  final TextEditingController descController = TextEditingController();
  final TextEditingController valueController = TextEditingController();
  void dispose() { descController.dispose(); valueController.dispose(); }
}

class _CatalogItem {
  final String itemType; // 'product' | 'package'
  final String itemId;
  final String name;
  final String currency;
  int priceCents; // mutável
  int quantity; // mutável
  final TextEditingController priceController; // Controller para o campo de preço
  final TextEditingController quantityController; // Controller para o campo de quantidade

  _CatalogItem({
    required this.itemType,
    required this.itemId,
    required this.name,
    required this.currency,
    required this.priceCents,
    required this.quantity,
  }) : priceController = TextEditingController(
         text: (priceCents / 100.0).toStringAsFixed(2).replaceAll('.', ','),
       ),
       quantityController = TextEditingController(
         text: quantity.toString(),
       );

  // Métodos para atualizar valores sem recriar o objeto
  void updatePriceCents(int cents) {
    priceCents = cents;
  }

  void updateQuantity(int qty) {
    quantity = qty;
  }

  _CatalogItem copyWith({
    String? itemType,
    String? itemId,
    String? name,
    String? currency,
    int? priceCents,
    int? quantity,
  }) {
    final newItem = _CatalogItem(
      itemType: itemType ?? this.itemType,
      itemId: itemId ?? this.itemId,
      name: name ?? this.name,
      currency: currency ?? this.currency,
      priceCents: priceCents ?? this.priceCents,
      quantity: quantity ?? this.quantity,
    );
    // Se o preço mudou, atualiza o controller
    if (priceCents != null && priceCents != this.priceCents) {
      newItem.priceController.text = (priceCents / 100.0).toStringAsFixed(2).replaceAll('.', ',');
    } else {
      // Mantém o texto atual do controller (preserva o que o usuário está digitando)
      newItem.priceController.text = priceController.text;
    }
    // Se a quantidade mudou, atualiza o controller
    if (quantity != null && quantity != this.quantity) {
      newItem.quantityController.text = quantity.toString();
    } else {
      // Mantém o texto atual do controller (preserva o que o usuário está digitando)
      newItem.quantityController.text = quantityController.text;
    }
    return newItem;
  }

  void dispose() {
    priceController.dispose();
    quantityController.dispose();
  }
}

class _SelectCatalogItemDialog extends StatefulWidget {
  final String currency;
  const _SelectCatalogItemDialog({required this.currency});
  @override
  State<_SelectCatalogItemDialog> createState() => _SelectCatalogItemDialogState();
}

class _SelectCatalogItemDialogState extends State<_SelectCatalogItemDialog> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _products = [];
  List<Map<String, dynamic>> _packages = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final prods = await productsModule.getProductsByCurrency(widget.currency);
      final packs = await productsModule.getPackagesByCurrency(widget.currency);
      if (!mounted) return;
      setState(() {
        _products = prods;
        _packages = packs;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  String _fmt(int cents) => (cents/100.0).toStringAsFixed(2).replaceAll('.', ',');
  String _sym(String? code) {
    if (code == 'USD') return '\$';
    if (code == 'EUR') return '€';
    return 'R\$';
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: 560, maxHeight: MediaQuery.of(context).size.height * 0.8),
          child: _loading ? const Center(child: CircularProgressIndicator()) : DefaultTabController(
            length: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text('Erro: $_error', style: TextStyle(color: Theme.of(context).colorScheme.error)),
                  ),
                const TabBar(tabs: [Tab(text: 'Produtos'), Tab(text: 'Pacotes')]),
                const Divider(height: 1),
                Expanded(
                  child: TabBarView(children: [
                    ListView.separated(
                      itemCount: _products.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, i) {
                        final p = _products[i];
                        return ListTile(
                          title: Text(p['name'] ?? ''),
                          subtitle: Text('${_sym(p['currency_code'] as String?)} ${_fmt((p['price_cents'] ?? 0) as int)}'),
                          onTap: () => Navigator.pop(context, _CatalogItem(
                            itemType: 'product',
                            itemId: p['id'] as String,
                            name: p['name'] as String? ?? '-',
                            currency: p['currency_code'] as String? ?? 'BRL',
                            priceCents: p['price_cents'] as int? ?? 0,
                            quantity: 1,
                          )),
                        );
                      },
                    ),
                    ListView.separated(
                      itemCount: _packages.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, i) {
                        final p = _packages[i];
                        return ListTile(
                          title: Text(p['name'] ?? ''),
                          subtitle: Text('${_sym(p['currency_code'] as String?)} ${_fmt((p['price_cents'] ?? 0) as int)}'),
                          onTap: () => Navigator.pop(context, _CatalogItem(
                            itemType: 'package',
                            itemId: p['id'] as String,
                            name: p['name'] as String? ?? '-',
                            currency: p['currency_code'] as String? ?? 'BRL',
                            priceCents: p['price_cents'] as int? ?? 0,
                            quantity: 1,
                          )),
                        );
                      },
                    ),
                  ]),
                ),
              ],
            ),
            ),
        ),
      ),
    );
  }
}
*/


