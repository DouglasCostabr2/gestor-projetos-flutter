# 🔄 Guia de Migração - Atomic Design

Este documento orienta a migração de imports da estrutura antiga (`lib/widgets/`) para a nova estrutura Atomic Design (`lib/ui/`).

---

## 📋 Tabela de Migração de Imports

### Atoms (Componentes Básicos)

| **Antes** | **Depois** |
|-----------|------------|
| `import 'package:gestor_projetos_flutter/widgets/buttons/buttons.dart';` | `import 'package:gestor_projetos_flutter/ui/atoms/buttons/buttons.dart';` |
| `import 'package:gestor_projetos_flutter/widgets/inputs/inputs.dart';` | `import 'package:gestor_projetos_flutter/ui/atoms/inputs/inputs.dart';` |
| `import 'package:gestor_projetos_flutter/widgets/cached_avatar.dart';` | `import 'package:gestor_projetos_flutter/ui/atoms/avatars/cached_avatar.dart';` |

### Molecules (Combinações Simples)

| **Antes** | **Depois** |
|-----------|------------|
| `import 'package:gestor_projetos_flutter/widgets/dropdowns/dropdowns.dart';` | `import 'package:gestor_projetos_flutter/ui/molecules/dropdowns/dropdowns.dart';` |
| `import 'package:gestor_projetos_flutter/widgets/table_cells/table_cells.dart';` | `import 'package:gestor_projetos_flutter/ui/molecules/table_cells/table_cells.dart';` |
| `import 'package:gestor_projetos_flutter/widgets/user_avatar_name.dart';` | `import 'package:gestor_projetos_flutter/ui/molecules/user_avatar_name.dart';` |

### Organisms (Componentes Complexos)

| **Antes** | **Depois** |
|-----------|------------|
| `import 'package:gestor_projetos_flutter/widgets/side_menu.dart';` | `import 'package:gestor_projetos_flutter/ui/organisms/navigation/side_menu/side_menu.dart';` |
| `import 'package:gestor_projetos_flutter/widgets/side_menu/side_menu.dart';` | `import 'package:gestor_projetos_flutter/ui/organisms/navigation/side_menu/side_menu.dart';` |
| `import 'package:gestor_projetos_flutter/widgets/tab_bar/tab_bar_widget.dart';` | `import 'package:gestor_projetos_flutter/ui/organisms/navigation/tab_bar/tab_bar_widget.dart';` |
| `import 'package:gestor_projetos_flutter/widgets/reusable_data_table.dart';` | `import 'package:gestor_projetos_flutter/ui/organisms/tables/reusable_data_table.dart';` |
| `import 'package:gestor_projetos_flutter/widgets/table_search_filter_bar.dart';` | `import 'package:gestor_projetos_flutter/ui/organisms/tables/table_search_filter_bar.dart';` |
| `import 'package:gestor_projetos_flutter/src/widgets/dynamic_paginated_table.dart';` | `import 'package:gestor_projetos_flutter/ui/organisms/tables/dynamic_paginated_table.dart';` |
| `import 'package:gestor_projetos_flutter/widgets/custom_briefing_editor.dart';` | `import 'package:gestor_projetos_flutter/ui/organisms/editors/custom_briefing_editor.dart';` |
| `import 'package:gestor_projetos_flutter/widgets/chat_briefing.dart';` | `import 'package:gestor_projetos_flutter/ui/organisms/editors/chat_briefing.dart';` |
| `import 'package:gestor_projetos_flutter/widgets/comments_section.dart';` | `import 'package:gestor_projetos_flutter/ui/organisms/sections/comments_section.dart';` |
| `import 'package:gestor_projetos_flutter/widgets/task_files_section.dart';` | `import 'package:gestor_projetos_flutter/ui/organisms/sections/task_files_section.dart';` |
| `import 'package:gestor_projetos_flutter/widgets/final_project_section.dart';` | `import 'package:gestor_projetos_flutter/ui/organisms/sections/final_project_section.dart';` |
| `import 'package:gestor_projetos_flutter/widgets/standard_dialog.dart';` | `import 'package:gestor_projetos_flutter/ui/organisms/dialogs/standard_dialog.dart';` |
| `import 'package:gestor_projetos_flutter/widgets/drive_connect_dialog.dart';` | `import 'package:gestor_projetos_flutter/ui/organisms/dialogs/drive_connect_dialog.dart';` |
| `import 'package:gestor_projetos_flutter/widgets/tabs/tabs.dart';` | `import 'package:gestor_projetos_flutter/ui/organisms/tabs/tabs.dart';` |
| `import 'package:gestor_projetos_flutter/widgets/reorderable_drag_list.dart';` | `import 'package:gestor_projetos_flutter/ui/organisms/lists/reorderable_drag_list.dart';` |

---

## 🎯 Import Único (Recomendado)

Em vez de importar cada categoria separadamente, você pode usar o barrel file principal:

```dart
// ✅ RECOMENDADO - Import único
import 'package:gestor_projetos_flutter/ui/ui.dart';
```

Isso importa automaticamente:
- Todos os atoms (buttons, inputs, avatars)
- Todas as molecules (dropdowns, table_cells, user_avatar_name)
- Todos os organisms (navigation, tables, editors, sections, dialogs, tabs, lists)

---

## 📝 Processo de Migração

### 1. Identificar imports antigos
Procure por imports que começam com:
- `import 'package:gestor_projetos_flutter/widgets/`
- `import 'package:gestor_projetos_flutter/src/widgets/`

### 2. Substituir pelos novos imports
Use a tabela acima para encontrar o novo caminho.

### 3. Testar
Após cada arquivo migrado:
```bash
flutter analyze
```

### 4. Executar aplicativo
Após migrar um grupo de arquivos relacionados, execute o aplicativo para garantir que tudo funciona.

---

## ⚠️ Atenção

### Imports Relativos
Se você encontrar imports relativos (começando com `../`), eles também precisam ser atualizados:

**Antes:**
```dart
import '../widgets/buttons/buttons.dart';
```

**Depois:**
```dart
import 'package:gestor_projetos_flutter/ui/atoms/buttons/buttons.dart';
// OU
import 'package:gestor_projetos_flutter/ui/ui.dart';
```

### Componentes de Features
Componentes específicos de features (`lib/src/features/*/widgets/`) **NÃO** foram movidos e permanecem onde estão.

---

## 📊 Status da Migração

- [x] Estrutura criada
- [x] Atoms copiados
- [x] Molecules copiados
- [x] Organisms copiados
- [ ] Imports atualizados nas páginas
- [ ] Código antigo removido

---

**Última atualização:** 2025-10-13

