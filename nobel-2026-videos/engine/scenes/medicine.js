// 2026 生理学或医学奖 · 以光为令 —— 光门控离子通道与光遗传学
import * as L from '../lib.js';
import { drawTitle } from '../core.js';
const { W, H, TAU, clamp, lerp, smooth, ease, prog, glow, dot, line, text, reveal, F, rgba, fill, vgrad,
  additive, alpha, callout, badge, partial, rng, noise2, fbm, drawStars, makeStars, makeNebula, win, hash, mixHex } = L;

const P = { gold: '#e8c477', blue: '#4aa8ff', blueHi: '#9fd6ff', amber: '#ffb35c', yellow: '#ffd84a', green: '#6ee09a', eye: '#ff7a3a', violet: '#a98bff', teal: '#45d6c4', red: '#ff5f57', white: '#f2f7ff' };
let dust, neb, net = [], edges = [], field = [], cellShapes = [];

function init() {
  dust = makeStars(500, 41);
  neb = makeNebula(['#0e2a55', '#2a1650'], 8, 480, 270, 2.0, 0.75);
  // neural network
  const r = rng(21);
  for (let i = 0; i < 80; i++) net.push({ x: 80 + r() * (W - 160), y: 90 + r() * (H - 260), s: 0.6 + r() * 0.6, ph: r() * 10, sh: makeNeuronShape(r) });
  net.forEach((a, i) => net.forEach((b, j) => { if (j > i && Math.hypot(a.x - b.x, a.y - b.y) < 260 && r() < 0.55) edges.push({ a: i, b: j, bend: (r() - 0.5) * 120, ph: r() * 10, per: 2 + r() * 4 }); }));
  // mixed field of three cell types
  const rf = rng(5);
  for (let i = 0; i < 46; i++) field.push({ x: 260 + rf() * 1400, y: 230 + rf() * 560, type: i % 3, sh: makeNeuronShape(rf), ph: rf() * 6 });
}
function makeNeuronShape(r) {
  const dend = [];
  const n = 5 + Math.floor(r() * 3);
  for (let k = 0; k < n; k++) {
    const a0 = (k / n) * TAU + r() * 0.5; const pts = [[0, 0]]; let a = a0, x = 0, y = 0;
    const len = 50 + r() * 50;
    for (let s = 0; s < 6; s++) { a += (r() - 0.5) * 0.6; x += Math.cos(a) * len / 6; y += Math.sin(a) * len / 6; pts.push([x, y]); }
    dend.push(pts);
    if (r() < 0.7) { const b = pts[3]; const a2 = a + (r() < 0.5 ? 0.7 : -0.7); dend.push([b, [b[0] + Math.cos(a2) * 30, b[1] + Math.sin(a2) * 30], [b[0] + Math.cos(a2 + 0.2) * 50, b[1] + Math.sin(a2 + 0.2) * 50]]); }
  }
  return dend;
}
function neuronAt(c, x, y, s, sh, col, a = 1, fire = 0, o = {}) {
  if (a <= 0.003) return;
  c.save(); c.translate(x, y); c.scale(s, s);
  for (const d of sh) line(c, d, col, 2.2, a * 0.5);
  if (fire > 0.01) additive(c, () => glow(c, 0, 0, 60 + 40 * fire, o.fireCol ?? col, a * fire));
  const g = c.createRadialGradient(-4, -4, 1, 0, 0, 14);
  g.addColorStop(0, '#ffffff'); g.addColorStop(0.4, mixHex(col, '#ffffff', 0.4)); g.addColorStop(1, col);
  alpha(c, a, () => { c.fillStyle = g; c.beginPath(); c.arc(0, 0, 13, 0, TAU); c.fill(); });
  if (o.chr) for (let k = 0; k < 8; k++) { const ang = k / 8 * TAU + 0.2; dot(c, Math.cos(ang) * 15, Math.sin(ang) * 15, 3, P.blue, a); }
  c.restore();
}
function bg(c, st, o = {}) {
  fill(c, vgrad(c, [[0, '#02060f'], [0.6, '#06122a'], [1, '#0a1834']]));
  alpha(c, o.neb ?? 0.7, () => c.drawImage(neb, -40 + Math.sin(st * 0.05) * 20, -20, W + 80, H + 40));
  drawStars(c, dust, st, { dx: -st * 3, dy: st * 1.5, alpha: o.dust ?? 0.45 });
}
// voltage trace: spikes at given local times
function trace(c, x, y, w, h, t, spikes, o = {}) {
  const a = o.a ?? 1; if (a <= 0) return;
  const span = o.span ?? 4, col = o.col ?? '#ffffff';
  alpha(c, a, () => { c.fillStyle = 'rgba(0,0,0,0.35)'; L.rrect(c, x - 16, y - h - 20, w + 32, h + 60, 12); c.fill(); });
  const pts = [];
  for (let i = 0; i <= 240; i++) {
    const tt = t - span + (i / 240) * span;
    let v = 0;
    for (const s of spikes) { const d = tt - s; if (d > 0 && d < 0.05) v = Math.max(v, Math.sin(d / 0.05 * Math.PI) * (d < 0.025 ? 1 : 0.9)); if (d >= 0.05 && d < 0.2) v = Math.min(v, -0.18 * Math.sin((d - 0.05) / 0.15 * Math.PI)); }
    if (o.bump) for (const s of o.bump) { const d = tt - s; if (d > 0) v = Math.max(v, 0.55 * (1 - Math.exp(-d * 60)) * Math.exp(-d * (o.decay ?? 3))); }
    pts.push([x + (i / 240) * w, y - (v * 0.85 + 0.12) * h]);
  }
  line(c, [[x, y + 10], [x + w, y + 10]], '#8aa', 1, a * 0.4);
  line(c, pts, col, 2.5, a, 8);
  if (o.marks) for (const m of o.marks) { const dx = (m - (t - span)) / span; if (dx >= 0 && dx <= 1) { line(c, [[x + dx * w, y + 22], [x + dx * w, y + 36]], o.markCol ?? P.blue, 4, a); } }
  if (o.label) text(c, o.label, x, y - h - 2, { size: 22, color: '#cfe0f5', align: 'left', alpha: a });
}
function membrane(c, y, x0, x1, st, o = {}) {
  const a = o.a ?? 1; const gap = o.gap ?? null;
  for (let x = x0; x <= x1; x += 22) {
    if (gap && x > gap[0] && x < gap[1]) continue;
    const wob = Math.sin(x * 0.05 + st) * 1.5;
    for (const side of [-1, 1]) {
      const hy = y + side * 52 + wob;
      line(c, [[x - 4, hy - side * 10], [x - 3, y + side * 8]], '#c8b590', 2, a * 0.6);
      line(c, [[x + 4, hy - side * 10], [x + 5, y + side * 8]], '#c8b590', 2, a * 0.6);
      const g = c.createRadialGradient(x - 3, hy - 3, 1, x, hy, 11); g.addColorStop(0, '#fff3dc'); g.addColorStop(1, '#c79a5a');
      alpha(c, a, () => { c.fillStyle = g; c.beginPath(); c.arc(x, hy, 10, 0, TAU); c.fill(); });
    }
  }
}
function ion(c, x, y, a = 1, col = P.amber, r = 13) {
  additive(c, () => glow(c, x, y, r * 2.6, col, 0.6 * a));
  dot(c, x, y, r, col, a);
  text(c, '+', x, y + 1, { size: r * 1.7, weight: 900, color: '#3a1a00', alpha: a, font: F.greek });
}
function photon(c, x0, y0, x1, y1, u, col, a = 1) {
  // a short wave packet travelling from (x0,y0) to (x1,y1)
  const ang = Math.atan2(y1 - y0, x1 - x0), L0 = Math.hypot(x1 - x0, y1 - y0);
  const hx = x0 + Math.cos(ang) * L0 * u, hy = y0 + Math.sin(ang) * L0 * u;
  const pts = [];
  for (let k = 0; k <= 60; k++) { const s = -k * 2.4; const off = Math.sin(k * 0.6) * 12 * Math.exp(-Math.pow((k - 25) / 18, 2)); pts.push([hx + Math.cos(ang) * s - Math.sin(ang) * off, hy + Math.sin(ang) * s + Math.cos(ang) * off]); }
  additive(c, () => { line(c, pts, col, 3, a, 14); glow(c, hx, hy, 26, col, a); });
}
function mouseShape(c, x, y, s, st, run, a = 1) {
  c.save(); c.translate(x, y); c.scale(s, s);
  alpha(c, a, () => {
    c.lineWidth = 3; c.strokeStyle = 'rgba(230,240,255,0.95)'; c.fillStyle = 'rgba(160,180,210,0.16)';
    // tail
    c.beginPath(); c.moveTo(-160, 30); c.bezierCurveTo(-260, 80, -330, -20, -400, 40 + Math.sin(st * 4) * 10 * run); c.stroke();
    // body and head as one outline, then the ear
    c.beginPath(); c.moveTo(-165, 20);
    c.bezierCurveTo(-170, -60, -60, -100, 60, -88);
    c.bezierCurveTo(120, -82, 150, -75, 178, -66);
    c.bezierCurveTo(222, -54, 268, -18, 292, 8);
    c.bezierCurveTo(270, 30, 210, 45, 150, 55);
    c.bezierCurveTo(100, 85, 0, 98, -80, 88);
    c.bezierCurveTo(-140, 80, -168, 60, -165, 20); c.closePath(); c.fill(); c.stroke();
    c.beginPath(); c.arc(165, -84, 30, 0, TAU); c.fillStyle = 'rgba(40,52,78,0.95)'; c.fill(); c.stroke();
    dot(c, 238, -16, 6, '#ffffff', 1);
    // legs
    for (const [lx, ph] of [[100, 0], [-100, Math.PI]]) { const sw = Math.sin(st * 12 + ph) * 22 * run; c.beginPath(); c.moveTo(lx, 70); c.lineTo(lx + sw, 120); c.lineTo(lx + sw + 24, 122); c.stroke(); }
  });
  c.restore();
}
function brainPath(c) {
  c.beginPath();
  c.moveTo(-270, 40);
  c.bezierCurveTo(-300, -60, -230, -170, -90, -190);
  c.bezierCurveTo(40, -210, 200, -175, 260, -90);
  c.bezierCurveTo(300, -30, 300, 40, 250, 75);
  c.bezierCurveTo(200, 100, 150, 85, 110, 80);
  c.bezierCurveTo(60, 120, -40, 130, -110, 105);
  c.bezierCurveTo(-170, 90, -250, 90, -270, 40);
  c.closePath();
}
function brainExtras(c, a) {
  // cerebellum
  c.save(); c.beginPath(); c.ellipse(185, 112, 78, 44, -0.15, 0, TAU); c.fillStyle = 'rgba(120,140,190,0.12)'; c.fill(); c.strokeStyle = rgba('#d2e1ff', 0.8 * a); c.lineWidth = 2.5; c.stroke(); c.clip();
  for (let k = -3; k <= 3; k++) { c.beginPath(); c.ellipse(185, 112 + k * 11, 80, 10, -0.15, 0, Math.PI); c.strokeStyle = rgba('#9fb3dd', 0.35 * a); c.lineWidth = 1.2; c.stroke(); }
  c.restore();
  // brainstem
  c.beginPath(); c.moveTo(62, 100); c.bezierCurveTo(66, 150, 70, 185, 76, 225); c.lineTo(120, 225); c.bezierCurveTo(118, 185, 114, 140, 108, 92);
  c.fillStyle = 'rgba(120,140,190,0.12)'; c.fill(); c.strokeStyle = rgba('#d2e1ff', 0.8 * a); c.lineWidth = 2.5; c.stroke();
  // lateral sulcus
  c.beginPath(); c.moveTo(-150, 40); c.bezierCurveTo(-80, 10, 20, 0, 110, -20); c.strokeStyle = rgba('#d2e1ff', 0.55 * a); c.lineWidth = 2; c.stroke();
}
function eyeball(c, x, y, R, a = 1) {
  alpha(c, a, () => {
    const g = c.createRadialGradient(x - R * 0.3, y - R * 0.3, R * 0.2, x, y, R);
    g.addColorStop(0, 'rgba(40,60,90,0.6)'); g.addColorStop(1, 'rgba(10,20,40,0.9)');
    c.fillStyle = g; c.beginPath(); c.arc(x, y, R, 0, TAU); c.fill();
    c.strokeStyle = 'rgba(230,240,255,0.8)'; c.lineWidth = 3; c.stroke();
    // lens
    c.fillStyle = 'rgba(200,230,255,0.35)'; c.beginPath(); c.ellipse(x - R * 0.82, y, R * 0.12, R * 0.32, 0, 0, TAU); c.fill(); c.stroke();
  });
}

