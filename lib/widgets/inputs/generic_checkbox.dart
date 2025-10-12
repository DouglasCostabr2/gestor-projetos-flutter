import 'package:flutter/material.dart';

/// Widget genérico para checkbox com label
///
/// Características:
/// - Design consistente com tema global
/// - Label customizável (à direita ou esquerda)
/// - Validação opcional
/// - Suporte a estados (enabled/disabled)
/// - Cores customizáveis
/// - Tristate opcional (null, true, false)
///
/// Exemplo de uso básico:
/// ```dart
/// GenericCheckbox(
///   value: _isActive,
///   onChanged: (value) => setState(() => _isActive = value),
///   label: 'Ativo',
///   enabled: !_saving,
/// )
/// ```
///
/// Exemplo com validação:
/// ```dart
/// GenericCheckbox(
///   value: _acceptTerms,
///   onChanged: (value) => setState(() => _acceptTerms = value),
///   label: 'Aceito os termos e condições *',
///   validator: (value) => value != true ? 'Você deve aceitar os termos' : null,
/// )
/// ```
///
/// Exemplo tristate:
/// ```dart
/// GenericCheckbox(
///   value: _selectAll,
///   onChanged: (value) => setState(() => _selectAll = value),
///   label: 'Selecionar todos',
///   tristate: true,
/// )
/// ```
///
/// Exemplo sem label (apenas checkbox):
/// ```dart
/// GenericCheckbox(
///   value: _isChecked,
///   onChanged: (value) => setState(() => _isChecked = value),
/// )
/// ```
class GenericCheckbox extends StatelessWidget {
  /// Valor atual do checkbox
  final bool? value;

  /// Callback quando o valor muda
  final ValueChanged<bool?>? onChanged;

  /// Texto do label (opcional)
  final String? label;

  /// Estilo do texto do label
  final TextStyle? labelStyle;

  /// Posição do label em relação ao checkbox
  final CheckboxLabelPosition labelPosition;

  /// Se o checkbox está habilitado
  final bool enabled;

  /// Se permite estado null (tristate)
  final bool tristate;

  /// Cor quando marcado
  final Color? activeColor;

  /// Cor da borda quando desmarcado
  final Color? checkColor;

  /// Função de validação (retorna mensagem de erro ou null)
  final String? Function(bool?)? validator;

  /// Mensagem de erro (se houver validação)
  final String? errorText;

  /// Espaçamento entre checkbox e label
  final double spacing;

  /// Padding ao redor do componente
  final EdgeInsetsGeometry? padding;

  /// Callback quando o checkbox é tocado (alternativa ao onChanged)
  final VoidCallback? onTap;

  const GenericCheckbox({
    super.key,
    required this.value,
    this.onChanged,
    this.label,
    this.labelStyle,
    this.labelPosition = CheckboxLabelPosition.right,
    this.enabled = true,
    this.tristate = false,
    this.activeColor,
    this.checkColor,
    this.validator,
    this.errorText,
    this.spacing = 8.0,
    this.padding,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Validação
    String? validationError;
    if (validator != null) {
      validationError = validator!(value);
    }
    final displayError = errorText ?? validationError;

    // Estilo do label
    final effectiveLabelStyle = labelStyle ??
        TextStyle(
          color: enabled ? colorScheme.onSurface : colorScheme.onSurface.withOpacity(0.38),
          fontSize: 14,
        );

    // Widget do checkbox
    final checkboxWidget = Checkbox(
      value: value,
      onChanged: enabled ? onChanged : null,
      tristate: tristate,
      activeColor: activeColor ?? colorScheme.primary,
      checkColor: checkColor ?? colorScheme.onPrimary,
      side: BorderSide(
        color: enabled
            ? (displayError != null ? colorScheme.error : colorScheme.outline)
            : colorScheme.onSurface.withOpacity(0.38),
        width: 2,
      ),
    );

    // Widget do label
    Widget? labelWidget;
    if (label != null) {
      labelWidget = Text(
        label!,
        style: effectiveLabelStyle,
      );
    }

    // Combinar checkbox e label
    Widget content;
    if (labelWidget == null) {
      // Apenas checkbox
      content = checkboxWidget;
    } else {
      // Checkbox + label
      final children = labelPosition == CheckboxLabelPosition.right
          ? [checkboxWidget, SizedBox(width: spacing), Expanded(child: labelWidget)]
          : [Expanded(child: labelWidget), SizedBox(width: spacing), checkboxWidget];

      content = InkWell(
        onTap: enabled && onChanged != null
            ? () {
                if (onTap != null) {
                  onTap!();
                } else {
                  // Toggle automático
                  if (tristate) {
                    // Ciclo: false -> true -> null -> false
                    if (value == false) {
                      onChanged!(true);
                    } else if (value == true) {
                      onChanged!(null);
                    } else {
                      onChanged!(false);
                    }
                  } else {
                    // Toggle simples: true <-> false
                    onChanged!(!(value ?? false));
                  }
                }
              }
            : null,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: children,
          ),
        ),
      );
    }

    // Adicionar padding se especificado
    if (padding != null) {
      content = Padding(
        padding: padding!,
        child: content,
      );
    }

    // Adicionar mensagem de erro se houver
    if (displayError != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          content,
          Padding(
            padding: const EdgeInsets.only(left: 12, top: 4),
            child: Text(
              displayError,
              style: TextStyle(
                color: colorScheme.error,
                fontSize: 12,
              ),
            ),
          ),
        ],
      );
    }

    return content;
  }
}

/// Posição do label em relação ao checkbox
enum CheckboxLabelPosition {
  /// Label à esquerda do checkbox
  left,

  /// Label à direita do checkbox
  right,
}

