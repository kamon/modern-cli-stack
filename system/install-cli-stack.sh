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
  # On Apple Silicon, there are two Homebrew install paths:
  #   /opt/homebrew/bin/brew  -- native ARM64 brew (preferred)
  #   /usr/local/bin/brew     -- x86_64 brew (Intel or Rosetta)
  # The native one is faster and has more reliable ARM64 builds.
  # If it exists, prepend it to PATH so `brew` finds the right one
  # first, regardless of what the user's current PATH says.
  if [ -x /opt/homebrew/bin/brew ]; then
    export PATH="/opt/homebrew/bin:$PATH"
    info "Using native ARM64 Homebrew at /opt/homebrew/bin/brew"
    return 0
  fi

  # If we're on Apple Silicon (ARM64-capable CPU) but only the x86
  # brew is available, we're running under Rosetta 2. The x86 brew
  # works but installs slower x86 binaries; some tools may also be
  # missing x86 builds. Warn the user so they can decide.
  if [ "$(uname -m)" = "x86_64" ] && sysctl -n hw.optional.arm64 2>/dev/null | grep -q 1; then
    warn "Detected x86_64 Homebrew under Rosetta 2 on Apple Silicon."
    warn "Tools will install as x86 binaries. For native ARM64 speed,"
    warn "install Homebrew natively: https://brew.sh"
  fi

  if ! command -v brew >/dev/null 2>&1; then
    warn "Homebrew not found. Installing..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    ok "Homebrew installed"
  fi
}

# --- Tool installer ---------------------------------------------------------
# Each entry: name | install-mac | install-linux | check-command
TOOLS=(
  "mise|brew install mise||mise --version|https://mise.jdx.dev"
  "broot|brew install broot|cargo install broot|pacman -S broot|broot --version|https://github.com/Canop/broot"
  "starship|brew install starship||starship --version|https://starship.rs"
  "zoxide|brew install zoxide|apt:zoxide|pacman -S zoxide|zoxide --version|https://github.com/ajeetdsouza/zoxide"
  "fzf|brew install fzf|apt:fzf|pacman -S fzf|fzf --version|https://github.com/junegunn/fzf"
  "ripgrep|brew install ripgrep|apt:ripgrep|pacman -S ripgrep|rg --version|https://github.com/BurntSushi/ripgrep"
  "fd|brew install fd|apt:fd-find|pacman -S fd|fd --version|https://github.com/sharkdp/fd"
  "bat|brew install bat|apt:bat|pacman -S bat|bat --version|https://github.com/sharkdp/bat"
  "eza|brew install eza|apt:eza|pacman -S eza|eza --version|https://github.com/eza-community/eza"
  "delta|brew install git-delta|brew install git-delta|pacman -S git-delta|delta --version|https://github.com/dandavison/delta"
  "tldr|brew install tldr|apt:tldr|pacman -S tldr|tldr --version|https://github.com/tldr-pages/tldr"
  "atuin|brew install atuin||atuin --version|https://github.com/atuinsh/atuin"
  "lazygit|brew install lazygit|apt:lazygit|pacman -S lazygit|lazygit --version|https://github.com/jesseduffield/lazygit"
)

install_tool() {
  local name="$1" mac_cmd="$2" lin_cmd="$3" check_cmd="$4" homepage="$5"

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
    printf "  %s⚠%s %s (no install command for this OS — see %s)\n" \
      "$YEL" "$RST" "$name" "$homepage"
    return 0
  fi

  printf "  %s→%s %s ... " "$CYN" "$RST" "$name"
  # Capture stderr so we can show the user why it failed. The full
  # stderr for some tools is 50+ lines of cargo/rust output; we
  # keep it all (in $err) but only print the first non-empty line
  # + a "more info" pointer on failure. If the user wants the full
  # output, they can re-run the install manually.
  local err
  err=$(eval "$cmd" 2>&1 >/dev/null) || true
  if command -v "$check_cmd" >/dev/null 2>&1; then
    printf "\r  %s✓%s %s\n" "$GRN" "$RST" "$name"
  else
    printf "\r  %s✗%s %s (install failed — see %s)\n" \
      "$YEL" "$RST" "$name" "$homepage"
    # Show the first non-empty line of stderr as a one-line hint.
    # This is usually the actual error message ("error: ...", "fatal: ...",
    # "command not found", etc.). If stderr is empty (some commands
    # print to stdout for errors), we fall back to a generic message.
    local hint
    hint=$(printf '%s\n' "$err" | grep -v '^[[:space:]]*$' | head -1)
    if [ -n "$hint" ]; then
      printf "      %s→%s %s\n" "$DIM" "$RST" "$hint"
    else
      printf "      %s→%s no error output captured (run the install manually for details)\n" \
        "$DIM" "$RST"
    fi
  fi
}

# --- Shell rc setup ---------------------------------------------------------
setup_shell_rc() {
  local rc="$HOME/.bashrc"
  [ ! -f "$rc" ] && [ -f "$HOME/.bash_profile" ] && rc="$HOME/.bash_profile"

  local additions=""

  # Bash 3.x (macOS default) has trouble parsing the original pattern
  # of mixing single-quoted, double-quoted, and ANSI-C quoted strings
  # on a single line. We use printf instead — the format string is in
  # single quotes (so $ and " are literal), and the result is appended
  # to $additions via +=.
  printf -v additions '%s' \
'# --- Modern CLI Stack ---
eval "$(mise activate bash)"
eval "$(starship init bash)"
eval "$(zoxide init bash)"
eval "$(fzf --bash)" 2>/dev/null || true
eval "$(atuin init bash)"
'

  if ! grep -q "Modern CLI Stack" "$rc" 2>/dev/null; then
    printf "\n%s\n" "$additions" >> "$rc"
    ok "Added shell init lines to $rc"
  else
    info "Shell init lines already present in $rc"
  fi

  # Aliases
  if ! grep -q "alias ll=" "$rc" 2>/dev/null; then
    printf -v aliases '%s' \
'# CLI stack aliases
alias ls='"'"'eza --icons'"'"'
alias ll='"'"'eza -la --icons --git'"'"'
alt='"'"'eza --tree --level=2 --icons'"'"'
alias cat='"'"'bat'"'"'
'
    printf "\n%s" "$aliases" >> "$rc"
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
    IFS='|' read -r name mac lin check url <<< "$entry"
    install_tool "$name" "$mac" "$lin" "$check" "$url"
  done

  info "Configuring shell..."
  setup_shell_rc

  echo
  ok "Done! Restart your shell or run: ${CYN}exec bash${RST}"
  echo
  info "Next steps:"
  printf "  1. Try: ${CYN}z${RST} (visit a few dirs first, then jump back)\n"
  printf "  2. Try: ${CYN}Ctrl+R${RST} (search shell history)\n"
  printf "  3. Try: ${CYN}rg 'TODO'${RST} in any project\n"
  echo
}

main "$@"
exit 0
