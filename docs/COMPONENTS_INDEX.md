# Índice de Componentes Reutilizáveis

Este documento lista todos os componentes reutilizáveis disponíveis no projeto.

---

## 📦 Componentes Disponíveis

### 1. ReorderableDragList
**Localização**: `lib/widgets/reorderable_drag_list.dart`

**Descrição**: Componente genérico para listas com drag and drop (reordenação).

**Documentação**:
- 📖 [README](REORDERABLE_DRAG_LIST_README.md) - Visão geral e introdução
- 📚 [Guia Completo](REORDERABLE_DRAG_LIST_GUIDE.md) - Documentação detalhada
- 🔄 [Exemplos de Migração](REORDERABLE_MIGRATION_EXAMPLE.md) - Como migrar código existente
- 🎨 [Demo](../lib/widgets/reorderable_drag_list_demo.dart) - Página de demonstração interativa

**Uso**:
```dart
import 'package:gestor_projetos_flutter/widgets/reorderable_drag_list.dart';

ReorderableDragList<T>(
  items: _items,
  enabled: true,
  onReorder: (old, new) { /* ... */ },
  itemBuilder: (ctx, item, idx) => Widget(),
  getKey: (item) => item.id,
)
```

**Casos de Uso**:
- Reordenar itens do catálogo
- Reordenar produtos em pacotes
- Reordenar blocos de texto
- Qualquer lista que precise de reordenação

---

### 2. ReusableDataTable
**Localização**: `lib/widgets/reusable_data_table.dart`

**Descrição**: Tabela de dados reutilizável com checkboxes, ações e ordenação.

**Documentação**:
- 📚 [LISTA_MUDANCAS_TABELAS.md](../LISTA_MUDANCAS_TABELAS.md) - Documentação de migração

**Uso**:
```dart
import 'package:gestor_projetos_flutter/widgets/reusable_data_table.dart';

ReusableDataTable<T>(
  items: _items,
  selectedIds: _selected,
  onSelectionChanged: (ids) => setState(() => _selected = ids),
  columns: [...],
  cellBuilders: [...],
  getId: (item) => item['id'],
  onRowTap: (item) => { /* ... */ },
  actions: [...],
)
```

**Casos de Uso**:
- Tabelas de clientes
- Tabelas de projetos
- Tabelas de tarefas
- Qualquer tabela com dados

---

### 3. DynamicPaginatedTable
**Localização**: `lib/src/widgets/dynamic_paginated_table.dart`

**Descrição**: Tabela com paginação dinâmica baseada na altura disponível.

**Uso**:
```dart
import 'package:gestor_projetos_flutter/src/widgets/dynamic_paginated_table.dart';

DynamicPaginatedTable<T>(
  items: _filteredData,
  columns: [...],
  cellBuilders: [...],
  getId: (item) => item['id'],
  onRowTap: (item) => { /* ... */ },
)
```

**Casos de Uso**:
- Tabelas grandes com muitos itens
- Quando precisa de paginação automática

---

### 4. CustomBriefingEditor
**Localização**: `lib/widgets/custom_briefing_editor.dart`

**Descrição**: Editor de briefing com blocos de texto, imagens e tabelas.

**Documentação**:
- 📚 [APPFLOWY_EDITOR_GUIDE.md](APPFLOWY_EDITOR_GUIDE.md) - Guia do editor

**Uso**:
```dart
import 'package:gestor_projetos_flutter/widgets/custom_briefing_editor.dart';

CustomBriefingEditor(
  initialContent: _briefingContent,
  onChanged: (content) => setState(() => _briefingContent = content),
  enabled: !_saving,
)
```

**Casos de Uso**:
- Editor de briefing de tarefas
- Editor de descrições de projetos
- Qualquer editor de texto rico

---

### 5. TaskAssetsSection
**Localização**: `lib/src/features/tasks/widgets/task_assets_section.dart`

**Descrição**: Seção de assets de tarefas (imagens, arquivos, vídeos).

**Uso**:
```dart
import 'package:gestor_projetos_flutter/src/features/tasks/widgets/task_assets_section.dart';

TaskAssetsSection(
  assetsImages: _assetsImages,
  assetsFiles: _assetsFiles,
  assetsVideos: _assetsVideos,
  onAssetsChanged: (images, files, videos) {
    setState(() {
      _assetsImages = images;
      _assetsFiles = files;
      _assetsVideos = videos;
    });
  },
  enabled: !_saving,
)
```

**Casos de Uso**:
- Gerenciar assets de tarefas
- Upload de arquivos
- Visualização de arquivos

---

### 6. CommentsSection
**Localização**: `lib/widgets/comments_section.dart`

**Descrição**: Seção de comentários reutilizável.

**Uso**:
```dart
import 'package:gestor_projetos_flutter/widgets/comments_section.dart';

CommentsSection(
  taskId: widget.taskId,
  enabled: !_saving,
)
```

**Casos de Uso**:
- Comentários em tarefas
- Comentários em projetos
- Qualquer sistema de comentários

---

### 7. FinalProjectSection
**Localização**: `lib/widgets/final_project_section.dart`

**Descrição**: Seção de arquivos finais do projeto.

