import 'package:flutter_test/flutter_test.dart';
import 'package:my_business/src/utils/date_helpers.dart';

void main() {
  group('formatDate', () {
    test('deve formatar DateTime como DD/MM/AAAA', () {
      final date = DateTime(2025, 10, 31);
      expect(formatDate(date), '31/10/2025');
    });

    test('deve formatar String ISO como DD/MM/AAAA', () {
      expect(formatDate('2025-10-31'), '31/10/2025');
    });

    test('deve retornar texto padrão para null', () {
      expect(formatDate(null), '-');
      expect(formatDate(null, nullText: 'N/A'), 'N/A');
    });

    test('deve adicionar zeros à esquerda', () {
      final date = DateTime(2025, 1, 5);
      expect(formatDate(date), '05/01/2025');
    });
  });

  group('formatDateTime', () {
    test('deve formatar DateTime como DD/MM/AAAA HH:mm', () {
      final date = DateTime(2025, 10, 31, 14, 30);
      expect(formatDateTime(date), '31/10/2025 14:30');
    });

    test('deve adicionar zeros à esquerda nas horas', () {
      final date = DateTime(2025, 1, 5, 9, 5);
      expect(formatDateTime(date), '05/01/2025 09:05');
    });

    test('deve retornar texto padrão para null', () {
      expect(formatDateTime(null), '-');
    });
  });

  group('formatDayMonth', () {
    test('deve formatar como DD/MM', () {
      final date = DateTime(2025, 10, 31);
      expect(formatDayMonth(date), '31/10');
    });

    test('deve adicionar zeros à esquerda', () {
      final date = DateTime(2025, 1, 5);
      expect(formatDayMonth(date), '05/01');
    });
  });

  group('formatMonthYear', () {
    test('deve formatar como MM/AAAA', () {
      final date = DateTime(2025, 10, 31);
      expect(formatMonthYear(date), '10/2025');
    });

    test('deve adicionar zero à esquerda no mês', () {
      final date = DateTime(2025, 1, 15);
      expect(formatMonthYear(date), '01/2025');
    });
  });

  group('parseDate', () {
    test('deve retornar DateTime diretamente', () {
      final date = DateTime(2025, 10, 31);
      expect(parseDate(date), date);
    });

    test('deve fazer parse de String ISO', () {
      final result = parseDate('2025-10-31');
      expect(result, isNotNull);
      expect(result!.year, 2025);
      expect(result.month, 10);
      expect(result.day, 31);
    });

    test('deve retornar null para string inválida', () {
      expect(parseDate('invalid'), null);
    });

    test('deve retornar null para null', () {
      expect(parseDate(null), null);
    });
  });

  group('isOverdue', () {
    test('deve retornar true para data passada', () {
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      expect(isOverdue(yesterday), true);
    });

    test('deve retornar false para data futura', () {
      final tomorrow = DateTime.now().add(const Duration(days: 1));
      expect(isOverdue(tomorrow), false);
    });

    test('deve retornar false para hoje', () {
      final today = DateTime.now();
      expect(isOverdue(today), false);
    });

    test('deve retornar false para null', () {
      expect(isOverdue(null), false);
    });
  });

  group('isToday', () {
    test('deve retornar true para hoje', () {
      final now = DateTime.now();
      expect(isToday(now), true);
    });

    test('deve retornar false para ontem', () {
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      expect(isToday(yesterday), false);
    });

    test('deve retornar false para amanhã', () {
      final tomorrow = DateTime.now().add(const Duration(days: 1));
      expect(isToday(tomorrow), false);
    });

    test('deve retornar false para null', () {
      expect(isToday(null), false);
    });
  });

  group('isTomorrow', () {
    test('deve retornar true para amanhã', () {
      final tomorrow = DateTime.now().add(const Duration(days: 1));
      expect(isTomorrow(tomorrow), true);
    });

    test('deve retornar false para hoje', () {
      final today = DateTime.now();
      expect(isTomorrow(today), false);
    });

    test('deve retornar false para null', () {
      expect(isTomorrow(null), false);
    });
  });

  group('getStartOfWeek', () {
    test('deve retornar segunda-feira da semana', () {
      final date = DateTime(2025, 10, 31); // Sexta-feira
      final result = getStartOfWeek(date);
      
      expect(result.weekday, 1); // Segunda-feira
      expect(result.hour, 0);
      expect(result.minute, 0);
      expect(result.second, 0);
    });

    test('deve funcionar para segunda-feira', () {
      final monday = DateTime(2025, 10, 27); // Segunda-feira
      final result = getStartOfWeek(monday);
      
      expect(result.day, 27);
      expect(result.weekday, 1);
    });
  });

  group('getEndOfWeek', () {
    test('deve retornar domingo da semana', () {
      final date = DateTime(2025, 10, 31); // Sexta-feira
      final result = getEndOfWeek(date);
      
      expect(result.weekday, 7); // Domingo
      expect(result.hour, 23);
      expect(result.minute, 59);
      expect(result.second, 59);
    });
  });

  group('getStartOfMonth', () {
    test('deve retornar dia 1 do mês', () {
      final date = DateTime(2025, 10, 31);
      final result = getStartOfMonth(date);
      
      expect(result.day, 1);
      expect(result.month, 10);
      expect(result.year, 2025);
      expect(result.hour, 0);
    });
  });

  group('getEndOfMonth', () {
    test('deve retornar último dia do mês', () {
      final date = DateTime(2025, 10, 15);
      final result = getEndOfMonth(date);
      
      expect(result.day, 31); // Outubro tem 31 dias
      expect(result.month, 10);
      expect(result.hour, 23);
      expect(result.minute, 59);
    });

    test('deve funcionar para fevereiro', () {
      final date = DateTime(2025, 2, 15);
      final result = getEndOfMonth(date);
      
      expect(result.day, 28); // 2025 não é bissexto
      expect(result.month, 2);
    });

    test('deve funcionar para fevereiro em ano bissexto', () {
      final date = DateTime(2024, 2, 15);
      final result = getEndOfMonth(date);
      
      expect(result.day, 29); // 2024 é bissexto
      expect(result.month, 2);
    });
  });

  group('daysBetween', () {
    test('deve calcular diferença em dias', () {
      final date1 = DateTime(2025, 11, 1);
      final date2 = DateTime(2025, 10, 31);
      
      expect(daysBetween(date1, date2), 1);
      expect(daysBetween(date2, date1), -1);
    });

    test('deve retornar 0 para mesma data', () {
      final date = DateTime(2025, 10, 31);
      expect(daysBetween(date, date), 0);
    });

    test('deve retornar null se alguma data for inválida', () {
      final validDate = DateTime(2025, 10, 31);
      expect(daysBetween(null, validDate), null);
      expect(daysBetween('invalid', validDate), null);
    });

    test('deve usar hoje como padrão para date2', () {
      final today = DateTime.now();
      final tomorrow = today.add(const Duration(days: 1));
      
      expect(daysBetween(tomorrow), 1);
    });
  });
}

