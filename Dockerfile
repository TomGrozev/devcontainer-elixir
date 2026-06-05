# Build args
ARG ELIXIR_VERSION=1.19.4
ARG OTP_VERSION=28.5.0.1
ARG DEBIAN_VERSION=trixie-20260518-slim
ARG TZ=Australia/Sydney
ARG NODE_MAJOR=22
ARG NVIM_VERSION=v0.10.4
ARG ZSH_IN_DOCKER_VERSION=1.2.1
ARG INSTALL_TIDEWAVE=false

FROM hexpm/elixir:${ELIXIR_VERSION}-erlang-${OTP_VERSION}-debian-${DEBIAN_VERSION}

# Re-declare args for use in this stage
ARG ELIXIR_VERSION
ARG OTP_VERSION
ARG DEBIAN_VERSION
ARG TZ
ARG NODE_MAJOR
ARG NVIM_VERSION
ARG ZSH_IN_DOCKER_VERSION
ARG INSTALL_TIDEWAVE
ARG TARGETARCH

ENV DEBIAN_FRONTEND=noninteractive \
  TZ=${TZ} \
  DEVCONTAINER=true \
  EDITOR=nvim \
  VISUAL=nvim \
  NPM_CONFIG_PREFIX=/home/dev/.local \
  PATH="/home/dev/.local/bin:/home/dev/.opencode/bin:${PATH}"

# System packages, locale, timezone, node
RUN apt-get update && apt-get install -y --no-install-recommends \
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
  vim-tiny \
  locales \
  gcc \
  make \
  libc-dev \
  inotify-tools \
  && sed -i 's/^# *en_AU.UTF-8/en_AU.UTF-8/' /etc/locale.gen \
  && locale-gen en_AU.UTF-8 \
  && ln -snf /usr/share/zoneinfo/${TZ} /etc/localtime \
  && echo ${TZ} > /etc/timezone \
  && curl -fsSL https://deb.nodesource.com/setup_${NODE_MAJOR}.x | bash - \
  && apt-get install -y --no-install-recommends nodejs \
  && ln -sf /usr/bin/vim.tiny /usr/bin/vim \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

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

# Install opencode as dev user
USER dev
RUN curl -fsSL https://opencode.ai/install | bash

# zsh-in-docker with plugins and history
RUN curl -fsSL \
  "https://github.com/deluan/zsh-in-docker/releases/download/v${ZSH_IN_DOCKER_VERSION}/zsh-in-docker.sh" \
  -o /tmp/zsh-in-docker.sh \
  && chmod +x /tmp/zsh-in-docker.sh \
  && /tmp/zsh-in-docker.sh \
  -p git \
  -p fzf \
  -p mix \
  -p zsh-autosuggestions \
  && rm /tmp/zsh-in-docker.sh

# Persistent history setup
USER root
RUN mkdir -p /commandhistory && touch /commandhistory/.zsh_history \
  && mkdir -p /etc/zsh \
  && printf '%s\n' \
  'export PROMPT_COMMAND="history -a"' \
  'export HISTFILE=/commandhistory/.zsh_history' \
  'zstyle ":completion:*" menu select' \
  'autoload -Uz compinit && compinit' \
  > /etc/zsh/zshrc \
  && chown root:root /etc/zsh/zshrc \
  && chmod 644 /etc/zsh/zshrc
USER dev

# Mix setup
RUN mix local.hex --force && mix local.rebar --force

# Git safe directory
RUN git config --global --add safe.directory '*'

# Optional Tidewave CLI
USER root
RUN if [ "${INSTALL_TIDEWAVE}" = "true" ]; then \
  case "${TARGETARCH}" in \
  amd64) TIDE_ARCH="x86_64" ;; \
  arm64) TIDE_ARCH="aarch64" ;; \
  *) TIDE_ARCH="${TARGETARCH}" ;; \
  esac \
  && curl -fsSL -o /usr/local/bin/tidewave \
  "https://github.com/tidewave-ai/tidewave-cli/releases/latest/download/tidewave-linux-${TIDE_ARCH}" \
  && chmod +x /usr/local/bin/tidewave; \
  fi

# DevPod support: create runtime dirs and marker for non-root usage
RUN mkdir -p /var/run/devpod /var/devpod

# Create workspace and dirs owned by dev
RUN mkdir -p /workspace \
  /home/dev/.config/opencode \
  /home/dev/.mix \
  /home/dev/.hex \
  /home/dev/.local/bin \
  && chown -R dev:dev /workspace /home/dev /commandhistory /var/run/devpod /var/devpod

# DevPod git credential support: allow dev user to write system gitconfig
RUN touch /etc/gitconfig && chown dev:dev /etc/gitconfig

# DevPod support: allow agent to write system paths
RUN touch /etc/envfile.json \
    && chown dev:dev /etc/envfile.json /usr/local/bin \
    && sed -i 's/^auth\s\+sufficient\s\+pam_rootok.so/auth\t sufficient\t pam_rootok.so\nauth\t sufficient\t pam_succeed_if.so user = dev/' /etc/pam.d/su

WORKDIR /workspace

RUN chsh -s /bin/zsh dev
USER dev
