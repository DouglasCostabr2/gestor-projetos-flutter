import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Widget genérico para campo de telefone
///
/// Características:
/// - Design consistente com tema global
/// - Aceita qualquer formato internacional de telefone
/// - Formatação automática inteligente baseada no código do país
/// - Ícone de telefone padrão
/// - Suporta múltiplos formatos internacionais
///
/// Exemplo de uso:
/// ```dart
/// GenericPhoneField(
///   controller: _phoneController,
///   labelText: 'Telefone',
///   hintText: '+55 (11) 98765-4321',
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

    // Validação customizada do usuário (se fornecida)
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
        InternationalPhoneFormatter(),
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

/// Formatador inteligente de telefone internacional
///
/// Detecta automaticamente o código do país e aplica formatação apropriada:
/// - Brasil (+55): +55 (11) 98765-4321
/// - EUA/Canadá (+1): +1 (555) 123-4567
/// - Portugal (+351): +351 912 345 678
/// - Outros países: +XX XXX XXX XXX
class InternationalPhoneFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text;

    // Remove tudo exceto dígitos e o símbolo +
    String digitsAndPlus = text.replaceAll(RegExp(r'[^\d+]'), '');

    // Se não começar com +, adiciona automaticamente
    if (digitsAndPlus.isNotEmpty && !digitsAndPlus.startsWith('+')) {
      digitsAndPlus = '+$digitsAndPlus';
    }

    // Limita o tamanho total (código do país + número)
    if (digitsAndPlus.length > 20) {
      return oldValue;
    }

    // Se está vazio ou só tem +, retorna como está
    if (digitsAndPlus.isEmpty || digitsAndPlus == '+') {
      return TextEditingValue(
        text: digitsAndPlus,
        selection: TextSelection.collapsed(offset: digitsAndPlus.length),
      );
    }

    // Extrai apenas os dígitos (sem o +)
    final digits = digitsAndPlus.substring(1);

    // Formata baseado no código do país
    String formatted = _formatByCountryCode(digits);

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }

  String _formatByCountryCode(String digits) {
    if (digits.isEmpty) return '+';

    // Brasil (+55)
    if (digits.startsWith('55')) {
      return _formatBrazil(digits);
    }

    // EUA/Canadá (+1)
    if (digits.startsWith('1')) {
      return _formatNorthAmerica(digits);
    }

    // Portugal (+351)
    if (digits.startsWith('351')) {
      return _formatPortugal(digits);
    }

    // Espanha (+34)
    if (digits.startsWith('34')) {
      return _formatSpain(digits);
    }

    // Argentina (+54)
    if (digits.startsWith('54')) {
      return _formatArgentina(digits);
    }

    // Formato genérico para outros países
    return _formatGeneric(digits);
  }

  String _formatBrazil(String digits) {
    // +55 (11) 98765-4321
    if (digits.length <= 2) return '+$digits';

    String formatted = '+55';
    final remaining = digits.substring(2);

    if (remaining.isEmpty) return formatted;

    // DDD
    if (remaining.length <= 2) {
      formatted += ' ($remaining';
    } else {
      formatted += ' (${remaining.substring(0, 2)})';
      final number = remaining.substring(2);

      if (number.isEmpty) return formatted;

      // Primeira parte do número (5 dígitos para celular, 4 para fixo)
      final isMobile = number.length >= 9;
      final firstPartLength = isMobile ? 5 : 4;

      if (number.length <= firstPartLength) {
        formatted += ' $number';
      } else {
        formatted += ' ${number.substring(0, firstPartLength)}-${number.substring(firstPartLength)}';
      }
    }

    return formatted;
  }

  String _formatNorthAmerica(String digits) {
    // +1 (555) 123-4567
    if (digits.length <= 1) return '+$digits';

    String formatted = '+1';
    final remaining = digits.substring(1);

    if (remaining.isEmpty) return formatted;

    // Area code
    if (remaining.length <= 3) {
      formatted += ' ($remaining';
    } else {
      formatted += ' (${remaining.substring(0, 3)})';
      final number = remaining.substring(3);

      if (number.isEmpty) return formatted;

      if (number.length <= 3) {
        formatted += ' $number';
      } else {
        formatted += ' ${number.substring(0, 3)}-${number.substring(3)}';
      }
    }

    return formatted;
  }

  String _formatPortugal(String digits) {
    // +351 912 345 678
    if (digits.length <= 3) return '+$digits';

    String formatted = '+351';
    final remaining = digits.substring(3);

    if (remaining.isEmpty) return formatted;

    if (remaining.length <= 3) {
      formatted += ' $remaining';
    } else if (remaining.length <= 6) {
      formatted += ' ${remaining.substring(0, 3)} ${remaining.substring(3)}';
    } else {
      formatted += ' ${remaining.substring(0, 3)} ${remaining.substring(3, 6)} ${remaining.substring(6)}';
    }

    return formatted;
  }

  String _formatSpain(String digits) {
    // +34 912 345 678
    if (digits.length <= 2) return '+$digits';

    String formatted = '+34';
    final remaining = digits.substring(2);

    if (remaining.isEmpty) return formatted;

    if (remaining.length <= 3) {
      formatted += ' $remaining';
    } else if (remaining.length <= 6) {
      formatted += ' ${remaining.substring(0, 3)} ${remaining.substring(3)}';
    } else {
      formatted += ' ${remaining.substring(0, 3)} ${remaining.substring(3, 6)} ${remaining.substring(6)}';
    }

    return formatted;
  }

  String _formatArgentina(String digits) {
    // +54 11 1234-5678
    if (digits.length <= 2) return '+$digits';

    String formatted = '+54';
    final remaining = digits.substring(2);

    if (remaining.isEmpty) return formatted;

    // Area code (2-4 dígitos)
    if (remaining.length <= 2) {
      formatted += ' $remaining';
    } else if (remaining.length <= 4) {
      formatted += ' ${remaining.substring(0, 2)} ${remaining.substring(2)}';
    } else {
      formatted += ' ${remaining.substring(0, 2)} ${remaining.substring(2, 6)}-${remaining.substring(6)}';
    }

    return formatted;
  }

  String _formatGeneric(String digits) {
    // Formato genérico: +XX XXX XXX XXX
    String formatted = '+';

    // Código do país (1-3 dígitos)
    int countryCodeLength = 1;
    if (digits.length >= 2 && int.tryParse(digits.substring(0, 2)) != null) {
      if (digits.startsWith('1') || digits.startsWith('7')) {
        countryCodeLength = 1;
      } else if (digits.length >= 3 && int.tryParse(digits.substring(0, 3)) != null) {
        countryCodeLength = 3;
      } else {
        countryCodeLength = 2;
      }
    }

    if (digits.length <= countryCodeLength) {
      return '+$digits';
    }

    formatted += digits.substring(0, countryCodeLength);
    final remaining = digits.substring(countryCodeLength);

    // Agrupa o restante em blocos de 3
    for (int i = 0; i < remaining.length; i += 3) {
      formatted += ' ${remaining.substring(i, i + 3 > remaining.length ? remaining.length : i + 3)}';
    }

    return formatted;
  }
}

