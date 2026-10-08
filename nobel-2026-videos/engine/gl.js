// WebGL2 着色器图层：星云、极光、黑洞、星系、银河、冰体光、水波焦散、纸张、墨迹。
// 用法：const c = GLFX.draw('nebula', {C1:[...], ...}, scale); ctx.drawImage(c, 0, 0, W, H)
(function (G) {
  'use strict';
  const HEAD = `#version 300 es
precision highp float;
out vec4 O; uniform vec2 R; uniform float T;
float h13(vec3 p){p=fract(p*.1031);p+=dot(p,p.zyx+31.32);return fract((p.x+p.y)*p.z);}
float h12(vec2 p){vec3 q=fract(vec3(p.xyx)*.1031);q+=dot(q,q.yzx+33.33);return fract((q.x+q.y)*q.z);}
float noise(vec3 x){vec3 i=floor(x),f=fract(x);f=f*f*(3.-2.*f);
 return mix(mix(mix(h13(i),h13(i+vec3(1,0,0)),f.x),mix(h13(i+vec3(0,1,0)),h13(i+vec3(1,1,0)),f.x),f.y),
            mix(mix(h13(i+vec3(0,0,1)),h13(i+vec3(1,0,1)),f.x),mix(h13(i+vec3(0,1,1)),h13(i+vec3(1,1,1)),f.x),f.y),f.z);}
float fbm(vec3 p){float a=0.,w=.5;for(int i=0;i<6;i++){a+=w*noise(p);p=p*2.03+vec3(1.7,9.2,3.1);w*=.5;}return a;}
float fbm4(vec3 p){float a=0.,w=.5;for(int i=0;i<4;i++){a+=w*noise(p);p=p*2.03+vec3(1.7,9.2,3.1);w*=.5;}return a;}
vec2 UV(){return (gl_FragCoord.xy-.5*R)/R.y;}
vec2 rot(vec2 p,float a){float c=cos(a),s=sin(a);return vec2(c*p.x-s*p.y,s*p.x+c*p.y);}
`;
  const SH = {};
  // 发光星云（与 'lighter' 叠加）；MODE=1 时输出吸光尘埃（暗色 + alpha）
  SH.nebula = `uniform vec3 C1,C2,C3; uniform float S,D,A,MODE; uniform vec2 OFF,MC,MR;
void main(){vec2 p=UV()*S+OFF; float msk=1.; if(MR.x>0.){vec2 q2=(UV()-MC)/MR; float rr=length(q2)+.18*(fbm4(vec3(UV()*4.,T*.02))-.5); msk=smoothstep(1.,.35,rr);} vec3 q=vec3(p,T*.015);
 float w1=fbm4(q); float w2=fbm4(q+vec3(w1*2.2,w1*1.4,0.)+vec3(5.2,1.3,0.));
 float d=fbm(q+vec3(w2*2.6,w2*1.8,0.)+vec3(1.,7.,0.));
 float m=smoothstep(.42-D*.25,.95,d);
 vec3 col=mix(C1,C2,smoothstep(.25,.85,w2)); col=mix(col,C3,smoothstep(.6,.95,d));
 float fil=pow(smoothstep(.5,.9,fbm(q*3.+vec3(w2))),2.);
 if(MODE>.5){O=vec4(C1,clamp(m*A*(.6+fil)*msk,0.,1.));return;}
 O=vec4(col*(m*(.55+.9*fil))*A*msk,1.);}`;
  // 极光帘幕
  SH.aurora = `uniform float HZ,A; void main(){vec2 f=gl_FragCoord.xy/R; float x=f.x*R.x/R.y; vec3 col=vec3(0.);
 for(int k=0;k<3;k++){float fk=float(k);
  float base=HZ+.12+.12*fk+.07*sin(x*1.1+fk*2.3+T*.08)+.09*(fbm4(vec3(x*.5+fk*3.,T*.03,fk))-.5);
  float dy=f.y-base; float up=exp(-max(dy,0.)*(4.+fk*2.5))*smoothstep(-.035,.0,dy);
  float rays=pow(.5+.5*noise(vec3(x*48.+fk*10.,T*.22,fk)),2.6)*.85+.15;
  float pch=smoothstep(.38,.72,fbm4(vec3(x*.45+fk*7.,T*.025,fk+4.)));
  float fold=.5+.7*fbm4(vec3(x*2.,T*.06+fk,2.));
  vec3 c=mix(vec3(.12,.95,.55),vec3(.5,.32,.95),smoothstep(.0,.25,dy)); if(k==1)c=mix(vec3(.18,.85,.95),vec3(.35,.38,.95),smoothstep(0.,.22,dy));
  col+=c*up*rays*fold*pch*(1.-.3*fk);}
 col*=smoothstep(HZ-.01,HZ+.08,f.y);
 O=vec4(col*A,1.);}`;
  // 黑洞：吸积盘（多普勒增亮）+ 透镜弧 + 光子环 + 喷流。阴影本身由画布另行涂黑。
  SH.blackhole = `uniform vec2 P; uniform float SZ,TILT,A,JET;
void main(){vec2 d=(UV()-P)/SZ; float r=length(d);
 float s=max(.10,TILT); vec2 e=vec2(d.x,d.y/s); float rd=length(e); float ang=atan(e.y,e.x);
 float band=smoothstep(1.25,1.7,rd)*smoothstep(4.6,2.0,rd);
 float sw=fbm4(vec3(rd*3.2-T*.25,ang*2.+T*.9-rd*1.4,1.)); float streak=fbm4(vec3(rd*14.,ang*.5+T*.6,3.));
 float beam=clamp(1.+.85*(-e.x/max(rd,.001)),.15,2.);
 vec3 dc=mix(vec3(1.,.45,.15),vec3(1.,.92,.75),sw)*band*(.35+sw*.9+streak*.4)*beam;
 float front=smoothstep(.02,-.02,d.y);
 float ra=atan(d.y,d.x);
 float arc=smoothstep(1.12,1.28,r)*smoothstep(2.3,1.45,r)*smoothstep(-.4,.4,d.y+.25);
 float asw=fbm4(vec3(r*5.-T*.25,ra*3.+T*.9,2.));
 vec3 ac=vec3(1.,.68,.32)*arc*(.45+asw)*.95*clamp(1.+.7*(-d.x/max(r,.001)),.3,2.);
 float shadow=smoothstep(1.03,.97,r);
 float ring=exp(-pow((r-1.06)*22.,2.))*1.4;
 vec3 behind=ac+dc*(1.-front);
 vec3 col=behind*(1.-shadow)+dc*front+vec3(1.,.8,.55)*ring;
 col+=vec3(1.,.6,.3)*exp(-r*.9)*.08;
 float jx=abs(d.x)/(.06+abs(d.y)*.045); float jl=exp(-jx*jx)*smoothstep(1.,2.2,abs(d.y))*exp(-abs(d.y)*.32);
 float jn=fbm4(vec3(d.x*3.,abs(d.y)*1.2-T*1.6,5.));
 col+=vec3(.55,.7,1.)*jl*(.4+jn)*JET*1.3;
 O=vec4(col*A,1.);}`;
  // 旋涡星系（倾斜、旋臂、尘带）
  SH.galaxy = `uniform vec2 P; uniform float SZ,INC,ROT,A,DUST; uniform vec3 C1,C2;
void main(){vec2 d=rot((UV()-P)/SZ,ROT); d.y/=max(.15,INC); float r=length(d),a=atan(d.y,d.x);
 float arm=pow(.5+.5*cos(2.*(a-log(r+.04)*2.6-T*.03)),2.5);
 float n=fbm(vec3(d*5.,1.)); float clump=pow(fbm4(vec3(d*14.,2.)),2.)*2.;
 float disk=exp(-r*2.2)*(.18+arm*(.8+clump)*n*2.2);
 float core=exp(-r*16.)*1.3+exp(-r*5.)*.22;
 float dust=smoothstep(.48,.78,fbm4(vec3(d*8.,4.)))*pow(.5+.5*cos(2.*(a-log(r+.04)*2.6-T*.03)-.6),2.)*exp(-r*1.6)*DUST;
 vec3 col=mix(C2,C1,exp(-r*3.))*disk+vec3(1.,.88,.68)*core; col*=1.-clamp(dust,0.,.85);
 O=vec4(col*A,1.);}`;
  // 银河光带
  SH.milkyway = `uniform float A,TILT,Y0; uniform vec3 C1;
void main(){vec2 u=UV(); u=rot(u,TILT); float y=u.y-Y0; float x=u.x;
 float wob=.04*(fbm4(vec3(x*1.2,0.,7.))-.5);
 float band=exp(-pow((y+wob)/.085,2.))*(.55+.45*fbm4(vec3(x*2.,y*6.,1.)));
 float halo=exp(-pow(y/.22,2.))*.25;
 float clouds=pow(fbm(vec3(x*6.,y*14.,2.)),1.6)*1.8;
 float dust=smoothstep(.42,.7,fbm(vec3(x*5.,(y+wob)*16.+fbm4(vec3(x*3.,0.,3.))*1.2,5.)))*exp(-pow((y+wob*1.4)/.04,2.));
 float stars=pow(h12(floor(gl_FragCoord.xy)),220.)*2.5*(.4+band*2.);
 vec3 col=mix(vec3(.5,.58,.85),vec3(1.,.86,.66),exp(-x*x*1.5))*(band*clouds+halo*.6)*(1.-dust*.9)+stars;
 O=vec4(col*A,1.);}`;
  // 冰下体积光
  SH.icevol = `uniform float DEPTH,A; void main(){vec2 f=gl_FragCoord.xy/R; float x=f.x*R.x/R.y;
 vec3 top=mix(vec3(.45,.75,.95),vec3(.03,.16,.34),DEPTH), bot=mix(vec3(.08,.32,.58),vec3(.0,.025,.07),DEPTH);
 vec3 col=mix(bot,top,pow(f.y,.8));
 float ray=fbm4(vec3(x*2.6+f.y*.7,T*.04,0.)); ray=pow(ray,3.)*smoothstep(.1,1.,f.y)*(1.-DEPTH*.9);
 col+=vec3(.55,.85,1.)*ray*1.1;
 float sp=pow(noise(vec3(gl_FragCoord.xy*.42,T*.4)),28.)*2.5; col+=sp*vec3(.8,.92,1.)*(1.-DEPTH*.4);
 O=vec4(col*A,1.);}`;
  // 水中焦散（池水、阳光）
  SH.water = `uniform vec3 C1,C2; uniform float A,S;
void main(){vec2 p=UV()*S; float t=T*.35; vec2 i=p; float c=1.; float inten=.005;
 for(int n=0;n<5;n++){float tt=t*(1.-(3.5/float(n+1))); i=p+vec2(cos(tt-i.x)+sin(tt+i.y),sin(tt-i.y)+cos(tt+i.x)); c+=1./length(vec2(p.x/(sin(i.x+tt)/inten),p.y/(cos(i.y+tt)/inten)));}
 c/=5.; c=1.17-pow(c,1.4); float k=pow(abs(c),8.);
 vec3 col=mix(C1,C2,gl_FragCoord.y/R.y)+vec3(k)*.55*vec3(.75,1.,.85);
 O=vec4(col*A,1.);}`;
  // 宣纸：纤维与微妙不均
  SH.paper = `uniform vec3 C1; uniform float A,SEED;
void main(){vec2 p=gl_FragCoord.xy; float f=fbm4(vec3(p*.004,SEED))*.10+fbm4(vec3(p*.03,SEED+3.))*.05;
 float fiber=pow(noise(vec3(p.x*.02,p.y*.6,SEED)),6.)*.12+pow(noise(vec3(p.x*.5,p.y*.015,SEED+1.)),8.)*.08;
 float grain=(h12(p+SEED)-.5)*.05;
 vec3 col=C1*(1.-f-fiber*.6+grain); vec2 v=gl_FragCoord.xy/R-.5; col*=1.-dot(v,v)*.35;
 O=vec4(col*A,1.);}`;
  // 墨迹晕染遮罩：在 P 点以半径 RAD 扩散，边缘呈毛边
  SH.ink = `uniform vec2 P; uniform float RAD,A,SEED; uniform vec3 C1;
void main(){vec2 u=UV(); float r=length(u-P); float n=fbm(vec3((u-P)*6.,SEED))-.5; float edge=RAD*(1.+n*.55);
 float m=smoothstep(edge,edge-.04-RAD*.08,r); float core=smoothstep(edge*.85,0.,r);
 float bleed=smoothstep(edge+.06,edge,r)*(1.-m)*.35*fbm4(vec3(u*40.,SEED));
 float a=clamp(m*(.78+.22*fbm4(vec3(u*12.,SEED+2.)))+bleed+core*.1,0.,1.);
 O=vec4(C1,a*A);}`;

  const canvas = document.createElement('canvas'); canvas.width = 960; canvas.height = 540;
  const gl = canvas.getContext('webgl2', { preserveDrawingBuffer: true, premultipliedAlpha: false, alpha: true, antialias: false });
  const progs = {};
  const VS = `#version 300 es\nin vec2 p; void main(){gl_Position=vec4(p,0.,1.);}`;
  function compile(ty, src) { const s = gl.createShader(ty); gl.shaderSource(s, src); gl.compileShader(s); if (!gl.getShaderParameter(s, gl.COMPILE_STATUS)) throw new Error('GLSL: ' + gl.getShaderInfoLog(s)); return s; }
  const buf = gl.createBuffer(); gl.bindBuffer(gl.ARRAY_BUFFER, buf); gl.bufferData(gl.ARRAY_BUFFER, new Float32Array([-1, -1, 1, -1, -1, 1, 1, 1]), gl.STATIC_DRAW);
  function prog(name) {
    if (progs[name]) return progs[name];
    const src = SH[name]; if (!src) throw new Error('no shader ' + name);
    const p = gl.createProgram(); gl.attachShader(p, compile(gl.VERTEX_SHADER, VS)); gl.attachShader(p, compile(gl.FRAGMENT_SHADER, HEAD + src)); gl.linkProgram(p);
    if (!gl.getProgramParameter(p, gl.LINK_STATUS)) throw new Error(gl.getProgramInfoLog(p));
    progs[name] = { p, loc: {}, attr: gl.getAttribLocation(p, 'p') }; return progs[name];
  }
  const col = c => typeof c === 'string' ? MP.hexRgb(c).map(v => v / 255) : c;
  function draw(name, u = {}, scale = .5) {
    const w = Math.round(1920 * scale), h = Math.round(1080 * scale);
    if (canvas.width !== w || canvas.height !== h) { canvas.width = w; canvas.height = h; }
    gl.viewport(0, 0, w, h);
    const P = prog(name); gl.useProgram(P.p);
    gl.bindBuffer(gl.ARRAY_BUFFER, buf); gl.enableVertexAttribArray(P.attr); gl.vertexAttribPointer(P.attr, 2, gl.FLOAT, false, 0, 0);
    const all = Object.assign({ R: [w, h], T: 0 }, u);
    for (const k in all) {
      let v = all[k]; if (typeof v === 'string') v = col(v);
      const L = P.loc[k] ?? (P.loc[k] = gl.getUniformLocation(P.p, k)); if (L === null) continue;
      if (typeof v === 'number') gl.uniform1f(L, v); else if (v.length === 2) gl.uniform2fv(L, v); else if (v.length === 3) gl.uniform3fv(L, v); else gl.uniform4fv(L, v);
    }
    gl.clearColor(0, 0, 0, 0); gl.clear(gl.COLOR_BUFFER_BIT);
    gl.drawArrays(gl.TRIANGLE_STRIP, 0, 4);
    return canvas;
  }
  // 便捷：画到 2D 画布上（可指定叠加模式与透明度）
  function layer(ctx, name, u, o = {}) {
    const c = draw(name, u, o.scale ?? .5);
    ctx.save(); ctx.globalCompositeOperation = o.mode || 'lighter'; ctx.globalAlpha = o.alpha ?? 1;
    ctx.imageSmoothingEnabled = true; ctx.imageSmoothingQuality = 'high'; ctx.drawImage(c, 0, 0, MP.W, MP.H); ctx.restore();
  }
  // 屏幕像素坐标 → 着色器 UV（以画面高度为单位、中心为原点、y 向上）
  const uv = (x, y) => [(x - MP.W / 2) / MP.H, -(y - MP.H / 2) / MP.H];
  G.GLFX = { draw, layer, uv, define: (n, s) => { SH[n] = s; delete progs[n]; } };
})(window);
