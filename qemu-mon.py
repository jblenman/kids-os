#!/usr/bin/env python3
"""Talk to the test VM's QEMU monitor: `shot` (PNG of the guest display), `quit`, or any raw monitor command."""
import pathlib, socket, subprocess, sys, time
WORK = pathlib.Path.home() / "kids-os-build" / "qemu"
cmd = sys.argv[1] if len(sys.argv) > 1 else "shot"
s = socket.socket(socket.AF_UNIX); s.settimeout(10); s.connect(str(WORK / "monitor.sock"))
time.sleep(0.3); s.recv(65536)
if cmd == "shot":
    ppm = WORK / f"shot-{int(time.time())}.ppm"; png = ppm.with_suffix(".png")
    s.sendall(f"screendump {ppm}\n".encode()); time.sleep(1.5)
    subprocess.run(["sips", "-s", "format", "png", str(ppm), "--out", str(png)], check=True, capture_output=True)
    ppm.unlink(); print(png)
else:
    s.sendall((" ".join(sys.argv[1:]) + "\n").encode()); time.sleep(0.5)
    print(s.recv(65536).decode(errors="replace"))
