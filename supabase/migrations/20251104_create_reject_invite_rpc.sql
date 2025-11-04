-- ============================================================================
-- RPC Function: Reject Organization Invite
-- ============================================================================

CREATE OR REPLACE FUNCTION public.reject_organization_invite(
  p_invite_id UUID
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_invite RECORD;
  v_user_id UUID;
  v_user_email TEXT;
  v_result JSON;
BEGIN
  -- Obter ID e email do usuário autenticado
  v_user_id := auth.uid();
  v_user_email := auth.jwt()->>'email';
  
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Usuário não autenticado';
  END IF;

  -- Buscar o convite
  SELECT * INTO v_invite
  FROM public.organization_invites
  WHERE id = p_invite_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Convite não encontrado';
  END IF;

  -- Verificar se o convite é para o email do usuário (case-insensitive)
  IF LOWER(v_invite.email) != LOWER(v_user_email) THEN
    RAISE EXCEPTION 'Este convite não é para você';
  END IF;

  -- Verificar se o convite está pendente
  IF v_invite.status != 'pending' THEN
    RAISE EXCEPTION 'Convite já foi processado';
  END IF;

  -- Atualizar status do convite
  UPDATE public.organization_invites
  SET status = 'rejected'
  WHERE id = p_invite_id;

  -- Retornar resultado
  SELECT json_build_object(
    'id', v_invite.id,
    'organization_id', v_invite.organization_id,
    'email', v_invite.email,
    'role', v_invite.role,
    'status', 'rejected'
  ) INTO v_result;

  RETURN v_result;
END;
$$;

-- Permitir que usuários autenticados chamem esta função
GRANT EXECUTE ON FUNCTION public.reject_organization_invite(UUID) TO authenticated;

-- Comentário
COMMENT ON FUNCTION public.reject_organization_invite IS 
  'Permite que um usuário autenticado rejeite um convite de organização';

