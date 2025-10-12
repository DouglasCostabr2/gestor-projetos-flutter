# DynamicPaginatedTable - Componente Genérico de Tabela com Paginação Dinâmica

## Descrição

`DynamicPaginatedTable` é um componente genérico reutilizável que encapsula toda a lógica de paginação dinâmica baseada na altura disponível da tela.

### Características:

✅ **Paginação Dinâmica**: Calcula automaticamente quantos itens cabem na tela baseado na altura disponível  
✅ **Gerenciamento Interno**: Gerencia a paginação internamente (não precisa de variáveis de estado externas)  
✅ **Controles de Paginação**: Exibe controles de navegação com informações de itens exibidos  
✅ **Integração com ReusableDataTable**: Usa o componente de tabela existente  
✅ **Genérico**: Funciona com qualquer tipo de dado (`<T>`)  
✅ **Estados de UI**: Suporta loading, erro e vazio  
✅ **Ordenação**: Suporta ordenação de colunas  
✅ **Seleção**: Suporta seleção múltipla de itens  
✅ **Ações**: Suporta ações por linha  

---

## Como Usar

### 1. Estrutura Básica

```dart
import '../../widgets/dynamic_paginated_table.dart';

// No build do seu widget:
Expanded(
  child: DynamicPaginatedTable<Map<String, dynamic>>(
    items: _filteredData,
    itemLabel: 'projeto(s)', // ou 'cliente(s)', 'tarefa(s)', etc.
    columns: const [
      DataTableColumn(label: 'Nome', sortable: true),
      DataTableColumn(label: 'Email', sortable: true),
    ],
    cellBuilders: [
      (item) => Text(item['name'] ?? ''),
      (item) => Text(item['email'] ?? ''),
    ],
    getId: (item) => item['id'] as String,
  ),
)
```

### 2. Com Seleção

```dart
DynamicPaginatedTable<Map<String, dynamic>>(
  items: _filteredData,
  itemLabel: 'cliente(s)',
  selectedIds: _selected,
  onSelectionChanged: (ids) => setState(() => _selected
    ..clear()
    ..addAll(ids)),
  // ... resto da configuração
)
```

### 3. Com Ordenação

```dart
DynamicPaginatedTable<Map<String, dynamic>>(
  items: _filteredData,
  itemLabel: 'tarefa(s)',
  onSort: (columnIndex, ascending) {
    setState(() {
      _sortColumnIndex = columnIndex;
      _sortAscending = ascending;
      _applySorting(); // Sua função de ordenação
    });
  },
  externalSortColumnIndex: _sortColumnIndex,
  externalSortAscending: _sortAscending,
  sortComparators: [
    (a, b) => (a['name'] ?? '').toString().compareTo(b['name'] ?? ''),
    (a, b) => (a['email'] ?? '').toString().compareTo(b['email'] ?? ''),
  ],
  // ... resto da configuração
)
```

### 4. Com Ações

```dart
DynamicPaginatedTable<Map<String, dynamic>>(
  items: _filteredData,
  itemLabel: 'usuário(s)',
  actions: [
    DataTableAction<Map<String, dynamic>>(
      icon: Icons.edit,
      label: 'Editar',
      onPressed: (item) => _editItem(item),
      showWhen: (item) => appState.isAdmin,
    ),
    DataTableAction<Map<String, dynamic>>(
      icon: Icons.delete,
      label: 'Excluir',
      onPressed: (item) => _deleteItem(item),
      showWhen: (item) => appState.isAdmin,
    ),
  ],
  // ... resto da configuração
)
```

### 5. Com Estados de UI

```dart
DynamicPaginatedTable<Map<String, dynamic>>(
  items: _filteredData,
  itemLabel: 'produto(s)',
  isLoading: _loading,
  hasError: _error != null,
  errorWidget: Center(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Text('Erro ao carregar dados:\n\n${_error ?? ""}'),
    ),
  ),
  emptyWidget: const Center(child: Text('Nenhum item encontrado')),
  // ... resto da configuração
)
```

### 6. Com Clique na Linha

```dart
DynamicPaginatedTable<Map<String, dynamic>>(
  items: _filteredData,
  itemLabel: 'pedido(s)',
  onRowTap: (item) {
    // Navegar para detalhes, abrir modal, etc.
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ItemDetailPage(itemId: item['id'] as String),
      ),
    );
  },
  // ... resto da configuração
)
```

