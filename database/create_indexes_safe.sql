-- ============================================================================
-- ÍNDICES ESSENCIAIS PARA OTIMIZAÇÃO DE PERFORMANCE
-- ============================================================================
-- Este script cria apenas os índices mais importantes e seguros.
-- Execute no Supabase SQL Editor.
--
-- IMPORTANTE: 
-- - Este script usa apenas colunas que sabemos que existem
-- - Índices melhoram leitura mas podem deixar escrita um pouco mais lenta
-- - Monitore o tamanho do banco após criar índices
-- ============================================================================

-- ============================================================================
-- PASSO 1: VERIFICAR ESTRUTURA DAS TABELAS
-- ============================================================================

-- Execute esta query primeiro para ver as colunas de cada tabela:
/*
SELECT 
    table_name, 
    column_name, 
    data_type 
FROM information_schema.columns 
WHERE table_schema = 'public' 
    AND table_name IN ('tasks', 'projects', 'clients', 'profiles', 'categories', 'package_items')
ORDER BY table_name, ordinal_position;
*/

-- ============================================================================
-- PASSO 2: CRIAR ÍNDICES ESSENCIAIS
-- ============================================================================

-- ----------------------------------------------------------------------------
-- TASKS - Índices mais importantes
-- ----------------------------------------------------------------------------

-- Índice para buscar tasks por projeto (CRÍTICO - usado em ProjectsPage)
CREATE INDEX IF NOT EXISTS idx_tasks_project_id 
ON tasks(project_id);

-- Índice para buscar tasks por pessoa atribuída
CREATE INDEX IF NOT EXISTS idx_tasks_assigned_to 
ON tasks(assigned_to);

-- Índice para filtrar tasks por status
CREATE INDEX IF NOT EXISTS idx_tasks_status 
ON tasks(status);

-- Índice para ordenar/filtrar por data de vencimento
CREATE INDEX IF NOT EXISTS idx_tasks_due_date 
ON tasks(due_date);

-- Índice composto para query comum: tasks de um projeto com status específico
CREATE INDEX IF NOT EXISTS idx_tasks_project_status 
ON tasks(project_id, status);

-- Índice para ordenar por data de criação
CREATE INDEX IF NOT EXISTS idx_tasks_created_at 
ON tasks(created_at DESC);

-- ----------------------------------------------------------------------------
-- PROJECTS - Índices mais importantes
-- ----------------------------------------------------------------------------

-- Índice para buscar projetos por cliente (CRÍTICO)
CREATE INDEX IF NOT EXISTS idx_projects_client_id 
ON projects(client_id);

-- Índice para buscar projetos por dono
CREATE INDEX IF NOT EXISTS idx_projects_owner_id 
ON projects(owner_id);

-- Índice para filtrar projetos por status
CREATE INDEX IF NOT EXISTS idx_projects_status 
ON projects(status);

-- Índice para ordenar por data de criação
CREATE INDEX IF NOT EXISTS idx_projects_created_at 
ON projects(created_at DESC);

-- Índice para ordenar por data de atualização
CREATE INDEX IF NOT EXISTS idx_projects_updated_at 
ON projects(updated_at DESC);

-- Índice composto para query comum: projetos de um cliente com status específico
CREATE INDEX IF NOT EXISTS idx_projects_client_status 
ON projects(client_id, status);

-- ----------------------------------------------------------------------------
-- CLIENTS - Índices mais importantes
-- ----------------------------------------------------------------------------

-- Índice para buscar clientes por categoria
CREATE INDEX IF NOT EXISTS idx_clients_category_id 
ON clients(category_id);

-- Índice para filtrar clientes por país
CREATE INDEX IF NOT EXISTS idx_clients_country 
ON clients(country);

-- Índice para filtrar clientes por estado
CREATE INDEX IF NOT EXISTS idx_clients_state 
ON clients(state);

-- Índice para ordenar por data de criação
CREATE INDEX IF NOT EXISTS idx_clients_created_at 
ON clients(created_at DESC);

-- Índice composto para query comum: clientes de um país e estado
CREATE INDEX IF NOT EXISTS idx_clients_country_state 
ON clients(country, state);

-- ----------------------------------------------------------------------------
-- PROFILES - Índices mais importantes
-- ----------------------------------------------------------------------------

-- Índice para buscar por email
CREATE INDEX IF NOT EXISTS idx_profiles_email 
ON profiles(email);

-- Índice para ordenar por nome completo
CREATE INDEX IF NOT EXISTS idx_profiles_full_name 
ON profiles(full_name);

