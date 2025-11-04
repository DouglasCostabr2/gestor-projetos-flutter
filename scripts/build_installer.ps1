# ============================================================================
# Script para compilar e criar instalador Windows - My Business
# ============================================================================
# Uso: .\scripts\build_installer.ps1 [-Version "1.0.0"] [-InstallerType "inno"] [-SkipBuild] [-Clean]
#
# Par?metros:
#   -Version        : Vers?o do instalador (padr?o: 1.0.0)
#   -InstallerType  : Tipo de instalador - "inno" ou "nsis" (padr?o: inno)
#   -SkipBuild      : Pular compila??o do Flutter (usar build existente)
#   -Clean          : Fazer limpeza completa antes de compilar
#   -Verbose        : Mostrar informa??es detalhadas
# ============================================================================

param(
    [string]$Version = "1.1.0",
    [string]$InstallerType = "inno",
    [switch]$SkipBuild = $false,
    [switch]$Clean = $false,
    [switch]$Verbose = $false
)

# Configura??es
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

# ============================================================================
# Fun??es Auxiliares
# ============================================================================

function Write-Step {
    param([string]$Message, [string]$Color = "Cyan")
    Write-Host "`n$Message" -ForegroundColor $Color
}

function Write-Success {
    param([string]$Message)
    Write-Host "[OK] $Message" -ForegroundColor Green
}

function Write-Error-Custom {
    param([string]$Message)
    Write-Host "[ERRO] $Message" -ForegroundColor Red
}

function Write-Warning-Custom {
    param([string]$Message)
    Write-Host "[AVISO] $Message" -ForegroundColor Yellow
}

function Write-Info {
    param([string]$Message)
    Write-Host "[INFO] $Message" -ForegroundColor White
}

function Test-Command {
    param([string]$Command)
    try {
        Get-Command $Command -ErrorAction Stop | Out-Null
        return $true
    } catch {
        return $false
    }
}

function Get-FileSize {
    param([string]$Path)
    if (Test-Path $Path) {
        $size = (Get-Item $Path).Length
        if ($size -gt 1MB) {
            return "{0:N2} MB" -f ($size / 1MB)
        } else {
            return "{0:N2} KB" -f ($size / 1KB)
        }
    }
    return "0 KB"
}

# ============================================================================
# Banner
# ============================================================================

Clear-Host
Write-Host "??????????????????????????????????????????????????????????????????" -ForegroundColor Cyan
Write-Host "?                                                                ?" -ForegroundColor Cyan
Write-Host "?          MY BUSINESS - BUILD & INSTALLER GENERATOR             ?" -ForegroundColor Cyan
Write-Host "?                                                                ?" -ForegroundColor Cyan
Write-Host "??????????????????????????????????????????????????????????????????" -ForegroundColor Cyan
Write-Host ""
Write-Host "Vers?o: $Version" -ForegroundColor White
Write-Host "Tipo: $InstallerType" -ForegroundColor White
Write-Host "Data: $(Get-Date -Format 'dd/MM/yyyy HH:mm:ss')" -ForegroundColor White
Write-Host ""

# ============================================================================
# Verifica??es Iniciais
# ============================================================================

Write-Step "Verificando requisitos..." "Yellow"

# Verificar Flutter
if (-not (Test-Command "flutter")) {
    Write-Error-Custom "Flutter n?o encontrado no PATH!"
    Write-Info "Instale o Flutter: https://flutter.dev/docs/get-started/install/windows"
    exit 1
}
Write-Success "Flutter encontrado: $(flutter --version | Select-String 'Flutter' | Select-Object -First 1)"

# Verificar Git (opcional)
if (Test-Command "git") {
    Write-Success "Git encontrado"
} else {
    Write-Warning-Custom "Git n?o encontrado (opcional)"
}

# Verificar pubspec.yaml
if (-not (Test-Path "pubspec.yaml")) {
    Write-Error-Custom "pubspec.yaml n?o encontrado!"
    Write-Info "Execute este script na raiz do projeto Flutter"
    exit 1
}
Write-Success "Projeto Flutter encontrado"

# ============================================================================
# Limpeza (se solicitado)
# ============================================================================

if ($Clean) {
    Write-Step "?? Limpando builds anteriores..." "Yellow"

    if (Test-Path "build") {
        Remove-Item -Path "build" -Recurse -Force
        Write-Success "Diret?rio build removido"
    }

    flutter clean | Out-Null
    Write-Success "Flutter clean executado"

    flutter pub get | Out-Null
    Write-Success "Depend?ncias atualizadas"
}

# ============================================================================
# Compila??o Flutter
# ============================================================================

