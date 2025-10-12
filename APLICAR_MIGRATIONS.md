# 🚀 Como Aplicar as Migrations no Supabase

**Data**: 2025-01-10  
**Objetivo**: Aplicar todas as otimizações de performance no banco de dados

---

## 📋 Migrations Disponíveis

### 1. **Índices de Performance** (CRÍTICO)
**Arquivo**: `supabase/migrations/20250110_add_performance_indexes.sql`  
**Impacto**: ⚡ Queries 5-10x mais rápidas  
**Tempo**: ~30 segundos para executar

### 2. **Função RPC para Company Projects** (IMPORTANTE)
**Arquivo**: `supabase/migrations/20250110_fix_company_projects_rpc.sql`  
**Impacto**: ⚡ Resolve N+1 queries em CompanyDetailPage  
**Tempo**: ~5 segundos para executar

---

## 🎯 Método 1: Supabase Dashboard (RECOMENDADO)

### Passo a Passo:

1. **Acessar Supabase Dashboard**
   - Ir para: https://supabase.com/dashboard
   - Fazer login
   - Selecionar seu projeto

2. **Abrir SQL Editor**
   - No menu lateral, clicar em **"SQL Editor"**
   - Ou acessar diretamente: `https://supabase.com/dashboard/project/SEU_PROJECT_ID/sql`

3. **Aplicar Migration 1 - Índices**
   - Clicar em **"New query"**
   - Copiar TODO o conteúdo de `supabase/migrations/20250110_add_performance_indexes.sql`
   - Colar no editor
   - Clicar em **"Run"** (ou pressionar Ctrl+Enter)
   - ✅ Aguardar mensagem de sucesso

4. **Aplicar Migration 2 - RPC Function**
   - Clicar em **"New query"** novamente
   - Copiar TODO o conteúdo de `supabase/migrations/20250110_fix_company_projects_rpc.sql`
   - Colar no editor
   - Clicar em **"Run"** (ou pressionar Ctrl+Enter)
   - ✅ Aguardar mensagem de sucesso

5. **Verificar Aplicação**
   - No SQL Editor, executar:
   ```sql
   -- Verificar índices criados
   SELECT 
     schemaname,
     tablename,
     indexname
   FROM pg_indexes
   WHERE schemaname = 'public'
     AND indexname LIKE 'idx_%'
   ORDER BY tablename, indexname;
   
   -- Verificar função RPC
   SELECT 
     routine_name,
     routine_type
   FROM information_schema.routines
   WHERE routine_schema = 'public'
     AND routine_name = 'get_company_projects_with_stats';
   ```
   - ✅ Deve mostrar ~15 índices e 1 função

---

## 🎯 Método 2: Supabase CLI (AVANÇADO)

### Pré-requisitos:
```bash
# Instalar Supabase CLI
npm install -g supabase

# Fazer login
supabase login

# Linkar projeto
supabase link --project-ref SEU_PROJECT_ID
```

### Aplicar Migrations:
```bash
# Navegar para pasta do projeto
cd C:\Users\PC\Downloads\gestor_projetos_flutter

# Aplicar todas as migrations
supabase db push

# Ou aplicar individualmente
supabase db execute --file supabase/migrations/20250110_add_performance_indexes.sql
supabase db execute --file supabase/migrations/20250110_fix_company_projects_rpc.sql
```

---

## ✅ Validação Pós-Aplicação

### 1. Testar Índices

Execute no SQL Editor:
```sql
-- Testar query em tasks (deve usar índice)
EXPLAIN ANALYZE
SELECT * FROM tasks 
WHERE project_id = 'algum-uuid-valido'
  AND status = 'pending'
ORDER BY created_at DESC;

-- Procurar por "Index Scan" na saída
-- Se aparecer "Seq Scan", algo está errado
```

### 2. Testar Função RPC

