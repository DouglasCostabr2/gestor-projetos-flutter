class Money {
  static String symbol(String? code) {
    switch ((code ?? 'BRL').toUpperCase()) {
      case 'USD':
        return r'$';
      case 'EUR':
        return '€';
      case 'BRL':
      default:
        return 'R\$';
    }
  }

  // Formats cents to a string with 2 decimals using comma as decimal separator.
  // Example: 123456 -> "1234,56"
  static String formatCents(int cents) {
    final v = cents / 100.0;
    // Keep it simple and consistent with current UI: decimal comma, no thousands grouping
    return v.toStringAsFixed(2).replaceAll('.', ',');
  }

  // Formats with currency symbol: "R$ 1234,56"
  static String formatWithSymbol(int cents, String? currencyCode) {
    return '${symbol(currencyCode)} ${formatCents(cents)}';
  }

  // Parses various user inputs into cents. Accepts both comma and dot for decimals,
  // strips currency symbols and spaces. Safe fallback = 0.
  static int parseToCents(String? input) {
    final s = (input ?? '')
        .trim()
        .replaceAll(' ', '')
        .replaceAll('R\$', '')
        .replaceAll(r'$', '')
        .replaceAll('€', '')
        .replaceAll('.', ''); // remove thousands if any
    final normalized = s.replaceAll(',', '.');
    final v = double.tryParse(normalized) ?? 0.0;
    return (v * 100).round();
  }
}

