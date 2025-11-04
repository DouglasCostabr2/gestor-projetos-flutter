# Quick Release - Script Simplificado
# Para releases rápidos sem muitas opções

param(
    [Parameter(Mandatory=$true)]
    [string]$Version
)

Write-Host ""
Write-Host "🚀 Quick Release - My Business v$Version" -ForegroundColor Cyan
Write-Host ""

# Executar script principal
.\scripts\create-release.ps1 -Version $Version

# Se o release foi criado com sucesso, perguntar sobre Supabase
if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    $updateSupabase = Read-Host "Deseja atualizar o Supabase agora? (s/N)"
    
    if ($updateSupabase -eq 's' -or $updateSupabase -eq 'S') {
        $downloadUrl = "https://github.com/DouglasCostabr2/gestor-projetos-flutter/releases/download/v$Version/MyBusiness-Setup-$Version.exe"
        
        Write-Host ""
        Write-Host "📊 Configurações da atualização:" -ForegroundColor Cyan
        $mandatory = Read-Host "A atualização é obrigatória? (s/N)"
        $isMandatory = ($mandatory -eq 's' -or $mandatory -eq 'S')
        
        Write-Host ""
        .\scripts\update-supabase-version.ps1 `
            -Version $Version `
            -DownloadUrl $downloadUrl `
            -IsMandatory $isMandatory
    }
}

Write-Host ""
Write-Host "✅ Processo concluído!" -ForegroundColor Green
Write-Host ""

