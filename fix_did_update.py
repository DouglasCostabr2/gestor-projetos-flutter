#!/usr/bin/env python3
with open('lib/ui/organisms/editors/generic_block_editor.dart', 'r', encoding='utf-8') as f:
    lines = f.readlines()

# Encontrar e substituir didUpdateWidget
in_did_update = False
start_line = None
for i, line in enumerate(lines):
    if 'void didUpdateWidget(covariant _GBBlockWidget oldWidget) {' in line and i > 600:
        start_line = i - 1  # Incluir o @override
        in_did_update = True
    elif in_did_update and line.strip() == '}' and i > start_line + 5:
        # Substituir todo o método
        new_method = [
            '  @override\n',
            '  void didUpdateWidget(covariant _GBBlockWidget oldWidget) {\n',
            '    super.didUpdateWidget(oldWidget);\n',
            '    if (oldWidget.block.content != widget.block.content) {\n',
            '      _currentText = widget.block.content;\n',
            '    }\n',
            '  }\n',
        ]
        lines[start_line:i+1] = new_method
        break

# Encontrar e atualizar dispose
for i, line in enumerate(lines):
    if '_controller.dispose();' in line and i > 600:
        lines[i] = ''
        break

# Salvar
with open('lib/ui/organisms/editors/generic_block_editor.dart', 'w', encoding='utf-8') as f:
    f.writelines(lines)

print("✅ didUpdateWidget e dispose atualizados!")

