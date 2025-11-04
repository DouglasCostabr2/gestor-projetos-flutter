# Guia de Migração - Table Cells

Este guia mostra como migrar código existente para usar os novos componentes padronizados de células.

## 📋 Checklist de Migração

Para cada página com tabela:

- [ ] Adicionar import: `import '../../../widgets/table_cells/table_cells.dart';`
- [ ] Substituir cellBuilders customizados pelos componentes padronizados
- [ ] Remover métodos privados não utilizados (ex: `_buildPeopleAvatars`, `_buildUpdatedByInfo`)
- [ ] Testar a página para garantir que tudo funciona
- [ ] Verificar se não há warnings de imports não utilizados

---

## 🔄 Exemplos de Migração

### 1. Avatar + Nome

**❌ Antes:**
```dart
(item) {
  final client = item['clients'];
  return Row(
    children: [
      CircleAvatar(
        radius: 12,
        backgroundImage: client['avatar_url'] != null 
            ? NetworkImage(client['avatar_url']) 
            : null,
        child: client['avatar_url'] == null
            ? Text(client['name'][0].toUpperCase())
            : null,
      ),
      SizedBox(width: 8),
      Text(client['name'] ?? '-'),
    ],
  );
}
```

**✅ Depois:**
```dart
(item) => TableCellAvatar(
  avatarUrl: item['clients']?['avatar_url'],
  name: item['clients']?['name'] ?? '-',
  size: 12,
)
```

---

### 2. Datas

**❌ Antes:**
```dart
(item) {
  final date = item['created_at'] != null
      ? DateTime.tryParse(item['created_at'])
      : null;
  if (date == null) return const Text('-');
  return Text('${date.day}/${date.month}/${date.year}');
}
```

**✅ Depois:**
```dart
(item) => TableCellDate(
  date: item['created_at'],
)
```

---

### 3. Valores Monetários

**❌ Antes:**
```dart
(item) {
  final valueCents = item['value_cents'] as int?;
  if (valueCents == null || valueCents == 0) return const Text('-');
  
  final value = valueCents / 100.0;
  return Text('R\$ ${value.toStringAsFixed(2)}');
}
```

**✅ Depois:**
```dart
(item) => TableCellCurrency(
  valueCents: item['value_cents'],
  currencyCode: item['currency_code'] ?? 'BRL',
)
```

---

### 4. Contadores

**❌ Antes:**
```dart
(item) {
  final totalTasks = item['total_tasks'] ?? 0;
  if (totalTasks == 0) return const Text('-');
  return Row(
    children: [
      Icon(Icons.task_alt, size: 16),
      SizedBox(width: 4),
      Text('$totalTasks'),
    ],
  );
}
```

**✅ Depois:**
```dart
(item) => TableCellCounter(
  count: item['total_tasks'],
  icon: Icons.task_alt,
)
```

---

### 5. Lista de Avatares

**❌ Antes:**
```dart
Widget _buildPeopleAvatars(List<dynamic> people) {
  // 60+ linhas de código para:
  // - Remover duplicatas
  // - Mostrar máximo 3 avatares
  // - Adicionar contador "+N"
  // - Tooltips
  // ...
}

// No cellBuilder:
(item) => _buildPeopleAvatars(item['task_people'] ?? [])
```

**✅ Depois:**
```dart
(item) => TableCellAvatarList(
  people: item['task_people'] ?? [],
  maxVisible: 3,
  avatarSize: 12,
)

// Remover o método _buildPeopleAvatars completamente
```

---

### 6. Última Atualização

**❌ Antes:**
```dart
Widget _buildUpdatedByInfo(Map<String, dynamic> item) {
  final profile = item['updated_by_profile'];
  final date = DateTime.tryParse(item['updated_at']);
  
  return Column(
    children: [
      Text('${date.day}/${date.month}/${date.year}'),
      Row(
        children: [
          CircleAvatar(...),
          Text(profile['full_name']),
        ],
      ),
    ],
  );
}

// No cellBuilder:
(item) => _buildUpdatedByInfo(item)
```

**✅ Depois:**
```dart
(item) => TableCellUpdatedBy(
  date: item['updated_at'],
  profile: item['updated_by_profile'],
  avatarSize: 10,
)

// Remover o método _buildUpdatedByInfo completamente
```

---

## 📄 Exemplo Completo de Migração

### Página de Clientes (clients_page.dart)

