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
        // Não iniciado - Cinza
        return _BadgeData(
          label: 'Não iniciado',
          backgroundColor: Colors.grey.shade700.withValues(alpha: 0.3),
          textColor: Colors.grey.shade50,
        );
      case 'negotiation':
      case 'em_negociacao':
        // Em negociação - Roxo
        return _BadgeData(
          label: 'Em negociação',
          backgroundColor: Colors.purple.shade700.withValues(alpha: 0.3),
          textColor: Colors.purple.shade50,
        );
      case 'in_progress':
      case 'em_andamento':
        // Em andamento - Azul
        return _BadgeData(
          label: 'Em andamento',
          backgroundColor: Colors.blue.shade700.withValues(alpha: 0.3),
          textColor: Colors.blue.shade50,
        );
      case 'paused':
      case 'pausado':
        // Pausado - Laranja
        return _BadgeData(
          label: 'Pausado',
          backgroundColor: Colors.orange.shade700.withValues(alpha: 0.3),
          textColor: Colors.orange.shade50,
        );
      case 'completed':
      case 'concluido':
        // Concluído - Verde
        return _BadgeData(
          label: 'Concluído',
          backgroundColor: Colors.green.shade700.withValues(alpha: 0.3),
          textColor: Colors.green.shade50,
        );
      case 'cancelled':
      case 'cancelado':
        // Cancelado - Vermelho
        return _BadgeData(
          label: 'Cancelado',
          backgroundColor: Colors.red.shade700.withValues(alpha: 0.3),
          textColor: Colors.red.shade50,
        );
      // Manter compatibilidade com status antigo
      case 'active':
      case 'ativo':
        return _BadgeData(
          label: 'Em andamento',
          backgroundColor: Colors.blue.shade700.withValues(alpha: 0.3),
          textColor: Colors.blue.shade50,
        );
      case 'inactive':
      case 'inativo':
        return _BadgeData(
          label: 'Pausado',
          backgroundColor: Colors.orange.shade700.withValues(alpha: 0.3),
          textColor: Colors.orange.shade50,
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

