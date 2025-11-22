#!/usr/bin/env python3
"""
Script completo para migrar GenericBlockEditor para usar MentionWebView
"""

# Ler o arquivo
with open('lib/ui/organisms/editors/generic_block_editor.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# 1. Atualizar didUpdateWidget
old_did_update = '''  @override
  void didUpdateWidget(covariant _GBBlockWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Sincroniza o TextEditingController quando o bloco  E9 atualizado pelo pai
    if (oldWidget.block.content != widget.block.content && _controller.text != widget.block.content) {
      final hadFocus = _textFocusNode?.hasFocus ?? false;
      final newText = widget.block.content;
      debugPrint('[GB] didUpdateWidget(index=${widget.index}): sync controller (len ${_controller.text.length} -> ${newText.length})');
      _controller.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: newText.length),
      );
      if (hadFocus) {
        _textFocusNode?.requestFocus();
      }
    }
  }'''

new_did_update = '''  @override
  void didUpdateWidget(covariant _GBBlockWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.block.content != widget.block.content) {
      _currentText = widget.block.content;
    }
  }'''

content = content.replace(old_did_update, new_did_update)

# 2. Atualizar dispose
old_dispose = '''  @override
  void dispose() {
    _debounceTimer?.cancel();
    _textFocusNode?.dispose();
    _controller.dispose();
    super.dispose();
  }'''

new_dispose = '''  @override
  void dispose() {
    _debounceTimer?.cancel();
    _textFocusNode?.dispose();
    super.dispose();
  }'''

content = content.replace(old_dispose, new_dispose)

# 3. Atualizar _buildTextBlock
old_build_text = '''  Widget _buildTextBlock() {
    if (!widget.enabled) {
      final text = _controller.text.trim();
      if (text.isEmpty) return const SizedBox.shrink();

      // Renderizar com suporte a menções
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        child: MentionText(
          text: text,
          style: const TextStyle(color: Color(0xFFEAEAEA), fontSize: 14, height: 1.5),
        ),
      );
    }

    final bool minimalChrome = widget.enabled && widget.onRemove == null;

    return _MentionTextField(
      controller: _controller,
      focusNode: _textFocusNode,
      onTap: () => widget.onFocused?.call(widget.index),
      enabled: widget.enabled,
      maxLines: null,
      style: const TextStyle(color: Color(0xFFEAEAEA), fontSize: 14, height: 1.5),
      decoration: InputDecoration(
        hintText: 'Digite o texto...',
        hintStyle: const TextStyle(color: Color(0xFF9AA0A6)),
        border: minimalChrome ? InputBorder.none : null,
        enabledBorder: minimalChrome ? InputBorder.none : null,
        focusedBorder: minimalChrome ? InputBorder.none : null,
        disabledBorder: minimalChrome ? InputBorder.none : null,
        filled: minimalChrome ? false : null,
        contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        isDense: true,
      ),
      onChanged: (text) {
        widget.onChanged(widget.block.copyWith(content: text));
      },
    );
  }'''

new_build_text = '''  Widget _buildTextBlock() {
    if (!widget.enabled) {
      final text = _currentText.trim();
      if (text.isEmpty) return const SizedBox.shrink();

      // Renderizar com suporte a menções
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        child: MentionText(
          text: text,
          style: const TextStyle(color: Color(0xFFEAEAEA), fontSize: 14, height: 1.5),
        ),
      );
    }

    return MentionWebView(
      initialText: widget.block.content,
      focusNode: _textFocusNode,
      onTap: () => widget.onFocused?.call(widget.index),
      enabled: widget.enabled,
      maxLines: null,
      height: 100,
      style: const TextStyle(color: Color(0xFFEAEAEA), fontSize: 14, height: 1.5),
      decoration: const InputDecoration(
        hintText: 'Digite o texto...',
      ),
      onChanged: _onTextChanged,
    );
  }'''

content = content.replace(old_build_text, new_build_text)

# Salvar o arquivo
with open('lib/ui/organisms/editors/generic_block_editor.dart', 'w', encoding='utf-8') as f:
    f.write(content)

print("✅ Migração completa!")

