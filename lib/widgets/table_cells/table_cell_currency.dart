import 'package:flutter/material.dart';

/// Widget reutilizável para células de tabela com valores monetários
/// 
/// Características:
/// - Suporte a múltiplas moedas (BRL, USD, EUR)
/// - Formatação automática de centavos para reais
/// - Mostra "-" quando zero ou null
/// - Símbolo de moeda automático
/// - Casas decimais configuráveis
/// 
/// Uso:
/// ```dart
/// // Em cellBuilders de tabelas - valor em centavos
/// (item) => TableCellCurrency(
///   valueCents: item['value_cents'],
///   currencyCode: item['currency_code'] ?? 'BRL',
/// )
/// 
/// // Valor já em decimal
/// (item) => TableCellCurrency.fromDecimal(
///   value: item['value'],
///   currencyCode: 'USD',
/// )
/// 
/// // Com estilo customizado
/// (item) => TableCellCurrency(
///   valueCents: item['value_cents'],
///   style: TextStyle(fontWeight: FontWeight.bold),
/// )
/// ```
class TableCellCurrency extends StatelessWidget {
  /// Valor em centavos (ex: 1000 = R$ 10.00)
  final int? valueCents;
  
  /// Código da moeda (BRL, USD, EUR)
  final String currencyCode;
  
  /// Texto a exibir quando valor é null ou zero
  final String nullText;
  
  /// Estilo do texto
  final TextStyle? style;
  
  /// Número de casas decimais
  final int decimalPlaces;
  
  /// Se deve mostrar zero como "-" ou "R$ 0,00"
  final bool hideZero;

  const TableCellCurrency({
    super.key,
    required this.valueCents,
    this.currencyCode = 'BRL',
    this.nullText = '-',
    this.style,
    this.decimalPlaces = 2,
    this.hideZero = true,
  });

  /// Construtor alternativo para valores já em decimal
  TableCellCurrency.fromDecimal({
    super.key,
    required double? value,
    this.currencyCode = 'BRL',
    this.nullText = '-',
    this.style,
    this.decimalPlaces = 2,
    this.hideZero = true,
  }) : valueCents = value != null ? (value * 100).round() : null;

  /// Retorna o símbolo da moeda
  String _getCurrencySymbol() {
    switch (currencyCode.toUpperCase()) {
      case 'USD':
        return '\$';
      case 'EUR':
        return '€';
      case 'GBP':
        return '£';
      case 'JPY':
        return '¥';
      case 'BRL':
      default:
        return 'R\$';
    }
  }

  /// Formata o valor
  String _formatValue(double value) {
    final symbol = _getCurrencySymbol();
    final formatted = value.toStringAsFixed(decimalPlaces);
    
    // Para BRL, usar vírgula como separador decimal
    if (currencyCode.toUpperCase() == 'BRL') {
      final parts = formatted.split('.');
      return '$symbol ${parts[0]},${parts[1]}';
    }
    
    // Para outras moedas, usar ponto
    return '$symbol $formatted';
  }

  @override
  Widget build(BuildContext context) {
    // Se valor é null, mostrar texto null
    if (valueCents == null) {
      return Text(nullText, style: style);
    }
    
    // Se valor é zero e hideZero = true, mostrar texto null
    if (valueCents == 0 && hideZero) {
      return Text(nullText, style: style);
    }
    
    // Converter centavos para decimal
    final value = valueCents! / 100.0;
    
    return Text(
      _formatValue(value),
      style: style,
    );
  }
}

