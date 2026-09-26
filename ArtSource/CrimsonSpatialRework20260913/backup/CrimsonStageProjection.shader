Shader "Mindstone/EnemySignature/CrimsonStageProjection"
{
Properties{_Source("Caster",Vector)=(.5,.65,0,0) _Target("Victim",Vector)=(.5,.3,0,0) _Aspect("Aspect",Float)=.6 _Phase("Phase",Float)=0 _Progress("Phase progress",Float)=0 _Variant("Weave / Needles",Float)=0}
SubShader{Tags{"Queue"="Overlay-3" "RenderType"="Transparent"} Cull Off ZWrite Off ZTest Always Blend One OneMinusSrcAlpha
Pass{CGPROGRAM
#pragma vertex vert
#pragma fragment frag
#pragma target 3.0
#include "UnityCG.cginc"
struct A{float4 vertex:POSITION;float2 uv:TEXCOORD0;};struct V{float4 pos:SV_POSITION;float2 uv:TEXCOORD0;};float4 _Source,_Target;float _Aspect,_Phase,_Progress,_Variant;
V vert(A a){V o;o.pos=UnityObjectToClipPos(a.vertex);o.uv=a.uv;return o;}
float hash(float n){return frac(sin(n*127.1)*43758.5453);}
float2 rot(float2 p,float a){float c=cos(a),s=sin(a);return float2(c*p.x-s*p.y,s*p.x+c*p.y);}
float noise(float2 p){float2 g=floor(p),f=frac(p);f=f*f*(3-2*f);float n=g.x+g.y*157;return lerp(lerp(hash(n),hash(n+1),f.x),lerp(hash(n+157),hash(n+158),f.x),f.y);}
float cloud(float2 p){return noise(p)*.55+noise(p*2.13+7.1)*.3+noise(p*4.3-3.7)*.15;}
float4 frag(V i):SV_Target
{
float p=_Progress,phase=_Phase,age=phase<.5?p*1.4:phase<1.5?1.4+p*.65:2.05+p*.8;
float charge=phase<.5?smoothstep(0,1,p):1,travel=phase<.5?0:phase<1.5?pow(p,1.65):1;
float impact=step(1.5,phase),decay=impact*(1-smoothstep(.2,1,p)),fade=phase<1.5?charge:1-smoothstep(.3,1,p);
float2 asp=float2(_Aspect,1),src=_Source.xy,dst=_Target.xy;
float2 stage=lerp(src,dst,travel),q=(i.uv-stage)*asp,qs=(i.uv-src)*asp,qt=(i.uv-dst)*asp;
float3 red=float3(1.2,.025,.11),wine=float3(.10,.003,.018),pearl=float3(1.85,1.30,1.37);
float n=cloud(q*17+float2(age*1.6,-age*2.2)),n2=cloud(rot(q,age*.3)*38+age*float2(-3,2));
float turbulence=pow(saturate(n*.8+n2*.6-.40),2.1)*8;
float3 col=0;float opacity=0;
// Dense power gathers around the real source before either attack advances.
float sourceWarp=sin(qs.y*31-age*6)*.02;float gathered=exp(-pow((abs(qs.x+sourceWarp)-.065)/.034,2))*exp(-abs(qs.y)*10);
col+=lerp(red,pearl,n2)*gathered*charge*(phase<.5?1:.26)*turbulence;
if(_Variant<.5)
{
 // The curtain is a rolling tidal surface with deep wine folds, pearl crests,
 // organic torn boundaries and a rapidly opening central lane, never a rectangle.
 float sweep=sin(q.x*13-age*6)*.055+sin(q.x*29+age*4)*.015;
 float height=.12+travel*.08;float membrane=exp(-pow((q.y-sweep)/height,4))*exp(-pow(q.x/(.15+charge*.12),4));
 float rip=cloud(float2(q.x*28-age*3,q.y*19+age*4));
 float gate=smoothstep(.24,.57,rip);float folds=pow(saturate(sin(q.x*48+q.y*12-age*10+n*3)*.5+.5),5);
 float body=membrane*gate*fade;opacity+=body*.48;
 col+=wine*body+red*body*(.32+turbulence*.78)+pearl*body*folds*.46;
 // Loose crests peel off the moving tide, curving outward through the air.
 for(int k=0;k<5;k++){float side=k%2==0?-1:1;float2 c=float2(side*(.04+k*.027),sin(age*4+k)*.04);float2 w=rot(q-c,side*(.7+sin(age*3+k)*.35));float crest=exp(-abs(w.y-sin(w.x*20+age*8)*.012)*95)*exp(-abs(w.x)*11);col+=lerp(red,pearl,n2)*crest*turbulence*fade*.50;}
}
else
{
 // An overhead loom gathers substantial needles, then accelerates them into a
 // target-sized crossing kill corridor. White tips and red broad wakes are distinct.
 for(int k=0;k<17;k++)
 {
  float lane=hash(k+21)*2-1,delay=hash(k+7)*.24;
  float fall=phase<.5?0:phase<1.5?pow(saturate((p-delay)/(1-delay)),2.5):1;
  float2 top=src+float2(lane*.22, .055+hash(k+13)*.065);
  float2 end=dst+float2(lane*.065,(hash(k+31)-.5)*.035);
  float2 head=lerp(top,end,fall);float2 delta=(end-top)*asp;float angle=atan2(delta.y,delta.x);
  float2 local=rot((i.uv-head)*asp,-angle);
  float len=.045+hash(k)*.035;float needle=exp(-abs(local.y)*950)*smoothstep(-len,-len+.014,local.x)*(1-smoothstep(0,.006,local.x));
  float wake=exp(-abs(local.y+sin(local.x*80-age*20)*.0015)*135)*smoothstep(-len*2,-len,local.x)*(1-smoothstep(-.005,.01,local.x));
  float visibility=phase<.5?saturate(p*1.8-hash(k)*.7):phase<1.5?1:(1-p);
  col+=pearl*needle*visibility*1.05+red*wake*turbulence*visibility*.64;
 }
 float loom=exp(-qs.x*qs.x*48-pow(qs.y-.065,2)*140)*charge*(1-travel);col+=red*loom*turbulence*.7;
}
// A shared material vocabulary, different impact geometry: a lateral velvet
// rupture for the tide, diagonal needle fractures for the second spell.
float radius=length(qt);float a=atan2(qt.y,qt.x);float spread=.028+p*.22;
float cloudImpact=cloud(rot(qt,impact*p*.7)*19+float2(-age*2,age*3));
float broken=pow(saturate(cloudImpact*.8+noise(qt*61-age*5)*.5-.37),2.1)*7;
float burst=exp(-radius*(5.0+p*2))*broken*decay;
float kernel=exp(-dot(qt,qt)/(.0015+p*.006))*exp(-p*8)*impact;
float fracture=_Variant<.5?exp(-abs(qt.y+sin(qt.x*30)*.012)*55):pow(saturate(sin(a*5-radius*38+p*4)*.5+.5),6);
col+=lerp(red,pearl,cloudImpact)*burst*(.8+fracture*.8)+pearl*kernel*1.2;
opacity+=burst*.13;
// Solid-looking bright slivers blow out through the red-black pressure cloud.
for(int j=0;j<13;j++){float angle=hash(j+60)*6.283;float2 c=float2(cos(angle),sin(angle))*(.025+p*(.10+hash(j)*.18));float2 d=rot(qt-c,angle);float sliver=exp(-abs(d.y)*700-abs(d.x)*100);col+=lerp(red,pearl,hash(j+4))*sliver*decay*.7;}
float vignette=1-smoothstep(.40,.64,radius);
return float4(min(col,2.5)*vignette,saturate(opacity)*vignette);
}
ENDCG}}
Fallback Off
}
