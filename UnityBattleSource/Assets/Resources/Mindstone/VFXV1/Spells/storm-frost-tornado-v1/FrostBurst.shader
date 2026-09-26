Shader "Mindstone/VFXV1/Frost Tornado Aurora Burst"
{
    Properties
    {
        _MainTex ("Directionless Burst Noise", 2D) = "white" {}
        _Tint ("Aurora Body", Color) = (0.08,0.78,0.72,1)
        _HotColor ("White Hot Ice", Color) = (0.90,1.00,0.96,1)
        _Phase ("Continuous Phase", Float) = 0
        _Opacity ("Opacity", Range(0,1)) = 1
        _AlphaCap ("Alpha Cap", Range(0,1)) = 0.44
        _Coverage ("Dense Coverage", Range(0,1)) = 0.36
        _Occlusion ("Actor Engulfment", Range(0,1)) = 0.30
        _Intensity ("Color Intensity", Range(0,4)) = 1.34
        _Accent ("White Hot Accent", Range(0,1)) = 0.58
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
                float2 p = input.uv * 2.0 - 1.0;
                float n0 = tex2D(_MainTex, input.uv * 1.43
                    + float2(_Phase * 0.21, _Phase * 0.47)).r;
                float n1 = tex2D(_MainTex, input.uv.yx * 2.37
                    + float2(-_Phase * 0.37, _Phase * 0.19)).g;
                float n2 = tex2D(_MainTex, input.uv * 4.71
                    + float2(_Phase * 0.09, -_Phase * 0.31)).b;

                // Directional frost-flame silhouette.  The former radial
                // envelope turned every particle into a fuzzy oval/leaf and
                // made the late frame look like coloured cotton.  These
                // particles now have a broad torn root and a narrow hooked
                // tip; renderer rotation aligns that taper with its velocity.
                float y01 = saturate((p.y + 1.0) * 0.5);
                float endMask = smoothstep(-1.0, -0.76, p.y)
                    * (1.0 - smoothstep(0.72, 1.0, p.y));
                float lateralWarp = (n0 - 0.5) * 0.22 * (1.0 - abs(p.y) * 0.54)
                    + sin(y01 * 10.8 + _Phase * 4.2) * 0.055;
                float halfWidth = lerp(0.78, 0.075, pow(y01, 0.78))
                    * lerp(0.82, 1.12, n1);
                float side = abs(p.x + lateralWarp) / max(halfWidth, 0.045);
                float envelope = (1.0 - smoothstep(0.70, 1.05, side)) * endMask;
                float density = saturate(n0 * 0.52 + n1 * 0.34 + n2 * 0.24 - 0.08);
                float tornBody = envelope * lerp(0.42, 1.0,
                    smoothstep(0.20, 0.78, density));
                float center = pow(saturate(1.0 - side), 1.70) * endMask;
                // Particle timing is authored deterministically in C#.  A
                // non-zero floor here kept already-faded pressure particles
                // visible and rebuilt an unwanted solid core during the late
                // breakup beat.  Respect zero exactly so stage five can open
                // a real hole while the newer outward fragments remain.
                float vertexAlpha = saturate(input.color.a);

                float alpha = _Opacity * vertexAlpha * tornBody;
                float dense = _Coverage * vertexAlpha * envelope
                    * lerp(0.58, 1.0, smoothstep(0.22, 0.74, density));
                float engulf = _Occlusion * vertexAlpha * envelope
                    * lerp(0.72, 1.0, center);
                alpha = min(_AlphaCap, max(alpha, max(dense, engulf)));

                // The colour hierarchy is intentionally triadic: jade/cyan
                // mass, violet refraction, and sparse gold-white hot ice.
                // Per-particle colour determines the local family while the
                // common hot centre visually welds all particles together.
                fixed3 particle = max(input.color.rgb, fixed3(0.025, 0.18, 0.30));
                float violetSignal = saturate((particle.b - particle.g * 0.58) * 2.4);
                float goldSignal = saturate((particle.r - particle.b * 0.72) * 2.8);
                fixed3 body = lerp(_Tint.rgb, particle, 0.82);
                body = lerp(body, fixed3(0.70, 0.30, 1.00), violetSignal * 0.34);
                body = lerp(body, fixed3(1.00, 0.72, 0.16), goldSignal * 0.42);
                float hot = pow(center, 2.4) * lerp(0.58, 1.0, density) * _Accent;
                float rim = pow(saturate(envelope * (1.0 - center)), 2.2)
                    * smoothstep(0.56, 0.92, density);
                fixed3 rgb = body * alpha
                    + _HotColor.rgb * hot * alpha * 0.34
                    + fixed3(0.28, 0.95, 1.00) * rim * alpha * 0.16;
                rgb *= _Intensity;
                return fixed4(rgb, alpha);
            }
            ENDCG
        }
    }
}
