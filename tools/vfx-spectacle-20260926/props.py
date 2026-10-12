"""Solid props for the spectacle layer (2026-10-07).

The user on 170.14: 你很多这些一条条的 -- every spell body was a band along a path.
These are objects instead: tarot cards (front, back), a wax seal, a wax splash, a wax
drop, mirror shards, a name card (front, back), and for every other spell identity
(2026-10-07 night, all 98 rows): crystals, ink, water, feathers, petals, weapons, chain
links, meteors, coins, bolts, a paw, a dragon, a mask, rocks, a crater, a phoenix, a page
and a sword-qi crescent. Most later cells are drawn in light greys so the identity's
colour (vertex tint) gives the hue; weapons, the dragon and the phoenix keep their own.
They tumble in 3D in Unity (SpectacleProp.shader).

Plain PIL, no numpy. Each cell is drawn at 4x and reduced. Output: 2048x2048, an 8x8
grid of 256 px cells, in the order of main(); SpellSpectacle20260926.PropCell mirrors it.

usage: python3 props.py <out.png>
"""
import math
import random
import sys

from PIL import Image, ImageChops, ImageDraw, ImageFilter

CELL = 256
K = 4                      # supersampling
C = CELL * K

GOLD = (236, 184, 76)
GOLD_LIGHT = (252, 222, 140)
GOLD_DARK = (150, 98, 30)


def canvas():
    return Image.new("RGBA", (C, C), (0, 0, 0, 0))


def vgradient(size, top, bottom):
    w, h = size
    g = Image.new("RGBA", (1, h))
    for y in range(h):
        t = y / max(1, h - 1)
        g.putpixel((0, y), tuple(int(top[i] + (bottom[i] - top[i]) * t) for i in range(3)) + (255,))
    return g.resize((w, h))


def paste_masked(base, layer, mask):
    base.paste(layer, (0, 0), mask)


def rounded_mask(box, r):
    m = Image.new("L", (C, C), 0)
    ImageDraw.Draw(m).rounded_rectangle(box, r, fill=255)
    return m


def star4(d, cx, cy, r, fill, thin=.22):
    pts = []
    for k in range(8):
        a = math.pi / 2 + k * math.pi / 4
        rr = r if k % 2 == 0 else r * thin
        pts.append((cx + math.cos(a) * rr, cy - math.sin(a) * rr))
    d.polygon(pts, fill=fill)


def crescent(img, cx, cy, r, color, cut=(0.42, -0.18)):
    m = Image.new("L", (C, C), 0)
    d = ImageDraw.Draw(m)
    d.ellipse((cx - r, cy - r, cx + r, cy + r), fill=255)
    ox, oy = cx + r * cut[0], cy + r * cut[1]
    d.ellipse((ox - r * .9, oy - r * .9, ox + r * .9, oy + r * .9), fill=0)
    img.paste(Image.new("RGBA", (C, C), color + (255,)), (0, 0), m)


def glow(img, cx, cy, r, color, alpha):
    g = Image.new("RGBA", (C, C), (0, 0, 0, 0))
    ImageDraw.Draw(g).ellipse((cx - r, cy - r, cx + r, cy + r), fill=color + (alpha,))
    g = g.filter(ImageFilter.GaussianBlur(r * .45))
    return Image.alpha_composite(img, g)


def finish(img):
    return img.resize((CELL, CELL), Image.LANCZOS)


# ------------------------------------------------------------------ cards

CARD = (212, 22, 812, 1002)


def tarot_front():
    img = canvas()
    mask = rounded_mask(CARD, 54)
    paste_masked(img, vgradient((C, C), (58, 22, 104), (16, 6, 40)), mask)
    img = glow(img, 512, 470, 260, (140, 80, 255), 150)
    img.putalpha(ImageChops.multiply(img.getchannel("A"), mask))
    d = ImageDraw.Draw(img)
    x0, y0, x1, y1 = CARD
    d.rounded_rectangle(CARD, 54, outline=GOLD, width=26)
    d.rounded_rectangle((x0 + 50, y0 + 50, x1 - 50, y1 - 50), 30, outline=GOLD_LIGHT, width=7)
    crescent(img, 512, 470, 150, GOLD)
    star4(d, 512, 250, 70, GOLD_LIGHT)
    rnd = random.Random(7)
    for _ in range(14):
        sx, sy = rnd.uniform(x0 + 90, x1 - 90), rnd.uniform(y0 + 110, y1 - 260)
        if math.hypot(sx - 512, sy - 470) < 190:
            continue
        star4(d, sx, sy, rnd.uniform(10, 22), GOLD_LIGHT)
    d.rounded_rectangle((x0 + 90, y1 - 190, x1 - 90, y1 - 110), 22, fill=(40, 14, 70), outline=GOLD, width=9)
    for k in range(3):
        cx = 512 + (k - 1) * 110
        d.ellipse((cx - 11, y1 - 161, cx + 11, y1 - 139), fill=GOLD_LIGHT)
    return finish(img)


def tarot_back():
    img = canvas()
    mask = rounded_mask(CARD, 54)
    paste_masked(img, vgradient((C, C), (24, 20, 74), (8, 8, 30)), mask)
    d = ImageDraw.Draw(img)
    x0, y0, x1, y1 = CARD
    d.rounded_rectangle(CARD, 54, outline=GOLD, width=26)
    d.rounded_rectangle((x0 + 50, y0 + 50, x1 - 50, y1 - 50), 30, outline=GOLD_DARK, width=7)
    star4(d, 512, 512, 210, GOLD, .18)
    star4(d, 512, 512, 120, GOLD_LIGHT, .3)
    d.ellipse((512 - 34, 512 - 34, 512 + 34, 512 + 34), fill=(24, 20, 74))
    d.ellipse((512 - 16, 512 - 16, 512 + 16, 512 + 16), fill=GOLD_LIGHT)
    for sx, sy in ((512, 190), (512, 834), (330, 512), (694, 512)):
        star4(d, sx, sy, 30, GOLD_LIGHT)
    return finish(img)


