import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;

/// Estilos customizados para o editor Quill em estilo chat/WhatsApp
quill.DefaultStyles chatDefaultStyles(BuildContext context) {
  final theme = Theme.of(context);

  return quill.DefaultStyles(
    h1: quill.DefaultTextBlockStyle(
      theme.textTheme.headlineLarge!.copyWith(
        color: theme.colorScheme.onSurface,
      ),
      const quill.HorizontalSpacing(0, 0),
      const quill.VerticalSpacing(16, 8),
      const quill.VerticalSpacing(0, 0),
      null,
    ),
    h2: quill.DefaultTextBlockStyle(
      theme.textTheme.headlineMedium!.copyWith(
        color: theme.colorScheme.onSurface,
      ),
      const quill.HorizontalSpacing(0, 0),
      const quill.VerticalSpacing(12, 6),
      const quill.VerticalSpacing(0, 0),
      null,
    ),
    h3: quill.DefaultTextBlockStyle(
      theme.textTheme.headlineSmall!.copyWith(
        color: theme.colorScheme.onSurface,
      ),
      const quill.HorizontalSpacing(0, 0),
      const quill.VerticalSpacing(10, 4),
      const quill.VerticalSpacing(0, 0),
      null,
    ),
    paragraph: quill.DefaultTextBlockStyle(
      theme.textTheme.bodyMedium!.copyWith(
        color: theme.colorScheme.onSurface,
      ),
      const quill.HorizontalSpacing(0, 0),
      const quill.VerticalSpacing(8, 4),
      const quill.VerticalSpacing(0, 0),
      null,
    ),
    bold: const TextStyle(fontWeight: FontWeight.bold),
    italic: const TextStyle(fontStyle: FontStyle.italic),
    underline: const TextStyle(decoration: TextDecoration.underline),
    strikeThrough: const TextStyle(decoration: TextDecoration.lineThrough),
    link: TextStyle(
      color: theme.colorScheme.primary,
      decoration: TextDecoration.underline,
    ),
    placeHolder: quill.DefaultTextBlockStyle(
      theme.textTheme.bodyMedium!.copyWith(
        color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
      ),
      const quill.HorizontalSpacing(0, 0),
      const quill.VerticalSpacing(0, 0),
      const quill.VerticalSpacing(0, 0),
      null,
    ),
    lists: quill.DefaultListBlockStyle(
      theme.textTheme.bodyMedium!.copyWith(
        color: theme.colorScheme.onSurface,
      ),
      const quill.HorizontalSpacing(0, 0),
      const quill.VerticalSpacing(8, 4),
      const quill.VerticalSpacing(0, 0),
      null,
      null,
    ),
    quote: quill.DefaultTextBlockStyle(
      theme.textTheme.bodyMedium!.copyWith(
        color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
      ),
      const quill.HorizontalSpacing(16, 0),
      const quill.VerticalSpacing(8, 4),
      const quill.VerticalSpacing(0, 0),
      BoxDecoration(
        border: Border(
          left: BorderSide(
            color: theme.colorScheme.primary,
            width: 4,
          ),
        ),
      ),
    ),
    code: quill.DefaultTextBlockStyle(
      theme.textTheme.bodyMedium!.copyWith(
        color: theme.colorScheme.onSurface,
        fontFamily: 'monospace',
      ),
      const quill.HorizontalSpacing(0, 0),
      const quill.VerticalSpacing(8, 4),
      const quill.VerticalSpacing(0, 0),
      BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(4),
      ),
    ),
    indent: quill.DefaultTextBlockStyle(
      theme.textTheme.bodyMedium!.copyWith(
        color: theme.colorScheme.onSurface,
      ),
      const quill.HorizontalSpacing(0, 0),
      const quill.VerticalSpacing(8, 4),
      const quill.VerticalSpacing(0, 0),
      null,
    ),
    align: quill.DefaultTextBlockStyle(
      theme.textTheme.bodyMedium!.copyWith(
        color: theme.colorScheme.onSurface,
      ),
      const quill.HorizontalSpacing(0, 0),
      const quill.VerticalSpacing(0, 0),
      const quill.VerticalSpacing(0, 0),
      null,
    ),
    leading: quill.DefaultTextBlockStyle(
      theme.textTheme.bodyMedium!.copyWith(
        color: theme.colorScheme.onSurface,
      ),
      const quill.HorizontalSpacing(0, 0),
      const quill.VerticalSpacing(0, 0),
      const quill.VerticalSpacing(0, 0),
      null,
    ),
    sizeSmall: const TextStyle(fontSize: 12),
    sizeLarge: const TextStyle(fontSize: 18),
    sizeHuge: const TextStyle(fontSize: 24),
  );
}

/// Builder customizado para imagens no estilo chat/WhatsApp
/// com altura máxima de 300px e proporção mantida
class ChatImageEmbedBuilder extends quill.EmbedBuilder {
  final ImageProvider? Function(String)? imageProviderBuilder;
  final Function(BuildContext, String)? onRemove;
  final Function(BuildContext, String)? onDownload;

  ChatImageEmbedBuilder({
    this.imageProviderBuilder,
    this.onRemove,
    this.onDownload,
  });

  @override
  String get key => 'image';

  @override
  Widget build(
    BuildContext context,
    quill.EmbedContext embedContext,
  ) {
    final imageUrl = embedContext.node.value.data as String;

    // NOTA: O cursor aparecendo atrás das imagens é uma limitação conhecida do flutter_quill
    // onde BlockEmbeds são renderizados em uma camada que sempre sobrepõe o cursor.
    // Tentativas de solução (todas falharam):
    // - paintCursorAboveText: true
    // - Theme com textSelectionTheme customizado
    // - RepaintBoundary com ValueKey
    // - Remover ClipRRect e usar Container
    // - IgnorePointer na imagem
    // O problema persiste porque o flutter_quill reconstrói o EmbedBuilder a cada frame.

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      constraints: const BoxConstraints(
        maxHeight: 300, // Altura máxima de 300px
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: _buildImage(context, imageUrl),
      ),
    );
  }

  Widget _buildImage(BuildContext context, String imageUrl) {
    ImageProvider? provider;

    if (imageProviderBuilder != null) {
      provider = imageProviderBuilder!(imageUrl);
    }

    if (provider != null) {
      return Image(
        image: provider,
        fit: BoxFit.contain, // Mantém proporção
        errorBuilder: (context, error, stackTrace) {
          return Container(
            height: 100,
            color: Colors.grey[800],
            child: const Center(
              child: Icon(Icons.broken_image, color: Colors.white54),
            ),
          );
        },
      );
    }

    // Fallback para URL direta
    if (imageUrl.startsWith('http://') || imageUrl.startsWith('https://')) {
      return Image.network(
        imageUrl,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            height: 100,
            color: Colors.grey[800],
            child: const Center(
              child: Icon(Icons.broken_image, color: Colors.white54),
            ),
          );
        },
      );
    }

    // Imagem local (file://)
    if (imageUrl.startsWith('file://')) {
      final localPath = imageUrl.substring(7);
      return Image.file(
        File(localPath),
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            height: 100,
            color: Colors.grey[800],
            child: const Center(
              child: Icon(Icons.broken_image, color: Colors.white54),
            ),
          );
        },
      );
    }

    // Fallback genérico
    return Container(
      height: 100,
      color: Colors.grey[800],
      child: const Center(
        child: Icon(Icons.image, color: Colors.white54),
      ),
    );
  }
}

