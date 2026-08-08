# Shared devcontainer base — system tools, CLI utilities, user setup
# Language toolchains layer on top via COPY --from or package managers.

# Build args (no defaults — docker-bake.hcl supplies all values)
ARG DEBIAN_VERSION
ARG TZ
ARG NODE_MAJOR
# renovate: datasource=github-releases depName=neovim/neovim extractVersion=^(?<version>.*)$
ARG NVIM_VERSION
# renovate: datasource=github-releases depName=rtk-ai/rtk extractVersion=^(?<version>.*)$
ARG RTK_VERSION
# renovate: datasource=github-releases depName=dandavison/delta extractVersion=^(?<version>.*)$
ARG DELTA_VERSION
# renovate: datasource=github-releases depName=BurntSushi/ripgrep extractVersion=^(?<version>.*)$
ARG RIPGREP_VERSION
# renovate: datasource=github-releases depName=sharkdp/bat extractVersion=^v(?<version>.+)$
ARG BAT_VERSION
# renovate: datasource=github-releases depName=anomalyco/opencode extractVersion=^v(?<version>.+)$
ARG OPENCODE_VERSION
# renovate: datasource=github-releases depName=zellij-org/zellij extractVersion=^v(?<version>.+)$
ARG ZELLIJ_VERSION
# renovate: datasource=github-releases depName=sharkdp/fd extractVersion=^v(?<version>.+)$
ARG FD_VERSION

FROM debian:${DEBIAN_VERSION}

# Re-declare args for use in this stage
ARG DEBIAN_VERSION
ARG TZ
ARG NODE_MAJOR
ARG NVIM_VERSION
ARG RTK_VERSION
ARG DELTA_VERSION
ARG RIPGREP_VERSION
ARG BAT_VERSION
ARG OPENCODE_VERSION
ARG ZELLIJ_VERSION
ARG FD_VERSION
ARG TARGETARCH

ENV DEBIAN_FRONTEND=noninteractive \
    TZ=${TZ} \
    LANG=en_AU.UTF-8 \
    EDITOR=nvim \
    VISUAL=nvim \
    NPM_CONFIG_PREFIX=/home/dev/.local \
    PATH="/home/dev/.local/bin:${PATH}"

