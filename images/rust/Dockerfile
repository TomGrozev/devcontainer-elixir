# Rust devcontainer — layers Rust on the shared base via rustup-init.

ARG BASE=base
ARG RUST_VERSION

FROM ${BASE}

USER root

ARG RUST_VERSION

ENV RUSTUP_HOME=/usr/local/rustup \
    CARGO_HOME=/usr/local/cargo \
    PATH="/usr/local/cargo/bin:${PATH}"

# Install Rust toolchain via rustup (minimal profile + common dev components)
# Toolchains and shims live outside /home/dev so the PVC doesn't shadow them.
# Runtime CARGO_HOME is redirected to the PVC via ENV in the coder template.
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | \
    sh -s -- -y \
    --profile minimal \
    --component rustfmt,clippy,rust-analyzer,rust-src \
    --default-toolchain "${RUST_VERSION}" \
    && rustup default "${RUST_VERSION}" \
    && chmod -R a+r /usr/local/rustup \
    && chmod -R a+r /usr/local/cargo

# Install build deps needed by common crates (openssl-sys, etc.)
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    set -e \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
    pkg-config \
    libssl-dev \
    && rm -rf /var/lib/apt/lists/*

# Bootstrap script — runs on first workspace start (currently a no-op;
# the PVC-mounted /home/dev/.cargo handles mutable state persistence)
COPY images/rust/bootstrap.sh /usr/local/share/devcontainer/bootstrap.sh
RUN chmod +x /usr/local/share/devcontainer/bootstrap.sh

# Runtime override: redirect cargo's mutable state to the PVC
ENV CARGO_HOME=/home/dev/.cargo \
    PATH="/usr/local/cargo/bin:/home/dev/.cargo/bin:${PATH}"

USER dev
