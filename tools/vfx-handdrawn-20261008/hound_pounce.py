"""Hand-drawn style frame-by-frame impact for the hound's pounce (2026-10-08).

The user's reference is 2D hand-drawn cartoon VFX (Alex Redfish's 2XKO concepts,
Daniil Tolmachov's animated GIFs): every frame is redrawn, shapes change instead of a
texture sliding; hard-edged 2-3 step colour bands, a small white core only where the
fire is thickest, near-black thorny strokes against saturated glowing fire, detached
droplets taking over as the main shape breaks up. Rhythm: dark gather -> sharp burst
-> claw tears and fire tongues fling out -> curl, break into drops, dark wisps -> gone.

Pure PIL (no numpy): every frame is drawn at 2x and downsampled. Each frame re-rolls a
small wobble on every contour, the way a redrawn frame never matches the last one.

usage: python3 hound_pounce.py <out_sheet.png> [preview_dir]
"""
import math
import random
import sys

from PIL import Image, ImageChops, ImageDraw, ImageFilter

FRAMES = 14
CELL = 512          # output cell size
SS = 2              # supersample
BASE = CELL * SS
S = int(BASE * 1.6)  # drawn on a roomy canvas, then every frame is cropped by the same square
C = (S / 2, S / 2)   # impact point: stays the centre of the final cell
U = BASE / 2 * .8    # one unit of the choreography

DARK = (38, 4, 12)
RIM = (205, 24, 22)
BODY = (255, 96, 20)
HOT = (255, 202, 52)
CORE = (255, 248, 214)
GLOW = (255, 64, 18)


# ------------------------------------------------------------------ geometry

def lerp(a, b, t):
    return a + (b - a) * t


def bez(p0, p1, p2, p3, n):
    out = []
    for i in range(n):
        t = i / (n - 1)
        a = (1 - t) ** 3
        b = 3 * (1 - t) ** 2 * t
        c = 3 * (1 - t) * t * t
        d = t ** 3
        out.append((a * p0[0] + b * p1[0] + c * p2[0] + d * p3[0],
                    a * p0[1] + b * p1[1] + c * p2[1] + d * p3[1]))
    return out


def normals(pts):
    out = []
    for i in range(len(pts)):
        a = pts[max(0, i - 1)]
        b = pts[min(len(pts) - 1, i + 1)]
        tx, ty = b[0] - a[0], b[1] - a[1]
        L = math.hypot(tx, ty) or 1.0
        out.append((-ty / L, tx / L))
    return out


def ribbon(pts, widths, shift=0.0, t0=0.0, t1=1.0):
    """Closed outline round a centreline. widths are half widths; shift moves the band
    toward the +normal side by that share of its own width (the inside of a curl).
    A span cut out of the middle tapers to points at its cut ends, never a square end."""
    n = len(pts)
    i0, i1 = int(t0 * (n - 1)), int(math.ceil(t1 * (n - 1)))
    nm = normals(pts)
    left, right = [], []
    span = max(1, i1 - i0)
    for i in range(i0, i1 + 1):
        w = widths[i]
        u = (i - i0) / span
        if i0 > 0 and u < .35:
            w *= (u / .35) ** .6
        if i1 < n - 1 and u > .65:
            w *= ((1 - u) / .35) ** .6
        cx = pts[i][0] + nm[i][0] * w * shift
        cy = pts[i][1] + nm[i][1] * w * shift
        left.append((cx + nm[i][0] * w, cy + nm[i][1] * w))
        right.append((cx - nm[i][0] * w, cy - nm[i][1] * w))
    return left + right[::-1]


def rot(v, a):
    c, s = math.cos(a), math.sin(a)
    return (v[0] * c - v[1] * s, v[0] * s + v[1] * c)


def polar(a, r, o=C):
    return (o[0] + math.cos(a) * r, o[1] + math.sin(a) * r)


# ------------------------------------------------------------------ drawing

class Layer:
    """One colour band layer: polygons filled flat, composited in order."""

    def __init__(self):
        self.img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
        self.d = ImageDraw.Draw(self.img)

    def poly(self, pts, col, a=255):
        if len(pts) >= 3:
            self.d.polygon([(float(x), float(y)) for x, y in pts], fill=col + (int(a),))

    def blob(self, c, r, col, a=255, wob=None, n=14):
        pts = []
        for i in range(n):
            ang = i / n * math.tau
            k = 1.0 + (wob[i % len(wob)] if wob else 0.0)
            pts.append(polar(ang, r * k, c))
        self.poly(pts, col, a)


