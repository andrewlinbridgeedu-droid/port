Shader "Mistport/BonePattern20260920" {
 Properties{_MainTex("Texture",2D)="white"{} _Color("Tint",Color)=(1,1,1,1) _Luma("Luminance alpha",Float)=1 _Dissolve("Dissolve",Range(0,1))=0 _Dst("Destination",Float)=1 _Ribbon("Ribbon",Float)=0 _Pattern("Pattern",Float)=0 _Age("Visual age",Float)=0}
 SubShader{Tags{"Queue"="Transparent+18" "RenderType"="Transparent"} Blend SrcAlpha [_Dst] ZWrite Off Cull Off
 Pass{CGPROGRAM
 #pragma vertex vert
 #pragma fragment frag
 #include "UnityCG.cginc"
 struct appdata{float4 vertex:POSITION;float2 uv:TEXCOORD0;};struct v2f{float4 pos:SV_POSITION;float2 uv:TEXCOORD0;};sampler2D _MainTex;float4 _Color;float _Luma,_Dissolve,_Ribbon,_Pattern,_Age;
 v2f vert(appdata v){v2f o;o.pos=UnityObjectToClipPos(v.vertex);o.uv=v.uv;return o;}
 float4 frag(v2f i):SV_Target{if(_Ribbon>.5){float core=pow(saturate(1-abs(i.uv.x*2-1)),3);float tail=pow(saturate(sin(i.uv.y*3.1415926)),.5);return float4(_Color.rgb,_Color.a*core*tail);}
 float2 p=(i.uv-.5)*2;float r=length(p);float angle=atan2(p.y,p.x);float noise=tex2D(_MainTex,i.uv*1.7+float2(.13,.27)).r;float shape,vein;
 if(_Pattern<.5){float drift=.046*sin(p.y*5.7)+.012*sin(p.y*19.1);float x=p.x-drift;float edge=(.09+.018*sin(p.y*8.3))*(1-p.y*p.y)+.006*sin(p.y*31);shape=saturate((edge-abs(x))*35)*saturate((1-abs(p.y))*12);vein=pow(saturate(1-abs(x)/(edge+.001)),10)*(.67+.33*sin(p.y*29-_Age*17));}
 else if(_Pattern<1.5){float warp=.11*sin(p.x*9+1.2)+.055*sin(p.x*23+p.y*7);float yy=p.y+warp;float tear=abs(yy-(.13*p.x*p.x-.22));float band=saturate((.13+.055*sin(p.x*17)-tear)*18);float gaps=smoothstep(-.25,.35,sin(p.x*11+.8)+.65*sin(p.x*27));shape=band*gaps*saturate((1-abs(p.x))*8);vein=pow(saturate(1-tear/.10),5)*(.5+.5*sin(p.x*31+noise*8));}

 else{float edge=.65+.12*sin(angle*7)+.06*sin(angle*13);shape=saturate((edge-r)*18);float crack=abs(sin(angle*2.7+sin(r*17+angle*1.6)*.38));vein=pow(saturate(1-crack),14)*(.68+.32*sin(r*38-_Age*15));shape*=.5+.5*noise;}
 float erosion=saturate(1-_Dissolve*1.4);float3 ink=_Color.rgb*(.22+noise*.55+vein*1.7);return float4(ink,shape*_Color.a*erosion);}

 ENDCG}
 }
}
