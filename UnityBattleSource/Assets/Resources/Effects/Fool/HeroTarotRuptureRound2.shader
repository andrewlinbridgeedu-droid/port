Shader "Mindstone/Hero Tarot Rupture Round2"
{
    Properties
    {
        _MainTex("Original great tarot art",2D)="white"{}
        _Clock("Visual release age",Float)=0
        _Fade("Release fade",Range(0,1))=1
        _Flash("Short edge response",Range(0,1))=0
    }
    SubShader
    {
        Tags{"Queue"="Transparent+24" "RenderType"="Transparent"}
        Cull Off ZWrite Off Blend SrcAlpha OneMinusSrcAlpha
        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma target 3.0
            #include "UnityCG.cginc"
            sampler2D _MainTex;
            float _Clock,_Fade,_Flash;
            struct A{float4 vertex:POSITION;float3 normal:NORMAL;float2 uv:TEXCOORD0;float2 surface:TEXCOORD1;};
            struct V{float4 pos:SV_POSITION;float2 uv:TEXCOORD0;float2 surface:TEXCOORD1;float3 normal:TEXCOORD2;};
            V vert(A a)
            {
                V o;o.pos=UnityObjectToClipPos(a.vertex);o.uv=a.uv;o.surface=a.surface;
                o.normal=UnityObjectToWorldNormal(a.normal);return o;
            }
            float hash(float2 p){return frac(sin(dot(p,float2(127.1,311.7)))*43758.5453);}
            float grain(float2 p)
            {
                float2 cell=floor(p),f=frac(p);f=f*f*(3-2*f);
                return lerp(lerp(hash(cell),hash(cell+float2(1,0)),f.x),
                    lerp(hash(cell+float2(0,1)),hash(cell+1),f.x),f.y);
            }
            float4 frag(V i):SV_Target
            {
                float4 paint=tex2D(_MainTex,i.uv);
                float2 s=i.surface;
                float foil=saturate((paint.r-paint.b)*4.5+(paint.r-.28)*.75);
                float detail=dot(paint.rgb,float3(.28,.55,.17));
                float shade=.57+.43*abs(dot(normalize(i.normal),normalize(float3(-.3,.7,-.65))));
                float3 purple=lerp(float3(.20,.028,.40),float3(.62,.20,.85),saturate(detail*1.7));
                float3 body=lerp(purple+paint.rgb*.24,paint.rgb*1.22+float3(.15,.055,.018),foil)*shade;
                // Gold is carried by the original engraving and the curved torn
                // edge. No broad white bloom overwrites the internal illustration.
                float edge=exp(-min(s.x,1-s.x)*62);
                float broken=.36+.64*grain(float2(s.y*49,_Clock*2.3));
                float glint=pow(saturate(1-abs(s.y-(_Clock*1.8+.12))*8),3)*foil;
                body+=float3(1.15,.57,.12)*(edge*broken*(.36+_Flash*.48)+glint*.24);
                float erosion=grain(s*float2(37,63)+float2(_Clock*1.6,0));
                float erase=smoothstep((1-_Fade)*1.16-.13,(1-_Fade)*1.16+.08,erosion);
                float rootFade=smoothstep(0,.10,s.y);
                float alpha=paint.a*rootFade*erase*_Fade;
                clip(alpha-.005);
                return float4(min(body,1.55),alpha*.96);
            }
            ENDCG
        }
    }
    Fallback Off
}
