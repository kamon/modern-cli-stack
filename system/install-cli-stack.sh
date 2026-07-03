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

  # Known binary aliases. Some Linux distros install the tool
  # under a different name than the tool name. For example, on
  # Debian/Ubuntu, the 'fd' apt package is called 'fd-find' and
  # installs a binary called 'fdfind' (not 'fd'). Same for
  # 'bat' (binary is 'batcat'). The script's "is this tool
  # installed" check needs to recognize these aliases.
  #
  # When we find an alias binary but not the primary name, we
  # create a symlink at ~/.local/bin/<primary> -> <alias> so the
  # primary command works. The symlink is what most docs and
  # shell configs reference.
  local alias=""
  case "$tool_name" in
    fd)   alias="fdfind" ;;
    bat)  alias="batcat" ;;
  esac

  # 1. Try the current shell's PATH first (most common case)
  if command -v "$tool_name" >/dev/null 2>&1; then
    command -v "$tool_name"
    return 0
  fi
  # 1b. If the primary name isn't found but a known alias is,
  # create a symlink in ~/.local/bin so the primary name works
  # for future invocations. This handles the case where the
  # user installed fd-find via apt and the binary is at
  # /usr/bin/fdfind -- we symlink ~/.local/bin/fd -> fdfind.
  if [ -n "$alias" ] && command -v "$alias" >/dev/null 2>&1; then
    mkdir -p "$HOME/.local/bin" 2>/dev/null
    if [ ! -e "$HOME/.local/bin/$tool_name" ]; then
      ln -s "$(command -v "$alias")" "$HOME/.local/bin/$tool_name" 2>/dev/null
      if [ $? -eq 0 ]; then
        echo "$HOME/.local/bin/$tool_name"
        return 0
      fi
    elif [ -x "$HOME/.local/bin/$tool_name" ]; then
      # Symlink already exists from a previous run
      echo "$HOME/.local/bin/$tool_name"
      return 0
    fi
    # Couldn't symlink, but the alias binary is available
    command -v "$alias"
    return 0
  fi
  # 2. On Apple Silicon, try the arm64 subshell. This finds tools
  # installed by the arm64 brew that the x86 shell can't see.
  if sysctl -n hw.optional.arm64 2>/dev/null | grep -q 1; then
    local arm64_path
    arm64_path=$(arch -arm64 /bin/bash -c "command -v $tool_name" 2>/dev/null || true)
    if [ -n "$arm64_path" ]; then
      echo "$arm64_path"
      return 0
    fi
  fi
  # 3. Last resort: check the github install dir directly. The
  # GitHub fallback installs to $HOME/.local/bin which may not
  # be in the current shell's PATH. If the binary is there, we
  # know the install succeeded -- the script just can't see it
  # until the user restarts their shell (or runs `exec bash`).
  if [ -x "$HOME/.local/bin/$tool_name" ]; then
    echo "$HOME/.local/bin/$tool_name"
    return 0
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
  "mise|brew install mise|cargo install mise --locked;github:jdx/mise;apt:mise;pacman -S mise|mise --version|https://mise.jdx.dev"
  "broot|brew install broot|cargo install broot --locked;github:Canop/broot;pacman -S broot|broot --version|https://github.com/Canop/broot"
  "starship|brew install starship|cargo install starship --locked;github:starship/starship;pacman -S starship|starship --version|https://starship.rs"
  "zoxide|brew install zoxide|apt:zoxide;cargo install zoxide --locked;github:ajeetdsouza/zoxide;pacman -S zoxide|zoxide --version|https://github.com/ajeetdsouza/zoxide"
  "fzf|brew install fzf|apt:fzf;github:junegunn/fzf;pacman -S fzf|fzf --version|https://github.com/junegunn/fzf"
  "ripgrep|brew install ripgrep|apt:ripgrep;github:BurntSushi/ripgrep;pacman -S ripgrep|rg --version|https://github.com/BurntSushi/ripgrep"
  "fd|brew install fd|apt:fd-find;github:sharkdp/fd;pacman -S fd|fd --version|https://github.com/sharkdp/fd"
  "bat|brew install bat|apt:bat;github:sharkdp/bat;pacman -S bat|bat --version|https://github.com/sharkdp/bat"
  "eza|brew install eza|cargo install eza;github:eza-community/eza;apt:eza;pacman -S eza|eza --version|https://github.com/eza-community/eza"
  "delta|brew install git-delta|cargo install git-delta;github:dandavison/delta;pacman -S git-delta|delta --version|https://github.com/dandavison/delta"
  "tldr|brew install tlrc|github:tldr-pages/tlrc|tldr --version|https://github.com/tldr-pages/tlrc"
  "atuin|brew install atuin|cargo install atuin --locked;github:atuinsh/atuin;pacman -S atuin|atuin --version|https://github.com/atuinsh/atuin"
  "lazygit|brew install lazygit|cargo install lazygit;github:jesseduffield/lazygit;apt:lazygit;pacman -S lazygit|lazygit --version|https://github.com/jesseduffield/lazygit"
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
        # by ';' (e.g. "cargo install foo;github:owner/repo;pacman -S foo").
        # We try each in order, using the first one that:
        #   (a) has its underlying command available, AND
        #   (b) for package-manager variants, the package actually
        #       exists in the repo.
        #
        # The "github:" variant is NOT tried in this loop. It's a
        # fallback that requires user opt-in (per-tool prompt) since
        # it makes a network call to GitHub and downloads a binary
        # the user didn't ask for. See the github_fallback block
        # below.
        #
        # This avoids common failures:
        #   - "cargo: command not found" when cargo isn't installed
        #   - "brew: command not found" on Linux (brew isn't there)
        #   - "E: Unable to locate package" when the apt package doesn't exist
        #   - "error: target not found: foo" on Arch if the package isn't in repos
        #
        # The case match converts a variant like "apt:foo" into
        # "sudo apt install -y foo". A bare command (no prefix) like
        # "cargo install foo" falls through to the * case and is used
        # as-is, after checking that the command (e.g. "cargo") is
        # actually available.
        local variants
        IFS=';' read -ra variants <<< "$lin_cmd"
        local variant
        for variant in "${variants[@]}"; do
          case "$variant" in
            apt:*)
              pkg="${variant#apt:}"
              if command -v apt-cache >/dev/null 2>&1 && \
                 apt-cache show "$pkg" >/dev/null 2>&1; then
                cmd="sudo apt install -y $pkg"
                break
              fi
              ;;
            dnf:*)
              pkg="${variant#dnf:}"
              if command -v dnf >/dev/null 2>&1 && \
                 dnf info "$pkg" >/dev/null 2>&1; then
                cmd="sudo dnf install -y $pkg"
                break
              fi
              ;;
            pacman:*)
              pkg="${variant#pacman:}"
              if command -v pacman >/dev/null 2>&1 && \
                 pacman -Si "$pkg" >/dev/null 2>&1; then
                cmd="sudo pacman -S --noconfirm $pkg"
                break
              fi
              ;;
            github:*)
              # Skip -- handled in the github_fallback block after
              # the main loop. The user gets a per-tool prompt.
              ;;
            *)
              # Bare command (e.g. "cargo install foo"). Check the
              # first word is available before trying.
              first_word=$(echo "$variant" | awk '{print $1}')
              if command -v "$first_word" >/dev/null 2>&1; then
                cmd="$variant"
                break
              fi
              ;;
          esac
        done
      fi
      ;;
  esac

  # GitHub release fallback. This runs AFTER the main variant loop
  # if no other variant matched. It requires user opt-in (per-tool
  # prompt) since it makes a network call to GitHub and downloads
  # a binary the user didn't explicitly ask for.
  #
  # The flow:
  #   1. Scan lin_cmd for any github: variants
  #   2. If none, fall through to "no install command"
  #   3. If at least one github: variant, check curl is available
  #   4. If running interactively, prompt the user
  #   5. If user accepts, call install_from_github_release
  if [ -z "$cmd" ] && [ -n "$lin_cmd" ] && [ "$OS" != "macos" ]; then
    local github_repo=""
    local fallback_variants
    IFS=';' read -ra fallback_variants <<< "$lin_cmd"
    for fv in "${fallback_variants[@]}"; do
      case "$fv" in
        github:*) github_repo="${fv#github:}"; break ;;
      esac
    done
    if [ -n "$github_repo" ] && command -v curl >/dev/null 2>&1; then
      # Make sure ~/.local/bin exists (and is writable) so the
      # user can see the install path before confirming.
      mkdir -p "$HOME/.local/bin" 2>/dev/null || {
        warn "Could not create $HOME/.local/bin -- skipping GitHub fallback for $name"
        return 1
      }

      # Decide whether to prompt. Prompt only if stdin is a TTY
      # (i.e. the user is running interactively). For
      # non-interactive runs (curl|bash, automation), skip
      # github: and report "no install command".
      local proceed=0
      if [ -t 0 ]; then
        printf "  %s?%s %s isn't available via package manager. Download from\n" \
          "$YEL" "$RST" "$name"
        printf "      https://github.com/%s/releases\n" "$github_repo"
        printf "  Install? [Y/n] "
        local answer
        read -r answer
        case "$answer" in
          [nN]|[nN][oO]) proceed=0 ;;
          *)            proceed=1 ;;
        esac
      else
        # Non-interactive (curl|bash, etc.). Skip without
        # prompting. Users can re-run with --interactive if they
        # want the github fallback.
        proceed=0
      fi

      if [ "$proceed" -eq 1 ]; then
        # The status line was already printed by install_tool
        # ("  → name ... "). The install command itself will print
        # "  downloading from GitHub: ..." which is more specific
        # than a static "(downloading from GitHub)" message. So
        # no extra printf here.
        cmd=$(install_from_github_release "$name" "$github_repo" 2>/dev/null) || cmd=""
      fi
    fi
  fi

  if [ -z "$cmd" ]; then
    printf "  %s⚠%s %s (no install command for this OS — see %s)\n" \
      "$YEL" "$RST" "$name" "$homepage"
    record_install "$name" "failed" "" "no install command for this OS — see $homepage"
    return 0
  fi

  printf "  %s→%s %s ... " "$CYN" "$RST" "$name"
  # Run the install command, streaming output to the terminal
  # in real-time (so the user sees the download progress and
  # status) AND capturing it to a file for hint extraction on
  # failure. This is the key difference from a plain $(...)
  # capture: the user gets live feedback ("downloading...",
  # "extracting...", etc.) and the parent script still has the
  # output for filtering.
  #
  # We use a temp file rather than a process substitution so
  # the capture is robust against weird edge cases (the
  # install command might use 'exec' which would close the
  # parent-side file descriptor). PIPESTATUS preserves the
  # install command's exit code through the pipe, but we
  # don't actually use it -- the install_path check below
  # determines success (a tool is installed iff the binary
  # is in PATH or ~/.local/bin).
  local err err_file
  err_file=$(mktemp)
  (eval "$cmd") 2>&1 | tee "$err_file"
  err=$(cat "$err_file")
  rm -f "$err_file"
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

