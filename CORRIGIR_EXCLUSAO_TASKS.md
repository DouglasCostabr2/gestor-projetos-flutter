# 🚨 CORRIGIR EXCLUSÃO DE TASKS

## ❌ PROBLEMA ATUAL

Quando você tenta excluir uma task, recebe este erro:

```
PostgrestException: insert or update on table "task_history" violates foreign key constraint "task_history_task_id_fkey"
Key (task_id)=(...) is not present in table "tasks"
```

## 📋 CAUSA

A tabela `task_history` tem uma foreign key para `tasks` que **impede a exclusão** de tasks que possuem histórico.

Atualmente a constraint está configurada como:
- `ON DELETE RESTRICT` (ou sem especificar, que é o padrão)
- Isso **bloqueia** a exclusão da task se houver registros em `task_history`

## ✅ SOLUÇÃO

Alterar a constraint para `ON DELETE CASCADE`:
- Quando uma task for excluída, **todos os registros de histórico** serão excluídos automaticamente
- Isso é o comportamento correto e esperado

---

## 🔧 COMO CORRIGIR (2 MINUTOS)

### Passo 1: Copiar SQL

Copie este SQL:

```sql
begin;

-- Drop existing foreign key constraint
alter table public.task_history 
drop constraint if exists task_history_task_id_fkey;

-- Recreate with ON DELETE CASCADE
alter table public.task_history 
add constraint task_history_task_id_fkey 
foreign key (task_id) 
references public.tasks(id) 
on delete cascade;

-- Add comment explaining the behavior
comment on constraint task_history_task_id_fkey on public.task_history is 
'Foreign key to tasks table with CASCADE delete - when a task is deleted, all its history entries are automatically deleted';

commit;
```

### Passo 2: Executar no Supabase

1. Acesse: https://app.supabase.com
2. Selecione seu projeto
3. Menu lateral → **SQL Editor**
4. Clique em **New Query**
5. Cole o SQL (Ctrl+V)
6. Clique em **Run** (ou Ctrl+Enter)
7. Aguarde aparecer "Success. No rows returned"

### Passo 3: Testar

1. **NÃO precisa reiniciar o app** (mudança no banco de dados)
2. Tente excluir uma task
3. Deve funcionar agora! ✅

---

## 📊 O QUE A MIGRATION FAZ

### 1. Remove constraint antiga
```sql
alter table public.task_history 
drop constraint if exists task_history_task_id_fkey;
```

### 2. Cria nova constraint com CASCADE
```sql
alter table public.task_history 
add constraint task_history_task_id_fkey 
foreign key (task_id) 
references public.tasks(id) 
on delete cascade;
```

**Comportamento**:
- ✅ Quando você excluir uma task
- ✅ Todos os registros de `task_history` dessa task serão excluídos automaticamente
- ✅ Não haverá mais erro de foreign key violation

---

## ✅ VERIFICAR SE DEU CERTO

Depois de executar, rode este SQL para verificar:

```sql
select 
  conname as constraint_name,
  confdeltype as on_delete_action
from pg_constraint
where conname = 'task_history_task_id_fkey';
```

**Deve retornar**:
```
constraint_name              | on_delete_action
-----------------------------|------------------
task_history_task_id_fkey    | c
```

O `c` significa **CASCADE** ✅

---

## 🎯 OUTRAS TABELAS QUE PODEM PRECISAR DO MESMO FIX

Se você tiver problemas similares ao excluir tasks, pode ser necessário aplicar CASCADE em:

- `task_files` → `task_id` (arquivos da task)
- `task_comments` → `task_id` (comentários da task)
- `task_attachments` → `task_id` (anexos da task)

**Mas teste primeiro!** Pode ser que já estejam corretas.

---

## 📝 NOTAS IMPORTANTES

### ✅ Seguro:
- Esta migration é **segura** e não afeta dados existentes
- Apenas muda o comportamento de exclusão
- É o comportamento **correto** e esperado

### ⚠️ Comportamento após migration:
- Excluir uma task → Exclui automaticamente:
  - ✅ Histórico da task (`task_history`)
  - ✅ Arquivos da task (se CASCADE estiver configurado)
  - ✅ Comentários da task (se CASCADE estiver configurado)

### 💡 Alternativa (NÃO recomendada):
Se você quiser **manter o histórico** mesmo após excluir a task:
- Use `ON DELETE SET NULL` em vez de `CASCADE`
- Mas isso pode causar registros "órfãos" no banco

**Recomendação**: Use CASCADE (como na migration acima)

---

## 🚀 DEPOIS DA MIGRATION

1. ✅ Executar migration no Supabase
2. ✅ Testar exclusão de task
3. ✅ Confirmar que funciona
4. ✅ Verificar se histórico foi excluído junto

---

**IMPORTANTE**: Esta migration corrige o problema de exclusão de tasks!

