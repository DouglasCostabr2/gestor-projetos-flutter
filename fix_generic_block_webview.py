#!/usr/bin/env python3
"""
Script para migrar GenericBlockEditor para usar MentionWebView
"""

import re

# Ler o arquivo
with open('lib/ui/organisms/editors/generic_block_editor.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# 1. Atualizar imports
content = re.sub(
    r"import '../../molecules/inputs/mention_overlay\.dart';\nimport '../../molecules/inputs/mention_protection_formatter\.dart';\nimport '../../molecules/inputs/mention_text_controller\.dart';",
    "import '../../molecules/inputs/mention_webview.dart';",
    content
)

# 2. Remover a classe _MentionTextField e suas dependências (do final do arquivo)
# Encontrar o início da classe _MentionTextField
mention_textfield_start = content.find('/// TextField com suporte a menções (@mentions)')
if mention_textfield_start != -1:
    # Remover tudo a partir daqui até o final
    content = content[:mention_textfield_start].rstrip() + '\n'

# 3. Atualizar _GBBlockWidgetState para não usar TextEditingController
# Substituir a declaração do controller
content = re.sub(
    r'class _GBBlockWidgetState extends State<_GBBlockWidget> \{\n  late TextEditingController _controller;',
    'class _GBBlockWidgetState extends State<_GBBlockWidget> {',
    content
)

# Adicionar _currentText após a declaração da classe
content = re.sub(
    r'(class _GBBlockWidgetState extends State<_GBBlockWidget> \{)\n(  Timer\? _debounceTimer;)',
    r'\1\n  String _currentText = \'\';\n\2',
    content
)

# 4. Atualizar initState para não criar controller
content = re.sub(
    r'  @override\n  void initState\(\) \{\n    super\.initState\(\);\n    _controller = MentionTextEditingController\(text: widget\.block\.content\);\n    _controller\.addListener\(_onContentChanged\);',
    r'  @override\n  void initState() {\n    super.initState();\n    _currentText = widget.block.content;',
    content
)

# 5. Atualizar _onContentChanged para _onTextChanged
content = re.sub(
    r'  void _onContentChanged\(\) \{[^}]+\}\n  \}',
    '''  void _onTextChanged(String newText) {
    debugPrint('🟢🟢🟢 [_GBBlockWidget._onTextChanged] text.length=\${newText.length}');
    _currentText = newText;
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      if (mounted) {
        debugPrint('🟢🟢🟢 [_GBBlockWidget._onTextChanged] CHAMANDO widget.onChanged após debounce');
        widget.onChanged(widget.block.copyWith(content: newText));
      }
    });
  }''',
    content,
    flags=re.DOTALL
)

# 6. Atualizar didUpdateWidget
content = re.sub(
    r'  @override\n  void didUpdateWidget\(covariant _GBBlockWidget oldWidget\) \{[^}]+\n  \}',
    '''  @override
  void didUpdateWidget(covariant _GBBlockWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.block.content != widget.block.content) {
      _currentText = widget.block.content;
    }
  }''',
    content,
    flags=re.DOTALL
)

# 7. Atualizar dispose para não dispor controller
content = re.sub(
    r'  @override\n  void dispose\(\) \{\n    _debounceTimer\?\.cancel\(\);\n    _textFocusNode\?\.dispose\(\);\n    _controller\.dispose\(\);',
    r'  @override\n  void dispose() {\n    _debounceTimer?.cancel();\n    _textFocusNode?.dispose();',
    content
)

# 8. Atualizar _buildTextBlock para usar MentionWebView
old_build_text = r'''  Widget _buildTextBlock\(\) \{
    if \(!widget\.enabled\) \{
      final text = _controller\.text\.trim\(\);
      if \(text\.isEmpty\) return const SizedBox\.shrink\(\);

      // Renderizar com suporte a menções
      return Padding\(
        padding: const EdgeInsets\.symmetric\(vertical: 8, horizontal: 12\),
        child: MentionText\(
          text: text,
          style: const TextStyle\(color: Color\(0xFFEAEAEA\), fontSize: 14, height: 1\.5\),
        \),
      \);
    \}

    final bool minimalChrome = widget\.enabled && widget\.onRemove == null;

    return _MentionTextField\([^}]+\}\n    \);
  \}'''

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

content = re.sub(old_build_text, new_build_text, content, flags=re.DOTALL)

# Salvar o arquivo
with open('lib/ui/organisms/editors/generic_block_editor.dart', 'w', encoding='utf-8') as f:
    f.write(content)

print("✅ Arquivo atualizado com sucesso!")

