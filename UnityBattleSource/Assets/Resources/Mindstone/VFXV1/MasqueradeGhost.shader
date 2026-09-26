Shader "Mindstone/VFXV1/MasqueradeGhost" {
 Properties { _Color("Tint",Color)=(0.48,0.22,1,0.4) }
 SubShader { Tags {"Queue"="Transparent" "RenderType"="Transparent"} Blend SrcAlpha One ZWrite Off Cull Back
 Pass { CGPROGRAM
 #pragma vertex vert
 #pragma fragment frag
 #include "UnityCG.cginc"
 struct v2f {float4 pos:SV_POSITION; float3 world:TEXCOORD0; float3 normal:TEXCOORD1;};
 float4 _Color;
 v2f vert(appdata_base v){v2f o;o.pos=UnityObjectToClipPos(v.vertex);o.world=mul(unity_ObjectToWorld,v.vertex).xyz;o.normal=UnityObjectToWorldNormal(v.normal);return o;}
 fixed4 frag(v2f i):SV_Target {float rim=pow(1-saturate(abs(dot(normalize(i.normal),normalize(_WorldSpaceCameraPos-i.world)))),1.65);float bands=.90+.10*sin(i.world.y*42-_Time.y*3);float veins=pow(saturate(sin(i.world.y*19+i.world.x*14+sin(i.world.z*11)-_Time.y*2)),12);float3 c=lerp(_Color.rgb,float3(1,.72,.3),rim*.85);return float4(c*(.96+rim*1.32+veins*.16),_Color.a*(.18+rim*.82)*bands);}
 ENDCG }
 }
}
