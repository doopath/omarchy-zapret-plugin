#!/bin/bash
# Install the zapret-ctl root helper and its sudoers whitelist.
# Idempotent: safe to re-run after a plugin update.
#
# Run as root:  sudo ./scripts/install-helper.sh

set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
HELPER_SRC="$SCRIPT_DIR/zapret-ctl"
SUDOERS_SRC="$SCRIPT_DIR/zapret-ctl.sudoers"
HELPER_DST=/usr/local/bin/zapret-ctl
SUDOERS_DST=/etc/sudoers.d/zapret-ctl

if [[ $EUID -ne 0 ]]; then
  echo "install-helper: run as root: sudo $0" >&2
  exit 1
fi

[[ -f $HELPER_SRC ]] || { echo "install-helper: missing $HELPER_SRC" >&2; exit 1; }
[[ -f $SUDOERS_SRC ]] || { echo "install-helper: missing $SUDOERS_SRC" >&2; exit 1; }

# The sudoers rule is granted to the user who invoked sudo (or pkexec).
# Defaults to the owner this plugin was written for when run from a root shell.
target_user=${SUDO_USER:-}
if [[ -z $target_user && -n ${PKEXEC_UID:-} ]]; then
  target_user=$(id -nu "$PKEXEC_UID" 2>/dev/null || true)
fi
target_user=${target_user:-doopath}
if ! id "$target_user" >/dev/null 2>&1; then
  echo "install-helper: unknown user '$target_user'" >&2
  exit 1
fi

# Refuse to continue if a helper already exists that we are not replacing with
# something we can verify (wrong owner/mode is a security problem).
if [[ -e $HELPER_DST ]]; then
  owner=$(stat -c '%U:%G' "$HELPER_DST")
  mode=$(stat -c '%a' "$HELPER_DST")
  if [[ $owner != root:root || $mode != 755 ]]; then
    echo "install-helper: refusing to replace $HELPER_DST ($owner $mode) with unexpected ownership/mode" >&2
    exit 1
  fi
fi

install -o root -g root -m 0755 "$HELPER_SRC" "$HELPER_DST"

# Build the sudoers file and let visudo validate it before it can take effect.
tmp=$(mktemp)
trap 'rm -f "$tmp"' EXIT
sed "s/^doopath /$target_user /" "$SUDOERS_SRC" > "$tmp"
visudo -cf "$tmp" >/dev/null

install -o root -g root -m 0440 "$tmp" "$SUDOERS_DST"

if ! grep -Eq '^[[:space:]]*@includedir[[:space:]]+/etc/sudoers.d' /etc/sudoers; then
  echo "install-helper: warning: /etc/sudoers does not include /etc/sudoers.d" >&2
fi

echo "installed $HELPER_DST (root:root 0755)"
echo "installed $SUDOERS_DST (root:root 0440) for user $target_user"
echo "check: $HELPER_DST status (no sudo) and sudo -n -l $HELPER_DST start"
