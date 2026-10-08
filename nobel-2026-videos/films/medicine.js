// 2026 诺贝尔生理学或医学奖 ·《以光为钥》——光门控离子通道与光遗传学
// 每一帧都是时间的纯函数：所有几何在载入时以固定种子预计算。
(function () {
  'use strict';
  const { W, H, clamp, lerp, smooth, E, prog, env, rng, hash, glow, dot, text, rgba, mix, line, label, noise3 } = MP;
  const { titleCard, endCard, term, counter } = KIT;
  const TAU = Math.PI * 2;
  const ACC = '#8fd0ff';
  const FIL = '#4fd0e2', CORE = '#e6fcff', BLUE = '#3d7bff', BLUE2 = '#59a8ff', AMB = '#ffc23d', GREEN = '#7ed957',
    EYE = '#ff5a2a', IVORY = '#f3e6d8', YFP = '#d9f26a', VIO = '#b58cff';

  // ---------- 小工具 ----------
  // 分段线性插值：K = [[t0,v0],[t1,v1],...]
  function pw(t, K) {
    if (t <= K[0][0]) return K[0][1];
    for (let i = 1; i < K.length; i++) if (t <= K[i][0]) { const u = (t - K[i - 1][0]) / (K[i][0] - K[i - 1][0] || 1); return lerp(K[i - 1][1], K[i][1], u); }
    return K[K.length - 1][1];
  }
  // 估计一句配音中某个词开始的时刻（按字数与标点停顿比例）
  function wt(S, k, sub, frac = 0) {
    const L = S.film && S.film.scenes[S.i] && S.film.scenes[S.i].lines[k]; if (!L) return S.d;
    const s = [...L.text]; const full = L.text; let idx = full.indexOf(sub); if (idx < 0) idx = 0;
    const pre = [...full.slice(0, idx)].length;
    const w = (ch, i) => (i === s.length - 1 && '，。；：、？！'.includes(ch)) ? 0 : '，。；：、？！'.includes(ch) ? 2.6 : '—“”'.includes(ch) ? .6 : 1;
    let tot = 0, before = 0; s.forEach((c, i) => { const v = w(c, i); tot += v; if (i < pre) before += v; });
    before += frac * [...sub].length;
    return S.cue(k) + (S.cend(k) - S.cue(k)) * before / (tot || 1);
  }
  // 柔和的暗晕（衬托文字）
  function shade(ctx, x, y, rx, ry, a) {
    if (a <= 0) return; ctx.save(); ctx.translate(x, y); ctx.scale(1, ry / rx);
    const g = ctx.createRadialGradient(0, 0, 0, 0, 0, rx); g.addColorStop(0, `rgba(1,6,8,${a})`); g.addColorStop(.55, `rgba(1,6,8,${a * .65})`); g.addColorStop(1, 'rgba(1,6,8,0)');
    ctx.fillStyle = g; ctx.beginPath(); ctx.arc(0, 0, rx, 0, TAU); ctx.fill(); ctx.restore();
  }
  const hex = c => '#' + c.map(v => Math.round(clamp(v, 0, 255)).toString(16).padStart(2, '0')).join('');
  const L2S = (x, y, s, rot, lx, ly) => { const c = Math.cos(rot), sn = Math.sin(rot); return [x + s * (c * lx - sn * ly), y + s * (sn * lx + c * ly)]; };
  function pathOf(pts) { const p = new Path2D(); p.moveTo(pts[0][0], pts[0][1]); for (let i = 1; i < pts.length; i++) p.lineTo(pts[i][0], pts[i][1]); return p; }
  // 发光线：宽淡光晕 + 中等 + 细亮芯
  function glowLine(ctx, pts, col, w, a, core = '#ffffff', mode = 'lighter') {
    if (!pts || pts.length < 2 || a <= 0) return;
    ctx.save(); ctx.globalCompositeOperation = mode; ctx.lineCap = 'round'; ctx.lineJoin = 'round';
    ctx.beginPath(); ctx.moveTo(pts[0][0], pts[0][1]); for (let i = 1; i < pts.length; i++) ctx.lineTo(pts[i][0], pts[i][1]);
    ctx.strokeStyle = col; ctx.globalAlpha = clamp(a * .07); ctx.lineWidth = w * 7; ctx.stroke();
    ctx.globalAlpha = clamp(a * .25); ctx.lineWidth = w * 2.6; ctx.stroke();
    ctx.strokeStyle = core; ctx.globalAlpha = clamp(a * .92); ctx.lineWidth = w; ctx.stroke();
    ctx.restore();
  }
  function withLen(pts) { const L = [0]; for (let i = 1; i < pts.length; i++) L.push(L[i - 1] + Math.hypot(pts[i][0] - pts[i - 1][0], pts[i][1] - pts[i - 1][1])); return { pts, L, len: L[L.length - 1] }; }
  function along(R, s) {
    const L = R.L, P = R.pts; if (s <= 0) return P[0]; if (s >= R.len) return P[P.length - 1];
    let lo = 0, hi = L.length - 1; while (hi - lo > 1) { const m = (lo + hi) >> 1; if (L[m] <= s) lo = m; else hi = m; }
    const k = (s - L[lo]) / (L[hi] - L[lo] || 1); return [lerp(P[lo][0], P[hi][0], k), lerp(P[lo][1], P[hi][1], k)];
  }
  function sub(R, s0, s1) { const out = [along(R, s0)]; for (let i = 0; i < R.pts.length; i++) if (R.L[i] > s0 && R.L[i] < s1) out.push(R.pts[i]); out.push(along(R, s1)); return out; }
  // Catmull-Rom 闭合/开放曲线采样
  function spline(P, closed = false, n = 14) {
    const out = []; const N = P.length; const g = i => closed ? P[(i + N) % N] : P[clamp(i, 0, N - 1)];
    const last = closed ? N : N - 1;
    for (let i = 0; i < last; i++) { const p0 = g(i - 1), p1 = g(i), p2 = g(i + 1), p3 = g(i + 2); for (let k = 0; k < n; k++) { const u = k / n, u2 = u * u, u3 = u2 * u; out.push([.5 * ((2 * p1[0]) + (-p0[0] + p2[0]) * u + (2 * p0[0] - 5 * p1[0] + 4 * p2[0] - p3[0]) * u2 + (-p0[0] + 3 * p1[0] - 3 * p2[0] + p3[0]) * u3), .5 * ((2 * p1[1]) + (-p0[1] + p2[1]) * u + (2 * p0[1] - 5 * p1[1] + 4 * p2[1] - p3[1]) * u2 + (-p0[1] + 3 * p1[1] - 3 * p2[1] + p3[1]) * u3)]); } }
    out.push(closed ? out[0] : P[N - 1]); return out;
  }

  // ---------- 自定义着色器 ----------
  // 池水：深度渐变 + 焦散 + 自 SP 斜射而下的光柱 + 悬浮微粒
  GLFX.define('pond', `uniform vec3 C1,C2,C3; uniform float A,S,SUN; uniform vec2 SP;
void main(){vec2 u=UV(); vec2 f=gl_FragCoord.xy/R;
 vec3 col=mix(C1,C2,smoothstep(0.,1.,f.y));
 vec2 p=u*S+vec2(-250.,-250.+T*.02); float t=T*.3; vec2 i=p; float c=1.; float inten=.005;
 for(int n=0;n<5;n++){float tt=t*(1.-(3.5/float(n+1))); i=p+vec2(cos(tt-i.x)+sin(tt+i.y),sin(tt-i.y)+cos(tt+i.x)); c+=1./length(vec2(p.x/(sin(i.x+tt)/inten),p.y/(cos(i.y+tt)/inten)));}
 c/=5.; c=1.17-pow(c,1.4); float k=pow(abs(c),8.);
 col+=C3*k*.5*smoothstep(-.1,1.,f.y);
 vec2 d=u-SP; float r=length(d); float ang=atan(d.x,-d.y);
 float rays=pow(fbm4(vec3(ang*6.,T*.05,2.)),2.)*2.4;
 float down=smoothstep(-.1,.7,-d.y/(r+.001));
 col+=C3*rays*exp(-r*1.0)*down*SUN*.36;
 col+=C3*exp(-r*2.6)*SUN*.22;
 float sn=pow(noise(vec3(gl_FragCoord.xy*.21,T*.25)),48.)*1.2; col+=sn*C3*.4;
 O=vec4(col*A,1.);}`);
  // 体内的柔光雾（蓝/青），用于神经组织背景
  GLFX.define('haze', `uniform vec3 C1,C2; uniform float A,S; uniform vec2 OFF;
void main(){vec2 u=UV()*S+OFF; float w=fbm4(vec3(u*1.3,T*.02)); float d=fbm(vec3(u*2.2+vec2(w*1.6,w),T*.03+3.));
 float fil=pow(smoothstep(.45,.85,fbm4(vec3(u*6.+vec2(d*2.),T*.02+7.))),2.);
 vec3 col=mix(C1,C2,smoothstep(.3,.8,d))*smoothstep(.32,.9,d)*(.6+fil*.9);
 O=vec4(col*A,1.);}`);

  // ---------- 背景 ----------
  const MOTES = (() => { const r = rng(909); const a = []; for (let i = 0; i < 170; i++) a.push({ x: r(), y: r(), z: .2 + r() * .8, ph: r() * TAU, b: r() }); return a; })();
  function motes(ctx, t, a0, col = '#9fe8f2') {
    if (a0 <= 0) return; ctx.save(); ctx.globalCompositeOperation = 'lighter';
    for (const m of MOTES) {
      const x = ((m.x * W * 1.1 + t * 10 * m.z) % (W * 1.1) + W * 1.1) % (W * 1.1) - W * .05;
      const y = ((m.y * H * 1.1 - t * 6 * m.z + 3 * Math.sin(t * .4 + m.ph)) % (H * 1.1) + H * 1.1) % (H * 1.1) - H * .05;
      const tw = .6 + .4 * Math.sin(t * (.6 + m.b) + m.ph);
      if (m.b > .94) glow(ctx, x, y, 26 + 30 * m.z, col, .05 * a0 * tw);
      else glow(ctx, x, y, 2 + 5 * m.z * m.z, col, (.1 + .28 * m.z) * a0 * tw);
    }
    ctx.restore();
  }
  function deep(ctx, t, o = {}) {
    const g = ctx.createRadialGradient(W * .5, H * .42, 0, W * .5, H * .5, W * .78);
    g.addColorStop(0, o.c1 || '#0a242b'); g.addColorStop(.5, o.c2 || '#06161c'); g.addColorStop(1, '#010507');
    ctx.fillStyle = g; ctx.fillRect(0, 0, W, H);
    if ((o.neb ?? 0) > 0) GLFX.layer(ctx, 'haze', { T: t + (o.seed || 0) * 30, C1: o.h1 || '#04323c', C2: o.h2 || '#1b7f93', S: o.ns || 1.2, A: o.neb, OFF: [(o.seed || 0) * 2.3 + t * .004, (o.seed || 0) * 1.7] }, { scale: .25 });
    motes(ctx, t, o.motes ?? 1, o.moteCol);
  }

  // ---------- 程序化神经元 ----------
  const BR = {
    bas: { step: 7, wig: .2, decay: .72, spread: .5, max: 3, min: 14, tri: .05 },
    obl: { step: 7, wig: .18, decay: .7, spread: .45, max: 3, min: 14, tri: 0 },
    tuft: { step: 7, wig: .18, decay: .74, spread: .45, max: 3, min: 14, tri: .1 },
    star: { step: 7, wig: .22, decay: .72, spread: .55, max: 3, min: 14, tri: .08 },
    mini: { step: 6, wig: .24, decay: .66, spread: .6, max: 2, min: 9, tri: .1 },
  };
  function makeNeuron(seed, kind, sc = 1) {
    const r = rng(seed); const segs = [];
    function grow(x, y, a, len, lvl, parent, p) {
      const n = Math.max(2, Math.round(len / p.step)); const pts = [[x, y]]; let ang = a;
      for (let i = 0; i < n; i++) { ang += (r() - .5) * p.wig; x += Math.cos(ang) * p.step; y += Math.sin(ang) * p.step; pts.push([x, y]); }
      const id = segs.length; segs.push({ pts, lvl, parent, kids: 0 });
      const nl = len * p.decay * (.8 + .4 * r());
      if (lvl < p.max && nl > p.min) {
        const k = r() < p.tri ? 3 : 2;
        for (let j = 0; j < k; j++) { const off = (k === 2 ? (j ? 1 : -1) : (j - 1)) * p.spread * (.55 + .7 * r()); segs[id].kids++; grow(x, y, ang + off, nl * (.75 + .5 * r()), lvl + 1, id, p); }
      }
      return id;
    }
    function axonFrom(x, y, a, len, wig) {
      const pts = [[x, y]]; let ang = a; const n = Math.round(len / 9);
      for (let i = 0; i < n; i++) { ang += (r() - .5) * wig + Math.sin(a - ang) * .04; x += Math.cos(ang) * 9; y += Math.sin(ang) * 9; pts.push([x, y]); }
      return pts;
    }
    let axon = [];
    if (kind === 'pyr') {
      let x = 0, y = -6, ang = -Math.PI / 2 + (r() - .5) * .25, parent = -1; const nSub = 6, trunkL = 170 + r() * 70;
      for (let k = 0; k < nSub; k++) {
        const pts = [[x, y]]; const n = Math.round(trunkL / nSub / 6);
        for (let i = 0; i < n; i++) { ang += (r() - .5) * .14 + Math.sin(-Math.PI / 2 - ang) * .08; x += Math.cos(ang) * 6; y += Math.sin(ang) * 6; pts.push([x, y]); }
        const id = segs.length; segs.push({ pts, lvl: 0, parent, kids: 0 });
        if (k > 0 && k < nSub - 1) { const side = (k % 2 ? 1 : -1) * (r() < .8 ? 1 : -1); segs[id].kids++; grow(x, y, ang + side * (.8 + r() * .5), 45 + r() * 50, 2, id, BR.obl); }
        parent = id;
      }
      for (let j = 0; j < 3; j++) { segs[parent].kids++; grow(x, y, -Math.PI / 2 + (j - 1) * .6 + (r() - .5) * .3, 60 + r() * 40, 1, parent, BR.tuft); }
      const nb = 5 + Math.floor(r() * 2);
      for (let j = 0; j < nb; j++) { const a = Math.PI * (-.05 + 1.1 * (j + .5) / nb) + (r() - .5) * .3; grow(Math.cos(a) * 8, Math.sin(a) * 8, a, 60 + r() * 50, 1, -1, BR.bas); }
      const main = axonFrom(0, 9, Math.PI / 2 + (r() - .5) * .3, 520 + r() * 260, .16); axon.push(main);
      for (const f of [.32, .58]) { const i = Math.floor(main.length * f); const p = main[i]; axon.push(axonFrom(p[0], p[1], Math.PI / 2 + (r() < .5 ? -1 : 1) * (.8 + r() * .4), 80 + r() * 90, .3)); }
    } else if (kind === 'bip') {
      for (const a0 of [-Math.PI / 2, Math.PI / 2]) grow(0, a0 > 0 ? 7 : -7, a0 + (r() - .5) * .3, 80 + r() * 50, 1, -1, BR.tuft);
      const a = (r() < .5 ? 0 : Math.PI) + (r() - .5) * .6; axon.push(axonFrom(Math.cos(a) * 8, Math.sin(a) * 8, a, 380 + r() * 240, .2));
    } else {
      const p = kind === 'mini' ? BR.mini : BR.star; const np = 5 + Math.floor(r() * 3); const L0 = kind === 'mini' ? 34 : 75;
      for (let j = 0; j < np; j++) { const a = j / np * TAU + (r() - .5) * .7; grow(Math.cos(a) * 7, Math.sin(a) * 7, a, L0 + r() * L0 * .8, 1, -1, p); }
      const a = r() * TAU; axon.push(axonFrom(Math.cos(a) * 8, Math.sin(a) * 8, a, (kind === 'mini' ? 120 : 400) + r() * 260, .2));
    }
    if (sc !== 1) { for (const s of segs) for (const q of s.pts) { q[0] *= sc; q[1] *= sc; } for (const ax of axon) for (const q of ax) { q[0] *= sc; q[1] *= sc; } }
    const paths = [new Path2D(), new Path2D(), new Path2D()];
    let ext = 0;
    for (const s of segs) { const c = s.lvl === 0 ? 0 : s.lvl <= 2 ? 1 : 2; const p = paths[c]; p.moveTo(s.pts[0][0], s.pts[0][1]); for (let i = 1; i < s.pts.length; i++) { p.lineTo(s.pts[i][0], s.pts[i][1]); ext = Math.max(ext, Math.hypot(s.pts[i][0], s.pts[i][1])); } }
    const axonPath = new Path2D(); for (const ax of axon) { axonPath.moveTo(ax[0][0], ax[0][1]); for (let i = 1; i < ax.length; i++) axonPath.lineTo(ax[i][0], ax[i][1]); }
    const terms = segs.map((s, i) => s.kids === 0 ? i : -1).filter(i => i >= 0);
    const routes = [];
    for (let k = 0; k < Math.min(6, terms.length); k++) { const id = terms[Math.floor(r() * terms.length)]; const pts = []; let q = id; while (q >= 0) { const sp = segs[q].pts; for (let i = sp.length - 1; i >= 0; i--) pts.push(sp[i]); q = segs[q].parent; } pts.push([0, 0]); routes.push(withLen(pts)); }
    return { kind, segs, paths, axonPath, axon: withLen(axon[0]), routes, ext };
  }
  const TPL = [];
  for (let i = 0; i < 6; i++) TPL.push(makeNeuron(1000 + i * 17, 'pyr'));
  for (let i = 0; i < 5; i++) TPL.push(makeNeuron(2000 + i * 31, 'star'));
  for (let i = 0; i < 2; i++) TPL.push(makeNeuron(3000 + i * 13, 'bip'));
  const MINI = []; for (let i = 0; i < 8; i++) MINI.push(makeNeuron(5000 + i * 7, 'mini'));
  const HERO = makeNeuron(1042, 'pyr', 1.25);

  const WID = [3.0, 1.7, .95];
  function drawNeuron(ctx, N, x, y, s, rot, o = {}) {
    const a = o.alpha ?? 1; if (a <= .01) return;
    const core = o.core || CORE, halo = o.halo || FIL, dof = o.dof || 0;
    ctx.save(); ctx.translate(x, y); ctx.rotate(rot); ctx.scale(s, s);
    ctx.globalCompositeOperation = o.mode || 'lighter'; ctx.lineCap = 'round'; ctx.lineJoin = 'round';
    const passes = o.lite ? [[2.4, .18], [1, .7]] : [[6 + dof * 9, .05], [2.4 + dof * 3, .14], [1, .82 * (1 - dof * .75)]];
    for (const [m, pa] of passes) {
      ctx.strokeStyle = m === 1 ? core : halo;
      for (let c = 0; c < 3; c++) { ctx.lineWidth = Math.max(WID[c] * m * (o.wmul || 1), (m === 1 ? .7 : 1.4) / s); ctx.globalAlpha = clamp(a * pa); ctx.stroke(N.paths[c]); }
      if (o.axon !== false) { ctx.lineWidth = Math.max(.9 * m, .6 / s); ctx.globalAlpha = clamp(a * pa * (o.axonA ?? .75)); ctx.stroke(N.axonPath); }
    }
    ctx.restore();
    if (o.soma !== false) { glow(ctx, x, y, 40 * s * (1 + dof), halo, a * .55); glow(ctx, x, y, 16 * s, core, a * .95); dot(ctx, x, y, Math.max(.8, 5.5 * s), core, a * .9 * (1 - dof * .6)); }
  }
  // 沿路径行进的电脉冲（亮头 + 渐隐尾）
  function pulse(ctx, R, u, x, y, s, rot, col, a, r0 = 12, tail = .05) {
    if (a <= 0 || u < 0 || u > 1) return;
    ctx.save(); ctx.globalCompositeOperation = 'lighter';
    for (let k = 0; k < 6; k++) { const p = along(R, (u - k * tail / 5) * R.len); const q = L2S(x, y, s, rot, p[0], p[1]); glow(ctx, q[0], q[1], Math.max(3, r0 * s) * (1 - k * .13), col, a * (1 - k * .16)); }
    ctx.restore();
  }

  // 神经元星海：三维纵深中漂移的神经元
  const FIELD = (() => { const r = rng(4242); const a = []; for (let i = 0; i < 120; i++) a.push({ x: (r() - .5) * 3800, y: (r() - .5) * 2300, z: r(), tpl: i % TPL.length, rot: r() * TAU, ph: r() * 20, per: 2.2 + r() * 3.6, hue: r() }); return a; })();
  function field(ctx, t, o = {}) {
    const a0 = o.alpha ?? 1; if (a0 <= 0) return;
    const D = 4400, near = 140, speed = o.speed ?? 110, fov = 950;
    const spin = (o.roll || 0) + t * (o.spin || 0); const cs = Math.cos(spin), sn = Math.sin(spin);
    const list = [];
    for (const n of FIELD) {
      const z = (((n.z * D - t * speed - (o.z0 || 0)) % D) + D) % D + near;
      const X = n.x * cs - n.y * sn, Y = n.x * sn + n.y * cs;
      const s = fov / z; const px = W / 2 + X * s + (o.dx || 0), py = H / 2 + Y * s + (o.dy || 0);
      const Rr = 330 * s; if (px < -Rr || px > W + Rr || py < -Rr || py > H + Rr) continue;
      const f = smooth(near + D, D - 500, z) * smooth(near, near + 650, z); if (f < .02) continue;
      list.push({ n, z, s, px, py, f });
    }
    list.sort((p, q) => q.z - p.z);
    for (const it of list) {
      const N = TPL[it.n.tpl]; const dof = smooth(1000, 300, it.z); const fog = .22 + .78 * smooth(D, 900, it.z);
      const col = it.n.hue < .14 ? ['#d6e4ff', '#5f8dff'] : it.n.hue < .27 ? ['#dafff3', '#3fd2b0'] : ['#e6fcff', '#46c6dc'];
      const rot = it.n.rot + spin, sc = it.s * .9, aa = a0 * it.f * fog;
      drawNeuron(ctx, N, it.px, it.py, sc, rot, { alpha: aa * (o.dim ?? 1), core: col[0], halo: col[1], dof });
      if (o.spikes && aa > .12) {
        const tc = ((t + it.n.ph) % it.n.per + it.n.per) % it.n.per;
        const R = N.routes[Math.floor(it.n.ph * 7) % N.routes.length];
        if (tc < .8) pulse(ctx, R, tc / .8, it.px, it.py, sc, rot, '#f2feff', aa * o.spikes, 22, .08);
        const fl = smooth(.75, .85, tc) * (1 - smooth(.9, 1.5, tc)); if (fl > 0) { glow(ctx, it.px, it.py, 110 * sc, col[1], fl * aa * o.spikes * .9); glow(ctx, it.px, it.py, 30 * sc, '#ffffff', fl * aa * o.spikes); }
        if (tc > .85 && tc < 2.2) pulse(ctx, N.axon, (tc - .85) / 1.35, it.px, it.py, sc, rot, col[0], aa * o.spikes * .9, 20, .06);
      }
    }
  }

  // ---------- 细胞膜 ----------
  // yf(x) 给出膜中线；half 为两层头基间距之半
  function bilayer(ctx, x0, x1, o = {}) {
    const a = o.alpha ?? 1; if (a <= 0) return;
    const half = o.half ?? 60, sp = o.sp ?? 15, hr = o.hr ?? 6.5, t = o.t || 0, yf = o.yf, skip = o.skip;
    ctx.save(); ctx.globalAlpha = a;
    // 疏水核心：温暖的半透明带
    ctx.beginPath(); for (let x = x0; x <= x1; x += 10) ctx.lineTo(x, yf(x) - half + hr); for (let x = x1; x >= x0; x -= 10) ctx.lineTo(x, yf(x) + half - hr); ctx.closePath();
    const cg = ctx.createLinearGradient(0, yf((x0 + x1) / 2) - half, 0, yf((x0 + x1) / 2) + half);
    cg.addColorStop(0, 'rgba(240,170,160,.05)'); cg.addColorStop(.5, 'rgba(250,200,170,.13)'); cg.addColorStop(1, 'rgba(240,170,160,.05)'); ctx.fillStyle = cg; ctx.fill();
    const heads = new Path2D(), back = new Path2D(), tails = new Path2D();
    for (let x = x0; x <= x1; x += sp) {
      const y = yf(x), d = (yf(x + 1) - y); const nn = Math.hypot(1, d), nx = -d / nn, ny = 1 / nn;
      for (const sd of [-1, 1]) {
        const skipHere = skip && skip(x);
        const xb = x + sp / 2, yb = yf(xb);
        if (!(skip && skip(xb))) { const bx = xb + nx * sd * (half - 2), by = yb + ny * sd * (half - 2); back.moveTo(bx + hr * .8, by); back.arc(bx, by, hr * .8, 0, TAU); }
        if (skipHere) continue;
        const hx = x + nx * sd * half, hy = y + ny * sd * half; heads.moveTo(hx + hr, hy); heads.arc(hx, hy, hr, 0, TAU);
        for (const k of [-1, 1]) {
          const wob = 2.2 * Math.sin(x * .07 + k * 1.7 + t * 1.6 + sd);
          const sx = hx + k * 2.4 - nx * sd * hr, sy = hy - ny * sd * hr;
          const ex = x + k * 2.4 + nx * sd * 5, ey = y + ny * sd * 5;
          tails.moveTo(sx, sy); tails.quadraticCurveTo((sx + ex) / 2 + wob, (sy + ey) / 2, ex + wob * .4, ey);
        }
      }
    }
    ctx.strokeStyle = o.tail || 'rgba(238,186,170,.42)'; ctx.lineWidth = 1.5; ctx.stroke(tails);
    ctx.fillStyle = o.back || 'rgba(170,120,120,.45)'; ctx.fill(back);
    ctx.fillStyle = o.head || '#f0c8b8'; ctx.fill(heads);
    ctx.globalAlpha = a * .5; ctx.strokeStyle = 'rgba(255,240,230,.7)'; ctx.lineWidth = 1; ctx.stroke(heads);
    ctx.restore();
  }
  function capsule(ctx, x, y, w, h) { ctx.beginPath(); ctx.roundRect(x, y, w, h, w / 2); }
  // 一根 α 螺旋：玻璃质感圆柱 + 螺旋纹
  function helix(ctx, x, y, w, h, tilt, a, o = {}) {
    ctx.save(); ctx.translate(x, y); ctx.rotate(tilt); ctx.globalAlpha = a;
    capsule(ctx, -w / 2, -h / 2, w, h);
    const g = ctx.createLinearGradient(-w / 2, 0, w / 2, 0);
    const c = o.col || [190, 246, 238];
    g.addColorStop(0, `rgba(${c[0]},${c[1]},${c[2]},.85)`); g.addColorStop(.42, `rgba(${c[0] * .45 | 0},${c[1] * .75 | 0},${c[2] * .75 | 0},.62)`); g.addColorStop(1, `rgba(${c[0] * .12 | 0},${c[1] * .28 | 0},${c[2] * .32 | 0},.88)`);
    ctx.fillStyle = g; ctx.fill();
    ctx.save(); ctx.clip(); ctx.strokeStyle = 'rgba(255,255,255,.16)'; ctx.lineWidth = 2.2;
    ctx.beginPath(); for (let k = -h / 2 - 20; k < h / 2 + 20; k += 15) { ctx.moveTo(-w / 2 - 4, k); ctx.quadraticCurveTo(0, k + 12, w / 2 + 4, k + 4); } ctx.stroke();
    ctx.restore();
    ctx.strokeStyle = 'rgba(220,255,250,.5)'; ctx.lineWidth = 1.2; capsule(ctx, -w / 2, -h / 2, w, h); ctx.stroke();
    ctx.restore();
  }
  // 视黄醛：β-紫罗兰酮环 + 多烯链；bend 0→1 表示全反式→13-顺式的弯折
  function retinalPts(bend) {
    const pts = []; let px = -40, py = 0; pts.push([px, py]);
    for (let i = 0; i < 9; i++) { const ang = (i % 2 ? 1 : -1) * Math.PI / 6; px += Math.cos(ang) * 11; py += Math.sin(ang) * 11; pts.push([px, py]); }
    if (bend > 0) { const c = pts[5], th = -bend * 1.1; for (let i = 6; i < pts.length; i++) { const dx = pts[i][0] - c[0], dy = pts[i][1] - c[1]; pts[i] = [c[0] + dx * Math.cos(th) - dy * Math.sin(th), c[1] + dx * Math.sin(th) + dy * Math.cos(th)]; } }
    return pts;
  }
  function retinal(ctx, x, y, s, bend, ex, a) {
    if (a <= 0) return;
    const pts = retinalPts(bend).map(p => [x + p[0] * s, y + p[1] * s]);
    const ring = []; for (let k = 0; k <= 6; k++) { const an = k / 6 * TAU + Math.PI / 6; ring.push([x + (-51 + Math.cos(an) * 11) * s, y + Math.sin(an) * 11 * s]); }
    const col = hex(mix(AMB, '#cfe6ff', ex)), cs = col;
    glowLine(ctx, pts, cs, 2.6 * s, a, '#fff4d8'); glowLine(ctx, ring, cs, 2.4 * s, a, '#fff4d8');
    // 甲基侧链
    ctx.save(); ctx.globalCompositeOperation = 'lighter'; ctx.strokeStyle = rgba(col, .8 * a); ctx.lineWidth = 1.6 * s; ctx.beginPath();
    for (const i of [2, 6]) { const p = pts[i]; ctx.moveTo(p[0], p[1]); ctx.lineTo(p[0], p[1] + (i % 2 ? 1 : -1) * 10 * s * (i === 6 ? 1 : -1)); } ctx.stroke(); ctx.restore();
    for (const p of pts) glow(ctx, p[0], p[1], 7 * s, col, .5 * a);
    if (ex > 0) glow(ctx, x, y, 90 * s * ex + 20, '#cfe6ff', ex * a * .9);
  }
  // 视紫红质类蛋白（七次跨膜）：侧视图。open：孔道张开；bend：视黄醛弯折；ex：受激发光
  const HX = [{ x: -54, b: 1, t: .05 }, { x: 0, b: 1, t: -.03 }, { x: 54, b: 1, t: .06 }, { x: -82, b: 0, t: -.06 }, { x: -28, b: 0, t: .08 }, { x: 28, b: 0, t: -.07 }, { x: 82, b: 0, t: .05 }];
  function rhodo(ctx, x, y, s, o = {}) {
    const a = o.alpha ?? 1; if (a <= 0) return; const open = o.open || 0;
    const shift = hx => (hx < 0 ? -1 : hx > 0 ? 1 : 0) * open * 16;
    // 孔道光
    if (open > 0) {
      ctx.save(); ctx.globalCompositeOperation = 'lighter';
      const g = ctx.createLinearGradient(0, y - 150 * s, 0, y + 150 * s); g.addColorStop(0, 'rgba(120,190,255,0)'); g.addColorStop(.5, `rgba(150,210,255,${.35 * open * a})`); g.addColorStop(1, 'rgba(120,190,255,0)');
      ctx.fillStyle = g; ctx.fillRect(x - 26 * s * open, y - 150 * s, 52 * s * open, 300 * s); ctx.restore();
      glow(ctx, x, y, 120 * s, BLUE2, .25 * open * a);
    }
    for (const h of HX) if (h.b) helix(ctx, x + (h.x + shift(h.x)) * s, y + 4 * s, 38 * s, 236 * s, h.t + (h.x < 0 ? -1 : h.x > 0 ? 1 : 0) * open * .05, a * .55, { col: [150, 215, 220] });
    // 视黄醛位于螺旋之间（前排之后）
    retinal(ctx, x + 8 * s, y - 8 * s, s, o.bend || 0, o.ex || 0, a * (o.retA ?? 1));
    for (const h of HX) if (!h.b) helix(ctx, x + (h.x + shift(h.x) * 1.15) * s, y, 40 * s, 250 * s, h.t + (h.x < 0 ? -1 : 1) * open * .07, a * .78);
    // 环区（螺旋之间的连接）
    ctx.save(); ctx.globalAlpha = a * .6; ctx.strokeStyle = 'rgba(170,235,230,.7)'; ctx.lineWidth = 3 * s; ctx.lineCap = 'round';
    const fx = HX.filter(h => !h.b).map(h => x + (h.x + shift(h.x) * 1.15) * s);
    for (let i = 0; i < fx.length - 1; i++) { const top = i % 2 === 0; const yy = y + (top ? -125 : 125) * s; ctx.beginPath(); ctx.moveTo(fx[i], yy); ctx.bezierCurveTo(fx[i], yy + (top ? -40 : 40) * s, fx[i + 1], yy + (top ? -40 : 40) * s, fx[i + 1], yy); ctx.stroke(); }
    ctx.restore();
  }
  // 离子：发光小球 + 符号
  const IONS = { Na: { c: '#ffe2a0', r: 1, s: 'Na⁺' }, H: { c: '#ffffff', r: .7, s: 'H⁺' }, K: { c: '#cdb0ff', r: 1.1, s: 'K⁺' }, Ca: { c: '#8ff0c8', r: 1.05, s: 'Ca²⁺' }, Cl: { c: '#a6f08a', r: 1.1, s: 'Cl⁻' } };
  function ion(ctx, x, y, kind, a, sz = 1, lab = false) {
    if (a <= 0) return; const I = IONS[kind]; const r = 9 * I.r * sz;
    glow(ctx, x, y, r * 3.2, I.c, a * .55); dot(ctx, x, y, r * .78, I.c, a * .9);
    ctx.save(); ctx.globalAlpha = clamp(a); ctx.strokeStyle = 'rgba(20,30,40,.85)'; ctx.lineWidth = 1.6 * sz; ctx.beginPath();
    ctx.moveTo(x - r * .4, y); ctx.lineTo(x + r * .4, y); if (kind !== 'Cl') { ctx.moveTo(x, y - r * .4); ctx.lineTo(x, y + r * .4); } ctx.stroke(); ctx.restore();
    if (lab) text(ctx, I.s, x + r + 6, y - r - 4, { size: 20 * sz, font: 'song', weight: 500, align: 'left', color: I.c, alpha: a * .95 });
  }

  // ---------- 示波器 ----------
  function scopeFrame(ctx, x, y, w, h, a) {
    if (a <= 0) return; ctx.save(); ctx.globalAlpha = a;
    ctx.strokeStyle = 'rgba(140,220,235,.07)'; ctx.lineWidth = 1; ctx.beginPath();
    for (let i = 1; i < 10; i++) { const xx = x + w * i / 10; ctx.moveTo(xx, y); ctx.lineTo(xx, y + h); }
    for (let j = 1; j < 8; j++) { const yy = y + h * j / 8; ctx.moveTo(x, yy); ctx.lineTo(x + w, yy); } ctx.stroke();
    ctx.strokeStyle = 'rgba(170,230,245,.5)'; ctx.lineWidth = 1.3; const k = 16; ctx.beginPath();
    for (const [cx, cy, sx, sy] of [[x, y, 1, 1], [x + w, y, -1, 1], [x, y + h, 1, -1], [x + w, y + h, -1, -1]]) { ctx.moveTo(cx + sx * k, cy); ctx.lineTo(cx, cy); ctx.lineTo(cx, cy + sy * k); }
    ctx.stroke(); ctx.restore();
  }

  // ---------- 场景 ----------
  const scenes = {};

  // 1. 八百六十亿：神经元星海 → 琴弦
  const STR = (() => { const a = []; for (let i = 0; i < 11; i++) { const r = rng(300 + i); const ts = []; let tt = -4 + r() * 1.2; while (tt < 24) { ts.push(tt); tt += .3 + r() * 1.25; } const tuft = []; const nd = 3 + Math.floor(r() * 2); for (let j = 0; j < nd; j++) { const a0 = Math.PI + (j - (nd - 1) / 2) * .55 + (r() - .5) * .25, L = 18 + r() * 16; const p1 = [Math.cos(a0) * L, Math.sin(a0) * L * .8]; tuft.push([[0, 0], p1]); for (const sd of [-1, 1]) { const a1 = a0 + sd * (.35 + r() * .25), L2 = 10 + r() * 10; tuft.push([p1, [p1[0] + Math.cos(a1) * L2, p1[1] + Math.sin(a1) * L2 * .8]]); } } a.push({ ts, tuft }); } return a; })();
  const PL = 6;
  function strings(ctx, t, S, m, ra) {
    if (ra <= 0) return;
    const tP0 = wt(S, 1, '亲手') - .5, tP1 = wt(S, 1, '拨动') + .15, tP2 = tP1 + .6;
    const quiet = smooth(tP0 - 1.4, tP0 + .2, t);
    const geo = i => { const k = i - 5; return { xl: lerp(560, 300, m), yl: lerp(712 + k * 8, 500 + k * 40, m), xr: lerp(1360, 1630, m), yr: lerp(712 + k * 8, 500 + k * 50, m) }; };
    const travel = lerp(3.2, 1.9, m);
    // 拨弦物理：三角初始形状的弦模分解
    const G6 = geo(PL); const xc = 1040, up = (xc - G6.xl) / (G6.xr - G6.xl);
    const hPull = 48 * E.out(prog(t, tP1, tP2, x => x));
    const tau = t - tP2; const om = TAU * 2.2, gam = .55;
    const modal = (u, tt) => { let y = 0; for (let n = 1; n <= 6; n++) { const an = 2 * hPull / (n * n * Math.PI * Math.PI * up * (1 - up)) * Math.sin(n * Math.PI * up); y += an * Math.sin(n * Math.PI * u) * Math.cos(n * om * tt) * Math.exp(-gam * n * tt); } return y; };
    const envl = u => { let y = 0; for (let n = 1; n <= 6; n++) { const an = 2 * hPull / (n * n * Math.PI * Math.PI * up * (1 - up)) * Math.sin(n * Math.PI * up); y += Math.abs(an * Math.sin(n * Math.PI * u)) * Math.exp(-gam * n * tau); } return y; };
    const dispP = u => t < tP1 ? 0 : t < tP2 ? hPull * (u < up ? u / up : (1 - u) / (1 - up)) : modal(u, tau);
    const plucked = smooth(tP2 - .1, tP2 + .3, t);
    ctx.save(); ctx.globalCompositeOperation = 'lighter';
    for (let i = 0; i < 11; i++) {
      const g = geo(i); const isP = i === PL && t > tP1;
      const symp = t > tP2 ? 4 * Math.exp(-Math.abs(i - PL) * .55) * Math.exp(-.7 * tau) : 0;
      const pts = []; const N = isP || symp > .05 ? 90 : 2;
      for (let k = 0; k <= N; k++) { const u = k / N; let dy = 0; if (isP) dy = dispP(u); else if (symp > .05) dy = symp * Math.sin(Math.PI * u) * Math.cos(om * 1.3 * tau + i); pts.push([lerp(g.xl, g.xr, u), lerp(g.yl, g.yr, u) + dy]); }
      // 弦：从栅格行渐变为亮弦
      const base = ra * (.18 + .3 * m) * (1 - .35 * quiet * (i === PL ? 0 : 1));
      if (isP) {
        if (t > tP2) { // 振动包络（快速振动的残影）
          ctx.beginPath(); for (let k = 0; k <= 60; k++) { const u = k / 60; ctx.lineTo(lerp(g.xl, g.xr, u), lerp(g.yl, g.yr, u) - envl(u)); } for (let k = 60; k >= 0; k--) { const u = k / 60; ctx.lineTo(lerp(g.xl, g.xr, u), lerp(g.yl, g.yr, u) + envl(u)); }
          ctx.closePath(); ctx.fillStyle = rgba(BLUE2, .24 * ra); ctx.fill();
        }
        glowLine(ctx, pts, BLUE2, 2.6 + 1.2 * plucked * Math.exp(-.8 * Math.max(0, tau)), ra * (.6 + .4 * plucked), '#eaf4ff');
      } else glowLine(ctx, pts, FIL, 1.1, base, '#d8f6ff');
      // 栅格刻度 / 弦上脉冲（交响）
      const play = ra * (1 - quiet);
      if (play > 0) for (const ts of STR[i].ts) {
        const u = (t - ts) / travel; if (u < 0 || u > 1) continue;
        const x = lerp(g.xl, g.xr, u), y = lerp(g.yl, g.yr, u); const fade = smooth(0, .06, u) * (1 - smooth(.85, 1, u));
        if (m < 1) { ctx.globalAlpha = play * (1 - m) * fade * .9; ctx.strokeStyle = '#dff8ff'; ctx.lineWidth = 1.6; ctx.beginPath(); ctx.moveTo(x, y - 3.5); ctx.lineTo(x, y + 3.5); ctx.stroke(); ctx.globalAlpha = 1; }
        if (m > 0) { glow(ctx, x, y, 16, '#bff2ff', play * m * fade * .9); glow(ctx, x - 14, y, 9, FIL, play * m * fade * .4); }
      }
    }
    ctx.restore();
    // 弦端的神经元胞体与末梢
    if (m > 0) for (let i = 0; i < 11; i++) {
      const g = geo(i); const hot = i === PL ? smooth(tP2, tP2 + .15, t) * (1 - smooth(tP2 + .6, tP2 + 2.5, t)) : 0;
      ctx.save(); ctx.globalCompositeOperation = 'lighter'; ctx.lineCap = 'round'; ctx.translate(g.xl - 8, g.yl); ctx.scale(m, m);
      for (const [w, al, c] of [[4, .12, hot > .1 ? BLUE2 : FIL], [1.2, .75, hot > .1 ? '#eaf3ff' : '#d8f6ff']]) { ctx.strokeStyle = c; ctx.lineWidth = w; ctx.globalAlpha = m * ra * al; ctx.beginPath(); for (const [p0, p1] of STR[i].tuft) { ctx.moveTo(p0[0], p0[1]); ctx.lineTo(p1[0], p1[1]); } ctx.stroke(); }
      ctx.restore();
      glow(ctx, g.xl - 10, g.yl, 26, i === PL && t > tP2 ? BLUE2 : FIL, m * ra * (.5 + hot)); glow(ctx, g.xl - 10, g.yl, 8, '#ffffff', m * ra * .9);
      ctx.save(); ctx.globalCompositeOperation = 'lighter'; ctx.globalAlpha = m * ra * .6; ctx.strokeStyle = '#bfefff'; ctx.lineWidth = 1.2; ctx.beginPath();
      for (const dy of [-9, 0, 9]) { ctx.moveTo(g.xr, g.yr); ctx.quadraticCurveTo(g.xr + 10, g.yr + dy * .4, g.xr + 20, g.yr + dy); } ctx.stroke(); ctx.restore();
      for (const dy of [-9, 0, 9]) glow(ctx, g.xr + 21, g.yr + dy, 7, i === PL && t > tP2 + 1 ? BLUE2 : '#dff8ff', m * ra * (.55 + (i === PL ? smooth(tP2 + .9, tP2 + 1.2, t) * (1 - smooth(tP2 + 1.6, tP2 + 3, t)) : 0)));
    }
    // 一点光：拨动琴弦
    if (t > tP0 - .2 && t < tP2 + 1.4) {
      const g = geo(PL); const yc0 = lerp(g.yl, g.yr, up);
      let px, py, la;
      if (t < tP1) { const u = E.inOut(prog(t, tP0, tP1, x => x)); px = lerp(1580, xc, u) + Math.sin(u * Math.PI) * 80; py = lerp(160, yc0 - 6, u) - Math.sin(u * Math.PI) * 40; la = smooth(tP0 - .2, tP0 + .4, t); }
      else if (t < tP2) { px = xc; py = yc0 + hPull - 6; la = 1; }
      else { const u = E.out(prog(t, tP2, tP2 + 1.2, x => x)); px = xc + u * 70; py = yc0 - 6 - u * 150; la = 1 - u; }
      glow(ctx, px, py, 110, BLUE, .35 * la); glow(ctx, px, py, 34, BLUE2, .9 * la); glow(ctx, px, py, 10, '#ffffff', la);
      // 脉冲沿被拨动的弦奔出
      const su = prog(t, tP2 + .05, tP2 + 1.1, x => x);
      if (su > 0 && su < 1) { const x = lerp(g.xl, g.xr, su), y = lerp(g.yl, g.yr, su) + dispP(su); glow(ctx, x, y, 46, BLUE2, .8); glow(ctx, x, y, 14, '#ffffff', 1); }
      if (t > tP2) { glow(ctx, xc, yc0, 340, BLUE, .32 * Math.exp(-1.1 * tau)); glow(ctx, (G6.xl + G6.xr) / 2, lerp(G6.yl, G6.yr, .5), 700, BLUE, .12 * Math.exp(-.9 * tau)); }
    }
  }
  scenes.brain = (ctx, S) => {
    const t = S.t, c1 = S.cue(1);
    deep(ctx, t, { neb: .2, seed: 0 });
    const m = E.inOut(prog(t, c1 - .3, c1 + 2.2, x => x));
    field(ctx, t, { alpha: smooth(-.5, 2.2, t) * (1 - .9 * smooth(c1 - .6, c1 + 1.6, t)), speed: 125, spin: .012, spikes: 1 });
    const ca = smooth(1.3, 2.3, t) * (1 - smooth(c1 - .9, c1 + .2, t));
    if (ca > 0) {
      shade(ctx, W / 2, 540, 680, 360, .7 * ca);
      counter(ctx, 860 * E.out(prog(t, 1.4, 4.4, x => x)), W / 2 - 32, 425, { alpha: ca, size: 160, unit: '亿', format: v => String(Math.round(v)), glowColor: ACC, unitColor: '#d6f2ff' });
      text(ctx, '个神经元', W / 2, 560, { size: 40, font: 'song', weight: 500, spacing: .5, color: '#e2f6fa', alpha: ca * smooth(2.2, 3.2, t) });
      text(ctx, 'NEURONS IN THE HUMAN BRAIN', W / 2, 612, { size: 16, font: 'latin', weight: 600, spacing: .38, color: rgba(ACC, .9), alpha: ca * smooth(2.6, 3.6, t) });
    }
    const ra = smooth(wt(S, 0, '以毫秒') - .4, wt(S, 0, '以毫秒') + .8, t);
    shade(ctx, W / 2, 716, 560, 95, .7 * ra * (1 - m));
    strings(ctx, t, S, m, ra);
    const la = smooth(wt(S, 0, '以毫秒'), wt(S, 0, '以毫秒') + 1, t) * (1 - smooth(c1 - .6, c1 + .2, t));
    if (la > 0) text(ctx, '以毫秒为节拍放电', W / 2, 782, { size: 22, font: 'song', weight: 400, spacing: .45, color: '#9fdcea', alpha: la * .85 });
  };

  // 2. 片名
  scenes.title = (ctx, S) => {
    const t = S.t; deep(ctx, t + 19, { neb: .16, seed: 1, motes: .7 });
    field(ctx, t + 19, { alpha: .6 * smooth(-.6, .8, t), speed: 60, spin: .012, spikes: .8 });
    shade(ctx, W / 2, H / 2, 900, 360, .78);
    titleCard(ctx, t, S.d, { kicker: '2026 诺贝尔生理学或医学奖', title: '以光为钥', sub: '光门控离子通道与光遗传学', color: ACC });
  };

  // 3. 神经的电：膜电位与动作电位
  const CHX = [380, 615, 850], MY = 430;
  const NA = (() => { const r = rng(55); const a = []; for (let i = 0; i < 34; i++) { const x = 250 + r() * 740, y = 262 + r() * 62; let j = 0, bd = 1e9; CHX.forEach((c, k) => { if (Math.abs(c - x) < bd) { bd = Math.abs(c - x); j = k; } }); a.push({ x, y, j, d: bd + r() * 60, ph: r() * 10, tx: (r() - .5) * 190, ty: r() * 52 }); } const ord = a.map((o, i) => i).sort((p, q) => a[p].d - a[q].d); ord.forEach((i, k) => { a[i].rank = k; }); return a; })();
  const KI = (() => { const r = rng(56); const a = []; for (let i = 0; i < 15; i++) a.push({ x: 250 + r() * 740, y: 548 + r() * 50, ph: r() * 10 }); return a; })();
  function apV(ms) {
    if (ms < 3) return -70;
    if (ms < 4) return -70 + 15 * (1 - Math.exp(-(ms - 3) * 2.4)) / (1 - Math.exp(-2.4));
    if (ms < 4.45) { const u = (ms - 4) / .45; return -55 + 85 * Math.pow(u, 1.6) * (3 - 2 * u) / (1 + .0 * u) * (u < 1 ? 1 : 1) * (1 / (1 + 0)); }
    if (ms < 5.7) { const u = (ms - 4.45) / 1.25; return 30 - 108 * E.inOutSine(u); }
    const u = clamp((ms - 5.7) / 2.4); return -78 + 8 * (1 - Math.exp(-u * 3.5)) / (1 - Math.exp(-3.5));
  }
  function naChannel(ctx, x, yc, open, a) {
    if (a <= 0) return; const g = open * 12;
    if (open > 0) { ctx.save(); ctx.globalCompositeOperation = 'lighter'; const pg = ctx.createLinearGradient(0, yc - 95, 0, yc + 95); pg.addColorStop(0, 'rgba(255,220,150,0)'); pg.addColorStop(.5, `rgba(255,226,170,${.4 * open * a})`); pg.addColorStop(1, 'rgba(255,220,150,0)'); ctx.fillStyle = pg; ctx.fillRect(x - g - 4, yc - 95, 2 * g + 8, 190); ctx.restore(); }
    helix(ctx, x, yc + 3, 26, 176, 0, a * .5, { col: [150, 215, 220] });
    for (const sd of [-1, 1]) helix(ctx, x + sd * (17 + g), yc, 30, 184, sd * open * .12, a * .85);
  }
  scenes.spike = (ctx, S) => {
    const t = S.t;
    deep(ctx, t + 30, { neb: .12, seed: 2, motes: .5 });
    const tOpen = wt(S, 1, '打开'), tFlood = wt(S, 1, '正离子'), tThr = wt(S, 1, '越过阈值'), tRace = wt(S, 1, '一个电脉冲');
    const hm = pw(t, [[.9, 0], [S.cend(0), 2.5], [tOpen, 2.95], [tThr, 4.0], [tThr + 1.15, 5.75], [tThr + 2.9, 10]]);
    const V = apV(hm) + .5 * noise3(hm * 3, 1, 0);
    const pa = smooth(-.3, 1, t); const dim = 1 - .4 * smooth(tRace + .2, tRace + 1, t);
    const open = smooth(tOpen - .2, tOpen + .6, t) * (1 - smooth(tThr + .9, tThr + 1.8, t));
    const yf = () => MY;
    // —— 膜 ——
    ctx.save(); ctx.globalAlpha = dim;
    bilayer(ctx, 240, 1000, { yf, half: 58, alpha: pa, t, skip: x => CHX.some(c => Math.abs(x - c) < 34) });
    CHX.forEach((c, j) => naChannel(ctx, c, MY, open, pa));
    // 电荷：外正内负；去极化时局部翻转
    const flip = clamp((V + 70) / 100);
    for (let x = 262; x < 1000; x += 46) {
      const nearC = Math.max(...CHX.map(c => 1 - smooth(40, 170, Math.abs(c - x)))); const f = flip * (.35 + .65 * nearC);
      const onCh = c0 => CHX.some(c => Math.abs(c - c0) < 42);
      if (!onCh(x)) { text(ctx, '+', x, MY - 86, { size: 26, font: 'song', weight: 300, color: '#ffd9a8', alpha: pa * .8 * (1 - f) });
      text(ctx, '−', x, MY - 86, { size: 26, font: 'song', weight: 300, color: '#9fd0ff', alpha: pa * .8 * f }); }
      if (!onCh(x + 23)) { text(ctx, '−', x + 23, MY + 86, { size: 26, font: 'song', weight: 300, color: '#9fd0ff', alpha: pa * .8 * (1 - f) });
      text(ctx, '+', x + 23, MY + 86, { size: 26, font: 'song', weight: 300, color: '#ffd9a8', alpha: pa * .8 * f }); }
    }
    // 离子
    for (const n of NA) {
      let x = n.x + 7 * noise3(n.ph, t * .35, 1), y = n.y + 5 * noise3(n.ph, t * .35, 4);
      const flows = n.rank < 18; const ts = tFlood + n.rank * .1;
      if (flows && t > ts) {
        const u = clamp((t - ts) / 1.5); const c = CHX[n.j];
        if (u < .45) { const k = E.in(u / .45); x = lerp(x, c, k); y = lerp(y, MY - 92, k); }
        else if (u < .62) { const k = (u - .45) / .17; x = c; y = lerp(MY - 92, MY + 92, k); }
        else { const k = E.out((u - .62) / .38); x = lerp(c, c + n.tx, k); y = lerp(MY + 92, MY + 112 + n.ty, k); }
      }
      ion(ctx, x, y, 'Na', pa * .95, .95);
    }
    for (const k of KI) ion(ctx, k.x + 6 * noise3(k.ph, t * .3, 2), k.y + 4 * noise3(k.ph, t * .3, 5), 'K', pa * .6, .9);
    text(ctx, '细胞外', 245, 228, { size: 26, font: 'song', weight: 500, align: 'left', color: '#efe6da', alpha: pa * .9, spacing: .25 });
    text(ctx, 'EXTRACELLULAR', 345, 230, { size: 15, font: 'latin', weight: 600, align: 'left', color: rgba(ACC, .85), alpha: pa * .8, spacing: .25 });
    text(ctx, '细胞内', 245, 640, { size: 26, font: 'song', weight: 500, align: 'left', color: '#efe6da', alpha: pa * .9, spacing: .25 });
    text(ctx, 'INTRACELLULAR', 345, 642, { size: 15, font: 'latin', weight: 600, align: 'left', color: rgba(ACC, .85), alpha: pa * .8, spacing: .25 });
    text(ctx, '细胞膜', 222, MY, { size: 26, font: 'song', weight: 500, align: 'right', color: '#f2d6c8', alpha: pa * .9, spacing: .2 });
    const ia = smooth(1.5, 2.5, t) * (1 - smooth(tThr + 1.5, tThr + 2.3, t));
    ion(ctx, 700, 640, 'Na', ia, .9); text(ctx, '钠离子 Na⁺', 720, 640, { size: 22, font: 'song', align: 'left', color: '#ffe2a0', alpha: ia });
    ion(ctx, 870, 640, 'K', ia * .8, .9); text(ctx, '钾离子 K⁺', 890, 640, { size: 22, font: 'song', align: 'left', color: '#d8c4ff', alpha: ia * .8 });
    label(ctx, '离子通道', CHX[2], MY - 92, { alpha: smooth(tOpen - 1.2, tOpen - .2, t) * (1 - smooth(tThr + 1.5, tThr + 2.3, t)), dx: 36, dy: -64, size: 24, en: 'ion channel' });
    ctx.restore();
    // —— 示波器 ——
    const ox = 1130, oy = 255, ow = 680, oh = 370; const X = ms => ox + ms / 10 * ow, Y = v => oy + oh - (v + 90) / 130 * oh;
    ctx.save(); ctx.globalAlpha = dim;
    scopeFrame(ctx, ox, oy, ow, oh, pa);
    ctx.save(); ctx.globalAlpha = pa * dim; ctx.strokeStyle = 'rgba(190,235,245,.55)'; ctx.lineWidth = 1.2; ctx.beginPath(); ctx.moveTo(ox, oy); ctx.lineTo(ox, oy + oh); ctx.lineTo(ox + ow, oy + oh); ctx.stroke();
    ctx.setLineDash([7, 7]); ctx.strokeStyle = 'rgba(255,200,120,.75)'; ctx.beginPath(); ctx.moveTo(ox, Y(-55)); ctx.lineTo(ox + ow, Y(-55)); ctx.stroke();
    ctx.setLineDash([2, 6]); ctx.strokeStyle = 'rgba(190,235,245,.35)'; ctx.beginPath(); ctx.moveTo(ox, Y(0)); ctx.lineTo(ox + ow, Y(0)); ctx.stroke(); ctx.restore();
    for (const [v, s] of [[30, '+30'], [0, '0'], [-55, '−55'], [-70, '−70']]) { text(ctx, s, ox - 14, Y(v) + (v === -70 ? 8 : v === -55 ? -6 : 0), { size: 20, font: 'song', weight: 300, align: 'right', color: v === -55 ? '#ffcf8a' : '#cfe8f0', alpha: pa }); ctx.save(); ctx.globalAlpha = pa; ctx.strokeStyle = 'rgba(190,235,245,.6)'; ctx.beginPath(); ctx.moveTo(ox - 6, Y(v)); ctx.lineTo(ox, Y(v)); ctx.stroke(); ctx.restore(); }
    for (let ms = 0; ms <= 10; ms += 2) text(ctx, String(ms), X(ms), oy + oh + 24, { size: 19, font: 'song', weight: 300, color: '#bcd8e2', alpha: pa });
    text(ctx, '毫伏 mV', ox, oy - 30, { size: 21, font: 'song', align: 'left', color: '#d6eef4', alpha: pa });
    text(ctx, '毫秒 ms', ox + ow, oy + oh + 58, { size: 21, font: 'song', align: 'right', color: '#d6eef4', alpha: pa });
    text(ctx, '阈值', ox + ow - 6, Y(-55) - 16, { size: 20, font: 'song', align: 'right', color: '#ffcf8a', alpha: pa * smooth(tOpen - .5, tOpen + .5, t) });
    text(ctx, '静息电位', ox + 12, Y(-70) + 22, { size: 20, font: 'song', align: 'left', color: '#bfe4ee', alpha: pa * smooth(2, 3, t) * (1 - smooth(tOpen, tOpen + .6, t)) });
    // 曲线
    const pts = []; for (let k = 0; k <= 260; k++) { const ms = k / 260 * hm; pts.push([X(ms), Y(apV(ms) + .5 * noise3(ms * 3, 1, 0))]); }
    if (hm > 0) { glowLine(ctx, pts, '#7fe6ff', 2, pa, '#f2fdff'); const hp = pts[pts.length - 1]; glow(ctx, hp[0], hp[1], 30, '#bff4ff', pa); glow(ctx, hp[0], hp[1], 8, '#ffffff', pa); }
    // 读数
    const vr = Math.round(V); const vs = (vr > 0 ? '+' : vr < 0 ? '−' : '') + Math.abs(vr);
    text(ctx, vs, ox + ow - 62, oy - 52, { size: 64, font: 'song', weight: 300, align: 'right', color: V > -55 ? '#fff1d8' : '#e8fbff', alpha: pa, glow: 14, glowColor: V > -55 ? '#ffb46a' : ACC });
    text(ctx, '毫伏', ox + ow, oy - 44, { size: 24, font: 'song', align: 'right', color: '#cfe8f0', alpha: pa * .9 });
    const apA = smooth(tThr + .9, tThr + 1.7, t);
    label(ctx, '动作电位', X(4.45), Y(30), { alpha: apA, dx: 120, dy: -20, size: 26, en: 'action potential', color: '#fff1d8' });
    if (apA > 0) { ctx.save(); ctx.globalAlpha = apA * .8; ctx.strokeStyle = '#ffd9a0'; ctx.lineWidth = 1.2; const y0 = Y(-88); ctx.beginPath(); ctx.moveTo(X(4), y0 - 6); ctx.lineTo(X(4), y0); ctx.lineTo(X(5.7), y0); ctx.lineTo(X(5.7), y0 - 6); ctx.stroke(); ctx.restore(); text(ctx, '约 1—2 毫秒', X(4.85), Y(-88) - 22, { size: 19, font: 'song', color: '#ffe0b0', alpha: apA }); }
    ctx.restore();
    // —— 轴突 ——
    const ay = 800, ax0 = 150, ax1 = 1790; const axA = smooth(.6, 1.6, t);
    const cx0 = 470;
    if (axA > 0) {
      ctx.save(); ctx.globalAlpha = axA * .3 * dim; ctx.setLineDash([2, 5]); ctx.strokeStyle = '#bfe8f0'; ctx.lineWidth = 1; ctx.beginPath(); ctx.moveTo(cx0 - 18, ay - 18); ctx.lineTo(240, 678); ctx.moveTo(cx0 + 18, ay - 18); ctx.lineTo(1000, 678); ctx.stroke(); ctx.restore();
      ctx.save(); ctx.globalAlpha = axA * .7; ctx.strokeStyle = '#cfefff'; ctx.lineWidth = 1.2; ctx.beginPath(); ctx.arc(cx0, ay, 24, 0, TAU); ctx.stroke(); ctx.restore();
      const tube = []; for (let x = ax0; x <= ax1; x += 20) tube.push([x, ay + 5 * Math.sin(x * .006)]);
      ctx.save(); ctx.globalCompositeOperation = 'lighter';
      ctx.lineCap = 'round'; ctx.strokeStyle = rgba(FIL, .1 * axA); ctx.lineWidth = 22; ctx.beginPath(); tube.forEach((p, i) => i ? ctx.lineTo(p[0], p[1]) : ctx.moveTo(p[0], p[1])); ctx.stroke();
      ctx.strokeStyle = rgba('#bff0ff', .45 * axA); ctx.lineWidth = 1.3; for (const o of [-8, 8]) { ctx.beginPath(); tube.forEach((p, i) => i ? ctx.lineTo(p[0], p[1] + o) : ctx.moveTo(p[0], p[1] + o)); ctx.stroke(); }
      ctx.restore();
      drawNeuron(ctx, TPL[7], ax0 - 10, ay, .55, Math.PI, { alpha: axA * .8, axon: false });
      ctx.save(); ctx.globalCompositeOperation = 'lighter'; ctx.strokeStyle = rgba('#cfefff', .6 * axA); ctx.lineWidth = 1.2; ctx.beginPath(); for (const dy of [-22, -8, 8, 22]) { ctx.moveTo(ax1, ay); ctx.quadraticCurveTo(ax1 + 16, ay + dy * .3, ax1 + 34, ay + dy); } ctx.stroke(); ctx.restore();
      text(ctx, '轴突', 1320, ay + 46, { size: 24, font: 'song', weight: 500, color: '#e6f4f6', alpha: axA * .85, spacing: .3 });
      text(ctx, 'AXON', 1320, ay + 76, { size: 15, font: 'latin', weight: 600, color: rgba(ACC, .85), alpha: axA * .8, spacing: .3 });
      // 动作电位沿轴突飞驰
      const ru = E.inOut(prog(t, tRace + .1, tRace + 2.2, x => x));
      if (t > tRace + .1) {
        const hx = lerp(cx0, ax1, ru), hy = ay + 5 * Math.sin(hx * .006);
        const bg = ctx.createLinearGradient(hx - 360, 0, hx + 30, 0); bg.addColorStop(0, 'rgba(255,200,120,0)'); bg.addColorStop(.8, 'rgba(255,214,150,.4)'); bg.addColorStop(1, 'rgba(255,240,210,0)');
        ctx.save(); ctx.globalCompositeOperation = 'lighter'; ctx.fillStyle = bg; ctx.fillRect(hx - 360, ay - 16, 390, 32); ctx.restore();
        if (ru < 1) { glow(ctx, hx, hy, 120, '#ffb45a', .5); glow(ctx, hx, hy, 34, '#fff0d0', 1); glow(ctx, hx, hy, 10, '#ffffff', 1); }
        const arr = smooth(tRace + 2.1, tRace + 2.3, t) * (1 - smooth(tRace + 2.4, tRace + 3.4, t)); if (arr > 0) glow(ctx, ax1 + 20, ay, 140, '#ffd27a', arr * .8);
      }
    }
  };
  const c1o = S => S.cue(1);

  // 4. 旧工具之困
  function tissue(seed, cx, cy, rx, ry, n, md = 44) {
    const r = rng(seed); const a = []; let guard = 0;
    while (a.length < n && guard++ < 6000) { const x = cx + (r() * 2 - 1) * rx, y = cy + (r() * 2 - 1) * ry; if (((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2 > 1) continue; if (a.some(q => Math.hypot(q.x - x, q.y - y) < md)) continue; a.push({ x, y, tpl: Math.floor(r() * MINI.length), rot: r() * TAU, s: .6 + r() * .35, type: Math.floor(r() * 3), ph: r() * 10 }); }
    return a;
  }
  const TA = tissue(71, 500, 545, 300, 210, 46, 52), TB = tissue(72, 1420, 545, 300, 210, 46, 52);
  const TCOL = [['#e2f7ff', '#5fc8e0'], ['#e6e4ff', '#8a8ce8'], ['#e2fff2', '#4fcfa6']];
  scenes.oldtools = (ctx, S) => {
    const t = S.t, c1 = S.cue(1);
    deep(ctx, t + 50, { neb: .1, seed: 3, motes: .5 });
    const tZap = wt(S, 0, '周围') + .1, tDrug = wt(S, 0, '药物'), tMin = wt(S, 0, '以分钟计'), tAny = wt(S, 0, '也挑不出');
    const pA = (1 - smooth(c1 - .4, c1 + .5, t)) * smooth(-.3, .8, t);
    if (pA > 0) {
      ctx.save(); ctx.globalAlpha = pA;
      // 分隔线
      ctx.strokeStyle = 'rgba(170,220,235,.18)'; ctx.lineWidth = 1; ctx.beginPath(); ctx.moveTo(960, 250); ctx.lineTo(960, 840); ctx.stroke();
      ctx.restore();
      // —— 电极 ——
      const tip = [520, 520];
      for (const c of TA) {
        const d = Math.hypot(c.x - tip[0], c.y - tip[1]); const ta = tZap + d / 700;
        const on = (1 - smooth(150, 230, d)) * smooth(ta, ta + .1, t) * (.55 + .45 * (1 - smooth(ta + .3, ta + 2.4, t)));
        const flick = on > 0 ? .75 + .25 * Math.sin(t * 23 + c.ph * 5) : 1;
        drawNeuron(ctx, MINI[c.tpl], c.x, c.y, c.s, c.rot, { alpha: pA * (.26 + .74 * on * flick), lite: true, core: on > .2 ? '#ffffff' : TCOL[c.type][0], halo: on > .2 ? '#bff4ff' : TCOL[c.type][1], axonA: .4 });
        if (on > 0) glow(ctx, c.x, c.y, 50 * c.s, '#dff8ff', on * pA * .7);
      }
      const app = E.out(prog(t, 0, 1.4, x => x)); const tx = lerp(800, tip[0], app), ty = lerp(140, tip[1], app);
      ctx.save(); ctx.globalAlpha = pA; const ang = Math.atan2(ty - 40, tx - 900);
      ctx.translate(tx, ty); ctx.rotate(Math.atan2(40 - ty, 900 - tx));
      const eg = ctx.createLinearGradient(0, -9, 0, 9); eg.addColorStop(0, '#e9eef2'); eg.addColorStop(.45, '#8b98a3'); eg.addColorStop(1, '#2c343b');
      ctx.fillStyle = eg; ctx.beginPath(); ctx.moveTo(0, 0); ctx.lineTo(90, -5); ctx.lineTo(700, -9); ctx.lineTo(700, 9); ctx.lineTo(90, 5); ctx.closePath(); ctx.fill();
      ctx.fillStyle = 'rgba(30,42,50,.75)'; ctx.beginPath(); ctx.moveTo(120, -6); ctx.lineTo(700, -10); ctx.lineTo(700, 10); ctx.lineTo(120, 6); ctx.closePath(); ctx.fill();
      ctx.strokeStyle = 'rgba(255,255,255,.55)'; ctx.lineWidth = 1; ctx.beginPath(); ctx.moveTo(4, -.5); ctx.lineTo(120, -5.5); ctx.lineTo(700, -8); ctx.stroke();
      ctx.restore(); glow(ctx, tx, ty, 16, '#dff4ff', pA * .6);
      const z = smooth(tZap - .05, tZap + .05, t) * (1 - smooth(tZap + .2, tZap + .9, t));
      if (z > 0) {
        glow(ctx, tip[0], tip[1], 260, '#bfe8ff', z * .6); glow(ctx, tip[0], tip[1], 40, '#ffffff', z);
        const q = Math.floor(t * 18); ctx.save(); ctx.globalCompositeOperation = 'lighter'; ctx.strokeStyle = rgba('#e8f8ff', .85 * z); ctx.lineWidth = 1.6;
        for (let k = 0; k < 7; k++) { let x = tip[0], y = tip[1]; const a0 = hash(k, q) * TAU; ctx.beginPath(); ctx.moveTo(x, y); for (let j = 0; j < 6; j++) { const a = a0 + (hash(k * 9 + j, q + 3) - .5) * 1.4; x += Math.cos(a) * 22; y += Math.sin(a) * 22; ctx.lineTo(x, y); } ctx.stroke(); }
        ctx.restore();
      }
      const wv = prog(t, tZap, tZap + .6, x => x); if (wv > 0 && wv < 1) { ctx.save(); ctx.globalCompositeOperation = 'lighter'; ctx.strokeStyle = rgba('#bff0ff', .5 * (1 - wv)); ctx.lineWidth = 2; ctx.beginPath(); ctx.ellipse(tip[0], tip[1], 230 * wv, 215 * wv, 0, 0, TAU); ctx.stroke(); ctx.restore(); }
      term(ctx, '电极', 'electrode', 240, 210, { alpha: pA * smooth(.3, 1.1, t), color: ACC, size: 36, align: 'left' });
      text(ctx, '周围细胞一并激活', 500, 858, { size: 30, font: 'song', weight: 500, color: '#e6f8ff', alpha: pA * smooth(tZap + .4, tZap + 1.2, t), spacing: .15 });
      // —— 药物 ——
      const dc = [1420, 520]; const dr = 300 * Math.sqrt(prog(t, tDrug + .2, tDrug + 5.5, x => x));
      if (dr > 2) GLFX.layer(ctx, 'nebula', { T: t * .6, C1: '#2a1650', C2: '#6a42c0', C3: '#d6b8ff', S: 3.2, D: .7, A: 1.25 * pA, MODE: 0, OFF: [1.3, 2.2], MC: GLFX.uv(dc[0], dc[1]), MR: [dr / H * 1.35, dr / H * 1.15] }, { scale: .35 });
      for (const c of TB) {
        const d = Math.hypot(c.x - dc[0], c.y - dc[1]); const inf = smooth(dr + 10, dr - 90, d);
        const pulseB = .5 + .5 * Math.sin(t * 1.2 + c.ph);
        drawNeuron(ctx, MINI[c.tpl], c.x, c.y, c.s, c.rot, { alpha: pA * (.26 + .34 * inf * pulseB), lite: true, core: inf > .3 ? '#efe2ff' : TCOL[c.type][0], halo: inf > .3 ? VIO : TCOL[c.type][1], axonA: .4 });
      }
      const pp = E.out(prog(t, tDrug - .8, tDrug + .2, x => x));
      { const py0 = lerp(60, 200, pp), top = py0 - 110, tipY = py0 + 200; ctx.save(); ctx.globalAlpha = pA * pp;
        const vg = ctx.createLinearGradient(0, top, 0, tipY); vg.addColorStop(0, 'rgba(210,230,250,0)'); vg.addColorStop(.35, 'rgba(210,230,250,.42)'); vg.addColorStop(1, 'rgba(210,230,250,.5)');
        ctx.fillStyle = vg; ctx.beginPath(); ctx.moveTo(1404, top); ctx.lineTo(1436, top); ctx.lineTo(1436, py0 + 100); ctx.lineTo(1424, tipY); ctx.lineTo(1416, tipY); ctx.lineTo(1404, py0 + 100); ctx.closePath(); ctx.fill();
        ctx.fillStyle = 'rgba(8,16,22,.55)'; ctx.fillRect(1409, top, 22, py0 + 100 - top);
        const fg = ctx.createLinearGradient(0, top, 0, py0 + 100); fg.addColorStop(0, 'rgba(181,140,255,0)'); fg.addColorStop(.5, 'rgba(181,140,255,.55)'); fg.addColorStop(1, 'rgba(181,140,255,.6)'); ctx.fillStyle = fg; ctx.fillRect(1410, py0 - 40, 20, 140);
        ctx.restore(); glow(ctx, 1420, tipY + 4, 22, VIO, pA * pp * .8); }
      // 时钟
      const ka = pA * smooth(tMin - .3, tMin + .5, t); const kx = 1745, ky = 330;
      if (ka > 0) {
        ctx.save(); ctx.globalAlpha = ka; ctx.strokeStyle = 'rgba(230,220,255,.8)'; ctx.lineWidth = 1.6; ctx.beginPath(); ctx.arc(kx, ky, 48, 0, TAU); ctx.stroke();
        ctx.lineWidth = 1.2; for (let i = 0; i < 12; i++) { const a = i / 12 * TAU; ctx.beginPath(); ctx.moveTo(kx + Math.cos(a) * 41, ky + Math.sin(a) * 41); ctx.lineTo(kx + Math.cos(a) * 46, ky + Math.sin(a) * 46); ctx.stroke(); }
        const mh = (t - tMin) * 2.4 - Math.PI / 2, hh = (t - tMin) * .2 - Math.PI / 2 + 1;
        ctx.strokeStyle = '#f4ecff'; ctx.lineWidth = 2; ctx.beginPath(); ctx.moveTo(kx, ky); ctx.lineTo(kx + Math.cos(mh) * 38, ky + Math.sin(mh) * 38); ctx.stroke();
        ctx.lineWidth = 3; ctx.beginPath(); ctx.moveTo(kx, ky); ctx.lineTo(kx + Math.cos(hh) * 24, ky + Math.sin(hh) * 24); ctx.stroke();
        ctx.fillStyle = 'rgba(200,170,255,.25)'; ctx.beginPath(); ctx.moveTo(kx, ky); ctx.arc(kx, ky, 36, -Math.PI / 2, mh); ctx.closePath(); ctx.fill();
        ctx.restore();
        text(ctx, '以分钟计', kx, ky + 82, { size: 26, font: 'song', weight: 500, color: '#efe6ff', alpha: ka, spacing: .2 });
      }
      term(ctx, '药物', 'drugs', 1080, 210, { alpha: pA * smooth(tDrug - .6, tDrug + .3, t), color: '#cdb6ff', size: 36, align: 'left' });
      text(ctx, '挑不出特定的细胞', 1420, 858, { size: 30, font: 'song', weight: 500, color: '#efe6ff', alpha: pA * smooth(tAny, tAny + .8, t), spacing: .15 });
    }
    // —— 梦想中的工具：快 ∩ 准 ——
    const tFast = wt(S, 1, '快如毫秒'), tType = wt(S, 1, '又只作用'), tAns = wt(S, 1, '答案');
    const vA = smooth(c1 - .2, c1 + .8, t) * (1 - smooth(tAns + .1, tAns + .9, t));
    if (vA > 0) {
      const A = [800, 470], B = [1120, 470], R = 220;
      const ga = smooth(tFast - .4, tFast + .4, t), gb = smooth(tType - .4, tType + .4, t);
      term(ctx, '理想的工具', 'the dream tool', W / 2, 185, { alpha: vA, color: ACC, size: 40 });
      ctx.save(); ctx.globalCompositeOperation = 'lighter';
      for (const [c, g, col] of [[A, ga, '#7fd0ff'], [B, gb, '#ffd9a8']]) {
        const rg = ctx.createRadialGradient(c[0], c[1], 0, c[0], c[1], R); rg.addColorStop(0, rgba(col, .0)); rg.addColorStop(.85, rgba(col, .06 * g)); rg.addColorStop(1, rgba(col, .12 * g));
        ctx.fillStyle = rg; ctx.beginPath(); ctx.arc(c[0], c[1], R, 0, TAU); ctx.fill();
        ctx.strokeStyle = rgba(col, .75 * g * vA); ctx.lineWidth = 1.6; ctx.beginPath(); ctx.arc(c[0], c[1], R, -Math.PI / 2, -Math.PI / 2 + TAU * E.out(g)); ctx.stroke();
      }
      ctx.restore();
      // A：毫秒级脉冲
      if (ga > 0) {
        const pts = []; const x0 = 650, x1 = 860, yb = 500;
        for (let x = x0; x <= x1; x += 2) { let y = yb; for (const sx of [690, 740, 790, 840]) { const d = (x - sx) / 5; y -= 78 * Math.exp(-d * d); } pts.push([x, y]); }
        glowLine(ctx, pts.slice(0, Math.max(2, Math.floor(pts.length * ga))), '#7fd0ff', 1.8, vA, '#eaf8ff');
        ctx.save(); ctx.globalAlpha = vA * ga; ctx.strokeStyle = 'rgba(200,235,255,.6)'; ctx.lineWidth = 1.2; ctx.beginPath(); ctx.moveTo(690, 530); ctx.lineTo(740, 530); ctx.moveTo(690, 524); ctx.lineTo(690, 536); ctx.moveTo(740, 524); ctx.lineTo(740, 536); ctx.stroke(); ctx.restore();
        text(ctx, '毫秒', 715, 552, { size: 18, font: 'song', color: '#cfeaff', alpha: vA * ga });
        text(ctx, '快如毫秒', A[0] - 40, 725, { size: 34, font: 'song', weight: 600, color: '#eaf8ff', alpha: vA * ga, spacing: .15 });
        text(ctx, 'MILLISECOND-FAST', A[0] - 40, 765, { size: 15, font: 'latin', weight: 600, color: '#9fd8ff', alpha: vA * ga, spacing: .3 });
      }
      // B：只作用于某一类
      if (gb > 0) {
        const cells = [[1170, 400, 1], [1240, 440, 0], [1200, 500, 1], [1270, 520, 0], [1150, 560, 0], [1235, 590, 1], [1300, 455, 0]];
        cells.forEach(([x, y, k], i) => {
          const ap = smooth(tType - .3 + i * .08, tType + .3 + i * .08, t) * vA;
          if (k) { const lit = smooth(tType + .8, tType + 1.4, t); glow(ctx, x, y, 44, '#ffd9a8', ap * lit * .7); ctx.save(); ctx.globalAlpha = ap; ctx.fillStyle = lit > .5 ? '#fff1dc' : 'rgba(220,210,200,.5)'; ctx.beginPath(); ctx.moveTo(x, y - 15); ctx.lineTo(x + 13, y + 9); ctx.lineTo(x - 13, y + 9); ctx.closePath(); ctx.fill(); ctx.restore(); }
          else { ctx.save(); ctx.globalAlpha = ap * .55; ctx.strokeStyle = '#a8c4cc'; ctx.lineWidth = 1.5; ctx.beginPath(); ctx.arc(x, y, 10, 0, TAU); ctx.stroke(); ctx.restore(); }
        });
        text(ctx, '只作用于某一类神经元', B[0] + 50, 725, { size: 34, font: 'song', weight: 600, color: '#fff3e2', alpha: vA * gb, spacing: .08 });
        text(ctx, 'ONE CELL TYPE ONLY', B[0] + 50, 765, { size: 15, font: 'latin', weight: 600, color: '#ffd9a8', alpha: vA * gb, spacing: .3 });
      }
      // 交集：问号
      const qa = smooth(tType + 1.2, tType + 2, t) * vA;
      if (qa > 0) { glow(ctx, 960, 470, 130, '#ffffff', qa * .25); text(ctx, '?', 960, 470, { size: 84, font: 'latinI', color: '#ffffff', alpha: qa, glow: 24, glowColor: ACC }); }
    }
    // —— 一滴水 → 池水 ——
    const dropT = tAns + .2; const wa = smooth(tAns + .4, tAns + 1.8, t);
    if (t > tAns - .2) {
      if (wa > 0) {
        GLFX.layer(ctx, 'pond', { T: t, C1: '#021a1e', C2: '#0b4446', C3: '#c8fff0', A: 1, S: 7, SUN: 0, SP: GLFX.uv(960, -400) }, { mode: 'source-over', alpha: wa });
        ctx.save(); ctx.globalCompositeOperation = 'lighter';
        for (let k = 0; k < 7; k++) { const tt = t - dropT - .45 - k * .32; if (tt <= 0) continue; const r = tt * (230 - k * 12); const a = Math.exp(-tt * .7) * (1 - k * .11); ctx.strokeStyle = rgba('#cfffee', .45 * a); ctx.lineWidth = 1.6; ctx.beginPath(); ctx.ellipse(960, 600, r, r * .32, 0, 0, TAU); ctx.stroke(); }
        ctx.restore();
      }
      const fu = prog(t, dropT, dropT + .45, E.in);
      if (fu > 0 && fu < 1) { const y = lerp(470, 600, fu); glow(ctx, 960, y, 40, '#dffaff', .8); dot(ctx, 960, y, 6, '#ffffff', 1); }
      const sp = smooth(dropT + .4, dropT + .5, t) * (1 - smooth(dropT + .55, dropT + 1.4, t)); if (sp > 0) glow(ctx, 960, 600, 180, '#cfffee', sp * .7);
    }
  };

  // 5. 池中绿藻
  function flagPts(sd, ph) {
    let base, curl;
    if (ph < .42) { const u = E.inOutSine(ph / .42); base = lerp(.32, 2.7, u); curl = .22 * (1 - u) + .04; }
    else { const u = (ph - .42) / .58; base = lerp(2.7, .32, E.inOutSine(u)); curl = 1.45 * Math.sin(Math.PI * Math.pow(u, .75)); }
    const n = 28, L = 330, ds = L / n; let x = sd * 10, y = -150; const pts = [[x, y]];
    for (let i = 0; i < n; i++) { const s = (i + .5) / n; const th = base + curl * Math.pow(s, 1.25); x += sd * Math.sin(th) * ds; y += -Math.cos(th) * ds; pts.push([x, y]); }
    return pts;
  }
  const ALGA_SPOTS = (() => { const r = rng(808); const a = []; for (let i = 0; i < 70; i++) { const th = r() * TAU, rr = Math.sqrt(r()); a.push([Math.cos(th) * rr * 90, 40 + Math.sin(th) * rr * 100, 2 + r() * 4]); } return a; })();
  function drawAlga(ctx, x, y, ang, s, t, o = {}) {
    const a = o.alpha ?? 1; if (a <= 0) return null;
    ctx.save(); ctx.translate(x, y); ctx.rotate(ang + Math.PI / 2); ctx.scale(s, s); ctx.globalAlpha = a;
    const ph = o.phase ?? (((t * 1.4) % 1) + 1) % 1;
    // 鞭毛
    ctx.globalCompositeOperation = 'lighter'; ctx.lineCap = 'round'; ctx.lineJoin = 'round';
    for (const sd of [-1, 1]) {
      const pts = flagPts(sd, ph); const p = pathOf(pts);
      ctx.strokeStyle = 'rgba(160,255,170,.06)'; ctx.lineWidth = 14; ctx.stroke(p);
      ctx.strokeStyle = 'rgba(190,255,190,.16)'; ctx.lineWidth = 5; ctx.stroke(p);
      for (let k = 0; k < 3; k++) { const seg = pts.slice(k * 9, k * 9 + 11); ctx.strokeStyle = `rgba(230,255,225,${.85 - k * .2})`; ctx.lineWidth = 3.4 - k * .9; ctx.stroke(pathOf(seg)); }
    }
    ctx.globalCompositeOperation = 'source-over';
    const rx = 112, ry = 150;
    // 外层光晕
    const hg = ctx.createRadialGradient(0, 0, ry * .8, 0, 0, ry * 1.35); hg.addColorStop(0, 'rgba(126,217,87,.07)'); hg.addColorStop(1, 'rgba(126,217,87,0)');
    ctx.fillStyle = hg; ctx.beginPath(); ctx.ellipse(0, 0, rx * 1.35, ry * 1.3, 0, 0, TAU); ctx.fill();
    // 细胞质
    ctx.beginPath(); ctx.ellipse(0, 0, rx, ry, 0, 0, TAU);
    const cg = ctx.createRadialGradient(-30, -50, 10, 0, 10, ry * 1.1); cg.addColorStop(0, 'rgba(150,186,138,.82)'); cg.addColorStop(.6, 'rgba(92,140,82,.86)'); cg.addColorStop(1, 'rgba(32,78,40,.92)');
    ctx.fillStyle = cg; ctx.fill();
    ctx.save(); ctx.beginPath(); ctx.ellipse(0, 0, rx - 3, ry - 3, 0, 0, TAU); ctx.clip();
    // 杯状叶绿体
    ctx.beginPath(); ctx.ellipse(0, 26, rx - 6, ry - 18, 0, 0, TAU); ctx.ellipse(0, -46, 64, 86, 0, 0, TAU, true);
    const pg = ctx.createRadialGradient(0, 60, 10, 0, 30, ry); pg.addColorStop(0, 'rgba(84,150,58,.96)'); pg.addColorStop(.7, 'rgba(46,108,40,.96)'); pg.addColorStop(1, 'rgba(20,62,28,.97)');
    ctx.fillStyle = pg; ctx.fill('evenodd');
    ctx.strokeStyle = 'rgba(170,230,140,.2)'; ctx.lineWidth = 1.4;
    for (let k = 0; k < 6; k++) { ctx.beginPath(); ctx.ellipse(0, 26, rx - 14 - k * 8, ry - 26 - k * 8, 0, .15 * Math.PI, .85 * Math.PI); ctx.stroke(); }
    for (const [sx, sy, sr] of ALGA_SPOTS) { ctx.fillStyle = 'rgba(160,220,130,.16)'; ctx.beginPath(); ctx.arc(sx, sy, sr, 0, TAU); ctx.fill(); }
    // 蛋白核
    ctx.fillStyle = 'rgba(160,184,142,.78)'; ctx.beginPath(); ctx.arc(0, 82, 26, 0, TAU); ctx.fill();
    ctx.strokeStyle = 'rgba(214,232,196,.55)'; ctx.lineWidth = 3; for (let k = 0; k < 6; k++) { ctx.beginPath(); ctx.arc(0, 82, 31, k / 6 * TAU + .1, (k + 1) / 6 * TAU - .1); ctx.stroke(); }
    // 细胞核
    ctx.fillStyle = 'rgba(110,150,146,.5)'; ctx.beginPath(); ctx.arc(0, -40, 30, 0, TAU); ctx.fill(); ctx.strokeStyle = 'rgba(210,235,228,.5)'; ctx.lineWidth = 1.5; ctx.stroke();
    ctx.fillStyle = 'rgba(120,150,150,.6)'; ctx.beginPath(); ctx.arc(4, -38, 9, 0, TAU); ctx.fill();
    // 伸缩泡
    for (const sd of [-1, 1]) { ctx.fillStyle = 'rgba(190,225,225,.5)'; ctx.beginPath(); ctx.arc(sd * 22, -120, 9, 0, TAU); ctx.fill(); }
    ctx.restore();
    // 细胞壁
    ctx.strokeStyle = 'rgba(215,240,205,.55)'; ctx.lineWidth = 2; ctx.beginPath(); ctx.ellipse(0, 0, rx, ry, 0, 0, TAU); ctx.stroke();
    ctx.strokeStyle = 'rgba(235,255,225,.15)'; ctx.lineWidth = 8; ctx.stroke();
    ctx.fillStyle = 'rgba(235,255,225,.6)'; ctx.beginPath(); ctx.ellipse(0, -ry, 12, 6, 0, 0, TAU); ctx.fill();
    // 眼点
    const ex = rx - 16, ey = -18;
    ctx.save(); ctx.translate(ex, ey); ctx.rotate(.12);
    const eg = ctx.createRadialGradient(-3, -6, 1, 0, 0, 22); eg.addColorStop(0, '#ffb070'); eg.addColorStop(.5, '#ff5a2a'); eg.addColorStop(1, '#b0241a');
    ctx.fillStyle = eg; ctx.beginPath(); ctx.ellipse(0, 0, 9, 21, 0, 0, TAU); ctx.fill(); ctx.restore();
    ctx.restore();
    const ep = L2S(x, y, s, ang + Math.PI / 2, ex, ey);
    glow(ctx, ep[0], ep[1], 46 * s, EYE, a * .55); glow(ctx, ep[0], ep[1], 12 * s, '#ffc090', a * .5);
    return { eye: ep, fb: L2S(x, y, s, ang + Math.PI / 2, 0, -175) };
  }
  // 分子视角：膜 + 感光蛋白 + 眼点颗粒
  const GRAN = (() => { const r = rng(919); const a = []; for (let row = 0; row < 3; row++) for (let i = 0; i < 30; i++) a.push({ x: 180 + i * 54 + (row % 2) * 27 + (r() - .5) * 6, y: 700 + row * 44, r: 17 + r() * 5 }); return a; })();
  scenes.alga = (ctx, S) => {
    const t = S.t, c1 = S.cue(1);
    const tz0 = c1 + .1, tz1 = wt(S, 1, '有一种') + .55, tRet = wt(S, 1, '内含视黄醛'), tEye = wt(S, 1, '正是');
    const zu = prog(t, tz0, tz1, x => x); const mol = smooth(tz1 - .3, tz1 + .08, t);
    const SP = GLFX.uv(1560, -80);
    if (mol < 1) {
      ctx.save();
      GLFX.layer(ctx, 'pond', { T: t + 4, C1: '#021411', C2: '#0b4036', C3: '#c8ffd8', A: 1, S: 6, SUN: .85, SP }, { mode: 'source-over' });
      // 光柱（画布层，增强方向感）
      ctx.save(); ctx.globalCompositeOperation = 'lighter';
      for (let k = 0; k < 3; k++) { const g = ctx.createLinearGradient(1560, -80, 980 - k * 160, 1080); g.addColorStop(0, `rgba(220,255,225,${.08 - k * .02})`); g.addColorStop(1, 'rgba(220,255,225,0)'); ctx.fillStyle = g; ctx.beginPath(); ctx.moveTo(1500 + k * 30, -80); ctx.lineTo(1640 + k * 30, -80); ctx.lineTo(1260 - k * 170, 1080); ctx.lineTo(880 - k * 170, 1080); ctx.closePath(); ctx.fill(); }
      ctx.restore();
      motes(ctx, t + 9, .7, '#c8ffd0');
      // 游向光
      const sw = E.out(prog(t, -.5, c1 + .2, x => x));
      const ph = (((t * 1.4) % 1) + 1) % 1; const surge = 8 * Math.sin(TAU * (t * 1.4 - .15));
      const px = lerp(400, 880, sw), py = lerp(720, 520, sw); const ang = -.62 + .05 * Math.sin(t * .9);
      const Z = Math.exp(Math.log(48) * zu * zu * (1.4 - .4 * zu));
      // 以眼点为中心推进
      const pre = drawAlgaPos(px, py, ang, surge);
      const ex = pre.eye[0], ey = pre.eye[1];
      if (zu > 0) { const k = E.inOut(clamp(zu * 1.3)); ctx.translate(lerp(ex, W / 2, k), lerp(ey, H / 2, k)); ctx.scale(Z, Z); ctx.translate(-ex, -ey); }
      const al = drawAlga(ctx, pre.x, pre.y, ang, .95, t, { phase: ph });
      // 眼点内的类胡萝卜素颗粒层（放大时浮现）
      if (zu > .2 && al) { const ga = smooth(.25, .6, zu); for (let r0 = 0; r0 < 3; r0++) for (let i = -3; i <= 3; i++) { const q = L2S(al.eye[0], al.eye[1], .95, ang + Math.PI / 2 + .12, (r0 - 1) * 5, i * 5.5); dot(ctx, q[0], q[1], 1.9, '#ff9a5a', ga * .9); } }
      ctx.restore();
      if (zu > .4) { const ia = smooth(.4, 1, zu); const rg = ctx.createRadialGradient(W / 2, H / 2, 0, W / 2, H / 2, 900); rg.addColorStop(0, `rgba(150,40,18,${.75 * ia})`); rg.addColorStop(1, `rgba(40,8,6,${.9 * ia})`); ctx.fillStyle = rg; ctx.fillRect(0, 0, W, H); }
      // 标签（不随推进缩放）
      const la = 1 - smooth(tz0, tz0 + .5, t);
      if (al) {
        term(ctx, '莱茵衣藻', 'Chlamydomonas reinhardtii', 1330, 690, { alpha: smooth(.8, 1.8, t) * la, color: '#bff5a0', size: 44 });
        text(ctx, '单细胞绿藻 · 两根鞭毛 · 趋光', 1330, 800, { size: 26, font: 'song', color: '#d8f2cf', alpha: smooth(1.8, 2.8, t) * la, spacing: .12 });
        label(ctx, '鞭毛', al.fb[0], al.fb[1], { alpha: smooth(wt(S, 0, '挥动'), wt(S, 0, '挥动') + .8, t) * la, dx: -120, dy: -70, size: 26, en: 'flagella', color: '#e2ffd8' });
        const ea = smooth(c1 - .6, c1 + .2, t) * (1 - smooth(tz0 + .3, tz0 + .8, t));
        label(ctx, '眼点', al.eye[0], al.eye[1], { alpha: ea, dx: 110, dy: 90, size: 28, en: 'eyespot', color: '#ffd2b8' });
      }
    }
    if (mol > 0) {
      ctx.save(); ctx.globalAlpha = mol;
      const g = ctx.createLinearGradient(0, 0, 0, H); g.addColorStop(0, '#0a2a26'); g.addColorStop(.55, '#06171a'); g.addColorStop(1, '#120a08'); ctx.fillStyle = g; ctx.fillRect(0, 0, W, H);
      ctx.restore();
      const k = E.out(prog(t, tz1 - .3, tz1 + 2.4, x => x)); const sc = lerp(2.2, 1, k);
      ctx.save(); ctx.globalAlpha = mol; ctx.translate(W / 2, 490); ctx.scale(sc, sc); ctx.translate(-W / 2, -490);
      // 自上方射入的光
      ctx.save(); ctx.globalCompositeOperation = 'lighter'; const lg = ctx.createLinearGradient(0, 0, 0, 420); lg.addColorStop(0, 'rgba(190,255,215,.12)'); lg.addColorStop(1, 'rgba(190,255,215,0)'); ctx.fillStyle = lg; ctx.fillRect(0, 0, W, 420); ctx.restore();
      motes(ctx, t, .5, '#c8ffd0');
      const yf = x => 490 + (x - 960) * (x - 960) / 14000;
      // 眼点颗粒
      for (const q of GRAN) { const yy = q.y + (yf(q.x) - 470); const ef = 1 - smooth(560, 900, Math.abs(q.x - 960)); if (ef <= .02) continue; const gr = ctx.createRadialGradient(q.x - q.r * .35, yy - q.r * .4, 1, q.x, yy, q.r); gr.addColorStop(0, '#e8a070'); gr.addColorStop(.5, '#b8441f'); gr.addColorStop(1, '#3a0e0a'); ctx.globalAlpha = mol * ef * .9; ctx.fillStyle = gr; ctx.beginPath(); ctx.arc(q.x, yy, q.r, 0, TAU); ctx.fill(); } ctx.globalAlpha = mol;
      
      bilayer(ctx, 80, 1840, { yf, half: 60, t, skip: x => Math.abs(x - 960) < 140 });
      const re = smooth(tRet - .2, tRet + .5, t) * (1 - .5 * smooth(tRet + 1.5, tRet + 3, t));
      rhodo(ctx, 960, 490, 1.18, { ex: 0, retA: .6 + .4 * smooth(tRet - .3, tRet + .3, t) });
      if (re > 0) { glow(ctx, 969, 481, 150, AMB, re * .4); glow(ctx, 969, 481, 50, '#fff0c8', re * .5); }
      ctx.restore();
      const lo = 1 - smooth(S.d - 1.5, S.d - .8, t); const la = mol * smooth(tz1 + .3, tz1 + 1.1, t) * lo;
      label(ctx, '感光蛋白', 880, 346, { alpha: la, dx: -150, dy: -100, size: 30, en: 'light-sensitive protein' });
      label(ctx, '视黄醛', 922, 481, { alpha: mol * lo * smooth(tRet - .1, tRet + .7, t), dx: -260, dy: -150, size: 34, en: 'retinal', color: '#ffe2a8', lineColor: 'rgba(255,220,160,.8)' });
      label(ctx, '眼点', 410, 764, { alpha: la * .95, dx: -110, dy: 100, size: 26, en: 'eyespot', color: '#ffd2b8' });
      label(ctx, '细胞膜', 420, yf(420) - 60, { alpha: la * .9, dx: -90, dy: -110, size: 26, en: 'cell membrane', color: '#f2d6c8' });
      // 人眼：同一种分子
      const ea = mol * lo * smooth(tEye - .2, tEye + .8, t);
      if (ea > 0) {
        const ex = 1560, ey = 235; const ew = 110;
        ctx.save(); ctx.globalAlpha = ea; shade(ctx, ex, ey, 300, 190, .6);
        ctx.strokeStyle = '#f4ead8'; ctx.lineWidth = 2; ctx.beginPath(); ctx.moveTo(ex - ew, ey); ctx.quadraticCurveTo(ex, ey - 78, ex + ew, ey); ctx.quadraticCurveTo(ex, ey + 78, ex - ew, ey); ctx.stroke();
        ctx.strokeStyle = 'rgba(255,214,140,.85)'; ctx.beginPath(); ctx.arc(ex, ey, 34, 0, TAU); ctx.stroke(); ctx.fillStyle = '#05080a'; ctx.beginPath(); ctx.arc(ex, ey, 15, 0, TAU); ctx.fill();
        ctx.restore(); glow(ctx, ex, ey, 70, AMB, ea * .35);
        const arc = KIT.arcPts(1000, 472, ex - 120, ey + 10, -.22, 50); const pu = prog(t, tEye, tEye + 1.2, E.inOut);
        ctx.save(); ctx.globalAlpha = ea * .8; ctx.setLineDash([3, 7]); ctx.strokeStyle = '#ffd9a0'; ctx.lineWidth = 1.4; ctx.beginPath(); arc.slice(0, Math.max(2, Math.floor(arc.length * pu))).forEach((p, i) => i ? ctx.lineTo(p[0], p[1]) : ctx.moveTo(p[0], p[1])); ctx.stroke(); ctx.restore();
        text(ctx, '我们的眼睛', ex, ey - 92, { size: 26, font: 'song', weight: 500, color: '#efe6d6', alpha: ea, spacing: .25 });
        text(ctx, '同一种分子：视黄醛', ex, ey + 96, { size: 30, font: 'song', weight: 600, color: '#ffdca0', alpha: ea * smooth(tEye + .8, tEye + 1.6, t), spacing: .1, glow: 10, glowColor: AMB });
      }
    }
  };
  function drawAlgaPos(px, py, ang, surge) { const x = px + Math.cos(ang) * surge, y = py + Math.sin(ang) * surge; const ep = L2S(x, y, .95, ang + Math.PI / 2, 112 - 16, -18); return { x, y, eye: ep }; }

  // 6. 光门控通道
  const FLOW = (() => { const r = rng(616); const kinds = ['Na', 'Na', 'Na', 'H', 'H', 'K', 'K', 'Ca']; const a = []; for (let i = 0; i < 64; i++) a.push({ k: kinds[Math.floor(r() * kinds.length)], x0: 640 + r() * 640, y0: 200 + r() * 140, x1: 620 + r() * 680, y1: 710 + r() * 130, ph: r(), w: (r() - .5) * 2 }); return a; })();
  scenes.channel = (ctx, S) => {
    const t = S.t, c1 = S.cue(1);
    const tBlue = wt(S, 0, '一遇蓝光'), tOpenC = wt(S, 0, '自身便打开'), tFlow = wt(S, 0, '让正离子'), tSw = wt(S, 0, '光的开关'), tSame = wt(S, 0, '竟是');
    const tName = c1, tEgg = wt(S, 1, '在蛙卵'), tFast = wt(S, 1, '它在0.2');
    deep(ctx, t + 70, { c1: '#0a2228', neb: .12, seed: 4, motes: .4 });
    const eggA = smooth(tEgg - .25, tEgg + .5, t);
    const pA = 1 - smooth(tEgg - .7, tEgg - .15, t);
    const hit = tBlue + 1.0;
    if (pA > 0) {
      const sc = 1.25, cx = 960, cy = 505;
      ctx.save(); ctx.globalAlpha = pA;
      const yf = () => cy;
      const tg = ctx.createLinearGradient(0, 0, 0, cy - 72); tg.addColorStop(0, 'rgba(40,80,140,.16)'); tg.addColorStop(1, 'rgba(40,80,140,0)'); ctx.fillStyle = tg; ctx.fillRect(0, 0, W, cy - 72);
      const bgr = ctx.createLinearGradient(0, cy + 72, 0, H); bgr.addColorStop(0, 'rgba(20,60,60,0)'); bgr.addColorStop(1, 'rgba(20,60,60,.18)'); ctx.fillStyle = bgr; ctx.fillRect(0, cy + 72, W, H - cy - 72);
      for (let i = 0; i < 46; i++) { const up = i % 2 === 0; const bx = (hash(i, 501) * 2100 - 90 + t * 6 * (hash(i, 502) - .5)), by = up ? 150 + hash(i, 503) * 260 : cy + 110 + hash(i, 503) * 260; const kk = ['Na', 'K', 'Na', 'Ca', 'H'][i % 5]; ion(ctx, bx + 10 * noise3(i, t * .3, 1), by + 8 * noise3(i, t * .3, 3), kk, .28, .95); }
      bilayer(ctx, 60, 1860, { yf, half: 72, sp: 17, hr: 8, t, skip: x => Math.abs(x - cx) < 128 + 20 * smooth(tOpenC, tOpenC + .8, t) });
      const open = smooth(tOpenC - .2, tOpenC + .8, t), bend = smooth(hit, hit + .5, t), ex = smooth(hit - .05, hit + .05, t) * (1 - smooth(hit + .4, hit + 1.6, t)) + .25 * open;
      rhodo(ctx, cx, cy, sc, { open, bend, ex: clamp(ex) });
      ctx.restore();
      // 蓝光光子
      const pu = prog(t, tBlue - .1, hit, x => x);
      if (pu > 0 && t < hit + .35) {
        const x0 = 230, y0 = 130, x1 = cx - 4, y1 = cy - 14; const dx = x1 - x0, dy = y1 - y0, L = Math.hypot(dx, dy), ux = dx / L, uy = dy / L; const hs = Math.min(1, pu) * L;
        const pts = []; for (let k = 0; k <= 120; k++) { const s = hs - 300 + k * 300 / 120; if (s < 0) continue; const en = Math.exp(-Math.pow((s - hs + 110) / 85, 2)); const w = Math.sin((s - t * 260) / 28 * TAU) * 20 * en; pts.push([x0 + ux * s - uy * w, y0 + uy * s + ux * w]); }
        glowLine(ctx, pts, BLUE2, 2.4, pA * (1 - smooth(hit - .05, hit + .3, t)), '#e4f0ff');
        const hp = [x0 + ux * hs, y0 + uy * hs]; glow(ctx, hp[0], hp[1], 60, BLUE, .5 * pA * (1 - smooth(hit - .05, hit + .2, t)));
        label(ctx, '蓝光 · 约 470 纳米', 420, 224, { alpha: pA * smooth(tBlue, tBlue + .6, t) * (1 - smooth(hit + 1, hit + 2, t)), dx: 110, dy: -70, size: 28, en: 'blue light', color: '#cfe0ff', lineColor: 'rgba(160,200,255,.8)' });
      }
      const fl = smooth(hit - .05, hit + .05, t) * (1 - smooth(hit + .1, hit + 1.2, t)); if (fl > 0) { glow(ctx, cx, cy - 14, 320, BLUE2, fl * .6 * pA); glow(ctx, cx, cy - 14, 60, '#ffffff', fl * pA); }
      // 阳离子流
      const fa = smooth(tFlow - .6, tFlow + .3, t) * pA;
      if (fa > 0) for (let i = 0; i < FLOW.length; i++) {
        const f = FLOW[i]; const u = (((t - tFlow) * .32 + f.ph) % 1 + 1) % 1; let x, y;
        const top = cy - 170, bot = cy + 170;
        if (u < .5) { const k = E.in(u / .5); x = lerp(f.x0, cx + f.w * 6, k); y = lerp(f.y0, top, k); }
        else if (u < .62) { const k = (u - .5) / .12; x = cx + f.w * 6; y = lerp(top, bot, k); }
        else { const k = E.out((u - .62) / .38); x = lerp(cx + f.w * 6, f.x1, k); y = lerp(bot, f.y1, k); }
        const appear = (t - tFlow) * .32 + f.ph < 1 && u < f.ph ? 0 : 1;
        const lab = i < 4 && smooth(tFlow + .4, tFlow + 1.2, t) > 0;
        ion(ctx, x, y, f.k, fa * (1 - smooth(.92, 1, u)) * appear, 1.25, lab);
      }
      // 图例
      const lga = smooth(tFlow + .5, tFlow + 1.4, t) * pA;
      if (lga > 0) { let lx = 1440; text(ctx, '正离子', 1430, 835, { size: 24, font: 'song', weight: 500, align: 'right', color: '#efe6da', alpha: lga, spacing: .2 }); for (const k of ['Na', 'H', 'K', 'Ca']) { ion(ctx, lx + 10, 835, k, lga, .85); text(ctx, IONS[k].s, lx + 28, 835, { size: 22, font: 'song', align: 'left', color: IONS[k].c, alpha: lga }); lx += k === 'Ca' ? 0 : 96; } }
      text(ctx, '细胞外', 120, 300, { size: 24, font: 'song', weight: 500, align: 'left', color: '#e6dccd', alpha: pA * .85, spacing: .25 });
      text(ctx, '细胞内', 120, 760, { size: 24, font: 'song', weight: 500, align: 'left', color: '#e6dccd', alpha: pA * .85, spacing: .25 });
      // 光的开关 = 离子的闸门
      const sA = smooth(tSw - .2, tSw + .6, t) * (1 - smooth(tSame + .4, tSame + 1.1, t)) * pA;
      label(ctx, '光的开关', cx - 40, cy - 14, { alpha: sA, dx: -330, dy: -170, size: 32, color: '#dce8ff', lineColor: 'rgba(170,200,255,.85)' });
      label(ctx, '离子的闸门', cx + 4, cy + 150, { alpha: smooth(tSw + .5, tSw + 1.2, t) * (1 - smooth(tSame + .4, tSame + 1.1, t)) * pA, dx: 300, dy: 120, size: 32, color: '#dce8ff', lineColor: 'rgba(170,200,255,.85)' });
      const same = smooth(tSame - .2, tSame + .7, t) * (1 - smooth(tName - .6, tName + .2, t)) * pA;
      if (same > 0) {
        ctx.save(); ctx.globalCompositeOperation = 'lighter'; ctx.setLineDash([4, 9]); ctx.lineDashOffset = -t * 20; ctx.strokeStyle = rgba(ACC, .7 * same); ctx.lineWidth = 1.5; ctx.beginPath(); ctx.ellipse(cx, cy, 200 * (.9 + .1 * E.out(same)), 210, 0, 0, TAU); ctx.stroke(); ctx.restore();
        shade(ctx, cx, 215, 520, 100, .8 * same); text(ctx, '光的开关 ＝ 离子的闸门', cx, 195, { size: 44, font: 'song', weight: 600, color: '#ffffff', alpha: same, spacing: .12, glow: 18, glowColor: ACC });
        text(ctx, '竟是同一个分子', cx, 258, { size: 26, font: 'song', weight: 500, color: '#bfe4ff', alpha: same * smooth(tSame + .5, tSame + 1.2, t), spacing: .35 });
      }
      // 命名
      const na = smooth(tName + .2, tName + 1.1, t) * pA;
      if (na > 0) shade(ctx, cx, 215, 520, 110, .55 * na);
    }
    // —— 蛙卵细胞 ——
    if (eggA > 0) {
      const ox = 600, oy = 540, R = 225; const lit = smooth(tFast - .3, tFast + .1, t);
      ctx.save(); ctx.globalAlpha = eggA;
      // 光锥
      ctx.save(); ctx.globalCompositeOperation = 'lighter'; for (let k = 0; k < 6; k++) { const wk = .35 + k * .14; const lg = ctx.createLinearGradient(0, 110, 0, oy + R * .5); lg.addColorStop(0, rgba(BLUE2, .12 * lit)); lg.addColorStop(1, rgba(BLUE2, 0)); ctx.fillStyle = lg; ctx.beginPath(); ctx.moveTo(ox - 14, 110); ctx.lineTo(ox + 14, 110); ctx.lineTo(ox + R * 1.2 * wk, oy + R * .5); ctx.lineTo(ox - R * 1.2 * wk, oy + R * .5); ctx.closePath(); ctx.fill(); } ctx.restore();
      glow(ctx, ox, 110, 40, BLUE2, lit * .9);
      // 卵
      const og = ctx.createLinearGradient(0, oy - R, 0, oy + R); og.addColorStop(0, '#2e1a13'); og.addColorStop(.42, '#4e2e20'); og.addColorStop(.55, '#a88e68'); og.addColorStop(1, '#c9b791');
      ctx.fillStyle = og; ctx.beginPath(); ctx.arc(ox, oy, R, 0, TAU); ctx.fill();
      const sh = ctx.createRadialGradient(ox - R * .4, oy - R * .45, R * .05, ox, oy, R * 1.02); sh.addColorStop(0, 'rgba(255,255,255,.2)'); sh.addColorStop(.35, 'rgba(255,255,255,0)'); sh.addColorStop(.85, 'rgba(0,0,0,.15)'); sh.addColorStop(1, 'rgba(0,0,0,.55)');
      ctx.fillStyle = sh; ctx.beginPath(); ctx.arc(ox, oy, R, 0, TAU); ctx.fill();
      ctx.strokeStyle = 'rgba(255,240,220,.35)'; ctx.lineWidth = 1.5; ctx.beginPath(); ctx.arc(ox, oy, R, 0, TAU); ctx.stroke();
      ctx.restore();
      // 膜上通道受光闪烁
      if (lit > 0) { ctx.save(); ctx.globalCompositeOperation = 'lighter'; for (let i = 0; i < 70; i++) { const a = -Math.PI * (.08 + .84 * hash(i, 31)); const rr = R * (.985); const x = ox + Math.cos(a) * rr, y = oy + Math.sin(a) * rr; const tw = .5 + .5 * Math.sin(t * 8 + i); glow(ctx, x, y, 10, BLUE2, lit * eggA * tw * .8); } ctx.restore(); glow(ctx, ox, oy - R * .6, 260, BLUE, lit * eggA * .18); }
      // 两根微电极
      for (const [x0, y0, x1, y1] of [[230, 190, ox - 80, oy - R + 52], [790, 150, ox + 74, oy - R + 40]]) {
        const ang = Math.atan2(y1 - y0, x1 - x0), Lp = Math.hypot(x1 - x0, y1 - y0);
        ctx.save(); ctx.globalAlpha = eggA * .9; ctx.translate(x0, y0); ctx.rotate(ang);
        const gg = ctx.createLinearGradient(0, -10, 0, 10); gg.addColorStop(0, 'rgba(220,240,255,.6)'); gg.addColorStop(.5, 'rgba(150,190,220,.12)'); gg.addColorStop(1, 'rgba(220,240,255,.6)');
        ctx.fillStyle = gg; ctx.beginPath(); ctx.moveTo(0, -10); ctx.lineTo(Lp * .55, -8); ctx.lineTo(Lp, -1); ctx.lineTo(Lp, 1); ctx.lineTo(Lp * .55, 8); ctx.lineTo(0, 10); ctx.closePath(); ctx.fill();
        ctx.strokeStyle = 'rgba(240,250,255,.5)'; ctx.lineWidth = 1; ctx.stroke(); ctx.restore();
      }
      label(ctx, '蛙卵细胞', ox - R * .72, oy + R * .7, { alpha: eggA * smooth(tEgg, tEgg + .8, t), dx: -60, dy: 110, size: 28, en: 'Xenopus oocyte' });
      // 秒表
      const sx = 1360, sy = 520, sr = 160; const sa = eggA * smooth(tEgg + .2, tEgg + 1, t);
      if (sa > 0) {
        ctx.save(); ctx.globalAlpha = sa; ctx.strokeStyle = 'rgba(200,225,255,.5)'; ctx.lineWidth = 1.4; ctx.beginPath(); ctx.arc(sx, sy, sr, 0, TAU); ctx.stroke();
        for (let i = 0; i < 50; i++) { const a = -Math.PI / 2 + i / 50 * TAU; const L = i % 5 === 0 ? 14 : 6; ctx.lineWidth = i % 5 === 0 ? 1.6 : 1; ctx.strokeStyle = i % 5 === 0 ? 'rgba(220,235,255,.8)' : 'rgba(200,225,255,.4)'; ctx.beginPath(); ctx.moveTo(sx + Math.cos(a) * (sr - 6), sy + Math.sin(a) * (sr - 6)); ctx.lineTo(sx + Math.cos(a) * (sr - 6 - L), sy + Math.sin(a) * (sr - 6 - L)); ctx.stroke(); }
        ctx.fillStyle = 'rgba(220,235,255,.8)'; ctx.fillRect(sx - 14, sy - sr - 24, 28, 14); ctx.restore();
        const su = prog(t, tFast, tFast + 1.6, E.inOut) * .2;
        ctx.save(); ctx.globalCompositeOperation = 'lighter'; ctx.strokeStyle = rgba(BLUE2, .95 * sa); ctx.lineWidth = 8; ctx.lineCap = 'round'; ctx.beginPath(); ctx.arc(sx, sy, sr - 30, -Math.PI / 2, -Math.PI / 2 + TAU * su); ctx.stroke(); ctx.lineWidth = 22; ctx.strokeStyle = rgba(BLUE, .2 * sa); ctx.stroke(); ctx.restore();
        const ha = -Math.PI / 2 + TAU * su; glow(ctx, sx + Math.cos(ha) * (sr - 30), sy + Math.sin(ha) * (sr - 30), 30, '#dfeaff', sa * smooth(tFast, tFast + .2, t));
        text(ctx, su.toFixed(1), sx, sy - 6, { size: 104, font: 'song', weight: 300, color: '#ffffff', alpha: sa, glow: 18, glowColor: BLUE2 });
        text(ctx, '毫秒', sx, sy + 70, { size: 30, font: 'song', weight: 500, color: '#d8e6ff', alpha: sa, spacing: .3 });
        text(ctx, '通道开启', sx, sy + sr + 50, { size: 28, font: 'song', weight: 500, color: '#e6eeff', alpha: sa * smooth(tFast + 1.2, tFast + 2, t), spacing: .3 });
      }
    }
    term(ctx, '通道视紫红质', 'channelrhodopsin', W / 2, 215, { alpha: smooth(tName + .2, tName + 1.1, t), color: ACC, size: 50, glow: 14 });
  };

  // 7. 光遗传学
  const ICO = (() => { const p = (1 + Math.sqrt(5)) / 2; const v = [[-1, p, 0], [1, p, 0], [-1, -p, 0], [1, -p, 0], [0, -1, p], [0, 1, p], [0, -1, -p], [0, 1, -p], [p, 0, -1], [p, 0, 1], [-p, 0, -1], [-p, 0, 1]].map(q => { const n = Math.hypot(...q); return q.map(c => c / n); }); const f = []; for (let i = 0; i < 12; i++) for (let j = i + 1; j < 12; j++) for (let k = j + 1; k < 12; k++) { const d = (a, b) => Math.hypot(v[a][0] - v[b][0], v[a][1] - v[b][1], v[a][2] - v[b][2]); if (d(i, j) < 1.1 && d(j, k) < 1.1 && d(i, k) < 1.1) f.push([i, j, k]); } return { v, f }; })();
  function virus(ctx, x, y, R, rotA, rotB, a) {
    if (a <= 0) return; const cA = Math.cos(rotA), sA = Math.sin(rotA), cB = Math.cos(rotB), sB = Math.sin(rotB);
    const P = ICO.v.map(([X, Y, Z]) => { let x1 = X * cA - Z * sA, z1 = X * sA + Z * cA; let y1 = Y * cB - z1 * sB, z2 = Y * sB + z1 * cB; return [x + x1 * R, y + y1 * R, z2]; });
    const faces = ICO.f.map(f => ({ f, z: (P[f[0]][2] + P[f[1]][2] + P[f[2]][2]) / 3 })).sort((p, q) => p.z - q.z);
    glow(ctx, x, y, R * 2.6, VIO, a * .25);
    ctx.save(); ctx.lineJoin = 'round';
    for (const { f, z } of faces) {
      const [A, B, C] = f.map(i => P[i]); const nz = ((B[0] - A[0]) * (C[1] - A[1]) - (B[1] - A[1]) * (C[0] - A[0]));
      const front = z > 0; const lum = .35 + .65 * clamp((-(A[1] + B[1] + C[1]) / 3 + y) / R * .5 + .5);
      ctx.globalAlpha = a * (front ? .55 : .2); ctx.fillStyle = rgba(mix('#4a2f8a', '#e4d4ff', lum), 1);
      ctx.beginPath(); ctx.moveTo(A[0], A[1]); ctx.lineTo(B[0], B[1]); ctx.lineTo(C[0], C[1]); ctx.closePath(); ctx.fill();
      ctx.globalAlpha = a * (front ? .85 : .25); ctx.strokeStyle = '#efe6ff'; ctx.lineWidth = 1.3; ctx.stroke();
    }
    ctx.restore();
    for (const p of P) if (p[2] > -.2) { glow(ctx, p[0], p[1], 10, '#f1e8ff', a * .7); }
  }
  function dnaPts(x0, y0, x1, y1, amp, wl, ph, n = 80) { const A = [], B = []; for (let k = 0; k <= n; k++) { const u = k / n; const x = lerp(x0, x1, u), y = lerp(y0, y1, u); const s = u * Math.hypot(x1 - x0, y1 - y0) / wl * TAU + ph; A.push([x, y + Math.sin(s) * amp, Math.cos(s)]); B.push([x, y + Math.sin(s + Math.PI) * amp, Math.cos(s + Math.PI)]); } return [A, B]; }
  function dna(ctx, x0, y0, x1, y1, o) {
    const a = o.alpha ?? 1; if (a <= 0) return; const [A, B] = dnaPts(x0, y0, x1, y1, o.amp || 14, o.wl || 60, o.ph || 0, o.n || 80);
    ctx.save(); ctx.globalCompositeOperation = 'lighter'; ctx.lineCap = 'round';
    for (let k = 0; k < A.length; k += 2) { const col = o.colAt ? o.colAt(k / (A.length - 1)) : o.col; ctx.strokeStyle = rgba(col, .35 * a); ctx.lineWidth = 1.4; ctx.beginPath(); ctx.moveTo(A[k][0], A[k][1]); ctx.lineTo(B[k][0], B[k][1]); ctx.stroke(); }
    for (const S2 of [A, B]) for (let k = 0; k < S2.length - 1; k++) { const col = o.colAt ? o.colAt(k / (S2.length - 1)) : o.col; const dep = .45 + .55 * (S2[k][2] * .5 + .5); ctx.strokeStyle = rgba(col, a * dep); ctx.lineWidth = 2.6 * (.6 + .4 * dep); ctx.beginPath(); ctx.moveTo(S2[k][0], S2[k][1]); ctx.lineTo(S2[k + 1][0], S2[k + 1][1]); ctx.stroke(); }
    ctx.restore();
  }
  const FLASH = [.07, .17, .27, .37, .5, .545, .59, .64, .73, .765, .8, .87, .895, .92];
  const TIS = (() => { const r = rng(733); const a = []; let g = 0; while (a.length < 34 && g++ < 5000) { const x = 230 + r() * 1460, y = 430 + r() * 400; if (a.some(q => Math.hypot(q.x - x, q.y - y) < 120)) continue; const type = a.length % 3; a.push({ x, y, type, rot: type === 0 ? -Math.PI / 2 + (r() - .5) * .5 + Math.PI / 2 : r() * TAU, s: .34 + r() * .1, tpl: type === 0 ? Math.floor(r() * 6) : type === 1 ? 6 + Math.floor(r() * 5) : 11 + Math.floor(r() * 2), ph: r() * 3 }); } return a; })();
  scenes.switch = (ctx, S) => {
    const t = S.t, c1 = S.cue(1), c2 = S.cue(2);
    deep(ctx, t + 90, { neb: .14, seed: 5, motes: .5 });
    const tVir = wt(S, 0, '借助病毒'), tGene = wt(S, 0, '把这种'), tSend = wt(S, 0, '送进');
    // —— A：病毒送入基因 ——
    const aA = 1 - smooth(c1 - .5, c1 + .3, t);
    if (aA > 0) {
      const nx = 1230, ny = 470, ns = 1.0;
      const expr = prog(t, tSend - .2, tSend + 2.2, x => x);
      drawNeuron(ctx, HERO, nx, ny, ns, 0, { alpha: aA * .55, core: '#c8dce2', halo: '#4b8f9e' });
      if (expr > 0) { ctx.save(); ctx.beginPath(); ctx.arc(nx, ny, 40 + expr * 700, 0, TAU); ctx.clip(); drawNeuron(ctx, HERO, nx, ny, ns, 0, { alpha: aA, core: '#f4ffc8', halo: '#b8e040' }); ctx.restore(); glow(ctx, nx, ny, 160, YFP, aA * .35 * smooth(0, .3, expr)); }
      // 病毒
      const vu = E.inOut(prog(t, tVir - .6, tGene + .2, x => x)); const vx = lerp(260, nx - 92, vu), vy = lerp(560, ny + 10, vu) + Math.sin(vu * Math.PI) * -70;
      const vA = aA * smooth(tVir - .8, tVir, t) * (1 - smooth(tSend + .4, tSend + 1.2, t));
      virus(ctx, vx, vy, 58, t * .5, .4 + t * .3, vA);
      label(ctx, '病毒载体', vx, vy - 60, { alpha: vA * smooth(tVir, tVir + .6, t) * (1 - smooth(tGene + .6, tGene + 1, t)), dx: -80, dy: -90, size: 28, en: 'viral vector', color: '#e4d8ff' });
      // 基因注入
      const gu = prog(t, tGene + .1, tSend + .6, E.inOut);
      if (gu > 0) { const L = 150; const gx0 = lerp(vx, nx - 40, gu), gx1 = gx0 + L * (1 - gu * .7); const ga = aA * (1 - smooth(tSend + .5, tSend + 1.1, t)); dna(ctx, gx0 - L * .2, vy, gx1, ny + 4, { alpha: ga, col: BLUE2, amp: 10, wl: 46, ph: t * 4, n: 40 }); label(ctx, 'ChR2 基因', (gx0 + gx1) / 2 - 20, ny + 4, { alpha: ga * smooth(tGene + .3, tGene + .9, t), dx: -150, dy: 150, size: 28, color: '#cfe2ff', lineColor: 'rgba(160,200,255,.85)' }); }
      text(ctx, '2005', 330, 300, { size: 140, font: 'song', weight: 200, color: '#ffffff', alpha: aA * smooth(.2, 1.2, t), spacing: .05, glow: 20, glowColor: ACC });
      text(ctx, '培养的大鼠海马神经元', 330, 400, { size: 26, font: 'song', color: '#cfe6ee', alpha: aA * smooth(1, 2, t), spacing: .1 });
      label(ctx, '黄色荧光：基因已表达', nx + 60, ny + 30, { alpha: aA * smooth(tSend + .4, tSend + 1.1, t), dx: 150, dy: 200, size: 26, en: 'fluorescent tag', color: '#eef8c0', lineColor: 'rgba(220,240,150,.8)' });
    }
    // —— B：一闪一放 ——
    const aB = smooth(c1 - .5, c1 + .3, t) * (1 - smooth(c2 - .5, c2 + .3, t));
    if (aB > 0) {
      const tPrec = wt(S, 1, '精确到毫秒');
      const pu = prog(t, c1 + .3, tPrec + .2, x => x);
      const nx = 340, ny = 520, ox = 700, ow = 1080;
      const X = u => ox + u * ow;
      const last = FLASH.filter(f => f <= pu).pop(); const since = last !== undefined ? (pu - last) * (tPrec - c1) : 9;
      const fl = Math.exp(-since * 9), sp = Math.exp(-Math.max(0, since - .02) * 6);
      // 神经元与光
      drawNeuron(ctx, HERO, nx, ny, .62, 0, { alpha: aB * (.55 + .45 * sp), core: '#f4ffd8', halo: '#9ed64a' });
      glow(ctx, nx, ny, 90, '#ffffff', aB * sp * .8);
      pulse(ctx, HERO.axon, clamp(since / .5), nx, ny, .62, 0, '#ffffff', aB * (since < .5 ? 1 : 0), 14, .1);
      ctx.save(); ctx.globalCompositeOperation = 'lighter'; const lg = ctx.createRadialGradient(nx, ny - 40, 0, nx, ny - 40, 330); lg.addColorStop(0, rgba(BLUE2, .5 * fl * aB)); lg.addColorStop(1, rgba(BLUE2, 0)); ctx.fillStyle = lg; ctx.fillRect(nx - 340, ny - 380, 680, 700); ctx.restore();
      ctx.save(); ctx.globalAlpha = aB; ctx.strokeStyle = 'rgba(200,225,255,.6)'; ctx.lineWidth = 1.5; ctx.beginPath(); ctx.moveTo(nx, 120); ctx.lineTo(nx, 200); ctx.stroke(); ctx.restore(); glow(ctx, nx, 202, 30, BLUE2, aB * (.3 + .7 * fl));
      // 轨道
      const rows = [['蓝光', 'LIGHT', 290], ['膜电位', 'VOLTAGE', 470], ['放电', 'SPIKES', 690]];
      for (const [zh, en, y] of rows) { text(ctx, zh, ox - 24, y - 8, { size: 24, font: 'song', weight: 500, align: 'right', color: '#e6f0f4', alpha: aB }); text(ctx, en, ox - 24, y + 20, { size: 13, font: 'latin', weight: 600, align: 'right', color: rgba(ACC, .8), alpha: aB, spacing: .25 }); }
      ctx.save(); ctx.globalAlpha = aB * .25; ctx.strokeStyle = '#bfe8f0'; ctx.lineWidth = 1; ctx.beginPath(); ctx.moveTo(ox, 320); ctx.lineTo(ox + ow, 320); ctx.moveTo(ox, 540); ctx.lineTo(ox + ow, 540); ctx.stroke(); ctx.restore();
      // 蓝光脉冲
      for (const f of FLASH) { if (f > pu) continue; const x = X(f); ctx.save(); ctx.globalCompositeOperation = 'lighter'; ctx.fillStyle = rgba(BLUE2, .9 * aB); ctx.fillRect(x - 3, 262, 6, 56); ctx.restore(); glow(ctx, x, 290, 30, BLUE2, aB * .5); }
      // 电位
      const vpts = []; for (let k = 0; k <= 540; k++) { const u = k / 540 * pu; let v = 0; for (const f of FLASH) { const d = (u - f - .006) / .0035; if (d > -3 && d < 8) v += d < 0 ? Math.exp(-d * d) : Math.exp(-d * .7) * (d < 1 ? 1 : 1); } v = Math.min(v, 1.1); const dip = FLASH.reduce((a, f) => a + (u > f + .012 && u < f + .05 ? -.08 * Math.sin((u - f - .012) / .038 * Math.PI) : 0), 0); vpts.push([X(u), 520 - v * 110 - dip * 110 + .8 * noise3(u * 60, 3, 0)]); }
      glowLine(ctx, vpts, '#9ff0ff', 1.6, aB, '#f2feff');
      // 栅格
      for (let tr = 0; tr < 6; tr++) for (const f of FLASH) { if (f > pu) continue; const x = X(f + .006) + (hash(tr * 31 + Math.round(f * 1000), 7) - .5) * 1.5; ctx.save(); ctx.globalCompositeOperation = 'lighter'; ctx.strokeStyle = rgba('#eafcff', .85 * aB); ctx.lineWidth = 2; ctx.beginPath(); ctx.moveTo(x, 630 + tr * 22); ctx.lineTo(x, 646 + tr * 22); ctx.stroke(); ctx.restore(); }
      // 对齐虚线
      ctx.save(); ctx.globalAlpha = aB * .35; ctx.setLineDash([2, 6]); ctx.strokeStyle = '#cfe6ff'; ctx.lineWidth = 1; ctx.beginPath(); for (const f of FLASH) { if (f > pu) continue; ctx.moveTo(X(f), 322); ctx.lineTo(X(f), 760); } ctx.stroke(); ctx.restore();
      // 扫描头
      const hx = X(pu); ctx.save(); ctx.globalAlpha = aB * .6; ctx.strokeStyle = '#ffffff'; ctx.lineWidth = 1; ctx.beginPath(); ctx.moveTo(hx, 250); ctx.lineTo(hx, 770); ctx.stroke(); ctx.restore();
      const pa = smooth(tPrec - .3, tPrec + .6, t) * aB;
      term(ctx, '精确到毫秒', 'millisecond precision', X(.5), 830, { alpha: pa, color: ACC, size: 36 });
    }
    // —— C：基因开关，只让一类神经元听命 ——
    const aC = smooth(c2 - .5, c2 + .3, t);
    if (aC > 0) {
      const tSel = wt(S, 2, '就能只让'), tBorn = wt(S, 2, '光遗传学');
      const expr = prog(t, c2 + 1.6, tSel - .2, x => x); const light = smooth(tSel - .2, tSel + .6, t);
      const scan = lerp(300, 900, expr);
      // 光照
      if (light > 0) { ctx.save(); ctx.globalCompositeOperation = 'lighter'; const lg = ctx.createRadialGradient(W / 2, -200, 100, W / 2, -200, 1350); lg.addColorStop(0, rgba(BLUE, .26 * light * aC)); lg.addColorStop(.55, rgba(BLUE, .1 * light * aC)); lg.addColorStop(1, rgba(BLUE, 0)); ctx.fillStyle = lg; ctx.fillRect(0, 0, W, H); ctx.restore(); }
      for (const n of TIS) {
        const N = TPL[n.tpl]; const target = n.type === 0; const ex = target ? smooth(n.y - 40, n.y + 40, scan) : 0;
        const cyc = ((t - tSel + n.ph) % .9 + .9) % .9; const fire = target && light > .3 ? Math.exp(-cyc * 7) : 0;
        const col = target ? (ex > .5 ? ['#eaf2ff', '#6f9cff'] : ['#cfdfe4', '#4a8a98']) : n.type === 1 ? ['#aebcc0', '#3e5e66'] : ['#b4c0ba', '#40625a'];
        drawNeuron(ctx, N, n.x, n.y, n.s, n.rot, { alpha: aC * (target ? .45 + .3 * ex + .25 * fire : .3 - .1 * light) * (1 - .25 * smooth(tBorn, tBorn + .8, t)), core: col[0], halo: col[1], axonA: .5 });
        if (fire > 0) { glow(ctx, n.x, n.y, 70, '#bcd4ff', aC * fire * .8); pulse(ctx, N.axon, cyc / .7, n.x, n.y, n.s, n.rot, '#ffffff', aC * light, 22, .1); }
        if (target && ex > 0) glow(ctx, n.x, n.y, 26, BLUE2, aC * ex * .6);
      }
      // 基因构件：启动子 + ChR2
      const da = aC * (1 - smooth(tBorn - .4, tBorn + .4, t));
      const gx0 = 620, gx1 = 1300, gy = 205;
      dna(ctx, gx0, gy, gx1, gy, { alpha: da * smooth(c2 - .2, c2 + .8, t), amp: 16, wl: 64, ph: t * 1.2, n: 120, colAt: u => u < .38 ? '#ffe08a' : u < .42 ? '#9fb8c8' : BLUE2 });
      label(ctx, '基因开关 · 启动子', lerp(gx0, gx1, .19), gy - 18, { alpha: da * smooth(c2 + .4, c2 + 1.2, t), dx: -150, dy: -55, size: 28, en: 'promoter', color: '#ffeab0', lineColor: 'rgba(255,224,140,.85)' });
      label(ctx, 'ChR2 基因', lerp(gx0, gx1, .72), gy - 18, { alpha: da * smooth(c2 + .9, c2 + 1.7, t), dx: 140, dy: -55, size: 28, color: '#cfe2ff', lineColor: 'rgba(160,200,255,.85)' });
      shade(ctx, W / 2, 312, 330, 40, .7 * da * smooth(tSel - 1.2, tSel - .4, t)); text(ctx, '只有这一类神经元表达光敏通道', W / 2, 312, { size: 24, font: 'song', color: '#d6e6ff', alpha: da * smooth(tSel - 1.2, tSel - .4, t), spacing: .15 });
      // 光遗传学诞生
      const ba = smooth(tBorn - .2, tBorn + .8, t) * aC * (1 - smooth(S.d - 1.3, S.d - .6, t));
      if (ba > 0) { shade(ctx, W / 2, 545, 640, 190, .75 * ba); term(ctx, '光遗传学', 'optogenetics', W / 2, 520, { alpha: ba, color: ACC, size: 76, glow: 22 }); text(ctx, '以光控制时间 · 以基因选择细胞', W / 2, 640, { size: 28, font: 'song', color: '#d8ecf6', alpha: ba * smooth(tBorn + .8, tBorn + 1.6, t), spacing: .2 }); }
    }
  };

  // 8. 开与关
  function mousePath() {
    const p = new Path2D();
    p.moveTo(0, 0); p.bezierCurveTo(28, -30, 80, -66, 150, -80); p.bezierCurveTo(250, -104, 380, -134, 500, -116); p.bezierCurveTo(610, -100, 690, -44, 700, 26);
    p.bezierCurveTo(705, 70, 668, 98, 612, 102); p.bezierCurveTo(520, 112, 400, 116, 300, 106); p.bezierCurveTo(220, 100, 150, 86, 100, 62); p.bezierCurveTo(60, 42, 20, 22, 0, 0);
    p.moveTo(140, -84); p.bezierCurveTo(118, -160, 210, -190, 232, -120); p.bezierCurveTo(236, -100, 222, -90, 205, -88);
    p.moveTo(700, 26); p.bezierCurveTo(800, 80, 880, 20, 1000, 70);
    p.moveTo(150, 92); p.bezierCurveTo(158, 112, 160, 128, 150, 140); p.lineTo(176, 140);
    p.moveTo(560, 104); p.bezierCurveTo(552, 124, 548, 136, 536, 146); p.lineTo(566, 146);
    for (const [dx, dy] of [[-70, -26], [-76, -4], [-66, 18]]) { p.moveTo(22, -6); p.quadraticCurveTo(22 + dx * .5, -6 + dy * .3, 22 + dx, -6 + dy); }
    return p;
  }
  const MOUSE = mousePath();
  const MBR = (() => { const p = new Path2D(); p.moveTo(92, -48); p.bezierCurveTo(110, -86, 220, -100, 290, -78); p.bezierCurveTo(330, -64, 330, -24, 296, -14); p.bezierCurveTo(240, -2, 140, -6, 100, -22); p.closePath(); return p; })();
  scenes.onoff = (ctx, S) => {
    const t = S.t, c1 = S.cue(1);
    deep(ctx, t + 110, { neb: .1, seed: 6, motes: .45 });
    const tOff = wt(S, 0, '由黄光'), tB = wt(S, 0, '蓝光点亮'), tY = wt(S, 0, '黄光熄灭');
    const aA = 1 - smooth(c1 - .8, c1 - .1, t);
    if (aA > 0) {
      const nx = 340, ny = 380; const T0 = .2, T1 = S.cend(0) + .2; const X = tt => lerp(640, 1700, (tt - T0) / (T1 - T0));
      const spont = [.9, 2.0, 3.1, 3.8], blue = []; for (let tt = tB + .08; tt < tY; tt += .13) blue.push(tt);
      const spikes = spont.concat(blue).filter(s => s < tB || (s >= tB && s < tY));
      const vAt = tt => { let v = 0; for (const s of spikes) { const d = (tt - s) / .022; if (d > -3 && d < 6) v += d < 0 ? Math.exp(-d * d) : Math.exp(-d * .9); } v = Math.min(1, v); const hyp = tt > tY ? -.32 * smooth(tY, tY + .15, tt) : 0; return v + hyp; };
      const isB = t >= tB && t < tY, isY = t >= tY;
      const lastS = spikes.filter(s => s <= t).pop(); const since = lastS !== undefined ? t - lastS : 9; const sp = Math.exp(-since * 10);
      // 光照
      if (isB || isY) { const c = isB ? BLUE2 : AMB; const k = isB ? smooth(tB, tB + .15, t) : smooth(tY, tY + .15, t); ctx.save(); ctx.globalCompositeOperation = 'lighter'; const lg = ctx.createRadialGradient(nx, ny, 0, nx, ny, 420); lg.addColorStop(0, rgba(c, .32 * k * aA)); lg.addColorStop(1, rgba(c, 0)); ctx.fillStyle = lg; ctx.fillRect(nx - 420, ny - 420, 840, 840); ctx.restore(); }
      drawNeuron(ctx, TPL[3], nx, ny + 40, .62, 0, { alpha: aA * (isY ? .4 : .6 + .4 * sp), core: isY ? '#e8d8b8' : '#eaf8ff', halo: isY ? '#a08050' : FIL });
      glow(ctx, nx, ny + 40, 80, '#ffffff', aA * sp * .8 * (isY ? 0 : 1));
      if (since < .5) pulse(ctx, TPL[3].axon, since / .5, nx, ny + 40, .62, 0, '#ffffff', aA, 14, .1);
      // 键
      const keys = [{ y: 300, c: BLUE2, zh: '开', en: 'ON', l1: 'ChR2 · 约 470 纳米蓝光', l2: '阳离子通道 · 让正离子流入', on: isB, ap: smooth(.1, .8, t) }, { y: 490, c: AMB, zh: '关', en: 'OFF', l1: 'NpHR · 约 590 纳米黄光', l2: '氯离子泵 · 把负离子泵入', on: isY, ap: smooth(tOff - .2, tOff + .6, t) }];
      for (const k of keys) {
        const a = aA * k.ap; if (a <= 0) continue; const kx = 1060, kw = 640, kh = 128; const press = k.on ? 1 : 0;
        ctx.save(); ctx.globalAlpha = a; ctx.beginPath(); ctx.roundRect(kx, k.y - kh / 2 + press * 3, kw, kh, 64);
        const kg = ctx.createLinearGradient(kx, 0, kx + kw, 0); kg.addColorStop(0, rgba(k.c, k.on ? .32 : .1)); kg.addColorStop(.5, rgba(k.c, k.on ? .12 : .03)); kg.addColorStop(1, 'rgba(255,255,255,0)'); ctx.fillStyle = kg; ctx.fill();
        ctx.strokeStyle = rgba(k.c, k.on ? .95 : .45); ctx.lineWidth = 1.6; ctx.stroke(); ctx.restore();
        const lx = kx + 64, ly = k.y + press * 3; glow(ctx, lx, ly, k.on ? 110 : 50, k.c, a * (k.on ? .7 : .3)); dot(ctx, lx, ly, 30, k.on ? '#ffffff' : rgba(k.c, 1), a * (k.on ? .95 : .5));
        text(ctx, k.zh, lx, ly + 1, { size: 34, font: 'song', weight: 700, color: k.on ? '#1a1a1a' : '#0b1418', alpha: a });
        text(ctx, k.en, kx + 130, ly - 26, { size: 22, font: 'latin', weight: 700, align: 'left', color: k.c, alpha: a, spacing: .3 });
        text(ctx, k.l1, kx + 200, ly - 22, { size: 26, font: 'song', weight: 600, align: 'left', color: '#f4f0e6', alpha: a });
        text(ctx, k.l2, kx + 130, ly + 26, { size: 24, font: 'song', align: 'left', color: '#d0dce0', alpha: a * .95 });
      }
      // 曲线（带光照时段底色）
      const ty0 = 660, th = 150, ya = v => ty0 + th * .62 - v * th * .55;
      ctx.save(); ctx.globalAlpha = aA;
      if (t > tB) { ctx.fillStyle = rgba(BLUE2, .12); ctx.fillRect(X(tB), ty0, Math.min(X(t), X(tY)) - X(tB), th); }
      if (t > tY) { ctx.fillStyle = rgba(AMB, .12); ctx.fillRect(X(tY), ty0, X(t) - X(tY), th); }
      ctx.strokeStyle = 'rgba(190,230,240,.2)'; ctx.lineWidth = 1; ctx.beginPath(); ctx.moveTo(640, ya(0)); ctx.lineTo(1700, ya(0)); ctx.stroke(); ctx.restore();
      const pts = []; for (let k = 0; k <= 700; k++) { const tt = lerp(T0, Math.min(t, T1), k / 700); pts.push([X(tt), ya(vAt(tt)) + .6 * noise3(tt * 40, 2, 0)]); }
      if (t > T0) glowLine(ctx, pts, '#9ff0ff', 1.6, aA, '#f2feff');
      text(ctx, '膜电位', 640, ty0 - 4, { size: 22, font: 'song', align: 'left', color: '#cfe6ee', alpha: aA * .9 }); text(ctx, 'MEMBRANE VOLTAGE', 722, ty0 - 3, { size: 13, font: 'latin', weight: 600, align: 'left', color: rgba(ACC, .8), alpha: aA * .8, spacing: .25 });
      if (t > tB + .3) text(ctx, '蓝光：连续放电', (X(tB) + X(Math.min(t, tY))) / 2, ty0 + th + 26, { size: 22, font: 'song', color: '#bcd6ff', alpha: aA * smooth(tB + .3, tB + .8, t) });
      if (t > tY + .3) text(ctx, '黄光：沉默', (X(tY) + X(t)) / 2, ty0 + th + 26, { size: 22, font: 'song', color: '#ffe0a0', alpha: aA * smooth(tY + .3, tY + .8, t) });
    }
    // —— 小鼠与光纤 ——
    const aM = smooth(c1 - .25, c1 + .5, t);
    if (aM > 0) {
      const mx = 560, my = 560, ms = 1.05; const tFib = c1, tDeep = wt(S, 1, '就能把光');
      ctx.save(); ctx.globalAlpha = aM; ctx.translate(mx, my); ctx.scale(ms, ms);
      ctx.lineCap = 'round'; ctx.lineJoin = 'round';
      ctx.strokeStyle = 'rgba(243,230,216,.1)'; ctx.lineWidth = 9; ctx.stroke(MOUSE);
      ctx.strokeStyle = 'rgba(243,230,216,.85)'; ctx.lineWidth = 2; ctx.stroke(MOUSE);
      ctx.fillStyle = 'rgba(243,230,216,.9)'; ctx.beginPath(); ctx.ellipse(92, -40, 5, 6, 0, 0, TAU); ctx.fill();
      // 透视的大脑
      ctx.setLineDash([3, 5]); ctx.strokeStyle = 'rgba(160,220,235,.6)'; ctx.lineWidth = 1.4; ctx.stroke(MBR); ctx.setLineDash([]);
      ctx.restore();
      const S2 = (x, y) => [mx + x * ms, my + y * ms];
      // 脑内神经元
      for (let i = 0; i < 9; i++) { const p = S2(150 + hash(i, 41) * 150, -70 + hash(i, 42) * 50); drawNeuron(ctx, MINI[i % MINI.length], p[0], p[1], .3, hash(i, 43) * TAU, { alpha: aM * .5, lite: true, axon: false }); }
      // 光纤
      const top = S2(268, -420), skull = S2(268, -100), tip = S2(268, -42);
      const fa = aM * smooth(tFib - .2, tFib + .6, t);
      ctx.save(); ctx.globalAlpha = fa; ctx.strokeStyle = 'rgba(220,235,245,.8)'; ctx.lineWidth = 1.6; ctx.beginPath(); ctx.moveTo(top[0], 0); ctx.lineTo(skull[0], skull[1]); ctx.stroke();
      ctx.fillStyle = 'rgba(210,220,230,.85)'; ctx.fillRect(skull[0] - 9, skull[1] - 26, 18, 30); ctx.strokeStyle = 'rgba(255,255,255,.6)'; ctx.strokeRect(skull[0] - 9, skull[1] - 26, 18, 30);
      ctx.strokeStyle = 'rgba(230,245,255,.9)'; ctx.lineWidth = 1.2; ctx.beginPath(); ctx.moveTo(skull[0], skull[1]); ctx.lineTo(tip[0], tip[1]); ctx.stroke(); ctx.restore();
      // 光沿光纤下行
      const lu = prog(t, tDeep - .4, tDeep + 1.1, x => x);
      if (lu > 0) {
        const y = lerp(0, tip[1], E.in(Math.min(1, lu)));
        glowLine(ctx, [[top[0], 0], [top[0], y]], BLUE2, 2, fa * .9, '#e6f0ff');
        if (lu < 1) { glow(ctx, top[0], y, 40, BLUE2, fa); glow(ctx, top[0], y, 10, '#ffffff', fa); }
        const ta = smooth(.95, 1, lu);
        if (ta > 0) {
          ctx.save(); ctx.globalCompositeOperation = 'lighter'; const cg = ctx.createRadialGradient(tip[0], tip[1], 0, tip[0], tip[1], 110); cg.addColorStop(0, rgba(BLUE2, .7 * ta * fa)); cg.addColorStop(1, rgba(BLUE2, 0)); ctx.fillStyle = cg; ctx.beginPath(); ctx.moveTo(tip[0], tip[1]); ctx.arc(tip[0], tip[1], 110, Math.PI * .28, Math.PI * .72); ctx.closePath(); ctx.fill(); ctx.restore();
          glow(ctx, tip[0], tip[1], 70, BLUE2, ta * fa * (.7 + .3 * Math.sin(t * 6))); glow(ctx, tip[0], tip[1], 14, '#ffffff', ta * fa);
        }
      }
      label(ctx, '光纤 · 细如发丝', top[0], 230, { alpha: fa * smooth(tFib + .3, tFib + 1.1, t), dx: 130, dy: -40, size: 28, en: 'optical fibre' });
      label(ctx, '大脑深处', tip[0], tip[1], { alpha: aM * smooth(tDeep + 1, tDeep + 1.8, t), dx: 170, dy: 150, size: 28, en: 'deep brain', color: '#d8e8ff' });
      text(ctx, '活体小鼠 · 自由活动', 1470, 760, { size: 26, font: 'song', color: '#e2dccf', alpha: aM * smooth(tDeep, tDeep + 1, t), spacing: .2 });
    }
  };

  // 9. 按下琴键
  const BRAIN = (() => {
    const p = new Path2D();
    p.moveTo(30, 360); p.bezierCurveTo(25, 300, 70, 262, 140, 262); p.bezierCurveTo(175, 262, 200, 270, 215, 262);
    p.bezierCurveTo(320, 120, 520, 60, 720, 62); p.bezierCurveTo(880, 64, 990, 120, 1030, 190);
    p.bezierCurveTo(1050, 180, 1090, 175, 1130, 190); p.bezierCurveTo(1200, 215, 1235, 290, 1215, 360);
    p.bezierCurveTo(1205, 395, 1180, 415, 1160, 425); p.bezierCurveTo(1200, 440, 1260, 450, 1300, 455); p.lineTo(1300, 500);
    p.bezierCurveTo(1220, 498, 1120, 505, 1050, 520); p.bezierCurveTo(980, 535, 900, 548, 820, 545);
    p.bezierCurveTo(740, 543, 680, 560, 620, 548); p.bezierCurveTo(540, 535, 430, 495, 320, 470);
    p.bezierCurveTo(260, 458, 215, 440, 195, 430); p.bezierCurveTo(140, 435, 50, 420, 30, 360); p.closePath();
    return p;
  })();
  const BOX = 340, BOY = 230;
  const NET = (() => {
    const c = document.createElement('canvas').getContext('2d'); const r = rng(1313); const nodes = [];
    let g = 0; while (nodes.length < 260 && g++ < 20000) { const x = 40 + r() * 1250, y = 40 + r() * 520; if (c.isPointInPath(BRAIN, x, y) && !nodes.some(n => Math.hypot(n[0] - x, n[1] - y) < 26)) nodes.push([x, y, r()]); }
    const edges = new Path2D(); const e2 = [];
    nodes.forEach((n, i) => { const near = nodes.map((m, j) => [Math.hypot(m[0] - n[0], m[1] - n[1]), j]).filter(d => d[1] !== i).sort((a, b) => a[0] - b[0]).slice(0, 3); for (const [d, j] of near) { if (j < i || d > 110) continue; const m = nodes[j]; const mx = (n[0] + m[0]) / 2 + (r() - .5) * 18, my = (n[1] + m[1]) / 2 + (r() - .5) * 18; edges.moveTo(n[0], n[1]); edges.quadraticCurveTo(mx, my, m[0], m[1]); e2.push([n, m, mx, my]); } });
    const dots = new Path2D(); for (const n of nodes) { dots.moveTo(n[0] + 2.2, n[1]); dots.arc(n[0], n[1], 2.2, 0, TAU); }
    return { nodes, edges, dots, e2 };
  })();
  const REG = { wake: [640, 470, '觉醒', 'wakefulness'], feed: [690, 525, '进食', 'feeding'], fear: [830, 235, '恐惧记忆', 'fear memory'] };
  const LOOPS = [
    { zh: '帕金森病', en: "parkinson's disease", c: '#ffb36a', P: [[520, 130], [650, 140], [720, 250], [770, 345], [650, 405], [520, 320]], lab: [640, 22] },
    { zh: '抑郁', en: 'depression', c: '#8fb8ff', P: [[215, 270], [310, 225], [410, 300], [425, 405], [320, 430], [240, 350]], lab: [190, 175] },
    { zh: '焦虑', en: 'anxiety', c: '#c2a6ff', P: [[700, 445], [800, 425], [905, 455], [885, 512], [770, 528], [690, 495]], lab: [960, 610] },
].map(L => ({ ...L, pts: spline(L.P, true, 18).map(p => [p[0] + BOX, p[1] + BOY]) }));
  scenes.map = (ctx, S) => {
    const t = S.t, c1 = S.cue(1);
    deep(ctx, t + 130, { neb: .14, seed: 7, motes: .4 });
    const tKey = wt(S, 0, '逐一按下'), tWake = wt(S, 0, '让动物醒来') - .4, tFeed = wt(S, 0, '驱动进食') - .3, tFear = wt(S, 0, '恐惧的记忆') - .6;
    const reveal = prog(t, .6, 3.0, E.inOut);
    ctx.save(); ctx.translate(BOX, BOY);
    // 黑箱 → 透明
    ctx.fillStyle = `rgba(0,0,0,${.85 * (1 - reveal)})`; ctx.fill(BRAIN);
    ctx.save(); ctx.clip(BRAIN);
    const sx = lerp(-200, 1500, reveal);
    const rg = ctx.createLinearGradient(sx - 300, 0, sx + 40, 0); rg.addColorStop(0, 'rgba(160,230,255,0)'); rg.addColorStop(.85, 'rgba(190,240,255,.55)'); rg.addColorStop(1, 'rgba(190,240,255,0)');
    ctx.globalCompositeOperation = 'lighter';
    ctx.globalAlpha = .9 * smooth(.4, 1.4, t); ctx.strokeStyle = rgba(FIL, .16 + .1 * reveal); ctx.lineWidth = 1; ctx.stroke(NET.edges);
    ctx.fillStyle = rgba('#bff4ff', .3 + .4 * reveal); ctx.fill(NET.dots);
    // 扫描光
    if (reveal > 0 && reveal < 1) { ctx.globalAlpha = .5; ctx.fillStyle = rg; ctx.fillRect(sx - 300, 0, 340, 600); }
    // 环路上的随机活动
    ctx.globalAlpha = 1;
    for (let i = 0; i < NET.e2.length; i += 3) { const [n, m, cx, cy] = NET.e2[i]; const u = ((t * .6 + hash(i, 61) * 5) % 2.4) / .6; if (u > 1) continue; const x = (1 - u) * (1 - u) * n[0] + 2 * (1 - u) * u * cx + u * u * m[0], y = (1 - u) * (1 - u) * n[1] + 2 * (1 - u) * u * cy + u * u * m[1]; glow(ctx, x, y, 8, '#dff8ff', .5 * reveal * (1 - .5 * smooth(c1 - .5, c1 + .5, t))); }
    ctx.restore();
    ctx.strokeStyle = rgba('#cfefff', .7); ctx.lineWidth = 1.8; ctx.stroke(BRAIN);
    ctx.strokeStyle = rgba('#cfefff', .12); ctx.lineWidth = 8; ctx.stroke(BRAIN);
    // 内部结构（细线）
    ctx.save(); ctx.clip(BRAIN); ctx.globalAlpha = .35 * reveal; ctx.strokeStyle = '#a8dbe6'; ctx.lineWidth = 1.2; ctx.beginPath();
    ctx.moveTo(240, 280); ctx.bezierCurveTo(420, 160, 720, 150, 990, 230);
    ctx.moveTo(700, 205); ctx.bezierCurveTo(880, 200, 980, 300, 905, 400);
    ctx.moveTo(835, 340); ctx.ellipse(760, 340, 75, 46, 0, 0, TAU);
    for (let k = 0; k < 6; k++) { const r0 = 30 + k * 26; ctx.moveTo(1150 + r0 * Math.cos(-1.9), 300 + r0 * Math.sin(-1.9)); ctx.arc(1150, 300, r0, -1.9, 1.2); }
    ctx.stroke(); ctx.restore(); ctx.globalAlpha = 1;
    ctx.restore();
    text(ctx, '小鼠大脑 · 矢状切面（示意）', W - 110, 170, { size: 20, font: 'song', align: 'right', color: '#9fc4cc', alpha: smooth(1, 2, t) * .85, spacing: .12 });
    // 琴键
    const kA = smooth(tKey - .4, tKey + .6, t) * (1 - smooth(c1 - .4, c1 + .4, t));
    const keys = [null, 'wake', null, 'feed', null, 'fear', null];
    const kt = { wake: tWake, feed: tFeed, fear: tFear };
    keys.forEach((k, i) => {
      const kx = W / 2 + (i - 3) * 160, ky = 840; const a = kA * smooth(tKey - .4 + i * .08, tKey + .3 + i * .08, t);
      if (a <= 0) return; const on = k ? smooth(kt[k], kt[k] + .25, t) : 0; const press = k ? smooth(kt[k], kt[k] + .1, t) * (1 - smooth(kt[k] + .25, kt[k] + .5, t)) : 0;
      ctx.save(); ctx.globalAlpha = a; ctx.beginPath(); ctx.roundRect(kx - 70, ky - 26 + press * 5, 140, 52, 26);
      ctx.fillStyle = k ? rgba(ACC, .06 + .22 * on) : 'rgba(200,230,240,.04)'; ctx.fill(); ctx.strokeStyle = k ? rgba(ACC, .4 + .5 * on) : 'rgba(200,230,240,.22)'; ctx.lineWidth = 1.4; ctx.stroke(); ctx.restore();
      if (k) {
        const R = REG[k]; text(ctx, R[2], kx, ky + press * 5, { size: 26, font: 'song', weight: 600, color: on > .5 ? '#ffffff' : '#cfe2ea', alpha: a, spacing: .1 });
        if (on > 0) {
          const rx = R[0] + BOX, ry = R[1] + BOY; const pts = KIT.arcPts(kx, ky - 28, rx, ry, (i < 3 ? -.18 : .18), 40);
          const gu = E.out(clamp((t - kt[k]) / .6));
          glowLine(ctx, pts.slice(0, Math.max(2, Math.floor(pts.length * gu))), ACC, 1.2, a * .8, '#eaf8ff');
          if (gu >= 1) { glow(ctx, rx, ry, 120, ACC, a * .45 * (.8 + .2 * Math.sin(t * 5))); glow(ctx, rx, ry, 30, '#ffffff', a * .9); for (let j = 0; j < 10; j++) { const an = hash(j, i) * TAU, rr = 20 + hash(j, i + 9) * 40; glow(ctx, rx + Math.cos(an) * rr, ry + Math.sin(an) * rr * .7, 10, '#dff8ff', a * .6 * (.5 + .5 * Math.sin(t * 9 + j))); } }
        }
      }
    });
    const ka2 = kA * smooth(tKey, tKey + .8, t);
    // 环路勾勒
    if (t > c1 - .5) {
      const la = smooth(c1 - .3, c1 + .5, t);
      const lt = [wt(S, 1, '帕金森'), wt(S, 1, '抑郁'), wt(S, 1, '焦虑')];
      LOOPS.forEach((L, i) => {
        const u = prog(t, lt[i] - .1, lt[i] + 1.8, E.inOut); if (u <= 0) return;
        const n = Math.max(2, Math.floor(L.pts.length * u)); glowLine(ctx, L.pts.slice(0, n), L.c, 2.2, la, hex(mix(L.c, '#ffffff', .35)));
        const hp = L.pts[n - 1]; if (u < 1) glow(ctx, hp[0], hp[1], 30, L.c, la);
        L.P.forEach((q, j) => { if (j / L.P.length <= u) { glow(ctx, q[0] + BOX, q[1] + BOY, 22, L.c, la * .6); dot(ctx, q[0] + BOX, q[1] + BOY, 3.5, '#ffffff', la); } });
        if (u >= 1) { const cu = ((t - lt[i] - 1.9) * .35) % 1; const k2 = Math.floor(cu * (L.pts.length - 1)); glow(ctx, L.pts[k2][0], L.pts[k2][1], 26, L.c, la * .9); glow(ctx, L.pts[k2][0], L.pts[k2][1], 8, '#ffffff', la); }
        const lx = L.lab[0] + BOX, ly = L.lab[1] + BOY; shade(ctx, lx, ly, 150, 55, .55 * smooth(.3, .8, u));
        text(ctx, L.zh, lx, ly - 6, { size: 32, font: 'song', weight: 600, color: L.c, alpha: la * smooth(.25, .7, u), spacing: .15, glow: 10, glowColor: L.c });
        text(ctx, L.en.toUpperCase(), lx, ly + 24, { size: 14, font: 'latin', weight: 600, color: rgba(L.c, .9), alpha: la * smooth(.35, .8, u), spacing: .3 });
      });
      text(ctx, '神经环路（示意）', W / 2, 860, { size: 24, font: 'song', color: '#cfe2ea', alpha: smooth(lt[2] + 1, lt[2] + 2, t), spacing: .3 });
    }
  };

  // 10. 走向临床
  const EC = [560, 470], ER = 250;
  const GC = (() => { const a = []; for (let i = 0; i < 8; i++) a.push({ y: 250 + i * 58 + (i % 2) * 8, x: 1200 + (i % 2) * 14 }); return a; })();
  const PR = (() => { const r = rng(1777); const a = []; for (let i = 0; i < 26; i++) a.push({ y: 210 + i * 19.5, len: 30 + r() * 70, dead: r(), cone: r() < .25 }); return a; })();
  const CUP = (() => { const p = new Path2D(); p.moveTo(-95, -95); p.lineTo(85, -95); p.bezierCurveTo(84, 0, 66, 70, 34, 98); p.lineTo(-44, 98); p.bezierCurveTo(-76, 70, -94, 0, -95, -95); p.closePath(); return p; })();
  const HANDLE = (() => { const p = new Path2D(); p.ellipse(100, -18, 42, 50, 0, -1.6, 1.6); return p; })();
  const SAUCER = (() => { const p = new Path2D(); p.ellipse(-5, 112, 150, 22, 0, 0, TAU); return p; })();
  const CUPDOTS = (() => { const c = document.createElement('canvas').getContext('2d'); const a = []; for (let y = -210; y <= 210; y += 12) for (let x = -210; x <= 210; x += 12) { if (x * x + y * y > 228 * 228) continue; c.lineWidth = 15; const onE = c.isPointInStroke(CUP, x, y) || c.isPointInStroke(HANDLE, x, y); c.lineWidth = 11; const onS = c.isPointInStroke(SAUCER, x, y); const inF = c.isPointInPath(CUP, x, y); a.push({ x, y, v: onE ? 1 : onS ? .75 : inF ? .22 : 0, h: hash(x * 7 + y * 13, 5) }); } return a; })();
  scenes.clinic = (ctx, S) => {
    const t = S.t, c1 = S.cue(1), c2 = S.cue(2);
    const tExpr = wt(S, 0, '眼中细胞'), tGog = wt(S, 0, '借助特制'), tSee = wt(S, 0, '重新感知'), tLoc = wt(S, 0, '定位'), tTouch = wt(S, 0, '触碰');
    deep(ctx, t + 150, { c1: '#0a1f24', neb: .1, seed: 8, motes: .35 });
    const aA = 1 - smooth(c1 - .5, c1 + .3, t);
    if (aA > 0) {
      const ea = aA * smooth(-.2, 1, t);
      // —— 眼球剖面 ——
      ctx.save(); ctx.globalAlpha = ea;
      const vg = ctx.createRadialGradient(EC[0] - 60, EC[1] - 40, 20, EC[0], EC[1], ER); vg.addColorStop(0, 'rgba(40,70,80,.35)'); vg.addColorStop(1, 'rgba(10,25,30,.6)');
      ctx.fillStyle = vg; ctx.beginPath(); ctx.arc(EC[0], EC[1], ER, 0, TAU); ctx.fill();
      // 视网膜（后壁）
      const ret = ctx.createLinearGradient(EC[0] + ER * .2, 0, EC[0] + ER, 0); ret.addColorStop(0, 'rgba(170,150,140,.0)'); ret.addColorStop(1, 'rgba(190,160,150,.5)');
      ctx.strokeStyle = 'rgba(210,180,170,.55)'; ctx.lineWidth = 10; ctx.beginPath(); ctx.arc(EC[0], EC[1], ER - 12, -1.2, 1.2); ctx.stroke();
      ctx.strokeStyle = 'rgba(120,60,50,.6)'; ctx.lineWidth = 6; ctx.beginPath(); ctx.arc(EC[0], EC[1], ER - 3, -1.25, 1.25); ctx.stroke();
      // 巩膜与角膜
      ctx.strokeStyle = 'rgba(240,235,225,.85)'; ctx.lineWidth = 2; ctx.beginPath(); ctx.arc(EC[0], EC[1], ER, Math.PI + .62, Math.PI - .62); ctx.stroke();
      const cA = [EC[0] + Math.cos(Math.PI - .62) * ER, EC[1] + Math.sin(Math.PI - .62) * ER], cB = [EC[0] + Math.cos(Math.PI + .62) * ER, EC[1] + Math.sin(Math.PI + .62) * ER];
      ctx.beginPath(); ctx.moveTo(cB[0], cB[1]); ctx.quadraticCurveTo(EC[0] - ER - 70, EC[1], cA[0], cA[1]); ctx.stroke();
      // 晶状体与虹膜
      const lx = EC[0] - ER + 82; ctx.fillStyle = 'rgba(200,230,240,.18)'; ctx.strokeStyle = 'rgba(220,240,250,.7)'; ctx.lineWidth = 1.6; ctx.beginPath(); ctx.ellipse(lx, EC[1], 30, 82, 0, 0, TAU); ctx.fill(); ctx.stroke();
      ctx.strokeStyle = 'rgba(120,170,190,.85)'; ctx.lineWidth = 5; ctx.beginPath(); ctx.moveTo(lx - 22, EC[1] - 150); ctx.lineTo(lx - 18, EC[1] - 60); ctx.moveTo(lx - 22, EC[1] + 150); ctx.lineTo(lx - 18, EC[1] + 60); ctx.stroke();
      // 视神经
      ctx.strokeStyle = 'rgba(240,235,225,.7)'; ctx.lineWidth = 2; ctx.beginPath(); const oa = .32; ctx.moveTo(EC[0] + Math.cos(oa - .1) * ER, EC[1] + Math.sin(oa - .1) * ER); ctx.lineTo(EC[0] + ER + 110, EC[1] + 70); ctx.moveTo(EC[0] + Math.cos(oa + .12) * ER, EC[1] + Math.sin(oa + .12) * ER); ctx.lineTo(EC[0] + ER + 100, EC[1] + 130); ctx.stroke();
      ctx.restore();
      text(ctx, '视网膜色素变性', EC[0], EC[1] + ER + 60, { size: 28, font: 'song', weight: 500, color: '#efe6da', alpha: ea * smooth(1, 2, t), spacing: .2 });
      text(ctx, 'RETINITIS PIGMENTOSA', EC[0], EC[1] + ER + 96, { size: 14, font: 'latin', weight: 600, color: rgba(ACC, .85), alpha: ea * smooth(1.3, 2.3, t), spacing: .3 });
      // 眼镜与琥珀色光
      const gA = aA * smooth(tGog - .3, tGog + .5, t);
      if (gA > 0) {
        const gx = 165, gy = EC[1];
        ctx.save(); ctx.globalAlpha = gA; ctx.fillStyle = 'rgba(30,40,46,.9)'; ctx.strokeStyle = 'rgba(230,230,225,.75)'; ctx.lineWidth = 1.6; ctx.beginPath(); ctx.roundRect(gx - 30, gy - 85, 60, 170, 22); ctx.fill(); ctx.stroke();
        ctx.globalAlpha = gA * .3; ctx.beginPath(); ctx.moveTo(gx + 10, gy - 85); ctx.bezierCurveTo(gx + 60, gy - 200, EC[0] - 60, EC[1] - ER - 60, EC[0] + 40, EC[1] - ER - 30); ctx.stroke(); ctx.restore();
        glow(ctx, gx + 24, gy, 60, AMB, gA * .7);
        const pat = Math.floor(t * 3);
        ctx.save(); ctx.globalCompositeOperation = 'lighter';
        for (let k = -3; k <= 3; k++) { const y0 = gy + k * 18, y1 = EC[1] - k * 22; const on = hash(k + 10, pat) > .35 ? 1 : .35; const lg = ctx.createLinearGradient(gx, 0, EC[0] + ER, 0); lg.addColorStop(0, rgba(AMB, .5 * gA * on)); lg.addColorStop(1, rgba(AMB, .12 * gA * on)); ctx.strokeStyle = lg; ctx.lineWidth = 3; ctx.beginPath(); ctx.moveTo(gx + 30, y0); ctx.lineTo(lx, EC[1] + k * 9); ctx.lineTo(EC[0] + ER - 16, y1); ctx.stroke(); }
        ctx.restore();
        for (let k = -3; k <= 3; k++) glow(ctx, EC[0] + ER - 18, EC[1] - k * 22, 18, AMB, gA * .8);
        label(ctx, '投影眼镜 · 595 纳米琥珀光', gx, gy + 85, { alpha: gA, dx: 50, dy: 120, size: 28, en: 'projection goggles', color: '#ffe6b0', lineColor: 'rgba(255,214,140,.8)' });
      }
      // —— 放大：视网膜细胞层 ——
      const iA = aA * smooth(1.2, 2.2, t); const IX = 1350, IY = 450, IR = 260;
      const persp = smooth(tSee - .3, tSee + .9, t);
      if (iA > 0) {
        const sxp = EC[0] + ER - 12, syp = EC[1];
        ctx.save(); ctx.globalAlpha = iA * .55; ctx.strokeStyle = '#cfe6ee'; ctx.lineWidth = 1; ctx.beginPath(); ctx.arc(sxp, syp, 30, 0, TAU); ctx.moveTo(sxp + 6, syp - 30); ctx.lineTo(IX - 60, IY - IR + 8); ctx.moveTo(sxp + 6, syp + 30); ctx.lineTo(IX - 60, IY + IR - 8); ctx.stroke(); ctx.restore();
        ctx.save(); ctx.beginPath(); ctx.arc(IX, IY, IR, 0, TAU); ctx.fillStyle = `rgba(4,14,18,${.92 * iA})`; ctx.fill(); ctx.clip();
        const cellA = iA * (1 - persp);
        if (cellA > 0) {
          // 色素上皮
          ctx.fillStyle = rgba('#5a2a20', .8 * cellA); ctx.fillRect(1560, 150, 60, 620);
          // 感光细胞（退化）
          for (const p of PR) { const L = p.len * (p.dead < .7 ? .45 : 1); const col = 'rgba(150,150,150,'; ctx.strokeStyle = col + (.55 * cellA) + ')'; ctx.lineWidth = p.cone ? 9 : 6; ctx.lineCap = 'round'; ctx.beginPath(); ctx.moveTo(1440, p.y); ctx.lineTo(1440 + L, p.y + (p.dead < .3 ? 6 : 0)); ctx.stroke(); dot(ctx, 1432, p.y, 6, '#8a8a8a', cellA * .6); }
          // 双极细胞
          for (let i = 0; i < 12; i++) { const y = 230 + i * 40; ctx.save(); ctx.globalAlpha = cellA * .45; ctx.strokeStyle = '#9fb8c0'; ctx.lineWidth = 1.4; ctx.beginPath(); ctx.ellipse(1320, y, 18, 8, 0, 0, TAU); ctx.moveTo(1302, y); ctx.lineTo(1250, y + 6); ctx.moveTo(1338, y); ctx.lineTo(1420, y - 4); ctx.stroke(); ctx.restore(); }
          // 神经节细胞：表达 ChrimsonR 后变为琥珀色
          const ex = smooth(tExpr, tExpr + 1.6, t), lit = smooth(tGog + .2, tGog + .8, t);
          ctx.save(); ctx.globalAlpha = cellA * .6; ctx.strokeStyle = ex > .5 ? '#ffcf80' : '#a8c8d0'; ctx.lineWidth = 2; ctx.beginPath(); ctx.moveTo(1160, 160); ctx.lineTo(1160, 760); ctx.stroke(); ctx.restore();
          GC.forEach((g, i) => {
            const col = rgba(mix('#9fc0c8', AMB, ex), 1); const fire = lit * Math.exp(-(((t * 1.3 + hash(i, 3) * 2) % 1.1)) * 5);
            ctx.save(); ctx.globalAlpha = cellA; ctx.strokeStyle = col; ctx.lineWidth = 1.6; ctx.beginPath(); ctx.moveTo(g.x + 14, g.y); ctx.lineTo(g.x + 60, g.y - 10); ctx.moveTo(g.x + 14, g.y + 4); ctx.lineTo(g.x + 70, g.y + 16); ctx.moveTo(g.x - 14, g.y); ctx.quadraticCurveTo(g.x - 34, g.y, 1160, g.y + 24); ctx.stroke();
            ctx.fillStyle = col; ctx.beginPath(); ctx.arc(g.x, g.y, 15, 0, TAU); ctx.fill(); ctx.restore();
            glow(ctx, g.x, g.y, 46, AMB, cellA * ex * (.35 + .65 * fire));
            if (fire > .2) { const yy = g.y + 24 + ((t * 1.3 + hash(i, 3) * 2) % 1.1) * 300; glow(ctx, 1160, yy, 14, '#fff0d0', cellA * fire); }
          });
          // 光从左侧射入
          if (lit > 0) { ctx.save(); ctx.globalCompositeOperation = 'lighter'; for (let k = 0; k < 7; k++) { const y = 250 + k * 66; const lg = ctx.createLinearGradient(1090, 0, 1260, 0); lg.addColorStop(0, rgba(AMB, .45 * lit * cellA)); lg.addColorStop(1, rgba(AMB, 0)); ctx.fillStyle = lg; ctx.fillRect(1090, y - 3, 170, 6); } ctx.restore(); }
        }
        // 患者“看到”的点阵杯子
        if (persp > 0) {
          const grow = prog(t, tSee, tSee + 2.2, x => x);
          for (const d of CUPDOTS) { const v = d.v * smooth(d.h * .7, d.h * .7 + .3, grow) + .07 * (hash(d.x * 3 + d.y, Math.floor(t * 6)) > .86 ? 1 : 0); if (v <= .02) continue; glow(ctx, IX + d.x, IY + d.y, 12, AMB, persp * iA * v * .5); dot(ctx, IX + d.x, IY + d.y, 2.8, '#ffe3a8', persp * iA * v); }
          const tu = smooth(tTouch, tTouch + .4, t) * (1 - smooth(tTouch + 1.2, tTouch + 2.2, t)); if (tu > 0) { ctx.save(); ctx.globalCompositeOperation = 'lighter'; for (let k = 0; k < 3; k++) { const r = 30 + k * 26 + (t - tTouch) * 60; ctx.strokeStyle = rgba(AMB, .5 * tu * (1 - k * .3)); ctx.lineWidth = 1.4; ctx.beginPath(); ctx.arc(IX + 110, IY - 10, r, 0, TAU); ctx.stroke(); } ctx.restore(); }
        }
        ctx.restore();
        ctx.save(); ctx.globalAlpha = iA; ctx.strokeStyle = 'rgba(220,240,245,.65)'; ctx.lineWidth = 1.5; ctx.beginPath(); ctx.arc(IX, IY, IR, 0, TAU); ctx.stroke(); ctx.restore();
        const lA = iA * (1 - persp);
        label(ctx, '感光细胞已退化', 1500, 640, { alpha: lA * smooth(2, 3, t), dx: 70, dy: 120, size: 26, en: 'photoreceptors lost', color: '#d8d0c8' });
        label(ctx, '神经节细胞 · 植入光敏蛋白', 1200, 656, { alpha: lA * smooth(tExpr + .3, tExpr + 1.1, t), dx: -70, dy: 118, size: 26, en: 'ganglion cells + ChrimsonR', color: '#ffe0a8', lineColor: 'rgba(255,214,140,.8)' });
        // 感知 · 定位 · 触碰
        const st = [['感知', tSee], ['定位', tLoc], ['触碰', tTouch]];
        st.forEach(([w, tw], i) => { const a = aA * smooth(tw - .2, tw + .4, t); text(ctx, w, IX + (i - 1) * 150, IY + IR + 70, { size: 34, font: 'song', weight: 600, color: '#fff1d6', alpha: a, spacing: .2, glow: 12, glowColor: AMB }); if (i < 2) text(ctx, '·', IX + (i - .5) * 150, IY + IR + 70, { size: 34, font: 'song', color: '#d8c8a8', alpha: aA * smooth(st[i + 1][1] - .2, st[i + 1][1] + .4, t) }); });
      }
      const capA = aA * smooth(.8, 1.8, t);
      text(ctx, '2021 · 《自然·医学》 · 部分恢复视觉', W / 2, 160, { size: 30, font: 'song', weight: 500, color: '#f2ead8', alpha: capA * smooth(5.5, 6.5, t), spacing: .15 });
    }
    // —— 研究工具 → 临床：仍在路上 ——
    const aB = smooth(c1 - .5, c1 + .3, t) * (1 - smooth(c2 - .5, c2 + .3, t));
    if (aB > 0) {
      const vx = 960, vy = 430; const tWay = wt(S, 1, '走向临床');
      ctx.save(); ctx.globalCompositeOperation = 'lighter';
      for (let k = 0; k < 44; k++) { const u = k / 44; const z = Math.pow(u, 2.2); for (const sd of [-1, 1]) { const x = lerp(vx + sd * 380, vx + sd * 6, Math.sqrt(u)), y = lerp(850, vy, Math.sqrt(u)); glow(ctx, x, y, lerp(10, 2, u), '#bfe8f0', aB * (1 - u * .7) * .55 * smooth(k / 44 * 2, k / 44 * 2 + .6, t - c1)); } }
      ctx.restore();
      ctx.save(); ctx.globalCompositeOperation = 'lighter';
      for (let r0 = 0; r0 < 14; r0++) { const u = Math.pow(r0 / 14, 1.6); const y = lerp(900, vy + 6, Math.sqrt(u)); const hw = lerp(900, 20, Math.sqrt(u)); for (let k = -6; k <= 6; k++) { const x = vx + k / 6 * hw; glow(ctx, x, y, lerp(5, 1.5, u), '#9fd8e6', aB * .16 * (1 - u * .6) * smooth(r0 / 14 * 2, r0 / 14 * 2 + .8, t - c1)); } }
      ctx.restore();
      glow(ctx, vx, vy, 160, AMB, aB * .18); glow(ctx, vx, vy, 16, '#fff1d6', aB * .5);
      { const mu2 = .42, my2 = lerp(850, vy, mu2); const ma = aB * smooth(c1 + 1.2, c1 + 2, t); ctx.save(); ctx.globalAlpha = ma * .8; ctx.strokeStyle = '#ffd9a0'; ctx.lineWidth = 1.2; ctx.beginPath(); ctx.moveTo(vx + 120, my2); ctx.lineTo(vx + 240, my2 - 40); ctx.lineTo(vx + 400, my2 - 40); ctx.stroke(); ctx.restore(); dot(ctx, vx + 120, my2, 4, '#ffe6b8', ma); glow(ctx, vx + 120, my2, 24, AMB, ma * .6); text(ctx, '2021 · 一位患者部分恢复视觉', vx + 410, my2 - 40, { size: 24, font: 'song', align: 'left', color: '#ffe6c0', alpha: ma }); }
      const mu = .28 + .08 * prog(t, c1, c2, x => x); const my = lerp(850, vy, mu);
      glow(ctx, vx, my, 70, BLUE2, aB * .5); glow(ctx, vx, my, 14, '#ffffff', aB);
      text(ctx, '研究工具', vx, 872, { size: 30, font: 'song', weight: 600, color: '#e6f4ff', alpha: aB * smooth(c1 + .2, c1 + 1, t), spacing: .3 });
      text(ctx, '临床', vx, vy - 44, { size: 30, font: 'song', weight: 600, color: '#ffe8c0', alpha: aB * smooth(tWay, tWay + .8, t), spacing: .3 });
      text(ctx, '仍以研究工具为主 · 临床尚在早期', W / 2, 200, { size: 40, font: 'song', weight: 500, color: '#f6efe2', alpha: aB * smooth(c1 + .3, c1 + 1.3, t), spacing: .15 });
      text(ctx, '截至 2026 年尚无获批的光遗传疗法', W / 2, 262, { size: 24, font: 'song', color: '#b8ccd2', alpha: aB * smooth(c1 + 1.3, c1 + 2.3, t), spacing: .12 });
    }
    // —— 回到池水 ——
    const aC = smooth(c2 - .5, c2 + .5, t);
    if (aC > 0) {
      ctx.save(); ctx.globalAlpha = aC;
      GLFX.layer(ctx, 'pond', { T: t, C1: '#021411', C2: '#0b4036', C3: '#c8ffd8', A: 1, S: 6, SUN: .9, SP: GLFX.uv(1500, -80) }, { mode: 'source-over', alpha: aC });
      ctx.restore();
      motes(ctx, t + 3, .6 * aC, '#c8ffd0');
      const u = prog(t, c2 - .5, S.d + 1, x => x); const px = lerp(620, 1180, u), py = lerp(800, 360, u);
      drawAlga(ctx, px, py, -.9, .55, t, { alpha: aC });
      // 光中浮现的神经丝
      const na = smooth(wt(S, 2, '去读懂'), wt(S, 2, '去读懂') + 2, t) * aC;
      if (na > 0) { drawNeuron(ctx, HERO, 1350, 300, .9, .4, { alpha: na * .35, core: '#e6fff0', halo: '#6fe0b0' }); }
    }
  };

  scenes.end = (ctx, S) => {
    const t = S.t; deep(ctx, t + 200, { neb: .1, seed: 9, motes: .5 });
    field(ctx, t + 200, { alpha: .32 * smooth(-.6, 1, t), speed: 40, spin: .008, spikes: .5 });
    shade(ctx, W / 2, H / 2, 1000, 450, .8);
    endCard(ctx, t, S.d, {
      prize: '2026 年诺贝尔生理学或医学奖', color: ACC,
      zh: '表彰他们“在光门控离子通道\n和光遗传学方面的发现”',
      en: '“for their discoveries concerning light-gated ion channels and optogenetics”',
      who: '获奖者：卡尔·戴塞罗思（Karl Deisseroth）　彼得·黑格曼（Peter Hegemann）　格奥尔格·内格尔（Georg Nagel）',
      src: '资料：诺贝尔奖官方新闻稿与科普资料、Nagel 等 Science 2002 / PNAS 2003、Boyden 等 Nat Neurosci 2005、Sahel 等 Nat Med 2021 · 部分画面为示意 · 配音为合成语音'
    });
  };

  FILM({ id: 'medicine', scenes, accent: ACC, brand: 'NOBEL PRIZE 2026 · MEDICINE', chapters: { spike: [1, '神经的电'], oldtools: [2, '旧工具之困'], alga: [3, '池中绿藻'], channel: [4, '光门控通道'], switch: [5, '光遗传学'], onoff: [6, '开与关'], map: [7, '按下琴键'], clinic: [8, '走向临床'] }, noPush: ['title', 'end'], post: { bloom: .55, vignette: .55, grain: .05 } });
})();
