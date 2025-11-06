-- ============================================================================
-- Fix: Accept Organization Invite for Previously Removed Members
-- ============================================================================
-- Problema: Quando um usuário é removido de uma organização e depois recebe
-- um novo convite, ao aceitar o convite ocorre erro de constraint única
-- porque já existe um registro em organization_members (mesmo que inativo).
--
-- Solução: Modificar a função accept_organization_invite para:
-- 1. Verificar se existe membro ATIVO (não apenas se existe registro)
-- 2. Se existir membro removido/inativo, fazer UPDATE ao invés de INSERT

CREATE OR REPLACE FUNCTION public.accept_organization_invite(
  p_invite_id UUID
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER -- Executa com privilégios do owner da função
SET search_path = public
AS $$
DECLARE
  v_invite RECORD;
  v_user_id UUID;
  v_user_email TEXT;
  v_member_id UUID;
  v_existing_member RECORD;
  v_result JSON;
BEGIN
  -- Obter ID e email do usuário autenticado
  v_user_id := auth.uid();
  v_user_email := auth.jwt()->>'email';
  
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Usuário não autenticado';
  END IF;

  RAISE NOTICE '🎯 [ACCEPT_INVITE_RPC] User ID: %, Email: %', v_user_id, v_user_email;

  -- Buscar o convite
  SELECT * INTO v_invite
  FROM public.organization_invites
  WHERE id = p_invite_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Convite não encontrado';
  END IF;

  RAISE NOTICE '🎯 [ACCEPT_INVITE_RPC] Convite encontrado: org=%, role=%, email=%, status=%', 
    v_invite.organization_id, v_invite.role, v_invite.email, v_invite.status;

  -- Verificar se o convite é para o email do usuário (case-insensitive)
  IF LOWER(v_invite.email) != LOWER(v_user_email) THEN
    RAISE EXCEPTION 'Este convite não é para você (convite: %, seu email: %)', v_invite.email, v_user_email;
  END IF;

  -- Verificar se o convite está pendente
  IF v_invite.status != 'pending' THEN
    RAISE EXCEPTION 'Convite já foi processado (status: %)', v_invite.status;
  END IF;

  -- Verificar se o convite não expirou
  IF v_invite.expires_at < NOW() THEN
    RAISE EXCEPTION 'Convite expirado';
  END IF;

  -- Verificar se o usuário já é membro ATIVO da organização
  SELECT * INTO v_existing_member
  FROM public.organization_members
  WHERE organization_id = v_invite.organization_id
    AND user_id = v_user_id;

  IF FOUND THEN
    -- Se já existe um registro de membro
    IF v_existing_member.status = 'active' THEN
      -- Se o membro está ativo, não pode aceitar o convite
      RAISE EXCEPTION 'Você já é membro ativo desta organização';
    ELSE
      -- Se o membro foi removido/inativo, reativar o registro
      RAISE NOTICE '🔄 [ACCEPT_INVITE_RPC] Membro removido encontrado. Reativando...';
      
      UPDATE public.organization_members
      SET 
        role = v_invite.role,
        status = 'active',
        invited_by = v_invite.invited_by,
        joined_at = NOW(),
        updated_at = NOW()
      WHERE id = v_existing_member.id
      RETURNING id INTO v_member_id;

      RAISE NOTICE '✅ [ACCEPT_INVITE_RPC] Membro reativado! ID: %', v_member_id;
    END IF;
  ELSE
    -- Se não existe registro, criar novo membro
    RAISE NOTICE '✅ [ACCEPT_INVITE_RPC] Convite válido! Adicionando novo membro...';

    INSERT INTO public.organization_members (
      organization_id,
      user_id,
      role,
      status,
      invited_by,
      joined_at
    ) VALUES (
      v_invite.organization_id,
      v_user_id,
      v_invite.role,
      'active',
      v_invite.invited_by,
      NOW()
    )
    RETURNING id INTO v_member_id;

    RAISE NOTICE '✅ [ACCEPT_INVITE_RPC] Membro adicionado! ID: %', v_member_id;
  END IF;

  -- Atualizar status do convite
  UPDATE public.organization_invites
  SET 
    status = 'accepted',
    accepted_at = NOW()
  WHERE id = p_invite_id;

  RAISE NOTICE '✅ [ACCEPT_INVITE_RPC] Convite marcado como aceito';

  -- Retornar resultado
  SELECT json_build_object(
    'id', v_invite.id,
    'organization_id', v_invite.organization_id,
    'email', v_invite.email,
    'role', v_invite.role,
    'status', 'accepted',
    'member_id', v_member_id
  ) INTO v_result;

  RETURN v_result;
END;
$$;

-- Comentário
COMMENT ON FUNCTION public.accept_organization_invite IS 
  'Permite que um usuário autenticado aceite um convite de organização. Se o usuário foi removido anteriormente, reativa o registro ao invés de criar um novo.';

