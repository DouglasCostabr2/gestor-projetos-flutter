-- ============================================================================
-- Migration: Adicionar Funções RPC para Filtrar Projetos e Tarefas por Usuário
-- Data: 2025-10-28
-- Descrição: Cria funções que retornam apenas projetos e tarefas que o usuário
--            tem permissão de visualizar (owner, membro, ou responsável)
-- ============================================================================

-- ============================================================================
-- FUNÇÃO: get_user_projects
-- Retorna projetos que o usuário tem acesso (owner, membro, ou tem tarefas)
-- ============================================================================

CREATE OR REPLACE FUNCTION public.get_user_projects(
  p_offset integer DEFAULT NULL,
  p_limit integer DEFAULT NULL
)
RETURNS TABLE (
  id uuid,
  name text,
  description text,
  owner_id uuid,
  client_id uuid,
  company_id uuid,
  status text,
  priority text,
  start_date date,
  due_date date,
  created_at timestamptz,
  updated_at timestamptz,
  updated_by uuid,
  value_cents bigint,
  currency_code text,
  profiles jsonb,
  clients jsonb,
  updated_by_profile jsonb
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id uuid;
BEGIN
  -- Obter ID do usuário autenticado
  v_user_id := auth.uid();
  
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Usuário não autenticado';
  END IF;

  -- Retornar projetos onde o usuário:
  -- 1. É o owner (dono do projeto)
  -- 2. É membro (project_members)
  -- 3. Tem tarefas atribuídas no projeto
  RETURN QUERY
  SELECT DISTINCT
    p.id,
    p.name,
    p.description,
    p.owner_id,
    p.client_id,
    p.company_id,
    p.status,
    p.priority,
    p.start_date,
    p.due_date,
    p.created_at,
    p.updated_at,
    p.updated_by,
    p.value_cents,
    p.currency_code,
    -- Perfil do owner
    to_jsonb(row(prof.full_name, prof.avatar_url)) as profiles,
    -- Cliente
    to_jsonb(row(c.name, c.company, c.email, c.avatar_url)) as clients,
    -- Perfil de quem atualizou
    to_jsonb(row(upd_prof.id, upd_prof.full_name, upd_prof.avatar_url)) as updated_by_profile
  FROM public.projects p
  LEFT JOIN public.profiles prof ON prof.id = p.owner_id
  LEFT JOIN public.clients c ON c.id = p.client_id
  LEFT JOIN public.profiles upd_prof ON upd_prof.id = p.updated_by
  WHERE
    -- Usuário é o owner
    p.owner_id = v_user_id
    OR
    -- Usuário é membro do projeto
    EXISTS (
      SELECT 1 FROM public.project_members pm
      WHERE pm.project_id = p.id
        AND pm.user_id = v_user_id
    )
    OR
    -- Usuário tem tarefas atribuídas no projeto
    EXISTS (
      SELECT 1 FROM public.tasks t
      WHERE t.project_id = p.id
        AND (
          t.assigned_to = v_user_id
          OR v_user_id = ANY(t.assignee_user_ids)
        )
    )
  ORDER BY p.created_at DESC
  LIMIT p_limit
  OFFSET p_offset;
END;
$$;

-- Comentário da função
COMMENT ON FUNCTION public.get_user_projects IS 'Retorna projetos que o usuário tem acesso (owner, membro, ou responsável por tarefas)';

-- ============================================================================
-- FUNÇÃO: get_user_tasks
-- Retorna tarefas que o usuário tem acesso (responsável ou membro do projeto)
-- ============================================================================

CREATE OR REPLACE FUNCTION public.get_user_tasks(
  p_project_id uuid DEFAULT NULL,
  p_offset integer DEFAULT NULL,
  p_limit integer DEFAULT NULL
)
RETURNS TABLE (
  id uuid,
  title text,
  description text,
  status text,
  priority text,
  created_at timestamptz,
  updated_at timestamptz,
  completed_at timestamptz,
  created_by uuid,
  updated_by uuid,
  due_date date,
  start_date date,
  project_id uuid,
  assigned_to uuid,
  assignee_user_ids uuid[],
  parent_task_id uuid,
  projects jsonb,
  creator_profile jsonb,
  assignee_profile jsonb
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id uuid;
BEGIN
  -- Obter ID do usuário autenticado
  v_user_id := auth.uid();
  
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Usuário não autenticado';
  END IF;

  -- Retornar tarefas onde o usuário:
  -- 1. É o responsável principal (assigned_to)
  -- 2. É um dos responsáveis (assignee_user_ids)
  -- 3. É membro do projeto
  -- 4. É owner do projeto
  RETURN QUERY
  SELECT
    t.id,
    t.title,
    t.description,
    t.status,
    t.priority,
    t.created_at,
    t.updated_at,
    t.completed_at,
    t.created_by,
    t.updated_by,
    t.due_date,
    t.start_date,
    t.project_id,
    t.assigned_to,
    t.assignee_user_ids,
    t.parent_task_id,
    -- Projeto
    to_jsonb(row(proj.name, proj.client_id)) as projects,
    -- Criador
    to_jsonb(row(creator.full_name, creator.avatar_url)) as creator_profile,
    -- Responsável
    to_jsonb(row(assignee.full_name, assignee.avatar_url)) as assignee_profile
  FROM public.tasks t
  LEFT JOIN public.projects proj ON proj.id = t.project_id
  LEFT JOIN public.profiles creator ON creator.id = t.created_by
  LEFT JOIN public.profiles assignee ON assignee.id = t.assigned_to
  WHERE
    (p_project_id IS NULL OR t.project_id = p_project_id)
    AND
    (
      -- Usuário é responsável principal
      t.assigned_to = v_user_id
      OR
      -- Usuário é um dos responsáveis
      v_user_id = ANY(t.assignee_user_ids)
      OR
      -- Usuário é membro do projeto
      EXISTS (
        SELECT 1 FROM public.project_members pm
        WHERE pm.project_id = t.project_id
          AND pm.user_id = v_user_id
      )
      OR
      -- Usuário é owner do projeto
      EXISTS (
        SELECT 1 FROM public.projects p
        WHERE p.id = t.project_id
          AND p.owner_id = v_user_id
      )
    )
  ORDER BY t.created_at DESC
  LIMIT p_limit
  OFFSET p_offset;
END;
$$;

-- Comentário da função
COMMENT ON FUNCTION public.get_user_tasks IS 'Retorna tarefas que o usuário tem acesso (responsável, membro do projeto, ou owner do projeto)';

-- ============================================================================
-- PERMISSÕES
-- ============================================================================

-- Permitir que usuários autenticados executem as funções
GRANT EXECUTE ON FUNCTION public.get_user_projects TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_user_tasks TO authenticated;

-- Mensagem de sucesso
DO $$
BEGIN
  RAISE NOTICE '✅ Funções RPC criadas com sucesso!';
  RAISE NOTICE '   - get_user_projects: Filtra projetos por acesso do usuário';
  RAISE NOTICE '   - get_user_tasks: Filtra tarefas por acesso do usuário';
END $$;

