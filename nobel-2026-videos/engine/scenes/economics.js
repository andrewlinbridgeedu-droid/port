// 2026 经济学奖 · 以微知著 —— 宏观经济稳定的微观基础
import * as L from '../lib.js';
import { drawTitle } from '../core.js';
const { W, H, TAU, clamp, lerp, smooth, ease, prog, glow, dot, line, text, reveal, F, rgba, fill, vgrad,
  additive, alpha, callout, badge, partial, rng, noise2, fbm, drawStars, makeStars, makeNebula, win, hash, mixHex } = L;

const P = { gold: '#e8c477', jade: '#4fd1b5', red: '#ff6b5b', blue: '#5aa9ff', violet: '#a98bff', paper: '#efe6d2', white: '#f4f1ea' };
let motes, neb, crowd = [], globePts = [], walks = [];

function init() {
  motes = makeStars(500, 71);
  neb = makeNebula(['#0f2a4a', '#2a2240'], 12, 480, 270, 2.0, 0.7);
  const r = rng(8);
  for (let i = 0; i < 160; i++) crowd.push({ x: 140 + r() * 640, y: 260 + r() * 520, a0: r() * TAU, sp: 0.5 + r(), ph: r() * TAU });
  const N = 1300;
  for (let i = 0; i < N; i++) { const y = 1 - (i / (N - 1)) * 2, rad = Math.sqrt(1 - y * y), th = i * 2.399963; const x = Math.cos(th) * rad, z = Math.sin(th) * rad; const lat = Math.asin(y), lon = Math.atan2(z, x); globePts.push({ x, y, z, land: fbm(Math.cos(lat) * Math.cos(lon) * 1.6 + 3, Math.sin(lat) * 1.6 + Math.cos(lat) * Math.sin(lon) * 1.3, 4) > 0.08 }); }
  const rw = rng(4);
  for (let k = 0; k < 26; k++) { const p = [0]; for (let j = 1; j <= 40; j++) p.push(p[j - 1] + (rw() - 0.5) * 2); walks.push(p); }
}

// ---------------------------------------------------------------- painters
function bg(c, st, o = {}) {
  fill(c, vgrad(c, [[0, '#04080f'], [0.6, '#081322'], [1, '#0c1a2c']]));
  alpha(c, o.neb ?? 0.6, () => c.drawImage(neb, -40 + Math.sin(st * 0.04) * 20, -20, W + 80, H + 40));
  // faint ledger grid
  if (o.grid !== false) { c.strokeStyle = 'rgba(160,190,230,0.045)'; c.lineWidth = 1; for (let x = 0; x < W; x += 60) { c.beginPath(); c.moveTo(x, 0); c.lineTo(x, H); c.stroke(); } for (let y = 0; y < H; y += 60) { c.beginPath(); c.moveTo(0, y); c.lineTo(W, y); c.stroke(); } }
  drawStars(c, motes, st, { dx: -st * 4, alpha: 0.35 });
}
function tide(c, st, y0, amp, a = 1, o = {}) {
  for (let k = 0; k < (o.n ?? 9); k++) {
    const pts = []; const y = y0 + k * (o.gap ?? 22);
    for (let x = -20; x <= W + 20; x += 16) pts.push([x, y + Math.sin(x * 0.006 + st * (0.5 + k * 0.05) + k * 0.8) * amp * (1 - k * 0.06) + Math.sin(x * 0.017 - st * 0.7 + k) * amp * 0.25]);
    line(c, pts, o.color ?? P.gold, 1.4, a * (0.55 - k * 0.04), k === 0 ? 8 : 0);
  }
}
function house(c, x, y, s, col, a = 1) {
  alpha(c, a, () => { c.save(); c.translate(x, y); c.scale(s, s); c.strokeStyle = col; c.lineWidth = 2 / s * 1.2; c.beginPath(); c.moveTo(-14, -2); c.lineTo(0, -16); c.lineTo(14, -2); c.moveTo(-10, -5); c.lineTo(-10, 12); c.lineTo(10, 12); c.lineTo(10, -5); c.stroke(); c.fillStyle = rgba(col, 0.25); c.fillRect(-3, 3, 6, 9); c.restore(); });
}
function shop(c, x, y, s, col, a = 1) {
  alpha(c, a, () => { c.save(); c.translate(x, y); c.scale(s, s); c.strokeStyle = col; c.lineWidth = 2 / s * 1.2; c.strokeRect(-12, -2, 24, 14); c.beginPath(); c.moveTo(-15, -2); c.lineTo(-12, -12); c.lineTo(12, -12); c.lineTo(15, -2); c.closePath(); c.stroke(); c.fillStyle = rgba(col, 0.3); for (let k = -1; k <= 1; k++) c.fillRect(k * 8 - 3, -11, 5, 8); c.restore(); });
}
function bookCard(c, x, y, title, sub, year, col, a = 1, o = {}) {
  if (a <= 0.003) return;
  const w = o.w ?? 300, h = o.h ?? 400, e = ease.out(clamp(a));
  c.save(); c.translate(x, y + (1 - e) * 30); c.globalAlpha *= a;
  c.shadowColor = 'rgba(0,0,0,0.6)'; c.shadowBlur = 40; c.shadowOffsetY = 16;
  const g = c.createLinearGradient(-w / 2, 0, w / 2, 0); g.addColorStop(0, mixHex(col, '#000000', 0.45)); g.addColorStop(0.08, col); g.addColorStop(1, mixHex(col, '#000000', 0.2));
  c.fillStyle = g; L.rrect(c, -w / 2, -h / 2, w, h, 8); c.fill();
  c.shadowBlur = 0; c.shadowOffsetY = 0;
  c.strokeStyle = 'rgba(255,240,210,0.5)'; c.lineWidth = 1.5; c.strokeRect(-w / 2 + 22, -h / 2 + 22, w - 44, h - 44);
  c.restore();
  const ty = y - h * 0.18;
  text(c, title, x, ty, { size: o.tsize ?? 44, font: F.kai, weight: 700, color: '#fff6e6', alpha: a, spacing: 4 });
  if (o.en) text(c, o.en, x, ty + (o.tsize ?? 44) * 0.6 + 22, { size: 24, font: F.latin, italic: true, weight: 500, color: '#f3e3c2', alpha: a * 0.9 });
  text(c, sub, x, y + h * 0.16, { size: o.ssize ?? 24, font: F.kai, color: '#f5e8d0', alpha: a * 0.95 });
  text(c, year, x, y + h * 0.33, { size: 26, font: F.latin, weight: 600, color: '#f3e3c2', alpha: a * 0.85, spacing: 4 });
}
function axes(c, x0, y0, x1, y1, a, xl, yl) {
  line(c, [[x0, y1 - 20], [x0, y0], [x1 + 20, y0]], '#d6e2f0', 2, a);
  L.arrowHead(c, x1 + 26, y0, 0, 14, '#d6e2f0', a); L.arrowHead(c, x0, y1 - 26, -Math.PI / 2, 14, '#d6e2f0', a);
  if (xl) text(c, xl, x1 + 20, y0 + 40, { size: 26, color: '#d6e2f0', alpha: a, align: 'right' });
  if (yl) text(c, yl, x0 + 16, y1 - 20, { size: 26, color: '#d6e2f0', alpha: a, align: 'left' });
}
function bolt(c, x, y, s, col, a = 1) {
  alpha(c, a, () => { c.save(); c.translate(x, y); c.scale(s, s); additive(c, () => glow(c, 0, 0, 40, col, 0.6)); c.fillStyle = col; c.beginPath(); c.moveTo(4, -22); c.lineTo(-10, 2); c.lineTo(0, 2); c.lineTo(-4, 22); c.lineTo(10, -4); c.lineTo(0, -4); c.closePath(); c.fill(); c.restore(); });
}
function dial(c, x, y, R, v, a = 1, o = {}) {
  // v in 0..1 maps to -135..135 degrees
  alpha(c, a, () => {
    c.save(); c.translate(x, y);
    c.strokeStyle = 'rgba(220,230,245,0.25)'; c.lineWidth = 10; c.beginPath(); c.arc(0, 0, R, Math.PI * 0.75, Math.PI * 2.25); c.stroke();
    c.strokeStyle = o.col ?? P.gold; c.lineWidth = 10; c.beginPath(); c.arc(0, 0, R, Math.PI * 0.75, Math.PI * 0.75 + v * Math.PI * 1.5); c.stroke();
    const ang = Math.PI * 0.75 + v * Math.PI * 1.5;
    c.strokeStyle = '#ffffff'; c.lineWidth = 4; c.beginPath(); c.moveTo(0, 0); c.lineTo(Math.cos(ang) * R * 0.8, Math.sin(ang) * R * 0.8); c.stroke();
    c.fillStyle = '#ffffff'; c.beginPath(); c.arc(0, 0, 8, 0, TAU); c.fill();
    c.restore();
  });
  if (o.label) text(c, o.label, x, y + R * 0.55, { size: 30, weight: 800, color: '#ffffff', alpha: a });
  if (o.title) text(c, o.title, x, y + R + 40, { size: 28, weight: 600, color: o.col ?? P.gold, alpha: a, spacing: 4 });
}
function bank(c, x, y, s, a = 1) {
  alpha(c, a, () => {
    c.save(); c.translate(x, y); c.scale(s, s); c.strokeStyle = P.gold; c.lineWidth = 3;
    c.beginPath(); c.moveTo(-110, -60); c.lineTo(0, -120); c.lineTo(110, -60); c.closePath(); c.stroke();
    c.strokeRect(-115, -60, 230, 16);
    for (let k = -2; k <= 2; k++) { c.beginPath(); c.moveTo(k * 44, -40); c.lineTo(k * 44, 60); c.stroke(); }
    c.strokeRect(-125, 62, 250, 18);
    c.restore();
  });
}

