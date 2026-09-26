Shader "Mindstone/VFXV1/Wraith Scream Volume"
{
    Properties
    {
        _MainTex ("Flow Noise", 2D) = "white" {}
        _DeepColor ("Deep Violet", Color) = (0.035, 0.002, 0.085, 1)
        _MidColor ("Spectral Magenta", Color) = (0.55, 0.025, 0.88, 1)
        _EdgeColor ("Cold Edge", Color) = (0.05, 0.95, 0.82, 1)
        _Opacity ("Opacity", Range(0, 1)) = 1
        _Intensity ("Intensity", Range(0, 8)) = 2
        _Phase ("Phase", Float) = 0
        _Pulse ("Pulse", Range(0, 1)) = 0
    }

    SubShader
    {
        Tags { "Queue"="Transparent+350" "RenderType"="Transparent" "IgnoreProjector"="True" }
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

            sampler2D _MainTex;
            float4 _MainTex_ST;
            float4 _DeepColor;
            float4 _MidColor;
            float4 _EdgeColor;
            float _Opacity;
            float _Intensity;
            float _Phase;
            float _Pulse;

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
                float4 color : COLOR;
            };

            struct v2f
            {
                float4 position : SV_POSITION;
                float2 uv : TEXCOORD0;
                float4 color : COLOR;
            };

            float hash21(float2 value)
            {
                value = frac(value * float2(123.34, 456.21));
                value += dot(value, value + 45.32);
                return frac(value.x * value.y);
            }

            float noise2d(float2 value)
            {
                float2 cell = floor(value);
                float2 local = frac(value);
                local = local * local * (3.0 - 2.0 * local);
                float a = hash21(cell);
                float b = hash21(cell + float2(1, 0));
                float c = hash21(cell + float2(0, 1));
                float d = hash21(cell + float2(1, 1));
                return lerp(lerp(a, b, local.x), lerp(c, d, local.x), local.y);
            }

            v2f vert(appdata input)
            {
                v2f output;
                output.position = UnityObjectToClipPos(input.vertex);
                output.uv = TRANSFORM_TEX(input.uv, _MainTex);
                output.color = input.color;
                return output;
            }

            fixed4 frag(v2f input) : SV_Target
            {
                // Mesh U runs mouth-to-target and V crosses the pressure body.
                // Keep a dense mother shape behind the detailed wave filaments,
                // but warp and erode its edge so it never reads as a straight
                // tube or a perfect geometric cone.
                float longitudinal = input.uv.x;
                float signedAcross = input.uv.y * 2.0 - 1.0;
                float bodyWarp = sin(longitudinal * 12.7 - _Phase * 3.8)
                        * 0.075
                    + sin(longitudinal * 31.4 + _Phase * 5.1) * 0.025;
                float side = abs(signedAcross + bodyWarp);
                float edge = smoothstep(0.54, 0.96, side);
                float cone = pow(saturate(1.0 - side), 1.12);
                float caps = smoothstep(0.0, 0.045, longitudinal)
                    * (1.0 - smoothstep(0.94, 1.0, longitudinal));
                float breath = 0.78 + 0.22 * sin(
                    longitudinal * 11.0 - _Phase * 5.4
                    + signedAcross * 2.5);
                float flowTexture = tex2D(_MainTex,
                    float2(longitudinal * 3.6 + _Phase * 0.035,
                        input.uv.y * 1.85 - _Phase * 0.08
                            + bodyWarp * 0.7)).r;
                float turbulent = noise2d(
                    float2(longitudinal * 15.0, input.uv.y * 8.5)
                    + float2(_Phase * 0.12, -_Phase * 0.24));
                float broken = saturate(flowTexture * 0.55 + turbulent * 0.62);
                float edgeTear = smoothstep(0.18, 0.76,
                    noise2d(float2(longitudinal * 31.0
                            - _Phase * 0.9,
                        input.uv.y * 11.0 + _Phase * 0.55)));
                float tornSilhouette = lerp(1.0, edgeTear,
                    smoothstep(0.38, 0.96, side));
                float alpha = cone * caps * breath
                    * (0.16 + broken * 0.31 + edge * 0.055)
                    * tornSilhouette;
                alpha *= _Opacity * input.color.a
                    * lerp(0.88, 1.10, _Pulse);
                clip(alpha - 0.004);

                float hot = saturate(broken * 0.52 + _Pulse * 0.28);
                float3 color = lerp(_DeepColor.rgb, _MidColor.rgb,
                    saturate(0.25 + broken * 0.72));
                color = lerp(color, _EdgeColor.rgb,
                    saturate(edge * 0.24 + hot * 0.18));
                color *= input.color.rgb * _Intensity;
                return fixed4(color, alpha);
            }
            ENDCG
        }
    }
}
