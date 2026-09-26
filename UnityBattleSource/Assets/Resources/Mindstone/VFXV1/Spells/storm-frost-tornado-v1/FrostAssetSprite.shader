Shader "Mindstone/VFXV1/Frost Recolored Asset Sprite"
{
    Properties
    {
        _MainTex ("Mature Source Texture", 2D) = "black" {}
        _DeepColor ("Shadow Jade", Color) = (0.025,0.14,0.17,1)
        _Tint ("Emerald Body", Color) = (0.06,0.55,0.50,1)
        _HotColor ("Ice Cyan Highlight", Color) = (0.62,0.94,1.0,1)
        _WarmColor ("Rare Warm Glint", Color) = (1.0,0.78,0.24,1)
        _Phase ("Continuous Phase", Float) = 0
        _Opacity ("Opacity", Range(0,1)) = 1
        _AlphaCap ("Alpha Cap", Range(0,1)) = 0.62
        _Intensity ("Intensity", Range(0,4)) = 1.4
        _Distortion ("UV Distortion", Range(0,0.2)) = 0.06
        _CutLow ("Luminance Cut Low", Range(0,1)) = 0.025
        _CutHigh ("Luminance Cut High", Range(0,1)) = 0.24
        _ArcSpan ("Visible Arc Fraction", Range(0,1)) = 1
        _WarmAmount ("Rare Warm Amount", Range(0,0.2)) = 0.015
        _SourceMix ("Preserve Source Colour", Range(0,1)) = 0.15
        _VertexMix ("Per-card Palette Strength", Range(0,1)) = 0.35
        _EdgeErode ("Organic Card Erosion", Range(0,1)) = 0
        _FlowDissolve ("Flow Edge Dissolve", Range(0,1)) = 0.35
        _VortexEye ("Vortex Eye Width", Range(0,0.4)) = 0
        _VolumeFill ("Low Frequency Volume Fill", Range(0,1)) = 0
        _UseSourceAlpha ("Use Source Alpha", Range(0,1)) = 0
        [Enum(UnityEngine.Rendering.BlendMode)] _SrcBlend ("Source Blend", Float) = 1
        [Enum(UnityEngine.Rendering.BlendMode)] _DstBlend ("Destination Blend", Float) = 10
        [Enum(UnityEngine.Rendering.CompareFunction)] _ZTest ("ZTest", Float) = 8
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
        Blend [_SrcBlend] [_DstBlend]

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "UnityCG.cginc"

            sampler2D _MainTex;
            fixed4 _DeepColor;
            fixed4 _Tint;
            fixed4 _HotColor;
            fixed4 _WarmColor;
            float _Phase;
            float _Opacity;
            float _AlphaCap;
            float _Intensity;
            float _Distortion;
            float _CutLow;
            float _CutHigh;
            float _ArcSpan;
            float _WarmAmount;
            float _SourceMix;
            float _VertexMix;
            float _EdgeErode;
            float _FlowDissolve;
            float _VortexEye;
            float _VolumeFill;
            float _UseSourceAlpha;

            struct appdata
            {
                float4 vertex : POSITION;
                fixed4 color : COLOR;
                float2 uv : TEXCOORD0;
                float3 localUV : TEXCOORD1;
            };

            struct v2f
            {
                float4 position : SV_POSITION;
                fixed4 color : COLOR;
                float2 uv : TEXCOORD0;
                float3 localUV : TEXCOORD1;
            };

            v2f vert(appdata input)
            {
                v2f output;
                output.position = UnityObjectToClipPos(input.vertex);
                output.color = input.color;
                output.uv = input.uv;
                output.localUV = input.localUV;
                return output;
            }

            fixed4 frag(v2f input) : SV_Target
            {
                // Source UVs may point at a deliberately cropped region of a
                // mature Effekseer texture.  TEXCOORD1 remains the quad-local
                // 0..1 domain, so crop borders still receive a soft organic
                // fade instead of exposing a rectangular sprite edge.
                // Custom asset meshes set localUV.z to one.  Procedural leaves
                // use two so they can keep a recognisable leaf silhouette
                // while the same Effekseer atlas supplies colour detail.
                // Unity particle billboards stay at zero and use TEXCOORD0.
                float customMesh = step(0.5, input.localUV.z);
                float leafMesh = step(1.5, input.localUV.z)
                    - step(2.5, input.localUV.z);
                float phoenixMesh = step(3.5, input.localUV.z)
                    - step(4.5, input.localUV.z);
                float phoenixSilhouetteMesh = step(4.5,
                    input.localUV.z) - step(5.5, input.localUV.z);
                float surfaceMesh = step(2.5, input.localUV.z);
                float2 local = lerp(input.uv, input.localUV.xy, customMesh);
                if (customMesh > 0.5)
                {
                    fixed4 customSource = tex2D(_MainTex, input.uv);
                    float customLuminance = dot(customSource.rgb,
                        float3(0.299, 0.587, 0.114));
                    float sourceDetail = smoothstep(0.035, 0.72,
                        customLuminance);
                    float2 flowUv = input.localUV.xy;
                    float n0 = 0.5 + 0.5 * sin(
                        flowUv.x * 17.0 + flowUv.y * 5.0
                        + _Phase * 3.1);
                    float n1 = 0.5 + 0.5 * sin(
                        flowUv.x * 41.0 - flowUv.y * 13.0
                        - _Phase * 2.2 + 1.7);
                    float n2 = 0.5 + 0.5 * sin(
                        flowUv.x * 73.0 + flowUv.y * 19.0
                        + _Phase * 4.7 - 0.8);
                    float density = saturate(0.16 * sourceDetail
                        + 0.50 * n0 + 0.22 * n1 + 0.12 * n2);
                    float holes = smoothstep(0.50, 0.78, density);
                    float filament = smoothstep(0.58, 0.90,
                        n1 * 0.72 + n2 * 0.28);
                    // A low-frequency field supplies broad air-density
                    // variation inside the stream.  It is gated by the
                    // existing interior density, so it modulates the body
                    // without expanding the silhouette or making another
                    // readable ribbon.  The atlas and its fine noise remain
                    // the detail source; this only creates the missing
                    // compressed-air feeling.
                    float lowFrequencyAir = 0.5 + 0.5 * sin(
                        flowUv.x * 5.7 + flowUv.y * 1.6
                        + _Phase * 0.738
                        + sin(flowUv.y * 2.4 + _Phase * 0.279) * 0.7);
                    float interiorAirGate = smoothstep(0.42, 0.78,
                        density);
                    float airDensityVariation = 1.0
                        + (lowFrequencyAir - 0.5) * 0.24
                        * interiorAirGate;
                    // Break the material into short turbulent pockets.  This
                    // is deliberately a dissolve, not another ribbon: the
                    // existing Effekseer atlas remains the detail source while
                    // its long straight silhouette is eaten away by moving
                    // noise.
                    float dissolveNoise = 0.5 + 0.5 * sin(
                        flowUv.x * 23.0 - flowUv.y * 8.0
                        + _Phase * 2.6 + n2 * 2.1);
                    dissolveNoise = saturate(dissolveNoise * 0.72
                        + n0 * 0.18 + n1 * 0.10);
                    float dissolve = smoothstep(0.22, 0.72,
                        dissolveNoise);
                    dissolve = lerp(1.0, dissolve,
                        saturate(_FlowDissolve * 1.35));
                    float across = surfaceMesh > 0.5
                        ? abs(flowUv.x * 2.0 - 1.0)
                        : abs(flowUv.y * 2.0 - 1.0);
                    float ribbonEdge = lerp(0.62, 1.0,
                        1.0 - smoothstep(0.82, 1.0, across));
                    float streamBreak = 0.76 + 0.24 * (0.5 + 0.5 * sin(
                        flowUv.y * 31.0 + flowUv.x * 17.0
                        + _Phase * 3.7));
                    ribbonEdge *= streamBreak;
                    // Leave a narrow negative-space eye through the centre of
                    // the open funnel.  Multiple phase-offset surfaces still
                    // overlap around it, so the result reads as a rotating
                    // air volume instead of a flat green sheet.
                    float eyeMask = 1.0;
                    if (surfaceMesh > 0.5 && _VortexEye > 0.001)
                    {
                        float centerDistance = abs(flowUv.x - 0.5);
                        float eyeHalf = max(0.025, _VortexEye * 0.5);
                        eyeMask = smoothstep(eyeHalf * 0.55,
                            eyeHalf * 1.35, centerDistance);
                    }
                    float customVertexAlpha = saturate(input.color.a * 4.0);

                    // The phoenix is a single filled contour, not a stack of
                    // flame cards.  Its recognisable outline comes from the
                    // mesh; the reused Effekseer atlas contributes animated
                    // fire grain and the material colour ramp contributes the
                    // hot/cold depth inside that outline.
                    if (phoenixSilhouetteMesh > 0.5)
                    {
                        float broadFlow = 0.5 + 0.5 * sin(
                            flowUv.y * 8.0 - flowUv.x * 4.5
                            + _Phase * 1.35);
                        float featherFlow = 0.5 + 0.5 * sin(
                            flowUv.x * 22.0 + flowUv.y * 9.0
                            - _Phase * 2.25 + n1 * 2.0);
                        float crownGlow = smoothstep(0.56, 0.96,
                            flowUv.y);
                        float wingGlow = smoothstep(0.08, 0.50,
                            abs(flowUv.x - 0.5));
                        float coreGlow = 1.0 - smoothstep(0.02, 0.40,
                            abs(flowUv.x - 0.5));
                        float sourceFire = smoothstep(0.02, 0.62,
                            sourceDetail);
                        float silhouetteValue = saturate(
                            0.10 + broadFlow * 0.29
                            + featherFlow * 0.16
                            + crownGlow * 0.12
                            + wingGlow * 0.09
                            + sourceFire * 0.08);
                        fixed3 silhouetteBody = lerp(
                            _DeepColor.rgb, _Tint.rgb, silhouetteValue);
                        silhouetteBody = lerp(silhouetteBody,
                            _HotColor.rgb,
                            saturate(crownGlow * 0.32
                                + featherFlow * 0.12
                                + coreGlow * 0.08));
                        silhouetteBody = lerp(silhouetteBody,
                            _WarmColor.rgb,
                            saturate(crownGlow * 0.20
                                + coreGlow * 0.10));
                        silhouetteBody += _HotColor.rgb
                            * (0.025 + featherFlow * 0.045
                                + sourceFire * 0.035);

                        // Readable feather lanes are drawn inside the same
                        // filled mesh. They add structure to the wing and tail
                        // without reintroducing independent feather sprites.
                        float wingRegion = smoothstep(0.16, 0.88,
                            abs(flowUv.x - 0.5) * 2.0)
                            * smoothstep(0.34, 0.72, flowUv.y);
                        float featherLanes = smoothstep(0.48, 0.58,
                            0.5 + 0.5 * sin(
                                flowUv.x * 47.0 + flowUv.y * 13.0
                                - _Phase * 0.42));
                        float tailRegion = 1.0 - smoothstep(0.34, 0.58,
                            flowUv.y);
                        float tailLanes = smoothstep(0.50, 0.62,
                            0.5 + 0.5 * sin(
                                flowUv.x * 34.0 - flowUv.y * 18.0
                                + _Phase * 0.58));
                        silhouetteBody = lerp(silhouetteBody,
                            _DeepColor.rgb * 0.72,
                            wingRegion * featherLanes * 0.16
                                + tailRegion * tailLanes * 0.10);

                        // Shade the lower edge of the pointed beak so the
                        // profile remains legible when the effect blooms.
                        float beakRegion = smoothstep(0.70, 0.96,
                            flowUv.x) * smoothstep(0.78, 0.94,
                                flowUv.y);
                        silhouetteBody = lerp(silhouetteBody,
                            _DeepColor.rgb * 0.52,
                            beakRegion * smoothstep(0.78, 0.88,
                                flowUv.y) * 0.32);

                        // A small internal eye gives the continuous contour a
                        // focal point without adding another sprite or quad.
                        float eyeDistance = length(
                            (flowUv - float2(0.62, 0.865))
                            * float2(1.0, 1.55));
                        float eye = 1.0 - smoothstep(0.012, 0.032,
                            eyeDistance);
                        silhouetteBody = lerp(silhouetteBody,
                            _DeepColor.rgb * 0.28, eye * 0.88);
                        float silhouetteAlpha = min(_AlphaCap,
                            customVertexAlpha * _Opacity);
                        return fixed4(silhouetteBody * silhouetteAlpha
                            * _Intensity, silhouetteAlpha);
                    }

                    // A phoenix body needs a rounded mass behind the pointed
                    // Fire_Single feathers. This analytic oval is still
                    // rendered by the same Effekseer recolour material; it
                    // only prevents the chest and head from collapsing into
                    // another sharp shard at phone-sized review scale.
                    if (phoenixMesh > 0.5)
                    {
                        float2 phoenixPoint = flowUv * 2.0 - 1.0;
                        float phoenixRadius = length(
                            phoenixPoint * float2(0.86, 1.0));
                        float phoenixMask = 1.0 - smoothstep(
                            0.74, 1.0, phoenixRadius);
                        float phoenixHighlight = 1.0 - smoothstep(
                            0.05, 0.82,
                            length(phoenixPoint - float2(-0.18, 0.22)));
                        float phoenixAlpha = min(_AlphaCap,
                            customVertexAlpha * phoenixMask * _Opacity);
                        fixed3 phoenixBody = lerp(_DeepColor.rgb,
                            _Tint.rgb, 0.58 + sourceDetail * 0.12);
                        phoenixBody = lerp(phoenixBody, _HotColor.rgb,
                            phoenixHighlight * 0.24 + n0 * 0.06);
                        phoenixBody = lerp(phoenixBody, _WarmColor.rgb,
                            phoenixHighlight * 0.10);
                        return fixed4(phoenixBody * phoenixAlpha
                            * _Intensity, phoenixAlpha);
                    }

                    if (leafMesh > 0.5)
                    {
                        float leafAlong = saturate(flowUv.y);
                        float leafHalfWidth = max(0.045,
                            sin(leafAlong * 3.1415926) * 0.48);
                        float leafMask = 1.0 - smoothstep(
                            leafHalfWidth * 0.78,
                            leafHalfWidth,
                            abs(flowUv.x - 0.5));
                        float vein = 1.0 - smoothstep(0.02, 0.09,
                            abs(flowUv.x - 0.5));
                        float leafAlpha = min(_AlphaCap,
                            customVertexAlpha * leafMask * _Opacity);
                        fixed3 leafBody = lerp(_DeepColor.rgb,
                            _Tint.rgb, 0.46 + sourceDetail * 0.24);
                        leafBody = lerp(leafBody, _HotColor.rgb,
                            sourceDetail * 0.22);
                        leafBody += _HotColor.rgb * vein * 0.16;
                        // Leaf meshes carry their own vertex colour so a
                        // phoenix can separate ember-red body, solar-gold
                        // wings, and warm-white head without another texture
                        // or material instance.
                        fixed3 leafVertexTint = max(input.color.rgb,
                            fixed3(0.02, 0.02, 0.02));
                        leafBody = lerp(leafBody, leafVertexTint,
                            saturate(_VertexMix * 0.78));
                        return fixed4(leafBody * leafAlpha * _Intensity,
                            leafAlpha);
                    }

                    // The source texture is material detail, not a complete
                    // silhouette.  Analytic flow noise opens and closes the
                    // ribbon so three streams read as broken volume instead
                    // of transparent plastic bands.
                    float volumeFill = saturate(_VolumeFill);
                    float volumeDensity = smoothstep(0.20, 0.86, density);
                    float customAlpha = min(_AlphaCap,
                        (customVertexAlpha * (0.07 + holes * 0.42)
                            + filament * 0.065
                            + volumeFill * (0.12 + volumeDensity * 0.28))
                        * ribbonEdge * dissolve * eyeMask * _Opacity
                        * airDensityVariation);
                    float customValue = saturate(holes * 0.72
                        + filament * 0.18 + sourceDetail * 0.10
                        + volumeFill * (0.10 + volumeDensity * 0.18));
                    float highValue = smoothstep(0.76, 0.98, density);
                    fixed3 customBody = lerp(_DeepColor.rgb,
                        _Tint.rgb, customValue * 0.84);
                    customBody = lerp(customBody, _HotColor.rgb,
                        smoothstep(0.52, 0.90, customValue) * 0.38
                        + filament * 0.08 + highValue * 0.16);
                    customBody = lerp(customBody, _WarmColor.rgb,
                        smoothstep(0.84, 0.98, customValue) * 0.12
                        + highValue * 0.08);
                    customBody += _HotColor.rgb
                        * (0.035 + holes * 0.105 + filament * 0.035
                            + highValue * 0.10);
                    customBody = saturate(customBody * (1.08
                        + sourceDetail * 0.24 + filament * 0.08));
                    customBody = lerp(customBody, customSource.rgb,
                        min(_SourceMix, 0.12) * sourceDetail);
                    fixed3 customVertexTint = max(input.color.rgb,
                        fixed3(0.02, 0.06, 0.03));
                    // Connected VFX V1 surfaces carry their palette in the
                    // vertex colour: green roots, lime/gold waists, and an
                    // occasional orange tip. The previous factor was small
                    // enough that blue_fire's shared green material washed
                    // every layer back to one yellow-green tone.
                    customBody = lerp(customBody, customVertexTint,
                        saturate(_VertexMix * 0.72));
                    return fixed4(customBody * customAlpha * _Intensity,
                        customAlpha);
                }
                float2 centered = local * 2.0 - 1.0;
                float edgeStart = lerp(0.68, 0.38, _EdgeErode);
                float edgeX = 1.0 - smoothstep(edgeStart, 0.98, abs(centered.x));
                float edgeY = 1.0 - smoothstep(edgeStart, 0.98, abs(centered.y));
                float edge = edgeX * edgeY;
                float organicRadius = lerp(1.32, 0.78, _EdgeErode);
                organicRadius += (sin(centered.x * 8.7 + _Phase * 5.1)
                    + cos(centered.y * 10.3 - _Phase * 4.2))
                    * 0.055 * _EdgeErode;
                float organicEdge = 1.0 - smoothstep(
                    organicRadius - 0.22,
                    organicRadius + 0.10,
                    length(centered * float2(0.88, 1.0)));
                edge *= lerp(1.0, organicEdge, _EdgeErode);

                // Two phase-offset analytic flow bands keep every crop alive.
                // The source texture supplies the silhouette and fine detail;
                // the shader only bends it, so this never becomes a translated
                // whole-frame image.
                float2 warp;
                warp.x = sin(local.y * 12.7 + _Phase * 6.8)
                    + sin(local.y * 28.1 - _Phase * 3.9) * 0.34;
                warp.y = cos(local.x * 10.9 - _Phase * 5.4)
                    + sin(local.x * 24.3 + _Phase * 4.7) * 0.30;
                float2 uv = input.uv + warp * (_Distortion * 0.055) * edge;
                fixed4 source = tex2D(_MainTex, uv);
                // Use a stable perceptual luminance for every mature atlas.
                // The previous green-heavy weighting made blue_fire's cyan
                // source dominate the recolour and exposed its indigo/pink
                // value islands when several crops overlapped.
                float luminance = dot(source.rgb, float3(0.299, 0.587, 0.114));
                float mask = smoothstep(_CutLow, max(_CutLow + 0.002, _CutHigh), luminance);
                // Effekseer textures often store the actual silhouette in
                // alpha while leaving bright RGB in transparent texels.  The
                // old luminance-only mask therefore rendered SnowCrystals as
                // square cards and exposed crop borders on flame atlases.
                // RGB mature atlases such as blue_fire and Burst01_2 carry
                // their silhouette in luminance and intentionally have no
                // alpha channel.  Gray+alpha atlases such as Fire_Single and
                // SnowCrystals_M opt into the alpha gate explicitly from C#.
                mask *= lerp(1.0, source.a, _UseSourceAlpha);
                // Connected runtime strips already carry their own silhouette
                // through vertex alpha and the source crop. Do not apply the
                // billboard edge mask to those strips; the card-domain mask
                // can erase the entire mesh when TEXCOORD1 is interpolated
                // along a non-rectangular path.
                edge = lerp(edge, 1.0, customMesh);
                mask = lerp(mask, max(mask, 1.0), customMesh);

                // Wind and shockwave textures may be reduced to a broken arc.
                // Full-span materials bypass this branch entirely.
                float angle01 = frac(atan2(centered.y, centered.x) / 6.2831853
                    - _Phase * 0.27 + 1.0);
                float arcDistance = abs(frac(angle01 + 0.5) - 0.5);
                float arcHalf = saturate(_ArcSpan) * 0.5;
                float arcMask = 1.0 - smoothstep(max(0.0, arcHalf - 0.12),
                    arcHalf + 0.11, arcDistance);
                float arcEnabled = 1.0 - step(0.985, _ArcSpan);
                mask *= lerp(1.0, arcMask, arcEnabled);

                float vertexAlpha = saturate(input.color.a);
                float alpha = min(_AlphaCap, mask * vertexAlpha * _Opacity * edge);
                float value = smoothstep(_CutLow, 0.90, luminance);
                fixed3 body = lerp(_DeepColor.rgb, _Tint.rgb, smoothstep(0.02, 0.68, value));
                body = lerp(body, _HotColor.rgb, pow(saturate(value), 4.8) * 0.62);

                // blue_fire already contains the mature cyan / indigo /
                // violet temperature variation that made the source sample
                // look expensive.  Preserve it for body cards; ring and
                // burst materials keep SourceMix near zero so they still use
                // the authored frost palette.
                float sourcePeak = max(0.035, max(source.r, max(source.g, source.b)));
                fixed3 sourceHue = saturate(source.rgb / sourcePeak);
                // Keep most of the photographed source hue/value.  The old
                // multiplication by one shared cyan ramp made blue_fire's
                // violet, indigo and jade detail collapse into a flat cyan
                // slab once several cards overlapped.
                fixed3 preservedSource = saturate(source.rgb * 1.04);
                fixed3 sourceBody = lerp(
                    preservedSource,
                    sourceHue * lerp(_Tint.rgb, _HotColor.rgb,
                        smoothstep(0.18, 0.92, value)),
                    0.22);
                body = lerp(body, sourceBody, _SourceMix);

                // Vertex colour separates adjacent cards without flattening
                // away the source texture's internal value structure.
                fixed3 vertexTint = max(input.color.rgb, fixed3(0.02,0.06,0.10));
                body *= lerp(fixed3(1.0,1.0,1.0), vertexTint * 1.18,
                    _VertexMix * 0.52);
                body = lerp(body, vertexTint, _VertexMix * 0.34);
                float hot = pow(saturate(value), 9.0);
                float warm = pow(saturate(value), 16.0) * _WarmAmount;
                fixed3 rgb = body * alpha
                    + _HotColor.rgb * hot * alpha * 0.14
                    + _WarmColor.rgb * warm * alpha;
                rgb *= _Intensity;
                return fixed4(rgb, alpha);
            }
            ENDCG
        }
    }
}
