"""Baroque gold filigree, generated as embossed strokes (see paint.Canvas.stroke).
Units are centimetres in a garment's flattened (UV) space."""
import math
import random


def _unit(a):
    return math.cos(a), math.sin(a)


def volute(start, heading, stem_len, R, turns, turn, w0, w1, step=0.05):
    """A gently arcing stem that rolls into a logarithmic spiral of `turns` turns,
    radius R shrinking to R*0.16, tapering from w0 to w1."""
    x, y = start
    a = heading
    pts, ws = [(x, y)], [w0]
    n_stem = max(2, int(stem_len / step))
    for i in range(1, n_stem + 1):
        a += turn * step / (4.5 * R)
        x += math.cos(a) * step
        y += math.sin(a) * step
        pts.append((x, y))
        ws.append(w0)
    total = turns * math.tau
    b = math.log(1 / 0.16) / total
    acc = 0.0
    while acc < total:
        r = R * math.exp(-b * acc)
        da = step / r
        acc += da
        a += turn * da
        x += math.cos(a) * step
        y += math.sin(a) * step
        pts.append((x, y))
        ws.append(w1 + (w0 - w1) * math.exp(-b * acc * 1.4))
    return pts, ws, a


def leaf(base, heading, length, width, bend=0.0, step=0.05):
    """Teardrop lobe with a slight bend; widest about a third along."""
    x, y = base
    a = heading
    pts, ws = [(x, y)], [width * 0.2]
    n = max(2, int(length / step))
    for i in range(1, n + 1):
        t = i / n
        a += bend * step / max(length, 1e-3)
        x += math.cos(a) * step
        y += math.sin(a) * step
        pts.append((x, y))
        ws.append(width * (math.sin(math.pi * min(1.0, t ** 0.62)) ** 1.1) * (1 - t) ** 0.3 + 0.015)
    return pts, ws


def acanthus(base, heading, length, width, turn):
    """Three-lobed acanthus leaf: a long central lobe curling over, two side lobes."""
    out = [leaf(base, heading, length, width, bend=turn * 1.2)]
    for side, k in ((1, 0.62), (-1, 0.5)):
        out.append(leaf(base, heading + side * 0.75, length * k, width * 0.72, bend=-side * 1.4))
    return out


def scroll_motif(origin, heading, size, turn, rng):
    """Stem rolling into a volute, an acanthus leaf at the root and a small
    counter-scroll; size ~ overall height in cm."""
    out = []
    w = 0.055 * size + 0.05
    stem, ws, _ = volute(origin, heading, size * 0.55, size * 0.34, 1.55 + rng.uniform(-0.1, 0.15), turn,
                         w, w * 0.32)
    out.append((stem, ws))
    i = int(0.18 * len(stem))
    (x0, y0), (x1, y1) = stem[i], stem[i + 1]
    tang = math.atan2(y1 - y0, x1 - x0)
    out.extend(acanthus(stem[i], tang - turn * 0.95, size * 0.48, size * 0.085 + 0.05, -turn))
    curl, cw, _ = volute(stem[max(1, int(0.08 * len(stem)))], heading - turn * 2.2, size * 0.12, size * 0.13,
                         1.2, -turn, w * 0.7, w * 0.3)
    out.append((curl, cw))
    return out


def resample_poly(pts, spacing):
    out = [pts[0]]
    acc = 0.0
    for (x0, y0), (x1, y1) in zip(pts, pts[1:]):
        seg = math.hypot(x1 - x0, y1 - y0)
        if seg < 1e-9:
            continue
        t = (spacing - acc) / seg
        while t <= 1.0:
            out.append((x0 + (x1 - x0) * t, y0 + (y1 - y0) * t))
            t += spacing / seg
        acc = (acc + seg) % spacing
    return out


def offset_poly(pts, dist):
    """Offset a polyline to its left (positive dist) using averaged normals."""
    out = []
    n = len(pts)
    for i in range(n):
        x0, y0 = pts[max(i - 1, 0)]
        x1, y1 = pts[min(i + 1, n - 1)]
        dx, dy = x1 - x0, y1 - y0
        l = math.hypot(dx, dy) or 1.0
        out.append((pts[i][0] - dy / l * dist, pts[i][1] + dx / l * dist))
    return out


def border(guide, inset, pitch, size, rng, vine_w=0.17, inward=1):
    """Running scroll border: an edge line, a vine `inset` cm inside `guide`, and
    alternating scrolls every `pitch` cm, curling toward and away from the edge."""
    strokes = []
    edge = offset_poly(guide, 0.9 * inward)
    strokes.append((edge, [vine_w * 0.7] * len(edge)))
    vine = offset_poly(guide, inset * inward)
    strokes.append((vine, [vine_w] * len(vine)))
    marks = resample_poly(vine, pitch)
    for k, p in enumerate(marks[1:-1], 1):
        q = marks[k + 1]
        tang = math.atan2(q[1] - p[1], q[0] - p[0])
        up = k % 2 == 0
        if up:
            strokes.extend(scroll_motif(p, tang + 0.75 * inward, size, inward, rng))
        else:
            strokes.extend(scroll_motif(p, tang - 0.55 * inward, size * 0.62, -inward, rng))
    return strokes


