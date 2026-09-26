Shader "Mindstone/Encore Flame" {
 Properties { _MainTex ("Flame", 2D) = "white" {} _Color ("Tint", Color) = (1,1,1,1) }
 SubShader {
  Tags { "Queue"="Transparent" "RenderType"="Transparent" }
  Cull Off ZWrite Off ZTest LEqual Blend SrcAlpha One
  Pass {
   CGPROGRAM
   #pragma vertex vert
   #pragma fragment frag
   #include "UnityCG.cginc"
   sampler2D _MainTex; fixed4 _Color;
   struct appdata { float4 vertex:POSITION; float2 uv:TEXCOORD0; fixed4 color:COLOR; };
   struct v2f { float4 vertex:SV_POSITION; float2 uv:TEXCOORD0; fixed4 color:COLOR; };
   v2f vert(appdata v) { v2f o; o.vertex=UnityObjectToClipPos(v.vertex); o.uv=v.uv; o.color=v.color*_Color; return o; }
   fixed4 frag(v2f i):SV_Target {
    fixed4 t=tex2D(_MainTex,i.uv);
    float density=t.r*t.a;
    float3 core=lerp(i.color.rgb,float3(1,.85,.35),density*.7);
    return fixed4(core*1.8,density*i.color.a);
   }
   ENDCG
  }
 }
}