if (-not $SkipBuild) {
    Write-Step "Compilando versao Release..." "Yellow"

    $buildStartTime = Get-Date

    try {
        if ($Verbose) {
            flutter build windows --release
        } else {
            flutter build windows --release | Out-Null
        }

        if ($LASTEXITCODE -ne 0) {
            throw "Erro na compila??o"
        }

        $buildEndTime = Get-Date
        $buildDuration = ($buildEndTime - $buildStartTime).TotalSeconds

        Write-Success "Build Release conclu?do em $([math]::Round($buildDuration, 2)) segundos"
    } catch {
        Write-Error-Custom "Erro ao compilar!"
        Write-Info "Detalhes: $_"
        exit 1
    }
} else {
    Write-Warning-Custom "Pulando compila??o (usando build existente)"
}

# ============================================================================
# Verifica??o do Build
# ============================================================================

Write-Step "Verificando build..." "Yellow"

$exePath = "build\windows\x64\runner\Release\gestor_projetos_flutter.exe"
if (-not (Test-Path $exePath)) {
    Write-Error-Custom "Execut?vel n?o encontrado em $exePath"
    Write-Info "Execute sem -SkipBuild para compilar o projeto"
    exit 1
}

$exeSize = Get-FileSize $exePath
Write-Success "Execut?vel encontrado: $exePath ($exeSize)"

# Verificar DLLs necess?rias
$requiredDlls = @(
    "build\windows\x64\runner\Release\flutter_windows.dll"
)

foreach ($dll in $requiredDlls) {
    if (Test-Path $dll) {
        Write-Success "DLL encontrada: $(Split-Path $dll -Leaf)"
    } else {
        Write-Warning-Custom "DLL n?o encontrada: $dll"
    }
}

# ============================================================================
# Prepara??o do Instalador
# ============================================================================

Write-Step "Preparando instalador..." "Yellow"

$outputDir = "windows\installer\output"
if (-not (Test-Path $outputDir)) {
    New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
    Write-Success "Diret?rio de sa?da criado: $outputDir"
} else {
    Write-Info "Diret?rio de sa?da j? existe: $outputDir"
}

# ============================================================================
# Compila??o do Instalador
# ============================================================================

$installerStartTime = Get-Date

if ($InstallerType -eq "inno") {
    Write-Step "Compilando com Inno Setup..." "Yellow"

    # Procurar Inno Setup em locais comuns
    $innoPaths = @(
        "C:\Program Files (x86)\Inno Setup 6\ISCC.exe",
        "C:\Program Files\Inno Setup 6\ISCC.exe",
        "$env:ProgramFiles(x86)\Inno Setup 6\ISCC.exe",
        "$env:ProgramFiles\Inno Setup 6\ISCC.exe"
    )

    $innoPath = $null
    foreach ($path in $innoPaths) {
        if (Test-Path $path) {
            $innoPath = $path
            break
        }
    }

    if (-not $innoPath) {
        Write-Error-Custom "Inno Setup n?o encontrado!"
        Write-Info "Procurado em:"
        foreach ($path in $innoPaths) {
            Write-Info "  - $path"
        }
        Write-Info "`nBaixe em: https://jrsoftware.org/isdl.php"
        exit 1
    }

    Write-Success "Inno Setup encontrado: $innoPath"

    try {
        if ($Verbose) {
            & $innoPath "windows\installer\setup.iss"
        } else {
            & $innoPath "windows\installer\setup.iss" | Out-Null
        }

        if ($LASTEXITCODE -ne 0) {
            throw "Erro ao compilar instalador"
        }

        $installerEndTime = Get-Date
        $installerDuration = ($installerEndTime - $installerStartTime).TotalSeconds

        Write-Success "Instalador criado em $([math]::Round($installerDuration, 2)) segundos"
    } catch {
        Write-Error-Custom "Erro ao criar instalador!"
        Write-Info "Detalhes: $_"
        exit 1
    }
}
elseif ($InstallerType -eq "nsis") {
    Write-Step "Compilando com NSIS..." "Yellow"

    # Procurar NSIS em locais comuns
    $nsisPaths = @(
        "C:\Program Files (x86)\NSIS\makensis.exe",
        "C:\Program Files\NSIS\makensis.exe",
        "$env:ProgramFiles(x86)\NSIS\makensis.exe",
        "$env:ProgramFiles\NSIS\makensis.exe"
    )

    $nsisPath = $null
    foreach ($path in $nsisPaths) {
        if (Test-Path $path) {
            $nsisPath = $path
            break
        }
    }

    if (-not $nsisPath) {
        Write-Error-Custom "NSIS n?o encontrado!"
        Write-Info "Procurado em:"
        foreach ($path in $nsisPaths) {
            Write-Info "  - $path"
        }
        Write-Info "`nBaixe em: https://nsis.sourceforge.io/"
        exit 1
    }

    Write-Success "NSIS encontrado: $nsisPath"

    try {
        if ($Verbose) {
            & $nsisPath "windows\installer\setup.nsi"
        } else {
            & $nsisPath "windows\installer\setup.nsi" | Out-Null
        }

        if ($LASTEXITCODE -ne 0) {
            throw "Erro ao compilar instalador"
        }

        $installerEndTime = Get-Date
        $installerDuration = ($installerEndTime - $installerStartTime).TotalSeconds

        Write-Success "Instalador criado em $([math]::Round($installerDuration, 2)) segundos"
    } catch {
        Write-Error-Custom "Erro ao criar instalador!"
        Write-Info "Detalhes: $_"
        exit 1
    }
}
else {
    Write-Error-Custom "Tipo de instalador inv?lido: $InstallerType"
    Write-Info "Use: 'inno' ou 'nsis'"
    exit 1
}

