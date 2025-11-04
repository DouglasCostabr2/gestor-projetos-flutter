-- Migration: Fix RLS policies for task_comments table
-- Description: Adds proper Row Level Security policies to allow users to insert, view, update, and delete comments
-- Date: 2025-10-28

-- ============================================================================
-- PARTE 1: HABILITAR RLS NA TABELA task_comments
-- ============================================================================

ALTER TABLE public.task_comments ENABLE ROW LEVEL SECURITY;

-- ============================================================================
-- PARTE 2: REMOVER POLÍTICAS ANTIGAS (se existirem)
-- ============================================================================

DROP POLICY IF EXISTS "Users can view task comments" ON public.task_comments;
DROP POLICY IF EXISTS "Users can insert task comments" ON public.task_comments;
DROP POLICY IF EXISTS "Users can update own task comments" ON public.task_comments;
DROP POLICY IF EXISTS "Users can delete own task comments" ON public.task_comments;

-- ============================================================================
-- PARTE 3: CRIAR POLÍTICAS DE SELECT (Visualizar comentários)
-- ============================================================================

-- Política: Usuários podem ver comentários de tarefas que eles têm acesso
-- (tarefas atribuídas a eles ou tarefas de projetos que eles participam)
CREATE POLICY "Users can view task comments"
  ON public.task_comments
  FOR SELECT
  USING (
    -- Ver comentários de tarefas atribuídas a eles
    EXISTS (
      SELECT 1 FROM public.tasks
      WHERE tasks.id = task_comments.task_id
        AND (
          tasks.assigned_to = auth.uid()
          OR auth.uid() = ANY(tasks.assignee_user_ids)
        )
    )
    OR
    -- Ver comentários de tarefas de projetos que eles participam
    EXISTS (
      SELECT 1 FROM public.tasks t
      INNER JOIN public.project_members pm ON pm.project_id = t.project_id
      WHERE t.id = task_comments.task_id
        AND pm.user_id = auth.uid()
    )
  );

-- ============================================================================
-- PARTE 4: CRIAR POLÍTICAS DE INSERT (Inserir comentários)
-- ============================================================================

-- Política: Usuários podem inserir comentários apenas em tarefas que eles têm acesso
CREATE POLICY "Users can insert task comments"
  ON public.task_comments
  FOR INSERT
  WITH CHECK (
    -- Deve ser o usuário autenticado
    auth.uid() = user_id
    AND
    -- E a tarefa deve existir e o usuário deve ter acesso
    (
      -- Tarefa atribuída a ele
      EXISTS (
        SELECT 1 FROM public.tasks
        WHERE tasks.id = task_id
          AND (
            tasks.assigned_to = auth.uid()
            OR auth.uid() = ANY(tasks.assignee_user_ids)
          )
      )
      OR
      -- Ou tarefa de projeto que ele participa
      EXISTS (
        SELECT 1 FROM public.tasks t
        INNER JOIN public.project_members pm ON pm.project_id = t.project_id
        WHERE t.id = task_id
          AND pm.user_id = auth.uid()
      )
    )
  );

-- ============================================================================
-- PARTE 5: CRIAR POLÍTICAS DE UPDATE (Atualizar comentários)
-- ============================================================================

-- Política: Usuários podem atualizar apenas seus próprios comentários
CREATE POLICY "Users can update own task comments"
  ON public.task_comments
  FOR UPDATE
  USING (auth.uid() = user_id)
  WITH CHECK (
    auth.uid() = user_id
    AND
    -- Verificar que a tarefa ainda existe e o usuário tem acesso
    (
      EXISTS (
        SELECT 1 FROM public.tasks
        WHERE tasks.id = task_id
          AND (
            tasks.assigned_to = auth.uid()
            OR auth.uid() = ANY(tasks.assignee_user_ids)
          )
      )
      OR
      EXISTS (
        SELECT 1 FROM public.tasks t
        INNER JOIN public.project_members pm ON pm.project_id = t.project_id
        WHERE t.id = task_id
          AND pm.user_id = auth.uid()
      )
    )
  );

-- ============================================================================
-- PARTE 6: CRIAR POLÍTICAS DE DELETE (Deletar comentários)
-- ============================================================================

-- Política: Usuários podem deletar apenas seus próprios comentários
CREATE POLICY "Users can delete own task comments"
  ON public.task_comments
  FOR DELETE
  USING (auth.uid() = user_id);

-- ============================================================================
-- CONFIRMAÇÃO
-- ============================================================================

SELECT 'RLS policies for task_comments created successfully!' as status;

