# Estrutura Visual - Atomic Design

Visualização completa da estrutura de componentes do projeto.

---

## 📁 Árvore de Diretórios

```
lib/ui/
│
├── 📄 ui.dart                          # Barrel file principal
├── 📄 atoms.dart                       # Barrel file de atoms
├── 📄 molecules.dart                   # Barrel file de molecules
├── 📄 organisms.dart                   # Barrel file de organisms
├── 📄 templates.dart                   # Barrel file de templates
│
├── 📖 README.md                        # Documentação principal
├── 🚀 QUICK_REFERENCE.md               # Referência rápida
├── 💡 EXAMPLES.md                      # Exemplos de uso
├── ✨ BEST_PRACTICES.md                # Boas práticas
├── 🔄 MIGRATION_GUIDE.md               # Guia de migração
├── 📊 ATOMIC_DESIGN_STATUS.md          # Status da migração
├── 📁 STRUCTURE.md                     # Este arquivo
│
├── 🔹 atoms/                           # COMPONENTES BÁSICOS
│   ├── 📄 atoms.dart                   # Barrel file
│   │
│   ├── 🔘 buttons/                     # 7 componentes
│   │   ├── primary_button.dart
│   │   ├── secondary_button.dart
│   │   ├── outline_button.dart
│   │   ├── text_button_custom.dart
│   │   ├── icon_button_custom.dart
│   │   ├── danger_button.dart
│   │   ├── success_button.dart
│   │   └── 📄 buttons.dart             # Barrel file
│   │
│   ├── ✏️ inputs/                      # 6 componentes
│   │   ├── generic_text_field.dart
│   │   ├── generic_text_area.dart
│   │   ├── generic_checkbox.dart
│   │   ├── generic_date_picker.dart
│   │   ├── generic_color_picker.dart
│   │   ├── generic_number_field.dart
│   │   └── 📄 inputs.dart              # Barrel file
│   │
│   └── 👤 avatars/                     # 1 componente
│       ├── cached_avatar.dart
│       └── 📄 avatars.dart             # Barrel file
│
├── 🔸 molecules/                       # COMBINAÇÕES SIMPLES
│   ├── 📄 molecules.dart               # Barrel file
│   │
│   ├── 📋 dropdowns/                   # 3 componentes
│   │   ├── async_dropdown_field.dart
│   │   ├── searchable_dropdown_field.dart
│   │   ├── multi_select_dropdown_field.dart
│   │   └── 📄 dropdowns.dart           # Barrel file
│   │
│   ├── 📊 table_cells/                 # 6 componentes
│   │   ├── table_cell_avatar.dart
│   │   ├── table_cell_avatar_list.dart
│   │   ├── table_cell_badge.dart
│   │   ├── table_cell_date.dart
│   │   ├── table_cell_text.dart
│   │   ├── table_cell_updated_by.dart
│   │   └── 📄 table_cells.dart         # Barrel file
│   │
│   └── 👥 user_avatar_name.dart        # 1 componente
│
├── 🔶 organisms/                       # COMPONENTES COMPLEXOS
│   └── 📄 organisms.dart               # Barrel file (vazio - em migração)
│
└── 📐 templates/                       # TEMPLATES DE PÁGINA
    └── 📄 templates.dart               # Barrel file
```

---

## 📊 Estatísticas por Categoria

### ✅ Atoms (14 componentes)

| Categoria | Quantidade | Status |
|-----------|------------|--------|
| Buttons | 7 | ✅ Migrado |
| Inputs | 6 | ✅ Migrado |
| Avatars | 1 | ✅ Migrado |
| **Total** | **14** | **100%** |

### ✅ Molecules (10 componentes)

| Categoria | Quantidade | Status |
|-----------|------------|--------|
| Dropdowns | 3 | ✅ Migrado |
| Table Cells | 6 | ✅ Migrado |
| User Components | 1 | ✅ Migrado |
| **Total** | **10** | **100%** |

### ⚠️ Organisms (~20 componentes)