# System packages, locale, timezone, Node.js, GitHub CLI
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    set -e \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
    less \
    git \
    procps \
    sudo \
    fzf \
    zsh \
    unzip \
    curl \
    ca-certificates \
    jq \
    locales \
    gcc \
    make \
    pip \
    pipx \
    openssh-client \
    libc-dev \
    build-essential \
    g++ \
    gpg \
    gpg-agent \
    zoxide \
    && sed -i 's/^# *en_AU.UTF-8/en_AU.UTF-8/' /etc/locale.gen \
    && locale-gen en_AU.UTF-8 \
    && ln -snf /usr/share/zoneinfo/${TZ} /etc/localtime \
    && echo ${TZ} > /etc/timezone \
    && curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key \
    | gpg --dearmor -o /usr/share/keyrings/nodesource.gpg \
    && echo "deb [signed-by=/usr/share/keyrings/nodesource.gpg] https://deb.nodesource.com/node_${NODE_MAJOR}.x nodistro main" \
    > /etc/apt/sources.list.d/nodesource.list \
    && curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
    | gpg --dearmor -o /usr/share/keyrings/githubcli-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
    > /etc/apt/sources.list.d/github-cli.list \
    && apt-get update \
    && apt-get install -y --no-install-recommends nodejs gh \
    && rm -rf /tmp/* /var/tmp/*

# Create dev user
RUN groupadd --gid 1000 dev \
    && useradd --uid 1000 --gid 1000 --shell /bin/zsh --create-home dev \
    && echo "dev ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/dev \
    && chmod 0440 /etc/sudoers.d/dev

# Install Neovim (multi-arch)
RUN case "${TARGETARCH}" in \
    amd64) NvimArch="x86_64" ;; \
    arm64) NvimArch="arm64" ;; \
    *) echo "Unsupported arch: ${TARGETARCH}" && exit 1 ;; \
    esac \
    && curl -fsSL -o /tmp/nvim.tar.gz \
    "https://github.com/neovim/neovim/releases/download/${NVIM_VERSION}/nvim-linux-${NvimArch}.tar.gz" \
    && tar -xzf /tmp/nvim.tar.gz -C /opt \
    && mv /opt/nvim-linux-${NvimArch} /opt/nvim \
    && ln -sf /opt/nvim/bin/nvim /usr/local/bin/nvim \
    && rm /tmp/nvim.tar.gz

# zsh skeleton, directories, ownership, Coder rootless pod support
USER root
RUN mkdir -p /etc/zsh \
    && printf '%s\n' \
    'zstyle ":completion:*" menu select' \
    'autoload -Uz compinit && compinit' \
    > /etc/zsh/zshrc \
    && chown root:root /etc/zsh/zshrc \
    && chmod 644 /etc/zsh/zshrc \
    && mkdir -p \
    /home/dev/.config/opencode \
    /home/dev/.local/bin \
    /run/user/1000/gnupg \
    && touch /etc/gitconfig && chown dev:dev /etc/gitconfig \
    && chown dev:dev /usr/local/bin \
    && chown -R dev:dev /home/dev /run/user/1000 \
    && chsh -s /bin/zsh dev

# Install rtk (LLM token optimizer)
RUN case "${TARGETARCH}" in \
    amd64) RtkArch="x86_64-unknown-linux-musl" ;; \
    arm64) RtkArch="aarch64-unknown-linux-gnu" ;; \
    *) echo "Unsupported arch: ${TARGETARCH}" && exit 1 ;; \
    esac \
    && curl -fsSL -o /tmp/rtk.tar.gz \
    "https://github.com/rtk-ai/rtk/releases/download/${RTK_VERSION}/rtk-${RtkArch}.tar.gz" \
    && tar -xzf /tmp/rtk.tar.gz -C /usr/local/bin/ \
    && chmod +x /usr/local/bin/rtk \
    && rm /tmp/rtk.tar.gz

# Install delta (syntax-highlighting pager for git)
RUN case "${TARGETARCH}" in \
    amd64) DeltaArch="x86_64-unknown-linux-musl" ;; \
    arm64) DeltaArch="aarch64-unknown-linux-gnu" ;; \
    *) echo "Unsupported arch: ${TARGETARCH}" && exit 1 ;; \
    esac \
    && curl -fsSL -o /tmp/delta.tar.gz \
    "https://github.com/dandavison/delta/releases/download/${DELTA_VERSION}/delta-${DELTA_VERSION}-${DeltaArch}.tar.gz" \
    && tar -xzf /tmp/delta.tar.gz -C /tmp/ \
    && mv /tmp/delta-${DELTA_VERSION}-${DeltaArch}/delta /usr/local/bin/ \
    && chmod +x /usr/local/bin/delta \
    && rm -rf /tmp/delta*

# Install ripgrep (fast search tool)
RUN case "${TARGETARCH}" in \
    amd64) RgArch="x86_64"; RgLibc="unknown-linux-musl" ;; \
    arm64) RgArch="aarch64"; RgLibc="unknown-linux-gnu" ;; \
    *) echo "Unsupported arch: ${TARGETARCH}" && exit 1 ;; \
    esac \
    && curl -fsSL -o /tmp/ripgrep.tar.gz \
    "https://github.com/BurntSushi/ripgrep/releases/download/${RIPGREP_VERSION}/ripgrep-${RIPGREP_VERSION}-${RgArch}-${RgLibc}.tar.gz" \
    && tar -xzf /tmp/ripgrep.tar.gz -C /tmp/ \
    && mv /tmp/ripgrep-${RIPGREP_VERSION}-${RgArch}-${RgLibc}/rg /usr/local/bin/ \
    && chmod +x /usr/local/bin/rg \
    && rm -rf /tmp/ripgrep*

# Install bat (syntax-highlighting cat)
RUN case "${TARGETARCH}" in \
    amd64) BatArch="x86_64-unknown-linux-musl" ;; \
    arm64) BatArch="aarch64-unknown-linux-gnu" ;; \
    *) echo "Unsupported arch: ${TARGETARCH}" && exit 1 ;; \
    esac \
    && curl -fsSL -o /tmp/bat.tar.gz \
    "https://github.com/sharkdp/bat/releases/download/v${BAT_VERSION}/bat-v${BAT_VERSION}-${BatArch}.tar.gz" \
    && tar -xzf /tmp/bat.tar.gz -C /tmp/ \
    && mv /tmp/bat-v${BAT_VERSION}-${BatArch}/bat /usr/local/bin/ \
    && chmod +x /usr/local/bin/bat \
    && rm -rf /tmp/bat*

# Install zellij (terminal workspace)
RUN case "${TARGETARCH}" in \
    amd64) ZellijArch="x86_64-unknown-linux-musl" ;; \
    arm64) ZellijArch="aarch64-unknown-linux-gnu" ;; \
    *) echo "Unsupported arch: ${TARGETARCH}" && exit 1 ;; \
    esac \
    && curl -fsSL -o /tmp/zellij.tar.gz \
    "https://github.com/zellij-org/zellij/releases/download/v${ZELLIJ_VERSION}/zellij-${ZellijArch}.tar.gz" \
    && tar -xzf /tmp/zellij.tar.gz -C /usr/local/bin/ \
    && chmod +x /usr/local/bin/zellij \
    && rm /tmp/zellij.tar.gz

# Install fd (modern find)
RUN case "${TARGETARCH}" in \
    amd64) FdArch="x86_64-unknown-linux-musl" ;; \
    arm64) FdArch="aarch64-unknown-linux-gnu" ;; \
    *) echo "Unsupported arch: ${TARGETARCH}" && exit 1 ;; \
    esac \
    && curl -fsSL -o /tmp/fd.tar.gz \
    "https://github.com/sharkdp/fd/releases/download/v${FD_VERSION}/fd-v${FD_VERSION}-${FdArch}.tar.gz" \
    && tar -xzf /tmp/fd.tar.gz -C /tmp/ \
    && mv /tmp/fd-v${FD_VERSION}-${FdArch}/fd /usr/local/bin/ \
    && chmod +x /usr/local/bin/fd \
    && rm -rf /tmp/fd*

# Git safe directory
RUN git config --global --add safe.directory '*'

# Coder rootless pod support: replace su with passthrough wrapper
USER root
RUN mv /usr/bin/su /usr/bin/su.real && \
    ln -sf /usr/bin/su.real /usr/sbin/su.real 2>/dev/null || true
COPY shared/su-wrapper.sh /usr/bin/su
RUN chmod 755 /usr/bin/su
USER dev

# Coder rootless pod support: replace sudo with passthrough wrapper
USER root
RUN mv /usr/bin/sudo /usr/bin/sudo.real
COPY shared/sudo-wrapper.sh /usr/bin/sudo
RUN chmod 755 /usr/bin/sudo
USER dev

# Install OpenCode CLI (multi-arch)
RUN case "${TARGETARCH}" in \
    amd64) OpenCodeArch="x64" ;; \
    arm64) OpenCodeArch="arm64" ;; \
    *) echo "Unsupported arch: ${TARGETARCH}" && exit 1 ;; \
    esac \
    && curl -fsSL -o /tmp/opencode.tar.gz \
    "https://github.com/anomalyco/opencode/releases/download/v${OPENCODE_VERSION}/opencode-linux-${OpenCodeArch}.tar.gz" \
    && tar -xzf /tmp/opencode.tar.gz -C /usr/local/bin/ \
    && chmod +x /usr/local/bin/opencode \
    && rm /tmp/opencode.tar.gz \
    && opencode --version

WORKDIR /home/dev/workspace
