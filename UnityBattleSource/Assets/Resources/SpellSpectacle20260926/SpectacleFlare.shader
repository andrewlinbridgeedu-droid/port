// Camera-facing flares, splashes and motes built on the CPU each frame.
// Vertex colour carries tint and alpha; uv2.x carries how much of the quad
// is alpha-blended (1) versus additive (0). Only the tight centre of a texel
// whitens, so the flare keeps the identity hue around a small hot heart.
Shader "Mistport/Spectacle/Flare20260926" {
 Properties {
  _MainTex("Atlas",2D)="white"{} _WhiteCore("White core",Float)=.9
  _Hot("Hot colour",Color)=(1,.97,.9,1)
 }
 SubShader {
  Tags { "Queue"="Transparent+90" "RenderType"="Transparent" "IgnoreProjector"="True" }
  Blend One OneMinusSrcAlpha ZWrite Off ZTest Always Cull Off
  Pass { CGPROGRAM
  #pragma vertex vert
  #pragma fragment frag
  #include "UnityCG.cginc"
  struct appdata { float4 vertex:POSITION; float2 uv:TEXCOORD0; float2 uv2:TEXCOORD1; float4 color:COLOR; };
  struct v2f { float4 pos:SV_POSITION; float2 uv:TEXCOORD0; float2 blend:TEXCOORD1; float4 color:COLOR; };
  sampler2D _MainTex; float _WhiteCore; float4 _Hot;
  v2f vert(appdata v){ v2f o; o.pos=UnityObjectToClipPos(v.vertex); o.uv=v.uv; o.blend=v.uv2; o.color=v.color; return o; }
  float4 frag(v2f i):SV_Target {
   float t=tex2D(_MainTex,i.uv).a;
   // uv2.y: how far this mark's densest texels whiten (stars high, solid matter none).
   float3 col=lerp(i.color.rgb,_Hot.rgb,saturate(pow(t,5)*_WhiteCore*i.blend.y));
   float a=t*i.color.a;
   return float4(col*a,a*i.blend.x);
  }
  ENDCG }
 }
}
