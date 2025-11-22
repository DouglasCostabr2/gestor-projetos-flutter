#!/usr/bin/env python3
import re

with open('lib/ui/organisms/editors/generic_block_editor.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# Usar regex para substituir didUpdateWidget, ignorando o caractere especial
pattern = r'  @override\s+void didUpdateWidget\(covariant _GBBlockWidget oldWidget\) \{\s+super\.didUpdateWidget\(oldWidget\);\s+// Sincroniza o TextEditingController quando o bloco.*?\s+if \(oldWidget\.block\.content != widget\.block\.content && _controller\.text != widget\.block\.content\) \{.*?debugPrint\(\'\[GB\] didUpdateWidget.*?\);\s+_controller\.value = TextEditingValue\(.*?\);\s+if \(hadFocus\) \{\s+_textFocusNode\?\.requestFocus\(\);\s+\}\s+\}\s+\}'

replacement = '''  @override
  void didUpdateWidget(covariant _GBBlockWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.block.content != widget.block.content) {
      _currentText = widget.block.content;
    }
  }'''

content = re.sub(pattern, replacement, content, flags=re.DOTALL)

with open('lib/ui/organisms/editors/generic_block_editor.dart', 'w', encoding='utf-8') as f:
    f.write(content)

print("✅ didUpdateWidget atualizado com regex!")

