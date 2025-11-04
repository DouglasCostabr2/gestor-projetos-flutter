import '../navigation/user_role.dart';

/// Enum que representa as diferentes ações que podem ser realizadas no sistema
enum PermissionAction {
  create,
  read,
  update,
  delete,
  duplicate,
}

/// Enum que representa as diferentes entidades do sistema
enum PermissionEntity {
  project,
  task,
  client,
  company,
  category,
  product,
  package_,
  user,
}

/// Serviço centralizado de controle de permissões baseado em roles
/// 
/// Este serviço define uma matriz completa de permissões para todos os roles
/// e todas as entidades do sistema, garantindo controle de acesso consistente.
/// 
/// Exemplo de uso:
/// ```dart
/// final permissions = PermissionsService();
/// final userRole = UserRoleExtension.fromString(appState.role);
/// 
/// // Verificar se pode editar projeto
/// if (permissions.canPerformAction(userRole, PermissionEntity.project, PermissionAction.update)) {
///   // Mostrar botão de editar
/// }
/// 
/// // Verificar se pode excluir task (com verificação de ownership)
/// if (permissions.canDeleteTask(userRole, taskCreatorId, currentUserId)) {
///   // Mostrar botão de excluir
/// }
/// ```
class PermissionsService {
  /// Matriz de permissões: role -> entidade -> ação -> permitido
  static const Map<UserRole, Map<PermissionEntity, Set<PermissionAction>>> _permissions = {
    // ADMIN: Acesso total a tudo
    UserRole.admin: {
      PermissionEntity.project: {
        PermissionAction.create,
        PermissionAction.read,
        PermissionAction.update,
        PermissionAction.delete,
        PermissionAction.duplicate,
      },
      PermissionEntity.task: {
        PermissionAction.create,
        PermissionAction.read,
        PermissionAction.update,
        PermissionAction.delete,
        PermissionAction.duplicate,
      },
      PermissionEntity.client: {
        PermissionAction.create,
        PermissionAction.read,
        PermissionAction.update,
        PermissionAction.delete,
        PermissionAction.duplicate,
      },
      PermissionEntity.company: {
        PermissionAction.create,
        PermissionAction.read,
        PermissionAction.update,
        PermissionAction.delete,
        PermissionAction.duplicate,
      },
      PermissionEntity.category: {
        PermissionAction.create,
        PermissionAction.read,
        PermissionAction.update,
        PermissionAction.delete,
        PermissionAction.duplicate,
      },
      PermissionEntity.product: {
        PermissionAction.create,
        PermissionAction.read,
        PermissionAction.update,
        PermissionAction.delete,
        PermissionAction.duplicate,
      },
      PermissionEntity.package_: {
        PermissionAction.create,
        PermissionAction.read,
        PermissionAction.update,
        PermissionAction.delete,
        PermissionAction.duplicate,
      },
      PermissionEntity.user: {
        PermissionAction.create,
        PermissionAction.read,
        PermissionAction.update,
        PermissionAction.delete,
      },
    },

    // GESTOR: Gestão completa de projetos, tasks e equipe
    UserRole.gestor: {
      PermissionEntity.project: {
        PermissionAction.create,
        PermissionAction.read,
        PermissionAction.update,
        PermissionAction.delete,
        PermissionAction.duplicate,
      },
      PermissionEntity.task: {
        PermissionAction.create,
        PermissionAction.read,
        PermissionAction.update,
        PermissionAction.delete,
        PermissionAction.duplicate,
      },
      PermissionEntity.client: {
        PermissionAction.create,
        PermissionAction.read,
        PermissionAction.update,
        PermissionAction.delete,
        PermissionAction.duplicate,
      },
      PermissionEntity.company: {
        PermissionAction.create,
        PermissionAction.read,
        PermissionAction.update,
        PermissionAction.delete,
        PermissionAction.duplicate,
      },
      PermissionEntity.category: {
        PermissionAction.create,
        PermissionAction.read,
        PermissionAction.update,
        PermissionAction.delete,
        PermissionAction.duplicate,
      },
      PermissionEntity.product: {
        PermissionAction.create,
        PermissionAction.read,
        PermissionAction.update,
        PermissionAction.delete,
        PermissionAction.duplicate,
      },
      PermissionEntity.package_: {
        PermissionAction.create,
        PermissionAction.read,
        PermissionAction.update,
        PermissionAction.delete,
        PermissionAction.duplicate,
      },
      PermissionEntity.user: {
        PermissionAction.read,
        PermissionAction.update,
      },
    },

    // DESIGNER: Acesso limitado - NÃO pode editar/excluir/duplicar projetos
    UserRole.designer: {
      PermissionEntity.project: {
        PermissionAction.read, // Apenas leitura de projetos
      },
      PermissionEntity.task: {
        PermissionAction.create,
        PermissionAction.read,
        PermissionAction.update,
        // delete e duplicate são controlados por ownership (ver canDeleteTask)
      },
      PermissionEntity.client: {
        PermissionAction.read,
      },
      PermissionEntity.company: {
        PermissionAction.read,
      },
      PermissionEntity.category: {
        PermissionAction.read,
      },
      PermissionEntity.product: {
        PermissionAction.create,
        PermissionAction.read,
        PermissionAction.update,
        PermissionAction.delete,
        PermissionAction.duplicate,
      },
      PermissionEntity.package_: {
        PermissionAction.create,
        PermissionAction.read,
        PermissionAction.update,
        PermissionAction.delete,
        PermissionAction.duplicate,
      },
      PermissionEntity.user: {
        PermissionAction.read,
      },
    },

    // FINANCEIRO: Acesso a clientes e catálogo
    UserRole.financeiro: {
      PermissionEntity.project: {
        PermissionAction.read,
        PermissionAction.update, // Pode editar valores financeiros
      },
      PermissionEntity.task: {
        PermissionAction.read,
      },
      PermissionEntity.client: {
        PermissionAction.create,
        PermissionAction.read,
        PermissionAction.update,
        PermissionAction.delete,
        PermissionAction.duplicate,
      },
      PermissionEntity.company: {
        PermissionAction.create,
        PermissionAction.read,
        PermissionAction.update,
        PermissionAction.delete,
        PermissionAction.duplicate,
      },
      PermissionEntity.category: {
        PermissionAction.create,
        PermissionAction.read,
        PermissionAction.update,
        PermissionAction.delete,
        PermissionAction.duplicate,
      },
      PermissionEntity.product: {
        PermissionAction.create,
        PermissionAction.read,
        PermissionAction.update,
        PermissionAction.delete,
        PermissionAction.duplicate,
      },
      PermissionEntity.package_: {
        PermissionAction.create,
        PermissionAction.read,
        PermissionAction.update,
        PermissionAction.delete,
        PermissionAction.duplicate,
      },
      PermissionEntity.user: {
        PermissionAction.read,
      },
    },

    // CLIENTE: Acesso muito limitado
    UserRole.cliente: {
      PermissionEntity.project: {
        PermissionAction.read,
      },
      PermissionEntity.task: {
        PermissionAction.read,
      },
      PermissionEntity.client: {},
      PermissionEntity.company: {},
      PermissionEntity.category: {},
      PermissionEntity.product: {},
      PermissionEntity.package_: {},
      PermissionEntity.user: {
        PermissionAction.read,
      },
    },

    // USUARIO: Acesso básico
    UserRole.usuario: {
      PermissionEntity.project: {
        PermissionAction.read,
      },
      PermissionEntity.task: {
        PermissionAction.create,
        PermissionAction.read,
        PermissionAction.update,
        // delete e duplicate são controlados por ownership (ver canDeleteTask)
      },
      PermissionEntity.client: {
        PermissionAction.read,
      },
      PermissionEntity.company: {
        PermissionAction.read,
      },
      PermissionEntity.category: {
        PermissionAction.read,
      },
      PermissionEntity.product: {
        PermissionAction.read,
      },
      PermissionEntity.package_: {
        PermissionAction.read,
      },
      PermissionEntity.user: {
        PermissionAction.read,
      },
    },
  };