// ---------------------------------------------------------------- scenes
const S = {};
S.title = (c, st) => {
  bg(c, st);
  // faint network breathing behind the title
  netDraw(c, st, 0.35, 0.6);
  additive(c, () => { glow(c, W / 2, -120, 900, P.blue, 0.35); });
  drawTitle(c, st, { glow: P.blue });
};
function netDraw(c, st, a, act = 1, o = {}) {
  for (const e of edges) {
    const A = net[e.a], B = net[e.b];
    const mx = (A.x + B.x) / 2 + e.bend, my = (A.y + B.y) / 2 - e.bend * 0.4;
    c.strokeStyle = rgba(o.edge ?? '#6f8fc0', 0.16 * a); c.lineWidth = 1.2; c.beginPath(); c.moveTo(A.x, A.y); c.quadraticCurveTo(mx, my, B.x, B.y); c.stroke();
    const k = ((st + e.ph) % e.per) / e.per;
    if (k < 0.5 * act) {
      const u = k / 0.5; const x = (1 - u) * (1 - u) * A.x + 2 * (1 - u) * u * mx + u * u * B.x, y = (1 - u) * (1 - u) * A.y + 2 * (1 - u) * u * my + u * u * B.y;
      additive(c, () => glow(c, x, y, 16, o.pulse ?? P.amber, a * 0.9));
    }
  }
  net.forEach((n, i) => { const f = Math.max(0, Math.sin(st * 1.3 + n.ph * 3)) ** 16 * act; neuronAt(c, n.x, n.y, n.s * 0.8, n.sh, o.cell ?? '#d8b48a', a * 0.85, f, { fireCol: o.pulse ?? P.amber }); });
}

