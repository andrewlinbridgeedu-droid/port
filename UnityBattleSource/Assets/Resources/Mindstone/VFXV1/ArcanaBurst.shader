Shader "Mindstone/VFXV1/ArcanaBurst" {
 SubShader {
  Tags { "Queue"="Transparent" "RenderType"="Transparent" }
  Blend SrcAlpha One
  Cull Off ZWrite Off
  Pass {
   CGPROGRAM
   #pragma vertex vert
   #pragma fragment frag
   #include "UnityCG.cginc"
   struct appdata { float4 vertex:POSITION; float2 uv:TEXCOORD0; };
   struct v2f { float4 pos:SV_POSITION; float2 uv:TEXCOORD0; };
   float4 _Color;
   v2f vert(appdata v){v2f o;o.pos=UnityObjectToClipPos(v.vertex);o.uv=v.uv;return o;}
   fixed4 frag(v2f i):SV_Target {
    float2 p=(i.uv-.5)*2;
    float r=length(p);
    float turbulence=.7+.3*sin(p.x*19+sin(p.y*13))*sin(p.y*17+p.x*7);
    float alpha=pow(saturate(1-r),2)*turbulence;
    return float4(lerp(_Color.rgb,float3(1,.92,.8),pow(saturate(1-r),6))*1.5,alpha*_Color.a);
   }
   ENDCG
  }
 }
}
