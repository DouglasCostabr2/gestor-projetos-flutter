import 'package:flutter/material.dart';
import 'package:my_business/ui/molecules/dropdowns/dropdowns.dart';

/// Widget reutilizável para campo de seleção de status de projeto
///
/// Características:
/// - Dropdown com 6 status de projeto
/// - Valores: not_started, negotiation, in_progress, paused, completed, cancelled
/// - Labels em português
/// - Valor padrão: not_started
/// - Callback para mudanças
///
/// Uso:
/// ```dart
/// ProjectStatusField(
///   status: _status,
///   onStatusChanged: (status) {
///     setState(() => _status = status);
///   },
///   enabled: !_saving,
/// )
/// ```
class ProjectStatusField extends StatelessWidget {
  final String status;
  final ValueChanged<String> onStatusChanged;
  final bool enabled;

  const ProjectStatusField({
    super.key,
    required this.status,
    required this.onStatusChanged,
    this.enabled = true,
  });

  String _normalizeStatus(String status) {
    if (status == 'active' || status == 'ativo') return 'in_progress';
    if (status == 'inactive' || status == 'inativo') return 'paused';
    return status;
  }

  @override
  Widget build(BuildContext context) {
    return GenericDropdownField<String>(
      value: _normalizeStatus(status),
      items: const [
        DropdownItem(value: 'not_started', label: 'Não iniciado'),
        DropdownItem(value: 'negotiation', label: 'Em negociação'),
        DropdownItem(value: 'in_progress', label: 'Em andamento'),
        DropdownItem(value: 'paused', label: 'Pausado'),
        DropdownItem(value: 'completed', label: 'Concluído'),
        DropdownItem(value: 'cancelled', label: 'Cancelado'),
      ],
      onChanged: (v) {
        if (v != null) onStatusChanged(v);
      },
      labelText: 'Status',
      enabled: enabled,
      width: 200,
    );
  }
}

