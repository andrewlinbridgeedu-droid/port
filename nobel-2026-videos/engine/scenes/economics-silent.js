// 经济学奖 · 无配音节拍版：沿用 economics.js 的各场景，另加卡点片头、片名重拍和倒放片头的片尾。
// 96 BPM：一拍 0.625 秒，一小节 2.5 秒；片头、片名、片尾的每个变化都落在拍点上。
import base, { P, bg, tide, house, shop, dial, bolt, axes } from './economics.js';
import * as L from '../lib.js';
const { W, H, TAU, F, clamp, lerp, smooth, ease, glow, dot, line, text, reveal, rgba, additive, hash } = L;

const BEAT = 60 / 96, BAR = BEAT * 4;
const GRID = [];
for (let j = 0; j < 6; j++) for (let i = 0; i < 16; i++) GRID.push({ x: 260 + i * 93, y: 260 + j * 82, h: (i + j) % 3 !== 0 });

const flash = (c, st, at, a = 0.28) => { const k = st - at; if (k >= 0 && k < 0.25) { c.save(); c.globalAlpha = a * Math.exp(-k * 16); c.fillStyle = '#fff6e0'; c.fillRect(0, 0, W, H); c.restore(); } };
const word = (c, s, st, at, col = '#ffffff') => { const k = st - at; if (k < 0 || k > BEAT) return; const e = ease.out(clamp(k / 0.12)); text(c, s, W / 2, 900 - (1 - e) * 16, { size: 64, weight: 900, color: col, alpha: e * (1 - smooth(BEAT - 0.08, BEAT, k)), spacing: 18, glow: 18, glowColor: col }); };

// 四个镜头，片头正着放、片尾倒着放；k 为镜头内时间
const oneHome = (c, st) => { const p = 1 + 0.25 * Math.sin(st * 14); additive(c, () => glow(c, W / 2, H / 2, 120 * p, P.gold, 0.8)); dot(c, W / 2, H / 2, 12 * p, '#fff4d6', 1); };
const homes = (c, g) => GRID.forEach(p => (p.h ? house : shop)(c, lerp(W / 2, p.x, g), lerp(H / 2, p.y, g), 1.6 * g + 0.2, p.h ? P.gold : P.jade, Math.min(1, g * 1.5)));
const tags = (c, k) => {
  for (let i = 0; i < 5; i++) {
    const x = 560 + i * 200, y = 480, fl = Math.abs(Math.cos(clamp((k - i * 0.06) / 0.18) * Math.PI));
    c.save(); c.translate(x, y); c.scale(1.4, 1.4 * Math.max(0.05, fl));
    c.fillStyle = '#efe6d2'; c.beginPath(); c.moveTo(-56, -40); c.lineTo(40, -40); c.lineTo(62, 0); c.lineTo(40, 40); c.lineTo(-56, 40); c.closePath(); c.fill();
    c.restore();
    text(c, `¥${12 + i + (k - i * 0.06 > 0.09 ? 1 : 0)}`, x - 10, y + 2, { size: 44, weight: 800, color: '#1a1410', alpha: fl });
  }
};
const rate = (c, k, from = 0.2, to = 0.75) => dial(c, W / 2, 500, 210, lerp(from, to, ease.outBack(clamp(k / 0.3))), 1, { col: P.violet, label: '利率' });

const S = { ...base.scenes };

