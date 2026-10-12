; Per-user NSIS installer for the Godot Windows export.
; Unsigned on purpose: Windows SmartScreen will warn until a publisher certificate is added.
; Backslashes in NSIS strings are escapes, so Windows paths use \\.

!include "MUI2.nsh"

!ifndef SOURCE_DIR
  !define SOURCE_DIR "../build/windows"
!endif

Name "TussieCars"
OutFile "${SOURCE_DIR}/TussieCars-Windows-Setup.exe"
Unicode True
RequestExecutionLevel user
InstallDir "$LOCALAPPDATA\\TussieCars"
InstallDirRegKey HKCU "Software\\TussieCars" "InstallDir"

!define MUI_ICON "${SOURCE_DIR}/icon.ico"
!define MUI_UNICON "${SOURCE_DIR}/icon.ico"
!define MUI_ABORTWARNING

!insertmacro MUI_PAGE_WELCOME
!insertmacro MUI_PAGE_DIRECTORY
!insertmacro MUI_PAGE_INSTFILES
!insertmacro MUI_PAGE_FINISH
!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_INSTFILES
!insertmacro MUI_LANGUAGE "Norwegian"
!insertmacro MUI_LANGUAGE "English"

VIProductVersion "1.1.0.0"
VIAddVersionKey "ProductName" "TussieCars"
VIAddVersionKey "FileDescription" "TussieCars Windows installer"
VIAddVersionKey "FileVersion" "1.1.0.0"
VIAddVersionKey "ProductVersion" "1.1.0.0"
VIAddVersionKey "CompanyName" "TussieCars"
VIAddVersionKey "LegalCopyright" "TussieCars"

Section "TussieCars" SecMain
  SectionIn RO
  SetOutPath "$INSTDIR"
  File "${SOURCE_DIR}/TussieCars.exe"
  File "${SOURCE_DIR}/libgodotopenxrvendors.dll"
  File "${SOURCE_DIR}/TussieCars-VR.bat"
  File "${SOURCE_DIR}/icon.ico"
  WriteUninstaller "$INSTDIR\\Avinstaller.exe"
  CreateDirectory "$SMPROGRAMS\\TussieCars"
  CreateShortcut "$SMPROGRAMS\\TussieCars\\TussieCars.lnk" "$INSTDIR\\TussieCars.exe"
  CreateShortcut "$SMPROGRAMS\\TussieCars\\TussieCars VR.lnk" "$INSTDIR\\TussieCars-VR.bat"
  CreateShortcut "$DESKTOP\\TussieCars.lnk" "$INSTDIR\\TussieCars.exe"
  WriteRegStr HKCU "Software\\TussieCars" "InstallDir" "$INSTDIR"
  WriteRegStr HKCU "Software\\Microsoft\\Windows\\CurrentVersion\\Uninstall\\TussieCars" "DisplayName" "TussieCars"
  WriteRegStr HKCU "Software\\Microsoft\\Windows\\CurrentVersion\\Uninstall\\TussieCars" "UninstallString" "$INSTDIR\\Avinstaller.exe"
  WriteRegStr HKCU "Software\\Microsoft\\Windows\\CurrentVersion\\Uninstall\\TussieCars" "DisplayVersion" "1.1.0"
  WriteRegStr HKCU "Software\\Microsoft\\Windows\\CurrentVersion\\Uninstall\\TussieCars" "Publisher" "TussieCars"
  WriteRegStr HKCU "Software\\Microsoft\\Windows\\CurrentVersion\\Uninstall\\TussieCars" "DisplayIcon" "$INSTDIR\\TussieCars.exe"
  WriteRegDWORD HKCU "Software\\Microsoft\\Windows\\CurrentVersion\\Uninstall\\TussieCars" "NoModify" 1
  WriteRegDWORD HKCU "Software\\Microsoft\\Windows\\CurrentVersion\\Uninstall\\TussieCars" "NoRepair" 1
SectionEnd

Section "Uninstall"
  Delete "$INSTDIR\\TussieCars.exe"
  Delete "$INSTDIR\\libgodotopenxrvendors.dll"
  Delete "$INSTDIR\\TussieCars-VR.bat"
  Delete "$INSTDIR\\icon.ico"
  Delete "$INSTDIR\\Avinstaller.exe"
  Delete "$SMPROGRAMS\\TussieCars\\TussieCars.lnk"
  Delete "$SMPROGRAMS\\TussieCars\\TussieCars VR.lnk"
  RMDir "$SMPROGRAMS\\TussieCars"
  Delete "$DESKTOP\\TussieCars.lnk"
  RMDir "$INSTDIR"
  DeleteRegKey HKCU "Software\\Microsoft\\Windows\\CurrentVersion\\Uninstall\\TussieCars"
  DeleteRegKey HKCU "Software\\TussieCars"
SectionEnd
