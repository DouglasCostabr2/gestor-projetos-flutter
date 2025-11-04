import 'package:flutter/material.dart';

/// Serviço para tratamento de erros relacionados ao timer
/// 
/// Fornece feedback visual ao usuário quando operações do timer falham
class TimerErrorHandler {
  /// Mostra uma mensagem de erro ao usuário
  static void showError(BuildContext context, String message, {String? details}) {
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(
              Icons.error_outline,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (details != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      details,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
        backgroundColor: Colors.red[700],
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  /// Mostra uma mensagem de sucesso ao usuário
  static void showSuccess(BuildContext context, String message) {
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(
              Icons.check_circle_outline,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 12),
            Text(
              message,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        backgroundColor: Colors.green[700],
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  /// Mostra uma mensagem de aviso ao usuário
  static void showWarning(BuildContext context, String message) {
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(
              Icons.warning_amber_rounded,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 12),
            Text(
              message,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        backgroundColor: Colors.orange[700],
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  /// Mensagens de erro padrão
  static const String errorStartTimer = 'Erro ao iniciar timer';
  static const String errorStopTimer = 'Erro ao parar timer';
  static const String errorPauseTimer = 'Erro ao pausar timer';
  static const String errorResumeTimer = 'Erro ao retomar timer';
  static const String errorLoadHistory = 'Erro ao carregar histórico';
  static const String errorUpdateDescription = 'Erro ao atualizar descrição';
  static const String errorDeleteEntry = 'Erro ao excluir registro';

  /// Mensagens de sucesso padrão
  static const String successTimerStarted = 'Timer iniciado';
  static const String successTimerStopped = 'Timer parado e salvo';
  static const String successTimerPaused = 'Timer pausado';
  static const String successTimerResumed = 'Timer retomado';
  static const String successDescriptionUpdated = 'Descrição atualizada';
  static const String successEntryDeleted = 'Registro excluído';
}

