// 2026 化学奖 · 镜中之谜 —— 不对称合成中的非线性效应与自催化
import * as L from '../lib.js';
import { drawTitle } from '../core.js';
const { W, H, TAU, clamp, lerp, smooth, ease, prog, glow, dot, line, text, reveal, F, rgba, fill, vgrad,
  additive, alpha, callout, badge, partial, rng, noise2, fbm, drawStars, makeStars, makeNebula, win, hash, mixHex } = L;

const P = { gold: '#e8c477', teal: '#3fe2c6', rose: '#ff6fa8', violet: '#a98bff', white: '#f6f2ff', grey: '#8a8798', red: '#ff5a5a' };
let stars, neb, handImg, handGlow, crowd = [], field = [];

function init() {
  stars = makeStars(700, 31);
  neb = makeNebula(['#2a1650', '#0f3a4a'], 6, 480, 270, 2.2, 0.85);
  // a stylised hand, palm facing the viewer, thumb to the right (a left hand)
  handImg = document.createElement('canvas'); handImg.width = 600; handImg.height = 820;
  const g = handImg.getContext('2d'); g.fillStyle = '#ffffff';
  const finger = (bx, by, len, w, rot) => { g.save(); g.translate(bx, by); g.rotate(rot); g.beginPath(); g.roundRect(-w / 2, -len, w, len + 40, w / 2); g.fill(); g.restore(); };
  g.beginPath(); g.roundRect(150, 360, 300, 340, 90); g.fill();
  finger(190, 440, 240, 55, -0.17); finger(262, 412, 300, 63, -0.06); finger(334, 410, 325, 66, 0.035); finger(404, 420, 285, 62, 0.13);
  finger(410, 650, 250, 70, 0.72);
  g.beginPath(); g.roundRect(195, 640, 200, 200, 30); g.fill();
  handGlow = document.createElement('canvas'); handGlow.width = 600; handGlow.height = 820;
  const hg = handGlow.getContext('2d'); hg.filter = 'blur(16px)'; hg.drawImage(handImg, 0, 0);
  // catalyst crowd: 30 of one hand, 20 of the other (ee = 20 %)
  const r = rng(12);
  for (let i = 0; i < 50; i++) crowd.push({ x: 360 + r() * 1200, y: 260 + r() * 470, h: i < 30 ? 1 : -1, ph: r() * TAU, sp: 0.4 + r() * 0.6 });
  // pair each minority molecule with its nearest majority partner
  const maj = crowd.filter(m => m.h > 0), min = crowd.filter(m => m.h < 0);
  const used = new Set();
  min.forEach(m => { let best = null, bd = 1e9; maj.forEach(M => { if (used.has(M)) return; const d = Math.hypot(M.x - m.x, M.y - m.y); if (d < bd) { bd = d; best = M; } }); used.add(best); m.mate = best; best.mate = m; });
  // dot field for the race
  const rf = rng(99);
  for (let j = 0; j < 30; j++) for (let i = 0; i < 64; i++) field.push({ x: 320 + i * 20.3, y: 300 + j * 17.5, r: rf(), d: rf() });
}

