import 'package:flutter/material.dart';
import 'mention_overlay.dart';

/// Campo de texto com suporte a menções (@mentions)
///
/// Características:
/// - Detecta quando usuário digita "@"
/// - Mostra dropdown com lista de usuários
/// - Filtra usuários conforme digita
/// - Insere menção formatada ao selecionar
/// - Destaca menções visualmente
///
/// Exemplo de uso:
/// ```dart
/// MentionTextField(
///   controller: _controller,
///   onMentionsChanged: (mentions) {
///     print('Usuários mencionados: $mentions');
///   },
///   decoration: InputDecoration(
///     hintText: 'Digite @ para mencionar alguém...',
///   ),
/// )
/// ```
class MentionTextField extends StatefulWidget {
  final TextEditingController controller;
  final InputDecoration? decoration;
  final int? maxLines;
  final int? minLines;
  final TextStyle? style;
  final bool enabled;
  final FocusNode? focusNode;
  final ValueChanged<List<String>>? onMentionsChanged;
  final String? Function(String?)? validator;
  final VoidCallback? onTap;

  const MentionTextField({
    super.key,
    required this.controller,
    this.decoration,
    this.maxLines = 1,
    this.minLines,
    this.style,
    this.enabled = true,
    this.focusNode,
    this.onMentionsChanged,
    this.validator,
    this.onTap,
  });

  @override
  State<MentionTextField> createState() => _MentionTextFieldState();
}

class _MentionTextFieldState extends State<MentionTextField> {
  final LayerLink _layerLink = LayerLink();
  late FocusNode _focusNode;
  late MentionOverlay _overlay;
  late MentionTextFieldHelper _helper;

  @override
  void initState() {
    super.initState();
    _focusNode = widget.focusNode ?? FocusNode();

    _overlay = MentionOverlay(
      context: context,
      layerLink: _layerLink,
      onUserSelected: _onUserSelected,
    );

    _helper = MentionTextFieldHelper(
      controller: widget.controller,
      overlay: _overlay,
    );

    _overlay.loadUsers();
    widget.controller.addListener(_notifyMentionsChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_notifyMentionsChanged);
    _helper.dispose();
    _overlay.dispose();
    if (widget.focusNode == null) {
      _focusNode.dispose();
    }
    super.dispose();
  }

  void _onUserSelected(Map<String, dynamic> user) {
    _helper.insertMention(user);
    _notifyMentionsChanged();
  }

  void _notifyMentionsChanged() {
    if (widget.onMentionsChanged == null) return;
    
    final mentions = _extractMentions(widget.controller.text);
    widget.onMentionsChanged!(mentions);
  }

  List<String> _extractMentions(String text) {
    final regex = RegExp(r'@\[([^\]]+)\]\(([^)]+)\)');
    final matches = regex.allMatches(text);
    return matches.map((m) => m.group(2)!).toList();
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: TextFormField(
        controller: widget.controller,
        focusNode: _focusNode,
        decoration: widget.decoration,
        maxLines: widget.maxLines,
        minLines: widget.minLines,
        style: widget.style,
        enabled: widget.enabled,
        validator: widget.validator,
      ),
    );
  }
}

