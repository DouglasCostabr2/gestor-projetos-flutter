import 'package:flutter/material.dart';

/// Badge reutilizável para indicar o status de um membro da organização
///
/// Características:
/// - Design consistente em toda a aplicação
/// - Cores e textos padronizados
/// - Suporta 3 status: active, inactive, suspended
///
/// Uso:
/// ```dart
/// MemberStatusBadge(
///   status: member['status'],
/// )
/// ```
class MemberStatusBadge extends StatelessWidget {
  final String? status;

  const MemberStatusBadge({
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
    switch (status?.toLowerCase()) {
      case 'active':
        // Ativo - Verde suave
        return _BadgeData(
          label: 'Ativo',
          backgroundColor: Colors.green.shade700.withValues(alpha: 0.3),
          textColor: Colors.green.shade100,
        );
      case 'inactive':
        // Inativo - Cinza suave
        return _BadgeData(
          label: 'Inativo',
          backgroundColor: Colors.grey.shade600.withValues(alpha: 0.25),
          textColor: Colors.grey.shade100,
        );
      case 'suspended':
        // Suspenso - Vermelho suave
        return _BadgeData(
          label: 'Suspenso',
          backgroundColor: Colors.red.shade700.withValues(alpha: 0.3),
          textColor: Colors.red.shade100,
        );
      case 'pending':
        // Pendente - Amarelo suave
        return _BadgeData(
          label: 'Pendente',
          backgroundColor: Colors.orange.shade600.withValues(alpha: 0.3),
          textColor: Colors.orange.shade100,
        );
      default:
        // Desconhecido - Cinza escuro
        return _BadgeData(
          label: 'Desconhecido',
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