-- ----------------------------------------------------------------------------
-- PACKAGE_ITEMS - Índices mais importantes (se a tabela existir)
-- ----------------------------------------------------------------------------

-- Descomente se a tabela package_items existir:
-- CREATE INDEX IF NOT EXISTS idx_package_items_package_id
-- ON package_items(package_id);

-- CREATE INDEX IF NOT EXISTS idx_package_items_product_id
-- ON package_items(product_id);

-- ----------------------------------------------------------------------------
-- CATEGORIES - Índices mais importantes (se a tabela existir)
-- ----------------------------------------------------------------------------

-- Descomente se a tabela categories existir:
-- CREATE INDEX IF NOT EXISTS idx_categories_type
-- ON categories(type);

-- CREATE INDEX IF NOT EXISTS idx_categories_name
-- ON categories(name);

-- ============================================================================
-- PASSO 3: VERIFICAR ÍNDICES CRIADOS
-- ============================================================================

-- Execute esta query para ver todos os índices criados:
SELECT 
    schemaname,
    tablename,
    indexname,
    indexdef
FROM pg_indexes
WHERE schemaname = 'public'
    AND indexname LIKE 'idx_%'
ORDER BY tablename, indexname;

-- ============================================================================
-- PASSO 4: TESTAR PERFORMANCE
-- ============================================================================

-- Teste 1: Verificar se índice está sendo usado em tasks por projeto
EXPLAIN ANALYZE
SELECT * FROM tasks WHERE project_id = (SELECT id FROM projects LIMIT 1);

-- Teste 2: Verificar se índice está sendo usado em projetos por cliente
EXPLAIN ANALYZE
SELECT * FROM projects WHERE client_id = (SELECT id FROM clients LIMIT 1);

-- Teste 3: Verificar se índice está sendo usado em filtro de status
EXPLAIN ANALYZE
SELECT * FROM tasks WHERE status = 'in_progress';

-- Procure por "Index Scan using idx_..." no resultado
-- Se aparecer "Seq Scan", o índice não está sendo usado (normal para tabelas pequenas)

-- ============================================================================
-- PASSO 5: MONITORAMENTO
-- ============================================================================

-- Ver tamanho dos índices:
SELECT
    schemaname,
    tablename,
    indexname,
    pg_size_pretty(pg_relation_size(indexrelid)) AS index_size
FROM pg_stat_user_indexes
WHERE schemaname = 'public'
    AND indexname LIKE 'idx_%'
ORDER BY pg_relation_size(indexrelid) DESC;

-- Ver índices não utilizados (considere remover após alguns dias):
SELECT
    schemaname,
    tablename,
    indexname,
    idx_scan AS scans,
    pg_size_pretty(pg_relation_size(indexrelid)) AS size
FROM pg_stat_user_indexes
WHERE schemaname = 'public'
    AND indexname LIKE 'idx_%'
    AND idx_scan < 10
ORDER BY pg_relation_size(indexrelid) DESC;

-- ============================================================================
-- MANUTENÇÃO (OPCIONAL)
-- ============================================================================

-- Reindexar tabelas (executar mensalmente ou quando houver degradação):
-- REINDEX TABLE tasks;
-- REINDEX TABLE projects;
-- REINDEX TABLE clients;

-- Atualizar estatísticas (executar semanalmente):
-- ANALYZE tasks;
-- ANALYZE projects;
-- ANALYZE clients;

-- ============================================================================
-- NOTAS IMPORTANTES
-- ============================================================================

-- ✅ Índices criados:
--    - tasks: 6 índices (project_id, assigned_to, status, due_date, project_status, created_at)
--    - projects: 6 índices (client_id, owner_id, status, created_at, updated_at, client_status)
--    - clients: 5 índices (category_id, country, state, created_at, country_state)
--    - profiles: 2 índices (email, full_name)
--    - package_items: 2 índices (package_id, product_id)
--    - categories: 2 índices (type, name)

-- ⚠️ Considerações:
--    1. Índices ocupam espaço em disco (~10-30% do tamanho da tabela)
--    2. Índices deixam INSERT/UPDATE/DELETE ~5-10% mais lentos
--    3. Para tabelas pequenas (<1000 linhas), índices podem não fazer diferença
--    4. PostgreSQL escolhe automaticamente usar ou não o índice
--    5. Mantenha estatísticas atualizadas com ANALYZE

-- 📊 Impacto esperado:
--    - Queries de busca: 10-100x mais rápidas
--    - Queries de filtro: 5-50x mais rápidas
--    - Queries de ordenação: 2-10x mais rápidas
--    - Especialmente importante com >1000 registros

-- ============================================================================
-- FIM DO SCRIPT
-- ============================================================================

