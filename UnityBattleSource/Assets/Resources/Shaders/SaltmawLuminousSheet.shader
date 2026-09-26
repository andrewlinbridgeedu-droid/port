Shader "Mistport/SaltmawLuminousSheet" {
 Properties { _Color("Tint",Color)=(1,1,1,1) }
 SubShader { Tags {"Queue"="Transparent"} Blend SrcAlpha One ZWrite Off Cull Off
 Pass { CGPROGRAM
 #pragma vertex vert
 #pragma fragment frag
 #include "UnityCG.cginc"
 struct A {float4 vertex:POSITION;float2 uv:TEXCOORD0;float4 color:COLOR;};
 struct V {float4 pos:SV_POSITION;float2 uv:TEXCOORD0;float4 color:COLOR;};
 V vert(A v){V o;o.pos=UnityObjectToClipPos(v.vertex);o.uv=v.uv;o.color=v.color;return o;}
 float4 frag(V i):SV_Target {
 float edge=pow(saturate(1-abs(i.uv.y*2-1)),.6);
 float flow=sin(i.uv.x*55+sin(i.uv.y*21)*2-_Time.y*18);
 float vein=pow(saturate(flow),10);
 float core=exp(-pow((i.uv.y-.5)*6,2));
 float3 color=lerp(i.color.rgb,float3(1.7,1.65,1.3),core*.28+vein*.18);
 return float4(color*(1+vein*.35),i.color.a*edge*(.75+.25*vein));
 }
 ENDCG }
 }
}
