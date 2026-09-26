Shader "Mindstone/VFXV1/Wraith Scream Mesh"
{
    Properties
    {
        _MainTex ("Meshy Base Color", 2D) = "white" {}
        _Tint ("Deep Violet Tint", Color) = (0.18, 0.055, 0.34, 1)
        _RimColor ("Spectral Rim", Color) = (0.42, 0.92, 1, 1)
        _Opacity ("Opacity", Range(0, 1)) = 1
        _Intensity ("Intensity", Range(0, 8)) = 1.5
        _Dissolve ("Dissolve", Range(0, 1)) = 0
        _Burst ("Burst", Range(0, 1)) = 0
        _Phase ("Phase", Float) = 0
        _RimPower ("Rim Power", Range(0.5, 6)) = 2.6
    }

    SubShader
    {
        Tags { "Queue"="Transparent+415" "RenderType"="Transparent" "IgnoreProjector"="True" }
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
            float4 _RimColor;
            float _Opacity;
            float _Intensity;
            float _Dissolve;
            float _Burst;
            float _Phase;
            float _RimPower;

            struct appdata
            {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float4 position : SV_POSITION;
                float2 uv : TEXCOORD0;
                float3 worldNormal : TEXCOORD1;
                float3 worldPosition : TEXCOORD2;
                float3 objectPosition : TEXCOORD3;
            };

            float hash31(float3 value)
            {
                value = frac(value * 0.1031);
                value += dot(value, value.yzx + 33.33);
                return frac((value.x + value.y) * value.z);
            }

            float noise3d(float3 value)
            {
                float3 cell = floor(value);
                float3 local = frac(value);
                local = local * local * (3.0 - 2.0 * local);
                float n000 = hash31(cell);
                float n100 = hash31(cell + float3(1, 0, 0));
                float n010 = hash31(cell + float3(0, 1, 0));
                float n110 = hash31(cell + float3(1, 1, 0));
                float n001 = hash31(cell + float3(0, 0, 1));
                float n101 = hash31(cell + float3(1, 0, 1));
                float n011 = hash31(cell + float3(0, 1, 1));
                float n111 = hash31(cell + float3(1, 1, 1));
                return lerp(
                    lerp(lerp(n000, n100, local.x),
                        lerp(n010, n110, local.x), local.y),
                    lerp(lerp(n001, n101, local.x),
                        lerp(n011, n111, local.x), local.y), local.z);
            }

            v2f vert(appdata input)
            {
                v2f output;
                float3 objectPosition = input.vertex.xyz;
                float noise = noise3d(objectPosition * 18.0
                    + _Phase * 0.23);
                float3 normal = normalize(input.normal);
                float3 burstDirection = normalize(objectPosition
                    + normal * 0.35
                    + float3(noise - 0.5, noise * 0.7 - 0.35,
                        0.45 - noise));
                objectPosition += normal * _Burst
                    * (0.035 + noise * 0.090);
                objectPosition += burstDirection * _Burst
                    * (0.020 + noise * 0.050);
                float4 world = mul(unity_ObjectToWorld,
                    float4(objectPosition, 1));
                output.position = UnityWorldToClipPos(world);
                output.uv = TRANSFORM_TEX(input.uv, _MainTex);
                output.worldNormal = UnityObjectToWorldNormal(normal);
                output.worldPosition = world.xyz;
                output.objectPosition = objectPosition;
                return output;
            }

            fixed4 frag(v2f input) : SV_Target
            {
                fixed4 source = tex2D(_MainTex, input.uv);
                float field = noise3d(input.objectPosition * 21.0
                    + float3(_Phase * 0.31, -_Phase * 0.19,
                        _Phase * 0.23));
                float dissolveEdge = smoothstep(0.24, 0.72,
                    1.0 - abs(field - _Dissolve));
                clip(field - _Dissolve + 0.04);

                float3 viewDirection = normalize(
                    _WorldSpaceCameraPos - input.worldPosition);
                float rim = pow(1.0 - saturate(dot(
                    normalize(input.worldNormal), viewDirection)),
                    _RimPower);
                float luminance = dot(source.rgb,
                    float3(0.30, 0.59, 0.11));
                float3 body = lerp(_Tint.rgb * 0.86,
                    max(source.rgb * 1.12, _Tint.rgb * 0.62),
                    saturate(luminance * 2.4 + 0.30));
                float3 color = body * (0.96 + _Burst * 0.32)
                    + _RimColor.rgb * (rim * 1.28
                        + dissolveEdge * _Burst * 0.82);
                float alpha = source.a * _Opacity
                    * (0.70 + rim * 0.70 + luminance * 0.28)
                    * (1.0 - _Dissolve * 0.18);
                return fixed4(color * _Intensity, alpha);
            }
            ENDCG
        }
    }
}
