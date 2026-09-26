Shader "Mindstone/Mainline/SilkRound2" {
 Properties{_NeedlePass("Silver needle metal",Float)=0}
 SubShader {
  Tags { "Queue"="Transparent+10" "RenderType"="Transparent" }
  Blend SrcAlpha OneMinusSrcAlpha ZWrite Off Cull Off
  Pass {
   CGPROGRAM
   #pragma target 3.0
   #pragma vertex vert
   #pragma fragment frag
   #include "UnityCG.cginc"
   float _NeedlePass;
   struct v2f { float4 pos:SV_POSITION;float3 normal:TEXCOORD0;float3 world:TEXCOORD1;float4 color:COLOR;float3 uv:TEXCOORD2; };
   v2f vert(appdata_full v){v2f o;o.pos=UnityObjectToClipPos(v.vertex);o.normal=UnityObjectToWorldNormal(v.normal);o.world=mul(unity_ObjectToWorld,v.vertex).xyz;o.color=v.color;o.uv=v.texcoord.xyz;return o;}
   float4 frag(v2f i):SV_Target {
    float3 n=normalize(i.normal),v=normalize(_WorldSpaceCameraPos.xyz-i.world),light=normalize(float3(-.35,.8,-.55));
    float diffuse=abs(dot(n,light));
    float spec=pow(saturate(abs(dot(n,normalize(light+v)))),30);
    float3 color=_NeedlePass>.5?i.color.rgb*(.18+diffuse*.72)+float3(.91,.94,.96)*spec*.92:i.color.rgb*(.68+diffuse*.48)+float3(.54,.68,.79)*spec*.55;
    float alpha=i.color.a;
    if(i.uv.z>.5){
     float y=i.uv.x,x=i.uv.y*2-1;
     float fold=.78+.22*cos(x*3.8+y*7);
     float weave=sin(y*235+x*35)*sin(x*143-y*42);
     float seam=x-.25*sin(y*9)-.12*sin(y*23+.7);
     float inlay=exp(-pow(seam/.035,2));
     // Two unequal interior embroidered curls, never a periodic row of ribs.
     float branchA=exp(-pow((seam-.32*sin((y-.16)*6.1))/.045,2))*exp(-pow((y-.31)/.14,2));
     float branchB=exp(-pow((seam+.25*sin((y-.56)*7.3))/.037,2))*exp(-pow((y-.73)/.10,2));
     float feather=(branchA+branchB)*smoothstep(.08,.21,abs(seam))*(1-smoothstep(.5,.82,abs(x)));
     float hem=exp(-pow((abs(x)-.81-.035*sin(y*7.1))/.025,2));
     color=i.color.rgb*(.78+diffuse*.42)*fold*(1+weave*.026);
     color+=float3(.98,.61,.22)*(inlay*.73+feather*.27+hem*.30);
     color+=float3(.75,.19,.24)*spec*.18;
     alpha*=smoothstep(0,.10,1-abs(x));
    }
    clip(alpha-.008);return float4(color,alpha);
   }
   ENDCG
  }
 }
}
