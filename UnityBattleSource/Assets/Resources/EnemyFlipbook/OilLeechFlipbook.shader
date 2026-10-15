// The oil leech's camera-facing flipbook (2026-10-12). Same atlas drawing as Mistport/AIHeroAtlas,
// but the quad stands on the floor at the pool's centre, so its lower half would sink into the
// marble's depth: every vertex takes the depth of _DepthAnchor (a point just in front of the pool's
// front lip), so the floor never cuts the pool while anything standing in front still covers it.
Shader "Mistport/OilLeechFlipbook20261012" {
 Properties {
  _MainTex("Frames",2D)="white"{}
  _Color("Opacity",Color)=(1,1,1,1)
  _Grid("Grid",Vector)=(4,12,0,0) _Frame("Frame",Float)=0
  _DepthAnchor("Depth anchor (world)",Vector)=(0,0,0,1)
 }
 SubShader {
  Tags {"Queue"="Transparent" "RenderType"="Transparent" "IgnoreProjector"="True"}
  Cull Off ZWrite Off Blend One OneMinusSrcAlpha
  Pass {
   CGPROGRAM
   #pragma vertex vert
   #pragma fragment frag
   #include "UnityCG.cginc"
   sampler2D _MainTex; float4 _Grid,_DepthAnchor; float _Frame; fixed4 _Color;
   struct appdata { float4 vertex:POSITION; float2 uv:TEXCOORD0; };
   struct v2f { float4 vertex:SV_POSITION; float2 uv:TEXCOORD0; };
   v2f vert(appdata v) {
    v2f o; o.vertex=UnityObjectToClipPos(v.vertex);
    float4 a=mul(UNITY_MATRIX_VP,float4(_DepthAnchor.xyz,1));
    o.vertex.z=a.z/a.w*o.vertex.w;
    o.uv=v.uv; return o;
   }
   fixed4 frag(v2f i):SV_Target {
    float2 cell=float2(fmod(_Frame,_Grid.x),_Grid.y-1-floor(_Frame/_Grid.x));
    fixed4 c=tex2D(_MainTex,(cell+lerp(float2(.002,.002),float2(.998,.998),i.uv))/_Grid.xy);
    c.rgb*=c.a; c.rgb*=_Color.rgb*_Color.a; c.a*=_Color.a;
    return c;
   }
   ENDCG
  }
 }
}
