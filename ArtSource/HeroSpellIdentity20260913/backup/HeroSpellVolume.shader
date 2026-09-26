Shader "Mindstone/HeroSpellVolume"
{
Properties{_TimeBeat("Time",Float)=0 _Contact("Contact",Float)=.7 _Kind("Skill",Float)=2 _Center("Spell center",Vector)=(.5,.5,0,0) _SourceUV("Origin",Vector)=(.5,.3,0,0) _Aspect("Aspect",Float)=.6 _Atlas("Tarot art",2D)="black"{} }
SubShader{Tags{"Queue"="Overlay-2" "RenderType"="Transparent"} Cull Off ZWrite Off ZTest Always Blend SrcAlpha One
Pass{CGPROGRAM
#pragma vertex vert
#pragma fragment frag
#pragma target 3.0
#include "UnityCG.cginc"
struct A{float4 vertex:POSITION;float2 uv:TEXCOORD0;};struct V{float4 pos:SV_POSITION;float2 uv:TEXCOORD0;};
float _TimeBeat,_Contact,_Kind,_Aspect;float4 _Center,_SourceUV;sampler2D _Atlas;
V vert(A a){V o;o.pos=UnityObjectToClipPos(a.vertex);o.uv=a.uv;return o;}
float hash(float n){return frac(sin(n*127.1)*43758.5453);}
float2 rot(float2 p,float a){float c=cos(a),s=sin(a);return float2(c*p.x-s*p.y,s*p.x+c*p.y);}
float noise(float2 p){float2 g=floor(p),f=frac(p);f=f*f*(3-2*f);float n=g.x+g.y*157;return lerp(lerp(hash(n),hash(n+1),f.x),lerp(hash(n+157),hash(n+158),f.x),f.y);}
float cloud(float2 p){return noise(p)*.55+noise(p*2.1)*.3+noise(p*4.3)*.15;}
float3 art(float2 p,float tile){float2 uv=p+.5;float mask=step(0,uv.x)*step(uv.x,1)*step(0,uv.y)*step(uv.y,1);float2 offset=float2(fmod(tile,4),3-floor(tile/4));return tex2D(_Atlas,(offset+clamp(uv,.006,.994))*.25).rgb*mask;}
float4 frag(V i):SV_Target
{
float t=_TimeBeat,dt=t-_Contact,h=max(dt,0),charge=saturate(t/_Contact);
float release=smoothstep(-.02,.045,dt),fade=1-smoothstep(.38,.93,h),appear=smoothstep(0,.12,t);
float2 aspect=float2(_Aspect,1),p=(i.uv-_Center.xy)*aspect;float r=length(p);
float3 violet=float3(.43,.10,1.25),cyan=float3(.08,.66,1.25),gold=float3(1.35,.51,.075),pink=float3(1.1,.06,.32);
float3 tint=_Kind>8.5&&_Kind<9.5?cyan:_Kind>7.5&&_Kind<8.5?pink:violet;
float3 coreTint=lerp(tint,float3(1.6,1.45,1.8),.62);if((_Kind>4.5&&_Kind<5.5)||(_Kind>6.5&&_Kind<7.5)){tint=lerp(violet,gold,.45);coreTint=float3(1.9,1.2,.32);}
float n=cloud(p*15+float2(-t*1.6,t*2.3)),n2=cloud(rot(p,h*.8)*29-float2(h*4,h*2));
float3 col=0;float envelope=exp(-r*(5.3+h*3));float flame=pow(saturate(n*.7+n2*.55-.34),2.1)*10;
float bloom=release*fade;float hot=exp(-r*r/(.0018+h*.023))*exp(-h*4.5)*release;
float shape=1,windup=0;
if(_Kind<2.5){
 // A manifested face surrounded by rising, broken soul-fire lobes. Face center
 // remains readable while shoulders and crown erupt into a much larger silhouette.
 float2 q=p+float2(sin(p.y*19-t*7)*.024,0);
 float wing=exp(-pow((abs(q.x)-(.07+.055*charge))/.05,2))*exp(-abs(q.y)*6);
 float crown=exp(-p.x*p.x*90-pow(p.y-.13,2)*100);
 windup=(wing+crown)*flame*(.35+charge*.7);shape=smoothstep(.035,.10,r);
 col+=tint*windup;col+=coreTint*hot*.5*shape;
}else if(_Kind<4.5){
 float converge=.22*(1-charge);float left=exp(-pow((p.x+converge+sin(p.y*17-t*8)*.03)/.04,2));float right=exp(-pow((p.x-converge-sin(p.y*15+t*9)*.025)/.04,2));
 col+=tint*(left+right)*exp(-abs(p.y)*9)*flame*(.35+charge*.7)*(1-release*.7);
 col+=coreTint*exp(-abs(p.x)*110-abs(p.y)*8)*release*exp(-h*5)*1.7;
}else if(_Kind<5.5){
 float drop=.30*(1-pow(charge,3));float2 q=p-float2(0,drop);
 col+=gold*exp(-abs(q.x)*35-abs(q.y)*16)*flame*charge*(1-release);
 col+=coreTint*exp(-abs(p.y)*68-abs(p.x)*8)*release*exp(-h*4)*2.5;
 col+=art(rot(p,.05)/(.20+h*.4),10)*bloom*.48;
}else if(_Kind<6.5){
 float2 delta=(_Center.xy-_SourceUV.xy)*aspect;float angle=atan2(delta.y,delta.x);float2 q=rot((i.uv-_SourceUV.xy)*aspect,-angle);float along=q.x/max(.02,length(delta));
 float trail=exp(-abs(q.y+sin(along*24-t*21)*.008)*115)*smoothstep(0,.12,along)*(1-smoothstep(charge-.14,charge+.03,along));
 col+=lerp(cyan,violet,n)*trail*(1-release)*2.5;
}else if(_Kind<7.5){
 // A target-spanning hot blade stroke, followed by a broad art/shard explosion.
 float2 q=rot(p,-.63);float slash=exp(-abs(q.y+sin(q.x*30)*.006)*180)*exp(-pow(q.x/.29,4));
 col+=lerp(gold,coreTint,n2)*slash*smoothstep(.66,.98,charge)*exp(-h*7)*3.4;
 col+=gold*exp(-abs(q.y)*23)*exp(-abs(q.x)*4)*flame*bloom*1.8;
}else if(_Kind<8.5){
 float opening=.025+release*(.08+h*.32);float wall=exp(-pow((abs(p.x)-opening)/.042,2))*exp(-pow(p.y/.23,4));
 col+=lerp(pink,violet,n)*wall*flame*(.3+charge*.8)*fade;
 col+=coreTint*hot*1.5;
}else if(_Kind<9.5){
 float angle=atan2(p.y,p.x);float spiral=pow(saturate(sin(angle*3+r*56+t*15)*.5+.5),3);
 shape=spiral*.8+.25;col+=cyan*shape*flame*exp(-r*7)*charge*(1-release*.6);
 col+=coreTint*hot*.7;
}else{
 float angle=atan2(p.y,p.x);float vortex=pow(saturate(sin(angle*3-r*43-t*11)*.5+.5),2);
 shape=(vortex*.9+.25)*smoothstep(.025,.07,r);
 col+=lerp(violet,pink,n2)*shape*flame*exp(-r*5)*charge*(1-release*.25);
 col+=coreTint*hot*.7;
}
// Multiscale broken flames and illustrated shards follow each skill's geometry,
// preserving the proven TarotNova density without replacing every spell by a card.
col+=lerp(tint,coreTint,smoothstep(.58,.88,n2))*flame*envelope*bloom*shape*1.65;
if(_Kind>4.5&&_Kind<7.5){
 for(int k=0;k<16;k++){float a=hash(k+21)*6.283;float speed=.2+hash(k+7)*.42;float2 center=float2(cos(a),sin(a))*(.025+h*speed);center.y-=h*h*.06;float size=.045+hash(k+2)*.075;col+=art(rot(p-center,a+h*(hash(k+9)*5-2))/size,1+floor(hash(k+4)*3))*bloom*.58;}
}else{
 for(int k=0;k<7;k++){float a=hash(k+71)*6.283+t*(.5+hash(k));float2 c=float2(cos(a),sin(a))*(.065+h*.19);float f=exp(-length(rot(p-c,a)*float2(1,2))*55);col+=lerp(tint,coreTint,hash(k+2))*f*flame*(.4*charge+bloom)*.6;}
}
col+=coreTint*hot*.8;
float mist=pow(saturate(cloud(p*13+float2(t*.5,-t*.8))-.42),3)*3;col+=tint*mist*envelope*bloom;
return float4(min(col,2.4),appear*(1-smoothstep(.70,.95,h)));
}
ENDCG}}
Fallback Off
}
