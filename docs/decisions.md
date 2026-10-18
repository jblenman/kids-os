# Decisions

Each entry: what was decided, why, what was rejected. Newest last.

## 2026-10-16 — Build our own OS instead of staying on ChromeOS Flex (path B)
- **Why:** Flex cannot be managed by a home user — no policies without Google's paid enterprise tier, no supported administrative shell — and on this board it froze on every idle resume. The goal is the same look for the child and ordinary Linux underneath for the parents: ssh, policies, scripts, and a project worth exploring.
- **Rejected A — openFyde / ChromiumOS from source:** the literal Ash UI, but a Gentoo-sized build (x86-64 host, ~200 GB, hours per build), Family Link support on non-Google builds unverified, and the same kernel/graphics stack whose sleep behaviour froze this board.
- **Rejected C — Yocto/Buildroot from source:** the deepest "own OS", but Chromium (not Chrome) → no Family Link, and Chromium builds eat the exploration budget. Possible later as a learning branch.

## 2026-10-16 — Debian 13 + mkosi
- Declarative, reproducible disk images from distro packages in minutes; verity-protected read-only roots, A/B partitions and `systemd-sysupdate` are first-class in the same tool. Debian for its package depth and Chrome's official .deb support.

## 2026-10-16 — Google Chrome's official .deb, not Chromium
- Family Link supervision and Google sign-in need Google's API keys; Chromium builds lost them in 2021. Google's own page confirms Family Link's website filter and SafeSearch apply to Chrome on Linux when the child signs in with sync (support.google.com/families/answer/7087030). Its listed gaps (sign out, switch profile, another browser) are closed by policy here.

## 2026-10-16 — GRUB for both EFI and BIOS; no Secure Boot; dm-verity only
- The board's "Hybrid EFI" boots an EFI GRUB (Flex's own path) but exposes no EFI runtime, Secure Boot or TPM. One GPT disk with an ESP (`EFI/BOOT/BOOTX64.EFI`) *and* a BIOS-boot partition covers both paths, exactly as Flex's partition 12 does. There is no firmware root of trust to build on, so integrity = dm-verity at runtime — which is also all Flex gets on this hardware.

## 2026-10-16 — Intel-only graphics in phase 1
- On Flex, Chrome renders on the Intel HD 3000 while the TITAN X only scans out under `nouveau`; the Intel VGA port reports a phantom 1024x768 display that forced mirror mode (and 1024x768 on the TV). Phase 1: `nouveau` blacklisted, `video=VGA-1:d`, TV on the motherboard HDMI at 1080p. Later option: NVIDIA's 580 branch (the last with Maxwell support) for 4K60.

## 2026-10-16 — Never suspend
- The box S3-suspended on Flex when idle; the dead-input black screens match a failed resume. `AllowSuspend=no`, `IdleAction=ignore`; DPMS display-off is the only idle behaviour.

## 2026-10-16 — Build host: a Lima VM on an Apple-silicon Mac
- Self-contained; the x86-64 image builds under `qemu-user-static` in about ten minutes incrementally. A native x86-64 Linux host is the faster option once builds get heavier (a real VM rather than WSL2, to keep loop devices and systemd uncomplicated); `build.sh` has a `KIDS_OS_BUILD_HOST=native` path for it.

## 2026-10-16 — Secrets and identity outside the tree
- Wi-Fi PSK, the admin's password hash, the PIN, the admin's name, hostname, time zone and ssh keys come from a configuration directory (`~/.config/kids-os/`), injected into the build as environment variables and staged files. Nothing personal is ever committed, which is also what makes the repository publishable.

## 2026-10-16 — BIOS GRUB on an arm64 build host
- mkosi runs `grub-bios-setup` from the *host* (it only takes the i386-pc modules from the image), and Debian ships that binary solely inside the amd64 `grub-pc-bin` package — the arm64 `grub-common` has `grub-mkimage` but no `grub-bios-setup`. Fix: extract the amd64 binary into the VM at `/usr/lib/grub/i386-pc/grub-bios-setup` (a path mkosi checks) with its amd64 libraries installed through multiarch; `qemu-user-static` runs it. Chrome's `.deb` post-install also needs `apt-config` in the image, so `apt` is in the package list, and `/etc/default/google-chrome` is pre-seeded with `repo_add_once="false"` so Chrome never adds its own apt repository on the box.

## 2026-10-18 — Installer: partition table and filesystems by script
- `sfdisk` script lines are `start=, size=, type=, name=, uuid=` fields (any omitted: start = next free, size = rest). The positional form (`- 2048 TYPE name=…`) the first draft used is rejected as `unsupported command`; the mistake only surfaced in the QEMU rehearsal because the running image lacked `sfdisk` until v0.20 (`fdisk` package).
- `mkfs.fat` (dosfstools) has no `-q`; an unknown option prints the help and exits 1, which `set -e` turns into a silent abort after the root copy. `mke2fs -q` is fine.
- `test-install.sh` copies the repo's `kids-os-install` into the booted guest before running it, so an installer fix is rehearsed without rebuilding the image; it also stops after phase 1 when the MBR has no boot code (the earlier run waited 15 min for an unbootable disk).

## 2026-10-18 — Installed boot partition is not an ESP
- The Gigabyte Z68XP-UD3's Hybrid EFI took the EFI path (and ate the setup keys) as soon as a GPT disk with an EFI System Partition was present. BIOS GRUB finds its files by filesystem UUID and never looks at the partition type, so the installer types the boot partition as a plain Linux partition and mounts it through fstab (`gpt-auto` would have mounted an ESP by itself). The stick image keeps its real ESP for UEFI machines.
- The root copy is a block copy of the live root: `sync` first; the Chrome profile lives on `/data` and is not copied, so the only in-flight writes are logs.
