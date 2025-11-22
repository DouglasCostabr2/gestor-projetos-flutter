-- ============================================================================
-- Migration: Fix shared_oauth_tokens DELETE policy to include 'owner' role
-- Date: 2025-11-12
-- Description: The DELETE policy was only allowing 'admin' and 'gestor' roles,
--              but 'owner' should also be able to disconnect Google Drive.
--              This migration updates the policy to include 'owner' role.
-- ============================================================================

-- Remover política DELETE antiga
DROP POLICY IF EXISTS "shared_oauth_tokens_delete" ON public.shared_oauth_tokens;

-- Política DELETE: owner, admin e gestor podem deletar tokens
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
        AND role IN ('owner', 'admin', 'gestor')
    )
  );

-- ============================================================================
-- Comentário
-- ============================================================================

COMMENT ON POLICY "shared_oauth_tokens_delete" ON public.shared_oauth_tokens IS 
  'Owner, admin e gestor podem deletar tokens OAuth da organização';

-- ============================================================================
-- Verificação
-- ============================================================================

-- Verificar a política atualizada
DO $$
BEGIN
  RAISE NOTICE '✅ Política DELETE atualizada com sucesso!';
  RAISE NOTICE '📝 Roles permitidos: owner, admin, gestor';
END $$;

