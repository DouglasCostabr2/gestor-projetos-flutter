import 'package:flutter/material.dart';
import '../../src/state/app_state.dart';
import '../../src/state/app_state_scope.dart';
import '../../src/features/organization/dialogs/create_organization_dialog.dart';

/// Widget para alternar entre organizações
///
/// Exibe a organização ativa e permite trocar para outra organização
/// através de um dropdown/menu
class OrganizationSwitcher extends StatelessWidget {
  final AppState appState;
  final bool collapsed;

  const OrganizationSwitcher({
    super.key,
    required this.appState,
    required this.collapsed,
  });

  @override
  Widget build(BuildContext context) {
    final currentOrg = appState.currentOrganization;
    final orgs = appState.myOrganizations;
    final isAdmin = appState.isAdmin;

    debugPrint('🏢 [OrganizationSwitcher] Build - currentOrg: ${currentOrg?['name']}, orgs.length: ${orgs.length}, isAdmin: $isAdmin');

    // IMPORTANTE: Apenas admins podem ver e gerenciar organizações
    // Usuários comuns não precisam saber sobre organizações - é transparente para eles
    if (!isAdmin) {
      debugPrint('🔒 [OrganizationSwitcher] Usuário não é admin, ocultando widget');
      return const SizedBox.shrink();
    }

    // Se não há organizações, não exibir nada
    if (orgs.isEmpty) {
      debugPrint('⚠️ [OrganizationSwitcher] Nenhuma organização encontrada, ocultando widget');
      return const SizedBox.shrink();
    }

    // Se há apenas uma organização, exibir sem dropdown
    if (orgs.length == 1) {
      debugPrint('📌 [OrganizationSwitcher] Exibindo organização única: ${orgs.first['name']}');
      return _SingleOrganizationDisplay(
        organization: currentOrg ?? orgs.first,
        collapsed: collapsed,
      );
    }

    // Se há múltiplas organizações, exibir com dropdown
    debugPrint('📋 [OrganizationSwitcher] Exibindo dropdown com ${orgs.length} organizações');
    return _MultipleOrganizationsDropdown(
      appState: appState,
      collapsed: collapsed,
    );
  }
}

/// Exibe uma única organização (com opção de criar nova)
class _SingleOrganizationDisplay extends StatelessWidget {
  final Map<String, dynamic> organization;
  final bool collapsed;

  const _SingleOrganizationDisplay({
    required this.organization,
    required this.collapsed,
  });

  @override
  Widget build(BuildContext context) {
    // Verificar se o usuário é admin (role global)
    final appState = AppStateScope.of(context);
    final isAdmin = appState.isAdmin;

    debugPrint('🔐 [SingleOrgDisplay] isAdmin: $isAdmin, role: ${appState.role}');

    if (collapsed) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Center(
          child: PopupMenuButton<String>(
            tooltip: 'Opções de organização',
            offset: const Offset(60, 0),
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: const Color(0xFF2A2A2A),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text(
                  _getInitials(organization['name'] ?? 'O'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            itemBuilder: (context) {
              final items = <PopupMenuEntry<String>>[
                PopupMenuItem<String>(
                  value: organization['id'],
                  child: Row(
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: const Color(0xFF3A3A3A),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Center(
                          child: Text(
                            _getInitials(organization['name'] ?? 'O'),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          organization['name'] ?? 'Organização',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      const Icon(Icons.check, size: 20, color: Color(0xFF4CAF50)),
                    ],
                  ),
                ),
              ];

              // Adicionar opção de criar nova organização apenas para admins
              if (isAdmin) {
                items.add(const PopupMenuDivider());
                items.add(
                  const PopupMenuItem<String>(
                    value: '__create_new__',
                    child: Row(
                      children: [
                        Icon(Icons.add_circle_outline, size: 20, color: Color(0xFF2196F3)),
                        SizedBox(width: 12),
                        Text(
                          'Criar Nova Organização',
                          style: TextStyle(
                            color: Color(0xFF2196F3),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return items;
            },
            onSelected: (value) async {
              if (value == '__create_new__') {
                if (context.mounted) {
                  await showDialog(
                    context: context,
                    builder: (context) => const CreateOrganizationDialog(),
                  );
                }
              }
            },
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: PopupMenuButton<String>(
        tooltip: 'Opções de organização',
        offset: const Offset(0, 50),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF2A2A2A),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: const Color(0xFF3A3A3A),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    _getInitials(organization['name'] ?? 'O'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      organization['name'] ?? 'Organização',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Organização',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_drop_down,
                color: Colors.white70,
                size: 20,
              ),
            ],
          ),
        ),
        itemBuilder: (context) {
          final items = <PopupMenuEntry<String>>[
            PopupMenuItem<String>(
              value: organization['id'],
              child: Row(
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: const Color(0xFF3A3A3A),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Center(
                      child: Text(
                        _getInitials(organization['name'] ?? 'O'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      organization['name'] ?? 'Organização',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  const Icon(Icons.check, size: 20, color: Color(0xFF4CAF50)),
                ],
              ),
            ),
          ];

          // Adicionar opção de criar nova organização apenas para admins
          if (isAdmin) {
            items.add(const PopupMenuDivider());
            items.add(
              const PopupMenuItem<String>(
                value: '__create_new__',
                child: Row(
                  children: [
                    Icon(Icons.add_circle_outline, size: 20, color: Color(0xFF2196F3)),
                    SizedBox(width: 12),
                    Text(
                      'Criar Nova Organização',
                      style: TextStyle(
                        color: Color(0xFF2196F3),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          return items;
        },
        onSelected: (value) async {
          if (value == '__create_new__') {
            if (context.mounted) {
              await showDialog(
                context: context,
                builder: (context) => const CreateOrganizationDialog(),
              );
            }
          }
        },
      ),
    );
  }
}

/// Dropdown para alternar entre múltiplas organizações
class _MultipleOrganizationsDropdown extends StatelessWidget {
  final AppState appState;
  final bool collapsed;

  const _MultipleOrganizationsDropdown({
    required this.appState,
    required this.collapsed,
  });

  @override
  Widget build(BuildContext context) {
    final currentOrg = appState.currentOrganization;
    final orgs = appState.myOrganizations;
    final isAdmin = appState.isAdmin;

    debugPrint('🔐 [MultipleOrgsDropdown] isAdmin: $isAdmin, role: ${appState.role}');

    if (collapsed) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Center(
          child: PopupMenuButton<String>(
            tooltip: 'Trocar organização',
            offset: const Offset(60, 0),
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: const Color(0xFF2A2A2A),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text(
                  _getInitials(currentOrg?['name'] ?? 'O'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            itemBuilder: (context) {
              final items = orgs.map((org) {
                final isSelected = org['id'] == currentOrg?['id'];
                return PopupMenuItem<String>(
                  value: org['id'],
                  child: Row(
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: const Color(0xFF3A3A3A),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Center(
                          child: Text(
                            _getInitials(org['name'] ?? 'O'),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          org['name'] ?? 'Organização',
                          style: TextStyle(
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                          ),
                        ),
                      ),
                      if (isSelected)
                        const Icon(Icons.check, size: 18, color: Colors.green),
                    ],
                  ),
                );
              }).toList();

              // Adicionar opção de criar nova organização apenas para admins
              if (isAdmin) {
                items.add(
                  const PopupMenuItem<String>(
                    value: '__create_new__',
                    child: Row(
                      children: [
                        Icon(Icons.add_circle_outline, size: 20, color: Color(0xFF2196F3)),
                        SizedBox(width: 12),
                        Text(
                          'Criar Nova Organização',
                          style: TextStyle(
                            color: Color(0xFF2196F3),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return items;
            },
            onSelected: (orgId) async {
              // Se for a opção de criar nova organização
              if (orgId == '__create_new__') {
                if (context.mounted) {
                  await showDialog(
                    context: context,
                    builder: (context) => const CreateOrganizationDialog(),
                  );
                }
                return;
              }

              // Caso contrário, trocar de organização
              try {
                await appState.setCurrentOrganization(orgId);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Organização alterada para: ${appState.currentOrganization?['name']}'),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Erro ao trocar organização: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: PopupMenuButton<String>(
        tooltip: 'Trocar organização',
        offset: const Offset(0, 50),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF2A2A2A),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: const Color(0xFF3A3A3A),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    _getInitials(currentOrg?['name'] ?? 'O'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      currentOrg?['name'] ?? 'Organização',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${orgs.length} organizações',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.unfold_more,
                size: 18,
                color: Colors.white.withValues(alpha: 0.6),
              ),
            ],
          ),
        ),
        itemBuilder: (context) {
          final items = orgs.map((org) {
            final isSelected = org['id'] == currentOrg?['id'];
            return PopupMenuItem<String>(
              value: org['id'],
              child: Row(
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: const Color(0xFF3A3A3A),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Center(
                      child: Text(
                        _getInitials(org['name'] ?? 'O'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      org['name'] ?? 'Organização',
                      style: TextStyle(
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                  ),
                  if (isSelected)
                    const Icon(Icons.check, size: 18, color: Colors.green),
                ],
              ),
            );
          }).toList();

          // Adicionar opção de criar nova organização apenas para admins
          if (isAdmin) {
            items.add(
              const PopupMenuItem<String>(
                value: '__create_new__',
                child: Row(
                  children: [
                    Icon(Icons.add_circle_outline, size: 20, color: Color(0xFF2196F3)),
                    SizedBox(width: 12),
                    Text(
                      'Criar Nova Organização',
                      style: TextStyle(
                        color: Color(0xFF2196F3),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          return items;
        },
        onSelected: (orgId) async {
          // Se for a opção de criar nova organização
          if (orgId == '__create_new__') {
            if (context.mounted) {
              await showDialog(
                context: context,
                builder: (context) => const CreateOrganizationDialog(),
              );
            }
            return;
          }

          // Caso contrário, trocar de organização
          try {
            await appState.setCurrentOrganization(orgId);
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Organização alterada para: ${appState.currentOrganization?['name']}'),
                  duration: const Duration(seconds: 2),
                ),
              );
            }
          } catch (e) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Erro ao trocar organização: $e'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          }
        },
      ),
    );
  }
}

/// Helper para obter iniciais do nome da organização
String _getInitials(String name) {
  final words = name.trim().split(' ');
  if (words.isEmpty) return 'O';
  if (words.length == 1) return words[0][0].toUpperCase();
  return (words[0][0] + words[1][0]).toUpperCase();
}

