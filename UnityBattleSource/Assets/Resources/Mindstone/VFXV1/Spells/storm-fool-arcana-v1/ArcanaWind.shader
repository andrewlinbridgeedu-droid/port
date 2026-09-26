Shader "Mindstone/ArcanaWind" {
Properties { _Tint("Tint",Color)=(.4,.2,1,1) _Phase("Phase",Float)=0 _Visibility("Visibility",Float)=1 }
SubShader { Tags {"Queue"="Transparent" "RenderType"="Transparent"} Cull Off ZWrite Off Blend SrcAlpha OneMinusSrcAlpha
Pass { CGPROGRAM
#pragma vertex vert
#pragma fragment frag
#include "UnityCG.cginc"
float4 _Tint; float _Phase,_Visibility;
struct app {float4 vertex:POSITION;float2 uv:TEXCOORD0;};
struct v2f {float4 pos:SV_POSITION;float2 uv:TEXCOORD0;float3 p:TEXCOORD1;};
v2f vert(app v){v2f o;o.pos=UnityObjectToClipPos(v.vertex);o.uv=v.uv;o.p=mul(unity_ObjectToWorld,v.vertex).xyz;return o;}
float hash(float3 p){return frac(sin(dot(p,float3(127.1,311.7,74.7)))*43758.5453);}
float noise(float3 p){float3 i=floor(p),f=frac(p);f=f*f*(3-2*f);return lerp(lerp(lerp(hash(i),hash(i+float3(1,0,0)),f.x),lerp(hash(i+float3(0,1,0)),hash(i+float3(1,1,0)),f.x),f.y),lerp(lerp(hash(i+float3(0,0,1)),hash(i+float3(1,0,1)),f.x),lerp(hash(i+float3(0,1,1)),hash(i+1),f.x),f.y),f.z);}
float4 frag(v2f i):SV_Target {float3 p=i.p*float3(2.5,7,2.5)+float3(_Phase*.5,-_Phase*3,_Phase);float n=noise(p)*.55+noise(p*2.1)*.3+noise(p*4.4)*.15;float edge=pow(saturate(sin(i.uv.x*3.14159)),.65);float tip=smoothstep(0,.08,i.uv.y)*(1-smoothstep(.86,1,i.uv.y));float ridge=pow(saturate(n*1.4),5);float3 col=lerp(float3(.018,.013,.055),_Tint.rgb,.45+n*.8)+ridge*_Tint.rgb*2.5;return float4(col,edge*tip*smoothstep(.3,.65,n)*.85*_Visibility);}
ENDCG } } }
