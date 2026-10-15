// Hand-drawn frame-by-frame impacts (2026-10-08): one cell of a flipbook sheet per
// drawing, held (never blended) like a redrawn animation frame. The sheet is straight
// alpha; it is drawn premultiplied so the saturated fire keeps its hue over bright
// marble, with _Bright lifting the colour toward a neon glow without turning it white.
// Painted props (2026-10-09, user: 这个太静态 / 这几个东西都要动起来): _Flow warps the cell
// inside its own bounds with scrolling noise (1 smoke / cloth billows, 2 fire licks upward,
// 3 liquid / bubbles wobble, 4 light shimmers) and _Erode makes a fading sprite break up into
// wisps instead of dimming as one picture. Both default to 0 (tarot flights, flipbooks).
Shader "Mistport/Spectacle/Flipbook20261008" {
 Properties {
  _MainTex("Sheet",2D)="black"{}
  _Noise("Noise",2D)="gray"{}
  _Cols("Columns",Float)=4 _Rows("Rows",Float)=4
  _Frame("Frame",Float)=0 _Flip("Mirror",Float)=0
  _Alpha("Alpha",Float)=1 _Bright("Brightness",Float)=1.15
  _Tint("Tint (painted sprites)",Color)=(1,1,1,1)
  _Flow("Flow mode",Float)=0 _Seed("Seed",Float)=0 _Erode("Erode as it fades",Float)=0
  _Curl("Curl",Float)=0 _CurlC("Curl centre (xy) and radius (z)",Vector)=(.5,.5,.5,0)
 }
 SubShader {
  Tags { "Queue"="Transparent+70" "RenderType"="Transparent" "IgnoreProjector"="True" }
  Blend One OneMinusSrcAlpha ZWrite Off Cull Off ZTest Always
  Pass { CGPROGRAM
  #pragma vertex vert
  #pragma fragment frag
  #include "UnityCG.cginc"
  sampler2D _MainTex,_Noise; float _Cols,_Rows,_Frame,_Flip,_Alpha,_Bright,_Flow,_Seed,_Erode,_Curl; float4 _Tint,_CurlC;
  struct appdata { float4 vertex:POSITION; float2 uv:TEXCOORD0; };
  struct v2f { float4 pos:SV_POSITION; float2 local:TEXCOORD0; float2 cell:TEXCOORD1; };
  v2f vert(appdata v){
   v2f o; o.pos=UnityObjectToClipPos(v.vertex);
   float2 uv=v.uv; if(_Flip>.5) uv.x=1-uv.x;
   float f=floor(_Frame+.5);
   o.cell=float2(fmod(f,_Cols),floor(f/_Cols));
   o.local=uv;
   return o;
  }
  fixed4 frag(v2f i):SV_Target{
   float2 l=i.local; float shimmer=1;
   float curlFoam=0;
   // Curl (2026-10-09, user: 能不能让这浪卷起来): the picture twirls round _CurlC.xy, most
   // at the centre and fading out by radius _CurlC.z, by _Curl radians (positive turns the
   // content clockwise) - a wave's crest rolls over into its hollow as _Curl grows.
   if(abs(_Curl)>.001){
    float2 cd=l-_CurlC.xy; float cr=length(cd);
    // Not a smooth twirl (user: 这个太光滑了): the turn and the radius wander with noise so
    // the spiral arms come out ragged and clumped like churning water.
    float spin=saturate(abs(_Curl)/6.283);
    float tn=tex2D(_Noise,cd*1.7+float2(_Time.y*.35,_Time.y*.1)).r-.5;
    float tn2=tex2D(_Noise,cd*4.6-float2(_Time.y*.6,0)).g-.5;
    float ca=_Curl*pow(saturate(1-cr/_CurlC.z),1.6)*(1+.4*tn)+tn2*1.2*spin;
    float rj=1+(tex2D(_Noise,float2(atan2(cd.y,cd.x)*.9,cr*3.2-_Time.y*.8)).b-.5)*.35*spin;
    float cc=cos(ca), cn=sin(ca);
    l=_CurlC.xy+float2(cd.x*cc-cd.y*cn, cd.x*cn+cd.y*cc)*rj;
    curlFoam=spin*smoothstep(.62,.8,tex2D(_Noise,cd*7.3+float2(0,-_Time.y*1.4)).r);
   }
   l=clamp(l,.01,.99);
   if(_Flow>.5){
    float time=_Time.y+_Seed*13.7;
    float spd = _Flow<1.5?.35 : _Flow<2.5?1.8 : _Flow<3.5?.9 : 1.2;
    float amp = _Flow<1.5?.05 : _Flow<2.5?.075*(.3+l.y) : _Flow<3.5?.03 : .015;
    float2 q=l*1.3+_Seed;
    float n1=tex2D(_Noise,q+float2(0,-time*spd)).r-.5;
    float n2=tex2D(_Noise,q*1.6+float2(time*spd*.37,-time*spd*.8)).g-.5;
    l=clamp(l+float2(n1,n2)*amp,.01,.99);
    float n3=tex2D(_Noise,i.local*2.2+float2(_Seed*.3,-time*spd*1.3)).b;
    shimmer = _Flow<1.5? .85+.3*n3 : _Flow<2.5? .72+.56*n3 : _Flow<3.5? .88+.24*n3 : .75+.5*n3;
   }
   // Sheet rows run top to bottom; texture v runs bottom to top. Inset so a neighbouring
   // cell never bleeds in.
   float2 cs=float2(1/_Cols,1/_Rows);
   float2 lu=lerp(float2(.001,.001),float2(.999,.999),l);
   float2 uv=float2((i.cell.x+lu.x)*cs.x,1-(i.cell.y+1-lu.y)*cs.y);
   fixed4 c=tex2D(_MainTex,uv);
   float a=c.a*_Alpha;
   if(_Erode>.5){
    float nd=tex2D(_Noise,i.local*1.7+_Seed+float2(0,-_Time.y*.15)).b;
    float keep=saturate((nd-(1-saturate(_Alpha))*1.15+.25)/.25);
    a=c.a*keep*saturate(_Alpha*1.6);
   }
   // White foam flecks over the churning water while it spins.
   float3 rgb=saturate(c.rgb*_Tint.rgb*_Bright*shimmer); rgb=lerp(rgb,float3(1,1,1),curlFoam*.75*saturate(c.a*2));
   return fixed4(rgb*a,a);
  }
  ENDCG }
 }
}
