Shader "Mistport/BountyIdentity" {
Properties { _MainTex("Base",2D)="white"{} _BumpMap("Normal",2D)="bump"{} _MetallicGlossMap("MetalSmooth",2D)="black"{} _Color("Color",Color)=(1,1,1,1) _IdentityTint("Identity palette",Color)=(.5,.5,.5,1) _ArtPreserve("Preserve authored color",Range(0,1))=0 _EmissionColor("Emission",Color)=(0,0,0,1) _BumpScale("Normal strength",Float)=.7 _GlossMapScale("Gloss",Float)=.5 }
SubShader { Tags {"RenderType"="Opaque"} LOD 200
CGPROGRAM
#pragma surface surf Standard fullforwardshadows
#pragma target 3.0
sampler2D _MainTex,_BumpMap,_MetallicGlossMap; fixed4 _Color,_IdentityTint,_EmissionColor; half _BumpScale,_GlossMapScale,_ArtPreserve;
struct Input {float2 uv_MainTex;};
void surf(Input IN,inout SurfaceOutputStandard o){fixed4 base=tex2D(_MainTex,IN.uv_MainTex);half lum=dot(base.rgb,half3(.2126,.7152,.0722));o.Albedo=lerp(base.rgb,lum.xxx,.88*(1-_ArtPreserve))*_IdentityTint.rgb*_Color.rgb*lerp(1.25,1,_ArtPreserve);o.Normal=UnpackScaleNormal(tex2D(_BumpMap,IN.uv_MainTex),_BumpScale);fixed4 mr=tex2D(_MetallicGlossMap,IN.uv_MainTex);o.Metallic=mr.r;o.Smoothness=mr.a*_GlossMapScale;o.Emission=_EmissionColor.rgb;o.Alpha=1;}
ENDCG
} FallBack "Standard"
}
