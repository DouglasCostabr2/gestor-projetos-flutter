; Inno Setup Script para My Business
; Gere o instalador com: "C:\Program Files (x86)\Inno Setup 6\ISCC.exe" setup.iss

[Setup]
AppName=My Business
AppVersion=1.1.0
AppPublisher=Douglas Costa
AppPublisherURL=https://github.com/DouglasCostabr2
AppSupportURL=https://github.com/DouglasCostabr2/gestor_projetos_flutter/issues
AppUpdatesURL=https://github.com/DouglasCostabr2/gestor_projetos_flutter/releases
DefaultDirName={autopf}\My Business
DefaultGroupName=My Business
AllowNoIcons=yes
OutputDir=output
OutputBaseFilename=MyBusiness-1.1.0-Setup
Compression=lzma
SolidCompression=yes
PrivilegesRequired=lowest
ArchitecturesInstallIn64BitMode=x64
ArchitecturesAllowed=x64
WizardStyle=modern
UninstallDisplayIcon={app}\gestor_projetos_flutter.exe
LicenseFile=..\..\LICENSE.txt
SetupIconFile=..\runner\resources\app_icon.ico
AppId={{8B5E5F1A-9C3D-4E2B-A1F6-7D8C9E0B1A2F}
VersionInfoVersion=1.1.0
VersionInfoCompany=Douglas Costa
VersionInfoDescription=My Business - Gerenciador de Projetos e Tarefas
VersionInfoCopyright=Copyright (C) 2025 Douglas Costa
VersionInfoProductName=My Business
VersionInfoProductVersion=1.1.0
DisableProgramGroupPage=no
DisableReadyPage=no
DisableWelcomePage=no
CloseApplications=yes
RestartApplications=no
CloseApplicationsFilter=gestor_projetos_flutter.exe

[Languages]
Name: "portuguese"; MessagesFile: "compiler:Languages\Portuguese.isl"
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked
Name: "quicklaunchicon"; Description: "{cm:CreateQuickLaunchIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked; OnlyBelowVersion: 6.1,10.0

[Files]
; Copiar todos os arquivos do build Release
Source: "..\..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\My Business"; Filename: "{app}\gestor_projetos_flutter.exe"; IconIndex: 0
Name: "{group}\{cm:UninstallProgram,My Business}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\My Business"; Filename: "{app}\gestor_projetos_flutter.exe"; Tasks: desktopicon; IconIndex: 0
Name: "{userappdata}\Microsoft\Internet Explorer\Quick Launch\My Business"; Filename: "{app}\gestor_projetos_flutter.exe"; Tasks: quicklaunchicon; IconIndex: 0

[Run]
Filename: "{app}\gestor_projetos_flutter.exe"; Description: "{cm:LaunchProgram,My Business}"; Flags: nowait postinstall skipifsilent

[UninstallDelete]
Type: dirifempty; Name: "{app}"

[Code]
var
  IsUpgrade: Boolean;
  OldVersion: String;

// Verificar se já existe instalação anterior
function InitializeSetup(): Boolean;
var
  UninstallKey: String;
  InstalledVersion: String;
  MsgText: String;
begin
  Result := True;
  IsUpgrade := False;
  
  // Verificar se é 64-bit
  if not Is64BitInstallMode then
  begin
    MsgBox('Este programa requer Windows 64-bit.', mbError, MB_OK);
    Result := False;
    Exit;
  end;
  
  // Verificar se já existe instalação
  UninstallKey := 'Software\Microsoft\Windows\CurrentVersion\Uninstall\{8B5E5F1A-9C3D-4E2B-A1F6-7D8C9E0B1A2F}_is1';
  
  if RegQueryStringValue(HKLM, UninstallKey, 'DisplayVersion', InstalledVersion) or
     RegQueryStringValue(HKCU, UninstallKey, 'DisplayVersion', InstalledVersion) then
  begin
    IsUpgrade := True;
    OldVersion := InstalledVersion;
    
    MsgText := 'My Business versão ' + InstalledVersion + ' já está instalado.' + #13#13 +
               'A instalação irá atualizar para a versão {#SetupSetting("AppVersion")}.' + #13#13 +
               'Deseja continuar?';
    
    if MsgBox(MsgText, mbConfirmation, MB_YESNO) = IDNO then
    begin
      Result := False;
      Exit;
    end;
  end;
end;

// Fechar aplicação se estiver rodando
function PrepareToInstall(var NeedsRestart: Boolean): String;
var
  ResultCode: Integer;
begin
  Result := '';
  
  // Tentar fechar o aplicativo graciosamente
  if CheckForMutexes('MyBusinessMutex') then
  begin
    if MsgBox('My Business está em execução.' + #13#13 +
              'Clique em OK para fechar o aplicativo e continuar a instalação.' + #13 +
              'Clique em Cancelar para abortar a instalação.', 
              mbConfirmation, MB_OKCANCEL) = IDOK then
    begin
      // Tentar fechar via taskkill
      Exec('taskkill.exe', '/F /IM my_business.exe', '', SW_HIDE, ewWaitUntilTerminated, ResultCode);
      Sleep(1000);
    end
    else
    begin
      Result := 'Instalação cancelada pelo usuário.';
    end;
  end;
end;

// Mensagem de conclusão
procedure CurStepChanged(CurStep: TSetupStep);
var
  MsgText: String;
begin
  if CurStep = ssPostInstall then
  begin
    if IsUpgrade then
      MsgText := 'My Business foi atualizado com sucesso!' + #13#13 +
                 'Versão anterior: ' + OldVersion + #13 +
                 'Versão atual: {#SetupSetting("AppVersion")}' + #13#13 +
                 'Clique em Concluir para iniciar o programa.'
    else
      MsgText := 'My Business foi instalado com sucesso!' + #13#13 +
                 'Clique em Concluir para iniciar o programa.';
    
    MsgBox(MsgText, mbInformation, MB_OK);
  end;
end;

