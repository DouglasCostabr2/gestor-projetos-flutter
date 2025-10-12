import 'package:supabase_flutter/supabase_flutter.dart';
import '../../config/supabase_config.dart';
import 'contract.dart';

/// Implementação do contrato de autenticação
/// 
/// IMPORTANTE: Esta classe é INTERNA ao módulo.
/// O mundo externo deve usar apenas o contrato AuthContract.
class AuthRepository implements AuthContract {
  final SupabaseClient _client = SupabaseConfig.client;

  @override
  Future<AuthResponse> signInWithEmail({
    required String email,
    required String password,
  }) async {
    return await _client.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  @override
  Future<AuthResponse> signUpWithEmail({
    required String email,
    required String password,
  }) async {
    return await _client.auth.signUp(
      email: email,
      password: password,
    );
  }

  @override
  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  @override
  User? get currentUser => _client.auth.currentUser;

  @override
  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;
}

/// Instância singleton do repositório de autenticação
/// Esta é a ÚNICA instância que deve ser usada em todo o aplicativo
final AuthContract authModule = AuthRepository();

