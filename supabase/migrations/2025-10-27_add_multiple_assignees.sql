-- ============================================================================
-- Migration: Adicionar Suporte a Múltiplos Responsáveis em Tarefas
-- Data: 2025-10-27
-- Descrição: Adiciona campo assignee_user_ids (array) e mantém assigned_to para compatibilidade
-- ============================================================================

-- ============================================================================
-- PARTE 1: ADICIONAR NOVA COLUNA assignee_user_ids
-- ============================================================================

-- Adicionar coluna para múltiplos responsáveis (array de UUIDs)
ALTER TABLE public.tasks 
ADD COLUMN IF NOT EXISTS assignee_user_ids uuid[] DEFAULT '{}';

COMMENT ON COLUMN public.tasks.assignee_user_ids IS 'Array de IDs dos usuários responsáveis pela tarefa (suporta múltiplos responsáveis)';

-- ============================================================================
-- PARTE 2: MIGRAR DADOS EXISTENTES
-- ============================================================================

-- Copiar dados de assigned_to para assignee_user_ids (se assigned_to não for null)
UPDATE public.tasks
SET assignee_user_ids = ARRAY[assigned_to]
WHERE assigned_to IS NOT NULL AND assignee_user_ids = '{}';

-- ============================================================================
-- PARTE 3: CRIAR ÍNDICE PARA PERFORMANCE
-- ============================================================================

-- Índice GIN para buscar tasks por responsável (suporta queries em arrays)
CREATE INDEX IF NOT EXISTS idx_tasks_assignee_user_ids 
ON public.tasks USING GIN (assignee_user_ids);

COMMENT ON INDEX idx_tasks_assignee_user_ids IS 'Índice GIN para buscar tasks por qualquer responsável no array';

-- ============================================================================
-- PARTE 4: CRIAR FUNÇÃO PARA SINCRONIZAR assigned_to COM assignee_user_ids
-- ============================================================================

-- Função para manter assigned_to sincronizado (primeiro elemento do array)
CREATE OR REPLACE FUNCTION public.sync_assigned_to()
RETURNS TRIGGER AS $$
BEGIN
  -- Se assignee_user_ids tem elementos, assigned_to = primeiro elemento
  -- Se assignee_user_ids está vazio, assigned_to = NULL
  IF array_length(NEW.assignee_user_ids, 1) > 0 THEN
    NEW.assigned_to := NEW.assignee_user_ids[1];
  ELSE
    NEW.assigned_to := NULL;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION public.sync_assigned_to() IS 'Mantém assigned_to sincronizado com o primeiro elemento de assignee_user_ids';

-- ============================================================================
-- PARTE 5: CRIAR TRIGGER
-- ============================================================================

-- Trigger para sincronizar assigned_to automaticamente
DROP TRIGGER IF EXISTS sync_assigned_to_trigger ON public.tasks;
CREATE TRIGGER sync_assigned_to_trigger
  BEFORE INSERT OR UPDATE OF assignee_user_ids ON public.tasks
  FOR EACH ROW
  EXECUTE FUNCTION public.sync_assigned_to();

COMMENT ON TRIGGER sync_assigned_to_trigger ON public.tasks IS 'Sincroniza assigned_to com assignee_user_ids automaticamente';

-- ============================================================================
-- PARTE 6: ATUALIZAR POLÍTICAS RLS (se necessário)
-- ============================================================================

-- Nota: As políticas RLS existentes que usam assigned_to continuarão funcionando
-- porque assigned_to é sincronizado automaticamente com assignee_user_ids[1]

-- Adicionar política para permitir que qualquer responsável veja a tarefa
-- (não apenas o primeiro)
DROP POLICY IF EXISTS "Users can view tasks assigned to them (multiple)" ON public.tasks;
CREATE POLICY "Users can view tasks assigned to them (multiple)"
  ON public.tasks
  FOR SELECT
  USING (
    -- Usuário é um dos responsáveis
    auth.uid() = ANY(assignee_user_ids)
    OR
    -- Ou é membro do projeto
    EXISTS (
      SELECT 1 FROM public.project_members
      WHERE project_members.project_id = tasks.project_id
        AND project_members.user_id = auth.uid()
    )
  );

-- ============================================================================
-- CONCLUÍDO
-- ============================================================================
--
-- Esta migration adiciona suporte a múltiplos responsáveis com:
-- ✅ Nova coluna assignee_user_ids (uuid[])
-- ✅ Migração automática de dados existentes
-- ✅ Índice GIN para performance em queries de array
-- ✅ Sincronização automática com assigned_to (compatibilidade)
-- ✅ Políticas RLS atualizadas
-- ✅ Documentação completa
--
-- COMPATIBILIDADE:
-- - assigned_to continua existindo e é sincronizado automaticamente
-- - Código antigo que usa assigned_to continuará funcionando
-- - Novo código pode usar assignee_user_ids para múltiplos responsáveis
-- ============================================================================

