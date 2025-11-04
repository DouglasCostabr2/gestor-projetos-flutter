import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:my_business/ui/organisms/dialogs/dialogs.dart';

/// Classe centralizada para tratamento de erros.
/// 
/// Fornece métodos para:
/// - Exibir mensagens de erro amigáveis ao usuário
/// - Logar erros para debug
/// - Categorizar erros por tipo
/// - Mostrar detalhes técnicos quando necessário
/// 
/// Exemplo de uso:
/// ```dart
/// try {
///   await projectsModule.deleteProject(id);
/// } catch (e) {
///   if (mounted) {
///     ErrorHandler.handle(context, e, customMessage: 'Erro ao excluir projeto');
///   }
/// }
/// ```
class ErrorHandler {
  /// Trata um erro e exibe mensagem apropriada ao usuário.
  /// 
  /// [context] - BuildContext para exibir SnackBar
  /// [error] - O erro capturado
  /// [customMessage] - Mensagem customizada (opcional)
  /// [showDetails] - Se deve mostrar botão de detalhes (padrão: true em debug)
  static void handle(
    BuildContext context,
    dynamic error, {
    String? customMessage,
    bool? showDetails,
  }) {
    final message = customMessage ?? _getErrorMessage(error);
    final shouldShowDetails = showDetails ?? kDebugMode;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(fontSize: 14),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.red.shade700,
        duration: const Duration(seconds: 5),
        action: shouldShowDetails
            ? SnackBarAction(
                label: 'Detalhes',
                textColor: Colors.white,
                onPressed: () => _showErrorDialog(context, error, message),
              )
            : null,
      ),
    );

    // Log para debug
    _logError(error, customMessage);
  }

  /// Trata um erro de forma silenciosa (apenas log, sem UI).
  static void handleSilent(dynamic error, {String? context}) {
    _logError(error, context);
  }

  /// Exibe mensagem de sucesso.
  static void showSuccess(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.green.shade700,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  /// Exibe mensagem de aviso.
  static void showWarning(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.warning_amber_outlined, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.orange.shade700,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  /// Exibe mensagem informativa.
  static void showInfo(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.info_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.blue.shade700,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  /// Converte erro em mensagem amigável ao usuário.
  static String _getErrorMessage(dynamic error) {
    // Erros do Supabase/PostgreSQL
    if (error is PostgrestException) {
      return _handlePostgrestException(error);
    }

    // Erros de autenticação
    if (error is AuthException) {
      return _handleAuthException(error);
    }

    // Erros de storage
    if (error is StorageException) {
      return 'Erro ao acessar arquivos: ${error.message}';
    }

    // Erros de rede
    final errorString = error.toString();
    if (errorString.contains('SocketException') ||
        errorString.contains('NetworkException')) {
      return 'Sem conexão com a internet. Verifique sua conexão.';
    }

    if (errorString.contains('TimeoutException')) {
      return 'Tempo de conexão esgotado. Tente novamente.';
    }

    if (errorString.contains('HandshakeException')) {
      return 'Erro de segurança na conexão. Verifique sua rede.';
    }

    // Erro genérico
    return 'Erro inesperado. Tente novamente.';
  }

  /// Trata erros específicos do Postgrest.
  static String _handlePostgrestException(PostgrestException error) {
    final code = error.code;
    final message = error.message.toLowerCase();

    // Violação de constraint única
    if (code == '23505' || message.contains('unique')) {
      if (message.contains('email')) {
        return 'Este email já está cadastrado.';
      }
      if (message.contains('full_name') || message.contains('profiles_full_name_unique')) {
        return 'Este nome já está em uso por outro usuário. Por favor, escolha um nome diferente.';
      }
      if (message.contains('name')) {
        return 'Este nome já está em uso.';
      }
      return 'Registro duplicado. Este item já existe.';
    }

    // Violação de chave estrangeira
    if (code == '23503' || message.contains('foreign key')) {
      return 'Não é possível excluir. Existem itens relacionados.';
    }

    // Violação de not null
    if (code == '23502' || message.contains('null value')) {
      return 'Campos obrigatórios não preenchidos.';
    }

    // Permissão negada
    if (code == '42501' || message.contains('permission denied')) {
      return 'Você não tem permissão para esta ação.';
    }

    // Erro genérico do banco
    return 'Erro no banco de dados: ${error.message}';
  }

  /// Trata erros específicos de autenticação.
  static String _handleAuthException(AuthException error) {
    final message = error.message.toLowerCase();

    if (message.contains('invalid login credentials')) {
      return 'Email ou senha incorretos.';
    }

    if (message.contains('email not confirmed')) {
      return 'Email não confirmado. Verifique sua caixa de entrada.';
    }

    if (message.contains('user already registered')) {
      return 'Este email já está cadastrado.';
    }

    if (message.contains('invalid email')) {
      return 'Email inválido.';
    }

    if (message.contains('password')) {
      return 'Senha inválida ou muito fraca.';
    }

    return 'Erro de autenticação: ${error.message}';
  }

  /// Loga erro para debug.
  static void _logError(dynamic error, String? context) {
    final timestamp = DateTime.now().toIso8601String();
    final contextStr = context != null ? '[$context] ' : '';

    if (kDebugMode) {
      debugPrint('');
      debugPrint('❌ ═══════════════════════════════════════════════════════');
      debugPrint('❌ ERROR: $timestamp');
      debugPrint('❌ Context: $contextStr');
      debugPrint('❌ Type: ${error.runtimeType}');
      debugPrint('❌ Message: $error');
      if (error is Error) {
        debugPrint('❌ Stack Trace:');
        debugPrint(error.stackTrace.toString());
      }
      debugPrint('❌ ═══════════════════════════════════════════════════════');
      debugPrint('');
    }

    // Future enhancement: Integrate error logging service (Sentry, Firebase Crashlytics, etc)
    // Example: Analytics.logError(error, stackTrace, context);
  }

  /// Exibe dialog com detalhes técnicos do erro.
  static void _showErrorDialog(
    BuildContext context,
    dynamic error,
    String userMessage,
  ) {
    DialogHelper.show(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.bug_report, color: Colors.red),
            SizedBox(width: 8),
            Text('Detalhes do Erro'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Mensagem ao Usuário:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(userMessage),
              const SizedBox(height: 16),
              const Text(
                'Tipo do Erro:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              SelectableText(error.runtimeType.toString()),
              const SizedBox(height: 16),
              const Text(
                'Detalhes Técnicos:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              SelectableText(
                error.toString(),
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              ),
              if (error is Error && error.stackTrace != null) ...[
                const SizedBox(height: 16),
                const Text(
                  'Stack Trace:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                SelectableText(
                  error.stackTrace.toString(),
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 10),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fechar'),
          ),
        ],
      ),
    );
  }
}

