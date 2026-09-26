using System;
using System.Collections.Generic;
using UnityEngine;

/// <summary>
/// Presentation-only contact spectacle layered over every formal spell.
/// Native combat stays authoritative: a burst is spawned only when the
/// existing Unity contact callback fires for a cue registered by the same
/// cast entry. Nothing here settles damage, moves actors, delays callbacks
/// or touches the combat clock. Each identity picks its own body family,
/// colour ramp, particle matter and intensity tier; support and control
/// casts never receive a damage explosion.
/// </summary>
public sealed class SpellSpectacle20260926 : MonoBehaviour
{
    public enum Family { Crescent, Rising, Falling, Surge, Fan, Twin, Curtain, Tide }
    public enum Style { Light, Strike, Heavy, Support, Control }
    enum Mote { Spark = 0, Ember = 1, Shard = 2, Ink = 3, Petal = 4, Card = 5, Wisp = 6, Puff = 7 }

    sealed class Profile
    {
        public string id;
        public Family family, familyAlt;
        public Style style;
        public Color[] ramp;
        public Color line, core, wash, hot;
        public Mote mote, mote2;
        public bool column;
        public float scale = 1f, rampSpan = 1f;
    }

    sealed class Cue
    {
        public Profile profile;
        public Style style;
        public Func<Vector3> caster;
        public readonly List<Func<Vector3>> targets = new List<Func<Vector3>>();
        public readonly List<int> seeds = new List<int>();
        public float expiresAt, lastContact = float.NegativeInfinity;
        public int cast;
    }

    static SpellSpectacle20260926 instance;
    public static bool ReducedMotion;
    /// Editor diagnostics only: record the formal spells without this layer.
    public static bool Suppressed;
    /// Live transient bodies and flare clusters (the reusable wash is not counted).
    public static int LiveEffects => instance ? instance.live : 0;
    public static int ContactBursts => instance ? instance.bursts : 0;

    readonly Dictionary<string, Cue> pending = new Dictionary<string, Cue>();
    readonly Dictionary<string, int> castCount = new Dictionary<string, int>();
    readonly Dictionary<string, Texture2D> ramps = new Dictionary<string, Texture2D>();
    Material sweepMaterial, washMaterial, flareMaterial;
    Texture2D filigree, noise, atlas;
    Transform root;
    Wash wash;
    int live, bursts;

    // ------------------------------------------------------------ public API

    static SpellSpectacle20260926 Ensure(Component battle)
    {
        if (instance) return instance;
        if (!battle) return null;
        instance = battle.GetComponent<SpellSpectacle20260926>();
        if (!instance) instance = battle.gameObject.AddComponent<SpellSpectacle20260926>();
        return instance;
    }

    public static void BeginPlayer(Component battle, string skillID, Func<Vector3> caster, IList<Func<Vector3>> targets, IList<int> targetSeeds)
    {
        var director = Ensure(battle);
        if (!director || targets == null || targets.Count == 0) return;
        var profile = PlayerProfile(skillID);
        director.Register("player", profile, profile.style, caster, targets, targetSeeds);
    }

    public static void BeginEnemy(Component battle, EnemyHandle actor, string intent, Func<Vector3> playerTarget, EnemyHandle supportRecipient)
    {
        var director = Ensure(battle);
        if (!director || !actor) return;
        intent = intent ?? "strike";
        string key = "enemy:" + actor.BattleEnemyId;
        if (intent == "recover" || IsPreparation(intent)) { director.pending.Remove(key); return; }
        // Ghost skins keep the guard profile ID and add a FogGhostActor child.
        string model = actor.ProfileEnemyId;
        var ghost = actor.EnemyRoot ? actor.EnemyRoot.GetComponentInChildren<FogGhostActor>(false) : null;
        if (ghost && ghost.gameObject.activeInHierarchy) model = ghost.IsSplit ? "crimson-ghost" : "fog-ghost";
        var profile = EnemyProfile(actor.BattleEnemyId, intent, model);
        var style = EnemyStyle(profile, intent, model);
        Func<Vector3> caster = () => actor && actor.EffectAnchor ? actor.EffectAnchor.position
            : actor && actor.EnemyRoot ? actor.EnemyRoot.position + Vector3.up : Vector3.zero;
        var targets = new List<Func<Vector3>>();
        var seeds = new List<int>();
        if (style == Style.Support)
        {
            var who = supportRecipient ? supportRecipient : actor;
            Vector3 last = AnchorOf(who);
            targets.Add(() => { if (who && who.gameObject.activeInHierarchy) last = AnchorOf(who); return last; });
            seeds.Add(StableHash(who.BattleEnemyId));
        }
        else
        {
            targets.Add(playerTarget);
            seeds.Add(StableHash(actor.BattleEnemyId + intent));
        }
        director.Register(key, profile, style, caster, targets, seeds);
    }

    /// Immediate enveloping burst for a state that has no contact callback
    /// (armour lock, manual mask). Support style only: gather, wrap, rise.
    public static void PlayState(Component battle, string profileKey, Func<Vector3> anchor, int seed)
    {
        var director = Ensure(battle);
        if (!director || anchor == null || !Profiles.TryGetValue(profileKey, out var profile)) return;
        var cue = new Cue { profile = profile, style = Style.Support, caster = anchor, expiresAt = Time.unscaledTime + 1f };
        director.castCount.TryGetValue("state" + profileKey, out int n);
        director.castCount["state" + profileKey] = n + 1;
        cue.cast = n;
        cue.targets.Add(anchor); cue.seeds.Add(seed);
        director.Burst(cue);
    }

    public static Vector3 AnchorOf(EnemyHandle handle)
    {
        if (!handle) return Vector3.zero;
        if (handle.EffectAnchor) return handle.EffectAnchor.position;
        return handle.EnemyRoot ? handle.EnemyRoot.position + Vector3.up * 1.05f : handle.transform.position;
    }

    public static int StableHash(string text)
    {
        unchecked
        {
            int h = 23;
            foreach (char c in text ?? "") h = h * 31 + c;
            return h & 0x7fffffff;
        }
    }

    public static void Contact(string actor)
    {
        if (!instance || string.IsNullOrEmpty(actor)) return;
        if (Suppressed || !instance.pending.TryGetValue(actor, out var cue) || Time.unscaledTime > cue.expiresAt) return;
        // Same-frame duplicate callbacks are one contact; a legal second hit
        // of a multi-projectile attack still gets its own burst.
        if (Time.unscaledTime - cue.lastContact < .085f) return;
        cue.lastContact = Time.unscaledTime;
        instance.Burst(cue);
    }

    public static void StopAll()
    {
        if (!instance) return;
        instance.pending.Clear();
        if (instance.root)
            for (int i = instance.root.childCount - 1; i >= 0; i--)
                Destroy(instance.root.GetChild(i).gameObject);
    }

    void OnDestroy()
    {
        if (instance == this) instance = null;
        if (root) Destroy(root.gameObject);
        foreach (var t in ramps.Values) if (t) Destroy(t);
        if (sweepMaterial) Destroy(sweepMaterial);
        if (washMaterial) Destroy(washMaterial);
        if (flareMaterial) Destroy(flareMaterial);
    }

    // ------------------------------------------------------------ setup

    void Register(string key, Profile profile, Style style, Func<Vector3> caster, IList<Func<Vector3>> targets, IList<int> seeds)
    {
        castCount.TryGetValue(key + profile.id, out int n);
        castCount[key + profile.id] = n + 1;
        var cue = new Cue { profile = profile, style = style, caster = caster, expiresAt = Time.unscaledTime + 6f, cast = n };
        for (int i = 0; i < targets.Count; i++)
        {
            if (targets[i] == null) continue;
            cue.targets.Add(targets[i]);
            cue.seeds.Add(seeds != null && i < seeds.Count ? seeds[i] : i * 7919);
        }
        if (cue.targets.Count > 0) pending[key] = cue;
    }

    bool Load()
    {
        if (sweepMaterial) return true;
        var sweep = Resources.Load<Shader>("SpellSpectacle20260926/SpectacleSweep");
        var washShader = Resources.Load<Shader>("SpellSpectacle20260926/SpectacleWash");
        var flare = Resources.Load<Shader>("SpellSpectacle20260926/SpectacleFlare");
        filigree = Resources.Load<Texture2D>("SpellSpectacle20260926/SpectacleFiligree");
        noise = Resources.Load<Texture2D>("SpellSpectacle20260926/SpectacleNoise");
        atlas = Resources.Load<Texture2D>("SpellSpectacle20260926/SpectacleAtlas");
        if (!sweep || !washShader || !flare || !filigree || !noise || !atlas)
        {
            Debug.LogWarning("SPELL_SPECTACLE_MISSING_RESOURCE");
            return false;
        }
        sweepMaterial = new Material(sweep) { name = "SpectacleSweep" };
        sweepMaterial.SetTexture("_Filigree", filigree);
        sweepMaterial.SetTexture("_Noise", noise);
        washMaterial = new Material(washShader) { name = "SpectacleWash" };
        washMaterial.SetTexture("_Noise", noise);
        flareMaterial = new Material(flare) { name = "SpectacleFlare" };
        flareMaterial.SetTexture("_MainTex", atlas);
        // Scene root with identity transform: bodies and flares are built in world space.
        root = new GameObject("SpellSpectacle20260926").transform;
        return true;
    }

