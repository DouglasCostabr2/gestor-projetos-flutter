-- Query para atualizar versão no Supabase
-- Execute no SQL Editor do Supabase: https://zfgsddweabsemxcchxjq.supabase.co

INSERT INTO app_versions (version, download_url, release_notes, is_mandatory, min_supported_version)
VALUES (
    '1.1.14', 
    'https://github.com/DouglasCostabr2/gestor-projetos-flutter/releases/download/v1.1.14/MyBusiness-Setup-1.1.14.exe', 
    '# My Business v1.1.14

## ✨ Novidades
- Melhorias gerais de performance
- Correções de bugs

## 🔧 Melhorias
- Interface mais responsiva
- Otimizações no carregamento

---
Desenvolvido com ❤️ usando Flutter', 
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
