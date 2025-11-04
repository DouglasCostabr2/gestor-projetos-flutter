; Script Inno Setup para My Business
; Este script cria um instalador profissional para Windows
; 
; COMO USAR:
; 1. Instale o Inno Setup: https://jrsoftware.org/isdl.php
; 2. Compile o app: flutter build windows --release
; 3. Abra este arquivo no Inno Setup Compiler
; 4. Clique em "Compile" (F9)
; 5. O instalador será criado em: installer/Output/

#define MyAppName "My Business"
#define MyAppVersion "1.1.0"
#define MyAppPublisher "Sua Empresa"
#define MyAppURL "https://seusite.com"
#define MyAppExeName "gestor_projetos_flutter.exe"

[Setup]
; INFORMAÇÕES BÁSICAS
AppId={{YOUR-UNIQUE-APP-ID-HERE}}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}
AppUpdatesURL={#MyAppURL}

; DIRETÓRIOS
DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}
DisableProgramGroupPage=yes

; SAÍDA
OutputDir=Output
OutputBaseFilename=MyBusiness-Setup-{#MyAppVersion}
SetupIconFile=..\windows\runner\resources\app_icon.ico
Compression=lzma2/max
SolidCompression=yes

; PRIVILÉGIOS
PrivilegesRequired=admin
PrivilegesRequiredOverridesAllowed=dialog

; INTERFACE
WizardStyle=modern
WizardImageFile=compiler:WizModernImage-IS.bmp
WizardSmallImageFile=compiler:WizModernSmallImage-IS.bmp

; IDIOMA
ShowLanguageDialog=no

; DESINSTALAÇÃO
UninstallDisplayIcon={app}\{#MyAppExeName}

; ARQUITETURA
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible

[Languages]
Name: "brazilianportuguese"; MessagesFile: "compiler:Languages\BrazilianPortuguese.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
; ARQUIVOS DO APLICATIVO
Source: "..\build\windows\x64\runner\Release\{#MyAppExeName}"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

; NOTA: Não use "Flags: ignoreversion" em arquivos compartilhados do sistema

[Icons]
; ÍCONES DO MENU INICIAR
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{group}\{cm:UninstallProgram,{#MyAppName}}"; Filename: "{uninstallexe}"

; ÍCONE DA ÁREA DE TRABALHO
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
; EXECUTAR APÓS INSTALAÇÃO
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent

[Code]
// CÓDIGO PASCAL PARA LÓGICA CUSTOMIZADA

// Verificar se o app está rodando antes de instalar
function InitializeSetup(): Boolean;
var
  ResultCode: Integer;
begin
  // Tentar fechar o app se estiver rodando
  if CheckForMutexes('MyBusinessAppMutex') then
  begin
    if MsgBox('O My Business está em execução. Deseja fechá-lo e continuar a instalação?', 
              mbConfirmation, MB_YESNO) = IDYES then
    begin
      // Tentar fechar graciosamente
      Exec('taskkill', '/F /IM {#MyAppExeName}', '', SW_HIDE, ewWaitUntilTerminated, ResultCode);
      Sleep(1000);
    end
    else
    begin
      Result := False;
      Exit;
    end;
  end;
  Result := True;
end;

// Verificar se há versão anterior instalada
function InitializeUninstall(): Boolean;
begin
  Result := True;
  if MsgBox('Deseja realmente desinstalar o My Business?', mbConfirmation, MB_YESNO) = IDNO then
    Result := False;
end;

// Limpar dados do usuário (opcional)
procedure CurUninstallStepChanged(CurUninstallStep: TUninstallStep);
var
  AppDataPath: String;
begin
  if CurUninstallStep = usPostUninstall then
  begin
    // Perguntar se deseja remover dados do usuário
    if MsgBox('Deseja remover também os dados do aplicativo (configurações, cache, etc.)?', 
              mbConfirmation, MB_YESNO) = IDYES then
    begin
      AppDataPath := ExpandConstant('{localappdata}\my_business');
      if DirExists(AppDataPath) then
        DelTree(AppDataPath, True, True, True);
    end;
  end;
end;

[UninstallDelete]
; ARQUIVOS PARA DELETAR NA DESINSTALAÇÃO
Type: filesandordirs; Name: "{app}\data"
Type: filesandordirs; Name: "{app}\cache"

