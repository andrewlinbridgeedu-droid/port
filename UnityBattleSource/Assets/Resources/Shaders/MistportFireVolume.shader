Shader "Mindstone/Mistport Fire Volume"
{
    Properties
    {
        _NoiseTex ("Flow Noise", 2D) = "gray" {}
        _DetailTex ("Fire Detail", 2D) = "black" {}
        _Color ("Tint", Color) = (1,1,1,1)
        _Phase ("Flow Phase", Float) = 0
        _Intensity ("Volume Intensity", Range(0, 2)) = 1
        _Core ("Hot Core", Range(0, 1)) = 0
        _Distortion ("Flow Distortion", Range(0, 0.35)) = 0.10
        _DetailStrength ("Fire Detail Strength", Range(0, 1)) = 0.24
    }

    SubShader
    {
        Tags
        {
            "Queue" = "Transparent+4300"
            "RenderType" = "Transparent"
            "IgnoreProjector" = "True"
        }
        Cull Off
        Lighting Off
        ZWrite Off
        ZTest Always
        Blend SrcAlpha OneMinusSrcAlpha

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "UnityCG.cginc"

            sampler2D _NoiseTex;
            sampler2D _DetailTex;
            fixed4 _Color;
            float _Phase;
            float _Intensity;
            float _Core;
            float _Distortion;
            float _DetailStrength;

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float4 vertex : SV_POSITION;
                float2 uv : TEXCOORD0;
            };

            v2f vert(appdata input)
            {
                v2f output;
                output.vertex = UnityObjectToClipPos(input.vertex);
                output.uv = input.uv;
                return output;
            }

            fixed4 frag(v2f input) : SV_Target
            {
                float2 p = input.uv * 2.0 - 1.0;
                float2 flow = float2(_Phase * 0.035, -_Phase * 0.021);
                float2 noiseUV = input.uv * 1.18 + flow;
                float2 noiseUV2 = input.uv * 2.35 - flow * 1.31 + float2(0.23, 0.47);
                float n = tex2D(_NoiseTex, noiseUV).r;
                float n2 = tex2D(_NoiseTex, noiseUV2).g;
                float n3 = tex2D(_NoiseTex, input.uv * 3.65 - flow * 0.42 + float2(0.19, 0.63)).r;
                float detailLuma = max(
                    tex2D(_DetailTex, input.uv * float2(0.82, 0.94) + flow * 0.20).r,
                    max(
                        tex2D(_DetailTex, input.uv * float2(0.82, 0.94) + flow * 0.20).g,
                        tex2D(_DetailTex, input.uv * float2(0.82, 0.94) + flow * 0.20).b));
                float2 drift = (float2(n, n2) - 0.5) * _Distortion;
                // The carrier stays coherent in the middle; only the outer
                // silhouette is pushed by the flow field.
                float edge = smoothstep(0.12, 1.0, length(p));
                p += drift * edge;

                float y = p.y;
                float upper = saturate((y + 0.10) * 0.72);
                float bottomEdge = -0.72
                    + sin(p.x * 4.1 - _Phase * 0.38) * 0.11
                    + (n2 - 0.5) * 0.13;
                float topEdge = 0.14
                    + sin(p.x * 4.8 + _Phase * 0.54) * 0.18
                    + (n - 0.5) * 0.16;
                float baseRange = smoothstep(bottomEdge - 0.18, bottomEdge + 0.16, y)
                    * (1.0 - smoothstep(topEdge, topEdge + 0.28, y));
                float bodyWidth = 0.84 - upper * 0.22
                    + (n - 0.5) * 0.18
                    + sin(y * 5.4 + _Phase * 0.62) * 0.055;
                float body = 1.0 - smoothstep(bodyWidth, bodyWidth + 0.13, abs(p.x));
                body *= baseRange;

                // Four broad tongues are blended into the body. They are not
                // separate cards: the shared density makes one moving mass.
                float tongues = 0.0;
                for (int i = 0; i < 4; i++)
                {
                    float lane = -0.54 + i * 0.36;
                    float lanePhase = _Phase * (0.74 + i * 0.08) + i * 1.63;
                    float center = lane
                        + sin((y + 0.85) * (3.7 + i * 0.25) + lanePhase) * 0.14
                        + (n2 - 0.5) * 0.09;
                    float width = 0.15 + (1.0 - saturate((y + 0.75) * 0.62)) * 0.075;
                    float tongue = 1.0 - smoothstep(width, width + 0.075, abs(p.x - center));
                    tongue *= smoothstep(-0.88, -0.47, y);
                    float tongueTop = 0.36 + (i % 3) * 0.15;
                    tongue *= 1.0 - smoothstep(tongueTop, tongueTop + 0.25, y);
                    tongues = max(tongues, tongue);
                }

                // Low side flares give the impact the broad, horizontal
                // footprint seen in the reference without making a ring.
                float flareY = 1.0 - smoothstep(0.16, 0.46, abs(y + 0.24));
                float flareCurve = abs(p.x) - (0.28 + (y + 0.24) * 0.15);
                float flare = 1.0 - smoothstep(0.06, 0.20, flareCurve);
                flare *= smoothstep(0.12, 0.82, abs(p.x));

                float density = saturate(body * 0.44 + tongues * 0.98 + flare * 0.72);
                float flowDensity = 0.62 + n * 0.42 + n2 * 0.22 + n3 * 0.16;
                density *= flowDensity;
                // Keep a strong central veil so the actor is swallowed at
                // the hit peak instead of remaining readable through gaps.
                float centerVeil = 1.0 - smoothstep(0.58, 0.98, length(p * float2(0.88, 0.72)));
                density = saturate(density + centerVeil * 0.12);
                // A final organic falloff guarantees that no source quad is
                // visible at the edge. The internal tongues still break the
                // silhouette, so this is not a geometric circle or ring.
                float envelope = 1.0 - smoothstep(
                    0.88,
                    1.08,
                    length(p * float2(0.94, 0.82)));
                density *= envelope;

                float hotSpot = 1.0 - smoothstep(
                    0.05,
                    0.82,
                    length(float2(p.x * 1.32, (p.y + 0.20) * 1.08)));
                hotSpot *= saturate(body * 0.50 + tongues * 0.70 + flare * 0.46);
                float gold = saturate(hotSpot * 0.92 + _Core * 0.52);
                float white = saturate(hotSpot * _Core * 0.95);
                float3 deep = float3(0.64, 0.008, 0.001);
                float3 red = float3(0.98, 0.035, 0.002);
                float3 orange = float3(1.00, 0.25, 0.008);
                float3 goldColor = float3(1.00, 0.74, 0.055);
                float3 whiteColor = float3(1.00, 0.98, 0.70);
                float3 color = lerp(deep, red, saturate(0.24 + n * 0.54));
                color = lerp(color, orange, saturate(0.18 + body * 0.42));
                color = lerp(color, goldColor, gold);
                color = lerp(color, whiteColor, white * 0.72);
                color *= lerp(0.82, 1.22, detailLuma * _DetailStrength);
                density *= lerp(0.86, 1.14, detailLuma * _DetailStrength);
                color *= _Color.rgb * (0.92 + hotSpot * 0.34 + _Core * 0.20);

                return fixed4(color, saturate(density * _Color.a * _Intensity));
            }
            ENDCG
        }
    }
}
