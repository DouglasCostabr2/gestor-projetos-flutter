// New Flutter desktop app entrypoint with Supabase initialization and routing
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'config/supabase_config.dart';
import 'src/app_shell.dart';
import 'src/navigation/route_observer.dart';

import 'src/features/auth/login_page.dart';
import 'src/state/app_state.dart';
import 'src/state/app_state_scope.dart';
import 'src/theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SupabaseConfig.initialize();
  runApp(const MyApp());
}


class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final AppState _appState = AppState();

  @override
  void initState() {
    super.initState();
    _appState.initialize();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _appState,
      builder: (context, _) {
        return AppStateScope(
          appState: _appState,
          child: MaterialApp(
            title: 'Gestor de Projetos',
            theme: AppTheme.light(),
            darkTheme: AppTheme.dark(),
            themeMode: ThemeMode.dark,
            navigatorObservers: [routeObserver],
            debugShowCheckedModeBanner: false,
            home: _buildHome(),
          ),
        );
      },
    );
  }

  Widget _buildHome() {
    if (!_appState.initialized) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) {
      return LoginPage(onLoggedIn: _appState.refreshProfile);
    }
    return AppShell(appState: _appState);
  }
}

