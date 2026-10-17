using System.Collections.Generic;
using UnityEngine;

/// One oval light shield that wraps a body whole (user, 2026-10-05: 要一个椭圆的光盾，
/// 会有流光闪烁；2 个盾同时要做出差异). Reworked 2026-10-06 after "仍然太古板",
/// taking the rhythm of Effekseer's official CC0 samples (tktk01 hozyo1/hozyo2,
/// MAGICALxSPIRAL MagicArea) but rebuilt here so every part fits the body:
///  Fortify (amber): reworked again 2026-10-07 (user: 要流动，是能量盾，不会那么明显
///   固定在那; 要和Q1一样). Fixed shards read as plates hung on the body, so it is now
///   six amber energy currents that whirl in from outside and keep racing round the
///   body, half climbing and half sinking so they cross in front (each well under
///   one turn), and every current carries a few crystal shards lying along the flow.
///   The shards still read as a crystal shell (thin strands alone: 太细了，不像盾了;
///   broad veils read as fire), but none of them ever stays in one place. Small
///   flecks tumble off the leading edges.
///   It ends by flinging the currents and a spray of flecks outwards.
///  Ward (blue-white): 2–3 uneven ribbons spiral up the body (each under 0.7 turn).
///   It never shows a whole oval (user, 2026-10-07: 还是有很短瞬间出来这个，不好，
///   要保持光带的状态): a periodic vortex and every hit make the ribbons flare and
///   throw sparks instead, and a break scatters pale shards.
/// Neither preset draws a whole oval membrane any more (user, 2026-10-07: Q12 按 Q1
/// 的做法去掉); only currents, ribbons, flecks and sparks.
/// The root follows the body centre with identity rotation and unit world scale, so
/// the parts mesh is built in world units around the centre.
public sealed class OvalLightShield : MonoBehaviour
{
    public enum Preset { Ward, Fortify }

    const float Gather = .40f;       // fortify: the currents have closed in by now
    const float ShatterTime = .5f;   // a broken shield's pieces fly apart over this long
    const float SwirlTime = .32f;    // ward pulse: vortex gathers before the ribbons flare
    const int ArcPoints = 22, RibbonPoints = 26, CurrentPoints = 24, Currents = 6, Riders = 4;

    /// A small crystal piece in flight: shed from a current's head, chipped off by a
    /// hit, or one of the pieces a shield breaks into.
    sealed class Fleck
    {
        public Vector3 p, vel, axis, u, v, n; public float born, life, size, spin, seed, heat, glow, gravity, drag;
        public Vector2[] outline; public float[] shade;
    }
    sealed class Ribbon { public float born, dur, span, a0, sign, spin, rScale, length, width, seed, lastSpark; }
    /// Fortify energy current: a short helical strand racing round the shell while it
    /// climbs or sinks; rising and sinking strands cross in front of the body.
    sealed class Current
    {
        public float born, dur, a0, sign, rise, speed, climb, h0, span, length, rScale, width, seed, lastFleck;
        // Shards riding the current: where along it (0 tail .. 1 head), size, tilt.
        public float[] at, size, tilt, wob; public Vector2[][] outline; public float[][] shade;
    }
    sealed class Spark { public Vector3 p, vel; public float born, life, size, cross, drag, bright; }

    static Shader partShader; static Texture2D noise;

    Transform body; Preset preset;
    Material parts; Mesh partMesh;
    float born, life = -1f, opacity = 1f, seed, hitAt = -100f, pulseAt = -100f, nextPulse, shatterAt = -1f, hitSeen = -100f;
    bool closed, pulseBurst;
    Vector3 centre; float rx = .5f, ry = 1f, lastW = .6f, lastH = 1f;
    System.Random rng;
    readonly List<Fleck> flecks = new List<Fleck>();
    readonly List<Ribbon> ribbons = new List<Ribbon>();
    readonly List<Current> currents = new List<Current>();
    readonly List<Spark> sparks = new List<Spark>();
    readonly List<Vector3> vs = new List<Vector3>(); readonly List<Color> cs = new List<Color>();
    readonly List<Vector2> uvA = new List<Vector2>(), uvB = new List<Vector2>(), uvC = new List<Vector2>();
    readonly List<int> tris = new List<int>();
    const int Arcs = 6;
    readonly float[] arcA0 = new float[Arcs], arcSpan = new float[Arcs], arcR = new float[Arcs];
    readonly Vector3[] sp = new Vector3[32], sx = new Vector3[32]; readonly float[] sw = new float[32], sa = new float[32];

