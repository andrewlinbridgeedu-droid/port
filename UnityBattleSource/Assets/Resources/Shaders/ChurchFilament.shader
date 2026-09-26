Shader "Mistport/ChurchFilament" {
 Properties{_MainTex("Texture",2D)="white"{} _Color("Tint",Color)=(1,1,1,1) _Luma("Luminance alpha",Float)=1 _Dissolve("Dissolve",Range(0,1))=0 _Dst("Destination",Float)=1 _Ribbon("Ribbon",Float)=0}
 SubShader{Tags{"Queue"="Transparent+18" "RenderType"="Transparent"} Blend SrcAlpha [_Dst] ZWrite Off Cull Off
 Pass{CGPROGRAM
 #pragma vertex vert
 #pragma fragment frag
 #include "UnityCG.cginc"
 struct appdata{float4 vertex:POSITION;float2 uv:TEXCOORD0;};struct v2f{float4 pos:SV_POSITION;float2 uv:TEXCOORD0;};sampler2D _MainTex;float4 _Color;float _Luma,_Dissolve,_Ribbon;
 v2f vert(appdata v){v2f o;o.pos=UnityObjectToClipPos(v.vertex);o.uv=v.uv;return o;}
 float4 frag(v2f i):SV_Target{if(_Ribbon>.5){float core=pow(saturate(1-abs(i.uv.x*2-1)),3);float tail=pow(saturate(sin(i.uv.y*3.1415926)),.5);return float4(_Color.rgb,_Color.a*core*tail);}
 float4 t=tex2D(_MainTex,i.uv);float m=lerp(1,max(t.r,max(t.g,t.b)),_Luma);float edge=smoothstep(_Dissolve*.9,_Dissolve*.9+.12,m);return float4(t.rgb*_Color.rgb,t.a*m*_Color.a*edge);}
 ENDCG}
 }
}
