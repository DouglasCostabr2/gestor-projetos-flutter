-- ============================================================================
-- Migration: Fix notify_task_status_changed to include organization_id
-- Date: 2025-11-04
-- Description: Updates the task status change notification trigger to include
--              organization_id parameter when calling create_notification
-- ============================================================================

-- ============================================================================
-- FIX TASK STATUS CHANGED NOTIFICATION
-- ============================================================================
CREATE OR REPLACE FUNCTION public.notify_task_status_changed()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_task_title TEXT;
  v_updated_by_name TEXT;
  v_user_id UUID;
BEGIN
  -- Apenas notificar se status mudou
  IF TG_OP = 'UPDATE' AND NEW.status IS DISTINCT FROM OLD.status THEN
    
    v_task_title := NEW.title;
    
    -- Buscar nome de quem atualizou
    SELECT full_name INTO v_updated_by_name
    FROM public.profiles
    WHERE id = NEW.updated_by;
    
    -- Notificar o responsável pela tarefa (se não for quem atualizou)
    IF NEW.assigned_to IS NOT NULL AND NEW.assigned_to != NEW.updated_by THEN
      PERFORM public.create_notification(
        p_user_id := NEW.assigned_to,
        p_organization_id := NEW.organization_id,
        p_type := 'task_status_changed',
        p_title := 'Status da tarefa alterado',
        p_message := 'A tarefa "' || v_task_title || '" mudou para: ' || NEW.status,
        p_entity_type := 'task',
        p_entity_id := NEW.id,
        p_metadata := jsonb_build_object(
          'task_id', NEW.id,
          'task_title', v_task_title,
          'old_status', OLD.status,
          'new_status', NEW.status,
          'updated_by', NEW.updated_by,
          'updated_by_name', COALESCE(v_updated_by_name, 'Sistema')
        )
      );
    END IF;
    
    -- Notificar outros responsáveis (assignee_user_ids)
    IF NEW.assignee_user_ids IS NOT NULL THEN
      FOR v_user_id IN SELECT unnest(NEW.assignee_user_ids)
      LOOP
        -- Não notificar quem fez a mudança
        IF v_user_id != NEW.updated_by THEN
          PERFORM public.create_notification(
            p_user_id := v_user_id,
            p_organization_id := NEW.organization_id,
            p_type := 'task_status_changed',
            p_title := 'Status da tarefa alterado',
            p_message := 'A tarefa "' || v_task_title || '" mudou para: ' || NEW.status,
            p_entity_type := 'task',
            p_entity_id := NEW.id,
            p_metadata := jsonb_build_object(
              'task_id', NEW.id,
              'task_title', v_task_title,
              'old_status', OLD.status,
              'new_status', NEW.status,
              'updated_by', NEW.updated_by,
              'updated_by_name', COALESCE(v_updated_by_name, 'Sistema')
            )
          );
        END IF;
      END LOOP;
    END IF;
  END IF;
  
  RETURN NEW;
END;
$$;

-- Completion notice
DO $$
BEGIN
  RAISE NOTICE '✅ Fixed notify_task_status_changed trigger to include organization_id';
END $$;

