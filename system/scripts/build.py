#!/usr/bin/env python3
"""
build.py — Build PDFs (or HTML/EPUB) from Markdown content + YAML metadata.

Usage:
    python build.py                          # build all products (drafts filtered)
    python build.py modern-cli-stack         # build one product by id
    python build.py --format pdf html        # override formats
    python build.py --watch                  # watch mode (rebuild on change)
    python build.py --list                   # list configured products
    python build.py --init <id>              # scaffold a new product from template

Architecture:
    1. Load global author config + per-product config
    2. Render Markdown content as Jinja2 template (vars come from author + product)
    3. Run Pandoc with merged config (variables, theme, engine)
    4. Run pre/post hooks (validation, asset checks)
    5. Print summary + open output file

This is the ONLY script you need to remember.
All complexity lives in the YAML configs and the Markdown content.
"""

import argparse
import datetime as dt
import fnmatch
import os
import shutil
import subprocess
import sys
import time
from pathlib import Path
from typing import Any, Dict, List, Optional

try:
    import yaml
except ImportError:
    print("ERROR: PyYAML not installed. Run: pip install pyyaml jinja2 watchdog", file=sys.stderr)
    sys.exit(1)

try:
    import jinja2
except ImportError:
    print("ERROR: Jinja2 not installed. Run: pip install pyyaml jinja2 watchdog", file=sys.stderr)
    sys.exit(1)

try:
    from rich.console import Console
    from rich.panel import Panel
    from rich.table import Table
    console = Console()
except ImportError:
    # Fallback to plain print
    class _Plain:
        def print(self, *args, **kwargs):
            print(*args)
        def rule(self, text):
            print(f"\n=== {text} ===")
    console = _Plain()


# ---------------------------------------------------------------------------
# Paths
# ---------------------------------------------------------------------------
SYSTEM_DIR = Path(__file__).resolve().parent.parent
CONTENT_DIR = SYSTEM_DIR / "content"
CONFIG_DIR = SYSTEM_DIR / "config"
THEMES_DIR = SYSTEM_DIR / "themes"
OUTPUT_DIR = SYSTEM_DIR / "output"
SCRIPTS_DIR = SYSTEM_DIR / "scripts"
HOOKS_DIR = SCRIPTS_DIR / "hooks"


# ---------------------------------------------------------------------------
# Config loading
# ---------------------------------------------------------------------------
def load_yaml(path: Path) -> Dict[str, Any]:
    """Load a YAML file. Empty files return {}."""
    if not path.exists():
        return {}
    with path.open("r", encoding="utf-8") as f:
        return yaml.safe_load(f) or {}


def deep_merge(base: Dict[str, Any], override: Dict[str, Any]) -> Dict[str, Any]:
    """Deep merge two dicts. Override wins on conflict."""
    merged = dict(base)
    for k, v in override.items():
        if k in merged and isinstance(merged[k], dict) and isinstance(v, dict):
            merged[k] = deep_merge(merged[k], v)
        else:
            merged[k] = v
    return merged


def load_configs() -> Dict[str, Any]:
    """Load author + build configs (global)."""
    author = load_yaml(CONFIG_DIR / "author.yaml")
    build = load_yaml(CONFIG_DIR / "build.yaml")
    return {"author": author, "build": build}


def discover_products(filter_status: Optional[str] = None) -> List[Path]:
    """Find all product.yaml files in content/<id>/."""
    if not CONTENT_DIR.exists():
        return []
    products = []
    for path in sorted(CONTENT_DIR.glob("*/product.yaml")):
        product_cfg = load_yaml(path)
        status = product_cfg.get("product", {}).get("status", "draft")
        if filter_status and status != filter_status:
            continue
        products.append(path)
    return products


# ---------------------------------------------------------------------------
# Template rendering
# ---------------------------------------------------------------------------
def build_jinja_env() -> jinja2.Environment:
    """Jinja2 env with helpful globals."""
    env = jinja2.Environment(
        loader=jinja2.BaseLoader(),
        undefined=jinja2.StrictUndefined,  # fail on missing vars (catch typos)
        trim_blocks=True,
        lstrip_blocks=True,
        keep_trailing_newline=True,
    )
    env.globals["now"] = dt.datetime.now
    env.filters["strftime"] = lambda d, fmt: d.strftime(fmt)
    return env


def render_markdown(content_path: Path, context: Dict[str, Any]) -> str:
    """Read markdown file, render as Jinja2, return rendered string."""
    raw = content_path.read_text(encoding="utf-8")
    template = build_jinja_env().from_string(raw)
    return template.render(**context)


