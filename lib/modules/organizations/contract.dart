/// Interface pública do módulo de organizações
abstract class OrganizationsContract {
  // ============================================================================
  // ORGANIZATIONS
  // ============================================================================

  /// Buscar todas as organizações do usuário autenticado
  Future<List<Map<String, dynamic>>> getMyOrganizations();

  /// Buscar uma organização por ID
  Future<Map<String, dynamic>?> getOrganization(String organizationId);

  /// Criar uma nova organização (usuário se torna owner)
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
  });

  /// Atualizar uma organização
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
  });

  /// Deletar uma organização (apenas owner)
  Future<void> deleteOrganization(String organizationId);

  // ============================================================================
  // ORGANIZATION MEMBERS
  // ============================================================================

  /// Buscar membros de uma organização
  Future<List<Map<String, dynamic>>> getOrganizationMembers(String organizationId);

  /// Buscar um membro específico
  Future<Map<String, dynamic>?> getOrganizationMember({
    required String organizationId,
    required String userId,
  });

  /// Adicionar um membro à organização (apenas owner/admin)
  Future<Map<String, dynamic>> addOrganizationMember({
    required String organizationId,
    required String userId,
    required String role,
  });

  /// Atualizar role de um membro (apenas owner/admin)
  Future<Map<String, dynamic>> updateOrganizationMemberRole({
    required String organizationId,
    required String userId,
    required String role,
  });

  /// Atualizar status de um membro (apenas owner/admin)
  Future<Map<String, dynamic>> updateOrganizationMemberStatus({
    required String organizationId,
    required String userId,
    required String status,
  });

  /// Remover um membro da organização (apenas owner/admin)
  Future<void> removeOrganizationMember({
    required String organizationId,
    required String userId,
  });

  /// Sair de uma organização (usuário remove a si mesmo)
  Future<void> leaveOrganization(String organizationId);

  // ============================================================================
  // ORGANIZATION INVITES
  // ============================================================================

  /// Buscar convites pendentes de uma organização
  Future<List<Map<String, dynamic>>> getOrganizationInvites(String organizationId);

  /// Buscar convites recebidos pelo usuário autenticado
  Future<List<Map<String, dynamic>>> getMyInvites();

  /// Criar um convite para uma organização (apenas owner/admin)
  Future<Map<String, dynamic>> createOrganizationInvite({
    required String organizationId,
    required String email,
    required String role,
  });

  /// Aceitar um convite
  Future<Map<String, dynamic>> acceptInvite(String inviteId);

  /// Rejeitar um convite
  Future<void> rejectInvite(String inviteId);

  /// Cancelar um convite (apenas owner/admin)
  Future<void> cancelInvite(String inviteId);

  /// Reenviar um convite (apenas owner/admin)
  Future<Map<String, dynamic>> resendInvite(String inviteId);

  // ============================================================================
  // HELPERS
  // ============================================================================

  /// Verificar se o usuário é membro de uma organização
  Future<bool> isMember(String organizationId);

  /// Verificar se o usuário tem uma role específica em uma organização
  Future<bool> hasRole({
    required String organizationId,
    required String role,
  });

  /// Verificar se o usuário é owner de uma organização
  Future<bool> isOwner(String organizationId);

  /// Verificar se o usuário pode gerenciar membros (owner ou admin)
  Future<bool> canManageMembers(String organizationId);

  /// Verificar se o usuário pode gerenciar a organização (owner ou admin)
  Future<bool> canManageOrganization(String organizationId);

  /// Buscar a role do usuário em uma organização
  Future<String?> getUserRole(String organizationId);
}

