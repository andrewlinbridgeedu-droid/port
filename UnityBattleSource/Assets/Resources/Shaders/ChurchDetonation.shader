Shader "Mistport/ChurchDetonation" {
 Properties {_Color("Color",Color)=(1,.3,.1,1) _Age("Age",Float)=0 _Gather("Gather",Float)=0}
 SubShader {Tags{"Queue"="Transparent+20"} Blend SrcAlpha One ZWrite Off Cull Off
 Pass {CGPROGRAM
 #pragma vertex vert
 #pragma fragment frag
 #include "UnityCG.cginc"
 struct A{float4 vertex:POSITION;float2 uv:TEXCOORD0;};struct V{float4 pos:SV_POSITION;float2 uv:TEXCOORD0;};float4 _Color;float _Age,_Gather;
 V vert(A v){V o;o.pos=UnityObjectToClipPos(v.vertex);o.uv=v.uv;return o;}
 float hash(float2 p){return frac(sin(dot(p,float2(127.1,311.7)))*43758.5453);}
 float noise(float2 p){float2 i=floor(p),f=frac(p);f=f*f*(3-2*f);return lerp(lerp(hash(i),hash(i+float2(1,0)),f.x),lerp(hash(i+float2(0,1)),hash(i+1),f.x),f.y);}
 float fbm(float2 p){return noise(p)*.55+noise(p*2.07+17)*.28+noise(p*4.1-9)*.12+noise(p*8.2)*.05;}
 float4 frag(V i):SV_Target{
  float t=max(0,_Age);float2 p=(i.uv-.5)*2;
  float2 warp=float2(fbm(p*3+float2(t*1.8,-t*1.1)),fbm(p*3+float2(-t*.8,t*1.4)+31))-.5;
  float2 q=p+warp*.48;float r=length(q);
  float fog=fbm(q*5+float2(t*.7,-t*2));
  float reach=lerp(.24+.52*(1-exp(-t*9)),.58+sin(t*7)*.045,_Gather);
  float density=saturate((reach-r+fog*.26)*4.2);
  float threads=pow(saturate(1-abs(fbm(q*9+warp*3-t)-.52)*15),3);
  float lumps=fbm(p*7+warp*4+float2(-t*2,t));
  float core=pow(density,3)*(.35+.65*lumps);
  float flame=density*(.22+threads*.78)*smoothstep(.24,.65,fog);
  float life=lerp(saturate(1-t/.70),1,_Gather);
  float alpha=saturate(flame+core*.5)*life*(1-smoothstep(.78,1,length(p)))*_Color.a;
  float3 rgb=lerp(_Color.rgb,float3(1,.89,.69),core*.18+threads*.06);
  return float4(rgb*1.35,alpha*.52);
 }
 ENDCG}
 }
}
