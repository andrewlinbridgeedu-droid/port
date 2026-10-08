// 2026 文学奖 · 在残缺处写作 —— 安妮·卡森
import * as L from '../lib.js';
import { drawTitle } from '../core.js';
const { W, H, TAU, clamp, lerp, smooth, ease, prog, glow, dot, line, text, reveal, F, rgba, fill, vgrad,
  additive, alpha, callout, badge, partial, rng, noise2, fbm, drawStars, makeStars, win, hash, mixHex } = L;

const P = { gold: '#d8b26a', paper: '#ece2cc', papyrus: '#d9bf8c', ink: '#2a1d12', red: '#c8452d', redHi: '#ff6a4a', blue: '#7fa6d8', white: '#f5eee2', honey: '#f0c06a', bitter: '#6fa39a' };
const GREEK = ['ποικιλόθρον᾽ ἀθανάτ᾽ Ἀφρόδιτα', 'παῖ Δίος δολόπλοκε λίσσομαί σε', 'Ἔρος δηὖτέ μ᾽ ὀ λυσιμέλης δόνει', 'γλυκύπικρον ἀμάχανον ὄρπετον', 'μή μ᾽ ἄσαισι μηδ᾽ ὀνίαισι δάμνα', 'πότνια θῦμον'];
let motes, frags = [], grain;

