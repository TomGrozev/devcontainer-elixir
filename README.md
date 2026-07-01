# Elixir Coder Workspace Image

Prebuilt multi-arch Docker image for Elixir development in Coder workspaces, published to `ghcr.io/tomgrozev/devcontainer-elixir`. The image bakes system-level tooling; user-level tooling (opencode, zsh plugins, asdf, mix/hex cache) is deferred to the Coder `coder-labs/opencode` module, the user's dotfiles repo, and the persistent `/home/dev` PVC. The Coder Terraform template lives in `./coder-template/`.

![CI](https://github.com/tomgrozev/devcontainer-elixir/actions/workflows/build.yml/badge.svg)

## What's Baked

- Elixir + Erlang/OTP (hexpm base, configurable versions)
- Node.js 22 + GitHub CLI
- Neovim (pinned v0.12.2, multi-arch, `/opt/nvim`)
- rtk, delta, AgentAPI (system binaries on PATH)
- apt packages: build-essential, inotify-tools, fzf, git, jq, gpg, openssh-client, locales, curl, ca-certificates
- Rootless `su`/`sudo` passthrough wrappers (graceful degradation for the rootless pod securityContext)
- User `dev` UID/GID 1000, shell `/bin/zsh`, sudoers entry, `/etc/zsh/zshrc` skeleton
- Locale `en_AU.UTF-8`, timezone `Australia/Sydney` (configurable via `TZ`)

## What's Deferred

- **opencode** — installed at first workspace start by the `coder-labs/opencode` module into `/home/dev/.opencode/bin` (persists on PVC)
- **zsh + oh-my-zsh + powerlevel10k + fzf integration** — applied via the user's dotfiles repo (`github.com/TomGrozev/dots`)
- **asdf** — managed by dotfiles
- **mix/hex/rebar bootstrap** — run once at first workspace start by the Coder template's `startup_script` (persists on PVC at `/home/dev/.mix`/`/home/dev/.hex`)

## Build Args

| Arg | Default | Description |
| --- | --- | --- |
| `ELIXIR_VERSION` | `1.19.4` | Elixir version |
| `OTP_VERSION` | `28.5.0.1` | Erlang/OTP version |
| `DEBIAN_VERSION` | `trixie-20260518-slim` | Debian base image tag |
| `TZ` | `Australia/Sydney` | System timezone |
| `NODE_MAJOR` | `22` | Node.js major version |
| `NVIM_VERSION` | `v0.12.2` | Neovim release tag |
| `RTK_VERSION` | `v0.42.1` | rtk release tag |
| `DELTA_VERSION` | `0.18.2` | delta release version |
| `AGENTAPI_VERSION` | `v0.11.2` | AgentAPI release tag (used by the Coder opencode module) |

## Usage

The Coder Terraform template in `./coder-template/` deploys this image as a rootless Kubernetes pod with a persistent home PVC, dotfiles, and opencode. See `coder-template/README.md` for setup instructions including the OpenCode user-secret one-liner.

To rebuild the image manually: trigger **Actions > Build and Push > Run workflow** in GitHub. Override `ELIXIR_VERSION`, `OTP_VERSION`, `NVIM_VERSION`, or `image_tag` (custom tag suffix). The workflow builds `linux/amd64` + `linux/arm64` and pushes to GHCR.

## Notes

- The `dev` user has UID/GID 1000.
- The image runs rootless: pod securityContext drops all capabilities and forbids privilege escalation. The `su`/`sudo` wrappers passthrough commands as the current user.
- Persistent state lives under `/home/dev` (mounted on a PVC in Coder); rebuilds of the image do not affect workspace state.
- This image was previously DevPod-oriented; the DevPod `devcontainer.json` entrypoint has been removed and the project is now Coder-only.
