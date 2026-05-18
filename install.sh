#!/usr/bin/env bash
# Bootstrap entry point for a-vafa/new-chez (Unix/macOS/Linux/WSL).
# Run:  curl -fsSL https://raw.githubusercontent.com/a-vafa/chez-public/main/install.sh | bash
set -euo pipefail

PRIVATE_REPO="a-vafa/new-chez"

log()  { printf '\033[1;34m[boot]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[warn]\033[0m %s\n' "$*"; }
die()  { printf '\033[1;31m[err ]\033[0m %s\n' "$*" >&2; exit 1; }

need_cmd() { command -v "$1" >/dev/null 2>&1; }

install_gh() {
    need_cmd gh && return 0
    log "Installing GitHub CLI..."
    if need_cmd brew; then
        brew install gh
    elif need_cmd apt-get; then
        sudo apt-get update -y && sudo apt-get install -y gh \
            || { type -p curl >/dev/null || sudo apt-get install -y curl; \
                 curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
                   | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg; \
                 sudo chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg; \
                 echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
                   | sudo tee /etc/apt/sources.list.d/github-cli.list >/dev/null; \
                 sudo apt-get update -y && sudo apt-get install -y gh; }
    elif need_cmd dnf;     then sudo dnf install -y gh
    elif need_cmd pacman;  then sudo pacman -Sy --noconfirm github-cli
    elif need_cmd apk;     then sudo apk add github-cli
    else die "no supported package manager (brew/apt/dnf/pacman/apk); install gh manually then re-run"
    fi
}

install_chezmoi() {
    need_cmd chezmoi && return 0
    log "Installing chezmoi..."
    sh -c "$(curl -fsSL https://get.chezmoi.io)" -- -b "$HOME/.local/bin"
    export PATH="$HOME/.local/bin:$PATH"
}

auth_gh() {
    if ! gh auth status >/dev/null 2>&1; then
        log "Starting GitHub device-code auth."
        log "Open https://github.com/login/device in your LOCAL browser and paste the 8-char code printed below."
        # BROWSER=true: gh tries to xdg-open a browser, which fails on headless
        # boxes (SSH/VPS/CI). Pointing it at /usr/bin/true makes the launch a
        # silent no-op; the URL + code are already echoed for the user.
        BROWSER=true gh auth login --hostname github.com --web
    else
        log "gh already authenticated"
    fi
    # Always (re-)wire git to use gh's credential helper so `git clone` of
    # private repos works without prompting for username/password. Idempotent.
    gh auth setup-git
}

setup_bitwarden_optional() {
    # bw should have been installed by chezmoi's package step if the user's
    # profile/overlay includes it. If not present, skip silently.
    need_cmd bw || return 0

    # We're being piped from curl, so stdin isn't a TTY — read from /dev/tty.
    # `[[ -r /dev/tty ]]` only checks mode bits (rw-rw-rw-) and lies in CI
    # where the file exists but cannot be opened. Probe by actually opening it.
    if ! true </dev/tty 2>/dev/null; then
        warn "No TTY available; skipping Bitwarden setup."
        warn "Run later: bw login && export BW_SESSION=\$(bw unlock --raw) && chezmoi apply"
        return 0
    fi

    local answer
    printf '\n'
    read -rp "Set up Bitwarden secrets now? [y/N] " answer </dev/tty || answer=""
    case "${answer:-N}" in
        y|Y|yes|YES) ;;
        *)  log "Skipped. To enable later: bw login && export BW_SESSION=\$(bw unlock --raw) && chezmoi apply"
            return 0 ;;
    esac

    if ! bw login --check >/dev/null 2>&1; then
        log "Running 'bw login' (email + master password)..."
        bw login </dev/tty || { warn "bw login failed; skipping"; return 0; }
    fi

    log "Unlocking vault..."
    local session
    session=$(bw unlock --raw </dev/tty) || { warn "bw unlock failed; skipping"; return 0; }
    export BW_SESSION="$session"

    log "Re-applying chezmoi with secrets..."
    chezmoi apply

    warn "BW_SESSION is set for this bootstrap only. New shells will start locked."
    warn "Unlock again with: export BW_SESSION=\$(bw unlock --raw)"
}

drop_into_zsh() {
    # Magic: if we have a usable TTY and zsh exists, replace this bash subshell
    # with an interactive zsh. Works through `curl | bash` because we re-bind
    # stdin to /dev/tty. The user sees their fully-loaded zsh prompt the moment
    # bootstrap finishes; Ctrl+D returns them to the parent (login) shell.
    need_cmd zsh || { warn "zsh not found; bootstrap done, run 'exec zsh' manually if installed later."; return 0; }
    # Probe by opening; mode-bit check is unreliable (CI has /dev/tty rw-rw-rw-
    # but it cannot actually be opened without a controlling terminal).
    if ! true </dev/tty 2>/dev/null; then
        log "No TTY (likely CI/non-interactive). Open a new shell to use zsh."
        return 0
    fi
    log "Bootstrap done. Dropping you into zsh now..."
    exec zsh -l </dev/tty
}

main() {
    need_cmd curl || die "curl is required (install it first)"
    need_cmd git  || die "git is required (install it first)"
    install_gh
    install_chezmoi
    auth_gh
    log "Bootstrapping dotfiles from ${PRIVATE_REPO}..."
    chezmoi init --apply "${PRIVATE_REPO}"
    setup_bitwarden_optional
    drop_into_zsh
}

main "$@"
