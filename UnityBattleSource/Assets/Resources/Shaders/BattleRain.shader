Shader "Mindstone/Battle Rain" {
Properties { _MainTex("Texture",2D)="white"{} }
SubShader { Tags {"Queue"="Transparent" "RenderType"="Transparent"} Blend SrcAlpha OneMinusSrcAlpha ZWrite Off Cull Off
Pass { CGPROGRAM
#pragma vertex vert
#pragma fragment frag
#include "UnityCG.cginc"
sampler2D _MainTex;
struct a {float4 vertex:POSITION;float2 uv:TEXCOORD0;fixed4 color:COLOR;};
struct v {float4 pos:SV_POSITION;float2 uv:TEXCOORD0;fixed4 color:COLOR;};
v vert(a i){v o;o.pos=UnityObjectToClipPos(i.vertex);o.uv=i.uv;o.color=i.color;return o;}
fixed4 frag(v i):SV_Target {return tex2D(_MainTex,i.uv)*i.color;}
ENDCG } } }
