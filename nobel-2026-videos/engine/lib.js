// Shared drawing helpers. Every function is a pure function of its inputs so
// any frame can be rendered at any time in any order.
export const W = 1920, H = 1080;
export const TAU = Math.PI * 2;

export const clamp = (x, a = 0, b = 1) => Math.min(b, Math.max(a, x));
export const lerp = (a, b, t) => a + (b - a) * t;
export const mix = lerp;
export const smooth = (e0, e1, x) => { const t = clamp((x - e0) / (e1 - e0)); return t * t * (3 - 2 * t); };
export const win = (x, a, b, f = 0.5) => smooth(a, a + f, x) * (1 - smooth(b - f, b, x)); // fade in at a, out at b
export const ease = {
  in: t => t * t * t,
  out: t => 1 - Math.pow(1 - t, 3),
  inOut: t => (t < 0.5 ? 4 * t * t * t : 1 - Math.pow(-2 * t + 2, 3) / 2),
  outExpo: t => (t >= 1 ? 1 : 1 - Math.pow(2, -10 * t)),
  outBack: t => { const c1 = 1.70158, c3 = c1 + 1; return 1 + c3 * Math.pow(t - 1, 3) + c1 * Math.pow(t - 1, 2); },
  sine: t => 0.5 - 0.5 * Math.cos(Math.PI * t),
};
export const prog = (st, a, d, f = ease.inOut) => f(clamp((st - a) / d));

