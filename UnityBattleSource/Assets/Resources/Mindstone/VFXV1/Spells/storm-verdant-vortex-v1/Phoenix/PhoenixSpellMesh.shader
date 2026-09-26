Shader "Mindstone/VFXV1/Phoenix Spell Mesh"
{
    Properties
    {
        _MainTex ("Base Color", 2D) = "white" {}
        _NormalMap ("Normal", 2D) = "bump" {}
        _MetallicTex ("Metallic", 2D) = "black" {}
        _RoughnessTex ("Roughness", 2D) = "gray" {}
        _BaseTint ("Base Tint", Color) = (1, 0.38, 0.05, 1)
        _DeepColor ("Deep Fire", Color) = (0.15, 0.008, 0.001, 1)
        _GoldColor ("Phoenix Gold", Color) = (1, 0.28, 0.015, 1)
        _HotColor ("Hot Core", Color) = (1, 0.95, 0.48, 1)
        _RimColor ("Rim", Color) = (1, 0.54, 0.06, 1)
        _Opacity ("Opacity", Range(0, 1)) = 1
        _EmissionBoost ("Emission", Range(0, 5)) = 1.8
        _RimPower ("Rim Power", Range(0.5, 8)) = 2.4
        _Phase ("Animation Phase", Float) = 0
        _WingFlap ("Wing Flap", Float) = 0.1
        _WingSpread ("Wing Spread", Float) = 0.04
        _MeshScale ("Imported Mesh Scale", Float) = 100
        _Explode ("Phoenix Fragment Burst", Range(0, 1)) = 0
        _ExplosionSize ("Fragment Travel", Float) = 1
        _ExplosionSeed ("Fragment Seed", Float) = 0
    }

    SubShader
    {
        Tags
        {
            "Queue" = "Transparent"
            "RenderType" = "Transparent"
            "IgnoreProjector" = "True"
        }
        LOD 300
        Cull Off
        ZWrite Off
        Blend SrcAlpha OneMinusSrcAlpha

        Pass
        {
            CGPROGRAM
            #pragma target 3.0
            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile_fog
            #include "UnityCG.cginc"

            sampler2D _MainTex;
            sampler2D _NormalMap;
            sampler2D _MetallicTex;
            sampler2D _RoughnessTex;
            float4 _MainTex_ST;
            float4 _BaseTint;
            float4 _DeepColor;
            float4 _GoldColor;
            float4 _HotColor;
            float4 _RimColor;
            float _Opacity;
            float _EmissionBoost;
            float _RimPower;
            float _Phase;
            float _WingFlap;
            float _WingSpread;
            float _MeshScale;
            float _Explode;
            float _ExplosionSize;
            float _ExplosionSeed;

            struct appdata
            {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
                float4 tangent : TANGENT;
                float2 uv : TEXCOORD0;
                float4 color : COLOR;
            };

            struct v2f
            {
                float4 position : SV_POSITION;
                float2 uv : TEXCOORD0;
                float3 worldPosition : TEXCOORD1;
                float3 worldNormal : TEXCOORD2;
                float4 worldTangent : TEXCOORD3;
                float4 color : COLOR;
                UNITY_FOG_COORDS(4)
                float fragmentSeed : TEXCOORD5;
            };

            float hash13(float3 value)
            {
                return frac(sin(dot(value, float3(12.9898, 78.233, 37.719)))
                    * 43758.5453);
            }

            float3 hash33(float3 value)
            {
                return float3(
                    hash13(value + float3(17.0, 3.0, 11.0)),
                    hash13(value + float3(41.0, 19.0, 7.0)),
                    hash13(value + float3(5.0, 29.0, 47.0)));
            }

            v2f vert(appdata input)
            {
                v2f output;

                // Meshy imports this asset with a large root scale and very
                // small source vertices. Convert into the model's authored
                // local units before applying wing motion, then convert back
                // so the deformation remains stable after fitting the model.
                float safeScale = max(_MeshScale, 0.0001);
                float3 authored = input.vertex.xyz * safeScale;
                float wingSide = authored.x < 0.0 ? -1.0 : 1.0;
                float span = abs(authored.x);
                float wingMask = smoothstep(0.16, 0.32, span)
                    * smoothstep(-0.18, 0.22, authored.y)
                    * (1.0 - smoothstep(0.70, 1.15, span));
                float beat = sin(_Phase + span * 2.8 + wingSide * 0.55);
                float wingAmplitude = _WingFlap * wingMask * (0.55 + span * 0.55);

                // This is a lightweight engine-side wing rig. It keeps the
                // body, crest, beak and tail coherent while the lateral wing
                // vertices lift, fold and spread as a single continuous mesh.
                authored.z += beat * wingAmplitude;
                authored.y += cos(_Phase + span * 2.1) * wingAmplitude * 0.25;
                authored.x += wingSide * _WingSpread * wingMask *
                    (0.30 + saturate(span));

                float3 deformed = authored / safeScale;

                // At contact the complete mesh is still present. Over the
                // next few frames each duplicated face vertex receives a
                // deterministic outward impulse, so the same Phoenix mesh
                // visibly tears from one coherent silhouette into scattered
                // fire fragments instead of disappearing and being replaced
                // by unrelated particles.
                float fragmentSeed = hash13(
                    authored + float3(input.uv, _ExplosionSeed));
                float3 randomVector = hash33(
                    authored + float3(input.uv * 7.0, _ExplosionSeed));
                float3 radial = normalize(
                    authored + input.normal * 0.42
                    + (randomVector - 0.5) * 0.34);
                float3 tangent = normalize(
                    cross(radial, float3(0.37, 0.82, 0.19)));
                if (dot(tangent, tangent) < 0.001)
                    tangent = float3(1.0, 0.0, 0.0);
                float burst = smoothstep(0.0, 1.0, saturate(_Explode));
                float impulse = burst * burst
                    * _ExplosionSize * (0.08 + fragmentSeed * 0.82);
                float flutter = sin(
                    _Phase * (2.2 + fragmentSeed * 1.8)
                    + fragmentSeed * 31.0);
                authored += radial * impulse;
                authored += tangent * flutter
                    * _ExplosionSize * burst * (0.035 + randomVector.z * 0.12);
                authored += input.normal * _ExplosionSize * burst
                    * (randomVector.x - 0.5) * 0.10;
                deformed = authored / safeScale;
                output.position = UnityObjectToClipPos(float4(deformed, 1.0));
                output.uv = TRANSFORM_TEX(input.uv, _MainTex);
                output.worldPosition = mul(unity_ObjectToWorld, float4(deformed, 1.0)).xyz;
                output.worldNormal = UnityObjectToWorldNormal(input.normal);
                output.worldTangent = float4(
                    UnityObjectToWorldDir(input.tangent.xyz),
                    input.tangent.w * unity_WorldTransformParams.w);
                output.color = input.color;
                output.fragmentSeed = fragmentSeed;
                UNITY_TRANSFER_FOG(output, output.position);
                return output;
            }

            fixed4 frag(v2f input, fixed facing : VFACE) : SV_Target
            {
                fixed4 source = tex2D(_MainTex, input.uv);
                float3 normal = normalize(input.worldNormal);
                if (facing < 0.0)
                    normal = -normal;
                float3 tangent = normalize(
                    input.worldTangent.xyz - normal
                    * dot(input.worldTangent.xyz, normal));
                float3 bitangent = normalize(
                    cross(normal, tangent) * input.worldTangent.w);
                float3 mappedNormal = UnpackNormal(tex2D(_NormalMap, input.uv));
                normal = normalize(mappedNormal.x * tangent
                    + mappedNormal.y * bitangent
                    + mappedNormal.z * normal);
                float3 viewDirection = normalize(_WorldSpaceCameraPos - input.worldPosition);
                float fresnel = pow(1.0 - saturate(dot(normal, viewDirection)), _RimPower);

                // Keep the supplied texture's feather detail, but move its
                // orange base toward the requested gold/red phoenix palette.
                float3 tintedSource = saturate(
                    source.rgb * lerp(float3(1.0, 1.0, 1.0), _BaseTint.rgb, 0.28));
                float luminance = saturate(dot(tintedSource, float3(0.30, 0.59, 0.11)));
                float featherBand = saturate(luminance * 1.35 + source.r * 0.20);
                float3 fire = lerp(_DeepColor.rgb, _GoldColor.rgb, featherBand);
                fire = lerp(fire, _HotColor.rgb, pow(featherBand, 3.0) * 0.24);
                fire *= lerp(0.80, 1.10, tintedSource.g);

                float metal = tex2D(_MetallicTex, input.uv).r;
                float roughness = tex2D(_RoughnessTex, input.uv).r;
                float highlight = lerp(0.90, 1.25, metal)
                    * lerp(1.10, 0.82, roughness);
                float flow = 0.92 + 0.10 * sin(_Phase * 0.80 + input.uv.y * 18.0);
                float3 emission = fire * _EmissionBoost * highlight * flow;
                emission += _RimColor.rgb * fresnel * 1.65;
                emission += _HotColor.rgb * pow(fresnel, 3.0) * 0.28;

                float breakup = saturate(_Explode);
                float holeAmount = smoothstep(0.28, 0.94, breakup);
                float fragmentKeep = step(holeAmount * 0.96,
                    input.fragmentSeed);
                float alpha = saturate(source.a * _Opacity * input.color.a);
                alpha *= lerp(1.0, fragmentKeep, holeAmount);
                float3 finalColor = emission + fire * 0.18;
                fixed4 output = fixed4(finalColor, alpha);
                UNITY_APPLY_FOG(input.fogCoord, output);
                return output;
            }
            ENDCG
        }
    }
    FallBack "Transparent/VertexLit"
}
