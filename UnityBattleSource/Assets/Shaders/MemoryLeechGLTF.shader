Shader "Mindstone/Memory Leech GLTF" {
    Properties {
        _MainTex ("Base Color", 2D) = "white" {}
        _MetallicRoughness ("Metallic B Roughness G", 2D) = "white" {}
        _BumpMap ("Normal", 2D) = "bump" {}
    }
    SubShader {
        Tags { "RenderType"="Opaque" }
        Cull Off
        CGPROGRAM
        #pragma surface surf Standard fullforwardshadows
        #pragma target 3.0
        sampler2D _MainTex, _MetallicRoughness, _BumpMap;
        struct Input { float2 uv_MainTex; };
        void surf(Input IN, inout SurfaceOutputStandard o) {
            fixed4 color = tex2D(_MainTex, IN.uv_MainTex);
            fixed4 mr = tex2D(_MetallicRoughness, IN.uv_MainTex);
            o.Albedo = color.rgb;
            o.Metallic = mr.b;
            o.Smoothness = 1 - mr.g;
            o.Normal = UnpackNormal(tex2D(_BumpMap, IN.uv_MainTex));
            o.Alpha = 1;
        }
        ENDCG
    }
    FallBack "Diffuse"
}