NAME = (90, 230, 934, 794)


def name_front():
    img = canvas()
    mask = rounded_mask(NAME, 40)
    paste_masked(img, vgradient((C, C), (246, 236, 208), (222, 204, 160)), mask)
    d = ImageDraw.Draw(img)
    x0, y0, x1, y1 = NAME
    d.rounded_rectangle(NAME, 40, outline=GOLD_DARK, width=22)
    d.rounded_rectangle((x0 + 40, y0 + 40, x1 - 40, y1 - 40), 24, outline=(176, 136, 70), width=6)
    # Portrait silhouette on the left.
    d.ellipse((170, 340, 400, 690), fill=(88, 64, 52))
    d.ellipse((220, 360, 350, 500), fill=(120, 92, 74))
    # A name written in ink: uneven strokes, not text.
    rnd = random.Random(3)
    ink = (52, 30, 24)
    for row, (ya, length) in enumerate(((410, 440), (520, 380), (620, 300))):
        pts = []
        for k in range(28):
            x = 450 + length * k / 27
            pts.append((x, ya + math.sin(k * 1.7 + row) * 16 + rnd.uniform(-6, 6)))
        d.line(pts, fill=ink, width=16 if row == 0 else 10, joint="curve")
    # Red wax dot in the corner.
    d.ellipse((790, 600, 880, 690), fill=(170, 26, 34))
    d.ellipse((806, 612, 840, 646), fill=(214, 70, 64))
    return finish(img)


def name_back():
    img = canvas()
    mask = rounded_mask(NAME, 40)
    paste_masked(img, vgradient((C, C), (110, 24, 46), (60, 10, 26)), mask)
    d = ImageDraw.Draw(img)
    x0, y0, x1, y1 = NAME
    d.rounded_rectangle(NAME, 40, outline=GOLD, width=22)
    d.rounded_rectangle((x0 + 40, y0 + 40, x1 - 40, y1 - 40), 24, outline=GOLD_DARK, width=6)
    crescent(img, 512, 512, 130, GOLD, (.4, -.1))
    star4(ImageDraw.Draw(img), 560, 470, 46, GOLD_LIGHT)
    return finish(img)


# ------------------------------------------------------------------ wax

WAX = (150, 16, 26)
WAX_LIGHT = (214, 52, 50)
WAX_DARK = (84, 6, 14)


def blob_polygon(cx, cy, r, rnd, n=72, wobble=.07, lobes=5):
    ph = rnd.uniform(0, 6.28)
    pts = []
    for k in range(n):
        a = k / n * 2 * math.pi
        rr = r * (1 + wobble * math.sin(a * lobes + ph) + wobble * .6 * math.sin(a * 11 + ph * 2) + rnd.uniform(-.015, .015))
        pts.append((cx + math.cos(a) * rr, cy + math.sin(a) * rr))
    return pts


def wax_seal():
    rnd = random.Random(11)
    img = canvas()
    d = ImageDraw.Draw(img)
    # Drips squeezed out under the stamp.
    for k in range(7):
        a = rnd.uniform(0, 6.28)
        r = rnd.uniform(380, 440)
        cx, cy = 512 + math.cos(a) * r, 512 + math.sin(a) * r
        rr = rnd.uniform(40, 70)
        d.ellipse((cx - rr, cy - rr, cx + rr, cy + rr), fill=WAX_DARK + (255,))
    d.polygon(blob_polygon(512, 512, 420, rnd), fill=WAX + (255,))
    d.polygon(blob_polygon(512, 512, 330, rnd, wobble=.03), fill=WAX_LIGHT + (255,))
    d.polygon(blob_polygon(512, 512, 300, rnd, wobble=.02), fill=(176, 28, 36, 255))
    # Embossed sigil: light offset up-left, shadow down-right, face in between.
    for off, col in (((10, 10), WAX_DARK), ((-8, -8), (238, 110, 96)), ((0, 0), (190, 36, 40))):
        layer = canvas()
        crescent(layer, 512 + off[0], 540 + off[1], 150, col)
        star4(ImageDraw.Draw(layer), 512 + off[0], 330 + off[1], 70, col + (255,))
        img = Image.alpha_composite(img, layer)
    # Gloss.
    hl = canvas()
    ImageDraw.Draw(hl).ellipse((250, 210, 520, 380), fill=(255, 230, 220, 120))
    img = Image.alpha_composite(img, hl.filter(ImageFilter.GaussianBlur(40)))
    return finish(img)


