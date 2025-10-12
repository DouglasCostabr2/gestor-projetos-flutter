# Guia de Uso - ReorderableDragList

## 📦 Componente Reutilizável de Drag and Drop

O `ReorderableDragList` é um widget genérico e reutilizável para criar listas com funcionalidade de drag and drop (reordenação).

---

## 🚀 Importação

```dart
import 'package:gestor_projetos_flutter/widgets/reorderable_drag_list.dart';
```

---

## 📋 Características

✅ **Genérico** - Funciona com qualquer tipo de dado (`List<T>`)
✅ **Drag Handle Customizável** - Ícone, cor, tamanho personalizáveis
✅ **Habilitar/Desabilitar** - Controle total sobre quando permitir drag
✅ **Keys Únicas** - Mantém estado dos widgets durante reordenação
✅ **Widget Vazio** - Exibe widget customizado quando lista está vazia
✅ **Duas Variantes** - Com drag handle ou item inteiro arrastável

---

## 🎯 Uso Básico

### Exemplo 1: Lista Simples com Drag Handle

```dart
class MyPage extends StatefulWidget {
  @override
  State<MyPage> createState() => _MyPageState();
}

class _MyPageState extends State<MyPage> {
  List<String> _items = ['Item 1', 'Item 2', 'Item 3'];

  @override
  Widget build(BuildContext context) {
    return ReorderableDragList<String>(
      items: _items,
      enabled: true,
      onReorder: (oldIndex, newIndex) {
        setState(() {
          if (newIndex > oldIndex) newIndex -= 1;
          final item = _items.removeAt(oldIndex);
          _items.insert(newIndex, item);
        });
      },
      itemBuilder: (context, item, index) {
        return Container(
          padding: EdgeInsets.all(8),
          child: Text(item),
        );
      },
      getKey: (item) => item, // Usa o próprio item como key
    );
  }
}
```

---

### Exemplo 2: Lista de Objetos Complexos

```dart
class CatalogItem {
  final String id;
  final String name;
  final String type;
  final int price;

  CatalogItem({
    required this.id,
    required this.name,
    required this.type,
    required this.price,
  });
}

class CatalogList extends StatefulWidget {
  @override
  State<CatalogList> createState() => _CatalogListState();
}

class _CatalogListState extends State<CatalogList> {
  List<CatalogItem> _catalogItems = [];

  @override
  Widget build(BuildContext context) {
    return ReorderableDragList<CatalogItem>(
      items: _catalogItems,
      enabled: true,
      onReorder: (oldIndex, newIndex) {
        setState(() {
          if (newIndex > oldIndex) newIndex -= 1;
          final item = _catalogItems.removeAt(oldIndex);
          _catalogItems.insert(newIndex, item);
        });
      },
      itemBuilder: (context, item, index) {
        return Container(
          margin: EdgeInsets.only(bottom: 8),
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(item.name, style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 4),
              Text('${item.type} - R\$ ${(item.price / 100).toStringAsFixed(2)}'),
            ],
          ),
        );
      },
      getKey: (item) => item.id,
      emptyWidget: Center(child: Text('Nenhum item adicionado')),
    );
  }
}
```

---

### Exemplo 3: Customização do Drag Handle

```dart
ReorderableDragList<MyItem>(
  items: _items,
  enabled: true,
  onReorder: _handleReorder,
  itemBuilder: _buildItem,
  getKey: (item) => item.id,
  
  // Customizações do drag handle
  dragHandleIcon: Icons.menu, // Ícone diferente
  dragHandleSize: 20, // Tamanho menor
  dragHandleColor: Colors.blue, // Cor azul
  dragHandlePadding: EdgeInsets.only(right: 12), // Mais espaçamento
)
```

---

### Exemplo 4: Lista com Item Inteiro Arrastável

Use `ReorderableDragListFullItem` quando quiser que o item inteiro seja arrastável (sem drag handle separado):

```dart
ReorderableDragListFullItem<String>(
  items: _items,
  enabled: true,
  onReorder: (oldIndex, newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex -= 1;
      final item = _items.removeAt(oldIndex);
      _items.insert(newIndex, item);
    });
  },
  itemBuilder: (context, item, index) {
    return ListTile(
      title: Text(item),
      trailing: Icon(Icons.drag_handle),
    );
  },
  getKey: (item) => item,
)
```

---

### Exemplo 5: Desabilitar Drag Temporariamente

