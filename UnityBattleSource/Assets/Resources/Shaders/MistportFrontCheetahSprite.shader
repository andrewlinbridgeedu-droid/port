Shader "Mindstone/Mistport Front Cheetah Sprite"
{
    Properties
    {
        [PerRendererData] _MainTex ("Cheetah Texture", 2D) = "white" {}
        _ClosedTex ("Closed Mouth Texture", 2D) = "white" {}
        _Color ("Tint", Color) = (1,1,1,1)
        _EdgeColor ("Energy Edge", Color) = (1,0.26,0.06,1)
        _Phase ("Motion Phase", Float) = 0
        _ActionPhase ("Limb Action Phase", Float) = 0
        _LimbMotion ("Limb Motion", Range(0,2)) = 1
        _MouthOpen ("Mouth Open", Range(0,1)) = 0
        _Distortion ("Motion Distortion", Range(0,0.2)) = 0.04
        _Dissolve ("Impact Dissolve", Range(0,1)) = 0
        _Glow ("Energy Glow", Range(0,2)) = 0.5
    }

    SubShader
    {
        Tags
        {
            "Queue" = "Transparent+320"
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

            sampler2D _MainTex;
            sampler2D _ClosedTex;
            float4 _MainTex_ST;
            fixed4 _Color;
            fixed4 _EdgeColor;
            float _Phase;
            float _ActionPhase;
            float _LimbMotion;
            float _MouthOpen;
            float _Distortion;
            float _Dissolve;
            float _Glow;

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

            float hash21(float2 p)
            {
                p = frac(p * float2(123.34, 456.21));
                p += dot(p, p + 45.32);
                return frac(p.x * p.y);
            }

            float valueNoise(float2 p)
            {
                float2 cell = floor(p);
                float2 local = frac(p);
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
                float2 centered = input.uv * 2.0 - 1.0;
                float envelope = saturate(1.0 - abs(centered.y) * 0.45);
                float wave = sin(_Phase + centered.y * 8.0 + centered.x * 3.0)
                    + cos(_Phase * 1.31 - centered.y * 5.0);
                input.vertex.x += wave * _Distortion * 0.018 * envelope;
                input.vertex.y += sin(_Phase * 0.73 + centered.x * 6.0) * _Distortion * 0.012;

                // The source is one clean front-facing cheetah, but the mesh
                // is subdivided so the silhouette can act like a creature:
                // alternating forepaw swings, a head nod, and a loose tail.
                // These are vertex deformations, never particle emitters.
                float leftPaw = exp(-pow((input.uv.x - 0.34) / 0.21, 2.0))
                    * (1.0 - smoothstep(0.18, 0.50, input.uv.y));
                float rightPaw = exp(-pow((input.uv.x - 0.66) / 0.21, 2.0))
                    * (1.0 - smoothstep(0.18, 0.50, input.uv.y));
                float pawMotion = _LimbMotion * (0.72 + 0.28 * smoothstep(0.0, 0.34, input.uv.y));
                float action = _ActionPhase * 9.0;
                float leftSwing = sin(action + 0.35);
                float rightSwing = sin(action + 3.49);

                float2 leftPivot = float2(-0.16, -0.27);
                float2 leftOffset = input.vertex.xy - leftPivot;
                float leftAngle = leftSwing * 0.36;
                float leftCos = cos(leftAngle);
                float leftSin = sin(leftAngle);
                float2 leftRotated = float2(
                    leftOffset.x * leftCos - leftOffset.y * leftSin,
                    leftOffset.x * leftSin + leftOffset.y * leftCos);
                input.vertex.xy += (leftRotated - leftOffset) * leftPaw * 0.86;

                float2 rightPivot = float2(0.16, -0.27);
                float2 rightOffset = input.vertex.xy - rightPivot;
                float rightAngle = rightSwing * 0.36;
                float rightCos = cos(rightAngle);
                float rightSin = sin(rightAngle);
                float2 rightRotated = float2(
                    rightOffset.x * rightCos - rightOffset.y * rightSin,
                    rightOffset.x * rightSin + rightOffset.y * rightCos);
                input.vertex.xy += (rightRotated - rightOffset) * rightPaw * 0.86;

                input.vertex.x += (leftPaw * leftSwing + rightPaw * rightSwing)
                    * 0.11 * pawMotion;
                input.vertex.y += (leftPaw * (0.5 + 0.5 * sin(action + 1.2))
                    + rightPaw * (0.5 + 0.5 * sin(action + 4.34)))
                    * 0.066 * pawMotion;

                float head = exp(-pow((input.uv.x - 0.50) / 0.27, 2.0))
                    * smoothstep(0.22, 0.36, input.uv.y)
                    * (1.0 - smoothstep(0.58, 0.68, input.uv.y));
                input.vertex.y += sin(action + 0.7) * head * 0.052 * _LimbMotion;
                input.vertex.x += sin(action + 2.1) * head * 0.030 * _LimbMotion;

                float body = exp(-pow((input.uv.x - 0.50) / 0.34, 2.0))
                    * smoothstep(0.44, 0.58, input.uv.y)
                    * (1.0 - smoothstep(0.76, 0.90, input.uv.y));
                float bodyBeat = sin(action + 1.1);
                input.vertex.x += input.vertex.x * body * bodyBeat * 0.052 * _LimbMotion;
                input.vertex.y += (input.vertex.y + 0.05) * body * bodyBeat * 0.060 * _LimbMotion;

                float tail = exp(-pow((input.uv.x - 0.67) / 0.20, 2.0))
                    * smoothstep(0.60, 0.84, input.uv.y);
                float tailSwing = sin(_ActionPhase * 4.2 + input.uv.y * 9.0);
                input.vertex.x += tail * tailSwing * 0.10 * _LimbMotion;
                input.vertex.y += tail * cos(_ActionPhase * 4.2 + input.uv.y * 7.0) * 0.032 * _LimbMotion;

                output.vertex = UnityObjectToClipPos(input.vertex);
                output.uv = TRANSFORM_TEX(input.uv, _MainTex);
                return output;
            }

            fixed4 frag(v2f input) : SV_Target
            {
                float2 uv = input.uv;
                float2 centered = uv * 2.0 - 1.0;
                float2 flow = float2(
                    sin(_Phase * 0.74 + centered.y * 9.0),
                    cos(_Phase * 0.61 - centered.x * 8.0))
                    * _Distortion * 0.035;
                fixed4 openTex = tex2D(_MainTex, uv + flow);
                fixed4 closedTex = tex2D(_ClosedTex, uv + flow);
                float mouthRegion = smoothstep(0.24, 0.29, uv.y)
                    * (1.0 - smoothstep(0.42, 0.50, uv.y))
                    * exp(-pow((uv.x - 0.50) / 0.16, 2.0));
                float closedBlend = (1.0 - saturate(_MouthOpen)) * mouthRegion;
                fixed4 texel = lerp(openTex, closedTex, closedBlend);
                float alpha = texel.a * _Color.a;

                float noise = valueNoise(uv * 17.0 + _Phase * 0.08);
                float tear = smoothstep(0.52, 0.84, noise);
                float dissolveMask = lerp(1.0, tear, saturate(_Dissolve));
                alpha *= dissolveMask;

                float edgeBand = smoothstep(0.04, 0.20, texel.a)
                    * (1.0 - smoothstep(0.28, 0.72, texel.a));
                float shimmer = 0.82 + 0.18 * sin(_Phase * 1.7 + uv.x * 31.0 + uv.y * 19.0);
                float textureLight = saturate(dot(texel.rgb, float3(0.22, 0.62, 0.16)) * 1.36);
                float spectralHeight = saturate(uv.y * 1.18 + 0.06 * sin(_Phase * 0.42 + uv.x * 8.0));
                float3 emberTint = float3(1.0, 0.13, 0.025);
                float3 wineTint = float3(0.86, 0.025, 0.24);
                float3 goldTint = float3(1.0, 0.58, 0.08);
                float3 spectralTint = lerp(
                    emberTint,
                    wineTint,
                    smoothstep(0.16, 0.64, spectralHeight));
                spectralTint = lerp(
                    spectralTint,
                    goldTint,
                    smoothstep(0.72, 1.0, spectralHeight));
                float colorPulse = 0.5 + 0.5 * sin(_Phase * 0.92 + uv.y * 24.0 - uv.x * 11.0 + noise * 4.0);
                float3 color = spectralTint * (0.34 + textureLight * 1.02) * _Color.rgb;
                color += spectralTint * (0.10 + colorPulse * 0.20) * _Glow;
                color = lerp(color, _EdgeColor.rgb, edgeBand * 0.72);
                color += _EdgeColor.rgb * edgeBand * (_Glow * 0.46) * shimmer;
                color *= 0.92 + noise * 0.16;
                return fixed4(color, alpha);
            }
            ENDCG
        }
    }
}