def wax_splash():
    rnd = random.Random(23)
    img = canvas()
    d = ImageDraw.Draw(img)
    d.polygon(blob_polygon(512, 512, 230, rnd, wobble=.12, lobes=7), fill=WAX + (255,))
    # Uneven tongues of wax thrown out, each tapering to a drop.
    for k in range(13):
        a = k / 13 * 2 * math.pi + rnd.uniform(-.2, .2)
        length = rnd.uniform(260, 470)
        w = rnd.uniform(46, 90)
        ux, uy = math.cos(a), math.sin(a)
        px, py = -uy, ux
        pts = [(512 + px * w, 512 + py * w)]
        for j in range(1, 9):
            t = j / 8
            ww = w * (1 - t) ** 1.2 + 10
            pts.append((512 + ux * length * t + px * ww, 512 + uy * length * t + py * ww))
        for j in range(8, 0, -1):
            t = j / 8
            ww = w * (1 - t) ** 1.2 + 10
            pts.append((512 + ux * length * t - px * ww, 512 + uy * length * t - py * ww))
        pts.append((512 - px * w, 512 - py * w))
        d.polygon(pts, fill=WAX + (255,))
        rr = rnd.uniform(18, 36)
        tx, ty = 512 + ux * (length + rr * 1.4), 512 + uy * (length + rr * 1.4)
        d.ellipse((tx - rr, ty - rr, tx + rr, ty + rr), fill=WAX + (255,))
    for _ in range(16):
        a, r = rnd.uniform(0, 6.28), rnd.uniform(300, 490)
        rr = rnd.uniform(8, 22)
        x, y = 512 + math.cos(a) * r, 512 + math.sin(a) * r
        d.ellipse((x - rr, y - rr, x + rr, y + rr), fill=WAX + (255,))
    # Darker wet centre and lit ridges.
    core = canvas()
    ImageDraw.Draw(core).polygon(blob_polygon(512, 512, 170, rnd, wobble=.1), fill=WAX_DARK + (200,))
    img = Image.alpha_composite(img, core.filter(ImageFilter.GaussianBlur(30)))
    hl = canvas()
    hd = ImageDraw.Draw(hl)
    for _ in range(9):
        a, r = rnd.uniform(0, 6.28), rnd.uniform(120, 300)
        x, y = 512 + math.cos(a) * r, 512 + math.sin(a) * r
        hd.ellipse((x - 26, y - 14, x + 26, y + 14), fill=(255, 150, 130, 170))
    img = Image.alpha_composite(img, hl.filter(ImageFilter.GaussianBlur(9)))
    return finish(img)


def wax_drop():
    rnd = random.Random(31)
    img = canvas()
    d = ImageDraw.Draw(img)
    d.polygon(blob_polygon(500, 540, 300, rnd, wobble=.06, lobes=3), fill=WAX + (255,))
    d.ellipse((640, 250, 760, 370), fill=WAX + (255,))
    d.polygon(blob_polygon(480, 560, 220, rnd, wobble=.05, lobes=4), fill=(178, 26, 34, 255))
    hl = canvas()
    ImageDraw.Draw(hl).ellipse((360, 380, 520, 470), fill=(255, 220, 210, 230))
    img = Image.alpha_composite(img, hl.filter(ImageFilter.GaussianBlur(16)))
    return finish(img)


# ------------------------------------------------------------------ mirror

def mirror_shard(points, seed):
    rnd = random.Random(seed)
    img = canvas()
    mask = Image.new("L", (C, C), 0)
    ImageDraw.Draw(mask).polygon(points, fill=255)
    grad = Image.new("RGBA", (C, C))
    gd = ImageDraw.Draw(grad)
    for k in range(C):
        t = k / C
        col = (int(196 - 110 * t), int(222 - 100 * t), int(255 - 60 * t), 255)
        gd.line((k, 0, 0, k), fill=col)
        gd.line((C - 1, k, k, C - 1), fill=(int(90 + 40 * t), int(116 + 40 * t), int(190 + 30 * t), 255))
    img.paste(grad, (0, 0), mask)
    # Reflections: two soft diagonal sheens, uneven.
    sh = canvas()
    sd = ImageDraw.Draw(sh)
    for k in range(2):
        off = rnd.uniform(-200, 200) + k * 260
        w = rnd.uniform(40, 90)
        sd.polygon([(off, 0), (off + w, 0), (off + w + C, C), (off + C, C)], fill=(255, 255, 255, 150 if k == 0 else 90))
    sh = sh.filter(ImageFilter.GaussianBlur(14))
    sh.putalpha(ImageChops.multiply(sh.getchannel("A"), mask))
    img = Image.alpha_composite(img, sh)
    d = ImageDraw.Draw(img)
    d.line(points + [points[0]], fill=(255, 255, 255, 255), width=16, joint="curve")
    return finish(img)


# ------------------------------------------------------------------ night pass (2026-10-07)

def shade_poly(img, pts, fill, outline=None, width=0):
    d = ImageDraw.Draw(img)
    d.polygon(pts, fill=fill)
    if outline:
        d.line(pts + [pts[0]], fill=outline, width=width, joint="curve")


def crystal(seed, tall=False):
    rnd = random.Random(seed)
    img = canvas()
    if tall:
        base_y, top = 1000, 30
        bl, br = 512 - rnd.uniform(120, 160), 512 + rnd.uniform(120, 160)
        tip = (512 + rnd.uniform(-40, 40), top)
        mid = (512 + rnd.uniform(-20, 20), 560)
        shade_poly(img, [(bl, base_y), mid, tip], (236, 240, 248, 255))
        shade_poly(img, [mid, (br, base_y), tip], (170, 180, 200, 255))
        shade_poly(img, [(bl, base_y), (br, base_y), mid], (204, 212, 228, 255))
        d = ImageDraw.Draw(img)
        d.line([(bl, base_y), tip, (br, base_y)], fill=(255, 255, 255, 255), width=14, joint="curve")
        d.line([mid, tip], fill=(255, 255, 255, 200), width=8)
    else:
        n = rnd.randint(5, 6)
        cx, cy = 512, 512
        pts = []
        for k in range(n):
            a = k / n * 2 * math.pi + rnd.uniform(-.25, .25)
            r = rnd.uniform(260, 470) * (1.25 if k % 2 == 0 else .8)
            pts.append((cx + math.cos(a) * r * .62, cy + math.sin(a) * r))
        ridge = (cx + rnd.uniform(-60, 60), cy + rnd.uniform(-60, 60))
        greys = [236, 196, 160, 214, 180, 224]
        for k in range(n):
            g = greys[k % len(greys)]
            shade_poly(img, [ridge, pts[k], pts[(k + 1) % n]], (g, g + 4, min(255, g + 14), 255))
        d = ImageDraw.Draw(img)
        d.line(pts + [pts[0]], fill=(255, 255, 255, 255), width=14, joint="curve")
        for k in range(0, n, 2):
            d.line([ridge, pts[k]], fill=(255, 255, 255, 170), width=7)
    sh = canvas()
    ImageDraw.Draw(sh).polygon([(300, 0), (420, 0), (720, 1024), (600, 1024)], fill=(255, 255, 255, 110))
    sh = sh.filter(ImageFilter.GaussianBlur(20))
    sh.putalpha(ImageChops.multiply(sh.getchannel("A"), img.getchannel("A")))
    return finish(Image.alpha_composite(img, sh))