    Texture2D Ramp(Profile p)
    {
        if (ramps.TryGetValue(p.id, out var tex) && tex) return tex;
        tex = new Texture2D(128, 1, TextureFormat.RGBA32, false) { wrapMode = TextureWrapMode.Clamp, filterMode = FilterMode.Bilinear, name = "ramp-" + p.id };
        var px = new Color[128];
        for (int i = 0; i < 128; i++)
        {
            float t = i / 127f * (p.ramp.Length - 1);
            int a = Mathf.Min((int)t, p.ramp.Length - 2);
            px[i] = Color.Lerp(p.ramp[a], p.ramp[a + 1], Mathf.SmoothStep(0, 1, t - a));
        }
        tex.SetPixels(px);
        tex.Apply(false, true);
        ramps[p.id] = tex;
        return tex;
    }

    // ------------------------------------------------------------ burst

    void Burst(Cue cue)
    {
        var cam = Camera.main;
        if (!cam || !Load()) return;
        bursts++;
        var p = cue.profile;
        var style = cue.style;
        Vector3 caster = SafeEval(cue.caster);
        var points = new List<Vector3>();
        foreach (var f in cue.targets) points.Add(SafeEval(f));
        if (points.Count == 0) return;
        Vector3 mean = Vector3.zero;
        foreach (var v in points) mean += v;
        mean /= points.Count;

        // Every size below is a fraction of the visible half-height at the
        // hit depth, so tower scaling or a recorder close-up keeps the same
        // screen proportion instead of a fixed world size.
        // One target: the full body grows around it. Several targets: one shared
        // environment body spans the group, and every recipient still gets its
        // own heart, splash and matter so no hit is hidden inside another.
        bool group = points.Count > 1;
        if (group)
        {
            float spread = 0;
            foreach (var v in points) spread = Mathf.Max(spread, Vector3.Distance(v, mean));
            var rng = new System.Random(StableHash(p.id) + cue.cast * 7);
            float half = Vector3.Distance(cam.transform.position, mean) * Mathf.Tan(cam.fieldOfView * .5f * Mathf.Deg2Rad);
            float s = half / 4.5f * p.scale * TierScale(style) * 1.12f;
            SpawnBodies(cue, style, caster, mean, s, rng, 0f, cam);
        }
        for (int i = 0; i < points.Count; i++)
        {
            var rng = new System.Random(cue.seeds[i] * 31 + cue.cast * 7 + p.id.Length);
            float half = Vector3.Distance(cam.transform.position, points[i]) * Mathf.Tan(cam.fieldOfView * .5f * Mathf.Deg2Rad);
            float s = half / 4.5f * p.scale * TierScale(style) * (group ? .78f : 1f);
            float delay = i * .035f;
            if (!group) SpawnBodies(cue, style, caster, points[i], s, rng, delay, cam);
            var flares = Flares.Create(root, flareMaterial, this);
            flares.Build(p, style, new Frame(cam, caster, points[i], s, rng), rng, delay, group);
        }
        float amount = style switch
        {
            Style.Heavy => .52f, Style.Strike => .38f, Style.Light => .28f, Style.Control => .22f, _ => .2f
        };
        if (group) amount *= .7f;
        if (ReducedMotion) amount *= .35f;
        if (!wash) wash = Wash.Create(root, washMaterial, this);
        wash.Trigger(mean, p.wash, p.hot, amount, style == Style.Support ? .2f : style == Style.Light ? .18f : style == Style.Heavy ? .34f : .26f, style == Style.Support ? .6f : .46f);
    }

    static Vector3 SafeEval(Func<Vector3> f)
    {
        try { return f != null ? f() : Vector3.zero; } catch { return Vector3.zero; }
    }

    static float TierScale(Style s) => s switch
    {
        Style.Heavy => 1.32f, Style.Strike => 1.16f, Style.Light => 1.06f, Style.Support => 1.1f, _ => 1.06f
    };

    void SpawnBodies(Cue cue, Style style, Vector3 caster, Vector3 target, float s, System.Random rng, float delay, Camera cam)
    {
        var p = cue.profile;
        var frame = new Frame(cam, caster, target, s, rng);
        var family = cue.cast % 2 == 1 ? p.familyAlt : p.family;
        if (style == Style.Support) family = Family.Rising;
        int layers = style switch { Style.Heavy => 3, Style.Strike => 3, Style.Light => 2, Style.Support => 3, _ => 2 };
        var ramp = Ramp(p);
        var paths = Paths(family, frame, layers, rng);
        for (int k = 0; k < paths.Count; k++)
        {
            var body = Body.Create(root, sweepMaterial, this);
            float bodyDelay = delay + paths[k].delay;
            body.Setup(paths[k], frame.target, ramp, p, style, bodyDelay, (float)rng.NextDouble() * 10f, k);
        }
        // Strike and heavy casts also open one body of the identity's second
        // form, so a hit reads as layered matter rather than a single sweep.
        if ((style == Style.Strike || style == Style.Heavy) && p.familyAlt != family)
        {
            var extra = Paths(p.familyAlt, frame, 1, rng);
            for (int k = 0; k < Mathf.Min(2, extra.Count); k++)
            {
                var body = Body.Create(root, sweepMaterial, this);
                extra[k].rampShift += .18f;
                body.Setup(extra[k], frame.target, ramp, p, style, delay + .045f + extra[k].delay, (float)rng.NextDouble() * 10f, 4 + k);
            }
        }
        if (p.column && style != Style.Light)
        {
            var col = Column(frame, rng);
            var body = Body.Create(root, sweepMaterial, this);
            body.Setup(col, frame.target, ramp, p, style == Style.Support ? Style.Support : Style.Heavy, delay + .02f, (float)rng.NextDouble() * 10f, 7);
        }
    }

    // ------------------------------------------------------------ geometry

    struct Frame
    {
        public Vector3 target, caster, right, up, toCam, dir;
        public float s, side;
        public Frame(Camera cam, Vector3 caster, Vector3 target, float s, System.Random rng)
        {
            this.target = target; this.caster = caster; this.s = s;
            right = cam.transform.right; up = Vector3.up;
            toCam = -cam.transform.forward; toCam.y *= .35f; toCam.Normalize();
            var d = target - caster; d.y = 0;
            dir = d.sqrMagnitude > .01f ? d.normalized : right;
            float onScreen = Vector3.Dot(target - caster, right);
            side = Mathf.Abs(onScreen) > .05f ? Mathf.Sign(onScreen) : (rng.NextDouble() < .5 ? -1f : 1f);
        }
    }

    public sealed class Path
    {
        public Vector3[] points;   // world, along
        public Vector3[] across;   // unit width direction
        public float[] half;       // half width
        public Vector3 bulge;      // direction the centre of the section swells
        public float bulgeAmount = .35f;
        public bool anchored;      // width grows from the spine to one side
        public float delay, reveal = 1f, tile = 2.5f, rampShift, rampSpan = 1f;
    }

    static float R(System.Random rng, float a, float b) => a + (float)rng.NextDouble() * (b - a);

    static Path Make(int n, Func<float, Vector3> pos, Func<float, Vector3> across, Func<float, float> half, Vector3 bulge)
    {
        var path = new Path { points = new Vector3[n], across = new Vector3[n], half = new float[n], bulge = bulge };
        for (int i = 0; i < n; i++)
        {
            float t = i / (n - 1f);
            path.points[i] = pos(t);
            path.half[i] = Mathf.Max(0f, half(t));
        }
        for (int i = 0; i < n; i++)
        {
            float t = i / (n - 1f);
            var a = across(t);
            path.across[i] = a.sqrMagnitude > 1e-6f ? a.normalized : Vector3.up;
        }
        return path;
    }

    static Vector3 Bezier(Vector3 a, Vector3 b, Vector3 c, Vector3 d, float t)
    {
        float u = 1 - t;
        return u * u * u * a + 3 * u * u * t * b + 3 * u * t * t * c + t * t * t * d;
    }

    static Func<float, Vector3> FacingAcross(Func<float, Vector3> pos, Vector3 toCam)
    {
        return t =>
        {
            var tangent = pos(Mathf.Min(1, t + .01f)) - pos(Mathf.Max(0, t - .01f));
            return Vector3.Cross(tangent, toCam);
        };
    }

    // sin(pi) is slightly negative in float; clamp before the fractional power (NaN otherwise).
    static float Swell(float t, float power) => Mathf.Pow(Mathf.Max(0f, Mathf.Sin(Mathf.PI * Mathf.Clamp01(t))), power);

