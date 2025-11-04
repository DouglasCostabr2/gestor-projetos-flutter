# 🚀 Scripts de Automação - My Business

Scripts PowerShell para automatizar o processo de release e atualização do My Business.

## 📋 Índice

- [Pré-requisitos](#pré-requisitos)
- [Scripts Disponíveis](#scripts-disponíveis)
- [Guia de Uso](#guia-de-uso)
- [Exemplos](#exemplos)
- [Troubleshooting](#troubleshooting)

---

## 🔧 Pré-requisitos

Antes de usar os scripts, certifique-se de ter instalado:

- ✅ **Flutter SDK** - Para compilar o aplicativo
- ✅ **Git** - Para controle de versão
- ✅ **GitHub CLI (gh)** - Para criar releases no GitHub
- ✅ **Inno Setup 6** - Para criar o instalador Windows
- ✅ **PowerShell 5.1+** - Já vem com Windows 10/11

### Verificar Instalações

```powershell
# Verificar Flutter
flutter --version

# Verificar Git
git --version

# Verificar GitHub CLI
gh --version

# Verificar Inno Setup
Test-Path "C:\Program Files (x86)\Inno Setup 6\ISCC.exe"
```

---

## 📦 Scripts Disponíveis

### 1. `create-release.ps1`

Script principal que automatiza todo o processo de criação de uma nova versão.

**O que ele faz:**

1. ✅ Valida o formato da versão (semantic versioning)
2. ✅ Atualiza a versão no `pubspec.yaml`
3. ✅ Atualiza a versão no `installer/setup.iss`
4. ✅ Compila o aplicativo Flutter (`flutter build windows --release`)
5. ✅ Cria o instalador com Inno Setup
6. ✅ Faz commit das mudanças
7. ✅ Cria uma tag Git
8. ✅ Faz push para o GitHub
9. ✅ Cria o release no GitHub e faz upload do instalador

**Parâmetros:**

| Parâmetro | Obrigatório | Descrição | Padrão |
|-----------|-------------|-----------|--------|
| `-Version` | ✅ Sim | Versão no formato X.Y.Z (ex: 1.2.0) | - |
| `-ReleaseNotes` | ❌ Não | Notas de release em Markdown | Template padrão |
| `-IsMandatory` | ❌ Não | Se a atualização é obrigatória | `$false` |
| `-SkipBuild` | ❌ Não | Pular compilação do Flutter | `$false` |
| `-SkipGitPush` | ❌ Não | Pular push para GitHub | `$false` |

### 2. `update-supabase-version.ps1`

Script para atualizar a tabela `app_versions` no Supabase com a nova versão.

**O que ele faz:**

1. ✅ Valida o formato da versão
2. ✅ Busca release notes do GitHub (se não fornecidas)
3. ✅ Gera a query SQL para inserir/atualizar a versão
4. ✅ Salva a query em arquivo
5. ✅ Copia a query para a área de transferência
6. ✅ Fornece instruções para execução manual ou via API

**Parâmetros:**

| Parâmetro | Obrigatório | Descrição | Padrão |
|-----------|-------------|-----------|--------|
| `-Version` | ✅ Sim | Versão no formato X.Y.Z | - |
| `-DownloadUrl` | ✅ Sim | URL do instalador no GitHub | - |
| `-ReleaseNotes` | ❌ Não | Notas de release | Busca do GitHub |
| `-IsMandatory` | ❌ Não | Se a atualização é obrigatória | `$false` |
| `-MinSupportedVersion` | ❌ Não | Versão mínima suportada | `1.0.0` |

---

## 📖 Guia de Uso

### Processo Completo de Release

#### Passo 1: Preparar o Código

```powershell
# Certifique-se de que todas as mudanças estão commitadas
git status

# Se houver mudanças, commite-as
git add .
git commit -m "feat: adicionar nova funcionalidade"
```

#### Passo 2: Criar o Release

```powershell
# Navegue até a pasta do projeto
cd C:\Users\PC\Downloads\gestor_projetos_flutter

# Execute o script de release
.\scripts\create-release.ps1 -Version "1.2.0"
```

**Com release notes customizadas:**

```powershell
$notes = @"
# 🎉 My Business v1.2.0

## ✨ Novidades

- ✅ Nova funcionalidade X
- ✅ Integração com Y

## 🔧 Melhorias

- Otimização de performance
- Interface mais responsiva

## 🐛 Correções

- Corrigido bug no login
- Corrigido erro ao salvar projeto
"@

.\scripts\create-release.ps1 -Version "1.2.0" -ReleaseNotes $notes
```

**Atualização obrigatória:**

```powershell
.\scripts\create-release.ps1 -Version "1.2.0" -IsMandatory $true
```

#### Passo 3: Atualizar o Supabase

Após o script de release concluir, ele mostrará a URL do instalador. Use essa URL para atualizar o Supabase:

```powershell
.\scripts\update-supabase-version.ps1 `
    -Version "1.2.0" `
    -DownloadUrl "https://github.com/DouglasCostabr2/gestor-projetos-flutter/releases/download/v1.2.0/MyBusiness-Setup-1.2.0.exe"
```

**Com atualização obrigatória:**

```powershell
.\scripts\update-supabase-version.ps1 `
    -Version "1.2.0" `
    -DownloadUrl "https://github.com/DouglasCostabr2/gestor-projetos-flutter/releases/download/v1.2.0/MyBusiness-Setup-1.2.0.exe" `
    -IsMandatory $true `
    -MinSupportedVersion "1.1.0"
```

---

## 💡 Exemplos

### Exemplo 1: Release Simples

```powershell
# Release básico com template padrão
.\scripts\create-release.ps1 -Version "1.2.0"

# Atualizar Supabase
.\scripts\update-supabase-version.ps1 `
    -Version "1.2.0" `
    -DownloadUrl "https://github.com/DouglasCostabr2/gestor-projetos-flutter/releases/download/v1.2.0/MyBusiness-Setup-1.2.0.exe"
```

### Exemplo 2: Release com Notas Customizadas

```powershell
# Criar release com notas detalhadas
.\scripts\create-release.ps1 -Version "1.3.0" -ReleaseNotes @"
# 🎉 My Business v1.3.0 - Grande Atualização!

## ✨ Novidades Principais

- 🚀 **Nova Dashboard**: Interface completamente redesenhada
- 📊 **Relatórios Avançados**: Gráficos e análises detalhadas
- 🔔 **Notificações Push**: Receba alertas em tempo real

## 🔧 Melhorias

- Performance 50% mais rápida
- Uso de memória reduzido em 30%
- Interface mais intuitiva

## 🐛 Correções

- Corrigido crash ao exportar relatórios
- Corrigido problema de sincronização
- Melhorias de estabilidade geral

---

**Nota:** Esta é uma atualização importante com muitas melhorias!
"@

# Atualizar Supabase (obrigatória)
.\scripts\update-supabase-version.ps1 `
    -Version "1.3.0" `
    -DownloadUrl "https://github.com/DouglasCostabr2/gestor-projetos-flutter/releases/download/v1.3.0/MyBusiness-Setup-1.3.0.exe" `
    -IsMandatory $true `
    -MinSupportedVersion "1.2.0"
```

### Exemplo 3: Release Apenas Local (Sem Push)

```powershell
# Criar release mas não fazer push (para testar)
.\scripts\create-release.ps1 -Version "1.2.0" -SkipGitPush $true

# Depois de testar, fazer push manualmente
git push origin master
git push origin v1.2.0
```

### Exemplo 4: Release Rápido (Sem Rebuild)

```powershell
# Se você já compilou o app manualmente
.\scripts\create-release.ps1 -Version "1.2.0" -SkipBuild $true
```

---

## 🔍 Troubleshooting

### Problema: "gh: command not found"

**Solução:**

```powershell
# Atualizar PATH no PowerShell atual
$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")

# Verificar se gh está disponível
gh --version

# Se ainda não funcionar, reinicie o PowerShell
```

### Problema: "Inno Setup não encontrado"

**Solução:**

Verifique se o Inno Setup está instalado em:
```
C:\Program Files (x86)\Inno Setup 6\ISCC.exe
```

Se estiver em outro local, edite o script `create-release.ps1` e atualize a variável `$innoSetupPath`.

### Problema: "Erro ao criar release no GitHub"

**Solução:**

```powershell
# Verificar se está autenticado no GitHub CLI
gh auth status

# Se não estiver, fazer login
gh auth login
```

### Problema: "Versão já existe no GitHub"

**Solução:**

```powershell
# Deletar a tag local
git tag -d v1.2.0

# Deletar a tag remota
git push origin :refs/tags/v1.2.0

# Deletar o release no GitHub
gh release delete v1.2.0

# Tentar novamente
.\scripts\create-release.ps1 -Version "1.2.0"
```

### Problema: Query SQL não funciona no Supabase

**Solução:**

1. Acesse o Supabase: https://zfgsddweabsemxcchxjq.supabase.co
2. Vá em **SQL Editor**
3. Cole a query que foi copiada para a área de transferência
4. Execute a query
5. Verifique se a versão foi inserida em **Table Editor** > **app_versions**

---

## 📝 Notas Importantes

### Semantic Versioning

O projeto usa **Semantic Versioning** (semver):

- **MAJOR** (X.0.0): Mudanças incompatíveis na API
- **MINOR** (0.X.0): Novas funcionalidades compatíveis
- **PATCH** (0.0.X): Correções de bugs compatíveis

Exemplos:
- `1.0.0` → `1.1.0`: Nova funcionalidade
- `1.1.0` → `1.1.1`: Correção de bug
- `1.1.1` → `2.0.0`: Mudança incompatível

### Atualizações Obrigatórias

Use `-IsMandatory $true` quando:

- ✅ Houver correções críticas de segurança
- ✅ Houver mudanças no banco de dados que exigem migração
- ✅ A versão antiga tiver bugs graves
- ✅ Houver mudanças na API do backend

### Versão Mínima Suportada

Use `-MinSupportedVersion` para forçar usuários em versões muito antigas a atualizar:

```powershell
# Usuários abaixo de 1.2.0 serão forçados a atualizar
-MinSupportedVersion "1.2.0"
```

---

## 🎯 Checklist de Release

Antes de criar um release, verifique:

- [ ] Todas as mudanças estão commitadas
- [ ] Todos os testes passam
- [ ] A documentação está atualizada
- [ ] As release notes estão preparadas
- [ ] A versão segue semantic versioning
- [ ] Você está na branch correta (master)
- [ ] Você está autenticado no GitHub CLI

---

## 📞 Suporte

Se encontrar problemas com os scripts:

1. Verifique a seção [Troubleshooting](#troubleshooting)
2. Verifique os logs de erro no PowerShell
3. Verifique se todos os pré-requisitos estão instalados
4. Consulte a documentação do projeto

---

**Desenvolvido com ❤️ para My Business**