    public static OvalLightShield Attach(Transform bodyRoot, Preset preset)
    {
        var go = new GameObject(preset == Preset.Ward ? "Oval light shield · ward" : "Oval light shield · fortify");
        go.transform.SetParent(bodyRoot, false);
        var s = go.AddComponent<OvalLightShield>();
        s.body = bodyRoot; s.preset = preset; s.Build();
        return s;
    }

    /// A shield that lives `seconds`, gathering in and shattering out on its own.
    public static OvalLightShield Flash(Transform bodyRoot, Preset preset, float seconds)
    {
        if (!bodyRoot) return null;
        foreach (var old in bodyRoot.GetComponentsInChildren<OvalLightShield>())
            if (old.preset == preset && old.life > 0f && old.shatterAt < 0f)
            {
                // Still standing: hold it longer instead of gathering it again.
                old.life = Mathf.Max(old.life, Time.time - old.born + seconds);
                return old;
            }
        var s = Attach(bodyRoot, preset); s.life = seconds; return s;
    }

    public void SetOpacity(float value) { opacity = value; }
    public void Impact() { hitAt = Time.time; }
    public void ImpactAfter(float delay) { CancelInvoke(nameof(Impact)); Invoke(nameof(Impact), delay); }
    public void Break() { Shatter(); }

    float R(float a, float b) => a + (b - a) * (float)rng.NextDouble();
    static float Smooth(float e0, float e1, float x) { float t = Mathf.Clamp01((x - e0) / (e1 - e0)); return t * t * (3f - 2f * t); }
    static float Envelope(float x, float attack, float decay) => x < 0f ? 0f : x < attack ? x / attack : Mathf.Exp(-(x - attack) / decay);

    void Build()
    {
        if (!partShader) partShader = Resources.Load<Shader>("Shaders/OvalShieldParts");
        if (!noise) noise = Resources.Load<Texture2D>("SpellSpectacle20260926/SpectacleNoise");
        seed = Random.Range(0f, 6.28f); born = Time.time;
        rng = new System.Random(Random.Range(1, int.MaxValue));

        var p = new GameObject("parts"); p.transform.SetParent(transform, false);
        partMesh = new Mesh { name = "Oval shield parts" }; partMesh.MarkDynamic();
        p.AddComponent<MeshFilter>().sharedMesh = partMesh;
        var pr = p.AddComponent<MeshRenderer>(); parts = new Material(partShader); pr.sharedMaterial = parts; Quiet(pr);
        parts.SetTexture("_Noise", noise);

        if (preset == Preset.Ward)
        {
            // Cool, calm: blue-white.
            parts.SetColor("_Tint", new Color(.36f, .76f, 1f)); parts.SetColor("_Deep", new Color(.10f, .28f, .86f));
            parts.SetColor("_Edge", new Color(.62f, .88f, 1f)); parts.SetColor("_Hot", new Color(.93f, .98f, 1f));
        }
        else
        {
            // Hot: amber crystal.
            parts.SetColor("_Tint", new Color(1f, .70f, .22f)); parts.SetColor("_Deep", new Color(.78f, .28f, .04f));
            parts.SetColor("_Edge", new Color(1f, .82f, .42f)); parts.SetColor("_Hot", new Color(1f, .97f, .86f));
        }
        Fit(true); Place();
        if (preset == Preset.Ward)
        {
            for (int i = 0; i < 3; i++) ribbons.Add(NewRibbon(Time.time - i * 1.05f - R(0f, .4f)));
            nextPulse = Time.time + R(.9f, 1.6f);
        }
        else for (int i = 0; i < Currents; i++) currents.Add(NewCurrent(i, Time.time, i / (float)Currents * .6f + R(0f, .08f)));
    }

    static void Quiet(Renderer r) { r.shadowCastingMode = UnityEngine.Rendering.ShadowCastingMode.Off; r.receiveShadows = false; }

    // The body's renderers, gathered once a second: the shield still follows the body every
    // frame, but no longer walks its whole hierarchy every frame (2026-10-17, iPhone 13: 好卡).
    readonly List<Renderer> fitRenderers = new List<Renderer>();
    float nextFitGather;

    void Fit(bool force)
    {
        if (!body) return;
        if (force || Time.unscaledTime >= nextFitGather)
        {
            nextFitGather = Time.unscaledTime + 1f;
            fitRenderers.Clear();
            foreach (var r in body.GetComponentsInChildren<Renderer>())
                if (r && !r.GetComponentInParent<OvalLightShield>() && (r is SkinnedMeshRenderer || r is MeshRenderer)) fitRenderers.Add(r);
        }
        bool any = false; var b = new Bounds();
        foreach (var r in fitRenderers)
        {
            if (!r || !r.gameObject.activeInHierarchy) continue;   // as before: disabled renderers still count
            if (!any) { b = r.bounds; any = true; } else b.Encapsulate(r.bounds);
        }
        if (any && b.size.y > .3f)
        {
            // Width from the torso, not from an outstretched sword: never wider than
            // 55% of the body height (user, 2026-10-05: Q1 的这个太大了).
            centre = b.center; lastH = b.extents.y;
            lastW = Mathf.Min(Mathf.Max(b.extents.x, b.extents.z), lastH * .55f);
        }
        else if (force) centre = body.position + Vector3.up * 1f;
        rx = lastW * 1.08f + .06f; ry = lastH * 1.04f + .06f;
        // The fortify shell sits just outside the ward so both read when they overlap.
        if (preset == Preset.Fortify) { rx *= 1.08f; ry *= 1.04f; }
    }

