Shader "Mindstone/Mistport Front Cloud"
{
    Properties
    {
        _Color ("Color", Color) = (1,1,1,1)
        _Phase ("Phase", Float) = 0
    }

    SubShader
    {
        Tags
        {
            "Queue" = "Transparent+300"
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

            fixed4 _Color;
            float _Phase;

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
                float amplitude = 0.55;
                for (int octave = 0; octave < 4; octave++)
                {
                    value += noise2d(coord) * amplitude;
                    coord = coord * 2.03 + 17.1;
                    amplitude *= 0.5;
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
                float2 flow = float2(_Phase * 0.035, -_Phase * 0.022);
                float warp = fbm(p * 2.25 + flow);
                p += (warp - 0.5) * float2(0.22, 0.15);

                float edgeNoise = fbm(p * 3.15 + flow * 1.6);
                float radius = length(float2(p.x * 1.42, p.y * 1.08));
                float body = 1.0 - smoothstep(0.60 + edgeNoise * 0.20, 1.04, radius);

                float streamNoise = fbm(float2(p.x * 5.3 + _Phase * 0.06, p.y * 2.4 - _Phase * 0.045));
                float tornNoise = noise2d(p * 9.0 + flow * 2.0);
                float density = body * (0.34 + streamNoise * 0.90);
                density *= smoothstep(0.06, 0.30, tornNoise + streamNoise * 0.34);

                // A few uneven vertical tongues keep the veil energetic and
                // stop it from reading as a calm circular fog patch.
                float tongue = smoothstep(0.24, 0.02,
                    abs(p.x + sin(p.y * 4.1 + _Phase * 0.11) * 0.08));
                tongue *= smoothstep(1.08, 0.10, abs(p.y));
                density = saturate(density + tongue * body * 0.20);

                float hot = saturate(1.0 - length(p * float2(0.72, 0.86)));
                float light = 0.72 + hot * 0.28 + streamNoise * 0.12;
                fixed3 tint = _Color.rgb * light;
                return fixed4(tint, saturate(density * _Color.a));
            }
            ENDCG
        }
    }
}