    List<Path> Paths(Family family, Frame f, int layers, System.Random rng)
    {
        var list = new List<Path>();
        float s = f.s;
        switch (family)
        {
            case Family.Crescent:
            {
                // Layered, off-centre arcs of unequal span: a torn rainbow dome.
                for (int k = 0; k < layers; k++)
                {
                    var centre = f.target - f.up * (.1f - .16f * k) * s + f.right * f.side * R(rng, -.3f, .3f) * s - f.toCam * (.2f * k) * s;
                    float radius = (1.55f + .42f * k + R(rng, -.1f, .15f)) * s;
                    float a0 = R(rng, 178, 205) * Mathf.Deg2Rad, a1 = R(rng, -18, 14) * Mathf.Deg2Rad;
                    if (f.side < 0) { float t0 = a0; a0 = Mathf.PI - a1; a1 = Mathf.PI - t0; }
                    var yAxis = (f.up * .86f + f.toCam * .5f).normalized;
                    float squash = R(rng, .72f, .9f), wob = R(rng, 0, 6);
                    float width = (.82f - .12f * k) * s;
                    Func<float, Vector3> pos = t => { float a = Mathf.Lerp(a0, a1, t); return centre + radius * (Mathf.Cos(a) * f.right + Mathf.Sin(a) * squash * yAxis); };
                    var path = Make(72, pos, t => { float a = Mathf.Lerp(a0, a1, t); return Mathf.Cos(a) * f.right + Mathf.Sin(a) * squash * yAxis; },
                        t => width * Swell(t, .45f) * (1 + .28f * Mathf.Sin(t * 9 + wob)), f.toCam);
                    path.delay = k * .03f; path.rampShift = -.1f * k; path.rampSpan = 1.05f; path.tile = 3.2f;
                    list.Add(path);
                }
                break;
            }
            case Family.Rising:
            {
                // Tongues that climb from the recipient in S-curves, broad side to camera.
                int tongues = layers + 1;
                for (int k = 0; k < tongues; k++)
                {
                    float x0 = (k - (tongues - 1) * .5f) * R(rng, .55f, .8f) * s, sway = R(rng, .45f, .85f) * s * (k % 2 == 0 ? 1 : -1);
                    float height = R(rng, 3.4f, 4.6f) * s * (k == tongues / 2 ? 1.15f : 1f), phase = R(rng, 0, 6.28f), depth = R(rng, -.4f, .4f) * s;
                    float width = R(rng, .5f, .72f) * s;
                    var t2 = f.target;
                    Func<float, Vector3> pos = t => t2 + f.right * (x0 * (1 - .6f * t) + Mathf.Sin(t * 5.2f + phase) * sway * t) + f.up * (-.9f * s + height * Mathf.Pow(t, .9f)) + f.toCam * depth;
                    var path = Make(56, pos, FacingAcross(pos, f.toCam), t => width * Swell(Mathf.Pow(t, .55f), .6f) * (1 - .45f * t), f.toCam);
                    path.delay = Mathf.Abs(k - (tongues - 1) * .5f) * .03f; path.rampShift = R(rng, -.15f, .12f); path.tile = 1.9f;
                    list.Add(path);
                }
                break;
            }
            case Family.Falling:
            {
                for (int k = 0; k < Mathf.Max(1, layers - 1); k++)
                {
                    float sd = f.side * (k % 2 == 0 ? 1 : -1);
                    var p0 = f.target + f.up * (5.4f + .5f * k) * s - f.right * sd * R(rng, 1.8f, 2.6f) * s + f.toCam * .3f * s;
                    var p1 = f.target + f.up * 2.8f * s - f.right * sd * .5f * s;
                    var p2 = f.target + f.up * .1f * s - f.right * sd * .15f * s;
                    var p3 = f.target + f.right * sd * R(rng, 1.8f, 2.6f) * s + f.up * .05f * s + f.toCam * .8f * s;
                    Func<float, Vector3> pos = t => Bezier(p0, p1, p2, p3, t);
                    var path = Make(64, pos, FacingAcross(pos, f.toCam), t => s * (.26f + .78f * Mathf.Exp(-Mathf.Pow((t - .58f) / .22f, 2))) * (1 - .25f * k), f.toCam);
                    path.delay = k * .05f; path.rampShift = .1f * k; path.tile = 2.8f;
                    list.Add(path);
                }
                // Impact skirt that tears sideways along the ground.
                var skirt = SkirtPath(f, rng);
                skirt.delay = .03f;
                list.Add(skirt);
                break;
            }
            case Family.Surge:
            {
                for (int k = 0; k < layers; k++)
                {
                    float lateral = f.side * R(rng, 1.2f, 2f) * s * (k % 2 == 0 ? 1 : -.7f);
                    var p0 = Vector3.Lerp(f.caster, f.target, .35f) + f.up * .2f * s + f.right * lateral * .4f;
                    var p1 = Vector3.Lerp(f.caster, f.target, .78f) + f.right * lateral - f.up * .1f * s;
                    var p2 = f.target + f.dir * 1.3f * s + f.up * 1.4f * s - f.right * lateral * .4f;
                    var p3 = f.target - f.right * lateral * .35f + f.up * (2.9f + .4f * k) * s;
                    Func<float, Vector3> pos = t => Bezier(p0, p1, p2, p3, t);
                    var path = Make(72, pos, FacingAcross(pos, f.toCam), t => s * (.82f - .14f * k) * Swell(t, .5f) * (1 + .45f * Mathf.Exp(-Mathf.Pow((t - .72f) / .14f, 2))), f.toCam);
                    path.delay = k * .035f; path.rampShift = -.08f * k; path.tile = 3.4f;
                    list.Add(path);
                }
                break;
            }
            case Family.Fan:
            {
                int blades = 4 + layers + rng.Next(0, 2);
                float span = R(rng, 150, 210) * Mathf.Deg2Rad, start = Mathf.PI * .5f - span * .5f + R(rng, -.2f, .2f);
                var centre = f.target + f.up * .35f * s;
                var plane = (f.up * .9f + f.toCam * .4f).normalized;
                for (int b = 0; b < blades; b++)
                {
                    float a = start + span * (b + R(rng, -.3f, .3f)) / Mathf.Max(1, blades - 1);
                    var d = Mathf.Cos(a) * f.right + Mathf.Sin(a) * plane;
                    var perp = -Mathf.Sin(a) * f.right + Mathf.Cos(a) * plane;
                    float length = R(rng, 1.9f, 3.5f) * s, curl = R(rng, -.4f, .4f), depth = R(rng, -.5f, .5f) * s, width = R(rng, .46f, .66f) * s;
                    Func<float, Vector3> pos = t => centre + d * length * t + perp * Mathf.Sin(t * Mathf.PI) * curl * length * .45f + f.toCam * depth * t;
                    var path = Make(40, pos, _ => perp, t => width * Swell(Mathf.Pow(t, .7f), .7f) * (1 - .3f * t), f.toCam);
                    path.delay = b * .014f; path.rampShift = R(rng, -.2f, .2f); path.tile = 1.6f;
                    list.Add(path);
                }
                break;
            }
            case Family.Twin:
            {
                int cuts = layers >= 3 ? 3 : 2;
                for (int k = 0; k < cuts; k++)
                {
                    float ang = (k == 0 ? R(rng, 24, 40) : k == 1 ? R(rng, -58, -38) : R(rng, -8, 8)) * Mathf.Deg2Rad * f.side;
                    var d = (Mathf.Cos(ang) * f.right + Mathf.Sin(ang) * f.up).normalized;
                    var perp = Vector3.Cross(d, f.toCam).normalized;
                    float length = (k == 0 ? 4.1f : k == 1 ? 3.2f : 3.6f) * s, bend = R(rng, .28f, .5f) * (k % 2 == 0 ? 1 : -1);
                    var centre = f.target + f.up * .45f * s + f.toCam * .2f * s * k;
                    Func<float, Vector3> pos = t => centre + (t - .5f) * length * d + perp * bend * length * .5f * (1 - Mathf.Pow(2 * t - 1, 2));
                    var path = Make(56, pos, _ => perp, t => s * (.58f - .08f * k) * Swell(t, .55f) * (1 + .45f * Mathf.Exp(-Mathf.Pow((t - .6f) / .16f, 2))), f.toCam);
                    path.delay = k * .055f; path.rampShift = .12f * k; path.tile = 3.6f;
                    list.Add(path);
                }
                break;
            }
            case Family.Curtain:
            {
                int folds = 2 + layers;
                for (int k = 0; k < folds; k++)
                {
                    float x = (k - (folds - 1) * .5f) * R(rng, .8f, 1.15f) * s + R(rng, -.2f, .2f) * s;
                    float top = R(rng, 3.4f, 5.2f) * s, sway = R(rng, .25f, .6f) * s, phase = R(rng, 0, 6), depth = R(rng, -.6f, .6f) * s, width = R(rng, .55f, .8f) * s;
                    var t2 = f.target;
                    Func<float, Vector3> pos = t => t2 + f.right * (x + Mathf.Sin(t * 5 + phase) * sway * t) + f.up * (top * (1 - t) - .8f * s) + f.toCam * depth;
                    var path = Make(48, pos, t => f.right + f.toCam * Mathf.Sin(t * 7 + phase) * .6f, t => width * Swell(t, .35f) * (1 + .35f * t), f.toCam);
                    path.delay = Mathf.Abs(k - (folds - 1) * .5f) * .025f; path.rampShift = R(rng, -.15f, .15f); path.tile = 1.8f;
                    list.Add(path);
                }
                break;
            }
            case Family.Tide:
            {
                for (int k = 0; k < layers; k++)
                {
                    float sd = f.side * (k == 1 ? -1 : 1);
                    float reach = R(rng, 2.6f, 3.4f) * s, depth = (.8f - .5f * k) * s;
                    var t2 = f.target - f.up * .75f * s;
                    Func<float, Vector3> pos = t => t2 + f.right * sd * Mathf.Lerp(-reach, reach * .75f, t) + f.toCam * (Mathf.Sin(Mathf.PI * t) * depth);
                    var path = Make(64, pos, _ => f.up, t => s * (.55f + 1.05f * Swell(t, .8f)) * (1 - .18f * k), f.toCam);
                    path.anchored = true; path.bulgeAmount = .9f;
                    path.delay = k * .045f; path.rampShift = .1f * k; path.tile = 3f;
                    list.Add(path);
                }
                break;
            }
        }
        return list;
    }

    static Path SkirtPath(Frame f, System.Random rng)
    {
        float s = f.s, reach = R(rng, 2.2f, 3f) * s;
        var t2 = f.target - f.up * .78f * s;
        Func<float, Vector3> pos = t => t2 + f.right * Mathf.Lerp(-reach, reach, t) + f.toCam * Mathf.Sin(t * Mathf.PI) * .9f * s;
        var path = Make(48, pos, _ => f.up, t => s * (.2f + .55f * Swell(t, .9f)), f.toCam);
        path.anchored = true; path.bulgeAmount = 1.1f; path.tile = 2.4f; path.rampShift = .15f;
        return path;
    }

