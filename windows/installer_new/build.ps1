# Script para gerar instalador My Business
# Uso: .\build.ps1 -Version "1.1.0" -Type "inno"

param(
    [string]$Version = "1.1.0",
    [string]$Type = "inno"  # "inno" ou "nsis"
)

Write-Host "🚀 Gerando instalador My Business..." -ForegroundColor Green
Write-Host "Versão: $Version" -ForegroundColor Cyan
Write-Host "Tipo: $Type" -ForegroundColor Cyan

# Verificar se o build existe
$buildPath = "..\..\build\windows\x64\runner\Release\gestor_projetos_flutter.exe"
if (-not (Test-Path $buildPath)) {
    Write-Host "❌ Build não encontrado!" -ForegroundColor Red
    Write-Host "Execute primeiro: flutter build windows --release" -ForegroundColor Yellow
    exit 1
}

# Criar diretório de saída
if (-not (Test-Path "output")) {
    New-Item -ItemType Directory -Path "output" | Out-Null
}

if ($Type -eq "inno") {
    Write-Host "`n📝 Compilando com Inno Setup..." -ForegroundColor Yellow
    
    $innoPath = "C:\Program Files (x86)\Inno Setup 6\ISCC.exe"
    if (-not (Test-Path $innoPath)) {
        Write-Host "❌ Inno Setup não encontrado!" -ForegroundColor Red
        Write-Host "Baixe em: https://jrsoftware.org/isdl.php" -ForegroundColor Cyan
        exit 1
    }
    
    & $innoPath "setup.iss"
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "`n✅ Instalador criado com sucesso!" -ForegroundColor Green
        Write-Host "📁 Localização: output\MyBusiness-$Version-Setup.exe" -ForegroundColor Cyan
    } else {
        Write-Host "`n❌ Erro ao criar instalador!" -ForegroundColor Red
        exit 1
    }
}
elseif ($Type -eq "nsis") {
    Write-Host "`n📝 Compilando com NSIS..." -ForegroundColor Yellow
    
    $nsisPath = "C:\Program Files (x86)\NSIS\makensis.exe"
    if (-not (Test-Path $nsisPath)) {
        Write-Host "❌ NSIS não encontrado!" -ForegroundColor Red
        Write-Host "Baixe em: https://nsis.sourceforge.io/" -ForegroundColor Cyan
        exit 1
    }
    
    & $nsisPath "setup.nsi"
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "`n✅ Instalador criado com sucesso!" -ForegroundColor Green
        Write-Host "📁 Localização: output\MyBusiness-$Version-Setup.exe" -ForegroundColor Cyan
    } else {
        Write-Host "`n❌ Erro ao criar instalador!" -ForegroundColor Red
        exit 1
    }
}
else {
    Write-Host "❌ Tipo inválido! Use 'inno' ou 'nsis'" -ForegroundColor Red
    exit 1
}

Write-Host "`n✨ Pronto!" -ForegroundColor Green