    void Place()
    {
        transform.position = centre + Vector3.up * .04f;
        transform.rotation = Quaternion.identity;
        var ps = transform.parent ? transform.parent.lossyScale : Vector3.one;
        transform.localScale = new Vector3(1f / Mathf.Max(.001f, ps.x), 1f / Mathf.Max(.001f, ps.y), 1f / Mathf.Max(.001f, ps.z));
    }

    Vector3 Surface(Vector3 dir, float k = 1f) => new Vector3(dir.x * rx, dir.y * ry, dir.z * rx) * k;
    Vector3 Normal(Vector3 p) => new Vector3(p.x / (rx * rx), p.y / (ry * ry), p.z / (rx * rx)).normalized;
    static void Frame(Vector3 n, float twist, out Vector3 u, out Vector3 v)
    {
        u = Vector3.Cross(Vector3.up, n); if (u.sqrMagnitude < 1e-4f) u = Vector3.Cross(Vector3.right, n);
        u.Normalize(); v = Vector3.Cross(n, u);
        float c = Mathf.Cos(twist), s = Mathf.Sin(twist);
        var u2 = u * c + v * s; v = v * c - u * s; u = u2;
    }

    /// Strands alternate between climbing one way round and sinking the other, so
    /// they keep crossing in front of the body like a weave that is never still.
    /// Unlike the ward's two or three slow rising ribbons these are many, fast and
    /// run both ways.
    Current NewCurrent(int i, float bornAt, float phase)
    {
        float rise = i % 2 == 0 ? 1f : -1f;
        var c = new Current
        {
            born = bornAt, dur = R(1.5f, 2.1f), a0 = R(0f, 6.2832f),
            sign = -rise * (rng.NextDouble() < .8 ? 1f : -1f), rise = rise,
            speed = R(2.0f, 3.0f), climb = R(.4f, .7f), h0 = -rise * R(.3f, .8f),
            span = R(.34f, .5f), length = R(.5f, .85f),
            rScale = R(1.02f, 1.1f), width = ry * R(.085f, .12f), seed = R(0f, 10f),
            at = new float[Riders], size = new float[Riders], tilt = new float[Riders], wob = new float[Riders],
            outline = new Vector2[Riders][], shade = new float[Riders][],
        };
        for (int k = 0; k < Riders; k++)
        {
            c.at[k] = Mathf.Clamp01((k + R(.25f, .75f)) / Riders * .82f + .12f);
            c.size[k] = ry * R(.085f, .17f); c.tilt[k] = R(-.45f, .45f); c.wob[k] = R(0f, 6.28f);
            int corners = rng.Next(5, 8); float aspect = R(1.3f, 2.0f), a0 = R(0f, 6.2832f);
            c.outline[k] = new Vector2[corners]; c.shade[k] = new float[corners];
            for (int j = 0; j < corners; j++)
            {
                float ang = a0 + (j + R(-.3f, .3f)) / corners * 6.2832f, rad = R(.6f, 1f);
                c.outline[k][j] = new Vector2(Mathf.Cos(ang) * rad * aspect, Mathf.Sin(ang) * rad);
                c.shade[k][j] = R(0f, 1f);
            }
        }
        c.born -= c.dur * phase;
        return c;
    }

    Fleck AddFleck(Vector3 p, Vector3 vel, Vector3 along, float size, float lifeSpan, float heat, float gravity, float drag, int corners, float aspect)
    {
        if (flecks.Count > 70) return null;
        var f = new Fleck { p = p, vel = vel, born = Time.time, life = lifeSpan, size = size, heat = heat, gravity = gravity, drag = drag, seed = R(0f, 1f) };
        f.n = Normal(p);
        Frame(f.n, R(0f, 6.2832f), out f.u, out f.v);
        if (along.sqrMagnitude > 1e-6f)
        {
            // Slivers lie along the flow they were shed from.
            var a = (along - f.n * Vector3.Dot(along, f.n)).normalized;
            if (a.sqrMagnitude > .5f) { f.u = a; f.v = Vector3.Cross(f.n, a); }
        }
        f.axis = new Vector3(R(-1f, 1f), R(-1f, 1f), R(-1f, 1f)).normalized;
        f.spin = R(4f, 11f) * (rng.NextDouble() < .5 ? -1f : 1f);
        f.outline = new Vector2[corners]; f.shade = new float[corners];
        float a0 = R(0f, 6.2832f);
        for (int j = 0; j < corners; j++)
        {
            float ang = a0 + (j + R(-.3f, .3f)) / corners * 6.2832f, rad = R(.6f, 1f);
            f.outline[j] = new Vector2(Mathf.Cos(ang) * rad * aspect, Mathf.Sin(ang) * rad);
            f.shade[j] = R(0f, 1f);
        }
        flecks.Add(f);
        return f;
    }

