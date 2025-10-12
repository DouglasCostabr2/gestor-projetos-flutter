# 🚨 CORRIGIR EXCLUSÃO DE TASKS - SOLUÇÃO COMPLETA

## ❌ PROBLEMA ATUAL

Quando você tenta excluir uma task, recebe este erro:

```
PostgrestException: insert or update on table "task_history" violates foreign key constraint "task_history_task_id_fkey"
Key (task_id)=(...) is not present in table "tasks"
```

## 📋 CAUSA RAIZ

**Dois problemas combinados**:

1. **Trigger com timing errado**: O trigger `task_changes_trigger` está tentando inserir um registro de histórico **DEPOIS** que a task já foi deletada (AFTER DELETE), causando violação de foreign key porque a task não existe mais.

2. **Foreign key sem CASCADE**: A constraint `task_history_task_id_fkey` não tem `ON DELETE CASCADE`, então não limpa automaticamente os registros de histórico quando a task é deletada.

## ✅ SOLUÇÃO COMPLETA

**Duas migrations necessárias** (execute na ordem):

1. **Migration 1**: Adicionar `ON DELETE CASCADE` na foreign key
2. **Migration 2**: Corrigir o trigger para não tentar inserir histórico de DELETE

---

## 🔧 COMO CORRIGIR (5 MINUTOS)

### Migration 1: Adicionar CASCADE na Foreign Key

Copie e execute este SQL no Supabase SQL Editor:

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

commit;
```

### Migration 2: Corrigir o Trigger

Copie e execute este SQL no Supabase SQL Editor:

```sql
begin;

-- Drop existing trigger
drop trigger if exists task_changes_trigger on public.tasks;

-- Recreate trigger function with proper DELETE handling
create or replace function public.log_task_changes()
returns trigger as $$
declare
  v_user_id uuid;
begin
  -- Get current user ID (from session or system)
  v_user_id := coalesce(auth.uid(), new.created_by, old.created_by);

  -- Handle INSERT (task created)
  if (TG_OP = 'INSERT') then
    insert into public.task_history (task_id, user_id, action, field_name, new_value)
    values (new.id, v_user_id, 'created', 'task', 'Tarefa criada');
    return new;
  end if;

  -- Handle UPDATE (task modified)
  if (TG_OP = 'UPDATE') then
    -- Track title changes
    if (old.title is distinct from new.title) then
      insert into public.task_history (task_id, user_id, action, field_name, old_value, new_value)
      values (new.id, v_user_id, 'updated', 'title', old.title, new.title);
    end if;

    -- Track description changes
    if (old.description is distinct from new.description) then
      insert into public.task_history (task_id, user_id, action, field_name, old_value, new_value)
      values (new.id, v_user_id, 'updated', 'description', 
              left(coalesce(old.description, ''), 100), 
              left(coalesce(new.description, ''), 100));
    end if;

    -- Track status changes
    if (old.status is distinct from new.status) then
      insert into public.task_history (task_id, user_id, action, field_name, old_value, new_value)
      values (new.id, v_user_id, 'updated', 'status', old.status, new.status);
    end if;

    -- Track priority changes
    if (old.priority is distinct from new.priority) then
      insert into public.task_history (task_id, user_id, action, field_name, old_value, new_value)
      values (new.id, v_user_id, 'updated', 'priority', old.priority, new.priority);
    end if;

    -- Track assigned_to changes
    if (old.assigned_to is distinct from new.assigned_to) then
      insert into public.task_history (task_id, user_id, action, field_name, old_value, new_value)
      values (new.id, v_user_id, 'updated', 'assigned_to', 
              coalesce(old.assigned_to::text, 'não atribuído'), 
              coalesce(new.assigned_to::text, 'não atribuído'));
    end if;

    -- Track due_date changes
    if (old.due_date is distinct from new.due_date) then
      insert into public.task_history (task_id, user_id, action, field_name, old_value, new_value)
      values (new.id, v_user_id, 'updated', 'due_date', 
              coalesce(old.due_date::text, 'sem prazo'), 
              coalesce(new.due_date::text, 'sem prazo'));
    end if;

    return new;
  end if;

  -- Handle DELETE (task deleted)
  -- NOTE: We don't log DELETE because CASCADE will auto-delete history
  -- This prevents foreign key violations
  if (TG_OP = 'DELETE') then
    return old;
  end if;

  return null;
