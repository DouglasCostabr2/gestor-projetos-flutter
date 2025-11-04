# Script de Automação de Release - My Business
# Este script automatiza todo o processo de criação de uma nova versão

param(
    [Parameter(Mandatory=$true)]
    [string]$Version,
    
    [Parameter(Mandatory=$false)]
    [string]$ReleaseNotes = "",
    
    [Parameter(Mandatory=$false)]
    [bool]$IsMandatory = $false,
    
    [Parameter(Mandatory=$false)]
    [bool]$SkipBuild = $false,
    
    [Parameter(Mandatory=$false)]
    [bool]$SkipGitPush = $false
)

# Cores para output
function Write-Success { Write-Host $args -ForegroundColor Green }
function Write-Info { Write-Host $args -ForegroundColor Cyan }
function Write-Warning { Write-Host $args -ForegroundColor Yellow }
function Write-Error { Write-Host $args -ForegroundColor Red }

# Banner
Write-Host ""
Write-Host "╔════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║         My Business - Automação de Release v1.0           ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

# Validar formato da versão (semantic versioning)
if ($Version -notmatch '^\d+\.\d+\.\d+$') {
    Write-Error "❌ Erro: Versão deve estar no formato X.Y.Z (ex: 1.2.0)"
    exit 1
}

Write-Info "🚀 Iniciando processo de release para versão $Version"
Write-Host ""

# Passo 1: Verificar se há mudanças não commitadas
Write-Info "📋 Passo 1/9: Verificando mudanças não commitadas..."
$gitStatus = git status --porcelain
if ($gitStatus -and !$SkipBuild) {
    Write-Warning "⚠️  Há mudanças não commitadas:"
    git status --short
    $continue = Read-Host "`nDeseja continuar mesmo assim? (s/N)"
    if ($continue -ne 's' -and $continue -ne 'S') {
        Write-Error "❌ Release cancelado pelo usuário"
        exit 1
    }
}
Write-Success "✅ Verificação concluída"
Write-Host ""

# Passo 2: Atualizar versão no pubspec.yaml
Write-Info "📋 Passo 2/9: Atualizando versão no pubspec.yaml..."
$pubspecPath = "pubspec.yaml"
$pubspecContent = Get-Content $pubspecPath -Raw

# Extrair versão atual
if ($pubspecContent -match 'version:\s*(\d+\.\d+\.\d+)\+(\d+)') {
    $currentVersion = $matches[1]
    $currentBuildNumber = [int]$matches[2]
    $newBuildNumber = $currentBuildNumber + 1
    
    Write-Info "   Versão atual: $currentVersion+$currentBuildNumber"
    Write-Info "   Nova versão: $Version+$newBuildNumber"
    
    # Atualizar pubspec.yaml
    $pubspecContent = $pubspecContent -replace "version:\s*\d+\.\d+\.\d+\+\d+", "version: $Version+$newBuildNumber"
    Set-Content $pubspecPath -Value $pubspecContent -NoNewline
    
    Write-Success "✅ pubspec.yaml atualizado"
} else {
    Write-Error "❌ Erro: Não foi possível encontrar a versão no pubspec.yaml"
    exit 1
}
Write-Host ""

