!include "MUI2.nsh"
Name "WorkplaceGuard Pro"
OutFile "WorkplaceGuardPro_Installer.exe"
InstallDir "$PROGRAMFILES\WorkplaceGuard"
Page Directory
Page InstFiles
Section
  SetOutPath $INSTDIR
  File /r "..\target\release\bundle\WorkplaceGuardPro.exe"
  File "..\src-tauri\target\release\EvidenceCollector.exe"
SectionEnd