# --- GitHub release installer ----------------------------------------------
# Download a pre-built binary from a GitHub release and install to
# ~/.local/bin. This is the fallback for systems that don't have a
# working package manager (no apt, no cargo, no dnf, no pacman).
#
# Args:
#   $1: tool name (e.g. "mise") -- used for the binary name
#   $2: repo (e.g. "jdx/mise") -- the GitHub owner/repo
#
# Outputs the command to be run by install_tool (so the existing
# error-capture / retry logic applies). The command is a heredoc
# that does the full install: curl API -> parse asset URL -> download
# -> extract -> install.
#
# Returns 0 if a usable asset was found, 1 otherwise.
install_from_github_release() {
  local tool_name="$1"
  local repo="$2"
  local install_dir="${HOME}/.local/bin"

  # Make sure ~/.local/bin exists. The check in install_tool
  # should have already done this, but belt-and-suspenders.
  mkdir -p "$install_dir" 2>/dev/null || {
    echo "# could not create $install_dir" >&2
    return 1
  }

  # Fetch the latest release JSON. The API is unauthenticated but
  # rate-limited (60 req/hour per IP). The script makes 13 calls
  # (one per tool) which is well under the limit.
  local api_url="https://api.github.com/repos/${repo}/releases/latest"
  local release_json
  release_json=$(curl -sL --max-time 30 "$api_url" 2>/dev/null) || {
    echo "# curl failed: $api_url" >&2
    return 1
  }

  # Detect architecture for asset selection
  local arch
  case "$(uname -m)" in
    x86_64)  arch="x86_64" ;;
    aarch64|arm64) arch="aarch64" ;;
    *)       arch="$(uname -m)" ;;
  esac

  # Find the right asset. Each repo names its assets differently,
  # so we use heuristics:
  #   - prefer "linux" + arch (x86_64 / amd64 / aarch64 / arm64)
  #   - prefer .tar.gz, .tgz, or .zip
  #   - avoid .deb / .rpm / .msi / .dmg / .pkg (we install manually)
  #   - avoid "musl" if a non-musl is available (glibc is more common)
  #   - avoid "debug" or "sha" / "sig" / "asc" files
  #
  # We use grep to extract browser_download_url entries, then awk
  # to score each by the heuristics above. This is fragile by
  # design -- if a release names its assets unusually, the user
  # gets a clear error and can install manually.
  local asset_url
  asset_url=$(printf '%s\n' "$release_json" | \
    grep -oE '"browser_download_url":\s*"[^"]+"' | \
    sed -E 's/^"browser_download_url":[ \t]*"//;s/"$//' | \
    awk -v arch="$arch" -v tool="$tool_name" '
      BEGIN { IGNORECASE = 1 }
      # Skip obviously wrong assets
      /\.deb$/ || /\.rpm$/ || /\.msi$/ || /\.dmg$/ || /\.pkg$/ || \
      /\.sig$/ || /\.asc$/ || /\.sha/ || /\.sha256/ || /\.sha512/ || \
      /\/install\.sh/ || /\/install\.ps1/ || /debug/ { next }
      {
        score = 0
        url = $0
        # Linux/Unix detection: prefer explicit linux, but also
        # accept anything with an arch suffix (x86_64, x64, amd64,
        # aarch64, arm64) and no .dmg/.msi (already filtered above).
        if (url ~ /linux/) score += 6
        if (url ~ /darwin/ || url ~ /macos/ || url ~ /osx/ || url ~ /apple/) score -= 4
        if (url ~ /windows/ || url ~ /win32/ || url ~ /_win/ || url ~ /\.exe/) score -= 4
        # Architecture matching -- be generous with naming variants
        if (url ~ "x86_64" || url ~ /x86-64/ || url ~ "x64" || url ~ "amd64") {
          if (arch == "x86_64") score += 12
        }
        if (url ~ "aarch64" || url ~ "arm64") {
          if (arch == "aarch64") score += 12
        }
        if (url ~ /i[36]86/ || url ~ /i686/) score += 1
        if (url ~ /armv7/) score += 1
        # Prefer the tool name as a path component followed by a
        # version/arch segment. The pattern: tool name + (-/v/_/.digit)
        # where the next char is a digit (version like v1.0.0 or 1.0.0)
        # or the tool name is the final segment before the extension.
        # This avoids false matches like 'atuin-server' for 'atuin':
        # the regex requires the tool name to be followed by either
        # '-v' + digit (versioned), '-' + digit (e.g. eza-0.23.4), or
        # '_v' + digit (uncommon but possible).
        if (url ~ ("^[^/]*/" tool "[-_]v[0-9]") || \
            url ~ ("/" tool "[-_]v[0-9]") || \
            url ~ ("^[^/]*/" tool "[-_][0-9]") || \
            url ~ ("/" tool "[-_][0-9]") || \
            url ~ ("/" tool "\\.[a-z]")) score += 8
        # Archive format preferences: .tar.gz > .tar.xz > .zip
        if (url ~ /\.tar\.gz$/ || url ~ /\.tgz$/) score += 5
        else if (url ~ /\.tar\.xz$/ || url ~ /\.txz$/) score += 4
        else if (url ~ /\.zip$/) score += 3
        # Penalty for musl (prefer glibc when both are available)
        if (url ~ /musl/) score -= 4
        # Penalty for "-server" suffix (e.g. atuin-server vs
        # atuin). The user wants the CLI binary, not the server.
        if (url ~ (tool "-server")) score -= 10
        # Bonus for "no_libgit" variants on Linux (eza-specific
        # naming; these are the standalone binaries)
        if (url ~ /no_libgit/) score += 2
        if (score > best) { best = score; best_url = url }
      }
      END { if (best_url) print best_url }
    ')

  if [ -z "$asset_url" ]; then
    echo "# no suitable linux asset found for $repo (arch=$arch)" >&2
    return 1
  fi

  # Emit the install command. The script's existing error-capture
  # (2>&1 >/dev/null) will swallow the verbose output and put any
  # errors in $err for the hint display.
  #
  # IMPORTANT: the heredoc is unquoted, so $... and $(...) are
  # expanded NOW (when cat reads the heredoc). Variables that should
  # be evaluated at install time (tmpdir, binary, mktemp) are
  # escaped with \$ to defer their expansion. Variables that
  # should be evaluated now ($install_dir, $tool_name, $asset_url)
  # are left unescaped.
  cat <<INSTALL_CMD
# Note: set -e is intentionally NOT used here. We want to capture
# errors and report them via the parent script's hint filter, not
# silently exit on the first failure.
tmpdir=\$(mktemp -d) || { echo "could not create temp dir" >&2; exit 1; }
cd "\$tmpdir"
echo "  downloading from GitHub: $asset_url"
if ! curl -fLs --max-time 120 -o asset "$asset_url" 2>&1; then
  echo "  curl failed: download error or non-200 status" >&2
  exit 1
fi
if [ ! -s asset ]; then
  echo "  downloaded file is empty" >&2
  exit 1
fi
# Detect archive type and extract
file_type=\$(file asset)
if echo "\$file_type" | grep -q 'gzip compressed'; then
  tar -xzf asset 2>&1 || { echo "  tar extraction failed" >&2; exit 1; }
elif echo "\$file_type" | grep -q 'Zip archive'; then
  unzip -q asset 2>&1 || { echo "  unzip failed" >&2; exit 1; }
elif echo "\$file_type" | grep -q 'XZ compressed'; then
  tar -xJf asset 2>&1 || { echo "  tar (xz) extraction failed" >&2; exit 1; }
elif echo "\$file_type" | grep -q 'bzip2 compressed'; then
  tar -xjf asset 2>&1 || { echo "  tar (bz2) extraction failed" >&2; exit 1; }
else
  # Not a known archive type. If it's an executable, install as-is.
  if [ -x asset ]; then
    install -m 755 asset "$install_dir/$tool_name" || { echo "  install failed" >&2; exit 1; }
    echo "  installed as flat binary"
  else
    echo "  unrecognized file type: \$file_type" >&2
    echo "  (not an archive, and not an executable)" >&2
    exit 1
  fi
  cd /
  rm -rf "\$tmpdir"
  exit 0
fi
# Find the binary in the extracted contents. Some tools ship
# multiple platform binaries in one archive (e.g. broot has
# aarch64/, x86_64/, etc. subdirs). Prefer the one matching the
# current arch, then fall back to any executable matching the
# tool name, then to any executable.
arch_dir=\$(uname -m)
case "\$arch_dir" in
  x86_64)  arch_dir="x86_64" ;;
  aarch64|arm64) arch_dir="aarch64" ;;
  *)       arch_dir="" ;;
