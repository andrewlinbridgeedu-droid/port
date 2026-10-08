// 2026 物理学奖 · 冰中捕光 —— IceCube 与天体物理高能中微子
import * as L from '../lib.js';
import { drawTitle } from '../core.js';
const { W, H, TAU, clamp, lerp, smooth, ease, prog, glow, dot, line, text, reveal, F, rgba, project, fill, vgrad,
  additive, alpha, callout, badge, partial, rng, noise2, fbm, drawStars, makeStars, makeNebula, win, rainbow, hash } = L;

const P = { gold: '#e8c477', cyan: '#5fe3ff', ice: '#a8e8ff', blue: '#3d86ff', violet: '#8f7dff', orange: '#ffa25a', red: '#ff5f57', green: '#57f0a8', white: '#f4fbff' };
let stars, starsFar, neb, nebWarm, hand, handGlow, strings = [], doms = [], earthPts = [], bgEvents = [], galPlane = [];

// ---------------------------------------------------------------- init
function init() {
  stars = makeStars(900, 11); starsFar = makeStars(1600, 23);
  neb = makeNebula(['#123a6b', '#3b1f6b'], 4, 480, 270, 2.0, 0.9);
  nebWarm = makeNebula(['#3a2a5e', '#0f4a6a'], 9, 480, 270, 2.4, 0.8);
  // ghostly hand silhouette, drawn once
  hand = document.createElement('canvas'); hand.width = 600; hand.height = 820;
  const g = hand.getContext('2d');
  const grad = g.createLinearGradient(0, 0, 0, 820); grad.addColorStop(0, '#d8f4ff'); grad.addColorStop(1, '#5fb6e8');
  g.fillStyle = grad;
  const finger = (bx, by, len, w, rot) => { g.save(); g.translate(bx, by); g.rotate(rot); g.beginPath(); g.roundRect(-w / 2, -len, w, len + 40, w / 2); g.fill(); g.restore(); };
  g.beginPath(); g.roundRect(150, 360, 300, 340, 90); g.fill();
  finger(196, 420, 285, 62, -0.13); finger(266, 410, 325, 66, -0.035); finger(338, 412, 300, 63, 0.06); finger(410, 440, 240, 55, 0.17);
  finger(190, 650, 250, 70, -0.72);
  g.beginPath(); g.roundRect(205, 640, 200, 200, 30); g.fill();
  handGlow = document.createElement('canvas'); handGlow.width = 600; handGlow.height = 820;
  const hg = handGlow.getContext('2d'); hg.filter = 'blur(18px)'; hg.drawImage(hand, 0, 0);

  // IceCube geometry: 78 strings on a 125 m triangular grid + 8 DeepCore, 60 DOMs each
  const pts = [];
  for (let i = -6; i <= 6; i++) for (let j = -6; j <= 6; j++) {
    const x = 125 * (i + j / 2), z = 125 * (j * Math.sqrt(3) / 2);
    const ring = Math.max(Math.abs(i), Math.abs(j), Math.abs(i + j));
    pts.push({ x, z, ring });
  }
  const inner = pts.filter(p => p.ring <= 4);
  const r5 = pts.filter(p => p.ring === 5).sort((a, b) => Math.hypot(a.x - 260, a.z + 120) - Math.hypot(b.x - 260, b.z + 120)).slice(0, 17);
  strings = [...inner, ...r5].map(p => ({ x: p.x - 40, z: p.z + 20, deep: false }));
  for (let k = 0; k < 8; k++) { const a = k / 8 * TAU + 0.3; strings.push({ x: -40 + 62 * Math.cos(a), z: 20 + 62 * Math.sin(a), deep: true }); }
  doms = [];
  strings.forEach((s, si) => {
    for (let d = 0; d < 60; d++) {
      const y = s.deep ? (d < 10 ? 380 - d * 10 : -150 - (d - 10) * 7) : 500 - d * (1000 / 59);
      doms.push({ x: s.x, y, z: s.z, si });
    }
  });
  // dotted Earth
  const N = 1700, r = rng(5);
  for (let i = 0; i < N; i++) {
    const yy = 1 - (i / (N - 1)) * 2, rad = Math.sqrt(1 - yy * yy), th = i * 2.399963;
    const x = Math.cos(th) * rad, z = Math.sin(th) * rad;
    const lat = Math.asin(yy), lon = Math.atan2(z, x);
    const land = fbm(Math.cos(lat) * Math.cos(lon) * 1.6 + 3, Math.sin(lat) * 1.6 + Math.cos(lat) * Math.sin(lon) * 1.3, 4) > 0.08;
    earthPts.push({ x, y: yy, z, land, j: r() });
  }
  // background neutrino events on the sky map
  const rb = rng(77);
  for (let i = 0; i < 700; i++) bgEvents.push({ ra: rb() * 360, dec: Math.asin(rb() * 2 - 1) * 180 / Math.PI, ph: rb() * TAU, a: 0.2 + rb() * 0.5 });
  // galactic plane in equatorial coordinates
  for (let l = 0; l < 360; l += 1.5) galPlane.push({ l, ...galToEq(l, 0) });
}

// ---------------------------------------------------------------- shared painters
function space(c, st, o = {}) {
  fill(c, vgrad(c, [[0, '#02040b'], [0.6, '#040f1e'], [1, '#07182b']]));
  alpha(c, o.neb ?? 0.85, () => c.drawImage(o.warm ? nebWarm : neb, -60 + Math.sin(st * 0.05) * 30, -30, W + 120, H + 60));
  drawStars(c, starsFar, st, { dx: -st * (o.drift ?? 2) * 0.5, alpha: 0.55 });
  drawStars(c, stars, st, { dx: -st * (o.drift ?? 2) });
}
function iceBg(c, st, o = {}) {
  const g = c.createRadialGradient(W / 2, H * 0.45, 50, W / 2, H * 0.5, W * 0.75);
  g.addColorStop(0, o.c0 ?? '#0d3357'); g.addColorStop(0.55, o.c1 ?? '#061a31'); g.addColorStop(1, '#01060e');
  fill(c, g);
  // drifting specks in the ice
  const r = rng(91);
  for (let i = 0; i < 160; i++) {
    const x = (r() * W + st * (6 + r() * 10)) % W, y = (r() * H + Math.sin(st * 0.3 + i) * 6);
    dot(c, x, y, 0.6 + r() * 1.3, '#9fd9ff', 0.08 + 0.12 * r());
  }
}
// streaks travelling along a direction; returns nothing, purely visual
function streaks(c, st, n, o) {
  const ang = o.angle ?? 0, ca = Math.cos(ang), sa = Math.sin(ang);
  const cx = o.cx ?? W / 2, cy = o.cy ?? H / 2;
  const D = (o.D ?? (W + H)) + 600;
  const r = rng(o.seed ?? 1);
  for (let i = 0; i < n; i++) {
    const off = (r() - 0.5) * (o.spread ?? (W + H) * 1.1), ph = r(), spd = o.speed * (0.7 + 0.6 * r()), len = o.len * (0.5 + r());
    const u = ((st * spd + ph * D) % D) - D / 2;
    const hx = cx + ca * u - sa * off, hy = cy + sa * u + ca * off;
    const tx = hx - ca * len, ty = hy - sa * len;
    const a = (o.alpha ?? 1) * (0.35 + 0.65 * r());
    const g = c.createLinearGradient(tx, ty, hx, hy);
    g.addColorStop(0, rgba(o.color, 0)); g.addColorStop(1, rgba(o.color, a));
    c.strokeStyle = g; c.lineWidth = o.w ?? 1.6; c.lineCap = 'round';
    c.beginPath(); c.moveTo(tx, ty); c.lineTo(hx, hy); c.stroke();
    if (o.heads !== false) glow(c, hx, hy, o.head ?? 9, o.color, a * 0.8);
  }
}
// radial streaks emitted from a point (e.g. the Sun)
function emanate(c, st, x0, y0, n, o) {
  const r = rng(o.seed ?? 3);
  for (let i = 0; i < n; i++) {
    const ang = (o.a0 ?? -0.35) + r() * ((o.a1 ?? 0.35) - (o.a0 ?? -0.35));
    const spd = o.speed * (0.75 + 0.5 * r()), len = o.len * (0.5 + r()), ph = r();
    const D = o.D ?? 2400;
    const u = (st * spd + ph * D) % D + (o.r0 ?? 0);
    const hx = x0 + Math.cos(ang) * u, hy = y0 + Math.sin(ang) * u;
    const tx = x0 + Math.cos(ang) * Math.max(o.r0 ?? 0, u - len), ty = y0 + Math.sin(ang) * Math.max(o.r0 ?? 0, u - len);
    const a = (o.alpha ?? 1) * (0.35 + 0.65 * r());
    const g = c.createLinearGradient(tx, ty, hx, hy); g.addColorStop(0, rgba(o.color, 0)); g.addColorStop(1, rgba(o.color, a));
    c.strokeStyle = g; c.lineWidth = o.w ?? 1.4; c.beginPath(); c.moveTo(tx, ty); c.lineTo(hx, hy); c.stroke();
    glow(c, hx, hy, 7, o.color, a * 0.7);
  }
}
function sun(c, x, y, R, st) {
  additive(c, () => {
    glow(c, x, y, R * 4.2, '#ff7a1a', 0.35); glow(c, x, y, R * 2.4, '#ffb347', 0.55);
    for (let i = 0; i < 140; i++) {
      const a = i / 140 * TAU, n = noise2(Math.cos(a) * 2 + st * 0.15, Math.sin(a) * 2 - st * 0.1);
      const l = R * (1.05 + 0.35 * (n * 0.5 + 0.5));
      line(c, [[x + Math.cos(a) * R * 0.95, y + Math.sin(a) * R * 0.95], [x + Math.cos(a) * l, y + Math.sin(a) * l]], '#ffc070', 2, 0.18);
    }
  });
  const g = c.createRadialGradient(x - R * 0.2, y - R * 0.2, R * 0.1, x, y, R);
  g.addColorStop(0, '#fffbe8'); g.addColorStop(0.5, '#ffd27a'); g.addColorStop(0.85, '#ff9a2e'); g.addColorStop(1, '#ff6a00');
  c.fillStyle = g; c.beginPath(); c.arc(x, y, R, 0, TAU); c.fill();
  // granulation
  alpha(c, 0.18, () => { for (let i = 0; i < 90; i++) { const a = hash(i) * TAU, rr = Math.sqrt(hash(i + 9)) * R * 0.9; dot(c, x + Math.cos(a + st * 0.02) * rr, y + Math.sin(a + st * 0.02) * rr, 6 + hash(i + 3) * 10, '#fff2c0', 0.5 + 0.5 * Math.sin(st * 2 + i)); } });
}
function earthGlobe(c, x, y, R, st, o = {}) {
  additive(c, () => glow(c, x, y, R * 1.6, '#2a7bff', 0.35 * (o.a ?? 1)));
  const g = c.createRadialGradient(x - R * 0.3, y - R * 0.3, R * 0.1, x, y, R);
  g.addColorStop(0, '#0f3a6a'); g.addColorStop(1, '#03122a');
  alpha(c, o.a ?? 1, () => { c.fillStyle = g; c.beginPath(); c.arc(x, y, R, 0, TAU); c.fill(); });
  const yaw = st * 0.18, tilt = 0.38;
  const cy = Math.cos(yaw), sy = Math.sin(yaw), ct = Math.cos(tilt), stt = Math.sin(tilt);
  for (const p of earthPts) {
    let X = p.x * cy - p.z * sy, Z = p.x * sy + p.z * cy;
    let Y = p.y * ct - Z * stt; Z = p.y * stt + Z * ct;
    if (Z < -0.05 && !o.back) continue;
    const front = clamp((Z + 0.2) / 1.2);
    const col = p.land ? '#7ff0c0' : '#5aa8ff';
    dot(c, x + X * R, y - Y * R, (p.land ? 1.9 : 1.3) * (0.6 + 0.5 * front), col, (o.a ?? 1) * (p.land ? 0.85 : 0.45) * (0.25 + 0.75 * front));
  }
  alpha(c, o.a ?? 1, () => { c.strokeStyle = 'rgba(120,190,255,0.55)'; c.lineWidth = 2; c.beginPath(); c.arc(x, y, R, 0, TAU); c.stroke(); });
}
function smallEarth(c, x, y, R, a = 1) {
  additive(c, () => glow(c, x, y, R * 3, '#3d8bff', 0.5 * a));
  alpha(c, a, () => {
    const g = c.createRadialGradient(x - R * 0.4, y - R * 0.4, 2, x, y, R);
    g.addColorStop(0, '#9fd2ff'); g.addColorStop(0.5, '#2f6fd6'); g.addColorStop(1, '#0b2a63');
    c.fillStyle = g; c.beginPath(); c.arc(x, y, R, 0, TAU); c.fill();
    c.fillStyle = 'rgba(120,230,170,0.6)'; c.beginPath(); c.ellipse(x - R * 0.2, y - R * 0.1, R * 0.35, R * 0.22, 0.6, 0, TAU); c.fill();
    c.beginPath(); c.ellipse(x + R * 0.35, y + R * 0.3, R * 0.2, R * 0.28, -0.3, 0, TAU); c.fill();
  });
}

