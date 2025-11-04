-- Tabela para armazenar versões do aplicativo
-- Esta tabela é usada pelo sistema de atualização automática

CREATE TABLE IF NOT EXISTS app_versions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  version TEXT NOT NULL UNIQUE,
  download_url TEXT NOT NULL,
  release_notes TEXT,
  is_mandatory BOOLEAN DEFAULT false,
  min_supported_version TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Índice para buscar a versão mais recente rapidamente
CREATE INDEX IF NOT EXISTS idx_app_versions_created_at ON app_versions(created_at DESC);

-- Comentários para documentação
COMMENT ON TABLE app_versions IS 'Armazena informações sobre versões do aplicativo para sistema de atualização automática';
COMMENT ON COLUMN app_versions.version IS 'Versão do app no formato semântico (ex: 1.2.3)';
COMMENT ON COLUMN app_versions.download_url IS 'URL para download do instalador (.exe)';
COMMENT ON COLUMN app_versions.release_notes IS 'Notas de lançamento em markdown';
COMMENT ON COLUMN app_versions.is_mandatory IS 'Se true, força o usuário a atualizar';
COMMENT ON COLUMN app_versions.min_supported_version IS 'Versão mínima suportada (versões abaixo devem atualizar obrigatoriamente)';

-- Habilitar RLS (Row Level Security)
ALTER TABLE app_versions ENABLE ROW LEVEL SECURITY;

-- Política: Todos podem ler as versões
CREATE POLICY "Todos podem ler versões do app"
  ON app_versions
  FOR SELECT
  USING (true);

-- Política: Apenas admins podem inserir/atualizar versões
-- Nota: Você precisará ajustar esta política de acordo com seu sistema de roles
CREATE POLICY "Apenas admins podem gerenciar versões"
  ON app_versions
  FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
      AND profiles.role = 'admin'
    )
  );

-- Inserir versão inicial (exemplo)
INSERT INTO app_versions (version, download_url, release_notes, is_mandatory)
VALUES (
  '1.1.0',
  'https://github.com/seu-usuario/seu-repo/releases/download/v1.1.0/MyBusiness-Setup-1.1.0.exe',
  '# Versão 1.1.0

## Novidades
- Sistema de atualização automática implementado
- Melhorias de performance
- Correções de bugs

## Correções
- Corrigido problema com timer de tarefas
- Melhorias na interface do usuário',
  false
) ON CONFLICT (version) DO NOTHING;

