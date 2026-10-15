// Moving parts of OvalLightShield (2026-10-06): crystal shards, energy ribbons,
// swirl arcs and sparks, all in one dynamic mesh. uv2.y picks the part:
// 0 shard   uv.x 0 centre -> 1 edge, uv.y seed, uv3.x facet shade, uv2.x heat
// 1 ribbon  uv.x 0 tail -> 1 head, uv.y across, uv2.x flow seed
// 2 spark   uv quad 0..1, uv2.x star-cross amount
// Vertex colour multiplies everything (alpha = fade). Premultiplied output.
Shader "Mistport/OvalShieldParts"
{
    Properties
    {
        _Tint("Body",Color)=(.35,.75,1,1)
        _Deep("Deep",Color)=(.1,.25,.75,1)
        _Edge("Edge",Color)=(.85,.95,1,1)
        _Hot("Hot",Color)=(1,1,1,1)
        _Noise("Noise",2D)="gray"{}
        _Age("Seconds",Float)=0
    }
    SubShader
    {
        Tags {"Queue"="Transparent+21" "RenderType"="Transparent" "IgnoreProjector"="True"}
        Blend One OneMinusSrcAlpha ZWrite Off Cull Off
        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "UnityCG.cginc"
            struct A {float4 vertex:POSITION;float4 color:COLOR;float2 uv:TEXCOORD0;float2 uv2:TEXCOORD1;float2 uv3:TEXCOORD2;};
            struct V {float4 pos:SV_POSITION;float4 color:COLOR;float2 uv:TEXCOORD0;float2 uv2:TEXCOORD1;float2 uv3:TEXCOORD2;};
            sampler2D _Noise;float4 _Tint,_Deep,_Edge,_Hot;float _Age;
            V vert(A i){V o;o.pos=UnityObjectToClipPos(i.vertex);o.color=i.color;o.uv=i.uv;o.uv2=i.uv2;o.uv3=i.uv3;return o;}
            float4 frag(V i):SV_Target
            {
                float mode=i.uv2.y;float a=i.color.a;
                if(mode<.5)
                {
                    // Crystal shard: glassy centre, bright cut edge, each facet its own
                    // shade, a sliding highlight; hot when lit.
                    float e=i.uv.x,s=i.uv.y,shade=i.uv3.x,heat=i.uv2.x;
                    float vein=tex2D(_Noise,float2(e*.6+s*3.1,shade*2.3+_Age*.05)).r;
                    float3 col=lerp(_Deep.rgb,_Tint.rgb,saturate(.35+e*.45+shade*.35+(vein-.5)*.6));
                    float edge=smoothstep(.84,.985,e);
                    float sheen=pow(saturate(1-abs(frac(shade*1.7+s*2.3+_Age*.35)*2-1)),6)*(.4+.6*e);
                    float body=(.14+.30*e*e)*(.8+.4*shade);
                    float alpha=saturate(body+edge*.55+sheen*.12)*a;
                    float3 c=(col*body+_Edge.rgb*edge*.55)*a;
                    c+=(_Hot.rgb*heat*(.25+.8*edge+.25*shade)+_Edge.rgb*(edge*.35+sheen*.5))*a;
                    return float4(c*i.color.rgb,alpha);
                }
                if(mode<1.5)
                {
                    // Energy ribbon: soft body, white core, light racing tail to head.
                    float u=i.uv.x,v=i.uv.y,seed=i.uv2.x;
                    float prof=1-abs(2*v-1);
                    float soft=pow(prof,1.3),core=pow(prof,7);
                    float flow=tex2D(_Noise,float2(u*1.7-_Age*1.25+seed,v*.22+seed*.37)).r;
                    float flow2=tex2D(_Noise,float2(u*3.9-_Age*2.1+seed*1.7,.5+seed)).g;
                    float streak=smoothstep(.38,.82,flow)*.7+smoothstep(.55,.9,flow2)*.6;
                    float head=.55+.9*smoothstep(.45,1,u);
                    float alpha=saturate(soft*(.32+.45*streak))*a;
                    float3 c=_Tint.rgb*soft*(.35+.55*streak)*a+_Hot.rgb*core*(.35+streak)*head*a;
                    return float4(c*i.color.rgb,alpha);
                }
                // Spark: soft disc with an optional four-point glint.
                float2 p=i.uv*2-1;float r2=dot(p,p);
                float disc=exp(-r2*7);
                float cross=(exp(-abs(p.x)*20)*exp(-p.y*p.y*3)+exp(-abs(p.y)*20)*exp(-p.x*p.x*3))*i.uv2.x;
                float val=disc+cross*.7;
                float3 c=lerp(_Tint.rgb,_Hot.rgb,saturate(disc*1.3))*val*a;
                return float4(c*i.color.rgb,saturate(val*.18)*a);
            }
            ENDCG
        }
    }
}
