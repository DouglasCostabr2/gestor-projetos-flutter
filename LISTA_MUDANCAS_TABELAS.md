# 📋 Lista Completa de Mudanças para Aplicar em Todas as Páginas com Tabelas

**Data**: 2025-10-10  
**Baseado em**: Implementação da página de detalhes de empresa (`company_detail_page.dart`)

---

## 🎯 RESUMO DAS MUDANÇAS

Todas as páginas com tabelas precisam implementar:

1. ✅ **Scroll na página** - `SingleChildScrollView` ao redor do conteúdo
2. ✅ **Altura fixa para tabela** - `SizedBox(height: 600)` para área da tabela
3. ✅ **Paginação fixa** - 5 itens por página com controles de navegação
4. ✅ **Filtros aplicados a TODOS os itens** - Não apenas à página atual
5. ✅ **Ordenação externa** - Aplicada aos itens filtrados antes da paginação
6. ✅ **Ações em lote** - Excluir múltiplos itens selecionados
7. ✅ **Design consistente** - Cores #1E1E1E e #3E3E3E para botões de ação

---

## 📊 STATUS DE CADA ENTIDADE

### **Projetos** (Projects)
```dart
import 'package:gestor_projetos_flutter/constants/project_status.dart';

// Valores: not_started, negotiation, in_progress, paused, completed, cancelled
ProjectStatus.values // Lista completa
ProjectStatus.getLabel(status) // Label em português
```

### **Tarefas** (Tasks)
```dart
import 'package:gestor_projetos_flutter/constants/task_status.dart';

// Valores: todo, in_progress, review, waiting, completed, cancelled
TaskStatus.values // Lista completa
TaskStatus.getLabel(status) // Label em português
```

### **Clientes** (Clients)
```dart
import 'package:gestor_projetos_flutter/constants/client_status.dart';

// Valores: active, inactive
ClientStatus.values // Lista completa
ClientStatus.getLabel(status) // Label em português
```

### **Empresas** (Companies)
```dart
import 'package:gestor_projetos_flutter/constants/company_status.dart';

// Valores: active, inactive
CompanyStatus.values // Lista completa
CompanyStatus.getLabel(status) // Label em português
```

---

## 🔧 ESTRUTURA COMPLETA A IMPLEMENTAR

### **1. ESTRUTURA DA PÁGINA**

```dart
@override
Widget build(BuildContext context) {
  final appState = AppStateScope.of(context);
  
  return Material(
    type: MaterialType.transparency,
    child: SingleChildScrollView( // ← SCROLL NA PÁGINA
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header da página
            Row(
              children: [
                Text('Título', style: Theme.of(context).textTheme.headlineSmall),
                const Spacer(),
                // Botões de ação (se necessário)
              ],
            ),
            const SizedBox(height: 16),
            
            // Área da tabela com altura fixa
            SizedBox(
              height: 600, // ← ALTURA FIXA
              child: Column(
                children: [
                  // Barra de busca e filtros
                  TableSearchFilterBar(...),
                  
                  // Loading/Empty/Tabela
                  if (_loading)
                    const SizedBox(
                      height: 200,
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (_filteredData.isEmpty)
                    const SizedBox(
                      height: 200,
                      child: Center(child: Text('Nenhum item encontrado')),
                    )
                  else ...[
                    // Tabela
                    ReusableDataTable(...),
                    
                    // Controles de paginação
                    const SizedBox(height: 16),
                    _buildPaginationControls(),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
```

---

### **2. VARIÁVEIS DE ESTADO**

```dart
class _PageState extends State<Page> {
  // Dados
  bool _loading = true;
  List<Map<String, dynamic>> _data = [];
  List<Map<String, dynamic>> _filteredData = [];
  
  // Seleção
  final Set<String> _selected = {};
  
  // Paginação
  int _currentPage = 0;
  final int _itemsPerPage = 5;
  
  // Ordenação
  int? _sortColumnIndex = 0; // Inicializar com primeira coluna
  bool _sortAscending = true;
  
  // Filtros
  String _searchQuery = '';
  String _filterType = 'none';
  String? _filterValue;
  
  // Outros dados necessários (ex: lista de usuários para filtros)
  List<Map<String, dynamic>> _allUsers = [];
  
  @override
  void initState() {
    super.initState();
    _loadData();
  }
  
  // ... resto do código
}
```

