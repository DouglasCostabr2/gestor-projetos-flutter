-- ============================================================================
-- Migration: Corrigir políticas RLS de time_logs para múltiplos responsáveis
-- Data: 2025-10-28
-- Descrição: Atualiza as políticas RLS de INSERT e UPDATE para permitir que
--            qualquer responsável (assigned_to ou assignee_user_ids) possa
--            criar e atualizar time_logs
-- ============================================================================

-- ============================================================================
-- PARTE 1: ATUALIZAR POLÍTICA DE INSERT
-- ============================================================================

-- Remove a política antiga de INSERT
DROP POLICY IF EXISTS "Users can insert time logs for assigned tasks" ON public.time_logs;

-- Cria a nova política que verifica ambos assigned_to e assignee_user_ids
CREATE POLICY "Users can insert time logs for assigned tasks"
  ON public.time_logs
  FOR INSERT
  WITH CHECK (
    -- Só pode criar time_log para si mesmo
    auth.uid() = user_id
    AND
    -- E apenas para tarefas atribuídas a ele (assigned_to ou assignee_user_ids)
    EXISTS (
      SELECT 1 FROM public.tasks
      WHERE tasks.id = task_id
        AND (
          tasks.assigned_to = auth.uid()
          OR auth.uid() = ANY(tasks.assignee_user_ids)
        )
    )
  );

-- ============================================================================
-- PARTE 2: ATUALIZAR POLÍTICA DE UPDATE
-- ============================================================================

-- Remove a política antiga de UPDATE
DROP POLICY IF EXISTS "Users can update own time logs" ON public.time_logs;

-- Cria a nova política que verifica ambos assigned_to e assignee_user_ids
CREATE POLICY "Users can update own time logs"
  ON public.time_logs
  FOR UPDATE
  USING (auth.uid() = user_id)
  WITH CHECK (
    auth.uid() = user_id
    AND
    EXISTS (
      SELECT 1 FROM public.tasks
      WHERE tasks.id = task_id
        AND (
          tasks.assigned_to = auth.uid()
          OR auth.uid() = ANY(tasks.assignee_user_ids)
        )
    )
  );

-- ============================================================================
-- CONCLUÍDO
-- ============================================================================

DO $$
BEGIN
  RAISE NOTICE '✅ Migration concluída com sucesso!';
  RAISE NOTICE '📝 Políticas RLS de time_logs atualizadas para múltiplos responsáveis';
  RAISE NOTICE '✓  INSERT policy: Verifica assigned_to e assignee_user_ids';
  RAISE NOTICE '✓  UPDATE policy: Verifica assigned_to e assignee_user_ids';
END $$;

