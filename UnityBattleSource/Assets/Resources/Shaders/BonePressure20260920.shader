Shader "Mistport/BonePressure20260920" {
 Properties{_Color("Tint",Color)=(1,1,1,1)}
 SubShader{Tags{"Queue"="Transparent+20"} Blend SrcAlpha One ZWrite Off Cull Off
 Pass{CGPROGRAM
 #pragma vertex vert
 #pragma fragment frag
 #include "UnityCG.cginc"
 struct A{float4 vertex:POSITION;float2 uv:TEXCOORD0;float4 color:COLOR;};struct V{float4 pos:SV_POSITION;float2 uv:TEXCOORD0;float4 color:COLOR;};
 V vert(A v){V o;o.pos=UnityObjectToClipPos(v.vertex);o.uv=v.uv;o.color=v.color;return o;}
 float4 frag(V i):SV_Target{float width=pow(saturate(1-abs(i.uv.y*2-1)),2);float tail=sin(saturate(i.uv.x)*3.14159);float grain=.6+.4*sin(i.uv.x*83+_Time.y*14);return float4(i.color.rgb*1.6,i.color.a*width*tail*grain);}
 ENDCG}
 }
}
