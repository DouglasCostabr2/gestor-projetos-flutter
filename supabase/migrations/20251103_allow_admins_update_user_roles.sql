-- Migration: Permitir que admins atualizem roles de usuários
-- Data: 2025-11-03
-- Descrição: Adiciona política RLS para permitir que usuários com role 'admin' 
--            possam atualizar o campo 'role' de outros usuários na tabela profiles

-- Criar política para permitir admins atualizarem roles
CREATE POLICY "Admins can update user roles"
ON public.profiles
FOR UPDATE
TO authenticated
USING (
  -- Permitir se o usuário atual é admin
  EXISTS (
    SELECT 1 FROM public.profiles
    WHERE id = auth.uid()
    AND role = 'admin'
  )
)
WITH CHECK (
  -- Permitir se o usuário atual é admin
  EXISTS (
    SELECT 1 FROM public.profiles
    WHERE id = auth.uid()
    AND role = 'admin'
  )
);

-- Comentário explicativo
COMMENT ON POLICY "Admins can update user roles" ON public.profiles IS 
'Permite que usuários com role admin atualizem informações de outros usuários, incluindo seus roles';

