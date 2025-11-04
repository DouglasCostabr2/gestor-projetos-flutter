-- ============================================================================
-- Migration: Fix all remaining notification functions to include organization_id
-- Date: 2025-11-03
-- Description: Updates all notification triggers that still use the old signature
--              without organization_id parameter
-- ============================================================================

-- ============================================================================
-- 1. FIX TASK ASSIGNED NOTIFICATION
-- ============================================================================
CREATE OR REPLACE FUNCTION public.notify_task_assigned()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_task_title TEXT;
  v_assigned_by_name TEXT;
BEGIN
  -- Só notificar se assigned_to mudou e não é NULL
  IF NEW.assigned_to IS NOT NULL AND (TG_OP = 'INSERT' OR OLD.assigned_to IS DISTINCT FROM NEW.assigned_to) THEN
    -- Não notificar se o usuário atribuiu a tarefa para si mesmo
    IF NEW.assigned_to = NEW.created_by THEN
      RETURN NEW;
    END IF;
    
    -- Buscar título da tarefa
    v_task_title := NEW.title;
    
    -- Buscar nome de quem atribuiu
    SELECT full_name INTO v_assigned_by_name
    FROM public.profiles
    WHERE id = NEW.created_by;
    
    -- Criar notificação para o usuário atribuído
    PERFORM public.create_notification(
      p_user_id := NEW.assigned_to,
      p_organization_id := NEW.organization_id,
      p_type := 'task_assigned',
      p_title := 'Nova tarefa atribuída',
      p_message := 'Você foi atribuído à tarefa: ' || v_task_title,
      p_entity_type := 'task',
      p_entity_id := NEW.id,
      p_metadata := jsonb_build_object(
        'task_id', NEW.id,
        'task_title', v_task_title,
        'assigned_by', NEW.created_by,
        'assigned_by_name', COALESCE(v_assigned_by_name, 'Sistema'),
        'project_id', NEW.project_id
      )
    );
  END IF;
  
  RETURN NEW;
END;
$$;

-- ============================================================================
-- 2. FIX PROJECT MEMBER ADDED NOTIFICATION
-- ============================================================================
CREATE OR REPLACE FUNCTION public.notify_project_member_added()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_project_name TEXT;
  v_project_org_id UUID;
  v_added_by_name TEXT;
BEGIN
  -- NÃO notificar se o usuário adicionou a si mesmo
  IF NEW.user_id = auth.uid() THEN
    RETURN NEW;
  END IF;

  -- Buscar nome e organization_id do projeto
  SELECT name, organization_id INTO v_project_name, v_project_org_id
  FROM public.projects
  WHERE id = NEW.project_id;

  -- Buscar nome de quem adicionou
  SELECT full_name INTO v_added_by_name
  FROM public.profiles
  WHERE id = auth.uid();

  -- Criar notificação para o membro adicionado
  PERFORM public.create_notification(
    p_user_id := NEW.user_id,
    p_organization_id := v_project_org_id,
    p_type := 'project_added',
    p_title := 'Adicionado a projeto',
    p_message := 'Você foi adicionado ao projeto: ' || v_project_name,
    p_entity_type := 'project',
    p_entity_id := NEW.project_id,
    p_metadata := jsonb_build_object(
      'project_id', NEW.project_id,
      'project_name', v_project_name,
      'role', NEW.role,
      'added_by', auth.uid(),
      'added_by_name', COALESCE(v_added_by_name, 'Sistema')
    )
  );

  RETURN NEW;
END;
$$;

-- ============================================================================
-- 3. FIX COMMENT MENTION NOTIFICATION
-- ============================================================================
CREATE OR REPLACE FUNCTION public.notify_comment_mention()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_comment RECORD;
  v_task RECORD;
  v_mentioner_name TEXT;
BEGIN
  -- Buscar informações do comentário
  SELECT id, task_id, user_id, content
  INTO v_comment
  FROM public.task_comments
  WHERE id = NEW.comment_id;

  -- Buscar informações da tarefa (incluindo organization_id)
  SELECT id, title, organization_id
  INTO v_task
  FROM public.tasks
  WHERE id = v_comment.task_id;

  -- Buscar nome de quem mencionou
  SELECT full_name INTO v_mentioner_name
  FROM public.profiles
  WHERE id = NEW.mentioned_by_user_id;

  -- Criar notificação para o usuário mencionado
  PERFORM public.create_notification(
    p_user_id := NEW.mentioned_user_id,
    p_organization_id := v_task.organization_id,
    p_type := 'mention',
    p_title := 'Você foi mencionado',
    p_message := COALESCE(v_mentioner_name, 'Alguém') || ' mencionou você em um comentário na tarefa: ' || v_task.title,
    p_entity_type := 'comment',
    p_entity_id := v_comment.id,
    p_metadata := jsonb_build_object(
      'task_id', v_task.id,
      'task_title', v_task.title,
      'comment_id', v_comment.id,
      'mentioned_by_user_id', NEW.mentioned_by_user_id,
      'mentioned_by_name', COALESCE(v_mentioner_name, 'Desconhecido')
    )
  );

  RETURN NEW;
