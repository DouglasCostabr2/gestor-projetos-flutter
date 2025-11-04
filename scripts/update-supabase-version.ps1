# Script para Atualizar Versão no Supabase
# Este script adiciona ou atualiza uma versão na tabela app_versions do Supabase

param(
    [Parameter(Mandatory=$true)]
    [string]$Version,
    
    [Parameter(Mandatory=$true)]
    [string]$DownloadUrl,
    
    [Parameter(Mandatory=$false)]
    [string]$ReleaseNotes = "",
    
    [Parameter(Mandatory=$false)]
    [bool]$IsMandatory = $false,
    
    [Parameter(Mandatory=$false)]
    [string]$MinSupportedVersion = "1.0.0"
)

# Cores para output
function Write-Success { Write-Host $args -ForegroundColor Green }
function Write-Info { Write-Host $args -ForegroundColor Cyan }
function Write-Warning { Write-Host $args -ForegroundColor Yellow }
function Write-Error { Write-Host $args -ForegroundColor Red }

# Banner
Write-Host ""
Write-Host "╔════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║      My Business - Atualização Supabase v1.0              ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

# Validar formato da versão
if ($Version -notmatch '^\d+\.\d+\.\d+$') {
    Write-Error "❌ Erro: Versão deve estar no formato X.Y.Z (ex: 1.2.0)"
    exit 1
}

Write-Info "🔄 Atualizando versão $Version no Supabase..."
Write-Host ""

# Configurações do Supabase
$projectId = "zfgsddweabsemxcchxjq"
$supabaseUrl = "https://zfgsddweabsemxcchxjq.supabase.co"

# Preparar release notes
if ($ReleaseNotes -eq "") {
    Write-Info "📝 Buscando release notes do GitHub..."
    
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
    
    # Tentar buscar release notes do GitHub
    $ghOutput = gh release view "v$Version" --json body 2>&1
    if ($LASTEXITCODE -eq 0) {
        $releaseData = $ghOutput | ConvertFrom-Json
        $ReleaseNotes = $releaseData.body
        Write-Success "✅ Release notes obtidas do GitHub"
    } else {
        Write-Warning "⚠️  Não foi possível obter release notes do GitHub"
        $ReleaseNotes = "# Versão $Version`n`nVeja mais detalhes em: https://github.com/DouglasCostabr2/gestor-projetos-flutter/releases/tag/v$Version"
    }
}

# Escapar aspas simples no SQL
$escapedReleaseNotes = $ReleaseNotes -replace "'", "''"
$escapedDownloadUrl = $DownloadUrl -replace "'", "''"

# Criar query SQL
$query = @"
INSERT INTO app_versions (version, download_url, release_notes, is_mandatory, min_supported_version)
VALUES ('$Version', '$escapedDownloadUrl', '$escapedReleaseNotes', $($IsMandatory.ToString().ToLower()), '$MinSupportedVersion')
ON CONFLICT (version) 
DO UPDATE SET 
    download_url = EXCLUDED.download_url,
    release_notes = EXCLUDED.release_notes,
    is_mandatory = EXCLUDED.is_mandatory,
    min_supported_version = EXCLUDED.min_supported_version,
    updated_at = NOW();
"@

Write-Info "📊 Informações da versão:"
Write-Info "   Versão: $Version"
Write-Info "   Download URL: $DownloadUrl"
Write-Info "   Obrigatória: $IsMandatory"
Write-Info "   Versão mínima suportada: $MinSupportedVersion"
Write-Host ""

# Confirmar antes de executar
Write-Warning "⚠️  Esta operação irá inserir/atualizar a versão no Supabase."
$confirm = Read-Host "Deseja continuar? (s/N)"
if ($confirm -ne 's' -and $confirm -ne 'S') {
    Write-Error "❌ Operação cancelada pelo usuário"
    exit 1
}

Write-Host ""
Write-Info "🚀 Executando query no Supabase..."

# Executar query usando Supabase CLI ou API
# Nota: Este script requer que você tenha o Supabase CLI instalado e configurado
# Ou você pode usar a API REST do Supabase

# Opção 1: Usando Supabase Management API (requer token)
# Para este exemplo, vamos mostrar a query que deve ser executada

Write-Host ""
Write-Host "╔════════════════════════════════════════════════════════════╗" -ForegroundColor Yellow
Write-Host "║              EXECUTE A QUERY ABAIXO NO SUPABASE            ║" -ForegroundColor Yellow
Write-Host "╚════════════════════════════════════════════════════════════╝" -ForegroundColor Yellow
Write-Host ""
Write-Host "Acesse: $supabaseUrl" -ForegroundColor Cyan
Write-Host "Vá em: SQL Editor" -ForegroundColor Cyan
Write-Host ""
Write-Host "Execute a seguinte query:" -ForegroundColor Cyan
Write-Host ""
Write-Host $query -ForegroundColor White
Write-Host ""

# Salvar query em arquivo para facilitar
$queryFile = "scripts\temp\supabase-update-$Version.sql"
$queryDir = Split-Path $queryFile -Parent
if (!(Test-Path $queryDir)) {
    New-Item -ItemType Directory -Path $queryDir -Force | Out-Null
}
Set-Content $queryFile -Value $query

Write-Success "✅ Query salva em: $queryFile"
Write-Host ""

# Copiar query para clipboard (se disponível)
try {
    Set-Clipboard -Value $query
    Write-Success "✅ Query copiada para a área de transferência!"
    Write-Info "   Cole diretamente no SQL Editor do Supabase"
} catch {
    Write-Warning "⚠️  Não foi possível copiar para a área de transferência"
}

Write-Host ""
Write-Info "📋 Ou execute manualmente via API:"
Write-Info "   Use a ferramenta Supabase do Augment Agent"
Write-Host ""

# Perguntar se o usuário quer que o script execute via API
Write-Host ""
$executeNow = Read-Host "Deseja que eu execute a query automaticamente via API? (s/N)"
if ($executeNow -eq 's' -or $executeNow -eq 'S') {
    Write-Info "🔄 Executando via Supabase Management API..."
    Write-Warning "⚠️  Esta funcionalidade requer que o Augment Agent execute a query"
    Write-Info "   Por favor, solicite ao Augment Agent para executar:"
    Write-Host ""
    Write-Host "   supabase POST /v1/projects/$projectId/database/query" -ForegroundColor Cyan
    Write-Host "   com o conteúdo do arquivo: $queryFile" -ForegroundColor Cyan
    Write-Host ""
}

Write-Host ""
Write-Success "✅ Script concluído!"
Write-Host ""

