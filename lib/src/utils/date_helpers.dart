/// Helpers para formatação e manipulação de datas.
///
/// Centraliza a lógica de datas para evitar duplicação e garantir consistência.
library;

/// Formata uma data no formato DD/MM/AAAA.
/// 
/// Parâmetros:
/// - `date`: Data a ser formatada (pode ser DateTime, String ou null)
/// - `nullText`: Texto a retornar se a data for nula (padrão: '-')
/// 
/// Retorna:
/// - String formatada ou `nullText` se a data for nula/inválida
/// 
/// Exemplo de uso:
/// ```dart
/// formatDate(DateTime.now()); // "31/10/2025"
/// formatDate('2025-10-31'); // "31/10/2025"
/// formatDate(null); // "-"
/// formatDate(null, nullText: 'N/A'); // "N/A"
/// ```
String formatDate(dynamic date, {String nullText = '-'}) {
  final parsedDate = parseDate(date);
  if (parsedDate == null) return nullText;
  
  final day = parsedDate.day.toString().padLeft(2, '0');
  final month = parsedDate.month.toString().padLeft(2, '0');
  final year = parsedDate.year.toString();
  
  return '$day/$month/$year';
}

/// Formata uma data no formato DD/MM/AAAA HH:mm.
/// 
/// Parâmetros:
/// - `date`: Data a ser formatada (pode ser DateTime, String ou null)
/// - `nullText`: Texto a retornar se a data for nula (padrão: '-')
/// 
/// Retorna:
/// - String formatada ou `nullText` se a data for nula/inválida
/// 
/// Exemplo de uso:
/// ```dart
/// formatDateTime(DateTime.now()); // "31/10/2025 14:30"
/// formatDateTime('2025-10-31T14:30:00'); // "31/10/2025 14:30"
/// ```
String formatDateTime(dynamic date, {String nullText = '-'}) {
  final parsedDate = parseDate(date);
  if (parsedDate == null) return nullText;
  
  final day = parsedDate.day.toString().padLeft(2, '0');
  final month = parsedDate.month.toString().padLeft(2, '0');
  final year = parsedDate.year.toString();
  final hour = parsedDate.hour.toString().padLeft(2, '0');
  final minute = parsedDate.minute.toString().padLeft(2, '0');
  
  return '$day/$month/$year $hour:$minute';
}

/// Formata uma data no formato DD/MM.
/// 
/// Útil para exibir apenas dia e mês.
/// 
/// Exemplo de uso:
/// ```dart
/// formatDayMonth(DateTime.now()); // "31/10"
/// ```
String formatDayMonth(dynamic date, {String nullText = '-'}) {
  final parsedDate = parseDate(date);
  if (parsedDate == null) return nullText;
  
  final day = parsedDate.day.toString().padLeft(2, '0');
  final month = parsedDate.month.toString().padLeft(2, '0');
  
  return '$day/$month';
}

/// Formata uma data no formato MM/AAAA.
/// 
/// Útil para exibir apenas mês e ano.
/// 
/// Exemplo de uso:
/// ```dart
/// formatMonthYear(DateTime.now()); // "10/2025"
/// ```
String formatMonthYear(dynamic date, {String nullText = '-'}) {
  final parsedDate = parseDate(date);
  if (parsedDate == null) return nullText;
  
  final month = parsedDate.month.toString().padLeft(2, '0');
  final year = parsedDate.year.toString();
  
  return '$month/$year';
}

/// Faz parsing de uma data de diferentes formatos.
/// 
/// Aceita:
/// - DateTime (retorna diretamente)
/// - String ISO 8601 (ex: "2025-10-31T14:30:00")
/// - null (retorna null)
/// 
/// Retorna:
/// - DateTime se o parsing foi bem-sucedido
/// - null se a data for nula ou inválida
/// 
/// Exemplo de uso:
/// ```dart
/// parseDate(DateTime.now()); // DateTime
/// parseDate('2025-10-31'); // DateTime
/// parseDate('invalid'); // null
/// parseDate(null); // null
/// ```
DateTime? parseDate(dynamic date) {
  if (date == null) return null;
  if (date is DateTime) return date;
  if (date is String) return DateTime.tryParse(date);
  return null;
}

/// Verifica se uma data está atrasada (antes de hoje).
/// 
/// Parâmetros:
/// - `date`: Data a ser verificada
/// 
/// Retorna:
/// - true se a data é anterior a hoje (00:00:00)
/// - false caso contrário ou se a data for nula
/// 
/// Exemplo de uso:
/// ```dart
/// isOverdue('2025-10-30'); // true (se hoje for 31/10/2025)
/// isOverdue('2025-11-01'); // false
/// isOverdue(null); // false
/// ```
bool isOverdue(dynamic date) {
  final parsedDate = parseDate(date);
  if (parsedDate == null) return false;
  
  final today = DateTime.now();
  final todayStart = DateTime(today.year, today.month, today.day);
  
  return parsedDate.isBefore(todayStart);
}

