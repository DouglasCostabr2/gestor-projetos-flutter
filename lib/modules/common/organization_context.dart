import '../../src/state/app_state.dart';

/// Helper para obter o organization_id do contexto atual
/// 
/// IMPORTANTE: Este helper deve ser usado apenas em repositories
/// para filtrar dados por organização.
class OrganizationContext {
  static AppState? _appState;

  /// Inicializar o contexto com o AppState
  static void initialize(AppState appState) {
    _appState = appState;
  }

  /// Obter o organization_id da organização ativa
  /// 
  /// Retorna null se:
  /// - AppState não foi inicializado
  /// - Não há organização ativa
  /// 
  /// IMPORTANTE: Repositories devem lidar com null adequadamente
  static String? get currentOrganizationId {
    return _appState?.currentOrganizationId;
  }

  /// Verificar se há uma organização ativa
  static bool get hasActiveOrganization {
    return currentOrganizationId != null;
  }

  /// Obter a organização ativa completa
  static Map<String, dynamic>? get currentOrganization {
    return _appState?.currentOrganization;
  }
}

