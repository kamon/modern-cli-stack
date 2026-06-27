#!/usr/bin/env bash
#
# release.sh — Bump version, rebuild PDF, tag, push.
#
# Usage:  ./scripts/release.sh [version]
#   e.g.  ./scripts/release.sh 2026.2
#         ./scripts/release.sh          (auto-bumps patch)
#
# What it does:
#   1. Updates version in content/modern-cli-stack/product.yaml
#   2. Rebuilds the PDF
#   3. Verifies the build succeeded
#   4. Commits the version bump
#   5. Creates a git tag (v<version>)
#   6. Pushes the commit + tag to origin
#
# Requirements: working tree clean (no uncommitted changes), on main branch,
# remote named "origin", gh CLI authenticated.

set -euo pipefail

cd "$(dirname "$0")/.."
ROOT="$(pwd)"

# ---- Pre-flight checks ---------------------------------------------------

if [ -n "$(git status --porcelain)" ]; then
    echo "ERROR: Working tree has uncommitted changes."
    echo "Commit or stash them first."
    git status --short
    exit 1
fi

CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
if [ "$CURRENT_BRANCH" != "main" ]; then
    echo "ERROR: Must be on main branch (currently on $CURRENT_BRANCH)."
    exit 1
fi

# ---- Version handling ----------------------------------------------------

PRODUCT_YAML="$ROOT/content/modern-cli-stack/product.yaml"
CURRENT_VERSION=$(grep -E "^[[:space:]]+version:" "$PRODUCT_YAML" | head -1 | sed 's/.*version:[[:space:]]*"\?\([^"]*\)"\?.*/\1/')

if [ $# -ge 1 ]; then
    NEW_VERSION="$1"
else
    # Auto-bump patch: 2026.1 -> 2026.2
    MAJOR=$(echo "$CURRENT_VERSION" | cut -d. -f1)
    MINOR=$(echo "$CURRENT_VERSION" | cut -d. -f2)
    NEW_MINOR=$((MINOR + 1))
    NEW_VERSION="${MAJOR}.${NEW_MINOR}"
fi

echo "Current version: $CURRENT_VERSION"
echo "New version:     $NEW_VERSION"
echo
read -p "Continue? [y/N] " -r
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Aborted."
    exit 1
fi

# ---- Bump version --------------------------------------------------------

sed -i.bak "s/^[[:space:]]*version:[[:space:]]*\"[^\"]*\"/  version: \"$NEW_VERSION\"/" "$PRODUCT_YAML"
rm "$PRODUCT_YAML.bak"
echo "Updated $PRODUCT_YAML"

# ---- Rebuild -------------------------------------------------------------

echo "Rebuilding PDF..."
cd system
.venv/bin/python scripts/build.py modern-cli-stack || {
    echo "ERROR: Build failed. Version bump kept, but PDF not regenerated."
    exit 1
}
cd ..

PDF=$(ls system/output/modern-cli-stack/modern-cli-stack-v${NEW_VERSION}.pdf 2>/dev/null || \
      ls system/output/modern-cli-stack/*.pdf | head -1)
echo "Built: $PDF"

# ---- Commit + tag + push -------------------------------------------------

git add content/modern-cli-stack/product.yaml system/output/modern-cli-stack/ CHANGELOG.md
git commit -m "Release v${NEW_VERSION}"
git tag -a "v${NEW_VERSION}" -m "Release v${NEW_VERSION}"
git push origin main
git push origin "v${NEW_VERSION}"

echo
echo "✓ Released v${NEW_VERSION}"
echo "Tag pushed: v${NEW_VERSION}"
echo
echo "Next: create a GitHub release at https://github.com/kamon/cli-resources/releases/new?tag=v${NEW_VERSION}"
echo "      Attach the PDF: $PDF"