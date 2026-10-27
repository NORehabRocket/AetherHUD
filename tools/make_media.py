"""Generates AetherHUD's textures as 32-bit TGA (the format the 1.12 client reads from an
addon folder: uncompressed, top-left origin, power-of-two sizes) plus a PNG contact sheet
for previewing them. Pure Python, no dependencies.

    python make_media.py <addon media dir> [preview.png]
"""
import math
import os
import struct
import sys
import zlib

SS = 4  # supersampling factor for anti-aliased edges


class Canvas:
    def __init__(self, w, h):
        self.w, self.h = w, h
        # premultiplied-free RGBA floats 0..1
        self.px = [[0.0, 0.0, 0.0, 0.0] for _ in range(w * h)]

    def set(self, x, y, r, g, b, a):
        self.px[y * self.w + x] = [r, g, b, a]

    def get(self, x, y):
        return self.px[y * self.w + x]


def supersample(w, h, fn):
    """fn(u, v) -> (r, g, b, a) with u, v in pixel units of the final image."""
    c = Canvas(w, h)
    inv = 1.0 / (SS * SS)
    for y in range(h):
        for x in range(w):
            acc = [0.0, 0.0, 0.0, 0.0]
            for sy in range(SS):
                for sx in range(SS):
                    u = x + (sx + 0.5) / SS
                    v = y + (sy + 0.5) / SS
                    r, g, b, a = fn(u, v)
                    acc[0] += r * a
                    acc[1] += g * a
                    acc[2] += b * a
                    acc[3] += a
            a = acc[3] * inv
            if a > 0:
                c.set(x, y, acc[0] / acc[3], acc[1] / acc[3], acc[2] / acc[3], a)
            else:
                c.set(x, y, 1.0, 1.0, 1.0, 0.0)
    return c


def clamp(v, lo=0.0, hi=1.0):
    return lo if v < lo else hi if v > hi else v


def smooth(e0, e1, x):
    t = clamp((x - e0) / (e1 - e0))
    return t * t * (3 - 2 * t)


def write_tga(path, c):
    header = struct.pack("<BBBHHBHHHHBB", 0, 0, 2, 0, 0, 0, 0, 0, c.w, c.h, 32, 0x28)
    out = bytearray(header)
    for y in range(c.h):
        for x in range(c.w):
            r, g, b, a = c.get(x, y)
            out += bytes((int(clamp(b) * 255 + 0.5), int(clamp(g) * 255 + 0.5),
                          int(clamp(r) * 255 + 0.5), int(clamp(a) * 255 + 0.5)))
    with open(path, "wb") as f:
        f.write(out)


def write_png(path, w, h, rows):
    raw = bytearray()
    for row in rows:
        raw.append(0)
        for r, g, b in row:
            raw += bytes((r, g, b))

    def chunk(tag, data):
        body = tag + data
        return struct.pack(">I", len(data)) + body + struct.pack(">I", zlib.crc32(body) & 0xFFFFFFFF)

    png = b"\x89PNG\r\n\x1a\n"
    png += chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 2, 0, 0, 0))
    png += chunk(b"IDAT", zlib.compress(bytes(raw), 9))
    png += chunk(b"IEND", b"")
    with open(path, "wb") as f:
        f.write(png)


# ---------------------------------------------------------------- textures

def tex_bar():
    # Glossy bar fill: grey ramp (lighter on top), a soft highlight band and a darker foot.
    def fn(u, v):
        y = v / 32.0
        val = 0.62 + 0.22 * (1 - y)
        val += 0.20 * math.exp(-((y - 0.22) / 0.10) ** 2)
        val -= 0.18 * smooth(0.78, 1.0, y)
        if v < 1.0:
            val = 1.0
        return (val, val, val, 1.0)
    return supersample(256, 32, fn)


