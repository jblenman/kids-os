# Development and testing

## Build host
- **Apple-silicon Mac (what the maintainer uses):** `./setup-build-vm.sh` creates the Lima VM `kidos-build` (Debian 13, arm64, 4 CPUs, 6 GB) with mkosi, `qemu-user-static` for the x86-64 cross-build, `ntfs-3g` for the fake Windows disk, and the one amd64-only tool mkosi needs for BIOS GRUB (`grub-bios-setup`, extracted from the amd64 `grub-pc-bin` package and run through binfmt emulation — Debian's arm64 `grub-common` has `grub-mkimage` but not that binary). The repository and the output directory are mounted into the VM. `limactl stop kidos-build` when you are done, `limactl start kidos-build` before the next build.
- **Linux x86-64:** `KIDS_OS_BUILD_HOST=native ./build.sh` runs mkosi directly (needs mkosi ≥ 25 and root). This path is not yet exercised by the maintainer.
- An incremental rebuild takes about ten minutes under emulation; the first build (package download, Chrome's `.deb`) longer. Output: `$KIDS_OS_OUT/kids-os_<ImageVersion>.raw` (~3.2 GB raw, sparse). Bump `ImageVersion` in `mkosi/mkosi.conf` for every image you keep.

## Two kinds of change
- **Live patch** (anything under `mkosi/mkosi.extra/`: shell pages, units, scripts, configuration, policies): `./deploy-live.sh admin@host`, then `sudo systemctl restart kid-session` on the box (or wait for the next sign-out). The family loses the screen for about ten seconds.
- **Image change** (packages, kernel command line, partitions, `mkosi.postinst`): rebuild, rewrite the stick or reinstall. The installer copies the *running* root, so a box patched live and then installed carries the patches.

## Test bench (QEMU on the build Mac)
All tests boot the image headless under `qemu-system-x86_64` (TCG, slow but faithful), with ssh forwarded to `localhost:2222` and a QEMU monitor socket for screenshots.
- `./test-qemu.sh bios|efi IMG` — boot a scratch copy on a 16 GiB disk (room for the data partition to grow). `./qemu-mon.py shot` saves a PNG of the guest display, `./qemu-mon.py quit` stops it, anything else is sent to the monitor (`sendkey`, `info block`…). Serial console log: `$KIDS_OS_OUT/qemu/serial.log`.
- `bash test-v1b.sh IMG` — the shell end to end on an image built with `KIDS_OS_PIN=1234`: PIN screen → `sendkey 1 2 3 4 ret` → session up (labwc, waybar, Chrome) → launcher → `/api/launch` → sign out → back at the PIN screen, a screenshot per step, and the failed-unit dump at the end. Point `KIDS_OS_SECRETS` at the test secrets file so the script knows the image's admin user.
- `bash test-install.sh IMG` — the installer rehearsal: phase 1 boots the image as a USB stick with an empty 20 GiB "SSD" and the fake Windows disk attached, copies the repository's current `kids-os-install` into the guest (so an installer fix needs no rebuild) and runs it; phase 2 boots the SSD alone under legacy BIOS, screenshots the GRUB menu and checks root, data partition, failed units and the generated `grub.cfg`. Make the fake Windows disk once with `tools/make-fake-windows-disk.sh` (its NTFS partitions carry no boot code, so the Windows entry is verified as generated and parsed, not booted).

## Things that bit us
- Scripts that wait on ssh must not pipe through `grep -v` (its exit status is 1 on empty output and the loop never ends) — see the `waitssh` functions.
- `pkill -f` matches your own shell when the pattern appears in its command line; use `pkill -x` or a `[b]racket` in the pattern.
- `sfdisk` scripts take `size=, type=, name=, uuid=` fields; `mkfs.fat` has no `-q`; systemd mounts an ESP-typed partition at `/boot` by itself (gpt-auto), which is why the installed boot partition is typed as plain Linux and mounted through fstab. More in `docs/decisions.md`.
- Build outputs must not live under a cloud-synced folder (the maintainer's Google Drive client zeroed large freshly written files); `KIDS_OS_OUT` defaults to `~/kids-os-build/` for that reason.
