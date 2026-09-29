// Large authored spell body for SpellSpectacle20260926.
// uv.x runs along the body (0 tail -> 1 head), uv.y across it (0..1).
// _Row picks one of eight matters in SpectacleMatter (filigree, flame,
// water, crystal, silk, ink, electric, smoke); the edge, darkness, flow and
// flicker parameters give each matter its own silhouette and behaviour.
// Saturated colour is alpha-blended so the body keeps its hue over bright
// marble or sky; only the contact head, dissolve rim and sparkle add light.
Shader "Mistport/Spectacle/Sweep20260926" {
 Properties {
  _Matter("Matter atlas",2D)="black"{} _Noise("Noise",2D)="gray"{} _Ramp("Ramp",2D)="white"{}
  _Line("Line colour",Color)=(1,.8,.35,1) _Core("Core colour",Color)=(1,1,1,1)
  _Reveal("Reveal head",Float)=1 _Dissolve("Dissolve",Float)=-.3 _Alpha("Alpha",Float)=1
  _Intensity("Intensity",Float)=1 _Glow("Glow",Float)=1 _Opacity("Opacity",Float)=.9 _Seed("Seed",Float)=0
  _RampShift("Ramp shift",Float)=0 _RampSpan("Ramp span",Float)=1 _Tile("Matter tile",Float)=2.5
  _Scroll("Scroll",Float)=0 _Tear("Edge tear",Float)=1 _Head("Head glow",Float)=1 _CoreAmt("Center core",Float)=.6
  _Flow("Flow",Float)=0 _Row("Matter row",Float)=0 _EdgeSoft("Edge softness",Float)=.07 _Facet("Facet edge",Float)=0
  _Ink("Ink darkness",Float)=0 _Distort("Flow distortion",Float)=0 _Flicker("Flicker",Float)=0
  _Wobble("Vibration",Float)=0 _WobbleFreq("Vibration waves",Float)=2
 }
 SubShader {
  Tags { "Queue"="Transparent+40" "RenderType"="Transparent" "IgnoreProjector"="True" }
  Blend One OneMinusSrcAlpha ZWrite Off Cull Off ZTest LEqual
  Pass { CGPROGRAM
  #pragma vertex vert
  #pragma fragment frag
  #include "UnityCG.cginc"
  struct appdata { float4 vertex:POSITION; float3 normal:NORMAL; float2 uv:TEXCOORD0; float4 color:COLOR; };
  struct v2f { float4 pos:SV_POSITION; float2 uv:TEXCOORD0; float4 color:COLOR; float shade:TEXCOORD1; };
  sampler2D _Matter,_Noise,_Ramp; float4 _Line,_Core;
  float _Reveal,_Dissolve,_Alpha,_Intensity,_Glow,_Opacity,_Seed,_RampShift,_RampSpan,_Tile,_Scroll,_Tear,_Head,_CoreAmt,_Flow;
  float _Row,_EdgeSoft,_Facet,_Ink,_Distort,_Flicker,_Wobble,_WobbleFreq;
  float hash1(float n){ return frac(sin(n*12.9898+_Seed*3.17)*43758.5453); }
  v2f vert(appdata v){
   // Travelling vibration along the body (sound, resonance): the surface
   // itself moves, not only its texture.
   float w=sin(v.uv.x*_WobbleFreq*6.2832-_Flow*24+_Seed)*_Wobble*sin(3.1416*saturate(v.uv.x));
   v.vertex.xyz+=v.normal*w;
   v2f o; o.pos=UnityObjectToClipPos(v.vertex); o.uv=v.uv; o.color=v.color;
   float3 n=normalize(UnityObjectToWorldNormal(v.normal));
   float3 view=normalize(WorldSpaceViewDir(v.vertex));
   o.shade=abs(dot(n,view));
   return o;
  }
  float4 frag(v2f i):SV_Target {
   float along=i.uv.x, across=i.uv.y;
   float n=tex2D(_Noise,float2(along*1.3+_Seed*.37+_Flow*.2, across*.8+_Seed*.61)).r;
   float nEdge=tex2D(_Noise,float2(along*1.6+_Seed*.13,across*.7-_Flow*.3)).g;
   float nFine=tex2D(_Noise,float2(along*7.0+_Seed*.29,across*2.1)).b;
   float head=_Reveal-along+(n-.5)*.24;
   float reveal=saturate(head/.07);
   float centre=1-abs(across*2-1);
   // Organic torn edge, or a crystalline sawtooth of flat facets.
   float cutSoft=.04+(.48*nEdge+.10*nFine)*_Tear;
   float seg=along*13+_Seed*7, id=floor(seg), fr=frac(seg);
   float cutFacet=.05+.40*hash1(id)*_Tear+(fr-.5)*.30*(hash1(id+.37)-.5)*2;
   float cut=lerp(cutSoft,cutFacet,_Facet);
   float edge=saturate((centre-cut)/max(_EdgeSoft,.004));
   float inner=saturate((centre-cut)/.30);
   float dn=tex2D(_Noise,float2(along*1.9+_Seed*1.3+_Flow*.15,across*1.1)).r*.8+nEdge*.2;
   float keep=saturate((dn-_Dissolve)/.10);
   float rim=saturate(1-abs(dn-_Dissolve)/.05)*step(-.05,_Dissolve);
   float2 muv=float2(along*_Tile+_Scroll+_Seed, across*.92+.04);
   muv.y=clamp(muv.y+(n-.5)*_Distort,.03,.97);
   float4 f=tex2D(_Matter,float2(muv.x,(7-_Row+muv.y)/8));
   float band=saturate(across*_RampSpan+_RampShift+(n-.5)*.2+sin(along*5.1+_Seed)*.06);
   float3 ramp=tex2D(_Ramp,float2(band,.5)).rgb;
   float lit=.62+.38*i.shade;
   float3 base=ramp*(.62+.5*f.g)*lit;
   base*=lerp(.66,1.1,smoothstep(.12,.78,n));
   float luma=dot(base,float3(.299,.587,.114));
   base=max(0,lerp(luma.xxx,base,1.45));
   base*=lerp(.42,1,inner);
   // Ink: the dense stroke turns near black, colour survives at its wet edge.
   base=lerp(base,base*.07,_Ink*saturate(f.g*1.15));
   base=lerp(base,_Line.rgb*1.08,saturate(f.r*(.9+_Ink*.9)));
   float headGlow=exp(-pow((along-_Reveal)/.08,2))*_Head;
   float3 glow=_Core.rgb*(headGlow*.55+pow(centre,7)*_CoreAmt*.45)+_Core.rgb*f.b*.9+_Line.rgb*rim*.9;
   float body=saturate(.86+.14*max(f.g,f.r)+headGlow*.3);
   // Matter coverage lets ink gaps, smoke holes and bolt gaps show through.
   body*=lerp(1,f.a,saturate(_Ink+step(5.5,_Row)*step(_Row,6.5)*.85+step(6.5,_Row)*.6));
   float a=edge*reveal*keep*i.color.a*_Alpha*body;
   a*=lerp(1,.35+.65*step(.42,hash1(floor(_Flow*34))),_Flicker);
   return float4((base*_Intensity+glow*_Glow)*a,a*_Opacity);
  }
  ENDCG }
 }
}
