# Elixir Devcontainer Image

Prebuilt Docker image for Elixir development in devcontainers, published to `ghcr.io/tomgrozev/devcontainer-elixir`.

![CI](https://github.com/tomgrozev/devcontainer-elixir/actions/workflows/build.yml/badge.svg)

## Features

- **Elixir** (configurable version)
- **Erlang/OTP** (configurable version)
- **Node.js** (via NodeSource, configurable major version)
- **Neovim** (pinned, multi-arch: x86_64 & arm64)
- **opencode** pre-installed as the dev user
- **zsh** with oh-my-zsh, fzf, and autosuggestions
- **Tidewave CLI** (optional, configurable)
- Persistent command history volume support
- Locale and timezone configured for AU by default

## Usage

Reference the image in your project's `devcontainer.json`:

```json
{
  "name": "Elixir Devcontainer",
  "image": "ghcr.io/tomgrozev/devcontainer-elixir:latest",
  "remoteUser": "dev",
  "remoteEnv": {
    "MIX_BUILD_PATH": "/workspace/_build/devcontainer",
    "MIX_DEPS_PATH": "/workspace/deps/devcontainer"
  },
  "containerEnv": {
    "DEVCONTAINER": "true",
    "EDITOR": "nvim",
    "VISUAL": "nvim",
    "POWERLEVEL9K_DISABLE_GITSTATUS": "false"
  },
  "forwardPorts": [4000],
  "workspaceMount": "source=${localWorkspaceFolder},target=/workspace,type=bind,consistency=delegated",
  "workspaceFolder": "/workspace",
  "mounts": [
    "source=elixir-command-history,target=/commandhistory,type=volume"
  ],
  "postCreateCommand": "git config --global --add safe.directory '*' && mix deps.get"
}
```

Or copy the provided `devcontainer.json` example from this repo into your project.

## Build Args

| Arg                     | Default                | Description           |
| ----------------------- | ---------------------- | --------------------- |
| `ELIXIR_VERSION`        | `1.19.4`               | Elixir version        |
| `OTP_VERSION`           | `28.5.0.1`             | Erlang/OTP version    |
| `DEBIAN_VERSION`        | `trixie-20260518-slim` | Debian base image tag |
| `TZ`                    | `Australia/Sydney`     | System timezone       |
| `NODE_MAJOR`            | `22`                   | Node.js major version |
| `NVIM_VERSION`          | `v0.12.2`              | Neovim release tag    |
| `ZSH_IN_DOCKER_VERSION` | `1.2.1`                | zsh-in-docker version |
| `INSTALL_TIDEWAVE`      | `false`                | Install Tidewave CLI  |

## Manual Rebuild

Trigger a manual build via **Actions > Build and Push > Run workflow** in GitHub. You can override:

- `ELIXIR_VERSION`
- `OTP_VERSION`
- `NVIM_VERSION`
- `image_tag` (custom tag suffix)

The workflow will build multi-arch images (`linux/amd64`, `linux/arm64`) and push to GHCR.

## Notes

- **opencode** is pre-installed in the image under `/home/dev/.opencode/bin`. No devcontainer feature is required.
- **Protected paths / opencode deny rules are NOT included** in this image. Handle those via your own dotfiles or post-create commands.
- The `dev` user has UID/GID 1000 and uses `zsh` by default.
- Command history is persisted via the `/commandhistory` volume mount.
