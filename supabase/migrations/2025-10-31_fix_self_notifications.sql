-- Migration: Fix Self Notifications
-- Data: 2025-10-31
-- Descrição: Evita que usuários recebam notificações de suas próprias ações

-- ============================================================================
-- PARTE 1: CORRIGIR NOTIFICAÇÃO DE TAREFA ATRIBUÍDA
-- ============================================================================
-- Não notificar se o usuário atribuiu a tarefa para si mesmo

CREATE OR REPLACE FUNCTION public.notify_task_assigned()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_task_title TEXT;
  v_assigned_by_name TEXT;
BEGIN
  -- Apenas notificar se assigned_to mudou e não é NULL
  IF (TG_OP = 'UPDATE' AND NEW.assigned_to IS DISTINCT FROM OLD.assigned_to AND NEW.assigned_to IS NOT NULL) OR
     (TG_OP = 'INSERT' AND NEW.assigned_to IS NOT NULL) THEN
    
    -- NÃO notificar se o usuário atribuiu a tarefa para si mesmo
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
-- PARTE 2: CORRIGIR NOTIFICAÇÃO DE MEMBRO ADICIONADO A PROJETO
-- ============================================================================
-- Não notificar se o usuário adicionou a si mesmo ao projeto

CREATE OR REPLACE FUNCTION public.notify_project_member_added()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_project_name TEXT;
  v_added_by_name TEXT;
BEGIN
  -- NÃO notificar se o usuário adicionou a si mesmo
  IF NEW.user_id = auth.uid() THEN
    RETURN NEW;
  END IF;

  -- Buscar nome do projeto
  SELECT name INTO v_project_name
  FROM public.projects
  WHERE id = NEW.project_id;

  -- Buscar nome de quem adicionou
  SELECT full_name INTO v_added_by_name
  FROM public.profiles
  WHERE id = auth.uid();

  -- Criar notificação para o membro adicionado
  PERFORM public.create_notification(
    p_user_id := NEW.user_id,
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
-- PARTE 3: CORRIGIR NOTIFICAÇÃO DE MENÇÃO EM TAREFA
-- ============================================================================
-- Não notificar se o usuário mencionou a si mesmo

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

-- ============================================================================
-- PARTE 4: CORRIGIR NOTIFICAÇÃO DE MENÇÃO EM PROJETO
-- ============================================================================
-- Não notificar se o usuário mencionou a si mesmo

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

-- ============================================================================
-- PARTE 5: CORRIGIR NOTIFICAÇÃO DE COMENTÁRIO
-- ============================================================================
-- Não notificar se o usuário comentou em sua própria tarefa

CREATE OR REPLACE FUNCTION public.notify_task_comment()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_task_title TEXT;
  v_commenter_name TEXT;
  v_user_id UUID;
  v_task_assigned_to UUID;
BEGIN
  -- Buscar título da tarefa e responsável
  SELECT title, assigned_to INTO v_task_title, v_task_assigned_to
  FROM public.tasks
  WHERE id = NEW.task_id;
  
  -- Buscar nome de quem comentou
  SELECT full_name INTO v_commenter_name
  FROM public.profiles
  WHERE id = NEW.user_id;
  
  -- Notificar o responsável pela tarefa (se não for quem comentou)
  IF v_task_assigned_to IS NOT NULL AND v_task_assigned_to != NEW.user_id THEN
    PERFORM public.create_notification(
      p_user_id := v_task_assigned_to,
      p_type := 'task_comment',
      p_title := 'Novo comentário',
      p_message := COALESCE(v_commenter_name, 'Alguém') || ' comentou na tarefa: ' || v_task_title,
      p_entity_type := 'task',
      p_entity_id := NEW.task_id,
      p_metadata := jsonb_build_object(
        'task_id', NEW.task_id,
        'task_title', v_task_title,
        'comment_id', NEW.id,
        'commenter_id', NEW.user_id,
        'commenter_name', COALESCE(v_commenter_name, 'Sistema')
      )
    );
  END IF;
  
  RETURN NEW;
END;
$$;

