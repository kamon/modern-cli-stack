# Modern CLI Stack — PDF Outline

**Working title:** *The Modern CLI Stack: 12 Tools That Replaced My 200-Line .bashrc*
**Subtitle:** *A Beginner's Field Guide to a Faster Terminal — for macOS, Linux, and Windows (WSL)*
**Format:** PDF, ~6-8 pages, designed (cover + sections), A4/Letter
**Tone:** Friendly, opinionated, junior-friendly — assumes zero CLI knowledge
**Length target:** 2,500-3,500 words in the body
**Companion file:** `install-cli-stack.sh` (referenced, not inline)

---

## Page 1 — Cover

**Visual:** Terminal screenshot showing the curated stack in action (zoxide prompt, fzf fuzzy search, ripgrep-in-fzf with preview, delta-rendered git diff). Clean dark background, one accent color.

**Title block:**
- Logo/wordmark (optional): `MODERN CLI STACK`
- Headline: *The 12 Tools That Replaced My 200-Line .bashrc*
- Subhead: *A Beginner's Field Guide to a Faster Terminal*
- Author line (placeholder): `Your Name · @yourhandle`
- Edition: `v2026.1 · macOS · Linux · WSL`
- Footer: `Free PDF · Companion script inside`

**Back of cover (page 2):**
- One-paragraph "Why this exists"
- "What's in this PDF" (bullet list)
- "How to use this PDF" (3 quick steps)
- License (CC BY-NC-SA 4.0 recommended — attribution, share-alike, no commercial reuse)
- "If this helps, buy me a coffee" → Gumroad tip jar link
- Email signup for newsletter (or Skool link)

---

## Page 2 — Intro (Front matter, optional)

**Headline:** *Why your terminal is slow (and how to fix it in one afternoon)*

**Body (~250 words):**
- The problem: most engineers inherit a default shell from 1995 and wonder why the terminal feels painful.
- The promise: 12 modern, actively-maintained tools that drop into Bash and immediately make navigation, search, history, and git feel 5-10x faster.
- Who this is for: junior devs, bootcamp grads, career switchers, anyone still typing `cd ~/projects/foo/bar` 40 times a day.
- Who this is NOT for: senior engineers already on a tuned stack — feel free to skim.
- What you'll do: read (10 min), run one script (5 min), try each tool once (15 min). Total: 30 minutes to a better terminal for life.

**Three callouts (icons):**
- 🟢 **Beginner-friendly** — every term defined, no assumed knowledge
- ⚡ **One-line installs** — Homebrew, apt, dnf, or a single bootstrap script
- 🔄 **Reversible** — every tool is opt-in; nothing changes your default shell

---

## Page 3 — Section 1: Mental Models (Read This First)

**Purpose:** Junior-friendly foundation. If the reader understands these 4 concepts, every tool below will make sense.

### 1.1 — What "the terminal" actually is
- The shell (Bash) is a program that interprets text commands.
- Your terminal app (Terminal.app, iTerm2, Windows Terminal, GNOME Terminal) is just the *window* that runs the shell.
- Prompt: `$` = shell is ready for input. You'll see this everywhere.

### 1.2 — Pipes: the most important idea in Unix
- `|` takes the **output** of one command and feeds it as **input** to the next.
- Example walkthrough: `cat file.txt | grep "error" | wc -l` — show file → grep → count.
- Analogy: assembly line. Each station does one thing.

### 1.3 — Exit codes: silent signals
- Every command returns a number when it finishes. `0` = success, anything else = something went wrong.
- Why this matters: tools like `&&` and `||` chain commands based on success/failure.
- `command1 && command2` = "run command2 only if command1 succeeded"
- `command1 || command2` = "run command2 only if command1 failed"

### 1.4 — Streams: stdin, stdout, stderr
- **stdin** (input) — keyboard, or previous command's pipe
- **stdout** (normal output) — terminal screen, or next command's pipe
- **stderr** (errors) — also terminal screen, but separate stream (can be redirected)
- `>` redirects stdout to a file: `ls > files.txt`
- `2>` redirects stderr: `ls /nonexistent 2> errors.txt`

**Mini-glossary box:** Pipe, redirect, stdin, stdout, stderr, exit code, flag, argument, argument, environment variable.

---

## Page 4 — Section 2: The Install Script (Do This Once)

**Headline:** *One script. 12 tools. Safe to re-run.*