// ---------------------------------------------------------------- scenes
const S = {};
S.title = (c, st) => {
  bg(c, st);
  tide(c, st, 955, 20, smooth(0.5, 2.5, st), { n: 6 });
  for (let i = 0; i < 220; i++) { const x = (hash(i) * W + st * (10 + hash(i + 3) * 30)) % W, y = 930 + hash(i + 7) * 150 + Math.sin(st + i) * 8; dot(c, x, y, 1.6, i % 5 ? P.gold : P.jade, 0.5 * smooth(1, 3, st)); }
  drawTitle(c, st, { glow: P.gold });
};

S.cycle = (c, st, sp) => {
  bg(c, st);
  const x0 = 160, x1 = 1760, yc = 540;
  const draw = clamp((st - sp.cue(0) + 1) / 8);
  const wave = x => yc - 170 * Math.sin((x - x0) * 0.0085 - 0.6) - 30 * Math.sin((x - x0) * 0.021);
  const calm = smooth(sp.cue(1) + 3, sp.cue(1) + 7, st);
  const pts = []; for (let x = x0; x <= x1; x += 8) pts.push([x, wave(x)]);
  line(c, [[x0, yc], [x1, yc]], '#9fb2c8', 1, 0.3);
  // shaded troughs
  if (draw > 0) {
    c.save(); c.beginPath(); c.rect(x0, 0, (x1 - x0) * draw, H); c.clip();
    alpha(c, 0.18 * (1 - calm * 0.6), () => { c.fillStyle = P.blue; c.beginPath(); c.moveTo(x0, yc); pts.forEach(p => c.lineTo(p[0], Math.max(p[1], yc))); c.lineTo(x1, yc); c.closePath(); c.fill(); c.fillStyle = P.gold; c.beginPath(); c.moveTo(x0, yc); pts.forEach(p => c.lineTo(p[0], Math.min(p[1], yc))); c.lineTo(x1, yc); c.closePath(); c.fill(); });
    c.restore();
  }
  line(c, partial(pts, draw), P.gold, 4, 1 - 0.65 * calm, 14);
  [[x0 + 255, '繁荣', -1], [x0 + 625, '衰退', 1], [x0 + 995, '繁荣', -1], [x0 + 1365, '衰退', 1]].forEach(([x, s, side], i) => {
    const a = smooth(sp.cue(0) + 1.5 + i * 1.6, sp.cue(0) + 2.3 + i * 1.6, st) * (1 - calm * 0.7);
    text(c, s, x, wave(x) + side * 60, { size: 40, weight: 800, color: side < 0 ? P.gold : P.blue, alpha: a, spacing: 8, glow: 12, glowColor: side < 0 ? P.gold : P.blue });
  });
  // the tools
  const ta = smooth(sp.cue(1), sp.cue(1) + 1, st);
  badge(c, '财政政策 · 收支与税收', 560, 170, P.jade, ta, { size: 32 });
  badge(c, '货币政策 · 利率与货币', 1360, 170, P.violet, smooth(sp.cue(1) + 2, sp.cue(1) + 3, st), { size: 32 });
  if (calm > 0) {
    const sm = []; for (let x = x0; x <= x1; x += 8) sm.push([x, yc - (yc - wave(x)) * lerp(1, 0.32, calm)]);
    line(c, sm, P.jade, 4.5, calm, 16);
    text(c, '更平稳的轨迹', 1560, yc - 120, { size: 32, weight: 700, color: P.jade, alpha: calm });
  }
  // the map
  const ma = smooth(sp.cue(2), sp.cue(2) + 1.2, st);
  if (ma > 0) {
    c.strokeStyle = rgba(P.gold, 0.18 * ma); c.lineWidth = 1; for (let k = 0; k < 14; k++) { c.beginPath(); c.moveTo(x0, 260 + k * 40); c.lineTo(x1, 260 + k * 40); c.stroke(); }
    const cx = 1640, cy = 820, R = 60;
    alpha(c, ma, () => { c.strokeStyle = P.gold; c.lineWidth = 2; c.beginPath(); c.arc(cx, cy, R, 0, TAU); c.stroke(); c.save(); c.translate(cx, cy); c.rotate(Math.sin(st * 2) * 0.3); c.fillStyle = P.gold; c.beginPath(); c.moveTo(0, -R + 8); c.lineTo(10, 0); c.lineTo(0, R - 8); c.lineTo(-10, 0); c.closePath(); c.fill(); c.restore(); });
    text(c, '宏观经济模型 = 政策的地图', W / 2, 900, { size: 44, weight: 800, color: '#ffffff', alpha: ma, spacing: 6, glow: 18, glowColor: P.gold });
  }
};

