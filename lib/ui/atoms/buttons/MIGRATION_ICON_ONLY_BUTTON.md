# Migração para IconOnlyButton

Este documento descreve a migração de `IconButton` inline para o componente genérico `IconOnlyButton`.

---

## 📋 Status da Migração

### ✅ Componente Criado
- [x] `IconOnlyButton` criado em `lib/widgets/buttons/icon_only_button.dart`
- [x] Exportado em `lib/widgets/buttons/buttons.dart`
- [x] Documentação adicionada ao README.md
- [x] Exemplos criados em `icon_only_button_example.dart`

### 🔄 Arquivos a Migrar

#### Widgets (Alta Prioridade)
- [x] `lib/widgets/text_field_with_toolbar.dart` - Toolbar com múltiplos IconButton ✅
- [x] `lib/widgets/appflowy_text_field_with_toolbar.dart` - Toolbar de formatação ✅
- [x] `lib/widgets/custom_briefing_editor.dart` - Editor de briefing ✅
- [x] `lib/widgets/comments_section.dart` - Seção de comentários ✅
- [x] `lib/widgets/standard_dialog.dart` - Dialogs padrão ✅
- [x] `lib/widgets/side_menu/side_menu.dart` - Menu lateral (logout button) ✅
- [x] `lib/widgets/tab_bar/new_tab_dialog.dart` - Dialog de nova aba ✅

#### Features - Clients (Média Prioridade)
- [x] `lib/src/features/clients/widgets/avatar_picker.dart` - Picker de avatar ✅
- [x] `lib/src/features/clients/widgets/client_financial_section.dart` - Seção financeira ✅
- [x] `lib/src/features/clients/client_detail_page.dart` - Detalhes do cliente ✅
- [x] `lib/src/features/clients/client_financial_page.dart` - Página financeira ✅
- [x] `lib/src/features/clients/client_categories_page.dart` - Categorias ✅

#### Features - Projects (Média Prioridade)
- [x] `lib/src/features/projects/widgets/project_financial_section.dart` - Seção financeira ✅
- [x] `lib/src/features/projects/widgets/project_finance_tabs.dart` - Abas financeiras ✅
- [x] `lib/src/features/projects/project_detail_page.dart` - Detalhes do projeto ✅
- [x] `lib/src/features/projects/project_form_dialog.dart` - Formulário de projeto ✅
- [x] `lib/src/features/projects/project_members_dialog.dart` - Membros do projeto ✅
- [x] `lib/src/features/projects/projects_page.dart` - Lista de projetos ✅

#### Features - Tasks (Média Prioridade)
- [x] `lib/src/features/tasks/widgets/subtasks_section.dart` - Seção de subtarefas ✅
- [x] `lib/src/features/tasks/task_detail_page.dart` - Detalhes da tarefa ✅

#### Features - Catalog (Média Prioridade)
- [x] `lib/src/features/catalog/catalog_page.dart` - Página de catálogo ✅
- [x] `lib/src/features/catalog/_select_products_dialog.dart` - Seleção de produtos ✅

#### Features - Outros (Baixa Prioridade)
- [x] `lib/src/features/admin/admin_page.dart` - Página admin ✅
- [x] `lib/src/features/companies/companies_page.dart` - Empresas ✅
- [x] `lib/src/features/companies/company_detail_page.dart` - Detalhes da empresa ✅
- [x] `lib/src/features/monitoring/user_monitoring_page.dart` - Monitoramento ✅
- [x] `lib/src/features/settings/settings_page.dart` - Configurações ✅
- [x] `lib/src/features/shared/quick_forms.dart` - Formulários rápidos ✅
- [x] `lib/src/features/users/users_page.dart` - Usuários ✅
- [x] `lib/src/widgets/dynamic_paginated_table.dart` - Tabela paginada ✅

#### Arquivos de Backup (Ignorar)
- [ ] `lib/src/features/clients/clients_page_backup.dart` - Backup (não migrar)
- [ ] `lib/src/features/tasks/tasks_page_backup.dart` - Backup (não migrar)

---

## 🔄 Padrões de Migração

### Padrão 1: IconButton Simples

**Antes:**
```dart
IconButton(
  icon: const Icon(Icons.edit),
  onPressed: _edit,
  tooltip: 'Editar',
)
```

