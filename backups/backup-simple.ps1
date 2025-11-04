# Script de Backup Simplificado
# Data: 2025-10-31

$timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$backupDir = "backups\backup-$timestamp"

Write-Host "Criando backup em: $backupDir" -ForegroundColor Cyan

# Criar diretorio
New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
New-Item -ItemType Directory -Path "$backupDir\migrations" -Force | Out-Null

# Copiar migrations
if (Test-Path "supabase\migrations") {
    Copy-Item -Path "supabase\migrations\*" -Destination "$backupDir\migrations\" -Force
    Write-Host "OK - Migrations copiadas" -ForegroundColor Green
}

# Copiar documentacao
if (Test-Path "backups\pre-multitenancy-backup-2025-10-31.md") {
    Copy-Item -Path "backups\pre-multitenancy-backup-2025-10-31.md" -Destination "$backupDir\" -Force
    Write-Host "OK - Documentacao copiada" -ForegroundColor Green
}

# Criar arquivo de info
$info = "BACKUP CRIADO EM: $(Get-Date)`n`n"
$info += "Backup local criado com sucesso!`n`n"
$info += "PROXIMO PASSO OBRIGATORIO:`n"
$info += "Acesse: https://supabase.com/dashboard/project/zfgsddweabsemxcchxjq/database/backups`n"
$info += "Clique em 'Create Backup' ou 'Download Backup'`n"
$info += "Salve o arquivo .sql neste diretorio`n"

$info | Out-File -FilePath "$backupDir\README.txt" -Encoding UTF8

Write-Host "`nBackup local concluido!" -ForegroundColor Green
Write-Host "Localizacao: $backupDir" -ForegroundColor White
Write-Host "`nAbrindo Supabase Dashboard..." -ForegroundColor Yellow

Start-Process "https://supabase.com/dashboard/project/zfgsddweabsemxcchxjq/database/backups"