function init() {
  motes = makeStars(260, 61);
  for (let i = 0; i < 9; i++) frags.push(makeFragment(100 + i, 380 + (i % 3) * 60, 260 + (i % 2) * 70));
  grain = document.createElement('canvas'); grain.width = 480; grain.height = 270;
  const g = grain.getContext('2d'); const img = g.createImageData(480, 270); const r = rng(3);
  for (let i = 0; i < img.data.length; i += 4) { const v = 120 + r() * 60; img.data[i] = v; img.data[i + 1] = v * 0.92; img.data[i + 2] = v * 0.8; img.data[i + 3] = 255; }
  g.putImageData(img, 0, 0);
}
function makeFragment(seed, w, h) {
  const c = document.createElement('canvas'); c.width = w; c.height = h;
  const g = c.getContext('2d'); const r = rng(seed);
  const pts = []; const n = 46;
  for (let i = 0; i < n; i++) {
    const a = i / n * TAU, ca = Math.cos(a), sa = Math.sin(a);
    const ex = Math.sign(ca) * Math.pow(Math.abs(ca), 0.35), ey = Math.sign(sa) * Math.pow(Math.abs(sa), 0.35);
    const jag = 1 - 0.18 * r() - 0.12 * (noise2(seed + i * 0.4, 1) * 0.5 + 0.5);
    pts.push([w / 2 + ex * w * 0.46 * jag, h / 2 + ey * h * 0.44 * jag]);
  }
  g.beginPath(); pts.forEach(([x, y], i) => (i ? g.lineTo(x, y) : g.moveTo(x, y))); g.closePath();
  g.save(); g.clip();
  const gr = g.createLinearGradient(0, 0, w, h); gr.addColorStop(0, '#e3cb98'); gr.addColorStop(1, '#bf9f68'); g.fillStyle = gr; g.fillRect(0, 0, w, h);
  for (let y = 0; y < h; y += 3) { g.strokeStyle = `rgba(110,80,40,${0.05 + r() * 0.08})`; g.lineWidth = 1 + r(); g.beginPath(); g.moveTo(0, y + r() * 2); g.lineTo(w, y + r() * 2); g.stroke(); }
  for (let x = 0; x < w; x += 7) { g.strokeStyle = `rgba(90,60,30,${0.03 + r() * 0.05})`; g.beginPath(); g.moveTo(x, 0); g.lineTo(x + r() * 3, h); g.stroke(); }
  g.fillStyle = 'rgba(42,26,14,0.82)'; g.font = `italic 400 ${22 + (seed % 3) * 2}px "Noto Serif"`; g.textBaseline = 'middle';
  for (let k = 0; k < 6; k++) {
    let s = GREEK[(seed + k) % GREEK.length];
    s = [...s].map(ch => (r() < 0.16 ? ' ' : ch)).join('');
    g.fillText(s, 16 + r() * 20 - 30 * (k % 2), 36 + k * 40);
  }
  g.globalCompositeOperation = 'destination-out';
  for (let k = 0; k < 4; k++) { const x = r() * w, y = r() * h, rr = 8 + r() * 26; g.beginPath(); for (let j = 0; j < 12; j++) { const a = j / 12 * TAU; const q = rr * (0.6 + 0.6 * r()); j ? g.lineTo(x + Math.cos(a) * q, y + Math.sin(a) * q) : g.moveTo(x + Math.cos(a) * q, y + Math.sin(a) * q); } g.closePath(); g.fill(); }
  g.restore();
  g.strokeStyle = 'rgba(90,60,30,0.6)'; g.lineWidth = 2; g.beginPath(); pts.forEach(([x, y], i) => (i ? g.lineTo(x, y) : g.moveTo(x, y))); g.closePath(); g.stroke();
  return c;
}
function frag(c, i, x, y, s, rot, a = 1) {
  if (a <= 0.003) return;
  const f = frags[i % frags.length];
  c.save(); c.translate(x, y); c.rotate(rot); c.globalAlpha *= a;
  c.shadowColor = 'rgba(0,0,0,0.6)'; c.shadowBlur = 30; c.shadowOffsetY = 10;
  c.drawImage(f, -f.width * s / 2, -f.height * s / 2, f.width * s, f.height * s);
  c.restore();
}
function bg(c, st, o = {}) {
  fill(c, vgrad(c, [[0, '#0d0a08'], [0.6, '#16110c'], [1, '#1d150e']]));
  alpha(c, 0.06, () => c.drawImage(grain, 0, 0, W, H));
  additive(c, () => glow(c, W * 0.5, H * 0.45, 900, o.warm ?? '#5a3a1c', 0.25));
  // floating ink motes
  for (const m of motes) { const x = (m.x + st * 6 * m.sp) % W, y = (m.y - st * 4 * m.sp + H) % H; dot(c, x, y, m.r * 0.9, '#e8d2a8', 0.25 * m.a); }
}
function paperBg(c, st) {
  fill(c, vgrad(c, [[0, '#efe6d2'], [1, '#e2d5ba']]));
  alpha(c, 0.12, () => c.drawImage(grain, 0, 0, W, H));
}
function bookCard(c, x, y, title, sub, year, col, a = 1, o = {}) {
  if (a <= 0.003) return;
  const w = o.w ?? 300, h = o.h ?? 400;
  const e = ease.out(clamp(a));
  c.save(); c.translate(x, y + (1 - e) * 30); c.globalAlpha *= a;
  c.shadowColor = 'rgba(0,0,0,0.6)'; c.shadowBlur = 40; c.shadowOffsetY = 16;
  const g = c.createLinearGradient(-w / 2, 0, w / 2, 0); g.addColorStop(0, mixHex(col, '#000000', 0.45)); g.addColorStop(0.08, col); g.addColorStop(1, mixHex(col, '#000000', 0.2));
  c.fillStyle = g; L.rrect(c, -w / 2, -h / 2, w, h, 8); c.fill();
  c.shadowBlur = 0; c.shadowOffsetY = 0;
  c.strokeStyle = 'rgba(255,240,210,0.5)'; c.lineWidth = 1.5; c.strokeRect(-w / 2 + 22, -h / 2 + 22, w - 44, h - 44);
  c.restore();
  const ty = y - h * 0.18;
  text(c, title, x, ty, { size: o.tsize ?? 40, font: F.kai, weight: 700, color: '#fff6e6', alpha: a, spacing: 4 });
  if (o.en) text(c, o.en, x, ty + (o.tsize ?? 40) * 0.6 + 22, { size: 22, font: F.latin, italic: true, weight: 500, color: '#f3e3c2', alpha: a * 0.9 });
  text(c, sub, x, y + h * 0.16, { size: o.ssize ?? 24, font: F.kai, color: '#f5e8d0', alpha: a * 0.95 });
  text(c, year, x, y + h * 0.33, { size: 24, font: F.latin, weight: 600, color: '#f3e3c2', alpha: a * 0.85, spacing: 4 });
}
function scroll(c, x, y, s, a = 1) {
  alpha(c, a, () => {
    c.save(); c.translate(x, y); c.scale(s, s);
    const g = c.createLinearGradient(-20, 0, 20, 0); g.addColorStop(0, '#8a6a3a'); g.addColorStop(0.5, '#e6cf9c'); g.addColorStop(1, '#8a6a3a');
    c.fillStyle = g; L.rrect(c, -22, -90, 44, 180, 18); c.fill();
    c.fillStyle = '#5a3a1c'; L.rrect(c, -6, -104, 12, 208, 6); c.fill();
    c.strokeStyle = 'rgba(80,50,20,0.5)'; for (let k = -70; k < 80; k += 22) { c.beginPath(); c.moveTo(-20, k); c.quadraticCurveTo(0, k + 6, 20, k); c.stroke(); }
    c.restore();
  });
}
function wingedFigure(c, x, y, s, st, o = {}) {
  const a = o.a ?? 1; if (a <= 0) return;
  c.save(); c.translate(x, y); c.scale(s, s); c.globalAlpha *= a;
  const flap = Math.sin(st * (o.flap ?? 2)) * 0.12;
  const red = c.createLinearGradient(0, -200, 0, 200); red.addColorStop(0, '#ff7a55'); red.addColorStop(1, '#8a1c10');
  additive(c, () => glow(c, 0, -20, 300, '#ff4a2a', 0.3));
  for (const side of [-1, 1]) {
    c.save(); c.scale(side, 1); c.rotate(-flap);
    c.fillStyle = red; c.beginPath(); c.moveTo(10, -60);
    c.bezierCurveTo(120, -220, 300, -200, 360, -120); c.bezierCurveTo(300, -110, 260, -60, 280, -20);
    c.bezierCurveTo(220, -40, 180, 0, 190, 40); c.bezierCurveTo(120, 10, 60, 20, 20, 20); c.closePath(); c.fill();
    c.strokeStyle = 'rgba(255,200,170,0.35)'; c.lineWidth = 2; for (let k = 0; k < 5; k++) { c.beginPath(); c.moveTo(20, -30); c.quadraticCurveTo(140 + k * 30, -150 + k * 30, 240 + k * 20, -120 + k * 30); c.stroke(); }
    c.restore();
  }
  c.fillStyle = red; c.beginPath(); c.ellipse(0, 20, 46, 110, 0, 0, TAU); c.fill();
  c.beginPath(); c.arc(0, -110, 38, 0, TAU); c.fill();
  c.beginPath(); c.moveTo(-26, -140); c.lineTo(-40, -185); c.lineTo(-8, -146); c.moveTo(26, -140); c.lineTo(40, -185); c.lineTo(8, -146); c.fill();
  c.restore();
}
function boy(c, x, y, s, st, a = 1) {
  if (a <= 0) return;
  c.save(); c.translate(x, y); c.scale(s, s); c.globalAlpha *= a;
  const flap = Math.sin(st * 3) * 0.1;
  for (const side of [-1, 1]) { c.save(); c.translate(side * 18, -90); c.scale(side, 1); c.rotate(-0.4 - flap); c.fillStyle = '#d9402a'; c.beginPath(); c.moveTo(0, 0); c.bezierCurveTo(40, -50, 90, -40, 100, -10); c.bezierCurveTo(70, -5, 50, 10, 0, 18); c.closePath(); c.fill(); c.restore(); }
  c.shadowColor = 'rgba(255,120,80,0.8)'; c.shadowBlur = 18;
  c.fillStyle = '#1c130e';
  c.beginPath(); c.arc(0, -150, 26, 0, TAU); c.fill();
  c.beginPath(); c.moveTo(-34, -115); c.lineTo(34, -115); c.lineTo(28, 10); c.lineTo(-28, 10); c.closePath(); c.fill();
  c.fillRect(-24, 10, 18, 90); c.fillRect(6, 10, 18, 90);
  c.shadowBlur = 0;
  // camera held at chest
  c.fillStyle = '#3a3028'; L.rrect(c, -30, -78, 60, 38, 6); c.fill();
  c.strokeStyle = 'rgba(255,200,160,0.7)'; c.lineWidth = 1.5; c.stroke();
  c.fillStyle = '#c8b8a0'; c.beginPath(); c.arc(0, -59, 11, 0, TAU); c.fill();
  c.restore();
}
function volcano(c, x, y, s, st, a = 1) {
  c.save(); c.translate(x, y); c.scale(s, s); c.globalAlpha *= a;
  additive(c, () => { glow(c, 0, -280, 260, '#ff5a20', 0.45 + 0.1 * Math.sin(st * 2)); });
  const g = c.createLinearGradient(0, -280, 0, 60); g.addColorStop(0, '#3a1a10'); g.addColorStop(1, '#0d0806');
  c.fillStyle = g; c.beginPath(); c.moveTo(-620, 60); c.lineTo(-90, -270); c.lineTo(-40, -280); c.lineTo(40, -280); c.lineTo(90, -270); c.lineTo(620, 60); c.closePath(); c.fill();
  c.strokeStyle = 'rgba(255,110,50,0.5)'; c.lineWidth = 3; c.beginPath(); c.moveTo(-40, -280); c.quadraticCurveTo(-60, -150, -120, -40); c.stroke();
  for (let i = 0; i < 14; i++) { const u = (st * 0.2 + hash(i)) % 1; additive(c, () => glow(c, (hash(i + 4) - 0.5) * 160 + Math.sin(u * 6 + i) * 30, -290 - u * 260, 30 * (1 - u) + 6, '#ff9a6a', 0.35 * (1 - u))); }
  c.restore();
}
function polaroid(c, x, y, rot, s, st, a = 1, seed = 0) {
  if (a <= 0) return;
  c.save(); c.translate(x, y); c.rotate(rot); c.scale(s, s); c.globalAlpha *= a;
  c.shadowColor = 'rgba(0,0,0,0.6)'; c.shadowBlur = 20; c.fillStyle = '#efe7d8'; c.fillRect(-80, -90, 160, 190); c.shadowBlur = 0;
  const g = c.createLinearGradient(0, -74, 0, 70); g.addColorStop(0, ['#b8402a', '#5a2a3a', '#a85a2a'][seed % 3]); g.addColorStop(1, '#2a1410');
  c.fillStyle = g; c.fillRect(-68, -78, 136, 136);
  c.fillStyle = 'rgba(255,200,150,0.35)'; c.beginPath(); c.arc(-20 + seed * 9 % 40, -20, 18, 0, TAU); c.fill();
  c.restore();
}