def splat(seed, body, edge, gloss, tongues=13, reach=(260, 470)):
    rnd = random.Random(seed)
    img = canvas()
    d = ImageDraw.Draw(img)
    d.polygon(blob_polygon(512, 512, 230, rnd, wobble=.12, lobes=7), fill=body)
    for k in range(tongues):
        a = k / tongues * 2 * math.pi + rnd.uniform(-.2, .2)
        length = rnd.uniform(*reach)
        w = rnd.uniform(40, 86)
        ux, uy = math.cos(a), math.sin(a)
        px, py = -uy, ux
        pts = []
        for j in range(0, 9):
            t = j / 8
            ww = w * (1 - t) ** 1.2 + 9
            pts.append((512 + ux * length * t + px * ww, 512 + uy * length * t + py * ww))
        for j in range(8, -1, -1):
            t = j / 8
            ww = w * (1 - t) ** 1.2 + 9
            pts.append((512 + ux * length * t - px * ww, 512 + uy * length * t - py * ww))
        d.polygon(pts, fill=body)
        rr = rnd.uniform(16, 34)
        tx, ty = 512 + ux * (length + rr * 1.4), 512 + uy * (length + rr * 1.4)
        d.ellipse((tx - rr, ty - rr, tx + rr, ty + rr), fill=body)
    for _ in range(18):
        a, r = rnd.uniform(0, 6.28), rnd.uniform(300, 490)
        rr = rnd.uniform(7, 20)
        x, y = 512 + math.cos(a) * r, 512 + math.sin(a) * r
        d.ellipse((x - rr, y - rr, x + rr, y + rr), fill=body)
    if edge:
        core = canvas()
        ImageDraw.Draw(core).polygon(blob_polygon(512, 512, 170, rnd, wobble=.1), fill=edge)
        img = Image.alpha_composite(img, core.filter(ImageFilter.GaussianBlur(30)))
    hl = canvas()
    hd = ImageDraw.Draw(hl)
    for _ in range(9):
        a, r = rnd.uniform(0, 6.28), rnd.uniform(100, 300)
        x, y = 512 + math.cos(a) * r, 512 + math.sin(a) * r
        hd.ellipse((x - 26, y - 14, x + 26, y + 14), fill=gloss)
    img = Image.alpha_composite(img, hl.filter(ImageFilter.GaussianBlur(9)))
    return finish(img)


def drop(seed, body, inner, light):
    rnd = random.Random(seed)
    img = canvas()
    d = ImageDraw.Draw(img)
    d.polygon(blob_polygon(500, 540, 300, rnd, wobble=.06, lobes=3), fill=body)
    d.polygon(blob_polygon(480, 560, 220, rnd, wobble=.05, lobes=4), fill=inner)
    hl = canvas()
    ImageDraw.Draw(hl).ellipse((360, 380, 520, 470), fill=light)
    return finish(Image.alpha_composite(img, hl.filter(ImageFilter.GaussianBlur(16))))


def water_splash():
    rnd = random.Random(41)
    img = canvas()
    d = ImageDraw.Draw(img)
    # A crown of water: a low sheet with upright spouts, each ending in a drop.
    d.polygon(blob_polygon(512, 700, 330, rnd, wobble=.08, lobes=6), fill=(214, 232, 255, 170))
    for k in range(9):
        x = 512 + (k - 4) * 82 + rnd.uniform(-20, 20)
        h = rnd.uniform(260, 520) * (1 - abs(k - 4) / 7)
        w = rnd.uniform(26, 44)
        d.polygon([(x - w, 720), (x - w * .3, 720 - h), (x + w * .3, 720 - h), (x + w, 720)], fill=(232, 244, 255, 200))
        rr = w * .9
        d.ellipse((x - rr, 700 - h - rr * 1.6, x + rr, 700 - h + rr * .2), fill=(244, 250, 255, 230))
    for _ in range(14):
        x, y, rr = rnd.uniform(140, 880), rnd.uniform(120, 520), rnd.uniform(10, 24)
        d.ellipse((x - rr, y - rr, x + rr, y + rr), fill=(240, 248, 255, 220))
    rim = canvas()
    ImageDraw.Draw(rim).line(blob_polygon(512, 700, 330, rnd, wobble=.08, lobes=6), fill=(255, 255, 255, 255), width=18)
    img = Image.alpha_composite(img, rim.filter(ImageFilter.GaussianBlur(4)))
    return finish(img)


def bubble():
    img = canvas()
    d = ImageDraw.Draw(img)
    d.ellipse((150, 150, 874, 874), fill=(220, 236, 255, 60))
    rim = canvas()
    ImageDraw.Draw(rim).ellipse((150, 150, 874, 874), outline=(255, 255, 255, 230), width=34)
    img = Image.alpha_composite(img, rim.filter(ImageFilter.GaussianBlur(6)))
    hl = canvas()
    ImageDraw.Draw(hl).ellipse((300, 260, 470, 380), fill=(255, 255, 255, 240))
    return finish(Image.alpha_composite(img, hl.filter(ImageFilter.GaussianBlur(10))))