    Ribbon NewRibbon(float bornAt) => new Ribbon
    {
        born = bornAt, dur = R(2.5f, 3.5f), span = R(.40f, .66f), a0 = R(0f, Mathf.PI * 2f),
        sign = rng.NextDouble() < .7 ? 1f : -1f, spin = R(.5f, 1f), rScale = R(1.03f, 1.14f),
        length = ry * R(.6f, 1.05f), width = ry * R(.10f, .16f), seed = R(0f, 10f),
    };

    void Shatter()
    {
        if (shatterAt >= 0f) return;
        shatterAt = Time.time;
        bool ward = preset == Preset.Ward;
        // The ward breaks into a few pale pieces; the fortify flings a spray of small ones.
        int pieces = ward ? 12 : 16;
        for (int i = 0; i < pieces; i++)
        {
            var d = new Vector3(R(-1f, 1f), R(-.8f, .9f), R(-1f, 1f)).normalized;
            var at = Surface(d); var n = Normal(at);
            var vel = n * R(1.3f, 2.4f) * ry + Vector3.up * R(.2f, .9f) + new Vector3(R(-.4f, .4f), R(-.2f, .3f), R(-.4f, .4f));
            if (ward) AddFleck(at, vel, Vector3.zero, ry * R(.12f, .24f), ShatterTime, .9f, -5f, 0f, rng.Next(4, 7), 1.5f);
            else AddFleck(at, vel, Vector3.zero, ry * R(.05f, .11f), ShatterTime, .9f, -5f, 0f, rng.Next(4, 7), R(1.4f, 2.2f));
        }
        for (int i = 0; i < 16; i++)
        {
            var d = new Vector3(R(-1f, 1f), R(-.6f, 1f), R(-1f, 1f)).normalized; var at = Surface(d);
            AddSpark(at, Normal(at) * ry * R(1f, 2.4f), R(.3f, .55f), ry * R(.05f, .1f), rng.NextDouble() < .4 ? 1f : 0f, 3f, 1.2f);
        }
    }

    void AddSpark(Vector3 p, Vector3 vel, float lifeSpan, float size, float cross, float drag, float bright)
    {
        if (sparks.Count > 90) return;
        sparks.Add(new Spark { p = p, vel = vel, born = Time.time, life = lifeSpan, size = size, cross = cross, drag = drag, bright = bright });
    }

    void LateUpdate()
    {
        if (!parts) return;
        float now = Time.time, t = now - born, dt = Mathf.Min(Time.deltaTime, .05f);
        if (life > 0f && shatterAt < 0f && t > life - ShatterTime) Shatter();
        if (shatterAt >= 0f && now - shatterAt > ShatterTime + .05f) { Destroy(gameObject); return; }
        Fit(false); Place();
        var cam = Camera.main;
        Vector3 toCam = cam ? (cam.transform.position - transform.position).normalized : Vector3.back;
        Vector3 camR = cam ? cam.transform.right : Vector3.right, camU = cam ? cam.transform.up : Vector3.up;
        float hit = Envelope(now - hitAt, .05f, .38f);

        vs.Clear(); cs.Clear(); uvA.Clear(); uvB.Clear(); uvC.Clear(); tris.Clear();
        if (preset == Preset.Fortify) DrawFortify(t, now, hit, toCam); else DrawWard(t, now, hit, toCam, camR, camU);
        DrawFlecks(now, dt, toCam);
        DrawSparks(now, dt, camR, camU);
        partMesh.Clear();
        partMesh.SetVertices(vs); partMesh.SetColors(cs);
        partMesh.SetUVs(0, uvA); partMesh.SetUVs(1, uvB); partMesh.SetUVs(2, uvC);
        partMesh.SetTriangles(tris, 0);
        partMesh.bounds = new Bounds(Vector3.zero, Vector3.one * (ry * 8f + 2f));
        parts.SetFloat("_Age", t);
    }

