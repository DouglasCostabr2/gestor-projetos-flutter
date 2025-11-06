-- ============================================================================
-- Migration: Add task unassigned notification
-- Date: 2025-11-06
-- Description: Notify user when they are removed from a task
-- ============================================================================

-- Primeiro, adicionar o novo tipo de notificação ao constraint
ALTER TABLE public.notifications DROP CONSTRAINT IF EXISTS notifications_type_check;

ALTER TABLE public.notifications ADD CONSTRAINT notifications_type_check 
CHECK (type = ANY (ARRAY[
  'task_assigned'::text,
  'task_unassigned'::text,  -- NOVO TIPO
  'task_due_soon'::text,
  'task_overdue'::text,
  'task_updated'::text,
  'task_comment'::text,
  'task_status_changed'::text,
  'task_created'::text,
  'project_added'::text,
  'project_updated'::text,
  'mention'::text,
  'payment_received'::text,
  'client_created'::text,
  'company_created'::text,
  'organization_invite_received'::text,
  'organization_role_changed'::text,
  'organization_member_added'::text
]));

-- Criar função para notificar quando usuário é removido de tarefa
CREATE OR REPLACE FUNCTION public.notify_task_unassigned()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_task_title TEXT;
  v_removed_by_name TEXT;
  v_removed_by_id UUID;
BEGIN
  -- Só notificar se assigned_to mudou de um usuário para NULL ou outro usuário
  IF TG_OP = 'UPDATE' AND OLD.assigned_to IS NOT NULL AND OLD.assigned_to IS DISTINCT FROM NEW.assigned_to THEN
    
    -- Determinar quem está fazendo a remoção
    v_removed_by_id := COALESCE(NEW.updated_by, NEW.created_by);
    
    -- Não notificar se o usuário removeu a si mesmo
    IF OLD.assigned_to = v_removed_by_id THEN
      RETURN NEW;
    END IF;
    
    -- Buscar título da tarefa
    v_task_title := NEW.title;
    
    -- Buscar nome de quem removeu
    SELECT full_name INTO v_removed_by_name
    FROM public.profiles
    WHERE id = v_removed_by_id;
    
    -- Criar notificação para o usuário que foi removido
    PERFORM public.create_notification(
      p_user_id := OLD.assigned_to,
      p_organization_id := NEW.organization_id,
      p_type := 'task_unassigned',
      p_title := 'Você foi removido de uma tarefa',
      p_message := 'Você foi removido da tarefa: ' || v_task_title,
      p_entity_type := 'task',
      p_entity_id := NEW.id,
      p_metadata := jsonb_build_object(
        'task_id', NEW.id,
        'task_title', v_task_title,
        'removed_by', v_removed_by_id,
        'removed_by_name', COALESCE(v_removed_by_name, 'Sistema'),
        'project_id', NEW.project_id
      )
    );
  END IF;
  
  RETURN NEW;
END;
$$;

-- Criar trigger para notificar remoção de tarefa
DROP TRIGGER IF EXISTS trigger_notify_task_unassigned ON public.tasks;

CREATE TRIGGER trigger_notify_task_unassigned
  AFTER UPDATE OF assigned_to ON public.tasks
  FOR EACH ROW
  EXECUTE FUNCTION public.notify_task_unassigned();

COMMENT ON FUNCTION public.notify_task_unassigned() IS 'Notifica usuário quando ele é removido de uma tarefa';
COMMENT ON TRIGGER trigger_notify_task_unassigned ON public.tasks IS 'Trigger para notificar quando usuário é removido de tarefa';

