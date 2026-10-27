#!/bin/bash
# Remove the zapret-ctl root helper and its sudoers whitelist.
# Idempotent: missing files are not an error.
#
# Run as root:  sudo ./scripts/uninstall-helper.sh

set -euo pipefail

HELPER_DST=/usr/local/bin/zapret-ctl
SUDOERS_DST=/etc/sudoers.d/zapret-ctl

if [[ $EUID -ne 0 ]]; then
  echo "uninstall-helper: run as root: sudo $0" >&2
  exit 1
fi

rm -f "$SUDOERS_DST"
rm -f "$HELPER_DST"

echo "removed $SUDOERS_DST and $HELPER_DST (if present)"
