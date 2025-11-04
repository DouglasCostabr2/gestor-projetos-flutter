# Table Cells - Componentes Reutilizáveis para Tabelas

Esta biblioteca fornece componentes padronizados para células de tabelas, garantindo consistência visual e facilitando a manutenção.

## 📦 Instalação

```dart
import 'package:gestor_projetos_flutter/widgets/table_cells/table_cells.dart';
```

## 🎯 Componentes Disponíveis

### 1. TableCellAvatar
Avatar com nome para usuários/clientes.

**Características:**
- Usa `CachedAvatar` para performance
- Suporte a inicial ou ícone como fallback
- Tamanho configurável

**Uso:**
```dart
// Avatar + nome
(item) => TableCellAvatar(
  avatarUrl: item['avatar_url'],
  name: item['name'],
  size: 12,
)

// Com inicial como fallback
(item) => TableCellAvatar(
  avatarUrl: item['avatar_url'],
  name: item['name'],
  size: 12,
  showInitial: true,
)

// Apenas avatar (sem nome)
(item) => TableCellAvatarOnly(
  avatarUrl: item['avatar_url'],
  name: item['name'],
  size: 12,
)
```

---

### 2. TableCellDate
Formatação padronizada de datas.

**Características:**
- Formato padrão: DD/MM/AAAA
- Parsing automático de strings
- Múltiplos formatos disponíveis

**Uso:**
```dart
// Formato padrão (DD/MM/AAAA)
(item) => TableCellDate(
  date: item['created_at'],
)

// Com hora (DD/MM/AAAA HH:mm)
(item) => TableCellDate(
  date: item['created_at'],
  format: TableCellDateFormat.full,
)

// Apenas mês/ano (MM/AAAA)
(item) => TableCellDate(
  date: item['created_at'],
  format: TableCellDateFormat.monthYear,
)
```

**Formatos disponíveis:**
- `TableCellDateFormat.short` - DD/MM/AAAA (padrão)
- `TableCellDateFormat.full` - DD/MM/AAAA HH:mm
- `TableCellDateFormat.monthYear` - MM/AAAA
- `TableCellDateFormat.dayMonth` - DD/MM

---

### 3. TableCellDueDate
Datas de vencimento com indicador visual de atraso.

**Características:**
- Formato padrão: DD/MM/AAAA
- Exibe ícone de alerta vermelho quando vencida e não concluída
- Verifica status da task automaticamente
- Parsing automático de strings

**Uso:**
```dart
// Uso básico
(task) => TableCellDueDate(
  dueDate: task['due_date'],
  status: task['status'],
)

// Com formato customizado
(task) => TableCellDueDate(
  dueDate: task['due_date'],
  status: task['status'],
  format: TableCellDueDateFormat.full, // DD/MM/AAAA HH:mm
)

// Com cor de alerta customizada
(task) => TableCellDueDate(
  dueDate: task['due_date'],
  status: task['status'],
  alertColor: Colors.orange,
)
```

**Lógica de alerta:**
- ✅ Mostra ícone vermelho: task vencida E não concluída
- ❌ Não mostra ícone: task concluída OU não vencida

**Formatos disponíveis:**
- `TableCellDueDateFormat.short` - DD/MM/AAAA (padrão)
- `TableCellDueDateFormat.full` - DD/MM/AAAA HH:mm
- `TableCellDueDateFormat.monthYear` - MM/AAAA
- `TableCellDueDateFormat.dayMonth` - DD/MM

---

### 4. TableCellCurrency
Valores monetários formatados.

**Características:**
- Suporte a múltiplas moedas (BRL, USD, EUR, GBP, JPY)
- Conversão automática de centavos
- Formatação com vírgula (BRL) ou ponto (outras)

**Uso:**
```dart
// Valor em centavos (padrão)
(item) => TableCellCurrency(
  valueCents: item['value_cents'],
  currencyCode: item['currency_code'] ?? 'BRL',
)

// Valor já em decimal
(item) => TableCellCurrency.fromDecimal(
  value: item['value'],
  currencyCode: 'USD',
)

// Mostrar zero (não esconder)
(item) => TableCellCurrency(
  valueCents: item['value_cents'],
  hideZero: false,
)
```

**Moedas suportadas:**
- `BRL` - R$ 1.234,56
- `USD` - $ 1234.56
- `EUR` - € 1234.56
- `GBP` - £ 1234.56
- `JPY` - ¥ 1234.56

---

### 5. TableCellCounter
Contador com ícone.

**Características:**
- Ícone + número
- Esconde zero por padrão
- Tooltip opcional

**Uso:**
```dart
// Contador básico
(item) => TableCellCounter(
  count: item['total_tasks'],
  icon: Icons.task_alt,
)

// Com tooltip
(item) => TableCellCounter(
  count: item['total_people'],
  icon: Icons.people,
  tooltip: 'Total de pessoas',
)

// Apenas número (sem ícone)
(item) => TableCellNumber(
  count: item['total'],
)
```

---

### 6. TableCellAvatarList
Lista de avatares com contador.

