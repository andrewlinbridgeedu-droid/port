Shader "Mistport/GoldenRiftArt"
{
 Properties
 {
  _MainTex("Painted continuous fissure",2D)="white"{} _FxTime("Sample time",Float)=0
  _Layer("Raised ember fold",Float)=0 _Seed("Fold variation",Float)=0 _TargetU("Recipient along fissure",Float)=.7
 }
 SubShader
 {
  Tags { "Queue"="Transparent-10" "RenderType"="Transparent" }
  Blend One OneMinusSrcAlpha ZWrite Off Cull Off ZTest LEqual
  Pass
  {
   CGPROGRAM
   #pragma target 3.0
   #pragma vertex vert
   #pragma fragment frag
   #include "UnityCG.cginc"
   sampler2D _MainTex;float _FxTime,_Layer,_Seed,_TargetU;
   struct app {float4 vertex:POSITION;float2 uv:TEXCOORD0;float2 domain:TEXCOORD1;};
   struct v2f {float4 vertex:SV_POSITION;float2 uv:TEXCOORD0;float3 world:TEXCOORD1;float2 domain:TEXCOORD2;};
   v2f vert(app v)
   {
    v2f o;
    // Low-frequency geometry in BOTH texture axes; retain original full-resolution painted detail.
    float4 art=tex2Dlod(_MainTex,float4(v.uv,0,5));
    float4 acrossA=tex2Dlod(_MainTex,float4(v.uv+float2(0,.012),0,5));
    float4 acrossB=tex2Dlod(_MainTex,float4(v.uv-float2(0,.012),0,5));
    float4 alongA=tex2Dlod(_MainTex,float4(v.uv+float2(.008,0),0,5));
    float4 alongB=tex2Dlod(_MainTex,float4(v.uv-float2(.008,0),0,5));
    float4 soft=(art*4+acrossA+acrossB+alongA+alongB)*.125;
    float gold=smoothstep(.03,.7,soft.g-soft.b)*soft.a;
    float heat=saturate(soft.r-soft.g)*soft.a;
    float age=_FxTime-(.18+v.uv.x*.65);
    float open=smoothstep(0,.10,age),close=1-smoothstep(1.55,2.16,_FxTime);
    float hit=exp(-pow((_FxTime-.91)/.11,2));
    float post=max(0,_FxTime-.84);
    float release=saturate(post/.05)*exp(-max(0,post-.05)*11);
    float recipient=exp(-pow((v.uv.x-_TargetU)/.18,2));
    float roll=.5+.5*sin(v.uv.x*17-_FxTime*7+v.uv.y*9);
    float endTaper=sin(saturate(v.uv.x)*3.14159);
    float crest=gold*(.24+hit*.12);
    float curl=heat*(.08+roll*.28)*endTaper;
    v.vertex.y+=(crest+curl)*open*close;
    // Local contact pressure lifts the hot shoulder; the continuous dark channel stays intact.
    v.vertex.y+=heat*recipient*release*.38*open*close;
    v.vertex.x+=sign(v.vertex.x)*heat*.24*sin(roll*3.14159)*open*close;
    v.vertex.x*=1+hit*.10*open;
    if(_Layer>.5)
    {
     float a=v.domain.x,b=v.domain.y;
     float taper=pow(saturate(sin(a*3.14159)),.7)*sin(b*3.14159);
     float turn=a*3.7+b*1.9+_Seed-_FxTime*3.1;
     float loft=(.13+.12*sin(turn)+recipient*release*.42)*taper*open*close;
     v.vertex.y+=loft;
     v.vertex.x+=sign(v.vertex.x)*sin(turn)*taper*.12*open*close;
     v.vertex.z+=cos(turn)*taper*.16*open*close;
    }
    o.world=mul(unity_ObjectToWorld,v.vertex).xyz;
    o.vertex=UnityObjectToClipPos(v.vertex);o.uv=v.uv;o.domain=v.domain;return o;
   }
   float4 frag(v2f i):SV_Target
   {
    // Preserve the original travel front, sustain, and backwards closing wave.
    float opening=saturate((_FxTime-.18)/.65),closing=saturate((_FxTime-1.55)/.60);
    float openMask=smoothstep(i.uv.x-.045,i.uv.x+.035,opening);
    float closeMask=1-smoothstep(i.uv.x-.04,i.uv.x+.045,closing);
    float startup=saturate((_FxTime-.16)*40),ended=1-saturate((_FxTime-2.16)*9);
    float4 base=tex2D(_MainTex,i.uv);
    float heat=saturate(base.r-base.g);
    float2 flow=i.uv;
    flow.y+=sin(i.uv.x*24-_FxTime*8)*.0035*heat;
    flow.x+=sin(i.uv.y*19+_FxTime*5)*.0015*heat;
    float4 c=tex2D(_MainTex,flow);
    float gold=saturate((c.r-c.b)*3);
    float front=exp(-abs(i.uv.x-opening)*45)*saturate((.96-_FxTime)*8);
    float3 normal=cross(ddy(i.world),ddx(i.world));
    normal*=rsqrt(max(dot(normal,normal),.0000001));
    if(normal.y<0)normal=-normal;
    float facing=saturate(dot(normal,normalize(float3(-.5,1,-.45))));
    float wall=1-saturate(normal.y);
    c.rgb*=lerp(.53,1.03,facing);
    c.rgb*=1+gold*(.20+front*.8);
    float packet=pow(saturate(sin(i.uv.x*39-_FxTime*14+c.g*4)),12);
    c.rgb+=float3(.12,.055,.006)*packet*gold+float3(.08,.023,.002)*heat;
    c.rgb*=1-wall*.075;
    c.a*=openMask*closeMask*startup*ended;
    if(_Layer>.5)
    {
     float a=i.domain.x,b=i.domain.y;
     float taper=smoothstep(0,.12,a)*(1-smoothstep(.81,1,a));
     taper*=smoothstep(0,.16,b)*(1-smoothstep(.77,1,b));
     float streak=.48+.25*sin(a*19+b*7-_FxTime*9+_Seed)+base.g*.32;
     float erosion=smoothstep(1.27,2.08,_FxTime);
     float torn=smoothstep(erosion-.16,erosion+.13,streak);
     c.a*=taper*saturate(heat*3)*torn*.60;
     c.rgb=lerp(float3(.48,.035,.004),float3(1.30,.49,.05),saturate(base.g*2+packet*.26));
     c.rgb*=.78+facing*.22;
    }
    c.rgb*=c.a;return c;
   }
   ENDCG
  }
 }
}
