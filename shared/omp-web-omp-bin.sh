#!/bin/sh
# omp-web-omp-bin: OMP_WEB_OMP_BIN target for ompweb's RPC-mode agent spawns.
#
# ompweb (@kahme247/ompweb) resolves this path via OMP_WEB_OMP_BIN and spawns
# it directly, with pipe stdio, once per chat session it opens:
#   spawn(OMP_WEB_OMP_BIN, ["--mode", "rpc-ui", "--cwd", <dir>, ...extraArgs])
#
# Rather than exec the bare `omp` binary, hand that same argv to `miao launch
# omp` — captain-miao's agent launcher. It strips its own `--pool-session`
# flag, prepends `-e <generated-hook-extension>`, and execs omp with the rest
# untouched, so every session ompweb opens becomes a hooked, dashboard-visible
# row instead of an invisible child process.
#
# `--pool-session` is captain-miao's own flag here, not a real pooled-session
# name. It does two things, both load-bearing for this headless, terminal-less
# invocation:
#   - it exempts the launch from captain-miao's "must run inside a supported
#     terminal (Kitty or zellij)" check, which would otherwise reject this
#     (main.rs's requires_terminal());
#   - as a name with no registered pool daemon, it makes the launcher's
#     daemon-liveness watch (wait_until_minting_daemon_gone) resolve to "wait
#     forever" instead of finding nothing and killing the session immediately.
#
# The launcher inherits its own stdio verbatim (plain fd passthrough, no PTY
# allocated) and execs omp with it, so the RPC framing ompweb speaks over
# stdin/stdout reaches omp untouched. Hook events travel over a separate Unix
# socket entirely, so they never interleave with that stream.
exec miao launch omp --pool-session ompweb "$@"