// ---------------------------------------------------------------- painters
function bg(c, st, o = {}) {
  fill(c, vgrad(c, [[0, '#07040f'], [0.55, '#0e0a22'], [1, '#160e2c']]));
  alpha(c, o.neb ?? 0.8, () => c.drawImage(neb, -50 + Math.sin(st * 0.04) * 25, -30, W + 100, H + 60));
  drawStars(c, stars, st, { dx: -st * 2, alpha: o.stars ?? 0.6 });
}
function mirrorLine(c, x, a = 1, st = 0) {
  if (a <= 0) return;
  additive(c, () => {
    const g = c.createLinearGradient(x - 60, 0, x + 60, 0);
    g.addColorStop(0, 'rgba(180,170,255,0)'); g.addColorStop(0.5, `rgba(200,190,255,${0.16 * a})`); g.addColorStop(1, 'rgba(180,170,255,0)');
    c.fillStyle = g; c.fillRect(x - 60, 0, 120, H);
  });
  line(c, [[x, 60], [x, H - 60]], '#d9d2ff', 1.5, a * 0.8, 10);
  for (let i = 0; i < 18; i++) { const y = ((hash(i) * H + st * 40 * (0.5 + hash(i + 3))) % H); glow(c, x, y, 10, '#ffffff', a * 0.5 * hash(i + 7)); }
}
// ball-and-stick chiral molecule: centre + 4 different groups
const TET = [[1, 1, 1], [1, -1, -1], [-1, 1, -1], [-1, -1, 1]].map(v => v.map(x => x / Math.sqrt(3)));
const GROUP = [{ col: '#ff5a5a', r: 0.36 }, { col: '#44d27a', r: 0.44 }, { col: '#4f8bff', r: 0.38 }, { col: '#f2f2f2', r: 0.24 }];
function ball(c, x, y, r, col, a = 1) {
  const g = c.createRadialGradient(x - r * 0.35, y - r * 0.4, r * 0.1, x, y, r);
  g.addColorStop(0, '#ffffff'); g.addColorStop(0.25, mixHex(col, '#ffffff', 0.25)); g.addColorStop(0.8, col); g.addColorStop(1, mixHex(col, '#000000', 0.55));
  alpha(c, a, () => { c.fillStyle = g; c.beginPath(); c.arc(x, y, r, 0, TAU); c.fill(); });
}
function molecule(c, x, y, s, yaw, pitch, mirror, o = {}) {
  const a = o.a ?? 1; if (a <= 0) return;
  const cy = Math.cos(yaw), sy = Math.sin(yaw), cp = Math.cos(pitch), sp2 = Math.sin(pitch);
  const tr = (v) => { let X = v[0] * (mirror ? -1 : 1), Y = v[1], Z = v[2]; let x1 = X * cy + Z * sy, z1 = -X * sy + Z * cy; let y1 = Y * cp - z1 * sp2; z1 = Y * sp2 + z1 * cp; const k = 1 / (1 - z1 * 0.18); return [x + x1 * s * k, y - y1 * s * k, z1, k]; };
  const C = tr([0, 0, 0]);
  const atoms = TET.map((v, i) => ({ p: tr(v.map(q => q * 1.25)), i }));
  if (o.glow) additive(c, () => glow(c, x, y, s * 2.4, o.glow, 0.35 * a));
  // bonds
  atoms.slice().sort((m, n) => m.p[2] - n.p[2]).forEach(m => {
    line(c, [[C[0], C[1]], [m.p[0], m.p[1]]], '#d8d4e8', s * 0.11, a * 0.85);
  });
  const all = [...atoms.map(m => ({ p: m.p, col: (o.cols ?? GROUP)[m.i].col, r: GROUP[m.i].r })), { p: C, col: '#5e5a6e', r: 0.3 }];
  all.sort((m, n) => m.p[2] - n.p[2]).forEach(m => ball(c, m.p[0], m.p[1], m.r * s * m.p[3], m.col, a));
  return { C, atoms };
}
// a chiral "pinwheel" glyph – blades curl one way or the other
function pinwheel(c, x, y, r, rot, hand, col, a = 1, o = {}) {
  if (a <= 0.003) return;
  alpha(c, a, () => {
    c.save(); c.translate(x, y); c.rotate(rot);
    if (o.glow !== false) additive(c, () => glow(c, 0, 0, r * 2.4, col, 0.35));
    c.fillStyle = col; c.strokeStyle = mixHex(col, '#ffffff', 0.5); c.lineWidth = 1.2;
    for (let k = 0; k < 3; k++) {
      c.save(); c.rotate(k * TAU / 3);
      c.beginPath(); c.moveTo(0, 0);
      c.quadraticCurveTo(r * 0.9, hand * r * 0.1, r * 0.95, hand * r * 0.6);
      c.quadraticCurveTo(r * 0.45, hand * r * 0.45, 0, 0);
      c.fill(); c.stroke(); c.restore();
    }
    dot(c, 0, 0, r * 0.18, '#ffffff', 1);
    c.restore();
  });
}
function drawHand(c, x, y, s, col, mirror, a = 1) {
  if (a <= 0.003) return;
  c.save(); c.translate(x, y); c.scale(mirror ? -s : s, s);
  // tint
  const tmp = tintCache(col);
  alpha(c, a * 0.32, () => c.drawImage(tmp.fill, -300, -410));
  additive(c, () => alpha(c, a * 0.55, () => c.drawImage(tmp.glow, -300, -410)));
  c.restore();
}
const tints = {};
function tintCache(col) {
  if (tints[col]) return tints[col];
  const mk = (src) => { const cv = document.createElement('canvas'); cv.width = 600; cv.height = 820; const g = cv.getContext('2d'); g.drawImage(src, 0, 0); g.globalCompositeOperation = 'source-in'; g.fillStyle = col; g.fillRect(0, 0, 600, 820); return cv; };
  return (tints[col] = { fill: mk(handImg), glow: mk(handGlow) });
}
function leaf(c, x, y, s, rot, a = 1) {
  alpha(c, a, () => {
    c.save(); c.translate(x, y); c.rotate(rot); c.scale(s, s);
    const g = c.createLinearGradient(0, -60, 0, 60); g.addColorStop(0, '#7ff0a0'); g.addColorStop(1, '#1f8a4c');
    c.fillStyle = g; c.beginPath(); c.moveTo(0, -70); c.bezierCurveTo(46, -40, 46, 30, 0, 70); c.bezierCurveTo(-46, 30, -46, -40, 0, -70); c.fill();
    c.strokeStyle = 'rgba(220,255,230,0.7)'; c.lineWidth = 2; c.beginPath(); c.moveTo(0, -60); c.lineTo(0, 66); c.stroke();
    for (let i = -2; i <= 2; i++) { c.beginPath(); c.moveTo(0, i * 22); c.lineTo(26, i * 22 - 14); c.moveTo(0, i * 22); c.lineTo(-26, i * 22 - 14); c.stroke(); }
    c.restore();
  });
}
function seeds(c, x, y, s, a = 1) {
  for (let i = 0; i < 7; i++) {
    const ang = hash(i) * TAU, rr = 10 + hash(i + 9) * 40;
    alpha(c, a, () => {
      c.save(); c.translate(x + Math.cos(ang) * rr * s, y + Math.sin(ang) * rr * s); c.rotate(ang * 2);
      const g = c.createLinearGradient(-20, 0, 20, 0); g.addColorStop(0, '#c8955a'); g.addColorStop(1, '#6b4320');
      c.fillStyle = g; c.beginPath(); c.ellipse(0, 0, 26 * s, 8 * s, 0, 0, TAU); c.fill();
      c.strokeStyle = 'rgba(255,230,190,0.6)'; c.lineWidth = 1; for (let k = -1; k <= 1; k++) { c.beginPath(); c.moveTo(-22 * s, k * 3 * s); c.lineTo(22 * s, k * 3 * s); c.stroke(); }
      c.restore();
    });
  }
}
function capsule(c, x, y, s, col, a = 1, rot = -0.5) {
  alpha(c, a, () => {
    c.save(); c.translate(x, y); c.rotate(rot); c.scale(s, s);
    additive(c, () => glow(c, 0, 0, 120, col, 0.4));
    c.beginPath(); c.roundRect(-80, -30, 160, 60, 30); c.fillStyle = 'rgba(255,255,255,0.12)'; c.fill();
    c.save(); c.clip(); c.fillStyle = col; c.fillRect(0, -30, 80, 60); c.restore();
    c.strokeStyle = 'rgba(255,255,255,0.8)'; c.lineWidth = 2; c.beginPath(); c.roundRect(-80, -30, 160, 60, 30); c.stroke();
    c.fillStyle = 'rgba(255,255,255,0.35)'; c.beginPath(); c.roundRect(-64, -20, 110, 10, 5); c.fill();
    c.restore();
  });
}
function helix(c, x, y, h, rw, st, col, a = 1, o = {}) {
  if (a <= 0) return;
  const n = 60;
  const pts1 = [], pts2 = [];
  for (let i = 0; i <= n; i++) {
    const u = i / n, ang = u * TAU * 2.2 + st * 0.8;
    const yy = y - h / 2 + u * h;
    pts1.push([x + Math.sin(ang) * rw, yy, Math.cos(ang)]); pts2.push([x + Math.sin(ang + Math.PI) * rw, yy, Math.cos(ang + Math.PI)]);
  }
  for (let i = 0; i <= n; i += 3) line(c, [[pts1[i][0], pts1[i][1]], [pts2[i][0], pts2[i][1]]], o.rung ?? '#ffffff', 2, a * 0.35);
  for (const pts of [pts1, pts2]) for (let i = 0; i < n; i++) {
    const z = (pts[i][2] + 1) / 2;
    line(c, [[pts[i][0], pts[i][1]], [pts[i + 1][0], pts[i + 1][1]]], col, 4 + 3 * z, a * (0.35 + 0.65 * z));
  }
  additive(c, () => glow(c, x, y, h * 0.6, col, 0.15 * a));
}
function flask(c, x, y, s, a = 1) {
  alpha(c, a, () => {
    c.save(); c.translate(x, y); c.scale(s, s);
    c.strokeStyle = 'rgba(230,225,255,0.85)'; c.lineWidth = 3;
    c.beginPath(); c.moveTo(-28, -170); c.lineTo(-28, -80); c.arc(0, 30, 116, -Math.PI / 2 - 0.24, Math.PI * 1.5 + 0.24 - TAU, true); c.lineTo(28, -170); c.stroke();
    c.beginPath(); c.moveTo(-40, -170); c.lineTo(40, -170); c.stroke();
    c.restore();
  });
}
function scale2(c, x, y, tilt, a = 1, o = {}) {
  alpha(c, a, () => {
    c.save(); c.translate(x, y);
    c.strokeStyle = '#e8e2ff'; c.lineWidth = 3;
    c.beginPath(); c.moveTo(0, 0); c.lineTo(0, 170); c.moveTo(-60, 170); c.lineTo(60, 170); c.stroke();
    c.rotate(tilt);
    c.beginPath(); c.moveTo(-220, 0); c.lineTo(220, 0); c.stroke();
    for (const [sx, col] of [[-220, o.left ?? P.teal], [220, o.right ?? P.rose]]) {
      c.save(); c.translate(sx, 0); c.rotate(-tilt);
      c.beginPath(); c.moveTo(0, 0); c.lineTo(-60, 90); c.moveTo(0, 0); c.lineTo(60, 90); c.stroke();
      c.fillStyle = rgba(col, 0.35); c.beginPath(); c.ellipse(0, 92, 75, 14, 0, 0, TAU); c.fill(); c.stroke();
      for (let k = 0; k < 6; k++) pinwheel(c, -45 + k * 18, 70 - (k % 2) * 12, 9, k, col === P.teal ? 1 : -1, col, 1, { glow: false });
      c.restore();
    }
    dot(c, 0, 0, 7, P.gold, 1);
    c.restore();
  });
}

