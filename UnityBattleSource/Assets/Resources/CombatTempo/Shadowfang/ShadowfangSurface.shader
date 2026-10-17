Shader "Mistport/Shadowfang/Surface"
{
 Properties {
  _MainTex ("Albedo", 2D) = "white" {}
  _BumpMap ("Normal", 2D) = "bump" {}
  _PackedMap ("glTF roughness G", 2D) = "white" {}
  _Color ("Tint", Color) = (0.85,0.85,0.85,1)
  _BumpScale ("Normal strength", Range(0,2)) = 0.95
 }
 SubShader {
  Tags { "RenderType"="Opaque" }
  LOD 300
  CGPROGRAM
  #pragma surface surf StandardSpecular fullforwardshadows
  #pragma target 3.0
  #include "UnityStandardUtils.cginc"
  sampler2D _MainTex, _BumpMap, _PackedMap;
  fixed4 _Color;
  half _BumpScale;
  struct Input { float2 uv_MainTex; float4 color : COLOR; };
  void surf(Input IN, inout SurfaceOutputStandardSpecular o) {
   fixed4 base = tex2D(_MainTex, IN.uv_MainTex);
   half rough = tex2D(_PackedMap, IN.uv_MainTex).g;
   o.Albedo = base.rgb * _Color.rgb;
   o.Normal = normalize(lerp(half3(0,0,1), UnpackScaleNormal(tex2D(_BumpMap, IN.uv_MainTex), _BumpScale), IN.color.a));
   // Preserve the authored UV-aligned material variation, with a broad matte
   // fur response and restrained dielectric highlights on smoother regions.
   o.Smoothness = clamp((1-rough)*0.65, 0.06, 0.32);
   o.Specular = half3(0.012,0.012,0.012);
   o.Occlusion = 1;
   o.Alpha = 1;
  }
  ENDCG
 }
 Fallback "Standard"
}
