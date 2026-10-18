#!/usr/bin/env bash
# Rehearse kids-os-install under QEMU: boot the image as a USB stick with an empty "SSD" and a fake Windows disk attached,
# run the installer against the SSD, then boot from the SSD alone (legacy BIOS) and check the result.
# usage: [KIDS_OS_SECRETS=…] bash test-install.sh ~/kids-os-build/kids-os_<version>.raw   (needs win-fake.raw: tools/make-fake-windows-disk.sh)
set -uo pipefail
IMG="$1"; cd "$(dirname "$0")"; . ./lib/env.sh; W="$KIDS_OS_OUT/qemu"; mkdir -p "$W"
S() { ssh -p 2222 -o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR -o ConnectTimeout=5 "$ADMIN"@localhost "$@" 2>&1 | grep -v "Could not chdir"; }
waitssh() { local max=${1:-180} n=0; until ssh -p 2222 -o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR -o ConnectTimeout=5 "$ADMIN"@localhost true >/dev/null 2>&1; do n=$((n+1)); [ $n -ge $max ] && return 1; sleep 5; done; echo "ssh after ~$((n*5)) s"; }
pgrep -x qemu-system-x86_64 >/dev/null && pkill -x qemu-system-x86_64; sleep 1
cp -f "$IMG" "$W/stick.raw"; rm -f "$W/ssd.raw"; python3 -c "open('$W/ssd.raw','wb').truncate(20<<30)"; cp -f "$KIDS_OS_OUT/win-fake.raw" "$W/win.raw"; : > "$W/serial.log"
COMMON=(-machine q35 -cpu max -smp 2 -m 2048 -netdev user,id=n0,hostfwd=tcp::2222-:22 -device virtio-net-pci,netdev=n0 -vga std -display none -monitor "unix:$W/monitor.sock,server,nowait" -serial "file:$W/serial.log" -pidfile "$W/qemu.pid")
echo "== phase 1: boot the stick (USB), SSD + Windows disks attached"
nohup qemu-system-x86_64 "${COMMON[@]}" -device qemu-xhci,id=xhci -drive if=none,id=stick,file="$W/stick.raw",format=raw -device usb-storage,bus=xhci.0,drive=stick,bootindex=0 \
    -drive file="$W/ssd.raw",format=raw,if=virtio -drive file="$W/win.raw",format=raw,if=virtio > "$W/qemu.out" 2>&1 &
waitssh || { echo "phase 1: no ssh"; ./qemu-mon.py quit; exit 1; }
# the repo's current installer replaces the image's copy, so an installer fix needs no rebuild
scp -P 2222 -o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR mkosi/mkosi.extra/usr/lib/kids-os/kids-os-install "$ADMIN"@localhost:/tmp/kids-os-install \
    && S 'sudo install -m 755 /tmp/kids-os-install /usr/lib/kids-os/kids-os-install && echo "installer injected from the repo"'
S 'lsblk -o NAME,SIZE,TRAN,FSTYPE,LABEL,MOUNTPOINTS | grep -v loop; echo "--- running the installer:"; sudo /usr/lib/kids-os/kids-os-install /dev/vda --windows-disk /dev/vdb --yes 2>&1 | tail -15; echo "--- result table:"; lsblk -o NAME,SIZE,PARTTYPENAME,FSTYPE,LABEL /dev/vda; echo "--- MBR boot code: $(sudo dd if=/dev/vda bs=1 count=3 2>/dev/null | od -An -tx1)"'
MBR=$(S 'sudo dd if=/dev/vda bs=1 count=3 2>/dev/null | od -An -tx1' | tr -d ' \r\n')
./qemu-mon.py quit >/dev/null 2>&1; sleep 2
case "$MBR" in ""|000000) echo "phase 1: the installer left no boot code in the MBR ($MBR) — phase 2 skipped"; exit 1;; esac
echo "== phase 2: boot from the SSD alone, legacy BIOS"
: > "$W/serial.log"
nohup qemu-system-x86_64 "${COMMON[@]}" -drive file="$W/ssd.raw",format=raw,if=virtio -drive file="$W/win.raw",format=raw,if=virtio > "$W/qemu.out" 2>&1 &
sleep 2.5; cp -f "$(./qemu-mon.py shot)" "$KIDS_OS_OUT/install-grub-menu.png" 2>/dev/null && echo "GRUB menu shot: $KIDS_OS_OUT/install-grub-menu.png"
waitssh 60 || { echo "phase 2: no ssh"; tr -d '\033' < "$W/serial.log" | grep -a -v "^\[" | tail -8; ./qemu-mon.py quit; exit 1; }
sleep 30
S 'echo "booted via $([ -d /sys/firmware/efi ] && echo EFI || echo BIOS); root=$(findmnt -n -o SOURCE /); data=$(findmnt -n -o SOURCE,SIZE /data); failed=$(systemctl --failed --no-legend | wc -l); kid-session=$(systemctl is-active kid-session) greeter=$(systemctl is-active greeter-session)"; lsblk -o NAME,SIZE,FSTYPE,LABEL,MOUNTPOINTS | grep -v loop; echo "--- grub.cfg menu entries (the installed fstab mounts the boot partition at /boot):"; sudo grep -E "menuentry|search|drivemap|chainloader|linux " /boot/grub/grub.cfg | cut -c1-150; echo "--- fstab: $(grep -v "^#" /etc/fstab)"'
tr -d '\033' < "$W/serial.log" | grep -a -i -E "GRUB|Kids|Windows|Booting" | head -5 | cut -c1-100
./qemu-mon.py quit >/dev/null 2>&1; echo "install rehearsal done"
