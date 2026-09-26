Shader "Mistport/Character Surface 20260916"
{
 Properties {
  _MainTex("Authored albedo",2D)="white"{} _Color("Identity tint",Color)=(1,1,1,1)
  _BumpMap("Authored tangent normal",2D)="bump"{} _BumpScale("Normal strength",Float)=1
  _MetallicGlossMap("Standard metal R smoothness A",2D)="white"{}
  _MetallicRoughness("GLTF metal B roughness G",2D)="white"{}
  _SurfaceMetalMap("Linear separate metal",2D)="black"{} _SurfaceRoughMap("Linear separate roughness",2D)="white"{}
  _Metallic("Metallic fallback",Range(0,1))=0 _Glossiness("Smoothness fallback",Range(0,1))=.4
  _GlossMapScale("Packed smoothness",Float)=1
  _OcclusionMap("Authored AO",2D)="white"{} _OcclusionStrength("AO strength",Range(0,1))=1
  _EmissionMap("Authored emission mask",2D)="white"{} _EmissionColor("Original emission",Color)=(0,0,0,1)
  _SurfaceMaps("0 scalar 1 packed 2 separate 3 GLTF 4 story detail",Float)=0
  _SurfaceRoughCenter("Source roughness center",Float)=.88 _SurfaceRoughDetail("Source roughness variation",Float)=.65
  _SurfaceNormal("Has normal",Float)=0 _SurfaceEmission("Has emission",Float)=0
  _SurfaceFamily("Family",Float)=0 _SurfaceRoughBias("Nonmetal roughness bias",Float)=.04
  _SurfaceMetalFloor("Metal roughness floor",Float)=.22 _SurfaceClothFloor("Cloth roughness floor",Float)=.55
  _SurfaceArt("Material-specific finish",Float)=0
  _HealPulse("Confirmed healing",Range(0,1))=0
  _SurfaceCull("Cull",Float)=2
  _ExitOpacity("Exit opacity",Range(0,1))=1 _Cutoff("Alpha cutoff",Float)=.5 _SurfaceCutout("Cutout",Float)=0
 }
 SubShader {
  Tags {"RenderType"="Opaque" "Queue"="Geometry"}
  Cull [_SurfaceCull]
  CGPROGRAM
  #pragma surface surf Standard fullforwardshadows addshadow
  #pragma target 3.0
  #include "UnityStandardUtils.cginc"
  sampler2D _MainTex,_BumpMap,_MetallicGlossMap,_MetallicRoughness,_SurfaceMetalMap,_SurfaceRoughMap,_OcclusionMap,_EmissionMap;
  fixed4 _Color,_EmissionColor;
  half _BumpScale,_Metallic,_Glossiness,_GlossMapScale,_OcclusionStrength,_SurfaceMaps,_SurfaceNormal,_SurfaceEmission;
  half _SurfaceArt,_HealPulse,_SurfaceRoughCenter,_SurfaceRoughDetail;
  half _SurfaceFamily,_SurfaceRoughBias,_SurfaceMetalFloor,_SurfaceClothFloor,_ExitOpacity,_Cutoff,_SurfaceCutout;
  struct Input {float2 uv_MainTex; float3 viewDir;};
  void surf(Input i,inout SurfaceOutputStandard o) {
   fixed4 paint=tex2D(_MainTex,i.uv_MainTex)*_Color;
   if(_SurfaceCutout>.5) clip(paint.a-_Cutoff);
   half metal=_Metallic,rough=1-_Glossiness;
   half authoredAO=tex2D(_OcclusionMap,i.uv_MainTex).g;
   if(_SurfaceMaps>.5 && _SurfaceMaps<1.5) {half4 channels=tex2D(_MetallicGlossMap,i.uv_MainTex);metal=channels.r;rough=1-channels.a*_GlossMapScale;}
   if(_SurfaceMaps>1.5 && _SurfaceMaps<2.5) {metal=tex2D(_SurfaceMetalMap,i.uv_MainTex).r;rough=tex2D(_SurfaceRoughMap,i.uv_MainTex).r;}
   if(_SurfaceMaps>2.5) {
    half4 channels=tex2D(_MetallicRoughness,i.uv_MainTex);
    if(_SurfaceMaps<3.5) {metal=channels.b;rough=channels.g;}
    else {rough+=(channels.g-_SurfaceRoughCenter)*_SurfaceRoughDetail;authoredAO=channels.r;}
   }
   // Preserve painted segmentation: metal uses the authored metallic mask;
   // cloth/skin retains a broader, softer highlight rather than a plastic coat.
   metal=saturate(metal);
   half floorRough=lerp(_SurfaceClothFloor,_SurfaceMetalFloor,metal);
   rough=clamp(max(rough+_SurfaceRoughBias*(1-metal),floorRough),.14,.96);
   half3 normal=lerp(half3(0,0,1),UnpackScaleNormal(tex2D(_BumpMap,i.uv_MainTex),_BumpScale),_SurfaceNormal);
   // Screen-space normal variance broadens highlights on minified detail.
   // Prevent isolated sparkling texels on skin/cloth without flattening the painted forms.
   half3 dx=ddx(normal),dy=ddy(normal);
   half variance=min(.12, .35*(dot(dx,dx)+dot(dy,dy)));
   rough=sqrt(saturate(rough*rough+variance));
   if(abs(_SurfaceFamily-4)<.25) {metal=min(metal,.06);rough=clamp(rough,.34,.70);} // moist organic leech, not chrome
   if(abs(_SurfaceFamily-3)<.25) {metal=min(metal,.08);rough=max(rough,.64);} // ghosts retain soft depth
   // Authored pigments, not a global tint: the generated metallic atlas overstates
   // metal on skin, cloth, fur and bone. Separate those responses before lighting.
   half luminance=dot(paint.rgb,half3(.2126,.7152,.0722));
   half chroma=max(paint.r,max(paint.g,paint.b))-min(paint.r,min(paint.g,paint.b));
   if(_SurfaceArt>.5) {
    if(abs(_SurfaceFamily-0)<.25) {
     // Story materials already have explicit regions; only legacy iron uses this finish.
     if(_SurfaceMaps<3.5) {metal=min(metal,.72);rough=max(rough,.42);paint.rgb*=half3(.88,.92,1.02);}
    }
    if(abs(_SurfaceFamily-1)<.25) {
     // Black fur needs a readable midtone, without bleaching the muzzle/teeth.
     half fur=(1-smoothstep(.22,.52,luminance));
     paint.rgb+=half3(.021,.019,.017)*fur;
     metal=min(metal,.035);rough=max(rough,.76);normal=normalize(lerp(half3(0,0,1),normal,.8));
    }
    if(abs(_SurfaceFamily-2)<.25) {
     half eye=saturate((paint.r-max(paint.g,paint.b))*5);
     metal=lerp(min(metal,.64),.04,eye);rough=lerp(max(rough,.44),.28,eye);
     paint.rgb*=lerp(half3(.78,.86,.98),half3(1,.92,.86),eye);
    }
    if(abs(_SurfaceFamily-3)<.25) {
     // Woven spectral shroud: darker folds, luminous edges, no chrome-blue shell.
     paint.rgb*=half3(.60,.70,.78);metal=0;rough=.86;
     normal=normalize(lerp(half3(0,0,1),normal,.68));
    }
    if(abs(_SurfaceFamily-4)<.25) {
     // Damp organic hide retains broad highlights rather than white hard specular.
     half pale=smoothstep(.35,.82,luminance);
     paint.rgb*=lerp(half3(.93,.90,1.0),half3(.73,.78,.84),pale);
     metal=0;rough=clamp(rough,.44,.67);
    }
    if(abs(_SurfaceFamily-5)<.25) {
     half green=saturate((paint.g-paint.r)*8)*saturate((paint.g-paint.b)*8);
     half brass=saturate((paint.r-paint.b)*5)*saturate((paint.g-paint.b)*4)*(1-green)*smoothstep(.20,.45,chroma/max(.02,max(paint.r,max(paint.g,paint.b))));
     half bone=smoothstep(.40,.75,luminance)*(1-saturate(chroma*3));
     metal=lerp(.02,min(metal,.68),brass);
     rough=max(rough,lerp(.70,.40,brass));
     paint.rgb*=lerp(half3(.84,.92,.88),half3(.48,.44,.38),bone);
     normal=normalize(lerp(half3(0,0,1),normal,.72));
    }
    if(abs(_SurfaceFamily-6)<.25) {
     // Ivory enamel sits over metal, with dark mechanical joints retained.
     half enamel=smoothstep(.32,.72,luminance)*(1-saturate(chroma*2.6));
     metal=lerp(min(metal,.8),.06,enamel);rough=max(rough,lerp(.32,.49,enamel));
     paint.rgb*=lerp(half3(.87,.92,1.03),half3(.91,.88,.79),enamel);
     normal=normalize(lerp(normal,half3(0,0,1),enamel*.24));
    }
    if(abs(_SurfaceFamily-7)<.25) {
     half brass=saturate((paint.r-paint.b)*5)*saturate((paint.g-paint.b)*6);
     metal=lerp(.025,min(metal,.78),brass);rough=max(rough,lerp(.74,.34,brass));
     paint.rgb+=half3(.018,.017,.016)*(1-brass)*(1-smoothstep(.2,.5,luminance));
    }
    if(abs(_SurfaceFamily-8)<.25) {
     half silk=saturate((paint.r-max(paint.g,paint.b))*5);
     half ivory=smoothstep(.40,.72,luminance)*(1-saturate(chroma*2.4));
     // Human face/hands and woven red cloth cannot inherit metallic generated masks.
     metal=min(metal,.28)*(1-max(silk,ivory));
     rough=max(rough,lerp(.52,.78,silk));
     paint.rgb*=lerp(half3(1,.91,.90),half3(.90,.73,.76),silk);
     paint.rgb*=lerp(half3(1,1,1),half3(.92,.82,.76),ivory);
     normal=normalize(lerp(normal,half3(0,0,1),ivory*.36));
    }
   }
   o.Albedo=lerp(paint.rgb,paint.rgb*half3(.6,1.4,.75)+half3(0,.08,.025),_HealPulse*.55);
   o.Normal=normal;
   o.Metallic=metal;o.Smoothness=1-rough;
   o.Occlusion=lerp(1,authoredAO,_OcclusionStrength);
   half rim=pow(1-saturate(dot(normalize(i.viewDir),normalize(normal))),3.2);
   half spectral=abs(_SurfaceFamily-3)<.25 ? (.12+.65*rim) : 1;
   o.Emission=tex2D(_EmissionMap,i.uv_MainTex).rgb*_EmissionColor.rgb*_SurfaceEmission*spectral;
   o.Emission+=_HealPulse*half3(.035,.24,.085);
   o.Alpha=paint.a*_ExitOpacity;
  }
  ENDCG
 }
 Fallback "Standard"
}