// IceCube detector in 3D --------------------------------------------------------
function detCam(st, o = {}) {
  return { yaw: (o.yaw ?? 0.6) + st * (o.spin ?? 0.06), pitch: o.pitch ?? 0.32, dist: o.dist ?? 2100, fov: o.fov ?? 1250, cx: o.cx ?? W / 2, cy: o.cy ?? H / 2 + 20 };
}
function drawDetector(c, cam, o = {}) {
  const a = o.a ?? 1;
  // strings
  for (const s of strings) {
    const t = project(s.x, 520, s.z, cam), b = project(s.x, -520, s.z, cam);
    line(c, [[t[0], t[1]], [b[0], b[1]]], s.deep ? '#7fb8ff' : '#6aa6d6', 1, a * 0.22);
  }
  // cube outline
  if (o.cube) {
    const q = 520, cA = o.cube;
    const v = [[-q, -q, -q], [q, -q, -q], [q, -q, q], [-q, -q, q], [-q, q, -q], [q, q, -q], [q, q, q], [-q, q, q]].map(p => project(p[0] - 40, p[1], p[2] + 20, cam));
    const E = [[0, 1], [1, 2], [2, 3], [3, 0], [4, 5], [5, 6], [6, 7], [7, 4], [0, 4], [1, 5], [2, 6], [3, 7]];
    c.save(); c.setLineDash([10, 8]);
    for (const [i, j] of E) line(c, [[v[i][0], v[i][1]], [v[j][0], v[j][1]]], P.gold, 1.4, cA * 0.6);
    c.restore();
  }
  // DOMs
  c.fillStyle = '#bfe6ff';
  for (const d of doms) {
    const p = project(d.x, d.y, d.z, cam);
    const fog = clamp(1.25 - (p[2] - cam.dist + 700) / 1600);
    c.globalAlpha = a * 0.55 * fog;
    const r = Math.max(0.8, 2.6 * p[3]);
    c.fillRect(p[0] - r / 2, p[1] - r / 2, r, r);
  }
  c.globalAlpha = 1;
}
// light up DOMs: hits = [{i, t, q}] ; colour by time
function drawHits(c, cam, hits, now, o = {}) {
  additive(c, () => {
    for (const h of hits) {
      if (now < h.t) continue;
      const d = doms[h.i]; const p = project(d.x, d.y, d.z, cam);
      const age = now - h.t;
      const flash = 1 + 2.2 * Math.exp(-age * 5);
      const col = o.color ?? rainbow(h.tn);
      const r = (4 + 22 * Math.sqrt(h.q)) * p[3] * flash;
      glow(c, p[0], p[1], r * 2.2, o.colorHex ?? '#ffffff', 0.08 * (o.a ?? 1) * flash);
      c.globalAlpha = clamp((o.a ?? 1) * (0.65 + 0.35 * h.q));
      c.fillStyle = col; c.beginPath(); c.arc(p[0], p[1], Math.max(1.3, r * 0.42), 0, TAU); c.fill();
      c.globalAlpha = 1;
    }
  });
}
function trackHits(A, B, v, maxD = 170) {
  const dx = B[0] - A[0], dy = B[1] - A[1], dz = B[2] - A[2]; const Ln = Math.hypot(dx, dy, dz);
  const u = [dx / Ln, dy / Ln, dz / Ln];
  const hits = [];
  doms.forEach((d, i) => {
    const wx = d.x - A[0], wy = d.y - A[1], wz = d.z - A[2];
    const s = wx * u[0] + wy * u[1] + wz * u[2];
    if (s < 0 || s > Ln) return;
    const px = wx - s * u[0], py = wy - s * u[1], pz = wz - s * u[2];
    const dist = Math.hypot(px, py, pz);
    if (dist > maxD) return;
    hits.push({ i, t: s / v + dist / (v * 0.76) * 0.6, q: Math.exp(-dist / 55) });
  });
  const tmax = Math.max(...hits.map(h => h.t));
  hits.forEach(h => h.tn = h.t / tmax);
  return { hits, u, Ln };
}
function cascadeHits(C, v, maxD = 260) {
  const hits = [];
  doms.forEach((d, i) => { const dist = Math.hypot(d.x - C[0], d.y - C[1], d.z - C[2]); if (dist < maxD) hits.push({ i, t: dist / v, q: Math.exp(-dist / 80) }); });
  const tmax = Math.max(...hits.map(h => h.t)); hits.forEach(h => h.tn = h.t / tmax);
  return hits;
}
let TRACK, CASC;

// polar landscape with vertical camera offset `dy` (0 = surface view)
function polar(c, st, dy, o = {}) {
  const hz = 600 - dy; // horizon / ice surface
  fill(c, vgrad(c, [[0, '#01030a'], [Math.max(0.01, hz / H), '#0a2036']]));
  drawStars(c, stars, st, { dy: -dy * 0.3, alpha: clamp(1 - dy / 700) });
  // aurora
  if (hz > 0) {
    additive(c, () => {
      for (let x = 0; x < W; x += 7) {
        const n1 = noise2(x * 0.0016, st * 0.05), n2 = noise2(x * 0.004 + 9, st * 0.09);
        const base = hz - 170 + n1 * 70 - dy * 0.05;
        const hgt = 160 + 120 * (n2 * 0.5 + 0.5);
        const a = 0.16 * (0.4 + 0.6 * (noise2(x * 0.003 - 4, st * 0.12) * 0.5 + 0.5)) * (o.aurora ?? 1);
        const g = c.createLinearGradient(0, base - hgt, 0, base);
        g.addColorStop(0, 'rgba(120,80,255,0)'); g.addColorStop(0.55, `rgba(80,255,190,${a})`); g.addColorStop(1, `rgba(80,255,190,${a * 0.2})`);
        c.fillStyle = g; c.fillRect(x, base - hgt, 7.5, hgt);
      }
    });
  }
  // ice body
  const scale = o.scale ?? 0.34; // px per metre
  const bed = hz + 2800 * scale;
  const ig = c.createLinearGradient(0, hz, 0, bed);
  ig.addColorStop(0, '#e9f6ff'); ig.addColorStop(0.03, '#a9d7f2'); ig.addColorStop(0.25, '#3f86b8'); ig.addColorStop(0.6, '#123f6b'); ig.addColorStop(1, '#071a33');
  c.fillStyle = ig; c.fillRect(0, hz, W, bed - hz);
  c.fillStyle = '#1b1410'; c.fillRect(0, bed, W, H);
  // surface sheen
  line(c, [[0, hz], [W, hz]], '#ffffff', 2, 0.7, 10);
  // IceCube Lab
  const lx = 960, ly = hz;
  alpha(c, 1, () => {
    c.fillStyle = '#0b1220'; c.fillRect(lx - 70, ly - 46, 140, 46); c.fillRect(lx - 12, ly - 78, 24, 34); c.fillRect(lx - 70, ly - 10, 140, 10);
    for (let i = 0; i < 6; i++) { c.fillStyle = `rgba(255,214,140,${0.7 + 0.3 * Math.sin(st * 3 + i)})`; c.fillRect(lx - 58 + i * 20, ly - 34, 10, 8); }
  });
  glow(c, lx, ly - 30, 60, '#ffd27a', 0.25);
  return { hz, scale, bed };
}

