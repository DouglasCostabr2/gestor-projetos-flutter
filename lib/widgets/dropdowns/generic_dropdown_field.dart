import 'package:flutter/material.dart';

/// Modelo para item de dropdown genérico
class DropdownItem<T> {
  final T value;
  final String label;
  final Widget? leadingIcon;
  final Widget? trailingIcon;

  const DropdownItem({
    required this.value,
    required this.label,
    this.leadingIcon,
    this.trailingIcon,
  });
}

/// Widget genérico para dropdown simples com lista estática (Material 3 DropdownMenu)
///
/// Características:
/// - Type-safe com generics
/// - Design Material 3 (igual ao TableSearchFilterBar)
/// - Suporta valores nullable
/// - Callback para mudanças
/// - Suporta ícones leading/trailing
/// - Largura responsiva ou fixa
///
/// Exemplo de uso:
/// ```dart
/// GenericDropdownField<String>(
///   value: _selectedValue,
///   items: [
///     DropdownItem(value: 'opt1', label: 'Opção 1'),
///     DropdownItem(value: 'opt2', label: 'Opção 2'),
///   ],
///   onChanged: (value) => setState(() => _selectedValue = value),
///   labelText: 'Selecione uma opção',
///   enabled: !_saving,
/// )
/// ```
///
/// Exemplo com valores nullable:
/// ```dart
/// GenericDropdownField<String?>(
///   value: _selectedValue,
///   items: [
///     DropdownItem(value: null, label: 'Nenhum'),
///     DropdownItem(value: 'opt1', label: 'Opção 1'),
///   ],
///   onChanged: (value) => setState(() => _selectedValue = value),
///   labelText: 'Opcional',
/// )
/// ```
///
/// Exemplo com ícones:
/// ```dart
/// GenericDropdownField<String>(
///   value: _status,
///   items: [
///     DropdownItem(value: 'active', label: 'Ativo', leadingIcon: Icon(Icons.check_circle)),
///     DropdownItem(value: 'inactive', label: 'Inativo', leadingIcon: Icon(Icons.cancel)),
///   ],
///   onChanged: (value) => setState(() => _status = value),
/// )
/// ```
class GenericDropdownField<T> extends StatefulWidget {
  /// Valor atual selecionado
  final T? value;

  /// Lista de itens do dropdown
  final List<DropdownItem<T>> items;

  /// Callback quando o valor muda
  final ValueChanged<T?>? onChanged;

  /// Texto do label
  final String? labelText;

  /// Texto de hint
  final String? hintText;

  /// Se o campo está habilitado
  final bool enabled;

  /// Largura do dropdown (null = responsiva automática)
  final double? width;

  /// Callback chamado antes de mudar o valor (para validações assíncronas)
  /// Retorna true se pode mudar, false caso contrário
  final Future<bool> Function(T? newValue)? onBeforeChanged;

  /// Mensagem de erro a ser exibida quando onBeforeChanged retorna false
  final String? validationErrorMessage;

  const GenericDropdownField({
    super.key,
    this.value,
    required this.items,
    this.onChanged,
    this.labelText,
    this.hintText,
    this.enabled = true,
    this.width,
    this.onBeforeChanged,
    this.validationErrorMessage,
  });

  @override
  State<GenericDropdownField<T>> createState() => _GenericDropdownFieldState<T>();
}

class _GenericDropdownFieldState<T> extends State<GenericDropdownField<T>> {
  T? _currentValue;

  @override
  void initState() {
    super.initState();
    _currentValue = widget.value;
  }

  @override
  void didUpdateWidget(GenericDropdownField<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _currentValue = widget.value;
    }
  }

  Future<void> _handleChange(T? newValue) async {
    // Se tem validação antes de mudar
    if (widget.onBeforeChanged != null) {
      final messenger = ScaffoldMessenger.of(context);
      final canChange = await widget.onBeforeChanged!(newValue);
      
      if (!canChange) {
        if (!mounted) return;
        
        // Mostra mensagem de erro
        messenger.showSnackBar(
          SnackBar(
            content: Text(widget.validationErrorMessage ?? 'Não é possível alterar este valor.'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
        
        // Force rebuild para resetar o dropdown
        setState(() {});
        return;
      }
    }

    // Atualiza o valor
    setState(() {
      _currentValue = newValue;
    });
    
    widget.onChanged?.call(newValue);
  }

  @override
  Widget build(BuildContext context) {
    // Verifica se o valor atual está na lista de itens
    final validValue = widget.items.any((item) => item.value == _currentValue)
        ? _currentValue
        : null;

    final dropdown = DropdownMenu<T>(
      key: ValueKey(_currentValue),
      initialSelection: validValue,
      enabled: widget.enabled,
      label: widget.labelText != null ? Text(widget.labelText!) : null,
      hintText: widget.hintText,
      width: widget.width,
      dropdownMenuEntries: widget.items.map((item) {
        return DropdownMenuEntry<T>(
          value: item.value,
          label: item.label,
          leadingIcon: item.leadingIcon,
          trailingIcon: item.trailingIcon,
        );
      }).toList(),
      onSelected: widget.enabled ? _handleChange : null,
    );

    return dropdown;
  }
}

