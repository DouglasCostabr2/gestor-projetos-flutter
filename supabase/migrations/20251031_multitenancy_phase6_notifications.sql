-- ============================================================================
-- MULTI-TENANCY IMPLEMENTATION - PHASE 6: NOTIFICATIONS
-- ============================================================================
-- Date: 2025-10-31
-- Description: Update notifications system for multi-tenancy
-- Author: System
-- ============================================================================

-- ============================================================================
-- 1. ADD NEW NOTIFICATION TYPES FOR ORGANIZATIONS
-- ============================================================================

-- Drop existing constraint
ALTER TABLE public.notifications
DROP CONSTRAINT IF EXISTS notifications_type_check;

-- Add constraint with new organization types
ALTER TABLE public.notifications
ADD CONSTRAINT notifications_type_check CHECK (type IN (
  'task_assigned',
  'task_due_soon',
  'task_overdue',
  'task_updated',
  'task_comment',
  'task_status_changed',
  'task_created',
  'project_added',
  'project_updated',
  'mention',
  'payment_received',
  'client_created',
  'company_created',
  'organization_invite_received',
  'organization_role_changed',
  'organization_member_added'
));

-- Update entity_type constraint
ALTER TABLE public.notifications
DROP CONSTRAINT IF EXISTS notifications_entity_type_check;

ALTER TABLE public.notifications
ADD CONSTRAINT notifications_entity_type_check CHECK (entity_type IN (
  'task',
  'project',
  'comment',
  'payment',
  'mention',
  'client',
  'company',
  'organization'
));

-- ============================================================================
-- 2. UPDATE create_notification FUNCTION TO INCLUDE organization_id
-- ============================================================================

