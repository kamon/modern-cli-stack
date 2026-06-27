#!/usr/bin/env python3
"""Validate product config before build."""
import sys, os
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
from build import load_yaml, CONFIG_DIR  # noqa
import yaml

errors = []

# Author config must have required fields
author = load_yaml(CONFIG_DIR / "author.yaml")
if not author.get("author", {}).get("name"):
    errors.append("author.yaml: author.name is required")

# Walk all products
content_dir = Path(__file__).resolve().parent.parent.parent / "content"
if content_dir.exists():
    for pdir in content_dir.iterdir():
        if not pdir.is_dir():
            continue
        pcfg_path = pdir / "product.yaml"
        if not pcfg_path.exists():
            continue
        pcfg = load_yaml(pcfg_path)
        product = pcfg.get("product", {})
        if not product.get("id"):
            errors.append(f"{pdir.name}/product.yaml: product.id is required")
        if not product.get("title"):
            errors.append(f"{pdir.name}/product.yaml: product.title is required")

if errors:
    print("❌ Config validation failed:")
    for e in errors:
        print(f"  - {e}")
    sys.exit(1)
else:
    print("✅ Config validation passed")
    sys.exit(0)
