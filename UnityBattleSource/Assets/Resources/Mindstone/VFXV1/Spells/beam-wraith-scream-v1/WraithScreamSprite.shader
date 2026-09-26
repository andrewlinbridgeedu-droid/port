Shader "Mindstone/VFXV1/Wraith Scream Sprite"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _Tint ("Tint", Color) = (0.48, 0.08, 1, 1)
        _Opacity ("Opacity", Range(0, 1)) = 1
        _Intensity ("Intensity", Range(0, 8)) = 2
        _CropHead ("Crop Wraith Head", Range(0, 1)) = 0
        _SoftParticle ("Soft Particle Mask", Range(0, 1)) = 0
        _PreserveSourceColor ("Preserve Source Color", Range(0, 1)) = 0
        _Phase ("Phase", Float) = 0
    }

    SubShader
    {
        Tags { "Queue"="Transparent+450" "RenderType"="Transparent" "IgnoreProjector"="True" }
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
            float4 _Tint;
            float _Opacity;
            float _Intensity;
            float _CropHead;
            float _SoftParticle;
            float _PreserveSourceColor;
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
                output.uv = TRANSFORM_TEX(input.uv, _MainTex);
                output.color = input.color;
                return output;
            }

            fixed4 frag(v2f input) : SV_Target
            {
                float2 headUV = float2(
                    lerp(0.57, 1.0, input.uv.x),
                    lerp(0.12, 0.80, input.uv.y));
                float2 sampleUV = lerp(input.uv, headUV, _CropHead);
                fixed4 source = tex2D(_MainTex, sampleUV);
                float pulse = 0.88 + 0.12 * sin(_Phase * 7.0
                    + input.uv.y * 11.0);
                float alpha = source.a * _Tint.a * input.color.a
                    * _Opacity * pulse;
                float2 centeredUV = input.uv * 2.0 - 1.0;
                float radial = saturate(1.0 - dot(centeredUV, centeredUV));
                float softMask = smoothstep(0.0, 0.72, radial);
                alpha *= lerp(1.0, softMask, _SoftParticle);
                clip(alpha - 0.006);
                float luminance = dot(source.rgb, float3(0.30, 0.59, 0.11));
                float3 spectral = lerp(_Tint.rgb * 0.42, _Tint.rgb,
                    saturate(luminance * 1.8 + 0.20));
                spectral = lerp(spectral, source.rgb,
                    _PreserveSourceColor);
                return fixed4(
                    spectral * input.color.rgb * _Intensity,
                    alpha);
            }
            ENDCG
        }
    }
}
