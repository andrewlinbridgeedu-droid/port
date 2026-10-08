// 2026 诺贝尔化学奖 ·《积微成著》——手性的放大与生命的偏手之谜
// 视觉语言：墨紫底色；左手型 = 青（TEAL），右手型 = 玫红（ROSE），纯度/放大 = 金（GOLD）；
// 贯穿全片的是一道竖直的“镜面”与镜像对称的构图。每一帧都只是时间的纯函数。
(function () {
  const { W, H, clamp, lerp, inv, smooth, E, prog, env, rng, hash, glow, dot, text, rgba, mix, cam, line, partial, label, noise3, measure } = MP;
  const { stars, titleCard, endCard, term, counter, comet } = KIT;
  const TEAL = '#4fe3c1', ROSE = '#ff5fa2', GOLD = '#ffd27a', LILAC = '#cbbcff', IVORY = '#f4efe6', MUTE = '#8d84a6', AMBER = '#ffad5c', MINT = '#7dffc8';
  const TEAL_D = '#1f9c86', ROSE_D = '#b8306f';
  const D2R = Math.PI / 180, TAU = Math.PI * 2;

  // ======================================================================
  // 着色器
  // ======================================================================
  // 万花筒：极坐标折叠 + 域扭曲噪声，青/玫/金三色晶体纹
  GLFX.define('kaleido', `uniform float A,N,SP; uniform vec3 C1,C2,C3;
void main(){vec2 u=UV(); float r=length(u); float a=atan(u.y,u.x)+T*SP;
 float seg=6.2831853/N; a=mod(a,seg); a=abs(a-seg*.5);
 vec2 p=vec2(cos(a),sin(a))*r;
 vec3 q=vec3(p*2.3,T*.035);
 float w=fbm4(q+vec3(0.,-T*.04,0.));
 float d=fbm(q*1.45+vec3(w*2.2,w*1.1,1.)-vec3(T*.02,0.,0.));
 float iso=abs(fract(d*7.)-.5); float edge=smoothstep(.07,.0,iso)*smoothstep(.3,.62,d);
 float body=smoothstep(.42,.82,d);
 float side=smoothstep(-.2,.2,u.x);
 vec3 hue=mix(C1,C2,side);
 vec3 col=hue*(body*.75+.04)+mix(hue*1.6,C3,.35)*edge*.85+C3*pow(body,5.)*.7;
 float rad=smoothstep(1.3,.35,r)*smoothstep(.05,.32,r);
 O=vec4(col*A*rad,1.);}`);

  // 香气：两缕上升的烟（P1 处 C1 色，P2 处 C2 色）
  GLFX.define('wisp', `uniform vec3 C1,C2; uniform vec2 P1,P2; uniform float A,A1,A2,HT;
float plume(vec2 u,vec2 P,float sd){vec2 d=u-P; float h=d.y; if(h<-.03)return 0.;
 float t=T*.22; vec3 q=vec3(d.x*3.2,h*2.2-t,sd);
 float w1=fbm4(q); float w2=fbm4(q*1.9+vec3(w1*1.7,0.,3.));
 float x=d.x+(w1-.5)*.18*(h+.05)*2.4+(w2-.5)*.06;
 float wd=.025+h*.22;
 float body=exp(-pow(x/wd,2.))*smoothstep(-.03,.06,h)*smoothstep(HT,HT*.25,h);
 float curl=fbm(vec3(x*9.,h*5.-t*1.6,sd+2.));
 float str=pow(smoothstep(.42,.8,curl),1.4);
 return body*(.12+str*1.5);}
void main(){vec2 u=UV(); vec3 col=C1*plume(u,P1,1.3)*A1+C2*plume(u,P2,7.7)*A2; O=vec4(col*A,1.);}`);

  // 一千万个分子：可缩放的点阵（青/玫随机），缩小时化作闪烁的纹理
  GLFX.define('field', `uniform float Z,A,SD,F0,F1,WR; uniform vec2 C; uniform vec3 C1,C2;
void main(){vec2 px=(gl_FragCoord.xy-.5*R)/R.y; vec2 g=px/Z+C; vec2 id=floor(g); vec2 f=fract(g)-.5;
 float h=h12(id+SD); float Fl=mix(F0,F1,smoothstep(WR,WR-.15,length(px)+.04*(h12(id*.7)-.5)));
 vec3 col=h<Fl?C1:C2; vec2 jo=(vec2(h12(id+3.1),h12(id+7.7))-.5)*.34; float rr=.2+.1*h12(id+1.9);
 float d=length(f-jo); float pw=(1./R.y)/Z; float dm=smoothstep(rr+pw,rr-pw,d);
 float sub=smoothstep(.1,.5,pw);
 float tw=.6+.4*sin(T*2.+h*40.);
 vec2 pc=floor(gl_FragCoord.xy); float hp=h12(pc+SD*13.); float sp=pow(h12(pc*1.37+SD+floor(T*6.)),2.5);
 vec3 grain=(hp<Fl?C1:C2)*(.12+.9*sp);
 vec3 c=mix(col*dm*(.6+.4*tw)+col*.05,grain,sub);
 float vg=smoothstep(1.15,.3,length(px*vec2(.72,1.)));
 O=vec4(c*A*vg,1.);}`);

  // 原始海洋星球
  GLFX.define('planet', `uniform vec2 P; uniform float SZ,A,ROT,GL; uniform vec2 GP;
void main(){vec2 d=(UV()-P)/SZ; float r=length(d); vec3 col=vec3(0.);
 vec3 Lg=normalize(vec3(-.55,.45,.7));
 if(r<1.){float z=sqrt(1.-r*r); vec3 n=vec3(d.x,d.y,z);
  float c=cos(ROT),s=sin(ROT); vec3 q=vec3(c*n.x+s*n.z,n.y,-s*n.x+c*n.z);
  float sw=fbm4(q*3.+vec3(0.,0.,T*.01));
  float cl=fbm(q*vec3(4.,7.,4.)+vec3(sw*1.6,T*.015,0.)); cl=smoothstep(.52,.82,cl);
  float isl=smoothstep(.66,.72,fbm4(q*5.+11.));
  vec3 ocean=mix(vec3(.01,.05,.11),vec3(.03,.25,.33),smoothstep(.3,.8,sw));
  float dif=clamp(dot(n,Lg),0.,1.); float term=smoothstep(-.12,.25,dot(n,Lg));
  vec3 c2=ocean*(.08+dif*1.1)+mix(vec3(.25,.18,.12),vec3(.5,.35,.2),sw)*isl*dif*.6;
  c2+=vec3(.92,.95,1.)*cl*(.04+dif*.95);
  vec3 hh=normalize(Lg+vec3(0.,0.,1.)); c2+=vec3(1.,.95,.85)*pow(max(dot(n,hh),0.),28.)*.28*(1.-cl);
  float lava=isl*smoothstep(.1,-.2,dot(n,Lg))*pow(h12(floor(q.xy*60.)),8.)*2.; c2+=vec3(1.,.4,.1)*lava;
  vec2 gd=(UV()-GP)/SZ; float gr=length(gd); c2+=vec3(1.,.85,.5)*GL*exp(-gr*gr*2500.)*1.4+vec3(.3,1.,.8)*GL*exp(-gr*gr*60.)*.12*term;
  col=c2*smoothstep(1.,.985,r);}
 float atm=exp(-pow(max(r-1.,0.)*16.,1.2))*smoothstep(.75,1.,r);
 float lit=clamp(dot(normalize(vec3(d,.25)),Lg)*1.3+.2,0.,1.);
 col+=vec3(.25,.6,1.)*atm*lit*.9;
 O=vec4(col*A,1.);}`);

  // ======================================================================
  // 通用画面部件
  // ======================================================================
  const MOTES = (() => { const r = rng(4242); const a = []; for (let i = 0; i < 160; i++) a.push({ x: r(), y: r(), z: r(), ph: r() * TAU, sp: .2 + r() * .8 }); return a; })();
  // 墨紫底：径向渐变 + 低强度星云 + 漂浮微尘
  function inkBg(ctx, t, o = {}) {
    const g = ctx.createRadialGradient(W / 2, H * .45, 0, W / 2, H * .5, W * .8);
    g.addColorStop(0, o.c1 || '#160c26'); g.addColorStop(.5, o.c2 || '#0d0719'); g.addColorStop(1, '#040208');
    ctx.fillStyle = g; ctx.fillRect(0, 0, W, H);
    const neb = o.neb ?? .45, sd = o.seed || 0;
    if (neb > 0) GLFX.layer(ctx, 'nebula', { T: t + sd * 37, C1: o.n1 || '#2b0f46', C2: o.n2 || '#14234a', C3: o.n3 || '#5a1f5c', S: o.ns || 1.25, D: .15, A: neb, MODE: 0, OFF: [sd * 3.1 + t * .004, sd * 1.7] });
    const ma = o.motes ?? 1;
    if (ma > 0) {
      ctx.save(); ctx.globalCompositeOperation = 'lighter';
      for (let i = 0; i < MOTES.length; i++) {
        const m = MOTES[i]; const x = ((m.x * W + t * (6 + m.z * 14) * (m.x < .5 ? -1 : 1)) % W + W) % W, y = ((m.y * H - t * (4 + m.z * 8)) % H + H) % H;
        const tw = .5 + .5 * Math.sin(t * m.sp * 2 + m.ph);
        const c = i % 3 === 0 ? TEAL : i % 3 === 1 ? ROSE : LILAC;
        if (m.z > .8) glow(ctx, x, y, 6 + m.z * 8, c, .1 * tw * ma);
        dot(ctx, x, y, .5 + m.z * 1.1, '#efe6ff', (.12 + .3 * m.z) * tw * ma);
      }
      ctx.restore();
    }
  }

  // 镜面：一道竖直的玻璃光线，带微光、游动的亮点与玻璃厚度
  let MIRROR_SPR = null;
  function mirrorSprite() {
    if (MIRROR_SPR) return MIRROR_SPR;
    const c = document.createElement('canvas'); c.width = 320; c.height = 1080; const g = c.getContext('2d');
    const hg = g.createLinearGradient(0, 0, 320, 0);
    hg.addColorStop(0, 'rgba(203,188,255,0)'); hg.addColorStop(.38, 'rgba(203,188,255,.05)'); hg.addColorStop(.47, 'rgba(225,215,255,.22)');
    hg.addColorStop(.5, 'rgba(255,255,255,.62)'); hg.addColorStop(.53, 'rgba(225,215,255,.22)'); hg.addColorStop(.62, 'rgba(203,188,255,.05)'); hg.addColorStop(1, 'rgba(203,188,255,0)');
    g.fillStyle = hg; g.fillRect(0, 0, 320, 1080);
    g.fillStyle = 'rgba(255,255,255,.42)'; g.fillRect(159.3, 0, 1.4, 1080);
    g.fillStyle = 'rgba(220,210,255,.16)'; g.fillRect(150, 0, 1, 1080); g.fillRect(169, 0, 1, 1080);
    g.globalCompositeOperation = 'destination-in';
    const vg = g.createLinearGradient(0, 0, 0, 1080); vg.addColorStop(0, 'rgba(0,0,0,0)'); vg.addColorStop(.18, 'rgba(0,0,0,.8)'); vg.addColorStop(.5, 'rgba(0,0,0,1)'); vg.addColorStop(.82, 'rgba(0,0,0,.8)'); vg.addColorStop(1, 'rgba(0,0,0,0)');
    g.fillStyle = vg; g.fillRect(0, 0, 320, 1080);
    MIRROR_SPR = c; return c;
  }
  function mirror(ctx, x, t, a, o = {}) {
    if (a <= 0) return;
    const y0 = o.y0 ?? 0, y1 = o.y1 ?? H, grow = clamp(o.grow ?? 1), cy = (y0 + y1) / 2, hh = (y1 - y0) / 2 * E.out(grow);
    const top = cy - hh, bot = cy + hh; if (hh < 1) return;
    const col = o.color || LILAC;
    ctx.save(); ctx.globalCompositeOperation = 'lighter';
    ctx.globalAlpha = a * (o.bright ?? 1); ctx.drawImage(mirrorSprite(), x - 160, top, 320, bot - top);
    // 呼吸的光脉：沿镜面分段调制
    const N = 36;
    for (let i = 0; i < N; i++) {
      const u0 = i / N, yy = lerp(top, bot, u0), hseg = (bot - top) / N; const vf = Math.sin(Math.PI * (u0 + .5 / N));
      const n = .5 + .5 * noise3(i * .23, t * .7, 3.3); const k = Math.pow(n, 3) * vf * a;
      if (k < .02) continue;
      ctx.globalAlpha = k * .32; ctx.fillStyle = col; ctx.fillRect(x - 1.2, yy, 2.4, hseg + 1);
    }
    ctx.globalAlpha = 1;
    // 游动的亮点 + 横向的细小眩光
    const ng = o.glints ?? 5;
    for (let k = 0; k < ng; k++) {
      const sp = .05 + hash(k, 31) * .07, dir = hash(k, 32) < .5 ? 1 : -1;
      const u = ((hash(k, 33) + t * sp * dir) % 1 + 1) % 1; const yy = lerp(top, bot, u); const vf = Math.sin(Math.PI * u);
      glow(ctx, x, yy, 22 + 12 * hash(k, 34), '#efe9ff', .38 * a * vf);
      const fl = ctx.createLinearGradient(x - 90, 0, x + 90, 0); fl.addColorStop(0, rgba(col, 0)); fl.addColorStop(.5, rgba('#ffffff', .32 * a * vf)); fl.addColorStop(1, rgba(col, 0));
      ctx.fillStyle = fl; ctx.fillRect(x - 90, yy - .6, 180, 1.2);
    }
    // 外部触发的涟漪闪光
    if (o.flash > 0) { glow(ctx, x, o.fy ?? cy, 260 * o.flash, '#ffffff', .35 * o.flash); const fl = ctx.createLinearGradient(x - 400, 0, x + 400, 0); fl.addColorStop(0, rgba(col, 0)); fl.addColorStop(.5, rgba('#ffffff', .7 * o.flash)); fl.addColorStop(1, rgba(col, 0)); ctx.fillStyle = fl; ctx.fillRect(x - 400, (o.fy ?? cy) - 1, 800, 2); }
    ctx.restore();
  }

  // ---------- 有明暗的球（预渲染精灵：高光 + 体积 + 边缘光） ----------
  const SPR = new Map();
  function sphereSprite(col, rim) {
    const key = col + '|' + (rim || ''); if (SPR.has(key)) return SPR.get(key);
    const s = 192, R = s * .44, c = document.createElement('canvas'); c.width = c.height = s; const g = c.getContext('2d'); const cx = s / 2, cy = s / 2;
    const base = MP.hexRgb(col);
    const gr = g.createRadialGradient(cx - R * .36, cy - R * .4, R * .04, cx - R * .08, cy - R * .08, R * 1.18);
    gr.addColorStop(0, rgba(mix(base, [255, 255, 255], .62))); gr.addColorStop(.3, rgba(mix(base, [255, 255, 255], .12)));
    gr.addColorStop(.72, rgba(mix(base, [10, 5, 20], .55))); gr.addColorStop(1, rgba(mix(base, [4, 2, 10], .88)));
    g.fillStyle = gr; g.beginPath(); g.arc(cx, cy, R, 0, TAU); g.fill();
    g.save(); g.beginPath(); g.arc(cx, cy, R, 0, TAU); g.clip(); g.globalCompositeOperation = 'lighter';
    if (rim) { const rg = g.createRadialGradient(cx - R * .2, cy - R * .2, R * .66, cx, cy, R); rg.addColorStop(0, rgba(rim, 0)); rg.addColorStop(.62, rgba(rim, 0)); rg.addColorStop(1, rgba(rim, .95)); g.fillStyle = rg; g.fillRect(0, 0, s, s); }
    const sp = g.createRadialGradient(cx - R * .38, cy - R * .42, 0, cx - R * .38, cy - R * .42, R * .3); sp.addColorStop(0, 'rgba(255,255,255,.95)'); sp.addColorStop(.35, 'rgba(255,255,255,.3)'); sp.addColorStop(1, 'rgba(255,255,255,0)');
    g.fillStyle = sp; g.fillRect(0, 0, s, s); g.restore();
    const o = { c, k: s / (2 * R) }; SPR.set(key, o); return o;
  }
  let SHADOW = null;
  function shadowSprite() { if (SHADOW) return SHADOW; const s = 128, c = document.createElement('canvas'); c.width = c.height = s; const g = c.getContext('2d'); const gr = g.createRadialGradient(s / 2, s / 2, 0, s / 2, s / 2, s / 2); gr.addColorStop(0, 'rgba(0,0,0,.55)'); gr.addColorStop(.55, 'rgba(0,0,0,.35)'); gr.addColorStop(1, 'rgba(0,0,0,0)'); g.fillStyle = gr; g.fillRect(0, 0, s, s); SHADOW = c; return c; }
  function sphere(ctx, x, y, r, col, rim, a = 1) {
    if (a <= .003 || r < .3) return; const sp = sphereSprite(col, rim);
    ctx.globalAlpha = clamp(a) * .8; const sr = r * 1.45; ctx.drawImage(shadowSprite(), x - sr + r * .12, y - sr + r * .18, sr * 2, sr * 2);
    ctx.globalAlpha = clamp(a); ctx.drawImage(sp.c, x - r * sp.k, y - r * sp.k, 2 * r * sp.k, 2 * r * sp.k); ctx.globalAlpha = 1;
  }
  // 圆柱状的键：两半各取原子色，带一道高光
  function bond(ctx, p1, p2, w, c1, c2, a = 1, order = 1) {
    if (a <= .003) return;
    if (order === 2) { const dx = p2.x - p1.x, dy = p2.y - p1.y, L = Math.hypot(dx, dy) || 1, ox = -dy / L * w * .42, oy = dx / L * w * .42; bond(ctx, { x: p1.x + ox, y: p1.y + oy }, { x: p2.x + ox, y: p2.y + oy }, w * .5, c1, c2, a); bond(ctx, { x: p1.x - ox, y: p1.y - oy }, { x: p2.x - ox, y: p2.y - oy }, w * .5, c1, c2, a); return; }
    const mx = (p1.x + p2.x) / 2, my = (p1.y + p2.y) / 2;
    const dx = p2.x - p1.x, dy = p2.y - p1.y, L = Math.hypot(dx, dy) || 1, nx = -dy / L, ny = dx / L; const sgn = (nx + ny) > 0 ? -1 : 1;
    ctx.save(); ctx.lineCap = 'butt'; ctx.globalAlpha = clamp(a);
    ctx.strokeStyle = 'rgba(4,2,10,.7)'; ctx.lineWidth = w + 3; ctx.beginPath(); ctx.moveTo(p1.x, p1.y); ctx.lineTo(p2.x, p2.y); ctx.stroke();
    ctx.lineWidth = w;
    ctx.strokeStyle = rgba(mix(c1, [16, 10, 28], .45)); ctx.beginPath(); ctx.moveTo(p1.x, p1.y); ctx.lineTo(mx, my); ctx.stroke();
    ctx.strokeStyle = rgba(mix(c2, [16, 10, 28], .45)); ctx.beginPath(); ctx.moveTo(mx, my); ctx.lineTo(p2.x, p2.y); ctx.stroke();
    const ox = nx * w * .22 * sgn, oy = ny * w * .22 * sgn;
    ctx.strokeStyle = 'rgba(255,255,255,.28)'; ctx.lineWidth = Math.max(1, w * .26); ctx.beginPath(); ctx.moveTo(p1.x + ox, p1.y + oy); ctx.lineTo(p2.x + ox, p2.y + oy); ctx.stroke();
    ctx.restore();
  }
  // 三维旋转
  const rotY = (p, a) => { const c = Math.cos(a), s = Math.sin(a); return [p[0] * c + p[2] * s, p[1], -p[0] * s + p[2] * c]; };
  const rotX = (p, a) => { const c = Math.cos(a), s = Math.sin(a); return [p[0], p[1] * c - p[2] * s, p[1] * s + p[2] * c]; };
  const rotZ = (p, a) => { const c = Math.cos(a), s = Math.sin(a); return [p[0] * c - p[1] * s, p[0] * s + p[1] * c, p[2]]; };
  const mirX = p => [-p[0], p[1], p[2]];
  // 画一个球棍分子。mol = {atoms:[{p,r,col}], bonds:[[i,j]]}；xf(p) 把模型坐标变换到世界坐标；c 为相机
  function drawMol(ctx, mol, xf, c, o = {}) {
    const a = o.alpha ?? 1; if (a <= 0) return null;
    const sc = o.scale ?? 1, rim = o.rim, bw = (o.bondW ?? 13) * sc;
    const P = mol.atoms.map(at => { const w = xf(at.p.map(v => v * sc)); const p = c.p(w[0], w[1], w[2]); return p; });
    const items = [];
    mol.atoms.forEach((at, i) => items.push({ z: P[i].z, k: 0, i }));
    mol.bonds.forEach(([i, j, ord], bi) => items.push({ z: (P[i].z + P[j].z) / 2 + 1, k: 1, i, j, bi, ord: ord || 1 }));
    items.sort((p, q) => q.z - p.z);
    for (const it of items) {
      if (it.k === 1) { const s = (P[it.i].s + P[it.j].s) / 2; bond(ctx, P[it.i], P[it.j], bw * s, mol.atoms[it.i].col, mol.atoms[it.j].col, a * (o.bondAlpha ? o.bondAlpha(it.bi) : 1), it.ord); if (o.bondGlow) o.bondGlow(it.bi, P[it.i], P[it.j]); }
      else { const at = mol.atoms[it.i], p = P[it.i]; const k = o.atomAlpha ? o.atomAlpha(it.i) : 1; sphere(ctx, p.x, p.y, at.r * sc * p.s, at.col, at.rim || rim, a * k); if (o.atomGlow) o.atomGlow(it.i, p, at.r * sc * p.s); }
    }
    return P;
  }
  // 幽灵模式：只画轮廓环（用于“试图重合”）
  function ghostMol(ctx, mol, xf, c, col, a, o = {}) {
    if (a <= 0) return null; const sc = o.scale ?? 1;
    const P = mol.atoms.map(at => { const w = xf(at.p.map(v => v * sc)); return c.p(w[0], w[1], w[2]); });
    ctx.save(); ctx.globalCompositeOperation = 'lighter'; ctx.lineWidth = 1.4;
    for (const [i, j] of mol.bonds) { const p = P[i], q = P[j]; const ri = mol.atoms[i].r * sc * p.s, rj = mol.atoms[j].r * sc * q.s; const dx = q.x - p.x, dy = q.y - p.y, L = Math.hypot(dx, dy) || 1; if (L < ri + rj) continue; ctx.strokeStyle = rgba(col, .45 * a); ctx.beginPath(); ctx.moveTo(p.x + dx / L * ri, p.y + dy / L * ri); ctx.lineTo(q.x - dx / L * rj, q.y - dy / L * rj); ctx.stroke(); }
    mol.atoms.forEach((at, i) => { const p = P[i], r = at.r * sc * p.s; ctx.fillStyle = rgba(at.col, .16 * a); ctx.beginPath(); ctx.arc(p.x, p.y, r, 0, TAU); ctx.fill(); ctx.strokeStyle = rgba(col, .9 * a); ctx.beginPath(); ctx.arc(p.x, p.y, r, 0, TAU); ctx.stroke(); ctx.strokeStyle = rgba(at.col, .8 * a); ctx.beginPath(); ctx.arc(p.x, p.y, r * .82, -2.4, -.8); ctx.stroke(); });
    ctx.restore(); return P;
  }

  // ---------- 手性四面体分子：中心碳 + 四个不同的基团 ----------
  const CARB = '#4a4361';
  const GRP = ['#efe8dc', '#f6a04d', '#6f8dff', '#a66bff'];
  const TET = (() => {
    const L = 122; const atoms = [{ p: [0, 0, 0], r: 33, col: CARB }];
    const dirs = [[0, -1, 0]]; for (const k of [90, 210, 330]) { const a = k * D2R; dirs.push([Math.cos(a) * .9428, 1 / 3, Math.sin(a) * .9428]); }
    const rr = [21, 37, 31, 43];
    dirs.forEach((d, i) => atoms.push({ p: d.map(v => v * (L + rr[i] * .35)), r: rr[i], col: GRP[i] }));
    return { atoms, bonds: [[0, 1], [0, 2], [0, 3], [0, 4]] };
  })();
  // 小型手性分子（用于“锁与钥匙”等）：同 TET，缩放使用

  // ---------- 手：程序化轮廓（左手，掌心朝向观众，拇指指向画面左侧） ----------
  const HAND = (() => {
    const F = [ // [基部x, 基部y, 角度, 长度, 半宽]
      [-104, 28, -.86, 168, 27], // 拇指
      [-62, -78, -.12, 196, 23.5],
      [-12, -94, -.02, 222, 24.5],
      [38, -84, .07, 202, 23],
      [84, -54, .19, 156, 20],
    ];
    const pts = [];
    const push = (x, y) => pts.push([x, y]);
    const fing = (f, from) => { // 沿手指一侧上行、绕指尖、另一侧下行
      const [bx, by, an, L, hw] = f; const dx = Math.sin(an), dy = -Math.cos(an), nx = Math.cos(an), ny = Math.sin(an); const tw = hw * .86;
      const tip = [bx + dx * (L - tw), by + dy * (L - tw)];
      for (let k = 0; k <= 6; k++) { const u = k / 6; const w = lerp(hw, tw, u) * (1 + .05 * Math.sin(u * Math.PI * 3)); push(bx + dx * (L - tw) * u - nx * w, by + dy * (L - tw) * u - ny * w); }
      for (let k = 1; k < 14; k++) { const th = Math.PI - k / 14 * Math.PI; push(tip[0] + nx * tw * Math.cos(th) + dx * tw * Math.sin(th), tip[1] + ny * tw * Math.cos(th) + dy * tw * Math.sin(th)); }
      for (let k = 6; k >= 0; k--) { const u = k / 6; const w = lerp(hw, tw, u) * (1 + .05 * Math.sin(u * Math.PI * 3)); push(bx + dx * (L - tw) * u + nx * w, by + dy * (L - tw) * u + ny * w); }
    };
    // 腕部左侧 → 拇指外缘
    push(-78, 270); push(-84, 200); push(-96, 140); push(-112, 96);
    fing(F[0]);
    // 虎口
    push(-84, -12); push(-80, -40);
    for (let i = 1; i < 5; i++) { fing(F[i]); if (i < 4) { const a = F[i], b = F[i + 1]; const ax = a[0] + Math.cos(a[2]) * a[4], bx2 = b[0] - Math.cos(b[2]) * b[4]; push((ax + bx2) / 2, (a[1] + b[1]) / 2 + 12); } }
    push(104, -10); push(110, 50); push(104, 130); push(90, 200); push(82, 270);
    // Catmull-Rom 平滑
    const sm = []; const n = pts.length;
    for (let i = 0; i < n - 1; i++) { const p0 = pts[Math.max(0, i - 1)], p1 = pts[i], p2 = pts[i + 1], p3 = pts[Math.min(n - 1, i + 2)]; for (let k = 0; k < 4; k++) { const u = k / 4, u2 = u * u, u3 = u2 * u; sm.push([.5 * ((2 * p1[0]) + (-p0[0] + p2[0]) * u + (2 * p0[0] - 5 * p1[0] + 4 * p2[0] - p3[0]) * u2 + (-p0[0] + 3 * p1[0] - 3 * p2[0] + p3[0]) * u3), .5 * ((2 * p1[1]) + (-p0[1] + p2[1]) * u + (2 * p0[1] - 5 * p1[1] + 4 * p2[1] - p3[1]) * u2 + (-p0[1] + 3 * p1[1] - 3 * p2[1] + p3[1]) * u3)]); } }
    sm.push(pts[n - 1]);
    // 掌纹与指节纹
    const creases = [];
    const bez = (a, b, c, d, N = 24) => { const o = []; for (let k = 0; k <= N; k++) { const u = k / N, v = 1 - u; o.push([v * v * v * a[0] + 3 * v * v * u * b[0] + 3 * v * u * u * c[0] + u * u * u * d[0], v * v * v * a[1] + 3 * v * v * u * b[1] + 3 * v * u * u * c[1] + u * u * u * d[1]]); } return o; };
    creases.push(bez([100, -22], [50, -6], [0, -24], [-52, -44]));    // 感情线
    creases.push(bez([-86, -20], [-40, 6], [20, 22], [70, 40]));      // 智慧线
    creases.push(bez([-80, -22], [-40, 40], [-46, 120], [-30, 210])); // 生命线
    const joints = [];
    F.forEach((f, fi) => { const [bx, by, an, L, hw] = f; const dx = Math.sin(an), dy = -Math.cos(an), nx = Math.cos(an), ny = Math.sin(an); for (const u of fi === 0 ? [.52] : [.4, .7]) { const cx = bx + dx * L * u, cy = by + dy * L * u, w = hw * .7; joints.push(bez([cx - nx * w, cy - ny * w], [cx - nx * w * .3 + dx * 4, cy - ny * w * .3 + dy * 4], [cx + nx * w * .3 + dx * 4, cy + ny * w * .3 + dy * 4], [cx + nx * w, cy + ny * w], 8)); } });
    // 指甲（手背时显示）
    const nails = F.map(f => { const [bx, by, an, L, hw] = f; const dx = Math.sin(an), dy = -Math.cos(an); return { x: bx + dx * (L - hw * 1.25), y: by + dy * (L - hw * 1.25), an, w: hw * .62, h: hw * .95 }; });
    const knuck = F.slice(1).map(f => { const [bx, by, an, L, hw] = f; const dx = Math.sin(an), dy = -Math.cos(an), nx = Math.cos(an), ny = Math.sin(an); const cx = bx + dx * 8, cy = by + dy * 8; return bez([cx - nx * hw * .5, cy - ny * hw * .5], [cx - nx * hw * .2 - dx * 6, cy - ny * hw * .2 - dy * 6], [cx + nx * hw * .2 - dx * 6, cy + ny * hw * .2 - dy * 6], [cx + nx * hw * .5, cy + ny * hw * .5], 8); });
    // 用于粒子的采样点（轮廓 + 内部）
    const L = [0]; for (let i = 1; i < sm.length; i++) L.push(L[i - 1] + Math.hypot(sm[i][0] - sm[i - 1][0], sm[i][1] - sm[i - 1][1]));
    const at = u => { const tg = u * L[L.length - 1]; let i = 1; while (i < L.length - 1 && L[i] < tg) i++; const k = (tg - L[i - 1]) / (L[i] - L[i - 1] || 1); return [lerp(sm[i - 1][0], sm[i][0], k), lerp(sm[i - 1][1], sm[i][1], k)]; };
    const inside = (x, y) => { let c = false; for (let i = 0, j = sm.length - 1; i < sm.length; j = i++) { const [xi, yi] = sm[i], [xj, yj] = sm[j]; if ((yi > y) !== (yj > y) && x < (xj - xi) * (y - yi) / (yj - yi) + xi) c = !c; } return c; };
    const samples = []; const r = rng(77);
    for (let i = 0; i < 520; i++) samples.push(at(i / 520));
    let guard = 0; while (samples.length < 820 && guard++ < 20000) { const x = -130 + r() * 260, y = -330 + r() * 600; if (y < 250 && inside(x, y)) samples.push([x, y]); }
    return { outline: sm, creases, joints, nails, knuck, samples };
  })();

  // 画一只手。sx：水平缩放（-1 为镜像=右手；翻转时随 cos 变化），back：显示手背
  function drawHand(ctx, x, y, sx, col, a, o = {}) {
    if (a <= 0) return; const sc = o.scale ?? 1, rev = o.reveal ?? 1, t = o.t || 0;
    const back = o.back ?? false;
    ctx.save(); ctx.translate(x, y); ctx.scale(sx * sc, sc);
    const lw = 1 / Math.max(.25, Math.abs(sx * sc));
    const path = rev >= 1 ? HAND.outline : partial(HAND.outline, rev);
    const trace = (pts) => { ctx.beginPath(); ctx.moveTo(pts[0][0], pts[0][1]); for (let i = 1; i < pts.length; i++) ctx.lineTo(pts[i][0], pts[i][1]); };
    // 柔和的体积填充
    if (rev >= 1) {
      const fg = ctx.createLinearGradient(0, -320, 0, 270); fg.addColorStop(0, rgba(col, .10 * a)); fg.addColorStop(.6, rgba(col, .05 * a)); fg.addColorStop(1, rgba(col, 0));
      ctx.fillStyle = fg; trace(HAND.outline); ctx.fill();
    }
    ctx.globalCompositeOperation = 'lighter'; ctx.lineJoin = 'round'; ctx.lineCap = 'round';
    ctx.strokeStyle = rgba(col, .10 * a); ctx.lineWidth = 12 * lw; trace(path); ctx.stroke();
    ctx.strokeStyle = rgba(col, .28 * a); ctx.lineWidth = 5 * lw; trace(path); ctx.stroke();
    ctx.strokeStyle = rgba(col, .95 * a); ctx.lineWidth = 2 * lw; trace(path); ctx.stroke();
    ctx.strokeStyle = rgba('#ffffff', .45 * a); ctx.lineWidth = .8 * lw; trace(path); ctx.stroke();
    const da = a * smooth(.7, 1, rev) * (o.detail ?? 1);
    if (da > 0) {
      ctx.lineWidth = 1.3 * lw;
      if (!back) {
        ctx.strokeStyle = rgba(col, .55 * da); for (const c of HAND.creases) { trace(c); ctx.stroke(); }
        ctx.strokeStyle = rgba(col, .38 * da); for (const c of HAND.joints) { trace(c); ctx.stroke(); }
      } else {
        ctx.strokeStyle = rgba(col, .75 * da);
        for (const n of HAND.nails) { ctx.save(); ctx.translate(n.x, n.y); ctx.rotate(n.an); ctx.beginPath(); ctx.moveTo(-n.w, n.h * .5); ctx.lineTo(-n.w, -n.h * .2); ctx.quadraticCurveTo(-n.w, -n.h, 0, -n.h); ctx.quadraticCurveTo(n.w, -n.h, n.w, -n.h * .2); ctx.lineTo(n.w, n.h * .5); ctx.quadraticCurveTo(0, n.h * .75, -n.w, n.h * .5); ctx.stroke(); ctx.restore(); }
        ctx.strokeStyle = rgba(col, .45 * da); for (const c of HAND.knuck) { trace(c); ctx.stroke(); }
        // 手背的筋络
        for (let k = 0; k < 4; k++) { const f = [-62, -12, 38, 84][k]; ctx.beginPath(); ctx.moveTo(f * .8, -50); ctx.quadraticCurveTo(f * .55, 60, f * .25, 200); ctx.strokeStyle = rgba(col, .18 * da); ctx.stroke(); }
      }
    }
    ctx.restore();
    // 沿轮廓流动的光点
    if (rev >= 1 && (o.sparks ?? 1) > 0) {
      ctx.save(); ctx.globalCompositeOperation = 'lighter'; const N = HAND.outline.length;
      for (let k = 0; k < 14; k++) { const u = ((hash(k, 91) + t * (.025 + hash(k, 92) * .02)) % 1); const p = HAND.outline[Math.floor(u * (N - 1))]; glow(ctx, x + p[0] * sx * sc, y + p[1] * sc, 14, col, .55 * a * (o.sparks ?? 1)); dot(ctx, x + p[0] * sx * sc, y + p[1] * sc, 1.6, '#ffffff', .8 * a * (o.sparks ?? 1)); }
      ctx.restore();
    }
  }

  // 错位标记：一个细线“✕”与脉冲圈
  function crossMark(ctx, x, y, r, col, a) {
    if (a <= 0) return; ctx.save(); ctx.globalCompositeOperation = 'lighter';
    glow(ctx, x, y, r * 3.2, col, .45 * a);
    ctx.strokeStyle = rgba(col, .95 * a); ctx.lineWidth = 2.2; ctx.lineCap = 'round'; const k = r * .55 * E.outBack(clamp(a * 1.2));
    ctx.beginPath(); ctx.moveTo(x - k, y - k); ctx.lineTo(x + k, y + k); ctx.moveTo(x + k, y - k); ctx.lineTo(x - k, y + k); ctx.stroke();
    ctx.lineWidth = 1.2; ctx.strokeStyle = rgba(col, .6 * a); ctx.beginPath(); ctx.arc(x, y, r * (1 + .3 * (1 - a)), 0, TAU); ctx.stroke();
    ctx.restore();
  }
  function checkMark(ctx, x, y, r, col, a) {
    if (a <= 0) return; ctx.save(); ctx.globalCompositeOperation = 'lighter';
    glow(ctx, x, y, r * 3, col, .4 * a);
    ctx.strokeStyle = rgba(col, .95 * a); ctx.lineWidth = 2.4; ctx.lineCap = 'round'; ctx.lineJoin = 'round';
    const pts = [[x - r * .5, y], [x - r * .12, y + r * .4], [x + r * .55, y - r * .42]]; line(ctx, partial(pts, clamp(a * 1.4)), rgba(col, .95 * a), 2.4);
    ctx.lineWidth = 1.2; ctx.strokeStyle = rgba(col, .55 * a); ctx.beginPath(); ctx.arc(x, y, r, 0, TAU); ctx.stroke();
    ctx.restore();
  }

  // 粒子：从源点经噪声弯曲路径飞向目标点
  function flyPt(sx, sy, tx, ty, u, i, amp = 160) {
    const e = E.inOut(clamp(u)); const b = Math.sin(Math.PI * clamp(u));
    const nx = noise3(i * .37, 1.3, u * 1.2) * amp * b, ny = noise3(i * .37, 7.9, u * 1.2) * amp * b;
    return [lerp(sx, tx, e) + nx, lerp(sy, ty, e) + ny];
  }


  // ---------- 向量小工具 ----------
  const vadd = (a, b) => [a[0] + b[0], a[1] + b[1], a[2] + b[2]], vmul = (a, k) => [a[0] * k, a[1] * k, a[2] * k];
  const vnorm = a => { const n = Math.hypot(a[0], a[1], a[2]) || 1; return [a[0] / n, a[1] / n, a[2] / n]; };
  const vcross = (a, b) => [a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0]];

  // ---------- 香芹酮（重原子 + 手性中心上的氢）。z=+1 时为 (R) 构型（在本片的右手坐标系里核对过 CIP 顺序） ----------
  const C_COL = '#4d4766', O_COL = '#ff6f5e', H_COL = '#efe9df';
  const CARVONE = (() => {
    const ring = [[0, -1.4, 0], [-1.21, -.7, 0], [-1.21, .7, 0], [0, 1.4, -.22], [1.21, .7, .3], [1.21, -.7, 0]];
    const out = i => vnorm([ring[i][0], ring[i][1], 0]);
    const O = vadd(ring[0], vmul(out(0), 1.22)), C7 = vadd(ring[1], vmul(out(1), 1.5));
    const d8 = vnorm(vadd(vmul(out(4), .55), [0, 0, .83])); const C8 = vadd(ring[4], vmul(d8, 1.5));
    const H5 = vadd(ring[4], vmul(vnorm(vadd(vmul(out(4), .55), [0, 0, -.83])), 1.05));
    const v = vnorm(vcross(d8, [0, 0, 1]));
    const C9 = vadd(C8, vmul(vnorm(vadd(vmul(d8, .5), vmul(v, .866))), 1.34)), C10 = vadd(C8, vmul(vnorm(vadd(vmul(d8, .5), vmul(v, -.866))), 1.5));
    const P = [...ring, O, C7, C8, C9, C10, H5]; const cen = P.reduce((a, p) => vadd(a, vmul(p, 1 / P.length)), [0, 0, 0]);
    const A = 60; const col = [C_COL, C_COL, C_COL, C_COL, C_COL, C_COL, O_COL, C_COL, C_COL, C_COL, C_COL, H_COL]; const rad = [21, 21, 21, 21, 21, 21, 24, 20, 21, 20, 20, 12];
    return { atoms: P.map((p, i) => ({ p: vmul([p[0] - cen[0], p[1] - cen[1], p[2] - cen[2]], A), r: rad[i], col: col[i] })), bonds: [[0, 1], [1, 2, 2], [2, 3], [3, 4], [4, 5], [5, 0], [0, 6, 2], [1, 7], [4, 8], [8, 9, 2], [8, 10], [4, 11]] };
  })();

  // 水平面上的三维圆环（可只画前半或后半）
  function ring3(ctx, c, ctr, rad, col, a, o = {}) {
    if (a <= 0) return; const N = 56; const pts = [];
    for (let k = 0; k <= N; k++) { const an = k / N * TAU; const w = [ctr[0] + Math.cos(an) * rad, ctr[1], ctr[2] + Math.sin(an) * rad]; const p = c.p(w[0], w[1], w[2]); pts.push([p.x, p.y, w[2] - ctr[2]]); }
    ctx.save(); ctx.globalCompositeOperation = 'lighter'; ctx.lineCap = 'round';
    if (o.fill) { ctx.fillStyle = rgba(col, o.fill * a); ctx.beginPath(); pts.forEach((p, i) => i ? ctx.lineTo(p[0], p[1]) : ctx.moveTo(p[0], p[1])); ctx.fill(); }
    for (const [w, al] of [[o.w ? o.w * 4 : 7, .12], [o.w || 2, .9]]) {
      ctx.strokeStyle = rgba(col, al * a); ctx.lineWidth = w; ctx.beginPath(); let pen = false;
      for (const p of pts) { const ok = !o.half || (o.half === 'front' ? p[2] <= 0 : p[2] >= 0); if (ok) { pen ? ctx.lineTo(p[0], p[1]) : ctx.moveTo(p[0], p[1]); pen = true; } else pen = false; }
      ctx.stroke();
    }
    ctx.restore();
  }

  // 程序化薄荷叶：锯齿叶缘 + 主脉侧脉 + 高光
  function mintLeaf(ctx, x, y, sz, ang, a, t, grow = 1) {
    if (a <= 0) return; ctx.save(); ctx.translate(x, y); ctx.rotate(ang); const sc = sz / 200; ctx.scale(sc, sc);
    const N = 90, L = 200; const half = side => { const pts = []; for (let i = 0; i <= N; i++) { const u = i / N; let w = 66 * Math.pow(Math.sin(Math.PI * Math.pow(u, .8)), .85) * (1 - .25 * u); const tooth = 1 + .07 * (1 - Math.abs(((u * 13) % 1) * 2 - 1)) * smooth(.05, .2, u) * (1 - smooth(.9, 1, u)); w *= tooth; pts.push([w * side, -u * L * grow]); } return pts; };
    const lp = half(-1), rp = half(1);
    ctx.beginPath(); ctx.moveTo(0, 0); lp.forEach(p => ctx.lineTo(p[0], p[1])); for (let i = rp.length - 1; i >= 0; i--) ctx.lineTo(rp[i][0], rp[i][1]); ctx.closePath();
    const g = ctx.createLinearGradient(-60, -L, 60, 0); g.addColorStop(0, rgba('#5fe0a6', .85 * a)); g.addColorStop(.5, rgba('#1f8f6a', .8 * a)); g.addColorStop(1, rgba('#0b4a3a', .85 * a));
    ctx.fillStyle = g; ctx.fill();
    ctx.globalCompositeOperation = 'lighter'; ctx.strokeStyle = rgba(MINT, .7 * a); ctx.lineWidth = 1.6 / sc; ctx.stroke();
    // 叶脉
    ctx.strokeStyle = rgba('#c8ffe6', .55 * a); ctx.lineWidth = 2 / sc; ctx.beginPath(); ctx.moveTo(0, 20); ctx.lineTo(0, -L * grow * .97); ctx.stroke();
    ctx.lineWidth = 1.1 / sc; ctx.strokeStyle = rgba('#c8ffe6', .35 * a);
    for (let k = 1; k <= 6; k++) { const u = k / 7.3; const y0 = -u * L * grow; for (const sd of [-1, 1]) { const w = 60 * Math.pow(Math.sin(Math.PI * Math.pow(u + .08, .8)), .85) * (1 - .25 * u); ctx.beginPath(); ctx.moveTo(0, y0); ctx.quadraticCurveTo(sd * w * .45, y0 - 10, sd * w * .86, y0 - 34); ctx.stroke(); } }
    // 叶柄
    ctx.strokeStyle = rgba('#2f9f78', .9 * a); ctx.lineWidth = 3.2 / sc; ctx.beginPath(); ctx.moveTo(0, 0); ctx.quadraticCurveTo(4, 26, 12, 46); ctx.stroke();
    // 光泽
    const hg = ctx.createRadialGradient(-22, -L * .58, 0, -22, -L * .58, 70); hg.addColorStop(0, rgba('#e6fff4', .22 * a)); hg.addColorStop(1, rgba('#e6fff4', 0)); ctx.fillStyle = hg; ctx.fillRect(-90, -L, 180, L);
    ctx.restore();
  }
  // 葛缕子籽：弯月形，纵棱
  function carawaySeed(ctx, x, y, len, ang, a) {
    if (a <= 0) return; ctx.save(); ctx.translate(x, y); ctx.rotate(ang);
    const N = 30, bend = len * .16, w = len * .13; const top = [], bot = [];
    for (let i = 0; i <= N; i++) { const u = i / N, xx = (u - .5) * len, cy = -bend * (1 - Math.pow(2 * u - 1, 2)); const ww = w * Math.pow(Math.sin(Math.PI * u), .7); top.push([xx, cy - ww]); bot.push([xx, cy + ww]); }
    ctx.beginPath(); top.forEach((p, i) => i ? ctx.lineTo(p[0], p[1]) : ctx.moveTo(p[0], p[1])); for (let i = N; i >= 0; i--) ctx.lineTo(bot[i][0], bot[i][1]); ctx.closePath();
    const g = ctx.createLinearGradient(0, -bend - w, 0, w); g.addColorStop(0, rgba('#e2a25c', a)); g.addColorStop(.5, rgba('#8a4f22', a)); g.addColorStop(1, rgba('#3a1d0c', a)); ctx.fillStyle = g; ctx.fill();
    ctx.strokeStyle = rgba('#ffc98a', .6 * a); ctx.lineWidth = 1; ctx.stroke();
    ctx.lineWidth = .9;
    for (let k = -2; k <= 2; k++) { ctx.strokeStyle = rgba(k % 2 ? '#3a1d0c' : '#ffd7a0', (k % 2 ? .5 : .35) * a); ctx.beginPath(); for (let i = 2; i <= N - 2; i++) { const u = i / N, xx = (u - .5) * len, cy = -bend * (1 - Math.pow(2 * u - 1, 2)); const ww = w * Math.pow(Math.sin(Math.PI * u), .7) * k / 2.6; i === 2 ? ctx.moveTo(xx, cy + ww) : ctx.lineTo(xx, cy + ww); } ctx.stroke(); }
    ctx.restore();
  }


  // 章节开场：一道镜面光自中线向两侧打开（全片反复出现的转场母题）
  function mirrorOpen(ctx, t) {
    const u = smooth(-.75, 1.1, t); if (u <= 0 || u >= 1) return;
    const k = Math.sin(Math.PI * u); const dx = E.out(u) * W * .55;
    ctx.save(); ctx.setTransform(1, 0, 0, 1, 0, 0); ctx.globalCompositeOperation = 'lighter';
    for (const sd of [-1, 1]) {
      const x = MX + sd * dx; const g = ctx.createLinearGradient(x - 70, 0, x + 70, 0); g.addColorStop(0, rgba(LILAC, 0)); g.addColorStop(.5, rgba('#ffffff', .22 * k)); g.addColorStop(1, rgba(LILAC, 0));
      ctx.fillStyle = g; ctx.fillRect(x - 70, 0, 140, H);
      ctx.fillStyle = rgba('#ffffff', .35 * k); ctx.fillRect(x - .7, 0, 1.4, H);
      // 镜面碎片般的斜向光棱
      for (let j = 0; j < 5; j++) { const yy = H * (.15 + .7 * hash(j, 501)); const len = 120 + 160 * hash(j, 502); ctx.strokeStyle = rgba(j % 2 ? TEAL : ROSE, .18 * k); ctx.lineWidth = 1; ctx.beginPath(); ctx.moveTo(x, yy); ctx.lineTo(x - sd * len, yy + (hash(j, 503) - .5) * len * .8); ctx.stroke(); }
    }
    const cg = ctx.createLinearGradient(MX - 300, 0, MX + 300, 0); cg.addColorStop(0, rgba(LILAC, 0)); cg.addColorStop(.5, rgba(LILAC, .1 * (1 - u))); cg.addColorStop(1, rgba(LILAC, 0)); ctx.fillStyle = cg; ctx.fillRect(MX - 300, 0, 600, H);
    ctx.restore();
  }

  // ======================================================================
  // 场景
  // ======================================================================
  const scenes = {};
  const MX = W / 2; // 镜面所在 x

  // 1. 双手 → 手性分子
  scenes.hands = (ctx, S) => {
    const t = S.t, c1 = S.cue(1);
    inkBg(ctx, t, { neb: .4 });
    const HY = 520, HD = 400; // 手的高度、离镜面的距离
    // —— 第一句：双手相合而不能重合 ——
    const meet = prog(t, 2.5, 3.6, E.inOut) * (1 - prog(t, 6.6, 7.6, E.inOut));
    const flip = prog(t, 4.5, 5.6, E.inOut) * (1 - prog(t, 6.6, 7.6, E.inOut)); // 右手绕竖轴翻转 0→π
    const dis = prog(t, c1 - .1, c1 + 1.4, x => x); // 消散为粒子
    const ha = smooth(.3, 1.2, t) * (1 - smooth(c1 + .2, c1 + 1.0, t));
    const lx = lerp(MX - HD, MX, meet), rx = lerp(MX + HD, MX, meet);
    const rev = prog(t, .5, 2.4, E.inOut);
    const mflash = smooth(3.3, 3.6, t) * (1 - smooth(3.6, 4.4, t)) + .6 * smooth(5.3, 5.6, t) * (1 - smooth(5.6, 6.4, t));
    mirror(ctx, MX, t, smooth(0, 1.2, t) * (1 - .7 * meet) * (1 - smooth(c1 - .2, c1 + .8, t)), { grow: prog(t, 0, 1.6, E.out), flash: mflash, fy: HY - 40, y0: 90, y1: 820 });
    if (ha > 0) {
      const phi = flip * Math.PI; let rsx = -Math.cos(phi); if (Math.abs(rsx) < .01) rsx = .01; const back = Math.cos(phi) < 0;
      drawHand(ctx, lx, HY, 1, TEAL, ha, { reveal: rev, t });
      drawHand(ctx, rx, HY, rsx, ROSE, ha * (meet > .05 ? .92 : 1), { reveal: rev, t, back, sparks: 1 - meet * .7 });
      // 错位：拇指指向相反的方向
      const m1 = smooth(3.5, 3.9, t) * (1 - smooth(4.4, 4.7, t));
      if (m1 > 0) {
        const tl = [MX - 104 + Math.sin(-.86) * 100, HY + 28 - Math.cos(-.86) * 100];
        crossMark(ctx, tl[0], tl[1], 26, TEAL, m1); crossMark(ctx, 2 * MX - tl[0], tl[1], 26, ROSE, m1);
        text(ctx, '拇指方向相反', MX, 860, { size: 30, font: 'song', weight: 500, spacing: .3, color: '#efe6ff', alpha: m1 });
      }
      const m2 = smooth(5.6, 6.0, t) * (1 - smooth(6.5, 6.9, t));
      if (m2 > 0) {
        crossMark(ctx, MX, HY - 40, 34, '#ffffff', m2);
        text(ctx, '掌心', MX - 150, 860, { size: 30, font: 'song', weight: 500, spacing: .3, color: TEAL, alpha: m2 });
        text(ctx, '≠', MX, 858, { size: 34, font: 'song', weight: 300, color: '#efe6ff', alpha: m2 });
        text(ctx, '手背', MX + 150, 860, { size: 30, font: 'song', weight: 500, spacing: .3, color: ROSE, alpha: m2 });
      }
    }
    // —— 第二句：手化作粒子，聚成两只镜像的手性分子 ——
    const molA = smooth(c1 + 1.6, c1 + 2.6, t);
    const th = .5 + (t - c1) * .32; // 左分子绕竖轴的角度；右分子取镜像
    const glide = prog(t, c1 + 4.4, c1 + 5.0, E.inOut) * (1 - prog(t, c1 + 6.4, c1 + 7.0, E.inOut));
    const MD = 430, MY = 470;
    const camL = cam({ pitch: .3, dist: 1300, fov: 1300, cx: MX - MD, cy: MY });
    const camR = cam({ pitch: .3, dist: 1300, fov: 1300, cx: MX + MD, cy: MY });
    const xfL = p => rotY(p, th), xfR = p => mirX(rotY(p, th));
    if (dis > 0 && t < c1 + 3.4) {
      // 粒子：从手的轮廓飞向分子上的原子
      ctx.save(); ctx.globalCompositeOperation = 'lighter';
      const PL = TET.atoms.map(at => { const w = xfL(at.p); return camL.p(w[0], w[1], w[2]); });
      const PR = TET.atoms.map(at => { const w = xfR(at.p); return camR.p(w[0], w[1], w[2]); });
      const NS = HAND.samples.length;
      for (let side = 0; side < 2; side++) {
        const sgn = side ? -1 : 1, hx = side ? MX + HD : MX - HD, col = side ? ROSE : TEAL, PP = side ? PR : PL;
        for (let i = 0; i < NS; i += 1) {
          const s = HAND.samples[i]; const d0 = hash(i, 5) * .35; const u = clamp((t - c1 + .1 - d0 * 1.5) / 2.3);
          if (u <= 0) { if (dis > 0) dot(ctx, hx + s[0] * sgn, HY + s[1], 1.3, col, .6 * (1 - smooth(c1 + .2, c1 + 1, t))); continue; }
          const ai = Math.floor(hash(i, 6) * 4.999); const at = TET.atoms[ai], p = PP[ai]; const rr = at.r * p.s * Math.sqrt(hash(i, 7)) * .95, aa = hash(i, 8) * TAU;
          const q = flyPt(hx + s[0] * sgn, HY + s[1], p.x + Math.cos(aa) * rr, p.y + Math.sin(aa) * rr, u, i + side * 999, 140);
          const fade = 1 - smooth(.85, 1, u) * smooth(c1 + 1.8, c1 + 3.2, t);
          const c = ai === 0 || u <= .7 ? col : rgba(mix(col, GRP[ai - 1], (u - .7) / .3));
          dot(ctx, q[0], q[1], 1.6, c, .85 * fade);
          if (i % 9 === 0) glow(ctx, q[0], q[1], 10, col, .35 * fade);
        }
      }
      ctx.restore();
    }
    if (molA > 0) {
      // 原子相同、连接相同：依次点亮
      const pa = env(t, c1 + 2.1, c1 + 3.5, .3, .4), pb = env(t, c1 + 3.3, c1 + 4.4, .3, .4);
      const atomGlow = (side) => (i, p, r) => { if (pa > 0) glow(ctx, p.x, p.y, r * 2.4, side ? ROSE : TEAL, .35 * pa); };
      const bondGlow = (side) => (bi, p, q) => { if (pb > 0) { const u = clamp((t - c1 - 3.3) / .9); ctx.save(); ctx.globalCompositeOperation = 'lighter'; glow(ctx, lerp(p.x, q.x, u), lerp(p.y, q.y, u), 18, '#ffffff', .8 * pb); ctx.restore(); } };
      // 镜面
      mirror(ctx, MX, t, molA * .9 * (1 - .85 * glide), { y0: 90, y1: 770, flash: env(t, c1 + 4.8, c1 + 5.3, .1, .4) * .6, fy: MY });
      const lcx = lerp(MX - MD, MX, glide), rcx = lerp(MX + MD, MX, glide);
      const cL = cam({ pitch: .3, dist: 1300, fov: 1300, cx: lcx, cy: MY });
      const cR = cam({ pitch: .3, dist: 1300, fov: 1300, cx: rcx, cy: MY });
      // 试图重合：右分子取左分子同向，再绕竖轴尝试旋转
      const tryRot = prog(t, c1 + 5.45, c1 + 6.0, E.inOut) * 120 * D2R;
      const align = glide;
      const xfR2 = p => { const m = mirX(p); return rotY(m, lerp(-th, th, align) + tryRot * align); };
      ctx.save(); ctx.globalAlpha = 1;
      drawMol(ctx, TET, xfL, cL, { alpha: molA, rim: TEAL, atomGlow: atomGlow(0), bondGlow: bondGlow(0), scale: 1.15 });
      if (glide < .5) drawMol(ctx, TET, xfR2, cR, { alpha: molA * (1 - smooth(.2, .5, glide)), rim: ROSE, atomGlow: atomGlow(1), bondGlow: bondGlow(1), scale: 1.15 });
      const P = ghostMol(ctx, TET, xfR2, cR, ROSE, molA * smooth(.15, .5, glide), { scale: 1.15 });
      ctx.restore();
      // 错位闪光
      if (glide > .9 && P) {
        const PL = TET.atoms.map(at => { const w = xfL(at.p.map(v => v * 1.15)); return cL.p(w[0], w[1], w[2]); });
        const f1 = env(t, c1 + 5.0, c1 + 5.45, .12, .2), f2 = env(t, c1 + 6.0, c1 + 6.45, .12, .2);
        const f = f1 + f2;
        if (f > 0) for (let i = 1; i < 5; i++) { const d = Math.hypot(PL[i].x - P[i].x, PL[i].y - P[i].y); if (d > 12) { crossMark(ctx, (PL[i].x + P[i].x) / 2, (PL[i].y + P[i].y) / 2 - 0, 20, '#ffffff', f); line(ctx, [[PL[i].x, PL[i].y], [P[i].x, P[i].y]], rgba('#ffffff', .6 * f), 1.2); } else glow(ctx, P[i].x, P[i].y, 40, TEAL, .4 * f); }
      }
      text(ctx, '转来转去，总有两处错位', MX, 790, { size: 28, font: 'song', weight: 500, color: '#efe6ff', alpha: env(t, c1 + 4.9, c1 + 6.5, .3, .4), spacing: .25 });
      // 标注
      const la = smooth(c1 + 7.0, c1 + 7.8, t);
      if (la > 0) {
        text(ctx, '左手型', MX - MD, 760, { size: 30, font: 'song', weight: 500, spacing: .4, color: TEAL, alpha: la });
        text(ctx, '右手型', MX + MD, 760, { size: 30, font: 'song', weight: 500, spacing: .4, color: ROSE, alpha: la });
      }
      term(ctx, '手性', 'chirality', MX, 836, { alpha: smooth(c1 + 6.8, c1 + 7.8, t), color: LILAC, size: 46, glow: 18 });
    }
  };

  // 2. 片名
  scenes.title = (ctx, S) => {
    const t = S.t;
    inkBg(ctx, t, { neb: .25, motes: .6, c1: '#1a0d2c' });
    GLFX.layer(ctx, 'kaleido', { T: t + 20, A: 1.1 * smooth(0, 1.4, t), N: 6, SP: .02, C1: '#1d8a78', C2: '#a8306c', C3: '#ffd27a' });
    // 中心变暗以托住片名
    const g = ctx.createRadialGradient(W / 2, H / 2, 0, W / 2, H / 2, 620); g.addColorStop(0, 'rgba(8,4,14,.78)'); g.addColorStop(.6, 'rgba(8,4,14,.35)'); g.addColorStop(1, 'rgba(8,4,14,0)');
    ctx.fillStyle = g; ctx.fillRect(0, 0, W, H);
    titleCard(ctx, t, S.d, { kicker: '2026 诺贝尔化学奖', title: '积微成著', sub: '手性的放大与生命的偏手之谜', color: GOLD });
  };


  // 3. 镜中两物：性质相同；遇到手性受体则判若两物；香芹酮的两种气味
  const SEEDS = (() => { const r = rng(808); const a = []; const P = [[-95, -6, .25], [-30, -18, -.35], [40, -10, .15], [100, 2, -.5], [-60, 22, -.1], [10, 18, .45], [75, 30, .05], [-118, 34, .6]]; P.forEach(([x, y, an]) => a.push({ x: x + (r() - .5) * 10, y: y + (r() - .5) * 6, an: an + (r() < .5 ? Math.PI : 0), l: 74 + r() * 14 })); return a; })();
  scenes.mirror = (ctx, S) => {
    const t = S.t, c0 = S.cue(0), c1 = S.cue(1), e0 = S.cend(0);
    inkBg(ctx, t, { neb: .38, seed: 2 });
    const MD = 420;
    // —— A：镜像分子 + 性质读数 + 手性受体 ——
    const aA = 1 - smooth(c1 - .7, c1 - .1, t);
    if (aA > 0) {
      const recA = smooth(e0 - 4.0, e0 - 3.3, t);                       // 受体出现
      const desc = prog(t, e0 - 3.2, e0 - 2.3, E.inOut);                // 下降
      const bounce = smooth(e0 - 2.3, e0 - 1.7, t);                     // 右侧弹开
      const th0 = .55 + t * .35, psi = .2 + Math.sin(t * .35) * .06;
      const dock = prog(t, e0 - 4.2, e0 - 3.2, E.inOut);                // 取向转到对接姿态
      const MY = lerp(380, 300, dock);
      mirror(ctx, MX, t, aA * smooth(0, 1, t) * .85, { y0: 90, y1: lerp(600, 880, recA) });
      const cL = cam({ pitch: lerp(.3, .42, dock), dist: 1300, fov: 1300, cx: MX - MD, cy: MY });
      const cR = cam({ pitch: lerp(.3, .42, dock), dist: 1300, fov: 1300, cx: MX + MD, cy: MY });
      const drop = lerp(-150, 0, desc);
      const yawL = lerp(th0, psi, dock), yawR = lerp(-th0, psi, dock);
      const xfL = p => { const q = rotY(p, yawL); return [q[0], q[1] + drop * recA, q[2]]; };
      const bob = bounce > 0 ? -62 * E.out(bounce) + Math.sin(t * 9) * 3 * bounce : 0;
      const xfR = p => { const q = rotY(mirX(p), yawR); return [q[0], q[1] + (drop + bob) * recA, q[2]]; };
      // 受体：一块圆形托台 + 三个与基团同色的“插座”，两侧完全相同（并非镜像）
      const sockets = [2, 3, 4].map(i => { const q = rotY(TET.atoms[i].p, psi); return { p: [q[0], q[1] + TET.atoms[i].r * .7, q[2]], r: TET.atoms[i].r * 1.25, col: TET.atoms[i].col }; });
      const plateY = Math.max(...sockets.map(s => s.p[1])) + 34;
      const drawRec = (c, side, front) => {
        if (recA <= 0) return; const a = recA * aA;
        if (!front) {
          ring3(ctx, c, [0, plateY, 0], 205 * E.out(recA), LILAC, a * .7, { fill: .07, w: 1.4 });
          ring3(ctx, c, [0, plateY + 22, 0], 205 * E.out(recA), LILAC, a * .25, { w: 1 });
          sockets.forEach(sk => { const p0 = c.p(sk.p[0], sk.p[1], sk.p[2]), p1 = c.p(sk.p[0], plateY, sk.p[2]); line(ctx, [[p0.x, p0.y], [p1.x, p1.y]], rgba(LILAC, .35 * a), 1.2); });
        }
        sockets.forEach((sk, k) => {
          let col = sk.col, w = 2;
          if (desc >= 1) { const hit = side === 0 || k === 0; const f = smooth(e0 - 2.3, e0 - 2.0, t); col = rgba(mix(sk.col, hit ? GOLD : ROSE, f)); w = 2 + f * 1.2; }
          ring3(ctx, c, sk.p, sk.r, typeof col === 'string' && col[0] === '#' ? col : sk.col, a, { half: front ? 'front' : 'back', w, fill: front ? 0 : .12 });
          if (desc >= 1 && typeof col !== 'string' || (desc >= 1 && col[0] !== '#')) { /* colour shift handled below */ }
        });
      };
      drawRec(cL, 0, false); drawRec(cR, 1, false);
      drawMol(ctx, TET, xfL, cL, { alpha: aA * smooth(0, .8, t), rim: TEAL });
      drawMol(ctx, TET, xfR, cR, { alpha: aA * smooth(0, .8, t), rim: ROSE });
      drawRec(cL, 0, true); drawRec(cR, 1, true);
      // 对接结果
      if (desc >= 1) {
        const f = smooth(e0 - 2.3, e0 - 1.9, t) * aA;
        sockets.forEach((sk, k) => {
          const pL = cL.p(sk.p[0], sk.p[1], sk.p[2]), pR = cR.p(sk.p[0], sk.p[1], sk.p[2]);
          ring3(ctx, cL, sk.p, sk.r * 1.12, GOLD, f * .9, { w: 2 });
          if (k === 0) ring3(ctx, cR, sk.p, sk.r * 1.12, GOLD, f * .5, { w: 1.5 }); else crossMark(ctx, pR.x, pR.y + 6, 18, ROSE, f * env(t, e0 - 2.3, S.d, .2, .1));
        });
        checkMark(ctx, MX - MD, 740, 22, GOLD, smooth(e0 - 1.9, e0 - 1.4, t) * aA);
        text(ctx, '契合', MX - MD, 800, { size: 34, font: 'song', weight: 600, spacing: .5, color: '#ffe6b0', alpha: smooth(e0 - 1.8, e0 - 1.2, t) * aA });
        crossMark(ctx, MX + MD, 740, 22, ROSE, smooth(e0 - 1.9, e0 - 1.4, t) * aA);
        text(ctx, '不合', MX + MD, 800, { size: 34, font: 'song', weight: 600, spacing: .5, color: '#ffc0d8', alpha: smooth(e0 - 1.8, e0 - 1.2, t) * aA });
      }
      if (recA > 0) {
        const la = recA * aA * (1 - smooth(e0 - 2.4, e0 - 2, t)); const pl = cL.p(-200, plateY, 0), pr = cR.p(200, plateY, 0);
        label(ctx, '手性受体', pl.x, pl.y, { alpha: la, dx: -60, dy: 110, size: 26, en: 'chiral receptor' });
        label(ctx, '同一个受体', pr.x, pr.y, { alpha: la, dx: 60, dy: 110, size: 26, en: 'identical, not mirrored' });
      }
      // 熔点、沸点：两侧等长的读数条
      const ra = smooth(c0 + 1.0, c0 + 1.8, t) * (1 - smooth(e0 - 4.4, e0 - 3.8, t)) * aA;
      if (ra > 0) {
        [['熔点', 'melting point'], ['沸点', 'boiling point']].forEach(([zh, en], k) => {
          const y = 650 + k * 82, L = 300 * E.out(prog(t, c0 + 1.4 + k * .9, c0 + 2.6 + k * .9, x => x));
          text(ctx, zh, MX, y - 6, { size: 34, font: 'song', weight: 600, spacing: .3, color: IVORY, alpha: ra });
          text(ctx, en.toUpperCase(), MX, y + 26, { size: 13, font: 'latin', weight: 600, spacing: .3, color: rgba(LILAC, .8), alpha: ra });
          for (const sd of [-1, 1]) {
            const x0 = MX + sd * 92, x1 = x0 + sd * L, col = sd < 0 ? TEAL : ROSE;
            ctx.save(); ctx.globalAlpha = ra; ctx.strokeStyle = rgba(col, .25); ctx.lineWidth = 1; ctx.beginPath(); ctx.moveTo(x0, y); ctx.lineTo(x0 + sd * 300, y); ctx.stroke();
            const g = ctx.createLinearGradient(x0, 0, x1, 0); g.addColorStop(0, rgba(col, .2)); g.addColorStop(1, rgba(col, 1)); ctx.strokeStyle = g; ctx.lineWidth = 3; ctx.beginPath(); ctx.moveTo(x0, y); ctx.lineTo(x1, y); ctx.stroke(); ctx.restore();
            ctx.save(); ctx.globalCompositeOperation = 'lighter'; glow(ctx, x1, y, 22, col, ra); dot(ctx, x1, y, 3.5, '#ffffff', ra); ctx.restore();
          }
        });
        text(ctx, '＝　完全相同　＝', MX, 820, { size: 26, font: 'song', weight: 500, spacing: .3, color: GOLD, alpha: ra * smooth(c0 + 3.4, c0 + 4.2, t) });
      }
    }
    // —— B：香芹酮 ——
    const aB = smooth(c1 - .25, c1 + .55, t);
    if (aB > 0) {
      const PY = 330;
      const lA = smooth(c1 + .6, c1 + 1.8, t), rA = smooth(c1 + 3.4, c1 + 4.6, t);
      // 香气：从叶与籽升起，穿过分子
      GLFX.layer(ctx, 'wisp', { T: t, C1: '#4fe3c1', C2: '#d98a4e', P1: GLFX.uv(MX - MD, 690), P2: GLFX.uv(MX + MD, 700), A: 1.2 * aB, A1: lA, A2: rA * .62, HT: .62 });
      mirror(ctx, MX, t, aB * .85, { y0: 90, y1: 880 });
      const th = .35 * Math.sin((t - c1) * .45) + .1;
      const cL = cam({ pitch: .25, dist: 1300, fov: 1300, cx: MX - MD, cy: PY });
      const cR = cam({ pitch: .25, dist: 1300, fov: 1300, cx: MX + MD, cy: PY });
      const tilt = p => rotX(rotZ(p, .18), -.12);
      drawMol(ctx, CARVONE, p => rotY(tilt(p), th), cL, { alpha: aB, rim: TEAL, bondW: 9, scale: 1.05 });
      drawMol(ctx, CARVONE, p => mirX(rotY(tilt(p), th)), cR, { alpha: aB, rim: AMBER, bondW: 9, scale: 1.05 });
      // 留兰香（薄荷叶）
      ctx.save(); ctx.globalCompositeOperation = 'lighter'; glow(ctx, MX - MD, 690, 200, TEAL, .18 * lA); glow(ctx, MX + MD, 700, 200, AMBER, .18 * rA); ctx.restore();
      mintLeaf(ctx, MX - MD - 40, 740, 170, -.55, lA, t, E.out(lA));
      mintLeaf(ctx, MX - MD + 46, 748, 130, .62, lA * .9, t, E.out(lA));
      SEEDS.forEach((sd, i) => carawaySeed(ctx, MX + MD + sd.x, 712 + sd.y, sd.l, sd.an, rA * smooth(i * .08, i * .08 + .4, rA)));
      term(ctx, '(R)-香芹酮 · 留兰香', '(R)-carvone · spearmint', MX - MD, 846, { alpha: smooth(c1 + 1.2, c1 + 2.2, t), color: TEAL, size: 34 });
      term(ctx, '(S)-香芹酮 · 葛缕子', '(S)-carvone · caraway', MX + MD, 846, { alpha: smooth(c1 + 4.0, c1 + 5.0, t), color: AMBER, size: 34 });
    }
  };


  // ---------- 生命的螺旋 ----------
  // α-螺旋（右手螺旋：沿 −y 上升时绕 x→z 方向旋转）
  function alphaHelix(ctx, cx, cy, o = {}) {
    const a = o.alpha ?? 1; if (a <= 0) return; const n = o.n ?? 26, R = (o.R ?? 70) * (o.sc ?? 1), rise = (o.rise ?? 23) * (o.sc ?? 1), yaw = o.yaw || 0, grow = o.grow ?? 1;
    const c = cam({ pitch: o.pitch ?? .12, dist: 1600, fov: 1600, cx, cy });
    const P = s => { const an = s * TAU / 3.6 + yaw; return c.p(R * Math.cos(an), -(s - (n - 1) / 2) * rise, R * Math.sin(an)); };
    const items = []; const shown = grow * (n - 1);
    for (let k = 0; k < (n - 1) * 8; k++) { const s0 = k / 8, s1 = (k + 1) / 8; if (s1 > shown + .001) break; const p0 = P(s0), p1 = P(s1); items.push({ z: (p0.z + p1.z) / 2, k: 0, p0, p1 }); }
    for (let i = 0; i < n; i++) { if (i > shown + .001) break; const p = P(i); items.push({ z: p.z - 1, k: 1, p, i }); if (i + 4 <= shown && i + 4 < n) { const q = P(i + 4); items.push({ z: (p.z + q.z) / 2 + 2, k: 2, p, q }); } }
    items.sort((u, v) => v.z - u.z);
    const col = o.col || TEAL; const zc = 1600;
    for (const it of items) {
      const dep = clamp(1 - (it.z - zc + R) / (2 * R)) * .6 + .4;
      if (it.k === 0) { ctx.strokeStyle = rgba(mix(col, '#0a1a18', 1 - dep), a * (.4 + .6 * dep)); ctx.lineWidth = 7 * it.p0.s * (o.sc ?? 1); ctx.lineCap = 'round'; ctx.beginPath(); ctx.moveTo(it.p0.x, it.p0.y); ctx.lineTo(it.p1.x, it.p1.y); ctx.stroke(); }
      else if (it.k === 1) { const pop = o.pop ? o.pop(it.i) : 1; sphere(ctx, it.p.x, it.p.y, 15 * it.p.s * (o.sc ?? 1) * pop, o.bead || col, o.rim || '#ffffff', a * (.55 + .45 * dep)); }
      else { ctx.save(); ctx.setLineDash([3, 5]); ctx.strokeStyle = rgba(LILAC, .22 * a * dep); ctx.lineWidth = 1; ctx.beginPath(); ctx.moveTo(it.p.x, it.p.y); ctx.lineTo(it.q.x, it.q.y); ctx.stroke(); ctx.restore(); }
    }
    if (o.glowA) { ctx.save(); ctx.globalCompositeOperation = 'lighter'; glow(ctx, cx, cy, n * rise * .7, col, .12 * a * o.glowA); ctx.restore(); }
  }
  // DNA 双螺旋（同为右手），糖-磷酸骨架上的糖用 ROSE
  function dnaHelix(ctx, cx, cy, o = {}) {
    const a = o.alpha ?? 1; if (a <= 0) return; const n = o.n ?? 18, R = (o.R ?? 92) * (o.sc ?? 1), rise = (o.rise ?? 34) * (o.sc ?? 1), yaw = o.yaw || 0, grow = o.grow ?? 1, off = 2.35;
    const c = cam({ pitch: o.pitch ?? .12, dist: 1600, fov: 1600, cx, cy });
    const P = (s, k) => { const an = s * TAU / 10.5 + yaw + k * off; return c.p(R * Math.cos(an), -(s - (n - 1) / 2) * rise, R * Math.sin(an)); };
    const items = []; const shown = grow * (n - 1);
    for (let k = 0; k < 2; k++) for (let j = 0; j < (n - 1) * 6; j++) { const s0 = j / 6, s1 = (j + 1) / 6; if (s1 > shown + .001) break; const p0 = P(s0, k), p1 = P(s1, k); items.push({ z: (p0.z + p1.z) / 2, k: 0, p0, p1 }); }
    for (let i = 0; i < n; i++) { if (i > shown + .001) break; const pA = P(i, 0), pB = P(i, 1); items.push({ z: pA.z - 1, k: 1, p: pA }); items.push({ z: pB.z - 1, k: 1, p: pB }); items.push({ z: (pA.z + pB.z) / 2 + 3, k: 2, p: pA, q: pB, i }); }
    items.sort((u, v) => v.z - u.z); const zc = 1600;
    for (const it of items) {
      const dep = clamp(1 - (it.z - zc + R) / (2 * R)) * .6 + .4;
      if (it.k === 0) { ctx.strokeStyle = rgba(mix(ROSE, '#1a0812', 1 - dep), a * (.35 + .55 * dep)); ctx.lineWidth = 5 * it.p0.s * (o.sc ?? 1); ctx.lineCap = 'round'; ctx.beginPath(); ctx.moveTo(it.p0.x, it.p0.y); ctx.lineTo(it.p1.x, it.p1.y); ctx.stroke(); }
      else if (it.k === 1) sphere(ctx, it.p.x, it.p.y, 12 * it.p.s * (o.sc ?? 1), ROSE, '#ffffff', a * (.55 + .45 * dep));
      else { const mx = (it.p.x + it.q.x) / 2, my = (it.p.y + it.q.y) / 2; const c1 = it.i % 3 === 0 ? '#e9dcc2' : '#c9b8ff', c2 = it.i % 3 === 0 ? '#c9b8ff' : '#e9dcc2'; line(ctx, [[it.p.x, it.p.y], [mx - (mx - it.p.x) * .06, my - (my - it.p.y) * .06]], rgba(c1, .5 * dep), 3.2 * it.p.s, a); line(ctx, [[it.q.x, it.q.y], [mx + (it.q.x - mx) * .06, my + (it.q.y - my) * .06]], rgba(c2, .5 * dep), 3.2 * it.p.s, a); }
    }
  }

  // 圆底烧瓶（玻璃线稿）
  function flask(ctx, x, y, R, a, o = {}) {
    if (a <= 0) return; const nw = R * .3, nTop = y - R * 2.05, nBot = y - R * .93;
    const th = Math.asin(nw / R);
    ctx.save();
    // 液体
    const lv = y - R * .18;
    ctx.save(); ctx.beginPath(); ctx.arc(x, y, R - 3, 0, TAU); ctx.clip();
    const lg = ctx.createLinearGradient(0, lv, 0, y + R); lg.addColorStop(0, rgba('#3a2a5e', .55 * a)); lg.addColorStop(1, rgba('#150c26', .75 * a)); ctx.fillStyle = lg; ctx.fillRect(x - R, lv, 2 * R, R * 1.3);
    ctx.globalCompositeOperation = 'lighter'; ctx.strokeStyle = rgba(LILAC, .45 * a); ctx.lineWidth = 1.2; ctx.beginPath(); ctx.ellipse(x, lv, Math.sqrt(R * R - (lv - y) * (lv - y)), 10, 0, 0, TAU); ctx.stroke();
    if (o.inner) o.inner(lv);
    ctx.restore();
    // 玻璃
    const path = () => { ctx.beginPath(); ctx.moveTo(x - nw, nTop); ctx.lineTo(x - nw, y - R * Math.cos(th)); ctx.arc(x, y, R, -Math.PI / 2 - th, -Math.PI / 2 + th, true); ctx.lineTo(x + nw, nTop); };
    ctx.globalCompositeOperation = 'lighter';
    ctx.strokeStyle = rgba(LILAC, .12 * a); ctx.lineWidth = 9; path(); ctx.stroke();
    ctx.strokeStyle = rgba('#e8e0ff', .75 * a); ctx.lineWidth = 1.8; path(); ctx.stroke();
    ctx.strokeStyle = rgba('#e8e0ff', .5 * a); ctx.lineWidth = 2; ctx.beginPath(); ctx.ellipse(x, nTop, nw + 8, 7, 0, 0, TAU); ctx.stroke();
    // 高光
    ctx.strokeStyle = rgba('#ffffff', .4 * a); ctx.lineWidth = 3; ctx.beginPath(); ctx.arc(x, y, R * .84, Math.PI * 1.08, Math.PI * 1.36); ctx.stroke();
    ctx.strokeStyle = rgba('#ffffff', .25 * a); ctx.lineWidth = 2; ctx.beginPath(); ctx.moveTo(x - nw * .55, nTop + 20); ctx.lineTo(x - nw * .55, nBot - 10); ctx.stroke();
    ctx.restore();
  }
  // 左右比例条
  function ratioBar(ctx, x, y, w, f, a, o = {}) {
    if (a <= 0) return; const xm = x - w / 2 + w * f;
    ctx.save(); ctx.globalAlpha = a;
    ctx.fillStyle = rgba(TEAL, .85); ctx.fillRect(x - w / 2, y - 3, w * f, 6);
    ctx.fillStyle = rgba(ROSE, .85); ctx.fillRect(xm, y - 3, w * (1 - f), 6);
    ctx.strokeStyle = 'rgba(255,255,255,.5)'; ctx.lineWidth = 1; ctx.beginPath(); ctx.moveTo(x, y - 14); ctx.lineTo(x, y + 14); ctx.stroke();
    ctx.restore();
    ctx.save(); ctx.globalCompositeOperation = 'lighter'; glow(ctx, xm, y, 26, '#ffffff', .6 * a); ctx.restore();
    if (o.labels !== false) {
      text(ctx, o.lt ?? `左 ${Math.round(f * 100)}%`, x - w / 2 - 22, y, { size: 26, font: 'song', weight: 400, align: 'right', color: TEAL, alpha: a });
      text(ctx, o.rt ?? `右 ${Math.round((1 - f) * 100)}%`, x + w / 2 + 22, y, { size: 26, font: 'song', weight: 400, align: 'left', color: ROSE, alpha: a });
    }
  }

  // 4. 生命的偏手
  const FLASKP = (() => { const r = rng(55); const a = []; for (let i = 0; i < 120; i++) a.push({ a: r() * TAU, r: Math.sqrt(r()), ph: r() * TAU, sp: .3 + r() * .5, d: r() }); return a; })();
  scenes.life = (ctx, S) => {
    const t = S.t, c0 = S.cue(0), c1 = S.cue(1), c2 = S.cue(2), e0 = S.cend(0);
    inkBg(ctx, t, { neb: .38, seed: 3 });
    const partB = smooth(c1 - .4, c1 + .6, t), partC = smooth(c2 - .3, c2 + .7, t);
    // 螺旋：A 段在两侧；B 段淡出；C 段左侧螺旋回归
    const hxA = (1 - partB) + partC;
    const hx = lerp(560, 480, partC), hsc = lerp(1, .82, partC);
    mirror(ctx, MX, t, .55 * (1 - partB) * smooth(0, 1, t) + .5 * partC, { y0: 120, y1: lerp(820, 640, partC), glints: 3 });
    alphaHelix(ctx, hx, 470, { alpha: hxA * smooth(c0, c0 + .6, t), grow: prog(t, c0 + .2, c0 + 2.6, E.inOut) * (1 - partB) + partC, yaw: t * .55, sc: hsc, glowA: 1 });
    dnaHelix(ctx, 1360, 470, { alpha: (1 - partB) * smooth(c0 + 3.2, c0 + 3.8, t), grow: prog(t, c0 + 3.3, c0 + 5.4, E.inOut), yaw: t * .5 });
    const la = (1 - partB);
    if (la > 0) {
      term(ctx, 'L-氨基酸 · 左手型', 'proteins · L-amino acids', 560, 846, { alpha: la * smooth(c0 + 1.6, c0 + 2.6, t), color: TEAL, size: 36 });
      term(ctx, 'D-糖 · 右手型', 'DNA · RNA · D-sugars', 1360, 846, { alpha: la * smooth(c0 + 4.6, c0 + 5.6, t), color: ROSE, size: 36 });
      label(ctx, '蛋白质 α-螺旋', 490, 250, { alpha: la * smooth(c0 + 2, c0 + 3, t), dx: -110, dy: -60, size: 26, en: 'alpha helix' });
      label(ctx, '核酸双螺旋', 1440, 250, { alpha: la * smooth(c0 + 5, c0 + 6, t), dx: 110, dy: -60, size: 26, en: 'double helix' });
    }
    // 烧瓶：B 段居中，C 段移到右侧
    const fA = partB; if (fA > 0) {
      const fx = lerp(MX, 1440, partC), fy = lerp(560, 520, partC), fR = lerp(190, 150, partC);
      const conv = prog(t, c1 + .4, c1 + 4.6, x => x); // 已加入的原料比例
      // 落入瓶口的无手性原料（灰）
      ctx.save(); ctx.globalCompositeOperation = 'lighter';
      for (let i = 0; i < 26; i++) { const u = ((t - c1) * .55 + hash(i, 21)) % 1; if (t < c1 || partC > .5) break; const yy = lerp(fy - fR * 2.9, fy - fR * .2, E.in(u)); const xx = fx + (hash(i, 22) - .5) * fR * .4 * (1 - u); glow(ctx, xx, yy, 9, '#bdb6cc', .5 * fA * (1 - smooth(.85, 1, u))); dot(ctx, xx, yy, 2, '#e8e4f0', .8 * fA * (1 - smooth(.85, 1, u))); }
      ctx.restore();
      flask(ctx, fx, fy, fR, fA, { inner: lv => {
        for (let i = 0; i < FLASKP.length; i++) { const q = FLASKP[i]; if (q.d > clamp(conv * 1.15 + partC)) continue; const an = q.a + t * q.sp * .6, rr = q.r * fR * .86; let px = fx + Math.cos(an) * rr, py = fy + Math.sin(an) * rr * .9 + Math.sin(t + q.ph) * 4; if (py < lv + 8) py = lv + 8 + (lv + 8 - py) * .4; const col = i % 2 ? ROSE : TEAL; glow(ctx, px, py, 12 * fR / 190, col, .5 * fA); dot(ctx, px, py, 2.6 * fR / 190, '#ffffff', .85 * fA); }
      } });
      label(ctx, '无手性原料', fx - fR * .32, fy - fR * 2.1, { alpha: fA * smooth(c1 + .3, c1 + 1.2, t) * (1 - partC), dx: -140, dy: -30, size: 26, en: 'achiral starting materials' });
      const jit = .5 + .012 * Math.sin(t * 5.3) + .008 * Math.sin(t * 8.1);
      ratioBar(ctx, fx, lerp(fy + fR + 70, 840, partC), lerp(460, 360, partC), jit, fA * smooth(c1 + 1.6, c1 + 2.6, t), { lt: '左 50%', rt: '右 50%' });
      term(ctx, '外消旋', 'racemic · 50 : 50', 1500, 420, { alpha: fA * smooth(c1 + 2.8, c1 + 3.8, t) * (1 - partC), color: LILAC, size: 40, align: 'left' });
    }
    // C：生命 100% 对 实验室 50:50
    if (partC > 0) {
      ratioBar(ctx, hx, 840, 360, 1, partC, { lt: '', rt: '' });
      text(ctx, '生命 · 100% 同手', hx, 778, { size: 30, font: 'song', weight: 500, spacing: .2, color: '#bff7e8', alpha: partC });
      text(ctx, '实验室 · 左右各半', 1440, 778, { size: 30, font: 'song', weight: 500, spacing: .2, color: '#e6dcff', alpha: partC });
      const qa = smooth(c2 + .4, c2 + 1.4, t);
      text(ctx, '？', MX, 470, { size: 230, font: 'song', weight: 300, color: '#fff3d6', alpha: qa, glow: 40, glowColor: GOLD });
    }
  };

  // ---------- ee：小瓶、图表 ----------
  // 葵花籽排布的 40 个点
  const VIAL = (() => { const a = []; for (let i = 0; i < 40; i++) { const r = Math.sqrt((i + .5) / 40) * 92, an = i * 2.39996; a.push([Math.cos(an) * r, Math.sin(an) * r]); } return a; })();
  function vial(ctx, x, y, nT, a, cancel, t) {
    if (a <= 0) return;
    ctx.save(); ctx.globalAlpha = a; ctx.strokeStyle = rgba(LILAC, .45); ctx.lineWidth = 1.2; ctx.beginPath(); ctx.arc(x, y, 118, 0, TAU); ctx.stroke();
    ctx.strokeStyle = rgba(LILAC, .14); ctx.lineWidth = 6; ctx.beginPath(); ctx.arc(x, y, 118, 0, TAU); ctx.stroke(); ctx.restore();
    // 先给少数派配对：前 nR 个青与全部玫互相抵消
    const nR = 40 - nT; const order = VIAL.map((p, i) => i).sort((i, j) => hash(i, 3) - hash(j, 3));
    order.forEach((idx, k) => {
      const p = VIAL[idx]; const isT = k < nT; const pairIdx = isT ? k : k - nT; const cancelled = pairIdx < nR;
      const pop = smooth(k * .012, k * .012 + .3, a);
      const dim = cancelled ? cancel : 0; const col = isT ? TEAL : ROSE;
      const px = x + p[0], py = y + p[1];
      ctx.save(); ctx.globalCompositeOperation = 'lighter';
      if (!cancelled && cancel > 0) glow(ctx, px, py, 22, GOLD, .5 * cancel * a);
      glow(ctx, px, py, 12, col, .35 * a * pop * (1 - dim * .8)); ctx.restore();
      sphere(ctx, px, py, 7.5 * pop, dim > .5 ? '#5a5470' : col, null, a * (1 - dim * .55));
    });
  }
  const CH = { x0: 640, y0: 800, w: 560, h: 540 };
  const chx = (g, v) => g.x0 + v * g.w, chy = (g, v) => g.y0 - v * g.h;
  function chart(ctx, g, a, o = {}) {
    if (a <= 0) return; const k = g.w / CH.w;
    ctx.save(); ctx.globalAlpha = a;
    // 网格
    ctx.strokeStyle = 'rgba(203,188,255,.10)'; ctx.lineWidth = 1;
    for (const v of [.25, .5, .75, 1]) { ctx.beginPath(); ctx.moveTo(chx(g, v), g.y0); ctx.lineTo(chx(g, v), g.y0 - g.h); ctx.stroke(); ctx.beginPath(); ctx.moveTo(g.x0, chy(g, v)); ctx.lineTo(g.x0 + g.w, chy(g, v)); ctx.stroke(); }
    ctx.strokeStyle = 'rgba(235,228,255,.75)'; ctx.lineWidth = 1.4; const gr = E.out(clamp(o.grow ?? 1));
    ctx.beginPath(); ctx.moveTo(g.x0, g.y0 - g.h * gr); ctx.lineTo(g.x0, g.y0); ctx.lineTo(g.x0 + g.w * gr, g.y0); ctx.stroke();
    for (const v of [0, .5, 1]) { ctx.beginPath(); ctx.moveTo(chx(g, v), g.y0); ctx.lineTo(chx(g, v), g.y0 + 8); ctx.stroke(); ctx.beginPath(); ctx.moveTo(g.x0, chy(g, v)); ctx.lineTo(g.x0 - 8, chy(g, v)); ctx.stroke(); }
    ctx.restore();
    const fs = Math.max(15, 22 * k);
    if (o.xticks !== false) [0, .5, 1].forEach(v => text(ctx, `${v * 100}%`, chx(g, v), g.y0 + 30 * k + 4, { size: fs, font: 'song', weight: 300, color: '#d8cff0', alpha: a }));
    [.5, 1].forEach(v => text(ctx, `${v * 100}%`, g.x0 - 16 * k, chy(g, v), { size: fs, font: 'song', weight: 300, color: '#d8cff0', alpha: a, align: 'right' }));
    const xt = text(ctx, '催化剂纯度', g.x0 + g.w + 26 * k, g.y0 - 2, { size: Math.max(16, 26 * k), font: 'song', weight: 500, align: 'left', color: IVORY, alpha: a * .95, spacing: .1 });
    text(ctx, 'ee', g.x0 + g.w + 26 * k + xt + 10 * k, g.y0 - 4, { size: Math.max(15, 25 * k), font: 'latinI', align: 'left', color: GOLD, alpha: a * .9 });
    const yt = text(ctx, '产物纯度', g.x0 - 40 * k, g.y0 - g.h - 40 * k, { size: Math.max(16, 26 * k), font: 'song', weight: 500, align: 'left', color: IVORY, alpha: a * .95, spacing: .1 });
    text(ctx, 'ee', g.x0 - 40 * k + yt + 10 * k, g.y0 - g.h - 42 * k, { size: Math.max(15, 25 * k), font: 'latinI', align: 'left', color: GOLD, alpha: a * .9 });
  }
  // 正非线性效应（Kagan 的 ML₂ 模型，异手二聚体完全惰性；示意参数）
  function nleY(x, K = 60) { if (x >= 1) return 1; if (x <= 0) return 0; const ab = (1 + x) / 2 * (1 - x) / 2; const A = 4 - K; const r = (-K + Math.sqrt(K * K + 4 * A * K * ab)) / (2 * A); return clamp(x / (1 - 2 * r)); }
  const NLE_PTS = (() => { const a = []; for (let i = 0; i <= 160; i++) { const x = Math.pow(i / 160, 1.6); a.push([x, nleY(x)]); } return a; })();
  const toCh = (g, pts) => pts.map(([x, y]) => [chx(g, x), chy(g, y)]);

  // 5. 纯度的直线：对映体过量
  scenes.catalyst = (ctx, S) => {
    ctx.setTransform(1, 0, 0, 1, 0, 0); // 图表场景不做推镜，保证与下一场的图表无缝衔接
    const t = S.t, c0 = S.cue(0), c1 = S.cue(1), e0 = S.cend(0);
    inkBg(ctx, t, { neb: .34, seed: 4 });
    const pB = smooth(c1 - .3, c1 + .7, t);
    // A：定义
    const aA = 1 - pB;
    if (aA > 0) {
      term(ctx, '对映体过量', 'enantiomeric excess · ee', MX, 200, { alpha: aA * smooth(c0 + .2, c0 + 1.2, t), color: GOLD, size: 46 });
      // 公式：ee = (多数 − 少数) / (多数 + 少数)
      const fa = aA * smooth(c0 + 1.3, c0 + 2.3, t), fx = MX + 70, fy = 345;
      text(ctx, 'ee', fx - 270, fy - 4, { size: 58, font: 'latinI', color: GOLD, alpha: fa, align: 'center' });
      text(ctx, '=', fx - 196, fy - 2, { size: 44, font: 'song', weight: 300, color: IVORY, alpha: fa });
      ctx.save(); ctx.globalAlpha = fa; ctx.strokeStyle = rgba(GOLD, .9); ctx.lineWidth = 1.5; const bw = 150 * E.out(fa); ctx.beginPath(); ctx.moveTo(fx - bw, fy); ctx.lineTo(fx + bw, fy); ctx.stroke(); ctx.restore();
      const part = (y, sign) => { text(ctx, '多数', fx - 86, y, { size: 38, font: 'song', weight: 500, color: TEAL, alpha: fa, spacing: .1 }); text(ctx, sign, fx, y, { size: 38, font: 'song', weight: 300, color: IVORY, alpha: fa }); text(ctx, '少数', fx + 86, y, { size: 38, font: 'song', weight: 500, color: ROSE, alpha: fa, spacing: .1 }); };
      part(fy - 42, '−'); part(fy + 44, '+');
      // 三只小瓶：50:50、75:25、100:0
      const V = [[560, 20, '50 : 50', 0, c0 + 3.6], [MX, 30, '75 : 25', 50, c0 + 5.0], [1360, 40, '100 : 0', 100, c0 + 6.2]];
      V.forEach(([x, nT, rs, ee, ts], i) => {
        const a = aA * smooth(ts, ts + .7, t); if (a <= 0) return;
        const cancel = smooth(ts + .8, ts + 1.5, t);
        vial(ctx, x, 600, nT, a, cancel, t);
        const [l, r] = rs.split(' : ');
        text(ctx, l, x - 18, 448, { size: 30, font: 'song', weight: 300, color: TEAL, alpha: a, align: 'right' });
        text(ctx, ':', x, 446, { size: 28, font: 'song', weight: 300, color: IVORY, alpha: a * .8 });
        text(ctx, r, x + 18, 448, { size: 30, font: 'song', weight: 300, color: ROSE, alpha: a, align: 'left' });
        const v = ee * E.out(cancel);
        counter(ctx, v, x, 790, { alpha: a * smooth(ts + .8, ts + 1.2, t), size: 70, format: q => Math.round(q) + '%', color: '#fff4d8', glowColor: GOLD });
      });
      text(ctx, '相反的两手两两抵消，剩下的“过量”就是 ee', MX, 880, { size: 24, font: 'song', weight: 400, color: '#cfc4ea', alpha: aA * smooth(c0 + 5.6, c0 + 6.4, t), spacing: .1 });
    }
    // B：原以为成正比
    if (pB > 0) {
      chart(ctx, CH, pB, { grow: prog(t, c1 - .2, c1 + .8, x => x), xticks: false });
      // 三个 ee 数值飞到横轴刻度
      [[560, 0], [MX, .5], [1360, 1]].forEach(([x, v], i) => { const u = E.inOut(prog(t, c1 - .3 + i * .1, c1 + .7 + i * .1, x => x)); const X = lerp(x, chx(CH, v), u), Y = lerp(790, CH.y0 + 34, u); text(ctx, `${v * 100}%`, X, Y, { size: lerp(70, 22, u), font: 'song', weight: 300, color: rgba(mix('#fff4d8', '#d8cff0', u)), alpha: 1 }); });
      const lu = prog(t, c1 + .9, c1 + 2.8, E.inOut);
      const pts = toCh(CH, [[0, 0], [1, 1]]);
      if (lu > 0) { line(ctx, partial(pts, lu), rgba(LILAC, .9), 2.4); const hp = partial(pts, lu).slice(-1)[0]; ctx.save(); ctx.globalCompositeOperation = 'lighter'; glow(ctx, hp[0], hp[1], 30, LILAC, .8 * (1 - smooth(c1 + 2.8, c1 + 3.4, t))); ctx.restore(); }
      // 探针：x → y 相等
      const pu = prog(t, c1 + 2.8, S.d, E.inOut) * .7 + .15; const pa = smooth(c1 + 2.8, c1 + 3.3, t);
      if (pa > 0) {
        const X = chx(CH, pu), Y = chy(CH, pu);
        ctx.save(); ctx.globalAlpha = pa; ctx.setLineDash([4, 6]); ctx.strokeStyle = rgba(IVORY, .5); ctx.lineWidth = 1; ctx.beginPath(); ctx.moveTo(X, CH.y0); ctx.lineTo(X, Y); ctx.lineTo(CH.x0, Y); ctx.stroke(); ctx.restore();
        ctx.save(); ctx.globalCompositeOperation = 'lighter'; glow(ctx, X, Y, 26, LILAC, pa); ctx.restore(); dot(ctx, X, Y, 4, '#ffffff', pa);
      }
      term(ctx, '原以为：成正比', 'expected · proportional', 1510, 470, { alpha: smooth(c1 + 1.4, c1 + 2.4, t), color: LILAC, size: 40 });
      text(ctx, '催化剂纯一倍，产物也纯一倍', 1510, 580, { size: 26, font: 'song', weight: 400, color: '#cfc4ea', alpha: smooth(c1 + 2.2, c1 + 3.0, t), spacing: .1 });
    }
  };

  // 6. 非线性效应：曲线鼓起 → 结对 → 少数派被锁住
  const CATS = (() => { const r = rng(1986); const a = []; for (let i = 0; i < 24; i++) a.push({ x: 180 + r() * 1060, y: 230 + r() * 540, ph: r() * TAU, hand: i < 18 ? 0 : 1 }); return a; })();
  // 配对：0–11 青青六对；12–17 青 与 18–23 玫 六对
  const PAIRS = (() => { const a = []; for (let k = 0; k < 6; k++) a.push({ i: 2 * k, j: 2 * k + 1, homo: true, slot: k }); for (let k = 0; k < 6; k++) a.push({ i: 12 + k, j: 18 + k, homo: false, slot: k }); return a; })();
  function padlock(ctx, x, y, s, col, a) {
    if (a <= 0) return; ctx.save(); ctx.globalAlpha = a; ctx.strokeStyle = col; ctx.lineWidth = 1.6; ctx.fillStyle = 'rgba(14,8,24,.85)';
    ctx.beginPath(); ctx.arc(x, y - s * .35, s * .42, Math.PI, 0); ctx.stroke();
    ctx.beginPath(); ctx.roundRect ? ctx.roundRect(x - s * .62, y - s * .35, s * 1.24, s * .95, s * .16) : ctx.rect(x - s * .62, y - s * .35, s * 1.24, s * .95); ctx.fill(); ctx.stroke();
    ctx.fillStyle = col; ctx.beginPath(); ctx.arc(x, y + s * .05, s * .12, 0, TAU); ctx.fill(); ctx.fillRect(x - s * .04, y + s * .05, s * .08, s * .25);
    ctx.restore();
  }
  scenes.nle = (ctx, S) => {
    ctx.setTransform(1, 0, 0, 1, 0, 0);
    const t = S.t, c0 = S.cue(0), c1 = S.cue(1), c2 = S.cue(2), e0 = S.cend(0);
    inkBg(ctx, t, { neb: .34, seed: 5 });
    const pB = smooth(c1 - .2, c1 + .9, t);
    // 图表：A 段全尺寸，B/C 段缩到右侧
    const INS = { x0: 1430, y0: 560, w: 300, h: 290 };
    const g = { x0: lerp(CH.x0, INS.x0, E.inOut(pB)), y0: lerp(CH.y0, INS.y0, E.inOut(pB)), w: lerp(CH.w, INS.w, E.inOut(pB)), h: lerp(CH.h, INS.h, E.inOut(pB)) };
    chart(ctx, g, 1 - .25 * pB);
    // 原来的直线（虚线）
    { const p = toCh(g, [[0, 0], [1, 1]]); ctx.save(); ctx.setLineDash([7, 8]); ctx.strokeStyle = rgba(LILAC, .55); ctx.lineWidth = 1.6; ctx.beginPath(); ctx.moveTo(p[0][0], p[0][1]); ctx.lineTo(p[1][0], p[1][1]); ctx.stroke(); ctx.restore(); }
    const cu = prog(t, c0 + 2.8, c0 + 5.6, E.inOut);
    const cp = toCh(g, NLE_PTS);
    if (cu > 0) {
      // 线与曲线之间的金色区域
      const n = Math.max(2, Math.floor(cp.length * cu));
      ctx.save(); const fg = ctx.createLinearGradient(0, g.y0, 0, g.y0 - g.h); fg.addColorStop(0, rgba(GOLD, .05)); fg.addColorStop(1, rgba(GOLD, .22)); ctx.fillStyle = fg; ctx.beginPath(); ctx.moveTo(cp[0][0], cp[0][1]); for (let i = 1; i < n; i++) ctx.lineTo(cp[i][0], cp[i][1]); const last = NLE_PTS[n - 1]; ctx.lineTo(chx(g, last[0]), chy(g, last[0])); ctx.closePath(); ctx.fill(); ctx.restore();
      ctx.save(); ctx.globalCompositeOperation = 'lighter'; line(ctx, cp.slice(0, n), rgba(GOLD, .25), 9); ctx.restore();
      line(ctx, cp.slice(0, n), rgba('#ffe2a0', 1), 2.6);
      if (cu < 1) { ctx.save(); ctx.globalCompositeOperation = 'lighter'; glow(ctx, cp[n - 1][0], cp[n - 1][1], 34, GOLD, .9); ctx.restore(); }
    }
    // A 段：探针显示“部分纯 → 意外地纯”
    const aA = 1 - pB;
    if (aA > 0) {
      text(ctx, '1986', 1520, 300, { size: 120, font: 'song', weight: 200, color: '#fff4dc', alpha: aA * smooth(c0, c0 + 1, t), glow: 24, glowColor: GOLD, spacing: .05 });
      const pa = smooth(c0 + 5.2, c0 + 6.0, t) * aA, xv = .3, yv = nleY(xv);
      if (pa > 0) {
        const X = chx(g, xv), Yl = chy(g, xv), Yc = chy(g, yv);
        ctx.save(); ctx.globalAlpha = pa; ctx.setLineDash([4, 6]); ctx.strokeStyle = rgba(IVORY, .55); ctx.lineWidth = 1; ctx.beginPath(); ctx.moveTo(X, g.y0); ctx.lineTo(X, Yc); ctx.lineTo(g.x0, Yc); ctx.stroke(); ctx.restore();
        // 放大量：从直线到曲线的金色箭头
        const au = prog(t, c0 + 5.8, c0 + 7.0, E.out); const Ya = lerp(Yl, Yc + 14, au);
        ctx.save(); ctx.globalAlpha = pa; ctx.strokeStyle = GOLD; ctx.lineWidth = 2.2; ctx.beginPath(); ctx.moveTo(X + 16, Yl); ctx.lineTo(X + 16, Ya); ctx.stroke(); ctx.beginPath(); ctx.moveTo(X + 9, Ya + 9); ctx.lineTo(X + 16, Ya); ctx.lineTo(X + 23, Ya + 9); ctx.stroke(); ctx.restore();
        dot(ctx, X, Yl, 4, LILAC, pa); ctx.save(); ctx.globalCompositeOperation = 'lighter'; glow(ctx, X, Yc, 30, GOLD, pa); ctx.restore(); dot(ctx, X, Yc, 5, '#ffffff', pa);
        text(ctx, '部分纯', X, g.y0 + 62, { size: 24, font: 'song', weight: 500, color: '#e6dcff', alpha: pa, spacing: .2 });
        text(ctx, '意外地纯', g.x0 - 30, Yc - 34, { size: 24, font: 'song', weight: 500, color: '#ffe6b0', alpha: pa * smooth(c0 + 6.4, c0 + 7.0, t), align: 'right', spacing: .2 });
      }
      term(ctx, '非线性效应', 'non-linear effect', 1520, 480, { alpha: aA * smooth(c0 + 7.6, c0 + 8.6, t), color: GOLD, size: 50, glow: 16 });
      text(ctx, '正非线性效应 · 不对称放大（曲线为示意）', 1520, 590, { size: 22, font: 'song', weight: 400, color: '#d9cfee', alpha: aA * smooth(c0 + 8.4, c0 + 9.2, t), spacing: .08 });
      text(ctx, '例：配体纯度 15% ee → 产物 95% ee（Noyori, 1989）', 1520, 640, { size: 22, font: 'song', weight: 400, color: '#bfb4dc', alpha: aA * smooth(c0 + 9.0, c0 + 9.8, t), spacing: .04 });
    }
    // B/C 段：结对
    if (pB > 0) {
      const lock = smooth(c2 + .1, c2 + 1.0, t);
      const pos = (i) => {
        const q = CATS[i]; const pr = PAIRS.find(p => p.i === i || p.j === i); const first = pr.i === i;
        const ts = pr.homo ? c1 + 1.6 + pr.slot * .12 : c1 + 4.4 + pr.slot * .12; const u = prog(t, ts, ts + 1.2, E.inOut);
        const sx = 230 + pr.slot * 190, sy = pr.homo ? 330 : 640 + 30 * lock;
        const wob = (1 - u) * 1;
        const fx = q.x + 18 * Math.sin(t * .9 + q.ph) * wob, fy = q.y + 14 * Math.cos(t * .7 + q.ph * 1.3) * wob;
        const spin = pr.homo ? .35 * Math.sin(t * 1.6 + pr.slot * 1.3) : .12;
        const tx = sx + (first ? -1 : 1) * 30 * Math.cos(spin), ty = sy + (first ? -1 : 1) * 30 * Math.sin(spin);
        return { x: lerp(fx, tx, u), y: lerp(fy, ty, u), u, pr };
      };
      const P = CATS.map((q, i) => pos(i));
      // 连接
      for (const pr of PAIRS) {
        const a = P[pr.i], b = P[pr.j]; const u = Math.min(a.u, b.u); if (u < .8) continue; const k = smooth(.8, 1, u) * pB;
        if (pr.homo) { ctx.save(); ctx.globalCompositeOperation = 'lighter'; line(ctx, [[a.x, a.y], [b.x, b.y]], rgba(TEAL, .8 * k), 3); glow(ctx, (a.x + b.x) / 2, (a.y + b.y) / 2, 70, TEAL, .25 * k); ctx.restore(); }
        else { const mx = (a.x + b.x) / 2, my = (a.y + b.y) / 2; ctx.save(); ctx.globalAlpha = k; ctx.strokeStyle = 'rgba(190,180,215,.75)'; ctx.lineWidth = 2; ctx.beginPath(); ctx.ellipse(mx - 7, my, 11, 7, 0, 0, TAU); ctx.stroke(); ctx.beginPath(); ctx.ellipse(mx + 7, my, 11, 7, 0, 0, TAU); ctx.stroke(); ctx.restore(); }
      }
      // 产物火花：同手对不断“干活”
      ctx.save(); ctx.globalCompositeOperation = 'lighter';
      for (const pr of PAIRS) {
        if (!pr.homo) continue; const a = P[pr.i], b = P[pr.j]; if (Math.min(a.u, b.u) < 1) continue; const mx = (a.x + b.x) / 2, my = (a.y + b.y) / 2;
        const t0 = c1 + 3.0 + pr.slot * .12; const rate = 1 + 1.2 * lock;
        for (let k = 0; k < 14; k++) { const life = 1.6; const ph = ((t - t0) * rate / life + hash(k + pr.slot * 31, 41)) % 1; if (t < t0) break; const an = -Math.PI / 2 + (hash(k + pr.slot * 31, 42) - .5) * 2.2; const d = 20 + ph * 110; glow(ctx, mx + Math.cos(an) * d, my + Math.sin(an) * d * .8, 10, TEAL, .6 * (1 - ph) * pB); dot(ctx, mx + Math.cos(an) * d, my + Math.sin(an) * d * .8, 2, '#e8fff8', .9 * (1 - ph) * pB); }
      }
      ctx.restore();
      // 催化剂分子
      CATS.forEach((q, i) => {
        const p = P[i]; const isHet = !p.pr.homo; const dim = isHet ? smooth(.85, 1, p.u) * (.55 + .3 * lock) : 0;
        const col = q.hand ? ROSE : TEAL; const a = pB * smooth(c1 - .3 + hash(i, 9) * .5, c1 + .4 + hash(i, 9) * .5, t);
        if (!isHet || dim < .5) { ctx.save(); ctx.globalCompositeOperation = 'lighter'; glow(ctx, p.x, p.y, 44, col, .3 * a * (1 - dim)); ctx.restore(); }
        sphere(ctx, p.x, p.y, 22, col, '#ffffff', a * (1 - dim));
        if (dim > 0) sphere(ctx, p.x, p.y, 22, q.hand ? '#7a3f60' : '#2f6a62', null, a * dim * .9);
      });
      // 锁
      if (lock > 0) for (const pr of PAIRS) { if (pr.homo) continue; const a = P[pr.i], b = P[pr.j]; padlock(ctx, (a.x + b.x) / 2, (a.y + b.y) / 2 - 44, 22, 'rgba(255,214,140,.9)', lock * smooth(pr.slot * .1, pr.slot * .1 + .3, lock)); }
      // 行标签
      text(ctx, '同手对 · 结伴干活', 705, 226, { size: 30, font: 'song', weight: 600, spacing: .2, color: '#bff7e8', alpha: pB * smooth(c1 + 2.6, c1 + 3.4, t) });
      text(ctx, '异手对 · 彼此牵制', 705, 540 + 30 * lock, { size: 30, font: 'song', weight: 600, spacing: .2, color: '#d6cde8', alpha: pB * smooth(c1 + 5.4, c1 + 6.2, t) });
      // C 段：统计与放大
      const sA = smooth(c2 + 1.8, c2 + 2.6, t);
      if (sA > 0) {
        const y = 850;
        text(ctx, '投入  18 : 6  （ee 50%）', 420, y, { size: 26, font: 'song', weight: 400, color: '#e6dcff', alpha: sA, spacing: .06 });
        text(ctx, '→', 650, y, { size: 26, font: 'song', weight: 300, color: GOLD, alpha: sA * smooth(c2 + 2.4, c2 + 2.9, t) });
        text(ctx, '锁住 6 对', 790, y, { size: 26, font: 'song', weight: 400, color: '#d6cde8', alpha: sA * smooth(c2 + 2.4, c2 + 2.9, t), spacing: .06 });
        text(ctx, '→', 930, y, { size: 26, font: 'song', weight: 300, color: GOLD, alpha: sA * smooth(c2 + 3.2, c2 + 3.7, t) });
        text(ctx, '在场干活  12 : 0', 1110, y, { size: 28, font: 'song', weight: 600, color: '#fff0c8', alpha: sA * smooth(c2 + 3.2, c2 + 3.7, t), spacing: .06, glow: 12, glowColor: GOLD });
      }
      // 插图里的点：50% 催化剂 → 曲线上的产物纯度
      const ia = smooth(c2 + 4.2, c2 + 5.0, t);
      if (ia > 0) {
        const X = chx(g, .5), Yl = chy(g, .5), Yc = chy(g, nleY(.5)); const au = prog(t, c2 + 4.6, c2 + 5.6, E.out); const Ya = lerp(Yl, Yc, au);
        dot(ctx, X, Yl, 4, LILAC, ia); ctx.save(); ctx.globalAlpha = ia; ctx.strokeStyle = GOLD; ctx.lineWidth = 2; ctx.beginPath(); ctx.moveTo(X, Yl); ctx.lineTo(X, Ya); ctx.stroke(); ctx.restore();
        ctx.save(); ctx.globalCompositeOperation = 'lighter'; glow(ctx, X, Ya, 34, GOLD, ia); ctx.restore(); dot(ctx, X, Ya, 4.5, '#ffffff', ia);
        term(ctx, '纯度被放大', 'asymmetric amplification', 1580, 680, { alpha: smooth(c2 + 5.0, c2 + 5.8, t), color: GOLD, size: 36 });
      }
    }
  };


  // ---------- 7. 自我复制 ----------
  // 平面、无手性的底物（灰色六边形片）
  function flatMol(ctx, x, y, r, a, rot = 0) {
    if (a <= 0) return; ctx.save(); ctx.translate(x, y); ctx.rotate(rot); ctx.scale(1, .55); ctx.globalAlpha = a;
    ctx.fillStyle = 'rgba(150,142,170,.25)'; ctx.strokeStyle = 'rgba(210,204,226,.8)'; ctx.lineWidth = 1.4;
    ctx.beginPath(); for (let k = 0; k < 6; k++) { const an = k / 6 * TAU; k ? ctx.lineTo(Math.cos(an) * r, Math.sin(an) * r) : ctx.moveTo(Math.cos(an) * r, Math.sin(an) * r); } ctx.closePath(); ctx.fill(); ctx.stroke();
    ctx.beginPath(); ctx.moveTo(r, 0); ctx.lineTo(r * 1.7, 0); ctx.stroke(); ctx.restore();
  }
  // A 段的复制树：每一代翻倍
  const TREE = (() => { const n = []; const X = [330, 620, 880, 1110, 1320]; for (let g = 0; g < 5; g++) { const m = 1 << g; for (let k = 0; k < m; k++) n.push({ g, k, x: X[g], y: 505 + (k - (m - 1) / 2) * Math.min(210, 500 / m), par: g ? n.findIndex(q => q.g === g - 1 && q.k === (k >> 1)) : -1 }); } return n; })();
  // B 段的雪崩：自中心向外的分枝；异手相遇被锁住
  const CASCADE = (() => {
    const r = rng(1995); const gens = []; const seeds = [0, 1, 0, 0, 1, 0, 0, 1]; // 5 青 : 3 玫
    gens.push(seeds.map((h, i) => ({ g: 0, hand: h, par: -1, lock: false })));
    const lockP = [0, .35, .55, .7, .85, 1, 1, 1];
    for (let g = 1; g <= 7; g++) {
      const prev = gens[g - 1]; const cur = [];
      prev.forEach((p, pi) => { if (p.lock) return; for (let c = 0; c < 2; c++) cur.push({ g, hand: p.hand, par: pi, lock: false }); });
      cur.forEach((q, i) => { if (q.hand !== 1 || q.lock || r() > lockP[g]) return; let best = -1, bd = 1e9; cur.forEach((z, j) => { if (z.hand === 0 && !z.lock) { const d = Math.min(Math.abs(j - i), cur.length - Math.abs(j - i)); if (d < bd) { bd = d; best = j; } } }); if (best >= 0) { q.lock = true; cur[best].lock = true; q.mate = best; } });
      gens.push(cur);
    }
    // 每一代均匀铺满一圈（按父代顺序，保持枝条不交叉）
    const nodes = []; const base = [];
    gens.forEach((gen, g) => { base.push(nodes.length); gen.forEach((q, i) => { q.a = (i + .5) / gen.length * TAU + g * .11 + (r() - .5) * .6 / gen.length * TAU; q.jr = (r() - .5) * 18; nodes.push(q); }); });
    nodes.forEach(q => { if (q.par >= 0) q.par += base[q.g - 1]; if (q.mate !== undefined) q.mate += base[q.g]; });
    return nodes;
  })();
  const cascR = g => 46 + g * 56 + g * g * 2;
  scenes.soai = (ctx, S) => {
    const t = S.t, c0 = S.cue(0), c1 = S.cue(1), c2 = S.cue(2), e2 = S.cend(2);
    inkBg(ctx, t, { neb: .3, seed: 6 });
    // —— A：产物即催化剂 ——
    const aA = 1 - smooth(c1 - .5, c1 + .2, t);
    if (aA > 0) {
      text(ctx, '1995', 1560, 250, { size: 110, font: 'song', weight: 200, color: '#e9fff8', alpha: aA * smooth(c0, c0 + 1, t), glow: 22, glowColor: TEAL, spacing: .05 });
      text(ctx, '嘧啶-5-甲醛 + 二异丙基锌 → 嘧啶基烷醇（产物即催化剂）', 820, 176, { size: 24, font: 'song', weight: 400, color: '#d6cde8', alpha: aA * smooth(c0 + .8, c0 + 1.8, t), spacing: .08 });
      const T0 = c0 + 1.6, dt = 1.05;
      const camF = (x, y, sc) => cam({ pitch: .3, dist: 1300, fov: 1300 * sc, cx: x, cy: y });
      // 分枝
      ctx.save(); ctx.globalCompositeOperation = 'lighter';
      TREE.forEach(nd => { if (nd.par < 0) return; const p = TREE[nd.par]; const u = prog(t, T0 + nd.g * dt - .3, T0 + nd.g * dt + .4, E.out); if (u <= 0) return; const pts = []; for (let k = 0; k <= 20; k++) { const v = k / 20 * u; pts.push([lerp(p.x, nd.x, v), lerp(p.y, nd.y, E.inOutSine(v))]); } line(ctx, pts, rgba(TEAL, .45 * aA), 1.6); });
      ctx.restore();
      // 底物飞入并转化
      TREE.forEach((nd, i) => {
        const ts = T0 + nd.g * dt; const u = prog(t, ts - .9, ts, E.inOut);
        if (nd.g > 0 && u > 0 && u < 1) { const p = TREE[nd.par]; const sx = p.x + 60 + hash(i, 4) * 60, sy = p.y - 160 - hash(i, 5) * 60; flatMol(ctx, lerp(sx, (p.x + nd.x) / 2, u), lerp(sy, (p.y + nd.y) / 2, u), 22 * Math.max(.45, 1 - nd.g * .15), aA * (1 - smooth(.8, 1, u)), t + i); }
        const a = aA * smooth(ts, ts + .35, t); if (a <= 0) return;
        if (t < ts + .5) { ctx.save(); ctx.globalCompositeOperation = 'lighter'; glow(ctx, nd.x, nd.y, 70 / (1 + nd.g), '#ffffff', (1 - smooth(ts, ts + .5, t)) * .6 * aA / (1 + nd.g * .6)); ctx.restore(); }
        const sc = [1, .78, .6, .44, .3, .2][nd.g];
        if (nd.g <= 3) { ctx.save(); ctx.globalCompositeOperation = 'lighter'; glow(ctx, nd.x, nd.y, 150 * sc, TEAL, .22 * a); ctx.restore(); drawMol(ctx, TET, p => rotY(p, t * .6 + nd.k), camF(nd.x, nd.y, sc * .85), { alpha: a, rim: TEAL }); }
        else { ctx.save(); ctx.globalCompositeOperation = 'lighter'; glow(ctx, nd.x, nd.y, 22 * sc / .3, TEAL, .6 * a); ctx.restore(); sphere(ctx, nd.x, nd.y, 9 * sc / .3, TEAL, '#ffffff', a); }
      });
      // 回路：产物 = 催化剂
      const la = aA * smooth(c0 + 4.6, c0 + 5.6, t);
      if (la > 0) {
        const p0 = TREE[1], p1 = TREE[0]; const pts = KIT.arcPts(p0.x - 10, p0.y - 90, p1.x + 20, p1.y - 110, -.5, 50);
        ctx.save(); ctx.setLineDash([6, 7]); ctx.lineDashOffset = -t * 30; line(ctx, partial(pts, smooth(c0 + 4.6, c0 + 5.6, t)), rgba(GOLD, .9 * la), 1.8); ctx.restore();
        const e = pts[pts.length - 1], q = pts[pts.length - 4]; const an = Math.atan2(e[1] - q[1], e[0] - q[0]);
        ctx.save(); ctx.globalAlpha = la * smooth(c0 + 5.4, c0 + 5.7, t); ctx.strokeStyle = GOLD; ctx.lineWidth = 1.8; ctx.beginPath(); ctx.moveTo(e[0] - Math.cos(an - .5) * 12, e[1] - Math.sin(an - .5) * 12); ctx.lineTo(e[0], e[1]); ctx.lineTo(e[0] - Math.cos(an + .5) * 12, e[1] - Math.sin(an + .5) * 12); ctx.stroke(); ctx.restore();
        text(ctx, '产物 = 催化剂', 470, 270, { size: 30, font: 'song', weight: 600, color: '#fff0c8', alpha: la, spacing: .2 });
      }
      { const u = prog(t, c0 + 1.6 + 1.05 - .9, c0 + 1.6 + 1.05, E.inOut); const p = TREE[0], nd = TREE[1]; const lx = lerp(p.x + 60 + hash(1, 4) * 60, (p.x + nd.x) / 2, u), ly = lerp(p.y - 160 - hash(1, 5) * 60, (p.y + nd.y) / 2, u); label(ctx, '无手性底物', lx, ly, { alpha: aA * env(t, c0 + 1.0, c0 + 3.6, .5, .5), dx: -80, dy: -70, size: 24, en: 'achiral substrate' }); }
      term(ctx, '不对称自催化', 'asymmetric autocatalysis', MX, 846, { alpha: aA * smooth(c0 + 5.8, c0 + 6.8, t), color: TEAL, size: 44, glow: 14 });
    }
    // —— B：雪崩 ——
    const aB = smooth(c1 - .4, c1 + .4, t) * (1 - smooth(c2 - .2, c2 + .9, t));
    if (aB > 0) {
      const C = [MX, 450], T0 = c1 - .2, dg = .8;
      const born = g => T0 + g * dg;
      const pos = (q) => { const R = cascR(q.g) + q.jr; return [C[0] + Math.cos(q.a) * R * 1.3, C[1] + Math.sin(q.a) * R * .8]; };
      let nT = 0, nR = 0;
      ctx.save(); ctx.globalCompositeOperation = 'lighter';
      for (let i = 0; i < CASCADE.length; i++) {
        const q = CASCADE[i]; const tb = born(q.g) + hash(i, 61) * .25; const u = prog(t, tb, tb + .5, E.out); if (u <= 0) continue;
        const p = pos(q); const pp = q.par >= 0 ? pos(CASCADE[q.par]) : C;
        const x = lerp(pp[0], p[0], u), y = lerp(pp[1], p[1], u);
        const lockK = q.lock ? smooth(tb + .5, tb + 1.0, t) : 0;
        const col = q.hand ? ROSE : TEAL; const old = 1 - .55 * smooth(born(q.g + 3), born(q.g + 4), t);
        if (q.par >= 0) line(ctx, [[pp[0], pp[1]], [x, y]], rgba(col, (.28 - .2 * lockK) * aB), 1.1);
        if (lockK < 1) glow(ctx, x, y, Math.max(10, 30 - q.g * 3.2), col, .5 * aB * (1 - lockK) * old);
        if (q.g <= 3) { ctx.globalCompositeOperation = 'source-over'; sphere(ctx, x, y, 11 - q.g * 1.9, col, '#ffffff', aB * (1 - lockK) * old); if (lockK > 0) sphere(ctx, x, y, 11 - q.g * 1.9, q.hand ? '#7a3f60' : '#2f6a62', null, aB * lockK); ctx.globalCompositeOperation = 'lighter'; }
        else dot(ctx, x, y, Math.max(1.6, 4.6 - q.g * .45), lockK > .5 ? '#6d6585' : '#f2fffb', aB * (1 - lockK * .5));
        if (q.mate !== undefined && lockK > 0) { const m = CASCADE[q.mate]; const pm = pos(m); line(ctx, [[x, y], [pm[0], pm[1]]], rgba('#b8afd0', .5 * lockK * aB), 1.2); }
        if (u >= 1 && !q.lock) { if (q.hand) nR++; else nT++; } else if (u >= 1 && q.lock && lockK < .5) { if (q.hand) nR++; else nT++; }
      }
      ctx.restore();
      // 雪球：整体的青色辉光随数量增长
      const grow = clamp(nT / 600); ctx.save(); ctx.globalCompositeOperation = 'lighter'; glow(ctx, C[0], C[1], 300 + grow * 500, TEAL, .22 * grow * aB); ctx.restore();
      // 计数：只数当代仍在复制的分子
      const ca = aB * smooth(c1 + .6, c1 + 1.4, t);
      if (ca > 0) {
        const lastG = clamp(Math.floor((t - T0) / dg), 0, 7); let aT = 0, aR = 0; for (const q of CASCADE) if (q.g === lastG && !q.lock) { if (q.hand) aR++; else aT++; }
        const f = aT + aR ? aT / (aT + aR) : .5;
        const vg = ctx.createLinearGradient(0, 760, 0, 930); vg.addColorStop(0, 'rgba(6,3,12,0)'); vg.addColorStop(.5, `rgba(6,3,12,${.8 * ca})`); vg.addColorStop(1, `rgba(6,3,12,${.85 * ca})`); ctx.fillStyle = vg; ctx.fillRect(0, 760, W, 170);
        ratioBar(ctx, MX, 860, 520, f, ca, { lt: '左手型', rt: '右手型' });
        text(ctx, `第 ${lastG} 代`, MX, 820, { size: 24, font: 'song', weight: 300, color: '#d6cde8', alpha: ca, spacing: .2 });
      }
      { const lk = CASCADE.find(q => q.g === 2 && q.lock && q.hand === 1) || CASCADE[1]; const lp = pos(lk); label(ctx, '异手相遇 · 锁死', lp[0], lp[1], { alpha: aB * env(t, c1 + 2.4, c1 + 6.0, .5, .6), dx: lp[0] > MX ? 170 : -170, dy: -120, size: 26, color: '#e6dcff' }); }
    }
    // —— C：一千万分之五 ——
    const aC = smooth(c2 - .2, c2 + .9, t);
    if (aC > 0) {
      const zu = prog(t, c2 + .6, c2 + 4.4, E.inOut); const Z = Math.exp(lerp(Math.log(.0005), Math.log(.019), zu));
      // 三轮：青色比例 0.5 → 0.785 → 0.995 → 0.9975，自中心向外扫过
      const r1 = c2 + 6.5, r2 = r1 + 1.0, r3 = r2 + 1.0;
      const rp = [prog(t, r1, r1 + .9, x => x), prog(t, r2, r2 + .9, x => x), prog(t, r3, r3 + .9, x => x)];
      const stage = rp[2] > 0 ? 2 : rp[1] > 0 ? 1 : 0; const Fs = [.5, .785, .995, .9975];
      GLFX.layer(ctx, 'field', { T: t, Z, A: 1.35 * aC, SD: 7, C: [0, 0], C1: '#4fe3c1', C2: '#ff5fa2', F0: Fs[stage], F1: Fs[stage + 1], WR: rp[stage] * 1.4 });
      // 暗场托住文字
      const vg = ctx.createLinearGradient(0, 600, 0, H); vg.addColorStop(0, 'rgba(6,3,12,0)'); vg.addColorStop(.32, 'rgba(6,3,12,.78)'); vg.addColorStop(1, 'rgba(6,3,12,.92)'); ctx.fillStyle = vg; ctx.fillRect(0, 600, W, H - 600);
      const tg = ctx.createLinearGradient(0, 0, 0, 330); tg.addColorStop(0, 'rgba(6,3,12,.85)'); tg.addColorStop(1, 'rgba(6,3,12,0)'); ctx.fillStyle = tg; ctx.fillRect(0, 0, W, 330);
      text(ctx, '2003', 1560, 160, { size: 90, font: 'song', weight: 200, color: '#fff4dc', alpha: aC * smooth(c2, c2 + 1, t), glow: 18, glowColor: GOLD, spacing: .05 });
      // 一千万
      const na = aC * smooth(c2 + .6, c2 + 1.6, t) * (1 - smooth(c2 + 4.0, c2 + 4.6, t));
      counter(ctx, 10000000, MX, 170, { alpha: na, size: 84, format: v => '10,000,000', color: '#ffffff', glowColor: LILAC });
      text(ctx, '个分子', MX, 238, { size: 28, font: 'song', weight: 500, color: '#e6dcff', alpha: na, spacing: .3 });
      // 多出的 5 个
      const fa = aC * smooth(c2 + 4.6, c2 + 5.4, t) * (1 - smooth(r1 + .4, r1 + 1.2, t));
      if (fa > 0) {
        ctx.save(); ctx.translate(MX, 200); ctx.scale(1, .32); const bk = ctx.createRadialGradient(0, 0, 0, 0, 0, 420); bk.addColorStop(0, `rgba(6,3,12,${.85 * fa})`); bk.addColorStop(1, 'rgba(6,3,12,0)'); ctx.fillStyle = bk; ctx.beginPath(); ctx.arc(0, 0, 420, 0, TAU); ctx.fill(); ctx.restore();
        const cells = [[3, 2], [-9, 4], [12, -2], [-4, -3], [7, 7]];
        ctx.save(); ctx.globalCompositeOperation = 'lighter';
        cells.forEach(([i, j], k) => { const x = W / 2 + (i + .5) * Z * H, y = H / 2 - (j + .5) * Z * H; const pk = smooth(c2 + 4.6 + k * .15, c2 + 5.0 + k * .15, t); glow(ctx, x, y, 70, GOLD, .8 * fa * pk); glow(ctx, x, y, 24, '#ffffff', .9 * fa * pk); ctx.strokeStyle = rgba(GOLD, .8 * fa * pk); ctx.lineWidth = 1.4; ctx.beginPath(); ctx.arc(x, y, 30 + 6 * Math.sin(t * 4 + k), 0, TAU); ctx.stroke(); });
        ctx.restore();
        text(ctx, '左右只差 5 个', MX, 170, { size: 60, font: 'song', weight: 600, color: '#fff0c8', alpha: fa, glow: 20, glowColor: GOLD, spacing: .2 });
        text(ctx, 'ee ≈ 0.00005%', MX, 245, { size: 30, font: 'song', weight: 300, color: '#e6dcff', alpha: fa, spacing: .1 });
      }
      // 三轮的进度轨道
      const ta = aC * smooth(r1 - .6, r1, t);
      if (ta > 0) {
        const st = [['起始', '0.00005%'], ['第 1 轮', '≈ 57%'], ['第 2 轮', '≈ 99%'], ['第 3 轮', '> 99.5%']]; const xs = [480, 800, 1120, 1440], y = 800;
        ctx.save(); ctx.globalAlpha = ta; ctx.strokeStyle = 'rgba(203,188,255,.35)'; ctx.lineWidth = 1.2; ctx.beginPath(); ctx.moveTo(xs[0], y); ctx.lineTo(xs[3], y); ctx.stroke(); ctx.restore();
        const prog3 = rp[0] + rp[1] + rp[2];
        ctx.save(); ctx.globalAlpha = ta; const gx = lerp(xs[0], xs[3], prog3 / 3); const lg = ctx.createLinearGradient(xs[0], 0, gx, 0); lg.addColorStop(0, rgba(TEAL, .6)); lg.addColorStop(1, rgba(GOLD, 1)); ctx.strokeStyle = lg; ctx.lineWidth = 3; ctx.beginPath(); ctx.moveTo(xs[0], y); ctx.lineTo(gx, y); ctx.stroke(); ctx.restore();
        st.forEach(([nm, v], k) => {
          const on = k === 0 ? 1 : smooth(.85, 1, rp[k - 1]); const cur = k === stage + (rp[stage] >= 1 ? 1 : 0) || (k === 3 && rp[2] >= 1);
          ctx.save(); ctx.globalCompositeOperation = 'lighter'; glow(ctx, xs[k], y, 30 + 20 * on, on > .5 ? GOLD : LILAC, ta * (.3 + .6 * on)); ctx.restore(); dot(ctx, xs[k], y, 5, on > .5 ? '#fff4d8' : '#8d84a6', ta);
          text(ctx, nm, xs[k], y + 40, { size: 24, font: 'song', weight: 500, color: '#d6cde8', alpha: ta * (.5 + .5 * on), spacing: .15 });
          text(ctx, v, xs[k], y - 46, { size: k === 3 ? 44 : 34, font: 'song', weight: 300, color: k === 3 ? '#fff0c8' : '#f4efe6', alpha: ta * on, glow: k === 3 ? 18 : 0, glowColor: GOLD });
        });
      }
    }
  };

  // ---------- 8. 第一推力 ----------
  // 石英：六方柱 + 两端锥顶；hand=±1 决定小斜面（梯形面）在哪一侧
  const QUARTZ = (() => {
    const V = [], F = []; const r = 46, h = 120, cap = 62;
    for (let k = 0; k < 6; k++) { const a = k / 6 * TAU; V.push([Math.cos(a) * r, -h / 2, Math.sin(a) * r]); }
    for (let k = 0; k < 6; k++) { const a = k / 6 * TAU; V.push([Math.cos(a) * r, h / 2, Math.sin(a) * r]); }
    V.push([0, -h / 2 - cap, 0], [0, h / 2 + cap, 0]);
    for (let k = 0; k < 6; k++) { const k2 = (k + 1) % 6; F.push([k, k2, 6 + k2, 6 + k]); F.push([12, k2, k]); F.push([13, 6 + k, 6 + k2]); }
    return { V, F };
  })();
  function quartz(ctx, x, y, yaw, hand, col, a, sc = 1) {
    if (a <= 0) return; const c = cam({ pitch: .32, dist: 1100, fov: 1100 * sc, cx: x, cy: y });
    const xf = p => { let q = hand < 0 ? mirX(p) : p; q = rotY(q, yaw); return rotZ(q, .18 * hand); };
    const Pw = QUARTZ.V.map(xf), P = Pw.map(w => c.p(w[0], w[1], w[2]));
    const L = vnorm([-.5, -.7, -.6]);
    const faces = QUARTZ.F.map((f, i) => { const a0 = Pw[f[0]], a1 = Pw[f[1]], a2 = Pw[f[2]]; const n = vnorm(vcross([a1[0] - a0[0], a1[1] - a0[1], a1[2] - a0[2]], [a2[0] - a0[0], a2[1] - a0[1], a2[2] - a0[2]])); const z = f.reduce((s, k) => s + P[k].z, 0) / f.length; return { f, n, z, i }; }).sort((p, q) => q.z - p.z);
    ctx.save();
    for (const fc of faces) {
      const facing = fc.n[2] < 0; const lit = clamp(-(fc.n[0] * L[0] + fc.n[1] * L[1] + fc.n[2] * L[2]) * .5 + .5);
      ctx.beginPath(); fc.f.forEach((k, j) => j ? ctx.lineTo(P[k].x, P[k].y) : ctx.moveTo(P[k].x, P[k].y)); ctx.closePath();
      ctx.fillStyle = rgba(mix(mix(col, '#0a0614', .65), '#ffffff', lit * .35), (facing ? .55 : .25) * a); ctx.fill();
      ctx.strokeStyle = rgba(mix(col, '#ffffff', .5), (facing ? .8 : .25) * a); ctx.lineWidth = 1.2; ctx.stroke();
    }
    // 标志性的小斜面：在上锥与柱面交界处的一角
    const k0 = 0, A0 = P[k0], A1 = P[1], A2 = P[12];
    const fx = [lerp(A0.x, A1.x, .5), lerp(A0.x, A2.x, .38), A0.x], fy = [lerp(A0.y, A1.y, .5), lerp(A0.y, A2.y, .38), A0.y];
    ctx.globalCompositeOperation = 'lighter'; ctx.fillStyle = rgba(GOLD, .55 * a); ctx.beginPath(); ctx.moveTo(fx[0], fy[0]); ctx.lineTo(fx[1], fy[1]); ctx.lineTo(lerp(A0.x, P[6].x, .2), lerp(A0.y, P[6].y, .2)); ctx.closePath(); ctx.fill();
    ctx.restore();
    ctx.save(); ctx.globalCompositeOperation = 'lighter'; glow(ctx, x, y, 160 * sc, col, .12 * a); ctx.restore();
  }
  // 原子核：质子与中子的紧密堆积
  const NUC = n => { const pts = []; for (let i = 0; i < n; i++) { const y = 1 - (i + .5) / n * 2, r = Math.sqrt(1 - y * y), th = i * 2.39996; pts.push([Math.cos(th) * r, y, Math.sin(th) * r]); } return pts; };
  const NUC12 = NUC(12), NUC13 = NUC(13);
  function nucleus(ctx, x, y, pts, a, t, extra) {
    if (a <= 0) return; const c = cam({ pitch: .2, dist: 900, fov: 900, cx: x, cy: y }); const R = 30 + pts.length * 1.2;
    const items = pts.map((p, i) => { const w = rotX(rotY(vmul(p, R * (.75 + .25 * hash(i, 71))), t * .5), .3); const q = c.p(w[0], w[1], w[2]); return { q, i }; }).sort((u, v) => v.q.z - u.q.z);
    for (const it of items) { const isP = it.i % 2 === 0 && it.i < 12; const isX = extra && it.i === pts.length - 1; sphere(ctx, it.q.x, it.q.y, 17 * it.q.s, isP ? '#ff8f6b' : (isX ? GOLD : '#9f96c8'), isX ? GOLD : null, a); if (isX) { ctx.save(); ctx.globalCompositeOperation = 'lighter'; glow(ctx, it.q.x, it.q.y, 60, GOLD, .6 * a * (.7 + .3 * Math.sin(t * 4))); ctx.restore(); } }
  }
  // 小天平：偏向一侧
  function tilt(ctx, x, y, dir, a) {
    if (a <= 0) return; const ang = dir * .28 * E.outBack(clamp(a)); const L = 90;
    ctx.save(); ctx.globalAlpha = clamp(a); ctx.strokeStyle = 'rgba(230,222,250,.75)'; ctx.lineWidth = 1.4;
    ctx.beginPath(); ctx.moveTo(x - 9, y + 14); ctx.lineTo(x, y); ctx.lineTo(x + 9, y + 14); ctx.closePath(); ctx.stroke();
    const dx = Math.cos(ang) * L, dy = Math.sin(ang) * L; ctx.beginPath(); ctx.moveTo(x - dx, y - dy); ctx.lineTo(x + dx, y + dy); ctx.stroke(); ctx.restore();
    const down = dir < 0 ? [x - dx, y - dy] : [x + dx, y + dy]; const up = dir < 0 ? [x + dx, y + dy] : [x - dx, y - dy];
    sphere(ctx, down[0], down[1] - 14, 15, dir < 0 ? TEAL : ROSE, '#ffffff', a); sphere(ctx, up[0], up[1] - 9, 8, dir < 0 ? ROSE : TEAL, null, a * .8);
  }
  // 铅笔（立于笔尖）
  function pencil(ctx, x, y, ang, len, a, col = IVORY) {
    if (a <= 0) return; ctx.save(); ctx.translate(x, y); ctx.rotate(ang); ctx.globalAlpha = a;
    const w = 13, tip = 54;
    ctx.fillStyle = 'rgba(30,20,48,.9)'; ctx.beginPath(); ctx.moveTo(0, 0); ctx.lineTo(-w, -tip); ctx.lineTo(-w, -len); ctx.lineTo(w, -len); ctx.lineTo(w, -tip); ctx.closePath(); ctx.fill();
    ctx.globalCompositeOperation = 'lighter'; ctx.strokeStyle = rgba(col, .85); ctx.lineWidth = 1.6; ctx.stroke();
    ctx.strokeStyle = rgba(col, .35); ctx.lineWidth = 1; ctx.beginPath(); ctx.moveTo(-w, -tip); ctx.lineTo(w, -tip); ctx.moveTo(0, -tip); ctx.lineTo(0, -len + 34); ctx.moveTo(-w, -len + 34); ctx.lineTo(w, -len + 34); ctx.stroke();
    ctx.fillStyle = rgba(col, .9); ctx.beginPath(); ctx.moveTo(0, 0); ctx.lineTo(-w * .3, -tip * .3); ctx.lineTo(w * .3, -tip * .3); ctx.closePath(); ctx.fill();
    ctx.restore();
  }
  const RUNS = (() => { const r = rng(1953); const a = []; for (let i = 0; i < 64; i++) { const side = r() < .5 ? -1 : 1; const m = .78 + Math.pow(r(), .6) * .22; a.push({ v: side * m, t: r() }); } a.sort((p, q) => p.t - q.t); return a; })();
  scenes.trigger = (ctx, S) => {
    const t = S.t, c0 = S.cue(0), c1 = S.cue(1), e1 = S.cend(1);
    inkBg(ctx, t, { neb: .34, seed: 7 });
    const aA = 1 - smooth(c1 - .4, c1 + .3, t);
    if (aA > 0) {
      term(ctx, '第一推力', 'the first push', MX, 190, { alpha: aA * smooth(c0 + .4, c0 + 1.4, t), color: GOLD, size: 48, glow: 14 });
      const P = [[400, c0 + 3.4], [MX, c0 + 5.1], [1520, c0 + 6.9]];
      // 1 圆偏振光
      { const [x, ts] = P[0]; const a = aA * smooth(ts, ts + .8, t); if (a > 0) {
        const c = cam({ yaw: -.32, pitch: .12, dist: 1200, fov: 1200, cx: x, cy: 450 }); const R = 48, L = 400, k = TAU / 120, ph = t * 5;
        const pts = [], vec = []; const head = lerp(-L / 2, L / 2, prog(t, ts, ts + 1.2, E.out));
        for (let s = -L / 2; s <= head; s += 4) { const an = s * k - ph; const w = [s, Math.cos(an) * R, Math.sin(an) * R]; const q = c.p(w[0], w[1], w[2]); pts.push([q.x, q.y]); }
        ctx.save(); ctx.globalCompositeOperation = 'lighter';
        const a0 = c.p(-L / 2 - 20, 0, 0), a1 = c.p(L / 2 + 30, 0, 0); line(ctx, [[a0.x, a0.y], [a1.x, a1.y]], rgba(TEAL, .10 * a), 30); line(ctx, [[a0.x, a0.y], [a1.x, a1.y]], rgba(LILAC, .45 * a), 1);
        for (let s = -L / 2; s <= head; s += 15) { const an = s * k - ph; const q0 = c.p(s, 0, 0), q1 = c.p(s, Math.cos(an) * R, Math.sin(an) * R); line(ctx, [[q0.x, q0.y], [q1.x, q1.y]], rgba('#bff7e8', .35 * a), 1); }
        line(ctx, pts, rgba(TEAL, .25 * a), 8); line(ctx, pts, rgba('#dffcf3', .95 * a), 2);
        if (pts.length) glow(ctx, pts[pts.length - 1][0], pts[pts.length - 1][1], 30, TEAL, a);
        ctx.restore();
        term(ctx, '圆偏振光', 'circularly polarized light', x, 700, { alpha: a, color: TEAL, size: 34 });
        tilt(ctx, x, 800, -1, a * smooth(ts + 1.0, ts + 1.6, t));
      } }
      // 2 手性石英：左旋与右旋两种晶体
      { const [x, ts] = P[1]; const a = aA * smooth(ts, ts + .8, t); if (a > 0) {
        const yaw = .5 + Math.sin(t * .6) * .25;
        quartz(ctx, x - 95, 450, yaw, 1, '#7fe8d0', a, .9); quartz(ctx, x + 95, 450, -yaw, -1, '#ff8cbc', a, .9);
        ctx.save(); ctx.globalAlpha = a * .6; ctx.strokeStyle = rgba(LILAC, .5); ctx.setLineDash([2, 6]); ctx.beginPath(); ctx.moveTo(x, 300); ctx.lineTo(x, 600); ctx.stroke(); ctx.restore();
        term(ctx, '手性石英', 'left- & right-handed quartz', x, 700, { alpha: a, color: LILAC, size: 34 });
        tilt(ctx, x - 95, 800, -1, a * smooth(ts + 1.0, ts + 1.6, t) * .9); tilt(ctx, x + 95, 800, 1, a * smooth(ts + 1.2, ts + 1.8, t) * .9);
      } }
      // 3 碳同位素
      { const [x, ts] = P[2]; const a = aA * smooth(ts, ts + .8, t); if (a > 0) {
        nucleus(ctx, x - 90, 450, NUC12, a, t, false); nucleus(ctx, x + 90, 450, NUC13, a, t + 1, true);
        text(ctx, '¹²C', x - 90, 560, { size: 32, font: 'song', weight: 400, color: IVORY, alpha: a }); text(ctx, '¹³C', x + 90, 560, { size: 32, font: 'song', weight: 400, color: '#ffe6b0', alpha: a });
        text(ctx, '6 质子 + 6 中子', x - 90, 600, { size: 18, font: 'song', weight: 400, color: '#bfb4dc', alpha: a }); text(ctx, '6 质子 + 7 中子', x + 90, 600, { size: 18, font: 'song', weight: 400, color: '#e8d6b0', alpha: a });
        term(ctx, '碳同位素', 'carbon isotopes', x, 700, { alpha: a, color: GOLD, size: 34 });
        tilt(ctx, x, 800, -1, a * smooth(ts + 1.2, ts + 1.8, t));
      } }
      text(ctx, '触发物的手性，决定产物的手性', MX, 872, { size: 24, font: 'song', weight: 400, color: '#cfc4ea', alpha: aA * smooth(c0 + 8.6, c0 + 9.4, t), spacing: .15 });
    }
    // B：自发对称性破缺
    const aB = smooth(c1 - .3, c1 + .6, t);
    if (aB > 0) {
      // 铅笔
      const px = 520, py = 720, fall = prog(t, e1 - 2.6, e1 - 1.0, E.in); const wob = Math.sin(t * 3.1) * .018 * smooth(c1, c1 + 3, t);
      const ang = wob - fall * 1.42;
      ctx.save(); ctx.strokeStyle = rgba(LILAC, .5 * aB); ctx.lineWidth = 1.2; ctx.beginPath(); ctx.moveTo(px - 380, py); ctx.lineTo(px + 380, py); ctx.stroke(); ctx.restore();
      const ga = aB * smooth(c1 + 4.4, c1 + 5.4, t);
      if (ga > 0) { for (const sd of [-1, 1]) { ctx.save(); ctx.setLineDash([4, 8]); ctx.strokeStyle = rgba(sd < 0 ? TEAL : ROSE, .7 * ga); ctx.lineWidth = 1.5; ctx.beginPath(); ctx.arc(px, py, 330, -Math.PI / 2, -Math.PI / 2 + sd * 1.42, sd < 0); ctx.stroke(); ctx.restore(); pencil(ctx, px, py, sd * 1.42, 340, .18 * ga, sd < 0 ? TEAL : ROSE); } text(ctx, '或左', px - 300, py - 300, { size: 28, font: 'song', weight: 500, color: TEAL, alpha: ga, spacing: .2 }); text(ctx, '或右', px + 300, py - 300, { size: 28, font: 'song', weight: 500, color: ROSE, alpha: ga, spacing: .2 }); }
      pencil(ctx, px, py, ang, 340, aB, fall > .9 ? '#bff7e8' : IVORY);
      if (fall >= 1) { const f = 1 - smooth(e1 - 1.0, e1 - .2, t); ctx.save(); ctx.globalCompositeOperation = 'lighter'; glow(ctx, px - 330, py, 120, TEAL, .5 * f); ctx.restore(); }
      // 直方图：反复做同一个实验
      const hx = 1360, hy = 760, hw = 600, bins = 24, bw = hw / bins;
      ctx.save(); ctx.globalAlpha = aB; ctx.strokeStyle = 'rgba(235,228,255,.7)'; ctx.lineWidth = 1.2; ctx.beginPath(); ctx.moveTo(hx - hw / 2 - 20, hy); ctx.lineTo(hx + hw / 2 + 20, hy); ctx.stroke(); ctx.beginPath(); ctx.moveTo(hx, hy); ctx.lineTo(hx, hy + 10); ctx.stroke(); ctx.restore();
      text(ctx, '0', hx, hy + 30, { size: 22, font: 'song', weight: 300, color: '#d8cff0', alpha: aB });
      text(ctx, 'S', hx - hw / 2, hy + 34, { size: 34, font: 'latinI', color: TEAL, alpha: aB }); text(ctx, 'R', hx + hw / 2, hy + 34, { size: 34, font: 'latinI', color: ROSE, alpha: aB });
      text(ctx, '产物 ee', hx, hy + 70, { size: 22, font: 'song', weight: 400, color: '#bfb4dc', alpha: aB, spacing: .2 });
      text(ctx, '把同一个实验重复许多次', hx, 300, { size: 30, font: 'song', weight: 500, color: IVORY, alpha: aB * smooth(c1 + .8, c1 + 1.6, t), spacing: .15 });
      const cnt = {}; const t0 = c1 + 1.4, t1 = e1 - 2.8;
      RUNS.forEach((r, i) => {
        const ti = lerp(t0, t1, i / RUNS.length); const u = prog(t, ti, ti + .5, E.in); if (u <= 0) return;
        const b = clamp(Math.floor((r.v + 1) / 2 * bins), 0, bins - 1); cnt[b] = (cnt[b] || 0) + (u >= 1 ? 1 : 0); const n = (cnt[b] || 0) + (u < 1 ? 1 : 0);
        const x = hx - hw / 2 + (b + .5) * bw, yT = hy - 12 - (n - 1) * 21, y = lerp(330, yT, u);
        const col = r.v < 0 ? TEAL : ROSE; ctx.save(); ctx.globalCompositeOperation = 'lighter'; glow(ctx, x, y, 18, col, .5 * aB); ctx.restore(); sphere(ctx, x, y, 9, col, '#ffffff', aB);
      });
      const na = aB * smooth(t1 - .5, t1 + .5, t);
      text(ctx, '从不停在中间', hx, hy - 90, { size: 24, font: 'song', weight: 400, color: '#e6dcff', alpha: na, spacing: .2 });
      text(ctx, 'Frank 1953：自我复制 + 相互抑制', hx, 872, { size: 22, font: 'song', weight: 400, color: '#bfb4dc', alpha: aB * smooth(c1 + 3, c1 + 4, t), spacing: .06 });
    }
  };

  // ---------- 9. 积微成著 ----------
  const HELIXF = (() => { const r = rng(4004); const a = []; const rows = [[10, .3, 330, .35], [8, .46, 420, .6], [6, .68, 500, 1]]; rows.forEach(([n, s, y, al], ri) => { for (let i = 0; i < n; i++) a.push({ x: (i + .5 + (ri % 2 ? .25 : 0) + (r() - .5) * .3) / n * W, y: y + (r() - .5) * 40, s, al, d: r() }); }); return a; })();
  const PILLS = (() => { const r = rng(2013); const a = []; for (let i = 0; i < 7; i++) a.push({ x: 1280 + r() * 420, y: 280 + r() * 420, an: r() * TAU, sp: (r() - .5) * .4, l: 70 + r() * 40 }); return a; })();
  function capsule(ctx, x, y, len, rad, ang, c1, c2, a) {
    if (a <= 0) return; ctx.save(); ctx.translate(x, y); ctx.rotate(ang); ctx.globalAlpha = a; const h = len / 2;
    const half = (sx, col) => { ctx.beginPath(); ctx.moveTo(0, -rad); ctx.lineTo(sx * (h - rad), -rad); ctx.arc(sx * (h - rad), 0, rad, -Math.PI / 2, Math.PI / 2, sx < 0); ctx.lineTo(0, rad); ctx.closePath(); const g = ctx.createLinearGradient(0, -rad, 0, rad); g.addColorStop(0, rgba(mix(col, '#ffffff', .55))); g.addColorStop(.45, rgba(col)); g.addColorStop(1, rgba(mix(col, '#05030a', .6))); ctx.fillStyle = g; ctx.fill(); };
    half(-1, c1); half(1, c2);
    ctx.strokeStyle = 'rgba(255,255,255,.35)'; ctx.lineWidth = 2; ctx.beginPath(); ctx.moveTo(-h + rad, -rad * .5); ctx.lineTo(h - rad, -rad * .5); ctx.stroke();
    ctx.restore();
  }
  scenes.meaning = (ctx, S) => {
    const t = S.t, c0 = S.cue(0), c1 = S.cue(1), c2 = S.cue(2), e0 = S.cend(0), e2 = S.cend(2);
    inkBg(ctx, t, { neb: .3, seed: 8 });
    // A：原始地球 → 微小偏差扩散 → 同手性的生命
    const zoom = prog(t, c0 + 5.4, c0 + 8.2, E.inOut);
    const pa = 1 - smooth(c0 + 6.0, c0 + 7.8, t);
    if (pa > 0) {
      stars(ctx, t, { alpha: .6 * pa });
      const R = lerp(300, 760, zoom), px = MX, py = lerp(480, 640, zoom);
      ctx.fillStyle = `rgba(0,0,0,${pa})`; ctx.beginPath(); ctx.arc(px, py, R * .995, 0, TAU); ctx.fill();
      const gp = [px - R * .02, py - R * .2];
      GLFX.layer(ctx, 'planet', { T: t, P: GLFX.uv(px, py), SZ: R / H, A: 1.1 * pa, ROT: t * .03, GL: smooth(c0 + .4, c0 + 1.4, t) * (1 - zoom), GP: GLFX.uv(gp[0], gp[1]) });
      if (zoom < 1) { ctx.save(); ctx.globalCompositeOperation = 'lighter'; const gk = smooth(c0 + .4, c0 + 1.4, t) * (1 - zoom) * pa; glow(ctx, gp[0], gp[1], 26, GOLD, .7 * gk); dot(ctx, gp[0], gp[1], 2.4, '#fff8e0', gk); ctx.strokeStyle = rgba(GOLD, .6 * gk); ctx.lineWidth = 1.2; ctx.beginPath(); ctx.arc(gp[0], gp[1], 16 + 4 * Math.sin(t * 3), 0, TAU); ctx.stroke(); ctx.restore(); }
      // 扩散：青色的“复制”在球面上蔓延
      const sp = prog(t, c0 + 2.2, c0 + 6.4, x => x);
      if (sp > 0) {
        ctx.save(); ctx.beginPath(); ctx.arc(px, py, R, 0, TAU); ctx.clip(); ctx.globalCompositeOperation = 'lighter';
        for (let i = 0; i < 700; i++) { const an = hash(i, 81) * TAU, rr = Math.sqrt(hash(i, 82)) * R * 1.9; const d = rr / (R * 1.9); if (d > sp * 1.15) continue; const x = gp[0] + Math.cos(an) * rr, y = gp[1] + Math.sin(an) * rr * .8; const dx = (x - px) / R, dy = (y - py) / R; if (dx * dx + dy * dy > 1) continue; const age = clamp((sp * 1.15 - d) * 4); glow(ctx, x, y, 14 * R / 300, TEAL, .55 * pa * age); dot(ctx, x, y, 1.8, '#e6fff8', .9 * pa * age); }
        for (let k = 0; k < 3; k++) { const rr = ((sp * 1.6 + k / 3) % 1) * R * 1.6; ctx.strokeStyle = rgba(TEAL, .35 * pa * (1 - rr / (R * 1.6))); ctx.lineWidth = 2; ctx.beginPath(); ctx.ellipse(gp[0], gp[1], rr, rr * .8, 0, 0, TAU); ctx.stroke(); }
        ctx.restore();
      }
      label(ctx, '偶然的微小偏差', gp[0], gp[1], { alpha: pa * env(t, c0 + .8, c0 + 5.0, .6, .6), dx: -140, dy: -120, size: 28, color: '#ffe6b0', lineColor: 'rgba(255,220,150,.7)' });
      text(ctx, '自我复制 + 相互抑制', MX, 870, { size: 30, font: 'song', weight: 500, color: '#bff7e8', alpha: pa * env(t, c0 + 2.6, c0 + 6.4, .6, .6), spacing: .25 });
    }
    // 同手性的螺旋之林
    const fa = smooth(c0 + 6.6, c0 + 8.4, t) * (1 - smooth(c2 - .4, c2 + .4, t));
    if (fa > 0) {
      ctx.save(); ctx.globalCompositeOperation = 'lighter'; glow(ctx, MX, 460, 900, TEAL, .12 * fa); ctx.restore();
      HELIXF.forEach((h, i) => { const d0 = c0 + 6.2 + h.d * 1.6; alphaHelix(ctx, h.x, h.y, { alpha: fa * h.al * smooth(d0, d0 + .8, t), sc: h.s, yaw: t * .6, n: 24, grow: prog(t, d0, d0 + 1.8, E.out), glowA: .35 }); });
      term(ctx, '生命的同手性', 'homochirality · a plausible path', MX, 846, { alpha: fa * smooth(c0 + 8.6, c0 + 9.6, t) * (1 - smooth(c1 - .3, c1 + .2, t)), color: TEAL, size: 42, glow: 14 });
      const ba = fa * smooth(c1 + .1, c1 + 1.0, t);
      if (ba > 0) {
        const vg = ctx.createLinearGradient(0, 680, 0, 920); vg.addColorStop(0, 'rgba(6,3,12,0)'); vg.addColorStop(1, `rgba(6,3,12,${.75 * ba})`); ctx.fillStyle = vg; ctx.fillRect(0, 680, W, 240);
        term(ctx, '原理证明 · 并非最终答案', 'proof of principle · not the final answer', MX, 800, { alpha: ba, color: GOLD, size: 42 });
        text(ctx, 'Soai 反应需要有机锌与无水溶剂，并非前生命条件下的化学', MX, 880, { size: 22, font: 'song', weight: 400, color: '#bfb4dc', alpha: ba * smooth(c1 + 1.6, c1 + 2.4, t), spacing: .06 });
      }
    }
    // C：药物
    const dA = smooth(c2 - .3, c2 + .6, t) * (1 - smooth(c2 + 4.4, c2 + 5.2, t));
    if (dA > 0) {
      const dx = 640, dy = 480, R = 175;
      const segs = [[.59, GOLD, '单一对映体', '59%'], [.38, '#8d84a6', '无手性', '38%'], [.036, ROSE, '外消旋', '3.6%']]; const tot = segs.reduce((s, q) => s + q[0], 0);
      let a0 = -Math.PI / 2; const gu = prog(t, c2 + .2, c2 + 1.8, E.inOut);
      segs.forEach(([v, col], k) => { const a1 = a0 + v / tot * TAU; const e = Math.min(a1, -Math.PI / 2 + gu * TAU); if (e > a0) { ctx.save(); ctx.globalAlpha = dA; ctx.strokeStyle = col; ctx.lineWidth = k === 0 ? 30 : 22; ctx.beginPath(); ctx.arc(dx, dy, R, a0 + .012, e - .012); ctx.stroke(); if (k === 0) { ctx.globalCompositeOperation = 'lighter'; ctx.strokeStyle = rgba(GOLD, .25); ctx.lineWidth = 56; ctx.beginPath(); ctx.arc(dx, dy, R, a0 + .012, e - .012); ctx.stroke(); } ctx.restore(); } a0 = a1; });
      counter(ctx, 59 * E.out(gu), dx, dy - 12, { alpha: dA, size: 92, format: v => Math.round(v) + '%', color: '#fff4dc', glowColor: GOLD });
      text(ctx, '单一手性分子', dx, dy + 62, { size: 26, font: 'song', weight: 500, color: '#ffe6b0', alpha: dA, spacing: .2 });
      text(ctx, 'FDA 2013–2022 批准的新分子药物', dx, dy - R - 64, { size: 26, font: 'song', weight: 500, color: IVORY, alpha: dA * smooth(c2 + .4, c2 + 1.2, t), spacing: .1 });
      segs.forEach(([v, col, nm, pc], k) => { const y = 400 + k * 70, a = dA * smooth(c2 + 1.2 + k * .3, c2 + 1.8 + k * .3, t); ctx.save(); ctx.globalAlpha = a; ctx.fillStyle = col; ctx.fillRect(900, y - 3, 34, 6); ctx.restore(); text(ctx, nm, 952, y, { size: 26, font: 'song', weight: 500, color: IVORY, alpha: a, align: 'left', spacing: .1 }); text(ctx, pc, 1120, y, { size: 26, font: 'song', weight: 300, color: col === '#8d84a6' ? '#d0c8e6' : col, alpha: a, align: 'left' }); });
      PILLS.forEach((p, i) => { const a = dA * smooth(c2 + .6 + i * .15, c2 + 1.4 + i * .15, t); const y = p.y + Math.sin(t * .8 + i) * 10; capsule(ctx, p.x, y, p.l, p.l * .2, p.an + t * p.sp, TEAL, '#efe8dc', a); });
    }
    // 收尾：镜面两侧，一侧泛起金光
    const mA = smooth(c2 + 4.6, c2 + 5.6, t);
    if (mA > 0) {
      const gl = smooth(c2 + 5.6, c2 + 7.4, t);
      const lg = ctx.createRadialGradient(MX - 430, 470, 0, MX - 430, 470, 640); lg.addColorStop(0, rgba(GOLD, .2 * gl * mA)); lg.addColorStop(.6, rgba(GOLD, .06 * gl * mA)); lg.addColorStop(1, rgba(GOLD, 0)); ctx.save(); ctx.globalCompositeOperation = 'lighter'; ctx.fillStyle = lg; ctx.beginPath(); ctx.rect(0, 0, MX, H); ctx.clip(); ctx.fillRect(0, 0, MX, H); ctx.restore();
      mirror(ctx, MX, t, mA * .9, { y0: 90, y1: 860, flash: env(t, c2 + 5.6, c2 + 6.6, .2, .8) * .5, fy: 470 });
      const th = .6 + t * .3;
      const cL = cam({ pitch: .3, dist: 1300, fov: 1300, cx: MX - 420, cy: 470 }), cR = cam({ pitch: .3, dist: 1300, fov: 1300, cx: MX + 420, cy: 470 });
      drawMol(ctx, TET, p => rotY(p, th), cL, { alpha: mA, rim: gl > .3 ? GOLD : TEAL, scale: 1.1 });
      drawMol(ctx, TET, p => mirX(rotY(p, th)), cR, { alpha: mA * (1 - .45 * gl), rim: ROSE, scale: 1.1 });
      ctx.save(); ctx.globalCompositeOperation = 'lighter'; glow(ctx, MX - 420, 470, 300, GOLD, .3 * gl * mA); ctx.restore();

    }
  };

  const stub = name => (ctx, S) => { inkBg(ctx, S.t); text(ctx, name, W / 2, H / 2, { size: 60 }); };

  scenes.end = (ctx, S) => {
    inkBg(ctx, S.t, { neb: .3, motes: .5 });
    endCard(ctx, S.t, S.d, {
      prize: '2026 年诺贝尔化学奖', color: GOLD,
      zh: '表彰他们“发现不对称有机合成中的\n非线性效应和自催化”',
      en: '“for the discovery of non-linear effects and autocatalysis in asymmetric organic synthesis”',
      who: '获奖者：亨利·卡甘（Henri B. Kagan）　硖合宪三（Kenso Soai）',
      src: '资料：诺贝尔奖官方新闻稿与科普资料、Kagan 等 JACS 1986、Soai 等 Nature 1995 / Angew. Chem. 2003 · 部分画面为示意 · 配音为合成语音'
    });
  };

  for (const k of ['mirror', 'life', 'catalyst', 'nle', 'soai', 'trigger', 'meaning']) { const f = scenes[k]; scenes[k] = (ctx, S) => { f(ctx, S); mirrorOpen(ctx, S.t); }; }

  FILM({ id: 'chemistry', scenes, accent: GOLD, brand: 'NOBEL PRIZE 2026 · CHEMISTRY', chapters: { mirror: [1, '镜中两物'], life: [2, '生命的偏手'], catalyst: [3, '纯度的直线'], nle: [4, '非线性效应'], soai: [5, '自我复制'], trigger: [6, '第一推力'], meaning: [7, '积微成著'] }, noPush: ['title', 'end'], post: { bloom: .5, vignette: .55, grain: .05 } });
})();
