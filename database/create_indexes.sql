-- ============================================================================
-- ÍNDICES PARA OTIMIZAÇÃO DE PERFORMANCE
-- ============================================================================
-- Este script cria índices para melhorar a performance das queries mais comuns.
-- Execute no Supabase SQL Editor.
--
-- IMPORTANTE: 
-- - Índices melhoram leitura mas podem deixar escrita um pouco mais lenta
-- - Monitore o tamanho do banco após criar índices
-- - Use EXPLAIN ANALYZE para verificar se os índices estão sendo usados
-- ============================================================================

-- ============================================================================
-- TASKS - Índices para queries de tasks
-- ============================================================================

-- Índice para buscar tasks por projeto (usado em ProjectsPage)
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

-- Índice para ordenar por prioridade
CREATE INDEX IF NOT EXISTS idx_tasks_priority 
ON tasks(priority);

-- Índice composto para query comum: tasks de um projeto com status específico
CREATE INDEX IF NOT EXISTS idx_tasks_project_status 
ON tasks(project_id, status);

-- Índice composto para query comum: tasks atribuídas a uma pessoa com status
CREATE INDEX IF NOT EXISTS idx_tasks_assigned_status 
ON tasks(assigned_to, status);

-- Índice para ordenar por data de criação
CREATE INDEX IF NOT EXISTS idx_tasks_created_at 
ON tasks(created_at DESC);

-- Índice para ordenar por data de atualização
CREATE INDEX IF NOT EXISTS idx_tasks_updated_at 
ON tasks(updated_at DESC);

-- ============================================================================
-- PROJECTS - Índices para queries de projetos
-- ============================================================================

-- Índice para buscar projetos por cliente
CREATE INDEX IF NOT EXISTS idx_projects_client_id 
ON projects(client_id);

-- Índice para buscar projetos por dono
CREATE INDEX IF NOT EXISTS idx_projects_owner_id 
ON projects(owner_id);

-- Índice para filtrar projetos por status
CREATE INDEX IF NOT EXISTS idx_projects_status 
ON projects(status);

-- Índice para filtrar projetos por prioridade
CREATE INDEX IF NOT EXISTS idx_projects_priority 
ON projects(priority);

-- Índice para ordenar por data de criação
CREATE INDEX IF NOT EXISTS idx_projects_created_at 
ON projects(created_at DESC);

-- Índice para ordenar por data de atualização
CREATE INDEX IF NOT EXISTS idx_projects_updated_at 
ON projects(updated_at DESC);

-- Índice para buscar por quem atualizou
CREATE INDEX IF NOT EXISTS idx_projects_updated_by 
ON projects(updated_by);

-- Índice composto para query comum: projetos de um cliente com status específico
CREATE INDEX IF NOT EXISTS idx_projects_client_status 
ON projects(client_id, status);

-- Índice composto para query comum: projetos de um dono com status
CREATE INDEX IF NOT EXISTS idx_projects_owner_status 
ON projects(owner_id, status);

-- Índice para buscar por data de início
CREATE INDEX IF NOT EXISTS idx_projects_start_date 
ON projects(start_date);

-- Índice para buscar por data de vencimento
CREATE INDEX IF NOT EXISTS idx_projects_due_date 
ON projects(due_date);

-- ============================================================================
-- CLIENTS - Índices para queries de clientes
-- ============================================================================

-- Índice para buscar clientes por categoria
CREATE INDEX IF NOT EXISTS idx_clients_category_id 
ON clients(category_id);

-- Índice para filtrar clientes por país
CREATE INDEX IF NOT EXISTS idx_clients_country 
ON clients(country);

-- Índice para filtrar clientes por estado
CREATE INDEX IF NOT EXISTS idx_clients_state 
ON clients(state);

-- Índice para filtrar clientes por cidade
CREATE INDEX IF NOT EXISTS idx_clients_city 
ON clients(city);

-- Índice para buscar por email (único)
CREATE INDEX IF NOT EXISTS idx_clients_email 
ON clients(email);

-- Índice para buscar por telefone
CREATE INDEX IF NOT EXISTS idx_clients_phone 
ON clients(phone);

-- Índice para ordenar por data de criação
CREATE INDEX IF NOT EXISTS idx_clients_created_at 
ON clients(created_at DESC);

-- Índice composto para query comum: clientes de um país e estado
CREATE INDEX IF NOT EXISTS idx_clients_country_state 
ON clients(country, state);

