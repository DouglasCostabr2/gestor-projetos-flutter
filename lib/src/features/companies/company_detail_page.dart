import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../state/app_state_scope.dart';
import '../../state/app_state.dart';
import '../../navigation/tab_manager_scope.dart';
import '../../navigation/tab_item.dart';
import '../projects/project_form_dialog.dart';
import '../projects/project_detail_page.dart';
import 'package:my_business/ui/organisms/tables/dynamic_paginated_table.dart';
import 'package:my_business/ui/organisms/tables/reusable_data_table.dart';
import '../../../ui/molecules/user_avatar_name.dart';
import '../../../ui/molecules/table_cells/responsible_cell.dart';
import 'package:my_business/ui/organisms/tables/table_search_filter_bar.dart';
import 'package:my_business/ui/organisms/dialogs/dialogs.dart';
import 'package:my_business/ui/atoms/buttons/buttons.dart';
import '../../../ui/organisms/tabs/tabs.dart';
import '../../../modules/modules.dart';
import '../clients/client_detail_page.dart';
import 'companies_page.dart';
import '../projects/widgets/project_status_badge.dart';
import '../../utils/project_helpers.dart';
import 'package:my_business/ui/organisms/cards/cards.dart';
import 'widgets/company_info_card_items.dart';
import '../clients/widgets/design_materials/design_materials_tab.dart';

class CompanyDetailPage extends StatefulWidget {
  final String companyId;
  const CompanyDetailPage({super.key, required this.companyId});

  @override
  State<CompanyDetailPage> createState() => _CompanyDetailPageState();
}

class _CompanyDetailPageState extends State<CompanyDetailPage> {
  late Future<Map<String, dynamic>?> _companyFuture;
  List<Map<String, dynamic>> _projects = [];
  List<Map<String, dynamic>> _filteredProjects = [];
  bool _projectsLoading = true;
  final Set<String> _selectedProjects = <String>{};

  // Busca e filtros
  String _searchQuery = '';
  String _filterType = 'none'; // none, status, value, person
  String? _filterValue;

  // Lista de usuários para o filtro de pessoas
  List<Map<String, dynamic>> _allUsers = [];

  // Ordenação - padrão por "Criado" (coluna 6) decrescente
  int? _sortColumnIndex = 6;
  bool _sortAscending = false;

  @override
  void initState() {
    super.initState();
    _companyFuture = _loadCompany();
    _reloadProjects();
  }

  Future<Map<String, dynamic>?> _loadCompany() async {
    final res = await Supabase.instance.client
        .from('companies')
        .select('*, clients(id, name, avatar_url)')
        .eq('id', widget.companyId)
        .maybeSingle();
    return res;
  }

  /// Constrói os cards de informações da empresa (similar ao design da project detail page)
  Widget _buildCompanyInfoCards({
    required BuildContext context,
    required Map<String, dynamic> company,
  }) {
    final appState = AppStateScope.of(context);
    final canAccessClientPage = appState.isAdmin || appState.isGestor;

    // Card esquerdo: Nome da Empresa + Cliente
    final leftCardItems = <InfoCardItem>[
      CompanyInfoCardItems.buildCompanyNameItem(context, company),
      CompanyInfoCardItems.buildClientItem(
        context,
        company['client_id'] as String?,
        company['clients']?['name'] ?? '-',
        company['clients']?['avatar_url'] as String?,
        canNavigate: canAccessClientPage,
      ),
    ];

    // Card direito: Notas/Observações
    final rightCardItems = <InfoCardItem>[
      CompanyInfoCardItems.buildNotesItem(context, company),
    ];

    return InfoCardsSection(
      leftCard: InfoCard(
        items: leftCardItems,
        minWidth: 120,
        minHeight: 104,
        totalItems: 2,
        debugEmoji: '🏢',
        debugDescription: 'Nome da Empresa/Cliente',
      ),
      rightCard: InfoCard(
        items: rightCardItems,
        minWidth: 120,
        minHeight: 104,
        totalItems: 1,
        debugEmoji: '📝',
        debugDescription: 'Notas/Observações',
      ),
    );
  }

