Shader "Mindstone/Mistport Front Ribbon"
{
    Properties
    {
        _Color ("Color", Color) = (1,1,1,1)
    }

    SubShader
    {
        Tags
        {
            "Queue" = "Transparent+150"
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

            struct appdata
            {
                float4 vertex : POSITION;
                fixed4 color : COLOR;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float4 vertex : SV_POSITION;
                fixed4 color : COLOR;
                float2 uv : TEXCOORD0;
            };

            v2f vert(appdata input)
            {
                v2f output;
                output.vertex = UnityObjectToClipPos(input.vertex);
                output.color = input.color * _Color;
                output.uv = input.uv;
                return output;
            }

            fixed4 frag(v2f input) : SV_Target
            {
                // Rounded, torn ends keep the front layer reading as energy
                // ribbons instead of rectangular bars.
                float endFade = smoothstep(0.0, 0.12, input.uv.x)
                    * smoothstep(1.0, 0.84, input.uv.x);
                float irregular = 0.92
                    + 0.08 * sin(input.uv.x * 31.0 + input.uv.y * 8.0);
                return fixed4(input.color.rgb, input.color.a * endFade * irregular);
            }
            ENDCG
        }
    }
}
