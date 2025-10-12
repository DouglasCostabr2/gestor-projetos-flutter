/// Enum que representa os diferentes papéis de usuário no sistema
enum UserRole {
  admin,
  gestor,
  financeiro,
  cliente,
  usuario,
}

/// Extensão para converter string em UserRole
extension UserRoleExtension on UserRole {
  /// Retorna o valor string do role
  String get value {
    switch (this) {
      case UserRole.admin:
        return 'admin';
      case UserRole.gestor:
        return 'gestor';
      case UserRole.financeiro:
        return 'financeiro';
      case UserRole.cliente:
        return 'cliente';
      case UserRole.usuario:
        return 'usuario';
    }
  }

  /// Retorna o label formatado do role
  String get label {
    switch (this) {
      case UserRole.admin:
        return 'Administrador';
      case UserRole.gestor:
        return 'Gestor';
      case UserRole.financeiro:
        return 'Financeiro';
      case UserRole.cliente:
        return 'Cliente';
      case UserRole.usuario:
        return 'Usuário';
    }
  }

  /// Converte string para UserRole
  static UserRole fromString(String? role) {
    switch (role?.toLowerCase()) {
      case 'admin':
        return UserRole.admin;
      case 'gestor':
        return UserRole.gestor;
      case 'financeiro':
        return UserRole.financeiro;
      case 'cliente':
        return UserRole.cliente;
      default:
        return UserRole.usuario;
    }
  }

  /// Verifica se o role tem permissão de admin
  bool get isAdmin => this == UserRole.admin;

  /// Verifica se o role tem permissão de gestor ou superior
  bool get isGestorOrAbove => this == UserRole.admin || this == UserRole.gestor;

  /// Verifica se o role tem permissão financeira
  bool get hasFinanceAccess =>
      this == UserRole.admin ||
      this == UserRole.gestor ||
      this == UserRole.financeiro;
}

