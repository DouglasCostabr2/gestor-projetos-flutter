import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Widget genérico para campo de texto simples
///
/// Características:
/// - Design consistente com tema global
/// - Validação customizável
/// - Máscaras e formatadores opcionais
/// - Prefixo e sufixo customizáveis
/// - Contador de caracteres opcional
///
/// Exemplo de uso básico:
/// ```dart
/// GenericTextField(
///   controller: _nameController,
///   labelText: 'Nome *',
///   hintText: 'Digite seu nome',
///   validator: (value) => value?.isEmpty ?? true ? 'Campo obrigatório' : null,
///   enabled: !_saving,
/// )
/// ```
///
/// Exemplo com máscara:
/// ```dart
/// GenericTextField(
///   controller: _cepController,
///   labelText: 'CEP',
///   hintText: '00000-000',
///   keyboardType: TextInputType.number,
///   inputFormatters: [
///     FilteringTextInputFormatter.digitsOnly,
///     CepInputFormatter(),
///   ],
/// )
/// ```
class GenericTextField extends StatelessWidget {
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

  /// Ícone de prefixo
  final Widget? prefixIcon;

  /// Texto de prefixo
  final String? prefixText;

  /// Ícone de sufixo
  final Widget? suffixIcon;

  /// Texto de sufixo
  final String? suffixText;

  /// Função de validação
  final String? Function(String?)? validator;

  /// Callback quando o valor muda
  final ValueChanged<String>? onChanged;

  /// Callback quando o campo perde o foco
  final VoidCallback? onEditingComplete;

  /// Callback quando o usuário pressiona Enter
  final ValueChanged<String>? onFieldSubmitted;

  /// Se o campo está habilitado
  final bool enabled;

  /// Se o campo é somente leitura
  final bool readOnly;

  /// Se deve obscurecer o texto (senha)
  final bool obscureText;

  /// Tipo de teclado
  final TextInputType? keyboardType;

  /// Ação do teclado
  final TextInputAction? textInputAction;

  /// Capitalização automática
  final TextCapitalization textCapitalization;

  /// Número máximo de linhas (1 = single line)
  final int? maxLines;

  /// Número mínimo de linhas
  final int? minLines;

  /// Número máximo de caracteres
  final int? maxLength;

  /// Se deve mostrar o contador de caracteres
  final bool showCounter;

  /// Formatadores de input
  final List<TextInputFormatter>? inputFormatters;

  /// Se deve auto-focar ao criar
  final bool autofocus;

  /// FocusNode customizado
  final FocusNode? focusNode;

  /// Estilo do texto
  final TextStyle? style;

  /// Alinhamento do texto
  final TextAlign textAlign;

  const GenericTextField({
    super.key,
    this.controller,
    this.initialValue,
    this.labelText,
    this.hintText,
    this.helperText,
    this.prefixIcon,
    this.prefixText,
    this.suffixIcon,
    this.suffixText,
    this.validator,
    this.onChanged,
    this.onEditingComplete,
    this.onFieldSubmitted,
    this.enabled = true,
    this.readOnly = false,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction,
    this.textCapitalization = TextCapitalization.none,
    this.maxLines = 1,
    this.minLines,
    this.maxLength,
    this.showCounter = false,
    this.inputFormatters,
    this.autofocus = false,
    this.focusNode,
    this.style,
    this.textAlign = TextAlign.start,
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
      obscureText: obscureText,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      textCapitalization: textCapitalization,
      maxLines: maxLines,
      minLines: minLines,
      maxLength: maxLength,
      inputFormatters: inputFormatters,
      autofocus: autofocus,
      focusNode: focusNode,
      style: style,
      textAlign: textAlign,
      decoration: InputDecoration(
        labelText: labelText,
        hintText: hintText,
        helperText: helperText,
        prefixIcon: prefixIcon,
        prefixText: prefixText,
        suffixIcon: suffixIcon,
        suffixText: suffixText,
        counterText: showCounter ? null : '', // Esconde contador se showCounter = false
      ),
      validator: validator,
      onChanged: onChanged,
      onEditingComplete: onEditingComplete,
      onFieldSubmitted: onFieldSubmitted,
    );
  }
}

