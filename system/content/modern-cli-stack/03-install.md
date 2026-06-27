\newpage

# The Install Script (Do This Once)

Download and **inspect** before running (don't pipe blindly to bash):

```bash
curl -fsSL {{ vars.install_script_url }} -o install-cli-stack.sh
less install-cli-stack.sh      # always read what you're about to run
bash install-cli-stack.sh
```

## What it does

Installs the 13 tools below via your system package manager. Skips tools
that are already installed. Safe to re-run.

## What it does NOT do

- Does not change your default shell
- Does not replace your existing `.bashrc`
- Does not touch files outside `~/.config/` and standard package paths

## OS-specific notes

**macOS** — Requires Homebrew. Installs via `brew install ...`

**Linux (Debian/Ubuntu)** — Uses `apt`. Some tools need `cargo install`
fallback if not in repos.

**Linux (Fedora/RHEL)** — Uses `dnf` + cargo fallback.

**Linux (Arch)** — Uses `pacman` (most tools already in repos).

**WSL (Windows)** — Treat as Linux. Install WSLg for GUI tools.
**Do not run on native PowerShell.**

## How to uninstall

See Appendix A — one command removes every tool, leaves configs in place.