export function rng(seed) {
  let a = seed >>> 0;
  return () => {
    a |= 0; a = (a + 0x6d2b79f5) | 0;
    let t = Math.imul(a ^ (a >>> 15), 1 | a);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}
export const hash = (n) => { const x = Math.sin(n * 127.1 + 311.7) * 43758.5453; return x - Math.floor(x); };

// --- 2D simplex noise -------------------------------------------------------
const perm = new Uint8Array(512);
{ const r = rng(1337); const p = [...Array(256).keys()]; for (let i = 255; i > 0; i--) { const j = Math.floor(r() * (i + 1)); [p[i], p[j]] = [p[j], p[i]]; } for (let i = 0; i < 512; i++) perm[i] = p[i & 255]; }
const G2 = [[1, 1], [-1, 1], [1, -1], [-1, -1], [1, 0], [-1, 0], [0, 1], [0, -1]];
export function noise2(x, y) {
  const F2 = 0.366025403784, G = 0.211324865405;
  const s = (x + y) * F2, i = Math.floor(x + s), j = Math.floor(y + s);
  const t = (i + j) * G, x0 = x - (i - t), y0 = y - (j - t);
  const i1 = x0 > y0 ? 1 : 0, j1 = 1 - i1;
  const x1 = x0 - i1 + G, y1 = y0 - j1 + G, x2 = x0 - 1 + 2 * G, y2 = y0 - 1 + 2 * G;
  const ii = i & 255, jj = j & 255;
  let n = 0;
  const c = (gx, gy, xx, yy) => { let tt = 0.5 - xx * xx - yy * yy; if (tt < 0) return 0; tt *= tt; return tt * tt * (gx * xx + gy * yy); };
  let g = G2[perm[ii + perm[jj]] & 7]; n += c(g[0], g[1], x0, y0);
  g = G2[perm[ii + i1 + perm[jj + j1]] & 7]; n += c(g[0], g[1], x1, y1);
  g = G2[perm[ii + 1 + perm[jj + 1]] & 7]; n += c(g[0], g[1], x2, y2);
  return 70 * n;
}
export function fbm(x, y, oct = 4) { let a = 0, f = 1, amp = 0.5; for (let i = 0; i < oct; i++) { a += amp * noise2(x * f, y * f); f *= 2; amp *= 0.5; } return a; }

// --- colour ------------------------------------------------------------------
const hexCache = {};
export function rgb(hex) {
  if (hexCache[hex]) return hexCache[hex];
  const h = hex.replace('#', '');
  const v = h.length === 3 ? h.split('').map(c => parseInt(c + c, 16)) : [0, 2, 4].map(i => parseInt(h.slice(i, i + 2), 16));
  return (hexCache[hex] = v);
}
export const rgba = (hex, a = 1) => { const [r, g, b] = rgb(hex); return `rgba(${r},${g},${b},${a})`; };
export function mixHex(h1, h2, t) { const a = rgb(h1), b = rgb(h2); return '#' + a.map((v, i) => Math.round(lerp(v, b[i], t)).toString(16).padStart(2, '0')).join(''); }
// IceCube-style time colouring: red (early) -> yellow -> green -> blue -> violet (late)
export function rainbow(t) { const h = lerp(0, 270, clamp(t)); return `hsl(${h},100%,60%)`; }

// --- glow sprites -------------------------------------------------------------
const spriteCache = new Map();
export function glowSprite(color, size = 128, hard = 0.0) {
  const key = color + size + hard;
  if (spriteCache.has(key)) return spriteCache.get(key);
  const c = document.createElement('canvas'); c.width = c.height = size;
  const g = c.getContext('2d');
  const gr = g.createRadialGradient(size / 2, size / 2, 0, size / 2, size / 2, size / 2);
  const [r, gg, b] = rgb(color);
  gr.addColorStop(0, `rgba(${r},${gg},${b},1)`);
  gr.addColorStop(clamp(0.08 + hard * 0.5), `rgba(${r},${gg},${b},${0.85})`);
  gr.addColorStop(0.25 + hard * 0.3, `rgba(${r},${gg},${b},0.35)`);
  gr.addColorStop(0.55, `rgba(${r},${gg},${b},0.08)`);
  gr.addColorStop(1, `rgba(${r},${gg},${b},0)`);
  g.fillStyle = gr; g.fillRect(0, 0, size, size);
  spriteCache.set(key, c);
  return c;
}
export function glow(ctx, x, y, r, color, a = 1, hard = 0) {
  if (a <= 0.003 || r <= 0.2) return;
  const s = glowSprite(color, 128, hard);
  const pa = ctx.globalAlpha; ctx.globalAlpha = pa * clamp(a);
  ctx.drawImage(s, x - r, y - r, r * 2, r * 2);
  ctx.globalAlpha = pa;
}
export function dot(ctx, x, y, r, color, a = 1) {
  if (a <= 0.003) return;
  const pa = ctx.globalAlpha; ctx.globalAlpha = pa * clamp(a); ctx.fillStyle = color; ctx.beginPath(); ctx.arc(x, y, r, 0, TAU); ctx.fill(); ctx.globalAlpha = pa;
}
export function additive(ctx, fn) { const p = ctx.globalCompositeOperation; ctx.globalCompositeOperation = 'lighter'; fn(); ctx.globalCompositeOperation = p; }
export function alpha(ctx, a, fn) { if (a <= 0.003) return; const p = ctx.globalAlpha; ctx.globalAlpha = p * clamp(a); fn(); ctx.globalAlpha = p; }

// glowing line / polyline
export function line(ctx, pts, color, w = 2, a = 1, glowW = 0) {
  if (a <= 0.003 || pts.length < 2) return;
  ctx.save(); ctx.globalAlpha *= clamp(a); ctx.lineCap = 'round'; ctx.lineJoin = 'round';
  const path = () => { ctx.beginPath(); ctx.moveTo(pts[0][0], pts[0][1]); for (let i = 1; i < pts.length; i++) ctx.lineTo(pts[i][0], pts[i][1]); };
  if (glowW > 0) { ctx.globalCompositeOperation = 'lighter'; ctx.strokeStyle = rgba(color, 0.12); ctx.lineWidth = w + glowW; path(); ctx.stroke(); ctx.strokeStyle = rgba(color, 0.25); ctx.lineWidth = w + glowW * 0.45; path(); ctx.stroke(); }
  ctx.strokeStyle = color; ctx.lineWidth = w; path(); ctx.stroke();
  ctx.restore();
}
// partial polyline (0..1 of its length)
export function partial(pts, p) {
  if (p >= 1) return pts; if (p <= 0) return [pts[0]];
  let L = 0; const seg = [];
  for (let i = 1; i < pts.length; i++) { const d = Math.hypot(pts[i][0] - pts[i - 1][0], pts[i][1] - pts[i - 1][1]); seg.push(d); L += d; }
  let target = L * p, out = [pts[0]];
  for (let i = 1; i < pts.length; i++) {
    if (target <= seg[i - 1]) { const k = target / seg[i - 1]; out.push([lerp(pts[i - 1][0], pts[i][0], k), lerp(pts[i - 1][1], pts[i][1], k)]); return out; }
    target -= seg[i - 1]; out.push(pts[i]);
  }
  return out;
}

// --- text ----------------------------------------------------------------------
export const F = {
  serif: '"Noto Serif SC", "WenQuanYi Zen Hei", serif',
  kai: '"LXGW WenKai", "Noto Serif SC", serif',
  brush: '"Ma Shan Zheng", "LXGW WenKai", serif',
  xiaowei: '"ZCOOL XiaoWei", "Noto Serif SC", serif',
  latin: '"Cormorant Garamond", "Noto Serif", serif',
  greek: '"Noto Serif", serif',
};
export function text(ctx, s, x, y, o = {}) {
  const a = o.alpha ?? 1; if (a <= 0.003 || !s) return;
  ctx.save();
  ctx.globalAlpha *= clamp(a);
  ctx.font = `${o.italic ? 'italic ' : ''}${o.weight ?? 500} ${o.size ?? 40}px ${o.font ?? F.serif}`;
  ctx.textAlign = o.align ?? 'center'; ctx.textBaseline = o.baseline ?? 'middle';
  ctx.letterSpacing = (o.spacing ?? 0) + 'px';
  if (o.glow) { ctx.shadowColor = o.glowColor ?? o.color ?? '#fff'; ctx.shadowBlur = o.glow; }
  if (o.stroke) { ctx.lineWidth = o.stroke; ctx.strokeStyle = o.strokeColor ?? 'rgba(0,0,0,.6)'; ctx.lineJoin = 'round'; ctx.strokeText(s, x, y); }
  ctx.fillStyle = o.color ?? '#fff';
  ctx.fillText(s, x, y);
  if (o.glow && o.double) ctx.fillText(s, x, y);
  ctx.restore();
}
export function measure(ctx, s, o = {}) {
  ctx.save(); ctx.font = `${o.weight ?? 500} ${o.size ?? 40}px ${o.font ?? F.serif}`; ctx.letterSpacing = (o.spacing ?? 0) + 'px';
  const w = ctx.measureText(s).width; ctx.restore(); return w;
}
// per-character reveal: each glyph fades in, rises and sharpens; p in [0,1]
export function reveal(ctx, s, x, y, p, o = {}) {
  if (p <= 0) return;
  const chars = [...s];
  const size = o.size ?? 40, sp = o.spacing ?? 0;
  ctx.save(); ctx.font = `${o.weight ?? 500} ${size}px ${o.font ?? F.serif}`; ctx.letterSpacing = '0px';
  const ws = chars.map(c => ctx.measureText(c).width + sp);
  ctx.restore();
  const total = ws.reduce((a, b) => a + b, 0) - sp;
  let cx = (o.align ?? 'center') === 'center' ? x - total / 2 : (o.align === 'right' ? x - total : x);
  const n = chars.length, spread = o.spread ?? 0.6;
  chars.forEach((c, i) => {
    const t0 = n > 1 ? (i / (n - 1)) * spread : 0;
    const k = clamp((p - t0) / (1 - spread + 1e-6));
    const e = ease.out(k);
    if (k > 0) text(ctx, c, cx + ws[i] / 2, y + (1 - e) * (o.rise ?? 14), { ...o, align: 'center', spacing: 0, alpha: (o.alpha ?? 1) * e, glow: (o.glow ?? 0) + (1 - e) * 24 });
    cx += ws[i];
  });
}

// --- 3D ------------------------------------------------------------------------
// camera: {yaw, pitch, dist, fov(px focal), cx, cy, tx,ty,tz target}
export function project(x, y, z, cam) {
  x -= cam.tx ?? 0; y -= cam.ty ?? 0; z -= cam.tz ?? 0;
  const cy = Math.cos(cam.yaw), sy = Math.sin(cam.yaw);
  let X = x * cy - z * sy, Z = x * sy + z * cy;
  const cp = Math.cos(cam.pitch), sp = Math.sin(cam.pitch);
  let Y = y * cp - Z * sp; Z = y * sp + Z * cp;
  Z += cam.dist;
  const s = cam.fov / Math.max(1, Z);
  return [cam.cx + X * s, cam.cy - Y * s, Z, s];
}

// --- misc shapes -------------------------------------------------------------
export function rrect(ctx, x, y, w, h, r) { ctx.beginPath(); ctx.roundRect(x, y, w, h, r); }
export function arrowHead(ctx, x, y, ang, size, color, a = 1) {
  alpha(ctx, a, () => { ctx.fillStyle = color; ctx.beginPath(); ctx.moveTo(x, y); ctx.lineTo(x - size * Math.cos(ang - 0.45), y - size * Math.sin(ang - 0.45)); ctx.lineTo(x - size * Math.cos(ang + 0.45), y - size * Math.sin(ang + 0.45)); ctx.closePath(); ctx.fill(); });
}

// --- backgrounds -------------------------------------------------------------
export function makeStars(n, seed = 7, w = W, h = H) {
  const r = rng(seed); const s = [];
  for (let i = 0; i < n; i++) { const m = Math.pow(r(), 3); s.push({ x: r() * w, y: r() * h, r: 0.4 + m * 1.9, a: 0.25 + 0.75 * r(), ph: r() * TAU, sp: 0.5 + r() * 2, hue: r() }); }
  return s;
}
export function drawStars(ctx, stars, t, o = {}) {
  const a0 = o.alpha ?? 1; if (a0 <= 0) return;
  const dx = o.dx ?? 0, dy = o.dy ?? 0, sc = o.scale ?? 1;
  for (const s of stars) {
    let x = (s.x + dx * (0.3 + s.r)) % W; if (x < 0) x += W;
    let y = (s.y + dy * (0.3 + s.r)) % H; if (y < 0) y += H;
    if (sc !== 1) { x = W / 2 + (x - W / 2) * sc; y = H / 2 + (y - H / 2) * sc; }
    const tw = 0.65 + 0.35 * Math.sin(t * s.sp + s.ph);
    const col = s.hue < 0.15 ? '#ffd9b0' : s.hue > 0.85 ? '#b8d4ff' : '#ffffff';
    dot(ctx, x, y, s.r, col, a0 * s.a * tw);
    if (s.r > 1.6) glow(ctx, x, y, s.r * 6, col, a0 * 0.25 * tw);
  }
}
// pre-rendered soft nebula on a small canvas (cheap to scale up)
export function makeNebula(colors, seed = 3, w = 480, h = 270, scale = 2.2, strength = 1) {
  const c = document.createElement('canvas'); c.width = w; c.height = h;
  const g = c.getContext('2d'); const img = g.createImageData(w, h);
  const cols = colors.map(rgb);
  for (let y = 0; y < h; y++) for (let x = 0; x < w; x++) {
    const u = x / w * scale + seed * 10, v = y / h * scale * (h / w) * 1.7 + seed * 3;
    const n1 = fbm(u, v, 5) * 0.5 + 0.5, n2 = fbm(u * 1.7 + 9, v * 1.7 - 4, 4) * 0.5 + 0.5;
    const d = Math.pow(clamp(n1 * 1.25 - 0.35), 2.2) * strength;
    const i = (y * w + x) * 4;
    const c1 = cols[0], c2 = cols[1] ?? cols[0];
    img.data[i] = lerp(c1[0], c2[0], n2) * d; img.data[i + 1] = lerp(c1[1], c2[1], n2) * d; img.data[i + 2] = lerp(c1[2], c2[2], n2) * d;
    img.data[i + 3] = 255;
  }
  g.putImageData(img, 0, 0);
  return c;
}
export function vgrad(ctx, stops, x0 = 0, y0 = 0, x1 = 0, y1 = H) {
  const g = ctx.createLinearGradient(x0, y0, x1, y1); stops.forEach(([o, c]) => g.addColorStop(o, c)); return g;
}
export function fill(ctx, style) { ctx.fillStyle = style; ctx.fillRect(0, 0, W, H); }
export function vignette(ctx, strength = 0.6) {
  const g = ctx.createRadialGradient(W / 2, H / 2, H * 0.35, W / 2, H / 2, H * 1.0);
  g.addColorStop(0, 'rgba(0,0,0,0)'); g.addColorStop(1, `rgba(0,0,0,${strength})`);
  ctx.fillStyle = g; ctx.fillRect(0, 0, W, H);
}
// label with a thin leader line
export function callout(ctx, x, y, lx, ly, title, sub, color, a = 1, o = {}) {
  if (a <= 0.003) return;
  const k = ease.out(clamp(a));
  const ex = lerp(x, lx, k), ey = lerp(y, ly, k);
  line(ctx, [[x, y], [ex, ey]], rgba(color, 0.8), 1.5, a);
  dot(ctx, x, y, 4, color, a);
  const al = o.align ?? (lx >= x ? 'left' : 'right');
  const off = al === 'left' ? 12 : -12;
  text(ctx, title, lx + off, ly - (sub ? 18 : 0), { size: o.size ?? 34, weight: 600, color: o.titleColor ?? '#fff', align: al, alpha: a, glow: 10, glowColor: color });
  if (sub) text(ctx, sub, lx + off, ly + 22, { size: o.subSize ?? 24, weight: 400, color: rgba(o.subColor ?? '#c9d6e8', 0.95), align: al, alpha: a });
}
// a gently glowing tag/badge
export function badge(ctx, s, x, y, color, a = 1, o = {}) {
  if (a <= 0.003) return;
  const size = o.size ?? 28; const w = measure(ctx, s, { size, weight: o.weight ?? 600, spacing: o.spacing ?? 2, font: o.font }) + size * 1.4; const h = size * 1.9;
  alpha(ctx, a, () => {
    rrect(ctx, x - w / 2, y - h / 2, w, h, h / 2);
    ctx.fillStyle = rgba(o.bg ?? '#000000', o.bgA ?? 0.45); ctx.fill();
    ctx.strokeStyle = rgba(color, 0.85); ctx.lineWidth = 1.5; ctx.stroke();
  });
  text(ctx, s, x, y + 1, { size, weight: o.weight ?? 600, color: o.color ?? '#fff', alpha: a, spacing: o.spacing ?? 2, font: o.font });
}
