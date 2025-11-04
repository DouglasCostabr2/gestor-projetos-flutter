-- ============================================================================
-- Migration: Permitir que usuários vejam perfis básicos de outros usuários
-- Data: 2025-10-28
-- Descrição: Adiciona política RLS para permitir que todos os usuários
--            autenticados vejam informações básicas (nome, email, avatar)
--            de outros usuários. Isso é necessário para exibir nomes e
--            avatares em históricos, comentários, etc.
-- ============================================================================

-- Criar política para permitir visualização de perfis básicos
CREATE POLICY IF NOT EXISTS "profiles_select_basic_info"
  ON public.profiles
  FOR SELECT
  TO authenticated
  USING (true);

-- ============================================================================
-- CONCLUÍDO
-- ============================================================================

DO $$
BEGIN
  RAISE NOTICE '✅ Migration concluída com sucesso!';
  RAISE NOTICE '📝 Política RLS criada: profiles_select_basic_info';
  RAISE NOTICE '✓  Usuários autenticados podem ver perfis básicos de outros usuários';
END $$;

