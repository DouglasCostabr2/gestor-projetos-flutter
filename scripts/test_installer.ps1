# ============================================================================
# Script de Teste do Instalador - My Business
# ============================================================================
# Uso: .\scripts\test_installer.ps1 [-InstallerPath "caminho"] [-Verbose]
#
# Este script realiza testes automatizados no instalador gerado
# ============================================================================

param(
    [string]$InstallerPath = "windows\installer\output\MyBusiness-1.0.0-Setup.exe",
    [switch]$Verbose = $false
)

# Configurações
$ErrorActionPreference = "Continue"
$ProgressPreference = "SilentlyContinue"

# ============================================================================
# Funções Auxiliares
# ============================================================================

function Write-TestHeader {
    param([string]$Message)
    Write-Host "`n╔════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║ $($Message.PadRight(62)) ║" -ForegroundColor Cyan
    Write-Host "╚════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
}

function Write-TestStep {
    param([string]$Message)
    Write-Host "`n🔍 $Message" -ForegroundColor Yellow
}

function Write-TestSuccess {
    param([string]$Message)
    Write-Host "  ✅ $Message" -ForegroundColor Green
}

function Write-TestFail {
    param([string]$Message)
    Write-Host "  ❌ $Message" -ForegroundColor Red
}

function Write-TestWarning {
    param([string]$Message)
    Write-Host "  ⚠️  $Message" -ForegroundColor Yellow
}

function Write-TestInfo {
    param([string]$Message)
    Write-Host "  ℹ️  $Message" -ForegroundColor White
}

# ============================================================================
# Variáveis de Teste
# ============================================================================

$testResults = @{
    Total = 0
    Passed = 0
    Failed = 0
    Warnings = 0
}

# ============================================================================
# Banner
# ============================================================================

Clear-Host
Write-TestHeader "MY BUSINESS - TESTE DE INSTALADOR"
Write-Host ""
Write-Host "Instalador: $InstallerPath" -ForegroundColor White
Write-Host "Data: $(Get-Date -Format 'dd/MM/yyyy HH:mm:ss')" -ForegroundColor White
Write-Host ""

# ============================================================================
# Teste 1: Verificar Existência do Instalador
# ============================================================================

Write-TestStep "Teste 1: Verificando existência do instalador..."
$testResults.Total++

if (Test-Path $InstallerPath) {
    Write-TestSuccess "Instalador encontrado"
    $testResults.Passed++
    
    # Informações do arquivo
    $fileInfo = Get-Item $InstallerPath
    $fileSize = "{0:N2} MB" -f ($fileInfo.Length / 1MB)
    Write-TestInfo "Tamanho: $fileSize"
    Write-TestInfo "Data de criação: $($fileInfo.CreationTime)"
    Write-TestInfo "Última modificação: $($fileInfo.LastWriteTime)"
} else {
    Write-TestFail "Instalador não encontrado em: $InstallerPath"
    $testResults.Failed++
    Write-Host "`n❌ Teste abortado: instalador não encontrado!" -ForegroundColor Red
    exit 1
}

# ============================================================================
# Teste 2: Verificar Hash SHA256
# ============================================================================

Write-TestStep "Teste 2: Verificando hash SHA256..."
$testResults.Total++

$hashFile = "$InstallerPath.sha256"
if (Test-Path $hashFile) {
    Write-TestSuccess "Arquivo de hash encontrado"
    
    try {
        $expectedHash = (Get-Content $hashFile).Trim()
        $actualHash = (Get-FileHash -Path $InstallerPath -Algorithm SHA256).Hash
        
        if ($expectedHash -eq $actualHash) {
            Write-TestSuccess "Hash SHA256 válido"
            $testResults.Passed++
            if ($Verbose) {
                Write-TestInfo "Hash: $actualHash"
            }
        } else {
            Write-TestFail "Hash SHA256 não corresponde!"
            Write-TestInfo "Esperado: $expectedHash"
            Write-TestInfo "Atual: $actualHash"
            $testResults.Failed++
        }
    } catch {
        Write-TestFail "Erro ao verificar hash: $_"
        $testResults.Failed++
    }
} else {
    Write-TestWarning "Arquivo de hash não encontrado"
    $testResults.Warnings++
}

# ============================================================================
# Teste 3: Verificar Assinatura Digital (se existir)
# ============================================================================

Write-TestStep "Teste 3: Verificando assinatura digital..."
$testResults.Total++

try {
    $signature = Get-AuthenticodeSignature -FilePath $InstallerPath
    
    if ($signature.Status -eq "Valid") {
        Write-TestSuccess "Assinatura digital válida"
        Write-TestInfo "Assinado por: $($signature.SignerCertificate.Subject)"
        $testResults.Passed++
    } elseif ($signature.Status -eq "NotSigned") {
        Write-TestWarning "Instalador não assinado digitalmente"
        Write-TestInfo "Recomendação: Assine o instalador para distribuição pública"
        $testResults.Warnings++
    } else {
        Write-TestFail "Assinatura digital inválida: $($signature.Status)"
        $testResults.Failed++
    }
} catch {
    Write-TestWarning "Não foi possível verificar assinatura: $_"
    $testResults.Warnings++
}

# ============================================================================
# Teste 4: Verificar Estrutura do Instalador (Inno Setup)
# ============================================================================

Write-TestStep "Teste 4: Verificando estrutura do instalador..."
$testResults.Total++

try {
    # Verificar se é um executável válido
    $peHeader = [System.IO.File]::ReadAllBytes($InstallerPath)[0..1]
    if ($peHeader[0] -eq 0x4D -and $peHeader[1] -eq 0x5A) {
        Write-TestSuccess "Executável PE válido"
        $testResults.Passed++
    } else {
        Write-TestFail "Arquivo não é um executável PE válido"
        $testResults.Failed++
    }
} catch {
    Write-TestFail "Erro ao verificar estrutura: $_"
    $testResults.Failed++
}

