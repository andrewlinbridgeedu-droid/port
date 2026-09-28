// M12 sealed ward: feathers of light, not steel and not a translucent film.
// Each blade-feather is luminous energy: azure -> violet body carrying the
// shared gold filigree/scale matter, a white-hot rim with an inner light line,
// twinkling motes and a tip that dissolves into light. Blades slide out from
// behind the wearer (per-plate delay in color.g, centre in uv2) as _Open
// rises, flash on the lock, then hover and breathe.
Shader "MistHarbor/ArchiveAegis" {
Properties { _MainTex("Unused",2D)="white"{} _Matter("Spectacle matter",2D)="black"{} _ShimmerTime("Time",Float)=0 _DeployPulse("Lock impulse",Float)=0 _Open("Open",Float)=1 }
SubShader { Tags {"Queue"="Transparent+14" "RenderType"="Transparent" "IgnoreProjector"="True"} ZWrite Off Cull Off Blend One OneMinusSrcAlpha
Pass { CGPROGRAM
#pragma target 3.0
#pragma vertex vert
#pragma fragment frag
#include "UnityCG.cginc"
sampler2D _Matter; float _ShimmerTime,_DeployPulse,_Open;
struct a {float4 vertex:POSITION;float2 uv:TEXCOORD0;float3 centre:TEXCOORD1;float4 color:COLOR;};
struct v {float4 pos:SV_POSITION;float2 uv:TEXCOORD0;float4 color:COLOR;float open:TEXCOORD1;};
float hash(float n){return frac(sin(n*127.1+311.7)*43758.5453);}
float hash2(float2 p){return frac(sin(dot(p,float2(127.1,311.7)))*43758.5453);}
v vert(a i){
 v o;
 float id=i.color.r*37;
 float open=smoothstep(0,1,saturate((_Open*1.35-i.color.g)/.55));
 float3 c=i.centre, start=float3(c.x*.2,c.y,c.z+.14);
 float3 p=lerp(start,c,open)+(i.vertex.xyz-c)*lerp(.55,1,open);
 // Light armour hovers: each feather drifts on its own slow beat.
 p.y+=.012*sin(_ShimmerTime*1.7+id*1.3)*open;
 p.x+=.006*sin(_ShimmerTime*1.1+id*2.1)*open;
 o.pos=UnityObjectToClipPos(float4(p,1));
 o.uv=i.uv;o.color=i.color;o.open=open;
 return o;
}
float4 frag(v i):SV_Target {
 float x=i.uv.x*2-1,y=i.uv.y,id=i.color.r*37,t=_ShimmerTime;
 float e=min(1-abs(x),min(y*3.2,(1-y)*1.6));
 // Shared filigree matter (row 0 of SpectacleMatter), flowing out along the feather.
 float4 f=tex2D(_Matter,float2(y*1.35-t*.16+id*.37,(7+saturate(x*.46+.5))/8));
 float3 azure=float3(.04,.42,1.0), cyan=float3(.20,.85,1.0), violet=float3(.46,.16,1.0), gold=float3(1,.76,.28);
 // Root runs hot cyan, the blade deepens to azure then violet toward the tip.
 float3 body=lerp(cyan,azure,smoothstep(0,.4,y));
 body=lerp(body,violet,smoothstep(.45,1,y+.12*x));
 body*=.7+.6*f.g;
 float rimCore=exp(-e/.016), rimGlow=exp(-e/.075);
 float innerLine=exp(-abs(e-.2)/.022);
 float breathe=.85+.15*sin(t*2.2+id*1.9);
 float twinkle=step(.982,hash2(floor(float2(x*9,y*34))+floor(t*7+id)))*smoothstep(.1,.3,e);
 float3 col=body*breathe*1.15
   +cyan*(rimGlow*(1.1+1.8*_DeployPulse)+innerLine*.7)
   +float3(1,.97,.9)*(rimCore*.9+f.b*.5+twinkle*1.1);
 // Gold scrollwork replaces the blade colour (adding it to cyan only whitens it).
 col=lerp(col,gold*(1.25+.9*_DeployPulse),saturate(f.r*.85));
 // Sliding out: a bright streak along each feather; lock: whole feather flares.
 col+=cyan*(1-i.open)*.7+float3(.7,.9,1)*_DeployPulse*.35;
 // The outer tip dissolves into light instead of ending in a hard point.
 float tipFade=1-smoothstep(.62,1,y)*(.55+.45*(1-f.g));
 float shape=smoothstep(0,.03,e);
 float cover=shape*saturate(.42+.28*f.g+rimGlow*.6+innerLine*.25+f.r*.3)*tipFade*i.color.a*saturate(i.open*3);
 clip(cover-.004);
 // Premultiplied glow: colour exceeds coverage so it reads as light, while
 // partial coverage keeps the hue on bright marble instead of washing white.
 return float4(col*cover,cover*.78);
}
ENDCG
}}}
