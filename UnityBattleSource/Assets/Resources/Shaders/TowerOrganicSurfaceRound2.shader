Shader "Mistport/TowerOrganicSurfaceRound2"
{
    Properties
    {
        _MainTex("Painted detail", 2D) = "white" {}
        _Color("Tint", Color) = (1,1,1,1)
        _Age("Visual seconds", Float) = 0
        _Seed("Layer phase", Float) = 0
        _Luma("Luminance alpha", Float) = 0
        _Dst("Destination blend", Float) = 10
        _Dissolve("Edge retreat", Range(0,1)) = 0
    }
    SubShader
    {
        Tags { "Queue"="Transparent+17" "RenderType"="Transparent" }
        Blend SrcAlpha [_Dst] ZWrite Off Cull Off
        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "UnityCG.cginc"
            struct appdata { float4 vertex:POSITION; float2 uv:TEXCOORD0; float2 local:TEXCOORD1; };
            struct v2f { float4 pos:SV_POSITION; float2 uv:TEXCOORD0; float2 local:TEXCOORD1; float3 world:TEXCOORD2; };
            sampler2D _MainTex;
            float4 _Color;
            float _Age,_Seed,_Luma,_Dissolve;
            v2f vert(appdata v)
            {
                v2f o; o.pos=UnityObjectToClipPos(v.vertex); o.uv=v.uv; o.local=v.local;
                o.world=mul(unity_ObjectToWorld,v.vertex).xyz; return o;
            }
            float4 frag(v2f i):SV_Target
            {
                float4 ink=tex2D(_MainTex,i.uv);
                float2 p=i.local;
                float grain=tex2D(_MainTex,i.uv*1.73+float2(_Seed*.071,-_Age*.085)).r;
                float edge=min(p.x,1-p.x);
                float erode=smoothstep(.008+.032*grain+_Dissolve*.44,.10+_Dissolve*.47,edge);
                float tips=smoothstep(0,.055,p.y)*smoothstep(0,.075,1-p.y);
                float alpha=lerp(ink.a,max(ink.r,max(ink.g,ink.b)),saturate(_Luma))*erode*tips;
                float3 normal=normalize(cross(ddx(i.world),ddy(i.world))+float3(0,0,.00001));
                float shade=.73+.27*abs(dot(normal,normalize(float3(.35,.8,-.45))));
                float flow=pow(saturate(.5+.5*sin(p.y*17-p.x*3-_Age*7+_Seed)),10);
                float veins=saturate(max(ink.r,max(ink.g,ink.b))-.38);
                float3 rgb=ink.rgb*_Color.rgb*shade+_Color.rgb*flow*veins*.42;
                return float4(rgb,alpha*_Color.a);
            }
            ENDCG
        }
    }
}
