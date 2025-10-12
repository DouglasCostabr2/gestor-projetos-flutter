# GenericCheckbox em Tabelas - Exemplo

## ✅ Você PODE usar GenericCheckbox em tabelas!

Basta usar **sem label** e com padding mínimo:

```dart
// Checkbox de header (selecionar todos)
TableCell(
  child: Container(
    height: 56,
    alignment: Alignment.center,
    child: GenericCheckbox(
      value: _selectAll,
      onChanged: (v) {
        if (v == true) {
          // Selecionar todos
        } else {
          // Desselecionar todos
        }
      },
      tristate: true,
      // SEM LABEL! ← Importante
    ),
  ),
)

// Checkbox de linha
TableCell(
  child: Container(
    height: 52,
    alignment: Alignment.center,
    child: GenericCheckbox(
      value: isSelected,
      onChanged: (v) {
        // Toggle seleção
      },
      // SEM LABEL! ← Importante
    ),
  ),
)
```

## 🎯 Vantagens de Usar GenericCheckbox na Tabela

1. **Consistência visual** - Mesmo estilo em todo o app
2. **Validação** - Se precisar validar seleção
3. **Cores customizadas** - Fácil de personalizar
4. **Tristate integrado** - Já tem suporte

## ⚠️ Desvantagens

1. **Overhead desnecessário** - InkWell e Row extras quando não tem label
2. **Mais código** - `Checkbox` nativo é mais direto
3. **Performance** - Widgets extras (mínimo, mas existe)

## 🤔 Recomendação

**Para tabelas simples de seleção:**
- Use `Checkbox` nativo (mais leve e direto)

**Para tabelas com validação ou estilo customizado:**
- Use `GenericCheckbox` sem label

**Para formulários:**
- Use `GenericCheckbox` com label (ideal!)

## 📝 Exemplo Completo: Migração do ReusableDataTable

Se você quiser migrar o `ReusableDataTable` para usar `GenericCheckbox`:

```dart
// ANTES (Checkbox nativo)
TableCell(
  child: Container(
    height: 56,
    alignment: Alignment.center,
    child: Checkbox(
      tristate: true,
      value: widget.selectedIds.isEmpty
          ? false
          : (widget.selectedIds.length == _sortedItems.length ? true : null),
      onChanged: widget.onSelectionChanged == null ? null : (v) {
        if (v == true) {
          widget.onSelectionChanged!(_sortedItems.map(widget.getId).toSet());
        } else {
          widget.onSelectionChanged!({});
        }
      },
    ),
  ),
)

// DEPOIS (GenericCheckbox)
TableCell(
  child: Container(
    height: 56,
    alignment: Alignment.center,
    child: GenericCheckbox(
      value: widget.selectedIds.isEmpty
          ? false
          : (widget.selectedIds.length == _sortedItems.length ? true : null),
      onChanged: widget.onSelectionChanged == null ? null : (v) {
        if (v == true) {
          widget.onSelectionChanged!(_sortedItems.map(widget.getId).toSet());
        } else {
          widget.onSelectionChanged!({});
        }
      },
      tristate: true,
      // Sem label!
    ),
  ),
)
```

## ✅ Conclusão

**Você PODE usar `GenericCheckbox` em tabelas**, mas:

- ✅ **Recomendado:** Formulários com label
- ⚠️ **Opcional:** Tabelas sem label (funciona, mas `Checkbox` nativo é mais direto)
- ❌ **Não recomendado:** Tabelas com label (fica estranho visualmente)

**Decisão final:** Depende do seu caso de uso!

- Se quer **consistência total** → Use `GenericCheckbox` em tudo
- Se quer **performance e simplicidade** → Use `Checkbox` nativo em tabelas, `GenericCheckbox` em formulários

