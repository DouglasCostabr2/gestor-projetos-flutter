import 'package:flutter/material.dart';

/// Um container reutilizável que habilita a seleção de texto para seus filhos.
///
/// Este widget envolve o conteúdo em um [SelectionArea] padrão do Flutter.
/// Utilizar este componente centralizado facilita a manutenção e garante
/// consistência no comportamento de seleção de texto em toda a aplicação.
///
/// Exemplo de uso:
/// ```dart
/// SelectableContainer(
///   child: Column(
///     children: [
///       Text('Este texto pode ser selecionado'),
///       Text('Este também'),
///     ],
///   ),
/// )
/// ```
class SelectableContainer extends StatelessWidget {
  final Widget child;
  final FocusNode? focusNode;
  final TextSelectionControls? selectionControls;

  const SelectableContainer({
    super.key,
    required this.child,
    this.focusNode,
    this.selectionControls,
  });

  @override
  Widget build(BuildContext context) {
    return SelectionArea(
      focusNode: focusNode,
      selectionControls: selectionControls,
      child: child,
    );
  }
}
