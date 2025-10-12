# 🚀 EXECUTAR MIGRATION - FIX UPDATED_BY

Data: 2025-10-10

---

## ❌ PROBLEMA ATUAL

As tarefas e empresas existentes no banco de dados não têm o campo `updated_by` preenchido, então a coluna "Última Atualização" não mostra o avatar e nome do usuário que fez a última atualização.

**Sintoma**:
- Coluna "Última Atualização" mostra apenas a data (ex: 09/10/2025)
- Não aparece avatar e nome do usuário
- Afeta tanto a tabela de **Tarefas** quanto a tabela de **Empresas**

**Causa**:
- Campo `updated_by` está `NULL` nos registros existentes
- O código foi corrigido para preencher `updated_by` em novas atualizações, mas os registros antigos continuam sem esse campo

---

## ✅ SOLUÇÃO RÁPIDA (2 MINUTOS)

### Passo 1: Copiar SQL

Abra o arquivo: `supabase/migrations/2025-10-10_fix_updated_by_field.sql`

Copie TODO o conteúdo (Ctrl+A, Ctrl+C)

### Passo 2: Executar no Supabase

1. Acesse: https://app.supabase.com
2. Selecione seu projeto
3. Menu lateral → **SQL Editor**
4. Clique em **New Query**
5. Cole o SQL (Ctrl+V)
6. Clique em **Run** (ou Ctrl+Enter)
7. Aguarde aparecer "Success. X rows affected" (onde X é o número de tarefas atualizadas)

### Passo 3: Recarregar a Página do Projeto

1. No app Flutter, volte para a página do projeto
2. Recarregue a página (feche e abra novamente)
3. Agora a coluna "Última Atualização" deve mostrar o avatar e nome do usuário

---

## 📋 O QUE A MIGRATION FAZ

```sql
-- Atualizar todas as tarefas que não têm updated_by
UPDATE tasks
SET updated_by = created_by
WHERE updated_by IS NULL AND created_by IS NOT NULL;

-- Atualizar todas as empresas que não têm updated_by
UPDATE companies
SET updated_by = owner_id
WHERE updated_by IS NULL AND owner_id IS NOT NULL;
```

**Explicação**:
- **Tarefas**: Preenche `updated_by` com o valor de `created_by` para todas as tarefas que não têm `updated_by`
- **Empresas**: Preenche `updated_by` com o valor de `owner_id` para todas as empresas que não têm `updated_by`
- Isso faz sentido porque se o registro nunca foi atualizado, o último "atualizador" é o criador/dono
- Apenas registros com `created_by`/`owner_id` preenchido serão atualizados

---

## 🔍 VERIFICAR SE DEU CERTO

Após executar a migration, execute estas queries para verificar:

```sql
-- Ver quantas tarefas ainda têm updated_by NULL
SELECT COUNT(*) as tarefas_sem_updated_by
FROM tasks
WHERE updated_by IS NULL;

-- Ver quantas empresas ainda têm updated_by NULL
SELECT COUNT(*) as empresas_sem_updated_by
FROM companies
WHERE updated_by IS NULL;
```

**Resultado esperado**: `0` (zero registros sem updated_by em ambas as tabelas)

---

## 📊 ESTATÍSTICAS

Para ver quantos registros foram atualizados:

```sql
-- Ver quantas tarefas têm updated_by preenchido
SELECT
  COUNT(*) as total_tarefas,
  COUNT(updated_by) as tarefas_com_updated_by,
  COUNT(*) - COUNT(updated_by) as tarefas_sem_updated_by
FROM tasks;

-- Ver quantas empresas têm updated_by preenchido
SELECT
  COUNT(*) as total_empresas,
  COUNT(updated_by) as empresas_com_updated_by,
  COUNT(*) - COUNT(updated_by) as empresas_sem_updated_by
FROM companies;
```

---

## ⚠️ IMPORTANTE

- Esta migration é **segura** e **idempotente** (pode ser executada múltiplas vezes sem problemas)
- Não afeta tarefas que já têm `updated_by` preenchido
- Não deleta nenhum dado
- Apenas preenche campos vazios

---

## 🎯 PRÓXIMOS PASSOS

Após executar a migration:

1. ✅ Todas as tarefas e empresas existentes terão `updated_by` preenchido
2. ✅ A coluna "Última Atualização" mostrará avatar e nome do usuário em ambas as tabelas
3. ✅ Novas atualizações continuarão preenchendo `updated_by` automaticamente (código já corrigido)

---

## 🐛 TROUBLESHOOTING

### Erro: "permission denied for table tasks"

Você precisa ter permissões de admin no Supabase. Peça para o administrador do projeto executar a migration.

### Ainda não aparece avatar após executar

1. Verifique se a migration foi executada com sucesso
2. Recarregue a página do projeto no app (feche e abra novamente)
3. Verifique se as tarefas têm `created_by` preenchido (execute a query de verificação acima)

### Alguns registros ainda não têm avatar

Isso pode acontecer se:
- O registro não tem `created_by`/`owner_id` preenchido (registros muito antigos)
- O registro foi criado por um usuário que foi deletado do sistema

Nesse caso, você pode atualizar manualmente:

```sql
-- Atualizar tarefas sem created_by para usar o usuário atual
UPDATE tasks
SET updated_by = 'SEU_USER_ID_AQUI'
WHERE updated_by IS NULL;

-- Atualizar empresas sem owner_id para usar o usuário atual
UPDATE companies
SET updated_by = 'SEU_USER_ID_AQUI'
WHERE updated_by IS NULL;
```

