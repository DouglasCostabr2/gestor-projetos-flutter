# 🚀 EXECUTAR MIGRATIONS - TASK PRODUCTS

Data: 2025-10-02

---

## ⚠️ IMPORTANTE: EXECUTE ESTAS MIGRATIONS ANTES DE CONTINUAR

Foram criadas 2 migrations essenciais para corrigir problemas e adicionar funcionalidades:

---

## 📋 MIGRATION 1: Limpar Histórico Órfão

**Arquivo**: `supabase/migrations/2025-10-02_cleanup_orphan_task_history.sql`

**Problema que resolve**:
- Erro: `insert or update on table "task_history" violates foreign key constraint "task_history_task_id_fkey"`
- Causa: Registros de histórico referenciando tasks que foram deletadas

**O que faz**:
- Remove todos os registros de `task_history` que referenciam tasks inexistentes

**Como executar**:
1. Acesse: https://app.supabase.com
2. SQL Editor → New Query
3. Cole o conteúdo do arquivo `supabase/migrations/2025-10-02_cleanup_orphan_task_history.sql`
4. Run (Ctrl+Enter)
5. Aguarde "Success"

---

## 📋 MIGRATION 2: Criar Tabela task_products

**Arquivo**: `supabase/migrations/2025-10-02_create_task_products_table.sql`

**Funcionalidade que adiciona**:
- Permite vincular **múltiplos produtos** a uma task (relação 1:N)
- Produtos já vinculados a outras tasks terão indicador
- Opção de desvincular produto de uma task e vincular a outra

**O que faz**:
1. Cria tabela `task_products` com:
   - `task_id` (referência para tasks)
   - `product_id` (referência para products)
   - `package_id` (referência para packages, opcional)
   - Constraint UNIQUE para evitar duplicatas
   - ON DELETE CASCADE para limpar automaticamente

2. Cria índices para performance

3. Configura RLS (Row Level Security) com mesmas regras de tasks

4. **Migra dados existentes** de `tasks.linked_product_id` para `task_products`

5. Mantém colunas antigas por enquanto (para compatibilidade)

**Como executar**:
1. Acesse: https://app.supabase.com
2. SQL Editor → New Query
3. Cole o conteúdo do arquivo `supabase/migrations/2025-10-02_create_task_products_table.sql`
4. Run (Ctrl+Enter)
5. Aguarde "Success"

---

## ✅ ORDEM DE EXECUÇÃO

**IMPORTANTE**: Execute nesta ordem:

1. ✅ **PRIMEIRO**: `2025-10-02_cleanup_orphan_task_history.sql`
2. ✅ **DEPOIS**: `2025-10-02_create_task_products_table.sql`

---

## 🔍 VERIFICAR SE DEU CERTO

Após executar as migrations, execute estas queries para verificar:

### Verificar task_products criada:
```sql
select * from public.task_products limit 10;
```

### Verificar dados migrados:
```sql
select 
  tp.id,
  t.title as task_title,
  p.name as product_name,
  pkg.name as package_name
from public.task_products tp
join public.tasks t on t.id = tp.task_id
join public.products p on p.id = tp.product_id
left join public.packages pkg on pkg.id = tp.package_id
limit 10;
```

### Verificar histórico limpo:
```sql
-- Deve retornar 0 registros
select count(*) as orphan_count
from public.task_history th
where th.task_id not in (select id from public.tasks);
```

---

## 📝 PRÓXIMOS PASSOS

Após executar as migrations, o código Flutter será atualizado para:

1. ✅ **Carregar produtos vinculados** da tabela `task_products`
2. ✅ **Permitir adicionar múltiplos produtos** a uma task
3. ✅ **Mostrar indicador** em produtos já vinculados a outras tasks
4. ✅ **Permitir desvincular** produto de uma task e vincular a outra
5. ✅ **Carregar assets existentes** ao editar task

---

## ⚠️ ROLLBACK (se necessário)

Se algo der errado, você pode reverter com:

```sql
begin;

-- Remover tabela task_products
drop table if exists public.task_products cascade;

commit;
```

**ATENÇÃO**: Isso apagará todos os vínculos de produtos! Use apenas em emergência.

---

**EXECUTE AS MIGRATIONS AGORA E ME AVISE QUANDO ESTIVER PRONTO!** 🚀

