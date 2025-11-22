import 'package:flutter/material.dart';
import '../exceptions/app_exceptions.dart';
import 'package:my_business/ui/organisms/dialogs/dialogs.dart';

/// Handler centralizado de erros da aplicação
/// 
/// Responsável por:
/// - Converter erros genéricos em exceções tipadas
/// - Logar erros de forma consistente
/// - Fornecer mensagens amigáveis ao usuário
class ErrorHandler {
  /// Processar erro e retornar mensagem amigável
  static String getErrorMessage(dynamic error) {
    if (error is AppException) {
      return error.message;
    }

    if (error is AuthException) {
      return 'Erro de autenticação: ${error.message}';
    }

    if (error is NetworkException) {
      return 'Erro de conexão: ${error.message}';
    }

    if (error is ValidationException) {
      return 'Erro de validação: ${error.message}';
    }

    if (error is PermissionException) {
      return 'Sem permissão: ${error.message}';
    }

    if (error is NotFoundException) {
      return 'Não encontrado: ${error.message}';
    }

    if (error is StorageException) {
      return 'Erro de armazenamento: ${error.message}';
    }

    if (error is DriveException) {
      return 'Erro no Google Drive: ${error.message}';
    }

    if (error is DatabaseException) {
      return 'Erro no banco de dados: ${error.message}';
    }

    if (error is BusinessException) {
      return error.message;
    }

    if (error is TimeoutException) {
      return 'Tempo esgotado: ${error.message}';
    }

    if (error is ConflictException) {
      return 'Conflito: ${error.message}';
    }

    // Erro genérico
    return 'Erro inesperado: ${error.toString()}';
  }

  /// Logar erro de forma consistente
  static void logError(
    dynamic error, {
    StackTrace? stackTrace,
    String? context,
  }) {
    // Log silenciado
  }

  /// Mostrar erro em um SnackBar
  static void showErrorSnackBar(
    BuildContext context,
    dynamic error, {
    Duration duration = const Duration(seconds: 4),
  }) {
    final message = getErrorMessage(error);
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red[700],
        duration: duration,
        action: SnackBarAction(
          label: 'OK',
          textColor: Colors.white,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );
  }

  /// Mostrar erro em um Dialog
  static Future<void> showErrorDialog(
    BuildContext context,
    dynamic error, {
    String title = 'Erro',
  }) async {
    final message = getErrorMessage(error);

    return DialogHelper.show(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  /// Executar função com tratamento de erro
  static Future<T?> handleAsync<T>(
    Future<T> Function() function, {
    String? context,
    void Function(dynamic error)? onError,
  }) async {
    try {
      return await function();
    } catch (error) {
      logError(error, context: context);
      onError?.call(error);
      return null;
    }
  }

  /// Executar função síncrona com tratamento de erro
  static T? handleSync<T>(
    T Function() function, {
    String? context,
    void Function(dynamic error)? onError,
  }) {
    try {
      return function();
    } catch (error) {
      logError(error, context: context);
      onError?.call(error);
      return null;
    }
  }
}