S.network = (c, st, sp) => {
  bg(c, st);
  const act = 0.7 + 0.6 * smooth(sp.cue(1), sp.cue(1) + 2, st);
  netDraw(c, st, smooth(0, 1.5, st), act);
  const a = smooth(sp.cue(0), sp.cue(0) + 1, st) * (1 - smooth(sp.cue(1) - 0.5, sp.cue(1) + 0.3, st));
  if (a > 0) { c.fillStyle = `rgba(2,6,15,${0.55 * a})`; c.fillRect(0, 380, W, 300); }
  text(c, '约 860 亿', W / 2, 500, { size: 120, weight: 900, color: '#ffffff', alpha: a, spacing: 8, glow: 30, glowColor: P.amber });
  text(c, '个神经元', W / 2, 600, { size: 40, weight: 600, color: '#f3e3cc', alpha: a, spacing: 16 });
  const b = smooth(sp.cue(1) + 3, sp.cue(1) + 4, st);
  text(c, '念头 · 记忆 · 心跳 —— 都是电信号的合奏', W / 2, 150, { size: 36, weight: 700, color: '#f3e3cc', alpha: b, spacing: 4, glow: 14, glowColor: '#000' });
};

S.ionchannel = (c, st, sp) => {
  bg(c, st, { neb: 0.5 });
  const y = 520, open = ease.inOut(clamp((st - 3) / 1.2)) * (1 - ease.inOut(clamp((st - 9) / 1)));
  membrane(c, y, 120, 1800, st, { gap: [870, 1050] });
  // channel: two purple halves
  const gx = 960, sep = 28 + 36 * open;
  for (const side of [-1, 1]) {
    alpha(c, 1, () => {
      const g = c.createLinearGradient(gx + side * sep - 40, 0, gx + side * sep + 40, 0); g.addColorStop(0, '#7d5cff'); g.addColorStop(1, '#b49bff');
      c.fillStyle = g; L.rrect(c, gx + side * (sep + 20) - 30, y - 92, 60, 184, 26); c.fill();
      c.strokeStyle = 'rgba(255,255,255,0.6)'; c.lineWidth = 1.5; c.stroke();
    });
  }
  text(c, '细胞外', 220, 330, { size: 30, color: '#cfe0f5', alpha: 0.85, align: 'left' });
  text(c, '细胞内', 220, 720, { size: 30, color: '#cfe0f5', alpha: 0.85, align: 'left' });
  callout(c, gx + 70, y - 80, gx + 240, 300, '离子通道', '细胞膜上的“闸门”', P.violet, smooth(0.8, 1.8, st));
  // ions waiting outside, rushing in when open
  for (let i = 0; i < 18; i++) {
    const r0x = 600 + hash(i) * 720, r0y = 250 + hash(i + 3) * 120;
    const t0 = 3.4 + i * 0.22; const u = clamp((st - t0) / 1.4);
    let x = r0x + Math.sin(st * 2 + i) * 6, yy = r0y + Math.cos(st * 1.7 + i) * 6;
    if (u > 0 && open > 0.3) { const k = ease.inOut(u); x = u < 0.5 ? lerp(r0x, gx, k * 2) : gx + (hash(i + 7) - 0.5) * 500 * (k - 0.5) * 2; yy = u < 0.5 ? lerp(r0y, y - 90, k * 2) : lerp(y - 90, 800 + hash(i + 9) * 100, (k - 0.5) * 2); }
    ion(c, x, yy, 0.9);
  }
  trace(c, 1380, 900, 380, 120, st, [4.25], { a: smooth(2.5, 3.2, st), label: '膜电位', span: 6, col: P.amber });
  badge(c, '闸门打开 → 离子涌入 → 放电', 700, 900, P.amber, smooth(4.5, 5.5, st), { size: 28 });
};

S.electrode = (c, st, sp) => {
  bg(c, st, { neb: 0.5 });
  const cols = [P.amber, P.teal, P.violet];
  const ex = 960, ey = lerp(-200, 470, ease.out(clamp((st - sp.cue(1) - 0.5) / 1.4)));
  const zap = st > sp.cue(1) + 1.9 && st < sp.cue(1) + 5.5;
  field.forEach((n, i) => {
    const d = Math.hypot(n.x - ex, n.y - 520);
    const fire = zap && d < 420 ? 0.6 + 0.4 * Math.sin(st * 20 + i) : (Math.sin(st * 1.1 + n.ph) > 0.97 ? 0.6 : 0);
    neuronAt(c, n.x, n.y, 0.75, n.sh, cols[n.type], 0.9, fire);
  });
  const qa = win(st, 0.3, sp.cue(1) + 0.4, 0.8);
  ['哪一群神经元？', '在哪一刻？', '造就哪种行为？'].forEach((s, i) => text(c, s, 480 + i * 480, 140, { size: 40, weight: 800, color: '#ffffff', alpha: qa * smooth(1 + i * 1.2, 2 + i * 1.2, st), spacing: 4, glow: 14, glowColor: '#000' }));
  // electrode
  if (st > sp.cue(1)) {
    line(c, [[ex, -40], [ex, ey]], '#d8dde8', 10, 1); line(c, [[ex, ey], [ex, ey + 40]], '#ffffff', 3, 1);
    if (zap) additive(c, () => { glow(c, ex, ey + 40, 420, '#ffffff', 0.15); for (let k = 0; k < 10; k++) { const a = hash(k + Math.floor(st * 12)) * TAU; line(c, [[ex, ey + 40], [ex + Math.cos(a) * 160, ey + 40 + Math.sin(a) * 160]], '#ffffff', 2, 0.6); } });
    badge(c, '电极：一刺激，一大片', 1500, 140, '#ffffff', smooth(sp.cue(1) + 2, sp.cue(1) + 3, st), { size: 30 });
  }
  // drugs: slow haze
  const da = smooth(sp.cue(1) + 6, sp.cue(1) + 7, st);
  if (da > 0) {
    const R = 60 + (st - sp.cue(1) - 6) * 40;
    additive(c, () => glow(c, 420, 760, R * 2, '#7fe08a', 0.35 * da));
    badge(c, '药物：太慢', 420, 900, '#7fe08a', da, { size: 30 });
    text(c, '大脑的节奏：毫秒', 1500, 900, { size: 34, weight: 800, color: P.gold, alpha: smooth(sp.cue(1) + 8, sp.cue(1) + 9, st), spacing: 4 });
  }
};