    static Path Column(Frame f, System.Random rng)
    {
        float s = f.s, height = R(rng, 5.2f, 6.6f) * s, lean = R(rng, -.35f, .35f) * s, phase = R(rng, 0, 6);
        var t2 = f.target;
        Func<float, Vector3> pos = t => t2 + f.up * (-.85f * s + height * t) + f.right * (Mathf.Sin(t * 4 + phase) * .14f * s + lean * t);
        var path = Make(40, pos, t => f.right * Mathf.Cos(t * 3 + phase) + f.toCam * Mathf.Sin(t * 3 + phase) * .6f,
            t => s * .5f * (1 - .6f * t) * (.55f + .45f * Mathf.Sin(Mathf.PI * Mathf.Pow(t, .35f))), f.toCam);
        path.tile = 1.3f; path.rampShift = .25f; path.rampSpan = .6f;
        return path;
    }

    // ------------------------------------------------------------ body

    sealed class Body : MonoBehaviour
    {
        SpellSpectacle20260926 owner;
        MeshRenderer meshRenderer;
        Mesh mesh;
        MaterialPropertyBlock block;
        Vector3 pivot;
        float age, delay, reveal, hold, fade, intensity, seed, dir;
        Style style;

        public static Body Create(Transform parent, Material material, SpellSpectacle20260926 owner)
        {
            var go = new GameObject("SpectacleBody");
            go.transform.SetParent(parent, false);
            var body = go.AddComponent<Body>();
            body.owner = owner;
            owner.live++;
            go.AddComponent<MeshFilter>();
            body.meshRenderer = go.AddComponent<MeshRenderer>();
            body.meshRenderer.sharedMaterial = material;
            body.meshRenderer.shadowCastingMode = UnityEngine.Rendering.ShadowCastingMode.Off;
            body.meshRenderer.receiveShadows = false;
            return body;
        }

        public void Setup(Path path, Vector3 pivot, Texture2D ramp, Profile p, Style style, float delay, float seed, int layer)
        {
            this.pivot = pivot; this.delay = delay; this.seed = seed; this.style = style;
            dir = layer % 2 == 0 ? 1 : -1;
            (reveal, hold, fade, intensity) = style switch
            {
                Style.Heavy => (.15f, .16f, .50f, 1.16f),
                Style.Strike => (.12f, .12f, .42f, 1.1f),
                Style.Light => (.10f, .08f, .34f, 1.06f),
                Style.Support => (.30f, .26f, .54f, 1.06f),
                _ => (.16f, .14f, .44f, 1.06f),
            };
            transform.position = pivot;
            mesh = BuildMesh(path, pivot);
            GetComponent<MeshFilter>().sharedMesh = mesh;
            block = new MaterialPropertyBlock();
            block.SetTexture("_Ramp", ramp);
            block.SetColor("_Line", p.line);
            block.SetColor("_Core", p.core);
            block.SetFloat("_Seed", seed);
            block.SetFloat("_RampShift", path.rampShift);
            block.SetFloat("_RampSpan", path.rampSpan * p.rampSpan);
            block.SetFloat("_Tile", path.tile);
            block.SetFloat("_Tear", style == Style.Support ? .7f : 1f);
            block.SetFloat("_CoreAmt", style == Style.Support ? .4f : style == Style.Control ? .45f : .6f);
            block.SetFloat("_Opacity", style == Style.Support ? .95f : .97f);
            Apply(0);
        }

        static Mesh BuildMesh(Path path, Vector3 pivot)
        {
            const int across = 7;
            int n = path.points.Length;
            var v = new Vector3[n * across];
            var nrm = new Vector3[n * across];
            var uv = new Vector2[n * across];
            var col = new Color[n * across];
            var tri = new int[(n - 1) * (across - 1) * 6];
            for (int i = 0; i < n; i++)
            {
                var tangent = path.points[Mathf.Min(n - 1, i + 1)] - path.points[Mathf.Max(0, i - 1)];
                var w = path.across[i];
                var normal = Vector3.Cross(tangent, w).normalized;
                if (Vector3.Dot(normal, path.bulge) < 0) normal = -normal;
                float h = path.half[i];
                float tailFade = Mathf.SmoothStep(0, 1, i / (n - 1f) / .12f);
                for (int j = 0; j < across; j++)
                {
                    float u = j / (across - 1f);
                    float x = path.anchored ? u : u * 2 - 1;
                    float swell = path.anchored ? u * u : 1 - x * x;
                    var offset = path.anchored ? w * (u * 2 * h) : w * (x * h);
                    offset += normal * swell * h * path.bulgeAmount;
                    int idx = i * across + j;
                    var vertex = path.points[i] + offset - pivot;
                    v[idx] = float.IsFinite(vertex.x) && float.IsFinite(vertex.y) && float.IsFinite(vertex.z) ? vertex : path.points[i] - pivot;
                    // The fold normal turns across the section for lit/dark sides.
                    nrm[idx] = (normal * (1 - Mathf.Abs(x) * .7f) + w * x * .9f).normalized;
                    uv[idx] = new Vector2(i / (n - 1f), u);
                    col[idx] = new Color(1, 1, 1, tailFade);
                }
            }
            int t = 0;
            for (int i = 0; i < n - 1; i++)
                for (int j = 0; j < across - 1; j++)
                {
                    int a = i * across + j, b = a + 1, c = a + across, d = c + 1;
                    tri[t++] = a; tri[t++] = c; tri[t++] = b;
                    tri[t++] = b; tri[t++] = c; tri[t++] = d;
                }
            var mesh = new Mesh { name = "SpectacleBodyMesh" };
            mesh.vertices = v; mesh.normals = nrm; mesh.uv = uv; mesh.colors = col; mesh.triangles = tri;
            mesh.RecalculateBounds();
            return mesh;
        }

        void Update()
        {
            age += Time.deltaTime;
            Apply(age - delay);
            if (age - delay > reveal + hold + fade + .02f) Destroy(gameObject);
        }

        void Apply(float t)
        {
            if (!meshRenderer) return;
            meshRenderer.enabled = t >= 0;
            if (t < 0) return;
            float grow = Mathf.Clamp01(t / reveal);
            float eased = 1 - Mathf.Pow(1 - grow, 3);
            // Fast expansion that overshoots, settles, then drifts outward as it tears apart.
            float scale = Mathf.Lerp(.5f, 1.07f, eased);
            if (t > reveal) scale = Mathf.Lerp(1.07f, 1f, Mathf.Clamp01((t - reveal) / .1f));
            float out01 = Mathf.Clamp01((t - reveal - hold) / fade);
            scale += out01 * .10f;
            transform.localScale = Vector3.one * scale;
            float flash = 1 + 1.3f * Mathf.Exp(-t / .07f);
            block.SetFloat("_Reveal", Mathf.Lerp(-.05f, 1.12f, eased));
            block.SetFloat("_Dissolve", Mathf.Lerp(-.25f, 1.05f, out01 * out01 * (3 - 2 * out01)));
            block.SetFloat("_Alpha", 1 - Mathf.SmoothStep(.55f, 1f, out01));
            block.SetFloat("_Intensity", intensity * (1 + .12f * Mathf.Exp(-t / .07f)));
            block.SetFloat("_Glow", flash);
            block.SetFloat("_Head", grow < 1 ? 1.4f : Mathf.Lerp(1.4f, .2f, Mathf.Clamp01((t - reveal) / .12f)));
            block.SetFloat("_Scroll", t * .55f * dir);
            block.SetFloat("_Flow", t);
            meshRenderer.SetPropertyBlock(block);
        }

        void OnDestroy()
        {
            if (owner) owner.live--;
            if (mesh) Destroy(mesh);
        }
    }

    // ------------------------------------------------------------ flares & motes

    sealed class Flares : MonoBehaviour
    {
        struct Mark
        {
            public Vector3 pos, vel;
            public Color color;
            public Rect cell;
            public float size, sizeEnd, rot, spin, life, age, delay, drag, gravity, stretch, peak, opacity, hot;
            public bool flat, pop;
        }

        SpellSpectacle20260926 owner;
        readonly List<Mark> marks = new List<Mark>();
        Mesh mesh;
        MeshRenderer meshRenderer;
        Vector3[] verts; Vector2[] uvs, uvs2; Color[] cols; int[] tris;

        public static Flares Create(Transform parent, Material material, SpellSpectacle20260926 owner)
        {
            var go = new GameObject("SpectacleFlares");
            go.transform.SetParent(parent, false);
            var f = go.AddComponent<Flares>();
            f.owner = owner;
            owner.live++;
            f.mesh = new Mesh { name = "SpectacleFlareMesh" };
            f.mesh.MarkDynamic();
            go.AddComponent<MeshFilter>().sharedMesh = f.mesh;
            f.meshRenderer = go.AddComponent<MeshRenderer>();
            f.meshRenderer.sharedMaterial = material;
            f.meshRenderer.shadowCastingMode = UnityEngine.Rendering.ShadowCastingMode.Off;
            f.meshRenderer.receiveShadows = false;
            return f;
        }

        // Atlas cells in UV (y up). Image rows are measured from the top.
        static Rect Cell(int px, int py, int size) => new Rect(px / 2048f, 1f - (py + size) / 2048f, size / 2048f, size / 2048f);
        static Rect Star(int i) => Cell((i & 1) * 512, (i >> 1) * 512, 512);
        static Rect Splash(int i) => Cell(1024 + (i & 1) * 512, (i >> 1) * 512, 512);
        static Rect MoteCell(Mote m) => Cell(((int)m & 3) * 256, 1024 + ((int)m >> 2) * 256, 256);