const D60 = [[6.7, 1.1], [5.5, 1.2], [5.7, 1.2], [5.2, 1.3], [4.5, 1.6], [3.8, 2.9], [3.8, 3.1], [3.6, 4.2], [3.5, 5.5]];
const D70 = [[4.9, 5.7], [5.9, 4.4], [5.6, 3.2], [4.9, 6.2], [5.6, 11.0], [8.5, 9.1], [7.7, 5.8], [7.1, 6.5], [6.1, 7.6], [5.8, 11.3], [7.1, 13.5]];
S.phillips = (c, st, sp) => {
  bg(c, st);
  const x0 = 360, x1 = 1460, y0 = 860, y1 = 200;
  const gx = u => lerp(x0, x1, (u - 2) / 8), gy = p => lerp(y0, y1, p / 14);
  const a0 = smooth(sp.cue(0) - 0.5, sp.cue(0) + 0.5, st);
  const dis = smooth(sp.cue(3) + 1, sp.cue(3) + 4, st);
  alpha(c, 1 - dis * 0.8, () => {
    axes(c, x0, y0, x1, y1, a0, '失业率', '通胀率');
    for (let u = 2; u <= 8; u += 2) text(c, `${u}%`, gx(u), y0 + 30, { size: 22, color: '#b8c6d6', alpha: a0 });
    for (let p = 0; p <= 14; p += 4) text(c, `${p}%`, x0 - 16, gy(p), { size: 22, color: '#b8c6d6', alpha: a0, align: 'right' });
  });
  // 1960s: a tidy trade-off
  D60.forEach(([u, p], i) => { const a = smooth(sp.cue(0) + 1 + i * 0.35, sp.cue(0) + 1.4 + i * 0.35, st) * (1 - dis); additive(c, () => glow(c, gx(u), gy(p), 26, P.blue, a * 0.6)); dot(c, gx(u), gy(p), 7, P.blue, a); });
  const fit = []; for (let u = 3.42; u <= 7.2; u += 0.04) fit.push([gx(u), gy(0.9 + 1.38 / (u - 3.2))]);
  const crack = smooth(sp.cue(2) + 5, sp.cue(2) + 6, st);
  if (crack <= 0) line(c, partial(fit, clamp((st - sp.cue(0) - 4.5) / 2)), P.blue, 3, 0.9 * (1 - dis), 10);
  else { const half = Math.floor(fit.length * 0.45); line(c, fit.slice(0, half).map(([x, y]) => [x - crack * 20, y - crack * 14]), P.blue, 3, 0.6 * (1 - dis)); line(c, fit.slice(half + 3).map(([x, y]) => [x + crack * 24, y + crack * 18]), P.blue, 3, 0.6 * (1 - dis)); }
  text(c, '1960 年代：此消彼长', gx(6.6), gy(4.4), { size: 32, weight: 700, color: P.blue, alpha: smooth(sp.cue(0) + 5, sp.cue(0) + 6, st) * (1 - dis), align: 'left' });
  badge(c, '旧模型：只看宏观数字之间的统计关系', W / 2, 140, '#9fb2c8', smooth(sp.cue(1), sp.cue(1) + 1, st) * (1 - dis), { size: 28 });
  // 1970s: stagflation
  const oa = smooth(sp.cue(2), sp.cue(2) + 1, st) * (1 - dis);
  if (oa > 0) {
    // oil barrel
    alpha(c, oa, () => { c.save(); c.translate(1660, 330); c.fillStyle = '#1a1410'; c.strokeStyle = '#ff9a5a'; c.lineWidth = 3; L.rrect(c, -50, -70, 100, 140, 14); c.fill(); c.stroke(); for (const yy of [-30, 30]) { c.beginPath(); c.moveTo(-50, yy); c.lineTo(50, yy); c.stroke(); } c.restore(); });
    text(c, '石油危机', 1660, 450, { size: 30, weight: 800, color: '#ffb07a', alpha: oa });
    D70.forEach(([u, p], i) => {
      const k = ease.out(clamp((st - sp.cue(2) - 1 - i * 0.4) / 1.2)); if (k <= 0) return;
      const x = lerp(1660, gx(u), k), y = lerp(330, gy(p), k);
      additive(c, () => glow(c, x, y, 28, P.red, 0.7 * (1 - dis))); dot(c, x, y, 7.5, P.red, 1 - dis);
    });
    text(c, '滞胀', gx(8.4), gy(12.2), { size: 88, weight: 900, color: P.red, alpha: smooth(sp.cue(2) + 5, sp.cue(2) + 6, st) * (1 - dis), spacing: 20, glow: 26, glowColor: P.red });
    text(c, '1970 年代：通胀与失业一起攀升', gx(8.4), gy(10.3), { size: 26, color: '#ffc7bd', alpha: smooth(sp.cue(2) + 5.5, sp.cue(2) + 6.5, st) * (1 - dis) });
    text(c, '示意 · 据美国 1961–1980 年数据近似', x1, y0 + 70, { size: 20, color: '#8fa0b4', alpha: oa * 0.8, align: 'right' });
  }
  // behind every dot: people deciding
  if (dis > 0) {
    crowd.forEach((p, i) => { const x = lerp(gx(D70[i % D70.length][0]), 260 + (i % 20) * 72, ease.inOut(dis)), y = lerp(gy(D70[i % D70.length][1]), 300 + Math.floor(i / 20) * 70, ease.inOut(dis)); const col = i % 3 ? P.gold : P.jade; const bob = Math.sin(st * 2 + p.ph) * 3; dot(c, x, y - 12 + bob, 6, col, dis); alpha(c, dis, () => { c.fillStyle = col; c.beginPath(); c.ellipse(x, y + 8 + bob, 9, 12, 0, Math.PI, 0); c.fill(); }); if (Math.sin(st * 1.7 + p.ph * 3) > 0.9) text(c, '?', x + 14, y - 24, { size: 20, weight: 800, color: '#ffffff', alpha: dis }); });
    text(c, '政策一变 → 预期一变 → 规律一变', W / 2, 880, { size: 44, weight: 800, color: '#ffffff', alpha: smooth(sp.cue(3) + 4, sp.cue(3) + 5, st), spacing: 4, glow: 18, glowColor: P.gold });
  }
};