function chlamy(c, x, y, s, st, o = {}) {
  const a = o.a ?? 1; if (a <= 0) return;
  c.save(); c.translate(x, y); c.rotate(o.rot ?? 0); c.scale(s, s);
  // flagella (breast-stroke)
  const beat = Math.sin(st * 7);
  for (const side of [-1, 1]) {
    const pts = [];
    for (let k = 0; k <= 30; k++) { const u = k / 30; const ang = -Math.PI / 2 + side * (0.25 + 0.9 * u * (0.6 + 0.4 * beat)); const rr = u * 260; pts.push([side * 10 + Math.cos(ang) * rr * 0.7 + side * Math.sin(u * 6 + st * 7) * 14 * u, -150 + Math.sin(ang) * rr]); }
    line(c, pts, '#d8ffe0', 3, a * 0.85, 6);
  }
  additive(c, () => glow(c, 0, 0, 240, P.green, 0.25 * a));
  alpha(c, a, () => {
    const g = c.createRadialGradient(-30, -40, 10, 0, 0, 170); g.addColorStop(0, '#b9ffc9'); g.addColorStop(0.6, '#3fae6a'); g.addColorStop(1, '#1b5e3a');
    c.fillStyle = g; c.beginPath(); c.ellipse(0, 0, 120, 155, 0, 0, TAU); c.fill();
    c.strokeStyle = 'rgba(220,255,230,0.7)'; c.lineWidth = 2; c.stroke();
    // cup chloroplast
    c.save(); c.beginPath(); c.rect(-130, -10, 260, 200); c.clip();
    c.fillStyle = 'rgba(18,96,48,0.32)'; c.beginPath(); c.ellipse(0, 0, 108, 143, 0, 0, TAU); c.ellipse(0, -30, 78, 104, 0, 0, TAU); c.fill('evenodd');
    c.restore();
    // nucleus
    c.fillStyle = 'rgba(230,255,240,0.35)'; c.beginPath(); c.arc(0, -30, 36, 0, TAU); c.fill();
  });
  // eyespot
  additive(c, () => glow(c, 95, -40, 50, P.eye, a * (0.7 + (o.spotFlash ?? 0))));
  alpha(c, a, () => { c.fillStyle = '#ff6a2a'; c.beginPath(); c.ellipse(98, -40, 14, 26, 0.2, 0, TAU); c.fill(); });
  c.restore();
}
S.alga = (c, st, sp) => {
  bg(c, st, { neb: 0.4 });
  // light source upper right
  additive(c, () => { glow(c, 1780, 80, 600, '#fff2c0', 0.35); for (let k = 0; k < 12; k++) { const a = Math.PI * 0.62 + k * 0.05; line(c, [[1780, 80], [1780 + Math.cos(a) * 1600, 80 + Math.sin(a) * 1600]], '#fff6d8', 30, 0.025); } });
  const zoom = ease.inOut(clamp((st - sp.cue(2) - 0.5) / 2.5));
  const sw = st * 12;
  const cx = lerp(760 + sw, 1100, zoom), cy = lerp(600 - sw * 0.5, 650, zoom), sc = lerp(1.25, 2.6, zoom);
  const flash = st > sp.cue(2) + 4 ? Math.exp(-((st - sp.cue(2) - 4) % 3) * 4) : 0;
  chlamy(c, cx, cy, sc, st, { rot: 0.55, spotFlash: flash });
  const a0 = smooth(sp.cue(0) + 1, sp.cue(0) + 2, st) * (1 - zoom);
  text(c, '莱茵衣藻', 330, 380, { size: 56, weight: 900, color: '#d8ffe4', alpha: a0, spacing: 10, glow: 18, glowColor: P.green });
  text(c, '一个细胞，就是一个生命', 330, 450, { size: 28, color: '#cdeedd', alpha: a0, spacing: 4 });
  const k1 = smooth(sp.cue(1) + 1, sp.cue(1) + 2, st) * (1 - zoom);
  if (k1 > 0) {
    const ang = 0.55, ex = cx + (98 * Math.cos(ang) + 40 * Math.sin(ang)) * sc, ey = cy + (98 * Math.sin(ang) - 40 * Math.cos(ang)) * sc;
    callout(c, ex, ey, ex + 240, ey + 160, '眼点', '感知光的方向', P.eye, k1);
    callout(c, cx + 60, cy - 330, cx - 250, cy - 420, '两根鞭毛', '朝光游去', '#d8ffe0', smooth(sp.cue(1) + 3, sp.cue(1) + 4, st) * (1 - zoom));
  }
  if (zoom > 0) {
    // the surprisingly fast photocurrent
    const flashes = []; for (let k = 0; k < 6; k++) flashes.push(sp.cue(2) + 4 + k * 3);
    trace(c, 200, 880, 520, 150, st, [], { a: zoom, bump: flashes, decay: 6, marks: flashes, markCol: '#fff2c0', label: '光照 → 电流（毫秒级）', col: P.green, span: 7 });
    const da = smooth(sp.cue(2) + 7, sp.cue(2) + 8, st);
    if (da > 0) {
      // a door of light
      const dx = 520, dy = 330, ow = 120 * ease.out(da);
      alpha(c, da, () => { c.strokeStyle = '#fff2c0'; c.lineWidth = 3; c.strokeRect(dx - 70, dy - 120, 140, 240); });
      additive(c, () => { const g = c.createLinearGradient(dx - 70, 0, dx - 70 + ow, 0); g.addColorStop(0, rgba('#fff2c0', 0.9 * da)); g.addColorStop(1, rgba('#fff2c0', 0)); c.fillStyle = g; c.fillRect(dx - 70, dy - 118, ow, 236); });
      text(c, '光，直接推开了一扇门？', dx, dy + 170, { size: 34, weight: 800, color: '#fff2c0', alpha: da, spacing: 4 });
    }
  }
};

