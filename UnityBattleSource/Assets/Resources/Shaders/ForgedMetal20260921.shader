Shader "Mistport/ForgedMetal20260921"{
Properties{_Color("Metal",Color)=(.2,.25,.3,1)}
SubShader{Tags{"RenderType"="Opaque"}Cull Off
CGPROGRAM
#pragma surface surf Standard fullforwardshadows
#pragma target 3.0
fixed4 _Color;
struct Input{float3 worldPos;float3 worldNormal;};
void surf(Input IN,inout SurfaceOutputStandard o){float3 p=IN.worldPos;float grain=frac(sin(dot(floor(p*240),float3(12.9,78.2,39.4)))*43758);float scratch=pow(abs(sin(p.y*170+p.x*3)),28)*.14;float engraving=pow(saturate(cos(p.y*28+sin(p.x*19)*2.8)),18)*pow(saturate(cos(p.x*21)),6);o.Albedo=_Color.rgb*(.72+grain*.25+scratch)+float3(.32,.28,.18)*engraving*.45;o.Metallic=.8;o.Smoothness=.55+scratch;o.Emission=float3(.04,.07,.08)*engraving;}
ENDCG}Fallback "Standard"}
