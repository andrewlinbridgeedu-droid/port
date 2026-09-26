Shader "Mistport/BountyMatterRound2"
{
    Properties
    {
        _MainTex("Existing authored matter", 2D) = "white" {}
        _Clock("Visual age", Float) = 0
        _Opacity("Owner opacity", Float) = 1
        _Light("Light on folds", Float) = 1
        _Fabric("Woven textile", Float) = 0
        _Metal("Open copper filigree", Float) = 0
        _Water("Foamed water", Float) = 0
    }
    SubShader
    {
        Tags { "Queue"="Transparent" "RenderType"="Transparent" }
        Cull Off ZWrite Off ZTest LEqual
        CGINCLUDE
        #include "UnityCG.cginc"
        sampler2D _MainTex;
        float _Clock, _Opacity, _Light, _Fabric, _Metal, _Water;
        struct a2v { float4 vertex:POSITION; float3 normal:NORMAL; float2 uv:TEXCOORD0; float4 color:COLOR; };
        struct v2f { float4 pos:SV_POSITION; float2 uv:TEXCOORD0; float3 normal:TEXCOORD1; float4 color:COLOR; };
        v2f vert(a2v v) {
            v2f o; o.pos=UnityObjectToClipPos(v.vertex); o.uv=v.uv;
            o.normal=UnityObjectToWorldNormal(v.normal); o.color=v.color; return o;
        }
        float4 matter(v2f i) {
            float2 flow=float2(i.uv.x*1.83-_Clock*.14, i.uv.y*.83+sin(i.uv.x*8.1-_Clock*1.7)*.055);
            float3 art=tex2D(_MainTex,flow).rgb;
            float ink=dot(art,float3(.3,.51,.19));
            float curl=sin(i.uv.x*23+sin(i.uv.y*9.7+_Clock)*2.8-_Clock*4);
            float edgeDistance=min(i.uv.y,1-i.uv.y);
            float edge=smoothstep(.008,.12,edgeDistance);
            float grain=sin(i.uv.x*79+sin(i.uv.y*31)*1.9-_Clock*3.3)*.5+.5;
            float warp=sin(i.uv.x*46+sin(i.uv.y*17-_Clock*2.1)*3.1);
            float broken=smoothstep(.07,.36,ink+grain*.17+edge*.24+warp*.055);
            float density=(.55+ink*.41+grain*.08)*edge*broken;
            float fabricInk=smoothstep(.10,.56,art.r);
            float torn=smoothstep(.12,.65,art.r+grain*.17+warp*.08);
            float cloth=(.52+.23*fabricInk+.14*grain)*edge;
            density=lerp(density,saturate(cloth+.11*torn)*edge,_Fabric);
            density=lerp(density,(.57+ink*.41)*edge*broken,_Metal);
            float current=sin(i.uv.x*31+sin(i.uv.y*13-_Clock*2.2)*2.1-_Clock*4.6);
            density=lerp(density,saturate(.46+ink*.26+current*.16+grain*.11)*edge,_Water);
            float light=.38+.52*abs(dot(normalize(i.normal),normalize(float3(.35,.8,-.55))));
            float fiber=pow(saturate(curl*.5+.5),13)*(.25+ink*.75);
            float weave=sin(i.uv.x*420)*sin(i.uv.y*270)*.055*_Fabric;
            return float4(light+ink*.25+weave,fiber,density,ink);
        }
        ENDCG
        Pass
        {
            Blend SrcAlpha OneMinusSrcAlpha
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            float4 frag(v2f i):SV_Target {
                float4 m=matter(i);
                float3 art=tex2D(_MainTex,float2(i.uv.x*1.83-_Clock*.14,
                    i.uv.y*.83+sin(i.uv.x*8.1-_Clock*1.7)*.055)).rgb;
                float3 baseColor=i.color.rgb*(m.x*.65+.19+art.r*.38);
                float3 fabricColor=i.color.rgb*(.36+art.r*.82)+art*.44;
                float3 metalColor=baseColor*(.66+m.w*.68);
                float foam=smoothstep(.47,.96,sin(i.uv.x*29+sin(i.uv.y*18-_Clock*3)*1.8-_Clock*5));
                float3 waterColor=lerp(i.color.rgb*.74,float3(.88,.98,1),foam*.31+m.w*.10);
                float3 shaded=lerp(lerp(lerp(baseColor,fabricColor,_Fabric),metalColor,_Metal),waterColor,_Water);
                return float4(shaded,m.z*i.color.a*_Opacity);
            }
            ENDCG
        }
        Pass
        {
            Blend SrcAlpha One
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            float4 frag(v2f i):SV_Target {
                float4 m=matter(i);
                float3 art=tex2D(_MainTex,float2(i.uv.x*1.83-_Clock*.14,
                    i.uv.y*.83+sin(i.uv.x*8.1-_Clock*1.7)*.055)).rgb;
                float glint=pow(saturate(sin(i.uv.x*141+sin(i.uv.y*48)*2-_Clock*7.1)),26)*m.w;
                float brightness=m.z*(.23+m.y*.85)+glint*.22+art.r*_Fabric*.18+m.w*_Metal*.09;
                brightness=lerp(brightness,brightness*.81+glint*.17,_Water);
                return float4(lerp(i.color.rgb,float3(1,.86,.65),m.y*.18)*_Light,
                    brightness*i.color.a*_Opacity);
            }
            ENDCG
        }
    }
}
