-- Migration: Fix updated_by field in tasks, companies, projects and clients tables
-- Data: 2025-10-10
-- Descrição: Preenche o campo updated_by para registros que não têm updated_by

-- Atualizar todas as tarefas que não têm updated_by
-- Usa created_by como fallback (quem criou foi o último a "atualizar")
UPDATE tasks
SET updated_by = created_by
WHERE updated_by IS NULL AND created_by IS NOT NULL;

-- Atualizar todas as empresas que não têm updated_by
-- Usa owner_id como fallback
UPDATE companies
SET updated_by = owner_id
WHERE updated_by IS NULL AND owner_id IS NOT NULL;

-- Atualizar todos os projetos que não têm updated_by
-- Usa created_by como fallback, se não tiver usa owner_id
UPDATE projects
SET updated_by = COALESCE(created_by, owner_id)
WHERE updated_by IS NULL AND (created_by IS NOT NULL OR owner_id IS NOT NULL);

-- Atualizar todos os clientes que não têm updated_by
-- Usa owner_id como fallback
UPDATE clients
SET updated_by = owner_id
WHERE updated_by IS NULL AND owner_id IS NOT NULL;

-- Comentários explicativos
COMMENT ON COLUMN tasks.updated_by IS 'ID do usuário que fez a última atualização na tarefa';
COMMENT ON COLUMN companies.updated_by IS 'ID do usuário que fez a última atualização na empresa';
COMMENT ON COLUMN projects.updated_by IS 'ID do usuário que fez a última atualização no projeto';
COMMENT ON COLUMN clients.updated_by IS 'ID do usuário que fez a última atualização no cliente';

