// Painted cutout-rig parts of the final-boss party (2026-10-10): one atlas per character
// (tools/animation/pack_rig.py), straight alpha. _Flash lifts the whole figure toward white
// for a hit; _Color tints and fades it (a fallen ally dims). Same queue as the video bodies.
Shader "Mistport/CutoutPart20261010" {
 Properties { _MainTex("Parts",2D)="black"{} _Color("Tint",Color)=(1,1,1,1) _Flash("Hit flash",Range(0,1))=0 _Glow("Rim glow colour",Color)=(1,.85,.5,0) }
 SubShader {
  Tags { "Queue"="Transparent" "RenderType"="Transparent" "IgnoreProjector"="True" }
  Blend SrcAlpha OneMinusSrcAlpha ZWrite Off Cull Off
  Pass { CGPROGRAM
  #pragma vertex vert
  #pragma fragment frag
  #include "UnityCG.cginc"
  sampler2D _MainTex; fixed4 _Color, _Glow; float _Flash;
  struct A { float4 vertex:POSITION; float2 uv:TEXCOORD0; };
  struct V { float4 pos:SV_POSITION; float2 uv:TEXCOORD0; };
  V vert(A i){ V o; o.pos=UnityObjectToClipPos(i.vertex); o.uv=i.uv; return o; }
  fixed4 frag(V i):SV_Target{
   fixed4 c=tex2D(_MainTex,i.uv);
   c.rgb=lerp(c.rgb*_Color.rgb,float3(1,1,1),_Flash)+_Glow.rgb*_Glow.a*c.a;
   c.a*=_Color.a;
   return c;
  }
  ENDCG }
 }
}
