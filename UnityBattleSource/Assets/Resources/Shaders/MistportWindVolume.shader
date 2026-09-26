Shader "Mindstone/Mistport Wind Volume"
{
    Properties
    {
        _NoiseTex ("Flow Noise", 2D) = "gray" {}
        _Color ("Tint", Color) = (1,1,1,1)
        _Phase ("Flow Phase", Float) = 0
        _Intensity ("Volume Intensity", Range(0, 2)) = 1
        _Core ("Luminous Core", Range(0, 1)) = 0
        _Distortion ("Flow Distortion", Range(0, 0.35)) = 0.10
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
            fixed4 _Color;
            float _Phase;
            float _Intensity;
            float _Core;
            float _Distortion;

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
                float2 flow = float2(_Phase * 0.021, -_Phase * 0.038);
                float2 uvA = input.uv * 1.18 + flow;
                float2 uvB = input.uv * 2.46 - flow * 1.31 + float2(0.37, 0.11);
                float n = tex2D(_NoiseTex, uvA).r;
                float n2 = tex2D(_NoiseTex, uvB).g;
                float edgeWeight = smoothstep(0.16, 1.0, length(p));
                p += (float2(n, n2) - 0.5) * _Distortion * edgeWeight;

                float h = saturate((p.y + 1.0) * 0.5);
                float center = sin(p.y * 2.75 + _Phase * 0.31) * 0.065
                    + sin(p.y * 6.2 - _Phase * 0.19) * 0.026
                    + (n2 - 0.5) * 0.075;
                // Broad at the crown, grounded at the base, with a soft
                // asymmetry like a hand-painted gust rather than a cone.
                float width = lerp(0.57, 0.80, h)
                    + sin(p.y * 3.6 + _Phase * 0.22) * 0.035
                    + (n - 0.5) * 0.075;
                float vertical = smoothstep(-1.02, -0.78, p.y)
                    * (1.0 - smoothstep(0.82, 1.05, p.y));
                float normalizedX = abs(p.x - center) / max(0.18, width);
                float silhouette = 1.0 - smoothstep(0.88, 1.04, normalizedX);
                float sideSheet = 1.0 - smoothstep(0.025, 0.17, abs(normalizedX - 0.84));
                sideSheet *= vertical * (0.88 + n * 0.13);
                float veil = silhouette * vertical * (0.075 + n * 0.08 + n2 * 0.05);

                // Two living helical currents create movement inside the
                // connected veil. They are broad, soft lanes, never straight
                // LineRenderer bars.
                float helixRadius = lerp(0.34, 0.52, h);
                float laneCenterA = center
                    + sin(p.y * 4.15 + _Phase * 0.68) * helixRadius;
                float laneCenterB = center
                    + sin(p.y * 4.15 + _Phase * 0.68 + 2.55) * helixRadius;
                float helixA = 1.0 - smoothstep(0.045, 0.16, abs(p.x - laneCenterA));
                float helixB = 1.0 - smoothstep(0.045, 0.16, abs(p.x - laneCenterB));
                float lanes = max(helixA, helixB) * silhouette * vertical;
                lanes *= 0.72 + n2 * 0.42;

                // Broken, uneven floor vortex and a warm rising heart. The
                // angular breakup keeps it from reading as a UI circle.
                float2 baseP = float2((p.x - center) / 0.74, (p.y + 0.73) / 0.22);
                float baseRadius = length(baseP);
                float baseAngle = atan2(baseP.y, baseP.x);
                float broken = smoothstep(0.22, 0.74,
                    0.52 + 0.34 * sin(baseAngle * 3.0 + _Phase * 0.42)
                    + (n - 0.5) * 0.48);
                float baseRing = (1.0 - smoothstep(0.055, 0.17, abs(baseRadius - 1.0))) * broken;
                float baseGlow = 1.0 - smoothstep(0.08, 1.10,
                    length(float2((p.x - center) / 0.72, (p.y + 0.69) / 0.36)));
                float heart = 1.0 - smoothstep(
                    0.06,
                    0.34,
                    abs(p.x - center - sin(p.y * 4.8 - _Phase * 0.48) * 0.08));
                heart *= smoothstep(-0.90, -0.67, p.y)
                    * (1.0 - smoothstep(-0.03, 0.52, p.y));

                float density = saturate(
                    veil
                    + sideSheet * 0.62
                    + lanes * 0.46
                    + baseRing * 0.68
                    + baseGlow * (0.42 + _Core * 0.24)
                    + heart * (0.32 + _Core * 0.38));
                density *= 0.80 + n * 0.26 + n2 * 0.14;

                float3 deep = float3(0.16, 0.34, 0.23);
                float3 mint = float3(0.64, 0.88, 0.72);
                float3 ivory = float3(0.95, 1.00, 0.94);
                float3 lime = float3(0.68, 0.96, 0.38);
                float3 gold = float3(1.00, 0.82, 0.24);
                float3 color = lerp(deep, mint, saturate(0.46 + n * 0.38));
                color = lerp(color, ivory, saturate(sideSheet * 0.88 + veil * 0.28));
                color = lerp(color, lime, saturate(lanes * 0.44));
                color = lerp(color, gold, saturate((baseGlow + baseRing + heart) * _Core * 0.78));
                color *= _Color.rgb * (0.94 + _Core * 0.11 + baseGlow * 0.16);

                return fixed4(color, saturate(density * _Color.a * _Intensity));
            }
            ENDCG
        }
    }
}
