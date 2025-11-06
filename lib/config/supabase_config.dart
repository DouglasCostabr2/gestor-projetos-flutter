import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:app_links/app_links.dart';

/// Configuração do Supabase para o projeto
class SupabaseConfig {
  // Credenciais do Supabase já configuradas
  static const String supabaseUrl = 'https://zfgsddweabsemxcchxjq.supabase.co';
  static const String supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InpmZ3NkZHdlYWJzZW14Y2NoeGpxIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTUxMDQyMjIsImV4cCI6MjA3MDY4MDIyMn0.cKWKEyIwYhInUVxbsYgp-9I08XZs_IpkvFRMHDcHJzo';

  // Subscription para auth state changes (precisa ser cancelada no shutdown)
  static StreamSubscription<AuthState>? _authStateSubscription;
  static StreamSubscription<Uri>? _deepLinkSubscription;

  /// Inicializa o cliente Supabase
  static Future<void> initialize() async {
    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
      authOptions: const FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce,
        autoRefreshToken: true,  // Auto-refresh token quando expirar
      ),
    );

    // Debug: Log auth state changes
    // IMPORTANTE: Armazenar a subscription para poder cancelá-la no shutdown
    _authStateSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      debugPrint('🔐 Auth State Changed: ${data.event}');
      debugPrint('👤 User: ${data.session?.user.email ?? "null"}');
      debugPrint('🆔 User ID: ${data.session?.user.id ?? "null"}');
    });

    // Listener para deep links (OAuth callback)
    final appLinks = AppLinks();
    _deepLinkSubscription = appLinks.uriLinkStream.listen((uri) {
      debugPrint('🔗 Deep Link recebido: $uri');
      // O Supabase Flutter já processa automaticamente os deep links
      // Mas vamos logar para debug
    });
  }

  /// Limpa recursos do Supabase (deve ser chamado no shutdown do app)
  static Future<void> dispose() async {
    debugPrint('🧹 [SupabaseConfig] Limpando recursos...');
    await _authStateSubscription?.cancel();
    _authStateSubscription = null;
    await _deepLinkSubscription?.cancel();
    _deepLinkSubscription = null;
    debugPrint('✅ [SupabaseConfig] Recursos limpos');
  }

  /// Getter para acessar o cliente Supabase
  static SupabaseClient get client => Supabase.instance.client;
}
