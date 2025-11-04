import 'package:flutter/material.dart';

/// Modelo de dados para um item de informação em um InfoCard
class InfoCardItem {
  /// Label do item (ex: "Nome da Tarefa", "Prioridade")
  final String label;

  /// Widget de conteúdo do item
  final Widget content;

  /// Função para calcular largura do item baseado em itemsPerRow e adjustedItemWidth
  /// Se null, usa adjustedItemWidth
  /// Se retorna null, usa "hug" (sem largura fixa)
  final double? Function(int itemsPerRow, double adjustedItemWidth)? widthCalculator;

  /// Função para calcular largura mínima baseado em itemsPerRow
  /// Se null, usa minWidth padrão
  final double Function(int itemsPerRow)? minWidthCalculator;

  /// Largura mínima padrão do item
  final double minWidth;

  /// Função para calcular padding direito baseado em itemsPerRow
  /// Se null, usa rightPadding padrão
  final double Function(int itemsPerRow)? rightPaddingCalculator;

  /// Padding direito padrão do item
  final double rightPadding;

  /// Altura do item
  final double height;

  /// Espaçamento entre label e conteúdo
  final double labelContentSpacing;

  /// CrossAxisAlignment do Column
  final CrossAxisAlignment crossAxisAlignment;

  /// MainAxisSize do Column
  final MainAxisSize mainAxisSize;

  /// MainAxisAlignment do Column (opcional)
  final MainAxisAlignment? mainAxisAlignment;

  /// Se este item deve usar Expanded quando em Row (apenas para um item por card)
  final bool useExpanded;

  const InfoCardItem({
    required this.label,
    required this.content,
    this.widthCalculator,
    this.minWidthCalculator,
    this.minWidth = 120,
    this.rightPaddingCalculator,
    this.rightPadding = 20,
    this.height = 60,
    this.labelContentSpacing = 20,
    this.crossAxisAlignment = CrossAxisAlignment.start,
    this.mainAxisSize = MainAxisSize.min,
    this.mainAxisAlignment,
    this.useExpanded = false,
  });
}

/// Card genérico para exibir informações em layout responsivo
class InfoCard extends StatelessWidget {
  /// Lista de itens a serem exibidos no card
  final List<InfoCardItem> items;

  /// Largura mínima do card
  final double minWidth;

  /// Altura mínima do card
  final double minHeight;

  /// Número total de itens (usado para calcular quando usar Row vs Wrap)
  final int totalItems;

  /// Se deve forçar 2 itens por linha quando só cabem 3
  final bool force2ItemsWhen3Fit;

  /// Callback para calcular tamanho após renderização
  final void Function(Size size)? onSizeCalculated;

  /// Emoji para debug log
  final String debugEmoji;

  /// Descrição para debug log
  final String debugDescription;

