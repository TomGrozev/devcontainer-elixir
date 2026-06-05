#!/bin/sh
# sudo-passthrough: Wrapper for sudo(8) in rootless DevPod containers
#
# When the container already runs as the target user (UID 1000/dev),
# privilege escalation is unnecessary and blocked by pod security contexts
# that drop ALL capabilities and set allowPrivilegeEscalation=false.
# This wrapper strips sudo and executes the command directly,
# avoiding CAP_SETUID/CAP_SETGID requirements.

exec "$@"