// galactic -> equatorial (degrees)
function galToEq(l, b) {
  const d2r = Math.PI / 180, aG = 192.85948 * d2r, dG = 27.12825 * d2r, lN = 122.93192 * d2r;
  l *= d2r; b *= d2r;
  const sd = Math.sin(dG) * Math.sin(b) + Math.cos(dG) * Math.cos(b) * Math.cos(lN - l);
  const dec = Math.asin(sd);
  const y = Math.cos(b) * Math.sin(lN - l), x = Math.cos(dG) * Math.sin(b) - Math.sin(dG) * Math.cos(b) * Math.cos(lN - l);
  let ra = aG + Math.atan2(y, x);
  ra = ((ra / d2r) % 360 + 360) % 360;
  return { ra, dec: dec / d2r };
}
function moll(ra, dec, cx, cy, k) {
  const lam = -((ra > 180 ? ra - 360 : ra)) * Math.PI / 180, phi = dec * Math.PI / 180;
  let th = phi;
  for (let i = 0; i < 12; i++) { const f = 2 * th + Math.sin(2 * th) - Math.PI * Math.sin(phi); th -= f / (2 + 2 * Math.cos(2 * th) + 1e-9); }
  return [cx + k * (2 * Math.SQRT2 / Math.PI) * lam * Math.cos(th), cy - k * Math.SQRT2 * Math.sin(th)];
}

// ---------------------------------------------------------------- scenes
const S = {};

S.title = (c, st) => {
  space(c, st, { drift: 5 });
  additive(c, () => { glow(c, W / 2, H * 1.05, 1100, '#0e5a86', 0.55); });
  streaks(c, st, 34, { angle: 0.42, speed: 1500, len: 340, color: P.cyan, seed: 5, alpha: 0.85, w: 1.5 });
  drawTitle(c, st, { glow: P.cyan });
};

S.ghost = (c, st, sp) => {
  space(c, st, { drift: 2, neb: 0.6 });
  const sx = -60, sy = 520;
  sun(c, sx, sy, 300, st);
  emanate(c, st, sx, sy, 170, { color: P.cyan, speed: 1300, len: 220, seed: 8, a0: -0.42, a1: 0.42, r0: 300, D: 2600, alpha: 0.85 });
  // ghostly hand
  const hx = 1080, hy = 545, hs = 0.95;
  const ha = smooth(0.3, 1.8, st) * (1 - 0.35 * smooth(sp.cue(1), sp.cue(1) + 1, st));
  alpha(c, ha * 0.2, () => c.drawImage(hand, hx - 300 * hs, hy - 410 * hs, 600 * hs, 820 * hs));
  additive(c, () => alpha(c, ha * 0.45, () => c.drawImage(handGlow, hx - 300 * hs, hy - 410 * hs, 600 * hs, 820 * hs)));
  // streaks seen through the hand are unaffected – draw a few brighter ones over it
  c.save(); c.beginPath(); c.rect(hx - 300 * hs, hy - 410 * hs, 600 * hs, 820 * hs); c.clip();
  emanate(c, st, sx, sy, 60, { color: '#d9fbff', speed: 1300, len: 200, seed: 21, a0: -0.25, a1: 0.25, r0: 300, D: 2600, alpha: 0.6 * ha });
  c.restore();
  text(c, '每一秒 · 数以百万亿计', hx, 150, { size: 40, weight: 700, color: P.white, spacing: 6, alpha: win(st, 1.2, sp.cue(1)), glow: 16, glowColor: P.cyan });
  // fingernail square
  const k = smooth(sp.cue(1), sp.cue(1) + 1.0, st);
  const nx = 1080 + (275 - 300) * hs, ny = 545 + (150 - 410) * hs, ns = lerp(90, 130, k);
  if (k > 0) {
    alpha(c, k, () => { c.strokeStyle = P.gold; c.lineWidth = 2.5; c.setLineDash([8, 6]); c.strokeRect(nx - ns / 2, ny - ns / 2, ns, ns); c.setLineDash([]); });
    callout(c, nx + ns / 2, ny, 1450, 300, '约 1 平方厘米', '指甲盖大小', P.gold, k);
    const n = Math.floor(600 * clamp((st - sp.cue(1) - 0.6) / 2.6));
    text(c, `${n} 亿`, 1580, 450, { size: 92, weight: 900, color: P.white, align: 'center', alpha: k, glow: 24, glowColor: P.cyan, spacing: 2 });
    text(c, '来自太阳的中微子 / 每秒', 1580, 530, { size: 28, weight: 500, color: '#cfe6f5', alpha: k * 0.9, spacing: 3 });
  }
  // properties
  const pa = smooth(sp.cue(2), sp.cue(2) + 0.8, st);
  ['电荷：零', '质量：几乎为零', '与物质：几乎不作用'].forEach((s, i) => badge(c, s, 1580, 650 + i * 80, P.cyan, smooth(sp.cue(2) + i * 0.7, sp.cue(2) + i * 0.7 + 0.6, st), { size: 30 }));
};

S.earth = (c, st, sp) => {
  space(c, st, { drift: 2 });
  const ex = W / 2, ey = 455, R = 320;
  const dim = 1 - 0.45 * smooth(sp.cue(1), sp.cue(1) + 1, st);
  earthGlobe(c, ex, ey, R, st + 20, { a: dim });
  // parallel neutrinos sailing straight through
  additive(c, () => streaks(c, st, 120, { angle: 0, speed: 1100, len: 300, color: P.cyan, seed: 33, spread: 900, cy: ey, alpha: 0.9, w: 1.4 }));
  const a1 = smooth(1.5, 2.5, st) * (1 - smooth(sp.cue(1) - 0.3, sp.cue(1) + 0.4, st));
  text(c, '穿越整个地球，被拦下的几率', ex, 828, { size: 34, weight: 500, color: '#dcecf8', alpha: a1, spacing: 3 });
  text(c, '不到十亿分之一', ex, 884, { size: 44, weight: 800, color: P.gold, alpha: a1, spacing: 6, glow: 16, glowColor: P.gold });
  // "幽灵粒子"
  const k = clamp((st - sp.cue(1)) / 1.6);
  if (k > 0) {
    const g = c.createLinearGradient(0, ey - 90, 0, ey + 90); g.addColorStop(0, '#ffffff'); g.addColorStop(1, '#8fe9ff');
    for (let i = 0; i < 3; i++) {
      const dx = Math.sin(st * 2.3 + i * 2) * 6 * (1 - k * 0.6), dy = Math.cos(st * 1.7 + i) * 4;
      reveal(c, '幽灵粒子', ex + dx, ey + dy, k, { size: 150, weight: 900, color: i === 2 ? g : (i ? 'rgba(255,90,160,0.35)' : 'rgba(80,200,255,0.35)'), spacing: 30, glow: i === 2 ? 30 : 0, glowColor: P.cyan, spread: 0.5 });
    }
  }
};

