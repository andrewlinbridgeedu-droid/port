Shader "Mistport/TowerMarrowRound2"
{
    Properties
    {
        _MainTex("Original marrow grain",2D)="white"{}
        _Color("Body",Color)=(.35,.68,1,1)
        _VeinTint("Carved vein",Color)=(.85,.96,1,1)
        _Age("Visual age",Float)=0
        _Seed("Layer phase",Float)=0
    }
    SubShader
    {
        Tags {"Queue"="Transparent+17" "RenderType"="Transparent"}
        Blend SrcAlpha OneMinusSrcAlpha ZWrite Off Cull Off
        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "UnityCG.cginc"
            struct A {float4 vertex:POSITION;float2 uv:TEXCOORD0;float2 local:TEXCOORD1;};
            struct V {float4 pos:SV_POSITION;float2 uv:TEXCOORD0;float2 local:TEXCOORD1;float3 world:TEXCOORD2;};
            sampler2D _MainTex;float4 _Color,_VeinTint;float _Age,_Seed;
            V vert(A i){V o;o.pos=UnityObjectToClipPos(i.vertex);o.uv=i.uv;o.local=i.local;o.world=mul(unity_ObjectToWorld,i.vertex).xyz;return o;}
            float4 frag(V i):SV_Target
            {
                float4 ink=tex2D(_MainTex,i.uv);
                float grain=dot(ink.rgb,float3(.25,.50,.25));
                float2 p=i.local;
                float edge=min(p.x,1-p.x);
                float erode=smoothstep(.015+.035*grain,.13,edge);
                float tip=smoothstep(0,.05,p.y)*smoothstep(0,.06,1-p.y);
                float3 n=normalize(cross(ddx(i.world),ddy(i.world))+float3(0,0,.00001));
                float shade=.56+.44*abs(dot(n,normalize(float3(.32,.71,-.5))));
                float flow=.82+.18*sin(p.y*8.7-_Age*9+_Seed);
                float vein=smoothstep(.32,.82,grain);
                // Broad colored matter stays present between the original
                // branching painted veins, rather than only glowing edges.
                float3 body=_Color.rgb*(.51+.68*sqrt(saturate(grain)))*shade;
                float3 carved=_VeinTint.rgb*vein*flow*.94;
                float alpha=_Color.a*erode*tip*(.62+.34*ink.a);
                return float4(body+carved,alpha);
            }
            ENDCG
        }
    }
}
