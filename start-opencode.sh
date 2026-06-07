#!/bin/bash
#
# start-opencode.sh
#
# Launches the opencode server in the background with a cryptographically
# random password. The password is exported as OPENCODE_SERVER_PASSWORD so
# that the opencode server process (and any future processes that source
# this script) can read it from the environment.
#
# Usage:
#   ./start-opencode.sh                       # use default port (4096)
#   ./start-opencode.sh 5050                  # custom port via positional arg
#   OPENCODE_PORT=5050 ./start-opencode.sh    # custom port via env var
#
# To make OPENCODE_SERVER_PASSWORD available in your *current* shell, source
# this script instead of executing it:
#   source ./start-opencode.sh
#

set -euo pipefail

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
DEFAULT_PORT=4096
LOG_FILE=/tmp/opencode-serve.log

# ---------------------------------------------------------------------------
# Resolve port.
#
# Precedence: positional argument > OPENCODE_PORT env var > default.
# ---------------------------------------------------------------------------
PORT="${1:-${OPENCODE_PORT:-${DEFAULT_PORT}}}"

# ---------------------------------------------------------------------------
# Pre-flight: verify the `opencode` binary is on PATH.
# ---------------------------------------------------------------------------
if ! command -v opencode >/dev/null 2>&1; then
  cat >&2 <<'EOF'
❌  Error: 'opencode' command not found in PATH.
    Install opencode first (e.g. 'curl -fsSL https://opencode.ai/install | bash').
EOF
  exit 127
fi

# ---------------------------------------------------------------------------
# Generate a cryptographically random password.
#
# 24 random bytes from /dev/urandom → 32 base64 characters (~192 bits of
# entropy). /dev/urandom is the correct source for password-grade randomness
# on Linux: it is non-blocking but draws from the same CSPRNG pool as
# /dev/random. `base64` is provided by coreutils on Debian/Ubuntu.
# ---------------------------------------------------------------------------
PASSWORD="$(head -c 24 /dev/urandom | base64 | tr -d '\n')"

# ---------------------------------------------------------------------------
# Export the password for the opencode server process and any future
# processes spawned in this session. (Use `source` to inherit it in the
# current interactive shell.)
# ---------------------------------------------------------------------------
export OPENCODE_SERVER_PASSWORD="${PASSWORD}"

# ---------------------------------------------------------------------------
# Launch the server fully detached from the current shell.
#
#   nohup        — ignore SIGHUP so the process survives shell exit
#   &            — background the process
#   disown       — remove from the shell's job table
#   >LOG 2>&1    — capture both stdout and stderr to the log file
# ---------------------------------------------------------------------------
nohup opencode serve --port "${PORT}" > "${LOG_FILE}" 2>&1 &
disown

# ---------------------------------------------------------------------------
# Notify the user. The password is shown exactly once — there is no way to
# retrieve it after this script exits, so it must be saved now.
# ---------------------------------------------------------------------------
cat <<EOF
⚠️   OPENCODE SERVER STARTED
⚠️   Server URL: http://localhost:${PORT}
🔑   Password: ${PASSWORD}

⚠️   IMPORTANT: Save this password! It cannot be retrieved later.
⚠️   The password is also available in the OPENCODE_SERVER_PASSWORD environment variable.
📋   Logs: ${LOG_FILE}
EOF
