-- ============================================================================
-- FIX: Notifications RLS Policy for Organization Invites
-- ============================================================================
-- Problema: A política RLS atual exige is_organization_member(organization_id)
-- Isso impede que usuários vejam notificações de convites para organizações
-- das quais eles ainda NÃO são membros.
--
-- Solução: Permitir que usuários vejam suas próprias notificações mesmo que
-- não sejam membros da organização, desde que a notificação seja do tipo
-- organization_invite_received

-- Remover política antiga
DROP POLICY IF EXISTS "Users can view their notifications in their organizations" ON public.notifications;

-- Criar nova política que permite:
-- 1. Ver notificações de organizações das quais o usuário É membro
-- 2. Ver notificações de CONVITE mesmo que o usuário NÃO seja membro ainda
CREATE POLICY "Users can view their notifications"
ON public.notifications
FOR SELECT
TO authenticated
USING (
  user_id = auth.uid() 
  AND (
    -- Notificações de organizações das quais o usuário é membro
    is_organization_member(organization_id)
    OR
    -- OU notificações de convite (mesmo que não seja membro ainda)
    type = 'organization_invite_received'
  )
);

-- Atualizar política de UPDATE para permitir marcar convites como lidos
DROP POLICY IF EXISTS "Users can update their notifications" ON public.notifications;

CREATE POLICY "Users can update their notifications"
ON public.notifications
FOR UPDATE
TO authenticated
USING (
  user_id = auth.uid()
  AND (
    is_organization_member(organization_id)
    OR
    type = 'organization_invite_received'
  )
)
WITH CHECK (
  user_id = auth.uid()
  AND (
    is_organization_member(organization_id)
    OR
    type = 'organization_invite_received'
  )
);

-- Atualizar política de DELETE para permitir deletar convites
DROP POLICY IF EXISTS "Users can delete their notifications" ON public.notifications;

CREATE POLICY "Users can delete their notifications"
ON public.notifications
FOR DELETE
TO authenticated
USING (
  user_id = auth.uid()
  AND (
    is_organization_member(organization_id)
    OR
    type = 'organization_invite_received'
  )
);

-- Verificar as novas políticas
SELECT 
  policyname,
  cmd,
  qual
FROM pg_policies 
WHERE tablename = 'notifications'
ORDER BY cmd, policyname;

