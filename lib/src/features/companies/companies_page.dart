import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../app_shell.dart';
import '../../state/app_state_scope.dart';
import '../../navigation/user_role.dart';
import '../../../ui/organisms/navigation/side_menu.dart';
import 'company_detail_page.dart';
import '../../../ui/organisms/tables/dynamic_paginated_table.dart';
import '../../../ui/organisms/tables/reusable_data_table.dart';
import 'package:my_business/ui/molecules/user_avatar_name.dart';
import '../../../ui/organisms/dialogs/standard_dialog.dart';
import '../../../ui/organisms/tables/table_search_filter_bar.dart';
import '../../../modules/modules.dart';
import 'package:my_business/ui/atoms/buttons/buttons.dart';
import '../../../ui/molecules/table_cells/table_cells.dart';
import '../../../core/di/service_locator.dart';
import '../../navigation/interfaces/tab_manager_interface.dart';
import 'package:my_business/ui/molecules/inputs/mention_text_area.dart';
import 'package:my_business/services/mentions_service.dart';
import '../../utils/project_helpers.dart';
import 'package:my_business/ui/atoms/inputs/inputs.dart';
import 'widgets/company_fiscal_bank_widget.dart';

class CompaniesPage extends StatefulWidget {
  final String clientId;
  final String clientName;

  const CompaniesPage({
    super.key,
    required this.clientId,
    required this.clientName,
  });

  @override
  State<CompaniesPage> createState() => _CompaniesPageState();
}

class _CompaniesPageState extends State<CompaniesPage> {
  List<Map<String, dynamic>> _data = [];
  List<Map<String, dynamic>> _filteredData = [];
  bool _loading = true;
  final Set<String> _selected = <String>{};

  // Busca e filtros
  String _searchQuery = '';
  String _filterType = 'none'; // none, social_network
  String? _filterValue;