S.oocyte = (c, st, sp) => {
  bg(c, st, { neb: 0.5 });
  const ox = 700, oy = 520, R = 260;
  additive(c, () => glow(c, ox, oy, R * 1.8, '#ffcf9a', 0.18));
  const g = c.createLinearGradient(0, oy - R, 0, oy + R); g.addColorStop(0, '#3a2516'); g.addColorStop(0.48, '#6b4a30'); g.addColorStop(0.52, '#e8d7b0'); g.addColorStop(1, '#f6ecd2');
  c.fillStyle = g; c.beginPath(); c.arc(ox, oy, R, 0, TAU); c.fill();
  const g2 = c.createRadialGradient(ox - R * 0.4, oy - R * 0.5, 10, ox, oy, R); g2.addColorStop(0, 'rgba(255,255,255,0.35)'); g2.addColorStop(1, 'rgba(0,0,0,0.25)');
  c.fillStyle = g2; c.beginPath(); c.arc(ox, oy, R, 0, TAU); c.fill();
  text(c, '蛙卵细胞', ox, oy + R + 50, { size: 34, weight: 700, color: '#f3e3cc', alpha: smooth(0.5, 1.5, st), spacing: 8 });
  // inject algal gene
  const inj = clamp((st - sp.cue(0)) / 2.2);
  const nx = lerp(1300, ox + R * 0.75, ease.out(inj)), ny = lerp(160, oy - R * 0.62, ease.out(inj));
  line(c, [[1500, 40], [nx, ny]], '#e0e6f0', 4, smooth(sp.cue(0) - 0.5, sp.cue(0), st));
  if (inj > 0.6) additive(c, () => glow(c, ox + R * 0.7, oy - R * 0.55, 60, P.green, (inj - 0.6) * 2 * (1 - smooth(sp.cue(0) + 3, sp.cue(0) + 4, st))));
  badge(c, '藻类的基因', 1460, 140, P.green, smooth(sp.cue(0), sp.cue(0) + 1, st), { size: 28 });
  // channels appear on the surface
  const ch = smooth(sp.cue(0) + 3, sp.cue(0) + 5, st);
  for (let i = 0; i < 40; i++) { const a = i / 40 * TAU; const k = smooth(i / 40, i / 40 + 0.2, ch); dot(c, ox + Math.cos(a) * R, oy + Math.sin(a) * R, 6, P.violet, k); }
  // blue light flash -> current
  const fl = []; for (let k = 0; k < 5; k++) fl.push(sp.cue(0) + 6 + k * 2.2);
  const last = fl.filter(f => st > f).pop();
  if (last !== undefined && st - last < 0.9) additive(c, () => glow(c, ox, oy, R * 2.2, P.blue, 0.5 * Math.exp(-(st - last) * 3)));
  trace(c, 1200, 620, 520, 160, st, [], { a: smooth(sp.cue(0) + 5, sp.cue(0) + 6, st), bump: fl, decay: 4, marks: fl, markCol: P.blue, label: '蓝光 → 电流', col: P.blueHi, span: 8 });
  const ta = smooth(sp.cue(1), sp.cue(1) + 1.2, st);
  if (ta > 0) {
    c.fillStyle = `rgba(2,6,15,${0.6 * ta})`; c.fillRect(0, 0, W, H);
    reveal(c, '通道视紫红质', W / 2, 500, clamp((st - sp.cue(1)) / 1.5), { size: 110, weight: 900, color: '#ffffff', spacing: 18, glow: 34, glowColor: P.blue, spread: 0.5 });
    text(c, 'Channelrhodopsin', W / 2, 620, { size: 44, font: F.latin, italic: true, weight: 500, color: P.blueHi, alpha: smooth(sp.cue(1) + 1, sp.cue(1) + 2, st), spacing: 4 });
  }
};

S.channel = (c, st, sp) => {
  bg(c, st, { neb: 0.45 });
  const y = 540, gx = 960;
  // cycles of light: first at cue(1)
  const c0 = sp.cue(1);
  const per = 4.2;
  const k = st - c0;
  const ph = k > 0 ? k % per : -1;
  const lightOn = ph >= 0 && ph < 1.6;
  const open = ph < 0 ? 0 : ease.inOut(clamp((ph - 0.35) / 0.35)) * (1 - ease.inOut(clamp((ph - 2.0) / 0.5)));
  membrane(c, y, 80, 1840, st, { gap: [800, 1120] });
  // the protein body, then its helices
  additive(c, () => glow(c, gx, y, 260, P.violet, 0.25));
  alpha(c, 0.9, () => { c.fillStyle = 'rgba(140,110,255,0.16)'; L.rrect(c, gx - 175 - 34 * open, y - 140, 350 + 68 * open, 280, 60); c.fill(); c.strokeStyle = 'rgba(200,180,255,0.35)'; c.lineWidth = 1.5; c.stroke(); });
  const offs = [-120, -60, 60, 120];
  offs.forEach((o, i) => {
    const side = o < 0 ? -1 : 1;
    const x = gx + o + side * 34 * open;
    const g = c.createLinearGradient(x - 26, 0, x + 26, 0); g.addColorStop(0, '#6d4fe8'); g.addColorStop(0.5, '#c2adff'); g.addColorStop(1, '#6d4fe8');
    c.fillStyle = g; L.rrect(c, x - 24, y - 120, 48, 240, 22); c.fill();
    c.strokeStyle = 'rgba(255,255,255,0.35)'; c.lineWidth = 1.2; for (let j = -100; j < 110; j += 18) { c.beginPath(); c.moveTo(x - 22, y + j); c.lineTo(x + 22, y + j + 10); c.stroke(); }
  });
  // retinal: a zigzag chain that kinks under light
  const kink = ph < 0 ? 0 : ease.out(clamp((ph - 0.1) / 0.25)) * (1 - ease.inOut(clamp((ph - 2.0) / 0.5)));
  const ret = [];
  for (let j = 0; j <= 10; j++) { let px = gx - 80 + j * 16, py = y - 20 + (j % 2 ? -10 : 10); if (j > 5) { const ang = kink * 0.9; const dx = (j - 5) * 16; px = gx - 80 + 80 + dx * Math.cos(ang); py = y - 20 + dx * Math.sin(ang) + (j % 2 ? -10 : 10); } ret.push([px, py]); }
  line(c, ret, '#ffb35c', 5, 1, 10);
  callout(c, gx - 40, y - 24, 560, 250, '视黄醛', '维生素 A 的“近亲”', P.amber, smooth(sp.cue(0) + 1, sp.cue(0) + 2, st) * (1 - smooth(c0 - 0.3, c0 + 0.5, st)));
  text(c, '通道视紫红质', gx, 210, { size: 40, weight: 800, color: '#d9ccff', alpha: smooth(0.4, 1.4, st), spacing: 8, glow: 14, glowColor: P.violet });
  // light
  if (ph >= 0 && ph < 0.45) photon(c, gx + 420, 0, gx, y - 40, ph / 0.45, P.blue, 1);
  if (lightOn) additive(c, () => glow(c, gx, y - 60, 380, P.blue, 0.35 * (1 - ph / 1.6)));
  const la = smooth(c0, c0 + 1, st);
  badge(c, lightOn ? '蓝光：开' : '黑暗：关', 1600, 220, lightOn ? P.blue : '#8aa0b8', la, { size: 30 });
  // ions through the open pore
  if (open > 0.2) for (let i = 0; i < 12; i++) { const u = ((st * 0.9 + i / 12) % 1); const x = gx + (hash(i) - 0.5) * 40 * open, yy = lerp(260, 860, u); ion(c, x, yy, open * (u < 0.1 ? u * 10 : 1) * (u > 0.85 ? (1 - u) / 0.15 : 1), P.amber, 11); }
  const spikes = []; for (let n = 0; n < 6; n++) spikes.push(c0 + n * per + 0.75);
  trace(c, 1330, 920, 460, 120, st, spikes, { a: smooth(sp.cue(2), sp.cue(2) + 1, st), label: '电信号', span: 8, col: P.amber, marks: spikes.map(s => s - 0.65), markCol: P.blue });
  const fa = smooth(sp.cue(3), sp.cue(3) + 1, st);
  text(c, '大自然造好的“光控开关”', 520, 880, { size: 40, weight: 800, color: '#ffffff', alpha: fa, spacing: 6, glow: 18, glowColor: P.blue });
};