// ---------------------------------------------------------------- scenes
const S = {};
S.title = (c, st) => {
  bg(c, st);
  for (let i = 0; i < 7; i++) { const x = (hash(i) * W + st * (8 + i * 2)) % (W + 400) - 200, y = 140 + hash(i + 9) * 800; frag(c, i, x, y, 0.55 + hash(i + 3) * 0.3, (hash(i + 5) - 0.5) * 0.6 + Math.sin(st * 0.2 + i) * 0.05, 0.22); }
  drawTitle(c, st, { glow: P.red });
};

S.papyrus = (c, st, sp) => {
  bg(c, st);
  // nine books (scrolls)
  const a0 = smooth(sp.cue(0), sp.cue(0) + 1, st) * (1 - smooth(sp.cue(1) - 0.2, sp.cue(1) + 1.2, st));
  for (let i = 0; i < 9; i++) scroll(c, 560 + i * 100, 480, 1.3, a0 * smooth(sp.cue(0) + i * 0.25, sp.cue(0) + 0.5 + i * 0.25, st));
  text(c, '萨福 · 九卷诗', W / 2, 250, { size: 44, font: F.kai, weight: 700, color: '#f3e3c2', alpha: a0, spacing: 10 });
  text(c, '约公元前 600 年 · 莱斯博斯岛', W / 2, 310, { size: 26, color: '#d9c7a4', alpha: a0, spacing: 4 });
  // what survives: fragments
  const a1 = smooth(sp.cue(1), sp.cue(1) + 1.2, st) * (1 - smooth(sp.cue(2) - 0.5, sp.cue(2) + 0.6, st));
  if (a1 > 0) {
    const pos = [[420, 420, -0.2], [780, 330, 0.1], [1180, 420, 0.15], [1530, 360, -0.1], [600, 700, 0.08], [1050, 700, -0.12], [1450, 690, 0.2]];
    pos.forEach(([x, y, r], i) => frag(c, i, x + Math.sin(st * 0.3 + i) * 6, y + Math.cos(st * 0.25 + i) * 6, 0.85, r, a1 * smooth(sp.cue(1) + i * 0.3, sp.cue(1) + 0.6 + i * 0.3, st)));
    const k = smooth(sp.cue(1) + 3.5, sp.cue(1) + 4.5, st);
    badge(c, '一首完整的诗', 780, 175, P.gold, a1 * k, { size: 26 });
    badge(c, '撕裂的莎草纸', 420, 570, '#d9c7a4', a1 * smooth(sp.cue(1) + 4.5, sp.cue(1) + 5.3, st), { size: 24 });
    badge(c, '虫蛀的字句', 1180, 570, '#d9c7a4', a1 * smooth(sp.cue(1) + 5.5, sp.cue(1) + 6.3, st), { size: 24 });
    badge(c, '后人引用里的只言片语', 1450, 860, '#d9c7a4', a1 * smooth(sp.cue(1) + 6.5, sp.cue(1) + 7.3, st), { size: 24 });
  }
  // brackets on the page
  const a2 = smooth(sp.cue(2), sp.cue(2) + 1.2, st);
  if (a2 > 0) {
    const px = W / 2, py = 470, pw = 760, ph = 620;
    alpha(c, a2, () => { c.shadowColor = 'rgba(0,0,0,0.6)'; c.shadowBlur = 40; c.fillStyle = '#efe6d2'; c.fillRect(px - pw / 2, py - ph / 2, pw, ph); c.shadowBlur = 0; alpha(c, 0.1, () => c.drawImage(grain, px - pw / 2, py - ph / 2, pw, ph)); });
    const lines = [['', ']'], ['若非，冬天', ']'], ['', ']', '        ]'], ['', ']'], ['', ']', '      ]']];
    const imagine = smooth(sp.cue(3), sp.cue(3) + 2, st);
    lines.forEach((ln, i) => {
      const y = py - 200 + i * 95; const la = a2 * smooth(sp.cue(2) + 0.6 + i * 0.5, sp.cue(2) + 1.2 + i * 0.5, st);
      text(c, ']', px - 260, y, { size: 58, font: F.serif, weight: 400, color: '#3a2a1a', alpha: la });
      if (ln[0]) text(c, ln[0], px - 220, y, { size: 50, font: F.kai, weight: 700, color: '#2a1d12', alpha: la, align: 'left', spacing: 6 });
      if (ln[2]) text(c, ']', px + 200, y, { size: 58, font: F.serif, color: '#3a2a1a', alpha: la });
      // imagination blooming inside the gaps
      if (imagine > 0 && !ln[0]) additive(c, () => { for (let k = 0; k < 7; k++) { const gx = px - 180 + k * 55 + Math.sin(st * 1.5 + k + i) * 10, gy = y + Math.cos(st * 1.2 + k * 2 + i) * 14; glow(c, gx, gy, 22, k % 2 ? P.gold : P.blue, imagine * la * 0.7); } });
    });
    text(c, '（方括号：原稿在此残缺 · 示意）', px, py + ph / 2 - 40, { size: 22, color: '#6a5a44', alpha: a2 });
    text(c, '想象的自由空间', 1620, 470, { size: 40, font: F.kai, weight: 700, color: P.gold, alpha: imagine, spacing: 6, glow: 16, glowColor: P.gold });
  }
};

