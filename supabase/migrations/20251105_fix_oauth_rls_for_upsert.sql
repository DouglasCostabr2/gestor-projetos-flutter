-- ============================================================================
-- Migration: Fix RLS policies for shared_oauth_tokens to allow UPSERT
-- Date: 2025-11-05
-- Description: The UPSERT operation needs both INSERT and UPDATE permissions.
--              This migration ensures that the RLS policies allow token refresh
--              via UPSERT for all authenticated users (not just admin/gestor).
-- ============================================================================

-- Remover políticas antigas
DROP POLICY IF EXISTS "shared_oauth_tokens_select" ON public.shared_oauth_tokens;
DROP POLICY IF EXISTS "shared_oauth_tokens_insert" ON public.shared_oauth_tokens;
DROP POLICY IF EXISTS "shared_oauth_tokens_update" ON public.shared_oauth_tokens;
DROP POLICY IF EXISTS "shared_oauth_tokens_delete" ON public.shared_oauth_tokens;

-- Política SELECT: Membros da organização podem ler tokens da sua org
CREATE POLICY "shared_oauth_tokens_select"
  ON public.shared_oauth_tokens
  FOR SELECT
  TO authenticated
  USING (
    organization_id IN (
      SELECT organization_id
      FROM public.organization_members
      WHERE user_id = auth.uid() AND status = 'active'
    )
  );

-- Política INSERT: Todos os usuários autenticados podem inserir tokens
-- (necessário para UPSERT funcionar durante token refresh)
CREATE POLICY "shared_oauth_tokens_insert"
  ON public.shared_oauth_tokens
  FOR INSERT
  TO authenticated
  WITH CHECK (
    -- Permitir inserção se o usuário é membro da organização
    organization_id IN (
      SELECT organization_id
      FROM public.organization_members
      WHERE user_id = auth.uid() AND status = 'active'
    )
  );

-- Política UPDATE: Todos os usuários autenticados podem atualizar tokens
-- (necessário para UPSERT funcionar durante token refresh)
CREATE POLICY "shared_oauth_tokens_update"
  ON public.shared_oauth_tokens
  FOR UPDATE
  TO authenticated
  USING (
    -- Permitir atualização se o usuário é membro da organização
    organization_id IN (
      SELECT organization_id
      FROM public.organization_members
      WHERE user_id = auth.uid() AND status = 'active'
    )
  )
  WITH CHECK (
    -- Permitir atualização se o usuário é membro da organização
    organization_id IN (
      SELECT organization_id
      FROM public.organization_members
      WHERE user_id = auth.uid() AND status = 'active'
    )
  );

-- Política DELETE: Apenas admin/gestor podem deletar tokens
CREATE POLICY "shared_oauth_tokens_delete"
  ON public.shared_oauth_tokens
  FOR DELETE
  TO authenticated
  USING (
    organization_id IN (
      SELECT organization_id
      FROM public.organization_members
      WHERE user_id = auth.uid() 
        AND status = 'active'
        AND role IN ('admin', 'gestor')
    )
  );

-- ============================================================================
-- Comentários
-- ============================================================================

COMMENT ON POLICY "shared_oauth_tokens_select" ON public.shared_oauth_tokens IS 
  'Membros da organização podem ler tokens OAuth da sua organização';

COMMENT ON POLICY "shared_oauth_tokens_insert" ON public.shared_oauth_tokens IS 
  'Membros da organização podem inserir tokens (necessário para UPSERT durante refresh)';

COMMENT ON POLICY "shared_oauth_tokens_update" ON public.shared_oauth_tokens IS 
  'Membros da organização podem atualizar tokens (necessário para UPSERT durante refresh)';

COMMENT ON POLICY "shared_oauth_tokens_delete" ON public.shared_oauth_tokens IS 
  'Apenas admin/gestor podem deletar tokens OAuth';

