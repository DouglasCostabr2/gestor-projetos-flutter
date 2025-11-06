import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'contract.dart';
import 'models.dart';
import '../auth/module.dart';
import '../../services/google_drive_oauth_service.dart';

class OrganizationsRepository implements OrganizationsContract {
  final SupabaseClient _client = Supabase.instance.client;

  // ============================================================================
  // ORGANIZATIONS
  // ============================================================================

  @override
  Future<List<Map<String, dynamic>>> getMyOrganizations() async {
    try {
      final user = authModule.currentUser;
      if (user == null) throw Exception('Usuário não autenticado');

      debugPrint('🔍 [Repository] Buscando organizações do usuário ${user.id}...');

      // Buscar organizações onde o usuário é membro ativo
      final response = await _client
          .from('organization_members')
          .select('''
            organization_id,
            role,
            organizations:organization_id (
              id, name, slug, legal_name, trade_name, tax_id, tax_id_type,
              state_registration, municipal_registration, address, address_number,
              address_complement, neighborhood, city, state_province, postal_code, country,
              phone, mobile, email, website, logo_url, primary_color,
              invoice_prefix, next_invoice_number, invoice_notes, invoice_terms,
              bank_name, bank_code, bank_agency, bank_account, bank_account_type,
              pix_key, pix_key_type, fiscal_country, fiscal_data, bank_data,
              owner_id, status, created_at, updated_at
            )
          ''')
          .eq('user_id', user.id)
          .eq('status', 'active')
          .order('created_at', ascending: false);

      debugPrint('🔍 [Repository] Memberships encontrados: ${response.length}');

      // Extrair organizações dos memberships
      final organizations = response
          .where((membership) => membership['organizations'] != null)
          .map<Map<String, dynamic>>((membership) {
            final org = membership['organizations'] as Map<String, dynamic>;
            return organizationFromJson(org);
          })
          .toList();

      debugPrint('✅ [Repository] Organizações encontradas: ${organizations.length}');
      if (organizations.isNotEmpty) {
        debugPrint('✅ [Repository] IDs: ${organizations.map((o) => o['id']).join(', ')}');
      }

      return organizations;
    } catch (e, stackTrace) {
      debugPrint('❌ [Repository] Erro ao buscar organizações: $e');
      debugPrint('Stack trace: $stackTrace');
      rethrow;
    }
  }

  @override
  Future<Map<String, dynamic>?> getOrganization(String organizationId) async {
    try {
      debugPrint('🔍 [Repository] Buscando organização $organizationId...');

      final response = await _client
          .from('organizations')
          .select('''
            id, name, slug, legal_name, trade_name, tax_id, tax_id_type,
            state_registration, municipal_registration, address, address_number,
            address_complement, neighborhood, city, state_province, postal_code, country,
            phone, mobile, email, website, logo_url, primary_color,
            invoice_prefix, next_invoice_number, invoice_notes, invoice_terms,
            bank_name, bank_code, bank_agency, bank_account, bank_account_type,
            pix_key, pix_key_type, fiscal_country, fiscal_data, bank_data,
            owner_id, status, created_at, updated_at
          ''')
          .eq('id', organizationId)
          .maybeSingle();

      debugPrint('🔍 [Repository] Response: ${response != null ? "encontrada" : "null"}');

      if (response == null) {
        debugPrint('❌ [Repository] Organização não encontrada');
        return null;
      }

      debugPrint('✅ [Repository] Organização encontrada: ${response['name']}');
      return organizationFromJson(response);
    } catch (e, stackTrace) {
      debugPrint('❌ [Repository] Erro ao buscar organização: $e');
      debugPrint('Stack trace: $stackTrace');
      return null;
    }
  }

