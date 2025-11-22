import 'package:supabase_flutter/supabase_flutter.dart';
import '../../config/supabase_config.dart';
import '../auth/module.dart';
import '../common/organization_context.dart';
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
        final userName = user.userMetadata?['full_name'] ?? user.email?.split('@')[0] ?? 'Usuário';
        final newProfile = {
          'id': user.id,
          'email': user.email ?? '',
          'full_name': userName,
          'avatar_url': null,
          'role': 'usuario', // Role padrão para novos usuários
        };

        await _client.from('profiles').insert(newProfile);

        // Criar organização padrão para o novo usuário
        await _createDefaultOrganization(user.id, userName, user.email ?? '');

        return newProfile;
      }

      return response;
    } catch (e) {
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
      return null;
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getAllProfiles() async {
    try {
      // Obter organization_id
      final orgId = OrganizationContext.currentOrganizationId;
      if (orgId == null) {
        return [];
      }


      // Buscar membros ativos da organização usando RPC
      final response = await _client.rpc(
        'get_organization_members_with_profiles',
        params: {'org_id': orgId},
      );

      // Transformar para o formato esperado
      final profiles = <Map<String, dynamic>>[];
      for (final member in (response as List)) {
        final m = member as Map<String, dynamic>;
        profiles.add({
          'id': m['user_id'],
          'full_name': m['full_name'],
          'email': m['email'],
          'avatar_url': m['avatar_url'],
          'role': m['role'], // Role do profiles
        });
      }

      return profiles;
    } catch (e) {
      return [];
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getEmployeeProfiles() async {
    try {
      final orgId = OrganizationContext.currentOrganizationId;
      if (orgId == null) {
        return [];
      }


      // Buscar membros ativos da organização usando RPC
      final response = await _client.rpc(
        'get_organization_members_with_profiles',
        params: {'org_id': orgId},
      );

      // Transformar para o formato esperado
      final profiles = <Map<String, dynamic>>[];
      for (final member in (response as List)) {
        final m = member as Map<String, dynamic>;
        profiles.add({
          'id': m['user_id'],
          'full_name': m['full_name'],
          'email': m['email'],
          'avatar_url': m['avatar_url'],
          'role': m['role'], // Role do profiles
          'organization_role': m['om_role'], // Role na organização
        });
      }

      return profiles;
    } catch (e) {
      return [];
    }
  }

  /// Cria uma organização padrão para um novo usuário
  Future<void> _createDefaultOrganization(String userId, String userName, String userEmail) async {
    try {

      // Gerar nome e slug da organização baseado no nome do usuário
      final orgName = '$userName - Organização';
      final orgSlug = userName
          .toLowerCase()
          .trim()
          .replaceAll(RegExp(r'[^a-z0-9\s-]'), '')
          .replaceAll(RegExp(r'\s+'), '-')
          .replaceAll(RegExp(r'-+'), '-')
          .replaceAll(RegExp(r'^-|-$'), '');

      // Usar a função RPC do Supabase para criar a organização
      // Isso contorna problemas de RLS e cria automaticamente o membro owner
      await _client.rpc('create_organization', params: {
        'p_name': orgName,
        'p_slug': orgSlug,
        'p_legal_name': null,
        'p_email': userEmail,
        'p_phone': null,
      });

    } catch (e) {
      // Não lançar exceção - a criação da organização é opcional
      // O usuário pode criar manualmente depois se for admin
    }
  }
}

/// Instância singleton do repositório de usuários
/// Esta é a ÚNICA instância que deve ser usada em todo o aplicativo
final UsersContract usersModule = UsersRepository();

