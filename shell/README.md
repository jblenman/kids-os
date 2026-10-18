# shell/ — the web UI of the OS

The pages themselves ship inside the image from `mkosi/mkosi.extra/usr/share/kids-os/shell/` (`login.html` = sign-in/PIN screen, `launcher.html` = search + app grid, sign out, shut down) and are served by `kids-sessiond`. This directory holds the design notes (`DESIGN.md`) and the wallpaper generator (`wallpaper/make-wallpaper.py`).