S.messengers = (c, st, sp) => {
  space(c, st, { drift: 1.5, warm: true, neb: 0.7 });
  const sx = 300, sy = 540, ex = 1660, ey = 540;
  // magnetic field lines (lower half)
  const fa = smooth(sp.cue(1) - 0.5, sp.cue(1) + 0.8, st);
  for (let k = 0; k < 7; k++) {
    const pts = []; for (let x = 420; x <= 1540; x += 20) pts.push([x, 640 + k * 42 + Math.sin(x * 0.006 + k + st * 0.4) * 26]);
    line(c, pts, P.violet, 1.2, fa * 0.3);
  }
  // dust cloud on the light path
  const cxd = 980, cyd = 300;
  additive(c, () => glow(c, cxd, cyd, 230, '#6a4a3a', 0.25));
  for (let i = 0; i < 26; i++) {
    const a = hash(i) * TAU, rr = 40 + hash(i + 4) * 120;
    const x = cxd + Math.cos(a) * rr * 1.2 + Math.sin(st * 0.3 + i) * 6, y = cyd + Math.sin(a) * rr * 0.7;
    const g = c.createRadialGradient(x, y, 0, x, y, 90 + hash(i + 7) * 60);
    g.addColorStop(0, 'rgba(26,16,12,0.85)'); g.addColorStop(0.6, 'rgba(46,30,22,0.45)'); g.addColorStop(1, 'rgba(40,26,20,0)');
    c.fillStyle = g; c.beginPath(); c.arc(x, y, 150, 0, TAU); c.fill();
  }
  // source: black hole with disk and jets
  additive(c, () => {
    glow(c, sx, sy, 260, '#ff8a3a', 0.3);
    for (let i = 0; i < 2; i++) { const dir = i ? 1 : -1; for (let k = 0; k < 18; k++) { const u = ((st * 0.9 + k / 18) % 1); glow(c, sx + dir * 6 * u, sy + dir * u * 300, 24 * (1 - u) + 6, '#9fd8ff', 0.5 * (1 - u)); } }
  });
  c.save(); c.translate(sx, sy); c.scale(1, 0.32);
  for (let i = 0; i < 260; i++) { const a = hash(i) * TAU + st * (0.8 + 1.5 * hash(i + 1)), rr = 50 + hash(i + 2) * 70; dot(c, Math.cos(a) * rr, Math.sin(a) * rr, 2.2, i % 3 ? '#ffb46a' : '#fff0c8', 0.75); }
  c.restore();
  dot(c, sx, sy, 34, '#000000', 1); c.strokeStyle = 'rgba(255,190,110,0.9)'; c.lineWidth = 3; c.beginPath(); c.arc(sx, sy, 37, 0, TAU); c.stroke();
  smallEarth(c, ex, ey, 46);
  text(c, '地球', ex, ey + 92, { size: 28, color: '#cfe3ff', alpha: smooth(0.5, 1.5, st) });

  // 1. light: gold photons along an arc, swallowed by dust
  const a0 = smooth(0.5, 1.5, st);
  const bez = (u) => { const x = (1 - u) * (1 - u) * sx + 2 * (1 - u) * u * 980 + u * u * ex, y = (1 - u) * (1 - u) * sy + 2 * (1 - u) * u * 80 + u * u * ey; return [x, y]; };
  additive(c, () => { for (let i = 0; i < 40; i++) { const u = (st * 0.12 + i / 40) % 1; if (u > 0.5) continue; const [x, y] = bez(u); const fade = 1 - smooth(0.38, 0.5, u); glow(c, x, y, 16, '#ffd27a', a0 * fade * 0.9); dot(c, x, y, 2.2, '#fff4cf', a0 * fade); } });
  c.save(); c.setLineDash([4, 10]); line(c, Array.from({ length: 30 }, (_, i) => bez(i / 29 * 0.5)), '#ffd27a', 1.2, a0 * 0.35); c.restore();
  callout(c, 990, 215, 1190, 150, '光', '被星际尘埃遮挡、吸收', '#ffd27a', a0 * smooth(sp.cue(0) + 1.5, sp.cue(0) + 2.5, st));

  // 2. cosmic rays: charged, scrambled paths
  const r = rng(17);
  const crA = smooth(sp.cue(1), sp.cue(1) + 1, st);
  for (let p = 0; p < 7; p++) {
    const pts = []; let x = sx + 30, y = sy + 20, ang = 0;
    for (let k = 0; k < 200; k++) {
      ang = clamp(0.2 + 1.1 * noise2(p * 7.1, k * 0.045) + 0.55 * Math.sin(k * 0.21 + p * 1.7) - (y - 735) / 150, -1.15, 1.25);
      x += Math.cos(ang) * 8; y += Math.sin(ang) * 8;
      y = Math.min(Math.max(y, 570), 900);
      pts.push([x, y]);
      if (x > ex - 170) break;
    }
    const end = pts[pts.length - 1]; const ang2 = Math.atan2(ey - end[1], ex - end[0]);
    for (let k = 1; k <= 8; k++) pts.push([end[0] + (ex - 40 * Math.cos(ang2) - end[0]) * k / 8, end[1] + (ey - 40 * Math.sin(ang2) - end[1]) * k / 8 + Math.sin(k + p) * 12]);
    const prog = clamp((st - sp.cue(1) - p * 0.35) / 4.5);
    const seg = partial(pts, prog);
    line(c, seg, P.orange, 1.6, crA * (0.55 - 0.3 * smooth(sp.cue(3), sp.cue(3) + 1.5, st)), 6);
    const h = seg[seg.length - 1]; if (prog < 1) glow(c, h[0], h[1], 14, P.orange, crA);
  }
  callout(c, 1450, 780, 1560, 860, '宇宙射线', '带电，被磁场拨弄、偏转', P.orange, crA * smooth(sp.cue(1) + 2, sp.cue(1) + 3, st));
  // mystery
  const qa = win(st, sp.cue(2), sp.cue(3), 0.6);
  text(c, '？', sx, sy - 150, { size: 120, weight: 900, color: P.orange, alpha: qa * (0.7 + 0.3 * Math.sin(st * 4)), glow: 30, glowColor: P.orange });
  text(c, '1912 年发现 · 起源成谜', sx, sy - 250, { size: 30, weight: 600, color: '#ffd9bf', alpha: qa, spacing: 3 });

  // 3. neutrinos: dead straight
  const na = smooth(sp.cue(3), sp.cue(3) + 1, st);
  line(c, [[sx + 40, sy], [ex - 50, ey]], P.cyan, 2, na * 0.5, 12);
  additive(c, () => { for (let i = 0; i < 9; i++) { const u = (st * 0.35 + i / 9) % 1; const x = lerp(sx + 40, ex - 50, u); glow(c, x, sy, 26, P.cyan, na); dot(c, x, sy, 3, '#ffffff', na); } });
  callout(c, 1300, 540, 1360, 420, '中微子', '不带电 · 直线抵达', P.cyan, na * smooth(sp.cue(3) + 1.5, sp.cue(3) + 2.5, st));

  // 4. the accelerator
  const ka = smooth(sp.cue(4), sp.cue(4) + 1, st);
  if (ka > 0) {
    c.save(); c.strokeStyle = rgba(P.gold, 0.8 * ka); c.lineWidth = 2; c.beginPath(); c.arc(sx, sy, 110 + 6 * Math.sin(st * 3), 0, TAU); c.stroke(); c.restore();
    text(c, '宇宙加速器', sx, sy - 170, { size: 40, weight: 800, color: P.gold, alpha: ka, spacing: 8, glow: 18, glowColor: P.gold });
    const chain = ['质子', '高速碰撞', '中微子'];
    chain.forEach((s, i) => { const a = smooth(sp.cue(4) + 0.8 + i * 0.8, sp.cue(4) + 1.5 + i * 0.8, st); badge(c, s, 150 + i * 170, 820, i === 2 ? P.cyan : P.gold, a, { size: 26 }); if (i < 2) text(c, '→', 235 + i * 170, 820, { size: 30, color: '#fff', alpha: a }); });
  }
};

S.antarctica = (c, st, sp) => {
  const down = ease.inOut(clamp((st - sp.cue(2) + 0.6) / 3.2));
  const dy = down * 470;
  const { hz, scale, bed } = polar(c, st, dy);
  // depth ruler
  const ra = smooth(sp.cue(2), sp.cue(2) + 1.5, st);
  [[0, '冰面'], [500, '500 米'], [1000, '1000 米'], [1450, '1450 米'], [2000, '2000 米'], [2450, '2450 米'], [2800, '基岩']].forEach(([m, s]) => {
    const y = hz + m * scale; line(c, [[60, y], [96, y]], '#ffffff', 1.5, ra * 0.7);
    text(c, s, 108, y, { size: 22, align: 'left', color: '#e6f3ff', alpha: ra * 0.85 });
  });
  if (st < sp.cue(2) + 1) {
    text(c, '南极点', 960, hz - 120, { size: 34, weight: 700, color: '#eaf6ff', spacing: 8, alpha: win(st, 0.8, sp.cue(2) + 0.8), glow: 12, glowColor: '#7fd6ff' });
    text(c, '冰层厚约 2800 米', 960, hz + 60, { size: 26, color: '#123a5c', alpha: win(st, sp.cue(1), sp.cue(2) + 0.6), spacing: 3 });
  }
  // clear deep ice: a beam that travels far
  const ba = win(st, sp.cue(2) + 2.2, sp.cue(4) + 0.5, 0.8);
  if (ba > 0) {
    const y = hz + 2050 * scale, u = clamp((st - sp.cue(2) - 2.2) / 2.5);
    additive(c, () => { line(c, [[260, y], [lerp(260, 1660, ease.out(u)), y]], '#bff3ff', 3, ba, 18); glow(c, lerp(260, 1660, ease.out(u)), y, 30, '#ffffff', ba); });
    text(c, '深层冰极其清澈：光可穿行上百米', 960, y - 46, { size: 30, weight: 600, color: '#e8f8ff', alpha: ba, spacing: 3, glow: 12, glowColor: '#000' });
  }
  // the idea: a volume
  const ia = smooth(sp.cue(3), sp.cue(3) + 1, st);
  const y0 = hz + 1450 * scale, y1 = hz + 2450 * scale;
  if (ia > 0) { c.save(); c.setLineDash([10, 8]); c.strokeStyle = rgba(P.gold, 0.8 * ia * (1 - 0.5 * smooth(sp.cue(4), sp.cue(4) + 2, st))); c.lineWidth = 2; c.strokeRect(560, y0, 1000, y1 - y0); c.restore(); }
  // strings drilled one by one
  const n = 11;
  for (let i = 0; i < n; i++) {
    const x = 560 + i * 100;
    const tt = st - sp.cue(4) - i * 0.55;
    const pr = ease.inOut(clamp(tt / 1.6));
    if (pr <= 0) continue;
    const yb = lerp(hz, y1, pr);
    line(c, [[x, hz], [x, yb]], '#cfefff', 1.2, 0.7);
    if (pr < 1) { glow(c, x, yb, 26, '#ffb36b', 0.9); dot(c, x, yb, 3, '#fff', 1); }
    for (let d = 0; d < 60; d++) { const y = y0 + d * (y1 - y0) / 59; if (y > yb) break; glow(c, x, y, 7, '#9fe9ff', 0.55); dot(c, x, y, 1.6, '#e8fbff', 0.95); }
  }
  const ca = smooth(sp.cue(4) + 3, sp.cue(4) + 4, st);
  badge(c, '86 根缆绳', 1730, hz + 1500 * scale, P.gold, ca, { size: 28 });
  badge(c, '5160 个光学传感器', 1730, hz + 1700 * scale, P.cyan, smooth(sp.cue(4) + 3.6, sp.cue(4) + 4.6, st), { size: 28 });
  badge(c, '深 1450–2450 米', 1730, hz + 1900 * scale, '#ffffff', smooth(sp.cue(4) + 4.2, sp.cue(4) + 5.2, st), { size: 28 });
};

