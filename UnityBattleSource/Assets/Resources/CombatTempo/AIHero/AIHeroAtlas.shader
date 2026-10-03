Shader "Mistport/AIHeroAtlas" {
 Properties {
  _MainTex("Frames",2D)="white"{} _IdleTex("Rest",2D)="white"{}
  _Grid("Grid",Vector)=(8,6,0,0) _Frame("Frame",Float)=0 _IdleBlend("Rest blend",Range(0,1))=1
 }
 SubShader {
  Tags {"Queue"="Transparent" "RenderType"="Transparent" "IgnoreProjector"="True"}
  Cull Off ZWrite Off Blend One OneMinusSrcAlpha
  Pass {
   CGPROGRAM
   #pragma vertex vert
   #pragma fragment frag
   #include "UnityCG.cginc"
   sampler2D _MainTex, _IdleTex; float4 _MainTex_TexelSize, _Grid; float _Frame,_IdleBlend;
   struct appdata { float4 vertex:POSITION; float2 uv:TEXCOORD0; };
   struct v2f { float4 vertex:SV_POSITION; float2 uv:TEXCOORD0; };
   v2f vert(appdata v) { v2f o;o.vertex=UnityObjectToClipPos(v.vertex);o.uv=v.uv;return o; }
   fixed4 frag(v2f i):SV_Target {
    float2 cell=float2(fmod(_Frame,_Grid.x),_Grid.y-1-floor(_Frame/_Grid.x));
    float2 uv=(cell+lerp(float2(.002,.002),float2(.998,.998),i.uv))/_Grid.xy;
    fixed4 a=tex2D(_MainTex,uv);fixed4 b=tex2D(_IdleTex,i.uv);
    a.rgb*=a.a;b.rgb*=b.a;
    return lerp(a,b,_IdleBlend);
   }
   ENDCG
  }
 }
}