  @override
  Future<Map<String, dynamic>> createOrganization({
    required String name,
    required String slug,
    String? legalName,
    String? tradeName,
    String? taxId,
    String? taxIdType,
    String? stateRegistration,
    String? municipalRegistration,
    String? address,
    String? addressNumber,
    String? addressComplement,
    String? neighborhood,
    String? city,
    String? state,
    String? zipCode,
    String? country,
    String? phone,
    String? mobile,
    String? email,
    String? website,
    String? logoUrl,
    String? primaryColor,
    String? secondaryColor,
    String? invoicePrefix,
    int? nextInvoiceNumber,
    String? invoiceNotes,
    String? invoiceTerms,
    String? bankName,
    String? bankCode,
    String? bankAgency,
    String? bankAccount,
    String? bankAccountType,
    String? pixKey,
    String? pixKeyType,
  }) async {
    final user = authModule.currentUser;
    if (user == null) throw Exception('Usuário não autenticado');

    debugPrint('🏢 Criando organização: $name');
    debugPrint('   Slug: $slug');
    debugPrint('   User ID: ${user.id}');

    try {
      // Usar função do Supabase para criar organização
      // Isso contorna problemas de RLS
      final response = await _client.rpc('create_organization', params: {
        'p_name': name.trim(),
        'p_slug': slug.trim().toLowerCase(),
        'p_legal_name': legalName?.trim(),
        'p_email': email?.trim(),
        'p_phone': phone?.trim(),
      });

      debugPrint('✅ Organização criada com sucesso via RPC');

      // Se temos campos adicionais, atualizar a organização
      if (tradeName != null ||
          taxId != null ||
          address != null ||
          city != null ||
          website != null ||
          logoUrl != null ||
          primaryColor != null ||
          bankName != null) {
        debugPrint('📝 Atualizando campos adicionais...');
        await _updateAdditionalFields(
          response['id'],
          tradeName: tradeName,
          taxId: taxId,
          taxIdType: taxIdType,
          stateRegistration: stateRegistration,
          municipalRegistration: municipalRegistration,
          address: address,
          addressNumber: addressNumber,
          addressComplement: addressComplement,
          neighborhood: neighborhood,
          city: city,
          state: state,
          zipCode: zipCode,
          country: country,
          mobile: mobile,
          website: website,
          logoUrl: logoUrl,
          primaryColor: primaryColor,
          secondaryColor: secondaryColor,
          invoicePrefix: invoicePrefix,
          nextInvoiceNumber: nextInvoiceNumber,
          invoiceNotes: invoiceNotes,
          invoiceTerms: invoiceTerms,
          bankName: bankName,
          bankCode: bankCode,
          bankAgency: bankAgency,
          bankAccount: bankAccount,
          bankAccountType: bankAccountType,
          pixKey: pixKey,
          pixKeyType: pixKeyType,
        );
      }

      return organizationFromJson(response as Map<String, dynamic>);
    } catch (e) {
      debugPrint('❌ Erro ao criar organização: $e');
      rethrow;
    }
  }

  /// Atualiza campos adicionais da organização
  Future<void> _updateAdditionalFields(
    String orgId, {
    String? tradeName,
    String? taxId,
    String? taxIdType,
    String? stateRegistration,
    String? municipalRegistration,
    String? address,
    String? addressNumber,
    String? addressComplement,
    String? neighborhood,
    String? city,
    String? state,
    String? zipCode,
    String? country,
    String? mobile,
    String? website,
    String? logoUrl,
    String? primaryColor,
    String? secondaryColor,
    String? invoicePrefix,
    int? nextInvoiceNumber,
    String? invoiceNotes,
    String? invoiceTerms,
    String? bankName,
    String? bankCode,
    String? bankAgency,
    String? bankAccount,
    String? bankAccountType,
    String? pixKey,
    String? pixKeyType,
  }) async {
    final updateData = <String, dynamic>{};

    if (tradeName != null) updateData['trade_name'] = tradeName.trim();
    if (taxId != null) updateData['tax_id'] = taxId.trim();
    if (taxIdType != null) updateData['tax_id_type'] = taxIdType.trim();
    if (stateRegistration != null) updateData['state_registration'] = stateRegistration.trim();
    if (municipalRegistration != null) updateData['municipal_registration'] = municipalRegistration.trim();
    if (address != null) updateData['address'] = address.trim();
    if (addressNumber != null) updateData['address_number'] = addressNumber.trim();
    if (addressComplement != null) updateData['address_complement'] = addressComplement.trim();
    if (neighborhood != null) updateData['neighborhood'] = neighborhood.trim();
    if (city != null) updateData['city'] = city.trim();
    if (state != null) updateData['state_province'] = state.trim();
    if (zipCode != null) updateData['postal_code'] = zipCode.trim();
    if (country != null) updateData['country'] = country.trim();
    if (mobile != null) updateData['mobile'] = mobile.trim();
    if (website != null) updateData['website'] = website.trim();
    if (logoUrl != null) updateData['logo_url'] = logoUrl;
    if (primaryColor != null) updateData['primary_color'] = primaryColor;
    if (secondaryColor != null) updateData['secondary_color'] = secondaryColor;
    if (invoicePrefix != null) updateData['invoice_prefix'] = invoicePrefix.trim();
    if (nextInvoiceNumber != null) updateData['next_invoice_number'] = nextInvoiceNumber;
    if (invoiceNotes != null) updateData['invoice_notes'] = invoiceNotes.trim();
    if (invoiceTerms != null) updateData['invoice_terms'] = invoiceTerms.trim();
    if (bankName != null) updateData['bank_name'] = bankName.trim();
    if (bankCode != null) updateData['bank_code'] = bankCode.trim();
    if (bankAgency != null) updateData['bank_agency'] = bankAgency.trim();
    if (bankAccount != null) updateData['bank_account'] = bankAccount.trim();
    if (bankAccountType != null) updateData['bank_account_type'] = bankAccountType;
    if (pixKey != null) updateData['pix_key'] = pixKey.trim();
    if (pixKeyType != null) updateData['pix_key_type'] = pixKeyType;

    if (updateData.isNotEmpty) {
      await _client
          .from('organizations')
          .update(updateData)
          .eq('id', orgId);

      debugPrint('✅ Campos adicionais atualizados');
    }
  }

