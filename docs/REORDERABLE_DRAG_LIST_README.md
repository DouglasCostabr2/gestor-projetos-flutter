# ReorderableDragList - Componente Reutilizável 🎯

## 📦 O que é?

`ReorderableDragList` é um **componente reutilizável** criado para padronizar e simplificar a implementação de listas com funcionalidade de **drag and drop** (reordenação) em todo o projeto.

---

## 🎯 Problema Resolvido

### Antes:
- ❌ Código duplicado em 5+ lugares diferentes
- ❌ Implementações inconsistentes
- ❌ Difícil de manter
- ❌ ~40-50 linhas de código por uso
- ❌ Fácil de cometer erros

### Depois:
- ✅ Componente único e reutilizável
- ✅ Implementação consistente
- ✅ Fácil de manter
- ✅ ~15-20 linhas de código por uso
- ✅ API clara e documentada

---

## 📁 Arquivos Criados

```
lib/widgets/
  └── reorderable_drag_list.dart          # Componente principal
  └── reorderable_drag_list_demo.dart     # Página de demonstração

docs/
  └── REORDERABLE_DRAG_LIST_GUIDE.md      # Guia completo de uso
  └── REORDERABLE_MIGRATION_EXAMPLE.md    # Exemplos de migração
  └── REORDERABLE_DRAG_LIST_README.md     # Este arquivo
```

---

## 🚀 Como Usar

### Importação

```dart
import 'package:gestor_projetos_flutter/widgets/reorderable_drag_list.dart';
```

### Uso Básico

```dart
ReorderableDragList<String>(
  items: _myItems,
  enabled: true,
  onReorder: (oldIndex, newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex -= 1;
      final item = _myItems.removeAt(oldIndex);
      _myItems.insert(newIndex, item);
    });
  },
  itemBuilder: (context, item, index) {
    return Text(item);
  },
  getKey: (item) => item,
)
```

---

## 🎨 Características

### 1. **Genérico**
Funciona com qualquer tipo de dado:
- `ReorderableDragList<String>`
- `ReorderableDragList<Map<String, dynamic>>`
- `ReorderableDragList<CatalogItem>`
- `ReorderableDragList<MyCustomClass>`

### 2. **Customizável**
```dart
ReorderableDragList<T>(
  // ... parâmetros obrigatórios
  dragHandleIcon: Icons.menu,           // Ícone customizado
  dragHandleSize: 20,                   // Tamanho customizado
  dragHandleColor: Colors.blue,         // Cor customizada
  dragHandlePadding: EdgeInsets.all(8), // Padding customizado
  emptyWidget: MyEmptyWidget(),         // Widget quando vazio
)
```

### 3. **Duas Variantes**

#### Com Drag Handle (padrão)
```dart
ReorderableDragList<T>(...)
```
Exibe um ícone de drag handle ao lado de cada item.

#### Item Inteiro Arrastável
```dart
ReorderableDragListFullItem<T>(...)
```
O item inteiro é arrastável (sem handle separado).

### 4. **Controle de Estado**
```dart
ReorderableDragList<T>(
  enabled: _isEditing, // Habilita/desabilita drag dinamicamente
  // ...
)
```

---

## 📚 Documentação Completa

### Guias Disponíveis:

1. **[REORDERABLE_DRAG_LIST_GUIDE.md](REORDERABLE_DRAG_LIST_GUIDE.md)**
   - Guia completo de uso
   - Todos os parâmetros explicados
   - Exemplos práticos
   - Troubleshooting

2. **[REORDERABLE_MIGRATION_EXAMPLE.md](REORDERABLE_MIGRATION_EXAMPLE.md)**
   - Exemplos de migração do código existente
   - Comparação antes/depois
   - Checklist de migração

3. **[reorderable_drag_list_demo.dart](../lib/widgets/reorderable_drag_list_demo.dart)**
   - Página de demonstração interativa
   - Exemplos visuais
   - Testes práticos

---

## 🔄 Onde Pode Ser Usado

### Usos Atuais no Projeto:
1. ✅ **Catalog Page** - Reordenar produtos em pacotes
2. ✅ **Project Form** - Reordenar itens do catálogo
3. ✅ **Quick Forms** - Reordenar itens do catálogo
4. ✅ **Projects Page** - Reordenar itens do catálogo
5. ✅ **Custom Briefing Editor** - Reordenar blocos de texto

### Usos Futuros Possíveis:
- ⏳ Reordenar tarefas em um projeto
- ⏳ Reordenar arquivos/assets
- ⏳ Reordenar etapas de um workflow
- ⏳ Reordenar campos de formulário
- ⏳ Qualquer lista que precise de reordenação!

---

## 💡 Exemplos Rápidos