// 片头：十秒四小节，一拍一刀
S.opening = (c, st) => {
  bg(c, st);
  const b = st / BEAT;
  if (b < 1) { oneHome(c, st); word(c, '一个家庭', st, 0.05, P.gold); }
  else if (b < 2) { homes(c, ease.out(clamp((st - BEAT) / 0.4))); word(c, '千家万户', st, BEAT); }
  else if (b < 3) { tags(c, st - 2 * BEAT); word(c, '定价', st, 2 * BEAT, P.gold); }
  else if (b < 4) { rate(c, st - 3 * BEAT); word(c, '利率', st, 3 * BEAT, P.violet); }
  else if (st < 2 * BAR) {                       // 第二小节：滞胀
    const k = st - BAR;
    const x0 = 520, x1 = 1400, y0 = 820, y1 = 220;
    axes(c, x0, y0, x1, y1, 1, '失业', '通胀');
    const curve = []; for (let u = 0; u <= 1.0001; u += 0.02) curve.push([lerp(x0 + 60, x1 - 80, u), lerp(y1 + 80, y0 - 60, Math.pow(u, 0.35))]);
    line(c, L.partial(curve, clamp(k / 0.5)), P.blue, 4, 1, 12);
    for (let i = 0; i < 22; i++) {
      const kk = ease.out(clamp((k - BEAT - i * 0.02) / 0.5)); if (kk <= 0) continue;
      const a = hash(i) * TAU, r = 120 + hash(i + 3) * 300;
      const x = lerp(900, 980 + Math.cos(a) * r * 1.3, kk), y = lerp(560, 380 + Math.sin(a) * r * 0.6 - 60, kk);
      additive(c, () => glow(c, x, y, 26, P.red, 0.8)); dot(c, x, y, 8, P.red, 1);
    }
    const sk = st - (BAR + 2 * BEAT);
    if (sk > 0) { const shake = Math.exp(-sk * 6) * 14; text(c, '滞胀', W / 2 + Math.sin(sk * 60) * shake, 470, { size: 200, weight: 900, color: P.red, alpha: smooth(0, 0.08, sk), spacing: 40, glow: 40, glowColor: P.red }); bolt(c, 1560, 300, 2.4, '#ffb07a', smooth(0, 0.1, sk)); }
  } else if (st < 3 * BAR) {                     // 第三小节：潮起潮落
    const k = st - 2 * BAR;
    const sweep = ease.inOut(clamp(k / 1.2));
    const wave = x => 540 - 170 * Math.sin(x * 0.008 - st * 1.2);
    const pts = []; for (let x = 0; x <= W * sweep; x += 8) pts.push([x, wave(x)]);
    line(c, pts, P.gold, 5, 1, 18);
    for (let n = 0; n < 16; n++) { const x = 60 + n * 120; if (x < W * sweep) house(c, x, wave(x) - 26, 1.3, P.gold, 1); }
    const calm = smooth(BEAT * 2, BEAT * 3, k);
    if (calm > 0) { const sm = []; for (let x = 0; x <= W; x += 8) sm.push([x, 540 - (540 - wave(x)) * 0.3]); line(c, sm, P.jade, 5, calm, 18); }
    word(c, '潮起潮落', st, 2 * BAR + 0.1, P.gold);
    word(c, '如何平稳？', st, 2 * BAR + 2 * BEAT, P.jade);
  } else {                                       // 第四小节：万点归一，最后一拍几乎全黑
    const k = st - 3 * BAR;
    const pull = ease.in(clamp(k / (3 * BEAT)));
    const out = 1 - smooth(3 * BEAT, 3 * BEAT + 0.05, k);
    for (let i = 0; i < 260; i++) {
      const a0 = hash(i) * TAU, r0 = 200 + hash(i + 7) * 900;
      const a = a0 + pull * 3, r = r0 * (1 - pull);
      dot(c, W / 2 + Math.cos(a) * r, H / 2 + Math.sin(a) * r * 0.62, 2 + 2 * hash(i + 2), i % 4 ? P.gold : P.jade, 0.9 * out);
    }
    if (out < 1) { c.save(); c.globalAlpha = (1 - out) * 0.9; c.fillStyle = '#000'; c.fillRect(0, 0, W, H); c.restore(); additive(c, () => glow(c, W / 2, H / 2, 40 + 30 * (k - 3 * BEAT), '#fff4d6', 1 - out)); }
  }
  [1, 2, 3, 4, 6, 8, 12].forEach(n => flash(c, st, n * BEAT));
};

