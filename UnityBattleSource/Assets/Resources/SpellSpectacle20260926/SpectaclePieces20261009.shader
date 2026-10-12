// A painted prop breaking apart (2026-10-09, user: 这几个东西都要动起来，散开或者怎样，不能一整块
// 过来). The cell is cut into overlapping soft tiles with ragged noise edges; each tile flies,
// turns and shrinks on its own (PaintPieces) and erodes into wisps as it fades.
// uv: cell-local coordinate (0..1, may run past the cell at the border tiles, masked);
// uv2: tile-local -1..1; uv3.x: per-tile seed. Colour: tint and fade. Premultiplied.
Shader "Mistport/Spectacle/Pieces20261009" {
 Properties { _MainTex("Sheet",2D)="black"{} _Noise("Noise",2D)="gray"{} _CellRect("Cell rect",Vector)=(0,0,.25,.25) _Bright("Brightness",Float)=1 _Curl("Curl",Float)=0 _CurlC("Curl centre",Vector)=(.5,.5,.5,0) }
 SubShader {
  Tags { "Queue"="Transparent+70" "RenderType"="Transparent" "IgnoreProjector"="True" }
  Blend One OneMinusSrcAlpha ZWrite Off Cull Off ZTest Always
  Pass { CGPROGRAM
  #pragma vertex vert
  #pragma fragment frag
  #include "UnityCG.cginc"
  sampler2D _MainTex,_Noise; float4 _CellRect,_CurlC; float _Bright,_Curl;
  struct A { float4 vertex:POSITION; float4 color:COLOR; float2 uv:TEXCOORD0; float2 uv2:TEXCOORD1; float4 uv3:TEXCOORD2; };
  struct V { float4 pos:SV_POSITION; float4 color:COLOR; float2 cl:TEXCOORD0; float2 tile:TEXCOORD1; float seed:TEXCOORD2; };
  V vert(A i){ V o; o.pos=UnityObjectToClipPos(i.vertex); o.color=i.color; o.cl=i.uv; o.tile=i.uv2; o.seed=i.uv3.x; return o; }
  fixed4 frag(V i):SV_Target{
   float2 cl=i.cl;
   float curlFoam=0;
   // Curl (2026-10-09, user: 能不能让这浪卷起来): the picture twirls round _CurlC.xy, most
   // at the centre and fading out by radius _CurlC.z, by _Curl radians (positive turns the
   // content clockwise) - a wave's crest rolls over into its hollow as _Curl grows.
   if(abs(_Curl)>.001){
    float2 cd=cl-_CurlC.xy; float cr=length(cd);
    // Not a smooth twirl (user: 这个太光滑了): the turn and the radius wander with noise so
    // the spiral arms come out ragged and clumped like churning water.
    float spin=saturate(abs(_Curl)/6.283);
    float tn=tex2D(_Noise,cd*1.7+float2(_Time.y*.35,_Time.y*.1)).r-.5;
    float tn2=tex2D(_Noise,cd*4.6-float2(_Time.y*.6,0)).g-.5;
    float ca=_Curl*pow(saturate(1-cr/_CurlC.z),1.6)*(1+.4*tn)+tn2*1.2*spin;
    float rj=1+(tex2D(_Noise,float2(atan2(cd.y,cd.x)*.9,cr*3.2-_Time.y*.8)).b-.5)*.35*spin;
    float cc=cos(ca), cn=sin(ca);
    cl=_CurlC.xy+float2(cd.x*cc-cd.y*cn, cd.x*cn+cd.y*cc)*rj;
    curlFoam=spin*smoothstep(.62,.8,tex2D(_Noise,cd*7.3+float2(0,-_Time.y*1.4)).r);
   }
   float inside=step(0,cl.x)*step(cl.x,1)*step(0,cl.y)*step(cl.y,1);
   float2 uv=_CellRect.xy+lerp(.002,.998,saturate(cl))*_CellRect.zw;
   fixed4 c=tex2D(_MainTex,uv);
   float n=tex2D(_Noise,i.tile*.35+i.seed).r;
   float m=smoothstep(1.0,.5,length(i.tile)+(n-.5)*.7);
   float nd=tex2D(_Noise,cl*1.7+i.seed*.37).b;
   float keep=saturate((nd-(1-saturate(i.color.a))*1.15+.25)/.25);
   float a=c.a*m*inside*keep*saturate(i.color.a*1.6);
   float3 rgb=saturate(c.rgb*i.color.rgb*_Bright); rgb=lerp(rgb,float3(1,1,1),curlFoam*.75*saturate(c.a*2));
   return fixed4(rgb*a,a);
  }
  ENDCG }
 }
}
