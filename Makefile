# Convenience wrapper around docker compose for the Rust Jupyter environment.
#
# NOTEBOOK is given RELATIVE TO the notebooks/ folder (mounted at /workspace),
# e.g.  make export-html NOTEBOOK=example.ipynb

COMPOSE ?= docker compose
SERVICE ?= rust-jupyter
NOTEBOOK ?= example.ipynb

.PHONY: help build build-pdf up down shell logs \
        pair export-html export-pdf export-script rebuild-cache \
        book book-clean sync-notebooks

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) \
		| awk 'BEGIN{FS=":.*?## "}{printf "  \033[36m%-16s\033[0m %s\n", $$1, $$2}'

build: ## Build the image (no PDF layer)
	$(COMPOSE) build

build-pdf: ## Build the image WITH the PDF export layer (~1GB+)
	$(COMPOSE) build --build-arg INCLUDE_PDF_EXPORT=true

up: ## Start JupyterLab and print the URL
	$(COMPOSE) up -d
	@echo ""
	@echo "JupyterLab is starting -> http://localhost:8888"
	@echo "(if JUPYTER_TOKEN is set, append ?token=YOUR_TOKEN)"
	@echo "Follow logs with: make logs"

down: ## Stop and remove the container
	$(COMPOSE) down

shell: ## Open a bash shell inside the running container
	$(COMPOSE) exec $(SERVICE) bash

logs: ## Tail container logs
	$(COMPOSE) logs -f $(SERVICE)

pair: ## Pair a notebook with a .md twin (ipynb,md) via jupytext
	$(COMPOSE) exec $(SERVICE) jupytext --set-formats ipynb,md /workspace/$(NOTEBOOK)

export-html: ## Export a notebook to HTML
	$(COMPOSE) exec $(SERVICE) jupyter nbconvert --to html /workspace/$(NOTEBOOK)

export-pdf: ## Export a notebook to PDF (requires image built with build-pdf)
	$(COMPOSE) exec $(SERVICE) jupyter nbconvert --to pdf /workspace/$(NOTEBOOK)

export-script: ## Export the Rust cells to a flat .rs-style script (reference only)
	$(COMPOSE) exec $(SERVICE) jupyter nbconvert --to script /workspace/$(NOTEBOOK)

rebuild-cache: ## Re-run the crate pre-warm in the running container (no full rebuild)
	$(COMPOSE) exec -T $(SERVICE) evcxr < prewarm.evcxr

# ---- Jupyter Book ---------------------------------------------------------
# These build the book INSIDE the running container (needs `make up` first).
# Windows/Git Bash: prefix with MSYS_NO_PATHCONV=1 (see README).
book: ## Build the book (executes all chapters) -> book/_build/html
	$(COMPOSE) exec -T $(SERVICE) jupyter-book build /book --all
	@echo "Built: open book/_build/html/index.html"

book-clean: ## Remove the book's generated _build output
	$(COMPOSE) exec -T $(SERVICE) jupyter-book clean /book --all

sync-notebooks: ## jupytext --sync every chapter notebook (pair .ipynb <-> .md)
	$(COMPOSE) exec -T $(SERVICE) sh -c 'find /book -name "*.ipynb" -not -path "*/_build/*" -exec jupytext --sync {} +'