S.liubai = (c, st, sp) => {
  paperBg(c, st);
  // ink-wash mountains
  const layers = [[430, 160, 0.55, 0.0016], [520, 120, 0.35, 0.0022], [600, 90, 0.2, 0.003]];
  layers.forEach(([base, amp, a, f], li) => {
    const pts = []; for (let x = -20; x <= W + 20; x += 12) pts.push([x, base - Math.abs(fbm(x * f + li * 7 + st * 0.01, li * 3, 4)) * amp * 2.2 - (li === 0 ? Math.exp(-Math.pow((x - 520) / 260, 2)) * 220 : 0)]);
    const g = c.createLinearGradient(0, base - amp * 2.5, 0, base + 220); g.addColorStop(0, `rgba(30,24,18,${a})`); g.addColorStop(0.55, `rgba(30,24,18,${a * 0.35})`); g.addColorStop(1, 'rgba(30,24,18,0)');
    c.fillStyle = g; c.beginPath(); c.moveTo(pts[0][0], pts[0][1]); pts.forEach(p => c.lineTo(p[0], p[1])); c.lineTo(W + 20, base + 260); c.lineTo(-20, base + 260); c.closePath(); c.fill();
  });
  // a lone boat on empty water
  const bx = 1180 + st * 6, by = 780;
  c.fillStyle = 'rgba(30,24,18,0.85)'; c.beginPath(); c.moveTo(bx - 60, by); c.quadraticCurveTo(bx, by + 22, bx + 60, by); c.closePath(); c.fill();
  c.fillRect(bx - 6, by - 26, 10, 24); c.beginPath(); c.arc(bx - 1, by - 32, 8, 0, TAU); c.fill();
  line(c, [[bx + 10, by - 20], [bx + 70, by + 18]], 'rgba(30,24,18,0.8)', 2, 1);
  for (let k = 1; k <= 3; k++) line(c, [[bx - 60 - k * 30, by + 8 + k * 6], [bx + 60 + k * 30, by + 8 + k * 6]], 'rgba(30,24,18,0.25)', 1.2, 1 - k * 0.25);
  // seal
  const sa = smooth(1.2, 2.2, st);
  alpha(c, sa * 0.9, () => { c.fillStyle = '#b8321e'; L.rrect(c, 1580, 210, 110, 210, 8); c.fill(); });
  text(c, '留', 1635, 270, { size: 76, font: F.brush, color: '#f6ead8', alpha: sa });
  text(c, '白', 1635, 360, { size: 76, font: F.brush, color: '#f6ead8', alpha: sa });
};

S.bittersweet = (c, st, sp) => {
  bg(c, st, { warm: '#5a3a24' });
  const c0 = sp.cue(0);
  const split = ease.inOut(clamp((st - c0 - 2.2) / 1.6));
  const ga = smooth(c0, c0 + 1.2, st) * (1 - smooth(sp.cue(2) - 0.5, sp.cue(2) + 0.5, st));
  if (ga > 0) {
    text(c, 'γλυκύ', W / 2 - 140 - split * 260, 330, { size: 92, font: F.greek, italic: true, color: P.honey, alpha: ga, glow: 20, glowColor: P.honey, align: 'right' });
    text(c, 'πικρον', W / 2 - 140 + split * 260, 330, { size: 92, font: F.greek, italic: true, color: '#9fd0c6', alpha: ga, glow: 20, glowColor: P.bitter, align: 'left' });
    text(c, '萨福 · 残篇 130', W / 2, 220, { size: 26, color: '#d9c7a4', alpha: ga * (1 - split * 0.4), spacing: 4 });
    const ka = smooth(c0 + 3.4, c0 + 4.4, st);
    text(c, '甜', W / 2 - 400, 560, { size: 220, font: F.brush, color: P.honey, alpha: ga * ka, glow: 40, glowColor: P.honey });
    text(c, '苦', W / 2 + 400, 560, { size: 220, font: F.brush, color: '#8fc4b8', alpha: ga * ka, glow: 40, glowColor: P.bitter });
    text(c, '先甜，后苦', W / 2, 560, { size: 34, font: F.kai, color: '#efe2c8', alpha: ga * smooth(c0 + 4.5, c0 + 5.5, st), spacing: 8 });
  }
  const ba = win(st, sp.cue(1), sp.cue(2) + 0.6, 0.8);
  bookCard(c, W / 2, 770, '爱欲：苦甜', '卡森的第一部著作', '1986', '#6a2a2a', ba, { w: 520, h: 280, tsize: 40, en: 'Eros the Bittersweet' });
  // lack: reaching but never touching
  const la = smooth(sp.cue(2), sp.cue(2) + 1, st);
  if (la > 0) {
    const sx = 620, sy = 560, tx = 1300, ty = 460;
    additive(c, () => { glow(c, tx, ty, 90 + 10 * Math.sin(st * 2), P.honey, la); glow(c, tx, ty, 26, '#ffffff', la); });
    const reach = 0.82 + 0.06 * Math.sin(st * 1.3);
    const pts = []; for (let k = 0; k <= 40; k++) { const u = k / 40 * reach; pts.push([lerp(sx, tx, u), lerp(sy, ty, u) - Math.sin(u * Math.PI) * 140]); }
    c.save(); c.setLineDash([3, 10]); line(c, pts, '#f3e3c2', 3, la); c.restore();
    dot(c, sx, sy, 10, '#f3e3c2', la);
    text(c, '渴望', sx, sy + 50, { size: 30, font: F.kai, color: '#f3e3c2', alpha: la });
    text(c, '尚未拥有之物', tx, ty + 120, { size: 30, font: F.kai, color: P.honey, alpha: la });
    text(c, '爱欲 = 缺失', W / 2, 220, { size: 64, font: F.kai, weight: 700, color: '#ffffff', alpha: smooth(sp.cue(2) + 1.5, sp.cue(2) + 2.5, st), spacing: 10, glow: 18, glowColor: P.red });
  }
};

