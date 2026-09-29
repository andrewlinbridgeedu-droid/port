"""Split the night painting into an unlit plate and switchable lights.

usage: prepare_lights.py <night_image> <deepnight_image> <out_dir> <prefix> [plate_size] [mode]

mode "deep" (default; used for spring): every bright warm pixel is a light and
the unlit plate borrows the deep-night painting there. Mode "local" (used when
the night painting has large lamp-lit surfaces): only small light points that
stand out from their surroundings are lights, filled from the local
background; broad lamplight on stone stays in the plate.

<night_image> must be moonless (the plate the app shows); both images share
one composition. Writes, for prefix P (e.g. CityLive, CitySummer):
  P+Night.jpg         night plate with windows and lamps dark (plate_size, default 2800)
  P+Lights.jpg        2048px additive light layer (black = no light);
                      unlit plate + lights == the night painting
  P+LightOrder.png    1024px; R = 1 - switch-on time, G = switch-off time
                      (0..1 along the dusk and late-night ramps), per light
  check-lights-P.jpg  preview
Groups: in the distant city each window is its own light; in the foreground a
lamp and the pools of light it throws on walls and steps form one group, so a
pool never glows before its lamp.
"""
import os
import sys

import cv2
import numpy as np


def main():
    night_path, deep_path, out, prefix = sys.argv[1:5]
    N = int(sys.argv[5]) if len(sys.argv) > 5 else 2800
    mode = sys.argv[6] if len(sys.argv) > 6 else "deep"
    os.makedirs(out, exist_ok=True)
    def load(path):
        img = cv2.imread(path)
        interp = cv2.INTER_AREA if img.shape[0] >= N else cv2.INTER_LANCZOS4
        return cv2.resize(img, (N, N), interpolation=interp).astype(np.float32) / 255
    night = load(night_path)
    deep = load(deep_path)

    def lum(im):
        return 0.299 * im[..., 2] + 0.587 * im[..., 1] + 0.114 * im[..., 0]

    ln, ld = lum(night), lum(deep)
    warm_n = night[..., 2] - night[..., 0]
    warm_d = deep[..., 2] - deep[..., 0]
    # Artificial light: bright and warm. Below the horizon only (the moon glow
    # and red clouds are not lamps).
    rows = np.arange(N)[:, None] / N
    if mode == "local":
        scale = N / 2800
        # Light points: warm and clearly brighter than their neighbourhood, or
        # very bright lamp heads.
        tophat = ln - cv2.GaussianBlur(ln, (0, 0), 7 * scale)
        # Lamp and window light is yellow-white: green stays high relative to
        # red. Orange-red autumn leaves and red flowers are not lights.
        yellowish = night[..., 1] > 0.66 * night[..., 2]
        core = (((tophat > 0.07) & (ln > 0.34)) | (ln > 0.80)) & (warm_n > 0.10) & yellowish & (rows > 0.245)
        core = cv2.morphologyEx(core.astype(np.uint8), cv2.MORPH_OPEN, np.ones((2, 2), np.uint8))
        # In the foreground a real lamp or lit window has a very bright centre;
        # leftover warm patches on stone and lit leaves do not.
        n_c, lab_c = cv2.connectedComponents(core)
        peak = np.zeros(n_c, np.float32)
        np.maximum.at(peak, lab_c.ravel(), ln.ravel())
        cy = np.zeros(n_c, np.float32); cnt = np.bincount(lab_c.ravel(), minlength=n_c).astype(np.float32)
        np.add.at(cy, lab_c.ravel(), np.broadcast_to(rows, lab_c.shape).ravel().astype(np.float32))
        cy /= np.maximum(cnt, 1)
        ok = (cy < 0.50) | (peak > 0.75)
        ok[0] = False
        core = ok[lab_c].astype(np.uint8)
        sys.path.insert(0, os.path.dirname(__file__))
        from relight_night import floor_mask
        core = core * (floor_mask(N, 1) < 0.5).astype(np.uint8)
        grow_px = max(3, int(round(4 * scale)) * 2 + 1)
        soft = cv2.GaussianBlur(cv2.dilate(core, np.ones((grow_px, grow_px), np.uint8)).astype(np.float32), (0, 0), 1.5 * scale + 0.5)
        soft = np.clip(soft * 1.5, 0, 1)
        # Fill each light point with the same spot of the deep-night painting
        # (same composition, windows mostly dark), matched to the night
        # painting's local brightness away from the lights. Where the deep
        # painting is itself lit, darken it to an unlit pane.
        free = (1 - soft)[..., None]
        sig = 12 * scale
        num = cv2.GaussianBlur(night * free, (0, 0), sig)
        den = cv2.GaussianBlur(deep * free, (0, 0), sig) + 1e-3
        gain = np.clip(num / den, 0.6, 2.2)
        fill = deep * gain
        still_lit = ((ld > 0.40) & (warm_d > 0.12)).astype(np.float32)
        still_lit = cv2.GaussianBlur(cv2.dilate(still_lit, np.ones((5, 5), np.uint8)), (0, 0), 2)[..., None]
        pane = cv2.GaussianBlur(fill, (0, 0), 3 * scale) * np.array([0.62, 0.46, 0.44], np.float32)   # BGR: cool, dark
        fill = fill * (1 - still_lit) + np.minimum(fill, pane) * still_lit
        unlit = night * (1 - soft[..., None]) + np.minimum(night, fill) * soft[..., None]
        lights = np.clip(night - unlit, 0, 1)
    else:
        core = (ln > 0.42) & (warm_n > 0.13) & (rows > 0.245)
        core = core.astype(np.uint8)
        # Soft mask reaching into each light's halo.
        soft = cv2.GaussianBlur(cv2.dilate(core, np.ones((5, 5), np.uint8)).astype(np.float32), (0, 0), 3)
        soft = np.clip(soft * 1.6, 0, 1)

        # Unlit plate: take the deep-night painting (windows dark) lifted to the
        # night painting's ambient level, measured away from the lights.
        free = (1 - soft)[..., None]
        sigma = 40
        num = cv2.GaussianBlur(night * free, (0, 0), sigma)
        den = cv2.GaussianBlur(deep * free, (0, 0), sigma) + 1e-4
        gain = np.clip(num / den, 0.6, 3.0)
        lifted = deep * gain
        # Lights still burning in the deep-night painting would stay lit; dim them.
        still_lit = ((ld > 0.40) & (warm_d > 0.12)).astype(np.float32)
        still_lit = cv2.GaussianBlur(cv2.dilate(still_lit, np.ones((5, 5), np.uint8)), (0, 0), 2)[..., None]
        dark_window = cv2.GaussianBlur(lifted, (0, 0), 6) * 0.45
        lifted = lifted * (1 - still_lit) + np.minimum(lifted, dark_window) * still_lit
        unlit = night * (1 - soft[..., None]) + np.minimum(night, lifted) * soft[..., None]
        lights = np.clip(night - unlit, 0, 1)

    # Groups: small dilation far away, large in the foreground so lamps and
    # their pools merge.
    grow = np.zeros_like(core)
    far = rows < 0.60
    grow |= np.where(far, cv2.dilate(core, np.ones((5, 5), np.uint8)), 0).astype(np.uint8)
    k = max(15, int(71 * N / 2800) | 1)
    near_k = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (k, k))
    grow |= np.where(~far, cv2.dilate(core, near_k), 0).astype(np.uint8)
    count, labels = cv2.connectedComponents(grow)
    rng = np.random.default_rng(20260927)
    on = np.zeros(count, np.float32)
    off = np.zeros(count, np.float32)
    deep_lit = np.zeros(count, np.float32)
    ys = np.zeros(count, np.float32)
    area = np.bincount(labels.ravel(), minlength=count).astype(np.float32)
    np.add.at(deep_lit, labels.ravel(), (still_lit[..., 0] > 0.5).ravel().astype(np.float32))
    np.add.at(ys, labels.ravel(), np.broadcast_to(rows, labels.shape).ravel().astype(np.float32))
    ys /= np.maximum(area, 1)
    for i in range(1, count):
        if ys[i] >= 0.60:
            # Street lamps and foreground lanterns come on first.
            on[i] = rng.uniform(0.02, 0.28)
        else:
            on[i] = rng.uniform(0.05, 1.0) ** 0.8
        if deep_lit[i] / max(area[i], 1) > 0.05:
            # Burns on into deep night: hand over to the deep painting as it fades in.
            off[i] = rng.uniform(0.40, 0.52)
        elif ys[i] >= 0.60:
            off[i] = rng.uniform(0.65, 1.0)
        else:
            off[i] = rng.uniform(0.02, 1.0)
    order = np.zeros((N, N, 3), np.float32)
    order[..., 2] = np.where(labels > 0, 1 - on[labels], 0)   # R (OpenCV is BGR)
    order[..., 1] = np.where(labels > 0, off[labels], 0)      # G

    cv2.imwrite(os.path.join(out, prefix + "Night.jpg"), (unlit * 255).astype(np.uint8), [cv2.IMWRITE_JPEG_QUALITY, 92])
    cv2.imwrite(os.path.join(out, prefix + "Lights.jpg"),
                cv2.resize((lights * 255).astype(np.uint8), (2048, 2048), interpolation=cv2.INTER_AREA),
                [cv2.IMWRITE_JPEG_QUALITY, 94])
    cv2.imwrite(os.path.join(out, prefix + "LightOrder.png"),
                cv2.resize((order * 255).astype(np.uint8), (1024, 1024), interpolation=cv2.INTER_NEAREST))
    # previews: unlit vs night, and lights with ~40% switched on
    y0 = int(0.38 * N)
    half = np.clip(unlit + lights * (on[labels] < 0.4)[..., None], 0, 1)
    strip = np.hstack([unlit[y0:], half[y0:], night[y0:]])
    cv2.imwrite(os.path.join(out, "check-lights-" + prefix + ".jpg"), cv2.resize((strip * 255).astype(np.uint8), (1800, int(1800 * strip.shape[0] / strip.shape[1]))))
    print("groups", count - 1, "deep-lit groups", int((deep_lit / np.maximum(area, 1) > 0.05).sum()))


if __name__ == "__main__":
    main()
