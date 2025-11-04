# Script para executar query SQL no Supabase via Management API
# Requer que você tenha acesso ao Augment Agent ou Supabase CLI

param(
    [Parameter(Mandatory=$true)]
    [string]$QueryFile
)

# Cores para output
function Write-Success { Write-Host $args -ForegroundColor Green }
function Write-Info { Write-Host $args -ForegroundColor Cyan }
function Write-Error { Write-Host $args -ForegroundColor Red }

Write-Host ""
Write-Host "╔════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║         Executar Query SQL no Supabase                     ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

# Verificar se o arquivo existe
if (!(Test-Path $QueryFile)) {
    Write-Error "❌ Erro: Arquivo não encontrado: $QueryFile"
    exit 1
}

# Ler conteúdo do arquivo
$query = Get-Content $QueryFile -Raw

Write-Info "📄 Arquivo: $QueryFile"
Write-Info "📊 Tamanho: $((Get-Item $QueryFile).Length) bytes"
Write-Host ""

Write-Info "📋 Query a ser executada:"
Write-Host ""
Write-Host $query -ForegroundColor White
Write-Host ""

# Configurações
$projectId = "zfgsddweabsemxcchxjq"

Write-Info "🎯 Projeto Supabase: $projectId"
Write-Host ""

Write-Info "💡 Para executar esta query, você tem 3 opções:"
Write-Host ""

Write-Host "1️⃣  Via Supabase Web UI (Mais Fácil):" -ForegroundColor Yellow
Write-Host "   - Acesse: https://zfgsddweabsemxcchxjq.supabase.co" -ForegroundColor Gray
Write-Host "   - Vá em: SQL Editor" -ForegroundColor Gray
Write-Host "   - Cole a query (já está na área de transferência)" -ForegroundColor Gray
Write-Host "   - Clique em 'Run'" -ForegroundColor Gray
Write-Host ""

Write-Host "2️⃣  Via Augment Agent:" -ForegroundColor Yellow
Write-Host "   - Peça ao Augment Agent para executar:" -ForegroundColor Gray
Write-Host "   - supabase POST /v1/projects/$projectId/database/query" -ForegroundColor Cyan
Write-Host "   - com query: (conteúdo do arquivo $QueryFile)" -ForegroundColor Gray
Write-Host ""

Write-Host "3️⃣  Via Supabase CLI (Se instalado):" -ForegroundColor Yellow
Write-Host "   - supabase db execute --file $QueryFile" -ForegroundColor Cyan
Write-Host ""

# Copiar para clipboard
try {
    Set-Clipboard -Value $query
    Write-Success "✅ Query copiada para a área de transferência!"
} catch {
    Write-Error "❌ Não foi possível copiar para a área de transferência"
}

Write-Host ""
$choice = Read-Host "Escolha uma opção (1/2/3) ou Enter para sair"

switch ($choice) {
    "1" {
        Write-Info "🌐 Abrindo Supabase no navegador..."
        Start-Process "https://zfgsddweabsemxcchxjq.supabase.co/project/zfgsddweabsemxcchxjq/sql/new"
        Write-Success "✅ Cole a query (Ctrl+V) e clique em 'Run'"
    }
    "2" {
        Write-Info "🤖 Instruções para Augment Agent:"
        Write-Host ""
        Write-Host "Peça ao Augment Agent:" -ForegroundColor Cyan
        Write-Host "Execute a query SQL do arquivo: $QueryFile" -ForegroundColor White
        Write-Host ""
    }
    "3" {
        Write-Info "🔧 Executando via Supabase CLI..."
        supabase db execute --file $QueryFile
        if ($LASTEXITCODE -eq 0) {
            Write-Success "✅ Query executada com sucesso!"
        } else {
            Write-Error "❌ Erro ao executar query"
        }
    }
    default {
        Write-Info "👋 Saindo..."
    }
}

Write-Host ""

