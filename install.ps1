# Bootstrap entry point for a-vafa/new-chez (Windows PowerShell 5+).
# Run:  iwr -useb https://raw.githubusercontent.com/a-vafa/chez-public/main/install.ps1 | iex

$ErrorActionPreference = 'Stop'
$PrivateRepo = 'a-vafa/new-chez'

function Log  ($m) { Write-Host "[boot] $m" -ForegroundColor Cyan }
function Warn ($m) { Write-Host "[warn] $m" -ForegroundColor Yellow }
function Die  ($m) { Write-Host "[err ] $m" -ForegroundColor Red; exit 1 }

function Has-Cmd ($name) { [bool](Get-Command $name -ErrorAction SilentlyContinue) }

function Install-WingetPkg ($id) {
    if (-not (Has-Cmd winget)) {
        Die "winget not available. Install 'App Installer' from the Microsoft Store, then re-run."
    }
    Log "winget install --id $id"
    winget install -e --id $id --accept-source-agreements --accept-package-agreements --silent
}

function Ensure-Path ($dir) {
    if ($env:Path -notlike "*$dir*") { $env:Path = "$dir;$env:Path" }
}

function Install-Gh {
    if (Has-Cmd gh) { return }
    Install-WingetPkg 'GitHub.cli'
    Ensure-Path "$env:ProgramFiles\GitHub CLI"
}

function Install-Chezmoi {
    if (Has-Cmd chezmoi) { return }
    Install-WingetPkg 'twpayne.chezmoi'
    Ensure-Path "$env:LOCALAPPDATA\Microsoft\WinGet\Links"
}

function Auth-Gh {
    & gh auth status 2>$null
    if ($LASTEXITCODE -eq 0) { Log 'gh already authenticated'; return }
    Log 'Starting GitHub device-code auth (paste the 8-char code in your browser)...'
    & gh auth login --hostname github.com --git-protocol https --web
    if ($LASTEXITCODE -ne 0) { Die 'gh auth failed' }
}

Install-Gh
Install-Chezmoi
Auth-Gh
Log "Bootstrapping dotfiles from $PrivateRepo..."
& chezmoi init --apply $PrivateRepo
if ($LASTEXITCODE -ne 0) { Die 'chezmoi init failed' }
Log 'Done. Open a new shell.'
