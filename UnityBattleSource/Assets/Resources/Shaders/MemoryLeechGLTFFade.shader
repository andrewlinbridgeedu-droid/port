Shader "Mindstone/Memory Leech GLTF Fade" {
    Properties {
        _Color ("Fade Tint", Color) = (1,1,1,1)
        _MainTex ("Base Color", 2D) = "white" {}
        _MetallicRoughness ("Metallic B Roughness G", 2D) = "white" {}
        _BumpMap ("Normal", 2D) = "bump" {}
    }
    SubShader {
        Tags { "RenderType"="Transparent" "Queue"="Transparent" }
        Cull Off
        CGPROGRAM
        #pragma surface surf Standard fullforwardshadows alpha:fade
        #pragma target 3.0
        fixed4 _Color;
        sampler2D _MainTex, _MetallicRoughness, _BumpMap;
        struct Input { float2 uv_MainTex; };
        void surf(Input IN, inout SurfaceOutputStandard o) {
            fixed4 color = tex2D(_MainTex, IN.uv_MainTex);
            fixed4 mr = tex2D(_MetallicRoughness, IN.uv_MainTex);
            o.Albedo = color.rgb;
            o.Metallic = mr.b;
            o.Smoothness = 1 - mr.g;
            o.Normal = UnpackNormal(tex2D(_BumpMap, IN.uv_MainTex));
            o.Alpha = _Color.a;
        }
        ENDCG
    }
    FallBack "Diffuse"
}
