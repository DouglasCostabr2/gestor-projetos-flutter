-- Migration: Restringir criação de organizações apenas para admins
-- Data: 2025-11-03
-- Descrição: Adiciona política RLS para permitir que apenas usuários com role 'admin' 
--            possam criar novas organizações na tabela organizations

-- Remover política antiga de INSERT se existir (permitia qualquer usuário autenticado)
DROP POLICY IF EXISTS "Users can create organizations" ON public.organizations;
DROP POLICY IF EXISTS "Authenticated users can create organizations" ON public.organizations;
DROP POLICY IF EXISTS "organizations_insert_authenticated" ON public.organizations;

-- Criar nova política para permitir apenas admins criarem organizações
CREATE POLICY "Only admins can create organizations"
ON public.organizations
FOR INSERT
TO authenticated
WITH CHECK (
  -- Permitir se o usuário atual é admin (role global)
  EXISTS (
    SELECT 1 FROM public.profiles
    WHERE id = auth.uid()
    AND role = 'admin'
  )
);

-- Comentário explicativo
COMMENT ON POLICY "Only admins can create organizations" ON public.organizations IS 
'Permite que apenas usuários com role admin (global) possam criar novas organizações. Esta é uma restrição temporária que será removida no futuro quando qualquer usuário puder criar sua própria organização.';