  @override
  Future<Map<String, dynamic>> updateOrganization({
    required String organizationId,
    String? name,
    String? slug,
    String? legalName,
    String? tradeName,
    String? taxId,
    String? taxIdType,
    String? stateRegistration,
    String? municipalRegistration,
    String? address,
    String? addressNumber,
    String? addressComplement,
    String? neighborhood,
    String? city,
    String? state,
    String? zipCode,
    String? country,
    String? phone,
    String? mobile,
    String? email,
    String? website,
    String? logoUrl,
    String? primaryColor,
    String? secondaryColor,
    String? invoicePrefix,
    int? nextInvoiceNumber,
    String? invoiceNotes,
    String? invoiceTerms,
    String? bankName,
    String? bankCode,
    String? bankAgency,
    String? bankAccount,
    String? bankAccountType,
    String? pixKey,
    String? pixKeyType,
    String? status,
    String? fiscalCountry,
    String? fiscalData,
    String? bankData,
  }) async {
    final orgData = <String, dynamic>{};

    // Campos obrigatórios
    if (name != null) orgData['name'] = name.trim();

    // Campos opcionais - aceita string vazia para limpar o valor no banco
    if (slug != null) orgData['slug'] = slug.trim().isEmpty ? null : slug.trim().toLowerCase();
    if (legalName != null) orgData['legal_name'] = legalName.trim().isEmpty ? null : legalName.trim();
    if (tradeName != null) orgData['trade_name'] = tradeName.trim().isEmpty ? null : tradeName.trim();
    if (taxId != null) orgData['tax_id'] = taxId.trim().isEmpty ? null : taxId.trim();
    if (taxIdType != null) orgData['tax_id_type'] = taxIdType.trim().isEmpty ? null : taxIdType.trim();
    if (stateRegistration != null) orgData['state_registration'] = stateRegistration.trim().isEmpty ? null : stateRegistration.trim();
    if (municipalRegistration != null) orgData['municipal_registration'] = municipalRegistration.trim().isEmpty ? null : municipalRegistration.trim();
    if (address != null) orgData['address'] = address.trim().isEmpty ? null : address.trim();
    if (addressNumber != null) orgData['address_number'] = addressNumber.trim().isEmpty ? null : addressNumber.trim();
    if (addressComplement != null) orgData['address_complement'] = addressComplement.trim().isEmpty ? null : addressComplement.trim();
    if (neighborhood != null) orgData['neighborhood'] = neighborhood.trim().isEmpty ? null : neighborhood.trim();
    if (city != null) orgData['city'] = city.trim().isEmpty ? null : city.trim();
    if (state != null) orgData['state_province'] = state.trim().isEmpty ? null : state.trim();
    if (zipCode != null) orgData['postal_code'] = zipCode.trim().isEmpty ? null : zipCode.trim();
    if (country != null) orgData['country'] = country.trim().isEmpty ? null : country.trim();
    if (phone != null) orgData['phone'] = phone.trim().isEmpty ? null : phone.trim();
    if (mobile != null) orgData['mobile'] = mobile.trim().isEmpty ? null : mobile.trim();
    if (email != null) orgData['email'] = email.trim().isEmpty ? null : email.trim();
    if (website != null) orgData['website'] = website.trim().isEmpty ? null : website.trim();
    if (logoUrl != null) orgData['logo_url'] = logoUrl;
    if (primaryColor != null) orgData['primary_color'] = primaryColor;
    if (secondaryColor != null) orgData['secondary_color'] = secondaryColor;
    if (invoicePrefix != null) orgData['invoice_prefix'] = invoicePrefix.trim().isEmpty ? null : invoicePrefix.trim();
    if (nextInvoiceNumber != null) orgData['next_invoice_number'] = nextInvoiceNumber;
    if (invoiceNotes != null) orgData['invoice_notes'] = invoiceNotes.trim().isEmpty ? null : invoiceNotes.trim();
    if (invoiceTerms != null) orgData['invoice_terms'] = invoiceTerms.trim().isEmpty ? null : invoiceTerms.trim();
    if (bankName != null) orgData['bank_name'] = bankName.trim().isEmpty ? null : bankName.trim();
    if (bankCode != null) orgData['bank_code'] = bankCode.trim().isEmpty ? null : bankCode.trim();
    if (bankAgency != null) orgData['bank_agency'] = bankAgency.trim().isEmpty ? null : bankAgency.trim();
    if (bankAccount != null) orgData['bank_account'] = bankAccount.trim().isEmpty ? null : bankAccount.trim();
    if (bankAccountType != null) orgData['bank_account_type'] = bankAccountType;
    if (pixKey != null) orgData['pix_key'] = pixKey.trim().isEmpty ? null : pixKey.trim();
    if (pixKeyType != null) orgData['pix_key_type'] = pixKeyType;
    if (status != null) orgData['status'] = status;
    if (fiscalCountry != null) orgData['fiscal_country'] = fiscalCountry.trim().isEmpty ? null : fiscalCountry.trim();
    if (fiscalData != null) orgData['fiscal_data'] = fiscalData;
    if (bankData != null) orgData['bank_data'] = bankData;

    if (orgData.isEmpty) {
      throw Exception('Nenhum campo para atualizar');
    }

    final response = await _client
        .from('organizations')
        .update(orgData)
        .eq('id', organizationId)
        .select()
        .single();

    return organizationFromJson(response);
  }