S.triangle = (c, st, sp) => {
  bg(c, st, { warm: '#4a2a2a' });
  const cx = W / 2, by = 720;
  // the two lovers approach, touch, and part again
  const cyc = (st % 9) / 9;
  const close = smooth(7.0, 9.0, st) * (1 - smooth(10.3, 12.3, st));
  const gap = lerp(330, 6, ease.inOut(close));
  const A = [cx - gap, by], B = [cx + gap, by], T = [cx, by - 420 * (gap / 330)];
  const desire = clamp((gap - 10) / 200);
  // energy along the triangle
  const tri = [A, T, B, A];
  line(c, tri, P.gold, 2.5, 0.4 + 0.5 * desire, 12 * desire);
  additive(c, () => { for (let k = 0; k < 12; k++) { const u = (st * 0.25 + k / 12) % 1; const seg = Math.floor(u * 3), f = u * 3 - seg; const p0 = tri[seg], p1 = tri[seg + 1]; glow(c, lerp(p0[0], p1[0], f), lerp(p0[1], p1[1], f), 18, P.honey, desire); } });
  glow(c, A[0], A[1], 50, '#ffd8a8', 0.8); glow(c, B[0], B[1], 50, '#ffb0a0', 0.8);
  dot(c, A[0], A[1], 10, '#fff', 1); dot(c, B[0], B[1], 10, '#fff', 1);
  text(c, '爱者', A[0] - 30, A[1] + 56, { size: 34, font: F.kai, weight: 700, color: '#f3e3c2', align: 'right' });
  text(c, '被爱者', B[0] + 30, B[1] + 56, { size: 34, font: F.kai, weight: 700, color: '#f3e3c2', align: 'left' });
  text(c, '二者之间的距离', T[0], T[1] - 44, { size: 34, font: F.kai, weight: 700, color: P.gold, alpha: desire, glow: 12, glowColor: P.gold });
  text(c, '距离一旦消失，渴望也随之熄灭', cx, 200, { size: 34, font: F.kai, color: '#e9dcc4', alpha: smooth(7.2, 8.0, st) * (1 - smooth(sp.cue(1) - 0.5, sp.cue(1), st)), spacing: 4 });
  const ka = smooth(sp.cue(1), sp.cue(1) + 1, st);
  text(c, '甜 · 想象中的拥有', 520, 200, { size: 40, font: F.kai, weight: 700, color: P.honey, alpha: ka, glow: 14, glowColor: P.honey });
  text(c, '苦 · 无法跨越的间隔', 1400, 200, { size: 40, font: F.kai, weight: 700, color: '#9fd0c6', alpha: smooth(sp.cue(1) + 2.5, sp.cue(1) + 3.5, st), glow: 14, glowColor: P.bitter });
};

S.red = (c, st, sp) => {
  bg(c, st, { warm: '#6a1e10' });
  const [c0, c1, c2, c3, c4] = [0, 1, 2, 3, 4].map(k => sp.cue(k));
  // 0: Stesichorus' fragments
  const a0 = win(st, c0 - 0.5, c1 + 0.5, 0.9);
  [[560, 460, -0.15], [960, 400, 0.08], [1360, 470, 0.18]].forEach(([x, y, r], i) => frag(c, i + 3, x, y, 0.9, r, a0 * smooth(c0 + i * 0.5, c0 + 0.8 + i * 0.5, st)));
  text(c, '斯特西克鲁斯 · 关于革律翁的长诗', W / 2, 200, { size: 40, font: F.kai, weight: 700, color: '#f3e3c2', alpha: a0, spacing: 6 });
  text(c, '约公元前 6 世纪 · 残篇', W / 2, 260, { size: 26, color: '#d9c7a4', alpha: a0, spacing: 4 });
  // 1: the myth – a monster shot, reduced to a footnote
  const a1 = win(st, c1, c2 + 0.4, 0.8);
  if (a1 > 0) {
    const hit = c1 + 4.5;
    const shrink = ease.inOut(clamp((st - hit - 1) / 2.5));
    wingedFigure(c, lerp(1100, 1560, shrink), lerp(470, 760, shrink), lerp(1.0, 0.12, shrink), st, { a: a1 });
    const ax = lerp(-100, 1080, ease.in(clamp((st - c1 - 3.3) / 1.2)));
    if (st < hit + 0.6) line(c, [[ax - 220, 470], [ax, 470]], '#f3e3c2', 3, a1, 8);
    if (st > hit && st < hit + 0.6) additive(c, () => glow(c, 1080, 470, 200, '#ffffff', (1 - (st - hit) / 0.6) * a1));
    text(c, '革律翁：长着翅膀的红色怪物', 520, 250, { size: 36, font: F.kai, weight: 700, color: '#ffb6a0', alpha: a1 * smooth(c1 + 1, c1 + 2, st) * (1 - shrink), spacing: 4 });
    text(c, '英雄赫拉克勒斯的一箭', 360, 540, { size: 30, font: F.kai, color: '#f3e3c2', alpha: a1 * smooth(c1 + 3, c1 + 3.6, st) * (1 - shrink) });
    const fa = smooth(0.7, 1, shrink) * a1;
    line(c, [[260, 820], [1660, 820]], '#d9c7a4', 1, fa * 0.6);
    text(c, '¹ 英雄伟业中的一个注脚', 260, 860, { size: 30, font: F.kai, color: '#d9c7a4', alpha: fa, align: 'left' });
  }
  // 2: the book
  const a2 = win(st, c2, c3 + 0.4, 0.8);
  bookCard(c, W / 2, 470, '红的自传', '一部诗体小说', '1998', '#8a2418', a2, { w: 440, h: 500, tsize: 54, en: 'Autobiography of Red' });
  // 3: modern Geryon: a boy with small red wings and a camera, by a volcano
  const a3 = smooth(c3, c3 + 1.2, st);
  if (a3 > 0) {
    volcano(c, 1420, 820, 1.0, st, a3);
    boy(c, 760, 790, 1.45, st, a3);
    const flash = ((st - c3) % 4) < 0.15 ? 1 - ((st - c3) % 4) / 0.15 : 0;
    if (flash > 0) additive(c, () => glow(c, 760, 790 - 59 * 1.45, 260, '#ffffff', flash * a3));
    [[420, 330, -0.2, 0], [1060, 280, 0.15, 1], [300, 640, 0.1, 2], [1150, 560, -0.12, 0]].forEach(([x, y, r, sd], i) => polaroid(c, x + Math.sin(st * 0.4 + i) * 8, y + Math.cos(st * 0.3 + i) * 8, r + Math.sin(st * 0.3 + i) * 0.03, 0.9, st, a3 * smooth(c3 + 1 + i * 0.8, c3 + 1.8 + i * 0.8, st), sd));
    text(c, '敏感、孤独、背生红色小翅膀的少年', W / 2, 150, { size: 30, font: F.kai, color: '#f3e3c2', alpha: a3 * smooth(c3 + 2, c3 + 3, st) * (1 - smooth(c4, c4 + 0.6, st)), spacing: 2 });
  }
  // 4: a voice of his own
  const a4 = smooth(c4, c4 + 1.2, st);
  if (a4 > 0) {
    c.fillStyle = `rgba(10,6,4,${0.55 * a4})`; c.fillRect(0, 0, W, H);
    text(c, '“', 440, 400, { size: 220, font: F.serif, weight: 900, color: P.redHi, alpha: a4, glow: 30, glowColor: P.red });
    text(c, '”', 1570, 640, { size: 220, font: F.serif, weight: 900, color: P.redHi, alpha: a4, glow: 30, glowColor: P.red });
    reveal(c, '怪物，有了自己的声音', W / 2, 500, clamp((st - c4 - 0.3) / 1.8), { size: 76, font: F.kai, weight: 700, color: '#ffffff', spacing: 10, glow: 24, glowColor: P.red, spread: 0.6 });
  }
};

