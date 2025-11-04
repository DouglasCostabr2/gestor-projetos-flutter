-- ============================================================================
-- Migration: Create mentions system
-- Date: 2025-10-30
-- Description: Creates tables and policies for @mentions system
-- ============================================================================

-- ============================================================================
-- PARTE 1: CRIAR TABELA DE MENÇÕES
-- ============================================================================

-- Tabela para armazenar menções em comentários
CREATE TABLE IF NOT EXISTS public.comment_mentions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  comment_id UUID NOT NULL REFERENCES public.task_comments(id) ON DELETE CASCADE,
  mentioned_user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  mentioned_by_user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  
  -- Evitar duplicatas
  UNIQUE(comment_id, mentioned_user_id)
);

-- Tabela para armazenar menções em tarefas (título/descrição)
CREATE TABLE IF NOT EXISTS public.task_mentions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  task_id UUID NOT NULL REFERENCES public.tasks(id) ON DELETE CASCADE,
  mentioned_user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  mentioned_by_user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  field_name VARCHAR(50) NOT NULL, -- 'title', 'description', 'briefing'
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  
  -- Evitar duplicatas
  UNIQUE(task_id, mentioned_user_id, field_name)
);

-- Tabela para armazenar menções em projetos
CREATE TABLE IF NOT EXISTS public.project_mentions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  project_id UUID NOT NULL REFERENCES public.projects(id) ON DELETE CASCADE,
  mentioned_user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  mentioned_by_user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  field_name VARCHAR(50) NOT NULL, -- 'title', 'description'
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  
  -- Evitar duplicatas
  UNIQUE(project_id, mentioned_user_id, field_name)
);

-- ============================================================================
-- PARTE 2: CRIAR ÍNDICES
-- ============================================================================

-- Índices para comment_mentions
CREATE INDEX IF NOT EXISTS idx_comment_mentions_comment_id 
  ON public.comment_mentions(comment_id);
CREATE INDEX IF NOT EXISTS idx_comment_mentions_mentioned_user_id 
  ON public.comment_mentions(mentioned_user_id);
CREATE INDEX IF NOT EXISTS idx_comment_mentions_mentioned_by_user_id 
  ON public.comment_mentions(mentioned_by_user_id);

-- Índices para task_mentions
CREATE INDEX IF NOT EXISTS idx_task_mentions_task_id 
  ON public.task_mentions(task_id);
CREATE INDEX IF NOT EXISTS idx_task_mentions_mentioned_user_id 
  ON public.task_mentions(mentioned_user_id);
CREATE INDEX IF NOT EXISTS idx_task_mentions_mentioned_by_user_id 
  ON public.task_mentions(mentioned_by_user_id);

-- Índices para project_mentions
CREATE INDEX IF NOT EXISTS idx_project_mentions_project_id 
  ON public.project_mentions(project_id);
CREATE INDEX IF NOT EXISTS idx_project_mentions_mentioned_user_id 
  ON public.project_mentions(mentioned_user_id);
CREATE INDEX IF NOT EXISTS idx_project_mentions_mentioned_by_user_id 
  ON public.project_mentions(mentioned_by_user_id);

-- ============================================================================
-- PARTE 3: HABILITAR RLS
-- ============================================================================

ALTER TABLE public.comment_mentions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.task_mentions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.project_mentions ENABLE ROW LEVEL SECURITY;

-- ============================================================================
-- PARTE 4: POLÍTICAS RLS - COMMENT_MENTIONS
-- ============================================================================

-- Usuários podem ver menções em comentários que eles têm acesso
CREATE POLICY "Users can view comment mentions"
  ON public.comment_mentions
  FOR SELECT
  USING (
    -- Ver menções em comentários de tarefas que eles têm acesso
    EXISTS (
      SELECT 1 FROM public.task_comments tc
      INNER JOIN public.tasks t ON t.id = tc.task_id
      WHERE tc.id = comment_mentions.comment_id
        AND (
          t.assigned_to = auth.uid()
          OR auth.uid() = ANY(t.assignee_user_ids)
          OR EXISTS (
            SELECT 1 FROM public.project_members pm
            WHERE pm.project_id = t.project_id
              AND pm.user_id = auth.uid()
          )
        )
    )
    OR
    -- Ou se foram mencionados
    mentioned_user_id = auth.uid()
  );

