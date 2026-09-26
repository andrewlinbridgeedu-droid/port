Shader "Mistport/RiftImpact"
{
 Properties { _Age("Age",Float)=0 _Seed("Seed",Float)=0 }
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
   float _Age,_Seed;
   v vert(a i){v o;o.p=UnityObjectToClipPos(i.p);o.uv=i.uv;return o;}
   float4 frag(v i):SV_Target
   {
    // Keep the recorder-owned .84 contact/.055 expansion/.32 life.
    // Retraction happens inside the carrier, without moving the real target or changing callbacks.
    float retract=lerp(1,.30,smoothstep(.055,.28,_Age));
    float2 p=(i.uv-.5)*2/max(.01,retract);
    p.x+=sin(p.y*4.7+_Seed)*p.y*.10;
    p.y+=sin(p.x*5.3-_Seed)*.045;
    float r=length(p),angle=atan2(p.y,p.x);
    float contour=1+.21*sin(angle*3+_Seed)+.105*sin(angle*7-.9)+.04*sin(angle*11+1.3);
    float core=exp(-dot(p,p)*18);
    float grain=.56+.22*sin(p.x*19+p.y*11-_Age*18+_Seed)+.14*sin(p.y*31-p.x*7);
    float plume=pow(saturate(1-r*contour),3)*(.60+grain*.48);
    float fade=1-smoothstep(.035,.30,_Age);
    float3 color=lerp(float3(1,.12,.008),float3(1.8,1.35,.60),core);
    float alpha=(plume*.8+core)*fade;
    return float4(color*alpha,0);
   }
   ENDCG
  }
 }
}