S.genres = (c, st, sp) => {
  bg(c, st, { warm: '#2a3a5a' });
  const words = ['诗', '小说', '随笔', '论文', '翻译', '戏剧', '歌剧', '漫画', '讲演'];
  const a0 = smooth(0.5, 1.5, st) * (1 - smooth(sp.cue(1) - 0.5, sp.cue(1) + 0.5, st));
  const melt = ease.inOut(clamp((st - sp.cue(0) - 1) / 3.5));
  words.forEach((w, i) => {
    const ang = i / words.length * TAU + st * 0.08;
    const x0 = 360 + (i % 5) * 300, y0 = 330 + Math.floor(i / 5) * 260;
    const x = lerp(x0, W / 2 + Math.cos(ang) * 600, melt), y = lerp(y0, 500 + Math.sin(ang) * 300, melt);
    const bw = 90 + [...w].length * 50;
    alpha(c, a0 * (1 - melt), () => { c.strokeStyle = 'rgba(240,226,200,0.8)'; c.lineWidth = 2; c.strokeRect(x - bw / 2, y - 50, bw, 100); });
    text(c, w, x, y, { size: 52, font: F.kai, weight: 700, color: '#f3e3c2', alpha: a0, glow: 12 * melt, glowColor: P.blue });
    if (melt > 0.2) additive(c, () => glow(c, x, y, 110 * melt, i % 2 ? P.blue : P.gold, 0.2 * a0 * melt));
  });
  text(c, '边界，像水面一样柔软', W / 2, 500, { size: 44, font: F.kai, weight: 700, color: '#ffffff', alpha: a0 * smooth(0.6, 1, melt), spacing: 8, glow: 16, glowColor: P.blue });
  // the forms
  const cards = [['红的自传', '诗体小说', '1998', '#8a2418'], ['丈夫之美', '二十九支探戈里的虚构随笔', '2001', '#3a4a6a'], ['特洛伊妇女', '把古希腊悲剧画成漫画', '2021', '#5a4a2a'], ['漂浮', '二十二本散页小册 · 任意顺序', '2016', '#2a5a5a']];
  const a1 = smooth(sp.cue(1), sp.cue(1) + 0.8, st) * (1 - smooth(sp.cue(2) - 0.5, sp.cue(2) + 0.5, st));
  cards.forEach(([t, s, y, col], i) => bookCard(c, 330 + i * 420, 500, t, s, y, col, a1 * smooth(sp.cue(1) + i * 3, sp.cue(1) + 0.8 + i * 3, st), { w: 360, h: 420, tsize: 40, ssize: 22 }));
  // Float's loose booklets fanning out
  const fa = a1 * smooth(sp.cue(1) + 10, sp.cue(1) + 11.5, st);
  if (fa > 0) for (let k = 0; k < 22; k++) { const ang = -0.9 + k / 21 * 1.8; alpha(c, fa, () => { c.save(); c.translate(1590, 860); c.rotate(ang * ease.out(clamp((st - sp.cue(1) - 10) / 2))); c.fillStyle = mixHex('#2a5a5a', '#e9dcc8', (k % 5) / 6); c.fillRect(-10, -140, 20, 120); c.restore(); }); }
  // scholar + poet braided
  const a2 = smooth(sp.cue(2), sp.cue(2) + 1, st);
  if (a2 > 0) {
    for (const [col, ph, lab, ly] of [[P.gold, 0, '考据', 380], [P.blue, Math.PI, '想象', 660]]) {
      const pts = [[150, ly]]; for (let x = 260; x <= 1720; x += 10) { const u = (x - 260) / 1460; pts.push([x, 520 + Math.sin(u * 9 + ph + st * 1.5) * 110 * (1 - u * 0.85) + (ly - 520) * Math.max(0, 1 - u * 6)]); }
      line(c, partial(pts, clamp((st - sp.cue(2)) / 2.5)), col, 5, a2, 18);
      text(c, lab, 130, ly, { size: 38, font: F.kai, weight: 700, color: col, alpha: a2, align: 'right' });
    }
    text(c, '本是一体', 1720, 420, { size: 44, font: F.kai, weight: 700, color: '#ffffff', alpha: smooth(sp.cue(2) + 2.5, sp.cue(2) + 3.5, st), glow: 18, glowColor: P.gold, align: 'right' });
  }
};

