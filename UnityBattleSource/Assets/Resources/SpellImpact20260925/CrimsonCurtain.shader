Shader "Mistport/ImpactGrade/CrimsonCurtain" {
 Properties { _Color("Color",Color)=(1,1,1,1) _MainTex("Authored silk",2D)="white"{} _Clock("Clock",Float)=0 _Seed("Seed",Float)=0 _Lucent("Inner translucency",Float)=1 _Flare("Contact inner light",Float)=0 }
 SubShader { Tags { "Queue"="Transparent+17" "RenderType"="Transparent" } Blend SrcAlpha OneMinusSrcAlpha Cull Off ZWrite Off
 Pass { CGPROGRAM
 #pragma vertex vert
 #pragma fragment frag
 #include "UnityCG.cginc"
 struct appdata {float4 vertex:POSITION;float3 normal:NORMAL;float2 uv:TEXCOORD0;};
 struct v2f {float4 pos:SV_POSITION;float2 uv:TEXCOORD0;float3 normal:TEXCOORD1;};
 float4 _Color;float _Clock,_Seed,_Lucent,_Flare;sampler2D _MainTex;
 v2f vert(appdata v){v2f o;o.pos=UnityObjectToClipPos(v.vertex);o.uv=v.uv;o.normal=UnityObjectToWorldNormal(v.normal);return o;}
 float4 frag(v2f i):SV_Target {
  float x=i.uv.y*2-1,y=i.uv.x;
  float2 artUV=float2(.20+y*.55+x*.20,.12+y*.76-x*.23);
  artUV+=float2(sin(y*11+_Clock*3),cos(y*7-_Clock*5))*.009;
  float4 art=tex2D(_MainTex,artUV);
  float edge=smoothstep(0,.08,y)*smoothstep(0,.10,1-y)*smoothstep(0,.20,.94+.06*sin(y*23+_Seed)-abs(x));
  float shade=.40+.60*abs(dot(normalize(i.normal),normalize(float3(.4,.8,-.6))));
  float hot=smoothstep(.39,.9,art.r)*(.18+_Flare*.45);
  float3 col=art.rgb*float3(1.62,.95,1.28)*(.80+shade*.38)+float3(.48,.013,.12)*(.55+shade*.45)+float3(1.2,.52,.65)*hot;
  col+=float3(.12,.01,.17)*(1-art.a)*.35;
  col+=float3(1.12,.48,.67)*max(0,_Lucent-1.3)*2.4*(.6+_Flare*.4);
  return float4(col,_Color.a*edge*saturate(.56+art.r*.64));
 }
 ENDCG }} }