S.neuron = (c, st, sp) => {
  bg(c, st, { neb: 0.45 });
  const nx = 620, ny = 470;
  const flashes = []; for (let k = 0; k < 40; k++) flashes.push(sp.cue(1) + 0.5 + k * 0.6);
  const lastF = flashes.filter(f => st >= f).pop();
  const since = lastF === undefined ? 9 : st - lastF;
  const fire = Math.exp(-since * 9) * (since < 1 ? 1 : 0);
  // axon
  const axon = []; for (let k = 0; k <= 40; k++) { const u = k / 40; axon.push([nx + u * 1050, ny + Math.sin(u * 5) * 40 + u * 60]); }
  line(c, axon, '#d8c3a0', 5, 0.8);
  if (since < 2) { const u = clamp(since / 0.9); const p = axon[Math.floor(u * 40)]; additive(c, () => glow(c, p[0], p[1], 34, P.amber, 1 - u * 0.5)); }
  for (let k = 0; k < 6; k++) { const e = axon[40]; const a = -0.6 + k * 0.25; line(c, [e, [e[0] + Math.cos(a) * 90, e[1] + Math.sin(a) * 90]], '#d8c3a0', 3, 0.7); }
  // the cell
  const sh = net[3].sh;
  c.save(); c.translate(nx, ny); c.scale(2.6, 2.6); for (const d of sh) line(c, d, '#d8c3a0', 2.2, 0.75); c.restore();
  if (fire > 0.01) additive(c, () => glow(c, nx, ny, 260, P.amber, fire));
  const g = c.createRadialGradient(nx - 10, ny - 10, 4, nx, ny, 44); g.addColorStop(0, '#fff2dc'); g.addColorStop(1, '#c98a4a');
  c.fillStyle = g; c.beginPath(); c.arc(nx, ny, 42, 0, TAU); c.fill();
  // channelrhodopsin dots
  const ca = smooth(sp.cue(0) + 1, sp.cue(0) + 3, st);
  for (let k = 0; k < 18; k++) { const a = k / 18 * TAU; dot(c, nx + Math.cos(a) * 46, ny + Math.sin(a) * 46, 4.5, P.blue, ca); }
  callout(c, nx + 40, ny - 34, nx + 260, ny - 230, '装上通道视紫红质的神经元', '2005', P.blue, smooth(sp.cue(0) + 2, sp.cue(0) + 3, st));
  // blue light pulses
  if (since < 0.25) additive(c, () => { const k = 1 - since / 0.25; const gg = c.createLinearGradient(nx, 0, nx, ny); gg.addColorStop(0, rgba(P.blue, 0)); gg.addColorStop(1, rgba(P.blue, 0.55 * k)); c.fillStyle = gg; c.beginPath(); c.moveTo(nx - 30, 0); c.lineTo(nx + 30, 0); c.lineTo(nx + 160, ny); c.lineTo(nx - 160, ny); c.closePath(); c.fill(); glow(c, nx, ny, 160, P.blue, 0.6 * k); });
  const ta = smooth(sp.cue(1), sp.cue(1) + 0.8, st);
  trace(c, 360, 900, 1200, 150, st, flashes.map(f => f + 0.012), { a: ta, label: '蓝光闪一下（蓝色刻度） → 神经元放电一次', span: 5, col: P.amber, marks: flashes, markCol: P.blue });
  text(c, '一拍不差', 1500, 300, { size: 64, weight: 900, color: '#ffffff', alpha: smooth(sp.cue(1) + 3, sp.cue(1) + 4, st), spacing: 14, glow: 24, glowColor: P.blue });
  text(c, '毫秒级的精度', 1500, 380, { size: 32, weight: 600, color: P.blueHi, alpha: smooth(sp.cue(1) + 3.5, sp.cue(1) + 4.5, st), spacing: 6 });
};

S.celltype = (c, st, sp) => {
  bg(c, st, { neb: 0.45 });
  const cols = [P.amber, P.teal, P.violet];
  const light = smooth(4, 5, st);
  if (light > 0) additive(c, () => { const g = c.createRadialGradient(W / 2, 0, 50, W / 2, 500, 1100); g.addColorStop(0, rgba(P.blue, 0.4 * light)); g.addColorStop(1, rgba(P.blue, 0)); c.fillStyle = g; c.fillRect(0, 0, W, H); });
  field.forEach((n, i) => {
    const tagged = n.type === 2;
    const fire = tagged && light > 0.5 ? Math.max(0, Math.sin(st * 9 + i)) ** 4 : 0;
    neuronAt(c, n.x, n.y, 0.8, n.sh, cols[n.type], tagged ? 1 : 0.55 + 0.45 * (1 - light), fire, { chr: tagged && st > 1.5, fireCol: P.blueHi });
  });
  badge(c, '只给这一类神经元装上开关', 560, 140, P.violet, smooth(1.5, 2.5, st), { size: 30 });
  badge(c, '蓝光照下：只有它们响应', 1360, 140, P.blue, smooth(5, 6, st), { size: 30 });
  text(c, '基因的“地址标签”', W / 2, 900, { size: 40, weight: 800, color: '#ffffff', alpha: smooth(2.5, 3.5, st), spacing: 8, glow: 16, glowColor: P.violet });
};

