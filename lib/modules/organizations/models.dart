// Modelos de dados do módulo de organizações
// Atualmente usa Map<String, dynamic> para flexibilidade
// Pode ser expandido no futuro para classes tipadas

/// Helper para criar um Map de Organization a partir de dados do Supabase
Map<String, dynamic> organizationFromJson(Map<String, dynamic> json) {
  return {
    'id': json['id'] ?? '',
    'name': json['name'] ?? 'Organização sem nome',
    'slug': json['slug'] ?? '',
    'legal_name': json['legal_name'],
    'trade_name': json['trade_name'],
    'tax_id': json['tax_id'],
    'tax_id_type': json['tax_id_type'],
    'state_registration': json['state_registration'],
    'municipal_registration': json['municipal_registration'],
    'address': json['address'],
    'address_number': json['address_number'],
    'address_complement': json['address_complement'],
    'neighborhood': json['neighborhood'],
    'city': json['city'],
    'state_province': json['state_province'],
    'postal_code': json['postal_code'],
    'country': json['country'] ?? 'Brasil',
    'phone': json['phone'],
    'mobile': json['mobile'],
    'email': json['email'],
    'website': json['website'],
    'logo_url': json['logo_url'],
    'primary_color': json['primary_color'],
    'secondary_color': json['secondary_color'],
    'invoice_prefix': json['invoice_prefix'],
    'invoice_next_number': json['invoice_next_number'] ?? 1,
    'invoice_footer_text': json['invoice_footer_text'],
    'bank_name': json['bank_name'],
    'bank_agency': json['bank_agency'],
    'bank_account': json['bank_account'],
    'bank_account_type': json['bank_account_type'],
    'pix_key': json['pix_key'],
    'pix_key_type': json['pix_key_type'],
    'fiscal_country': json['fiscal_country'],
    'fiscal_data': json['fiscal_data'],
    'bank_data': json['bank_data'],
    'owner_id': json['owner_id'] ?? '',
    'status': json['status'] ?? 'active',
    'created_at': json['created_at'] ?? DateTime.now().toIso8601String(),
    'updated_at': json['updated_at'] ?? DateTime.now().toIso8601String(),
  };
}

/// Helper para criar um Map de OrganizationMember a partir de dados do Supabase
Map<String, dynamic> organizationMemberFromJson(Map<String, dynamic> json) {
  return {
    'id': json['id'] ?? '',
    'organization_id': json['organization_id'] ?? '',
    'user_id': json['user_id'] ?? '',
    'role': json['role'] ?? 'usuario',
    'status': json['status'] ?? 'active',
    'invited_by': json['invited_by'],
    'joined_at': json['joined_at'],
    'created_at': json['created_at'] ?? DateTime.now().toIso8601String(),
    'updated_at': json['updated_at'] ?? DateTime.now().toIso8601String(),
    // Dados relacionados (se incluídos na query)
    'user': json['profiles'],
    'organization': json['organizations'],
  };
}

/// Helper para criar um Map de OrganizationInvite a partir de dados do Supabase
Map<String, dynamic> organizationInviteFromJson(Map<String, dynamic> json) {
  return {
    'id': json['id'] ?? '',
    'organization_id': json['organization_id'] ?? '',
    'email': json['email'] ?? '',
    'role': json['role'] ?? 'usuario',
    'token': json['token'] ?? '',
    'status': json['status'] ?? 'pending',
    'invited_by': json['invited_by'] ?? '',
    'expires_at': json['expires_at'],
    'accepted_at': json['accepted_at'],
    'created_at': json['created_at'] ?? DateTime.now().toIso8601String(),
    // Dados relacionados (se incluídos na query)
    'organization': json['organizations'],
    'inviter': json['profiles'],
  };
}

/// Roles disponíveis em uma organização
class OrganizationRole {
  static const String owner = 'owner';
  static const String admin = 'admin';
  static const String gestor = 'gestor';
  static const String financeiro = 'financeiro';
  static const String designer = 'designer';
  static const String usuario = 'usuario';

  static const List<String> all = [
    owner,
    admin,
    gestor,
    financeiro,
    designer,
    usuario,
  ];

  static String getDisplayName(String role) {
    switch (role) {
      case owner:
        return 'Proprietário';
      case admin:
        return 'Administrador';
      case gestor:
        return 'Gestor';
      case financeiro:
        return 'Financeiro';
      case designer:
        return 'Designer';
      case usuario:
        return 'Usuário';
      default:
        return role;
    }
  }

  static bool canManageMembers(String role) {
    return role == owner || role == admin;
  }

  static bool canManageOrganization(String role) {
    return role == owner || role == admin;
  }

  static bool isOwner(String role) {
    return role == owner;
  }
}

/// Status de membro de organização
class OrganizationMemberStatus {
  static const String active = 'active';
  static const String inactive = 'inactive';
  static const String suspended = 'suspended';

  static const List<String> all = [active, inactive, suspended];

  static String getDisplayName(String status) {
    switch (status) {
      case active:
        return 'Ativo';
      case inactive:
        return 'Inativo';
      case suspended:
        return 'Suspenso';
      default:
        return status;
    }
  }
}

/// Status de convite de organização
class OrganizationInviteStatus {
  static const String pending = 'pending';
  static const String accepted = 'accepted';
  static const String rejected = 'rejected';
  static const String expired = 'expired';

  static const List<String> all = [pending, accepted, rejected, expired];

  static String getDisplayName(String status) {
    switch (status) {
      case pending:
        return 'Pendente';
      case accepted:
        return 'Aceito';
      case rejected:
        return 'Rejeitado';
      case expired:
        return 'Expirado';
      default:
        return status;
    }
  }
}

/// Status de organização
class OrganizationStatus {
  static const String active = 'active';
  static const String inactive = 'inactive';
  static const String suspended = 'suspended';

  static const List<String> all = [active, inactive, suspended];

  static String getDisplayName(String status) {
    switch (status) {
      case active:
        return 'Ativa';
      case inactive:
        return 'Inativa';
      case suspended:
        return 'Suspensa';
      default:
        return status;
    }
  }
}

