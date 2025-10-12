# Componentes Dropdown Genéricos

Este módulo fornece componentes dropdown reutilizáveis e type-safe para uso em todo o projeto.

## 📦 Componentes Disponíveis

### 1. GenericDropdownField<T>
Dropdown simples com lista estática de opções.

**Quando usar:**
- Lista fixa de opções conhecidas em tempo de compilação
- Status, prioridades, tipos predefinidos
- Não precisa de busca/filtro

**Características:**
- ✅ Type-safe com generics
- ✅ Suporta valores nullable
- ✅ Validação customizável
- ✅ Validação assíncrona (onBeforeChanged)
- ✅ Widgets customizados nos itens
- ✅ Auto-reset em caso de validação falhar

### 2. SearchableDropdownField<T>
Dropdown com busca integrada (Material 3 DropdownMenu).

**Quando usar:**
- Muitas opções (>10 itens)
- Usuário precisa buscar/filtrar
- Categorias, países, cidades, etc.

**Características:**
- ✅ Busca e filtro integrados
- ✅ Largura responsiva automática
- ✅ Loading state
- ✅ Controller opcional
- ✅ Material 3 design

### 3. AsyncDropdownField<T>
Dropdown que carrega dados assincronamente do servidor.

**Quando usar:**
- Dados vêm de API/banco de dados
- Lista depende de outros valores (cascata)
- Precisa recarregar dados dinamicamente

**Características:**
- ✅ Carregamento assíncrono
- ✅ Loading state automático
- ✅ Tratamento de erros
- ✅ Botão de retry
- ✅ Recarregamento automático por dependências
- ✅ Callback de erro

---

## 🚀 Exemplos de Uso

### GenericDropdownField - Básico

```dart
import 'package:gestor_projetos_flutter/widgets/dropdowns/dropdowns.dart';

GenericDropdownField<String>(
  value: _status,
  items: [
    DropdownItem(value: 'active', label: 'Ativo'),
    DropdownItem(value: 'inactive', label: 'Inativo'),
    DropdownItem(value: 'pending', label: 'Pendente'),
  ],
  onChanged: (value) => setState(() => _status = value),
  labelText: 'Status',
  enabled: !_saving,
)
```

### GenericDropdownField - Com Validação

```dart
GenericDropdownField<String>(
  value: _priority,
  items: [
    DropdownItem(value: 'low', label: 'Baixa'),
    DropdownItem(value: 'medium', label: 'Média'),
    DropdownItem(value: 'high', label: 'Alta'),
  ],
  onChanged: (value) => setState(() => _priority = value),
  labelText: 'Prioridade *',
  validator: (value) => value == null ? 'Selecione uma prioridade' : null,
)
```

### GenericDropdownField - Nullable com Widget Customizado

```dart
GenericDropdownField<String?>(
  value: _assigneeId,
  items: [
    DropdownItem(value: null, label: 'Não atribuído'),
    ...users.map((user) => DropdownItem(
      value: user['id'],
      label: user['name'],
      customWidget: UserDropdownItem(
        avatarUrl: user['avatar_url'],
        name: user['name'],
      ),
    )),
  ],
  onChanged: (value) => setState(() => _assigneeId = value),
  labelText: 'Responsável',
)
```

### GenericDropdownField - Com Validação Assíncrona

```dart
GenericDropdownField<String>(
  value: _taskStatus,
  items: [
    DropdownItem(value: 'todo', label: 'A Fazer'),
    DropdownItem(value: 'in_progress', label: 'Em Andamento'),
    DropdownItem(value: 'completed', label: 'Concluída'),
  ],
  onChanged: (value) => setState(() => _taskStatus = value),
  labelText: 'Status',
  onBeforeChanged: (newValue) async {
    // Validar se pode concluir a task
    if (newValue == 'completed' && _taskId != null) {
      return await tasksModule.canCompleteTask(_taskId!);
    }
    return true;
  },
  validationErrorMessage: 'Não é possível concluir. Todas as sub tarefas devem estar concluídas.',
)
```

### SearchableDropdownField - Básico

```dart
SearchableDropdownField<String>(
  value: _categoryId,
  items: _categories.map((cat) => SearchableDropdownItem(
    value: cat['id'] as String,
    label: cat['name'] as String,
  )).toList(),
  onChanged: (value) => setState(() => _categoryId = value),
  labelText: 'Categoria',
  hintText: 'Digite para buscar...',
  isLoading: _loadingCategories,
  enabled: !_loadingCategories,
)
```

### SearchableDropdownField - Com Busca Customizada

```dart
SearchableDropdownField<String>(
  value: _userId,
  items: _users.map((user) => SearchableDropdownItem(
    value: user['id'] as String,
    label: user['name'] as String,
    searchableText: '${user['name']} ${user['email']}', // Busca por nome ou email
  )).toList(),
  onChanged: (value) => setState(() => _userId = value),
  labelText: 'Usuário',
)
```

