import 'package:flutter_test/flutter_test.dart';
import 'package:my_business/src/utils/table_comparators.dart';

void main() {
  group('compareByTitle', () {
    test('deve ordenar por título (case-insensitive)', () {
      final a = {'title': 'Zebra'};
      final b = {'title': 'apple'};
      
      expect(compareByTitle(a, b), greaterThan(0));
      expect(compareByTitle(b, a), lessThan(0));
    });

    test('deve tratar valores nulos', () {
      final a = {'title': 'Test'};
      final b = <String, dynamic>{};
      
      expect(compareByTitle(a, b), greaterThan(0));
    });
  });

  group('compareByStatus', () {
    test('deve ordenar por status', () {
      final a = {'status': 'pending'};
      final b = {'status': 'completed'};
      
      expect(compareByStatus(a, b), greaterThan(0));
    });
  });

  group('compareByPriority', () {
    test('deve ordenar low < medium < high < urgent', () {
      final low = {'priority': 'low'};
      final medium = {'priority': 'medium'};
      final high = {'priority': 'high'};
      final urgent = {'priority': 'urgent'};
      
      expect(compareByPriority(low, medium), lessThan(0));
      expect(compareByPriority(medium, high), lessThan(0));
      expect(compareByPriority(high, urgent), lessThan(0));
      expect(compareByPriority(urgent, low), greaterThan(0));
    });

    test('deve tratar prioridades desconhecidas como medium', () {
      final unknown = {'priority': 'unknown'};
      final medium = {'priority': 'medium'};
      
      expect(compareByPriority(unknown, medium), 0);
    });
  });

  group('compareByDueDate', () {
    test('deve ordenar por data de vencimento', () {
      final a = {'due_date': '2025-01-01'};
      final b = {'due_date': '2025-12-31'};
      
      expect(compareByDueDate(a, b), lessThan(0));
      expect(compareByDueDate(b, a), greaterThan(0));
    });

    test('deve colocar nulos no final', () {
      final withDate = {'due_date': '2025-01-01'};
      final withoutDate = <String, dynamic>{};
      
      expect(compareByDueDate(withDate, withoutDate), lessThan(0));
      expect(compareByDueDate(withoutDate, withDate), greaterThan(0));
    });

    test('deve tratar dois nulos como iguais', () {
      final a = <String, dynamic>{};
      final b = <String, dynamic>{};
      
      expect(compareByDueDate(a, b), 0);
    });
  });

  group('compareByCreatedAt', () {
    test('deve ordenar por data de criação', () {
      final a = {'created_at': '2025-01-01T10:00:00'};
      final b = {'created_at': '2025-01-01T15:00:00'};
      
      expect(compareByCreatedAt(a, b), lessThan(0));
    });
  });

  group('compareByUpdatedAt', () {
    test('deve ordenar por data de atualização', () {
      final a = {'updated_at': '2025-01-01T10:00:00'};
      final b = {'updated_at': '2025-01-01T15:00:00'};
      
      expect(compareByUpdatedAt(a, b), lessThan(0));
    });
  });

  group('compareByProjectName', () {
    test('deve ordenar por nome do projeto', () {
      final a = {'projects': {'name': 'Zebra Project'}};
      final b = {'projects': {'name': 'Apple Project'}};
      
      expect(compareByProjectName(a, b), greaterThan(0));
    });

    test('deve tratar projetos nulos', () {
      final a = {'projects': {'name': 'Test'}};
      final b = <String, dynamic>{};
      
      expect(compareByProjectName(a, b), greaterThan(0));
    });
  });

  group('compareByAssignee', () {
    test('deve ordenar pelo primeiro responsável', () {
      final a = {'assignees_list': [{'full_name': 'Zebra'}]};
      final b = {'assignees_list': [{'full_name': 'Apple'}]};
      
      expect(compareByAssignee(a, b), greaterThan(0));
    });

    test('deve tratar listas vazias', () {
      final a = {'assignees_list': [{'full_name': 'Test'}]};
      final b = {'assignees_list': []};
      
      expect(compareByAssignee(a, b), greaterThan(0));
    });

    test('deve tratar listas nulas', () {
      final a = {'assignees_list': [{'full_name': 'Test'}]};
      final b = <String, dynamic>{};
      
      expect(compareByAssignee(a, b), greaterThan(0));
    });
  });

  group('createFieldComparator', () {
    test('deve criar comparador para campo específico', () {
      final comparator = createFieldComparator('description');
      final a = {'description': 'Zebra'};
      final b = {'description': 'Apple'};
      
      expect(comparator(a, b), greaterThan(0));
    });

    test('deve respeitar case-sensitive quando especificado', () {
      final comparator = createFieldComparator('email', caseInsensitive: false);
      final a = {'email': 'Z@test.com'};
      final b = {'email': 'a@test.com'};
      
      expect(comparator(a, b), lessThan(0)); // 'Z' < 'a' em ASCII
    });
  });

  group('createDateComparator', () {
    test('deve criar comparador para campo de data', () {
      final comparator = createDateComparator('completed_at');
      final a = {'completed_at': '2025-01-01'};
      final b = {'completed_at': '2025-12-31'};
      
      expect(comparator(a, b), lessThan(0));
    });

    test('deve respeitar nullsLast=false', () {
      final comparator = createDateComparator('start_date', nullsLast: false);
      final withDate = {'start_date': '2025-01-01'};
      final withoutDate = <String, dynamic>{};
      
      expect(comparator(withDate, withoutDate), greaterThan(0));
      expect(comparator(withoutDate, withDate), lessThan(0));
    });
  });
}

