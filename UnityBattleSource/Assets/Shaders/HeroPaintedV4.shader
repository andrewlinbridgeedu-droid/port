Shader "Mistport/HeroPaintedV4"
{
    // Thick-paint anime shading for the v4 hero, matching the Blender preview
    // (tools/animation/hero_v4/looks.py): a smooth light-to-shadow ramp with a
    // coloured shadow, baked crease shading (vertex colour), a thresholded
    // highlight that is soft on cloth and crisp on leather and gold, a soft rim
    // and a thin coloured outline. The key light follows the camera so the
    // hero reads the same in every arena.
    Properties {
        _MainTex ("Painted colour", 2D) = "white" {}
        _Color ("Colour", Color) = (1,1,1,1)
        _ShadeColor ("Shadow tint", Color) = (0.6,0.52,0.76,1)
        _HighlightColor ("Highlight", Color) = (1,0.96,0.9,1)
        _HighlightStrength ("Highlight strength", Range(0,1.5)) = 0.1
        _HighlightFrom ("Highlight from", Range(0,1)) = 0.6
        _HighlightTo ("Highlight to", Range(0,1)) = 0.95
        _Gloss ("Glossiness", Range(2,256)) = 16
        _Rim ("Rim", Range(0,1)) = 0.16
        _AO ("Crease shading", Range(0,1)) = 0.75
        _ViewLight ("Key light (view space)", Vector) = (-0.35,0.55,0.75,0)
        _OutlineColor ("Outline", Color) = (0.11,0.08,0.13,1)
        _OutlineWidth ("Outline width (m)", Range(0,0.01)) = 0.0012
    }
    SubShader {
        Tags { "RenderType"="Opaque" "Queue"="Geometry" }
        Pass {
            Tags { "LightMode"="ForwardBase" }
            Cull Back
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile_fog
            #include "UnityCG.cginc"
            sampler2D _MainTex;
            float4 _MainTex_ST;
            fixed4 _Color, _ShadeColor, _HighlightColor;
            half _HighlightStrength, _HighlightFrom, _HighlightTo, _Gloss, _Rim, _AO;
            float4 _ViewLight;
            struct appdata { float4 vertex:POSITION; float3 normal:NORMAL; float2 uv:TEXCOORD0; fixed4 color:COLOR; };
            struct v2f {
                float4 pos:SV_POSITION;
                float2 uv:TEXCOORD0;
                float3 worldNormal:TEXCOORD1;
                float3 worldPos:TEXCOORD2;
                fixed ao:TEXCOORD3;
                UNITY_FOG_COORDS(4)
            };
            v2f vert(appdata v) {
                v2f o;
                o.pos = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                o.worldNormal = UnityObjectToWorldNormal(v.normal);
                o.worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;
                o.ao = v.color.r;
                UNITY_TRANSFER_FOG(o, o.pos);
                return o;
            }
            half3 Ramp(half value) {
                half3 shade = _ShadeColor.rgb;
                half3 deep = shade * 0.72h;
                if (value < 0.26h) return lerp(deep, shade, smoothstep(0.0h, 0.26h, value));
                if (value < 0.62h) return lerp(shade, half3(1,1,1), smoothstep(0.26h, 0.62h, value));
                return lerp(half3(1,1,1), half3(1.06h,1.05h,1.03h), smoothstep(0.62h, 0.95h, value));
            }
            fixed4 frag(v2f i) : SV_Target {
                float3 n = normalize(i.worldNormal);
                // Camera-relative key light: view space to world space.
                float3 l = normalize(mul((float3x3)UNITY_MATRIX_I_V, normalize(_ViewLight.xyz)));
                float3 vdir = normalize(_WorldSpaceCameraPos - i.worldPos);
                half ndl = saturate(dot(n, l));
                half value = 0.30h + 0.85h * ndl;
                fixed4 base = tex2D(_MainTex, i.uv) * _Color;
                half3 col = base.rgb * Ramp(value);
                // Crease shading, tinted like the shadow.
                half3 aoTint = lerp(_ShadeColor.rgb * 0.55h, half3(1,1,1), i.ao);
                col *= lerp(half3(1,1,1), aoTint, _AO);
                float3 h = normalize(l + vdir);
                half spec = pow(saturate(dot(n, h)), _Gloss);
                col += _HighlightColor.rgb * smoothstep(_HighlightFrom, _HighlightTo, spec) * _HighlightStrength;
                half rim = smoothstep(0.55h, 0.85h, 1.0h - saturate(dot(n, vdir))) * _Rim * saturate(value);
                col = 1.0h - (1.0h - col) * (1.0h - half3(1.0h, 0.92h, 0.86h) * rim);
                fixed4 c = fixed4(col, 1);
                UNITY_APPLY_FOG(i.fogCoord, c);
                return c;
            }
            ENDCG
        }
        Pass {
            Name "OUTLINE"
            Tags { "LightMode"="Always" }
            Cull Front
            ZWrite On
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile_fog
            #include "UnityCG.cginc"
            fixed4 _OutlineColor;
            float _OutlineWidth;
            struct appdata { float4 vertex:POSITION; float3 normal:NORMAL; };
            struct v2f { float4 pos:SV_POSITION; UNITY_FOG_COORDS(0) };
            v2f vert(appdata v) {
                v2f o;
                float3 p = v.vertex.xyz + normalize(v.normal) * _OutlineWidth;
                o.pos = UnityObjectToClipPos(float4(p, 1));
                UNITY_TRANSFER_FOG(o, o.pos);
                return o;
            }
            fixed4 frag(v2f i) : SV_Target {
                fixed4 c = _OutlineColor;
                UNITY_APPLY_FOG(i.fogCoord, c);
                return c;
            }
            ENDCG
        }
        UsePass "Legacy Shaders/VertexLit/SHADOWCASTER"
    }
    FallBack "Unlit/Texture"
}
