import 'package:flutter/material.dart';

/// Botão apenas com ícone (sem texto)
///
/// Características:
/// - Apenas ícone (IconButton)
/// - Sem texto
/// - Cor do tema global
/// - Tamanho customizável
/// - Loading state integrado
/// - Tooltip opcional
/// - Variantes: standard, filled, tonal, outlined
///
/// Exemplo de uso básico:
/// ```dart
/// IconOnlyButton(
///   onPressed: _edit,
///   icon: Icons.edit,
///   tooltip: 'Editar',
/// )
/// ```
///
/// Exemplo com variante filled:
/// ```dart
/// IconOnlyButton(
///   onPressed: _delete,
///   icon: Icons.delete,
///   tooltip: 'Excluir',
///   variant: IconButtonVariant.filled,
/// )
/// ```
///
/// Exemplo com loading:
/// ```dart
/// IconOnlyButton(
///   onPressed: _loading ? null : _refresh,
///   icon: Icons.refresh,
///   tooltip: 'Recarregar',
///   isLoading: _loading,
/// )
/// ```
enum IconButtonVariant {
  /// Botão padrão (sem background)
  standard,

  /// Botão com background preenchido
  filled,

  /// Botão com background tonal
  tonal,

  /// Botão com outline
  outlined,
}

class IconOnlyButton extends StatelessWidget {
  /// Callback quando o botão é pressionado
  final VoidCallback? onPressed;

  /// Ícone do botão
  final IconData icon;

  /// Tooltip (texto de ajuda ao passar o mouse)
  final String? tooltip;

  /// Se está em estado de loading
  final bool isLoading;

  /// Tamanho do ícone
  final double iconSize;

  /// Variante do botão
  final IconButtonVariant variant;

  /// Cor customizada do ícone (null = cor do tema)
  final Color? iconColor;

  /// Cor customizada do background (null = cor do tema)
  final Color? backgroundColor;

  /// Padding customizado
  final EdgeInsetsGeometry? padding;

  const IconOnlyButton({
    super.key,
    required this.onPressed,
    required this.icon,
    this.tooltip,
    this.isLoading = false,
    this.iconSize = 20,
    this.variant = IconButtonVariant.standard,
    this.iconColor,
    this.backgroundColor,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveOnPressed = isLoading ? null : onPressed;

    Widget button;

    if (isLoading) {
      // Loading state: mostra CircularProgressIndicator
      button = SizedBox(
        width: iconSize + 16,
        height: iconSize + 16,
        child: Center(
          child: SizedBox(
            width: iconSize * 0.8,
            height: iconSize * 0.8,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: iconColor,
            ),
          ),
        ),
      );
    } else {
      // Normal state: mostra o ícone
      switch (variant) {
        case IconButtonVariant.standard:
          button = IconButton(
            onPressed: effectiveOnPressed,
            icon: Icon(icon, size: iconSize),
            color: iconColor,
            padding: padding,
          );
          break;

        case IconButtonVariant.filled:
          button = IconButton.filled(
            onPressed: effectiveOnPressed,
            icon: Icon(icon, size: iconSize),
            color: iconColor,
            style: backgroundColor != null
                ? IconButton.styleFrom(backgroundColor: backgroundColor)
                : null,
            padding: padding,
          );
          break;

        case IconButtonVariant.tonal:
          button = IconButton.filledTonal(
            onPressed: effectiveOnPressed,
            icon: Icon(icon, size: iconSize),
            color: iconColor,
            style: backgroundColor != null
                ? IconButton.styleFrom(backgroundColor: backgroundColor)
                : null,
            padding: padding,
          );
          break;

        case IconButtonVariant.outlined:
          button = IconButton.outlined(
            onPressed: effectiveOnPressed,
            icon: Icon(icon, size: iconSize),
            color: iconColor,
            padding: padding,
          );
          break;
      }
    }

    // Tooltip desabilitado para evitar erro de múltiplos tickers
    // if (tooltip != null && tooltip!.isNotEmpty) {
    //   return Tooltip(
    //     message: tooltip!,
    //     child: button,
    //   );
    // }

    return button;
  }
}

