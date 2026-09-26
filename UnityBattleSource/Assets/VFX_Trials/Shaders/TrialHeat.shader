Shader "Mistport/TrialHeat" {Properties {_MainTex("Fire",2D)="white"{} _Opacity("Fade",Float)=1}
SubShader{Tags{"Queue"="Transparent+3"} Blend One One ZWrite Off Cull Off ZTest LEqual
Pass{CGPROGRAM
#pragma vertex vert
#pragma fragment frag
#include "UnityCG.cginc"
sampler2D _MainTex;float _Opacity;struct a{float4 p:POSITION;float2 uv:TEXCOORD0;};struct v{float4 p:SV_POSITION;float2 uv:TEXCOORD0;};v vert(a i){v o;o.p=UnityObjectToClipPos(i.p);o.uv=i.uv;return o;}
float4 frag(v i):SV_Target{float4 f=tex2D(_MainTex,i.uv);float d=dot(f.rgb,float3(.3,.5,.2))*f.a;float3 col=lerp(float3(1,.07,.004),float3(1,.9,.25),d*d);return float4(col*d*_Opacity*2,0);}
ENDCG}
}}
