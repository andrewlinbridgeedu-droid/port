Shader "Mistport/IronclawRadiance" {
 Properties { _Color("Color",Color)=(1,.9,.6,1) _Age("Age",Float)=0 }
 SubShader { Tags {"Queue"="Transparent+22"} Blend SrcAlpha One ZWrite Off Cull Off
 Pass { CGPROGRAM
 #pragma vertex vert
 #pragma fragment frag
 #include "UnityCG.cginc"
 struct A {float4 vertex:POSITION;float2 uv:TEXCOORD0;};
 struct V {float4 pos:SV_POSITION;float2 uv:TEXCOORD0;};
 float4 _Color; float _Age;
 V vert(A v){V o;o.pos=UnityObjectToClipPos(v.vertex);o.uv=v.uv;return o;}
 float4 frag(V i):SV_Target {
  float2 p=(i.uv-.5)*2;float r=length(p);float a=atan2(p.y,p.x);
  float curl=sin(a*7+r*19-_Age*11)*sin(a*3-r*13+_Age*6);
  float core=exp(-r*r*95);
  float halo=exp(-r*r*8)*(.32+.12*curl);
  float rays=pow(saturate(sin(a*5+sin(a*3+_Age)*.45)),20)*exp(-r*5)*smoothstep(.06,.16,r);
  float edge=1-smoothstep(.65,1,r);
  float energy=(core*.8+halo+rays*.4)*edge;
  return float4(lerp(_Color.rgb,float3(1,1,.93),core)*1.45,energy*_Color.a);
 }
 ENDCG }
 }
}
