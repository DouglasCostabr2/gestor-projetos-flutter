# 🚀 Guia Rápido - Sistema de Atualização

Este é um guia rápido para usar o sistema de atualização automática do My Business.

## ⚡ Para Desenvolvedores

### Publicar Nova Versão (Processo Completo)

```bash
# 1. Atualizar versão no pubspec.yaml
# version: 1.2.0+3

# 2. Executar script de build (Windows)
.\scripts\build-installer.ps1

# 3. Testar instalador
installer\Output\MyBusiness-Setup-1.2.0.exe

# 4. Fazer upload para GitHub Releases
# - Criar tag: git tag v1.2.0
# - Criar release no GitHub
# - Upload do instalador

# 5. Registrar no Supabase (SQL Editor)
INSERT INTO app_versions (version, download_url, release_notes, is_mandatory)
VALUES (
  '1.2.0',
  'https://github.com/user/repo/releases/download/v1.2.0/MyBusiness-Setup-1.2.0.exe',
  '# Versão 1.2.0\n\n## Novidades\n- Feature X\n- Melhoria Y',
  false
);
```

### Comandos Úteis

```bash
# Build manual
flutter build windows --release

# Criar instalador (requer Inno Setup)
"C:\Program Files (x86)\Inno Setup 6\ISCC.exe" installer\setup.iss

# Executar app
build\windows\x64\runner\Debug\gestor_projetos_flutter.exe
```

## 👥 Para Usuários

### Como Funciona

1. **Automático**: Ao abrir o app, ele verifica atualizações
2. **Notificação**: Se houver atualização, um diálogo aparece
3. **Download**: Clique em "Atualizar agora" para baixar
4. **Instalação**: O instalador executa automaticamente
5. **Pronto**: Reabra o app atualizado

### Tipos de Atualização

- **Opcional**: Você pode escolher "Mais tarde"
- **Obrigatória**: Deve atualizar para continuar usando

## 🔧 Arquivos Importantes

```
gestor_projetos_flutter/
├── lib/
│   ├── models/
│   │   └── app_update.dart              # Modelo de atualização
│   ├── services/
│   │   └── update_service.dart          # Serviço de atualização
│   ├── widgets/
│   │   └── update_dialog.dart           # Diálogo de atualização
│   └── main.dart                        # Integração (linha 96-126)
├── installer/
│   ├── setup.iss                        # Script Inno Setup
│   └── README.md                        # Guia do instalador
├── scripts/
│   └── build-installer.ps1              # Script de automação
├── supabase/
│   └── migrations/
│       └── create_app_versions_table.sql # Tabela do Supabase
└── docs/
    └── SISTEMA_ATUALIZACAO.md           # Documentação completa
```

## 📊 Estrutura da Tabela Supabase

```sql
-- Tabela: app_versions
CREATE TABLE app_versions (
  id UUID PRIMARY KEY,
  version TEXT NOT NULL UNIQUE,           -- Ex: "1.2.0"
  download_url TEXT NOT NULL,             -- URL do instalador
  release_notes TEXT,                     -- Markdown
  is_mandatory BOOLEAN DEFAULT false,     -- Forçar atualização?
  min_supported_version TEXT,             -- Versão mínima
  created_at TIMESTAMP DEFAULT NOW()
);
```

## 🎯 Exemplos de Uso

### Atualização Opcional

```sql
INSERT INTO app_versions (version, download_url, release_notes, is_mandatory)
VALUES (
  '1.3.0',
  'https://github.com/user/repo/releases/download/v1.3.0/MyBusiness-Setup-1.3.0.exe',
  '# Novidades\n- Nova funcionalidade\n- Melhorias de UI',
  false  -- Opcional
);
```

### Atualização Obrigatória

```sql
INSERT INTO app_versions (version, download_url, release_notes, is_mandatory)
VALUES (
  '2.0.0',
  'https://github.com/user/repo/releases/download/v2.0.0/MyBusiness-Setup-2.0.0.exe',
  '# Atualização Crítica\n- Correção de segurança\n- Mudanças importantes',
  true  -- Obrigatória
);
```

### Com Versão Mínima

```sql
INSERT INTO app_versions (
  version, download_url, release_notes, is_mandatory, min_supported_version
) VALUES (
  '2.1.0',
  'https://github.com/user/repo/releases/download/v2.1.0/MyBusiness-Setup-2.1.0.exe',
  '# Versão 2.1.0\n- Novas funcionalidades',
  false,
  '2.0.0'  -- Versões < 2.0.0 devem atualizar obrigatoriamente
);
```

## 🧪 Testar Sistema

### 1. Criar Versão de Teste

```sql
-- Versão muito alta para sempre aparecer
INSERT INTO app_versions (version, download_url, release_notes, is_mandatory)
VALUES (
  '99.99.99',
  'https://exemplo.com/teste.exe',
  '# Versão de Teste\n\nEsta é uma versão de teste.',
  false
);
```

### 2. Executar App

```bash
flutter run -d windows
```

### 3. Verificar

- Diálogo deve aparecer após 2 segundos
- Informações devem estar corretas
- Botões devem funcionar

### 4. Limpar Teste

```sql
DELETE FROM app_versions WHERE version = '99.99.99';
```

## 🐛 Problemas Comuns

### Diálogo não aparece

```bash
# Verificar logs no console
# Procurar por:
# 🔍 Verificando atualizações...
# 📱 Versão atual: X.X.X
# 🌐 Versão mais recente no servidor: X.X.X
```

**Soluções:**
- Verificar se tabela `app_versions` tem dados
- Verificar se versão no Supabase é maior que a atual
- Verificar conexão com Supabase

### Erro ao baixar

**Soluções:**
- Testar URL no navegador
- Verificar conexão com internet
- Verificar logs de erro

### Instalador não executa

**Soluções:**
- Verificar se arquivo foi baixado
- Adicionar exceção no antivírus
- Executar como administrador

## 📚 Documentação Completa

Para mais detalhes, consulte:

- **Sistema de Atualização**: `docs/SISTEMA_ATUALIZACAO.md`
- **Criação de Instalador**: `installer/README.md`
- **Script de Build**: `scripts/build-installer.ps1 -Help`

## 🔗 Links Úteis

- [Inno Setup](https://jrsoftware.org/isdl.php) - Criar instaladores
- [GitHub Releases](https://docs.github.com/en/repositories/releasing-projects-on-github) - Hospedar instaladores
- [Semantic Versioning](https://semver.org/) - Versionamento
- [Package Info Plus](https://pub.dev/packages/package_info_plus) - Obter versão do app
- [Dio](https://pub.dev/packages/dio) - Download de arquivos

## ✅ Checklist de Release

- [ ] Versão atualizada em `pubspec.yaml`
- [ ] Versão atualizada em `installer/setup.iss`
- [ ] App compilado: `flutter build windows --release`
- [ ] Instalador criado: `.\scripts\build-installer.ps1`
- [ ] Instalador testado em máquina limpa
- [ ] Upload para GitHub Releases ou servidor
- [ ] URL do instalador copiada
- [ ] Versão registrada no Supabase
- [ ] Release notes escritas
- [ ] Usuários notificados (se necessário)

## 💡 Dicas

1. **Sempre teste** o instalador antes de publicar
2. **Use versionamento semântico** (major.minor.patch)
3. **Escreva boas release notes** - usuários leem!
4. **Atualizações obrigatórias** - use com moderação
5. **Mantenha backup** dos instaladores antigos
6. **Assine digitalmente** para evitar avisos do Windows

---

**Dúvidas?** Consulte a documentação completa em `docs/SISTEMA_ATUALIZACAO.md`