def tex_glow():
    def fn(u, v):
        dx, dy = (u - 32) / 32.0, (v - 32) / 32.0
        r = math.sqrt(dx * dx + dy * dy)
        a = clamp(1 - r) ** 2.2
        return (1, 1, 1, a)
    return supersample(64, 64, fn)


def tex_ring():
    # Portrait bezel: the hole fits a round 2D portrait; grey so the addon tints it.
    rin, rout = 53.0, 62.0

    def fn(u, v):
        dx, dy = u - 64, v - 64
        r = math.sqrt(dx * dx + dy * dy)
        if r < rin - 1.6 or r > rout + 1.6:
            return (1, 1, 1, 0)
        ang = math.atan2(dx, -dy)  # 0 at top
        light = 0.62 + 0.38 * math.cos(ang)
        if r < rin:  # dark seam against the portrait
            a = smooth(rin - 1.6, rin - 0.4, r)
            return (0.05, 0.05, 0.06, 0.85 * a)
        if r > rout:  # dark outer seam
            a = 1 - smooth(rout + 0.4, rout + 1.6, r)
            return (0.02, 0.02, 0.03, 0.9 * a)
        t = (r - rin) / (rout - rin)
        prof = 0.55 + 0.45 * math.exp(-((t - 0.18) / 0.16) ** 2) + 0.25 * math.exp(-((t - 0.85) / 0.10) ** 2)
        val = clamp(prof * light + 0.08)
        return (val, val, val, 1)
    return supersample(128, 128, fn)


def tex_diamond():
    def fn(u, v):
        d = abs(u - 16) + abs(v - 16)
        a = 1 - smooth(13.2, 14.6, d)
        val = 1.0 - 0.28 * (v / 32.0)
        if d > 11.5:  # bright rim
            val = min(1.0, val + 0.15)
        return (val, val, val, a)
    return supersample(32, 32, fn)


def tex_diamond_outline():
    def fn(u, v):
        d = abs(u - 16) + abs(v - 16)
        a = smooth(10.6, 11.8, d) * (1 - smooth(13.4, 14.6, d))
        return (1, 1, 1, a)
    return supersample(32, 32, fn)


def tex_line():
    def fn(u, v):
        x = u / 256.0
        y = v / 8.0
        a = clamp(1 - abs(2 * x - 1)) ** 1.4 * clamp(1 - abs(2 * y - 1)) ** 1.2
        return (1, 1, 1, a)
    return supersample(256, 8, fn)


def tex_vignette():
    def fn(u, v):
        dx, dy = (u - 128) / 128.0, (v - 128) / 128.0
        r = math.sqrt(dx * dx + dy * dy) / math.sqrt(2) * 1.25
        a = smooth(0.62, 1.12, r) ** 1.3
        return (1, 1, 1, a)
    # vignette is soft: no need for heavy supersampling
    global SS
    old, SS = SS, 1
    try:
        return supersample(256, 256, fn)
    finally:
        SS = old


def tex_slot():
    # Beveled socket frame for skill icons; the icon sits inside the inner ~84%.
    def fn(u, v):
        x, y = u, v
        edge = min(x, y, 64 - x, 64 - y)
        if edge > 6.5:
            return (1, 1, 1, 0)
        if edge < 1.6:  # outer black rim
            return (0.0, 0.0, 0.0, 0.95)
        if edge > 5.4:  # inner dark seam
            return (0.02, 0.02, 0.03, 0.9 * (1 - smooth(6.0, 6.5, edge)))
        # bevel: lit from top-left
        side_top = y < 64 - y and y <= x and y <= 64 - x
        side_left = x < 64 - x and x < y and x <= 64 - y
        side_right = (64 - x) < x and (64 - x) < y and (64 - x) <= (64 - y)
        if side_top:
            val = 1.0
        elif side_left:
            val = 0.86
        elif side_right:
            val = 0.56
        else:
            val = 0.44
        t = (edge - 1.6) / 3.8
        val *= 0.8 + 0.3 * math.exp(-((t - 0.3) / 0.25) ** 2)
        return (clamp(val), clamp(val), clamp(val), 1.0)
    return supersample(64, 64, fn)


