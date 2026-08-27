#!/bin/sh
# omp-web-omp-bin: OMP_WEB_OMP_BIN target, resolved by ompweb for EVERY omp
# binary invocation it makes -- not just chat sessions. ompweb's resolveOmpBin()
# is a single shared helper backing two structurally different call shapes:
#
#   1. Interactive chat sessions (RPC mode), spawned with pipe stdio:
#        spawn(bin, ["--mode", "rpc-ui", "--cwd", <dir>, ...extraArgs])
#   2. One-shot CLI calls, shelled out to directly for UI features:
#        execFile(bin, ["--version"])
#        execFile(bin, ["update", "--check"])
#        execFile(bin, ["plugin", "list", "--json", ...])
#        execFile(bin, ["agents", "unpack", "--dir", ..., "--json"])
#        execFile(bin, ["--export", <in>, <out>])
#
# Only (1) should go through captain-miao's agent launcher (`miao launch
# omp`) so the chat session gets hooks and shows up in the dashboard instead
# of running as an invisible child process. (2) MUST reach the real omp
# binary untouched: captain-miao's `split_cwd` treats a first positional that
# doesn't start with `-` as a *working directory* to canonicalize, not an omp
# subcommand -- so routing e.g. `update --check` through `miao launch` reads
# "update" as a target directory (which doesn't exist) and the launch fails.
#
# ompweb only ever constructs the RPC shape as exactly `--mode rpc-ui ...`,
# so checking the first argument is a precise, non-overlapping discriminator
# between the two shapes.
#
# Both branches exec /usr/local/bin/<bin> by absolute path rather than a bare
# name: ompweb runs this wrapper inside captain-miao's pty pool, whose
# background --cmd children get a minimal PATH that omits /usr/local/bin, and
# an absolute path also can't be shadowed by an earlier PATH entry (e.g. a
# stray personal ~/.local/bin/miao).
#
# The RPC branch additionally needs /usr/local/bin ON PATH, not just as our
# own exec target: once handed off, captain-miao's own agent_command() does
# its own unconditional `find_in_path("omp")` internally (crates/cm-core/src
# /agents/common.rs) with no env var or flag to override it, so miao itself
# must be able to see /usr/local/bin to find the omp binary it launches.
if [ "$1" = "--mode" ]; then
  export PATH="/usr/local/bin:$PATH"
  exec /usr/local/bin/miao launch omp --pool-session ompweb "$@"
fi
exec /usr/local/bin/omp "$@"
