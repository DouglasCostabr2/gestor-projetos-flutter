// New Flutter desktop app entrypoint with Supabase initialization and routing
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:window_manager/window_manager.dart';
import 'package:world_countries/world_countries.dart';
import 'package:flutter_mentions/flutter_mentions.dart';
import 'config/supabase_config.dart';
import 'core/di/service_registration.dart';
import 'src/app_shell.dart';
import 'src/navigation/route_observer.dart';
import 'services/task_timer_service.dart';

import 'src/features/auth/login_page.dart';
import 'src/features/auth/reset_password_page.dart';
import 'src/state/app_state.dart';
import 'src/state/app_state_scope.dart';
import 'src/theme/app_theme.dart';
import 'services/update_service.dart';
import 'widgets/update_dialog.dart';

// Global navigator key para acessar o contexto de qualquer lugar
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializar window_manager
  await windowManager.ensureInitialized();

  // Configurar janela - SEM setPreventClose para permitir fechamento imediato
  WindowOptions windowOptions = const WindowOptions(
    skipTaskbar: false,
  );
  windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
  });

  // Inicializar Supabase
  await SupabaseConfig.initialize();

  // Registrar services no Service Locator (Dependency Injection)
  registerServices();

  // Inicializar TaskTimerService para restaurar estado do timer
  await taskTimerService.initialize();

  // Capturar exceções
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
  };

  runApp(const MyApp());
}


class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WindowListener {
  final AppState _appState = AppState();

  @override
  void initState() {
    super.initState();
    _appState.initialize();
    windowManager.addListener(this);
    _checkForUpdates();
  }

  /// Verifica se há atualizações disponíveis
  Future<void> _checkForUpdates() async {
    // Aguardar um pouco para garantir que a UI está pronta
    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;

    try {
      final updateService = UpdateService();
      final update = await updateService.checkForUpdates();

      if (update != null && mounted) {
        // Mostrar diálogo de atualização
        await UpdateDialog.show(
          navigatorKey.currentContext ?? context,
          update,
          updateService,
        );
      }
    } catch (e) {
      // Erro ao verificar atualizações
    }
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _appState,
      builder: (context, _) {
        return AppStateScope(
          appState: _appState,
          child: Portal(
            child: MaterialApp(
              navigatorKey: navigatorKey,
              title: 'My Business',
              theme: AppTheme.light(),
              darkTheme: AppTheme.dark(),
              themeMode: ThemeMode.dark,
              navigatorObservers: [routeObserver],
              debugShowCheckedModeBanner: false,
              // Localização para português brasileiro
              localizationsDelegates: const [
                GlobalMaterialLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                TypedLocaleDelegate(), // Para traduções do world_countries
              ],
              supportedLocales: const [
                Locale('pt', 'BR'), // Português do Brasil
                Locale('en', 'US'), // Inglês (fallback)
              ],
              locale: const Locale('pt', 'BR'),
              home: _buildHome(),
              routes: {
                '/reset-password': (context) => const ResetPasswordPage(),
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildHome() {
    if (!_appState.initialized) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo do app
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  image: const DecorationImage(
                    image: AssetImage('assets/images/app_logo.png'),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(height: 32),
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              const Text('Carregando...'),
            ],
          ),
        ),
      );
    }

    // Usar o estado do AppState em vez de verificar a sessão do Supabase diretamente
    // Isso garante que a navegação seja sincronizada com o estado da aplicação
    final user = _appState.profile;
    if (user == null) {
      return LoginPage(onLoggedIn: _appState.refreshProfile);
    }
    return AppShell(appState: _appState);
  }
}

