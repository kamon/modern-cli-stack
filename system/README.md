# CLI Resources Build System

A reusable, single-source-of-truth system for producing PDFs, books, newsletters, and any other text-based resources. Built for the **Modern CLI Stack** project — extensible to anything.

## Architecture

```
┌──────────────────────────────────────────────────────────────────┐
│                          YAML CONFIGS                            │
│  config/author.yaml   — YOU (name, social, brand, defaults)      │
│  config/build.yaml    — pipeline settings (engines, hooks)       │
│  config/product.yaml  — per-product metadata (title, audience)   │
└──────────────────────────────────────────────────────────────────┘
                              ↓ loaded into Jinja2 context
┌──────────────────────────────────────────────────────────────────┐
│                       MARKDOWN CONTENT                           │
│  content/<product>/*.md   — uses {{ author.name }}, etc.         │
└──────────────────────────────────────────────────────────────────┘
                              ↓ rendered
┌──────────────────────────────────────────────────────────────────┐
│                       BUILD ENGINE                               │
│  scripts/build.py  — Jinja2 + Pandoc + LaTeX                     │
│  Makefile          — convenience shortcuts                       │
└──────────────────────────────────────────────────────────────────┘
                              ↓
┌──────────────────────────────────────────────────────────────────┐
│                       OUTPUTS                                    │
│  output/<slug>-v<version>.pdf  (+html, +epub as configured)      │
└──────────────────────────────────────────────────────────────────┘
```

## Quick Start

```bash
cd system/

# 1. Set up Python venv (one-time)
make setup

# 2. Edit author info
$EDITOR config/author.yaml

# 3. List products (default: Modern CLI Stack)
make list

# 4. Build the PDF
make build
# → output/modern-cli-stack-v2026.1.pdf

# 5. Watch & rebuild on edit
make watch PRODUCT=modern-cli-stack

# 6. Add a new product
make new ID=my-next-book
# → creates content/my-next-book/ with template files
```

## Directory Layout

```
system/
├── config/
│   ├── author.yaml         ← your identity (edit once)
│   ├── product.yaml        ← metadata for THIS product (in content/)
│   └── build.yaml          ← pipeline settings (edit rarely)
├── content/                ← one folder per product
│   └── modern-cli-stack/
│       ├── product.yaml
│       └── *.md
├── themes/                 ← Pandoc templates (eisvogel.latex etc.)
├── scripts/
│   ├── build.py            ← the only CLI you need
│   └── hooks/              ← pre/post-build scripts
├── output/                 ← generated PDFs land here
├── templates/              ← scaffolds for new products
├── tests/
├── install-cli-stack.sh    ← companion installer (bundled with PDF)
└── Makefile
```

## The Pattern: Separation of Concerns

| What | Where | Edit frequency |
|------|-------|----------------|
| Who you are | `config/author.yaml` | Once, then rarely |
| How to build | `config/build.yaml` | Rarely |
| What this product is | `content/<id>/product.yaml` | Per product |
| What it says | `content/<id>/*.md` | Every revision |

The **content** never needs to know the author's name — it just says `{{ author.name }}` and the build system fills it in. **One author update = every PDF re-branded.**

## Adding a New Product (5 min)

```bash
make new ID=tmux-mastery
$EDITOR content/tmux-mastery/product.yaml   # set title, version, audience
$EDITOR content/tmux-mastery/01-intro.md    # write content
make build
```

The new product uses the **same author info, same theme, same build pipeline** as your existing products.

## Extending

| Want to... | Edit |
|------------|------|
| Change author name | `config/author.yaml` |
| Switch PDF engine | `config/build.yaml` (`pandoc.pdf_engine`) |
| Add a hook (e.g. spell check) | `config/build.yaml` (`hooks.pre_build`) + new file in `scripts/hooks/` |
| New theme | drop file in `themes/`, set `theme.name` in product.yaml |
| Multi-author | add to `author.yaml` (per-product `pdf.author` override) |
| Newsletter generation | new product type — extend `product.type` + add template |

## Dependencies

- **Pandoc** (`brew install pandoc`)
- **TeX Live** (`brew install texlive` — ~4.6GB, full distribution)
- **Python 3.9+** with `pyyaml`, `jinja2`, `rich`, `watchdog`

## Why this design

- **One source of truth** — author info in one file updates everywhere
- **Content-as-data** — markdown with template vars, not hardcoded strings
- **Composable** — Pandoc + Jinja2 + LaTeX is the gold standard for technical publishing
- **Reusable** — every future product (book, newsletter, ebook) uses the same pipeline
- **CI-ready** — `make build` is one command, idempotent, deterministic

---

Built for the Modern CLI Stack PDF. Ship more things by writing less glue.