Execute no SQL Editor:
```sql
-- Testar função RPC (substitua pelo UUID real de uma empresa)
SELECT * FROM get_company_projects_with_stats('b4734abd-6d76-472d-b218-1a9b7943445b');

-- Deve retornar projetos com todas as estatísticas
-- Não deve dar erro de "column p.end_date does not exist"
```

### 3. Testar no App

1. Executar o app Flutter
2. Navegar para CompanyDetailPage
3. Verificar logs no console:
   ```
   ✅ Deve aparecer:
   🚀 Carregando projetos com stats otimizado...
   🚀 Buscando projetos da empresa com stats (RPC): ...
   ✅ X projetos carregados com stats
   
   ❌ NÃO deve aparecer:
   ❌ Erro ao buscar projetos com stats: PostgrestException...
   ```

---

## 🐛 Troubleshooting

### Erro: "permission denied for schema public"
**Solução**: Você não tem permissões de admin. Peça ao owner do projeto para aplicar.

### Erro: "relation already exists"
**Solução**: Índice já foi criado. Pode ignorar ou dropar antes:
```sql
DROP INDEX IF EXISTS idx_tasks_project_id;
-- Depois executar a migration novamente
```

### Erro: "function already exists"
**Solução**: A migration já dropa e recria. Se persistir:
```sql
DROP FUNCTION IF EXISTS get_company_projects_with_stats(UUID);
-- Depois executar a migration novamente
```

### Erro: "column p.end_date does not exist"
**Solução**: A função antiga ainda está no banco. Execute a migration de fix:
```sql
-- Executar todo o conteúdo de:
supabase/migrations/20250110_fix_company_projects_rpc.sql
```

---

## 📊 Impacto Esperado Após Aplicação

### Antes:
- ⏱️ CompanyDetailPage: ~3-5s para carregar 10 projetos
- 📡 ~50 queries executadas
- 🐌 Queries lentas sem índices

### Depois:
- ⚡ CompanyDetailPage: ~0.3-0.5s para carregar 10 projetos
- 📡 1 query RPC executada
- 🚀 Queries rápidas com índices

---

## 📝 Checklist de Aplicação

- [ ] Acessar Supabase Dashboard
- [ ] Abrir SQL Editor
- [ ] Aplicar migration de índices
- [ ] Aplicar migration de RPC function
- [ ] Verificar índices criados (query de verificação)
- [ ] Verificar função RPC criada (query de verificação)
- [ ] Testar função RPC com UUID real
- [ ] Executar app Flutter
- [ ] Navegar para CompanyDetailPage
- [ ] Verificar que não há erros no console
- [ ] Verificar que projetos carregam rapidamente
- [ ] ✅ Tudo funcionando!

---

## 🎓 Dicas

1. **Backup**: Supabase faz backup automático, mas se quiser garantir:
   ```sql
   -- Criar snapshot antes de aplicar
   -- (Supabase Dashboard > Database > Backups)
   ```

2. **Rollback**: Se algo der errado, pode dropar:
   ```sql
   -- Dropar índices
   DROP INDEX IF EXISTS idx_tasks_project_id;
   DROP INDEX IF EXISTS idx_tasks_assigned_to;
   -- ... etc
   
   -- Dropar função
   DROP FUNCTION IF EXISTS get_company_projects_with_stats(UUID);
   ```

3. **Performance**: Após aplicar índices, execute:
   ```sql
   -- Atualizar estatísticas do PostgreSQL
   ANALYZE tasks;
   ANALYZE projects;
   ANALYZE project_members;
   ANALYZE payments;
   ANALYZE project_catalog_items;
   ```

---

## 🚀 Próximos Passos Após Aplicação

1. ✅ Testar app completamente
2. ✅ Verificar logs de performance
3. ✅ Monitorar uso de memória
4. ✅ Validar que tudo funciona
5. 🎉 Comemorar a performance melhorada!

---

**Autor**: Augment AI  
**Última Atualização**: 2025-01-10  
**Status**: Pronto para aplicar

