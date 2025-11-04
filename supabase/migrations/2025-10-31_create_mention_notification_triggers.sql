-- ============================================================================
-- Migration: Create triggers for mention notifications
-- Date: 2025-10-31
-- Description: Creates triggers to automatically notify users when they are mentioned
-- ============================================================================

-- ============================================================================
-- PARTE 1: TRIGGER PARA MENÇÕES EM COMENTÁRIOS
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

  -- Buscar informações da tarefa
  SELECT id, title
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

-- Criar trigger
DROP TRIGGER IF EXISTS trigger_notify_comment_mention ON public.comment_mentions;

CREATE TRIGGER trigger_notify_comment_mention
  AFTER INSERT ON public.comment_mentions
  FOR EACH ROW
  EXECUTE FUNCTION public.notify_comment_mention();

-- ============================================================================
-- PARTE 2: TRIGGER PARA MENÇÕES EM TAREFAS
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
  -- Buscar informações da tarefa
  SELECT id, title
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

-- Criar trigger
DROP TRIGGER IF EXISTS trigger_notify_task_mention ON public.task_mentions;

CREATE TRIGGER trigger_notify_task_mention
  AFTER INSERT ON public.task_mentions
  FOR EACH ROW
  EXECUTE FUNCTION public.notify_task_mention();

-- ============================================================================
-- PARTE 3: TRIGGER PARA MENÇÕES EM PROJETOS
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
  -- Buscar informações do projeto
  SELECT id, name
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

-- Criar trigger
DROP TRIGGER IF EXISTS trigger_notify_project_mention ON public.project_mentions;

CREATE TRIGGER trigger_notify_project_mention
  AFTER INSERT ON public.project_mentions
  FOR EACH ROW
  EXECUTE FUNCTION public.notify_project_mention();

-- ============================================================================
-- PARTE 4: COMENTÁRIOS
-- ============================================================================

COMMENT ON FUNCTION public.notify_comment_mention() IS 'Cria notificação quando um usuário é mencionado em um comentário';
COMMENT ON FUNCTION public.notify_task_mention() IS 'Cria notificação quando um usuário é mencionado em uma tarefa';
COMMENT ON FUNCTION public.notify_project_mention() IS 'Cria notificação quando um usuário é mencionado em um projeto';

