# Guia Completo: Publicar seu Programa Flutter como Instalador Windows

## 📋 Visão Geral
Este guia mostra como criar um instalador profissional (.exe) para seu programa Flutter no Windows.

## 🎯 Opções Disponíveis

### Opção 1: INNO Setup (Recomendado - Mais Fácil)
**Vantagens:**
- Interface gráfica intuitiva
- Suporta atalhos, registro do Windows, desinstalação
- Gratuito e open-source
- Muito usado em aplicações Windows

**Desvantagens:**
- Requer instalação do Inno Setup

### Opção 2: NSIS (Advanced Installer)
**Vantagens:**
- Muito leve
- Altamente customizável
- Suporta scripts complexos

**Desvantagens:**
- Curva de aprendizado maior

### Opção 3: MSI (Windows Installer)
**Vantagens:**
- Padrão Windows nativo
- Integração com Windows Update

**Desvantagens:**
- Mais complexo de configurar

---

## 🚀 PASSO A PASSO: Usando INNO SETUP (Recomendado)

### Passo 1: Preparar o Build Release

```bash
# 1. Limpar builds anteriores
flutter clean

# 2. Compilar versão Release
flutter build windows --release

# 3. Verificar o executável gerado
# Localização: build\windows\x64\runner\Release\gestor_projetos_flutter.exe
```

### Passo 2: Instalar Inno Setup

1. Baixe em: https://jrsoftware.org/isdl.php
2. Instale a versão mais recente
3. Escolha "Install Inno Setup" (versão completa)

### Passo 3: Criar Script Inno Setup

Crie o arquivo `windows/installer/setup.iss`:

```ini
[Setup]
AppName=Gestor de Projetos
AppVersion=1.0.0
AppPublisher=Seu Nome/Empresa
AppPublisherURL=https://seu-site.com
AppSupportURL=https://seu-site.com/suporte
AppUpdatesURL=https://seu-site.com/atualizacoes
DefaultDirName={autopf}\Gestor de Projetos
DefaultGroupName=Gestor de Projetos
AllowNoIcons=yes
OutputDir=output
OutputBaseFilename=GestorProjetos-1.0.0-Setup
Compression=lzma
SolidCompression=yes
PrivilegesRequired=lowest
ArchitecturesInstallIn64BitMode=x64

[Languages]
Name: "portuguese"; MessagesFile: "compiler:Languages\Portuguese.isl"
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
Source: "..\..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\Gestor de Projetos"; Filename: "{app}\gestor_projetos_flutter.exe"
Name: "{group}\{cm:UninstallProgram,Gestor de Projetos}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\Gestor de Projetos"; Filename: "{app}\gestor_projetos_flutter.exe"; Tasks: desktopicon

[Run]
Filename: "{app}\gestor_projetos_flutter.exe"; Description: "{cm:LaunchProgram,Gestor de Projetos}"; Flags: nowait postinstall skipifsilent
```

### Passo 4: Compilar o Instalador

1. Abra o Inno Setup Compiler
2. Arquivo → Abrir → Selecione `windows/installer/setup.iss`
3. Clique em "Compile"
4. O instalador será gerado em `windows/installer/output/`

---

## 📦 PASSO A PASSO: Usando NSIS (Alternativa)

### Passo 1: Instalar NSIS

Baixe em: https://nsis.sourceforge.io/

### Passo 2: Criar Script NSIS

Crie `windows/installer/setup.nsi`:

```nsis
!include "MUI2.nsh"

Name "Gestor de Projetos"
OutFile "output\GestorProjetos-1.0.0-Setup.exe"
InstallDir "$PROGRAMFILES64\Gestor de Projetos"

!insertmacro MUI_PAGE_DIRECTORY
!insertmacro MUI_PAGE_INSTFILES
!insertmacro MUI_LANGUAGE "PortugueseBR"

Section "Install"
  SetOutPath "$INSTDIR"
  File /r "..\..\build\windows\x64\runner\Release\*.*"
  CreateDirectory "$SMPROGRAMS\Gestor de Projetos"
  CreateShortcut "$SMPROGRAMS\Gestor de Projetos\Gestor de Projetos.lnk" "$INSTDIR\gestor_projetos_flutter.exe"
  CreateShortcut "$DESKTOP\Gestor de Projetos.lnk" "$INSTDIR\gestor_projetos_flutter.exe"
SectionEnd

Section "Uninstall"
  RMDir /r "$INSTDIR"
  RMDir /r "$SMPROGRAMS\Gestor de Projetos"
  Delete "$DESKTOP\Gestor de Projetos.lnk"
SectionEnd
```

### Passo 3: Compilar

```bash
# No prompt de comando
"C:\Program Files (x86)\NSIS\makensis.exe" windows/installer/setup.nsi
```

---

## 🔧 Configurações Recomendadas

### Atualizar Informações do Programa

Edite `windows/runner/Runner.rc`:

```rc
VALUE "CompanyName", "Seu Nome/Empresa"
VALUE "FileDescription", "Gestor de Projetos - Gerenciamento Profissional"
VALUE "LegalCopyright", "Copyright (C) 2025 Seu Nome. Todos os direitos reservados."
```

### Adicionar Ícone Personalizado

1. Crie um ícone 256x256 em `.ico`
2. Coloque em `windows/runner/resources/app_icon.ico`
3. Recompile com `flutter build windows --release`

---

## 📊 Comparação de Métodos

| Aspecto | INNO Setup | NSIS | MSI |
|--------|-----------|------|-----|
| Facilidade | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐ |
| Tamanho | Médio | Pequeno | Médio |
| Customização | Boa | Excelente | Boa |
| Suporte | Excelente | Bom | Nativo |
| Recomendado | ✅ | ✅ | ❌ |

---

## 🎁 Próximos Passos

1. **Assinatura Digital**: Assine o .exe com certificado para evitar avisos
2. **Versionamento**: Atualize `pubspec.yaml` e `Runner.rc` a cada release
3. **Distribuição**: Hospede em GitHub Releases, seu site, ou plataformas como SourceForge
4. **Atualizações**: Implemente sistema de auto-atualização (ex: Sparkle)

---

## ⚠️ Dicas Importantes

- ✅ Sempre compile em **Release** para melhor performance
- ✅ Teste o instalador em uma VM antes de publicar
- ✅ Inclua arquivo README com requisitos do sistema
- ✅ Mantenha histórico de versões
- ❌ Não distribua versão Debug (muito grande e lenta)


