# 📋 Fase 3: Plano de Migração de Organisms

**Data:** 2025-10-13  
**Status:** 🔄 Em Andamento  
**Objetivo:** Migrar todos os organisms de `lib/widgets/` para `lib/ui/organisms/`

---

## ✅ Estrutura Criada

### Pastas e Barrel Files

- ✅ `lib/ui/organisms/dialogs/` + `dialogs.dart`
- ✅ `lib/ui/organisms/lists/` + `lists.dart`
- ✅ `lib/ui/organisms/tabs/` + `tabs.dart`
- ✅ `lib/ui/organisms/tables/` + `tables.dart`
- ✅ `lib/ui/organisms/editors/` + `editors.dart`
- ✅ `lib/ui/organisms/sections/` + `sections.dart`
- ✅ `lib/ui/organisms/navigation/` + `navigation.dart`
- ✅ `lib/ui/organisms/organisms.dart` - Barrel file principal atualizado

---

## 📊 Organisms a Migrar (16 componentes)

### 🟢 Low Complexity (2 componentes)

#### 1. StandardDialog
- **Localização atual:** `lib/widgets/standard_dialog.dart`
- **Destino:** `lib/ui/organisms/dialogs/standard_dialog.dart`
- **Dependências:** Nenhuma (apenas Flutter widgets)
- **Complexidade:** Baixa
- **Prioridade:** Alta (fácil de migrar)

#### 2. DriveConnectDialog
- **Localização atual:** `lib/widgets/drive_connect_dialog.dart`
- **Destino:** `lib/ui/organisms/dialogs/drive_connect_dialog.dart`
- **Dependências:** 
  - `IGoogleDriveService` (já disponível via Service Locator)
- **Complexidade:** Baixa
- **Prioridade:** Alta

---

### 🟡 Medium Complexity (5 componentes)

#### 3. ReorderableDragList
- **Localização atual:** `lib/widgets/reorderable_drag_list.dart`
- **Destino:** `lib/ui/organisms/lists/reorderable_drag_list.dart`
- **Dependências:** Nenhuma
- **Complexidade:** Média
- **Prioridade:** Média

#### 4. GenericTabView
- **Localização atual:** `lib/widgets/tabs/generic_tab_view.dart`
- **Destino:** `lib/ui/organisms/tabs/generic_tab_view.dart`
- **Dependências:** Nenhuma
- **Complexidade:** Média
- **Prioridade:** Média

#### 5. CommentsSection
- **Localização atual:** `lib/widgets/comments_section.dart`
- **Destino:** `lib/ui/organisms/sections/comments_section.dart`
- **Dependências:**
  - `task_comments_repository` (módulo existente)
- **Complexidade:** Média
- **Prioridade:** Média

#### 6. TaskFilesSection
- **Localização atual:** `lib/widgets/task_files_section.dart`
- **Destino:** `lib/ui/organisms/sections/task_files_section.dart`
- **Dependências:**
  - `task_files_repository` (módulo existente)
  - `IGoogleDriveService` (Service Locator)
- **Complexidade:** Média
- **Prioridade:** Média

#### 7. FinalProjectSection
- **Localização atual:** `lib/widgets/final_project_section.dart`
- **Destino:** `lib/ui/organisms/sections/final_project_section.dart`
- **Dependências:**
  - `IGoogleDriveService` (Service Locator)
  - `task_files_repository` (módulo existente)
- **Complexidade:** Média
- **Prioridade:** Média

---

### 🔴 High Complexity (9 componentes)

#### 8. ReusableDataTable
- **Localização atual:** `lib/widgets/reusable_data_table.dart`
- **Destino:** `lib/ui/organisms/tables/reusable_data_table.dart`
- **Dependências:** Múltiplas (callbacks, state management)
- **Complexidade:** Alta
- **Prioridade:** Baixa

#### 9. DynamicPaginatedTable
- **Localização atual:** `lib/src/widgets/dynamic_paginated_table.dart`
- **Destino:** `lib/ui/organisms/tables/dynamic_paginated_table.dart`
- **Dependências:** Múltiplas (paginação, filtros)
- **Complexidade:** Alta
- **Prioridade:** Baixa

#### 10. TableSearchFilterBar
- **Localização atual:** `lib/widgets/table_search_filter_bar.dart`
- **Destino:** `lib/ui/organisms/tables/table_search_filter_bar.dart`
- **Dependências:** State management complexo
- **Complexidade:** Alta
- **Prioridade:** Baixa

#### 11. CustomBriefingEditor
- **Localização atual:** `lib/widgets/custom_briefing_editor.dart`
- **Destino:** `lib/ui/organisms/editors/custom_briefing_editor.dart`
- **Dependências:**
  - `IBriefingImageService` (Service Locator)
  - `IGoogleDriveService` (Service Locator)
- **Complexidade:** Alta
- **Prioridade:** Média (usa Service Locator)

