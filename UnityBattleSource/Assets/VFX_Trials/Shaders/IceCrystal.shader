Shader "Mistport/IceCrystalTrial"
{
 Properties
 {
  _MainTex("Ice veins",2D)="white"{} _Opacity("Life",Float)=1
  _Color("Tint",Color)=(1,1,1,1) _Gain("Gain",Float)=1
  _Phase("Sample time",Float)=0 _Seed("Facet variation",Float)=0 _Ground("Ice flower",Float)=0
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
   sampler2D _MainTex;
   float _Opacity,_Gain,_Phase,_Seed,_Ground; float4 _Color;
   struct a {float4 p:POSITION;float3 n:NORMAL;float4 c:COLOR;float2 uv:TEXCOORD0;};
   struct v {float4 p:SV_POSITION;float3 n:TEXCOORD1;float3 local:TEXCOORD0;float3 eye:TEXCOORD2;float4 c:COLOR;float2 uv:TEXCOORD3;};
   v vert(a i)
   {
    v o;
    if(_Ground>.5)
    {
     float age=max(0,_Phase-.5);
     float open=saturate(age/.05)*exp(-age*6);
     float taper=sin(saturate(i.uv.x)*3.14159)*sin(saturate(i.uv.y)*3.14159);
     i.p.y+=taper*open*(.045+.018*sin(i.uv.x*11+i.uv.y*17));
    }
    o.p=UnityObjectToClipPos(i.p);o.n=UnityObjectToWorldNormal(i.n);o.local=i.p.xyz;
    o.eye=WorldSpaceViewDir(i.p);o.c=i.c;o.uv=i.uv;return o;
   }
   float4 frag(v i):SV_Target
   {
    if(_Ground>.5)
    {
     float2 uv=i.uv;
     float4 art=tex2D(_MainTex,uv);
     float detail=tex2D(_MainTex,uv*.79+.07).g;
     float age=max(0,_Phase-.5);
     float erosion=smoothstep(.12,.45,age);
     float torn=smoothstep(erosion-.12,erosion+.12,.24+detail*.65);
     float edge=smoothstep(0,.08,uv.x)*(1-smoothstep(.92,1,uv.x));
     edge*=smoothstep(0,.07,uv.y)*(1-smoothstep(.93,1,uv.y));
     float alpha=art.a*_Opacity*edge*torn;
     float3 col=art.rgb*float3(.45,.83,1.05)*(.65+detail*.42);
     return float4(col*alpha,alpha);
    }
    float3 n=normalize(i.n),eye=normalize(i.eye);
    float2 uv=float2(i.local.x*.23+.5,i.local.y*.52+.14);
    // Two internal depths slide by different amounts across a fixed, faceted exterior.
    float3 tex=tex2D(_MainTex,uv+float2(eye.x*.018,0)).rgb;
    float3 deep=tex2D(_MainTex,uv*.83+float2(.06,-_Phase*.025+_Seed*.003)).rgb;
    float vein=smoothstep(.52,.94,tex.g)*.58;
    float facing=abs(dot(n,eye)),fres=pow(1-facing,3);
    float light=.4+.6*abs(dot(n,normalize(float3(-.4,.7,-.6))));
    float3 base=lerp(float3(.018,.075,.21),float3(.22,.52,.72),light);
    base*=.78+i.c.rgb*.32;
    float packet=pow(saturate(sin(i.local.y*8-_Phase*7+deep.g*4+_Seed)),14);
    float3 col=base+float3(.25,.58,.78)*vein+float3(.10,.24,.34)*deep.g;
    col+=float3(.46,.75,.88)*fres*.5+float3(.65,.88,1)*packet*vein*.55;
    float alpha=_Opacity*(.71+fres*.18);
    return float4(col*_Color.rgb*_Gain*alpha,alpha);
   }
   ENDCG
  }
 }
}
