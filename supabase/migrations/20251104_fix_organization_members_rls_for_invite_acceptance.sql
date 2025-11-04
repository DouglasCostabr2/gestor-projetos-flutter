-- ============================================================================
-- FIX: Organization Members RLS Policy for Invite Acceptance
-- ============================================================================
-- Problema: A política RLS de INSERT exige is_organization_admin(organization_id)
-- Isso impede que usuários aceitem convites, pois eles ainda não são membros
-- da organização quando tentam se adicionar.
--
-- Solução: Adicionar política que permite usuários se adicionarem quando
-- estão aceitando um convite válido (pending) para seu email.

-- Criar política adicional para permitir aceitar convites
CREATE POLICY "Users can add themselves when accepting valid invites"
ON public.organization_members
FOR INSERT
TO authenticated
WITH CHECK (
  -- O usuário está se adicionando (user_id = auth.uid())
  user_id = auth.uid()
  AND
  -- Existe um convite pendente para o email do usuário nesta organização
  EXISTS (
    SELECT 1
    FROM public.organization_invites oi
    JOIN auth.users u ON u.email = oi.email
    WHERE oi.organization_id = organization_members.organization_id
      AND oi.status = 'pending'
      AND u.id = auth.uid()
      AND oi.expires_at > NOW()
  )
);

-- Verificar as políticas atualizadas
SELECT 
  policyname,
  cmd,
  with_check
FROM pg_policies 
WHERE tablename = 'organization_members'
  AND cmd = 'INSERT'
ORDER BY policyname;