---

### **3. FUNÇÕES NECESSÁRIAS**

#### **A. Carregar Dados**
```dart
Future<void> _loadData() async {
  setState(() => _loading = true);
  
  try {
    final response = await Supabase.instance.client
        .from('table_name')
        .select('*')
        .order('created_at', ascending: false);
    
    if (!mounted) return;
    
    setState(() {
      _data = List<Map<String, dynamic>>.from(response);
      _applyFilters();
      _loading = false;
    });
  } catch (e) {
    if (!mounted) return;
    setState(() => _loading = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Erro ao carregar dados: $e')),
    );
  }
}

void _reload() {
  _loadData();
}
```

#### **B. Aplicar Filtros (a TODOS os itens)**
```dart
void _applyFilters() {
  setState(() {
    var filtered = List<Map<String, dynamic>>.from(_data);
    
    // 1. Busca por texto
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtered = filtered.where((item) {
        // Adaptar campos de busca para cada entidade
        final name = (item['name'] ?? '').toString().toLowerCase();
        final email = (item['email'] ?? '').toString().toLowerCase();
        return name.contains(query) || email.contains(query);
      }).toList();
    }
    
    // 2. Filtros específicos
    if (_filterType != 'none' && _filterValue != null) {
      switch (_filterType) {
        case 'status':
          filtered = filtered.where((item) => item['status'] == _filterValue).toList();
          break;
        // Adicionar outros tipos de filtro conforme necessário
      }
    }
    
    _filteredData = filtered;
    _applySorting();
    _currentPage = 0; // Resetar para primeira página
  });
}
```

#### **C. Aplicar Ordenação (aos itens filtrados)**
```dart
void _applySorting() {
  if (_sortColumnIndex == null) return;
  
  final comparators = _getSortComparators();
  if (_sortColumnIndex! >= comparators.length) return;
  
  final comparator = comparators[_sortColumnIndex!];
  if (comparator == null) return;
  
  _filteredData.sort((a, b) {
    final result = comparator(a, b);
    return _sortAscending ? result : -result;
  });
}

// Definir comparadores para cada coluna
List<int Function(Map<String, dynamic>, Map<String, dynamic>)?> _getSortComparators() {
  return [
    // Exemplo: ordenar por nome
    (a, b) => (a['name'] ?? '').toString().toLowerCase()
        .compareTo((b['name'] ?? '').toString().toLowerCase()),
    
    // Exemplo: ordenar por data
    (a, b) {
      final dateA = a['created_at'] != null ? DateTime.tryParse(a['created_at']) : null;
      final dateB = b['created_at'] != null ? DateTime.tryParse(b['created_at']) : null;
      if (dateA == null && dateB == null) return 0;
      if (dateA == null) return 1;
      if (dateB == null) return -1;
      return dateA.compareTo(dateB);
    },
    
    // null para colunas não ordenáveis
    null,
  ];
}
```

#### **D. Paginação**
```dart
// Obter itens da página atual
List<Map<String, dynamic>> _getPaginatedItems() {
  final startIndex = _currentPage * _itemsPerPage;
  final endIndex = startIndex + _itemsPerPage;
  
  if (startIndex >= _filteredData.length) {
    return [];
  }
  
  return _filteredData.sublist(
    startIndex,
    endIndex > _filteredData.length ? _filteredData.length : endIndex,
  );
}

// Calcular total de páginas
int get _totalPages {
  if (_filteredData.isEmpty) return 1;
  return (_filteredData.length / _itemsPerPage).ceil();
}
```

