# Modern CLI Stack — Template

A Pandoc-based build system for technical books and PDFs. Produces
the **Modern CLI Stack** PDF as a worked example.

This repo is a **template** — fork it, swap in your own content, and
build your own PDF. The 13 chapters in `system/content/modern-cli-stack/`
are the example. Replace them with yours.

## What's in this repo

- **A Pandoc + xelatex + Eisvogel build pipeline** that turns
  markdown source into a print-ready PDF.
- **The Modern CLI Stack** (13 chapters, ~20 pages) — a complete
  example of what this build system produces. Read it as
  documentation; replace it with your own book.
- **Pre-build hooks** — AI-tell check, word-count check,
  required-fields check. Run automatically before every build.
- **A bundled install script** (`system/install-cli-stack.sh`) —
  one shell command that installs the 13 example tools on macOS,
  Linux, or WSL. Reuse it in your own book if your tools overlap.
- **CI workflow** (`.github/workflows/build-pdf.yml`) that builds
  the PDF on every push and uploads it as a workflow artifact.

## Quick start

```bash
git clone https://github.com/kamon/modern-cli-stack
cd modern-cli-stack/system

# Install dependencies
python -m venv .venv
.venv/bin/pip install pyyaml jinja2 rich watchdog

# macOS: install pandoc + xelatex
brew install pandoc librsvg
brew install --cask mactex-no-gui    # or: brew install texlive

# Build the PDF
.venv/bin/python scripts/build.py modern-cli-stack

# Output
open output/modern-cli-stack/modern-cli-stack-v2026.1.pdf
```

On Linux/WSL:

```bash
sudo apt install pandoc texlive-xetex librsvg2-bin
# Then same as above from the system/ directory
```

## Using this template for your own book

1. **Edit author identity** in `system/config/author.yaml`
   (name, handle, social links).
2. **Edit product metadata** in
   `system/content/modern-cli-stack/product.yaml`
   (title, subtitle, version, theme).
3. **Replace the chapters** in `system/content/modern-cli-stack/`
   with your own markdown files. Filenames control chapter
   order (`build.py` sorts them lexicographically). To include
   a partial file without rendering it as its own chapter,
   prefix the filename with `_` (e.g., `_shared-resources.md`).
4. **Run** `.venv/bin/python scripts/build.py modern-cli-stack`
   to produce your PDF.

The `scripts/build.py` is the only entry point you need to learn.
All complexity lives in the YAML configs and the markdown content.

## Repo structure

```
modern-cli-stack/
├── system/                       # The build pipeline
│   ├── config/                   # author.yaml, build.yaml (global); product.yaml per product
│   ├── content/modern-cli-stack/ # Markdown source for the example PDF
│   ├── scripts/                  # build.py + validation hooks
│   │   └── hooks/
│   ├── themes/                   # Eisvogel LaTeX template, syntax theme
│   ├── docs/                     # GETTING-STARTED and friends
│   └── install-cli-stack.sh      # Bundled installer
├── .github/workflows/            # CI: builds PDF on push
├── README.md                     # You are here
├── LICENSE                       # MIT
├── CHANGELOG.md
├── CONVENTIONS.md                # Shared conventions across kamon repos
├── pdf-outline.md                # Design doc for the example PDF
└── scripts/release.sh            # Tag-and-bump helper
```

## What the build system gives you

- **Versioned PDF artifacts** — `modern-cli-stack-v2026.1.pdf`,
  automatically named from `product.yaml:version`.
- **PDF metadata** (author, title, keywords) injected from
  YAML into the final PDF's properties.
- **Validation hooks** that run before every build and fail
  loudly on missing fields, AI tells, or word-count violations.
- **A watch mode** — `python scripts/build.py --watch` rebuilds
  on file change.
- **A tag-and-release helper** — `./scripts/release.sh` bumps the
  patch version, rebuilds, and tags.

## Companion project

The companion to this template is
[`kamon/shellcraft-newsletter`](https://github.com/kamon/kamon/shellcraft-newsletter),
a newsletter operations system. If you publish a weekly newsletter
alongside your book/PDF, the two systems share the same
`CONVENTIONS.md` patterns.

## License

MIT. See [LICENSE](LICENSE).