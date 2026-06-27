# Conventions — kamon's publishing system

This document describes the shared conventions used across all kamon
publishing projects (PDFs, newsletters, books, etc.). Following these
conventions keeps new products consistent and easy to maintain.

## Repository pattern

**One product = one repo.** Each kamon publishing project gets its own
GitHub repository under [github.com/kamon](https://github.com/kamon).

Currently:

| Repo | Visibility | Purpose |
|---|---|---|
| `cli-resources` | **public** | "The Modern CLI Stack" PDF + build system |
| `shellcraft-newsletter` | **private** | Shellcraft newsletter operations system |

When you start a new product, create a new repo following the same
conventions. Cross-repo references (e.g., PDF links to newsletter, or
newsletter links to PDF) are done by URL in the content, not by
code-level coupling.

## Directory structure

Every product repo follows the same skeleton:

```
<product-repo>/
├── README.md                 # Top-level: what is this, how to use it
├── LICENSE                   # CC BY-NC-SA for content, MIT for code
├── CHANGELOG.md              # Keep-a-Changelog format
├── .gitignore                # Standard pattern (Python, output/, OS)
├── .github/
│   └── workflows/            # GitHub Actions CI
├── scripts/
│   └── release.sh            # Bump + tag + push
├── config/                   # YAML: metadata, build settings, hooks
├── content/                  # Markdown source files (the actual product)
├── output/                   # Generated artifacts (gitignored)
└── themes/ or templates/     # Visual templates (LaTeX, etc.)
```

## Content split

**Metadata** lives in `config/`:
- `author.yaml` (or equivalent) — global author info
- `product.yaml` (or equivalent) — per-product title, version, audience
- `build.yaml` (or equivalent) — build pipeline settings, validation rules

**Content** lives in `content/`:
- Plain markdown files
- Named by section/issue/tool (e.g., `04-tools-01-04.md`)
- Frontmatter is YAML with required fields (title, version, etc.)

**Templates** live in `themes/` or `templates/`:
- LaTeX, HTML, or other format-specific files
- Versioned with the build system

## Build interface

Every product has a `make` interface with these targets:

| Target | Purpose |
|---|---|
| `make help` | Show all targets |
| `make setup` | Install dependencies (Python venv, etc.) |
| `make build` | Build the product (PDF, newsletter artifacts, etc.) |
| `make audit` | Run quality checks (AI tells, word count, etc.) |
| `make release` | (Optional) Bump version + tag + push |

The CLI tool (if any) follows the same naming: `scripts/<product>.py`
with subcommands `status`, `draft`, `build`, `publish`, `ideas`, etc.

## Validation hooks

Every product runs **pre-build hooks** that validate content before
producing artifacts. The current standard set:

| Hook | What it checks |
|---|---|
| `check_word_count.py` | Draft within target range |
| `check_required_fields.py` | All required frontmatter present |
| `check_ai_tells.py` | No P0/P1 AI tells detected |

To add a new product: **copy these hooks from an existing repo**. They
are not yet a shared library — that's premature with only 2 products.

## AI tell cleanup

Every product uses the `check_ai_tells.py` hook. The script classifies
issues into three tiers:

- **P0** (credibility killers) — block the build
- **P1** (obvious AI smell) — warn but don't block
- **P2** (stylistic polish) — report only

Run `make audit` to scan all content without building. Fix P0/P1 before
publishing.

## Git workflow

- **Default branch**: `main`
- **Tag format**: `v<version>` (e.g., `v2026.1`, `v0.1.0`)
- **Commit messages**: imperative mood, sentence case, no period
  - Good: "Add broot to the tools list"
  - Bad: "added broot." / "ADD BROOT!!!"
- **Never commit** the `output/` directory — it's gitignored

## Releases

The pattern for releasing:

1. Update `CHANGELOG.md` — move items from "Unreleased" to a new version
2. For PDF products: run `./scripts/release.sh <version>` (auto-bumps, builds, tags, pushes)
3. For non-PDF products: run `./scripts/release.sh <version>` (just tags + pushes)
4. Create a GitHub release at github.com/kamon/<repo>/releases/new
5. For PDFs: attach the PDF file to the GitHub release

## License model

- **Content** (markdown source for PDFs, published newsletter issues):
  CC BY-NC-SA 4.0
- **Code** (build scripts, hooks, automation): MIT
- **Third-party assets**: keep their original license (Eisvogel = MIT,
  Pygments = BSD)

See individual `LICENSE` files for the specific language.

## When to extract a shared library

If you have **3+ products** and the duplication hurts (e.g., updating
`check_ai_tells.py` in three places is annoying), extract it to
`kamon/publishing-patterns` as a Python package. Until then, copy-paste
is fine — three copies are easier to maintain than an abstraction.

## Adding a new product

1. Copy this `CONVENTIONS.md` to the new repo
2. Copy the standard `.gitignore`, `.github/workflows/`, `scripts/release.sh`
3. Copy the standard validation hooks (`scripts/hooks/`)
4. Define your product-specific config in `config/`
5. Write your content in `content/`
6. Build with `make build` and verify with `make audit`

The first 3-4 repos will feel like copying-paste. By repo #4, you'll
see which patterns are worth extracting.
