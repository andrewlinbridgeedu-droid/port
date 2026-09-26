Shader "Mindstone/Mistport Wild Ribbon"
{
    Properties
    {
        _Color ("Body Color", Color) = (0.2,0.8,0.3,1)
        _EdgeColor ("Edge Color", Color) = (0.9,1,0.8,1)
        _Phase ("Flow Phase", Float) = 0
        _Glow ("Glow", Range(0,2)) = 1
    }

    SubShader
    {
        Tags
        {
            "Queue" = "Transparent+250"
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
                output.color = input.color;
                output.uv = input.uv;
                return output;
            }

            fixed4 frag(v2f input) : SV_Target
            {
                float along = input.uv.x;
                float across = abs(input.uv.y * 2.0 - 1.0);
                float edge = 1.0 - smoothstep(0.48, 0.98, across);
                float endFade = smoothstep(0.0, 0.08, along)
                    * smoothstep(1.0, 0.84, along);
                float flow = 0.90
                    + 0.10 * sin(along * 16.0 + _Phase)
                    + 0.035 * sin(along * 43.0 - _Phase * 1.7);
                float edgeLight = smoothstep(0.16, 0.92, across);
                float3 color = lerp(_Color.rgb, _EdgeColor.rgb, edgeLight * 0.82);
                color *= (0.92 + edgeLight * 0.22) * _Glow;
                float alpha = _Color.a * input.color.a * edge * endFade * flow;
                return fixed4(color, alpha);
            }
            ENDCG
        }
    }
}