// 片名：第五小节强拍砸下，其后每两拍落一层
S.title = (c, st, sp, G) => {
  const T = G.S, gold = P.gold;
  bg(c, st);
  tide(c, st, 955, 20, smooth(0, 1.2, st), { n: 6 });
  for (let i = 0; i < 220; i++) { const x = (hash(i) * W + st * (10 + hash(i + 3) * 30)) % W, y = 930 + hash(i + 7) * 150 + Math.sin(st + i) * 8; dot(c, x, y, 1.6, i % 5 ? gold : P.jade, 0.5 * smooth(0, 1.5, st)); }
  const e = ease.out(clamp(st / 0.22)), z = lerp(1.22, 1, e);
  c.save(); c.translate(W / 2, 515); c.scale(z, z); c.translate(-W / 2, -515);
  const g = c.createLinearGradient(0, 430, 0, 610); g.addColorStop(0, '#ffffff'); g.addColorStop(0.55, '#fff4dc'); g.addColorStop(1, gold);
  text(c, T.title, W / 2, 515, { size: 168, weight: 900, color: g, spacing: 28, glow: 28 + 50 * (1 - e), glowColor: rgba(gold, 0.55), alpha: clamp(st / 0.05) });
  c.restore();
  const a1 = smooth(2 * BEAT, 2 * BEAT + 0.2, st);
  text(c, T.prize, W / 2, 285 - 12 * (1 - a1), { size: 40, weight: 600, color: gold, spacing: 14, alpha: a1, glow: 18, glowColor: rgba(gold, 0.6) });
  text(c, T.prizeEn, W / 2, 338, { size: 22, font: F.latin, weight: 600, color: '#d9d2c0', spacing: 9, alpha: a1 * 0.75 });
  reveal(c, T.subtitle, W / 2, 652, clamp((st - BAR) / 0.6), { size: 46, weight: 500, color: '#efe9dc', spacing: 12, spread: 0.6 });
  const a3 = smooth(BAR + 2 * BEAT, BAR + 2 * BEAT + 0.25, st);
  line(c, [[W / 2 - 240 * a3, 718], [W / 2 + 240 * a3, 718]], gold, 1.2, a3 * 0.7);
  text(c, '获奖者　' + T.laureates, W / 2, 766, { size: 30, weight: 500, color: '#d8d0bf', spacing: 6, alpha: a3 * 0.9 });
  const a4 = smooth(2 * BAR, 2 * BAR + 0.3, st);
  T.citation.forEach((s, i) => text(c, s, W / 2, 828 + i * 44, { size: 31, font: F.kai, weight: 400, color: '#cfc6b2', spacing: 3, alpha: a4 * 0.92 }));
  flash(c, st, 0, 0.55);
};

// 片尾：把片头倒着放一遍——利率、定价、千家万户，归成一点，再升作明月
S.finale = (c, st, sp) => {
  bg(c, st, { grid: false });
  const b = st / BEAT;
  if (b < 1) { rate(c, st, 0.75, 0.42); word(c, '利率', st, 0, P.violet); }
  else if (b < 2) { tags(c, st - BEAT); word(c, '定价', st, BEAT, P.gold); }
  else if (b < 3) { homes(c, ease.out(clamp((st - 2 * BEAT) / 0.3))); word(c, '千家万户', st, 2 * BEAT); }
  else if (b < 4) homes(c, 1 - ease.in(clamp((st - 3 * BEAT) / BEAT)));
  else {
    const k = st - BAR;
    const lit = smooth(0, BEAT * 2, k);                                // 潮水与倒影渐起
    const calm = clamp((k - BEAT) / 9);
    const m = ease.inOut(clamp((k - 2 * BEAT) / (BAR * 1.4)));         // 一点升作明月
    const mx = lerp(W / 2, 1380, m), my = lerp(540, 290, m) - Math.sin(m * Math.PI) * 80, r = lerp(9, 62, m);
    const ma = smooth(BAR, BAR * 2, k);
    additive(c, () => { glow(c, mx, my, lerp(120, 360, m), P.gold, lerp(0.8, 0.25, m)); glow(c, mx, my, r * 2, '#fff2c8', 0.6); });
    dot(c, mx, my, r, '#fbf1d6', 1);
    additive(c, () => { for (let n = 0; n < 26; n++) { const y = 580 + n * 16, w = 60 + n * 9 + Math.sin(st * 2 + n) * 14; line(c, [[mx - w / 2, y], [mx + w / 2, y]], '#fff2c8', 2, ma * 0.35 * (1 - n / 28)); } });
    tide(c, st, 560, lerp(90, 14, ease.out(calm)), lit, { n: 14, gap: 26 });
    for (let i = 0; i < 300; i++) { const x = (hash(i) * W + st * 12) % W, y = 600 + hash(i + 5) * 360 + Math.sin(st * 0.8 + i) * lerp(30, 6, calm); dot(c, x, y, 1.5, i % 4 ? P.gold : P.jade, 0.5 * ma); }
    word(c, '以微知著', st, BAR, P.gold);
  }
  [0, 1, 2, 4].forEach(n => flash(c, st, n * BEAT, n ? 0.28 : 0.4));
};

export default { palette: base.palette, init: base.init, scenes: S, sources: ['economics.js'] };