CREATE OR REPLACE FUNCTION public.create_notification(
  p_user_id UUID,
  p_organization_id UUID,
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
    organization_id,
    type,
    title,
    message,
    entity_type,
    entity_id,
    metadata
  ) VALUES (
    p_user_id,
    p_organization_id,
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

COMMENT ON FUNCTION public.create_notification IS 'Função auxiliar para criar notificações de forma segura com suporte a multi-tenancy';

-- ============================================================================
-- 3. UPDATE EXISTING TRIGGERS TO INCLUDE organization_id
-- ============================================================================

-- Update task assignment trigger
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
-- 4. CREATE HELPER FUNCTION TO NOTIFY ORGANIZATION MEMBERS
-- ============================================================================

CREATE OR REPLACE FUNCTION public.notify_organization_members(
  p_organization_id UUID,
  p_type TEXT,
  p_title TEXT,
  p_message TEXT,
  p_entity_type TEXT DEFAULT NULL,
  p_entity_id UUID DEFAULT NULL,
  p_metadata JSONB DEFAULT '{}'::jsonb,
  p_exclude_user_id UUID DEFAULT NULL,
  p_roles TEXT[] DEFAULT NULL
)
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_member RECORD;
  v_notification_count INTEGER := 0;
BEGIN
  -- Iterar sobre membros ativos da organização
  FOR v_member IN
    SELECT user_id, role
    FROM public.organization_members
    WHERE organization_id = p_organization_id
      AND status = 'active'
      AND (p_exclude_user_id IS NULL OR user_id != p_exclude_user_id)
      AND (p_roles IS NULL OR role = ANY(p_roles))
  LOOP
    -- Criar notificação para o membro
    PERFORM public.create_notification(
      p_user_id := v_member.user_id,
      p_organization_id := p_organization_id,
      p_type := p_type,
      p_title := p_title,
      p_message := p_message,
      p_entity_type := p_entity_type,
      p_entity_id := p_entity_id,
      p_metadata := p_metadata
    );
    
    v_notification_count := v_notification_count + 1;
  END LOOP;
  
  RETURN v_notification_count;
END;
$$;

COMMENT ON FUNCTION public.notify_organization_members IS 'Notifica membros de uma organização com filtros opcionais de role';

-- ============================================================================
-- 5. CREATE TRIGGER FOR ORGANIZATION INVITES
-- ============================================================================

CREATE OR REPLACE FUNCTION public.notify_organization_invite()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_org_name TEXT;
  v_inviter_name TEXT;
  v_user_id UUID;
BEGIN
  -- Buscar nome da organização
  SELECT name INTO v_org_name
  FROM public.organizations
  WHERE id = NEW.organization_id;
  
  -- Buscar nome de quem convidou
  SELECT full_name INTO v_inviter_name
  FROM public.profiles
  WHERE id = NEW.invited_by;
  
  -- Buscar user_id do email convidado (se já for usuário)
  SELECT id INTO v_user_id
  FROM auth.users
  WHERE email = NEW.email;
  
  -- Se o usuário já existe, criar notificação
  IF v_user_id IS NOT NULL THEN
    PERFORM public.create_notification(
      p_user_id := v_user_id,
      p_organization_id := NEW.organization_id,
      p_type := 'organization_invite_received',
      p_title := 'Convite para organização',
      p_message := COALESCE(v_inviter_name, 'Alguém') || ' convidou você para ' || COALESCE(v_org_name, 'uma organização'),
      p_entity_type := 'organization',
      p_entity_id := NEW.organization_id,
      p_metadata := jsonb_build_object(
        'invite_id', NEW.id,
        'organization_id', NEW.organization_id,
        'organization_name', v_org_name,
        'role', NEW.role,
        'invited_by', NEW.invited_by,
        'invited_by_name', v_inviter_name
      )
    );
  END IF;
  
  RETURN NEW;
END;
$$;

CREATE TRIGGER trigger_notify_organization_invite
  AFTER INSERT ON public.organization_invites
  FOR EACH ROW
  EXECUTE FUNCTION public.notify_organization_invite();

-- ============================================================================
-- 6. CREATE TRIGGER FOR ORGANIZATION ROLE CHANGES
-- ============================================================================

CREATE OR REPLACE FUNCTION public.notify_organization_role_change()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_org_name TEXT;
BEGIN
  -- Só notificar se o role mudou
  IF OLD.role IS DISTINCT FROM NEW.role THEN
    -- Buscar nome da organização
    SELECT name INTO v_org_name
    FROM public.organizations
    WHERE id = NEW.organization_id;
    
    -- Criar notificação para o usuário
    PERFORM public.create_notification(
      p_user_id := NEW.user_id,
      p_organization_id := NEW.organization_id,
      p_type := 'organization_role_changed',
      p_title := 'Seu role foi alterado',
      p_message := 'Seu role em ' || COALESCE(v_org_name, 'uma organização') || ' foi alterado de ' || OLD.role || ' para ' || NEW.role,
      p_entity_type := 'organization',
      p_entity_id := NEW.organization_id,
      p_metadata := jsonb_build_object(
        'organization_id', NEW.organization_id,
        'organization_name', v_org_name,
        'old_role', OLD.role,
        'new_role', NEW.role
      )
    );
  END IF;
  
  RETURN NEW;
END;
$$;

CREATE TRIGGER trigger_notify_organization_role_change
  AFTER UPDATE ON public.organization_members
  FOR EACH ROW
  WHEN (OLD.role IS DISTINCT FROM NEW.role)
  EXECUTE FUNCTION public.notify_organization_role_change();

-- ============================================================================
-- PHASE 6 COMPLETE
-- ============================================================================

DO $$
BEGIN
  RAISE NOTICE '========================================';
  RAISE NOTICE 'PHASE 6 - NOTIFICATIONS COMPLETED';
  RAISE NOTICE '========================================';
  RAISE NOTICE 'Added 3 new notification types for organizations';
  RAISE NOTICE 'Updated create_notification function with organization_id';
  RAISE NOTICE 'Updated task assignment trigger';
  RAISE NOTICE 'Created notify_organization_members helper function';
  RAISE NOTICE 'Created triggers for invites and role changes';
  RAISE NOTICE '========================================';
END $$;

