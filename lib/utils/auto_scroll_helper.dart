import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// Helper utilitário para auto-scroll de widgets.
///
/// Fornece funcionalidade robusta de auto-scroll que aguarda o render completo
/// de widgets antes de fazer scroll, garantindo que o widget alvo fique
/// completamente visível na tela com margem adequada.
///
/// **Casos de uso:**
/// - Campos de texto que expandem ao digitar
/// - Campos com imagens inseridas dinamicamente
/// - Emoji pickers, dropdowns e outros overlays
/// - Qualquer widget que precise ficar visível após mudanças de layout
///
/// **Exemplos de uso:**
///
/// ```dart
/// // Para campo de texto simples (scroll rápido)
/// AutoScrollHelper.scrollToWidget(
///   key: _myFieldKey,
///   framesToWait: 1,
///   extraMargin: 80.0,
/// );
///
/// // Para campo com imagem (aguardar render completo)
/// AutoScrollHelper.scrollToWidget(
///   key: _myFieldKey,
///   framesToWait: 6,
///   delayMs: 150,
///   extraMargin: 200.0,
///   alwaysScroll: true,
///   debugLabel: 'Campo com Imagem',
/// );
///
/// // Para emoji picker ou dropdown (scroll garantido)
/// AutoScrollHelper.scrollToWidget(
///   key: _myPickerKey,
///   framesToWait: 3,
///   delayMs: 100,
///   extraMargin: 80.0,
///   alwaysScroll: true,
///   debugLabel: 'Emoji Picker',
/// );
/// ```
class AutoScrollHelper {
  /// Faz scroll para tornar um widget completamente visível na tela.
  ///
  /// **Parâmetros:**
  ///
  /// - `key`: GlobalKey do widget alvo que deve ficar visível
  ///
  /// - `framesToWait`: Número de frames para aguardar antes de fazer scroll.
  ///   - 1 frame: Para texto simples (padrão)
  ///   - 3 frames: Para pickers, dropdowns, overlays
  ///   - 6 frames: Para imagens grandes ou widgets complexos
  ///
  /// - `delayMs`: Delay adicional em milissegundos após aguardar os frames.
  ///   Útil para garantir que o layout esteja completamente estabilizado.
  ///   - 0ms: Para texto simples (padrão)
  ///   - 100ms: Para pickers e overlays
  ///   - 150ms: Para imagens grandes
  ///
  /// - `extraMargin`: Margem extra em pixels abaixo do widget após o scroll.
  ///   Garante que o widget não fique colado na borda inferior da tela.
  ///   - 80px: Para texto e pickers (padrão)
  ///   - 150-200px: Para campos com imagens
  ///
  /// - `durationMs`: Duração da animação de scroll em milissegundos.
  ///   Padrão: 400ms (animação suave)
  ///
  /// - `curve`: Curva de animação do scroll.
  ///   Padrão: Curves.easeOutCubic (suave e natural)
  ///
  /// - `alwaysScroll`: Se true, sempre faz scroll mesmo que o widget já esteja
  ///   parcialmente visível. Se false, só faz scroll se o widget estiver cortado.
  ///   Padrão: false
  ///
  /// - `enableDebugLogs`: Se true, imprime logs detalhados no console para debug.
  ///   Padrão: false
  ///
  /// - `debugLabel`: Label opcional para identificar o widget nos logs de debug.
  ///   Só é usado se `enableDebugLogs` for true.
  ///
  /// - `alignToBottom`: Se true, alinha o scroll para mostrar a parte inferior do widget.
  ///   Se false, alinha para mostrar a parte superior. Padrão: false
  static void scrollToWidget({
    required GlobalKey key,
    int framesToWait = 1,
    int delayMs = 0,
    double extraMargin = 80.0,
    int durationMs = 400,
    Curve curve = Curves.easeOutCubic,
    bool alwaysScroll = false,
    bool enableDebugLogs = false,
    String? debugLabel,
    bool alignToBottom = false,
  }) {
    // Validação de parâmetros
    assert(framesToWait >= 0, 'framesToWait deve ser >= 0');
    assert(delayMs >= 0, 'delayMs deve ser >= 0');
    assert(extraMargin >= 0, 'extraMargin deve ser >= 0');
    assert(durationMs > 0, 'durationMs deve ser > 0');

    // Aguardar múltiplos frames para garantir render completo
    void scheduleScroll(int framesRemaining) {
      if (framesRemaining <= 0) {
        // Se há delay adicional, aguardar antes de fazer scroll
        if (delayMs > 0) {
          Future.delayed(Duration(milliseconds: delayMs), () {
            _performScroll(
              key: key,
              extraMargin: extraMargin,
              durationMs: durationMs,
              curve: curve,
              alwaysScroll: alwaysScroll,
              enableDebugLogs: enableDebugLogs,
              debugLabel: debugLabel,
              alignToBottom: alignToBottom,
            );
          });
        } else {
          _performScroll(
            key: key,
            extraMargin: extraMargin,
            durationMs: durationMs,
            curve: curve,
            alwaysScroll: alwaysScroll,
            enableDebugLogs: enableDebugLogs,
            debugLabel: debugLabel,
            alignToBottom: alignToBottom,
          );
        }
      } else {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          scheduleScroll(framesRemaining - 1);
        });
      }
    }

    scheduleScroll(framesToWait);
  }

  /// Executa o scroll propriamente dito.
  ///
  /// Este método é chamado internamente por `scrollToWidget` após aguardar
  /// os frames e delay necessários.
  static void _performScroll({
    required GlobalKey key,
    required double extraMargin,
    required int durationMs,
    required Curve curve,
    required bool alwaysScroll,
    required bool enableDebugLogs,
    String? debugLabel,
    required bool alignToBottom,
  }) {

    // Obter o contexto do widget alvo
    final context = key.currentContext;
    if (context == null) {
      if (enableDebugLogs) {
      }
      return;
    }

    // Obter o RenderBox do widget alvo
    final RenderBox? renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) {
      if (enableDebugLogs) {
      }
      return;
    }

    // Obter o Scrollable mais próximo
    final scrollable = Scrollable.maybeOf(context);
    if (scrollable == null) {
      if (enableDebugLogs) {
      }
      return;
    }

    // Calcular a altura do widget alvo
    final widgetHeight = renderBox.size.height;

    // Obter o RenderBox do container scrollable
    final RenderBox? scrollableBox = scrollable.context.findRenderObject() as RenderBox?;
    if (scrollableBox == null) {
      if (enableDebugLogs) {
      }
      return;
    }

    // Calcular a posição do widget alvo relativa ao scrollable
    final widgetPosition = renderBox.localToGlobal(Offset.zero, ancestor: scrollableBox);
    final scrollableHeight = scrollableBox.size.height;

    // Calcular o scroll necessário
    final currentScroll = scrollable.position.pixels;
    final widgetBottom = widgetPosition.dy + widgetHeight;
    final visibleBottom = scrollableHeight;

    // Logs de debug
    if (enableDebugLogs) {
    }

    // Calcular o scroll necessário
    final double scrollNeeded;

    if (alignToBottom) {
      // Alinhar ao final: SEMPRE garantir que o widget inteiro fique visível
      // Estratégia: posicionar o widget de forma que seu bottom fique a extraMargin pixels do bottom da tela
      // Isso garante que os botões sempre fiquem completamente visíveis

      // Posição ideal do bottom do widget (com margem)
      final idealWidgetBottom = visibleBottom - extraMargin;

      // Quanto precisa scrollar para chegar nessa posição
      scrollNeeded = widgetBottom - idealWidgetBottom;

      if (enableDebugLogs) {
      }
    } else {
      // Alinhar ao topo: só faz scroll se necessário
      scrollNeeded = widgetBottom - visibleBottom + extraMargin;
    }

    // Decidir se deve fazer scroll
    final shouldScroll = alignToBottom || alwaysScroll || widgetBottom > visibleBottom;

    if (shouldScroll) {
      final targetScroll = currentScroll + scrollNeeded;

      if (enableDebugLogs) {
      }

      // Fazer scroll com animação
      scrollable.position.animateTo(
        targetScroll.clamp(
          scrollable.position.minScrollExtent,
          scrollable.position.maxScrollExtent,
        ),
        duration: Duration(milliseconds: durationMs),
        curve: curve,
      );
    } else {
      if (enableDebugLogs) {
      }
    }
  }

  /// Configurações pré-definidas para casos de uso comuns.
  ///
  /// Facilita o uso do helper sem precisar especificar todos os parâmetros.

  /// Scroll para campo de texto simples (rápido, sem delay)
  static void scrollToTextField({
    required GlobalKey key,
    bool enableDebugLogs = false,
  }) {
    scrollToWidget(
      key: key,
      framesToWait: 1,
      delayMs: 0,
      extraMargin: 80.0,
      alwaysScroll: false,
      enableDebugLogs: enableDebugLogs,
      debugLabel: 'Campo de Texto',
      alignToBottom: false,
    );
  }

  /// Scroll para campo com imagem (aguarda render completo, margem maior, alinha ao final)
  static void scrollToImageField({
    required GlobalKey key,
    bool enableDebugLogs = false,
  }) {
    scrollToWidget(
      key: key,
      framesToWait: 6,
      delayMs: 150,
      extraMargin: 80.0,
      alwaysScroll: true,
      enableDebugLogs: enableDebugLogs,
      debugLabel: 'Campo com Imagem',
      alignToBottom: true,
    );
  }

  /// Scroll para picker/dropdown/overlay (aguarda render, scroll garantido)
  static void scrollToPicker({
    required GlobalKey key,
    bool enableDebugLogs = false,
  }) {
    scrollToWidget(
      key: key,
      framesToWait: 3,
      delayMs: 100,
      extraMargin: 80.0,
      alwaysScroll: true,
      enableDebugLogs: enableDebugLogs,
      debugLabel: 'Picker/Overlay',
      alignToBottom: true,
    );
  }

  /// Scroll para o final da página (maxScrollExtent) relativo ao Scrollable do widget da key.
  static void scrollToBottom({
    required GlobalKey key,
    int framesToWait = 1,
    int delayMs = 0,
    int durationMs = 400,
    Curve curve = Curves.easeOutCubic,
    bool enableDebugLogs = false,
  }) {
    void scheduleScroll(int framesRemaining) {
      if (framesRemaining <= 0) {
        if (delayMs > 0) {
          Future.delayed(Duration(milliseconds: delayMs), () {
            _performScrollToEnd(
              key: key,
              durationMs: durationMs,
              curve: curve,
              enableDebugLogs: enableDebugLogs,
            );
          });
        } else {
          _performScrollToEnd(
            key: key,
            durationMs: durationMs,
            curve: curve,
            enableDebugLogs: enableDebugLogs,
          );
        }
      } else {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          scheduleScroll(framesRemaining - 1);
        });
      }
    }

    scheduleScroll(framesToWait);
  }

  static void _performScrollToEnd({
    required GlobalKey key,
    required int durationMs,
    required Curve curve,
    required bool enableDebugLogs,
  }) {
    final context = key.currentContext;
    if (context == null) {
      return;
    }

    // Preferir o PrimaryScrollController (scroll principal da página)
    final primaryController = PrimaryScrollController.maybeOf(context);
    // Fallback: scrollable mais próximo
    final scrollable = Scrollable.maybeOf(context);

    ScrollPosition? position;
    if (primaryController != null && primaryController.hasClients) {
      position = primaryController.position;
    } else if (scrollable != null) {
      position = scrollable.position;
    }

    if (position == null) {
      return;
    }

    final target = position.maxScrollExtent;


    if (enableDebugLogs) {
      if ((position.pixels - target).abs() < 0.5) {
      } else {
      }
    }

    // 1º passe
    if ((position.pixels - target).abs() >= 0.5) {
      position.animateTo(
        target,
        duration: Duration(milliseconds: durationMs),
        curve: curve,
      );
    }

    // 2º passe (garantia) após o layout estabilizar mais um pouco
    Future.delayed(const Duration(milliseconds: 120), () {
      try {
        final secondTarget = position!.maxScrollExtent;
        if ((position.pixels - secondTarget).abs() >= 0.5) {
          position.animateTo(
            secondTarget,
            duration: Duration(milliseconds: (durationMs * 0.75).round()),
            curve: curve,
          );
        }
      } catch (_) {}
    });
  }

  /// Versão simples: um único post-frame + um único movimento para o final.
  /// Evita múltiplos passes e reduz flicker. Usa jumpTo para deltas pequenos.
  static void scrollToBottomSimple({
    required GlobalKey key,
    ScrollController? preferredController,
    int durationMs = 180,
    bool enableDebugLogs = false,
  }) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final context = key.currentContext;
      if (context == null) return;

      final primary = PrimaryScrollController.maybeOf(context);
      final scrollable = Scrollable.maybeOf(context);

      ScrollPosition? position;
      if (preferredController != null && preferredController.hasClients) {
        position = preferredController.position;
      } else if (primary != null && primary.hasClients) {
        position = primary.position;
      } else if (scrollable != null) {
        position = scrollable.position;
      } else {
        return;
      }

      final target = position.maxScrollExtent;
      final delta = (target - position.pixels).abs();
      if (enableDebugLogs) {
      }

      if (delta < 1.0) return; // já está no final
      if (delta < 24.0) {
        // Pequeno ajuste: pular sem animação evita “sobe e desce” perceptível
        position.jumpTo(target);
      } else {
        position.animateTo(
          target,
          duration: Duration(milliseconds: durationMs),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  /// Garante que a key esteja visível no viewport de um ScrollPosition fornecido
  static void ensureVisibleOnPosition({
    required GlobalKey key,
    required ScrollPosition position,
    double extraBottomMargin = 96.0,
    int durationMs = 180,
    bool enableDebugLogs = false,
    bool allowScrollUpIfNeeded = false,
  }) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final context = key.currentContext;
      final renderObject = context?.findRenderObject();
      if (context == null || renderObject == null) {
        if (enableDebugLogs) {
        }
        return;
      }
      final viewport = RenderAbstractViewport.of(renderObject);
      // Offset para alinhar o bottom do widget ao fundo do viewport
      final reveal = viewport.getOffsetToReveal(renderObject, 1.0);
      double target = reveal.offset - extraBottomMargin;
      target = target.clamp(position.minScrollExtent, position.maxScrollExtent);
      final current = position.pixels;
      final delta = (target - current).abs();
      if (enableDebugLogs) {
      }
      // Nunca mover para cima... exceto quando explicitamente permitido (ex.: correção pós-shrink)
      if (!allowScrollUpIfNeeded && target <= current + 0.5) {
        if (enableDebugLogs) {
        }
        return;
      }
      if (delta < 24.0) {
        if (enableDebugLogs) {
        }
        position.jumpTo(target);
      } else {
        if (enableDebugLogs) {
        }
        position.animateTo(
          target,
          duration: Duration(milliseconds: durationMs),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }


  /// Rola para o fim (maxScrollExtent) mas nunca move para cima.
  static void scrollToBottomNeverUp({
    required GlobalKey key,
    ScrollController? preferredController,
    int durationMs = 180,
    bool enableDebugLogs = false,
  }) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final context = key.currentContext;
      if (context == null) return;

      final primary = PrimaryScrollController.maybeOf(context);
      final scrollable = Scrollable.maybeOf(context);

      ScrollPosition? position;
      if (preferredController != null && preferredController.hasClients) {
        position = preferredController.position;
      } else if (primary != null && primary.hasClients) {
        position = primary.position;
      } else if (scrollable != null) {
        position = scrollable.position;
      } else {
        return;
      }

      final double current = position.pixels;
      final double target = position.maxScrollExtent;
      final double delta = (target - current).abs();

      if (enableDebugLogs) {
      }

      // Não sobe
      if (target <= current + 0.5) return;

      if (delta < 24.0) {
        position.jumpTo(target);
      } else {
        position.animateTo(
          target,
          duration: Duration(milliseconds: durationMs),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }


}