        static Color Pick(Profile p, System.Random rng, float lo = 0, float hi = 1)
        {
            float t = R(rng, lo, hi) * (p.ramp.Length - 1);
            int a = Mathf.Min((int)t, p.ramp.Length - 2);
            return Color.Lerp(p.ramp[a], p.ramp[a + 1], t - a);
        }

        public void Build(Profile p, Style style, Frame f, System.Random rng, float delay, bool group)
        {
            float s = f.s;
            bool support = style == Style.Support;
            bool damage = style == Style.Light || style == Style.Strike || style == Style.Heavy;
            float tier = style == Style.Heavy ? 1.2f : style == Style.Strike ? 1f : style == Style.Light ? .62f : .7f;
            var hotSpot = f.target + f.toCam * .35f * s;
            if (damage || style == Style.Control)
            {
                // Small white-gold heart inside an identity-coloured star, then a
                // torn splash of body colour that stays readable on bright ground.
                var rim = Pick(p, rng, .45f, .85f);
                // Several recipients each keep one tinted heart; only a single hit gets the white core.
                if (!group)
                    Add(new Mark { pos = hotSpot, cell = Star(rng.Next(4)), color = Color.Lerp(rim, p.core, .45f), size = 1.1f * s * tier, sizeEnd = 2.8f * s * tier, rot = R(rng, 0, 360), spin = R(rng, -40, 40), life = .26f, delay = delay, peak = .14f, pop = true, opacity = .35f, hot = 1f });
                Add(new Mark { pos = hotSpot + f.toCam * .05f, cell = Star(rng.Next(4)), color = rim, size = (group ? 1.3f : 1.7f) * s * tier, sizeEnd = (group ? 3.1f : 4.1f) * s * tier, rot = R(rng, 0, 360), spin = R(rng, -25, 25), life = .38f, delay = delay + .02f, peak = .18f, pop = true, opacity = .6f, hot = group ? .35f : .8f });
                Add(new Mark { pos = hotSpot - f.toCam * .1f, cell = Splash(rng.Next(4)), color = Pick(p, rng, .15f, .6f), size = 1.5f * s * tier, sizeEnd = 5f * s * tier, rot = R(rng, 0, 360), spin = R(rng, -30, 30), life = .48f, delay = delay, peak = .2f, opacity = .92f, hot = .15f });
                if (style == Style.Heavy && !group)
                    Add(new Mark { pos = f.target - f.up * .78f * s, cell = Splash(rng.Next(4)), color = Pick(p, rng, .1f, .5f), size = 2.4f * s, sizeEnd = 8.4f * s, rot = R(rng, 0, 360), spin = R(rng, -15, 15), life = .65f, delay = delay + .02f, peak = .22f, flat = true, opacity = .9f, hot = .1f });
            }
            if (support)
            {
                // A soft tinted bloom on the recipient: warmth and reception, no splash or white core.
                Add(new Mark { pos = hotSpot, cell = Star(rng.Next(4)), color = Pick(p, rng, .35f, .7f), size = 1.2f * s, sizeEnd = 3.2f * s, rot = R(rng, 0, 360), spin = R(rng, -20, 20), life = .7f, delay = delay + .12f, peak = .35f, pop = true, opacity = .25f, hot = .2f });
            }
            int count = style switch { Style.Heavy => 112, Style.Strike => 82, Style.Light => 52, Style.Support => 64, _ => 52 };
            if (group) count = Mathf.RoundToInt(count * .6f);
            if (ReducedMotion) count = Mathf.RoundToInt(count * .6f);
            for (int i = 0; i < count; i++)
            {
                var type = i % 3 == 2 ? p.mote2 : p.mote;
                var m = new Mark { cell = MoteCell(type), color = Pick(p, rng), delay = delay + R(rng, 0, .06f), rot = R(rng, 0, 360), spin = R(rng, -360, 360),
                    opacity = type == Mote.Spark || type == Mote.Ember || type == Mote.Wisp ? .3f : .85f,
                    hot = type == Mote.Spark ? .8f : type == Mote.Ember ? .55f : type == Mote.Wisp ? .25f : 0f };
                if (support)
                {
                    // Matter gathers onto the recipient, then rises: no explosion.
                    var dirIn = Random3(rng);
                    m.pos = f.target + dirIn * R(rng, 1.6f, 2.8f) * s;
                    m.vel = -dirIn * R(rng, 3.5f, 6f) * s + f.up * R(rng, .5f, 1.5f) * s;
                    m.drag = 2.2f; m.gravity = -1.2f * s; m.life = R(rng, .45f, .75f); m.size = R(rng, .10f, .22f) * s; m.sizeEnd = m.size * .4f; m.peak = .5f;
                }
                else
                {
                    var outDir = (Random3(rng) + f.toCam * .35f + f.up * .25f).normalized;
                    float speed = R(rng, 3.5f, 10.5f) * s * tier;
                    m.pos = hotSpot + outDir * R(rng, 0, .3f) * s;
                    m.vel = outDir * speed;
                    m.life = R(rng, .35f, .8f);
                    m.peak = .12f;
                    m.size = R(rng, .08f, .2f) * s * tier;
                    m.sizeEnd = m.size * .5f;
                    switch (type)
                    {
                        case Mote.Spark: m.stretch = .045f; m.drag = 2.6f; m.size *= .9f; break;
                        case Mote.Ember: m.gravity = -2.4f * s; m.drag = 1.8f; break;
                        case Mote.Shard: m.gravity = 9f * s; m.drag = .9f; m.size *= 1.3f; break;
                        case Mote.Ink: m.gravity = 7f * s; m.drag = 1.2f; m.stretch = .02f; break;
                        case Mote.Petal: m.gravity = 1.4f * s; m.drag = 3f; m.size *= 1.4f; m.life *= 1.3f; break;
                        case Mote.Card: m.gravity = 2.2f * s; m.drag = 2.6f; m.size *= 1.5f; m.life *= 1.2f; break;
                        case Mote.Wisp: m.gravity = -1.2f * s; m.drag = 2.8f; m.size *= 2.2f; m.stretch = .012f; break;
                        case Mote.Puff: m.gravity = -.6f * s; m.drag = 3.4f; m.size *= 3.2f; m.sizeEnd = m.size * 1.8f; m.life *= 1.1f; break;
                    }
                }
                Add(m);
            }
        }

        static Vector3 Random3(System.Random rng)
        {
            var v = new Vector3(R(rng, -1, 1), R(rng, -1, 1), R(rng, -1, 1));
            return v.sqrMagnitude > 1e-4f ? v.normalized : Vector3.up;
        }

        void Add(Mark m) => marks.Add(m);

        void LateUpdate()
        {
            float dt = Time.deltaTime;
            var cam = Camera.main;
            if (!cam) return;
            Vector3 right = cam.transform.right, up = cam.transform.up;
            int alive = 0;
            for (int i = 0; i < marks.Count; i++)
            {
                var m = marks[i];
                m.age += dt;
                float t = m.age - m.delay;
                if (t >= 0)
                {
                    m.vel *= Mathf.Exp(-m.drag * dt);
                    m.vel += Vector3.down * m.gravity * dt;
                    m.pos += m.vel * dt;
                    m.rot += m.spin * dt;
                }
                marks[i] = m;
                if (t < m.life) alive++;
            }
            if (alive == 0) { Destroy(gameObject); return; }
            int quads = marks.Count;
            if (verts == null || verts.Length != quads * 4)
            {
                verts = new Vector3[quads * 4]; uvs = new Vector2[quads * 4]; uvs2 = new Vector2[quads * 4]; cols = new Color[quads * 4]; tris = new int[quads * 6];
                for (int q = 0; q < quads; q++)
                {
                    tris[q * 6] = q * 4; tris[q * 6 + 1] = q * 4 + 1; tris[q * 6 + 2] = q * 4 + 2;
                    tris[q * 6 + 3] = q * 4; tris[q * 6 + 4] = q * 4 + 2; tris[q * 6 + 5] = q * 4 + 3;
                }
                mesh.Clear();
                for (int q = 0; q < quads; q++)
                    uvs2[q * 4] = uvs2[q * 4 + 1] = uvs2[q * 4 + 2] = uvs2[q * 4 + 3] = new Vector2(marks[q].opacity, marks[q].hot);
                mesh.vertices = verts; mesh.uv = uvs; mesh.uv2 = uvs2; mesh.colors = cols; mesh.triangles = tris;
            }
            var origin = transform.position;
            for (int q = 0; q < quads; q++)
            {
                var m = marks[q];
                float t = m.age - m.delay;
                float k = Mathf.Clamp01(t / m.life);
                bool visible = t >= 0 && t < m.life;
                float size = m.pop ? Mathf.Lerp(m.size, m.sizeEnd, 1 - Mathf.Pow(1 - Mathf.Clamp01(k / .35f), 3)) * (1 - .35f * Mathf.Clamp01((k - .35f) / .65f))
                                   : Mathf.Lerp(m.size, m.sizeEnd, k);
                float alpha = visible ? Mathf.Clamp01(k / Mathf.Max(.01f, m.peak * .35f)) * (1 - Mathf.SmoothStep(m.peak, 1f, k)) : 0f;
                Vector3 ax, ay;
                if (m.flat)
                {
                    float r = m.rot * Mathf.Deg2Rad;
                    ax = new Vector3(Mathf.Cos(r), 0, Mathf.Sin(r)); ay = new Vector3(-Mathf.Sin(r), 0, Mathf.Cos(r));
                }
                else if (m.stretch > 0 && m.vel.sqrMagnitude > 1e-4f)
                {
                    var v = Vector3.ProjectOnPlane(m.vel, cam.transform.forward);
                    float len = v.magnitude;
                    ax = len > 1e-4f ? v / len : right;
                    ay = Vector3.Cross(cam.transform.forward, ax);
                    ax *= 1 + len * m.stretch * 20f;
                }
                else
                {
                    float r = m.rot * Mathf.Deg2Rad;
                    ax = right * Mathf.Cos(r) + up * Mathf.Sin(r); ay = -right * Mathf.Sin(r) + up * Mathf.Cos(r);
                }
                ax *= size * .5f; ay *= size * .5f;
                var c = m.pos - origin;
                int b = q * 4;
                verts[b] = c - ax - ay; verts[b + 1] = c - ax + ay; verts[b + 2] = c + ax + ay; verts[b + 3] = c + ax - ay;
                var cell = m.cell;
                uvs[b] = new Vector2(cell.xMin, cell.yMin); uvs[b + 1] = new Vector2(cell.xMin, cell.yMax);
                uvs[b + 2] = new Vector2(cell.xMax, cell.yMax); uvs[b + 3] = new Vector2(cell.xMax, cell.yMin);
                var col = m.color; col.a = alpha;
                cols[b] = cols[b + 1] = cols[b + 2] = cols[b + 3] = col;
            }
            mesh.vertices = verts; mesh.uv = uvs; mesh.colors = cols;
            mesh.bounds = new Bounds(Vector3.zero, Vector3.one * 200f);
        }

