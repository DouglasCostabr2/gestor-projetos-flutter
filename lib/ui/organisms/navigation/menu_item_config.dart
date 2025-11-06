import 'package:flutter/material.dart';
import '../../../src/navigation/app_page.dart';
import '../../../src/navigation/user_role.dart';

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
      hasAccess: (role) => role == UserRole.admin || role == UserRole.gestor || role == UserRole.financeiro,
    ),
    MenuItemConfig(
      page: AppPage.projects,
      icon: Icons.work,
      label: 'Projetos',
      hasAccess: (role) => true, // Todos têm acesso
    ),
    MenuItemConfig(
      page: AppPage.tasks,
      icon: Icons.checklist,
      label: 'Tarefas',
      hasAccess: (role) => true, // Todos têm acesso
    ),
    MenuItemConfig(
      page: AppPage.notifications,
      icon: Icons.notifications,
      label: 'Notificações',
      hasAccess: (role) => true, // Todos têm acesso
    ),
    MenuItemConfig(
      page: AppPage.admin,
      icon: Icons.security,
      label: 'Admin',
      hasAccess: (role) => role.isAdmin,
    ),
    MenuItemConfig(
      page: AppPage.organization,
      icon: Icons.business,
      label: 'Organização',
      hasAccess: (role) => role.isAdmin, // Owner e Admin têm acesso
    ),
    // Configurações removido - agora está apenas no rodapé do menu
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

