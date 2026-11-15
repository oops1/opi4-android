"""Android 16-style boot animation for the Orange Pi 4 build (original artwork).

Material 3 Expressive look: one shape that grows from a dot and keeps morphing between
a "cookie", a flower and a clover while it slowly turns, over a black screen, with an
"android 16" wordmark in Roboto (Apache 2.0, from external/roboto-fonts).

Writes bootanimation.zip (desc.txt + part0 intro + part1 loop, stored, PNG frames)
and preview.gif (scaled down) next to this script.

Usage: python make_bootanim.py [--preview-only]
"""
import io
import math
import os
import sys
import zipfile

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
W, H, FPS = 1920, 1080, 30
SS = 2                      # supersampling for smooth edges
INTRO, LOOP = 72, 150       # frames: 2.4 s intro, 5 s seamless loop
CX, CY = W // 2, H // 2 - 60
R = 150                     # base radius of the shape
FONT = os.path.join(HERE, "Roboto-Regular.ttf")

# Android green family, then teal and lime: (outer, inner) gradient stops
PALETTE = [
    ((61, 220, 132), (180, 245, 200)),
    ((32, 201, 178), (170, 240, 230)),
    ((150, 214, 74), (225, 245, 180)),
]

# Shape families blended in polar form: r = R * (1 + sum w_i * a_i * cos(k_i * theta))
SHAPES = [(9, 0.075), (6, 0.16), (4, 0.22)]   # cookie, flower, clover


def ease_out(x):
    return 1 - (1 - x) ** 3


def ease_in_out(x):
    return 0.5 - 0.5 * math.cos(math.pi * x)


def mix(c1, c2, t):
    return tuple(int(a + (b - a) * t) for a, b in zip(c1, c2))


def loop_weights(t):
    """Periodic weights over the 3 shapes, t in [0, 1): each shape peaks once per loop."""
    w = []
    for i in range(len(SHAPES)):
        d = (t - i / len(SHAPES)) % 1.0
        d = min(d, 1 - d) * len(SHAPES)          # 0 at the peak, 1.5 far away
        w.append(max(0.0, math.cos(min(d, 1.0) * math.pi / 2)) ** 2)
    s = sum(w) or 1.0
    return [x / s for x in w]


def loop_colors(t):
    n = len(PALETTE)
    x = (t * n) % n
    i, f = int(x), ease_in_out(x - int(x))
    a, b = PALETTE[i], PALETTE[(i + 1) % n]
    return mix(a[0], b[0], f), mix(a[1], b[1], f)


def shape_points(radius, weights, amount, rot, n=720):
    pts = []
    for j in range(n):
        th = 2 * math.pi * j / n
        k_sum = sum(w * a * math.cos(k * (th + rot)) for w, (k, a) in zip(weights, SHAPES))
        r = radius * (1 + amount * k_sum)
        pts.append(((CX + r * math.cos(th)) * SS, (CY + r * math.sin(th)) * SS))
    return pts


def render_shape(radius, weights, amount, rot, colors, glow):
    big = (W * SS, H * SS)
    mask = Image.new("L", big, 0)
    ImageDraw.Draw(mask).polygon(shape_points(radius, weights, amount, rot), fill=255)

    # radial gradient: inner colour in the middle, outer colour at the rim
    yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
    d = np.sqrt((xx - CX) ** 2 + (yy - CY) ** 2) / max(radius * 1.25, 1)
    d = np.clip(d, 0, 1)[..., None]
    outer, inner = np.array(colors[0], np.float32), np.array(colors[1], np.float32)
    grad = (inner * (1 - d) + outer * d).astype(np.uint8)
    fill = Image.fromarray(grad, "RGB")

    mask = mask.resize((W, H), Image.LANCZOS)
    frame = Image.new("RGB", (W, H), (0, 0, 0))
    if glow > 0:
        halo = mask.filter(ImageFilter.GaussianBlur(40)).point(lambda v: int(v * glow))
        frame = Image.composite(Image.new("RGB", (W, H), colors[0]), frame, halo)
    frame.paste(fill, (0, 0), mask)
    return frame


def draw_wordmark(frame, alpha):
    if alpha <= 0:
        return frame
    frame = frame.convert("RGBA")
    frame.alpha_composite(text_layer([("android", (232, 234, 237)), (" 16", (61, 220, 132))],
                                     1.0, alpha, CY + R + 160))
    return frame.convert("RGB")


