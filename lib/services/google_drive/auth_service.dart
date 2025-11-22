import 'package:googleapis/drive/v3.dart' as drive;
import 'package:googleapis_auth/auth_io.dart';
import 'package:http/http.dart' as http;
import '../../config/supabase_config.dart';
import '../../core/exceptions/app_exceptions.dart' as app_exceptions;
import '../../core/error_handler/error_handler.dart';

/// Serviço de autenticação OAuth do Google Drive
/// 
/// Responsável por:
/// - Gerenciar autenticação OAuth 2.0
/// - Armazenar e recuperar tokens de refresh
/// - Criar clientes autenticados
class GoogleDriveAuthService {
  static const _scopes = [drive.DriveApi.driveFileScope];

  /// Obter cliente autenticado do Google Drive
  /// 
  /// Retorna um cliente HTTP autenticado pronto para fazer chamadas à API do Google Drive.
  /// Se o usuário não tiver token armazenado, lança uma exceção.
  /// 
  /// Throws:
  /// - [app_exceptions.AuthException] se o usuário não estiver autenticado ou não tiver token
  ///
  /// Exemplo:
  /// ```dart
  /// final client = await authService.getAuthedClient();
  /// final driveApi = drive.DriveApi(client);
  /// ```
  Future<http.Client> getAuthedClient() async {
    try {
      final userId = SupabaseConfig.client.auth.currentUser?.id;
      if (userId == null) {
        throw app_exceptions.AuthException('Usuário não autenticado');
      }


      // Buscar token do banco de dados
      final response = await SupabaseConfig.client
          .from('google_drive_tokens')
          .select('refresh_token')
          .eq('user_id', userId)
          .maybeSingle();

      if (response == null) {
        throw app_exceptions.AuthException(
          'Token do Google Drive não encontrado. Por favor, conecte sua conta do Google Drive.',
        );
      }

      final refreshToken = response['refresh_token'] as String?;
      if (refreshToken == null || refreshToken.isEmpty) {
        throw app_exceptions.AuthException('Token de refresh inválido');
      }


      // Criar credenciais a partir do refresh token
      final credentials = AccessCredentials(
        AccessToken('Bearer', '', DateTime.now().toUtc()),
        refreshToken,
        _scopes,
      );

      // Criar cliente autenticado
      final client = await clientViaRefreshToken(
        credentials,
        http.Client(),
      );

      return client;
    } catch (e) {
      ErrorHandler.logError(
        e,
        context: 'GoogleDriveAuthService.getAuthedClient',
      );

      if (e is app_exceptions.AuthException) {
        rethrow;
      }

      throw app_exceptions.AuthException(
        'Erro ao obter cliente autenticado do Google Drive',
        originalError: e,
      );
    }
  }

  /// Criar cliente autenticado a partir de um refresh token
  ///
  /// Método auxiliar que cria um cliente HTTP autenticado usando um refresh token.
  ///
  /// Parâmetros:
  /// - [credentials]: Credenciais com refresh token
  /// - [baseClient]: Cliente HTTP base
  ///
  /// Retorna: Cliente HTTP autenticado
  Future<http.Client> clientViaRefreshToken(
    AccessCredentials credentials,
    http.Client baseClient,
  ) async {
    try {
      // Credenciais do Google OAuth
      // Para uso em produção, considere usar variáveis de ambiente
      final clientId = ClientId(
        '785385154853-mi7bsh7nbf5tgbufebv1k66qr67uph9u'
        '.apps.googleusercontent.com',
        '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',
      );

      // Atualizar credenciais (refresh)
      final newCredentials = await refreshCredentials(
        clientId,
        credentials,
        baseClient,
      );

      // Criar cliente autenticado com as novas credenciais
      final authedClient = autoRefreshingClient(
        clientId,
        newCredentials,
        baseClient,
      );

      return authedClient;
    } catch (e) {
      ErrorHandler.logError(
        e,
        context: 'GoogleDriveAuthService.clientViaRefreshToken',
      );

      throw app_exceptions.AuthException(
        'Erro ao criar cliente via refresh token',
        originalError: e,
      );
    }
  }

  /// Salvar refresh token no banco de dados
  ///
  /// Armazena o refresh token do usuário no Supabase para uso futuro.
  ///
  /// Parâmetros:
  /// - [userId]: ID do usuário
  /// - [refreshToken]: Token de refresh do Google OAuth
  ///
  /// Exemplo:
  /// ```dart
  /// await authService.saveRefreshToken(userId, refreshToken);
  /// ```
  Future<void> saveRefreshToken(String userId, String refreshToken) async {
    try {

      await SupabaseConfig.client.from('google_drive_tokens').upsert({
        'user_id': userId,
        'refresh_token': refreshToken,
        'updated_at': DateTime.now().toIso8601String(),
      });

    } catch (e) {
      ErrorHandler.logError(
        e,
        context: 'GoogleDriveAuthService.saveRefreshToken',
      );

      throw app_exceptions.DatabaseException(
        'Erro ao salvar refresh token',
        originalError: e,
      );
    }
  }

  /// Verificar se o usuário tem token armazenado
  /// 
  /// Retorna true se o usuário já conectou sua conta do Google Drive.
  /// 
  /// Exemplo:
  /// ```dart
  /// final hasToken = await authService.hasToken();
  /// if (!hasToken) {
  ///   // Mostrar botão "Conectar Google Drive"
  /// }
  /// ```
  Future<bool> hasToken() async {
    try {
      final userId = SupabaseConfig.client.auth.currentUser?.id;
      if (userId == null) return false;

      final response = await SupabaseConfig.client
          .from('google_drive_tokens')
          .select('refresh_token')
          .eq('user_id', userId)
          .maybeSingle();

      return response != null && response['refresh_token'] != null;
    } catch (e) {
      ErrorHandler.logError(
        e,
        context: 'GoogleDriveAuthService.hasToken',
      );
      return false;
    }
  }

  /// Remover token do usuário
  ///
  /// Remove o refresh token do banco de dados, desconectando a conta do Google Drive.
  ///
  /// Exemplo:
  /// ```dart
  /// await authService.removeToken();
  /// ```
  Future<void> removeToken() async {
    try {
      final userId = SupabaseConfig.client.auth.currentUser?.id;
      if (userId == null) return;


      await SupabaseConfig.client
          .from('google_drive_tokens')
          .delete()
          .eq('user_id', userId);

    } catch (e) {
      ErrorHandler.logError(
        e,
        context: 'GoogleDriveAuthService.removeToken',
      );

      throw app_exceptions.DatabaseException(
        'Erro ao remover token',
        originalError: e,
      );
    }
  }
}