### Exemplo 1: Lista Simples
```dart
List<String> _items = ['A', 'B', 'C'];

ReorderableDragList<String>(
  items: _items,
  enabled: true,
  onReorder: (old, new) {
    setState(() {
      if (new > old) new -= 1;
      final item = _items.removeAt(old);
      _items.insert(new, item);
    });
  },
  itemBuilder: (ctx, item, idx) => Text(item),
  getKey: (item) => item,
)
```

### Exemplo 2: Lista de Objetos
```dart
class Product {
  final String id;
  final String name;
  Product(this.id, this.name);
}

List<Product> _products = [...];

ReorderableDragList<Product>(
  items: _products,
  enabled: true,
  onReorder: (old, new) {
    setState(() {
      if (new > old) new -= 1;
      final item = _products.removeAt(old);
      _products.insert(new, item);
    });
  },
  itemBuilder: (ctx, product, idx) {
    return ListTile(title: Text(product.name));
  },
  getKey: (product) => product.id,
  emptyWidget: Text('Nenhum produto'),
)
```

### Exemplo 3: Customizado
```dart
ReorderableDragList<MyItem>(
  items: _items,
  enabled: _isEditing,
  dragHandleIcon: Icons.drag_handle_rounded,
  dragHandleSize: 18,
  dragHandleColor: Theme.of(context).primaryColor,
  onReorder: _handleReorder,
  itemBuilder: _buildItem,
  getKey: (item) => item.id,
  emptyWidget: EmptyStateWidget(),
)
```

---

## 🎓 Como Testar

### Opção 1: Página de Demo
Execute a página de demonstração para ver exemplos interativos:

```dart
// Navegue para a página de demo
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (_) => ReorderableDragListDemo(),
  ),
);
```

### Opção 2: Integração Direta
Substitua um uso existente de `ReorderableListView.builder` pelo novo componente e teste.

---

## 📊 Comparação de Código

### Antes (Código Duplicado)
```dart
// ~45 linhas de código
ReorderableListView.builder(
  shrinkWrap: true,
  buildDefaultDragHandles: false,
  physics: const NeverScrollableScrollPhysics(),
  itemCount: items.length,
  onReorder: (oldIndex, newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex -= 1;
      final item = items.removeAt(oldIndex);
      items.insert(newIndex, item);
    });
  },
  itemBuilder: (context, i) {
    final item = items[i];
    return Container(
      key: ValueKey(item.id),
      child: Row(
        children: [
          ReorderableDragStartListener(
            index: i,
            child: Icon(Icons.drag_indicator),
          ),
          Expanded(child: Text(item.name)),
        ],
      ),
    );
  },
)
```

### Depois (Usando Componente)
```dart
// ~15 linhas de código
ReorderableDragList<Item>(
  items: items,
  enabled: true,
  onReorder: (old, new) {
    setState(() {
      if (new > old) new -= 1;
      final item = items.removeAt(old);
      items.insert(new, item);
    });
  },
  itemBuilder: (ctx, item, idx) => Text(item.name),
  getKey: (item) => item.id,
)
```

**Redução: ~67% menos código!** 🎉

---

## ✅ Benefícios

1. **Menos Código** - 30-70% menos linhas
2. **Mais Legível** - Intenção clara
3. **Consistente** - Mesmo comportamento em todo lugar
4. **Manutenível** - Mudanças em um lugar
5. **Documentado** - Guias completos
6. **Testável** - Componente isolado
7. **Reutilizável** - Use em qualquer lugar
8. **Customizável** - Adapte às suas necessidades

---

## 🔧 Manutenção

### Adicionar Nova Funcionalidade
Edite apenas `lib/widgets/reorderable_drag_list.dart` e todos os usos se beneficiam automaticamente.

### Corrigir Bug
Corrija em um lugar, funciona em todos os lugares.

### Atualizar Estilo
Mude o estilo padrão do drag handle em um lugar.

---

## 📝 Próximos Passos (Opcional)

1. ✅ **Componente criado e documentado**
2. ⏳ **Migrar código existente** (opcional, não obrigatório)
3. ⏳ **Adicionar testes unitários** (futuro)
4. ⏳ **Adicionar animações customizadas** (futuro)
5. ⏳ **Adicionar suporte a gestos adicionais** (futuro)

---

## 🤝 Como Contribuir

Se você encontrar um caso de uso que o componente não cobre:

1. Abra uma issue descrevendo o caso
2. Sugira melhorias
3. Adicione novos parâmetros opcionais
4. Atualize a documentação

---

## 📞 Suporte

- **Documentação**: Veja os guias em `docs/`
- **Exemplos**: Veja `reorderable_drag_list_demo.dart`
- **Código**: Veja `reorderable_drag_list.dart`

---

## 🎉 Conclusão

O `ReorderableDragList` é um componente **pronto para uso** que:
- ✅ Simplifica a implementação de drag and drop
- ✅ Padroniza o comportamento em todo o projeto
- ✅ Reduz código duplicado
- ✅ Facilita manutenção futura

**Use-o sempre que precisar de uma lista reordenável!** 🚀