  const InfoCard({
    super.key,
    required this.items,
    this.minWidth = 300,
    this.minHeight = 104,
    required this.totalItems,
    this.force2ItemsWhen3Fit = true,
    this.onSizeCalculated,
    this.debugEmoji = '📝',
    this.debugDescription = 'InfoCard',
  });

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(
        minWidth: minWidth,
        minHeight: minHeight,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Log da altura do ConstrainedBox após renderização
          if (onSizeCalculated != null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              final renderBox = context.findRenderObject() as RenderBox?;
              if (renderBox != null) {
                debugPrint('$debugEmoji ALTURA DA DIV ($debugDescription): ${renderBox.size.height}px');
                debugPrint('$debugEmoji LARGURA DA DIV ($debugDescription): ${renderBox.size.width}px');
                onSizeCalculated!(renderBox.size);
              }
            });
          }

          return Card(
            clipBehavior: Clip.hardEdge,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: Colors.grey.withValues(alpha: 0.15),
                width: 1,
              ),
            ),
            child: Container(
              constraints: BoxConstraints(
                minHeight: minHeight,
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    // Calcular largura de cada item baseado no espaço disponível
                    final availableWidth = constraints.maxWidth;
                    const minItemWidth = 120.0;
                    final itemsPerRow = (availableWidth / minItemWidth).floor().clamp(1, totalItems);

                    // Lógica: se só cabem 3 itens por linha, forçar 2 itens por linha
                    final adjustedItemsPerRow = (force2ItemsWhen3Fit && itemsPerRow == 3) ? 2 : itemsPerRow;
                    final adjustedItemWidth = availableWidth / adjustedItemsPerRow;

                    // LOG: Informações de cálculo
                    debugPrint('$debugEmoji ========== CÁLCULO DE LARGURA ($debugDescription) ==========');
                    debugPrint('$debugEmoji Largura disponível: $availableWidth');
                    debugPrint('$debugEmoji Total de itens: $totalItems');
                    debugPrint('$debugEmoji Itens por linha (calculado): $itemsPerRow');
                    debugPrint('$debugEmoji Itens por linha (ajustado): $adjustedItemsPerRow');
                    debugPrint('$debugEmoji Largura ajustada por item: $adjustedItemWidth');

                    // Construir lista de widgets com larguras calculadas
                    int itemIndex = 0;
                    final widgets = items.map((item) {
                      itemIndex++;

                      // Calcular largura do item
                      final itemWidth = item.widthCalculator != null
                          ? item.widthCalculator!(itemsPerRow, adjustedItemWidth)
                          : adjustedItemWidth;

                      // LOG: Largura de cada item
                      debugPrint('$debugEmoji Item $itemIndex ("${item.label}"): largura = ${itemWidth ?? "null (hug content)"}');

                      // Calcular largura mínima do item
                      final itemMinWidth = item.minWidthCalculator != null
                          ? item.minWidthCalculator!(itemsPerRow)
                          : item.minWidth;

                      // Calcular padding direito do item
                      final itemRightPadding = item.rightPaddingCalculator != null
                          ? item.rightPaddingCalculator!(itemsPerRow)
                          : item.rightPadding;

                      final columnWidget = Column(
                        crossAxisAlignment: item.crossAxisAlignment,
                        mainAxisSize: item.mainAxisSize,
                        mainAxisAlignment: item.mainAxisAlignment ?? MainAxisAlignment.start,
                        children: [
                          Text(
                            item.label,
                            style: Theme.of(context).textTheme.labelSmall,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          SizedBox(height: item.labelContentSpacing),
                          item.content,
                        ],
                      );

                      final itemWidget = SizedBox(
                        width: itemWidth,
                        child: Container(
                          constraints: BoxConstraints(
                            minWidth: itemMinWidth,
                          ),
                          child: Padding(
                            padding: EdgeInsets.only(right: itemRightPadding),
                            child: SizedBox(
                              height: item.height,
                              child: columnWidget,
                            ),
                          ),
                        ),
                      );

                      // Se o item deve usar Expanded E estamos em modo Row (todos os itens cabem)
                      if (item.useExpanded && itemsPerRow >= totalItems) {
                        return Expanded(
                          child: Container(
                            constraints: BoxConstraints(
                              minWidth: itemMinWidth,
                            ),
                            child: Padding(
                              padding: EdgeInsets.only(right: itemRightPadding),
                              child: SizedBox(
                                height: item.height,
                                child: columnWidget,
                              ),
                            ),
                          ),
                        );
                      }

                      return itemWidget;
                    }).toList();

                    // Quando todos os itens cabem na mesma linha, usar Row
                    if (itemsPerRow >= totalItems) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: widgets,
                      );
                    }

                    // Quando os itens não cabem todos na mesma linha, usar Wrap
                    return Wrap(
                      alignment: WrapAlignment.start,
                      spacing: 0,
                      runSpacing: 24,
                      crossAxisAlignment: WrapCrossAlignment.start,
                      children: widgets,
                    );
                  },
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Seção com dois InfoCards lado a lado
class InfoCardsSection extends StatelessWidget {
  /// Card da esquerda
  final InfoCard leftCard;

  /// Card da direita
  final InfoCard rightCard;

  /// Espaçamento entre os cards
  final double spacing;

  const InfoCardsSection({
    super.key,
    required this.leftCard,
    required this.rightCard,
    this.spacing = 12,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth;
        final totalMinWidth = leftCard.minWidth + spacing + rightCard.minWidth;

        // Se não há espaço suficiente para ambos os cards com largura mínima,
        // usar Column em vez de Row
        if (availableWidth < totalMinWidth) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ConstrainedBox(
                constraints: BoxConstraints(minWidth: leftCard.minWidth),
                child: leftCard,
              ),
              SizedBox(height: spacing),
              ConstrainedBox(
                constraints: BoxConstraints(minWidth: rightCard.minWidth),
                child: rightCard,
              ),
            ],
          );
        }

        // Se há espaço suficiente, usar Row com Expanded
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ConstrainedBox(
                constraints: BoxConstraints(minWidth: leftCard.minWidth),
                child: leftCard,
              ),
            ),
            SizedBox(width: spacing),
            Expanded(
              child: ConstrainedBox(
                constraints: BoxConstraints(minWidth: rightCard.minWidth),
                child: rightCard,
              ),
            ),
          ],
        );
      },
    );
  }
}

