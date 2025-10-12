import 'package:flutter/material.dart';

/// Widget genérico para campo de texto multilinha (área de texto)
///
/// Características:
/// - Design consistente com tema global
/// - Múltiplas linhas
/// - Contador de caracteres opcional
/// - Validação customizável
/// - Altura expansível ou fixa
///
/// Exemplo de uso:
/// ```dart
/// GenericTextArea(
///   controller: _descriptionController,
///   labelText: 'Descrição',
///   hintText: 'Digite a descrição do projeto...',
///   minLines: 3,
///   maxLines: 8,
///   maxLength: 500,
///   showCounter: true,
///   enabled: !_saving,
/// )
/// ```
class GenericTextArea extends StatelessWidget {
  /// Controller do campo
  final TextEditingController? controller;

  /// Valor inicial (se não usar controller)
  final String? initialValue;

  /// Texto do label
  final String? labelText;

  /// Texto de hint
  final String? hintText;

  /// Texto de ajuda
  final String? helperText;

  /// Função de validação
  final String? Function(String?)? validator;

  /// Callback quando o valor muda
  final ValueChanged<String>? onChanged;

  /// Se o campo está habilitado
  final bool enabled;

  /// Se o campo é somente leitura
  final bool readOnly;

  /// Número mínimo de linhas
  final int minLines;

  /// Número máximo de linhas (null = expansível)
  final int? maxLines;

  /// Número máximo de caracteres
  final int? maxLength;

  /// Se deve mostrar o contador de caracteres
  final bool showCounter;

  /// Se deve auto-focar ao criar
  final bool autofocus;

  /// FocusNode customizado
  final FocusNode? focusNode;

  /// Estilo do texto
  final TextStyle? style;

  /// Se o label deve ficar alinhado com o hint (topo)
  final bool alignLabelWithHint;

  const GenericTextArea({
    super.key,
    this.controller,
    this.initialValue,
    this.labelText,
    this.hintText,
    this.helperText,
    this.validator,
    this.onChanged,
    this.enabled = true,
    this.readOnly = false,
    this.minLines = 3,
    this.maxLines = 8,
    this.maxLength,
    this.showCounter = false,
    this.autofocus = false,
    this.focusNode,
    this.style,
    this.alignLabelWithHint = true,
  }) : assert(
          controller == null || initialValue == null,
          'Cannot provide both controller and initialValue',
        );

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      initialValue: initialValue,
      enabled: enabled,
      readOnly: readOnly,
      keyboardType: TextInputType.multiline,
      textCapitalization: TextCapitalization.sentences,
      minLines: minLines,
      maxLines: maxLines,
      maxLength: maxLength,
      autofocus: autofocus,
      focusNode: focusNode,
      style: style,
      decoration: InputDecoration(
        labelText: labelText,
        hintText: hintText,
        helperText: helperText,
        alignLabelWithHint: alignLabelWithHint,
        counterText: showCounter ? null : '', // Esconde contador se showCounter = false
      ),
      validator: validator,
      onChanged: onChanged,
    );
  }
}

