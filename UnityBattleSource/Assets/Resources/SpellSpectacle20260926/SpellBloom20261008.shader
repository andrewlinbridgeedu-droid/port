// Spell bloom (2026-10-08, user: 试整屏辉光后期). The spell layer alone is drawn into a
// half-resolution buffer, blurred down and back up (dual filter) and added onto the
// camera image, so spells light their surroundings as in the reference short while the
// bright marble and sky stay as they are.
// Pass 0: downsample. Pass 1: upsample, added onto the larger level. Pass 2: composite.
Shader "Hidden/Mistport/SpellBloom20261008" {
 Properties { _MainTex("", 2D) = "black" {} }
 CGINCLUDE
 #include "UnityCG.cginc"
 sampler2D _MainTex; float4 _MainTex_TexelSize; float _Intensity;
 struct v2f { float4 pos:SV_POSITION; float2 uv:TEXCOORD0; };
 v2f vert(appdata_img v) { v2f o; o.pos = UnityObjectToClipPos(v.vertex); o.uv = v.texcoord; return o; }
 half4 down(v2f i):SV_Target {
  float2 d = _MainTex_TexelSize.xy;
  half4 s = tex2D(_MainTex, i.uv) * 4;
  s += tex2D(_MainTex, i.uv + d * float2(-1, -1));
  s += tex2D(_MainTex, i.uv + d * float2( 1, -1));
  s += tex2D(_MainTex, i.uv + d * float2(-1,  1));
  s += tex2D(_MainTex, i.uv + d * float2( 1,  1));
  return s / 8;
 }
 half4 up(v2f i):SV_Target {
  float2 d = _MainTex_TexelSize.xy;
  half4 s = tex2D(_MainTex, i.uv + float2(-2 * d.x, 0));
  s += tex2D(_MainTex, i.uv + float2(-d.x, d.y)) * 2;
  s += tex2D(_MainTex, i.uv + float2(0, 2 * d.y));
  s += tex2D(_MainTex, i.uv + float2(d.x, d.y)) * 2;
  s += tex2D(_MainTex, i.uv + float2(2 * d.x, 0));
  s += tex2D(_MainTex, i.uv + float2(d.x, -d.y)) * 2;
  s += tex2D(_MainTex, i.uv + float2(0, -2 * d.y));
  s += tex2D(_MainTex, i.uv + float2(-d.x, -d.y)) * 2;
  return s / 12;
 }
 half4 comp(v2f i):SV_Target { return tex2D(_MainTex, i.uv) * _Intensity; }
 ENDCG
 SubShader {
  Cull Off ZWrite Off ZTest Always
  Pass { Blend Off
   CGPROGRAM
   #pragma vertex vert
   #pragma fragment down
   ENDCG }
  Pass { Blend One One
   CGPROGRAM
   #pragma vertex vert
   #pragma fragment up
   ENDCG }
  Pass { Blend One One
   CGPROGRAM
   #pragma vertex vert
   #pragma fragment comp
   ENDCG }
 }
}
