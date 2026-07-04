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
  (`ls='eza --icons'`, `cat='bat'`) to your shell config file. The
  script picks the right one based on your `$SHELL`: `~/.bashrc` for
  bash, `~/.zshrc` for zsh (which is macOS's default shell). Re-runs
  detect existing blocks and skip them.
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
- Does not touch files outside your shell config (`~/.bashrc` or
  `~/.zshrc`, depending on shell), `~/.config/`, and standard
  package paths

## Flags

```text
bash install-cli-stack.sh --help
```

- `--no-shell-config` (or `-S`): don't modify your shell config.
  Instead, the script prints the additions block (init lines +
  aliases) so you can copy them into your own shell config. Useful
  if you manage your shell via a dotfiles repo, or use a non-bash
  default shell (zsh, fish) and need to adapt the additions.
- `--uninstall` (or `-U`): interactive uninstall. The script scans
  the 13 tools, prompts for each (y/N), detects how the tool was
  installed (brew / apt / dnf / pacman / cargo / GitHub fallback),
  and removes it. At the end it asks to also remove the shell
  config additions (`~/.bashrc` or `~/.zshrc`, depending on shell).
  Run with this flag on the same OS you installed on.
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

## After the install: opening a new shell

The shell config block the script adds (the `# --- Modern CLI Stack ---`
block in your `~/.bashrc` for bash, or `~/.zshrc` for zsh) only takes
effect on a new shell session. The session the script ran in is
unchanged.

Open a new terminal window, or run `exec $SHELL` in the current one
to reload the config. **The prompt will look different.** This is
expected.

### What changes and why

The install script adds 5 eval lines to your shell config, and a
small aliases block. Together they:

- **Replace your prompt with a starship prompt** (this is the
  visible change). Starship is opinionated about format. The new
  prompt is a single arrow (`❯` on macOS / Linux, `>` on Windows)
  preceded by your current working directory. If you prefer the
  default macOS prompt (`username@host path %`), you can either
  uninstall starship, edit your `~/.config/starship.toml`, or
  remove the `eval "$(starship init <shell>)"` line from your
  shell config.
- **Replace `cd` with zoxide's `z`.** `z Documents` jumps to a
  directory named "Documents" (or fuzzy match) instead of trying
  to enter a literal `Documents` subdirectory of the current
  folder. The original `cd` still works. To use it, just type `cd`.
- **Add fzf key bindings** (Ctrl+R for history, Ctrl+T for files,
  Alt+C for directories). These work in any command, not just at
  the prompt.
- **Add atuin for shell history** (replaces the default history
  with a searchable, syncable database). The key binding is
  Ctrl+R, the same as fzf's. Atuin wins on Ctrl+R by default.
- **Add mise for tool version management** (Python, Node, Ruby,
  etc., per-project). The first time you `cd` into a project with
  a `.mise.toml` or `.tool-versions` file, mise will install the
  right tools automatically.

### First check: do the tools work?

Open a new shell and run these commands. Each one should print
a version number, not an error.

```bash
mise --version
starship --version
zoxide --version
fzf --version
atuin --version
ls --version | head -1    # shows eza (via the ls alias)
bat --version
rg --version
fd --version
```

If all of them print version numbers, the install succeeded. If
any of them print "command not found", the binary isn't on your
PATH. Two things to check:

1. **Did you open a new shell?** The session the script ran in
   doesn't see the new PATH changes.
2. **Is the tool installed under `~/.local/bin`?** Tools from
   the GitHub fallback (e.g. on Linux without apt) are installed
   to `~/.local/bin/<tool>`. The script tries to add this to
   your PATH via the `setup_shell_rc` block. If the eval lines
   didn't run, `~/.local/bin` is not on your PATH and the
   binary isn't found. Run `echo $PATH` and check if
   `~/.local/bin` is there.

If a tool is missing, re-run the install script. It
skips tools that are already installed and re-tries only the
missing ones.

### Trying out the workflow

Once the tools respond, try these in a project directory:

```bash
ls        # eza, with icons
ll        # eza with details and git status
bat README.md   # syntax-highlighted file viewer
rg TODO         # ripgrep, fast recursive search
fd .rs          # fd-find, fast file finder
z <name>        # zoxide, smart cd
```

Then open a new shell with `Ctrl+R` and search your history.
That's fzf + atuin, working together.

## How to uninstall

The recommended way is the script's `--uninstall` flag, which prompts
for each tool and the shell config cleanup:

```bash
bash install-cli-stack.sh --uninstall
```

For a fully manual uninstall (no script), see Appendix D — one
command per package manager removes every tool, leaves configs in
place. After uninstall, you can also remove the `# --- Modern CLI
Stack ---` block from your `~/.bashrc`.
