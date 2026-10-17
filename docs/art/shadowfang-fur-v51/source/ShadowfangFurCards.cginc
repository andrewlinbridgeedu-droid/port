// Shared by ShadowfangFurCards (solid, alpha-tested) and ShadowfangFurSoft
// (the blended fringe). Review only: these cards are not production assets yet.
//
// A card bends on the GPU from its own data: uv.y is 0 at the root and 1 at the
// tip, uv2 = (random phase, card length in Blender units). The first _RootLock
// of every card never moves; past it the bend grows with the square of the
// distance, a travelling wave makes the tip lag the middle, and the tip is
// pulled back toward the root as it swings so the card keeps its length
// instead of stretching into a spike. Wind and the body's inertia arrive as
// world-space vectors per renderer (ShadowfangFurWind).

sampler2D _MainTex;
fixed4 _Color;
half _RootShade, _Wrap, _Sheen, _StrandContrast;  // _Cutoff: declared by alphatest, or by the soft pass
float _FurWorldUnit, _RootLock, _Sway, _Flutter, _WaveLag;
float4 _FurWind;    // xyz: wind, direction * bend share
float4 _FurDrag;    // xyz: inertia, direction * bend share
float _FurAmbient;  // always-on breeze, bend share

struct Input
{
    float2 uv_MainTex;
    float rootT;
    float4 color : COLOR;   // v51: the body albedo under this card's root
};

void vert(inout appdata_full v, out Input o)
{
    UNITY_INITIALIZE_OUTPUT(Input, o);
    float t = v.texcoord.y;
    o.rootT = t;
    float phase = v.texcoord1.x * 6.2832;
    float L = v.texcoord1.y * _FurWorldUnit;

    float3 wpos = mul(unity_ObjectToWorld, v.vertex).xyz;
    float3 n = UnityObjectToWorldNormal(v.normal);
    float3 across = normalize(UnityObjectToWorldDir(v.tangent.xyz));
    float3 along = normalize(cross(n, across) * v.tangent.w * unity_WorldTransformParams.w);

    float flex = saturate((t - _RootLock) / (1 - _RootLock));
    flex *= flex;
    float time = _Time.y;
    // Every card is its own lock: its own share of the gust, pace and heading.
    float h1 = frac(v.texcoord1.x * 7.13), h2 = frac(v.texcoord1.x * 13.71 + .37);
    float amp = .6 + .8 * h1;
    float pace = _Sway * (.8 + .45 * h2);
    // Gusts run downwind across the body, so neighbouring locks lift one after another.
    float windLen = length(_FurWind.xyz);
    float3 windDir = windLen > 1e-5 ? _FurWind.xyz / windLen : float3(1, 0, 0);
    float travel = dot(wpos, windDir) / max(_FurWorldUnit, 1e-4) * 3.2;
    float sway = sin(time * pace * 6.2832 + phase - t * _WaveLag - travel);
    float flutter = sin(time * _Flutter * (.85 + .3 * h1) * 6.2832 + phase * 3.1 - t * _WaveLag * 2.3);
    // Turn the gust a little about the strand, differently for each lock.
    float turn = (h2 - .5) * 1.5;
    float3 wind = _FurWind.xyz * cos(turn) + cross(along, _FurWind.xyz) * sin(turn);
    float3 push = wind * amp * (.2 + .8 * (.5 + .5 * sway)) + _FurDrag.xyz * (.75 + .5 * h1);
    // The breeze differs per card so neighbours never move as one sheet.
    push += (across * sin(time * .9 * 6.2832 + phase) + n * .45 * sin(time * 1.3 * 6.2832 + phase * 1.7)) * _FurAmbient * amp;
    // Only the part of the push across the strand bends it.
    push -= along * dot(push, along);
    float strength = length(push);
    float3 disp = push * L * flex;
    disp += (across * .16 + n * .07) * flutter * strength * L * flex;
    // Keep the arc length: a point swung sideways by d at arc distance s from
    // the root comes back toward the root by about d^2 / 2s.
    float arc = max(t * L, 1e-4);
    disp -= along * min(dot(disp, disp) / (2 * arc), .6 * arc);
    v.vertex.xyz = mul(unity_WorldToObject, float4(wpos + disp, 1)).xyz;
}

half4 LightingFur(SurfaceOutput s, half3 lightDir, half3 viewDir, half atten)
{
    // The cards lie along the body and share its outward normals, so they take the light
    // like the skin beneath: lit side lit, shadow side dark, with only a soft wrap
    // (v51: lighting both faces made the fur a step paler than the body).
    half ndl = dot(s.Normal, lightDir);
    half diff = saturate((ndl + _Wrap) / (1 + _Wrap));
    half3 h = normalize(lightDir + viewDir);
    half sheen = pow(saturate(abs(dot(s.Normal, h))), 18) * _Sheen;
    half4 c;
    c.rgb = (s.Albedo * diff + sheen * s.Alpha) * _LightColor0.rgb * atten;
    c.a = s.Alpha;
    return c;
}

fixed4 FurSample(Input IN)
{
    fixed4 c = tex2D(_MainTex, IN.uv_MainTex) * _Color;
    // The atlas is neutral around 0.5: 0.5 is the body's own colour; _StrandContrast keeps
    // the lighter and darker strands from drifting far from it.
    c.rgb = IN.color.rgb * lerp(1, c.rgb * 2, _StrandContrast);
    // Roots sit in the body's shadow; the tips catch the light.
    c.rgb *= lerp(1 - _RootShade, 1, smoothstep(0, .55, IN.rootT));
    return c;
}
