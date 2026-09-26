Shader "Mistport/ChurchFragments" {
 Properties {_MainTex("Art",2D)="white"{} _Organic("Organic",Float)=0 _Recolor("Use fragment hue",Float)=0}
 SubShader {Tags{"Queue"="Transparent+21"} Blend SrcAlpha OneMinusSrcAlpha ZWrite Off Cull Off
 Pass{CGPROGRAM
 #pragma vertex vert
 #pragma fragment frag
 #include "UnityCG.cginc"
 struct A{float4 vertex:POSITION;float2 uv:TEXCOORD0;float2 local:TEXCOORD1;float4 color:COLOR;};struct V{float4 pos:SV_POSITION;float2 uv:TEXCOORD0;float2 local:TEXCOORD1;float4 color:COLOR;};sampler2D _MainTex;float _Organic,_Recolor;
 V vert(A v){V o;o.pos=UnityObjectToClipPos(v.vertex);o.uv=v.uv;o.color=v.color;o.local=v.local;return o;}
 float4 frag(V i):SV_Target{float2 q=(i.local-.5)*2;float boundary=lerp(abs(q.x)*.9+abs(q.y)*.65+.13*sin(q.y*17),length(q)*.95,_Organic);float mask=1-smoothstep(.70,.95,boundary);float4 ink=tex2D(_MainTex,i.uv);float mono=max(ink.r,max(ink.g,ink.b));ink.rgb=lerp(ink.rgb,float3(mono,mono,mono),_Recolor);float4 c=ink*i.color;c.a*=mask;return c;}
 ENDCG}
 }
}
