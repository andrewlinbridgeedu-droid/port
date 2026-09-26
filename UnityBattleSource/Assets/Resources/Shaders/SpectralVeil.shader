Shader "Mindstone/Spectral Veil" {
 Properties { _Color("Color",Color)=(0.01,0.25,0.20,1) }
 SubShader {
 Tags { "Queue"="Transparent" "RenderType"="Transparent" }
 Cull Off ZWrite Off Blend SrcAlpha OneMinusSrcAlpha
 Pass {
 CGPROGRAM
 #pragma vertex vert
 #pragma fragment frag
 #include "UnityCG.cginc"
 struct input { float4 vertex:POSITION; float2 uv:TEXCOORD0; float4 color:COLOR; };
 struct output { float4 position:SV_POSITION; float2 uv:TEXCOORD0; float4 color:COLOR; };
 fixed4 _Color;
 output vert(input v) { output o; o.position=UnityObjectToClipPos(v.vertex);o.uv=v.uv;o.color=v.color*_Color;return o; }
 fixed4 frag(output i):SV_Target {
 float across=abs(i.uv.y*2-1);
 float edge=pow(across,12);
 float flow=.5+.5*sin(i.uv.x*61-_Time.y*17+i.uv.y*12);
 float wisps=pow(.5+.5*sin(i.uv.y*38+i.uv.x*19-_Time.y*7),4);
 float breaks=smoothstep(.12,.7,.5+.5*sin(i.uv.x*27+sin(i.uv.y*13)-_Time.y*11));
 float3 c=lerp(i.color.rgb,float3(.48,1,.86),saturate(edge+wisps*.6));
 float alpha=i.color.a*(.42+wisps*.44+edge*.8)*(.65+.35*breaks);
 return float4(c,alpha);

 }
 ENDCG
 }
 }
}
