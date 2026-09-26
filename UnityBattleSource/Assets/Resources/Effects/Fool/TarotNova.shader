Shader "Mindstone/Fool Tarot Nova" {
Properties { _Atlas("Tarot artwork",2D)="black" {} _Beat("Time",Float)=0 _Source("Source",Vector)=(.3,.3,0,0) _Target("Target",Vector)=(.7,.65,0,0) _Aspect("Aspect",Float)=.5 }
SubShader { Tags { "Queue"="Overlay" "RenderType"="Transparent" } Cull Off ZWrite Off ZTest Always Blend SrcAlpha One
Pass { CGPROGRAM
#pragma vertex vert
#pragma fragment frag
#include "UnityCG.cginc"
struct a {float4 vertex:POSITION;float2 uv:TEXCOORD0;}; struct v {float4 pos:SV_POSITION;float2 uv:TEXCOORD0;};
float _Beat,_Aspect; float4 _Source,_Target; sampler2D _Atlas;
v vert(a i){v o;o.pos=UnityObjectToClipPos(i.vertex);o.uv=i.uv;return o;}
float hash(float n){return frac(sin(n*127.1)*43758.5453);}
float2 rot(float2 p,float a){float c=cos(a),s=sin(a);return float2(c*p.x-s*p.y,s*p.x+c*p.y);}
float noise(float2 p){float2 g=floor(p),f=frac(p); f=f*f*(3-2*f);float n=g.x+g.y*157;return lerp(lerp(hash(n),hash(n+1),f.x),lerp(hash(n+157),hash(n+158),f.x),f.y);}
float cloud(float2 p){return noise(p)*.55+noise(p*2.1)*.3+noise(p*4.3)*.15;}
float3 art(float2 q,float tile){float2 uv=q+.5;float mask=step(0,uv.x)*step(uv.x,1)*step(0,uv.y)*step(uv.y,1);float2 offset=float2(fmod(tile,4),3-floor(tile/4));return tex2D(_Atlas,(offset+clamp(uv,.006,.994))*.25).rgb*mask;}
float4 frag(v i):SV_Target {
float t=_Beat;float2 asp=float2(_Aspect,1);float2 src=_Source.xy,dst=_Target.xy;float2 p=(i.uv-dst)*asp;float r=length(p);float hit=max(0,t-.58);float fade=1-smoothstep(1.04,1.65,t);float impact=smoothstep(.58,.62,t)*fade;
float3 violet=float3(.39,.075,1),gold=float3(1,.48,.10);float3 col=0;
float fly=saturate((t-.16)/.42);float flying=smoothstep(.08,.18,t)*(1-smoothstep(.58,.64,t));
float2 travel=(dst-src)*asp;float angle=atan2(travel.y,travel.x)-.785398;
float2 flight=lerp(src,dst,fly)+float2(-.06,.06)*sin(fly*3.14159);
col+=art(rot((i.uv-flight)*asp,-angle)/.24,5)*flying*.75;
// Turbulent ribbons taper along the curved flight path instead of rigid spokes.
float2 pathCoord=rot((i.uv-src)*asp,-atan2(travel.y,travel.x));float along=pathCoord.x/max(length(travel),.01);
float wobble=sin(along*15-t*12)*.009+sin(along*31+t*8)*.004;
float plume=exp(-abs(pathCoord.y-wobble)*110)*(0.3+cloud(float2(along*18-t*5,pathCoord.y*90))*1.2);
col+=lerp(violet,gold,pow(saturate(plume),3)) * plume * smoothstep(0,.12,along)*(1-smoothstep(fly-.13,fly+.02,along))*flying*.7;
// Irregular, curling impact flame sheets with broken edges.
float n=cloud(p*15+float2(-t*1.6,t*2.3));float n2=cloud(rot(p,hit*.8)*29-float2(hit*4,hit*2));
float envelope=exp(-r*(5.5+hit*4))*smoothstep(.015,.08,r);
float flame=pow(saturate(n*.7+n2*.55-.37),2.4)*8;
col+=lerp(violet,gold,smoothstep(.6,.88,n2))*flame*envelope*impact;
float kick=smoothstep(0,.04,hit)*exp(-max(0,hit-.04)*14);
float expand=.24+hit*.25+kick*.14;
col+=art(rot(p,hit*.17)/expand,10)*impact*.55;
// Unevenly scattered illustrated cards drift and tumble out of the impact.
for(int k=0;k<7;k++) {float a=hash(k+21)*6.283;float speed=.18+hash(k+7)*.36;float2 center=float2(cos(a),sin(a))*(.04+(1-exp(-hit*12))*speed*.65);center.y-=hit*hit*.07;float size=.075+hash(k+2)*.055;col+=art(rot(p-center,a+hit*(hash(k+9)*3-1.5))/size,1+floor(hash(k+4)*3))*impact*.38;}
// Organic wisps and embers spread beyond the impact to the screen edges.
float2 grid=i.uv*float2(9,17);float2 cell=floor(grid);float id=cell.x+cell.y*9;float2 local=frac(grid)-float2(.15+hash(id)*.7,.15+hash(id+8)*.7);local+=float2(sin(t*2+id)*.12,hit*(.2+hash(id)*.5));
float star=exp(-length(local*float2(1,2))*65)+exp(-abs(local.x)*190-abs(local.y)*18)*.3;
col+=lerp(violet,gold,hash(id+6))*star*impact*(.25+hash(id+3))*1.4;
float mist=pow(saturate(cloud(i.uv*9+float2(t*.5,-t*.8))-.45),3)*2;
col+=violet*mist*impact*.5;
return float4(min(col,2.3),smoothstep(0,.06,t)*fade);
}
ENDCG } } }
