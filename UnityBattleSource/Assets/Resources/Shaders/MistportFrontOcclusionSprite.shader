Shader "Mindstone/Mistport Front Occlusion Sprite"
{
    Properties
    {
        [PerRendererData] _MainTex ("Sprite Texture", 2D) = "white" {}
        _Color ("Tint", Color) = (1,1,1,1)
        _Phase ("Organic Phase", Float) = 0
    }
    SubShader
    {
        Tags
        {
            "Queue"="Transparent+100"
            "IgnoreProjector"="True"
            "RenderType"="Transparent"
            "PreviewType"="Plane"
            "CanUseSpriteAtlas"="True"
        }
        Cull Off
        Lighting Off
        ZWrite Off
        // This is a deliberate front-facing VFX veil. The actor Renderer
        // stays enabled; the detonation owns the pixels at contact peak.
        ZTest Always
        Blend SrcAlpha OneMinusSrcAlpha

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "UnityCG.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
                fixed4 color : COLOR;
            };

            struct v2f
            {
                float4 vertex : SV_POSITION;
                float2 uv : TEXCOORD0;
                fixed4 color : COLOR;
            };

            sampler2D _MainTex;
            fixed4 _Color;
            float _Phase;

            float hash21(float2 coord)
            {
                coord = frac(coord * float2(123.34, 456.21));
                coord += dot(coord, coord + 45.32);
                return frac(coord.x * coord.y);
            }

            float noise2d(float2 coord)
            {
                float2 cell = floor(coord);
                float2 local = frac(coord);
                local = local * local * (3.0 - 2.0 * local);
                float a = hash21(cell);
                float b = hash21(cell + float2(1.0, 0.0));
                float c = hash21(cell + float2(0.0, 1.0));
                float d = hash21(cell + float2(1.0, 1.0));
                return lerp(lerp(a, b, local.x), lerp(c, d, local.x), local.y);
            }

            v2f vert(appdata input)
            {
                v2f output;
                output.vertex = UnityObjectToClipPos(input.vertex);
                output.uv = input.uv;
                // The cover is also used on a runtime Quad, whose imported
                // mesh may not carry a vertex-color channel. The material
                // tint is therefore authoritative for both SpriteRenderer
                // and MeshRenderer paths.
                output.color = _Color;
                return output;
            }

            fixed4 frag(v2f input) : SV_Target
            {
                // Keep the contact cover procedural on the runtime Quad. It
                // preserves the irregular flame/smoke silhouette without
                // relying on a generated Texture2D's alpha import path.
                float2 centered = input.uv * 2.0 - 1.0;
                float radius = length(centered);
                float angle = atan2(centered.y, centered.x);
                float2 flow = float2(_Phase * 0.021, -_Phase * 0.015);
                float coarse = noise2d(centered * 2.8 + flow);
                float fine = noise2d(centered * 7.2 - flow * 1.8);
                float lobe = 0.92
                    + sin(angle * 3.10 + 0.80 + _Phase * 0.04) * 0.13
                    + sin(angle * 6.70 - 2.30 - _Phase * 0.06) * 0.09
                    + sin(angle * 11.30 + 0.40 + _Phase * 0.09) * 0.045;
                lobe *= 1.0 + cos(angle - 0.40) * 0.08
                    + sin(angle * 2.20 + 1.10) * 0.05;
                lobe += (coarse - 0.5) * 0.22 + (fine - 0.5) * 0.075;
                float edge = 0.86 * lobe;
                // Keep the irregular edge, but make the inner mass solid so
                // the live protagonist cannot leak through at peak contact.
                float alpha = 1.0 - smoothstep(edge * 0.78, edge, radius);
                alpha *= 0.94 + sin(angle * 4.70 + 0.2) * 0.06;
                float detail = saturate(fine * 0.72 + coarse * 0.28);
                // Leave small torn gaps only near the perimeter. The core
                // remains opaque, while the moving edge reads as hot smoke
                // and flame instead of a clean geometric disk.
                float torn = smoothstep(edge * 0.52, edge, radius)
                    * smoothstep(0.22, 0.72, fine);
                alpha *= 1.0 - torn * 0.22;
                float coreLight = saturate(1.0 - radius / max(0.01, edge));
                float soot = smoothstep(0.30, 0.82, detail)
                    * smoothstep(0.18, 0.95, radius) * 0.16;
                float3 tint = input.color.rgb
                    * (0.76 + coreLight * 0.28 + detail * 0.08);
                tint *= 1.0 - soot;
                return fixed4(tint, input.color.a * alpha);
            }
            ENDCG
        }
    }
}
