#!/bin/sh
# omp-web-omp-bin: OMP_WEB_OMP_BIN target. ompweb resolves this one binary for
# EVERY omp invocation it makes, in two structurally different shapes:
#
#   1. Interactive chat sessions:  spawn(bin, ["--mode", "rpc-ui", "--cwd", …])
#   2. One-shot CLI calls:         execFile(bin, ["update", "--check"]), etc.
#
# Only (1) goes through captain-miao's launcher, so the session gets hooks and a
# dashboard row instead of being an invisible child. (2) MUST reach the real omp
# untouched: miao's `split_cwd` reads a leading non-`-` positional as a working
# directory, so `miao launch omp update --check` looks for a dir named "update"
# and fails. ompweb builds the RPC shape as exactly `--mode rpc-ui …`, so `$1`
# discriminates the two exactly.
#
# `--launch-id`, not `--pool-session`. These children are spawned by ompweb with
# pipe stdio, so they are NOT in miao-server's pty pool. Claiming otherwise gets
# them killed: `pool_session` is how the daemon identifies pool members, and at
# startup `reap_previous_pool_launchers()` SIGTERMs every launcher carrying one,
# on the assumption it is a leftover from a previous incarnation — and the
# launcher's SIGTERM handler kills its agent (miao v0.7.0,
# cm-server/src/server.rs + cm-core/src/launcher.rs). So any daemon (re)start —
# `daemon ensure` after a crash, a stop, or the 300s idle exit — would wipe every
# live ompweb chat session. A fixed name compounded it: name resolution is
# first-match, so an attach report for one session could signal a sibling.
# Either flag equally suppresses the launcher's window self-report, which is what
# a headless child wants, so `--launch-id` gives that up for nothing.
#
# Absolute /usr/local/bin paths: this wrapper runs inside a pool `--cmd` child,
# whose minimal PATH omits /usr/local/bin, and an absolute path can't be
# shadowed by a stray earlier entry. The RPC branch additionally needs it ON
# PATH, because once handed off miao's own agent_command() does an
# unconditional, unoverridable `find_in_path("omp")` (cm-core/src/agents/common.rs).
if [ "$1" = "--mode" ]; then
  export PATH="/usr/local/bin:$PATH"
  exec /usr/local/bin/miao launch omp --launch-id "omp-web-$$" "$@"
fi
exec /usr/local/bin/omp "$@"