def tongue(L, base, ang, length, width, curl, lift, heat, rng, alpha=1.0, t0=0.0):
    """A flame tongue: wide near its root, curling to a sharp tip. heat 0..1 decides how
    many hot bands remain (core, hot, body, rim)."""
    d = (math.cos(ang), math.sin(ang))
    nrm = (-d[1], d[0])
    j = lambda: rng.uniform(-.06, .06) * length
    p0 = base
    p1 = (base[0] + d[0] * length * .35 + nrm[0] * curl * .2 * length + j(),
          base[1] + d[1] * length * .35 + nrm[1] * curl * .2 * length + j())
    p2 = (base[0] + d[0] * length * .7 + nrm[0] * curl * .55 * length + j(),
          base[1] + d[1] * length * .7 + nrm[1] * curl * .55 * length - lift * .5 * length + j())
    # The tip hooks back against the curl, like a brush flick.
    p3 = (base[0] + d[0] * length * .85 + nrm[0] * curl * -.12 * length + j(),
          base[1] + d[1] * length * .85 + nrm[1] * curl * -.12 * length - lift * length + j())
    pts = bez(p0, p1, p2, p3, 36)
    ws = []
    for i in range(36):
        t = i / 35
        w = (t / .16) ** .55 if t < .16 else ((1 - t) / .84) ** .9
        w *= width * (1 + rng.uniform(-.07, .07))
        ws.append(max(w, .5))
    # The inside of the curl is the hot side.
    side = 1.0 if curl >= 0 else -1.0
    a = 255 * alpha
    L.poly(ribbon(pts, ws, 0, t0), RIM, a)
    if heat > .15:
        L.poly(ribbon(pts, [w * .74 for w in ws], .2 * side, t0, .97), BODY, a)
    if heat > .45:
        L.poly(ribbon(pts, [w * .4 for w in ws], .5 * side, max(t0, .04), .8), HOT, a)
    if heat > .8:
        L.poly(ribbon(pts, [w * .15 for w in ws], .7 * side, max(t0, .08), .42), CORE, a)
    return pts


def thorn(L, pts, width, col, a, rng, hooks=2, side=1.0):
    """A dark thorny stroke: thin, tapered, with small hooks off one side."""
    ws = []
    for i in range(len(pts)):
        t = i / (len(pts) - 1)
        ws.append(max(.6, width * math.sin(math.pi * min(1, t * 1.05)) ** .7 * (1 + rng.uniform(-.12, .12))))
    L.poly(ribbon(pts, ws), col, a)
    nm = normals(pts)
    for h in range(hooks):
        i = int((h + 1) / (hooks + 1) * (len(pts) - 1) + rng.randint(-2, 2))
        i = max(1, min(len(pts) - 2, i))
        b = pts[i]
        tang = (pts[i + 1][0] - pts[i - 1][0], pts[i + 1][1] - pts[i - 1][1])
        tl = math.hypot(*tang) or 1
        tang = (tang[0] / tl, tang[1] / tl)
        hl = width * rng.uniform(2.2, 3.6)
        tip = (b[0] + nm[i][0] * side * hl + tang[0] * hl * .6, b[1] + nm[i][1] * side * hl + tang[1] * hl * .6)
        L.poly([(b[0] - tang[0] * width * 1.4, b[1] - tang[1] * width * 1.4), tip,
                (b[0] + tang[0] * width * 1.2, b[1] + tang[1] * width * 1.2)], col, a)


def star(L, n_tips, r_valley, tips, heat, rng, alpha=1.0, spin=0.0):
    """A sharp, irregular star burst. tips: list of (angle, length, valley jitter)."""
    def outline(scale_len, scale_valley):
        pts = []
        for k, (ang, ln, vj) in enumerate(tips):
            nxt = tips[(k + 1) % len(tips)][0]
            if nxt < ang:
                nxt += math.tau
            pts.append(polar(ang + spin, ln * scale_len))
            pts.append(polar((ang + nxt) / 2 + spin, r_valley * scale_valley * vj))
        return pts
    a = 255 * alpha
    L.poly(outline(1.0, 1.0), RIM, a)
    if heat > .15:
        L.poly(outline(.78, .82), BODY, a)
    if heat > .45:
        L.poly(outline(.5, .62), HOT, a)
    if heat > .75:
        wob = [rng.uniform(-.18, .18) for _ in range(9)]
        L.blob(C, r_valley * .55, CORE, a, wob, 9)


