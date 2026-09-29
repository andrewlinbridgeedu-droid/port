"""Hub plates for the four seasons and winter snow (2026-09-28 paintings).

usage: prepare_seasons.py <src_dir> <skyline.txt> <out_dir> [set ...]

<src_dir> holds the user's paintings (1672×941, one composition), and
<src_dir>/sr-x4/<name>-x4.png their ×4 Real-ESRGAN upscales:
  <season>1 day, <season>2 sunset, <season>3dark unlit night, <season>3 lit night
  winter1snow … winter3snowdark: the same winter with snow lying.
Every painting is warped onto spring1 with a homography measured on the
originals, then the upscale is reduced to 4096 wide. For each set P
(CitySpring, CitySummer, CityAutumn, CityWinter, CityWinterSnow) writes
  P+Day.jpg, P+Sunset.jpg, P+Night.jpg (unlit)
  P+Lights.jpg       additive light layer, lit night − unlit night
  P+LightOrder.png   2048 wide; R = 1 − switch-on time, G = switch-off time
and once
  CityWinterSnowOrder.png  2048 wide; R = 1 − the snow cover at which that
                           spot turns white (roofs, trees and ledges first,
                           open ground later, in soft patches)
plus previews check-*.jpg. Light groups: see prepare.py.
"""
import ast
import os
import sys

import cv2
import numpy as np

W, H = 4096, 2305
OW, OH = 2048, 1153
SETS = {
    "CitySpring": ("spring1", "spring2", "spring3dark", "spring3"),
    "CitySummer": ("summer1", "summer2", "summer3dark", "summer3"),
    "CityAutumn": ("autumn1", "autumn2", "autumn3dark", "autumn3"),
    "CityWinter": ("winter1", "winter2", "winter3dark", "winter3"),
    "CityWinterSnow": ("winter1snow", "winter2snow", "winter3snowdark", "winter3snow"),
}
REFERENCE = "spring1"

eq = cv2.createCLAHE(3.0, (8, 8))
sift = cv2.SIFT_create(8000)
_features = {}


def features(src, name):
    if name not in _features:
        img = cv2.imread(f"{src}/{name}.png")
        _features[name] = sift.detectAndCompute(eq.apply(cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)), None)
    return _features[name]


def to_reference(src, name):
    """Homography taking painting `name` onto the reference (original pixels)."""
    if name == REFERENCE:
        return np.eye(3), 0, 0.0
    ka, kb = features(src, name), features(src, REFERENCE)
    good = [m for m, n in cv2.BFMatcher().knnMatch(ka[1], kb[1], k=2) if m.distance < 0.72 * n.distance]
    a = np.float32([ka[0][m.queryIdx].pt for m in good])
    b = np.float32([kb[0][m.trainIdx].pt for m in good])
    M, inl = cv2.findHomography(a, b, cv2.RANSAC, 2.5)
    ok = inl.ravel() == 1
    res = np.linalg.norm(cv2.perspectiveTransform(a[ok][None], M)[0] - b[ok], axis=1)
    return M, int(ok.sum()), float(np.median(res))


def plate(src, name):
    oh, ow = 941, 1672
    M, n, r = to_reference(src, name)
    big = cv2.imread(f"{src}/sr-x4/{name}-x4.png")
    small = cv2.resize(big, (W, H), interpolation=cv2.INTER_AREA)
    S = np.diag([W / ow, H / oh, 1.0])
    print(f"  {name}: {n} inliers, residual {r:.2f}px")
    return cv2.warpPerspective(small, S @ M @ np.linalg.inv(S), (W, H), flags=cv2.INTER_LANCZOS4,
                               borderMode=cv2.BORDER_REFLECT)


def lum(im):
    return 0.299 * im[..., 2] + 0.587 * im[..., 1] + 0.114 * im[..., 0]


