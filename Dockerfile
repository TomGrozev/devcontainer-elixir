# Build args
ARG ELIXIR_VERSION=1.19.4
ARG OTP_VERSION=28.5.0.1
ARG DEBIAN_VERSION=trixie-20260518-slim
ARG TZ=Australia/Sydney
ARG NODE_MAJOR=22
ARG NVIM_VERSION=v0.10.4
ARG ZSH_IN_DOCKER_VERSION=1.2.1
ARG INSTALL_TIDEWAVE=false
ARG RTK_VERSION=v0.42.1

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
ARG RTK_VERSION
ARG TARGETARCH

ENV DEBIAN_FRONTEND=noninteractive \
  TZ=${TZ} \
  DEVCONTAINER=true \
  EDITOR=nvim \
  VISUAL=nvim \
  NPM_CONFIG_PREFIX=/home/dev/.local \
  PATH="/home/dev/.local/bin:/home/dev/.opencode/bin:${PATH}"

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
  openssh-client \
  libc-dev \
  inotify-tools \
  gpg \
  gpg-agent \
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

# zsh-in-docker with plugins
USER dev
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

# Persistent history, zshrc, directories, ownership, DevPod support
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
  && chmod 644 /etc/zsh/zshrc \
  && mkdir -p /workspace \
  /home/dev/.config/opencode \
  /home/dev/.mix \
  /home/dev/.hex \
  /home/dev/.local/bin \
  /var/run/devpod \
  /var/devpod \
  /run/user/1000/gnupg \
  && touch /etc/gitconfig && chown dev:dev /etc/gitconfig \
  && echo '{}' > /etc/envfile.json && chown dev:dev /etc/envfile.json /usr/local/bin \
  && chown -R dev:dev /workspace /home/dev /commandhistory /var/run/devpod /var/devpod /run/user/1000 \
  && chsh -s /bin/zsh dev \
  && sed -i 's/^auth\s\+sufficient\s\+pam_rootok.so/auth\t sufficient\t pam_rootok.so\nauth\t sufficient\t pam_succeed_if.so user = dev/' /etc/pam.d/su

# Optional Tidewave CLI
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

# Mix setup
USER dev
RUN mix local.hex --force && mix local.rebar --force

# Git safe directory
RUN git config --global --add safe.directory '*'

# DevPod rootless support: replace su with passthrough wrapper
# When running as non-root (UID 1000/dev), all su calls to switch
# to the dev user are no-ops. The wrapper just executes the command
# directly, avoiding CAP_SETUID/CAP_SETGID requirements.
USER root
RUN mv /usr/bin/su /usr/bin/su.real && \
  ln -sf /usr/bin/su.real /usr/sbin/su.real 2>/dev/null || true
COPY su-wrapper.sh /usr/bin/su
RUN chmod 755 /usr/bin/su
USER dev

# DevPod rootless support: replace sudo with passthrough wrapper
# When running as non-root (UID 1000/dev), privilege escalation is
# unnecessary and blocked by pod security contexts. This wrapper
# strips sudo and executes commands directly as the current user.
USER root
RUN mv /usr/bin/sudo /usr/bin/sudo.real
COPY sudo-wrapper.sh /usr/bin/sudo
RUN chmod 755 /usr/bin/sudo
USER dev

WORKDIR /workspace

# Install opencode (last for best cache efficiency)
RUN curl -fsSL https://opencode.ai/install | bash

# Install opencode server startup script. The script is placed at the root
# of the filesystem and made world-executable so the dev user can run it
# directly (e.g. `start-opencode.sh` or `bash /start-opencode.sh`).
USER root
COPY start-opencode.sh /start-opencode.sh
RUN chmod +x /start-opencode.sh
USER dev
