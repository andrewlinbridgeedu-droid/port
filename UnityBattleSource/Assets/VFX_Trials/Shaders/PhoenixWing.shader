Shader "Mistport/PhoenixWingTrial"
{
 Properties
 {
  _MainTex("Gold vein source",2D)="white"{}
  _Erode("Dissolve",Float)=0 _Flash("Impact",Float)=0
  _FxTime("Sample time",Float)=0 _Opacity("Life",Float)=1 _Layer("Fold layer",Float)=0
 }
 SubShader
 {
  Tags { "Queue"="Transparent+1" "RenderType"="Transparent" }
  Blend One OneMinusSrcAlpha ZWrite Off Cull Off ZTest LEqual
  Pass
  {
   CGPROGRAM
   #pragma target 3.0
   #pragma vertex vert
   #pragma fragment frag
   #include "UnityCG.cginc"
   sampler2D _MainTex;
   float _Erode,_Flash,_FxTime,_Opacity,_Layer;
   struct a { float4 p:POSITION; float2 uv:TEXCOORD0; float4 c:COLOR; };
   struct v { float4 p:SV_POSITION; float2 uv:TEXCOORD0; float3 world:TEXCOORD1; float alpha:TEXCOORD2; };
   v vert(a i) { v o; o.world=mul(unity_ObjectToWorld,i.p).xyz; o.p=UnityObjectToClipPos(i.p); o.uv=i.uv; o.alpha=i.c.a; return o; }
   float3 rainbow(float h) { return saturate(abs(frac(h+float3(0,.666667,.333333))*6-3)-1); }
   float4 frag(v i):SV_Target
   {
    float u=i.uv.x,w=i.uv.y;
    float bend=sin(w*5.3+u*8.7-_FxTime*2.7)*.013;
    float2 artUV=float2(.04+u*.92+bend,.06+w*.87);
    float4 ink=tex2D(_MainTex,artUV);
    float lum=dot(ink.rgb,float3(.25,.55,.2));
    float veins=smoothstep(.035,.21,ink.r-ink.b)*smoothstep(.42,.85,ink.g);
    float fine=tex2D(_MainTex,float2(.12+u*.73+bend,w*.6+.2)).g;
    float grain=.5+.24*sin(u*71+w*36+sin(w*47)*2)+.15*sin(u*139-w*93);
    float order=.28+grain*.24+fine*.29+(1-w)*.18;
    float dissolve=smoothstep(_Erode-.06,_Erode+.07,order);
    float edgeFire=saturate(1-abs(order-_Erode)*34)*step(.03,_Erode);
    float torn=.86+.065*sin(u*19.3+fine*2)+.032*sin(u*43.1+1.3);
    float edge=smoothstep(0,.12,u)*(1-smoothstep(.88,1,u));
    edge*=smoothstep(.012,.10,w)*(1-smoothstep(torn-.17,torn,w));
    float alpha=edge*_Opacity*dissolve*(.68+veins*.20)*i.alpha;
    float hueOffset=(_Layer>.5 && _Layer<3.5)?(_Layer-2)*.075:0;
    float3 spectral=rainbow(.55+u*.75+w*.06+hueOffset);
    float3 color=spectral*(.56+lum*.86)+.025;
    // Sparkle follows painted veins, with dark intervals between moving packets.
    float shimmer=pow(saturate(sin(w*15-_FxTime*13+u*4+fine*3)),12);
    color=lerp(color,float3(1,.72,.2),veins*.83);
    color+=float3(1,.80,.34)*(veins*(.17+shimmer*.64)+edgeFire*.65);
    float crease=pow(saturate(1-abs(w-(.60+.08*sin(u*8.1)))*12),4);
    color+=float3(1,.84,.48)*crease*(_Flash*.38+.10)*(.35+veins*.65);
    float3 n=cross(ddy(i.world),ddx(i.world));
    n*=rsqrt(max(dot(n,n),.0000001));
    color*=.68+.32*abs(dot(n,normalize(float3(.4,1,-.3))));
    if(_Layer>.5 && _Layer<3.5)
    {
     // A broad luminous interior belongs to each thick feather surface. This is not
     // an extra bare line, a fan rib, or a white sheet laid over the painted gold veins.
     float spine=.38+.14*sin(u*4.7+_Layer*1.4)+fine*.055;
     float brush=pow(saturate(1-abs(w-spine)/.24),1.6);
     float3 coreColor=lerp(spectral,float3(1.20,1.12,.94),.32);
     alpha*=.84+veins*.16;
     color+=coreColor*brush*(.42+_Flash*.46)*(1-veins*.48);
     color=lerp(color,color*.83+float3(.30,.19,.035),veins*.55);
    }
    if(_Layer>3.5)
    {
     color=lerp(float3(.75,.19,.04),float3(1.5,1.05,.34),saturate(veins+shimmer*.65));
     alpha*=.85;
    }
    return float4(color*alpha,alpha);
   }
   ENDCG
  }
 }
}
