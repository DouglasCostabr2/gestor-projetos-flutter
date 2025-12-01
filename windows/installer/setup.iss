; ============================================================================
; Inno Setup Script para My Business
; Gerenciador de Projetos e Tarefas Profissional
; ============================================================================
; Gere o instalador com: "C:\Program Files (x86)\Inno Setup 6\ISCC.exe" setup.iss
; Ou use o script: .\scripts\build_installer.ps1

#define MyAppName "My Business"
#define MyAppVersion "1.1.15"
#define MyAppPublisher "Douglas Costa"
#define MyAppURL "https://github.com/DouglasCostabr2"
#define MyAppExeName "gestor_projetos_flutter.exe"
#define MyAppId "8B5E5F1A-9C3D-4E2B-A1F6-7D8C9E0B1A2F"
#define MyAppDescription "Gerenciador Profissional de Projetos e Tarefas"

[Setup]
; Informações básicas do aplicativo
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}/gestor_projetos_flutter/issues
AppUpdatesURL={#MyAppURL}/gestor_projetos_flutter/releases
AppId={{{#MyAppId}}

; Diretórios de instalação
DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}
DisableProgramGroupPage=no

; Saída do instalador
OutputDir=output
OutputBaseFilename=MyBusiness-{#MyAppVersion}-Setup
SetupIconFile=..\runner\resources\app_icon.ico

; Compressão
Compression=lzma2/ultra64
SolidCompression=yes
LZMAUseSeparateProcess=yes
LZMANumBlockThreads=2

; Requisitos do sistema
PrivilegesRequired=lowest
ArchitecturesInstallIn64BitMode=x64
ArchitecturesAllowed=x64
MinVersion=10.0.17763

; Informações de versão
VersionInfoVersion={#MyAppVersion}.0
VersionInfoCompany={#MyAppPublisher}
VersionInfoDescription={#MyAppDescription}
VersionInfoCopyright=Copyright (C) 2025 {#MyAppPublisher}
VersionInfoProductName={#MyAppName}
VersionInfoProductVersion={#MyAppVersion}.0
VersionInfoTextVersion={#MyAppVersion}

; Interface do instalador
WizardStyle=modern
WizardSizePercent=120
DisableWelcomePage=no
DisableReadyPage=no
AllowNoIcons=yes
UninstallDisplayIcon={app}\{#MyAppExeName}
UninstallDisplayName={#MyAppName}

; Licença
LicenseFile=..\..\LICENSE.txt

; Comportamento durante instalação
CloseApplications=force
RestartApplications=no
CloseApplicationsFilter={#MyAppExeName}
AlwaysRestart=no

; Logs e segurança
SetupLogging=yes
SignedUninstaller=no

[Languages]
Name: "portuguese"; MessagesFile: "compiler:Languages\Portuguese.isl"
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "Criar atalho na Área de Trabalho"; GroupDescription: "Atalhos adicionais:"; Flags: unchecked
Name: "quicklaunchicon"; Description: "Criar atalho na Barra de Inicialização Rápida"; GroupDescription: "Atalhos adicionais:"; Flags: unchecked; OnlyBelowVersion: 6.1,10.0
Name: "associatefiles"; Description: "Associar arquivos .mybusiness com {#MyAppName}"; GroupDescription: "Associações de arquivo:"; Flags: unchecked
Name: "startupicon"; Description: "Iniciar {#MyAppName} automaticamente com o Windows"; GroupDescription: "Opções de inicialização:"; Flags: unchecked

[Files]
; Arquivos principais do aplicativo
Source: "..\..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs
; Documentação
Source: "..\..\LICENSE.txt"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\..\README.md"; DestDir: "{app}"; Flags: ignoreversion skipifsourcedoesntexist

[Icons]
; Menu Iniciar
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Comment: "{#MyAppDescription}"
Name: "{group}\Desinstalar {#MyAppName}"; Filename: "{uninstallexe}"; Comment: "Remover {#MyAppName} do computador"
; Desktop
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Comment: "{#MyAppDescription}"; Tasks: desktopicon
; Quick Launch (Windows 7 e anterior)
Name: "{userappdata}\Microsoft\Internet Explorer\Quick Launch\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: quicklaunchicon
; Startup (inicialização automática)
Name: "{userstartup}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: startupicon; Comment: "Iniciar {#MyAppName} automaticamente"

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "Iniciar {#MyAppName} agora"; Flags: nowait postinstall skipifsilent unchecked

[UninstallDelete]
; Limpar diretórios vazios
Type: dirifempty; Name: "{app}"
; Limpar logs se existirem
Type: filesandordirs; Name: "{localappdata}\{#MyAppName}\logs"

[Registry]
; Associação de arquivos (se selecionado)
Root: HKCU; Subkey: "Software\Classes\.mybusiness"; ValueType: string; ValueName: ""; ValueData: "MyBusinessFile"; Flags: uninsdeletevalue; Tasks: associatefiles
Root: HKCU; Subkey: "Software\Classes\MyBusinessFile"; ValueType: string; ValueName: ""; ValueData: "{#MyAppName} File"; Flags: uninsdeletekey; Tasks: associatefiles
Root: HKCU; Subkey: "Software\Classes\MyBusinessFile\DefaultIcon"; ValueType: string; ValueName: ""; ValueData: "{app}\{#MyAppExeName},0"; Tasks: associatefiles
Root: HKCU; Subkey: "Software\Classes\MyBusinessFile\shell\open\command"; ValueType: string; ValueName: ""; ValueData: """{app}\{#MyAppExeName}"" ""%1"""; Tasks: associatefiles
; Informações do aplicativo
Root: HKCU; Subkey: "Software\{#MyAppName}"; ValueType: string; ValueName: "InstallPath"; ValueData: "{app}"; Flags: uninsdeletekey
Root: HKCU; Subkey: "Software\{#MyAppName}"; ValueType: string; ValueName: "Version"; ValueData: "{#MyAppVersion}"; Flags: uninsdeletekey

[Code]
var
  IsUpgrade: Boolean;
  OldVersion: String;
  DataDir: String;

// ============================================================================
// Funções de Verificação do Sistema
// ============================================================================

// Verificar requisitos mínimos do Windows
function CheckWindowsVersion(): Boolean;
var
  Version: TWindowsVersion;
begin
  GetWindowsVersionEx(Version);
  // Windows 10 1809 (Build 17763) ou superior
  Result := (Version.Major > 10) or
            ((Version.Major = 10) and (Version.Build >= 17763));

  if not Result then
  begin
    MsgBox('⚠️ REQUISITO NÃO ATENDIDO' + #13#13 +
           'Este aplicativo requer Windows 10 versão 1809 (Build 17763) ou superior.' + #13#13 +
           'Versão detectada: ' + IntToStr(Version.Major) + '.' + IntToStr(Version.Minor) +
           ' (Build ' + IntToStr(Version.Build) + ')' + #13#13 +
           'Por favor, atualize seu Windows antes de instalar o {#MyAppName}.',
           mbError, MB_OK);
  end;
end;

// Verificar se é sistema 64-bit
function Check64BitSystem(): Boolean;
begin
  Result := Is64BitInstallMode;

  if not Result then
  begin
    MsgBox('⚠️ SISTEMA INCOMPATÍVEL' + #13#13 +
           'Este aplicativo requer Windows 64-bit.' + #13#13 +
           'Sistema detectado: 32-bit' + #13#13 +
           'Por favor, use um sistema operacional de 64 bits para instalar o {#MyAppName}.',
           mbError, MB_OK);
  end;
end;

// Verificar espaço em disco (mínimo 500 MB)
function CheckDiskSpace(): Boolean;
begin
  // Simplificado - sempre retorna True
  // A verificação real de espaço será feita pelo Windows durante a instalação
  Result := True;
end;

// ============================================================================
// Funções de Detecção de Instalação Anterior
// ============================================================================

// Verificar se já existe instalação anterior
function GetInstalledVersion(var Version: String): Boolean;
var
  UninstallKey: String;
begin
  UninstallKey := 'Software\Microsoft\Windows\CurrentVersion\Uninstall\{' +
                  '{#MyAppId}' + '}_is1';

  Result := RegQueryStringValue(HKLM, UninstallKey, 'DisplayVersion', Version) or
            RegQueryStringValue(HKCU, UninstallKey, 'DisplayVersion', Version);
end;

// Obter diretório de dados do usuário
function GetUserDataDir(): String;
begin
  Result := ExpandConstant('{localappdata}\{#MyAppName}');
end;

// Fazer backup dos dados do usuário
function BackupUserData(): Boolean;
var
  SourceDir: String;
  BackupDir: String;
  ResultCode: Integer;
begin
  Result := True;
  SourceDir := GetUserDataDir();

  if DirExists(SourceDir) then
  begin
    BackupDir := SourceDir + '.backup.' + GetDateTimeString('yyyymmddhhnnss', #0, #0);

    if MsgBox('💾 BACKUP DE DADOS' + #13#13 +
              'Deseja fazer backup dos seus dados antes de atualizar?' + #13#13 +
              'Origem: ' + SourceDir + #13 +
              'Backup: ' + BackupDir + #13#13 +
              '✅ Recomendado: Sim',
              mbConfirmation, MB_YESNO) = IDYES then
    begin
      CreateDir(BackupDir);
      // Copiar arquivos usando xcopy
      Exec('xcopy.exe', '"' + SourceDir + '" "' + BackupDir + '" /E /I /H /Y',
           '', SW_HIDE, ewWaitUntilTerminated, ResultCode);

      if ResultCode = 0 then
        MsgBox('✅ BACKUP CONCLUÍDO' + #13#13 +
               'Backup criado com sucesso em:' + #13 + BackupDir + #13#13 +
               'Seus dados estão seguros!',
               mbInformation, MB_OK)
      else
        MsgBox('⚠️ AVISO' + #13#13 +
               'Não foi possível criar o backup.' + #13 +
               'Código de erro: ' + IntToStr(ResultCode) + #13#13 +
               'A instalação continuará, mas recomendamos fazer backup manual.',
               mbError, MB_OK);
    end;
  end;
end;

// ============================================================================
// Funções de Controle de Processo
// ============================================================================

// Verificar se o aplicativo está em execução
function IsAppRunning(): Boolean;
begin
  // Desabilitado - o Windows irá gerenciar arquivos em uso
  Result := False;
end;

// Fechar aplicação se estiver rodando
function CloseRunningApp(): Boolean;
var
  ResultCode: Integer;
  Attempts: Integer;
begin
  Result := True;
  Attempts := 0;

  while IsAppRunning() and (Attempts < 3) do
  begin
    if Attempts = 0 then
    begin
      if MsgBox('⚠️ APLICATIVO EM EXECUÇÃO' + #13#13 +
                '{#MyAppName} está em execução e precisa ser fechado.' + #13#13 +
                '✅ Clique em OK para fechar o aplicativo e continuar.' + #13 +
                '❌ Clique em Cancelar para abortar a instalação.',
                mbConfirmation, MB_OKCANCEL) = IDCANCEL then
      begin
        Result := False;
        Exit;
      end;
    end;

    // Tentar fechar graciosamente primeiro
    Exec('taskkill.exe', '/IM {#MyAppExeName}', '', SW_HIDE, ewWaitUntilTerminated, ResultCode);
    Sleep(2000);

    // Se ainda estiver rodando, forçar fechamento
    if IsAppRunning() then
    begin
      Exec('taskkill.exe', '/F /IM {#MyAppExeName}', '', SW_HIDE, ewWaitUntilTerminated, ResultCode);
      Sleep(1000);
    end;

    Attempts := Attempts + 1;
  end;

  if IsAppRunning() then
  begin
    MsgBox('❌ ERRO' + #13#13 +
           'Não foi possível fechar {#MyAppName}.' + #13#13 +
           'Por favor, feche o aplicativo manualmente e tente novamente a instalação.',
           mbError, MB_OK);
    Result := False;
  end;
end;

// ============================================================================
// Eventos Principais do Instalador
// ============================================================================

// Inicialização do instalador
function InitializeSetup(): Boolean;
var
  InstalledVersion: String;
  MsgText: String;
begin
  Result := True;
  IsUpgrade := False;

  // Verificar requisitos do sistema
  if not Check64BitSystem() then
  begin
    Result := False;
    Exit;
  end;

  if not CheckWindowsVersion() then
  begin
    Result := False;
    Exit;
  end;

  if not CheckDiskSpace() then
  begin
    Result := False;
    Exit;
  end;

  // Verificar instalação anterior
  if GetInstalledVersion(InstalledVersion) then
  begin
    IsUpgrade := True;
    OldVersion := InstalledVersion;

    MsgText := '🔄 ATUALIZAÇÃO DISPONÍVEL' + #13#13 +
               '{#MyAppName} versão ' + InstalledVersion + ' já está instalado.' + #13#13 +
               'A instalação irá atualizar para a versão {#MyAppVersion}.' + #13#13 +
               '✅ Seus dados serão preservados.' + #13#13 +
               'Deseja continuar com a atualização?';

    if MsgBox(MsgText, mbConfirmation, MB_YESNO) = IDNO then
    begin
      Result := False;
      Exit;
    end;
  end;
end;

// Preparação para instalação
function PrepareToInstall(var NeedsRestart: Boolean): String;
begin
  Result := '';

  // Fechar aplicativo se estiver rodando
  if not CloseRunningApp() then
  begin
    Result := 'Instalação cancelada: não foi possível fechar o aplicativo.';
    Exit;
  end;

  // Fazer backup se for atualização
  if IsUpgrade then
  begin
    BackupUserData();
  end;
end;

// Eventos durante a instalação
procedure CurStepChanged(CurStep: TSetupStep);
var
  MsgText: String;
begin
  if CurStep = ssPostInstall then
  begin
    // Salvar informações da instalação
    DataDir := GetUserDataDir();

    if IsUpgrade then
    begin
      MsgText := '✅ ATUALIZAÇÃO CONCLUÍDA!' + #13#13 +
                 '{#MyAppName} foi atualizado com sucesso!' + #13#13 +
                 'Versão anterior: ' + OldVersion + #13 +
                 'Versão atual: {#MyAppVersion}' + #13#13 +
                 '💾 Seus dados foram preservados em:' + #13 +
                 DataDir;
    end
    else
    begin
      MsgText := '✅ INSTALAÇÃO CONCLUÍDA!' + #13#13 +
                 '{#MyAppName} foi instalado com sucesso!' + #13#13 +
                 'Versão: {#MyAppVersion}' + #13#13 +
                 '💾 Dados do aplicativo serão salvos em:' + #13 +
                 DataDir;
    end;

    // Não mostrar mensagem, deixar para a tela final
    // MsgBox(MsgText, mbInformation, MB_OK);
  end;
end;

// Personalizar página final
procedure CurPageChanged(CurPageID: Integer);
begin
  if CurPageID = wpFinished then
  begin
    // Customizar mensagem final se necessário
  end;
end;

