import 'package:flutter/material.dart';
import 'package:gestor_projetos_flutter/modules/modules.dart';
import 'package:gestor_projetos_flutter/widgets/dropdowns/dropdowns.dart';

/// Widget reutilizável para campo de seleção de status
///
/// Características:
/// - Dropdown com 5 status de tarefa
/// - Valores: todo, in_progress, review, waiting, completed
/// - Labels em português: A Fazer, Em Andamento, Revisão, Aguardando, Concluída
/// - Valor padrão: todo
/// - Callback para mudanças
/// - Validação: não permite concluir task com subtasks não concluídas
///
/// Uso:
/// ```dart
/// TaskStatusField(
///   status: _status,
///   taskId: taskId, // Opcional, para validação de subtasks
///   onStatusChanged: (status) {
///     setState(() => _status = status);
///   },
///   enabled: !_saving,
/// )
/// ```
class TaskStatusField extends StatelessWidget {
  final String status;
  final String? taskId; // ID da task para validação de subtasks
  final ValueChanged<String> onStatusChanged;
  final bool enabled;

  const TaskStatusField({
    super.key,
    required this.status,
    this.taskId,
    required this.onStatusChanged,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return GenericDropdownField<String>(
      value: status,
      items: const [
        DropdownItem(value: 'todo', label: 'A Fazer'),
        DropdownItem(value: 'in_progress', label: 'Em Andamento'),
        DropdownItem(value: 'review', label: 'Revisão'),
        DropdownItem(value: 'waiting', label: 'Aguardando'),
        DropdownItem(value: 'completed', label: 'Concluída'),
      ],
      onChanged: (v) => onStatusChanged(v ?? 'todo'),
      labelText: 'Status',
      enabled: enabled,
      onBeforeChanged: (newValue) async {
        // Validar se pode concluir a task
        if (newValue == 'completed' && taskId != null) {
          return await tasksModule.canCompleteTask(taskId!);
        }
        return true;
      },
      validationErrorMessage: 'Não é possível concluir esta tarefa. Todas as sub tarefas devem estar concluídas primeiro.',
    );
  }
}

