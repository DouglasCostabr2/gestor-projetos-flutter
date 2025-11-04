import 'dart:ui';
import 'package:flutter/material.dart';

/// Helper para exibir diálogos com backdrop escuro e desfocado
/// 
/// Uso:
/// ```dart
/// final result = await DialogHelper.show<bool>(
///   context: context,
///   builder: (context) => MyDialog(),
/// );
/// ```
class DialogHelper {
  /// Cor de barreira padrão (preto com 70% de opacidade)
  static const Color defaultBarrierColor = Color(0xB3000000);
  
  /// Intensidade do blur padrão
  static const double defaultBlurSigma = 3.0;

  /// Exibe um diálogo com backdrop escuro e desfocado
  static Future<T?> show<T>({
    required BuildContext context,
    required WidgetBuilder builder,
    bool barrierDismissible = true,
    Color barrierColor = defaultBarrierColor,
    String? barrierLabel,
    double blurSigma = defaultBlurSigma,
  }) {
    return showDialog<T>(
      context: context,
      barrierDismissible: barrierDismissible,
      barrierColor: Colors.transparent, // Usamos transparent aqui porque vamos criar nosso próprio backdrop
      barrierLabel: barrierLabel,
      builder: (context) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
        child: Container(
          color: barrierColor,
          child: builder(context),
        ),
      ),
    );
  }
}