def render_markdown_dir(content_dir: Path, context: Dict[str, Any]) -> str:
    """
    Concatenate all .md files in a product's content dir (sorted by filename),
    rendering each through Jinja2.
    """
    md_files = sorted(content_dir.glob("*.md"))
    if not md_files:
        raise FileNotFoundError(f"No markdown files in {content_dir}")
    rendered = []
    for md in md_files:
        if md.name.startswith("_"):
            continue  # skip files starting with _ (partials)
        rendered.append(render_markdown(md, context))
        rendered.append("\n\n")
    return "".join(rendered)


# ---------------------------------------------------------------------------
# Pandoc invocation
# ---------------------------------------------------------------------------
def check_dependencies() -> List[str]:
    """Return list of missing tools. Empty list = all good."""
    missing = []
    for tool in ["pandoc"]:
        if not shutil.which(tool):
            missing.append(tool)
    # PDF engine check
    pdf_engine = "xelatex"  # default
    build_cfg = load_yaml(CONFIG_DIR / "build.yaml")
    pdf_engine = build_cfg.get("build", {}).get("pandoc", {}).get("pdf_engine", pdf_engine)
    if not shutil.which(pdf_engine):
        missing.append(pdf_engine)
    return missing


def run_pandoc(input_md: str, output_path: Path, product_cfg: Dict[str, Any],
               build_cfg: Dict[str, Any], fmt: str = "pdf",
               context: Optional[Dict[str, Any]] = None) -> bool:
    """Run Pandoc with the right flags. Returns True on success."""
    if context is None:
        context = {}
    pandoc_cfg = build_cfg.get("build", {}).get("pandoc", {})
    pdf_engine = pandoc_cfg.get("pdf_engine", "xelatex")

    # Pandoc variables — merge global + product
    variables = dict(pandoc_cfg.get("variables", {}))

    # Theme: pick a Pandoc template
    theme_name = product_cfg.get("theme", {}).get("name", "eisvogel")
    theme_path = THEMES_DIR / f"{theme_name}.latex" if fmt == "pdf" else THEMES_DIR / f"{theme_name}.html"
    if theme_path.exists():
        if fmt == "pdf":
            variables["template"] = str(theme_path)
        else:
            variables["template"] = str(theme_path)

    # Build Pandoc command
    cmd = ["pandoc"]
    cmd += ["-f", "markdown"]
    cmd += ["-t", "latex" if fmt == "pdf" else fmt]

    # PDF engine
    if fmt == "pdf":
        cmd += [f"--pdf-engine={pdf_engine}"]

    # Raw LaTeX header-includes. Supports:
    #   - a single string path to a .tex file (e.g. "themes/header-includes.tex")
    #   - a list of inline LaTeX strings
    # All entries are passed to Pandoc via -H.
    raw_includes = pandoc_cfg.get("header_includes")
    paths_to_include: list = []
    if isinstance(raw_includes, str):
        # Resolve path. Supports:
        # - absolute paths (used as-is)
        # - paths starting with "themes/" (stripped, relative to system root)
        # - bare filenames (relative to themes/)
        ri_path = Path(raw_includes)
        if ri_path.is_absolute():
            include_path = ri_path
        elif raw_includes.startswith("themes/"):
            include_path = (SYSTEM_DIR / raw_includes).resolve()
        else:
            include_path = (THEMES_DIR / raw_includes).resolve()
        if include_path.exists():
            paths_to_include.append(str(include_path))
        else:
            console.print(f"[yellow]Header-include file not found:[/yellow] {include_path}")
    elif isinstance(raw_includes, list):
        for h in raw_includes:
            if isinstance(h, str):
                paths_to_include.append(h)
    for h in paths_to_include:
        cmd += ["-H", h]

    # Pandoc variables (passed as -V key=value)
    for k, v in variables.items():
        cmd += [f"-V", f"{k}={v}"]

    # TOC
    if pandoc_cfg.get("toc", False):
        cmd += ["--toc"]
        cmd += [f"--toc-depth={pandoc_cfg.get('toc_depth', 2)}"]

    # Number sections
    if pandoc_cfg.get("number_sections", False):
        cmd += ["--number-sections"]

    # Standalone / self-contained
    if pandoc_cfg.get("standalone", True):
        cmd += ["--standalone"]
    if pandoc_cfg.get("self_contained", True) and fmt == "html":
        cmd += ["--self-contained"]

    # Syntax highlighting (Pandoc 3.x)
    # highlight_style can be either a built-in style name (pygments, tango, etc.)
    # OR a path to a .theme JSON file. Paths must be absolute for Pandoc.
    if "highlight_style" in pandoc_cfg:
        style = pandoc_cfg["highlight_style"]
        if style.endswith(".theme") or style.endswith(".json") or "/" in style:
            style_path = (SYSTEM_DIR / style).resolve()
            if style_path.exists():
                style = str(style_path)
            else:
                console.print(f"[yellow]Highlight style not found:[/yellow] {style_path}")
        cmd += [f"--syntax-highlighting={style}"]

    # PDF metadata is passed via -M (Pandoc metadata block).
    # Template vars in metadata ({{ author.x }}, etc.) must be resolved first.
    pdf_meta_raw = product_cfg.get("pdf", {})
    pdf_meta = {}
    for k, v in pdf_meta_raw.items():
        if isinstance(v, str) and "{{" in v:
            pdf_meta[k] = build_jinja_env().from_string(v).render(**context)
        else:
            pdf_meta[k] = v
    meta_args = []
    if pdf_meta.get("author"):
        meta_args += ["author:" + str(pdf_meta["author"]).strip("\"")]
    if pdf_meta.get("title"):
        meta_args += ["title:" + str(pdf_meta["title"]).strip("\"")]
    if pdf_meta.get("subject"):
        meta_args += ["subject:" + str(pdf_meta["subject"]).strip("\"")]
    if pdf_meta.get("keywords"):
        meta_args += ["keywords:" + str(pdf_meta["keywords"]).strip("\"")]
    if pdf_meta.get("lang"):
        meta_args += ["lang:" + str(pdf_meta["lang"]).strip("\"")]
    if pdf_meta.get("date"):
        meta_args += ["date:" + str(pdf_meta["date"]).strip("\"")]

    for m in meta_args:
        cmd += ["-M", m]

    # Output
    cmd += ["-o", str(output_path)]

    # Input via stdin (we already rendered the merged markdown)
    console.print(f"[dim]Running: pandoc → {fmt.upper()} → {output_path.name}[/dim]")
    result = subprocess.run(
        cmd,
        input=input_md,
        capture_output=True,
        text=True,
    )

    if result.returncode != 0:
        console.print(f"[red]Pandoc failed:[/red]")
        console.print(result.stderr)
        return False
    return True


