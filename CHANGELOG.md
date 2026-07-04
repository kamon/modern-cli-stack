# Changelog

All notable changes to this template will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [2026.2] — 2026-07-04

### Added
- "After the install" section to the install chapter: explains what
  the script adds to the shell config, the 5 eval lines + aliases,
  the first 9 version-check commands, and a "trying out the workflow"
  block (`ls`, `bat`, `rg`, `fd`, `z <name>`, then `Ctrl+R` for
  history)
- zsh notes throughout the brief: mise, starship, and zoxide per-tool
  install blocks now include a "On zsh (macOS default)" callout
  pointing at `~/.zshrc` + the right init command. The Appendix C
  troubleshooting, Appendix D uninstall, and the "What it does" /
  "What it does NOT do" sections all distinguish bash vs. zsh.
- `--help` output in the install script now mentions the auto-detect
  behavior (`$SHELL` env var → `.bashrc` or `.zshrc`) and the help
  text says "your shell config" instead of `.bashrc` everywhere.

### Changed
- The brief is now 25 pages (was 19). Content added: the install
  chapter's "After the install" section (~3 pages), the bumped
  zsh coverage (~1 page), and the page count reflects the actual
  rendered PDF.

## [2026.1] — 2026-06-27

### Added
- Initial public release of the build system template
- Modern CLI Stack PDF as the worked example (13 chapters)
- Pandoc + xelatex + Eisvogel build pipeline (`system/scripts/build.py`)
- Pre-build hooks: AI tell check, word-count check, required-fields check
- Bundled install script (`system/install-cli-stack.sh`) covering macOS,
  Debian/Ubuntu, and Arch Linux
- CI workflow that builds the PDF on every push to `main`
  (`.github/workflows/build-pdf.yml`)