#!/bin/sh
# sudo-passthrough: Wrapper for sudo(8) in rootless DevPod containers
#
# When the container already runs as the target user (UID 1000/dev),
# privilege escalation is unnecessary and blocked by pod security contexts
# that drop ALL capabilities and set allowPrivilegeEscalation=false.
# This wrapper strips sudo and executes the command directly,
# avoiding CAP_SETUID/CAP_SETGID requirements.
#
# chown is a special case: non-root users cannot change file ownership
# on Linux, but DevPod's GPG setup runs `sudo chown -R 1000:1000 ...`
# to (re)assert ownership of GPG socket paths. Since we are already
# running as that user, this is effectively a no-op. We short-circuit
# the matching case and silently swallow failures on other chown calls
# because there is nothing useful we can do without root in a rootless
# container.

case "$1" in
	chown|/bin/chown|/usr/bin/chown)
		chown_cmd="$1"
		shift
		current_uid="$(id -u)"
		current_gid="$(id -g)"
		# Find the ownership spec by skipping any leading options
		# (e.g. -R, -v, --reference=R, ..., or a "--" terminator).
		target=""
		for arg in "$@"; do
			case $arg in
				--|-*)	continue ;;
				*)	target=$arg; break ;;
			esac
		done
		if [ "$target" = "${current_uid}:${current_gid}" ]; then
			# Already owned by us, or will be via K8s fsGroup; no-op.
			exit 0
		fi
		# Other chown calls: try, but don't fail the wrapper.
		"$chown_cmd" "$@" || exit 0
		exit 0
		;;
esac

exec "$@"
