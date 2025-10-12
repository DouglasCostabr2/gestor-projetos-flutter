-- Migration: Adicionar coluna description_json à tabela projects
-- Data: 2025-10-08
-- Descrição: Adiciona suporte para rich text (AppFlowy Editor) nos projetos

-- Adicionar coluna description_json para armazenar o JSON do rich text
ALTER TABLE projects 
ADD COLUMN IF NOT EXISTS description_json TEXT;

-- Comentário explicativo
COMMENT ON COLUMN projects.description_json IS 'JSON do rich text editor (AppFlowy Editor) - contém formatação completa, checklists, listas, etc.';

-- A coluna description continua existindo para texto plano (compatibilidade e busca)
COMMENT ON COLUMN projects.description IS 'Texto plano da descrição - usado para busca e compatibilidade';

-- Índice para busca (opcional - se você fizer buscas frequentes)
-- CREATE INDEX IF NOT EXISTS idx_projects_description_json ON projects USING gin (to_tsvector('portuguese', description_json));

