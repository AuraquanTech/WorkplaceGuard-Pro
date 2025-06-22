<#
.SYNOPSIS
  One-click bootstrap, build & launch for WorkplaceGuard Pro on Windows.

.DESCRIPTION
  - Installs missing tools via winget/npm/cargo.
  - Compiles EvidenceCollector.ahk → EvidenceCollector.exe.
  - Builds Vite/React UI.
  - Builds Tauri shell (release).
  - Launches the final WorkplaceGuardPro.exe in GUI or headless mode.

.PARAMETER Headless
  If supplied, runs WorkplaceGuardPro.exe with --headless (tray-only).

.EXAMPLE
  # GUI mode
  Set-ExecutionPolicy Bypass -Scope Process -Force
  .\build.ps1

  # Tray-only mode
  .\build.ps1 -Headless
#>
param(
  [switch]$Headless
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Write-Host "==> Starting in: $(Get-Location)" -ForegroundColor Cyan

function Ensure-Installed {
  param(
    [string]$CmdName,
    [string]$WingetId,
    [string]$InstallHint
  )
  if (-not (Get-Command $CmdName -ErrorAction SilentlyContinue)) {
    Write-Host "==> [$CmdName] not found → installing $InstallHint" -ForegroundColor Yellow
    winget install --id $WingetId --accept-package-agreements --accept-source-agreements --silent
  }
  else { Write-Host "==> [$CmdName] found." -ForegroundColor Green }
}

# 1) Ensure winget exists (Windows 10/11 should have it by default)
if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
  throw "winget is required but not installed. Please install the App Installer from the Microsoft Store."
}

# 2) Node & pnpm
Ensure-Installed -CmdName node -WingetId OpenJS.NodeJS.LTS -InstallHint "Node.js LTS (includes npm)"
if (-not (Get-Command pnpm -ErrorAction SilentlyContinue)) {
  Write-Host "==> pnpm not found → installing via npm" -ForegroundColor Yellow
  npm install -g pnpm
} else { Write-Host "==> pnpm found." -ForegroundColor Green }

# 3) Rust & cargo
Ensure-Installed -CmdName rustup -WingetId RustLang.Rustup -InstallHint "rustup-init"
& rustup-init.exe -y | Out-Null
$env:Path += ";$env:USERPROFILE\.cargo\bin"
if (-not (Get-Command cargo -ErrorAction SilentlyContinue)) {
  throw "cargo still missing after rustup. Aborting."
}

# 4) Tauri CLI
if (-not (Get-Command cargo-tauri -ErrorAction SilentlyContinue)) {
  Write-Host "==> tauri-cli not found → installing via cargo" -ForegroundColor Yellow
  cargo install tauri-cli --locked
} else { Write-Host "==> tauri-cli found." -ForegroundColor Green }

# 5) NSIS (for your installer.nsi)
Ensure-Installed -CmdName makensis.exe -WingetId NSIS.NSIS -InstallHint "NSIS (makensis.exe)"

# 6) AutoHotkey v2 compiler (Ahk2Exe.exe)
$ahkCandidates = @(
  "C:\Program Files\AutoHotkey\Compiler\Ahk2Exe.exe",
  "C:\Program Files (x86)\AutoHotkey\Compiler\Ahk2Exe.exe"
)
$ahkExe = $ahkCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $ahkExe) {
  throw "Ahk2Exe.exe not found. Install AutoHotkey v2 with the compiler package."
}
Write-Host "==> Found Ahk2Exe at $ahkExe" -ForegroundColor Green

# 7) Compile your AHK backend
Write-Host "==> Compiling EvidenceCollector.ahk → EvidenceCollector.exe" -ForegroundColor Cyan
& $ahkExe /in EvidenceCollector.ahk /out EvidenceCollector.exe `
  /base (Split-Path $ahkExe)'\Unicode64.bin'

# 8) Build the UI
if (-not (Test-Path ui\package.json)) {
  throw "UI folder missing package.json (did you scaffold / restore it?)."
}
Push-Location ui
Write-Host "==> Installing & building UI (pnpm)" -ForegroundColor Cyan
pnpm install
pnpm build
Pop-Location

# 9) Build the Tauri shell
Push-Location src-tauri
Write-Host "==> Running tauri build --release" -ForegroundColor Cyan
tauri build --release
Pop-Location

# 10) Locate the final exe
$exePath = Join-Path src-tauri\target\release 'WorkplaceGuardPro.exe'
if (-not (Test-Path $exePath)) {
  throw "Build finished but executable not found at $exePath"
}

# 11) Launch
if ($Headless) {
  Write-Host "==> Launching headless mode (tray only)" -ForegroundColor Cyan
  & $exePath --headless
} else {
  Write-Host "==> Launching GUI mode" -ForegroundColor Cyan
  & $exePath
}