  // Ordenação
  int? _sortColumnIndex = 0;
  bool _sortAscending = true;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<List<Map<String, dynamic>>> _load() async {
    // Usando o módulo de empresas
    final res = await companiesModule.getCompanies(widget.clientId);

    // Buscar informações dos usuários que fizeram a última atualização
    final updatedByIds = res.map((c) => c['updated_by']).whereType<String>().toSet();
    Map<String, Map<String, dynamic>> usersMap = {};

    if (updatedByIds.isNotEmpty) {
      try {
        // Usando o módulo de usuários
        final allUsers = await usersModule.getAllProfiles();
        final users = allUsers.where((u) => updatedByIds.contains(u['id'])).toList();

        for (final user in users) {
          usersMap[user['id']] = user;
        }
      } catch (e) {
        // Ignorar erro (operação não crítica)
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

    // OTIMIZAÇÃO: Usar helper para enriquecer empresas com responsáveis
    // Isso substitui ~70 linhas de código duplicado!
    try {
      await ProjectAssigneesHelper.enrichCompaniesWithAssignees(result);
    } catch (e) {
      // Em caso de erro, adicionar valores padrão
      for (final company in result) {
        company['task_people'] = [];
      }
    }

    return result;
  }

  Future<void> _reload() async {
    setState(() => _loading = true);
    final res = await _load();
    if (!mounted) return;
    setState(() {
      _data = res;
      _loading = false;
    });
    _applyFilters();
  }

  void _applyFilters() {
    setState(() {
      var filtered = List<Map<String, dynamic>>.from(_data);

      // Aplicar busca
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        filtered = filtered.where((company) {
          final name = (company['name'] ?? '').toString().toLowerCase();
          final website = (company['website'] ?? '').toString().toLowerCase();
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

  // Função para exclusão em lote
  Future<void> _bulkDelete() async {
    if (_selected.isEmpty) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => ConfirmDialog(
        title: 'Confirmar Exclusão',
        message: 'Deseja realmente excluir ${_selected.length} empresa(s) selecionada(s)?',
        confirmText: 'Excluir',
        isDestructive: true,
      ),
    );

    if (confirm != true) return;

    try {
      for (final id in _selected) {
        await companiesModule.deleteCompany(id);
      }

      if (!mounted) return;
      setState(() {
        _data.removeWhere((e) => _selected.contains(e['id']));
        _filteredData.removeWhere((e) => _selected.contains(e['id']));
        _selected.clear();
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Empresas excluídas com sucesso')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao excluir: $e')),
        );
      }
    }
  }



  // Obter comparadores de ordenação
  List<int Function(Map<String, dynamic>, Map<String, dynamic>)> _getSortComparators() {
    return [
      (a, b) => (a['name'] ?? '').toString().toLowerCase().compareTo((b['name'] ?? '').toString().toLowerCase()),
      (a, b) => (a['website'] ?? '').toString().toLowerCase().compareTo((b['website'] ?? '').toString().toLowerCase()),
      (a, b) => (a['social_network'] ?? '').toString().toLowerCase().compareTo((b['social_network'] ?? '').toString().toLowerCase()),
      (a, b) {
        final dateA = a['updated_at'] != null ? DateTime.tryParse(a['updated_at']) : null;
        final dateB = b['updated_at'] != null ? DateTime.tryParse(b['updated_at']) : null;
        if (dateA == null && dateB == null) return 0;
        if (dateA == null) return 1;
        if (dateB == null) return -1;
        return dateA.compareTo(dateB);
      },
      (a, b) => 0, // Atualizado por não ordenável
      (a, b) => 0, // Pessoas não ordenável
      (a, b) => ((a['projects_count'] as int?) ?? 0).compareTo((b['projects_count'] as int?) ?? 0), // Projetos ordenável
      (a, b) {
        final dateA = a['created_at'] != null ? DateTime.tryParse(a['created_at']) : null;
        final dateB = b['created_at'] != null ? DateTime.tryParse(b['created_at']) : null;
        if (dateA == null && dateB == null) return 0;
        if (dateA == null) return 1;
        if (dateB == null) return -1;
        return dateA.compareTo(dateB);
      }, // Criado ordenável
    ];
  }



  List<String> _getUniqueSocialNetworks() {
    final networks = _data
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

  Future<void> _openForm({Map<String, dynamic>? initial}) async {
    Map<String, dynamic>? freshData = initial;

    // Se estamos editando, recarregar dados frescos do banco
    if (initial != null && initial['id'] != null) {
      try {
        final companies = await companiesModule.getCompanies(widget.clientId);
        freshData = companies.firstWhere(
          (c) => c['id'] == initial['id'],
          orElse: () => initial,
        );
      } catch (e) {
        freshData = initial;
      }
    }

    if (!mounted) return;

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => CompanyFormDialog(
        key: ValueKey(freshData?['id'] ?? 'new'),
        clientId: widget.clientId,
        initial: freshData,
      ),
    );
    if (saved == true) {
      await _reload();
    }
  }

  Future<void> _duplicate(Map<String, dynamic> company) async {
    try {
      final formData = Map<String, dynamic>.from(company);
      formData.remove('id');
      formData.remove('created_at');
      formData.remove('updated_at');

      if (formData['name'] != null) {
        formData['name'] = '${formData['name']} (Cópia)';
      }

      // Usando o módulo de empresas
      await companiesModule.createCompany(
        clientId: widget.clientId,
        name: formData['name'] ?? '',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Empresa duplicada com sucesso')),
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

  Future<void> _delete(String id) async {
    // Usando o módulo de empresas
    await companiesModule.deleteCompany(id);
    if (!mounted) return;
    setState(() {
      _data.removeWhere((e) => e['id'] == id);
    });
  }

  @override
  Widget build(BuildContext context) {
    final appState = AppStateScope.of(context);
    // Usar novo sistema de permissões baseado em organização
    final permissions = appState.permissions;
    final canEdit = permissions.canEditCompanies;
    final canDelete = permissions.canDeleteCompanies;
    final canCreate = permissions.canCreateCompanies;
    final canDuplicate = permissions.canEditCompanies;

    return Scaffold(
      body: Row(
        children: [
          SideMenu(
            collapsed: appState.sideMenuCollapsed,
            selectedIndex: 0,
            onSelect: (i) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => AppShell(appState: appState, initialIndex: i)),
              );
            },
            onToggle: () => appState.toggleSideMenu(),
            onLogout: () async {
              final navigator = Navigator.of(context);
              // Limpar todas as abas antes do logout
              final tabManager = serviceLocator.get<ITabManager>();
              tabManager.clearAllTabs();
              // Usando o módulo de autenticação
              await authModule.signOut();
              if (!navigator.mounted) return;
              navigator.pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => AppShell(appState: appState)),
                (route) => false,
              );
            },
            userRole: UserRoleExtension.fromString(appState.role),
            profile: appState.profile,
            appState: appState,
          ),
          Expanded(
            child: SingleChildScrollView(
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
                          onPressed: () => Navigator.pop(context),
                        ),
                        Text('Empresas de ${widget.clientName}', style: Theme.of(context).textTheme.headlineSmall),
                      ],
                    ),
                    const SizedBox(height: 16),

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
                      selectedCount: _selected.length,
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
                        label: const Text('Nova Empresa'),
                      ) : null,
                    ),

                    const SizedBox(height: 16),

                    // Tabela com paginação dinâmica
                    Expanded(
                      child: DynamicPaginatedTable<Map<String, dynamic>>(
                        items: _filteredData,
                        itemLabel: 'empresa(s)',
                        selectedIds: _selected,
                        onSelectionChanged: (ids) => setState(() => _selected
                          ..clear()
                          ..addAll(ids)),
                        columns: const [
                          DataTableColumn(label: 'Nome', sortable: true),
                          DataTableColumn(label: 'Site', sortable: true),
                          DataTableColumn(label: 'Rede Social', sortable: true),
                          DataTableColumn(label: 'Atualizado', sortable: true),
                          DataTableColumn(label: 'Atualizado por'),
                          DataTableColumn(label: 'Pessoas'),
                          DataTableColumn(label: 'Projetos', sortable: true, fixedWidth: 120),
                          DataTableColumn(label: 'Criado', sortable: true),
                        ],
                        sortComparators: _getSortComparators(),
                        onSort: (columnIndex, ascending) {
                          setState(() {
                            _sortColumnIndex = columnIndex;
                            _sortAscending = ascending;
                            _applySorting();
                          });
                        },
                        externalSortColumnIndex: _sortColumnIndex,
                        externalSortAscending: _sortAscending,
                        isLoading: _loading,
                        loadingWidget: const Center(child: CircularProgressIndicator()),
                        emptyWidget: const Center(child: Text('Nenhuma empresa encontrada')),
                        cellBuilders: [
                          (c) => Text(c['name'] ?? 'Sem nome'),
                          (c) => Text(c['website_url'] ?? '-'),
                          (c) {
                            final socials = <String>[];
                            if (c['instagram_login'] != null && c['instagram_login'].toString().isNotEmpty) socials.add('IG');
                            if (c['facebook_login'] != null && c['facebook_login'].toString().isNotEmpty) socials.add('FB');
                            if (c['linkedin_login'] != null && c['linkedin_login'].toString().isNotEmpty) socials.add('LI');
                            if (c['tiktok_login'] != null && c['tiktok_login'].toString().isNotEmpty) socials.add('TT');
                            return Text(socials.isEmpty ? '-' : socials.join(', '));
                          },
                          (c) => TableCellDate(date: c['updated_at']),
                          (c) {
                            final updatedByProfile = c['updated_by_profile'] as Map<String, dynamic>?;
                            if (updatedByProfile == null) return const Text('-');
                            final userName = updatedByProfile['full_name'] as String? ?? updatedByProfile['email'] as String? ?? 'Usuário';
                            final avatarUrl = updatedByProfile['avatar_url'] as String?;
                            return UserAvatarName(
                              avatarUrl: avatarUrl,
                              name: userName,
                              size: 16,
                            );
                          },
                          (c) => TableCellAvatarList(
                            people: c['task_people'] ?? [],
                            maxVisible: 3,
                            avatarSize: 10, // Consistente com outras tabelas
                          ),
                          (c) => TableCellCounter(
                            count: c['projects_count'] as int?,
                            icon: Icons.folder,
                            hideZero: false,
                          ),
                          (c) => TableCellDate(date: c['created_at']),
                        ],
                        getId: (c) => c['id'] as String,
                        onRowTap: (c) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => CompanyDetailPage(companyId: c['id']),
                            ),
                          );
                        },
                        actions: [
                          if (canEdit)
                            DataTableAction<Map<String, dynamic>>(
                              icon: Icons.edit,
                              label: 'Editar',
                              onPressed: (c) => _openForm(initial: c),
                            ),
                          if (canDuplicate)
                            DataTableAction<Map<String, dynamic>>(
                              icon: Icons.content_copy,
                              label: 'Duplicar',
                              onPressed: (c) => _duplicate(c),
                            ),
                          if (canDelete)
                            DataTableAction<Map<String, dynamic>>(
                              icon: Icons.delete,
                              label: 'Excluir',
                              onPressed: (c) async {
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: const Text('Confirmar exclusão'),
                                    content: const Text('Deseja realmente excluir esta empresa?'),
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
                                  await _delete(c['id']);
                                }
                              },
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Formulário de Empresa
class CompanyFormDialog extends StatefulWidget {
  final String clientId;
  final Map<String, dynamic>? initial;

  const CompanyFormDialog({
    super.key,
    required this.clientId,
    this.initial,
  });

  @override
  State<CompanyFormDialog> createState() => _CompanyFormDialogState();
}

class _CompanyFormDialogState extends State<CompanyFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _notes = TextEditingController();

  // Instagram
  final _instagramLogin = TextEditingController();
  final _instagramPassword = TextEditingController();
  bool _showInstagramPassword = false;

  // Facebook
  final _facebookLogin = TextEditingController();
  final _facebookPassword = TextEditingController();
  bool _showFacebookPassword = false;

  // LinkedIn
  final _linkedinLogin = TextEditingController();
  final _linkedinPassword = TextEditingController();
  bool _showLinkedinPassword = false;

  // TikTok
  final _tiktokLogin = TextEditingController();
  final _tiktokPassword = TextEditingController();
  bool _showTiktokPassword = false;

  // Site
  final _websiteUrl = TextEditingController();
  final _websiteLogin = TextEditingController();
  final _websitePassword = TextEditingController();
  bool _showWebsitePassword = false;

  // Plataformas Personalizadas
  List<_CustomPlatform> _customPlatforms = [];

  // Address fields
  final _address = TextEditingController();
  final _city = TextEditingController();
  final _state = TextEditingController();
  final _zipCode = TextEditingController();
  final _country = TextEditingController();

  // Contact fields
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _website = TextEditingController();

  bool _saving = false;

  // Chave global para acessar o widget de dados fiscais/bancários
  final GlobalKey<CompanyFiscalBankWidgetState> _fiscalBankKey = GlobalKey<CompanyFiscalBankWidgetState>();

  @override
  void initState() {
    super.initState();
    final i = widget.initial;
    if (i != null) {
      _name.text = i['name'] ?? '';
      _notes.text = i['notes'] ?? '';

      // Address fields
      _address.text = i['address'] ?? '';
      _city.text = i['city'] ?? '';
      _state.text = i['state'] ?? '';
      _zipCode.text = i['zip_code'] ?? '';
      _country.text = i['country'] ?? '';

      // Contact fields
      _email.text = i['email'] ?? '';
      _phone.text = i['phone'] ?? '';
      _website.text = i['website'] ?? '';

      // Instagram
      if (i['instagram_login'] != null) _instagramLogin.text = i['instagram_login'];
      if (i['instagram_password'] != null) _instagramPassword.text = i['instagram_password'];

      // Facebook
      if (i['facebook_login'] != null) _facebookLogin.text = i['facebook_login'];
      if (i['facebook_password'] != null) _facebookPassword.text = i['facebook_password'];

      // LinkedIn
      if (i['linkedin_login'] != null) _linkedinLogin.text = i['linkedin_login'];
      if (i['linkedin_password'] != null) _linkedinPassword.text = i['linkedin_password'];

      // TikTok
      if (i['tiktok_login'] != null) _tiktokLogin.text = i['tiktok_login'];
      if (i['tiktok_password'] != null) _tiktokPassword.text = i['tiktok_password'];

      // Site
      if (i['website_url'] != null) _websiteUrl.text = i['website_url'];
      if (i['website_login'] != null) _websiteLogin.text = i['website_login'];
      if (i['website_password'] != null) _websitePassword.text = i['website_password'];

      // Plataformas Personalizadas
      if (i['custom_platforms'] != null) {
        final platforms = i['custom_platforms'] as List?;
        if (platforms != null) {
          _customPlatforms = platforms.map((p) => _CustomPlatform(
            platformName: p['platform_name'] ?? '',
            login: p['login'] ?? '',
            password: p['password'] ?? '',
          )).toList();
        }
      }
    }
  }



  @override
  void dispose() {
    _name.dispose();
    _notes.dispose();
    _address.dispose();
    _city.dispose();
    _state.dispose();
    _zipCode.dispose();
    _country.dispose();
    _email.dispose();
    _phone.dispose();
    _website.dispose();
    _instagramLogin.dispose();
    _instagramPassword.dispose();
    _facebookLogin.dispose();
    _facebookPassword.dispose();
    _linkedinLogin.dispose();
    _linkedinPassword.dispose();
    _tiktokLogin.dispose();
    _tiktokPassword.dispose();
    _websiteUrl.dispose();
    _websiteLogin.dispose();
    _websitePassword.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    try {
      if (widget.initial == null) {
        // Criar nova empresa usando o módulo
        final newCompany = await companiesModule.createCompany(
          clientId: widget.clientId,
          name: _name.text.trim(),
          address: _address.text.trim().isEmpty ? null : _address.text.trim(),
          city: _city.text.trim().isEmpty ? null : _city.text.trim(),
          state: _state.text.trim().isEmpty ? null : _state.text.trim(),
          zipCode: _zipCode.text.trim().isEmpty ? null : _zipCode.text.trim(),
          country: _country.text.trim().isEmpty ? null : _country.text.trim(),
          email: _email.text.trim().isEmpty ? null : _email.text.trim(),
          phone: _phone.text.trim().isEmpty ? null : _phone.text.trim(),
          website: _website.text.trim().isEmpty ? null : _website.text.trim(),
        );

        // Atualizar campos de redes sociais separadamente
        await _updateSocialMediaFields(newCompany['id']);
      } else {
        // Atualizar empresa existente usando o módulo
        await companiesModule.updateCompany(
          companyId: widget.initial!['id'],
          name: _name.text.trim(),
          address: _address.text.trim().isEmpty ? null : _address.text.trim(),
          city: _city.text.trim().isEmpty ? null : _city.text.trim(),
          state: _state.text.trim().isEmpty ? null : _state.text.trim(),
          zipCode: _zipCode.text.trim().isEmpty ? null : _zipCode.text.trim(),
          country: _country.text.trim().isEmpty ? null : _country.text.trim(),
          email: _email.text.trim().isEmpty ? null : _email.text.trim(),
          phone: _phone.text.trim().isEmpty ? null : _phone.text.trim(),
          website: _website.text.trim().isEmpty ? null : _website.text.trim(),
        );

        // Atualizar campos de redes sociais separadamente
        await _updateSocialMediaFields(widget.initial!['id']);

        // Salvar dados fiscais e bancários se o widget existir
        if (_fiscalBankKey.currentState != null) {
          await _fiscalBankKey.currentState!.saveFiscalBankData();
        }
      }
      if (mounted) navigator.pop(true);
    } catch (e) {
      messenger.showSnackBar(const SnackBar(content: Text('Erro ao salvar')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _updateSocialMediaFields(String companyId) async {
    final updateData = <String, dynamic>{};

    // Notas
    if (_notes.text.trim().isNotEmpty) {
      updateData['notes'] = _notes.text.trim();
    }

    // Instagram
    if (_instagramLogin.text.trim().isNotEmpty) {
      updateData['instagram_login'] = _instagramLogin.text.trim();
    }
    if (_instagramPassword.text.trim().isNotEmpty) {
      updateData['instagram_password'] = _instagramPassword.text.trim();
    }

    // Facebook
    if (_facebookLogin.text.trim().isNotEmpty) {
      updateData['facebook_login'] = _facebookLogin.text.trim();
    }
    if (_facebookPassword.text.trim().isNotEmpty) {
      updateData['facebook_password'] = _facebookPassword.text.trim();
    }

    // LinkedIn
    if (_linkedinLogin.text.trim().isNotEmpty) {
      updateData['linkedin_login'] = _linkedinLogin.text.trim();
    }
    if (_linkedinPassword.text.trim().isNotEmpty) {
      updateData['linkedin_password'] = _linkedinPassword.text.trim();
    }

    // TikTok
    if (_tiktokLogin.text.trim().isNotEmpty) {
      updateData['tiktok_login'] = _tiktokLogin.text.trim();
    }
    if (_tiktokPassword.text.trim().isNotEmpty) {
      updateData['tiktok_password'] = _tiktokPassword.text.trim();
    }

    // Site
    if (_websiteUrl.text.trim().isNotEmpty) {
      updateData['website_url'] = _websiteUrl.text.trim();
    }
    if (_websiteLogin.text.trim().isNotEmpty) {
      updateData['website_login'] = _websiteLogin.text.trim();
    }
    if (_websitePassword.text.trim().isNotEmpty) {
      updateData['website_password'] = _websitePassword.text.trim();
    }

    // Plataformas personalizadas
    if (_customPlatforms.isNotEmpty) {
      final platformsJson = _customPlatforms
          .where((p) => p.platformName.trim().isNotEmpty)
          .map((p) => {
                'platform_name': p.platformName.trim(),
                'login': p.login.trim(),
                'password': p.password.trim(),
              })
          .toList();
      updateData['custom_platforms'] = platformsJson;
    }

    // Atualizar no banco se houver dados
    if (updateData.isNotEmpty) {
      await Supabase.instance.client
          .from('companies')
          .update(updateData)
          .eq('id', companyId);
    }

    // Salvar menções das notas
    if (_notes.text.trim().isNotEmpty) {
      final mentionsService = MentionsService();
      try {
        await mentionsService.saveCompanyMentions(
          companyId: companyId,
          fieldName: 'notes',
          content: _notes.text,
        );
      } catch (e) {
        // Ignorar erro (operação não crítica)
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return StandardDialog(
      title: widget.initial == null ? 'Nova Empresa' : 'Editar Empresa',
      width: StandardDialog.widthLarge,
      height: StandardDialog.heightLarge,
      showCloseButton: false,
      isLoading: _saving,
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: const Text('Salvar'),
        ),
      ],
      child: Form(
        key: _formKey,
        child: DefaultTabController(
          length: 3,
          child: Column(
            children: [
              // Tab Bar
              TabBar(
                tabs: const [
                  Tab(icon: Icon(Icons.info_outline), text: 'Informações Gerais'),
                  Tab(icon: Icon(Icons.share), text: 'Redes Sociais'),
                  Tab(icon: Icon(Icons.account_balance), text: 'Dados Fiscais e Bancários'),
                ],
                labelColor: Theme.of(context).colorScheme.primary,
                unselectedLabelColor: Theme.of(context).colorScheme.onSurfaceVariant,
                indicatorColor: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 16),
              // Tab Views
              SizedBox(
                height: 500, // Altura fixa para evitar conflito com SingleChildScrollView
                child: TabBarView(
                  children: [
                    _buildGeneralInfoTab(),
                    _buildSocialMediaTab(),
                    _buildFiscalBankTab(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Aba 1: Informações Gerais
  Widget _buildGeneralInfoTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextFormField(
            controller: _name,
            decoration: const InputDecoration(labelText: 'Nome *'),
            validator: (v) => v == null || v.trim().isEmpty ? 'Informe o nome' : null,
          ),
          const SizedBox(height: 16),

          // Notas/Observações
          MentionTextArea(
            controller: _notes,
            labelText: 'Notas/Observações',
            hintText: 'Adicione notas sobre a empresa... (digite @ para mencionar)',
            minLines: 3,
            maxLines: 6,
            enabled: !_saving,
            onMentionsChanged: (userIds) {
              // Menções serão salvas ao salvar a empresa
            },
          ),
          const SizedBox(height: 24),

          // Seção de Endereço
          Text(
            '📍 Endereço da Empresa',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),

          // Address
          GenericTextField(
            controller: _address,
            labelText: 'Endereço Completo',
            hintText: 'Rua, número, complemento',
            enabled: !_saving,
          ),
          const SizedBox(height: 16),

          // City
          GenericTextField(
            controller: _city,
            labelText: 'Cidade',
            hintText: 'Nome da cidade',
            enabled: !_saving,
          ),
          const SizedBox(height: 16),

          // State
          GenericTextField(
            controller: _state,
            labelText: 'Estado/Província',
            hintText: 'Ex: SP, California, etc.',
            enabled: !_saving,
          ),
          const SizedBox(height: 16),

          // Zip Code
          GenericTextField(
            controller: _zipCode,
            labelText: 'CEP/Código Postal',
            hintText: 'Ex: 01234-567, 90210, etc.',
            enabled: !_saving,
          ),
          const SizedBox(height: 16),

          // Country
          GenericTextField(
            controller: _country,
            labelText: 'País',
            hintText: 'Ex: Brasil, United States, etc.',
            enabled: !_saving,
          ),
          const SizedBox(height: 24),

          // Seção de Contato
          Text(
            '📞 Contato da Empresa',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),

          // Email
          GenericEmailField(
            controller: _email,
            labelText: 'Email Corporativo',
            hintText: 'contato@empresa.com',
          ),
          const SizedBox(height: 16),

          // Phone
          GenericPhoneField(
            controller: _phone,
            labelText: 'Telefone',
            hintText: '+55 (11) 1234-5678',
          ),
          const SizedBox(height: 16),

          // Website
          GenericTextField(
            controller: _website,
            labelText: 'Website',
            hintText: 'https://www.empresa.com',
            enabled: !_saving,
          ),
        ],
      ),
    );
  }

  // Aba 2: Redes Sociais
  Widget _buildSocialMediaTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Seção de Redes Sociais
          Text(
            '🔐 Credenciais de Redes Sociais',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),

          // Instagram
                      ExpansionTile(
                        leading: const FaIcon(FontAwesomeIcons.instagram, size: 20),
                        title: const Text('Instagram'),
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            child: Column(
                              children: [
                                TextFormField(
                                  controller: _instagramLogin,
                                  decoration: const InputDecoration(labelText: 'Login'),
                                ),
                                const SizedBox(height: 12),
                                TextFormField(
                                  controller: _instagramPassword,
                                  decoration: InputDecoration(
                                    labelText: 'Senha',
                                    suffixIcon: IconOnlyButton(
                                      icon: _showInstagramPassword ? Icons.visibility_off : Icons.visibility,
                                      tooltip: _showInstagramPassword ? 'Ocultar senha' : 'Mostrar senha',
                                      onPressed: () => setState(() => _showInstagramPassword = !_showInstagramPassword),
                                    ),
                                  ),
                                  obscureText: !_showInstagramPassword,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // Facebook
                      ExpansionTile(
                        leading: const FaIcon(FontAwesomeIcons.facebook, size: 20),
                        title: const Text('Facebook'),
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            child: Column(
                              children: [
                                TextFormField(
                                  controller: _facebookLogin,
                                  decoration: const InputDecoration(labelText: 'Login'),
                                ),
                                const SizedBox(height: 12),
                                TextFormField(
                                  controller: _facebookPassword,
                                  decoration: InputDecoration(
                                    labelText: 'Senha',
                                    suffixIcon: IconOnlyButton(
                                      icon: _showFacebookPassword ? Icons.visibility_off : Icons.visibility,
                                      tooltip: _showFacebookPassword ? 'Ocultar senha' : 'Mostrar senha',
                                      onPressed: () => setState(() => _showFacebookPassword = !_showFacebookPassword),
                                    ),
                                  ),
                                  obscureText: !_showFacebookPassword,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // LinkedIn
                      ExpansionTile(
                        leading: const FaIcon(FontAwesomeIcons.linkedin, size: 20),
                        title: const Text('LinkedIn'),
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            child: Column(
                              children: [
                                TextFormField(
                                  controller: _linkedinLogin,
                                  decoration: const InputDecoration(labelText: 'Login'),
                                ),
                                const SizedBox(height: 12),
                                TextFormField(
                                  controller: _linkedinPassword,
                                  decoration: InputDecoration(
                                    labelText: 'Senha',
                                    suffixIcon: IconOnlyButton(
                                      icon: _showLinkedinPassword ? Icons.visibility_off : Icons.visibility,
                                      tooltip: _showLinkedinPassword ? 'Ocultar senha' : 'Mostrar senha',
                                      onPressed: () => setState(() => _showLinkedinPassword = !_showLinkedinPassword),
                                    ),
                                  ),
                                  obscureText: !_showLinkedinPassword,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // TikTok
                      ExpansionTile(
                        leading: const FaIcon(FontAwesomeIcons.tiktok, size: 20),
                        title: const Text('TikTok'),
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            child: Column(
                              children: [
                                TextFormField(
                                  controller: _tiktokLogin,
                                  decoration: const InputDecoration(labelText: 'Login'),
                                ),
                                const SizedBox(height: 12),
                                TextFormField(
                                  controller: _tiktokPassword,
                                  decoration: InputDecoration(
                                    labelText: 'Senha',
                                    suffixIcon: IconOnlyButton(
                                      icon: _showTiktokPassword ? Icons.visibility_off : Icons.visibility,
                                      tooltip: _showTiktokPassword ? 'Ocultar senha' : 'Mostrar senha',
                                      onPressed: () => setState(() => _showTiktokPassword = !_showTiktokPassword),
                                    ),
                                  ),
                                  obscureText: !_showTiktokPassword,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // Site
                      ExpansionTile(
                        leading: const Icon(Icons.language, size: 20),
                        title: const Text('Site'),
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            child: Column(
                              children: [
                                TextFormField(
                                  controller: _websiteUrl,
                                  decoration: const InputDecoration(labelText: 'URL'),
                                ),
                                const SizedBox(height: 12),
                                TextFormField(
                                  controller: _websiteLogin,
                                  decoration: const InputDecoration(labelText: 'Login'),
                                ),
                                const SizedBox(height: 12),
                                TextFormField(
                                  controller: _websitePassword,
                                  decoration: InputDecoration(
                                    labelText: 'Senha',
                                    suffixIcon: IconOnlyButton(
                                      icon: _showWebsitePassword ? Icons.visibility_off : Icons.visibility,
                                      tooltip: _showWebsitePassword ? 'Ocultar senha' : 'Mostrar senha',
                                      onPressed: () => setState(() => _showWebsitePassword = !_showWebsitePassword),
                                    ),
                                  ),
                                  obscureText: !_showWebsitePassword,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      // Plataformas Personalizadas
                      const SizedBox(height: 16),
                      ExpansionTile(
                        leading: const Icon(Icons.add_circle_outline, size: 20),
                        title: const Text('Plataformas Personalizadas'),
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Lista de plataformas personalizadas
                                ..._customPlatforms.asMap().entries.map((entry) {
                                  final index = entry.key;
                                  final platform = entry.value;
                                  return Card(
                                    margin: const EdgeInsets.only(bottom: 12),
                                    child: Padding(
                                      padding: const EdgeInsets.all(12),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  platform.platformName.isEmpty ? 'Nova Plataforma' : platform.platformName,
                                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                                ),
                                              ),
                                              IconOnlyButton(
                                                icon: Icons.delete,
                                                iconSize: 20,
                                                tooltip: 'Remover',
                                                onPressed: () {
                                                  setState(() {
                                                    _customPlatforms.removeAt(index);
                                                  });
                                                },
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 8),
                                          TextFormField(
                                            initialValue: platform.platformName,
                                            decoration: const InputDecoration(
                                              labelText: 'Nome da Plataforma *',
                                              hintText: 'Ex: Google Ads, Mailchimp, etc.',
                                            ),
                                            validator: (v) => v == null || v.trim().isEmpty ? 'Informe o nome' : null,
                                            onChanged: (value) {
                                              setState(() {
                                                platform.platformName = value;
                                              });
                                            },
                                          ),
                                          const SizedBox(height: 12),
                                          TextFormField(
                                            initialValue: platform.login,
                                            decoration: const InputDecoration(labelText: 'Login'),
                                            onChanged: (value) {
                                              setState(() {
                                                platform.login = value;
                                              });
                                            },
                                          ),
                                          const SizedBox(height: 12),
                                          TextFormField(
                                            initialValue: platform.password,
                                            decoration: const InputDecoration(labelText: 'Senha'),
                                            obscureText: true,
                                            onChanged: (value) {
                                              setState(() {
                                                platform.password = value;
                                              });
                                            },
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                }),

                                // Botão para adicionar nova plataforma
                                const SizedBox(height: 8),
                                OutlinedButton.icon(
                                  onPressed: () {
                                    setState(() {
                                      _customPlatforms.add(_CustomPlatform(
                                        platformName: '',
                                        login: '',
                                        password: '',
                                      ));
                                    });
                                  },
                                  icon: const Icon(Icons.add),
                                  label: const Text('Adicionar Plataforma'),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
        ],
      ),
    );
  }

  // Aba 3: Dados Fiscais e Bancários (JSONB Multi-país)
  Widget _buildFiscalBankTab() {
    // Mensagem para criar a empresa primeiro
    if (widget.initial == null) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Informação sobre a nova funcionalidade
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '🌍 Dados Fiscais e Bancários Multi-país',
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Esta funcionalidade avançada permite gerenciar dados fiscais e bancários para múltiplos países. '
                          'Salve a empresa primeiro e depois edite para configurar esses dados.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Center(
              child: Column(
                children: [
                  Icon(
                    Icons.account_balance,
                    size: 64,
                    color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Salve a empresa primeiro',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Os dados fiscais e bancários avançados podem ser\nconfigurados após criar a empresa.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // Interface completa de dados fiscais e bancários para empresas existentes
    return CompanyFiscalBankWidget(
      key: _fiscalBankKey,
      companyId: widget.initial!['id'] as String,
      initialFiscalData: widget.initial!['fiscal_data'] as Map<String, dynamic>?,
      initialBankData: widget.initial!['bank_data'] as Map<String, dynamic>?,
      initialFiscalCountry: widget.initial!['fiscal_country'] as String?,
      showSaveButton: false, // Não mostrar botão de salvar na aba
    );
  }
}

// Widget de diálogo com busca para seleção de itens
class _SearchablePickerDialog<T> extends StatefulWidget {
  final String title;
  final List<T> items;
  final T? selectedItem;
  final String Function(T) itemLabel;
  final String searchHint;

  const _SearchablePickerDialog({
    required this.title,
    required this.items,
    required this.selectedItem,
    required this.itemLabel,
    required this.searchHint,
  });

  @override
  State<_SearchablePickerDialog<T>> createState() => _SearchablePickerDialogState<T>();
}

class _SearchablePickerDialogState<T> extends State<_SearchablePickerDialog<T>> {
  final _searchController = TextEditingController();
  List<T> _filteredItems = [];

  @override
  void initState() {
    super.initState();
    _filteredItems = widget.items;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterItems(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredItems = widget.items;
      } else {
        _filteredItems = widget.items.where((item) {
          final label = widget.itemLabel(item).toLowerCase();
          return label.contains(query.toLowerCase());
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return StandardDialog(
      title: widget.title,
      width: StandardDialog.widthMedium,
      height: StandardDialog.heightMedium,
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _searchController,
            autofocus: true,
            decoration: InputDecoration(
              hintText: widget.searchHint,
              prefixIcon: const Icon(Icons.search),
              border: const OutlineInputBorder(),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconOnlyButton(
                      icon: Icons.clear,
                      tooltip: 'Limpar busca',
                      onPressed: () {
                        _searchController.clear();
                        _filterItems('');
                      },
                    )
                  : null,
            ),
            onChanged: _filterItems,
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _filteredItems.isEmpty
                ? const Center(
                    child: Text('Nenhum resultado encontrado'),
                  )
                : ListView.builder(
                    itemCount: _filteredItems.length,
                    itemBuilder: (context, index) {
                      final item = _filteredItems[index];
                      final isSelected = item == widget.selectedItem;
                      return ListTile(
                        title: Text(widget.itemLabel(item)),
                        selected: isSelected,
                        selectedTileColor: Colors.blue.withValues(alpha: 0.1),
                        trailing: isSelected ? const Icon(Icons.check, color: Colors.blue) : null,
                        onTap: () => Navigator.of(context).pop(item),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

// Classe para representar uma plataforma personalizada
class _CustomPlatform {
  String platformName;
  String login;
  String password;

  _CustomPlatform({
    required this.platformName,
    required this.login,
    required this.password,
  });
}
