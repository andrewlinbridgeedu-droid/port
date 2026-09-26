Shader "Mistport/BindingRibbon20260921" {
 Properties { _MainTex("Authored gold openwork",2D)="black"{} _Age("Time",Float)=0 _Fade("Fade",Float)=1 _Pulse("Contact light",Float)=0 }
 SubShader {
  Tags {"Queue"="Transparent" "RenderType"="Transparent"}
  Cull Off ZWrite Off ZTest LEqual
  CGINCLUDE
  #include "UnityCG.cginc"
  sampler2D _MainTex;float _Age,_Fade,_Pulse;
  struct Input{float4 vertex:POSITION;float2 uv:TEXCOORD0;float3 normal:NORMAL;float4 color:COLOR;};
  struct Interpolator{float4 pos:SV_POSITION;float2 uv:TEXCOORD0;float3 normal:TEXCOORD1;float4 color:COLOR;};
  Interpolator vert(Input i){Interpolator o;o.pos=UnityObjectToClipPos(i.vertex);o.uv=i.uv;o.normal=UnityObjectToWorldNormal(i.normal);o.color=i.color;return o;}
  float4 artwork(float2 uv){return tex2D(_MainTex,float2(.01+uv.x*.98,.1+uv.y*.8));}
  float edge(float2 uv){return smoothstep(0,.018,uv.x)*(1-smoothstep(.98,1,uv.x));}
  float mask(float4 tex){return smoothstep(.62,.91,tex.r)*smoothstep(.37,.73,tex.g)*tex.a;}
  float fineHalo(float2 uv){
   float2 p=float2(.01+uv.x*.98,.1+uv.y*.8);
   float a=tex2D(_MainTex,p+float2(0,.012)).r;
   float b=tex2D(_MainTex,p-float2(0,.012)).r;
   return smoothstep(.24,.70,max(a,b))*.24;
  }
  float flow(float2 uv){return pow(saturate(.5+.5*sin(uv.x*18-_Age*3.8)),10);}
  ENDCG
  Pass {
   Blend SrcAlpha OneMinusSrcAlpha
   CGPROGRAM
   #pragma vertex vert
   #pragma fragment frag
   float4 frag(Interpolator i):SV_Target{
    float4 tex=artwork(i.uv);float body=mask(tex);
    float facing=.72+.28*abs(dot(normalize(i.normal),float3(.2,.4,-.88)));
    float3 gold=lerp(float3(.70,.30,.055),float3(1.18,.95,.58),saturate((tex.g-.38)*1.5));
    return float4(gold*facing*i.color.rgb,(body+fineHalo(i.uv))*edge(i.uv)*_Fade*i.color.a);
   }
   ENDCG
  }
  Pass {
   Blend SrcAlpha One
   CGPROGRAM
   #pragma vertex vert
   #pragma fragment frag
   float4 frag(Interpolator i):SV_Target{
    float4 tex=artwork(i.uv);float body=mask(tex);float travel=flow(i.uv);
    float fine=pow(saturate(sin(i.uv.x*177+sin(i.uv.y*27)*2-_Age*8.5)),22);
    float gleam=fine*smoothstep(.79,.98,tex.g)*(.35+.65*travel);
    float luminous=body*(.44+travel*1.10+_Pulse*.52)+gleam*.83;
    float halo=fineHalo(i.uv)*.54;
    float3 color=lerp(float3(1,.51,.09),float3(1.5,1.26,.65),saturate(tex.b+travel*.4));
    return float4(color*i.color.rgb,(luminous+halo)*edge(i.uv)*_Fade*i.color.a);
   }
   ENDCG
  }
 }
}
