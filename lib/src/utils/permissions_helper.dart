import '../state/app_state.dart';

/// Helper para verificar permissões contextuais baseadas no role do usuário na organização ativa
/// 
/// Hierarquia de roles (do mais alto para o mais baixo):
/// 1. owner - Proprietário (todas as permissões)
/// 2. admin - Administrador (quase todas as permissões)
/// 3. gestor - Gestor (gerenciar projetos, tarefas, clientes)
/// 4. financeiro - Financeiro (gerenciar pagamentos, faturas)
/// 5. designer - Designer (gerenciar tarefas, produtos)
/// 6. usuario - Usuário (visualizar e criar tarefas)
class PermissionsHelper {
  final AppState appState;

  PermissionsHelper(this.appState);

  /// Role do usuário na organização ativa
  String? get currentRole => appState.currentOrgRole;

  /// Verifica se o usuário tem um role específico ou superior
  bool hasRole(String role) {
    if (currentRole == null) return false;
    
    final roleHierarchy = {
      'owner': 6,
      'admin': 5,
      'gestor': 4,
      'financeiro': 3,
      'designer': 2,
      'usuario': 1,
    };

    final currentLevel = roleHierarchy[currentRole] ?? 0;
    final requiredLevel = roleHierarchy[role] ?? 0;

    return currentLevel >= requiredLevel;
  }

  /// Verifica se o usuário tem um dos roles especificados
  bool hasAnyRole(List<String> roles) {
    if (currentRole == null) return false;
    return roles.contains(currentRole);
  }

  // ==================== ORGANIZAÇÕES ====================

  /// Pode gerenciar configurações da organização
  bool get canManageOrganization => hasAnyRole(['owner', 'admin']);

  /// Pode gerenciar membros da organização
  bool get canManageMembers => hasAnyRole(['owner', 'admin']);

  /// Pode enviar convites
  bool get canSendInvites => hasAnyRole(['owner', 'admin']);

  // ==================== CLIENTES ====================

  /// Pode visualizar clientes
  bool get canViewClients => hasRole('usuario');

  /// Pode criar clientes
  bool get canCreateClients => hasRole('gestor');

  /// Pode editar clientes
  bool get canEditClients => hasRole('gestor');

  /// Pode deletar clientes
  bool get canDeleteClients => hasRole('admin');

  // ==================== PROJETOS ====================

  /// Pode visualizar projetos
  bool get canViewProjects => hasRole('usuario');

  /// Pode criar projetos
  bool get canCreateProjects => hasRole('gestor');

  /// Pode editar projetos
  bool get canEditProjects => hasRole('gestor');

  /// Pode deletar projetos
  bool get canDeleteProjects => hasRole('admin');

  // ==================== TAREFAS ====================

  /// Pode visualizar tarefas
  bool get canViewTasks => hasRole('usuario');

  /// Pode criar tarefas
  bool get canCreateTasks => hasRole('usuario');

  /// Pode editar tarefas
  bool get canEditTasks => hasRole('usuario');

  /// Pode deletar tarefas
  bool get canDeleteTasks => hasRole('gestor');

  /// Pode atribuir tarefas a outros usuários
  bool get canAssignTasks => hasRole('gestor');

  /// Verifica se pode editar uma task específica
  /// Admin e Gestor podem editar qualquer task
  /// Outros usuários só podem editar tasks que criaram
  bool canEditTask(String? taskCreatorId, String? currentUserId) {
    if (hasRole('gestor')) return true;
    if (taskCreatorId != null && currentUserId != null && taskCreatorId == currentUserId) {
      return true;
    }
    return false;
  }

  /// Verifica se pode excluir uma task específica
  /// Admin e Gestor podem excluir qualquer task
  /// Outros usuários só podem excluir tasks que criaram
  bool canDeleteTask(String? taskCreatorId, String? currentUserId) {
    if (hasRole('gestor')) return true;
    if (taskCreatorId != null && currentUserId != null && taskCreatorId == currentUserId) {
      return true;
    }
    return false;
  }

  // ==================== PRODUTOS ====================

  /// Pode visualizar produtos
  bool get canViewProducts => hasRole('usuario');

  /// Pode criar produtos
  bool get canCreateProducts => hasRole('designer');

  /// Pode editar produtos
  bool get canEditProducts => hasRole('designer');

  /// Pode deletar produtos
  bool get canDeleteProducts => hasRole('gestor');

  // ==================== PACOTES ====================

