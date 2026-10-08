// 2026 诺贝尔物理学奖 ·《以冰为眼》——高能天体中微子与冰立方
(function () {
  const { W, H, clamp, lerp, smooth, E, prog, env, rng, hash, glow, dot, text, rgba, mix, cam, timeColor, line, partial, label, fbm, noise3 } = MP;
  const { stars, globe, geo, titleCard, endCard, term, counter, arcPts, comet } = KIT;
  const CY = '#7fd8ff', BLUE = '#3d8bff', ICE = '#bfe6ff', GOLD = '#ffcf7a', RED = '#ff6a5a', AMBER = '#ffb347';

  // ---------- 冰立方几何（单位：米；y 向下为正，阵列中心约在冰下 1950 米） ----------
  const STRINGS = (() => {
    const s = []; const sp = 125;
    for (let q = -5; q <= 5; q++) for (let r = -5; r <= 5; r++) {
      const k = -q - r; if (Math.abs(k) > 5) continue;
      const x = sp * (q + r / 2), z = sp * (r * Math.sqrt(3) / 2);
      // 去掉一侧边角，得到 78 根常规缆绳的不规则六边形
      if ((r === -5 && q >= 2) || (q === 5 && r <= -2) || (k === -5 && r <= -1 && q >= 4) || (r === 5 && q <= -4) || (q === -5 && r >= 3)) continue;
      s.push({ x, z, deep: false });
    }
    while (s.length > 78) s.pop();
    const dc = [[40, 30], [-45, 35], [5, -55], [70, -35], [-75, -25], [30, 90], [-30, -95], [95, 60]];
    for (const [x, z] of dc) s.push({ x, z, deep: true });
    return s;
  })();
  const DOMS = (() => {
    const d = [];
    STRINGS.forEach((s, si) => {
      if (!s.deep) for (let k = 0; k < 60; k++) d.push({ x: s.x, y: -500 + k * 17, z: s.z, si });
      else { for (let k = 0; k < 10; k++) d.push({ x: s.x, y: -420 + k * 10, z: s.z, si }); for (let k = 0; k < 50; k++) d.push({ x: s.x, y: 150 + k * 7, z: s.z, si }); }
    });
    return d;
  })();

  function space(ctx, t, o = {}) {
    const g = ctx.createRadialGradient(W * .5, H * .45, 0, W * .5, H * .5, W * .8);
    g.addColorStop(0, o.c1 || '#081226'); g.addColorStop(.55, o.c2 || '#030714'); g.addColorStop(1, '#010205');
    ctx.fillStyle = g; ctx.fillRect(0, 0, W, H);
    if ((o.neb ?? .55) > 0) GLFX.layer(ctx, 'nebula', { T: t + (o.seed || 0) * 40, C1: o.n1 || '#0b2a6b', C2: o.n2 || '#3a1d6e', C3: o.n3 || '#2a7fb8', S: o.ns || 1.6, D: .25, A: o.neb ?? .55, MODE: 0, OFF: [(o.seed || 0) * 3.7 + t * .004, (o.seed || 0) * 1.3] });
    stars(ctx, t, { alpha: o.stars ?? 1, dx: (o.drift ?? 6) * t });
  }

  // 冰立方阵列（可带事件着色）
  function drawArray(ctx, c, o = {}) {
    const a = o.alpha ?? 1; if (a <= 0) return;
    const showStr = o.strings ?? STRINGS.length;
    ctx.save(); ctx.globalCompositeOperation = 'lighter';
    // 缆绳
    ctx.lineWidth = 1;
    for (let i = 0; i < STRINGS.length; i++) {
      const s = STRINGS[i]; const grow = clamp(showStr - i); if (grow <= 0) continue;
      const p0 = c.p(s.x, -560, s.z), p1 = c.p(s.x, lerp(-560, 520, grow), s.z);
      ctx.strokeStyle = rgba(s.deep ? '#9fc6ff' : '#7fa9d9', .16 * a); ctx.beginPath(); ctx.moveTo(p0.x, p0.y); ctx.lineTo(p1.x, p1.y); ctx.stroke();
    }
    const hits = o.hits;
    for (let i = 0; i < DOMS.length; i++) {
      const d = DOMS[i]; const grow = clamp(showStr - d.si); if (grow <= 0) continue;
      if ((d.y + 560) / 1080 > grow) continue;
      const p = c.p(d.x, d.y, d.z); const s = p.s;
      const h = hits && hits[i];
      if (h && h.a > 0) {
        const r = (5 + 22 * h.q) * s * (o.hitScale || 1);
        glow(ctx, p.x, p.y, r * 2.6, h.col, .55 * h.a * a);
        dot(ctx, p.x, p.y, r, h.col, .95 * h.a * a);
      } else {
        const base = o.domColor || '#a9cfff';
        dot(ctx, p.x, p.y, Math.max(.7, 2.2 * s), base, (o.domAlpha ?? .55) * a * (o.dim ? o.dim(d, i) : 1));
      }
    }
    ctx.restore();
  }

  // 由一条径迹或一个簇射计算各光学模块的“受光时间”和“受光量”
  function trackHits(P0, dir, tNow, o = {}) {
    const hits = new Array(DOMS.length); const v = 300; // 米/单位时间
    const len = o.len ?? 2200;
    for (let i = 0; i < DOMS.length; i++) {
      const d = DOMS[i]; const rx = d.x - P0[0], ry = d.y - P0[1], rz = d.z - P0[2];
      const sAlong = rx * dir[0] + ry * dir[1] + rz * dir[2];
      if (sAlong < -60 || sAlong > len) continue;
      const px = rx - sAlong * dir[0], py = ry - sAlong * dir[1], pz = rz - sAlong * dir[2];
      const dp = Math.hypot(px, py, pz); if (dp > 170) continue;
      const th = (Math.max(0, sAlong) + dp * 1.1) / v; // 到达时间
      const q = Math.exp(-dp / 55) * (0.6 + 0.4 * hash(i, 7));
      const a = smooth(th, th + .25, tNow);
      hits[i] = { q, a, col: timeColor(th / (len / v + .6)) };
    }
    return hits;
  }
  function cascadeHits(C, tNow, o = {}) {
    const hits = new Array(DOMS.length); const R = o.R ?? 240;
    for (let i = 0; i < DOMS.length; i++) {
      const d = DOMS[i]; const r = Math.hypot(d.x - C[0], d.y - C[1], d.z - C[2]); if (r > R) continue;
      const th = r / 260; const q = Math.exp(-r / (R * .32)) * (0.7 + 0.3 * hash(i, 3));
      hits[i] = { q, a: smooth(th, th + .2, tNow), col: timeColor(th / (R / 260 + .2)) };
    }
    return hits;
  }

  // 指纹：同心而略带扰动的脊线，裁在指腹椭圆内
  const RIDGES = (() => {
    const out = []; const cx = 0, cy = 20;
    for (let k = 0; k < 30; k++) {
      const pts = []; const r0 = 10 + k * 8.6;
      for (let i = 0; i <= 220; i++) {
        const th = i / 220 * Math.PI * 2;
        const wob = 1 + .07 * MP.noise3(Math.cos(th) * 1.3, Math.sin(th) * 1.3, k * .13) + .03 * Math.sin(th * 3 + k * .4);
        const loop = th > Math.PI * .35 && th < Math.PI * .65 ? (1 + .35 * Math.sin((th - Math.PI * .35) / (Math.PI * .3) * Math.PI) * clamp((k - 6) / 14)) : 1;
        const r = r0 * wob * loop;
        const x = cx + Math.cos(th) * r * .82, y = cy + Math.sin(th) * r * 1.05;
        const inside = (x * x) / (205 * 205) + ((y - 10) * (y - 10)) / (265 * 265) < 1;
        const gap = MP.noise3(th * 2.2, k * .7, 4.1) > .42;
        pts.push(inside && !gap ? [x, y] : null);
      }
      out.push(pts);
    }
    return out;
  })();
  function fingerprint(ctx, x, y, a, grow, t) {
    if (a <= 0) return;
    ctx.save(); ctx.translate(x, y); ctx.globalCompositeOperation = 'lighter'; ctx.lineCap = 'round';
    RIDGES.forEach((pts, k) => {
      const kk = clamp(grow * 34 - k); if (kk <= 0) return;
      ctx.strokeStyle = rgba(k % 5 === 0 ? '#cfefff' : '#8fd2ff', (.22 + .25 * (1 - k / 30)) * a * kk); ctx.lineWidth = 2.2;
      ctx.beginPath(); let pen = false; for (const p of pts) { if (p) { pen ? ctx.lineTo(p[0], p[1]) : ctx.moveTo(p[0], p[1]); pen = true; } else pen = false; } ctx.stroke();
    });
    ctx.restore();
    // 指腹轮廓光
    ctx.save(); ctx.globalAlpha = a * .5; ctx.strokeStyle = 'rgba(160,220,255,.55)'; ctx.lineWidth = 1.2; ctx.beginPath(); ctx.ellipse(x, y + 10, 215, 275, 0, 0, Math.PI * 2); ctx.stroke(); ctx.restore();
  }

  // ---------- 场景 ----------
  const scenes = {};

  // 1. 幽灵之雨
  scenes.rain = (ctx, S) => {
    const t = S.t, c1 = S.cue(1);
    space(ctx, t, { stars: .8 });
    const pB = prog(t, c1 - .6, c1 + 1.4);
    // 指纹与 1 cm² 方框
    const fa = (1 - pB) * smooth(.1, 1.4, t);
    const fx = 700, fy = 470;
    fingerprint(ctx, fx, fy, fa, prog(t, .1, 3.2, E.out), t);
    if (fa > 0) {
      const sq = 236, k = E.out(smooth(2.0, 3.0, t));
      ctx.save(); ctx.globalAlpha = fa * k; ctx.strokeStyle = '#ffd89a'; ctx.lineWidth = 1.6; ctx.shadowColor = GOLD; ctx.shadowBlur = 14;
      const L = sq * k; ctx.beginPath(); ctx.rect(fx - L / 2, fy - L / 2, L, L); ctx.stroke(); ctx.restore();
      label(ctx, '1 平方厘米', fx + sq / 2, fy - sq / 2, { alpha: fa * smooth(2.6, 3.4, t), dx: 110, dy: -90, size: 28, en: 'one square centimetre', color: '#ffe6bd' });
    }
    // 地球
    const ga = pB; const gR = lerp(120, 300, E.out(pB));
    if (ga > 0) globe(ctx, 700, 500, gR, 15, 100 + t * 4, { alpha: ga });
    // 中微子流：自右上而来，笔直穿过一切
    ctx.save(); ctx.globalCompositeOperation = 'lighter';
    const N = 260, ang = Math.PI * 1.13, dx = Math.cos(ang), dy = Math.sin(ang), nx = -dy, ny = dx, L = 2600;
    const dens = smooth(.0, 1.5, t);
    for (let i = 0; i < N; i++) {
      if (hash(i, 1) > dens) continue;
      const off = (hash(i, 2) - .5) * 2400, sp = 1700 + hash(i, 3) * 900, ph = hash(i, 4) * L;
      const s = ((t * sp + ph) % L) - L / 2; const len = 60 + hash(i, 5) * 140;
      const x = W / 2 + nx * off + dx * s, y = H / 2 + ny * off + dy * s;
      const g = ctx.createLinearGradient(x, y, x - dx * len, y - dy * len); g.addColorStop(0, rgba(CY, .75)); g.addColorStop(1, rgba(CY, 0));
      ctx.strokeStyle = g; ctx.lineWidth = 1.1 + hash(i, 6) * 1.3; ctx.beginPath(); ctx.moveTo(x, y); ctx.lineTo(x - dx * len, y - dy * len); ctx.stroke();
    }
    ctx.restore();
    // 计数器
    const ca = smooth(.8, 1.8, t) * (1 - smooth(c1 - .4, c1 + .4, t));
    counter(ctx, 650 * E.out(prog(t, .9, c1 - 1.5, x => x)), 1240, 450, { alpha: ca, size: 170, unit: '亿', align: 'left', format: v => String(Math.round(v)) });
    text(ctx, '个中微子 · 每秒 · 每平方厘米', 1245, 575, { size: 34, font: 'kai', align: 'left', color: '#cfe6ff', alpha: ca * .9, spacing: .15 });
    text(ctx, '绝大部分来自太阳的核聚变', 1245, 625, { size: 26, font: 'kai', align: 'left', color: '#8fb3d6', alpha: ca * .8 });
    // 幽灵粒子
    const ta = smooth(c1 + .4, c1 + 1.8, t);
    if (ta > 0) {
      for (let k = 3; k >= 1; k--) text(ctx, '幽灵粒子', 1380 + k * 6 * Math.sin(t * 2 + k), 400 + k * 3, { size: 120, font: 'brush', color: k === 1 ? CY : '#3b6cff', alpha: ta * .18 });
      text(ctx, '幽灵粒子', 1380, 400, { size: 120, font: 'brush', color: '#eaf6ff', alpha: ta, glow: 30, glowColor: CY });
      const tags = ['不带电', '几乎没有质量', '可穿透地球'];
      tags.forEach((s, i) => text(ctx, s, 1380, 540 + i * 58, { size: 34, font: 'kai', color: '#bfe2ff', alpha: smooth(c1 + .4 + i * 1.1, c1 + 1.2 + i * 1.1, t), spacing: .2 }));
    }
  };

  // 2. 片名
  scenes.title = (ctx, S) => {
    const t = S.t; space(ctx, t, { c1: '#0b1a33', stars: .7 });
    // 冰晶微尘
    ctx.save(); ctx.globalCompositeOperation = 'lighter';
    for (let i = 0; i < 120; i++) { const x = (hash(i, 9) * W + t * 12 * (hash(i, 8) - .3)) % W, y = (hash(i, 10) * H + t * 20 * hash(i, 11)) % H; glow(ctx, x, y, 3 + hash(i, 12) * 8, ICE, .25 * smooth(0, 1, t)); }
    ctx.restore();
    titleCard(ctx, t, S.d, { kicker: '2026 诺贝尔物理学奖', title: '以冰为眼', sub: '高能天体中微子与冰立方', color: '#bfe6ff' });
  };

  // 3. 宇宙的信使
  scenes.messengers = (ctx, S) => {
    const t = S.t, c1 = S.cue(1), c2 = S.cue(2), c3 = S.cue(3);
    space(ctx, t, { stars: .9, drift: 3, neb: .45, seed: 1, n1: '#1a1446', n2: '#0d2c5e', n3: '#4b2a7a' });
    const sx = 400, sy = 470, ex = 1620, ey = 500;
    // 尘埃云（吸光）+ 边缘微光
    const da = smooth(c2 - 1.2, c2 + .6, t);
    if (da > 0) {
      const mc = GLFX.uv(1020, 300), mr = [400 / H, 250 / H];
      GLFX.layer(ctx, 'nebula', { T: t * .5, C1: '#7a3a20', C2: '#b8682e', C3: '#ffc080', S: 3.0, D: .6, A: 2.3 * da, MODE: 0, OFF: [3.6, 1.2], MC: mc, MR: mr });
      GLFX.layer(ctx, 'nebula', { T: t * .5, C1: '#050302', C2: '#000', C3: '#000', S: 3.6, D: .35, A: .75 * da, MODE: 1, OFF: [1.1, 4.7], MC: mc, MR: [mr[0] * .85, mr[1] * .85] }, { mode: 'source-over' });
      label(ctx, '尘埃与气体', 1200, 190, { alpha: da * .9, dx: 90, dy: -50, size: 26, en: 'dust & gas' });
    }
    // 磁场线：流动的虚线
    const ma = smooth(c2 - 1.2, c2 + .6, t);
    if (ma > 0) {
      ctx.save(); ctx.lineWidth = 1.3; ctx.setLineDash([3, 14]); ctx.lineDashOffset = -t * 60;
      for (let k = 0; k < 6; k++) { ctx.strokeStyle = rgba('#b79cff', (.18 + .05 * k) * ma); ctx.beginPath(); for (let x = 620; x <= 1440; x += 8) { const y = 640 + k * 34 + 36 * Math.sin(x / 80 + k * 1.1 + t * .5) + 14 * Math.sin(x / 31 + k); x === 620 ? ctx.moveTo(x, y) : ctx.lineTo(x, y); } ctx.stroke(); }
      ctx.restore();
      label(ctx, '星际磁场', 820, 805, { alpha: ma * .9, dx: 60, dy: 75, size: 26, en: 'magnetic fields' });
    }
    // 黑洞：先涂黑阴影，再叠加吸积盘
    const sa = smooth(0, 1.6, t);
    const bp = GLFX.uv(sx, sy);
    ctx.fillStyle = '#000'; ctx.beginPath(); ctx.arc(sx, sy, 52, 0, Math.PI * 2); ctx.fill();
    GLFX.layer(ctx, 'blackhole', { T: t, P: bp, SZ: 52 / H, TILT: .22, A: 1.25 * sa, JET: smooth(.5, 2.5, t) });
    term(ctx, '宇宙加速器', 'cosmic accelerator', sx, 760, { alpha: sa * env(t, .6, S.d, 1, .6), color: GOLD, size: 36 });
    text(ctx, '活动星系核 · 超大质量黑洞', sx, 838, { size: 24, font: 'kai', color: '#d9c8a6', alpha: sa * env(t, 1, S.d, 1, .6) * .9 });
    const ba = smooth(1.2, 2.4, t) * (1 - smooth(c2 - 1.4, c2 - .6, t));
    text(ctx, '粒子能量可达', 1080, 400, { size: 32, font: 'kai', color: '#e8dcc0', alpha: ba, spacing: .2 });
    text(ctx, '人造加速器的百万倍', 1080, 470, { size: 60, font: 'song', weight: 700, color: '#fff0d0', alpha: ba, glow: 22, glowColor: GOLD, spacing: .06 });
    // 疑问
    const qa = smooth(c1, c1 + .8, t) * (1 - smooth(c2 - 1.2, c2 - .4, t));
    if (qa > 0) { text(ctx, '在哪里？', 1080, 600, { size: 44, font: 'song', weight: 500, color: '#ffffff', alpha: qa, spacing: .3 }); text(ctx, '如何运作？', 1080, 670, { size: 44, font: 'song', weight: 500, color: '#ffffff', alpha: qa * smooth(c1 + 1, c1 + 1.8, t), spacing: .3 }); }
    // 地球
    const ea = smooth(.5, 1.5, t);
    globe(ctx, ex, ey, 74, 20, 120 + t * 10, { alpha: ea, grid: false });
    text(ctx, '地球', ex, ey + 118, { size: 26, font: 'song', color: '#cfe6ff', alpha: ea * .85, spacing: .3 });
    // 宇宙线：被磁场拨乱，错过地球
    const pu = prog(t, c2 + .1, c2 + 4.6, x => x);
    if (pu > 0) { const pts = []; for (let k = 0; k <= 160; k++) { const u = k / 160; const x = lerp(sx + 60, 1560, u); const y = sy + 60 + 230 * smooth(0, .3, u) + 70 * Math.sin(u * 22) * smooth(.25, .45, u) * (1 - smooth(.7, .9, u)) - 420 * smooth(.62, 1, u); pts.push([x, y]); } comet(ctx, pts, pu, RED, { tail: .45, width: 4, headR: 22 }); label(ctx, '宇宙线：带电，被磁场偏转', 1110, 745, { alpha: smooth(c2 + 2.2, c2 + 3.2, t), dx: 110, dy: 105, size: 28, color: '#ffc6bd', en: 'cosmic rays' }); }
    // 光：被尘埃吞没
    const lu = prog(t, c2 + 1.0, c2 + 3.6, x => x);
    if (lu > 0) { const pts = [[sx + 50, sy - 20], [1040, 300]]; const hp = comet(ctx, pts, lu, GOLD, { tail: .45, width: 3, headR: 20, alpha: 1 - smooth(.78, 1, lu) }); if (lu > .75) for (let k = 0; k < 8; k++) glow(ctx, 960 + hash(k, 5) * 90, 300 + (hash(k, 6) - .5) * 70, 8, GOLD, (1 - smooth(.8, 1, lu)) * .6); label(ctx, '光：被尘埃吸收', 900, 330, { alpha: smooth(c2 + 2.6, c2 + 3.6, t), dx: -100, dy: -100, size: 28, color: '#ffe4b8', en: 'light' }); }
    // 中微子：笔直抵达
    const nu = prog(t, c3 + .1, c3 + 2.2, E.inOut);
    if (nu > 0) {
      comet(ctx, [[sx + 40, sy + 4], [ex - 74, ey]], nu, CY, { tail: 1, width: 5, headR: 32 });
      if (nu >= 1) { const f = smooth(c3 + 2.2, c3 + 2.5, t) * (1 - smooth(c3 + 2.6, c3 + 4.2, t)); glow(ctx, ex, ey, 240, CY, f * .8); }
      term(ctx, '中微子：不偏不折，笔直而来', 'neutrinos', 1010, 560, { alpha: smooth(c3 + 1, c3 + 2, t), color: CY, size: 34 });
    }
  };

  // 4. 以冰为眼
  scenes.ice = (ctx, S) => {
    const t = S.t, c1 = S.cue(1), c2 = S.cue(2);
    // A：小探测器几乎什么也抓不到
    if (t < c1 + 1) {
      const a = 1 - smooth(c1 - .3, c1 + .8, t);
      space(ctx, t, { stars: .7 });
      const sz = lerp(70, 520, E.inOut(prog(t, 2.2, c1 - .2, x => x)));
      const c = cam({ yaw: .6 + t * .15, pitch: -.35, dist: 1600, fov: 1400 });
      const v = [[-1, -1, -1], [1, -1, -1], [1, 1, -1], [-1, 1, -1], [-1, -1, 1], [1, -1, 1], [1, 1, 1], [-1, 1, 1]].map(([x, y, z]) => c.p(x * sz / 2, y * sz / 2, z * sz / 2));
      const ed = [[0, 1], [1, 2], [2, 3], [3, 0], [4, 5], [5, 6], [6, 7], [7, 4], [0, 4], [1, 5], [2, 6], [3, 7]];
      ctx.save(); ctx.globalAlpha = a; ctx.strokeStyle = rgba(ICE, .8); ctx.lineWidth = 1.6; ctx.shadowColor = CY; ctx.shadowBlur = 12; for (const [i, j] of ed) { ctx.beginPath(); ctx.moveTo(v[i].x, v[i].y); ctx.lineTo(v[j].x, v[j].y); ctx.stroke(); } ctx.restore();
      ctx.save(); ctx.globalCompositeOperation = 'lighter';
      for (let i = 0; i < 90; i++) { const off = (hash(i, 2) - .5) * 1400, sp = 1500 + hash(i, 3) * 700, ph = hash(i, 4) * 2400; const s = ((t * sp + ph) % 2400) - 1200; const x = W / 2 + off * .85 - s * .5, y = H / 2 + off * .5 + s * .85; ctx.strokeStyle = rgba(CY, .5 * a); ctx.lineWidth = 1.2; ctx.beginPath(); ctx.moveTo(x, y); ctx.lineTo(x + 50, y - 85); ctx.stroke(); }
      ctx.restore();
      text(ctx, '绝大多数中微子穿行而过，不留痕迹', W / 2, 140, { size: 40, font: 'kai', color: '#d6ecff', alpha: a * smooth(.5, 1.5, t) });
      term(ctx, '1 立方公里', 'one cubic kilometre', W / 2, 860, { alpha: a * smooth(c1 - 2.2, c1 - 1.2, t), color: CY, size: 40 });
      if (a < 1) { ctx.fillStyle = `rgba(0,0,0,${1 - a})`; ctx.fillRect(0, 0, W, H); }
    }
    // B：南极，潜入冰下
    if (t >= c1 - .4 && t < c2 + 1.2) {
      const a = smooth(c1 - .4, c1 + .6, t) * (1 - smooth(c2 - .2, c2 + 1.0, t));
      ctx.save(); ctx.globalAlpha = a;
      const dive = E.inOut(prog(t, c1 + 2.4, c2 - .1, x => x));
      const k = .55, horizon = lerp(600, 300 - 1450 * k, dive);
      if (horizon > 0) {
        ctx.save(); ctx.beginPath(); ctx.rect(0, 0, W, horizon); ctx.clip();
        const sky = ctx.createLinearGradient(0, 0, 0, horizon); sky.addColorStop(0, '#01040c'); sky.addColorStop(1, '#0b2038'); ctx.fillStyle = sky; ctx.fillRect(0, 0, W, horizon);
        stars(ctx, t, { alpha: .8 });
        GLFX.layer(ctx, 'aurora', { T: t, HZ: 1 - horizon / H, A: .8 });
        ctx.restore();
      }
      ctx.save(); ctx.beginPath(); ctx.rect(0, Math.max(0, horizon), W, H); ctx.clip();
      GLFX.layer(ctx, 'icevol', { T: t, DEPTH: .15 + dive * .8, A: 1 }, { mode: 'source-over' });
      ctx.restore();
      if (horizon > -40) {
        const sg = ctx.createLinearGradient(0, horizon - 2, 0, horizon + 40); sg.addColorStop(0, 'rgba(240,248,255,.95)'); sg.addColorStop(1, 'rgba(200,230,250,0)'); ctx.fillStyle = sg; ctx.fillRect(0, horizon - 2, W, 42);
        // 冰立方实验室剪影
        ctx.fillStyle = '#16263a'; const bx = 1180; ctx.fillRect(bx, horizon - 46, 190, 34); ctx.fillRect(bx + 20, horizon - 12, 8, 12); ctx.fillRect(bx + 160, horizon - 12, 8, 12); ctx.fillRect(bx + 30, horizon - 78, 26, 32); ctx.fillRect(bx + 134, horizon - 78, 26, 32);
        text(ctx, '南极点 · 冰立方实验室', bx + 95, horizon - 112, { size: 26, font: 'song', color: '#e6f2ff', alpha: smooth(c1 + .5, c1 + 1.5, t) * (1 - dive * 3), spacing: .15 });
      }
      // 浅层气泡
      ctx.save(); ctx.globalCompositeOperation = 'lighter';
      for (let i = 0; i < 320; i++) { const depth = hash(i, 51) * 1600; const y = horizon + depth * k; if (y < -10 || y > H + 10) continue; const x = hash(i, 52) * W + 6 * Math.sin(t + i); const bub = 1 - smooth(900, 1400, depth); if (bub <= .02) continue; ctx.strokeStyle = rgba('#ffffff', .45 * bub); ctx.lineWidth = 1; ctx.beginPath(); ctx.arc(x, y, 1.5 + hash(i, 53) * 3.5, 0, Math.PI * 2); ctx.stroke(); }
      ctx.restore();
      // 深度标尺
      ctx.strokeStyle = 'rgba(220,240,255,.55)'; ctx.lineWidth = 1; ctx.beginPath(); ctx.moveTo(150, Math.max(0, horizon)); ctx.lineTo(150, H); ctx.stroke();
      for (let m = 0; m <= 2500; m += 250) { const y = horizon + m * k; if (y < 20 || y > H - 20) continue; const major = m % 500 === 0; ctx.beginPath(); ctx.moveTo(major ? 136 : 143, y); ctx.lineTo(150, y); ctx.stroke(); if (major) text(ctx, `${m} 米`, 166, y, { size: 22, font: 'song', align: 'left', color: '#d8ecff', alpha: .85 }); }
      // 探测区与“预览”的缆绳
      const z0 = horizon + 1450 * k, z1 = horizon + 2450 * k; const za = smooth(.55, .9, dive);
      if (za > 0) {
        ctx.save(); ctx.globalAlpha = a * za; ctx.strokeStyle = 'rgba(170,225,255,.55)'; ctx.setLineDash([8, 8]); ctx.strokeRect(240, z0, W - 300, z1 - z0); ctx.setLineDash([]); ctx.restore();
        ctx.save(); ctx.globalCompositeOperation = 'lighter'; for (let j = 0; j < 22; j++) { const x = 300 + j * (W - 420) / 21; for (let m = 1450; m <= 2450; m += 34) { const y = horizon + m * k; dot(ctx, x, y, 1.8, '#bfe8ff', .55 * za * a); } } ctx.restore();
        label(ctx, '1450 — 2450 米：最清澈的古冰', 1560, z0, { alpha: za * a, dx: -90, dy: -70, size: 30, en: 'detector depth' });
      }
      text(ctx, '浅层冰中多气泡，越深越清澈', W / 2 + 160, 170, { size: 34, font: 'song', color: '#f2f8ff', alpha: smooth(.15, .3, dive) * (1 - smooth(.5, .65, dive)), spacing: .12 });
      ctx.restore();
    }
    // C：阵列
    if (t >= c2 - .2) {
      const a = smooth(c2 - .2, c2 + .8, t);
      ctx.save(); ctx.globalAlpha = a;
      GLFX.layer(ctx, 'icevol', { T: t, DEPTH: .97, A: 1 }, { mode: 'source-over' });
      ctx.restore();
      const n = 86 * E.inOut(prog(t, c2 + .3, c2 + 6.5, x => x));
      const c = cam({ yaw: .5 + (t - c2) * .07, pitch: -.32, dist: 2900, fov: 1750, cy: H * .5 + 20 });
      drawArray(ctx, c, { strings: n, alpha: a, domAlpha: .75 });
      const k = smooth(c2 + .5, c2 + 1.5, t);
      counter(ctx, Math.min(86, n), 230, 300, { alpha: k, size: 96, unit: '根缆绳', align: 'left' });
      counter(ctx, Math.min(5160, Math.round(n / 86 * 5160)), 230, 440, { alpha: k, size: 96, unit: '颗感应球', align: 'left' });
      text(ctx, '热水钻孔 · 冰下 1450—2450 米', 235, 540, { size: 30, font: 'kai', align: 'left', color: '#bcdcff', alpha: k * .9 });
      const ta = smooth(S.cend(2) - 2.4, S.cend(2) - 1, t);
      term(ctx, '冰立方中微子天文台', 'IceCube Neutrino Observatory · 1 km³', 1470, 930, { alpha: ta, color: CY, size: 40 });
    }
  };

  // 5. 一闪蓝光
  scenes.flash = (ctx, S) => {
    const t = S.t, c1 = S.cue(1), c2 = S.cue(2);
    const g = ctx.createLinearGradient(0, 0, 0, H); g.addColorStop(0, '#04152a'); g.addColorStop(1, '#010710'); ctx.fillStyle = g; ctx.fillRect(0, 0, W, H);
    const split = smooth(c2 - .3, c2 + 1.2, t);
    const dir = (() => { const v = [.78, .38, -.5]; const n = Math.hypot(...v); return v.map(x => x / n); })();
    const V = [-330, -170, 230];
    const tv = .4 + 1.6; // 相互作用时刻
    const tl = t - (.4 + 1.6) ; // 相对相互作用的时间
    // 左：径迹事件
    {
      const cx = lerp(W / 2, W * .3, split), sc = lerp(1, .62, split);
      const c = cam({ yaw: .35 + t * .03, pitch: -.28, dist: 2400, fov: 1750 * sc, cx, cy: H * .52 });
      const tt = Math.max(0, (t - Math.max(tv, c1 - .6)) * 1.0);
      const hits = t > tv ? trackHits(V, dir, tt) : null;
      drawArray(ctx, c, { hits, domAlpha: .35, alpha: 1 });
      // 入射中微子（虚线）
      const inU = prog(t, .3, tv, x => x);
      const P = s => c.p(V[0] + dir[0] * s, V[1] + dir[1] * s, V[2] + dir[2] * s);
      if (inU < 1) { const a0 = P(-1600), a1 = P(lerp(-1600, 0, inU)); ctx.save(); ctx.setLineDash([10, 10]); ctx.strokeStyle = rgba(CY, .8); ctx.lineWidth = 2; ctx.beginPath(); ctx.moveTo(a0.x, a0.y); ctx.lineTo(a1.x, a1.y); ctx.stroke(); ctx.restore(); glow(ctx, a1.x, a1.y, 26, CY, .9); text(ctx, 'ν', a1.x - 30, a1.y - 30, { size: 40, font: 'latinI', color: CY }); }
      // 撞击闪光
      const fl = smooth(tv, tv + .08, t) * (1 - smooth(tv + .1, tv + 1.2, t)); if (fl > 0) { const p = P(0); glow(ctx, p.x, p.y, 260 * fl + 40, '#ffffff', fl); glow(ctx, p.x, p.y, 120, CY, fl); }
      if (t > tv && split < .5) label(ctx, '撞上原子核', P(0).x, P(0).y, { alpha: smooth(tv + .2, tv + .8, t) * (1 - smooth(c1 + 2, c1 + 3, t)), dx: -90, dy: -90, size: 28 });
      // μ 子与切伦科夫光锥
      const s = Math.min(2300, tt * 300);
      if (t > tv && s < 2250) {
        const p = P(s), pb = P(s - 60); const ang = Math.atan2(p.y - pb.y, p.x - pb.x); const L = 120 * c.p(0, 0, 0).s * 1.6;
        ctx.save(); ctx.globalCompositeOperation = 'lighter';
        for (let k = 0; k < 6; k++) { const back = L * (1 - k * .12), sp = Math.tan(49 * Math.PI / 180) * back; const ex = p.x - Math.cos(ang) * back, ey = p.y - Math.sin(ang) * back; ctx.strokeStyle = rgba('#7ab8ff', .28 - k * .045); ctx.lineWidth = 1.4; ctx.beginPath(); ctx.moveTo(ex - Math.sin(ang) * sp, ey + Math.cos(ang) * sp); ctx.lineTo(p.x, p.y); ctx.lineTo(ex + Math.sin(ang) * sp, ey - Math.cos(ang) * sp); ctx.stroke(); }
        const gr = ctx.createRadialGradient(p.x, p.y, 0, p.x, p.y, L * 1.3); gr.addColorStop(0, 'rgba(110,170,255,.28)'); gr.addColorStop(.5, 'rgba(90,150,255,.08)'); gr.addColorStop(1, 'rgba(90,160,255,0)'); ctx.fillStyle = gr; ctx.beginPath(); ctx.moveTo(p.x, p.y); const bx = p.x - Math.cos(ang) * L, by = p.y - Math.sin(ang) * L, sp = Math.tan(49 * Math.PI / 180) * L; ctx.lineTo(bx - Math.sin(ang) * sp, by + Math.cos(ang) * sp); ctx.lineTo(bx + Math.sin(ang) * sp, by - Math.cos(ang) * sp); ctx.closePath(); ctx.fill();
        ctx.restore(); glow(ctx, p.x, p.y, 22, '#ffffff', 1);
        if (s > 200) { const p0 = P(0); line(ctx, [[p0.x, p0.y], [p.x, p.y]], rgba('#ffffff', .7), 1.6); }
      }
      if (t > tv + 1) { const p0 = P(0), p1 = P(Math.min(s, 2200)); line(ctx, [[p0.x, p0.y], [p1.x, p1.y]], rgba('#ffffff', .55), 1.4); }
      term(ctx, '切伦科夫辐射', 'Cherenkov radiation', 1500, 250, { alpha: smooth(c1 + 1.5, c1 + 2.5, t) * (1 - split), color: '#7fb0ff', size: 40 });
      text(ctx, '冰中光速 ≈ 真空光速的 76%', 1500, 345, { size: 28, font: 'kai', color: '#bcd6ff', alpha: smooth(c1 + 3, c1 + 4, t) * (1 - split) });
      text(ctx, '带电粒子快过冰中光速 → 发出蓝光', 1500, 390, { size: 28, font: 'kai', color: '#bcd6ff', alpha: smooth(c1 + 4, c1 + 5, t) * (1 - split) });
      if (split > 0) term(ctx, '径迹 · 指明来向', 'track · μ 子穿行数公里', cx, 900, { alpha: split, color: CY, size: 38 });
      // 时间色标
      const ka = smooth(c1 + 5, c1 + 6, t) * (1 - split);
      if (ka > 0) { for (let i = 0; i < 100; i++) { ctx.fillStyle = timeColor(i / 100); ctx.globalAlpha = ka; ctx.fillRect(1320 + i * 3.6, 470, 3.7, 12); } ctx.globalAlpha = 1; text(ctx, '早', 1305, 476, { size: 24, font: 'kai', color: '#ffb0a0', alpha: ka, align: 'right' }); text(ctx, '晚', 1700, 476, { size: 24, font: 'kai', color: '#a0c0ff', alpha: ka, align: 'left' }); text(ctx, '颜色 = 光到达的先后，球的大小 = 光的多少', 1500, 520, { size: 24, font: 'kai', color: '#cfe0f5', alpha: ka }); }
    }
    // 右：簇射事件
    if (split > 0) {
      const c = cam({ yaw: .9 - t * .03, pitch: -.28, dist: 2400, fov: 1750 * .62, cx: W * .72, cy: H * .52 });
      const hits = cascadeHits([60, 80, 40], (t - c2 - .6) * 1.0, { R: 300 });
      drawArray(ctx, c, { hits, domAlpha: .35, alpha: split, hitScale: 1.1 });
      term(ctx, '簇射 · 记录能量', 'cascade · 光团近似球形', W * .72, 900, { alpha: split, color: GOLD, size: 38 });
    }
  };

  // 6. 以地球为盾
  scenes.shield = (ctx, S) => {
    const t = S.t, c1 = S.cue(1), c2 = S.cue(2);
    space(ctx, t, { stars: .6, drift: 2 });
    const zoom = smooth(c2 - .3, c2 + 1.2, t);
    const ex = W / 2, ey = 560, R = 300;
    const ga = 1 - zoom;
    if (ga > 0) {
      ctx.save(); ctx.globalAlpha = ga;
      const ag = ctx.createRadialGradient(ex, ey, R * .95, ex, ey, R * 1.18); ag.addColorStop(0, 'rgba(90,170,255,.35)'); ag.addColorStop(1, 'rgba(90,170,255,0)'); ctx.fillStyle = ag; ctx.beginPath(); ctx.arc(ex, ey, R * 1.18, 0, Math.PI * 2); ctx.fill();
      const lg = ctx.createRadialGradient(ex, ey, 0, ex, ey, R);
      lg.addColorStop(0, '#fff3c4'); lg.addColorStop(.19, '#ffd27a'); lg.addColorStop(.2, '#f2a24a'); lg.addColorStop(.54, '#c25a2a'); lg.addColorStop(.55, '#6e2a1c'); lg.addColorStop(.97, '#2a1210'); lg.addColorStop(.975, '#3a6a9a'); lg.addColorStop(1, '#2a4a70');
      ctx.fillStyle = lg; ctx.beginPath(); ctx.arc(ex, ey, R, 0, Math.PI * 2); ctx.fill();
      // 地幔对流的纹理
      ctx.save(); ctx.beginPath(); ctx.arc(ex, ey, R * .97, 0, Math.PI * 2); ctx.arc(ex, ey, R * .55, 0, Math.PI * 2, true); ctx.clip(); ctx.globalCompositeOperation = 'lighter';
      for (let i = 0; i < 90; i++) { const a = hash(i, 201) * 6.28 + t * .02, r = R * (.6 + hash(i, 202) * .35); glow(ctx, ex + Math.cos(a) * r, ey + Math.sin(a) * r, 30 + hash(i, 203) * 40, '#ff7a3a', .06); }
      ctx.restore();
      glow(ctx, ex, ey, R * .45, '#ffd890', .35);
      // 南极冰盖
      ctx.fillStyle = 'rgba(235,245,255,.95)'; ctx.beginPath(); ctx.arc(ex, ey, R, -Math.PI / 2 - .32, -Math.PI / 2 + .32); ctx.arc(ex, ey, R * .975, -Math.PI / 2 + .32, -Math.PI / 2 - .32, true); ctx.closePath(); ctx.fill();
      ctx.restore();
      const lab = smooth(.8, 1.8, t) * ga;
      text(ctx, '地核', ex, ey, { size: 26, font: 'song', color: '#5a2a10', alpha: lab, spacing: .3 });
      text(ctx, '地幔', ex - R * .76, ey + 8, { size: 24, font: 'song', color: '#ffd0b0', alpha: lab * .8, spacing: .3 });
      text(ctx, '北天方向', ex, ey + R + 44, { size: 26, font: 'song', color: '#cfe3ff', alpha: lab * .7, spacing: .2 });
      const dx = ex, dy = ey - R; // 南极冰立方在顶端
      ctx.save(); ctx.globalAlpha = ga; ctx.fillStyle = 'rgba(160,220,255,.9)'; ctx.fillRect(dx - 10, dy - 4, 20, 22); ctx.restore(); glow(ctx, dx, dy + 6, 40, CY, ga * .8);
      label(ctx, '南极 · 冰立方', dx, dy, { alpha: ga * smooth(0, 1, t), dx: 110, dy: -70, size: 30 });
      // 大气粒子雨（自上而下，止于地表）
      ctx.save(); ctx.globalCompositeOperation = 'lighter';
      const ra = ga * smooth(.2, 1.2, t);
      for (let i = 0; i < 160; i++) { const x = dx + (hash(i, 61) - .5) * 260; const sp = 900 + hash(i, 62) * 500; const L = dy - 0 + 40; const y = ((t * sp + hash(i, 63) * 2000) % (L + 400)) - 400; if (y > dy + 10) continue; ctx.strokeStyle = rgba(RED, .55 * ra); ctx.lineWidth = 1.4; ctx.beginPath(); ctx.moveTo(x, y); ctx.lineTo(x, y - 40); ctx.stroke(); }
      ctx.restore();
      text(ctx, '来自大气的干扰：多出约百万倍', 420, 230, { size: 32, font: 'song', color: '#ffc4b8', alpha: ra * (1 - .5 * smooth(c1, c1 + 1, t)) });
      // 穿过地球、自下而上的中微子
      const na = ga * smooth(c1 + .3, c1 + 1.3, t);
      if (na > 0) {
        ctx.save(); ctx.globalCompositeOperation = 'lighter';
        for (let i = 0; i < 10; i++) { const x0 = dx + (hash(i, 71) - .5) * 160; const u = ((t - c1) * .35 + hash(i, 72)) % 1; const y = lerp(H + 60, dy, u); const g2 = ctx.createLinearGradient(x0, y, x0, y + 160); g2.addColorStop(0, rgba(CY, .9 * na)); g2.addColorStop(1, rgba(CY, 0)); ctx.strokeStyle = g2; ctx.lineWidth = 2.6; ctx.beginPath(); ctx.moveTo(x0, y); ctx.lineTo(x0, y + 160); ctx.stroke(); glow(ctx, x0, y, 14, CY, na); }
        ctx.restore();
        term(ctx, '“朝下看”', 'looking down through the Earth', 1520, 520, { alpha: na, color: CY, size: 40 });
        text(ctx, '能穿过整个地球而来的', 1520, 640, { size: 30, font: 'song', color: '#d6efff', alpha: na, spacing: .1 });
        text(ctx, '几乎只有中微子', 1520, 690, { size: 30, font: 'song', color: '#d6efff', alpha: na, spacing: .1 });
      }
    }
    // 门卫：外层否决
    if (zoom > 0) {
      ctx.save(); ctx.globalAlpha = zoom;
      const c = cam({ yaw: .2 + t * .05, pitch: -.18, dist: 2500, fov: 1650, cy: H * .5 });
      const isOuter = d => { const r = Math.hypot(d.x, d.z); return r > 520 || d.y < -440 || d.y > 440; };
      const tt = t - c2;
      // 两个事件：一个从外部闯入（被否决），一个在内部亮起（保留）
      const inHits = cascadeHits([20, 60, 0], Math.max(0, tt - 3.2), { R: 230 });
      const outHits = trackHits([-700, -600, 200], (() => { const v = [.8, .5, -.2]; const n = Math.hypot(...v); return v.map(x => x / n); })(), Math.max(0, tt - .8), { len: 520 });
      const hits = new Array(DOMS.length);
      for (let i = 0; i < DOMS.length; i++) { if (outHits[i] && tt < 3.3) hits[i] = { ...outHits[i], col: RED, a: outHits[i].a * (1 - smooth(2.6, 3.2, tt)) }; else if (inHits[i]) hits[i] = { ...inHits[i], col: CY }; }
      drawArray(ctx, c, { hits, domAlpha: .7, dim: d => isOuter(d) ? 1 : .45, domColor: '#9cc2ea' });
      // 外层高亮
      ctx.save(); ctx.globalCompositeOperation = 'lighter';
      for (let i = 0; i < DOMS.length; i += 2) { const d = DOMS[i]; if (!isOuter(d)) continue; const p = c.p(d.x, d.y, d.z); dot(ctx, p.x, p.y, 2.2 * p.s, AMBER, .45 * smooth(.2, 1.2, tt)); }
      ctx.restore();
      ctx.restore();
      term(ctx, '外层 = 门卫', 'veto layer', 300, 260, { alpha: zoom * smooth(.4, 1.2, tt), color: AMBER, size: 38 });
      text(ctx, '✕ 自外闯入：拒之门外', 300, 380, { size: 32, font: 'kai', color: '#ffb0a0', alpha: zoom * smooth(1.6, 2.4, tt) });
      text(ctx, '✓ 内部亮起：予以放行', 300, 440, { size: 32, font: 'kai', color: '#bff0ff', alpha: zoom * smooth(3.6, 4.4, tt) });
    }
  };

  // 7. 首批证据
  scenes.discovery = (ctx, S) => {
    const t = S.t, c1 = S.cue(1);
    space(ctx, t, { stars: .5, c1: '#081428' });
    // 左：两个 PeV 簇射
    const la = smooth(0, 1, t) * (1 - smooth(c1 + 3, c1 + 4, t) * .0);
    [['伯特 Bert', '≈1.04 PeV', [-60, 40, 80], W * .2], ['厄尼 Ernie', '≈1.14 PeV', [80, -60, -40], W * .43]].forEach(([nm, en, C, cx], k) => {
      const c = cam({ yaw: .5 + k + t * .05, pitch: -.3, dist: 2500, fov: 900, cx, cy: 390 });
      drawArray(ctx, c, { hits: cascadeHits(C, Math.max(0, t - .6 - k * .5), { R: 330 }), domAlpha: .22, alpha: la, hitScale: .9 });
      text(ctx, nm, cx, 650, { size: 40, font: 'song', weight: 600, color: '#fff3d6', alpha: smooth(1 + k * .5, 2 + k * .5, t) });
      text(ctx, en, cx, 700, { size: 28, font: 'song', color: GOLD, alpha: smooth(1.2 + k * .5, 2.2 + k * .5, t) });
    });
    text(ctx, '1 PeV = 10¹⁵ 电子伏特 = 一千万亿电子伏特', W * .315, 770, { size: 30, font: 'kai', color: '#d9cfb8', alpha: smooth(2.5, 3.5, t) });
    // 右：28 个事件的能量分布（示意）
    const ox = 1160, oy = 700, w = 640, h = 400; const ra = smooth(1.5, 2.5, t);
    ctx.save(); ctx.globalAlpha = ra; ctx.strokeStyle = 'rgba(220,230,255,.6)'; ctx.lineWidth = 1.4; ctx.beginPath(); ctx.moveTo(ox, oy - h); ctx.lineTo(ox, oy); ctx.lineTo(ox + w, oy); ctx.stroke(); ctx.restore();
    const ticks = [[30, '30 TeV'], [100, '100 TeV'], [300, '300 TeV'], [1000, '1 PeV']]; const ex = e => ox + w * (Math.log10(e) - Math.log10(20)) / (Math.log10(2000) - Math.log10(20));
    ticks.forEach(([e, s]) => { text(ctx, s, ex(e), oy + 30, { size: 20, font: 'song', color: '#c9d4e6', alpha: ra }); });
    const evs = (() => { const r = rng(28); const a = []; for (let i = 0; i < 26; i++) a.push(30 * Math.pow(10, Math.pow(r(), 1.6) * 1.3)); a.push(1040, 1140); return a; })();
    const bins = {}; evs.forEach((e, i) => { const b = Math.round((ex(e) - ox) / 26); bins[b] = (bins[b] || 0) + 1; const n = bins[b]; const x = ox + b * 26 + 13, y = oy - n * 26 + 8; const ap = smooth(2.2 + i * .12, 2.5 + i * .12, t); if (ap <= 0) return; const big = e > 1000; glow(ctx, x, y, big ? 40 : 22, big ? GOLD : CY, ap * .7); dot(ctx, x, y, big ? 9 : 7, big ? '#fff1c8' : '#dff6ff', ap); });
    const nShown = Math.min(28, Math.max(0, Math.floor((t - 2.2) / .12) + 1));
    counter(ctx, nShown, ox + 20, oy - h - 20, { alpha: ra, size: 80, unit: '个高能事件', align: 'left' });
    text(ctx, '2010—2012 年数据 · 能量分布为示意', ox + w / 2, oy + 72, { size: 22, font: 'song', color: '#9fb3cc', alpha: ra });
    // 结论
    const ka = smooth(c1 + .2, c1 + 1.4, t);
    text(ctx, '来自太阳系之外', W / 2, 860, { size: 56, font: 'song', weight: 700, spacing: .3, color: '#ffffff', alpha: ka, glow: 24, glowColor: CY });
    text(ctx, '统计显著性：2013 年约 4σ（首批证据）→ 2014 年 5.7σ', W / 2, 922, { size: 24, font: 'song', color: '#bcd0e6', alpha: smooth(c1 + 3, c1 + 4, t) * (1 - smooth(S.d - 1.2, S.d - .4, t)) });
  };

  // 8. 追溯源头
  scenes.sources = (ctx, S) => {
    const t = S.t, c1 = S.cue(1), c2 = S.cue(2);
    space(ctx, t, { stars: .9, drift: 4 });
    // A：警报传遍全球
    const aA = 1 - smooth(c1 - .3, c1 + .6, t);
    if (aA > 0) {
      ctx.save(); ctx.globalAlpha = aA;
      const lat0 = -35, lon0 = -40 + t * 6, R = 360, cx = W * .42, cy = 560;
      globe(ctx, cx, cy, R, lat0, lon0, {});
      const sp = geo(-89.99, 0, cx, cy, R, lat0, lon0);
      const wave = prog(t, 1.2, c1 - .5, x => x);
      for (let k = 0; k < 3; k++) { const rr = ((wave * 3 + k / 3) % 1) * R * 1.6; ctx.strokeStyle = rgba(CY, .6 * (1 - rr / (R * 1.6))); ctx.lineWidth = 2; ctx.beginPath(); ctx.ellipse(sp.x, sp.y, rr, rr * .5, 0, 0, 7); ctx.stroke(); }
      glow(ctx, sp.x, sp.y, 50, CY, .9);
      const sites = [[28.76, -17.89, 'MAGIC 望远镜'], [31.68, -110.95, '射电/光学台站'], [-30.2, -70.8, '智利台站'], [-24.6, 16.5, '纳米比亚 H.E.S.S.']];
      sites.forEach(([la, lo, nm], i) => { const p = geo(la, lo, cx, cy, R, lat0, lon0); if (!p.vis) return; const a = smooth(2 + i * .7, 2.6 + i * .7, t); glow(ctx, p.x, p.y, 26, GOLD, a); dot(ctx, p.x, p.y, 5, '#fff', a); });
      ctx.restore();
      // 费米卫星轨道
      ctx.save(); ctx.globalAlpha = aA * smooth(2, 3, t); ctx.strokeStyle = 'rgba(255,220,150,.5)'; ctx.setLineDash([6, 8]); ctx.beginPath(); ctx.ellipse(cx, cy, R * 1.25, R * .45, -.3, 0, 7); ctx.stroke(); ctx.setLineDash([]); const fa = t * .5; const fx = cx + Math.cos(fa) * R * 1.25 * Math.cos(-.3) - Math.sin(fa) * R * .45 * Math.sin(-.3), fy = cy + Math.cos(fa) * R * 1.25 * Math.sin(-.3) + Math.sin(fa) * R * .45 * Math.cos(-.3); glow(ctx, fx, fy, 30, GOLD, 1); ctx.restore();
      text(ctx, '2017 年 9 月 22 日', 1450, 330, { size: 46, font: 'song', weight: 500, color: '#ffffff', alpha: aA * smooth(.5, 1.5, t) });
      text(ctx, 'IceCube-170922A', 1450, 390, { size: 30, font: 'latinI', color: CY, alpha: aA * smooth(.8, 1.8, t) });
      counter(ctx, 43 * clamp((t - 1.2) / 2.5), 1450, 520, { alpha: aA * smooth(1.2, 2, t), size: 110, unit: '秒', format: v => '+' + Math.round(v) });
      text(ctx, '自动警报发往全球望远镜', 1450, 610, { size: 30, font: 'kai', color: '#d8ecff', alpha: aA * smooth(2, 3, t) });
    }
    // B：耀变体
    const aB = smooth(c1 - .3, c1 + .6, t) * (1 - smooth(c2 - .3, c2 + .6, t));
    if (aB > 0) {
      ctx.save(); ctx.globalAlpha = aB; ctx.globalCompositeOperation = 'lighter';
      const bx = W * .45, by = 520; const flare = .6 + .4 * smooth(c1 + 1, c1 + 3, t) + .15 * Math.sin(t * 9) * smooth(c1 + 1, c1 + 3, t);
      for (let i = 0; i < 380; i++) { const a = hash(i, 81) * 6.28, r = Math.pow(hash(i, 82), 1.8) * 300; glow(ctx, bx + Math.cos(a + t * .05) * r, by + Math.sin(a + t * .05) * r * .45, 10 + hash(i, 83) * 22, i % 4 ? '#9fb6ff' : '#ffd0a0', .12); }
      // 指向我们的喷流
      for (let i = 0; i < 70; i++) { const u = (t * .7 + hash(i, 84)) % 1; const rr = 10 + u * 160; const a = hash(i, 85) * 6.28; glow(ctx, bx + Math.cos(a) * rr * .35, by + Math.sin(a) * rr * .35, 20 + u * 60, '#cfe0ff', .25 * (1 - u) * flare); }
      glow(ctx, bx, by, 160 * flare, '#ffffff', .8); glow(ctx, bx, by, 60, '#ffffff', 1);
      // γ 光芒
      for (let i = 0; i < 12; i++) { const a = i / 12 * 6.28 + t * .2; const L = (200 + 60 * Math.sin(t * 3 + i)) * flare; ctx.strokeStyle = rgba(GOLD, .25); ctx.lineWidth = 2; ctx.beginPath(); ctx.moveTo(bx + Math.cos(a) * 70, by + Math.sin(a) * 70); ctx.lineTo(bx + Math.cos(a) * L, by + Math.sin(a) * L); ctx.stroke(); }
      ctx.restore();
      comet(ctx, [[bx, by], [W + 50, by + 260]], prog(t, c1 + .6, c1 + 2.6, x => x), CY, { tail: .5, width: 4, headR: 24, alpha: aB });
      term(ctx, '耀变体 TXS 0506+056', 'blazar · 喷流正对地球', 1440, 400, { alpha: aB * smooth(c1 + .5, c1 + 1.5, t), color: GOLD, size: 40 });
      text(ctx, '距离约 40 亿光年', 1440, 520, { size: 36, font: 'kai', color: '#ffe8c4', alpha: aB * smooth(c1 + 1.5, c1 + 2.5, t) });
      text(ctx, '伽马射线同步爆发', 1440, 575, { size: 30, font: 'kai', color: '#e6d6b8', alpha: aB * smooth(c1 + 2.5, c1 + 3.5, t) });
    }
    // C：被尘埃深锁的星系 → 银河
    const aC = smooth(c2 - .3, c2 + .6, t);
    if (aC > 0) {
      const mw = smooth(c2 + 4.5, c2 + 6, t);
      // NGC 1068
      const ga = aC * (1 - mw);
      if (ga > 0) {
        const gx = W * .4, gy = 520;
        GLFX.layer(ctx, 'galaxy', { T: t, P: GLFX.uv(gx, gy), SZ: 330 / H, INC: .55, ROT: .35, A: 1.5 * ga, DUST: 1.2, C1: '#ffe2b8', C2: '#7f9cff' });
        // 伽马被挡、中微子逃逸
        for (let k = 0; k < 6; k++) { const a = k / 6 * 6.28 + .3; const u = ((t - c2) * .5 + k / 6) % 1; const r = u * 90; glow(ctx, gx + Math.cos(a) * r, gy + Math.sin(a) * r * .6, 10, GOLD, ga * (1 - smooth(.6, 1, u))); }
        for (let k = 0; k < 5; k++) { const a = k / 5 * 6.28 + 1; const u = ((t - c2) * .35 + k / 5) % 1; const r = u * 520; glow(ctx, gx + Math.cos(a) * r, gy + Math.sin(a) * r * .7, 16, CY, ga * (1 - u)); }
        term(ctx, '活动星系 NGC 1068（M77）', '约 4700 万光年 · 2022 年 · 4.2σ', 1450, 380, { alpha: ga * smooth(c2 + .5, c2 + 1.5, t), color: CY, size: 38 });
        text(ctx, '伽马射线困于尘埃，中微子破茧而出', 1450, 500, { size: 32, font: 'kai', color: '#d6ecff', alpha: ga * smooth(c2 + 1.5, c2 + 2.5, t) });
      }
      if (mw > 0) {
        GLFX.layer(ctx, 'milkyway', { T: t, A: 1.1 * mw, TILT: -.18, Y0: .03, C1: [0, 0, 0] });
        GLFX.layer(ctx, 'nebula', { T: t, C1: '#0a4a7a', C2: '#2aa0d8', C3: '#9fe6ff', S: 2.6, D: .55, A: 1.1 * mw * smooth(c2 + 6, c2 + 8, t), MODE: 0, OFF: [2, 2], MC: GLFX.uv(W / 2, 505), MR: [1.1, .07] });
        term(ctx, '我们的银河系 · 中微子之像', 'Galactic plane in neutrinos · 2023', W / 2, 820, { alpha: mw * smooth(c2 + 5, c2 + 6.2, t), color: CY, size: 40 });
      }
    }
  };

  // 9. 新的窗口
  scenes.window = (ctx, S) => {
    const t = S.t, c1 = S.cue(1), c2 = S.cue(2);
    space(ctx, t, { stars: .8, drift: 3 });
    // A：四扇窗
    const aA = 1 - smooth(c1 - .3, c1 + .5, t);
    if (aA > 0) {
      const items = [['光', '电磁波', '#ffe6a8'], ['宇宙线', '1912 —', '#ff9b8a'], ['引力波', '2015 —', '#c7a8ff'], ['中微子', '2013 —', CY]];
      items.forEach(([zh, sub, col], i) => {
        const x = 420 + i * 360, y = 500; const a = aA * smooth(.3 + i * .7, 1 + i * .7, t); const big = i === 3 ? 1 + .15 * smooth(3, 4, t) : 1;
        ctx.save(); ctx.globalAlpha = a; ctx.strokeStyle = rgba(col, .85); ctx.lineWidth = 2; ctx.shadowColor = col; ctx.shadowBlur = i === 3 ? 30 : 12; ctx.beginPath(); ctx.arc(x, y, 110 * big, 0, 7); ctx.stroke(); ctx.restore();
        if (i === 3) glow(ctx, x, y, 260, CY, a * .35 * smooth(3, 4, t));
        text(ctx, zh, x, y - 6, { size: 52 * big, font: 'song', weight: 700, color: '#fffaf0', alpha: a });
        text(ctx, sub, x, y + 170, { size: 26, font: 'song', color: col, alpha: a * .9, spacing: .1 });
      });
      text(ctx, '多信使天文学', W / 2, 840, { size: 46, font: 'song', weight: 600, spacing: .4, color: '#ffffff', alpha: aA * smooth(3.2, 4.2, t), glow: 18, glowColor: CY });
    }
    // B：全球的下一代望远镜
    const aB = smooth(c1 - .3, c1 + .6, t) * (1 - smooth(c2 - .3, c2 + .6, t));
    if (aB > 0) {
      const u = prog(t, c1, c2, E.inOut); const lat0 = lerp(-55, 25, u), lon0 = lerp(10, 95, u); const cx = W * .5, cy = 560, R = 400;
      globe(ctx, cx, cy, R, lat0, lon0, { alpha: aB });
      const sites = [[-89.99, 0, '冰立方 / IceCube-Gen2', '南极'], [36.3, 16.1, 'KM3NeT', '地中海'], [51.8, 104.4, 'Baikal-GVD', '贝加尔湖'], [17, 114, '海铃 TRIDENT · HUNT', '中国南海']];
      sites.forEach(([la, lo, nm, where], i) => { const p = geo(la, lo, cx, cy, R, lat0, lon0); if (!p.vis) return; const a = aB * smooth(.0, .25, p.z) * smooth(c1 + i * .9, c1 + .8 + i * .9, t); glow(ctx, p.x, p.y, 40 + 8 * Math.sin(t * 4 + i), i === 3 ? '#ff7a6a' : CY, a); dot(ctx, p.x, p.y, 6, '#fff', a); label(ctx, `${where} · ${nm}`, p.x, p.y, { alpha: a, dx: (p.x > cx ? 1 : -1) * 120, dy: -60 - i * 6, size: 28 }); });
    }
    // C：冰之眼
    const aC = smooth(c2 - .3, c2 + .8, t);
    if (aC > 0) {
      const c = cam({ yaw: t * .05, pitch: -1.5707, dist: 14000, fov: 5200, cy: H * .46 });
      ctx.save(); ctx.globalAlpha = aC; drawArray(ctx, c, { domAlpha: .9, domColor: '#bfe6ff' }); ctx.restore();
      ctx.save(); ctx.globalCompositeOperation = 'lighter';
      for (let k = 0; k < 4; k++) { ctx.strokeStyle = rgba(CY, (.25 - k * .05) * aC); ctx.lineWidth = 2; ctx.beginPath(); ctx.arc(W / 2, H * .46, 250 + k * 34 + 6 * Math.sin(t + k), 0, 7); ctx.stroke(); }
      ctx.restore();
      glow(ctx, W / 2, H * .46, 140, CY, aC * .25);
      text(ctx, '以冰为眼', W / 2, 860, { size: 60, font: 'song', weight: 700, spacing: .4, color: '#ffffff', alpha: aC * smooth(c2 + 1, c2 + 2.5, t), glow: 24, glowColor: CY });
    }
  };

  scenes.end = (ctx, S) => {
    space(ctx, S.t, { stars: .5, c1: '#0a1428' });
    endCard(ctx, S.t, S.d, {
      prize: '2026 年诺贝尔物理学奖', color: '#bfe6ff',
      zh: '表彰“对冰立方中微子天文台的决定性贡献，\n以及发现天体物理起源的高能中微子”',
      en: '“for decisive contributions to the IceCube Neutrino Observatory and the discovery of high-energy neutrinos of astrophysical origin”',
      who: '获奖者：弗朗西斯·哈尔岑（Francis Halzen）',
      src: '资料：诺贝尔奖官方新闻稿与科普资料、IceCube 合作组论文（Science 2013/2018/2022/2023 等）· 部分画面为示意 · 配音为合成语音'
    });
  };

  FILM({ id: 'physics', scenes, accent: '#bfe6ff', brand: 'NOBEL PRIZE 2026 · PHYSICS', chapters: { messengers: [1, '宇宙的信使'], ice: [2, '以冰为眼'], flash: [3, '一闪蓝光'], shield: [4, '以地球为盾'], discovery: [5, '天外来客'], sources: [6, '追本溯源'], window: [7, '新的窗口'] }, noPush: ['title', 'end'], post: { bloom: .55, vignette: .55, grain: .05 } });
})();
