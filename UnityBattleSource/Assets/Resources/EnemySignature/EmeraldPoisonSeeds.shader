Shader "MistHarbor/EmeraldPoisonSeeds" {
 SubShader {Tags {"Queue"="AlphaTest+30" "RenderType"="TransparentCutout"}
 Pass {Cull Off ZWrite On
 CGPROGRAM
 #pragma vertex vert
 #pragma fragment frag
 #include "UnityCG.cginc"
 struct appdata{float4 vertex:POSITION;float3 normal:NORMAL;fixed4 color:COLOR;};
 struct v2f{float4 pos:SV_POSITION;float3 world:TEXCOORD0;float3 normal:TEXCOORD1;fixed4 color:COLOR;};
 v2f vert(appdata v){v2f o;o.pos=UnityObjectToClipPos(v.vertex);o.world=mul(unity_ObjectToWorld,v.vertex).xyz;o.normal=UnityObjectToWorldNormal(v.normal);o.color=v.color;return o;}
 fixed4 frag(v2f i):SV_Target{float grain=frac(sin(dot(floor(i.pos.xy),float2(12.9898,78.233)))*43758.5453);clip(i.color.a-grain*.98-.005);
 float fissure=pow(saturate(1-abs(sin(i.world.x*31+i.world.y*19+sin(i.world.z*23)*1.8))*8),2);
 float light=.45+.55*abs(dot(normalize(i.normal),normalize(float3(-.3,1,.4))));
 return fixed4(i.color.rgb*light+float3(.14,.45,.16)*fissure,1);}
 ENDCG
 }}}
