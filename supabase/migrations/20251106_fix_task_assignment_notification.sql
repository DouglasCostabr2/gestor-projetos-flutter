-- ============================================================================
-- Migration: Fix task assignment notification to use updated_by instead of created_by
-- Date: 2025-11-06
-- Description: When editing an existing task and assigning it to someone,
--              the notification should check who is making the assignment (updated_by)
--              not who created the task originally (created_by)
-- ============================================================================

CREATE OR REPLACE FUNCTION public.notify_task_assigned()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_task_title TEXT;
  v_assigned_by_name TEXT;
  v_assigned_by_id UUID;
BEGIN
  -- Só notificar se assigned_to mudou e não é NULL
  IF NEW.assigned_to IS NOT NULL AND (TG_OP = 'INSERT' OR OLD.assigned_to IS DISTINCT FROM NEW.assigned_to) THEN
    
    -- Determinar quem está fazendo a atribuição
    -- Se for INSERT, usar created_by
    -- Se for UPDATE, usar updated_by (se existir) ou created_by
    IF TG_OP = 'INSERT' THEN
      v_assigned_by_id := NEW.created_by;
    ELSE
      v_assigned_by_id := COALESCE(NEW.updated_by, NEW.created_by);
    END IF;
    
    -- Não notificar se o usuário atribuiu a tarefa para si mesmo
    IF NEW.assigned_to = v_assigned_by_id THEN
      RETURN NEW;
    END IF;
    
    -- Buscar título da tarefa
    v_task_title := NEW.title;
    
    -- Buscar nome de quem atribuiu
    SELECT full_name INTO v_assigned_by_name
    FROM public.profiles
    WHERE id = v_assigned_by_id;
    
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
        'assigned_by', v_assigned_by_id,
        'assigned_by_name', COALESCE(v_assigned_by_name, 'Sistema'),
        'project_id', NEW.project_id
      )
    );
  END IF;
  
  RETURN NEW;
END;
$$;

