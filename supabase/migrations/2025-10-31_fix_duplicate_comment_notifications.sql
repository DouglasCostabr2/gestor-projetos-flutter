-- ============================================================================
-- Migration: Fix duplicate comment notifications
-- Date: 2025-10-31
-- Description: Updates notify_task_comment trigger to avoid duplicate notifications
--              when a user is both mentioned and is a task assignee
-- ============================================================================

CREATE OR REPLACE FUNCTION public.notify_task_comment()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_task RECORD;
  v_commenter_name TEXT;
  v_user_id UUID;
  v_has_mention BOOLEAN;
BEGIN
  -- Buscar informações da tarefa
  SELECT id, title, assigned_to, assignee_user_ids, created_by
  INTO v_task
  FROM public.tasks
  WHERE id = NEW.task_id;

  -- Buscar nome de quem comentou
  SELECT full_name INTO v_commenter_name
  FROM public.profiles
  WHERE id = NEW.user_id;

  -- Notificar o responsável principal (se não for quem comentou)
  IF v_task.assigned_to IS NOT NULL AND v_task.assigned_to != NEW.user_id THEN
    -- Verificar se o usuário foi mencionado neste comentário
    SELECT EXISTS (
      SELECT 1 FROM public.comment_mentions
      WHERE comment_id = NEW.id AND mentioned_user_id = v_task.assigned_to
    ) INTO v_has_mention;
    
    -- Só notificar se NÃO foi mencionado (para evitar duplicata)
    IF NOT v_has_mention THEN
      PERFORM public.create_notification(
        p_user_id := v_task.assigned_to,
        p_type := 'task_comment',
        p_title := 'Novo comentário',
        p_message := COALESCE(v_commenter_name, 'Alguém') || ' comentou na tarefa: ' || v_task.title,
        p_entity_type := 'comment',
        p_entity_id := NEW.id,
        p_metadata := jsonb_build_object(
          'task_id', v_task.id,
          'task_title', v_task.title,
          'comment_id', NEW.id,
          'commenter_id', NEW.user_id,
          'commenter_name', COALESCE(v_commenter_name, 'Desconhecido')
        )
      );
    END IF;
  END IF;

  -- Notificar outros responsáveis (assignee_user_ids)
  IF v_task.assignee_user_ids IS NOT NULL THEN
    FOR v_user_id IN SELECT unnest(v_task.assignee_user_ids)
    LOOP
      -- Não notificar quem fez o comentário
      IF v_user_id != NEW.user_id THEN
        -- Verificar se o usuário foi mencionado neste comentário
        SELECT EXISTS (
          SELECT 1 FROM public.comment_mentions
          WHERE comment_id = NEW.id AND mentioned_user_id = v_user_id
        ) INTO v_has_mention;
        
        -- Só notificar se NÃO foi mencionado (para evitar duplicata)
        IF NOT v_has_mention THEN
          PERFORM public.create_notification(
            p_user_id := v_user_id,
            p_type := 'task_comment',
            p_title := 'Novo comentário',
            p_message := COALESCE(v_commenter_name, 'Alguém') || ' comentou na tarefa: ' || v_task.title,
            p_entity_type := 'comment',
            p_entity_id := NEW.id,
            p_metadata := jsonb_build_object(
              'task_id', v_task.id,
              'task_title', v_task.title,
              'comment_id', NEW.id,
              'commenter_id', NEW.user_id,
              'commenter_name', COALESCE(v_commenter_name, 'Desconhecido')
            )
          );
        END IF;
      END IF;
    END LOOP;
  END IF;

  -- Notificar o criador da tarefa (se não for quem comentou e não for o responsável)
  IF v_task.created_by IS NOT NULL
     AND v_task.created_by != NEW.user_id
     AND v_task.created_by != v_task.assigned_to THEN
    -- Verificar se o usuário foi mencionado neste comentário
    SELECT EXISTS (
      SELECT 1 FROM public.comment_mentions
      WHERE comment_id = NEW.id AND mentioned_user_id = v_task.created_by
    ) INTO v_has_mention;
    
    -- Só notificar se NÃO foi mencionado (para evitar duplicata)
    IF NOT v_has_mention THEN
      PERFORM public.create_notification(
        p_user_id := v_task.created_by,
        p_type := 'task_comment',
        p_title := 'Novo comentário',
        p_message := COALESCE(v_commenter_name, 'Alguém') || ' comentou na tarefa: ' || v_task.title,
        p_entity_type := 'comment',
        p_entity_id := NEW.id,
        p_metadata := jsonb_build_object(
          'task_id', v_task.id,
          'task_title', v_task.title,
          'comment_id', NEW.id,
          'commenter_id', NEW.user_id,
          'commenter_name', COALESCE(v_commenter_name, 'Desconhecido')
        )
      );
    END IF;
  END IF;

  RETURN NEW;
END;
$$;

COMMENT ON FUNCTION public.notify_task_comment() IS 'Cria notificação quando há novo comentário em tarefa (evita duplicatas com menções)';

