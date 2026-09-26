Shader "Mindstone/VFXV1/Frost Organic Impact Plume"
{
    Properties
    {
        _MainTex ("Organic Smoke Atlas", 2D) = "white" {}
        _Tint ("Aurora Body", Color) = (0.05,0.78,0.72,1)
        _HotColor ("White Hot Core", Color) = (0.92,1.00,0.94,1)
        _Phase ("Continuous Phase", Float) = 0
        _Opacity ("Opacity", Range(0,1)) = 1
        _AlphaCap ("Alpha Cap", Range(0,1)) = 0.72
        _Coverage ("Dense Coverage", Range(0,1)) = 0.52
        _Occlusion ("Actor Engulfment", Range(0,1)) = 0.46
        _Intensity ("Color Intensity", Range(0,4)) = 1.7
        _Accent ("White Hot Accent", Range(0,1)) = 0.68
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
                fixed4 smoke = tex2D(_MainTex, input.uv);
                float density = saturate(dot(smoke.rgb, float3(0.30, 0.52, 0.18)));
                float mask = saturate(max(smoke.a, density));

                // Particle-sheet animation remaps UVs to one of four atlas
                // cells. Recover cell-local coordinates only for the soft hot
                // core; the silhouette itself is entirely supplied by the
                // photographed smoke, never by a geometric wedge or ring.
                float2 localUV = frac(input.uv * 2.0);
                float2 p = localUV * 2.0 - 1.0;
                float radial = saturate(1.0 - dot(p, p));
                float cellular = smoothstep(0.06, 0.88, density);
                float vertexAlpha = max(input.color.a, 0.001);

                float alpha = mask * vertexAlpha * _Opacity;
                float dense = mask * vertexAlpha * _Coverage
                    * lerp(0.48, 1.0, cellular);
                float engulf = mask * vertexAlpha * _Occlusion
                    * lerp(0.72, 1.0, radial);
                alpha = min(_AlphaCap, max(alpha, max(dense, engulf)));

                fixed3 particle = max(input.color.rgb, fixed3(0.02, 0.12, 0.18));
                float violetSignal = saturate((particle.b - particle.g * 0.64) * 2.1);
                float goldSignal = saturate((particle.r - particle.b * 0.70) * 2.6);
                fixed3 body = lerp(_Tint.rgb, particle, 0.84);
                body = lerp(body, fixed3(0.72, 0.30, 1.00), violetSignal * 0.32);
                body = lerp(body, fixed3(1.00, 0.72, 0.18), goldSignal * 0.42);

                float pulse = 0.92 + 0.08 * sin(_Phase * 6.28318
                    + density * 8.0 + input.color.b * 4.0);
                float hot = pow(radial, 2.2) * smoothstep(0.22, 0.82, density)
                    * _Accent * pulse;
                float coldRim = smoothstep(0.18, 0.72, mask)
                    * (1.0 - smoothstep(0.58, 0.96, density));

                fixed3 rgb = body * alpha
                    + _HotColor.rgb * hot * alpha * 0.24
                    + fixed3(0.20, 0.92, 1.00) * coldRim * alpha * 0.18;
                rgb *= _Intensity;
                return fixed4(rgb, alpha);
            }
            ENDCG
        }
    }
}
