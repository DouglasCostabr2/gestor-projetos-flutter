import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../state/app_state_scope.dart';
import '../../state/app_state.dart';
import '../../navigation/tab_manager_scope.dart';
import '../../navigation/tab_item.dart';
import '../../../ui/organisms/tables/dynamic_paginated_table.dart';
import 'package:my_business/ui/molecules/user_avatar_name.dart';
import '../companies/company_detail_page.dart';
import '../companies/companies_page.dart';
import '../../../ui/organisms/tables/reusable_data_table.dart';
import '../../../ui/organisms/dialogs/standard_dialog.dart';
import 'package:my_business/ui/atoms/buttons/buttons.dart';
import 'package:my_business/ui/atoms/loaders/loaders.dart';
import 'package:my_business/ui/organisms/tables/table_search_filter_bar.dart';
import '../../../ui/organisms/tabs/tabs.dart';
import 'package:my_business/ui/organisms/cards/cards.dart';
import 'widgets/client_form.dart';
import 'widgets/client_financial_section.dart';
import 'widgets/client_info_card_items.dart';
import 'clients_page.dart';
import '../../../modules/companies/module.dart';
// import 'clients_page_backup.dart'; // Backup file not used



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
  bool _showMoreInfo = false; // Estado do botão "Mais Informações"

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
        .select('id, name, category, category_id, email, phone, country, state, city, avatar_url, notes, status, social_networks, client_categories:category_id(name)')
        .eq('id', widget.clientId)
        .maybeSingle();
    return res;
  }

  /// Constrói os cards de informações do cliente (similar ao design das outras páginas)
  Widget _buildClientInfoCards({
    required BuildContext context,
    required Map<String, dynamic> client,
  }) {
    // Card esquerdo: Nome, Categoria, Status, Telefone
    final leftCardItems = <InfoCardItem>[
      ClientInfoCardItems.buildClientNameItem(context, client),
      ClientInfoCardItems.buildCategoryItem(context, client),
      ClientInfoCardItems.buildStatusItem(client),
      ClientInfoCardItems.buildPhoneItem(context, client),
    ];

    // Card direito: Notas/Observações + Botão "Mais Informações"
    final rightCardItems = <InfoCardItem>[
      ClientInfoCardItems.buildNotesItem(context, client),
      ClientInfoCardItems.buildMoreInfoButton(
        onTap: () {
          setState(() {
            _showMoreInfo = !_showMoreInfo;
          });
        },
      ),
    ];

    return InfoCardsSection(
      leftCard: InfoCard(
        items: leftCardItems,
        minWidth: 120,
        minHeight: 104,
        totalItems: 4, // Forçar uso de Wrap (mesmo padrão das outras páginas)
        debugEmoji: '👤',
        debugDescription: 'Informações do Cliente',
      ),
      rightCard: InfoCard(
        items: rightCardItems,
        minWidth: 120,
        minHeight: 104,
        totalItems: 4, // Forçar uso de Wrap (mesmo padrão das outras páginas)
        debugEmoji: '📝',
        debugDescription: 'Notas e Mais Informações',
      ),
    );
  }

  /// Constrói a seção expansível com informações adicionais
  Widget _buildMoreInfoSection({
    required BuildContext context,
    required Map<String, dynamic> client,
  }) {
    final email = client['email'] as String?;
    final country = client['country'] as String?;
    final state = client['state'] as String?;
    final city = client['city'] as String?;
    final socialNetworks = client['social_networks'] as List<dynamic>?;

    // Filtrar redes sociais que têm valores
    final validNetworks = socialNetworks
        ?.where((network) {
          final name = network['name'] as String?;
          final url = network['url'] as String?;
          return name != null && name.isNotEmpty && url != null && url.isNotEmpty;
        })
        .toList() ?? [];

    return AnimatedSize(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      alignment: Alignment.topCenter,
      child: _showMoreInfo
          ? Container(
              width: double.infinity,
              margin: const EdgeInsets.only(top: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.1),
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Título da seção
                  Text(
                    'Informações Adicionais',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 16),

                  // Email
                  if (email != null && email.isNotEmpty) ...[
                    Text(
                      'Email',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: Colors.white70,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildEmailChip(context, email),
                    const SizedBox(height: 16),
                  ],

                  // Localização
                  if (country != null || state != null || city != null) ...[
                    Text(
                      'Localização',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: Colors.white70,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        if (country != null && country.isNotEmpty) ...[
                          _buildInfoChip(context, 'País', country),
                          const SizedBox(width: 8),
                        ],
                        if (state != null && state.isNotEmpty) ...[
                          _buildInfoChip(context, 'Estado', state),
                          const SizedBox(width: 8),
                        ],
                        if (city != null && city.isNotEmpty)
                          _buildInfoChip(context, 'Cidade', city),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Redes Sociais
                  if (validNetworks.isNotEmpty) ...[
                    Text(
                      'Redes Sociais',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: Colors.white70,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: validNetworks.map((network) {
                        final name = network['name'] as String;
                        final url = network['url'] as String;
                        return _buildSocialNetworkChip(context, name, url);
                      }).toList(),
                    ),
                  ],

                  // Mensagem se não houver informações
                  if ((email == null || email.isEmpty) &&
                      (country == null || country.isEmpty) &&
                      (state == null || state.isEmpty) &&
                      (city == null || city.isEmpty) &&
                      validNetworks.isEmpty)
                    Text(
                      'Nenhuma informação adicional disponível.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.white54,
                      ),
                    ),
                ],
              ),
            )
          : const SizedBox(
              width: double.infinity,
              height: 0,
            ),
    );
  }

  /// Constrói um chip de email clicável
  Widget _buildEmailChip(BuildContext context, String email) {
    return InkWell(
      onTap: () async {
        final messenger = ScaffoldMessenger.of(context);
        await Clipboard.setData(ClipboardData(text: email));
        if (!mounted) return;
        messenger.showSnackBar(
          SnackBar(
            content: Text('Email "$email" copiado para a área de transferência'),
            duration: const Duration(seconds: 2),
          ),
        );
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF2A2A2A),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.email_outlined,
              size: 14,
              color: Colors.white70,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                email,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.white70,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 6),
            const Icon(
              Icons.copy,
              size: 12,
              color: Colors.white54,
            ),
          ],
        ),
      ),
    );
  }

  /// Constrói um chip de informação
  Widget _buildInfoChip(BuildContext context, String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label: ',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.white54,
            ),
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  /// Constrói um chip de rede social
  Widget _buildSocialNetworkChip(BuildContext context, String name, String url) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _getSocialIcon(name),
            size: 14,
            color: Colors.white70,
          ),
          const SizedBox(width: 6),
          Text(
            name,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            '•',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.white54,
            ),
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              url,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.white70,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  /// Retorna o ícone apropriado para cada rede social
  IconData _getSocialIcon(String networkName) {
    final name = networkName.toLowerCase();
    if (name.contains('instagram')) return FontAwesomeIcons.instagram;
    if (name.contains('facebook')) return FontAwesomeIcons.facebook;
    if (name.contains('linkedin')) return FontAwesomeIcons.linkedin;
    if (name.contains('tiktok')) return FontAwesomeIcons.tiktok;
    if (name.contains('twitter') || name.contains('x')) return FontAwesomeIcons.twitter;
    if (name.contains('youtube')) return FontAwesomeIcons.youtube;
    if (name.contains('whatsapp')) return FontAwesomeIcons.whatsapp;
    return Icons.link;
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

                  // Tooltips desabilitados para evitar erro de múltiplos tickers
                  if (c['instagram_login'] != null && c['instagram_login'].toString().isNotEmpty) {
                    socialIcons.add(
                      const FaIcon(
                        FontAwesomeIcons.instagram,
                        size: 18,
                        color: Colors.white,
                      ),
                    );
                  }

                  if (c['facebook_login'] != null && c['facebook_login'].toString().isNotEmpty) {
                    socialIcons.add(
                      const FaIcon(
                        FontAwesomeIcons.facebook,
                        size: 18,
                        color: Colors.white,
                      ),
                    );
                  }

                  if (c['linkedin_login'] != null && c['linkedin_login'].toString().isNotEmpty) {
                    socialIcons.add(
                      const FaIcon(
                        FontAwesomeIcons.linkedin,
                        size: 18,
                        color: Colors.white,
                      ),
                    );
                  }

                  if (c['tiktok_login'] != null && c['tiktok_login'].toString().isNotEmpty) {
                    socialIcons.add(
                      const FaIcon(
                        FontAwesomeIcons.tiktok,
                        size: 18,
                        color: Colors.white,
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
                      // Usar o módulo de empresas para criar, passando apenas os campos necessários
                      // Nota: Não copiar campos dinâmicos como 'updated_by_profile' e 'task_people'
                      await companiesModule.createCompany(
                        clientId: widget.clientId,
                        name: '${c['name'] ?? ''} (Cópia)',
                        email: c['email'],
                        phone: c['phone'],
                        address: c['address'],
                        city: c['city'],
                        state: c['state'],
                        zipCode: c['zip_code'],
                        country: c['country'],
                        website: c['website'],
                        notes: c['notes'],
                        status: c['status'] ?? 'active',
                        taxId: c['tax_id'],
                        taxIdType: c['tax_id_type'],
                        legalName: c['legal_name'],
                        stateRegistration: c['state_registration'],
                        municipalRegistration: c['municipal_registration'],
                      );

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

  /// Constrói skeleton loading para a página de detalhes do cliente
  Widget _buildClientDetailSkeleton() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Título skeleton
          Row(
            children: [
              SkeletonLoader.circle(size: 48),
              const SizedBox(width: 16),
              SkeletonLoader.text(width: 200),
            ],
          ),
          const SizedBox(height: 24),

          // Card de informações skeleton
          InfoCardSkeleton(itemCount: 8, minHeight: 140),
          const SizedBox(height: 24),

          // Tabs skeleton
          Row(
            children: [
              SkeletonLoader.box(width: 120, height: 40, borderRadius: 8),
              const SizedBox(width: 8),
              SkeletonLoader.box(width: 120, height: 40, borderRadius: 8),
            ],
          ),
          const SizedBox(height: 24),

          // Conteúdo skeleton
          Expanded(
            child: SkeletonLoader.box(
              width: double.infinity,
              height: double.infinity,
              borderRadius: 12,
            ),
          ),
        ],
      ),
    );
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
                'Apenas Administradores, Gestores e Financeiros podem acessar os detalhes do cliente.',
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

    return Material(
      type: MaterialType.transparency,
      child: FutureBuilder<Map<String, dynamic>?>(
              future: _clientFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return _buildClientDetailSkeleton();
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
                      _buildClientInfoCards(
                        context: context,
                        client: client,
                      ),
                      _buildMoreInfoSection(
                        context: context,
                        client: client,
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