# Passo 3: Atualizar versão no setup.iss
Write-Info "📋 Passo 3/9: Atualizando versão no setup.iss..."
$setupPath = "installer\setup.iss"
$setupContent = Get-Content $setupPath -Raw
$setupContent = $setupContent -replace '#define MyAppVersion ".*"', "#define MyAppVersion `"$Version`""
Set-Content $setupPath -Value $setupContent -NoNewline
Write-Success "✅ setup.iss atualizado"
Write-Host ""

# Passo 4: Build do Flutter (se não for pulado)
if (!$SkipBuild) {
    Write-Info "📋 Passo 4/9: Compilando aplicação Flutter..."
    Write-Info "   Isso pode levar alguns minutos..."
    
    $buildOutput = flutter build windows --release 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Error "❌ Erro ao compilar o aplicativo Flutter"
        Write-Error $buildOutput
        exit 1
    }
    Write-Success "✅ Aplicação compilada com sucesso"
} else {
    Write-Warning "⚠️  Passo 4/9: Build do Flutter pulado (--SkipBuild)"
}
Write-Host ""

# Passo 5: Criar instalador com Inno Setup
Write-Info "📋 Passo 5/9: Criando instalador com Inno Setup..."
$innoSetupPath = "C:\Program Files (x86)\Inno Setup 6\ISCC.exe"

if (!(Test-Path $innoSetupPath)) {
    Write-Error "❌ Erro: Inno Setup não encontrado em: $innoSetupPath"
    exit 1
}

$compileOutput = & $innoSetupPath "installer\setup.iss" 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Error "❌ Erro ao criar instalador"
    Write-Error $compileOutput
    exit 1
}

$installerPath = "installer\Output\MyBusiness-Setup-$Version.exe"
if (!(Test-Path $installerPath)) {
    Write-Error "❌ Erro: Instalador não foi criado em: $installerPath"
    exit 1
}

$installerSize = (Get-Item $installerPath).Length / 1MB
Write-Success "✅ Instalador criado: $installerPath ($([math]::Round($installerSize, 2)) MB)"
Write-Host ""

# Passo 6: Commit das mudanças
Write-Info "📋 Passo 6/9: Commitando mudanças..."
git add pubspec.yaml installer/setup.iss
git commit -m "chore: bump version to $Version"
Write-Success "✅ Mudanças commitadas"
Write-Host ""

# Passo 7: Criar tag
Write-Info "📋 Passo 7/9: Criando tag v$Version..."
git tag -a "v$Version" -m "Release version $Version"
Write-Success "✅ Tag criada"
Write-Host ""

# Passo 8: Push para GitHub (se não for pulado)
if (!$SkipGitPush) {
    Write-Info "📋 Passo 8/9: Enviando para GitHub..."
    git push origin master
    git push origin "v$Version"
    Write-Success "✅ Código e tag enviados para GitHub"
} else {
    Write-Warning "⚠️  Passo 8/9: Push para GitHub pulado (--SkipGitPush)"
    Write-Warning "   Execute manualmente: git push origin master && git push origin v$Version"
}
Write-Host ""

# Passo 9: Criar release no GitHub e fazer upload do instalador
Write-Info "📋 Passo 9/9: Criando release no GitHub..."

# Preparar release notes
if ($ReleaseNotes -eq "") {
    $defaultNotes = @"
# 🎉 My Business v$Version

## ✨ Novidades

- Adicione aqui as novidades desta versão

## 🔧 Melhorias

- Adicione aqui as melhorias

## 🐛 Correções

- Adicione aqui as correções de bugs

---

Desenvolvido com ❤️ usando Flutter
"@
    $ReleaseNotes = $defaultNotes
}

# Salvar release notes em arquivo temporário
$tempNotesFile = [System.IO.Path]::GetTempFileName()
Set-Content $tempNotesFile -Value $ReleaseNotes

# Criar release no GitHub
Write-Info "   Criando release v$Version no GitHub..."
$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")

gh release create "v$Version" `
    --title "My Business v$Version" `
    --notes-file $tempNotesFile `
    $installerPath

if ($LASTEXITCODE -ne 0) {
    Write-Error "❌ Erro ao criar release no GitHub"
    Remove-Item $tempNotesFile
    exit 1
}

Remove-Item $tempNotesFile
Write-Success "✅ Release criado e instalador enviado para GitHub"
Write-Host ""

# URL do instalador
$downloadUrl = "https://github.com/DouglasCostabr2/gestor-projetos-flutter/releases/download/v$Version/MyBusiness-Setup-$Version.exe"

# Resumo final
Write-Host ""
Write-Host "╔════════════════════════════════════════════════════════════╗" -ForegroundColor Green
Write-Host "║                  ✅ RELEASE CONCLUÍDO!                     ║" -ForegroundColor Green
Write-Host "╚════════════════════════════════════════════════════════════╝" -ForegroundColor Green
Write-Host ""
Write-Success "📦 Versão: $Version"
Write-Success "📥 Instalador: $installerPath"
Write-Success "🔗 Download URL: $downloadUrl"
Write-Host ""
Write-Info "📋 Próximos passos:"
Write-Info "   1. Atualize o Supabase com a nova versão"
Write-Info "   2. Execute: .\scripts\update-supabase-version.ps1 -Version $Version -DownloadUrl '$downloadUrl' -IsMandatory `$$IsMandatory"
Write-Host ""

