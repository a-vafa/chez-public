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
    if gh auth status >/dev/null 2>&1; then
        log "gh already authenticated"
        return 0
    fi
    log "Starting GitHub device-code auth (paste the 8-char code in your browser)..."
    gh auth login --hostname github.com --git-protocol https --web
}

main() {
    need_cmd curl || die "curl is required (install it first)"
    need_cmd git  || die "git is required (install it first)"
    install_gh
    install_chezmoi
    auth_gh
    log "Bootstrapping dotfiles from ${PRIVATE_REPO}..."
    chezmoi init --apply "${PRIVATE_REPO}"
    log "Done. Open a new shell."
}

main "$@"
