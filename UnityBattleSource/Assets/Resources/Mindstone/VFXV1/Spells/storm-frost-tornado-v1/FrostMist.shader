Shader "Mindstone/VFXV1/Frost Tornado Soft Mist"
{
    Properties
    {
        _MainTex ("Directionless Mist Noise", 2D) = "white" {}
        _Tint ("Tint", Color) = (0.12,0.52,0.58,1)
        _HotColor ("Dense Ice", Color) = (0.66,0.91,0.91,1)
        _Phase ("Continuous Phase", Float) = 0
        _Opacity ("Opacity", Range(0,1)) = 0.55
        _AlphaCap ("Alpha Cap", Range(0,1)) = 0.31
        _Coverage ("Dense Cloud Coverage", Range(0,1)) = 0
        _Occlusion ("Irregular Opaque Core", Range(0,1)) = 0
        _Intensity ("Color Intensity", Range(0,4)) = 1
        _Accent ("Moving Ice Luminance", Range(0,1)) = 0
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
            float _AlphaCap;
            float _Coverage;
            float _Occlusion;
            float _Intensity;
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
                float2 centered = input.uv * 2.0 - 1.0;
                centered.x *= 0.82;
                float radius = length(centered);
                float radial = 1.0 - smoothstep(0.40, 1.0, radius);
                float n0 = tex2D(_MainTex, input.uv * 1.34
                    + float2(_Phase * 0.17, _Phase * 0.61)).r;
                float n1 = tex2D(_MainTex, input.uv.yx * 2.11
                    + float2(-_Phase * 0.31, _Phase * 0.23)).g;
                // Keep mist as broken negative-space support.  The previous
                // unshifted sum filled almost every particle quad and made the
                // spell read as a white cloud instead of rotating ice qi.
                float density = saturate(n0 * 0.61 + n1 * 0.39 - 0.21);
                float macroPocket = smoothstep(0.47, 0.82,
                    n0 * 0.70 + n1 * 0.30 + centered.y * 0.05);
                float cavity = smoothstep(0.18, 0.62,
                    abs(n0 - n1) + (1.0 - density) * 0.28);
                float breakup = lerp(0.18, 0.88, macroPocket)
                    * lerp(0.42, 0.96, smoothstep(0.30, 0.82, density))
                    * lerp(0.70, 1.0, cavity);
                float vertexAlpha = max(input.color.a, 0.010);
                float alpha = min(_AlphaCap, _Opacity * vertexAlpha
                    * radial * breakup * 1.32);
                // Optional dense particle core. This is still eroded by both
                // noise channels and the radial falloff, so overlapping
                // particles can occlude an actor without exposing a card or
                // a clean geometric disc.
                float coverageNoise = smoothstep(0.34, 0.78,
                    density * 0.78 + macroPocket * 0.38);
                float denseCoverage = _Coverage * vertexAlpha * radial
                    * coverageNoise * lerp(0.72, 1.0, macroPocket);
                alpha = min(_AlphaCap, max(alpha, denseCoverage));
                float opaqueCloud = _Occlusion * vertexAlpha * radial
                    * lerp(0.46, 1.0, coverageNoise)
                    * lerp(0.76, 1.0, macroPocket);
                alpha = min(_AlphaCap, max(alpha, opaqueCloud));
                float packetCoord = frac(input.uv.y * 1.72
                    + input.uv.x * 0.36 - _Phase * 1.08);
                float packet = pow(saturate(1.0 - abs(packetCoord * 2.0 - 1.0)), 11.0)
                    * smoothstep(0.42, 0.80, density) * _Accent;
                alpha = min(_AlphaCap, alpha + packet * radial * 0.045);
                fixed3 shadow = fixed3(0.025, 0.24, 0.22);
                fixed3 body = lerp(shadow, _Tint.rgb * 1.06,
                    smoothstep(0.24, 0.86, density * macroPocket));
                // RGB remains an authored jade/cyan palette signal, but it no
                // longer injects magenta into every dense cloud overlap.
                float warmSignal = saturate((input.color.r - input.color.b) * 3.2);
                fixed3 particleBody = lerp(max(input.color.rgb * 0.58,
                        fixed3(0.035, 0.28, 0.26)),
                    input.color.rgb * 1.04,
                    smoothstep(0.20, 0.86, density));
                body = lerp(body, particleBody, 0.74);
                body = lerp(body, fixed3(0.96, 0.82, 0.34), warmSignal * 0.24);
                float highlight = pow(smoothstep(0.76, 0.97, density), 3.2);
                fixed3 rgb = body * alpha
                    + _HotColor.rgb * highlight * alpha * 0.12
                    + fixed3(0.36, 0.84, 0.88) * packet * radial * 0.18
                    + fixed3(0.86, 0.92, 0.68) * warmSignal
                        * highlight * alpha * 0.06;
                rgb *= _Intensity;
                return fixed4(rgb, alpha);
            }
            ENDCG
        }
    }
}
