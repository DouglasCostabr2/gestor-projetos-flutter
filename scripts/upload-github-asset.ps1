# Script para fazer upload de asset para GitHub Release usando credenciais do Git
param(
    [Parameter(Mandatory=$true)]
    [string]$FilePath,
    
    [Parameter(Mandatory=$true)]
    [string]$ReleaseId,
    
    [Parameter(Mandatory=$true)]
    [string]$FileName
)

$ErrorActionPreference = "Stop"

# Configuracoes
$owner = "DouglasCostabr2"
$repo = "gestor-projetos-flutter"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Upload de Asset para GitHub Release" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Arquivo: $FileName" -ForegroundColor White
Write-Host "Release ID: $ReleaseId" -ForegroundColor White
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
Write-Host "Tamanho: $fileSizeMB MB" -ForegroundColor Green
Write-Host ""

# Tentar obter credenciais do Windows Credential Manager
Write-Host "Obtendo credenciais do GitHub..." -ForegroundColor Yellow

$token = $null

# Metodo 1: Tentar variavel de ambiente
if ($env:GITHUB_TOKEN) {
    $token = $env:GITHUB_TOKEN
    Write-Host "Token encontrado em variavel de ambiente" -ForegroundColor Green
}

# Metodo 2: Tentar obter do Git Credential Manager
if (-not $token) {
    try {
        # Criar processo para obter credenciais
        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName = "git"
        $psi.Arguments = "credential fill"
        $psi.RedirectStandardInput = $true
        $psi.RedirectStandardOutput = $true
        $psi.RedirectStandardError = $true
        $psi.UseShellExecute = $false
        $psi.CreateNoWindow = $true
        
        $process = New-Object System.Diagnostics.Process
        $process.StartInfo = $psi
        $process.Start() | Out-Null
        
        # Enviar input
        $process.StandardInput.WriteLine("protocol=https")
        $process.StandardInput.WriteLine("host=github.com")
        $process.StandardInput.WriteLine("")
        $process.StandardInput.Close()
        
        # Ler output
        $output = $process.StandardOutput.ReadToEnd()
        $process.WaitForExit()
        
        # Extrair password (token)
        if ($output -match "password=([^\r\n]+)") {
            $token = $matches[1]
            Write-Host "Token obtido do Git Credential Manager" -ForegroundColor Green
        }
    } catch {
        Write-Host "Nao foi possivel obter token do Git Credential Manager" -ForegroundColor Yellow
    }
}

# Metodo 3: Solicitar manualmente
if (-not $token) {
    Write-Host ""
    Write-Host "Nao foi possivel obter o token automaticamente." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Opcao 1: Definir variavel de ambiente GITHUB_TOKEN" -ForegroundColor Cyan
    Write-Host "Opcao 2: Criar Personal Access Token em https://github.com/settings/tokens" -ForegroundColor Cyan
    Write-Host ""
    
    $tokenInput = Read-Host "Cole seu GitHub Personal Access Token aqui (ou pressione Enter para cancelar)"
    
    if ([string]::IsNullOrWhiteSpace($tokenInput)) {
        Write-Host ""
        Write-Host "Upload cancelado pelo usuario" -ForegroundColor Yellow
        exit 1
    }
    
    $token = $tokenInput.Trim()
}

if ([string]::IsNullOrWhiteSpace($token)) {
    Write-Host ""
    Write-Host "ERRO: Token do GitHub e obrigatorio para fazer upload" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "Preparando upload..." -ForegroundColor Cyan

# Preparar URL de upload
$uploadUrl = "https://uploads.github.com/repos/$owner/$repo/releases/$ReleaseId/assets?name=$FileName"

Write-Host "URL: $uploadUrl" -ForegroundColor Gray
Write-Host ""

try {
    Write-Host "Lendo arquivo..." -ForegroundColor Yellow
    $fileBytes = [System.IO.File]::ReadAllBytes($FilePath)
    
    Write-Host "Preparando requisicao..." -ForegroundColor Yellow
    $headers = @{
        "Authorization" = "Bearer $token"
        "Content-Type" = "application/octet-stream"
        "Accept" = "application/vnd.github+json"
    }
    
    Write-Host "Enviando arquivo para GitHub..." -ForegroundColor Yellow
    Write-Host "Isso pode levar alguns minutos dependendo da velocidade da internet..." -ForegroundColor Gray
    Write-Host ""
    
    # Fazer upload com timeout maior
    $response = Invoke-RestMethod -Uri $uploadUrl -Method Post -Headers $headers -Body $fileBytes -TimeoutSec 300
    
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Green
    Write-Host "UPLOAD CONCLUIDO COM SUCESSO!" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "Nome do asset: $($response.name)" -ForegroundColor White
    Write-Host "Tamanho: $([math]::Round($response.size / 1MB, 2)) MB" -ForegroundColor White
    Write-Host "Downloads: $($response.download_count)" -ForegroundColor White
    Write-Host ""
    Write-Host "URL de download:" -ForegroundColor Cyan
    Write-Host $response.browser_download_url -ForegroundColor White
    Write-Host ""
    Write-Host "O instalador esta disponivel para download!" -ForegroundColor Green
    Write-Host ""
    
    exit 0
    
} catch {
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Red
    Write-Host "ERRO AO FAZER UPLOAD" -ForegroundColor Red
    Write-Host "========================================" -ForegroundColor Red
    Write-Host ""
    Write-Host "Mensagem de erro:" -ForegroundColor Yellow
    Write-Host $_.Exception.Message -ForegroundColor Red
    Write-Host ""
    
    if ($_.Exception.Response) {
        try {
            $reader = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
            $responseBody = $reader.ReadToEnd()
            Write-Host "Detalhes da resposta:" -ForegroundColor Yellow
            Write-Host $responseBody -ForegroundColor Red
            Write-Host ""
        } catch {
            # Ignorar erro ao ler resposta
        }
    }
    
    Write-Host "Possiveis causas:" -ForegroundColor Yellow
    Write-Host "1. Token invalido ou expirado" -ForegroundColor White
    Write-Host "2. Token sem permissoes necessarias (precisa de 'repo')" -ForegroundColor White
    Write-Host "3. Asset com mesmo nome ja existe na release" -ForegroundColor White
    Write-Host "4. Problema de conexao com internet" -ForegroundColor White
    Write-Host ""
    
    exit 1
}

