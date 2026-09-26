Shader "Mistport/Character Contact Shadow" {
 Properties { _Color("Shadow",Color)=(.025,.024,.035,.18) }
 SubShader {
  Tags { "Queue"="Transparent-100" "RenderType"="Transparent" "IgnoreProjector"="True" }
  Blend SrcAlpha OneMinusSrcAlpha
  ZWrite Off Cull Off Lighting Off
  Pass {
   CGPROGRAM
   #pragma vertex vert
   #pragma fragment frag
   #include "UnityCG.cginc"
   struct appdata {float4 vertex:POSITION;float2 uv:TEXCOORD0;};
   struct v2f {float4 pos:SV_POSITION;float2 uv:TEXCOORD0;};
   fixed4 _Color;
   v2f vert(appdata v) {v2f o;o.pos=UnityObjectToClipPos(v.vertex);o.uv=v.uv*2-1;return o;}
   fixed4 frag(v2f i):SV_Target {
    float radius=dot(i.uv,i.uv);
    float soft=exp2(-radius*5.5)*saturate((1-radius)*3);
    return fixed4(_Color.rgb,_Color.a*soft);
   }
   ENDCG
  }
 }
}
