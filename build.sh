#!/usr/bin/env bash
# Build the kids-os image and copy it to $KIDS_OS_OUT (default ~/kids-os-build/).
#   ./build.sh                       build with the default configuration directory (~/.config/kids-os)
#   KIDS_OS_SECRETS=file ./build.sh  another secrets file (e.g. a test one carrying KIDS_OS_PIN=1234)
#   KIDS_OS_BUILD_HOST=native        run mkosi on this machine (Linux x86-64, mkosi ≥ 25, root) instead of the Lima VM
# Per-family configuration lives in $KIDS_OS_CONFIG: secrets.env (KEY=VALUE lines, see README) plus optional
# authorized_keys, config.json and wallpaper.png. The secrets file is handed to mkosi by variable NAME
# (--environment=NAME) so no value appears on a command line or in the build log; the files are staged into
# mkosi/mkosi.extra/etc/kids-os/local/ (git-ignored, removed after the build) and consumed by mkosi.postinst.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"; . "$HERE/lib/env.sh"
VM="${KIDS_OS_VM:-kidos-build}"; OUT="$KIDS_OS_OUT"; LOG="$OUT/build.log"
VM_OUT=/var/tmp/kidos-out; VM_CACHE=/var/tmp/kidos-cache; VM_SECRETS=/tmp/kidos-secrets.env
KEYS="KIDS_OS_ADMIN_USER KIDS_OS_ADMIN_PASSWORD_HASH KIDS_OS_WIFI_SSID KIDS_OS_WIFI_PSK KIDS_OS_PIN KIDS_OS_HOSTNAME KIDS_OS_TIMEZONE KIDS_OS_SCALE KIDS_OS_DATA_MAX"
LOCAL="$HERE/mkosi/mkosi.extra/etc/kids-os/local"
mkdir -p "$OUT"

# stage the family's files for mkosi.postinst (removed again when the build ends)
rm -rf "${LOCAL:?}"; mkdir -p "$LOCAL"; trap 'rm -rf "${LOCAL:?}"' EXIT
for f in authorized_keys config.json wallpaper.png; do
    if [ -f "$KIDS_OS_CONFIG/$f" ]; then cp "$KIDS_OS_CONFIG/$f" "$LOCAL/$f"; fi
done
[ -s "$LOCAL/authorized_keys" ] || echo "WARNING: $KIDS_OS_CONFIG/authorized_keys is missing — the image will accept no ssh login" >&2
if [ -f "$KIDS_OS_SECRETS" ]; then
    echo "secrets: $KIDS_OS_SECRETS (passed by name: $KEYS)"
else
    echo "secrets: none ($KIDS_OS_SECRETS missing) — defaults: admin user 'admin', no Wi-Fi, no console password, no PIN"
fi
ENVFLAGS=""; for k in $KEYS; do ENVFLAGS="$ENVFLAGS --environment=$k"; done
# the secrets file is read line by line and exported, so values may hold spaces and shell characters
EXPORT_SECRETS='if [ -f "$S" ]; then while IFS= read -r l || [ -n "$l" ]; do case "$l" in ""|"#"*) ;; *) export "$l";; esac; done < "$S"; fi'

if [ "${KIDS_OS_BUILD_HOST:-lima}" = native ]; then
    # not exercised by the maintainer yet (builds happen in the Lima VM); kept close to the VM path on purpose
    S="$KIDS_OS_SECRETS"; eval "$EXPORT_SECRETS"
    (cd "$HERE/mkosi" && sudo -E mkosi --output-directory "$OUT/mkosi.out" --cache-directory "$OUT/mkosi.cache" --incremental --force $ENVFLAGS build "$@") 2>&1 | tee "$LOG" | grep -E "^‣ |BUILD|Error|E: " || true
    cp -f "$OUT"/mkosi.out/*.raw "$OUT/"
else
    if [ -f "$KIDS_OS_SECRETS" ]; then limactl copy "$KIDS_OS_SECRETS" "$VM:$VM_SECRETS"; fi
    limactl shell "$VM" -- sudo bash -c "set -euo pipefail; mkdir -p $VM_OUT $VM_CACHE; rm -f ${VM_OUT:?}/*.raw; S=$VM_SECRETS; $EXPORT_SECRETS; \
        cd '$HERE/mkosi' && mkosi --output-directory $VM_OUT --cache-directory $VM_CACHE --incremental --force $ENVFLAGS build $*; \
        rm -f $VM_SECRETS" 2>&1 | tee "$LOG" | grep -E "^‣ |BUILD|Error|E: " || true
    limactl shell "$VM" -- bash -c "ls -l $VM_OUT/*.raw && cp -f $VM_OUT/*.raw '$OUT/'"
fi
ls -l "$OUT"/*.raw
