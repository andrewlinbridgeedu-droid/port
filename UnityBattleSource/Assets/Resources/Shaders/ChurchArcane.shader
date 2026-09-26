Shader "Mistport/ChurchArcane" {
 Properties { _BountyDetail("Bounty surface flow",Float)=0  _Color("Color",Color)=(1,1,1,1) _Soft("Soft cloud",Float)=0 _Glow("Arcane core",Float)=0 _Organic("Organic skin",Float)=0 _Cull("Cull",Float)=0 _Depth("Depth",Float)=0 }
 SubShader { Tags {"Queue"="Transparent+12" "RenderType"="Transparent"} Blend SrcAlpha OneMinusSrcAlpha ZWrite [_Depth] Cull [_Cull]
 Pass { CGPROGRAM
 #pragma vertex vert
 #pragma fragment frag
 #include "UnityCG.cginc"
 struct appdata {float4 vertex:POSITION;float2 uv:TEXCOORD0;float3 normal:NORMAL;};struct v2f{float4 pos:SV_POSITION;float2 uv:TEXCOORD0;float3 normal:TEXCOORD1;float3 world:TEXCOORD2;};float4 _Color;float _Soft;float _Glow;float _Organic;float _BountyDetail;
 v2f vert(appdata v){v2f o;o.pos=UnityObjectToClipPos(v.vertex);o.uv=v.uv;o.normal=UnityObjectToWorldNormal(v.normal);o.world=mul(unity_ObjectToWorld,v.vertex).xyz;return o;}
 float hash(float2 p){return frac(sin(dot(p,float2(127.1,311.7)))*43758.5453);}
 float noise(float2 p){float2 i=floor(p),f=frac(p);f=f*f*(3-2*f);return lerp(lerp(hash(i),hash(i+float2(1,0)),f.x),lerp(hash(i+float2(0,1)),hash(i+1),f.x),f.y);}
 float4 frag(v2f i):SV_Target {float4 c=_Color;float3 N=normalize(i.normal);float3 V=normalize(_WorldSpaceCameraPos-i.world);float diffuse=saturate(dot(N,normalize(float3(-.45,.8,-.5))));float edge=pow(1-abs(dot(N,V)),3);float sheen=pow(saturate(dot(reflect(normalize(float3(.45,-.8,.5)),N),V)),24);c.rgb*=.28+diffuse*.95;c.rgb+=_Color.rgb*edge*.5+sheen*.9;c.rgb+=_Glow*(_Color.rgb*.55+pow(saturate(length(i.uv-.5)),12)*.65);if(_BountyDetail>.5){float grain=noise(i.world.xy*8+_Time.y*float2(.22,-.35));float stroke=pow(saturate(1-abs(sin(i.world.y*23+i.world.x*13+grain*3-_Time.y*8))),10);c.rgb*=.72+grain*.35;c.rgb+=lerp(_Color.rgb,float3(1,.86,.58),.38)*stroke*.58;}if(_Organic>.5){float vein=pow(saturate(1-abs(sin(i.world.y*24+i.world.x*17+noise(i.world.xy*7)*4))),12);float pulse=.65+.35*sin(_Time.y*5+i.world.y*9);c.rgb*=1-vein*.48;c.rgb+=_Color.rgb*vein*pulse*.35;c.rgb+=pow(sheen, .45)*.22;}if(_Soft>.5){c.rgb=_Color.rgb;float2 q=i.uv*2-1;q+=float2(noise(i.uv*4+_Time.y*.4),noise(i.uv*5-_Time.y*.3))*.35-.175;float n=noise(i.uv*5+_Time.y*.5)*.6+noise(i.uv*11-_Time.y*.8)*.4;c.a*=pow(saturate(1-length(q)),1.4)*smoothstep(.15,.75,n)*2.5;}return c;}
 ENDCG }
 }
}
