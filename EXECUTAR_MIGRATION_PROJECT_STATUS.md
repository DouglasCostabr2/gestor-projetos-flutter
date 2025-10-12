# 🚀 Migration: Atualizar Status de Projetos

## 📋 Resumo

Esta migration atualiza a coluna `status` da tabela `projects` para usar os novos status:

### Status Antigos → Novos
- `active` → `in_progress` (Em andamento)
- `inactive` → `paused` (Pausado)

### Novos Status Disponíveis
1. `not_started` - Não iniciado
2. `negotiation` - Em negociação
3. `in_progress` - Em andamento
4. `paused` - Pausado
5. `completed` - Concluído
6. `cancelled` - Cancelado

---

## 🗄️ Como Executar a Migration

### Passo 1: Acessar Supabase Dashboard
1. Abra o navegador
2. Acesse: https://app.supabase.com
3. Faça login
4. Selecione seu projeto

### Passo 2: Abrir SQL Editor
1. No menu lateral esquerdo, clique em **"SQL Editor"**
2. Clique em **"New Query"**

### Passo 3: Executar a Migration
1. Copie o conteúdo do arquivo `supabase/migrations/2025-10-10_update_project_status.sql`
2. Cole no SQL Editor
3. Clique em **"Run"** (ou pressione `Ctrl+Enter`)
4. Aguarde a mensagem de sucesso

---

## 📝 SQL da Migration

```sql
-- Migration: Atualizar status de projetos
-- Data: 2025-10-10
-- Descrição: Migra status antigos (active/inactive) para novos status e adiciona constraint

-- 1. Migrar status antigos para novos
UPDATE projects
SET status = 'in_progress'
WHERE status = 'active';

UPDATE projects
SET status = 'paused'
WHERE status = 'inactive';

-- 2. Adicionar constraint para validar apenas os novos status
-- Primeiro, remover constraint antiga se existir
ALTER TABLE projects DROP CONSTRAINT IF EXISTS projects_status_check;

-- Adicionar nova constraint com os 6 status válidos
ALTER TABLE projects ADD CONSTRAINT projects_status_check 
CHECK (status IN ('not_started', 'negotiation', 'in_progress', 'paused', 'completed', 'cancelled'));

-- 3. Comentário explicativo
COMMENT ON COLUMN projects.status IS 'Status do projeto: not_started, negotiation, in_progress, paused, completed, cancelled';
```

---

## ✅ Verificar se a Migration Funcionou

Execute esta query no SQL Editor para verificar:

```sql
-- Ver quantos projetos foram migrados
SELECT 
  status,
  COUNT(*) as total
FROM projects
GROUP BY status
ORDER BY total DESC;
```

**Resultado esperado:**
- Não deve haver mais projetos com status `active` ou `inactive`
- Todos os projetos devem ter um dos 6 novos status

---

## 🔧 Verificar Constraint

Execute esta query para verificar se a constraint foi criada:

```sql
-- Ver constraints da tabela projects
SELECT 
  conname as constraint_name,
  pg_get_constraintdef(oid) as constraint_definition
FROM pg_constraint
WHERE conrelid = 'projects'::regclass
  AND conname = 'projects_status_check';
```

**Resultado esperado:**
```
constraint_name       | constraint_definition
----------------------|-------------------------------------------------------
projects_status_check | CHECK ((status = ANY (ARRAY['not_started'::text, ...
```

---

## ⚠️ Importante

### Antes de Executar
- ✅ Faça backup do banco de dados (opcional, mas recomendado)
- ✅ Certifique-se de que não há operações críticas em andamento

### Depois de Executar
- ✅ Verifique se todos os projetos foram migrados corretamente
- ✅ Teste criar um novo projeto no app
- ✅ Teste editar um projeto existente
- ✅ Verifique se os badges de status estão exibindo corretamente

### Rollback (se necessário)
Se algo der errado, você pode reverter com:

```sql
-- Remover constraint
ALTER TABLE projects DROP CONSTRAINT IF EXISTS projects_status_check;

-- Voltar para status antigos (se necessário)
UPDATE projects SET status = 'active' WHERE status = 'in_progress';
UPDATE projects SET status = 'inactive' WHERE status = 'paused';

-- Recriar constraint antiga (se existia)
ALTER TABLE projects ADD CONSTRAINT projects_status_check 
CHECK (status IN ('active', 'inactive', 'archived'));
```

---

## 🎯 Próximos Passos

Após executar a migration:

1. ✅ Recarregue a aplicação Flutter
2. ✅ Navegue até um projeto
3. ✅ Verifique se o badge de status está correto
4. ✅ Tente editar um projeto e mudar o status
5. ✅ Crie um novo projeto e escolha um status

---

## 📊 Impacto

### Tabelas Afetadas
- `projects` - Coluna `status` atualizada

### Registros Afetados
- Todos os projetos com `status = 'active'` → `in_progress`
- Todos os projetos com `status = 'inactive'` → `paused`

### Compatibilidade
- ✅ O código Flutter já está preparado para os novos status
- ✅ Status antigos são automaticamente convertidos na UI
- ✅ Novos projetos usarão apenas os novos status

---

**Data de Criação**: 2025-10-10  
**Status**: ⏳ Aguardando Execução  
**Prioridade**: 🔴 Alta (necessário para usar novos status)

