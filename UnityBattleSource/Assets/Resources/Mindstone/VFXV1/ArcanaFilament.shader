Shader "Mindstone/VFXV1/ArcanaFilament" {
 SubShader {
  Tags { "Queue"="Transparent" "RenderType"="Transparent" }
  Blend SrcAlpha One
  Cull Off ZWrite Off
  Pass {
   CGPROGRAM
   #pragma vertex vert
   #pragma fragment frag
   #include "UnityCG.cginc"
   struct appdata { float4 vertex:POSITION; float2 uv:TEXCOORD0; float4 color:COLOR; };
   struct v2f { float4 pos:SV_POSITION; float2 uv:TEXCOORD0; float4 color:COLOR; };
   v2f vert(appdata v) { v2f o; o.pos=UnityObjectToClipPos(v.vertex); o.uv=v.uv; o.color=v.color; return o; }
   fixed4 frag(v2f i):SV_Target {
    float d=abs(i.uv.y-.5)*2;
    float core=pow(saturate(1-d),9);
    float glow=pow(saturate(1-d),2);
    return float4(lerp(i.color.rgb,float3(1,.94,1),core*.65)*1.8,(core+glow*.4)*i.color.a);
   }
   ENDCG
  }
 }
}
