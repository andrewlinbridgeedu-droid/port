Shader "Hidden/MistportTrialBloom" {Properties{_MainTex("Source",2D)="white"{}}
SubShader {Cull Off ZWrite Off ZTest Always
CGINCLUDE
#include "UnityCG.cginc"
sampler2D _MainTex,_Bloom;float4 _MainTex_TexelSize;float2 _Axis;
float4 extract(v2f_img i):SV_Target{float3 c=tex2D(_MainTex,i.uv).rgb;float b=max(c.r,max(c.g,c.b));return float4(c*saturate((b-1.05)/max(b,.001)),1);}
float4 blur(v2f_img i):SV_Target{float2 d=_MainTex_TexelSize.xy*_Axis;float3 c=tex2D(_MainTex,i.uv).rgb*.227027;c+=(tex2D(_MainTex,i.uv+d*1.384615).rgb+tex2D(_MainTex,i.uv-d*1.384615).rgb)*.316216;c+=(tex2D(_MainTex,i.uv+d*3.230769).rgb+tex2D(_MainTex,i.uv-d*3.230769).rgb)*.07027;return float4(c,1);}
float4 combine(v2f_img i):SV_Target{float3 c=tex2D(_MainTex,i.uv).rgb;return float4(c+tex2D(_Bloom,i.uv).rgb*.36,1);}
ENDCG
Pass{CGPROGRAM
#pragma vertex vert_img
#pragma fragment extract
ENDCG}
Pass{CGPROGRAM
#pragma vertex vert_img
#pragma fragment blur
ENDCG}
Pass{CGPROGRAM
#pragma vertex vert_img
#pragma fragment combine
ENDCG}
}}
