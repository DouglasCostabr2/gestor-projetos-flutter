import 'package:flutter/foundation.dart';
import '../../modules/modules.dart';
import '../../modules/common/organization_context.dart';
import '../utils/permissions_helper.dart';

/// Centraliza estado da sessão, perfil/role, organização ativa e preferências de UI
///
/// OTIMIZAÇÃO: Usa ValueNotifier separados para evitar rebuilds desnecessários
class AppState extends ChangeNotifier {
  bool initialized = false;
  Map<String, dynamic>? profile;
  String role = 'convidado'; // admin | gestor | designer | financeiro | cliente | convidado

  // Multi-tenancy: Organização ativa e lista de organizações do usuário
  Map<String, dynamic>? currentOrganization;
  List<Map<String, dynamic>> myOrganizations = [];
  String? currentOrgRole; // Role do usuário na organização ativa

  // Preferências de UI com ValueNotifier separado para evitar rebuilds desnecessários
  final ValueNotifier<bool> sideMenuCollapsedNotifier = ValueNotifier<bool>(false);

  bool get sideMenuCollapsed => sideMenuCollapsedNotifier.value;

  // Construtor: inicializar OrganizationContext
  AppState() {
    OrganizationContext.initialize(this);
  }

  void setSideMenuCollapsed(bool v) {
    if (sideMenuCollapsedNotifier.value != v) {
      sideMenuCollapsedNotifier.value = v;
      // NÃO chama notifyListeners() aqui - só o ValueNotifier notifica
    }
  }

  void toggleSideMenu() {
    sideMenuCollapsedNotifier.value = !sideMenuCollapsedNotifier.value;
    // NÃO chama notifyListeners() aqui - só o ValueNotifier notifica
  }

  @override
  void dispose() {
    sideMenuCollapsedNotifier.dispose();
    super.dispose();
  }

  Future<void> initialize() async {
    // Usando o módulo de autenticação
    authModule.authStateChanges.listen((event) async {
      await refreshProfile();
    });
    await refreshProfile();
    initialized = true;
    notifyListeners();
  }

  Future<void> refreshProfile() async {
    // Usando o módulo de autenticação
    final user = authModule.currentUser;
    if (user == null) {
      profile = null;
      role = 'convidado';
      currentOrganization = null;
      myOrganizations = [];
      currentOrgRole = null;
      notifyListeners();
      return;
    }

    try {
      // Usando o módulo de usuários
      final data = await usersModule.getCurrentProfile();

      profile = data;
      final rRaw = (data?['role'] as String?)?.toLowerCase();
      if (rRaw == 'admin' || rRaw == 'gestor' || rRaw == 'designer' || rRaw == 'financeiro' || rRaw == 'cliente' || rRaw == 'usuario' || rRaw == 'convidado') {
        role = rRaw!;
      } else {
        role = 'usuario'; // fallback para usuário comum
      }

      // Carregar organizações do usuário
      await refreshOrganizations();
    } catch (_) {
      role = 'convidado';
      currentOrganization = null;
      myOrganizations = [];
      currentOrgRole = null;
    }
    notifyListeners();
  }

  /// Atualizar lista de organizações e definir organização ativa
  Future<void> refreshOrganizations() async {
    debugPrint('🔄 [AppState] Iniciando refreshOrganizations...');
    try {
      // Buscar organizações do usuário
      myOrganizations = await organizationsModule.getMyOrganizations();
      debugPrint('📋 [AppState] Organizações carregadas: ${myOrganizations.length}');

      if (myOrganizations.isNotEmpty) {
        debugPrint('📋 [AppState] Organizações: ${myOrganizations.map((o) => o['name']).join(', ')}');
      }

      // Se não há organização ativa, definir a primeira
      if (currentOrganization == null && myOrganizations.isNotEmpty) {
        debugPrint('🎯 [AppState] Definindo primeira organização como ativa...');
        await setCurrentOrganization(myOrganizations.first['id']);
      }
      // Se a organização ativa não está mais na lista, limpar
      else if (currentOrganization != null &&
               !myOrganizations.any((org) => org['id'] == currentOrganization!['id'])) {
        debugPrint('⚠️ [AppState] Organização ativa não está mais na lista, limpando...');
        currentOrganization = null;
        currentOrgRole = null;
        if (myOrganizations.isNotEmpty) {
          await setCurrentOrganization(myOrganizations.first['id']);
        }
      } else if (currentOrganization != null) {
        debugPrint('✅ [AppState] Organização ativa: ${currentOrganization!['name']} (role: $currentOrgRole)');
      }

      // Notificar listeners para atualizar UI
      notifyListeners();
      debugPrint('🔔 [AppState] Listeners notificados após refreshOrganizations');
    } catch (e, stackTrace) {
      debugPrint('❌ [AppState] Erro ao atualizar organizações: $e');
      debugPrint('Stack trace: $stackTrace');
      myOrganizations = [];
      currentOrganization = null;
      currentOrgRole = null;
      notifyListeners();
    }
  }

  /// Definir organização ativa
  Future<void> setCurrentOrganization(String organizationId) async {
    debugPrint('🎯 [AppState] setCurrentOrganization: $organizationId');
    try {
      // Buscar dados completos da organização
      debugPrint('🔍 [AppState] Buscando dados da organização...');
      final org = await organizationsModule.getOrganization(organizationId);
      if (org == null) {
        debugPrint('❌ [AppState] Organização não encontrada!');
        throw Exception('Organização não encontrada');
      }
      debugPrint('✅ [AppState] Organização encontrada: ${org['name']}');

      // Buscar role do usuário nesta organização
      debugPrint('🔍 [AppState] Buscando role do usuário...');
      final userRole = await organizationsModule.getUserRole(organizationId);
      debugPrint('✅ [AppState] Role do usuário: $userRole');

      currentOrganization = org;
      currentOrgRole = userRole;

      debugPrint('✅ [AppState] Organização ativa alterada para: ${org['name']} (role: $userRole)');

      notifyListeners();
    } catch (e) {
      debugPrint('Erro ao definir organização ativa: $e');
      rethrow;
    }
  }

  // Getters para role global (mantidos para compatibilidade)
  bool get isAdmin => role == 'admin';
  bool get isGestor => role == 'gestor';
  bool get isAdminOrGestor => isAdmin || isGestor;
  bool get isDesigner => role == 'designer' || isAdminOrGestor; // designer (antigo funcionario)
  bool get isFinanceiro => role == 'financeiro' || isAdminOrGestor;
  bool get isCliente => role == 'cliente';
  bool get isConvidado => role == 'convidado';

  // Getters para role na organização ativa (multi-tenancy)
  bool get isOrgOwner => currentOrgRole == 'owner';
  bool get isOrgAdmin => currentOrgRole == 'admin';
  bool get isOrgGestor => currentOrgRole == 'gestor';
  bool get isOrgFinanceiro => currentOrgRole == 'financeiro';
  bool get isOrgDesigner => currentOrgRole == 'designer';
  bool get isOrgUsuario => currentOrgRole == 'usuario';

  bool get isOrgOwnerOrAdmin => isOrgOwner || isOrgAdmin;
  bool get canManageOrganization => isOrgOwner || isOrgAdmin;
  bool get canManageMembers => isOrgOwner || isOrgAdmin;

  // Getter para ID da organização ativa
  String? get currentOrganizationId => currentOrganization?['id'];

  // Getter para helper de permissões
  PermissionsHelper get permissions => PermissionsHelper(this);
}