esac
binary=""
if [ -n "\$arch_dir" ]; then
  binary=\$(find . -type f -perm -u+x -name "$tool_name" -path "*/\$arch_dir/*" 2>/dev/null | head -1)
fi
if [ -z "\$binary" ]; then
  binary=\$(find . -type f -perm -u+x -name "$tool_name" 2>/dev/null | head -1)
fi
if [ -z "\$binary" ]; then
  binary=\$(find . -type f -perm -u+x 2>/dev/null | head -1)
fi
if [ -z "\$binary" ]; then
  echo "  no executable named '$tool_name' found in archive" >&2
  echo "  archive contents:" >&2
  find . -type f | head -20 | sed 's/^/    /' >&2
  exit 1
fi
# Use the binary's actual filename (basename) so the installed
# command matches the binary's name. For ripgrep, the binary is
# 'rg' but the tool name is 'ripgrep' -- so we install as 'rg'.
binary_name=\$(basename "\$binary")
install -m 755 "\$binary" "$install_dir/\$binary_name" || { echo "  install failed" >&2; exit 1; }
cd /
rm -rf "\$tmpdir"
INSTALL_CMD
  return 0
}

# --- Uninstall: remove a single tool ----------------------------------------
# Detects how a tool was installed (brew, apt, dnf, pacman,
# cargo, or the GitHub fallback at ~/.local/bin) and runs the
# appropriate uninstall command. Returns 0 on success, 1 on
# failure.
#
# Args:
#   $1: tool name (e.g. "mise")
#   $2: mac install command (e.g. "brew install mise") -- used
#       to extract the brew package name
#   $3: linux install variants (e.g. "apt:mise;cargo install mise")
#   $4: check command (e.g. "mise --version")
#   $5: github repo (for the GitHub fallback case)
#   $6: path to the installed binary (from find_tool_path)
uninstall_tool() {
  local name="$1"
  local mac_cmd="$2"
  local lin_cmd="$3"
  local check_cmd="$4"
  local github_repo="$5"
  local tool_path="$6"
  local tool_name="${check_cmd%% *}"

  printf "  %s↻%s Removing %s ...\n" "$CYN" "$RST" "$name"

  # Detect install path by looking at where the binary lives.
  case "$tool_path" in
    */homebrew/*|*/Cellar/*|/usr/local/bin/*)
      # brew (macOS or Linuxbrew)
      local brew_pkg
      brew_pkg=$(echo "$mac_cmd" | awk '{print $3}')
      if [ -n "$brew_pkg" ] && command -v brew >/dev/null 2>&1; then
        if brew uninstall "$brew_pkg" 2>/dev/null; then
          ok "Uninstalled $name (brew: $brew_pkg)"
          return 0
        fi
      fi
      warn "Could not uninstall $name via brew. Try manually: brew uninstall $brew_pkg"
      return 1
      ;;

    */.cargo/bin/*|*/cargo/bin/*)
      # cargo install -- no built-in uninstall, just remove the file
      if [ -f "$tool_path" ]; then
        rm -f "$tool_path"
        ok "Removed $name (cargo binary at $tool_path)"
        return 0
      fi
      warn "Could not find $name at $tool_path"
      return 1
      ;;

    */.local/bin/*)
      # GitHub fallback install
      if [ -f "$tool_path" ]; then
        rm -f "$tool_path"
        ok "Removed $name (GitHub fallback at $tool_path)"
      fi
      # Also remove the alias symlink if present (fd -> fdfind, bat -> batcat)
      case "$tool_name" in
        fd)  rm -f "$HOME/.local/bin/fd"  ;;
        bat) rm -f "$HOME/.local/bin/bat" ;;
      esac
      return 0
      ;;

    /usr/bin/*|/bin/*|/usr/sbin/*|/usr/local/sbin/*)
      # System package manager. Try apt, dnf, pacman in order.
      # The package name may differ from the tool name (e.g.
      # apt:fd-find installs the binary fdfind).

      if command -v apt-get >/dev/null 2>&1; then
        local apt_pkg
        apt_pkg=$(echo "$lin_cmd" | tr ';' ' ' | awk '{for(i=1;i<=NF;i++) if($i ~ /^apt:/) {print substr($i,5)}}' | head -1)
        if [ -n "$apt_pkg" ] && dpkg -l "$apt_pkg" >/dev/null 2>&1; then
          if sudo apt remove -y "$apt_pkg" 2>/dev/null; then
            ok "Uninstalled $name (apt: $apt_pkg)"
            return 0
          fi
        fi
      fi

      if command -v dnf >/dev/null 2>&1; then
        local dnf_pkg
        dnf_pkg=$(echo "$lin_cmd" | tr ';' ' ' | awk '{for(i=1;i<=NF;i++) if($i ~ /^dnf:/) {print substr($i,5)}}' | head -1)
        if [ -n "$dnf_pkg" ] && rpm -q "$dnf_pkg" >/dev/null 2>&1; then
          if sudo dnf remove -y "$dnf_pkg" 2>/dev/null; then
            ok "Uninstalled $name (dnf: $dnf_pkg)"
            return 0
          fi
        fi
      fi

      if command -v pacman >/dev/null 2>&1; then
        local pacman_pkg
        pacman_pkg=$(echo "$lin_cmd" | tr ';' ' ' | awk '{for(i=1;i<=NF;i++) if($i ~ /^pacman:/) {print substr($i,8)}}' | head -1)
        if [ -n "$pacman_pkg" ] && pacman -Q "$pacman_pkg" >/dev/null 2>&1; then
          if sudo pacman -Rns --noconfirm "$pacman_pkg" 2>/dev/null; then
            ok "Uninstalled $name (pacman: $pacman_pkg)"
            return 0
          fi
        fi
      fi

      # Last resort: use dpkg -S to find which package owns the
      # binary, then remove that package
      if command -v dpkg >/dev/null 2>&1; then
        local owner
        owner=$(dpkg -S "$tool_path" 2>/dev/null | awk '{print $1}' | sed 's/:$//' | head -1)
        if [ -n "$owner" ] && [ "$owner" != "dpkg" ]; then
          if sudo apt remove -y "$owner" 2>/dev/null; then
            ok "Uninstalled $name (apt: $owner -- found via dpkg -S)"
            return 0
          fi
        fi
      fi
      warn "Could not determine install method for $name. Try: sudo apt remove <pkg> or rm $tool_path"
      return 1
      ;;

    *)
      # Unknown install path. Just try to remove the file.
      if [ -f "$tool_path" ]; then
        rm -f "$tool_path"
        ok "Removed $name (file at $tool_path)"
        return 0
      fi
      warn "Unknown install location for $name: $tool_path"
      return 1
      ;;
  esac
}

# --- Uninstall: remove the .bashrc additions -------------------------------
# Removes the block the install script added. The block
# starts with the marker '# --- Modern CLI Stack ---' and
# runs through the aliases section. We use sed to delete
# from the marker through the next blank line.
uninstall_shell_rc() {
  local rc="$HOME/.bashrc"
  [ ! -f "$rc" ] && [ -f "$HOME/.bash_profile" ] && rc="$HOME/.bash_profile"

  if [ ! -f "$rc" ]; then
    info "No .bashrc or .bash_profile found -- nothing to remove."
    return 0
  fi

  if ! grep -q "Modern CLI Stack" "$rc" 2>/dev/null; then
    info "No Modern CLI Stack block found in $rc -- nothing to remove."
    return 0
  fi

  # Use sed to delete from the marker line through the next
  # blank line. This removes the eval lines block and the
  # trailing blank line that separates it from the aliases.
  # We also delete the aliases block that follows.
  local rc_backup="$rc.uninstall-backup.$$"
  cp "$rc" "$rc_backup" || {
    warn "Could not back up $rc. Aborting .bashrc cleanup."
    return 1
  }

  # Remove the Modern CLI Stack block: from the marker through
  # the line containing 'alias cat=' (the last line of the
  # aliases block we added).
  if sed -i.tmp \
      -e '/# --- Modern CLI Stack ---/,/alias cat=/d' \
      "$rc" 2>/dev/null; then
    rm -f "$rc.tmp"
    ok "Removed Modern CLI Stack block from $rc (backup at $rc_backup)"
    return 0
  else
    # Restore the backup if sed failed
    mv "$rc_backup" "$rc"
    warn "sed failed to edit $rc. File unchanged."
    return 1
  fi
}

# --- Uninstall: orchestrator ------------------------------------------------
# Loops over TOOLS, finds which are installed, prompts the
# user for each, and runs uninstall_tool on the accepted ones.
# At the end, prompts to remove the .bashrc additions.
run_uninstall() {
  local uninstalled=0
  local skipped=0
  local failed=0

  info "Checking which tools are currently installed..."

  for entry in "${TOOLS[@]}"; do
    IFS='|' read -r name mac lin check url <<< "$entry"

    # Find the tool's path. find_tool_path handles PATH, arm64
    # subshell, and the ~/.local/bin fallback.
    local tool_path
    tool_path=$(find_tool_path "$check" 2>/dev/null || true)
    if [ -z "$tool_path" ]; then
      skipped=$((skipped + 1))
      continue
    fi

    printf "\n  %s?%s %s found at: %s\n" \
      "$YEL" "$RST" "$name" "$tool_path"

    if [ ! -t 0 ]; then
      # Non-interactive (curl|bash etc.). Skip without prompting.
      info "Non-interactive -- skipping $name."
      skipped=$((skipped + 1))
      continue
    fi

    printf "  Uninstall? [y/N] "
    local answer
    read -r answer
    case "$answer" in
      [yY]|[yY][eE][sS])
        if uninstall_tool "$name" "$mac" "$lin" "$check" "$url" "$tool_path"; then
          uninstalled=$((uninstalled + 1))
        else
          failed=$((failed + 1))
        fi
        ;;
      *)
        info "Skipped $name."
        skipped=$((skipped + 1))
        ;;
    esac
  done

  # .bashrc cleanup
  echo
  if [ -t 0 ]; then
    printf "  %s?%s Remove the Modern CLI Stack block from .bashrc? [y/N] " \
      "$YEL" "$RST"
    local answer
    read -r answer
    case "$answer" in
      [yY]|[yY][eE][sS])
        uninstall_shell_rc
        ;;
      *)
        info "Skipped .bashrc cleanup."
        ;;
    esac
  else
    info "Non-interactive -- skipping .bashrc cleanup."
  fi

  # Per-tool config cleanup hint
  echo
  info "Optional manual cleanup (not done automatically):"
  printf "    %srm -rf ~/.config/atuin ~/.config/starship ~/.config/mise ~/.config/broot%s\n" \
    "$DIM" "$RST"
  echo
  ok "Uninstall complete. Removed: $uninstalled | Skipped: $skipped | Failed: $failed"
}

# --- Main -------------------------------------------------------------------
main() {
  # Parse flags. Currently supports:
  #   --no-shell-config (or -S): don't modify .bashrc. Instead,
  #     print the additions block at the end of the run so the user
  #     can copy it manually. Useful for users who want to review
  #     the changes before they land, or who manage their shell
  #     config via a dotfiles repo.
  #   --uninstall (or -U): interactive uninstall. Prompts for each
  #     tool before removing it. Also removes the .bashrc additions
  #     (with its own prompt). This is the reverse of the default
  #     install flow.
  FLAG_NO_SHELL_CONFIG=0
  FLAG_UNINSTALL=0
  while [ $# -gt 0 ]; do
    case "$1" in
      --no-shell-config|-S) FLAG_NO_SHELL_CONFIG=1; shift ;;
      --uninstall|-U)       FLAG_UNINSTALL=1; shift ;;
      -h|--help)
        cat <<EOF
Usage: install-cli-stack.sh [flags]

Flags:
  --no-shell-config, -S  Don't modify .bashrc. Print the additions
                          block at the end of the run for manual
                          application.
  --uninstall, -U         Interactive uninstall. Prompts for each
                          tool before removing it. Also removes
                          the .bashrc additions. Run with this
                          flag on the same OS you installed on.
  -h, --help              Show this help.

Default behavior: installs the 13 tools, then appends the eval
lines and aliases to ~/.bashrc so the tools work in new shells.
EOF
        exit 0 ;;
      *) warn "Unknown flag: $1 (ignored)"; shift ;;
    esac
  done
  export FLAG_NO_SHELL_CONFIG
  export FLAG_UNINSTALL

  # Branch into uninstall flow if --uninstall was passed
  if [ "$FLAG_UNINSTALL" -eq 1 ]; then
    echo
    printf "%sModern CLI Stack Uninstaller%s\n" "$CYN" "$RST"
    printf "%sInteractive -- prompts before each removal.%s\n\n" "$DIM" "$RST"
    detect_os  # needed for uninstall_tool's package-manager dispatch
    run_uninstall
    exit 0
  fi

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