// ---------------------------------------------------------------- scenes
const S = {};
S.title = (c, st) => {
  bg(c, st);
  mirrorLine(c, W / 2, smooth(0.3, 1.5, st) * 0.6, st);
  const yaw = st * 0.5;
  molecule(c, 330, 560, 105, yaw, 0.35, false, { a: smooth(0.5, 2, st), glow: P.teal });
  molecule(c, W - 330, 560, 105, -yaw, 0.35, true, { a: smooth(0.5, 2, st), glow: P.rose });
  drawTitle(c, st, { glow: P.violet });
};

S.hands = (c, st, sp) => {
  bg(c, st, { neb: 0.6 });
  mirrorLine(c, W / 2, smooth(0.2, 1.2, st), st);
  const slide = ease.inOut(clamp((st - sp.cue(0) - 3.4) / 2.2));
  const lx = 640, rx = lerp(1280, 640, slide);
  drawHand(c, lx, 560, 0.85, P.teal, false, smooth(0.3, 1.5, st));
  drawHand(c, rx, 560, 0.85, P.rose, true, smooth(0.6, 1.8, st) * (slide > 0 ? 0.9 : 1));
  text(c, '左手', 300, 560, { size: 34, weight: 700, color: P.teal, alpha: smooth(1, 2, st) * (1 - slide), spacing: 8 });
  text(c, '右手', 1620, 560, { size: 34, weight: 700, color: P.rose, alpha: smooth(1.3, 2.3, st) * (1 - slide), spacing: 8 });
  text(c, '互为镜像', W / 2, 140, { size: 40, weight: 700, color: '#e9e4ff', alpha: smooth(sp.cue(0), sp.cue(0) + 1, st), spacing: 12 });
  const ka = smooth(sp.cue(0) + 5.3, sp.cue(0) + 6, st);
  if (ka > 0) {
    // thumbs on opposite sides – mark them
    for (const [x, y] of [[640 + 200, 640], [640 - 200, 640]]) { c.strokeStyle = rgba(P.red, ka); c.lineWidth = 3; c.beginPath(); c.arc(x, y, 85 + 4 * Math.sin(st * 6), 0, TAU); c.stroke(); }
    text(c, '拇指朝向相反', 1320, 650, { size: 30, weight: 700, color: '#ffd0d0', alpha: ka, spacing: 4 });
    text(c, '无法完全重合', 1320, 560, { size: 56, weight: 900, color: '#ffffff', alpha: ka, spacing: 10, glow: 20, glowColor: P.red });
  }
};

S.molecule = (c, st, sp) => {
  bg(c, st, { neb: 0.6 });
  mirrorLine(c, W / 2, 0.8 * (1 - smooth(sp.cue(1) - 1, sp.cue(1), st)), st);
  const yaw = 0.6 + st * 0.35;
  const over = ease.inOut(clamp((st - 6.5) / 2));
  const back = ease.inOut(clamp((st - sp.cue(1) + 1.2) / 1.2));
  const lx = lerp(lerp(560, 760, over), 560, back), rx = lerp(lerp(1360, 1160, over), 1360, back);
  const lift = ease.inOut(clamp((st - sp.cue(1) - 4) / 1.5));
  molecule(c, lx, lerp(520, 400, lift), lerp(150, 100, lift), yaw, 0.3, false, { glow: P.teal });
  molecule(c, rx, lerp(520, 400, lift), lerp(150, 100, lift), -yaw + Math.PI, 0.3, true, { glow: P.rose });
  // labels
  const la = smooth(1, 2, st) * (1 - smooth(6, 6.6, st));
  callout(c, 560, 520, 330, 260, '手性碳', '连着四个不同的基团', P.gold, la);
  const leg = smooth(2, 3, st) * (1 - smooth(sp.cue(1) - 1, sp.cue(1), st));
  ['基团 A', '基团 B', '基团 C', '基团 D'].forEach((s, i) => { dot(c, 1510 + i * 0, 200 + i * 44, 12, GROUP[i].col, leg); text(c, s, 1535, 200 + i * 44, { size: 24, align: 'left', color: '#e8e4f8', alpha: leg }); });
  text(c, '左手型', 560, lerp(790, 260, lift), { size: 34, weight: 700, color: P.teal, alpha: smooth(2, 3, st) * (1 - over) + back, spacing: 8 });
  text(c, '右手型', 1360, lerp(790, 260, lift), { size: 34, weight: 700, color: P.rose, alpha: smooth(2.3, 3.3, st) * (1 - over) + back, spacing: 8 });
  const ma = smooth(8.8, 9.6, st) * (1 - back);
  text(c, '怎么转，都对不上', W / 2, 820, { size: 44, weight: 800, color: '#fff', alpha: ma, spacing: 8, glow: 18, glowColor: P.red });
  // same properties, different partners
  if (st > sp.cue(1)) {
    ['组成相同', '熔点相同', '沸点相同'].forEach((s, i) => badge(c, s, 760 + i * 200, 170, P.violet, smooth(sp.cue(1) + i * 0.6, sp.cue(1) + 0.6 + i * 0.6, st) * (1 - lift * 0.6), { size: 28 }));
    const ka = smooth(sp.cue(1) + 4.5, sp.cue(1) + 5.5, st);
    if (ka > 0) {
      const drop = ease.out(clamp((st - sp.cue(1) - 5.5) / 1.6));
      const sockY = 850;
      for (const [cx0, ok] of [[560, true], [1360, false]]) {
        // receptor plate with three coloured sockets (same for both)
        alpha(c, ka, () => { c.fillStyle = 'rgba(200,190,255,0.10)'; c.beginPath(); c.roundRect(cx0 - 130, sockY - 120, 260, 175, 30); c.fill(); c.strokeStyle = 'rgba(220,210,255,0.5)'; c.lineWidth = 1.5; c.stroke(); });
        [[-60, 0, 0], [60, 0, 1], [0, -70, 2]].forEach(([dx, dy, gi]) => { c.strokeStyle = rgba(GROUP[gi].col, ka); c.lineWidth = 3; c.setLineDash([5, 4]); c.beginPath(); c.arc(cx0 + dx, sockY + dy, 26, 0, TAU); c.stroke(); c.setLineDash([]); });
        // the molecule's footprint (mirror image on the right)
        const fy = lerp(sockY - 150, sockY, drop);
        [[-60, 0, 0], [60, 0, 1], [0, -70, 2]].forEach(([dx, dy, gi]) => ball(c, cx0 + (ok ? dx : -dx), fy + dy, 20, GROUP[gi].col, ka));
        const ra = smooth(0.85, 1, drop);
        text(c, ok ? '✓ 严丝合缝' : '✗ 对不上', cx0 + 160, sockY - 40, { size: 34, weight: 800, color: ok ? P.teal : P.red, alpha: ra, align: 'left', glow: 12, glowColor: ok ? P.teal : P.red });
      }
      text(c, '遇到手性的“锁”，便判若两物', W / 2, 640, { size: 36, weight: 700, color: '#efeaff', alpha: ka, spacing: 4 });
    }
  }
};

