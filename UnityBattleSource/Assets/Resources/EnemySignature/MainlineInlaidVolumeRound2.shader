Shader "Mindstone/Mainline/InlaidVolumeRound2" {
 Properties { _MemoryArt("Torn memory paper",2D)="white"{} _GoldBodyArt("Painted copper contract",2D)="white"{} _GoldArt("Painted gold engraving",2D)="white"{} _FlowArt("Painted rift fibres",2D)="white"{} _PaperArt("Painted memory fragments",2D)="white"{} _VenomArt("Painted living vein",2D)="white"{}  _Impact ("Contact accent",Float)=0 _Age ("Presentation age",Float)=0 _Motif ("Material identity",Float)=0 }
 SubShader {
  Tags { "Queue"="Transparent+17" "RenderType"="Transparent" }
  // Filled colour survives overlap. The older additive shader is still used by
  // other workers; do not change its blend mode underneath those recordings.
  Blend SrcAlpha OneMinusSrcAlpha ZWrite Off Cull Off
  Pass {
   CGPROGRAM
   #pragma target 3.0
   #pragma vertex vert
   #pragma fragment frag
   #include "UnityCG.cginc"
   float _Age,_Motif,_Impact; sampler2D _GoldArt,_GoldBodyArt,_FlowArt,_PaperArt,_VenomArt,_MemoryArt;
   struct appdata { float4 vertex:POSITION;float4 color:COLOR;float2 uv:TEXCOORD0; };
   struct v2f { float4 pos:SV_POSITION;float4 color:COLOR;float2 uv:TEXCOORD0; };
   v2f vert(appdata v){v2f o;o.pos=UnityObjectToClipPos(v.vertex);o.color=v.color;o.uv=v.uv;return o;}
   float4 frag(v2f i):SV_Target {
    float x=i.uv.x*2-1,y=i.uv.y;
    float edge=smoothstep(0,.16,1-abs(x))*smoothstep(0,.045,y)*smoothstep(0,.07,1-y);
    float curl=.29*sin(y*8.3)+.12*sin(y*19.7+.8);
    float distance=x-curl;
    float carved=exp(-pow(distance/.080,2)),inlay=exp(-pow(distance/.026,2));
    // Short, curved branches are interior engraving, not separate spokes/ribs.
    float branch=pow(saturate(cos(y*33+sin(y*12)*2.3-abs(distance)*9)),22);
    branch*=smoothstep(.05,.22,abs(distance))*(1-smoothstep(.45,.81,abs(x)));
    float moving=exp(-pow((y-frac(_Age*.32))/.10,2));
    float grain=sin(y*121+x*49)*sin(y*59-x*77);
    float relief=.58+.31*cos(x*2.8+.35*sin(y*9))+.10*sin(y*13+x*4);
    float cold=saturate((i.color.b-i.color.r)*2.4);
    float3 gold=lerp(float3(1,.70,.22),float3(.45,.85,1),cold);
    float3 base=i.color.rgb*(relief-carved*.23+grain*.025);
    float ornament=inlay*.86+branch*.39;
    if(_Motif>.5&&_Motif<1.5) {
     float script=pow(saturate(sin(y*39+x*12+sin(y*17)*2)),8);
     base=i.color.rgb*(relief*.82-script*.22);gold=float3(.99,.68,.31);
     ornament=inlay*.82+branch*.45;
    }
    if(_Motif>1.5&&_Motif<2.5) {
     base=i.color.rgb*(.44+.27*sin(y*9+x*5)*sin(y*7-x*8)+relief*.3);
     gold=float3(.74,.86,.18);ornament=inlay*.48+branch*.18;
    }
    if(_Motif>2.5&&_Motif<4.5)base*=.84;
    // M20 only: two unequal, longitudinal handwritten strokes, not periodic ribs.
    // All existing motif branches and their default rendering stay unchanged.
    if(_Motif>19.5&&_Motif<20.5) {
     float pathA=-.20+.22*sin(y*5.4+.6)+y*.10;
     float pathB=.40-.47*y+.13*sin(y*8.1+1.3);
     float windowA=smoothstep(.08,.18,y)*(1-smoothstep(.78,.94,y));
     float windowB=smoothstep(.29,.42,y)*(1-smoothstep(.64,.82,y));
     float strokeA=exp(-pow((x-pathA)/.026,2))*windowA;
     float strokeB=exp(-pow((x-pathB)/.021,2))*windowB;
     float inkGroove=exp(-pow((x-pathA)/.075,2))*windowA;
     base=i.color.rgb*(relief*.86-inkGroove*.18+grain*.012);
     gold=float3(.99,.68,.31);ornament=strokeA*.88+strokeB*.62;
     inlay=strokeA;
    }
    // New identities opt in; approved existing effects are unchanged.
    if(_Motif>29.5){
     float2 drift=float2(sin(y*13+x*7-_Age*7),cos(y*11+x*5+_Age*5))*.008;
     float4 art;
     if(_Motif<30.5){
      float2 bodyUV=float2(.20+y*.57+x*.18,.13+y*.72-x*.21)+drift;
      art=tex2D(_GoldBodyArt,bodyUV);
      float4 filigree=tex2D(_GoldArt,float2(.03+y*.94,.5+x*.33)+drift);
      float thread=saturate(max(filigree.r,max(filigree.g,filigree.b)));
      float light=max(art.r*.72+art.g*.28-art.b*.27,0);
      float reliefGlow=smoothstep(.42,.90,light);
      base=art.rgb*(.78+.25*relief)+float3(.46,.21,.06)*(1-art.a);
      base*=lerp(float3(.82,.80,.95),saturate(i.color.rgb)*.6+.55,.25);
      gold=lerp(float3(1.32,.41,.04),float3(1.82,1.48,.58),reliefGlow);
      ornament=thread*.28+reliefGlow*(.36+_Impact*.22);inlay=pow(reliefGlow,3);
      edge*=.66+saturate(art.a)*.34;
     }else if(_Motif<34.5){
      if(_Motif>33.5)art=tex2D(_MemoryArt,float2(.355+(.5+x*.5)*.29+y*.025,.20+y*.58-x*.04)+drift*.28);
      else art=tex2D(_FlowArt,float2(.18+(.5+x*.5)*.60,.07+y*.86)+drift);
      float lum=dot(art.rgb,float3(.26,.49,.25));
      float thread=smoothstep(.26,.78,lum);
      base=i.color.rgb*(.18+lum*1.30);
      
      gold=lerp(i.color.rgb,float3(1.35,1.55,1.60),.54);
      ornament=thread*(.44+_Impact*.35);inlay=pow(thread,3);
      if(_Motif<33.5)edge*=saturate(art.a*.86+.14);
      if(_Motif<31.5)edge*=.72;
      if(_Motif>33.5){
       // Retain fibrous paper and dark handwritten names, not heated metal or
       // cold crystal ridges. Movement comes from the soft physical page fold.
       base=art.rgb*(.72+.22*cos(x*1.7+y*1.3))*float3(.91,.97,1.06);
       float inkDepth=1-smoothstep(.17,.66,lum);
       base=lerp(base,float3(.022,.014,.115),inkDepth*.76);
       float fibreRim=exp(-pow((abs(x)-(.82+.035*sin(y*17.7)))/.075,2));
       float brokenLight=.45+.55*smoothstep(-.3,.65,sin(y*15.4+x*6.2));
       base+=float3(.26,.13,1.06)*fibreRim*brokenLight*(.55+_Impact*.35);
       gold=float3(.34,.42,.70);ornament=0;inlay=0;
       edge*=saturate(art.a*1.25);
      }
     }else{
      art=tex2D(_VenomArt,float2(.5+x*.27,.06+y*.9)+drift);
      float vein=max(art.g-art.r*.36,0),shine=smoothstep(.30,.8,vein);
      base=art.rgb*float3(.75,1.35,.42)+i.color.rgb*.13;
      gold=float3(1.4,1.65,.35);ornament=shine*.76;inlay=pow(shine,3);
      edge*=saturate(art.a+.17);
     }
     // Erosion follows the painted fibres as well as the actual uneven mesh.
     edge*=smoothstep(0,.14,.87+.12*sin(y*19.7+_Motif)-abs(x));
    }
    float3 color=base+gold*ornament*(.69+moving*.32);
    // Contact heats only a narrow inlay. No whole-face white multiplication.
    color+=gold*inlay*saturate(_Impact)*.32;
    float alpha=edge*i.color.a*(.80+.14*relief);
    clip(alpha-.003);
    return float4(color,saturate(alpha));
   }
   ENDCG
  }
 }
}
