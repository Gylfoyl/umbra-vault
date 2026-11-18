#ifndef BuildRoot
  #define BuildRoot SourcePath + "..\dist\UmbraVault"
#endif
#define AppVersion "1.1.1"

[Setup]
AppId={{18AC4989-33F9-4C70-A1E8-F5F1F8FD2BC4}
AppName=Umbra Vault
AppVersion={#AppVersion}
AppVerName=Umbra Vault {#AppVersion}
AppPublisher=Umbra
VersionInfoCompany=Umbra
VersionInfoDescription=Secure Offline Password Manager
VersionInfoProductName=Umbra Vault
VersionInfoVersion={#AppVersion}.0
DefaultDirName={localappdata}\Programs\Umbra Vault
DefaultGroupName=Umbra Vault
UninstallDisplayIcon={app}\UmbraVault.exe
PrivilegesRequired=lowest
ArchitecturesAllowed=x64os
ArchitecturesInstallIn64BitMode=x64os
MinVersion=10.0.22000
DisableDirPage=no
OutputDir=..\release
OutputBaseFilename=UmbraVault-Setup-{#AppVersion}
SetupIconFile=..\app\ui\assets\umbra.ico
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
CloseApplications=yes

[Languages]
Name: "russian"; MessagesFile: "compiler:Languages\Russian.isl"
Name: "english"; MessagesFile: "compiler:Default.isl"

[CustomMessages]
english.SeparateDataDir=Choose an installation folder separate from the vault data directory.
russian.SeparateDataDir=Выберите папку установки отдельно от каталога хранилища.

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; Flags: unchecked

[Files]
Source: "{#BuildRoot}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{userprograms}\Umbra Vault"; Filename: "{app}\UmbraVault.exe"; WorkingDir: "{app}"; AppUserModelID: "Umbra.UmbraVault"
Name: "{userdesktop}\Umbra Vault"; Filename: "{app}\UmbraVault.exe"; WorkingDir: "{app}"; AppUserModelID: "Umbra.UmbraVault"; Tasks: desktopicon

[Run]
Filename: "{app}\UmbraVault.exe"; Description: "{cm:LaunchProgram,Umbra Vault}"; Flags: nowait postinstall skipifsilent

[Code]
function InstallationOverlapsData: Boolean;
var
  DataDir, TargetDir: String;
begin
  DataDir := AddBackslash(ExpandConstant('{localappdata}\Umbra Vault\Data'));
  TargetDir := AddBackslash(ExpandFileName(WizardDirValue));
  Result := (CompareText(Copy(TargetDir, 1, Length(DataDir)), DataDir) = 0) or
            (CompareText(Copy(DataDir, 1, Length(TargetDir)), TargetDir) = 0);
end;

function NextButtonClick(CurPageID: Integer): Boolean;
begin
  Result := True;
  if (CurPageID = wpSelectDir) and InstallationOverlapsData then
  begin
    SuppressibleMsgBox(CustomMessage('SeparateDataDir'), mbError, MB_OK, IDOK);
    Result := False;
  end;
end;

function PrepareToInstall(var NeedsRestart: Boolean): String;
begin
  Result := '';
  if InstallationOverlapsData then
    Result := CustomMessage('SeparateDataDir');
end;
