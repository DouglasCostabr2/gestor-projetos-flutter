# 🔒 Script de Backup Automático - Pré Multi-Tenancy
# Data: 2025-10-31
# Projeto: Gestor de Projetos Flutter

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  BACKUP PRÉ-IMPLEMENTAÇÃO MULTI-TENANCY" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$backupDir = "backups\backup-$timestamp"

# Criar diretório de backup
Write-Host "📁 Criando diretório de backup..." -ForegroundColor Yellow
New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
Write-Host "✅ Diretório criado: $backupDir" -ForegroundColor Green
Write-Host ""

# Copiar migrations existentes
Write-Host "📋 Copiando migrations existentes..." -ForegroundColor Yellow
if (Test-Path "supabase\migrations") {
    Copy-Item -Path "supabase\migrations\*" -Destination "$backupDir\migrations" -Recurse -Force
    Write-Host "✅ Migrations copiadas" -ForegroundColor Green
} else {
    Write-Host "⚠️  Pasta de migrations não encontrada" -ForegroundColor Yellow
}
Write-Host ""

# Criar arquivo de informações do backup
Write-Host "📝 Criando arquivo de informações..." -ForegroundColor Yellow
$infoContent = "# BACKUP INFORMATION`n"
$infoContent += "Date: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')`n"
$infoContent += "Project: Gestor de Projetos Flutter`n"
$infoContent += "Supabase Project ID: zfgsddweabsemxcchxjq`n"
$infoContent += "Reason: Pre-Multi-Tenancy Implementation Backup`n`n"
$infoContent += "## What's Included:`n"
$infoContent += "* Database migrations (SQL files)`n"
$infoContent += "* Backup documentation`n"
$infoContent += "* Restoration instructions`n`n"
$infoContent += "## What's NOT Included - Manual Backup Required:`n"
$infoContent += "* Database data - records`n"
$infoContent += "* Supabase Storage files - avatars, briefings, attachments`n"
$infoContent += "* RLS Policies - need to be exported manually`n`n"
$infoContent += "## To Complete the Backup:`n`n"
$infoContent += "### 1. Database Data Backup`n"
$infoContent += "Access Supabase Dashboard:`n"
$infoContent += "https://supabase.com/dashboard/project/zfgsddweabsemxcchxjq/database/backups`n`n"
$infoContent += "Click 'Create Backup' or 'Download Backup'`n`n"
$infoContent += "### 2. Storage Backup`n"
$infoContent += "Access Supabase Dashboard:`n"
$infoContent += "https://supabase.com/dashboard/project/zfgsddweabsemxcchxjq/storage/buckets`n`n"
$infoContent += "Download files from buckets:`n"
$infoContent += "* avatars`n"
$infoContent += "* briefings`n"
$infoContent += "* task-attachments`n"
$infoContent += "* products`n"
$infoContent += "* packages`n`n"
$infoContent += "### 3. RLS Policies Backup`n"
$infoContent += "Run in SQL Editor and save results`n`n"
$infoContent += "## Restoration Instructions:`n"
$infoContent += "See: pre-multitenancy-backup-2025-10-31.md`n"

$infoContent | Out-File -FilePath "$backupDir\BACKUP_INFO.txt" -Encoding UTF8
Write-Host "✅ Arquivo de informações criado" -ForegroundColor Green
Write-Host ""

# Copiar documentação de backup
Write-Host "📄 Copiando documentação..." -ForegroundColor Yellow
if (Test-Path "backups\pre-multitenancy-backup-2025-10-31.md") {
    Copy-Item -Path "backups\pre-multitenancy-backup-2025-10-31.md" -Destination "$backupDir\" -Force
    Write-Host "✅ Documentação copiada" -ForegroundColor Green
} else {
    Write-Host "⚠️  Documentação não encontrada" -ForegroundColor Yellow
}
Write-Host ""

