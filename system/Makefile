# Convenience wrapper around build.py
# Usage:  make build   /   make watch   /   make clean

VENV     := .venv
PY       := $(VENV)/bin/python
PIP      := $(VENV)/bin/pip

.PHONY: setup build build-pdf watch list clean test new help

help:           ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2}'

setup:          ## Create venv and install Python deps
	test -d $(VENV) || python3 -m venv $(VENV)
	$(PIP) install --quiet --upgrade pip
	$(PIP) install --quiet pyyaml jinja2 rich watchdog
	@echo "✅ Setup complete. Run: source $(VENV)/bin/activate"

build:          ## Build all products
	$(PY) scripts/build.py

build-pdf:      ## Build only PDFs
	$(PY) scripts/build.py --format pdf

watch:          ## Watch & rebuild (requires product id: make watch PRODUCT=foo)
	$(PY) scripts/build.py --watch $(PRODUCT)

list:           ## List configured products
	$(PY) scripts/build.py --list

audit:          ## Audit all content for AI tells
	$(PY) scripts/hooks/check_ai_tells.py --mode audit content/

test:           ## Validate configs (dry run)
	$(PY) scripts/hooks/validate_config.py

new:            ## Scaffold new product (usage: make new ID=my-book)
	$(PY) scripts/build.py --init $(ID)

clean:          ## Remove build outputs
	rm -rf output/

clean-all:      ## Remove outputs AND venv
	rm -rf output/ $(VENV)
