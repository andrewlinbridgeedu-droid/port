Shader "Mindstone/Mistport Reference Flow Sprite"
{
    Properties
    {
        [PerRendererData] _MainTex ("Reference Shape", 2D) = "black" {}
        [PerRendererData] _NoiseTex ("Flow Noise", 2D) = "gray" {}
        _Color ("Tint", Color) = (1,1,1,1)
        _Phase ("Flow Phase", Float) = 0
        _Distortion ("Shape Distortion", Range(0, 0.25)) = 0.055
        _NoiseBreakup ("Edge Breakup", Range(0, 1)) = 0.32
        _LumaMask ("Use Luminance Mask", Range(0, 1)) = 1
        _Envelope ("Organic Envelope", Range(0, 1)) = 0
        _ColorFloor ("Lift Dark Fringe", Range(0, 1)) = 0
    }

    SubShader
    {
        Tags
        {
            "Queue" = "Transparent+360"
            "RenderType" = "Transparent"
            "IgnoreProjector" = "True"
        }
        Cull Off
        Lighting Off
        ZWrite Off
        // Reference effects are a deliberate front-facing presentation
        // layer. The actor remains rendered; this pass owns the pixels at
        // the impact peak so the spell has visual weight.
        ZTest Always
        Blend SrcAlpha OneMinusSrcAlpha

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "UnityCG.cginc"

            sampler2D _MainTex;
            sampler2D _NoiseTex;
            float4 _MainTex_ST;
            float4 _NoiseTex_ST;
            fixed4 _Color;
            float _Phase;
            float _Distortion;
            float _NoiseBreakup;
            float _LumaMask;
            float _Envelope;
            float _ColorFloor;

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
                output.uv = TRANSFORM_TEX(input.uv, _MainTex);
                return output;
            }

            fixed4 frag(v2f input) : SV_Target
            {
                float2 uv = input.uv;
                float2 flow = float2(_Phase * 0.047, -_Phase * 0.031);
                float2 noiseUv = uv * 1.35 + flow;
                float2 noiseUv2 = uv * 2.70 - flow * 1.37 + float2(0.17, 0.41);
                float2 noiseA = tex2D(_NoiseTex, noiseUv).rg;
                float2 noiseB = tex2D(_NoiseTex, noiseUv2).rg;
                float2 warp = (noiseA - 0.5) * _Distortion
                    + (noiseB - 0.5) * (_Distortion * 0.38);
                // Keep the center coherent. The outer silhouette is where
                // the flow field tears the authored shape into living flame
                // or wind instead of a rigid billboard.
                float radial = length(uv * 2.0 - 1.0);
                float edgeWeight = smoothstep(0.18, 1.02, radial);
                uv += warp * edgeWeight;

                fixed4 texel = tex2D(_MainTex, uv);
                float luminance = max(texel.r, max(texel.g, texel.b));
                float sourceMask = lerp(texel.a, luminance, _LumaMask);
                float2 envelopeUv = input.uv * 2.0 - 1.0;
                float envelopeRadius = length(envelopeUv);
                float organicEnvelope = 1.0 - smoothstep(0.72, 1.04, envelopeRadius);
                sourceMask *= lerp(1.0, organicEnvelope, _Envelope);
                float flowValue = saturate(noiseA.r * 0.68 + noiseB.g * 0.32);
                float breakup = lerp(1.0, 0.52 + flowValue * 0.92, _NoiseBreakup);
                // Never hollow out the hot center. Breakup is concentrated
                // on the edge so the effect can still cover the actor.
                breakup = lerp(1.0, breakup, edgeWeight);
                float alpha = saturate(sourceMask * breakup * _Color.a);
                float3 color = texel.rgb * _Color.rgb;
                // Chroma-keyed hand-painted sprites can retain dark RGB in
                // translucent edge pixels. This opt-in lift prevents a black
                // halo without changing the approved fire/sword materials,
                // whose _ColorFloor remains zero.
                float darkWeight = (1.0 - smoothstep(0.12, 0.42, luminance)) * _ColorFloor;
                color = lerp(color, _Color.rgb * 0.78, darkWeight);
                return fixed4(color, alpha);
            }
            ENDCG
        }
    }
}
