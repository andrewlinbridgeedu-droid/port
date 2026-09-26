Shader "Mistport/ChurchSurge" {
 Properties {_Color("Primary",Color)=(1,.2,.5,1) _Accent("Inner",Color)=(.2,.5,1,1) _Age("Age",Float)=0}
 SubShader {Tags{"Queue"="Transparent+19"} Blend SrcAlpha OneMinusSrcAlpha ZWrite Off Cull Off
 Pass {CGPROGRAM
 #pragma vertex vert
 #pragma fragment frag
 #include "UnityCG.cginc"
 struct A{float4 vertex:POSITION;float2 uv:TEXCOORD0;};struct V{float4 pos:SV_POSITION;float2 uv:TEXCOORD0;};float4 _Color,_Accent;float _Age;
 V vert(A v){V o;o.pos=UnityObjectToClipPos(v.vertex);o.uv=v.uv;return o;}
 float4 frag(V i):SV_Target{
 float x=i.uv.x,y=i.uv.y,t=_Age;
 float wav=sin(y*16-t*9)*.04+sin(y*31+t*7)*.025;
 float side=abs((x+wav)*2-1);
 float feather=1-smoothstep(.80,1,side);
 float edge=smoothstep(.63,.90,side);
 float flow=sin(y*26-x*8-t*13)*.5+.5;
 float filigree=pow(saturate(sin(y*48+sin(x*19+y*11)*3-t*10)),16);
 float stripe=pow(saturate(cos(x*23-y*17+sin(y*21-t*6)*1.7)),10);
 float3 body=lerp(_Accent.rgb,_Color.rgb,saturate(x*.8+flow*.2));
 body=lerp(body,float3(1,.78,.27),edge*.85);
 body+=float3(.65,.73,.82)*(filigree*.20+stripe*.15);
 float ends=pow(saturate(sin(y*3.14159265)),.38);
 return float4(body,feather*ends*_Color.a);
 }
 ENDCG}
 }
}
