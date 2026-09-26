Shader "Mistport/EnemyContactImpact"
{
    Properties { _Opacity("Opacity", Float) = 1 }
    SubShader
    {
        Tags { "Queue"="Transparent+10" "RenderType"="Transparent" }
        Pass
        {
            Blend SrcAlpha One
            ZWrite Off
            Cull Off
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "UnityCG.cginc"
            float _Opacity;
            struct appdata { float4 vertex : POSITION; float4 color : COLOR; };
            struct v2f { float4 pos : SV_POSITION; float4 color : COLOR; };
            v2f vert(appdata v) { v2f o; o.pos=UnityObjectToClipPos(v.vertex); o.color=v.color; return o; }
            float4 frag(v2f i) : SV_Target { return float4(i.color.rgb, i.color.a * _Opacity); }
            ENDCG
        }
    }
}