#### **E. Exclusão em Lote**
```dart
Future<void> _bulkDelete() async {
  final count = _selected.length;
  
  final confirm = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Confirmar exclusão'),
      content: Text('Deseja realmente excluir $count ${count > 1 ? 'itens' : 'item'}?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          style: FilledButton.styleFrom(
            backgroundColor: Colors.red,
          ),
          child: const Text('Excluir'),
        ),
      ],
    ),
  );
  
  if (confirm == true) {
    try {
      // Excluir todos os itens selecionados
      for (final id in _selected) {
        await Supabase.instance.client
            .from('table_name')
            .delete()
            .eq('id', id);
      }
      
      if (!mounted) return;
      
      // Limpar seleção
      setState(() => _selected.clear());
      
      // Recarregar dados
      _reload();
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$count ${count > 1 ? 'itens excluídos' : 'item excluído'} com sucesso'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao excluir: $e')),
      );
    }
  }
}
```

---

### **4. WIDGET DE PAGINAÇÃO**

```dart
Widget _buildPaginationControls() {
  return Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      // Primeira página
      IconButton(
        icon: const Icon(Icons.first_page),
        onPressed: _currentPage > 0
            ? () => setState(() => _currentPage = 0)
            : null,
        tooltip: 'Primeira página',
      ),
      
      // Página anterior
      IconButton(
        icon: const Icon(Icons.chevron_left),
        onPressed: _currentPage > 0
            ? () => setState(() => _currentPage--)
            : null,
        tooltip: 'Página anterior',
      ),
      
      // Indicador de página
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Text(
          'Página ${_currentPage + 1} de $_totalPages',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ),
      
      // Próxima página
      IconButton(
        icon: const Icon(Icons.chevron_right),
        onPressed: _currentPage < _totalPages - 1
            ? () => setState(() => _currentPage++)
            : null,
        tooltip: 'Próxima página',
      ),
      
      // Última página
      IconButton(
        icon: const Icon(Icons.last_page),
        onPressed: _currentPage < _totalPages - 1
            ? () => setState(() => _currentPage = _totalPages - 1)
            : null,
        tooltip: 'Última página',
      ),
      
      const SizedBox(width: 16),
      
      // Total de itens
      Text(
        'Total: ${_filteredData.length} ${_filteredData.length == 1 ? 'item' : 'itens'}',
        style: Theme.of(context).textTheme.bodySmall,
      ),
    ],
  );
}
```

---

### **5. TABLE SEARCH FILTER BAR**

```dart
TableSearchFilterBar(
  searchHint: 'Buscar... (adaptar para cada entidade)',
  onSearchChanged: (value) {
    _searchQuery = value;
    _applyFilters();
  },
  filterType: _filterType,
  filterTypeLabel: 'Tipo de filtro',
  filterTypeOptions: const [
    FilterOption(value: 'none', label: 'Nenhum'),
    FilterOption(value: 'status', label: 'Status'),
    // Adicionar outros filtros conforme necessário
  ],
  onFilterTypeChanged: (value) {
    if (value != null) {
      setState(() {
        _filterType = value;
        _filterValue = null;
      });
      _applyFilters();
    }
  },
  filterValue: _filterValue,
  filterValueLabel: _getFilterLabel(),
  filterValueOptions: _getFilterOptions(),
  filterValueLabelBuilder: _getFilterValueLabel,
  onFilterValueChanged: (value) {
    setState(() => _filterValue = value?.isEmpty == true ? null : value);
    _applyFilters();
  },
  selectedCount: _selected.length, // ← NOVO
  bulkActions: appState.isAdminOrGestor ? [ // ← NOVO
    BulkAction(
      icon: Icons.delete,
      label: 'Excluir selecionados',
      color: Colors.red,
      onPressed: _bulkDelete,
    ),
  ] : null,
  actionButton: appState.isAdminOrGestor ? FilledButton.icon(
    onPressed: _openNewDialog,
    icon: const Icon(Icons.add),
    label: const Text('Novo Item'),
  ) : null,
),
```

---

### **6. REUSABLE DATA TABLE**

