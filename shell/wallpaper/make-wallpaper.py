#!/usr/bin/env python3
"""Write a 1920x1080 gradient PNG (no PIL needed) — the placeholder wallpaper until a real one is chosen."""
import struct, sys, zlib
W, H = 1920, 1080
top, bottom = (0x1a, 0x4f, 0x8a), (0x0b, 0x1f, 0x3a)   # deep blue → near-navy
rows = bytearray()
for y in range(H):
    t = y / (H - 1)
    r, g, b = (round(top[i] + (bottom[i] - top[i]) * t) for i in range(3))
    rows += b"\x00" + bytes((r, g, b)) * W
def chunk(tag, data): return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", zlib.crc32(tag + data) & 0xffffffff)
png = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", W, H, 8, 2, 0, 0, 0)) + chunk(b"IDAT", zlib.compress(bytes(rows), 9)) + chunk(b"IEND", b"")
open(sys.argv[1] if len(sys.argv) > 1 else "wallpaper.png", "wb").write(png)
