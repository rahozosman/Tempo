; Tempo — Windows installer (Inno Setup 6)
;
; Build the app first, then compile this script:
;
;   flutter build windows --release
;   iscc packaging\windows\tempo.iss
;
; The result is packaging\windows\output\TempoSetup-<version>.exe, a plain
; installer that needs no store account. For the Microsoft Store, use the MSIX
; configuration in pubspec.yaml instead: `dart run msix:create`.

#define AppName "Tempo"
#define AppVersion "1.0.0"
#define AppPublisher "Tempo"
#define AppExeName "Tempo.exe"
#define BuildDir "..\..\build\windows\x64\runner\Release"

[Setup]
AppId={{8C5C2A4E-1E2B-4C63-9E0D-5B7C6A9D4F21}
AppName={#AppName}
AppVersion={#AppVersion}
AppPublisher={#AppPublisher}
DefaultDirName={autopf}\{#AppName}
DefaultGroupName={#AppName}
UninstallDisplayIcon={app}\{#AppExeName}
OutputDir=output
OutputBaseFilename=TempoSetup-{#AppVersion}
SetupIconFile=..\..\windows\runner\resources\app_icon.ico
Compression=lzma2/max
SolidCompression=yes
WizardStyle=modern
; Per-user by default: Tempo measures one person's time and needs no elevation.
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "Create a desktop shortcut"; GroupDescription: "Shortcuts:"; Flags: unchecked

[Files]
; The whole release folder: the executable, its DLLs and data\.
Source: "{#BuildDir}\{#AppExeName}"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#BuildDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
; A Start-menu shortcut is also what Windows requires before an application
; may raise toast notifications.
Name: "{group}\{#AppName}"; Filename: "{app}\{#AppExeName}"
Name: "{autodesktop}\{#AppName}"; Filename: "{app}\{#AppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#AppExeName}"; Description: "Open {#AppName}"; Flags: nowait postinstall skipifsilent

[UninstallDelete]
; Leaves the usage database alone: uninstalling the app should not silently
; delete someone's history. Settings has a delete action for that.
Type: filesandordirs; Name: "{app}"
