Shader "Mistport/RiftFlood" {
Properties { _MainTex("Grain",2D)="white"{} _FxTime("Time",Float)=0 }
SubShader { Tags {"Queue"="Transparent-8" "RenderType"="Transparent"} Cull Off ZWrite Off Blend One OneMinusSrcAlpha
Pass { CGPROGRAM
#pragma vertex vert
#pragma fragment frag
#include "UnityCG.cginc"
sampler2D _MainTex; float _FxTime;
struct a {float4 vertex:POSITION;float2 uv:TEXCOORD0;};struct v{float4 pos:SV_POSITION;float2 uv:TEXCOORD0;};
v vert(a i){v o;o.pos=UnityObjectToClipPos(i.vertex);o.uv=i.uv;return o;}
float hash(float2 p){return frac(sin(dot(p,float2(127.1,311.7)))*43758.5453);}
float noise(float2 p){float2 q=floor(p),f=frac(p);f=f*f*(3-2*f);return lerp(lerp(hash(q),hash(q+float2(1,0)),f.x),lerp(hash(q+float2(0,1)),hash(q+1),f.x),f.y);}
float4 frag(v i):SV_Target{
float t=_FxTime,z=i.uv.y,x=(i.uv.x-.5)*2;
float n=noise(float2(z*29,x*13));float fine=noise(float2(z*85,x*35));
float border=.12+.08*noise(float2(z*23,4))+.045*noise(float2(z*67,9));
float d=abs(x+.045*(noise(float2(z*9,3))-.5))-border;
float arrival=.16+z*.62;float age=t-arrival;
float opening=smoothstep(0,.09,age);float ending=1-smoothstep(1.45,2.15,t);
float core=1-smoothstep(-.012,.003,d);
float lip=exp(-abs(d)*95);
float outward=max(0,d);float extent=(.47+.18*noise(float2(z*13,7))+.10*n)*smoothstep(0,.16,z)*(1-smoothstep(.82,1,z));
float heat=pow(saturate(1-outward/max(.01,extent)),.65)*(1-core);
float streak=noise(float2(z*55-outward*7,outward*5-t*1.4));
float3 col=lerp(float3(.65,.008,.001),float3(1,.20,.002),saturate(1-outward*2.3+streak*.3));
col*=.8+streak*.38;col=lerp(col,float3(.005,.035,.039)+float3(.003,.027,.03)*noise(float2(z*28,x*22)),core);
float grain=tex2D(_MainTex,float2(z,i.uv.x)).r; col*=.86+grain*.28; col+=float3(1.6,1.15,.30)*lip;
float a=max(core*.98,heat*.87)*opening*ending*smoothstep(0,.035,z)*(1-smoothstep(.94,1,z));
return float4(col*a,a);
}
ENDCG }}}