S.grid = (c, st, sp) => {
  iceBg(c, st);
  const cam = detCam(st, { yaw: 0.2, spin: 0.07, dist: lerp(3200, 2500, ease.out(clamp(st / 6))), cy: H / 2 + 40 });
  const cubeA = smooth(1, 2.5, st);
  drawDetector(c, cam, { cube: cubeA });
  // gentle shimmer of random DOMs
  additive(c, () => { for (let i = 0; i < 70; i++) { const d = doms[Math.floor(hash(i + Math.floor(st * 2)) * doms.length)]; const p = project(d.x, d.y, d.z, cam); glow(c, p[0], p[1], 14 * p[3] * 2, P.cyan, 0.5 * (0.5 + 0.5 * Math.sin(st * 3 + i))); } });
  text(c, '1 立方千米', 1580, 300, { size: 56, weight: 900, color: P.gold, alpha: cubeA, spacing: 6, glow: 18, glowColor: P.gold });
  text(c, '约 10 亿吨冰', 1580, 370, { size: 30, color: '#e5d7b8', alpha: cubeA * 0.9, spacing: 4 });
  const ya = smooth(sp.cue(1), sp.cue(1) + 1, st);
  text(c, '2011', 300, 420, { size: 120, weight: 900, color: '#ffffff', alpha: ya, glow: 26, glowColor: P.cyan });
  text(c, '全面建成 · 日夜守望', 300, 520, { size: 32, weight: 600, color: '#d8f1ff', alpha: ya, spacing: 6 });
};

S.cherenkov = (c, st0, sp) => {
  let st = st0 % 10.5;
  const g = c.createLinearGradient(0, 0, 0, H); g.addColorStop(0, '#04172c'); g.addColorStop(1, '#020812');
  fill(c, g); iceBg(c, st, { c0: '#0b2f52', c1: '#04142a' });
  const nx = 520, ny = 600;
  const hitT = 2.4;
  // incoming neutrino
  const inA = 1 - smooth(hitT + 0.2, hitT + 1.2, st);
  c.save(); c.setLineDash([6, 10]); line(c, [[-50, ny + 160], [lerp(-50, nx, clamp(st / hitT)), lerp(ny + 160, ny, clamp(st / hitT))]], P.cyan, 2, inA * 0.8); c.restore();
  if (st < hitT) glow(c, lerp(-50, nx, st / hitT), lerp(ny + 160, ny, st / hitT), 22, P.cyan, 0.9);
  text(c, '中微子', 160, ny + 210, { size: 28, color: P.cyan, alpha: inA * smooth(0.5, 1.2, st) });
  // nucleus
  dot(c, nx, ny, 9, '#ffb36b', 1 - smooth(hitT, hitT + 0.3, st)); glow(c, nx, ny, 24, '#ffb36b', 0.6 * (1 - smooth(hitT, hitT + 0.3, st)));
  text(c, '原子核', nx, ny + 46, { size: 26, color: '#ffd2a8', alpha: smooth(0.8, 1.4, st) * (1 - smooth(hitT, hitT + 0.6, st)) });
  if (st > hitT) additive(c, () => { const k = st - hitT; glow(c, nx, ny, 200 * Math.sqrt(k) + 20, '#ffffff', Math.exp(-k * 3)); });
  // charged particle with Cherenkov cone
  if (st > hitT) {
    const v = 140, cw = v * 0.76; const tp = st - hitT;
    const px = nx + v * tp, py = ny - 0.18 * v * tp;
    const ang = Math.atan2(-0.18, 1);
    // wavefronts
    for (let k = 0; k < 60; k++) {
      const te = k * 0.22; if (te > tp) break;
      const ex = nx + v * te, ey = ny - 0.18 * v * te; const rr = cw * (tp - te);
      c.strokeStyle = `rgba(110,200,255,${0.22 * Math.exp(-(tp - te) * 0.12)})`; c.lineWidth = 1.2; c.beginPath(); c.arc(ex, ey, rr, 0, TAU); c.stroke();
    }
    // cone envelope
    const alphaC = Math.asin(0.76 / Math.hypot(1, 0.18));
    const Lc = Math.min(tp * v, 900);
    const e1 = [px - Math.cos(ang - alphaC) * Lc, py - Math.sin(ang - alphaC) * Lc], e2 = [px - Math.cos(ang + alphaC) * Lc, py - Math.sin(ang + alphaC) * Lc];
    additive(c, () => {
      const gg = c.createRadialGradient(px, py, 0, px, py, Lc); gg.addColorStop(0, 'rgba(90,170,255,0.5)'); gg.addColorStop(1, 'rgba(60,120,255,0)');
      c.fillStyle = gg; c.beginPath(); c.moveTo(px, py); c.lineTo(e1[0], e1[1]); c.lineTo(e2[0], e2[1]); c.closePath(); c.fill();
      line(c, [[px, py], e1], '#8fd8ff', 3, 0.9, 22); line(c, [[px, py], e2], '#8fd8ff', 3, 0.9, 22);
      glow(c, px, py, 40, '#ffffff', 1);
    });
    line(c, [[nx, ny], [px, py]], '#ffffff', 2, 0.8);
    text(c, '带电粒子', px + 30, py - 40, { size: 26, color: '#fff', align: 'left', alpha: smooth(hitT + 0.5, hitT + 1.2, st) * (1 - smooth(8.5, 9.5, st)) });
  }
  // fade between loops
  { const fa = Math.max(1 - smooth(0, 0.6, st), smooth(9.7, 10.5, st)); if (fa > 0 && st0 > 1) { c.fillStyle = `rgba(2,10,22,${fa})`; c.fillRect(0, 0, W, H); } }
  st = st0;
  // speed bars
  const ba = smooth(sp.cue(1), sp.cue(1) + 1, st);
  if (ba > 0) {
    const bx = 1180, by = 170;
    const w1 = 560 * ease.out(ba), w2 = 560 * 0.76 * ease.out(ba);
    text(c, '带电粒子速度', bx - 20, by, { size: 26, align: 'right', color: '#fff', alpha: ba });
    L.rrect(c, bx, by - 12, w1, 24, 12); c.fillStyle = rgba('#ffffff', 0.85 * ba); c.fill();
    text(c, '冰中光速（约 0.76 c）', bx - 20, by + 56, { size: 26, align: 'right', color: '#9fdcff', alpha: ba });
    L.rrect(c, bx, by + 44, w2, 24, 12); c.fillStyle = rgba('#58b8ff', 0.85 * ba); c.fill();
    text(c, '更快！', bx + w1 + 20, by, { size: 28, weight: 800, align: 'left', color: P.gold, alpha: smooth(sp.cue(1) + 1.2, sp.cue(1) + 2, st) });
  }
  const ka = smooth(sp.cue(2) + 1.5, sp.cue(2) + 2.5, st);
  text(c, '切伦科夫辐射', 1400, 820, { size: 64, weight: 900, color: '#bfe9ff', alpha: ka, spacing: 10, glow: 30, glowColor: P.blue });
  text(c, '光的“音爆”', 1400, 900, { size: 32, weight: 500, color: '#dbefff', alpha: ka, spacing: 6 });
};

