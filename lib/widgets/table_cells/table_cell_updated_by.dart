import 'package:flutter/material.dart';
import '../cached_avatar.dart';
import 'table_cell_date.dart';

/// Widget reutilizável para células de tabela com info de última atualização
/// 
/// Características:
/// - Mostra data + avatar + nome da pessoa
/// - Layout vertical ou horizontal
/// - Formatação automática de data
/// - Suporte a dados null
/// - Usa CachedAvatar para performance
/// 
/// Uso:
/// ```dart
/// // Em cellBuilders de tabelas - Layout vertical (padrão)
/// (item) => TableCellUpdatedBy(
///   date: item['updated_at'],
///   profile: item['updated_by_profile'],
/// )
/// 
/// // Layout horizontal
/// (item) => TableCellUpdatedBy(
///   date: item['updated_at'],
///   profile: item['updated_by_profile'],
///   layout: TableCellUpdatedByLayout.horizontal,
/// )
/// 
/// // Apenas data (sem pessoa)
/// (item) => TableCellUpdatedBy(
///   date: item['updated_at'],
/// )
/// ```
class TableCellUpdatedBy extends StatelessWidget {
  /// Data da atualização (DateTime ou String)
  final dynamic date;
  
  /// Perfil da pessoa que atualizou (Map com: id, full_name, avatar_url)
  final Map<String, dynamic>? profile;
  
  /// Layout (vertical ou horizontal)
  final TableCellUpdatedByLayout layout;
  
  /// Formato da data
  final TableCellDateFormat dateFormat;
  
  /// Tamanho do avatar
  final double avatarSize;
  
  /// Texto quando não há dados
  final String nullText;
  
  /// Estilo do texto da data
  final TextStyle? dateStyle;
  
  /// Estilo do texto do nome
  final TextStyle? nameStyle;

  const TableCellUpdatedBy({
    super.key,
    required this.date,
    this.profile,
    this.layout = TableCellUpdatedByLayout.vertical,
    this.dateFormat = TableCellDateFormat.short,
    this.avatarSize = 10.0,
    this.nullText = '-',
    this.dateStyle,
    this.nameStyle,
  });

  DateTime? _parseDate() {
    if (date == null) return null;
    
    if (date is DateTime) {
      return date as DateTime;
    }
    
    if (date is String) {
      try {
        return DateTime.parse(date as String);
      } catch (e) {
        return null;
      }
    }
    
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final parsedDate = _parseDate();
    
    // Se não há data, mostrar texto null
    if (parsedDate == null) {
      return Text(nullText);
    }
    
    // Se não há perfil, mostrar apenas a data
    if (profile == null) {
      return TableCellDate(
        date: parsedDate,
        format: dateFormat,
        style: dateStyle,
      );
    }
    
    final avatarUrl = profile!['avatar_url'] as String?;
    final fullName = profile!['full_name'] as String? ?? 'Sem nome';
    
    // Layout vertical
    if (layout == TableCellUpdatedByLayout.vertical) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Data primeiro
          TableCellDate(
            date: parsedDate,
            format: dateFormat,
            style: dateStyle ?? const TextStyle(fontSize: 12),
          ),
          const SizedBox(height: 4),
          // Avatar e nome abaixo
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CachedAvatar(
                avatarUrl: avatarUrl,
                radius: avatarSize,
                fallbackIcon: Icons.person,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  fullName,
                  style: nameStyle ?? const TextStyle(fontSize: 11),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      );
    }
    
    // Layout horizontal
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        CachedAvatar(
          avatarUrl: avatarUrl,
          radius: avatarSize,
          fallbackIcon: Icons.person,
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                fullName,
                style: nameStyle ?? const TextStyle(fontSize: 11),
                overflow: TextOverflow.ellipsis,
              ),
              TableCellDate(
                date: parsedDate,
                format: dateFormat,
                style: dateStyle ?? const TextStyle(fontSize: 10, color: Colors.grey),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Layout disponível para TableCellUpdatedBy
enum TableCellUpdatedByLayout {
  /// Data em cima, avatar + nome embaixo
  vertical,
  
  /// Avatar à esquerda, nome + data à direita
  horizontal,
}

/// Variante simplificada que mostra apenas data + nome (sem avatar)
class TableCellUpdatedBySimple extends StatelessWidget {
  final dynamic date;
  final String? userName;
  final TableCellDateFormat dateFormat;
  final String nullText;

  const TableCellUpdatedBySimple({
    super.key,
    required this.date,
    this.userName,
    this.dateFormat = TableCellDateFormat.short,
    this.nullText = '-',
  });

  @override
  Widget build(BuildContext context) {
    if (date == null) {
      return Text(nullText);
    }
    
    if (userName == null || userName!.isEmpty) {
      return TableCellDate(date: date, format: dateFormat);
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        TableCellDate(
          date: date,
          format: dateFormat,
          style: const TextStyle(fontSize: 12),
        ),
        const SizedBox(height: 2),
        Text(
          userName!,
          style: const TextStyle(fontSize: 11, color: Colors.grey),
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