# ---------------------------------------------------------------------------
# Hooks
# ---------------------------------------------------------------------------
def run_hooks(hook_list: List[str], context: Dict[str, Any]) -> bool:
    """Run a list of hook scripts. Return False if any fails."""
    import json as _json
    for hook_rel in hook_list:
        hook_path = SCRIPTS_DIR / hook_rel
        if not hook_path.exists():
            console.print(f"[yellow]Hook not found (skipping):[/yellow] {hook_rel}")
            continue
        console.print(f"[dim]Running hook: {hook_rel}[/dim]")
        result = subprocess.run(
            [sys.executable, str(hook_path)],
            env={**os.environ, "BUILD_CONTEXT": _json.dumps(context, default=str)},
        )
        if result.returncode != 0:
            console.print(f"[red]Hook failed:[/red] {hook_rel}")
            return False
    return True


# ---------------------------------------------------------------------------
# Build one product
# ---------------------------------------------------------------------------
def build_product(product_yaml: Path, formats: Optional[List[str]] = None,
                  verbose: bool = False) -> bool:
    """Build a single product. Returns True on success."""
    product_id = product_yaml.parent.name
    console.rule(f"[bold]Building: {product_id}[/bold]")

    # Load configs
    product_cfg = load_yaml(product_yaml)
    if not product_cfg:
        console.print(f"[red]Empty config: {product_yaml}[/red]")
        return False

    configs = load_configs()
    build_cfg = configs["build"]
    author_cfg = configs["author"]

    # Build Jinja context — everything available in content.
    # Templates can use {{ author.name }}, {{ author.defaults.license }},
    # {{ product.title }}, or {{ product.audience.platforms }}.
    author_view = {
        **author_cfg.get("author", {}),
        "defaults": author_cfg.get("defaults", {}),
        "social": author_cfg.get("social", {}),
        "links": author_cfg.get("links", {}),
        "brand": author_cfg.get("brand", {}),
    }
    product_view = {
        **product_cfg.get("product", {}),
        "audience": product_cfg.get("audience", {}),
        "distribution": product_cfg.get("distribution", {}),
        "theme": product_cfg.get("theme", {}),
        "pdf": product_cfg.get("pdf", {}),
        "vars": product_cfg.get("vars", {}),
    }
    context = {
        "author": author_view,
        "social": author_cfg.get("social", {}),
        "links": author_cfg.get("links", {}),
        "brand": author_cfg.get("brand", {}),
        "defaults": author_cfg.get("defaults", {}),
        "product": product_view,
        "audience": product_cfg.get("audience", {}),
        "distribution": product_cfg.get("distribution", {}),
        "theme": product_cfg.get("theme", {}),
        "vars": product_cfg.get("vars", {}),
        "build": build_cfg.get("build", {}),
    }

    # Run pre-build hooks
    pre_hooks = build_cfg.get("build", {}).get("hooks", {}).get("pre_hooks", []) or \
                build_cfg.get("build", {}).get("hooks", {}).get("pre_build", [])
    if pre_hooks and not run_hooks(pre_hooks, context):
        return False

    # Render markdown
    content_dir = product_yaml.parent
    try:
        rendered_md = render_markdown_dir(content_dir, context)
    except Exception as e:
        console.print(f"[red]Markdown rendering failed:[/red] {e}")
        return False

    if verbose:
        word_count = len(rendered_md.split())
        console.print(f"[dim]Rendered: {word_count} words, {len(rendered_md)} chars[/dim]")

    # Resolve formats
    if not formats:
        formats = build_cfg.get("build", {}).get("formats", ["pdf"])
    if isinstance(formats, str):
        formats = [formats]

    # Build each format
    output_dir = OUTPUT_DIR / product_cfg.get("product", {}).get("slug", product_id)
    output_dir.mkdir(parents=True, exist_ok=True)
    version = product_cfg.get("product", {}).get("version", "draft")
    slug = product_cfg.get("product", {}).get("slug", product_id)

    all_ok = True
    for fmt in formats:
        ext = {"pdf": "pdf", "html": "html", "epub": "epub", "markdown": "md"}.get(fmt, fmt)
        output_path = output_dir / f"{slug}-v{version}.{ext}"
        ok = run_pandoc(rendered_md, output_path, product_cfg, build_cfg, fmt=fmt, context=context)
        if ok:
            size_kb = output_path.stat().st_size / 1024
            console.print(f"[green]✓[/green] {fmt.upper():8s} → {output_path}  [dim]({size_kb:.1f} KB)[/dim]")
        else:
            console.print(f"[red]✗ {fmt.upper()} failed[/red]")
            all_ok = False

    # Post-build hooks
    post_hooks = build_cfg.get("build", {}).get("hooks", {}).get("post_build", [])
    if post_hooks:
        run_hooks(post_hooks, context)

    return all_ok


