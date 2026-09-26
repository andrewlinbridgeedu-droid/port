Shader "Mindstone/Mistport Front Sword Qi"
{
    Properties
    {
        _Color ("Sword Qi Color", Color) = (1,0.28,0.04,1)
        _EdgeColor ("Hot Edge", Color) = (1,0.86,0.34,1)
        _Phase ("Motion Phase", Float) = 0
        _Glow ("Glow", Range(0,4)) = 1
        _Alpha ("Alpha", Range(0,1)) = 1
    }

    SubShader
    {
        Tags
        {
            "Queue" = "Transparent+380"
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
            fixed4 _EdgeColor;
            float _Phase;
            float _Glow;
            float _Alpha;

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
                fixed4 color : COLOR;
            };

            struct v2f
            {
                float4 vertex : SV_POSITION;
                float2 uv : TEXCOORD0;
                fixed4 color : COLOR;
            };

            v2f vert(appdata input)
            {
                v2f output;
                float pulse = sin(_Phase * 1.7 + input.uv.y * 18.0) * 0.012;
                input.vertex.x += pulse * (0.35 + input.uv.y * 0.65);
                output.vertex = UnityObjectToClipPos(input.vertex);
                output.uv = input.uv;
                output.color = input.color * _Color;
                return output;
            }

            fixed4 frag(v2f input) : SV_Target
            {
                float edge = smoothstep(0.0, 0.22, input.uv.x)
                    * (1.0 - smoothstep(0.78, 1.0, input.uv.x));
                float bladeHeight = smoothstep(0.04, 0.20, input.uv.y)
                    * (1.0 - smoothstep(0.82, 1.0, input.uv.y));
                float shimmer = 0.84 + 0.16 * sin(
                    _Phase * 5.0 + input.uv.y * 31.0 - input.uv.x * 17.0);
                float3 color = input.color.rgb * shimmer;
                color = lerp(color, _EdgeColor.rgb, edge * 0.66);
                color += _EdgeColor.rgb * (0.12 + edge * 0.32) * _Glow;
                color += float3(1.0, 0.78, 0.36) * bladeHeight * 0.10 * _Glow;
                float alpha = input.color.a * _Alpha;
                return fixed4(color, alpha);
            }
            ENDCG
        }
    }
}