    void DrawFortify(float t, float now, float hit, Vector3 toCam)
    {
        float shatterU = shatterAt >= 0f ? Mathf.Clamp01((now - shatterAt) / ShatterTime) : 0f;
        // Closing in: the currents start wide and tighten onto the body.
        float gather = Smooth(0f, Gather, t);
        if (!closed && t >= Gather)
        {
            closed = true;
            for (int i = 0; i < 14; i++)
            {
                var d = new Vector3(R(-1f, 1f), R(-.8f, .9f), R(-1f, 1f)); d += toCam * .8f; d.Normalize();
                var at = Surface(d); AddSpark(at, Normal(at) * ry * R(.8f, 1.8f), R(.35f, .6f), ry * R(.05f, .1f), rng.NextDouble() < .45 ? 1f : 0f, 3f, 1.3f);
            }
        }
        if (hitAt > hitSeen && shatterAt < 0f && now >= hitAt && closed)
        {
            // A hit makes every current flare and chips flecks and sparks off the front.
            hitSeen = hitAt;
            for (int i = 0; i < 8; i++)
            {
                var d = (toCam + new Vector3(R(-.7f, .7f), R(-.5f, .7f), R(-.7f, .7f))).normalized;
                var at = Surface(d);
                AddSpark(at, (Normal(at) + Random.insideUnitSphere * .5f) * ry * R(.8f, 1.6f), R(.25f, .45f), ry * R(.04f, .09f), rng.NextDouble() < .5 ? 1f : 0f, 3.5f, 1.25f);
                if (i < 6) AddFleck(at, (Normal(at) + Random.insideUnitSphere * .6f) * ry * R(.9f, 1.7f), Vector3.zero, ry * R(.035f, .07f), R(.35f, .55f), 1f, -3f, 1.5f, rng.Next(4, 6), R(1.4f, 2.2f));
            }
        }
        float flare = hit;
        float scaleOut = Mathf.Lerp(1.35f, 1f, gather) * (1f + 1.6f * shatterU);
        for (int i = 0; i < currents.Count; i++)
        {
            var c = currents[i];
            float age = now - c.born;
            if (age > c.dur && shatterAt < 0f) { c = NewCurrent(i, now, R(0f, .05f)); currents[i] = c; age = now - c.born; }
            if (age < 0f) continue;
            float a = Mathf.Clamp01(age / c.dur);
            float env = Smooth(0f, .14f, a) * (1f - Smooth(.72f, 1f, a)) * opacity * Smooth(0f, .6f, gather + .3f)
                * (1f - Smooth(.1f, 1f, shatterU)) * (1f + 1.1f * flare);
            if (env <= .003f) continue;
            // Faster while closing in, then a steady sweep.
            float head = c.a0 + c.sign * (c.speed * age + (1f - gather) * 2.4f);
            float span = c.span * 6.2832f * Mathf.Lerp(.55f, 1f, Smooth(0f, .3f, a));
            float headH = c.h0 + c.rise * c.climb * age;
            for (int j = 0; j < CurrentPoints; j++)
            {
                float uu = j / (CurrentPoints - 1f);
                float th = head - c.sign * span * (1f - uu);
                float hr = headH - c.rise * c.length * (1f - uu);
                float rad = rx * c.rScale * scaleOut * Mathf.Max(Mathf.Sqrt(Mathf.Max(0f, 1f - hr * hr)), .2f);
                sp[j] = new Vector3(rad * Mathf.Sin(th), hr * ry, rad * Mathf.Cos(th));
                sw[j] = c.width * Mathf.Pow(Mathf.Max(0f, Mathf.Sin(Mathf.PI * Mathf.Lerp(.08f, .92f, uu))), .8f) * (.45f + .55f * uu) * (1f + .5f * flare);
                // Behind the body the current dims, so it reads as wrapping round.
                float facing = Mathf.Lerp(.28f, 1f, Mathf.Clamp01(Vector3.Dot(Normal(sp[j]), toCam) * .85f + .55f));
                float pole = 1f - Smooth(.8f, 1f, Mathf.Abs(hr));
                sa[j] = env * facing * pole;
            }
            for (int j = 0; j < CurrentPoints; j++)
            {
                var tan = sp[Mathf.Min(j + 1, CurrentPoints - 1)] - sp[Mathf.Max(j - 1, 0)];
                sx[j] = Vector3.Cross(tan, Normal(sp[j])).normalized;
            }
            Strip(CurrentPoints, c.seed);
            // Shards ride the current, lying along the flow and rocking a little.
            for (int k = 0; k < Riders; k++)
            {
                float fj = c.at[k] * (CurrentPoints - 1); int j0 = Mathf.Min((int)fj, CurrentPoints - 2); float fr = fj - j0;
                var p = Vector3.Lerp(sp[j0], sp[j0 + 1], fr);
                var n = Normal(p); var along = sp[j0 + 1] - sp[j0];
                var u = (along - n * Vector3.Dot(along, n)).normalized; var v = Vector3.Cross(n, u);
                float tw = c.tilt[k] + .25f * Mathf.Sin(now * 3.1f + c.wob[k]);
                float cs = Mathf.Cos(tw), sn = Mathf.Sin(tw); var u2 = u * cs + v * sn; v = v * cs - u * sn; u = u2;
                // Clamp: the current's own alpha is pushed past 1 by a hit, which would
                // blow a premultiplied crystal out to a white slab.
                float alpha = Mathf.Min(1f, Mathf.Lerp(sa[j0], sa[j0 + 1], fr) * 1.1f);
                float wave = Mathf.Pow(.5f + .5f * Mathf.Sin(c.at[k] * 7f - now * 6f + c.seed), 8f);
                Crystal(p + n * ry * .02f, u, v, n, c.size[k] * Mathf.Lerp(.7f, 1f, Smooth(0f, .2f, a)), c.outline[k], c.shade[k], alpha,
                    .22f + wave * .6f + flare * .4f + (1f - gather) * .35f, c.seed + k * .17f);
            }
            // The leading edge sheds tumbling crystal flecks and the odd glint.
            if (env > .35f && shatterAt < 0f && now - c.lastFleck > R(.1f, .17f))
            {
                c.lastFleck = now;
                var hp = sp[CurrentPoints - 2];
                var tan = (sp[CurrentPoints - 1] - sp[CurrentPoints - 3]).normalized;
                var n = Normal(hp);
                var shed = AddFleck(hp, tan * ry * R(.25f, .6f) + n * ry * R(.15f, .45f) + Random.insideUnitSphere * .1f, tan,
                    ry * R(.03f, .06f), R(.38f, .62f), .8f, -.8f, 1.8f, rng.Next(4, 6), R(1.5f, 2.4f));
                if (shed != null) shed.glow = .2f;
                if (rng.NextDouble() < .35) AddSpark(hp, n * .2f + Vector3.up * R(.1f, .3f), R(.3f, .5f), ry * R(.03f, .06f), rng.NextDouble() < .5 ? 1f : 0f, 1.5f, 1f);
            }
        }
    }

