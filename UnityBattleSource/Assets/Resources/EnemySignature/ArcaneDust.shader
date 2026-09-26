Shader "Mindstone/EnemySignature/ArcaneDust"
{
    Properties { _Backdrop("Backdrop",Float)=0 _Opacity("Opacity",Float)=0 }
    SubShader
    {
        Tags { "Queue"="Transparent+18" "RenderType"="Transparent" "IgnoreProjector"="True" }
        Blend SrcAlpha OneMinusSrcAlpha
        ZWrite Off Cull Off
        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma target 2.0
            #include "UnityCG.cginc"
            float _Backdrop,_Opacity;
            struct appdata { float4 vertex:POSITION; float4 color:COLOR; float2 uv:TEXCOORD0; };
            struct v2f { float4 vertex:SV_POSITION; fixed4 color:COLOR; float2 uv:TEXCOORD0; };
            v2f vert(appdata v) { v2f o;o.vertex=UnityObjectToClipPos(v.vertex);o.color=v.color;o.uv=v.uv;return o; }
            fixed4 frag(v2f i):SV_Target
            {
                // Soft asymmetric grain silhouette. The quad corners are fully
                // transparent; no square sprite or broad bloom is ever visible.
                if(_Backdrop>.5) return fixed4(.022,.008,.012,_Opacity);
                float2 q=i.uv;
                q.x += .13*sin(q.y*4.7);
                float r=dot(q,q);
                float edge=saturate((1-r)*3.1);
                float core=exp2(-r*2.5);
                float alpha=edge*core*i.color.a;
                return fixed4(i.color.rgb,alpha);
            }
            ENDCG
        }
    }
}
