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


# ---------------------------------------------------------------- TV variant outro
OUTRO_TV = 132              # 4.4 s
TV_A, TV_B = 1.5 * R, 1.02 * R     # half width / half height of the TV body
SCREEN = (24, 26, 30)


def superellipse_points(a, b, n, cx=None, cy=None, count=720):
    cx = CX if cx is None else cx
    cy = CY if cy is None else cy
    pts = []
    for j in range(count):
        th = 2 * math.pi * j / count
        c, s = math.cos(th), math.sin(th)
        x = a * math.copysign(abs(c) ** (2 / n), c)
        y = b * math.copysign(abs(s) ** (2 / n), s)
        pts.append(((cx + x) * SS, (cy + y) * SS))
    return pts


def render_tv(t, glow=0.35):
    """Orange (t=0) -> stylised orange TV (t=1): the sphere stretches into a rounded
    box, the peel turns to smooth plastic, a dark screen opens, the leaf gives way to
    antennas and two little legs grow."""
    e = ease_in_out(t)
    a, b = R + (TV_A - R) * e, R + (TV_B - R) * e
    n = 2 + 3.5 * e
    big = (W * SS, H * SS)
    mask = Image.new("L", big, 0)
    ImageDraw.Draw(mask).polygon(superellipse_points(a, b, n), fill=255)
    mask = mask.resize((W, H), Image.LANCZOS)

    yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
    hx, hy = CX - a * 0.35, CY - b * 0.4
    d_or = np.clip(np.sqrt((xx - hx) ** 2 + (yy - hy) ** 2) / (max(a, b) * 1.9), 0, 1)[..., None]
    o1 = np.array(ORANGE_HI, np.float32) * (1 - d_or) + np.array(ORANGE_MID, np.float32) * d_or
    o2 = np.array(ORANGE_MID, np.float32) * (1 - d_or) + np.array(ORANGE_RIM, np.float32) * d_or
    col = np.where(d_or < 0.35, o1 + (o2 - o1) * (d_or / 0.35), o2)
    col = col + (np.asarray(PEEL, np.float32)[..., None] / 255 - 0.5) * 34 * (1 - e)
    fill = Image.fromarray(np.clip(col, 0, 255).astype(np.uint8), "RGB")

    frame = Image.new("RGB", (W, H), (0, 0, 0))
    halo = mask.filter(ImageFilter.GaussianBlur(40)).point(lambda v: int(v * glow))
    frame = Image.composite(Image.new("RGB", (W, H), ORANGE_MID), frame, halo)
    frame.paste(fill, (0, 0), mask)

    layer = Image.new("RGBA", big, (0, 0, 0, 0))
    ld = ImageDraw.Draw(layer)
    # leaf and stem shrink away during the first half
    leaf = max(0.0, 1 - e * 2)
    # screen
    sc = ease_out(max(0.0, (t - 0.35) / 0.65))
    if sc > 0:
        sa, sb = a * 0.80 * sc, b * 0.72 * sc
        ld.polygon(superellipse_points(sa, sb, 5.0, CX - a * 0.06, CY), fill=SCREEN + (255,))
        # glare stripe on the glass
        gx, gy = (CX - a * 0.06) * SS, CY * SS
        ld.polygon([(gx - sa * 0.75 * SS, gy - sb * 0.55 * SS), (gx - sa * 0.35 * SS, gy - sb * 0.85 * SS),
                    (gx - sa * 0.15 * SS, gy - sb * 0.85 * SS), (gx - sa * 0.65 * SS, gy - sb * 0.35 * SS)],
                   fill=mix(SCREEN, (95, 100, 110), sc) + (255,))   # solid: RGBA draw replaces pixels
        # two knobs on the right
        for k, ky in enumerate((-0.25, 0.2)):
            r = 11 * sc * SS
            kx, kyy = (CX + a * 0.86) * SS, (CY + b * ky) * SS
            ld.ellipse([kx - r, kyy - r, kx + r, kyy + r], fill=(120, 55, 5, 255))
    # antennas grow from the top
    an = ease_out(max(0.0, (t - 0.45) / 0.55))
    if an > 0:
        top = (CX * SS, (CY - b) * SS)
        for ang in (-35, 32):
            rad = math.radians(-90 + ang)
            L = 115 * an * SS
            end = (top[0] + L * math.cos(rad), top[1] + L * math.sin(rad))
            ld.line([top, end], fill=(70, 70, 75, 255), width=int(6 * SS))
            r = 9 * an * SS
            ld.ellipse([end[0] - r, end[1] - r, end[0] + r, end[1] + r], fill=ORANGE_MID + (255,))
        r = 16 * an * SS
        ld.pieslice([top[0] - r, top[1] - r, top[0] + r, top[1] + r], 180, 360, fill=(70, 70, 75, 255))
        # legs
        for sx in (-1, 1):
            x0, y0 = (CX + sx * a * 0.55) * SS, (CY + b * 0.97) * SS
            ld.line([(x0, y0), (x0 + sx * 18 * an * SS, y0 + 30 * an * SS)], fill=(70, 70, 75, 255),
                    width=int(8 * SS))
    layer = layer.resize((W, H), Image.LANCZOS)
    frame = frame.convert("RGBA")
    frame.alpha_composite(layer)
    return frame.convert("RGB"), leaf