**Características:**
- Mostra até N avatares
- Contador "+N" para restantes
- Remove duplicatas automaticamente
- Tooltip com nomes

**Uso:**
```dart
// Lista de avatares (máximo 3 visíveis)
(item) => TableCellAvatarList(
  people: item['task_people'],
  maxVisible: 3,
)

// Com tamanho customizado
(item) => TableCellAvatarList(
  people: item['assigned_users'],
  maxVisible: 4,
  avatarSize: 16,
)

// Apenas contagem (sem avatares)
(item) => TableCellPeopleCount(
  people: item['people'],
  icon: Icons.people,
)
```

**Formato esperado de `people`:**
```dart
[
  {
    'id': 'user-1',
    'full_name': 'João Silva',
    'avatar_url': 'https://...',
  },
  {
    'id': 'user-2',
    'full_name': 'Maria Santos',
    'avatar_url': null,
  },
]
```

---

### 7. TableCellUpdatedBy
Informação de última atualização.

**Características:**
- Data + avatar + nome
- Layout vertical ou horizontal
- Suporte a dados null

**Uso:**
```dart
// Layout vertical (padrão)
(item) => TableCellUpdatedBy(
  date: item['updated_at'],
  profile: item['updated_by_profile'],
)

// Layout horizontal
(item) => TableCellUpdatedBy(
  date: item['updated_at'],
  profile: item['updated_by_profile'],
  layout: TableCellUpdatedByLayout.horizontal,
)

// Apenas data (sem pessoa)
(item) => TableCellUpdatedBy(
  date: item['updated_at'],
)

// Versão simplificada (sem avatar)
(item) => TableCellUpdatedBySimple(
  date: item['updated_at'],
  userName: item['updated_by_name'],
)
```

**Formato esperado de `profile`:**
```dart
{
  'id': 'user-1',
  'full_name': 'João Silva',
  'avatar_url': 'https://...',
}
```

---

## 📋 Exemplo Completo

```dart
import 'package:gestor_projetos_flutter/widgets/table_cells/table_cells.dart';

// Em uma página com DynamicPaginatedTable
DynamicPaginatedTable<Map<String, dynamic>>(
  items: _filteredData,
  columns: const [
    DataTableColumn(label: 'Cliente', sortable: true),
    DataTableColumn(label: 'Valor', sortable: true),
    DataTableColumn(label: 'Tasks', sortable: true),
    DataTableColumn(label: 'Pessoas', sortable: true),
    DataTableColumn(label: 'Atualizado', sortable: true),
    DataTableColumn(label: 'Criado', sortable: true),
  ],
  cellBuilders: [
    // Cliente com avatar
    (p) => TableCellAvatar(
      avatarUrl: p['clients']?['avatar_url'],
      name: p['clients']?['name'] ?? '-',
      size: 12,
    ),
    
    // Valor monetário
    (p) => TableCellCurrency(
      valueCents: p['value_cents'],
      currencyCode: p['currency_code'] ?? 'BRL',
    ),
    
    // Contador de tasks
    (p) => TableCellCounter(
      count: p['total_tasks'],
      icon: Icons.task_alt,
    ),
    
    // Lista de pessoas
    (p) => TableCellAvatarList(
      people: p['task_people'] ?? [],
      maxVisible: 3,
    ),
    
    // Última atualização
    (p) => TableCellUpdatedBy(
      date: p['updated_at'],
      profile: p['updated_by_profile'],
    ),
    
    // Data de criação
    (p) => TableCellDate(
      date: p['created_at'],
    ),
  ],
  // ... outros parâmetros
)
```

---

## 🎨 Customização

Todos os componentes suportam customização via parâmetros:

```dart
// Estilos customizados
TableCellDate(
  date: item['created_at'],
  style: TextStyle(color: Colors.grey, fontSize: 11),
)

// Cores customizadas
TableCellCounter(
  count: item['total'],
  icon: Icons.star,
  iconColor: Colors.amber,
)

// Tamanhos customizados
TableCellAvatar(
  avatarUrl: item['avatar_url'],
  name: item['name'],
  size: 16,
  spacing: 12,
)
```

---

## ✅ Benefícios

1. **Consistência** - Mesmo design em todas as tabelas
2. **Manutenção** - Mudanças em um lugar afetam todo o sistema
3. **Performance** - Uso de `CachedAvatar` para cache de imagens
4. **Produtividade** - Menos código para escrever
5. **Testabilidade** - Componentes isolados e testáveis

---

## 🔄 Migração

Para migrar código existente:

**Antes:**
```dart
(p) {
  final client = p['clients'];
  return Row(
    children: [
      CircleAvatar(
        radius: 12,
        backgroundImage: client['avatar_url'] != null 
            ? NetworkImage(client['avatar_url']) 
            : null,
      ),
      SizedBox(width: 8),
      Text(client['name'] ?? '-'),
    ],
  );
}
```

**Depois:**
```dart
(p) => TableCellAvatar(
  avatarUrl: p['clients']?['avatar_url'],
  name: p['clients']?['name'] ?? '-',
  size: 12,
)
```

