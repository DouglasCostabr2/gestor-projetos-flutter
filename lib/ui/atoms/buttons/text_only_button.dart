import 'package:flutter/material.dart';

/// Botão de texto para ações terciárias
///
/// Características:
/// - Apenas texto (TextButton)
/// - Sem background
/// - Cor do tema global
/// - BorderRadius 12
/// - Suporta ícone opcional
/// - Loading state integrado
///
/// Exemplo de uso básico:
/// ```dart
/// TextOnlyButton(
///   onPressed: () => Navigator.pop(context),
///   label: 'Cancelar',
/// )
/// ```
///
/// Exemplo com ícone:
/// ```dart
/// TextOnlyButton(
///   onPressed: _viewDetails,
///   label: 'Ver Detalhes',
///   icon: Icons.arrow_forward,
/// )
/// ```
class TextOnlyButton extends StatelessWidget {
  /// Callback quando o botão é pressionado
  final VoidCallback? onPressed;

  /// Texto do botão
  final String label;

  /// Ícone opcional (aparece antes do texto)
  final IconData? icon;

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

  const TextOnlyButton({
    super.key,
    required this.onPressed,
    required this.label,
    this.icon,
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
    } else if (icon != null) {
      child = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: iconSize),
          const SizedBox(width: 8),
          Text(label, style: textStyle),
        ],
      );
    } else {
      child = Text(label, style: textStyle);
    }

    final button = TextButton(
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

