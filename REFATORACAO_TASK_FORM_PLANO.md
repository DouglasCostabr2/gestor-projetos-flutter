# 🔄 Plano de Refatoração - Unificação dos Formulários de Task

## 📋 Objetivo

Unificar `_TaskForm` (TasksPage) e `QuickTaskForm` (quick_forms.dart) em um único componente reutilizável `TaskFormWidget`.

---

## 🎯 Abordagem Proposta

### Opção 1: Widget Unificado Completo ✅ RECOMENDADA
Criar um único widget `TaskFormWidget` que substitui ambos os formulários.

**Vantagens**:
- ✅ Zero duplicação de código
- ✅ Manutenção em um único lugar
- ✅ Comportamento 100% consistente
- ✅ Fácil adicionar novas features

**Desvantagens**:
- ⚠️ Widget grande (~800-1000 linhas)
- ⚠️ Muitos parâmetros de configuração
- ⚠️ Precisa refatorar 2 lugares (TasksPage + quick_forms.dart)

### Opção 2: Widget Base + Wrappers
Criar um widget base e 2 wrappers específicos.

**Vantagens**:
- ✅ Separação de responsabilidades
- ✅ Cada wrapper é simples

**Desvantagens**:
- ❌ Ainda tem alguma duplicação
- ❌ Mais arquivos para manter

---

## 📐 Estrutura do TaskFormWidget (Opção 1)

### Parâmetros do Widget

```dart
class TaskFormWidget extends StatefulWidget {
  // Context
  final String? projectId;           // Se fornecido, projeto pré-selecionado
  final bool isDialog;                // Se true, mostra em Dialog; se false, inline
  
  // Visibility controls
  final bool showProjectDropdown;     // Mostra dropdown de projeto
  final bool showStatusField;         // Mostra campo de status
  final bool showExistingAssets;      // Mostra seção de assets existentes
  
  // Data
  final Map<String, dynamic>? initial; // Dados da tarefa para edição
  
  // Callbacks
  final VoidCallback? onSaved;        // Chamado após salvar com sucesso
  final VoidCallback? onCancelled;    // Chamado ao cancelar
  
  const TaskFormWidget({
    super.key,
    this.projectId,
    this.isDialog = false,
    this.showProjectDropdown = true,
    this.showStatusField = true,
    this.showExistingAssets = true,
    this.initial,
    this.onSaved,
    this.onCancelled,
  });
}
```

### Lógica de Configuração

| Cenário | projectId | showProjectDropdown | showStatusField | showExistingAssets |
|---------|-----------|---------------------|-----------------|-------------------|
| **TasksPage** (lista geral) | `null` | `true` | `true` | `true` |
| **QuickTaskForm** (dentro projeto) | `'proj-123'` | `false` | `false` | `false` |

---

## 🔧 Implementação

### Passo 1: Criar TaskFormWidget ✅ INICIADO

**Arquivo**: `lib/src/features/tasks/widgets/task_form_widget.dart`

**Conteúdo**:
- ✅ Estrutura básica criada
- ⏳ Precisa completar método `_save()`
- ⏳ Precisa completar método `build()`
- ⏳ Precisa adicionar seção de Produto vinculado
- ⏳ Precisa adicionar seção de Briefing
- ⏳ Precisa adicionar seção de Assets
- ⏳ Precisa adicionar seção de Responsável/Status/Prioridade
- ⏳ Precisa adicionar seção de Histórico

### Passo 2: Atualizar TasksPage

**Arquivo**: `lib/src/features/tasks/tasks_page.dart`

**Mudanças**:
1. Remover classe `_TaskForm` (linhas ~300-1494)
2. Substituir por `TaskFormWidget`:

```dart
// ANTES:
showDialog(
  context: context,
  builder: (_) => Dialog(
    child: _TaskForm(initial: task),
  ),
);

// DEPOIS:
showDialog(
  context: context,
  builder: (_) => Dialog(
    child: TaskFormWidget(
      projectId: null,              // Usuário escolhe o projeto
      showProjectDropdown: true,    // Mostra dropdown
      showStatusField: true,         // Mostra status
      showExistingAssets: true,      // Mostra assets existentes
      initial: task,
      onSaved: () {
        Navigator.pop(context);
        _load(); // Recarrega lista
      },
    ),
  ),
);
```

### Passo 3: Atualizar quick_forms.dart

**Arquivo**: `lib/src/features/shared/quick_forms.dart`

**Mudanças**:
1. Remover classe `QuickTaskForm` (linhas ~750-2000)
2. Substituir por `TaskFormWidget`:

```dart
// ANTES:
showDialog(
  context: context,
  builder: (_) => QuickTaskForm(
    projectId: widget.projectId,
    initial: task,
  ),
);

// DEPOIS:
showDialog(
  context: context,
  builder: (_) => Dialog(
    child: TaskFormWidget(
      projectId: widget.projectId,   // Projeto pré-selecionado
      showProjectDropdown: false,    // NÃO mostra dropdown
      showStatusField: false,         // NÃO mostra status
      showExistingAssets: false,      // NÃO mostra assets existentes
      initial: task,
      onSaved: () {
        Navigator.pop(context);
        widget.onChanged?.call(); // Callback do parent
      },
    ),
  ),
);
```

### Passo 4: Remover Código Duplicado

**Arquivos afetados**:
- `lib/src/features/tasks/tasks_page.dart` - Remover ~1200 linhas
- `lib/src/features/shared/quick_forms.dart` - Remover ~1250 linhas

