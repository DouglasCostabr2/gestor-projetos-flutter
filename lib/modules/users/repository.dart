import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../config/supabase_config.dart';
import '../auth/module.dart';
import 'contract.dart';

/// Implementação do contrato de usuários
/// 
/// IMPORTANTE: Esta classe é INTERNA ao módulo.
/// O mundo externo deve usar apenas o contrato UsersContract.
class UsersRepository implements UsersContract {
  final SupabaseClient _client = SupabaseConfig.client;

  @override
  Future<Map<String, dynamic>?> getCurrentProfile() async {
    final user = authModule.currentUser;
    if (user == null) return null;

    try {
      final response = await _client
          .from('profiles')
          .select('*')
          .eq('id', user.id)
          .maybeSingle();

      // Se não existe perfil, criar um básico
      if (response == null) {
        final newProfile = {
          'id': user.id,
          'email': user.email ?? '',
          'full_name': user.userMetadata?['full_name'] ?? user.email?.split('@')[0] ?? 'Usuário',
          'avatar_url': null,
        };

        await _client.from('profiles').insert(newProfile);
        return newProfile;
      }

      return response;
    } catch (e) {
      debugPrint('Erro ao buscar perfil: $e');
      // Retornar perfil básico em caso de erro
      return {
        'id': user.id,
        'email': user.email ?? '',
        'full_name': user.email?.split('@')[0] ?? 'Usuário',
        'avatar_url': null,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };
    }
  }

  @override
  Future<Map<String, dynamic>> updateProfile({
    required String fullName,
    String? avatarUrl,
  }) async {
    final user = authModule.currentUser;
    if (user == null) throw Exception('Usuário não autenticado');

    final response = await _client
        .from('profiles')
        .update({
          'full_name': fullName,
          if (avatarUrl != null) 'avatar_url': avatarUrl,
        })
        .eq('id', user.id)
        .select()
        .single();
    return response;
  }

  @override
  Future<Map<String, dynamic>?> getProfileById(String userId) async {
    try {
      final response = await _client
          .from('profiles')
          .select('*')
          .eq('id', userId)
          .maybeSingle();
      return response;
    } catch (e) {
      debugPrint('Erro ao buscar perfil por ID: $e');
      return null;
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getAllProfiles() async {
    try {
      final response = await _client
          .from('profiles')
          .select('id, full_name, email, role, avatar_url')
          .order('full_name');
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Erro ao buscar todos os perfis: $e');
      return [];
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getEmployeeProfiles() async {
    try {
      debugPrint('Buscando perfis de funcionários');
      final response = await _client
          .from('profiles')
          .select('id, full_name, email, avatar_url, role')
          .order('full_name');

      debugPrint('Perfis de funcionários encontrados: ${response.length}');
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Erro ao buscar perfis de funcionários: $e');
      return [];
    }
  }
}

/// Instância singleton do repositório de usuários
/// Esta é a ÚNICA instância que deve ser usada em todo o aplicativo
final UsersContract usersModule = UsersRepository();

