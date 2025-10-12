import 'package:flutter/material.dart';

/// Botão com outline customizado (background escuro e borda)
///
/// Características:
/// - Background escuro (#1E1E1E)
/// - Borda sutil (#3E3E3E)
/// - Texto branco
/// - BorderRadius 8
/// - Suporta ícone opcional
/// - Design consistente para ações em lote e seleções
///
/// Exemplo de uso básico:
/// ```dart
/// OutlineButton(
///   onPressed: _deleteSelected,
///   label: '3 selecionados',
///   icon: Icons.delete,
/// )
/// ```
///
/// Exemplo com contador dinâmico:
/// ```dart
/// OutlineButton(
///   onPressed: _deleteSelected,
///   label: '$selectedCount selecionado${selectedCount > 1 ? 's' : ''}',
///   icon: Icons.delete,
/// )
/// ```
class OutlineButton extends StatelessWidget {
  /// Callback quando o botão é pressionado
  final VoidCallback? onPressed;

  /// Texto do botão
  final String label;

  /// Ícone opcional (aparece depois do texto)
  final IconData? icon;

  /// Tamanho do ícone
  final double iconSize;

  /// Cor de fundo customizada (padrão: #1E1E1E)
  final Color? backgroundColor;

  /// Cor da borda customizada (padrão: #3E3E3E)
  final Color? borderColor;

  /// Cor do texto e ícone (padrão: branco)
  final Color? foregroundColor;

  const OutlineButton({
    super.key,
    required this.onPressed,
    required this.label,
    this.icon,
    this.iconSize = 20,
    this.backgroundColor,
    this.borderColor,
    this.foregroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveBackgroundColor = backgroundColor ?? const Color(0xFF1E1E1E);
    final effectiveBorderColor = borderColor ?? const Color(0xFF3E3E3E);
    final effectiveForegroundColor = foregroundColor ?? Colors.white;

    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: effectiveBackgroundColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: effectiveBorderColor,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: effectiveForegroundColor,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (icon != null) ...[
              const SizedBox(width: 12),
              Icon(
                icon,
                color: effectiveForegroundColor,
                size: iconSize,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

