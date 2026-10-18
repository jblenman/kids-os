# kids-os

A small, locked-down Linux for a child's computer that looks and feels like a Chromebook. It boots straight into **Google Chrome** on a plain Wayland shell — wallpaper, a bottom shelf, an app launcher, an optional PIN sign-in — while the parents keep control through Chrome's enterprise policies, Google Family Link and their own network filter. It is built as a reproducible **Debian 13** disk image with [mkosi](https://github.com/systemd/mkosi), boots on legacy BIOS and UEFI, runs from a USB stick and installs to an internal drive next to an existing Windows.

**Why it exists.** ChromeOS Flex is excellent on old hardware, but a home user cannot manage it — no policies without the paid enterprise tier, no administrative shell — and on one old board it froze on every idle resume. kids-os keeps the part that matters to the child (Chrome, a sign-in screen, a shelf) and makes everything around it ordinary Debian that a parent can ssh into, patch and script. The decisions and the alternatives that were rejected: [`docs/decisions.md`](docs/decisions.md).

**Maturity.** One family's machine, a few days old: it runs daily on a 2011 Sandy Bridge desktop from a USB stick, the installer is rehearsed in QEMU, and every change goes through a QEMU test bench. Verified boot, A/B updates and remote management are on the roadmap, not in the tree. Expect rough edges and read [`docs/hardware-notes.md`](docs/hardware-notes.md) before blaming your board.

## What you get
- **Chrome** (Google's official package) maximized under `labwc`, at a device scale that suits a TV from the couch (1.5× by default, configurable).
- **A shelf** (`waybar`): launcher button, running apps, tray, network, volume, clock.
- **A launcher page**: search box plus an app grid you define in one JSON file.
- **An optional PIN sign-in screen** (avatar + pad), sign out, shut down / restart — all from the shell pages, all served by one small local service.
- **Chrome policies** that close the usual holes: no incognito, guest or extra profiles, no devtools, forced SafeSearch, restricted YouTube, downloads blocked, DNS-over-HTTPS off so your DNS filter sees every lookup.
- **Family Link**: the child signs into Chrome with their Google account; Google documents that Family Link's site filters and SafeSearch apply to Chrome on Linux when the child is signed in with sync ([support.google.com/families/answer/7087030](https://support.google.com/families/answer/7087030)); the policies above remove the sign-out and switch-profile escapes Google lists.
- **A separate data partition** for the Chrome profile, grown to the medium on first boot; a fixed 4 GiB root.
- **Admin access** over ssh (keys only), a console on tty2, `sudo` without a password for the admin.
- **An installer** that copies the running system onto an internal drive and adds a Windows entry to the boot menu.
- **A test bench**: headless QEMU boots, an end-to-end shell test, an installer rehearsal.

## Requirements
- **Target PC:** x86-64, ≥ 4 GB RAM, graphics that work with a wlroots compositor (Intel integrated graphics tested; `nouveau` is blacklisted so NVIDIA cards stay idle), Wi-Fi or Ethernet. Legacy BIOS or UEFI, no Secure Boot.
- **Build host:** an Apple-silicon Mac (`setup-build-vm.sh` creates a Lima VM that cross-builds the x86-64 image), or a Linux x86-64 machine with mkosi ≥ 25 (`KIDS_OS_BUILD_HOST=native`, not yet exercised by the maintainer).
- **A USB stick** ≥ 8 GB for the first boots — USB 3 if you can; USB 2 works but every write starves Chrome. A cheap SATA SSD for the permanent install is the single best upgrade for an old machine.
- A Google account for the child and one for a parent if you want Family Link.

## Quick start
1. **Configure.** Create `~/.config/kids-os/` with two files:

   `secrets.env` (KEY=VALUE lines; everything optional, the defaults are in parentheses):

   | key | meaning |
   |---|---|
   | `KIDS_OS_ADMIN_USER` | the parent's account on the box (`admin`) |
   | `KIDS_OS_ADMIN_PASSWORD_HASH` | `openssl passwd -6` output; console login on tty2 (none) |
   | `KIDS_OS_WIFI_SSID` / `KIDS_OS_WIFI_PSK` | Wi-Fi to join at boot (none — use Ethernet or `nmtui` on tty2) |
   | `KIDS_OS_PIN` | 4–8 digits; bakes the sign-in screen (none — straight into the session) |
   | `KIDS_OS_HOSTNAME` | (`kids-desktop`) |
   | `KIDS_OS_TIMEZONE` | tz database name, e.g. `Europe/Berlin` (`Etc/UTC`) |
   | `KIDS_OS_SCALE` | Chrome's device scale factor (`1.5`) |
   | `KIDS_OS_HOST` | `admin@ip` of the box, used by `deploy-live.sh` only (none) |

   `authorized_keys` — your SSH public key(s). Without it the image accepts no ssh login at all. Optional next to them: `config.json` (the launcher's apps — start from `mkosi/mkosi.extra/etc/kids-os/config.json`) and `wallpaper.png` (1920×1080).

2. **Build.** `./setup-build-vm.sh` once (macOS), then `./build.sh` → `~/kids-os-build/kids-os_<version>.raw`. Nothing from `~/.config/kids-os/` is ever written into the repository.
3. **Write the stick.** macOS: `sudo bash tools/write-usb-macos.sh ~/kids-os-build/kids-os_<version>.raw diskN` (verifies what it wrote). Linux: `sudo dd if=… of=/dev/sdX bs=4M conv=fsync status=progress`.
4. **Boot the PC from the stick** (boot-menu key or BIOS boot order; both the UEFI and the plain entry work). The first boot grows the data partition and starts Chrome; the PIN screen appears if you set `KIDS_OS_PIN`. Expect a slow first start from a USB 2 stick.
5. **Log in from another machine:** `ssh admin@<ip>` (`ip a` on tty2 if you do not know it). Edit `/etc/kids-os/config.json`, set or clear the PIN with `sudo kids-os-set-pin 1234` / `--clear`, look around.
6. **Install to an internal drive** when you are happy (below).

## Day to day
- **Apps:** `/etc/kids-os/config.json` — `name`, `avatar`, `search_url`, and `apps` (name, url, icon letter or emoji, color). The launcher reads it every time it opens.
- **PIN:** `sudo kids-os-set-pin 1234` turns the sign-in screen on, `sudo kids-os-set-pin --clear` off; effective at the next sign-out or boot.
- **Scale:** `KIDS_OS_SCALE` in `/etc/kids-os/kids-os.env`, then `sudo systemctl restart kid-session`.
- **Chrome policies:** `/etc/opt/chrome/policies/managed/kids-os.json`; Chrome rereads it on restart (`chrome://policy` shows what is active).
- **Wi-Fi changes:** `nmtui` or `nmcli` on tty2 / over ssh.
- **Patching from the repository:** edit under `mkosi/mkosi.extra/`, `./deploy-live.sh admin@host`, then restart `kid-session`. Packages, kernel command line, partitions and `mkosi.postinst` need a new image.
- **Updates:** Debian security updates with `sudo apt-get update && sudo apt-get upgrade` on the box. Chrome itself updates with a rebuilt image (the image deliberately does not add Google's apt repository on the box; add it yourself if you prefer in-place Chrome updates).
- **Logs:** `journalctl -b -u kid-session -u kids-sessiond`; Chrome's own output is tagged `kid-chrome`. A screenshot over ssh: `sudo -u kid XDG_RUNTIME_DIR=/run/user/1001 WAYLAND_DISPLAY=wayland-0 grim /tmp/shot.png`.

## Parental controls, honestly
- The PIN is a convenience gate against a younger sibling, not a security boundary: anyone with a screwdriver owns the box, and there is no verified boot yet.
- Chrome policies plus Family Link cover the browser. They do not cover the network: pair the box with a DNS filter you control (Pi-hole with a group for the child's device, NextDNS, your router's filter) — DNS-over-HTTPS is switched off in Chrome precisely so that filter is authoritative.
- The box never suspends and the admin can reach it at any time over ssh; nothing phones home anywhere except to Google through Chrome.

## Installing to an internal drive
On the box, from the running stick:

```
lsblk -o NAME,SIZE,PTTYPE,PARTTYPENAME,FSTYPE,LABEL    # find the target and, if any, the Windows disk
sudo kids-os-install /dev/sdX [--windows-disk /dev/sdY] --yes
```

- Erases `/dev/sdX` and lays down GPT: a 1 MiB BIOS boot partition, a 1 GiB `KIDSBOOT` boot filesystem (kernel, initrds, GRUB), an exact copy of the running root (4 GiB) and a data partition filling the rest; fstab is rewritten to `PARTUUID=` so the stick and the disk can coexist. The boot partition is typed as a plain Linux partition on purpose — some hybrid-EFI boards hijack any GPT disk carrying an EFI System Partition.
- `--windows-disk` adds a **Windows** menu entry for a BIOS/MBR Windows on another disk (GRUB finds its "System Reserved" partition, swaps BIOS drive numbers with `drivemap -s` as Debian's os-prober does, and chainloads it). A UEFI Windows cannot be chainloaded from BIOS GRUB — check `PTTYPE` first.
- Afterwards put that drive first in the BIOS boot order; the menu shows *Kids* and *Windows* for three seconds. The boot-menu key still reaches the stick and the other drives.
- Rehearse it first on your build host: `bash test-install.sh ~/kids-os-build/kids-os_<version>.raw` (see [`docs/development.md`](docs/development.md)).

## How it works
- **Disk (the image):** GPT — ESP 1 GiB (GRUB for EFI *and* BIOS, kernel, initrds) · BIOS boot 1 MiB · root 4 GiB ext4, fixed size · `kids-data`, pre-placed behind the root and grown to the medium by `systemd-repart` on first boot, mounted at `/data`. The data partition is capped at 32 GiB in `mkosi/mkosi.extra/usr/lib/repart.d/20-data.conf` as a guard against fake-capacity sticks; raise or remove the cap for media you trust.
- **Boot chain:** GRUB → Linux 6.12 → systemd `graphical.target` → `kids-os-session.service` (a oneshot running `session-select`) starts **either** `greeter-session.service` — user `greeter`, labwc + Chrome `--kiosk` on `login.html`, only while `/etc/kids-os/pin.hash` exists and `/run/kids-os/unlocked` does not — **or** `kid-session.service` — user `kid`, labwc + the waybar shelf + Chrome (`cage` + Chrome as the fallback if labwc dies within 20 s). The two session units `Conflicts=` each other; `ExecStopPost=loginctl terminate-user` keeps a restart clean. The box never suspends (`AllowSuspend=no`, `IdleAction=ignore`).
- **`kids-sessiond`** (root, Python, `127.0.0.1:7707`) serves the shell pages from `/usr/share/kids-os/shell/` and a small JSON API: `GET /api/config` · `POST /api/unlock {pin}` (pbkdf2 check with a failure delay; touches `/run/kids-os/unlocked`, starts the kid session) · `POST /api/launch {url}` (opens the URL in the kid's Chrome, closes the launcher) · `POST /api/signout` · `POST /api/power {poweroff|reboot}`.
- **Shell:** `labwc` with server decorations off and every window maximized (`/etc/kids-os/labwc/`), `waybar` as the shelf (`/etc/kids-os/waybar/`), `swaybg` for the wallpaper; the pages `login.html` (PIN pad, shut down / restart) and `launcher.html` (search + app grid, sign out, shut down). Design notes: [`shell/DESIGN.md`](shell/DESIGN.md).
- **Chrome:** Wayland (`--ozone-platform=wayland`), profile on `/data/kid/chrome`, device scale from `/etc/kids-os/kids-os.env`, enterprise policies in `/etc/opt/chrome/policies/managed/kids-os.json`.
- **Network:** NetworkManager (Wi-Fi profile baked at build time when configured), `systemd-resolved`, `systemd-timesyncd`.
- **Accounts:** the admin (your name; sudo without password, ssh keys from your configuration directory, console on tty2 with the password hash), `kid` (the session user: no password, no sudo, home on `/data/kid`), `greeter` (runs the sign-in page only). Root is locked.

## Repository layout
- `mkosi/` — the image: `mkosi.conf` (packages, kernel command line, GRUB for EFI + BIOS), `mkosi.repart/` (build-time partitions), `mkosi.extra/` (every file laid into the image: units, `usr/lib/kids-os/` scripts, shell pages, `etc/kids-os/` configuration, Chrome policies), `mkosi.sandbox/` (Chrome's apt source and key for the build), `mkosi.postinst` (users, services, per-family settings).
- `build.sh`, `setup-build-vm.sh`, `deploy-live.sh`, `lib/env.sh` — build, build-host setup, live patching, shared settings.
- `test-qemu.sh`, `qemu-mon.py`, `test-v1b.sh`, `test-install.sh` — the test bench ([`docs/development.md`](docs/development.md)).
- `tools/` — `write-usb-macos.sh` (write + verify a stick), `make-fake-windows-disk.sh` (for the installer rehearsal).
- `shell/` — design notes and the wallpaper generator · `docs/` — decisions, hardware notes, development, screenshots.

## Roadmap
1. Verified, read-only root (dm-verity) with A/B partitions and `systemd-sysupdate` from a server you control.
2. A pull-based agent (`kid-agent`) so the app list, policies and PIN follow a git repository.
3. Quick settings from the tray (volume, Wi-Fi picker), a boot splash, a real wallpaper.
4. NVIDIA's 580 driver branch as an option for 4K60 on Maxwell cards.

## License
MIT — see [`LICENSE`](LICENSE). Google Chrome is Google's; the image downloads it from Google's repository at build time under Google's terms.
