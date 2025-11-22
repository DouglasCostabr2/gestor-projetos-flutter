import 'package:supabase_flutter/supabase_flutter.dart';
import '../../config/supabase_config.dart';
import '../../services/google_drive_oauth_service.dart';
import '../auth/module.dart';
import '../common/organization_context.dart';
import 'contract.dart';

/// Implementação do contrato de empresas
class CompaniesRepository implements CompaniesContract {
  final SupabaseClient _client = SupabaseConfig.client;

  @override
  Future<List<Map<String, dynamic>>> getCompanies(String clientId) async {

    try {
      final orgId = OrganizationContext.currentOrganizationId;
      if (orgId == null) {
        return [];
      }


      // Tentar primeiro com o join
      try {
        final response = await _client
            .from('companies')
            .select('''
              *,
              updated_by_profile:profiles!companies_updated_by_fkey(full_name, email, avatar_url)
            ''')
            .eq('client_id', clientId)
            .eq('organization_id', orgId)
            .order('created_at', ascending: false);


        final companies = List<Map<String, dynamic>>.from(response);
        return companies;
      } catch (joinError) {

        // Se o join falhar, buscar sem join e enriquecer manualmente
        final response = await _client
            .from('companies')
            .select('*')
            .eq('client_id', clientId)
            .eq('organization_id', orgId)
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

        return companies;
      }
    } catch (e) {
      return [];
    }
  }

  @override
  Future<Map<String, dynamic>?> getCompanyById(String companyId) async {
    try {
      final response = await _client
          .from('companies')
          .select('*')
          .eq('id', companyId)
          .single();

      return response;
    } catch (e) {
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
    String? taxId,
    String? taxIdType,
    String? legalName,
    String? stateRegistration,
    String? municipalRegistration,
  }) async {
    final user = authModule.currentUser;
    if (user == null) throw Exception('Usuário não autenticado');

    final orgId = OrganizationContext.currentOrganizationId;
    if (orgId == null) throw Exception('Nenhuma organização ativa');

    // Agora a tabela companies tem campos completos para invoicing
    final companyData = <String, dynamic>{
      'client_id': clientId,
      'name': name.trim(),
      'owner_id': user.id,
      'organization_id': orgId,
      if (email != null) 'email': email.trim(),
      if (phone != null) 'phone': phone.trim(),
      if (address != null) 'address': address.trim(),
      if (city != null) 'city': city.trim(),
      if (state != null) 'state': state.trim(),
      if (zipCode != null) 'zip_code': zipCode.trim(),
      if (country != null) 'country': country.trim(),
      if (website != null) 'website': website.trim(),
      if (taxId != null) 'tax_id': taxId.trim(),
      if (taxIdType != null) 'tax_id_type': taxIdType.trim(),
      if (legalName != null) 'legal_name': legalName.trim(),
      if (stateRegistration != null) 'state_registration': stateRegistration.trim(),
      if (municipalRegistration != null) 'municipal_registration': municipalRegistration.trim(),
    };

    try {
      final response = await _client
          .from('companies')
          .insert(companyData)
          .select()
          .single();
      return response;
    } catch (e) {
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
    String? taxId,
    String? taxIdType,
    String? legalName,
    String? stateRegistration,
    String? municipalRegistration,
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
        // Ignorar erro ao buscar nome antigo (não crítico)
      }
    }

    // Agora a tabela companies tem campos completos para invoicing
    final updateData = <String, dynamic>{};
    if (name != null) updateData['name'] = name.trim();
    if (email != null) updateData['email'] = email.trim();
    if (phone != null) updateData['phone'] = phone.trim();
    if (address != null) updateData['address'] = address.trim();
    if (city != null) updateData['city'] = city.trim();
    if (state != null) updateData['state'] = state.trim();
    if (zipCode != null) updateData['zip_code'] = zipCode.trim();
    if (country != null) updateData['country'] = country.trim();
    if (website != null) updateData['website'] = website.trim();
    if (taxId != null) updateData['tax_id'] = taxId.trim();
    if (taxIdType != null) updateData['tax_id_type'] = taxIdType.trim();
    if (legalName != null) updateData['legal_name'] = legalName.trim();
    if (stateRegistration != null) updateData['state_registration'] = stateRegistration.trim();
    if (municipalRegistration != null) updateData['municipal_registration'] = municipalRegistration.trim();

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
          // Ignorar erro ao renomear pasta no Drive (não crítico)
        }
      }

      return response;
    } catch (e) {
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
        // Ignorar erro ao buscar nomes (não crítico)
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
        } catch (e) {
          // Ignorar erro ao deletar pasta no Drive (não crítico)
        }
      }
    } catch (e) {
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
    } catch (e) {
      // Ignorar erro ao atualizar timestamp (não crítico)
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getCompanyProjectsWithStats(String companyId) async {
    try {

      // OTIMIZAÇÃO: Usar RPC function para evitar N+1 queries
      final response = await _client
          .rpc('get_company_projects_with_stats', params: {
            'company_id_param': companyId,
          });

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      return [];
    }
  }

  @override
  Future<void> updateFiscalBankData({
    required String companyId,
    String? fiscalCountry,
    Map<String, dynamic>? fiscalData,
    Map<String, dynamic>? bankData,
  }) async {
    try {
      final updateData = <String, dynamic>{};

      if (fiscalCountry != null) {
        updateData['fiscal_country'] = fiscalCountry;
      }

      if (fiscalData != null) {
        updateData['fiscal_data'] = fiscalData;
      }

      if (bankData != null) {
        updateData['bank_data'] = bankData;
      }

      // Adicionar updated_by e updated_at
      final user = authModule.currentUser;
      if (user != null) {
        updateData['updated_by'] = user.id;
      }
      updateData['updated_at'] = DateTime.now().toIso8601String();

      await _client
          .from('companies')
          .update(updateData)
          .eq('id', companyId);

    } catch (e) {
      rethrow;
    }
  }
}

final CompaniesContract companiesModule = CompaniesRepository();

