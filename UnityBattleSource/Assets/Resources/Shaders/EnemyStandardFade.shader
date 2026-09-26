Shader "Mindstone/Enemy Standard Fade" {
 Properties {
  _Color("Color",Color)=(1,1,1,1)
  _MainTex("Albedo",2D)="white"{}
  _Metallic("Metallic",Range(0,1))=0
  _Glossiness("Smoothness",Range(0,1))=.5
  _MetallicGlossMap("Metallic Smoothness",2D)="white"{}
  _GlossMapScale("Smoothness Scale",Range(0,1))=1
  _BumpMap("Normal",2D)="bump"{}
  _BumpScale("Normal Scale",Float)=1
  _OcclusionMap("Occlusion",2D)="white"{}
  _OcclusionStrength("Occlusion Strength",Range(0,1))=1
  _EmissionMap("Emission",2D)="white"{}
  _EmissionColor("Emission Color",Color)=(0,0,0,0)
  _ExitOpacity("Exit Opacity",Range(0,1))=1
  _ExitMetallicMap("Use Metallic Map",Float)=0
  _ExitEmission("Use Emission",Float)=0
  _ExitNormal("Use Normal",Float)=0
  _ExitCutout("Original Cutout",Float)=0
  _Cutoff("Cutoff",Range(0,1))=.5
 }
 SubShader {
  Tags {"RenderType"="Transparent" "Queue"="Transparent"}
  CGPROGRAM
  #pragma surface surf Standard fullforwardshadows alpha:fade
  #pragma target 3.0
  #include "UnityStandardUtils.cginc"
  sampler2D _MainTex,_MetallicGlossMap,_BumpMap,_OcclusionMap,_EmissionMap;
  fixed4 _Color,_EmissionColor;
  half _Metallic,_Glossiness,_GlossMapScale,_BumpScale,_OcclusionStrength;
  half _ExitOpacity,_ExitMetallicMap,_ExitEmission,_ExitNormal,_ExitCutout,_Cutoff;
  struct Input {float2 uv_MainTex;};
  void surf(Input i,inout SurfaceOutputStandard o) {
   fixed4 c=tex2D(_MainTex,i.uv_MainTex)*_Color;
   if(_ExitCutout>.5) clip(c.a-_Cutoff);
   fixed4 mg=tex2D(_MetallicGlossMap,i.uv_MainTex);
   o.Albedo=c.rgb;
   o.Metallic=lerp(_Metallic,mg.r,_ExitMetallicMap);
   o.Smoothness=lerp(_Glossiness,mg.a*_GlossMapScale,_ExitMetallicMap);
   o.Normal=lerp(float3(0,0,1),UnpackScaleNormal(tex2D(_BumpMap,i.uv_MainTex),_BumpScale),_ExitNormal);
   o.Occlusion=lerp(1,tex2D(_OcclusionMap,i.uv_MainTex).g,_OcclusionStrength);
   o.Emission=tex2D(_EmissionMap,i.uv_MainTex).rgb*_EmissionColor.rgb*_ExitEmission;
   o.Alpha=c.a*_ExitOpacity;
  }
  ENDCG
 }
 Fallback "Transparent/Diffuse"
}
