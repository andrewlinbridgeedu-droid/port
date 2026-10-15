// Hand-drawn 2D strokes (2026-10-08). Cel bands as in the user's reference short
// (yao_vs_ting): a filled shape is coloured in four flat steps by its distance from the
// outline - a dark saturated outer band, a hot band, the body, a cream core - with a
// one-pixel anti-aliased step between them and a few bright brush streaks running along
// the stroke. uv.x: 0 at the outline, 1 on the core line; uv.y: 0 cel bands, 1 flat colour
// (colour.rgb), 2 soft alpha disc, 3 additive (colour.rgb * uv.x as the glow profile);
// uv.z: position along the stroke; uv.w: a per-shape seed. colour.a: fade.
// uv2.rgb: core (cream); uv2.w: side (-1 inner .. +1 outer, unused for now).
// uv3.rgb: band 2 (hot); uv4.rgb: outer (dark). The body colour is colour.rgb. Premultiplied.
Shader "Mistport/Spectacle/Ink20261008" {
 SubShader {
  Tags { "Queue"="Transparent+72" "RenderType"="Transparent" "IgnoreProjector"="True" }
  Blend One OneMinusSrcAlpha ZWrite Off Cull Off ZTest Always
  Pass { CGPROGRAM
  #pragma vertex vert
  #pragma fragment frag
  #pragma target 3.0
  #include "UnityCG.cginc"
  struct A { float4 vertex:POSITION; float4 color:COLOR; float4 uv:TEXCOORD0; float4 uv2:TEXCOORD1; float4 uv3:TEXCOORD2; float4 uv4:TEXCOORD3; };
  struct V { float4 pos:SV_POSITION; float4 color:COLOR; float4 uv:TEXCOORD0; float4 core:TEXCOORD1; float4 hot:TEXCOORD2; float4 outer:TEXCOORD3; };
  V vert(A i){ V o; o.pos=UnityObjectToClipPos(i.vertex); o.color=i.color; o.uv=i.uv; o.core=i.uv2; o.hot=i.uv3; o.outer=i.uv4; return o; }
  float hash2(float2 p){ return frac(sin(dot(p,float2(127.1,311.7)))*43758.5453); }
  float vnoise2(float2 p){ float2 i=floor(p), f=frac(p); f=f*f*(3-2*f);
   return lerp(lerp(hash2(i),hash2(i+float2(1,0)),f.x),lerp(hash2(i+float2(0,1)),hash2(i+float2(1,1)),f.x),f.y); }
  float fbm2(float2 p){ return vnoise2(p)*.55+vnoise2(p*2.07+3.1)*.3+vnoise2(p*4.13-1.7)*.15; }
  float4 frag(V i):SV_Target{
   float e=i.uv.x, mode=i.uv.y, along=i.uv.z, seed=i.uv.w, fade=i.color.a;
   // seed >= 2 flags a streaked stroke (2026-10-09, after the UE "通用特效材质" reference):
   // painted-looking streaks run along the stroke, scrolling, and its edges fray into wisps.
   float streaked=step(1.5,seed); seed=frac(seed);
   if(mode>2.5){
    // Additive: the vertex e is the brightness profile (glow 1 -> .32 -> 0, spikes 1).
    float v=saturate(e)*fade;
    return float4(i.color.rgb*v,0);
   }
   if(mode>1.5){
    float v=saturate(e)*fade;
    return float4(i.color.rgb*v,v);
   }
   if(mode>.5){
    return float4(i.color.rgb*fade,fade);
   }
   // Painterly rather than cartoon (2026-10-08, user: 有点卡通味道): the colour steps blend
   // over a band, their borders wander with flowing noise, fine bright filaments run
   // through the body, and the outline is soft so the shape glows into its surroundings.
   float2 lp=float2(i.hot.w,i.outer.w);
   float n=fbm2(lp*2.4+seed*7.3+float2(0,_Time.y*.7));
   float n2=fbm2(lp*6.3-seed*3.1+float2(_Time.y*1.3,0));
   float ee=e+(n-.5)*.24+(n2-.5)*.08;
   const float sw=.07;
   float s1=smoothstep(.16-sw,.16+sw,ee);
   float s2=smoothstep(.42-sw,.42+sw,ee);
   float s3=smoothstep(.8-sw,.8+sw,ee);
   float3 col=lerp(i.outer.rgb,lerp(i.hot.rgb,lerp(i.color.rgb,i.core.rgb,s3),s2),s1);
   float fil=pow(saturate(1-abs(n2*2-1)*5),3)*s1*(1-s3*.6);
   col+=i.core.rgb*fil*.45;
   col*=.88+.24*n;
   float a=fade*smoothstep(0,.16,e+(n-.5)*.08);
   if(streaked>.5){
    // Streaks: noise stretched along the stroke (along x40 across), scrolling toward the tip.
    float st=fbm2(float2(along*5.0-_Time.y*3.2,e*14.0+seed*9.0));
    float st2=fbm2(float2(along*11.0-_Time.y*5.0,e*30.0-seed*4.0));
    float lines=smoothstep(.52,.7,st)*.9+smoothstep(.58,.76,st2)*.6;
    col=lerp(col,i.core.rgb,saturate(lines)*.7*s1);
    col*=.62+.55*st;
    // Fray: the outer part breaks into wisps, and the tail (low along) erodes away.
    float fray=smoothstep(.0,.5,e+(st2-.5)*.8);
    float tail=smoothstep(.0,.35,along+(st-.5)*.4);
    a*=lerp(1,fray,.85)*tail;
   }
   return float4(col*a,a);
  }
  ENDCG }
 }
}
