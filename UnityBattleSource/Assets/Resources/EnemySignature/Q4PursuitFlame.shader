Shader "Mindstone/EnemySignature/Q4PursuitFlame" {
 Properties { _Tint("Tint",Color)=(1,.28,.02,1) _Age("Age",Float)=0 _Mode("Mode",Float)=0 _Power("Power",Float)=1 }
 SubShader { Tags {"Queue"="Transparent+25" "RenderType"="Transparent"} Blend SrcAlpha One ZWrite Off Cull Off
 Pass { CGPROGRAM
 #pragma vertex vert
 #pragma fragment frag
 #pragma target 3.0
 #include "UnityCG.cginc"
 struct app { float4 vertex:POSITION;float2 uv:TEXCOORD0;};
 struct vary {float4 pos:SV_POSITION;float2 uv:TEXCOORD0;};
 float4 _Tint;float _Age,_Mode,_Power;
 vary vert(app v){vary o;o.pos=UnityObjectToClipPos(v.vertex);o.uv=v.uv;return o;}
 float hash(float2 p){return frac(sin(dot(p,float2(127.1,311.7)))*43758.5453);}
 float noise(float2 p){float2 i=floor(p),f=frac(p);f=f*f*(3-2*f);return lerp(lerp(hash(i),hash(i+float2(1,0)),f.x),lerp(hash(i+float2(0,1)),hash(i+1),f.x),f.y);}
 float fbm(float2 p){return noise(p)*.57+noise(p*2.07+17)*.28+noise(p*4.13+9)*.15;}
 float4 frag(vary i):SV_Target {
 float2 p=(i.uv-.5)*2;float r=length(p);float a=atan2(p.y,p.x);float t=_Age;
 float n=fbm(p*4+float2(t*.8,-t*2.8));
 float swirl=fbm(float2(a*2.8+r*3-t*3,r*5-t*2));
 float boundary=1-smoothstep(.40+n*.24,.77+n*.22,r);
 float heat=saturate((1-r)*1.3+swirl*.55-.26);
 float3 c=lerp(float3(.65,.025,.002),float3(1,.34,.018),heat);
 c=lerp(c,float3(1,.90,.38),pow(heat,4));
 float alpha=boundary*(.48+n*.52);
 if(_Mode>.5 && _Mode<1.5){
 // Unequal folded combustion fronts, not a complete radial shock ring.
 float2 warp=p+float2(n-.5,swirl-.5)*.26;
 float upper=exp(-pow((warp.x+.16+warp.y*.36)/.20,2)-pow((warp.y-.23)/.49,2));
 float left=exp(-pow((warp.x+.34)/.37,2)-pow((warp.y+.17+warp.x*.42)/.16,2));
 float right=exp(-pow((warp.x-.35)/.32,2)-pow((warp.y-.03-sin(warp.x*5)*.16)/.20,2));
 float torn=smoothstep(.23,.68,n*.62+swirl*.6);
 float fronts=(upper+left*.87+right*.78)*torn;
 alpha=saturate(fronts*.9+boundary*.13)*(1-smoothstep(.84,.98,r));
 c=lerp(float3(.95,.065,.004),float3(1,.76,.24),saturate(fronts));
 }
 return float4(c*_Tint.rgb*_Power,alpha*_Tint.a);
 }
 ENDCG }
 }
}
