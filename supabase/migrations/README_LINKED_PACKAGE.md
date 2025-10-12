# Migration: Add Product Linking Columns to tasks

## 🚨 ERROS ENCONTRADOS

```
PostgrestException: Could not find the 'linked_product_id' column of 'tasks'
PostgrestException: Could not find the 'linked_package_id' column of 'tasks'
```

## 📋 PROBLEMA

As colunas `linked_product_id` e `linked_package_id` não existem na tabela `tasks` do Supabase, mas o código Flutter está tentando salvá-las.

## ✅ SOLUÇÃO

Execute a migration `2025-10-02_add_product_linking_columns.sql` no Supabase.

---

## 🔧 COMO EXECUTAR A MIGRATION

### Opção 1: Via Supabase Dashboard (RECOMENDADO)

1. Acesse: https://app.supabase.com
2. Selecione seu projeto
3. Vá em **SQL Editor** (menu lateral esquerdo)
4. Clique em **New Query**
5. Copie o conteúdo do arquivo `2025-10-02_add_product_linking_columns.sql`
6. Cole no editor
7. Clique em **Run** (ou pressione Ctrl+Enter)
8. Verifique se apareceu "Success. No rows returned"

### Opção 2: Via Supabase CLI

```bash
# Se você tem Supabase CLI instalado
supabase db push
```

---

## 📊 O QUE A MIGRATION FAZ

### 1. Adiciona coluna `linked_product_id`
```sql
alter table public.tasks
add column linked_product_id uuid references public.products(id) on delete set null;
```

**Características**:
- Tipo: `uuid`
- Nullable: `true` (opcional)
- Foreign Key: `products(id)`
- On Delete: `SET NULL` (se o produto for deletado, o campo fica null)

### 2. Adiciona coluna `linked_package_id`
```sql
alter table public.tasks
add column linked_package_id uuid references public.packages(id) on delete set null;
```

**Características**:
- Tipo: `uuid`
- Nullable: `true` (opcional)
- Foreign Key: `packages(id)`
- On Delete: `SET NULL` (se o pacote for deletado, o campo fica null)

### 3. Adiciona índices para performance
```sql
create index idx_tasks_linked_product_id on public.tasks(linked_product_id);
create index idx_tasks_linked_package_id on public.tasks(linked_package_id);
```

### 4. Adiciona comentários
```sql
comment on column public.tasks.linked_product_id is 'Optional product ID when task is linked to a product from project catalog or package';
comment on column public.tasks.linked_package_id is 'Optional package ID when task is linked to a package item (null if linked directly to project catalog)';
```

---

## 🎯 COMO FUNCIONA O VÍNCULO DE PRODUTO

### Cenário 1: Produto direto do catálogo do projeto
```
Task:
  linked_product_id: "prod-123"
  linked_package_id: null
```

O produto vem diretamente do catálogo do projeto (`project_catalog_items`).

### Cenário 2: Produto de um pacote
```
Task:
  linked_product_id: "prod-456"
  linked_package_id: "pkg-789"
```

O produto vem de um pacote específico (`package_items`).

---

## ✅ VERIFICAÇÃO

Após executar a migration, verifique se as colunas foram criadas:

```sql
select column_name, data_type, is_nullable
from information_schema.columns
where table_name = 'tasks'
and column_name in ('linked_product_id', 'linked_package_id')
order by column_name;
```

**Resultado esperado**:
```
column_name         | data_type | is_nullable
--------------------|-----------|------------
linked_package_id   | uuid      | YES
linked_product_id   | uuid      | YES
```

---

## 🔄 DEPOIS DA MIGRATION

1. **Reinicie o app Flutter** (hot reload pode não ser suficiente)
2. **Teste criar uma tarefa** vinculada a um produto
3. **Verifique se não há mais erros**

---

## 📝 NOTAS

- Estas colunas já deveriam existir desde o início, mas foram esquecidas na criação inicial da tabela
- A migration é **idempotente** (pode ser executada múltiplas vezes sem problemas)
- Não afeta dados existentes (apenas adiciona as colunas)
- Tarefas existentes terão `linked_product_id = null` e `linked_package_id = null` (comportamento correto)

---

## 🚀 PRÓXIMOS PASSOS

Depois de executar a migration:

1. ✅ Executar migration no Supabase
2. ✅ Reiniciar app Flutter
3. ✅ Testar criação de tarefa
4. ✅ Testar vínculo de produto (direto e de pacote)
5. ✅ Confirmar que erro desapareceu

---

**Status**: Migration pronta para execução! 🎉

