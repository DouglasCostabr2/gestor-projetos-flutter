import 'package:flutter/material.dart';

/// Badge reutilizável para indicar o status de um projeto
/// 
/// Características:
/// - Design consistente em toda a aplicação
/// - Cores e textos padronizados
/// - Suporta 6 status principais
/// 
/// Uso:
/// ```dart
/// ProjectStatusBadge(
///   status: project['status'],
/// )
/// ```
class ProjectStatusBadge extends StatelessWidget {
  final String status;

  const ProjectStatusBadge({
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
      case 'not_started':
      case 'nao_iniciado':
        // Não iniciado - Cinza suave
        return _BadgeData(
          label: 'Não iniciado',
          backgroundColor: Colors.grey.shade600.withValues(alpha: 0.25),
          textColor: Colors.grey.shade100,
        );
      case 'negotiation':
      case 'em_negociacao':
        // Em negociação - Roxo suave
        return _BadgeData(
          label: 'Em negociação',
          backgroundColor: Colors.purple.shade600.withValues(alpha: 0.3),
          textColor: Colors.purple.shade100,
        );
      case 'in_progress':
      case 'em_andamento':
        // Em andamento - Azul suave
        return _BadgeData(
          label: 'Em andamento',
          backgroundColor: Colors.blue.shade600.withValues(alpha: 0.3),
          textColor: Colors.blue.shade100,
        );
      case 'paused':
      case 'pausado':
        // Pausado - Laranja suave
        return _BadgeData(
          label: 'Pausado',
          backgroundColor: Colors.orange.shade600.withValues(alpha: 0.3),
          textColor: Colors.orange.shade100,
        );
      case 'completed':
      case 'concluido':
        // Concluído - Verde suave
        return _BadgeData(
          label: 'Concluído',
          backgroundColor: Colors.green.shade700.withValues(alpha: 0.3),
          textColor: Colors.green.shade100,
        );
      case 'cancelled':
      case 'cancelado':
        // Cancelado - Vermelho suave
        return _BadgeData(
          label: 'Cancelado',
          backgroundColor: Colors.red.shade700.withValues(alpha: 0.3),
          textColor: Colors.red.shade100,
        );
      // Manter compatibilidade com status antigo
      case 'active':
      case 'ativo':
        return _BadgeData(
          label: 'Em andamento',
          backgroundColor: Colors.blue.shade600.withValues(alpha: 0.3),
          textColor: Colors.blue.shade100,
        );
      case 'inactive':
      case 'inativo':
        return _BadgeData(
          label: 'Pausado',
          backgroundColor: Colors.orange.shade600.withValues(alpha: 0.3),
          textColor: Colors.orange.shade100,
        );
      default:
        return _BadgeData(
          label: status,
          backgroundColor: Colors.grey.shade600.withValues(alpha: 0.25),
          textColor: Colors.grey.shade100,
        );
    }
  }
}

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