# Criar arquivo de contagem de tabelas (para referência futura)
Write-Host "📊 Criando arquivo de referência de tabelas..." -ForegroundColor Yellow
$tablesContent = "# Database Tables Reference`n"
$tablesContent += "# Date: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')`n`n"
$tablesContent += "## Tables in Database (35 total):`n`n"
$tablesContent += "1. catalog_categories`n"
$tablesContent += "2. client_categories`n"
$tablesContent += "3. client_mentions`n"
$tablesContent += "4. clients`n"
$tablesContent += "5. comment_mentions`n"
$tablesContent += "6. companies`n"
$tablesContent += "7. company_mentions`n"
$tablesContent += "8. employee_payments`n"
$tablesContent += "9. notifications`n"
$tablesContent += "10. organization_settings`n"
$tablesContent += "11. package_items`n"
$tablesContent += "12. package_mentions`n"
$tablesContent += "13. packages`n"
$tablesContent += "14. payments`n"
$tablesContent += "15. product_mentions`n"
$tablesContent += "16. products`n"
$tablesContent += "17. profiles`n"
$tablesContent += "18. project_additional_costs`n"
$tablesContent += "19. project_catalog_items`n"
$tablesContent += "20. project_discounts`n"
$tablesContent += "21. project_members`n"
$tablesContent += "22. project_mentions`n"
$tablesContent += "23. project_package_item_comments`n"
$tablesContent += "24. projects`n"
$tablesContent += "25. shared_oauth_tokens`n"
$tablesContent += "26. task_attachments`n"
$tablesContent += "27. task_comments`n"
$tablesContent += "28. task_files`n"
$tablesContent += "29. task_history`n"
$tablesContent += "30. task_mentions`n"
$tablesContent += "31. task_products`n"
$tablesContent += "32. tasks`n"
$tablesContent += "33. time_logs`n"
$tablesContent += "34. user_favorites`n"
$tablesContent += "35. user_oauth_tokens`n`n"
$tablesContent += "## Tables That Will Receive organization_id Column:`n`n"
$tablesContent += "* clients`n"
$tablesContent += "* projects`n"
$tablesContent += "* tasks`n"
$tablesContent += "* products`n"
$tablesContent += "* packages`n"
$tablesContent += "* catalog_categories`n"
$tablesContent += "* client_categories`n"
$tablesContent += "* payments`n"
$tablesContent += "* employee_payments`n"
$tablesContent += "* notifications`n"
$tablesContent += "* user_favorites`n"
$tablesContent += "* shared_oauth_tokens`n"
$tablesContent += "* user_oauth_tokens`n`n"
$tablesContent += "## New Tables to be Created:`n`n"
$tablesContent += "* organizations`n"
$tablesContent += "* organization_members`n"
$tablesContent += "* organization_invites`n"

$tablesContent | Out-File -FilePath "$backupDir\TABLES_REFERENCE.txt" -Encoding UTF8
Write-Host "✅ Arquivo de referência criado" -ForegroundColor Green
Write-Host ""

# Resumo final
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  BACKUP LOCAL CONCLUÍDO" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "📁 Localização: $backupDir" -ForegroundColor White
Write-Host ""
Write-Host "⚠️  ATENÇÃO: Este backup contém apenas:" -ForegroundColor Yellow
Write-Host "   ✅ Migrations SQL" -ForegroundColor White
Write-Host "   ✅ Documentação" -ForegroundColor White
Write-Host "   ✅ Referências de tabelas" -ForegroundColor White
Write-Host ""
Write-Host "❌ NÃO INCLUÍDO (requer backup manual):" -ForegroundColor Red
Write-Host "   ⚠️  Dados do banco (registros)" -ForegroundColor Yellow
Write-Host "   ⚠️  Arquivos do Storage" -ForegroundColor Yellow
Write-Host "   ⚠️  RLS Policies" -ForegroundColor Yellow
Write-Host ""
Write-Host "📋 PRÓXIMOS PASSOS OBRIGATÓRIOS:" -ForegroundColor Cyan
Write-Host ""
Write-Host "1. Acesse o Supabase Dashboard:" -ForegroundColor White
Write-Host "   https://supabase.com/dashboard/project/zfgsddweabsemxcchxjq" -ForegroundColor Gray
Write-Host ""
Write-Host "2. Vá em Database → Backups" -ForegroundColor White
Write-Host "   Clique em 'Create Backup' ou 'Download Backup'" -ForegroundColor Gray
Write-Host ""
Write-Host "3. Salve o arquivo .sql no diretório:" -ForegroundColor White
Write-Host "   $backupDir" -ForegroundColor Gray
Write-Host ""
Write-Host "4. (Opcional) Faça backup do Storage:" -ForegroundColor White
Write-Host "   Database → Storage → Download buckets" -ForegroundColor Gray
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Pressione qualquer tecla para abrir o Supabase Dashboard..." -ForegroundColor Yellow
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")

# Abrir Supabase Dashboard
Start-Process "https://supabase.com/dashboard/project/zfgsddweabsemxcchxjq/database/backups"

Write-Host ""
Write-Host "✅ Dashboard aberto no navegador!" -ForegroundColor Green
Write-Host ""

