Shader "Mindstone/EnemySignature/EmeraldToxicVolume"
{
 Properties { _Age("Flow age",Float)=0 _Opacity("Density",Float)=1 _Burst("Explosion",Float)=0 }
 SubShader {
 Tags {"Queue"="Transparent+17" "RenderType"="Transparent"}
 Cull Front ZWrite Off ZTest LEqual Blend One OneMinusSrcAlpha
 Pass {
 CGPROGRAM
 #pragma vertex vert
 #pragma fragment frag
 #pragma target 3.0
 #include "UnityCG.cginc"
 float _Age,_Opacity,_Burst;
 struct v2f{float4 pos:SV_POSITION;float3 local:TEXCOORD0;};
 v2f vert(float4 vertex:POSITION){v2f o;o.pos=UnityObjectToClipPos(vertex);o.local=vertex.xyz;return o;}
 float hash(float3 p){return frac(sin(dot(p,float3(127.1,311.7,74.7)))*43758.5453);}
 float noise(float3 p){float3 a=floor(p),f=frac(p);f=f*f*(3-2*f);return lerp(lerp(lerp(hash(a),hash(a+float3(1,0,0)),f.x),lerp(hash(a+float3(0,1,0)),hash(a+float3(1,1,0)),f.x),f.y),lerp(lerp(hash(a+float3(0,0,1)),hash(a+float3(1,0,1)),f.x),lerp(hash(a+float3(0,1,1)),hash(a+1),f.x),f.y),f.z);}
 float4 frag(v2f i):SV_Target {
 float3 origin=mul(unity_WorldToObject,float4(_WorldSpaceCameraPos,1)).xyz;
 float3 ray=normalize(i.local-origin);
 float3 safe=(step(0,ray)*2-1)*max(abs(ray),.0001);
 float3 a=(-.5-origin)/safe,b=(.5-origin)/safe;
 float3 lo=min(a,b),hi=max(a,b);
 float entry=max(0,max(lo.x,max(lo.y,lo.z))),exit=min(hi.x,min(hi.y,hi.z));
 if(exit<=entry)return 0;
 float stepSize=(exit-entry)/32;float4 sum=0;
 [loop]for(int j=0;j<32;j++){
 float3 q=(origin+ray*(entry+(j+.5)*stepSize))*2;
 // Advected eddies: large cells roll horizontally while finer vapor climbs.
 float3 warped=q;
 float angle=_Age*.11+q.y*.65;
 float sn=sin(angle),cs=cos(angle);
 warped.xz=float2(q.x*cs-q.z*sn,q.x*sn+q.z*cs);
 float3 flow=warped*3.4+float3(_Age*.13,-_Age*.21,_Age*.085);
 flow+=float3(sin(q.z*3.2+_Age*.32),sin(q.x*3.6-_Age*.26),cos(q.y*2.8+_Age*.23))*.32;
 float coarse=noise(flow);
 float mid=noise(flow*2.13+coarse*1.5+float3(-_Age*.10,_Age*.08,0));
 float fine=noise(flow*4.7+float3(3,7,11));
 float fbm=coarse*.56+mid*.29+fine*.15;
 // Lobed, uneven silhouette with dense underside and lit, rolling edges.
 float radius=length(q*float3(.91,1.1,.91));
 float envelope=saturate((1.02-radius+(coarse-.5)*.64)*4);
 envelope*=smoothstep(-1.0,-.76,q.y);
 // Separate rolling pockets and open channels instead of integrating a
 // uniform green sheet across the entire ground footprint.
 float banks=noise(q*float3(2.2,1.3,2.2)+float3(_Age*.045,2,-_Age*.035));
 float channels=smoothstep(.30,.66,banks);
 float density=envelope*smoothstep(.44,.70,fbm)*lerp(.12,1.4,channels)*_Opacity*2.0;
 float upper=noise(flow+float3(0,.45,0));
 float edgeLight=saturate((coarse-upper)*3.5+.32);
 float shade=smoothstep(.36,.75,fbm+q.y*.10+edgeLight*.14);
 float3 gas=lerp(float3(.020,.075,.044),float3(.38,.56,.22),shade);
 float rim=pow(saturate(mid*.5+fine*.5),4)*envelope;
 gas+=float3(.29,.34,.08)*rim*edgeLight*1.6;
 float core=pow(saturate(1-radius),2)*_Burst;
 gas=lerp(gas,float3(.76,1.5,.83),saturate(core*4.5));
 float alpha=1-exp(-density*stepSize*4.3);
 sum.rgb+=(1-sum.a)*gas*alpha;sum.a+=(1-sum.a)*alpha;
 if(sum.a>.97)break;
 }
 return sum;
 }
 ENDCG
 }
 }
}
