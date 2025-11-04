-- ============================================================================
-- Migration: Adicionar campo de descrição aos registros de tempo
-- Data: 2025-10-26
-- Descrição: Adiciona coluna 'description' à tabela time_logs para permitir
--            que usuários descrevam a atividade realizada durante a sessão
-- ============================================================================

-- Adicionar coluna description
ALTER TABLE public.time_logs 
ADD COLUMN IF NOT EXISTS description TEXT;

-- Comentário explicativo
COMMENT ON COLUMN public.time_logs.description IS 'Descrição opcional da atividade realizada durante a sessão de tempo';

-- Constraint para garantir que description não seja apenas espaços em branco
ALTER TABLE public.time_logs
  DROP CONSTRAINT IF EXISTS check_description_not_empty;

ALTER TABLE public.time_logs
  ADD CONSTRAINT check_description_not_empty
  CHECK (
    description IS NULL OR trim(description) != ''
  );

-- ============================================================================
-- CONCLUÍDO
-- ============================================================================

DO $$
BEGIN
  RAISE NOTICE '✅ Migration concluída com sucesso!';
  RAISE NOTICE '📝 Coluna description adicionada à tabela time_logs';
  RAISE NOTICE '✓  Constraint de validação criado';
END $$;