S.micro = (c, st, sp) => {
  bg(c, st);
  const cols = 16, rows = 6, gx0 = 260, gy0 = 230, dx = 93, dy = 82;
  const merge = smooth(sp.cue(0) + 5, sp.cue(0) + 8.5, st) * (1 - smooth(sp.cue(1) - 0.5, sp.cue(1) + 0.5, st));
  const fwd = smooth(sp.cue(2), sp.cue(2) + 1.5, st);
  const quote = smooth(sp.cue(1), sp.cue(1) + 1, st) * (1 - smooth(sp.cue(2) - 0.5, sp.cue(2), st));
  const verbs = ['买', '存', '借', '工作', '定价', '投资', '招人', '囤货'];
  for (let j = 0; j < rows; j++) for (let i = 0; i < cols; i++) {
    const k = j * cols + i; const isH = (i + j) % 3 !== 0;
    const x = gx0 + i * dx, y = gy0 + j * dy;
    const a = smooth(sp.cue(0) - 0.5 + (i + j) * 0.05, sp.cue(0) + 0.3 + (i + j) * 0.05, st) * (1 - quote * 0.75);
    (isH ? house : shop)(c, x, y, 1.6, isH ? P.gold : P.jade, a);
    // flickering decisions
    const fl = Math.sin(st * 1.3 + k * 2.1); if (fl > 0.93 && a > 0.5 && merge < 0.2) text(c, verbs[(k + Math.floor(st)) % verbs.length], x, y - 34, { size: 20, color: '#ffffff', alpha: (fl - 0.93) * 14 * a });
    if (merge > 0) { const tx = 160 + (k / (cols * rows)) * 1600, ty = 880 - Math.sin((k / (cols * rows)) * TAU * 1.5) * 50; line(c, [[x, y + 14], [lerp(x, tx, merge), lerp(y + 14, ty, merge)]], isH ? P.gold : P.jade, 1, 0.25 * merge * a); }
    if (fwd > 0) { const L2 = 40 * fwd; line(c, [[x + 18, y], [x + 18 + L2, y]], P.jade, 2, fwd * 0.9); L.arrowHead(c, x + 22 + L2, y, 0, 9, P.jade, fwd); }
  }
  if (merge > 0) {
    const pts = []; for (let x = 160; x <= 1760; x += 10) pts.push([x, 880 - Math.sin(((x - 160) / 1600) * TAU * 1.5) * 50]);
    line(c, pts, P.gold, 4, merge, 16);
    text(c, '宏观 = 千万个微观决定的总和', W / 2, 960 - 150, { size: 34, weight: 800, color: '#ffffff', alpha: merge, spacing: 4, glow: 14, glowColor: '#000' });
  }
  text(c, '家庭', 160, 150, { size: 30, weight: 700, color: P.gold, alpha: smooth(sp.cue(0), sp.cue(0) + 1, st) * (1 - quote) * (1 - fwd), align: 'left' });
  text(c, '企业', 260, 150, { size: 30, weight: 700, color: P.jade, alpha: smooth(sp.cue(0), sp.cue(0) + 1, st) * (1 - quote) * (1 - fwd), align: 'left' });
  if (quote > 0) {
    alpha(c, quote, () => { c.fillStyle = 'rgba(4,8,15,0.75)'; L.rrect(c, 300, 380, 1320, 300, 20); c.fill(); c.strokeStyle = rgba(P.gold, 0.6); c.lineWidth = 1.5; c.stroke(); });
    text(c, '“经济的结果，是千百万家庭和企业', W / 2, 470, { size: 52, font: F.kai, weight: 700, color: '#fff6e6', alpha: quote, spacing: 4 });
    text(c, '在微观层面所作决定的总和。”', W / 2, 550, { size: 52, font: F.kai, weight: 700, color: '#fff6e6', alpha: quote, spacing: 4 });
    text(c, '—— 瑞典皇家科学院', 1500, 630, { size: 28, color: P.gold, alpha: quote, align: 'right' });
  }
  if (fwd > 0) {
    line(c, [[260, 130], [1700, 130]], P.jade, 2, fwd, 10); L.arrowHead(c, 1716, 130, 0, 18, P.jade, fwd);
    text(c, '今天', 230, 130, { size: 30, weight: 700, color: '#ffffff', alpha: fwd, align: 'right' });
    text(c, '未来', 1740, 130, { size: 30, weight: 700, color: P.jade, alpha: fwd, align: 'left' });
    text(c, '每一个决定，都着眼未来', W / 2, 820, { size: 44, weight: 800, color: '#ffffff', alpha: smooth(sp.cue(2) + 1, sp.cue(2) + 2, st), spacing: 6, glow: 16, glowColor: P.jade });
  }
};

