Shader "Mindstone/EnemySignature/CrimsonStageProjection"
{
    SubShader
    {
        Tags {"Queue"="Transparent+10" "RenderType"="Transparent"}
        Blend SrcAlpha OneMinusSrcAlpha
        ZWrite On
        Cull Off
        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma target 3.0
            #include "UnityCG.cginc"
            struct v2f {float4 pos:SV_POSITION;half3 normal:TEXCOORD0;float3 world:TEXCOORD1;half4 color:COLOR;};
            v2f vert(appdata_full v){v2f o;o.pos=UnityObjectToClipPos(v.vertex);o.normal=UnityObjectToWorldNormal(v.normal);o.world=mul(unity_ObjectToWorld,v.vertex).xyz;o.color=v.color;return o;}
            half4 frag(v2f i):SV_Target
            {
                clip(i.color.a-.008);
                half3 n=normalize(i.normal),v=normalize(_WorldSpaceCameraPos-i.world);
                half3 light=normalize(half3(-.35,.8,-.55));
                half ndl=abs(dot(n,light));
                half spec=pow(saturate(abs(dot(n,normalize(light+v)))),26);
                half steel=saturate((i.color.g-i.color.r+.08)*5);
                half3 color=i.color.rgb*(.3+ndl*.78)+spec*lerp(half3(.38,.065,.07),half3(.7,.8,1),steel);
                // Saturated silk has only a restrained sheen, never a light plate.
                color+=i.color.rgb*(1-steel)*.16;
                return half4(color,i.color.a);
            }
            ENDCG
        }
    }
    Fallback Off
}
