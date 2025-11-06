import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
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
      debugPrint('Iniciando login com Google...');

      // Criar servidor HTTP local para capturar o callback
      // Tentar porta 3000, se falhar, usar porta 0 (aleatória)
      try {
        server = await HttpServer.bind('localhost', 3000);
        debugPrint('✅ Servidor local iniciado na porta 3000');
      } catch (e) {
        debugPrint('⚠️ Porta 3000 em uso, tentando porta aleatória...');
        server = await HttpServer.bind('localhost', 0);
        debugPrint('✅ Servidor local iniciado na porta ${server.port}');
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

      debugPrint('🌐 Abrindo navegador para OAuth...');
      debugPrint('📍 Redirect URI: $redirectUri');
      await launchUrl(authUrl, mode: LaunchMode.externalApplication);

      // Aguardar callback do OAuth
      debugPrint('Aguardando callback do OAuth...');
      await for (final request in server) {
        final uri = request.uri;
        debugPrint('Callback recebido: ${uri.path}');

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
          debugPrint('Erro do OAuth: $error');
          return false;
        }

        if (code == null) {
          debugPrint('Código OAuth não encontrado no callback');
          return false;
        }

        debugPrint('Código OAuth recebido');

        // Trocar código por access token do Google
        try {
          debugPrint('Trocando código por access token...');
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
            debugPrint('Erro ao trocar código: ${tokenResponse.statusCode}');
            return false;
          }

          final tokenData = json.decode(tokenResponse.body);
          final idToken = tokenData['id_token'] as String?;

          if (idToken == null) {
            debugPrint('ID token não encontrado na resposta');
            return false;
          }

          debugPrint('ID token recebido, fazendo login no Supabase...');

          // Fazer login no Supabase com o ID token do Google
          await _client.auth.signInWithIdToken(
            provider: OAuthProvider.google,
            idToken: idToken,
          );

          debugPrint('Login no Supabase realizado com sucesso!');
          return true;
        } catch (e, stackTrace) {
          debugPrint('Erro ao processar OAuth: $e');
          debugPrint('StackTrace: $stackTrace');
          return false;
        }
      }

      return false;
    } catch (e, stackTrace) {
      debugPrint('Erro no signInWithGoogle: $e');
      debugPrint('StackTrace: $stackTrace');
      rethrow;
    } finally {
      await server?.close();
      debugPrint('Servidor local encerrado');
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
      debugPrint('Vinculando conta Google...');

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
        debugPrint('✅ Servidor local iniciado na porta 3000');
      } catch (e) {
        debugPrint('⚠️ Porta 3000 em uso, tentando porta aleatória...');
        try {
          server = await HttpServer.bind('localhost', 0);
          debugPrint('✅ Servidor local iniciado na porta ${server.port}');
        } catch (e2) {
          debugPrint('❌ Erro ao criar servidor: $e2');
          throw Exception(
            'Não foi possível iniciar o servidor local.\n\n'
            'Tente fechar e reabrir o aplicativo.'
          );
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

      debugPrint('🌐 Abrindo navegador para vinculação...');
      debugPrint('📍 Redirect URI: $redirectUri');
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
          debugPrint('Erro do OAuth: $error');
          return false;
        }

        if (code == null) {
          debugPrint('Código OAuth não encontrado');
          return false;
        }

        debugPrint('Código OAuth recebido para vinculação');

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
            debugPrint('Erro ao trocar código: ${tokenResponse.statusCode}');
            return false;
          }

          final tokenData = json.decode(tokenResponse.body);
          final idToken = tokenData['id_token'] as String?;

          if (idToken == null) {
            debugPrint('ID token não encontrado');
            return false;
          }

          debugPrint('ID token recebido, vinculando ao usuário atual...');

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
              debugPrint('Erro: Usuário diferente após vinculação');
              throw Exception('Erro inesperado ao vincular conta Google');
            }

            // Verificar se a identidade Google foi realmente adicionada
            final hasGoogleIdentity = updatedUser?.identities?.any(
              (identity) => identity.provider == 'google',
            ) ?? false;

            if (hasGoogleIdentity) {
              debugPrint('Conta Google vinculada com sucesso!');
              return true;
            } else {
              debugPrint('Erro: Identidade Google não foi adicionada');
              throw Exception(
                'Não foi possível vincular a conta Google.\n\n'
                'Possíveis causas:\n'
                '• Esta conta Google já está vinculada a outro usuário\n'
                '• "Manual Linking" está desabilitado no Supabase Dashboard'
              );
            }
          } on AuthApiException catch (e) {
            debugPrint('❌ Erro ao vincular: ${e.code} - ${e.message}');

            if (e.code == 'identity_already_exists') {
              throw Exception('Esta conta Google já está vinculada a outro usuário');
            } else if (e.message.contains('Manual linking is disabled')) {
              throw Exception(
                'Vinculação manual está desabilitada no Supabase.\n\n'
                'Habilite "Manual Linking" no Dashboard:\n'
                'Auth → Providers → Security Settings'
              );
            }
            throw Exception('Erro ao vincular conta Google: ${e.message}');
          }
        } catch (e) {
          debugPrint('Erro ao vincular conta: $e');
          return false;
        }
      }

      return false;
    } catch (e) {
      debugPrint('Erro ao vincular conta Google: $e');
      rethrow;
    } finally {
      await server?.close();
      debugPrint('Servidor local encerrado');
    }
  }

  /// Desvincula conta Google
  @override
  Future<bool> unlinkGoogleAccount() async {
    try {
      debugPrint('Desvinculando conta Google...');

      // Forçar atualização do usuário antes de desvincular
      await _client.auth.refreshSession();

      final user = _client.auth.currentUser;
      if (user == null) {
        throw Exception('Usuário não autenticado');
      }

      // Verificar quantas identidades o usuário tem
      final identitiesCount = user.identities?.length ?? 0;

      if (identitiesCount <= 1) {
        throw Exception(
          'única forma de login'  // Palavra-chave para o dialog
        );
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
        ) ?? false;

        if (!stillHasGoogle) {
          debugPrint('Conta Google desvinculada com sucesso!');
          return true;
        } else {
          debugPrint('Erro: Identidade Google ainda está presente');
          throw Exception('Erro ao desvincular conta Google');
        }
      } on AuthApiException catch (e) {
        if (e.code == 'single_identity_not_deletable') {
          throw Exception(
            'Você precisa definir uma senha antes de desvincular sua conta Google.\n\n'
            'Vá até a seção "Alterar Senha" acima e defina uma senha para sua conta.'
          );
        }
        rethrow;
      }
    } catch (e) {
      debugPrint('Erro ao desvincular conta Google: $e');
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
    ) ?? false;
  }
}

/// Instância singleton do repositório de autenticação
/// Esta é a ÚNICA instância que deve ser usada em todo o aplicativo
final AuthContract authModule = AuthRepository();

