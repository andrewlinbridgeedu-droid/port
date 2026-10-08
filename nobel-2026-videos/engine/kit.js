// 四部影片共用的画面部件：星空、地球、片名、片尾、术语牌、计数器。
(function (G) {
  'use strict';
  const { W, H, clamp, lerp, smooth, E, prog, env, rng, glow, dot, text, rgba, mix, font, wrap } = MP;

  // ---------- 星空 ----------
  const STARS = (() => { const r = rng(2026); const a = []; for (let i = 0; i < 900; i++) a.push({ x: r(), y: r(), m: Math.pow(r(), 3), ph: r() * 6.28, sp: .5 + r() * 2, hue: r() }); return a; })();
  function stars(ctx, t, o = {}) {
    const a0 = o.alpha ?? 1, dx = o.dx || 0, dy = o.dy || 0, sc = o.scale || 1;
    ctx.save(); ctx.globalCompositeOperation = 'lighter';
    for (const s of STARS) {
      let x = ((s.x * W * 1.2 + dx * (0.3 + s.m)) % (W * 1.2) + W * 1.2) % (W * 1.2) - W * .1;
      let y = ((s.y * H * 1.2 + dy * (0.3 + s.m)) % (H * 1.2) + H * 1.2) % (H * 1.2) - H * .1;
      if (sc !== 1) { x = W / 2 + (x - W / 2) * sc; y = H / 2 + (y - H / 2) * sc; }
      const tw = .65 + .35 * Math.sin(t * s.sp + s.ph); const b = (.15 + s.m * .85) * tw * a0;
      const col = s.hue < .15 ? '#ffd9a8' : s.hue < .35 ? '#bcd4ff' : '#ffffff';
      if (s.m > .55) glow(ctx, x, y, 4 + s.m * 10, col, b * .5);
      dot(ctx, x, y, .6 + s.m * 1.4, col, b);
    }
    ctx.restore();
  }

  // ---------- 正射投影地球 ----------
  const D2R = Math.PI / 180;
  function ortho(lat, lon, lat0, lon0) {
    const φ = lat * D2R, λ = lon * D2R, φ0 = lat0 * D2R, λ0 = lon0 * D2R;
    const cosc = Math.sin(φ0) * Math.sin(φ) + Math.cos(φ0) * Math.cos(φ) * Math.cos(λ - λ0);
    const x = Math.cos(φ) * Math.sin(λ - λ0);
    const y = Math.cos(φ0) * Math.sin(φ) - Math.sin(φ0) * Math.cos(φ) * Math.cos(λ - λ0);
    return { x, y: -y, vis: cosc > 0, z: cosc };
  }
  function globe(ctx, cx, cy, R, lat0, lon0, o = {}) {
    const a = o.alpha ?? 1; if (a <= 0) return;
    ctx.save(); ctx.globalAlpha = a;
    // 大气辉光
    const ag = ctx.createRadialGradient(cx, cy, R * .9, cx, cy, R * 1.25); ag.addColorStop(0, rgba(o.atmo || '#4aa8ff', .35)); ag.addColorStop(1, rgba(o.atmo || '#4aa8ff', 0));
    ctx.fillStyle = ag; ctx.beginPath(); ctx.arc(cx, cy, R * 1.25, 0, 7); ctx.fill();
    // 海洋
    const og = ctx.createRadialGradient(cx - R * .35, cy - R * .35, R * .1, cx, cy, R); og.addColorStop(0, o.ocean1 || '#123a6b'); og.addColorStop(1, o.ocean2 || '#040b1c');
    ctx.fillStyle = og; ctx.beginPath(); ctx.arc(cx, cy, R, 0, 7); ctx.fill();
    // 经纬网
    if (o.grid !== false) {
      ctx.strokeStyle = rgba(o.gridColor || '#7fb6ff', .13); ctx.lineWidth = 1;
      for (let lat = -60; lat <= 60; lat += 30) { ctx.beginPath(); let pen = false; for (let lon = -180; lon <= 180; lon += 4) { const p = ortho(lat, lon, lat0, lon0); if (p.vis) { const X = cx + p.x * R, Y = cy + p.y * R; pen ? ctx.lineTo(X, Y) : ctx.moveTo(X, Y); pen = true; } else pen = false; } ctx.stroke(); }
      for (let lon = -180; lon < 180; lon += 30) { ctx.beginPath(); let pen = false; for (let lat = -90; lat <= 90; lat += 3) { const p = ortho(lat, lon, lat0, lon0); if (p.vis) { const X = cx + p.x * R, Y = cy + p.y * R; pen ? ctx.lineTo(X, Y) : ctx.moveTo(X, Y); pen = true; } else pen = false; } ctx.stroke(); }
    }
    // 陆地（背面的点压到球缘上，填充近似正确）
    if (G.LAND) {
      ctx.fillStyle = o.land || 'rgba(120,170,230,.28)'; ctx.strokeStyle = o.coast || 'rgba(170,215,255,.75)'; ctx.lineWidth = o.coastW || 1.2;
      for (const poly of G.LAND) {
        let anyVis = false; const pts = poly.map(([lon, lat]) => { const p = ortho(lat, lon, lat0, lon0); if (p.vis) anyVis = true; let x = p.x, y = p.y; if (!p.vis) { const n = Math.hypot(x, y) || 1; x /= n; y /= n; } return [cx + x * R, cy + y * R, p.vis]; });
        if (!anyVis) continue;
        ctx.beginPath(); pts.forEach(([x, y], i) => i ? ctx.lineTo(x, y) : ctx.moveTo(x, y)); ctx.closePath(); ctx.fill();
        ctx.beginPath(); let pen = false; for (const [x, y, v] of pts) { if (v) { pen ? ctx.lineTo(x, y) : ctx.moveTo(x, y); pen = true; } else pen = false; } ctx.stroke();
      }
    }
    // 明暗交界
    const sh = ctx.createRadialGradient(cx - R * .5, cy - R * .5, R * .2, cx, cy, R * 1.05); sh.addColorStop(0, 'rgba(255,255,255,0.06)'); sh.addColorStop(.7, 'rgba(0,0,0,0)'); sh.addColorStop(1, 'rgba(0,0,0,.55)');
    ctx.fillStyle = sh; ctx.beginPath(); ctx.arc(cx, cy, R, 0, 7); ctx.fill();
    ctx.strokeStyle = rgba(o.atmo || '#4aa8ff', .6); ctx.lineWidth = 1.5; ctx.beginPath(); ctx.arc(cx, cy, R, 0, 7); ctx.stroke();
    ctx.restore();
  }
  function geo(lat, lon, cx, cy, R, lat0, lon0) { const p = ortho(lat, lon, lat0, lon0); return { x: cx + p.x * R, y: cy + p.y * R, vis: p.vis, z: p.z }; }

  // ---------- 片名 ----------
  function titleCard(ctx, t, d, o) {
    const c = o.color || '#e9d9b0';
    const a = env(t, 0, d + 2, .8, .01);
    // 中央横向光线
    const lw = E.outExpo(clamp(t / 1.6)) * 520;
    ctx.save(); ctx.globalCompositeOperation = 'lighter';
    const lg = ctx.createLinearGradient(W / 2 - lw, 0, W / 2 + lw, 0); lg.addColorStop(0, rgba(c, 0)); lg.addColorStop(.5, rgba(c, .9 * a)); lg.addColorStop(1, rgba(c, 0));
    ctx.fillStyle = lg; ctx.fillRect(W / 2 - lw, H / 2 + 92, lw * 2, 1.6);
    ctx.fillRect(W / 2 - lw * .6, H / 2 - 118, lw * 1.2, 1);
    ctx.restore();
    text(ctx, o.kicker, W / 2, H / 2 - 150, { size: 30, font: 'song', weight: 500, spacing: .6, color: c, alpha: a * .9, reveal: prog(t, .2, 1.6, E.out) });
    const s = 1 + .04 * (1 - E.out(clamp(t / 3)));
    ctx.save(); ctx.translate(W / 2, H / 2 - 10); ctx.scale(s, s);
    text(ctx, o.title, 0, 0, { size: o.titleSize || 150, font: o.titleFont || 'song', weight: o.titleWeight || 700, spacing: o.titleSpacing ?? .18, color: '#fbf6ea', glow: 28, glowColor: c, alpha: a, reveal: prog(t, .5, 2.4, E.out), soft: 2 });
    ctx.restore();
    text(ctx, o.sub, W / 2, H / 2 + 140, { size: 34, font: 'kai', spacing: .25, color: '#d7d2c6', alpha: a * .85, reveal: prog(t, 1.4, 3.0, E.out) });
  }

  // ---------- 片尾：颁奖词 ----------
  function endCard(ctx, t, d, o) {
    const c = o.color || '#e9d9b0';
    const a = smooth(0, 1.2, t);
    text(ctx, o.prize, W / 2, 250, { size: 40, font: 'song', weight: 600, spacing: .4, color: c, alpha: a, glow: 16, glowColor: c, reveal: prog(t, 0, 1.5, E.out) });
    const lines = wrap(ctx, o.zh, 'song', 50, 1300);
    lines.forEach((l, i) => text(ctx, l, W / 2, 380 + i * 78, { size: 50, font: 'song', weight: 500, spacing: .06, color: '#fbf6ea', alpha: a, reveal: prog(t, .8 + i * .5, 2.6 + i * .5, E.out) }));
    const ey = 380 + lines.length * 78 + 40;
    const el = wrap(ctx, o.en, 'latinI', 34, 1400);
    el.forEach((l, i) => text(ctx, l, W / 2, ey + i * 46, { size: 34, font: 'latinI', color: '#bdb6a6', alpha: a * .9 * smooth(2.2, 3.4, t) }));
    const ly = ey + el.length * 46 + 70;
    text(ctx, o.who, W / 2, ly, { size: 30, font: 'kai', color: '#d8d2c4', alpha: a * smooth(3, 4, t), spacing: .1 });
    text(ctx, o.src, W / 2, H - 70, { size: 22, font: 'kai', color: '#9a958a', alpha: a * smooth(3.5, 4.5, t), spacing: .05 });
    // 结尾整体淡出
    const fo = smooth(d - 1.4, d - .05, t); if (fo > 0) { ctx.fillStyle = `rgba(0,0,0,${fo})`; ctx.fillRect(0, 0, W, H); }
  }

  // ---------- 术语牌（中英对照）：细线 + 宋体 + 字距拉开的英文小字 ----------
  function term(ctx, zh, en, x, y, o = {}) {
    const a = o.alpha ?? 1; if (a <= 0) return; const c = o.color || '#9fd8ff';
    const size = o.size || 36; const align = o.align || 'center'; const rv = o.reveal ?? clamp(a * 1.2);
    const wz = MP.measure(ctx, zh, 'song', size, 600) + size * .08 * [...zh].length;
    ctx.save(); ctx.globalAlpha = a; ctx.strokeStyle = rgba(c, .9); ctx.lineWidth = 1.5;
    if (align === 'center') { const lw = 46 * E.out(clamp(a * 1.3)); ctx.beginPath(); ctx.moveTo(x - lw / 2, y - size * .95); ctx.lineTo(x + lw / 2, y - size * .95); ctx.stroke(); }
    else { const bx = align === 'left' ? x - 18 : x + 18; ctx.beginPath(); ctx.moveTo(bx, y - size * .55); ctx.lineTo(bx, y + (en ? size * 1.05 : size * .5)); ctx.stroke(); }
    ctx.restore();
    text(ctx, zh, x, y, { size, font: 'song', weight: 600, color: o.textColor || '#f7f2e8', alpha: a, spacing: .08, align, reveal: rv, glow: o.glow || 0, glowColor: c });
    if (en) text(ctx, en.toUpperCase(), x, y + size * .95, { size: Math.max(15, size * .46), font: 'latin', weight: 600, color: rgba(c, 1), alpha: a * .9, spacing: .22, align });
  }
  // ---------- 章节标记（左上）与系列标识（右上） ----------
  function chapter(ctx, idx, zh, t, o = {}) {
    const a = (o.alpha ?? 1) * (smooth(.2, 1.2, t) * (1 - smooth(5.2, 6.4, t)) * .85 + .0);
    if (a <= 0.01) return; const c = o.color || '#bfe6ff';
    text(ctx, String(idx).padStart(2, '0'), 72, 74, { size: 34, font: 'latin', weight: 600, color: c, alpha: a, align: 'left' });
    ctx.save(); ctx.globalAlpha = a; ctx.strokeStyle = rgba(c, .8); ctx.lineWidth = 1; const lw = 70 * E.out(smooth(.3, 1.4, t)); ctx.beginPath(); ctx.moveTo(122, 74); ctx.lineTo(122 + lw, 74); ctx.stroke(); ctx.restore();
    text(ctx, zh, 210, 74, { size: 28, font: 'song', weight: 500, color: o.textColor || '#efe9dc', alpha: a, align: 'left', spacing: .3, reveal: smooth(.4, 1.6, t) });
    if (o.brand) text(ctx, o.brand, W - 72, 74, { size: 19, font: 'latin', weight: 600, color: rgba(c, .9), alpha: a * .8, align: 'right', spacing: .32 });
  }

  // ---------- 大号计数 ----------
  function counter(ctx, value, x, y, o = {}) {
    const a = o.alpha ?? 1; if (a <= 0) return;
    const s = o.format ? o.format(value) : MP.fmtNum(Math.round(value));
    const size = o.size || 110;
    const w = text(ctx, s, x, y, { size, font: o.font || 'song', weight: o.weight || 300, color: o.color || '#ffffff', alpha: a, glow: 20, glowColor: o.glowColor || '#7fd0ff', align: o.align || 'center' });
    if (o.unit) text(ctx, o.unit, o.align === 'left' ? x + w + 16 : x + w / 2 + 16, y + size * .14, { size: size * .34, font: 'song', weight: 500, align: 'left', color: o.unitColor || '#cfe8ff', alpha: a });
  }

  // 两点之间的二次曲线采样
  function arcPts(x1, y1, x2, y2, bend = .25, n = 60) { const mx = (x1 + x2) / 2, my = (y1 + y2) / 2; const nx = -(y2 - y1), ny = x2 - x1; const cx = mx + nx * bend, cy = my + ny * bend; const out = []; for (let i = 0; i <= n; i++) { const u = i / n; out.push([(1 - u) * (1 - u) * x1 + 2 * (1 - u) * u * cx + u * u * x2, (1 - u) * (1 - u) * y1 + 2 * (1 - u) * u * cy + u * u * y2]); } return out; }

  // 一束会“流动”的光线（沿折线移动的亮头 + 渐隐尾巴）
  function comet(ctx, pts, u, color, o = {}) {
    const n = pts.length - 1; if (n < 1) return; const tail = o.tail ?? .25; const w = o.width ?? 3;
    const head = clamp(u) * n; const t0 = Math.max(0, head - tail * n);
    ctx.save(); ctx.globalCompositeOperation = 'lighter'; ctx.lineCap = 'round';
    const steps = 24;
    for (let k = 0; k < steps; k++) {
      const s0 = lerp(t0, head, k / steps), s1 = lerp(t0, head, (k + 1) / steps);
      const p0 = at(pts, s0), p1 = at(pts, s1); ctx.strokeStyle = rgba(color, (o.alpha ?? 1) * Math.pow((k + 1) / steps, 1.6)); ctx.lineWidth = w * (.3 + .7 * (k + 1) / steps);
      ctx.beginPath(); ctx.moveTo(p0[0], p0[1]); ctx.lineTo(p1[0], p1[1]); ctx.stroke();
    }
    const p = at(pts, head); if (u > 0 && u < 1.02) glow(ctx, p[0], p[1], o.headR ?? 18, color, (o.alpha ?? 1));
    ctx.restore(); return p;
  }
  function at(pts, s) { const i = Math.min(pts.length - 2, Math.max(0, Math.floor(s))); const f = clamp(s - i); return [lerp(pts[i][0], pts[i + 1][0], f), lerp(pts[i][1], pts[i + 1][1], f)]; }

  G.KIT = { stars, globe, geo, ortho, titleCard, endCard, term, chapter, counter, arcPts, comet, at };
})(window);
