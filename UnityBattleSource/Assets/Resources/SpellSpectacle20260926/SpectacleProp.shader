// Solid props of SpellSpectacle20260926 (2026-10-07): tarot cards, wax seals, mirror shards,
// name cards and the user's painted props (swords, smoke, fire, claw marks...), tumbling in
// 3D instead of bands of light (user on 170.14: 你很多这些一条条的). RGB matters (unlike the
// flare atlas). uv picks the front cell, uv2 the back cell (VFACE). uv3.x: glow (heat, a hit);
// uv3.y: sheen phase; uv3.zw: corner in the quad. uv4.x: flash amount; uv4.y: flow mode +
// seed (fraction); uv4.z: reveal progress of a wipe (1 = whole). Vertex colour tints/fades.
//
// Flow (user: 记得一定不能有静态图的感觉，法术一定是流动的): painted smoke billows, fire
// licks upward and flickers, light streaks shimmer and run, petals ripple; all of them break
// up into wisps as they fade (noise erosion) instead of fading as a whole picture. The cell
// is warped inside its own bounds with scrolling noise, so it never bleeds into a neighbour.
// Premultiplied output.
Shader "Mistport/Spectacle/Prop20261007" {
 Properties {
  _MainTex("Props",2D)="white"{}
  _Noise("Noise",2D)="gray"{}
  _CellSize("Cell size in the atlas",Float)=.125
  _Hot("Hot colour",Color)=(1,.96,.86,1)
 }
 SubShader {
  Tags { "Queue"="Transparent+60" "RenderType"="Transparent" "IgnoreProjector"="True" }
  Blend One OneMinusSrcAlpha ZWrite Off Cull Off ZTest LEqual
  Pass { CGPROGRAM
  #pragma vertex vert
  #pragma fragment frag
  #pragma target 3.0
  #include "UnityCG.cginc"
  struct appdata { float4 vertex:POSITION; float3 normal:NORMAL; float2 uv:TEXCOORD0; float2 uv2:TEXCOORD1; float4 uv3:TEXCOORD2; float4 uv4:TEXCOORD3; float4 color:COLOR; };
  struct v2f { float4 pos:SV_POSITION; float2 uv:TEXCOORD0; float2 uv2:TEXCOORD1; float4 fx:TEXCOORD2; float facing:TEXCOORD3; float2 local:TEXCOORD4; float rim:TEXCOORD5; float4 color:COLOR; };
  sampler2D _MainTex,_Noise; float4 _Hot; float _CellSize;
  v2f vert(appdata v){
   v2f o; o.pos=UnityObjectToClipPos(v.vertex); o.uv=v.uv; o.uv2=v.uv2; o.color=v.color;
   o.fx=float4(v.uv3.xy,v.uv4.x,v.uv4.y); o.local=v.uv3.zw; o.rim=v.uv4.z;
   float3 n=normalize(UnityObjectToWorldNormal(v.normal));
   float3 view=normalize(WorldSpaceViewDir(v.vertex));
   o.facing=abs(dot(n,view));
   return o;
  }
  float noise2(float2 p,float c){ float4 t=tex2D(_Noise,p); return c<.5?t.r:c<1.5?t.g:t.b; }
  float4 frag(v2f i, fixed face:VFACE):SV_Target {
   float mode=floor(i.fx.w+.001), seed=frac(i.fx.w)*17.0;
   float time=_Time.y+seed;
   float2 local=i.local, warped=local;
   float shimmer=1;
   if(mode>.5){
    // Speed and strength per kind: smoke rolls slowly, fire licks fast and harder near its
    // tips, light streaks run along themselves, petals ripple gently.
    float spd = mode<1.5?.28 : mode<2.5?1.7 : mode<3.5?1.1 : .45;
    float amp = mode<1.5?.05 : mode<2.5?.075*(.25+local.y) : mode<3.5?.018 : .02;
    float2 q=local*1.25+seed;
    float n1=noise2(q+float2(0,-time*spd),0)-.5;
    float n2=noise2(q*1.6+float2(time*spd*.37,-time*spd*.8),1)-.5;
    warped=clamp(local+float2(n1,n2)*amp,.012,.988);
    float n3=noise2(local*2.2+float2(seed*.3,-time*spd*1.3),2);
    shimmer = mode<1.5 ? .82+.36*n3 : mode<2.5 ? .78+.5*n3 : mode<3.5 ? .7+.6*n3 : .85+.3*n3;
   }
   float2 d=(warped-local)*_CellSize;
   float2 uv= face>0 ? i.uv+d : i.uv2+float2(-d.x,d.y);
   float4 t=tex2D(_MainTex,uv);
   float lit=.5+.5*i.facing;
   // A flash as it turns square to the camera, and a sheen band sliding over it.
   float flash=pow(i.facing,30)*.55*i.fx.z;
   float band=pow(saturate(1-abs(frac(local.x*.7+local.y*.5+i.fx.y)*2-1)),10)*.35*i.facing*i.fx.z;
   float3 col=t.rgb*i.color.rgb*lit*shimmer+_Hot.rgb*(flash+band+i.fx.x*.8)*t.a;
   if(i.rim>.001){
    // 2XKO-style banding (2026-10-08): the painted light is cut into three hard steps by its
    // own brightness instead of a smooth gradient - a near-white core, the tint, then a thin
    // contrasting rim (the tint's hue pushed round the wheel) - so it reads as drawn, not
    // airbrushed. The flow warp moves the step edges, so the bands run along the stroke.
    // The painted strokes are mostly half-transparent, so the steps sit high: only the
    // brightest 12 % is the white core, the next band the tint, the rest a magenta rim that
    // is made solid (alpha floor) so it reads as a drawn edge, not a haze.
    float heat=t.a*shimmer;
    float3 core=float3(1,.97,.8);
    float3 mid=i.color.rgb*1.2;
    float3 rimc=float3(1,.22,.62);
    float3 bands = heat>.88 ? core : heat>.58 ? mid : rimc;
    float edge=smoothstep(.08,.14,t.a);
    col=lerp(col, bands*(1.0+i.fx.x*.5)*edge, i.rim);
    t.a=lerp(t.a, max(t.a, edge*.85), i.rim);
   }
   float a=t.a*i.color.a;
   if(mode>.5){
    // Fading flowing matter erodes into wisps rather than dimming as one picture.
    float erode=1-saturate(i.color.a);
    float nd=noise2(local*1.7+float2(seed,seed*.6)+float2(0,-time*.15),2);
    float keep=saturate((nd-erode*1.15+.25)/.25);
    a=t.a*keep*saturate(i.color.a*1.6);
   }
   return float4(col*a,a);
  }
  ENDCG }
 }
}
