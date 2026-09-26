Shader "Mindstone/Mistport Front Organic Sprite"
{
    Properties
    {
        [PerRendererData] _MainTex ("Texture", 2D) = "white" {}
        _Color ("Color", Color) = (1,1,1,1)
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
        // The front veil is a dense but readable smoke/flame layer. The
        // authored additive ribbons remain separate for the hard highlights;
        // this pass keeps the protagonist underneath without blowing the
        // whole frame to white.
        Blend SrcAlpha OneMinusSrcAlpha

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "UnityCG.cginc"

            sampler2D _MainTex;
            float4 _MainTex_ST;
            fixed4 _Color;

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
                fixed4 texel = tex2D(_MainTex, input.uv);
                // These Effekseer source textures are authored on black. The
                // additive runtime material hides that black; this front
                // pass converts its luminance into alpha so the same art
                // becomes soft smoke, flame, or energy instead of a square.
                float luminance = max(texel.r, max(texel.g, texel.b));
                float softDensity = smoothstep(0.018, 0.22, luminance);
                softDensity *= saturate(luminance * 1.35);
                return fixed4(texel.rgb * _Color.rgb, softDensity * _Color.a);
            }
            ENDCG
        }
    }
}
