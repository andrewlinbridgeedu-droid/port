Shader "Mindstone/EnemySignature/Sprite"
{
 Properties {
  _MainTex ("Authored particle", 2D) = "white" {}
  _DstBlend ("Destination blend", Float) = 1
  _Shape ("0 particle, 1 glow, 2 parchment", Float) = 0
 }
 SubShader {
  Tags { "Queue"="Transparent+14" "RenderType"="Transparent" }
  Blend SrcAlpha [_DstBlend] ZWrite Off Cull Off
  Pass {
   CGPROGRAM
   #pragma target 3.0
   #pragma vertex vert
   #pragma fragment frag
   #include "UnityCG.cginc"
   sampler2D _MainTex; float _Shape;
   struct appdata { float4 vertex:POSITION; float4 color:COLOR; float2 uv:TEXCOORD0; };
   struct v2f { float4 position:SV_POSITION; float4 color:COLOR; float2 uv:TEXCOORD0; float3 world:TEXCOORD1; };
   v2f vert(appdata v) { v2f o; o.position=UnityObjectToClipPos(v.vertex); o.color=v.color; o.uv=v.uv;o.world=mul(unity_ObjectToWorld,v.vertex).xyz; return o; }
   float4 frag(v2f i):SV_Target {
    float2 q=i.uv*2-1;
    float4 tex=tex2D(_MainTex,i.uv);
    float alpha=tex.a*tex.r;
    float3 tint=i.color.rgb;
    if(_Shape>.5 && _Shape<1.5) {
      float r=dot(q,q);
      alpha=exp(-r*5)*saturate(1-r);
    }
    if(_Shape>1.5 && _Shape<2.5) {
      float edge=max(abs(q.x),abs(q.y));
      alpha=saturate((1-edge)*35);
      float border=step(.82,edge)*step(edge,.90);
      float row=step(.57,frac((i.uv.y-.15)*13))*step(abs(q.x),.67)*step(abs(q.y),.65);
      float words=step(.17,frac(i.uv.x*6+floor(i.uv.y*13)*.31));
      float fold=.76+.24*cos(q.x*2.8);
      tint*=fold*(1-.62*row*words);
      tint+=border*float3(.7,.32,.04);
    }
    if(_Shape>2.5 && _Shape<3.5) {
      // Five advected density slices establish hot interior and dark torn edges;
      // flame texture is a density field, not a flat yellow silhouette.
      float density=0,peak=0;
      float seed=dot(i.world,float3(.27,.13,.19));
      for(int slice=0;slice<5;slice++) {
        float z=slice*.21;
        float2 flow=float2(sin(i.uv.y*14+_Time.y*6+z*7+seed),cos(i.uv.x*11-_Time.y*4+z*9-seed))*.052;
        float2 uv=saturate(i.uv+flow+float2((z-.4)*.10,-_Time.y*.065+z*.06));
        uv.y=clamp(i.uv.y+flow.y+z*.03,0,1);
        float4 layer=tex2D(_MainTex,uv);
        float d=layer.a*pow(saturate(layer.r),.68);
        density+=d*.24;peak=max(peak,d);
      }
      float edge=saturate(min(min(i.uv.x,1-i.uv.x),min(i.uv.y,1-i.uv.y))*18);
      alpha=saturate(density*1.65)*edge;
      float temperature=smoothstep(.26,.83,peak)*smoothstep(.13,.78,density);
      float3 hot=lerp(i.color.rgb,float3(1,.93,.73),.58);
      tint=lerp(i.color.rgb*.14,i.color.rgb*.95,smoothstep(.05,.53,density));
      tint=lerp(tint,hot*1.25,pow(temperature,2.2));
      alpha*=.92;
    }
    if(_Shape>3.5) {
      // Enchanted cloth is internally lit, turbulent and perforated at the
      // moving front: a spectral material rather than an ordinary red curtain.
      float3 w=i.world*3.6;
      float n=sin(w.x*2.3+sin(w.y*1.7+_Time.y*3))*sin(w.y*2.1+w.z+_Time.y*2);
      float grain=sin(w.x*13+w.y*8-_Time.y*8)*sin(w.y*11-w.z*5);
      float heat=pow(saturate(n*.5+.5),5);
      tint=i.color.rgb*(.38+heat*5)+float3(1,.22,.08)*heat*.64;
      alpha=saturate(.55+n*.45+grain*.08);
    }
    return float4(tint,alpha*i.color.a);
   }
   ENDCG
  }
 }
}
