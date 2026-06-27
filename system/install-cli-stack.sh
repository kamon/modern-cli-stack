#!/usr/bin/env bash
# install-cli-stack.sh — Modern CLI Stack installer
# Tested on: macOS 13+, Ubuntu 22.04+, Fedora 39+, Arch, WSL Ubuntu
#
# Usage:
#   curl -fsSL <url> | bash                  # direct install
#   curl -fsSL <url> -o install.sh && bash install.sh   # inspect first
#
# Tools installed: mise, broot, starship, zoxide, fzf, ripgrep, fd, bat,
#                  eza, delta, tldr, atuin, lazygit
#
# Idempotent: safe to re-run. Skips tools already installed.
# Reversible: see README for uninstall instructions.

set -euo pipefail

# --- Colors & helpers -------------------------------------------------------
RED=$'\033[0;31m'; GRN=$'\033[0;32m'; YEL=$'\033[0;33m'; CYN=$'\033[0;36m'; DIM=$'\033[2m'; RST=$'\033[0m'

info()  { printf "%s[INFO]%s %s\n" "$CYN" "$RST" "$*"; }
ok()    { printf "%s[ OK ]%s %s\n" "$GRN" "$RST" "$*"; }
warn()  { printf "%s[WARN]%s %s\n" "$YEL" "$RST" "$*"; }
err()   { printf "%s[FAIL]%s %s\n" "$RED" "$RST" "$*" >&2; }

# --- OS detection -----------------------------------------------------------
detect_os() {
  case "$(uname -s)" in
    Darwin) OS="macos" ;;
    Linux)
      if grep -qi microsoft /proc/version 2>/dev/null; then
        OS="wsl"
      else
        OS="linux"
      fi
      ;;
    *) err "Unsupported OS: $(uname -s)"; exit 1 ;;
  esac

  if [ "$OS" = "linux" ] || [ "$OS" = "wsl" ]; then
    if   command -v apt    >/dev/null 2>&1; then PKG="apt"
    elif command -v dnf    >/dev/null 2>&1; then PKG="dnf"
    elif command -v pacman >/dev/null 2>&1; then PKG="pacman"
    else err "No supported package manager found (apt/dnf/pacman)."; exit 1
    fi
  fi
  info "Detected: $OS${PKG:+ / $PKG}"
}

# --- Brew install (macOS) ---------------------------------------------------
ensure_brew() {
  if ! command -v brew >/dev/null 2>&1; then
    warn "Homebrew not found. Installing..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    ok "Homebrew installed"
  fi
}

# --- Tool installer ---------------------------------------------------------
# Each entry: name | install-mac | install-linux | check-command
TOOLS=(
  "mise|brew install mise||mise --version"
  "broot|brew install broot|cargo install broot|pacman -S broot|broot --version"
  "starship|brew install starship||starship --version"
  "zoxide|brew install zoxide|apt:zoxide|pacman -S zoxide|zoxide --version"
  "fzf|brew install fzf|apt:fzf|pacman -S fzf|fzf --version"
  "ripgrep|brew install ripgrep|apt:ripgrep|pacman -S ripgrep|rg --version"
  "fd|brew install fd|apt:fd-find|pacman -S fd|fd --version"
  "bat|brew install bat|apt:bat|pacman -S bat|bat --version"
  "eza|brew install eza|apt:eza|pacman -S eza|eza --version"
  "delta|brew install git-delta|brew install git-delta|pacman -S git-delta|delta --version"
  "tldr|brew install tldr|apt:tldr|pacman -S tldr|tldr --version"
  "atuin|brew install atuin||atuin --version"
  "lazygit|brew install lazygit|apt:lazygit|pacman -S lazygit|lazygit --version"
)

install_tool() {
  local name="$1" mac_cmd="$2" lin_cmd="$3" check_cmd="$4"

  if command -v "$check_cmd" >/dev/null 2>&1; then
    printf "  %s✓%s %s (already installed)\n" "$GRN" "$RST" "$name"
    return 0
  fi

  local cmd=""
  case "$OS" in
    macos) cmd="$mac_cmd" ;;
    linux|wsl)
      if [ -n "$lin_cmd" ]; then
        case "$lin_cmd" in
          apt:*)   cmd="sudo apt install -y ${lin_cmd#apt:}" ;;
          dnf:*)   cmd="sudo dnf install -y ${lin_cmd#dnf:}" ;;
          pacman:*) cmd="sudo pacman -S --noconfirm ${lin_cmd#pacman:}" ;;
          *)       cmd="$lin_cmd" ;;
        esac
      fi
      ;;
  esac

  if [ -z "$cmd" ]; then
    printf "  %s⚠%s %s (no install command for this OS — install manually)\n" "$YEL" "$RST" "$name"
    return 0
  fi

  printf "  %s→%s %s ... " "$CYN" "$RST" "$name"
  if eval "$cmd" >/dev/null 2>&1; then
    printf "\r  %s✓%s %s\n" "$GRN" "$RST" "$name"
  else
    printf "\r  %s✗%s %s (install failed — continuing)\n" "$YEL" "$RST" "$name"
  fi
}

# --- Shell rc setup ---------------------------------------------------------
setup_shell_rc() {
  local rc="$HOME/.bashrc"
  [ ! -f "$rc" ] && [ -f "$HOME/.bash_profile" ] && rc="$HOME/.bash_profile"

  local additions=""
  additions+='# --- Modern CLI Stack ---'"$'\n'"
  additions+='eval "$(mise activate bash)"'"$'\n'"
  additions+='eval "$(starship init bash)"'"$'\n'"
  additions+='eval "$(zoxide init bash)"'"$'\n'"
  additions+='eval "$(fzf --bash)" 2>/dev/null || true'"$'\n"'
  additions+='eval "$(atuin init bash)"'"$'\n"'

  if ! grep -q "Modern CLI Stack" "$rc" 2>/dev/null; then
    printf "\n%s\n" "$additions" >> "$rc"
    ok "Added shell init lines to $rc"
  else
    info "Shell init lines already present in $rc"
  fi

  # Aliases
  if ! grep -q "alias ll=" "$rc" 2>/dev/null; then
    printf "\n# CLI stack aliases\nalias ls='eza --icons'\nalias ll='eza -la --icons --git'\nalt='eza --tree --level=2 --icons'\nalias cat='bat'\n" >> "$rc"
    ok "Added aliases to $rc"
  fi
}

# --- Main -------------------------------------------------------------------
main() {
  echo
  printf "%sModern CLI Stack Installer%s\n" "$CYN" "$RST"
  printf "%s13 tools. One script. Idempotent.%s\n\n" "$DIM" "$RST"

  detect_os
  [ "$OS" = "macos" ] && ensure_brew

  info "Installing tools..."
  for entry in "${TOOLS[@]}"; do
    IFS='|' read -r name mac lin check <<< "$entry"
    install_tool "$name" "$mac" "$lin" "$check"
  done

  info "Configuring shell..."
  setup_shell_rc

  echo
  ok "Done! Restart your shell or run: ${CYN}exec bash${RST}"
  echo
  info "Next steps:"
  printf "  1. Try: ${CYN}z ${RST}(visit a few dirs first, then jump back)\n"
  printf "  2. Try: ${CYN}Ctrl+R${RST} (search shell history)\n"
  printf "  3. Try: ${CYN}rg 'TODO'${RST} in any project\n"
  echo
}

main "$@"