S.carvone = (c, st, sp) => {
  bg(c, st, { neb: 0.55 });
  mirrorLine(c, W / 2, 0.5, st);
  const a1 = smooth(0.2, 1.2, st) * (1 - smooth(sp.cue(1) - 0.8, sp.cue(1), st));
  if (a1 > 0) {
    molecule(c, 560, 420, 110, st * 0.4, 0.3, false, { a: a1, glow: P.teal });
    molecule(c, 1360, 420, 110, -st * 0.4 + Math.PI, 0.3, true, { a: a1, glow: P.rose });
    for (let i = 0; i < 3; i++) leaf(c, 470 + i * 90, 700 + (i % 2) * 20, 0.9, -0.5 + i * 0.5 + Math.sin(st + i) * 0.05, a1 * smooth(1 + i * 0.3, 2 + i * 0.3, st));
    seeds(c, 1360, 700, 1.4, a1 * smooth(2, 3, st));
    text(c, '留兰香', 560, 850, { size: 44, weight: 800, color: '#9ff5c0', alpha: a1 * smooth(1.5, 2.5, st), spacing: 10 });
    text(c, '葛缕子', 1360, 850, { size: 44, weight: 800, color: '#f0c38a', alpha: a1 * smooth(2.5, 3.5, st), spacing: 10 });
    text(c, '同一种香芹酮的两只“手”', W / 2, 160, { size: 38, weight: 700, color: '#efeaff', alpha: a1, spacing: 6 });
  }
  const a2 = smooth(sp.cue(1), sp.cue(1) + 1, st);
  if (a2 > 0) {
    capsule(c, 600, 480, 1.4, P.teal, a2);
    capsule(c, 1320, 480, 1.4, P.rose, a2 * smooth(sp.cue(1) + 1.2, sp.cue(1) + 2, st), 0.5);
    text(c, '治病', 600, 680, { size: 48, weight: 800, color: P.teal, alpha: a2, spacing: 12, glow: 14, glowColor: P.teal });
    text(c, '致害', 1320, 680, { size: 48, weight: 800, color: P.rose, alpha: smooth(sp.cue(1) + 1.5, sp.cue(1) + 2.5, st), spacing: 12, glow: 14, glowColor: P.rose });
    text(c, '药物：镜像之差，天壤之别', W / 2, 160, { size: 38, weight: 700, color: '#efeaff', alpha: a2, spacing: 6 });
  }
};

S.life = (c, st, sp) => {
  bg(c, st, { neb: 0.7 });
  // 0: one hand only
  const a0 = win(st, 0.5, sp.cue(1) + 0.5, 0.8);
  drawHand(c, W / 2, 560, 0.75, P.teal, false, a0);
  text(c, '只选一只手', W / 2, 160, { size: 44, weight: 800, color: '#efeaff', alpha: smooth(sp.cue(0), sp.cue(0) + 1, st) * (1 - smooth(sp.cue(1), sp.cue(1) + 0.6, st)), spacing: 10 });
  // 1: proteins left-handed, nucleic-acid sugars right-handed
  const a1 = win(st, sp.cue(1), sp.cue(2) + 0.3, 0.9);
  if (a1 > 0) {
    const n = 16;
    for (let i = 0; i < n; i++) {
      const u = i / (n - 1); const x = 200 + u * 640, y = 520 + Math.sin(u * 7 + st * 1.2) * 110;
      if (i) { const u0 = (i - 1) / (n - 1); line(c, [[200 + u0 * 640, 520 + Math.sin(u0 * 7 + st * 1.2) * 110], [x, y]], '#cfe', 2, a1 * 0.5); }
      pinwheel(c, x, y, 26, st * 1.5 + i, 1, P.teal, a1 * smooth(sp.cue(1) + u * 2, sp.cue(1) + 0.5 + u * 2, st));
    }
    text(c, '蛋白质 · 氨基酸', 520, 300, { size: 36, weight: 800, color: P.teal, alpha: a1, spacing: 6 });
    text(c, '几乎全是左手型', 520, 720, { size: 30, color: '#dff', alpha: a1 });
    helix(c, 1400, 520, 480, 90, st, P.rose, a1 * smooth(sp.cue(1) + 2, sp.cue(1) + 3, st));
    text(c, '核酸中的糖', 1400, 230, { size: 36, weight: 800, color: P.rose, alpha: a1 * smooth(sp.cue(1) + 2, sp.cue(1) + 3, st), spacing: 6 });
    text(c, '全是右手型', 1400, 820, { size: 30, color: '#fde', alpha: a1 * smooth(sp.cue(1) + 2, sp.cue(1) + 3, st) });
    const ha = smooth(sp.cue(1) + 6, sp.cue(1) + 7, st);
    text(c, '同手性', W / 2, 870, { size: 84, weight: 900, color: '#ffffff', alpha: a1 * ha, spacing: 24, glow: 30, glowColor: P.violet });
  }
  // 2: in the lab – half and half
  const a2 = smooth(sp.cue(2), sp.cue(2) + 1, st);
  if (a2 > 0) {
    flask(c, 560, 560, 1.4, a2);
    const r = rng(3);
    for (let i = 0; i < 40; i++) {
      const h = i % 2 ? 1 : -1, ang = r() * TAU, rr = r() * 120;
      const x = 560 + Math.cos(ang + st * 0.3 * (r() - 0.5)) * rr, y = 600 + Math.sin(ang + st * 0.4 * (r() - 0.5)) * rr * 0.8;
      pinwheel(c, x, y, 13, st * 2 * h + i, h, h > 0 ? P.teal : P.rose, a2, { glow: false });
    }
    text(c, '实验室合成：左右各半', 560, 860, { size: 34, weight: 700, color: '#efeaff', alpha: a2, spacing: 4 });
    const tilt = -0.22 * ease.inOut(clamp((st - sp.cue(3) - 1.5) / 3)) * (1 + 0.05 * Math.sin(st * 2));
    scale2(c, 1340, 420, tilt, a2);
    text(c, '50 : 50', 1340, 330, { size: 48, font: F.serif, weight: 800, color: P.gold, alpha: a2 * (1 - smooth(sp.cue(3), sp.cue(3) + 1, st)), spacing: 6 });
    text(c, '天平如何倾斜？', 1340, 330, { size: 48, weight: 800, color: P.gold, alpha: smooth(sp.cue(3) + 0.5, sp.cue(3) + 1.5, st), spacing: 6, glow: 16, glowColor: P.gold });
  }
};