S.event = (c, st, sp) => {
  iceBg(c, st);
  const cam = detCam(st, { yaw: 0.9, spin: 0.045, dist: 2050, pitch: 0.26 });
  drawDetector(c, cam, { a: 0.9 });
  if (!TRACK) {
    TRACK = { A: [-760, -420, 380], B: [700, 520, -420], v: 380 };
    Object.assign(TRACK, trackHits(TRACK.A, TRACK.B, TRACK.v, 140));
    CASC = { C: [80, -120, 60], v: 160 }; CASC.hits = cascadeHits(CASC.C, CASC.v, 230);
  }
  const t0 = 0.6, tA = 1 - smooth(sp.cue(2) - 0.6, sp.cue(2) + 0.2, st);
  const tt = st - t0;
  if (tA > 0 && tt > 0) {
    drawHits(c, cam, TRACK.hits, tt, { a: tA });
    const s = Math.min(tt * TRACK.v, TRACK.Ln + 300);
    const P0 = project(...TRACK.A, cam);
    const cur = [TRACK.A[0] + TRACK.u[0] * s, TRACK.A[1] + TRACK.u[1] * s, TRACK.A[2] + TRACK.u[2] * s];
    const P1 = project(...cur, cam);
    line(c, [[P0[0], P0[1]], [P1[0], P1[1]]], '#ffffff', 2, 0.7 * tA, 8);
    if (s < TRACK.Ln + 250) additive(c, () => { glow(c, P1[0], P1[1], 40, '#ffffff', tA); for (let k = 0; k < 12; k++) { const a = k / 12 * TAU; const back = 140; const rr = back * Math.tan(0.7); const bx = cur[0] - TRACK.u[0] * back, by = cur[1] - TRACK.u[1] * back, bz = cur[2] - TRACK.u[2] * back; const q = project(bx + rr * Math.cos(a) * 0.7, by + rr * Math.sin(a), bz + rr * Math.cos(a) * 0.7, cam); line(c, [[P1[0], P1[1]], [q[0], q[1]]], '#6fc8ff', 1.2, 0.5 * tA); } });
    // reconstructed direction
    const ra = smooth(sp.cue(1), sp.cue(1) + 1, st) * tA;
    if (ra > 0) {
      const e0 = project(TRACK.A[0] - TRACK.u[0] * 600, TRACK.A[1] - TRACK.u[1] * 600, TRACK.A[2] - TRACK.u[2] * 600, cam), e1 = project(TRACK.B[0] + TRACK.u[0] * 500, TRACK.B[1] + TRACK.u[1] * 500, TRACK.B[2] + TRACK.u[2] * 500, cam);
      c.save(); c.setLineDash([14, 10]); line(c, [[e0[0], e0[1]], [e1[0], e1[1]]], P.gold, 2, ra); c.restore();
      text(c, 'μ 子径迹', 1560, 250, { size: 50, weight: 800, color: '#ffffff', alpha: ra, spacing: 6, glow: 18, glowColor: P.cyan });
      text(c, '方向精度 ≈ 1°', 1560, 320, { size: 34, weight: 600, color: P.gold, alpha: ra, spacing: 4 });
    }
  }
  // cascade
  const tc = st - sp.cue(2) - 0.4;
  if (tc > 0) {
    drawHits(c, cam, CASC.hits, tc);
    const P0 = project(...CASC.C, cam);
    const rr = Math.min(tc * CASC.v, 300) * P0[3];
    additive(c, () => { glow(c, P0[0], P0[1], rr * 2.2, '#ffd27a', 0.5 * Math.exp(-tc * 0.6)); glow(c, P0[0], P0[1], 60, '#ffffff', Math.exp(-tc * 1.5)); });
    c.strokeStyle = `rgba(255,220,150,${0.6 * Math.exp(-tc * 0.5)})`; c.lineWidth = 2; c.beginPath(); c.arc(P0[0], P0[1], rr, 0, TAU); c.stroke();
    const ca = smooth(0.8, 1.8, tc);
    text(c, '球形“簇射”', 1560, 250, { size: 50, weight: 800, color: '#ffffff', alpha: ca, spacing: 6, glow: 18, glowColor: '#ffb36b' });
    text(c, '能量测得更准', 1560, 320, { size: 34, weight: 600, color: P.gold, alpha: ca, spacing: 4 });
  }
  // legend
  const la = smooth(1.5, 2.5, st);
  if (la > 0) {
    const lx = 120, ly = 860, lw = 300;
    for (let i = 0; i < lw; i += 3) { c.fillStyle = rainbow(i / lw); c.globalAlpha = la; c.fillRect(lx + i, ly, 3, 12); }
    c.globalAlpha = 1;
    text(c, '光到达：早', lx, ly - 24, { size: 22, align: 'left', color: '#dbe9f5', alpha: la });
    text(c, '晚', lx + lw, ly - 24, { size: 22, align: 'right', color: '#dbe9f5', alpha: la });
    text(c, '圆点越大 · 光越强', lx, ly + 44, { size: 22, align: 'left', color: '#dbe9f5', alpha: la });
  }
};

S.rain = (c, st, sp) => {
  fill(c, vgrad(c, [[0, '#0b0820'], [0.22, '#1b2a5a'], [0.38, '#0a1f38'], [0.4, '#cfe8f7'], [0.47, '#3a78a6'], [0.7, '#0b2c4f'], [1, '#04132a']]));
  drawStars(c, stars, st, { alpha: 0.4 });
  const iceY = 432;
  text(c, '大气层', 120, 250, { size: 26, align: 'left', color: '#b9c8ff', alpha: 0.8 });
  text(c, '冰层', 120, iceY + 60, { size: 26, align: 'left', color: '#e3f3ff', alpha: 0.9 });
  // detector box
  const dx0 = 740, dy0 = 640, dw = 440, dh = 330;
  c.strokeStyle = rgba(P.gold, 0.7); c.lineWidth = 2; c.setLineDash([8, 6]); c.strokeRect(dx0, dy0, dw, dh); c.setLineDash([]);
  for (let i = 0; i < 9; i++) for (let j = 0; j < 12; j++) dot(c, dx0 + 30 + i * 47.5, dy0 + 20 + j * 26, 1.8, '#d8f4ff', 0.6);
  text(c, '冰立方', dx0 + dw / 2, dy0 + dh + 36, { size: 26, color: P.gold, alpha: 0.9 });
  // air showers
  const r = rng(4);
  for (let s = 0; s < 6; s++) {
    const x = 200 + s * 300 + r() * 100, ph = r() * 3, T = 3;
    const k = ((st + ph) % T) / T;
    const y0 = 90;
    additive(c, () => {
      glow(c, x, y0, 30, '#ffb36b', 1 - k);
      for (let b = 0; b < 14; b++) { const a = (r() - 0.5) * 0.6; const l = 120 + r() * 140; const e = ease.out(clamp(k * 2.2)); line(c, [[x, y0], [x + Math.sin(a) * l * e, y0 + Math.cos(a) * l * e]], '#ffcf8a', 1, 0.5 * (1 - k)); }
    });
  }
  // the muon rain
  additive(c, () => streaks(c, st, 220, { angle: Math.PI / 2 + 0.05, speed: 900, len: 120, color: '#ffffff', seed: 41, spread: 2200, cx: W / 2, cy: 560, D: 1300, alpha: 0.75, w: 1.3, head: 6 }));
  const ca = smooth(sp.cue(0) + 3, sp.cue(0) + 4, st);
  badge(c, '大气 μ 子 · 每天数以亿计', 1530, 560, '#ffffff', ca, { size: 30 });
  // one special drop
  const qa = smooth(sp.cue(1), sp.cue(1) + 0.8, st);
  if (qa > 0) {
    const x = 960, y = 470 + ((st * 140) % 120);
    additive(c, () => glow(c, x, y, 34, P.cyan, qa));
    c.strokeStyle = rgba(P.gold, qa); c.lineWidth = 2.5; c.beginPath(); c.arc(x, y, 46 + 4 * Math.sin(st * 5), 0, TAU); c.stroke();
    text(c, '宇宙中微子？', x + 70, y - 10, { size: 34, weight: 700, align: 'left', color: P.cyan, alpha: qa, glow: 14, glowColor: P.cyan });
  }
};

S.earthfilter = (c, st, sp) => {
  space(c, st, { drift: 1, neb: 0.5 });
  const ex = W / 2, ey = 760, R = 470;
  earthGlobe(c, ex, ey, R, st * 0.5, { a: 0.85 });
  const top = ey - R;
  // detector at the (south) pole on top
  glow(c, ex, top + 6, 40, P.gold, 0.8); c.fillStyle = P.gold; c.fillRect(ex - 14, top - 8, 28, 28);
  text(c, '南极 · 冰立方', ex + 40, top - 26, { size: 28, weight: 700, align: 'left', color: P.gold, alpha: 1 });
  // muons from above: stopped and rejected
  for (let i = 0; i < 26; i++) {
    const x = ex - 300 + hash(i) * 600, ph = hash(i + 50);
    const u = (st * 0.8 + ph) % 1; const y = lerp(-40, top, u);
    line(c, [[x + (ex - x) * u * 0.9, y - 60], [x + (ex - x) * u * 0.9, y]], P.red, 1.6, 0.8 * (1 - u * 0.3));
  }
  const ra = smooth(1, 2, st);
  badge(c, '从上方来：大气 μ 子 → 舍弃', 520, 150, P.red, ra, { size: 28 });
  // neutrinos from below, straight through the Earth
  const na = smooth(sp.cue(0) + 2, sp.cue(0) + 3, st);
  for (let i = 0; i < 7; i++) {
    const ang = Math.PI / 2 + (i - 3) * 0.07;
    const x0 = ex + Math.cos(ang) * 1300, y0 = top + Math.sin(ang) * 1300;
    const u = (st * 0.35 + i / 7) % 1;
    const hx = lerp(x0, ex, u), hy = lerp(y0, top, u);
    line(c, [[x0, y0], [ex, top]], P.cyan, 1.2, na * 0.25);
    additive(c, () => { glow(c, hx, hy, 20, P.cyan, na); dot(c, hx, hy, 2.5, '#fff', na); });
  }
  badge(c, '自下而上、穿过地球：只有中微子 ✓', 1500, 850, P.cyan, na, { size: 28 });
  text(c, '地球 = 天然滤网', ex, ey - 40, { size: 56, weight: 900, color: '#e8f6ff', spacing: 12, alpha: smooth(sp.cue(0) + 4, sp.cue(0) + 5, st), glow: 24, glowColor: P.blue });
};