S.consumption = (c, st, sp) => {
  bg(c, st);
  const [c0, c1, c2, c3, c4] = [0, 1, 2, 3, 4].map(k => sp.cue(k));
  const x0 = 260, x1 = 1660, y0 = 820, y1 = 220;
  // 1) lifetime income vs smooth consumption
  const a1 = smooth(c0 - 0.5, c0 + 0.5, st) * (1 - smooth(c2 - 0.6, c2 + 0.4, st));
  if (a1 > 0) {
    const age = x => 22 + (x - x0) / (x1 - x0) * 60;
    const inc = x => { const g = age(x); const base = g < 65 ? 0.25 + 0.55 * Math.sin(Math.PI * (g - 22) / 50) : 0.18; return base + 0.06 * Math.sin(g * 0.9) + 0.035 * Math.sin(g * 1.9 + 1); };
    const con = x => 0.42 + 0.06 * (age(x) - 22) / 60;
    const gy = v => lerp(y0, y1, v);
    axes(c, x0, y0, x1, y1, a1, '年龄', '收入 / 消费');
    [25, 40, 55, 65, 80].forEach(g => text(c, `${g}`, x0 + (g - 22) / 60 * (x1 - x0), y0 + 30, { size: 22, color: '#b8c6d6', alpha: a1 }));
    const pi = [], pc = []; for (let x = x0; x <= x1; x += 6) { pi.push([x, gy(inc(x))]); pc.push([x, gy(con(x))]); }
    const di = clamp((st - c0 - 1) / 4);
    line(c, partial(pi, di), P.blue, 3, a1, 8);
    text(c, '收入', x0 + 40, gy(0.32) + 40, { size: 30, weight: 700, color: P.blue, alpha: a1 * smooth(c0 + 2, c0 + 3, st), align: 'left' });
    const dc = clamp((st - c1) / 3);
    if (dc > 0) {
      c.save(); c.beginPath(); c.rect(x0, 0, (x1 - x0) * dc, H); c.clip();
      alpha(c, 0.25 * a1, () => { for (let k = 0; k < pi.length - 1; k++) { const yi = pi[k][1], yc = pc[k][1]; c.fillStyle = yi < yc ? P.jade : P.red; c.fillRect(pi[k][0], Math.min(yi, yc), 6, Math.abs(yi - yc)); } });
      c.restore();
      line(c, partial(pc, dc), P.gold, 5, a1, 16);
      text(c, '消费：尽量平稳', x1 - 10, gy(0.5) - 34, { size: 32, weight: 800, color: P.gold, alpha: a1 * smooth(c1 + 2, c1 + 3, st), align: 'right' });
      text(c, '储蓄', 900, gy(0.6), { size: 30, weight: 700, color: P.jade, alpha: a1 * smooth(c1 + 3, c1 + 4, st) });
      text(c, '动用积蓄', 1560, gy(0.3), { size: 28, weight: 700, color: '#ffb0a6', alpha: a1 * smooth(c1 + 3.5, c1 + 4.5, st) });
    }
  }
  // 2) only news moves consumption
  const a2 = smooth(c2, c2 + 1, st) * (1 - smooth(c4 - 0.6, c4 + 0.4, st));
  if (a2 > 0) {
    text(c, '1978', 220, 170, { size: 70, weight: 900, color: '#ffffff', alpha: a2, glow: 18, glowColor: P.gold, align: 'left' });
    text(c, '霍尔：消费的“随机漫步”', 230, 240, { size: 30, weight: 700, color: P.gold, alpha: a2, align: 'left' });
    const tx0 = 260, tx1 = 1300, ty = 560;
    const events = [[0.18, 'news', 40], [0.34, 'known', 0], [0.5, 'news', -55], [0.66, 'known', 0], [0.82, 'news', 30]];
    const prog2 = clamp((st - c2 - 1) / 9);
    let y = ty; const pts = [[tx0, y]];
    events.forEach(([u, kind, d]) => { const x = lerp(tx0, tx1, u); pts.push([x, y]); if (kind === 'news') { y -= d; pts.push([x, y]); } });
    pts.push([tx1, y]);
    line(c, partial(pts, prog2), P.gold, 5, a2, 14);
    events.forEach(([u, kind], i) => {
      const x = lerp(tx0, tx1, u), a = a2 * smooth(u - 0.02, u + 0.05, prog2);
      if (kind === 'news') { bolt(c, x, 380, 1.4, P.red, a); text(c, '意外消息', x, 330, { size: 24, weight: 700, color: '#ffb0a6', alpha: a }); }
      else { alpha(c, a, () => { c.strokeStyle = P.jade; c.lineWidth = 2.5; c.strokeRect(x - 20, 362, 40, 36); c.beginPath(); c.moveTo(x - 20, 374); c.lineTo(x + 20, 374); c.stroke(); }); text(c, '意料之中', x, 330, { size: 24, weight: 700, color: P.jade, alpha: a }); text(c, '不变', x, 440, { size: 22, color: P.jade, alpha: a }); }
    });
    // fan of possible futures
    const fa = smooth(c3, c3 + 1.5, st);
    if (fa > 0) {
      const sx = tx1, sy = y;
      walks.forEach((w, k) => { const pts2 = w.map((v, j) => [sx + j * 12, sy + v * 14]); line(c, partial(pts2, clamp((st - c3) / 3)), k % 2 ? P.gold : '#9fb2c8', 1.5, fa * 0.45); });
      text(c, '明天往哪里走？', 1580, 260, { size: 40, weight: 800, color: '#ffffff', alpha: fa, glow: 14, glowColor: P.gold });
      text(c, '今天无从预测', 1580, 320, { size: 30, color: '#d6e2f0', alpha: fa });
    }
    text(c, '消费', tx0 - 20, ty, { size: 28, weight: 700, color: P.gold, alpha: a2, align: 'right' });
  }
  // 3) small handouts vs expectations
  const a3 = smooth(c4, c4 + 1, st);
  if (a3 > 0) {
    const bx = [640, 1280], hs = [70, 330];
    ['一时的小额补贴', '对未来的判断'].forEach((s, i) => {
      const h = hs[i] * ease.out(clamp((st - c4 - 0.6 - i * 0.8) / 1.2));
      const g = c.createLinearGradient(0, 760 - h, 0, 760); g.addColorStop(0, i ? P.gold : '#9fb2c8'); g.addColorStop(1, rgba(i ? P.gold : '#9fb2c8', 0.2));
      alpha(c, a3, () => { c.fillStyle = g; L.rrect(c, bx[i] - 90, 760 - h, 180, h, 10); c.fill(); });
      text(c, s, bx[i], 810, { size: 32, weight: 700, color: i ? P.gold : '#c8d4e2', alpha: a3 });
    });
    text(c, '对家庭支出的影响', W / 2, 260, { size: 38, weight: 800, color: '#ffffff', alpha: a3, spacing: 4 });
    text(c, '示意', 1500, 760, { size: 20, color: '#8fa0b4', alpha: a3 });
  }
};

