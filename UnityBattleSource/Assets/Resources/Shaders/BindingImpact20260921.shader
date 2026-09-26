Shader "Mistport/BindingImpact20260921" {
Properties{_Energy("Energy",Float)=0 _Seed("Variation",Float)=0 _Core("Core",Float)=0}
SubShader{Tags{"Queue"="Transparent+12" "RenderType"="Transparent"}Blend One One Cull Off ZWrite Off ZTest LEqual
Pass{CGPROGRAM
#pragma vertex vert
#pragma fragment frag
#include "UnityCG.cginc"
struct a{float4 p:POSITION;float2 uv:TEXCOORD0;};struct v{float4 p:SV_POSITION;float2 uv:TEXCOORD0;};float _Energy,_Seed,_Core;
v vert(a i){v o;o.p=UnityObjectToClipPos(i.p);o.uv=i.uv;return o;}
float4 frag(v i):SV_Target{
 float2 p=(i.uv-.5)*2;float r=length(p);float ang=atan2(p.y,p.x);
 float jag=1+.10*sin(ang*7+_Seed)+.06*sin(ang*13-_Seed);
 float core=exp(-r*r*20);float plume=pow(saturate(1-r*jag),3);
 float taper=pow(saturate(1-abs(p.x)),.7);float ray=exp(-p.y*p.y*(10+abs(p.x)*22))*taper;
 float shape=lerp(ray,plume*.8+core,_Core);
 float white=lerp(pow(saturate(1-abs(p.y)),4),core,_Core);
 float3 color=lerp(float3(1,.29,.015),float3(1.65,1.40,.75),white);
 return float4(color*shape*_Energy,0);
}
ENDCG}}}
