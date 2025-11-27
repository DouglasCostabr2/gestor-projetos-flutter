-- ============================================================================
-- INSTRUÇÕES: Execute este SQL no Supabase Dashboard
-- ============================================================================
-- 1. Acesse: https://supabase.com/dashboard
-- 2. Selecione seu projeto
-- 3. Vá em "SQL Editor" no menu lateral
-- 4. Clique em "New Query"
-- 5. Cole este SQL e clique em "Run"
-- ============================================================================

-- Atualizar versão 1.1.13 no banco de dados
INSERT INTO app_versions (version, download_url, release_notes, is_mandatory, min_supported_version)
VALUES (
  '1.1.13',
  'https://github.com/DouglasCostabr2/gestor-projetos-flutter/releases/download/v1.1.13/MyBusiness-Setup-1.1.13.exe',
  '### Correções
- Corrigidos imports no final_project_section.dart
- Atualização de componentes para usar caminhos relativos corretos

### Melhorias
- Melhor organização de imports
- Uso de barrel files para imports mais limpos',
  false,
  '1.0.0'
)
ON CONFLICT (version) 
DO UPDATE SET 
    download_url = EXCLUDED.download_url,
    release_notes = EXCLUDED.release_notes,
    is_mandatory = EXCLUDED.is_mandatory,
    min_supported_version = EXCLUDED.min_supported_version,
    updated_at = NOW();

-- ============================================================================
-- VERIFICAÇÃO: Execute esta query para confirmar que a versão foi inserida
-- ============================================================================
SELECT version, download_url, is_mandatory, created_at, updated_at
FROM app_versions
WHERE version = '1.1.13';

