#!/usr/bin/env bash
# Make the 2 GiB fake "Windows disk" that test-install.sh attaches: an MBR disk with two NTFS partitions labelled like a
# BIOS Windows install ("System Reserved" + "Windows") so the installer's --windows-disk path has something to find.
# Needs sfdisk, losetup and mkntfs (ntfs-3g), so it runs inside the build VM unless KIDS_OS_BUILD_HOST=native.
# Output: $KIDS_OS_OUT/win-fake.raw (default ~/kids-os-build/win-fake.raw)
set -euo pipefail
HERE="$(cd "$(dirname "$0")/.." && pwd)"; . "$HERE/lib/env.sh"
OUT="$KIDS_OS_OUT/win-fake.raw"; mkdir -p "$KIDS_OS_OUT"
read -r -d '' SCRIPT <<'SH' || true
set -euo pipefail
T=$(mktemp /var/tmp/win-fake.XXXXXX); truncate -s 2G "$T"
command -v mkntfs >/dev/null || DEBIAN_FRONTEND=noninteractive apt-get install -y -qq ntfs-3g >/dev/null
sfdisk -q "$T" <<SF
label: dos
unit: sectors
size=1048576, type=7, bootable
type=7
SF
LOOP=$(losetup --find --show --partscan "$T")
# mkntfs warns that a loop device has no CHS geometry and "Windows will not be able to boot" — intended, this disk never boots
mkntfs -Q -F -L "System Reserved" "${LOOP}p1" >/dev/null 2>&1
mkntfs -Q -F -L "Windows" "${LOOP}p2" >/dev/null 2>&1
losetup -d "$LOOP"
cp -f "$T" "$1"; rm -f "$T"; chmod 644 "$1"
SH
if [ "${KIDS_OS_BUILD_HOST:-lima}" = native ]; then
    sudo bash -c "$SCRIPT" _ "$OUT"
else
    limactl shell "${KIDS_OS_VM:-kidos-build}" -- sudo bash -c "$SCRIPT" _ "$OUT"
fi
echo "wrote $OUT"
