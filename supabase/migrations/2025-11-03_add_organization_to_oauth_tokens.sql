-- ============================================================================
-- Migration: Adicionar organization_id aos tokens OAuth compartilhados
-- Data: 2025-11-03
-- Descrição: Transforma tokens OAuth de globais para por organização.
--            Cada organização terá sua própria conta do Google Drive.
-- ============================================================================

-- 1. Adicionar coluna organization_id à tabela shared_oauth_tokens
ALTER TABLE public.shared_oauth_tokens
ADD COLUMN IF NOT EXISTS organization_id uuid REFERENCES public.organizations(id) ON DELETE CASCADE;

-- 2. Remover constraint UNIQUE antiga (provider)
ALTER TABLE public.shared_oauth_tokens
DROP CONSTRAINT IF EXISTS shared_oauth_tokens_provider_key;

-- 3. Adicionar nova constraint UNIQUE (provider + organization_id)
-- Isso permite que cada organização tenha seu próprio token para cada provider
ALTER TABLE public.shared_oauth_tokens
ADD CONSTRAINT shared_oauth_tokens_provider_org_key 
UNIQUE (provider, organization_id);

-- 4. Atualizar comentários
COMMENT ON COLUMN public.shared_oauth_tokens.organization_id IS 'Organização dona do token OAuth';
COMMENT ON TABLE public.shared_oauth_tokens IS 'Tokens OAuth por organização (cada org tem sua própria conta)';

-- ============================================================================
-- Atualizar RLS (Row Level Security)
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

-- Política INSERT: Apenas admin/gestor podem inserir tokens
CREATE POLICY "shared_oauth_tokens_insert"
  ON public.shared_oauth_tokens
  FOR INSERT
  TO authenticated
  WITH CHECK (
    organization_id IN (
      SELECT organization_id
      FROM public.organization_members
      WHERE user_id = auth.uid() 
        AND status = 'active'
        AND role IN ('admin', 'gestor')
    )
  );

-- Política UPDATE: Apenas admin/gestor podem atualizar tokens
CREATE POLICY "shared_oauth_tokens_update"
  ON public.shared_oauth_tokens
  FOR UPDATE
  TO authenticated
  USING (
    organization_id IN (
      SELECT organization_id
      FROM public.organization_members
      WHERE user_id = auth.uid() 
        AND status = 'active'
        AND role IN ('admin', 'gestor')
    )
  )
  WITH CHECK (
    organization_id IN (
      SELECT organization_id
      FROM public.organization_members
      WHERE user_id = auth.uid() 
        AND status = 'active'
        AND role IN ('admin', 'gestor')
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
-- Índices para performance
-- ============================================================================

-- Índice para buscar tokens por organização
CREATE INDEX IF NOT EXISTS idx_shared_oauth_tokens_organization_id 
ON public.shared_oauth_tokens(organization_id);

-- Índice composto para busca rápida por provider + organization
CREATE INDEX IF NOT EXISTS idx_shared_oauth_tokens_provider_org 
ON public.shared_oauth_tokens(provider, organization_id);

