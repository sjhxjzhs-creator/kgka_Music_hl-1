; KA Music Windows 安装引导版打包脚本（Inno Setup 6）
; CI 通过 /DAppVersion /DSrcDir /DOutDir 注入版本号与绝对路径；
; 本地手动编译时默认值相对本脚本所在目录（windows/）解析。
; 中文向导语言文件随仓库携带（ChineseSimplified.isl，取自 Inno Setup 官方仓库），
; 不依赖打包机是否预装中文语言包。
#ifndef AppVersion
  #define AppVersion "3.3.0"
#endif
#ifndef SrcDir
  #define SrcDir "..\build\windows\x64\runner\Release"
#endif
#ifndef OutDir
  #define OutDir "..\installer-output"
#endif

#define MyAppName "KA Music"
#define MyAppExeName "kgka_music_hl.exe"
#define MyAppPublisher "kgka_Music_hl (MIT, 仅供学习交流)"
#define MyAppURL "https://github.com/umr-xiaomai/kgka_Music_hl"

[Setup]
; 固定 AppId：同 AppId 覆盖安装即升级，避免旧版残留
AppId={{8F3C2A11-7D4B-4E9A-9C6D-1B2A3C4D5E6F}
AppName={#MyAppName}
AppVersion={#AppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}
DisableProgramGroupPage=yes
OutputDir={#OutDir}
OutputBaseFilename=KA-Music-Setup-{#AppVersion}-x64
Compression=lzma2/max
SolidCompression=yes
WizardStyle=modern
ArchitecturesInstallIn64BitMode=x64compatible
ArchitecturesAllowed=x64compatible
; 未做代码签名；默认 per-user 安装（{autopf} 落到用户目录），不弹 UAC
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog
UninstallDisplayIcon={app}\{#MyAppExeName}

[Languages]
Name: "chinesesimplified"; MessagesFile: "ChineseSimplified.isl"
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "创建桌面快捷方式"; GroupDescription: "附加任务:"

[Files]
; 整个 Release 目录（exe + data\ + 各插件 dll）必须一起安装，缺 dll 会启动即崩
Source: "{#SrcDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon
Name: "{group}\卸载 {#MyAppName}"; Filename: "{uninstallexe}"

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "立即运行 {#MyAppName}"; Flags: nowait postinstall skipifsilent

[UninstallDelete]
Type: filesandordirs; Name: "{app}"
