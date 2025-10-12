import 'package:flutter/material.dart';

/// Widget genérico para campo de email
///
/// Características:
/// - Design consistente com tema global
/// - Validação de email integrada
/// - Teclado de email automático
/// - Ícone de email padrão
///
/// Exemplo de uso:
/// ```dart
/// GenericEmailField(
///   controller: _emailController,
///   labelText: 'Email *',
///   hintText: 'seu@email.com',
///   required: true,
///   enabled: !_saving,
/// )
/// ```
class GenericEmailField extends StatelessWidget {
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

  /// Função de validação customizada (adicional à validação de email)
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

  /// Mensagem de erro quando email inválido
  final String invalidEmailMessage;

  /// Mensagem de erro quando campo vazio (se required = true)
  final String requiredMessage;

  const GenericEmailField({
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
    this.invalidEmailMessage = 'Email inválido',
    this.requiredMessage = 'Campo obrigatório',
  }) : assert(
          controller == null || initialValue == null,
          'Cannot provide both controller and initialValue',
        );

  /// Valida formato de email
  bool _isValidEmail(String email) {
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );
    return emailRegex.hasMatch(email);
  }

  String? _validate(String? value) {
    // Campo vazio
    if (value == null || value.trim().isEmpty) {
      return required ? requiredMessage : null;
    }

    // Validação de formato
    if (!_isValidEmail(value.trim())) {
      return invalidEmailMessage;
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
      keyboardType: TextInputType.emailAddress,
      textCapitalization: TextCapitalization.none,
      autofocus: autofocus,
      focusNode: focusNode,
      decoration: InputDecoration(
        labelText: labelText,
        hintText: hintText,
        helperText: helperText,
        prefixIcon: const Icon(Icons.email_outlined),
      ),
      validator: _validate,
      onChanged: onChanged,
    );
  }
}

