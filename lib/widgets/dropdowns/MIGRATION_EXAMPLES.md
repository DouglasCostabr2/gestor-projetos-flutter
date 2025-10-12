# Exemplos Práticos de Migração

Este documento mostra exemplos reais de como migrar código existente do projeto para usar os novos componentes dropdown genéricos.

## 📝 Índice
1. [Migrar TaskStatusField](#1-migrar-taskstatusfield)
2. [Migrar TaskPriorityField](#2-migrar-taskpriorityfield)
3. [Migrar ProjectStatusField](#3-migrar-projectstatusfield)
4. [Migrar Categoria em ClientForm](#4-migrar-categoria-em-clientform)
5. [Migrar Cliente/Empresa em ProjectForm](#5-migrar-clienteempresa-em-projectform)
6. [Migrar TaskAssigneeField](#6-migrar-taskassigneefield)

---

## 1. Migrar TaskStatusField

### ❌ Código Atual (task_status_field.dart)

```dart
class TaskStatusField extends StatefulWidget {
  final String status;
  final String? taskId;
  final ValueChanged<String> onStatusChanged;
  final bool enabled;

  const TaskStatusField({
    super.key,
    required this.status,
    this.taskId,
    required this.onStatusChanged,
    this.enabled = true,
  });

  @override
  State<TaskStatusField> createState() => _TaskStatusFieldState();
}

class _TaskStatusFieldState extends State<TaskStatusField> {
  String? _currentValue;

  @override
  void initState() {
    super.initState();
    _currentValue = widget.status;
  }

  @override
  void didUpdateWidget(TaskStatusField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.status != widget.status) {
      _currentValue = widget.status;
    }
  }

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      key: ValueKey(_currentValue),
      initialValue: _currentValue,
      items: const [
        DropdownMenuItem(value: 'todo', child: Text('A Fazer')),
        DropdownMenuItem(value: 'in_progress', child: Text('Em Andamento')),
        DropdownMenuItem(value: 'review', child: Text('Revisão')),
        DropdownMenuItem(value: 'waiting', child: Text('Aguardando')),
        DropdownMenuItem(value: 'completed', child: Text('Concluída')),
      ],
      onChanged: widget.enabled
          ? (v) async {
              if (v == null) return;

              // Validar se pode concluir a task
              if (v == 'completed' && widget.taskId != null) {
                final messenger = ScaffoldMessenger.of(context);
                final canComplete = await tasksModule.canCompleteTask(widget.taskId!);
                if (!canComplete) {
                  if (!mounted) return;
                  messenger.showSnackBar(
                    const SnackBar(
                      content: Text('Não é possível concluir esta tarefa...'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  setState(() {});
                  return;
                }
              }

              setState(() {
                _currentValue = v;
              });
              widget.onStatusChanged(v);
            }
          : null,
      decoration: const InputDecoration(labelText: 'Status'),
    );
  }
}
```

### ✅ Código Novo (usando GenericDropdownField)

```dart
import 'package:flutter/material.dart';
import 'package:gestor_projetos_flutter/modules/modules.dart';
import 'package:gestor_projetos_flutter/widgets/dropdowns/dropdowns.dart';

class TaskStatusField extends StatelessWidget {
  final String status;
  final String? taskId;
  final ValueChanged<String> onStatusChanged;
  final bool enabled;

  const TaskStatusField({
    super.key,
    required this.status,
    this.taskId,
    required this.onStatusChanged,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return GenericDropdownField<String>(
      value: status,
      items: const [
        DropdownItem(value: 'todo', label: 'A Fazer'),
        DropdownItem(value: 'in_progress', label: 'Em Andamento'),
        DropdownItem(value: 'review', label: 'Revisão'),
        DropdownItem(value: 'waiting', label: 'Aguardando'),
        DropdownItem(value: 'completed', label: 'Concluída'),
      ],
      onChanged: (v) => onStatusChanged(v ?? 'todo'),
      labelText: 'Status',
      enabled: enabled,
      onBeforeChanged: (newValue) async {
        // Validar se pode concluir a task
        if (newValue == 'completed' && taskId != null) {
          return await tasksModule.canCompleteTask(taskId!);
        }
        return true;
      },
      validationErrorMessage: 'Não é possível concluir esta tarefa. Todas as sub tarefas devem estar concluídas primeiro.',
    );
  }
}
```

**Benefícios:**
- ✅ Reduzido de ~110 linhas para ~35 linhas (68% menos código)
- ✅ Não precisa mais de StatefulWidget
- ✅ Validação assíncrona integrada
- ✅ Auto-reset em caso de validação falhar
- ✅ Mais fácil de manter

---

## 2. Migrar TaskPriorityField

### ❌ Código Atual

```dart
class TaskPriorityField extends StatelessWidget {
  final String priority;
  final ValueChanged<String> onPriorityChanged;
  final bool enabled;

  const TaskPriorityField({
    super.key,
    required this.priority,
    required this.onPriorityChanged,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: priority,
      items: const [
        DropdownMenuItem(value: 'low', child: Text('Baixa')),
        DropdownMenuItem(value: 'medium', child: Text('Média')),
        DropdownMenuItem(value: 'high', child: Text('Alta')),
        DropdownMenuItem(value: 'urgent', child: Text('Urgente')),
      ],
      onChanged: enabled 
          ? (v) => onPriorityChanged(v ?? 'medium')
          : null,
      decoration: const InputDecoration(labelText: 'Prioridade'),
    );
  }
}
```

### ✅ Código Novo

```dart
import 'package:flutter/material.dart';
import 'package:gestor_projetos_flutter/widgets/dropdowns/dropdowns.dart';

class TaskPriorityField extends StatelessWidget {
  final String priority;
  final ValueChanged<String> onPriorityChanged;
  final bool enabled;

  const TaskPriorityField({
    super.key,
    required this.priority,
    required this.onPriorityChanged,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return GenericDropdownField<String>(
      value: priority,
      items: const [
        DropdownItem(value: 'low', label: 'Baixa'),
        DropdownItem(value: 'medium', label: 'Média'),
        DropdownItem(value: 'high', label: 'Alta'),
        DropdownItem(value: 'urgent', label: 'Urgente'),
      ],
      onChanged: (v) => onPriorityChanged(v ?? 'medium'),
      labelText: 'Prioridade',
      enabled: enabled,
    );
  }
}
```

**Benefícios:**
- ✅ Código mais limpo e legível
- ✅ Consistente com outros campos
- ✅ Fácil adicionar validação no futuro

---

## 3. Migrar ProjectStatusField

### ❌ Código Atual

```dart
class ProjectStatusField extends StatelessWidget {
  final String status;
  final ValueChanged<String> onStatusChanged;
  final bool enabled;

  const ProjectStatusField({
    super.key,
    required this.status,
    required this.onStatusChanged,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    // Normalizar status antigos
    String normalizedStatus = status;
    if (status == 'active' || status == 'ativo') {
      normalizedStatus = 'in_progress';
    } else if (status == 'inactive' || status == 'inativo') {
      normalizedStatus = 'paused';
    }

    return DropdownButtonFormField<String>(
      initialValue: normalizedStatus,
      items: const [
        DropdownMenuItem(value: 'not_started', child: Text('Não iniciado')),
        DropdownMenuItem(value: 'negotiation', child: Text('Em negociação')),
        DropdownMenuItem(value: 'in_progress', child: Text('Em andamento')),
        DropdownMenuItem(value: 'paused', child: Text('Pausado')),
        DropdownMenuItem(value: 'completed', child: Text('Concluído')),
        DropdownMenuItem(value: 'cancelled', child: Text('Cancelado')),
      ],
      onChanged: enabled ? (v) {
        if (v != null) {
          onStatusChanged(v);
        }
      } : null,
      decoration: const InputDecoration(
        labelText: 'Status',
        border: OutlineInputBorder(),
      ),
    );
  }
}
```

### ✅ Código Novo

```dart
import 'package:flutter/material.dart';
import 'package:gestor_projetos_flutter/widgets/dropdowns/dropdowns.dart';

class ProjectStatusField extends StatelessWidget {
  final String status;
  final ValueChanged<String> onStatusChanged;
  final bool enabled;

  const ProjectStatusField({
    super.key,
    required this.status,
    required this.onStatusChanged,
    this.enabled = true,
  });

  String _normalizeStatus(String status) {
    if (status == 'active' || status == 'ativo') return 'in_progress';
    if (status == 'inactive' || status == 'inativo') return 'paused';
    return status;
  }

  @override
  Widget build(BuildContext context) {
    return GenericDropdownField<String>(
      value: _normalizeStatus(status),
      items: const [
        DropdownItem(value: 'not_started', label: 'Não iniciado'),
        DropdownItem(value: 'negotiation', label: 'Em negociação'),
        DropdownItem(value: 'in_progress', label: 'Em andamento'),
        DropdownItem(value: 'paused', label: 'Pausado'),
        DropdownItem(value: 'completed', label: 'Concluído'),
        DropdownItem(value: 'cancelled', label: 'Cancelado'),
      ],
      onChanged: (v) {
        if (v != null) onStatusChanged(v);
      },
      labelText: 'Status',
      enabled: enabled,
      decoration: const InputDecoration(
        labelText: 'Status',
        border: OutlineInputBorder(),
      ),
    );
  }
}
```

---

## 4. Migrar Categoria em ClientForm

### ❌ Código Atual (client_form.dart)

```dart
// Categoria
LayoutBuilder(
  builder: (context, constraints) {
    return DropdownMenu<String>(
      controller: _categoryController,
      initialSelection: _selectedCategoryId,
      label: const Text('Categoria'),
      hintText: _loadingCategories ? 'Carregando...' : 'Digite para buscar...',
      enableFilter: true,
      enableSearch: true,
      requestFocusOnTap: true,
      enabled: !_loadingCategories,
      width: constraints.maxWidth,
      dropdownMenuEntries: _categories.map((category) {
        return DropdownMenuEntry<String>(
          value: category['id'] as String,
          label: category['name'] as String,
        );
      }).toList(),
      onSelected: (value) {
        setState(() {
          _selectedCategoryId = value;
        });
      },
    );
  },
)
```

### ✅ Código Novo

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

**Benefícios:**
- ✅ Reduzido de ~25 linhas para ~8 linhas (68% menos código)
- ✅ Não precisa de LayoutBuilder
- ✅ Não precisa de controller manual
- ✅ Largura responsiva automática

---

## 5. Migrar Cliente/Empresa em ProjectForm

### ❌ Código Atual (project_form_dialog.dart)

```dart
if (widget.fixedClientId == null)
  DropdownButtonFormField<String>(
    initialValue: _clients.any((c) => c['id'] == _clientId) ? _clientId : null,
    items: _clients.map((c) => DropdownMenuItem(
      value: (c['id'] as String),
      child: Text((c['name'] ?? '-') as String)
    )).toList(),
    onChanged: (v) {
      setState(() {
        _clientId = v;
        _companyId = null;
        _companies = [];
      });
      if (v != null) _loadCompanies(v);
    },
    decoration: const InputDecoration(labelText: 'Cliente'),
  ),

if (widget.fixedClientId == null && _companies.isNotEmpty)
  DropdownButtonFormField<String>(
    initialValue: _companies.any((c) => c['id'] == _companyId) ? _companyId : null,
    items: _companies.map((c) => DropdownMenuItem(
      value: (c['id'] as String),
      child: Text((c['name'] ?? '-') as String)
    )).toList(),
    onChanged: (v) => setState(() => _companyId = v),
    decoration: const InputDecoration(labelText: 'Empresa'),
  ),
```

### ✅ Código Novo

```dart
if (widget.fixedClientId == null)
  AsyncDropdownField<String>(
    value: _clientId,
    loadItems: () async {
      final response = await supabase.from('clients').select();
      return response.map((item) => DropdownItem(
        value: item['id'] as String,
        label: (item['name'] ?? '-') as String,
      )).toList();
    },
    onChanged: (v) {
      setState(() {
        _clientId = v;
        _companyId = null;
      });
    },
    labelText: 'Cliente',
    emptyMessage: 'Nenhum cliente cadastrado',
  ),

if (widget.fixedClientId == null)
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
        label: (item['name'] ?? '-') as String,
      )).toList();
    },
    onChanged: (v) => setState(() => _companyId = v),
    labelText: 'Empresa',
    dependencies: [_clientId], // Recarrega automaticamente quando cliente muda
    enabled: _clientId != null,
    emptyMessage: 'Selecione um cliente primeiro',
  ),
```

**Benefícios:**
- ✅ Não precisa mais de `_loadClients()` e `_loadCompanies()` no initState
- ✅ Não precisa mais de `_clients` e `_companies` como state
- ✅ Recarregamento automático de empresas quando cliente muda
- ✅ Loading state automático
- ✅ Tratamento de erro integrado

---

## 6. Migrar TaskAssigneeField

### ❌ Código Atual (task_assignee_field.dart)

```dart
return DropdownButtonFormField<String?>(
  key: ValueKey<String>('assignee:${assigneeUserId ?? ''}'),
  isExpanded: true,
  initialValue: validAssignee,
  items: [
    const DropdownMenuItem<String?>(
      value: null,
      child: Text('Não atribuído'),
    ),
    ...members.map((m) {
      final userId = m['user_id'] as String;
      final profile = m['profiles'] as Map<String, dynamic>?;
      final name = (profile?['full_name'] ?? profile?['email'] ?? 'Usuário') as String;
      final avatarUrl = profile?['avatar_url'] as String?;

      return DropdownMenuItem<String?>(
        value: userId,
        child: UserDropdownItem(
          avatarUrl: avatarUrl,
          name: name,
        ),
      );
    }),
  ],
  onChanged: enabled ? onAssigneeChanged : null,
  decoration: const InputDecoration(labelText: 'Responsável'),
);
```

### ✅ Código Novo

```dart
return GenericDropdownField<String?>(
  value: validAssignee,
  items: [
    const DropdownItem<String?>(
      value: null,
      label: 'Não atribuído',
    ),
    ...members.map((m) {
      final userId = m['user_id'] as String;
      final profile = m['profiles'] as Map<String, dynamic>?;
      final name = (profile?['full_name'] ?? profile?['email'] ?? 'Usuário') as String;
      final avatarUrl = profile?['avatar_url'] as String?;

      return DropdownItem<String?>(
        value: userId,
        label: name,
        customWidget: UserDropdownItem(
          avatarUrl: avatarUrl,
          name: name,
        ),
      );
    }),
  ],
  onChanged: onAssigneeChanged,
  labelText: 'Responsável',
  enabled: enabled,
);
```

**Benefícios:**
- ✅ Código mais limpo
- ✅ Usa customWidget para avatar
- ✅ Consistente com outros campos

---

## 🎯 Resumo de Benefícios

| Aspecto | Antes | Depois | Melhoria |
|---------|-------|--------|----------|
| **Linhas de código** | ~110 linhas (TaskStatusField) | ~35 linhas | **-68%** |
| **State management** | StatefulWidget necessário | StatelessWidget | **Mais simples** |
| **Validação assíncrona** | Código manual complexo | `onBeforeChanged` | **Integrado** |
| **Loading state** | Gerenciado manualmente | Automático | **Menos código** |
| **Recarregamento** | Callbacks manuais | `dependencies` | **Automático** |
| **Tratamento de erro** | Manual | Integrado com retry | **Robusto** |
| **Consistência** | Cada dropdown diferente | Todos iguais | **Padronizado** |

---

## 📚 Próximos Passos

1. Migrar os campos específicos (TaskStatusField, TaskPriorityField, etc.)
2. Migrar formulários complexos (ClientForm, ProjectForm, etc.)
3. Remover código duplicado
4. Testar todas as migrações
5. Documentar casos especiais

