import 'package:flutter/material.dart';

/// Botão de ação destrutiva (excluir, cancelar permanentemente)
///
/// Características:
/// - Background vermelho
/// - Texto branco
/// - BorderRadius 12
/// - Suporta ícone opcional
/// - Loading state integrado
/// - Confirmação visual clara
///
/// Exemplo de uso básico:
/// ```dart
/// DangerButton(
///   onPressed: _delete,
///   label: 'Excluir',
/// )
/// ```
///
/// Exemplo com ícone:
/// ```dart
/// DangerButton(
///   onPressed: _deleteAll,
///   label: 'Excluir Todos',
///   icon: Icons.delete_forever,
/// )
/// ```
class DangerButton extends StatelessWidget {
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

  /// Se deve usar outline em vez de filled
  final bool outlined;

  const DangerButton({
    super.key,
    required this.onPressed,
    required this.label,
    this.icon,
    this.isLoading = false,
    this.iconSize = 20,
    this.width,
    this.height,
    this.textStyle,
    this.outlined = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveOnPressed = isLoading ? null : onPressed;

    Widget child;
    if (isLoading) {
      child = SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: outlined ? theme.colorScheme.error : Colors.white,
        ),
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

    if (outlined) {
      // Outlined danger button
      final button = OutlinedButton(
        onPressed: effectiveOnPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: theme.colorScheme.error,
          side: BorderSide(color: theme.colorScheme.error),
        ),
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
    } else {
      // Filled danger button
      final button = FilledButton(
        onPressed: effectiveOnPressed,
        style: FilledButton.styleFrom(
          backgroundColor: theme.colorScheme.error,
          foregroundColor: Colors.white,
        ),
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
}