END;
$$;

-- ============================================================================
-- 4. FIX TASK MENTION NOTIFICATION
-- ============================================================================
CREATE OR REPLACE FUNCTION public.notify_task_mention()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_task RECORD;
  v_mentioner_name TEXT;
  v_field_label TEXT;
BEGIN
  -- NÃO notificar se o usuário mencionou a si mesmo
  IF NEW.mentioned_user_id = NEW.mentioned_by_user_id THEN
    RETURN NEW;
  END IF;

  -- Buscar informações da tarefa (incluindo organization_id)
  SELECT id, title, organization_id
  INTO v_task
  FROM public.tasks
  WHERE id = NEW.task_id;

  -- Buscar nome de quem mencionou
  SELECT full_name INTO v_mentioner_name
  FROM public.profiles
  WHERE id = NEW.mentioned_by_user_id;

  -- Determinar o label do campo
  CASE NEW.field_name
    WHEN 'title' THEN v_field_label := 'título';
    WHEN 'description' THEN v_field_label := 'descrição';
    WHEN 'briefing' THEN v_field_label := 'briefing';
    ELSE v_field_label := NEW.field_name;
  END CASE;

  -- Criar notificação para o usuário mencionado
  PERFORM public.create_notification(
    p_user_id := NEW.mentioned_user_id,
    p_organization_id := v_task.organization_id,
    p_type := 'mention',
    p_title := 'Você foi mencionado',
    p_message := COALESCE(v_mentioner_name, 'Alguém') || ' mencionou você no ' || v_field_label || ' da tarefa: ' || v_task.title,
    p_entity_type := 'task',
    p_entity_id := v_task.id,
    p_metadata := jsonb_build_object(
      'task_id', v_task.id,
      'task_title', v_task.title,
      'field_name', NEW.field_name,
      'mentioned_by_user_id', NEW.mentioned_by_user_id,
      'mentioned_by_name', COALESCE(v_mentioner_name, 'Desconhecido')
    )
  );

  RETURN NEW;
END;
$$;

-- ============================================================================
-- 5. FIX PROJECT MENTION NOTIFICATION
-- ============================================================================
CREATE OR REPLACE FUNCTION public.notify_project_mention()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_project RECORD;
  v_mentioner_name TEXT;
  v_field_label TEXT;
BEGIN
  -- NÃO notificar se o usuário mencionou a si mesmo
  IF NEW.mentioned_user_id = NEW.mentioned_by_user_id THEN
    RETURN NEW;
  END IF;

  -- Buscar informações do projeto (incluindo organization_id)
  SELECT id, name, organization_id
  INTO v_project
  FROM public.projects
  WHERE id = NEW.project_id;

  -- Buscar nome de quem mencionou
  SELECT full_name INTO v_mentioner_name
  FROM public.profiles
  WHERE id = NEW.mentioned_by_user_id;

  -- Determinar o label do campo
  CASE NEW.field_name
    WHEN 'title' THEN v_field_label := 'título';
    WHEN 'description' THEN v_field_label := 'descrição';
    ELSE v_field_label := NEW.field_name;
  END CASE;

  -- Criar notificação para o usuário mencionado
  PERFORM public.create_notification(
    p_user_id := NEW.mentioned_user_id,
    p_organization_id := v_project.organization_id,
    p_type := 'mention',
    p_title := 'Você foi mencionado',
    p_message := COALESCE(v_mentioner_name, 'Alguém') || ' mencionou você no ' || v_field_label || ' do projeto: ' || v_project.name,
    p_entity_type := 'project',
    p_entity_id := v_project.id,
    p_metadata := jsonb_build_object(
      'project_id', v_project.id,
      'project_name', v_project.name,
      'field_name', NEW.field_name,
      'mentioned_by_user_id', NEW.mentioned_by_user_id,
      'mentioned_by_name', COALESCE(v_mentioner_name, 'Desconhecido')
    )
  );

  RETURN NEW;
END;
$$;

-- Completion notice
DO $$
BEGIN
  RAISE NOTICE 'Fixed all remaining notification triggers to include organization_id';
END $$;