S.mouse = (c, st, sp) => {
  bg(c, st, { neb: 0.45 });
  const mx = 860, my = 560;
  const c1 = sp.cue(1);
  const blueOn = st > 3 && st < c1 ? ((st - 3) % 4) < 2.2 : false;
  const ph2 = st - c1 - 1.5;
  const blue2 = ph2 > 0 && (ph2 % 6) < 2.5, yellow2 = ph2 > 0 && (ph2 % 6) >= 3 && (ph2 % 6) < 5.5;
  const run = blueOn || blue2 ? 1 : 0;
  const dx = Math.sin(st * 0.6) * 40 * run;
  mouseShape(c, mx + dx, my, 1.25, st, run, smooth(0.2, 1.2, st));
  // optical fibre into the head
  const hx = mx + dx + 205 * 1.25, hy = my - 58 * 1.25;
  line(c, [[hx + 40, -40], [hx + 20, hy - 120], [hx, hy - 30]], '#dfe8f5', 3, 1);
  L.rrect(c, hx - 12, hy - 60, 24, 34, 6); c.fillStyle = '#c8d2e0'; c.fill();
  const lc = blueOn || blue2 ? P.blue : yellow2 ? P.yellow : null;
  if (lc) additive(c, () => { glow(c, hx, hy - 4, 120, lc, 0.8); glow(c, hx, hy - 4, 36, '#ffffff', 0.8); line(c, [[hx + 40, -40], [hx + 20, hy - 120], [hx, hy - 30]], lc, 3, 0.9, 10); });
  text(c, '2007 · 活体小鼠', 300, 200, { size: 44, weight: 900, color: '#ffffff', alpha: smooth(1, 2, st) * (1 - smooth(c1 - 0.5, c1, st)), glow: 16, glowColor: P.blue });
  callout(c, hx + 20, hy - 140, hx + 220, hy - 250, '细如发丝的光纤', '把光送入脑深处', P.blueHi, smooth(2, 3, st) * (1 - smooth(c1 - 0.5, c1, st)));
  text(c, run ? '回路被点亮 → 小鼠应声而动' : '', mx, 860, { size: 34, weight: 700, color: '#dff0ff', alpha: smooth(4, 5, st) * (1 - smooth(c1 - 0.5, c1, st)), spacing: 4 });
  // on / off
  const ka = smooth(c1, c1 + 1, st);
  if (ka > 0) {
    badge(c, '蓝光：开', 1500, 300, P.blue, ka * (blue2 ? 1 : 0.45), { size: 34 });
    badge(c, '黄光：关', 1500, 400, P.yellow, ka * (yellow2 ? 1 : 0.45), { size: 34, color: '#ffffff' });
    const spikes = []; for (let t = c1 + 1.5; t < c1 + 40; t += 0.13) { const p = (t - c1 - 1.5) % 6; if (p < 2.5) spikes.push(t + hash(t * 10) * 0.05); else if (!(p >= 3 && p < 5.5) && hash(t * 7) > 0.6) spikes.push(t); }
    const bm = [], ym = []; for (let t = c1 + 1.5; t < c1 + 40; t += 0.25) { const p = (t - c1 - 1.5) % 6; if (p < 2.5) bm.push(t); else if (p >= 3 && p < 5.5) ym.push(t); }
    trace(c, 1220, 900, 560, 130, st, spikes, { a: ka, span: 6, col: '#ffffff', marks: bm, markCol: P.blue, label: '神经元活动' });
    trace(c, 1220, 900, 560, 130, st, [], { a: 0, marks: ym, markCol: P.yellow, span: 6 });
    for (const m of ym) { const dxm = (m - (st - 6)) / 6; if (dxm >= 0 && dxm <= 1) line(c, [[1220 + dxm * 560, 922], [1220 + dxm * 560, 936]], P.yellow, 4, ka); }
  }
};

S.brain = (c, st, sp) => {
  bg(c, st, { neb: 0.5 });
  const bx = 900, by = 500, bs = 1.55;
  c.save(); c.translate(bx, by); c.scale(bs, bs);
  brainExtras(c, 1);
  brainPath(c); c.fillStyle = 'rgba(120,140,190,0.10)'; c.fill();
  c.save(); brainPath(c); c.clip();
  for (let k = 0; k < 26; k++) { const pts = []; for (let j = 0; j <= 30; j++) { const u = j / 30; pts.push([-300 + u * 620, -200 + k * 18 + Math.sin(u * 22 + k * 1.3) * 9 + noise2(u * 4, k) * 10]); } line(c, pts, '#9fb3dd', 1.4, 0.22); }
  c.restore();
  brainPath(c); c.strokeStyle = 'rgba(210,225,255,0.85)'; c.lineWidth = 2.5; c.stroke();
  c.restore();
  const gp = (x, y) => [bx + x * bs, by + y * bs];
  // 0: the recipe
  const a0 = win(st, sp.cue(0) - 0.4, sp.cue(1) + 0.3, 0.8);
  ['基因', '细胞“听懂”光', '光指挥细胞'].forEach((s, i) => { badge(c, s, 520 + i * 440, 920 - 0, i === 2 ? P.blue : i === 1 ? P.violet : P.green, a0 * smooth(sp.cue(0) + i * 1.5, sp.cue(0) + 1 + i * 1.5, st), { size: 32 }); if (i < 2) text(c, '→', 740 + i * 440, 920, { size: 36, color: '#fff', alpha: a0 * smooth(sp.cue(0) + i * 1.5 + 1, sp.cue(0) + i * 1.5 + 2, st) }); });
  text(c, '光遗传学', bx, 150, { size: 64, weight: 900, color: '#ffffff', alpha: smooth(sp.cue(0), sp.cue(0) + 1, st), spacing: 16, glow: 26, glowColor: P.blue });
  // 1: circuits lighting up
  const regs = [['记忆', 0, 70, P.blue, 1450, 300], ['恐惧', -70, 78, P.red, 1450, 400], ['奖赏', -120, 20, P.gold, 1450, 500], ['睡眠', -40, 40, P.violet, 1450, 600], ['帕金森病', -20, -10, P.teal, 1450, 700], ['抑郁症', -210, -50, '#ff9ad0', 1450, 800]];
  regs.forEach(([s, x, y, col, lx, ly], i) => {
    const a = smooth(sp.cue(1) + 0.8 + i * 1.6, sp.cue(1) + 1.6 + i * 1.6, st) * (1 - smooth(sp.cue(2) - 0.5, sp.cue(2) + 0.5, st));
    if (a <= 0) return;
    const [px, py] = gp(x, y);
    additive(c, () => glow(c, px, py, 90, col, a * (0.7 + 0.3 * Math.sin(st * 5 + i))));
    dot(c, px, py, 7, '#ffffff', a);
    line(c, [[px, py], [lx - 20, ly]], col, 1.5, a * 0.7);
    text(c, s, lx, ly, { size: 36, weight: 800, color: col, alpha: a, align: 'left', glow: 12, glowColor: col });
  });
  // 2: correlation -> causation
  const a2 = smooth(sp.cue(2), sp.cue(2) + 1, st);
  if (a2 > 0) {
    c.fillStyle = `rgba(2,6,15,${0.55 * a2})`; c.fillRect(0, 0, W, H);
    text(c, '相关', 640, 520, { size: 110, weight: 900, color: '#9aa6bf', alpha: a2, spacing: 20 });
    const ar = ease.out(clamp((st - sp.cue(2) - 0.8) / 1));
    line(c, [[800, 520], [lerp(800, 1100, ar), 520]], P.gold, 5, a2, 12);
    L.arrowHead(c, lerp(800, 1100, ar) + 18, 520, 0, 34, P.gold, a2 * ar);
    text(c, '因果', 1300, 520, { size: 110, weight: 900, color: '#ffffff', alpha: smooth(sp.cue(2) + 1.5, sp.cue(2) + 2.3, st), spacing: 20, glow: 30, glowColor: P.blue });
  }
};

