Shader "Mindstone/VFXV1/Frost Crystal Facets"
{
    Properties
    {
        _Tint ("Ice Blue", Color) = (0.45,0.84,0.90,1)
        _HotColor ("Rare Warm Facet", Color) = (0.92,0.87,0.75,1)
        _Opacity ("Opacity", Range(0,1)) = 0.88
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

            fixed4 _Tint;
            fixed4 _HotColor;
            float _Opacity;

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
                float2 p = input.uv * 2.0 - 1.0;
                float seed = frac(dot(input.color.rgb, float3(7.31, 13.17, 19.73)));
                // Tapered, bent spear silhouette.  It deliberately avoids the
                // symmetric |x|+|y| diamond that exposed regular blue tiles.
                p.x += p.y * (seed - 0.5) * 0.34;
                p.x += sin((p.y + seed) * 8.4) * 0.045 * (1.0 - abs(p.y));
                float vertical = smoothstep(-1.0, -0.80, p.y)
                    * (1.0 - smoothstep(0.86, 1.0, p.y));
                float height01 = saturate((p.y + 1.0) * 0.5);
                float halfWidth = lerp(0.62, 0.025, pow(height01, 0.82));
                halfWidth *= 0.86 + 0.14 * sin(p.y * 10.7 + seed * 12.0);
                float side = abs(p.x) / max(halfWidth, 0.025);
                float spear = 1.0 - smoothstep(0.76, 1.0, side);
                float chipA = smoothstep(0.04, 0.16,
                    abs(p.x + 0.22 + p.y * 0.16));
                float chipB = smoothstep(0.03, 0.13,
                    abs(p.x - 0.16 + p.y * 0.10));
                float chipped = lerp(0.56, 1.0, max(chipA, chipB));
                float core = spear * vertical * chipped;
                float ridge = pow(saturate(1.0 - side), 2.3);
                float fracture = smoothstep(0.70, 0.96,
                    sin((p.y * 12.0 + p.x * 6.0 + seed * 17.0)) * 0.5 + 0.5);
                float facet = saturate(0.32 + ridge * 0.78 + fracture * 0.20);
                float alpha = saturate(input.color.a * _Opacity * core);
                fixed3 ice = _Tint.rgb * input.color.rgb * lerp(0.58, 1.12, facet);
                float warmSignal = saturate((input.color.r - input.color.b) * 4.0);
                ice = lerp(ice, _HotColor.rgb * lerp(0.72, 1.02, facet), warmSignal * 0.42);
                float rareWarm = pow(ridge, 6.0) * warmSignal * 0.16;
                fixed3 rgb = ice * alpha
                    + fixed3(0.62, 0.91, 0.88) * ridge * fracture * alpha * 0.18
                    + _HotColor.rgb * rareWarm * alpha;
                return fixed4(rgb, alpha);
            }
            ENDCG
        }
    }
}