S.pricing = (c, st, sp) => {
  bg(c, st);
  const [c0, c1, c2] = [0, 1, 2].map(k => sp.cue(k));
  // 1) staggered price tags
  const a1 = smooth(c0 - 0.5, c0 + 0.5, st) * (1 - smooth(c1 - 0.6, c1 + 0.4, st));
  if (a1 > 0) {
    for (let i = 0; i < 10; i++) {
      const x = 230 + i * 162, y = 470;
      const per = 3 + (i % 4) * 0.9, off = hash(i) * per;
      const n = Math.floor((st + off) / per); const ph = ((st + off) % per) / per;
      const flip = ph < 0.08 ? Math.cos(ph / 0.08 * Math.PI) : 1;
      const price = 10 + n + (i % 3);
      alpha(c, a1, () => {
        c.save(); c.translate(x, y); c.scale(1, Math.abs(flip));
        c.fillStyle = '#efe6d2'; c.beginPath(); c.moveTo(-56, -40); c.lineTo(40, -40); c.lineTo(62, 0); c.lineTo(40, 40); c.lineTo(-56, 40); c.closePath(); c.fill();
        c.fillStyle = '#0b1626'; c.beginPath(); c.arc(42, 0, 6, 0, TAU); c.fill();
        c.restore();
      });
      text(c, `¥${price}`, x - 8, y + 2, { size: 34, weight: 800, color: '#1a1410', alpha: a1 * Math.abs(flip) });
      if (ph < 0.12) additive(c, () => glow(c, x, y, 90, P.gold, a1 * (1 - ph / 0.12)));
    }
    text(c, '改价有成本：隔一阵子，才调一次', W / 2, 280, { size: 40, weight: 800, color: '#ffffff', alpha: a1 * smooth(c0 + 1, c0 + 2, st), spacing: 4 });
    text(c, '不同的商家，在不同的时刻调价', W / 2, 650, { size: 30, color: '#c8d4e2', alpha: a1 * smooth(c0 + 4, c0 + 5, st), spacing: 4 });
  }
  // 2) set the price with the future in mind
  const a2 = smooth(c1, c1 + 1, st) * (1 - smooth(c2 - 0.4, c2 + 0.6, st));
  if (a2 > 0) {
    const x0 = 300, x1 = 1600, y0 = 820, y1 = 240;
    axes(c, x0, y0, x1, y1, a2, '时间', '价格 / 成本');
    const cost = x => y0 - 80 - (x - x0) * 0.32;
    const resets = [x0, x0 + 430, x0 + 860, x0 + 1290];
    const priceAt = x => { let r = resets[0]; for (const q of resets) if (x >= q) r = q; return cost(r + 280); };
    const dp = clamp((st - c1 - 0.5) / 5);
    const pc = [], pp = []; for (let x = x0; x <= x1; x += 4) { pc.push([x, cost(x)]); pp.push([x, priceAt(x)]); }
    line(c, partial(pc, dp), P.red, 3, a2, 8);
    line(c, partial(pp, dp), P.gold, 5, a2, 14);
    text(c, '成本', x1 - 230, cost(x1 - 230) + 56, { size: 28, weight: 700, color: P.red, alpha: a2 });
    text(c, '价格：一次定一段', x0 + 200, priceAt(x0 + 200) - 52, { size: 30, weight: 800, color: P.gold, alpha: a2 * smooth(c1 + 2, c1 + 3, st) });
    const fa = smooth(c1 + 4, c1 + 5, st);
    c.save(); c.setLineDash([8, 8]); line(c, [[x0 + 430, cost(x0 + 430)], [x0 + 710, cost(x0 + 710)]], P.red, 2, a2 * fa); c.restore();
    callout(c, x0 + 440, priceAt(x0 + 440), x0 + 620, 300, '往前看', '把未来的成本也算进去', P.jade, a2 * fa);
  }
  // 3) the forward-looking Phillips curve
  const a3 = smooth(c2 + 0.4, c2 + 1.2, st);
  if (a3 > 0) {
    const y = 470;
    text(c, '今天的通胀', 520, y, { size: 52, weight: 900, color: '#ffffff', alpha: a3 });
    text(c, '≈', 770, y, { size: 60, color: '#ffffff', alpha: a3 });
    text(c, '对明天通胀的预期', 1080, y, { size: 52, weight: 900, color: P.gold, alpha: smooth(c2 + 1.5, c2 + 2.5, st), glow: 18, glowColor: P.gold });
    text(c, '+  成本的压力', 1490, y, { size: 44, weight: 700, color: '#ffb0a6', alpha: smooth(c2 + 3, c2 + 4, st), align: 'left' });
    text(c, 'πₜ = β·Eₜ[πₜ₊₁] + κ·xₜ', W / 2, 610, { size: 48, font: F.greek, italic: true, color: '#c8d4e2', alpha: smooth(c2 + 4.5, c2 + 5.5, st) });
    text(c, '新凯恩斯菲利普斯曲线（简化示意）', W / 2, 690, { size: 26, color: '#8fa0b4', alpha: smooth(c2 + 4.5, c2 + 5.5, st), spacing: 2 });
    // arrow from tomorrow back to today
    const ka = smooth(c2 + 2.5, c2 + 3.5, st);
    c.save(); c.globalAlpha *= ka; c.strokeStyle = P.gold; c.lineWidth = 3; c.beginPath(); c.moveTo(1080, y - 60); c.quadraticCurveTo(800, y - 180, 540, y - 60); c.stroke(); c.restore();
    L.arrowHead(c, 540, y - 58, Math.PI * 0.62, 18, P.gold, ka);
  }
};

