"""Seasonal versions of the four harbour plates, made by editing the paintings.

usage: prepare_seasons.py <assets_dir> <out_dir> [season ...]

<assets_dir> is Mistport/Assets.xcassets (reads CityLive{Day,Sunset,Night,
DeepNight} — the cleaned plates). Each season is designed on the day plate;
the per-pixel colour change (gain) found there is carried to the sunset,
night and deep-night plates, so the same leaf or roof changes the same way
under every light. The sky is graded per plate instead.
Writes City<Season><Time>.jpg (2800px) and check-<season>.jpg previews.
Seasons: spring, summer, autumn, winter.
"""
import os
import sys

import cv2
import numpy as np

sys.path.insert(0, os.path.dirname(__file__))

TIMES = ["Day", "Sunset", "Night", "DeepNight"]
N = 2800
RNG_SEED = 20260927


def load(assets, t):
    return cv2.imread(os.path.join(assets, f"CityLive{t}.imageset", f"CityLive{t}.jpg")).astype(np.float32) / 255


def smoothstep(a, b, x):
    t = np.clip((x - a) / (b - a), 0, 1)
    return t * t * (3 - 2 * t)


def hsv(img):
    h = cv2.cvtColor((np.clip(img, 0, 1) * 255).astype(np.uint8), cv2.COLOR_BGR2HSV_FULL).astype(np.float32)
    return h[..., 0] * 360 / 256, h[..., 1] / 255, h[..., 2] / 255


def lum(img):
    return 0.114 * img[..., 0] + 0.587 * img[..., 1] + 0.299 * img[..., 2]


def feather(mask, sigma):
    return cv2.GaussianBlur(mask.astype(np.float32), (0, 0), sigma)


def poly_mask(points, soft=2.0):
    m = np.zeros((N, N), np.uint8)
    cv2.fillPoly(m, [np.array([[int(x * N), int(y * N)] for x, y in points], np.int32)], 1)
    return feather(m, soft) if soft else m.astype(np.float32)


def skyline_mask():
    """1 above the land (from the traced skyline in CityLivingScene.swift)."""
    import re
    src = open(os.path.join(os.path.dirname(__file__), "../../mistport-ios/Mistport/CityLivingScene.swift")).read()
    body = src.split("static let skyline: [Double] = [")[1].split("]")[0]
    vals = np.array([float(v) for v in re.findall(r"[0-9.]+", body)])
    xs = (np.arange(len(vals)) + 0.5) / len(vals)
    line = np.interp((np.arange(N) + 0.5) / N, xs, vals)
    rows = (np.arange(N)[:, None] + 0.5) / N
    return feather(rows < line[None, :] + 0.002, 1.5)


