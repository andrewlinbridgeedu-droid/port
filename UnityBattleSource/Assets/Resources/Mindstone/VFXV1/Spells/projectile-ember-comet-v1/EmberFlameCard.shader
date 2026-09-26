Shader "Mindstone/VFXV1/Ember Flame Card"
{
    Properties
    {
        _DeepColor ("Deep Ember", Color) = (0.18, 0.005, 0.018, 1)
        _MidColor ("Mid Flame", Color) = (1, 0.08, 0.004, 1)
        _HotColor ("Hot Gold", Color) = (1, 0.68, 0.03, 1)
        _WhiteColor ("White Hot", Color) = (1, 0.98, 0.72, 1)
        _Opacity ("Opacity", Range(0, 1)) = 1
        _Intensity ("Intensity", Range(0, 8)) = 2
        _Phase ("Phase", Float) = 0
        _Burst ("Burst", Range(0, 1)) = 0
        _Mode ("Mode", Range(0, 1)) = 0
    }

    SubShader
    {
        Tags
        {
            "Queue" = "Transparent+4400"
            "RenderType" = "Transparent"
            "IgnoreProjector" = "True"
        }
        Cull Off
        Lighting Off
        ZWrite Off
        ZTest Always
        Blend SrcAlpha One

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "UnityCG.cginc"

            float4 _DeepColor;
            float4 _MidColor;
            float4 _HotColor;
            float4 _WhiteColor;
            float _Opacity;
            float _Intensity;
            float _Phase;
            float _Burst;
            float _Mode;

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

            float hash21(float2 coord)
            {
                coord = frac(coord * float2(123.34, 456.21));
                coord += dot(coord, coord + 45.32);
                return frac(coord.x * coord.y);
            }

            float noise2d(float2 coord)
            {
                float2 cell = floor(coord);
                float2 local = frac(coord);
                local = local * local * (3.0 - 2.0 * local);
                float a = hash21(cell);
                float b = hash21(cell + float2(1.0, 0.0));
                float c = hash21(cell + float2(0.0, 1.0));
                float d = hash21(cell + float2(1.0, 1.0));
                return lerp(lerp(a, b, local.x), lerp(c, d, local.x), local.y);
            }

            float fbm(float2 coord)
            {
                float value = 0.0;
                float amplitude = 0.56;
                for (int octave = 0; octave < 4; octave++)
                {
                    value += noise2d(coord) * amplitude;
                    coord = coord * 2.04 + float2(17.1, 9.2);
                    amplitude *= 0.48;
                }
                return saturate(value);
            }

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
                float phase = _Phase * 0.72;
                float noise = fbm(p * 3.4 + float2(phase * 0.24, -phase * 0.18));
                float detail = noise2d(p * 8.5 + float2(-phase * 0.60, phase * 0.41));
                float alpha = 0.0;
                float hot = 0.0;

                if (_Mode < 0.5)
                {
                    // A coherent comet silhouette: round, hot nose and an
                    // uneven flame tail. The shared body keeps it readable
                    // as one projectile instead of disconnected streaks.
                    float head = 1.0 - smoothstep(
                        0.42, 0.86,
                        length(float2(p.x * 0.92, (p.y - 0.22) * 1.08)));
                    float tailAmount = saturate((-p.y + 0.12) * 0.70);
                    float tailCenter = sin(p.y * 4.9 + phase) * 0.12
                        + sin(p.y * 8.2 - phase * 0.83) * 0.055;
                    float tailWidth = lerp(0.38, 0.10, saturate((p.y + 1.0) * 0.50))
                        + noise * 0.12;
                    float tail = 1.0 - smoothstep(
                        tailWidth, tailWidth + 0.12,
                        abs(p.x - tailCenter));
                    tail *= smoothstep(-1.10, -0.42, p.y);
                    tail *= tailAmount;

                    float tongueA = 1.0 - smoothstep(
                        0.02, 0.16,
                        abs(p.x + 0.22 + sin(p.y * 7.0 + phase) * 0.08));
                    tongueA *= smoothstep(-1.05, -0.52, p.y);
                    float tongueB = 1.0 - smoothstep(
                        0.02, 0.13,
                        abs(p.x - 0.20 + sin(p.y * 6.2 - phase * 0.7) * 0.07));
                    tongueB *= smoothstep(-0.94, -0.40, p.y);

                    float body = max(head, tail * (0.60 + noise * 0.74));
                    body = max(body, tongueA * 0.68);
                    body = max(body, tongueB * 0.54);
                    float rim = saturate(1.0 - smoothstep(0.52, 0.96,
                        length(float2(p.x * 0.88, (p.y - 0.04) * 0.94))));
                    float core = saturate(head * 1.1 + tail * 0.50);
                    alpha = saturate(body * (0.48 + noise * 0.78)
                        + rim * 0.18 + (tongueA + tongueB) * 0.15);
                    hot = saturate(core * 0.92 + noise * 0.22);
                }
                else
                {
                    // Radial detonation: a bright contact core, a broken
                    // pressure shell, and long uneven flame spokes.
                    float radius = length(p);
                    float angle = atan2(p.y, p.x);
                    float spokes = saturate(0.5 + 0.5 * cos(
                        angle * 10.0 + phase * 1.5));
                    spokes = pow(spokes, 7.0);
                    float spokeFalloff = 1.0 - smoothstep(0.20, 1.12, radius);
                    float shell = 1.0 - smoothstep(
                        0.04, 0.22, abs(radius - (0.32 + _Burst * 0.44)));
                    float shards = pow(saturate(0.5 + 0.5 * cos(
                        angle * 17.0 - phase * 2.2)), 13.0);
                    float core = 1.0 - smoothstep(0.01, 0.30, radius);
                    float outer = 1.0 - smoothstep(0.36, 1.05, radius);
                    alpha = saturate(core * 1.18
                        + spokes * spokeFalloff * 1.18
                        + shell * (0.66 + detail * 0.42)
                        + shards * outer * 0.72);
                    alpha *= 0.86 + noise * 0.34;
                    hot = saturate(core * 1.3 + spokes * 0.86
                        + shell * 0.26);
                }

                alpha *= _Opacity;
                clip(alpha - 0.002);
                float3 color = lerp(_DeepColor.rgb, _MidColor.rgb,
                    saturate(0.30 + noise * 0.58));
                color = lerp(color, _HotColor.rgb, saturate(hot * 0.90));
                color = lerp(color, _WhiteColor.rgb,
                    saturate(pow(hot, 3.2) * 0.38));
                color *= _Intensity * (0.92 + detail * 0.22);
                return fixed4(color, alpha);
            }
            ENDCG
        }
    }
}