```dart
class EditableList extends StatefulWidget {
  @override
  State<EditableList> createState() => _EditableListState();
}

class _EditableListState extends State<EditableList> {
  List<String> _items = ['A', 'B', 'C'];
  bool _isEditing = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ElevatedButton(
          onPressed: () => setState(() => _isEditing = !_isEditing),
          child: Text(_isEditing ? 'Salvar' : 'Editar'),
        ),
        ReorderableDragList<String>(
          items: _items,
          enabled: _isEditing, // Só permite drag quando está editando
          onReorder: (oldIndex, newIndex) {
            setState(() {
              if (newIndex > oldIndex) newIndex -= 1;
              final item = _items.removeAt(oldIndex);
              _items.insert(newIndex, item);
            });
          },
          itemBuilder: (context, item, index) {
            return Container(
              padding: EdgeInsets.all(8),
              child: Text(item),
            );
          },
          getKey: (item) => item,
        ),
      ],
    );
  }
}
```

---

## 📚 Parâmetros

### ReorderableDragList

| Parâmetro | Tipo | Obrigatório | Padrão | Descrição |
|-----------|------|-------------|--------|-----------|
| `items` | `List<T>` | ✅ Sim | - | Lista de itens a serem exibidos |
| `onReorder` | `Function(int, int)` | ✅ Sim | - | Callback quando item é reordenado |
| `itemBuilder` | `Function(BuildContext, T, int)` | ✅ Sim | - | Builder para construir cada item |
| `getKey` | `Function(T)` | ✅ Sim | - | Função para obter key única do item |
| `enabled` | `bool` | ❌ Não | `true` | Se drag está habilitado |
| `dragHandleIcon` | `IconData` | ❌ Não | `Icons.drag_indicator` | Ícone do drag handle |
| `dragHandleSize` | `double` | ❌ Não | `24` | Tamanho do ícone |
| `dragHandleColor` | `Color?` | ❌ Não | Cinza com opacidade | Cor do ícone |
| `dragHandlePadding` | `EdgeInsets` | ❌ Não | `EdgeInsets.only(right: 8)` | Padding do handle |
| `shrinkWrap` | `bool` | ❌ Não | `true` | Se deve usar shrinkWrap |
| `physics` | `ScrollPhysics?` | ❌ Não | `NeverScrollableScrollPhysics` | Physics do scroll |
| `padding` | `EdgeInsets` | ❌ Não | `EdgeInsets.zero` | Padding da lista |
| `emptyWidget` | `Widget?` | ❌ Não | `null` | Widget quando lista vazia |

---

## 🔄 Migração de Código Existente

### Antes (código duplicado):

```dart
ReorderableListView.builder(
  shrinkWrap: true,
  buildDefaultDragHandles: false,
  physics: const NeverScrollableScrollPhysics(),
  itemCount: _catalogItems.length,
  onReorder: (oldIndex, newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex -= 1;
      final item = _catalogItems.removeAt(oldIndex);
      _catalogItems.insert(newIndex, item);
    });
  },
  itemBuilder: (context, i) {
    final it = _catalogItems[i];
    return Container(
      key: ValueKey(it.id),
      child: Row(
        children: [
          ReorderableDragStartListener(
            index: i,
            child: Icon(Icons.drag_indicator),
          ),
          Expanded(child: Text(it.name)),
        ],
      ),
    );
  },
)
```

### Depois (usando componente):

```dart
ReorderableDragList<CatalogItem>(
  items: _catalogItems,
  enabled: true,
  onReorder: (oldIndex, newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex -= 1;
      final item = _catalogItems.removeAt(oldIndex);
      _catalogItems.insert(newIndex, item);
    });
  },
  itemBuilder: (context, item, index) {
    return Text(item.name);
  },
  getKey: (item) => item.id,
)
```

**Benefícios:**
- ✅ Menos código
- ✅ Mais legível
- ✅ Consistente em todo o projeto
- ✅ Fácil de manter

---

## 💡 Dicas

1. **Key Única**: Sempre use uma key única e estável (como ID do banco de dados)
2. **Reorder Logic**: A lógica `if (newIndex > oldIndex) newIndex -= 1;` é necessária para o Flutter
3. **Performance**: Use `shrinkWrap: true` apenas quando necessário (dentro de ScrollView)
4. **Empty State**: Sempre forneça um `emptyWidget` para melhor UX

---

## 🎨 Casos de Uso no Projeto

- ✅ Reordenar itens do catálogo em projetos
- ✅ Reordenar produtos em pacotes
- ✅ Reordenar blocos no editor de briefing
- ✅ Reordenar tarefas (futuro)
- ✅ Reordenar arquivos/assets (futuro)

---

## 🔧 Troubleshooting

### Problema: Items não reordenam
**Solução**: Verifique se está chamando `setState()` no callback `onReorder`

### Problema: Keys duplicadas
**Solução**: Use IDs únicos na função `getKey`, não índices

### Problema: Drag handle não aparece
**Solução**: Verifique se `enabled: true` está definido

### Problema: Lista não rola
**Solução**: Ajuste `physics` para `AlwaysScrollableScrollPhysics()` se necessário

