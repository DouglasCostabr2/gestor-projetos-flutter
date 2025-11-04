# 📦 My Business - Instalador Windows

Este diretório contém os arquivos necessários para criar o instalador Windows do My Business.

## 🎯 Visão Geral

O instalador foi desenvolvido com as seguintes características:

- ✅ **Instalação Profissional**: Interface moderna e intuitiva
- ✅ **Detecção de Atualizações**: Identifica versões anteriores automaticamente
- ✅ **Backup de Dados**: Opção de backup antes de atualizar
- ✅ **Verificação de Requisitos**: Valida sistema operacional e espaço em disco
- ✅ **Fechamento Automático**: Fecha o aplicativo se estiver em execução
- ✅ **Associação de Arquivos**: Opção para associar arquivos .mybusiness
- ✅ **Desinstalação Limpa**: Remove todos os arquivos e configurações

## 📋 Requisitos

### Para Criar o Instalador

1. **Flutter SDK** (versão 3.8.1 ou superior)
   - Download: https://flutter.dev/docs/get-started/install/windows

2. **Inno Setup 6** (recomendado) ou **NSIS**
   - Inno Setup: https://jrsoftware.org/isdl.php
   - NSIS: https://nsis.sourceforge.io/

3. **PowerShell 5.1** ou superior (já incluído no Windows 10/11)

### Para Instalar o Aplicativo

- Windows 10 versão 1809 (Build 17763) ou superior
- Sistema operacional 64-bit
- 500 MB de espaço livre em disco

## 🚀 Como Criar o Instalador

### Método 1: Script Automático (Recomendado)

```powershell
# Na raiz do projeto, execute:
.\scripts\build_installer.ps1
```

#### Opções Avançadas

```powershell
# Especificar versão
.\scripts\build_installer.ps1 -Version "1.0.1"

# Usar NSIS em vez de Inno Setup
.\scripts\build_installer.ps1 -InstallerType "nsis"

# Pular compilação (usar build existente)
.\scripts\build_installer.ps1 -SkipBuild

# Fazer limpeza completa antes de compilar
.\scripts\build_installer.ps1 -Clean

# Modo verbose (mostrar detalhes)
.\scripts\build_installer.ps1 -Verbose

# Combinação de opções
.\scripts\build_installer.ps1 -Version "1.0.1" -Clean -Verbose
```

### Método 2: Manual

#### Passo 1: Compilar o Flutter

```powershell
# Limpar builds anteriores
flutter clean

# Compilar versão Release
flutter build windows --release
```

#### Passo 2: Criar o Instalador

**Com Inno Setup:**
```powershell
"C:\Program Files (x86)\Inno Setup 6\ISCC.exe" windows\installer\setup.iss
```

**Com NSIS:**
```powershell
"C:\Program Files (x86)\NSIS\makensis.exe" windows\installer\setup.nsi
```

## 📁 Estrutura de Arquivos

```
windows/installer/
├── setup.iss              # Script Inno Setup (recomendado)
├── setup.nsi              # Script NSIS (alternativa)
├── LICENSE.txt            # Licença do software
├── README.md              # Este arquivo
└── output/                # Instaladores gerados
    ├── MyBusiness-1.0.0-Setup.exe
    └── MyBusiness-1.0.0-Setup.exe.sha256
```

## 🔧 Personalização

### Alterar Versão

Edite o arquivo `setup.iss` (linha 10):

```pascal
#define MyAppVersion "1.0.1"
```

Ou use o parâmetro `-Version` no script:

```powershell
.\scripts\build_installer.ps1 -Version "1.0.1"
```

### Alterar Nome do Aplicativo

Edite o arquivo `setup.iss` (linha 9):

```pascal
#define MyAppName "Meu Aplicativo"
```

### Alterar Ícone

Substitua o arquivo:
```
windows/runner/resources/app_icon.ico
```

### Alterar Licença

Edite o arquivo:
```
LICENSE.txt
```

## 📊 Funcionalidades do Instalador

### Durante a Instalação

1. **Verificação de Requisitos**
   - Windows 10 Build 17763 ou superior
   - Sistema 64-bit
   - Espaço em disco suficiente (500 MB)

2. **Detecção de Versão Anterior**
   - Identifica instalações existentes
   - Oferece atualização automática
   - Preserva dados do usuário

3. **Backup de Dados**
   - Opção de backup antes de atualizar
   - Backup salvo em: `%LOCALAPPDATA%\My Business.backup.YYYYMMDDHHMMSS`

