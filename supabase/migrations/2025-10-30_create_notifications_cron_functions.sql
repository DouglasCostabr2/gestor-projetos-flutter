-- ============================================================================
-- NOTIFICATIONS CRON FUNCTIONS
-- ============================================================================
-- Funções para serem executadas periodicamente (via cron ou chamada manual)
-- para verificar tarefas que estão prestes a vencer ou vencidas

-- ============================================================================
-- FUNÇÃO PARA NOTIFICAR TAREFAS QUE VENCEM EM 1 DIA
-- ============================================================================

CREATE OR REPLACE FUNCTION public.notify_tasks_due_soon()
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_task RECORD;
  v_notification_count INTEGER := 0;
  v_tomorrow DATE;
  v_existing_notification UUID;
BEGIN
  -- Calcular data de amanhã
  v_tomorrow := CURRENT_DATE + INTERVAL '1 day';
  
  -- Buscar tarefas que vencem amanhã e não estão completas
  FOR v_task IN
    SELECT 
      t.id,
      t.title,
      t.assigned_to,
      t.assignee_user_ids,
      t.due_date,
      t.project_id,
      p.name as project_name
    FROM public.tasks t
    LEFT JOIN public.projects p ON p.id = t.project_id
    WHERE 
      DATE(t.due_date) = v_tomorrow
      AND t.status NOT IN ('completed', 'cancelled')
  LOOP
    -- Notificar o responsável principal
    IF v_task.assigned_to IS NOT NULL THEN
      -- Verificar se já existe notificação similar nas últimas 24h
      SELECT id INTO v_existing_notification
      FROM public.notifications
      WHERE 
        user_id = v_task.assigned_to
        AND type = 'task_due_soon'
        AND entity_id = v_task.id
        AND created_at > NOW() - INTERVAL '24 hours'
      LIMIT 1;
      
      -- Só criar se não existir notificação recente
      IF v_existing_notification IS NULL THEN
        PERFORM public.create_notification(
          p_user_id := v_task.assigned_to,
          p_type := 'task_due_soon',
          p_title := 'Tarefa vence amanhã',
          p_message := 'A tarefa "' || v_task.title || '" vence amanhã',
          p_entity_type := 'task',
          p_entity_id := v_task.id,
          p_metadata := jsonb_build_object(
            'task_id', v_task.id,
            'task_title', v_task.title,
            'due_date', v_task.due_date,
            'project_id', v_task.project_id,
            'project_name', COALESCE(v_task.project_name, 'Sem projeto')
          )
        );
        v_notification_count := v_notification_count + 1;
      END IF;
    END IF;
    
    -- Notificar outros responsáveis (assignee_user_ids)
    IF v_task.assignee_user_ids IS NOT NULL THEN
      FOR v_user_id IN SELECT unnest(v_task.assignee_user_ids)
      LOOP
        -- Verificar se já existe notificação similar nas últimas 24h
        SELECT id INTO v_existing_notification
        FROM public.notifications
        WHERE 
          user_id = v_user_id
          AND type = 'task_due_soon'
          AND entity_id = v_task.id
          AND created_at > NOW() - INTERVAL '24 hours'
        LIMIT 1;
        
        -- Só criar se não existir notificação recente
        IF v_existing_notification IS NULL THEN
          PERFORM public.create_notification(
            p_user_id := v_user_id,
            p_type := 'task_due_soon',
            p_title := 'Tarefa vence amanhã',
            p_message := 'A tarefa "' || v_task.title || '" vence amanhã',
            p_entity_type := 'task',
            p_entity_id := v_task.id,
            p_metadata := jsonb_build_object(
              'task_id', v_task.id,
              'task_title', v_task.title,
              'due_date', v_task.due_date,
              'project_id', v_task.project_id,
              'project_name', COALESCE(v_task.project_name, 'Sem projeto')
            )
          );
          v_notification_count := v_notification_count + 1;
        END IF;
      END LOOP;
    END IF;
  END LOOP;
  
  RETURN v_notification_count;
END;
$$;

COMMENT ON FUNCTION public.notify_tasks_due_soon IS 'Notifica usuários sobre tarefas que vencem em 1 dia. Retorna quantidade de notificações criadas.';

-- ============================================================================
-- FUNÇÃO PARA NOTIFICAR TAREFAS VENCIDAS
-- ============================================================================

CREATE OR REPLACE FUNCTION public.notify_tasks_overdue()
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_task RECORD;
  v_notification_count INTEGER := 0;
  v_existing_notification UUID;
  v_user_id UUID;
