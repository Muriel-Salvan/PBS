;--
; Copyright (c) 2009 - 2012 Muriel Salvan (muriel@x-aeon.com)
; Licensed under the terms specified in LICENSE file. No warranty is provided.
;++

; install.nsi
;
; This script creates an installer using NSIS for PBS on Windows.
; The compiler must define the following symbols:
; * VERSION (/DVERSION=0.0.1.20090430)
; * RELEASEDIR ("/DRELEASEDIR=C:\PBS\Releases\MyRelease")

;--------------------------------
; Global attributes
Name "PBS"
Caption "PBS: Portable Bookmarks and Shortcuts"
Icon "Icon.ico"
OutFile "setup.exe"

;--------------------------------
; Compiler tuner
XPStyle on

;--------------------------------
; Default location
InstallDir "$PROGRAMFILES\PBS"

;--------------------------------
; License
LicenseText "Welcome to PBS installation (v. ${VERSION}).$\nPBS is free and Open Source."
LicenseData "InstallLicense.txt"

;--------------------------------
; List of wizard pages to display
Page license
Page components
Page directory
Page instfiles
UninstPage uninstConfirm
UninstPage instfiles

;--------------------------------
; List of installable components
InstType "Full"

;--------------------------------
; Sections giving what to install

Section "PBS"
  SectionIn 1 RO
  SetOutPath $INSTDIR
  File /r ${RELEASEDIR}\*.*
SectionEnd

Section "Create uninstaller (not needed for roaming)"
  SectionIn 1
  ; Remember this directory
  WriteRegStr HKLM SOFTWARE\PBS "Install_Dir" "$INSTDIR"
  ; Write uninstall strings
  WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\PBS" "DisplayName" "PBS (remove only)"
  WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\PBS" "UninstallString" '"$INSTDIR\pbs_uninst.exe"'
  ; Create the uninstaller
  SetOutPath $INSTDIR
  WriteUninstaller "pbs_uninst.exe"
SectionEnd

Section "Create shortcuts in start menu"
  SectionIn 1
  CreateDirectory "$SMPROGRAMS\PBS"
  CreateShortCut "$SMPROGRAMS\PBS\PBS.lnk" "$INSTDIR\pbs.exe" \
  "" "$INSTDIR\pbs.exe" 0 SW_SHOWNORMAL \
  "" "PBS: Portable Bookmarks and Shortcuts"
  ; Test if the installer was created
  IfFileExists $INSTDIR\pbs_uninst.exe 0 afteruninst
  CreateShortCut "$SMPROGRAMS\PBS\PBS_uninst.lnk" "$INSTDIR\pbs_uninst.exe" \
  "" "$INSTDIR\pbs_uninst.exe" 0 SW_SHOWNORMAL \
  "" "Uninstall PBS"
  afteruninst:
SectionEnd

;--------------------------------
; Uninstaller

UninstallText "This will uninstall PBS. Hit next to continue."
UninstallIcon "${NSISDIR}\Contrib\Graphics\Icons\nsis1-uninstall.ico"

Section "Uninstall"
  DeleteRegKey HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\PBS"
  DeleteRegKey HKLM "SOFTWARE\PBS"
  RMDir /r "$INSTDIR"
  RMDir /r "$SMPROGRAMS\PBS"
  IfFileExists "$INSTDIR" 0 NoErrorMsg
  MessageBox MB_OK "Note: $INSTDIR could not be removed!" IDOK 0 ; skipped if file doesn't exist
  NoErrorMsg:
SectionEnd
