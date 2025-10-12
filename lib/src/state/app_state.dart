import 'package:flutter/foundation.dart';
import '../../modules/modules.dart';

/// Centraliza estado da sessão, perfil/role e preferências de UI
///
/// OTIMIZAÇÃO: Usa ValueNotifier separados para evitar rebuilds desnecessários
class AppState extends ChangeNotifier {
  bool initialized = false;
  Map<String, dynamic>? profile;
  String role = 'convidado'; // admin | gestor | designer | financeiro | cliente | convidado

  // Preferências de UI com ValueNotifier separado para evitar rebuilds desnecessários
  final ValueNotifier<bool> sideMenuCollapsedNotifier = ValueNotifier<bool>(false);

  bool get sideMenuCollapsed => sideMenuCollapsedNotifier.value;

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
      notifyListeners();
      return;
    }

    try {
      // Usando o módulo de usuários
      final data = await usersModule.getCurrentProfile();

      profile = data;
      final rRaw = (data?['role'] as String?)?.toLowerCase();
      // Migração suave: mapear 'funcionario' -> 'designer'
      final mapped = (rRaw == 'funcionario') ? 'designer' : rRaw;
      if (mapped == 'admin' || mapped == 'gestor' || mapped == 'designer' || mapped == 'financeiro' || mapped == 'cliente' || mapped == 'convidado') {
        role = mapped!;
      } else {
        role = 'convidado'; // fallback menos privilegiado
      }
    } catch (_) {
      role = 'convidado';
    }
    notifyListeners();
  }

  bool get isAdmin => role == 'admin';
  bool get isGestor => role == 'gestor';
  bool get isAdminOrGestor => isAdmin || isGestor;
  bool get isDesigner => role == 'designer' || isAdminOrGestor; // designer (antigo funcionario)
  bool get isFinanceiro => role == 'financeiro' || isAdminOrGestor;
  bool get isCliente => role == 'cliente';
  bool get isConvidado => role == 'convidado';
}

