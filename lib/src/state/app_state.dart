import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthState;
import '../../modules/modules.dart';
import '../../modules/common/organization_context.dart';
import '../utils/permissions_helper.dart';
import '../../services/notification_realtime_service.dart';

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

  // Subscription para auth state changes (precisa ser cancelada no dispose)
  StreamSubscription<AuthState>? _authStateSubscription;

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
    _authStateSubscription?.cancel();
    _authStateSubscription = null;
    sideMenuCollapsedNotifier.dispose();
    super.dispose();
  }

  Future<void> initialize() async {
    // Usando o módulo de autenticação
    // IMPORTANTE: Armazenar a subscription para poder cancelá-la no dispose
    _authStateSubscription = authModule.authStateChanges.listen((event) async {
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

      // Cancelar subscription de notificações no logout
      notificationRealtimeService.dispose();

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

      // Inicializar subscription de notificações em tempo real após login
      try {
        await notificationRealtimeService.initialize();
      } catch (e) {
        // Ignorar erro (operação não crítica)
      }
    } catch (e) {
      role = 'convidado';
      currentOrganization = null;
      myOrganizations = [];
      currentOrgRole = null;
    }
    notifyListeners();
  }

  /// Atualizar lista de organizações e definir organização ativa
  Future<void> refreshOrganizations() async {
    try {
      // Buscar organizações do usuário
      myOrganizations = await organizationsModule.getMyOrganizations();

      // Se não há organização ativa, definir a primeira
      if (currentOrganization == null && myOrganizations.isNotEmpty) {
        await setCurrentOrganization(myOrganizations.first['id']);
      }
      // Se a organização ativa não está mais na lista, limpar
      else if (currentOrganization != null &&
               !myOrganizations.any((org) => org['id'] == currentOrganization!['id'])) {
        currentOrganization = null;
        currentOrgRole = null;
        if (myOrganizations.isNotEmpty) {
          await setCurrentOrganization(myOrganizations.first['id']);
        }
      }

      // Notificar listeners para atualizar UI
      notifyListeners();
    } catch (e) {
      myOrganizations = [];
      currentOrganization = null;
      currentOrgRole = null;
      notifyListeners();
    }
  }

  /// Definir organização ativa
  Future<void> setCurrentOrganization(String organizationId) async {
    try {
      // Buscar dados completos da organização
      final org = await organizationsModule.getOrganization(organizationId);
      if (org == null) {
        throw Exception('Organização não encontrada');
      }

      // Buscar role do usuário nesta organização
      final userRole = await organizationsModule.getUserRole(organizationId);

      currentOrganization = org;
      currentOrgRole = userRole;

      notifyListeners();
    } catch (e) {
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

