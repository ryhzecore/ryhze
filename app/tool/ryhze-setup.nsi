Unicode true
!include "MUI2.nsh"
!include "x64.nsh"
Name "Ryhze"
!ifndef VERSION
!define VERSION "1.0.6"
!endif
OutFile "..\..\releases\Ryhze-${VERSION}-Windows-Setup.exe"
InstallDir "$LOCALAPPDATA\Programs\Ryhze"
InstallDirRegKey HKCU "Software\Ryhze" "InstallDir"
RequestExecutionLevel user
SetCompressor /SOLID lzma
Icon "..\windows\runner\resources\app_icon.ico"
UninstallIcon "..\windows\runner\resources\app_icon.ico"
VIProductVersion "${VERSION}.0"
VIAddVersionKey "ProductName" "Ryhze"
VIAddVersionKey "FileDescription" "Ryhze installer"
VIAddVersionKey "FileVersion" "${VERSION}"
VIAddVersionKey "LegalCopyright" "Copyright 2026 Ryhze"
!define MUI_ABORTWARNING
!define MUI_FINISHPAGE_RUN "$INSTDIR\ryhze.exe"
!insertmacro MUI_PAGE_WELCOME
!insertmacro MUI_PAGE_DIRECTORY
!insertmacro MUI_PAGE_INSTFILES
!insertmacro MUI_PAGE_FINISH
!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_INSTFILES
!insertmacro MUI_LANGUAGE "English"

Function .onInit
  ${IfNot} ${RunningX64}
    MessageBox MB_ICONSTOP "Ryhze requires 64-bit Windows."
    Abort
  ${EndIf}
FunctionEnd

Section "Ryhze"
  SetOutPath "$INSTDIR"
  ClearErrors
  File /r "..\build\windows\x64\runner\Release\*"
  IfErrors 0 +3
    SetErrorLevel 1
    Quit
  WriteUninstaller "$INSTDIR\Uninstall.exe"
  CreateShortcut "$SMPROGRAMS\Ryhze.lnk" "$INSTDIR\ryhze.exe"
  WriteRegStr HKCU "Software\Ryhze" "InstallDir" "$INSTDIR"
  WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\Ryhze" "DisplayName" "Ryhze"
  WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\Ryhze" "DisplayVersion" "${VERSION}"
  WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\Ryhze" "Publisher" "Ryhze"
  WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\Ryhze" "DisplayIcon" "$INSTDIR\ryhze.exe"
  WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\Ryhze" "UninstallString" '"$INSTDIR\Uninstall.exe"'
  WriteRegDWORD HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\Ryhze" "NoModify" 1
  WriteRegDWORD HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\Ryhze" "NoRepair" 1
SectionEnd

Section "Uninstall"
  ; Remove only packaged application files; user preferences remain untouched.
  !include "uninstall-files.nsh"
  Delete "$INSTDIR\Uninstall.exe"
  RMDir "$INSTDIR"
  Delete "$SMPROGRAMS\Ryhze.lnk"
  DeleteRegKey HKCU "Software\Ryhze"
  DeleteRegKey HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\Ryhze"
SectionEnd
