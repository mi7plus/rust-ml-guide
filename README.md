# Portable Rust Jupyter Notebook Environment

A Dockerized [JupyterLab](https://jupyter.org/) setup for interactive **Rust**
development (data-science / ML-style workflows) using the
[`evcxr`](https://github.com/evcxr/evcxr) kernel. Everything runs inside a
container, so the **only host dependency is Docker**. No local Rust or Jupyter
install required.

## Stack

| Component            | Purpose                                         |
| ------------------- | ----------------------------------------------- |
| Rust `1.90` (pinned) | Toolchain (>= 1.85 required by evcxr)             |
| `evcxr_jupyter`     | Rust Jupyter kernel                              |
| JupyterLab          | Notebook UI                                      |
| `jupytext`          | Git-friendly `.ipynb` ⇄ `.md` pairing           |
| `nbconvert` + pandoc | Export to HTML / PDF / script                   |

**Pre-warmed crates** (compiled into the image cache so first use is instant):
`ndarray`, `polars`, `linfa`, `linfa-clustering`, `linfa-trees`, `linfa-linear`,
`linfa-logistic`, `linfa-reduction`, `smartcore`, `plotters`, `argmin`.

This repo also hosts the **Rust ML Guide**, a multi-chapter
[Jupyter Book](https://jupyterbook.org) built from executable notebooks under
[`book/`](book/) — see [The book](#the-book-rust-ml-guide) below.

## Why Rust for data science / ML?

Honest answer: it depends on the layer. The wins are large and well-documented
for **data wrangling**, and more nuanced for **model training**. Where Rust
doesn't clearly beat Python, this section says so.

### Data processing: a real, measured win (`polars` vs `pandas`)

`polars` is the standout. On the PDS-H benchmark suite (derived from TPC-H),
Polars' own published results put it **~an order of magnitude faster than Dask
and PySpark**, and dramatically faster than pandas — up to **~30×** on the most
join-heavy queries, with **3–10×** being typical in everyday workloads. It also
used roughly **63% of the energy** pandas needed on large frames.

| Workload | Reported result | Source |
| -------- | --------------- | ------ |
| PDS-H (TPC-H-derived) queries | Polars ≈ order of magnitude faster than Dask/PySpark; up to ~30× vs pandas | [pola.rs benchmarks](https://pola.rs/posts/benchmarks/) |
| Large-frame processing energy | Polars ≈ 63% of pandas' energy | [pola.rs energy benchmark](https://pola.rs/posts/benchmark-energy-performance/) |

Why the gap: pandas' hash-join is single-threaded, while Polars uses a
multithreaded hash-join with predicate/projection pushdown over Arrow columnar
memory. (Note: PDS-H results aren't official TPC-H numbers and depend heavily on
hardware — the figures above came from a 96-vCPU cloud box. Treat them as
directional, not guarantees.)

### The language-level reasons

- **Compiled + no GIL.** Rust compiles to native code and has no Global
  Interpreter Lock, so CPU-bound work parallelizes across cores for free.
  Python leans on C extensions (NumPy, scikit-learn) precisely to escape these
  limits — with Rust you're *already* in the fast layer, no FFI boundary.
- **Predictable memory, no GC pauses.** Ownership gives tight, deterministic
  memory use — the basis for the energy result above.
- **Single-binary deployment.** A trained model compiles into one static binary
  with no Python runtime, interpreter version, or dependency environment to ship
  — often the deciding factor for embedded / serverless / edge inference.
- **Type & memory safety end-to-end.** The compiler catches shape/type mistakes
  before runtime, across the whole data-to-model pipeline.

### Model training: a fair comparison

For the modeling crates (`linfa`, `smartcore`) the speed story is **not** a
slam-dunk, and this guide won't pretend otherwise: scikit-learn's estimators are
already backed by C/Cython/BLAS, so they're fast. The Rust case for these is
less "it's X times faster" and more **deployment, safety, memory footprint, and
staying in one language end-to-end**. The ecosystem is also younger and thinner
than Python's — the book's later chapters flag this explicitly, crate by crate.

**Bottom line:** reach for Rust here when you want a fast, parallel data pipeline
and a self-contained deployable artifact — not on the assumption that every
model trains faster than scikit-learn.

Sources: [pola.rs benchmarks](https://pola.rs/posts/benchmarks/) ·
[pola.rs energy benchmark](https://pola.rs/posts/benchmark-energy-performance/)

## Prerequisites

- Docker (with the Compose plugin — `docker compose`)
- `make` is optional; every target maps to a plain `docker compose` command if
  you'd rather run those directly.
- **Memory:** give Docker a decent chunk of RAM (**≥ 6–8 GB** recommended). The
  build compiles the whole crate set at once; on a memory-starved Docker VM this
  can OOM and crash the engine (a `Bus error (core dumped)` mid-build). The
  pre-warm caps parallelism (`PREWARM_JOBS`, default 4) to keep this in check —
  lower it further on tight machines: `docker compose build --build-arg PREWARM_JOBS=2`.

## Quickstart

```bash
make build      # docker compose build
make up         # start JupyterLab, prints http://localhost:8888
```

Then open <http://localhost:8888> and launch the **Rust** kernel. Open
`example.ipynb` and run all cells to smoke-test every pre-warmed crate.

Stop it with:

```bash
make down
```

No `make`? The equivalents:

```bash
docker compose build
docker compose up -d
docker compose down
```

## Authentication

By default the server runs **tokenless** for convenience on a local machine.
To require a token, set `JUPYTER_TOKEN` before starting:

```bash
JUPYTER_TOKEN=mysecret make up
# then browse to http://localhost:8888/?token=mysecret
```

`JUPYTER_TOKEN` is read natively by Jupyter Server. Leave it empty for no auth.

## Where notebooks live

The host `./notebooks` directory is mounted into the container at `/workspace`.
Anything you create in JupyterLab lands there on your host — persistent,
portable, and git-trackable. The container itself is disposable.

Two named volumes persist state across restarts:

- `cargo-registry` — crates you add later (via a new `:dep`) that weren't in the
  pre-warm set, so they don't re-download every restart.
- `sccache-cache` — the compilation cache (see below), seeded on first run from
  the pre-warmed cache baked into the image.

### Why pre-warming needs sccache

evcxr recompiles a notebook's dependencies from scratch, in a throwaway build
directory, on every kernel session. So baking crates into the image at build
time only caches their *downloads* — not their *compiled* form — which on its
own saves almost nothing at notebook time. To make the pre-warm actually pay
off, the image routes every `rustc` call through
[`sccache`](https://github.com/mozilla/sccache) (`RUSTC_WRAPPER`), a persistent
compilation cache. The pre-warm step populates it during the build, so the
first time you use a pre-warmed crate in a notebook it's a cache hit (measured
~5-10x faster on the heavy crates) instead of a cold compile.

## Exporting

The `.ipynb` file is already the most portable artifact — it opens on any
machine with Jupyter + the evcxr kernel, or back in this container elsewhere.
For other formats (`NOTEBOOK` is relative to `notebooks/`):

```bash
make export-html   NOTEBOOK=example.ipynb   # -> notebooks/example.html
make export-script NOTEBOOK=example.ipynb   # -> notebooks/example.rs (reference log)
make export-pdf    NOTEBOOK=example.ipynb   # needs the PDF build (see below)
make pair          NOTEBOOK=example.ipynb   # create/refresh a .md twin (ipynb,md)
```

**jupytext pairing** keeps a plain-text `.md` version of a notebook alongside
the `.ipynb`, so git diffs are readable and notebooks can be edited as text.
Run `make pair` once per notebook; JupyterLab then keeps both in sync on save.

> Note: `export-script` dumps the Rust cells as a flat file. It is **not**
> directly compilable — evcxr cells aren't a single crate — but it's a useful
> readable log of the code.

> **Windows / Git Bash users:** MSYS rewrites the container path
> `/workspace/...` into a host path before Docker sees it, which breaks the
> `export-*` / `pair` targets. Prefix the command with `MSYS_NO_PATHCONV=1`,
> e.g. `MSYS_NO_PATHCONV=1 make export-html NOTEBOOK=example.ipynb`. This does
> not affect Linux/macOS hosts.

### PDF export (optional, heavy)

PDF needs `texlive-xetex` (~1GB+), so it's behind a build arg and **off by
default**. Build the PDF-capable image with:

```bash
make build-pdf      # docker compose build --build-arg INCLUDE_PDF_EXPORT=true
```

## Adding a crate to the pre-warm set

1. Add a pinned `:dep` line to [`prewarm.evcxr`](prewarm.evcxr).
2. Either rebuild the image (`make build`) to bake it in, or warm the
   **running** container without a full rebuild:

   ```bash
   make rebuild-cache   # re-runs prewarm.evcxr inside the container
   ```

Keep the crate list in `prewarm.evcxr` and the README table in sync.

## The book (Rust ML Guide)

The [`book/`](book/) directory is a [Jupyter Book](https://jupyterbook.org): a
multi-chapter guide to machine learning in Rust, written as executable notebooks
that are compiled and run at build time so the published pages show **real Rust
outputs** (printed results and `plotters` charts).

Chapters (see [`book/_toc.yml`](book/_toc.yml)): setup → `ndarray`/`polars`
foundations → linear & logistic regression → k-means & DBSCAN clustering →
decision trees → PCA → AutoML → crate-reference appendix.

### Build the book locally

```bash
make up            # start the container (once)
make book          # jupyter-book build /book --all  ->  book/_build/html
```

Then open `book/_build/html/index.html`. On Windows/Git Bash prefix with
`MSYS_NO_PATHCONV=1` (same reason as the export targets above).

`make book` re-executes every chapter (`execute_notebooks: force` in
[`book/_config.yml`](book/_config.yml)) so output always matches current code. If
per-chapter Rust recompiles make this too slow, switch that setting to `cache`.

### Publish to GitHub Pages

A workflow at [`.github/workflows/deploy-book.yml`](.github/workflows/deploy-book.yml)
builds the image, runs `jupyter-book build` inside it, and deploys `book/_build/html`
to Pages on every push to `main` (PRs build a preview without deploying). To turn
it on:

1. In [`book/_config.yml`](book/_config.yml), set `repository.url` to your repo.
2. Push to GitHub, then in **Settings → Pages** set **Source: GitHub Actions**.

> The CI image build compiles evcxr + all crates (~20+ min) each run unless you
> add layer caching. The AutoML chapter's `automl` crate is git-sourced, which
> adds fetch/compile time.

### Adding a chapter

1. Create a notebook in the right `book/NN-part/` folder (Rust kernel).
2. Add its path to [`book/_toc.yml`](book/_toc.yml).
3. Pair it: `make sync-notebooks` (keeps a `.md` twin for readable diffs).
4. Open a PR — CI executes and previews it.

### Git-friendly notebooks

`make sync-notebooks` runs `jupytext --sync` over every chapter, keeping each
`.ipynb` paired with a MyST `.md`. Commit both; PR diffs then read as Markdown
instead of giant JSON blobs.

## Portability notes

- A fresh `git clone` + `make build && make up` should reach a working
  JupyterLab with the Rust kernel and zero other host setup.
- Multi-arch: to confirm the image builds for both Intel and Apple Silicon:

  ```bash
  docker buildx build --platform linux/amd64,linux/arm64 .
  ```

  This environment was authored/tested on `amd64`; the Dockerfile uses only
  arch-neutral base images and packages, but treat `arm64` as untested until
  you run the buildx check on your side.

## Known limitations

- **Per-cell compile latency** is inherent to evcxr: each cell that introduces
  new code is compiled. Pre-warming removes the *dependency* compile cost, not
  the incremental per-cell cost. This is a property of the tool, not something
  this setup can fully hide.
- `export-script` output is a reference log, not a buildable crate (see above).
