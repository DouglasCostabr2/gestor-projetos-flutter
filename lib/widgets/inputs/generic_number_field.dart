import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Widget genérico para campo numérico
///
/// Características:
/// - Design consistente com tema global
/// - Aceita apenas números
/// - Suporta decimais opcionalmente
/// - Formatação automática
/// - Validação de range opcional
///
/// Exemplo de uso (inteiro):
/// ```dart
/// GenericNumberField(
///   controller: _quantityController,
///   labelText: 'Quantidade *',
///   hintText: '0',
///   allowDecimals: false,
///   min: 1,
///   max: 100,
///   validator: (value) => value == null || value.isEmpty ? 'Campo obrigatório' : null,
/// )
/// ```
///
/// Exemplo de uso (decimal):
/// ```dart
/// GenericNumberField(
///   controller: _priceController,
///   labelText: 'Preço',
///   hintText: '0,00',
///   allowDecimals: true,
///   decimalDigits: 2,
///   prefixText: 'R\$ ',
/// )
/// ```
class GenericNumberField extends StatelessWidget {
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

  /// Texto de prefixo (ex: 'R$ ')
  final String? prefixText;

  /// Ícone de sufixo
  final Widget? suffixIcon;

  /// Texto de sufixo (ex: 'kg')
  final String? suffixText;

  /// Função de validação
  final String? Function(String?)? validator;

  /// Callback quando o valor muda
  final ValueChanged<String>? onChanged;

  /// Se o campo está habilitado
  final bool enabled;

  /// Se permite números decimais
  final bool allowDecimals;

  /// Número de casas decimais (se allowDecimals = true)
  final int decimalDigits;

  /// Valor mínimo permitido
  final double? min;

  /// Valor máximo permitido
  final double? max;

  /// Se deve auto-focar ao criar
  final bool autofocus;

  /// FocusNode customizado
  final FocusNode? focusNode;

  const GenericNumberField({
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
    this.enabled = true,
    this.allowDecimals = false,
    this.decimalDigits = 2,
    this.min,
    this.max,
    this.autofocus = false,
    this.focusNode,
  }) : assert(
          controller == null || initialValue == null,
          'Cannot provide both controller and initialValue',
        );

  String? _validateRange(String? value) {
    if (value == null || value.isEmpty) return null;

    // Remove caracteres não numéricos (exceto vírgula/ponto)
    final cleanValue = value.replaceAll(RegExp(r'[^\d,.]'), '');
    if (cleanValue.isEmpty) return null;

    // Converte para double
    final numValue = double.tryParse(cleanValue.replaceAll(',', '.'));
    if (numValue == null) return 'Valor inválido';

    // Valida range
    if (min != null && numValue < min!) {
      return 'Valor mínimo: $min';
    }
    if (max != null && numValue > max!) {
      return 'Valor máximo: $max';
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    // Formatadores de input
    final formatters = <TextInputFormatter>[
      if (allowDecimals)
        // Permite dígitos, vírgula e ponto
        FilteringTextInputFormatter.allow(RegExp(r'[\d,.]'))
      else
        // Apenas dígitos
        FilteringTextInputFormatter.digitsOnly,
    ];

    return TextFormField(
      controller: controller,
      initialValue: initialValue,
      enabled: enabled,
      keyboardType: TextInputType.numberWithOptions(decimal: allowDecimals),
      inputFormatters: formatters,
      autofocus: autofocus,
      focusNode: focusNode,
      decoration: InputDecoration(
        labelText: labelText,
        hintText: hintText,
        helperText: helperText,
        prefixIcon: prefixIcon,
        prefixText: prefixText,
        suffixIcon: suffixIcon,
        suffixText: suffixText,
      ),
      validator: (value) {
        // Validação customizada do usuário
        final customError = validator?.call(value);
        if (customError != null) return customError;

        // Validação de range
        return _validateRange(value);
      },
      onChanged: onChanged,
    );
  }
}

