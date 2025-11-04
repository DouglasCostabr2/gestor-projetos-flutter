-- ============================================================================
-- Migration: Fix new-entity notification triggers to include organization_id
-- Date: 2025-11-03
-- Description: Rewrites notify_* functions for client/company/project/task creation
--              to use notify_organization_members and pass organization_id, avoiding
--              NOT NULL violations on public.notifications.organization_id and
--              preventing cross-organization notifications.
-- ============================================================================

-- 1) CLIENT CREATED
CREATE OR REPLACE FUNCTION public.notify_admins_gestors_new_client()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_creator_name TEXT;
BEGIN
  -- Buscar nome do criador
  SELECT full_name INTO v_creator_name
  FROM public.profiles
  WHERE id = NEW.owner_id;

  -- Notificar admins/gestores da MESMA organização (exclui o criador)
  PERFORM public.notify_organization_members(
    p_organization_id := NEW.organization_id,
    p_type := 'client_created',
    p_title := 'Novo cliente criado',
    p_message := COALESCE(v_creator_name, 'Alguém') || ' criou o cliente: ' || NEW.name,
    p_entity_type := 'client',
    p_entity_id := NEW.id,
    p_metadata := jsonb_build_object(
      'client_id', NEW.id,
      'client_name', NEW.name,
      'created_by_user_id', NEW.owner_id,
      'created_by_name', COALESCE(v_creator_name, 'Desconhecido')
    ),
    p_exclude_user_id := NEW.owner_id,
    p_roles := ARRAY['admin','gestor']
  );

  RETURN NEW;
END;
$$;

-- 2) COMPANY CREATED
CREATE OR REPLACE FUNCTION public.notify_admins_gestors_new_company()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_creator_name TEXT;
  v_client_name TEXT;
BEGIN
  -- Buscar nome do criador
  SELECT full_name INTO v_creator_name
  FROM public.profiles
  WHERE id = NEW.owner_id;

  -- Buscar nome do cliente
  SELECT name INTO v_client_name
  FROM public.clients
  WHERE id = NEW.client_id;

  PERFORM public.notify_organization_members(
    p_organization_id := NEW.organization_id,
    p_type := 'company_created',
    p_title := 'Nova empresa criada',
    p_message := COALESCE(v_creator_name, 'Alguém') || ' criou a empresa: ' || NEW.name ||
                 ' (Cliente: ' || COALESCE(v_client_name, 'Desconhecido') || ')',
    p_entity_type := 'company',
    p_entity_id := NEW.id,
    p_metadata := jsonb_build_object(
      'company_id', NEW.id,
      'company_name', NEW.name,
      'client_id', NEW.client_id,
      'client_name', COALESCE(v_client_name, 'Desconhecido'),
      'created_by_user_id', NEW.owner_id,
      'created_by_name', COALESCE(v_creator_name, 'Desconhecido')
    ),
    p_exclude_user_id := NEW.owner_id,
    p_roles := ARRAY['admin','gestor']
  );

  RETURN NEW;
END;
$$;

-- 3) PROJECT CREATED
CREATE OR REPLACE FUNCTION public.notify_admins_gestors_new_project()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_creator_name TEXT;
  v_client_name TEXT;
BEGIN
  -- Buscar nome do criador
  SELECT full_name INTO v_creator_name
  FROM public.profiles
  WHERE id = NEW.owner_id;

  -- Buscar nome do cliente (se houver)
  IF NEW.client_id IS NOT NULL THEN
    SELECT name INTO v_client_name
    FROM public.clients
    WHERE id = NEW.client_id;
  END IF;

  PERFORM public.notify_organization_members(
    p_organization_id := NEW.organization_id,
    p_type := 'project_added',
    p_title := 'Novo projeto criado',
    p_message := COALESCE(v_creator_name, 'Alguém') || ' criou o projeto: ' || NEW.name ||
                 CASE WHEN v_client_name IS NOT NULL THEN ' (Cliente: ' || v_client_name || ')' ELSE '' END,
    p_entity_type := 'project',
    p_entity_id := NEW.id,
    p_metadata := jsonb_build_object(
      'project_id', NEW.id,
      'project_name', NEW.name,
      'client_id', NEW.client_id,
      'client_name', COALESCE(v_client_name, 'N/A'),
      'created_by_user_id', NEW.owner_id,
      'created_by_name', COALESCE(v_creator_name, 'Desconhecido')
    ),
    p_exclude_user_id := NEW.owner_id,
    p_roles := ARRAY['admin','gestor']
  );

  RETURN NEW;
END;
$$;

-- 4) TASK CREATED
CREATE OR REPLACE FUNCTION public.notify_admins_gestors_new_task()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_creator_name TEXT;
  v_project_name TEXT;
BEGIN
  -- Buscar nome do criador
  SELECT full_name INTO v_creator_name
  FROM public.profiles
  WHERE id = NEW.created_by;

  -- Buscar nome do projeto
  SELECT name INTO v_project_name
  FROM public.projects
  WHERE id = NEW.project_id;

  PERFORM public.notify_organization_members(
    p_organization_id := NEW.organization_id,
    p_type := 'task_created',
    p_title := 'Nova tarefa criada',
    p_message := COALESCE(v_creator_name, 'Alguém') || ' criou a tarefa: ' || NEW.title ||
                 ' (Projeto: ' || COALESCE(v_project_name, 'Desconhecido') || ')',
    p_entity_type := 'task',
    p_entity_id := NEW.id,
    p_metadata := jsonb_build_object(
      'task_id', NEW.id,
      'task_title', NEW.title,
      'project_id', NEW.project_id,
      'project_name', COALESCE(v_project_name, 'Desconhecido'),
      'created_by_user_id', NEW.created_by,
      'created_by_name', COALESCE(v_creator_name, 'Desconhecido')
    ),
    p_exclude_user_id := NEW.created_by,
    p_roles := ARRAY['admin','gestor']
  );

  RETURN NEW;
END;
$$;

-- Completion notice
DO $$
BEGIN
  RAISE NOTICE 'Fixed new-entity notification triggers to include organization_id';
END $$;

