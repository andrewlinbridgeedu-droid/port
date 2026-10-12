// Inverted-hull outline for enemy bodies (2026-10-09 trial, the overlay-material outline
// from the user's UE article): the mesh is drawn again with its front faces culled and every
// vertex pushed out along its normal in clip space, so the back faces show only as a band
// round the silhouette and the inner contours. The band keeps the same width on screen
// (_Width is a fraction of the screen height) whatever the enemy's distance.
// Ink: alpha blend, writes depth. Glow: additive shells, one material per shell.
Shader "Mistport/EnemyOutline20261009"
{
    Properties
    {
        _Color ("Colour", Color) = (0.07, 0.04, 0.09, 1)
        _Width ("Width (fraction of screen height)", Float) = 0.002
        [Enum(UnityEngine.Rendering.BlendMode)] _Src ("Blend source", Float) = 5
        [Enum(UnityEngine.Rendering.BlendMode)] _Dst ("Blend destination", Float) = 10
        _ZW ("ZWrite", Float) = 1
    }
    SubShader
    {
        Tags { "Queue" = "Geometry+20" "RenderType" = "Opaque" "IgnoreProjector" = "True" }
        Pass
        {
            Cull Front
            ZWrite [_ZW]
            Blend [_Src] [_Dst]
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "UnityCG.cginc"

            fixed4 _Color;
            float _Width;

            struct appdata { float4 vertex : POSITION; float3 normal : NORMAL; };
            struct v2f { float4 pos : SV_POSITION; };

            v2f vert (appdata v)
            {
                v2f o;
                float4 p = UnityObjectToClipPos(v.vertex);
                float3 nv = mul((float3x3)UNITY_MATRIX_IT_MV, v.normal);
                float2 d = mul((float2x2)UNITY_MATRIX_P, nv.xy);
                float len = length(d);
                d = len > 1e-5 ? d / len : float2(0, 0);
                d.x *= _ScreenParams.y / _ScreenParams.x;
                p.xy += d * (_Width * 2.0) * p.w;
                o.pos = p;
                return o;
            }

            fixed4 frag (v2f i) : SV_Target { return _Color; }
            ENDCG
        }
    }
}