  @override
  Future<void> deleteOrganization(String organizationId) async {
    debugPrint('🗑️ Deletando organização $organizationId (com limpeza de dependências)');

    try {
      // 0) Buscar nome da organização antes de deletar (para limpar Google Drive)
      final orgResp = await _client
          .from('organizations')
          .select('name')
          .eq('id', organizationId)
          .maybeSingle();

      final organizationName = orgResp?['name'] as String?;

      // 1) Buscar IDs de produtos e pacotes da organização (para limpar package_items antes)
      final productsResp = await _client
          .from('products')
          .select('id')
          .eq('organization_id', organizationId);
      final packagesResp = await _client
          .from('packages')
          .select('id')
          .eq('organization_id', organizationId);

      final productIds = ((productsResp as List?) ?? [])
          .map((e) => (e['id'] ?? '').toString())
          .where((id) => id.isNotEmpty)
          .toList();
      final packageIds = ((packagesResp as List?) ?? [])
          .map((e) => (e['id'] ?? '').toString())
          .where((id) => id.isNotEmpty)
          .toList();

      // 2) Limpar package_items que referenciam esses produtos/pacotes
      if (productIds.isNotEmpty) {
        final inList = productIds.map((e) => '"$e"').join(',');
        debugPrint('➡️ Removendo package_items por product_id (count=${productIds.length})');
        await _client
            .from('package_items')
            .delete()
            .filter('product_id', 'in', '($inList)');
      }
      if (packageIds.isNotEmpty) {
        final inList = packageIds.map((e) => '"$e"').join(',');
        debugPrint('➡️ Removendo package_items por package_id (count=${packageIds.length})');
        await _client
            .from('package_items')
            .delete()
            .filter('package_id', 'in', '($inList)');
      }

      // 3) Limpar arquivos do Supabase Storage
      debugPrint('🗑️ Limpando arquivos do Supabase Storage...');
      await _deleteOrganizationStorageFiles(organizationId);

      // 4) Limpar pasta do Google Drive (best-effort)
      if (organizationName != null && organizationName.isNotEmpty) {
        debugPrint('🗑️ Limpando pasta do Google Drive...');
        await _deleteOrganizationDriveFolder(organizationName);
      }

      // 5) Agora deletar a organização (CASCADE cuidará do resto)
      await _client
          .from('organizations')
          .delete()
          .eq('id', organizationId);

      debugPrint('✅ Organização deletada com sucesso');
    } catch (e, st) {
      debugPrint('❌ Erro ao deletar organização: $e');
      debugPrint('$st');
      rethrow;
    }
  }

