"""Hub plates from the 2026-09-27 paintings (16:9, one composition).

usage: prepare.py <src_dir> <sr_dir> <skyline.txt> <out_dir>

<src_dir>: spring-day.png, spring-sunset.png, spring-night.png (unlit) and
spring-nightlight.png (the same night with lamps and windows on), 1672×941.
<sr_dir>: the same four upscaled ×4 by Real-ESRGAN (realesrgan-x4plus), named
<name>-x4.png.

The four paintings differ by a pixel or two; each is warped onto the day
painting with a homography measured on the originals, then the upscales are
reduced to 4096 wide. Writes, for the app's asset catalog:
  CityHarborDay.jpg, CityHarborSunset.jpg, CityHarborNight.jpg   plates
  CityHarborLights.jpg      additive light layer, lit night − unlit night
                            (unlit + lights == lit night)
  CityHarborLightOrder.png  2048 wide; R = 1 − switch-on time (dusk ramp),
                            G = switch-off time (late night 0 … 0.8, dawn
                            0.8 … 1), per light group
and previews check-*.jpg.
Groups: every lamp head or lit window is a core; each lit pixel belongs to
the core that lights it most (brightness over distance), so a pool of
lamplight comes on with its lamp. Foreground lamps and the lighthouse come on
first and burn until dawn; windows come on at random through the evening and
most go dark after midnight, about one in eight stay lit until dawn.
"""
import ast
import os
import sys

import cv2
import numpy as np

W, H = 4096, 2305
ORDER_W, ORDER_H = 2048, 1153


def homography(a, b):
    """Maps points of a onto b (both BGR, same size)."""
    eq = cv2.createCLAHE(3.0, (8, 8))
    ga = eq.apply(cv2.cvtColor(a, cv2.COLOR_BGR2GRAY))
    gb = eq.apply(cv2.cvtColor(b, cv2.COLOR_BGR2GRAY))
    sift = cv2.SIFT_create(8000)
    ka, da = sift.detectAndCompute(ga, None)
    kb, db = sift.detectAndCompute(gb, None)
    good = [m for m, n in cv2.BFMatcher().knnMatch(da, db, k=2) if m.distance < 0.72 * n.distance]
    src = np.float32([ka[m.queryIdx].pt for m in good])
    dst = np.float32([kb[m.trainIdx].pt for m in good])
    M, inl = cv2.findHomography(src, dst, cv2.RANSAC, 2.5)
    res = np.linalg.norm(cv2.perspectiveTransform(src[inl.ravel() == 1][None], M)[0] - dst[inl.ravel() == 1], axis=1)
    return M, int(inl.sum()), float(np.median(res))