        void OnDestroy()
        {
            if (owner) owner.live--;
            if (mesh) Destroy(mesh);
        }
    }

    // ------------------------------------------------------------ wash

    sealed class Wash : MonoBehaviour
    {
        SpellSpectacle20260926 owner;
        MeshRenderer meshRenderer;
        MaterialPropertyBlock block;
        Mesh mesh;
        float age = 99, amount, glow, decay = .42f;
        Vector3 centre;
        Color edge, hot;

        public static Wash Create(Transform parent, Material material, SpellSpectacle20260926 owner)
        {
            var go = new GameObject("SpectacleWash");
            go.transform.SetParent(parent, false);
            var w = go.AddComponent<Wash>();
            w.owner = owner;
            w.mesh = new Mesh { name = "SpectacleWashQuad" };
            w.mesh.vertices = new[] { new Vector3(0, 0, 0), new Vector3(0, 1, 0), new Vector3(1, 1, 0), new Vector3(1, 0, 0) };
            w.mesh.uv = new[] { new Vector2(0, 0), new Vector2(0, 1), new Vector2(1, 1), new Vector2(1, 0) };
            w.mesh.triangles = new[] { 0, 1, 2, 0, 2, 3 };
            // The vertex shader ignores object space; bounds only keep it from being culled.
            w.mesh.bounds = new Bounds(Vector3.zero, Vector3.one * 100000f);
            go.AddComponent<MeshFilter>().sharedMesh = w.mesh;
            w.meshRenderer = go.AddComponent<MeshRenderer>();
            w.meshRenderer.sharedMaterial = material;
            w.meshRenderer.shadowCastingMode = UnityEngine.Rendering.ShadowCastingMode.Off;
            w.meshRenderer.receiveShadows = false;
            w.meshRenderer.enabled = false;
            w.block = new MaterialPropertyBlock();
            return w;
        }

        public void Trigger(Vector3 centre, Color edge, Color hot, float amount, float glow, float decay)
        {
            // A new contact inside the tail keeps the stronger wash instead of stacking.
            float current = Current();
            this.centre = centre; this.edge = edge; this.hot = hot;
            this.amount = Mathf.Max(amount, current);
            this.glow = ReducedMotion ? glow * .5f : glow;
            this.decay = decay;
            age = 0;
            meshRenderer.enabled = true;
        }

        float Current() => age > 3f ? 0 : amount * Envelope(age);
        float Envelope(float t) => t < .05f ? t / .05f : Mathf.Exp(-(t - .05f) / (decay * .55f));

        void LateUpdate()
        {
            age += Time.deltaTime;
            float e = Envelope(age);
            if (age > .05f + decay * 3.2f) { meshRenderer.enabled = false; return; }
            block.SetVector("_Center", centre);
            block.SetColor("_Edge", edge);
            block.SetColor("_Hot", hot);
            block.SetFloat("_Amount", amount * e);
            block.SetFloat("_Glow", glow * e * e);
            block.SetFloat("_Radius", .30f + .25f * (1 - e));
            block.SetFloat("_Flow", age);
            meshRenderer.SetPropertyBlock(block);
        }

        void OnDestroy()
        {
            if (owner && owner.wash == this) owner.wash = null;
            if (mesh) Destroy(mesh);
        }
    }

    // ------------------------------------------------------------ identities

    static Color C(string hex) { ColorUtility.TryParseHtmlString(hex, out var c); return c; }

    static Profile P(string id, Family family, Family alt, Style style, string[] ramp, string line, string core, string wash, string hot, Mote mote, Mote mote2, bool column = false, float scale = 1f)
    {
        var colors = new Color[ramp.Length];
        for (int i = 0; i < ramp.Length; i++) colors[i] = C(ramp[i]);
        return new Profile { id = id, family = family, familyAlt = alt, style = style, ramp = colors, line = C(line), core = C(core), wash = C(wash), hot = C(hot), mote = mote, mote2 = mote2, column = column, scale = scale };
    }

    static readonly string[] Rainbow = { "#ff2a3c", "#ff7a1a", "#ffd21f", "#3ddc6a", "#28c8ff", "#4c6bff", "#b44cff" };

