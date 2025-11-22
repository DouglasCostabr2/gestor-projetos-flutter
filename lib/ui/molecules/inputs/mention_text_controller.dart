import 'package:flutter/material.dart';

/// TextEditingController customizado que formata menções para exibição
///
/// Armazena: @[Nome do Usuário](user_id)
/// Exibe: @Nome do Usuário
///
/// Isso permite que o usuário veja apenas @Nome mas o sistema
/// armazene o ID do usuário para referência
class MentionTextEditingController extends TextEditingController {
  MentionTextEditingController({super.text, this.enableFormatting = true});

  /// Se true, formata as menções (@Nome). Se false, mostra o texto completo (@[Nome](id))
  bool enableFormatting;

  /// Converte uma posição visual (baseada no texto exibido) para posição real (baseada no texto armazenado)
  int visualToRealPosition(int visualPos) {
    final regex = RegExp(r'@\[([^\]]+)\]\(([^)]+)\)');
    final matches = regex.allMatches(text).toList();

    int realPos = visualPos;
    int visualOffset = 0;

    for (final match in matches) {
      final mentionStart = match.start;
      final mentionEnd = match.end;
      final userName = match.group(1)!;

      // Tamanho visual: @Nome
      final visualSize = 1 + userName.length; // @ + Nome
      // Tamanho real: @[Nome](id)
      final realSize = mentionEnd - mentionStart;
      final sizeDiff = realSize - visualSize;

      // Ajustar a posição visual considerando menções anteriores
      final adjustedMentionStart = mentionStart - visualOffset;
      final adjustedMentionEnd = adjustedMentionStart + visualSize;

      if (visualPos <= adjustedMentionStart) {
        // Antes desta menção, não precisa ajustar mais
        break;
      } else if (visualPos <= adjustedMentionEnd) {
        // Dentro da menção visual, mapear para dentro do nome real
        final offsetInMention = visualPos - adjustedMentionStart;
        if (offsetInMention == 0) {
          // No @, mapear para antes do @
          realPos = mentionStart;
        } else {
          // Dentro do nome, mapear para dentro de @[Nome]
          realPos = mentionStart + 2 + (offsetInMention - 1); // +2 para pular @[
        }
        break;
      } else {
        // Depois desta menção, acumular o offset
        visualOffset += sizeDiff;
        realPos = visualPos + visualOffset;
      }
    }

    return realPos.clamp(0, text.length);
  }

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    // Se formatação está desabilitada, usar comportamento padrão
    if (!enableFormatting) {
      return super.buildTextSpan(
        context: context,
        style: style,
        withComposing: withComposing,
      );
    }

    final spans = _buildFormattedSpans(text, style);

    return TextSpan(
      children: spans.isNotEmpty ? spans : [TextSpan(text: '', style: style)],
      style: style,
    );
  }

  /// Constrói spans formatados, substituindo @[Nome](id) por @Nome
  List<InlineSpan> _buildFormattedSpans(String text, TextStyle? style) {
    // Se não houver menções, retornar texto simples
    if (!text.contains('@[')) {
      return [TextSpan(text: text, style: style)];
    }

    final spans = <InlineSpan>[];
    final regex = RegExp(r'@\[([^\]]+)\]\(([^)]+)\)');
    final matches = regex.allMatches(text).toList();

    int lastMatchEnd = 0;
    final defaultStyle = style ?? const TextStyle();

    for (final match in matches) {
      // Adicionar texto antes da menção
      if (match.start > lastMatchEnd) {
        spans.add(TextSpan(
          text: text.substring(lastMatchEnd, match.start),
          style: defaultStyle,
        ));
      }

      // Adicionar menção formatada (@Nome ao invés de @[Nome](id))
      final userName = match.group(1)!;
      spans.add(TextSpan(
        text: '@$userName',
        style: defaultStyle.copyWith(
          color: const Color(0xFFFFFFFF),
          fontWeight: FontWeight.w600,
        ),
      ));

      lastMatchEnd = match.end;
    }

    // Adicionar texto restante após a última menção
    if (lastMatchEnd < text.length) {
      spans.add(TextSpan(
        text: text.substring(lastMatchEnd),
        style: defaultStyle.copyWith(
          color: defaultStyle.color,
          fontWeight: defaultStyle.fontWeight ?? FontWeight.normal,
          fontStyle: defaultStyle.fontStyle ?? FontStyle.normal,
          decoration: defaultStyle.decoration ?? TextDecoration.none,
        ),
      ));
    }

    return spans;
  }
}

