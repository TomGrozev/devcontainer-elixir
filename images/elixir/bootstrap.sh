#!/bin/sh
# Elixir devcontainer bootstrap — first-time mix/hex init, idempotent
set -e

if [ ! -d /home/dev/.mix/archives ]; then
    mix local.hex --force && mix local.rebar --force
fi