---

## Parâmetros

### Obrigatórios

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `items` | `List<T>` | Lista completa de itens a serem exibidos |
| `columns` | `List<DataTableColumn>` | Colunas da tabela |
| `cellBuilders` | `List<Widget Function(T)>` | Construtores de células para cada coluna |
| `getId` | `String Function(T)` | Função para obter o ID único de cada item |
| `itemLabel` | `String` | Label para o tipo de item (ex: 'projeto(s)', 'cliente(s)') |

### Opcionais

| Parâmetro | Tipo | Padrão | Descrição |
|-----------|------|--------|-----------|
| `selectedIds` | `Set<String>` | `{}` | IDs dos itens selecionados |
| `onSelectionChanged` | `void Function(Set<String>)?` | `null` | Callback quando a seleção muda |
| `onRowTap` | `void Function(T)?` | `null` | Callback quando uma linha é clicada |
| `actions` | `List<DataTableAction<T>>?` | `null` | Ações disponíveis para cada item |
| `externalSortColumnIndex` | `int?` | `null` | Índice da coluna de ordenação (controle externo) |
| `externalSortAscending` | `bool` | `true` | Direção da ordenação (controle externo) |
| `onSort` | `void Function(int, bool)?` | `null` | Callback quando a ordenação muda |
| `sortComparators` | `List<int Function(T, T)>?` | `null` | Comparadores de ordenação para cada coluna |
| `loadingWidget` | `Widget?` | `CircularProgressIndicator` | Widget a ser exibido quando está carregando |
| `emptyWidget` | `Widget?` | `Text('Nenhum item encontrado')` | Widget a ser exibido quando não há itens |
| `errorWidget` | `Widget?` | `Text('Erro ao carregar dados')` | Widget a ser exibido quando há erro |
| `isLoading` | `bool` | `false` | Se está carregando |
| `hasError` | `bool` | `false` | Se há erro |

---

## Exemplo Completo (Projetos)

```dart
Expanded(
  child: DynamicPaginatedTable<Map<String, dynamic>>(
    items: _filteredData,
    itemLabel: 'projeto(s)',
    selectedIds: _selected,
    onSelectionChanged: (ids) => setState(() => _selected
      ..clear()
      ..addAll(ids)),
    columns: const [
      DataTableColumn(label: 'Nome', sortable: true),
      DataTableColumn(label: 'Cliente', sortable: true),
      DataTableColumn(label: 'Valor', sortable: true),
      DataTableColumn(label: 'Status', sortable: true),
      DataTableColumn(label: 'Criado em', sortable: true),
    ],
    onSort: (columnIndex, ascending) {
      setState(() {
        _sortColumnIndex = columnIndex;
        _sortAscending = ascending;
        _applySorting();
      });
    },
    externalSortColumnIndex: _sortColumnIndex,
    externalSortAscending: _sortAscending,
    sortComparators: [
      (a, b) => (a['name'] ?? '').toString().toLowerCase()
          .compareTo((b['name'] ?? '').toString().toLowerCase()),
      (a, b) => (a['clients']?['name'] ?? '').toString().toLowerCase()
          .compareTo((b['clients']?['name'] ?? '').toString().toLowerCase()),
      (a, b) {
        final valueA = a['value'] as num? ?? 0;
        final valueB = b['value'] as num? ?? 0;
        return valueA.compareTo(valueB);
      },
      (a, b) => (a['status'] ?? '').toString()
          .compareTo((b['status'] ?? '').toString()),
      (a, b) {
        final dateA = a['created_at'] != null ? DateTime.tryParse(a['created_at']) : null;
        final dateB = b['created_at'] != null ? DateTime.tryParse(b['created_at']) : null;
        if (dateA == null && dateB == null) return 0;
        if (dateA == null) return 1;
        if (dateB == null) return -1;
        return dateA.compareTo(dateB);
      },
    ],
    cellBuilders: [
      (p) => Text(p['name'] ?? ''),
      (p) => Text(p['clients']?['name'] ?? '-'),
      (p) {
        final value = p['value'] as num? ?? 0;
        if (value == 0) return const Text('-');
        return Text('R\$ ${value.toStringAsFixed(2)}');
      },
      (p) => ProjectStatusBadge(status: p['status'] ?? 'not_started'),
      (p) {
        final date = p['created_at'] != null
            ? DateTime.tryParse(p['created_at'])
            : null;
        if (date == null) return const Text('-');
        return Text('${date.day}/${date.month}/${date.year}');
      },
    ],
    getId: (p) => p['id'] as String,
    onRowTap: (p) {
      // Navegar para detalhes do projeto
    },
    actions: [
      DataTableAction<Map<String, dynamic>>(
        icon: Icons.edit,
        label: 'Editar',
        onPressed: (p) => _openForm(initial: p),
        showWhen: (p) => appState.isAdmin || appState.isDesigner,
      ),
      DataTableAction<Map<String, dynamic>>(
        icon: Icons.delete,
        label: 'Excluir',
        onPressed: (p) => _deleteProject(p),
        showWhen: (p) => appState.isAdmin || appState.isDesigner,
      ),
    ],
    isLoading: _loading,
    hasError: _error != null,
    errorWidget: Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text('Erro ao carregar projetos:\n\n${_error ?? ""}'),
      ),
    ),
    emptyWidget: const Center(child: Text('Nenhum projeto encontrado')),
  ),
)
```