BEGIN
  -- Buscar tarefas vencidas que não estão completas
  FOR v_task IN
    SELECT 
      t.id,
      t.title,
      t.assigned_to,
      t.assignee_user_ids,
      t.due_date,
      t.project_id,
      p.name as project_name
    FROM public.tasks t
    LEFT JOIN public.projects p ON p.id = t.project_id
    WHERE 
      DATE(t.due_date) < CURRENT_DATE
      AND t.status NOT IN ('completed', 'cancelled')
  LOOP
    -- Notificar o responsável principal
    IF v_task.assigned_to IS NOT NULL THEN
      -- Verificar se já existe notificação similar nas últimas 24h
      SELECT id INTO v_existing_notification
      FROM public.notifications
      WHERE 
        user_id = v_task.assigned_to
        AND type = 'task_overdue'
        AND entity_id = v_task.id
        AND created_at > NOW() - INTERVAL '24 hours'
      LIMIT 1;
      
      -- Só criar se não existir notificação recente
      IF v_existing_notification IS NULL THEN
        PERFORM public.create_notification(
          p_user_id := v_task.assigned_to,
          p_type := 'task_overdue',
          p_title := 'Tarefa vencida',
          p_message := 'A tarefa "' || v_task.title || '" está vencida desde ' || TO_CHAR(v_task.due_date, 'DD/MM/YYYY'),
          p_entity_type := 'task',
          p_entity_id := v_task.id,
          p_metadata := jsonb_build_object(
            'task_id', v_task.id,
            'task_title', v_task.title,
            'due_date', v_task.due_date,
            'days_overdue', CURRENT_DATE - DATE(v_task.due_date),
            'project_id', v_task.project_id,
            'project_name', COALESCE(v_task.project_name, 'Sem projeto')
          )
        );
        v_notification_count := v_notification_count + 1;
      END IF;
    END IF;
    
    -- Notificar outros responsáveis (assignee_user_ids)
    IF v_task.assignee_user_ids IS NOT NULL THEN
      FOR v_user_id IN SELECT unnest(v_task.assignee_user_ids)
      LOOP
        -- Verificar se já existe notificação similar nas últimas 24h
        SELECT id INTO v_existing_notification
        FROM public.notifications
        WHERE 
          user_id = v_user_id
          AND type = 'task_overdue'
          AND entity_id = v_task.id
          AND created_at > NOW() - INTERVAL '24 hours'
        LIMIT 1;
        
        -- Só criar se não existir notificação recente
        IF v_existing_notification IS NULL THEN
          PERFORM public.create_notification(
            p_user_id := v_user_id,
            p_type := 'task_overdue',
            p_title := 'Tarefa vencida',
            p_message := 'A tarefa "' || v_task.title || '" está vencida desde ' || TO_CHAR(v_task.due_date, 'DD/MM/YYYY'),
            p_entity_type := 'task',
            p_entity_id := v_task.id,
            p_metadata := jsonb_build_object(
              'task_id', v_task.id,
              'task_title', v_task.title,
              'due_date', v_task.due_date,
              'days_overdue', CURRENT_DATE - DATE(v_task.due_date),
              'project_id', v_task.project_id,
              'project_name', COALESCE(v_task.project_name, 'Sem projeto')
            )
          );
          v_notification_count := v_notification_count + 1;
        END IF;
      END LOOP;
    END IF;
  END LOOP;
  
  RETURN v_notification_count;
END;
$$;

COMMENT ON FUNCTION public.notify_tasks_overdue IS 'Notifica usuários sobre tarefas vencidas. Retorna quantidade de notificações criadas.';

-- ============================================================================
-- FUNÇÃO PARA LIMPAR NOTIFICAÇÕES ANTIGAS (OPCIONAL)
-- ============================================================================

CREATE OR REPLACE FUNCTION public.cleanup_old_notifications(days_to_keep INTEGER DEFAULT 90)
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_deleted_count INTEGER;
BEGIN
  -- Deletar notificações lidas com mais de X dias
  DELETE FROM public.notifications
  WHERE 
    is_read = TRUE
    AND read_at < NOW() - (days_to_keep || ' days')::INTERVAL;
  
  GET DIAGNOSTICS v_deleted_count = ROW_COUNT;
  
  RETURN v_deleted_count;
END;
$$;

COMMENT ON FUNCTION public.cleanup_old_notifications IS 'Remove notificações lidas antigas. Padrão: 90 dias. Retorna quantidade deletada.';

