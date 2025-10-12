import 'package:flutter/widgets.dart';
import 'app_state.dart';

class AppStateScope extends InheritedWidget {
  final AppState appState;
  const AppStateScope({super.key, required this.appState, required super.child});

  static AppState of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppStateScope>();
    assert(scope != null, 'AppStateScope not found in context');
    return scope!.appState;
  }

  @override
  bool updateShouldNotify(covariant AppStateScope oldWidget) => oldWidget.appState != appState;
}