class Masks:
    def __init__(self, day):
        self.rows = (np.arange(N)[:, None] + 0.5) / N * np.ones((1, N))
        self.cols = (np.arange(N)[None, :] + 0.5) / N * np.ones((N, 1))
        h, s, v = hsv(day)
        self.h, self.s, self.v = h, s, v
        self.sky = skyline_mask()
        land = 1 - self.sky
        # Lit foliage: yellow-green to teal, saturated enough.
        hue_green = np.clip(1 - np.abs(h - 105) / 70, 0, 1)
        self.foliage = feather(hue_green * smoothstep(0.16, 0.34, s) * smoothstep(0.12, 0.25, v), 1.2) * land
        # Wisteria blossom.
        hue_purple = np.clip(1 - np.abs(h - 282) / 30, 0, 1)
        self.wisteria = feather(hue_purple * smoothstep(0.25, 0.45, s) * smoothstep(0.12, 0.25, v), 1.2) * land
        # Canopies: foliage regions grouped into individual trees.
        canopy = (cv2.dilate((self.foliage > 0.3).astype(np.uint8), np.ones((15, 15), np.uint8)))
        self.tree_count, self.trees = cv2.connectedComponents(canopy)
        self.canopy = feather(canopy, 6) * land
        # Open water: bay and canals (for keeping water free of snow).
        sea = poly_mask([(0.452, 0.2440), (0.860, 0.2440), (0.850, 0.2700), (0.780, 0.2850), (0.700, 0.2950),
                         (0.655, 0.3050), (0.640, 0.3350), (0.520, 0.3380), (0.472, 0.3300), (0.472, 0.3000), (0.458, 0.2700)], 3)
        blue = np.clip(1 - np.abs(h - 222) / 25, 0, 1) * smoothstep(0.18, 0.30, s) * smoothstep(0.45, 0.6, v)
        city_water = feather(blue > 0.5, 3) * (self.rows > 0.33) * (self.rows < 0.63) * (self.cols > 0.30) * (self.cols < 0.82)
        self.water = np.clip(sea + city_water, 0, 1)
        # Slate roofs: cool blue-violet, moderately saturated, below the skyline.
        hue_slate = np.clip(1 - np.abs(h - 232) / 26, 0, 1)
        slate = hue_slate * smoothstep(0.16, 0.30, s) * (1 - smoothstep(0.62, 0.72, s)) * smoothstep(0.18, 0.30, v)
        self.roofs = feather(slate, 1.2) * land * (1 - self.water) * (self.rows > 0.26)
        # Ground: stairs, landings, plaza, promenade (pale stone, low saturation).
        ground_zone = np.clip(
            poly_mask([(0.14, 1.0), (0.27, 0.80), (0.45, 0.77), (0.47, 0.74), (0.59, 0.735), (0.59, 0.69), (0.53, 0.68),
                       (0.50, 0.655), (0.52, 0.62), (0.47, 0.63), (0.44, 0.62), (0.55, 0.585), (0.62, 0.60), (0.68, 0.60),
                       (0.70, 0.64), (0.69, 0.78), (0.73, 0.80), (0.86, 1.0)], 6), 0, 1)
        pale = (1 - smoothstep(0.18, 0.32, s)) * smoothstep(0.30, 0.45, v)
        self.ground = feather(ground_zone * pale, 1.5) * (1 - self.foliage) * (1 - self.wisteria)
        # Mountains: land in the upper band on both sides of the bay.
        self.mountains = land * (1 - smoothstep(0.28, 0.33, self.rows)) * np.clip(
            smoothstep(0.47, 0.42, self.cols) + smoothstep(0.80, 0.86, self.cols), 0, 1)


def recolor(img, weight, target_bgr, keep_lum=True, amount=1.0):
    """Move colour toward target while keeping each pixel's lightness."""
    target = np.array(target_bgr, np.float32)
    l = lum(img)[..., None]
    t = target * (l / max(lum(target[None, None])[0, 0], 1e-3)) if keep_lum else target
    w = (weight * amount)[..., None]
    return img * (1 - w) + np.clip(t, 0, 1.4) * w


def value_noise(scale, seed):
    rng = np.random.default_rng(seed)
    small = rng.random((max(2, int(N / scale)), max(2, int(N / scale)))).astype(np.float32)
    return cv2.resize(small, (N, N), interpolation=cv2.INTER_CUBIC)


# ---------------------------------------------------------------- seasons

def summer(day, m):
    out = day.copy()
    # Wisteria has finished: its trusses turn to leaf.
    out = recolor(out, m.wisteria, (0.20, 0.55, 0.28), amount=0.85)
    # Deeper, more saturated greens.
    hsv8 = cv2.cvtColor((np.clip(out, 0, 1) * 255).astype(np.uint8), cv2.COLOR_BGR2HSV_FULL).astype(np.float32)
    w = m.foliage
    hsv8[..., 1] = np.clip(hsv8[..., 1] * (1 + 0.35 * w), 0, 255)
    hsv8[..., 2] = hsv8[..., 2] * (1 - 0.10 * w)
    out = cv2.cvtColor(hsv8.astype(np.uint8), cv2.COLOR_HSV2BGR_FULL).astype(np.float32) / 255
    # Stronger summer sea.
    sea_w = m.water[..., None] * 0.25
    out = out * (1 - sea_w) + out * np.array([1.12, 1.0, 0.86], np.float32) * sea_w
    return out


