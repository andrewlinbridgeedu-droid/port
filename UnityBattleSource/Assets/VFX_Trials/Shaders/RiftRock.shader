Shader "Mistport/RiftRockTrial"{Properties{_MainTex("Rock grain",2D)="white"{} _Color("Tint",Color)=(1,1,1,1) _Gain("Gain",Float)=1 _Opacity("Life",Float)=1}
SubShader{Tags{"Queue"="Transparent"}Blend One OneMinusSrcAlpha ZWrite Off Cull Off ZTest LEqual
Pass{CGPROGRAM
#pragma vertex vert
#pragma fragment frag
#include "UnityCG.cginc"
sampler2D _MainTex;float4 _Color;float _Gain,_Opacity;struct a{float4 p:POSITION;float3 n:NORMAL;float2 uv:TEXCOORD0;};struct v{float4 p:SV_POSITION;float3 n:TEXCOORD1;float2 uv:TEXCOORD0;};v vert(a i){v o;o.p=UnityObjectToClipPos(i.p);o.n=UnityObjectToWorldNormal(i.n);o.uv=i.uv;return o;}
float4 frag(v i):SV_Target{float3 c=tex2D(_MainTex,float2(.3+i.uv.x*.2,.38+i.uv.y*.22)).rgb;float light=.7+max(0,dot(normalize(i.n),normalize(float3(-.3,1,-.6))))*.8;return float4(c*light*_Opacity,_Opacity);}
ENDCG}
}}
