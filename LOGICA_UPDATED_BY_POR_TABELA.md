# 📊 Lógica de `updated_by` por Tabela

Este documento explica **individualmente** a lógica de cada tabela que tem a coluna "Última Atualização" e quando o campo `updated_by` é registrado ou não.

---

## 🎯 REGRAS DEFINIDAS PELO USUÁRIO

### 📋 TASKS (Tarefas e Subtarefas)
**Registrar `updated_by` e `updated_at` quando:**
1. ✅ Tarefa/subtarefa é **criada** ou **editada**
2. ✅ Novo **comentário** é adicionado
3. ✅ **Checkbox** é usado (marcado/desmarcado no briefing)
4. ✅ **Asset** é adicionado ou removido
5. ✅ **Arquivo de projeto final** é adicionado ou removido

### 📁 PROJECTS (Projetos)
**Registrar `updated_by` e `updated_at` quando:**
1. ✅ Projeto é **criado** ou **editado**
2. ✅ Task é **criada**, **duplicada** ou **excluída** no projeto

### 🏢 COMPANIES (Empresas)
**Registrar `updated_by` e `updated_at` quando:**
1. ✅ Empresa é **criada** ou **editada**
2. ✅ Projeto é **criado**, **duplicado** ou **excluído** na empresa

### 👤 CLIENTS (Clientes)
**Registrar `updated_by` e `updated_at` quando:**
1. ✅ Cliente é **criado** ou **editado**
2. ❓ (A definir se precisa registrar quando empresa/projeto é criado)

---

---

## 1. 📋 TASKS (Tarefas)

### Campos
- `created_by` - ID do usuário que criou a tarefa
- `updated_by` - ID do usuário que fez a última atualização
- `updated_at` - Data/hora da última atualização

### ✅ Quando É Registrado

#### Ao Criar Tarefa
- `created_by` é preenchido automaticamente com o usuário logado
- `updated_by` **NÃO** é preenchido na criação (fica NULL)
- `updated_at` é preenchido automaticamente pelo banco

**Código:** `lib/modules/tasks/repository.dart` - método `createTask()`

#### Ao Editar Tarefa
- `updated_by` é preenchido automaticamente com o usuário logado
- `updated_at` é preenchido automaticamente com a data/hora atual

**Código:** `lib/modules/tasks/repository.dart` - método `updateTask()` (linhas 334-337)
```dart
final user = authModule.currentUser;
if (user != null) {
  updateData['updated_by'] = user.id;
}
updateData['updated_at'] = DateTime.now().toIso8601String();
```

**Locais onde é chamado:**
- QuickTaskForm (edição rápida de tarefa)
- TaskDetailPage (edição completa de tarefa)
- TasksPage (edição de tarefa)

### ❌ Quando NÃO É Registrado
- Tarefas criadas antes da correção (precisam da migration)
- Tarefas que nunca foram editadas (têm `updated_by = NULL`)

### 🔧 Solução para Tarefas Antigas
Execute a migration SQL:
```sql
UPDATE tasks
SET updated_by = created_by
WHERE updated_by IS NULL AND created_by IS NOT NULL;
```

---

## 2. 🏢 COMPANIES (Empresas)

### Campos
- `owner_id` - ID do dono da empresa (quem criou)
- `updated_by` - ID do usuário que fez a última atualização
- `updated_at` - Data/hora da última atualização

### ✅ Quando É Registrado

#### Ao Criar Empresa
- `owner_id` é preenchido automaticamente com o usuário logado
- `updated_by` **NÃO** é preenchido na criação (fica NULL)
- `updated_at` é preenchido automaticamente pelo banco

**Código:** `lib/modules/companies/repository.dart` - método `createCompany()`

#### Ao Editar Empresa
- `updated_by` é preenchido automaticamente com o usuário logado
- `updated_at` é preenchido automaticamente com a data/hora atual

**Código:** `lib/modules/companies/repository.dart` - método `updateCompany()` (linhas 173-177)
```dart
final user = authModule.currentUser;
if (user != null) {
  updateData['updated_by'] = user.id;
}
updateData['updated_at'] = DateTime.now().toIso8601String();
```

**Locais onde é chamado:**
- CompaniesPage (formulário de edição de empresa)

### ❌ Quando NÃO É Registrado
- Empresas criadas antes da correção (precisam da migration)
- Empresas que nunca foram editadas (têm `updated_by = NULL`)

### 🔧 Solução para Empresas Antigas
Execute a migration SQL:
```sql
UPDATE companies
SET updated_by = owner_id
WHERE updated_by IS NULL AND owner_id IS NOT NULL;
```

---

## 3. 📁 PROJECTS (Projetos)

### Campos
- `owner_id` - ID do dono do projeto (quem criou)
- `created_by` - ID do usuário que criou o projeto
- `updated_by` - ID do usuário que fez a última atualização
- `updated_at` - Data/hora da última atualização

### ⚠️ PROBLEMA IDENTIFICADO

O método `updateProject()` **NÃO** está preenchendo `updated_by` e `updated_at` automaticamente!

**Código atual:** `lib/modules/projects/repository.dart` - método `updateProject()` (linhas 239-244)
```dart
final response = await _client
    .from('projects')
    .update(updates)  // ❌ Passa o Map direto sem adicionar updated_by
    .eq('id', projectId)
    .select()
    .single();
```

### ✅ Quando É Registrado