def light_groups(lit, lights, seed):
    """Groups and switch times on the 2048 grid (see prepare.py)."""
    lw = cv2.resize(lit, (OW, OH), interpolation=cv2.INTER_AREA)
    lg = cv2.resize(lights, (OW, OH), interpolation=cv2.INTER_AREA)
    l_lit, l_add = lum(lw), lum(lg)
    warm = lw[..., 2] - lw[..., 0]
    tophat = l_lit - cv2.GaussianBlur(l_lit, (0, 0), 5)
    yy = np.arange(OH, dtype=np.float32)[:, None] / OH * np.ones((1, OW), np.float32)
    xx = np.arange(OW, dtype=np.float32)[None, :] / OH * np.ones((OH, 1), np.float32)
    core = (((tophat > 0.06) & (l_lit > 0.30)) | (l_lit > 0.72)) & (warm > 0.08) & (l_add > 0.14)
    core = cv2.morphologyEx(core.astype(np.uint8), cv2.MORPH_OPEN, np.ones((2, 2), np.uint8))
    near = yy > 0.45
    grown = np.where(near, cv2.dilate(core, cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (9, 9))),
                     cv2.dilate(core, np.ones((3, 3), np.uint8))).astype(np.uint8)
    count, cores = cv2.connectedComponents(grown)
    area = np.bincount(cores.ravel(), minlength=count).astype(np.float32)
    peak = np.zeros(count, np.float32)
    np.maximum.at(peak, cores.ravel(), l_add.ravel())
    cy = np.zeros(count, np.float32)
    cx = np.zeros(count, np.float32)
    np.add.at(cy, cores.ravel(), yy.ravel())
    np.add.at(cx, cores.ravel(), xx.ravel())
    cy /= np.maximum(area, 1)
    cx /= np.maximum(area, 1)
    best = np.zeros((OH, OW), np.float32)
    label = np.zeros((OH, OW), np.int32)
    bins = np.quantile(peak[1:], [0, 0.25, 0.5, 0.75, 0.9, 1.0])
    for b in range(len(bins) - 1):
        sel = np.zeros(count, bool)
        sel[1:] = (peak[1:] >= bins[b]) & (peak[1:] <= bins[b + 1] + 1e-6)
        if not sel.any():
            continue
        mask = sel[cores]
        dist, idx = cv2.distanceTransformWithLabels((~mask).astype(np.uint8), cv2.DIST_L2, 5,
                                                    labelType=cv2.DIST_LABEL_PIXEL)
        ys, xs = np.nonzero(mask)
        lut = np.zeros(idx.max() + 1, np.int32)
        lut[idx[ys, xs]] = cores[ys, xs]
        score = bins[b + 1] / (1 + dist / (6 + 60 * bins[b + 1]))
        take = score > best
        best = np.where(take, score, best)
        label = np.where(take, lut[idx], label)
    label = np.where((l_add > 0.012) | (cores > 0), label, 0)
    # Street lamps: the lights that throw the most light around them.
    thrown = np.zeros(count, np.float32)
    np.add.at(thrown, label.ravel(), l_add.ravel())
    thrown[0] = 0
    street = [i for i in np.argsort(-thrown) if i > 0 and cy[i] >= 0.38][:40]
    street_mask = np.isin(cores, street)
    if street_mask.any():
        d_any = cv2.distanceTransform((cores == 0).astype(np.uint8), cv2.DIST_L2, 5)
        d_st, idx = cv2.distanceTransformWithLabels((~street_mask).astype(np.uint8), cv2.DIST_L2, 5,
                                                    labelType=cv2.DIST_LABEL_PIXEL)
        ys, xs = np.nonzero(street_mask)
        lut = np.zeros(idx.max() + 1, np.int32)
        lut[idx[ys, xs]] = cores[ys, xs]
        pool = (label > 0) & (yy >= 0.45) & (d_any > 6) & (d_st < 220) & ~np.isin(label, street)
        label = np.where(pool, lut[idx], label)
    rng = np.random.default_rng(seed)
    on = np.zeros(count, np.float32)
    off = np.zeros(count, np.float32)
    street = set(street)
    for i in range(1, count):
        if 1.72 < cx[i] < 1.77 and 0.24 < cy[i] < 0.30:          # the lighthouse
            on[i], off[i] = 0.0, 0.99
        elif i in street:
            on[i], off[i] = rng.uniform(0.02, 0.30), rng.uniform(0.84, 0.97)
        else:
            on[i] = rng.uniform(0.04, 1.0) ** 0.8
            # Share of windows that burn all night: the palace and the noble
            # houses on the castle hill keep many lit, the middle-class
            # quarter on the left some, the harbour and works few.
            if 1.06 < cx[i] < 1.44 and cy[i] < 0.215:
                keep = 0.50          # the palace on the castle hill
            elif 0.98 < cx[i] < 1.50 and cy[i] < 0.33:
                keep = 0.25          # noble houses around it
            elif cx[i] < 0.70:
                keep = 0.125         # middle-class quarter on the left
            else:
                keep = 0.0625        # harbour, works and market
            off[i] = rng.uniform(0.82, 0.99) if rng.uniform() < keep else rng.uniform(0.02, 0.78)
    lamps = sorted((round(float(cx[i]), 3), round(float(cy[i]), 3)) for i in street)
    return label, on, off, lamps


