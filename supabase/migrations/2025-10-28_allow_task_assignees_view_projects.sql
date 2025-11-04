-- ============================================================================
-- Migration: Permitir que responsáveis por tarefas vejam projetos e clientes
-- Data: 2025-10-28
-- Descrição: Adiciona política RLS para permitir que usuários responsáveis
--            por tarefas (assigned_to ou assignee_user_ids) possam visualizar
--            informações do projeto (nome, cliente, avatar, etc.)
--            
--            Nota: A política de clientes já permite visualização para todos
--            os usuários autenticados, então não precisa de alteração.
-- ============================================================================

-- Criar política para permitir que responsáveis por tarefas vejam o projeto
CREATE POLICY IF NOT EXISTS "projects_select_task_assignees"
  ON public.projects
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 
      FROM tasks 
      WHERE tasks.project_id = projects.id 
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
  RAISE NOTICE '📝 Política RLS criada: projects_select_task_assignees';
  RAISE NOTICE '✓  Usuários responsáveis por tarefas podem ver o projeto';
  RAISE NOTICE '✓  Clientes já são visíveis para todos os usuários autenticados';
END $$;

