# chez-public

Tiny public bootstrap shim for [a-vafa/new-chez](https://github.com/a-vafa/new-chez)
(private dotfiles repo). Contains no secrets — only auth + clone glue.

## Usage

### macOS / Linux / WSL

```bash
curl -fsSL https://raw.githubusercontent.com/a-vafa/chez-public/main/install.sh | bash
```

### Windows (PowerShell)

```powershell
iwr -useb https://raw.githubusercontent.com/a-vafa/chez-public/main/install.ps1 | iex
```

## What it does

1. Installs `gh` (GitHub CLI) and `chezmoi` via the platform package manager.
2. Runs `gh auth login --web` — opens a browser, you paste an 8-character device
   code. Token is stored in the OS credential store (Keychain / Windows
   Credential Manager / libsecret); never written to plaintext.
3. Runs `chezmoi init --apply a-vafa/new-chez`. Clones over HTTPS using gh's
   git credential helper, then applies.

## Auth model

- No PATs, no env vars, no token files.
- Re-runs are idempotent: skips already-installed tools and already-authed gh.
- To revoke access on a machine: `gh auth logout`.
