import 'package:flutter_test/flutter_test.dart';
import 'package:my_business/src/utils/task_helpers.dart';

void main() {
  group('createProfilesMap', () {
    test('deve criar mapa vazio para lista vazia', () {
      final profiles = <Map<String, dynamic>>[];
      final result = createProfilesMap(profiles);
      
      expect(result, isEmpty);
    });

    test('deve criar mapa indexado por ID', () {
      final profiles = [
        {'id': 'user1', 'full_name': 'João Silva', 'email': 'joao@test.com'},
        {'id': 'user2', 'full_name': 'Maria Santos', 'email': 'maria@test.com'},
        {'id': 'user3', 'full_name': 'Pedro Costa', 'email': 'pedro@test.com'},
      ];
      
      final result = createProfilesMap(profiles);
      
      expect(result.length, 3);
      expect(result['user1']?['full_name'], 'João Silva');
      expect(result['user2']?['full_name'], 'Maria Santos');
      expect(result['user3']?['full_name'], 'Pedro Costa');
    });

    test('deve ignorar perfis sem ID', () {
      final profiles = [
        {'id': 'user1', 'full_name': 'João Silva'},
        {'full_name': 'Sem ID'}, // Sem ID
        {'id': 'user2', 'full_name': 'Maria Santos'},
      ];
      
      final result = createProfilesMap(profiles);
      
      expect(result.length, 2);
      expect(result.containsKey('user1'), true);
      expect(result.containsKey('user2'), true);
    });

    test('deve sobrescrever perfis com IDs duplicados', () {
      final profiles = [
        {'id': 'user1', 'full_name': 'João Silva'},
        {'id': 'user1', 'full_name': 'João Santos'}, // ID duplicado
      ];
      
      final result = createProfilesMap(profiles);
      
      expect(result.length, 1);
      expect(result['user1']?['full_name'], 'João Santos'); // Último vence
    });
  });
}

