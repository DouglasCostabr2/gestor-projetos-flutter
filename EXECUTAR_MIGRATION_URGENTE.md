# 🚨 EXECUTAR MIGRATION URGENTE

## ❌ ERRO ATUAL

```
PostgrestException: Could not find the 'linked_product_id' column of 'tasks'
PostgrestException: Could not find the 'linked_package_id' column of 'tasks'
```

## ✅ SOLUÇÃO RÁPIDA (5 MINUTOS)

### Passo 1: Copiar SQL

Abra o arquivo: `supabase/migrations/2025-10-02_add_product_linking_columns.sql`

Copie TODO o conteúdo (Ctrl+A, Ctrl+C)

### Passo 2: Executar no Supabase

1. Acesse: https://app.supabase.com
2. Selecione seu projeto
3. Menu lateral → **SQL Editor**
4. Clique em **New Query**
5. Cole o SQL (Ctrl+V)
6. Clique em **Run** (ou Ctrl+Enter)
7. Aguarde aparecer "Success. No rows returned"

### Passo 3: Reiniciar App

No terminal do Flutter:
1. Pressione `q` para sair
2. Execute: `flutter run`
3. Teste criar uma tarefa

---

## 📋 SQL COMPLETO (COPIE ISTO)

```sql
-- Migration: Add product linking columns to tasks table
-- Allows tasks to be linked to products from project catalog or packages

begin;

-- Add linked_product_id column if it doesn't exist
do $$
begin
  if not exists (
    select 1 from information_schema.columns 
    where table_schema = 'public' 
    and table_name = 'tasks' 
    and column_name = 'linked_product_id'
  ) then
    alter table public.tasks 
    add column linked_product_id uuid references public.products(id) on delete set null;
    
    -- Add index for performance
    create index idx_tasks_linked_product_id on public.tasks(linked_product_id);
    
    -- Add comment
    comment on column public.tasks.linked_product_id is 'Optional product ID when task is linked to a product from project catalog or package';
  end if;
end $$;

-- Add linked_package_id column if it doesn't exist
do $$
begin
  if not exists (
    select 1 from information_schema.columns 
    where table_schema = 'public' 
    and table_name = 'tasks' 
    and column_name = 'linked_package_id'
  ) then
    alter table public.tasks 
    add column linked_package_id uuid references public.packages(id) on delete set null;
    
    -- Add index for performance
    create index idx_tasks_linked_package_id on public.tasks(linked_package_id);
    
    -- Add comment
    comment on column public.tasks.linked_package_id is 'Optional package ID when task is linked to a package item (null if linked directly to project catalog)';
  end if;
end $$;

commit;
```

---

## ✅ VERIFICAR SE DEU CERTO

Depois de executar, rode este SQL para verificar:

```sql
select column_name, data_type, is_nullable 
from information_schema.columns 
where table_name = 'tasks' 
and column_name in ('linked_product_id', 'linked_package_id')
order by column_name;
```

**Deve retornar**:
```
column_name         | data_type | is_nullable
--------------------|-----------|------------
linked_package_id   | uuid      | YES
linked_product_id   | uuid      | YES
```

Se aparecer 2 linhas, está correto! ✅

---

## 🎯 DEPOIS DA MIGRATION

1. ✅ Reiniciar app Flutter
2. ✅ Testar criar tarefa
3. ✅ Testar vincular produto
4. ✅ Confirmar que erro desapareceu

---

**IMPORTANTE**: Esta migration é segura e não afeta dados existentes!

