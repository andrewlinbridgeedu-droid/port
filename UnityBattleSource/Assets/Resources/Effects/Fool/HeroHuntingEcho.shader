Shader "Mindstone/Fool/Hero Hunting Echo"
{
    Properties
    {
        _MainTex("Original costume", 2D) = "white" {}
        _Color("Original colour / fade", Color) = (1,1,1,1)
        _BumpMap("Original normal", 2D) = "bump" {}
        _BumpScale("Normal strength", Range(0,2)) = 1
        _HasNormal("Has normal", Float) = 0
        _RimColor("Spectral edge", Color) = (.65,.28,1,1)
        _RimStrength("Edge intensity", Range(0,3)) = 1.15
        _Glossiness("Costume gloss", Range(0,1)) = .35
    }
    SubShader
    {
        Tags { "Queue"="Transparent+16" "RenderType"="Transparent" }
        Blend SrcAlpha OneMinusSrcAlpha
        ZWrite Off
        Cull Back
        Pass
        {
            Tags { "LightMode"="ForwardBase" }
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma target 3.0
            #include "UnityCG.cginc"
            #include "Lighting.cginc"
            sampler2D _MainTex, _BumpMap;
            float4 _MainTex_ST, _BumpMap_ST, _Color, _RimColor;
            float _BumpScale, _HasNormal, _RimStrength, _Glossiness;
            struct Varyings {
                float4 position:SV_POSITION;
                float2 uv:TEXCOORD0;
                float2 normalUV:TEXCOORD1;
                float3 world:TEXCOORD2;
                half3 normal:TEXCOORD3;
                half3 tangent:TEXCOORD4;
                half3 bitangent:TEXCOORD5;
            };
            Varyings vert(appdata_tan v) {
                Varyings o;
                o.position=UnityObjectToClipPos(v.vertex);
                o.world=mul(unity_ObjectToWorld,v.vertex).xyz;
                o.uv=TRANSFORM_TEX(v.texcoord,_MainTex);
                o.normalUV=TRANSFORM_TEX(v.texcoord,_BumpMap);
                o.normal=UnityObjectToWorldNormal(v.normal);
                o.tangent=UnityObjectToWorldDir(v.tangent.xyz);
                o.bitangent=cross(o.normal,o.tangent)*v.tangent.w*unity_WorldTransformParams.w;
                return o;
            }
            fixed4 frag(Varyings i):SV_Target {
                half4 tex=tex2D(_MainTex,i.uv);
                half3 n=normalize(i.normal);
                half3 detail=UnpackNormal(tex2D(_BumpMap,i.normalUV));
                detail.xy*=_BumpScale;
                half3 mapped=normalize(i.tangent*detail.x+i.bitangent*detail.y+n*detail.z);
                n=normalize(lerp(n,mapped,saturate(_HasNormal)));
                half3 view=normalize(_WorldSpaceCameraPos-i.world);
                half3 light=normalize(UnityWorldSpaceLightDir(i.world));
                half facing=saturate(dot(n,view));
                half rim=pow(1-facing,3.6);
                // Preserve readable dark cloth, leather and skin; spectral colour
                // belongs to the silhouette, never a flat whole-body emission.
                half3 ambient=max(ShadeSH9(half4(n,1)),half3(.24,.25,.30));
                half diffuse=saturate(dot(n,light));
                half3 colour=tex.rgb*_Color.rgb*(ambient+_LightColor0.rgb*diffuse*.85);
                half spec=pow(saturate(dot(n,normalize(light+view))),lerp(16,64,_Glossiness));
                colour+=_LightColor0.rgb*spec*.13;
                colour+=_RimColor.rgb*rim*_RimStrength;
                return half4(colour,tex.a*_Color.a*lerp(.82,1,rim));
            }
            ENDCG
        }
    }
    Fallback Off
}