-- ============================================================================
-- PROFILES - Índices para queries de perfis de usuários
-- ============================================================================

-- Índice para buscar por email
CREATE INDEX IF NOT EXISTS idx_profiles_email
ON profiles(email);

-- Índice para filtrar por role (se a coluna existir)
-- CREATE INDEX IF NOT EXISTS idx_profiles_role
-- ON profiles(role);

-- Índice para ordenar por nome completo
CREATE INDEX IF NOT EXISTS idx_profiles_full_name
ON profiles(full_name);

-- Nota: Verifique quais colunas existem na sua tabela profiles antes de criar índices
-- Execute: SELECT column_name FROM information_schema.columns WHERE table_name = 'profiles';

-- ============================================================================
-- PACKAGE_ITEMS - Índices para itens de pacotes
-- ============================================================================

-- Índice para buscar itens por pacote
CREATE INDEX IF NOT EXISTS idx_package_items_package_id 
ON package_items(package_id);

-- Índice para buscar itens por produto
CREATE INDEX IF NOT EXISTS idx_package_items_product_id 
ON package_items(product_id);

-- Índice composto para query comum
CREATE INDEX IF NOT EXISTS idx_package_items_package_product 
ON package_items(package_id, product_id);

-- ============================================================================
-- CATEGORIES - Índices para categorias
-- ============================================================================

-- Índice para buscar por tipo
CREATE INDEX IF NOT EXISTS idx_categories_type 
ON categories(type);

-- Índice para ordenar por nome
CREATE INDEX IF NOT EXISTS idx_categories_name 
ON categories(name);

-- ============================================================================
-- VERIFICAR ÍNDICES CRIADOS
-- ============================================================================

-- Execute esta query para ver todos os índices criados:
/*
SELECT 
    schemaname,
    tablename,
    indexname,
    indexdef
FROM pg_indexes
WHERE schemaname = 'public'
ORDER BY tablename, indexname;
*/

-- ============================================================================
-- ANALISAR PERFORMANCE DE QUERIES
-- ============================================================================

-- Use EXPLAIN ANALYZE para verificar se os índices estão sendo usados:
/*
EXPLAIN ANALYZE
SELECT * FROM tasks WHERE project_id = 'some-uuid';
*/

-- Procure por "Index Scan" no resultado - isso significa que o índice está sendo usado
-- Se aparecer "Seq Scan", o índice não está sendo usado (pode ser normal para tabelas pequenas)

-- ============================================================================
-- MANUTENÇÃO DE ÍNDICES
-- ============================================================================

-- Reindexar tabelas periodicamente (recomendado mensalmente):
/*
REINDEX TABLE tasks;
REINDEX TABLE projects;
REINDEX TABLE clients;
REINDEX TABLE profiles;
*/

-- Analisar tabelas para atualizar estatísticas (recomendado semanalmente):
/*
ANALYZE tasks;
ANALYZE projects;
ANALYZE clients;
ANALYZE profiles;
*/

-- ============================================================================
-- MONITORAMENTO
-- ============================================================================

-- Ver tamanho dos índices:
/*
SELECT
    schemaname,
    tablename,
    indexname,
    pg_size_pretty(pg_relation_size(indexrelid)) AS index_size
FROM pg_stat_user_indexes
WHERE schemaname = 'public'
ORDER BY pg_relation_size(indexrelid) DESC;
*/

-- Ver índices não utilizados (considere remover):
/*
SELECT
    schemaname,
    tablename,
    indexname,
    idx_scan,
    idx_tup_read,
    idx_tup_fetch
FROM pg_stat_user_indexes
WHERE schemaname = 'public'
    AND idx_scan = 0
ORDER BY pg_relation_size(indexrelid) DESC;
*/

-- ============================================================================
-- NOTAS IMPORTANTES
-- ============================================================================

-- 1. Índices ocupam espaço em disco - monitore o tamanho do banco
-- 2. Índices deixam INSERT/UPDATE/DELETE um pouco mais lentos
-- 3. Para tabelas pequenas (<1000 linhas), índices podem não fazer diferença
-- 4. PostgreSQL escolhe automaticamente usar ou não o índice
-- 5. Mantenha estatísticas atualizadas com ANALYZE
-- 6. Reindexe periodicamente para manter performance

-- ============================================================================
-- FIM DO SCRIPT
-- ============================================================================