// ML2 model: heterochiral dimers are stable and inactive
function nle(e, K = 300) {
  const R = (1 + e) / 2, Sx = (1 - e) / 2;
  const A = 4 - K, B = K, Cq = -K * R * Sx;
  const z = (-B + Math.sqrt(B * B - 4 * A * Cq)) / (2 * A);
  const x = (R - z) / 2, y = (Sx - z) / 2;
  return 0.98 * (x - y) / (x + y + 1e-12);
}
S.nlegraph = (c, st, sp) => {
  bg(c, st, { neb: 0.5 });
  // 0: a chiral catalyst guiding a reaction
  const a0 = win(st, sp.cue(0) - 0.5, sp.cue(1) + 0.4, 0.8);
  if (a0 > 0) {
    molecule(c, W / 2, 520, 120, st * 0.6, 0.3, false, { a: a0, glow: P.gold, cols: GROUP });
    text(c, '手性催化剂', W / 2, 330, { size: 40, weight: 800, color: P.gold, alpha: a0, spacing: 10, glow: 14, glowColor: P.gold });
    for (let i = 0; i < 9; i++) { const u = (st * 0.25 + i / 9) % 1; const x = lerp(200, 1720, u); const y = 760 + Math.sin(u * 9 + i) * 20; const conv = u > 0.5; pinwheel(c, x, y, 16, st * 3 + i, 1, conv ? P.teal : '#9a98aa', a0 * (1 - smooth(0.85, 1, u)), { glow: conv }); }
    text(c, '原料　→　单一手型的产物', W / 2, 850, { size: 28, color: '#e2ddf5', alpha: a0, spacing: 4 });
  }
  // graph
  const ga = smooth(sp.cue(1), sp.cue(1) + 1, st);
  if (ga > 0) {
    const x0 = 520, x1 = 1400, y0 = 860, y1 = 200;
    const gx = v => lerp(x0, x1, v), gy = v => lerp(y0, y1, v);
    line(c, [[x0, y1 - 20], [x0, y0], [x1 + 20, y0]], '#e2ddf5', 2, ga);
    for (let k = 0; k <= 4; k++) { const v = k / 4; text(c, `${k * 25}%`, gx(v), y0 + 36, { size: 22, color: '#cfc9e6', alpha: ga }); text(c, `${k * 25}%`, x0 - 20, gy(v), { size: 22, color: '#cfc9e6', alpha: ga, align: 'right' }); }
    text(c, '催化剂的纯度 →', (x0 + x1) / 2, y0 + 82, { size: 28, color: '#e2ddf5', alpha: ga, spacing: 4 });
    c.save(); c.translate(x0 - 100, (y0 + y1) / 2); c.rotate(-Math.PI / 2); text(c, '产物的纯度 →', 0, 0, { size: 28, color: '#e2ddf5', alpha: ga, spacing: 4 }); c.restore();
    const pl = clamp((st - sp.cue(1) - 1.5) / 2.5);
    c.save(); c.setLineDash([10, 9]); line(c, partial([[gx(0), gy(0)], [gx(1), gy(0.98)]], pl), '#bdb6d8', 3, ga); c.restore();
    text(c, '按常理：成正比', gx(0.72), gy(0.6), { size: 30, weight: 700, color: '#d3cdea', alpha: smooth(sp.cue(1) + 3, sp.cue(1) + 4, st), align: 'left' });
    const pc = clamp((st - sp.cue(2) - 1.5) / 3);
    if (pc > 0) {
      const pts = []; for (let v = 0; v <= 1.0001; v += 0.01) pts.push([gx(v), gy(nle(v))]);
      line(c, partial(pts, pc), P.gold, 5, 1, 18);
      // marker at 20 %
      const ma = smooth(sp.cue(2) + 4.5, sp.cue(2) + 5.5, st);
      const mx = gx(0.2), my = gy(nle(0.2)), ly = gy(0.2 * 0.98);
      c.save(); c.setLineDash([4, 6]); line(c, [[mx, y0], [mx, my]], '#ffffff', 1.5, ma * 0.7); c.restore();
      dot(c, mx, ly, 7, '#bdb6d8', ma); dot(c, mx, my, 9, P.gold, ma); glow(c, mx, my, 30, P.gold, ma);
      text(c, `催化剂 20%  →  产物约 ${Math.round(nle(0.2) * 100)}%`, mx + 40, my + 75, { size: 30, weight: 800, color: '#ffffff', alpha: ma, align: 'left', glow: 12, glowColor: P.gold });
    }
    const ka = smooth(sp.cue(3), sp.cue(3) + 1, st);
    text(c, '非线性效应', 1560, 700, { size: 60, weight: 900, color: P.gold, alpha: ka, spacing: 10, glow: 22, glowColor: P.gold });
    text(c, '1986', 1560, 790, { size: 44, weight: 800, color: '#ffffff', alpha: ka * 0.9, spacing: 8 });
    text(c, '示意（ML₂ 模型）', x1, y1 - 30, { size: 20, color: '#a9a3c4', alpha: ga * 0.8, align: 'right' });
  }
};