def drop(L, pos, vel, size, heat, alpha=1.0):
    """A teardrop flung along vel: round head, sharp tail pointing back."""
    vl = math.hypot(*vel) or 1
    d = (vel[0] / vl, vel[1] / vl)
    nrm = (-d[1], d[0])
    def shape(k):
        pts = []
        for i in range(10):
            ang = math.pi * (-.5 + i / 9)
            pts.append((pos[0] + (d[0] * math.cos(ang) + nrm[0] * math.sin(ang)) * size * k,
                        pos[1] + (d[1] * math.cos(ang) + nrm[1] * math.sin(ang)) * size * k))
        pts.append((pos[0] - d[0] * size * k * 3.2, pos[1] - d[1] * size * k * 3.2))
        return pts
    a = 255 * alpha
    L.poly(shape(1.0), RIM if heat < .5 else BODY, a)
    if heat > .3:
        L.poly(shape(.55), HOT, a)


# ------------------------------------------------------------------ effect

def noise_mask(seed, thr):
    """Hard-edged holes eaten into fading fire: 255 keeps, 0 eats."""
    random.seed(seed)
    n = Image.effect_noise((S // 8, S // 8), 90).resize((S, S), Image.BICUBIC).filter(ImageFilter.GaussianBlur(10))
    lo, hi = n.getextrema()
    t = lo + (hi - lo) * thr
    return n.point(lambda v: 255 if v > t else 0)


def build(seed=7):
    master = random.Random(seed)
    # Fixed choreography (same every frame), wobble re-rolled per frame below.
    # Claw tears fan out from the upper left (the hound comes from up-screen).
    claws = []
    # The three tears are the subject of a pounce: big, curved, fanned, one after another.
    for k, (ang, off, ln, wd, bend) in enumerate([(math.radians(54), -.4, 1.85, .115, .24),
                                                 (math.radians(70), 0.0, 2.2, .14, -.17),
                                                 (math.radians(87), .4, 1.7, .1, .28)]):
        d = (math.cos(ang), math.sin(ang))
        nrm = (-d[1], d[0])
        mid = (C[0] + nrm[0] * off * U * .55, C[1] + nrm[1] * off * U * .55)
        a = (mid[0] - d[0] * ln * U * .5 - nrm[0] * off * U * .25, mid[1] - d[1] * ln * U * .5 - nrm[1] * off * U * .25)
        b = (mid[0] + d[0] * ln * U * .5 + nrm[0] * off * U * .3, mid[1] + d[1] * ln * U * .5 + nrm[1] * off * U * .3)
        p1 = (lerp(a[0], b[0], .33) + nrm[0] * bend * U, lerp(a[1], b[1], .33) + nrm[1] * bend * U)
        p2 = (lerp(a[0], b[0], .66) + nrm[0] * bend * U * .8, lerp(a[1], b[1], .66) + nrm[1] * bend * U * .8)
        claws.append(dict(a=a, b=b, nrm=nrm, wd=wd * U, bend=bend * U, start=2 + k, path=bez(a, p1, p2, b, 40)))
    # Flames lick up off each tear's edge a frame after it opens.
    licks = []
    for k, cl in enumerate(claws):
        for t in (master.uniform(.2, .32), master.uniform(.45, .58), master.uniform(.7, .82)):
            i = int(t * 39)
            licks.append(dict(at=cl["path"][i], start=cl["start"] + 1 + (1 if t > .6 else 0),
                              ang=math.radians(-90 + master.uniform(-38, 38)), len=master.uniform(.32, .55) * U,
                              wid=master.uniform(.065, .095) * U, curl=master.choice([-1, 1]) * master.uniform(.8, 1.3),
                              lift=master.uniform(.2, .4)))
    # Star tips: irregular angles and lengths, never evenly spaced.
    tips = []
    ang = master.uniform(0, math.tau)
    while len(tips) < 9:
        tips.append([ang, master.uniform(.32, .66), master.uniform(.8, 1.2)])
        ang += math.tau / 9 * master.uniform(.65, 1.35)
    tips.sort(key=lambda t: t[0] % math.tau)
    for t in tips:
        t[0] %= math.tau
    # Fire tongues: mostly up and out (fire rises), each its own curl.
    tongues = []
    # Six, each its own size: two big, two middling, two small, never a fan of equals.
    for k, (base_ang, ln, wd) in enumerate([(-138, .55, .11), (-58, .46, .095), (-100, .36, .08)]):
        tongues.append(dict(ang=math.radians(base_ang + master.uniform(-12, 12)),
                            len=ln * U * master.uniform(.9, 1.1), wid=wd * U,
                            curl=(1 if k % 2 == 0 else -1) * master.uniform(.8, 1.3), lift=master.uniform(.25, .5),
                            out=master.uniform(.18, .32) * U))
    # Droplets flung away from the attacker (down and sideways).
    drops = []
    for k in range(16):
        a = math.radians(master.uniform(-20, 200))
        drops.append(dict(dir=(math.cos(a), math.sin(a)), speed=master.uniform(.7, 1.1) * U,
                          size=master.uniform(.018, .034) * U, born=master.choice([4, 4, 5, 5, 6, 7])))
    # Dark gather thorns and later smoke wisps.
    gather = [dict(ang=math.radians(a + master.uniform(-12, 12)), curl=master.choice([-1, 1])) for a in (-135, -40, 60, 150)]
    wisps = [dict(ang=math.radians(a + master.uniform(-15, 15)), curl=master.choice([-1, 1]), r=master.uniform(.35, .55))
             for a in (-150, -95, -35, 30, 140)]

    frames = []
    for f in range(FRAMES):
        rng = random.Random(seed * 1000 + f)   # a fresh hand for every frame
        dark = Layer()
        fire = Layer()
        late = f >= 7

        # 0-2: dark thorns close in on the impact point.
        if f <= 2:
            r = U * [.62, .4, .26][f]
            for g in gather:
                a0 = g["ang"]
                p0 = polar(a0, r * 1.25)
                p3 = polar(a0 + g["curl"] * .9, r * .45)
                p1 = polar(a0 + g["curl"] * .25, r * 1.2 + rng.uniform(-.05, .05) * U)
                p2 = polar(a0 + g["curl"] * .7, r * .9)
                thorn(dark, bez(p0, p1, p2, p3, 24), U * (.03 if f < 2 else .022), DARK, 235, rng, hooks=2, side=g["curl"])
            if f >= 1:
                fire.blob(C, U * (.05 if f == 1 else .09), HOT, 255, [rng.uniform(-.25, .25) for _ in range(7)], 7)

        # 2-5: the burst.
        if 2 <= f <= 5:
            sc = [.62, 1.0, 1.08, .9][f - 2]
            th = [1.0, .85, .6, .35][f - 2]
            ts = [(t[0] + rng.uniform(-.04, .04), t[1] * U * sc * (1 + rng.uniform(-.08, .08)), t[2]) for t in tips]
            if f <= 3:
                star(fire, 9, U * .2 * sc * th + U * .04, ts, [1, .9][f - 2], rng)
            else:
                # Breaks apart: spikes detach as separate shards drifting outward, thinning.
                for ang, ln, vj in ts:
                    push = U * (.12 if f == 4 else .26)
                    base = polar(ang, push + U * .06)
                    tip = polar(ang, ln * (.9 if f == 4 else .75) + push)
                    w = U * (.045 if f == 4 else .028)
                    nrm = (-math.sin(ang), math.cos(ang))
                    pts = [(base[0] + nrm[0] * w, base[1] + nrm[1] * w), tip, (base[0] - nrm[0] * w, base[1] - nrm[1] * w),
                           polar(ang, push - U * .02)]
                    fire.poly(pts, RIM)
                    if f == 4:
                        inner = [(base[0] + nrm[0] * w * .45, base[1] + nrm[1] * w * .45), polar(ang, ln * .55 + push),
                                 (base[0] - nrm[0] * w * .45, base[1] - nrm[1] * w * .45)]
                        fire.poly(inner, HOT)

        # 2-9: claw tears, one per frame, then eaten away.
        for cl in claws:
            age = f - cl["start"]
            if age < 0 or age > 5:
                continue
            reveal = .55 if age == 0 else 1.0
            a, b, nrm = cl["a"], cl["b"], cl["nrm"]
            bend = cl["bend"] * (1 + .1 * rng.uniform(-1, 1))
            p1 = (lerp(a[0], b[0], .33) + nrm[0] * bend, lerp(a[1], b[1], .33) + nrm[1] * bend)
            p2 = (lerp(a[0], b[0], .66) + nrm[0] * bend * .8, lerp(a[1], b[1], .66) + nrm[1] * bend * .8)
            pts = bez(a, p1, p2, b, 40)
            pts = pts[:max(3, int(len(pts) * reveal))]
            shrink = [1, 1, 1, .8, .55, .35][age]
            ws = []
            for i in range(len(pts)):
                t = i / 39
                # A cut, not a carrot: widest a little past the middle, needle-sharp at both ends.
                w = (math.sin(math.pi * min(1, t)) ** 1.25) * (.7 + .5 * t) * cl["wd"] * shrink
                w *= 1 + .18 * math.sin(t * 23 + f * 1.7) * rng.uniform(.4, 1)   # torn, re-drawn edge
                ws.append(max(.5, w))
            heat = [1, 1, .9, .7, .45, .25][age]
            # From the fifth frame the tear breaks into pieces that drift apart.
            spans = [(0, 1)] if age < 4 else [(0, .3), (.4, .68), (.78, 1)] if age == 4 else [(.05, .22), (.48, .6), (.82, .95)]
            for (u0, u1) in spans:
                cut = pts
                drift = (age - 3) * U * .06 if age >= 4 else 0
                mid_i = int((u0 + u1) / 2 * (len(cut) - 1))
                nm = normals(cut)[min(mid_i, len(cut) - 1)]
                seg = [(x + nm[0] * drift * (1 if u0 < .5 else -1), y + nm[1] * drift * (1 if u0 < .5 else -1)) for x, y in cut]
                dark.poly(ribbon(seg, [w * 1.18 + U * .01 for w in ws], -.22, u0, u1), DARK, 225 * (1 if age < 3 else .7))
                fire.poly(ribbon(seg, ws, 0, u0, u1), RIM)
                if heat > .2:
                    fire.poly(ribbon(seg, [w * .64 for w in ws], .25, max(u0, .04), min(u1, .96)), BODY)
                if heat > .45:
                    fire.poly(ribbon(seg, [w * .32 for w in ws], .4, max(u0, .1), min(u1, .86)), HOT)
                if heat > .85:
                    fire.poly(ribbon(seg, [w * .11 for w in ws], .45, max(u0, .22), min(u1, .64)), CORE)

        # 3-11: fire tongues fling out, curl up, thin and break into drops.
        if 3 <= f <= 10:
            age = f - 3
            for k, tg in enumerate(tongues):
                if age == 0 and k >= 3:
                    continue  # the big ones first, the small ones a frame later
                grow = [.4, .85, 1.0, 1.0, .8, .6, .45, .3][age]
                out = tg["out"] * [0, .15, .4, .75, 1.1, 1.4, 1.7, 2.0][age]
                base = polar(tg["ang"], U * .06 + out)
                base = (base[0], base[1] - U * .07 * max(0, age - 2))  # everything rises as it cools
                heat = [1, 1, .9, .7, .5, .35, .22, .12][age]
                width = tg["wid"] * [1, 1, .95, .8, .62, .48, .36, .26][age]
                curl = tg["curl"] * (1 + .25 * age)
                if age >= 5 and k % 2 == 1:
                    continue  # some are already gone
                # From the fourth frame only the curled tip remains: a crescent flicked away.
                t0 = 0.0 if age < 4 else min(.6, .25 + (age - 4) * .12)
                pts = tongue(fire, base, tg["ang"] - .3 * curl * min(1, age / 4), tg["len"] * grow, width, curl,
                             tg["lift"] * (1 + .3 * age), heat, rng, t0=t0)
                if age >= 4:
                    # The tip pinches off into a drop.
                    tip = pts[-1]
                    v = (pts[-1][0] - pts[-6][0], pts[-1][1] - pts[-6][1])
                    drop(fire, (tip[0] + v[0] * .8, tip[1] + v[1] * .8), v, width * .55, heat)

        # Licks of flame off the tears: grow, curl up, pinch off into drops.
        for lk in licks:
            age = f - lk["start"]
            if age < 0 or age > 5:
                continue
            grow = [.5, 1.0, 1.0, .85, .7, .5][age]
            heat = [1, .95, .8, .6, .4, .25][age]
            width = lk["wid"] * [1, 1, .9, .75, .6, .45][age]
            base = (lk["at"][0], lk["at"][1] - U * .09 * max(0, age - 1))
            t0 = 0.0 if age < 3 else [.3, .45, .6][age - 3]
            pts = tongue(fire, base, lk["ang"], lk["len"] * grow, width, lk["curl"] * (1 + .2 * age), lk["lift"] * (1 + .3 * age), heat, rng, t0=t0)
            if age >= 4:
                v = (pts[-1][0] - pts[-6][0], pts[-1][1] - pts[-6][1])
                drop(fire, (pts[-1][0] + v[0] * .7, pts[-1][1] + v[1] * .7), v, width * .6, heat)

        # 4-13: droplets.
        for dp in drops:
            age = f - dp["born"]
            if age < 0 or age > 7:
                continue
            t = (age + 1) / 8
            dist = dp["speed"] * (1 - math.exp(-3.2 * t)) * .9 + U * .1
            pos = (C[0] + dp["dir"][0] * dist, C[1] + dp["dir"][1] * dist + U * .12 * t * t)
            size = dp["size"] * (1 - t * .7)
            drop(fire, pos, dp["dir"], size, 1 - t)

        # 6-13: dark wisps curling up and away.
        if 6 <= f <= 13:
            age = f - 6
            for w in wisps:
                r = U * (w["r"] + .05 * age)
                a0 = w["ang"]
                p0 = polar(a0, r)
                p0 = (p0[0], p0[1] - U * .05 * age)
                p3 = (p0[0] + w["curl"] * U * .16, p0[1] - U * (.22 + .02 * age))
                p1 = (p0[0] + w["curl"] * U * .12, p0[1] - U * .06)
                p2 = (p3[0] - w["curl"] * U * .1, p3[1] + U * .04)
                al = 220 * (1 - age / 8) ** 1.2
                if al > 6:
                    thorn(dark, bez(p0, p1, p2, p3, 20), U * .02 * (1 - age / 10), DARK, al, rng, hooks=1, side=w["curl"])

        # Fading fire is eaten by hard-edged holes, not faded.
        if f >= 6:
            m = noise_mask(seed * 77 + f, [0, .12, .22, .32, .44, .56, .7, .84][min(7, f - 6)])
            r, g, b, a = fire.img.split()
            fire.img = Image.merge("RGBA", (r, g, b, ImageChops.multiply(a, m)))

        # Neon bloom under the fire: saturated, never white.
        glow_a = fire.img.split()[3].filter(ImageFilter.GaussianBlur(U * .09))
        strength = [0, .35, .9, 1, .9, .75, .6, .5, .4, .32, .25, .18, .12, .06][f]
        glow_a = glow_a.point(lambda v: min(255, int(v * .95 * strength)))
        glow = Image.new("RGBA", (S, S), GLOW + (0,))
        glow.putalpha(glow_a)
        # A broad soft flash behind the burst frames.
        if 2 <= f <= 4:
            flash = Layer()
            flash.blob(C, U * [.5, .7, .6][f - 2], GLOW, [90, 70, 40][f - 2])
            flash.img = flash.img.filter(ImageFilter.GaussianBlur(U * .14))
            glow = Image.alpha_composite(flash.img, glow)

        out = Image.new("RGBA", (S, S), (0, 0, 0, 0))
        out = Image.alpha_composite(out, glow)
        out = Image.alpha_composite(out, dark.img)
        out = Image.alpha_composite(out, fire.img)
        frames.append(out)
    # One square crop round the impact point for all frames, just wide enough for the union
    # of everything drawn, so nothing is ever cut by the cell edge.
    half = 0
    for fr in frames:
        bb = fr.split()[3].point(lambda v: 255 if v > 6 else 0).getbbox()
        if bb:
            half = max(half, C[0] - bb[0], bb[2] - C[0], C[1] - bb[1], bb[3] - C[1])
    half = int(half * 1.04) + 4
    box = (int(C[0] - half), int(C[1] - half), int(C[0] + half), int(C[1] + half))
    print(f"cell half-width = {half / U:.2f} U")
    return [fr.crop(box).resize((CELL, CELL), Image.LANCZOS) for fr in frames], half / U


def sheet(frames, cols=4):
    rows = (len(frames) + cols - 1) // cols
    sh = Image.new("RGBA", (CELL * cols, CELL * rows), (0, 0, 0, 0))
    for i, fr in enumerate(frames):
        sh.paste(fr, ((i % cols) * CELL, (i // cols) * CELL))
    return sh


if __name__ == "__main__":
    frames, half_u = build()
    sheet(frames).save(sys.argv[1])
    if len(sys.argv) > 2:
        import os
        os.makedirs(sys.argv[2], exist_ok=True)
        for i, fr in enumerate(frames):
            fr.save(os.path.join(sys.argv[2], f"f{i:02d}.png"))
    print("frames", len(frames))
