"""Numpy texture painter. Canvas coordinates are centimetres (origin bottom-left,
+y up), so garment UVs in cm map straight onto the painting.

Strokes are embossed: each is a tube of thread with a rounded profile, lit from the
upper left, with satin stitches across it and a dark outline under it."""
import math
import numpy as np


class Canvas:
    def __init__(self, width_cm, height_cm, px_per_cm):
        self.w_cm, self.h_cm, self.ppc = width_cm, height_cm, px_per_cm
        self.W = int(round(width_cm * px_per_cm))
        self.H = int(round(height_cm * px_per_cm))
        self.rgb = np.zeros((self.H, self.W, 3), np.float32)
        # Height buffer for overlapping strokes (higher thread wins).
        self.hbuf = np.full((self.H, self.W), -1.0, np.float32)

    # --- coordinates
    def px(self, x, y):
        return x * self.ppc, (self.h_cm - y) * self.ppc

    def grid(self, x0, y0, x1, y1):
        """Pixel index box (clipped) and cm coordinates of pixel centres."""
        X0, Y1 = self.px(x0, y0)
        X1, Y0 = self.px(x1, y1)
        i0, i1 = max(0, int(math.floor(min(Y0, Y1)))), min(self.H, int(math.ceil(max(Y0, Y1))) + 1)
        j0, j1 = max(0, int(math.floor(min(X0, X1)))), min(self.W, int(math.ceil(max(X0, X1))) + 1)
        if i0 >= i1 or j0 >= j1:
            return None
        jj, ii = np.meshgrid(np.arange(j0, j1), np.arange(i0, i1))
        xs = (jj + 0.5) / self.ppc
        ys = self.h_cm - (ii + 0.5) / self.ppc
        return (i0, i1, j0, j1), xs, ys

    # --- fills
    def fill(self, color):
        self.rgb[:] = np.array(color, np.float32)

    def fill_rect(self, x0, y0, x1, y1, color):
        g = self.grid(x0, y0, x1, y1)
        if g is None:
            return
        (i0, i1, j0, j1), xs, ys = g
        self.rgb[i0:i1, j0:j1] = np.array(color, np.float32)

    def pattern(self, x0, y0, x1, y1, fn):
        """fn(xs, ys, rgb) -> rgb, over a rectangle in cm."""
        g = self.grid(x0, y0, x1, y1)
        if g is None:
            return
        (i0, i1, j0, j1), xs, ys = g
        self.rgb[i0:i1, j0:j1] = fn(xs, ys, self.rgb[i0:i1, j0:j1])

    # --- strokes
    def stroke(self, pts, widths, gold, outline=(0.06, 0.035, 0.02), outline_w=0.09, stitch=0.16,
               light=(-0.55, 0.65, 0.52), shine=0.55, flat=False):
        """pts: list of (x, y) cm; widths: half widths (cm) per point."""
        pts = np.asarray(pts, np.float32)
        widths = np.asarray(widths, np.float32)
        if len(pts) < 2:
            return
        # Drop points closer than ~1.5 px: the curves are smooth, painting is per segment.
        keep = [0]
        min_step = 1.5 / self.ppc
        for i in range(1, len(pts) - 1):
            if np.linalg.norm(pts[i] - pts[keep[-1]]) >= min_step:
                keep.append(i)
        keep.append(len(pts) - 1)
        pts, widths = pts[keep], widths[keep]
        seg_len = np.linalg.norm(pts[1:] - pts[:-1], axis=1)
        arc = np.concatenate([[0], np.cumsum(seg_len)])
        L = np.array(light, np.float32)
        L /= np.linalg.norm(L)
        gold = np.array(gold, np.float32)
        dark = np.array(outline, np.float32)
        for k in range(len(pts) - 1):
            a, b = pts[k], pts[k + 1]
            wa, wb = widths[k], widths[k + 1]
            wmax = max(wa, wb) + outline_w + 0.05
            g = self.grid(min(a[0], b[0]) - wmax, min(a[1], b[1]) - wmax, max(a[0], b[0]) + wmax, max(a[1], b[1]) + wmax)
            if g is None:
                continue
            (i0, i1, j0, j1), xs, ys = g
            ab = b - a
            ll = float(ab @ ab)
            if ll < 1e-10:
                continue
            t = np.clip(((xs - a[0]) * ab[0] + (ys - a[1]) * ab[1]) / ll, 0, 1)
            cx, cy = a[0] + t * ab[0], a[1] + t * ab[1]
            dx, dy = xs - cx, ys - cy
            d = np.sqrt(dx * dx + dy * dy)
            w = wa + (wb - wa) * t
            s = arc[k] + t * seg_len[k]
            px = 1.0 / self.ppc
            # Outline under the thread.
            cov_o = np.clip((w + outline_w - d) / px + 0.5, 0, 1)
            cov = np.clip((w - d) / px + 0.5, 0, 1)
            region = self.rgb[i0:i1, j0:j1]
            hb = self.hbuf[i0:i1, j0:j1]
            r = np.clip(d / np.maximum(w, 1e-4), 0, 1)
            h = np.sqrt(np.clip(1 - r * r, 0, 1))
            # Outline only where nothing higher is already drawn.
            o_mask = (cov_o > 0) & (hb < 0)
            region[o_mask] = region[o_mask] * (1 - cov_o[o_mask, None]) + dark * cov_o[o_mask, None]
            m = (cov > 0) & (h + 0.001 * k > hb - 0.02)
            if not np.any(m):
                continue
            nx = np.where(d > 1e-6, dx / np.maximum(d, 1e-6), 0) * r
            ny = np.where(d > 1e-6, dy / np.maximum(d, 1e-6), 0) * r
            nz = h
            if flat:
                nx, ny, nz = nx * 0.25, ny * 0.25, np.sqrt(np.clip(1 - (0.25 * r) ** 2, 0, 1))
            lam = np.clip(nx * L[0] + ny * L[1] + nz * L[2], 0, 1)
            # Satin stitches across the thread, offset each row.
            st = 0.82 + 0.18 * np.abs(np.sin(s / max(stitch, 1e-3) * math.pi + r * 1.3))
            shade = (0.42 + 0.78 * lam) * st
            spec = np.clip((lam - 0.78) / 0.2, 0, 1) ** 2 * shine
            col = gold[None, None, :] * shade[..., None] + spec[..., None] * np.array([1.0, 0.95, 0.8])
            c = cov[..., None]
            region[m] = region[m] * (1 - c[m]) + col[m] * c[m]
            hb[m] = np.maximum(hb[m], h[m])

    def dot(self, x, y, r, gold, **kw):
        pts = [(x - r * 0.01, y), (x + r * 0.01, y)]
        self.stroke(pts, [r, r], gold, **kw)

    def save(self, path, image_name):
        import bpy
        img = bpy.data.images.get(image_name)
        if img is None or img.size[0] != self.W or img.size[1] != self.H:
            if img is not None:
                bpy.data.images.remove(img)
            img = bpy.data.images.new(image_name, self.W, self.H, alpha=False)
        rgba = np.ones((self.H, self.W, 4), np.float32)
        rgba[..., :3] = np.clip(self.rgb, 0, 1)
        # Blender images are stored bottom row first.
        img.pixels.foreach_set(rgba[::-1].ravel())
        img.filepath_raw = str(path)
        img.file_format = 'PNG'
        img.save()
        return img


def srgb_to_linear(c):
    c = np.asarray(c, np.float32)
    return np.where(c <= 0.04045, c / 12.92, ((c + 0.055) / 1.055) ** 2.4)


def value_noise(xs, ys, scale, seed=0):
    """Cheap smooth noise (bilinear on a hashed lattice)."""
    rng = np.random.default_rng(seed)
    lattice = rng.random((257, 257)).astype(np.float32)
    x = xs / scale
    y = ys / scale
    xi = np.floor(x).astype(np.int64)
    yi = np.floor(y).astype(np.int64)
    fx = x - xi
    fy = y - yi
    fx = fx * fx * (3 - 2 * fx)
    fy = fy * fy * (3 - 2 * fy)
    xi %= 256
    yi %= 256
    a = lattice[yi, xi]
    b = lattice[yi, xi + 1]
    c = lattice[yi + 1, xi]
    d = lattice[yi + 1, xi + 1]
    return (a * (1 - fx) + b * fx) * (1 - fy) + (c * (1 - fx) + d * fx) * fy