**Uso**:
```dart
import 'package:gestor_projetos_flutter/widgets/final_project_section.dart';

FinalProjectSection(
  task: _task,
  enabled: !_saving,
)
```

**Casos de Uso**:
- Upload de arquivos finais
- Gerenciamento de entregas

---

### 8. CachedAvatar
**Localização**: `lib/widgets/cached_avatar.dart`

**Descrição**: Avatar com cache de imagem.

**Uso**:
```dart
import 'package:gestor_projetos_flutter/widgets/cached_avatar.dart';

CachedAvatar(
  imageUrl: user['avatar_url'],
  name: user['name'],
  radius: 20,
)
```

**Casos de Uso**:
- Avatares de usuários
- Avatares de clientes
- Qualquer imagem circular com fallback

---

### 9. UserAvatarName
**Localização**: `lib/widgets/user_avatar_name.dart`

**Descrição**: Widget que combina avatar e nome do usuário.

**Uso**:
```dart
import 'package:gestor_projetos_flutter/widgets/user_avatar_name.dart';

UserAvatarName(
  userId: task['assigned_to'],
)
```

**Casos de Uso**:
- Exibir usuário atribuído
- Exibir criador de tarefa
- Qualquer exibição de usuário

---

### 10. StandardDialog
**Localização**: `lib/widgets/standard_dialog.dart`

**Descrição**: Dialog padrão reutilizável.

**Uso**:
```dart
import 'package:gestor_projetos_flutter/widgets/standard_dialog.dart';

showDialog(
  context: context,
  builder: (_) => StandardDialog(
    title: 'Título',
    content: Text('Conteúdo'),
    actions: [...],
  ),
)
```

**Casos de Uso**:
- Confirmações
- Alertas
- Formulários em dialog

---

## 🎯 Como Escolher o Componente Certo

### Precisa de uma lista reordenável?
→ Use **ReorderableDragList**

### Precisa de uma tabela de dados?
→ Use **ReusableDataTable** ou **DynamicPaginatedTable**

### Precisa de um editor de texto rico?
→ Use **CustomBriefingEditor**

### Precisa de upload de arquivos?
→ Use **TaskAssetsSection** ou **FinalProjectSection**

### Precisa de comentários?
→ Use **CommentsSection**

### Precisa de avatares?
→ Use **CachedAvatar** ou **UserAvatarName**

### Precisa de um dialog?
→ Use **StandardDialog**

---

## 📚 Documentação Geral

### Guias de Módulos
- [GUIA_RAPIDO_MODULOS.md](../GUIA_RAPIDO_MODULOS.md) - Como usar os módulos do projeto

### Guias de Migração
- [GOOGLE_DRIVE_MIGRATION_GUIDE.md](GOOGLE_DRIVE_MIGRATION_GUIDE.md) - Migração do Google Drive
- [LISTA_MUDANCAS_TABELAS.md](../LISTA_MUDANCAS_TABELAS.md) - Migração de tabelas

### Guias de Features
- [APPFLOWY_EDITOR_GUIDE.md](APPFLOWY_EDITOR_GUIDE.md) - Editor de texto
- [REFATORACAO_COMPLETA_RESUMO.md](../REFATORACAO_COMPLETA_RESUMO.md) - Resumo de refatorações

---

## 🚀 Criando Novos Componentes

Ao criar um novo componente reutilizável:

1. **Crie o arquivo** em `lib/widgets/` ou `lib/src/widgets/`
2. **Documente** com comentários no código
3. **Crie exemplos** de uso
4. **Adicione ao índice** (este arquivo)
5. **Crie guia** se necessário (em `docs/`)
6. **Teste** o componente

### Template de Componente

```dart
import 'package:flutter/material.dart';

/// Descrição do componente
///
/// Este componente faz X, Y e Z.
///
/// Características:
/// - Feature 1
/// - Feature 2
/// - Feature 3
///
/// Exemplo de uso:
/// ```dart
/// MyComponent(
///   param1: value1,
///   param2: value2,
/// )
/// ```
class MyComponent extends StatelessWidget {
  /// Descrição do parâmetro 1
  final String param1;

  /// Descrição do parâmetro 2
  final int param2;

  const MyComponent({
    super.key,
    required this.param1,
    this.param2 = 0,
  });

  @override
  Widget build(BuildContext context) {
    // Implementação
    return Container();
  }
}
```

---

## 📝 Manutenção

### Atualizar Componente Existente
1. Edite o arquivo do componente
2. Atualize a documentação
3. Atualize exemplos se necessário
4. Teste em todos os usos

### Depreciar Componente
1. Marque como `@deprecated`
2. Adicione mensagem de deprecação
3. Forneça alternativa
4. Remova após período de transição

---

## 🎉 Benefícios de Usar Componentes Reutilizáveis

1. ✅ **Menos Código** - Não repita código
2. ✅ **Consistência** - Mesmo comportamento em todo lugar
3. ✅ **Manutenibilidade** - Mudanças em um lugar
4. ✅ **Testabilidade** - Teste uma vez, funciona em todo lugar
5. ✅ **Documentação** - Documentado e com exemplos
6. ✅ **Produtividade** - Desenvolva mais rápido

---

**Sempre prefira usar componentes reutilizáveis em vez de duplicar código!** 🚀

