-- ============================================================================
-- NOTIFICATIONS SYSTEM
-- ============================================================================
-- Migration para criar sistema completo de notificações
-- Data: 2025-10-30
-- Descrição: Tabela de notificações, índices, RLS policies e triggers automáticos

-- ============================================================================
-- PARTE 1: CRIAR TABELA DE NOTIFICAÇÕES
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.notifications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  type TEXT NOT NULL CHECK (type IN (
    'task_assigned',
    'task_due_soon',
    'task_overdue',
    'task_updated',
    'task_comment',
    'task_status_changed',
    'project_added',
    'project_updated',
    'mention',
    'payment_received'
  )),
  title TEXT NOT NULL,
  message TEXT NOT NULL,
  entity_type TEXT CHECK (entity_type IN ('task', 'project', 'comment', 'payment', 'mention')),
  entity_id UUID,
  is_read BOOLEAN NOT NULL DEFAULT FALSE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  read_at TIMESTAMPTZ,
  metadata JSONB DEFAULT '{}'::jsonb
);

-- Comentários explicativos
COMMENT ON TABLE public.notifications IS 'Armazena notificações dos usuários';
COMMENT ON COLUMN public.notifications.id IS 'ID único da notificação';
COMMENT ON COLUMN public.notifications.user_id IS 'ID do usuário que receberá a notificação';
COMMENT ON COLUMN public.notifications.type IS 'Tipo da notificação';
COMMENT ON COLUMN public.notifications.title IS 'Título da notificação';
COMMENT ON COLUMN public.notifications.message IS 'Mensagem descritiva da notificação';
COMMENT ON COLUMN public.notifications.entity_type IS 'Tipo da entidade relacionada (task, project, comment, payment, mention)';
COMMENT ON COLUMN public.notifications.entity_id IS 'ID da entidade relacionada';
COMMENT ON COLUMN public.notifications.is_read IS 'Indica se a notificação foi lida';
COMMENT ON COLUMN public.notifications.created_at IS 'Data/hora de criação da notificação';
COMMENT ON COLUMN public.notifications.read_at IS 'Data/hora em que a notificação foi lida';
COMMENT ON COLUMN public.notifications.metadata IS 'Dados adicionais em formato JSON';

-- ============================================================================
-- PARTE 2: CRIAR ÍNDICES PARA PERFORMANCE
-- ============================================================================

-- Índice para buscar notificações não lidas de um usuário (query mais comum)
CREATE INDEX IF NOT EXISTS idx_notifications_user_unread 
ON public.notifications(user_id, is_read) 
WHERE is_read = FALSE;

-- Índice para buscar notificações de um usuário ordenadas por data
CREATE INDEX IF NOT EXISTS idx_notifications_user_created 
ON public.notifications(user_id, created_at DESC);

-- Índice para buscar notificações de uma entidade específica
CREATE INDEX IF NOT EXISTS idx_notifications_entity 
ON public.notifications(entity_type, entity_id);

-- Índice para buscar por tipo de notificação
CREATE INDEX IF NOT EXISTS idx_notifications_type 
ON public.notifications(type);

-- ============================================================================
-- PARTE 3: ROW LEVEL SECURITY (RLS)
-- ============================================================================

-- Habilitar RLS na tabela
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;

-- Policy: Usuários só podem ver suas próprias notificações
CREATE POLICY "notifications_select_own"
  ON public.notifications
  FOR SELECT
  TO authenticated
  USING (user_id = auth.uid());

-- Policy: Usuários só podem atualizar suas próprias notificações (marcar como lida)
CREATE POLICY "notifications_update_own"
  ON public.notifications
  FOR UPDATE
  TO authenticated
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

-- Policy: Usuários só podem deletar suas próprias notificações
CREATE POLICY "notifications_delete_own"
  ON public.notifications
  FOR DELETE
  TO authenticated
  USING (user_id = auth.uid());

-- Policy: Sistema pode inserir notificações (via triggers)
CREATE POLICY "notifications_insert_system"
  ON public.notifications
  FOR INSERT
  TO authenticated
  WITH CHECK (true);

-- ============================================================================
-- PARTE 4: FUNÇÃO AUXILIAR PARA CRIAR NOTIFICAÇÕES
-- ============================================================================

