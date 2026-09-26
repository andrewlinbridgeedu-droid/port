Shader "Mindstone/EnemySignature/ArcaneImpactBloom"
{
 Properties { _Fire("Authored flame",2D)="white"{} _Smoke("Authored smoke atlas",2D)="white"{} _DstBlend("Destination",Float)=10 }
 SubShader {
  Tags {"Queue"="Transparent+22" "RenderType"="Transparent"}
  Blend SrcAlpha [_DstBlend] ZWrite Off Cull Off
  Pass {
   CGPROGRAM
   #pragma vertex vert
   #pragma fragment frag
   #pragma target 3.0
   #include "UnityCG.cginc"
   sampler2D _Fire,_Smoke;
   struct appdata {float4 vertex:POSITION;float4 color:COLOR;float2 uv:TEXCOORD0;float4 data:TEXCOORD1;};
   struct v2f {float4 vertex:SV_POSITION;float4 color:COLOR;float2 uv:TEXCOORD0;float4 data:TEXCOORD1;};
   v2f vert(appdata v){v2f o;o.vertex=UnityObjectToClipPos(v.vertex);o.color=v.color;o.uv=v.uv;o.data=v.data;return o;}
   float4 frag(v2f i):SV_Target {
    float2 q=i.uv;float seed=i.data.x,time=i.data.z;
    float2 warp=float2(sin(q.y*17+seed*31+time*11),sin(q.x*14-seed*19-time*9))*.027;
    float2 fuv=saturate(q+warp);
    float2 tile=float2(fmod(i.data.w,2),floor(i.data.w/2));
    float4 fire=tex2D(_Fire,fuv);
    float4 smoke=tex2D(_Smoke,(saturate(q+warp*.6)+tile)*.5);
    float detail=tex2D(_Smoke,(frac(q*1.7+seed+float2(time*.17,-time*.23))+tile)*.5).r;
    float f=dot(fire.rgb,float3(.30,.53,.17))*fire.a;
    // Multiply texture detail into highlights so authored white cores cannot
    // become a uniform painted billboard. Smoke carves holes through the fire.
    f*=.35+detail*.65;
    float density=lerp(f,smoke.r*smoke.a,i.data.y);
    float2 edge=min(q,1-q);float border=saturate(min(edge.x,edge.y)*15);
    float alpha=saturate(density*1.8)*border*i.color.a;
    float hot=pow(saturate(f),2.4)*(1-i.data.y)*.65;
    float3 tint=lerp(i.color.rgb*(.45+density*.65),float3(1,.90,.70),hot);
    return float4(tint*lerp(2.6,1.0,i.data.y),alpha);
   }
   ENDCG
  }
 }
}