  /// Verifica se um role pode realizar uma ação em uma entidade
  bool canPerformAction(
    UserRole role,
    PermissionEntity entity,
    PermissionAction action,
  ) {
    final entityPermissions = _permissions[role]?[entity];
    if (entityPermissions == null) return false;
    return entityPermissions.contains(action);
  }

  /// Verifica se pode criar uma entidade
  bool canCreate(UserRole role, PermissionEntity entity) {
    return canPerformAction(role, entity, PermissionAction.create);
  }

  /// Verifica se pode ler uma entidade
  bool canRead(UserRole role, PermissionEntity entity) {
    return canPerformAction(role, entity, PermissionAction.read);
  }

  /// Verifica se pode atualizar uma entidade
  bool canUpdate(UserRole role, PermissionEntity entity) {
    return canPerformAction(role, entity, PermissionAction.update);
  }

  /// Verifica se pode excluir uma entidade
  bool canDelete(UserRole role, PermissionEntity entity) {
    return canPerformAction(role, entity, PermissionAction.delete);
  }

  /// Verifica se pode duplicar uma entidade
  bool canDuplicate(UserRole role, PermissionEntity entity) {
    return canPerformAction(role, entity, PermissionAction.duplicate);
  }

  /// Verifica se pode excluir uma task específica
  /// 
  /// Regras especiais para tasks:
  /// - Admin e Gestor podem excluir qualquer task
  /// - Outros usuários só podem excluir tasks que eles mesmos criaram
  bool canDeleteTask(UserRole role, String? taskCreatorId, String? currentUserId) {
    // Admin e Gestor podem excluir qualquer task
    if (role == UserRole.admin || role == UserRole.gestor) {
      return true;
    }

    // Outros usuários só podem excluir tasks que criaram
    if (taskCreatorId != null && currentUserId != null && taskCreatorId == currentUserId) {
      return true;
    }

    return false;
  }

  /// Verifica se pode editar uma task específica
  /// 
  /// Regras especiais para tasks:
  /// - Admin e Gestor podem editar qualquer task
  /// - Outros usuários só podem editar tasks que eles mesmos criaram
  bool canEditTask(UserRole role, String? taskCreatorId, String? currentUserId) {
    // Admin e Gestor podem editar qualquer task
    if (role == UserRole.admin || role == UserRole.gestor) {
      return true;
    }

    // Outros usuários só podem editar tasks que criaram
    if (taskCreatorId != null && currentUserId != null && taskCreatorId == currentUserId) {
      return true;
    }

    return false;
  }

  /// Verifica se pode duplicar uma task específica
  /// 
  /// Regras especiais para tasks:
  /// - Admin e Gestor podem duplicar qualquer task
  /// - Outros usuários só podem duplicar tasks que eles mesmos criaram
  bool canDuplicateTask(UserRole role, String? taskCreatorId, String? currentUserId) {
    // Admin e Gestor podem duplicar qualquer task
    if (role == UserRole.admin || role == UserRole.gestor) {
      return true;
    }

    // Outros usuários só podem duplicar tasks que criaram
    if (taskCreatorId != null && currentUserId != null && taskCreatorId == currentUserId) {
      return true;
    }

    return false;
  }
}

/// Instância singleton do serviço de permissões
final permissionsService = PermissionsService();

