#!/usr/bin/env python3
"""
Script cuidadoso para migrar GenericBlockEditor para usar MentionWebView
Preserva a estrutura do arquivo e faz apenas as mudanças necessárias
"""

with open('lib/ui/organisms/editors/generic_block_editor.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# 1. Atualizar imports - remover os antigos e adicionar o novo
content = content.replace(
    "import '../../molecules/inputs/mention_overlay.dart';\n",
    ""
)
content = content.replace(
    "import '../../molecules/inputs/mention_protection_formatter.dart';\n",
    ""
)
content = content.replace(
    "import '../../molecules/inputs/mention_text_controller.dart';\n",
    ""
)
content = content.replace(
    "import '../../molecules/text/mention_text.dart';",
    "import '../../molecules/inputs/mention_webview.dart';\nimport '../../molecules/text/mention_text.dart';"
)

# 2. Substituir late TextEditingController _controller por String _currentText
content = content.replace(
    "class _GBBlockWidgetState extends State<_GBBlockWidget> {\n  late TextEditingController _controller;",
    "class _GBBlockWidgetState extends State<_GBBlockWidget> {\n  String _currentText = '';"
)

# 3. Substituir _controller = MentionTextEditingController por _currentText = widget.block.content
content = content.replace(
    "    _controller = MentionTextEditingController(text: widget.block.content);\n    _controller.addListener(_onContentChanged);",
    "    _currentText = widget.block.content;"
)

# 4. Substituir o bloco de emoji handler por um comentário
old_emoji = """      widget.registerInsertHandler?.call(widget.index, (emoji) {
        final sel = _controller.selection;
        final text = _controller.text;
        int start = sel.start;
        int end = sel.end;
        if (start < 0 || end < 0) {
          start = end = text.length;
        }
        debugPrint('📝 TextHandler(index=${widget.index}): emoji="$emoji" | selection=$start..$end | lenAntes=${text.length}');
        final newText = text.replaceRange(start, end, emoji);
        final newSelection = TextSelection.collapsed(offset: start + emoji.length);
        _controller.value = TextEditingValue(text: newText, selection: newSelection);
        widget.onChanged(widget.block.copyWith(content: newText));
        _textFocusNode?.requestFocus();
        debugPrint('✅ TextHandler(index=${widget.index}): lenDepois=${newText.length}');
        return true;
      });"""

new_emoji = "      // Note: Emoji insertion for WebView will be handled differently"

content = content.replace(old_emoji, new_emoji)

# 5. Renomear _onContentChanged para _onTextChanged
content = content.replace(
    "  void _onContentChanged() {\n    debugPrint('🟢🟢🟢 [_GBBlockWidget._onContentChanged] text.length=${_controller.text.length}');",
    "  void _onTextChanged(String newText) {\n    debugPrint('🟢🟢🟢 [_GBBlockWidget._onTextChanged] text.length=${newText.length}');\n    _currentText = newText;"
)

content = content.replace(
    "        widget.onChanged(widget.block.copyWith(content: _controller.text));",
    "        widget.onChanged(widget.block.copyWith(content: newText));"
)

# 6. Simplificar didUpdateWidget
old_did_update = """  @override
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
  }"""

new_did_update = """  @override
  void didUpdateWidget(covariant _GBBlockWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.block.content != widget.block.content) {
      _currentText = widget.block.content;
    }
  }"""

content = content.replace(old_did_update, new_did_update)

# 7. Remover _controller.dispose()
content = content.replace(
    "    _debounceTimer?.cancel();\n    _textFocusNode?.dispose();\n    _controller.dispose();",
    "    _debounceTimer?.cancel();\n    _textFocusNode?.dispose();"
)

# 8. Atualizar _buildTextBlock - substituir _controller.text por _currentText
content = content.replace(
    "      final text = _controller.text.trim();",
    "      final text = _currentText.trim();"
)

# 9. Substituir _MentionTextField por MentionWebView
old_mention_field = """    final bool minimalChrome = widget.enabled && widget.onRemove == null;

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
    );"""

new_mention_field = """    return MentionWebView(
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
    );"""

content = content.replace(old_mention_field, new_mention_field)

# 10. Remover as classes _MentionTextField no final do arquivo
# Encontrar o início da classe _MentionTextField
start_marker = "\n/// TextField com suporte a menções (@mentions)\n"
if start_marker in content:
    idx = content.index(start_marker)
    content = content[:idx] + "\n"

# Salvar
with open('lib/ui/organisms/editors/generic_block_editor.dart', 'w', encoding='utf-8') as f:
    f.write(content)

print("✅ Migração cuidadosa completa!")