def intro_frame(i):
    p = i / (INTRO - 1)
    grow = ease_out(min(1.0, p / 0.55))                 # dot -> full size
    morph = ease_in_out(max(0.0, (p - 0.35) / 0.65))    # circle -> loop start shape
    radius = 6 + (R - 6) * grow
    rot = 0.6 * (1 - morph)                              # settles into the loop's rotation
    frame = render_shape(radius, loop_weights(0.0), morph, rot, loop_colors(0.0), 0.35 * grow)
    return draw_wordmark(frame, ease_in_out(max(0.0, (p - 0.55) / 0.45)))


def loop_frame(i):
    t = i / LOOP
    rot = -2 * math.pi * t / 9                           # turns one cookie lobe per loop
    breathe = 1 + 0.03 * math.sin(2 * math.pi * t * 2)
    frame = render_shape(R * breathe, loop_weights(t), 1.0, rot, loop_colors(t), 0.35)
    return draw_wordmark(frame, 1.0)


OUTRO = 84                  # 2.8 s, played once after boot completes

ORANGE_RIM, ORANGE_MID, ORANGE_HI = (230, 105, 10), (255, 150, 30), (255, 214, 140)
LEAF_DARK, LEAF_LIGHT = (40, 160, 80), (120, 225, 140)
_rng = np.random.default_rng(16)
PEEL = Image.fromarray((_rng.random((H, W)) * 255).astype(np.uint8), "L").filter(
    ImageFilter.GaussianBlur(1.6))


def render_orange(radius, amount, rot, blend, leaf, glow, weights, colors):
    """Blob (blend=0) -> orange (blend=1): shape relaxes to a circle, colours turn orange,
    peel dimples and a highlight fade in, a leaf grows on top."""
    big = (W * SS, H * SS)
    mask = Image.new("L", big, 0)
    ImageDraw.Draw(mask).polygon(shape_points(radius, weights, amount, rot), fill=255)
    mask = mask.resize((W, H), Image.LANCZOS)

    yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
    # blob gradient (centred) and orange gradient (light from the top left)
    d_blob = np.clip(np.sqrt((xx - CX) ** 2 + (yy - CY) ** 2) / (radius * 1.25), 0, 1)[..., None]
    hx, hy = CX - radius * 0.35, CY - radius * 0.4
    d_or = np.clip(np.sqrt((xx - hx) ** 2 + (yy - hy) ** 2) / (radius * 1.9), 0, 1)[..., None]
    blob = np.array(colors[1], np.float32) * (1 - d_blob) + np.array(colors[0], np.float32) * d_blob
    o1 = np.array(ORANGE_HI, np.float32) * (1 - d_or) + np.array(ORANGE_MID, np.float32) * d_or
    o2 = np.array(ORANGE_MID, np.float32) * (1 - d_or) + np.array(ORANGE_RIM, np.float32) * d_or
    orange = np.where(d_or < 0.35, o1 + (o2 - o1) * (d_or / 0.35), o2)
    peel = (np.asarray(PEEL, np.float32)[..., None] / 255 - 0.5) * 34 * blend
    col = blob * (1 - blend) + orange * blend + peel
    fill = Image.fromarray(np.clip(col, 0, 255).astype(np.uint8), "RGB")

    frame = Image.new("RGB", (W, H), (0, 0, 0))
    glow_col = mix(colors[0], ORANGE_MID, blend)
    halo = mask.filter(ImageFilter.GaussianBlur(40)).point(lambda v: int(v * glow))
    frame = Image.composite(Image.new("RGB", (W, H), glow_col), frame, halo)
    frame.paste(fill, (0, 0), mask)

    if leaf > 0:
        layer = Image.new("RGBA", (W * SS, H * SS), (0, 0, 0, 0))
        ld = ImageDraw.Draw(layer)
        top = (CX * SS, (CY - radius * 0.96) * SS)
        # stem
        ld.line([top, (top[0] + 6 * SS, top[1] - 26 * SS * leaf)], fill=(110, 70, 30, 255),
                width=int(9 * SS))
        # leaf: lens shape leaning right, grows from the stem
        L, Wd = 110 * leaf * SS, 46 * leaf * SS
        base = (top[0] + 4 * SS, top[1] - 18 * SS * leaf)
        ang = math.radians(-28)
        pts = []
        for j in range(60):
            u = j / 59
            x, y = u * L, math.sin(math.pi * u) * Wd / 2
            pts.append((x, y))
        for j in range(60):
            u = 1 - j / 59
            x, y = u * L, -math.sin(math.pi * u) * Wd / 2
            pts.append((x, y))
        rot_pts = [(base[0] + x * math.cos(ang) - y * math.sin(ang),
                    base[1] + x * math.sin(ang) + y * math.cos(ang)) for x, y in pts]
        ld.polygon(rot_pts, fill=LEAF_DARK + (255,))
        half = rot_pts[:60] + [(base[0] + L * math.cos(ang), base[1] + L * math.sin(ang))]
        ld.polygon(half + [base], fill=LEAF_LIGHT + (255,))
        ld.line([base, (base[0] + L * 0.95 * math.cos(ang), base[1] + L * 0.95 * math.sin(ang))],
                fill=(30, 120, 60, 255), width=int(3 * SS))
        layer = layer.resize((W, H), Image.LANCZOS)
        frame = frame.convert("RGBA")
        frame.alpha_composite(layer)
        frame = frame.convert("RGB")
    return frame


