import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../config/supabase_config.dart';
import '../../services/google_drive_oauth_service.dart';
import '../auth/module.dart';
import '../common/organization_context.dart';
import 'contract.dart';

/// Implementação do contrato de clientes
/// 
/// IMPORTANTE: Esta classe é INTERNA ao módulo.
/// O mundo externo deve usar apenas o contrato ClientsContract.
class ClientsRepository implements ClientsContract {
  final SupabaseClient _client = SupabaseConfig.client;

  @override
  Future<List<Map<String, dynamic>>> getClients() async {
    try {
      final orgId = OrganizationContext.currentOrganizationId;
      if (orgId == null) {
        debugPrint('⚠️ Nenhuma organização ativa - retornando lista vazia');
        return [];
      }

      debugPrint('Buscando clientes da organização: $orgId');
      final response = await _client
          .from('clients')
          .select('id, name, email, phone, company, address, city, state, zip_code, country, website, notes, status, owner_id, created_at, updated_at, avatar_url, category, category_id, social_networks, tax_id, tax_id_type, legal_name, client_categories(*)')
          .eq('organization_id', orgId)
          .order('created_at', ascending: false);

      debugPrint('Resposta do Supabase para clientes: $response');

      return response.map<Map<String, dynamic>>((client) {
        return {
          'id': client['id'] ?? '',
          'name': client['name'] ?? 'Cliente sem nome',
          'email': client['email'],
          'phone': client['phone'],
          'company': client['company'],
          'address': client['address'],
          'city': client['city'],
          'state': client['state'],
          'zip_code': client['zip_code'],
          'country': client['country'],
          'website': client['website'],
          'notes': client['notes'],
          'status': client['status'] ?? 'nao_prospectado',
          'owner_id': client['owner_id'] ?? '',
          'created_at': client['created_at'] ?? DateTime.now().toIso8601String(),
          'updated_at': client['updated_at'] ?? DateTime.now().toIso8601String(),
          'avatar_url': client['avatar_url'],
          'category': client['category'],
          'category_id': client['category_id'],
          'social_networks': client['social_networks'],
          'tax_id': client['tax_id'],
          'tax_id_type': client['tax_id_type'],
          'legal_name': client['legal_name'],
          'client_categories': client['client_categories'],
          'profiles': client['profiles'],
        };
      }).toList();
    } catch (e) {
      debugPrint('Erro ao buscar clientes: $e');
      return [];
    }
  }

  @override
  Future<Map<String, dynamic>?> getClientById(String clientId) async {
    try {
      debugPrint('Buscando cliente por ID: $clientId');
      final response = await _client
          .from('clients')
          .select('*')
          .eq('id', clientId)
          .single();

      debugPrint('Cliente encontrado: $response');
      return response;
    } catch (e) {
      debugPrint('Erro ao buscar cliente por ID: $e');
      return null;
    }
  }

  @override
  Future<Map<String, dynamic>> createClient({
    required String name,
    String? email,
    String? phone,
    String? company,
    String? address,
    String? city,
    String? state,
    String? zipCode,
    String? country,
    String? website,
    String? notes,
    String status = 'nao_prospectado',
    String? avatarUrl,
    String? categoryId,
    String? taxId,
    String? taxIdType,
    String? legalName,
  }) async {
    final user = authModule.currentUser;
    if (user == null) throw Exception('Usuário não autenticado');

    final orgId = OrganizationContext.currentOrganizationId;
    if (orgId == null) throw Exception('Nenhuma organização ativa');

    final clientData = <String, dynamic>{
      'name': name.trim(),
      'email': email?.trim(),
      'phone': phone?.trim(),
      'company': company?.trim(),
      'address': address?.trim(),
      'city': city?.trim(),
      'state': state?.trim(),
      'zip_code': zipCode?.trim(),
      'country': country?.trim(),
      'website': website?.trim(),
      'notes': notes?.trim(),
      'status': status,
      'owner_id': user.id,
      'organization_id': orgId,
      if (avatarUrl != null) 'avatar_url': avatarUrl,
      if (categoryId != null) 'category_id': categoryId,
      if (taxId != null) 'tax_id': taxId.trim(),
      if (taxIdType != null) 'tax_id_type': taxIdType.trim(),
      if (legalName != null) 'legal_name': legalName.trim(),
    };

    try {
      final response = await _client
          .from('clients')
          .insert(clientData)
          .select()
          .single();
      return response;
    } catch (e) {
      debugPrint('Erro ao criar cliente: $e');
      debugPrint('Dados enviados: $clientData');
      rethrow;
    }
  }

