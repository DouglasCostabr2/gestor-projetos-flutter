import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Badge clicável para exibir links (URLs)
///
/// Características:
/// - Ícone de link do lado esquerdo
/// - Fundo escuro com borda
/// - Cursor muda para ponteiro ao passar o mouse
/// - Clique abre a URL no navegador externo
/// - Seleção de texto desabilitada (não interfere com clique)
///
/// Exemplo de uso:
/// ```dart
/// LinkBadge(
///   url: 'https://exemplo.com',
///   textStyle: TextStyle(fontSize: 14, color: Colors.white),
/// )
/// ```
class LinkBadge extends StatelessWidget {
  final String url;
  final TextStyle? textStyle;
  final Color? backgroundColor;
  final Color? borderColor;
  final Color? iconColor;
  final double? iconSize;
  final EdgeInsetsGeometry? padding;
  final BorderRadius? borderRadius;

  const LinkBadge({
    super.key,
    required this.url,
    this.textStyle,
    this.backgroundColor,
    this.borderColor,
    this.iconColor,
    this.iconSize,
    this.padding,
    this.borderRadius,
  });

  Future<void> _launchUrl() async {
    try {
      final Uri uri = Uri.parse(url);
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      // Ignorar erro (operação não crítica)
    }
  }

  @override
  Widget build(BuildContext context) {
    final defaultTextStyle = textStyle ??
        const TextStyle(
          fontSize: 14,
          color: Color(0xFFEAEAEA),
        );

    final effectiveIconSize =
        iconSize ?? (defaultTextStyle.fontSize ?? 14) * 0.95;
    final effectiveIconColor =
        iconColor ?? defaultTextStyle.color ?? const Color(0xFFEAEAEA);

    return SelectionContainer.disabled(
      child: GestureDetector(
        onTap: _launchUrl,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: Container(
            padding: padding ??
                const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: backgroundColor ?? const Color(0xFF2A2A2A),
              borderRadius: borderRadius ?? BorderRadius.circular(4),
              border: Border.all(
                color: borderColor ?? const Color(0xFF3A3A3A),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.link,
                  size: effectiveIconSize,
                  color: effectiveIconColor,
                ),
                const SizedBox(width: 4),
                Text(
                  url,
                  style: defaultTextStyle.copyWith(
                    fontSize: (defaultTextStyle.fontSize ?? 14) * 0.95,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