CREATE OR REPLACE FUNCTION public.create_notification(
  p_user_id UUID,
  p_type TEXT,
  p_title TEXT,
  p_message TEXT,
  p_entity_type TEXT DEFAULT NULL,
  p_entity_id UUID DEFAULT NULL,
  p_metadata JSONB DEFAULT '{}'::jsonb
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_notification_id UUID;
BEGIN
  -- Inserir notificação
  INSERT INTO public.notifications (
    user_id,
    type,
    title,
    message,
    entity_type,
    entity_id,
    metadata
  ) VALUES (
    p_user_id,
    p_type,
    p_title,
    p_message,
    p_entity_type,
    p_entity_id,
    p_metadata
  )
  RETURNING id INTO v_notification_id;
  
  RETURN v_notification_id;
END;
$$;

COMMENT ON FUNCTION public.create_notification IS 'Função auxiliar para criar notificações de forma segura';

-- ============================================================================
-- PARTE 5: TRIGGER PARA NOTIFICAR QUANDO TAREFA É ATRIBUÍDA
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
  -- Apenas notificar se assigned_to mudou e não é NULL
  IF (TG_OP = 'UPDATE' AND NEW.assigned_to IS DISTINCT FROM OLD.assigned_to AND NEW.assigned_to IS NOT NULL) OR
     (TG_OP = 'INSERT' AND NEW.assigned_to IS NOT NULL) THEN
    
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

CREATE TRIGGER trigger_notify_task_assigned
  AFTER INSERT OR UPDATE OF assigned_to ON public.tasks
  FOR EACH ROW
  EXECUTE FUNCTION public.notify_task_assigned();

-- ============================================================================
-- PARTE 6: TRIGGER PARA NOTIFICAR MUDANÇA DE STATUS DA TAREFA
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

CREATE TRIGGER trigger_notify_task_status_changed
  AFTER UPDATE OF status ON public.tasks
  FOR EACH ROW
  EXECUTE FUNCTION public.notify_task_status_changed();

-- ============================================================================
-- PARTE 7: TRIGGER PARA NOTIFICAR NOVOS COMENTÁRIOS
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

  -- Notificar outros responsáveis (assignee_user_ids)
  IF v_task.assignee_user_ids IS NOT NULL THEN
    FOR v_user_id IN SELECT unnest(v_task.assignee_user_ids)
    LOOP
      -- Não notificar quem fez o comentário
      IF v_user_id != NEW.user_id THEN
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
    END LOOP;
  END IF;

  -- Notificar o criador da tarefa (se não for quem comentou e não for o responsável)
  IF v_task.created_by IS NOT NULL
     AND v_task.created_by != NEW.user_id
     AND v_task.created_by != v_task.assigned_to THEN
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

  RETURN NEW;
END;
$$;

CREATE TRIGGER trigger_notify_task_comment
  AFTER INSERT ON public.task_comments
  FOR EACH ROW
  EXECUTE FUNCTION public.notify_task_comment();

-- ============================================================================
-- PARTE 8: TRIGGER PARA NOTIFICAR MENÇÕES
-- ============================================================================

CREATE OR REPLACE FUNCTION public.notify_mention()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_mentioner_name TEXT;
  v_context_title TEXT;
  v_entity_type TEXT;
  v_entity_id UUID;
BEGIN
  -- Buscar nome de quem mencionou
  SELECT full_name INTO v_mentioner_name
  FROM public.profiles
  WHERE id = NEW.mentioned_by_user_id;

  -- Determinar contexto baseado na tabela
  IF TG_TABLE_NAME = 'comment_mentions' THEN
    -- Buscar título da tarefa do comentário
    SELECT t.title, t.id INTO v_context_title, v_entity_id
    FROM public.task_comments c
    JOIN public.tasks t ON t.id = c.task_id
    WHERE c.id = NEW.comment_id;
    v_entity_type := 'comment';

  ELSIF TG_TABLE_NAME = 'task_mentions' THEN
    -- Buscar título da tarefa
    SELECT title, id INTO v_context_title, v_entity_id
    FROM public.tasks
    WHERE id = NEW.task_id;
    v_entity_type := 'task';

  ELSIF TG_TABLE_NAME = 'project_mentions' THEN
    -- Buscar nome do projeto
    SELECT name, id INTO v_context_title, v_entity_id
    FROM public.projects
    WHERE id = NEW.project_id;
    v_entity_type := 'project';
  END IF;

  -- Criar notificação para o usuário mencionado
  PERFORM public.create_notification(
    p_user_id := NEW.mentioned_user_id,
    p_type := 'mention',
    p_title := 'Você foi mencionado',
    p_message := COALESCE(v_mentioner_name, 'Alguém') || ' mencionou você em: ' || COALESCE(v_context_title, 'um item'),
    p_entity_type := v_entity_type,
    p_entity_id := v_entity_id,
    p_metadata := jsonb_build_object(
      'mentioned_by', NEW.mentioned_by_user_id,
      'mentioned_by_name', COALESCE(v_mentioner_name, 'Desconhecido'),
      'context', TG_TABLE_NAME
    )
  );

  RETURN NEW;
END;
$$;

CREATE TRIGGER trigger_notify_comment_mention
  AFTER INSERT ON public.comment_mentions
  FOR EACH ROW
  EXECUTE FUNCTION public.notify_mention();

CREATE TRIGGER trigger_notify_task_mention
  AFTER INSERT ON public.task_mentions
  FOR EACH ROW
  EXECUTE FUNCTION public.notify_mention();

CREATE TRIGGER trigger_notify_project_mention
  AFTER INSERT ON public.project_mentions
  FOR EACH ROW
  EXECUTE FUNCTION public.notify_mention();

-- ============================================================================
-- PARTE 9: TRIGGER PARA NOTIFICAR QUANDO USUÁRIO É ADICIONADO A PROJETO
-- ============================================================================

CREATE OR REPLACE FUNCTION public.notify_project_member_added()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_project_name TEXT;
  v_added_by_name TEXT;
BEGIN
  -- Buscar nome do projeto
  SELECT name INTO v_project_name
  FROM public.projects
  WHERE id = NEW.project_id;

  -- Buscar nome de quem adicionou (se disponível)
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

CREATE TRIGGER trigger_notify_project_member_added
  AFTER INSERT ON public.project_members
  FOR EACH ROW
  EXECUTE FUNCTION public.notify_project_member_added();

-- ============================================================================
-- PARTE 10: TRIGGER PARA NOTIFICAR PAGAMENTOS
-- ============================================================================

CREATE OR REPLACE FUNCTION public.notify_payment_received()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_project RECORD;
  v_paid_by_name TEXT;
BEGIN
  -- Apenas notificar se paid_to está definido
  IF NEW.paid_to IS NOT NULL THEN

    -- Buscar informações do projeto
    SELECT id, name INTO v_project
    FROM public.projects
    WHERE id = NEW.project_id;

    -- Buscar nome de quem registrou o pagamento
    SELECT full_name INTO v_paid_by_name
    FROM public.profiles
    WHERE id = NEW.paid_by;

    -- Criar notificação para quem recebeu o pagamento
    PERFORM public.create_notification(
      p_user_id := NEW.paid_to,
      p_type := 'payment_received',
      p_title := 'Pagamento registrado',
      p_message := 'Um pagamento de ' || (NEW.amount_cents / 100.0)::TEXT || ' ' || NEW.currency_code || ' foi registrado para você no projeto: ' || COALESCE(v_project.name, 'Desconhecido'),
      p_entity_type := 'payment',
      p_entity_id := NEW.id,
      p_metadata := jsonb_build_object(
        'payment_id', NEW.id,
        'project_id', NEW.project_id,
        'project_name', COALESCE(v_project.name, 'Desconhecido'),
        'amount_cents', NEW.amount_cents,
        'currency_code', NEW.currency_code,
        'paid_by', NEW.paid_by,
        'paid_by_name', COALESCE(v_paid_by_name, 'Sistema'),
        'payment_date', NEW.payment_date
      )
    );
  END IF;

  RETURN NEW;
END;
$$;

CREATE TRIGGER trigger_notify_payment_received
  AFTER INSERT ON public.payments
  FOR EACH ROW
  EXECUTE FUNCTION public.notify_payment_received();

