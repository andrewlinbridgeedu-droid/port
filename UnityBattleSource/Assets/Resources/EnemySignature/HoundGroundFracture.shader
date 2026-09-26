Shader "MistHarbor/HoundGroundFracture"
{
 Properties {
  _MainTex("Authored transparent ground",2D)="black"{}
  _Opacity("Opacity",Range(0,1))=1 _Glow("Local lava movement",Float)=1
  _Wave("Continuous fault",Float)=0 _Reveal("Fault front V",Range(0,1))=1
  _Open("Crater opening",Range(0,1))=1 _Age("Spell age",Float)=0 _Rock("Stone chip",Float)=0
 }
 SubShader {
  Tags {"Queue"="Transparent-18" "RenderType"="Transparent"}
  Pass {
   Cull Off ZWrite Off ZTest LEqual Blend SrcAlpha OneMinusSrcAlpha
   CGPROGRAM
   #pragma vertex vert
   #pragma fragment frag
   #include "UnityCG.cginc"
   sampler2D _MainTex;
   float _Opacity,_Glow,_Wave,_Reveal,_Open,_Age,_Rock;
   struct appdata{float4 vertex:POSITION;float3 normal:NORMAL;float2 uv:TEXCOORD0;};
   struct v2f{float4 pos:SV_POSITION;float3 normal:TEXCOORD0;float2 uv:TEXCOORD1;};
   v2f vert(appdata v){v2f o;o.pos=UnityObjectToClipPos(v.vertex);o.normal=UnityObjectToWorldNormal(v.normal);o.uv=v.uv;return o;}
   float hash(float2 p){return frac(sin(dot(p,float2(127.1,311.7)))*43758.5453);}
   float sootNoise(float2 p){float2 a=floor(p),f=frac(p);f=f*f*(3-2*f);return lerp(lerp(hash(a),hash(a+float2(1,0)),f.x),lerp(hash(a+float2(0,1)),hash(a+1),f.x),f.y);}
   float4 frag(v2f i):SV_Target{
    if(_Rock>.5){float light=.45+.55*abs(dot(normalize(i.normal),normalize(float3(-.4,1,.3))));return float4(float3(.31,.27,.225)*light,_Opacity);}
    if(_Wave>.5){
     float2 q=(i.uv-.5)*2;
     float grain=sootNoise(q*13)*.6+sootNoise(q*31)*.4;
     float radial=length(q)+ (sootNoise(q*7)-.5)*.17;
     float soot=(1-smoothstep(.42,.88,radial))*(.60+.4*grain)*_Reveal;
     return float4(float3(.045,.035,.028)*( .7+grain*.5),soot*_Opacity*.88);
    }
    float4 art=tex2D(_MainTex,i.uv);
    // Soft alpha is the source painting's edge, never a dithered cutout or a filled disk.
    float edge=smoothstep(0,.025,i.uv.x)*smoothstep(0,.025,1-i.uv.x)*smoothstep(0,.018,i.uv.y)*smoothstep(0,.018,1-i.uv.y);
    float reveal=1;
    if(_Wave>.5)reveal=(1-smoothstep(_Reveal-.028,_Reveal+.008,i.uv.y))*smoothstep(0,.018,_Reveal);
    float lava=smoothstep(.08,.35,art.r-max(art.g,art.b))*smoothstep(.16,.48,art.r);
    float flow=.78+.22*sin(i.uv.y*36-i.uv.x*13-_Age*7);
    float3 color=art.rgb+lava*float3(.40,.10,.008)*_Glow*flow;
    // The authored inward-facing walls darken as the crater collapses, leaving the rim's paint intact.
    float cavity=(1-smoothstep(.06,.27,length((i.uv-.5)*float2(1,1.2))))*(1-lava);
    color*=1-cavity*.24*_Open;
    color=lerp(color,color*.24,saturate((_Age-1)*.8));
    return float4(color,art.a*_Opacity*edge*reveal);
   }
   ENDCG
  }
 }
}