def flourish(origin, heading, size, turn, rng, depth=2):
    """Large branching acanthus scroll for the coat tails."""
    strokes = []
    w = 0.03 * size + 0.08
    stem, ws, _ = volute(origin, heading, size * 0.75, size * 0.26, 1.35, turn, w, w * 0.3)
    strokes.append((stem, ws))
    n = len(stem)
    for frac, side, s in ((0.14, -1, 0.46), (0.30, 1, 0.36), (0.46, -1, 0.26)):
        i = int(frac * (n - 1))
        (x0, y0), (x1, y1) = stem[i], stem[min(i + 1, n - 1)]
        tang = math.atan2(y1 - y0, x1 - x0)
        a = tang + side * turn * 0.85
        if depth > 1 and s > 0.3:
            strokes.extend(flourish(stem[i], a, size * s, -side * turn, rng, depth - 1))
        else:
            strokes.extend(scroll_motif(stem[i], a, size * s, -side * turn, rng))
        strokes.extend(acanthus(stem[i], tang - side * turn * 0.6, size * 0.2, size * 0.03 + 0.08, side * turn))
    return strokes


def damask_tile(cx, cy, size, rng):
    """Symmetric fleur motif for tone-on-tone lining patterns."""
    strokes = []
    for mirror in (1, -1):
        for heading, s, turn in ((math.pi / 2 + 0.35 * mirror, 1.0, mirror), (math.pi / 2 + 1.25 * mirror, 0.7, mirror),
                                 (-math.pi / 2 + 0.5 * mirror, 0.6, -mirror)):
            strokes.extend(scroll_motif((cx, cy), heading, size * s, turn, rng))
    strokes.append(leaf((cx, cy), math.pi / 2, size * 0.9, size * 0.1, 0))
    return strokes


def rinceau(guide, inset, wavelength, amplitude, rng, stem_w=0.16, inward=1, edge_line=True):
    """Classic running scroll: a wavy stem inside the edge, and in every hollow of
    the wave a branch rolls into a volute, with an acanthus leaf at the fork."""
    strokes = []
    if edge_line:
        edge = offset_poly(guide, 0.8 * inward)
        strokes.append((edge, [stem_w * 0.65] * len(edge)))
    base = resample_poly(offset_poly(guide, inset * inward), 0.08)
    n = len(base)
    # Wavy stem: offset each base point along its normal by a sine of arc length.
    stem = []
    normals = []
    for i in range(n):
        x0, y0 = base[max(i - 1, 0)]
        x1, y1 = base[min(i + 1, n - 1)]
        dx, dy = x1 - x0, y1 - y0
        l = math.hypot(dx, dy) or 1.0
        nx, ny = -dy / l * inward, dx / l * inward
        s = i * 0.08
        off = amplitude * math.sin(s / wavelength * math.tau)
        stem.append((base[i][0] + nx * off, base[i][1] + ny * off))
        normals.append((nx, ny))
    strokes.append((stem, [stem_w] * len(stem)))
    half = wavelength / 2
    k = 0
    s = wavelength * 0.25
    while s < (n - 1) * 0.08 - wavelength * 0.25:
        i = int(s / 0.08)
        (x0, y0), (x1, y1) = stem[max(i - 1, 0)], stem[min(i + 1, n - 1)]
        tang = math.atan2(y1 - y0, x1 - x0)
        crest = 1 if k % 2 == 0 else -1  # +1: crest toward the inside
        # The branch leaves the crest heading forward and away from the stem axis,
        # then rolls back into the hollow beside it.
        heading = tang - crest * inward * 0.55
        turn = crest * inward
        R = amplitude * 0.95 + 0.25
        branch, bw, _ = volute(stem[i], heading, half * 0.32, R, 1.6 + rng.uniform(-0.1, 0.1), turn,
                               stem_w * 0.92, stem_w * 0.3)
        strokes.append((branch, bw))
        strokes.extend(acanthus(stem[i], tang + crest * inward * 0.5, half * 0.42, amplitude * 0.24 + 0.08,
                                -turn))
        # A bead on the opposite side.
        j = min(n - 1, i + int(half * 0.5 / 0.08))
        bx, by = stem[j]
        nx, ny = normals[j]
        cx, cy = bx - crest * nx * amplitude * 0.75, by - crest * ny * amplitude * 0.75
        strokes.append(([(cx - 0.01, cy), (cx + 0.01, cy)], [stem_w * 1.1, stem_w * 1.1]))
        s += half
        k += 1
    return strokes


def grand_scroll(origin, heading, size, turn, rng):
    """A bold S: the stem bends one way, swings back and rolls into a large volute;
    two counter-volutes and acanthus leaves sprout from the outside of each bend."""
    strokes = []
    w = 0.022 * size + 0.12
    x, y = origin
    a = heading
    pts, ws = [(x, y)], [w]
    step = 0.05
    L1 = size * 0.45
    for i in range(int(L1 / step)):
        a -= turn * step / (size * 0.55)
        x += math.cos(a) * step
        y += math.sin(a) * step
        pts.append((x, y))
        ws.append(w)
    spiral_pts, sw, _ = volute((x, y), a, size * 0.25, size * 0.2, 1.45, turn, w, w * 0.28)
    pts += spiral_pts[1:]
    ws += sw[1:]
    strokes.append((pts, ws))
    n = len(pts)
    for frac, side, s in ((0.12, 1, 0.42), (0.34, -1, 0.34), (0.52, 1, 0.24)):
        i = int(frac * (n - 1))
        (x0, y0), (x1, y1) = pts[i], pts[min(i + 1, n - 1)]
        tang = math.atan2(y1 - y0, x1 - x0)
        b, bw, _ = volute(pts[i], tang + side * turn * 0.9, size * s * 0.35, size * s * 0.32, 1.4,
                          -side * turn, w * 0.7, w * 0.25)
        strokes.append((b, bw))
        strokes.extend(acanthus(pts[i], tang - side * turn * 0.7, size * s * 0.55, size * s * 0.07 + 0.06,
                                side * turn))
    return strokes
