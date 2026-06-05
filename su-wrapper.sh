#!/bin/sh
# su-passthrough: Wrapper for su(1) in rootless DevPod containers
#
# When the container already runs as the target user (UID 1000/dev),
# switching to that user is a no-op. This wrapper just executes the
# command directly, avoiding the need for CAP_SETUID/CAP_SETGID
# capabilities that would otherwise be required by the real su binary.
#
# Handles all DevPod invocation patterns:
#   su -c "CMD" 'USER'         (SSH helper, GPG setup)
#   su USER -c CMD             (lifecycle hooks, git creds, IDEs)
#   su USER -l -c CMD          (check command exists)
#   su USER -w ENV -l -c CMD   (Jupyter/RStudio with env preservation)
#   su - USER [-c CMD]        (interactive SSH sessions, login shell)
#   su USER                   (interactive shell)
#   su -c CMD                 (no user specified, agent inject fallback)

cmd=""
login_shell=false
next_is_c=false
next_is_w=false
next_is_s=false

# Parse all arguments
while [ $# -gt 0 ]; do
    # Handle flags whose values were attached to previous iteration
    if [ "$next_is_c" = true ]; then
        cmd="$1"
        next_is_c=false
        shift
        continue
    fi
    if [ "$next_is_w" = true ]; then
        # -w ENVVAR: env is already in our environment since we're
        # already the target user, so just skip the argument
        next_is_w=false
        shift
        continue
    fi
    if [ "$next_is_s" = true ]; then
        # -s SHELL: we select the shell ourselves, skip argument
        next_is_s=false
        shift
        continue
    fi

    case "$1" in
        -c)
            next_is_c=true
            shift
            ;;
        -l|--login)
            login_shell=true
            shift
            ;;
        -)
            # Bare dash = login shell flag (e.g., "su - username")
            login_shell=true
            shift
            ;;
        -w)
            next_is_w=true
            shift
            ;;
        -s)
            next_is_s=true
            shift
            ;;
        -m|-p|--preserve-environment)
            # Environment is already preserved since we don't switch users
            shift
            ;;
        -*)
            # Unknown flags - skip them
            shift
            ;;
        *)
            # Positional argument (username) - ignored since we're
            # already running as the correct user
            shift
            ;;
    esac
done

# Handle remaining -c value if it wasn't consumed (shouldn't happen
# with well-formed input, but defensive)
if [ -n "$cmd" ]; then
    if [ "$login_shell" = true ]; then
        exec /bin/zsh --login -c "$cmd"
    else
        exec /bin/sh -c "$cmd"
    fi
else
    # No command - start a login shell or interactive shell
    if [ "$login_shell" = true ]; then
        exec /bin/zsh --login
    else
        exec /bin/zsh
    fi
fi
