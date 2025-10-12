-- ============================================================================
-- ÍNDICES ESSENCIAIS - VERSÃO MÍNIMA E SEGURA
-- ============================================================================
-- Este script cria APENAS os índices mais críticos para as tabelas principais.
-- Execute no Supabase SQL Editor.
--
-- Tabelas cobertas: tasks, projects, clients, profiles
-- Tempo estimado: < 1 minuto
-- ============================================================================

-- ============================================================================
-- TASKS - Índices críticos
-- ============================================================================

-- CRÍTICO: Buscar tasks por projeto (usado em ProjectsPage)
-- Este é o índice mais importante para eliminar o problema de N+1 queries
CREATE INDEX IF NOT EXISTS idx_tasks_project_id 
ON tasks(project_id);

-- IMPORTANTE: Buscar tasks por pessoa atribuída
CREATE INDEX IF NOT EXISTS idx_tasks_assigned_to 
ON tasks(assigned_to);

-- IMPORTANTE: Filtrar tasks por status
CREATE INDEX IF NOT EXISTS idx_tasks_status 
ON tasks(status);

-- ÚTIL: Ordenar por data de criação
CREATE INDEX IF NOT EXISTS idx_tasks_created_at 
ON tasks(created_at DESC);

-- ============================================================================
-- PROJECTS - Índices críticos
-- ============================================================================

-- CRÍTICO: Buscar projetos por cliente
CREATE INDEX IF NOT EXISTS idx_projects_client_id 
ON projects(client_id);

-- IMPORTANTE: Buscar projetos por dono
CREATE INDEX IF NOT EXISTS idx_projects_owner_id 
ON projects(owner_id);

-- IMPORTANTE: Filtrar projetos por status
CREATE INDEX IF NOT EXISTS idx_projects_status 
ON projects(status);

-- ÚTIL: Ordenar por data de criação
CREATE INDEX IF NOT EXISTS idx_projects_created_at 
ON projects(created_at DESC);

-- ÚTIL: Ordenar por data de atualização
CREATE INDEX IF NOT EXISTS idx_projects_updated_at 
ON projects(updated_at DESC);

-- ============================================================================
-- CLIENTS - Índices críticos
-- ============================================================================

-- IMPORTANTE: Filtrar clientes por país
CREATE INDEX IF NOT EXISTS idx_clients_country 
ON clients(country);

-- IMPORTANTE: Filtrar clientes por estado
CREATE INDEX IF NOT EXISTS idx_clients_state 
ON clients(state);

-- ÚTIL: Ordenar por data de criação
CREATE INDEX IF NOT EXISTS idx_clients_created_at 
ON clients(created_at DESC);

-- ============================================================================
-- PROFILES - Índices críticos
-- ============================================================================

-- IMPORTANTE: Buscar por email
CREATE INDEX IF NOT EXISTS idx_profiles_email 
ON profiles(email);

-- ÚTIL: Ordenar por nome completo
CREATE INDEX IF NOT EXISTS idx_profiles_full_name 
ON profiles(full_name);

-- ============================================================================
-- VERIFICAR ÍNDICES CRIADOS
-- ============================================================================

-- Execute esta query para confirmar que os índices foram criados:
SELECT 
    tablename,
    indexname,
    indexdef
FROM pg_indexes
WHERE schemaname = 'public'
    AND indexname LIKE 'idx_%'
ORDER BY tablename, indexname;

-- ============================================================================
-- TESTAR PERFORMANCE
-- ============================================================================

-- Teste 1: Verificar se o índice mais crítico está funcionando
-- (Este é o que resolve o problema de N+1 queries)
EXPLAIN ANALYZE
SELECT * FROM tasks 
WHERE project_id = (SELECT id FROM projects LIMIT 1);

-- Resultado esperado: "Index Scan using idx_tasks_project_id"
-- Se aparecer "Seq Scan", o índice não está sendo usado (normal se a tabela for pequena)

-- ============================================================================
-- RESUMO
-- ============================================================================

-- ✅ Índices criados:
--    TASKS (4):
--      - idx_tasks_project_id (CRÍTICO)
--      - idx_tasks_assigned_to
--      - idx_tasks_status
--      - idx_tasks_created_at
--
--    PROJECTS (5):
--      - idx_projects_client_id (CRÍTICO)
--      - idx_projects_owner_id
--      - idx_projects_status
--      - idx_projects_created_at
--      - idx_projects_updated_at
--
--    CLIENTS (3):
--      - idx_clients_country
--      - idx_clients_state
--      - idx_clients_created_at
--
--    PROFILES (2):
--      - idx_profiles_email
--      - idx_profiles_full_name
--
-- 📊 Impacto esperado:
--    - Queries de tasks por projeto: 10-100x mais rápidas
--    - Filtros e ordenações: 5-50x mais rápidas
--    - Especialmente importante com >1000 registros
--
-- ⚠️ Notas:
--    - Índices ocupam ~10-30% do tamanho da tabela
--    - INSERT/UPDATE/DELETE ficam ~5-10% mais lentos
--    - Para tabelas pequenas (<1000 linhas), pode não fazer diferença
--    - PostgreSQL decide automaticamente se usa o índice ou não

-- ============================================================================
-- FIM DO SCRIPT
-- ============================================================================