    void DrawFlecks(float now, float dt, Vector3 toCam)
    {
        for (int i = flecks.Count - 1; i >= 0; i--)
        {
            var f = flecks[i]; float tau = now - f.born;
            if (tau > f.life) { flecks.RemoveAt(i); continue; }
            f.vel += Vector3.up * f.gravity * dt; f.vel *= Mathf.Max(0f, 1f - f.drag * dt); f.p += f.vel * dt;
            var q = Quaternion.AngleAxis(f.spin * tau * Mathf.Rad2Deg, f.axis);
            Vector3 u = q * f.u, v = q * f.v, n = q * f.n;
            float alpha = opacity * (1f - Smooth(f.life * .3f, f.life, tau));
            float size = f.size * (1f - .45f * Mathf.Clamp01(tau / f.life));
            float heat = Mathf.Exp(-tau / .12f) * f.heat + f.glow;
            // Pieces on the far side stay faint so the shell keeps its depth.
            alpha *= Mathf.Lerp(.35f, 1f, Mathf.Clamp01(Vector3.Dot(n, toCam) * .6f + .6f));
            if (alpha <= .003f) continue;
            Crystal(f.p, u, v, n, size, f.outline, f.shade, alpha, heat, f.seed);
        }
    }

    /// One faceted crystal: a fan of triangles from a slightly raised apex.
    void Crystal(Vector3 p, Vector3 u, Vector3 v, Vector3 n, float size, Vector2[] outline, float[] shade, float alpha, float heat, float seed)
    {
        if (alpha <= .003f) return;
        var c = new Color(1f, 1f, 1f, alpha);
        var apex = p + n * size * .14f;
        int k = outline.Length;
        for (int j = 0; j < k; j++)
        {
            var a = outline[j]; var b = outline[(j + 1) % k];
            int i0 = vs.Count; var sh = new Vector2(shade[j], 0f); var hb = new Vector2(heat, 0f);
            Vert(apex, c, new Vector2(0f, seed), hb, sh);
            Vert(p + (u * a.x + v * a.y) * size, c, new Vector2(1f, seed), hb, sh);
            Vert(p + (u * b.x + v * b.y) * size, c, new Vector2(1f, seed), hb, sh);
            tris.Add(i0); tris.Add(i0 + 1); tris.Add(i0 + 2);
        }
    }