end;
$$ language plpgsql security definer;

-- Recreate trigger
create trigger task_changes_trigger
  after insert or update or delete on public.tasks
  for each row execute function public.log_task_changes();

commit;
```

### Passos:
1. Acesse: https://app.supabase.com
2. SQL Editor → New Query
3. Cole a **Migration 1** e execute (Run)
4. Aguarde "Success"
5. Cole a **Migration 2** e execute (Run)
6. Aguarde "Success"
7. **Teste excluir uma task** (não precisa reiniciar o app!)

---

## 📊 O QUE AS MIGRATIONS FAZEM

### Migration 1: CASCADE na Foreign Key

**Antes**:
```sql
foreign key (task_id) references tasks(id)  -- Sem ON DELETE
```

**Depois**:
```sql
foreign key (task_id) references tasks(id) on delete cascade
```

**Comportamento**:
- ✅ Quando você excluir uma task
- ✅ Todos os registros de `task_history` dessa task serão excluídos **automaticamente**
- ✅ Não haverá mais registros "órfãos"

### Migration 2: Corrigir Trigger

**Antes**:
```sql
if (TG_OP = 'DELETE') then
  insert into public.task_history (...)  -- ❌ ERRO! Task já foi deletada
  values (old.id, ...);
end if;
```

**Depois**:
```sql
if (TG_OP = 'DELETE') then
  return old;  -- ✅ Não tenta inserir, deixa CASCADE fazer o trabalho
end if;
```

**Comportamento**:
- ✅ Não tenta inserir histórico de DELETE
- ✅ O CASCADE limpa automaticamente
- ✅ Sem erros de foreign key

---

## ✅ VERIFICAR SE DEU CERTO

### 1. Verificar CASCADE

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

### 2. Verificar Trigger

```sql
select 
  tgname as trigger_name,
  proname as function_name
from pg_trigger t
join pg_proc p on t.tgfoid = p.oid
where tgname = 'task_changes_trigger';
```

**Deve retornar**:
```
trigger_name            | function_name
------------------------|------------------
task_changes_trigger    | log_task_changes
```

### 3. Testar Exclusão

1. Crie uma task de teste
2. Verifique que ela tem histórico (registro "created")
3. Exclua a task
4. Verifique que o histórico foi excluído automaticamente

---

## 📝 NOTAS IMPORTANTES

### ✅ Seguro:
- Estas migrations são **seguras** e não afetam dados existentes
- Apenas mudam o comportamento de exclusão
- É o comportamento **correto** e esperado

### ⚠️ Comportamento após migrations:
- Excluir uma task → Exclui automaticamente:
  - ✅ Histórico da task (`task_history`)
  - ✅ Arquivos da task (se CASCADE estiver configurado em `task_files`)
  - ✅ Comentários da task (se CASCADE estiver configurado em `task_comments`)

### 💡 Por que não logar DELETE?
- Tentar inserir histórico DEPOIS de deletar a task causa erro de foreign key
- O CASCADE já garante que o histórico será limpo
- Se você quiser manter histórico de exclusões, seria necessário:
  - Usar uma tabela separada de "audit log" sem foreign key
  - Ou usar BEFORE DELETE trigger (mas isso complica a lógica)

---

## 🚀 DEPOIS DAS MIGRATIONS

1. ✅ Executar Migration 1 no Supabase
2. ✅ Executar Migration 2 no Supabase
3. ✅ Testar exclusão de task
4. ✅ Confirmar que funciona
5. ✅ Verificar que histórico foi excluído junto

---

**IMPORTANTE**: Execute as duas migrations para corrigir completamente o problema!

