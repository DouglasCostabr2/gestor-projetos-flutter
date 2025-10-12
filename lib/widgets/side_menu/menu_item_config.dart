import 'package:flutter/material.dart';
import '../../src/navigation/app_page.dart';
import '../../src/navigation/user_role.dart';

/// Configuração de um item do menu lateral
class MenuItemConfig {
  final AppPage page;
  final IconData icon;
  final String label;
  final bool Function(UserRole) hasAccess;

  const MenuItemConfig({
    required this.page,
    required this.icon,
    required this.label,
    required this.hasAccess,
  });

  /// Verifica se o usuário tem acesso a esta página
  bool isAccessibleBy(UserRole role) => hasAccess(role);
}

/// Configuração de todos os itens do menu
class MenuConfig {
  static final List<MenuItemConfig> items = [
    MenuItemConfig(
      page: AppPage.home,
      icon: Icons.home,
      label: 'Home',
      hasAccess: (role) => true, // Todos têm acesso
    ),
    MenuItemConfig(
      page: AppPage.clients,
      icon: Icons.people,
      label: 'Clientes',
      hasAccess: (role) => role != UserRole.cliente,
    ),
    MenuItemConfig(
      page: AppPage.projects,
      icon: Icons.work,
      label: 'Projetos',
      hasAccess: (role) => true, // Todos têm acesso
    ),
    MenuItemConfig(
      page: AppPage.catalog,
      icon: Icons.storefront,
      label: 'Catálogo',
      hasAccess: (role) => role != UserRole.cliente,
    ),
    MenuItemConfig(
      page: AppPage.tasks,
      icon: Icons.checklist,
      label: 'Tarefas',
      hasAccess: (role) => true, // Todos têm acesso
    ),
    MenuItemConfig(
      page: AppPage.finance,
      icon: Icons.account_balance_wallet,
      label: 'Financeiro',
      hasAccess: (role) => role.hasFinanceAccess,
    ),
    MenuItemConfig(
      page: AppPage.admin,
      icon: Icons.security,
      label: 'Admin',
      hasAccess: (role) => role.isAdmin,
    ),
    MenuItemConfig(
      page: AppPage.monitoring,
      icon: Icons.monitor_heart,
      label: 'Monitoramento',
      hasAccess: (role) => role.isGestorOrAbove,
    ),
  ];

  /// Retorna a configuração de um item pelo AppPage
  static MenuItemConfig? getByPage(AppPage page) {
    try {
      return items.firstWhere((item) => item.page == page);
    } catch (_) {
      return null;
    }
  }

  /// Retorna a configuração de um item pelo índice
  static MenuItemConfig? getByIndex(int index) {
    if (index < 0 || index >= items.length) return null;
    return items[index];
  }
}

