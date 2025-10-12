# Implementação de Paginação - Guia Completo

## ✅ Já Implementado

1. **PaginationController** (`lib/core/pagination/pagination_controller.dart`)
   - Controller genérico para gerenciar paginação
   - Suporta carregar primeira página, próxima página, reload
   - Gerencia estado de loading, erro e hasMore

## 📋 Próximos Passos

### 1. Atualizar Repositórios para Suportar Paginação

#### TasksRepository
```dart
// Em lib/modules/tasks/repository.dart
@override
Future<List<Map<String, dynamic>>> getTasks({
  String? projectId,
  int? offset,
  int? limit,
}) async {
  var query = _client
      .from('tasks')
      .select('''
        *,
        projects:project_id(name, client_id),
        creator_profile:created_by(full_name, avatar_url),
        assignee_profile:assigned_to(full_name, avatar_url)
      ''');

  if (projectId != null) {
    query = query.eq('project_id', projectId);
  }

  // PAGINAÇÃO
  if (offset != null && limit != null) {
    query = query.range(offset, offset + limit - 1);
  }

  final response = await query.order('created_at', ascending: false);
  return response.map<Map<String, dynamic>>((task) => {...}).toList();
}
```

#### ProjectsRepository
```dart
// Em lib/modules/projects/repository.dart
@override
Future<List<Map<String, dynamic>>> getProjects({
  int? offset,
  int? limit,
}) async {
  var query = _client
      .from('projects')
      .select('''
        *,
        profiles:owner_id(full_name, avatar_url),
        clients:client_id(name, company, email)
      ''');

  // PAGINAÇÃO
  if (offset != null && limit != null) {
    query = query.range(offset, offset + limit - 1);
  }

  final response = await query.order('created_at', ascending: false);
  return List<Map<String, dynamic>>.from(response);
}
```

#### ClientsRepository
```dart
// Em lib/modules/clients/repository.dart
@override
Future<List<Map<String, dynamic>>> getClients({
  int? offset,
  int? limit,
}) async {
  var query = _client
      .from('clients')
      .select('*, client_categories(*)');

  // PAGINAÇÃO
  if (offset != null && limit != null) {
    query = query.range(offset, offset + limit - 1);
  }

  final response = await query.order('created_at', ascending: false);
  return List<Map<String, dynamic>>.from(response);
}
```

### 2. Atualizar Páginas para Usar Paginação

#### TasksPage
```dart
// Em lib/src/features/tasks/tasks_page.dart

class _TasksPageState extends State<TasksPage> with RouteAware {
  late PaginationController<Map<String, dynamic>> _paginationController;
  List<Map<String, dynamic>> _filteredData = [];
  
  @override
  void initState() {
    super.initState();
    
    _paginationController = PaginationController(
      pageSize: 50, // Carregar 50 tarefas por vez
      onLoadPage: (offset, limit) async {
        return await tasksModule.getTasks(
          offset: offset,
          limit: limit,
        );
      },
    );
    
    _paginationController.addListener(_onDataChanged);
  }
  
  void _onDataChanged() {
    setState(() {
      _applyFilters();
    });
  }
  
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_depsInitialized) {
      _depsInitialized = true;
      _paginationController.loadFirstPage();
      // ... resto do código
    }
  }
  
  void _applyFilters() {
    final allData = _paginationController.items;
    // Aplicar filtros em allData
    // ...
  }
  
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ... header e filtros
        
        Expanded(
          child: AnimatedBuilder(
            animation: _paginationController,
            builder: (context, _) {
              if (_paginationController.isLoading && _paginationController.items.isEmpty) {
                return const Center(child: CircularProgressIndicator());
              }
              
              if (_paginationController.error != null) {
                return Center(child: Text('Erro: ${_paginationController.error}'));
              }
              
              return Column(
                children: [
                  Expanded(
                    child: ReusableDataTable<Map<String, dynamic>>(
                      items: _filteredData,
                      // ... resto da configuração
                    ),
                  ),
                  
                  // Botão "Carregar Mais"
                  if (_paginationController.hasMore)
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: FilledButton.icon(
                        onPressed: _paginationController.isLoading
                            ? null
                            : () => _paginationController.loadNextPage(),
                        icon: _paginationController.isLoading
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.expand_more),
                        label: Text(_paginationController.isLoading
                            ? 'Carregando...'
                            : 'Carregar Mais'),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
  
  @override
  void dispose() {
    _paginationController.removeListener(_onDataChanged);
    _paginationController.dispose();
    super.dispose();
  }
}
```

### 3. Implementar Scroll Infinito (Opcional)

Para uma experiência ainda melhor, pode-se implementar scroll infinito:

```dart
// Usar NotificationListener para detectar scroll
NotificationListener<ScrollNotification>(
  onNotification: (ScrollNotification scrollInfo) {
    if (scrollInfo.metrics.pixels >= scrollInfo.metrics.maxScrollExtent * 0.8) {
      // Quando chegar a 80% do scroll, carregar próxima página
      if (_paginationController.hasMore && !_paginationController.isLoading) {
        _paginationController.loadNextPage();
      }
    }
    return false;
  },
  child: ReusableDataTable(...),
)
```

## 📊 Benefícios Esperados

- **Carregamento Inicial**: De ~2-3s para ~0.5s (com 50 itens vs 1000+)
- **Uso de Memória**: Redução de ~70% (apenas itens visíveis + próxima página)
- **Responsividade**: UI não trava durante carregamento
- **Escalabilidade**: Suporta milhares de registros sem degradação

## 🎯 Prioridade de Implementação

1. **Alta**: TasksPage (geralmente tem mais registros)
2. **Média**: ProjectsPage
3. **Baixa**: ClientsPage (geralmente menos registros)

## ⚠️ Considerações

- Filtros locais devem ser aplicados apenas nos itens carregados
- Para busca global, considerar implementar busca no servidor
- Manter indicador visual de "carregando mais" para UX

