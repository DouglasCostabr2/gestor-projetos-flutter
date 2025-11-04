# 🚀 Guia Rápido de Release - My Business

Este guia mostra como criar uma nova versão do My Business de forma rápida e automatizada.

---

## ⚡ Release em 3 Passos

### 1️⃣ Preparar o Código

```powershell
# Certifique-se de que está na pasta do projeto
cd C:\Users\PC\Downloads\gestor_projetos_flutter

# Verifique se há mudanças não commitadas
git status

# Se houver, commite-as
git add .
git commit -m "feat: sua mensagem aqui"
```

### 2️⃣ Criar o Release

```powershell
# Execute o script de release rápido
.\scripts\quick-release.ps1 -Version "1.2.0"
```

**O script vai:**
- ✅ Atualizar versões nos arquivos
- ✅ Compilar o aplicativo
- ✅ Criar o instalador
- ✅ Fazer commit e push
- ✅ Criar release no GitHub
- ✅ Fazer upload do instalador
- ✅ Perguntar se quer atualizar o Supabase

### 3️⃣ Pronto! 🎉

Seus usuários já receberão a notificação de atualização na próxima vez que abrirem o app!

---

## 📋 Exemplos Práticos

### Exemplo 1: Release Simples

```powershell
# Versão 1.2.0 com template padrão
.\scripts\quick-release.ps1 -Version "1.2.0"

# Quando perguntar sobre Supabase, responda: s
# Quando perguntar se é obrigatória, responda: n
```

### Exemplo 2: Release com Notas Customizadas

```powershell
# Preparar notas de release
$notes = @"
# 🎉 My Business v1.3.0

## ✨ Novidades

- ✅ Nova funcionalidade X
- ✅ Melhorias na interface

## 🐛 Correções

- Corrigido bug Y
"@

# Criar release
.\scripts\create-release.ps1 -Version "1.3.0" -ReleaseNotes $notes

# Atualizar Supabase
.\scripts\update-supabase-version.ps1 `
    -Version "1.3.0" `
    -DownloadUrl "https://github.com/DouglasCostabr2/gestor-projetos-flutter/releases/download/v1.3.0/MyBusiness-Setup-1.3.0.exe"
```

### Exemplo 3: Atualização Obrigatória (Crítica)

```powershell
# Criar release
.\scripts\create-release.ps1 -Version "1.2.1" -IsMandatory $true

# Atualizar Supabase (obrigatória)
.\scripts\update-supabase-version.ps1 `
    -Version "1.2.1" `
    -DownloadUrl "https://github.com/DouglasCostabr2/gestor-projetos-flutter/releases/download/v1.2.1/MyBusiness-Setup-1.2.1.exe" `
    -IsMandatory $true `
    -MinSupportedVersion "1.2.0"
```

---

## 🎯 Quando Usar Cada Tipo de Versão

### PATCH (1.0.X) - Correções de Bugs

```powershell
# Exemplo: 1.0.0 → 1.0.1
.\scripts\quick-release.ps1 -Version "1.0.1"
```

**Use quando:**
- Corrigir bugs
- Pequenas melhorias
- Correções de texto/UI

### MINOR (1.X.0) - Novas Funcionalidades

```powershell
# Exemplo: 1.0.1 → 1.1.0
.\scripts\quick-release.ps1 -Version "1.1.0"
```

**Use quando:**
- Adicionar novas funcionalidades
- Melhorias significativas
- Novas integrações

### MAJOR (X.0.0) - Mudanças Grandes

```powershell
# Exemplo: 1.5.0 → 2.0.0
.\scripts\quick-release.ps1 -Version "2.0.0"
```

**Use quando:**
- Mudanças incompatíveis
- Redesign completo
- Mudanças na arquitetura

---

## 🔧 Troubleshooting Rápido

### Problema: "gh: command not found"

```powershell
# Atualizar PATH
$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")

# Ou reinicie o PowerShell
```

### Problema: "Erro ao compilar Flutter"

```powershell
# Limpar cache e tentar novamente
flutter clean
flutter pub get
.\scripts\quick-release.ps1 -Version "1.2.0"
```

### Problema: "Versão já existe"

```powershell
# Deletar tag e release
git tag -d v1.2.0
git push origin :refs/tags/v1.2.0
gh release delete v1.2.0

# Tentar novamente
.\scripts\quick-release.ps1 -Version "1.2.0"
```

---

## 📊 Checklist Antes de Fazer Release

- [ ] Código testado e funcionando
- [ ] Todas as mudanças commitadas
- [ ] Versão segue semantic versioning
- [ ] Release notes preparadas (se customizadas)
- [ ] Autenticado no GitHub CLI (`gh auth status`)
- [ ] Na branch master

---

## 💡 Dicas

### Testar Antes de Lançar

```powershell
# Criar release sem fazer push
.\scripts\create-release.ps1 -Version "1.2.0" -SkipGitPush $true

# Testar o instalador localmente
.\installer\Output\MyBusiness-Setup-1.2.0.exe

# Se estiver OK, fazer push manualmente
git push origin master
git push origin v1.2.0
gh release upload v1.2.0 "installer\Output\MyBusiness-Setup-1.2.0.exe"
```

### Ver Versões Anteriores

```powershell
# Ver todas as tags
git tag

# Ver detalhes de uma versão
gh release view v1.1.0

# Ver histórico de commits
git log --oneline
```

### Reverter um Release

```powershell
# Deletar release do GitHub
gh release delete v1.2.0

# Deletar tag
git tag -d v1.2.0
git push origin :refs/tags/v1.2.0

# Reverter commit
git revert HEAD
git push
```

---

## 📚 Documentação Completa

Para mais detalhes, consulte:

- **Scripts de Automação**: [scripts/README.md](../scripts/README.md)
- **Sistema de Atualização**: [SISTEMA_ATUALIZACAO.md](SISTEMA_ATUALIZACAO.md)
- **Configuração Google OAuth**: [CONFIGURACAO_GOOGLE_OAUTH.md](../CONFIGURACAO_GOOGLE_OAUTH.md)

---

## 🎊 Resumo

**Para um release rápido:**

```powershell
# 1. Commitar mudanças
git add .
git commit -m "feat: nova funcionalidade"

# 2. Criar release
.\scripts\quick-release.ps1 -Version "1.2.0"

# 3. Responder as perguntas
# - Atualizar Supabase? s
# - É obrigatória? n

# 4. Pronto! 🚀
```

**Tempo total: ~5 minutos** ⚡

---

**Desenvolvido com ❤️ para My Business**

