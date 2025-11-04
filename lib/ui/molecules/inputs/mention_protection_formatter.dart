import 'package:flutter/services.dart';

/// TextInputFormatter que protege a estrutura das menções
/// 
/// Garante que quando o usuário digita, o texto não seja inserido
/// dentro da estrutura @[Nome](id), mas sim antes ou depois dela
class MentionProtectionFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    // Se o texto não mudou, retornar
    if (oldValue.text == newValue.text) {
      return newValue;
    }

    // Detectar se há menções no texto
    final mentionRegex = RegExp(r'@\[([^\]]+)\]\(([^)]+)\)');
    final oldMatches = mentionRegex.allMatches(oldValue.text).toList();
    final newMatches = mentionRegex.allMatches(newValue.text).toList();

    // Se não há menções, permitir edição normal
    if (oldMatches.isEmpty) {
      return newValue;
    }

    final cursorPos = newValue.selection.baseOffset;

    for (final match in oldMatches) {
      final mentionEnd = match.end;
      final nameStart = match.start + 2; // Após "@["
      final nameEnd = match.start + 2 + match.group(1)!.length;

      // Se o cursor está dentro da estrutura da menção (mas não no nome)
      if (cursorPos > nameEnd && cursorPos < mentionEnd) {
        // Mover o cursor para depois da menção
        return TextEditingValue(
          text: oldValue.text,
          selection: TextSelection.collapsed(offset: mentionEnd),
        );
      }

      // Se o usuário está tentando editar o nome da menção
      if (cursorPos >= nameStart && cursorPos <= nameEnd) {
        final newMatch = newMatches.firstWhere(
          (m) => m.start == match.start,
          orElse: () => match,
        );

        final oldName = match.group(1)!;
        final newName = newMatch.group(1)!;

        // Se o nome foi modificado e ficou maior, redirecionar o texto
        if (newName.length > oldName.length) {
          final addedText = newName.substring(oldName.length);

          // Inserir o texto DEPOIS da menção ao invés de dentro
          final beforeMention = oldValue.text.substring(0, mentionEnd);
          final afterMention = oldValue.text.substring(mentionEnd);
          final correctedText = '$beforeMention$addedText$afterMention';

          return TextEditingValue(
            text: correctedText,
            selection: TextSelection.collapsed(
              offset: mentionEnd + addedText.length,
            ),
          );
        }
      }
    }

    return newValue;
  }
}

