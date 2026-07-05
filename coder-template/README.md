# Coder Template: Elixir Workspace (Kubernetes)

A [Coder](https://coder.com) template that deploys the [Elixir workspace image](../README.md) (`ghcr.io/tomgrozev/devcontainer-elixir`) on Kubernetes.

This template runs a prebuilt image directly (no build step), giving you:

- **Faster workspace startup** — no build step
- **Smaller surface area** — fewer moving parts to debug
- **Predictable behavior** — what you test locally is what runs in Coder

The image is a full Elixir dev environment: Elixir, Erlang/OTP, Node.js, Neovim, `zsh` + `oh-my-zsh`, `fzf`, `delta`, `rtk`, and the `opencode` CLI/server. See the [image README](../README.md) for details.

## Prerequisites

- A running [Coder](https://coder.com) deployment (v2.x or later)
- A Kubernetes cluster reachable from the Coder host
- (Optional) A `~/.kube/config` if the Coder host runs outside the cluster

## Quick start

1. Create a new template in your Coder deployment, pointing at this directory.
2. Optionally override variables (namespace) and parameters (image, repo, cpu, memory, volume size, storage class, dotfiles URI).
3. Create a new workspace from the template.

## Variables

Variables are set at template build time (not at workspace creation). They configure the Terraform providers and the target infrastructure.

| Variable         | Type   | Default | Description                                                                                                                    |
| ---------------- | ------ | ------- | ------------------------------------------------------------------------------------------------------------------------------ |
| `use_kubeconfig` | bool   | `false` | Controls the `kubernetes` provider `config_path`. Set `true` if the Coder host runs outside the cluster and `~/.kube/config` is present. When `false` the provider uses in-cluster auth. |
| `namespace`      | string | `dev`   | Kubernetes namespace where the PVC and Deployment are created.                                                                 |

## Parameters

Parameters are configurable from the Coder UI at workspace creation or (for mutable ones) via workspace updates.

| Parameter            | Default                                        | Mutable | Description                                                                      |
| -------------------- | ---------------------------------------------- | ------- | -------------------------------------------------------------------------------- |
| `image`              | `ghcr.io/tomgrozev/devcontainer-elixir:latest` | yes     | Container image to deploy                                                        |
| `repo`               | `""`                                           | yes     | Git repo URL to clone into `/home/dev/workspace` (leave empty for no auto-clone) |
| `cpu`                | `1`                                            | yes     | CPU limit (cores)                                                                |
| `memory`             | `2`                                            | yes     | Memory limit (GiB)                                                               |
| `home_volume_size`   | `20`                                           | no      | `/home/dev` volume size (GiB)                                                    |
| `storage_class_name` | `""`                                           | no      | Kubernetes StorageClass (empty = cluster default)                                |
| `dotfiles_uri`       | `https://github.com/TomGrozev/dots`            | yes     | Git repo URL containing dotfiles, applied by the startup script and the Refresh Dotfiles button |

## What this template uses

| Resource                                  | Purpose                                                                                                                                                                                                      |
| ----------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `coder_agent.main`                        | Registers the Coder agent in the workspace. Sets `GIT_AUTHOR_NAME`, `GIT_AUTHOR_EMAIL`, `GIT_COMMITTER_NAME`, `GIT_COMMITTER_EMAIL` env vars from the workspace owner (falling back to `TomGrozev` / `dev@coder.com`). Works in `/home/dev/workspace`. |
| `coder_agent.main.startup_script`         | Inlines first-time setup: creates `/home/dev/{workspace,.local/bin,.local/share,.config,.ssh}`, bootstraps mix/hex/rebar, optionally clones a repo, applies dotfiles via `coder dotfiles`, then launches `opencode serve`. |
| `kubernetes_persistent_volume_claim_v1.home` | Persistent `/home/dev` across workspace restarts. Labelled with Coder workspace, user, and resource metadata.                                                                                             |
| `kubernetes_deployment_v1.main`           | Runs the container rootless (UID/GID 1000, all capabilities dropped, seccomp `RuntimeDefault`), uses `Recreate` strategy, applies pod anti-affinity (preferred, hostname topology) against other `coder-workspace` pods, and requests 10m CPU / 512Mi memory as floor with `cpu`/`memory` parameters as the limits. |
| `coder_app.opencode`                      | Proxies the in-image OpenCode API server via subdomain (`http://localhost:4096`). Includes a healthcheck at `/global/health` (5s interval, 6 attempts).                                                       |
| `coder_app.refresh_dotfiles`              | A workspace-app button that re-runs `coder dotfiles` against the current `dotfiles_uri` value to pull the latest dotfiles and re-apply.                                                                      |

## Agent environment variables

The agent sets the following environment variables in the container, derived from the Coder workspace owner:

| Variable              | Source                                                        |
| --------------------- | ------------------------------------------------------------- |
| `GIT_AUTHOR_NAME`     | `workspace_owner.full_name` → `workspace_owner.name` → `TomGrozev` |
| `GIT_AUTHOR_EMAIL`    | `workspace_owner.email` → `dev@coder.com`                     |
| `GIT_COMMITTER_NAME`  | Same as `GIT_AUTHOR_NAME`                                      |
| `GIT_COMMITTER_EMAIL` | Same as `GIT_AUTHOR_EMAIL`                                     |

The agent's working directory is `/home/dev/workspace`.

## OpenCode setup

### Authentication

This template does **not** include any authentication handling in `main.tf`. The OpenCode server starts unauthenticated by default.

If you need authenticated OpenCode usage, extend the template yourself. One approach is to use a Coder user secret plus a write step in the startup script:

```bash
# Create the secret before starting the workspace
cat auth.json | coder secret create opencode-auth --file ~/.local/share/opencode/auth.json
```

You would then add logic to the agent `startup_script` to write the secret file before `opencode serve` starts. This is an extension point — the template ships without any auth wiring so you can tailor it to your environment.

## How it works

1. Coder applies this Terraform against your Kubernetes cluster.
2. A `PersistentVolumeClaim` is created in the configured namespace.
3. A `Deployment` is created that runs the prebuilt image as a rootless container (UID 1000, all capabilities dropped, seccomp `RuntimeDefault`).
4. The main container runs `coder_agent.main.init_script` which bootstraps the agent and connects to the Coder server.
5. The agent's `startup_script` runs first-time init:
   - Creates `/home/dev/{workspace,.local/bin,.local/share,.config,.ssh}`.
   - Bootstraps `mix local.hex` and `mix local.rebar` only if `/home/dev/.mix/archives` is missing (idempotent across restarts, cached on the PVC).
   - Clones the `repo` parameter into `/home/dev/workspace` if set and not already a git repo.
   - Applies dotfiles via `coder dotfiles <dotfiles_uri> -y` only if `/home/dev/.coder/dotfiles` is not already a git checkout. Output is tee'd to `/home/dev/.dotfiles.log`. Dotfiles are inlined in the agent script (rather than using the `coder/dotfiles` module) so anything dotfiles write to `~/.zshenv` is guaranteed to be in place before `opencode serve` starts.
   - Launches `opencode serve --port 4096 --hostname 0.0.0.0` in the background (via `zsh -c` if `zsh` is on PATH, else directly) with logs written to `/tmp/opencode.log`.
6. The `coder_app.opencode` resource registers a dashboard button that proxies to `http://localhost:4096` via a subdomain, with a healthcheck at `/global/health`.

## Customization

### Using a different image

Override the `image` parameter in the Coder UI. The image must:

- Be runnable as a non-root user (UID 1000, GID 1000)
- Have a writable home directory at `/home/dev`
- Have `curl` and `sh` for the coder agent installer
- Have `mix` and `hex` for the Elixir bootstrap

### Adding a repo to clone on startup

Set the `repo` parameter in the Coder UI (e.g. `git@github.com:you/repo.git`). The startup script clones it into `/home/dev/workspace`.

### Changing your dotfiles

The `dotfiles_uri` parameter controls which dotfiles repo is applied (mutable, so you can swap it per-workspace). The startup script applies dotfiles once on first boot; to refresh dotfiles after that, use the **Refresh Dotfiles** button in the workspace dashboard (the `coder_app.refresh_dotfiles` resource), which re-runs `coder dotfiles` against the current `dotfiles_uri` value.

### Using a private image registry

Add an `image_pull_secrets` block to the container spec and create the corresponding Kubernetes secret in the workspace namespace:

```hcl
image_pull_secrets {
  name = "regcred"
}
```

## Troubleshooting

### The agent keeps restarting

Check the workspace logs. The most common cause is the agent failing to download or install. Ensure the container has internet access.

### Permission errors on `/home/dev`

The PVC might be owned by a different UID from a previous session. The deployment sets `fs_group=1000` with `fs_group_change_policy=Always`, which should reclaim ownership. If it doesn't, run a one-off pod with `chown`, or delete the PVC and recreate the workspace.

### Mix/hex not found

The startup script runs `mix local.hex --force` on first start. If mix is not in the image, the bootstrap will fail. Ensure your image includes Elixir/Erlang.
