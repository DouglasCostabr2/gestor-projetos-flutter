# Larguras Automáticas de Colunas em Tabelas

## 📋 Visão Geral

O sistema de tabelas (`ReusableDataTable` e `DynamicPaginatedTable`) agora aplica **larguras fixas automaticamente** para colunas com labels padrão, garantindo consistência visual em todo o projeto.

## 🎯 Larguras Automáticas Aplicadas

### Colunas com 120px fixos:

1. **Status**
   - Labels detectados: `"status"`

2. **Prioridade**
   - Labels detectados:
     - `"prioridade"`
     - `"priority"`

3. **Data de Criação**
   - Labels detectados:
     - `"criado"`
     - `"criado em"`
     - `"created"`
     - `"created at"`

4. **Data de Atualização**
   - Labels detectados:
     - `"atualizado"`
     - `"atualizado em"`
     - `"última atualização"`
     - `"updated"`
     - `"updated at"`
     - `"last updated"`

5. **Data de Conclusão / Vencimento**
   - Labels detectados:
     - `"data de conclusão"`
     - `"vencimento"`
     - `"due date"`
     - `"deadline"`

6. **Responsável**
   - Labels detectados:
     - `"responsável"`
     - `"responsavel"`
     - `"assignee"`
     - `"assigned to"`

### Colunas com 80px fixos:

7. **Tasks**
   - Labels detectados:
     - `"tasks"`
     - `"tarefas"`

8. **Ações**
   - Coluna de ações (menu de 3 pontos)
   - Aplicado automaticamente quando há `actions` definidas

## 🔧 Como Funciona

### Detecção Automática

O componente `ReusableDataTable` possui o método `_getAutoFixedWidth(String label)` que:

1. Normaliza o label (lowercase, trim)
2. Compara com os labels conhecidos
3. Retorna a largura fixa apropriada ou `null`

```dart
double? _getAutoFixedWidth(String label) {
  final normalizedLabel = label.toLowerCase().trim();
  
  // Colunas de status
  if (normalizedLabel == 'status') {
    return 120;
  }

  // Colunas de prioridade
  if (normalizedLabel == 'prioridade' || normalizedLabel == 'priority') {
    return 120;
  }

  // Colunas de tasks
  if (normalizedLabel == 'tasks' || normalizedLabel == 'tarefas') {
    return 80;
  }

  // Colunas de data de criação
  if (normalizedLabel == 'criado' ||
      normalizedLabel == 'criado em' ||
      normalizedLabel == 'created' ||
      normalizedLabel == 'created at') {
    return 120;
  }

  // Colunas de data de atualização
  if (normalizedLabel == 'atualizado' ||
      normalizedLabel == 'atualizado em' ||
      normalizedLabel == 'última atualização' ||
      normalizedLabel == 'updated' ||
      normalizedLabel == 'updated at' ||
      normalizedLabel == 'last updated') {
    return 120;
  }

  // Colunas de data de conclusão/vencimento
  if (normalizedLabel == 'data de conclusão' ||
      normalizedLabel == 'vencimento' ||
      normalizedLabel == 'due date' ||
      normalizedLabel == 'deadline') {
    return 120;
  }

  // Colunas de responsável
  if (normalizedLabel == 'responsável' ||
      normalizedLabel == 'responsavel' ||
      normalizedLabel == 'assignee' ||
      normalizedLabel == 'assigned to') {
    return 120;
  }

  return null;
}
```

### Prioridade de Larguras

A aplicação de larguras segue esta ordem de prioridade:

1. **`fixedWidth` explícito** - Se especificado no `DataTableColumn`, tem prioridade máxima
2. **Largura automática** - Baseada no label da coluna
3. **`flex`** - Se especificado no `DataTableColumn`
4. **FlexColumnWidth padrão** - Largura flexível padrão

## 📝 Uso nas Páginas

### ✅ Forma Correta (Automática)

```dart
DynamicPaginatedTable<Map<String, dynamic>>(
  items: _filteredData,
  columns: const [
    DataTableColumn(label: 'Nome', sortable: true),
    DataTableColumn(label: 'Status', sortable: true),  // ← 120px automático
    DataTableColumn(label: 'Atualizado', sortable: true),  // ← 120px automático
    DataTableColumn(label: 'Criado', sortable: true),  // ← 120px automático
  ],
  // ...
)
```

### ❌ Forma Antiga (Redundante)

```dart
// NÃO É MAIS NECESSÁRIO especificar fixedWidth para colunas padrão
DynamicPaginatedTable<Map<String, dynamic>>(
  items: _filteredData,
  columns: const [
    DataTableColumn(label: 'Nome', sortable: true),
    DataTableColumn(label: 'Status', sortable: true, fixedWidth: 120),  // ← Redundante
    DataTableColumn(label: 'Atualizado', sortable: true, fixedWidth: 120),  // ← Redundante
    DataTableColumn(label: 'Criado', sortable: true, fixedWidth: 120),  // ← Redundante
  ],
  // ...
)
```

### 🔧 Sobrescrever Largura Automática

Se precisar de uma largura diferente da automática:

```dart
DataTableColumn(
  label: 'Status', 
  sortable: true, 
  fixedWidth: 150,  // ← Sobrescreve o 120px automático
)
```

## 📊 Páginas Afetadas

Todas as páginas com tabelas agora se beneficiam das larguras automáticas:

- ✅ **Catálogo** (Produtos e Pacotes)
- ✅ **Projetos**
- ✅ **Clientes**
- ✅ **Empresas**
- ✅ **Categorias de Clientes**
- ✅ **Detalhes de Projeto** (Tasks)
- ✅ **Detalhes de Empresa** (Projetos)
- ✅ Todas as futuras tabelas do sistema

## 🎨 Benefícios

1. **Consistência Visual**: Todas as tabelas têm larguras padronizadas
2. **Menos Código**: Não precisa especificar `fixedWidth` em cada página
3. **Manutenção Centralizada**: Mudanças de largura em um único lugar
4. **Flexibilidade**: Ainda permite sobrescrever quando necessário
5. **Internacionalização**: Suporta labels em português e inglês

## 🔄 Histórico de Mudanças

### Versão 1.3 (2025-01-13)
- Adicionada largura automática para coluna "Prioridade" (120px)
- Suporte para labels "prioridade" e "priority"

### Versão 1.2 (2025-01-13)
- Adicionada largura automática para coluna "Data de Conclusão" / "Vencimento" (120px)
- Adicionada largura automática para coluna "Responsável" (120px)
- Atualizado label "Data de Conclusão" → "Vencimento" em todas as páginas
- Suporte para labels em português e inglês

### Versão 1.1 (2025-01-13)
- Adicionada largura automática para coluna "Tasks" (80px)
- Suporte para labels "tasks" e "tarefas"

### Versão 1.0 (2025-01-13)
- Implementação inicial de larguras automáticas
- Suporte para colunas: Status, Criado, Atualizado, Ações
- Detecção automática de labels em português e inglês
- Aplicação em todas as tabelas do sistema

## 📚 Referências

- Componente: `lib/ui/organisms/tables/reusable_data_table.dart`
- Documentação de Tabelas: `LISTA_MUDANCAS_TABELAS.md`
- Componentes de Células: `lib/ui/molecules/table_cells/README.md`

