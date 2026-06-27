#!/usr/bin/env python3
"""Print build summary after a successful build."""
import os, sys, json
from pathlib import Path

ctx = json.loads(os.environ.get("BUILD_CONTEXT", "{}"))
product = ctx.get("product", {})

print()
print("━" * 60)
print(f"✅ Built: {product.get('title', '?')} v{product.get('version', '?')}")
print(f"   Slug: {product.get('slug', '?')}")
print(f"   ID:   {product.get('id', '?')}")
print(f"   Output: output/{product.get('slug', '?')}/")
print("━" * 60)
