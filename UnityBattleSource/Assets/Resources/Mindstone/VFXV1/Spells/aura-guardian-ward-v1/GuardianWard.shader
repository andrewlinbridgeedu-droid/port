Shader "Mindstone/GuardianWard" {
Properties { _Layer("Layer",Float)=0 _Opacity("Opacity",Float)=1 _Clock("Clock",Float)=0 _Hit("Hit",Float)=0 }
SubShader { Tags { "Queue"="Transparent+30" "RenderType"="Transparent" } Blend One OneMinusSrcAlpha ZWrite Off Cull Back
Pass { CGPROGRAM
#pragma target 3.0
#pragma vertex vert
#pragma fragment frag
#include "UnityCG.cginc"
struct v2f { float4 pos:SV_POSITION; float3 local:TEXCOORD0; float3 eye:TEXCOORD1; float2 uv:TEXCOORD2; };
float _Opacity,_Clock,_Hit,_Layer;
v2f vert(appdata_base v) { v2f o; o.pos=UnityObjectToClipPos(v.vertex);o.local=v.vertex.xyz;o.eye=mul(unity_WorldToObject,float4(_WorldSpaceCameraPos,1)).xyz;o.uv=v.texcoord.xy;return o; }
float mist(float3 p) {
return .5+.5*sin(p.x*15+sin(p.z*13))*sin(p.y*17+cos(p.x*11))*sin(p.z*16+sin(p.y*9));
}
float stroke(float x,float w) {return 1-smoothstep(w,w+.012,abs(x));}
fixed4 frag(v2f i):SV_Target {
float3 ray=normalize(i.local-i.eye);
float b=dot(i.eye,ray),c=dot(i.eye,i.eye)-.25;
float d=sqrt(max(0,b*b-c));float nearT=max(0,-b-d),farT=-b+d;
float stepSize=(farT-nearT)/20;
float density=0, wisps=0, energy=0;float t=_Clock;
float breath=.72+.28*sin(t*1.9635);
[unroll] for(int k=0;k<20;k++) {
float3 p=i.eye+ray*(nearT+(k+.5)*stepSize);
float r=length(p)*2;
// Density goes to zero before the enclosing geometry, so there is no silhouette rim.
float fall=exp(-pow((r-.72)/.24,2))*(1-smoothstep(.84,1,r));
float3 q=p+float3(sin(t*.37)*.12,t*.045,cos(t*.29)*.12);
float n=mist(q*1.7), n2=mist(q*3.1+4.7);
density+=(.14+.24*n)*fall*stepSize;
wisps+=pow(saturate(n2),7)*fall*stepSize;
}
float longitude=atan2(i.local.z,i.local.x);
float latitude=i.local.y/max(length(i.local),.001);
// Many seeded strands drift independently over the volume shell.
float filaments=0;
[unroll] for(int strand=0;strand<28;strand++) {
    float seed=frac(sin((strand+1)*127.13)*43758.54);
    float phase=seed*6.28318;
    float speed=(.18+seed*.42)*(fmod(strand,2)<1?1:-1);
    float center=sin(phase+t*speed)*2.8;
    float delta=atan2(sin(longitude-center),cos(longitude-center));
    float latitudePath=sin(phase*3.7+t*speed*.53)*.7
        +.14*sin(longitude*(2+fmod(strand,3))+phase+t*speed);
    float strandWidth=.012+seed*.009;
    float fine=exp(-pow((latitude-latitudePath)/strandWidth,2));
    float lengthMask=exp(-pow(delta/(.22+seed*.55),2));
    float shimmer=.35+.65*pow(.5+.5*sin(t*(.7+seed)+phase),2);
    filaments+=fine*lengthMask*shimmer;
}
energy=filaments*.22;
float facing=saturate(dot(normalize(i.local),-ray));
energy*=smoothstep(.08,.4,facing);
float2 cell=float2(frac(i.uv.x*21+t*.1)-.5,(i.uv.y-.5)*10);
float variation=fmod(floor(i.uv.x*21+t*.1),3);
float glyph=stroke(cell.x,.015)*step(abs(cell.y),.3);
glyph+=stroke(abs(cell.x)+abs(cell.y)-.24,.018)*step(abs(cell.y),.3);
glyph*=pow(facing,2)*(.35+.65*sin(i.uv.x*33+t)*sin(i.uv.x*33+t));
float hit=exp(-pow((length(i.local-float3(0,0,-.45))-_Hit*.9)*16,2))*(1-_Hit)*step(.001,_Hit)*facing;
if(_Layer==1){glyph=0;hit=0;energy=0;} if(_Layer==2){density=0;wisps=0;hit=0;} if(_Layer==3){density=0;wisps=0;glyph=0;energy=0;}
float alpha=saturate(density*.85*breath+glyph*.12+hit*.18)*_Opacity;
float3 col=float3(.09,.35,.8)*alpha;
col+=(float3(.035,.32,1)*density*.9+float3(.08,.55,1)*energy*4+float3(.15,.48,1)*wisps*2)*breath*_Opacity;
col+=(float3(.52,.72,1)*glyph*.16+float3(.35,.75,1)*hit*.7)*_Opacity;
return float4(col,alpha);
}
ENDCG } } }