#### 12. ChatBriefing
- **Localização atual:** `lib/widgets/chat_briefing.dart`
- **Destino:** `lib/ui/organisms/editors/chat_briefing.dart`
- **Dependências:** Múltiplas
- **Complexidade:** Alta
- **Prioridade:** Baixa

#### 13. AppFlowyTextFieldWithToolbar
- **Localização atual:** `lib/widgets/appflowy_text_field_with_toolbar.dart`
- **Destino:** `lib/ui/organisms/editors/appflowy_text_field_with_toolbar.dart`
- **Dependências:** AppFlowy Editor
- **Complexidade:** Alta
- **Prioridade:** Baixa

#### 14. TextFieldWithToolbar
- **Localização atual:** `lib/widgets/text_field_with_toolbar.dart`
- **Destino:** `lib/ui/organisms/editors/text_field_with_toolbar.dart`
- **Dependências:** Múltiplas
- **Complexidade:** Alta
- **Prioridade:** Baixa

#### 15. SideMenu
- **Localização atual:** `lib/widgets/side_menu/` (múltiplos arquivos)
- **Destino:** `lib/ui/organisms/navigation/side_menu/`
- **Dependências:**
  - `AppStateScope` (state management)
  - `ITabManager` (Service Locator)
- **Complexidade:** Muito Alta
- **Prioridade:** Baixa (componente crítico)

#### 16. TabBarWidget
- **Localização atual:** `lib/widgets/tab_bar/tab_bar_widget.dart`
- **Destino:** `lib/ui/organisms/navigation/tab_bar_widget.dart`
- **Dependências:**
  - `ITabManager` (já usa Service Locator)
- **Complexidade:** Alta
- **Prioridade:** Média (já refatorado)

---

## 🎯 Estratégia de Migração

### Fase 3.1: Low Complexity (ATUAL)
1. ✅ Criar estrutura de pastas
2. [ ] Migrar StandardDialog
3. [ ] Migrar DriveConnectDialog
4. [ ] Testar e validar

### Fase 3.2: Medium Complexity
5. [ ] Migrar ReorderableDragList
6. [ ] Migrar GenericTabView
7. [ ] Migrar CommentsSection
8. [ ] Migrar TaskFilesSection
9. [ ] Migrar FinalProjectSection
10. [ ] Testar e validar

### Fase 3.3: High Complexity (Editors)
11. [ ] Migrar CustomBriefingEditor
12. [ ] Migrar ChatBriefing
13. [ ] Migrar AppFlowyTextFieldWithToolbar
14. [ ] Migrar TextFieldWithToolbar
15. [ ] Testar e validar

### Fase 3.4: High Complexity (Tables)
16. [ ] Migrar ReusableDataTable
17. [ ] Migrar DynamicPaginatedTable
18. [ ] Migrar TableSearchFilterBar
19. [ ] Testar e validar

### Fase 3.5: High Complexity (Navigation)
20. [ ] Migrar TabBarWidget
21. [ ] Migrar SideMenu
22. [ ] Testar e validar

### Fase 3.6: Limpeza Final
23. [ ] Remover `lib/widgets/` deprecated
24. [ ] Atualizar todos os imports
25. [ ] Validação completa
26. [ ] Atualizar documentação

---

## 📝 Checklist para Cada Migração

### Antes de Migrar
- [ ] Ler código atual e entender dependências
- [ ] Verificar se usa services (criar interfaces se necessário)
- [ ] Identificar todos os arquivos que importam o componente

### Durante a Migração
- [ ] Copiar arquivo para nova localização
- [ ] Atualizar imports internos
- [ ] Adaptar para usar Service Locator (se aplicável)
- [ ] Adicionar export no barrel file da categoria
- [ ] Atualizar imports em todos os arquivos que usam o componente

### Depois de Migrar
- [ ] Compilar projeto (`flutter build windows --debug`)
- [ ] Executar aplicativo e testar funcionalidade
- [ ] Verificar console para erros
- [ ] Atualizar documentação

---

## 🧪 Validação

### Após Cada Componente
```bash
flutter analyze lib/ui/organisms/
flutter build windows --debug
./build/windows/x64/runner/Debug/gestor_projetos_flutter.exe
```

### Após Cada Fase
```bash
flutter analyze
flutter test
./build/windows/x64/runner/Debug/gestor_projetos_flutter.exe
# Testar todas as funcionalidades relacionadas
```

---

## 📚 Documentação a Atualizar

- [ ] `lib/ui/ATOMIC_DESIGN_STATUS.md` - Atualizar status após cada fase
- [ ] `lib/ui/organisms/README.md` - Criar guia de organisms
- [ ] `docs/PHASE_3_COMPLETE.md` - Criar ao finalizar
- [ ] `CHANGELOG_ATOMIC_DESIGN.md` - Adicionar entradas

---

## 🎯 Próximo Passo

**Começar Fase 3.1:** Migrar StandardDialog e DriveConnectDialog

**Comando para iniciar:**
```
Migrar StandardDialog de lib/widgets/ para lib/ui/organisms/dialogs/
```

