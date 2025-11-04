# Script PowerShell para automatizar build e criação de instalador
# My Business - Build Automation Script
#
# USO:
#   .\scripts\build-installer.ps1
#   .\scripts\build-installer.ps1 -Version "1.2.0" -BuildNumber 3
#   .\scripts\build-installer.ps1 -SkipBuild
#   .\scripts\build-installer.ps1 -OpenOutput

param(
    [string]$Version = "",
    [int]$BuildNumber = 0,
    [switch]$SkipBuild = $false,
    [switch]$SkipInstaller = $false,
    [switch]$OpenOutput = $false,
    [switch]$Help = $false
)

# Cores para output
function Write-ColorOutput($ForegroundColor) {
    $fc = $host.UI.RawUI.ForegroundColor
    $host.UI.RawUI.ForegroundColor = $ForegroundColor
    if ($args) {
        Write-Output $args
    }
    $host.UI.RawUI.ForegroundColor = $fc
}

function Write-Success { Write-ColorOutput Green $args }
function Write-Info { Write-ColorOutput Cyan $args }
function Write-Warning { Write-ColorOutput Yellow $args }
function Write-Error { Write-ColorOutput Red $args }

# Banner
function Show-Banner {
    Write-Info "╔════════════════════════════════════════════════════════════╗"
    Write-Info "║         My Business - Build Automation Script             ║"
    Write-Info "║                                                            ║"
    Write-Info "║  Automatiza o processo de build e criação de instalador   ║"
    Write-Info "╚════════════════════════════════════════════════════════════╝"
    Write-Output ""
}

# Ajuda
function Show-Help {
    Show-Banner
    Write-Output "USO:"
    Write-Output "  .\scripts\build-installer.ps1 [opções]"
    Write-Output ""
    Write-Output "OPÇÕES:"
    Write-Output "  -Version <versão>      Versão do app (ex: 1.2.0)"
    Write-Output "  -BuildNumber <número>  Número do build (ex: 3)"
    Write-Output "  -SkipBuild            Pular compilação do Flutter"
    Write-Output "  -SkipInstaller        Pular criação do instalador"
    Write-Output "  -OpenOutput           Abrir pasta de saída ao final"
    Write-Output "  -Help                 Mostrar esta ajuda"
    Write-Output ""
    Write-Output "EXEMPLOS:"
    Write-Output "  .\scripts\build-installer.ps1"
    Write-Output "  .\scripts\build-installer.ps1 -Version '1.2.0' -BuildNumber 3"
    Write-Output "  .\scripts\build-installer.ps1 -SkipBuild"
    Write-Output "  .\scripts\build-installer.ps1 -OpenOutput"
    Write-Output ""
    exit 0
}

if ($Help) {
    Show-Help
}

Show-Banner

# Verificar se está na raiz do projeto
if (-not (Test-Path "pubspec.yaml")) {
    Write-Error "❌ Erro: Execute este script da raiz do projeto!"
    Write-Output ""
    Write-Output "Navegue até a pasta do projeto e execute:"
    Write-Output "  cd C:\caminho\para\gestor_projetos_flutter"
    Write-Output "  .\scripts\build-installer.ps1"
    exit 1
}

# Ler versão atual do pubspec.yaml se não fornecida
if ($Version -eq "" -or $BuildNumber -eq 0) {
    Write-Info "📖 Lendo versão do pubspec.yaml..."
    $pubspecContent = Get-Content "pubspec.yaml" -Raw
    if ($pubspecContent -match "version:\s*(\d+\.\d+\.\d+)\+(\d+)") {
        $currentVersion = $matches[1]
        $currentBuildNumber = [int]$matches[2]
        
        if ($Version -eq "") {
            $Version = $currentVersion
        }
        if ($BuildNumber -eq 0) {
            $BuildNumber = $currentBuildNumber
        }
        
        Write-Success "   Versão atual: $Version+$BuildNumber"
    } else {
        Write-Error "❌ Não foi possível ler a versão do pubspec.yaml"
        exit 1
    }
}

Write-Output ""
Write-Info "🎯 Configuração:"
Write-Output "   Versão: $Version"
Write-Output "   Build: $BuildNumber"
Write-Output "   Pular Build: $SkipBuild"
Write-Output "   Pular Instalador: $SkipInstaller"
Write-Output ""

# Confirmar
$confirmation = Read-Host "Continuar? (S/N)"
if ($confirmation -ne 'S' -and $confirmation -ne 's') {
    Write-Warning "⚠️  Operação cancelada pelo usuário"
    exit 0
}

Write-Output ""

# Etapa 1: Limpar builds anteriores
if (-not $SkipBuild) {
    Write-Info "🧹 Limpando builds anteriores..."
    try {
        flutter clean | Out-Null
        Write-Success "   ✓ Build anterior limpo"
    } catch {
        Write-Warning "   ⚠️  Erro ao limpar build (continuando...)"
    }
    Write-Output ""
}

# Etapa 2: Obter dependências
if (-not $SkipBuild) {
    Write-Info "📦 Obtendo dependências..."
    try {
        flutter pub get | Out-Null
        Write-Success "   ✓ Dependências obtidas"
    } catch {
        Write-Error "   ❌ Erro ao obter dependências"
        exit 1
    }
    Write-Output ""
}

