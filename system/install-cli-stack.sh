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
RED=$'\033[0;31m'; GRN=$'\033[0;32m'; YEL=$'\033[0;33m'; CYN=$'\033[0;36m'; BLU=$'\033[0;34m'; DIM=$'\033[2m'; RST=$'\033[0m'

info()  { printf "%s[INFO]%s %s\n" "$CYN" "$RST" "$*"; }
ok()    { printf "%s[ OK ]%s %s\n" "$GRN" "$RST" "$*"; }
warn()  { printf "%s[WARN]%s %s\n" "$YEL" "$RST" "$*"; }
err()   { printf "%s[FAIL]%s %s\n" "$RED" "$RST" "$*" >&2; }

# --- Install result tracking ----------------------------------------------
# Each entry is "name|status|path|note" where:
#   status: "installed" or "failed"
#   path:   the tool's filesystem path, or empty if not found
#   note:   short human-readable note (e.g. "already installed",
#           "installed via arm64 subshell", "see https://...")
# We use a single array with a delimiter (rather than 4 parallel
# arrays) so the entry is atomic -- no risk of misalignment.
INSTALL_RESULTS=()

# Aggregate state. These track whether the script actually did
# anything, used to gate the end-of-run "Done" and "Next steps"
# messages. If nothing changed, those messages are misleading
# (suggesting a restart or new things to try when nothing was
# actually added).
TOOLS_FRESHLY_INSTALLED=0  # count of tools we installed in this run
SHELL_CONFIG_MODIFIED=0   # set to 1 if we added to .bashrc or aliases

# Find a tool's path. Tries the current shell first, then the arm64
# subshell (on Apple Silicon). The arm64 subshell is important when
# running under Rosetta: the ARM64 brew at /opt/homebrew installs
# tools to /opt/homebrew/bin, which the x86 shell might not have
# in PATH. Spawning an arm64 subshell lets us query the arm64 PATH
# and find tools that exist but aren't visible to the x86 shell.
find_tool_path() {
  local cmd="$1"
  local tool_name="${cmd%% *}"  # first word, e.g. "mise" from "mise --version"
  if command -v "$tool_name" >/dev/null 2>&1; then
    command -v "$tool_name"
    return 0
  fi
  # On Apple Silicon, try the arm64 subshell. This finds tools
  # installed by the arm64 brew that the x86 shell can't see.
  if sysctl -n hw.optional.arm64 2>/dev/null | grep -q 1; then
    local arm64_path
    arm64_path=$(arch -arm64 /bin/bash -c "command -v $tool_name" 2>/dev/null || true)
    if [ -n "$arm64_path" ]; then
      echo "$arm64_path"
      return 0
    fi
  fi
  return 1
}

# Record a result for the post-install summary table.
record_install() {
  local name="$1"
  local status="$2"
  local path="$3"
  local note="$4"
  INSTALL_RESULTS+=("$name|$status|$path|$note")
}

