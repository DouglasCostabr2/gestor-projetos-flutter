import 'package:flutter/material.dart';

/// SectionContainer
///
/// Container reutilizável para seções com o visual padrão do app
/// (mesmo usado no Briefing):
/// - Fundo: 0xFF1A1A1A
/// - Borda: 1px 0xFF2A2A2A
/// - Raio: 12px
/// - Padding: 16
///
/// Use para envolver conteúdos de seções (listas, formulários, seletores, etc.).
class SectionContainer extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final Color? backgroundColor;
  final Color? borderColor;

  const SectionContainer({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.borderRadius = 12,
    this.backgroundColor,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    // Mantemos os valores padrão idênticos ao estilo atual das seções
    const defaultBg = Color(0xFF1A1A1A);
    const defaultBorder = Color(0xFF2A2A2A);

    return Container(
      decoration: BoxDecoration(
        color: backgroundColor ?? defaultBg,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: borderColor ?? defaultBorder, width: 1),
      ),
      padding: padding,
      child: child,
    );
  }
}

