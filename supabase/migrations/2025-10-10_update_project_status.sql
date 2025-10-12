-- Migration: Atualizar status de projetos
-- Data: 2025-10-10
-- Descrição: Migra status antigos (active/inactive) para novos status e adiciona constraint

-- 1. PRIMEIRO: Remover constraint antiga para permitir a migração
ALTER TABLE projects DROP CONSTRAINT IF EXISTS projects_status_check;

-- 2. Migrar status antigos para novos
UPDATE projects
SET status = 'in_progress'
WHERE status = 'active';

UPDATE projects
SET status = 'paused'
WHERE status = 'inactive';

-- 3. Adicionar nova constraint com os 6 status válidos
ALTER TABLE projects ADD CONSTRAINT projects_status_check
CHECK (status IN ('not_started', 'negotiation', 'in_progress', 'paused', 'completed', 'cancelled'));

-- 4. Comentário explicativo
COMMENT ON COLUMN projects.status IS 'Status do projeto: not_started, negotiation, in_progress, paused, completed, cancelled';