def main(src_dir, sr_dir, skyline_path, out):
    os.makedirs(out, exist_ok=True)
    names = ["spring-day", "spring-sunset", "spring-night", "spring-nightlight"]
    orig = {n: cv2.imread(f"{src_dir}/{n}.png") for n in names}
    oh, ow = orig["spring-day"].shape[:2]
    # Night pair first (lit onto unlit), then everything onto the day painting.
    M_lit, n1, r1 = homography(orig["spring-nightlight"], orig["spring-night"])
    M_night, n2, r2 = homography(orig["spring-night"], orig["spring-day"])
    M_sun, n3, r3 = homography(orig["spring-sunset"], orig["spring-day"])
    print(f"lit→night {n1} inliers {r1:.2f}px, night→day {n2} {r2:.2f}px, sunset→day {n3} {r3:.2f}px")
    to_day = {"spring-day": np.eye(3), "spring-sunset": M_sun, "spring-night": M_night,
              "spring-nightlight": M_night @ M_lit}
    S = np.diag([W / ow, H / oh, 1.0])
    plates = {}
    for n in names:
        big = cv2.imread(f"{sr_dir}/{n}-x4.png")
        small = cv2.resize(big, (W, H), interpolation=cv2.INTER_AREA)
        M = S @ to_day[n] @ np.linalg.inv(S)
        plates[n] = cv2.warpPerspective(small, M, (W, H), flags=cv2.INTER_LANCZOS4, borderMode=cv2.BORDER_REFLECT)
    q = [cv2.IMWRITE_JPEG_QUALITY, 90]
    cv2.imwrite(f"{out}/CityHarborDay.jpg", plates["spring-day"], q)
    cv2.imwrite(f"{out}/CityHarborSunset.jpg", plates["spring-sunset"], q)
    cv2.imwrite(f"{out}/CityHarborNight.jpg", plates["spring-night"], q)

    dark = plates["spring-night"].astype(np.float32) / 255
    lit = plates["spring-nightlight"].astype(np.float32) / 255
    rows = np.arange(H, dtype=np.float32)[:, None] / H          # painting units (y)
    sky = np.array(ast.literal_eval(open(skyline_path).read()))
    sky_y = np.interp(np.arange(W), (np.arange(len(sky)) + 0.5) / len(sky) * W, sky * H)
    below = np.clip((np.arange(H)[:, None] - sky_y[None, :] + 4) / 8, 0, 1).astype(np.float32)
    lights = np.clip(lit - dark - 1.5 / 255, 0, 1) * below[..., None]
    cv2.imwrite(f"{out}/CityHarborLights.jpg", (lights * 255 + 0.5).astype(np.uint8), [cv2.IMWRITE_JPEG_QUALITY, 92])

    # --- groups, on a 2048-wide grid
    lw = cv2.resize(lit, (ORDER_W, ORDER_H), interpolation=cv2.INTER_AREA)
    lg = cv2.resize(lights, (ORDER_W, ORDER_H), interpolation=cv2.INTER_AREA)
    lum = lambda im: 0.299 * im[..., 2] + 0.587 * im[..., 1] + 0.114 * im[..., 0]
    l_lit, l_add = lum(lw), lum(lg)
    warm = lw[..., 2] - lw[..., 0]
    tophat = l_lit - cv2.GaussianBlur(l_lit, (0, 0), 5)
    yy = np.arange(ORDER_H, dtype=np.float32)[:, None] / ORDER_H * np.ones((1, ORDER_W), np.float32)
    core = (((tophat > 0.06) & (l_lit > 0.30)) | (l_lit > 0.72)) & (warm > 0.08) & (l_add > 0.14)
    core = cv2.morphologyEx(core.astype(np.uint8), cv2.MORPH_OPEN, np.ones((2, 2), np.uint8))
    # Far away each window is its own light; nearer, a lamp head and its
    # glowing glass merge into one.
    near = yy > 0.45
    grown = np.where(near, cv2.dilate(core, cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (9, 9))),
                     cv2.dilate(core, np.ones((3, 3), np.uint8))).astype(np.uint8)
    count, cores = cv2.connectedComponents(grown)
    # Each lit pixel joins the core that lights it most: brightness / distance.
    lit_px = l_add > 0.012
    best = np.zeros((ORDER_H, ORDER_W), np.float32)
    label = np.zeros((ORDER_H, ORDER_W), np.int32)
    peak = np.zeros(count, np.float32)
    np.maximum.at(peak, cores.ravel(), l_add.ravel())
    cy = np.zeros(count, np.float32)
    area = np.bincount(cores.ravel(), minlength=count).astype(np.float32)
    np.add.at(cy, cores.ravel(), yy.ravel())
    cy /= np.maximum(area, 1)
    # Distance fields per brightness band keep this cheap: cores are binned by
    # peak brightness and each bin gets one distance transform with labels.
    bins = np.quantile(peak[1:], [0, 0.25, 0.5, 0.75, 0.9, 1.0]) if count > 1 else [0, 1]
    for b in range(len(bins) - 1):
        sel = np.zeros(count, bool)
        sel[1:] = (peak[1:] >= bins[b]) & (peak[1:] <= bins[b + 1] + 1e-6)
        if not sel.any():
            continue
        mask = sel[cores]
        dist, idx = cv2.distanceTransformWithLabels((~mask).astype(np.uint8), cv2.DIST_L2, 5,
                                                    labelType=cv2.DIST_LABEL_PIXEL)
        # idx labels mask pixels; map them back to core labels.
        ys, xs = np.nonzero(mask)
        lut = np.zeros(idx.max() + 1, np.int32)
        lut[idx[ys, xs]] = cores[ys, xs]
        nearest = lut[idx]
        reach = 6 + 60 * (bins[b + 1])                        # brighter lights reach further
        score = bins[b + 1] / (1 + dist / reach)
        take = score > best
        best = np.where(take, score, best)
        label = np.where(take, nearest, label)
    label = np.where(lit_px | (cores > 0), label, 0)

    rng = np.random.default_rng(20260927)
    on = np.zeros(count, np.float32)
    off = np.zeros(count, np.float32)
    lighthouse = np.zeros(count, bool)
    cx = np.zeros(count, np.float32)
    xx = np.arange(ORDER_W, dtype=np.float32)[None, :] / ORDER_H * np.ones((ORDER_H, 1), np.float32)
    np.add.at(cx, cores.ravel(), xx.ravel())
    cx /= np.maximum(area, 1)
    # Street lamps throw the most light around them (pools on stone and
    # walls); a window lights little beyond its own pane.
    thrown = np.zeros(count, np.float32)
    np.add.at(thrown, label.ravel(), l_add.ravel())
    thrown[0] = 0
    candidates = [i for i in np.argsort(-thrown) if i > 0 and cy[i] >= 0.38]
    street = set(candidates[:40])
    # Light on the ground and walls in the town belongs to the street lamps:
    # a pool never goes dark with a window above it.
    street_mask = np.isin(cores, list(street))
    if street_mask.any():
        d_any = cv2.distanceTransform((cores == 0).astype(np.uint8), cv2.DIST_L2, 5)
        d_st, idx = cv2.distanceTransformWithLabels((~street_mask).astype(np.uint8), cv2.DIST_L2, 5,
                                                    labelType=cv2.DIST_LABEL_PIXEL)
        ys, xs = np.nonzero(street_mask)
        lut = np.zeros(idx.max() + 1, np.int32)
        lut[idx[ys, xs]] = cores[ys, xs]
        pool = (label > 0) & (yy >= 0.45) & (d_any > 6) & (d_st < 220) & ~np.isin(label, list(street))
        label = np.where(pool, lut[idx], label)
    for i in range(1, count):
        lighthouse[i] = 1.72 < cx[i] < 1.77 and 0.24 < cy[i] < 0.30
        foreground = i in street
        if lighthouse[i]:
            on[i], off[i] = 0.0, 0.998
        elif foreground:
            # Street lamps and lanterns: first on, last off (at dawn).
            on[i] = rng.uniform(0.02, 0.30)
            off[i] = rng.uniform(0.82, 0.99)
        else:
            on[i] = rng.uniform(0.04, 1.0) ** 0.8
            off[i] = rng.uniform(0.82, 0.99) if rng.uniform() < 0.12 else rng.uniform(0.02, 0.78)
    order = np.zeros((ORDER_H, ORDER_W, 3), np.float32)
    order[..., 2] = np.where(label > 0, 1 - on[label], 0)      # R (OpenCV is BGR)
    order[..., 1] = np.where(label > 0, off[label], 0)          # G
    cv2.imwrite(f"{out}/CityHarborLightOrder.png", (order * 255 + 0.5).astype(np.uint8))
    lamps = [i for i in range(1, count) if on[i] <= 0.30 and off[i] >= 0.82 and cy[i] >= 0.40]
    print("light groups", count - 1, "street lamps", len(lamps), "lit pixels assigned", round(float((label > 0).mean()), 3))
    print("lamp heads (x, y):", [(round(float(cx[i]), 3), round(float(cy[i]), 3)) for i in lamps])

    # --- previews at 1600 wide: dusk 30 % on, all on (== lit), deep night
    def preview(on_frac, off_frac):
        lab = cv2.resize(label.astype(np.float32), (W, H), interpolation=cv2.INTER_NEAREST).astype(np.int32)
        show = (on[lab] <= on_frac) & (off[lab] > off_frac) & (lab > 0)
        img = np.clip(dark + lights * show[..., None], 0, 1)
        return cv2.resize((img * 255).astype(np.uint8), (1600, 900), interpolation=cv2.INTER_AREA)
    cv2.imwrite(f"{out}/check-dusk30.jpg", preview(0.30, 0))
    cv2.imwrite(f"{out}/check-allon.jpg", preview(1.0, 0))
    cv2.imwrite(f"{out}/check-deep.jpg", preview(1.0, 0.80))
    cv2.imwrite(f"{out}/check-groups.jpg", cv2.resize(
        (np.where(label[..., None] > 0, rng.uniform(40, 255, (count, 3))[label], 0)).astype(np.uint8), (1600, 900),
        interpolation=cv2.INTER_NEAREST))


if __name__ == "__main__":
    main(*sys.argv[1:5])
