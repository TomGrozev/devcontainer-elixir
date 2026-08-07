# Elixir devcontainer — layers Erlang/OTP + Elixir on the shared base
# Toolchain is extracted from the official hexpm image via COPY --from.

ARG BASE=base
ARG ELIXIR_VERSION
ARG OTP_VERSION
ARG DEBIAN_VERSION

# Stage 1: grab the pinned toolchain from hexpm
FROM hexpm/elixir:${ELIXIR_VERSION}-erlang-${OTP_VERSION}-debian-${DEBIAN_VERSION} AS toolchain

# Stage 2: layer onto the shared base
FROM ${BASE}

USER root

# Re-declare args for use in this stage
ARG ELIXIR_VERSION
ARG OTP_VERSION
ARG DEBIAN_VERSION

# Install Erlang runtime deps + inotify-tools (Phoenix live-reload)
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    set -e \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
    ca-certificates \
    libodbc2 \
    libssl3t64 \
    libsctp1 \
    netbase \
    unixodbc \
    inotify-tools \
    && rm -rf /var/lib/apt/lists/*

# Copy Erlang/OTP and Elixir from the hexpm toolchain image
# Copy the lib trees explicitly — NOT /usr/local/bin, which the base owns.
COPY --from=toolchain /usr/local/lib/erlang /usr/local/lib/erlang
COPY --from=toolchain /usr/local/lib/elixir /usr/local/lib/elixir

# Create wrappers for Erlang and Elixir binaries
RUN ln -sf /usr/local/lib/erlang/bin/erl /usr/local/bin/erl \
    && ln -sf /usr/local/lib/erlang/bin/erlc /usr/local/bin/erlc \
    && ln -sf /usr/local/lib/erlang/bin/escript /usr/local/bin/escript \
    && ln -sf /usr/local/lib/erlang/bin/dialyzer /usr/local/bin/dialyzer \
    && ln -sf /usr/local/lib/elixir/bin/elixir /usr/local/bin/elixir \
    && ln -sf /usr/local/lib/elixir/bin/elixirc /usr/local/bin/elixirc \
    && ln -sf /usr/local/lib/elixir/bin/mix /usr/local/bin/mix \
    && ln -sf /usr/local/lib/elixir/bin/iex /usr/local/bin/iex

ENV LANG=C.UTF-8 \
    MIX_HOME=/home/dev/.mix \
    HEX_HOME=/home/dev/.hex

# Create mix/hex directories (PVC will shadow these at runtime if mounted;
# the bootstrap script below handles first-time init idempotently)
RUN mkdir -p /home/dev/.mix /home/dev/.hex \
    && chown -R dev:dev /home/dev/.mix /home/dev/.hex

# Bootstrap script — run once per workspace to init mix/hex
COPY images/elixir/bootstrap.sh /usr/local/share/devcontainer/bootstrap.sh
RUN chmod +x /usr/local/share/devcontainer/bootstrap.sh

USER dev