def feather():
    rnd = random.Random(51)
    img = canvas()
    d = ImageDraw.Draw(img)
    # Vane: a long asymmetric leaf shape along a slightly curved shaft, tip up.
    left, right = [], []
    for k in range(41):
        t = k / 40
        y = 980 - 940 * t
        x = 512 + 30 * math.sin(t * 2.2)
        wl = 170 * math.sin(math.pi * min(1, t * 1.15)) ** .8 * (1 - .15 * t)
        wr = 120 * math.sin(math.pi * min(1, t * 1.1)) ** .8
        left.append((x - wl, y)); right.append((x + wr, y))
    d.polygon(left + right[::-1], fill=(236, 238, 244, 255))
    for k in range(4, 38, 2):
        t = k / 40
        y = 980 - 940 * t
        x = 512 + 30 * math.sin(t * 2.2)
        d.line([(x, y), left[k][0] + 10, left[k][1] - 40], fill=(190, 196, 210, 255), width=5)
        d.line([(x, y), right[k][0] - 8, right[k][1] - 30], fill=(200, 206, 218, 255), width=5)
    d.line([(512 + 30 * math.sin(k / 40 * 2.2), 980 - 940 * k / 40) for k in range(41)], fill=(255, 255, 255, 255), width=14)
    # A few splits in the vane.
    for k in (14, 25):
        d.polygon([left[k], (left[k][0] + 70, left[k][1] - 20), (left[k][0] + 10, left[k][1] + 30)], fill=(0, 0, 0, 0))
    return finish(img)


def petal():
    img = canvas()
    d = ImageDraw.Draw(img)
    pts = []
    for k in range(80):
        a = k / 80 * 2 * math.pi
        x = math.sin(a)
        y = -math.cos(a)
        w = 300 * (1 - (y * .5 + .5) ** 3) ** .6 if y > -1 else 0
        pts.append((512 + x * 300 * (.55 + .45 * (1 - abs(y))), 520 + y * 470))
    d.polygon(pts, fill=(250, 248, 250, 255))
    inner = canvas()
    ImageDraw.Draw(inner).ellipse((380, 560, 644, 1000), fill=(200, 196, 206, 200))
    img = Image.alpha_composite(img, inner.filter(ImageFilter.GaussianBlur(50)))
    img.putalpha(ImageChops.multiply(img.getchannel("A"), Image.new("L", (C, C), 0).point(lambda v: 0) if False else img.getchannel("A")))
    d = ImageDraw.Draw(img)
    for k in (-1, 0, 1):
        d.line([(512 + k * 30, 940), (512 + k * 120, 300)], fill=(214, 210, 222, 255), width=6)
    mask = Image.new("L", (C, C), 0)
    ImageDraw.Draw(mask).polygon(pts, fill=255)
    img.putalpha(ImageChops.multiply(img.getchannel("A"), mask))
    return finish(img)


STEEL = (168, 178, 196)
STEEL_DARK = (96, 106, 124)
WOOD = (110, 70, 40)


def sword():
    img = canvas()
    d = ImageDraw.Draw(img)
    # Tip at the bottom: the sword points down the cell's -y.
    d.polygon([(470, 300), (554, 300), (548, 880), (512, 1010), (476, 880)], fill=STEEL + (255,))
    d.polygon([(512, 300), (554, 300), (548, 880), (512, 1010)], fill=(110, 120, 140, 255))
    d.line([(476, 320), (476, 880)], fill=(236, 240, 248, 255), width=6)
    d.line([(512, 320), (512, 900)], fill=(70, 78, 96, 255), width=6)
    d.rounded_rectangle((330, 262, 694, 306), 18, fill=GOLD + (255,), outline=GOLD_DARK + (255,), width=6)
    d.rounded_rectangle((486, 80, 538, 262), 14, fill=(70, 40, 26, 255))
    for y in range(100, 250, 34):
        d.line([(486, y), (538, y + 18)], fill=(120, 80, 50, 255), width=6)
    d.ellipse((470, 30, 554, 112), fill=GOLD + (255,), outline=GOLD_DARK + (255,), width=6)
    return finish(img)


def axe():
    img = canvas()
    d = ImageDraw.Draw(img)
    # Haft up the middle, a broad crescent blade at the top on the right.
    d.rounded_rectangle((470, 120, 530, 1000), 22, fill=WOOD + (255,))
    for y in range(160, 980, 60):
        d.line([(470, y), (530, y + 10)], fill=(80, 48, 26, 255), width=6)
    blade = [(520, 120), (720, 40), (900, 120), (960, 300), (900, 470), (720, 540), (520, 470)]
    d.polygon(blade, fill=STEEL_DARK + (255,))
    edge = []
    for k in range(25):
        a = -1.1 + 2.2 * k / 24
        edge.append((760 + math.cos(a) * 210, 290 + math.sin(a) * 260))
    d.polygon([(560, 160)] + edge + [(560, 430)], fill=STEEL + (255,))
    d.line(edge, fill=(236, 240, 248, 255), width=12)
    d.polygon([(600, 200), (760, 160), (820, 290), (760, 420), (600, 390)], fill=(120, 130, 150, 255))
    d.rectangle((452, 150, 548, 220), fill=(70, 70, 80, 255))
    d.rectangle((452, 400, 548, 460), fill=(70, 70, 80, 255))
    return finish(img)


def hammer():
    img = canvas()
    d = ImageDraw.Draw(img)
    d.rounded_rectangle((474, 300, 550, 1000), 24, fill=WOOD + (255,))
    d.rounded_rectangle((210, 70, 814, 330), 40, fill=(96, 100, 112, 255), outline=(60, 62, 70, 255), width=12)
    d.rounded_rectangle((250, 100, 774, 170), 20, fill=(150, 156, 170, 255))
    for x in (300, 724):
        d.rectangle((x - 30, 70, x + 30, 330), fill=GOLD_DARK + (255,))
        d.rectangle((x - 18, 70, x + 18, 330), fill=GOLD + (255,))
    return finish(img)


