import 'package:flutter/widgets.dart';
import 'interfaces/tab_manager_interface.dart';

/// InheritedWidget que fornece acesso ao TabManager em toda a árvore de widgets
///
/// Usa a interface ITabManager para permitir desacoplamento e facilitar testes.
class TabManagerScope extends InheritedWidget {
  final ITabManager tabManager;

  const TabManagerScope({
    super.key,
    required this.tabManager,
    required super.child,
  });

  /// Obtém o TabManager do contexto
  static ITabManager of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<TabManagerScope>();
    assert(scope != null, 'TabManagerScope not found in context');
    return scope!.tabManager;
  }

  /// Tenta obter o TabManager do contexto, retorna null se não encontrado
  static ITabManager? maybeOf(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<TabManagerScope>();
    return scope?.tabManager;
  }

  @override
  bool updateShouldNotify(covariant TabManagerScope oldWidget) {
    return oldWidget.tabManager != tabManager;
  }
}

