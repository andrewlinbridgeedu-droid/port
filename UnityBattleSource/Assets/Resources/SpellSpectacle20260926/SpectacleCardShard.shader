// Card hit (2026-10-08): a tarot card slams onto the target, cracks along glowing seams,
// bursts into shards that fly apart and burn away, with sparks and a soft flash.
// uv: card uv (shards) or 0..1 quad (spark, flash)
// uv2.x: seam glow weight (1 on a crack edge, 0 at the shard centre and on the card's own
//        border, so the card never gets a ruled glowing frame); uv2.y: 0 shard, 1 spark, 2 flash
// uv3.x: crack glow 0..1; uv3.y: dissolve 0..1; colour.a: fade. Premultiplied output.
Shader "Mistport/Spectacle/CardShard20261008" {
 Properties {
  _MainTex("Card",2D)="white"{} _Noise("Noise",2D)="gray"{}
  _Rim("Seam",Color)=(1,.42,.86,1) _Hot("Hot",Color)=(1,.88,.98,1)
 }
 SubShader {
  Tags { "Queue"="Transparent+70" "RenderType"="Transparent" "IgnoreProjector"="True" }
  Blend One OneMinusSrcAlpha ZWrite Off Cull Off ZTest Always
  Pass { CGPROGRAM
  #pragma vertex vert
  #pragma fragment frag
  #include "UnityCG.cginc"
  sampler2D _MainTex,_Noise; float4 _Rim,_Hot;
  struct A { float4 vertex:POSITION; float4 color:COLOR; float2 uv:TEXCOORD0; float2 uv2:TEXCOORD1; float2 uv3:TEXCOORD2; };
  struct V { float4 pos:SV_POSITION; float4 color:COLOR; float2 uv:TEXCOORD0; float2 uv2:TEXCOORD1; float2 uv3:TEXCOORD2; };
  V vert(A i){ V o; o.pos=UnityObjectToClipPos(i.vertex); o.color=i.color; o.uv=i.uv; o.uv2=i.uv2; o.uv3=i.uv3; return o; }
  float4 frag(V i):SV_Target{
   float mode=i.uv2.y; float fade=i.color.a;
   if(mode<.5){
    float4 tex=tex2D(_MainTex,i.uv);
    float d=i.uv3.y;
    float n=tex2D(_Noise,i.uv*float2(1.7,2.6)+float2(.31,.17)).r;
    float keep=d<=.001?1:smoothstep(d-.02,d+.05,n);
    float burn=d<=.001?0:keep*(1-smoothstep(d+.05,d+.15,n));
    // Seams and the burning edge go with the shard as it dissolves (no hollow outlines).
    float seam=smoothstep(.66,1,i.uv2.x)*i.uv3.x*keep;
    float a=tex.a*keep*fade;
    // colour.rgb: the shard's own magenta glow once the card has burst.
    float3 c=(tex.rgb*(1+.3*i.uv3.x)+i.color.rgb)*a;
    c+=(_Rim.rgb*seam*1.9+_Hot.rgb*seam*seam*.35+_Rim.rgb*burn*2.4)*fade;
    return float4(c,saturate(a+(seam*.5+burn*.5)*fade));
   }
   float2 p=i.uv*2-1; float r2=dot(p,p);
   if(mode<1.5){
    float disc=exp(-r2*8);
    float cross=(exp(-abs(p.x)*22)*exp(-p.y*p.y*3)+exp(-abs(p.y)*22)*exp(-p.x*p.x*3))*.8;
    float v=(disc+cross)*fade;
    return float4(lerp(i.color.rgb,_Hot.rgb,saturate(disc*1.2))*v,saturate(v*.2));
   }
   float glow=exp(-r2*3.2)*fade;
   return float4(i.color.rgb*glow,glow*.18);
  }
  ENDCG }
 }
}
