import 'package:flutter/material.dart';

/// Widget reutilizável para células de tabela com datas formatadas
/// 
/// Características:
/// - Formato padrão: DD/MM/AAAA
/// - Mostra "-" quando null
/// - Suporte a formato customizado
/// - Parsing automático de strings
/// - Tratamento de erros
/// 
/// Uso:
/// ```dart
/// // Em cellBuilders de tabelas
/// (item) => TableCellDate(
///   date: item['created_at'],
/// )
/// 
/// // Com formato customizado
/// (item) => TableCellDate(
///   date: item['created_at'],
///   format: TableCellDateFormat.full, // DD/MM/AAAA HH:mm
/// )
/// 
/// // Com estilo customizado
/// (item) => TableCellDate(
///   date: item['created_at'],
///   style: TextStyle(color: Colors.grey),
/// )
/// ```
class TableCellDate extends StatelessWidget {
  /// Data a ser formatada (pode ser DateTime, String ou null)
  final dynamic date;
  
  /// Formato da data
  final TableCellDateFormat format;
  
  /// Texto a exibir quando date é null
  final String nullText;
  
  /// Estilo do texto
  final TextStyle? style;

  const TableCellDate({
    super.key,
    required this.date,
    this.format = TableCellDateFormat.short,
    this.nullText = '-',
    this.style,
  });

  /// Converte o valor para DateTime
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

  /// Formata a data de acordo com o formato especificado
  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString();
    
    switch (format) {
      case TableCellDateFormat.short:
        // DD/MM/AAAA
        return '$day/$month/$year';
      
      case TableCellDateFormat.full:
        // DD/MM/AAAA HH:mm
        final hour = date.hour.toString().padLeft(2, '0');
        final minute = date.minute.toString().padLeft(2, '0');
        return '$day/$month/$year $hour:$minute';
      
      case TableCellDateFormat.monthYear:
        // MM/AAAA
        return '$month/$year';
      
      case TableCellDateFormat.dayMonth:
        // DD/MM
        return '$day/$month';
    }
  }

  @override
  Widget build(BuildContext context) {
    final parsedDate = _parseDate();
    
    if (parsedDate == null) {
      return Text(nullText, style: style);
    }
    
    return Text(
      _formatDate(parsedDate),
      style: style,
    );
  }
}

/// Formatos disponíveis para datas em células
enum TableCellDateFormat {
  /// DD/MM/AAAA (padrão)
  short,
  
  /// DD/MM/AAAA HH:mm
  full,
  
  /// MM/AAAA
  monthYear,
  
  /// DD/MM
  dayMonth,
}

