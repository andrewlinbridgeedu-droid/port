Shader "Mindstone/EnemySignature/HoundVolumetricInferno"
{
 Properties { _Fire("Authored flame density",2D)="black"{} _Age("Age",Float)=0 _Opacity("Opacity",Float)=1 _Wave("Wave",Float)=0 }
 SubShader {
 Tags {"Queue"="Transparent+17" "RenderType"="Transparent"}
 Cull Front ZWrite Off ZTest LEqual Blend One OneMinusSrcAlpha
 Pass {
 CGPROGRAM
 #pragma vertex vert
 #pragma fragment frag
 #pragma target 3.0
 #include "UnityCG.cginc"
 float _Age,_Opacity,_Wave; sampler2D _Fire;
 struct v2f{float4 pos:SV_POSITION;float3 local:TEXCOORD0;};
 v2f vert(float4 vertex:POSITION){v2f o;o.pos=UnityObjectToClipPos(vertex);o.local=vertex.xyz;return o;}
 float hash(float3 p){return frac(sin(dot(p,float3(127.1,311.7,74.7)))*43758.5453);}
 float noise(float3 p){float3 a=floor(p),f=frac(p);f=f*f*(3-2*f);return lerp(lerp(lerp(hash(a),hash(a+float3(1,0,0)),f.x),lerp(hash(a+float3(0,1,0)),hash(a+float3(1,1,0)),f.x),f.y),lerp(lerp(hash(a+float3(0,0,1)),hash(a+float3(1,0,1)),f.x),lerp(hash(a+float3(0,1,1)),hash(a+1),f.x),f.y),f.z);}
 float4 frag(v2f i):SV_Target {
  float3 origin=mul(unity_WorldToObject,float4(_WorldSpaceCameraPos,1)).xyz;
  float3 ray=normalize(i.local-origin);
  float3 safe=sign(ray)*max(abs(ray),.0001);
  float3 a=(-.5-origin)/safe,b=(.5-origin)/safe;
  float3 lo=min(a,b),hi=max(a,b);
  float entry=max(0,max(lo.x,max(lo.y,lo.z))),exit=min(hi.x,min(hi.y,hi.z));
  if(exit<=entry)return 0;
  float stepSize=(exit-entry)/48;
  float4 sum=0;
  [loop]for(int j=0;j<48;j++){
   float3 q=(origin+ray*(entry+(j+.5)*stepSize))*2;
   float y=q.y*.5+.5;
   // Stretch the advected fine structures vertically: narrow tongues fold
   // around changing 3D cavities instead of filling the box with broad fog.
   float turn=y*(3.7+_Wave*4.3)-_Age*(1.2+_Wave*1.6);
   float sn=sin(turn),cs=cos(turn);
   float2 orbit=float2(q.x*cs-q.z*sn,q.x*sn+q.z*cs);
   float3 flow=float3(orbit.x,y*2-1,orbit.y)*float3(5.8,2.9,6.3)+float3(0,-_Age*3.3,0);
   float coarse=noise(flow);
   float fine=noise(flow*3.17+float3(4,7,-_Age));
   float2 warp=float2(coarse-.5,fine-.5)*.15;
   float2 uvA=frac(float2(q.x*1.6+q.z*.23,y*.72-_Age*.31)+warp);
   float2 uvB=frac(float2(q.z*1.8-q.x*.21,y*.91-_Age*.37)+warp.yx);
   float fA=tex2Dlod(_Fire,float4(uvA,0,0)).r;
   float fB=tex2Dlod(_Fire,float4(uvB,0,0)).r;
   float textureDensity=max(fA*.82,fB*.76);
   float field=coarse*.42+fine*.18+textureDensity*.62;
   // The density vanishes well inside all bounds. Cylindrical falloff and
   // curved rising tongues never sample a visible wall of the bounding box.
   // Bend the density volume itself. High eruption has an offset folded crown;
   // the second spell stays low and sweeps through a tightening foot-level curl.
   float2 bent=q.xz-float2(sin(y*4.8-_Age*2),cos(y*3.7+_Age*1.6))*y*(.21+_Wave*.19);
   float radial=length(bent);
   float angle=atan2(bent.y,bent.x);
   float twist=angle-y*(5.8+_Wave*4.4)+_Age*(_Wave*2.2);
   float curl=pow(saturate(.5+.5*sin(twist*1.73+coarse*1.4+sin(angle*2.3)*.38)),1.8);
   float radius=.70-y*(.26+_Wave*.22)+(coarse-.5)*.15;
   float envelope=1-smoothstep(radius-.20,radius,radial);
   float tip=lerp(.69,.43,_Wave)+.15*sin(angle*2.7-_Age*4)+.08*sin(angle*4.3+_Age*3);
   float shape=envelope*(1-smoothstep(tip-.22,tip,y))*smoothstep(0,.055,y);
   shape*=.12+.88*curl;
   shape*=1-smoothstep(.72,.86,radial);
   // High thresholds create empty channels. Low-density material absorbs very
   // little so the interior's hot fronts remain visible through the envelope.
   float flameSheet=smoothstep(.45,.73,field);
   float density=shape*flameSheet*_Opacity;
   float heat=smoothstep(.52,.83,field);
   float3 flame=lerp(float3(.095,.004,.001),float3(1.45,.14,.004),smoothstep(.43,.60,field));
   flame=lerp(flame,float3(2.25,1.08,.075),heat*heat);
   flame+=float3(.32,.065,.001)*pow(saturate(textureDensity),3);
   float alpha=1-exp(-density*stepSize*4.8);
   sum.rgb+=(1-sum.a)*flame*alpha;
   sum.a+=(1-sum.a)*alpha;
   if(sum.a>.985)break;
  }
  return sum;
 }
 ENDCG
 }
 }
}
