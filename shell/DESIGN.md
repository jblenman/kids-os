# shell/ — the look (v1 design of 2026-10-16; v1b implemented 2026-10-18 — the pages ship from `mkosi/mkosi.extra/usr/share/kids-os/shell/`)

Goal: to a seven-year-old on a trackpad, daily use is indistinguishable from the ChromeOS Flex box it replaces — splash, a sign-in screen with his picture and a PIN pad, wallpaper with a bottom shelf, Chrome windows with Chrome's own frame. Chrome *is* Chrome; everything else is ours and small.

## Pieces
| Flex has | We build | How |
|---|---|---|
| Boot splash | `plymouth` with our own mark (not Google's logo) | quiet kernel + a two-colour theme |
| Sign-in: avatar + PIN pad | **greeter** = a Chrome kiosk window on `login.html` running as user `greeter` under `cage`; the PIN is checked by **`kids-sessiond`** (a small root service on a local socket) which then stops the greeter and starts `kid-session`. Lock = start the greeter again (idle timer, or a remote "lock"). | a convenience gate like ChromeOS's PIN, not a security boundary — anyone at the box is the admin |
| Wallpaper + shelf | `labwc` (wlroots, stacking, layer-shell) replaces `cage` for the kid session; `waybar` is the shelf: launcher button · pinned apps · tray (Wi-Fi, volume, clock); `swaybg` wallpaper | waybar CSS themed after the ChromeOS shelf |
| Launcher (search + app grid) | `launcher.html` in a Chrome app window toggled by the shelf button; lists the allowed web apps from `/etc/kids-os/config.json`; opens them as `google-chrome --app=URL` windows (ChromeOS-style app windows) or tabs | pure HTML/CSS/JS, no framework |
| Window frame | Chrome draws its own (`--ozone-platform=wayland`, system title bar off) | labwc: no server-side decorations, every window maximized, the shelf area reserved |
| Quick settings | tray clicks open a small `settings.html` (volume, Wi-Fi picker, brightness later) | v2 |
| Sign out / power | power menu in the launcher → `kids-sessiond` → `systemctl poweroff` / lock | |
| Keyboard | nothing bound for the kid except the keyboard's volume keys (`wpctl`) | Ctrl+Alt+F2 stays for the admin |

## Why this shape
- A web page is the natural material: ChromeOS's own sign-in/OOBE is WebUI, so fidelity comes cheap, and the pages read one JSON config that `kid-agent` (v3) will update from git.
- `labwc` + `waybar` over GNOME/KDE-with-a-theme: nothing for a kid to wander into, a few hundred lines of config, and every window maximized by rule.
- One privileged helper (`kids-sessiond`) instead of PAM/greetd machinery: the box has one child user and one admin; the PIN only guards against the younger sibling, not an attacker.

## Order of work
1. **v1a** — `labwc` + `waybar` shelf + `swaybg`, Chrome maximized, volume keys. One evening; usable by the child.
2. **v1b** — `launcher.html`, `kids-sessiond`, the PIN greeter, lock on idle. One or two evenings.
3. **v1c** — splash, scale factor for the TV (`--force-device-scale-factor`), polish from the reference screenshots.
