# Changelog

All notable changes to this template will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
- Companion cross-reference to `kamon/shellcraft-newsletter`