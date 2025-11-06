// New Flutter desktop app entrypoint with Supabase initialization and routing
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show debugPrintThrottled, kDebugMode;
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:window_manager/window_manager.dart';
import 'package:world_countries/world_countries.dart';
import 'config/supabase_config.dart';
import 'core/di/service_registration.dart';
import 'src/app_shell.dart';
import 'src/navigation/route_observer.dart';
import 'services/task_timer_service.dart';
import 'services/notification_realtime_service.dart';

import 'src/features/auth/login_page.dart';
import 'src/features/auth/reset_password_page.dart';
import 'src/state/app_state.dart';
import 'src/state/app_state_scope.dart';
import 'src/theme/app_theme.dart';
import 'src/features/tasks/widgets/timer_close_confirmation_dialog.dart';
import 'services/update_service.dart';
import 'widgets/update_dialog.dart';

// Global navigator key para acessar o contexto de qualquer lugar
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// Limitador de logs para erros de Tooltip/Ticker (evita spam no console)
DateTime? _lastTooltipTickerErrorPrintedAt;

Future<void> main() async {
  // Silencia logs de debug globais; habilite definindo kVerboseLogs = true
  bool kVerboseLogs = false;
  debugPrint = (String? message, {int? wrapWidth}) {
    // ignore: dead_code
    if (kDebugMode && kVerboseLogs) {
      debugPrintThrottled(message, wrapWidth: wrapWidth);
    }
  };

  WidgetsFlutterBinding.ensureInitialized();

  // Inicializar window_manager
  await windowManager.ensureInitialized();

  // Configurar para prevenir fechamento automático
  WindowOptions windowOptions = const WindowOptions(
    skipTaskbar: false,
  );
  windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.setPreventClose(true);
    await windowManager.show();
    await windowManager.focus();
  });

  // Inicializar Supabase
  await SupabaseConfig.initialize();

  // Registrar services no Service Locator (Dependency Injection)
  registerServices();

  // Inicializar TaskTimerService para restaurar estado do timer
  await taskTimerService.initialize();

  // Capturar exceções e reduzir spam específico de Tooltip/Ticker
  FlutterError.onError = (FlutterErrorDetails details) {
    final msg = details.exception.toString();
    if (msg.contains('TooltipState') || msg.contains('tickers were created')) {
      final now = DateTime.now();
      final shouldLog = _lastTooltipTickerErrorPrintedAt == null ||
          now.difference(_lastTooltipTickerErrorPrintedAt!).inSeconds >= 5;
      if (shouldLog) {
        _lastTooltipTickerErrorPrintedAt = now;
        debugPrint('\n🔎 Capturado erro relacionado a Tooltip/Ticker (mostrando detalhes, limitado)');
        // Mostra os detalhes completos apenas de tempos em tempos
        FlutterError.presentError(details);
      }
      // Suprime repetições para evitar travamentos/lag por excesso de logs
      return;
    }
    // Outros erros são apresentados normalmente
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
      debugPrint('❌ Erro ao verificar atualizações: $e');
    }
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }

  @override
  Future<void> onWindowClose() async {
    // TIMEOUT GLOBAL: Garantir que o app SEMPRE feche em no máximo 5 segundos
    // Isso evita travamentos causados por operações assíncronas que não completam
    Future.delayed(const Duration(seconds: 5), () {
      windowManager.destroy();
    });

    try {
      // Verificar se há timer ativo
      if (taskTimerService.isRunning || taskTimerService.activeTimeLogId != null) {
        final shouldClose = await TimerCloseConfirmationDialog.show(navigatorKey.currentContext!).timeout(
          const Duration(seconds: 2),
          onTimeout: () => true, // Se o diálogo travar, fecha mesmo assim
        );

        if (shouldClose != true) {
          // Usuário cancelou o fechamento - não fazer nada
          return;
        }

        // Usuário confirmou - parar e salvar o timer antes de fechar
        try {
          if (taskTimerService.isRunning || taskTimerService.activeTimeLogId != null) {
            // Adicionar timeout de 2 segundos para evitar travamento
            // skipNotify=true para não tentar atualizar widgets durante fechamento
            await taskTimerService.stop(skipNotify: true).timeout(
              const Duration(seconds: 2),
              onTimeout: () {
                return;
              },
            );
          }
        } catch (e) {
          // Continua fechando mesmo com erro
        }
      }

      // Sempre limpar todos os recursos antes de fechar
      // (seja com timer ativo ou não)
      await _cleanupBeforeClose();
    } catch (e) {
      // Qualquer erro: continua fechando
    }

    // Fechar a janela
    await windowManager.destroy();
  }

  /// Limpa todos os recursos antes de fechar o app
  /// Isso garante que todas as subscriptions sejam canceladas e o app feche rapidamente
  Future<void> _cleanupBeforeClose() async {
    try {
      // Executar todas as operações de limpeza com timeout de 2 segundos
      await Future.wait([
        // Limpar configuração do Supabase (cancela auth state listener global)
        SupabaseConfig.dispose().timeout(const Duration(seconds: 1), onTimeout: () {}),

        // Executar operações síncronas em um Future
        Future(() {
          taskTimerService.dispose();
          notificationRealtimeService.disposeAll();
          _appState.dispose();
          SupabaseConfig.client.removeAllChannels();
        }).timeout(const Duration(seconds: 1), onTimeout: () {}),
      ], eagerError: false).timeout(
        const Duration(seconds: 2),
        onTimeout: () => [],
      );
    } catch (e) {
      // Continua fechando mesmo com erro
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _appState,
      builder: (context, _) {
        return AppStateScope(
          appState: _appState,
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

