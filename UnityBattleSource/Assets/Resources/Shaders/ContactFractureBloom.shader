Shader "Mistport/ContactFractureBloom" {
 Properties {_Color("Tint",Color)=(.3,.8,1,1) _Age("Contact age",Float)=0}
 SubShader {Tags{"Queue"="Transparent+21"} Blend SrcAlpha One ZWrite Off Cull Off
 Pass {CGPROGRAM
 #pragma vertex vert
 #pragma fragment frag
 #include "UnityCG.cginc"
 struct A{float4 vertex:POSITION;float2 uv:TEXCOORD0;};struct V{float4 p:SV_POSITION;float2 uv:TEXCOORD0;};float4 _Color;float _Age;
 V vert(A v){V o;o.p=UnityObjectToClipPos(v.vertex);o.uv=v.uv;return o;}
 float4 frag(V i):SV_Target{float2 p=(i.uv-.5)*2;float r=length(p),a=atan2(p.y,p.x);float t=max(0,_Age);float grow=1-exp(-t*19);float lobe=pow(saturate(.5+.5*sin(a*5+sin(a*3)*1.4)),3);float front=.09+grow*(.26+lobe*.34);float torn=sin(p.x*43+sin(p.y*31)*2-t*8)*sin(p.y*37-p.x*9);float body=exp(-pow((r-front)/(.10+lobe*.11),2));float core=exp(-r*r*65)*exp(-t*20);float cut=saturate(.63+torn*.40);float alpha=(body*cut*exp(-t*5)+core)*saturate(1-r);float hot=pow(saturate(torn),5);return float4(lerp(_Color.rgb*2,float3(2.3,2.1,1.7),core*.6+hot*.28),alpha*.9);}
 ENDCG}
 }
}
