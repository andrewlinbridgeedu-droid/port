Shader "Mistport/TrialSurface" {
 Properties { _MainTex("Art",2D)="white"{} _Color("Tint",Color)=(1,1,1,1) _Gain("Radiance",Float)=1 _Opacity("Life",Float)=1 }
 SubShader { Tags {"Queue"="Transparent" "RenderType"="Transparent"} Blend One OneMinusSrcAlpha ZWrite Off Cull Off ZTest LEqual
 Pass { CGPROGRAM
 #pragma vertex vert
 #pragma fragment frag
 #include "UnityCG.cginc"
 sampler2D _MainTex; float4 _Color; float _Gain,_Opacity;
 struct a {float4 p:POSITION;float4 c:COLOR;float2 uv:TEXCOORD0;};
 struct v {float4 p:SV_POSITION;float4 c:COLOR;float2 uv:TEXCOORD0;};
 v vert(a i){v o;o.p=UnityObjectToClipPos(i.p);o.c=i.c*_Color;o.uv=i.uv;return o;}
 float4 frag(v i):SV_Target{float4 c=tex2D(_MainTex,i.uv)*i.c;float a=saturate(c.a*_Opacity);return float4(c.rgb*_Gain*a,a);}
 ENDCG }
 }
}
