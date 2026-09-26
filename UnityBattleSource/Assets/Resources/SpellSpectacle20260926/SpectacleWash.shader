// Full-screen chromatic wash for the contact beat. The mesh is a unit quad
// whose UVs are written straight to clip space, so whichever camera renders
// it (game camera or a recorder's second view) is fully covered.
Shader "Mistport/Spectacle/Wash20260926" {
 Properties {
  _Noise("Noise",2D)="gray"{} _Center("World centre",Vector)=(0,0,0,0)
  _Edge("Edge tint",Color)=(1,.35,.1,1) _Hot("Centre glow",Color)=(1,.85,.55,1)
  _Amount("Amount",Float)=0 _Glow("Glow",Float)=0 _Radius("Glow radius",Float)=.35 _Flow("Flow",Float)=0
 }
 SubShader {
  Tags { "Queue"="Transparent+80" "RenderType"="Transparent" "IgnoreProjector"="True" }
  Blend One OneMinusSrcAlpha ZWrite Off ZTest Always Cull Off
  Pass { CGPROGRAM
  #pragma vertex vert
  #pragma fragment frag
  #include "UnityCG.cginc"
  struct appdata { float4 vertex:POSITION; float2 uv:TEXCOORD0; };
  struct v2f { float4 pos:SV_POSITION; float4 screen:TEXCOORD0; float4 centre:TEXCOORD1; };
  sampler2D _Noise; float4 _Center,_Edge,_Hot; float _Amount,_Glow,_Radius,_Flow;
  v2f vert(appdata v){
   v2f o; o.pos=float4(v.uv*2-1,.5,1);
   o.screen=ComputeScreenPos(o.pos);
   o.centre=ComputeScreenPos(mul(UNITY_MATRIX_VP,float4(_Center.xyz,1)));
   return o;
  }
  float4 frag(v2f i):SV_Target {
   float2 s=i.screen.xy/i.screen.w;
   float2 c=i.centre.xy/max(i.centre.w,1e-4);
   float aspect=_ScreenParams.x/_ScreenParams.y;
   float2 d=(s-c)*float2(aspect,1);
   float dist=length(d);
   float n=tex2D(_Noise,s*float2(aspect,1)*1.3+float2(_Flow*.08,-_Flow*.21)).r;
   float n2=tex2D(_Noise,s*float2(aspect,1)*.55-float2(_Flow*.05,_Flow*.03)).g;
   float vign=saturate(length((s-.5)*float2(aspect,1))*1.25);
   // Heat-like tint: strongest toward frame edges and away from the hit,
   // broken by moving noise so it never reads as a flat filter.
   float tint=(.42+.58*vign)*(.72+.56*n2)*saturate(.35+dist*1.1);
   float glow=exp(-pow(dist/(_Radius*(.85+.3*n)),2))*_Glow;
   float3 col=_Edge.rgb*tint*_Amount+_Hot.rgb*glow;
   float a=saturate(tint*_Amount*.78);
   return float4(col,a);
  }
  ENDCG }
 }
}