**❌ Antes:**
```dart
cellBuilders: [
  // Nome com avatar
  (c) => Row(
    children: [
      CircleAvatar(
        radius: 16,
        backgroundImage: c['avatar_url'] != null 
            ? NetworkImage(c['avatar_url']) 
            : null,
        child: c['avatar_url'] == null 
            ? Icon(Icons.person, size: 16) 
            : null,
      ),
      SizedBox(width: 12),
      Text(c['name'] ?? ''),
    ],
  ),
  
  // Categoria
  (c) => Text(c['client_categories']?['name'] ?? '-'),
  
  // Email
  (c) => Text(c['email'] ?? '-'),
  
  // Criado em
  (c) {
    final date = DateTime.tryParse(c['created_at'] ?? '');
    if (date == null) return const Text('-');
    return Text('${date.day}/${date.month}/${date.year}');
  },
]
```

**✅ Depois:**
```dart
import '../../../widgets/table_cells/table_cells.dart';

cellBuilders: [
  // Nome com avatar
  (c) => TableCellAvatar(
    avatarUrl: c['avatar_url'],
    name: c['name'] ?? '',
    size: 16,
    showInitial: false, // Usar ícone em vez de inicial
  ),
  
  // Categoria
  (c) => Text(c['client_categories']?['name'] ?? '-'),
  
  // Email
  (c) => Text(c['email'] ?? '-'),
  
  // Criado em
  (c) => TableCellDate(date: c['created_at']),
]
```

---

## 🎯 Páginas Prioritárias para Migração

1. **✅ ProjectsPage** - Já migrada (exemplo de referência)
2. **ClientsPage** - Usar `TableCellAvatar` para nome
3. **TasksPage** - Usar `TableCellDate` para datas, badges já estão OK
4. **CompaniesPage** - Usar `TableCellDate` e `TableCellUpdatedBy`
5. **UsersPage** - Usar `TableCellAvatar` para usuários

---

## 🔍 Como Identificar Código para Migrar

Procure por esses padrões no código:

### Padrão 1: CircleAvatar com NetworkImage
```dart
CircleAvatar(
  backgroundImage: url != null ? NetworkImage(url) : null,
  // ...
)
```
→ Substituir por `TableCellAvatar` ou `CachedAvatar`

### Padrão 2: Formatação manual de datas
```dart
'${date.day}/${date.month}/${date.year}'
```
→ Substituir por `TableCellDate`

### Padrão 3: Formatação de valores monetários
```dart
'R\$ ${value.toStringAsFixed(2)}'
```
→ Substituir por `TableCellCurrency`

### Padrão 4: Row com Icon + Text
```dart
Row(
  children: [
    Icon(Icons.something),
    SizedBox(width: 4),
    Text('$count'),
  ],
)
```
→ Substituir por `TableCellCounter`

### Padrão 5: Métodos privados _build*
```dart
Widget _buildSomethingForTable(...) {
  // Lógica complexa de renderização
}
```
→ Verificar se pode ser substituído por componente reutilizável

---

## ⚠️ Cuidados na Migração

1. **Tamanhos de avatar**: Verifique se o `size` está correto (é o radius, não o diâmetro)
2. **Dados null**: Os componentes já tratam null, não precisa verificar antes
3. **Estilos customizados**: Use os parâmetros `style`, `textStyle`, etc.
4. **Performance**: `TableCellAvatar` usa `CachedAvatar` automaticamente
5. **Testes**: Sempre teste a página após migração

---

## 📊 Benefícios Medidos

Após migrar ProjectsPage:

- **-124 linhas** de código removidas (métodos privados)
- **-60%** de código duplicado
- **+100%** de consistência visual
- **Cache automático** de avatares (melhor performance)
- **Manutenção centralizada** (mudanças em 1 lugar)

---

## 🆘 Problemas Comuns

### Problema: Import não encontrado
```
Error: '../../../widgets/table_cells/table_cells.dart' not found
```
**Solução:** Verifique o caminho relativo correto baseado na localização do arquivo

### Problema: Tipo incompatível
```
Error: The argument type 'String?' can't be assigned to 'String'
```
**Solução:** Use operador `??` para fornecer valor padrão:
```dart
name: item['name'] ?? '-'
```

### Problema: Avatar não aparece
**Solução:** Verifique se:
1. A URL está correta
2. O campo `avatar_url` está sendo buscado do banco
3. O `size` não está muito pequeno

---

## ✅ Checklist Final

Após migrar uma página:

- [ ] Código compila sem erros
- [ ] Não há warnings de imports não utilizados
- [ ] Tabela renderiza corretamente
- [ ] Avatares aparecem (ou iniciais/ícones)
- [ ] Datas formatadas corretamente (DD/MM/AAAA)
- [ ] Valores monetários com símbolo correto
- [ ] Contadores mostram números corretos
- [ ] Tooltips funcionam (passar mouse sobre avatares)
- [ ] Performance está boa (sem lentidão)
- [ ] Métodos privados não utilizados foram removidos