def clock_hand():
    img = canvas()
    d = ImageDraw.Draw(img)
    # Hub at the bottom centre, the hand pointing up to a spade tip.
    d.polygon([(470, 860), (494, 300), (512, 260), (530, 300), (554, 860)], fill=GOLD + (255,))
    d.polygon([(512, 40), (420, 210), (512, 330), (604, 210)], fill=GOLD + (255,), outline=GOLD_DARK + (255,))
    d.ellipse((470, 180, 554, 260), fill=(40, 20, 10, 255))
    d.polygon([(512, 520), (468, 600), (512, 680), (556, 600)], fill=GOLD_LIGHT + (255,))
    d.ellipse((430, 830, 594, 994), fill=GOLD + (255,), outline=GOLD_DARK + (255,), width=12)
    d.ellipse((488, 888, 536, 936), fill=GOLD_DARK + (255,))
    d.line([(512, 320), (512, 830)], fill=GOLD_LIGHT + (255,), width=8)
    return finish(img)


def chain_link():
    img = canvas()
    d = ImageDraw.Draw(img)
    d.rounded_rectangle((280, 110, 744, 914), 230, outline=(150, 156, 170, 255), width=120)
    d.rounded_rectangle((300, 130, 724, 894), 210, outline=(214, 220, 232, 255), width=40)
    hl = canvas()
    ImageDraw.Draw(hl).arc((320, 150, 704, 874), 200, 260, fill=(255, 255, 255, 255), width=26)
    return finish(Image.alpha_composite(img, hl.filter(ImageFilter.GaussianBlur(5))))


def needle():
    img = canvas()
    d = ImageDraw.Draw(img)
    d.polygon([(498, 180), (526, 180), (516, 1010), (508, 1010)], fill=GOLD + (255,))
    d.line([(512, 190), (512, 990)], fill=GOLD_LIGHT + (255,), width=5)
    d.ellipse((430, 30, 594, 194), fill=(244, 236, 230, 255), outline=GOLD + (255,), width=10)
    d.ellipse((470, 64, 520, 110), fill=(255, 255, 255, 255))
    for y in (230, 270):
        d.rectangle((488, y, 536, y + 18), fill=GOLD_DARK + (255,))
    return finish(img)


def meteor():
    rnd = random.Random(61)
    img = canvas()
    d = ImageDraw.Draw(img)
    d.polygon(blob_polygon(512, 512, 330, rnd, wobble=.14, lobes=5), fill=(56, 36, 30, 255))
    lava = canvas()
    ld = ImageDraw.Draw(lava)
    for _ in range(9):
        a = rnd.uniform(0, 6.28)
        r0, r1 = rnd.uniform(0, 120), rnd.uniform(200, 320)
        pts = []
        h = a
        for k in range(8):
            r = r0 + (r1 - r0) * k / 7
            h += rnd.uniform(-.3, .3)
            pts.append((512 + math.cos(h) * r, 512 + math.sin(h) * r))
        ld.line(pts, fill=(255, 150, 40, 255), width=int(rnd.uniform(10, 22)), joint="curve")
    lava.putalpha(ImageChops.multiply(lava.getchannel("A"), img.getchannel("A")))
    glow = lava.filter(ImageFilter.GaussianBlur(14))
    img = Image.alpha_composite(img, glow)
    img = Image.alpha_composite(img, lava)
    rim = canvas()
    ImageDraw.Draw(rim).polygon(blob_polygon(450, 440, 260, rnd, wobble=.1, lobes=4), fill=(255, 200, 90, 120))
    rim = rim.filter(ImageFilter.GaussianBlur(40))
    rim.putalpha(ImageChops.multiply(rim.getchannel("A"), img.getchannel("A")))
    return finish(Image.alpha_composite(img, rim))


def coin():
    img = canvas()
    d = ImageDraw.Draw(img)
    d.ellipse((120, 120, 904, 904), fill=GOLD_DARK + (255,))
    d.ellipse((150, 150, 874, 874), fill=GOLD + (255,))
    d.ellipse((230, 230, 794, 794), fill=(222, 166, 60, 255))
    star4(d, 512, 512, 230, GOLD_LIGHT + (255,), .28)
    crescent(img, 512, 512, 120, GOLD_DARK, (.45, -.1))
    hl = canvas()
    ImageDraw.Draw(hl).ellipse((260, 220, 520, 400), fill=(255, 250, 220, 160))
    return finish(Image.alpha_composite(img, hl.filter(ImageFilter.GaussianBlur(30))))


def bolt(seed):
    rnd = random.Random(seed)
    pts = [(512 + rnd.uniform(-60, 60), 20)]
    y = 20
    while y < 980:
        y += rnd.uniform(90, 150)
        pts.append((512 + rnd.uniform(-170, 170), min(1004, y)))
    glow = canvas()
    ImageDraw.Draw(glow).line(pts, fill=(255, 255, 255, 150), width=70, joint="curve")
    img = glow.filter(ImageFilter.GaussianBlur(26))
    core = canvas()
    cd = ImageDraw.Draw(core)
    cd.line(pts, fill=(255, 255, 255, 255), width=22, joint="curve")
    k = rnd.randint(2, len(pts) - 3)
    bx, by = pts[k]
    cd.line([(bx, by), (bx + rnd.choice([-1, 1]) * 200, by + 120), (bx + rnd.choice([-1, 1]) * 260, by + 260)], fill=(255, 255, 255, 230), width=10)
    return finish(Image.alpha_composite(img, core))


def paw():
    img = canvas()
    d = ImageDraw.Draw(img)
    # Four splayed, hooked talons (no paw pad: with one it read as a jellyfish), each a
    # thick crescent tapering to a point, light so the identity colour tints it.
    for k in range(4):
        ang = math.radians(-24 + k * 16)
        root = (512 + (k - 1.5) * 120, 120)
        pts_l, pts_r = [], []
        for j in range(25):
            t = j / 24
            bend = 170 * t * t
            dx = math.sin(ang) * 820 * t + bend * (1 if k >= 2 else -1) * .35
            x = root[0] + dx
            y = root[1] + math.cos(ang) * 820 * t
            w = 70 * (1 - t) ** 1.1 + 3
            pts_l.append((x - w, y)); pts_r.append((x + w * .55, y))
        d.polygon(pts_l + pts_r[::-1], fill=(240, 240, 246, 255))
        d.line(pts_l[1:20], fill=(255, 255, 255, 255), width=10)
        d.line([(p[0] + 30, p[1]) for p in pts_l[2:18]], fill=(176, 180, 192, 255), width=8)
    return finish(img)


