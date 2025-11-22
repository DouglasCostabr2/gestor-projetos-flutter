import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:my_business/ui/organisms/cards/cards.dart';
import '../../../src/navigation/tab_manager_scope.dart';
import '../../../src/navigation/tab_item.dart';
import '../../../src/features/clients/client_detail_page.dart';

/// Helpers compartilhados para construir itens de InfoCard
/// 
/// Esta classe contém métodos reutilizáveis que são comuns entre diferentes
/// páginas de detalhes (projetos, empresas, etc.)
class InfoCardItemsHelpers {
  InfoCardItemsHelpers._(); // Private constructor - utility class

  /// Cria o item "Cliente" (clicável com avatar)
  /// 
  /// Este método é compartilhado entre ProjectInfoCardItems e CompanyInfoCardItems
  /// para manter consistência e evitar duplicação de código.
  static InfoCardItem buildClientItem(
    BuildContext context,
    String? clientId,
    String clientName,
    String? clientAvatarUrl, {
    bool canNavigate = true,
  }) {
    // Widget de conteúdo (avatar + nome)
    final contentWidget = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (clientAvatarUrl != null && clientAvatarUrl.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: CircleAvatar(
              radius: 12,
              backgroundImage: NetworkImage(clientAvatarUrl),
            ),
          ),
        Flexible(
          child: Text(
            clientName,
            style: Theme.of(context).textTheme.bodySmall,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );

    return InfoCardItem(
      label: 'Cliente',
      labelContentSpacing: 18,
      content: clientId != null && canNavigate
          ? GestureDetector(
              onTap: () => navigateToClient(context, clientId, clientName),
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: contentWidget,
              ),
            )
          : contentWidget,
    );
  }

  /// Navega para a página de detalhes do cliente
  ///
  /// Este método é compartilhado entre ProjectInfoCardItems e CompanyInfoCardItems
  /// para manter consistência de navegação.
  static void navigateToClient(BuildContext context, String clientId, String clientName) {
    final tabManager = TabManagerScope.maybeOf(context);
    if (tabManager != null) {
      final currentIndex = tabManager.currentIndex;
      final tabId = 'client_$clientId';
      final updatedTab = TabItem(
        id: tabId,
        title: clientName,
        icon: Icons.person,
        page: ClientDetailPage(
          key: ValueKey(tabId),
          clientId: clientId,
        ),
        canClose: true,
        selectedMenuIndex: 1, // Índice do menu de Clientes
      );
      tabManager.updateTab(currentIndex, updatedTab);
    }
  }

  /// Abre o WhatsApp com o número de telefone
  ///
  /// Este método é compartilhado para evitar duplicação de código.
  /// Remove caracteres não numéricos do telefone e abre o WhatsApp Web/App.
  static Future<void> openWhatsApp(BuildContext context, String phone) async {
    // Remove caracteres não numéricos
    final cleanPhone = phone.replaceAll(RegExp(r'[^\d+]'), '');
    final url = Uri.parse('https://wa.me/$cleanPhone');

    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível abrir o WhatsApp')),
      );
    }
  }
}

