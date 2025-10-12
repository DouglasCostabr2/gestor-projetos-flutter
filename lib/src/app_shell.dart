import 'package:flutter/material.dart';
import 'features/home/home_page.dart';
import 'features/clients/clients_page.dart';
import 'features/projects/projects_page.dart';
import 'features/tasks/tasks_page.dart';
import 'features/catalog/catalog_page.dart';
import 'features/finance/finance_page.dart';
import 'features/admin/admin_page.dart';
import 'features/monitoring/user_monitoring_page.dart';
import 'features/settings/settings_page.dart';

import 'features/auth/login_page.dart';
import 'state/app_state.dart';
import 'navigation/user_role.dart';
import 'navigation/tab_item.dart';
import 'navigation/tab_manager.dart';
import 'navigation/tab_manager_scope.dart';
import '../widgets/side_menu/side_menu.dart';
import '../widgets/tab_bar/tab_bar_widget.dart';
import '../modules/modules.dart';

class AppShell extends StatefulWidget {
  final AppState appState;
  final int initialIndex;
  const AppShell({super.key, required this.appState, this.initialIndex = 0});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  late int _selectedIndex;
  late TabManager _tabManager;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex;
    _tabManager = TabManager();

    // Adiciona a primeira aba com a página inicial
    _addTabForPage(_selectedIndex);