  Future<List<Map<String, dynamic>>> _loadProjects() async {
    try {
      // NOTA: Não usar RPC porque task_assignees não inclui assignee_user_ids
      // Buscar projetos manualmente e enriquecer com múltiplos responsáveis
      final projects = await companiesModule.getCompanyProjectsWithStats(widget.companyId);

      // FIX: A RPC function não retorna value_cents, currency_code e description_json
      // Buscar esses campos separadamente
      if (projects.isNotEmpty) {
        final projectIds = projects.map((p) => p['id'] as String).toList();
        final additionalFields = await Supabase.instance.client
            .from('projects')
            .select('id, value_cents, currency_code, description_json')
            .inFilter('id', projectIds);

        // Criar um mapa para acesso rápido
        final fieldsMap = <String, Map<String, dynamic>>{};
        for (final field in additionalFields) {
          fieldsMap[field['id'] as String] = field;
        }

        // Adicionar os campos aos projetos
        for (final project in projects) {
          final id = project['id'] as String;
          if (fieldsMap.containsKey(id)) {
            project['value_cents'] = fieldsMap[id]!['value_cents'];
            project['currency_code'] = fieldsMap[id]!['currency_code'];
            project['description_json'] = fieldsMap[id]!['description_json'];
          }

          // Debug: verificar campos financeiros da RPC
        }
      }

      // Transformar os dados para o formato esperado pela UI
      for (final project in projects) {
        // Dados do cliente já vêm agregados
        if (project['client_name'] != null) {
          project['clients'] = {
            'name': project['client_name'],
            'company': project['client_company'],
            'avatar_url': project['client_avatar_url'],
          };
        }

        // Dados do owner já vêm agregados
        if (project['owner_full_name'] != null) {
          project['profiles'] = {
            'full_name': project['owner_full_name'],
            'avatar_url': project['owner_avatar_url'],
          };
        }

        // Dados do updated_by já vêm agregados
        if (project['updated_by_full_name'] != null) {
          project['updated_by_profile'] = {
            'full_name': project['updated_by_full_name'],
            'avatar_url': project['updated_by_avatar_url'],
          };
        }

        // task_assignees vem da RPC mas NÃO inclui assignee_user_ids
        // Precisamos enriquecer manualmente
        project['task_assignees'] = [];

        // Calcular valor total do catálogo (já vem agregado em total_catalog_value_cents)
        // project_catalog_items não é mais necessário para cálculo,
        // mas se a UI precisar, pode ser buscado separadamente
        project['project_catalog_items'] = [];
      }

      // Enriquecer task_assignees com múltiplos responsáveis usando helper
      await ProjectAssigneesHelper.enrichWithAssignees(projects);

      return projects;
    } catch (e) {
      return [];
    }
  }

  Future<void> _reloadProjects() async {
    setState(() => _projectsLoading = true);
    final res = await _loadProjects();

    // Buscar todos os usuários para o filtro de pessoas
    final usersRes = await Supabase.instance.client
        .from('profiles')
        .select('id, full_name, email, avatar_url')
        .order('full_name', ascending: true);

    if (!mounted) return;
    setState(() {
      _projects = res;
      _allUsers = List<Map<String, dynamic>>.from(usersRes);
      _projectsLoading = false;
    });
    _applyFilters();
  }

