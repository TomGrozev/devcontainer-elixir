#!/bin/sh
# omp-web-omp-bin: OMP_WEB_OMP_BIN target, resolved by ompweb for EVERY omp
# binary invocation it makes \u2014 not just chat sessions. ompweb's resolveOmpBin()
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
# subcommand \u2014 so routing e.g. `update --check` through `miao launch` reads
# "update" as a target directory (which doesn't exist) and the launch fails.
# That failure is exactly what surfaces as "omp not found in PATH": once
# routed through the launcher, ompweb's RPC-mode client relays the failed
# child's stderr straight into its own UI, so a captain-miao-side failure
# shows up inside ompweb too.
#
# ompweb only ever constructs the RPC shape as exactly `--mode rpc-ui ...`,
# so checking the first argument is a precise, non-overlapping discriminator
# between the two shapes.
if [ "$1" = "--mode" ]; then
  exec miao launch omp --pool-session ompweb "$@"
fi
exec omp "$@"
