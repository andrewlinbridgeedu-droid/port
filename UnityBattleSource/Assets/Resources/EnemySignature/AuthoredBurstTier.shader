Shader "Mindstone/EnemySignature/AuthoredBurstTier" {
 Properties { _Impact ("Contact flare",Float)=0 _Age ("Presentation age",Float)=0 _Motif ("Folio material",Float)=0 }
 SubShader {
  Tags { "Queue"="Transparent+17" "RenderType"="Transparent" }
  Blend SrcAlpha One ZWrite Off Cull Off
  Pass {
   CGPROGRAM
   #pragma target 3.0
   #pragma vertex vert
   #pragma fragment frag
   #include "UnityCG.cginc"
   float _Age,_Motif,_Impact;
   struct appdata { float4 vertex:POSITION;float4 color:COLOR;float2 uv:TEXCOORD0; };
   struct v2f { float4 pos:SV_POSITION;float4 color:COLOR;float2 uv:TEXCOORD0; };
   v2f vert(appdata v){v2f o;o.pos=UnityObjectToClipPos(v.vertex);o.color=v.color;o.uv=v.uv;return o;}
   float4 frag(v2f i):SV_Target {
    float x=i.uv.x*2-1,y=i.uv.y;
    // The whole width is translucent coloured density; only a moving interior ridge gets hot.
    float edge=pow(saturate(1-abs(x)),.65)*smoothstep(0,.10,y)*smoothstep(0,.12,1-y);
    float flow=sin(y*19-_Age*8+sin(x*8+y*7))*sin(y*9+x*5+_Age*3);
    float grain=sin(y*71+x*23-_Age*12)*sin(y*33-x*18);
    float vein=exp(-pow((x-.16*sin(y*12-_Age*5))/.13,2));
    float density=saturate(.58+flow*.27+grain*.065);
    float3 tint=i.color.rgb*(.30+density*.55)+lerp(i.color.rgb,float3(1,.91,.69),.65)*vein*.48;
    float alpha=edge*(.46+density*.40)*i.color.a;
    if(_Motif>.5) {
     float border=exp(-pow((x-.48*sin(y*9+sin(y*21)))/.035,2));
     float row=smoothstep(.25,.65,sin(y*37+sin(x*8+y*11)*3));
     float word=smoothstep(.35,.65,sin(x*17+y*23+sin(y*19)));
     float fold=.63+.37*cos(x*3.1);
     tint=i.color.rgb*fold*(.62-.40*row*word)+float3(.66,.35,1)*border*.7;
     alpha=edge*(.58+.12*fold)*i.color.a;
    }
    tint*=1+_Impact*1.45;
    alpha=saturate(alpha*(1+_Impact*.35));
    return float4(tint,alpha);
   }
   ENDCG
  }
 }
}