def build(src, sky, out, prefix, names, seed):
    print(prefix)
    day, sunset, dark, lit = (plate(src, n) for n in names)
    q = [cv2.IMWRITE_JPEG_QUALITY, 90]
    cv2.imwrite(f"{out}/{prefix}Day.jpg", day, q)
    cv2.imwrite(f"{out}/{prefix}Sunset.jpg", sunset, q)
    cv2.imwrite(f"{out}/{prefix}Night.jpg", dark, q)
    d, l = dark.astype(np.float32) / 255, lit.astype(np.float32) / 255
    sky_y = np.interp(np.arange(W), (np.arange(len(sky)) + 0.5) / len(sky) * W, sky * H)
    below = np.clip((np.arange(H)[:, None] - sky_y[None, :] + 4) / 8, 0, 1).astype(np.float32)
    lights = np.clip(l - d - 1.5 / 255, 0, 1) * below[..., None]
    cv2.imwrite(f"{out}/{prefix}Lights.jpg", (lights * 255 + 0.5).astype(np.uint8), [cv2.IMWRITE_JPEG_QUALITY, 92])
    label, on, off, lamps = light_groups(l, lights, seed)
    order = np.zeros((OH, OW, 3), np.float32)
    order[..., 2] = np.where(label > 0, 1 - on[label], 0)
    order[..., 1] = np.where(label > 0, off[label], 0)
    cv2.imwrite(f"{out}/{prefix}LightOrder.png", (order * 255 + 0.5).astype(np.uint8))
    print(f"  {len(on) - 1} light groups, street lamps: {lamps}")
    lab = cv2.resize(label.astype(np.float32), (W, H), interpolation=cv2.INTER_NEAREST).astype(np.int32)
    for tag, on_f, off_f in [("dusk30", 0.30, 0), ("deep", 1.0, 0.80)]:
        show = (on[lab] <= on_f) & (off[lab] > off_f) & (lab > 0)
        img = np.clip(d + lights * show[..., None], 0, 1)
        cv2.imwrite(f"{out}/check-{prefix}-{tag}.jpg",
                    cv2.resize((img * 255).astype(np.uint8), (1600, 900), interpolation=cv2.INTER_AREA))
    return day


def snow_order(bare_day, snow_day, out):
    """When each spot turns white as the snow cover grows."""
    b = cv2.resize(bare_day, (OW, OH), interpolation=cv2.INTER_AREA).astype(np.float32) / 255
    s = cv2.resize(snow_day, (OW, OH), interpolation=cv2.INTER_AREA).astype(np.float32) / 255
    whiter = lum(s) - lum(b) + 0.5 * (np.abs(s - b).mean(2))
    whiter = cv2.GaussianBlur(whiter, (0, 0), 1.2)
    yy = np.arange(OH, dtype=np.float32)[:, None] / OH * np.ones((1, OW), np.float32)
    # Where the snow painting is much whiter (roofs, branches, ledges) it
    # settles first; open paving last. Low-frequency noise breaks the
    # front into patches.
    rng = np.random.default_rng(20260928)
    noise = cv2.GaussianBlur(rng.standard_normal((OH, OW)).astype(np.float32), (0, 0), 18)
    noise = (noise - noise.mean()) / (noise.std() + 1e-6)
    strength = np.clip(whiter / 0.35, 0, 1)
    t = 0.08 + 0.72 * (1 - strength) + 0.06 * noise + 0.08 * np.clip((yy - 0.55) / 0.45, 0, 1)
    t = np.clip(t, 0.03, 0.97)
    order = np.zeros((OH, OW, 3), np.float32)
    order[..., 2] = 1 - t
    cv2.imwrite(f"{out}/CityWinterSnowOrder.png", (order * 255 + 0.5).astype(np.uint8))
    for cover in (0.3, 0.6):
        show = (t <= cover)[..., None]
        img = np.where(show, s, b)
        cv2.imwrite(f"{out}/check-snow-{int(cover * 100)}.jpg",
                    cv2.resize((img * 255).astype(np.uint8), (1600, 900), interpolation=cv2.INTER_AREA))


def main(src, skyline_path, out, *only):
    os.makedirs(out, exist_ok=True)
    sky = np.array(ast.literal_eval(open(skyline_path).read()))
    days = {}
    for k, (prefix, names) in enumerate(SETS.items()):
        if only and prefix not in only:
            continue
        days[prefix] = build(src, sky, out, prefix, names, 20260928 + k)
    if "CityWinter" in days and "CityWinterSnow" in days:
        snow_order(days["CityWinter"], days["CityWinterSnow"], out)


if __name__ == "__main__":
    main(*sys.argv[1:])
