import 'dart:io';
import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;
import '../../config/supabase_config.dart';
import '../../config/google_oauth_config.dart';
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
  Future<void> resetPasswordForEmail({
    required String email,
  }) async {
    await _client.auth.resetPasswordForEmail(
      email,
      redirectTo: 'io.supabase.flutter://reset-password',
    );
  }

  @override
  Future<void> updatePassword({
    required String newPassword,
  }) async {
    await _client.auth.updateUser(
      UserAttributes(password: newPassword),
    );
  }

  @override
  User? get currentUser => _client.auth.currentUser;

  @override
  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  @override
  Future<List<Map<String, dynamic>>> getUserByEmail(String email) async {
    final response = await _client
        .from('profiles')
        .select('id, email, full_name, avatar_url')
        .eq('email', email)
        .limit(1);

    return List<Map<String, dynamic>>.from(response as List);
  }

  @override
  Future<bool> signInWithGoogle() async {
    HttpServer? server;
    try {
      // Criar servidor HTTP local para capturar o callback
      // Tentar porta 3000, se falhar, usar porta 0 (aleatória)
      try {
        server = await HttpServer.bind('localhost', 3000);
      } catch (e) {
        server = await HttpServer.bind('localhost', 0);
      }

      final port = server.port;

      // Construir URL de autorização do Google usando a porta do servidor
      final redirectUri = 'http://localhost:$port/auth/callback';
      final authUrl = Uri.https('accounts.google.com', '/o/oauth2/v2/auth', {
        'client_id': GoogleOAuthConfig.clientId,
        'redirect_uri': redirectUri,
        'response_type': 'code',
        'scope': 'email profile',
        'access_type': 'offline',
      });

      await launchUrl(authUrl, mode: LaunchMode.externalApplication);

      // Aguardar callback do OAuth
      await for (final request in server) {
        final uri = request.uri;

        // Enviar resposta HTML para o navegador
        final html = '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <title>Login Successful</title>
  <style>
    body {
      font-family: Arial, sans-serif;
      display: flex;
      justify-content: center;
      align-items: center;
      height: 100vh;
      margin: 0;
      background: #1a1a1a;
      color: white;
    }
    .container {
      text-align: center;
    }
    h1 { color: #4CAF50; }
  </style>
</head>
<body>
  <div class="container">
    <h1>✓ Login realizado com sucesso!</h1>
    <p>Você pode fechar esta janela e voltar ao aplicativo.</p>
  </div>
  <script>
    setTimeout(() => window.close(), 2000);
  </script>
</body>
</html>
''';
        request.response
          ..statusCode = 200
          ..headers.set('Content-Type', 'text/html; charset=utf-8')
          ..write(html);
        await request.response.close();

        // Processar o código OAuth
        final code = uri.queryParameters['code'];
        final error = uri.queryParameters['error'];

        if (error != null) {
          return false;
        }

        if (code == null) {
          return false;
        }

        // Trocar código por access token do Google
        try {
          final tokenResponse = await http.post(
            Uri.parse('https://oauth2.googleapis.com/token'),
            headers: {'Content-Type': 'application/x-www-form-urlencoded'},
            body: {
              'code': code,
              'client_id': GoogleOAuthConfig.clientId,
              'client_secret': GoogleOAuthConfig.clientSecret,
              'redirect_uri': redirectUri,
              'grant_type': 'authorization_code',
            },
          );

          if (tokenResponse.statusCode != 200) {
            return false;
          }

          final tokenData = json.decode(tokenResponse.body);
          final idToken = tokenData['id_token'] as String?;

          if (idToken == null) {
            return false;
          }

          // Fazer login no Supabase com o ID token do Google
          await _client.auth.signInWithIdToken(
            provider: OAuthProvider.google,
            idToken: idToken,
          );

          return true;
        } catch (e) {
          return false;
        }
      }

      return false;
    } catch (e) {
      rethrow;
    } finally {
      await server?.close();
    }
  }

  /// Vincula conta Google a uma conta existente
  ///
  /// NOTA: Esta funcionalidade requer que "Manual Linking" esteja habilitado
  /// no Supabase Dashboard (Auth → Providers → Security Settings)
  @override
  Future<bool> linkGoogleAccount() async {
    HttpServer? server;
    try {
      // Forçar atualização do usuário antes de verificar
      await _client.auth.refreshSession();

      final currentUser = _client.auth.currentUser;
      if (currentUser == null) {
        throw Exception('Usuário não autenticado');
      }

      // Verificar se já tem conta Google vinculada
      if (hasGoogleAccount) {
        throw Exception('Conta Google já vinculada');
      }

      // Criar servidor HTTP local para capturar o callback
      // Tentar porta 3000, se falhar, usar porta 0 (aleatória)
      try {
        server = await HttpServer.bind('localhost', 3000);
      } catch (e) {
        try {
          server = await HttpServer.bind('localhost', 0);
        } catch (e2) {
          throw Exception('Não foi possível iniciar o servidor local.\n\n'
              'Tente fechar e reabrir o aplicativo.');
        }
      }

      final port = server.port;

      // Construir URL de autorização do Google usando a porta do servidor
      final redirectUri = 'http://localhost:$port/auth/callback';
      final authUrl = Uri.https('accounts.google.com', '/o/oauth2/v2/auth', {
        'client_id': GoogleOAuthConfig.clientId,
        'redirect_uri': redirectUri,
        'response_type': 'code',
        'scope': 'email profile',
        'access_type': 'offline',
      });

      await launchUrl(authUrl, mode: LaunchMode.externalApplication);

      // Aguardar callback
      await for (final request in server) {
        final uri = request.uri;

        // Enviar resposta HTML
        final html = '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <title>Conta Vinculada</title>
  <style>
    body {
      font-family: Arial, sans-serif;
      display: flex;
      justify-content: center;
      align-items: center;
      height: 100vh;
      margin: 0;
      background: #1a1a1a;
      color: white;
    }
    .container { text-align: center; }
    h1 { color: #4CAF50; }
  </style>
</head>
<body>
  <div class="container">
    <h1>✓ Conta Google vinculada com sucesso!</h1>
    <p>Você pode fechar esta janela e voltar ao aplicativo.</p>
  </div>
  <script>setTimeout(() => window.close(), 2000);</script>
</body>
</html>
''';
        request.response
          ..statusCode = 200
          ..headers.set('Content-Type', 'text/html; charset=utf-8')
          ..write(html);
        await request.response.close();

        final code = uri.queryParameters['code'];
        final error = uri.queryParameters['error'];

        if (error != null) {
          return false;
        }

        if (code == null) {
          return false;
        }

        // Trocar código por ID token
        try {
          final tokenResponse = await http.post(
            Uri.parse('https://oauth2.googleapis.com/token'),
            headers: {'Content-Type': 'application/x-www-form-urlencoded'},
            body: {
              'code': code,
              'client_id': GoogleOAuthConfig.clientId,
              'client_secret': GoogleOAuthConfig.clientSecret,
              'redirect_uri': redirectUri,
              'grant_type': 'authorization_code',
            },
          );

          if (tokenResponse.statusCode != 200) {
            return false;
          }

          final tokenData = json.decode(tokenResponse.body);
          final idToken = tokenData['id_token'] as String?;

          if (idToken == null) {
            return false;
          }

          // Salvar o ID do usuário atual antes de vincular
          final userIdBeforeLink = currentUser.id;

          // Vincular identidade Google ao usuário atual
          // NOTA: signInWithIdToken() automaticamente vincula se o usuário já estiver autenticado
          // e "Manual Linking" estiver habilitado no Supabase Dashboard
          try {
            await _client.auth.signInWithIdToken(
              provider: OAuthProvider.google,
              idToken: idToken,
            );

            // Forçar atualização do usuário para pegar o estado mais recente
            await _client.auth.refreshSession();
            final updatedUser = _client.auth.currentUser;

            // Verificar se a vinculação foi bem-sucedida
            // 1. O ID do usuário deve permanecer o mesmo
            // 2. A identidade Google deve ter sido adicionada
            if (updatedUser?.id != userIdBeforeLink) {
              throw Exception('Erro inesperado ao vincular conta Google');
            }

            // Verificar se a identidade Google foi realmente adicionada
            final hasGoogleIdentity = updatedUser?.identities?.any(
                  (identity) => identity.provider == 'google',
                ) ??
                false;

            if (hasGoogleIdentity) {
              return true;
            } else {
              throw Exception('Não foi possível vincular a conta Google.\n\n'
                  'Possíveis causas:\n'
                  '• Esta conta Google já está vinculada a outro usuário\n'
                  '• "Manual Linking" está desabilitado no Supabase Dashboard');
            }
          } on AuthApiException catch (e) {
            if (e.code == 'identity_already_exists') {
              throw Exception(
                  'Esta conta Google já está vinculada a outro usuário');
            } else if (e.message.contains('Manual linking is disabled')) {
              throw Exception(
                  'Vinculação manual está desabilitada no Supabase.\n\n'
                  'Habilite "Manual Linking" no Dashboard:\n'
                  'Auth → Providers → Security Settings');
            }
            throw Exception('Erro ao vincular conta Google: ${e.message}');
          }
        } catch (e) {
          return false;
        }
      }

      return false;
    } catch (e) {
      rethrow;
    } finally {
      await server?.close();
    }
  }

  /// Desvincula conta Google
  @override
  Future<bool> unlinkGoogleAccount() async {
    try {
      // Forçar atualização do usuário antes de desvincular
      await _client.auth.refreshSession();

      final user = _client.auth.currentUser;
      if (user == null) {
        throw Exception('Usuário não autenticado');
      }

      // Verificar se o usuário tem identidade Google
      final googleIdentity = user.identities?.firstWhere(
        (identity) => identity.provider == 'google',
        orElse: () => throw Exception('Conta Google não vinculada'),
      );

      if (googleIdentity == null) {
        throw Exception('Conta Google não vinculada');
      }

      // Desvincular identidade
      try {
        await _client.auth.unlinkIdentity(googleIdentity);

        // Forçar atualização do usuário para pegar o estado mais recente
        await _client.auth.refreshSession();
        final updatedUser = _client.auth.currentUser;

        // Verificar se a identidade Google foi realmente removida
        final stillHasGoogle = updatedUser?.identities?.any(
              (identity) => identity.provider == 'google',
            ) ??
            false;

        if (!stillHasGoogle) {
          return true;
        } else {
          throw Exception('Erro ao desvincular conta Google');
        }
      } on AuthException catch (e) {
        if (e.code == 'single_identity_not_deletable') {
          // O Supabase não permite desvincular se for a única identidade
          // Isso significa que o usuário precisa fazer login com senha primeiro
          // para criar uma sessão autenticada por senha
          // Sempre solicitar confirmação de senha, independente de ter identidade de email
          throw Exception('NEEDS_PASSWORD_CONFIRMATION');
        }
        rethrow;
      } catch (e) {
        rethrow;
      }
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<bool> confirmPasswordAndUnlink(String password) async {
    try {
      final email = _client.auth.currentUser?.email;
      if (email == null) {
        throw Exception('Email não encontrado');
      }

      // 1. Fazer login com a senha para confirmar e atualizar a sessão
      // Isso evita o erro "same_password" do updateUser e garante uma sessão autenticada por senha
      try {
        await _client.auth.signInWithPassword(
          email: email,
          password: password,
        );
      } on AuthException catch (e) {
        // Se der erro de credenciais inválidas, pode ser:
        // 1. Senha incorreta
        // 2. Usuário não tem senha definida (só tem Google)
        if (e.message.contains('Invalid login credentials') ||
            e.message.contains('Invalid') ||
            e.code == 'invalid_credentials') {
          // Verificar se o usuário tem identidade de email
          final user = _client.auth.currentUser;
          final hasEmailIdentity = user?.identities?.any(
                (identity) => identity.provider == 'email',
              ) ??
              false;

          if (!hasEmailIdentity) {
            // Usuário não tem senha definida
            throw Exception('NEEDS_PASSWORD_CREATION');
          } else {
            // Senha incorreta
            throw Exception('Senha incorreta');
          }
        }
        rethrow;
      }

      // 2. Tentar desvincular novamente agora que estamos logados via senha
      // Desta vez não deve dar erro de single_identity_not_deletable
      final user = _client.auth.currentUser;
      if (user == null) {
        throw Exception('Usuário não autenticado');
      }

      final googleIdentity = user.identities?.firstWhere(
        (identity) => identity.provider == 'google',
        orElse: () => throw Exception('Conta Google não vinculada'),
      );

      if (googleIdentity == null) {
        throw Exception('Conta Google não vinculada');
      }

      await _client.auth.unlinkIdentity(googleIdentity);

      // Forçar atualização do usuário
      await _client.auth.refreshSession();
      final updatedUser = _client.auth.currentUser;

      // Verificar se a identidade Google foi realmente removida
      final stillHasGoogle = updatedUser?.identities?.any(
            (identity) => identity.provider == 'google',
          ) ??
          false;

      if (!stillHasGoogle) {
        return true;
      } else {
        throw Exception('Erro ao desvincular conta Google');
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Verifica se o usuário tem conta Google vinculada
  @override
  bool get hasGoogleAccount {
    final user = _client.auth.currentUser;
    if (user == null) return false;

    return user.identities?.any(
          (identity) => identity.provider == 'google',
        ) ??
        false;
  }
}

/// Instância singleton do repositório de autenticação
/// Esta é a ÚNICA instância que deve ser usada em todo o aplicativo
final AuthContract authModule = AuthRepository();