def text_layer(parts, scale, alpha, y_center):
    """parts = [(text, rgb)], drawn as one line centred at (CX, y_center), scaled."""
    size = max(4, int(72 * scale))
    font = ImageFont.truetype(FONT, size)
    tmp = ImageDraw.Draw(Image.new("L", (1, 1)))
    widths = [tmp.textlength(t, font=font) for t, _ in parts]
    x = CX - sum(widths) / 2
    asc, desc = font.getmetrics()
    y = y_center - (asc + desc) / 2
    layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    ld = ImageDraw.Draw(layer)
    a = int(255 * max(0.0, min(1.0, alpha)))
    for (t, rgb), w in zip(parts, widths):
        ld.text((x, y), t, font=font, fill=rgb + (a,))
        x += w
    return layer


def outro_frame(i):
    p = i / (OUTRO - 1)
    m = ease_in_out(min(1.0, p / 0.7))                   # blob -> orange
    leaf = ease_out(max(0.0, (p - 0.45) / 0.4))
    frame = render_orange(R, 1.0 - m, 0.0, m, leaf, 0.35, loop_weights(0.0), loop_colors(0.0))

    text_y = CY + R + 160
    # "android 16" flies towards the viewer: grows fast and fades out
    f = min(1.0, p / 0.45)
    s_out = 1 + 5 * f ** 2.2
    a_out = 1 - ease_in_out(f)
    # "Orange Pi 4" comes out of the dark: from small and dim to full size
    g = ease_out(max(0.0, (p - 0.3) / 0.55))
    s_in, a_in = 0.25 + 0.75 * g, g
    frame = frame.convert("RGBA")
    if a_in > 0:
        frame.alpha_composite(text_layer([("Orange Pi", ORANGE_MID), (" 4", (232, 234, 237))],
                                         s_in, a_in, text_y))
    if a_out > 0:
        frame.alpha_composite(text_layer([("android", (232, 234, 237)), (" 16", (61, 220, 132))],
                                         s_out, a_out, text_y))
    return frame.convert("RGB")


def png_bytes(img):
    b = io.BytesIO()
    img.save(b, "PNG", optimize=True)
    return b.getvalue()


def main():
    preview_only = "--preview-only" in sys.argv
    frames = [("part0", i, intro_frame(i)) for i in range(INTRO)]
    frames += [("part1", i, loop_frame(i)) for i in range(LOOP)]
    frames += [("part2", i, outro_frame(i)) for i in range(OUTRO)]

    # preview: intro + one loop + outro + a 1 s hold of the last frame, 640x360
    small = [f.resize((640, 360), Image.LANCZOS) for _, _, f in frames]
    small += [small[-1]] * FPS
    small[0].save(os.path.join(HERE, "preview.gif"), save_all=True, append_images=small[1:],
                  duration=int(1000 / FPS), loop=0, optimize=True)
    frames[INTRO + LOOP // 3][2].save(os.path.join(HERE, "preview-still.png"))
    frames[INTRO + LOOP + OUTRO // 3][2].save(os.path.join(HERE, "preview-outro-mid.png"))
    frames[-1][2].save(os.path.join(HERE, "preview-outro-end.png"))
    print("preview.gif written")
    if preview_only:
        return

    out = os.path.join(HERE, "bootanimation.zip")
    with zipfile.ZipFile(out, "w", zipfile.ZIP_STORED) as z:
        # c = always play fully (intro), p = loop until boot completes
        # c = always played fully; p 0 = loop until boot completes; the final c part runs once
        # after boot completes (intro -> loop -> outro)
        z.writestr("desc.txt", f"{W} {H} {FPS}\nc 1 0 part0\np 0 0 part1\nc 1 0 part2\n")
        for part, i, img in frames:
            z.writestr(f"{part}/{i:05d}.png", png_bytes(img))
    print(out, os.path.getsize(out) // 1024, "KiB")


if __name__ == "__main__":
    main()
