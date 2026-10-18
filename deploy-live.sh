#!/usr/bin/env bash
# deploy-live.sh — push the image overlay (mkosi/mkosi.extra) onto a RUNNING box over ssh and reload systemd.
# Live patching for everything that is not boot chain, partition layout or packages; those need a new image.
#   ./deploy-live.sh admin@host      → that box
#   ./deploy-live.sh                 → $KIDS_OS_HOST (environment, or a KIDS_OS_HOST=admin@host line in secrets.env)
#   DRY=1 ./deploy-live.sh [host]    → list what would be written, write nothing
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"; . "$HERE/lib/env.sh"
HOST="${1:-$BOX}"
[ -n "$HOST" ] || { echo "usage: ./deploy-live.sh admin@host   (or set KIDS_OS_HOST=admin@host in $KIDS_OS_SECRETS)" >&2; exit 2; }
# the box's host key changes with every re-image, so it is not pinned (home LAN use)
SSH="ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR -o ConnectTimeout=20"
SRC="$HERE/mkosi/mkosi.extra"
# build-time-only files stay out of live pushes
EXCLUDES=(--exclude=./etc/kids-os/local --exclude=./etc/default/google-chrome)
if [ "${DRY:-0}" = 1 ]; then
    (cd "$SRC" && tar -cf - "${EXCLUDES[@]}" . | tar -tf - | grep -v '/$')
    exit 0
fi
(cd "$SRC" && tar -cf - "${EXCLUDES[@]}" .) | $SSH "$HOST" 'sudo tar -C / -xvf - --no-same-owner --no-overwrite-dir 2>/dev/null | grep -v "/$"; sudo systemctl daemon-reload && echo "systemd reloaded"'
cat <<MSG
Pushed. Services pick up unit/config changes on their next start. To apply session changes now
(this kicks whoever is on the screen for ~10 s):   ssh $HOST sudo systemctl restart kid-session
MSG
