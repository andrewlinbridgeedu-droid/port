Shader "Mistport/HeroBrocadeV2"
{
    Properties {
        _MainTex ("Tailored albedo", 2D) = "white" {}
        _Color ("Colour", Color) = (1,1,1,1)
        _Relief ("Thread relief", Range(0,1)) = .12
    }
    SubShader {
        Tags { "RenderType"="Opaque" }
        LOD 200
        Cull Off
        CGPROGRAM
        #pragma surface surf Standard fullforwardshadows
        #pragma target 3.0
        sampler2D _MainTex;
        fixed4 _Color;
        half _Relief;
        float4 _MainTex_TexelSize;
        struct Input { float2 uv_MainTex; };
        void surf(Input IN, inout SurfaceOutputStandard o) {
            fixed3 c = tex2D(_MainTex, IN.uv_MainTex).rgb * _Color.rgb;
            half thread = saturate((c.r - c.g - .055h) * 6.0h) * saturate((c.g - c.b) * 5.0h);
            o.Albedo = c;
            o.Metallic = lerp(.015h, .62h, thread);
            o.Smoothness = lerp(.27h, .64h, thread);
            float2 step = _MainTex_TexelSize.xy;
            half height = dot(c, half3(.3,.5,.2));
            half dx = dot(tex2D(_MainTex, IN.uv_MainTex + float2(step.x,0)).rgb, half3(.3,.5,.2)) - height;
            half dy = dot(tex2D(_MainTex, IN.uv_MainTex + float2(0,step.y)).rgb, half3(.3,.5,.2)) - height;
            o.Normal = normalize(half3(-dx * _Relief * 4, -dy * _Relief * 4, 1));
            o.Alpha = 1;
        }
        ENDCG
    }
    FallBack "Standard"
}