# ============================================================================
# Verifica??o do Instalador
# ============================================================================

Write-Step "Verificando instalador..." "Yellow"

$installerPath = "$outputDir\MyBusiness-$Version-Setup.exe"
if (Test-Path $installerPath) {
    $installerSize = Get-FileSize $installerPath
    Write-Success "Instalador criado: $installerPath"
    Write-Info "Tamanho: $installerSize"

    # Calcular hash SHA256
    try {
        $hash = (Get-FileHash -Path $installerPath -Algorithm SHA256).Hash
        Write-Info "SHA256: $hash"

        # Salvar hash em arquivo
        $hashFile = "$installerPath.sha256"
        $hash | Out-File -FilePath $hashFile -Encoding ASCII
        Write-Success "Hash salvo em: $hashFile"
    } catch {
        Write-Warning-Custom "N?o foi poss?vel calcular hash"
    }
} else {
    Write-Error-Custom "Instalador n?o encontrado em $installerPath"
    exit 1
}

# ============================================================================
# Resumo Final
# ============================================================================

$totalEndTime = Get-Date
$totalDuration = ($totalEndTime - $buildStartTime).TotalSeconds

Write-Host ""
Write-Host "================================================================" -ForegroundColor Green
Write-Host "                  PROCESSO CONCLUIDO!                           " -ForegroundColor Green
Write-Host "================================================================" -ForegroundColor Green
Write-Host ""
Write-Host "RESUMO DA BUILD" -ForegroundColor Cyan
Write-Host "----------------------------------------------------------------" -ForegroundColor Cyan
Write-Host "  Versao:           $Version" -ForegroundColor White
Write-Host "  Tipo:             $InstallerType" -ForegroundColor White
Write-Host "  Tempo total:      $([math]::Round($totalDuration, 2)) segundos" -ForegroundColor White
Write-Host "  Executavel:       $exeSize" -ForegroundColor White
Write-Host "  Instalador:       $installerSize" -ForegroundColor White
Write-Host "----------------------------------------------------------------" -ForegroundColor Cyan
Write-Host ""
Write-Host "ARQUIVOS GERADOS" -ForegroundColor Cyan
Write-Host "----------------------------------------------------------------" -ForegroundColor Cyan
Write-Host "  Instalador:       $installerPath" -ForegroundColor White
Write-Host "  Hash SHA256:      $hashFile" -ForegroundColor White
Write-Host "----------------------------------------------------------------" -ForegroundColor Cyan
Write-Host ""
Write-Host "PROXIMOS PASSOS" -ForegroundColor Cyan
Write-Host "----------------------------------------------------------------" -ForegroundColor Cyan
Write-Host "  1. Testar o instalador em uma maquina limpa" -ForegroundColor White
Write-Host "  2. Verificar se todas as funcionalidades estao operacionais" -ForegroundColor White
Write-Host "  3. Criar release no GitHub com o instalador" -ForegroundColor White
Write-Host "  4. Distribuir para os usuarios" -ForegroundColor White
Write-Host "----------------------------------------------------------------" -ForegroundColor Cyan
Write-Host ""

# Abrir pasta de saida
if (-not $Verbose) {
    $openFolder = Read-Host "Deseja abrir a pasta de saida? (S/N)"
    if ($openFolder -eq "S" -or $openFolder -eq "s") {
        Start-Process explorer.exe -ArgumentList $outputDir
    }
}

Write-Host "Concluido!" -ForegroundColor Green
Write-Host ""

