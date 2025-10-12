import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Configuração do Supabase para o projeto
class SupabaseConfig {
  // Credenciais do Supabase já configuradas
  static const String supabaseUrl = 'https://zfgsddweabsemxcchxjq.supabase.co';
  static const String supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InpmZ3NkZHdlYWJzZW14Y2NoeGpxIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTUxMDQyMjIsImV4cCI6MjA3MDY4MDIyMn0.cKWKEyIwYhInUVxbsYgp-9I08XZs_IpkvFRMHDcHJzo';

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
    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      debugPrint('🔐 Auth State Changed: ${data.event}');
      debugPrint('👤 User: ${data.session?.user.email ?? "null"}');
      debugPrint('🆔 User ID: ${data.session?.user.id ?? "null"}');
    });
  }

  /// Getter para acessar o cliente Supabase
  static SupabaseClient get client => Supabase.instance.client;
}