S.pairing = (c, st, sp) => {
  bg(c, st, { neb: 0.5 });
  const pairT = 3.0, pairD = 3.5;
  const pk = ease.inOut(clamp((st - pairT) / pairD));
  const sink = ease.inOut(clamp((st - pairT - pairD) / 2.5));
  crowd.forEach((m, i) => {
    let x = m.x + Math.sin(st * m.sp + m.ph) * 18, y = m.y + Math.cos(st * m.sp * 0.8 + m.ph) * 14;
    let col = m.h > 0 ? P.teal : P.rose, a = 1, spin = st * 2 * m.h + m.ph;
    if (m.mate) {
      const M = m.mate; const mx = (m.x + M.x) / 2, my = (m.y + M.y) / 2;
      const side = m.h > 0 ? -1 : 1;
      x = lerp(x, mx + side * 16, pk); y = lerp(y, my, pk);
      y += sink * (880 - my) * 0.9; x += sink * ((i % 10) - 5) * 4;
      a = 1 - 0.65 * sink;
      if (sink > 0) col = mixHex(col, '#6d6a80', sink);
      spin = lerp(spin, m.ph, pk);
    } else {
      // the free majority glows and works harder
      spin = st * (2 + 4 * sink) + m.ph;
      if (sink > 0.2) additive(c, () => glow(c, x, y, 70, P.teal, 0.4 * sink));
    }
    pinwheel(c, x, y, 22, spin, m.h, col, a, { glow: !m.mate || sink < 0.5 });
  });
  // bonds inside pairs
  crowd.filter(m => m.h < 0).forEach(m => {
    if (pk <= 0) return;
    const M = m.mate; const mx = (m.x + M.x) / 2, my = (m.y + M.y) / 2 + sink * (880 - (m.y + M.y) / 2) * 0.9;
    line(c, [[mx - 16, my], [mx + 16, my]], '#cfcbe0', 3, pk * (1 - 0.5 * sink));
  });
  // counters
  const a0 = smooth(0.4, 1.2, st);
  text(c, '多数派 30　·　少数派 20', W / 2, 150, { size: 34, weight: 700, color: '#efeaff', alpha: a0 * (1 - smooth(pairT + pairD, pairT + pairD + 1, st)), spacing: 4 });
  text(c, '催化剂纯度 20%', W / 2, 205, { size: 30, color: P.gold, alpha: a0 * (1 - smooth(pairT + pairD, pairT + pairD + 1, st)) });
  const a1 = smooth(pairT + 1, pairT + 2, st) * (1 - smooth(sp.cue(1) - 0.5, sp.cue(1), st));
  text(c, '一左一右：配对稳固，却失去活性', W / 2, 980 - 60, { size: 32, weight: 700, color: '#d6d2e6', alpha: a1 * 0, spacing: 4 });
  badge(c, '一左一右的对子：稳固，但“退场”', 1500, 900, '#9a96b0', a1, { size: 26 });
  const a2 = smooth(pairT + pairD + 1.5, pairT + pairD + 2.5, st);
  text(c, '留在场上：清一色的多数派', W / 2, 150, { size: 38, weight: 800, color: P.teal, alpha: a2, spacing: 6, glow: 14, glowColor: P.teal });
  text(c, '有效纯度 ≈ 100%', W / 2, 210, { size: 32, weight: 700, color: P.gold, alpha: a2 });
};

S.autocat = (c, st, sp) => {
  bg(c, st, { neb: 0.55 });
  const cx = W / 2, cy = 560;
  // 0: product = catalyst
  const a0 = smooth(sp.cue(0), sp.cue(0) + 1, st);
  const grow = clamp((st - sp.cue(1) - 1) / 9);
  // branching tree of copies
  const gens = 7;
  const nodes = [{ x: cx, y: cy, g: 0, a: 0 }];
  for (let g = 1; g <= gens; g++) {
    const prev = nodes.filter(n => n.g === g - 1);
    prev.forEach((p, k) => { for (let j = 0; j < 2; j++) { const ang = (p.a ?? 0) + (j ? 1 : -1) * (0.9 / Math.sqrt(g)) + (g === 1 ? (j ? Math.PI : 0) : 0); const rr = 120 / Math.pow(g, 0.25); nodes.push({ x: p.x + Math.cos(ang) * rr, y: p.y + Math.sin(ang) * rr * 0.8, g, a: ang, px: p.x, py: p.y }); } });
  }
  nodes.forEach((n, i) => {
    const appear = n.g === 0 ? a0 : smooth((n.g - 1) / gens, n.g / gens, grow);
    if (appear <= 0) return;
    if (n.g > 0) line(c, [[n.px, n.py], [lerp(n.px, n.x, appear), lerp(n.py, n.y, appear)]], P.teal, 1.5, 0.4 * appear);
    pinwheel(c, lerp(n.px ?? n.x, n.x, appear), lerp(n.py ?? n.y, n.y, appear), n.g === 0 ? 34 : Math.max(9, 22 - n.g * 2), st * 2.5 + i, 1, P.teal, appear, { glow: n.g < 5 });
  });
  text(c, '产物 = 催化剂', cx, cy - 110, { size: 40, weight: 800, color: '#ffffff', alpha: a0 * (1 - smooth(sp.cue(1) + 1, sp.cue(1) + 2, st)), spacing: 8, glow: 14, glowColor: P.teal });
  const ya = smooth(sp.cue(1), sp.cue(1) + 1, st);
  text(c, '1995', 230, 200, { size: 72, weight: 900, color: '#ffffff', alpha: ya, glow: 20, glowColor: P.teal });
  text(c, '不对称自催化', 230, 270, { size: 30, weight: 700, color: P.teal, alpha: ya, spacing: 4 });
  text(c, '一传十，十传百', 1660, 200, { size: 40, weight: 800, color: P.gold, alpha: smooth(sp.cue(1) + 8, sp.cue(1) + 9, st), spacing: 6 });
  // 2: minority swallowed
  const a2 = smooth(sp.cue(2), sp.cue(2) + 1, st);
  if (a2 > 0) {
    for (let i = 0; i < 6; i++) {
      const ang = i * 1.1 + 0.4, rr = 300 + i * 30; const x = cx + Math.cos(ang) * rr, y = cy + Math.sin(ang) * rr * 0.6;
      const k = ease.inOut(clamp((st - sp.cue(2) - 1 - i * 0.4) / 1.5));
      pinwheel(c, x - 18 * k, y, 18, st * -2 + i, -1, mixHex(P.rose, '#6d6a80', k), a2);
      pinwheel(c, x + 18 * k + (1 - k) * 60, y, 18, st * 2 + i, 1, mixHex(P.teal, '#6d6a80', k), a2 * k);
      if (k > 0.9) line(c, [[x - 18, y], [x + 18, y]], '#cfcbe0', 3, a2);
    }
    badge(c, '少数派被成对“吞没”', 1600, 900, P.rose, smooth(sp.cue(2) + 2, sp.cue(2) + 3, st), { size: 26 });
  }
};

