import 'package:flutter/material.dart';
import 'mention_hover_card.dart';

/// Widget para exibir texto com menções destacadas
///
/// Características:
/// - Destaca menções com cor diferente
/// - Suporta clique nas menções (opcional)
/// - Suporta hover para exibir card com informações do usuário
/// - Formata menções para exibição (@Nome ao invés de @[Nome](id))
///
/// Exemplo de uso:
/// ```dart
/// MentionText(
///   text: 'Olá @[João Silva](user-123), tudo bem?',
///   style: TextStyle(fontSize: 14),
///   onMentionTap: (userId, userName) {
///     print('Clicou em: $userName ($userId)');
///   },
/// )
/// ```
class MentionText extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final TextStyle? mentionStyle;
  final void Function(String userId, String userName)? onMentionTap;
  final int? maxLines;
  final TextOverflow? overflow;
  final TextAlign? textAlign;

  const MentionText({
    super.key,
    required this.text,
    this.style,
    this.mentionStyle,
    this.onMentionTap,
    this.maxLines,
    this.overflow,
    this.textAlign,
  });

  @override
  State<MentionText> createState() => _MentionTextState();
}

class _MentionTextState extends State<MentionText> {
  OverlayEntry? _overlayEntry;
  String? _hoveredUserId;
  final LayerLink _layerLink = LayerLink();

  @override
  void dispose() {
    _removeOverlay();
    super.dispose();
  }

  void _showHoverCard(String userId, Offset position) {
    _removeOverlay();

    _hoveredUserId = userId;
    _overlayEntry = OverlayEntry(
      builder: (context) => GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: _removeOverlay,
        child: Stack(
          children: [
            MentionHoverCard(
              userId: userId,
              position: position,
              onClose: _removeOverlay,
            ),
          ],
        ),
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    _hoveredUserId = null;
  }

  @override
  Widget build(BuildContext context) {
    final defaultStyle = widget.style ?? DefaultTextStyle.of(context).style;
    final defaultMentionStyle = widget.mentionStyle ?? TextStyle(
      color: Theme.of(context).colorScheme.primary,
      fontWeight: FontWeight.w600,
    );

    final spans = _buildTextSpans(
      widget.text,
      defaultStyle,
      defaultMentionStyle,
      context,
    );

    return CompositedTransformTarget(
      link: _layerLink,
      child: RichText(
        text: TextSpan(children: spans),
        maxLines: widget.maxLines,
        overflow: widget.overflow ?? TextOverflow.clip,
        textAlign: widget.textAlign ?? TextAlign.start,
      ),
    );
  }

  List<InlineSpan> _buildTextSpans(
    String text,
    TextStyle defaultStyle,
    TextStyle mentionStyle,
    BuildContext context,
  ) {
    final spans = <InlineSpan>[];
    final regex = RegExp(r'@\[([^\]]+)\]\(([^)]+)\)');
    int lastMatchEnd = 0;

    for (final match in regex.allMatches(text)) {
      // Adicionar texto antes da menção
      if (match.start > lastMatchEnd) {
        spans.add(TextSpan(
          text: text.substring(lastMatchEnd, match.start),
          style: defaultStyle,
        ));
      }

      // Adicionar menção com hover e clique
      final userName = match.group(1)!;
      final userId = match.group(2)!;

      spans.add(WidgetSpan(
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (event) {
            // Calcular posição do hover card
            final RenderBox? box = context.findRenderObject() as RenderBox?;
            if (box != null) {
              final position = box.localToGlobal(Offset.zero);
              _showHoverCard(
                userId,
                Offset(
                  position.dx + event.localPosition.dx,
                  position.dy + event.localPosition.dy + 20,
                ),
              );
            }
          },
          onExit: (_) {
            // Pequeno delay antes de remover para permitir mover o mouse para o card
            Future.delayed(const Duration(milliseconds: 200), () {
              if (_hoveredUserId == userId) {
                _removeOverlay();
              }
            });
          },
          child: GestureDetector(
            onTap: widget.onMentionTap != null
                ? () => widget.onMentionTap!(userId, userName)
                : null,
            child: Text(
              '@$userName',
              style: mentionStyle.copyWith(
                decoration: widget.onMentionTap != null
                    ? TextDecoration.underline
                    : null,
              ),
            ),
          ),
        ),
      ));

      lastMatchEnd = match.end;
    }

    // Adicionar texto restante
    if (lastMatchEnd < text.length) {
      spans.add(TextSpan(
        text: text.substring(lastMatchEnd),
        style: defaultStyle,
      ));
    }

    return spans;
  }
}

/// Widget para exibir texto com menções em um campo de formulário
/// Similar ao MentionText, mas otimizado para uso em TextFormField
class MentionFormFieldText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final TextStyle? mentionStyle;

  const MentionFormFieldText({
    super.key,
    required this.text,
    this.style,
    this.mentionStyle,
  });

  @override
  Widget build(BuildContext context) {
    return MentionText(
      text: text,
      style: style,
      mentionStyle: mentionStyle,
    );
  }
}

