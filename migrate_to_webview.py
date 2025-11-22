#!/usr/bin/env python3
"""
Script para migrar GenericBlockEditor para usar MentionWebView
"""

# Ler o arquivo
with open('lib/ui/organisms/editors/generic_block_editor.dart', 'r', encoding='utf-8') as f:
    lines = f.readlines()

# Encontrar e remover as classes _MentionTextField
start_idx = None
for i, line in enumerate(lines):
    if '/// TextField com suporte a menções (@mentions)' in line:
        start_idx = i
        break

if start_idx is not None:
    # Remover tudo a partir daqui
    lines = lines[:start_idx]

# Atualizar imports
new_lines = []
skip_next = False
for i, line in enumerate(lines):
    if skip_next:
        skip_next = False
        continue
    
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

# Salvar o arquivo
with open('lib/ui/organisms/editors/generic_block_editor.dart', 'w', encoding='utf-8') as f:
    f.writelines(lines)

print("✅ Imports atualizados e classes antigas removidas!")
print(f"Total de linhas: {len(lines)}")