S.retina = (c, st, sp) => {
  bg(c, st, { neb: 0.4 });
  const ex = 1040, ey = 520, R = 300;
  eyeball(c, ex, ey, R, smooth(0.2, 1.2, st));
  // goggles projecting amber light
  const ga = smooth(sp.cue(1) + 4, sp.cue(1) + 5, st);
  const gx = ex - R - 260;
  alpha(c, ga, () => { c.strokeStyle = '#e8eef8'; c.lineWidth = 4; L.rrect(c, gx - 60, ey - 50, 120, 100, 20); c.stroke(); c.fillStyle = 'rgba(255,170,80,0.25)'; c.fill(); });
  text(c, '特制眼镜', gx, ey + 100, { size: 28, color: '#ffd8b0', alpha: ga });
  // light rays into the eye
  const rays = ga > 0 ? '#ffb35c' : '#fff6d8';
  for (let k = -2; k <= 2; k++) { const y0 = ey + k * 40; const pts = [[gx + 60, y0], [ex - R * 0.82, y0 * 0.6 + ey * 0.4], [ex + R * 0.95, ey - k * 60]]; additive(c, () => line(c, pts, rays, 2, 0.35 + 0.4 * ga * (0.5 + 0.5 * Math.sin(st * 8 + k)), 8)); }
  // retina along the back wall: photoreceptors gone (grey), ganglion cells made light-sensitive (amber)
  for (let k = 0; k < 34; k++) {
    const a = -1.05 + k / 33 * 2.1; const px = ex + Math.cos(a) * (R - 20), py = ey + Math.sin(a) * (R - 20);
    const qx = ex + Math.cos(a) * (R - 52), qy = ey + Math.sin(a) * (R - 52);
    line(c, [[px, py], [ex + Math.cos(a) * (R - 6), ey + Math.sin(a) * (R - 6)]], '#6c7280', 4, 0.7 * smooth(0.5, 1.5, st));
    const g = smooth(sp.cue(1) + 1 + k * 0.05, sp.cue(1) + 2 + k * 0.05, st);
    dot(c, qx, qy, 7, g > 0 ? mixHex('#8a93a6', P.amber, g) : '#8a93a6', 0.9 * smooth(0.5, 1.5, st));
    if (g > 0 && ga > 0) additive(c, () => glow(c, qx, qy, 26, P.amber, ga * (0.5 + 0.5 * Math.sin(st * 8 + k))));
  }
  callout(c, ex + R * 0.95 * Math.cos(-0.7), ey + R * 0.95 * Math.sin(-0.7), 1560, 200, '感光细胞已凋亡', '视网膜色素变性', '#9aa3b5', smooth(sp.cue(0) + 1, sp.cue(0) + 2, st));
  callout(c, ex + (R - 52) * Math.cos(0.5), ey + (R - 52) * Math.sin(0.5), 1560, 760, '基因治疗', '让其他视网膜细胞感光', P.amber, smooth(sp.cue(1) + 1.5, sp.cue(1) + 2.5, st));
  // what the patient begins to see
  const va = smooth(sp.cue(1) + 8, sp.cue(1) + 10, st);
  if (va > 0) {
    const cx0 = 300, cy0 = 300;
    alpha(c, va, () => { c.fillStyle = 'rgba(0,0,0,0.5)'; L.rrect(c, cx0 - 170, cy0 - 140, 340, 280, 20); c.fill(); c.strokeStyle = 'rgba(255,220,180,0.5)'; c.stroke(); });
    const r = rng(9);
    const outline = [];
    for (let i = 0; i <= 40; i++) { const u = i / 40; outline.push(u < 0.5 ? [lerp(-70, -55, u * 2), lerp(-60, 70, u * 2)] : [lerp(-55, 55, (u - 0.5) * 2), 70]); }
    for (let i = 0; i <= 20; i++) outline.push([lerp(55, 70, i / 20), lerp(70, -60, i / 20)]);
    for (let i = 0; i <= 18; i++) { const a = -Math.PI / 2 + i / 18 * Math.PI; outline.push([70 + Math.cos(a) * 32, Math.sin(a) * 32]); }
    for (let i = 0; i <= 30; i++) outline.push([lerp(-140, 140, i / 30), 82]);
    outline.forEach(([x, y], i) => { if (r() < va * 1.1) dot(c, cx0 + x + (r() - 0.5) * 5, cy0 + y - 10 + (r() - 0.5) * 5, 3.2, '#ffd8a8', 0.95 * va); });
    for (let i = 0; i < 60; i++) dot(c, cx0 + (r() - 0.5) * 300, cy0 + (r() - 0.5) * 240, 2, '#ffd8a8', 0.2 * va);
    text(c, '看见、找到、触碰', cx0, cy0 + 180, { size: 30, weight: 700, color: '#ffe6c8', alpha: va, spacing: 4 });
  }
  text(c, '2021 · 首例临床报告', 300, 120, { size: 32, weight: 800, color: '#ffffff', alpha: smooth(sp.cue(1), sp.cue(1) + 1, st) * (1 - va), glow: 12, glowColor: P.amber });
};

S.finale = (c, st, sp) => {
  bg(c, st, { neb: 0.7 });
  netDraw(c, st, 0.75, 1.2, { pulse: P.blue, cell: '#b9d4ff', edge: '#4aa8ff' });
  additive(c, () => glow(c, W / 2, 380, 700, P.blue, 0.25));
  chlamy(c, 360 + st * 8, 820 - st * 6, 0.55, st, { rot: 0.6 });
};

export default { palette: P, init, scenes: S };
