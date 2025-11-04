import 'package:flutter/material.dart';
import '../../../modules/modules.dart';
import '../../state/app_state_scope.dart';
import 'dialogs/add_member_dialog.dart';
import '../../../ui/organisms/tables/dynamic_paginated_table.dart';
import '../../../ui/organisms/tables/reusable_data_table.dart';
import '../../../ui/organisms/tables/table_search_filter_bar.dart';
import '../../../ui/atoms/badges/role_badge.dart';
import '../../../ui/atoms/badges/member_status_badge.dart';

/// Página de gerenciamento de membros da organização
class OrganizationMembersPage extends StatefulWidget {
  const OrganizationMembersPage({super.key});

  @override
  State<OrganizationMembersPage> createState() => _OrganizationMembersPageState();
}

class _OrganizationMembersPageState extends State<OrganizationMembersPage> {
  bool _loading = true;
  List<Map<String, dynamic>> _members = [];
  List<Map<String, dynamic>> _invites = [];
  String _searchQuery = '';
  String _filterType = 'none';
  String? _filterValue;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadMembers();
    });
  }

  /// Carrega membros ativos e convites pendentes da organização
  Future<void> _loadMembers() async {
    if (!mounted) return;

    setState(() => _loading = true);

    try {
      final appState = AppStateScope.of(context);
      final orgId = appState.currentOrganizationId;

      if (orgId != null) {
        // Carregar membros ativos
        final members = await organizationsModule.getOrganizationMembers(orgId);

        // Carregar convites pendentes
        final invites = await organizationsModule.getOrganizationInvites(orgId);
        final pendingInvites = invites.where((inv) => inv['status'] == 'pending').toList();

        // Enriquecer convites com dados do perfil do usuário (se existir)
        await _enrichInvitesWithProfiles(pendingInvites);

        if (mounted) {
          setState(() {
            _members = members;
            _invites = pendingInvites;
          });
        }
      }
    } catch (e) {
      debugPrint('Erro ao carregar membros: $e');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  /// Enriquece convites com dados do perfil do usuário (avatar, nome completo)
  Future<void> _enrichInvitesWithProfiles(List<Map<String, dynamic>> invites) async {
    for (var invite in invites) {
      try {
        final users = await authModule.getUserByEmail(invite['email']);
        if (users.isNotEmpty) {
          invite['user_profile'] = users.first;
        }
      } catch (e) {
        debugPrint('Erro ao buscar perfil de ${invite['email']}: $e');
      }
    }
  }

  /// Combina membros ativos e convites pendentes em uma única lista
  List<Map<String, dynamic>> get _allMembersAndInvites {
    final combined = <Map<String, dynamic>>[];

    // Adicionar membros ativos
    combined.addAll(_members);

    // Adicionar convites pendentes como "membros pendentes"
    for (final invite in _invites) {
      final userProfile = invite['user_profile'] as Map<String, dynamic>?;

      combined.add({
        'id': invite['id'],
        'user_id': userProfile?['id'] ?? invite['id'],
        'email': invite['email'],
        'role': invite['role'],
        'status': 'pending',
        'profiles': {
          'email': invite['email'],
          'full_name': userProfile?['full_name'] ?? invite['email'].split('@')[0],
          'avatar_url': userProfile?['avatar_url'],
        },
        'is_invite': true,
        'invite_id': invite['id'],
      });
    }

    return combined;
  }

  /// Filtra os membros baseado na busca e filtros selecionados
  List<Map<String, dynamic>> get _filteredMembers {
    var filtered = _allMembersAndInvites;

    // Aplicar busca por nome ou email
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtered = filtered.where((member) {
        final profile = member['profiles'] as Map<String, dynamic>?;
        final name = (profile?['full_name'] ?? '').toString().toLowerCase();
        final email = (profile?['email'] ?? '').toString().toLowerCase();
        return name.contains(query) || email.contains(query);
      }).toList();
    }

    // Aplicar filtro por cargo
    if (_filterType == 'role' && _filterValue != null && _filterValue!.isNotEmpty) {
      filtered = filtered.where((member) => member['role'] == _filterValue).toList();
    }

    // Aplicar filtro por status
    if (_filterType == 'status' && _filterValue != null && _filterValue!.isNotEmpty) {
      filtered = filtered.where((member) => member['status'] == _filterValue).toList();
    }

    return filtered;
  }

  @override
  Widget build(BuildContext context) {

    final appState = AppStateScope.of(context);
    final canManage = appState.canManageMembers;

    return Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Membros da Organização',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Gerencie membros e suas permissões',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Barra de busca e filtros
          TableSearchFilterBar(
            searchHint: 'Buscar membro (nome ou email...)',
            onSearchChanged: (value) {
              setState(() => _searchQuery = value);
            },
            filterType: _filterType,
            filterTypeLabel: 'Tipo de filtro',
            filterTypeOptions: const [
              FilterOption(value: 'none', label: 'Nenhum'),
              FilterOption(value: 'role', label: 'Cargo'),
              FilterOption(value: 'status', label: 'Status'),
            ],
            onFilterTypeChanged: (value) {
              setState(() {
                _filterType = value ?? 'none';
                _filterValue = null;
              });
            },
            filterValue: _filterValue,
            filterValueLabel: _filterType == 'role' ? 'Cargo' : 'Status',
            filterValueOptions: _filterType == 'role'
              ? ['owner', 'admin', 'gestor', 'financeiro', 'designer', 'usuario']
              : _filterType == 'status'
                ? ['active', 'inactive', 'suspended', 'pending']
                : null,
            filterValueLabelBuilder: (value) {
              if (_filterType == 'role') {
                switch (value) {
                  case 'owner': return 'Proprietário';
                  case 'admin': return 'Administrador';
                  case 'gestor': return 'Gestor';
                  case 'financeiro': return 'Financeiro';
                  case 'designer': return 'Designer';
                  case 'usuario': return 'Usuário';
                  default: return value;
                }
              } else if (_filterType == 'status') {
                switch (value) {
                  case 'active': return 'Ativo';
                  case 'inactive': return 'Inativo';
                  case 'suspended': return 'Suspenso';
                  case 'pending': return 'Pendente';
                  default: return value;
                }
              }
              return value;
            },
            onFilterValueChanged: (value) {
              setState(() => _filterValue = value?.isEmpty == true ? null : value);
            },
            showFilters: true,
            actionButton: canManage ? FilledButton.icon(
              onPressed: _addMember,
              icon: const Icon(Icons.mail_outline),
              label: const Text('Enviar Convite'),
            ) : null,
          ),

          // Tabela
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: DynamicPaginatedTable<Map<String, dynamic>>(
                items: _filteredMembers,
                itemLabel: 'membro(s)',
                isLoading: _loading,
                showCheckboxes: true,
                selectedIds: const {},
                columns: const [
                  DataTableColumn(label: 'Nome', sortable: true, flex: 2),
                  DataTableColumn(label: 'Email', sortable: true, flex: 2),
                  DataTableColumn(label: 'Cargo', sortable: true, flex: 1),
                  DataTableColumn(label: 'Status', sortable: true, flex: 1),
                ],
                cellBuilders: [
                  (member) {
                    final profile = member['profiles'] as Map<String, dynamic>?;
                    return Row(
                      children: [
                        CircleAvatar(
                          radius: 16,
                          backgroundColor: const Color(0xFF2196F3),
                          backgroundImage: profile?['avatar_url'] != null
                              ? NetworkImage(profile!['avatar_url'])
                              : null,
                          child: profile?['avatar_url'] == null
                              ? Text(
                                  (profile?['full_name'] ?? 'U')[0].toUpperCase(),
                                  style: const TextStyle(color: Colors.white, fontSize: 14),
                                )
                              : null,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            profile?['full_name'] ?? 'Usuário',
                            style: const TextStyle(color: Colors.white),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    );
                  },
                  (member) {
                    final profile = member['profiles'] as Map<String, dynamic>?;
                    return Text(
                      profile?['email'] ?? '',
                      style: TextStyle(color: Colors.grey[400]),
                      overflow: TextOverflow.ellipsis,
                    );
                  },
                  (member) => RoleBadge(role: member['role']),
                  (member) => MemberStatusBadge(status: member['status']),
                ],
                sortComparators: [
                  (a, b) {
                    final aProfile = a['profiles'] as Map<String, dynamic>?;
                    final bProfile = b['profiles'] as Map<String, dynamic>?;
                    final aName = aProfile?['full_name'] ?? '';
                    final bName = bProfile?['full_name'] ?? '';
                    return aName.toString().compareTo(bName.toString());
                  },
                  (a, b) {
                    final aProfile = a['profiles'] as Map<String, dynamic>?;
                    final bProfile = b['profiles'] as Map<String, dynamic>?;
                    final aEmail = aProfile?['email'] ?? '';
                    final bEmail = bProfile?['email'] ?? '';
                    return aEmail.toString().compareTo(bEmail.toString());
                  },
                  (a, b) {
                    final aRole = a['role'] ?? '';
                    final bRole = b['role'] ?? '';
                    return aRole.toString().compareTo(bRole.toString());
                  },
                  (a, b) {
                    final aStatus = a['status'] ?? '';
                    final bStatus = b['status'] ?? '';
                    return aStatus.toString().compareTo(bStatus.toString());
                  },
                ],
                getId: (member) => member['user_id'] as String,
                actions: canManage
                    ? [
                        // Ação: Alterar Função (só para membros ativos)
                        DataTableAction<Map<String, dynamic>>(
                          icon: Icons.edit,
                          label: 'Alterar Função',
                          onPressed: _changeRole,
                          showWhen: (member) {
                            final isInvite = member['is_invite'] == true;
                            if (isInvite) return false; // Não mostrar para convites

                            final currentUserId = authModule.currentUser?.id;
                            final memberId = member['user_id'];
                            final memberRole = member['role'];
                            return memberId != currentUserId && memberRole != 'owner';
                          },
                        ),
                        // Ação: Remover Membro (só para membros ativos)
                        DataTableAction<Map<String, dynamic>>(
                          icon: Icons.person_remove,
                          label: 'Remover',
                          onPressed: _removeMember,
                          showWhen: (member) {
                            final isInvite = member['is_invite'] == true;
                            if (isInvite) return false; // Não mostrar para convites

                            final currentUserId = authModule.currentUser?.id;
                            final memberId = member['user_id'];
                            final memberRole = member['role'];
                            return memberId != currentUserId && memberRole != 'owner';
                          },
                        ),
                        // Ação: Reenviar Convite (só para convites pendentes)
                        DataTableAction<Map<String, dynamic>>(
                          icon: Icons.send,
                          label: 'Reenviar Convite',
                          onPressed: _resendInvite,
                          showWhen: (member) => member['is_invite'] == true,
                        ),
                        // Ação: Cancelar Convite (só para convites pendentes)
                        DataTableAction<Map<String, dynamic>>(
                          icon: Icons.cancel,
                          label: 'Cancelar Convite',
                          onPressed: _cancelInvite,
                          showWhen: (member) => member['is_invite'] == true,
                        ),
                      ]
                    : null,
                emptyWidget: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.people_outline,
                        size: 64,
                        color: Colors.grey[600],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Nenhum membro encontrado',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _addMember() async {
    final appState = AppStateScope.of(context);
    final orgId = appState.currentOrganizationId;

    if (orgId == null) return;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AddMemberDialog(organizationId: orgId),
    );

    if (result == true) {
      _loadMembers();
    }
  }

  Future<void> _changeRole(Map<String, dynamic> member) async {
    final appState = AppStateScope.of(context);
    final orgId = appState.currentOrganizationId;
    if (orgId == null) return;

    final currentRole = member['role'] as String;
    final newRole = await _showRoleSelectionDialog(currentRole);

    if (newRole != null && newRole != currentRole) {
      try {
        await organizationsModule.updateOrganizationMemberRole(
          organizationId: orgId,
          userId: member['user_id'],
          role: newRole,
        );
        _showSuccessMessage('Função alterada com sucesso!');
        _loadMembers();
      } catch (e) {
        _showErrorMessage('Erro ao alterar função: $e');
      }
    }
  }

  /// Exibe diálogo de seleção de função
  Future<String?> _showRoleSelectionDialog(String currentRole) {
    String? selectedRole = currentRole;

    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('Alterar Função', style: TextStyle(color: Colors.white)),
        content: StatefulBuilder(
          builder: (context, setState) => RadioGroup<String>(
            groupValue: selectedRole,
            onChanged: (value) => setState(() => selectedRole = value),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                RadioListTile<String>(
                  title: const Text('Usuário', style: TextStyle(color: Colors.white)),
                  value: 'usuario',
                ),
                RadioListTile<String>(
                  title: const Text('Designer', style: TextStyle(color: Colors.white)),
                  value: 'designer',
                ),
                RadioListTile<String>(
                  title: const Text('Financeiro', style: TextStyle(color: Colors.white)),
                  value: 'financeiro',
                ),
                RadioListTile<String>(
                  title: const Text('Gestor', style: TextStyle(color: Colors.white)),
                  value: 'gestor',
                ),
                RadioListTile<String>(
                  title: const Text('Administrador', style: TextStyle(color: Colors.white)),
                  value: 'admin',
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, selectedRole),
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
  }

  Future<void> _removeMember(Map<String, dynamic> member) async {
    final appState = AppStateScope.of(context);
    final orgId = appState.currentOrganizationId;
    if (orgId == null) return;

    final profile = member['profiles'] as Map<String, dynamic>?;
    final userName = profile?['full_name'] ?? 'este membro';

    final confirmed = await _showConfirmationDialog(
      title: 'Remover Membro',
      message: 'Tem certeza que deseja remover $userName da organização?',
      confirmText: 'Remover',
    );

    if (confirmed == true) {
      try {
        await organizationsModule.removeOrganizationMember(
          organizationId: orgId,
          userId: member['user_id'],
        );
        _showSuccessMessage('Membro removido com sucesso!');
        _loadMembers();
      } catch (e) {
        _showErrorMessage('Erro ao remover membro: $e');
      }
    }
  }

  Future<void> _resendInvite(Map<String, dynamic> member) async {
    final inviteId = member['invite_id'];
    if (inviteId == null) return;

    try {
      await organizationsModule.resendInvite(inviteId);
      _showSuccessMessage('Convite reenviado com sucesso!');
      _loadMembers();
    } catch (e) {
      _showErrorMessage('Erro ao reenviar convite: $e');
    }
  }

  Future<void> _cancelInvite(Map<String, dynamic> member) async {
    final inviteId = member['invite_id'];
    if (inviteId == null) return;

    final email = member['email'] ?? 'este convite';

    final confirmed = await _showConfirmationDialog(
      title: 'Cancelar Convite',
      message: 'Tem certeza que deseja cancelar o convite para $email?',
      confirmText: 'Sim, Cancelar',
      cancelText: 'Não',
    );

    if (confirmed == true) {
      try {
        await organizationsModule.cancelInvite(inviteId);
        _showSuccessMessage('Convite cancelado com sucesso!');
        _loadMembers();
      } catch (e) {
        _showErrorMessage('Erro ao cancelar convite: $e');
      }
    }
  }

  /// Exibe um diálogo de confirmação
  Future<bool?> _showConfirmationDialog({
    required String title,
    required String message,
    required String confirmText,
    String cancelText = 'Cancelar',
  }) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: Text(title, style: const TextStyle(color: Colors.white)),
        content: Text(message, style: const TextStyle(color: Colors.white)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(cancelText),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(confirmText),
          ),
        ],
      ),
    );
  }

  /// Exibe mensagem de sucesso
  void _showSuccessMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  /// Exibe mensagem de erro
  void _showErrorMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }
}