| Categoria | Quantidade | Status |
|-----------|------------|--------|
| Navigation | 2 | ⚠️ Em lib/widgets/ |
| Tables | 3 | ⚠️ Em lib/widgets/ |
| Editors | 4 | ⚠️ Em lib/widgets/ |
| Sections | 3 | ⚠️ Em lib/widgets/ |
| Dialogs | 2 | ⚠️ Em lib/widgets/ |
| Tabs | 1 | ⚠️ Em lib/widgets/ |
| Lists | 1 | ⚠️ Em lib/widgets/ |
| **Total** | **~20** | **Pendente** |

---

## 🎯 Mapa de Dependências

```
┌─────────────────────────────────────────────────────────┐
│                        PAGES                            │
│                    (lib/src/features/)                  │
└────────────────────┬────────────────────────────────────┘
                     │
                     ↓
┌─────────────────────────────────────────────────────────┐
│                      TEMPLATES                          │
│                   (lib/ui/templates/)                   │
└────────────────────┬────────────────────────────────────┘
                     │
                     ↓
┌─────────────────────────────────────────────────────────┐
│                      ORGANISMS                          │
│                   (lib/ui/organisms/)                   │
│                  ⚠️ Em migração                         │
└────────────────────┬────────────────────────────────────┘
                     │
                     ↓
┌─────────────────────────────────────────────────────────┐
│                      MOLECULES                          │
│                   (lib/ui/molecules/)                   │
│                  ✅ 10 componentes                      │
└────────────────────┬────────────────────────────────────┘
                     │
                     ↓
┌─────────────────────────────────────────────────────────┐
│                        ATOMS                            │
│                    (lib/ui/atoms/)                      │
│                  ✅ 14 componentes                      │
└─────────────────────────────────────────────────────────┘
```

---

## 🔄 Fluxo de Import

### Opção 1: Import Único (Recomendado)

```dart
import 'package:gestor_projetos_flutter/ui/ui.dart';

// Acesso a todos os atoms e molecules
PrimaryButton(...)
GenericTextField(...)
AsyncDropdownField(...)
```

### Opção 2: Import por Categoria

```dart
import 'package:gestor_projetos_flutter/ui/atoms/atoms.dart';
import 'package:gestor_projetos_flutter/ui/molecules/molecules.dart';

// Acesso a atoms e molecules
PrimaryButton(...)
AsyncDropdownField(...)
```

### Opção 3: Import Específico

```dart
import 'package:gestor_projetos_flutter/ui/atoms/buttons/buttons.dart';
import 'package:gestor_projetos_flutter/ui/molecules/dropdowns/dropdowns.dart';

// Acesso apenas aos componentes importados
PrimaryButton(...)
AsyncDropdownField(...)
```

---

## 📈 Progresso da Migração

```
Atoms:      ████████████████████ 100% (14/14)
Molecules:  ████████████████████ 100% (10/10)
Organisms:  ░░░░░░░░░░░░░░░░░░░░   0% (0/~20)
Templates:  ░░░░░░░░░░░░░░░░░░░░   0% (0/0)
─────────────────────────────────────────────
Total:      ████████░░░░░░░░░░░░  55% (24/~44)
```

---

## 🗂️ Localização dos Componentes

### Atoms

| Componente | Arquivo | Categoria |
|------------|---------|-----------|
| PrimaryButton | `atoms/buttons/primary_button.dart` | Button |
| SecondaryButton | `atoms/buttons/secondary_button.dart` | Button |
| OutlineButton | `atoms/buttons/outline_button.dart` | Button |
| TextButtonCustom | `atoms/buttons/text_button_custom.dart` | Button |
| IconButtonCustom | `atoms/buttons/icon_button_custom.dart` | Button |
| DangerButton | `atoms/buttons/danger_button.dart` | Button |
| SuccessButton | `atoms/buttons/success_button.dart` | Button |
| GenericTextField | `atoms/inputs/generic_text_field.dart` | Input |
| GenericTextArea | `atoms/inputs/generic_text_area.dart` | Input |
| GenericCheckbox | `atoms/inputs/generic_checkbox.dart` | Input |
| GenericDatePicker | `atoms/inputs/generic_date_picker.dart` | Input |
| GenericColorPicker | `atoms/inputs/generic_color_picker.dart` | Input |
| GenericNumberField | `atoms/inputs/generic_number_field.dart` | Input |
| CachedAvatar | `atoms/avatars/cached_avatar.dart` | Avatar |