S.centralbank = (c, st, sp) => {
  bg(c, st);
  const [c0, c1, c2, c3] = [0, 1, 2, 3].map(k => sp.cue(k));
  // 1) today's rate vs the expected path
  const a1 = smooth(c0 - 0.5, c0 + 0.5, st) * (1 - smooth(c1 - 0.6, c1 + 0.4, st));
  if (a1 > 0) {
    dial(c, 420, 520, 150, 0.55 + 0.03 * Math.sin(st), a1, { label: '今天', title: '利率的一次调整', col: P.violet });
    const x0 = 800, x1 = 1700, y0 = 760;
    axes(c, x0, y0, x1, 280, a1, '未来', '利率');
    const path = []; for (let k = 0; k <= 12; k++) path.push([x0 + 40 + k * 70, y0 - 160 - 140 * (1 - Math.exp(-k / 4))]);
    dot(c, path[0][0], path[0][1], 10, P.violet, a1);
    const fp = smooth(c0 + 3, c0 + 6, st);
    c.save(); c.setLineDash([10, 10]); line(c, partial(path, fp), P.gold, 4, a1, 14); c.restore();
    path.slice(1).forEach(([x, y], k) => dot(c, x, y, 6, P.gold, a1 * smooth(k / 12, k / 12 + 0.1, fp)));
    text(c, '人们相信的“未来路径”', 1300, 300, { size: 34, weight: 800, color: P.gold, alpha: a1 * fp, glow: 12, glowColor: P.gold });
    text(c, '力量更大的，往往是这一段', 1300, 350, { size: 26, color: '#e6d6b6', alpha: a1 * smooth(c0 + 7, c0 + 8, st) });
  }
  // 2) credibility anchors expectations
  const a2 = smooth(c1, c1 + 1, st) * (1 - smooth(c3 - 0.6, c3 + 0.4, st));
  if (a2 > 0) {
    bank(c, 960, 360, 1.1, a2);
    const msg = st - c1;
    for (let k = 0; k < 4; k++) { const r = ((msg * 120 + k * 120) % 480); c.strokeStyle = rgba(P.gold, a2 * (1 - r / 480) * 0.6); c.lineWidth = 2; c.beginPath(); c.arc(960, 420, r, 0.2 * Math.PI, 0.8 * Math.PI); c.stroke(); }
    const align = smooth(c1 + 2, c1 + 6, st);
    for (let i = 0; i < 60; i++) {
      const x = 360 + (i % 15) * 86, y = 700 + Math.floor(i / 15) * 60;
      const ang = lerp(hash(i) * TAU + Math.sin(st + i) * 0.5, -Math.PI / 2 * 0 + 0, align);
      dot(c, x, y, 6, i % 4 ? P.gold : P.jade, a2);
      line(c, [[x, y], [x + Math.cos(ang) * 26, y + Math.sin(ang) * 26]], '#ffffff', 2, a2 * 0.7);
    }
    dial(c, 1620, 520, 110, lerp(0.2 + 0.6 * (0.5 + 0.5 * Math.sin(st * 3)), 0.42, align), a2, { label: '2%', title: '通胀目标', col: P.jade });
    text(c, '预期被稳住', 1620, 360, { size: 34, weight: 800, color: P.jade, alpha: a2 * align });
    // forward guidance
    const g = smooth(c2, c2 + 1, st);
    if (g > 0) {
      alpha(c, g, () => { c.fillStyle = 'rgba(239,230,210,0.95)'; L.rrect(c, 380, 160, 420, 110, 18); c.fill(); c.beginPath(); c.moveTo(760, 270); c.lineTo(800, 320); c.lineTo(700, 270); c.fill(); });
      text(c, '“未来一段时间，利率将……”', 590, 215, { size: 30, font: F.kai, weight: 700, color: '#1a1410', alpha: g });
      text(c, '前瞻指引', 590, 330, { size: 44, weight: 900, color: P.gold, alpha: g, spacing: 8, glow: 14, glowColor: P.gold });
    }
  }
  const a3 = smooth(c3, c3 + 1, st);
  if (a3 > 0) {
    bookCard(c, 760, 500, '利息与价格', '货币政策理论的基础', '2003', '#2a3a5a', a3, { w: 420, h: 520, tsize: 52, en: 'Interest and Prices' });
    text(c, '深刻影响了各国央行', 1360, 480, { size: 44, weight: 800, color: '#ffffff', alpha: smooth(c3 + 2, c3 + 3, st), glow: 16, glowColor: P.gold, spacing: 4 });
  }
};