  /// Pode visualizar pacotes
  bool get canViewPackages => hasRole('usuario');

  /// Pode criar pacotes
  bool get canCreatePackages => hasRole('designer');

  /// Pode editar pacotes
  bool get canEditPackages => hasRole('designer');

  /// Pode deletar pacotes
  bool get canDeletePackages => hasRole('gestor');

  // ==================== CATEGORIAS ====================

  /// Pode visualizar categorias
  bool get canViewCategories => hasRole('usuario');

  /// Pode criar categorias
  bool get canCreateCategories => hasRole('gestor');

  /// Pode editar categorias
  bool get canEditCategories => hasRole('gestor');

  /// Pode deletar categorias
  bool get canDeleteCategories => hasRole('admin');

  // ==================== EMPRESAS ====================

  /// Pode visualizar empresas
  bool get canViewCompanies => hasRole('usuario');

  /// Pode criar empresas
  bool get canCreateCompanies => hasRole('admin');

  /// Pode editar empresas
  bool get canEditCompanies => hasRole('admin');

  /// Pode deletar empresas
  bool get canDeleteCompanies => hasRole('owner');

  // ==================== PAGAMENTOS ====================

  /// Pode visualizar pagamentos
  bool get canViewPayments => hasRole('financeiro');

  /// Pode criar pagamentos
  bool get canCreatePayments => hasRole('financeiro');

  /// Pode editar pagamentos
  bool get canEditPayments => hasRole('financeiro');

  /// Pode deletar pagamentos
  bool get canDeletePayments => hasRole('admin');

  /// Pode aprovar pagamentos
  bool get canApprovePayments => hasRole('admin');

  // ==================== FATURAS ====================

  /// Pode visualizar faturas
  bool get canViewInvoices => hasRole('financeiro');

  /// Pode criar faturas
  bool get canCreateInvoices => hasRole('financeiro');

  /// Pode editar faturas
  bool get canEditInvoices => hasRole('financeiro');

  /// Pode deletar faturas
  bool get canDeleteInvoices => hasRole('admin');

  /// Pode enviar faturas
  bool get canSendInvoices => hasRole('financeiro');

  // ==================== CONFIGURAÇÕES ====================

  /// Pode acessar configurações
  bool get canAccessSettings => hasRole('usuario');

  /// Pode alterar configurações gerais
  bool get canEditSettings => hasRole('admin');

  /// Pode alterar configurações fiscais
  bool get canEditFiscalSettings => hasRole('admin');

  // ==================== RELATÓRIOS ====================

  /// Pode visualizar relatórios básicos
  bool get canViewBasicReports => hasRole('usuario');

  /// Pode visualizar relatórios financeiros
  bool get canViewFinancialReports => hasRole('financeiro');

  /// Pode visualizar todos os relatórios
  bool get canViewAllReports => hasRole('admin');

  /// Pode exportar relatórios
  bool get canExportReports => hasRole('gestor');

  // ==================== HELPERS ====================

  /// Retorna mensagem de erro de permissão
  String getPermissionDeniedMessage(String action) {
    return 'Você não tem permissão para $action. Role necessário: ${_getRequiredRoleForAction(action)}';
  }

  String _getRequiredRoleForAction(String action) {
    // Mapeamento de ações para roles necessários
    final actionRoleMap = {
      'criar clientes': 'Gestor',
      'editar clientes': 'Gestor',
      'deletar clientes': 'Administrador',
      'criar projetos': 'Gestor',
      'editar projetos': 'Gestor',
      'deletar projetos': 'Administrador',
      'criar tarefas': 'Usuário',
      'editar tarefas': 'Usuário',
      'deletar tarefas': 'Gestor',
      'criar produtos': 'Designer',
      'editar produtos': 'Designer',
      'deletar produtos': 'Gestor',
      'gerenciar organização': 'Administrador',
      'gerenciar membros': 'Administrador',
      'gerenciar pagamentos': 'Financeiro',
    };

    return actionRoleMap[action] ?? 'Administrador';
  }

  /// Retorna badge de role formatado
  String getRoleBadge() {
    switch (currentRole) {
      case 'owner':
        return 'Proprietário';
      case 'admin':
        return 'Administrador';
      case 'gestor':
        return 'Gestor';
      case 'financeiro':
        return 'Financeiro';
      case 'designer':
        return 'Designer';
      case 'usuario':
        return 'Usuário';
      default:
        return 'Sem role';
    }
  }
}

