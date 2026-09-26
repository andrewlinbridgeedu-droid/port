Shader "Mindstone/VFXV1/Frost Tornado Dynamic Flow"
{
    Properties
    {
        _MainTex ("Directionless Flow Noise", 2D) = "white" {}
        _Tint ("Tint", Color) = (0.46,0.94,0.88,1)
        _HotColor ("Dense Ice", Color) = (0.90,1.00,0.96,1)
        _Phase ("Continuous Phase", Float) = 0
        _Opacity ("Opacity", Range(0,1)) = 1
        _ErodeLow ("Erode Low", Range(0,1)) = 0.36
        _ErodeHigh ("Erode High", Range(0,1)) = 0.66
        _AlphaCap ("Alpha Cap", Range(0,1)) = 0.56
        _Accent ("Sparse Moving Highlight", Range(0,1)) = 0
        [Enum(UnityEngine.Rendering.CompareFunction)] _ZTest ("ZTest", Float) = 4
    }

    SubShader
    {
        Tags
        {
            "Queue" = "Transparent"
            "RenderType" = "Transparent"
            "IgnoreProjector" = "True"
        }
        Cull Off
        Lighting Off
        ZWrite Off
        ZTest [_ZTest]
        Blend One OneMinusSrcAlpha

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "UnityCG.cginc"

            sampler2D _MainTex;
            fixed4 _Tint;
            fixed4 _HotColor;
            float _Phase;
            float _Opacity;
            float _ErodeLow;
            float _ErodeHigh;
            float _AlphaCap;
            float _Accent;

            struct appdata
            {
                float4 vertex : POSITION;
                fixed4 color : COLOR;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float4 position : SV_POSITION;
                fixed4 color : COLOR;
                float2 uv : TEXCOORD0;
            };

            v2f vert(appdata input)
            {
                v2f output;
                output.position = UnityObjectToClipPos(input.vertex);
                output.color = input.color;
                output.uv = input.uv;
                return output;
            }

            fixed4 frag(v2f input) : SV_Target
            {
                // UV 22..23 is a dedicated broad storm-sheet branch.  It must
                // be classified before the legacy brush families: allowing a
                // sheet to leak into the dark/faceted branches created the
                // opaque black cables visible in the previous candidate.
                float stormSheet = step(21.5, input.uv.y);
                // UV 18..19 is the dark/mid faceted brush; UV 20..21 is
                // reserved for the sparse jade-white/gold high-value edge.
                // Both remain in this material and therefore add no draw call.
                float luminousBrush = step(19.5, input.uv.y) * (1.0 - stormSheet);
                float facetedBrush = step(17.5, input.uv.y)
                    * (1.0 - luminousBrush) * (1.0 - stormSheet);
                float authoredBrush = max(max(facetedBrush, luminousBrush), stormSheet);
                float occlusionVolume = step(15.5, input.uv.y) * (1.0 - authoredBrush);
                float engulfVolume = step(13.5, input.uv.y)
                    * (1.0 - occlusionVolume) * (1.0 - authoredBrush);
                float darkVolume = step(11.5, input.uv.y)
                    * (1.0 - engulfVolume) * (1.0 - occlusionVolume)
                    * (1.0 - authoredBrush);
                float coreFissure = step(9.5, input.uv.y)
                    * (1.0 - darkVolume) * (1.0 - engulfVolume)
                    * (1.0 - occlusionVolume) * (1.0 - authoredBrush);
                float denseCore = step(7.5, input.uv.y)
                    * (1.0 - coreFissure) * (1.0 - darkVolume)
                    * (1.0 - engulfVolume) * (1.0 - occlusionVolume)
                    * (1.0 - authoredBrush);
                float denseLayer = max(max(denseCore, coreFissure), darkVolume);
                float calligraphyBrush = step(5.5, input.uv.y)
                    * (1.0 - denseLayer) * (1.0 - engulfVolume)
                    * (1.0 - occlusionVolume) * (1.0 - authoredBrush);
                float organicBurst = step(3.5, input.uv.y)
                    * (1.0 - calligraphyBrush) * (1.0 - denseLayer)
                    * (1.0 - engulfVolume) * (1.0 - occlusionVolume)
                    * (1.0 - authoredBrush);
                float impactRefraction = step(1.5, input.uv.y)
                    * (1.0 - organicBurst) * (1.0 - calligraphyBrush)
                    * (1.0 - denseLayer) * (1.0 - engulfVolume)
                    * (1.0 - occlusionVolume) * (1.0 - authoredBrush);
                float localV = input.uv.y
                    - impactRefraction * 2.0
                    - organicBurst * 4.0
                    - calligraphyBrush * 6.0
                    - denseCore * 8.0
                    - coreFissure * 10.0
                    - darkVolume * 12.0
                    - engulfVolume * 14.0
                    - occlusionVolume * 16.0
                    - facetedBrush * 18.0
                    - luminousBrush * 20.0
                    - stormSheet * 22.0;
                float accentGeometry = impactRefraction * step(0.015, input.color.a);
                float2 authoredUV = float2(input.uv.x, localV);
                // Two differently moving samples keep the texture from
                // becoming a visible sheet while staying inside the mobile
                // three-fetch budget recommended by the VFX review.
                float2 uvA = authoredUV * float2(2.25, 1.10)
                    + float2(_Phase * 0.12, _Phase * 1.65);
                float2 uvB = authoredUV.yx * float2(1.45, 3.10)
                    + float2(-_Phase * 0.31, _Phase * 0.57);
                float noiseA = tex2D(_MainTex, uvA).r;
                float noiseB = tex2D(_MainTex, uvB).g;
                float density = saturate(noiseA * 0.68 + noiseB * 0.42 - 0.08);
                // The ribbon geometry already carries the silhouette. Noise
                // only breaks up its interior; it must never erase the whole
                // strip on mobile shader variants.
                float breakup = lerp(0.26, 1.0, smoothstep(0.27, 0.70, density));
                float across = 1.0 - abs(localV * 2.0 - 1.0);
                float softWidth = pow(saturate(across), 1.40);
                // Wide impact petals share this material but use a separate UV
                // type. Two independent noise bands bite through both edges,
                // preventing the broad procedural strips from reading as flat
                // triangles or symmetric star rays.
                float burstNoiseA = noiseA;
                float burstNoiseB = noiseB;
                float burstDensity = saturate(burstNoiseA * 0.62 + burstNoiseB * 0.38);
                float burstAcross = 1.0 - abs(localV * 2.0 - 1.0);
                float warpedAcross = burstAcross
                    + (burstNoiseA - 0.5) * 0.28
                    + (burstNoiseB - 0.5) * 0.18;
                float burstEdge = smoothstep(-0.04, 0.22, warpedAcross);
                float burstTip = smoothstep(0.015, 0.12, input.uv.x)
                    * (1.0 - smoothstep(0.82, 1.0, input.uv.x));
                float tornPockets = lerp(0.32, 1.0,
                    smoothstep(0.25, 0.70, burstDensity));
                float burstMask = burstEdge * burstTip * tornPockets;
                float brushEdge = smoothstep(-0.08, 0.22, warpedAcross);
                float brushInk = lerp(0.52, 1.0,
                    smoothstep(0.20, 0.78, burstDensity));
                float brushMask = brushEdge * burstTip * brushInk;
                // Dedicated storm sheets are wide flowing surfaces, not
                // tubular ribbons.  Their edge, pockets and moving highlight
                // are independent from every legacy UV family above.
                float sheetAcross = 1.0 - abs(localV * 2.0 - 1.0);
                float sheetWarp = sheetAcross
                    + (burstNoiseA - 0.5) * 0.22
                    + (burstNoiseB - 0.5) * 0.14;
                float sheetEdge = smoothstep(0.015, 0.31, sheetWarp);
                float sheetEnds = smoothstep(0.0, 0.045, input.uv.x)
                    * (1.0 - smoothstep(0.91, 1.0, input.uv.x));
                float sheetPockets = lerp(0.48, 1.0,
                    smoothstep(0.20, 0.76, burstDensity));
                float sheetMask = sheetEdge * sheetEnds * sheetPockets;
                float sheetRidgeCenter = 0.30
                    + (burstNoiseA - 0.5) * 0.11
                    + sin(input.uv.x * 9.8 - _Phase * 5.1) * 0.030;
                float sheetRidge = pow(saturate(
                    1.0 - abs(localV - sheetRidgeCenter) / 0.24), 3.0)
                    * sheetEnds;
                // Dense painterly surfaces use a firmer interior, torn ends,
                // an off-centre ice ridge, and small moving material cuts.
                // The mask stays visibly dimensional but can genuinely cover
                // the actor when several curved surfaces overlap.
                float facetedSide = abs(localV * 2.0 - 1.0);
                float facetedAcross = 1.0 - facetedSide;
                float facetedWarp = facetedAcross
                    + (burstNoiseA - 0.5) * 0.31
                    + (burstNoiseB - 0.5) * 0.16;
                float facetedEdge = smoothstep(0.10, 0.36, facetedWarp);
                float facetedTip = smoothstep(0.008, 0.070, input.uv.x)
                    * (1.0 - smoothstep(0.89, 1.0, input.uv.x));
                float facetedHoleField = burstNoiseA * 0.64 + burstNoiseB * 0.36;
                float facetedCutField = abs(burstNoiseA - burstNoiseB);
                float facetedPockets = max(
                    smoothstep(0.28, 0.58, facetedHoleField),
                    smoothstep(0.13, 0.34, facetedCutField) * 0.68);
                // Real holes and translucent tears stop the wide geometry from
                // reading as a plastic board. Several depth-offset strokes
                // still form a near-solid union over the target.
                float facetedMaterial = lerp(0.08, 1.0, facetedPockets);
                float facetedMask = facetedEdge * facetedTip * facetedMaterial;
                // The highlight hugs one torn edge rather than the centre;
                // central symmetry made every brush read as a glossy tube.
                float ridgeCenter = 0.18
                    + (burstNoiseA - 0.5) * 0.055
                    + sin(input.uv.x * 11.0 - _Phase * 4.2) * 0.014;
                float facetedRidge = pow(saturate(
                    1.0 - abs(localV - ridgeCenter) / 0.15), 3.4)
                    * facetedTip;
                float facetCut = pow(smoothstep(0.70, 0.94,
                    burstNoiseB * 0.58 + burstNoiseA * 0.42), 3.0)
                    * pow(saturate(facetedAcross), 1.8);
                float coreTurbulence = saturate(
                    burstNoiseA * 0.58 + burstNoiseB * 0.42);
                // The impact body is a tapered, turbulent frost-flame rather
                // than a stretched capsule. Its width collapses at both ends
                // and the noisy centreline bends independently per lobe.
                float coreLong = abs(input.uv.x * 2.0 - 1.0);
                float coreEnvelope = pow(saturate(1.0 - coreLong), 0.48);
                float coreDrift = (burstNoiseA - 0.5) * 0.16
                    + (burstNoiseB - 0.5) * 0.08
                    + sin(input.uv.x * 8.5 + _Phase * 5.2) * 0.035;
                float coreAcross = abs((localV - 0.5 + coreDrift) * 2.0);
                float coreEdge = coreEnvelope
                    * lerp(0.76, 1.08, coreTurbulence);
                float coreMask = (1.0 - smoothstep(
                    max(0.015, coreEdge * 0.66),
                    max(0.075, coreEdge),
                    coreAcross));
                coreMask *= pow(coreEnvelope, 0.34)
                    * lerp(0.62, 1.0,
                        smoothstep(0.18, 0.82, coreTurbulence));

                // The white-hot interior is authored as its own UV class.
                // It is a crooked, pointed ice fissure with two small forks,
                // never the flat vertical bar produced by the former mask.
                float fissureEnvelope = pow(saturate(sin(input.uv.x * 3.14159265)), 0.58);
                float fissureDrift = sin(input.uv.x * 13.0 + _Phase * 8.0) * 0.105
                    + sin(input.uv.x * 29.0 - _Phase * 4.5) * 0.032
                    + (burstNoiseA - 0.5) * 0.085;
                float fissureDistance = abs(localV - 0.5 - fissureDrift);
                float fissureWidth = lerp(0.025, 0.145, fissureEnvelope)
                    * lerp(0.78, 1.12, coreTurbulence);
                float fissureMain = 1.0 - smoothstep(
                    fissureWidth * 0.52,
                    fissureWidth,
                    fissureDistance);
                float forkGate = smoothstep(0.56, 0.68, input.uv.x)
                    * (1.0 - smoothstep(0.88, 0.97, input.uv.x));
                float forkDistance = abs(localV - 0.5 + fissureDrift * 0.52
                    - (input.uv.x - 0.64) * 0.44);
                float fissureFork = (1.0 - smoothstep(0.016, 0.060, forkDistance))
                    * forkGate;
                float fissureMask = max(fissureMain, fissureFork * 0.72)
                    * fissureEnvelope
                    * lerp(0.76, 1.0, smoothstep(0.26, 0.82, coreTurbulence));
                float denseMask = lerp(coreMask, fissureMask, coreFissure);
                float coreCenter = saturate(1.0 - coreAcross / max(coreEdge, 0.08));
                float fissureCenter = saturate(1.0
                    - fissureDistance / max(fissureWidth, 0.025));
                float denseCenter = lerp(coreCenter, fissureCenter, coreFissure);

                // Dense spell-owned wind pressure. A funnel envelope and two
                // domain-warped samples create one continuous body with torn
                // edges and internal voids; geometry may rotate this field for
                // horizontal impact sheets without changing the shader.
                float volumeLong = saturate(input.uv.x);
                float volumeEnvelope = smoothstep(0.0, 0.055, volumeLong)
                    * (1.0 - smoothstep(0.93, 1.0, volumeLong));
                float volumeProfile = lerp(0.43, 1.0, pow(volumeLong, 0.70));
                float volumeDrift = (burstNoiseA - 0.5) * 0.20
                    + (burstNoiseB - 0.5) * 0.11
                    + sin(volumeLong * 9.2 + _Phase * 4.4) * 0.045;
                float volumeAcross = abs((localV - 0.5 + volumeDrift) * 2.0);
                float volumeEdge = volumeProfile
                    * lerp(0.78, 1.12, coreTurbulence);
                float volumeMask = 1.0 - smoothstep(
                    max(0.04, volumeEdge * 0.72),
                    max(0.10, volumeEdge),
                    volumeAcross);
                float volumePockets = lerp(0.38, 1.0,
                    smoothstep(0.24, 0.78, burstDensity));
                volumeMask *= volumeEnvelope * volumePockets;
                float volumeCenter = saturate(1.0
                    - volumeAcross / max(volumeEdge, 0.08));
                float occlusionLong = saturate(input.uv.x);
                float occlusionEnvelope = smoothstep(0.0, 0.035, occlusionLong)
                    * (1.0 - smoothstep(0.965, 1.0, occlusionLong));
                float occlusionProfile = lerp(0.48, 1.0, pow(occlusionLong, 0.68));
                float occlusionDrift = (burstNoiseA - 0.5) * 0.13
                    + sin(occlusionLong * 8.8 + _Phase * 3.9) * 0.035;
                float occlusionAcross = abs((localV - 0.5 + occlusionDrift) * 2.0);
                float occlusionEdge = occlusionProfile
                    * lerp(0.88, 1.08, coreTurbulence);
                float occlusionMask = 1.0 - smoothstep(
                    max(0.06, occlusionEdge * 0.86),
                    max(0.11, occlusionEdge),
                    occlusionAcross);
                occlusionMask *= occlusionEnvelope;
                float occlusionCenter = saturate(1.0
                    - occlusionAcross / max(occlusionEdge, 0.10));
                // Preserve near-solid coverage while letting the two moving
                // noise fields carve material variation through the body.
                // The target is submerged by the spell, never by a flat card.
                float occlusionTexture = lerp(0.78, 1.0,
                    smoothstep(0.20, 0.78, burstDensity));
                float longitudinal = smoothstep(0.0, 0.055, input.uv.x)
                    * (1.0 - smoothstep(0.91, 1.0, input.uv.x));
                longitudinal = lerp(longitudinal, 1.0 - smoothstep(0.82, 1.0, input.uv.x), impactRefraction);
                longitudinal = lerp(longitudinal, burstMask, organicBurst);
                longitudinal = lerp(longitudinal, brushMask, calligraphyBrush);
                longitudinal = lerp(longitudinal, denseMask, denseLayer);
                longitudinal = lerp(longitudinal, volumeMask, engulfVolume);
                longitudinal = lerp(longitudinal, occlusionMask, occlusionVolume);
                // Metal's particle/mesh color-alpha packing is not stable
                // across the two renderers used here. RGB still carries the
                // authored density, so derive a bounded opacity weight from
                // luminance and keep _Opacity as the timeline authority.
                float colorWeight = saturate(dot(input.color.rgb, float3(0.28, 0.46, 0.26)) * 1.18);
                float alpha = min(_AlphaCap, saturate(_Opacity * colorWeight
                    * breakup * softWidth * longitudinal * 1.72));
                alpha = max(alpha, accentGeometry * input.color.a * _Opacity * 0.92);
                float burstAlpha = min(_AlphaCap,
                    saturate(input.color.a * _Opacity * burstMask * 2.05));
                alpha = lerp(alpha, burstAlpha, organicBurst);
                float brushAlpha = min(_AlphaCap,
                    saturate(input.color.a * _Opacity * brushMask * 2.18));
                alpha = lerp(alpha, brushAlpha, calligraphyBrush);
                float coreAlpha = min(_AlphaCap,
                    saturate(input.color.a * _Opacity * denseMask
                        * lerp(2.82, 3.45, coreFissure)
                        * lerp(1.0, 1.14, darkVolume)));
                alpha = lerp(alpha, coreAlpha, denseLayer);
                float volumeAlpha = min(_AlphaCap,
                    saturate(_Opacity * volumeMask * 5.60
                        * lerp(0.88, 1.0, colorWeight)));
                alpha = lerp(alpha, volumeAlpha, engulfVolume);
                // The material timeline owns opacity.  Ignoring _AlphaCap
                // here turned every wide VortexSheet into a thick neon cable.
                float occlusionAlpha = min(_AlphaCap,
                    saturate(_Opacity * occlusionMask * 7.2)
                        * occlusionTexture);
                alpha = lerp(alpha, occlusionAlpha, occlusionVolume);
                // Metal does not preserve mesh color alpha consistently across
                // the extension and particle renderers used by this preview.
                // Derive stable density from authored RGB, while the material
                // opacity remains the timeline authority.
                float facetedWeight = max(input.color.a * 0.52,
                    saturate(colorWeight * 0.94));
                float facetedAlpha = min(_AlphaCap,
                    saturate(facetedWeight * _Opacity * facetedMask * 1.96));
                alpha = lerp(alpha, facetedAlpha, facetedBrush);
                float luminousBreak = lerp(0.12, 1.0,
                    smoothstep(0.31, 0.62,
                        burstNoiseA * 0.56 + burstNoiseB * 0.44));
                float luminousAlpha = min(_AlphaCap,
                    saturate(max(input.color.a * 0.62, colorWeight)
                        * _Opacity * facetedMask * luminousBreak * 2.34));
                alpha = lerp(alpha, luminousAlpha, luminousBrush);
                float sheetAlpha = min(_AlphaCap,
                    saturate(_Opacity * sheetMask * 1.34));
                alpha = lerp(alpha, sheetAlpha, stormSheet);
                fixed3 body = lerp(_Tint.rgb * 0.62, _Tint.rgb * 1.18, density);
                float vertexInfluence = (1.0 - impactRefraction)
                    * saturate(colorWeight * 0.38);
                body = lerp(body, input.color.rgb * 1.08, vertexInfluence);
                body = lerp(body, input.color.rgb * 1.18, impactRefraction * 0.90);
                // Irregular frost veins emerge from the warped noise itself.
                // A periodic frac() stripe here used to expose repeated bands
                // on the widest strokes and made them look procedural.
                float brushVein = pow(smoothstep(0.56, 0.91,
                    burstNoiseB * 0.66 + burstNoiseA * 0.34), 3.2)
                    * pow(saturate(burstAcross), 1.35);
                float warmSignal = saturate((input.color.r - input.color.b) * 4.4);
                fixed3 brushShadow = fixed3(0.025, 0.25, 0.22);
                fixed3 brushMid = lerp(fixed3(0.12, 0.78, 0.66), input.color.rgb, 0.62);
                fixed3 burstBody = lerp(brushShadow, brushMid,
                    smoothstep(0.22, 0.80, burstDensity));
                burstBody = lerp(burstBody, fixed3(0.74, 0.98, 0.92),
                    pow(saturate(burstAcross), 2.8) * 0.62);
                burstBody += fixed3(0.34, 0.90, 0.96) * brushVein * tornPockets * 0.34;
                burstBody = lerp(burstBody, input.color.rgb * 1.12, warmSignal * 0.88);
                body = lerp(body, burstBody, organicBurst);
                fixed3 flowingBrush = lerp(fixed3(0.022, 0.22, 0.20),
                    fixed3(0.16, 0.82, 0.70),
                    smoothstep(0.18, 0.84, burstDensity));
                flowingBrush = lerp(flowingBrush, input.color.rgb,
                    0.46 + pow(saturate(burstAcross), 3.0) * 0.34);
                flowingBrush += fixed3(0.54, 0.96, 1.00)
                    * brushVein * tornPockets * 0.44;
                flowingBrush = lerp(flowingBrush, input.color.rgb * 1.14, warmSignal * 0.90);
                body = lerp(body, flowingBrush, calligraphyBrush);
                float coreHeat = pow(denseCenter, lerp(1.85, 1.18, coreFissure));
                fixed3 coldCore = lerp(input.color.rgb * 0.24,
                    input.color.rgb * 1.18,
                    coreHeat);
                coldCore = lerp(coldCore, fixed3(0.82, 0.99, 1.00),
                    coreHeat * 0.62);
                coldCore += fixed3(0.10, 0.58, 0.82)
                    * pow(smoothstep(0.62, 0.94, coreTurbulence), 2.0)
                    * (1.0 - coreHeat) * 0.30;
                coldCore = lerp(coldCore, fixed3(1.00, 0.97, 0.84),
                    pow(denseCenter, 6.0) * lerp(0.16, 0.46, coreFissure));
                fixed3 darkPressure = lerp(input.color.rgb * 0.44,
                    input.color.rgb * 1.04,
                    pow(denseCenter, 1.45));
                darkPressure += fixed3(0.04, 0.32, 0.52)
                    * smoothstep(0.58, 0.92, coreTurbulence) * 0.34;
                coldCore = lerp(coldCore, darkPressure, darkVolume);
                body = lerp(body, coldCore, denseLayer);
                fixed3 volumeShadow = max(input.color.rgb * 0.68,
                    fixed3(0.025, 0.22, 0.20));
                fixed3 volumeJade = lerp(fixed3(0.04, 0.50, 0.40),
                    fixed3(0.24, 0.88, 0.78),
                    smoothstep(0.20, 0.82, burstDensity));
                fixed3 volumeBody = lerp(volumeShadow, volumeJade,
                    smoothstep(0.08, 0.74, volumeCenter));
                volumeBody = lerp(volumeBody, fixed3(0.72, 0.96, 0.92),
                    pow(volumeCenter, 3.2) * brushVein * 0.52);
                volumeBody += fixed3(0.34, 0.88, 0.96)
                    * pow(smoothstep(0.62, 0.94, coreTurbulence), 2.4)
                    * volumeCenter * 0.14;
                // Cool indigo and rare pale-gold remain local palette breaks;
                // they prevent a flat all-cyan tornado without becoming pink.
                float violetSignal = saturate((input.color.b - input.color.g) * 3.0);
                volumeBody = lerp(volumeBody, input.color.rgb * 1.04,
                    violetSignal * 0.42);
                volumeBody = lerp(volumeBody, fixed3(0.94, 0.82, 0.38),
                    warmSignal * 0.20 * pow(volumeCenter, 2.0));
                body = lerp(body, volumeBody, engulfVolume);
                fixed3 occlusionBody = lerp(fixed3(0.012, 0.14, 0.24),
                    fixed3(0.08, 0.70, 0.86),
                    smoothstep(0.12, 0.82, burstDensity));
                occlusionBody = lerp(occlusionBody, input.color.rgb,
                    0.68 + occlusionCenter * 0.24);
                float jadeBloom = pow(smoothstep(0.54, 0.90,
                    burstNoiseA * 0.72 + (1.0 - burstNoiseB) * 0.28), 2.2)
                    * occlusionMask;
                float goldBloom = pow(smoothstep(0.78, 0.96,
                    burstNoiseB * 0.64 + burstNoiseA * 0.36), 4.0)
                    * pow(occlusionCenter, 1.6);
                occlusionBody = lerp(occlusionBody, fixed3(0.12, 0.94, 0.68),
                    jadeBloom * 0.34);
                occlusionBody = lerp(occlusionBody, fixed3(1.00, 0.88, 0.53),
                    goldBloom * 0.18);
                occlusionBody = lerp(occlusionBody, fixed3(0.72, 0.98, 1.00),
                    pow(occlusionCenter, 2.4) * brushVein * 0.34);
                body = lerp(body, occlusionBody, occlusionVolume);
                float facetedDarkBone = 1.0 - smoothstep(0.08, 0.46, facetedSide);
                float facetedJadeBand = smoothstep(0.12, 0.34, facetedSide)
                    * (1.0 - smoothstep(0.66, 0.94, facetedSide));
                fixed3 facetedShadow = fixed3(0.018, 0.16, 0.26);
                fixed3 facetedJade = lerp(fixed3(0.035, 0.40, 0.58),
                    fixed3(0.18, 0.80, 0.96),
                    smoothstep(0.22, 0.80, burstDensity));
                fixed3 facetedBody = facetedShadow * (0.84 + facetedDarkBone * 0.20)
                    + facetedJade * facetedJadeBand * 0.88;
                facetedBody = lerp(facetedBody, input.color.rgb * 0.72,
                    smoothstep(0.32, 0.86, burstDensity) * 0.20);
                facetedBody += fixed3(0.50, 0.94, 1.00)
                    * facetedRidge * 0.48;
                facetedBody += fixed3(0.58, 0.96, 1.00)
                    * facetCut * facetedMask * 0.16;
                facetedBody = lerp(facetedBody, input.color.rgb * 0.92,
                    warmSignal * 0.76);
                body = lerp(body, facetedBody, facetedBrush);
                fixed3 luminousBody = lerp(input.color.rgb * 0.46,
                    input.color.rgb * 1.08,
                    smoothstep(0.12, 0.82, burstDensity));
                luminousBody = lerp(luminousBody, fixed3(0.94, 1.00, 1.00),
                    facetedRidge * 0.92);
                luminousBody = lerp(luminousBody, fixed3(1.00, 0.88, 0.61),
                    warmSignal * 0.88);
                body = lerp(body, luminousBody, luminousBrush);
                // The storm branch has an explicit non-black colour floor.
                // Premultiplied transparency can then soften the silhouette
                // without ever darkening the actor into a striped cable.
                fixed3 sheetAuthored = max(input.color.rgb,
                    fixed3(0.055, 0.38, 0.34));
                fixed3 sheetBody = lerp(
                    fixed3(0.055, 0.43, 0.38),
                    fixed3(0.24, 0.82, 0.74),
                    smoothstep(0.12, 0.86, burstDensity));
                sheetBody = lerp(sheetBody, sheetAuthored * 1.10, 0.46);
                sheetBody = lerp(sheetBody, fixed3(0.30, 0.88, 0.94),
                    sheetRidge * 0.38);
                sheetBody = lerp(sheetBody, fixed3(0.44, 0.38, 0.82),
                    violetSignal * 0.34);
                sheetBody = lerp(sheetBody, fixed3(1.00, 0.82, 0.31),
                    warmSignal * sheetRidge * 0.28);
                body = lerp(body, sheetBody, stormSheet);
                float highlight = pow(smoothstep(0.76, 0.95, density), 2.2);
                // Two narrow, phase-offset brightness packets climb through
                // the existing helix. They are sparse accents rather than a
                // uniform white outline, preserving the dark ice body.
                float flowCoord = input.uv.x * 1.35 + input.uv.y * 0.62;
                float packet0 = frac(flowCoord * 1.55 - _Phase * 1.75);
                float packet1 = frac(flowCoord * 1.15 - _Phase * 1.20 + 0.37);
                float streak0 = pow(saturate(1.0 - abs(packet0 * 2.0 - 1.0)), 10.0);
                float streak1 = pow(saturate(1.0 - abs(packet1 * 2.0 - 1.0)), 13.0);
                float sparkle = max(streak0, streak1 * 0.55)
                    * smoothstep(0.56, 0.82, density) * _Accent;
                fixed3 premultiplied = body * alpha
                    + fixed3(0.38, 0.82, 0.86) * sparkle * 0.34
                    + _HotColor.rgb * highlight * alpha * 0.09
                    + fixed3(0.84, 0.91, 0.70) * pow(sparkle, 4.0) * 0.05
                    + input.color.rgb * accentGeometry * alpha * 0.52
                    + fixed3(0.64, 0.88, 0.88) * impactRefraction * alpha * 0.34
                    + fixed3(0.54, 0.96, 1.00) * organicBurst
                        * pow(saturate(burstAcross), 5.0) * burstAlpha * 0.62
                    + fixed3(0.99, 0.91, 0.72) * organicBurst
                        * pow(saturate(burstDensity * burstAcross), 9.0)
                        * burstAlpha * 0.17
                    + fixed3(0.82, 0.90, 0.58) * warmSignal
                        * max(organicBurst, calligraphyBrush) * alpha * 0.20
                    + fixed3(0.52, 0.96, 1.00) * calligraphyBrush
                        * brushVein * brushAlpha * 0.46
                    + fixed3(0.70, 0.90, 0.88) * denseLayer
                        * pow(denseCenter, 5.0) * coreAlpha
                        * lerp(0.14, 0.30, coreFissure)
                        * (1.0 - darkVolume * 0.82)
                    + fixed3(0.72, 0.97, 1.00) * engulfVolume
                        * brushVein * volumeCenter * volumeAlpha * 0.24
                    + fixed3(0.78, 0.98, 1.00) * occlusionVolume
                        * brushVein * occlusionCenter * occlusionAlpha * 0.18
                    + fixed3(0.56, 0.96, 1.00) * facetedBrush
                        * facetedRidge * facetedAlpha * 0.14
                    + fixed3(1.00, 0.88, 0.61) * facetedBrush
                        * warmSignal * facetedRidge * facetedAlpha * 0.07
                    + fixed3(0.68, 0.92, 0.90) * luminousBrush
                        * facetedRidge * luminousAlpha * 0.34
                    + fixed3(0.84, 0.91, 0.62) * luminousBrush
                        * warmSignal * facetedRidge * luminousAlpha * 0.12;
                fixed3 sheetPremultiplied = sheetBody * sheetAlpha
                    + fixed3(0.34, 0.92, 0.98)
                        * sheetRidge * sheetAlpha * 0.18
                    + fixed3(0.98, 0.82, 0.34)
                        * warmSignal * sheetRidge * sheetAlpha * 0.12;
                premultiplied = lerp(premultiplied, sheetPremultiplied, stormSheet);
                return fixed4(premultiplied, alpha);
            }
            ENDCG
        }
    }
}
