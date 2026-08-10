# syntax=docker/dockerfile:1

##############################################################################
# Portable Rust Jupyter environment
#
# Pinned Rust toolchain + evcxr kernel + JupyterLab + a pre-warmed crate cache.
# The PDF-export toolchain (texlive-xetex, ~1GB+) is behind a build arg and
# OFF by default. Turn it on with:  --build-arg INCLUDE_PDF_EXPORT=true
##############################################################################

# Pin the Rust version rather than :latest for reproducibility.
# Must be >= 1.85 — evcxr_jupyter requires Rust edition 2024 (stabilized in 1.85).
FROM rust:1.90-slim-bookworm

# ---- Build args -----------------------------------------------------------
ARG INCLUDE_PDF_EXPORT=false
# evcxr kernel + REPL versions (kept in lockstep).
ARG EVCXR_VERSION=0.21.1
# sccache gives evcxr a PERSISTENT compilation cache (see step 3b).
ARG SCCACHE_VERSION=0.8.2

# ---- Environment ----------------------------------------------------------
# Tokenless by default for local dev; override JUPYTER_TOKEN at run time to
# require auth. Jupyter Server reads this env var natively as its token.
ENV JUPYTER_TOKEN=""
ENV CARGO_HOME=/usr/local/cargo
ENV PATH=/usr/local/cargo/bin:$PATH
ENV PIP_BREAK_SYSTEM_PACKAGES=1
ENV PYTHONUNBUFFERED=1

# ---- 1. System dependencies ----------------------------------------------
RUN apt-get update && apt-get install -y --no-install-recommends \
        build-essential \
        cmake \
        pkg-config \
        libssl-dev \
        python3 \
        python3-pip \
        python3-venv \
        pandoc \
        curl \
        ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# ---- 1b. Optional PDF export layer (heavy: texlive-xetex ~1GB+) -----------
RUN if [ "$INCLUDE_PDF_EXPORT" = "true" ]; then \
        apt-get update && apt-get install -y --no-install-recommends \
            texlive-xetex \
            texlive-fonts-recommended \
            texlive-plain-generic \
        && rm -rf /var/lib/apt/lists/* ; \
    else \
        echo "Skipping PDF export layer (INCLUDE_PDF_EXPORT=$INCLUDE_PDF_EXPORT)"; \
    fi

# ---- 2. Python packages (pinned in requirements.txt) ----------------------
COPY requirements.txt /tmp/requirements.txt
RUN pip3 install --no-cache-dir -r /tmp/requirements.txt

# ---- 3. evcxr Jupyter kernel + REPL --------------------------------------
# The REPL binary (`evcxr`) is used at build time to pre-warm the crate cache.
RUN cargo install evcxr_jupyter --version ${EVCXR_VERSION} --locked \
    && cargo install evcxr_repl   --version ${EVCXR_VERSION} --locked \
    && evcxr_jupyter --install

# ---- 3b. sccache: persistent compilation cache ----------------------------
# evcxr recompiles dependencies from scratch in a throwaway dir every session,
# so baking crates in alone only caches DOWNLOADS, not compiled artifacts.
# sccache turns those recompiles into cache hits — this is what makes the
# pre-warm below actually pay off at notebook time (~5-10x on the heavy crates).
RUN set -eux; \
    arch="$(dpkg --print-architecture)"; \
    case "$arch" in \
      amd64) sarch=x86_64 ;; \
      arm64) sarch=aarch64 ;; \
      *) echo "unsupported arch: $arch" >&2; exit 1 ;; \
    esac; \
    url="https://github.com/mozilla/sccache/releases/download/v${SCCACHE_VERSION}/sccache-v${SCCACHE_VERSION}-${sarch}-unknown-linux-musl.tar.gz"; \
    curl -sSL "$url" -o /tmp/sccache.tar.gz; \
    tar -xzf /tmp/sccache.tar.gz -C /tmp; \
    cp "/tmp/sccache-v${SCCACHE_VERSION}-${sarch}-unknown-linux-musl/sccache" /usr/local/bin/sccache; \
    chmod +x /usr/local/bin/sccache; \
    rm -rf /tmp/sccache*; \
    sccache --version

# Route all rustc calls (build-time prewarm AND runtime notebooks) through sccache.
ENV RUSTC_WRAPPER=/usr/local/bin/sccache
ENV SCCACHE_DIR=/opt/sccache
ENV SCCACHE_CACHE_SIZE=20G

# ---- 4. Pre-warm the crate cache -----------------------------------------
# Compile every crate in the standard set ONCE at build time so the first use
# inside a notebook is instant instead of a multi-minute compile. This is the
# single biggest UX win for this stack.
COPY prewarm.evcxr /opt/prewarm.evcxr
# Cap parallelism during the prewarm so compiling the whole crate set at once
# doesn't spike memory hard enough to OOM the Docker VM (seen as "Bus error").
# Override at build time with --build-arg PREWARM_JOBS=N. Runtime notebook
# compiles are unaffected (they use full parallelism).
ARG PREWARM_JOBS=4
RUN CARGO_BUILD_JOBS=${PREWARM_JOBS} evcxr < /opt/prewarm.evcxr && sccache --show-stats

# ---- 5. Workspace + port --------------------------------------------------
WORKDIR /workspace
EXPOSE 8888

# ---- 6. Launch JupyterLab -------------------------------------------------
# Token is controlled by the JUPYTER_TOKEN env var. NOTE: an *empty* JUPYTER_TOKEN
# does NOT disable auth on its own — Jupyter then generates a random token. So we
# pass it explicitly: empty => "--IdentityProvider.token=" => no auth; a value
# => that token is required. Shell form so $JUPYTER_TOKEN expands at start.
CMD jupyter lab \
     --ip=0.0.0.0 \
     --port=8888 \
     --no-browser \
     --allow-root \
     --ServerApp.root_dir=/workspace \
     --IdentityProvider.token="${JUPYTER_TOKEN}"
