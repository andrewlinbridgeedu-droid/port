Shader "Hidden/Mistport/Review/ShadowfangFurSoft"
{
    Properties
    {
        _MainTex ("Strands (RGB albedo, A coverage)", 2D) = "white" {}
        _Color ("Tint", Color) = (0.78, 0.78, 0.78, 1)
        _Cutoff ("Solid cutoff", Range(0, 1)) = 0.5
        _RootShade ("Root shade", Range(0, 1)) = 0.5
        _Wrap ("Light wrap", Range(0, 1)) = 0.45
        _Sheen ("Strand sheen", Range(0, 1)) = 0.06
        _StrandContrast ("Strand contrast", Range(0, 1)) = 0.6
        _FurWorldUnit ("World units per Blender unit", Float) = 1
        _RootLock ("Locked root share", Range(0, 0.6)) = 0.18
        _Sway ("Sway (Hz)", Float) = 1.3
        _Flutter ("Flutter (Hz)", Float) = 5.2
        _WaveLag ("Root-to-tip lag (rad)", Float) = 2.2
    }
    SubShader
    {
        Tags { "Queue" = "AlphaTest" "RenderType" = "TransparentCutout" "IgnoreProjector" = "True" }
        Cull Off
        ZWrite Off
        CGPROGRAM
        #pragma surface surf Fur vertex:vert alpha:fade nometa noshadow
        #pragma target 3.0
        half _Cutoff;
        #include "ShadowfangFurCards.cginc"
        void surf(Input IN, inout SurfaceOutput o)
        {
            fixed4 c = FurSample(IN);
            // Only what the solid pass left out: the thin edges and loose hairs.
            clip(_Cutoff - c.a);
            o.Albedo = c.rgb;
            o.Alpha = c.a;
        }
        ENDCG
    }
}
