-- ============================================================================
-- Migration: Notify admins and gestors when new entities are created
-- Date: 2025-10-31
-- Description: Creates triggers to notify users with 'admin' or 'gestor' roles
--              when new clients, companies, projects, or tasks are created
-- ============================================================================

-- ============================================================================
-- PARTE 1: ATUALIZAR CONSTRAINT DE TIPOS DE NOTIFICAÇÃO
-- ============================================================================

-- Remover constraint antiga
ALTER TABLE public.notifications
DROP CONSTRAINT IF EXISTS notifications_type_check;

-- Adicionar constraint com novos tipos
ALTER TABLE public.notifications
ADD CONSTRAINT notifications_type_check CHECK (type IN (
  'task_assigned',
  'task_due_soon',
  'task_overdue',
  'task_updated',
  'task_comment',
  'task_status_changed',
  'task_created',
  'project_added',
  'project_updated',
  'mention',
  'payment_received',
  'client_created',
  'company_created'
));

-- Atualizar constraint de entity_type
ALTER TABLE public.notifications
DROP CONSTRAINT IF EXISTS notifications_entity_type_check;

ALTER TABLE public.notifications
ADD CONSTRAINT notifications_entity_type_check CHECK (entity_type IN (
  'task',
  'project',
  'comment',
  'payment',
  'mention',
  'client',
  'company'
));

-- ============================================================================
-- PARTE 2: TRIGGER PARA NOVOS CLIENTES
-- ============================================================================

CREATE OR REPLACE FUNCTION public.notify_admins_gestors_new_client()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_admin_gestor RECORD;
  v_creator_name TEXT;
BEGIN
  -- Buscar nome do criador
  SELECT full_name INTO v_creator_name
  FROM public.profiles
  WHERE id = NEW.owner_id;

  -- Notificar todos os admins e gestores (exceto o criador)
  FOR v_admin_gestor IN
    SELECT id FROM public.profiles
    WHERE role IN ('admin', 'gestor')
      AND id != NEW.owner_id
  LOOP
    PERFORM public.create_notification(
      p_user_id := v_admin_gestor.id,
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
      )
    );
  END LOOP;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trigger_notify_admins_gestors_new_client ON public.clients;

CREATE TRIGGER trigger_notify_admins_gestors_new_client
  AFTER INSERT ON public.clients
  FOR EACH ROW
  EXECUTE FUNCTION public.notify_admins_gestors_new_client();

-- ============================================================================
-- PARTE 3: TRIGGER PARA NOVAS EMPRESAS
-- ============================================================================

CREATE OR REPLACE FUNCTION public.notify_admins_gestors_new_company()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_admin_gestor RECORD;
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

  -- Notificar todos os admins e gestores (exceto o criador)
  FOR v_admin_gestor IN
    SELECT id FROM public.profiles
    WHERE role IN ('admin', 'gestor')
      AND id != NEW.owner_id
  LOOP
    PERFORM public.create_notification(
      p_user_id := v_admin_gestor.id,
      p_type := 'company_created',
      p_title := 'Nova empresa criada',
      p_message := COALESCE(v_creator_name, 'Alguém') || ' criou a empresa: ' || NEW.name || ' (Cliente: ' || COALESCE(v_client_name, 'Desconhecido') || ')',
      p_entity_type := 'company',
      p_entity_id := NEW.id,
      p_metadata := jsonb_build_object(
        'company_id', NEW.id,
        'company_name', NEW.name,
        'client_id', NEW.client_id,
        'client_name', COALESCE(v_client_name, 'Desconhecido'),
        'created_by_user_id', NEW.owner_id,
        'created_by_name', COALESCE(v_creator_name, 'Desconhecido')
      )
    );
  END LOOP;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trigger_notify_admins_gestors_new_company ON public.companies;

CREATE TRIGGER trigger_notify_admins_gestors_new_company
  AFTER INSERT ON public.companies
  FOR EACH ROW
  EXECUTE FUNCTION public.notify_admins_gestors_new_company();

-- ============================================================================
-- PARTE 4: TRIGGER PARA NOVOS PROJETOS
-- ============================================================================

CREATE OR REPLACE FUNCTION public.notify_admins_gestors_new_project()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_admin_gestor RECORD;
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

  -- Notificar todos os admins e gestores (exceto o criador)
  FOR v_admin_gestor IN
    SELECT id FROM public.profiles
    WHERE role IN ('admin', 'gestor')
      AND id != NEW.owner_id
  LOOP
    PERFORM public.create_notification(
      p_user_id := v_admin_gestor.id,
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
      )
    );
  END LOOP;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trigger_notify_admins_gestors_new_project ON public.projects;

CREATE TRIGGER trigger_notify_admins_gestors_new_project
  AFTER INSERT ON public.projects
  FOR EACH ROW
  EXECUTE FUNCTION public.notify_admins_gestors_new_project();

-- ============================================================================
-- PARTE 5: TRIGGER PARA NOVAS TAREFAS
-- ============================================================================

CREATE OR REPLACE FUNCTION public.notify_admins_gestors_new_task()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_admin_gestor RECORD;
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

  -- Notificar todos os admins e gestores (exceto o criador)
  FOR v_admin_gestor IN
    SELECT id FROM public.profiles
    WHERE role IN ('admin', 'gestor')
      AND id != NEW.created_by
  LOOP
    PERFORM public.create_notification(
      p_user_id := v_admin_gestor.id,
      p_type := 'task_created',
      p_title := 'Nova tarefa criada',
      p_message := COALESCE(v_creator_name, 'Alguém') || ' criou a tarefa: ' || NEW.title || ' (Projeto: ' || COALESCE(v_project_name, 'Desconhecido') || ')',
      p_entity_type := 'task',
      p_entity_id := NEW.id,
      p_metadata := jsonb_build_object(
        'task_id', NEW.id,
        'task_title', NEW.title,
        'project_id', NEW.project_id,
        'project_name', COALESCE(v_project_name, 'Desconhecido'),
        'created_by_user_id', NEW.created_by,
        'created_by_name', COALESCE(v_creator_name, 'Desconhecido')
      )
    );
  END LOOP;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trigger_notify_admins_gestors_new_task ON public.tasks;

CREATE TRIGGER trigger_notify_admins_gestors_new_task
  AFTER INSERT ON public.tasks
  FOR EACH ROW
  EXECUTE FUNCTION public.notify_admins_gestors_new_task();

-- ============================================================================
-- PARTE 6: COMENTÁRIOS
-- ============================================================================

COMMENT ON FUNCTION public.notify_admins_gestors_new_client() IS 'Notifica admins e gestores quando um novo cliente é criado';
COMMENT ON FUNCTION public.notify_admins_gestors_new_company() IS 'Notifica admins e gestores quando uma nova empresa é criada';
COMMENT ON FUNCTION public.notify_admins_gestors_new_project() IS 'Notifica admins e gestores quando um novo projeto é criado';
COMMENT ON FUNCTION public.notify_admins_gestors_new_task() IS 'Notifica admins e gestores quando uma nova tarefa é criada';

