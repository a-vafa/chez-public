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
    # --git-protocol https omitted for compat with older gh versions; default is https
    & gh auth login --hostname github.com --web
    if ($LASTEXITCODE -ne 0) { Die 'gh auth failed' }
}

function Setup-Bitwarden-Optional {
    # bw should be installed by chezmoi's package step if the user's profile
    # includes it. If not present, skip silently.
    if (-not (Has-Cmd bw)) { return }

    Write-Host ''
    $answer = Read-Host 'Set up Bitwarden secrets now? [y/N]'
    if ($answer -notmatch '^(y|Y|yes|YES)$') {
        Log 'Skipped. To enable later: bw login; $env:BW_SESSION = bw unlock --raw; chezmoi apply'
        return
    }

    & bw login --check 2>$null | Out-Null
    if ($LASTEXITCODE -ne 0) {
        Log "Running 'bw login' (email + master password)..."
        & bw login
        if ($LASTEXITCODE -ne 0) { Warn 'bw login failed; skipping'; return }
    }

    Log 'Unlocking vault...'
    $session = & bw unlock --raw
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($session)) {
        Warn 'bw unlock failed; skipping'; return
    }
    $env:BW_SESSION = $session

    Log 'Re-applying chezmoi with secrets...'
    & chezmoi apply
    if ($LASTEXITCODE -ne 0) { Warn 'chezmoi apply failed after unlock' }

    Warn 'BW_SESSION is set for this bootstrap only. New shells will start locked.'
    Warn 'Unlock again with: $env:BW_SESSION = bw unlock --raw'
}

Install-Gh
Install-Chezmoi
Auth-Gh
Log "Bootstrapping dotfiles from $PrivateRepo..."
& chezmoi init --apply $PrivateRepo
if ($LASTEXITCODE -ne 0) { Die 'chezmoi init failed' }
Setup-Bitwarden-Optional
Log 'Done. Open a new shell.'
