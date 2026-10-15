Shader "Mindstone/Mainline/LeechWetRound2" {
 Properties { _Color("Wet olive body",Color)=(.24,.42,.045,1) _Age("Flow",Float)=0
  _VeinTint("Veins",Color)=(.66,.72,.17,1) _SpecTint("Glint",Color)=(.57,.67,.35,1) _RimTint("Rim",Color)=(.32,.50,.055,1) }
 SubShader {
  Tags { "RenderType"="Opaque" }
  Pass {
   CGPROGRAM
   #pragma target 3.0
   #pragma vertex vert
   #pragma fragment frag
   #include "UnityCG.cginc"
   float4 _Color,_VeinTint,_SpecTint,_RimTint;float _Age;
   struct v2f {float4 pos:SV_POSITION;float3 normal:TEXCOORD0;float3 world:TEXCOORD1;float3 local:TEXCOORD2;};
   v2f vert(appdata_base v){v2f o;o.pos=UnityObjectToClipPos(v.vertex);o.normal=UnityObjectToWorldNormal(v.normal);o.world=mul(unity_ObjectToWorld,v.vertex).xyz;o.local=v.vertex.xyz;return o;}
   float4 frag(v2f i):SV_Target {
    float3 n=normalize(i.normal),v=normalize(_WorldSpaceCameraPos.xyz-i.world),l=normalize(float3(-.3,.8,-.55));
    float diffuse=saturate(dot(n,l)),fresnel=pow(1-saturate(dot(n,v)),3);
    float spec=pow(saturate(dot(n,normalize(l+v))),54);
    float3 p=i.local;
    float vein=pow(saturate(.5+.5*sin(p.x*22+p.y*17+sin(p.z*19+p.y*7)*2-_Age*.9)),19);
    float lobe=.6+.22*sin(p.y*13+p.z*11)*sin(p.x*9-p.z*8);
    float3 color=_Color.rgb*(lobe+diffuse*.65)+_VeinTint.rgb*vein*.39;
    color+=_SpecTint.rgb*spec*.75+_RimTint.rgb*fresnel*.32;
    return float4(color,1);
   }
   ENDCG
  }
 }
}
