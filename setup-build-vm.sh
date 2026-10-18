#!/usr/bin/env bash
# One-time build-host setup on the Mac: Lima + QEMU from Homebrew, a Debian 13 (arm64) VM `kidos-build` with mkosi,
# x86-64 user-mode emulation, and the one amd64-only tool mkosi needs for BIOS GRUB (grub-bios-setup, which Debian
# ships only in the amd64 grub-pc-bin package) running under that emulation. Idempotent enough to re-run.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"; . "$HERE/lib/env.sh"
VM="${KIDS_OS_VM:-kidos-build}"
brew list lima >/dev/null 2>&1 || brew install lima
brew list qemu >/dev/null 2>&1 || brew install qemu
mkdir -p "$KIDS_OS_OUT"
if ! limactl list --json 2>/dev/null | grep -q "\"name\":\"$VM\""; then
    limactl create --name="$VM" --cpus=4 --memory=6 --disk=60 \
        --mount-only="$HERE:w" --mount-only="$KIDS_OS_OUT:w" --tty=false template://debian-13
fi
limactl start --tty=false "$VM"
limactl shell "$VM" -- sudo bash -s <<'VMEOF'
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y -qq mkosi qemu-user-static binfmt-support systemd-repart systemd-ukify systemd-boot erofs-utils \
    squashfs-tools e2fsprogs dosfstools mtools ntfs-3g cryptsetup-bin debian-archive-keyring apt-utils bubblewrap python3-pefile grub-common
# amd64 grub-bios-setup + the amd64 libraries it loads, run through qemu-user-static (binfmt) on this arm64 host
if [ ! -x /usr/lib/grub/i386-pc/grub-bios-setup ]; then
    dpkg --add-architecture amd64
    apt-get update -qq
    apt-get install -y -qq libc6:amd64 libdevmapper1.02.1:amd64 liblzma5:amd64 libfreetype6:amd64 libfuse3-4:amd64 \
        libefiboot1t64:amd64 libefivar1t64:amd64
    tmp=$(mktemp -d); cd "$tmp"
    apt-get download grub-pc-bin:amd64
    dpkg-deb -x grub-pc-bin_*_amd64.deb x
    install -d /usr/lib/grub/i386-pc
    install -m 755 x/usr/lib/grub/i386-pc/grub-bios-setup /usr/lib/grub/i386-pc/grub-bios-setup
    cd /; rm -rf "$tmp"
fi
echo "mkosi $(mkosi --version | awk '{print $2}'); grub-bios-setup: $(/usr/lib/grub/i386-pc/grub-bios-setup --version | awk '{print $NF}'); binfmt entries: $(ls /proc/sys/fs/binfmt_misc | grep -c qemu)"
VMEOF
