-- ============================================================================
-- DEBUG: Organization Invite Notifications
-- ============================================================================
-- Esta migration adiciona logs detalhados para debugar por que notificações
-- de convite de organização não estão sendo criadas

-- Recriar a função com logs detalhados
CREATE OR REPLACE FUNCTION public.notify_organization_invite()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_org_name TEXT;
  v_inviter_name TEXT;
  v_user_id UUID;
  v_notification_id UUID;
BEGIN
  RAISE NOTICE '🔔 [INVITE TRIGGER] Iniciando trigger para convite ID: %', NEW.id;
  RAISE NOTICE '🔔 [INVITE TRIGGER] Email convidado: %', NEW.email;
  RAISE NOTICE '🔔 [INVITE TRIGGER] Organization ID: %', NEW.organization_id;
  RAISE NOTICE '🔔 [INVITE TRIGGER] Invited by: %', NEW.invited_by;
  
  -- Buscar nome da organização
  SELECT name INTO v_org_name
  FROM public.organizations
  WHERE id = NEW.organization_id;
  
  RAISE NOTICE '🔔 [INVITE TRIGGER] Nome da organização: %', COALESCE(v_org_name, 'NULL');
  
  -- Buscar nome de quem convidou
  SELECT full_name INTO v_inviter_name
  FROM public.profiles
  WHERE id = NEW.invited_by;
  
  RAISE NOTICE '🔔 [INVITE TRIGGER] Nome do invitador: %', COALESCE(v_inviter_name, 'NULL');
  
  -- Buscar user_id do email convidado (se já for usuário)
  SELECT id INTO v_user_id
  FROM auth.users
  WHERE email = NEW.email;
  
  RAISE NOTICE '🔔 [INVITE TRIGGER] User ID encontrado: %', COALESCE(v_user_id::TEXT, 'NULL');
  
  -- Se o usuário já existe, criar notificação
  IF v_user_id IS NOT NULL THEN
    RAISE NOTICE '🔔 [INVITE TRIGGER] Usuário existe! Criando notificação...';
    
    BEGIN
      -- Chamar create_notification e capturar o ID retornado
      SELECT public.create_notification(
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
      ) INTO v_notification_id;
      
      RAISE NOTICE '🔔 [INVITE TRIGGER] ✅ Notificação criada com sucesso! ID: %', v_notification_id;
      
    EXCEPTION WHEN OTHERS THEN
      RAISE WARNING '🔔 [INVITE TRIGGER] ❌ ERRO ao criar notificação: % - %', SQLERRM, SQLSTATE;
    END;
  ELSE
    RAISE NOTICE '🔔 [INVITE TRIGGER] ⚠️ Usuário não existe no sistema (email não encontrado em auth.users)';
  END IF;
  
  RAISE NOTICE '🔔 [INVITE TRIGGER] Trigger finalizado';
  RETURN NEW;
END;
$$;

-- Verificar se o trigger existe
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_trigger 
    WHERE tgname = 'trigger_notify_organization_invite'
  ) THEN
    RAISE NOTICE '⚠️ Trigger trigger_notify_organization_invite NÃO EXISTE! Criando...';
    
    CREATE TRIGGER trigger_notify_organization_invite
      AFTER INSERT ON public.organization_invites
      FOR EACH ROW
      EXECUTE FUNCTION public.notify_organization_invite();
      
    RAISE NOTICE '✅ Trigger criado com sucesso!';
  ELSE
    RAISE NOTICE '✅ Trigger trigger_notify_organization_invite já existe';
  END IF;
END $$;

-- Adicionar logs na função create_notification também
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
  RAISE NOTICE '📝 [CREATE_NOTIFICATION] Iniciando criação de notificação';
  RAISE NOTICE '📝 [CREATE_NOTIFICATION] User ID: %', p_user_id;
  RAISE NOTICE '📝 [CREATE_NOTIFICATION] Organization ID: %', p_organization_id;
  RAISE NOTICE '📝 [CREATE_NOTIFICATION] Type: %', p_type;
  RAISE NOTICE '📝 [CREATE_NOTIFICATION] Title: %', p_title;
  RAISE NOTICE '📝 [CREATE_NOTIFICATION] Entity Type: %', COALESCE(p_entity_type, 'NULL');
  RAISE NOTICE '📝 [CREATE_NOTIFICATION] Entity ID: %', COALESCE(p_entity_id::TEXT, 'NULL');
  
  INSERT INTO public.notifications (
    user_id,
    organization_id,
    type,
    title,
    message,
    entity_type,
    entity_id,
    metadata,
    is_read,
    created_at
  ) VALUES (
    p_user_id,
    p_organization_id,
    p_type,
    p_title,
    p_message,
    p_entity_type,
    p_entity_id,
    p_metadata,
    false,
    NOW()
  )
  RETURNING id INTO v_notification_id;
  
  RAISE NOTICE '📝 [CREATE_NOTIFICATION] ✅ Notificação inserida! ID: %', v_notification_id;
  
  RETURN v_notification_id;
  
EXCEPTION WHEN OTHERS THEN
  RAISE WARNING '📝 [CREATE_NOTIFICATION] ❌ ERRO: % - %', SQLERRM, SQLSTATE;
  RAISE;
END;
$$;

-- Query para verificar notificações criadas recentemente
RAISE NOTICE '=== VERIFICAÇÃO DE NOTIFICAÇÕES RECENTES ===';
DO $$
DECLARE
  v_count INTEGER;
BEGIN
  SELECT COUNT(*) INTO v_count
  FROM public.notifications
  WHERE type = 'organization_invite_received'
    AND created_at > NOW() - INTERVAL '1 hour';
    
  RAISE NOTICE 'Total de notificações de convite criadas na última hora: %', v_count;
END $$;

-- Query para verificar convites recentes
RAISE NOTICE '=== VERIFICAÇÃO DE CONVITES RECENTES ===';
DO $$
DECLARE
  v_count INTEGER;
BEGIN
  SELECT COUNT(*) INTO v_count
  FROM public.organization_invites
  WHERE created_at > NOW() - INTERVAL '1 hour';
    
  RAISE NOTICE 'Total de convites criados na última hora: %', v_count;
END $$;