# hand-written "TV": strokes in a unit box (x right, y down), drawn in this order
TV_STROKES = [
    [(0.02, 0.10), (0.20, 0.06), (0.40, 0.04), (0.56, 0.05)],                 # T bar
    [(0.29, 0.06), (0.30, 0.40), (0.28, 0.75), (0.26, 1.00)],                 # T stem
    [(0.56, 0.08), (0.64, 0.45), (0.72, 0.80), (0.77, 1.00),
     (0.84, 0.70), (0.92, 0.35), (1.00, 0.02)],                               # V
]


def _smooth(points, steps=24):
    """Catmull-Rom through the control points -> dense polyline."""
    pts = [points[0]] + points + [points[-1]]
    out = []
    for i in range(1, len(pts) - 2):
        p0, p1, p2, p3 = pts[i - 1], pts[i], pts[i + 1], pts[i + 2]
        for s in range(steps):
            u = s / steps
            u2, u3 = u * u, u * u * u
            out.append(tuple(0.5 * ((2 * p1[k]) + (-p0[k] + p2[k]) * u +
                                    (2 * p0[k] - 5 * p1[k] + 4 * p2[k] - p3[k]) * u2 +
                                    (-p0[k] + 3 * p1[k] - 3 * p2[k] + p3[k]) * u3) for k in (0, 1)))
    out.append(points[-1])
    return out


def handwriting_layer(progress, x0, y0, h, color):
    """Draw the first `progress` (0..1) of the TV strokes, as if written with a brush."""
    w = h * 1.05
    polys = [[(x0 + x * w, y0 + y * h) for x, y in _smooth(s)] for s in TV_STROKES]
    lens = [sum(math.dist(p[i], p[i + 1]) for i in range(len(p) - 1)) for p in polys]
    total, left = sum(lens), progress * sum(lens)
    layer = Image.new("RGBA", (W * SS, H * SS), (0, 0, 0, 0))
    ld = ImageDraw.Draw(layer)
    width = h * 0.13
    for poly, ln in zip(polys, lens):
        if left <= 0:
            break
        acc, pts = 0.0, [poly[0]]
        for i in range(len(poly) - 1):
            seg = math.dist(poly[i], poly[i + 1])
            if acc + seg >= left:
                f = (left - acc) / seg
                pts.append((poly[i][0] + (poly[i + 1][0] - poly[i][0]) * f,
                            poly[i][1] + (poly[i + 1][1] - poly[i][1]) * f))
                break
            acc += seg
            pts.append(poly[i + 1])
        sp = [(x * SS, y * SS) for x, y in pts]
        for i, (x, y) in enumerate(sp):        # brush: round dabs, slightly thicker mid-stroke
            k = i / max(1, len(sp) - 1)
            r = width * SS * (0.75 + 0.35 * math.sin(math.pi * k)) / 2
            ld.ellipse([x - r, y - r, x + r, y + r], fill=color + (255,))
        if len(sp) > 1:
            ld.line(sp, fill=color + (255,), width=int(width * SS * 0.8), joint="curve")
        left -= ln
    return layer.resize((W, H), Image.LANCZOS)