S.race = (c, st, sp) => {
  bg(c, st, { neb: 0.45 });
  // round progress 0..3 across the second line
  const rp = clamp((st - sp.cue(1) + 0.5) / 6.5) * 3;
  const teal = rp <= 0 ? 0.5 : 0.5 + 0.4975 * (1 - Math.pow(1 - clamp(rp / 3), 3.2));
  // dot field
  field.forEach(d => {
    const isT = d.r < teal;
    const col = isT ? P.teal : P.rose;
    const pulse = 0.75 + 0.25 * Math.sin(st * 3 + d.d * 20);
    dot(c, d.x, d.y, 4.2, col, (0.55 + 0.45 * pulse) * smooth(d.d * 1.5, d.d * 1.5 + 0.6, st));
  });
  // bar
  const bx = 320, bw = 1280, by = 880;
  L.rrect(c, bx, by - 14, bw, 28, 14); c.fillStyle = rgba(P.rose, 0.85); c.fill();
  L.rrect(c, bx, by - 14, bw * teal, 28, 14); c.fillStyle = rgba(P.teal, 0.95); c.fill();
  text(c, '左手型', bx - 20, by, { size: 26, color: P.teal, align: 'right' });
  text(c, '右手型', bx + bw + 20, by, { size: 26, color: P.rose, align: 'left' });
  const a0 = smooth(0.5, 1.5, st) * (1 - smooth(sp.cue(1), sp.cue(1) + 0.6, st));
  text(c, '起点：光学纯度约 0.00005%', W / 2, 150, { size: 40, weight: 800, color: '#ffffff', alpha: a0, spacing: 4 });
  text(c, '约一千万个分子里，左右只差几个', W / 2, 212, { size: 30, color: '#e8e4f8', alpha: a0, spacing: 4 });
  const rr = Math.min(3, Math.floor(rp + 0.001));
  const a1 = smooth(sp.cue(1), sp.cue(1) + 0.5, st);
  ['第一轮', '第二轮', '第三轮'].forEach((s, i) => badge(c, s, 760 + i * 200, 170, i < rr ? P.gold : '#6d6a80', a1 * (i < rr ? 1 : 0.5), { size: 28 }));
  const ea = smooth(sp.cue(1) + 6.2, sp.cue(1) + 7, st);
  text(c, '光学纯度 > 99.5%', W / 2, 240, { size: 46, weight: 900, color: P.gold, alpha: ea, spacing: 4, glow: 18, glowColor: P.gold });
  const fa = smooth(sp.cue(2), sp.cue(2) + 1, st);
  if (fa > 0) {
    c.fillStyle = `rgba(7,4,15,${0.65 * fa})`; c.fillRect(0, 0, W, H);
    text(c, '除了生命本身', W / 2, 470, { size: 52, weight: 700, color: '#efeaff', alpha: fa, spacing: 12 });
    text(c, '第一次', W / 2, 590, { size: 120, weight: 900, color: '#ffffff', alpha: smooth(sp.cue(2) + 1, sp.cue(2) + 2, st), spacing: 30, glow: 30, glowColor: P.teal });
  }
};

S.origin = (c, st, sp) => {
  // primordial sky and sea
  fill(c, vgrad(c, [[0, '#05030c'], [0.5, '#1a0f2e'], [0.58, '#3a1a2a'], [0.6, '#0b1f2a'], [1, '#04121a']]));
  drawStars(c, stars, st, { alpha: 0.7, dy: 0 });
  additive(c, () => glow(c, 1500, 620, 500, '#ff7a3a', 0.25));
  const hz = 640;
  // sea
  const spread = clamp((st - sp.cue(2) - 2) / 7);
  for (let k = 0; k < 26; k++) {
    const y = hz + Math.pow(k / 25, 1.6) * 440;
    const pts = []; for (let x = 0; x <= W; x += 24) pts.push([x, y + Math.sin(x * (0.012 - k * 0.0003) + st * 0.7 + k * 1.7) * (1 + k * 0.28)]);
    const d = Math.abs(960 - 960) ;
    line(c, pts, mixHex('#2a5a78', P.teal, spread * 0.85), 1.2 + k * 0.05, 0.18 + 0.4 * (k / 25));
  }
  if (spread > 0) {
    c.save(); c.beginPath(); c.rect(0, hz, W, H - hz); c.clip();
    additive(c, () => { const R = spread * 1300; const g = c.createRadialGradient(960, 760, 0, 960, 760, R + 1); g.addColorStop(0, rgba(P.teal, 0.35)); g.addColorStop(0.85, rgba(P.teal, 0.18)); g.addColorStop(1, rgba(P.teal, 0)); c.fillStyle = g; c.fillRect(0, hz, W, H - hz); });
    c.restore();
  }
  // triggers
  const t1 = win(st, sp.cue(1), sp.cue(2) + 0.5, 0.8);
  if (t1 > 0) {
    // circularly polarised starlight – a helix of light
    const hx = 420; const k1 = smooth(sp.cue(1), sp.cue(1) + 1, st);
    glow(c, hx, 90, 40, '#ffffff', t1 * k1);
    const pts = []; for (let y = 100; y < 600; y += 4) pts.push([hx + Math.sin(y * 0.06 - st * 6) * 26, y]);
    additive(c, () => line(c, partial(pts, k1), '#d8c8ff', 2.5, t1, 14));
    text(c, '圆偏振的星光', hx + 60, 330, { size: 30, weight: 700, color: '#e1d6ff', alpha: t1 * k1, align: 'left' });
    // quartz
    const k2 = smooth(sp.cue(1) + 2, sp.cue(1) + 3, st);
    crystal(c, 960, 470, 1.0, st, t1 * k2);
    text(c, '左旋或右旋的石英', 960, 600, { size: 30, weight: 700, color: '#f0e8ff', alpha: t1 * k2 });
    // fluctuation
    const k3 = smooth(sp.cue(1) + 4, sp.cue(1) + 5, st);
    const r = rng(8);
    for (let i = 0; i < 21; i++) pinwheel(c, 1440 + (r() - 0.5) * 300, 410 + (r() - 0.5) * 210, 16, st * 2 + i, i < 11 ? 1 : -1, i < 11 ? P.teal : P.rose, t1 * k3, { glow: i === 0 });
    text(c, '偶然的涨落：11 比 10', 1440, 560, { size: 30, weight: 700, color: '#f0e8ff', alpha: t1 * k3 });
  }
  // the spark
  const sk = st - sp.cue(2);
  if (sk > 0) {
    const fallY = lerp(120, 760, ease.in(clamp(sk / 1.8)));
    if (sk < 1.8) additive(c, () => glow(c, 960, fallY, 30, P.teal, 1));
    if (sk > 1.8) for (let k = 0; k < 4; k++) { const rr = (sk - 1.8 - k * 0.6) * 260; if (rr > 0) { c.strokeStyle = rgba(P.teal, Math.max(0, 0.8 - rr / 900)); c.lineWidth = 2; c.beginPath(); c.ellipse(960, 760, rr, rr * 0.22, 0, 0, TAU); c.stroke(); } }
    text(c, '捕获 · 放大 · 燎原', 960, 200, { size: 46, weight: 800, color: '#ffffff', alpha: smooth(2.5, 3.5, sk) * (1 - smooth(sp.cue(3) - sp.cue(2), sp.cue(3) - sp.cue(2) + 1, sk)), spacing: 10, glow: 18, glowColor: P.teal });
  }
  const la = smooth(sp.cue(3), sp.cue(3) + 1.5, st);
  if (la > 0) {
    helix(c, 760, 440, 380, 70, st, P.teal, la);
    for (let i = 0; i < 12; i++) { const u = i / 11; pinwheel(c, 1060 + u * 300, 440 + Math.sin(u * 6 + st) * 80, 15, st * 2 + i, 1, P.teal, la * smooth(u, u + 0.3, clamp((st - sp.cue(3)) / 2))); }
    text(c, '生命的同手性', W / 2, 160, { size: 52, weight: 900, color: '#ffffff', alpha: la, spacing: 14, glow: 22, glowColor: P.teal });
  }
};
function crystal(c, x, y, s, st, a) {
  if (a <= 0) return;
  c.save(); c.translate(x, y); c.scale(s, s); c.rotate(Math.sin(st * 0.5) * 0.05);
  additive(c, () => glow(c, 0, -40, 160, '#d8c8ff', 0.35 * a));
  const faces = [[[-40, 60], [-40, -60], [0, -110], [0, 20], [0, 80]], [[0, 80], [0, 20], [0, -110], [40, -60], [40, 60]]];
  faces.forEach((f, i) => { c.beginPath(); f.forEach(([px, py], k) => (k ? c.lineTo(px, py) : c.moveTo(px, py))); c.closePath(); c.fillStyle = `rgba(${i ? '200,190,255' : '160,150,230'},${0.35 * a})`; c.fill(); c.strokeStyle = `rgba(240,235,255,${0.9 * a})`; c.lineWidth = 2; c.stroke(); });
  // a twist arrow
  c.strokeStyle = rgba(P.gold, a); c.lineWidth = 2.5; c.beginPath(); c.ellipse(0, -10, 70, 18, 0, 0.3, Math.PI * 1.7); c.stroke();
  L.arrowHead(c, 70 * Math.cos(Math.PI * 1.7), -10 + 18 * Math.sin(Math.PI * 1.7), Math.PI * 1.7 + Math.PI / 2, 14, P.gold, a);
  c.restore();
}

