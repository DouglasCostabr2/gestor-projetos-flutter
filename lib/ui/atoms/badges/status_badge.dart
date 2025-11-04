import 'package:flutter/material.dart';
import 'package:my_business/constants/client_status.dart';

/// Badge reutilizável para indicar o status de prospecção de um cliente
///
/// Características:
/// - Design consistente em toda a aplicação
/// - Cores e textos padronizados
/// - Suporta 5 status principais
///
/// Uso:
/// ```dart
/// StatusBadge(
///   status: client['status'],
/// )
/// ```
class StatusBadge extends StatelessWidget {
  final String status;

  const StatusBadge({
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
    final normalizedStatus = status.toLowerCase();

    switch (normalizedStatus) {
      case 'nao_prospectado':
        // Não Prospectado - Cinza suave
        return _BadgeData(
          label: ClientStatus.getLabel(normalizedStatus),
          backgroundColor: Colors.grey.shade600.withValues(alpha: 0.25),
          textColor: Colors.grey.shade100,
        );
      case 'em_prospeccao':
        // Em Prospecção - Amarelo/Laranja suave
        return _BadgeData(
          label: ClientStatus.getLabel(normalizedStatus),
          backgroundColor: Colors.amber.shade700.withValues(alpha: 0.3),
          textColor: Colors.amber.shade100,
        );
      case 'prospeccao_negada':
        // Prospecção Negada - Vermelho suave
        return _BadgeData(
          label: ClientStatus.getLabel(normalizedStatus),
          backgroundColor: Colors.red.shade700.withValues(alpha: 0.35),
          textColor: Colors.red.shade100,
        );
      case 'neutro':
        // Neutro - Azul acinzentado suave
        return _BadgeData(
          label: ClientStatus.getLabel(normalizedStatus),
          backgroundColor: Colors.blueGrey.shade600.withValues(alpha: 0.3),
          textColor: Colors.blueGrey.shade100,
        );
      case 'ativo':
        // Ativo - Verde suave
        return _BadgeData(
          label: ClientStatus.getLabel(normalizedStatus),
          backgroundColor: Colors.green.shade700.withValues(alpha: 0.3),
          textColor: Colors.green.shade100,
        );
      case 'desativado':
        // Desativado - Roxo suave
        return _BadgeData(
          label: ClientStatus.getLabel(normalizedStatus),
          backgroundColor: Colors.purple.shade600.withValues(alpha: 0.3),
          textColor: Colors.purple.shade100,
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

