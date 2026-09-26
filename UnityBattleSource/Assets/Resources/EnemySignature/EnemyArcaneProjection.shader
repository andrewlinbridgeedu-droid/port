Shader "Mindstone/EnemySignature/ArcaneProjection"
{
Properties{_Kind("Kind",Float)=0 _Phase("Phase",Float)=0 _Progress("Progress",Float)=0 _Aspect("Aspect",Float)=.7 _Source("Source",Vector)=(.5,.6,0,0) _Target("Target",Vector)=(.5,.3,0,0)}
SubShader{Tags{"Queue"="Transparent+18" "RenderType"="Transparent"} Cull Off ZWrite Off ZTest Always Blend One One
Pass{CGPROGRAM
#pragma vertex vert
#pragma fragment frag
#pragma target 3.0
#include "UnityCG.cginc"
struct V{float4 pos:SV_POSITION;float2 uv:TEXCOORD0;};
V vert(float4 vertex:POSITION,float2 uv:TEXCOORD0){V o;o.pos=UnityObjectToClipPos(vertex);o.uv=uv;return o;}
float _Kind,_Phase,_Progress,_Aspect;float4 _Source,_Target;
float hash(float2 p){return frac(sin(dot(p,float2(127.1,311.7)))*43758.5453);}
float noise(float2 p){float2 c=floor(p),f=frac(p);f=f*f*(3-2*f);return lerp(lerp(hash(c),hash(c+float2(1,0)),f.x),lerp(hash(c+float2(0,1)),hash(c+1),f.x),f.y);}
float cloud(float2 p){return noise(p)*.53+noise(p*2.13+13)*.29+noise(p*4.19-7)*.18;}
float2 rotate(float2 p,float a){float c=cos(a),s=sin(a);return float2(c*p.x-s*p.y,s*p.x+c*p.y);}
float4 frag(V i):SV_Target{
 float v=saturate(_Progress),cast=1-step(.5,_Phase),travel=step(.5,_Phase)*(1-step(1.5,_Phase)),impact=step(1.5,_Phase);
 float beat=_Phase+v;float2 aspect=float2(_Aspect,1);
 float2 head=cast*_Source.xy+travel*lerp(_Source.xy,_Target.xy,v)+impact*_Target.xy;
 float2 p=(i.uv-head)*aspect;float r=length(p);
 float3 tint=_Kind<.5?float3(.025,.24,1):_Kind<1.5?float3(1,.31,.025):_Kind<2.5?float3(.015,.7,.19):float3(.13,.95,.43);
 float3 hot=lerp(tint,float3(.88,1,.93),.56);
 float n=cloud(p*19+float2(-beat*1.5,beat*2.3));
 float n2=cloud(rotate(p,beat*.43)*43+float2(beat*4,beat*1.2));
 float turbulence=pow(saturate(n*.78+n2*.58-.34),2.1)*8;
 float fade=cast*v*v+travel+impact*pow(1-v,1.8);
 float radius=cast?.055+.026*v:travel?.18:.20+.28*sqrt(v);
 float envelope=exp(-pow(r/max(radius,.01),1.3)*1.4);
 float3 col=0;
 if(_Kind<.5){
   // Ion exhaust wraps the real flying forearm, followed by a compressed plasma detonation.
   float2 delta=(_Target.xy-_Source.xy)*aspect;
   float angle=atan2(delta.y,delta.x);float2 tail=rotate((i.uv-head)*aspect,-angle);
   float wake=exp(-abs(tail.y+sin(tail.x*43-beat*13)*.008)*80)*smoothstep(-.3,-.03,tail.x)*(1-smoothstep(0,.02,tail.x));
   col+=lerp(tint,hot,n2)*wake*turbulence*travel*.9;
   col+=hot*exp(-r*75)*fade*.45;
 } else if(_Kind<1.5){
   // Broad turbulent pressure front behind the solid mechanical shards.
   float pressure=exp(-pow(p.y/.055,2))*exp(-abs(p.x)*8);
   col+=lerp(tint,hot,n2)*pressure*turbulence*travel*.75;
   col+=hot*exp(-abs(p.y)*105-abs(p.x)*14)*impact*pow(1-v,5)*.6;
 } else if(_Kind<2.5){
   // A broad living emerald wave, with irregular folded crests rather than a projectile sphere.
   float crest=p.y+sin(p.x*24+beat*4)*.018+sin(p.x*47-beat*7)*.007;
   float wave=exp(-abs(crest)*34)*exp(-pow(p.x/.24,4));
   col+=lerp(tint,hot,saturate(n2*n2))*wave*turbulence*(travel+cast*v*.3)*.85;
 } else {
   // The second soul spell contracts into a rotating crown of turbulent vapor.
   float angle=atan2(p.y,p.x);
   float curl=pow(saturate(sin(angle*3-r*42+beat*6)*.5+.5),2);
   col+=tint*curl*turbulence*exp(-r*13)*(travel+cast*v*.5)*.7;
 }
 col+=lerp(tint,hot,smoothstep(.58,.9,n2))*turbulence*envelope*fade*(impact?1.5:.65);
 float hotCore=exp(-r*r/(.00045+v*.008))*impact*pow(1-v,5);
 col+=hot*hotCore*.65;
 return float4(min(col*2.0,2.0),1);
}
ENDCG}}
Fallback Off
}
