# Exemplo de Migração - ReorderableDragList

Este documento mostra exemplos práticos de como migrar código existente para usar o novo componente `ReorderableDragList`.

---

## Exemplo 1: Catalog Page - Lista de Produtos em Pacotes

### ❌ ANTES (Código Original)

```dart
// lib/src/features/catalog/catalog_page.dart (linhas 920-970)

ConstrainedBox(
  constraints: const BoxConstraints(),
  child: pkgItems.isEmpty
    ? const Center(child: Text('Nenhum produto adicionado'))
    : ReorderableListView.builder(
        buildDefaultDragHandles: false,
        physics: const NeverScrollableScrollPhysics(),
        shrinkWrap: true,
        itemCount: pkgItems.length,
        onReorder: (oldIndex, newIndex) {
          setState(() {
            if (newIndex > oldIndex) newIndex -= 1;
            final item = pkgItems.removeAt(oldIndex);
            pkgItems.insert(newIndex, item);
          });
        },
        itemBuilder: (context, i) {
          final it = pkgItems[i];
          final pid = (it['product_id'] ?? '').toString();
          final prod = _products.firstWhere(
            (p) => (p['id'] ?? '').toString() == pid, 
            orElse: () => {}
          );
          final prodName = (prod['name'] ?? pid) as String;
          final pm = (prod['price_map'] as Map?)?.cast<String, dynamic>();
          final centsBRL = pm?['BRL'] as int? ?? (prod['price_cents'] as int? ?? 0);
          final qty = 1;
          final unitFmt = 'BRL ${_fmt(centsBRL)}';
          final totalFmt = 'BRL ${_fmt(centsBRL * qty)}';
          
          return ListTile(
            key: ValueKey('${pid}_$i'),
            dense: true,
            leading: Row(
              mainAxisSize: MainAxisSize.min, 
              children: [
                ReorderableDragStartListener(
                  index: i, 
                  child: const Icon(Icons.drag_indicator)
                ),
                const SizedBox(width: 6),
                _productLeadingThumb(prod),
              ]
            ),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start, 
              children: [
                Row(children: [
                  Expanded(child: Text(prodName)),
                ]),
                if (AppStateScope.of(context).isAdminOrGestor || 
                    AppStateScope.of(context).isFinanceiro) 
                  Text('Unit: $unitFmt • Total: $totalFmt'),
                // ... mais conteúdo
              ]
            ),
            // ... mais propriedades
          );
        },
      ),
)
```

### ✅ DEPOIS (Usando ReorderableDragList)

```dart
// lib/src/features/catalog/catalog_page.dart

import 'package:gestor_projetos_flutter/widgets/reorderable_drag_list.dart';

// ...

ReorderableDragList<Map<String, dynamic>>(
  items: pkgItems,
  enabled: true,
  onReorder: (oldIndex, newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex -= 1;
      final item = pkgItems.removeAt(oldIndex);
      pkgItems.insert(newIndex, item);
    });
  },
  itemBuilder: (context, item, index) {
    final pid = (item['product_id'] ?? '').toString();
    final prod = _products.firstWhere(
      (p) => (p['id'] ?? '').toString() == pid, 
      orElse: () => {}
    );
    final prodName = (prod['name'] ?? pid) as String;
    final pm = (prod['price_map'] as Map?)?.cast<String, dynamic>();
    final centsBRL = pm?['BRL'] as int? ?? (prod['price_cents'] as int? ?? 0);
    final qty = 1;
    final unitFmt = 'BRL ${_fmt(centsBRL)}';
    final totalFmt = 'BRL ${_fmt(centsBRL * qty)}';
    
    return ListTile(
      dense: true,
      leading: _productLeadingThumb(prod),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start, 
        children: [
          Row(children: [
            Expanded(child: Text(prodName)),
          ]),
          if (AppStateScope.of(context).isAdminOrGestor || 
              AppStateScope.of(context).isFinanceiro) 
            Text('Unit: $unitFmt • Total: $totalFmt'),
          // ... mais conteúdo
        ]
      ),
      // ... mais propriedades
    );
  },
  getKey: (item) => '${item['product_id']}_${pkgItems.indexOf(item)}',
  emptyWidget: const Center(child: Text('Nenhum produto adicionado')),
)
```

**Mudanças:**
- ✅ Removido `ReorderableListView.builder` manual
- ✅ Removido `buildDefaultDragHandles: false`
- ✅ Removido `ReorderableDragStartListener` manual
- ✅ Removido `key: ValueKey(...)` do ListTile (agora gerenciado pelo componente)
- ✅ Removido verificação `pkgItems.isEmpty` (agora usa `emptyWidget`)
- ✅ Drag handle agora é automático e consistente

---

## Exemplo 2: Quick Forms - Lista de Itens do Catálogo

### ❌ ANTES