  /// Deleta todos os arquivos do Supabase Storage relacionados à organização
  Future<void> _deleteOrganizationStorageFiles(String organizationId) async {
    final buckets = ['avatars', 'client-avatars', 'product-thumbnails'];

    for (final bucket in buckets) {
      try {
        debugPrint('🗑️ Limpando bucket: $bucket');

        // Listar todos os arquivos na pasta da organização
        final files = await _client.storage
            .from(bucket)
            .list(path: organizationId);

        if (files.isEmpty) {
          debugPrint('   ℹ️ Nenhum arquivo encontrado em $bucket/$organizationId');
          continue;
        }

        // Criar lista de paths para deletar
        final filePaths = files
            .map((file) => '$organizationId/${file.name}')
            .toList();

        debugPrint('   🗑️ Deletando ${filePaths.length} arquivo(s) de $bucket');

        // Deletar todos os arquivos
        await _client.storage
            .from(bucket)
            .remove(filePaths);

        debugPrint('   ✅ Arquivos deletados de $bucket');
      } catch (e) {
        // Não falhar a exclusão da organização se houver erro no storage
        debugPrint('   ⚠️ Erro ao limpar bucket $bucket: $e');
      }
    }
  }

  /// Deleta a pasta da organização no Google Drive (best-effort)
  Future<void> _deleteOrganizationDriveFolder(String organizationName) async {
    try {
      final driveService = GoogleDriveOAuthService();
      final client = await driveService.getAuthedClient();

      await driveService.deleteOrganizationFolder(
        client: client,
        organizationName: organizationName,
      );
    } catch (e) {
      // Não falhar a exclusão da organização se houver erro no Drive
      debugPrint('⚠️ Erro ao deletar pasta do Google Drive (ignorado): $e');
    }
  }

  // ============================================================================
  // ORGANIZATION MEMBERS
  // ============================================================================

  @override
  Future<List<Map<String, dynamic>>> getOrganizationMembers(String organizationId) async {
    try {
      // Usar RPC para fazer o join correto
      final response = await _client.rpc(
        'get_organization_members_with_profiles',
        params: {'org_id': organizationId},
      );

      return (response as List).map<Map<String, dynamic>>((member) {
        final m = member as Map<String, dynamic>;
        // Transformar para o formato esperado
        return {
          'id': m['user_id'], // Usar user_id como id temporário
          'organization_id': organizationId,
          'user_id': m['user_id'],
          'role': m['om_role'], // Role do organization_members
          'status': m['status'],
          'invited_by': null,
          'joined_at': null,
          'created_at': null,
          'updated_at': null,
          'profiles': {
            'id': m['user_id'],
            'email': m['email'],
            'full_name': m['full_name'],
            'avatar_url': m['avatar_url'],
          },
        };
      }).toList();
    } catch (e) {
      debugPrint('Erro ao buscar membros: $e');
      rethrow;
    }
  }