S.apply = (c, st, sp) => {
  bg(c, st, { neb: 0.5 });
  const items = [['药物', 420], ['香料', 960], ['新材料', 1500]];
  items.forEach(([s, x], i) => {
    const a = smooth(sp.cue(0) + i * 0.8, sp.cue(0) + 1 + i * 0.8, st);
    if (a <= 0) return;
    if (i === 0) capsule(c, x, 480, 1.3, P.teal, a);
    if (i === 1) bottle(c, x, 500, a, st);
    if (i === 2) lattice(c, x, 480, a, st);
    text(c, s, x, 700, { size: 46, weight: 800, color: '#ffffff', alpha: a, spacing: 12, glow: 14, glowColor: P.teal });
  });
  const ka = smooth(sp.cue(1) + 3, sp.cue(1) + 4, st);
  text(c, '尽可能纯净的单一镜像分子', W / 2, 820, { size: 40, weight: 700, color: P.gold, alpha: ka, spacing: 8, glow: 14, glowColor: P.gold });
  molecule(c, W / 2, 200, 60, st * 0.6, 0.3, false, { a: ka, glow: P.teal });
};
function bottle(c, x, y, a, st) {
  alpha(c, a, () => {
    c.save(); c.translate(x, y);
    additive(c, () => glow(c, 0, 20, 160, '#ff9ad0', 0.3));
    c.strokeStyle = 'rgba(255,240,250,0.9)'; c.lineWidth = 3;
    c.beginPath(); c.roundRect(-80, -40, 160, 150, 30); c.stroke();
    c.fillStyle = 'rgba(255,140,200,0.25)'; c.beginPath(); c.roundRect(-74, 10, 148, 94, 24); c.fill();
    c.beginPath(); c.roundRect(-22, -90, 44, 50, 8); c.stroke();
    c.beginPath(); c.arc(0, -110, 18, 0, TAU); c.stroke();
    for (let i = 0; i < 6; i++) { const u = (st * 0.3 + i / 6) % 1; glow(c, Math.sin(i * 2 + st) * 30, -130 - u * 140, 10, '#ffd0ea', 1 - u); }
    c.restore();
  });
}
function lattice(c, x, y, a, st) {
  alpha(c, a, () => {
    c.save(); c.translate(x, y);
    const pts = []; for (let i = -2; i <= 2; i++) for (let j = -2; j <= 2; j++) pts.push([i * 46 + (j % 2) * 23, j * 40]);
    const rot = st * 0.3;
    const tr = ([px, py]) => [px * Math.cos(rot) - py * Math.sin(rot) * 0.4, py + px * Math.sin(rot) * 0.2];
    pts.forEach((p, i) => pts.forEach((q, j) => { if (j > i && Math.hypot(p[0] - q[0], p[1] - q[1]) < 52) { const A = tr(p), B = tr(q); line(c, [A, B], '#b6f5ff', 1.5, 0.6); } }));
    pts.forEach(p => { const A = tr(p); ball(c, A[0], A[1], 9, '#7fe9ff'); });
    c.restore();
  });
}

S.finale = (c, st, sp) => {
  bg(c, st, { neb: 0.6 });
  // the mirror – one side alive, the other a fading reflection
  mirrorLine(c, W / 2, 0.9, st);
  helix(c, 640, 520, 560, 95, st, P.teal, 1);
  const r = rng(5);
  for (let i = 0; i < 40; i++) { const x = 160 + r() * 760, y = 160 + r() * 720; pinwheel(c, x + Math.sin(st + i) * 10, y + Math.cos(st * 0.8 + i) * 8, 7 + r() * 9, st * 2 + i, 1, P.teal, 0.8); }
  helix(c, 1280, 520, 560, 95, -st, P.rose, 0.2 + 0.05 * Math.sin(st));
};

export default { palette: P, init, scenes: S };
