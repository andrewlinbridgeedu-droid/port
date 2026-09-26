Shader "Mindstone/ArcanaCard" {SubShader{Tags{"Queue"="Geometry"} Cull Off Pass{CGPROGRAM
#pragma vertex vert
#pragma fragment frag
#include "UnityCG.cginc"
struct v{float4 p:SV_POSITION;float2 uv:TEXCOORD0;};v vert(appdata_base a){v o;o.p=UnityObjectToClipPos(a.vertex);o.uv=a.texcoord;return o;}
float4 frag(v i):SV_Target{float2 q=abs(i.uv-.5);float edge=max(q.x,q.y);float border=step(.40,edge)*step(edge,.47);float diamond=1-smoothstep(.014,.03,abs(q.x+q.y-.21));float eye=1-smoothstep(.018,.028,length((i.uv-.5)*float2(1,1.8)));return float4(lerp(float3(.07,.018,.14),float3(1,.65,.19),saturate(border+diamond+eye)),1);}
ENDCG}}}
