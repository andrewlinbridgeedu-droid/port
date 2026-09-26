Shader "Mistport/MinionSurface20260921" {
 Properties { _Color("Color",Color)=(1,1,1,1) _MainTex("Texture",2D)="white"{} _Clock("Clock",Float)=0 _Crop("Texture region",Vector)=(0,0,1,1) _Seed("Unequal surface seed",Float)=0 _Lucent("Inner translucency",Float)=1 _Flame("Flame atlas",Float)=0 _Flare("Contact inner light",Float)=0 _Claw("Diagonal authored claw",Float)=0 }
 SubShader { Tags { "Queue"="Transparent+17" "RenderType"="Transparent" } Blend SrcAlpha OneMinusSrcAlpha Cull Off ZWrite Off
 Pass { CGPROGRAM
 #pragma vertex vert
 #pragma fragment frag
 #include "UnityCG.cginc"
 struct appdata {float4 vertex:POSITION;float3 normal:NORMAL;float2 uv:TEXCOORD0;};
 struct v2f {float4 pos:SV_POSITION;float2 uv:TEXCOORD0;float3 normal:TEXCOORD1;};
 float4 _Color,_Crop;float _Clock,_Seed,_Lucent,_Flame,_Flare,_Claw;sampler2D _MainTex;
 float hash(float2 p){return frac(sin(dot(p,float2(127.1,311.7)))*43758.5453);}
 float noise(float2 p){float2 a=floor(p),b=frac(p);b=b*b*(3-2*b);return lerp(lerp(hash(a),hash(a+float2(1,0)),b.x),lerp(hash(a+float2(0,1)),hash(a+1),b.x),b.y);}
 v2f vert(appdata v){v2f o;o.pos=UnityObjectToClipPos(v.vertex);o.uv=v.uv;o.normal=UnityObjectToWorldNormal(v.normal);return o;}
 float4 frag(v2f i):SV_Target {
  float2 uv=i.uv;float flow=noise(float2(uv.x*8-_Clock*.9,_Seed+uv.y*2));
  float rag=noise(float2(uv.x*21+_Seed,uv.y*6-_Clock*.35));
  float profile=pow(saturate(sin(uv.x*3.14159)),.48);
  float boundary=(.37+.10*flow+.055*rag)*profile;
  float edge=1-smoothstep(boundary-.055,boundary,abs(uv.y-.5));
  edge*=smoothstep(0,.04,uv.x)*smoothstep(0,.065,1-uv.x);
  float2 artUV=saturate(uv+float2((flow-.5)*.055-_Clock*.009,(rag-.5)*.04));
  artUV=lerp(artUV,artUV.yx,_Flame);
  float2 clawUV=lerp(float2(.10,.90),float2(.66,.13),artUV.x)+float2(.20,.15)*(artUV.y-.5);
  artUV=lerp(artUV,clawUV,_Claw);
  float4 art=tex2D(_MainTex,artUV*_Crop.zw+_Crop.xy);float grain=max(art.r,max(art.g,art.b));
  grain=lerp(grain,pow(saturate(grain),.52),_Claw);
  float detail=noise(float2(uv.x*33-_Clock*2.1,uv.y*13+_Seed));
  float vein=pow(saturate((grain-.32)*1.5+detail*.32),3);
  float rim=pow(saturate(abs(uv.y-.5)/max(.001,boundary)),6);
  float shade=.38+.62*abs(dot(normalize(i.normal),normalize(float3(.4,.8,-.6))));
  float3 color=_Color.rgb*(.30*shade+grain*(.90+.24*flow)+vein*.37)+lerp(_Color.rgb,float3(1,1,1),.7)*rim*.20;
  float hot=pow(saturate(grain-.24),2)*(_Flame*.62+_Flare*.65);
  color+=lerp(_Color.rgb,float3(1,.92,.72),.70)*hot;
  float ink=lerp(art.a,.72,saturate(_Lucent-1)*2);
  float body=smoothstep(.025,.25,grain+max(0,_Lucent-1)*.40);
  return float4(color*_Lucent,_Color.a*edge*ink*body);
 }
 ENDCG }
 }
}
