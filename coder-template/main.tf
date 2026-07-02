terraform {
  required_providers {
    coder = {
      source  = "coder/coder"
      version = "~> 2.0"
    }
    kubernetes = {
      source = "hashicorp/kubernetes"
    }
  }
}

provider "coder" {}
provider "kubernetes" {
  config_path = var.use_kubeconfig ? "~/.kube/config" : null
}

data "coder_provisioner" "me" {}
data "coder_workspace" "me" {}
data "coder_workspace_owner" "me" {}

variable "use_kubeconfig" {
  type        = bool
  description = "Use ~/.kube/config (set true if Coder host runs outside the cluster)."
  default     = false
}

variable "namespace" {
  type        = string
  default     = "dev"
  description = "Kubernetes namespace for workspace resources."
}

# ─── Parameters ──────────────────────────────────────────────────────────────

data "coder_parameter" "image" {
  name         = "image"
  display_name = "Container Image"
  type         = "string"
  default      = "ghcr.io/tomgrozev/devcontainer-elixir:latest"
  description  = "Container image to deploy."
  mutable      = true
  order        = 1
}

data "coder_parameter" "repo" {
  name         = "repo"
  display_name = "Repository"
  type         = "string"
  default      = ""
  description  = "Git repo URL to clone (e.g. git@github.com:you/repo.git). Leave empty for no auto-clone."
  mutable      = true
  order        = 2
}

data "coder_parameter" "cpu" {
  name         = "cpu"
  display_name = "CPU"
  type         = "number"
  default      = "1"
  description  = "CPU limit (cores)."
  mutable      = true
  order        = 3
}

data "coder_parameter" "memory" {
  name         = "memory"
  display_name = "Memory"
  type         = "number"
  default      = "2"
  description  = "Memory limit (GiB)."
  mutable      = true
  order        = 4
}

data "coder_parameter" "home_volume_size" {
  name         = "home_volume_size"
  display_name = "Home Volume Size"
  type         = "number"
  default      = "20"
  description  = "Size of the /home/dev persistent volume (GiB)."
  mutable      = false
  order        = 5
}

data "coder_parameter" "storage_class_name" {
  name         = "storage_class_name"
  display_name = "Storage Class"
  type         = "string"
  default      = ""
  description  = "Kubernetes StorageClass (empty = cluster default)."
  mutable      = false
  order        = 6
}

# ─── Locals ──────────────────────────────────────────────────────────────────

locals {
  workspace_name = "coder-${lower(data.coder_workspace.me.id)}"
  git_name       = coalesce(data.coder_workspace_owner.me.full_name, data.coder_workspace_owner.me.name, "TomGrozev")
  git_email      = coalesce(data.coder_workspace_owner.me.email, "dev@coder.com")
}

# ─── Agent ───────────────────────────────────────────────────────────────────

resource "coder_agent" "main" {
  arch = data.coder_provisioner.me.arch
  os   = "linux"
  dir  = "/home/dev/workspace"

  env = {
    GIT_AUTHOR_NAME     = local.git_name
    GIT_AUTHOR_EMAIL    = local.git_email
    GIT_COMMITTER_NAME  = local.git_name
    GIT_COMMITTER_EMAIL = local.git_email
  }

  startup_script = <<-EOT
    #!/bin/sh
    set -e

    # Ensure common dirs exist on the freshly-mounted PVC
    mkdir -p /home/dev/workspace /home/dev/.local/bin /home/dev/.local/share /home/dev/.config

    # First-time mix/hex bootstrap (persists on PVC across restarts)
    if [ ! -d /home/dev/.mix/archives ]; then
      mix local.hex --force && mix local.rebar --force
    fi

    # Clone the repo parameter if set and not already present
    REPO="${data.coder_parameter.repo.value}"
    if [ -n "$REPO" ]; then
      REPO_NAME=$(basename "$REPO" .git)
      if [ ! -d "/home/dev/workspace/$REPO_NAME" ]; then
        git clone "$REPO" "/home/dev/workspace/$REPO_NAME" || true
      fi
    fi

    # Start the OpenCode API server for Coder app proxying
    nohup opencode serve --port 4096 --hostname 0.0.0.0 > /tmp/opencode.log 2>&1 &
  EOT
}

# ─── Persistent Volume Claim ─────────────────────────────────────────────────