4. **Fechamento Automático**
   - Detecta se o aplicativo está em execução
   - Solicita permissão para fechar
   - Fecha graciosamente ou força fechamento se necessário

5. **Opções de Instalação**
   - Atalho na área de trabalho (opcional)
   - Atalho no menu iniciar (padrão)
   - Associação de arquivos .mybusiness (opcional)

### Após a Instalação

- Aplicativo instalado em: `C:\Program Files\My Business`
- Dados do usuário em: `%LOCALAPPDATA%\My Business`
- Atalhos criados conforme selecionado
- Registro do Windows atualizado

### Durante a Desinstalação

- Remove todos os arquivos do aplicativo
- Remove atalhos
- Remove entradas do registro
- Opção de manter dados do usuário

## 🧪 Testando o Instalador

### Teste Básico

1. Execute o instalador em uma máquina limpa (ou VM)
2. Verifique se o aplicativo inicia corretamente
3. Teste todas as funcionalidades principais
4. Desinstale e verifique se tudo foi removido

### Teste de Atualização

1. Instale uma versão anterior
2. Use o aplicativo e crie alguns dados
3. Execute o instalador da nova versão
4. Verifique se:
   - A atualização foi detectada
   - Os dados foram preservados
   - A nova versão funciona corretamente

### Checklist de Testes

- [ ] Instalação limpa funciona
- [ ] Aplicativo inicia sem erros
- [ ] Todas as funcionalidades estão operacionais
- [ ] Atalhos foram criados corretamente
- [ ] Atualização preserva dados
- [ ] Desinstalação remove tudo (exceto dados do usuário)
- [ ] Instalador funciona em Windows 10
- [ ] Instalador funciona em Windows 11

## 🐛 Solução de Problemas

### Erro: "Flutter não encontrado"

**Solução:**
```powershell
# Adicione o Flutter ao PATH ou especifique o caminho completo
$env:PATH += ";C:\flutter\bin"
```

### Erro: "Inno Setup não encontrado"

**Solução:**
1. Baixe e instale: https://jrsoftware.org/isdl.php
2. Ou use NSIS: `.\scripts\build_installer.ps1 -InstallerType "nsis"`

### Erro: "Executável não encontrado"

**Solução:**
```powershell
# Compile o projeto primeiro
flutter build windows --release
```

### Instalador não inicia

**Possíveis causas:**
1. Windows Defender bloqueando (adicione exceção)
2. Antivírus bloqueando (desative temporariamente)
3. Arquivo corrompido (baixe novamente)

### Aplicativo não inicia após instalação

**Verificações:**
1. Verifique se todas as DLLs foram copiadas
2. Verifique logs em: `%LOCALAPPDATA%\My Business\logs`
3. Execute como administrador (teste)

## 📝 Logs

### Logs de Instalação

Localizados em:
```
%TEMP%\Setup Log YYYY-MM-DD #XXX.txt
```

### Logs do Aplicativo

Localizados em:
```
%LOCALAPPDATA%\My Business\logs\
```

## 🔐 Segurança

### Assinatura Digital (Opcional)

Para assinar o instalador digitalmente:

1. Obtenha um certificado de assinatura de código
2. Use `signtool.exe` do Windows SDK:

```powershell
signtool sign /f "certificado.pfx" /p "senha" /t http://timestamp.digicert.com "MyBusiness-1.0.0-Setup.exe"
```

### Verificação de Hash

O script gera automaticamente um arquivo SHA256:

```powershell
# Verificar hash
$hash = (Get-FileHash -Path "MyBusiness-1.0.0-Setup.exe" -Algorithm SHA256).Hash
Get-Content "MyBusiness-1.0.0-Setup.exe.sha256"
```

## 📚 Recursos Adicionais

- [Documentação Inno Setup](https://jrsoftware.org/ishelp/)
- [Documentação NSIS](https://nsis.sourceforge.io/Docs/)
- [Flutter Windows Desktop](https://docs.flutter.dev/platform-integration/windows/building)
- [Guia de Publicação](../../GUIA_PUBLICACAO_WINDOWS.md)

## 🆘 Suporte

- **Issues**: https://github.com/DouglasCostabr2/gestor_projetos_flutter/issues
- **Documentação**: Veja os arquivos .md na raiz do projeto

## 📄 Licença

Copyright (C) 2025 Douglas Costa

Veja LICENSE.txt para mais detalhes.

