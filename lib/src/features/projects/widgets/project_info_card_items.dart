import 'package:flutter/material.dart';
import 'package:my_business/ui/organisms/cards/cards.dart';
import 'project_status_badge.dart';

/// Widgets auxiliares para construir os itens dos cards de informações do projeto
class ProjectInfoCardItems {
  ProjectInfoCardItems._(); // Private constructor - utility class

  /// Cria o item "Nome do Projeto"
  static InfoCardItem buildProjectNameItem(BuildContext context, Map<String, dynamic> project) {
    return InfoCardItem(
      label: 'Nome do Projeto',
      labelContentSpacing: 22,
      content: Text(
        project['name'] ?? 'Sem nome',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  /// Cria o item "Cliente" (clicável com avatar)
  ///
  /// Delega para o helper compartilhado para evitar duplicação de código
  static InfoCardItem buildClientItem(
    BuildContext context,
    String? clientId,
    String clientName,
    String? clientAvatarUrl, {
    bool canNavigate = true,
  }) {
    return InfoCardItemsHelpers.buildClientItem(
      context,
      clientId,
      clientName,
      clientAvatarUrl,
      canNavigate: canNavigate,
    );
  }

  /// Cria o item "Status"
  static InfoCardItem buildStatusItem(BuildContext context, Map<String, dynamic> project) {
    return InfoCardItem(
      label: 'Status',
      labelContentSpacing: 18,
      // Retorna null para não ter largura fixa (usa "hug content")
      widthCalculator: (itemsPerRow, adjustedItemWidth) => null,
      content: ProjectStatusBadge(status: project['status'] ?? 'active'),
    );
  }

  /// Cria o item "Descrição"
  static InfoCardItem buildDescriptionItem(BuildContext context, Map<String, dynamic> project) {
    final description = project['description'] as String?;
    return InfoCardItem(
      label: 'Descrição',
      labelContentSpacing: 18,
      content: Text(
        description != null && description.isNotEmpty ? description : '-',
        style: Theme.of(context).textTheme.bodySmall,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