**Depois:**
```dart
IconOnlyButton(
  icon: Icons.edit,
  onPressed: _edit,
  tooltip: 'Editar',
)
```

---

### Padrão 2: IconButton com Tamanho Customizado

**Antes:**
```dart
IconButton(
  icon: const Icon(Icons.delete, size: 18),
  onPressed: _delete,
  tooltip: 'Excluir',
)
```

**Depois:**
```dart
IconOnlyButton(
  icon: Icons.delete,
  onPressed: _delete,
  tooltip: 'Excluir',
  iconSize: 18,
)
```

---

### Padrão 3: IconButton com Cor Customizada

**Antes:**
```dart
IconButton(
  icon: Icon(Icons.favorite, color: Colors.red),
  onPressed: _favorite,
  tooltip: 'Favoritar',
)
```

**Depois:**
```dart
IconOnlyButton(
  icon: Icons.favorite,
  onPressed: _favorite,
  tooltip: 'Favoritar',
  iconColor: Colors.red,
)
```

---

### Padrão 4: IconButton.filled

**Antes:**
```dart
IconButton.filled(
  icon: const Icon(Icons.add),
  onPressed: _add,
  tooltip: 'Adicionar',
)
```

**Depois:**
```dart
IconOnlyButton(
  icon: Icons.add,
  onPressed: _add,
  tooltip: 'Adicionar',
  variant: IconButtonVariant.filled,
)
```

---

### Padrão 5: IconButton.filledTonal

**Antes:**
```dart
IconButton.filledTonal(
  icon: const Icon(Icons.settings),
  onPressed: _settings,
  tooltip: 'Configurações',
)
```

**Depois:**
```dart
IconOnlyButton(
  icon: Icons.settings,
  onPressed: _settings,
  tooltip: 'Configurações',
  variant: IconButtonVariant.tonal,
)
```

---

### Padrão 6: IconButton.outlined

**Antes:**
```dart
IconButton.outlined(
  icon: const Icon(Icons.info),
  onPressed: _info,
  tooltip: 'Informações',
)
```

**Depois:**
```dart
IconOnlyButton(
  icon: Icons.info,
  onPressed: _info,
  tooltip: 'Informações',
  variant: IconButtonVariant.outlined,
)
```

---

### Padrão 7: IconButton com Padding Customizado

**Antes:**
```dart
IconButton(
  icon: const Icon(Icons.close),
  onPressed: _close,
  padding: const EdgeInsets.all(8),
  constraints: const BoxConstraints(
    minWidth: 36,
    minHeight: 36,
  ),
)
```

**Depois:**
```dart
IconOnlyButton(
  icon: Icons.close,
  onPressed: _close,
  padding: const EdgeInsets.all(8),
)
```

---

## 📝 Checklist de Migração

Para cada arquivo:

1. [ ] Adicionar import: `import 'package:gestor_projetos_flutter/widgets/buttons/buttons.dart';`
2. [ ] Identificar todos os `IconButton` no arquivo
3. [ ] Substituir cada `IconButton` por `IconOnlyButton` seguindo os padrões acima
4. [ ] Remover `const Icon()` wrapper (IconOnlyButton aceita `IconData` diretamente)
5. [ ] Ajustar propriedades conforme necessário
6. [ ] Testar visualmente o componente
7. [ ] Marcar como concluído neste documento

---

## 🎯 Benefícios da Migração

1. **Consistência**: Todos os botões de ícone seguem o mesmo padrão
2. **Manutenibilidade**: Mudanças no estilo podem ser feitas em um único lugar
3. **Loading State**: Suporte integrado para estado de carregamento
4. **Type Safety**: Menos erros com tipos
5. **Menos Código**: Menos boilerplate, código mais limpo
6. **Tooltip Integrado**: Tooltip é parte do componente

---

## 🚀 Próximos Passos

1. Migrar widgets de alta prioridade primeiro (toolbars, dialogs)
2. Migrar features por módulo (clients, projects, tasks)
3. Testar cada migração visualmente
4. Atualizar este documento conforme progresso
5. Remover arquivos de backup após confirmação

---

## 📚 Referências

- [IconOnlyButton Component](icon_only_button.dart)
- [Exemplos de Uso](icon_only_button_example.dart)
- [README](README.md)

