Shader "Mindstone/EnemySignature/EmeraldPoisonFog"
{
 Properties { _MainTex("Smoke density",2D)="white"{} }
 SubShader {
 Tags { "Queue"="Transparent+10" "RenderType"="Transparent" }
 Blend SrcAlpha OneMinusSrcAlpha ZWrite Off Cull Off
 Pass {
 CGPROGRAM
 #pragma target 3.0
 #pragma vertex vert
 #pragma fragment frag
 #include "UnityCG.cginc"
 sampler2D _MainTex; float _FlowAge;
 float hash(float2 p){return frac(sin(dot(p,float2(127.1,311.7)))*43758.5453);}
 float noise(float2 p){float2 a=floor(p),f=frac(p);f=f*f*(3-2*f);return lerp(lerp(hash(a),hash(a+float2(1,0)),f.x),lerp(hash(a+float2(0,1)),hash(a+1),f.x),f.y);}
 struct a2v {float4 vertex:POSITION;float4 color:COLOR;float2 uv:TEXCOORD0;};
 struct v2f {float4 pos:SV_POSITION;float4 color:COLOR;float2 uv:TEXCOORD0;float3 world:TEXCOORD1;};
 v2f vert(a2v v){v2f o;o.pos=UnityObjectToClipPos(v.vertex);o.color=v.color;o.uv=v.uv;o.world=mul(unity_ObjectToWorld,v.vertex).xyz;return o;}
 float4 frag(v2f i):SV_Target {
 float2 p=i.uv*2-1;
 float2 drift=float2(_FlowAge*.075,-_FlowAge*.065);
 float strata=sin(i.world.x*.73+i.world.z*.56+_FlowAge*.37)*.11;
 float2 swept=i.uv+float2(sin(i.world.z*.51+_FlowAge*.24)*.045,strata);
 float broad=noise(swept*4+drift);
 float curl=noise(swept*8+float2(broad,-broad)*1.4-drift*.7);
 float fine=noise(i.uv*17+curl-drift);
 float edge=pow(saturate(1-dot(p,p)),1.4);
 edge*=.83+.17*noise(i.world.xz*.58+float2(_FlowAge*.12,-_FlowAge*.08));
 float d=smoothstep(.26,.78,broad*.48+curl*.37+fine*.15)*edge;
 float light=saturate(curl*.6+fine*.3+i.uv.y*.2);
 float3 rgb=lerp(float3(.015,.070,.040),i.color.rgb,light);
 rgb+=float3(.15,.17,.025)*pow(saturate(curl),5)*edge;
 return float4(rgb,d*i.color.a);

 }
 ENDCG
 }
 }
}
