Shader "Mistport/OvalLightShield"
{
    Properties
    {
        _Tint("Membrane",Color)=(.35,.75,1,1)
        _Rim("Rim",Color)=(.85,.95,1,1)
        _Spark("Sparkle",Color)=(1,1,1,1)
        _Age("Seconds",Float)=0
        _Opacity("Opacity",Float)=1
        _FlowSpeed("Flow speed",Float)=.4
        _FlowAngle("Flow angle (rad)",Float)=1.5708
        _BandFreq("Band frequency",Float)=6
        _Facet("Facet amount",Float)=0
        _SparkAmt("Sparkle amount",Float)=.35
        _Seed("Phase",Float)=0
    }
    SubShader
    {
        Tags {"Queue"="Transparent+20" "RenderType"="Transparent"}
        Blend SrcAlpha One ZWrite Off Cull Back
        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "UnityCG.cginc"
            struct A {float4 vertex:POSITION;float3 normal:NORMAL;};
            struct V {float4 pos:SV_POSITION;float3 local:TEXCOORD0;float3 wn:TEXCOORD1;float3 wv:TEXCOORD2;};
            float4 _Tint,_Rim,_Spark;float _Age,_Opacity,_FlowSpeed,_FlowAngle,_BandFreq,_Facet,_SparkAmt,_Seed;
            V vert(A i){V o;o.pos=UnityObjectToClipPos(i.vertex);o.local=i.vertex.xyz;
                float3 w=mul(unity_ObjectToWorld,i.vertex).xyz;o.wn=UnityObjectToWorldNormal(i.normal);o.wv=normalize(_WorldSpaceCameraPos-w);return o;}
            float hash(float2 p){return frac(sin(dot(p,float2(127.1,311.7)))*43758.5453);}
            float4 frag(V i):SV_Target
            {
                float3 n=normalize(i.wn);float ndv=saturate(abs(dot(n,normalize(i.wv))));
                float rim=pow(1-ndv,2.2);
                // Flowing light bands sweep across the membrane along _FlowAngle.
                float2 d=float2(cos(_FlowAngle),sin(_FlowAngle));
                float along=dot(i.local.xy,d)*_BandFreq-_Age*_FlowSpeed*6.28318+_Seed;
                float band=pow(.5+.5*sin(along),3);
                float band2=pow(.5+.5*sin(along*.53+1.7+_Age*_FlowSpeed*2.1),4);
                // Faceted shimmer: cells that light up one at a time (crystal plates).
                float2 cell=floor(i.local.xy*float2(7,9)+float2(_Seed,0));
                float facet=step(.92,frac(hash(cell)*7.3+_Age*(.6+.9*hash(cell+3.1))));
                // Sparkle: short-lived glints drifting over the surface.
                float2 sp=i.local.xy*float2(23,29)+float2(_Age*.7,-_Age*.4);
                float glint=pow(saturate(sin(sp.x*3.1+_Seed)*sin(sp.y*2.7-_Age*5)),16);
                float3 col=_Tint.rgb*(.22+.55*band+.3*band2)+_Rim.rgb*rim*1.2+_Spark.rgb*(glint*_SparkAmt+facet*_Facet);
                float alpha=_Opacity*saturate(.10+.28*band+.18*band2+.75*rim+.5*glint*_SparkAmt+.6*facet*_Facet);
                return float4(col,alpha);
            }
            ENDCG
        }
    }
}