  @override
  Future<Map<String, dynamic>?> getOrganizationMember({
    required String organizationId,
    required String userId,
  }) async {
    try {
      debugPrint('Buscando membro $userId da organização $organizationId...');

      // Buscar o membro sem join
      final response = await _client
          .from('organization_members')
          .select('id, organization_id, user_id, role, status, invited_by, joined_at, created_at, updated_at')
          .eq('organization_id', organizationId)
          .eq('user_id', userId)
          .maybeSingle();

      if (response == null) {
        debugPrint('Membro não encontrado');
        return null;
      }

      // Buscar o profile separadamente
      final profile = await _client
          .from('profiles')
          .select('id, email, full_name, avatar_url')
          .eq('id', userId)
          .maybeSingle();

      // Adicionar profile ao response
      if (profile != null) {
        response['profiles'] = profile;
      }

      return organizationMemberFromJson(response);
    } catch (e) {
      debugPrint('Erro ao buscar membro: $e');
      return null;
    }
  }

  @override
  Future<Map<String, dynamic>> addOrganizationMember({
    required String organizationId,
    required String userId,
    required String role,
  }) async {
    final user = authModule.currentUser;
    if (user == null) throw Exception('Usuário não autenticado');

    final memberData = {
      'organization_id': organizationId,
      'user_id': userId,
      'role': role,
      'status': 'active',
      'invited_by': user.id,
      'joined_at': DateTime.now().toIso8601String(),
    };

    debugPrint('Adicionando membro $userId à organização $organizationId');

    final response = await _client
        .from('organization_members')
        .insert(memberData)
        .select('id, organization_id, user_id, role, status, invited_by, joined_at, created_at, updated_at')
        .single();

    // Buscar o profile separadamente
    final profile = await _client
        .from('profiles')
        .select('id, email, full_name, avatar_url')
        .eq('id', userId)
        .maybeSingle();

    // Adicionar profile ao response
    if (profile != null) {
      response['profiles'] = profile;
    }

    debugPrint('Membro adicionado com sucesso');

    return organizationMemberFromJson(response);
  }

  @override
  Future<Map<String, dynamic>> updateOrganizationMemberRole({
    required String organizationId,
    required String userId,
    required String role,
  }) async {
    debugPrint('Atualizando role do membro $userId para $role');

    final response = await _client
        .from('organization_members')
        .update({'role': role})
        .eq('organization_id', organizationId)
        .eq('user_id', userId)
        .select('''
          id, organization_id, user_id, role, status, invited_by, joined_at,
          created_at, updated_at,
          profiles:user_id(id, email, full_name, avatar_url)
        ''')
        .single();

    debugPrint('Role atualizada com sucesso');

    return organizationMemberFromJson(response);
  }

  @override
  Future<Map<String, dynamic>> updateOrganizationMemberStatus({
    required String organizationId,
    required String userId,
    required String status,
  }) async {
    debugPrint('Atualizando status do membro $userId para $status');

    final response = await _client
        .from('organization_members')
        .update({'status': status})
        .eq('organization_id', organizationId)
        .eq('user_id', userId)
        .select('''
          id, organization_id, user_id, role, status, invited_by, joined_at,
          created_at, updated_at,
          profiles:user_id(id, email, full_name, avatar_url)
        ''')
        .single();

    debugPrint('Status atualizado com sucesso');

    return organizationMemberFromJson(response);
  }

  @override
  Future<void> removeOrganizationMember({
    required String organizationId,
    required String userId,
  }) async {
    debugPrint('Removendo membro $userId da organização $organizationId');

    await _client
        .from('organization_members')
        .delete()
        .eq('organization_id', organizationId)
        .eq('user_id', userId);

    debugPrint('Membro removido com sucesso');
  }

  @override
  Future<void> leaveOrganization(String organizationId) async {
    final user = authModule.currentUser;
    if (user == null) throw Exception('Usuário não autenticado');

    debugPrint('Usuário ${user.id} saindo da organização $organizationId');

    await _client
        .from('organization_members')
        .delete()
        .eq('organization_id', organizationId)
        .eq('user_id', user.id);

    debugPrint('Usuário saiu da organização com sucesso');
  }

  // ============================================================================
  // ORGANIZATION INVITES
  // ============================================================================

