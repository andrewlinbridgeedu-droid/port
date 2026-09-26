Shader "MistHarbor/ArchiveAegis" {
Properties { _MainTex("Interior silver engraving",2D)="white"{} _DstBlend("Blend",Float)=10 _ShimmerTime("Shimmer time",Float)=0 _DeployPulse("Opening impulse",Float)=0 }
SubShader { Tags {"Queue"="Transparent+14" "RenderType"="Transparent"} ZWrite Off Cull Off Blend SrcAlpha OneMinusSrcAlpha
Pass { CGPROGRAM
#pragma target 3.0
#pragma vertex vert
#pragma fragment frag
#include "UnityCG.cginc"
sampler2D _MainTex; float _ShimmerTime,_DeployPulse;
struct a {float4 vertex:POSITION;float2 uv:TEXCOORD0;float4 color:COLOR;};
struct v {float4 pos:SV_POSITION;float2 uv:TEXCOORD0;float4 color:COLOR;};
v vert(a i){v o;o.pos=UnityObjectToClipPos(i.vertex);o.uv=i.uv;o.color=i.color;return o;}
float4 frag(v i):SV_Target {
 float x=i.uv.x*2-1,y=i.uv.y;
 // Crop, bend and offset interior details on each physical fold. Texture alpha
 // cannot redraw the old complete circular frame or its four decorative tips.
 float2 sampleUV=float2(.28+y*.39+x*.15,.23+y*.54-x*.13)+(i.color.r-.9)*1.8;
 float4 paint=tex2D(_MainTex,sampleUV);
 float ink=saturate(dot(paint.rgb,float3(.25,.46,.29)))*paint.a;
 float gold=saturate((paint.r-paint.b*.62)*2.2)*paint.a;
 float fold=.18*sin(y*5.2+i.color.r*9)+.10*sin(y*11.4-i.color.r*4);
 float core=exp(-pow((x-fold)/.18,2))*(.30+.70*ink);
 float3 body=lerp(float3(.025,.07,.27),float3(.12,.48,.96),saturate(ink*.88+core*.24));
 body+=float3(.40,.77,1.0)*core*(.24+.53*_DeployPulse);
 body+=float3(.72,.87,1.0)*ink*.42;
 body+=float3(.96,.69,.28)*gold*(.20+.45*_DeployPulse);
 float sweep=exp(-pow((y-frac(_ShimmerTime*.23+i.color.r))/.07,2));
 body+=float3(.14,.49,.92)*sweep*ink*.25;
 float edge=smoothstep(0,.11,1-abs(x))*smoothstep(0,.025,y)*smoothstep(0,.04,1-y);
 float alpha=edge*i.color.a*(.60+.17*ink+.13*core+.10*_DeployPulse);
 clip(alpha-.003);return float4(body*i.color.rgb,alpha);
}
ENDCG
}}}
