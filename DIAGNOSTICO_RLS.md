# 🔍 DIAGNÓSTICO - RLS TASK_PRODUCTS

Data: 2025-10-02

---

## 📋 **PASSO A PASSO:**

### 1️⃣ **PRIMEIRO: Execute a Migration de Fix**

**Arquivo**: `supabase/migrations/2025-10-02_fix_task_products_rls.sql`

1. Abra: https://app.supabase.com
2. SQL Editor → New Query
3. Cole o conteúdo da migration
4. Execute (Ctrl+Enter)
5. Aguarde "Success"

---

### 2️⃣ **TESTE NO APP:**

1. Abra o app
2. Edite a task `7bb80bfb-97ff-4e46-8f09-71e4b560bbb9`
3. Adicione 1-2 produtos
4. Salve
5. Verifique o console

**Resultado esperado**: Sem erro de RLS

---

### 3️⃣ **SE AINDA DER ERRO: Execute Diagnóstico**

**Arquivo**: `DEBUG_RLS_TASK_PRODUCTS.sql`

Execute as queries uma por uma no Supabase SQL Editor:

#### Query 1: Verificar usuário atual
```sql
select auth.uid() as current_user_id;
```
**Deve retornar**: Seu user_id

#### Query 2: Verificar se a task existe
```sql
select 
  t.id as task_id,
  t.title,
  t.project_id,
  p.name as project_name
from tasks t
join projects p on p.id = t.project_id
where t.id = '7bb80bfb-97ff-4e46-8f09-71e4b560bbb9';
```
**Deve retornar**: Dados da task

#### Query 3: Verificar membros do projeto
```sql
select 
  pm.user_id,
  pm.project_id,
  pm.role,
  u.email
from project_members pm
join auth.users u on u.id = pm.user_id
where pm.project_id = (
  select project_id 
  from tasks 
  where id = '7bb80bfb-97ff-4e46-8f09-71e4b560bbb9'
);
```
**Deve retornar**: Lista de membros (incluindo você)

#### Query 4: Verificar se VOCÊ é membro
```sql
select 
  pm.user_id,
  pm.project_id,
  pm.role,
  u.email,
  case 
    when pm.user_id = auth.uid() then 'SIM - Você é membro'
    else 'NÃO - Você NÃO é membro'
  end as is_member
from project_members pm
join auth.users u on u.id = pm.user_id
where pm.project_id = (
  select project_id 
  from tasks 
  where id = '7bb80bfb-97ff-4e46-8f09-71e4b560bbb9'
)
and pm.user_id = auth.uid();
```
**Deve retornar**: "SIM - Você é membro"

#### Query 5: Testar política RLS
```sql
select 
  exists (
    select 1 
    from public.tasks t
    join public.project_members pm on pm.project_id = t.project_id
    where t.id = '7bb80bfb-97ff-4e46-8f09-71e4b560bbb9'
      and pm.user_id = auth.uid()
  ) as can_insert;
```
**Deve retornar**: `true`

#### Query 6: Ver políticas atuais
```sql
select 
  policyname,
  cmd,
  qual,
  with_check
from pg_policies
where tablename = 'task_products';
```
**Deve retornar**: 4 políticas (SELECT, INSERT, UPDATE, DELETE)

---

## 🎯 **POSSÍVEIS CAUSAS DO ERRO:**

### Causa 1: Políticas duplicadas ou incorretas
**Solução**: Migration de fix remove e recria

### Causa 2: Usuário não é membro do projeto
**Solução**: Adicionar usuário ao projeto via `project_members`

### Causa 3: Task não tem `project_id`
**Solução**: Verificar se a task tem `project_id` válido

### Causa 4: RLS não está habilitado corretamente
**Solução**: Verificar com Query 6

---

## 📊 **RESULTADOS ESPERADOS:**

Após executar a migration de fix:

✅ Query 1: Retorna seu user_id  
✅ Query 2: Retorna dados da task  
✅ Query 3: Retorna lista de membros  
✅ Query 4: Retorna "SIM - Você é membro"  
✅ Query 5: Retorna `true`  
✅ Query 6: Retorna 4 políticas  

Se TODOS retornarem OK → **RLS está correto, problema é outro**  
Se ALGUM falhar → **Identificamos o problema específico**

---

## 🚀 **AÇÃO IMEDIATA:**

1. ⚠️ **Execute a migration de fix**
2. ✅ **Teste no app**
3. 🐛 **Se ainda der erro, execute diagnóstico**
4. 📝 **Me envie os resultados**

---

**COMECE PELA MIGRATION DE FIX!** 🚀