S.veto = (c, st, sp) => {
  iceBg(c, st);
  const cx = 960, cy = 520, S2 = 330, band = 70;
  // outer veto layer
  c.fillStyle = 'rgba(255,170,90,0.10)'; c.fillRect(cx - S2, cy - S2, S2 * 2, S2 * 2);
  c.fillStyle = 'rgba(8,24,44,0.9)'; c.fillRect(cx - S2 + band, cy - S2 + band, (S2 - band) * 2, (S2 - band) * 2);
  c.strokeStyle = rgba(P.orange, 0.8); c.lineWidth = 2; c.strokeRect(cx - S2, cy - S2, S2 * 2, S2 * 2);
  c.strokeStyle = rgba('#ffffff', 0.25); c.strokeRect(cx - S2 + band, cy - S2 + band, (S2 - band) * 2, (S2 - band) * 2);
  text(c, '外层“哨兵”', cx - S2 - 30, cy - S2 + 20, { size: 30, weight: 700, align: 'right', color: P.orange, alpha: smooth(0.3, 1.2, st) });
  const grid = [];
  for (let i = 0; i < 12; i++) for (let j = 0; j < 12; j++) grid.push([cx - S2 + 30 + i * (S2 * 2 - 60) / 11, cy - S2 + 30 + j * (S2 * 2 - 60) / 11]);
  grid.forEach(([x, y]) => dot(c, x, y, 2.2, '#cfeaff', 0.55));
  const outer = (x, y) => Math.abs(x - cx) > S2 - band || Math.abs(y - cy) > S2 - band;
  // A: muon entering from the edge
  const tA = st - 0.8, durA = 2.2;
  const pA = (u) => [lerp(cx - S2 - 120, cx + 120, u), lerp(cy - S2 - 200, cy + S2 + 80, u)];
  const aA = 1 - smooth(sp.cueEnd(0) * 0.55, sp.cueEnd(0) * 0.55 + 0.8, st);
  if (tA > 0 && aA > 0) {
    const u = clamp(tA / durA); const [hx, hy] = pA(u);
    line(c, [pA(0), [hx, hy]], '#ffffff', 2, aA * 0.8, 8);
    grid.forEach(([x, y], i) => { const dd = Math.abs((x - pA(0)[0]) * (pA(1)[1] - pA(0)[1]) - (y - pA(0)[1]) * (pA(1)[0] - pA(0)[0])) / Math.hypot(pA(1)[0] - pA(0)[0], pA(1)[1] - pA(0)[1]); if (dd < 50 && y < hy) additive(c, () => glow(c, x, y, 26, outer(x, y) ? P.red : '#ff9a7a', aA)); });
    badge(c, '从边缘闯入 → 舍弃', cx + S2 + 210, cy - 160, P.red, aA * smooth(1.8, 2.6, tA), { size: 28 });
  }
  // B: lights up deep inside
  const tB = st - sp.cueEnd(0) * 0.55 - 0.4;
  if (tB > 0) {
    grid.forEach(([x, y]) => { const d = Math.hypot(x - cx - 30, y - cy - 20); const th = d / 160; if (!outer(x, y) && d < 190 && tB > th) additive(c, () => glow(c, x, y, 30 * Math.exp(-d / 150) + 8, P.gold, 1)); });
    additive(c, () => glow(c, cx + 30, cy + 20, 120, '#ffffff', Math.exp(-tB * 1.2)));
    badge(c, '在深处凭空亮起 → 保留 ✓', cx + S2 + 210, cy + 120, P.gold, smooth(0.8, 1.6, tB), { size: 28 });
  }
};

S.spectrum = (c, st, sp) => {
  iceBg(c, st, { c0: '#0b2440', c1: '#050f1e' });
  const x0 = 360, x1 = 1560, y0 = 860, y1 = 210;
  const ex = e => lerp(x0, x1, (e - 13) / 3); // log10 eV from 13 to 16
  const yv = v => lerp(y0, y1, v);
  const a0 = smooth(0.2, 1, st);
  line(c, [[x0, y1 - 20], [x0, y0], [x1 + 20, y0]], '#cfe3f5', 2, a0);
  [[13, '10 TeV'], [14, '100 TeV'], [15, '1 PeV'], [16, '10 PeV']].forEach(([e, s]) => { line(c, [[ex(e), y0], [ex(e), y0 + 10]], '#cfe3f5', 2, a0); text(c, s, ex(e), y0 + 40, { size: 26, font: F.latin, weight: 600, color: '#dbe9f5', alpha: a0 }); });
  text(c, '中微子能量 →', (x0 + x1) / 2, y0 + 92, { size: 28, color: '#dbe9f5', alpha: a0, spacing: 4 });
  c.save(); c.translate(x0 - 60, (y0 + y1) / 2); c.rotate(-Math.PI / 2); text(c, '探测到的数量（对数）→', 0, 0, { size: 28, color: '#dbe9f5', alpha: a0, spacing: 4 }); c.restore();
  const atm = e => 0.95 - (e - 13) * 0.43;          // steep
  const ast = e => 0.62 - (e - 13) * 0.17;          // flatter
  const pa = clamp((st - 1) / 3), pb = clamp((st - sp.cue(0) - 3.5) / 3);
  c.save(); c.beginPath(); c.rect(x0 + 2, y1 - 40, x1 - x0 + 40, y0 - y1 + 38); c.clip();
  const A = [], B = [];
  for (let e = 13; e <= 16.001; e += 0.05) { A.push([ex(e), yv(atm(e))]); B.push([ex(e), yv(ast(e))]); }
  line(c, partial(A, pa), '#8fb3d9', 4, 0.95, 10);
  text(c, '大气中微子', ex(13.25), yv(atm(13.25)) - 34, { size: 30, weight: 700, align: 'left', color: '#b8d2ef', alpha: smooth(2, 3, st) });
  if (pb > 0) {
    const cross = 13 + (0.95 - 0.62) / (0.43 - 0.17);
    // shaded region where the cosmos wins
    alpha(c, smooth(0.5, 1, pb) * 0.25, () => { c.fillStyle = P.gold; c.beginPath(); c.moveTo(ex(cross), yv(ast(cross))); for (let e = cross; e <= 16; e += 0.05) c.lineTo(ex(e), yv(ast(e))); for (let e = 16; e >= cross; e -= 0.05) c.lineTo(ex(e), yv(Math.max(0, atm(e)))); c.closePath(); c.fill(); });
    line(c, partial(B, pb), P.gold, 5, 1, 16);
    text(c, '来自宇宙的中微子', ex(15.1), yv(ast(15.1)) - 40, { size: 34, weight: 800, align: 'left', color: P.gold, alpha: smooth(0.6, 1, pb), glow: 14, glowColor: P.gold });
  }
  c.restore();
  text(c, '示意图', x1, y1 - 10, { size: 22, align: 'right', color: '#9fb4c8', alpha: a0 * 0.8 });
};

S.energy = (c, st, sp) => {
  space(c, st, { drift: 2, neb: 0.6 });
  const x0 = 200, x1 = 1720, y = 600;
  const ex = e => lerp(x0, x1, e / 16);
  const a0 = smooth(0.2, 1, st);
  line(c, [[x0, y], [x1, y]], '#dfe9f5', 2, a0);
  for (let e = 0; e <= 16; e += 2) { line(c, [[ex(e), y - 8], [ex(e), y + 8]], '#dfe9f5', 2, a0); text(c, `10${sup(e)}`, ex(e), y + 44, { size: 26, font: F.greek, color: '#cbd8e8', alpha: a0 }); }
  text(c, '能量（电子伏特）', (x0 + x1) / 2, y + 100, { size: 26, color: '#cbd8e8', alpha: a0, spacing: 4 });
  const marks = [[0.3, '可见光光子', '约 2 电子伏', '#ffd27a', -1], [6, '太阳中微子', '约百万电子伏', '#ffb36b', 1], [12.83, '大型强子对撞机', '每个质子 6.8 万亿电子伏', '#c8a8ff', -1], [15, '冰立方中微子', '约一千万亿电子伏', P.cyan, 1]];
  const yb = y + 62;
  marks.forEach(([e, s, s2, col, side], i) => {
    const a = smooth(0.8 + i * 0.9, 1.6 + i * 0.9, st);
    const yy = y + side * (i === 3 ? 200 : 150);
    line(c, [[ex(e), y], [ex(e), yy - side * 40]], col, 1.5, a * 0.7);
    glow(c, ex(e), y, i === 3 ? 40 : 20, col, a);
    text(c, s, ex(e), yy - side * 2, { size: i === 3 ? 38 : 30, weight: 700, color: col, alpha: a, glow: 10, glowColor: col });
    text(c, s2, ex(e), yy + 40 * (side > 0 ? 1 : -0) + (side < 0 ? -42 : 0), { size: 24, color: '#e7eef7', alpha: a * 0.9 });
  });
  const ba = smooth(sp.cue(1), sp.cue(1) + 1, st);
  if (ba > 0) {
    line(c, [[ex(12.83), yb - 14], [ex(12.83), yb + 6], [ex(15) - 14, yb + 6], [ex(15) - 14, yb - 14]], P.gold, 2, ba);
    text(c, '高出上百倍', (ex(12.83) + ex(15)) / 2 - 20, yb + 44, { size: 34, weight: 800, color: P.gold, alpha: ba, glow: 14, glowColor: P.gold });
  }
  // window opening
  const wa = clamp((st - sp.cue(2) - 1.5) / 2.5);
  if (wa > 0) {
    const R = 1200 * ease.inOut(wa);
    c.save(); c.beginPath(); c.arc(W / 2, H / 2, R, 0, TAU); c.clip();
    space(c, st + 100, { drift: 8, warm: true, neb: 1 });
    streaks(c, st, 50, { angle: 0.6, speed: 1300, len: 300, color: P.cyan, seed: 70 });
    text(c, '来自太阳系之外', W / 2, H / 2 - 30, { size: 92, weight: 900, color: '#ffffff', spacing: 18, alpha: smooth(0.5, 0.9, wa), glow: 30, glowColor: P.cyan });
    text(c, '一扇新的窗口', W / 2, H / 2 + 70, { size: 40, weight: 500, color: '#d6f3ff', spacing: 12, alpha: smooth(0.7, 1, wa) });
    c.restore();
    c.strokeStyle = rgba(P.cyan, 0.8 * (1 - wa)); c.lineWidth = 3; c.beginPath(); c.arc(W / 2, H / 2, R, 0, TAU); c.stroke();
  }
};
const sup = n => String(n).split('').map(d => '⁰¹²³⁴⁵⁶⁷⁸⁹'[+d]).join('');

