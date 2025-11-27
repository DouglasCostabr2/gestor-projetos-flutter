@echo off
echo ========================================
echo PUBLICACAO MY BUSINESS v1.1.14
echo ========================================
echo.

echo [1/6] Limpando projeto...
call flutter clean
if %errorlevel% neq 0 goto :error

echo.
echo [2/6] Baixando dependencias...
call flutter pub get
if %errorlevel% neq 0 goto :error

echo.
echo [3/6] Compilando Release (isso pode levar 5-10 minutos)...
call flutter build windows --release
if %errorlevel% neq 0 goto :error

echo.
echo [4/6] Criando instalador com Inno Setup...
"C:\Program Files (x86)\Inno Setup 6\ISCC.exe" "installer\setup.iss"
if %errorlevel% neq 0 goto :error

echo.
echo [5/6] Fazendo commit das alteracoes...
git add pubspec.yaml installer/setup.iss
git commit -m "chore: bump version to 1.1.14"
git push origin master
if %errorlevel% neq 0 (
    echo Tentando push para main...
    git push origin main
)

echo.
echo [6/6] Criando tag e enviando para GitHub...
git tag -a "v1.1.14" -m "Release version 1.1.14"
git push origin v1.1.14

echo.
echo ========================================
echo BUILD CONCLUIDO COM SUCESSO!
echo ========================================
echo.
echo Instalador criado em: installer\Output\MyBusiness-Setup-1.1.14.exe
echo.
echo Proximos passos:
echo 1. Criar GitHub Release manualmente ou executar:
echo    gh release create "v1.1.14" --title "My Business v1.1.14" --notes "Release 1.1.14" "installer\Output\MyBusiness-Setup-1.1.14.exe"
echo.
echo 2. Atualizar Supabase (veja arquivo QUERY_SUPABASE_v1.1.14.sql)
echo.
pause
goto :end

:error
echo.
echo ========================================
echo ERRO! O processo foi interrompido.
echo ========================================
pause
exit /b 1

:end
