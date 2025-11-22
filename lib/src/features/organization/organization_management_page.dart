import 'package:flutter/material.dart';
import '../../state/app_state_scope.dart';
import 'tabs/organization_details_tab.dart';
import 'tabs/organization_invites_tab.dart';

/// Página de gerenciamento de organizações
///
/// Permite gerenciar:
/// - Dados da organização atual
/// - Convites pendentes
class OrganizationManagementPage extends StatefulWidget {
  /// Índice inicial da aba (0: Organização, 1: Convites)
  final int initialTabIndex;

  const OrganizationManagementPage({
    super.key,
    this.initialTabIndex = 0,
  });

  @override
  State<OrganizationManagementPage> createState() => _OrganizationManagementPageState();
}

class _OrganizationManagementPageState extends State<OrganizationManagementPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTabIndex.clamp(0, 1),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appState = AppStateScope.of(context);
    final currentOrg = appState.currentOrganization;


    if (currentOrg == null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.business_outlined,
                size: 64,
                color: Colors.grey[600],
              ),
              const SizedBox(height: 16),
              Text(
                'Nenhuma organização ativa',
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Selecione uma organização no menu lateral',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[500],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E),
              border: Border(
                bottom: BorderSide(
                  color: Colors.grey[800]!,
                  width: 1,
                ),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.business,
                      size: 32,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            currentOrg['name'] ?? 'Organização',
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Gerencie sua organização e convites',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[400],
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Role badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: _getRoleColor(appState.currentOrgRole),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _getRoleLabel(appState.currentOrgRole),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                // Tabs
                TabBar(
                  controller: _tabController,
                  indicatorColor: const Color(0xFF2196F3),
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.grey[500],
                  tabs: const [
                    Tab(
                      icon: Icon(Icons.business),
                      text: 'Organização',
                    ),
                    Tab(
                      icon: Icon(Icons.mail),
                      text: 'Convites',
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Tab content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: const [
                OrganizationDetailsTab(),
                OrganizationInvitesTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getRoleColor(String? role) {
    switch (role) {
      case 'owner':
        return const Color(0xFFE91E63);
      case 'admin':
        return const Color(0xFF9C27B0);
      case 'gestor':
        return const Color(0xFF2196F3);
      case 'financeiro':
        return const Color(0xFF4CAF50);
      case 'designer':
        return const Color(0xFFFF9800);
      default:
        return Colors.grey;
    }
  }

  String _getRoleLabel(String? role) {
    switch (role) {
      case 'owner':
        return 'Proprietário';
      case 'admin':
        return 'Administrador';
      case 'gestor':
        return 'Gestor';
      case 'financeiro':
        return 'Financeiro';
      case 'designer':
        return 'Designer';
      case 'usuario':
        return 'Usuário';
      default:
        return 'Sem role';
    }
  }
}

