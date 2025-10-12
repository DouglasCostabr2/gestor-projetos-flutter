import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../config/supabase_config.dart';
import '../../services/google_drive_oauth_service.dart';
import '../auth/module.dart';
import 'contract.dart';

/// Implementação do contrato de empresas
class CompaniesRepository implements CompaniesContract {
  final SupabaseClient _client = SupabaseConfig.client;

  @override
  Future<List<Map<String, dynamic>>> getCompanies(String clientId) async {
    try {
      debugPrint('Buscando empresas do cliente: $clientId');

      // Tentar primeiro com o join
      try {
        final response = await _client
            .from('companies')
            .select('''
              *,
              updated_by_profile:profiles!companies_updated_by_fkey(full_name, email, avatar_url)
            ''')
            .eq('client_id', clientId)
            .order('created_at', ascending: false);

        debugPrint('✅ Resposta do Supabase para empresas (com join): $response');
        return List<Map<String, dynamic>>.from(response);
      } catch (joinError) {
        debugPrint('⚠️ Erro no join, tentando sem join: $joinError');

        // Se o join falhar, buscar sem join e enriquecer manualmente
        final response = await _client
            .from('companies')
            .select('*')
            .eq('client_id', clientId)
            .order('created_at', ascending: false);

        final companies = List<Map<String, dynamic>>.from(response);

        // Buscar perfis dos usuários que fizeram a última atualização
        final updatedByIds = companies
            .map((c) => c['updated_by'])
            .whereType<String>()
            .toSet();

        if (updatedByIds.isNotEmpty) {
          final profiles = await _client
              .from('profiles')
              .select('id, full_name, email, avatar_url')
              .inFilter('id', updatedByIds.toList());

          final profilesMap = {
            for (var p in profiles) p['id']: p
          };

          // Enriquecer empresas com perfis
          for (var company in companies) {
            final updatedBy = company['updated_by'];
            if (updatedBy != null && profilesMap.containsKey(updatedBy)) {
              company['updated_by_profile'] = profilesMap[updatedBy];
            }
          }
        }

        debugPrint('✅ Resposta do Supabase para empresas (sem join, enriquecido): $companies');
        return companies;
      }
    } catch (e) {
      debugPrint('❌ Erro ao buscar empresas: $e');
      return [];
    }
  }

  @override
  Future<Map<String, dynamic>?> getCompanyById(String companyId) async {
    try {
      debugPrint('Buscando empresa por ID: $companyId');
      final response = await _client
          .from('companies')
          .select('*')
          .eq('id', companyId)
          .single();

      debugPrint('Empresa encontrada: $response');
      return response;
    } catch (e) {
      debugPrint('Erro ao buscar empresa por ID: $e');
      return null;
    }
  }

  @override
  Future<Map<String, dynamic>> createCompany({
    required String clientId,
    required String name,
    String? email,
    String? phone,
    String? address,
    String? city,
    String? state,
    String? zipCode,
    String? country,
    String? website,
    String? notes,
    String status = 'active',
  }) async {
    final user = authModule.currentUser;
    if (user == null) throw Exception('Usuário não autenticado');

    // A tabela companies tem apenas: client_id, name, owner_id, status, created_at, updated_at, custom_platforms
    // Os outros campos (email, phone, etc.) não existem na tabela
    final companyData = <String, dynamic>{
      'client_id': clientId,
      'name': name.trim(),
      'owner_id': user.id,
    };

    try {
      final response = await _client
          .from('companies')
          .insert(companyData)
          .select()
          .single();
      return response;
    } catch (e) {
      debugPrint('Erro ao criar empresa: $e');
      debugPrint('Dados enviados: $companyData');
      rethrow;
    }
  }

