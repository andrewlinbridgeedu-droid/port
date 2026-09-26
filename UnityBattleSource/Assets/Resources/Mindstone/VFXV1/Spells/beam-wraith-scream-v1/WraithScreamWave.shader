Shader "Mindstone/VFXV1/Wraith Scream Wave"
{
    Properties
    {
        _MainTex ("Effekseer Pressure Texture", 2D) = "white" {}
        _FlowTex ("Effekseer Aurora Flow", 2D) = "gray" {}
        _FilamentTex ("Effekseer Dark Rift Filament", 2D) = "white" {}
        _Opacity ("Opacity", Range(0, 1)) = 1
        _Intensity ("Intensity", Range(0, 8)) = 1.6
        _Phase ("Phase", Float) = 0
    }

    SubShader
    {
        Tags { "Queue"="Transparent+580" "RenderType"="Transparent" "IgnoreProjector"="True" }
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
            sampler2D _FlowTex;
            sampler2D _FilamentTex;
            float _Opacity;
            float _Intensity;
            float _Phase;

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

            v2f vert(appdata input)
            {
                v2f output;
                output.position = UnityObjectToClipPos(input.vertex);
                output.uv = input.uv;
                output.color = input.color;
                return output;
            }

            fixed4 frag(v2f input) : SV_Target
            {
                float across = abs(input.uv.y * 2.0 - 1.0);
                float softCore = pow(saturate(1.0 - across), 0.78);
                float softGlow = pow(saturate(1.0 - across), 2.6);
                float2 pressureUV = float2(
                    frac(input.uv.x * 2.35 + _Phase * 0.045),
                    across);
                float3 pressureRGB = tex2D(_MainTex, pressureUV).rgb;
                float pressure = dot(pressureRGB,
                    float3(0.30, 0.59, 0.11));
                float flowWarp = sin(input.uv.x * 13.0
                    - _Phase * 2.7) * 0.055
                    + sin(input.uv.x * 31.0 + _Phase * 4.1) * 0.018;
                float2 flowUV = float2(
                    frac(input.uv.x * 1.38 - _Phase * 0.032),
                    frac(input.uv.y * 1.72 + flowWarp));
                float3 flowRGB = tex2D(_FlowTex, flowUV).rgb;
                float flow = dot(flowRGB, float3(0.30, 0.59, 0.11));
                float2 filamentUV = float2(
                    saturate(input.uv.y),
                    frac(input.uv.x * 3.7 - _Phase * 0.075));
                float3 filamentRGB = tex2D(_FilamentTex, filamentUV).rgb;
                float filament = dot(filamentRGB,
                    float3(0.30, 0.59, 0.11));
                float cap = smoothstep(0.0, 0.055, input.uv.x)
                    * (1.0 - smoothstep(0.945, 1.0, input.uv.x));
                float ripple = 0.78
                    + 0.15 * sin(input.uv.x * 34.0 + _Phase * 4.8)
                    + 0.07 * sin(input.uv.x * 79.0 - _Phase * 7.1);
                float torn = smoothstep(0.13, 0.42,
                    0.5 + 0.5 * sin(input.uv.x * 53.0
                        + sin(input.uv.x * 17.0 + _Phase) * 1.8
                        - _Phase * 5.6));
                float microFracture = smoothstep(0.30, 0.70,
                    0.5 + 0.5 * sin(input.uv.x * 97.0
                        + sin(input.uv.x * 29.0 - _Phase * 2.3) * 2.1
                        + input.uv.y * 8.0));
                float density = saturate(pressure * 0.46
                    + flow * 0.36 + filament * 0.34);
                float alpha = input.color.a * cap
                    * (softCore * (0.14 + density * 0.72
                        + torn * 0.18) + softGlow * 0.24)
                    * saturate(ripple)
                    * lerp(0.74, 1.0, microFracture) * _Opacity;
                clip(alpha - 0.004);
                float spectralPhase = 0.5 + 0.5 * sin(
                    input.uv.x * 21.0 - _Phase * 4.2
                    + input.uv.y * 5.0);
                float3 spectralAccent = lerp(
                    float3(0.12, 0.92, 1.0),
                    float3(1.0, 0.10, 0.92),
                    spectralPhase);
                float3 color = lerp(input.color.rgb, spectralAccent,
                        saturate(filament * 0.18 + torn * 0.08))
                    * (0.56 + pressure * 0.32 + flow * 0.28
                        + filament * 0.46 + softGlow * 0.92
                        + torn * 0.12)
                    * _Intensity;
                return fixed4(color, alpha);
            }
            ENDCG
        }
    }
}