```dart
// lib/src/features/shared/quick_forms.dart (linhas 451-490)

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
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(children: [
        ReorderableDragStartListener(
          index: i, 
          child: const Padding(
            padding: EdgeInsets.only(right: 8), 
            child: Icon(Icons.drag_indicator)
          )
        ),
        Expanded(
          flex: 3,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(it.name, style: Theme.of(context).textTheme.bodyLarge),
              const SizedBox(height: 4),
              Text(
                it.itemType == 'product' ? 'Produto' : 'Pacote', 
                style: Theme.of(context).textTheme.bodySmall
              ),
            ],
          ),
        ),
        // ... mais conteúdo
      ]),
    );
  },
)
```

### ✅ DEPOIS

```dart
// lib/src/features/shared/quick_forms.dart

import 'package:gestor_projetos_flutter/widgets/reorderable_drag_list.dart';

// ...

ReorderableDragList<CatalogItemSelection>(
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
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(children: [
        Expanded(
          flex: 3,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(item.name, style: Theme.of(context).textTheme.bodyLarge),
              const SizedBox(height: 4),
              Text(
                item.itemType == 'product' ? 'Produto' : 'Pacote', 
                style: Theme.of(context).textTheme.bodySmall
              ),
            ],
          ),
        ),
        // ... mais conteúdo
      ]),
    );
  },
  getKey: (item) => item.uniqueId,
)
```

**Mudanças:**
- ✅ Código mais limpo e legível
- ✅ Drag handle automático
- ✅ Menos boilerplate
- ✅ Tipo genérico `CatalogItemSelection` explícito

---

## Exemplo 3: Custom Briefing Editor - Blocos de Texto

### ❌ ANTES

```dart
// lib/widgets/custom_briefing_editor.dart (linhas 386-405)

ReorderableListView.builder(
  shrinkWrap: true,
  physics: const NeverScrollableScrollPhysics(),
  padding: const EdgeInsets.only(bottom: 8),
  itemCount: _blocks.length,
  buildDefaultDragHandles: false,
  onReorder: widget.enabled ? _reorderBlocks : (oldIndex, newIndex) {},
  itemBuilder: (context, index) {
    final block = _blocks[index];
    return _BlockWidget(
      key: ValueKey('block_${block.hashCode}_$index'),
      block: block,
      enabled: widget.enabled,
      index: index,
      onChanged: (updated) => _updateBlock(index, updated),
      onRemove: () => _removeBlock(index),
      onToggleCheckbox: () => _toggleCheckbox(index),
    );
  },
)
```

### ✅ DEPOIS

```dart
// lib/widgets/custom_briefing_editor.dart

import 'package:gestor_projetos_flutter/widgets/reorderable_drag_list.dart';

// ...

ReorderableDragList<EditorBlock>(
  items: _blocks,
  enabled: widget.enabled,
  padding: const EdgeInsets.only(bottom: 8),
  onReorder: _reorderBlocks,
  itemBuilder: (context, block, index) {
    return _BlockWidget(
      block: block,
      enabled: widget.enabled,
      index: index,
      onChanged: (updated) => _updateBlock(index, updated),
      onRemove: () => _removeBlock(index),
      onToggleCheckbox: () => _toggleCheckbox(index),
    );
  },
  getKey: (block) => 'block_${block.hashCode}',
)
```

**Mudanças:**
- ✅ Removido callback condicional `widget.enabled ? _reorderBlocks : (oldIndex, newIndex) {}`
- ✅ Agora usa `enabled: widget.enabled` diretamente
- ✅ Key gerenciada pelo componente
- ✅ Mais simples e direto

---

## Checklist de Migração

Ao migrar código existente, siga este checklist:

- [ ] Importar `reorderable_drag_list.dart`
- [ ] Substituir `ReorderableListView.builder` por `ReorderableDragList<T>`
- [ ] Definir o tipo genérico `<T>` apropriado
- [ ] Mover `items` para o parâmetro `items:`
- [ ] Mover `onReorder` para o parâmetro `onReorder:`
- [ ] Converter `itemBuilder` para receber `(context, item, index)`
- [ ] Adicionar função `getKey:` para gerar keys únicas
- [ ] Remover `buildDefaultDragHandles: false`
- [ ] Remover `ReorderableDragStartListener` manual do itemBuilder
- [ ] Remover `key: ValueKey(...)` dos items (agora automático)
- [ ] Mover verificação de lista vazia para `emptyWidget:` (opcional)
- [ ] Testar a funcionalidade de drag and drop

---

## Benefícios da Migração

1. **Menos Código**: ~30-40% menos linhas de código
2. **Mais Legível**: Intenção clara e direta
3. **Consistente**: Mesmo comportamento em todo o projeto
4. **Manutenível**: Mudanças em um lugar afetam todos os usos
5. **Testável**: Componente isolado pode ser testado separadamente
6. **Documentado**: Guia completo de uso disponível

---

## Próximos Passos

1. ✅ Componente criado
2. ✅ Documentação completa
3. ⏳ Migrar código existente (opcional)
4. ⏳ Adicionar testes unitários (futuro)
5. ⏳ Adicionar mais customizações conforme necessário (futuro)