### Molecules

| Componente | Arquivo | Categoria |
|------------|---------|-----------|
| AsyncDropdownField | `molecules/dropdowns/async_dropdown_field.dart` | Dropdown |
| SearchableDropdownField | `molecules/dropdowns/searchable_dropdown_field.dart` | Dropdown |
| MultiSelectDropdownField | `molecules/dropdowns/multi_select_dropdown_field.dart` | Dropdown |
| TableCellAvatar | `molecules/table_cells/table_cell_avatar.dart` | Table Cell |
| TableCellAvatarList | `molecules/table_cells/table_cell_avatar_list.dart` | Table Cell |
| TableCellBadge | `molecules/table_cells/table_cell_badge.dart` | Table Cell |
| TableCellDate | `molecules/table_cells/table_cell_date.dart` | Table Cell |
| TableCellText | `molecules/table_cells/table_cell_text.dart` | Table Cell |
| TableCellUpdatedBy | `molecules/table_cells/table_cell_updated_by.dart` | Table Cell |
| UserAvatarName | `molecules/user_avatar_name.dart` | User |

### Organisms (em lib/widgets/)

| Componente | Arquivo Atual | Categoria |
|------------|---------------|-----------|
| SideMenu | `widgets/side_menu/` | Navigation |
| TabBarWidget | `widgets/tab_bar/` | Navigation |
| ReusableDataTable | `widgets/reusable_data_table.dart` | Table |
| DynamicPaginatedTable | `src/widgets/dynamic_paginated_table.dart` | Table |
| TableSearchFilterBar | `widgets/table_search_filter_bar.dart` | Table |
| CustomBriefingEditor | `widgets/custom_briefing_editor.dart` | Editor |
| ChatBriefing | `widgets/chat_briefing.dart` | Editor |
| AppFlowyTextField | `widgets/appflowy_text_field_with_toolbar.dart` | Editor |
| TextFieldWithToolbar | `widgets/text_field_with_toolbar.dart` | Editor |
| CommentsSection | `widgets/comments_section.dart` | Section |
| TaskFilesSection | `widgets/task_files_section.dart` | Section |
| FinalProjectSection | `widgets/final_project_section.dart` | Section |
| StandardDialog | `widgets/standard_dialog.dart` | Dialog |
| DriveConnectDialog | `widgets/drive_connect_dialog.dart` | Dialog |
| GenericTabView | `widgets/tabs/` | Tabs |
| ReorderableDragList | `widgets/reorderable_drag_list.dart` | List |

---

## 🎨 Convenções de Nomenclatura

### Arquivos
- **Snake case:** `primary_button.dart`
- **Descritivo:** Nome claro do componente
- **Sufixos:** `_button`, `_field`, `_dialog`, `_section`, `_cell`

### Classes
- **Pascal case:** `PrimaryButton`
- **Descritivo:** Nome indica função
- **Prefixos:** `Generic` para componentes genéricos

### Barrel Files
- **Nome da pasta:** `buttons.dart`, `inputs.dart`
- **Categoria:** `atoms.dart`, `molecules.dart`
- **Principal:** `ui.dart`

---

## 📚 Documentação Relacionada

- [README.md](README.md) - Visão geral completa
- [QUICK_REFERENCE.md](QUICK_REFERENCE.md) - Referência rápida
- [EXAMPLES.md](EXAMPLES.md) - Exemplos práticos
- [BEST_PRACTICES.md](BEST_PRACTICES.md) - Boas práticas
- [MIGRATION_GUIDE.md](MIGRATION_GUIDE.md) - Guia de migração
- [ATOMIC_DESIGN_STATUS.md](ATOMIC_DESIGN_STATUS.md) - Status detalhado

---

**Última atualização:** 2025-10-13  
**Versão:** 1.0.0

