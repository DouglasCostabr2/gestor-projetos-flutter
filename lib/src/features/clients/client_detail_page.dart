import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../state/app_state_scope.dart';
import '../../state/app_state.dart';
import '../../navigation/tab_manager_scope.dart';
import '../../navigation/tab_item.dart';
import '../../widgets/dynamic_paginated_table.dart';
import '../../../widgets/user_avatar_name.dart';
import '../companies/company_detail_page.dart';
import '../companies/companies_page.dart';
import '../../../widgets/reusable_data_table.dart';
import '../../../widgets/standard_dialog.dart';
import 'package:gestor_projetos_flutter/widgets/buttons/buttons.dart';
import '../../../widgets/table_search_filter_bar.dart';
import '../../../widgets/tabs/tabs.dart';
import 'widgets/client_form.dart';
import 'widgets/client_financial_section.dart';
import 'clients_page_backup.dart';



class ClientDetailPage extends StatefulWidget {
  final String clientId;
  const ClientDetailPage({super.key, required this.clientId});

  @override
  State<ClientDetailPage> createState() => _ClientDetailPageState();
}

class _ClientDetailPageState extends State<ClientDetailPage> {
  late Future<Map<String, dynamic>?> _clientFuture;
  List<Map<String, dynamic>> _companies = [];
  List<Map<String, dynamic>> _filteredCompanies = [];
  bool _companiesLoading = true;
  Set<String> _selectedCompanies = {};

  // Filtros e pesquisa
  String _searchQuery = '';
  String _filterType = 'none'; // none, social_network
  String? _filterValue;

  @override
  void initState() {
    super.initState();
    _clientFuture = _loadClient();
    _reloadCompanies();
  }