S.skymap = (c, st, sp) => {
  space(c, st, { drift: 0.6, neb: 0.35 });
  const cx = 960, cy = 520, k = 265;
  const ell = (fn) => { c.beginPath(); c.ellipse(cx, cy, k * 2 * Math.SQRT2, k * Math.SQRT2, 0, 0, TAU); fn(); };
  ell(() => { c.fillStyle = 'rgba(4,14,30,0.78)'; c.fill(); c.strokeStyle = 'rgba(160,210,255,0.6)'; c.lineWidth = 2; c.stroke(); });
  c.save(); ell(() => c.clip());
  // grid
  for (let ra = 0; ra < 360; ra += 30) { const pts = []; for (let d = -90; d <= 90; d += 3) pts.push(moll(ra, d, cx, cy, k)); line(c, pts, '#7fb2e0', 1, 0.15); }
  for (let d = -60; d <= 60; d += 30) { const pts = []; for (let ra = 0; ra <= 360; ra += 3) pts.push(moll(ra + 0.001, d, cx, cy, k)); line(c, pts, '#7fb2e0', 1, 0.15); }
  // milky way band
  const mw = smooth(sp.cue(4), sp.cue(4) + 2, st);
  additive(c, () => {
    for (const g of galPlane) {
      const [x, y] = moll(g.ra, g.dec, cx, cy, k);
      const core = Math.exp(-Math.pow(((g.l + 180) % 360 - 180) / 60, 2));
      glow(c, x, y, 30 + 26 * core, '#9fb7ff', 0.07 * (1 - mw) + 0.015);
      glow(c, x, y, 34 + 40 * core, P.cyan, mw * (0.09 + 0.2 * core) * (0.8 + 0.2 * Math.sin(st * 2 + g.l)));
    }
  });
  // background events
  for (const e of bgEvents) { const [x, y] = moll(e.ra, e.dec, cx, cy, k); dot(c, x, y, 1.6, '#cfe8ff', e.a * (0.5 + 0.5 * Math.sin(st * 1.5 + e.ph))); }
  c.restore();
  text(c, '冰立方眼中的中微子天空', cx, 95, { size: 34, weight: 700, color: '#e3f2ff', spacing: 8, alpha: smooth(0.2, 1, st) * (1 - mw) });
  // TXS 0506+056
  const [tx, ty] = moll(77.36, 5.69, cx, cy, k);
  const a1 = smooth(sp.cue(0) + 0.5, sp.cue(0) + 1.5, st);
  if (a1 > 0) {
    const u = clamp((st - sp.cue(0) - 0.3) / 1.4);
    if (u < 1) additive(c, () => { const hx = lerp(tx + 600, tx, ease.in(u)), hy = lerp(ty + 520, ty, ease.in(u)); line(c, [[lerp(tx + 600, tx, Math.max(0, ease.in(u) - 0.2)), lerp(ty + 520, ty, Math.max(0, ease.in(u) - 0.2))], [hx, hy]], P.cyan, 3, 1, 14); glow(c, hx, hy, 30, '#fff', 1); });
    additive(c, () => { glow(c, tx, ty, 50, P.cyan, a1); const pr = (st * 0.7) % 1; c.strokeStyle = rgba(P.cyan, (1 - pr) * a1); c.lineWidth = 2; c.beginPath(); c.arc(tx, ty, 20 + pr * 70, 0, TAU); c.stroke(); });
    callout(c, tx, ty, tx + 220, ty - 230, '2017 · 猎户座方向', '一颗高能中微子', P.cyan, a1 * (1 - smooth(sp.cue(2) - 0.5, sp.cue(2), st) * 0.6));
  }
  const b1 = win(st, sp.cue(1) + 0.5, sp.cue(2) - 0.2, 0.7);
  if (b1 > 0) inset(c, 1500, 820, b1, 'blazar', st, '耀变体 TXS 0506+056', '喷流正对地球 · 约 40 亿光年');
  // NGC 1068
  const [nx, ny] = moll(40.67, -0.01, cx, cy, k);
  const a2 = smooth(sp.cue(2) + 0.6, sp.cue(2) + 1.6, st);
  if (a2 > 0) {
    additive(c, () => { for (let i = 0; i < 4; i++) glow(c, nx + Math.sin(i * 2) * 8, ny + Math.cos(i * 3) * 6, 90 - i * 18, i < 2 ? '#ff9a4a' : '#fff1b0', a2 * 0.5); });
    callout(c, nx, ny, nx + 160, ny + 250, 'NGC 1068 · 鲸鱼座', '中微子“热点” · 约 4700 万光年', '#ffb36b', a2 * (1 - smooth(sp.cue(4) - 0.5, sp.cue(4), st) * 0.6));
  }
  const b2 = win(st, sp.cue(3) + 0.3, sp.cue(4) - 0.2, 0.7);
  if (b2 > 0) inset(c, 420, 820, b2, 'dusty', st, '尘埃包裹的星系核心', '光被困住 · 中微子逃逸');
  if (mw > 0) text(c, '2023 · 第一幅银河系的“中微子图像”', cx, 95, { size: 38, weight: 800, color: '#dff8ff', spacing: 4, alpha: mw, glow: 18, glowColor: P.cyan });
};
function inset(c, x, y, a, kind, st, t1, t2) {
  const w = 470, h = 250;
  alpha(c, a, () => { L.rrect(c, x - w / 2, y - h / 2, w, h, 18); c.fillStyle = 'rgba(2,8,18,0.88)'; c.fill(); c.strokeStyle = 'rgba(160,210,255,0.6)'; c.lineWidth = 1.5; c.stroke(); });
  c.save(); L.rrect(c, x - w / 2, y - h / 2, w, h, 18); c.clip();
  const ox = x - 130, oy = y - 5;
  if (kind === 'blazar') {
    additive(c, () => { glow(c, ox, oy, 120, '#ff9a4a', 0.4 * a); for (let i = 0; i < 24; i++) { const ang = i / 24 * TAU; const l = 60 + 30 * Math.sin(st * 4 + i * 1.7); line(c, [[ox, oy], [ox + Math.cos(ang) * l, oy + Math.sin(ang) * l]], '#bfe8ff', 2, 0.35 * a); } glow(c, ox, oy, 46, '#ffffff', a); });
  } else {
    c.save(); c.translate(ox, oy); c.scale(1, 0.55);
    for (let i = 0; i < 380; i++) { const arm = i % 2, r = 8 + hash(i) * 95, ang = r * 0.055 + arm * Math.PI + st * 0.15 + (hash(i + 5) - 0.5) * 0.5; dot(c, Math.cos(ang) * r, Math.sin(ang) * r, 1.6, i % 4 ? '#bcd0ff' : '#ffe2b0', 0.65 * a); }
    c.restore();
    additive(c, () => glow(c, ox, oy, 36, '#ffdca0', a));
    dot(c, ox, oy, 22, '#2a1a10', 0.85 * a);
    for (let i = 0; i < 8; i++) { const ang = i / 8 * TAU + 0.2, u = (st * 0.8 + i / 8) % 1; const r1 = 22 + u * 110; if (i % 2) { additive(c, () => glow(c, ox + Math.cos(ang) * r1, oy + Math.sin(ang) * r1 * 0.8, 10, P.cyan, a * (1 - u))); } else { const r2 = 22 + Math.min(u, 0.12) * 110; glow(c, ox + Math.cos(ang) * r2, oy + Math.sin(ang) * r2 * 0.8, 8, '#ffd27a', a * (u < 0.12 ? 1 : 0)); } }
  }
  c.restore();
  text(c, t1, x + 95, y - 22, { size: 24, weight: 700, color: '#fff', alpha: a });
  text(c, t2, x + 95, y + 20, { size: 19, color: '#cfe0f0', alpha: a });
}

S.finale = (c, st, sp) => {
  const dy = 300 + 20 * Math.sin(st * 0.08);
  const { hz, scale } = polar(c, st, dy, { aurora: 1.4, scale: 0.25 });
  // the glowing detector volume in the ice
  const y0 = hz + 1450 * scale, y1 = hz + 2450 * scale;
  additive(c, () => glow(c, 960, (y0 + y1) / 2, 520, '#3aa8ff', 0.35));
  for (let i = 0; i < 15; i++) { const x = 400 + i * 80; line(c, [[x, hz], [x, y1]], '#cfefff', 1, 0.35); for (let d = 0; d < 30; d++) { const y = y0 + d * (y1 - y0) / 29; const tw = 0.5 + 0.5 * Math.sin(st * 2 + i * 1.3 + d * 0.7); glow(c, x, y, 9, P.cyan, 0.35 + 0.4 * tw); } }
  // a messenger arriving from the stars
  const per = 6, k = (st % per) / per;
  const sx = 1500, sy = -40, tx = 900, ty = (y0 + y1) / 2;
  additive(c, () => { const u = ease.in(clamp(k * 1.4)); line(c, [[sx, sy], [lerp(sx, tx, u), lerp(sy, ty, u)]], P.cyan, 2, 0.6 * (1 - k), 14); if (k > 0.7) glow(c, tx, ty, 260 * (k - 0.7) / 0.3 + 30, '#ffffff', (1 - k) * 2.5); });
};

export default { palette: P, init, scenes: S };
