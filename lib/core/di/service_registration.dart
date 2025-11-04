import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/google_drive/google_drive_service.dart';
import '../../services/briefing_image_service.dart';
import '../../services/interfaces/interfaces.dart';
import '../../src/navigation/tab_manager.dart';
import '../../src/navigation/interfaces/tab_manager_interface.dart';
import '../../modules/audit/audit.dart';
import 'service_locator.dart';

/// Registra todos os services no Service Locator
///
/// Esta função deve ser chamada no início do aplicativo (main.dart)
/// antes de runApp().
///
/// ## Uso:
/// ```dart
/// void main() async {
///   WidgetsFlutterBinding.ensureInitialized();
///   await Supabase.initialize(...);
///   
///   // Registrar services
///   registerServices();
///   
///   runApp(MyApp());
/// }
/// ```
///
/// ## Services Registrados:
///
/// ### Singletons (mesma instância sempre):
/// - `IGoogleDriveService` → `GoogleDriveService`
/// - `IBriefingImageService` → `BriefingImageService`
/// - `ITabManager` → `TabManager`
/// - `FiscalBankAuditRepository` → Audit repository
///
/// ### Como usar os services:
/// ```dart
/// // Em qualquer lugar do código
/// final driveService = serviceLocator.get<IGoogleDriveService>();
/// final briefingService = serviceLocator.get<IBriefingImageService>();
/// final tabManager = serviceLocator.get<ITabManager>();
/// final auditRepo = serviceLocator.get<FiscalBankAuditRepository>();
/// ```
void registerServices() {
  // ========== GOOGLE DRIVE SERVICE ==========
  serviceLocator.register<IGoogleDriveService>(GoogleDriveService());

  // ========== BRIEFING IMAGE SERVICE ==========
  serviceLocator.register<IBriefingImageService>(BriefingImageService());

  // ========== TAB MANAGER ==========
  serviceLocator.register<ITabManager>(TabManager());

  // ========== AUDIT REPOSITORY ==========
  final supabaseClient = Supabase.instance.client;
  serviceLocator.register<FiscalBankAuditRepository>(
    FiscalBankAuditRepository(supabaseClient),
  );
}

/// Limpa todos os services registrados
///
/// Útil para testes ou para reinicializar o aplicativo.
///
/// ## Uso:
/// ```dart
/// void tearDown() {
///   unregisterServices();
/// }
/// ```
void unregisterServices() {
  serviceLocator.reset();
}

