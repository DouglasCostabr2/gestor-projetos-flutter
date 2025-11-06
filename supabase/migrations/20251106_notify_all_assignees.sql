-- ============================================================================
-- Migration: Notify all users added to assignee_user_ids array
-- Date: 2025-11-06
-- Description: When a user is added to the assignee_user_ids array,
--              they should receive a notification, even if they are not
--              the primary assigned_to user.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.notify_assignee_user_ids_changes()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_task_title TEXT;
  v_assigned_by_name TEXT;
  v_assigned_by_id UUID;
  v_new_assignee_id UUID;
  v_old_assignee_ids UUID[];
  v_new_assignee_ids UUID[];
BEGIN
  -- Determinar quem está fazendo a atribuição
  IF TG_OP = 'INSERT' THEN
    v_assigned_by_id := NEW.created_by;
  ELSE
    v_assigned_by_id := COALESCE(NEW.updated_by, NEW.created_by);
  END IF;
  
  -- Buscar título da tarefa
  v_task_title := NEW.title;
  
  -- Buscar nome de quem atribuiu
  SELECT full_name INTO v_assigned_by_name
  FROM public.profiles
  WHERE id = v_assigned_by_id;
  
  -- Obter arrays de IDs (garantir que não sejam NULL)
  v_old_assignee_ids := COALESCE(OLD.assignee_user_ids, ARRAY[]::UUID[]);
  v_new_assignee_ids := COALESCE(NEW.assignee_user_ids, ARRAY[]::UUID[]);
  
  -- Notificar usuários ADICIONADOS ao array
  IF TG_OP = 'INSERT' THEN
    -- Na criação, notificar todos os usuários no array (exceto quem criou)
    FOREACH v_new_assignee_id IN ARRAY v_new_assignee_ids
    LOOP
      -- Não notificar se o usuário atribuiu a tarefa para si mesmo
      IF v_new_assignee_id != v_assigned_by_id THEN
        PERFORM public.create_notification(
          p_user_id := v_new_assignee_id,
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
    END LOOP;
  ELSE
    -- Na atualização, notificar apenas os NOVOS usuários (que não estavam no array antes)
    FOREACH v_new_assignee_id IN ARRAY v_new_assignee_ids
    LOOP
      -- Verificar se o usuário NÃO estava no array antigo
      IF NOT (v_new_assignee_id = ANY(v_old_assignee_ids)) THEN
        -- Não notificar se o usuário atribuiu a tarefa para si mesmo
        IF v_new_assignee_id != v_assigned_by_id THEN
          PERFORM public.create_notification(
            p_user_id := v_new_assignee_id,
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
      END IF;
    END LOOP;
  END IF;
  
  -- Notificar usuários REMOVIDOS do array
  IF TG_OP = 'UPDATE' THEN
    FOREACH v_new_assignee_id IN ARRAY v_old_assignee_ids
    LOOP
      -- Verificar se o usuário NÃO está mais no array novo
      IF NOT (v_new_assignee_id = ANY(v_new_assignee_ids)) THEN
        -- Não notificar se o usuário removeu a si mesmo
        IF v_new_assignee_id != v_assigned_by_id THEN
          PERFORM public.create_notification(
            p_user_id := v_new_assignee_id,
            p_organization_id := NEW.organization_id,
            p_type := 'task_unassigned',
            p_title := 'Removido de tarefa',
            p_message := 'Você foi removido da tarefa: ' || v_task_title,
            p_entity_type := 'task',
            p_entity_id := NEW.id,
            p_metadata := jsonb_build_object(
              'task_id', NEW.id,
              'task_title', v_task_title,
              'removed_by', v_assigned_by_id,
              'removed_by_name', COALESCE(v_assigned_by_name, 'Sistema'),
              'project_id', NEW.project_id
            )
          );
        END IF;
      END IF;
    END LOOP;
  END IF;
  
  RETURN NEW;
END;
$$;

-- Remover trigger antigo se existir
DROP TRIGGER IF EXISTS trigger_notify_assignee_user_ids_changes ON public.tasks;

-- Criar trigger para monitorar mudanças no array assignee_user_ids
CREATE TRIGGER trigger_notify_assignee_user_ids_changes
  AFTER INSERT OR UPDATE OF assignee_user_ids ON public.tasks
  FOR EACH ROW
  EXECUTE FUNCTION public.notify_assignee_user_ids_changes();

-- ============================================================================
-- IMPORTANTE: Esta trigger complementa as triggers existentes:
-- - notify_task_assigned() - Notifica quando assigned_to muda
-- - notify_task_unassigned() - Notifica quando assigned_to é removido
-- - notify_assignee_user_ids_changes() - Notifica quando assignee_user_ids muda
-- ============================================================================

