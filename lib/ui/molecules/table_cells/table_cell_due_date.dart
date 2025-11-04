import 'package:flutter/material.dart';

/// Widget reutilizável para células de tabela com datas de vencimento
/// 
/// Características:
/// - Formato padrão: DD/MM/AAAA
/// - Mostra "-" quando null
/// - Exibe ícone de alerta vermelho quando vencida e não concluída
/// - Parsing automático de strings
/// - Tratamento de erros
/// 
/// Uso:
/// ```dart
/// // Em cellBuilders de tabelas de tasks
/// (task) => TableCellDueDate(
///   dueDate: task['due_date'],
///   status: task['status'],
/// )
/// 
/// // Com formato customizado
/// (task) => TableCellDueDate(
///   dueDate: task['due_date'],
///   status: task['status'],
///   format: TableCellDueDateFormat.full, // DD/MM/AAAA HH:mm
/// )
/// 
/// // Com estilo customizado
/// (task) => TableCellDueDate(
///   dueDate: task['due_date'],
///   status: task['status'],
///   style: TextStyle(color: Colors.grey),
/// )
/// ```
class TableCellDueDate extends StatelessWidget {
  /// Data de vencimento (pode ser DateTime, String ou null)
  final dynamic dueDate;
  
  /// Status da task (para verificar se está concluída)
  final String? status;
  
  /// Formato da data
  final TableCellDueDateFormat format;
  
  /// Texto a exibir quando dueDate é null
  final String nullText;
  
  /// Estilo do texto
  final TextStyle? style;
  
  /// Tamanho do ícone de alerta
  final double iconSize;
  
  /// Cor do ícone de alerta
  final Color alertColor;

  const TableCellDueDate({
    super.key,
    required this.dueDate,
    this.status,
    this.format = TableCellDueDateFormat.short,
    this.nullText = '-',
    this.style,
    this.iconSize = 16,
    this.alertColor = Colors.red,
  });

  /// Converte o valor para DateTime
  DateTime? _parseDate() {
    if (dueDate == null) return null;
    
    if (dueDate is DateTime) {
      return dueDate as DateTime;
    }
    
    if (dueDate is String) {
      try {
        return DateTime.parse(dueDate as String);
      } catch (e) {
        return null;
      }
    }
    
    return null;
  }

  /// Verifica se a task está vencida e não concluída
  bool _isOverdue(DateTime date) {
    // Verificar se está concluída
    final isCompleted = status?.toLowerCase() == 'completed' || 
                       status?.toLowerCase() == 'concluída' ||
                       status?.toLowerCase() == 'concluida';
    
    if (isCompleted) return false;
    
    // Verificar se está vencida (comparar apenas a data, sem hora)
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dueDay = DateTime(date.year, date.month, date.day);
    
    return dueDay.isBefore(today);
  }

  /// Formata a data de acordo com o formato especificado
  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString();
    
    switch (format) {
      case TableCellDueDateFormat.short:
        // DD/MM/AAAA
        return '$day/$month/$year';
      
      case TableCellDueDateFormat.full:
        // DD/MM/AAAA HH:mm
        final hour = date.hour.toString().padLeft(2, '0');
        final minute = date.minute.toString().padLeft(2, '0');
        return '$day/$month/$year $hour:$minute';
      
      case TableCellDueDateFormat.monthYear:
        // MM/AAAA
        return '$month/$year';
      
      case TableCellDueDateFormat.dayMonth:
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
    
    final isOverdue = _isOverdue(parsedDate);
    final formattedDate = _formatDate(parsedDate);
    
    if (isOverdue) {
      // Exibir com ícone de alerta
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.warning_rounded,
            size: iconSize,
            color: alertColor,
          ),
          const SizedBox(width: 4),
          Text(
            formattedDate,
            style: style,
          ),
        ],
      );
    }
    
    // Exibir apenas a data
    return Text(
      formattedDate,
      style: style,
    );
  }
}

/// Formatos disponíveis para datas de vencimento em células
enum TableCellDueDateFormat {
  /// DD/MM/AAAA (padrão)
  short,
  
  /// DD/MM/AAAA HH:mm
  full,
  
  /// MM/AAAA
  monthYear,
  
  /// DD/MM
  dayMonth,
}

