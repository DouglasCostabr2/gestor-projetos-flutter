import 'package:flutter/material.dart';

/// Botão com ícone e texto (variante tonal)
///
/// Características:
/// - Background tonal (FilledButton.tonal)
/// - Ícone + texto
/// - Cor do tema global
/// - BorderRadius 12
/// - Loading state integrado
///
/// Exemplo de uso:
/// ```dart
/// IconTextButton(
///   onPressed: _addItem,
///   icon: Icons.add,
///   label: 'Adicionar Item',
/// )
/// ```
///
/// Exemplo com loading:
/// ```dart
/// IconTextButton(
///   onPressed: _loading ? null : _load,
///   icon: Icons.refresh,
///   label: 'Recarregar',
///   isLoading: _loading,
/// )
/// ```
class IconTextButton extends StatelessWidget {
  /// Callback quando o botão é pressionado
  final VoidCallback? onPressed;

  /// Ícone do botão
  final IconData icon;

  /// Texto do botão
  final String label;

  /// Se está em estado de loading
  final bool isLoading;

  /// Tamanho do ícone
  final double iconSize;

  /// Largura customizada (null = ajusta ao conteúdo)
  final double? width;

  /// Altura customizada
  final double? height;

  /// Estilo do texto
  final TextStyle? textStyle;

  const IconTextButton({
    super.key,
    required this.onPressed,
    required this.icon,
    required this.label,
    this.isLoading = false,
    this.iconSize = 20,
    this.width,
    this.height,
    this.textStyle,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveOnPressed = isLoading ? null : onPressed;

    Widget child;
    if (isLoading) {
      child = const SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    } else {
      child = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: iconSize),
          const SizedBox(width: 8),
          Text(label, style: textStyle),
        ],
      );
    }

    final button = FilledButton.tonal(
      onPressed: effectiveOnPressed,
      child: child,
    );

    if (width != null || height != null) {
      return SizedBox(
        width: width,
        height: height,
        child: button,
      );
    }

    return button;
  }
}