  @override
  Future<Map<String, dynamic>> updateClient({
    required String clientId,
    String? name,
    String? email,
    String? phone,
    String? company,
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
  }) async {
    // Buscar nome antigo se o nome está sendo alterado
    String? oldName;
    if (name != null) {
      try {
        final current = await _client
            .from('clients')
            .select('name')
            .eq('id', clientId)
            .single();
        oldName = current['name'] as String?;
      } catch (e) {
        debugPrint('Erro ao buscar nome antigo do cliente: $e');
      }
    }

    final updateData = <String, dynamic>{};

    if (name != null) updateData['name'] = name.trim();
    if (email != null) updateData['email'] = email.trim();
    if (phone != null) updateData['phone'] = phone.trim();
    if (company != null) updateData['company'] = company.trim();
    if (address != null) updateData['address'] = address.trim();
    if (city != null) updateData['city'] = city.trim();
    if (state != null) updateData['state'] = state.trim();
    if (zipCode != null) updateData['zip_code'] = zipCode.trim();
    if (country != null) updateData['country'] = country.trim();
    if (website != null) updateData['website'] = website.trim();
    if (notes != null) updateData['notes'] = notes.trim();
    if (status != null) updateData['status'] = status;
    if (taxId != null) updateData['tax_id'] = taxId.trim();
    if (taxIdType != null) updateData['tax_id_type'] = taxIdType.trim();
    if (legalName != null) updateData['legal_name'] = legalName.trim();

    // Adicionar updated_by e updated_at
    updateData['updated_at'] = DateTime.now().toIso8601String();

    try {
      final response = await _client
          .from('clients')
          .update(updateData)
          .eq('id', clientId)
          .select()
          .single();

      // Renomear pasta no Google Drive se o nome foi alterado
      if (name != null && oldName != null && oldName.isNotEmpty && name.trim() != oldName) {
        try {
          final drive = GoogleDriveOAuthService();
          final authed = await drive.getAuthedClient();
          await drive.renameClientFolder(
            client: authed,
            oldClientName: oldName,
            newClientName: name.trim(),
          );
        } catch (e) {
          debugPrint('⚠️ Erro ao renomear pasta do cliente no Google Drive (ignorado): $e');
        }
      }

      return response;
    } catch (e) {
      debugPrint('Erro ao atualizar cliente: $e');
      rethrow;
    }
  }

  @override
  Future<void> deleteClient(String clientId) async {
    try {
      // Buscar nome do cliente antes de deletar
      String? clientName;
      try {
        final response = await _client
            .from('clients')
            .select('name')
            .eq('id', clientId)
            .single();
        clientName = response['name'] as String?;
      } catch (e) {
        debugPrint('Erro ao buscar nome do cliente: $e');
      }

      // Deletar do banco de dados
      await _client
          .from('clients')
          .delete()
          .eq('id', clientId);

      // Deletar pasta do Google Drive (best-effort)
      if (clientName != null && clientName.isNotEmpty) {
        try {
          final drive = GoogleDriveOAuthService();
          final authed = await drive.getAuthedClient();
          await drive.deleteClientFolder(
            client: authed,
            clientName: clientName,
          );
          debugPrint('✅ Pasta do cliente deletada do Google Drive: $clientName');
        } catch (e) {
          debugPrint('⚠️ Erro ao deletar pasta do cliente do Google Drive (ignorado): $e');
        }
      }
    } catch (e) {
      debugPrint('Erro ao deletar cliente: $e');
      rethrow;
    }
  }
}

/// Instância singleton do repositório de clientes
/// Esta é a ÚNICA instância que deve ser usada em todo o aplicativo
final ClientsContract clientsModule = ClientsRepository();

