// Large authored spell body for SpellSpectacle20260926.
// uv.x runs along the body (0 tail -> 1 head), uv.y across it (0..1).
// Saturated colour is alpha-blended so the body keeps its hue over bright
// marble or sky; only the contact head, dissolve rim and sparkle add light.
Shader "Mistport/Spectacle/Sweep20260926" {
 Properties {
  _Filigree("Filigree",2D)="black"{} _Noise("Noise",2D)="gray"{} _Ramp("Ramp",2D)="white"{}
  _Line("Line colour",Color)=(1,.8,.35,1) _Core("Core colour",Color)=(1,1,1,1)
  _Reveal("Reveal head",Float)=1 _Dissolve("Dissolve",Float)=-.3 _Alpha("Alpha",Float)=1
  _Intensity("Intensity",Float)=1 _Glow("Glow",Float)=1 _Opacity("Opacity",Float)=.9 _Seed("Seed",Float)=0
  _RampShift("Ramp shift",Float)=0 _RampSpan("Ramp span",Float)=1 _Tile("Filigree tile",Float)=2.5
  _Scroll("Scroll",Float)=0 _Tear("Edge tear",Float)=1 _Head("Head glow",Float)=1 _CoreAmt("Center core",Float)=.6
  _Flow("Flow",Float)=0
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
  sampler2D _Filigree,_Noise,_Ramp; float4 _Line,_Core;
  float _Reveal,_Dissolve,_Alpha,_Intensity,_Glow,_Opacity,_Seed,_RampShift,_RampSpan,_Tile,_Scroll,_Tear,_Head,_CoreAmt,_Flow;
  v2f vert(appdata v){
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
   // Irregular leading edge: the body grows from tail to head.
   float head=_Reveal-along+(n-.5)*.24;
   float reveal=saturate(head/.07);
   // Torn silhouette: broad lobes from low-frequency noise, fine fray on top.
   float centre=1-abs(across*2-1);
   float cut=.04+(.48*nEdge+.10*nFine)*_Tear;
   float edge=saturate((centre-cut)/.07);
   float inner=saturate((centre-cut)/.30);
   // Dissolve into drifting islands with a lit rim.
   float dn=tex2D(_Noise,float2(along*1.9+_Seed*1.3+_Flow*.15,across*1.1)).r*.8+nEdge*.2;
   float keep=saturate((dn-_Dissolve)/.10);
   float rim=saturate(1-abs(dn-_Dissolve)/.05)*step(-.05,_Dissolve);
   float4 f=tex2D(_Filigree,float2(along*_Tile+_Scroll+_Seed,across*.92+.04));
   float band=saturate(across*_RampSpan+_RampShift+(n-.5)*.2+sin(along*5.1+_Seed)*.06);
   float3 ramp=tex2D(_Ramp,float2(band,.5)).rgb;
   float lit=.62+.38*i.shade;
   // Saturated body: scale/cloud fill lightens, low noise deepens.
   float3 base=ramp*(.70+.42*f.g)*lit;
   base*=lerp(.66,1.1,smoothstep(.12,.78,n));
   // Vibrance: push the ramp away from grey so it holds on bright ground.
   float luma=dot(base,float3(.299,.587,.114));
   base=max(0,lerp(luma.xxx,base,1.45));
   // Darker torn contour gives each lobe a readable edge and volume.
   base*=lerp(.42,1,inner);
   // Gold calligraphy replaces the body colour where it is drawn.
   base=lerp(base,_Line.rgb*1.08,saturate(f.r*.9));
   float headGlow=exp(-pow((along-_Reveal)/.08,2))*_Head;
   float3 glow=_Core.rgb*(headGlow*.55+pow(centre,7)*_CoreAmt*.45)+_Core.rgb*f.b*.9+_Line.rgb*rim*.9;
   float body=saturate(.86+.14*max(f.g,f.r)+headGlow*.3);
   float a=edge*reveal*keep*i.color.a*_Alpha*body;
   return float4((base*_Intensity+glow*_Glow)*a,a*_Opacity);
  }
  ENDCG }
 }
}