# Etapa 3: Compilar app
if (-not $SkipBuild) {
    Write-Info "🔨 Compilando aplicativo (isso pode demorar)..."
    Write-Output ""
    
    $buildStartTime = Get-Date
    
    try {
        flutter build windows --release
        
        $buildEndTime = Get-Date
        $buildDuration = $buildEndTime - $buildStartTime
        
        Write-Output ""
        Write-Success "   ✓ Aplicativo compilado com sucesso!"
        Write-Output "   Tempo: $($buildDuration.Minutes)m $($buildDuration.Seconds)s"
    } catch {
        Write-Error "   ❌ Erro ao compilar aplicativo"
        exit 1
    }
    Write-Output ""
}

# Verificar se o executável foi criado
$exePath = "build\windows\x64\runner\Release\gestor_projetos_flutter.exe"
if (-not (Test-Path $exePath)) {
    Write-Error "❌ Executável não encontrado: $exePath"
    Write-Output ""
    Write-Output "Execute o build manualmente:"
    Write-Output "  flutter build windows --release"
    exit 1
}

$exeSize = (Get-Item $exePath).Length / 1MB
Write-Success "   ✓ Executável encontrado ($([math]::Round($exeSize, 2)) MB)"
Write-Output ""

# Etapa 4: Criar instalador
if (-not $SkipInstaller) {
    Write-Info "📦 Criando instalador com Inno Setup..."
    
    # Procurar Inno Setup
    $innoSetupPaths = @(
        "C:\Program Files (x86)\Inno Setup 6\ISCC.exe",
        "C:\Program Files\Inno Setup 6\ISCC.exe",
        "C:\Program Files (x86)\Inno Setup 5\ISCC.exe",
        "C:\Program Files\Inno Setup 5\ISCC.exe"
    )
    
    $isccPath = $null
    foreach ($path in $innoSetupPaths) {
        if (Test-Path $path) {
            $isccPath = $path
            break
        }
    }
    
    if ($null -eq $isccPath) {
        Write-Error "   ❌ Inno Setup não encontrado!"
        Write-Output ""
        Write-Output "Instale o Inno Setup:"
        Write-Output "  https://jrsoftware.org/isdl.php"
        Write-Output ""
        Write-Output "Ou crie o instalador manualmente:"
        Write-Output "  1. Abra installer\setup.iss no Inno Setup"
        Write-Output "  2. Atualize a versão para $Version"
        Write-Output "  3. Compile (F9)"
        exit 1
    }
    
    Write-Success "   ✓ Inno Setup encontrado: $isccPath"
    
    # Atualizar versão no script do Inno Setup
    Write-Info "   Atualizando versão no setup.iss..."
    $setupIssPath = "installer\setup.iss"
    
    if (Test-Path $setupIssPath) {
        $setupContent = Get-Content $setupIssPath -Raw
        $setupContent = $setupContent -replace '#define MyAppVersion ".*"', "#define MyAppVersion `"$Version`""
        Set-Content $setupIssPath -Value $setupContent
        Write-Success "   ✓ Versão atualizada para $Version"
    } else {
        Write-Error "   ❌ Arquivo setup.iss não encontrado!"
        exit 1
    }
    
    # Compilar instalador
    Write-Info "   Compilando instalador..."
    try {
        & $isccPath $setupIssPath | Out-Null
        Write-Success "   ✓ Instalador criado com sucesso!"
    } catch {
        Write-Error "   ❌ Erro ao criar instalador"
        exit 1
    }
    Write-Output ""
}

# Etapa 5: Verificar resultado
$installerPath = "installer\Output\MyBusiness-Setup-$Version.exe"
if (Test-Path $installerPath) {
    $installerSize = (Get-Item $installerPath).Length / 1MB
    
    Write-Success "╔════════════════════════════════════════════════════════════╗"
    Write-Success "║                    BUILD CONCLUÍDO!                        ║"
    Write-Success "╚════════════════════════════════════════════════════════════╝"
    Write-Output ""
    Write-Success "✓ Instalador criado:"
    Write-Output "  📁 $installerPath"
    Write-Output "  📊 Tamanho: $([math]::Round($installerSize, 2)) MB"
    Write-Output ""
    
    # Próximos passos
    Write-Info "📋 Próximos passos:"
    Write-Output ""
    Write-Output "1. Testar o instalador:"
    Write-Output "   $installerPath"
    Write-Output ""
    Write-Output "2. Fazer upload para GitHub Releases ou servidor"
    Write-Output ""
    Write-Output "3. Registrar no Supabase:"
    Write-Output "   INSERT INTO app_versions (version, download_url, release_notes, is_mandatory)"
    Write-Output "   VALUES ('$Version', 'URL_DO_INSTALADOR', 'Release notes...', false);"
    Write-Output ""
    
    # Abrir pasta de saída
    if ($OpenOutput) {
        Write-Info "📂 Abrindo pasta de saída..."
        explorer "installer\Output"
    }
    
} else {
    Write-Error "❌ Instalador não foi criado!"
    Write-Output ""
    Write-Output "Verifique os logs acima para mais detalhes."
    exit 1
}

Write-Output ""
Write-Success "🎉 Processo concluído com sucesso!"