/// Verifica se uma data é hoje.
/// 
/// Parâmetros:
/// - `date`: Data a ser verificada
/// 
/// Retorna:
/// - true se a data é hoje
/// - false caso contrário ou se a data for nula
/// 
/// Exemplo de uso:
/// ```dart
/// isToday(DateTime.now()); // true
/// isToday('2025-10-31'); // true (se hoje for 31/10/2025)
/// isToday('2025-11-01'); // false
/// ```
bool isToday(dynamic date) {
  final parsedDate = parseDate(date);
  if (parsedDate == null) return false;
  
  final today = DateTime.now();
  return parsedDate.year == today.year &&
         parsedDate.month == today.month &&
         parsedDate.day == today.day;
}

/// Verifica se uma data é amanhã.
/// 
/// Exemplo de uso:
/// ```dart
/// isTomorrow('2025-11-01'); // true (se hoje for 31/10/2025)
/// ```
bool isTomorrow(dynamic date) {
  final parsedDate = parseDate(date);
  if (parsedDate == null) return false;
  
  final tomorrow = DateTime.now().add(const Duration(days: 1));
  return parsedDate.year == tomorrow.year &&
         parsedDate.month == tomorrow.month &&
         parsedDate.day == tomorrow.day;
}

/// Retorna o início da semana (segunda-feira às 00:00:00).
/// 
/// Parâmetros:
/// - `date`: Data de referência (padrão: hoje)
/// 
/// Retorna:
/// - DateTime representando a segunda-feira da semana
/// 
/// Exemplo de uso:
/// ```dart
/// getStartOfWeek(); // Segunda-feira desta semana às 00:00:00
/// getStartOfWeek(DateTime(2025, 10, 31)); // Segunda-feira daquela semana
/// ```
DateTime getStartOfWeek([DateTime? date]) {
  final referenceDate = date ?? DateTime.now();
  final weekday = referenceDate.weekday; // 1 = Monday, 7 = Sunday
  final daysToSubtract = weekday - 1; // Dias até segunda-feira
  
  final monday = referenceDate.subtract(Duration(days: daysToSubtract));
  return DateTime(monday.year, monday.month, monday.day);
}

/// Retorna o fim da semana (domingo às 23:59:59).
/// 
/// Parâmetros:
/// - `date`: Data de referência (padrão: hoje)
/// 
/// Retorna:
/// - DateTime representando o domingo da semana
/// 
/// Exemplo de uso:
/// ```dart
/// getEndOfWeek(); // Domingo desta semana às 23:59:59
/// ```
DateTime getEndOfWeek([DateTime? date]) {
  final startOfWeek = getStartOfWeek(date);
  final sunday = startOfWeek.add(const Duration(days: 6));
  return DateTime(sunday.year, sunday.month, sunday.day, 23, 59, 59);
}

/// Retorna o início do mês (dia 1 às 00:00:00).
/// 
/// Parâmetros:
/// - `date`: Data de referência (padrão: hoje)
/// 
/// Exemplo de uso:
/// ```dart
/// getStartOfMonth(); // 01/10/2025 00:00:00 (se hoje for outubro)
/// ```
DateTime getStartOfMonth([DateTime? date]) {
  final referenceDate = date ?? DateTime.now();
  return DateTime(referenceDate.year, referenceDate.month, 1);
}

/// Retorna o fim do mês (último dia às 23:59:59).
/// 
/// Parâmetros:
/// - `date`: Data de referência (padrão: hoje)
/// 
/// Exemplo de uso:
/// ```dart
/// getEndOfMonth(); // 31/10/2025 23:59:59 (se hoje for outubro)
/// ```
DateTime getEndOfMonth([DateTime? date]) {
  final referenceDate = date ?? DateTime.now();
  final nextMonth = DateTime(referenceDate.year, referenceDate.month + 1, 1);
  final lastDay = nextMonth.subtract(const Duration(days: 1));
  return DateTime(lastDay.year, lastDay.month, lastDay.day, 23, 59, 59);
}

/// Calcula a diferença em dias entre duas datas.
/// 
/// Parâmetros:
/// - `date1`: Primeira data
/// - `date2`: Segunda data (padrão: hoje)
/// 
/// Retorna:
/// - Número de dias de diferença (positivo se date1 > date2)
/// - null se alguma data for inválida
/// 
/// Exemplo de uso:
/// ```dart
/// daysBetween('2025-11-01', '2025-10-31'); // 1
/// daysBetween('2025-10-30'); // -1 (se hoje for 31/10/2025)
/// ```
int? daysBetween(dynamic date1, [dynamic date2]) {
  final parsedDate1 = parseDate(date1);
  final parsedDate2 = parseDate(date2 ?? DateTime.now());
  
  if (parsedDate1 == null || parsedDate2 == null) return null;
  
  final difference = parsedDate1.difference(parsedDate2);
  return difference.inDays;
}

