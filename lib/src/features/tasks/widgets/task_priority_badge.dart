import 'package:flutter/material.dart';

/// Badge reutilizável para indicar a prioridade de uma tarefa
/// 
/// Características:
/// - Design consistente em toda a aplicação
/// - Cores e textos padronizados
/// - Suporta 4 níveis de prioridade
/// 
/// Uso:
/// ```dart
/// TaskPriorityBadge(
///   priority: task['priority'],
/// )
/// ```
class TaskPriorityBadge extends StatelessWidget {
  final String priority;

  const TaskPriorityBadge({
    super.key,
    required this.priority,
  });

  @override
  Widget build(BuildContext context) {
    final badge = _calculateBadge();

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

  _BadgeData _calculateBadge() {
    switch (priority.toLowerCase()) {
      case 'low':
        // Baixa - Azul
        return _BadgeData(
          label: 'Baixa',
          backgroundColor: Colors.blue.shade700.withValues(alpha: 0.3),
          textColor: Colors.blue.shade50,
        );
      case 'medium':
        // Média - Verde
        return _BadgeData(
          label: 'Média',
          backgroundColor: Colors.green.shade700.withValues(alpha: 0.3),
          textColor: Colors.green.shade50,
        );
      case 'high':
        // Alta - Amarela
        return _BadgeData(
          label: 'Alta',
          backgroundColor: Colors.yellow.shade700.withValues(alpha: 0.3),
          textColor: Colors.yellow.shade50,
        );
      case 'urgent':
        // Urgente - Vermelho
        return _BadgeData(
          label: 'Urgente',
          backgroundColor: Colors.red.shade700.withValues(alpha: 0.3),
          textColor: Colors.red.shade50,
        );
      default:
        return _BadgeData(
          label: priority,
          backgroundColor: Colors.grey.shade700.withValues(alpha: 0.3),
          textColor: Colors.grey.shade50,
        );
    }
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

