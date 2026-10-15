// Brief darkening of the battle backdrop at a hit (2026-10-07, user: 可以在命中的瞬间把背景
// 压暗一点), so the glowing spell reads as light on a dark ground. Drawn right after the
// backdrop quad (queue 1000) and before the figures and effects, so only the painted
// backdrop darkens; the hit point itself stays lighter (a soft pool of light round it).
// Clip-space unit quad like the wash.
Shader "Mistport/Spectacle/Dim20261007" {
 Properties { _Center("World centre",Vector)=(0,0,0,0) _Amount("Amount",Float)=0 _Radius("Light radius",Float)=.32 }
 SubShader {
  Tags { "Queue"="Geometry-500" "RenderType"="Transparent" "IgnoreProjector"="True" }
  Blend SrcAlpha OneMinusSrcAlpha ZWrite Off ZTest Always Cull Off
  Pass { CGPROGRAM
  #pragma vertex vert
  #pragma fragment frag
  #include "UnityCG.cginc"
  struct appdata { float4 vertex:POSITION; float2 uv:TEXCOORD0; };
  struct v2f { float4 pos:SV_POSITION; float4 screen:TEXCOORD0; float4 centre:TEXCOORD1; };
  float4 _Center; float _Amount,_Radius;
  v2f vert(appdata v){
   v2f o; o.pos=float4(v.uv*2-1,.5,1);
   o.screen=ComputeScreenPos(o.pos);
   o.centre=ComputeScreenPos(mul(UNITY_MATRIX_VP,float4(_Center.xyz,1)));
   return o;
  }
  float4 frag(v2f i):SV_Target {
   float2 s=i.screen.xy/i.screen.w, c=i.centre.xy/max(i.centre.w,1e-4);
   float aspect=_ScreenParams.x/_ScreenParams.y;
   float dist=length((s-c)*float2(aspect,1));
   float pool=smoothstep(0,_Radius,dist);
   return float4(0,0,0,saturate(_Amount*(.45+.55*pool)));
  }
  ENDCG }
 }
}
