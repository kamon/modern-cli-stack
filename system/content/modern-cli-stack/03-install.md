\newpage

# The Install Script (Do This Once)

Download and **inspect** before running (don't pipe blindly to bash):

```bash
curl -fsSL {{ vars.install_script_url }} -o install-cli-stack.sh
less install-cli-stack.sh      # always read what you're about to run
bash install-cli-stack.sh
```

## What it does

- Installs the 13 tools below via your system package manager (brew
  on macOS, apt/dnf/pacman on Linux).
- Skips tools that are already installed. Safe to re-run.
- Appends the tool init lines (`eval "$(mise activate bash)"`,
  `eval "$(zoxide init bash)"`, etc.) and a few aliases
  (`ls='eza --icons'`, `cat='bat'`) to your `~/.bashrc`. Re-runs detect
  existing blocks and skip them.
- On Apple Silicon running under Rosetta 2, each install retries via
  `arch -arm64` so the ARM64 Homebrew can install tools to
  `/opt/homebrew` even when the script itself is running as x86_64.
- On Linux without a working package manager (e.g. a fresh server
  with no apt/cargo/dnf/pacman), the script prompts per tool to
  download a pre-built binary from the tool's GitHub release. The
  binary is installed to `~/.local/bin/<tool>`. This fallback
  requires network access and a writable home directory.

## What it does NOT do

- Does not change your default shell
- Does not touch files outside `~/.bashrc`, `~/.config/`, and standard
  package paths

## Flags

```text
bash install-cli-stack.sh --help
```

- `--no-shell-config` (or `-S`): don't modify `~/.bashrc`. Instead,
  the script prints the additions block (init lines + aliases) so
  you can copy them into your own shell config. Useful if you manage
  your shell via a dotfiles repo, or use a non-bash default shell
  (zsh, fish) and need to adapt the additions.
- `--uninstall` (or `-U`): interactive uninstall. The script scans
  the 13 tools, prompts for each (y/N), detects how the tool was
  installed (brew / apt / dnf / pacman / cargo / GitHub fallback),
  and removes it. At the end it asks to also remove the `~/.bashrc`
  additions. Run with this flag on the same OS you installed on.
- `-h`, `--help`: show all available flags.

## OS-specific notes

**macOS** — Requires Homebrew. Installs via `brew install ...`. On
Apple Silicon, the script detects Rosetta 2 and uses an `arch -arm64`
fallback for tool installs.

**Linux (Debian/Ubuntu)** — Uses `apt`. Some tools need `cargo install`
fallback if not in repos. If neither works, the script prompts to
download a pre-built binary from the tool's GitHub release.

**Linux (Fedora/RHEL)** — Uses `dnf` + cargo fallback.

**Linux (Arch)** — Uses `pacman` (most tools already in repos).

**WSL (Windows)** — Treat as Linux. Install WSLg for GUI tools.
**Do not run on native PowerShell.**

## How to uninstall

The recommended way is the script's `--uninstall` flag, which prompts
for each tool and the `.bashrc` cleanup:

```bash
bash install-cli-stack.sh --uninstall
```

For a fully manual uninstall (no script), see Appendix D — one
command per package manager removes every tool, leaves configs in
place. After uninstall, you can also remove the `# --- Modern CLI
Stack ---` block from your `~/.bashrc`.
