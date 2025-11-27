import 'package:supabase_flutter/supabase_flutter.dart';

/// Contrato público do módulo de autenticação
/// Define as operações disponíveis para autenticação e gestão de sessão
///
/// IMPORTANTE: Este é o ÚNICO ponto de comunicação com o módulo de autenticação.
/// Nenhum código externo deve acessar a implementação interna diretamente.
abstract class AuthContract {
  /// Faz login com email e senha
  Future<AuthResponse> signInWithEmail({
    required String email,
    required String password,
  });

  /// Registra um novo usuário
  Future<AuthResponse> signUpWithEmail({
    required String email,
    required String password,
  });

  /// Faz logout
  Future<void> signOut();

  /// Solicita recuperação de senha por email
  Future<void> resetPasswordForEmail({
    required String email,
  });

  /// Atualiza a senha do usuário autenticado
  Future<void> updatePassword({
    required String newPassword,
  });

  /// Obtém o usuário atual
  User? get currentUser;

  /// Stream para monitorar mudanças de autenticação
  Stream<AuthState> get authStateChanges;

  /// Buscar usuário por email
  Future<List<Map<String, dynamic>>> getUserByEmail(String email);

  /// Faz login com Google OAuth
  Future<bool> signInWithGoogle();

  /// Vincula conta Google a uma conta existente
  Future<bool> linkGoogleAccount();

  /// Desvincula conta Google
  Future<bool> unlinkGoogleAccount();

  /// Verifica se o usuário tem conta Google vinculada
  bool get hasGoogleAccount;

  /// Confirma a senha e desvincula a conta Google
  /// Usado quando o sistema exige confirmação de senha para permitir a desvinculação
  Future<bool> confirmPasswordAndUnlink(String password);
}