S.nox = (c, st, sp) => {
  fill(c, vgrad(c, [[0, '#06070a'], [1, '#0f0d0c']]));
  alpha(c, 0.05, () => c.drawImage(grain, 0, 0, W, H));
  const [c0, c1, c2, c3] = [0, 1, 2, 3].map(k => sp.cue(k));
  // 0: title
  const a0 = win(st, c0 - 0.5, c1 + 0.6, 0.9);
  text(c, '夜', W / 2 - 120, 470, { size: 260, font: F.brush, color: '#e9e2d6', alpha: a0, glow: 30, glowColor: '#6a7aa0' });
  text(c, 'NOX', W / 2 + 170, 500, { size: 110, font: F.latin, weight: 600, color: '#bfc6d8', alpha: a0, spacing: 20 });
  text(c, '献给离世的哥哥', W / 2, 700, { size: 34, font: F.kai, color: '#d6d0c4', alpha: a0 * smooth(c0 + 2, c0 + 3, st), spacing: 8 });
  // 1: a box and its long folded page
  const a1 = win(st, c1, c2 + 0.5, 0.9);
  if (a1 > 0) {
    const open = ease.inOut(clamp((st - c1 - 1.2) / 5));
    const n = 11, pw = 150, x0 = 140, y0 = 470;
    // box
    alpha(c, a1, () => { c.fillStyle = '#2a2622'; c.fillRect(x0 - 10, y0 - 150, 170, 300); c.strokeStyle = 'rgba(200,190,170,0.5)'; c.strokeRect(x0 - 10, y0 - 150, 170, 300); });
    for (let i = n - 1; i >= 0; i--) {
      const k = clamp(open * n - i); if (k <= 0) continue;
      const px = x0 + i * pw * ease.out(k) + 10, fold = i % 2 ? 1 : -1;
      const skew = ((1 - k) * 0.6 + 0.12) * fold;
      c.save(); c.globalAlpha *= a1; c.translate(px, y0); c.transform(1, skew * 0.3, 0, 1, 0, 0);
      const g = c.createLinearGradient(0, 0, pw, 0); g.addColorStop(0, fold > 0 ? '#e6dccb' : '#d4c8b2'); g.addColorStop(1, fold > 0 ? '#d4c8b2' : '#e6dccb');
      c.fillStyle = g; c.fillRect(0, -140, pw, 280);
      // collage
      const r = rng(i + 5);
      if (i % 3 === 0) { c.fillStyle = '#6a5a48'; c.fillRect(20, -110, 100, 80); c.fillStyle = 'rgba(240,220,190,0.4)'; c.fillRect(30, -100, 80, 60); }
      if (i % 3 === 1) { c.strokeStyle = '#3a3026'; c.lineWidth = 1.5; for (let l = 0; l < 6; l++) { c.beginPath(); for (let x = 16; x < pw - 16; x += 6) c.lineTo(x, -90 + l * 24 + Math.sin(x * 0.3 + l * 2 + i) * 3); c.stroke(); } }
      if (i % 3 === 2) { c.fillStyle = '#efe6d2'; c.save(); c.rotate(0.06); c.fillRect(14, -60, 120, 90); c.restore(); c.fillStyle = '#2a2018'; c.font = 'italic 400 15px "Noto Serif"'; c.fillText(['multas per gentes', 'et multa per aequora', 'frater', 'ave atque vale'][i % 4], 20, -10); }
      c.restore();
    }
    text(c, '一只盒子 · 一整条折叠的长页', W / 2, 160, { size: 36, font: F.kai, weight: 700, color: '#e9e2d6', alpha: a1 * smooth(c1 + 0.5, c1 + 1.5, st), spacing: 6 });
    text(c, 'multas per gentes et multa per aequora vectus', W / 2, 800, { size: 34, font: F.latin, italic: true, weight: 500, color: '#d8cdb8', alpha: a1 * smooth(c1 + 7, c1 + 8, st), spacing: 2 });
    text(c, '卡图卢斯 · 第 101 首 · 悼亡兄', W / 2, 850, { size: 24, color: '#b9b0a0', alpha: a1 * smooth(c1 + 8, c1 + 9, st), spacing: 4 });
  }
  // 2: groping for the light switch, word by word
  const a2 = win(st, c2, c3 + 0.4, 0.9);
  if (a2 > 0) {
    const on = smooth(c2 + 5.5, c2 + 6.5, st);
    additive(c, () => glow(c, 1300, 420, 900, '#ffcf8a', 0.35 * on * a2));
    // wall switch
    alpha(c, a2, () => { c.fillStyle = '#d8cfbe'; L.rrect(c, 1270, 360, 60, 100, 8); c.fill(); c.fillStyle = '#8a8070'; L.rrect(c, 1290, 380 + (1 - on) * 30, 20, 30, 4); c.fill(); });
    // a groping hand: fingertips drifting toward the switch
    const hx = lerp(820, 1240, ease.inOut(clamp((st - c2 - 0.5) / 5))) + Math.sin(st * 2) * 20 * (1 - on), hy = 430 + Math.cos(st * 1.6) * 30 * (1 - on);
    // a reaching hand, index finger extended
    c.save(); c.translate(hx, hy); c.globalAlpha *= a2;
    c.fillStyle = '#2e2620'; c.strokeStyle = 'rgba(220,200,170,0.75)'; c.lineWidth = 2;
    const cap = (x, y, w, h, r) => { c.beginPath(); c.roundRect(x, y, w, h, r); c.fill(); c.stroke(); };
    cap(-300, -20, 190, 70, 30);
    cap(-170, -48, 120, 92, 34);
    for (let k = 0; k < 3; k++) cap(-82, -2 + k * 20, 44, 22, 11);
    cap(-90, -40, 96, 26, 13);
    c.save(); c.translate(-120, -44); c.rotate(-0.5); cap(0, -12, 60, 24, 12); c.restore();
    c.restore();
    const wordsLat = ['multas', 'per', 'gentes', 'et', 'multa', 'per', 'aequora', 'vectus'];
    wordsLat.forEach((w, i) => text(c, w, 300, 250 + i * 70, { size: 36, font: F.latin, italic: true, color: '#d8cdb8', alpha: a2 * smooth(c2 + i * 0.6, c2 + 0.5 + i * 0.6, st), align: 'left' }));
    wordsLat.forEach((w, i) => line(c, [[460, 252 + i * 70], [620 + hash(i) * 140, 252 + i * 70]], '#9a8e78', 1.5, a2 * 0.6 * smooth(c2 + i * 0.6 + 0.3, c2 + 0.8 + i * 0.6, st)));
    text(c, '翻译，像在房间里摸索电灯的开关', 1300, 760, { size: 36, font: F.kai, weight: 700, color: '#f3e8d6', alpha: a2 * smooth(c2 + 3, c2 + 4, st), spacing: 2 });
  }
  // 3: what cannot be translated
  const a3 = smooth(c3, c3 + 1, st);
  if (a3 > 0) {
    text(c, 'frater, ave atque vale', W / 2, 400, { size: 70, font: F.latin, italic: true, weight: 500, color: '#efe6d6', alpha: a3, spacing: 4, glow: 16, glowColor: '#6a7aa0' });
    const zh = ['兄', '弟', '，', '致', '意', '，', '也', '道', '别'];
    zh.forEach((ch, i) => { const miss = i === 3 || i === 7; const fade = miss ? 1 - smooth(c3 + 3, c3 + 5, st) : 1; text(c, ch, W / 2 - 240 + i * 60, 560, { size: 54, font: F.kai, weight: 700, color: '#d6cbb8', alpha: a3 * fade * smooth(c3 + 1 + i * 0.15, c3 + 1.5 + i * 0.15, st) }); });
    text(c, '有些失去，无法被完整地译出', W / 2, 700, { size: 32, font: F.kai, color: '#bfb4a2', alpha: smooth(c3 + 4, c3 + 5, st), spacing: 6 });
  }
};