# ---------------------------------------------------------------------------
# Watch mode
# ---------------------------------------------------------------------------
def watch_mode(product_yaml: Path):
    """Rebuild on file change."""
    try:
        from watchdog.observers import Observer
        from watchdog.events import FileSystemEventHandler
    except ImportError:
        console.print("[red]watchdog not installed. Run: pip install watchdog[/red]")
        sys.exit(1)

    class _Rebuild(FileSystemEventHandler):
        def on_modified(self, event):
            if event.is_directory:
                return
            console.print(f"\n[yellow]↻ Change detected:[/yellow] {event.src_path}")
            build_product(product_yaml, verbose=True)

    product_dir = product_yaml.parent
    observer = Observer()
    observer.schedule(_Rebuild(), str(product_dir), recursive=True)
    observer.schedule(_Rebuild(), str(CONFIG_DIR), recursive=True)
    observer.start()
    console.print(f"[cyan]👁 Watching[/cyan] {product_dir} and {CONFIG_DIR} (Ctrl+C to stop)")
    try:
        while True:
            time.sleep(1)
    except KeyboardInterrupt:
        observer.stop()
    observer.join()


# ---------------------------------------------------------------------------
# Scaffold new product
# ---------------------------------------------------------------------------
def init_product(product_id: str, template: str = "default") -> bool:
    """Scaffold a new product directory from a template."""
    target = CONTENT_DIR / product_id
    if target.exists():
        console.print(f"[red]Product already exists: {target}[/red]")
        return False
    target.mkdir(parents=True)

    # Copy product.yaml template
    template_yaml = SYSTEM_DIR / "templates" / template / "product.yaml"
    if template_yaml.exists():
        shutil.copy(template_yaml, target / "product.yaml")
    else:
        # Write a minimal one
        (target / "product.yaml").write_text(f"""product:
  id: "{product_id}"
  slug: "{product_id}"
  type: "pdf"
  version: "0.1.0"
  status: "draft"
  title: "Untitled Product"
  subtitle: ""
  tagline: ""

audience:
  primary: ""
  level: "beginner"

theme:
  name: "eisvogel"

pdf:
  author: "{{{{ author.name }}}}"
  title: "{{{{ product.title }}}}"
  subject: "{{{{ product.tagline }}}}"
  keywords: ""
  lang: "{{{{ author.defaults.language }}}}"
""", encoding="utf-8")

    # Copy content markdown templates
    content_template_dir = SYSTEM_DIR / "templates" / template / "content"
    if content_template_dir.exists():
        for f in content_template_dir.glob("*.md"):
            shutil.copy(f, target / f.name)
    else:
        (target / "01-intro.md").write_text("""# {{ product.title }}

{{ product.subtitle }}

## Introduction

Write your opening here.
""", encoding="utf-8")

    console.print(f"[green]✓ Scaffolded:[/green] {target}")
    console.print(f"  Next: edit [cyan]{target}/product.yaml[/cyan] and [cyan]{target}/*.md[/cyan]")
    console.print(f"  Then: [cyan]python build.py {product_id}[/cyan]")
    return True


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------
def main():
    parser = argparse.ArgumentParser(
        description="Build PDFs, HTML, and EPUBs from Markdown + YAML metadata.",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  python build.py                              Build all products
  python build.py modern-cli-stack             Build one product
  python build.py --format pdf                 Override output format
  python build.py --watch modern-cli-stack     Rebuild on file change
  python build.py --list                       Show all products
  python build.py --init my-new-book           Scaffold a new product
        """,
    )
    parser.add_argument("product", nargs="?", help="Product ID to build (default: all)")
    parser.add_argument("--format", choices=["pdf", "html", "epub", "markdown"],
                        help="Override output format (can repeat)")
    parser.add_argument("--watch", "-w", action="store_true", help="Watch mode")
    parser.add_argument("--list", "-l", action="store_true", help="List products")
    parser.add_argument("--init", metavar="ID", help="Scaffold a new product")
    parser.add_argument("--template", default="default", help="Template name for --init")
    parser.add_argument("--status", default="draft", help="Filter products by status")
    parser.add_argument("--verbose", "-v", action="store_true", help="Verbose output")
    args = parser.parse_args()

    # Dependency check
    missing = check_dependencies()
    if missing and not args.init and not args.list:
        console.print(f"[red]Missing dependencies:[/red] {', '.join(missing)}")
        console.print("Install with: brew install pandoc librsvg mactex-no-gui")
        sys.exit(1)

    # --init: scaffold a new product
    if args.init:
        if init_product(args.init, template=args.template):
            sys.exit(0)
        else:
            sys.exit(1)

    # --list: show products
    if args.list:
        products = discover_products()
        if not products:
            console.print("[yellow]No products found in content/[/yellow]")
            console.print(f"Create one with: python build.py --init my-product-id")
            return
        table = Table(title="Configured Products")
        table.add_column("ID", style="cyan")
        table.add_column("Status", style="green")
        table.add_column("Title")
        table.add_column("Version")
        for path in products:
            cfg = load_yaml(path)
            p = cfg.get("product", {})
            table.add_row(
                p.get("id", "?"),
                p.get("status", "?"),
                p.get("title", "?"),
                p.get("version", "?"),
            )
        console.print(table)
        return

    # --watch: watch mode for single product
    if args.watch:
        if not args.product:
            console.print("[red]--watch requires a product ID[/red]")
            sys.exit(1)
        product_yaml = CONTENT_DIR / args.product / "product.yaml"
        if not product_yaml.exists():
            console.print(f"[red]Product not found:[/red] {args.product}")
            sys.exit(1)
        # Build once, then watch
        build_product(product_yaml, verbose=args.verbose)
        watch_mode(product_yaml)
        return

    # Normal build
    formats = [args.format] if args.format else None
    if args.product:
        product_yaml = CONTENT_DIR / args.product / "product.yaml"
        if not product_yaml.exists():
            console.print(f"[red]Product not found:[/red] {args.product}")
            console.print(f"Available products:")
            for p in discover_products():
                console.print(f"  - {p.parent.name}")
            sys.exit(1)
        ok = build_product(product_yaml, formats=formats, verbose=args.verbose)
    else:
        products = discover_products(filter_status=args.status)
        if not products:
            console.print(f"[yellow]No products with status='{args.status}'[/yellow]")
            return
        console.print(f"[cyan]Building {len(products)} product(s)...[/cyan]")
        results = [build_product(p, formats=formats, verbose=args.verbose) for p in products]
        ok = all(results)

    sys.exit(0 if ok else 1)


if __name__ == "__main__":
    main()