#### Ao Criar Projeto
- `owner_id` é preenchido automaticamente com o usuário logado
- `created_by` **pode** ser preenchido (depende do código que chama)
- `updated_by` **NÃO** é preenchido na criação
- `updated_at` é preenchido automaticamente pelo banco

**Código:** `lib/modules/projects/repository.dart` - método `createProject()`

#### Ao Editar Projeto
- ❌ **ATUALMENTE NÃO ESTÁ SENDO REGISTRADO!**
- O método `updateProject()` recebe um `Map<String, dynamic> updates` e passa direto para o banco
- Não adiciona `updated_by` nem `updated_at`

**Exceção:** Quando uma tarefa é editada via QuickTaskForm, o projeto é atualizado manualmente:
```dart
// lib/src/features/shared/quick_forms.dart (linhas 1182-1185)
await client.from('projects').update({
  'updated_by': userId,
  'updated_at': DateTime.now().toIso8601String(),
}).eq('id', widget.projectId!);
```

### ❌ Quando NÃO É Registrado
- ❌ **SEMPRE** - o método `updateProject()` não preenche esses campos
- Projetos criados antes da correção
- Projetos que nunca foram editados

### 🔧 Solução Necessária

**1. Corrigir o código:**
```dart
// lib/modules/projects/repository.dart - método updateProject()
Future<Map<String, dynamic>> updateProject({
  required String projectId,
  required Map<String, dynamic> updates,
}) async {
  // ... código existente ...

  // ADICIONAR ANTES DO UPDATE:
  final user = authModule.currentUser;
  if (user != null) {
    updates['updated_by'] = user.id;
  }
  updates['updated_at'] = DateTime.now().toIso8601String();

  final response = await _client
      .from('projects')
      .update(updates)
      .eq('id', projectId)
      .select()
      .single();

  // ... resto do código ...
}
```

**2. Executar migration SQL:**
```sql
UPDATE projects
SET updated_by = COALESCE(created_by, owner_id)
WHERE updated_by IS NULL;
```

---

## 4. 👤 CLIENTS (Clientes)

### Campos
- `owner_id` - ID do dono do cliente (quem criou)
- `updated_by` - ID do usuário que fez a última atualização
- `updated_at` - Data/hora da última atualização

### ⚠️ STATUS: NÃO VERIFICADO

Preciso verificar se o método `updateClient()` está preenchendo `updated_by` e `updated_at`.

**Ação necessária:** Verificar o código em `lib/modules/clients/repository.dart`

---

## 📊 Resumo Geral

| Tabela | Criação | Edição | Status | Precisa Correção? |
|--------|---------|--------|--------|-------------------|
| **tasks** | ✅ `created_by` | ✅ `updated_by` | ✅ OK | ❌ Não (apenas migration) |
| **companies** | ✅ `owner_id` | ✅ `updated_by` | ✅ OK | ❌ Não (apenas migration) |
| **projects** | ✅ `owner_id` | ❌ **NÃO PREENCHE** | ⚠️ PROBLEMA | ✅ **SIM - URGENTE** |
| **clients** | ✅ `owner_id` | ❓ Não verificado | ❓ Desconhecido | ❓ Verificar |

---

## 🎯 Ações Recomendadas

### Imediatas (Urgente)
1. ✅ **Corrigir `updateProject()`** - Adicionar `updated_by` e `updated_at`
2. ✅ **Executar migration para projects** - Preencher registros antigos
3. ❓ **Verificar `updateClient()`** - Confirmar se está OK

### Já Feitas
1. ✅ Corrigido `updateTask()` - OK
2. ✅ Corrigido `updateCompany()` - OK
3. ✅ Migration para tasks - Criada
4. ✅ Migration para companies - Criada

---

## 🔍 Como Verificar se Está Funcionando

### 1. Verificar no Código
Procure por `updated_by` e `updated_at` no método `update` de cada repositório:
```dart
final user = authModule.currentUser;
if (user != null) {
  updateData['updated_by'] = user.id;
}
updateData['updated_at'] = DateTime.now().toIso8601String();
```

### 2. Verificar no Banco de Dados
Execute esta query no Supabase SQL Editor:
```sql
-- Ver registros sem updated_by
SELECT 
  'tasks' as tabela,
  COUNT(*) as total,
  COUNT(updated_by) as com_updated_by,
  COUNT(*) - COUNT(updated_by) as sem_updated_by
FROM tasks
UNION ALL
SELECT 
  'companies',
  COUNT(*),
  COUNT(updated_by),
  COUNT(*) - COUNT(updated_by)
FROM companies
UNION ALL
SELECT 
  'projects',
  COUNT(*),
  COUNT(updated_by),
  COUNT(*) - COUNT(updated_by)
FROM projects
UNION ALL
SELECT 
  'clients',
  COUNT(*),
  COUNT(updated_by),
  COUNT(*) - COUNT(updated_by)
FROM clients;
```

### 3. Testar Manualmente
1. Edite um registro (tarefa, empresa, projeto, cliente)
2. Verifique no banco se `updated_by` foi preenchido
3. Verifique na UI se aparece o avatar e nome do usuário

---

## 📝 Notas Importantes

- **Migration é necessária** para registros antigos (criados antes da correção)
- **Código corrigido** garante que novos registros terão `updated_by` preenchido
- **Projetos precisam de correção urgente** no código
- **Clientes precisam de verificação** para confirmar se está OK