def outro_tv_frame(i):
    fr = i
    # 0..30: blob -> orange, "android 16" flies out, "Orange Pi 4" appears (by frame ~36)
    # 36..70: orange -> TV;  66..104: "TV" is written (a second after "Orange Pi 4");  hold
    text_y = CY + R + 160
    big_h = 150
    font = ImageFont.truetype(FONT, 72)
    opi_w = ImageDraw.Draw(Image.new("L", (1, 1))).textlength("Orange Pi 4", font=font)
    tv_w = big_h * 1.05
    gap = 34
    shift = -(tv_w + gap) / 2                      # keep "Orange Pi 4" + "TV" centred

    m = ease_in_out(min(1.0, fr / 30))
    if fr < 36:
        leaf = ease_out(min(1.0, max(0.0, (fr - 10) / 24)))
        frame = render_orange(R, 1.0 - m, 0.0, m, leaf, 0.35, loop_weights(0.0), loop_colors(0.0))
    else:
        t = min(1.0, (fr - 36) / 34)
        leaf = max(0.0, 1 - ease_in_out(t) * 2.2)
        frame = render_orange(R, 0.0, 0.0, 1.0, leaf, 0.35, loop_weights(0.0), loop_colors(0.0)) \
            if t <= 0 else render_tv(t)[0]
        if leaf > 0 and t > 0:
            # let the leaf fade out over the morphing body
            orange_leaf = render_orange(R, 0.0, 0.0, 1.0, 1.0, 0.35, loop_weights(0.0), loop_colors(0.0))
            lm = Image.new("L", (W, H), 0)
            ImageDraw.Draw(lm).rectangle([CX - 40, CY - R - 120, CX + 160, CY - R + 2], fill=int(255 * leaf))
            frame = Image.composite(orange_leaf, frame, lm)

    frame = frame.convert("RGBA")
    f = min(1.0, fr / 13.5)
    if f < 1:
        frame.alpha_composite(text_layer([("android", (232, 234, 237)), (" 16", (61, 220, 132))],
                                         1 + 5 * f ** 2.2, 1 - ease_in_out(f), text_y))
    g = ease_out(min(1.0, max(0.0, (fr - 9) / 27)))
    if g > 0:
        lay = text_layer([("Orange Pi", ORANGE_MID), (" 4", (232, 234, 237))], 0.25 + 0.75 * g, g, text_y)
        frame.alpha_composite(lay.transform(lay.size, Image.AFFINE, (1, 0, -shift * g, 0, 1, 0)))
    hw = min(1.0, max(0.0, (fr - 66) / 38))
    if hw > 0:
        x0 = CX + opi_w / 2 + shift + gap
        frame.alpha_composite(handwriting_layer(ease_in_out(hw), x0, text_y - big_h * 0.62, big_h,
                                                (255, 170, 60)))
    return frame.convert("RGB")


def png_bytes(img):
    b = io.BytesIO()
    img.save(b, "PNG", optimize=True)
    return b.getvalue()


def write_kernel_logo(path):
    """Boot logo for fbcon (shown centred from DRM init until SurfaceFlinger takes over):
    the last intro frame, cropped symmetrically around the screen centre so it lines up
    with the animation, reduced to <= 224 colours as pnmtologo requires (plain PPM)."""
    lw, lh = 720, 600
    box = (W // 2 - lw // 2, H // 2 - lh // 2, W // 2 + lw // 2, H // 2 + lh // 2)
    img = intro_frame(INTRO - 1).crop(box)
    img = img.quantize(colors=223, dither=Image.Dither.NONE).convert("RGB")
    px = np.asarray(img).reshape(-1)
    with open(path, "w") as f:
        f.write(f"P3\n# Orange Pi 4 boot logo (make_bootanim.py)\n{lw} {lh}\n255\n")
        for i in range(0, len(px), 24):
            f.write(" ".join(map(str, px[i:i + 24])) + "\n")
    print(path, "colours:", len(set(map(tuple, np.asarray(img).reshape(-1, 3)))))


def main():
    if "--kernel-logo" in sys.argv:
        write_kernel_logo(os.path.join(HERE, "logo_linux_clut224.ppm"))
        return
    preview_only = "--preview-only" in sys.argv
    tv = "--tv" in sys.argv
    sfx = "-tv" if tv else ""
    frames = [("part0", i, intro_frame(i)) for i in range(INTRO)]
    frames += [("part1", i, loop_frame(i)) for i in range(LOOP)]
    if tv:
        frames += [("part2", i, outro_tv_frame(i)) for i in range(OUTRO_TV)]
    else:
        frames += [("part2", i, outro_frame(i)) for i in range(OUTRO)]
    n_out = OUTRO_TV if tv else OUTRO

    # preview: intro + one loop + outro + a 1 s hold of the last frame, 640x360
    small = [f.resize((640, 360), Image.LANCZOS) for _, _, f in frames]
    small += [small[-1]] * FPS
    small[0].save(os.path.join(HERE, f"preview{sfx}.gif"), save_all=True, append_images=small[1:],
                  duration=int(1000 / FPS), loop=0, optimize=True)
    frames[INTRO + LOOP // 3][2].save(os.path.join(HERE, f"preview{sfx}-still.png"))
    frames[INTRO + LOOP + n_out // 2][2].save(os.path.join(HERE, f"preview{sfx}-outro-mid.png"))
    frames[-1][2].save(os.path.join(HERE, f"preview{sfx}-outro-end.png"))
    print(f"preview{sfx}.gif written")
    if preview_only:
        return

    out = os.path.join(HERE, f"bootanimation{sfx}.zip")
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
