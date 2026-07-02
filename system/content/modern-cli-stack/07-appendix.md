\newpage

# Appendix A: Cheat Sheet

Quick reference for the 13 tools covered in this PDF.

| # | Tool | What it does | One-liner |
|---|------|--------------|-----------|
| 1 | **mise** | Manages language versions per project | `mise use node@20` |
| 2 | **starship** | Cross-shell prompt | (auto-loads in prompt) |
| 3 | **zoxide** | Smarter `cd` that learns | `z proj` |
| 4 | **fzf** | Fuzzy finder for anything | `Ctrl+R` · `Ctrl+T` · `Alt+C` |
| 5 | **broot** | Interactive tree navigator | `Ctrl+B` |
| 6 | **ripgrep** | Fast code search (respects .gitignore) | `rg "TODO"` |
| 7 | **fd** | Friendly `find` replacement | `fd "\.py$"` |
| 8 | **bat** | Syntax-highlighted `cat` | `bat file.py` |
| 9 | **eza** | Modern `ls` with icons | `ll` |
| 10 | **delta** | Beautiful `git diff` rendering | (auto-loads in `git diff`) |
| 11 | **tldr** | Simplified man pages | `tldr tar` |
| 12 | **atuin** | Searchable shell history | `Ctrl+R` |
| 13 | **lazygit** | Terminal UI for Git | `lazygit` |

> **Tip:** Bookmark this page. You'll come back to it often during your first month.

# Appendix B: Glossary

Key terms used throughout this PDF.

- **Pipe** (`|`) — sends one command's output to another's input.
- **Redirect** (`>` / `<`) — sends output to a file, or reads input from a file.
- **stdin / stdout / stderr** — the three streams every command has: standard input, output, and error.
- **Exit code** — a number (0 = success) returned by every command when it finishes.
- **Prompt** — the `$` (or custom) symbol indicating the shell is ready for input.
- **Shell** — the program that interprets your commands (Bash, Zsh, Fish).
- **Terminal** — the window or UI that runs the shell (Terminal.app, iTerm2, Windows Terminal).
- **TUI** — Text-based User Interface; a GUI that lives entirely in the terminal.
- **REPL** — Read-Eval-Print Loop; the interactive shell itself.
- **Alias** — a shortcut for a longer command (e.g. `alias ll='ls -la'`).
- **Flag** — a switch passed to a command to change its behavior (e.g. `ls -la`).
- **Argument** — a value passed to a command (e.g. `cat file.txt`).
- **Environment variable** — a named value available to every command (e.g. `PATH`, `HOME`, `EDITOR`); set with `export NAME=value` and read with `$NAME`.

# Appendix C: Troubleshooting

- **Tool not found after install?** Restart your shell: `exec bash`
- **Starship prompt empty?** Check `~/.bashrc` has the `eval` line.
- **zoxide doesn't work?** Same — restart shell.
- **Used `--no-shell-config` and tools don't work?** The script didn't
  add the init lines to `~/.bashrc` because you asked it not to.
  Either re-run without the flag, or copy the printed additions
  block into your shell config (`.bashrc`, `.zshrc`, etc.).
- **bat/eza showing as `batcat`/`fdfind`?** Debian aliases. Add to `~/.bashrc`:
  ```bash
  alias bat='batcat'
  alias fd='fdfind'
  ```
- **WSL fonts broken?** Install Nerd Font in Windows Terminal.
- **Permissions errors on Linux?** `sudo` the install. Don't run as root user.
- **On Apple Silicon + Rosetta 2, the install fails with
  "Cannot install under Rosetta 2 in ARM default prefix"?** The
  script retries via `arch -arm64` automatically. If that also fails,
  install the x86 Homebrew manually and re-run:
  `arch -x86_64 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"`.

# Appendix D: Uninstall

Three steps: remove the tools, remove the shell init block, and
(optionally) clean up per-tool config directories.

## Step 1: Remove the tools

### macOS

```bash
brew uninstall mise broot starship zoxide fzf ripgrep fd bat
brew uninstall eza git-delta tldr atuin lazygit
```

### Debian / Ubuntu

```bash
sudo apt remove mise broot zoxide fzf ripgrep fd-find bat
sudo apt remove eza git-delta tldr atuin lazygit
```

(Some tools — `broot`, `starship`, `delta` — may not be in the
default Debian repos. If `apt remove` can't find them, skip
that line — they were probably installed via the script's
`cargo install` fallback or downloaded manually.)

### Fedora / RHEL

```bash
sudo dnf remove mise broot zoxide fzf ripgrep fd-find bat
sudo dnf remove eza git-delta tldr atuin lazygit
```

### Arch / Manjaro

```bash
sudo pacman -Rns mise broot zoxide fzf ripgrep fd bat
sudo pacman -Rns eza git-delta tldr atuin lazygit
```

(`starship`, `delta`, `broot` may not be in the default Arch
repos. If `pacman` can't find them, skip that line — they were
probably installed via the script's `cargo install` fallback.)

## Step 2: Remove the shell init block

The install script appended a `# --- Modern CLI Stack ---` block
to your `~/.bashrc`. To remove it:

```bash
# Show what's there
grep -A 6 "Modern CLI Stack" ~/.bashrc

# Remove the block (and the aliases section after it). The exact
# range depends on how many lines the script added; this example
# removes the init block + 7 lines of aliases = ~16 lines.
# Or use your editor and delete the block manually.
ed ~/.bashrc <<'EOF'
/# --- Modern CLI Stack ---/
.,/# CLI stack aliases/#
/# CLI stack aliases/+1,/# --- Modern CLI Stack ---/-1d
wq
EOF
```

If you used the `--no-shell-config` flag when installing, there's
nothing to remove from `~/.bashrc` (the script never wrote to it).
The init block and aliases are wherever you put them.

## Step 3 (optional): Remove per-tool config

Some tools write their own config to `~/.config/`. The install
script doesn't touch these — they're created on first run by
the tools themselves. If you want a full clean uninstall:

```bash
rm -rf ~/.config/atuin      # shell history DB
rm -rf ~/.config/starship   # prompt config
rm -rf ~/.config/mise       # version manager config
rm -rf ~/.config/broot      # tree navigator history
```

The install script is idempotent: running it again on a fresh
system reproduces the setup. If you've removed the `.bashrc`
block and want to re-install, just run `bash install-cli-stack.sh`
again — it will detect the missing state and re-add everything.

# Appendix E: Resources

- Repo: {{ vars.repo_url }}
- Newsletter: {{ links.newsletter }}
- Twitter: {{ links.twitter }}
- Buy me a coffee: {{ links.coffee }}
- Store: {{ links.store }}
