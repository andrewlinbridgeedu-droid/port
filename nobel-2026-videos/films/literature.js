// 2026 诺贝尔文学奖 ·《与火为邻》——安妮·卡森的残篇与新形
// 纸本、水墨、朱砂。所有静态纹理（宣纸、纸草、墨晕、远山）在 init 中一次性生成，逐帧只做画布运算。
(function () {
  'use strict';
  const { W, H, clamp, lerp, inv, smooth, E, prog, env, rng, hash, glow, dot, text, vtext, rgba, mix, cam, line, partial, fbm, noise3, font, measure } = MP;
  const PAPER = '#efe6d4', INK = '#1a1612', INK2 = '#3a3027', INK3 = '#6e6252', INK4 = '#a39682', RED = '#b8321e', RED2 = '#c8321e', GOLD = '#b08a3e', HONEY = '#c48f2a', UMBER = '#1e140d';
  const GK = '"FreeSerif"'; // 多调希腊文：项目字体缺字，改用系统 FreeSerif
  const mk = (w, h) => { const c = document.createElement('canvas'); c.width = w; c.height = h; return c; };
  const OFF = [mk(W, H), mk(W, H), mk(W, H), mk(W, H)];
  const TEX = {};
  const TAU = Math.PI * 2;

  // ---------- 着色器（只在 init 中运行一次） ----------
  const SH_XUAN = `uniform vec3 C1; uniform float SEED;
float ridge(vec2 p,float s){float n=noise(vec3(p,s));return 1.-abs(n*2.-1.);}
void main(){vec2 p=gl_FragCoord.xy;
 float low=fbm4(vec3(p*.0016,SEED)); float mid=fbm4(vec3(p*.008,SEED+3.)); float hi=noise(vec3(p*.3,SEED+4.));
 float f=0.;
 for(int k=0;k<4;k++){float fk=float(k); vec2 q=rot(p,fk*1.7+.4); q.x*=.22; float r=ridge(q*.05,SEED+10.+fk); f+=pow(r,40.)*(.4+.6*noise(vec3(p*.006,fk+20.)));}
 float lf=0.; for(int k=0;k<2;k++){float fk=float(k); vec2 q=rot(p,fk*2.3+1.1); q.x*=.3; float r=ridge(q*.09,SEED+30.+fk); lf+=pow(r,60.);}
 float grain=h12(p+SEED*17.)-.5;
 vec3 col=C1*(1.+(low-.5)*.09+(mid-.5)*.05+(hi-.5)*.03+grain*.035);
 col=mix(col,col*vec3(.90,.88,.84),clamp(f,0.,1.)*.32);
 col=mix(col,min(col*1.05,vec3(1.)),clamp(lf,0.,1.)*.5);
 vec2 v=gl_FragCoord.xy/R-.5; col*=1.-dot(v*vec2(1.,1.25),v*vec2(1.,1.25))*.20;
 O=vec4(col,1.);}`;

  // 纸草：不规则撕裂多边形 + 两层纤维（上层横纹、下层竖纹，撕口处露出下层）
  const PAPV = [[470, 252], [640, 232], [760, 244], [905, 230], [1080, 210], [1250, 226], [1330, 250], [1452, 300], [1494, 470], [1470, 650], [1430, 790], [1300, 850], [1160, 862], [900, 846], [700, 874], [540, 836], [462, 760], [432, 640], [452, 430]];
  const SH_PAP = `uniform float SEED;
const int N=${PAPV.length};
const vec2 V[N]=vec2[N](${PAPV.map(v => `vec2(${v[0].toFixed(1)},${v[1].toFixed(1)})`).join(',')});
float sdPoly(vec2 p){float d=dot(p-V[0],p-V[0]); float s=1.;
 for(int i=0;i<N;i++){int j=i==0?N-1:i-1; vec2 e=V[j]-V[i]; vec2 w=p-V[i]; vec2 b=w-e*clamp(dot(w,e)/dot(e,e),0.,1.); d=min(d,dot(b,b));
  bvec3 c=bvec3(p.y>=V[i].y,p.y<V[j].y,e.x*w.y>e.y*w.x); if(all(c)||all(not(c))) s*=-1.;}
 return s*sqrt(d);}
void main(){vec2 p=vec2(gl_FragCoord.x,R.y-gl_FragCoord.y)*(1080./R.y);
 float base=-sdPoly(p);
 float big=(fbm4(vec3(p*.0045,SEED))-.5)*70.; float mid=(fbm4(vec3(p*.022,SEED+2.))-.5)*24.;
 float fibH=(noise(vec3(p.x*.012,p.y*.33,SEED+3.))-.5)*14.; float fibV=(noise(vec3(p.x*.33,p.y*.012,SEED+13.))-.5)*12.;
 float s=base+big+mid+fibH;
 float s2=base+big*.9+mid*.6+fibV+16.+(fbm4(vec3(p*.011,SEED+21.))-.5)*30.;
 float top=smoothstep(0.,1.3,s); float bot=smoothstep(0.,1.3,s2);
 float a=max(top,bot*.96);
 float strip=noise(vec3(1.3,p.y*.040,SEED+5.)); float strip2=noise(vec3(p.x*.028,2.1,SEED+6.));
 float fine=noise(vec3(p.x*.005,p.y*.42,SEED+7.)); float fine2=noise(vec3(p.x*.38,p.y*.006,SEED+8.));
 float stain=fbm(vec3(p*.0032,SEED+9.)); float spots=smoothstep(.60,.80,fbm4(vec3(p*.018,SEED+10.)));
 vec3 lc=vec3(.86,.73,.52), dc=vec3(.60,.44,.26);
 vec3 col=mix(lc,dc,clamp(strip*.55+stain*.8-.42,0.,1.));
 col*=.90+.17*fine; col*=.96+.07*fine2; col*=.95+.08*strip2; col*=1.-spots*.13;
 vec3 vcol=mix(vec3(.80,.67,.46),vec3(.66,.50,.31),noise(vec3(p.x*.045,1.,SEED+14.)))*(.9+.16*noise(vec3(p.x*.4,p.y*.005,SEED+15.)));
 col=mix(vcol,col,top);
 float edge=smoothstep(22.,0.,s)*top; col=mix(col,vec3(.45,.30,.16),edge*.55);
 float edge2=smoothstep(14.,0.,s2)*(1.-top); col=mix(col,vec3(.50,.36,.20),edge2*.5);
 col*=1.+(h12(p)-.5)*.08;
 O=vec4(col,a);}`;

  // 墨晕：中心浓、边缘带一圈“水痕”，外缘纤维状渗化
  const SH_BLOT = `uniform float SEED,RAD;
void main(){vec2 u=UV(); float r=length(u); float ang=atan(u.y,u.x);
 float n=fbm(vec3(u*5.,SEED))-.5; float n2=fbm4(vec3(u*22.,SEED+3.))-.5;
 float e=RAD*(1.+n*.6+n2*.12);
 float body=smoothstep(e,e-.02,r);
 float rim=exp(-pow((r-e*.97)/(.012+RAD*.02),2.))*.35;
 float fib=pow(noise(vec3(u*90.,SEED+5.)),3.)*smoothstep(e+.05,e,r)*(1.-body);
 float dens=.70+.30*fbm4(vec3(u*9.,SEED+7.));
 float a=clamp(body*dens+rim*body+fib*.6,0.,1.);
 O=vec4(vec3(1.),a);}`;

  // 水墨远山：层层山脊，向下化入云雾
  const SH_SHAN = `uniform float SEED,BASE,AMP;
void main(){vec2 p=vec2(gl_FragCoord.x,R.y-gl_FragCoord.y)*(1080./R.y);
 float a=0.;
 for(int k=0;k<4;k++){float fk=float(k);
  float h=pow(fbm4(vec3(p.x*(.0021+fk*.0006)+fk*7.3,fk*1.7,SEED)),1.6)*1.6;
  float pk=pow(max(0.,sin(p.x*.0042+fk*2.1+SEED)),3.)*.35;
  float ridge=BASE+fk*58.-(h+pk)*(AMP-fk*50.);
  float d=p.y-ridge;
  float body=smoothstep(-1.5,2.5,d)*exp(-max(d,0.)/(70.+fk*26.));
  float cun=noise(vec3(p.x*.045,p.y*.010,SEED+fk*3.))*.6+noise(vec3(p.x*.012,p.y*.05,SEED+fk*5.))*.4;
  float dens=body*(.45+.75*cun)*(.80-fk*.17);
  a=a+dens*(1.-a);}
 O=vec4(vec3(1.),clamp(a,0.,1.));}`;

  function snap(name, u, scale) { const g = GLFX.draw(name, u, scale); const c = mk(W, H); c.getContext('2d').drawImage(g, 0, 0, W, H); return c; }
  function crop(src, x, y, w, h) { const c = mk(w, h); c.getContext('2d').drawImage(src, x, y, w, h, 0, 0, w, h); return c; }
  function tint(src, color) { const c = mk(src.width, src.height); const g = c.getContext('2d'); g.drawImage(src, 0, 0); g.globalCompositeOperation = 'source-in'; g.fillStyle = color; g.fillRect(0, 0, c.width, c.height); return c; }

  // ---------- 通用部件 ----------
  // 估算第 k 句中某个词被念到的时刻（按字数比例）
  function at(S, k, sub, after = 0) { const L = S.film.scenes[S.i].lines[k]; if (!L) return 0; const i = L.text.indexOf(sub); const n = [...L.text].length; const idx = i < 0 ? 0 : [...L.text.slice(0, i)].length + after; return S.cue(k) + (S.cend(k) - S.cue(k)) * idx / n; }
  function paper(ctx) { ctx.drawImage(TEX.paper, 0, 0); }
  // 纸面上缓缓浮动的微尘
  function motes(ctx, t, a = 1, o = {}) {
    if (a <= 0) return; const n = o.n || 50; ctx.save(); ctx.fillStyle = o.color || '#7a5a36';
    for (let i = 0; i < n; i++) {
      const x = ((hash(i, 31) * W + t * (6 + 12 * hash(i, 32)) + 30 * Math.sin(t * .27 + i)) % W + W) % W;
      const y = ((hash(i, 33) * H - t * (3 + 8 * hash(i, 34)) + 20 * Math.sin(t * .2 + i * 2)) % H + H) % H;
      ctx.globalAlpha = a * (.06 + .16 * hash(i, 36)) * (.6 + .4 * Math.sin(t * 1.1 + i));
      ctx.beginPath(); ctx.arc(x, y, .6 + 1.6 * hash(i, 35) ** 2, 0, TAU); ctx.fill();
    }
    ctx.restore();
  }
  // 方括号：side=-1 为“[”，+1 为“]”；u 为描画进度（从中点向两端）
  function bracket(ctx, x, y, h, side, u = 1, o = {}) {
    if (u <= 0 || (o.alpha ?? 1) <= 0) return; const arm = o.arm ?? h * .24; const xa = x - side * arm;
    ctx.save(); ctx.globalAlpha = o.alpha ?? 1; ctx.strokeStyle = o.color || RED; ctx.lineWidth = o.w ?? Math.max(1.5, h * .05); ctx.lineCap = 'butt'; ctx.lineJoin = 'miter';
    for (const s of [-1, 1]) { const q = partial([[x, y], [x, y + s * h / 2], [xa, y + s * h / 2]], u); ctx.beginPath(); ctx.moveTo(q[0][0], q[0][1]); for (let i = 1; i < q.length; i++) ctx.lineTo(q[i][0], q[i][1]); ctx.stroke(); }
    ctx.restore();
  }
  // 博物馆式说明牌：朱砂小方 + 中文 + 字距拉开的英文小字
  function tag(ctx, zh, en, x, y, o = {}) {
    const a = o.alpha ?? 1; if (a <= .01) return; const al = o.align || 'left'; const size = o.size || 26;
    const rv = o.reveal ?? clamp(a * 1.4);
    if (o.mark !== false) { ctx.save(); ctx.globalAlpha = a; ctx.fillStyle = o.accent || RED; const mx = al === 'left' ? x - 22 : al === 'right' ? x + 14 : x - 4; if (al !== 'center') ctx.fillRect(mx, y - size * .22, 8, 8); ctx.restore(); }
    text(ctx, zh, x, y, { size, font: 'song', weight: o.weight || 500, color: o.color || INK2, alpha: a, align: al, spacing: o.spacing ?? .12, reveal: rv });
    if (en) text(ctx, o.raw ? en : en.toUpperCase(), x, y + size * 1.02, { size: o.enSize || Math.max(14, size * .52), font: o.enFont || 'latin', weight: 600, color: o.enColor || INK3, alpha: a * .9, spacing: o.enSpacing ?? .26, align: al, reveal: rv });
  }
  // 两端渐细的笔触
  function stroke(ctx, pts, w, color, a = 1, o = {}) {
    const n = pts.length; if (n < 2 || a <= 0) return; const L = [], R = [];
    for (let i = 0; i < n; i++) {
      const q = pts[Math.min(n - 1, i + 1)], r = pts[Math.max(0, i - 1)]; let dx = q[0] - r[0], dy = q[1] - r[1]; const m = Math.hypot(dx, dy) || 1; dx /= m; dy /= m;
      const u = i / (n - 1); const ww = (o.wfn ? o.wfn(u) : w * Math.pow(Math.sin(Math.PI * clamp(u * .94 + .03)), o.taper ?? .6)) / 2;
      L.push([pts[i][0] - dy * ww, pts[i][1] + dx * ww]); R.push([pts[i][0] + dy * ww, pts[i][1] - dx * ww]);
    }
    ctx.save(); ctx.globalAlpha = clamp(a); ctx.fillStyle = color; ctx.beginPath(); ctx.moveTo(L[0][0], L[0][1]);
    for (let i = 1; i < n; i++) ctx.lineTo(L[i][0], L[i][1]); for (let i = n - 1; i >= 0; i--) ctx.lineTo(R[i][0], R[i][1]); ctx.closePath(); ctx.fill(); ctx.restore();
  }
  function qpts(x0, y0, cx, cy, x1, y1, n = 24) { const o = []; for (let i = 0; i <= n; i++) { const u = i / n; o.push([(1 - u) * (1 - u) * x0 + 2 * (1 - u) * u * cx + u * u * x1, (1 - u) * (1 - u) * y0 + 2 * (1 - u) * u * cy + u * u * y1]); } return o; }
  // 不规则的“破洞”轮廓：g 为生长参数，让轮廓随扩张而变化
  function blobPath(ctx, x, y, rx, ry, seed, g = 0, n = 140, jag = 1) {
    ctx.beginPath();
    for (let i = 0; i <= n; i++) {
      const a = i / n * TAU, c = Math.cos(a), s = Math.sin(a);
      const r = 1 + .30 * fbm(c * 1.2 + seed, s * 1.2 + seed * .3, g * .6 + seed, 3) + .07 * jag * noise3(c * 7 + seed, s * 7, g + seed * 2) + .035 * jag * noise3(c * 23, s * 23 + seed, seed);
      const px = x + c * rx * r, py = y + s * ry * r; i ? ctx.lineTo(px, py) : ctx.moveTo(px, py);
    }
    ctx.closePath();
  }
  // 墨晕（静态纹理按比例放大，模拟在宣纸上洇开）
  function blot(ctx, k, x, y, r, a, o = {}) { if (a <= 0 || r <= 1) return; const B = (o.color ? TEX.blotC[k % 4][o.color] || (TEX.blotC[k % 4][o.color] = tint(TEX.blot[k % 4], o.color)) : TEX.blotInk[k % 4]); ctx.save(); ctx.globalAlpha = clamp(a); if (o.mode) ctx.globalCompositeOperation = o.mode; ctx.translate(x, y); ctx.rotate(o.rot ?? k * 1.3); ctx.drawImage(B, -r, -r, r * 2, r * 2); ctx.restore(); }
  // 火星：从一条横带中升起
  function embers(ctx, t, o) {
    const n = o.n || 40, a0 = o.alpha ?? 1; if (a0 <= 0) return; ctx.save(); if (o.dark) ctx.globalCompositeOperation = 'lighter';
    for (let i = 0; i < n; i++) {
      const sd = (o.seed || 0) * 97 + i; const life = (o.life || 3.2) * (.7 + .6 * hash(sd, 41)); const u = ((t + hash(sd, 42) * life) % life) / life;
      const x = lerp(o.x0, o.x1, hash(sd, 43)) + (o.sway ?? 40) * Math.sin(t * (.7 + hash(sd, 44)) + i) * u + (o.wind || 0) * u;
      const y = (o.ys ? lerp(o.y0, o.ys, hash(sd, 47)) : o.y0) - u * (o.rise || 420) * (.55 + .45 * hash(sd, 45));
      const fl = .6 + .4 * Math.sin(t * 11 + i * 2.7); const al = a0 * Math.pow(Math.sin(Math.PI * Math.min(1, u * 1.15)), .7) * fl;
      const r = (o.size || 2.2) * (.5 + hash(sd, 46)) * (1 - u * .55);
      if (o.dark) { glow(ctx, x, y, r * 7, '#ff8a3a', al * .55); dot(ctx, x, y, r, u < .35 ? '#fff0c0' : '#ffb05a', al); }
      else { glow(ctx, x, y, r * 5, RED2, al * .16); dot(ctx, x, y, r, u < .3 ? '#e0662a' : RED2, al * .9); }
    }
    ctx.restore();
  }
  // 朱文/白文印章（静态预渲染）
  function makeSeal(chars, w, h, o = {}) {
    const c = mk(w + 20, h + 20), g = c.getContext('2d'); const r = rng(o.seed || 7); g.translate(10, 10);
    g.fillStyle = RED2; g.beginPath(); const pts = [];
    const side = (x0, y0, x1, y1, n) => { for (let i = 0; i < n; i++) { const u = i / n; pts.push([lerp(x0, x1, u) + (r() - .5) * 2.2, lerp(y0, y1, u) + (r() - .5) * 2.2]); } };
    const rr = 5; side(rr, 0, w - rr, 0, 14); side(w, rr, w, h - rr, 14); side(w - rr, h, rr, h, 14); side(0, h - rr, 0, rr, 14);
    pts.forEach((p, i) => i ? g.lineTo(p[0], p[1]) : g.moveTo(p[0], p[1])); g.closePath(); g.fill();
    g.globalCompositeOperation = 'destination-out'; g.fillStyle = '#000'; g.textAlign = 'center'; g.textBaseline = 'middle';
    const cols = o.cols || 1, rows = Math.ceil(chars.length / cols); const cw = (w - 16) / cols, ch = (h - 16) / rows; const fs = Math.min(cw, ch) * (o.fs || .86);
    g.font = font(o.font || 'song', fs, o.weight || 900);
    [...chars].forEach((s, i) => { const col = cols - 1 - Math.floor(i / rows), row = i % rows; g.fillText(s, 8 + cw * (col + .5), 8 + ch * (row + .5) + fs * .03); });
    for (let i = 0; i < 90; i++) { g.globalAlpha = .25 + r() * .7; g.beginPath(); g.arc(r() * w, r() * h, .4 + r() * r() * 2.2, 0, TAU); g.fill(); }
    g.globalAlpha = .55; for (let i = 0; i < 6; i++) { g.beginPath(); g.ellipse(r() * w, r() * h, 3 + r() * 9, 1 + r() * 3, r() * 3, 0, TAU); g.fill(); }
    return c;
  }
  function drawSeal(ctx, S, x, y, a, k = 1, rot = -.04) { if (a <= 0) return; ctx.save(); ctx.globalAlpha = clamp(a); ctx.globalCompositeOperation = 'multiply'; ctx.translate(x, y); ctx.rotate(rot); ctx.scale(k, k); ctx.drawImage(S, -S.width / 2, -S.height / 2); ctx.restore(); }

  // ---------- 1. 纸草残片：萨福残篇 130（古抄本式大写连写、月形 sigma） ----------
  const PAP = { cx: 960, cy: 540, hw: 530, hh: 330, seed: 4.2 };
  const GLINES = ['ΕΡΟϹΔΗΥΤΕΜΟΛΥϹΙ', 'ΜΕΛΗϹΔΟΝΕΙ', 'ΓΛΥΚΥΠΙΚΡΟΝΑΜΑ', 'ΧΑΝΟΝΟΡΠΕΤΟΝ'];
  const GADV = 55, GX0 = 572, GY0 = 400, GLH = 92, GSIZE = 60;
  const LETTERS = []; GLINES.forEach((s, li) => [...s].forEach((ch, i) => { const k = LETTERS.length; LETTERS.push({ ch, li, i, k, x: GX0 + i * GADV + (hash(k, 3) - .5) * 6, y: GY0 + li * GLH + (hash(k, 4) - .5) * 5, rot: (hash(k, 5) - .5) * .08, s: .93 + hash(k, 6) * .12, a: .70 + hash(k, 7) * .26 }); }));
  // 缺口（前四个对应方括号）
  const HOLES = [
    { x: GX0 + 5.6 * GADV, y: GY0 - 4, rx: 82, ry: 46, g: .38, seed: 1.3 },
    { x: GX0 + 1.4 * GADV, y: GY0 + GLH, rx: 70, ry: 42, g: .36, seed: 2.9 },
    { x: GX0 + 12.9 * GADV, y: GY0 + 2 * GLH + 4, rx: 104, ry: 48, g: .32, seed: 4.4 },
    { x: GX0 + 4.4 * GADV, y: GY0 + 3 * GLH, rx: 82, ry: 44, g: .34, seed: 6.1 },
    { x: 1330, y: 296, rx: 30, ry: 20, g: .6, seed: 7.7 }, { x: 540, y: 772, rx: 36, ry: 22, g: .5, seed: 8.8 }, { x: 1170, y: 784, rx: 22, ry: 15, g: .7, seed: 9.9 }, { x: 1440, y: 640, rx: 18, ry: 26, g: .5, seed: 11.1 }
  ];
  // 残行的墨迹痕（无法辨读的残笔）
  const TRACES = (() => { const r = rng(61); const a = []; for (const y of [306, 768]) for (let i = 0; i < 16; i++) { const x = GX0 - 10 + i * GADV + (r() - .5) * 10; if (r() < .35) continue; const kind = Math.floor(r() * 4); a.push({ x, y: y + (r() - .5) * 8, kind, s: .7 + r() * .5, rot: (r() - .5) * .6, a: .35 + r() * .5 }); } return a; })();
  const CHIPS = (() => { const r = rng(91); const a = []; for (let i = 0; i < 70; i++) { const h = Math.floor(r() * 4); a.push({ h, ang: r() * TAU, ts: 5.6 + r() * 5.8, dur: 1.8 + r() * 1.6, sz: 3 + r() * 7, rot: r() * 6, vr: (r() - .5) * 6, dx: (r() - .5) * 60, sh: r() }); } return a; })();

  // 漂浮诗行（萨福残篇 130 的意译，缺处即方括号）
  const POEM = [['爱欲', '摇撼我'], [null, null], ['甜苦', null], [null, '潜入']];
  function drawTrace(g, tr) {
    g.save(); g.translate(tr.x, tr.y); g.rotate(tr.rot); g.scale(tr.s, tr.s); g.strokeStyle = 'rgba(42,26,14,1)'; g.globalAlpha = tr.a; g.lineWidth = 4.5; g.lineCap = 'round'; g.beginPath();
    if (tr.kind === 0) { g.moveTo(-14, -18); g.lineTo(-14, 18); } else if (tr.kind === 1) { g.arc(0, 0, 17, .6, 2.6); } else if (tr.kind === 2) { g.moveTo(-16, 16); g.lineTo(0, -18); g.lineTo(14, 16); } else { g.moveTo(-15, -14); g.lineTo(15, -14); g.moveTo(0, -14); g.lineTo(0, 18); }
    g.stroke(); g.restore();
  }
  // 纸草：贴图 + 墨字 + 逐步扩大的破洞，合成到 OFF[0]（设计坐标 1920×1080）
  function composePapyrus(t, o) {
    const F = OFF[0], g = F.getContext('2d'); g.setTransform(1, 0, 0, 1, 0, 0); g.globalCompositeOperation = 'source-over'; g.globalAlpha = 1; g.clearRect(0, 0, W, H);
    g.drawImage(TEX.pap, 0, 0);
    g.globalCompositeOperation = 'source-atop';
    // 墨字
    g.font = font(GK, GSIZE, 400); g.textAlign = 'center'; g.textBaseline = 'middle';
    for (const L of LETTERS) {
      const ap = o.write ? o.write(L) : 1; if (ap <= 0) continue;
      g.save(); g.translate(L.x, L.y); g.rotate(L.rot); g.scale(L.s, L.s * 1.04); g.globalAlpha = L.a * ap * (o.letterAlpha ?? 1);
      g.fillStyle = o.letterColor ? o.letterColor(L) : '#2b1a0e'; g.shadowColor = 'rgba(43,26,14,.55)'; g.shadowBlur = 2.5; g.fillText(L.ch, 0, 0); g.restore();
    }
    for (const tr of TRACES) drawTrace(g, tr);
    // 破洞：先压暗边缘，再挖空
    const er = o.erode ?? 0;
    g.save(); g.filter = 'blur(5px)'; g.fillStyle = 'rgba(70,42,20,.55)';
    HOLES.forEach(h => { const k = 1 + h.g * er; blobPath(g, h.x, h.y, h.rx * k * 1.12 + 6, h.ry * k * 1.12 + 6, h.seed, er); g.fill(); });
    g.restore();
    g.globalCompositeOperation = 'destination-out'; g.fillStyle = '#000';
    HOLES.forEach(h => { const k = 1 + h.g * er; blobPath(g, h.x, h.y, h.rx * k, h.ry * k, h.seed, er); g.fill(); });
    if (o.burn) o.burn(g);
    g.globalCompositeOperation = 'source-over';
    return F;
  }
  // 投影（同样挖出破洞，边缘柔化）
  function papShadow(er, dx = 12, dy = 24) {
    const c = OFF[2], g = c.getContext('2d'); g.setTransform(1, 0, 0, 1, 0, 0); g.globalCompositeOperation = 'source-over'; g.globalAlpha = 1; g.filter = 'none'; g.clearRect(0, 0, W, H);
    g.drawImage(TEX.papShadow, dx, dy); g.globalCompositeOperation = 'destination-out'; g.filter = 'blur(9px)'; g.fillStyle = '#000';
    HOLES.forEach(h => { const k = 1 + h.g * er; blobPath(g, h.x + dx, h.y + dy, h.rx * k * .92, h.ry * k * .9, h.seed, er, 60, .5); g.fill(); });
    g.filter = 'none'; g.globalCompositeOperation = 'source-over'; return c;
  }
  function holeR(h, er) { return { rx: h.rx * (1 + h.g * er), ry: h.ry * (1 + h.g * er) }; }

  const scenes = {};

  scenes.fragment = (ctx, S) => {
    const t = S.t, c1 = S.cue(1);
    paper(ctx); motes(ctx, t, .8);
    const intro = E.out(smooth(0, 8, t));
    const tLift = c1 + 4.2, tLift2 = c1 + 6.6;
    const shift = E.inOut(prog(t, tLift - .2, tLift2, x => x));
    const fs = lerp(1.16, .98, intro) * lerp(1, .74, shift);
    const fx = lerp(960, 610, shift), fy = lerp(500, 470, intro) + 0 * shift, frot = lerp(-.05, -.025, intro);
    const fa = smooth(.2, 2.4, t);
    const er = E.inOut(prog(t, 5.6, 11.2, x => x));
    const F = composePapyrus(t, { erode: er, write: L => smooth(1.2 + L.k * .055, 1.5 + L.k * .055, t) });
    const M = (x, y) => { const dx = (x - 960) * fs, dy = (y - 540) * fs; const c = Math.cos(frot), s = Math.sin(frot); return [fx + dx * c - dy * s, fy + dx * s + dy * c]; };
    // 投影 + 残片
    ctx.save(); ctx.translate(fx, fy); ctx.rotate(frot); ctx.scale(fs, fs); ctx.translate(-960, -540);
    ctx.globalAlpha = fa * .5; ctx.drawImage(papShadow(er), 0, 0);
    ctx.globalAlpha = fa; ctx.drawImage(F, 0, 0);
    // 碎屑
    for (const c of CHIPS) {
      const u = (t - c.ts) / c.dur; if (u <= 0 || u >= 1) continue; const h = HOLES[c.h]; const rr = holeR(h, prog(c.ts, 5.6, 11.2, E.inOut));
      const x0 = h.x + Math.cos(c.ang) * rr.rx, y0 = h.y + Math.sin(c.ang) * rr.ry;
      const x = x0 + c.dx * u, y = y0 + 260 * u * u + 20 * u;
      ctx.save(); ctx.translate(x, y); ctx.rotate(c.rot + c.vr * u); ctx.globalAlpha = fa * (1 - u) * .9; ctx.fillStyle = c.sh > .5 ? '#a8844f' : '#8a6a3c';
      ctx.beginPath(); ctx.moveTo(-c.sz, -c.sz * .4); ctx.lineTo(c.sz * .7, -c.sz * .6); ctx.lineTo(c.sz, c.sz * .3); ctx.lineTo(-c.sz * .4, c.sz * .5); ctx.closePath(); ctx.fill(); ctx.restore();
    }
    ctx.restore();
    // 说明牌
    const ta = smooth(3, 4.4, t) * (1 - smooth(tLift - .4, tLift + .4, t));
    const tp = M(PAP.cx - 420, PAP.cy + 352);
    tag(ctx, '萨福 · 残篇 130', 'Sappho · fragment 130', tp[0], tp[1], { alpha: ta, size: 24 });
    // 方括号：在缺口中“开”出来，然后离开纸草，漂进留白
    const targets = [[1345, 330, 150], [1300, 455, 260], [1420, 580, 110], [1400, 705, 200]];
    for (let k = 0; k < 4; k++) {
      const h = HOLES[k]; const rr = holeR(h, 1);
      const tb = c1 + .7 + k * .55; const bu = E.out(prog(t, tb, tb + .7, x => x));
      if (bu <= 0) continue;
      const lu = E.inOut(prog(t, tLift + k * .3, tLift2 + k * .3, x => x));
      const p0 = M(h.x, h.y); const gap0 = (rr.rx * .95) * fs, h0 = 82 * fs;
      const tg = targets[k]; const bob = Math.sin(t * 1.1 + k * 1.7) * 5 * lu;
      const arc = Math.sin(Math.PI * lu) * -70;
      const cx = lerp(p0[0], tg[0], lu), cy = lerp(p0[1], tg[1], lu) + arc + bob;
      const gap = lerp(gap0, tg[2] / 2, lu), hh = lerp(h0, 76, lu), rot = lerp(frot, (hash(k, 9) - .5) * .05, lu);
      // 漂进留白之后，括号旁浮出淡淡的诗行：空白也是诗的一部分
      const wa = smooth(tLift2 + .2 + k * .35, tLift2 + 1.4 + k * .35, t) * .9;
      if (wa > 0 && POEM[k]) { const [l, r] = POEM[k]; if (l) text(ctx, l, cx - gap - 26, cy, { size: 36, font: 'song', weight: 300, color: INK2, alpha: wa, align: 'right', spacing: .18 }); if (r) text(ctx, r, cx + gap + 26, cy, { size: 36, font: 'song', weight: 300, color: INK2, alpha: wa, align: 'left', spacing: .18 }); }
      ctx.save(); ctx.translate(cx, cy); ctx.rotate(rot);
      if (lu > 0) { ctx.save(); ctx.globalAlpha = .22 * lu; ctx.fillStyle = 'rgba(90,40,20,1)'; ctx.filter = 'blur(6px)'; ctx.fillRect(-gap - 4, -hh / 2 + 14, 8, hh); ctx.fillRect(gap - 4, -hh / 2 + 14, 8, hh); ctx.restore(); }
      bracket(ctx, -gap, 0, hh, -1, bu, { w: lerp(4.4 * fs, 4.2, lu) });
      bracket(ctx, gap, 0, hh, 1, bu, { w: lerp(4.4 * fs, 4.2, lu) });
      ctx.restore();
    }
  };

  // ---------- 2. 片名 ----------
  scenes.title = (ctx, S) => {
    const t = S.t, d = S.d;
    paper(ctx); motes(ctx, t + 30, .8);
    const T = TEX.title; const out = 1 - smooth(d - .25, d + .5, t);
    // 洇开的墨：每个字从中心向外晕染出来
    const F = OFF[1], g = F.getContext('2d'); g.setTransform(1, 0, 0, 1, 0, 0); g.globalCompositeOperation = 'source-over'; g.globalAlpha = 1; g.clearRect(0, 0, W, H);
    const Mk = OFF[2], mg = Mk.getContext('2d'); mg.setTransform(1, 0, 0, 1, 0, 0); mg.globalCompositeOperation = 'source-over'; mg.globalAlpha = 1; mg.clearRect(0, 0, W, H);
    T.cx.forEach((x, i) => { const u = E.out(prog(t, .25 + i * .3, 2.2 + i * .3, x => x)); blot(mg, i, x, T.y, 30 + 200 * u, 1, { rot: i * 2.1 }); });
    g.drawImage(T.canvas, 0, 0); g.globalCompositeOperation = 'destination-in'; g.drawImage(Mk, 0, 0); g.globalCompositeOperation = 'source-over';
    // 水痕
    T.cx.forEach((x, i) => { const u = E.out(prog(t, .25 + i * .3, 2.6 + i * .3, x => x)); blot(ctx, i + 1, x, T.y + 6, 40 + 230 * u, .07 * (1 - .6 * smooth(2.5, 5, t)) * u, { rot: i * 1.4 + 2, color: '#5a4a38', mode: 'multiply' }); });
    ctx.drawImage(F, 0, 0);
    text(ctx, '2026 诺贝尔文学奖', W / 2, 300, { size: 30, font: 'song', weight: 500, spacing: .62, color: INK2, alpha: smooth(.1, 1.2, t), reveal: prog(t, .1, 1.4, E.out) });
    // 细金线
    const lw = 260 * E.out(prog(t, .4, 2.2, x => x)); ctx.save(); ctx.strokeStyle = rgba(GOLD, .8); ctx.lineWidth = 1.2; ctx.beginPath(); ctx.moveTo(W / 2 - lw, 350); ctx.lineTo(W / 2 + lw, 350); ctx.stroke(); ctx.restore();
    // 副题与方括号
    const sa = smooth(1.6, 2.8, t);
    const sw = measure(ctx, '安妮·卡森的残篇与新形', 'song', 38, 400) + 38 * .3 * 10;
    text(ctx, '安妮·卡森的残篇与新形', W / 2, 705, { size: 38, font: 'song', weight: 400, spacing: .3, color: INK2, alpha: sa, reveal: prog(t, 1.6, 3.0, E.out) });
    const bu = E.out(prog(t, 2.0, 2.8, x => x));
    bracket(ctx, W / 2 - sw / 2 - 48, 705, 58, -1, bu, { w: 3 }); bracket(ctx, W / 2 + sw / 2 + 36, 705, 58, 1, bu, { w: 3 });
    // 印章：落下
    const su = prog(t, 2.6, 3.0, x => x); const k = lerp(1.35, 1, E.out(su));
    drawSeal(ctx, TEX.sealName, T.x1 + 70, T.y + 70, smooth(2.6, 2.75, t) * .92, k, -.05);
    if (out < 1) { ctx.save(); ctx.globalAlpha = 1 - out; paper(ctx); ctx.restore(); }
  };

  // 其余场景暂留
  for (const k of ['citation', 'eros', 'red', 'brackets', 'nox', 'forms', 'close', 'end']) scenes[k] = (ctx, S) => { paper(ctx); text(ctx, k, W / 2, H / 2, { size: 80, color: INK }); };

  async function init() {
    GLFX.define('xuan', SH_XUAN); GLFX.define('papyrus', SH_PAP); GLFX.define('blot', SH_BLOT); GLFX.define('shan', SH_SHAN);
    TEX.paper = snap('xuan', { C1: PAPER, SEED: 3.7 }, 1);
    TEX.pap = snap('papyrus', { SEED: PAP.seed }, 1);
    { const c = mk(W, H), g = c.getContext('2d'); g.filter = 'blur(16px)'; g.drawImage(tint(TEX.pap, '#4a2e14'), 0, 0); TEX.papShadow = c; }
    TEX.blot = []; TEX.blotInk = []; TEX.blotC = [];
    for (let k = 0; k < 4; k++) { const g = GLFX.draw('blot', { SEED: 1.7 + k * 3.1, RAD: .36 }, .5); const c = mk(512, 512); c.getContext('2d').drawImage(g, (g.width - g.height) / 2, 0, g.height, g.height, 0, 0, 512, 512); TEX.blot.push(c); TEX.blotInk.push(tint(c, INK)); TEX.blotC.push({}); }
    TEX.mount = snap('shan', { SEED: 2.3, BASE: 560, AMP: 260 }, .75);
    // 片名
    {
      const c = mk(W, H), g = c.getContext('2d'); const chars = [...'与火为邻']; const size = 236; g.font = font('brush', size, 400); g.textAlign = 'center'; g.textBaseline = 'middle';
      const ws = chars.map(ch => g.measureText(ch).width); const gap = size * .16; const total = ws.reduce((a, b) => a + b, 0) + gap * 3; let x = W / 2 - total / 2; const cx = []; const y = 512;
      chars.forEach((ch, i) => { const xc = x + ws[i] / 2; cx.push(xc); x += ws[i] + gap; });
      g.save(); g.filter = 'blur(3px)'; g.globalAlpha = .35; g.fillStyle = INK; chars.forEach((ch, i) => g.fillText(ch, cx[i], y + (i % 2 ? 6 : -4))); g.restore();
      g.fillStyle = INK; chars.forEach((ch, i) => { g.save(); g.translate(cx[i], y + (i % 2 ? 6 : -4)); g.rotate((i % 2 ? .02 : -.015)); g.fillText(ch, 0, 0); g.restore(); });
      TEX.title = { canvas: c, cx, y, x1: W / 2 + total / 2 };
    }
    TEX.sealName = makeSeal('卡森', 64, 118, { cols: 1, seed: 5 });
    TEX.sealFire = makeSeal('与火为邻', 104, 104, { cols: 2, seed: 9 });
  }

  FILM({ id: 'literature', scenes, init, accent: '#b8321e', chapterText: '#2a241c', brand: 'NOBEL PRIZE 2026 · LITERATURE', subStyle: { theme: 'paper' }, chapters: { citation: [1, '颁奖词'], eros: [2, '甜苦'], red: [3, '红的自传'], brackets: [4, '方括号'], nox: [5, '夜'], forms: [6, '新的形式'], close: [7, '与火为邻'] }, noPush: ['title', 'end'], post: { bloom: 0, vignette: .28, vignetteColor: '#3a2814', grain: .06 } });
})();
