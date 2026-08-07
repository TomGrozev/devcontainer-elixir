#!/bin/sh
# Rust devcontainer bootstrap — currently a no-op.
# Mutable cargo state (registry, installed binaries) lives on the PVC at
# /home/dev/.cargo. The toolchain itself is baked at /usr/local/rustup.
set -e
# No-op for now. Add first-run setup here if needed (e.g. cargo install ...).