resource "kubernetes_persistent_volume_claim_v1" "home" {
  metadata {
    name      = "${local.workspace_name}-home"
    namespace = var.namespace
    labels = {
      "app.kubernetes.io/name"     = "${local.workspace_name}-home"
      "app.kubernetes.io/instance" = "${local.workspace_name}-home"
      "app.kubernetes.io/part-of"  = "coder"
      "com.coder.resource"         = "true"
      "com.coder.workspace.id"     = data.coder_workspace.me.id
      "com.coder.workspace.name"   = data.coder_workspace.me.name
      "com.coder.user.id"          = data.coder_workspace_owner.me.id
      "com.coder.user.username"    = data.coder_workspace_owner.me.name
    }
    annotations = {
      "com.coder.user.email" = data.coder_workspace_owner.me.email
    }
  }
  wait_until_bound = false
  spec {
    access_modes = ["ReadWriteOnce"]
    resources {
      requests = {
        storage = "${data.coder_parameter.home_volume_size.value}Gi"
      }
    }
    storage_class_name = data.coder_parameter.storage_class_name.value != "" ? data.coder_parameter.storage_class_name.value : null
  }
}

# ─── Deployment ──────────────────────────────────────────────────────────────

resource "kubernetes_deployment_v1" "main" {
  count = data.coder_workspace.me.start_count

  depends_on = [
    kubernetes_persistent_volume_claim_v1.home
  ]

  wait_for_rollout = false

  metadata {
    name      = local.workspace_name
    namespace = var.namespace
    labels = {
      "app.kubernetes.io/name"     = "coder-workspace"
      "app.kubernetes.io/instance" = local.workspace_name
      "app.kubernetes.io/part-of"  = "coder"
      "com.coder.resource"         = "true"
      "com.coder.workspace.id"     = data.coder_workspace.me.id
      "com.coder.workspace.name"   = data.coder_workspace.me.name
      "com.coder.user.id"          = data.coder_workspace_owner.me.id
      "com.coder.user.username"    = data.coder_workspace_owner.me.name
    }
    annotations = {
      "com.coder.user.email" = data.coder_workspace_owner.me.email
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        "app.kubernetes.io/name" = "coder-workspace"
      }
    }

    strategy {
      type = "Recreate"
    }

    template {
      metadata {
        labels = {
          "app.kubernetes.io/name"   = "coder-workspace"
          "com.coder.resource"       = "true"
          "com.coder.workspace.pod"  = "true"
          "com.coder.workspace.name" = data.coder_workspace.me.name
        }
      }

      spec {
        # Pod-level security context (rootless)
        security_context {
          run_as_user            = 1000
          run_as_group           = 1000
          run_as_non_root        = true
          fs_group               = 1000
          fs_group_change_policy = "Always"
          seccomp_profile {
            type = "RuntimeDefault"
          }
        }

        # Main workspace container
        # The init_script (from coder_agent.main) bootstraps the agent:
        # it downloads the coder CLI and runs "coder agent" which connects
        # to the Coder server. Source: Terraform provider agent docs example.
        container {
          name              = "dev"
          image             = data.coder_parameter.image.value
          image_pull_policy = "Always"

          command = ["sh", "-c", coder_agent.main.init_script]

          security_context {
            run_as_user                = 1000
            run_as_group               = 1000
            run_as_non_root            = true
            allow_privilege_escalation = false
            capabilities {
              drop = ["ALL"]
            }
          }

          env {
            name  = "CODER_AGENT_TOKEN"
            value = coder_agent.main.token
          }

          resources {
            requests = {
              cpu    = "10m"
              memory = "512Mi"
            }
            limits = {
              cpu    = data.coder_parameter.cpu.value
              memory = "${data.coder_parameter.memory.value}Gi"
            }
          }

          volume_mount {
            name       = "home"
            mount_path = "/home/dev"
            sub_path   = ""
          }
        }

        volume {
          name = "home"
          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim_v1.home.metadata[0].name
            read_only  = false
          }
        }

        affinity {
          pod_anti_affinity {
            preferred_during_scheduling_ignored_during_execution {
              weight = 1
              pod_affinity_term {
                topology_key = "kubernetes.io/hostname"
                label_selector {
                  match_expressions {
                    key      = "app.kubernetes.io/name"
                    operator = "In"
                    values   = ["coder-workspace"]
                  }
                }
              }
            }
          }
        }
      }
    }
  }
}

# ─── Modules ─────────────────────────────────────────────────────────────────

module "dotfiles" {
  count                   = data.coder_workspace.me.start_count
  source                  = "registry.coder.com/coder/dotfiles/coder"
  version                 = "1.4.2"
  agent_id                = coder_agent.main.id
  default_dotfiles_uri    = "https://github.com/TomGrozev/dots"
  default_dotfiles_branch = "master"
  manual_update           = true
}

resource "coder_app" "opencode" {
  agent_id     = coder_agent.main.id
  slug         = "opencode"
  display_name = "OpenCode"
  url          = "http://localhost:4096"
  subdomain    = true
  share        = "owner"
  open_in      = "slim-window"

  healthcheck {
    url       = "http://localhost:4096/global/health"
    interval  = 5
    threshold = 6
  }
}
