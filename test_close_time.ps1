# Script para testar o tempo de fechamento do app
Write-Host "Iniciando app..." -ForegroundColor Cyan

$process = Start-Process -FilePath ".\build\windows\x64\runner\Release\gestor_projetos_flutter.exe" -PassThru
Write-Host "App iniciado com PID: $($process.Id)" -ForegroundColor Green

Write-Host "Aguardando 5 segundos para o app carregar..." -ForegroundColor Yellow
Start-Sleep -Seconds 5

Write-Host "Fechando app..." -ForegroundColor Cyan
$startTime = Get-Date

# Fechar o processo
Stop-Process -Id $process.Id -Force

# Aguardar o processo terminar
Wait-Process -Id $process.Id -ErrorAction SilentlyContinue

$endTime = Get-Date
$duration = ($endTime - $startTime).TotalSeconds

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "Tempo para fechar: $duration segundos" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green