def autumn(day, m):
    out = day.copy()
    rng = np.random.default_rng(RNG_SEED + 3)
    palette = [(0.10, 0.45, 0.95), (0.08, 0.30, 0.90), (0.10, 0.20, 0.78), (0.12, 0.62, 0.95), (0.10, 0.38, 0.70)]
    hues = np.array([palette[rng.integers(len(palette))] for _ in range(m.tree_count)], np.float32)
    hues[0] = palette[0]
    per_tree = hues[m.trees]                    # BGR target per canopy
    per_tree = cv2.GaussianBlur(per_tree, (0, 0), 3)
    l = lum(out)[..., None]
    target = per_tree * (l / np.maximum(lum(per_tree)[..., None], 1e-3))
    w = (m.foliage * 0.92)[..., None]
    out = out * (1 - w) + np.clip(target, 0, 1.3) * w
    # Wisteria leaves yellow-brown.
    out = recolor(out, m.wisteria, (0.18, 0.50, 0.72), amount=0.8)
    # Forested slopes rust and gold.
    out = recolor(out, m.mountains * m.foliage, (0.12, 0.40, 0.72), amount=0.6)
    # Leaf litter on the ground, thinner down the walked middle of the stairs.
    litter = (value_noise(6, RNG_SEED + 5) > 0.72).astype(np.float32) * (value_noise(40, RNG_SEED + 6) > 0.35)
    walked = 1 - 0.8 * np.exp(-((m.cols - 0.635) / 0.035) ** 2) * (m.rows > 0.66)
    litter = feather(litter, 1.0) * m.ground * walked
    leaf_col = cv2.GaussianBlur(np.stack([value_noise(3, RNG_SEED + 7) * 0.1 + 0.05,
                                          value_noise(3, RNG_SEED + 8) * 0.35 + 0.18,
                                          value_noise(3, RNG_SEED + 9) * 0.3 + 0.62], -1), (0, 0), 0.8)
    lw = (litter * 0.85)[..., None]
    out = out * (1 - lw) + leaf_col * lum(out)[..., None] * 1.25 * lw
    # Softer, warmer air.
    out = out * np.array([0.94, 0.98, 1.04], np.float32)
    return out


def winter(day, m):
    out = day.copy()
    l = lum(out)[..., None]
    snow = np.array([1.0, 0.97, 0.94], np.float32)       # BGR, faintly blue
    detail = (l - cv2.GaussianBlur(l, (0, 0), 2)[..., None]) if l.ndim == 3 else 0
    # Roofs under snow, keeping tile lines and edges as faint texture.
    roof_w = (m.roofs * 0.88)[..., None]
    roof_snow = snow * (0.80 + 0.20 * smoothstep(0.15, 0.6, l)) + detail * 1.5
    out = out * (1 - roof_w) + roof_snow * roof_w
    # Snow on the ground with a trodden, darker path down the middle.
    path = np.exp(-((m.cols - 0.635) / 0.030) ** 2) * (m.rows > 0.62) \
        + np.exp(-((m.rows - (0.60 + (m.cols - 0.55) * 0.35)) / 0.012) ** 2) * (m.cols > 0.50) * (m.cols < 0.71)
    path = np.clip(path, 0, 1)
    ground_snow = snow * (0.86 + 0.14 * smoothstep(0.3, 0.8, l)) + detail * 1.2
    trodden = out * np.array([0.92, 0.9, 0.9], np.float32) * 0.9 + snow * 0.25
    ground = ground_snow * (1 - path[..., None] * 0.75) + trodden * path[..., None] * 0.75
    gw = (m.ground * 0.9)[..., None]
    out = out * (1 - gw) + ground * gw
    # Trees: lit crowns carry snow, shaded parts go bare and grey-brown.
    grey = np.repeat(l, 3, -1) * np.array([0.9, 0.92, 1.0], np.float32)
    fw = m.foliage[..., None]
    out = out * (1 - fw) + (snow * (0.78 + 0.22 * smoothstep(0.2, 0.6, l)) + detail) * fw
    cw = (m.canopy * (1 - m.foliage) * 0.6)[..., None]
    out = out * (1 - cw) + grey * 0.8 * cw
    # Wisteria: bare vines.
    ww = (m.wisteria * 0.9)[..., None]
    out = out * (1 - ww) + np.repeat(l, 3, -1) * np.array([0.55, 0.62, 0.72], np.float32) * ww
    # Snow-capped mountains, whiter higher up.
    cap = m.mountains * smoothstep(0.30, 0.16, m.rows) * smoothstep(0.2, 0.5, l[..., 0])
    capw = (cap * 0.85)[..., None]
    out = out * (1 - capw) + snow * (0.75 + 0.25 * l) * capw
    # Top edges of walls, sills and balustrades: a thin line of snow.
    lum2 = l[..., 0]
    up = lum2 - np.roll(lum2, 4, axis=0)
    edge = smoothstep(0.08, 0.2, up) * (1 - m.water) * (1 - m.sky) * (m.rows > 0.30)
    edge = feather(cv2.dilate(edge, np.ones((3, 1), np.float32)), 0.8)
    ew = (edge * 0.7)[..., None]
    out = out * (1 - ew) + snow * 0.95 * ew
    # Cold, pale air.
    g = lum(out)[..., None]
    out = out * 0.82 + g * 0.18
    out = out * np.array([1.05, 1.0, 0.95], np.float32)
    return out