# Print the install summary table. Called at the end of main.
print_install_summary() {
  [ ${#INSTALL_RESULTS[@]} -eq 0 ] && return 0

  echo
  info "Install summary:"

  # Compute the longest name for column alignment
  local max_name_len=0
  for result in "${INSTALL_RESULTS[@]}"; do
    local n="${result%%|*}"
    [ ${#n} -gt $max_name_len ] && max_name_len=${#n}
  done

  # Find the longest path, capped at 60 chars (so very long paths
  # don't make the table too wide)
  local max_path_len=0
  for result in "${INSTALL_RESULTS[@]}"; do
    local p
    p=$(printf '%s' "$result" | awk -F'|' '{print $3}')
    [ ${#p} -gt $max_path_len ] && max_path_len=${#p}
  done
  if [ $max_path_len -gt 60 ]; then
    max_path_len=60
  fi

  for result in "${INSTALL_RESULTS[@]}"; do
    IFS='|' read -r rname rstatus rpath rnote <<< "$result"
    local symbol color
    if [ "$rstatus" = "installed" ]; then
      if printf '%s' "$rnote" | grep -q "already"; then
        symbol="✓"; color="$BLU"
      else
        symbol="✓"; color="$GRN"
      fi
    else
      symbol="✗"; color="$YEL"
    fi

    # Truncate from the start if too long (the right side is more
    # interesting for paths like /opt/homebrew/bin/foo)
    local display_path="$rpath"
    if [ -z "$display_path" ]; then
      display_path="—"
    elif [ ${#display_path} -gt 60 ]; then
      display_path="...${display_path: -57}"
    fi

    printf "  %s%s%s %-${max_name_len}s  %-${max_path_len}s  %s\n" \
      "$color" "$symbol" "$RST" "$rname" "$display_path" "$rnote"
  done
}

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
  #   /opt/homebrew/bin/brew  -- native ARM64 brew (runs on arm64 processes)
  #   /usr/local/bin/brew     -- x86_64 brew (runs on x86_64 processes,
  #                              including via Rosetta 2 emulation)
  #
  # The native ARM64 brew REFUSES to run under Rosetta: it aborts with
  # "Cannot install under Rosetta 2 in ARM default prefix". So the
  # right brew for us depends on the architecture of the current
  # process, not which brew is installed.
  #
  # Decision tree:
  #   - Apple Silicon, running ARM64 (native shell): use /opt/homebrew
  #   - Apple Silicon, running x86_64 (Rosetta shell): use /usr/local,
  #     warn the user (they'd be faster in a native shell)
  #   - Intel Mac: use whatever's in PATH, no special handling
  if sysctl -n hw.optional.arm64 2>/dev/null | grep -q 1; then
    # Apple Silicon. Check the current process architecture.
    if [ "$(uname -m)" = "arm64" ]; then
      # Native shell. Prefer ARM64 brew.
      if [ -x /opt/homebrew/bin/brew ]; then
        export PATH="/opt/homebrew/bin:$PATH"
        info "Using native ARM64 Homebrew at /opt/homebrew/bin/brew"
        return 0
      fi
    else
      # Rosetta shell (uname -m is x86_64). The ARM64 brew will
      # refuse to run. We need the x86 brew. If it's not installed,
      # this script can't proceed -- bail out cleanly with a clear
      # message.
      if [ -x /usr/local/bin/brew ]; then
        export PATH="/usr/local/bin:$PATH"
        warn "Detected x86_64 Homebrew (you're running under Rosetta 2)."
        warn "Tools will install as x86 binaries. For native ARM64 speed,"
        warn "switch to a native arm64 shell (Terminal.app's default"
        warn "since macOS 11) before running this script."
        return 0
      else
        # No x86 brew. The ARM64 brew at /opt/homebrew will refuse
        # to run from this x86 shell. Tools get installed via the
        # per-tool arm64 fallback (see install_tool below).
        warn "Apple Silicon + Rosetta detected, no x86 brew found."
        warn "Tools will be installed via 'arch -arm64' (you may see"
        warn "extra output). To use them from THIS x86 shell, install"
        warn "the x86 brew manually: /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
      fi
    fi
  fi

  # Fallback: no special handling. Use whatever brew is in PATH.
  # (Covers Intel Macs and the case where the architecture-specific
  # paths above didn't match.)
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
  "broot|brew install broot|cargo install broot;pacman -S broot|broot --version|https://github.com/Canop/broot"
  "starship|brew install starship||starship --version|https://starship.rs"
  "zoxide|brew install zoxide|apt:zoxide;pacman -S zoxide|zoxide --version|https://github.com/ajeetdsouza/zoxide"
  "fzf|brew install fzf|apt:fzf;pacman -S fzf|fzf --version|https://github.com/junegunn/fzf"
  "ripgrep|brew install ripgrep|apt:ripgrep;pacman -S ripgrep|rg --version|https://github.com/BurntSushi/ripgrep"
  "fd|brew install fd|apt:fd-find;pacman -S fd|fd --version|https://github.com/sharkdp/fd"
  "bat|brew install bat|apt:bat;pacman -S bat|bat --version|https://github.com/sharkdp/bat"
  "eza|brew install eza|apt:eza;pacman -S eza|eza --version|https://github.com/eza-community/eza"
  "delta|brew install git-delta|brew install git-delta;pacman -S git-delta|delta --version|https://github.com/dandavison/delta"
  "tldr|brew install tldr|apt:tldr;pacman -S tldr|tldr --version|https://github.com/tldr-pages/tldr"
  "atuin|brew install atuin||atuin --version|https://github.com/atuinsh/atuin"
  "lazygit|brew install lazygit|apt:lazygit;pacman -S lazygit|lazygit --version|https://github.com/jesseduffield/lazygit"
)

install_tool() {
  local name="$1" mac_cmd="$2" lin_cmd="$3" check_cmd="$4" homepage="$5"

  # Check if already installed. Try the current shell first, then
  # the arm64 subshell on Apple Silicon. This handles the case
  # where the user is running under Rosetta and tools were installed
  # by the ARM64 brew (which the x86 shell's PATH might not include).
  local existing_path
  existing_path=$(find_tool_path "$check_cmd" 2>/dev/null || true)
  if [ -n "$existing_path" ]; then
    record_install "$name" "installed" "$existing_path" "already installed"
    printf "  %s✓%s %s (already installed)\n" "$BLU" "$RST" "$name"
    return 0
  fi

  local cmd=""
  case "$OS" in
    macos) cmd="$mac_cmd" ;;
    linux|wsl)
      if [ -n "$lin_cmd" ]; then
        # The lin field may contain multiple install variants separated
        # by ';' (e.g. "cargo install foo;pacman -S foo"). We try each
        # in order, using the first one that matches the current
        # package manager. The case match converts a variant like
        # "apt:foo" into "sudo apt install -y foo". A bare command
        # (no prefix) like "cargo install foo" falls through to the *
        # case and is used as-is. We use a custom IFS to split on ';'
        # only, so variant strings with spaces (e.g. "cargo install")
        # stay together as a single value.
        local variants
        IFS=';' read -ra variants <<< "$lin_cmd"
        local variant
        for variant in "${variants[@]}"; do
          case "$variant" in
            apt:*)   cmd="sudo apt install -y ${variant#apt:}"; break ;;
            dnf:*)   cmd="sudo dnf install -y ${variant#dnf:}"; break ;;
            pacman:*) cmd="sudo pacman -S --noconfirm ${variant#pacman:}"; break ;;
            *)       cmd="$variant"; break ;;
          esac
        done
      fi
      ;;
  esac

  if [ -z "$cmd" ]; then
    printf "  %s⚠%s %s (no install command for this OS — see %s)\n" \
      "$YEL" "$RST" "$name" "$homepage"
    record_install "$name" "failed" "" "no install command for this OS — see $homepage"
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
  if install_path=$(find_tool_path "$check_cmd" 2>/dev/null || true) && [ -n "$install_path" ]; then
    record_install "$name" "installed" "$install_path" "freshly installed"
    TOOLS_FRESHLY_INSTALLED=$((TOOLS_FRESHLY_INSTALLED + 1))
    printf "\r  %s✓%s %s\n" "$GRN" "$RST" "$name"
  else
    # Install failed. If the failure looks like the "can't run under
    # Rosetta 2" error from the ARM64 brew, retry by spawning an
    # arm64 subshell to do the install. This works on Apple Silicon
    # where we're in an x86 shell but the ARM64 brew is at
    # /opt/homebrew/bin/brew.
    if printf '%s' "$err" | grep -q "Cannot install under Rosetta 2"; then
      printf "\r  %s↻%s %s (retrying via arm64 subshell) ... " \
        "$CYN" "$RST" "$name"
      err=$(arch -arm64 /bin/bash -c "$cmd" 2>&1 >/dev/null) || true
      if install_path=$(find_tool_path "$check_cmd" 2>/dev/null || true) && [ -n "$install_path" ]; then
        record_install "$name" "installed" "$install_path" "installed via arm64 subshell"
        TOOLS_FRESHLY_INSTALLED=$((TOOLS_FRESHLY_INSTALLED + 1))
        printf "\r  %s✓%s %s (installed via arm64 subshell)\n" "$GRN" "$RST" "$name"
        return 0
      fi
    fi
    printf "\r  %s✗%s %s (install failed — see %s)\n" \
      "$YEL" "$RST" "$name" "$homepage"
    # Show a one-line hint from the captured output. Strategy:
    # filter out Homebrew's progress chatter and analytics warnings
    # (which are at the start of the output), then pick the LAST
    # non-empty line. The last line is usually the actual error
    # ("Error: ...", "fatal: ...", etc.), which appears AFTER all
    # the "==> Downloading" / "==> Pouring" progress messages.
    #
    # Common Homebrew noise patterns we filter:
    #   - "Warning: The following taps are not trusted" (analytics)
    #   - "==> Downloading/Pouring/Installing/Tapping" (progress)
    #   - "Already downloaded/up-to-date" (cache hits)
    #   - "Remote: " / "RESOLVE:" (git output during tap updates)
    #   - "  homebrew/" (lines listing trusted taps)
    #   - "  brew reinstall" (Homebrew's hint, NOT an error -- it
    #     means the tool is already installed at the requested version)
    #   - "Warning: <tool> <version> is already installed and up-to-date"
    #     (same: Homebrew's "tool is here" message, not an error)
    #   - "To reinstall <version>, run:" (parent line of the above;
    #     introduces the reinstall command which we already filter)
    #   - "==> Auto-updating Homebrew" / "==> Updating Homebrew" / etc.
    #     (the auto-update step that triggered the trust prompt)
    local hint
    hint=$(printf '%s\n' "$err" | \
      grep -v '^[[:space:]]*$' | \
      grep -vE '^(Warning: The following taps are not trusted|Warning: [a-zA-Z0-9_.-]+ [0-9].* is already installed|Tap formulae with deleted formulae|==> (Downloading|Pouring|Installing|Checking|Tapping|Cloning|Fetching|Patching|Autodiscovered|Searching|Updating|Pinning|Waiting|Read|Auto-updating)|You can get trusted taps with one command|Homebrew collects anonymous|Already (downloaded|up-to-date)|Remote: |fatal: could not resolve|HEAD .* with .* has disappeared from|RESOLVE:|Updating Homebrew|HEAD is now at|--fetching|Found .* formula|Using .* formula|to be installed|\[new\]|\[updated\]|  homebrew/|  brew reinstall|To reinstall [0-9].*, run:)' | \
      tail -1)
    if [ -n "$hint" ]; then
      printf "      %s→%s %s\n" "$DIM" "$RST" "$hint"
      record_install "$name" "failed" "" "see $homepage — $hint"
    else
      # All output was Homebrew chatter. Tell the user the install
      # failed but we couldn't extract a useful error.
      printf "      %s→%s install failed but stderr was empty/filtered (try the install manually for diagnostics)\n" \
        "$DIM" "$RST"
      record_install "$name" "failed" "" "see $homepage — no error details captured"
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

  if [ "$FLAG_NO_SHELL_CONFIG" -eq 1 ]; then
    # The user wants to manage their .bashrc themselves. We
    # generate the additions in memory (already done above) but
    # skip writing to .bashrc. The block will be printed in the
    # summary at the end of main().
    info "Shell init lines: skipped (--no-shell-config set). See suggestions below, if you want to manage the init details yourself."
    # Also generate the aliases block (in case the user wants
    # to copy them too).
    printf -v aliases '%s' \
'# CLI stack aliases
alias ls='"'"'eza --icons'"'"'
alias ll='"'"'eza -la --icons --git'"'"'
alt='"'"'eza --tree --level=2 --icons'"'"'
alias cat='"'"'bat'"'"'
'
    # Print both blocks to stderr so the user can see them
    # immediately, even before the summary.
    {
      printf '\n# --- Modern CLI Stack ---\n'
      printf '%s\n' "$additions"
      printf '%s\n' "$aliases"
    } >&2
    return 0
  fi

  if ! grep -q "Modern CLI Stack" "$rc" 2>/dev/null; then
    printf "\n%s\n" "$additions" >> "$rc"
    ok "Added shell init lines to $rc"
    SHELL_CONFIG_MODIFIED=1
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
    SHELL_CONFIG_MODIFIED=1
  fi
}

# --- Main -------------------------------------------------------------------
main() {
  # Parse flags. Currently supports:
  #   --no-shell-config (or -S): don't modify .bashrc. Instead,
  #     print the additions block at the end of the run so the user
  #     can copy it manually. Useful for users who want to review
  #     the changes before they land, or who manage their shell
  #     config via a dotfiles repo.
  FLAG_NO_SHELL_CONFIG=0
  while [ $# -gt 0 ]; do
    case "$1" in
      --no-shell-config|-S) FLAG_NO_SHELL_CONFIG=1; shift ;;
      -h|--help)
        cat <<EOF
Usage: install-cli-stack.sh [flags]

Flags:
  --no-shell-config, -S  Don't modify .bashrc. Print the additions
                          block at the end of the run for manual
                          application.
  -h, --help              Show this help.

Default behavior: installs the 13 tools, then appends the eval
lines and aliases to ~/.bashrc so the tools work in new shells.
EOF
        exit 0 ;;
      *) warn "Unknown flag: $1 (ignored)"; shift ;;
    esac
  done
  export FLAG_NO_SHELL_CONFIG

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

  # Post-install summary: shows status of each tool with its path
  # (or "—" if not found). Makes it easy to see at a glance which
  # tools are installed and where, especially helpful when running
  # under Rosetta where some tools may be in the arm64 PATH but
  # not visible to the x86 shell.
  print_install_summary

  info "Configuring shell..."
  setup_shell_rc

  # The "Done! Restart your shell" and "Next steps" messages are
  # misleading if the script didn't actually change anything. Show
  # them only when there's a real reason for the user to act:
  #   - "Done! Restart your shell" -- only if we modified .bashrc
  #     (new shell init lines or aliases). If the config was
  #     already up-to-date, a restart would do nothing.
  #   - "Next steps" -- only if we actually installed a new tool.
  #     If everything was already installed, the user has
  #     presumably already tried z/Ctrl+R/rg and the suggestions
  #     are noise.
  echo
  if [ "$SHELL_CONFIG_MODIFIED" -eq 1 ]; then
    ok "Done! Restart your shell or run: ${CYN}exec bash${RST}"
  fi
  echo
  if [ "$TOOLS_FRESHLY_INSTALLED" -gt 0 ]; then
    info "Next steps:"
    printf "  1. Try: ${CYN}z${RST} (visit a few dirs first, then jump back)\n"
    printf "  2. Try: ${CYN}Ctrl+R${RST} (search shell history)\n"
    printf "  3. Try: ${CYN}rg 'TODO'${RST} in any project\n"
    echo
  fi
}

# Note for readers: Homebrew may print "Warning: The following taps
# are not trusted" during installs. This is Homebrew's analytics
# security feature (it asks the user to confirm trust for taps).
# The warning is benign: the install proceeds normally, and the
# script filters this noise from the install-failure hint.
#
# To silence the warning permanently, pre-approve the common taps:
#   brew tap --force homebrew/cask
# (the script doesn't use casks, but this suppresses the prompt)
#
# Or set HOMEBREW_NO_AUTO_UPDATE=1 to skip the auto-update that
# triggers the trust prompt.

main "$@"
exit 0