**Body:**
- Download and inspect (don't pipe-to-shell blindly):
  ```bash
  curl -fsSL https://your-domain/install-cli-stack.sh -o install-cli-stack.sh
  less install-cli-stack.sh    # always read what you're about to run
  bash install-cli-stack.sh
  ```
- What it does (1-line per tool listed).
- What it does NOT do: change your default shell, replace your `.bashrc`, or touch files outside `~/.config/` and standard package manager paths.
- Idempotent: safe to re-run. If a tool is already installed, it's skipped.

**OS-specific callouts (collapsible boxes or side notes):**
- **macOS:** Requires Homebrew (`brew`). Installs via `brew install ...`.
- **Linux (Debian/Ubuntu):** Uses `apt` + cargo fallback for tools not in repos.
- **Linux (Fedora/RHEL):** Uses `dnf` + cargo fallback.
- **Linux (Arch):** Uses `pacman` (most tools already in repos).
- **WSL (Windows):** Treat as Linux. Install WSLg for GUI tools. **Don't run on Windows native PowerShell.**

**Reversal section:** "How to uninstall everything" — one command, removes each tool, leaves configs in place (so re-running the script restores them).

---

## Page 5-7 — Section 3: The 12 Tools (One Page Each, Condensed)

*Each tool gets ~200-300 words: what it is, why it matters, the one-line install, the one killer feature, the one config snippet, the one "try this" exercise.*

> **Layout note:** Each tool = one sub-section with: icon, name, tagline, install command, "Before / After" mini-demo, "Try this" exercise.

---

### Tool 1: `mise` (formerly `rtx`) — Runtime Version Manager

**Tagline:** *One command for Node, Python, Ruby, Go, Java — no more `nvm` chaos.*

**What:** Manages language versions per-project. Reads `.mise.toml` in your repo; `cd` into a folder and the right Node version auto-loads.

**Install:**
```bash
# macOS / Linux / WSL
curl https://mise.run | sh
echo 'eval "$(~/.local/bin/mise activate bash)"' >> ~/.bashrc
```

**Before / After:**
- Before: `nvm use 18` then realize you're in the wrong project and have Node 14.
- After: `cd ~/projects/old-app && node --version` → v14 (auto). `cd ~/projects/new-app && node --version` → v20 (auto).

**Config snippet (`~/.config/mise/config.toml`):**
```toml
[tools]
node = "lts"
python = "3.12"
go = "latest"
```

**Try this:** `cd ~/any-project && mise use node@20` → creates `.mise.toml`. Open a new shell, cd back in, watch the version auto-switch.

---

### Tool 2: `starship` — Cross-Shell Prompt

**Tagline:** *Your prompt, but it actually tells you what you need to know.*

**What:** A fast, customizable prompt that shows git branch, language version, exit-code-of-last-command, elapsed time for long-running commands — all in one line.

**Install:**
```bash
# macOS
brew install starship

# Linux / WSL
curl -sS https://starship.rs/install.sh | sh
```

Add to `~/.bashrc`:
```bash
eval "$(starship init bash)"
```

**Before / After:**
- Before: `user@machine:~/projects/foo (master) $`
- After: `~/projects/foo on master via 🐍 v3.12 took 2s ❯` (green when last command succeeded, red when it failed)

**Config snippet (`~/.config/starship.toml`):**
```toml
[character]
success_symbol = "[❯](bold green)"
error_symbol = "[❯](bold red)"

[git_branch]
symbol = " "
```

**Try this:** Run `false` → notice red prompt. Run `true` → notice green. Run `sleep 3 && echo done` → notice elapsed time.

---

### Tool 3: `zoxide` — `cd` That Learns

**Tagline:** *Stop typing full paths. Type `z foo` and arrive.*

**What:** A smarter `cd` that remembers which directories you visit most and jumps to them with fuzzy matching. `z proj` from anywhere → goes to `~/projects/proj-thing`.

**Install:**
```bash
# macOS
brew install zoxide

# Linux / WSF
sudo apt install zoxide    # Debian/Ubuntu 24.04+
# or: cargo install zoxide
```

Add to `~/.bashrc`:
```bash
eval "$(zoxide init bash)"
```

**Before / After:**
- Before: `cd ~/projects/clients/acme-corp/website`
- After: `z acme` (after visiting once)

**Try this:** Visit 3-4 directories with `cd`. Then from anywhere, type `z <partial-name>`.

---

### Tool 4: `fzf` — Fuzzy Finder

**Tagline:** *Search anything — files, history, branches — with a few keystrokes.*

**What:** An interactive fuzzy finder. Bind it to `Ctrl+R` (history), `Ctrl+T` (files), `Alt+C` (directories). Lives in your shell, works everywhere.

**Install:**
```bash
# macOS
brew install fzf

# Linux / WSL
git clone --depth 1 https://github.com/junegunn/fzf.git ~/.fzf
~/.fzf/install
```

**Before / After:**
- Before: `↑↑↑↑↑↑` through 500 history entries looking for that one command.
- After: `Ctrl+R` → type 3 letters → Enter.

**Try this:** `Ctrl+R` → search for "git" → use arrow keys → Enter to run, or `Ctrl+Y` to copy.

---

### Tool 5: `ripgrep` (`rg`) — Fast Code Search

**Tagline:** *Search 10,000 files in 0.2 seconds.*

**What:** A grep replacement that's dramatically faster, respects `.gitignore`, and skips binary files automatically. Default tool for searching code.

**Install:**
```bash
# macOS
brew install ripgrep

# Linux / WSL
sudo apt install ripgrep    # Debian/Ubuntu
```

**Before / After:**
- Before: `grep -r "TODO" .` → slow, spams binary files, includes `node_modules`.
- After: `rg "TODO"` → instant, respects `.gitignore`, syntax-highlighted matches.

**Common flags:**
- `rg -i "error"` → case-insensitive
- `rg "TODO" --type py` → only Python files
- `rg "fixme" -l` → files only, no content
- `rg "auth" -C 3` → 3 lines of context

**Try this:** `rg "TODO|FIXME" --type-add 'web:*.{html,css,js}' -t web` in any project.

---

### Tool 6: `fd` — Friendly `find`

**Tagline:** *`find` syntax you can actually remember.*

**What:** A simple, fast, user-friendly alternative to `find`. Smart defaults: ignores hidden files, respects `.gitignore`, parallel by default.

**Install:**
```bash
# macOS
brew install fd

# Linux / WSL
sudo apt install fd-find    # Debian/Ubuntu (binary is `fdfind`)
```

**Before / After:**
- Before: `find . -name "*.py" -not -path "*/node_modules/*"`
- After: `fd "\.py$"`

**Try this:** `fd config` (finds all config files), `fd -e md` (all markdown), `fd -H "^\.env"` (hidden env files).

---

### Tool 7: `bat` — `cat` With Wings

**Tagline:** *Syntax-highlighted, line-numbered, Git-aware `cat`.*

**What:** Drop-in `cat` replacement that shows line numbers, syntax highlights, and integrates with Git to show diff markers. Paginates long files automatically.

**Install:**
```bash
# macOS
brew install bat

# Linux / WSL
sudo apt install bat        # binary may be `batcat` on Debian — alias it
```

**Before / After:**
- Before: `cat package.json` → wall of text.
- After: `bat package.json` → syntax-highlighted, numbered, with `|##|` markers for unstaged Git changes.

**Try this:** `bat --list-languages | head -20` to see all supported syntaxes. Use as `bat -A file.sh` to show non-printing chars.

---

### Tool 8: `eza` — Modern `ls`

**Tagline:** *`ls`, but pretty and informative.*

**What:** Drop-in `ls` replacement with sensible defaults: Git status, file icons (with Nerd Font), tree view, color-coded by file type.

**Install:**
```bash
# macOS
brew install eza

# Linux / WSL
sudo apt install eza        # Debian 13+ / Ubuntu 24.04+
# or: cargo install eza
```

Add to `~/.bashrc`:
```bash
alias ls="eza --icons"
alias ll="eza -la --icons --git"
alias lt="eza --tree --level=2 --icons"
```

**Before / After:**
- Before: `ls -la` → 8 columns of grey text.
- After: `ll` → colored, icon-prefixed, with Git status indicators.

**Try this:** `lt` in any project to see a 2-level tree. `ll --sort=modified` to find recently-changed files.

---

### Tool 9: `delta` — Beautiful Git Diffs

**Tagline:** *Side-by-side, syntax-highlighted `git diff` that you actually want to read.*

**What:** A syntax-highlighting pager for `git diff`, `git log`, `git show`. Replaces the wall-of-red-and-green text with aligned, colored, line-numbered output.

**Install:**
```bash
# macOS
brew install git-delta

# Linux / WSL
# See https://github.com/dandavison/delta for installer
```

Add to `~/.gitconfig`:
```ini
[core]
    pager = delta

[interactive]
    diffFilter = delta --color-only

[delta]
    navigate = true
    line-numbers = true
    side-by-side = true
```

**Before / After:**
- Before: `git diff` → red/green blocks you scroll through.
- After: `git diff` → aligned, syntax-highlighted, line-numbered, side-by-side.

**Try this:** `git log -p` → beautifully rendered commit history with diffs.

---

### Tool 10: `tldr` — Simplified Man Pages

**Tagline:** *Man pages, but for humans.*

**What:** Community-maintained, simplified command examples. Skips the 40-option man page, gives you 5-10 practical examples.

**Install:**
```bash
# macOS
brew install tldr

# Linux / WSL
sudo apt install tldr        # or npm i -g tldr
```

**Before / After:**
- Before: `man tar` → 200 lines, exits with `:q` confusion.
- After: `tldr tar` → 10 common examples, color-coded.

**Try this:** `tldr ffmpeg`, `tldr kubectl`, `tldr jq`. Run `tldr --update` weekly.

---

### Tool 11: `atuin` — Magical Shell History

**Tagline:** *Searchable, synced, deduplicated shell history across machines.*

**What:** Replaces your shell history with a SQLite-backed, searchable, optionally-encrypted-and-synced history. Works across machines if you want it to.

**Install:**
```bash
# macOS
brew install atuin

# Linux / WSL
curl --proto '=https' --tlsv1.2 -sSf https://setup.atuin.sh | sh
```

Run `atuin import` to import existing history, then `atuin login` for sync (optional).

**Before / After:**
- Before: `Ctrl+R` searches current machine only, loses history across machines.
- After: `Ctrl+R` searches all machines (if synced), full-text, fuzzy, with date filters.

**Try this:** `Ctrl+R`, type part of an old command. Run `atuin search --before "yesterday"` for time-based queries.

---

### Tool 12: `lazygit` or `gh` — TUI for Git (pick one)

**Headline:** *Your terminal now has a GUI for Git.*

**Pick `lazygit` if:** you want a full terminal UI for staging, committing, branching, merging, rebasing — all with keyboard.
**Pick `gh` if:** you want GitHub integration (PRs, issues, releases) from the command line.

**Install `lazygit`:**
```bash
# macOS
brew install lazygit

# Linux / WSL
sudo apt install lazygit
```

**Install `gh`:**
```bash
# macOS
brew install gh

# Linux / WSL
sudo apt install gh
```

**Try this:** `lazygit` in any repo → press `?` for help. Or `gh repo view`, `gh pr create`, `gh issue list`.

---

## Page 8 — Section 4: Putting It All Together

**Headline:** *What does this look like in real life?*

**Scenario walkthrough (500 words):**
- Imagine: a junior dev joins a new repo. They need to find where auth is implemented, fix a bug, run tests, commit, push, open a PR.
- With default tools: 8 shell windows, lots of clicking.
- With the stack:
  1. `z repo` → jump to project
  2. `git checkout -b fix/auth-bug && lazygit` → visual branch management
  3. `rg "authenticate"` → find the function in 0.2s
  4. `bat src/auth.py` → see it highlighted
  5. Edit, then `git diff` → delta renders it beautifully
  6. `lazygit` → stage, commit, push
  7. `gh pr create` → open PR from terminal
  8. Total time: ~3 minutes. Context preserved. No IDE needed.

**Three "cheatcodes" box:**
- `Ctrl+R` (in fzf/atuin) → search history
- `Ctrl+T` (in fzf) → find file
- `Alt+C` (in fzf) → cd into directory

---

## Page 9 — Section 5: What's Next

**Headline:** *You've finished the starter pack. Here's your roadmap.*

### If you want to go deeper (intermediate)
- **Shell scripting**: learn Bash properly. Book: *Classic Shell Scripting* (Robbins). Tool: `shellcheck`.
- **tmux / zellij**: terminal multiplexing — survive SSH disconnects, pair programming.
- **Make / Just**: task runners. Replace shell scripts with `justfile`.
- **Task / Mise tasks**: project-scoped commands.

### If you want to build tools (advanced)
- **Cobra (Go)** or **Click (Python)**: build CLIs teams will actually use.
- **Bubble Tea (Go)** or **Textual (Python)**: build beautiful TUIs.
- **Gum**: wrap shell scripts in interactive prompts.
- **Inquire / PromptUI**: prompts in Go/Python.

### If you want to learn the *why* (forever-curious)
- Julia Evans' zines (`wizardzines.com`)
- *The Linux Command Line* (free PDF)
- *Effective Shell* (effective-shell.com)
- `man bash` (yes, really — read it once)

### If you want AI-powered CLI (cutting edge)
- Claude Code, Codex, aider — all live in the terminal. Your new fluency makes you 10x more effective with them.
- Skill: *Prompt engineering for shell tasks.*

---

## Page 10 — Appendix + Closing

### A. Glossary (5-10 terms)
Pipe, redirect, stdin/stdout/stderr, exit code, prompt, shell, terminal, TUI, REPL, alias.

### B. Cheat Sheet (one-page, tear-out style)
| Tool | One-liner |
|------|-----------|
| mise | `mise use node@20` |
| starship | (auto-loads in prompt) |
| zoxide | `z proj` |
| fzf | `Ctrl+R` / `Ctrl+T` / `Alt+C` |
| ripgrep | `rg "TODO"` |
| fd | `fd "\.py$"` |
| bat | `bat file.py` |
| eza | `ll` |
| delta | (auto-loads in `git diff`) |
| tldr | `tldr tar` |
| atuin | `Ctrl+R` |
| lazygit | `lazygit` |

### C. Troubleshooting
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

### D. Resources
- Each tool's GitHub link (one per tool)
- This PDF's GitHub repo (for updates + issues)
- Companion install script URL
- Newsletter signup → URL
- Skool community → URL

### E. License + Author
- CC BY-NC-SA 4.0
- Author bio (1 sentence + link)
- "Buy me a coffee" → Gumroad tip jar
- "Want to learn more? Join the newsletter → URL"

---

## Design Notes

**Visual style:**
- Dark mode by default (light mode option for print)
- One accent color (suggest green `#4ade80` or cyan `#22d3ee`)
- Nerd Font icons in tool headers
- Code blocks: monospace, syntax-highlighted, subtle background
- Before/After pairs: side-by-side boxes, not full-page blocks
- Whitespace-heavy — don't cram

**Typography:**
- Body: 11-12pt sans-serif (Inter, system-ui)
- Code: 10-11pt monospace (JetBrains Mono, Fira Code)
- Headings: same family, weight + color contrast

**Length calibration:**
- Each tool section: ~200-300 words (not a manual — a *taste*)
- Total body: 2,500-3,500 words
- Designed to be read in 15-20 minutes, used as reference for 6 months

---

## Production Checklist (Post-Outline)

- [ ] **Tool selection finalized** — confirm 12 tools match your stack
- [ ] **Install script written** — `install-cli-stack.sh`, tested on macOS + Ubuntu + WSL
- [ ] **Screenshots captured** — one per tool (terminal screenshot, dark mode)
- [ ] **PDF designed** — Canva, Figma, or LaTeX (Pandoc + Eisvogel template is a fast path)
- [ ] **Gumroad product page** — cover image, description, files, follow button
- [ ] **Email sequence** — 5-day mini-course loaded in Beehiiv/ConvertKit
- [ ] **Landing page** — link from Gumroad → email signup
- [ ] **Launch post** — LinkedIn, Twitter/X, Dev.to, Reddit, HN (Show HN)

---

## Open Decisions (For You)

1. **Author name / handle** — placeholder above
2. **Color accent** — green, cyan, or pick your own
3. **Tool 12** — `lazygit` or `gh`? Or include both?
4. **Bonus tool** — add `mise` companion `direnv` for auto-loading `.envrc` per directory?
5. **Companion script URL** — where will `install-cli-stack.sh` live? (GitHub gist? repo? S3?)
6. **Newsletter name** — `CLI Mastery Weekly`, `Terminal Tuesday`, `Prompt & Pipe`, etc.?
7. **Brand name** — `Modern CLI Stack`, `The Terminal Field Guide`, `Promptcraft`, etc.?

---

*Outline complete. Ready for your feedback before I draft the actual prose.*