    void DrawWard(float t, float now, float hit, Vector3 toCam, Vector3 camR, Vector3 camU)
    {
        float shatterU = shatterAt >= 0f ? Mathf.Clamp01((now - shatterAt) / ShatterTime) : 0f;
        if (shatterAt < 0f && now >= nextPulse)
        {
            pulseAt = now; nextPulse = now + R(3.4f, 4.8f); pulseBurst = false;
            for (int k = 0; k < Arcs; k++) { arcA0[k] = k * 6.2832f / Arcs + R(-.4f, .4f); arcSpan[k] = R(.22f, .36f); arcR[k] = R(.62f, 1.05f); }
            for (int i = 0; i < 12; i++)
            {
                float a = R(0f, 6.2832f), r = R(1.05f, 1.3f);
                var at = (camR * Mathf.Cos(a) * rx + camU * Mathf.Sin(a) * ry) * r;
                var tangent = (-camR * Mathf.Sin(a) * rx + camU * Mathf.Cos(a) * ry) * r;
                AddSpark(at, (-at * .75f + tangent * .9f) / SwirlTime, SwirlTime + .05f, ry * R(.04f, .08f), 0f, 0f, 1.1f);
            }
        }
        float ps = now - pulseAt;
        if (ps >= 0f && ps < SwirlTime && shatterAt < 0f)
        {
            // The vortex: six short, uneven spiral arcs whirl in onto the chest (hozyo1).
            float s = ps / SwirlTime, e = s * s;
            float env = Smooth(0f, .25f, s) * (1f - Smooth(.85f, 1f, s)) * opacity;
            for (int k = 0; k < Arcs; k++)
            {
                float rot = arcA0[k] + s * 4.2f, rad = Mathf.Lerp(1.3f, .55f, e) * arcR[k];
                for (int j = 0; j < ArcPoints; j++)
                {
                    float uu = j / (ArcPoints - 1f), th = rot - arcSpan[k] * uu * 6.2832f;
                    float radial = rad * (1f + .35f * (1f - uu));
                    sp[j] = camR * Mathf.Cos(th) * (rx * .55f + ry * .45f) * radial + camU * Mathf.Sin(th) * ry * .8f * radial + Vector3.up * ry * .12f + toCam * rx * .3f;
                    sw[j] = Mathf.Lerp(.11f, .05f, e) * ry * Mathf.Pow(Mathf.Max(0f, Mathf.Sin(Mathf.PI * uu)), .7f) * (.5f + .5f * uu);
                    sa[j] = env;
                }
                for (int j = 0; j < ArcPoints; j++)
                {
                    var tan = sp[Mathf.Min(j + 1, ArcPoints - 1)] - sp[Mathf.Max(j - 1, 0)];
                    sx[j] = Vector3.Cross(tan, toCam).normalized;
                }
                Strip(ArcPoints, k * 3.1f + seed);
            }
        }
        // The vortex and hits make the ribbons flare.
        float flare = Mathf.Max(Envelope(ps - SwirlTime, .06f, .45f), hit * .8f);
        if (!pulseBurst && ps >= SwirlTime && shatterAt < 0f)
        {
            pulseBurst = true;
            for (int i = 0; i < 12; i++)
            {
                var d = new Vector3(R(-1f, 1f), R(-.5f, .8f), R(-1f, 1f)); d += toCam * .6f; d.Normalize();
                var at = Surface(d, .7f);
                AddSpark(at, Normal(at) * ry * R(.6f, 1.4f), R(.3f, .55f), ry * R(.04f, .08f), rng.NextDouble() < .4 ? 1f : 0f, 3f, 1.1f);
            }
        }
        if (hitAt > hitSeen && shatterAt < 0f && now >= hitAt)
        {
            hitSeen = hitAt;
            for (int i = 0; i < 9; i++)
            {
                var d = (toCam + new Vector3(R(-.7f, .7f), R(-.5f, .7f), R(-.7f, .7f))).normalized;
                var at = Surface(d, .85f);
                AddSpark(at, (Normal(at) + Random.insideUnitSphere * .5f) * ry * R(.7f, 1.5f), R(.25f, .45f), ry * R(.04f, .08f), rng.NextDouble() < .5 ? 1f : 0f, 3.5f, 1.2f);
            }
        }

        // Two or three uneven ribbons spiral up the body, each under 0.7 turn (MagicArea).
        for (int i = 0; i < ribbons.Count; i++)
        {
            var r = ribbons[i];
            float age = now - r.born;
            if (age > r.dur && shatterAt < 0f) { r = NewRibbon(now + (i == 2 ? R(0f, 1.2f) : R(0f, .3f))); ribbons[i] = r; age = now - r.born; }
            if (age < 0f) continue;
            float a = Mathf.Clamp01(age / r.dur);
            float env = Smooth(0f, .18f, a) * (1f - Smooth(.72f, 1f, a)) * opacity * (1f - Smooth(.2f, 1f, shatterU)) * (1f + .9f * flare);
            if (env <= .003f) continue;
            float headH = Mathf.Lerp(-.75f, 1.2f, a) * ry;
            for (int j = 0; j < RibbonPoints; j++)
            {
                float uu = j / (RibbonPoints - 1f), h = headH - r.length * (1f - uu);
                float az = r.a0 + r.sign * (r.spin * age + r.span * uu * 6.2832f);
                float hr = h / (ry * 1.02f);
                float rad = rx * r.rScale * Mathf.Max(Mathf.Sqrt(Mathf.Max(0f, 1f - hr * hr)), .18f) * (1f + 2.2f * shatterU);
                sp[j] = new Vector3(rad * Mathf.Sin(az), h, rad * Mathf.Cos(az));
                sw[j] = r.width * Mathf.Pow(Mathf.Max(0f, Mathf.Sin(Mathf.PI * uu)), .7f) * (.6f + .4f * uu) * (1f + .4f * flare);
                float pole = 1f - Smooth(.82f, 1f, Mathf.Abs(hr));
                float facing = Mathf.Lerp(.45f, 1f, Mathf.Clamp01(Vector3.Dot(Normal(sp[j]), toCam) * .8f + .6f));
                sa[j] = env * pole * facing;
            }
            for (int j = 0; j < RibbonPoints; j++)
            {
                var tan = sp[Mathf.Min(j + 1, RibbonPoints - 1)] - sp[Mathf.Max(j - 1, 0)];
                sx[j] = Vector3.Cross(tan, Normal(sp[j])).normalized;
            }
            Strip(RibbonPoints, r.seed);
            if (env > .3f && now - r.lastSpark > .09f && shatterAt < 0f)
            {
                r.lastSpark = now;
                var head = sp[RibbonPoints - 2];
                AddSpark(head, Normal(head) * .25f + Vector3.up * R(.2f, .45f) + Random.insideUnitSphere * .12f, R(.5f, .8f), ry * R(.03f, .06f), rng.NextDouble() < .25 ? 1f : 0f, 1.5f, .9f);
            }
        }
    }

