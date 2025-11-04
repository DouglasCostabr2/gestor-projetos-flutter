import 'package:flutter/material.dart';

/// Badge reutilizável para indicar a função (role) de um usuário
///
/// Características:
/// - Design consistente em toda a aplicação
/// - Cores e textos padronizados
/// - Suporta 7 roles principais: owner, admin, gestor, financeiro, designer, cliente, usuario
///
/// Uso:
/// ```dart
/// RoleBadge(
///   role: member['role'],
/// )
/// ```
class RoleBadge extends StatelessWidget {
  final String? role;

  const RoleBadge({
    super.key,
    required this.role,
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
    switch (role?.toLowerCase()) {
      case 'owner':
        // Proprietário - Rosa suave
        return _BadgeData(
          label: 'Proprietário',
          backgroundColor: Colors.pink.shade700.withValues(alpha: 0.3),
          textColor: Colors.pink.shade100,
        );
      case 'admin':
        // Administrador - Roxo suave
        return _BadgeData(
          label: 'Administrador',
          backgroundColor: Colors.purple.shade600.withValues(alpha: 0.3),
          textColor: Colors.purple.shade100,
        );
      case 'gestor':
        // Gestor - Azul suave
        return _BadgeData(
          label: 'Gestor',
          backgroundColor: Colors.blue.shade600.withValues(alpha: 0.3),
          textColor: Colors.blue.shade100,
        );
      case 'financeiro':
        // Financeiro - Verde suave
        return _BadgeData(
          label: 'Financeiro',
          backgroundColor: Colors.green.shade700.withValues(alpha: 0.3),
          textColor: Colors.green.shade100,
        );
      case 'designer':
        // Designer - Laranja suave
        return _BadgeData(
          label: 'Designer',
          backgroundColor: Colors.orange.shade600.withValues(alpha: 0.3),
          textColor: Colors.orange.shade100,
        );
      case 'cliente':
        // Cliente - Ciano suave
        return _BadgeData(
          label: 'Cliente',
          backgroundColor: Colors.cyan.shade700.withValues(alpha: 0.3),
          textColor: Colors.cyan.shade100,
        );
      case 'usuario':
        // Usuário - Cinza suave
        return _BadgeData(
          label: 'Usuário',
          backgroundColor: Colors.grey.shade600.withValues(alpha: 0.25),
          textColor: Colors.grey.shade100,
        );
      default:
        // Sem role - Cinza escuro
        return _BadgeData(
          label: 'Sem role',
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

