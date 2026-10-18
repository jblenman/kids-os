#!/usr/bin/env bash
# Boot the built image under QEMU on the Mac, headless (x86-64 under TCG: slow, but it validates GRUB on BIOS and on EFI).
#   ./test-qemu.sh bios|efi [image.raw]     starts QEMU in the background on a scratch copy of the image
#   ./qemu-mon.py shot                      saves a PNG of the guest display (QEMU monitor screendump)
#   ./qemu-mon.py quit                      stops it
# Guest ssh: ssh -p 2222 <admin>@localhost (the keys from the configuration directory are in the image). Serial console log: ~/kids-os-build/qemu/serial.log
set -euo pipefail
MODE="${1:-bios}"
IMG="${2:-$(ls -t "$HOME"/kids-os-build/*.raw | head -1)}"
WORK="$HOME/kids-os-build/qemu"; mkdir -p "$WORK"
cp -f "$IMG" "$WORK/test.raw"            # boot a scratch copy, never the build output
python3 -c "import sys; f=open(sys.argv[1],'r+b'); f.truncate(16<<30)" "$WORK/test.raw"   # 16 GiB disk: room for the 4 GiB root + the first-boot /data partition
: > "$WORK/serial.log"
ARGS=(-machine q35 -cpu max -smp 2 -m 2048 -drive "file=$WORK/test.raw,format=raw,if=virtio"
      -netdev user,id=n0,hostfwd=tcp::2222-:22 -device virtio-net-pci,netdev=n0
      -vga std -display none -monitor "unix:$WORK/monitor.sock,server,nowait" -serial "file:$WORK/serial.log"
      -pidfile "$WORK/qemu.pid")
if [ "$MODE" = efi ]; then
    FW="$(brew --prefix)/share/qemu/edk2-x86_64-code.fd"
    cp -f "$(brew --prefix)/share/qemu/edk2-i386-vars.fd" "$WORK/vars.fd"
    ARGS+=(-drive "if=pflash,format=raw,readonly=on,file=$FW" -drive "if=pflash,format=raw,file=$WORK/vars.fd")
fi
echo "QEMU ($MODE) on $IMG → monitor $WORK/monitor.sock, serial $WORK/serial.log"
nohup qemu-system-x86_64 "${ARGS[@]}" > "$WORK/qemu.out" 2>&1 &
echo "pid $!"