  @override
  Future<List<Map<String, dynamic>>> getOrganizationInvites(String organizationId) async {
    try {
      debugPrint('Buscando convites da organização $organizationId...');

      final response = await _client
          .from('organization_invites')
          .select('''
            id, organization_id, email, role, token, status, invited_by,
            expires_at, accepted_at, created_at,
            organizations:organization_id(name)
          ''')
          .eq('organization_id', organizationId)
          .order('created_at', ascending: false);

      debugPrint('Convites encontrados: ${response.length}');

      return response.map<Map<String, dynamic>>((invite) {
        return organizationInviteFromJson(invite);
      }).toList();
    } catch (e) {
      debugPrint('Erro ao buscar convites: $e');
      rethrow;
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getMyInvites() async {
    try {
      final user = authModule.currentUser;
      if (user == null) throw Exception('Usuário não autenticado');

      final userEmail = user.email;
      if (userEmail == null) throw Exception('Email do usuário não encontrado');

      debugPrint('Buscando convites para $userEmail...');

      final response = await _client
          .from('organization_invites')
          .select('''
            id, organization_id, email, role, token, status, invited_by,
            expires_at, accepted_at, created_at,
            organizations:organization_id(name, logo_url)
          ''')
          .eq('email', userEmail)
          .eq('status', 'pending')
          .order('created_at', ascending: false);

      debugPrint('Convites encontrados: ${response.length}');

      return response.map<Map<String, dynamic>>((invite) {
        return organizationInviteFromJson(invite);
      }).toList();
    } catch (e) {
      debugPrint('Erro ao buscar convites: $e');
      rethrow;
    }
  }

  @override
  Future<Map<String, dynamic>> createOrganizationInvite({
    required String organizationId,
    required String email,
    required String role,
  }) async {
    final user = authModule.currentUser;
    if (user == null) throw Exception('Usuário não autenticado');

    // Gerar token único
    final token = DateTime.now().millisecondsSinceEpoch.toString() +
                  email.hashCode.toString();

    // Expiração em 7 dias
    final expiresAt = DateTime.now().add(const Duration(days: 7));

    final inviteData = {
      'organization_id': organizationId,
      'email': email.trim().toLowerCase(),
      'role': role,
      'token': token,
      'status': 'pending',
      'invited_by': user.id,
      'expires_at': expiresAt.toIso8601String(),
    };

    debugPrint('📧 [INVITE] Criando convite para $email');
    debugPrint('📧 [INVITE] Organization ID: $organizationId');
    debugPrint('📧 [INVITE] Role: $role');
    debugPrint('📧 [INVITE] Invited by: ${user.id}');

    final response = await _client
        .from('organization_invites')
        .insert(inviteData)
        .select('''
          id, organization_id, email, role, token, status, invited_by,
          expires_at, accepted_at, created_at,
          organizations:organization_id(name)
        ''')
        .single();

    debugPrint('📧 [INVITE] ✅ Convite criado com sucesso! ID: ${response['id']}');
    debugPrint('📧 [INVITE] Trigger do Supabase deve criar notificação agora...');

    return organizationInviteFromJson(response);
  }

  @override
  Future<Map<String, dynamic>> acceptInvite(String inviteId) async {
    final user = authModule.currentUser;
    if (user == null) throw Exception('Usuário não autenticado');

    debugPrint('🎯 [ACCEPT_INVITE] Chamando RPC accept_organization_invite para $inviteId');

    try {
      // Chamar função RPC que bypassa RLS
      final response = await _client.rpc(
        'accept_organization_invite',
        params: {'p_invite_id': inviteId},
      );

      debugPrint('✅ [ACCEPT_INVITE] Convite aceito com sucesso via RPC!');
      debugPrint('Response: $response');

      // Buscar dados completos do convite atualizado
      final invite = await _client
          .from('organization_invites')
          .select('''
            id, organization_id, email, role, token, status, invited_by,
            expires_at, accepted_at, created_at,
            organizations:organization_id(name)
          ''')
          .eq('id', inviteId)
          .single();

      return organizationInviteFromJson(invite);
    } catch (e) {
      debugPrint('❌ [ACCEPT_INVITE] Erro ao aceitar convite: $e');
      rethrow;
    }
  }

  @override
  Future<void> rejectInvite(String inviteId) async {
    debugPrint('🎯 [REJECT_INVITE] Chamando RPC reject_organization_invite para $inviteId');

    try {
      await _client.rpc(
        'reject_organization_invite',
        params: {'p_invite_id': inviteId},
      );

      debugPrint('✅ [REJECT_INVITE] Convite rejeitado com sucesso via RPC!');
    } catch (e) {
      debugPrint('❌ [REJECT_INVITE] Erro ao rejeitar convite: $e');
      rethrow;
    }
  }

  @override
  Future<void> cancelInvite(String inviteId) async {
    debugPrint('Cancelando convite $inviteId');

    await _client
        .from('organization_invites')
        .delete()
        .eq('id', inviteId);

    debugPrint('Convite cancelado com sucesso');
  }

  @override
  Future<Map<String, dynamic>> resendInvite(String inviteId) async {
    debugPrint('Reenviando convite $inviteId');

    // Atualizar data de expiração
    final expiresAt = DateTime.now().add(const Duration(days: 7));

    final response = await _client
        .from('organization_invites')
        .update({'expires_at': expiresAt.toIso8601String()})
        .eq('id', inviteId)
        .select('''
          id, organization_id, email, role, token, status, invited_by,
          expires_at, accepted_at, created_at,
          organizations:organization_id(name)
        ''')
        .single();

    debugPrint('Convite reenviado com sucesso');

    return organizationInviteFromJson(response);
  }

  // ============================================================================
  // HELPERS
  // ============================================================================

  @override
  Future<bool> isMember(String organizationId) async {
    try {
      final user = authModule.currentUser;
      if (user == null) return false;

      final response = await _client
          .from('organization_members')
          .select('id')
          .eq('organization_id', organizationId)
          .eq('user_id', user.id)
          .eq('status', 'active')
          .maybeSingle();

      return response != null;
    } catch (e) {
      debugPrint('Erro ao verificar membership: $e');
      return false;
    }
  }

  @override
  Future<bool> hasRole({
    required String organizationId,
    required String role,
  }) async {
    try {
      final user = authModule.currentUser;
      if (user == null) return false;

      final response = await _client
          .from('organization_members')
          .select('role')
          .eq('organization_id', organizationId)
          .eq('user_id', user.id)
          .eq('status', 'active')
          .maybeSingle();

      if (response == null) return false;

      return response['role'] == role;
    } catch (e) {
      debugPrint('Erro ao verificar role: $e');
      return false;
    }
  }

  @override
  Future<bool> isOwner(String organizationId) async {
    return hasRole(organizationId: organizationId, role: 'owner');
  }

  @override
  Future<bool> canManageMembers(String organizationId) async {
    try {
      final user = authModule.currentUser;
      if (user == null) return false;

      final response = await _client
          .from('organization_members')
          .select('role')
          .eq('organization_id', organizationId)
          .eq('user_id', user.id)
          .eq('status', 'active')
          .maybeSingle();

      if (response == null) return false;

      final role = response['role'] as String;
      return OrganizationRole.canManageMembers(role);
    } catch (e) {
      debugPrint('Erro ao verificar permissão de gerenciar membros: $e');
      return false;
    }
  }

  @override
  Future<bool> canManageOrganization(String organizationId) async {
    try {
      final user = authModule.currentUser;
      if (user == null) return false;

      final response = await _client
          .from('organization_members')
          .select('role')
          .eq('organization_id', organizationId)
          .eq('user_id', user.id)
          .eq('status', 'active')
          .maybeSingle();

      if (response == null) return false;

      final role = response['role'] as String;
      return OrganizationRole.canManageOrganization(role);
    } catch (e) {
      debugPrint('Erro ao verificar permissão de gerenciar organização: $e');
      return false;
    }
  }

  @override
  Future<String?> getUserRole(String organizationId) async {
    try {
      final user = authModule.currentUser;
      if (user == null) return null;

      final response = await _client
          .from('organization_members')
          .select('role')
          .eq('organization_id', organizationId)
          .eq('user_id', user.id)
          .eq('status', 'active')
          .maybeSingle();

      if (response == null) return null;

      return response['role'] as String;
    } catch (e) {
      debugPrint('Erro ao buscar role do usuário: $e');
      return null;
    }
  }
}