```dart
ReusableDataTable<Map<String, dynamic>>(
  items: _getPaginatedItems(), // ← Apenas itens da página atual
  selectedIds: _selected, // ← NOVO
  onSelectionChanged: (ids) => setState(() => _selected
    ..clear()
    ..addAll(ids)), // ← NOVO
  columns: const [
    DataTableColumn(label: 'Nome', sortable: true),
    DataTableColumn(label: 'Email', sortable: true),
    // ... outras colunas
  ],
  // Controle externo de ordenação ← NOVO
  onSort: (columnIndex, ascending) {
    setState(() {
      _sortColumnIndex = columnIndex;
      _sortAscending = ascending;
      _applySorting();
      _currentPage = 0; // Resetar para primeira página
    });
  },
  externalSortColumnIndex: _sortColumnIndex, // ← NOVO
  externalSortAscending: _sortAscending, // ← NOVO
  sortComparators: _getSortComparators(),
  cellBuilders: [
    (item) => Text(item['name'] ?? ''),
    (item) => Text(item['email'] ?? '-'),
    // ... outros builders
  ],
  getId: (item) => item['id'] as String,
  onRowTap: (item) {
    // Navegar para detalhes
  },
  actions: appState.isAdminOrGestor ? [
    DataTableAction(
      icon: Icons.edit,
      tooltip: 'Editar',
      onPressed: (item) => _openEditDialog(item),
    ),
    DataTableAction(
      icon: Icons.delete,
      tooltip: 'Excluir',
      onPressed: (item) => _deleteItem(item),
    ),
  ] : null,
),
```

---

## 📋 PÁGINAS QUE PRECISAM SER ATUALIZADAS

### ✅ **1. Projetos** (`projects_page.dart`)
- Status: `ProjectStatus.values`
- Filtros: status, cliente, valor, pessoa
- Tabela: nome, cliente, valor, status, datas

### ✅ **2. Clientes** (`clients_page.dart`)
- Status: `ClientStatus.values`
- Filtros: país, estado, cidade, categoria
- Tabela: nome, email, telefone, empresa, categoria

### ✅ **3. Tarefas** (`tasks_page.dart`)
- Status: `TaskStatus.values`
- Filtros: status, prioridade, projeto
- Tabela: título, projeto, status, prioridade, responsável

### ✅ **4. Empresas** (`companies_page.dart`)
- Status: `CompanyStatus.values`
- Filtros: rede social
- Tabela: nome, cliente, website, projetos

### ✅ **5. Detalhes do Projeto - Tarefas** (`project_detail_page.dart`)
- Status: `TaskStatus.values`
- Filtros: status, prioridade, responsável
- Tabela: título, status, prioridade, responsável
- **TAMBÉM PARA SUBTAREFAS**

### ✅ **6. Categorias de Clientes** (`client_categories_page.dart`)
- Sem status
- Sem filtros adicionais (apenas busca)
- Tabela: nome, descrição, total de clientes

---

## ⚠️ PONTOS DE ATENÇÃO

1. **Status diferentes por entidade** - Usar as constantes corretas
2. **Filtros específicos** - Cada página tem filtros diferentes
3. **Permissões** - Verificar `appState.isAdminOrGestor` para ações
4. **Campos de busca** - Adaptar para cada entidade
5. **Comparadores de ordenação** - Adaptar para cada coluna
6. **Mensagens de confirmação** - Adaptar texto para cada entidade

---

## 🎯 CHECKLIST POR PÁGINA

Para cada página, verificar:

- [ ] `SingleChildScrollView` ao redor do conteúdo
- [ ] `SizedBox(height: 600)` para área da tabela
- [ ] Variáveis de estado: `_selected`, `_currentPage`, `_sortColumnIndex`, etc.
- [ ] Função `_applyFilters()` aplicada a TODOS os itens
- [ ] Função `_applySorting()` aplicada aos itens filtrados
- [ ] Função `_getPaginatedItems()` retorna apenas 5 itens
- [ ] Função `_bulkDelete()` implementada
- [ ] Widget `_buildPaginationControls()` implementado
- [ ] `TableSearchFilterBar` com `selectedCount` e `bulkActions`
- [ ] `ReusableDataTable` com `onSort`, `externalSortColumnIndex`, `externalSortAscending`
- [ ] `ReusableDataTable` com `selectedIds` e `onSelectionChanged`
- [ ] Usar constantes de status corretas (ProjectStatus, TaskStatus, etc.)
- [ ] Testar filtros, ordenação, paginação e exclusão em lote

---

**Pronto para aplicar as mudanças?**