# ============================================================================
# Teste 5: Verificar Tamanho do Instalador
# ============================================================================

Write-TestStep "Teste 5: Verificando tamanho do instalador..."
$testResults.Total++

$fileSize = (Get-Item $InstallerPath).Length
$minSize = 10 * 1024 * 1024  # 10 MB
$maxSize = 500 * 1024 * 1024  # 500 MB

if ($fileSize -lt $minSize) {
    Write-TestWarning "Instalador muito pequeno: $("{0:N2} MB" -f ($fileSize / 1MB))"
    Write-TestInfo "Tamanho mínimo esperado: 10 MB"
    $testResults.Warnings++
} elseif ($fileSize -gt $maxSize) {
    Write-TestWarning "Instalador muito grande: $("{0:N2} MB" -f ($fileSize / 1MB))"
    Write-TestInfo "Tamanho máximo recomendado: 500 MB"
    $testResults.Warnings++
} else {
    Write-TestSuccess "Tamanho adequado: $("{0:N2} MB" -f ($fileSize / 1MB))"
    $testResults.Passed++
}

# ============================================================================
# Teste 6: Verificar Arquivos de Origem
# ============================================================================

Write-TestStep "Teste 6: Verificando arquivos de origem..."
$testResults.Total++

$requiredFiles = @(
    "build\windows\x64\runner\Release\my_business.exe",
    "build\windows\x64\runner\Release\flutter_windows.dll"
)

$allFilesExist = $true
foreach ($file in $requiredFiles) {
    if (Test-Path $file) {
        Write-TestSuccess "Encontrado: $(Split-Path $file -Leaf)"
    } else {
        Write-TestFail "Não encontrado: $file"
        $allFilesExist = $false
    }
}

if ($allFilesExist) {
    $testResults.Passed++
} else {
    $testResults.Failed++
}

# ============================================================================
# Teste 7: Verificar Scripts de Instalação
# ============================================================================

Write-TestStep "Teste 7: Verificando scripts de instalação..."
$testResults.Total++

$setupScript = "windows\installer\setup.iss"
if (Test-Path $setupScript) {
    Write-TestSuccess "Script Inno Setup encontrado"
    
    # Verificar conteúdo do script
    $scriptContent = Get-Content $setupScript -Raw
    
    $checks = @{
        "AppName" = $scriptContent -match '#define MyAppName'
        "AppVersion" = $scriptContent -match '#define MyAppVersion'
        "AppId" = $scriptContent -match '#define MyAppId'
        "Files" = $scriptContent -match '\[Files\]'
        "Icons" = $scriptContent -match '\[Icons\]'
        "Code" = $scriptContent -match '\[Code\]'
    }
    
    $allChecksPass = $true
    foreach ($check in $checks.GetEnumerator()) {
        if ($check.Value) {
            if ($Verbose) {
                Write-TestSuccess "Seção $($check.Key) presente"
            }
        } else {
            Write-TestFail "Seção $($check.Key) ausente"
            $allChecksPass = $false
        }
    }
    
    if ($allChecksPass) {
        $testResults.Passed++
    } else {
        $testResults.Failed++
    }
} else {
    Write-TestFail "Script de instalação não encontrado"
    $testResults.Failed++
}

# ============================================================================
# Teste 8: Verificar Documentação
# ============================================================================

Write-TestStep "Teste 8: Verificando documentação..."
$testResults.Total++

$docs = @(
    "LICENSE.txt",
    "README.md",
    "windows\installer\README.md"
)

$docsFound = 0
foreach ($doc in $docs) {
    if (Test-Path $doc) {
        Write-TestSuccess "Encontrado: $doc"
        $docsFound++
    } else {
        Write-TestWarning "Não encontrado: $doc"
    }
}

if ($docsFound -eq $docs.Count) {
    $testResults.Passed++
} elseif ($docsFound -gt 0) {
    $testResults.Warnings++
} else {
    $testResults.Failed++
}

# ============================================================================
# Resumo dos Testes
# ============================================================================

Write-Host ""
Write-Host "╔════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║                     RESUMO DOS TESTES                          ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

$passRate = if ($testResults.Total -gt 0) { 
    [math]::Round(($testResults.Passed / $testResults.Total) * 100, 2) 
} else { 
    0 
}

Write-Host "Total de testes:    $($testResults.Total)" -ForegroundColor White
Write-Host "Testes aprovados:   $($testResults.Passed)" -ForegroundColor Green
Write-Host "Testes falhados:    $($testResults.Failed)" -ForegroundColor Red
Write-Host "Avisos:             $($testResults.Warnings)" -ForegroundColor Yellow
Write-Host "Taxa de aprovação:  $passRate%" -ForegroundColor $(if ($passRate -ge 80) { "Green" } elseif ($passRate -ge 60) { "Yellow" } else { "Red" })
Write-Host ""

# ============================================================================
# Conclusão
# ============================================================================

if ($testResults.Failed -eq 0) {
    Write-Host "✅ TODOS OS TESTES PASSARAM!" -ForegroundColor Green
    Write-Host ""
    Write-Host "O instalador está pronto para distribuição." -ForegroundColor Green
    exit 0
} elseif ($testResults.Failed -le 2) {
    Write-Host "⚠️  ALGUNS TESTES FALHARAM" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Revise os erros acima antes de distribuir." -ForegroundColor Yellow
    exit 1
} else {
    Write-Host "❌ MUITOS TESTES FALHARAM!" -ForegroundColor Red
    Write-Host ""
    Write-Host "Corrija os problemas antes de distribuir o instalador." -ForegroundColor Red
    exit 1
}

