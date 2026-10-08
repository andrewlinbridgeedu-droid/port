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
 vec3 q=vec3(p*2.6,T*.04);
 float w=fbm4(q+vec3(0.,-T*.05,0.)); float d=fbm(q*1.6+vec3(w*2.4,w*1.3,2.));
 float fil=pow(smoothstep(.5,.9,d),2.2);
 float vein=pow(1.-abs(fbm4(q*3.+vec3(d))*2.-1.),12.);
 vec3 col=mix(C1,C2,smoothstep(.3,.75,w)); col=mix(col,C3,fil);
 float rad=smoothstep(1.15,.18,r)*(.55+.45*smoothstep(.0,.35,r));
 O=vec4((col*(.18+fil*1.3)+C3*vein*.35)*A*rad,1.);}`);

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
  GLFX.define('field', `uniform float Z,A,SD; uniform vec2 C; uniform vec3 C1,C2;
void main(){vec2 px=(gl_FragCoord.xy-.5*R)/R.y; vec2 g=px/Z+C; vec2 id=floor(g); vec2 f=fract(g)-.5;
 float h=h12(id+SD); vec3 col=h<.5?C1:C2; float d=length(f);
 float pw=(1./R.y)/Z; float dm=smoothstep(.30+pw,.30-pw,d);
 float sub=smoothstep(.12,.55,pw);
 float tw=.55+.45*sin(T*2.+h*40.);
 vec3 avg=mix(C1,C2,.5+.25*(h12(floor(px*R.y*.5)+SD)-.5))*.30*(.7+.6*h12(floor(px*R.y)+T));
 vec3 c=mix(col*dm*(.55+.45*tw),avg,sub);
 float vg=smoothstep(.95,.25,length(px*vec2(.85,1.)));
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
  vec3 hh=normalize(Lg+vec3(0.,0.,1.)); c2+=vec3(1.,.95,.85)*pow(max(dot(n,hh),0.),60.)*.7*(1.-cl);
  float lava=isl*smoothstep(.1,-.2,dot(n,Lg))*pow(h12(floor(q.xy*60.)),8.)*2.; c2+=vec3(1.,.4,.1)*lava;
  vec2 gd=(UV()-GP)/SZ; float gr=length(gd); c2+=vec3(1.,.82,.45)*GL*exp(-gr*gr*90.)*1.6+vec3(.3,1.,.8)*GL*exp(-gr*gr*12.)*.25*term;
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
    mirror(ctx, MX, t, smooth(0, 1.2, t) * (1 - .55 * meet), { grow: prog(t, 0, 1.6, E.out), flash: mflash, fy: HY - 40, y0: 60, y1: H - 140 });
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
      mirror(ctx, MX, t, molA * .9 * (1 - .5 * glide), { y0: 60, y1: H - 140, flash: env(t, c1 + 4.8, c1 + 5.3, .1, .4) * .6, fy: MY });
      const lcx = lerp(MX - MD, MX, glide), rcx = lerp(MX + MD, MX, glide);
      const cL = cam({ pitch: .3, dist: 1300, fov: 1300, cx: lcx, cy: MY });
      const cR = cam({ pitch: .3, dist: 1300, fov: 1300, cx: rcx, cy: MY });
      // 试图重合：右分子取左分子同向，再绕竖轴尝试旋转
      const tryRot = prog(t, c1 + 5.45, c1 + 6.0, E.inOut) * 120 * D2R;
      const align = glide;
      const xfR2 = p => { const m = mirX(p); return rotY(m, lerp(-th, th, align) + tryRot * align); };
      ctx.save(); ctx.globalAlpha = 1;
      drawMol(ctx, TET, xfL, cL, { alpha: molA, rim: TEAL, atomGlow: atomGlow(0), bondGlow: bondGlow(0) });
      if (glide < .5) drawMol(ctx, TET, xfR2, cR, { alpha: molA * (1 - smooth(.2, .5, glide)), rim: ROSE, atomGlow: atomGlow(1), bondGlow: bondGlow(1) });
      const P = ghostMol(ctx, TET, xfR2, cR, ROSE, molA * smooth(.15, .5, glide));
      ctx.restore();
      // 错位闪光
      if (glide > .9 && P) {
        const PL = TET.atoms.map(at => { const w = xfL(at.p); return cL.p(w[0], w[1], w[2]); });
        const f1 = env(t, c1 + 5.0, c1 + 5.45, .12, .2), f2 = env(t, c1 + 6.0, c1 + 6.45, .12, .2);
        const f = f1 + f2;
        if (f > 0) for (let i = 1; i < 5; i++) { const d = Math.hypot(PL[i].x - P[i].x, PL[i].y - P[i].y); if (d > 12) { crossMark(ctx, (PL[i].x + P[i].x) / 2, (PL[i].y + P[i].y) / 2 - 0, 20, '#ffffff', f); line(ctx, [[PL[i].x, PL[i].y], [P[i].x, P[i].y]], rgba('#ffffff', .6 * f), 1.2); } else glow(ctx, P[i].x, P[i].y, 40, TEAL, .4 * f); }
      }
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
    GLFX.layer(ctx, 'kaleido', { T: t + 20, A: .85 * smooth(0, 1.4, t), N: 8, SP: .015, C1: '#2a1050', C2: '#0f5a55', C3: '#ff7fb6' });
    // 中心变暗以托住片名
    const g = ctx.createRadialGradient(W / 2, H / 2, 0, W / 2, H / 2, 620); g.addColorStop(0, 'rgba(8,4,14,.78)'); g.addColorStop(.6, 'rgba(8,4,14,.35)'); g.addColorStop(1, 'rgba(8,4,14,0)');
    ctx.fillStyle = g; ctx.fillRect(0, 0, W, H);
    mirror(ctx, MX, t, .5 * smooth(0, 1, t), { y0: 0, y1: H, glints: 3 });
    titleCard(ctx, t, S.d, { kicker: '2026 诺贝尔化学奖', title: '积微成著', sub: '手性的放大与生命的偏手之谜', color: GOLD });
  };


  // 3. 镜中两物：性质相同；遇到手性受体则判若两物；香芹酮的两种气味
  const SEEDS = (() => { const r = rng(808); const a = []; for (let i = 0; i < 9; i++) a.push({ x: (r() - .5) * 170, y: (r() - .5) * 46 + Math.abs(r() - .5) * 20, an: (r() - .5) * 1.6 + (r() < .5 ? Math.PI : 0), l: 54 + r() * 18 }); return a; })();
  scenes.mirror = (ctx, S) => {
    const t = S.t, c0 = S.cue(0), c1 = S.cue(1), e0 = S.cend(0);
    inkBg(ctx, t, { neb: .38, seed: 2 });
    const MD = 420;
    // —— A：镜像分子 + 性质读数 + 手性受体 ——
    const aA = 1 - smooth(c1 - .5, c1 + .3, t);
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
      const bob = bounce > 0 ? -110 * E.out(bounce) + Math.sin(t * 9) * 3 * bounce : 0;
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
        label(ctx, '手性受体', MX - MD - 200, 600, { alpha: recA * aA * (1 - smooth(e0 - 2.4, e0 - 2, t)), dx: -40, dy: 70, size: 26, en: 'chiral receptor' });
        label(ctx, '同一个受体', MX + MD + 200, 600, { alpha: recA * aA * (1 - smooth(e0 - 2.4, e0 - 2, t)), dx: 40, dy: 70, size: 26, en: 'the same, not mirrored' });
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
    const aB = smooth(c1 - .4, c1 + .6, t);
    if (aB > 0) {
      const PY = 330;
      const lA = smooth(c1 + .6, c1 + 1.8, t), rA = smooth(c1 + 3.4, c1 + 4.6, t);
      // 香气：从叶与籽升起，穿过分子
      GLFX.layer(ctx, 'wisp', { T: t, C1: '#4fe3c1', C2: '#ffa24a', P1: GLFX.uv(MX - MD, 690), P2: GLFX.uv(MX + MD, 700), A: 1.25 * aB, A1: lA, A2: rA, HT: .62 });
      mirror(ctx, MX, t, aB * .85, { y0: 90, y1: 880 });
      const th = .4 + (t - c1) * .4;
      const cL = cam({ pitch: .25, dist: 1300, fov: 1300, cx: MX - MD, cy: PY });
      const cR = cam({ pitch: .25, dist: 1300, fov: 1300, cx: MX + MD, cy: PY });
      const tilt = p => rotX(rotZ(p, .25), .2);
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

  const stub = name => (ctx, S) => { inkBg(ctx, S.t); text(ctx, name, W / 2, H / 2, { size: 60 }); };
  for (const k of ['life', 'catalyst', 'nle', 'soai', 'trigger', 'meaning']) scenes[k] = stub(k);

  scenes.end = (ctx, S) => {
    inkBg(ctx, S.t, { neb: .3, motes: .5 });
    mirror(ctx, MX, S.t, .18, { glints: 2 });
    endCard(ctx, S.t, S.d, {
      prize: '2026 年诺贝尔化学奖', color: GOLD,
      zh: '表彰他们“发现不对称有机合成中的\n非线性效应和自催化”',
      en: '“for the discovery of non-linear effects and autocatalysis in asymmetric organic synthesis”',
      who: '获奖者：亨利·卡甘（Henri B. Kagan）　硖合宪三（Kenso Soai）',
      src: '资料：诺贝尔奖官方新闻稿与科普资料、Kagan 等 JACS 1986、Soai 等 Nature 1995 / Angew. Chem. 2003 · 部分画面为示意 · 配音为合成语音'
    });
  };

  FILM({ id: 'chemistry', scenes, accent: GOLD, brand: 'NOBEL PRIZE 2026 · CHEMISTRY', chapters: { mirror: [1, '镜中两物'], life: [2, '生命的偏手'], catalyst: [3, '纯度的直线'], nle: [4, '非线性效应'], soai: [5, '自我复制'], trigger: [6, '第一推力'], meaning: [7, '积微成著'] }, noPush: ['title', 'end'], post: { bloom: .5, vignette: .55, grain: .05 } });
})();
