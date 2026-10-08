// 2026 诺贝尔文学奖 ·《与火为邻》——安妮·卡森的残篇与新形
// 纸本、水墨、朱砂。所有静态纹理（宣纸、纸草、墨晕、远山）在 init 中一次性生成，逐帧只做画布运算。
(function () {
  'use strict';
  const { W, H, clamp, lerp, inv, smooth, E, prog, env, rng, hash, glow, dot, text, vtext, rgba, mix, cam, line, partial, fbm, noise3, font, measure } = MP;
  const PAPER = '#efe6d4', INK = '#1a1612', INK2 = '#3a3027', INK3 = '#6e6252', INK4 = '#a39682', RED = '#b8321e', RED2 = '#c8321e', GOLD = '#b08a3e', HONEY = '#c48f2a', UMBER = '#1e140d';
  const GK = '"GFS Didot", "FreeSerif"'; // 多调希腊文：GFS Didot（开源，支持多调符号；月形 sigma 以形同的 C 代替）
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
  const PAPV = [[486, 262], [640, 236], [770, 248], [905, 232], [1040, 214], [1110, 268], [1190, 282], [1250, 236], [1340, 252], [1452, 316], [1496, 470], [1474, 640], [1440, 742], [1380, 792], [1300, 852], [1160, 866], [1010, 838], [900, 850], [700, 878], [600, 858], [520, 800], [470, 742], [436, 640], [452, 520], [440, 430]];
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
 float fibH=(noise(vec3(p.x*.02,p.y*.30,SEED+3.))-.5)*7.; float fibV=(noise(vec3(p.x*.33,p.y*.012,SEED+13.))-.5)*12.;
 float s=base+big+mid+fibH;
 float s2=base+big*.9+mid*.6+fibV+16.+(fbm4(vec3(p*.011,SEED+21.))-.5)*30.;
 float top=smoothstep(0.,1.3,s); float bot=smoothstep(0.,1.3,s2);
 float a=max(top,bot*.96);
 float strip=noise(vec3(1.3,p.y*.040,SEED+5.)); float strip2=noise(vec3(p.x*.028,2.1,SEED+6.));
 float fine=noise(vec3(p.x*.005,p.y*.42,SEED+7.)); float fine2=noise(vec3(p.x*.38,p.y*.006,SEED+8.));
 float stain=fbm(vec3(p*.0032,SEED+9.)); float spots=smoothstep(.60,.80,fbm4(vec3(p*.018,SEED+10.)));
 vec3 lc=vec3(.85,.74,.55), dc=vec3(.58,.44,.28);
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
  function blobR(a, seed, g, jag) { const c = Math.cos(a), s = Math.sin(a); return 1 + .30 * fbm(c * 1.2 + seed, s * 1.2 + seed * .3, g * .6 + seed, 3) + .06 * jag * noise3(c * 5 + seed, s * 5, g + seed * 2) + .05 * jag * Math.abs(c) * noise3(c * 3, s * 34 + seed, seed) + .012 * jag * noise3(c * 30, s * 30 + seed, seed); }
  function blobPath(ctx, x, y, rx, ry, seed, g = 0, n = 140, jag = 1) {
    ctx.beginPath();
    for (let i = 0; i <= n; i++) { const a = i / n * TAU; const r = blobR(a, seed, g, jag); const px = x + Math.cos(a) * rx * r, py = y + Math.sin(a) * ry * r; i ? ctx.lineTo(px, py) : ctx.moveTo(px, py); }
    ctx.closePath();
  }
  // 柔边绘制：用阴影偏移实现真正的高斯模糊（Chromium 的 filter: blur 在大半径时会出现块状）
  function soft(g, r, color, fn) { const m = g.getTransform(); const sc = Math.hypot(m.a, m.b) || 1; const dx = 12000 / sc; g.save(); g.translate(dx, 0); g.shadowColor = color; g.shadowBlur = r * 2; g.shadowOffsetX = -m.a * dx; g.shadowOffsetY = -m.b * dx; g.fillStyle = '#000'; g.strokeStyle = '#000'; fn(g); g.restore(); }
  function inPoly(x, y, P) { let c = false; for (let i = 0, j = P.length - 1; i < P.length; j = i++) { if ((P[i][1] > y) !== (P[j][1] > y) && x < (P[j][0] - P[i][0]) * (y - P[i][1]) / (P[j][1] - P[i][1]) + P[i][0]) c = !c; } return c; }
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
  const GLINES = ['ΕΡΟCΔΗΥΤΕΜΟΛΥCΙ', 'ΜΕΛΗCΔΟΝΕΙ', 'ΓΛΥΚΥΠΙΚΡΟΝΑΜΑ', 'ΧΑΝΟΝΟΡΠΕΤΟΝ'];
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
  const TRACES = (() => { const r = rng(61); const a = []; const al = 'ΑΒΓΔΕΗΘΙΚΛΜΝΞΟΠΡCΤΥΦΧΩ'; for (const [y, top] of [[312, false], [768, true]]) for (let i = 0; i < 15; i++) { if (r() < .3) continue; a.push({ x: GX0 + i * GADV + (r() - .5) * 8, y: y + (r() - .5) * 6, ch: al[Math.floor(r() * al.length)], top, cut: .25 + r() * .35, a: .45 + r() * .4 }); } return a; })();
  const CHIPS = (() => { const r = rng(91); const a = []; for (let i = 0; i < 70; i++) { const h = Math.floor(r() * 4); a.push({ h, ang: r() * TAU, ts: 5.6 + r() * 5.8, dur: 1.8 + r() * 1.6, sz: 3 + r() * 7, rot: r() * 6, vr: (r() - .5) * 6, dx: (r() - .5) * 60, sh: r() }); } return a; })();

  // 漂浮诗行（萨福残篇 130 的意译，缺处即方括号）
  const POEM = [['爱欲', '摇撼我'], [null, null], ['甜苦', null], [null, '潜入']];
  // 残行：只剩半个字（上一行只留下字脚，下一行只留下字头）
  function drawTrace(g, tr) {
    g.save(); g.beginPath(); const hh = GSIZE * .75; if (tr.top) g.rect(tr.x - 40, tr.y - hh, 80, hh * (1 - tr.cut) ); else g.rect(tr.x - 40, tr.y - hh + hh * 2 * tr.cut, 80, hh * 2); g.clip();
    g.globalAlpha = tr.a; g.fillStyle = '#2b1a0e'; g.font = font(GK, GSIZE, 400); g.textAlign = 'center'; g.textBaseline = 'middle'; g.fillText(tr.ch, tr.x, tr.y); g.restore();
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
    const tw = o.traceAlpha ?? 1; if (tw > 0) for (const tr of TRACES) { g.save(); g.globalAlpha = tw; drawTrace(g, tr); g.restore(); }
    // 破洞：先压暗边缘，再挖空
    const er = o.erode ?? 0;
    soft(g, 6, o.rim || 'rgba(88,58,30,.36)', g => HOLES.forEach(h => { const k = 1 + h.g * er; blobPath(g, h.x, h.y, h.rx * k * 1.12 + 6, h.ry * k * 1.12 + 6, h.seed, er); g.fill(); }));
    g.globalCompositeOperation = 'destination-out'; g.fillStyle = '#000';
    HOLES.forEach(h => { const k = 1 + h.g * er; blobPath(g, h.x, h.y, h.rx * k, h.ry * k, h.seed, er); g.fill(); });
    if (o.burn) o.burn(g);
    g.globalCompositeOperation = 'source-over';
    return F;
  }
  // 投影（同样挖出破洞，边缘柔化）
  function papShadow(er, dx = 12, dy = 24) {
    const c = OFF[2], g = c.getContext('2d'); g.setTransform(1, 0, 0, 1, 0, 0); g.globalCompositeOperation = 'source-over'; g.globalAlpha = 1; g.filter = 'none'; g.clearRect(0, 0, W, H);
    g.drawImage(TEX.papShadow, dx, dy); g.globalCompositeOperation = 'destination-out';
    soft(g, 9, '#000', g => HOLES.forEach(h => { const k = 1 + h.g * er; blobPath(g, h.x + dx, h.y + dy, h.rx * k * .92, h.ry * k * .9, h.seed, er, 60, .5); g.fill(); }));
    g.globalCompositeOperation = 'source-over'; return c;
  }
  function holeR(h, er) { return { rx: h.rx * (1 + h.g * er), ry: h.ry * (1 + h.g * er) }; }

  const scenes = {};

  scenes.fragment = (ctx, S) => {
    const t = S.t, c1 = S.cue(1);
    paper(ctx); motes(ctx, t, .8);
    const intro = E.out(smooth(0, 8, t));
    const tLift = c1 + 3.4, tLift2 = c1 + 5.6;
    const shift = E.inOut(prog(t, tLift - .2, tLift2, x => x));
    const fs = lerp(1.16, .98, intro) * lerp(1, .74, shift);
    const fx = lerp(960, 610, shift), fy = lerp(500, 470, intro) + 0 * shift, frot = lerp(-.05, -.025, intro);
    const fa = smooth(.2, 2.4, t);
    const er = E.inOut(prog(t, 5.6, 11.2, x => x));
    const F = composePapyrus(t, { erode: er, write: L => smooth(1.2 + L.k * .055, 1.5 + L.k * .055, t), traceAlpha: smooth(3.4, 4.4, t) });
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
      if (lu > 0) { ctx.save(); ctx.globalAlpha = .22 * lu; soft(ctx, 6, 'rgba(90,40,20,1)', g => { g.fillRect(-gap - 4, -hh / 2 + 14, 8, hh); g.fillRect(gap - 4, -hh / 2 + 14, 8, hh); }); ctx.restore(); }
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
    T.cx.forEach((x, i) => { const u = E.out(prog(t, .25 + i * .3, 2.2 + i * .3, x => x)); if (u > 0) blot(mg, i, x, T.y, 230 * u, 1, { rot: i * 2.1 }); });
    g.drawImage(T.canvas, 0, 0); g.globalCompositeOperation = 'destination-in'; g.drawImage(Mk, 0, 0); g.globalCompositeOperation = 'source-over';
    // 水痕
    T.cx.forEach((x, i) => { const u = E.out(prog(t, .25 + i * .3, 2.6 + i * .3, x => x)); blot(ctx, i + 1, x, T.y + 6, 40 + 200 * u, .045 * (1 - .8 * smooth(2.2, 4.5, t)) * u, { rot: i * 1.4 + 2, color: '#5a4a38', mode: 'multiply' }); });
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

  // ---------- 3. 颁奖词：古典的柱 与 现代的格 ----------
  const COLTXT = [['ΕΡΩΣ', 1], ['ΓΛΥΚΥΠΙΚΡΟΝ', 1], ['ΣΑΠΦΩ', 1], ['ΣΤΗΣΙΧΟΡΟΣ', 1], ['ΓΗΡΥΩΝ', 1], ['CATVLLVS', 0], ['FRATER', 0], ['AVE ATQVE', 0], ['VALE', 0], ['NOX', 0], ['ΑΜΑΧΑΝΟΝ', 1], ['ΟΡΠΕΤΟΝ', 1]];
  function spiral(cx, cy, r, turns, dir) { const o = []; const n = 60; for (let i = 0; i <= n; i++) { const u = i / n; const a = dir * (u * turns * TAU) + (dir > 0 ? Math.PI : 0); const rr = r * (1 - u * .82); o.push([cx + Math.cos(a) * rr, cy + Math.sin(a) * rr]); } return o; }
  function column(ctx, x, top, bot, u, a, lit) {
    if (a <= 0) return; ctx.save(); ctx.globalAlpha = a; const gc = mix(INK4, GOLD, lit);
    ctx.strokeStyle = rgba(gc, .9); ctx.lineWidth = 1.3; ctx.lineCap = 'round';
    const cu = k => clamp(u * 1.6 - k);
    // 柱头
    const ab = partial([[x - 112, top], [x + 112, top]], cu(0)); line(ctx, ab, rgba(gc, .95), 1.4);
    line(ctx, partial([[x - 112, top + 12], [x + 112, top + 12]], cu(0)), rgba(gc, .7), 1);
    line(ctx, partial(spiral(x - 88, top + 38, 26, 2.1, 1), cu(.15)), rgba(gc, .9), 1.3);
    line(ctx, partial(spiral(x + 88, top + 38, 26, 2.1, -1), cu(.15)), rgba(gc, .9), 1.3);
    const ech = []; for (let i = 0; i <= 30; i++) { const v = i / 30; ech.push([lerp(x - 64, x + 64, v), top + 34 + Math.sin(v * Math.PI) * 14]); } line(ctx, partial(ech, cu(.2)), rgba(gc, .8), 1.2);
    // 柱身：凹槽细线（带收分）
    const s0 = top + 62, s1 = bot - 36;
    for (let k = 0; k <= 8; k++) { const f = k / 8 - .5; const pts = []; for (let i = 0; i <= 20; i++) { const v = i / 20; const w = lerp(84, 94, v) + Math.sin(v * Math.PI) * 4; pts.push([x + f * 2 * w, lerp(s0, s1, v)]); } line(ctx, partial(pts, cu(.3 + k * .04)), rgba(gc, k === 0 || k === 8 ? .85 : .32), k === 0 || k === 8 ? 1.3 : 1); }
    // 柱础
    line(ctx, partial([[x - 104, bot - 30], [x + 104, bot - 30]], cu(.5)), rgba(gc, .8), 1.2);
    line(ctx, partial([[x - 116, bot - 16], [x + 116, bot - 16]], cu(.55)), rgba(gc, .8), 1.2);
    line(ctx, partial([[x - 128, bot], [x + 128, bot]], cu(.6)), rgba(gc, .95), 1.5);
    ctx.restore();
    // 刻在柱身上的古希腊文、拉丁文
    COLTXT.forEach(([w, gk], i) => { const y = s0 + 26 + i * ((s1 - s0 - 40) / (COLTXT.length - 1)); text(ctx, w, x, y, { size: gk ? 16 : 18, font: gk ? GK : 'latin', weight: 600, color: rgba(mix(INK3, '#6a4a14', lit * .7)), alpha: a * clamp(u * 2.2 - .6 - i * .05) * .9, spacing: gk ? .22 : .3 }); });
  }
  const GRIDC = { x0: 1462, y0: 304, cw: 112, ch: 118, nc: 3, nr: 4 };
  function gridCell(ctx, i, cx, cy, a, t) {
    if (a <= 0) return; ctx.save(); ctx.globalAlpha = a; const s = E.outBack(clamp(a)); ctx.translate(cx, cy); ctx.scale(s, s); ctx.strokeStyle = INK2; ctx.fillStyle = INK2; ctx.lineWidth = 1.6;
    switch (i) {
      case 0: ctx.fillStyle = RED2; ctx.fillRect(-30, -30, 60, 60); break;
      case 1: ctx.restore(); text(ctx, '新', cx, cy + 2, { size: 62, font: 'song', weight: 900, color: INK, alpha: a }); return;
      case 2: ctx.beginPath(); ctx.arc(0, 0, 30, 0, TAU); ctx.stroke(); ctx.beginPath(); ctx.arc(0, 0, 4, 0, TAU); ctx.fill(); break;
      case 3: for (let k = 0; k < 6; k++) { ctx.globalAlpha = a * (.5 + .5 * hash(k, 3)); ctx.fillRect(-33 + k * 11, -32 + hash(k, 4) * 10, 7, 62 - hash(k, 4) * 10); } break;
      case 4: ctx.beginPath(); ctx.ellipse(0, -6, 36, 24, 0, 0, TAU); ctx.stroke(); ctx.beginPath(); ctx.moveTo(-12, 15); ctx.lineTo(-20, 32); ctx.lineTo(0, 17); ctx.stroke(); break;
      case 5: { ctx.beginPath(); for (let k = 0; k <= 6; k++) ctx.lineTo(-36 + k * 12, k % 2 ? 24 : -24); ctx.stroke(); break; }
      case 6: ctx.restore(); text(ctx, '29', cx, cy + 2, { size: 56, font: 'latin', weight: 600, color: INK, alpha: a }); return;
      case 7: ctx.restore(); bracket(ctx, cx - 26, cy, 56, -1, 1, { w: 3, alpha: a }); bracket(ctx, cx + 26, cy, 56, 1, 1, { w: 3, alpha: a }); return;
      case 8: ctx.beginPath(); ctx.moveTo(-34, 30); ctx.lineTo(34, -30); ctx.stroke(); ctx.fillStyle = RED2; ctx.beginPath(); ctx.arc(14, 12, 7, 0, TAU); ctx.fill(); break;
      case 9: ctx.fillStyle = RED2; ctx.beginPath(); ctx.moveTo(-38, -34); ctx.quadraticCurveTo(-8, -4, -18, 34); ctx.lineTo(-38, 34); ctx.closePath(); ctx.fill(); ctx.beginPath(); ctx.moveTo(38, -34); ctx.quadraticCurveTo(8, -4, 18, 34); ctx.lineTo(38, 34); ctx.closePath(); ctx.fill(); ctx.fillRect(-40, -38, 80, 5); break;
      case 10: ctx.restore(); text(ctx, 'NOX', cx, cy + 2, { size: 34, font: 'latin', weight: 600, color: INK, alpha: a, spacing: .2 }); return;
      case 11: for (let k = 0; k < 7; k++) { const r = 3 + 9 * hash(k, 8); ctx.globalAlpha = a * (.4 + .6 * hash(k, 9)); ctx.beginPath(); ctx.arc((hash(k, 6) - .5) * 56, (hash(k, 7) - .5) * 56, r, 0, TAU); ctx.fill(); } break;
    }
    ctx.restore();
  }
  function threadPts(x0, x1, y, n = 220) { const o = []; for (let i = 0; i <= n; i++) { const u = i / n; const k = 3; const env_ = Math.sin(Math.PI * u); o.push([lerp(x0, x1, u) - 72 * env_ * Math.sin(TAU * k * u), y - 34 * env_ * Math.cos(TAU * k * u) + 34 * env_ * .4]); } return o; }

  scenes.citation = (ctx, S) => {
    const t = S.t, c1 = S.cue(1);
    paper(ctx); motes(ctx, t + 60, .7);
    const tB = c1 - .6; const mv = E.inOut(prog(t, tB, tB + 1.4, x => x));
    // 名字（身后一团极淡的墨晕，缓缓洇开）
    const na = smooth(.5, 1.8, t);
    blot(ctx, 3, W / 2, lerp(430, 175, mv), lerp(160, 520, E.out(prog(t, .3, 7, x => x))) * lerp(1, .55, mv), .032 * na * (1 - mv * .6), { color: '#6a5a48', mode: 'multiply', rot: .7 });
    const ny = lerp(420, 168, mv), nsz = lerp(116, 54, mv);
    ctx.save(); ctx.globalAlpha = na; ctx.fillStyle = RED; const rw = lerp(70, 40, mv) * E.out(prog(t, .6, 2, x => x)); ctx.fillRect(W / 2 - rw / 2, ny - nsz * .95 - 6, rw, 2.5); ctx.restore();
    text(ctx, '安妮·卡森', W / 2, ny, { size: nsz, font: 'song', weight: 300, spacing: .22, color: INK, alpha: na, reveal: prog(t, .5, 2.2, E.out) });
    text(ctx, 'ANNE CARSON', W / 2, ny + nsz * .86, { size: lerp(30, 19, mv), font: 'latin', weight: 600, spacing: .62, color: INK3, alpha: na * .95, reveal: prog(t, 1, 2.6, E.out) });
    const da = 1 - smooth(tB - .2, tB + .4, t);
    const desc = [['加拿大', at(S, 0, '加拿大')], ['诗人', at(S, 0, '诗人')], ['古典学者', at(S, 0, '古典学者')]];
    { const ws = desc.map(([w]) => measure(ctx, w, 'song', 34, 400) + 34 * .2 * ([...w].length - 1)); const sep = 64; const tot = ws.reduce((a, b) => a + b, 0) + sep * 2; let x = W / 2 - tot / 2;
      desc.forEach(([w, tt], i) => { const a = smooth(tt - .1, tt + .6, t) * da; text(ctx, w, x, 610, { size: 34, font: 'song', weight: 400, spacing: .2, color: INK2, alpha: a, align: 'left', reveal: prog(t, tt - .1, tt + .7, E.out) }); x += ws[i]; if (i < 2) { dot(ctx, x + sep / 2, 612, 3.2, RED, smooth(desc[i + 1][1] - .2, desc[i + 1][1] + .3, t) * da); x += sep; } }); }
    // 柱与格
    const tCol = at(S, 0, '古典学者') - .3, tGrid = at(S, 0, '诗人') - .2;
    const tCT = at(S, 1, '古典传统'), tPD = at(S, 1, '游戏性对话'), tNF = at(S, 1, '新的形式');
    const lit = smooth(tCT, tCT + .8, t);
    column(ctx, 300, 248, 822, prog(t, tCol, tCol + 3.2, x => x), smooth(tCol, tCol + .6, t), lit);
    // 格
    const ga = smooth(tGrid, tGrid + .8, t); const gu = prog(t, tGrid, tGrid + 2.4, E.inOut);
    if (ga > 0) {
      const G = GRIDC; ctx.save(); ctx.globalAlpha = ga; ctx.strokeStyle = rgba(INK4, .75); ctx.lineWidth = 1;
      for (let c = 0; c <= G.nc; c++) { const x = G.x0 + c * G.cw; ctx.beginPath(); ctx.moveTo(x, G.y0); ctx.lineTo(x, G.y0 + G.nr * G.ch * clamp(gu * 1.4 - c * .1)); ctx.stroke(); }
      for (let r = 0; r <= G.nr; r++) { const y = G.y0 + r * G.ch; ctx.beginPath(); ctx.moveTo(G.x0, y); ctx.lineTo(G.x0 + G.nc * G.cw * clamp(gu * 1.4 - r * .1), y); ctx.stroke(); }
      ctx.restore();
      // 角标
      text(ctx, '+', G.x0 - 14, G.y0 - 14, { size: 22, font: 'latin', color: RED, alpha: ga }); text(ctx, '+', G.x0 + G.nc * G.cw + 14, G.y0 + G.nr * G.ch + 14, { size: 22, font: 'latin', color: RED, alpha: ga });
      for (let i = 0; i < 12; i++) { const c = i % 3, r = Math.floor(i / 3); const order = [0, 4, 8, 1, 5, 9, 2, 6, 10, 3, 7, 11][i]; gridCell(ctx, i, G.x0 + (c + .5) * G.cw, G.y0 + (r + .5) * G.ch, smooth(tNF - .3 + order * .1, tNF + .1 + order * .1, t), t); }
    }
    // 颁奖词关键词
    const p1 = smooth(c1 + .1, c1 + .9, t);
    tag(ctx, '大胆而富有创造力', 'bold and inventive', W / 2, 352, { size: 56, weight: 500, align: 'center', color: INK, alpha: p1, enSize: 20, enSpacing: .42, mark: false, reveal: prog(t, c1 + .1, c1 + 1.2, E.out) });
    tag(ctx, '古典传统', 'classical tradition', 470, 482, { size: 40, weight: 500, color: INK, alpha: smooth(tCT - .1, tCT + .7, t), enSize: 16, accent: GOLD });
    tag(ctx, '新的形式', 'new forms', 1410, 482, { size: 40, weight: 500, color: INK, align: 'right', alpha: smooth(tNF - .1, tNF + .7, t), enSize: 16 });
    // 游戏性对话：一根朱红细线在柱与格之间来回打转
    const pa = smooth(tPD - .1, tPD + .7, t);
    if (pa > 0) {
      const pts = threadPts(430, 1430, 620); const tu = prog(t, tPD - .2, tPD + 1.4, E.inOut);
      line(ctx, partial(pts, tu), rgba(RED2, .85), 1.6, pa);
      if (tu >= 1) { const v = .5 - .5 * Math.cos((t - tPD - 1.4) * 1.5); const p = KIT.at(pts, v * (pts.length - 1)); glow(ctx, p[0], p[1], 16, RED2, .25 * pa); dot(ctx, p[0], p[1], 5, RED2, pa); }
      dot(ctx, 430, 620, 3.5, GOLD, pa); dot(ctx, 1430, 620, 3.5, RED2, pa);
      tag(ctx, '游戏性对话', 'playful dialogue', W / 2, 760, { size: 42, weight: 500, align: 'center', color: INK, alpha: pa, enSize: 17, enSpacing: .4, mark: false });
    }
  };

  // ---------- 4. 甜苦：爱欲的三角，在水一方 ----------
  const REEDS = (() => { const r = rng(404); const a = []; for (let i = 0; i < 17; i++) { const bx = 20 + r() * 400 + (i % 3) * 16; const near = r(); a.push({ bx, lean: 40 + r() * 110, ty: 330 + r() * 330 - near * 60, ph: r() * 6, sp: .5 + r() * .5, tone: near, w: 2.4 + near * 3.6, leaves: [...Array(2 + Math.floor(r() * 3))].map(() => ({ at: .25 + r() * .5, side: r() < .5 ? -1 : 1, len: 120 + r() * 200, droop: .3 + r() * .7, w: 8 + r() * 10 })), plume: r() < .6, pl: [...Array(16)].map(() => [r(), r(), r()]) }); } return a.sort((p, q) => p.tone - q.tone); })();
  const WSTROKES = (() => { const r = rng(77); return [...Array(46)].map(() => ({ y: 590 + Math.pow(r(), 1.3) * 330, x: r() * 2200 - 140, len: 80 + r() * 420, w: 1 + r() * 2.6, a: .04 + r() * .12, sp: 3 + r() * 8 })); })();
  function reed(ctx, R, t, grow, a) {
    if (grow <= 0 || a <= 0) return; const sway = Math.sin(t * R.sp + R.ph) * 10 + Math.sin(t * .37 + R.ph) * 6;
    const col = rgba(mix('#8a8070', INK, .35 + R.tone * .6)); const by = 1110, tx = R.bx + R.lean + sway, ty = lerp(by, R.ty, grow);
    const cx = R.bx + R.lean * .15, cy = lerp(by, R.ty, .55);
    const pts = qpts(R.bx, by, cx, cy, lerp(R.bx, tx, grow), ty, 30);
    stroke(ctx, pts, R.w, col, a * (.55 + R.tone * .4), { wfn: u => R.w * (1 - u * .55) });
    if (grow > .6) for (const L of R.leaves) {
      const k = Math.floor(L.at * 30); const p = pts[k]; const lg = smooth(.6, 1, grow); const sw = sway * .6;
      const ex = p[0] + L.side * L.len * .55 * lg + sw, ey = p[1] - L.len * .55 * lg + L.len * L.droop * .65 * lg;
      const lp = qpts(p[0], p[1], p[0] + L.side * L.len * .25 + sw * .5, p[1] - L.len * .7 * lg, ex, ey, 18);
      stroke(ctx, lp, L.w, col, a * (.45 + R.tone * .4), { wfn: u => L.w * Math.sin(Math.PI * Math.pow(u, .7)) * (1 - u * .3) });
    }
    if (R.plume && grow > .85) {
      const pa = a * smooth(.85, 1, grow); ctx.save(); ctx.strokeStyle = rgba(mix('#9a8c78', INK2, R.tone * .5)); ctx.lineCap = 'round';
      for (const [u, v, w] of R.pl) { const ang = -1.2 + u * 1.6 + Math.sin(t * 1.3 + R.ph + u * 3) * .08; const L = 26 + v * 46; ctx.globalAlpha = pa * (.18 + w * .3); ctx.lineWidth = .8 + w * 1.4; ctx.beginPath(); ctx.moveTo(tx, ty); ctx.quadraticCurveTo(tx + Math.cos(ang) * L * .5 + 8, ty + Math.sin(ang) * L * .5, tx + Math.cos(ang) * L + 14, ty + Math.sin(ang) * L + L * .4); ctx.stroke(); }
      ctx.restore();
    }
  }
  function figure(ctx, x, y, h, a, col = INK2) {
    if (a <= 0) return; ctx.save(); ctx.globalAlpha = a; ctx.fillStyle = col; const s = h / 52; ctx.translate(x, y); ctx.scale(s, s);
    ctx.beginPath(); ctx.arc(0, -46, 4.6, 0, TAU); ctx.fill();
    ctx.beginPath(); ctx.moveTo(-3, -41); ctx.quadraticCurveTo(-6, -24, -11, 0); ctx.lineTo(10, 0); ctx.quadraticCurveTo(5, -22, 3, -41); ctx.closePath(); ctx.fill();
    ctx.beginPath(); ctx.moveTo(2, -36); ctx.quadraticCurveTo(14, -26, 18, -12); ctx.lineTo(15, -11); ctx.quadraticCurveTo(10, -22, 1, -30); ctx.fill();
    ctx.restore();
  }

  scenes.eros = (ctx, S) => {
    const t = S.t, c1 = S.cue(1), c2 = S.cue(2);
    paper(ctx); motes(ctx, t + 90, .6);
    // A：γλυκύπικρον 一分为二
    const aA = 1 - smooth(c1 - .6, c1 + .3, t);
    if (aA > 0) {
      const tS = at(S, 0, '甜苦'), tSw = at(S, 0, '甜在前'), tBt = at(S, 0, '苦在后');
      const sz = 176, y = 455; const w1 = measure(ctx, 'γλυκύ', GK, sz), w2 = measure(ctx, 'πικρον', GK, sz);
      const sp = E.inOut(prog(t, tS - .1, tS + 1.1, x => x)); const gap = 130 * sp;
      const x0 = W / 2 - (w1 + w2 + gap) / 2; const wr = prog(t, 1.4, 3.3, E.out);
      const honey = smooth(tS, tS + 1.2, t);
      // 苦：墨晕
      blot(ctx, 2, x0 + w1 + gap + w2 * .5, y + 10, 40 + 250 * E.out(prog(t, tS + .2, tS + 2.6, x => x)), .10 * aA * smooth(tS, tS + .4, t), { color: '#4a3e32', mode: 'multiply' });
      // 甜：蜜色微光
      if (honey > 0) { const g = ctx.createRadialGradient(x0 + w1 / 2, y, 10, x0 + w1 / 2, y, 300); g.addColorStop(0, rgba('#e9c46a', .28 * honey * aA)); g.addColorStop(1, rgba('#e9c46a', 0)); ctx.fillStyle = g; ctx.fillRect(x0 + w1 / 2 - 300, y - 300, 600, 600); }
      text(ctx, 'γλυκύ', x0, y, { size: sz, font: GK, color: rgba(mix(INK, HONEY, honey)), alpha: aA, align: 'left', reveal: clamp(wr * 2.1), rise: 0, soft: 2 });
      text(ctx, 'πικρον', x0 + w1 + gap, y, { size: sz, font: GK, color: INK, alpha: aA, align: 'left', reveal: clamp(wr * 2.1 - 1.05), rise: 0, soft: 2 });
      // 一滴蜜
      const dd = smooth(tS + 1.4, tS + 3.4, t); if (dd > 0) { const dx = x0 + w1 * .80, dy0 = y + 52; const L = 8 + 46 * dd; ctx.save(); ctx.globalAlpha = aA; const g = ctx.createLinearGradient(dx - 8, 0, dx + 8, 0); g.addColorStop(0, '#a8701a'); g.addColorStop(.5, '#e6b443'); g.addColorStop(1, '#a8701a'); ctx.fillStyle = g; ctx.beginPath(); ctx.moveTo(dx - 4, dy0); ctx.quadraticCurveTo(dx - 2.5, dy0 + L * .7, dx - 8 - dd * 2, dy0 + L); ctx.arc(dx, dy0 + L, 8 + dd * 2, Math.PI, 0, true); ctx.quadraticCurveTo(dx + 2.5, dy0 + L * .7, dx + 4, dy0); ctx.closePath(); ctx.fill(); ctx.fillStyle = 'rgba(255,248,220,.8)'; ctx.beginPath(); ctx.arc(dx - 3, dy0 + L - 2, 2.4, 0, TAU); ctx.fill(); ctx.restore(); }
      text(ctx, '甜', x0 + w1 / 2, 670, { size: 92, font: 'song', weight: 300, color: HONEY, alpha: aA * smooth(tSw - .2, tSw + .5, t), reveal: prog(t, tSw - .2, tSw + .5, E.out) });
      text(ctx, '苦', x0 + w1 + gap + w2 / 2, 670, { size: 92, font: 'song', weight: 300, color: INK, alpha: aA * smooth(tBt - .2, tBt + .5, t), reveal: prog(t, tBt - .2, tBt + .5, E.out) });
      text(ctx, 'sweet', x0 + w1 / 2, 745, { size: 30, font: 'latinI', color: '#8a6420', alpha: aA * smooth(tSw + .2, tSw + .9, t) });
      text(ctx, 'bitter', x0 + w1 + gap + w2 / 2, 745, { size: 30, font: 'latinI', color: INK3, alpha: aA * smooth(tBt + .2, tBt + .9, t) });
      tag(ctx, '她的第一部书', 'Eros the Bittersweet · 1986', W / 2, 232, { size: 26, align: 'center', alpha: aA * smooth(.5, 1.5, t), mark: false, raw: true, enFont: 'latinI', enSize: 30, enSpacing: .04, enColor: INK2 });
    }
    // B：爱者、被爱者，以及其间的距离
    const aB = smooth(c1 - .3, c1 + .5, t) * (1 - smooth(c2 - .7, c2 + .1, t));
    if (aB > 0) {
      const tA = at(S, 1, '爱者'), tBl = at(S, 1, '被爱者'), tG = at(S, 1, '距离'), tX = at(S, 1, '距离一旦') + .2, tO = at(S, 1, '熄灭');
      const cl = E.inOut(prog(t, tX, tX + 1.8, x => x)); const dim = smooth(tX + .6, tO + .3, t);
      const A = [lerp(610, 905, cl), 700], B = [lerp(1310, 1015, cl), 700], C = [960, lerp(318, 700, cl)];
      tag(ctx, '爱欲，生于匮乏', null, W / 2, 182, { size: 44, weight: 300, align: 'center', color: INK, alpha: aB * smooth(c1 + .2, c1 + 1.2, t), spacing: .3, mark: false });
      const ea = smooth(tG - .2, tG + .8, t) * aB;
      const gold = rgba(mix(GOLD, '#9a9080', dim));
      if (ea > 0) {
        line(ctx, partial([A, C], prog(t, tG - .2, tG + .9, E.out)), gold, 1.8, ea * (1 - dim * .55));
        line(ctx, partial([B, C], prog(t, tG - .2, tG + .9, E.out)), gold, 1.8, ea * (1 - dim * .55));
        // 光沿 爱者 → 距离 → 被爱者 流动
        if (dim < 1) for (let k = 0; k < 3; k++) { const u = ((t - tG) * .32 + k / 3) % 1; const p = u < .5 ? [lerp(A[0], C[0], u * 2), lerp(A[1], C[1], u * 2)] : [lerp(C[0], B[0], u * 2 - 1), lerp(C[1], B[1], u * 2 - 1)]; glow(ctx, p[0], p[1], 22, '#e3b04a', .35 * ea * (1 - dim)); dot(ctx, p[0], p[1], 3, '#c8902a', ea * (1 - dim)); }
        // 中心：爱欲
        const cx = (A[0] + B[0] + C[0]) / 3, cy = (A[1] + B[1] + C[1]) / 3;
        const lg = ctx.createRadialGradient(cx, cy, 0, cx, cy, 220); lg.addColorStop(0, rgba('#e8c070', .30 * ea * (1 - dim))); lg.addColorStop(1, rgba('#e8c070', 0)); ctx.fillStyle = lg; ctx.fillRect(cx - 220, cy - 220, 440, 440);
        const ey = lerp(cy + 10, 520, cl); text(ctx, '爱欲', cx, ey, { size: 54, font: 'song', weight: 400, spacing: .3, color: rgba(mix(INK, '#a09684', dim)), alpha: ea * (1 - dim * .65) });
        text(ctx, 'EROS', cx, ey + 48, { size: 16, font: 'latin', weight: 600, spacing: .5, color: INK3, alpha: ea * (1 - dim * .75) });
      }
      // 底边：没有直接的路
      const ba = smooth(tBl, tBl + .6, t) * aB; if (ba > 0) { ctx.save(); ctx.setLineDash([3, 9]); line(ctx, [A, B], rgba(INK4, .9), 1.2, ba * (1 - cl)); ctx.restore(); }
      // 需要三方：先出现三个虚位
      const t3 = at(S, 1, '三方') - .2; const ga3 = smooth(t3, t3 + .6, t) * aB * (1 - smooth(tX, tX + .5, t));
      if (ga3 > 0) { ctx.save(); ctx.setLineDash([2, 6]); ctx.strokeStyle = rgba(INK3, .8); ctx.lineWidth = 1.4; [[A, tA], [B, tBl], [C, tG]].forEach(([P, tt], k) => { const a = ga3 * (1 - smooth(tt - .1, tt + .4, t) * .7) * smooth(t3 + k * .25, t3 + .5 + k * .25, t); if (a <= 0) return; ctx.globalAlpha = a; ctx.beginPath(); ctx.arc(P[0], P[1], 22, 0, TAU); ctx.stroke(); }); ctx.restore(); }
      // 三个点
      const a1 = smooth(tA - .1, tA + .5, t) * aB, a2 = smooth(tBl - .1, tBl + .5, t) * aB, a3 = ea;
      const emb = mix(RED2, '#8a8478', dim);
      if (a1 > 0) { glow(ctx, A[0], A[1], 46, RED2, .35 * a1 * (1 - dim)); dot(ctx, A[0], A[1], 9, rgba(emb), a1); }
      if (a2 > 0) dot(ctx, B[0], B[1], 9, INK, a2);
      if (a3 > 0) { ctx.save(); ctx.globalAlpha = a3 * (1 - cl); ctx.strokeStyle = RED2; ctx.lineWidth = 1.6; ctx.setLineDash([4, 5]); ctx.lineDashOffset = -t * 6; ctx.beginPath(); ctx.arc(C[0], C[1], 16, 0, TAU); ctx.stroke(); ctx.restore(); }
      const la = 1 - smooth(tX, tX + .8, t);
      tag(ctx, '爱者', 'lover', A[0], A[1] + 56, { size: 32, align: 'center', alpha: a1 * la, mark: false, color: INK });
      tag(ctx, '被爱者', 'beloved', B[0], B[1] + 56, { size: 32, align: 'center', alpha: a2 * la, mark: false, color: INK });
      tag(ctx, '距离', 'the gap between', C[0], C[1] - 64, { size: 32, align: 'center', alpha: a3 * la, mark: false, color: RED });
      // 熄灭：一缕烟
      const sm = smooth(tO - .4, tO + .6, t) * (1 - smooth(c2 - 1.2, c2 - .2, t)) * aB;
      if (sm > 0) { ctx.save(); ctx.strokeStyle = rgba('#8a8070', .5 * sm); ctx.lineWidth = 1.4; ctx.lineCap = 'round'; for (let k = 0; k < 3; k++) { ctx.beginPath(); for (let i = 0; i <= 30; i++) { const v = i / 30; const yy = 690 - v * 200 * smooth(tO - .4, tO + 1.8, t); const xx = 960 + Math.sin(v * 7 + t * 1.5 + k * 2) * 14 * v + (k - 1) * 6 * v; i ? ctx.lineTo(xx, yy) : ctx.moveTo(xx, yy); } ctx.globalAlpha = (1 - k * .25); ctx.stroke(); } ctx.restore(); }
    }
    // C：所谓伊人，在水一方
    const aC = smooth(c2 - .5, c2 + .9, t);
    if (aC > 0) {
      const tY = at(S, 2, '所谓伊人'), tZ = at(S, 2, '在水一方'), tW = at(S, 2, '那一湾水');
      ctx.save(); ctx.globalAlpha = aC * .5; ctx.drawImage(TEX.mountInk, 260, -4); ctx.restore();
      // 雾
      const mg = ctx.createLinearGradient(0, 520, 0, 620); mg.addColorStop(0, rgba(PAPER, 0)); mg.addColorStop(.6, rgba(PAPER, .85 * aC)); mg.addColorStop(1, rgba(PAPER, 0)); ctx.fillStyle = mg; ctx.fillRect(0, 520, W, 100);
      // 水岸线
      const hu = E.inOut(prog(t, c2 - .5, c2 + 1.2, x => x)); line(ctx, [[W / 2 - 900 * hu, 572], [W / 2 + 900 * hu, 572]], rgba(INK3, .5), 1.2, aC);
      // 水面
      ctx.save(); ctx.lineCap = 'round';
      for (const w of WSTROKES) { const x = ((w.x + t * w.sp) % 2200 + 2200) % 2200 - 140; ctx.globalAlpha = w.a * aC * smooth(570, 640, w.y); ctx.strokeStyle = INK2; ctx.lineWidth = w.w; ctx.beginPath(); ctx.moveTo(x, w.y); ctx.lineTo(x + w.len, w.y + Math.sin(x * .01) * 1.5); ctx.stroke(); }
      ctx.restore();
      // 一湾水：一道流光
      const sh = prog(t, tW - .3, tW + 2.6, E.inOut); if (sh > 0 && sh < 1) { const sx = lerp(300, 1700, sh); const g = ctx.createLinearGradient(sx - 260, 0, sx + 260, 0); g.addColorStop(0, rgba('#fffaf0', 0)); g.addColorStop(.5, rgba('#fffaf0', .55 * aC)); g.addColorStop(1, rgba('#fffaf0', 0)); ctx.fillStyle = g; ctx.fillRect(sx - 260, 590, 520, 300); }
      // 伊人与倒影
      const fa = smooth(tY - .6, tY + .8, t) * aC; const fx = 1235, fy = 566;
      figure(ctx, fx, fy, 50, fa * .85);
      ctx.save(); ctx.globalAlpha = fa * .22; for (let k = 0; k < 10; k++) { const yy = fy + 4 + k * 5; ctx.save(); ctx.beginPath(); ctx.rect(fx - 40, yy, 80, 5); ctx.clip(); ctx.translate(Math.sin(t * 2 + k) * 2.5, 0); ctx.translate(fx, fy + 4); ctx.scale(1, -1); ctx.translate(-fx, -(fy + 4)); figure(ctx, fx, fy + 4, 50, 1, INK3); ctx.restore(); } ctx.restore();
      // 芦苇
      REEDS.forEach((R, i) => reed(ctx, R, t, E.out(prog(t, c2 - .2 + i * .06, c2 + 2.2 + i * .06, x => x)), aC));
      // 思慕：一根朱红细线伸向对岸，却始终差一点
      const ra = smooth(tW, tW + .8, t) * aC; if (ra > 0) { const k = .88 * (1 - Math.exp(-(t - tW) * .9)); const pts = partial(qpts(520, 700, 900, 690, fx - 20, fy + 12, 60), k); ctx.save(); ctx.lineCap = 'round'; for (let i = 1; i < pts.length; i++) { ctx.globalAlpha = ra * .85 * Math.pow(1 - i / pts.length, .6); ctx.strokeStyle = RED2; ctx.lineWidth = 1.6; ctx.beginPath(); ctx.moveTo(pts[i - 1][0], pts[i - 1][1]); ctx.lineTo(pts[i][0], pts[i][1]); ctx.stroke(); } ctx.restore(); }
      // 竖排诗句
      const vs = 74; vtext(ctx, '所谓伊人', 1730, 240, { size: vs, font: 'brush', color: INK, alpha: aC, reveal: prog(t, tY - .3, tY + 1.2, E.out), spacing: .12 });
      vtext(ctx, '在水一方', 1636, 300, { size: vs, font: 'brush', color: INK, alpha: aC, reveal: prog(t, tZ - .3, tZ + 1.2, E.out), spacing: .12 });
      tag(ctx, '《诗经·蒹葭》', null, 1683, 812, { size: 22, align: 'center', alpha: aC * smooth(tZ + .4, tZ + 1.4, t), mark: false, color: INK3 });
    }
  };

  // ---------- 5. 红的自传：残章拼成长着红翼的少年 ----------
  const ROMAN = ['I', 'II', 'III', 'IV', 'V', 'VI', 'VII', 'VIII', 'IX', 'X', 'XI', 'XII', 'XIII'];
  const SCRAPS = (() => { const r = rng(515); const a = []; const spots = [[230, 250], [520, 170], [820, 230], [1120, 160], [1440, 240], [1700, 330], [190, 560], [430, 760], [1560, 560], [1720, 760], [760, 800], [1180, 820]]; spots.forEach(([x, y], i) => a.push({ x, y, w: 120 + r() * 70, h: 80 + r() * 50, rot: (r() - .5) * .5, ph: r() * 6, n: ROMAN[(i * 5 + 2) % 13], lines: 3 + Math.floor(r() * 3), seed: r() * 100 })); return a; })();
  // 革律翁：身体由横向“诗行”组成，翅膀由沿弧线排开的希腊字母组成
  const GER = (() => {
    const r = rng(1998); const body = []; const span = y => {
      if (y < -186) { const dy = (y + 220) / 34; const w = 30 * Math.sqrt(Math.max(0, 1 - dy * dy)); return w > 2 ? [[-w + 2, w + 2]] : []; }
      if (y < -176) return [[-8, 8]];
      if (y < -40) { const v = (y + 176) / 136; const w = lerp(64, 40, Math.pow(v, .8)); return [[-w, w]]; }
      if (y < 4) { const w = lerp(40, 50, (y + 40) / 44); return [[-w, w]]; }
      const v = (y - 4) / 216; const sep = lerp(6, 14, v); const lw = lerp(24, 13, v); return [[-sep - lw, -sep], [sep, sep + lw]];
    };
    for (let y = -252; y <= 220; y += 7.5) for (const [a0, a1] of span(y)) { const segs = []; let x = a0 + r() * 3; while (x < a1 - 2) { const L = Math.min(a1 - x, 5 + r() * 18); segs.push([x, x + L]); x += L + 3 + r() * 3; } if (segs.length) body.push({ y, segs, src: Math.floor(r() * 12), d: r() }); }
    const GW = 'ΓΗΡΥΟΝΗΙΣΕΡΥΘΡΟΣΠΤΕΡΑΠΥΡΟΣΚΑΙΦΩΣ';
    const wings = []; for (const side of [-1, 1]) for (let k = 0; k < 14; k++) { const v = k / 13; wings.push({ side, k, v, len: lerp(360, 150, Math.pow(v, .9)) * (.92 + r() * .14), open: lerp(-112, -196, v) * Math.PI / 180, shut: lerp(98, 112, v) * Math.PI / 180, bend: .10 + r() * .08, chars: [...Array(40)].map((_, j) => GW[(k * 7 + j * 3 + (side > 0 ? 5 : 0)) % GW.length]), src: Math.floor(r() * 12), d: r() }); }
    return { body, wings };
  })();
  function scrap(ctx, sc, x, y, a, t) {
    if (a <= 0) return; ctx.save(); ctx.translate(x, y); ctx.rotate(sc.rot + Math.sin(t * .4 + sc.ph) * .04); ctx.globalAlpha = a;
    ctx.shadowColor = 'rgba(80,50,20,.18)'; ctx.shadowBlur = 14; ctx.shadowOffsetY = 6; ctx.fillStyle = '#f6efe0';
    ctx.beginPath(); const n = 18; for (let i = 0; i < n * 4; i++) { const side = Math.floor(i / n), u = (i % n) / n; const jj = (hash(i, sc.seed | 0) - .5) * 5; let px, py; if (side === 0) { px = lerp(-sc.w / 2, sc.w / 2, u); py = -sc.h / 2 + jj; } else if (side === 1) { px = sc.w / 2 + jj; py = lerp(-sc.h / 2, sc.h / 2, u); } else if (side === 2) { px = lerp(sc.w / 2, -sc.w / 2, u); py = sc.h / 2 + jj; } else { px = -sc.w / 2 + jj; py = lerp(sc.h / 2, -sc.h / 2, u); } i ? ctx.lineTo(px, py) : ctx.moveTo(px, py); } ctx.closePath(); ctx.fill();
    ctx.shadowColor = 'transparent';
    text(ctx, sc.n, -sc.w / 2 + 12, -sc.h / 2 + 18, { size: 18, font: 'latin', weight: 600, color: RED, align: 'left' });
    ctx.strokeStyle = rgba(INK2, .55); ctx.lineWidth = 1.6; for (let l = 0; l < sc.lines; l++) { const yy = -sc.h / 2 + 34 + l * 12; if (yy > sc.h / 2 - 8) break; let xx = -sc.w / 2 + 12; const end = sc.w / 2 - 12 - hash(l, sc.seed | 0) * 40; while (xx < end) { const L = 6 + hash(l * 31 + xx | 0, 3) * 16; ctx.beginPath(); ctx.moveTo(xx, yy); ctx.lineTo(Math.min(end, xx + L), yy); ctx.stroke(); xx += L + 5; } }
    ctx.restore();
  }
  function wingPts(f, ang, cx, cy) { const sx = cx + f.side * 26, sy = cy - 160; const a = f.side < 0 ? ang : Math.PI - ang; const ex = sx + Math.cos(a) * f.len, ey = sy + Math.sin(a) * f.len; const nx = -Math.sin(a), ny = Math.cos(a); const bx = (sx + ex) / 2 + nx * f.len * f.bend * f.side * -1, by = (sy + ey) / 2 + Math.abs(ny) * f.len * f.bend + f.len * .08; return qpts(sx, sy, bx, by, ex, ey, 30); }
  function geryon(ctx, t, o) {
    const { cx, cy, asm, open, a, sc = 1 } = o; if (a <= 0) return;
    ctx.save(); ctx.translate(cx, cy); ctx.scale(sc, sc); ctx.translate(-cx, -cy);
    // 身体
    ctx.lineCap = 'butt';
    for (const L of GER.body) {
      const u = E.inOut(clamp((asm - L.d * .45) / .55)); if (u <= 0) continue; const S = SCRAPS[L.src];
      const ox = lerp(S.x - cx + (L.d - .5) * S.w * .6, 0, u), oy = lerp(S.y - cy - L.y + (L.d - .5) * S.h * .5, 0, u); const k = lerp(.35, 1, u);
      ctx.strokeStyle = rgba(mix('#8a1e12', RED2, L.d * .6)); ctx.globalAlpha = a * (.55 + .45 * u); ctx.lineWidth = 2.6;
      ctx.beginPath(); for (const [x0, x1] of L.segs) { ctx.moveTo(cx + ox + x0 * k, cy + oy + L.y); ctx.lineTo(cx + ox + x1 * k, cy + oy + L.y); } ctx.stroke();
    }
    // 翅膀
    ctx.font = font(GK, 15, 400); ctx.textAlign = 'center'; ctx.textBaseline = 'middle';
    for (const f of GER.wings) {
      const u = E.inOut(clamp((asm - f.d * .45) / .55)); if (u <= 0) continue; const S = SCRAPS[f.src];
      const op = E.inOut(clamp(open * 1.35 - f.v * .35)); const ang = lerp(f.shut, f.open, op);
      const pts = wingPts(f, ang, cx, cy); const an = pts[15]; const k = lerp(.3, 1, u); const ox = (S.x - an[0]) * (1 - u), oy = (S.y - an[1]) * (1 - u);
      ctx.fillStyle = rgba(mix(RED2, '#e0602a', (1 - f.v) * .35)); ctx.globalAlpha = a * (.5 + .5 * u);
      let acc = 0; let ci = 0; const step = 12.5;
      for (let i = 1; i < pts.length; i++) { const dx = pts[i][0] - pts[i - 1][0], dy = pts[i][1] - pts[i - 1][1]; const seg = Math.hypot(dx, dy); acc += seg; while (acc >= step && ci < f.chars.length) { acc -= step; const fr = 1 - acc / seg; const px = pts[i - 1][0] + dx * fr, py = pts[i - 1][1] + dy * fr; const x = an[0] + (px - an[0]) * k + ox, y = an[1] + (py - an[1]) * k + oy; ctx.save(); ctx.translate(x, y); ctx.rotate(Math.atan2(dy, dx) + (f.side < 0 ? Math.PI : 0)); ctx.scale(k, k); ctx.fillText(f.chars[ci], 0, 0); ctx.restore(); ci++; } }
    }
    ctx.restore();
  }
  function iconCamera(ctx, x, y, a, t, u) {
    if (a <= 0) return; ctx.save(); ctx.globalAlpha = a; ctx.strokeStyle = RED2; ctx.lineWidth = 2.4; ctx.lineJoin = 'round';
    const dr = (p) => clamp(u * 1.5 - p);
    ctx.beginPath(); const bw = 250, bh = 168; ctx.moveTo(x - bw / 2 + 16, y - bh / 2); ctx.lineTo(x - 40, y - bh / 2); ctx.lineTo(x - 26, y - bh / 2 - 24); ctx.lineTo(x + 26, y - bh / 2 - 24); ctx.lineTo(x + 40, y - bh / 2); ctx.lineTo(x + bw / 2 - 16, y - bh / 2); ctx.quadraticCurveTo(x + bw / 2, y - bh / 2, x + bw / 2, y - bh / 2 + 16); ctx.lineTo(x + bw / 2, y + bh / 2 - 16); ctx.quadraticCurveTo(x + bw / 2, y + bh / 2, x + bw / 2 - 16, y + bh / 2); ctx.lineTo(x - bw / 2 + 16, y + bh / 2); ctx.quadraticCurveTo(x - bw / 2, y + bh / 2, x - bw / 2, y + bh / 2 - 16); ctx.lineTo(x - bw / 2, y - bh / 2 + 16); ctx.quadraticCurveTo(x - bw / 2, y - bh / 2, x - bw / 2 + 16, y - bh / 2);
    ctx.globalAlpha = a * dr(0); ctx.stroke();
    const R = 58; ctx.globalAlpha = a * dr(.2); ctx.beginPath(); ctx.arc(x, y + 6, R + 10, 0, TAU); ctx.stroke(); ctx.beginPath(); ctx.arc(x, y + 6, R, 0, TAU); ctx.stroke();
    // 光圈叶片
    const ap = 14 + 26 * (.5 + .5 * Math.cos(t * 2.2)); const rot = t * .6; const P = [...Array(6)].map((_, k) => [x + Math.cos(k * TAU / 6 + rot) * ap, y + 6 + Math.sin(k * TAU / 6 + rot) * ap]);
    ctx.lineWidth = 1.6; ctx.globalAlpha = a * dr(.4);
    for (let k = 0; k < 6; k++) { const p0 = P[k], p1 = P[(k + 1) % 6]; let dx = p1[0] - p0[0], dy = p1[1] - p0[1]; const m = Math.hypot(dx, dy); dx /= m; dy /= m; const ox = p0[0] - x, oy = p0[1] - y - 6; const b = ox * dx + oy * dy, c = ox * ox + oy * oy - R * R; const sN = -b + Math.sqrt(b * b - c); ctx.beginPath(); ctx.moveTo(p0[0], p0[1]); ctx.lineTo(p0[0] + dx * sN, p0[1] + dy * sN); ctx.stroke(); }
    ctx.lineWidth = 2.4; ctx.beginPath(); ctx.rect(x + bw / 2 - 52, y - bh / 2 + 18, 28, 14); ctx.stroke();
    ctx.restore();
  }
  function iconRoad(ctx, x, y, a, t, u) {
    if (a <= 0) return; ctx.save(); ctx.globalAlpha = a; ctx.strokeStyle = RED2; ctx.lineWidth = 2.4; ctx.lineCap = 'round';
    const vx = x + 10, vy = y - 70, by = y + 100; const hw = lerp(0, 150, E.out(clamp(u * 1.4)));
    line(ctx, [[x - 160, vy], [x + 160, vy]], rgba(RED2, .5), 1.4, a * clamp(u * 2));
    line(ctx, [[vx, vy], [x - hw, by]], RED2, 2.4, a); line(ctx, [[vx, vy], [x + hw, by]], RED2, 2.4, a);
    for (let k = 0; k < 7; k++) { const s = ((k / 7 + t * .35) % 1); const s0 = s * s, s1 = Math.min(1, (s + .07) * (s + .07)); const y0 = lerp(vy, by, s0), y1 = lerp(vy, by, s1); ctx.globalAlpha = a * smooth(0, .15, s) * clamp(u * 2 - .5); ctx.lineWidth = 1 + 3 * s; ctx.beginPath(); ctx.moveTo(lerp(vx, x, s0), y0); ctx.lineTo(lerp(vx, x, s1), y1); ctx.stroke(); }
    ctx.restore();
  }
  function iconVolcano(ctx, x, y, a, t, u) {
    if (a <= 0) return; ctx.save(); ctx.globalAlpha = a;
    const g = ctx.createRadialGradient(x, y - 74, 2, x, y - 74, 120); const fl = .75 + .25 * Math.sin(t * 5) * Math.sin(t * 3.1);
    g.addColorStop(0, rgba('#f08a3a', .55 * fl * clamp(u * 2 - .6))); g.addColorStop(.4, rgba(RED2, .18 * fl * clamp(u * 2 - .6))); g.addColorStop(1, rgba(RED2, 0)); ctx.fillStyle = g; ctx.fillRect(x - 130, y - 200, 260, 260);
    const pts = [[x - 170, y + 100], [x - 120, y + 40], [x - 70, y - 30], [x - 36, y - 72], [x - 14, y - 66], [x, y - 76], [x + 16, y - 66], [x + 40, y - 74], [x + 80, y - 20], [x + 130, y + 50], [x + 172, y + 100]];
    line(ctx, partial(pts, E.out(clamp(u * 1.4))), RED2, 2.4, a);
    line(ctx, partial([[x - 6, y - 70], [x - 18, y - 30], [x - 8, y + 10], [x - 30, y + 60]], clamp(u * 2 - .8)), rgba('#e0602a', .9), 2, a);
    ctx.strokeStyle = rgba(RED2, .55); ctx.lineWidth = 1.6;
    for (let k = 0; k < 5; k++) { const v = ((t * .25 + k / 5) % 1); const r = 10 + v * 34; ctx.globalAlpha = a * (1 - v) * clamp(u * 2 - 1); ctx.beginPath(); ctx.arc(x + Math.sin(v * 4 + k) * 20 + v * 30, y - 90 - v * 130, r, 0, TAU); ctx.stroke(); }
    ctx.restore();
    embers(ctx, t, { x0: x - 30, x1: x + 30, y0: y - 80, rise: 200, n: 14, alpha: a * clamp(u * 2 - 1), size: 1.8, seed: 3 });
  }

  scenes.red = (ctx, S) => {
    const t = S.t, c1 = S.cue(1);
    paper(ctx); motes(ctx, t + 120, .6);
    const tSt = at(S, 0, '斯特西克鲁斯'), tAsm = at(S, 0, '写成') - .2, tWing = at(S, 0, '红色翅膀') - .2, tGer = at(S, 0, '革律翁');
    const asm = prog(t, tAsm, tAsm + 3.0, x => x), open = prog(t, tWing, tWing + 2.4, x => x);
    const gOut = E.inOut(prog(t, c1 - .2, c1 + 1.6, x => x));
    // 漂浮的残章
    SCRAPS.forEach((sc, i) => { const a = smooth(.2 + i * .12, 1 + i * .12, t) * (1 - smooth(tAsm + .2 + i * .1, tAsm + 1.6 + i * .1, t)); const x = sc.x + Math.sin(t * .3 + sc.ph) * 12, y = sc.y + Math.cos(t * .27 + sc.ph) * 9; scrap(ctx, sc, x, y, a, t); });
    // 背景中的淡红光晕
    const gl = smooth(tWing, tWing + 2, t) * (1 - gOut); if (gl > 0) { const g = ctx.createRadialGradient(960, 360, 20, 960, 400, 520); g.addColorStop(0, rgba('#e8a080', .22 * gl)); g.addColorStop(1, rgba('#e8a080', 0)); ctx.fillStyle = g; ctx.fillRect(0, 0, W, H); }
    geryon(ctx, t, { cx: 960, cy: 545, asm, open, a: 1 - gOut * .92, sc: lerp(1, .5, gOut) });
    // 说明
    const la = 1 - smooth(c1 - .6, c1 + .2, t);
    tag(ctx, '斯特西克鲁斯 · 残章', 'Stesichoros · Geryoneis', 560, 330, { size: 30, align: 'right', alpha: smooth(tSt, tSt + .8, t) * la, color: INK, enFont: 'latinI', raw: true, enSize: 24, enSpacing: .04 });
    tag(ctx, '诗体小说', 'a novel in verse', 560, 450, { size: 30, align: 'right', alpha: smooth(tAsm + .3, tAsm + 1.1, t) * la, color: INK, enFont: 'latinI', raw: true, enSize: 24, enSpacing: .04 });
    tag(ctx, '革律翁', 'Geryon', 1360, 330, { size: 56, weight: 300, alpha: smooth(tGer - .2, tGer + .7, t) * la, color: RED, enFont: 'latinI', raw: true, enSize: 30, enSpacing: .04, enColor: RED });
    [['敏感', '敏感'], ['孤独', '孤独'], ['坠入爱河', '坠入爱河']].forEach(([w, k], i) => { const tt = at(S, 0, k); text(ctx, w, 1362, 470 + i * 58, { size: 34, font: 'song', weight: 400, color: INK2, alpha: smooth(tt - .1, tt + .6, t) * la, align: 'left', spacing: .2, reveal: prog(t, tt - .1, tt + .6, E.out) }); });
    const tBoy = at(S, 0, '少年'); text(ctx, '——一个少年', 1362, 660, { size: 30, font: 'song', weight: 300, color: INK3, alpha: smooth(tBoy - .2, tBoy + .6, t) * la, align: 'left', spacing: .2 });
    // B：相机、公路、火山
    const tCam = at(S, 1, '相机'), tRoad = at(S, 1, '公路'), tVol = at(S, 1, '火山'), tEnd = at(S, 1, '书的结尾'), tQ1 = at(S, 1, '我们是了不起'), tQ2 = at(S, 1, '我们是火');
    const ia = 1 - smooth(tEnd - .2, tEnd + .8, t);
    const icons = [[iconCamera, 520, tCam, '相机', 'camera'], [iconRoad, 960, tRoad, '公路', 'road'], [iconVolcano, 1400, tVol, '火山', 'volcano']];
    icons.forEach(([fn, x, tt, zh, en]) => { const a = smooth(tt - .5, tt + .3, t) * ia; const u = prog(t, tt - .5, tt + 1.3, x => x); fn(ctx, x, 470, a, t, u); tag(ctx, zh, en, x, 650, { size: 30, align: 'center', alpha: a * smooth(tt, tt + .6, t), mark: false, color: INK }); });
    const ha = smooth(c1 + .4, c1 + 1.4, t) * ia; text(ctx, '神话  →  现代', W / 2, 220, { size: 30, font: 'song', weight: 300, spacing: .4, color: INK3, alpha: ha });
    // 结尾：我们是火的邻居
    const qa = smooth(tEnd + .2, tEnd + 1.2, t);
    if (qa > 0) {
      embers(ctx, t, { x0: 300, x1: 1620, y0: 940, rise: 760, n: 46, alpha: qa * smooth(tQ2 - .5, tQ2 + 1, t) * .9 + qa * .25, size: 2.2, life: 4.5, seed: 9, wind: 40 });
      geryon(ctx, t, { cx: 960, cy: 600, asm: 1, open: 1, a: qa * .09, sc: 1.25 });
      const cols = [['我们是了不起的生灵', 1050, tQ1], ['我们是火的邻居', 880, tQ2]];
      for (const [str, x, tt] of cols) { const chs = [...str]; chs.forEach((ch, i) => { const a = qa * smooth(tt - .2 + i * .1, tt + .3 + i * .1, t); if (a <= 0) return; const isF = ch === '火'; const y = 232 + i * 70; if (isF) { const g = ctx.createRadialGradient(x, y, 2, x, y, 70); g.addColorStop(0, rgba('#f0a060', .35 * a)); g.addColorStop(1, rgba('#f0a060', 0)); ctx.fillStyle = g; ctx.fillRect(x - 70, y - 70, 140, 140); } text(ctx, ch, x, y + (1 - a) * 10, { size: 60, font: 'song', weight: isF ? 600 : 400, color: isF ? RED2 : INK, alpha: a }); }); }
      tag(ctx, '《红的自传》', 'Autobiography of Red · 1998', 1250, 760, { size: 28, alpha: qa * smooth(tQ1 + .6, tQ1 + 1.6, t), color: INK, enFont: 'latinI', raw: true, enSize: 26, enSpacing: .04 });
    }
  };

  // ---------- 6. 方括号：想象自由冒险的空间 ----------
  // 书页上的诗行：[文字, 括号缺口宽度(0=无), 缺口所在的字符偏移]
  const PAGE = [['……爱欲又一次摇撼我', 0], ['', 300], ['甜苦，无可抵御', 0], ['', 170, 120], ['……', 0]];
  const GHOSTS = (() => { const r = rng(2002); return [...Array(14)].map((_, i) => { const ring = i % 2; const x = ring ? 470 + r() * 980 : (i % 4 < 2 ? 420 + r() * 150 : 1350 + r() * 150), y = ring ? (i % 4 === 1 ? 250 + r() * 60 : 700 + r() * 50) : 300 + r() * 360; return ({ kind: i % 7, x, y, t0: r() * 3.2, s: .7 + r() * .6, dx: (r() - .5) * 60, dy: -20 - r() * 40, rot: (r() - .5) * .5 }); }); })();
  function ghost(ctx, g, x, y, s, a) {
    if (a <= 0) return; ctx.save(); ctx.translate(x, y); ctx.rotate(g.rot); ctx.scale(s, s); ctx.globalAlpha = a; ctx.strokeStyle = INK3; ctx.lineWidth = 1.6 / s; ctx.lineCap = 'round'; ctx.beginPath();
    switch (g.kind) {
      case 0: ctx.arc(0, 0, 26, -1.9, 1.9); ctx.arc(10, 0, 22, 1.75, -1.75, true); break; // 新月
      case 1: ctx.moveTo(-30, 0); ctx.quadraticCurveTo(-15, -16, 0, 0); ctx.quadraticCurveTo(15, -16, 30, 0); break; // 飞鸟
      case 2: for (let i = 0; i <= 40; i++) { const u = i / 40; ctx.lineTo(-40 + u * 80, Math.sin(u * 9) * 8 * (1 - u * .4)); } break; // 波
      case 3: ctx.moveTo(-34, 6); ctx.quadraticCurveTo(0, 22, 34, 6); ctx.moveTo(0, 10); ctx.lineTo(0, -40); ctx.lineTo(24, 0); ctx.lineTo(0, 0); break; // 小船
      case 4: ctx.moveTo(0, -22); ctx.quadraticCurveTo(2, -2, 22, 0); ctx.quadraticCurveTo(2, 2, 0, 22); ctx.quadraticCurveTo(-2, 2, -22, 0); ctx.quadraticCurveTo(-2, -2, 0, -22); break; // 星
      case 5: ctx.moveTo(0, 24); ctx.quadraticCurveTo(-4, 0, 0, -26); ctx.moveTo(0, 0); ctx.quadraticCurveTo(-20, -6, -24, -22); ctx.moveTo(0, -8); ctx.quadraticCurveTo(18, -12, 20, -28); break; // 草
      case 6: ctx.arc(0, 0, 18, 0, TAU); ctx.moveTo(-36, 0); ctx.lineTo(-24, 0); ctx.moveTo(24, 0); ctx.lineTo(36, 0); ctx.moveTo(0, -36); ctx.lineTo(0, -24); break; // 日
    }
    ctx.stroke(); ctx.restore();
  }
  function pageLines(ctx, x0, y0, a, t, tw, gapK) {
    PAGE.forEach(([str, gap, off], i) => { const y = y0 + i * 82; const la = a * smooth(tw + i * .35, tw + .6 + i * .35, t); if (str) text(ctx, str, x0, y, { size: 42, font: 'song', weight: 300, color: INK, alpha: la, align: 'left', spacing: .14 }); if (gap) { const g = gap * gapK; const cx = x0 + (off || 0) + gap / 2; bracket(ctx, cx - g / 2, y, 58, -1, smooth(tw + i * .35, tw + .5 + i * .35, t), { w: 3, alpha: a }); bracket(ctx, cx + g / 2, y, 58, 1, smooth(tw + i * .35, tw + .5 + i * .35, t), { w: 3, alpha: a }); } });
  }
  const OLD = [['蒹', '葭', '苍', '□'], ['白', '□', '为', '霜'], ['所', '谓', '伊', '人'], ['在', '水', '□', '方']];

  scenes.brackets = (ctx, S) => {
    const t = S.t, c1 = S.cue(1);
    paper(ctx); motes(ctx, t + 150, .6);
    const tSay = at(S, 0, '她说'), tIm = at(S, 0, '想象'), tGu = at(S, 1, '古籍'), tQz = at(S, 1, '缺字'), tLb = at(S, 1, '留白'), tYx = at(S, 1, '遥相呼应');
    const zoom = E.inOut(prog(t, tSay - .4, tSay + 1.0, x => x)); const back = E.inOut(prog(t, c1 - .5, c1 + .9, x => x));
    // 书页
    const pa = (1 - smooth(tSay - .2, tSay + .6, t));
    if (pa > 0) {
      ctx.save(); ctx.globalAlpha = pa; ctx.shadowColor = 'rgba(80,50,20,.16)'; ctx.shadowBlur = 40; ctx.shadowOffsetY = 14; ctx.fillStyle = '#f7f1e4'; ctx.fillRect(560, 150, 800, 700); ctx.restore();
      ctx.save(); ctx.globalAlpha = pa; const gg = ctx.createLinearGradient(560, 0, 620, 0); gg.addColorStop(0, 'rgba(120,90,50,.16)'); gg.addColorStop(1, 'rgba(120,90,50,0)'); ctx.fillStyle = gg; ctx.fillRect(560, 150, 60, 700); ctx.restore();
      text(ctx, 'SAPPHO', 960, 228, { size: 16, font: 'latin', weight: 600, spacing: .6, color: INK3, alpha: pa * smooth(.4, 1.2, t) });
      text(ctx, '萨福 · 残篇（示意）', 960, 262, { size: 22, font: 'song', weight: 400, spacing: .2, color: INK3, alpha: pa * smooth(.4, 1.2, t) });
      pageLines(ctx, 700, 380, pa, t, .6, lerp(.08, 1, E.out(prog(t, 1.2, 3.2, x => x))));
      text(ctx, '130', 960, 806, { size: 18, font: 'latin', weight: 500, color: INK3, alpha: pa * .8 });
    }
    // 括号放大成为一个空间
    const qa = smooth(tSay - .2, tSay + .6, t);
    if (qa > 0) {
      const src = { x: 700 + 150, y: 380 + 82, g: 300, h: 58 }; const dst = { x: 960, y: 470, g: 1260, h: 560 }; const sm = { x: 960, y: 470, g: 150, h: 120 };
      const cur = zoom < 1 || back <= 0 ? { x: lerp(src.x, dst.x, zoom), y: lerp(src.y, dst.y, zoom), g: lerp(src.g, dst.g, zoom), h: lerp(src.h, dst.h, zoom) } : { x: lerp(dst.x, sm.x, back), y: lerp(dst.y, sm.y, back), g: lerp(dst.g, sm.g, back), h: lerp(dst.h, sm.h, back) };
      const bw = lerp(3, 7, zoom) * lerp(1, .6, back);
      // 括号内微亮
      const ia = qa * (1 - back); if (ia > 0) { const g = ctx.createRadialGradient(cur.x, cur.y, 0, cur.x, cur.y, cur.g * .6); g.addColorStop(0, rgba('#fffaf0', .55 * ia)); g.addColorStop(1, rgba('#fffaf0', 0)); ctx.fillStyle = g; ctx.fillRect(cur.x - cur.g, cur.y - cur.h, cur.g * 2, cur.h * 2); }
      bracket(ctx, cur.x - cur.g / 2, cur.y, cur.h, -1, 1, { w: bw, arm: Math.min(cur.h * .2, 70) });
      bracket(ctx, cur.x + cur.g / 2, cur.y, cur.h, 1, 1, { w: bw, arm: Math.min(cur.h * .2, 70) });
      // 想象的游影
      const ga = (1 - back) * smooth(tIm - .6, tIm + .4, t);
      if (ga > 0) GHOSTS.forEach(g => { const lt = t - tIm + .6 - g.t0; if (lt < 0) return; const e = Math.sin(Math.PI * clamp(lt / 3.4)); ghost(ctx, g, g.x + g.dx * lt / 3.4, g.y + g.dy * lt / 3.4, g.s, ga * e * .55); });
      // 引文
      const ta = smooth(tSay + .5, tSay + 1.3, t) * (1 - smooth(c1 - .6, c1 + .1, t));
      text(ctx, '方括号里，是一片', 960, 400, { size: 60, font: 'song', weight: 300, spacing: .16, color: INK, alpha: ta, reveal: prog(t, tSay + .5, tSay + 1.6, E.out) });
      text(ctx, '供想象自由冒险的空间', 960, 492, { size: 60, font: 'song', weight: 300, spacing: .16, color: INK, alpha: ta, reveal: prog(t, tSay + 1.4, tSay + 2.8, E.out) });
      text(ctx, '“Brackets imply a free space of imaginal adventure.”', 960, 576, { size: 30, font: 'latinI', color: INK2, alpha: ta * smooth(tIm, tIm + 1, t) });
      tag(ctx, '安妮·卡森《若非，冬季：萨福断章》', 'If Not, Winter · 2002', 960, 652, { size: 24, align: 'center', mark: false, alpha: ta * smooth(tIm + .6, tIm + 1.6, t), color: INK3, enFont: 'latinI', raw: true, enSize: 22, enSpacing: .04 });
    }
    // B：古籍缺字 · 留白
    const ba = smooth(c1 - .1, c1 + .9, t);
    if (ba > 0) {
      // 左：古籍
      const lx = 260, ly = 220, lw = 470, lh = 560;
      ctx.save(); ctx.globalAlpha = ba; ctx.fillStyle = 'rgba(214,196,160,.28)'; ctx.fillRect(lx, ly, lw, lh); ctx.strokeStyle = rgba(RED, .45); ctx.lineWidth = 1; for (let k = 0; k <= 5; k++) { const x = lx + 40 + k * (lw - 80) / 5; ctx.beginPath(); ctx.moveTo(x, ly + 30); ctx.lineTo(x, ly + lh - 30); ctx.stroke(); } ctx.strokeRect(lx + 20, ly + 20, lw - 40, lh - 40); ctx.restore();
      OLD.forEach((col, ci) => { const x = lx + 40 + (lw - 80) / 5 * (4 - ci) + (lw - 80) / 10 - (lw - 80) / 5 * .0; col.forEach((ch, ri) => { const y = ly + 100 + ri * 104; const a = ba * smooth(tGu - .3 + ci * .15 + ri * .05, tGu + .3 + ci * .15 + ri * .05, t); if (ch === '□') { const qq = smooth(tQz - .3, tQz + .4, t); ctx.save(); ctx.globalAlpha = a; ctx.strokeStyle = rgba(mix(INK, RED2, qq)); ctx.lineWidth = 2.2; ctx.strokeRect(x - 26, y - 26, 52, 52); if (qq > 0) { const g = ctx.createRadialGradient(x, y, 0, x, y, 70); g.addColorStop(0, rgba(RED2, .14 * qq)); g.addColorStop(1, rgba(RED2, 0)); ctx.fillStyle = g; ctx.fillRect(x - 70, y - 70, 140, 140); } ctx.restore(); } else text(ctx, ch, x, y, { size: 58, font: 'song', weight: 500, color: INK, alpha: a }); }); });
      tag(ctx, '古籍缺字', 'lacunae in old texts', lx + lw / 2, ly + lh + 52, { size: 28, align: 'center', mark: false, alpha: ba * smooth(tQz, tQz + .7, t), color: INK });
      // 右：留白山水
      const rx = 1190, ry = 220, rw = 470, rh = 560; const ra = ba * smooth(tLb - 1.2, tLb + .2, t);
      if (ra > 0) {
        { const O = OFF[2], og = O.getContext('2d'); og.setTransform(1, 0, 0, 1, 0, 0); og.globalCompositeOperation = 'source-over'; og.globalAlpha = 1; og.clearRect(0, 0, W, H); og.drawImage(TEX.mount2, 0, 0, W, H, rx - 420, ry + 40, W * .62, H * .62);
          og.globalCompositeOperation = 'destination-in'; const mg2 = og.createRadialGradient(rx + rw * .45, ry + rh * .62, 40, rx + rw * .45, ry + rh * .62, rw * .62); mg2.addColorStop(0, 'rgba(0,0,0,1)'); mg2.addColorStop(.7, 'rgba(0,0,0,.8)'); mg2.addColorStop(1, 'rgba(0,0,0,0)'); og.fillStyle = mg2; og.fillRect(0, 0, W, H); og.globalCompositeOperation = 'source-over';
          ctx.save(); ctx.globalAlpha = ra * .9; ctx.drawImage(O, 0, 0); ctx.restore(); }
        ctx.save(); ctx.globalAlpha = ra; ctx.strokeStyle = rgba(INK2, .9); ctx.lineWidth = 1.6; const bx = rx + 300 + Math.sin(t * .5) * 4, by = ry + 452; ctx.beginPath(); ctx.moveTo(bx - 22, by); ctx.quadraticCurveTo(bx, by + 8, bx + 22, by); ctx.stroke(); ctx.beginPath(); ctx.moveTo(bx + 4, by - 2); ctx.lineTo(bx + 4, by - 14); ctx.stroke(); ctx.restore();
        tag(ctx, '留白', 'the empty space in ink painting', rx + rw / 2, ry + rh + 52, { size: 28, align: 'center', mark: false, alpha: ra * smooth(tLb, tLb + .7, t), color: INK });
      }
      const ya = smooth(tYx - .3, tYx + .5, t); text(ctx, '遥相呼应', 960, 610, { size: 30, font: 'song', weight: 400, spacing: .4, color: INK2, alpha: ya });
      text(ctx, '（解读性联想）', 960, 652, { size: 20, font: 'song', weight: 400, spacing: .2, color: INK3, alpha: ya * .9 });
    }
  };

  // ---------- 7. 夜：盒中的手风琴长卷，以及“翻译像一个房间” ----------
  const DICT = [['multus, -a, -um', 'adj.', 'much, many;', 'great in number.'], ['gēns, gentis', 'f.', 'clan, race, people;', 'a nation.'], ['aequor, -oris', 'n.', 'a level surface;', 'the sea.'], ['vehō, vehere, vexī, vectum', 'v.', 'to carry, convey;', 'pass. to travel, sail.'], ['frāter, frātris', 'm.', 'brother.', ''], ['avē', 'interj.', 'hail!  ·  valē, farewell.', '']];
  const NPAN = 12, PW = 220, PH = 320;
  function makeDictPanel(e, i) {
    const s = 1.5, c = mk(PW * s, PH * s), g = c.getContext('2d'); const r = rng(300 + i);
    g.fillStyle = '#f3ede0'; g.fillRect(0, 0, c.width, c.height);
    for (let k = 0; k < 900; k++) { g.fillStyle = `rgba(120,100,70,${r() * .06})`; g.fillRect(r() * c.width, r() * c.height, 1.5, 1.5); }
    g.fillStyle = INK; g.textBaseline = 'alphabetic'; g.font = font('latin', 34, 700); const head = e[0]; let fs = 34; while (g.measureText(head).width > c.width - 50 && fs > 18) { fs -= 2; g.font = font('latin', fs, 700); } g.fillText(head, 26, 74);
    g.font = font('latinI', 26, 400); g.fillStyle = INK3; g.fillText(e[1], 26, 110);
    g.font = font('latin', 27, 500); g.fillStyle = INK2; g.fillText(e[2], 26, 152); if (e[3]) g.fillText(e[3], 26, 186);
    g.strokeStyle = 'rgba(60,50,40,.28)'; g.lineWidth = 3; for (let l = 0; l < 13; l++) { const y = 232 + l * 26; let x = 26; const end = c.width - 26 - (l % 4 === 3 ? 120 * r() : 0); while (x < end) { const L = 12 + r() * 46; g.beginPath(); g.moveTo(x, y); g.lineTo(Math.min(end, x + L), y); g.stroke(); x += L + 8; } }
    g.font = font('latin', 20, 600); g.fillStyle = RED; g.fillText(String(i + 1).padStart(2, '0'), c.width - 50, 40);
    return c;
  }
  function makeCollagePanel(i) {
    const s = 1.5, c = mk(PW * s, PH * s), g = c.getContext('2d'); const r = rng(700 + i);
    g.fillStyle = '#dcd8d0'; g.fillRect(0, 0, c.width, c.height);
    for (let k = 0; k < 1200; k++) { g.fillStyle = `rgba(60,55,50,${r() * .07})`; g.fillRect(r() * c.width, r() * c.height, 2, 2); }
    // 旧照片
    const px = 30 + r() * 30, py = 30 + r() * 60, pw = 220 + r() * 40, ph = 160 + r() * 30;
    g.save(); g.translate(px + pw / 2, py + ph / 2); g.rotate((r() - .5) * .16); g.fillStyle = '#f2efe8'; g.fillRect(-pw / 2 - 10, -ph / 2 - 10, pw + 20, ph + 34);
    const gr = g.createLinearGradient(0, -ph / 2, 0, ph / 2); gr.addColorStop(0, '#b9b6b0'); gr.addColorStop(1, '#7c7974'); g.fillStyle = gr; g.fillRect(-pw / 2, -ph / 2, pw, ph);
    const fx = (r() - .5) * pw * .5; soft(g, 5, 'rgba(40,38,36,.7)', g => { g.beginPath(); g.ellipse(fx, -ph * .12, 16, 18, 0, 0, TAU); g.fill(); g.beginPath(); g.ellipse(fx, ph * .28, 32, 50, 0, 0, TAU); g.fill(); }); soft(g, 5, 'rgba(230,228,222,.5)', g => g.fillRect(-pw / 2, ph * .3, pw, ph * .2)); g.restore();
    // 手写信笺
    g.save(); g.translate(40 + r() * 40, 300 + r() * 40); g.rotate((r() - .5) * .2); g.fillStyle = '#efe9da'; g.fillRect(0, 0, 230, 130); g.strokeStyle = 'rgba(40,40,70,.75)'; g.lineWidth = 1.6;
    for (let l = 0; l < 5; l++) { g.beginPath(); let x = 14; const y = 24 + l * 22; g.moveTo(x, y); while (x < 200 - r() * 40) { x += 4; g.lineTo(x, y + Math.sin(x * .45 + l * 2 + r()) * 4 * (r() < .2 ? 2 : 1)); } g.stroke(); }
    g.restore();
    // 胶带
    g.fillStyle = 'rgba(240,235,215,.6)'; g.save(); g.translate(px + 20, py); g.rotate(-.5); g.fillRect(-26, -9, 52, 18); g.restore();
    return c;
  }
  function makeLid() { const c = mk(300, 420), g = c.getContext('2d'); g.fillStyle = '#8f8e8a'; g.fillRect(0, 0, 300, 420); const r = rng(5); for (let k = 0; k < 2000; k++) { g.fillStyle = `rgba(${r() < .5 ? 255 : 0},${r() < .5 ? 255 : 0},${r() < .5 ? 255 : 0},${r() * .05})`; g.fillRect(r() * 300, r() * 420, 2, 2); } g.fillStyle = '#6f6e6a'; g.fillRect(70, 90, 160, 120); g.filter = 'blur(4px)'; g.fillStyle = '#3e3d3a'; g.beginPath(); g.ellipse(150, 135, 14, 16, 0, 0, TAU); g.fill(); g.beginPath(); g.ellipse(150, 190, 30, 30, 0, 0, TAU); g.fill(); g.filter = 'none'; g.fillStyle = '#e8e6e0'; g.font = font('latin', 46, 600); g.textAlign = 'center'; g.fillText('N O X', 150, 300); return c; }
  function makeStack() { const c = mk(280, 400), g = c.getContext('2d'); g.fillStyle = '#ede6d6'; g.fillRect(0, 0, 280, 400); g.strokeStyle = 'rgba(90,70,50,.35)'; g.lineWidth = 1; for (let k = 0; k < 38; k++) { const y = 6 + k * 10.3; g.beginPath(); g.moveTo(0, y); g.lineTo(280, y); g.stroke(); } return c; }
  // 透视贴图：按纵条细分，每条做仿射映射
  function mapPanel(ctx, img, c, P3, nu, a, nv = 1) {
    if (a <= 0) return; const sw = img.width / nu, sh = img.height / nv;
    const pr = (u, v) => { const x = lerp(lerp(P3[0][0], P3[1][0], u), lerp(P3[3][0], P3[2][0], u), v), y = lerp(lerp(P3[0][1], P3[1][1], u), lerp(P3[3][1], P3[2][1], u), v), z = lerp(lerp(P3[0][2], P3[1][2], u), lerp(P3[3][2], P3[2][2], u), v); return c.p(x, y, z); };
    const G = []; for (let j = 0; j <= nv; j++) { const row = []; for (let k = 0; k <= nu; k++) row.push(pr(k / nu, j / nv)); G.push(row); }
    ctx.save(); ctx.globalAlpha = a;
    for (let j = 0; j < nv; j++) for (let k = 0; k < nu; k++) { const s0 = [k * sw, j * sh], s1 = [(k + 1) * sw, j * sh], s2 = [(k + 1) * sw, (j + 1) * sh], s3 = [k * sw, (j + 1) * sh]; const d0 = G[j][k], d1 = G[j][k + 1], d2 = G[j + 1][k + 1], d3 = G[j + 1][k]; triMap(ctx, img, s0, s1, s2, d0, d1, d2); triMap(ctx, img, s0, s2, s3, d0, d2, d3); }
    ctx.restore();
  }
  function triMap(ctx, img, s0, s1, s2, d0, d1, d2) {
    const x0 = s0[0], y0 = s0[1], x1 = s1[0], y1 = s1[1], x2 = s2[0], y2 = s2[1]; const u0 = d0.x, v0 = d0.y, u1 = d1.x, v1 = d1.y, u2 = d2.x, v2 = d2.y;
    const den = (x1 - x0) * (y2 - y0) - (x2 - x0) * (y1 - y0); if (Math.abs(den) < 1e-6) return;
    const A = ((u1 - u0) * (y2 - y0) - (u2 - u0) * (y1 - y0)) / den, C = ((u2 - u0) * (x1 - x0) - (u1 - u0) * (x2 - x0)) / den;
    const B = ((v1 - v0) * (y2 - y0) - (v2 - v0) * (y1 - y0)) / den, D = ((v2 - v0) * (x1 - x0) - (v1 - v0) * (x2 - x0)) / den;
    const cx = (u0 + u1 + u2) / 3, cy = (v0 + v1 + v2) / 3; const ex = (x, y) => { const dx = x - cx, dy = y - cy, m = Math.hypot(dx, dy) || 1; return [x + dx / m * .9, y + dy / m * .9]; };
    ctx.save(); ctx.beginPath(); const e0 = ex(u0, v0), e1 = ex(u1, v1), e2 = ex(u2, v2); ctx.moveTo(e0[0], e0[1]); ctx.lineTo(e1[0], e1[1]); ctx.lineTo(e2[0], e2[1]); ctx.closePath(); ctx.clip();
    ctx.transform(A, B, C, D, u0 - A * x0 - C * y0, v0 - B * x0 - D * y0); ctx.drawImage(img, 0, 0); ctx.restore();
  }
  function poly3(ctx, c, P3, fill, a) { if (a <= 0) return; ctx.save(); ctx.globalAlpha = a; ctx.fillStyle = fill; ctx.beginPath(); P3.forEach((p, i) => { const q = c.p(p[0], p[1], p[2]); i ? ctx.lineTo(q.x, q.y) : ctx.moveTo(q.x, q.y); }); ctx.closePath(); ctx.fill(); ctx.restore(); }
  const HAND = [[-38, 40], [-48, -40], [-54, -62], [-92, -96], [-110, -122], [-100, -134], [-70, -112], [-47, -114], [-52, -190], [-41, -206], [-30, -192], [-26, -122], [-20, -126], [-19, -210], [-6, -224], [6, -210], [4, -128], [10, -126], [16, -196], [27, -207], [35, -193], [28, -118], [32, -110], [45, -160], [53, -169], [60, -156], [50, -94], [45, -40], [37, 40]];
  function hand(ctx, x, y, rot, s, a, lit) {
    if (a <= 0) return; ctx.save(); ctx.translate(x, y); ctx.rotate(rot); ctx.scale(s, s); ctx.globalAlpha = a;
    ctx.beginPath(); for (let i = 0; i < HAND.length; i++) { const p = HAND[i], q = HAND[(i + 1) % HAND.length]; const m = [(p[0] + q[0]) / 2, (p[1] + q[1]) / 2]; if (i === 0) ctx.moveTo(m[0], m[1]); else ctx.quadraticCurveTo(p[0], p[1], m[0], m[1]); } ctx.closePath();
    ctx.fillStyle = rgba(mix('#3a2e24', '#e8d8bc', lit), .55); ctx.fill(); ctx.strokeStyle = rgba(mix('#c8b490', INK2, lit), .9); ctx.lineWidth = 2 / s; ctx.stroke();
    ctx.restore();
  }
  const ROOMTXT = ['multas per gentes et multa per aequora vectus', 'advenio has miseras, frater, ad inferias', 'ut te postremo donarem munere mortis', 'et mutam nequiquam alloquerer cinerem', 'atque in perpetuum, frater, ave atque vale'];

  scenes.nox = (ctx, S) => {
    const t = S.t, c1 = S.cue(1), c2 = S.cue(2);
    paper(ctx);
    const tBook = at(S, 0, '做了一本书'), tStrip = at(S, 0, '一整张长纸'), tFold = at(S, 0, '折成手风琴'), tBox = at(S, 0, '装进');
    // A：灰色的盒子
    const boxA = smooth(.3, 1.4, t) * (1 - smooth(tStrip + .6, tStrip + 1.6, t));
    if (boxA > 0) {
      const lift = E.inOut(prog(t, tBook + .6, tStrip + .6, x => x)); const th = lift * 1.75;
      const c = cam({ yaw: .42 + t * .02, pitch: .62, dist: 1150, fov: 1250, cy: H * .52 - 40 * lift, cx: W / 2 });
      const sh = ctx.createRadialGradient(W / 2, H * .62, 50, W / 2, H * .62, 420); sh.addColorStop(0, rgba('#3a2a1a', .22 * boxA)); sh.addColorStop(1, rgba('#3a2a1a', 0)); ctx.fillStyle = sh; ctx.fillRect(0, 0, W, H);
      const X0 = -150, X1 = 150, Z0 = -210, Z1 = 210, Y0 = 40, Y1 = 140;
      poly3(ctx, c, [[X0, Y0, Z1], [X1, Y0, Z1], [X1, Y1, Z1], [X0, Y1, Z1]], '#7a7975', boxA); // 后壁（内侧）
      poly3(ctx, c, [[X1, Y0, Z0], [X1, Y0, Z1], [X1, Y1, Z1], [X1, Y1, Z0]], '#83827e', boxA);
      mapPanel(ctx, TEX.noxStack, c, [[X0 + 10, Y0 + 14, Z1 - 10], [X1 - 10, Y0 + 14, Z1 - 10], [X1 - 10, Y0 + 14, Z0 + 10], [X0 + 10, Y0 + 14, Z0 + 10]], 3, boxA, 3);
      poly3(ctx, c, [[X0, Y0, Z0], [X0, Y0, Z1], [X0, Y1, Z1], [X0, Y1, Z0]], '#9e9d99', boxA);
      poly3(ctx, c, [[X0, Y0, Z0], [X1, Y0, Z0], [X1, Y1, Z0], [X0, Y1, Z0]], '#a9a8a4', boxA);
      // 盒盖：绕后缘抬起
      const L = 420, hz = Z1 + 4; const lp = (x, sOff, yOff) => [x, Y0 - 2 - sOff * Math.sin(th) + yOff * Math.cos(th), hz - sOff * Math.cos(th) - yOff * Math.sin(th)];
      const la = boxA * (1 - smooth(tStrip - .2, tStrip + .6, t));
      poly3(ctx, c, [lp(X0 - 6, L + 8, 0), lp(X1 + 6, L + 8, 0), lp(X1 + 6, L + 8, 14), lp(X0 - 6, L + 8, 14)], '#7d7c78', la);
      mapPanel(ctx, TEX.noxLid, c, [lp(X0 - 6, 0, -12), lp(X1 + 6, 0, -12), lp(X1 + 6, L + 8, -12), lp(X0 - 6, L + 8, -12)], 3, la, 4);
    }
    // B：手风琴长卷
    const sa = smooth(tStrip + .2, tStrip + 1.2, t) * (1 - smooth(c2 - 1.2, c2 - .2, t));
    if (sa > 0) {
      const rise = E.out(prog(t, tStrip + .2, tStrip + 1.6, x => x)); const unf = prog(t, tFold - .6, tBox + 1.6, x => x);
      const foc = E.inOut(prog(t, c1 - .4, c1 + 2, x => x)), foc2 = E.inOut(prog(t, at(S, 1, '另一侧') - .5, at(S, 1, '另一侧') + 1.6, x => x));
      // 顶点
      const V = [[0, 0]]; for (let i = 0; i < NPAN; i++) { const g = lerp(86, 38, E.inOut(clamp(unf * 1.5 - i / NPAN * .5))) * Math.PI / 180; const [x, z] = V[i]; V.push([x + PW * Math.cos(g), z + (i % 2 ? -1 : 1) * PW * Math.sin(g)]); }
      const span = V[NPAN][0]; const midx = span / 2;
      const p4 = (V[4][0] + V[5][0]) / 2, p5 = (V[5][0] + V[6][0]) / 2;
      const tx = lerp(lerp(midx, p4, foc), p5, foc2), dist = lerp(lerp(2000, 1180, foc), 1180, foc2) - 300 * (1 - unf) * 0;
      const c = cam({ yaw: lerp(-.28, -.18, foc), pitch: .10, dist, fov: 1350, cx: W / 2, cy: H * .47, tx, ty: lerp(380, 0, rise), tz: 60 });
      const order = [...Array(NPAN).keys()].map(i => ({ i, z: c.p((V[i][0] + V[i + 1][0]) / 2, 0, (V[i][1] + V[i + 1][1]) / 2).z })).sort((p, q) => q.z - p.z);
      // 地面投影
      ctx.save(); ctx.globalAlpha = sa * .22 * rise; const gp = V.map(([x, z]) => c.p(x, PH / 2 + 6, z)), gq = V.map(([x, z]) => c.p(x + 30, PH / 2 + 6, z + 60)); soft(ctx, 14, '#4a3a28', g => { g.beginPath(); gp.forEach((q, i) => i ? g.lineTo(q.x, q.y) : g.moveTo(q.x, q.y)); for (let i = NPAN; i >= 0; i--) g.lineTo(gq[i].x, gq[i].y); g.closePath(); g.fill(); }); ctx.restore();
      for (const { i } of order) {
        const P3 = [[V[i][0], -PH / 2, V[i][1]], [V[i + 1][0], -PH / 2, V[i + 1][1]], [V[i + 1][0], PH / 2, V[i + 1][1]], [V[i][0], PH / 2, V[i][1]]];
        const tl = c.p(...P3[0]), tr = c.p(...P3[1]), bl = c.p(...P3[3]); const front = (tr.x - tl.x) * (bl.y - tl.y) - (tr.y - tl.y) * (bl.x - tl.x) > 0;
        if (front) mapPanel(ctx, TEX.noxPan[i], c, P3, 6, sa); else poly3(ctx, c, P3, '#e6dfcf', sa);
        const nx = V[i + 1][1] - V[i][1]; const shade = (i % 2 ? .10 : .02) + (front ? 0 : .08); poly3(ctx, c, P3, '#2a1e12', sa * shade);
        ctx.save(); ctx.globalAlpha = sa * .5; ctx.strokeStyle = 'rgba(80,64,44,.6)'; ctx.lineWidth = 1; ctx.beginPath(); P3.forEach((p, k) => { const q = c.p(...p); k ? ctx.lineTo(q.x, q.y) : ctx.moveTo(q.x, q.y); }); ctx.closePath(); ctx.stroke(); ctx.restore(); void nx;
      }
      // 注记
      const a1 = smooth(c1 + .6, c1 + 1.4, t) * (1 - smooth(at(S, 1, '另一侧') - .4, at(S, 1, '另一侧') + .3, t)) * sa;
      const q4 = c.p((V[4][0] + V[5][0]) / 2, -PH / 2, (V[4][1] + V[5][1]) / 2);
      tag(ctx, '逐词查考 · 卡图卢斯第 101 首', 'Catullus 101 · word by word', q4.x, Math.min(q4.y - 60, 200), { size: 30, align: 'center', mark: false, alpha: a1, color: INK, enFont: 'latinI', raw: true, enSize: 26, enSpacing: .04 });
      const a2 = smooth(at(S, 1, '另一侧') + .1, at(S, 1, '另一侧') + .8, t) * sa;
      const q5 = c.p((V[5][0] + V[6][0]) / 2, -PH / 2, (V[5][1] + V[6][1]) / 2);
      tag(ctx, '照片 · 信件 · 记忆的碎片', 'photographs · letters · fragments', q5.x, Math.min(q5.y - 60, 200), { size: 30, align: 'center', mark: false, alpha: a2, color: INK, enSize: 15 });
      tag(ctx, 'Nox《夜》', '2010', 150, 830, { size: 30, alpha: sa * smooth(tFold, tFold + 1, t), color: INK, enFont: 'latin', enSize: 20 });
      text(ctx, '一整张长纸 · 折成手风琴', W / 2, 860, { size: 26, font: 'song', weight: 300, spacing: .3, color: INK3, alpha: sa * smooth(tFold, tFold + .8, t) * (1 - smooth(c1 - .4, c1 + .4, t)) });
    }
    // C：黑暗的房间
    const ra = smooth(c2 - 1.2, c2 - .2, t);
    if (ra > 0) {
      const tGrope = at(S, 2, '摸索'), tSw = at(S, 2, '电灯开关') + .05, tRoom = at(S, 2, '翻译像');
      const light = E.out(prog(t, tSw, tSw + .35, x => x));
      const VX = 960, VY = 450, bx0 = 700, bx1 = 1220, by0 = 300, by1 = 600;
      // 房间：墙面写满诗行
      const ink = (a) => rgba(INK2, a);
      ctx.save(); ctx.lineCap = 'round';
      for (let k = 0; k < 16; k++) { const v = (k + .5) / 16; const yL = lerp(by0, by1, v); const y0 = lerp(-60, H + 60, v); for (const side of [-1, 1]) { const xE = side < 0 ? 0 : W, xB = side < 0 ? bx0 : bx1; let u = 0; const r = hash(k, side + 5); while (u < 1) { const L = .03 + hash(k * 13 + Math.floor(u * 50), side + 7) * .08; const u1 = Math.min(1, u + L); const p0 = [lerp(xE, xB, Math.pow(u, .8)), lerp(y0, yL, Math.pow(u, .8))], p1 = [lerp(xE, xB, Math.pow(u1, .8)), lerp(y0, yL, Math.pow(u1, .8))]; ctx.strokeStyle = ink(.32); ctx.lineWidth = lerp(5, 1.4, u); ctx.beginPath(); ctx.moveTo(p0[0], p0[1]); ctx.lineTo(p1[0], p1[1]); ctx.stroke(); u = u1 + .012 + r * .01; } } }
      ctx.restore();
      ctx.save(); ctx.strokeStyle = ink(.5); ctx.lineWidth = 1.2; ctx.strokeRect(bx0, by0, bx1 - bx0, by1 - by0); for (const [x, y] of [[0, -60], [W, -60], [0, H + 60], [W, H + 60]]) { ctx.beginPath(); ctx.moveTo(x, y); ctx.lineTo(x < VX ? bx0 : bx1, y < VY ? by0 : by1); ctx.stroke(); } ctx.restore();
      ROOMTXT.forEach((l, i) => text(ctx, l, VX, i < 2 ? by0 - 120 + i * 40 : by1 + 70 + (i - 2) * 40, { size: 24, font: 'latinI', color: INK3, alpha: .6 * ra }));
      // 开关
      const swx = 1390, swy = 560; ctx.save(); ctx.fillStyle = '#efe8da'; ctx.strokeStyle = ink(.7); ctx.lineWidth = 1.5; ctx.beginPath(); ctx.rect(swx - 22, swy - 34, 44, 68); ctx.fill(); ctx.stroke(); ctx.fillStyle = INK2; const fl = light > 0 ? -1 : 1; ctx.fillRect(swx - 6, swy - 4 + fl * 8, 12, 14); ctx.restore();
      // 黑暗
      const dark = ra * (1 - light);
      if (dark > 0) { ctx.save(); ctx.globalAlpha = dark; ctx.fillStyle = '#17110c'; ctx.fillRect(0, 0, W, H); const g = ctx.createRadialGradient(W / 2, H + 60, 40, W / 2, H + 60, 760); g.addColorStop(0, 'rgba(170,128,80,.55)'); g.addColorStop(.5, 'rgba(120,86,50,.22)'); g.addColorStop(1, 'rgba(120,86,50,0)'); ctx.fillStyle = g; ctx.fillRect(0, 0, W, H); ctx.restore(); }
      // 黑暗中隐约的字
      const qa = smooth(tRoom - .2, tRoom + 1.2, t);
      text(ctx, '翻译像一个房间', W / 2, 452, { size: 64, font: 'song', weight: 300, spacing: .3, color: rgba(mix('#d8c49a', INK, light)), alpha: qa * lerp(.55, 1, light), glow: (1 - light) * 18, glowColor: '#b08a50' });
      text(ctx, '人在其中摸索着寻找电灯开关', W / 2, 540, { size: 30, font: 'song', weight: 300, spacing: .3, color: rgba(mix('#a89470', INK2, light)), alpha: smooth(tGrope, tGrope + 1, t) * lerp(.5, 1, light) });
      // 摸索的手
      const hp = prog(t, tGrope - 1.2, tSw, x => x); const ha = smooth(tGrope - 1.2, tGrope - .4, t) * (1 - light * .3) * ra;
      const hx = lerp(1780, swx + 34, E.inOut(hp)) + Math.sin(t * 2.3) * 10 * (1 - hp), hy = lerp(820, swy + 160, E.inOut(hp)) + Math.sin(t * 1.7 + 1) * 14 * (1 - hp) + (hp >= 1 ? 6 * smooth(tSw - .1, tSw + .05, t) : 0);
      hand(ctx, hx, hy, -.35 + Math.sin(t * 1.9) * .08 * (1 - hp), .9, ha, light);
      if (dark > 0) { const g = ctx.createRadialGradient(swx, swy, 0, swx, swy, 90); g.addColorStop(0, rgba('#c8a878', .16 * dark)); g.addColorStop(1, rgba('#c8a878', 0)); ctx.fillStyle = g; ctx.fillRect(swx - 90, swy - 90, 180, 180); }
      // 灯亮
      if (light > 0 && light < 1) { const g = ctx.createRadialGradient(W / 2, 240, 0, W / 2, 240, 1400 * light); g.addColorStop(0, rgba('#fff4d8', .9 * (1 - light))); g.addColorStop(1, rgba('#fff4d8', 0)); ctx.fillStyle = g; ctx.fillRect(0, 0, W, H); }
      if (light > 0) { const g = ctx.createRadialGradient(W / 2, 200, 0, W / 2, 200, 900); g.addColorStop(0, rgba('#ffe7b0', .22 * light)); g.addColorStop(1, rgba('#ffe7b0', 0)); ctx.fillStyle = g; ctx.fillRect(0, 0, W, H); }
    }
  };

  // ---------- 8. 新的形式：盒中小册子、探戈、漫画、歌剧；去创造 ----------
  const BOOKS = (() => { const r = rng(2016); const tints = ['#efe7d6', '#e9dfca', '#f2ece0', '#e4dccb', '#ece2cf']; const shuf = () => { const a = [...Array(22).keys()]; for (let i = 21; i > 0; i--) { const j = Math.floor(r() * (i + 1)); [a[i], a[j]] = [a[j], a[i]]; } return a; }; const p1 = shuf(), p2 = shuf(); return [...Array(22)].map((_, i) => ({ i, h: 200 + r() * 26, tint: tints[Math.floor(r() * tints.length)], sx: 360 + r() * 1200, sy: 600 + r() * 160, sr: (r() - .5) * 1.6, d: r() * .5, p1: p1[i], p2: p2[i], red: r() < .14 })); })();
  function booklet(ctx, b, x, y, rot, a) { if (a <= 0) return; ctx.save(); ctx.translate(x, y); ctx.rotate(rot); ctx.globalAlpha = a; ctx.shadowColor = 'rgba(60,40,20,.18)'; ctx.shadowBlur = 8; ctx.shadowOffsetY = 3; ctx.fillStyle = b.red ? RED2 : b.tint; ctx.fillRect(-13, -b.h / 2, 26, b.h); ctx.shadowColor = 'transparent'; ctx.strokeStyle = 'rgba(80,60,40,.35)'; ctx.lineWidth = 1; ctx.strokeRect(-13, -b.h / 2, 26, b.h); ctx.rotate(-Math.PI / 2); ctx.fillStyle = b.red ? '#f6eee0' : INK2; ctx.font = font('latin', 15, 600); ctx.textAlign = 'center'; ctx.textBaseline = 'middle'; ctx.fillText(String(b.i + 1), b.h / 2 - 22, 0); ctx.restore(); }
  const TANGO = (() => { const a = []; for (let k = 0; k < 29; k++) { const u = k / 28; const x = lerp(330, 1590, u); const side = k % 2 ? 1 : -1; a.push({ x, y: 470 + Math.sin(u * TAU * 1.5) * 90 + side * 34, side, rot: Math.cos(u * TAU * 1.5) * .5 + side * .25 }); } return a; })();
  function tangoLine(ph, amp) { const o = []; for (let i = 0; i <= 160; i++) { const u = i / 160; o.push([lerp(300, 1620, u), 470 + Math.sin(u * TAU * 1.5) * 90 + Math.sin(u * TAU * 6 + ph) * amp]); } return o; }
  function comicPanel(ctx, k, x, y, w, h, a, t) {
    if (a <= 0) return; ctx.save(); ctx.globalAlpha = a; ctx.fillStyle = '#f7f2e6'; ctx.fillRect(x, y, w, h); ctx.strokeStyle = INK; ctx.lineWidth = 3; ctx.strokeRect(x, y, w, h);
    ctx.beginPath(); ctx.rect(x, y, w, h); ctx.clip(); ctx.lineWidth = 2.2; ctx.strokeStyle = INK; const cx = x + w / 2, cy = y + h / 2;
    switch (k) {
      case 0: for (let i = 0; i < 4; i++) { const px = x + 40 + i * (w - 80) / 3; ctx.beginPath(); ctx.moveTo(px - 12, y + h - 20); ctx.lineTo(px - 12, y + 40); ctx.moveTo(px + 12, y + h - 20); ctx.lineTo(px + 12, y + 40); ctx.stroke(); } ctx.beginPath(); ctx.moveTo(x + 10, y + 36); ctx.lineTo(x + w - 10, y + 36); ctx.stroke(); break;
      case 1: figure(ctx, cx - 30, y + h - 20, 120, 1, INK); figure(ctx, cx + 50, y + h - 20, 110, 1, INK2); break;
      case 2: ctx.beginPath(); ctx.ellipse(cx, cy - 10, w * .36, h * .26, 0, 0, TAU); ctx.fillStyle = '#fff'; ctx.fill(); ctx.stroke(); ctx.beginPath(); ctx.moveTo(cx - 20, cy + h * .2); ctx.lineTo(cx - 40, cy + h * .38); ctx.lineTo(cx + 2, cy + h * .22); ctx.stroke(); text(ctx, '……', cx, cy - 12, { size: 36, font: 'song', color: INK }); break;
      case 3: ctx.fillStyle = RED2; for (let i = 0; i < 5; i++) { const fx = x + 30 + i * (w - 60) / 4, hh = 50 + 40 * Math.sin(t * 6 + i * 1.7) ** 2 + 30 * hash(i, 4); ctx.beginPath(); ctx.moveTo(fx - 16, y + h); ctx.quadraticCurveTo(fx - 18, y + h - hh * .6, fx, y + h - hh); ctx.quadraticCurveTo(fx + 18, y + h - hh * .6, fx + 16, y + h); ctx.fill(); } break;
      case 4: for (let i = 0; i < 4; i++) { ctx.beginPath(); for (let j = 0; j <= 30; j++) { const u = j / 30; ctx.lineTo(x + u * w, y + 50 + i * 34 + Math.sin(u * 12 + t * 2 + i) * 8); } ctx.stroke(); } break;
      case 5: ctx.beginPath(); ctx.ellipse(cx, cy, 46, 58, 0, 0, TAU); ctx.stroke(); ctx.beginPath(); ctx.ellipse(cx - 18, cy - 10, 9, 6, 0, 0, TAU); ctx.ellipse(cx + 18, cy - 10, 9, 6, 0, 0, TAU); ctx.fillStyle = INK; ctx.fill(); ctx.beginPath(); ctx.arc(cx, cy + 26, 16, Math.PI * 1.1, Math.PI * 1.9); ctx.stroke(); break;
    }
    ctx.restore();
  }
  function curtain(ctx, open, a, t) {
    if (a <= 0) return; ctx.save(); ctx.globalAlpha = a; const x0 = 600, x1 = 1320, y0 = 280, y1 = 740; const mid = (x0 + x1) / 2;
    // 舞台与追光
    ctx.strokeStyle = rgba(INK2, .7); ctx.lineWidth = 1.6; ctx.beginPath(); ctx.moveTo(x0 - 60, y1); ctx.lineTo(x1 + 60, y1); ctx.stroke();
    const sp = ctx.createRadialGradient(mid, y1 - 10, 4, mid, y1 - 10, 260); sp.addColorStop(0, rgba('#f6d890', .55 * open)); sp.addColorStop(1, rgba('#f6d890', 0)); ctx.fillStyle = sp; ctx.beginPath(); ctx.moveTo(mid - 30, y0 + 20); ctx.lineTo(mid + 30, y0 + 20); ctx.lineTo(mid + 200, y1); ctx.lineTo(mid - 200, y1); ctx.closePath(); ctx.fill();
    ctx.fillStyle = rgba('#f6d890', .35 * open); ctx.beginPath(); ctx.ellipse(mid, y1, 200, 18, 0, 0, TAU); ctx.fill();
    figure(ctx, mid, y1 - 4, 130, open, INK);
    // 两幅幕布：收拢到两侧并束起
    for (const side of [-1, 1]) {
      const edge = side < 0 ? x0 : x1; const inner = lerp(mid, edge - side * 175, open); const tieY = lerp(y1, y0 + (y1 - y0) * .62, open);
      const nf = 7; for (let k = 0; k < nf; k++) { const u0 = k / nf, u1 = (k + 1) / nf; const xa = lerp(edge, inner, u0), xb = lerp(edge, inner, u1); const tie = side < 0 ? x0 + 70 : x1 - 70; const ta = lerp(xa, tie + (u0 - .5) * 30 * open, open * .9), tb = lerp(xb, tie + (u1 - .5) * 30 * open, open * .9);
        const g = ctx.createLinearGradient(xa, 0, xb, 0); g.addColorStop(0, '#8e2214'); g.addColorStop(.55, '#cf4a2c'); g.addColorStop(1, '#962616'); ctx.fillStyle = g;
        ctx.beginPath(); ctx.moveTo(xa, y0); ctx.lineTo(xb, y0); ctx.quadraticCurveTo(xb, (y0 + tieY) / 2, tb, tieY); ctx.quadraticCurveTo(tb + (xb - tb) * .3, (tieY + y1) / 2, lerp(tb, xb, .55) + side * 10 * open, y1); ctx.lineTo(lerp(ta, xa, .55) + side * 10 * open, y1); ctx.quadraticCurveTo(ta + (xa - ta) * .3, (tieY + y1) / 2, ta, tieY); ctx.quadraticCurveTo(xa, (y0 + tieY) / 2, xa, y0); ctx.closePath(); ctx.fill(); }
      if (open > .3) { ctx.fillStyle = GOLD; ctx.globalAlpha = a * smooth(.3, .6, open); ctx.beginPath(); ctx.ellipse(side < 0 ? x0 + 70 : x1 - 70, tieY, 16, 6, 0, 0, TAU); ctx.fill(); ctx.globalAlpha = a; }
    }
    // 帷幔
    ctx.fillStyle = '#9a2a18'; ctx.beginPath(); ctx.moveTo(x0 - 30, y0 - 24); ctx.lineTo(x1 + 30, y0 - 24); ctx.lineTo(x1 + 30, y0 + 10); for (let k = 8; k >= 0; k--) { const xx = lerp(x0 - 30, x1 + 30, k / 8); ctx.quadraticCurveTo(xx + (x1 - x0 + 60) / 16, y0 + 44, xx, y0 + 10); } ctx.closePath(); ctx.fill();
    ctx.strokeStyle = GOLD; ctx.lineWidth = 2; ctx.beginPath(); ctx.moveTo(x0 - 30, y0 - 24); ctx.lineTo(x1 + 30, y0 - 24); ctx.stroke();
    ctx.restore();
  }
  let ASH = null; // init 中采样“让自我退后，好让别的东西进来”的笔画像素
  const ASHLINE = '让自我退后，好让别的东西进来';

  scenes.forms = (ctx, S) => {
    const t = S.t, c1 = S.cue(1);
    paper(ctx); motes(ctx, t + 180, .6);
    const tBox = at(S, 0, '一盒'), tAny = at(S, 0, '任意次序'), tTan = at(S, 0, '二十九支'), tCom = at(S, 0, '漫画'), tOp = at(S, 0, '歌剧');
    const ends = [tTan - .25, tCom - .55, tOp - .4, c1 + .6]; const starts = [.2, tTan - .25, tCom - .55, tOp - .4];
    const va = k => (k === 0 ? smooth(starts[k] - .05, starts[k] + .35, t) : smooth(starts[k] - .18, starts[k] + .18, t)) * (1 - smooth(ends[k] - .18, ends[k] + .18, t));
    // 目录
    const ia = smooth(.4, 1.2, t) * (1 - smooth(c1 - .6, c1, t));
    if (ia > 0) { const items = ['一盒小册子', '二十九支探戈', '漫画', '歌剧']; items.forEach((w, k) => { const x = W / 2 + (k - 1.5) * 250; const on = va(k); text(ctx, w, x, 170, { size: 26, font: 'song', weight: on > .5 ? 500 : 300, spacing: .2, color: on > .5 ? INK : INK4, alpha: ia }); ctx.save(); ctx.globalAlpha = ia * on; ctx.fillStyle = RED2; ctx.fillRect(x - 20, 196, 40, 2.5); ctx.restore(); }); }
    // 1. Float：透明盒倾倒，22 本小册子散开，再以随机次序排列
    const a1 = va(0);
    if (a1 > 0) {
      const tip = E.inOut(prog(t, tBox + .9, tBox + 1.9, x => x)); const sc = prog(t, tBox + 1.4, tBox + 3.0, E.out); const ord = E.inOut(prog(t, tAny - .3, tAny + 1.2, x => x)), ord2 = E.inOut(prog(t, tAny + 1.6, tAny + 2.8, x => x));
      const bx = 960, by = 700, bw = 22 * 30 + 40, bh = 260;
      ctx.save(); ctx.translate(bx + bw / 2, by); ctx.rotate(-tip * .32); ctx.translate(-(bx + bw / 2), -by);
      const ba = a1 * (1 - smooth(tBox + 1.6, tBox + 2.6, t));
      ctx.save(); ctx.globalAlpha = ba; ctx.fillStyle = 'rgba(220,232,236,.22)'; ctx.fillRect(bx - bw / 2, by - bh, bw, bh); ctx.strokeStyle = 'rgba(90,110,120,.6)'; ctx.lineWidth = 1.6; ctx.strokeRect(bx - bw / 2, by - bh, bw, bh); ctx.strokeStyle = 'rgba(255,255,255,.7)'; ctx.beginPath(); ctx.moveTo(bx - bw / 2 + 20, by - bh + 16); ctx.lineTo(bx - bw / 2 + 80, by - bh + 16); ctx.stroke(); ctx.restore();
      ctx.restore();
      for (const b of BOOKS) {
        const x0 = bx - bw / 2 + 35 + b.i * 30, y0 = by - b.h / 2 - 6; const u = E.out(clamp(sc * 1.4 - b.d)); const slot = k => [W / 2 + (k - 10.5) * 52, 520];
        const s1 = slot(b.p1), s2 = slot(b.p2);
        let x = lerp(x0, b.sx, u), y = lerp(y0, b.sy - 80, u), r = lerp(0, b.sr, u);
        if (u <= 0) { const ang = -tip * .32; const dx = x0 - (bx + bw / 2), dy = y0 - by; x = bx + bw / 2 + dx * Math.cos(ang) - dy * Math.sin(ang); y = by + dx * Math.sin(ang) + dy * Math.cos(ang); r = ang; }
        x = lerp(x, s1[0], ord); y = lerp(y, s1[1], ord); r = lerp(r, 0, ord); x = lerp(x, s2[0], ord2);
        booklet(ctx, b, x, y, r, a1);
      }
      tag(ctx, 'Float', '2016 · 22 本小册子 · 任意次序', 150, 800, { size: 34, alpha: a1 * smooth(tBox, tBox + .8, t), color: INK, enFont: 'song', raw: true, enSize: 22, enSpacing: .12, enColor: INK2 });
    }
    // 2. 二十九支探戈
    const a2 = va(1);
    if (a2 > 0) {
      const u = prog(t, starts[1], ends[1] - .3, x => x);
      text(ctx, '29', W / 2, 470, { size: 420, font: 'latin', weight: 300, color: rgba(RED2, .10), alpha: a2 });
      line(ctx, partial(tangoLine(0, 26), u), INK, 2, a2); line(ctx, partial(tangoLine(Math.PI, 26), u), RED2, 2, a2);
      const n = Math.min(29, Math.floor(u * 29.99)); TANGO.slice(0, n).forEach((s2, k) => { ctx.save(); ctx.translate(s2.x, s2.y); ctx.rotate(s2.rot); ctx.globalAlpha = a2 * .8; ctx.fillStyle = k % 2 ? RED2 : INK2; ctx.beginPath(); ctx.ellipse(0, -5, 6, 10, 0, 0, TAU); ctx.fill(); ctx.beginPath(); ctx.ellipse(0, 10, 4.5, 5, 0, 0, TAU); ctx.fill(); ctx.restore(); });
      text(ctx, String(Math.max(1, n)).padStart(2, '0') + ' / 29', 1590, 690, { size: 26, font: 'latin', weight: 600, spacing: .2, color: INK2, alpha: a2, align: 'right' });
      tag(ctx, '《丈夫之美》 · 二十九支探戈', 'The Beauty of the Husband · 2001 · a fictional essay in 29 tangos', 150, 800, { size: 34, alpha: a2, color: INK, enFont: 'latinI', raw: true, enSize: 24, enSpacing: .03, enColor: INK2 });
    }
    // 3. 漫画
    const a3 = va(2);
    if (a3 > 0) { const gx = 560, gy = 250, pw = 260, ph = 220, gap = 14; for (let k = 0; k < 6; k++) { const c = k % 3, r = Math.floor(k / 3); comicPanel(ctx, k, gx + c * (pw + gap), gy + r * (ph + gap), pw, ph, a3 * smooth(starts[2] + k * .08, starts[2] + .25 + k * .08, t), t); } tag(ctx, '漫画', 'The Trojan Women: A Comic · 2021', 150, 800, { size: 34, alpha: a3, color: INK, enFont: 'latinI', raw: true, enSize: 24, enSpacing: .03, enColor: INK2 }); }
    // 4. 歌剧
    const a4 = va(3);
    if (a4 > 0) { curtain(ctx, E.inOut(prog(t, starts[3] + .05, starts[3] + .85, x => x)), a4, t); tag(ctx, '歌剧', 'opera', 150, 800, { size: 34, alpha: a4, color: INK, enFont: 'latinI', raw: true, enSize: 24, enSpacing: .03, enColor: INK2 }); }
    // B：去创造
    const ba = smooth(c1 - .2, c1 + .7, t);
    if (ba > 0) {
      const tSelf = at(S, 1, '让自我退后'), tIn = at(S, 1, '好让别的东西');
      text(ctx, '去创造', W / 2, 300, { size: 104, font: 'song', weight: 300, spacing: .3, color: INK, alpha: ba, reveal: prog(t, c1 - .2, c1 + 1, E.out) });
      text(ctx, 'décréation', W / 2, 392, { size: 46, font: 'latinI', color: INK2, alpha: ba * smooth(c1 + .3, c1 + 1.1, t) });
      tag(ctx, '西蒙娜·薇依', 'Simone Weil', W / 2, 454, { size: 24, align: 'center', mark: false, alpha: ba * smooth(c1 + .6, c1 + 1.4, t), color: INK3, enSize: 15 });
      // 那一行字，逐字化作灰烬
      const ly = 640; const A = ASH; const la = ba * smooth(c1 + 1, c1 + 1.8, t);
      const pc = i => clamp((t - (tSelf + .3) - A.order[i] * .16) / 1.8);
      A.chars.forEach((ch, i) => { const p = pc(i); if (p >= .35) return; text(ctx, ch.s, ch.x, ly, { size: 50, font: 'song', weight: 400, color: INK, alpha: la * (1 - p / .35) }); });
      ctx.save(); for (let k = 0; k < A.pts.length; k += 1) { const P = A.pts[k]; const p = pc(P.c); if (p <= 0 || p >= 1) continue; const e = E.out(p); const x = P.x + Math.sin(t * 1.3 + P.r * 9) * 24 * p + (P.r - .5) * 180 * e, y = ly + P.y - e * (60 + 300 * P.r2) - 90 * p * p; ctx.globalAlpha = la * Math.min(1, p * 8) * Math.pow(1 - p, 1.6) * .85; ctx.fillStyle = P.r < .06 && p < .5 ? '#c8502a' : rgba(mix(INK2, '#b0a491', clamp(p * 1.6))); const sz = (1.6 + P.r2 * 2) * (1 - p * .5); ctx.fillRect(x, y, sz, sz); } ctx.restore();
      // 别的东西进来：一片暖光
      const lg = smooth(tIn - .2, tIn + 1.6, t) * ba; if (lg > 0) { const g = ctx.createRadialGradient(W / 2, ly, 0, W / 2, ly, 520); g.addColorStop(0, rgba('#fff3d6', .75 * lg)); g.addColorStop(.4, rgba('#f6dfa8', .25 * lg)); g.addColorStop(1, rgba('#f6dfa8', 0)); ctx.fillStyle = g; ctx.fillRect(0, ly - 520, W, 1040); glow(ctx, W / 2, ly, 60, '#e8b860', .25 * lg); }
    }
  };

  // ---------- 9. 与火为邻：语文学与诗交汇，残篇重新燃烧 ----------
  const LEX = ['γλυκύπικρον · sweetbitter', 'λυσιμελής · loosening the limbs', 'ἀμάχανον · without means', 'ὄρπετον · creeping thing', 'frāter · brother', 'aequor · the sea', 'ave atque vale', 'ἔρος · desire', 'nox · night', 'Γηρυών', 'Στησίχορος', 'multas per gentes'];
  const BURN = [[440, 430, 0], [1494, 470, .3], [700, 878, .5], [1250, 236, .15], [1040, 214, .7], [436, 700, .9], [1430, 790, .45], [900, 850, .8]];
  function streamPath(k, side) { const o = []; for (let i = 0; i <= 50; i++) { const u = i / 50; const x = side < 0 ? lerp(-60, 960, u) : lerp(1980, 960, u); const yy = 470 + (k - 3) * (side < 0 ? 70 : 52) * (1 - u) * (1 - u) * 1.6 + Math.sin(u * 5 + k + (side > 0 ? 2 : 0)) * 30 * (1 - u) * (side > 0 ? 2.2 : .3); o.push([x, yy]); } return o; }
  function along(pts, u) { const n = pts.length - 1; const f = clamp(u) * n; const i = Math.min(n - 1, Math.floor(f)); const r = f - i; return [lerp(pts[i][0], pts[i + 1][0], r), lerp(pts[i][1], pts[i + 1][1], r), Math.atan2(pts[i + 1][1] - pts[i][1], pts[i + 1][0] - pts[i][0])]; }

  scenes.close = (ctx, S) => {
    const t = S.t, c1 = S.cue(1);
    paper(ctx);
    const tPo = at(S, 0, '诗人'), tMeet = at(S, 0, '交汇'), tOld = at(S, 1, '古老的残篇'), tBurn = at(S, 1, '燃烧'), tFire = at(S, 1, '与火为邻');
    const dark = Math.pow(smooth(tMeet - .2, tOld + .4, t), .7);
    // A：两股流
    const aA = smooth(.1, 1, t) * (1 - smooth(tMeet + .2, tOld - .2, t));
    if (aA > 0) {
      ctx.save(); ctx.font = font(GK, 19, 400); ctx.textAlign = 'center'; ctx.textBaseline = 'middle'; ctx.fillStyle = INK2;
      for (let k = 0; k < 7; k++) { const pts = streamPath(k, -1); const txt = LEX[k % LEX.length] + '   ' + LEX[(k + 5) % LEX.length] + '   '; const chars = [...txt]; const n = 60; for (let j = 0; j < n; j++) { const u = ((j / n + t * .055 + k * .07) % 1); if (u > .97) continue; const [x, y, a] = along(pts, u); ctx.globalAlpha = aA * smooth(0, .1, u) * (1 - smooth(.85, .97, u)) * .8; ctx.save(); ctx.translate(x, y); ctx.rotate(a); ctx.fillText(chars[j % chars.length], 0, 0); ctx.restore(); } }
      ctx.restore();
      const pa = aA * smooth(tPo - 1, tPo + .2, t);
      for (let k = 0; k < 5; k++) { const pts = streamPath(k + 1, 1); const head = clamp((t - tPo + 1.4) * .26 + k * .04); const tail = Math.max(0, head - .62); const seg = pts.slice(Math.floor(tail * 50), Math.max(2, Math.floor(head * 50) + 1)); if (seg.length > 2) { const ww = [16, 24, 30, 20, 12][k]; stroke(ctx, seg, ww, k === 2 ? RED2 : INK, pa * (k === 2 ? .8 : .35 + k * .08), { wfn: u => ww * Math.pow(Math.sin(Math.PI * u), .5) * (.55 + .45 * Math.sin(u * 7 + k)) }); } }
      [['诗', 0], ['夜', 1], ['火', 2], ['红', 3]].forEach(([ch, i]) => { const u = clamp((t - tPo + .6) * .2 - i * .12); if (u <= 0 || u >= 1) return; const [x, y] = along(streamPath(i + 1, 1), u); text(ctx, ch, x, y - 64 + i * 30, { size: 62, font: 'brush', color: i === 2 || i === 3 ? RED2 : INK, alpha: pa * Math.sin(Math.PI * u) * .85 }); });
      tag(ctx, '语文学者对词语的执迷', 'philology', 140, 230, { size: 34, alpha: aA * smooth(.4, 1.2, t), color: INK, enSize: 16 });
      tag(ctx, '诗人对新意义的渴望', 'poetry', 1780, 230, { size: 34, align: 'right', alpha: pa, color: INK, enSize: 16 });
      const ma = smooth(tMeet - .3, tMeet + .4, t) * aA; if (ma > 0) { const g = ctx.createRadialGradient(960, 470, 0, 960, 470, 260); g.addColorStop(0, rgba('#ffe9b8', .8 * ma)); g.addColorStop(1, rgba('#ffe9b8', 0)); ctx.fillStyle = g; ctx.fillRect(700, 210, 520, 520); text(ctx, '交汇', 960, 470, { size: 40, font: 'song', weight: 400, spacing: .4, color: RED, alpha: ma }); }
    }
    // 夜色渐起（暖褐，而非灰）
    if (dark > 0) { const r0 = lerp(1250, 0, dark); const gv = ctx.createRadialGradient(W / 2, 540, r0, W / 2, 540, r0 + 520); gv.addColorStop(0, 'rgba(18,11,7,0)'); gv.addColorStop(1, 'rgba(18,11,7,.96)'); ctx.fillStyle = gv; ctx.fillRect(0, 0, W, H);
      ctx.save(); ctx.globalAlpha = Math.pow(dark, 1.6) * .94; const g0 = ctx.createRadialGradient(W / 2, 560, 60, W / 2, 560, 1150); g0.addColorStop(0, '#4a2e18'); g0.addColorStop(.45, '#24160d'); g0.addColorStop(1, '#0e0906'); ctx.fillStyle = g0; ctx.fillRect(0, 0, W, H); ctx.restore(); const g = ctx.createRadialGradient(W / 2, H + 80, 50, W / 2, H + 80, 820); g.addColorStop(0, rgba('#b8763a', .5 * dark)); g.addColorStop(1, rgba('#b8763a', 0)); ctx.fillStyle = g; ctx.fillRect(0, 0, W, H); }
    // B：残篇燃烧
    const fa = smooth(tOld - .9, tOld + .3, t);
    if (fa > 0) {
      const bu = prog(t, tBurn - .5, S.d + 1.2, x => x);
      const fs = .66, fx = 960, fy = 500 - 50 * smooth(tFire - .6, tFire + .6, t), frot = -.03;
      const BR = BURN.map(([x, y, d], i) => ({ x, y, r: Math.max(0, bu - d * .22) * 400 * (1 + .25 * Math.sin(i)), seed: i + 20 }));
      const cut = (g, k, grow) => BR.forEach(b => { if (b.r > 2) { blobPath(g, b.x, b.y, b.r * 1.12 * k + grow, b.r * 1.0 * k + grow, b.seed, bu * 2, 90, .6); g.fill(); } });
      const F = composePapyrus(t, { erode: 1, letterColor: L => rgba(mix('#2b1a0e', '#ff8a30', smooth(tBurn + L.k * .025, tBurn + 1.0 + L.k * .025, t))), burn: g => {
        g.globalCompositeOperation = 'source-atop'; soft(g, 12, 'rgba(34,14,4,.95)', g => cut(g, 1, 34)); soft(g, 5, 'rgba(20,8,2,1)', g => cut(g, 1, 10));
        g.globalCompositeOperation = 'destination-out'; cut(g, 1, 0);
      } });
      // 燃烧的边：只保留真正的火线（去掉落在其它烧穿区域里的部分）
      const R = OFF[3], rg = R.getContext('2d'); rg.setTransform(1, 0, 0, 1, 0, 0); rg.globalCompositeOperation = 'source-over'; rg.globalAlpha = 1; rg.clearRect(0, 0, W, H); rg.lineJoin = 'round';
      const fk = .8 + .2 * Math.sin(t * 9) * Math.sin(t * 5.3);
      BR.forEach(b => { if (b.r > 2) { soft(rg, 10, `rgba(255,96,24,${.9 * fk})`, g => { blobPath(g, b.x, b.y, b.r * 1.12, b.r, b.seed, bu * 2, 90, .6); g.lineWidth = 26; g.stroke(); }); soft(rg, 3, 'rgba(255,170,70,1)', g => { blobPath(g, b.x, b.y, b.r * 1.12, b.r, b.seed, bu * 2, 90, .6); g.lineWidth = 9; g.stroke(); }); blobPath(rg, b.x, b.y, b.r * 1.12, b.r, b.seed, bu * 2, 90, .6); rg.strokeStyle = 'rgba(255,236,190,1)'; rg.lineWidth = 2.6; rg.stroke(); } });
      rg.globalCompositeOperation = 'destination-out'; rg.fillStyle = '#000'; BR.forEach(b => { if (b.r > 12) { blobPath(rg, b.x, b.y, b.r * 1.12 - 9, b.r - 9, b.seed, bu * 2, 90, .6); rg.fill(); } });
      rg.globalCompositeOperation = 'destination-in'; rg.drawImage(TEX.papWide, 0, 0); rg.globalCompositeOperation = 'source-over';
      // 火舌：沿火线向上
      const flames = []; BR.forEach(b => { if (b.r < 8) return; for (let k = 0; k < 28; k++) { const a = k / 28 * TAU + b.seed; const rr = blobR(a, b.seed, bu * 2, .6); const x = b.x + Math.cos(a) * b.r * 1.12 * rr, y = b.y + Math.sin(a) * b.r * rr; if (!inPoly(x, y, PAPV)) continue; if (BR.some(o => o !== b && Math.hypot((x - o.x) / 1.12, y - o.y) < o.r * .92)) continue; flames.push([x, y, k + b.seed * 7]); } });
      ctx.save(); ctx.translate(fx, fy); ctx.rotate(frot); ctx.scale(fs, fs); ctx.translate(-960, -540);
      const glowA = smooth(tBurn - .5, tBurn + .5, t);
      ctx.globalAlpha = fa * (1 - dark * .8) * .5; ctx.drawImage(papShadow(1), 0, 0);
      ctx.globalAlpha = fa; ctx.drawImage(F, 0, 0);
      ctx.globalCompositeOperation = 'lighter'; ctx.globalAlpha = fa * glowA; ctx.drawImage(R, 0, 0);
      for (const [x, y, sd] of flames) { const h = (26 + 30 * hash(sd, 3)) * (.7 + .3 * Math.sin(t * 13 + sd)) * glowA; const w = 9 + 6 * hash(sd, 4); const sw = Math.sin(t * 7 + sd) * 5; const g = ctx.createLinearGradient(x, y, x, y - h); g.addColorStop(0, 'rgba(255,170,60,.85)'); g.addColorStop(.5, 'rgba(255,90,20,.45)'); g.addColorStop(1, 'rgba(200,40,10,0)'); ctx.fillStyle = g; ctx.globalAlpha = fa * glowA * .8; ctx.beginPath(); ctx.moveTo(x - w, y); ctx.quadraticCurveTo(x - w * .6 + sw * .4, y - h * .55, x + sw, y - h); ctx.quadraticCurveTo(x + w * .6 + sw * .4, y - h * .55, x + w, y); ctx.closePath(); ctx.fill(); }
      ctx.restore();
      // 火光与火星
      const fl = glowA * fa * fk; const g = ctx.createRadialGradient(fx, fy + 30, 30, fx, fy + 30, 720); g.addColorStop(0, rgba('#ff9a48', .30 * fl * dark)); g.addColorStop(1, rgba('#ff9a48', 0)); ctx.save(); ctx.globalCompositeOperation = 'lighter'; ctx.fillStyle = g; ctx.fillRect(0, 0, W, H); ctx.restore();
      embers(ctx, t, { x0: fx - 330, x1: fx + 330, y0: fy + 160, ys: fy - 150, rise: 560, n: 110, alpha: fl, size: 2.2, life: 3.4, seed: 21, dark: true, wind: 30 });
    }
    // 与火为邻
    const ta = smooth(tFire - .3, tFire + .9, t);
    if (ta > 0) {
      const T = TEX.titleFire; ctx.save(); ctx.globalAlpha = ta; const k = lerp(1.06, 1, E.out(ta)); ctx.translate(W / 2, 800); ctx.scale(k * .6, k * .6); ctx.translate(-W / 2, -T.y);
      ctx.globalCompositeOperation = 'lighter'; ctx.globalAlpha = ta * .8; soft(ctx, 16, 'rgba(255,130,50,.9)', g => g.drawImage(T.canvas, 0, 0)); ctx.globalAlpha = ta; ctx.drawImage(T.canvas, 0, 0); ctx.restore();
    }
  };

  // ---------- 10. 片尾 ----------
  scenes.end = (ctx, S) => {
    const t = S.t, d = S.d; paper(ctx); motes(ctx, t + 240, .5);
    const a = smooth(0, 1.2, t);
    text(ctx, '2026 年诺贝尔文学奖', W / 2, 200, { size: 40, font: 'song', weight: 500, spacing: .42, color: INK, alpha: a, reveal: prog(t, 0, 1.4, E.out) });
    const lw = 240 * E.out(prog(t, .3, 1.8, x => x)); ctx.save(); ctx.strokeStyle = rgba(GOLD, .85); ctx.lineWidth = 1.2; ctx.beginPath(); ctx.moveTo(W / 2 - lw, 252); ctx.lineTo(W / 2 + lw, 252); ctx.stroke(); ctx.restore();
    const zh = ['表彰“她大胆而富有创造力的作品，在与古典传统的游戏性对话中，', '为当代文学创造了新的形式”'];
    zh.forEach((l, i) => text(ctx, l, W / 2, 352 + i * 78, { size: 46, font: 'song', weight: 400, spacing: .06, color: INK, alpha: a, reveal: prog(t, .7 + i * .6, 2.4 + i * .6, E.out) }));
    const el = MP.wrap(ctx, '“for her bold and inventive oeuvre that, in playful dialogue with the classical tradition, has created new forms for contemporary literature.”', 'latinI', 34, 1240);
    el.forEach((l, i) => text(ctx, l, W / 2, 548 + i * 48, { size: 34, font: 'latinI', color: INK2, alpha: a * smooth(2.0 + i * .3, 3.0 + i * .3, t) }));
    const wy = 548 + el.length * 48 + 64;
    text(ctx, '获奖者：安妮·卡森（Anne Carson）', W / 2, wy, { size: 34, font: 'song', weight: 500, spacing: .12, color: INK, alpha: a * smooth(3, 4, t) });
    drawSeal(ctx, TEX.sealFire, W / 2 + 420, wy - 4, smooth(3.6, 3.75, t) * .9, lerp(1.3, .82, E.out(prog(t, 3.6, 3.95, x => x))), -.05);
    text(ctx, '资料：瑞典学院公告、诺贝尔奖官方资料、《红的自传》《若非，冬季》《夜》等 · 引文为节译 · 配音为合成语音', W / 2, 960, { size: 22, font: 'song', weight: 400, color: INK3, alpha: a * smooth(3.6, 4.6, t), spacing: .04 });
    const fo = smooth(d - 1.5, d - .05, t); if (fo > 0) { ctx.save(); ctx.globalAlpha = fo; paper(ctx); ctx.restore(); }
  };
  void ASHLINE;

  async function init() {
    GLFX.define('xuan', SH_XUAN); GLFX.define('papyrus', SH_PAP); GLFX.define('blot', SH_BLOT); GLFX.define('shan', SH_SHAN);
    TEX.paper = snap('xuan', { C1: PAPER, SEED: 3.7 }, 1);
    TEX.pap = snap('papyrus', { SEED: PAP.seed }, 1);
    { const c = mk(W, H), g = c.getContext('2d'); soft(g, 16, '#4a2e14', g => g.drawImage(TEX.pap, 0, 0)); TEX.papShadow = c; }
    TEX.blot = []; TEX.blotInk = []; TEX.blotC = [];
    for (let k = 0; k < 4; k++) { const g = GLFX.draw('blot', { SEED: 1.7 + k * 3.1, RAD: .36 }, .5); const c = mk(512, 512); c.getContext('2d').drawImage(g, (g.width - g.height) / 2, 0, g.height, g.height, 0, 0, 512, 512); TEX.blot.push(c); TEX.blotInk.push(tint(c, INK)); TEX.blotC.push({}); }
    TEX.mount = snap('shan', { SEED: 2.3, BASE: 560, AMP: 260 }, .75);
    TEX.mountInk = tint(TEX.mount, '#3a3027');
    TEX.mount2 = tint(snap('shan', { SEED: 7.9, BASE: 640, AMP: 420 }, .75), '#2a241c');
    // 片名
    {
      const c = mk(W, H), g = c.getContext('2d'); const chars = [...'与火为邻']; const size = 236; g.font = font('brush', size, 400); g.textAlign = 'center'; g.textBaseline = 'middle';
      const ws = chars.map(ch => g.measureText(ch).width); const gap = size * .16; const total = ws.reduce((a, b) => a + b, 0) + gap * 3; let x = W / 2 - total / 2; const cx = []; const y = 512;
      chars.forEach((ch, i) => { const xc = x + ws[i] / 2; cx.push(xc); x += ws[i] + gap; });
      g.save(); g.globalAlpha = .35; soft(g, 3, INK, g => chars.forEach((ch, i) => g.fillText(ch, cx[i], y + (i % 2 ? 6 : -4)))); g.restore();
      g.fillStyle = INK; chars.forEach((ch, i) => { g.save(); g.translate(cx[i], y + (i % 2 ? 6 : -4)); g.rotate((i % 2 ? .02 : -.015)); g.fillText(ch, 0, 0); g.restore(); });
      TEX.title = { canvas: c, cx, y, x1: W / 2 + total / 2 };
    }
    TEX.noxPan = [...Array(NPAN)].map((_, i) => i % 2 === 0 ? makeDictPanel(DICT[(i / 2) % DICT.length], i / 2) : makeCollagePanel(i)); TEX.noxLid = makeLid(); TEX.noxStack = makeStack();
    { const c = mk(W, H), g = c.getContext('2d'); g.drawImage(TEX.pap, 0, 0); g.globalCompositeOperation = 'source-in'; g.fillStyle = '#fff'; g.fillRect(0, 0, W, H); const c2 = mk(W, H), g2 = c2.getContext('2d'); soft(g2, 10, '#fff', g => { g.drawImage(c, 0, 0); g.drawImage(c, 0, 0); }); TEX.papWide = c2; }
    { const T = TEX.title; const c = mk(W, H), g = c.getContext('2d'); g.drawImage(T.canvas, 0, 0); g.globalCompositeOperation = 'source-in'; const gr = g.createLinearGradient(0, T.y - 120, 0, T.y + 120); gr.addColorStop(0, '#ffd890'); gr.addColorStop(.55, '#ff9a48'); gr.addColorStop(1, '#d8462a'); g.fillStyle = gr; g.fillRect(0, 0, W, H); TEX.titleFire = { canvas: c, y: T.y }; }
    { const c = mk(W, 200), g = c.getContext('2d'); g.font = font('song', 50, 400); g.textBaseline = 'middle'; g.fillStyle = '#000'; const chs = [...ASHLINE]; const ws = chs.map(ch => g.measureText(ch).width); const tot = ws.reduce((a, b) => a + b, 0); let x = W / 2 - tot / 2; const chars = []; chs.forEach((ch, i) => { chars.push({ s: ch, x: x + ws[i] / 2, x0: x, x1: x + ws[i] }); g.fillText(ch, x, 100); x += ws[i]; }); const id = g.getImageData(0, 0, W, 200).data; const pts = []; const r = rng(55); for (let y = 0; y < 200; y += 2) for (let xx = (y / 2) % 2; xx < W; xx += 2) { if (id[(y * W + xx) * 4 + 3] > 120) { let ci = chars.findIndex(c => xx >= c.x0 && xx < c.x1); if (ci < 0) ci = 0; pts.push({ x: xx, y: y - 100, c: ci, r: r(), r2: r() }); } } const self = 2; const order = chars.map((c, i) => Math.abs(i - self) * .6 + (i > 5 ? 1.5 : 0)); ASH = { chars, pts, order }; }
    TEX.sealName = makeSeal('卡森', 64, 118, { cols: 1, seed: 5 });
    TEX.sealFire = makeSeal('与火为邻', 104, 104, { cols: 2, seed: 9 });
  }

  FILM({ id: 'literature', scenes, init, accent: '#b8321e', chapterText: '#2a241c', brand: 'NOBEL PRIZE 2026 · LITERATURE', subStyle: { theme: 'paper' }, chapters: { citation: [1, '颁奖词'], eros: [2, '甜苦'], red: [3, '红的自传'], brackets: [4, '方括号'], nox: [5, '夜'], forms: [6, '新的形式'], close: [7, '与火为邻'] }, noPush: ['title', 'end'], post: { bloom: 0, vignette: .28, vignetteColor: '#3a2814', grain: .06 } });
})();