S.dialogue = (c, st, sp) => {
  bg(c, st, { warm: '#4a3a1c' });
  const [c0, c1, c2, c3] = [0, 1, 2, 3].map(k => sp.cue(k));
  // 0: play
  const a0 = win(st, c0 - 0.4, c1 + 0.4, 0.8);
  if (a0 > 0) {
    ['游', '戏'].forEach((ch, i) => text(c, ch, W / 2 - 110 + i * 220, 470 + Math.sin(st * 3 + i * 1.7) * 18, { size: 200, font: F.brush, color: '#ffe9c4', alpha: a0, glow: 34, glowColor: P.gold }));
    text(c, '“在与古典传统的游戏式对话中”', W / 2, 700, { size: 36, font: F.kai, color: '#efe2c8', alpha: a0 * smooth(c0 + 1.5, c0 + 2.5, st), spacing: 4 });
  }
  // 1: column and the present, talking
  const a1 = win(st, c1, c2 + 0.4, 0.8);
  if (a1 > 0) {
    alpha(c, a1, () => {
      c.strokeStyle = P.gold; c.lineWidth = 3;
      const x = 420, y = 520;
      c.strokeRect(x - 70, y - 220, 140, 30); c.beginPath(); c.arc(x - 70, y - 190, 26, 0, TAU); c.arc(x + 70, y - 190, 26, 0, TAU); c.stroke();
      for (let k = -2; k <= 2; k++) { c.beginPath(); c.moveTo(x + k * 22, y - 165); c.lineTo(x + k * 22, y + 200); c.stroke(); }
      c.strokeRect(x - 80, y + 200, 160, 30);
    });
    text(c, '古典', 420, 820, { size: 34, font: F.kai, weight: 700, color: P.gold, alpha: a1 });
    alpha(c, a1, () => { const x = 1500, y = 520; c.strokeStyle = '#bcd0f0'; c.lineWidth = 3; c.strokeRect(x - 110, y - 200, 220, 400); for (let k = 0; k < 8; k++) { c.strokeRect(x - 100, y - 190 + k * 50, 16, 16); c.strokeRect(x + 84, y - 190 + k * 50, 16, 16); } c.fillStyle = 'rgba(190,210,240,0.12)'; c.fillRect(x - 70, y - 180, 140, 360); });
    text(c, '当下', 1500, 820, { size: 34, font: F.kai, weight: 700, color: '#bcd0f0', alpha: a1 });
    const lines = [['χαῖρε', P.gold, -1], ['你好', '#bcd0f0', 1], ['ἔρως', P.gold, -1], ['爱，仍是缺失', '#bcd0f0', 1]];
    lines.forEach(([s, col, side], i) => { const t0 = c1 + 0.8 + i * 1.5; const k = clamp((st - t0) / 1.4); if (k <= 0 || k >= 1) return; const x = side < 0 ? lerp(560, 1360, ease.inOut(k)) : lerp(1360, 560, ease.inOut(k)); text(c, s, x, 360 + i * 90, { size: 40, font: side < 0 ? F.greek : F.kai, italic: side < 0, color: col, alpha: a1 * Math.sin(k * Math.PI), glow: 12, glowColor: col }); });
    text(c, '古典：一位仍在说话的对谈者', W / 2, 200, { size: 38, font: F.kai, weight: 700, color: '#f3e3c2', alpha: a1 * smooth(c1 + 3, c1 + 4, st), spacing: 4 });
  }
  // 2: three pairings
  const a2 = win(st, c2, c3 + 0.4, 0.8);
  [['特洛伊的海伦', '玛丽莲·梦露'], ['赫拉克勒斯', '今天的剧场'], ['两千年前的词语', '今天的痛楚']].forEach(([l, r], i) => {
    const a = a2 * smooth(c2 + i * 2.6, c2 + 0.8 + i * 2.6, st), y = 330 + i * 170;
    text(c, l, 860, y, { size: 44, font: F.kai, weight: 700, color: P.gold, alpha: a, align: 'right' });
    line(c, [[W / 2 - 60, y - 8], [W / 2 + 60, y - 8]], '#ffffff', 2, a); L.arrowHead(c, W / 2 + 66, y - 8, 0, 14, '#ffffff', a);
    line(c, [[W / 2 - 60, y + 10], [W / 2 + 60, y + 10]], '#ffffff', 2, a); L.arrowHead(c, W / 2 - 66, y + 10, Math.PI, 14, '#ffffff', a);
    text(c, r, 1060, y, { size: 44, font: F.kai, weight: 700, color: '#bcd0f0', alpha: a, align: 'left' });
  });
  // 3: Lu Xun
  const a3 = smooth(c3, c3 + 1, st);
  if (a3 > 0) {
    bookCard(c, 640, 500, '故事新编', '鲁迅', '1936', '#3a2a1a', a3, { w: 380, h: 480, tsize: 56 });
    const sweep = clamp((st - c3 - 1.5) / 3);
    additive(c, () => { const x = lerp(900, 1700, sweep); glow(c, x, 480, 260, '#ffdca0', a3 * 0.35); });
    text(c, '旧的故事', 1300, 420, { size: 48, font: F.kai, weight: 700, color: '#d9c7a4', alpha: a3 * smooth(c3 + 1.5, c3 + 2.5, st), spacing: 8 });
    text(c, '被新的目光重新照亮', 1300, 520, { size: 48, font: F.kai, weight: 700, color: '#ffffff', alpha: a3 * smooth(c3 + 2.5, c3 + 3.5, st), spacing: 8, glow: 18, glowColor: P.gold });
  }
};

S.finale = (c, st, sp) => {
  bg(c, st, { warm: '#5a3a1c' });
  for (let i = 0; i < 8; i++) { const x = 200 + hash(i) * 1520 + Math.sin(st * 0.2 + i) * 30, y = 160 + hash(i + 5) * 760 + Math.cos(st * 0.17 + i) * 20; frag(c, i, x, y, 0.5 + hash(i + 2) * 0.3, (hash(i + 7) - 0.5) * 0.7, 0.35); }
  const open = ease.inOut(clamp(st / 4));
  const gap = lerp(40, 560, open);
  text(c, '[', W / 2 - gap, 470, { size: 420, font: F.serif, weight: 400, color: '#efe2c8', alpha: 0.85, glow: 20, glowColor: P.gold });
  text(c, ']', W / 2 + gap, 470, { size: 420, font: F.serif, weight: 400, color: '#efe2c8', alpha: 0.85, glow: 20, glowColor: P.gold });
  additive(c, () => { c.save(); c.translate(W / 2, 480); c.scale(gap / 300, 1); glow(c, 0, 0, 330, '#ffd9a0', 0.45 * open); c.restore(); });
};

export default { palette: P, init, scenes: S };
