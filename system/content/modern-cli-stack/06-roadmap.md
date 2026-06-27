\newpage

# What's Next

You've finished the starter pack. Here's your roadmap by depth.

## If you want to go deeper (intermediate)

- **Shell scripting**: learn Bash properly. Book: *Classic Shell Scripting*
  (Robbins). Tool: `shellcheck`.
- **tmux / zellij**: terminal multiplexing — survive SSH disconnects, pair
  programming.
- **Make / Just**: task runners. Replace shell scripts with `justfile`.
- **direnv**: auto-load `.envrc` per directory.

## If you want to specialize (advanced daily-drivers)

These are worth installing once you have the core 13 down and find
yourself wanting more. Pick the ones that match your daily work — most
people only need one or two.

- **`watchexec`** — rerun a command when files change. The Rust
  replacement for the Python `watchdog` CLI (`watchmedo`). Pairs naturally
  with `just` or `make` for live-reload workflows.
- **`yazi`** — terminal file manager. Browse directories with previews
  (images, PDFs, archives) without leaving the terminal. Replaces the
  "I need to open Finder for this" reflex.
- **`xh`** — a friendlier `curl`. Better defaults, colorized output,
  sensible HTTPS. Drop-in replacement for most curl commands.
- **`doggo`** or **`dog`** — modern `dig` alternatives with DNS-over-HTTPS,
  JSON output, and prettier formatting. Useful if you debug DNS.

## If you want to build tools (advanced)

- **Cobra (Go)** or **Click (Python)**: build CLIs teams will actually use.
- **Bubble Tea (Go)** or **Textual (Python)**: build beautiful TUIs.
- **Gum**: wrap shell scripts in interactive prompts.
- **Inquire / PromptUI**: prompts in Go/Python.

## If you want to learn the *why* (forever-curious)

- Julia Evans' zines ([wizardzines.com](https://wizardzines.com))
- *The Linux Command Line* (free PDF)
- *Effective Shell* ([effective-shell.com](https://effective-shell.com))
- `man bash` (yes, really — read it once)

## If you want AI-powered CLI

- Claude Code, Codex, aider — all live in the terminal. Your new fluency
  makes you more effective with them — they reward people who already
  know how to navigate a shell.
- Skill: *Prompt engineering for shell tasks.*
