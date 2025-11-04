import 'package:flutter/material.dart';

/// Badge reutilizável para indicar o status de produtos e pacotes do catálogo
/// 
/// Características:
/// - Design consistente em toda a aplicação
/// - Cores e textos padronizados
/// - Suporta 4 status principais: active, inactive, discontinued, coming_soon
/// 
/// Uso:
/// ```dart
/// CatalogStatusBadge(
///   status: product['status'],
/// )
/// ```
class CatalogStatusBadge extends StatelessWidget {
  final String status;

  const CatalogStatusBadge({
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
      case 'active':
      case 'ativo':
        // Ativo - Verde suave
        return _BadgeData(
          label: 'Ativo',
          backgroundColor: Colors.green.shade700.withValues(alpha: 0.3),
          textColor: Colors.green.shade100,
        );
      case 'inactive':
      case 'inativo':
        // Inativo - Laranja suave
        return _BadgeData(
          label: 'Inativo',
          backgroundColor: Colors.deepOrange.shade600.withValues(alpha: 0.3),
          textColor: Colors.deepOrange.shade100,
        );
      case 'discontinued':
      case 'descontinuado':
        // Descontinuado - Vermelho suave
        return _BadgeData(
          label: 'Descontinuado',
          backgroundColor: Colors.red.shade800.withValues(alpha: 0.35),
          textColor: Colors.red.shade100,
        );
      case 'coming_soon':
      case 'em_breve':
        // Em breve - Azul suave
        return _BadgeData(
          label: 'Em breve',
          backgroundColor: Colors.blue.shade600.withValues(alpha: 0.3),
          textColor: Colors.blue.shade100,
        );
      default:
        return _BadgeData(
          label: status,
          backgroundColor: Colors.grey.shade700.withValues(alpha: 0.3),
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

