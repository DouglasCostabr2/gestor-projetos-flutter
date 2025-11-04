-- ============================================================================
-- Migration: Criar tabela para tokens OAuth compartilhados
-- Data: 2025-10-28
-- Descrição: Permite que uma conta do Google Drive seja compartilhada entre
--            todos os usuários do sistema. Quando um admin/gestor vincula
--            uma conta, todos os outros usuários podem usar essa conta para
--            fazer uploads sem precisar fazer login novamente.
-- ============================================================================

-- Criar tabela para tokens OAuth compartilhados (não vinculados a usuário)
CREATE TABLE IF NOT EXISTS public.shared_oauth_tokens (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  provider text NOT NULL UNIQUE, -- 'google', 'dropbox', etc.
  refresh_token text,
  access_token text,
  access_token_expiry timestamptz,
  connected_by uuid REFERENCES auth.users(id) ON DELETE SET NULL, -- Quem conectou
  connected_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Comentários
COMMENT ON TABLE public.shared_oauth_tokens IS 'Tokens OAuth compartilhados entre todos os usuários';
COMMENT ON COLUMN public.shared_oauth_tokens.provider IS 'Provedor OAuth (google, dropbox, etc.)';
COMMENT ON COLUMN public.shared_oauth_tokens.refresh_token IS 'Token de refresh para renovar access_token';
COMMENT ON COLUMN public.shared_oauth_tokens.access_token IS 'Token de acesso atual';
COMMENT ON COLUMN public.shared_oauth_tokens.access_token_expiry IS 'Data/hora de expiração do access_token';
COMMENT ON COLUMN public.shared_oauth_tokens.connected_by IS 'Usuário que conectou a conta';
COMMENT ON COLUMN public.shared_oauth_tokens.connected_at IS 'Data/hora da conexão';
COMMENT ON COLUMN public.shared_oauth_tokens.updated_at IS 'Data/hora da última atualização';

-- ============================================================================
-- RLS (Row Level Security)
-- ============================================================================

-- Habilitar RLS
ALTER TABLE public.shared_oauth_tokens ENABLE ROW LEVEL SECURITY;

-- Política: Todos os usuários autenticados podem ler tokens compartilhados
CREATE POLICY "shared_oauth_tokens_select"
  ON public.shared_oauth_tokens
  FOR SELECT
  TO authenticated
  USING (true);

-- Política: Apenas admin e gestor podem inserir/atualizar tokens compartilhados
CREATE POLICY "shared_oauth_tokens_insert"
  ON public.shared_oauth_tokens
  FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
        AND profiles.role IN ('admin', 'gestor')
    )
  );

CREATE POLICY "shared_oauth_tokens_update"
  ON public.shared_oauth_tokens
  FOR UPDATE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
        AND profiles.role IN ('admin', 'gestor')
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
        AND profiles.role IN ('admin', 'gestor')
    )
  );

-- Política: Apenas admin pode deletar tokens compartilhados
CREATE POLICY "shared_oauth_tokens_delete"
  ON public.shared_oauth_tokens
  FOR DELETE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
        AND profiles.role = 'admin'
    )
  );

-- ============================================================================
-- CONCLUÍDO
-- ============================================================================

DO $$
BEGIN
  RAISE NOTICE '✅ Migration concluída com sucesso!';
  RAISE NOTICE '📝 Tabela shared_oauth_tokens criada';
  RAISE NOTICE '🔒 Políticas RLS configuradas:';
  RAISE NOTICE '   - Todos podem ler tokens compartilhados';
  RAISE NOTICE '   - Admin/Gestor podem inserir/atualizar';
  RAISE NOTICE '   - Apenas Admin pode deletar';
END $$;