  void _applyFilters() {
    setState(() {
      var filtered = List<Map<String, dynamic>>.from(_companies);

      // Aplicar busca
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        filtered = filtered.where((company) {
          final name = (company['name'] ?? '').toString().toLowerCase();
          final website = (company['website_url'] ?? '').toString().toLowerCase();
          return name.contains(query) || website.contains(query);
        }).toList();
      }

      // Aplicar filtro selecionado
      if (_filterType != 'none' && _filterValue != null && _filterValue!.isNotEmpty) {
        filtered = filtered.where((company) {
          switch (_filterType) {
            case 'social_network':
              return company['social_network'] == _filterValue;
            default:
              return true;
          }
        }).toList();
      }

      _filteredCompanies = filtered;
    });
  }

  List<String> _getUniqueSocialNetworks() {
    final networks = _companies
        .map((c) => c['social_network'] as String?)
        .whereType<String>()
        .where((n) => n.isNotEmpty)
        .toSet()
        .toList();
    networks.sort();
    return networks;
  }

  List<String> _getFilterOptions() {
    switch (_filterType) {
      case 'social_network':
        return _getUniqueSocialNetworks();
      case 'none':
        return [];
      default:
        return [];
    }
  }

  String _getFilterLabel() {
    switch (_filterType) {
      case 'social_network':
        return 'Filtrar por rede social';
      case 'none':
        return 'Sem filtro';
      default:
        return 'Filtrar';
    }
  }

  Future<Map<String, dynamic>?> _loadClient() async {
    final res = await Supabase.instance.client
        .from('clients')
        .select('id, name, category, category_id, email, phone, country, state, city, avatar_url, client_categories:category_id(name)')
        .eq('id', widget.clientId)
        .maybeSingle();
    return res;
  }

  void _copyEmail(String email) {
    Clipboard.setData(ClipboardData(text: email));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Email copiado: $email'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _openWhatsApp(String phone) async {
    // Remove caracteres não numéricos
    final cleanPhone = phone.replaceAll(RegExp(r'[^\d+]'), '');
    final url = Uri.parse('https://wa.me/$cleanPhone');

    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível abrir o WhatsApp')),
      );
    }
  }

  Future<List<Map<String, dynamic>>> _loadCompanies() async {
    final res = await Supabase.instance.client
        .from('companies')
        .select('*')
        .eq('client_id', widget.clientId)
        .order('created_at', ascending: false);

    // Buscar informações dos usuários que fizeram a última atualização
    final updatedByIds = res.map((c) => c['updated_by']).whereType<String>().toSet();
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
    final result = List<Map<String, dynamic>>.from(res);
    for (final company in result) {
      final updatedBy = company['updated_by'];
      if (updatedBy != null && usersMap.containsKey(updatedBy)) {
        company['updated_by_profile'] = usersMap[updatedBy];
      }
    }

    return result;
  }

  Future<void> _reloadCompanies() async {
    setState(() => _companiesLoading = true);
    final res = await _loadCompanies();
    if (!mounted) return;
    setState(() {
      _companies = res;
      _filteredCompanies = res;
      _companiesLoading = false;
      _applyFilters();
    });
  }

  Widget _buildCompaniesTab(AppState appState) {
    return Column(
      children: [
        // Barra de busca e filtros
        TableSearchFilterBar(
          searchHint: 'Buscar empresa (nome ou website...)',
          onSearchChanged: (value) {
            _searchQuery = value;
            _applyFilters();
          },
          filterType: _filterType,
          filterTypeLabel: 'Tipo de filtro',
          filterTypeOptions: const [
            FilterOption(value: 'none', label: 'Nenhum'),
            FilterOption(value: 'social_network', label: 'Rede Social'),
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
          onFilterValueChanged: (value) {
            setState(() => _filterValue = value?.isEmpty == true ? null : value);
            _applyFilters();
          },
          actionButton: FilledButton.icon(
            onPressed: () async {
              final saved = await showDialog<bool>(
                context: context,
                builder: (context) => CompanyFormDialog(
                  clientId: widget.clientId,
                ),
              );
              if (saved == true) {
                _reloadCompanies();
              }
            },
            icon: const Icon(Icons.add),
            label: const Text('Adicionar Empresa'),
          ),
        ),

        const SizedBox(height: 8),
        Expanded(
          child: DynamicPaginatedTable<Map<String, dynamic>>(
            items: _filteredCompanies,
            itemLabel: 'empresa(s)',
            selectedIds: _selectedCompanies,
            onSelectionChanged: (ids) => setState(() => _selectedCompanies = ids),
            columns: const [
              DataTableColumn(label: 'Nome', sortable: true),
              DataTableColumn(label: 'Rede Social'),
              DataTableColumn(label: 'Site', sortable: true),
              DataTableColumn(label: 'Última Atualização', sortable: true),
            ],
            isLoading: _companiesLoading,
            loadingWidget: const Center(child: CircularProgressIndicator()),
            emptyWidget: _companies.isEmpty
                ? const Center(child: Text('Nenhuma empresa cadastrada para este cliente'))
                : const Center(child: Text('Nenhuma empresa encontrada com os filtros aplicados')),
            sortComparators: [
              (a, b) => (a['name'] ?? '').toString().toLowerCase().compareTo((b['name'] ?? '').toString().toLowerCase()),
              (a, b) => 0, // Rede Social não ordenável
              (a, b) => (a['website_url'] ?? '').toString().toLowerCase().compareTo((b['website_url'] ?? '').toString().toLowerCase()),
              (a, b) {
                final dateA = a['updated_at'] != null ? DateTime.tryParse(a['updated_at']) : null;
                final dateB = b['updated_at'] != null ? DateTime.tryParse(b['updated_at']) : null;
                if (dateA == null && dateB == null) return 0;
                if (dateA == null) return 1;
                if (dateB == null) return -1;
                return dateA.compareTo(dateB);
              },
            ],
            cellBuilders: [
                (c) => Text(c['name'] ?? ''),
                (c) {
                  final socialIcons = <Widget>[];

                  if (c['instagram_login'] != null && c['instagram_login'].toString().isNotEmpty) {
                    socialIcons.add(
                      const Tooltip(
                        message: 'Instagram',
                        child: FaIcon(
                          FontAwesomeIcons.instagram,
                          size: 18,
                          color: Colors.white,
                        ),
                      ),
                    );
                  }

                  if (c['facebook_login'] != null && c['facebook_login'].toString().isNotEmpty) {
                    socialIcons.add(
                      const Tooltip(
                        message: 'Facebook',
                        child: FaIcon(
                          FontAwesomeIcons.facebook,
                          size: 18,
                          color: Colors.white,
                        ),
                      ),
                    );
                  }

                  if (c['linkedin_login'] != null && c['linkedin_login'].toString().isNotEmpty) {
                    socialIcons.add(
                      const Tooltip(
                        message: 'LinkedIn',
                        child: FaIcon(
                          FontAwesomeIcons.linkedin,
                          size: 18,
                          color: Colors.white,
                        ),
                      ),
                    );
                  }

                  if (c['tiktok_login'] != null && c['tiktok_login'].toString().isNotEmpty) {
                    socialIcons.add(
                      const Tooltip(
                        message: 'TikTok',
                        child: FaIcon(
                          FontAwesomeIcons.tiktok,
                          size: 18,
                          color: Colors.white,
                        ),
                      ),
                    );
                  }

                  if (socialIcons.isEmpty) {
                    return const Text('-');
                  }

                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (int i = 0; i < socialIcons.length; i++) ...[
                        socialIcons[i],
                        if (i < socialIcons.length - 1) const SizedBox(width: 8),
                      ],
                    ],
                  );
                },
                (c) => Text(c['website_url'] ?? '-'),
                (c) {
                  final updatedAt = c['updated_at'];
                  final updatedByProfile = c['updated_by_profile'] as Map<String, dynamic>?;

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
            getId: (c) => c['id'] as String,
            onRowTap: (c) async {
                // Atualiza a aba atual com os detalhes da empresa
                final tabManager = TabManagerScope.maybeOf(context);
                if (tabManager != null) {
                  final companyId = c['id'].toString();
                  final companyName = c['name'] as String? ?? 'Empresa';
                  final tabId = 'company_$companyId';

                  // Atualiza a aba atual em vez de criar uma nova
                  final currentIndex = tabManager.currentIndex;
                  final updatedTab = TabItem(
                    id: tabId,
                    title: companyName,
                    icon: Icons.business,
                    page: CompanyDetailPage(companyId: companyId),
                    canClose: true,
                  );
                  tabManager.updateTab(currentIndex, updatedTab);
                } else {
                  // Fallback para navegação tradicional
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CompanyDetailPage(companyId: c['id']),
                    ),
                  );
                  _reloadCompanies();
                }
            },
            actions: [
                DataTableAction(
                  icon: Icons.edit,
                  label: 'Editar',
                  onPressed: (c) async {
                    final saved = await showDialog<bool>(
                      context: context,
                      builder: (context) => CompanyFormDialog(
                        clientId: widget.clientId,
                        initial: c,
                      ),
                    );
                    if (saved == true) {
                      _reloadCompanies();
                    }
                  },
                ),
                DataTableAction(
                  icon: Icons.content_copy,
                  label: 'Duplicar',
                  onPressed: (c) async {
                    try {
                      final formData = Map<String, dynamic>.from(c);
                      formData.remove('id');
                      formData.remove('created_at');
                      formData.remove('updated_at');
                      if (formData['name'] != null) {
                        formData['name'] = '${formData['name']} (Cópia)';
                      }

                      await Supabase.instance.client.from('companies').insert(formData);

                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Empresa duplicada com sucesso')),
                      );
                      _reloadCompanies();
                    } catch (e) {
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Erro ao duplicar: $e')),
                      );
                    }
                  },
                ),
                DataTableAction(
                  icon: Icons.delete,
                  label: 'Excluir',
                  onPressed: (c) async {
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (_) => ConfirmDialog(
                        title: 'Excluir Empresa',
                        message: 'Tem certeza que deseja excluir esta empresa?',
                        confirmText: 'Excluir',
                        isDestructive: true,
                      ),
                    );
                    if (ok == true) {
                      await Supabase.instance.client
                          .from('companies')
                          .delete()
                          .eq('id', c['id']);
                      if (mounted) _reloadCompanies();
                    }
                  },
                  showWhen: (c) => appState.isAdmin,
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFinancialTab() {
    return ClientFinancialSection(clientId: widget.clientId);
  }

  @override
  Widget build(BuildContext context) {
    final appState = AppStateScope.of(context);
    return Material(
      type: MaterialType.transparency,
      child: FutureBuilder<Map<String, dynamic>?>(
              future: _clientFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Erro ao carregar cliente'));
                }
                final client = snapshot.data;
                if (client == null) {
                  return const Center(child: Text('Cliente não encontrado'));
                }
                return Padding(
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
                                  // Se não há histórico, volta para a página de Clientes
                                  final currentTab = tabManager.currentTab;
                                  if (currentTab != null) {
                                    final clientsTab = TabItem(
                                      id: 'page_1', // ID da página de Clientes
                                      title: 'Clientes',
                                      icon: Icons.people,
                                      page: const ClientsPage(),
                                      canClose: true,
                                      selectedMenuIndex: 1, // Índice do menu de Clientes
                                    );
                                    tabManager.updateTab(tabManager.currentIndex, clientsTab, saveToHistory: false);
                                  }
                                }
                              } else {
                                // Fallback para navegação tradicional
                                Navigator.of(context).pop();
                              }
                            },
                          ),
                          Text('Cliente', style: Theme.of(context).textTheme.headlineSmall),
                          const Spacer(),
                          // Botão Editar
                          IconOnlyButton(
                            icon: Icons.edit,
                            tooltip: 'Editar',
                            onPressed: (appState.isAdmin || appState.isGestor) ? () async {
                              final saved = await showDialog<bool>(
                                context: context,
                                builder: (context) => ClientForm(initial: client),
                              );
                              if (saved == true) {
                                setState(() {
                                  _clientFuture = _loadClient();
                                });
                              }
                            } : null,
                          ),
                          // Botão Excluir
                          IconOnlyButton(
                            icon: Icons.delete,
                            tooltip: 'Excluir',
                            onPressed: appState.isAdmin ? () async {
                                final navigator = Navigator.of(context);
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (context) => ConfirmDialog(
                                    title: 'Confirmar Exclusão',
                                    message: 'Deseja realmente excluir o cliente "${client['name']}"?',
                                    confirmText: 'Excluir',
                                    isDestructive: true,
                                  ),
                                );
                                if (confirm == true && mounted) {
                                  await Supabase.instance.client
                                      .from('clients')
                                      .delete()
                                      .eq('id', widget.clientId);
                                  if (!mounted) return;
                                  navigator.pop();
                                }
                              } : null,
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              // Avatar
                              CircleAvatar(
                                radius: 24,
                                backgroundImage: client['avatar_url'] != null &&
                                                 (client['avatar_url'] as String).isNotEmpty
                                    ? NetworkImage(client['avatar_url'])
                                    : null,
                                child: client['avatar_url'] == null ||
                                       (client['avatar_url'] as String).isEmpty
                                    ? const Icon(Icons.person, size: 24)
                                    : null,
                              ),
                              const SizedBox(width: 16),
                              // Nome
                              Expanded(
                                child: _Info('Nome', client['name'] ?? ''),
                              ),
                              const SizedBox(width: 24),
                              // Categoria
                              Expanded(
                                child: _Info(
                                  'Categoria',
                                  client['client_categories']?['name'] ??
                                  client['category'] ??
                                  '-'
                                ),
                              ),
                              const SizedBox(width: 24),
                              // Email (clicável para copiar)
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Email', style: Theme.of(context).textTheme.labelMedium),
                                    const SizedBox(height: 4),
                                    InkWell(
                                      onTap: () => _copyEmail(client['email']),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.email, size: 16, color: Colors.white),
                                          const SizedBox(width: 8),
                                          Flexible(
                                            child: Text(
                                              client['email'] ?? '-',
                                              style: const TextStyle(
                                                color: Colors.white,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 24),
                              // Telefone (clicável para WhatsApp)
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Telefone', style: Theme.of(context).textTheme.labelMedium),
                                    const SizedBox(height: 4),
                                    InkWell(
                                      onTap: () => _openWhatsApp(client['phone']),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const _WhatsAppIcon(size: 16, color: Colors.white),
                                          const SizedBox(width: 8),
                                          Flexible(
                                            child: Text(
                                              client['phone'] ?? '-',
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
                                  ],
                                ),
                              ),
                              const SizedBox(width: 24),
                              // País
                              Expanded(
                                child: _Info('País', client['country'] ?? '-'),
                              ),
                              const SizedBox(width: 8),
                              // Estado
                              Expanded(
                                child: _Info('Estado', client['state'] ?? '-'),
                              ),
                              const SizedBox(width: 8),
                              // Cidade
                              Expanded(
                                child: _Info('Cidade', client['city'] ?? '-'),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Tabs usando componente genérico
                      Expanded(
                        child: GenericTabView(
                          tabs: const [
                            TabConfig(text: 'Empresas'),
                            TabConfig(text: 'Financeiro'),
                          ],
                          children: [
                            _buildCompaniesTab(appState),
                            _buildFinancialTab(),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
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
        Text(label, style: Theme.of(context).textTheme.labelMedium),
        const SizedBox(height: 4),
        Text(value, style: Theme.of(context).textTheme.titleSmall),
      ],
    );
  }
}

class _WhatsAppIcon extends StatelessWidget {
  final double size;
  final Color color;

  const _WhatsAppIcon({
    required this.size,
    required this.color,
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
