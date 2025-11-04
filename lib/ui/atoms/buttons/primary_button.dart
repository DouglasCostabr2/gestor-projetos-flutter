import 'package:flutter/material.dart';

/// Botão primário para ações principais
///
/// Características:
/// - Background preenchido (FilledButton)
/// - Cor do tema global
/// - BorderRadius 12
/// - Suporta ícone opcional
/// - Loading state integrado
///
/// Exemplo de uso básico:
/// ```dart
/// PrimaryButton(
///   onPressed: _save,
///   label: 'Salvar',
/// )
/// ```
///
/// Exemplo com ícone:
/// ```dart
/// PrimaryButton(
///   onPressed: _create,
///   label: 'Criar Novo',
///   icon: Icons.add,
/// )
/// ```
///
/// Exemplo com loading:
/// ```dart
/// PrimaryButton(
///   onPressed: _saving ? null : _save,
///   label: 'Salvar',
///   isLoading: _saving,
/// )
/// ```
class PrimaryButton extends StatelessWidget {
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

  const PrimaryButton({
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

    final button = FilledButton(
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

