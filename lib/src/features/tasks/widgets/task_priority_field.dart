import 'package:flutter/material.dart';
import 'package:my_business/ui/molecules/dropdowns/dropdowns.dart';

/// Widget reutilizável para campo de seleção de prioridade
///
/// Características:
/// - Dropdown com 4 níveis de prioridade
/// - Valores: low, medium, high, urgent
/// - Labels em português
/// - Valor padrão: medium
/// - Callback para mudanças
///
/// Uso:
/// ```dart
/// TaskPriorityField(
///   priority: _priority,
///   onPriorityChanged: (priority) {
///     setState(() => _priority = priority);
///   },
///   enabled: !_saving,
/// )
/// ```
class TaskPriorityField extends StatelessWidget {
  final String priority;
  final ValueChanged<String> onPriorityChanged;
  final bool enabled;

  const TaskPriorityField({
    super.key,
    required this.priority,
    required this.onPriorityChanged,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return GenericDropdownField<String>(
          value: priority,
          items: const [
            DropdownItem(value: 'low', label: 'Baixa'),
            DropdownItem(value: 'medium', label: 'Média'),
            DropdownItem(value: 'high', label: 'Alta'),
            DropdownItem(value: 'urgent', label: 'Urgente'),
          ],
          onChanged: (v) => onPriorityChanged(v ?? 'medium'),
          labelText: 'Prioridade',
          enabled: enabled,
          width: constraints.maxWidth,
        );
      },
    );
  }
}

