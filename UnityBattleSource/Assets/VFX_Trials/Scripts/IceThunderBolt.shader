Shader "Mistport/IceThunderBolt"
{
 Properties
 {
  _MainTex("Crystal filaments",2D)="white"{} _Color("Color",Color)=(1,1,1,1)
  _Gain("Gain",Float)=1 _Opacity("Opacity",Float)=1 _Head("Head",Float)=0 _Phase("Phase",Float)=0
 }
 SubShader
 {
  Tags { "Queue"="Transparent" "RenderType"="Transparent" }
  Blend One OneMinusSrcAlpha ZWrite Off Cull Off ZTest LEqual
  Pass
  {
   CGPROGRAM
   #pragma target 3.0
   #pragma vertex vert
   #pragma fragment frag
   #include "UnityCG.cginc"
   sampler2D _MainTex;float4 _Color;float _Gain,_Opacity,_Head,_Phase;
   struct a {float4 p:POSITION;float3 n:NORMAL;float2 uv:TEXCOORD0;};
   struct v {float4 p:SV_POSITION;float3 n:TEXCOORD1;float3 eye:TEXCOORD2;float2 uv:TEXCOORD0;};
   v vert(a i)
   {
    v o;
    // A short discharge travels through the branch volume; the ground endpoint stays fixed.
    float age=max(0,_Phase-.5);
    float pulse=(1-exp(-age*80))*exp(-age*13);
    float envelope=sin(saturate(i.uv.y)*3.14159);
    i.p.x+=sin(i.uv.y*19+_Phase*6)*envelope*(.012+pulse*.035);
    i.p.z+=sin(i.uv.y*27-_Phase*8)*envelope*(.012+pulse*.07);
    o.p=UnityObjectToClipPos(i.p);o.n=UnityObjectToWorldNormal(i.n);
    o.eye=WorldSpaceViewDir(i.p);o.uv=i.uv;return o;
   }
   float4 frag(v i):SV_Target
   {
    float reveal=1-smoothstep(_Head-.012,_Head+.012,i.uv.y);
    float facing=saturate(abs(dot(normalize(i.n),normalize(i.eye))));
    float soft=pow(facing,1.6);
    float2 uv=float2(.2+i.uv.x*.57,frac(i.uv.y*2.4-_Phase*.42)*.58+.2);
    float3 tex=tex2D(_MainTex,uv).rgb;
    float veins=smoothstep(.35,.85,tex.g);
    float flow=.5+.5*sin(i.uv.y*37-_Phase*25+tex.b*2);
    float density=.32+veins*.52+flow*.16;
    float age=max(0,_Phase-.5);
    float surge=(1-exp(-age*80))*exp(-age*13);
    float fracture=smoothstep(.64,.97,_Phase);
    float broken=smoothstep(fracture*.8-.08,fracture*.8+.08,.22+veins*.58+flow*.20);
    float alpha=reveal*_Opacity*_Color.a*soft*density*broken;
    float filament=pow(saturate(flow),10)*veins;
    float3 col=_Color.rgb*_Gain*(.72+veins*.4+filament*.22+surge*.12);
    return float4(col*alpha,alpha);
   }
   ENDCG
  }
 }
}
