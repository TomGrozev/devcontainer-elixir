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
- A pre-provisioned namespace (default: `dev`)
- (Optional) A `~/.kube/config` if the Coder host runs outside the cluster

## Quick start

1. Create a new template in your Coder deployment, pointing at this directory.
2. Optionally override parameters (image, cpu, memory, volume size, storage class).
3. Create a new workspace from the template.

## What this template uses

| Module / Resource                            | Purpose                                                                          |
| -------------------------------------------- | -------------------------------------------------------------------------------- |
| `coder_agent.main`                           | Registers the Coder agent in the workspace                                       |
| `kubernetes_persistent_volume_claim_v1.home` | Persistent `/home/dev` across workspace restarts                                 |
| `kubernetes_deployment_v1.main`              | Runs the container as rootless (UID 1000)                                        |
| `module.dotfiles`                            | Clones your dotfiles on first start (<git@github.com>:TomGrozev/dots.git)        |
| `coder_app.opencode`                         | Proxies the in-image OpenCode API server via subdomain (`http://localhost:4096`) |

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

## OpenCode setup

### Authentication (user secrets)

For authenticated OpenCode usage, create a Coder user secret before starting the workspace:

```bash
cat auth.json | coder secret create opencode-auth --file ~/.local/share/opencode/auth.json
```

The agent writes the secret before the startup script runs. The module skips its own auth.json write when `auth_json = ""` (the default in this template).

## How it works

1. Coder applies this Terraform against your Kubernetes cluster.
2. A `PersistentVolumeClaim` is created in the configured namespace.
3. A `Deployment` is created that runs the prebuilt image as a rootless container (UID 1000).
4. The main container runs `coder_agent.main.init_script` which bootstraps the agent and connects to the Coder server.
5. The agent's `startup_script` runs first-time init on the empty PVC: creates directories, bootstraps mix/hex, optionally clones a repo, then launches `opencode serve --port 4096 --hostname 0.0.0.0` in the background.
6. The `coder_app.opencode` resource registers a dashboard button that proxies to `http://localhost:4096` via a subdomain.

## Customization

### Using a different image

Override the `image` parameter in the Coder UI. The image must:

- Be runnable as a non-root user (UID 1000, GID 1000)
- Have a writable home directory at `/home/dev`
- Have `curl` and `sh` for the coder agent installer
- Have `mix` and `hex` for the Elixir bootstrap

### Adding a repo to clone on startup

Set the `repo` parameter in the Coder UI (e.g. `git@github.com:you/repo.git`). The startup script clones it into `/home/dev/workspace`.

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

The PVC might be owned by a different UID from a previous session. The deployment sets `fs_group=1000` with `fs_group_change_policy=OnRootMismatch`, which should reclaim ownership. If it doesn't, run a one-off pod with `chown`, or delete the PVC and recreate the workspace.

### Mix/hex not found

The startup script runs `mix local.hex --force` on first start. If mix is not in the image, the bootstrap will fail. Ensure your image includes Elixir/Erlang.
