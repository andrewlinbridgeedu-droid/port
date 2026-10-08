// 诺贝尔 2026 解说片 · 确定性 Canvas 渲染核心
// 每一帧都只是时间 t 的纯函数：可以任意顺序、多进程并行渲染。
(function (G) {
  'use strict';
  const W = 1920, H = 1080;

  // ---------- 数学 ----------
  const clamp = (x, a = 0, b = 1) => Math.max(a, Math.min(b, x));
  const lerp = (a, b, t) => a + (b - a) * t;
  const inv = (a, b, x) => clamp((x - a) / (b - a));
  const smooth = (a, b, x) => { const t = inv(a, b, x); return t * t * (3 - 2 * t); };
  const E = {
    inOut: t => t < .5 ? 4 * t * t * t : 1 - Math.pow(-2 * t + 2, 3) / 2,
    out: t => 1 - Math.pow(1 - t, 3),
    in: t => t * t * t,
    outExpo: t => t >= 1 ? 1 : 1 - Math.pow(2, -10 * t),
    inOutSine: t => -(Math.cos(Math.PI * t) - 1) / 2,
    outBack: t => { const c1 = 1.70158, c3 = c1 + 1; return 1 + c3 * Math.pow(t - 1, 3) + c1 * Math.pow(t - 1, 2); },
    outElastic: t => t === 0 ? 0 : t === 1 ? 1 : Math.pow(2, -10 * t) * Math.sin((t * 10 - .75) * (2 * Math.PI / 3)) + 1,
  };
  // 在 [a,b] 区间内按缓动推进的进度
  const prog = (t, a, b, ease = E.inOut) => ease(inv(a, b, t));
  // 进入、停留、退出的包络
  const env = (t, a, b, fin = .6, fout = .6) => Math.min(smooth(a, a + fin, t), 1 - smooth(b - fout, b, t));

  // ---------- 可复现的随机数 ----------
  function rng(seed) {
    let s = seed >>> 0;
    return function () {
      s += 0x6D2B79F5; let t = s;
      t = Math.imul(t ^ t >>> 15, t | 1);
      t ^= t + Math.imul(t ^ t >>> 7, t | 61);
      return ((t ^ t >>> 14) >>> 0) / 4294967296;
    };
  }
  const hash = (i, seed = 0) => { let h = (i * 374761393 + seed * 668265263) | 0; h = Math.imul(h ^ h >>> 13, 1274126177); return ((h ^ h >>> 16) >>> 0) / 4294967296; };

  // ---------- 噪声（Simplex 2D/3D） ----------
  const perm = new Uint8Array(512);
  (function () { const r = rng(1234); const p = [...Array(256).keys()]; for (let i = 255; i > 0; i--) { const j = Math.floor(r() * (i + 1)); [p[i], p[j]] = [p[j], p[i]]; } for (let i = 0; i < 512; i++) perm[i] = p[i & 255]; })();
  const g3 = [[1,1,0],[-1,1,0],[1,-1,0],[-1,-1,0],[1,0,1],[-1,0,1],[1,0,-1],[-1,0,-1],[0,1,1],[0,-1,1],[0,1,-1],[0,-1,-1]];
  function noise3(x, y, z) {
    const F3 = 1 / 3, G3 = 1 / 6; const s = (x + y + z) * F3;
    const i = Math.floor(x + s), j = Math.floor(y + s), k = Math.floor(z + s); const t = (i + j + k) * G3;
    const x0 = x - i + t, y0 = y - j + t, z0 = z - k + t; let i1, j1, k1, i2, j2, k2;
    if (x0 >= y0) { if (y0 >= z0) { i1 = 1; j1 = 0; k1 = 0; i2 = 1; j2 = 1; k2 = 0; } else if (x0 >= z0) { i1 = 1; j1 = 0; k1 = 0; i2 = 1; j2 = 0; k2 = 1; } else { i1 = 0; j1 = 0; k1 = 1; i2 = 1; j2 = 0; k2 = 1; } }
    else { if (y0 < z0) { i1 = 0; j1 = 0; k1 = 1; i2 = 0; j2 = 1; k2 = 1; } else if (x0 < z0) { i1 = 0; j1 = 1; k1 = 0; i2 = 0; j2 = 1; k2 = 1; } else { i1 = 0; j1 = 1; k1 = 0; i2 = 1; j2 = 1; k2 = 0; } }
    const x1 = x0 - i1 + G3, y1 = y0 - j1 + G3, z1 = z0 - k1 + G3, x2 = x0 - i2 + 2 * G3, y2 = y0 - j2 + 2 * G3, z2 = z0 - k2 + 2 * G3, x3 = x0 - 1 + .5, y3 = y0 - 1 + .5, z3 = z0 - 1 + .5;
    const ii = i & 255, jj = j & 255, kk = k & 255; let n = 0;
    const c = (xx, yy, zz, gi) => { let tt = .6 - xx * xx - yy * yy - zz * zz; if (tt < 0) return 0; tt *= tt; const g = g3[gi % 12]; return tt * tt * (g[0] * xx + g[1] * yy + g[2] * zz); };
    n += c(x0, y0, z0, perm[ii + perm[jj + perm[kk]]]);
    n += c(x1, y1, z1, perm[ii + i1 + perm[jj + j1 + perm[kk + k1]]]);
    n += c(x2, y2, z2, perm[ii + i2 + perm[jj + j2 + perm[kk + k2]]]);
    n += c(x3, y3, z3, perm[ii + 1 + perm[jj + 1 + perm[kk + 1]]]);
    return 32 * n;
  }
  const fbm = (x, y, z, oct = 4) => { let a = 0, f = 1, amp = .5; for (let o = 0; o < oct; o++) { a += amp * noise3(x * f, y * f, z * f); f *= 2; amp *= .5; } return a; };

  // ---------- 颜色 ----------
  function hexRgb(h) { h = h.replace('#', ''); if (h.length === 3) h = h.split('').map(c => c + c).join(''); const n = parseInt(h, 16); return [n >> 16 & 255, n >> 8 & 255, n & 255]; }
  const rgba = (c, a = 1) => { const [r, g, b] = Array.isArray(c) ? c : hexRgb(c); return `rgba(${r | 0},${g | 0},${b | 0},${a})`; };
  const mix = (c1, c2, t) => { const a = Array.isArray(c1) ? c1 : hexRgb(c1), b = Array.isArray(c2) ? c2 : hexRgb(c2); return [lerp(a[0], b[0], t), lerp(a[1], b[1], t), lerp(a[2], b[2], t)]; };
  const hsl = (h, s, l, a = 1) => `hsla(${h},${s}%,${l}%,${a})`;
  // 按时间顺序上色的“彩虹”（IceCube 事件图的经典配色：红→黄→绿→蓝）
  const timeColor = u => { const h = lerp(0, 240, clamp(u)); return `hsl(${h},95%,58%)`; };

  // ---------- 发光精灵（缓存的径向渐变） ----------
  const spriteCache = new Map();
  function glowSprite(color, hard = .0) {
    const key = color + '|' + hard; if (spriteCache.has(key)) return spriteCache.get(key);
    const s = 128, c = document.createElement('canvas'); c.width = c.height = s; const g = c.getContext('2d');
    const [r, gg, b] = hexRgb(color); const grd = g.createRadialGradient(s / 2, s / 2, 0, s / 2, s / 2, s / 2);
    grd.addColorStop(0, `rgba(${r},${gg},${b},1)`);
    grd.addColorStop(clamp(.08 + hard * .5), `rgba(${r},${gg},${b},${.85})`);
    grd.addColorStop(.25 + hard * .3, `rgba(${r},${gg},${b},.35)`);
    grd.addColorStop(.6, `rgba(${r},${gg},${b},.08)`);
    grd.addColorStop(1, `rgba(${r},${gg},${b},0)`);
    g.fillStyle = grd; g.fillRect(0, 0, s, s); spriteCache.set(key, c); return c;
  }
  // 在 'lighter' 叠加模式下画一个光点
  function glow(ctx, x, y, r, color, a = 1, hard = 0) {
    if (a <= 0.003 || r <= 0.1) return; const sp = glowSprite(color, hard);
    ctx.globalAlpha = clamp(a); ctx.drawImage(sp, x - r, y - r, r * 2, r * 2); ctx.globalAlpha = 1;
  }
  function dot(ctx, x, y, r, color, a = 1) { ctx.globalAlpha = clamp(a); ctx.fillStyle = color; ctx.beginPath(); ctx.arc(x, y, Math.max(.1, r), 0, Math.PI * 2); ctx.fill(); ctx.globalAlpha = 1; }

  // ---------- 3D 投影 ----------
  function cam(o = {}) {
    const c = { yaw: o.yaw || 0, pitch: o.pitch || 0, roll: o.roll || 0, dist: o.dist || 1200, fov: o.fov || 1100, cx: o.cx ?? W / 2, cy: o.cy ?? H / 2, tx: o.tx || 0, ty: o.ty || 0, tz: o.tz || 0 };
    const cy_ = Math.cos(c.yaw), sy_ = Math.sin(c.yaw), cp = Math.cos(c.pitch), sp = Math.sin(c.pitch), cr = Math.cos(c.roll), sr = Math.sin(c.roll);
    c.p = (x, y, z) => {
      x -= c.tx; y -= c.ty; z -= c.tz;
      let X = x * cy_ - z * sy_, Z = x * sy_ + z * cy_; // yaw 绕 y 轴
      let Y = y * cp - Z * sp; Z = y * sp + Z * cp;       // pitch 绕 x 轴
      const X2 = X * cr - Y * sr, Y2 = X * sr + Y * cr;
      const zz = Z + c.dist; const s = c.fov / Math.max(1, zz);
      return { x: c.cx + X2 * s, y: c.cy + Y2 * s, s, z: zz };
    };
    return c;
  }

  // ---------- 字体与文字 ----------
  const FONT = {
    song: '"Noto Serif SC"', kai: '"LXGW WenKai"', kaiM: '"LXGW WenKai Medium"', brush: '"Ma Shan Zheng"', xing: '"Zhi Mang Xing"', latin: '"Cormorant Garamond"', latinI: '"Cormorant Garamond Italic"'
  };
  function font(fam, size, weight = 400) { return `${weight} ${size}px ${FONT[fam] || fam}, "Noto Serif SC", serif`; }
  // 文字：支持逐字显现、字距、发光
  function text(ctx, str, x, y, o = {}) {
    const size = o.size || 48; ctx.save();
    ctx.font = font(o.font || 'song', size, o.weight || 400);
    ctx.textBaseline = o.baseline || 'middle';
    const ls = (o.spacing || 0) * size; const chars = [...str];
    const widths = chars.map(ch => ctx.measureText(ch).width); const total = widths.reduce((a, b) => a + b, 0) + ls * Math.max(0, chars.length - 1);
    let sx = x; const align = o.align || 'center'; if (align === 'center') sx = x - total / 2; else if (align === 'right') sx = x - total;
    const reveal = o.reveal ?? 1; const n = chars.length; const a0 = o.alpha ?? 1;
    const color = o.color || '#f4efe6';
    if (o.glow) { ctx.shadowColor = o.glowColor || color; ctx.shadowBlur = o.glow; }
    let cx = sx;
    for (let i = 0; i < n; i++) {
      const local = clamp(reveal * (n + (o.soft ?? 3)) - i, 0, o.soft ?? 3) / (o.soft ?? 3);
      if (local > 0) {
        ctx.globalAlpha = a0 * local; ctx.fillStyle = color;
        const dy = (1 - local) * (o.rise ?? size * .35);
        ctx.fillText(chars[i], cx, y + dy);
      }
      cx += widths[i] + ls;
    }
    ctx.restore(); return total;
  }
  // 竖排文字（自上而下）
  function vtext(ctx, str, x, y, o = {}) {
    const size = o.size || 48; ctx.save(); ctx.font = font(o.font || 'song', size, o.weight || 400);
    ctx.textAlign = 'center'; ctx.textBaseline = 'middle'; const chars = [...str]; const gap = size * (1 + (o.spacing || .1));
    const reveal = o.reveal ?? 1, n = chars.length; if (o.glow) { ctx.shadowColor = o.glowColor || o.color; ctx.shadowBlur = o.glow; }
    for (let i = 0; i < n; i++) { const local = clamp(reveal * (n + 3) - i, 0, 3) / 3; if (local <= 0) continue; ctx.globalAlpha = (o.alpha ?? 1) * local; ctx.fillStyle = o.color || '#f4efe6'; ctx.fillText(chars[i], x, y + i * gap + (1 - local) * size * .3); }
    ctx.restore();
  }
  function measure(ctx, str, fam, size, weight = 400) { ctx.save(); ctx.font = font(fam, size, weight); const w = ctx.measureText(str).width; ctx.restore(); return w; }
  // 自动换行：中文按字，西文按词；支持 \n 强制换行
  function wrap(ctx, str, fam, size, maxW) {
    ctx.save(); ctx.font = font(fam, size); const lines = [];
    const latin = /^[\x00-\u024f\u2018-\u201d\s]+$/.test(str);
    for (const para of str.split('\n')) {
      if (latin) { let cur = ''; for (const w of para.split(' ')) { const t = cur ? cur + ' ' + w : w; if (ctx.measureText(t).width > maxW && cur) { lines.push(cur); cur = w; } else cur = t; } if (cur) lines.push(cur); continue; }
      let cur = '';
      for (const ch of para) { const t = cur + ch; if (ctx.measureText(t).width > maxW && cur) { if ('，。、；：？！”’）》'.includes(ch)) { cur = t; continue; } lines.push(cur); cur = ch; } else cur = t; }
      if (cur) lines.push(cur);
    }
    ctx.restore(); return lines;
  }
  // ---------- 画面后期 ----------
  let grainTiles = null;
  function makeGrain() {
    grainTiles = []; for (let k = 0; k < 6; k++) { const c = document.createElement('canvas'); c.width = 480; c.height = 270; const g = c.getContext('2d'); const id = g.createImageData(480, 270); const r = rng(77 + k); for (let i = 0; i < id.data.length; i += 4) { const v = r() * 255; id.data[i] = id.data[i + 1] = id.data[i + 2] = v; id.data[i + 3] = 255; } g.putImageData(id, 0, 0); grainTiles.push(c); }
  }
  function grain(ctx, frame, amt = .045) { if (!grainTiles) makeGrain(); ctx.save(); ctx.globalCompositeOperation = 'overlay'; ctx.globalAlpha = amt; ctx.imageSmoothingEnabled = false; ctx.drawImage(grainTiles[Math.floor(frame / 2) % 6], 0, 0, W, H); ctx.restore(); }
  function vignette(ctx, amt = .55, color = '#000') { const g = ctx.createRadialGradient(W / 2, H / 2, H * .35, W / 2, H / 2, H * 1.0); g.addColorStop(0, rgba(color, 0)); g.addColorStop(1, rgba(color, amt)); ctx.fillStyle = g; ctx.fillRect(0, 0, W, H); }
  let bloomC = null, bloomC2 = null;
  function bloom(ctx, canvas, amt = .55, blur = 10, thresh = 'brightness(0.9) contrast(1.6)') {
    if (amt <= 0) return;
    if (!bloomC) { bloomC = document.createElement('canvas'); bloomC.width = 480; bloomC.height = 270; bloomC2 = document.createElement('canvas'); bloomC2.width = 480; bloomC2.height = 270; }
    const b = bloomC.getContext('2d'); b.globalCompositeOperation = 'copy'; b.filter = thresh; b.drawImage(canvas, 0, 0, 480, 270); b.filter = 'none';
    const b2 = bloomC2.getContext('2d'); b2.globalCompositeOperation = 'copy'; b2.filter = `blur(${blur}px)`; b2.drawImage(bloomC, 0, 0); b2.filter = 'none';
    ctx.save(); ctx.globalCompositeOperation = 'lighter'; ctx.globalAlpha = amt; ctx.drawImage(bloomC2, 0, 0, W, H); ctx.globalAlpha = amt * .6; ctx.filter = 'blur(2px)'; ctx.drawImage(bloomC2, 0, 0, W, H); ctx.filter = 'none'; ctx.restore();
  }

  // ---------- 字幕 ----------
  function subtitle(ctx, line, t, o = {}) {
    if (!line) return; const a = env(t, line.start, line.end, .18, .18); if (a <= 0) return;
    const size = o.size || 44; const y = o.y || H - 92; ctx.save();
    const lines = wrap(ctx, line.text, 'kai', size, W * .78);
    const lh = size * 1.42; const top = y - (lines.length - 1) * lh;
    ctx.font = font('kai', size); ctx.textAlign = 'center'; ctx.textBaseline = 'middle';
    // 柔和的椭圆形暗晕（不出现矩形边缘）
    const mw = Math.max(...lines.map(l => ctx.measureText(l).width)); const cy = (top + y) / 2;
    ctx.save(); ctx.translate(W / 2, cy); ctx.scale(1, (lines.length * lh + lh) / (mw + 260)); const rg = ctx.createRadialGradient(0, 0, 0, 0, 0, (mw + 260) / 2); const paper = o.theme === 'paper'; const bc = paper ? '250,244,230' : '0,0,0'; rg.addColorStop(0, `rgba(${bc},${(paper ? .75 : .42) * a})`); rg.addColorStop(.6, `rgba(${bc},${(paper ? .45 : .22) * a})`); rg.addColorStop(1, `rgba(${bc},0)`); ctx.fillStyle = rg; ctx.beginPath(); ctx.arc(0, 0, (mw + 260) / 2, 0, Math.PI * 2); ctx.fill(); ctx.restore();
    ctx.globalAlpha = a; ctx.shadowColor = o.theme === 'paper' ? 'rgba(255,252,244,.95)' : 'rgba(0,0,0,.9)'; ctx.shadowBlur = 10; ctx.shadowOffsetY = o.theme === 'paper' ? 0 : 2;
    ctx.fillStyle = o.color || (o.theme === 'paper' ? '#1f1a14' : '#f6f1e7');
    lines.forEach((l, i) => ctx.fillText(l, W / 2, top + i * lh));
    ctx.restore();
  }

  // ---------- 通用小件 ----------
  function bg(ctx, c1, c2, c3) { const g = ctx.createRadialGradient(W / 2, H * .45, 0, W / 2, H * .5, W * .75); g.addColorStop(0, c1); g.addColorStop(.6, c2); g.addColorStop(1, c3 || c2); ctx.fillStyle = g; ctx.fillRect(0, 0, W, H); }
  function line(ctx, pts, color, w = 2, a = 1) { if (pts.length < 2) return; ctx.save(); ctx.globalAlpha = clamp(a); ctx.strokeStyle = color; ctx.lineWidth = w; ctx.lineCap = 'round'; ctx.lineJoin = 'round'; ctx.beginPath(); ctx.moveTo(pts[0][0], pts[0][1]); for (let i = 1; i < pts.length; i++) ctx.lineTo(pts[i][0], pts[i][1]); ctx.stroke(); ctx.restore(); }
  // 画一段线的前 u 比例（用于“生长”的线条）
  function partial(pts, u) { u = clamp(u); if (u >= 1) return pts; const L = [0]; for (let i = 1; i < pts.length; i++) L.push(L[i - 1] + Math.hypot(pts[i][0] - pts[i - 1][0], pts[i][1] - pts[i - 1][1])); const target = L[L.length - 1] * u; const out = [pts[0]]; for (let i = 1; i < pts.length; i++) { if (L[i] <= target) out.push(pts[i]); else { const k = (target - L[i - 1]) / (L[i] - L[i - 1] || 1); out.push([lerp(pts[i - 1][0], pts[i][0], k), lerp(pts[i - 1][1], pts[i][1], k)]); break; } } return out; }
  // 标签：锚点小圈 + 折线引线 + 宋体小字（可带英文）
  function label(ctx, str, x, y, o = {}) { const a = o.alpha ?? 1; if (a <= 0) return; const dx = o.dx ?? 60, dy = o.dy ?? -50; const lc = o.lineColor || 'rgba(235,240,250,.7)'; const g = E.out(clamp(a * 1.4));
    ctx.save(); ctx.globalAlpha = a; ctx.strokeStyle = lc; ctx.lineWidth = 1.2; ctx.beginPath(); ctx.arc(x, y, 5, 0, Math.PI * 2); ctx.stroke();
    const ex = x + dx * .55 * g, ey = y + dy * g; ctx.beginPath(); ctx.moveTo(x + Math.sign(dx) * 5 * Math.abs(Math.cos(Math.atan2(dy, dx * .55))), y + 5 * Math.sin(Math.atan2(dy, dx * .55))); ctx.lineTo(ex, ey); if (g > .5) ctx.lineTo(x + dx * g, ey); ctx.stroke(); ctx.restore();
    const tx = x + dx + (dx >= 0 ? 12 : -12); const al = dx >= 0 ? 'left' : 'right';
    text(ctx, str, tx, y + dy - (o.en ? 10 : 0), { size: o.size || 30, font: o.font || 'song', weight: o.weight || 500, align: al, color: o.color || '#eae4d8', alpha: a, reveal: o.reveal ?? smooth(.3, 1, a) });
    if (o.en) text(ctx, o.en.toUpperCase(), tx, y + dy + (o.size || 30) * .75, { size: 15, font: 'latin', weight: 600, align: al, color: o.enColor || 'rgba(200,215,235,.85)', alpha: a, spacing: .2 }); }
  // 大号数字计数器
  function fmtNum(v, digits = 0) { return v.toLocaleString('zh-CN', { minimumFractionDigits: digits, maximumFractionDigits: digits }); }

  G.MP = { W, H, clamp, lerp, inv, smooth, E, prog, env, rng, hash, noise3, fbm, hexRgb, rgba, mix, hsl, timeColor, glow, glowSprite, dot, cam, FONT, font, text, vtext, measure, wrap, grain, vignette, bloom, subtitle, bg, line, partial, label, fmtNum };
})(window);
