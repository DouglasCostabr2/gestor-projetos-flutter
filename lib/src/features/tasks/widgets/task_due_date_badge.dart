import 'package:flutter/material.dart';

/// Badge reutilizável para indicar o status do prazo de uma tarefa
/// 
/// Características:
/// - Design consistente em toda a aplicação
/// - Cores e textos padronizados
/// - Lógica centralizada de cálculo de prazo
/// 
/// Uso:
/// ```dart
/// TaskDueDateBadge(
///   dueDate: task['due_date'],
///   status: task['status'],
/// )
/// ```
class TaskDueDateBadge extends StatelessWidget {
  final dynamic dueDate;
  final String status;
  final int thresholdDays;

  const TaskDueDateBadge({
    super.key,
    required this.dueDate,
    required this.status,
    this.thresholdDays = 2,
  });

  @override
  Widget build(BuildContext context) {
    final badge = _calculateBadge();
    if (badge == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: badge.backgroundColor,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        badge.label,
        style: TextStyle(
          fontSize: 11,
          color: badge.textColor,
          fontWeight: FontWeight.w600,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        softWrap: false,
      ),
    );
  }

  _BadgeData? _calculateBadge() {
    if (dueDate == null) return null;

    DateTime? dueDt;
    try {
      if (dueDate is DateTime) {
        dueDt = dueDate;
      } else if (dueDate is String) {
        dueDt = DateTime.parse(dueDate);
      }
    } catch (_) {
      return null;
    }

    if (dueDt == null) return null;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dueDay = DateTime(dueDt.year, dueDt.month, dueDt.day);
    final dueEod = DateTime(dueDt.year, dueDt.month, dueDt.day, 23, 59, 59);

    // Se está concluída - não mostra badge de prazo
    final statusLower = status.toLowerCase();
    if (statusLower == 'completed' || statusLower == 'done') {
      return null;
    }

    // Se está atrasada - Vermelho
    if (now.isAfter(dueEod)) {
      return _BadgeData(
        label: 'Atrasada',
        backgroundColor: Colors.red.shade700.withValues(alpha: 0.3),
        textColor: Colors.red.shade50,
      );
    }

    final daysDiff = dueDay.difference(today).inDays;

    // Vence hoje - Amarelo
    if (daysDiff == 0) {
      return _BadgeData(
        label: 'Vence hoje',
        backgroundColor: Colors.yellow.shade700.withValues(alpha: 0.3),
        textColor: Colors.yellow.shade50,
      );
    }

    // Vence amanhã - Roxo
    if (daysDiff == 1) {
      return _BadgeData(
        label: 'Vence amanhã',
        backgroundColor: Colors.purple.shade700.withValues(alpha: 0.3),
        textColor: Colors.purple.shade50,
      );
    }

    // Em dia (2 ou mais dias) - Azul
    return _BadgeData(
      label: 'Em dia',
      backgroundColor: Colors.blue.shade700.withValues(alpha: 0.3),
      textColor: Colors.blue.shade50,
    );
  }
}

/// Dados internos do badge
class _BadgeData {
  final String label;
  final Color backgroundColor;
  final Color textColor;

  _BadgeData({
    required this.label,
    required this.backgroundColor,
    required this.textColor,
  });
}

