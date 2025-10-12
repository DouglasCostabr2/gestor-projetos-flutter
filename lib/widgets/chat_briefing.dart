import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;

/// Function type to provide an ImageProvider for a given image URL used by Quill
/// (supports our cached MemoryImage/FileImage providers).
typedef ImageProviderBuilder = ImageProvider<Object>? Function(
  BuildContext context,
  String imageUrl,
);

/// Default WhatsApp-like bubble styles for Quill text blocks (paragraphs)
quill.DefaultStyles chatDefaultStyles(BuildContext context) {
  final base = quill.DefaultStyles.getInstance(context);
  // Approximate editor width: both forms constrain to maxWidth 560
  final screenW = MediaQuery.of(context).size.width;
  final editorW = screenW >= 600 ? 560.0 : (screenW - 32.0).clamp(280.0, screenW);
  final targetMax = math.min(400.0, editorW * 0.8); // bubble max width
  final rightMargin = (editorW - targetMax).clamp(0.0, editorW);
  return base.merge(
    quill.DefaultStyles(
      paragraph: quill.DefaultTextBlockStyle(
        base.paragraph?.style ?? const TextStyle(),
        quill.HorizontalSpacing(0, rightMargin), // limit width to ~targetMax
        const quill.VerticalSpacing(6, 6), // space between bubbles
        const quill.VerticalSpacing(0, 0),
        BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(14),
        ),
      ),
    ),
  );
}

/// Image embed that renders images inside a rounded bubble like chat messages
class ChatImageEmbedBuilder extends quill.EmbedBuilder {
  ChatImageEmbedBuilder({required this.imageProviderBuilder, this.onRemove, this.onDownload});

  final ImageProviderBuilder imageProviderBuilder;
  final void Function(BuildContext context, String imageUrl)? onRemove;
  final void Function(BuildContext context, String imageUrl)? onDownload;

  @override
  String get key => 'image';

  @override
  Widget build(
    BuildContext context,
    quill.EmbedContext embedContext,
  ) {
    final node = embedContext.node;
    final src = (node.value.data ?? '').toString();
    final provider = imageProviderBuilder(context, src);
    final image = provider != null
        ? Image(image: provider, fit: BoxFit.scaleDown)
        : Image.network(src, fit: BoxFit.scaleDown);

    final screenW = MediaQuery.of(context).size.width;
    final editorW = screenW >= 600 ? 560.0 : (screenW - 32.0).clamp(280.0, screenW);
    final maxBubbleW = math.min(400.0, editorW * 0.8);

    return Align(
      alignment: Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxBubbleW),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 6),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Stack(children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 300),
                child: image,
              ),
            ),
            if (onDownload != null || onRemove != null)
              Positioned(
                right: 4,
                top: 4,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (onDownload != null)
                      InkWell(
                        onTap: () => onDownload?.call(context, src),
                        child: Container(
                          decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.all(2),
                          child: const Icon(Icons.download, color: Colors.white, size: 18),
                        ),
                      ),
                    if (onDownload != null && onRemove != null)
                      const SizedBox(width: 6),
                    if (onRemove != null)
                      InkWell(
                        onTap: () => onRemove?.call(context, src),
                        child: Container(
                          decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.all(2),
                          child: const Icon(Icons.close, color: Colors.white, size: 18),
                        ),
                      ),
                  ],
                ),
              ),
          ]),
        ),
      ),
    );
  }
}

