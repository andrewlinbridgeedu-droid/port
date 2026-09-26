Shader "Mindstone/Fool Sidestep Rift"
{
    Properties
    {
        _Beat("Skill beat", Float) = 0
        _Source("Source viewport", Vector) = (.28,.28,0,0)
        _Target("Target viewport", Vector) = (.72,.62,0,0)
        _Aspect("Viewport aspect", Float) = 1
        _RiftSeed("Rift seed", Float) = 0
        _InstanceWeight("Shared exposure weight", Float) = 1
    }
    SubShader
    {
        Tags { "Queue"="Overlay" "RenderType"="Transparent" }
        Cull Off
        ZWrite Off
        ZTest Always
        Blend One OneMinusSrcAlpha
        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma target 3.0
            #include "UnityCG.cginc"

            struct appdata { float4 vertex:POSITION; float2 uv:TEXCOORD0; };
            struct v2f { float4 pos:SV_POSITION; float2 uv:TEXCOORD0; };
            float _Beat, _Aspect, _RiftSeed;
            float4 _Source, _Target, _Secondary;
            float _HasSecondary, _InstanceWeight;

            v2f vert(appdata input)
            {
                v2f output;
                output.pos = UnityObjectToClipPos(input.vertex);
                output.uv = input.uv;
                return output;
            }

            float hash(float n)
            {
                return frac(sin(n * 127.1 + 19.7) * 43758.5453);
            }

            float noise(float2 p)
            {
                float2 cell = floor(p);
                float2 local = frac(p);
                local = local * local * (3.0 - 2.0 * local);
                float seed = cell.x + cell.y * 157.0 + _RiftSeed;
                return lerp(lerp(hash(seed), hash(seed + 1.0), local.x),
                    lerp(hash(seed + 157.0), hash(seed + 158.0), local.x), local.y);
            }

            float2 rotate(float2 p, float angle)
            {
                float c = cos(angle), s = sin(angle);
                return float2(c * p.x - s * p.y, s * p.x + c * p.y);
            }

            float cross2(float2 a, float2 b)
            {
                return a.x * b.y - a.y * b.x;
            }

            // A broken, displaced segment. The gaps and side-to-side wobble
            // are the rift identity during travel, rather than a projectile
            // or a radial card burst.
            float fracturedSegment(float2 samplePos, float2 start, float2 finish, float width, float seed)
            {
                float2 delta = finish - start;
                float lengthDelta = max(length(delta), .0001);
                float2 direction = delta / lengthDelta;
                float along = dot(samplePos - start, direction) / lengthDelta;
                float perpendicular = abs(cross2(samplePos - start, direction));
                float jag = (noise(float2(along * 17.0 + seed, _Beat * 4.0 + seed * 2.0)) - .5) * width * 1.35;
                float core = 1.0 - smoothstep(width * .18, width, abs(perpendicular - jag));
                float ends = smoothstep(0.0, .07, along) * (1.0 - smoothstep(.84, 1.0, along));
                float breaks = .52 + .48 * step(.18, noise(float2(along * 29.0 + seed, seed + 3.0)));
                return core * ends * breaks;
            }

            // A finite diagonal cut with chipped ends. Two of these crossing
            // at the target form the unmistakable impact body.
            float cut(float2 samplePos, float2 center, float2 direction, float halfLength, float width, float seed)
            {
                float2 delta = samplePos - center;
                float along = dot(delta, direction);
                float perpendicular = abs(cross2(delta, direction));
                float jag = (noise(float2(along * 24.0 + seed, _Beat * 3.0 + seed)) - .5) * width * .75;
                float body = 1.0 - smoothstep(width * .24, width * 1.18, abs(perpendicular - jag));
                float ends = 1.0 - smoothstep(halfLength * .68, halfLength, abs(along));
                return body * ends;
            }

            // Low-energy halo around a cut. Keeping this separate from the
            // bright core prevents the impact from becoming a solid white bar.
            float cutHalo(float2 samplePos, float2 center, float2 direction, float halfLength, float width, float seed)
            {
                float2 delta = samplePos - center;
                float along = dot(delta, direction);
                float perpendicular = abs(cross2(delta, direction));
                float jag = (noise(float2(along * 18.0 + seed, _Beat * 2.0 + seed)) - .5) * width * 1.4;
                float halo = 1.0 - smoothstep(width * .65, width * 5.0, abs(perpendicular - jag));
                float ends = 1.0 - smoothstep(halfLength * .70, halfLength, abs(along));
                return halo * ends;
            }

            float3 renderRift(float2 uv, float2 destination)
            {
                float2 aspect = float2(max(_Aspect, .01), 1.0);
                float2 source = _Source.xy * aspect;
                float2 target = destination * aspect;
                float2 samplePos = uv * aspect;
                float2 travel = target - source;
                float travelLength = max(length(travel), .0001);
                float2 direction = travel / travelLength;
                float2 normal = float2(-direction.y, direction.x);
                float time = _Beat;
                float3 cyan = float3(1.0, .56, .12);
                float3 violet = float3(.68, .16, 1.0);
                float3 white = float3(1.0, .89, .66);
                float3 colour = 0;

                // Two deliberately offset rifts travel along the same route.
                // Their independent heads make the motion read as a split step.
                float travelWindow = smoothstep(.025, .105, time) * (1.0 - smoothstep(.53, .625, time));
                float progress = smoothstep(.06, .56, time);
                float2 head = lerp(source, target, progress);
                for (int branch = 0; branch < 2; branch++)
                {
                    float side = branch == 0 ? 1.0 : -1.0;
                    float offset = (.038 + .014 * branch) * side;
                    float2 start = source + normal * offset;
                    float2 finish = head + normal * offset;
                    float fracture = fracturedSegment(samplePos, start, finish, .018 + .007 * branch, 3.0 + branch * 11.0);
                    colour += lerp(cyan, violet, branch) * fracture * travelWindow * (1.35 - branch * .15);
                    float2 headPoint = finish;
                    float headGlow = exp(-length(samplePos - headPoint) * (28.0 + branch * 5.0));
                    colour += white * headGlow * travelWindow * (.56 - branch * .08);
                }

                // A small opposing chevron appears before contact, showing the
                // step changing sides before the target is cut.
                float chevron = smoothstep(.27, .46, time) * (1.0 - smoothstep(.53, .63, time));
                float2 chevronPoint = head - direction * .035;
                float2 chevronA = rotate(direction, .72);
                float2 chevronB = rotate(direction, -.72);
                colour += cyan * cut(samplePos, chevronPoint + normal * .025, chevronA, .095, .011, 21.0) * chevron;
                colour += violet * cut(samplePos, chevronPoint - normal * .025, chevronB, .095, .011, 31.0) * chevron;

                // Contact tears two offset diagonal cuts across the target.
                float impact = smoothstep(.58, .622, time);
                float kick=smoothstep(.58,.622,time)*exp(-max(0,time-.622)*10);
                // The crossed cut is a compact target punctuation. It reaches
                // at most .30 in aspect space and fades shortly after contact.
                float impactFade = 1.0 - smoothstep(.82, 1.25, time);
                float cutLength = (.07 + impact * .133)*(1+kick*.85);
                float cutWidth = (.014 + impact * .011)*(1+kick*.42);
                float2 cutDirectionA = rotate(direction, .76);
                float2 cutDirectionB = rotate(direction, -.76);
                float crossedA = cut(samplePos, target + normal * .032, cutDirectionA, cutLength, cutWidth, 51.0);
                float crossedB = cut(samplePos, target - normal * .032, cutDirectionB, cutLength, cutWidth, 67.0);
                float haloA = cutHalo(samplePos, target + normal * .032, cutDirectionA, cutLength, cutWidth, 51.0);
                float haloB = cutHalo(samplePos, target - normal * .032, cutDirectionB, cutLength, cutWidth, 67.0);
                colour += cyan * crossedA * impact * impactFade * 1.55;
                colour += violet * crossedB * impact * impactFade * 1.55;
                colour += white * (crossedA + crossedB) * impact * impactFade * .43;
                colour += cyan * haloA * impact * impactFade * .33;
                colour += violet * haloB * impact * impactFade * .33;

                // The strike leaves a dark split and a reverse-going tail,
                // rather than the basic attack's expanding illustrated burst.
                float tail = fracturedSegment(samplePos,
                    target - direction * (.06 + impact * .20), target - direction * .015,
                    .010 + impact * .006, 103.0);
                colour += violet * tail * impact * impactFade * 1.03;
                float distance = length(samplePos - target);
                float ringRadius = .03 + impact * .105;
                float ringWidth = .008 + impact * .010;
                float ring = exp(-abs(distance - ringRadius) / ringWidth) * impact * impactFade;
                float ringBreak = .48 + .52 * step(.20, noise(float2(atan2(samplePos.y - target.y, samplePos.x - target.x) * 8.0, time * 3.0)));
                colour += cyan * ring * ringBreak * .84;
                float voidMask = exp(-distance * (18.0 - impact * 5.0)) * impact * impactFade;
                colour += float3(.05, .015, .12) * voidMask * .85;

                // Four broad shards peel from the crossing and fade with the
                // same tail. They reinforce the offset geometry at phone scale.
                for (int shard = 0; shard < 4; shard++)
                {
                    float angle = hash(shard * 9.0 + 4.0) * 6.28318;
                    float2 shardDirection = float2(cos(angle), sin(angle));
                    float2 shardCenter = target + shardDirection * (.055 + impact * (.08 + hash(shard + 8.0) * .12));
                    float shardGlow = cut(samplePos, shardCenter, shardDirection, .040 + impact * .052, .007, 81.0 + shard);
                    colour += lerp(violet, cyan, hash(shard + 14.0)) * shardGlow * impact * impactFade * .70;
                }

                // At the existing .58 beat (ContactTime in C#), the two cuts
                // shear open into four broad displaced slabs along their own axes.
                float contactAge=max(0,time-.58);
                float rupture=step(.58,time)*(1-smoothstep(.26,.52,contactAge));
                float opening=1-exp(-contactAge*30);
                float3 shear=0;
                for(int piece=0;piece<4;piece++) {
                    float sign=piece%2==0?-1:1;
                    float2 axis=piece<2?cutDirectionA:cutDirectionB;
                    float2 outward=float2(-axis.y,axis.x)*sign;
                    float2 center=target+outward*(.025+opening*(.075+hash(piece+42)*.065))+axis*sign*(.035+hash(piece+7)*.06);
                    float slab=cut(samplePos,center,axis,(.080+hash(piece+1)*.05)*(1+kick*.6),.018+hash(piece+9)*.008,121+piece*13);
                    shear+=lerp(cyan,violet,piece<2?0:1)*slab;
                }
                colour=colour*(1-rupture*.17)+shear*rupture*1.3;

                float alpha = smoothstep(.02, .08, time) * (1.0 - smoothstep(1.08, 1.65, time));
                return min(colour, 2.8) * alpha;
            }
            float4 frag(v2f input) : SV_Target {
                float3 c = renderRift(input.uv, _Target.xy);
                if (_HasSecondary > .5) c += renderRift(input.uv, _Secondary.xy);
                // Premultiplied, partly covering the ground under bright seams,
                // with hue-preserving roll-off: vivid cuts instead of a white field.
                float3 E = min(c, 3.2) * _InstanceWeight;
                float m = max(E.r, max(E.g, E.b));
                float lum = dot(E, float3(.299, .587, .114));
                E = max(0, lerp(lum.xxx, E, 1.3));
                float mm = max(max(E.r, max(E.g, E.b)), 1e-4);
                E *= (mm / (1 + mm * .55) * 1.55) / mm;
                return float4(E, saturate(m * .6) * .68);
            }
            ENDCG
        }
    }
    Fallback Off
}
