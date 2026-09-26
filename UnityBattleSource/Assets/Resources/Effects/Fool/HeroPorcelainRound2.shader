Shader "Mindstone/Hero/Porcelain Round2"
{
Properties {
 _MainTex("Porcelain artwork",2D)="white"{} _Color("Original colour",Color)=(1,1,1,1)
 _BumpMap("Original porcelain normal",2D)="bump"{} _BumpScale("Normal detail",Float)=1 _HasNormal("Normal enabled",Float)=0
 _Gilt("Moving seams",Color)=(1,.65,.25,1) _Fade("Visibility",Float)=1
 _Dissolve("Edge erosion",Float)=0 _Clock("Visual time",Float)=0 _Response("Real state response",Float)=0
 _PortraitFill("Distant identity portrait fill",Range(0,1))=0
}
SubShader { Tags{"Queue"="Transparent+21" "RenderType"="Transparent"} Blend SrcAlpha OneMinusSrcAlpha ZWrite Off Cull Back
Pass { Tags{"LightMode"="ForwardBase"}
CGPROGRAM
#pragma vertex vert
#pragma fragment frag
#pragma target 3.0
#include "UnityCG.cginc"
#include "Lighting.cginc"
sampler2D _MainTex,_BumpMap;float4 _MainTex_ST,_BumpMap_ST,_Color,_Gilt;float _Fade,_Dissolve,_Clock,_Response,_BumpScale,_HasNormal,_PortraitFill;
struct V {float4 pos:SV_POSITION;float2 uv:TEXCOORD0;float3 normal:TEXCOORD1;float3 world:TEXCOORD2;float2 normalUV:TEXCOORD3;float3 tangent:TEXCOORD4;float3 bitangent:TEXCOORD5;};
V vert(appdata_tan a){V o;o.pos=UnityObjectToClipPos(a.vertex);o.uv=TRANSFORM_TEX(a.texcoord,_MainTex);o.normal=UnityObjectToWorldNormal(a.normal);o.world=mul(unity_ObjectToWorld,a.vertex).xyz;o.normalUV=TRANSFORM_TEX(a.texcoord,_BumpMap);o.tangent=UnityObjectToWorldDir(a.tangent.xyz);o.bitangent=cross(o.normal,o.tangent)*a.tangent.w*unity_WorldTransformParams.w;return o;}
float hash(float2 p){return frac(sin(dot(p,float2(127.1,311.7)))*43758.5453);}
float noise(float2 p){float2 i=floor(p),f=frac(p);f=f*f*(3-2*f);return lerp(lerp(hash(i),hash(i+float2(1,0)),f.x),lerp(hash(i+float2(0,1)),hash(i+1),f.x),f.y);}
float4 frag(V i):SV_Target{
 float4 art=tex2D(_MainTex,i.uv);float3 n=normalize(i.normal),view=normalize(_WorldSpaceCameraPos-i.world),light=normalize(UnityWorldSpaceLightDir(i.world));
 float3 detail=UnpackNormal(tex2D(_BumpMap,i.normalUV));detail.xy*=_BumpScale;
 if(_HasNormal>.5)n=normalize(i.tangent*detail.x+i.bitangent*detail.y+n*detail.z);
 float facing=saturate(dot(n,view)),rim=pow(1-facing,3);
 float3 lit=art.rgb*_Color.rgb*(max(ShadeSH9(float4(n,1)),float3(.25,.25,.30))+_LightColor0.rgb*saturate(dot(n,light))*.75);
 // A soft camera-side key reveals the nose, cheeks and authored porcelain.
 // It is coloured surface lighting, not additive face-erasing bloom.
 lit+=art.rgb*_Color.rgb*_PortraitFill*(.34+.30*facing);
 float spec=pow(saturate(dot(n,normalize(light+view))),40);
 float grain=noise(i.uv*22+float2(.0,.15))* .7+noise(i.uv*63)*.3;
 float fissure=pow(saturate(1-abs(noise(i.uv*33)-.50)*22),5);
 float scan=exp(-pow((frac(i.uv.y*.73+i.uv.x*.23-_Clock*.35)-.45)/.09,2));
 float erase=smoothstep(_Dissolve*.94-.025,_Dissolve*.94+.06,grain);
 float edge=(1-smoothstep(.0,.085,abs(grain-_Dissolve*.94)))*step(.025,_Dissolve);
 lit+=_LightColor0.rgb*spec*.23+_Gilt.rgb*(rim*(.22+scan*.50)+fissure*scan*.28+edge*.65+_Response*fissure*.6);
 return float4(lit,art.a*_Color.a*_Fade*erase);
}
ENDCG }
}
Fallback Off
}