    // Escuta mudanças de aba para atualizar o selectedIndex
    _tabManager.addListener(_onTabChanged);
  }

  void _onTabChanged() {
    // Quando a aba atual mudar, atualizar o _selectedIndex para refletir
    // o selectedMenuIndex da aba ativa
    final currentTab = _tabManager.currentTab;
    if (currentTab != null && currentTab.selectedMenuIndex != _selectedIndex) {
      setState(() {
        _selectedIndex = currentTab.selectedMenuIndex;
      });
      debugPrint('🔄 Aba mudou: atualizando selectedIndex para ${currentTab.selectedMenuIndex}');
    }
  }

  @override
  void dispose() {
    _tabManager.removeListener(_onTabChanged);
    _tabManager.dispose();
    super.dispose();
  }

  Widget _getPageForIndex(int index) {
    switch (index) {
      case 0:
        return const HomePage();
      case 1:
        return const ClientsPage();
      case 2:
        return const ProjectsPage();
      case 3:
        return const CatalogPage();
      case 4:
        return const TasksPage();
      case 5:
        return const FinancePage();
      case 6:
        return const AdminPage();
      case 7:
        return const UserMonitoringPage();
      default:
        return const HomePage();
    }
  }

  String _getTitleForIndex(int index) {
    switch (index) {
      case 0:
        return 'Home';
      case 1:
        return 'Clientes';
      case 2:
        return 'Projetos';
      case 3:
        return 'Catálogo';
      case 4:
        return 'Tarefas';
      case 5:
        return 'Financeiro';
      case 6:
        return 'Admin';
      case 7:
        return 'Monitoramento';
      default:
        return 'Home';
    }
  }

  IconData _getIconForIndex(int index) {
    switch (index) {
      case 0:
        return Icons.home;
      case 1:
        return Icons.people;
      case 2:
        return Icons.work;
      case 3:
        return Icons.storefront;
      case 4:
        return Icons.checklist;
      case 5:
        return Icons.account_balance_wallet;
      case 6:
        return Icons.admin_panel_settings;
      case 7:
        return Icons.monitor_heart;
      default:
        return Icons.home;
    }
  }

  void _addTabForPage(int pageIndex) {
    // Todas as páginas principais usam ID fixo baseado no índice
    final String id = 'page_$pageIndex';
    final bool allowDuplicates = false;

    final tab = TabItem(
      id: id,
      title: _getTitleForIndex(pageIndex),
      icon: _getIconForIndex(pageIndex),
      page: _getPageForIndex(pageIndex),
      canClose: true,
      selectedMenuIndex: pageIndex, // Armazena qual item do menu está selecionado
    );
    _tabManager.addTab(tab, allowDuplicates: allowDuplicates);
  }

  void _handleNewTab() {
    // Sempre cria uma nova aba da Home (índice 0)
    _addTabForPage(0);
  }

  @override
  Widget build(BuildContext context) {
    // OTIMIZAÇÃO: Usar AnimatedBuilder apenas para mudanças de perfil/role
    // O sideMenu usa ValueListenableBuilder separado para evitar rebuilds desnecessários
    return AnimatedBuilder(
      animation: widget.appState,
      builder: (context, _) {
        // Cliente: bloquear Clientes e Catálogo; manter Home/Projetos/Tarefas
        if (widget.appState.isCliente && (_selectedIndex == 1 || _selectedIndex == 3)) {
          _selectedIndex = 0; // Home
        }
        // Financeiro: apenas admin, gestor ou financeiro
        if (!(widget.appState.isAdmin || widget.appState.isGestor || widget.appState.isFinanceiro) && _selectedIndex == 5) {
          _selectedIndex = 0;
        }
        // Admin: apenas admin
        if (!widget.appState.isAdmin && _selectedIndex == 6) {
          _selectedIndex = 0;
        }
        // Monitoramento: apenas admin ou gestor
        if (!(widget.appState.isAdmin || widget.appState.isGestor) && _selectedIndex == 7) {
          _selectedIndex = 0;
        }

        return TabManagerScope(
          tabManager: _tabManager,
          child: Scaffold(
            body: Column(
              children: [
                // Barra de abas no topo
                TabBarWidget(
                  tabManager: _tabManager,
                  onNewTab: _handleNewTab,
                ),
                // Conteúdo abaixo (side menu + página)
                Expanded(
                  child: Row(
                    children: [
                      // OTIMIZAÇÃO: ValueListenableBuilder apenas para collapsed state
                      ValueListenableBuilder<bool>(
                        valueListenable: widget.appState.sideMenuCollapsedNotifier,
                        builder: (context, collapsed, _) {
                          return SideMenu(
                            collapsed: collapsed,
                            selectedIndex: _selectedIndex,
                            onSelect: (i) {
                              setState(() => _selectedIndex = i);

                              debugPrint('🖱️ SideMenu.onSelect: índice $i');

                              final pageId = 'page_$i';
                              final currentTab = _tabManager.currentTab;

                              debugPrint('   Aba atual: ${currentTab?.id}');
                              debugPrint('   Página desejada: $pageId');

                              // Se a aba atual já é a página desejada, não faz nada
                              if (currentTab?.id == pageId) {
                                debugPrint('   ✅ Já está na página correta!');
                                return;
                              }

                              // Sempre atualizar a aba atual em vez de criar uma nova
                              if (currentTab != null) {
                                debugPrint('   🔄 Atualizando aba de "${currentTab.id}" para "$pageId"');
                                final updatedTab = currentTab.copyWith(
                                  id: pageId,
                                  page: _getPageForIndex(i),
                                  title: _getTitleForIndex(i),
                                  icon: _getIconForIndex(i),
                                  selectedMenuIndex: i, // Atualiza o índice do menu selecionado
                                );
                                _tabManager.updateTab(_tabManager.currentIndex, updatedTab);
                              } else {
                                // Se não há aba atual, criar uma nova
                                debugPrint('   ➕ Criando nova aba "$pageId"');
                                _addTabForPage(i);
                              }
                            },
                            onToggle: () => widget.appState.toggleSideMenu(),
                            onLogout: () async {
                              final navigator = Navigator.of(context);
                              await authModule.signOut();
                              if (!mounted) return;
                              navigator.pushAndRemoveUntil(
                                MaterialPageRoute(builder: (_) => LoginPage(onLoggedIn: widget.appState.refreshProfile)),
                                (route) => false,
                              );
                            },
                            onProfileTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const SettingsPage()),
                              );
                            },
                            userRole: UserRoleExtension.fromString(widget.appState.role),
                            profile: widget.appState.profile,
                          );
                        },
                      ),
                      Expanded(
                        child: AnimatedBuilder(
                          animation: _tabManager,
                          builder: (context, _) {
                            final currentTab = _tabManager.currentTab;
                            debugPrint('📄 AppShell renderizando aba: ${currentTab?.id} - ${currentTab?.title}');

                            if (currentTab == null) {
                              debugPrint('   ⚠️ Nenhuma aba atual, renderizando página do índice $_selectedIndex');
                              return _getPageForIndex(_selectedIndex);
                            }

                            debugPrint('   ✅ Renderizando página da aba: ${currentTab.id}');
                            return currentTab.page;
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
