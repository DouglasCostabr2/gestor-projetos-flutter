import 'package:flutter/material.dart';
import '../../../ui/organisms/cards/navigation_cards_grid.dart';
import '../../navigation/tab_manager_scope.dart';
import '../../navigation/tab_item.dart';
import 'organization_management_page.dart';
import 'organization_members_page.dart';
import '../monitoring/user_monitoring_page.dart';
import '../finance/finance_page.dart';
import '../catalog/catalog_page.dart';
import '../clients/client_categories_page.dart';
import 'pages/fiscal_and_bank_page.dart';
import 'pages/invoice_settings_page.dart';
import 'pages/integrations_page.dart';

/// Página de Organização
///
/// Página inicial de organização com cards de navegação para diferentes seções.
class OrganizationPage extends StatelessWidget {
  const OrganizationPage({super.key});

  /// Lista de cards de organização
  List<NavigationCardItem> _organizationCards(BuildContext context) => [
        NavigationCardItem(
          icon: Icons.business,
          title: 'Gerenciar Organização',
          description: 'Configure dados básicos, endereço, contatos, membros e convites',
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
                selectedMenuIndex: currentTab?.selectedMenuIndex ?? 11, // Organização
              );
              tabManager.updateTab(currentIndex, updatedTab);
            }
          },
        ),
        NavigationCardItem(
          icon: Icons.people,
          title: 'Membros',
          description: 'Gerencie membros da organização e permissões',
          onTap: () {
            final tabManager = TabManagerScope.maybeOf(context);
            if (tabManager != null) {
              final currentIndex = tabManager.currentIndex;
              final currentTab = tabManager.currentTab;
              final updatedTab = TabItem(
                id: 'organization_members',
                title: 'Membros',
                icon: Icons.people,
                page: const OrganizationMembersPage(),
                canClose: true,
                selectedMenuIndex: currentTab?.selectedMenuIndex ?? 11, // Organização
              );
              tabManager.updateTab(currentIndex, updatedTab);
            }
          },
        ),
        NavigationCardItem(
          icon: Icons.monitor_heart,
          title: 'Monitoramento',
          description: 'Monitore atividades e status dos usuários',
          onTap: () {
            final tabManager = TabManagerScope.maybeOf(context);
            if (tabManager != null) {
              final currentIndex = tabManager.currentIndex;
              final currentTab = tabManager.currentTab;
              final updatedTab = TabItem(
                id: 'user_monitoring',
                title: 'Monitoramento',
                icon: Icons.monitor_heart,
                page: const UserMonitoringPage(),
                canClose: true,
                selectedMenuIndex: currentTab?.selectedMenuIndex ?? 11, // Organização
              );
              tabManager.updateTab(currentIndex, updatedTab);
            }
          },
        ),
        NavigationCardItem(
          icon: Icons.account_balance_wallet,
          title: 'Financeiro',
          description: 'Gerencie pagamentos de clientes e funcionários',
          onTap: () {
            final tabManager = TabManagerScope.maybeOf(context);
            if (tabManager != null) {
              final currentIndex = tabManager.currentIndex;
              final currentTab = tabManager.currentTab;
              final updatedTab = TabItem(
                id: 'finance',
                title: 'Financeiro',
                icon: Icons.account_balance_wallet,
                page: const FinancePage(),
                canClose: true,
                selectedMenuIndex: currentTab?.selectedMenuIndex ?? 11, // Organização
              );
              tabManager.updateTab(currentIndex, updatedTab);
            }
          },
        ),
        NavigationCardItem(
          icon: Icons.storefront,
          title: 'Catálogo',
          description: 'Gerencie produtos, pacotes e categorias',
          onTap: () {
            final tabManager = TabManagerScope.maybeOf(context);
            if (tabManager != null) {
              final currentIndex = tabManager.currentIndex;
              final currentTab = tabManager.currentTab;
              final updatedTab = TabItem(
                id: 'catalog',
                title: 'Catálogo',
                icon: Icons.storefront,
                page: const CatalogPage(),
                canClose: true,
                selectedMenuIndex: currentTab?.selectedMenuIndex ?? 11, // Organização
              );
              tabManager.updateTab(currentIndex, updatedTab);
            }
          },
        ),
        NavigationCardItem(
          icon: Icons.category,
          title: 'Categorias de Clientes',
          description: 'Gerencie categorias para organizar clientes',
          onTap: () {
            final tabManager = TabManagerScope.maybeOf(context);
            if (tabManager != null) {
              final currentIndex = tabManager.currentIndex;
              final currentTab = tabManager.currentTab;
              final updatedTab = TabItem(
                id: 'client_categories',
                title: 'Categorias de Clientes',
                icon: Icons.category,
                page: const ClientCategoriesPage(),
                canClose: true,
                selectedMenuIndex: currentTab?.selectedMenuIndex ?? 11, // Organização
              );
              tabManager.updateTab(currentIndex, updatedTab);
            }
          },
        ),
        NavigationCardItem(
          icon: Icons.account_balance,
          title: 'Dados Fiscais e Bancários',
          description: 'Gerencie informações fiscais, tributárias e bancárias',
          onTap: () {
            final tabManager = TabManagerScope.maybeOf(context);
            if (tabManager != null) {
              final currentIndex = tabManager.currentIndex;
              final currentTab = tabManager.currentTab;
              final updatedTab = TabItem(
                id: 'fiscal_and_bank',
                title: 'Dados Fiscais e Bancários',
                icon: Icons.account_balance,
                page: const FiscalAndBankPage(),
                canClose: true,
                selectedMenuIndex: currentTab?.selectedMenuIndex ?? 11,
              );
              tabManager.updateTab(currentIndex, updatedTab);
            }
          },
        ),
        NavigationCardItem(
          icon: Icons.integration_instructions,
          title: 'Integrações',
          description: 'Gerencie integrações com serviços externos (Google Drive, etc)',
          onTap: () {
            final tabManager = TabManagerScope.maybeOf(context);
            if (tabManager != null) {
              final currentIndex = tabManager.currentIndex;
              final currentTab = tabManager.currentTab;
              final updatedTab = TabItem(
                id: 'integrations',
                title: 'Integrações',
                icon: Icons.integration_instructions,
                page: const IntegrationsPage(),
                canClose: true,
                selectedMenuIndex: currentTab?.selectedMenuIndex ?? 11,
              );
              tabManager.updateTab(currentIndex, updatedTab);
            }
          },
        ),
        NavigationCardItem(
          icon: Icons.description,
          title: 'Configurações de Invoice',
          description: 'Defina prefixos, numeração e termos de pagamento',
          onTap: () {
            final tabManager = TabManagerScope.maybeOf(context);
            if (tabManager != null) {
              final currentIndex = tabManager.currentIndex;
              final currentTab = tabManager.currentTab;
              final updatedTab = TabItem(
                id: 'invoice_settings',
                title: 'Configurações de Invoice',
                icon: Icons.description,
                page: const InvoiceSettingsPage(),
                canClose: true,
                selectedMenuIndex: currentTab?.selectedMenuIndex ?? 11,
              );
              tabManager.updateTab(currentIndex, updatedTab);
            }
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
              'Organização',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Gerencie sua organização e configurações empresariais',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade500,
              ),
            ),
            const SizedBox(height: 32),

            // Grid de cards usando componente genérico
            NavigationCardsGrid(
              items: _organizationCards(context),
            ),
          ],
        ),
      ),
    );
  }
}