    static readonly Dictionary<string, Profile> Profiles = new Dictionary<string, Profile>
    {
        // Hero: the Fool's tarot light is prismatic; each card keeps its own form.
        ["paper"] = P("paper", Family.Surge, Family.Surge, Style.Light, new[] { "#5a1bd6", "#b04cff", "#ff5fd0", "#ffc94a", "#7fe8ff" }, "#ffd76a", "#fff4d8", "#7a2cff", "#ffe2a8", Mote.Card, Mote.Spark),
        ["sidestep"] = P("sidestep", Family.Twin, Family.Twin, Style.Strike, new[] { "#3a0f8f", "#8a3dff", "#ff58c8", "#ffb22e", "#fff0b0" }, "#ffd35a", "#fff6e0", "#8c2bff", "#ffd9a0", Mote.Spark, Mote.Card),
        ["mask"] = P("mask", Family.Fan, Family.Fan, Style.Control, new[] { "#0a3a66", "#1f8ad6", "#3ad6e8", "#a57bff", "#f0f4ff" }, "#dff8ff", "#ffffff", "#2aa6c8", "#e8fbff", Mote.Shard, Mote.Wisp),
        ["identity"] = P("identity", Family.Fan, Family.Fan, Style.Control, new[] { "#1a4dff", "#46b8ff", "#f4f1ff", "#ffb04a", "#ff6a1f" }, "#ffe0a0", "#ffffff", "#3b6cff", "#ffe6c2", Mote.Shard, Mote.Card),
        ["seal"] = P("seal", Family.Falling, Family.Falling, Style.Heavy, new[] { "#3b0a6e", "#9b2cff", "#ff4f9a", "#ff9a2e", "#ffe27a" }, "#ffcf5a", "#fff2d0", "#ff5a1f", "#ffd08a", Mote.Ember, Mote.Card, true),
        ["chase"] = P("chase", Family.Surge, Family.Twin, Style.Strike, new[] { "#0b3b66", "#1fb7d6", "#6af0e0", "#b58cff", "#ffffff" }, "#c9fff4", "#ffffff", "#1b9bd0", "#e6fffb", Mote.Wisp, Mote.Spark),
        ["climax"] = P("climax", Family.Crescent, Family.Crescent, Style.Heavy, Rainbow, "#ffd24a", "#fff8e0", "#ff4a14", "#ffe39a", Mote.Spark, Mote.Petal, true, 1.12f),
        ["reversal"] = P("reversal", Family.Curtain, Family.Curtain, Style.Strike, new[] { "#3a0640", "#a81f86", "#ff4fae", "#ffb04a", "#6a3cff" }, "#ffd07a", "#ffe6f4", "#c2289a", "#ffd4ec", Mote.Petal, Mote.Spark),
        ["ward"] = P("ward", Family.Rising, Family.Rising, Style.Support, new[] { "#0b5a8a", "#39c6ff", "#8ae0ff", "#ffd66b", "#ffffff" }, "#fff0b0", "#ffffff", "#2a9fe0", "#e6f8ff", Mote.Wisp, Mote.Spark),
        ["declaration"] = P("declaration", Family.Rising, Family.Rising, Style.Heavy, new[] { "#2b1466", "#6a3cff", "#c07aff", "#ffcf6a", "#fff4dc" }, "#ffd76a", "#fffaf0", "#6f3cff", "#fff0cc", Mote.Card, Mote.Shard, true),

        // Mainline enemies.
        ["guard"] = P("guard", Family.Twin, Family.Twin, Style.Strike, new[] { "#4a0610", "#c01a24", "#ff5a1e", "#ffc23a", "#fff0c0" }, "#ffcf6a", "#fff1d6", "#d8341c", "#ffd9a8", Mote.Spark, Mote.Shard),
        ["archivist"] = P("archivist", Family.Twin, Family.Falling, Style.Strike, new[] { "#081a3a", "#1a4fb8", "#2a9aff", "#ffb02a", "#fff0c0" }, "#ffd27a", "#f4fbff", "#2f86e0", "#dff4ff", Mote.Shard, Mote.Spark),
        ["fog-ghost"] = P("fog-ghost", Family.Tide, Family.Surge, Style.Strike, new[] { "#0a1f4f", "#1f66c8", "#2fc8ff", "#8a7bff", "#e6fdff" }, "#bff6ff", "#f2feff", "#1d6fd8", "#dcfbff", Mote.Wisp, Mote.Puff),
        ["crimson-ghost"] = P("crimson-ghost", Family.Tide, Family.Surge, Style.Strike, new[] { "#3a0620", "#b0124a", "#ff4f7a", "#a04cff", "#ffd0dc" }, "#ffc0cf", "#fff0f4", "#c01848", "#ffd6e0", Mote.Wisp, Mote.Puff),
        ["early-hound"] = P("early-hound", Family.Surge, Family.Surge, Style.Light, new[] { "#3a0602", "#c41a06", "#ff6a0a", "#ffb81f", "#fff0a0" }, "#ffd35a", "#fff3d0", "#ff4a0c", "#ffd08a", Mote.Ember, Mote.Spark),
        ["hound"] = P("hound", Family.Surge, Family.Tide, Style.Strike, new[] { "#4a0a04", "#d62a0a", "#ff7a14", "#ffc93a", "#fff2b0" }, "#ffd35a", "#fff3d0", "#ff4a0c", "#ffd08a", Mote.Ember, Mote.Spark),
        ["magma"] = P("magma", Family.Tide, Family.Rising, Style.Heavy, new[] { "#1a0402", "#8a1206", "#ff4a0a", "#ffa21f", "#fff0a0" }, "#ffc24a", "#fff0c8", "#ff3a08", "#ffc070", Mote.Ember, Mote.Shard),
        ["emerald"] = P("emerald", Family.Rising, Family.Surge, Style.Heavy, new[] { "#032a1a", "#0e8a4a", "#3cff8a", "#c8ff5a", "#fff6b0" }, "#d8ff7a", "#f4ffe0", "#16c85a", "#e2ffc0", Mote.Ember, Mote.Puff),
        ["mind"] = P("mind", Family.Fan, Family.Fan, Style.Strike, new[] { "#1a1454", "#4a3cd6", "#8a9cff", "#c8a8ff", "#ffe1a0" }, "#e8ecff", "#ffffff", "#5a5ae0", "#eef0ff", Mote.Card, Mote.Wisp),
        ["leech"] = P("leech", Family.Surge, Family.Rising, Style.Strike, new[] { "#200a3a", "#7a1fae", "#d85cff", "#ffd0f4", "#9fe8ff" }, "#f2c6ff", "#fff0ff", "#8a28c8", "#f6dcff", Mote.Card, Mote.Wisp),
        ["scribe"] = P("scribe", Family.Surge, Family.Twin, Style.Strike, new[] { "#12041f", "#4a148a", "#a33cff", "#ff5fb0", "#ffd36a" }, "#ffcf5a", "#f8e8ff", "#7a22d0", "#f0d4ff", Mote.Ink, Mote.Spark),
        ["executor"] = P("executor", Family.Twin, Family.Surge, Style.Heavy, new[] { "#120a04", "#5a3208", "#d68a14", "#ffd24a", "#fff6d0" }, "#ffe08a", "#fff8e8", "#d87a10", "#ffe2a8", Mote.Ink, Mote.Spark),
        ["chronarch"] = P("chronarch", Family.Falling, Family.Fan, Style.Heavy, new[] { "#2a1204", "#8a4a12", "#e89a2e", "#ffe07a", "#5ae0c8" }, "#ffd76a", "#fff4d8", "#e0821a", "#ffe4a8", Mote.Shard, Mote.Card, true, 1.08f),
        ["matriarch"] = P("matriarch", Family.Curtain, Family.Twin, Style.Strike, new[] { "#3a0412", "#c0142e", "#ff4f6a", "#ff9ab0", "#f4f6ff" }, "#f4f6ff", "#ffffff", "#d01a3a", "#ffd8e0", Mote.Petal, Mote.Spark),
        ["rescue"] = P("rescue", Family.Falling, Family.Falling, Style.Strike, new[] { "#3a1a04", "#b86a14", "#ffb23a", "#ffd86a", "#ffffff" }, "#ffe08a", "#fff8e8", "#e08a1a", "#ffe6b8", Mote.Spark, Mote.Puff),
        ["adjudicator"] = P("adjudicator", Family.Falling, Family.Falling, Style.Heavy, new[] { "#1f1206", "#6a3a12", "#d6862a", "#ffd35a", "#fff4d0" }, "#ffd76a", "#fff6e0", "#c8701a", "#ffe0a8", Mote.Shard, Mote.Puff, false, 1.08f),
        ["convoy"] = P("convoy", Family.Tide, Family.Tide, Style.Heavy, new[] { "#120c06", "#4a3212", "#b87a2a", "#ffc24a", "#fff0c0" }, "#ffd06a", "#fff4dc", "#b8661a", "#ffdca0", Mote.Shard, Mote.Puff, false, 1.08f),
        ["elite"] = P("elite", Family.Twin, Family.Falling, Style.Heavy, new[] { "#3a0608", "#b81a1a", "#ff6a2a", "#ffd24a", "#fff8e0" }, "#ffd35a", "#fff6e0", "#e0301a", "#ffd4a0", Mote.Spark, Mote.Shard, true),

        // Church tower beasts.
        ["stonehide"] = P("stonehide", Family.Falling, Family.Falling, Style.Heavy, new[] { "#1a1006", "#6a4a1a", "#d69a3a", "#ffe08a", "#fff8e0" }, "#ffd87a", "#fff6e0", "#c87a2a", "#ffe0b0", Mote.Shard, Mote.Puff),
        ["saltmaw"] = P("saltmaw", Family.Rising, Family.Fan, Style.Strike, new[] { "#0a2a3a", "#2ab8d6", "#e8ffff", "#ff9ad6", "#b58cff" }, "#ffffff", "#ffffff", "#2ab0d0", "#eaffff", Mote.Shard, Mote.Spark),
        ["salt-poison"] = P("salt-poison", Family.Tide, Family.Tide, Style.Strike, new[] { "#062a1a", "#1a8a5a", "#6affb0", "#e8ffd0", "#c8ffff" }, "#e0fff0", "#ffffff", "#1aa86a", "#e0ffe8", Mote.Puff, Mote.Ember),
        ["shellback"] = P("shellback", Family.Twin, Family.Surge, Style.Strike, new[] { "#2a0a06", "#8a2a12", "#e86a2a", "#ffc24a", "#fff0c8" }, "#ffd06a", "#fff2dc", "#d8501a", "#ffd8a8", Mote.Spark, Mote.Shard),
        ["ironclaw"] = P("ironclaw", Family.Twin, Family.Twin, Style.Strike, new[] { "#0a1a2a", "#2a6ab8", "#5ad0ff", "#ffc24a", "#ffffff" }, "#ffe08a", "#ffffff", "#3a8ad0", "#e6f8ff", Mote.Spark, Mote.Shard),
        ["frilled-naga"] = P("frilled-naga", Family.Fan, Family.Surge, Style.Strike, new[] { "#2a1a04", "#b8861a", "#ffd24a", "#fff6c0", "#4ae0c0" }, "#fff0a0", "#fffbe8", "#e0a01a", "#fff0b8", Mote.Wisp, Mote.Spark, true),
        ["boneclaw"] = P("boneclaw", Family.Crescent, Family.Twin, Style.Strike, new[] { "#0a2a2a", "#1aa8a0", "#7ae0c8", "#c8b0ff", "#ffffff" }, "#f4f0d8", "#ffffff", "#18a09a", "#eafff8", Mote.Shard, Mote.Spark),
        ["copperback"] = P("copperback", Family.Tide, Family.Falling, Style.Strike, new[] { "#1a0a04", "#8a3a12", "#e8782a", "#ffc86a", "#4ad6b8" }, "#ffd07a", "#fff2dc", "#d86a1a", "#ffdcaa", Mote.Shard, Mote.Spark),
        ["crimson-brute"] = P("crimson-brute", Family.Surge, Family.Falling, Style.Heavy, new[] { "#2a0404", "#b80c0c", "#ff4a14", "#ffb22a", "#fff0b0" }, "#ffcf4a", "#fff2d0", "#ff300c", "#ffc890", Mote.Ember, Mote.Spark),
        ["veil-oracle"] = P("veil-oracle", Family.Twin, Family.Curtain, Style.Strike, new[] { "#2a0418", "#a0124a", "#ff3a6a", "#ffb0c8", "#ffe0a0" }, "#ffd8a0", "#fff0f4", "#c8124a", "#ffd0dc", Mote.Petal, Mote.Wisp),
        ["golden-throat"] = P("golden-throat", Family.Fan, Family.Tide, Style.Strike, new[] { "#2a2a04", "#8ab81a", "#e8ff4a", "#ffd24a", "#fff8d0" }, "#fff0a0", "#fffbe0", "#b8d01a", "#fff4b0", Mote.Puff, Mote.Wisp),
        ["moonfang"] = P("moonfang", Family.Crescent, Family.Twin, Style.Strike, new[] { "#0a0a2a", "#3a4ab8", "#7a9cff", "#ffe08a", "#ffffff" }, "#f4f6ff", "#ffffff", "#4a5ad0", "#eef2ff", Mote.Spark, Mote.Shard),

        // Wanted bosses.
        ["bounty-b01"] = P("bounty-b01", Family.Twin, Family.Twin, Style.Heavy, new[] { "#2a0408", "#9a1020", "#e8484a", "#9ab0d0", "#ffffff" }, "#f0f4ff", "#ffffff", "#c01a24", "#ffd8d8", Mote.Spark, Mote.Shard),
        ["bounty-b02"] = P("bounty-b02", Family.Rising, Family.Falling, Style.Heavy, new[] { "#2a1804", "#a8741a", "#ffc83a", "#fff2b0", "#ffffff" }, "#ffe08a", "#fffbe8", "#e0a01a", "#fff0c0", Mote.Card, Mote.Spark, true),
        ["bounty-b03"] = P("bounty-b03", Family.Tide, Family.Surge, Style.Heavy, new[] { "#041a3a", "#0a5aa0", "#1fc8e0", "#6ae8ff", "#ffffff" }, "#e0ffff", "#ffffff", "#0a7ac8", "#dcfaff", Mote.Puff, Mote.Spark),
        ["bounty-b04"] = P("bounty-b04", Family.Surge, Family.Falling, Style.Heavy, new[] { "#0e0418", "#3a148a", "#8a3cff", "#ff8a3a", "#ffe08a" }, "#ffcf6a", "#f8ecff", "#6a22d0", "#f0dcff", Mote.Ink, Mote.Card),
        ["bounty-b05"] = P("bounty-b05", Family.Twin, Family.Curtain, Style.Strike, new[] { "#2a0206", "#b00a1e", "#ff3a4a", "#ffc0c8", "#ffe8a0" }, "#ffd0a0", "#fff0f0", "#d0101e", "#ffd0d4", Mote.Petal, Mote.Spark),
        ["bounty-b06"] = P("bounty-b06", Family.Falling, Family.Tide, Style.Heavy, new[] { "#040e1f", "#12386a", "#3a8ab8", "#bfe8f8", "#ffffff" }, "#dff4ff", "#ffffff", "#1a5a9a", "#dcefff", Mote.Shard, Mote.Puff, false, 1.08f),
        ["bounty-b07"] = P("bounty-b07", Family.Fan, Family.Tide, Style.Strike, new[] { "#2a1a02", "#c8861a", "#ffc83a", "#9aff5a", "#fff8d0" }, "#fff0a0", "#fffbe0", "#e0a01a", "#fff0b8", Mote.Wisp, Mote.Puff, true),
        ["bounty-b08"] = P("bounty-b08", Family.Twin, Family.Twin, Style.Heavy, new[] { "#5a6aa8", "#ff7ac0", "#7ad0ff", "#c89cff", "#ffffff" }, "#ffffff", "#ffffff", "#8a9ac8", "#f4f8ff", Mote.Shard, Mote.Spark),
        ["bounty-b09"] = P("bounty-b09", Family.Twin, Family.Surge, Style.Heavy, new[] { "#1a0804", "#7a2a0a", "#d8661a", "#ffc24a", "#fff0c0" }, "#ffd06a", "#fff4e0", "#c8501a", "#ffd8a0", Mote.Shard, Mote.Spark),
        ["bounty-b10"] = P("bounty-b10", Family.Curtain, Family.Crescent, Style.Heavy, new[] { "#2a0212", "#a00a3a", "#ff2a5a", "#ff9ab8", "#ffe0a0" }, "#ffd0a0", "#fff0f4", "#d0103a", "#ffd0dc", Mote.Petal, Mote.Wisp, false, 1.08f),

        // Support semantics.
        ["heal"] = P("heal", Family.Rising, Family.Rising, Style.Support, new[] { "#0a4a3a", "#1ac89a", "#6affc8", "#ffe08a", "#ffffff" }, "#fff0b0", "#ffffff", "#18b88a", "#e0fff4", Mote.Petal, Mote.Spark),
        ["heal-crimson"] = P("heal-crimson", Family.Rising, Family.Rising, Style.Support, new[] { "#4a0a1a", "#d03a6a", "#ffb0c8", "#ffffff", "#ffe08a" }, "#ffe0b0", "#ffffff", "#d03a6a", "#ffe4ec", Mote.Petal, Mote.Wisp),
        ["enemy-ward"] = P("enemy-ward", Family.Rising, Family.Rising, Style.Support, new[] { "#0a1640", "#1f4fc8", "#3aa8ff", "#ffb83a", "#fff2c8" }, "#ffe0a0", "#ffffff", "#3a7ad0", "#e4f2ff", Mote.Shard, Mote.Wisp),
        ["relic-mask"] = P("relic-mask", Family.Rising, Family.Rising, Style.Support, new[] { "#1a0f3a", "#5a3cc8", "#9a8cff", "#e8e4ff", "#ffd88a" }, "#ffe6a8", "#ffffff", "#5a4ad0", "#eeeaff", Mote.Card, Mote.Wisp),
        ["stone-ward"] = P("stone-ward", Family.Rising, Family.Rising, Style.Support, new[] { "#1a1006", "#6a4a1a", "#d69a3a", "#ffe08a", "#fff8e0" }, "#ffd87a", "#fff6e0", "#c87a2a", "#ffe0b0", Mote.Shard, Mote.Spark),
        ["anchor-ward"] = P("anchor-ward", Family.Rising, Family.Rising, Style.Support, new[] { "#040e1f", "#12386a", "#2a7ac8", "#8ad8ff", "#ffffff" }, "#dff4ff", "#ffffff", "#1a5a9a", "#dcefff", Mote.Shard, Mote.Wisp),
        ["poison-field"] = P("poison-field", Family.Rising, Family.Rising, Style.Support, new[] { "#022414", "#0a7a3a", "#2ae86a", "#b8ff4a", "#f0ffb0" }, "#d8ff7a", "#f4ffe0", "#16b04a", "#d8ffb0", Mote.Puff, Mote.Ember),
        ["escort-ward"] = P("escort-ward", Family.Rising, Family.Rising, Style.Support, new[] { "#041a3a", "#0a5aa0", "#1fc8e0", "#6ae8ff", "#ffffff" }, "#e0ffff", "#ffffff", "#0a7ac8", "#dcfaff", Mote.Wisp, Mote.Spark),
        ["empower"] = P("empower", Family.Rising, Family.Rising, Style.Support, new[] { "#3a1a04", "#d8861a", "#ffd24a", "#fff6d0", "#ff6a3a" }, "#fff0a0", "#ffffff", "#e0901a", "#fff0c8", Mote.Ember, Mote.Spark),
    };

