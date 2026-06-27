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
- **bat/eza showing as `batcat`/`fdfind`?** Debian aliases. Add to `~/.bashrc`:
  ```bash
  alias bat='batcat'
  alias fd='fdfind'
  ```
- **WSL fonts broken?** Install Nerd Font in Windows Terminal.
- **Permissions errors on Linux?** `sudo` the install. Don't run as root user.

# Appendix D: Uninstall

=== macOS ===

```bash
brew uninstall mise broot starship zoxide fzf ripgrep fd bat
brew uninstall eza git-delta tldr atuin lazygit gh
```

=== Debian / Ubuntu ===

```bash
sudo apt remove mise broot zoxide fzf ripgrep fd-find bat
sudo apt remove eza git-delta tldr atuin lazygit gh
```

Config files in `~/.config/` are preserved so re-running the install
restores your setup.

# Appendix E: Resources

- Repo: {{ vars.repo_url }}
- Newsletter: {{ links.newsletter }}
- Community: {{ links.community }}
- Support: {{ links.tip_jar }}
