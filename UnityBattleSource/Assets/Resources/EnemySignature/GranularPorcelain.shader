Shader "Mindstone/EnemySignature/GranularPorcelain"
{
    Properties
    {
        _Color ("Porcelain color / opacity", Color) = (0.72,0.66,0.57,1)
        _Dust ("Granular dissolution", Range(0,1)) = 0.55
        _Tint ("Warm gold / violet dust tint", Color) = (0.88,0.53,0.25,1)
        _MainTex ("Porcelain texture (optional)", 2D) = "white" {}
    }
    SubShader
    {
        Tags { "Queue"="Transparent+20" "RenderType"="Transparent" "IgnoreProjector"="True" }
        Blend SrcAlpha OneMinusSrcAlpha
        ZWrite Off
        Cull Back
        Pass
        {
            Tags { "LightMode"="ForwardBase" }
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma target 3.0
            #include "UnityCG.cginc"
            #include "Lighting.cginc"
            sampler2D _MainTex;
            float4 _MainTex_ST;
            float4 _Color, _Tint;
            float _Dust;
            struct appdata { float4 vertex:POSITION; float3 normal:NORMAL; float2 uv:TEXCOORD0; };
            struct v2f
            {
                float4 pos:SV_POSITION;
                float3 grainPosition:TEXCOORD0;
                float3 worldNormal:TEXCOORD1;
                float3 worldPosition:TEXCOORD2;
                float2 uv:TEXCOORD3;
            };
            float hash31(float3 p)
            {
                p=frac(p*0.1031);
                p+=dot(p,p.yzx+33.33);
                return frac((p.x+p.y)*p.z);
            }
            float3 hash33(float3 p)
            {
                p=frac(p*float3(.1031,.1030,.0973));
                p+=dot(p,p.yxz+33.33);
                return frac((p.xxy+p.yxx)*p.zyx);
            }
            float noise3(float3 p)
            {
                float3 i=floor(p), f=frac(p); f=f*f*(3-2*f);
                return lerp(lerp(lerp(hash31(i),hash31(i+float3(1,0,0)),f.x),
                                 lerp(hash31(i+float3(0,1,0)),hash31(i+float3(1,1,0)),f.x),f.y),
                            lerp(lerp(hash31(i+float3(0,0,1)),hash31(i+float3(1,0,1)),f.x),
                                 lerp(hash31(i+float3(0,1,1)),hash31(i+float3(1,1,1)),f.x),f.y),f.z);
            }
            v2f vert(appdata v)
            {
                v2f o; o.pos=UnityObjectToClipPos(v.vertex);
                // Local orientation, world-sized grains: they follow the mask and never
                // become a camera-space overlay. Translation/rotation do not cause crawl.
                float3 scale=float3(length(unity_ObjectToWorld._m00_m10_m20),
                                    length(unity_ObjectToWorld._m01_m11_m21),
                                    length(unity_ObjectToWorld._m02_m12_m22));
                o.grainPosition=v.vertex.xyz*scale;
                o.worldPosition=mul(unity_ObjectToWorld,v.vertex).xyz;
                o.worldNormal=UnityObjectToWorldNormal(v.normal);
                o.uv=TRANSFORM_TEX(v.uv,_MainTex); return o;
            }
            float4 frag(v2f i):SV_Target
            {
                float dust=saturate(_Dust);
                // Two irregular spatial scales. Warping removes any readable voxel rows.
                float3 p=i.grainPosition;
                float drift=noise3(p*5.7+float3(0,-_Time.y*.24,0));
                float3 q=p/0.013+float3(drift,drift*.71,-drift*.43)*.8;
                float3 cell=floor(q-.5);
                float best=100, identity=0;
                [unroll] for(int z=0;z<2;z++)
                [unroll] for(int y=0;y<2;y++)
                [unroll] for(int x=0;x<2;x++)
                {
                    float3 id=cell+float3(x,y,z);
                    float3 jitter=hash33(id);
                    float3 d=q-(id+.15+jitter*.7);
                    float distanceSquared=dot(d,d);
                    if(distanceSquared<best){best=distanceSquared;identity=jitter.x;}
                }
                float distanceToGrain=sqrt(best);
                float aa=clamp(fwidth(distanceToGrain),.025,.22);
                float radius=lerp(.36,.61,identity);
                float grain=1-smoothstep(radius-aa,radius+aa,distanceToGrain);
                float core=1-smoothstep(.10,.29,distanceToGrain);
                float stream=smoothstep(.24,.65,drift);
                // Dense opaque cores, small actual transparent gaps, larger drifting
                // dissolution patches at high Dust. Zero Dust retains a readable face.
                float coverage=lerp(1,grain,dust)*lerp(1,.12+.88*stream,dust*dust);
                float4 tex=tex2D(_MainTex,i.uv);
                float3 n=normalize(i.worldNormal);
                float3 l=normalize(UnityWorldSpaceLightDir(i.worldPosition));
                float diffuse=saturate(dot(n,l));
                float3 ambient=max(ShadeSH9(float4(n,1)),float3(.20,.18,.22));
                float3 illumination=min(ambient+_LightColor0.rgb*(.2+.72*diffuse),float3(1.15,1.15,1.15));
                float variation=lerp(.61,1.04,identity);
                float3 ivory=tex.rgb*_Color.rgb;
                float3 pigment=lerp(ivory,lerp(ivory,_Tint.rgb,.30)*variation,dust);
                float sparkle=core*step(.61,identity)*(.55+.45*sin(_Time.y*2.1+identity*42));
                float3 rgb=pigment*illumination*1.1+_Tint.rgb*sparkle*dust*.58;
                return float4(rgb,saturate(_Color.a*tex.a*coverage));
            }
            ENDCG
        }
    }
    Fallback Off
}
