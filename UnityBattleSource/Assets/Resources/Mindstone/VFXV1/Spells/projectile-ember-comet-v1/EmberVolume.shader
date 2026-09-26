Shader "Mindstone/VFXV1/Ember Volume"
{
    Properties
    {
        _DeepColor ("Deep Ember", Color) = (0.10, 0.005, 0.001, 1)
        _MidColor ("Mid Flame", Color) = (0.85, 0.06, 0.005, 1)
        _HotColor ("Hot Core", Color) = (1, 0.72, 0.05, 1)
        _EdgeColor ("Edge Glow", Color) = (1, 0.16, 0.005, 1)
        _Opacity ("Opacity", Range(0, 1)) = 1
        _Intensity ("Intensity", Range(0, 8)) = 2
        _Phase ("Phase", Float) = 0
        _NoiseScale ("Noise Scale", Float) = 2.8
        _Dissolve ("Dissolve", Range(0, 1)) = 0
        _Burst ("Burst", Range(0, 1)) = 0
    }

    SubShader
    {
        Tags { "Queue"="Transparent" "RenderType"="Transparent" "IgnoreProjector"="True" }
        Cull Off
        ZWrite Off
        Blend One OneMinusSrcAlpha

        Pass
        {
            CGPROGRAM
            #pragma target 3.0
            #pragma vertex vert
            #pragma fragment frag
            #include "UnityCG.cginc"

            float4 _DeepColor;
            float4 _MidColor;
            float4 _HotColor;
            float4 _EdgeColor;
            float _Opacity;
            float _Intensity;
            float _Phase;
            float _NoiseScale;
            float _Dissolve;
            float _Burst;

            struct appdata
            {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
            };

            struct v2f
            {
                float4 position : SV_POSITION;
                float3 localPosition : TEXCOORD0;
                float3 worldPosition : TEXCOORD1;
                float3 worldNormal : TEXCOORD2;
            };

            float hash13(float3 p)
            {
                return frac(sin(dot(p, float3(12.9898, 78.233, 37.719)))
                    * 43758.5453);
            }

            float noise3(float3 p)
            {
                float3 cell = floor(p);
                float3 f = frac(p);
                f = f * f * (3.0 - 2.0 * f);
                float n000 = hash13(cell + float3(0, 0, 0));
                float n100 = hash13(cell + float3(1, 0, 0));
                float n010 = hash13(cell + float3(0, 1, 0));
                float n110 = hash13(cell + float3(1, 1, 0));
                float n001 = hash13(cell + float3(0, 0, 1));
                float n101 = hash13(cell + float3(1, 0, 1));
                float n011 = hash13(cell + float3(0, 1, 1));
                float n111 = hash13(cell + float3(1, 1, 1));
                float x00 = lerp(n000, n100, f.x);
                float x10 = lerp(n010, n110, f.x);
                float x01 = lerp(n001, n101, f.x);
                float x11 = lerp(n011, n111, f.x);
                return lerp(lerp(x00, x10, f.y), lerp(x01, x11, f.y), f.z);
            }

            float fbm(float3 p)
            {
                float value = 0.0;
                float amplitude = 0.55;
                for (int index = 0; index < 4; index++)
                {
                    value += noise3(p) * amplitude;
                    p = p * 2.03 + float3(7.1, 3.7, 5.3);
                    amplitude *= 0.48;
                }
                return saturate(value);
            }

            v2f vert(appdata input)
            {
                v2f output;
                output.position = UnityObjectToClipPos(input.vertex);
                output.localPosition = input.vertex.xyz;
                output.worldPosition = mul(unity_ObjectToWorld, input.vertex).xyz;
                output.worldNormal = UnityObjectToWorldNormal(input.normal);
                return output;
            }

            fixed4 frag(v2f input, fixed facing : VFACE) : SV_Target
            {
                float3 normal = normalize(input.worldNormal);
                if (facing < 0.0)
                    normal = -normal;
                float3 viewDirection = normalize(
                    _WorldSpaceCameraPos - input.worldPosition);
                float fresnel = pow(
                    1.0 - saturate(dot(normal, viewDirection)), 2.1);
                float3 flowPoint = input.localPosition * _NoiseScale
                    + float3(0.0, _Phase * 0.30, -_Phase * 0.17);
                float noise = fbm(flowPoint);
                float tongue = fbm(flowPoint * float3(1.0, 1.7, 1.0)
                    + float3(0.0, _Phase * 0.42, 2.7));
                float flame = saturate(noise * 0.72 + tongue * 0.54
                    + fresnel * 0.35);
                float breakup = saturate(_Dissolve + _Burst * 0.66);
                clip(flame + fresnel * 0.50 - breakup * 0.72 - 0.08);

                float hot = saturate(flame * 1.35 + (1.0 - fresnel) * 0.24);
                float3 color = lerp(_DeepColor.rgb, _MidColor.rgb, hot * 0.72);
                color = lerp(color, _HotColor.rgb,
                    saturate(pow(hot, 2.5) * 0.88));
                color += _EdgeColor.rgb * fresnel * 0.82;
                float alpha = saturate(_Opacity * (0.18 + flame * 0.78
                    + fresnel * 0.34));
                return fixed4(color * _Intensity, alpha);
            }
            ENDCG
        }
    }
    FallBack "Transparent/VertexLit"
}