def spring(day, m):
    out = day.copy()
    rng = np.random.default_rng(RNG_SEED + 11)
    # About a third of the trees flower pink or white.
    chosen = rng.random(m.tree_count) < 0.38
    chosen[0] = False
    shade = rng.random(m.tree_count)
    blossom = chosen[m.trees].astype(np.float32)
    tint = np.where(shade[m.trees][..., None] < 0.6, np.array([0.86, 0.74, 1.0], np.float32), np.array([0.96, 0.94, 1.0], np.float32))
    speckle = smoothstep(0.35, 0.75, value_noise(2.5, RNG_SEED + 12))
    w = (feather(blossom, 2) * m.foliage * (0.55 + 0.4 * speckle))[..., None]
    l = lum(out)[..., None]
    out = out * (1 - w) + np.clip(tint * (0.55 + 0.75 * l), 0, 1.2) * w
    # Fresh greens elsewhere.
    hsv8 = cv2.cvtColor((np.clip(out, 0, 1) * 255).astype(np.uint8), cv2.COLOR_BGR2HSV_FULL).astype(np.float32)
    fw = m.foliage * (1 - feather(blossom, 2))
    hsv8[..., 0] = hsv8[..., 0] - 6 * fw * 256 / 360
    hsv8[..., 2] = np.clip(hsv8[..., 2] * (1 + 0.06 * fw), 0, 255)
    out = cv2.cvtColor(hsv8.astype(np.uint8), cv2.COLOR_HSV2BGR_FULL).astype(np.float32) / 255
    # A few petals on the stairs.
    petals = feather((value_noise(4, RNG_SEED + 13) > 0.86).astype(np.float32), 0.8) * m.ground * 0.5
    out = out * (1 - petals[..., None]) + np.array([0.86, 0.78, 1.0], np.float32) * lum(out)[..., None] * 1.15 * petals[..., None]
    return out


SEASONS = {"spring": spring, "summer": summer, "autumn": autumn, "winter": winter}

SKY_GRADE = {   # per season, applied to the sky of the non-day plates (BGR multipliers, desaturation)
    "spring": ((1.0, 1.0, 1.0), 0.0),
    "summer": ((1.03, 1.0, 0.98), 0.0),
    "autumn": ((0.96, 0.99, 1.03), 0.08),
    "winter": ((1.05, 1.0, 0.96), 0.25),
}


def main():
    assets, out = sys.argv[1], sys.argv[2]
    which = sys.argv[3:] or list(SEASONS)
    os.makedirs(out, exist_ok=True)
    plates = {t: load(assets, t) for t in TIMES}
    day = plates["Day"]
    m = Masks(day)
    print("trees", m.tree_count)
    for name in which:
        new_day = np.clip(SEASONS[name](day, m), 0, 1)
        land = (1 - m.sky)[..., None]
        gain = np.clip((new_day + 0.02) / (day + 0.02), 0.15, 6.0)
        mult, desat = SKY_GRADE[name]
        results = {}
        for t in TIMES:
            if t == "Day":
                img = new_day
            else:
                src = plates[t]
                changed = src * gain
                sky = src * np.array(mult, np.float32)
                sky = sky * (1 - desat) + lum(sky)[..., None] * desat
                img = np.clip(changed * land + sky * (1 - land), 0, 1)
            results[t] = img
            cv2.imwrite(os.path.join(out, f"City{name.capitalize()}{t}.jpg"), (img * 255).astype(np.uint8),
                        [cv2.IMWRITE_JPEG_QUALITY, 90])
        strip = np.hstack([cv2.resize(results[t], (700, 700), interpolation=cv2.INTER_AREA) for t in TIMES])
        cv2.imwrite(os.path.join(out, f"check-{name}.jpg"), (strip * 255).astype(np.uint8))
        crop = results["Day"][int(0.30 * N):int(0.80 * N), int(0.0 * N):int(1.0 * N)]
        cv2.imwrite(os.path.join(out, f"check-{name}-detail.jpg"), cv2.resize((crop * 255).astype(np.uint8), (1600, 800)))
        print("wrote", name)


if __name__ == "__main__":
    main()
