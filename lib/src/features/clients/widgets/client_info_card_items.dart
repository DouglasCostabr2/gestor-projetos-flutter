import 'package:flutter/material.dart';
import 'package:my_business/ui/organisms/cards/cards.dart';
import 'package:my_business/ui/atoms/badges/status_badge.dart';

/// Widgets auxiliares para construir os itens dos cards de informações do cliente
class ClientInfoCardItems {
  ClientInfoCardItems._(); // Private constructor - utility class

  /// Cria o item "Nome do Cliente" com avatar
  static InfoCardItem buildClientNameItem(
    BuildContext context,
    Map<String, dynamic> client,
  ) {
    final avatarUrl = client['avatar_url'] as String?;
    final name = client['name'] ?? 'Sem nome';

    return InfoCardItem(
      label: 'Nome do Cliente',
      labelContentSpacing: 18,
      content: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 12,
            backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty
                ? NetworkImage(avatarUrl)
                : null,
            child: avatarUrl == null || avatarUrl.isEmpty
                ? const Icon(Icons.person, size: 12)
                : null,
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              name,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  /// Cria o item "Categoria"
  static InfoCardItem buildCategoryItem(
    BuildContext context,
    Map<String, dynamic> client,
  ) {
    final category = client['client_categories']?['name'] ??
        client['category'] ??
        '-';

    return InfoCardItem(
      label: 'Categoria',
      content: Text(
        category,
        style: Theme.of(context).textTheme.bodySmall,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  /// Cria o item "Status"
  static InfoCardItem buildStatusItem(Map<String, dynamic> client) {
    return InfoCardItem(
      label: 'Status',
      content: StatusBadge(
        status: client['status'] ?? 'nao_prospectado',
      ),
    );
  }

  /// Cria o item "Telefone" (clicável para WhatsApp)
  static InfoCardItem buildPhoneItem(
    BuildContext context,
    Map<String, dynamic> client,
  ) {
    final phone = client['phone'] as String?;

    return InfoCardItem(
      label: 'Telefone',
      content: phone != null && phone.isNotEmpty
          ? GestureDetector(
              onTap: () => InfoCardItemsHelpers.openWhatsApp(context, phone),
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.phone, size: 14, color: Colors.white),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        phone,
                        style: Theme.of(context).textTheme.bodySmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            )
          : Text(
              '-',
              style: Theme.of(context).textTheme.bodySmall,
            ),
    );
  }

  /// Cria um item genérico de texto simples
  static InfoCardItem _buildTextItem(
    BuildContext context,
    String label,
    String? value,
  ) {
    return InfoCardItem(
      label: label,
      content: Text(
        value ?? '-',
        style: Theme.of(context).textTheme.bodySmall,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  /// Cria o item "País"
  static InfoCardItem buildCountryItem(
    BuildContext context,
    Map<String, dynamic> client,
  ) {
    return _buildTextItem(context, 'País', client['country'] as String?);
  }

  /// Cria o item "Estado"
  static InfoCardItem buildStateItem(
    BuildContext context,
    Map<String, dynamic> client,
  ) {
    return _buildTextItem(context, 'Estado', client['state'] as String?);
  }

  /// Cria o item "Cidade"
  static InfoCardItem buildCityItem(
    BuildContext context,
    Map<String, dynamic> client,
  ) {
    return _buildTextItem(context, 'Cidade', client['city'] as String?);
  }

  /// Cria o item "Notas/Observações"
  static InfoCardItem buildNotesItem(
    BuildContext context,
    Map<String, dynamic> client,
  ) {
    final notes = client['notes'] as String?;

    return InfoCardItem(
      label: 'Notas/Observações',
      useExpanded: true,
      widthCalculator: (itemsPerRow, adjustedItemWidth) => adjustedItemWidth,
      content: Text(
        notes != null && notes.isNotEmpty ? notes : '-',
        style: Theme.of(context).textTheme.bodySmall,
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  /// Cria o item "Mais Informações" (botão expansível)
  static InfoCardItem buildMoreInfoButton({required VoidCallback? onTap}) {
    return InfoCardItem(
      label: '',
      labelContentSpacing: 12,
      widthCalculator: (itemsPerRow, adjustedItemWidth) => itemsPerRow >= 2 ? null : adjustedItemWidth,
      minWidthCalculator: (itemsPerRow) => itemsPerRow >= 2 ? 0 : 120,
      rightPaddingCalculator: (itemsPerRow) => itemsPerRow >= 2 ? 0 : 20,
      mainAxisSize: MainAxisSize.max,
      mainAxisAlignment: MainAxisAlignment.center,
      content: Material(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: const SizedBox(
            width: 40,
            height: 40,
            child: Icon(
              Icons.info_outline,
              size: 20,
              color: Colors.white70,
            ),
          ),
        ),
      ),
    );
  }
}

