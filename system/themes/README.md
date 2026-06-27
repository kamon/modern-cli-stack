# Themes

Pandoc templates that control the visual design of generated PDFs / HTML / EPUB.

## Available themes

- **`eisvogel`** — Pandoc LaTeX template by Wandmalfarbe. Beautiful, opinionated, designed for technical PDFs. Source: https://github.com/Wandmalfarbe/pandoc-latex-template

## Adding a new theme

1. Drop the Pandoc template file here (`mytheme.latex`, `mytheme.html`, etc.)
2. Reference it from `config/product.yaml`:
   ```yaml
   theme:
     name: "mytheme"
   ```

## How theme selection works

`build.py` looks up `themes/<theme.name>.<format>` based on:
- `theme.name` from product config (default: `eisvogel`)
- output format (`pdf` → `.latex`, `html` → `.html`, `epub` → `.epub`)

If the file doesn't exist, Pandoc's built-in default template is used.