  void _applyFilters() {
    setState(() {
      var filtered = List<Map<String, dynamic>>.from(_projects);

      // Aplicar busca
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        filtered = filtered.where((project) {
          final name = (project['name'] ?? '').toString().toLowerCase();
          return name.contains(query);
        }).toList();
      }

      // Aplicar filtro selecionado
      if (_filterType != 'none' && _filterValue != null && _filterValue!.isNotEmpty) {
        filtered = filtered.where((project) {
          switch (_filterType) {
            case 'status':
              return project['status'] == _filterValue;
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

      _filteredProjects = filtered;

      // Aplicar ordenação inicial (sempre pela primeira coluna - Nome)
      _applySorting();
    });
  }

  void _applySorting() {
    if (_sortColumnIndex == null) return;

    final comparators = _getSortComparators();
    final comparator = comparators[_sortColumnIndex!];

    _filteredProjects.sort((a, b) {
      final result = comparator(a, b);
      return _sortAscending ? result : -result;
    });
  }

  List<int Function(Map<String, dynamic>, Map<String, dynamic>)> _getSortComparators() {
    return [
      // Nome
      (a, b) => (a['name'] ?? '').toString().toLowerCase().compareTo((b['name'] ?? '').toString().toLowerCase()),
      // Tasks
      (a, b) => ((a['pending_tasks_count'] ?? 0) as int).compareTo((b['pending_tasks_count'] ?? 0) as int),
      // Pessoas (não ordenável)
      (a, b) => 0,
      // Valor
      (a, b) {
        // Usar o valor agregado que já vem da RPC function
        final aTotal = (a['total_catalog_value_cents'] as int? ?? 0);
        final bTotal = (b['total_catalog_value_cents'] as int? ?? 0);
        return aTotal.compareTo(bTotal);
      },
      // Status
      (a, b) => (a['status'] ?? 'active').toString().compareTo((b['status'] ?? 'active').toString()),
      // Última Atualização
      (a, b) {
        final dateA = a['updated_at'] != null ? DateTime.tryParse(a['updated_at']) : null;
        final dateB = b['updated_at'] != null ? DateTime.tryParse(b['updated_at']) : null;
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
    ];
  }

  List<String> _getFilterOptions() {
    switch (_filterType) {
      case 'status':
        return ['not_started', 'negotiation', 'in_progress', 'paused', 'completed', 'cancelled'];
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
        switch (value) {
          case 'not_started':
            return 'Não iniciado';
          case 'negotiation':
            return 'Em negociação';
          case 'in_progress':
            return 'Em andamento';
          case 'paused':
            return 'Pausado';
          case 'completed':
            return 'Concluído';
          case 'cancelled':
            return 'Cancelado';
          default:
            return value;
        }
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

  Future<void> _openNewProjectDialog() async {
    final company = await _companyFuture;
    if (company == null) return;

    if (!mounted) return;

    final created = await DialogHelper.show<bool>(
      context: context,
      builder: (context) => ProjectFormDialog(
        fixedClientId: company['client_id'],
        fixedCompanyId: widget.companyId,
      ),
    );
    if (created == true && mounted) {
      await _reloadProjects();
    }
  }

  Future<void> _openEditCompanyDialog(Map<String, dynamic> company) async {
    final saved = await DialogHelper.show<bool>(
      context: context,
      builder: (context) => CompanyFormDialog(
        clientId: company['client_id'],
        initial: company,
      ),
    );
    if (saved == true && mounted) {
      setState(() {
        _companyFuture = _loadCompany();
      });
    }
  }

  Future<void> _bulkDeleteProjects() async {
    final count = _selectedProjects.length;
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
        for (final projectId in _selectedProjects) {
          await Supabase.instance.client
              .from('projects')
              .delete()
              .eq('id', projectId);
        }

        if (!mounted) return;

        // Limpar seleção
        setState(() {
          _selectedProjects.clear();
        });

        // Recarregar projetos
        _reloadProjects();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$count projeto${count > 1 ? 's excluídos' : ' excluído'} com sucesso')),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao excluir projetos: $e')),
        );
      }
    }
  }

  Future<void> _deleteCompany(Map<String, dynamic> company) async {
    final confirm = await DialogHelper.show<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar exclusão'),
        content: const Text('Deseja realmente excluir esta empresa? Todos os projetos associados também serão excluídos.'),
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
        await Supabase.instance.client
            .from('companies')
            .delete()
            .eq('id', widget.companyId);

        if (!mounted) return;
        Navigator.pop(context); // Volta para a página anterior
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao excluir empresa: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = AppStateScope.of(context);
    return Material(
      type: MaterialType.transparency,
      child: FutureBuilder<Map<String, dynamic>?>(
              future: _companyFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError || snapshot.data == null) {
                  return const Center(child: Text('Erro ao carregar empresa'));
                }
                final company = snapshot.data!;

                return SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                      Row(
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
                                  // Se não há histórico, volta para a página do Cliente
                                  final clientId = company['client_id'] as String?;
                                  if (clientId != null) {
                                    final tabId = 'client_$clientId';
                                    final clientTab = TabItem(
                                      id: tabId,
                                      title: 'Cliente',
                                      icon: Icons.person,
                                      page: ClientDetailPage(
                                        key: ValueKey(tabId),
                                        clientId: clientId,
                                      ),
                                      canClose: true,
                                      selectedMenuIndex: 1, // Índice do menu de Clientes
                                    );
                                    tabManager.updateTab(tabManager.currentIndex, clientTab, saveToHistory: false);
                                  }
                                }
                              } else {
                                // Fallback para navegação tradicional
                                Navigator.of(context).pop();
                              }
                            },
                          ),
                          Text('Empresa', style: Theme.of(context).textTheme.headlineSmall),
                          const Spacer(),
                          if (appState.isAdminOrGestor) ...[
                            IconOnlyButton(
                              icon: Icons.edit,
                              tooltip: 'Editar Empresa',
                              onPressed: () => _openEditCompanyDialog(company),
                            ),
                            IconOnlyButton(
                              icon: Icons.delete,
                              tooltip: 'Excluir Empresa',
                              onPressed: () => _deleteCompany(company),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Cards de informações da empresa
                      _buildCompanyInfoCards(
                        context: context,
                        company: company,
                      ),
                      const SizedBox(height: 16),

                      // Abas: Tabela / Financeiro / Contas / Design Materials usando componente genérico
                      GenericTabView(
                        height: 600,
                        tabs: const [
                          TabConfig(text: 'Tabela'),
                          TabConfig(text: 'Financeiro'),
                          TabConfig(text: 'Contas'),
                          TabConfig(text: 'Design Materials', icon: Icons.folder_special),
                        ],
                        children: [
                          _buildProjectsTab(appState, company),
                          _buildFinancialTab(),
                          _buildAccountsTab(company),
                          _buildDesignMaterialsTab(company),
                        ],
                      ),
                    ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  // Aba de Projetos (Tabela)
  Widget _buildProjectsTab(AppState appState, Map<String, dynamic> company) {
    return Column(
      children: [
        const SizedBox(height: 16),

        // Barra de busca e filtros
        TableSearchFilterBar(
          searchHint: 'Buscar projeto (nome...)',
          onSearchChanged: (value) {
            _searchQuery = value;
            _applyFilters();
          },
          filterType: _filterType,
          filterTypeLabel: 'Tipo de filtro',
          filterTypeOptions: const [
            FilterOption(value: 'none', label: 'Nenhum'),
            FilterOption(value: 'status', label: 'Status'),
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
          selectedCount: _selectedProjects.length,
          bulkActions: appState.isAdminOrGestor ? [
            BulkAction(
              icon: Icons.delete,
              label: 'Excluir selecionados',
              color: Colors.red,
              onPressed: _bulkDeleteProjects,
            ),
          ] : null,
          actionButton: appState.isAdminOrGestor ? FilledButton.icon(
            onPressed: _openNewProjectDialog,
            icon: const Icon(Icons.add),
            label: const Text('Novo Projeto'),
          ) : null,
        ),

        const SizedBox(height: 16),

        // Tabela com paginação dinâmica
        Expanded(
          child: DynamicPaginatedTable<Map<String, dynamic>>(
            items: _filteredProjects,
            itemLabel: 'projeto(s)',
            selectedIds: _selectedProjects,
            onSelectionChanged: (ids) => setState(() => _selectedProjects
              ..clear()
              ..addAll(ids)),
            columns: const [
              DataTableColumn(label: 'Nome', sortable: true),
              DataTableColumn(label: 'Tasks', sortable: true),
              DataTableColumn(label: 'Membros'),
              DataTableColumn(label: 'Valor', sortable: true),
              DataTableColumn(label: 'Status', sortable: true),
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
            isLoading: _projectsLoading,
            loadingWidget: const Center(child: CircularProgressIndicator()),
            emptyWidget: const Center(child: Text('Nenhum projeto encontrado')),
            sortComparators: [
                (a, b) => (a['name'] ?? '').toString().toLowerCase().compareTo((b['name'] ?? '').toString().toLowerCase()),
                              (a, b) => ((a['pending_tasks_count'] ?? 0) as int).compareTo((b['pending_tasks_count'] ?? 0) as int),
                              (a, b) => 0, // Pessoas não ordenável
                              (a, b) {
                                // Priorizar value_cents (valor manual) se existir, senão usar total_catalog_value_cents (soma dos itens)
                                final aValueCents = a['value_cents'] as int?;
                                final aTotalCatalogCents = a['total_catalog_value_cents'] as int? ?? 0;
                                final aDisplayCents = (aValueCents != null && aValueCents > 0) ? aValueCents : aTotalCatalogCents;

                                final bValueCents = b['value_cents'] as int?;
                                final bTotalCatalogCents = b['total_catalog_value_cents'] as int? ?? 0;
                                final bDisplayCents = (bValueCents != null && bValueCents > 0) ? bValueCents : bTotalCatalogCents;

                                return aDisplayCents.compareTo(bDisplayCents);
                              },
                              (a, b) => (a['status'] ?? 'active').toString().compareTo((b['status'] ?? 'active').toString()),
                              (a, b) {
                                final dateA = a['updated_at'] != null ? DateTime.tryParse(a['updated_at']) : null;
                                final dateB = b['updated_at'] != null ? DateTime.tryParse(b['updated_at']) : null;
                                if (dateA == null && dateB == null) return 0;
                                if (dateA == null) return 1;
                                if (dateB == null) return -1;
                                return dateA.compareTo(dateB);
                              },
                              (a, b) {
                                final dateA = a['created_at'] != null ? DateTime.tryParse(a['created_at']) : null;
                                final dateB = b['created_at'] != null ? DateTime.tryParse(b['created_at']) : null;
                                if (dateA == null && dateB == null) return 0;
                                if (dateA == null) return 1;
                                if (dateB == null) return -1;
                                return dateA.compareTo(dateB);
                              },
                            ],
                            cellBuilders: [
                              // Nome
                              (p) => Text(p['name'] ?? 'Sem nome'),

                              // Tasks não concluídas
                              (p) {
                                final count = p['pending_tasks_count'] ?? 0;
                                return Text('$count');
                              },

                              // Pessoas (avatares dos assignees das tasks)
                              // REFATORADO: Usa ResponsibleCell para consistência
                              (p) => ResponsibleCell(
                                people: p['task_assignees'] as List?,
                              ),

                              // Valor
                              (p) {
                                final currency = p['currency_code'] as String? ?? 'BRL';
                                final currencySymbol = _getCurrencySymbol(currency);

                                // Priorizar value_cents (valor manual) se existir, senão usar total_catalog_value_cents (soma dos itens)
                                final valueCents = p['value_cents'] as int?;
                                final totalCatalogCents = p['total_catalog_value_cents'] as int? ?? 0;
                                final displayCents = (valueCents != null && valueCents > 0) ? valueCents : totalCatalogCents;
                                final displayValue = displayCents / 100.0;

                                return Text('$currencySymbol ${displayValue.toStringAsFixed(2).replaceAll('.', ',')}');
                              },

                              // Status
                              (p) {
                                final status = p['status'] ?? 'not_started';
                                return ProjectStatusBadge(status: status);
                              },

                              // Última Atualização
                              (p) {
                                final updatedAt = p['updated_at'];
                                final updatedByProfile = p['updated_by_profile'] as Map<String, dynamic>?;

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

                              // Criado em
                              (p) {
                                final createdAt = p['created_at'];
                                if (createdAt == null) return const Text('-');
                                try {
                                  final date = DateTime.parse(createdAt);
                                  return Text('${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}');
                                } catch (e) {
                                  return const Text('-');
                                }
                              },
                            ],
                            getId: (p) => p['id'] as String,
                            onRowTap: (p) {
                              final tabManager = TabManagerScope.maybeOf(context);
                              if (tabManager != null) {
                                final projectId = p['id'].toString();
                                final projectName = p['name'] as String? ?? 'Projeto';
                                final tabId = 'project_$projectId';

                                // Atualiza a aba atual em vez de criar uma nova
                                final currentIndex = tabManager.currentIndex;
                                final updatedTab = TabItem(
                                  id: tabId,
                                  title: projectName,
                                  icon: Icons.work,
                                  page: ProjectDetailPage(
                                    key: ValueKey(tabId),
                                    projectId: projectId,
                                  ),
                                  canClose: true,
                                );
                                tabManager.updateTab(currentIndex, updatedTab);
                              }
                            },
                            actions: appState.isAdminOrGestor ? [
                              DataTableAction<Map<String, dynamic>>(
                                icon: Icons.edit,
                                label: 'Editar',
                                onPressed: (p) async {
                                  final changed = await DialogHelper.show<bool>(
                                    context: context,
                                    builder: (context) => ProjectFormDialog(
                                      fixedClientId: company['client_id'],
                                      fixedCompanyId: widget.companyId,
                                      initial: p,
                                    ),
                                  );
                                  if (changed == true) _reloadProjects();
                                },
                              ),
                              DataTableAction<Map<String, dynamic>>(
                                icon: Icons.content_copy,
                                label: 'Duplicar',
                                onPressed: (p) async {
                                  try {
                                    // Usar o módulo de projetos para criar, passando apenas os campos necessários
                                    await projectsModule.createProject(
                                      name: '${p['name'] ?? ''} (Cópia)',
                                      description: p['description'] ?? '',
                                      clientId: p['client_id'],
                                      companyId: p['company_id'],
                                      priority: p['priority'] ?? 'medium',
                                      status: p['status'] ?? 'active',
                                      currencyCode: p['currency_code'],
                                      startDate: p['start_date'] != null
                                          ? DateTime.tryParse(p['start_date'])
                                          : null,
                                      dueDate: p['due_date'] != null
                                          ? DateTime.tryParse(p['due_date'])
                                          : null,
                                    );

                                    if (mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Projeto duplicado com sucesso')),
                                      );
                                      _reloadProjects();
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
                                onPressed: (p) async {
                                  final confirm = await DialogHelper.show<bool>(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      title: const Text('Confirmar exclusão'),
                                      content: const Text('Deseja realmente excluir este projeto?'),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.pop(context, false),
                                          child: const Text('Cancelar'),
                                        ),
                                        TextButton(
                                          onPressed: () => Navigator.pop(context, true),
                                          child: const Text('Excluir'),
                                        ),
                                      ],
                                    ),
                                  );
                                  if (confirm == true) {
                                    await Supabase.instance.client
                                        .from('projects')
                                        .delete()
                                        .eq('id', p['id']);
                                    _reloadProjects();
                                  }
                                },
                              ),
                            ] : null,
          ),
        ),
      ],
    );
  }



  // Aba Financeiro
  Widget _buildFinancialTab() {
    if (_projectsLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_projects.isEmpty) {
      return const Center(
        child: Text('Nenhum projeto encontrado'),
      );
    }

    // Agrupar projetos por moeda
    final Map<String, List<Map<String, dynamic>>> projectsByCurrency = {};

    for (final project in _projects) {
      final currency = project['currency_code'] as String? ?? 'BRL';
      if (!projectsByCurrency.containsKey(currency)) {
        projectsByCurrency[currency] = [];
      }
      projectsByCurrency[currency]!.add(project);
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Sanfonas por moeda
          ...projectsByCurrency.entries.map((entry) {
            final currency = entry.key;
            final projects = entry.value;

            // Calcular totais
            double totalValue = 0;
            double paidValue = 0;
            double pendingValue = 0;

            for (final project in projects) {
              // Calcular valor total do projeto usando os valores agregados da RPC
              // Lógica: Se value_cents > 0, usar value_cents (valor manual), senão usar total_catalog_value_cents
              // Sempre adicionar total_additional_costs_cents
              final valueCents = project['value_cents'] as int? ?? 0;
              final additionalCostsCents = project['total_additional_costs_cents'] as int? ?? 0;
              final catalogCents = project['total_catalog_value_cents'] as int? ?? 0;

              // Priorizar value_cents se existir, senão usar catalogCents
              final baseCents = valueCents > 0 ? valueCents : catalogCents;
              final projectTotalCents = baseCents + additionalCostsCents;
              final projectTotal = projectTotalCents / 100.0;

              totalValue += projectTotal;

              // Usar pagamentos recebidos ao invés do status
              final receivedCents = project['total_received_cents'] as int? ?? 0;
              final receivedValue = receivedCents / 100;

              paidValue += receivedValue;

              // Pendente = Total do projeto - Recebido
              final projectPending = projectTotal - receivedValue;
              if (projectPending > 0) {
                pendingValue += projectPending;
              }
            }

            return _buildCurrencyExpansionTile(
              currency,
              totalValue,
              paidValue,
              pendingValue,
              projects,
            );
          }),
        ],
      ),
    );
  }

  Widget _buildCurrencyExpansionTile(
    String currency,
    double totalValue,
    double paidValue,
    double pendingValue,
    List<Map<String, dynamic>> projects,
  ) {
    final currencySymbol = _getCurrencySymbol(currency);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              currency,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            Row(
              children: [
                Text(
                  '$currencySymbol ${totalValue.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 8),
              ],
            ),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              children: [
                // Recebido
                InkWell(
                  onTap: paidValue > 0 ? () => _showPaidProjectsDialog(currency, projects) : null,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle, color: Colors.green, size: 20),
                        const SizedBox(width: 12),
                        const Text(
                          'Recebido',
                          style: TextStyle(fontSize: 16),
                        ),
                        const Spacer(),
                        Row(
                          children: [
                            Text(
                              '$currencySymbol ${paidValue.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: Colors.green,
                              ),
                            ),
                            const SizedBox(width: 4),
                            if (paidValue > 0)
                              const Icon(Icons.chevron_right, size: 20, color: Colors.green),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                // Pendente
                InkWell(
                  onTap: pendingValue > 0 ? () => _showPendingProjectsDialog(currency, projects) : null,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Row(
                      children: [
                        const Icon(Icons.pending, color: Colors.grey, size: 20),
                        const SizedBox(width: 12),
                        const Text(
                          'Pendente',
                          style: TextStyle(fontSize: 16),
                        ),
                        const Spacer(),
                        Row(
                          children: [
                            Text(
                              '$currencySymbol ${pendingValue.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(width: 4),
                            if (pendingValue > 0)
                              const Icon(Icons.chevron_right, size: 20),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getCurrencySymbol(String currencyCode) {
    switch (currencyCode) {
      case 'BRL':
        return 'R\$';
      case 'USD':
        return '\$';
      case 'EUR':
        return '€';
      default:
        return currencyCode;
    }
  }

  void _showPaidProjectsDialog(String currency, List<Map<String, dynamic>> projects) {
    final currencySymbol = _getCurrencySymbol(currency);

    // Filtrar apenas projetos que têm pagamentos recebidos
    final paidProjects = projects.where((project) {
      final receivedCents = project['total_received_cents'] as int? ?? 0;
      return receivedCents > 0;
    }).toList();

    if (paidProjects.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nenhum pagamento recebido encontrado')),
      );
      return;
    }

    // Capturar TabManager ANTES de abrir o dialog
    final tabManager = TabManagerScope.maybeOf(context);

    DialogHelper.show(
      context: context,
      builder: (dialogContext) => StandardDialog(
        title: 'Pagamentos Recebidos ($currency)',
        width: StandardDialog.widthMedium,
        height: StandardDialog.heightMedium,
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: paidProjects.length,
          itemBuilder: (listContext, index) {
            final project = paidProjects[index];
            final projectId = project['id'] as String;
            final projectName = project['name'] as String? ?? 'Sem nome';

            // Usar valor recebido ao invés do total do projeto
            final receivedCents = project['total_received_cents'] as int? ?? 0;
            final receivedValue = receivedCents / 100;

            return ListTile(
              leading: const Icon(Icons.check_circle, color: Colors.green),
              title: Text(projectName),
              subtitle: Text('$currencySymbol ${receivedValue.toStringAsFixed(2)}'),
              trailing: const Icon(Icons.arrow_forward),
              onTap: () {
                Navigator.pop(dialogContext);

                // Usar TabManager capturado ANTES do dialog
                if (tabManager != null) {
                  final tabId = 'project_$projectId';
                  final currentIndex = tabManager.currentIndex;
                  final updatedTab = TabItem(
                    id: tabId,
                    title: projectName,
                    icon: Icons.folder,
                    page: ProjectDetailPage(
                      key: ValueKey('project_$projectId'),
                      projectId: projectId,
                    ),
                    canClose: true,
                  );
                  tabManager.updateTab(currentIndex, updatedTab);
                } else {
                  // Fallback
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ProjectDetailPage(projectId: projectId),
                    ),
                  );
                }
              },
            );
          },
        ),
      ),
    );
  }

  void _showPendingProjectsDialog(String currency, List<Map<String, dynamic>> projects) {
    final currencySymbol = _getCurrencySymbol(currency);

    // Filtrar apenas projetos que têm valores pendentes
    final pendingProjects = projects.where((project) {
      // Calcular valor total do projeto usando os valores agregados da RPC
      // Lógica: Se value_cents > 0, usar value_cents, senão usar total_catalog_value_cents
      final valueCents = project['value_cents'] as int? ?? 0;
      final additionalCostsCents = project['total_additional_costs_cents'] as int? ?? 0;
      final catalogCents = project['total_catalog_value_cents'] as int? ?? 0;

      final baseCents = valueCents > 0 ? valueCents : catalogCents;
      final projectTotalCents = baseCents + additionalCostsCents;
      final projectTotal = projectTotalCents / 100.0;

      final receivedCents = project['total_received_cents'] as int? ?? 0;
      final receivedValue = receivedCents / 100;
      final pendingValue = projectTotal - receivedValue;

      return pendingValue > 0;
    }).toList();

    if (pendingProjects.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nenhum valor pendente encontrado')),
      );
      return;
    }

    // Capturar TabManager ANTES de abrir o dialog
    final tabManager = TabManagerScope.maybeOf(context);

    DialogHelper.show(
      context: context,
      builder: (dialogContext) => StandardDialog(
        title: 'Valores Pendentes ($currency)',
        width: StandardDialog.widthMedium,
        height: StandardDialog.heightMedium,
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: pendingProjects.length,
          itemBuilder: (listContext, index) {
            final project = pendingProjects[index];
            final projectId = project['id'] as String;
            final projectName = project['name'] as String? ?? 'Sem nome';

            // Calcular valor pendente do projeto usando os valores agregados da RPC
            // Lógica: Se value_cents > 0, usar value_cents, senão usar total_catalog_value_cents
            final valueCents = project['value_cents'] as int? ?? 0;
            final additionalCostsCents = project['total_additional_costs_cents'] as int? ?? 0;
            final catalogCents = project['total_catalog_value_cents'] as int? ?? 0;

            final baseCents = valueCents > 0 ? valueCents : catalogCents;
            final projectTotalCents = baseCents + additionalCostsCents;
            final projectTotal = projectTotalCents / 100.0;

            final receivedCents = project['total_received_cents'] as int? ?? 0;
            final receivedValue = receivedCents / 100;
            final pendingValue = projectTotal - receivedValue;

            return ListTile(
              leading: const Icon(Icons.pending, color: Colors.grey),
              title: Text(projectName),
              subtitle: Text('$currencySymbol ${pendingValue.toStringAsFixed(2)}'),
              trailing: const Icon(Icons.arrow_forward),
              onTap: () {
                Navigator.pop(dialogContext);

                // Usar TabManager capturado ANTES do dialog
                if (tabManager != null) {
                  final tabId = 'project_$projectId';
                  final currentIndex = tabManager.currentIndex;
                  final updatedTab = TabItem(
                    id: tabId,
                    title: projectName,
                    icon: Icons.folder,
                    page: ProjectDetailPage(
                      key: ValueKey('project_$projectId'),
                      projectId: projectId,
                    ),
                    canClose: true,
                  );
                  tabManager.updateTab(currentIndex, updatedTab);
                } else {
                  // Fallback
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ProjectDetailPage(projectId: projectId),
                    ),
                  );
                }
              },
            );
          },
        ),
      ),
    );
  }

  // Aba de Contas (Redes Sociais e Site)
  Widget _buildAccountsTab(Map<String, dynamic> company) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Redes Sociais em Sanfonas
          if (company['instagram_login'] != null && company['instagram_login'].toString().isNotEmpty)
            _buildSocialExpansionTile(
              'Instagram',
              FontAwesomeIcons.instagram,
              company['instagram_login'],
              company['instagram_password'],
            ),
          if (company['facebook_login'] != null && company['facebook_login'].toString().isNotEmpty)
            _buildSocialExpansionTile(
              'Facebook',
              FontAwesomeIcons.facebook,
              company['facebook_login'],
              company['facebook_password'],
            ),
          if (company['linkedin_login'] != null && company['linkedin_login'].toString().isNotEmpty)
            _buildSocialExpansionTile(
              'LinkedIn',
              FontAwesomeIcons.linkedin,
              company['linkedin_login'],
              company['linkedin_password'],
            ),
          if (company['tiktok_login'] != null && company['tiktok_login'].toString().isNotEmpty)
            _buildSocialExpansionTile(
              'TikTok',
              FontAwesomeIcons.tiktok,
              company['tiktok_login'],
              company['tiktok_password'],
            ),

          // Site em Sanfona
          if (company['website_url'] != null && company['website_url'].toString().isNotEmpty)
            _buildWebsiteExpansionTile(
              company['website_url'],
              company['website_login'],
              company['website_password'],
            ),

          // Plataformas Personalizadas
          if (company['custom_platforms'] != null) ...[
            const SizedBox(height: 16),
            Text('Outras Plataformas', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            ...() {
              final platforms = company['custom_platforms'] as List?;
              if (platforms == null || platforms.isEmpty) {
                return [const Text('Nenhuma plataforma personalizada cadastrada', style: TextStyle(color: Colors.grey))];
              }
              return platforms.map((p) => _buildCustomPlatformExpansionTile(
                p['platform_name'] ?? 'Plataforma',
                p['login'],
                p['password'],
              )).toList();
            }(),
          ],
        ],
      ),
    );
  }

  Widget _buildSocialExpansionTile(String title, IconData icon, String? login, String? password) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ExpansionTile(
        leading: FaIcon(icon, size: 20),
        title: Text(title),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Info('Login', login ?? '-'),
                const SizedBox(height: 12),
                if (password != null && password.isNotEmpty)
                  _PasswordInfo('Senha', password),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWebsiteExpansionTile(String? url, String? login, String? password) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ExpansionTile(
        leading: const Icon(Icons.language, size: 24),
        title: const Text('Site'),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Info('URL', url ?? '-'),
                if (login != null && login.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _Info('Login', login),
                ],
                if (password != null && password.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _PasswordInfo('Senha', password),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomPlatformExpansionTile(String platformName, String? login, String? password) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ExpansionTile(
        leading: const Icon(Icons.apps, size: 24),
        title: Text(platformName),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (login != null && login.isNotEmpty) ...[
                  _Info('Login', login),
                  const SizedBox(height: 12),
                ],
                if (password != null && password.isNotEmpty)
                  _PasswordInfo('Senha', password),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Aba de Design Materials
  Widget _buildDesignMaterialsTab(Map<String, dynamic> company) {
    final companyId = company['id'] as String;
    final companyName = company['name'] as String;

    // Obter dados do cliente
    final client = company['clients'] as Map<String, dynamic>?;
    final clientName = client?['name'] as String? ?? 'Cliente Desconhecido';

    return DesignMaterialsTab(
      companyId: companyId,
      companyName: companyName,
      clientName: clientName,
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
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontSize: 14)),
      ],
    );
  }
}

class _SocialInfo extends StatefulWidget {
  final String platform;
  final String login;
  final String? password;
  const _SocialInfo(this.platform, this.login, this.password);

  @override
  State<_SocialInfo> createState() => _SocialInfoState();
}

class _SocialInfoState extends State<_SocialInfo> {
  bool _showPassword = false;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 250,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.platform, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text('Login: ${widget.login}', style: const TextStyle(fontSize: 12)),
              if (widget.password != null && widget.password!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Senha: ${_showPassword ? widget.password : '••••••••'}',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                    IconOnlyButton(
                      icon: _showPassword ? Icons.visibility_off : Icons.visibility,
                      iconSize: 16,
                      tooltip: _showPassword ? 'Ocultar senha' : 'Mostrar senha',
                      onPressed: () => setState(() => _showPassword = !_showPassword),
                      padding: EdgeInsets.zero,
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _PasswordInfo extends StatefulWidget {
  final String label;
  final String password;
  const _PasswordInfo(this.label, this.password);

  @override
  State<_PasswordInfo> createState() => _PasswordInfoState();
}

class _PasswordInfoState extends State<_PasswordInfo> {
  bool _showPassword = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 4),
        Row(
          children: [
            Text(
              _showPassword ? widget.password : '••••••••',
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(width: 8),
            IconOnlyButton(
              icon: _showPassword ? Icons.visibility_off : Icons.visibility,
              iconSize: 16,
              tooltip: _showPassword ? 'Ocultar senha' : 'Mostrar senha',
              onPressed: () => setState(() => _showPassword = !_showPassword),
              padding: EdgeInsets.zero,
            ),
          ],
        ),
      ],
    );
  }
}