**Total removido**: ~2450 linhas de código duplicado! 🎉

---

## 📊 Comparação Antes/Depois

### ANTES:
```
tasks_page.dart:          1494 linhas (inclui _TaskForm)
quick_forms.dart:         2012 linhas (inclui QuickTaskForm)
task_form_widget.dart:    0 linhas
-------------------------------------------
TOTAL:                    3506 linhas
```

### DEPOIS:
```
tasks_page.dart:          ~300 linhas (sem _TaskForm)
quick_forms.dart:         ~750 linhas (sem QuickTaskForm)
task_form_widget.dart:    ~900 linhas (widget unificado)
-------------------------------------------
TOTAL:                    ~1950 linhas (-44% de código!)
```

---

## ⚠️ Riscos e Mitigações

### Risco 1: Quebrar funcionalidade existente
**Mitigação**: 
- Testar TODOS os cenários antes de remover código antigo
- Manter código antigo comentado temporariamente
- Fazer commit antes de começar

### Risco 2: Widget muito complexo
**Mitigação**:
- Dividir em métodos helper bem nomeados
- Documentar cada seção claramente
- Usar comentários explicativos

### Risco 3: Comportamentos sutis diferentes
**Mitigação**:
- Comparar lado a lado os 2 formulários atuais
- Listar TODAS as diferenças
- Garantir que cada diferença é controlada por parâmetro

---

## 🧪 Plano de Testes

### Cenário 1: TasksPage - Nova Tarefa
1. Abrir TasksPage
2. Clicar "Nova Tarefa"
3. Verificar: Dropdown de projeto aparece
4. Verificar: Campo status aparece
5. Preencher todos os campos
6. Salvar
7. Verificar: Tarefa criada corretamente

### Cenário 2: TasksPage - Editar Tarefa
1. Abrir TasksPage
2. Clicar "Editar" em uma tarefa
3. Verificar: Dados carregados corretamente
4. Verificar: Assets existentes aparecem
5. Modificar campos
6. Salvar
7. Verificar: Alterações salvas

### Cenário 3: ClientDetailPage - Nova Tarefa (Quick)
1. Abrir ClientDetailPage > Projeto
2. Clicar "Nova Tarefa"
3. Verificar: Dropdown de projeto NÃO aparece
4. Verificar: Campo status NÃO aparece
5. Preencher campos
6. Salvar
7. Verificar: Tarefa criada no projeto correto

### Cenário 4: ClientDetailPage - Editar Tarefa (Quick)
1. Abrir ClientDetailPage > Projeto
2. Clicar "Editar" em uma tarefa
3. Verificar: Dados carregados
4. Verificar: Assets existentes NÃO aparecem
5. Modificar campos
6. Salvar
7. Verificar: Alterações salvas

---

## 📝 Checklist de Implementação

### Fase 1: Preparação
- [x] Criar arquivo `task_form_widget.dart`
- [x] Definir estrutura básica do widget
- [ ] Completar método `_save()`
- [ ] Completar método `build()` com TODAS as seções

### Fase 2: Seções do Formulário
- [ ] Seção: Título do formulário
- [ ] Seção: Dropdown de projeto (condicional)
- [ ] Seção: Título da tarefa
- [ ] Seção: Prazo
- [ ] Seção: Produto vinculado
- [ ] Seção: Briefing (editor Quill)
- [ ] Seção: Assets (abas)
- [ ] Seção: Responsável
- [ ] Seção: Status (condicional)
- [ ] Seção: Prioridade
- [ ] Seção: Histórico (condicional)
- [ ] Seção: Botões Cancelar/Salvar

### Fase 3: Integração
- [ ] Atualizar TasksPage para usar TaskFormWidget
- [ ] Testar TasksPage - Nova tarefa
- [ ] Testar TasksPage - Editar tarefa
- [ ] Atualizar quick_forms.dart para usar TaskFormWidget
- [ ] Testar QuickTaskForm - Nova tarefa
- [ ] Testar QuickTaskForm - Editar tarefa

### Fase 4: Limpeza
- [ ] Remover classe `_TaskForm` de tasks_page.dart
- [ ] Remover classe `QuickTaskForm` de quick_forms.dart
- [ ] Executar `flutter analyze`
- [ ] Executar testes
- [ ] Commit final

---

## 🚀 Próximos Passos

**OPÇÃO A: Implementação Completa Agora**
- Completar TaskFormWidget (~2-3 horas de trabalho)
- Testar exaustivamente
- Integrar e remover código antigo

**OPÇÃO B: Implementação Incremental**
- Completar TaskFormWidget
- Integrar APENAS em TasksPage primeiro
- Testar bem
- Depois integrar em quick_forms.dart
- Remover código antigo por último

**OPÇÃO C: Manter Como Está**
- Não refatorar agora
- Manter os 2 formulários separados
- Refatorar no futuro quando houver mais tempo

---

## 💬 Recomendação

**Eu recomendo OPÇÃO B (Implementação Incremental)** porque:

1. ✅ Menos risco de quebrar tudo de uma vez
2. ✅ Podemos testar cada etapa
3. ✅ Se algo der errado, é mais fácil reverter
4. ✅ Você pode usar o sistema enquanto refatoramos

**Quer que eu continue com a implementação completa do TaskFormWidget?**

Ou prefere:
- [ ] Continuar implementação completa agora
- [ ] Fazer incremental (TasksPage primeiro)
- [ ] Revisar o plano antes de continuar
- [ ] Manter como está por enquanto

