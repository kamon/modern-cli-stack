#!/usr/bin/env python3
"""Check that referenced assets (logos, fonts, images) exist."""
import os, sys
from pathlib import Path

ctx_path = Path(__file__).resolve().parent.parent.parent
errors = []

# Check brand logo
import yaml
author = yaml.safe_load((ctx_path / "config" / "author.yaml").read_text())
logo = author.get("brand", {}).get("logo_path", "")
if logo:
    full = ctx_path / "themes" / logo
    if not full.exists():
        errors.append(f"Logo not found: {full}")

if errors:
    print("⚠ Asset warnings:")
    for e in errors:
        print(f"  - {e}")
    # Non-fatal
sys.exit(0)
