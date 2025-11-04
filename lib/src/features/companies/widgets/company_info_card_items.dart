import 'package:flutter/material.dart';
import 'package:my_business/ui/organisms/cards/cards.dart';

/// Widgets auxiliares para construir os itens dos cards de informações da empresa
class CompanyInfoCardItems {
  CompanyInfoCardItems._(); // Private constructor - utility class

  /// Cria o item "Nome da Empresa"
  static InfoCardItem buildCompanyNameItem(BuildContext context, Map<String, dynamic> company) {
    return InfoCardItem(
      label: 'Nome da Empresa',
      labelContentSpacing: 22,
      content: Text(
        company['name'] ?? 'Sem nome',
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

  /// Cria o item "Notas/Observações"
  static InfoCardItem buildNotesItem(BuildContext context, Map<String, dynamic> company) {
    final notes = company['notes'] as String?;
    return InfoCardItem(
      label: 'Notas/Observações',
      labelContentSpacing: 18,
      content: Text(
        notes != null && notes.isNotEmpty ? notes : '-',
        style: Theme.of(context).textTheme.bodySmall,
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

