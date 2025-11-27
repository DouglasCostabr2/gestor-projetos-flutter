import 'package:flutter/material.dart';
import 'mention_hover_card.dart';
import '../../atoms/badges/link_badge.dart';

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
    final defaultMentionStyle = widget.mentionStyle ??
        TextStyle(
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
      child: Text.rich(
        TextSpan(children: spans),
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

    // Regex para detectar URLs
    final urlRegex = RegExp(
      r'https?:\/\/(www\.)?[-a-zA-Z0-9@:%._\+~#=]{1,256}\.[a-zA-Z0-9()]{1,6}\b([-a-zA-Z0-9()@:%_\+.~#?&//=]*)',
      caseSensitive: false,
    );

    // Suporta dois formatos de menções:
    // 1. @[Nome](id) - formato antigo com ID
    // 2. @Nome - formato novo sem ID
    final regexWithId = RegExp(r'@\[([^\]]+)\]\(([^)]+)\)');
    final regexSimple = RegExp(r'@([A-Za-zÀ-ÿ\s]+)(?=\s|$|[.,!?;:])');

    // Coletar todas as correspondências (menções e URLs)
    final allMatches = <({
      int start,
      int end,
      String type, // 'mention' ou 'url'
      String? userName,
      String? userId,
      String? url,
    })>[];

    // Encontrar menções com ID
    for (final match in regexWithId.allMatches(text)) {
      allMatches.add((
        start: match.start,
        end: match.end,
        type: 'mention',
        userName: match.group(1)!,
        userId: match.group(2)!,
        url: null,
      ));
    }

    // Encontrar menções simples (@Nome)
    for (final match in regexSimple.allMatches(text)) {
      // Verificar se não está dentro de uma menção com ID
      bool isInsideIdMention = false;
      for (final idMatch in allMatches.where((m) => m.type == 'mention')) {
        if (match.start >= idMatch.start && match.end <= idMatch.end) {
          isInsideIdMention = true;
          break;
        }
      }

      if (!isInsideIdMention) {
        allMatches.add((
          start: match.start,
          end: match.end,
          type: 'mention',
          userName: match.group(1)!,
          userId: null,
          url: null,
        ));
      }
    }

    // Encontrar URLs
    for (final match in urlRegex.allMatches(text)) {
      // Verificar se não está dentro de uma menção
      bool isInsideMention = false;
      for (final mentionMatch in allMatches.where((m) => m.type == 'mention')) {
        if (match.start >= mentionMatch.start &&
            match.end <= mentionMatch.end) {
          isInsideMention = true;
          break;
        }
      }

      if (!isInsideMention) {
        allMatches.add((
          start: match.start,
          end: match.end,
          type: 'url',
          userName: null,
          userId: null,
          url: match.group(0)!,
        ));
      }
    }

    // Ordenar por posição
    allMatches.sort((a, b) => a.start.compareTo(b.start));

    int lastMatchEnd = 0;

    for (final match in allMatches) {
      // Adicionar texto antes da correspondência
      if (match.start > lastMatchEnd) {
        spans.add(TextSpan(
          text: text.substring(lastMatchEnd, match.start),
          style: defaultStyle,
        ));
      }

      if (match.type == 'mention') {
        // Adicionar menção com hover e clique
        final userName = match.userName!;
        final userId = match.userId;

        if (userId != null) {
          // Menção com ID - mostrar hover card
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
        } else {
          // Menção sem ID - apenas destacar em negrito
          spans.add(TextSpan(
            text: '@$userName',
            style: mentionStyle,
          ));
        }
      } else if (match.type == 'url') {
        // Adicionar URL clicável usando o componente LinkBadge
        final url = match.url!;
        spans.add(WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: LinkBadge(
            url: url,
            textStyle: defaultStyle,
          ),
        ));
      }

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