---

## Notas Importantes

1. **Expanded é necessário**: O componente precisa estar dentro de um `Expanded` ou ter uma altura definida, pois usa `LayoutBuilder` internamente.

2. **Cálculo Automático**: O componente calcula automaticamente quantos itens cabem na tela. Não é necessário gerenciar `_currentPage` ou `_itemsPerPage` externamente.

3. **Ordenação Externa**: Se você quiser controlar a ordenação externamente (para aplicar filtros, por exemplo), use `externalSortColumnIndex` e `externalSortAscending`.

4. **Performance**: O componente é otimizado para grandes listas, pois só renderiza os itens da página atual.

5. **Responsivo**: A paginação se ajusta automaticamente quando a janela é redimensionada.

6. **Reset Automático**: Quando a lista de itens muda (ex: filtro aplicado), a página é automaticamente resetada para a primeira.

7. **Validação**: O componente valida que o número de `cellBuilders` é igual ao número de `columns` em tempo de compilação.

8. **Callback de Página**: Use `onPageChanged` para rastrear mudanças de página (útil para analytics ou logging).

---

## Configuração Avançada

### Constantes de Altura

O componente usa as seguintes constantes para calcular a altura disponível:

```dart
const double _kTableHeaderHeight = 56.0;  // Altura do cabeçalho da tabela
const double _kTableRowHeight = 48.0;     // Altura de cada linha de dados
const double _kPaginationHeight = 80.0;   // Altura dos controles de paginação
const double _kSpacingBetweenTableAndPagination = 24.0;  // Espaçamento
const double _kExtraMargin = 20.0;        // Margem extra de segurança
const int _kMinItemsPerPage = 5;          // Mínimo de itens por página
```

**Fórmula de Cálculo:**
```dart
availableHeight = constraints.maxHeight - (spacing + pagination + margin)
itemsPerPage = max((availableHeight - headerHeight) / rowHeight, minItems)
```

Se você precisar ajustar esses valores, edite as constantes no arquivo `dynamic_paginated_table.dart`.

---

## Migração de Código Existente

### Antes (código manual):

```dart
// Variáveis de estado
int _currentPage = 0;
int _itemsPerPage = 5;

// Métodos auxiliares
List<T> _getPaginatedItems() { ... }
int get _totalPages { ... }
Widget _buildPaginationControls() { ... }

// Build
LayoutBuilder(
  builder: (context, constraints) {
    final availableHeight = constraints.maxHeight - 285;
    // ... cálculo de itemsPerPage
    // ... SizedBox com ReusableDataTable
    // ... _buildPaginationControls()
  }
)
```

### Depois (usando DynamicPaginatedTable):

```dart
// Sem variáveis de paginação!
// Sem métodos auxiliares!

// Build
Expanded(
  child: DynamicPaginatedTable<T>(
    items: _filteredData,
    itemLabel: 'item(s)',
    // ... configuração
  ),
)
```

**Benefícios:**
- ✅ Menos código
- ✅ Menos bugs
- ✅ Mais reutilizável
- ✅ Mais fácil de manter
- ✅ Comportamento consistente em todas as páginas