S.shocks = (c, st, sp) => {
  bg(c, st);
  const [c0, c1, c2] = [0, 1, 2].map(k => sp.cue(k));
  const a1 = smooth(c0 - 0.5, c0 + 0.5, st) * (1 - smooth(c2 - 0.6, c2 + 0.4, st));
  if (a1 > 0) {
    // a control-room screen
    alpha(c, a1, () => { c.fillStyle = 'rgba(4,10,20,0.85)'; L.rrect(c, 200, 180, 1520, 640, 24); c.fill(); c.strokeStyle = 'rgba(160,190,230,0.4)'; c.lineWidth = 2; c.stroke(); });
    const x0 = 280, x1 = 1360, yc = 520, tS = x0 + 160;
    line(c, [[x0, yc], [x1, yc]], '#9fb2c8', 1, a1 * 0.35);
    const pr = clamp((st - c0 - 1) / 6);
    const bad = [], good = [];
    for (let x = x0; x <= x1; x += 6) { const u = Math.max(0, x - tS); bad.push([x, yc - 190 * Math.sin(u * 0.012) * Math.exp(-u * 0.0012) * (x > tS ? 1 : 0)]); good.push([x, yc - 120 * Math.sin(u * 0.012) * Math.exp(-u * 0.0065) * (x > tS ? 1 : 0)]); }
    c.save(); c.setLineDash([10, 8]); line(c, partial(bad, pr), P.red, 3, a1 * 0.9); c.restore();
    line(c, partial(good, clamp((st - c0 - 3) / 6)), P.jade, 5, a1, 16);
    bolt(c, tS, 300, 2, '#ffb07a', a1 * smooth(c0 + 0.5, c0 + 1.2, st));
    text(c, '冲击：能源 · 消费意愿突变', tS + 40, 300, { size: 28, weight: 700, color: '#ffc7a0', alpha: a1 * smooth(c0 + 0.5, c0 + 1.2, st), align: 'left' });
    text(c, '不加应对', 1150, 330, { size: 28, weight: 700, color: P.red, alpha: a1 * smooth(c0 + 3, c0 + 4, st) });
    text(c, '依模型推演的应对', 1150, 720, { size: 28, weight: 700, color: P.jade, alpha: a1 * smooth(c0 + 6, c0 + 7, st) });
    // sliders
    [['利率', P.violet], ['财政', P.gold]].forEach(([s, col], i) => {
      const y = 380 + i * 160, v = 0.5 + 0.35 * Math.sin(st * 0.9 + i * 1.7) * smooth(c0 + 3, c0 + 5, st);
      line(c, [[1470, y], [1650, y]], '#9fb2c8', 4, a1 * 0.5);
      dot(c, lerp(1470, 1650, v), y, 13, col, a1); text(c, s, 1560, y - 40, { size: 28, weight: 700, color: col, alpha: a1 });
    });
    text(c, '先在模型里推演', 960, 140, { size: 38, weight: 800, color: '#ffffff', alpha: a1, spacing: 6 });
    const ka = smooth(c1, c1 + 1, st);
    badge(c, '评委会：近年的应对，比七十年代石油危机时更有效', W / 2, 880, P.gold, ka, { size: 28 });
  }
  // the world's central banks
  const a2 = smooth(c2, c2 + 1.2, st);
  if (a2 > 0) {
    const ex = W / 2, ey = 500, R = 300;
    additive(c, () => glow(c, ex, ey, R * 1.6, '#2a7bff', 0.3 * a2));
    const g = c.createRadialGradient(ex - R * 0.3, ey - R * 0.3, R * 0.1, ex, ey, R); g.addColorStop(0, '#0f3a6a'); g.addColorStop(1, '#03122a');
    alpha(c, a2, () => { c.fillStyle = g; c.beginPath(); c.arc(ex, ey, R, 0, TAU); c.fill(); });
    const yaw = st * 0.2, ct = Math.cos(0.35), stt = Math.sin(0.35);
    const lit = [];
    globePts.forEach((p, i) => {
      let X = p.x * Math.cos(yaw) - p.z * Math.sin(yaw), Z = p.x * Math.sin(yaw) + p.z * Math.cos(yaw);
      let Y = p.y * ct - Z * stt; Z = p.y * stt + Z * ct;
      if (Z < 0) return;
      const x = ex + X * R, y = ey - Y * R;
      dot(c, x, y, p.land ? 1.8 : 1.2, p.land ? '#7fe6c8' : '#5aa8ff', a2 * (p.land ? 0.8 : 0.4) * (0.3 + 0.7 * Z));
      if (p.land && i % 13 === 0) lit.push([x, y, i]);
    });
    lit.forEach(([x, y, i]) => additive(c, () => glow(c, x, y, 26, P.gold, a2 * (0.6 + 0.4 * Math.sin(st * 3 + i)))));
    for (let k = 0; k < lit.length - 1; k += 2) line(c, [[lit[k][0], lit[k][1]], [lit[k + 1][0], lit[k + 1][1]]], P.gold, 1, a2 * 0.35);
    text(c, '世界各国的央行与财政部门', ex, 880, { size: 40, weight: 800, color: '#ffffff', alpha: smooth(c2 + 1.5, c2 + 2.5, st), spacing: 6, glow: 14, glowColor: P.gold });
  }
};

S.finale = (c, st, sp) => {
  bg(c, st, { grid: false });
  const calm = clamp(st / 10);
  // a moon over the sea, and its reflection
  const mx = 1380, my = 290, ma = smooth(0.5, 3, st);
  additive(c, () => { glow(c, mx, my, 360, '#e8c477', 0.25 * ma); glow(c, mx, my, 120, '#fff2c8', 0.6 * ma); });
  dot(c, mx, my, 62, '#fbf1d6', ma);
  additive(c, () => { for (let k = 0; k < 26; k++) { const y = 580 + k * 16, w = 60 + k * 9 + Math.sin(st * 2 + k) * 14; line(c, [[mx - w / 2, y], [mx + w / 2, y]], '#fff2c8', 2, ma * 0.35 * (1 - k / 28)); } });
  tide(c, st, 560, lerp(90, 14, ease.out(calm)), 1, { n: 14, gap: 26 });
  for (let i = 0; i < 300; i++) { const x = (hash(i) * W + st * 12) % W, y = 520 + hash(i + 5) * 420 + Math.sin(st * 0.8 + i) * lerp(30, 6, calm); dot(c, x, y, 1.5, i % 4 ? P.gold : P.jade, 0.55); }
};

export default { palette: P, init, scenes: S };