def dragon_head():
    img = canvas()
    d = ImageDraw.Draw(img)
    gold, dark, teal = (232, 178, 64, 255), (150, 96, 26, 255), (60, 170, 160, 255)
    # Side view facing right: snout, open jaw, horns swept back, mane.
    d.polygon([(200, 470), (520, 330), (860, 400), (930, 470), (860, 520), (560, 560), (300, 600)], fill=gold)
    d.polygon([(330, 600), (560, 580), (880, 620), (820, 700), (520, 700), (300, 660)], fill=dark)
    for x in range(600, 860, 50):
        d.polygon([(x, 560), (x + 18, 600), (x + 36, 560)], fill=(255, 255, 255, 255))
    d.polygon([(420, 360), (300, 120), (360, 100), (470, 340)], fill=GOLD_LIGHT + (255,))
    d.polygon([(520, 340), (480, 80), (540, 70), (570, 340)], fill=GOLD_LIGHT + (255,))
    for k in range(6):
        y = 380 + k * 50
        d.polygon([(260, y), (60 + k * 10, y - 60 + k * 30), (110 + k * 10, y + 40)], fill=teal)
    d.ellipse((640, 410, 700, 460), fill=(255, 60, 40, 255))
    d.line([(860, 470), (960, 600), (1000, 760)], fill=GOLD_LIGHT + (255,), width=10, joint="curve")
    d.line([(820, 520), (900, 700), (880, 880)], fill=GOLD_LIGHT + (255,), width=8, joint="curve")
    return finish(img)


def dragon_scale():
    img = canvas()
    d = ImageDraw.Draw(img)
    d.ellipse((140, 220, 884, 804), fill=(214, 156, 50, 255))
    for row in range(3):
        for k in range(4):
            x = 260 + k * 170 + (row % 2) * 85
            y = 330 + row * 150
            d.pieslice((x - 90, y - 90, x + 90, y + 90), 0, 180, fill=GOLD + (255,), outline=GOLD_DARK + (255,), width=8)
    d.polygon([(380, 230), (512, 60), (640, 230)], fill=(60, 170, 160, 255))
    mask = Image.new("L", (C, C), 0)
    ImageDraw.Draw(mask).ellipse((140, 60, 884, 804), fill=255)
    img.putalpha(ImageChops.multiply(img.getchannel("A"), mask))
    return finish(img)


def mask():
    img = canvas()
    d = ImageDraw.Draw(img)
    pts = []
    for k in range(80):
        a = k / 80 * 2 * math.pi
        x, y = math.sin(a), -math.cos(a)
        w = 330 * (1 - .35 * max(0, y)) if y > 0 else 330
        pts.append((512 + x * w, 470 + y * (430 if y > 0 else 400)))
    d.polygon(pts, fill=(246, 244, 240, 255))
    d.line(pts + [pts[0]], fill=GOLD + (255,), width=18)
    for sx in (-1, 1):
        d.polygon([(512 + sx * 70, 420), (512 + sx * 230, 380), (512 + sx * 250, 470), (512 + sx * 90, 480)], fill=(20, 14, 30, 255))
        d.line([(512 + sx * 60, 400), (512 + sx * 260, 350)], fill=GOLD + (255,), width=10)
    d.arc((380, 560, 644, 760), 20, 160, fill=(180, 60, 90, 255), width=16)
    d.polygon([(512, 520), (490, 600), (534, 600)], fill=(214, 210, 204, 255))
    return finish(img)


def rock(seed):
    rnd = random.Random(seed)
    img = canvas()
    pts = blob_polygon(512, 512, 330, rnd, n=9, wobble=.18, lobes=3)
    ridge = (512 + rnd.uniform(-80, 80), 512 + rnd.uniform(-80, 80))
    greys = [196, 150, 120, 176, 140, 210, 160, 130, 186]
    for k in range(len(pts)):
        g = greys[k % len(greys)]
        shade_poly(img, [ridge, pts[k], pts[(k + 1) % len(pts)]], (g, g, g + 6, 255))
    ImageDraw.Draw(img).line(pts + [pts[0]], fill=(90, 90, 96, 255), width=10)
    return finish(img)


def crater():
    rnd = random.Random(81)
    img = canvas()
    d = ImageDraw.Draw(img)
    d.polygon(blob_polygon(512, 512, 440, rnd, wobble=.1, lobes=6), fill=(60, 52, 50, 110))
    d.polygon(blob_polygon(512, 512, 330, rnd, wobble=.08, lobes=5), fill=(40, 32, 30, 200))
    d.polygon(blob_polygon(512, 512, 190, rnd, wobble=.06, lobes=4), fill=(20, 14, 12, 235))
    for _ in range(26):
        a, r = rnd.uniform(0, 6.28), rnd.uniform(330, 470)
        rr = rnd.uniform(14, 34)
        x, y = 512 + math.cos(a) * r, 512 + math.sin(a) * r
        d.polygon(blob_polygon(x, y, rr, rnd, n=7, wobble=.2), fill=(120, 110, 104, 230))
    return finish(img.filter(ImageFilter.GaussianBlur(2)))


