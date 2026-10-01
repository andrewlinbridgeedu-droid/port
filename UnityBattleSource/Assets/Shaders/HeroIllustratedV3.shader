Shader "Mistport/HeroIllustratedV3"
{
    Properties {
        _MainTex ("Painted colour", 2D) = "white" {}
        _Color ("Palette", Color) = (1,1,1,1)
        _Form ("Soft drawn form", Range(0,1)) = .16
    }
    SubShader {
        Tags { "RenderType"="Opaque" "Queue"="Geometry" }
        Cull Off
        Pass {
            Tags { "LightMode"="ForwardBase" }
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile_fwdbase
            #pragma multi_compile_fog
            #include "UnityCG.cginc"
            #include "Lighting.cginc"
            #include "AutoLight.cginc"
            sampler2D _MainTex;
            float4 _MainTex_ST;
            fixed4 _Color;
            half _Form;
            struct appdata { float4 vertex:POSITION; float3 normal:NORMAL; float2 uv:TEXCOORD0; };
            struct v2f {
                float4 pos:SV_POSITION;
                float2 uv:TEXCOORD0;
                float3 worldNormal:TEXCOORD1;
                float3 worldPos:TEXCOORD2;
                SHADOW_COORDS(3)
                UNITY_FOG_COORDS(4)
            };
            v2f vert(appdata v) {
                v2f o;
                o.pos=UnityObjectToClipPos(v.vertex);
                o.uv=TRANSFORM_TEX(v.uv,_MainTex);
                o.worldNormal=UnityObjectToWorldNormal(v.normal);
                o.worldPos=mul(unity_ObjectToWorld,v.vertex).xyz;
                TRANSFER_SHADOW(o);
                UNITY_TRANSFER_FOG(o,o.pos);
                return o;
            }
            fixed4 frag(v2f i):SV_Target {
                half3 n=normalize(i.worldNormal);
                half3 direction=normalize(UnityWorldSpaceLightDir(i.worldPos));
                half form=smoothstep(-.28h,.78h,dot(n,direction));
                UNITY_LIGHT_ATTENUATION(attenuation,i,i.worldPos);
                // Limited diffuse variation keeps painted palettes visible. No
                // specular lobe, metallic response, reflection or shiny rim.
                half tone=lerp(1-_Form,1,form)*lerp(.94h,1.0h,attenuation);
                fixed4 colour=tex2D(_MainTex,i.uv)*_Color;
                colour.rgb*=tone;
                colour.a=1;
                UNITY_APPLY_FOG(i.fogCoord,colour);
                return colour;
            }
            ENDCG
        }
        UsePass "Legacy Shaders/VertexLit/SHADOWCASTER"
    }
    FallBack "Unlit/Texture"
}
