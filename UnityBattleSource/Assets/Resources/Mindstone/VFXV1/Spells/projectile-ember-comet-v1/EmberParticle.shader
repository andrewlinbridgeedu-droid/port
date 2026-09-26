Shader "Mindstone/VFXV1/Ember Particle"
{
    Properties
    {
        _MainTex ("Particle Texture", 2D) = "white" {}
        _Tint ("Tint", Color) = (1, 0.25, 0.01, 1)
        _Intensity ("Intensity", Range(0, 8)) = 2
    }

    SubShader
    {
        Tags { "Queue"="Transparent" "RenderType"="Transparent" "IgnoreProjector"="True" }
        Cull Off
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
            float _Intensity;

            struct appdata
            {
                float4 vertex : POSITION;
                float4 color : COLOR;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float4 position : SV_POSITION;
                float4 color : COLOR;
                float2 uv : TEXCOORD0;
            };

            v2f vert(appdata input)
            {
                v2f output;
                output.position = UnityObjectToClipPos(input.vertex);
                output.color = input.color * _Tint;
                output.uv = TRANSFORM_TEX(input.uv, _MainTex);
                return output;
            }

            fixed4 frag(v2f input) : SV_Target
            {
                float2 particleCoord = input.uv * 2.0 - 1.0;
                float softCircle = saturate(1.0 - dot(particleCoord, particleCoord));
                fixed4 source = tex2D(_MainTex, input.uv);
                float alpha = source.a * input.color.a * softCircle;
                clip(alpha - 0.003);
                return fixed4(input.color.rgb * _Intensity, alpha);
            }
            ENDCG
        }
    }
    FallBack "Particles/Standard Unlit"
}
