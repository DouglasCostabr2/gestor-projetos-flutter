import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Widget genérico para campo de telefone
///
/// Características:
/// - Design consistente com tema global
/// - Máscara automática de telefone brasileiro
/// - Teclado numérico
/// - Ícone de telefone padrão
/// - Suporta celular (11 dígitos) e fixo (10 dígitos)
///
/// Exemplo de uso:
/// ```dart
/// GenericPhoneField(
///   controller: _phoneController,
///   labelText: 'Telefone',
///   hintText: '(00) 00000-0000',
///   required: true,
///   enabled: !_saving,
/// )
/// ```
class GenericPhoneField extends StatelessWidget {
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

  /// Função de validação customizada (adicional à validação de telefone)
  final String? Function(String?)? validator;

  /// Callback quando o valor muda
  final ValueChanged<String>? onChanged;

  /// Se o campo está habilitado
  final bool enabled;

  /// Se o campo é obrigatório
  final bool required;

  /// Se deve auto-focar ao criar
  final bool autofocus;

  /// FocusNode customizado
  final FocusNode? focusNode;

  /// Mensagem de erro quando telefone inválido
  final String invalidPhoneMessage;

  /// Mensagem de erro quando campo vazio (se required = true)
  final String requiredMessage;

  const GenericPhoneField({
    super.key,
    this.controller,
    this.initialValue,
    this.labelText,
    this.hintText,
    this.helperText,
    this.validator,
    this.onChanged,
    this.enabled = true,
    this.required = false,
    this.autofocus = false,
    this.focusNode,
    this.invalidPhoneMessage = 'Telefone inválido',
    this.requiredMessage = 'Campo obrigatório',
  }) : assert(
          controller == null || initialValue == null,
          'Cannot provide both controller and initialValue',
        );

  String? _validate(String? value) {
    // Campo vazio
    if (value == null || value.trim().isEmpty) {
      return required ? requiredMessage : null;
    }

    // Remove caracteres não numéricos
    final digitsOnly = value.replaceAll(RegExp(r'\D'), '');

    // Valida quantidade de dígitos (10 para fixo, 11 para celular)
    if (digitsOnly.length < 10 || digitsOnly.length > 11) {
      return invalidPhoneMessage;
    }

    // Validação customizada do usuário
    return validator?.call(value);
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      initialValue: initialValue,
      enabled: enabled,
      keyboardType: TextInputType.phone,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        _PhoneInputFormatter(),
      ],
      autofocus: autofocus,
      focusNode: focusNode,
      decoration: InputDecoration(
        labelText: labelText,
        hintText: hintText,
        helperText: helperText,
        prefixIcon: const Icon(Icons.phone_outlined),
      ),
      validator: _validate,
      onChanged: onChanged,
    );
  }
}

/// Formatador de telefone brasileiro
/// Formatos: (00) 0000-0000 ou (00) 00000-0000
class _PhoneInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text;
    final digitsOnly = text.replaceAll(RegExp(r'\D'), '');

    // Limita a 11 dígitos
    if (digitsOnly.length > 11) {
      return oldValue;
    }

    String formatted = '';

    // DDD
    if (digitsOnly.isNotEmpty) {
      formatted = '(${digitsOnly.substring(0, digitsOnly.length > 2 ? 2 : digitsOnly.length)}';
    }

    // Fecha parênteses após DDD
    if (digitsOnly.length > 2) {
      formatted += ') ';
    }

    // Primeira parte do número
    if (digitsOnly.length > 2) {
      final firstPartLength = digitsOnly.length == 11 ? 5 : 4;
      final endIndex = digitsOnly.length > (2 + firstPartLength) 
          ? (2 + firstPartLength) 
          : digitsOnly.length;
      formatted += digitsOnly.substring(2, endIndex);
    }

    // Hífen
    if (digitsOnly.length > 6) {
      formatted += '-';
    }

    // Segunda parte do número
    if (digitsOnly.length > 6) {
      final startIndex = digitsOnly.length == 11 ? 7 : 6;
      formatted += digitsOnly.substring(startIndex);
    }

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

