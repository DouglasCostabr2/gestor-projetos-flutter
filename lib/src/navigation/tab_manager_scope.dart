import 'package:flutter/widgets.dart';
import 'tab_manager.dart';

/// InheritedWidget que fornece acesso ao TabManager em toda a árvore de widgets
class TabManagerScope extends InheritedWidget {
  final TabManager tabManager;
  
  const TabManagerScope({
    super.key,
    required this.tabManager,
    required super.child,
  });

  /// Obtém o TabManager do contexto
  static TabManager of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<TabManagerScope>();
    assert(scope != null, 'TabManagerScope not found in context');
    return scope!.tabManager;
  }

  /// Tenta obter o TabManager do contexto, retorna null se não encontrado
  static TabManager? maybeOf(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<TabManagerScope>();
    return scope?.tabManager;
  }

  @override
  bool updateShouldNotify(covariant TabManagerScope oldWidget) {
    return oldWidget.tabManager != tabManager;
  }
}