  @override
  Future<Map<String, dynamic>> updateCompany({
    required String companyId,
    String? name,
    String? email,
    String? phone,
    String? address,
    String? city,
    String? state,
    String? zipCode,
    String? country,
    String? website,
    String? notes,
    String? status,
  }) async {
    // Buscar nome antigo e cliente se o nome está sendo alterado
    String? oldName;
    String? clientName;
    if (name != null) {
      try {
        final current = await _client
            .from('companies')
            .select('name, clients(name)')
            .eq('id', companyId)
            .single();
        oldName = current['name'] as String?;
        final clientData = current['clients'] as Map<String, dynamic>?;
        clientName = clientData?['name'] as String?;
      } catch (e) {
        debugPrint('Erro ao buscar dados antigos da empresa: $e');
      }
    }

    // A tabela companies tem apenas: client_id, name, owner_id, status, created_at, updated_at, custom_platforms
    // Os outros campos (email, phone, etc.) não existem na tabela
    final updateData = <String, dynamic>{};
    if (name != null) updateData['name'] = name.trim();

    // Adicionar updated_by e updated_at
    final user = authModule.currentUser;
    if (user != null) {
      updateData['updated_by'] = user.id;
    }
    updateData['updated_at'] = DateTime.now().toIso8601String();

    try {
      final response = await _client
          .from('companies')
          .update(updateData)
          .eq('id', companyId)
          .select()
          .single();

      // Renomear pasta no Google Drive se o nome foi alterado
      if (name != null && oldName != null && oldName.isNotEmpty &&
          clientName != null && clientName.isNotEmpty &&
          name.trim() != oldName) {
        try {
          final drive = GoogleDriveOAuthService();
          final authed = await drive.getAuthedClient();
          await drive.renameCompanyFolder(
            client: authed,
            clientName: clientName,
            oldCompanyName: oldName,
            newCompanyName: name.trim(),
          );
        } catch (e) {
          debugPrint('⚠️ Erro ao renomear pasta da empresa no Google Drive (ignorado): $e');
        }
      }

      return response;
    } catch (e) {
      debugPrint('Erro ao atualizar empresa: $e');
      rethrow;
    }
  }

  @override
  Future<void> deleteCompany(String companyId) async {
    try {
      // Buscar nome da empresa e cliente antes de deletar
      String? companyName;
      String? clientName;
      try {
        final response = await _client
            .from('companies')
            .select('name, clients(name)')
            .eq('id', companyId)
            .single();
        companyName = response['name'] as String?;
        final clientData = response['clients'] as Map<String, dynamic>?;
        clientName = clientData?['name'] as String?;
      } catch (e) {
        debugPrint('Erro ao buscar dados da empresa: $e');
      }

      // Deletar do banco de dados
      await _client
          .from('companies')
          .delete()
          .eq('id', companyId);

      // Deletar pasta do Google Drive (best-effort)
      if (companyName != null && companyName.isNotEmpty &&
          clientName != null && clientName.isNotEmpty) {
        try {
          final drive = GoogleDriveOAuthService();
          final authed = await drive.getAuthedClient();
          await drive.deleteCompanyFolder(
            client: authed,
            clientName: clientName,
            companyName: companyName,
          );
          debugPrint('✅ Pasta da empresa deletada do Google Drive: $companyName');
        } catch (e) {
          debugPrint('⚠️ Erro ao deletar pasta da empresa do Google Drive (ignorado): $e');
        }
      }
    } catch (e) {
      debugPrint('Erro ao deletar empresa: $e');
      rethrow;
    }
  }

  /// Atualizar updated_by e updated_at da empresa
  /// Usado quando um projeto é criado, duplicado ou excluído
  @override
  Future<void> touchCompany(String companyId) async {
    final user = authModule.currentUser;
    if (user == null) return;

    try {
      await _client
          .from('companies')
          .update({
            'updated_by': user.id,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', companyId);
      debugPrint('✅ Empresa $companyId atualizada (touch)');
    } catch (e) {
      debugPrint('⚠️ Erro ao atualizar empresa (touch): $e');
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getCompanyProjectsWithStats(String companyId) async {
    try {
      debugPrint('🚀 Buscando projetos da empresa com stats (RPC): $companyId');

      // OTIMIZAÇÃO: Usar RPC function para evitar N+1 queries
      final response = await _client
          .rpc('get_company_projects_with_stats', params: {
            'company_id_param': companyId,
          });

      debugPrint('✅ Projetos com stats encontrados: ${response.length}');
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('❌ Erro ao buscar projetos com stats: $e');
      return [];
    }
  }
}

final CompaniesContract companiesModule = CompaniesRepository();

