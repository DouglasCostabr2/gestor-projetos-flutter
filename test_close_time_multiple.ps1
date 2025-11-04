# Script para testar o tempo de fechamento do app múltiplas vezes
$times = @()

Write-Host "Testando tempo de fechamento 5 vezes..." -ForegroundColor Cyan
Write-Host ""

for ($i = 1; $i -le 5; $i++) {
    Write-Host "Teste $i/5:" -ForegroundColor Yellow
    
    $process = Start-Process -FilePath ".\build\windows\x64\runner\Release\gestor_projetos_flutter.exe" -PassThru
    Start-Sleep -Seconds 3
    
    $startTime = Get-Date
    Stop-Process -Id $process.Id -Force
    Wait-Process -Id $process.Id -ErrorAction SilentlyContinue
    $endTime = Get-Date
    
    $duration = ($endTime - $startTime).TotalSeconds
    $times += $duration
    
    Write-Host "  Tempo: $duration segundos" -ForegroundColor Green
    Start-Sleep -Seconds 1
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Resultados:" -ForegroundColor Cyan
Write-Host "  Média: $(($times | Measure-Object -Average).Average) segundos" -ForegroundColor Green
Write-Host "  Mínimo: $(($times | Measure-Object -Minimum).Minimum) segundos" -ForegroundColor Green
Write-Host "  Máximo: $(($times | Measure-Object -Maximum).Maximum) segundos" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan

