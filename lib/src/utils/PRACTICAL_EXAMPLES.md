# Exemplos Práticos de Uso dos Utilitários de Tabela

Este documento contém exemplos práticos e casos de uso reais dos utilitários de tabela.

---

## 📋 Índice

1. [Busca Avançada](#busca-avançada)
2. [Filtros Complexos](#filtros-complexos)
3. [Ordenação Customizada](#ordenação-customizada)
4. [Seleção e Ações em Lote](#seleção-e-ações-em-lote)
5. [Integração Completa](#integração-completa)

---

## 🔍 Busca Avançada

### Exemplo 1: Busca em Múltiplos Campos

```dart
// Buscar em nome, email e telefone
final results = items.where((item) => 
  TableUtils.searchInFields(
    item,
    query: searchQuery,
    fields: ['name', 'email', 'phone'],
  )
).toList();
```

### Exemplo 2: Busca em Campos Aninhados

```dart
// Buscar em projeto e cliente
final results = items.where((item) => 
  TableUtils.searchInFields(
    item,
    query: searchQuery,
    fields: [
      'name',                    // Nome do projeto
      'description',             // Descrição do projeto
      'clients.name',            // Nome do cliente
      'clients.company',         // Empresa do cliente
      'owner.username',          // Nome do responsável
    ],
  )
).toList();
```

### Exemplo 3: Busca Case-Sensitive

```dart
// Busca exata (case-sensitive)
final results = items.where((item) => 
  TableUtils.searchInFields(
    item,
    query: 'ACME Corp',
    fields: ['clients.company'],
    caseSensitive: true,
  )
).toList();
```

---

## 🎯 Filtros Complexos

### Exemplo 1: Filtro por Status

```dart
@override
bool applyCustomFilter(Map<String, dynamic> item) {
  if (filterType == 'status' && filterValue != null) {
    return item['status'] == filterValue;
  }
  return true;
}
```

### Exemplo 2: Filtro por Faixa de Valores

```dart
@override
bool applyCustomFilter(Map<String, dynamic> item) {
  if (filterType == 'value' && filterValue != null) {
    final value = item['value'] as num?;
    if (value == null) return false;

    switch (filterValue) {
      case 'low':
        return TableUtils.filterByNumericRange(item, 'value', max: 1000);
      case 'medium':
        return TableUtils.filterByNumericRange(item, 'value', min: 1001, max: 10000);
      case 'high':
        return TableUtils.filterByNumericRange(item, 'value', min: 10001, max: 50000);
      case 'very_high':
        return TableUtils.filterByNumericRange(item, 'value', min: 50001);
      default:
        return true;
    }
  }
  return true;
}
```

### Exemplo 3: Filtro por Data

```dart
@override
bool applyCustomFilter(Map<String, dynamic> item) {
  if (filterType == 'date' && filterValue != null) {
    final now = DateTime.now();
    
    switch (filterValue) {
      case 'today':
        final today = DateTime(now.year, now.month, now.day);
        final tomorrow = today.add(const Duration(days: 1));
        return TableUtils.filterByDateRange(
          item,
          'created_at',
          start: today,
          end: tomorrow,
        );
      
      case 'this_week':
        final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
        return TableUtils.filterByDateRange(
          item,
          'created_at',
          start: startOfWeek,
        );
      
      case 'this_month':
        final startOfMonth = DateTime(now.year, now.month, 1);
        return TableUtils.filterByDateRange(
          item,
          'created_at',
          start: startOfMonth,
        );
      
      default:
        return true;
    }
  }
  return true;
}
```

### Exemplo 4: Filtros Compostos

```dart
@override
bool applyCustomFilter(Map<String, dynamic> item) {
  // Aplicar múltiplos filtros ao mesmo tempo
  
  // Filtro de status
  if (filterType == 'status' && filterValue != null) {
    if (item['status'] != filterValue) return false;
  }
  
  // Filtro de cliente
  if (_selectedClientId != null) {
    if (item['client_id'] != _selectedClientId) return false;
  }
  
  // Filtro de valor mínimo
  if (_minValue != null) {
    final value = item['value'] as num?;
    if (value == null || value < _minValue!) return false;
  }
  
  // Filtro de data
  if (_startDate != null) {
    if (!TableUtils.filterByDateRange(
      item,
      'created_at',
      start: _startDate,
    )) return false;
  }
  
  return true;
}
```

---

## 📊 Ordenação Customizada

### Exemplo 1: Ordenação Básica

```dart
@override
List<int Function(Map<String, dynamic>, Map<String, dynamic>)> get sortComparators => [
  TableUtils.textComparator('name'),
  TableUtils.textComparator('email'),
  TableUtils.numericComparator('value'),
  TableUtils.dateComparator('created_at'),
];
```

### Exemplo 2: Ordenação com Campos Aninhados

```dart
@override
List<int Function(Map<String, dynamic>, Map<String, dynamic>)> get sortComparators => [
  TableUtils.textComparator('name'),
  TableUtils.textComparator('clients.name'),        // Cliente
  TableUtils.textComparator('owner.username'),      // Responsável
  TableUtils.numericComparator('value'),
  TableUtils.dateComparator('created_at'),
];
```

### Exemplo 3: Ordenação Customizada

```dart
@override
List<int Function(Map<String, dynamic>, Map<String, dynamic>)> get sortComparators => [
  // Ordenação por nome
  TableUtils.textComparator('name'),
  
  // Ordenação customizada por prioridade
  (a, b) {
    const priorities = {'high': 0, 'medium': 1, 'low': 2};
    final priorityA = priorities[a['priority']] ?? 999;
    final priorityB = priorities[b['priority']] ?? 999;
    return priorityA.compareTo(priorityB);
  },
  
  // Ordenação por status (ordem específica)
  (a, b) {
    const statusOrder = {
      'in_progress': 0,
      'pending': 1,
      'completed': 2,
      'cancelled': 3,
    };
    final orderA = statusOrder[a['status']] ?? 999;
    final orderB = statusOrder[b['status']] ?? 999;
    return orderA.compareTo(orderB);
  },
  
  // Ordenação numérica
  TableUtils.numericComparator('value'),
];
```

---

## ✅ Seleção e Ações em Lote

### Exemplo 1: Selecionar Todos

```dart
FilledButton.icon(
  onPressed: () {
    selectAll();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${selectedIds.length} itens selecionados')),
    );
  },
  icon: const Icon(Icons.select_all),
  label: const Text('Selecionar Todos'),
)
```

### Exemplo 2: Limpar Seleção

```dart
TextButton.icon(
  onPressed: selectedIds.isEmpty ? null : () {
    clearSelection();
  },
  icon: const Icon(Icons.clear),
  label: const Text('Limpar Seleção'),
)
```

### Exemplo 3: Excluir Selecionados

```dart
Future<void> _deleteSelected() async {
  final items = getSelectedItems();
  
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Confirmar Exclusão'),
      content: Text('Deseja excluir ${items.length} item(ns)?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Excluir'),
        ),
      ],
    ),
  );
  
  if (confirmed != true) return;
  
  try {
    for (final item in items) {
      await supabaseModule.client
          .from('projects')
          .delete()
          .eq('id', item['id']);
    }
    
    clearSelection();
    await reloadData();
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${items.length} item(ns) excluído(s)')),
      );
    }
  } catch (e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao excluir: $e')),
      );
    }
  }
}
```

### Exemplo 4: Atualizar Status em Lote

```dart
Future<void> _updateStatusBulk(String newStatus) async {
  final items = getSelectedItems();
  
  try {
    for (final item in items) {
      await supabaseModule.client
          .from('projects')
          .update({'status': newStatus})
          .eq('id', item['id']);
    }
    
    clearSelection();
    await reloadData();
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Status de ${items.length} item(ns) atualizado'),
        ),
      );
    }
  } catch (e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao atualizar: $e')),
      );
    }
  }
}
```

---

## 🔗 Integração Completa

### Exemplo: Página Completa com Todos os Recursos

```dart
class _MyPageState extends State<MyPage> 
    with TableStateMixin<Map<String, dynamic>> {
  
  @override
  void initState() {
    super.initState();
    loadData();
  }

  // ========== IMPLEMENTAÇÃO DO MIXIN ==========
  
  @override
  Future<List<Map<String, dynamic>>> fetchData() async {
    final response = await supabaseModule.client
        .from('my_table')
        .select('*, related_table(*)')
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(response);
  }

  @override
  List<String> get searchFields => [
    'name',
    'description',
    'related_table.name',
  ];

  @override
  List<int Function(Map<String, dynamic>, Map<String, dynamic>)> get sortComparators => [
    TableUtils.textComparator('name'),
    TableUtils.textComparator('related_table.name'),
    TableUtils.numericComparator('value'),
    TableUtils.dateComparator('created_at'),
  ];

  @override
  bool applyCustomFilter(Map<String, dynamic> item) {
    if (filterType == 'status' && filterValue != null) {
      return item['status'] == filterValue;
    }
    return true;
  }

  @override
  void onDataLoaded() {
    print('✅ Dados carregados: ${allData.length} itens');
  }

  @override
  void onDataError(String error) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Erro: $error')),
    );
  }

  // ========== UI ==========
  
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Header
        _buildHeader(),
        const Divider(height: 1),
        
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Busca e filtros
                TableSearchFilterBar(
                  searchHint: 'Buscar...',
                  onSearchChanged: updateSearchQuery,
                  filterType: filterType,
                  filterTypeOptions: const [
                    FilterOption(value: 'none', label: 'Nenhum'),
                    FilterOption(value: 'status', label: 'Status'),
                  ],
                  onFilterTypeChanged: (v) => updateFilterType(v ?? 'none'),
                  filterValue: filterValue,
                  filterValueOptions: ['active', 'inactive'],
                  onFilterValueChanged: updateFilterValue,
                  selectedCount: selectedIds.length,
                  bulkActions: [
                    BulkAction(
                      icon: Icons.delete,
                      label: 'Excluir',
                      color: Colors.red,
                      onPressed: _deleteSelected,
                    ),
                  ],
                ),
                
                const SizedBox(height: 16),
                
                // Tabela
                Expanded(
                  child: DynamicPaginatedTable<Map<String, dynamic>>(
                    items: filteredData,
                    itemLabel: 'item(ns)',
                    selectedIds: selectedIds,
                    onSelectionChanged: updateSelection,
                    columns: const [
                      DataTableColumn(label: 'Nome', sortable: true),
                      DataTableColumn(label: 'Valor', sortable: true),
                      DataTableColumn(label: 'Data', sortable: true),
                    ],
                    cellBuilders: [
                      (item) => Text(item['name'] ?? ''),
                      (item) => Text('R\$ ${item['value'] ?? 0}'),
                      (item) {
                        final date = DateTime.tryParse(item['created_at'] ?? '');
                        return Text(date != null 
                          ? '${date.day}/${date.month}/${date.year}'
                          : '-'
                        );
                      },
                    ],
                    getId: (item) => item['id'] as String,
                    onSort: updateSorting,
                    externalSortColumnIndex: sortColumnIndex,
                    externalSortAscending: sortAscending,
                    sortComparators: sortComparators,
                    isLoading: isLoading,
                    hasError: errorMessage != null,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
```

---

## 🎯 Dicas e Truques

### 1. Performance com Grandes Listas

```dart
// Use debounce para busca
Timer? _debounce;

void _onSearchChanged(String query) {
  _debounce?.cancel();
  _debounce = Timer(const Duration(milliseconds: 300), () {
    updateSearchQuery(query);
  });
}
```

### 2. Filtros Salvos

```dart
// Salvar filtros no SharedPreferences
Future<void> _saveFilters() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('filter_type', filterType);
  await prefs.setString('filter_value', filterValue ?? '');
}

Future<void> _loadFilters() async {
  final prefs = await SharedPreferences.getInstance();
  final type = prefs.getString('filter_type') ?? 'none';
  final value = prefs.getString('filter_value');
  
  updateFilterType(type);
  if (value != null && value.isNotEmpty) {
    updateFilterValue(value);
  }
}
```

### 3. Exportar Dados Filtrados

```dart
Future<void> _exportToCSV() async {
  final csv = const ListToCsvConverter().convert([
    ['Nome', 'Valor', 'Data'], // Header
    ...filteredData.map((item) => [
      item['name'],
      item['value'],
      item['created_at'],
    ]),
  ]);
  
  // Salvar arquivo...
}
```

---

**Mais exemplos e casos de uso serão adicionados conforme necessário.**

