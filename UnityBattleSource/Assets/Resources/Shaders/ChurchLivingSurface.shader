Shader "Mistport/ChurchLivingSurface" {
 Properties {_MainTex("Art",2D)="white"{} _Color("Tint",Color)=(1,1,1,1) _Age("Age",Float)=0}
 SubShader {Tags{"Queue"="Transparent+19"} Blend SrcAlpha One ZWrite Off Cull Off
 Pass {CGPROGRAM
 #pragma vertex vert
 #pragma fragment frag
 #include "UnityCG.cginc"
 struct A{float4 vertex:POSITION;float2 uv:TEXCOORD0;};struct V{float4 pos:SV_POSITION;float2 uv:TEXCOORD0;};sampler2D _MainTex;float4 _Color;float _Age;
 V vert(A v){V o;o.pos=UnityObjectToClipPos(v.vertex);o.uv=v.uv;return o;}
 float4 frag(V i):SV_Target{
 float4 art=tex2D(_MainTex,i.uv);float2 p=i.uv*2-1;
 float v=sin(p.x*68+sin(p.y*33)*3+_Age*11)*sin(p.y*49-p.x*16-_Age*8);
 float vein=pow(saturate(v),12);float flow=pow(saturate(sin(length(p)*29-_Age*23+sin(atan2(p.y,p.x)*11))),8);
 float bright=max(art.r,max(art.g,art.b));float a=art.a*saturate(vein*.9+flow*bright*.75)*_Color.a;
 return float4(art.rgb*2.6+_Color.rgb*.42,a);
 }
 ENDCG}
 }
}
