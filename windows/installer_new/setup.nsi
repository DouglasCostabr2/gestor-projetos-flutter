; NSIS Script para My Business
; Compile com: "C:\Program Files (x86)\NSIS\makensis.exe" setup.nsi

!include "MUI2.nsh"
!include "x64.nsh"

; Configurações básicas
Name "My Business"
OutFile "output\MyBusiness-1.1.0-Setup.exe"
InstallDir "$PROGRAMFILES64\My Business"
InstallDirRegKey HKCU "Software\My Business" ""

; Variáveis
Var StartMenuFolder

; Interface
!insertmacro MUI_PAGE_WELCOME
!insertmacro MUI_PAGE_DIRECTORY
!insertmacro MUI_PAGE_STARTMENU "Application" $StartMenuFolder
!insertmacro MUI_PAGE_INSTFILES
!insertmacro MUI_PAGE_FINISH

!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_INSTFILES

; Idioma
!insertmacro MUI_LANGUAGE "PortugueseBR"
!insertmacro MUI_LANGUAGE "English"

; Versão
VIProductVersion "1.1.0.0"
VIAddVersionKey /LANG=${LANG_PORTUGUESE} "ProductName" "My Business"
VIAddVersionKey /LANG=${LANG_PORTUGUESE} "CompanyName" "Douglas Costa"
VIAddVersionKey /LANG=${LANG_PORTUGUESE} "FileVersion" "1.1.0"
VIAddVersionKey /LANG=${LANG_PORTUGUESE} "ProductVersion" "1.1.0"
VIAddVersionKey /LANG=${LANG_PORTUGUESE} "FileDescription" "My Business - Gerenciador de Projetos e Tarefas"
VIAddVersionKey /LANG=${LANG_PORTUGUESE} "LegalCopyright" "Copyright (C) 2025 Douglas Costa"

; Variáveis globais
Var IsUpgrade
Var OldVersion

; Seção de instalação
Section "Instalar"
  SetOutPath "$INSTDIR"
  
  ; Se for atualização, remover arquivos antigos primeiro
  ${If} $IsUpgrade == "1"
    DetailPrint "Removendo arquivos da versão anterior..."
    RMDir /r "$INSTDIR\data"
    Delete "$INSTDIR\*.dll"
    Delete "$INSTDIR\*.exe"
  ${EndIf}
  
  ; Copiar arquivos do build Release (sobrescrever sempre)
  SetOverwrite on
  File /r "..\..\build\windows\x64\runner\Release\*.*"
  
  ; Criar atalhos no Menu Iniciar
  !insertmacro MUI_STARTMENU_WRITE_BEGIN Application
    CreateDirectory "$SMPROGRAMS\$StartMenuFolder"
    CreateShortcut "$SMPROGRAMS\$StartMenuFolder\My Business.lnk" "$INSTDIR\gestor_projetos_flutter.exe"
    CreateShortcut "$SMPROGRAMS\$StartMenuFolder\Desinstalar.lnk" "$INSTDIR\uninstall.exe"
  !insertmacro MUI_STARTMENU_WRITE_END

  ; Criar atalho na Área de Trabalho
  CreateShortcut "$DESKTOP\My Business.lnk" "$INSTDIR\gestor_projetos_flutter.exe"

  ; Registrar no Windows
  WriteRegStr HKCU "Software\My Business" "" "$INSTDIR"
  WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\My Business" "DisplayName" "My Business"
  WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\My Business" "UninstallString" "$INSTDIR\uninstall.exe"
  WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\My Business" "DisplayIcon" "$INSTDIR\gestor_projetos_flutter.exe"
  WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\My Business" "DisplayVersion" "1.1.0"
  WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\My Business" "Publisher" "Douglas Costa"
  WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\My Business" "InstallLocation" "$INSTDIR"

  ; Criar desinstalador
  WriteUninstaller "$INSTDIR\uninstall.exe"

  ; Mensagem de conclusão
  ${If} $IsUpgrade == "1"
    MessageBox MB_OK "My Business foi atualizado com sucesso!$\r$\n$\r$\nVersão anterior: $OldVersion$\r$\nVersão atual: 1.1.0"
  ${Else}
    MessageBox MB_OK "My Business foi instalado com sucesso!"
  ${EndIf}
SectionEnd

; Seção de desinstalação
Section "Uninstall"
  ; Remover atalhos
  !insertmacro MUI_STARTMENU_GETFOLDER Application $StartMenuFolder
  RMDir /r "$SMPROGRAMS\$StartMenuFolder"
  Delete "$DESKTOP\My Business.lnk"

  ; Remover arquivos
  RMDir /r "$INSTDIR"

  ; Remover registro
  DeleteRegKey HKCU "Software\My Business"
  DeleteRegKey HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\My Business"
SectionEnd

; Função de inicialização
Function .onInit
  ; Verificar se é 64-bit
  ${If} ${RunningX64}
    SetRegView 64
  ${Else}
    MessageBox MB_OK "Este programa requer Windows 64-bit."
    Quit
  ${EndIf}
  
  ; Verificar se já existe instalação anterior
  StrCpy $IsUpgrade "0"
  ReadRegStr $OldVersion HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\My Business" "DisplayVersion"
  
  ${If} $OldVersion != ""
    StrCpy $IsUpgrade "1"
    MessageBox MB_YESNO "My Business versão $OldVersion já está instalado.$\r$\n$\r$\nA instalação irá atualizar para a versão 1.0.0.$\r$\n$\r$\nDeseja continuar?" IDYES continue
    Quit
    continue:
  ${EndIf}
  
  ; Fechar aplicação se estiver rodando
  FindWindow $0 "" "My Business"
  ${If} $0 != 0
    MessageBox MB_OKCANCEL "My Business está em execução.$\r$\n$\r$\nClique em OK para fechar o aplicativo e continuar.$\r$\nClique em Cancelar para abortar a instalação." IDOK closeapp
    Quit
    closeapp:
    nsExec::Exec 'taskkill /F /IM my_business.exe'
    Sleep 1000
  ${EndIf}
FunctionEnd

