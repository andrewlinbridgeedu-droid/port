Shader "Mindstone/SpellImpact20260925/AuthoredNeedle"{
 Properties{_Art("Authored silver needle silk",2D)="white"{} _Age("After contact",Float)=0 _Flash("Needle tip flash",Float)=0}
 SubShader{Tags{"Queue"="Transparent+23" "RenderType"="Transparent"} Blend SrcAlpha OneMinusSrcAlpha ZWrite Off Cull Off
 Pass{CGPROGRAM
 #pragma vertex vert
 #pragma fragment frag
 #pragma target 3.0
 #include "UnityCG.cginc"
 sampler2D _Art;float _Age,_Flash;
 struct V{float4 vertex:POSITION;float2 uv:TEXCOORD0;float4 color:COLOR;};
 struct F{float4 pos:SV_POSITION;float2 uv:TEXCOORD0;float4 color:COLOR;float3 world:TEXCOORD1;};
 F vert(V v){F o;o.pos=UnityObjectToClipPos(v.vertex);o.uv=v.uv;o.color=v.color;o.world=mul(unity_ObjectToWorld,v.vertex).xyz;return o;}
 float4 frag(F i):SV_Target{
  if(i.uv.x<0)return i.color;
  float2 flow=i.uv+float2(sin(i.uv.y*18-_Age*11),cos(i.uv.x*17+_Age*7))*.009;
  float4 art=tex2D(_Art,flow);float luminance=dot(art.rgb,float3(.25,.56,.19));
  float3 n=normalize(cross(ddx(i.world),ddy(i.world)));float lighting=.75+.35*abs(dot(n,normalize(float3(-.4,.8,-.6))));
  float hot=smoothstep(.65,.95,luminance),silver=smoothstep(.32,.74,luminance);
  float3 color=art.rgb*i.color.rgb*lighting*(1.03+silver*.38);
  color+=float3(.58,.83,.95)*hot*(.56+_Flash*.75);
  // Retain embroidered crimson and dark navy fabric between silver highlights.
  float red=saturate((art.r-art.g)*3);color=lerp(color,art.rgb*float3(2.1,.66,.71),red*.85);
  float alpha=art.a*i.color.a;clip(alpha-.008);return float4(color,alpha);
 }
 ENDCG}
 }
}