    void Strip(int n, float flowSeed)
    {
        int b = vs.Count;
        for (int j = 0; j < n; j++)
        {
            float uu = j / (n - 1f); var c = new Color(1f, 1f, 1f, sa[j]);
            Vert(sp[j] - sx[j] * sw[j], c, new Vector2(uu, 0f), new Vector2(flowSeed, 1f), Vector2.zero);
            Vert(sp[j] + sx[j] * sw[j], c, new Vector2(uu, 1f), new Vector2(flowSeed, 1f), Vector2.zero);
        }
        for (int j = 0; j < n - 1; j++)
        {
            int i = b + j * 2;
            tris.Add(i); tris.Add(i + 1); tris.Add(i + 2);
            tris.Add(i + 1); tris.Add(i + 3); tris.Add(i + 2);
        }
    }

    void DrawSparks(float now, float dt, Vector3 camR, Vector3 camU)
    {
        for (int i = sparks.Count - 1; i >= 0; i--)
        {
            var s = sparks[i]; float age = now - s.born;
            if (age > s.life) { sparks.RemoveAt(i); continue; }
            s.p += s.vel * dt; s.vel *= Mathf.Max(0f, 1f - s.drag * dt);
            float k = age / s.life, a = Smooth(0f, .12f, k) * (1f - Smooth(.55f, 1f, k)) * opacity * s.bright;
            float size = s.size * (1f - .4f * k);
            int b = vs.Count; var c = new Color(1f, 1f, 1f, a); var mode = new Vector2(s.cross, 2f);
            Vert(s.p + (-camR - camU) * size, c, new Vector2(0f, 0f), mode, Vector2.zero);
            Vert(s.p + (camR - camU) * size, c, new Vector2(1f, 0f), mode, Vector2.zero);
            Vert(s.p + (camR + camU) * size, c, new Vector2(1f, 1f), mode, Vector2.zero);
            Vert(s.p + (-camR + camU) * size, c, new Vector2(0f, 1f), mode, Vector2.zero);
            tris.Add(b); tris.Add(b + 1); tris.Add(b + 2); tris.Add(b); tris.Add(b + 2); tris.Add(b + 3);
        }
    }

    void Vert(Vector3 p, Color c, Vector2 a, Vector2 b, Vector2 d) { vs.Add(p); cs.Add(c); uvA.Add(a); uvB.Add(b); uvC.Add(d); }

    void OnDestroy()
    {
        if (parts) Destroy(parts);
        if (partMesh) Destroy(partMesh);
    }
}
