import 'package:flutter/material.dart';
import '../../molecules/cards/navigation_card.dart';

/// Item de configuração para o grid de navegação
class NavigationCardItem {
  /// Ícone do card
  final IconData icon;
  
  /// Título do card
  final String title;
  
  /// Descrição do card
  final String description;
  
  /// Callback ao clicar no card
  final VoidCallback onTap;

  const NavigationCardItem({
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
  });
}

/// Grid responsivo de cards de navegação
/// 
/// Componente genérico que exibe uma lista de NavigationCard em um grid responsivo.
/// O número de colunas se adapta automaticamente à largura disponível.
/// 
/// Características:
/// - Grid responsivo (1-4 colunas)
/// - Cards com largura e altura fixas
/// - Espaçamento configurável
/// - Aspect ratio mantido
/// 
/// Exemplo de uso:
/// ```dart
/// NavigationCardsGrid(
///   items: [
///     NavigationCardItem(
///       icon: Icons.settings,
///       title: 'Configurações',
///       description: 'Gerencie suas preferências',
///       onTap: () => print('Configurações'),
///     ),
///     // ... mais itens
///   ],
/// )
/// ```
class NavigationCardsGrid extends StatelessWidget {
  /// Lista de itens a serem exibidos no grid
  final List<NavigationCardItem> items;
  
  /// Largura de cada card (padrão: 280)
  final double cardWidth;
  
  /// Altura de cada card (padrão: 160)
  final double cardHeight;
  
  /// Espaçamento entre cards (padrão: 16)
  final double spacing;
  
  /// Número mínimo de colunas (padrão: 1)
  final int minColumns;
  
  /// Número máximo de colunas (padrão: 4)
  final int maxColumns;
  
  /// Cor de fundo dos cards
  final Color? cardBackgroundColor;
  
  /// Cor da borda dos cards
  final Color? cardBorderColor;
  
  /// Cor da borda ao fazer hover
  final Color? cardHoverBorderColor;
  
  /// Cor de fundo do container do ícone
  final Color? iconBackgroundColor;
  
  /// Cor do ícone
  final Color? iconColor;
  
  /// Cor do título
  final Color? titleColor;
  
  /// Cor da descrição
  final Color? descriptionColor;

  const NavigationCardsGrid({
    super.key,
    required this.items,
    this.cardWidth = 280,
    this.cardHeight = 160,
    this.spacing = 16,
    this.minColumns = 1,
    this.maxColumns = 4,
    this.cardBackgroundColor,
    this.cardBorderColor,
    this.cardHoverBorderColor,
    this.iconBackgroundColor,
    this.iconColor,
    this.titleColor,
    this.descriptionColor,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const SizedBox.shrink();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        // Calcular número de colunas baseado na largura disponível
        final columns = (constraints.maxWidth / (cardWidth + spacing))
            .floor()
            .clamp(minColumns, maxColumns);

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: spacing,
            mainAxisSpacing: spacing,
            childAspectRatio: cardWidth / cardHeight,
          ),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            return NavigationCard(
              icon: item.icon,
              title: item.title,
              description: item.description,
              onTap: item.onTap,
              backgroundColor: cardBackgroundColor,
              borderColor: cardBorderColor,
              hoverBorderColor: cardHoverBorderColor,
              iconBackgroundColor: iconBackgroundColor,
              iconColor: iconColor,
              titleColor: titleColor,
              descriptionColor: descriptionColor,
            );
          },
        );
      },
    );
  }
}

