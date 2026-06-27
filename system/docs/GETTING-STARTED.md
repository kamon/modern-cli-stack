# Build System — Verified Working

**Date:** 2026-06-24
**Status:** ✅ End-to-end pipeline verified

## What was built

A reusable Python + Pandoc + LaTeX build system that:
- Reads YAML metadata (author info, product info, build config)
- Renders Markdown content via Jinja2 templates
- Compiles to PDF via Pandoc + xelatex + Eisvogel template
- Runs pre/post hooks for validation
- Outputs versioned files ready for distribution

## Verified output

```
Title:           The Modern CLI Stack
Subject:         A Beginner's Field Guide to a Faster Terminal
Keywords:        cli, terminal, bash, devops, productivity, command-line
Author:          Your Name
Creator:         LaTeX via pandoc
Producer:        xdvipdfmx
Pages:           14
File size:       97 KB
Page size:       612 x 792 pts (US Letter)
```

Template variables resolved correctly:
- `{{ author.name }}` → "Your Name"
- `{{ author.handle }}` → "@yourhandle"
- `{{ product.title }}` → "The Modern CLI Stack"
- `{{ product.version }}` → "2026.1"
- `{{ product.audience.platforms | join(' · ') }}` → "macOS · Linux · WSL"
- `{{ author.defaults.license }}` → "CC BY-NC-SA 4.0"
- `{{ links.newsletter }}` → "https://yoursite.com/newsletter"

## Tooling stack

| Component | Version | Install |
|-----------|---------|---------|
| Python | 3.14 (venv) | `brew install python@3.14` |
| PyYAML | latest | `pip install pyyaml` |
| Jinja2 | latest | `pip install jinja2` |
| Rich | latest | `pip install rich` |
| Watchdog | latest | `pip install watchdog` |
| Pandoc | 3.10 | `arch -arm64 brew install pandoc` |
| TeX Live | 2026 | `arch -arm64 brew install texlive` |
| Poppler | 26.06 | `arch -arm64 brew install poppler` (for verification) |

> **Note on arm64 Macs:** Homebrew on Apple Silicon requires `arch -arm64` prefix for installs when the shell is running under Rosetta 2. If you see "Cannot install under Rosetta 2", use the arm64 prefix.

## File layout

```
/Users/kamonayeva/DEV/1-BOOKS/cli-resources/system/
├── README.md                              ← system overview
├── Makefile                               ← convenience shortcuts
├── config/
│   ├── author.yaml                        ← YOUR identity (edit once)
│   └── build.yaml                         ← pipeline settings
├── content/
│   └── modern-cli-stack/
│       ├── product.yaml                   ← per-product metadata
│       ├── 00-cover.md
│       ├── 01-intro.md
│       ├── 02-mental-models.md
│       ├── 03-install.md
│       ├── 04-tools-01-04.md
│       ├── 04-tools-05-08.md
│       ├── 04-tools-09-12.md
│       ├── 05-scenario.md
│       ├── 06-roadmap.md
│       └── 07-appendix.md
├── themes/
│   ├── eisvogel.latex                     ← Pandoc template
│   └── README.md
├── scripts/
│   ├── build.py                           ← the only CLI you need
│   └── hooks/
│       ├── validate_config.py
│       ├── check_assets.py
│       └── print_summary.py
├── output/
│   └── modern-cli-stack/
│       └── modern-cli-stack-v2026.1.pdf   ← ✅ BUILT
├── install-cli-stack.sh                  ← bundled installer
└── .venv/                                 ← Python venv (gitignore)
```

## Commands

```bash
cd /Users/kamonayeva/DEV/1-BOOKS/cli-resources/system

# Build
.venv/bin/python scripts/build.py modern-cli-stack

# List products
.venv/bin/python scripts/build.py --list

# Scaffold new product
.venv/bin/python scripts/build.py --init my-next-book

# Watch & rebuild
.venv/bin/python scripts/build.py --watch modern-cli-stack
```

## Next steps for you

1. **Edit `config/author.yaml`** — replace placeholder values with your real info
2. **Polish the markdown content** — add screenshots, refine copy
3. **Test the install script** — `bash install-cli-stack.sh` on a clean VM
4. **Upload to Gumroad** — use the output PDF as the deliverable
5. **Iterate** — change author info once, watch it propagate everywhere
6. **Add a second product** — `make new ID=tmux-mastery` (after edit) — prove the reusability
