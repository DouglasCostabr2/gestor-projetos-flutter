import 'package:flutter/material.dart';

/// Badge reutilizável para indicar o status de uma tarefa
/// 
/// Características:
/// - Design consistente em toda a aplicação
/// - Cores e textos padronizados
/// - Suporta 5 status principais
/// 
/// Uso:
/// ```dart
/// TaskStatusBadge(
///   status: task['status'],
/// )
/// ```
class TaskStatusBadge extends StatelessWidget {
  final String status;

  const TaskStatusBadge({
    super.key,
    required this.status,
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
    switch (status.toLowerCase()) {
      case 'todo':
        // A fazer - Cinza azulado suave
        return _BadgeData(
          label: 'A fazer',
          backgroundColor: Colors.blueGrey.shade600.withValues(alpha: 0.25),
          textColor: Colors.blueGrey.shade100,
        );
      case 'in_progress':
        // Em andamento - Azul suave
        return _BadgeData(
          label: 'Em andamento',
          backgroundColor: Colors.indigo.shade600.withValues(alpha: 0.3),
          textColor: Colors.indigo.shade100,
        );
      case 'review':
        // Em revisão - Amarelo suave
        return _BadgeData(
          label: 'Em revisão',
          backgroundColor: Colors.amber.shade700.withValues(alpha: 0.3),
          textColor: Colors.amber.shade100,
        );
      case 'waiting':
      case 'aguardando':
        // Aguardando - Marrom suave
        return _BadgeData(
          label: 'Aguardando',
          backgroundColor: Colors.brown.shade600.withValues(alpha: 0.3),
          textColor: Colors.brown.shade100,
        );
      case 'completed':
      case 'done':
        // Concluída - Verde suave
        return _BadgeData(
          label: 'Concluída',
          backgroundColor: Colors.green.shade700.withValues(alpha: 0.3),
          textColor: Colors.green.shade100,
        );
      case 'cancelled':
        // Cancelada - Rosa suave
        return _BadgeData(
          label: 'Cancelada',
          backgroundColor: Colors.pink.shade800.withValues(alpha: 0.3),
          textColor: Colors.pink.shade100,
        );
      default:
        return _BadgeData(
          label: status,
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

