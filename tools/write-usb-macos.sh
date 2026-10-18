#!/bin/bash
# write_image_usb.sh - write a raw disk image to a USB stick or card on macOS and verify it byte for byte.
# Usage: sudo bash write_image_usb.sh IMAGE diskN
#   IMAGE  a raw image (.bin / .img / .iso), already unpacked; its size must be a multiple of 512 bytes
#   diskN  the whole-disk identifier from `diskutil list` (must be external, physical)
# Steps: show the disk -> YES -> unmountDisk force -> dd bs=4m status=progress -> sync ->
#        read the written length back from /dev/rdiskN (raw = uncached) and compare SHA-1 -> eject.
# Exit 1 on mismatch. Needs root for the raw device. DESTROYS everything on diskN.
set -euo pipefail
IMG="${1:?usage: sudo bash $0 IMAGE diskN}"; DISK="${2:?usage: sudo bash $0 IMAGE diskN}"
[ "$(id -u)" = 0 ] || { echo "run with sudo"; exit 1; }
[ -f "$IMG" ] || { echo "no such image: $IMG"; exit 1; }
SIZE=$(stat -f %z "$IMG")
[ $((SIZE % 512)) = 0 ] || { echo "image size $SIZE is not a multiple of 512 bytes; pad it first (dd if=/dev/zero bs=1 count=$((512 - SIZE % 512)) >> \"$IMG\")"; exit 1; }
INFO=$(diskutil info "$DISK")
echo "$INFO" | grep -q "Device Location: *External" || { echo "refusing: $DISK is not an external disk"; exit 1; }
DISK_BYTES=$(echo "$INFO" | sed -n 's/.*Disk Size:.*(\([0-9]*\) Bytes).*/\1/p')
[ "$SIZE" -le "$DISK_BYTES" ] || { echo "image ($SIZE B) is larger than $DISK ($DISK_BYTES B)"; exit 1; }
DEV="/dev/r$DISK"
echo "Image: $IMG ($SIZE bytes)"; echo "Target:"; diskutil list "$DISK"
read -r -p "Everything on $DISK will be destroyed. Type YES to continue: " ok; [ "$ok" = "YES" ] || exit 1
diskutil unmountDisk force "$DISK" >/dev/null
echo "== $(date '+%H:%M:%S') writing =="
dd if="$IMG" of="$DEV" bs=4m status=progress
sync
echo "== $(date '+%H:%M:%S') verifying (SHA-1 of the image vs the device) =="
diskutil unmountDisk force "$DISK" >/dev/null 2>&1 || true
want=$(shasum -a 1 "$IMG" | awk '{print $1}')
full=$((SIZE / 4194304)); rest=$(( (SIZE - full * 4194304) / 512 ))
got=$( { dd if="$DEV" bs=4m count=$full; [ "$rest" = 0 ] || dd if="$DEV" bs=512 skip=$((full * 8192)) count=$rest; } 2>/dev/null | shasum -a 1 | awk '{print $1}')
echo "  image:  $want"; echo "  device: $got"
if [ "$want" = "$got" ]; then echo "  VERIFIED - byte for byte"; else echo "  MISMATCH - do not use this media"; fi
diskutil eject "$DISK" >/dev/null 2>&1 && echo "== $(date '+%H:%M:%S') ejected - unplug it ==" || echo "(could not eject; unplug once the light stops)"
[ "$want" = "$got" ]