### AsyncDropdownField - Básico

```dart
AsyncDropdownField<String>(
  value: _clientId,
  loadItems: () async {
    final response = await supabase.from('clients').select();
    return response.map((item) => DropdownItem(
      value: item['id'] as String,
      label: item['name'] as String,
    )).toList();
  },
  onChanged: (value) => setState(() => _clientId = value),
  labelText: 'Cliente',
  emptyMessage: 'Nenhum cliente cadastrado',
)
```

### AsyncDropdownField - Com Dependências (Cascata)

```dart
// Dropdown de empresas que depende do cliente selecionado
AsyncDropdownField<String>(
  value: _companyId,
  loadItems: () async {
    if (_clientId == null) return [];
    
    final response = await supabase
      .from('companies')
      .select()
      .eq('client_id', _clientId!);
      
    return response.map((item) => DropdownItem(
      value: item['id'] as String,
      label: item['name'] as String,
    )).toList();
  },
  onChanged: (value) => setState(() => _companyId = value),
  labelText: 'Empresa',
  dependencies: [_clientId], // Recarrega quando _clientId muda
  enabled: _clientId != null,
  emptyMessage: 'Selecione um cliente primeiro',
)
```

### AsyncDropdownField - Com Tratamento de Erro

```dart
AsyncDropdownField<String>(
  value: _productId,
  loadItems: () async {
    final response = await supabase.from('products').select();
    return response.map((item) => DropdownItem(
      value: item['id'] as String,
      label: item['name'] as String,
    )).toList();
  },
  onChanged: (value) => setState(() => _productId = value),
  labelText: 'Produto',
  errorMessage: 'Erro ao carregar produtos',
  showRetryButton: true,
  onError: (error) {
    print('Erro ao carregar produtos: $error');
  },
)
```

---

## 🔄 Guia de Migração

### Migrar DropdownButtonFormField → GenericDropdownField

**Antes:**
```dart
DropdownButtonFormField<String>(
  initialValue: _status,
  items: const [
    DropdownMenuItem(value: 'todo', child: Text('A Fazer')),
    DropdownMenuItem(value: 'in_progress', child: Text('Em Andamento')),
    DropdownMenuItem(value: 'completed', child: Text('Concluída')),
  ],
  onChanged: (v) => setState(() => _status = v ?? 'todo'),
  decoration: const InputDecoration(labelText: 'Status'),
)
```

**Depois:**
```dart
GenericDropdownField<String>(
  value: _status,
  items: const [
    DropdownItem(value: 'todo', label: 'A Fazer'),
    DropdownItem(value: 'in_progress', label: 'Em Andamento'),
    DropdownItem(value: 'completed', label: 'Concluída'),
  ],
  onChanged: (v) => setState(() => _status = v ?? 'todo'),
  labelText: 'Status',
)
```

### Migrar DropdownMenu → SearchableDropdownField

**Antes:**
```dart
LayoutBuilder(
  builder: (context, constraints) {
    return DropdownMenu<String>(
      controller: _categoryController,
      initialSelection: _selectedCategoryId,
      label: const Text('Categoria'),
      hintText: _loadingCategories ? 'Carregando...' : 'Digite para buscar...',
      enableFilter: true,
      enableSearch: true,
      enabled: !_loadingCategories,
      width: constraints.maxWidth,
      dropdownMenuEntries: _categories.map((category) {
        return DropdownMenuEntry<String>(
          value: category['id'] as String,
          label: category['name'] as String,
        );
      }).toList(),
      onSelected: (value) => setState(() => _selectedCategoryId = value),
    );
  },
)
```

**Depois:**
```dart
SearchableDropdownField<String>(
  value: _selectedCategoryId,
  items: _categories.map((category) => SearchableDropdownItem(
    value: category['id'] as String,
    label: category['name'] as String,
  )).toList(),
  onChanged: (value) => setState(() => _selectedCategoryId = value),
  labelText: 'Categoria',
  isLoading: _loadingCategories,
)
```

---

## 📋 API Reference

### DropdownItem<T>
```dart
class DropdownItem<T> {
  final T value;              // Valor do item
  final String label;         // Texto exibido
  final Widget? customWidget; // Widget customizado (opcional)
}
```

### SearchableDropdownItem<T>
```dart
class SearchableDropdownItem<T> {
  final T value;              // Valor do item
  final String label;         // Texto exibido
  final String? searchableText; // Texto adicional para busca
}
```

---

## ✅ Benefícios

1. **Menos código duplicado** - Escreva uma vez, use em qualquer lugar
2. **Type-safe** - Erros de tipo detectados em tempo de compilação
3. **Consistência** - Comportamento uniforme em todo o app
4. **Manutenibilidade** - Mudanças em um lugar afetam todos os usos
5. **Documentação** - Exemplos claros e bem documentados
6. **Flexibilidade** - Customizável mas com defaults sensatos

