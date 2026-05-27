; EmojiContainer Windows 安装包（Inno Setup）
; CI 构建前设置环境变量 MY_APP_VERSION（不含 v 前缀，如 2.3）

#define MyAppName "EmojiContainer"
#define MyAppDisplayName "表情包管理器"
#define MyAppVersion GetEnv("MY_APP_VERSION")
#define MyAppPublisher "PortianLiu"
#define MyAppURL "https://github.com/PortianLiu/emoji_container"
#define MyAppExeName "emoji_container.exe"
#define ProjectDir "."
#define BuildDir ".\build\windows\x64\runner\Release"

[Setup]
AppId={{A8F3E2C1-9B4D-4E6A-8F2C-1D5E7A9B3C4D}}
AppName={#MyAppDisplayName}
AppVersion={#MyAppVersion}
AppVerName={#MyAppDisplayName} {#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}
AppUpdatesURL={#MyAppURL}
DefaultDirName={autopf}\{#MyAppName}
UninstallDisplayIcon={app}\{#MyAppExeName}
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
DefaultGroupName={#MyAppDisplayName}
AllowNoIcons=yes
LicenseFile={#ProjectDir}\LICENSE
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=commandline
OutputDir={#ProjectDir}\build\dist
OutputBaseFilename=EmojiContainer_Setup_x64_v{#MyAppVersion}
SetupIconFile={#ProjectDir}\assets\tray_icon.ico
SolidCompression=yes
WizardStyle=modern

[Languages]
Name: "chinesesimp"; MessagesFile: "compiler:Languages\ChineseSimplified.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
Source: "{#BuildDir}\{#MyAppExeName}"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#BuildDir}\*.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#BuildDir}\data\*"; DestDir: "{app}\data"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\{#MyAppDisplayName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{autodesktop}\{#MyAppDisplayName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(MyAppDisplayName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent
