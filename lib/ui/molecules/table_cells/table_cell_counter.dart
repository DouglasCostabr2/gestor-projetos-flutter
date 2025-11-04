import 'package:flutter/material.dart';

/// Widget reutilizável para células de tabela com contador + ícone
/// 
/// Características:
/// - Ícone + número em layout horizontal
/// - Mostra "-" quando zero ou null
/// - Ícone configurável
/// - Espaçamento consistente
/// - Suporte a tooltip
/// 
/// Uso:
/// ```dart
/// // Em cellBuilders de tabelas
/// (item) => TableCellCounter(
///   count: item['total_tasks'],
///   icon: Icons.task_alt,
/// )
/// 
/// // Com tooltip
/// (item) => TableCellCounter(
///   count: item['total_people'],
///   icon: Icons.people,
///   tooltip: 'Total de pessoas',
/// )
/// 
/// // Mostrar zero
/// (item) => TableCellCounter(
///   count: item['total_items'],
///   icon: Icons.inventory,
///   hideZero: false,
/// )
/// ```
class TableCellCounter extends StatelessWidget {
  /// Valor do contador
  final int? count;
  
  /// Ícone a ser exibido
  final IconData icon;
  
  /// Tamanho do ícone
  final double iconSize;
  
  /// Texto a exibir quando count é null ou zero
  final String nullText;
  
  /// Se deve esconder quando count é zero
  final bool hideZero;
  
  /// Espaçamento entre ícone e número
  final double spacing;
  
  /// Estilo do texto do número
  final TextStyle? textStyle;
  
  /// Cor do ícone
  final Color? iconColor;
  
  /// Tooltip (opcional)
  final String? tooltip;

  const TableCellCounter({
    super.key,
    required this.count,
    required this.icon,
    this.iconSize = 16.0,
    this.nullText = '-',
    this.hideZero = true,
    this.spacing = 4.0,
    this.textStyle,
    this.iconColor,
    this.tooltip,
  });

  Widget _buildContent() {
    // Se count é null, mostrar texto null
    if (count == null) {
      return Text(nullText, style: textStyle);
    }
    
    // Se count é zero e hideZero = true, mostrar texto null
    if (count == 0 && hideZero) {
      return Text(nullText, style: textStyle);
    }
    
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: iconSize,
          color: iconColor,
        ),
        SizedBox(width: spacing),
        Text(
          count.toString(),
          style: textStyle,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final content = _buildContent();

    // Tooltip desabilitado para evitar erro de múltiplos tickers
    // if (tooltip != null) {
    //   return Tooltip(
    //     message: tooltip!,
    //     child: content,
    //   );
    // }

    return content;
  }
}

/// Variante que mostra apenas o número (sem ícone)
class TableCellNumber extends StatelessWidget {
  final int? count;
  final String nullText;
  final bool hideZero;
  final TextStyle? style;
  final String? tooltip;

  const TableCellNumber({
    super.key,
    required this.count,
    this.nullText = '-',
    this.hideZero = true,
    this.style,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    String text;

    if (count == null) {
      text = nullText;
    } else if (count == 0 && hideZero) {
      text = nullText;
    } else {
      text = count.toString();
    }

    final textWidget = Text(text, style: style);

    // Tooltip desabilitado para evitar erro de múltiplos tickers
    // if (tooltip != null) {
    //   return Tooltip(
    //     message: tooltip!,
    //     child: textWidget,
    //   );
    // }

    return textWidget;
  }
}

