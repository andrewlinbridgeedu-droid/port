Shader "Mindstone/EnemySignature/Filament"
{
 Properties { _DstBlend ("Destination blend", Float) = 1 }
 SubShader {
  Tags { "Queue"="Transparent+15" "RenderType"="Transparent" }
  Blend SrcAlpha [_DstBlend]
  ZWrite Off Cull Off
  Pass {
   CGPROGRAM
   #pragma vertex vert
   #pragma fragment frag
   #include "UnityCG.cginc"
   struct appdata { float4 vertex:POSITION; float4 color:COLOR; float2 uv:TEXCOORD0; };
   struct v2f { float4 position:SV_POSITION; float4 color:COLOR; float2 uv:TEXCOORD0; };
   v2f vert(appdata v) { v2f o; o.position=UnityObjectToClipPos(v.vertex); o.color=v.color; o.uv=v.uv; return o; }
   fixed4 frag(v2f i):SV_Target {
    float edge=saturate(1-abs(i.uv.y*2-1));
    float soft=pow(edge,.65);
    return float4(i.color.rgb, i.color.a*soft);
   }
   ENDCG
  }
 }
}
