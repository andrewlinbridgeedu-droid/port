Shader "Mindstone/HeroSpellVolume"
{
Properties{_TimeBeat("Time",Float)=0 _Contact("Contact",Float)=.7 _Kind("Skill",Float)=2 _Layer("Depth layer",Float)=0 _Tint("Body flame",Color)=(.4,.08,1,1)}
SubShader{Tags{"Queue"="Transparent+9" "RenderType"="Transparent"} Cull Off ZWrite Off Blend One OneMinusSrcAlpha
Pass{CGPROGRAM
#pragma vertex vert
#pragma fragment frag
#pragma target 3.0
#include "UnityCG.cginc"
struct A{float4 vertex:POSITION;float2 uv:TEXCOORD0;};struct V{float4 pos:SV_POSITION;float2 uv:TEXCOORD0;};
float _TimeBeat,_Contact,_Kind,_Layer;float4 _Tint;
V vert(A a){V o;o.pos=UnityObjectToClipPos(a.vertex);o.uv=a.uv;return o;}
float hash(float2 p){return frac(sin(dot(p,float2(127.1,311.7)))*43758.5453);}
float noise(float2 p){float2 i=floor(p),f=frac(p);f=f*f*(3-2*f);return lerp(lerp(hash(i),hash(i+float2(1,0)),f.x),lerp(hash(i+float2(0,1)),hash(i+1),f.x),f.y);}
float fbm(float2 p){return noise(p)*.57+noise(p*2.13+13.4)*.29+noise(p*4.07-7.1)*.14;}
float4 frag(V i):SV_Target
{
float t=_TimeBeat,dt=t-_Contact,charge=saturate(t/_Contact),hit=smoothstep(-.025,.018,dt)*exp(-max(dt,0)*4.6),tail=1-smoothstep(_Contact+.40,_Contact+.95,t);
float2 p=(i.uv-.5)*2;float phase=_Layer*1.91;float n=fbm(p*5.5+float2(phase-t*1.6,t*2.9));float n2=fbm(p*12+float2(t*4,-t*5)+phase);float shape=0,core=0;
float warp=(n-.5)*.2,spread=.14+max(dt,0)*1.5;
if(_Kind<2.5){ // Summoning: rising twin flame columns close into a blazing forehead crest.
 float y=p.y+.45;float width=.15+.16*saturate(y);float x=p.x+sin(y*5-t*7)*.065;
 shape=exp(-pow((abs(x)-(.24*(1-charge)+.12))/width,2))*smoothstep(-.8,-.4,p.y)*(1-smoothstep(.55,1,p.y));core=exp(-dot(p-float2(0,.25),p-float2(0,.25))*32)*hit;
}else if(_Kind<4.5){ // Identity swap: two opposed energy fronts, a hot collision seam.
 float seam=p.y-sin(p.x*4+t*6)*.13;shape=exp(-abs(seam+warp)*10)*exp(-abs(abs(p.x)-(.75*(1-charge)+.10))*3);core=exp(-abs(p.x)*20-abs(p.y)*5)*hit;
}else if(_Kind<5.5){ // Evidence: a crushing vertical pressure column and ground-level detonation.
 float w=.19+.17*hit;shape=exp(-pow((p.x+warp*.5)/w,2))*smoothstep(-.85,-.5,p.y)*(1-smoothstep(.7,1,p.y));core=exp(-p.x*p.x*5-abs(p.y+.42)*20)*hit;
}else if(_Kind<6.5){ // Real shadow rush: elongated directional streak bodies, not dots.
 float y=p.y+sin(p.x*10-t*16)*.07;shape=exp(-abs(y+warp*.25)*19)*smoothstep(-1,-.7,p.x)*(1-smoothstep(.6,1,p.x));core=exp(-pow(p.x-.5,2)*28-p.y*p.y*40)*hit;
}else if(_Kind<7.5){ // Heavy slash: diagonal incision widens into a tearing explosive wedge.
 float cut=p.x*.78+p.y*.62+warp*.25;shape=exp(-abs(cut)/( .035+.11*hit))*exp(-dot(p,p)*.6);core=exp(-abs(cut)*25-dot(p,p)*3)*hit;
}else if(_Kind<8.5){ // Curtain: energy trapped behind two walls; blast escapes through opening.
 float gap=.10+hit*.5+max(dt,0)*.6;shape=exp(-pow((abs(p.x)-gap)/.16,2))*(1-smoothstep(.55,1,abs(p.y)));core=exp(-dot(p,p)/( .03+max(dt,0)*.9))*hit;
}else if(_Kind<9.5){ // Reverse time: visibly tightening, downward-running helical funnel.
 float width=.11+.38*saturate(p.y*.5+.5)*(1-.55*charge);float angle=p.y*15+t*15;float spine=sin(angle)*width;shape=exp(-abs(p.x-spine-warp*.25)*17)*(1-smoothstep(.65,1,abs(p.y)));core=exp(-p.x*p.x*55-pow(p.y+.45,2)*30)*hit;
}else{ // Soul storm: broad rotating fire funnel around the physical soul faces.
 float width=.20+.26*(p.y*.5+.5);float spine=sin(p.y*11-t*10+phase)*width;shape=exp(-abs(p.x-spine-warp)*8)*(1-smoothstep(.65,1,abs(p.y)));core=exp(-dot(p,p)*8)*hit;
}
// Three depth sheets carry different turbulence. Dark smoke surrounds the hot
// flame core; emission is localized, never a uniform washed-out rectangle.
float ragged=saturate(n*.9+n2*.65-.48);float fire=shape*pow(ragged,1.8)*4*(.32+charge*.8+hit*.9);
float explosion=exp(-dot(p,p)/( .055+max(dt,0)*1.6))*pow(saturate(n2+n-.64),2)*hit*2.3;
float smoke=saturate(shape*.20+explosion*.14)*tail;
float goldSkill=step(4.5,_Kind)*step(_Kind,5.5)+step(6.5,_Kind)*step(_Kind,7.5);
float3 hot=lerp(lerp(_Tint.rgb,float3(1.35,1.35,1.45),.72),float3(1.8,1.14,.48),saturate(goldSkill));float3 color=lerp(_Tint.rgb,hot,saturate(fire*.8+core));
float fade=smoothstep(0,.09,t)*tail*(1-smoothstep(.83,1,max(abs(p.x),abs(p.y))));
float alpha=saturate((fire*.22+smoke+core*.28+explosion*.16)*fade)*.72;
float3 rgb=(color*fire*.61+hot*core*.78+lerp(_Tint.rgb,hot,n2)*explosion*.7)*fade*.55;
return float4(rgb+float3(.022,.012,.035)*smoke,alpha);
}
ENDCG}}
Fallback Off
}
