#!/usr/bin/env python3
"""
Script final para migrar GenericBlockEditor para usar MentionWebView
"""

# Ler o arquivo
with open('lib/ui/organisms/editors/generic_block_editor.dart', 'r', encoding='utf-8') as f:
    lines = f.readlines()

# 1. Remover classes _MentionTextField
start_idx = None
for i, line in enumerate(lines):
    if '/// TextField com suporte a menções (@mentions)' in line:
        start_idx = i
        break

if start_idx is not None:
    lines = lines[:start_idx]

# 2. Atualizar imports
new_lines = []
for line in lines:
    if "import '../../molecules/inputs/mention_overlay.dart';" in line:
        continue
    elif "import '../../molecules/inputs/mention_protection_formatter.dart';" in line:
        continue
    elif "import '../../molecules/inputs/mention_text_controller.dart';" in line:
        continue
    elif "import '../../molecules/text/mention_text.dart';" in line:
        new_lines.append("import '../../molecules/inputs/mention_webview.dart';\n")
        new_lines.append(line)
    else:
        new_lines.append(line)

lines = new_lines

# 3. Substituir late TextEditingController _controller por String _currentText
for i, line in enumerate(lines):
    if 'late TextEditingController _controller;' in line and i > 600:  # Apenas na classe _GBBlockWidgetState
        lines[i] = '  String _currentText = \'\';\n'
        break

# 4. Substituir _controller = MentionTextEditingController por _currentText = widget.block.content
for i, line in enumerate(lines):
    if '_controller = MentionTextEditingController(text: widget.block.content);' in line:
        lines[i] = '    _currentText = widget.block.content;\n'
        # Remover a próxima linha (_controller.addListener)
        if i+1 < len(lines) and '_controller.addListener(_onContentChanged);' in lines[i+1]:
            lines[i+1] = ''
        break

# 5. Remover o handler de emoji
in_emoji_handler = False
emoji_start = None
for i, line in enumerate(lines):
    if 'widget.registerInsertHandler?.call(widget.index, (emoji) {' in line:
        emoji_start = i
        in_emoji_handler = True
    elif in_emoji_handler and '});' in line and 'registerInsertHandler' not in line:
        # Substituir todo o bloco por um comentário
        lines[emoji_start] = '      // Note: Emoji insertion for WebView will be handled differently\n'
        for j in range(emoji_start + 1, i + 1):
            lines[j] = ''
        break

# 6. Renomear _onContentChanged para _onTextChanged e atualizar
for i, line in enumerate(lines):
    if 'void _onContentChanged() {' in line:
        lines[i] = '  void _onTextChanged(String newText) {\n'
        # Atualizar a linha seguinte
        if i+1 < len(lines) and '_controller.text.length' in lines[i+1]:
            lines[i+1] = '    debugPrint(\'🟢🟢🟢 [_GBBlockWidget._onTextChanged] text.length=${newText.length}\');\n'
        # Adicionar _currentText = newText
        if i+2 < len(lines):
            lines.insert(i+2, '    _currentText = newText;\n')
        # Atualizar widget.onChanged
        for j in range(i, min(i+10, len(lines))):
            if 'widget.onChanged(widget.block.copyWith(content: _controller.text));' in lines[j]:
                lines[j] = '        widget.onChanged(widget.block.copyWith(content: newText));\n'
                break
        break

# 7. Atualizar didUpdateWidget
in_did_update = False
did_update_start = None
for i, line in enumerate(lines):
    if 'void didUpdateWidget(covariant _GBBlockWidget oldWidget) {' in line and i > 600:
        did_update_start = i
        in_did_update = True
    elif in_did_update and line.strip() == '}' and 'didUpdateWidget' not in line:
        # Substituir todo o método
        lines[did_update_start] = '  @override\n'
        lines[did_update_start+1] = '  void didUpdateWidget(covariant _GBBlockWidget oldWidget) {\n'
        lines[did_update_start+2] = '    super.didUpdateWidget(oldWidget);\n'
        lines[did_update_start+3] = '    if (oldWidget.block.content != widget.block.content) {\n'
        lines[did_update_start+4] = '      _currentText = widget.block.content;\n'
        lines[did_update_start+5] = '    }\n'
        lines[did_update_start+6] = '  }\n'
        for j in range(did_update_start+7, i+1):
            lines[j] = ''
        break

# 8. Atualizar dispose
for i, line in enumerate(lines):
    if '_controller.dispose();' in line and i > 600:
        lines[i] = ''
        break

# 9. Atualizar _buildTextBlock
in_build_text = False
build_text_start = None
for i, line in enumerate(lines):
    if 'Widget _buildTextBlock() {' in line:
        build_text_start = i
        in_build_text = True
    elif in_build_text and line.strip() == '}' and 'buildTextBlock' not in line:
        # Encontrar o final do método
        # Substituir _controller.text por _currentText
        for j in range(build_text_start, i+1):
            if 'final text = _controller.text.trim();' in lines[j]:
                lines[j] = '      final text = _currentText.trim();\n'
            elif 'return _MentionTextField(' in lines[j]:
                # Substituir todo o return _MentionTextField por MentionWebView
                lines[j] = '    return MentionWebView(\n'
                lines[j+1] = '      initialText: widget.block.content,\n'
                lines[j+2] = '      focusNode: _textFocusNode,\n'
                lines[j+3] = '      onTap: () => widget.onFocused?.call(widget.index),\n'
                lines[j+4] = '      enabled: widget.enabled,\n'
                lines[j+5] = '      maxLines: null,\n'
                lines[j+6] = '      height: 100,\n'
                lines[j+7] = '      style: const TextStyle(color: Color(0xFFEAEAEA), fontSize: 14, height: 1.5),\n'
                lines[j+8] = '      decoration: const InputDecoration(\n'
                lines[j+9] = '        hintText: \'Digite o texto...\',\n'
                lines[j+10] = '      ),\n'
                lines[j+11] = '      onChanged: _onTextChanged,\n'
                lines[j+12] = '    );\n'
                # Remover as linhas antigas
                for k in range(j+13, i+1):
                    lines[k] = ''
                break
        break

# Salvar o arquivo
with open('lib/ui/organisms/editors/generic_block_editor.dart', 'w', encoding='utf-8') as f:
    f.writelines(lines)

print("✅ Migração final completa!")