-- Usuários podem inserir menções em comentários que eles criaram
CREATE POLICY "Users can insert comment mentions"
  ON public.comment_mentions
  FOR INSERT
  WITH CHECK (
    -- Deve ser o usuário autenticado que está mencionando
    auth.uid() = mentioned_by_user_id
    AND
    -- E o comentário deve existir e pertencer ao usuário
    EXISTS (
      SELECT 1 FROM public.task_comments
      WHERE task_comments.id = comment_id
        AND task_comments.user_id = auth.uid()
    )
  );

-- Usuários podem deletar menções que eles criaram
CREATE POLICY "Users can delete their comment mentions"
  ON public.comment_mentions
  FOR DELETE
  USING (
    mentioned_by_user_id = auth.uid()
  );

-- ============================================================================
-- PARTE 5: POLÍTICAS RLS - TASK_MENTIONS
-- ============================================================================

-- Usuários podem ver menções em tarefas que eles têm acesso
CREATE POLICY "Users can view task mentions"
  ON public.task_mentions
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.tasks
      WHERE tasks.id = task_mentions.task_id
        AND (
          tasks.assigned_to = auth.uid()
          OR auth.uid() = ANY(tasks.assignee_user_ids)
          OR EXISTS (
            SELECT 1 FROM public.project_members pm
            WHERE pm.project_id = tasks.project_id
              AND pm.user_id = auth.uid()
          )
        )
    )
    OR
    mentioned_user_id = auth.uid()
  );

-- Usuários podem inserir menções em tarefas que eles têm acesso
CREATE POLICY "Users can insert task mentions"
  ON public.task_mentions
  FOR INSERT
  WITH CHECK (
    auth.uid() = mentioned_by_user_id
    AND
    EXISTS (
      SELECT 1 FROM public.tasks
      WHERE tasks.id = task_id
        AND (
          tasks.assigned_to = auth.uid()
          OR auth.uid() = ANY(tasks.assignee_user_ids)
          OR EXISTS (
            SELECT 1 FROM public.project_members pm
            WHERE pm.project_id = tasks.project_id
              AND pm.user_id = auth.uid()
          )
        )
    )
  );

-- Usuários podem deletar menções que eles criaram
CREATE POLICY "Users can delete their task mentions"
  ON public.task_mentions
  FOR DELETE
  USING (
    mentioned_by_user_id = auth.uid()
  );

-- ============================================================================
-- PARTE 6: POLÍTICAS RLS - PROJECT_MENTIONS
-- ============================================================================

-- Usuários podem ver menções em projetos que eles têm acesso
CREATE POLICY "Users can view project mentions"
  ON public.project_mentions
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.project_members
      WHERE project_members.project_id = project_mentions.project_id
        AND project_members.user_id = auth.uid()
    )
    OR
    mentioned_user_id = auth.uid()
  );

-- Usuários podem inserir menções em projetos que eles participam
CREATE POLICY "Users can insert project mentions"
  ON public.project_mentions
  FOR INSERT
  WITH CHECK (
    auth.uid() = mentioned_by_user_id
    AND
    EXISTS (
      SELECT 1 FROM public.project_members
      WHERE project_members.project_id = project_id
        AND project_members.user_id = auth.uid()
    )
  );

-- Usuários podem deletar menções que eles criaram
CREATE POLICY "Users can delete their project mentions"
  ON public.project_mentions
  FOR DELETE
  USING (
    mentioned_by_user_id = auth.uid()
  );

-- ============================================================================
-- PARTE 7: COMENTÁRIOS
-- ============================================================================

COMMENT ON TABLE public.comment_mentions IS 'Armazena menções (@mentions) em comentários de tarefas';
COMMENT ON TABLE public.task_mentions IS 'Armazena menções (@mentions) em tarefas (título, descrição, briefing)';
COMMENT ON TABLE public.project_mentions IS 'Armazena menções (@mentions) em projetos (título, descrição)';

