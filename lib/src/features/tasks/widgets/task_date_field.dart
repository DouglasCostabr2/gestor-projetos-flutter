import 'package:flutter/material.dart';
import 'package:my_business/ui/organisms/dialogs/dialogs.dart';
import 'package:my_business/ui/atoms/buttons/buttons.dart';

/// Widget reutilizável para campo de data de vencimento de tarefas
/// 
/// Características:
/// - Campo somente leitura com ícone de calendário
/// - Abre date picker ao clicar
/// - Validação de data no passado
/// - Formatação automática da data
/// - Callback para mudanças
/// 
/// Uso:
/// ```dart
/// TaskDateField(
///   dueDate: _dueDate,
///   onDateChanged: (date) {
///     setState(() => _dueDate = date);
///   },
///   enabled: !_saving,
/// )
/// ```
class TaskDateField extends StatefulWidget {
  final DateTime? dueDate;
  final ValueChanged<DateTime?> onDateChanged;
  final bool enabled;

  const TaskDateField({
    super.key,
    required this.dueDate,
    required this.onDateChanged,
    this.enabled = true,
  });

  @override
  State<TaskDateField> createState() => _TaskDateFieldState();
}

class _TaskDateFieldState extends State<TaskDateField> {
  late TextEditingController _controller;

  /// Formata a data no formato brasileiro dd/mm/aaaa
  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString();
    return '$day/$month/$year';
  }

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.dueDate != null
          ? _formatDate(DateUtils.dateOnly(widget.dueDate!))
          : '',
    );
  }

  @override
  void didUpdateWidget(TaskDateField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.dueDate != widget.dueDate) {
      _controller.text = widget.dueDate != null
          ? _formatDate(DateUtils.dateOnly(widget.dueDate!))
          : '';
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    if (!widget.enabled) return;

    // Diálogo customizado: somente calendário (sem cabeçalho lateral do Material)
    final initial = widget.dueDate ?? DateTime.now();
    DateTime temp = DateUtils.dateOnly(initial);

    final picked = await DialogHelper.show<DateTime>(
      context: context,
      builder: (context) {
        return StandardDialog(
          title: 'Selecionar data',
          width: 420,
          height: 560,
          actions: [
            TextOnlyButton(onPressed: () => Navigator.pop(context), label: 'Cancelar'),
            PrimaryButton(onPressed: () => Navigator.pop(context, temp), label: 'Salvar'),
          ],
          child: StatefulBuilder(
            builder: (context, setState) {
              return CalendarDatePicker(
                initialDate: temp,
                firstDate: DateTime(2020),
                lastDate: DateTime(2100),
                onDateChanged: (d) => setState(() => temp = DateUtils.dateOnly(d)),
              );
            },
          ),
        );
      },
    );

    if (picked != null) {
      final dateOnly = DateUtils.dateOnly(picked);
      _controller.text = _formatDate(dateOnly);
      widget.onDateChanged(dateOnly);
    }
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: _controller,
      readOnly: true,
      enabled: widget.enabled,
      decoration: const InputDecoration(
        labelText: 'Data de conclusão',
        suffixIcon: Icon(Icons.event),
      ),
      onTap: _pickDate,
      validator: (_) {
        if (widget.dueDate != null) {
          final today = DateUtils.dateOnly(DateTime.now());
          if (widget.dueDate!.isBefore(today)) {
            return 'Data no passado';
          }
        }
        return null;
      },
    );
  }
}

