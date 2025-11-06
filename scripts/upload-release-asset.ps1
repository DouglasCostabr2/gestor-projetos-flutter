# Script para fazer upload de asset para GitHub Release
param(
    [Parameter(Mandatory=$true)]
    [string]$FilePath,

    [Parameter(Mandatory=$true)]
    [string]$ReleaseTag,

    [Parameter(Mandatory=$true)]
    [string]$FileName
)

$ErrorActionPreference = "Stop"

# Configuracoes
$owner = "DouglasCostabr2"
$repo = "gestor-projetos-flutter"
$releaseId = "260102400"

Write-Host "Fazendo upload de $FileName para release $ReleaseTag..." -ForegroundColor Cyan
Write-Host ""

# Verificar se o arquivo existe
if (-not (Test-Path $FilePath)) {
    Write-Host "ERRO: Arquivo nao encontrado: $FilePath" -ForegroundColor Red
    exit 1
}

# Obter tamanho do arquivo
$fileInfo = Get-Item $FilePath
$fileSize = $fileInfo.Length
$fileSizeMB = [math]::Round($fileSize / 1MB, 2)
Write-Host "Arquivo: $FileName ($fileSizeMB MB)" -ForegroundColor Green

# Tentar obter token do GitHub
$token = $null

# Metodo 1: Variavel de ambiente
if ($env:GITHUB_TOKEN) {
    $token = $env:GITHUB_TOKEN
    Write-Host "Token encontrado em GITHUB_TOKEN" -ForegroundColor Green
}

# Metodo 2: Solicitar ao usuario
if (-not $token) {
    Write-Host ""
    Write-Host "Token do GitHub nao encontrado automaticamente" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Para fazer upload, voce precisa de um Personal Access Token do GitHub." -ForegroundColor Cyan
    Write-Host "Crie um em: https://github.com/settings/tokens" -ForegroundColor Cyan
    Write-Host "Permissoes necessarias: repo (Full control of private repositories)" -ForegroundColor Cyan
    Write-Host ""

    $token = Read-Host "Cole seu GitHub Personal Access Token aqui"
}

if (-not $token) {
    Write-Host "ERRO: Token do GitHub e obrigatorio" -ForegroundColor Red
    exit 1
}

# Preparar upload
$uploadUrl = "https://uploads.github.com/repos/$owner/$repo/releases/$releaseId/assets?name=$FileName"

Write-Host ""
Write-Host "Iniciando upload..." -ForegroundColor Cyan

try {
    # Ler arquivo como bytes
    $fileBytes = [System.IO.File]::ReadAllBytes($FilePath)

    # Preparar headers
    $headers = @{
        "Authorization" = "Bearer $token"
        "Content-Type" = "application/octet-stream"
        "Accept" = "application/vnd.github+json"
    }

    # Fazer upload
    $response = Invoke-RestMethod -Uri $uploadUrl -Method Post -Headers $headers -Body $fileBytes -ContentType "application/octet-stream"

    Write-Host ""
    Write-Host "Upload concluido com sucesso!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Detalhes do asset:" -ForegroundColor Cyan
    Write-Host "   Nome: $($response.name)" -ForegroundColor White
    Write-Host "   Tamanho: $([math]::Round($response.size / 1MB, 2)) MB" -ForegroundColor White
    Write-Host "   URL: $($response.browser_download_url)" -ForegroundColor White
    Write-Host ""
    Write-Host "O instalador esta disponivel para download!" -ForegroundColor Green

} catch {
    Write-Host ""
    Write-Host "ERRO ao fazer upload:" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red

    if ($_.Exception.Response) {
        $reader = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
        $responseBody = $reader.ReadToEnd()
        Write-Host "Detalhes: $responseBody" -ForegroundColor Red
    }

    exit 1
}

