Shader "Mindstone/ArcanaSky" {
Properties { _Tint("Tint",Color)=(.4,.2,1,1) _Phase("Phase",Float)=0 _Visibility("Visibility",Float)=1 }
SubShader { Tags {"Queue"="Background" "RenderType"="Transparent"} Cull Off ZWrite Off Blend One Zero
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
float4 frag(v2f i):SV_Target {float3 p=float3(i.uv.x*7,i.uv.y*9,_Phase*.05);float n=noise(p)*.6+noise(p*2.2)*.3+noise(p*4.5)*.1;float lit=pow(saturate(n),3);float band=smoothstep(.3,.85,i.uv.y);return float4(float3(.012,.018,.038)+float3(.12,.09,.21)*lit*band,1);}
ENDCG } } }
