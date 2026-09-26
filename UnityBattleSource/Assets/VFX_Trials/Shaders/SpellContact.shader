Shader "Mistport/SpellContact"
{
 Properties
 {
  _Age("Age",Float)=0 _Seed("Seed",Float)=0 _Ice("Ice",Float)=0
  _Core("Core",Float)=0 _MainTex("Authored internal detail",2D)="white"{} _UseArt("Has art",Float)=0
 }
 SubShader
 {
  Tags { "Queue"="Transparent+10" "RenderType"="Transparent" }
  Blend One One ZWrite Off Cull Off ZTest LEqual
  Pass
  {
   CGPROGRAM
   #pragma target 3.0
   #pragma vertex vert
   #pragma fragment frag
   #include "UnityCG.cginc"
   struct a {float4 p:POSITION;float2 uv:TEXCOORD0;};
   struct v {float4 p:SV_POSITION;float2 uv:TEXCOORD0;};
   float _Age,_Seed,_Ice,_Core,_UseArt;sampler2D _MainTex;
   v vert(a i){v o;o.p=UnityObjectToClipPos(i.p);o.uv=i.uv;return o;}
   float4 frag(v i):SV_Target
   {
    float2 p=(i.uv-.5)*2;
    float3 art=tex2D(_MainTex,float2(.16+i.uv.x*.68,.12+i.uv.y*.72)).rgb;
    float grain=lerp(.45,dot(art,float3(.2,.65,.15)),_UseArt);
    float fade=1-smoothstep(.035,.30,_Age);
    float density,core;
    if(_Core>.5)
    {
     p+=float2(sin(p.y*6.1+_Seed),sin(p.x*8.7-_Seed))*.047;
     float r=length(p),angle=atan2(p.y,p.x);
     float contour=1+.22*sin(angle*3+_Seed)+.12*sin(angle*7-.7);
     core=exp(-dot(p,p)*24);
     density=pow(saturate(1-r*contour),3)*(.48+grain*.34)+core;
     // Break up the outside after the peak, retaining a legible compact contact point.
     float tear=.35+.32*sin(p.x*19+p.y*13+grain*4)+grain*.32;
     density*=smoothstep(saturate((_Age-.09)*5)-.16,saturate((_Age-.09)*5)+.12,tear);
    }
    else
    {
     float tip=pow(saturate(sin(i.uv.x*3.14159)),.8);
     float filament=exp(-abs(p.y+sin(i.uv.x*12+grain*3)*.15)*lerp(4.8,9,_Ice));
     float flow=.58+.42*sin(i.uv.x*17-_Age*39+grain*4+_Seed);
     core=filament*pow(saturate(flow),6);
     density=tip*(filament*.52+core*.34)*(.55+grain*.45);
     density*=smoothstep(.018,.045,_Age);
     density*=1-smoothstep(.07,.30,_Age+i.uv.x*.02);
    }
    float3 gold=lerp(float3(.85,.12,.018),float3(1.55,1.10,.49),core);
    float3 blue=lerp(float3(.035,.29,.90),float3(.68,1.15,1.5),core);
    float3 color=lerp(gold,blue,_Ice);
    return float4(color*density*fade,0);
   }
   ENDCG
  }
 }
}
