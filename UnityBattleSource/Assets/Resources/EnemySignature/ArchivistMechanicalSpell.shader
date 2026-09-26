Shader "MistHarbor/ArchivistMechanicalSpell"
{
 Properties { _EdgeGlow("Edge energy",Color)=(.15,.65,1,1) }
 SubShader { Tags { "Queue"="Transparent+5" "RenderType"="Transparent" }
 Pass { Cull Off ZWrite Off Blend SrcAlpha OneMinusSrcAlpha
 CGPROGRAM
 #pragma vertex vert
 #pragma fragment frag
 #include "UnityCG.cginc"
 struct appdata {float4 vertex:POSITION;float3 normal:NORMAL;float2 uv:TEXCOORD0;float4 color:COLOR;};
 struct v2f {float4 pos:SV_POSITION;float3 normal:TEXCOORD0;float3 world:TEXCOORD1;float4 color:COLOR;};
 float4 _EdgeGlow;
 v2f vert(appdata v){v2f o;o.pos=UnityObjectToClipPos(v.vertex);o.normal=UnityObjectToWorldNormal(v.normal);o.world=mul(unity_ObjectToWorld,v.vertex).xyz;o.color=v.color;return o;}
 fixed4 frag(v2f i):SV_Target {
 if(i.color.r>1.5)return fixed4(_EdgeGlow.rgb*1.6,i.color.a);
 float3 n=normalize(i.normal),v=normalize(_WorldSpaceCameraPos.xyz-i.world);
 n=dot(n,v)<0?-n:n;
 float3 light=normalize(float3(-.35,.82,-.43));
 float diffuse=saturate(dot(n,light));
 float spec=pow(saturate(dot(n,normalize(light+v))),64);
 float fresnel=pow(1-saturate(dot(n,v)),3);
 float3 base=i.color.rgb*(.50+diffuse*.65)+float3(.84,.91,1)*spec*.72+float3(.14,.21,.29)*fresnel*.22;
 return fixed4(base,i.color.a);
 }
 ENDCG
 } }
}
