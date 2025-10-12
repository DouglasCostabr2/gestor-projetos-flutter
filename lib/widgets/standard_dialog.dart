import 'package:flutter/material.dart';
import 'package:gestor_projetos_flutter/widgets/buttons/buttons.dart';

/// Widget padrão para diálogos no sistema
///
/// Fornece um layout consistente com:
/// - Header com título e botão de fechar
/// - Área de conteúdo scrollável
/// - Rodapé fixo com botões de ação (opcional)
/// - Overlay de loading (opcional)
class StandardDialog extends StatelessWidget {
  // Tamanhos padrão para formulários
  static const double widthSmall = 500;
  static const double heightSmall = 500;

  static const double widthMedium = 600;
  static const double heightMedium = 700;

  static const double widthLarge = 800;
  static const double heightLarge = 850;

  /// Título do diálogo
  final String title;

  /// Conteúdo principal do diálogo
  final Widget child;

  /// Botões de ação no rodapé (opcional)
  /// Se null, não mostra o rodapé
  final List<Widget>? actions;

  /// Largura fixa do diálogo
  final double width;

  /// Altura fixa do diálogo
  final double height;

  /// Se true, mostra um botão X no header para fechar
  final bool showCloseButton;

  /// Padding interno do conteúdo
  final EdgeInsets contentPadding;

  /// Se true, mostra overlay de loading sobre o diálogo
  final bool isLoading;

  /// Mensagem a exibir durante o loading
  final String loadingMessage;

  const StandardDialog({
    super.key,
    required this.title,
    required this.child,
    this.actions,
    this.width = widthMedium,
    this.height = heightMedium,
    this.showCloseButton = true,
    this.contentPadding = const EdgeInsets.all(24),
    this.isLoading = false,
    this.loadingMessage = 'Salvando...',
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHigh,
      child: SizedBox(
        width: width,
        height: height,
        child: Stack(
          children: [
            Column(
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: Theme.of(context).colorScheme.outlineVariant,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                      if (showCloseButton)
                        IconOnlyButton(
                          icon: Icons.close,
                          onPressed: () => Navigator.of(context).pop(),
                          tooltip: 'Fechar',
                        ),
                    ],
                  ),
                ),

                // Content
                Expanded(
                  child: SingleChildScrollView(
                    padding: contentPadding,
                    child: child,
                  ),
                ),

                // Actions (rodapé fixo)
                if (actions != null && actions!.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(
                          color: Theme.of(context).colorScheme.outlineVariant,
                        ),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        for (int i = 0; i < actions!.length; i++) ...[
                          actions![i],
                          if (i < actions!.length - 1) const SizedBox(width: 8),
                        ],
                      ],
                    ),
                  ),
              ],
            ),

            // Loading overlay
            if (isLoading)
              Positioned.fill(
                child: AbsorbPointer(
                  child: Container(
                    color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.8),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const CircularProgressIndicator(),
                          const SizedBox(height: 12),
                          Text(
                            loadingMessage,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Widget padrão para diálogos de confirmação
/// 
/// Fornece um layout simples para confirmações com:
/// - Título
/// - Mensagem
/// - Botões Cancelar e Confirmar
class ConfirmDialog extends StatelessWidget {
  /// Título do diálogo
  final String title;
  
  /// Mensagem de confirmação
  final String message;
  
  /// Texto do botão de confirmação
  final String confirmText;
  
  /// Texto do botão de cancelamento
  final String cancelText;
  
  /// Se true, o botão de confirmação usa cor de erro
  final bool isDestructive;

  const ConfirmDialog({
    super.key,
    required this.title,
    required this.message,
    this.confirmText = 'Confirmar',
    this.cancelText = 'Cancelar',
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(cancelText),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: isDestructive
              ? FilledButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.error,
                )
              : null,
          child: Text(confirmText),
        ),
      ],
    );
  }
}