    static Profile PlayerProfile(string skillID)
    {
        string key = skillID switch
        {
            "basic" => "paper",
            "defend" => "ward",
            "fool_skill_01" => "sidestep",
            "fool_skill_02" => "mask",
            "fool_skill_04" => "identity",
            "fool_skill_05" => "seal",
            "fool_skill_06" => "chase",
            "fool_skill_07" => "climax",
            "fool_skill_08" => "reversal",
            "fool_skill_09" => "ward",
            "fool_skill_10" => "declaration",
            _ => "paper",
        };
        return Profiles[key];
    }

    static bool IsPreparation(string intent)
    {
        if (string.IsNullOrEmpty(intent)) return false;
        if (intent == "thirteenth_charge") return false; // charged strike, contacts the player
        return intent == "charge" || intent.EndsWith("_charge", StringComparison.Ordinal)
            || intent == "bounty_mirror" || intent == "bounty_armor";
    }

    static Profile EnemyProfile(string actorID, string intent, string modelID)
    {
        actorID = actorID ?? ""; modelID = modelID ?? ""; intent = intent ?? "strike";
        string id = actorID + ":" + modelID;
        bool crimsonBoss = id.Contains("bounty-b10") || id.Contains("bounty_b10");
        if (intent == "repair_guard" || intent == "tower_mend" || intent == "bounty_transfer" || intent.Contains("mend"))
            return Profiles[crimsonBoss ? "heal-crimson" : "heal"];
        if (intent == "tower_empower") return Profiles["empower"];
        if (intent == "guard" || intent == "fortify" || intent == "calibrate" || intent == "calibration" || intent == "tower_armor")
            return Profiles["enemy-ward"];
        for (int i = 1; i <= 10; i++)
        {
            string b = "bounty-b" + i.ToString("00");
            if (id.Contains(b) || id.Contains("bounty_b" + i.ToString("00"))) return Profiles[b];
        }
        if (intent.Contains("poison") || intent.Contains("spittle"))
            return Profiles[id.Contains("saltmaw") ? "salt-poison" : "emerald"];
        if (intent == "thirteenth_charge") return Profiles["elite"];
        foreach (var key in new[] { "executor", "chronarch", "matriarch", "scribe", "adjudicator", "convoy", "rescue", "archivist",
                     "fog-ghost", "crimson-ghost", "stonehide", "saltmaw", "shellback", "ironclaw", "frilled-naga", "boneclaw",
                     "copperback", "crimson-brute", "veil-oracle", "golden-throat", "moonfang" })
            if (id.Contains(key)) return Profiles[key];
        if (id.Contains("early-hell-hound")) return Profiles["early-hound"];
        if (id.Contains("emerald")) return Profiles["emerald"];
        if (id.Contains("armored-hell") || id.Contains("armored_hell")) return Profiles["magma"];
        if (id.Contains("hound") || id.Contains("emberwolf")) return Profiles["hound"];
        if (id.Contains("leech")) return Profiles["leech"];
        if (id.Contains("clock-core") || id.Contains("memory")) return Profiles["mind"];
        if (id.Contains("ghost") || id.Contains("wraith")) return Profiles["fog-ghost"];
        return Profiles["guard"];
    }

    static Style EnemyStyle(Profile p, string intent, string modelID)
    {
        if (p.style == Style.Support) return Style.Support;
        intent = intent ?? "strike";
        if (intent.Contains("heavy") || intent.Contains("second") || intent.Contains("slam") || intent == "thirteenth_charge"
            || intent == "name_devour" || intent == "overwrite" || intent == "bind" || intent.Contains("silk_bind")
            || intent.Contains("true_stab") || intent.Contains("rend"))
            return Style.Heavy;
        if (intent.Contains("first") || intent == "ambush") return p.style == Style.Heavy ? Style.Strike : p.style;
        return p.style;
    }
}
