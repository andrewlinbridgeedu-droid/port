Shader "Mindstone/Hero Tailored PBR" {
 Properties {
 _MainTex("Original painted costume",2D)="white"{} _Color("Tint",Color)=(1,1,1,1)
 _BumpMap("Authored folds and trim",2D)="bump"{} _BumpScale("Normal strength",Range(0,2))=1.12
 _MetalMap("Authored metal mask",2D)="black"{} _RoughMap("Authored roughness",2D)="white"{}
 _FacePaintMap("Baked face albedo",2D)="black"{} _FacePaintReady("Face paint available",Float)=0
 _RegionMap("UV skin hair leather regions",2D)="black"{} _RegionsReady("Semantic regions available",Float)=0
 _Painted("Body atlas",Range(0,1))=1 _Hair("Hair material",Range(0,1))=0
 _AuthoredSurfaceReady("Refined material maps",Float)=0
 _SourceMetal("Source metal",Range(0,1))=0 _SourceSmooth("Source smooth",Range(0,1))=.35
 _Fabric("Fabric material",Range(0,1))=0 _Gold("Gold material",Range(0,1))=0
 }
 SubShader { Tags {"RenderType"="Opaque"} LOD 300
 CGPROGRAM
 #pragma surface surf Standard fullforwardshadows
 #pragma target 3.0
 #include "UnityStandardUtils.cginc"
 sampler2D _MainTex,_BumpMap,_MetalMap,_RoughMap,_RegionMap,_FacePaintMap; fixed4 _Color; half _AuthoredSurfaceReady,_FacePaintReady,_RegionsReady,_BumpScale,_Fabric,_Gold,_Painted,_Hair,_SourceMetal,_SourceSmooth;
 float4 _BackCenter,_BackRight,_BackUp,_BackForward;
 struct Input {float2 uv_MainTex;float3 viewDir;float3 worldPos;};
 float thread(float2 p,float2 a,float2 b,float width) {float2 d=b-a;float t=saturate(dot(p-a,d)/dot(d,d));float dist=length(p-a-d*t);return 1-smoothstep(width,width+max(fwidth(dist),.005),dist);}
 void surf(Input IN,inout SurfaceOutputStandard o) {
  fixed4 paint=tex2D(_MainTex,IN.uv_MainTex)*_Color;
  half4 facePaint=tex2D(_FacePaintMap,IN.uv_MainTex);
  half faceCoverage=facePaint.a*_FacePaintReady*_Painted;
  paint.rgb=lerp(paint.rgb,facePaint.rgb*_Color.rgb,faceCoverage);
  // Preserve the atlas's pale skin/ivory regions before any costume tint or embroidery.
  half sourceMax=max(paint.r,max(paint.g,paint.b));
  half sourceMin=min(paint.r,min(paint.g,paint.b));
  half sourceSaturation=(sourceMax-sourceMin)/max(sourceMax,.001);
  half3 region=tex2D(_RegionMap,IN.uv_MainTex).rgb*_RegionsReady*_Painted;
  half hair=region.g,skin=region.r,leather=region.b;
  half pale=lerp(smoothstep(.18,.42,sourceMax)*(1-smoothstep(.23,.42,sourceSaturation)),skin,_RegionsReady*_Painted);
  // Hair islands share the atlas with the coat, but must never inherit gold flecks.
  half hairValue=clamp(dot(paint.rgb,half3(.2126,.7152,.0722)),.015,.095);
  paint.rgb=lerp(paint.rgb,half3(.010,.012,.020)+hairValue*.20,hair);
  // Costume embroidery is authored in UV space; do not paint rigid world-space lines over moving cloth.
  half embroidery=0;
  half metal=saturate(tex2D(_MetalMap,IN.uv_MainTex).r);
  half rough=tex2D(_RoughMap,IN.uv_MainTex).r;
  // Original gold is warm and saturated: restrict lustre to its painted inlay.
  half gold=saturate((paint.r-paint.b)*5)*saturate((paint.g-paint.b)*7)*(1-pale)*(1-hair);
  // Body paint uses gold hue as a material boundary: grey cloth must stay dielectric.
  metal=max(metal*gold*.56,max(gold*.78,embroidery*.72));
  metal=lerp(_SourceMetal,metal,_Painted); metal=lerp(metal,.02,_Fabric);metal=lerp(metal,.82,_Gold);
  half cloth=(1-metal)*(1-smoothstep(.12,.4,max(paint.r,max(paint.g,paint.b))))*(1-max(hair,skin));
  // Lift only crushed costume shadows; the map's seams and embroidered lines remain intact.
  half textile=(1-gold)*_Painted*(1-pale)*(1-hair)*(1-leather*.8);
  // Preserve painted value detail while making charcoal plum distinct from grey metal.
  o.Albedo=paint.rgb*lerp(half3(1,1,1),half3(.83,.73,.96),textile*.65)+cloth*half3(.002,.001,.004);
  half exposedSkin=skin*(1-faceCoverage)*smoothstep(.20,.55,sourceMax)*(1-smoothstep(.25,.45,sourceSaturation));
  o.Albedo*=lerp(half3(1,1,1),half3(.78,.69,.63),exposedSkin);
  half2 uv=IN.uv_MainTex*1024;
  half attenuation=1-saturate(max(length(ddx(uv)),length(ddy(uv))));
  half weave=sin(uv.x*6.283)*sin(uv.y*6.283)*attenuation;
  o.Albedo*=1+weave*.025*cloth;
  o.Normal=lerp(half3(0,0,1),UnpackScaleNormal(tex2D(_BumpMap,IN.uv_MainTex),_BumpScale),_Painted);
  o.Normal.xy+=half2(weave,-weave)*.018*cloth;
  o.Normal=normalize(lerp(o.Normal,half3(0,0,1),max(faceCoverage*.96,max(hair*.70,skin*.65))));
  o.Metallic=lerp(metal,0,max(pale*_Painted,hair));
  o.Smoothness=lerp(clamp(1-rough,.10,.28),clamp(1-rough,.38,.67),metal);
  o.Smoothness=lerp(_SourceSmooth,o.Smoothness,_Painted);
  o.Smoothness=lerp(o.Smoothness,.24,_Hair);o.Smoothness=lerp(o.Smoothness,.25,_Fabric);o.Smoothness=lerp(o.Smoothness,.54,_Gold);
  o.Smoothness=lerp(o.Smoothness,.34,hair);
  o.Smoothness=lerp(o.Smoothness,.30,skin);
  o.Smoothness=lerp(o.Smoothness,.44,leather*(1-gold));
  // Calibrated surface maps retain real cloth/skin/metal separation instead of a shared gloss clamp.
  o.Smoothness=lerp(o.Smoothness,clamp(1-rough,.08,.65),_AuthoredSurfaceReady*(1-max(skin,hair)));
  o.Metallic=lerp(o.Metallic,tex2D(_MetalMap,IN.uv_MainTex).r,_AuthoredSurfaceReady*(1-max(skin,hair)));
  // Keep distant gold trim and authored folds from sparkling as the camera/model moves.
  half3 normalDx=ddx(o.Normal),normalDy=ddy(o.Normal);
  half normalVariance=min(.10,.35*(dot(normalDx,normalDx)+dot(normalDy,normalDy)));
  half filteredRough=sqrt(saturate((1-o.Smoothness)*(1-o.Smoothness)+normalVariance));
  o.Smoothness=1-filteredRough;
  half rim=pow(1-saturate(dot(normalize(IN.viewDir),o.Normal)),3.4);
  o.Emission=rim*half3(.004,.006,.012)*(1-metal)+gold*half3(.012,.008,.002);
  o.Occlusion=1;o.Alpha=paint.a;
 }
 ENDCG
 }
 Fallback "Standard"
}