def tex_wing():
    # Banner wing pointing left: five tapered, fanned feathers. Mirrored by texcoords for the right side.
    W, H = 256, 64
    big_w, big_h = W * SS, H * SS
    alpha = [0.0] * (big_w * big_h)
    feathers = []
    for k in range(5):
        tip = (6 + 26 * k, 12 + 9.5 * k)
        root = (250, 34 + k * 1.2)
        ctrl = (150 - 8 * k, 30 + k * 4)
        feathers.append((root, ctrl, tip, 1.0 - 0.12 * k))
    for root, ctrl, tip, strength in feathers:
        steps = 700
        for i in range(steps + 1):
            t = i / steps
            x = (1 - t) ** 2 * root[0] + 2 * (1 - t) * t * ctrl[0] + t * t * tip[0]
            y = (1 - t) ** 2 * root[1] + 2 * (1 - t) * t * ctrl[1] + t * t * tip[1]
            rad = (2.6 * (1 - t) ** 0.85 + 0.35) * SS
            a0 = strength * (1 - 0.7 * t)
            cx, cy = x * SS, y * SS
            x0, x1 = int(cx - rad - 1), int(cx + rad + 1)
            y0, y1 = int(cy - rad - 1), int(cy + rad + 1)
            for py in range(max(0, y0), min(big_h, y1 + 1)):
                for px in range(max(0, x0), min(big_w, x1 + 1)):
                    d = math.hypot(px + 0.5 - cx, py + 0.5 - cy)
                    if d <= rad:
                        a = a0 * (1 - smooth(rad - SS * 0.8, rad, d))
                        idx = py * big_w + px
                        if a > alpha[idx]:
                            alpha[idx] = a
    c = Canvas(W, H)
    inv = 1.0 / (SS * SS)
    for y in range(H):
        for x in range(W):
            s = 0.0
            for sy in range(SS):
                row = (y * SS + sy) * big_w + x * SS
                for sx in range(SS):
                    s += alpha[row + sx]
            c.set(x, y, 1, 1, 1, s * inv)
    return c


TEXTURES = [
    ("bar", tex_bar),
    ("glow", tex_glow),
    ("ring", tex_ring),
    ("diamond", tex_diamond),
    ("diamondo", tex_diamond_outline),
    ("line", tex_line),
    ("vignette", tex_vignette),
    ("slot", tex_slot),
    ("wing", tex_wing),
]


def contact_sheet(path, made):
    pad = 12
    scale = 2
    width = max(c.w for _, c in made) * scale + pad * 2
    height = sum(c.h * scale + pad for _, c in made) + pad
    bg = (14, 22, 34)
    rows = [[bg] * width for _ in range(height)]
    y0 = pad
    for _, c in made:
        for y in range(c.h * scale):
            for x in range(c.w * scale):
                r, g, b, a = c.get(x // scale, y // scale)
                # tint grey textures gold for the preview
                tr, tg, tb = r * 1.0, g * 0.82, b * 0.45
                px = rows[y0 + y][pad + x]
                rows[y0 + y][pad + x] = tuple(int(clamp(p / 255.0 * (1 - a) + t * a) * 255)
                                              for p, t in zip(px, (tr, tg, tb)))
        y0 += c.h * scale + pad
    write_png(path, width, height, rows)


def main():
    out = sys.argv[1]
    os.makedirs(out, exist_ok=True)
    made = []
    for name, fn in TEXTURES:
        c = fn()
        write_tga(os.path.join(out, name + ".tga"), c)
        made.append((name, c))
        print("wrote", name, c.w, "x", c.h)
    if len(sys.argv) > 2:
        contact_sheet(sys.argv[2], made)
        print("preview", sys.argv[2])


if __name__ == "__main__":
    main()