def phoenix():
    img = canvas()
    d = ImageDraw.Draw(img)
    fire = [(255, 236, 140), (255, 176, 50), (240, 90, 30), (190, 30, 30)]
    # Facing up (dives along the cell's +y): spread wings, a crested head, a long tail.
    for layer, col in enumerate(fire[::-1]):
        k = 1 - layer * .16
        for sx in (-1, 1):
            wing = [(512, 470)]
            for j in range(9):
                t = j / 8
                wing.append((512 + sx * (100 + 380 * t) * k, 470 - (300 * math.sin(t * 2.6)) * k + 90 * t))
            for j in range(8, -1, -1):
                t = j / 8
                wing.append((512 + sx * (100 + 380 * t) * k, 470 - (300 * math.sin(t * 2.6)) * k + 90 * t + (160 * (1 - t) + 40) * k))
            d.polygon(wing, fill=col + (255,))
        for j in range(5):
            a = (j - 2) * .22
            L = (440 + (60 if j == 2 else 0)) * k
            d.polygon([(512 - 30, 560), (512 + 30, 560), (512 + math.sin(a) * L + 20, 560 + math.cos(a) * L), (512 + math.sin(a) * L - 20, 560 + math.cos(a) * L)], fill=col + (255,))
    d.ellipse((440, 380, 584, 600), fill=(255, 210, 90, 255))
    d.ellipse((462, 250, 562, 380), fill=(255, 230, 140, 255))
    for j in range(3):
        d.polygon([(500, 270), (470 + j * 30, 120 + abs(j - 1) * 40), (530, 270)], fill=(255, 140, 40, 255))
    d.polygon([(495, 255), (512, 200), (529, 255)], fill=(255, 250, 220, 255))
    return finish(img)


def page():
    rnd = random.Random(91)
    img = canvas()
    d = ImageDraw.Draw(img)
    pts = [(240, 90), (800, 70), (830, 960), (210, 940)]
    d.polygon(pts, fill=(244, 238, 222, 255))
    for k in range(12):
        y = 180 + k * 62
        x0, x1 = 300, 300 + rnd.uniform(300, 440)
        line = [(x0 + (x1 - x0) * j / 20, y + math.sin(j * 1.9 + k) * 8) for j in range(21)]
        d.line(line, fill=(70, 66, 74, 255), width=10)
    d.line(pts + [pts[0]], fill=(200, 190, 170, 255), width=10)
    return finish(img)


def qi_crescent():
    img = canvas()
    # A thick crescent of light, fullest in the middle, tapering to two points.
    body = canvas()
    bd = ImageDraw.Draw(body)
    outer, inner = [], []
    for k in range(61):
        a = math.radians(-70 + 140 * k / 60)
        t = k / 60
        th = math.sin(math.pi * t) ** .8
        outer.append((512 - 380 + math.cos(a) * 760, 512 + math.sin(a) * 760 * .62))
        inner.append((512 - 380 + math.cos(a) * (760 - 230 * th), 512 + math.sin(a) * (760 - 230 * th) * .62))
    bd.polygon(outer + inner[::-1], fill=(255, 255, 255, 200))
    img = body.filter(ImageFilter.GaussianBlur(10))
    core = canvas()
    cd = ImageDraw.Draw(core)
    mid = [((o[0] * 3 + i[0]) / 4, (o[1] * 3 + i[1]) / 4) for o, i in zip(outer, inner)]
    cd.line(mid[6:-6], fill=(255, 255, 255, 255), width=26, joint="curve")
    return finish(Image.alpha_composite(img, core.filter(ImageFilter.GaussianBlur(4))))


def main(out):
    cells = [
        tarot_front(),                                                       # 0
        tarot_back(),                                                        # 1
        wax_seal(),                                                          # 2
        wax_splash(),                                                        # 3
        wax_drop(),                                                          # 4
        mirror_shard([(140, 120), (900, 330), (430, 930)], 5),               # 5
        mirror_shard([(300, 80), (860, 260), (720, 880), (180, 640)], 6),    # 6
        name_front(),                                                        # 7
        name_back(),                                                         # 8
        crystal(101),                                                        # 9  CrystalA
        crystal(102),                                                        # 10 CrystalB
        crystal(103, tall=True),                                             # 11 Spike
        splat(111, (26, 24, 30, 255), (6, 6, 8, 220), (150, 150, 170, 170)), # 12 InkSplat
        drop(112, (24, 22, 28, 255), (40, 38, 46, 255), (200, 200, 220, 220)),  # 13 InkDrop
        splat(151, (222, 238, 255, 190), None, (255, 255, 255, 235), tongues=15, reach=(240, 480)),  # 14 WaterSplash
        drop(113, (210, 230, 255, 190), (236, 246, 255, 150), (255, 255, 255, 240)),  # 15 WaterDrop
        bubble(),                                                            # 16 Bubble
        feather(),                                                           # 17 Feather
        petal(),                                                             # 18 Petal
        sword(),                                                             # 19 Sword
        axe(),                                                               # 20 Axe
        hammer(),                                                            # 21 Hammer
        clock_hand(),                                                        # 22 ClockHand
        chain_link(),                                                        # 23 ChainLink
        needle(),                                                            # 24 Needle
        meteor(),                                                            # 25 Meteor
        coin(),                                                              # 26 Coin
        bolt(121),                                                           # 27 BoltA
        bolt(122),                                                           # 28 BoltB
        paw(),                                                               # 29 Paw
        dragon_head(),                                                       # 30 DragonHead
        dragon_scale(),                                                      # 31 DragonScale
        mask(),                                                              # 32 Mask
        rock(131),                                                           # 33 RockA
        rock(132),                                                           # 34 RockB
        crater(),                                                            # 35 Crater
        phoenix(),                                                           # 36 Phoenix
        page(),                                                              # 37 Page
        qi_crescent(),                                                       # 38 Qi
        splat(141, (236, 236, 240, 255), None, (255, 255, 255, 200), tongues=11, reach=(220, 420)),  # 39 Splash (tint)
    ]
    sheet = Image.new("RGBA", (CELL * 8, CELL * 8), (0, 0, 0, 0))
    for i, cell in enumerate(cells):
        sheet.paste(cell, ((i % 8) * CELL, (i // 8) * CELL))
    sheet.save(out)
    print("wrote", out, len(cells), "cells")


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else "SpectacleProps.png")
