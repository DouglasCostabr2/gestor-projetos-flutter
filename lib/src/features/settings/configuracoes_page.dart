import 'package:flutter/material.dart';
import '../../../ui/organisms/cards/navigation_cards_grid.dart';
import '../../navigation/tab_manager_scope.dart';
import '../../navigation/tab_item.dart';
import '../settings/settings_page.dart';
import '../organization/organization_management_page.dart';

/// Página de Configurações
class ConfiguracoesPage extends StatelessWidget {
  const ConfiguracoesPage({super.key});

  /// Lista de cards de configuração
  List<NavigationCardItem> _configCards(BuildContext context) => [
        NavigationCardItem(
          icon: Icons.person,
          title: 'Perfil',
          description: 'Gerencie suas informações pessoais',
          onTap: () {
            final tabManager = TabManagerScope.maybeOf(context);
            if (tabManager != null) {
              final currentIndex = tabManager.currentIndex;
              final currentTab = tabManager.currentTab;
              final updatedTab = TabItem(
                id: 'settings_profile',
                title: 'Perfil',
                icon: Icons.person,
                page: const SettingsPage(),
                canClose: true,
                selectedMenuIndex: currentTab?.selectedMenuIndex ?? 9, // Configurações
              );
              tabManager.updateTab(currentIndex, updatedTab);
            }
          },
        ),
        NavigationCardItem(
          icon: Icons.business,
          title: 'Organização',
          description: 'Configure dados da empresa e informações fiscais',
          onTap: () {
            final tabManager = TabManagerScope.maybeOf(context);
            if (tabManager != null) {
              final currentIndex = tabManager.currentIndex;
              final currentTab = tabManager.currentTab;
              final updatedTab = TabItem(
                id: 'organization_management',
                title: 'Gerenciar Organização',
                icon: Icons.business,
                page: const OrganizationManagementPage(),
                canClose: true,
                selectedMenuIndex: currentTab?.selectedMenuIndex ?? 9, // Configurações
              );
              tabManager.updateTab(currentIndex, updatedTab);
            }
          },
        ),
        NavigationCardItem(
          icon: Icons.notifications,
          title: 'Notificações',
          description: 'Configure suas preferências de notificação',
          onTap: () {
            // Funcionalidade em desenvolvimento
          },
        ),
        NavigationCardItem(
          icon: Icons.palette,
          title: 'Aparência',
          description: 'Personalize o tema e cores do aplicativo',
          onTap: () {
            // Funcionalidade em desenvolvimento
          },
        ),
        NavigationCardItem(
          icon: Icons.language,
          title: 'Idioma',
          description: 'Altere o idioma do aplicativo',
          onTap: () {
            // Funcionalidade em desenvolvimento
          },
        ),
        NavigationCardItem(
          icon: Icons.security,
          title: 'Segurança',
          description: 'Gerencie senha e autenticação',
          onTap: () {
            // Funcionalidade em desenvolvimento
          },
        ),
        NavigationCardItem(
          icon: Icons.storage,
          title: 'Armazenamento',
          description: 'Gerencie arquivos e espaço em disco',
          onTap: () {
            // Funcionalidade em desenvolvimento
          },
        ),
      ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            const Text(
              'Configurações',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Personalize sua experiência',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade500,
              ),
            ),
            const SizedBox(height: 32),

            // Grid de cards usando componente genérico
            NavigationCardsGrid(
              items: _configCards(context),
            ),
          ],
        ),
      ),
    );
  }
}

