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
    public enum Family { Crescent, Rising, Falling, Surge, Fan, Twin, Curtain, Tide, MirrorCut }
    public enum Style { Light, Strike, Heavy, Support, Control }
    /// Row in SpectacleMatter; each matter has its own edge, darkness, flow and flicker.
    public enum Matter { Filigree = 0, Flame = 1, Water = 2, Crystal = 3, Silk = 4, Ink = 5, Electric = 6, Smoke = 7 }
    /// Signature element that belongs to one identity, on top of its body.
    public enum Accent { None, Lightning, Cracks, Vortex, Wings, Orbit, Shards, Splatter, Foam,
        // Signature moves: whirlwind, sword qi, sword rain, meteor shower, ground spikes, coiling dragon, lotus bloom.
        Tornado, SwordQi, SwordRain, Meteor, Spikes, Dragon, Lotus }
    /// Glint and Twinkle are the four-point star glints (tools/vfx-spectacle-20260926/glints.py).
    enum Mote { Spark = 0, Ember = 1, Shard = 2, Ink = 3, Petal = 4, Card = 5, Wisp = 6, Puff = 7, Glint = 8, Twinkle = 9 }
    /// How a hero card reaches its target. Bloom is the original contact-only
    /// burst; the others leave the hero during the cast, travel the corridor to
    /// the target and land on the contact receipt (2026-10-03: attacks must read
    /// as aimed at the enemy, each card with its own form, not a screen-wide bloom).
    public enum Form { Bloom, Throw, Hunt, Rain, Dash, Flick }
    /// 错步穿行 cuts each further target this long after the previous one (visual only).
    const float DashChainStep = .12f;

    sealed class Profile
    {
        public string id;
        public Family family, familyAlt;
        public Style style;
        public Color[] ramp;
        public Color line, core, wash, hot;
        public Mote mote, mote2;
        public Matter matter;
        public Accent accent;
        public bool column;
        public float scale = 1f, rampSpan = 1f, wobble;
        public Form form = Form.Bloom;
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
        public bool player;
        /// Travelling bodies of a hero form, finished early if the contact comes first.
        public readonly List<Body> launch = new List<Body>();
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
    /// Drawn after the battle backdrop (queue 1000) and before the illustrated hero
    /// (Transparent, 3000): light behind the figure and the sigil under its feet,
    /// so the hero stands in front of its own glow.
    Material sweepUnderMaterial, flareUnderMaterial;
    Texture2D matterAtlas, noise, atlas;
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

    /// <param name="expectedContact">Seconds from now to the contact receipt when the
    /// caller knows it (tempo samples); hero forms time their travel to land on it.</param>
    public static void BeginPlayer(Component battle, string skillID, Func<Vector3> caster, IList<Func<Vector3>> targets, IList<int> targetSeeds, float expectedContact = -1f)
    {
        var director = Ensure(battle);
        if (!director || targets == null || targets.Count == 0) return;
        var profile = PlayerProfile(skillID);
        var cue = director.Register("player", profile, profile.style, caster, targets, targetSeeds);
        if (cue == null) return;
        cue.player = true;
        if (profile.form != Form.Bloom && !Suppressed) director.Launch(cue, expectedContact);
    }

    /// True when the hero card has its own travelling form; the tempo samples then
    /// show only this layer for it, without the older full-stage theatre bodies.
    public static bool HasForm(string skillID) => PlayerProfile(skillID).form != Form.Bloom;

    /// Light coming off the hero while it casts (2026-10-03, user, with the reference
    /// battles: 出技能时主角本身就要冒出各种光). Built once at the cast from the figure
    /// as drawn: <paramref name="chest"/> and <paramref name="feet"/> of the hero.
    public static void CastLight(Component battle, string skillID, Func<Vector3> chest, Func<Vector3> feet, float expectedContact = -1f)
    {
        var director = Ensure(battle);
        if (!director || Suppressed || chest == null || feet == null) return;
        director.HeroLight(PlayerProfile(skillID), skillID == "basic", SafeEval(chest), SafeEval(feet), expectedContact);
    }

    /// Logs launch and impact geometry (SPELLFORM lines) for Simulator review builds.
    public static bool Diagnostics = Debug.isDebugBuild;

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
        // Wanted bosses reuse other enemies' art templates (B04 executor, B06
        // adjudicator); their identity lives on the bounty presentation.
        // The emerald revenant replaces a hound's body from the battle object.
        var revenant = battle.GetComponent<EmeraldRevenantPresentation>();
        if (revenant && revenant.InstalledHandle == actor) model = "emerald";
        var bounty = actor.GetComponent<BountyIdentityPresentation20260917>();
        if (bounty && !string.IsNullOrEmpty(bounty.bountyID) && bounty.bountyID.Length >= 3)
            model = "bounty-" + bounty.bountyID.Substring(0, 3);
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
        if (Diagnostics) Debug.Log($"SPELLFORM contact {actor} {cue.profile.id} t={Time.unscaledTime:F3} launched={cue.launch.Count}");
        // A hero card's cue serves its own hits only: a multi-hit card lands within a
        // fraction of a second, while a later basic attack (tempo samples register no
        // cue for it) must not replay the card's landing.
        if (cue.player) cue.expiresAt = Mathf.Min(cue.expiresAt, Time.unscaledTime + .45f);
        // A contact that arrives before the thrown body finishes its flight
        // completes the flight at once, so the impact never lands ahead of it.
        foreach (var body in cue.launch) if (body) body.Hasten(.06f);
        cue.launch.Clear();
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
        if (sweepUnderMaterial) Destroy(sweepUnderMaterial);
        if (flareUnderMaterial) Destroy(flareUnderMaterial);
    }

    // ------------------------------------------------------------ setup

    Cue Register(string key, Profile profile, Style style, Func<Vector3> caster, IList<Func<Vector3>> targets, IList<int> seeds)
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
        if (cue.targets.Count == 0) return null;
        pending[key] = cue;
        return cue;
    }

    bool Load()
    {
        if (sweepMaterial) return true;
        var sweep = Resources.Load<Shader>("SpellSpectacle20260926/SpectacleSweep");
        var washShader = Resources.Load<Shader>("SpellSpectacle20260926/SpectacleWash");
        var flare = Resources.Load<Shader>("SpellSpectacle20260926/SpectacleFlare");
        matterAtlas = Resources.Load<Texture2D>("SpellSpectacle20260926/SpectacleMatter");
        noise = Resources.Load<Texture2D>("SpellSpectacle20260926/SpectacleNoise");
        atlas = Resources.Load<Texture2D>("SpellSpectacle20260926/SpectacleAtlas");
        if (!sweep || !washShader || !flare || !matterAtlas || !noise || !atlas)
        {
            Debug.LogWarning("SPELL_SPECTACLE_MISSING_RESOURCE");
            return false;
        }
        sweepMaterial = new Material(sweep) { name = "SpectacleSweep" };
        sweepMaterial.SetTexture("_Matter", matterAtlas);
        sweepMaterial.SetTexture("_Noise", noise);
        washMaterial = new Material(washShader) { name = "SpectacleWash" };
        washMaterial.SetTexture("_Noise", noise);
        flareMaterial = new Material(flare) { name = "SpectacleFlare" };
        flareMaterial.SetTexture("_MainTex", atlas);
        sweepUnderMaterial = new Material(sweepMaterial) { name = "SpectacleSweepUnder", renderQueue = 2990 };
        flareUnderMaterial = new Material(flareMaterial) { name = "SpectacleFlareUnder", renderQueue = 2990 };
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
        if (p.form != Form.Bloom && cue.player)
        {
            FormImpact(cue, cam, caster, points);
            return;
        }
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
        // Only the ultimate may tint the whole screen; hero cards stay on their target.
        if (cue.player && p.id != "declaration") return;
        if (!wash) wash = Wash.Create(root, washMaterial, this);
        wash.Trigger(mean, p.wash, p.hot, amount, style == Style.Support ? .2f : style == Style.Light ? .18f : style == Style.Heavy ? .34f : .26f, style == Style.Support ? .6f : .46f);
    }

    // ------------------------------------------------------------ hero cast light

    /// While the hero casts, light comes off the figure itself, as in the reference
    /// battles: an aura behind it (drawn before the hero, so it rims the silhouette),
    /// the identity's matter rising off the body, four-point glints popping on it, a
    /// flash at the hand when the card leaves with light thrown out from the chest, and
    /// under the feet a sigil of broken arcs (never a closed ring) turning on the floor.
    /// It builds to the release and is gone soon after. A basic attack keeps only a
    /// small aura, two glints and the hand flash: it is the beat between cards.
    void HeroLight(Profile p, bool basic, Vector3 chest, Vector3 feet, float expectedContact)
    {
        var cam = Camera.main;
        if (!cam || !Load()) return;
        float contact = expectedContact > 0 ? expectedContact : p.form != Form.Bloom ? .55f : .7f;
        // Same release as Launch: the card leaves the hand when its travel starts.
        float release = Mathf.Max(.14f, contact - Mathf.Clamp(contact * .45f, .22f, .42f));
        // Figure height as drawn: the chest sits at 62% of it above the feet.
        float h = Mathf.Max(.3f, (chest.y - feet.y) / .62f);
        castCount.TryGetValue("light" + p.id, out int n);
        castCount["light" + p.id] = n + 1;
        var rng = new System.Random(StableHash(p.id) * 13 + n * 7 + 5);
        Vector3 right = cam.transform.right, up = Vector3.up;
        var toCam = -cam.transform.forward; toCam.y = 0;
        toCam = toCam.sqrMagnitude > 1e-6f ? toCam.normalized : Vector3.back;
        var hand = chest + right * .14f * h;
        if (Diagnostics) Debug.Log($"SPELLFORM light {p.id} t={Time.unscaledTime:F3} release={release:F3} chest={chest:F2} feet={feet:F2} h={h:F2}");
        var floor = new Vector3(feet.x, feet.y + .02f, feet.z);
        Flares.Create(root, flareUnderMaterial, this).Aura(p, feet + up * .55f * h, floor, right, h, release, basic, rng);
        Flares.Create(root, flareMaterial, this).CastSparkle(p, feet, chest, hand, right, up, toCam, h, release, basic, rng);
        if (basic) return;
        var ramp = Ramp(p);
        var gx = right; gx.y = 0;
        gx = gx.sqrMagnitude > 1e-6f ? gx.normalized : Vector3.right;
        var gz = Vector3.Cross(gx, Vector3.up);
        // Light streaming off the hero: four fine rays leave the figure at the shoulders, back
        // and sides and shoot straight up and outward, each at its own angle, length and time,
        // so they fan instead of standing parallel. Drawn before the figure, they show round
        // its outline. Thin, soft-edged and smooth (silk look) with a hot core:
        // - 169.50-169.60: five broad tongues of the identity's matter hid the hero and read
        //   as cracked glass (user on 169.60: 我不喜欢这2个的样子);
        // - 169.62: threads wound round the figure read from the camera as oval frames;
        // - 169.66: curving, swaying wisps (user: 你很多都设置成这样弯弯的，都改掉吧).
        for (int k = 0; k < 4; k++)
        {
            float sideSign = k % 2 == 0 ? 1f : -1f;
            var start = feet + Vector3.up * R(rng, .38f, .82f) * h + gx * sideSign * R(rng, .08f, .2f) * h - toCam * R(rng, 0f, .12f) * h;
            var dir = (Vector3.up + gx * sideSign * R(rng, .2f, .7f) - toCam * R(rng, 0f, .2f)).normalized;
            float length = R(rng, .6f, 1.05f) * h, width = R(rng, .03f, .045f) * h;
            Func<float, Vector3> pos = t => start + dir * (length * t);
            var ray = Make(20, pos, FacingAcross(pos, toCam), t => width * Mathf.Min(1f, t * 6f) * Mathf.Pow(1f - t, .8f), toCam);
            ray.look = Matter.Silk; ray.rigid = true; ray.solidStart = true; ray.delay = R(rng, 0f, .12f) + k * .03f;
            ray.revealScale = Mathf.Max(.15f, release * .9f - ray.delay) / .12f; ray.holdScale = .25f / .12f;
            ray.coreAmt = 2f; ray.tile = 1.2f; ray.opacity = .7f;
            ray.rampShift = p.ramp.Length > 5 ? R(rng, -.45f, .45f) : R(rng, 0f, .3f);
            Body.Create(root, sweepUnderMaterial, this).Setup(Dispersing(ray, h * .2f, .35f, .15f, 0f, true), start, ramp, p, Style.Strike, ray.delay, (float)rng.NextDouble() * 10f, 45 + k);
        }
        // The sigil: an inner band of long arcs and an outer band of short ones, turning
        // opposite ways, each band left open (it never closes into a ring). Seen from the
        // low camera the floor is foreshortened, so the bands are wide to stay readable.
        float hold = Mathf.Max(.1f, release + .12f - .18f);
        for (int band = 0; band < 2; band++)
        {
            float radius = h * (band == 0 ? R(rng, .42f, .52f) : R(rng, .74f, .88f));
            float spin = (band == 0 ? 1f : -1f) * R(rng, 22f, 40f) * (n % 2 == 0 ? 1f : -1f);
            float a = R(rng, 0f, 6.283f), end = a + R(rng, 5.1f, 5.8f);
            for (int k = 0; a < end && k < 9; k++)
            {
                float span = Mathf.Min(band == 0 ? R(rng, 1f, 1.75f) : R(rng, .25f, .7f), end - a);
                float a0 = a, r0 = radius * R(rng, .96f, 1.04f), w = h * (band == 0 ? R(rng, .05f, .07f) : R(rng, .03f, .045f));
                Func<float, Vector3> radial = t => { float ang = a0 + span * t; return Mathf.Cos(ang) * gx + Mathf.Sin(ang) * gz; };
                var arc = Make(Mathf.Max(8, Mathf.RoundToInt(span * 14f)), t => floor + radial(t) * r0, radial, t => w * Swell(t, .35f), Vector3.up);
                arc.rigid = true; arc.spin = spin; arc.spinAxis = Vector3.up; arc.delay = band * .05f + k * .02f; arc.look = Matter.Silk;
                // Heavy timing base: reveal .15 s, hold .16 s.
                arc.revealScale = 1.2f; arc.holdScale = hold / .16f; arc.coreAmt = 2.6f; arc.opacity = .95f; arc.tile = 1.4f; arc.bulgeAmount = 0f;
                // A rainbow identity gives every arc its own hue.
                arc.rampShift = p.ramp.Length > 5 ? R(rng, -.45f, .45f) : R(rng, .05f, .35f);
                Body.Create(root, sweepUnderMaterial, this).Setup(Dispersing(arc, h * .25f, .4f, .25f, 0f, true), floor, ramp, p, Style.Heavy, arc.delay, (float)rng.NextDouble() * 10f, 40 + band);
                a += span + (band == 0 ? R(rng, .3f, .7f) : R(rng, .18f, .42f));
            }
        }
    }

    // ------------------------------------------------------------ hero forms

    /// A hero form leaves the caster during the cast's drive and travels the
    /// corridor to its target, timed to land on the contact receipt. The travel
    /// is presentation only: the contact time, damage and target never move.
    void Launch(Cue cue, float expectedContact)
    {
        var cam = Camera.main;
        if (!cam || !Load() || cue.targets.Count == 0) return;
        var p = cue.profile;
        float contact = expectedContact > 0 ? expectedContact : .55f;
        float travel = Mathf.Clamp(contact * .45f, .22f, .42f);
        // A volley spreads its landings around the contact instead of after it.
        float spread = p.form == Form.Rain ? .12f : 0f;
        float start = Mathf.Max(0f, contact - travel - spread);
        Vector3 caster = SafeEval(cue.caster);
        var ramp = Ramp(p);
        var heads = Flares.Create(root, flareMaterial, this);
        if (Diagnostics)
            Debug.Log($"SPELLFORM launch {p.id} t={Time.unscaledTime:F3} contact={contact:F3} travel={travel:F3} start={start:F3} caster={caster:F2} target={SafeEval(cue.targets[0]):F2} cam={cam.transform.position:F2} fov={cam.fieldOfView:F1}");
        for (int i = 0; i < cue.targets.Count; i++)
        {
            Vector3 target = SafeEval(cue.targets[i]);
            var rng = new System.Random(cue.seeds[i] * 17 + cue.cast * 5 + 3);
            float half = Vector3.Distance(cam.transform.position, target) * Mathf.Tan(cam.fieldOfView * .5f * Mathf.Deg2Rad);
            // A dash cuts its further targets on the way through: each leg starts at the
            // previous target, after the contact.
            bool chained = p.form == Form.Dash && i > 0;
            var frame = new Frame(cam, chained ? SafeEval(cue.targets[i - 1]) : caster, target, half / 4.5f * p.scale, rng);
            if (Diagnostics) Debug.Log($"SPELLFORM frame {p.id} s={frame.s:F2} dir={frame.dir:F2} right={frame.right:F2}");
            var shots = LaunchShots(p.form, frame, travel, contact, rng, chained ? i : 0);
            // A dash runs from the hero's feet straight away from the camera, so its floor glint,
            // prints and motes lie behind the figure; drawn over it they stacked as a line and
            // bars across the hero's coat (169.60). Under the figure, the figure covers them.
            bool behind = p.form == Form.Dash;
            var trail = behind ? Flares.Create(root, flareUnderMaterial, this) : heads;
            for (int n = 0; n < shots.Count; n++)
            {
                // A bystander of a group card gets half the volley, so three never swamp the screen.
                if (i > 0 && p.form == Form.Rain && n % 2 == 1) continue;
                var shot = shots[n];
                float at = (shot.at >= 0 ? shot.at : start + shot.delay) + (shot.chained ? 0f : i * .03f);
                var path = shot.path;
                path.rigid = true;
                path.revealScale = shot.time / BaseReveal(cue.style);
                path.solidStart = true;
                if (path.revealEase <= 0) path.revealEase = 1f;
                if (Diagnostics) Debug.Log($"SPELLFORM shot {p.id} at={at:F3} time={shot.time:F3} from={shot.from:F2} end={path.points[path.points.Length - 1]:F2}");
                var body = Body.Create(root, behind ? sweepUnderMaterial : sweepMaterial, this);
                body.Setup(path, path.pivot ?? frame.target, ramp, p, cue.style, at, (float)rng.NextDouble() * 10f, 20 + cue.launch.Count);
                // A chained leg runs after the contact; hastening it would cut the whole chain at once.
                if (!shot.chained) cue.launch.Add(body);
                foreach (var strand in shot.strands)
                {
                    strand.rigid = true;
                    strand.revealScale = shot.time / BaseReveal(cue.style);
                    strand.holdScale = path.holdScale;
                    strand.revealEase = path.revealEase;
                    var braid = Body.Create(root, sweepMaterial, this);
                    braid.Setup(strand, path.pivot ?? frame.target, ramp, p, cue.style, at, (float)rng.NextDouble() * 10f, 21 + cue.launch.Count);
                    cue.launch.Add(braid);
                }
                var headColor = Color.Lerp(p.core, p.hot, .5f);
                if (shot.star && shot.headSize > 0) heads.ProjectileStar(shot.from, shot.vel, shot.gravity, at, shot.time, shot.headSize * 2.2f, Color.Lerp(p.hot, p.line, .4f), rng);
                if (shot.headSize > 0) heads.Projectile(shot.from, shot.vel, shot.gravity, at, shot.time, shot.headSize, shot.head, headColor, shot.stretch, shot.spin);
                if (shot.course != null && shot.sparks > 0)
                    trail.Wake(p, shot.course, at, shot.time, frame.s, shot.sparks, shot.spark, rng);
                if (shot.course != null && shot.stream > 0)
                    trail.Stream(p, shot.course, at, shot.time, frame.s, shot.stream, shot.spark, rng);
                if (shot.course != null && shot.glow > 0)
                    trail.Follow(shot.course, at, shot.time, shot.glow * frame.s, Color.Lerp(p.hot, p.line, .35f), rng);
                if (shot.course != null && shot.twinkles > 0)
                    trail.Twinkles(p, shot.course, at, shot.time, frame.s, shot.twinkles, rng);
                foreach (var footprint in shot.prints)
                    trail.Footprint(p, footprint.at, at + footprint.when, footprint.heading, frame.s, rng);
            }
        }
    }

    /// One travelling element: a trail along a ballistic or straight course and the
    /// bright head that flies the same course, so the eye can follow it to the target.
    sealed class Shot
    {
        public Path path;
        public Vector3 from, vel;
        public float gravity, time, delay, headSize, stretch, spin;
        public Mote head;
        /// Strands wound round the main band, revealed with it.
        public readonly List<Path> strands = new List<Path>();
        /// Where the head is at u in [0,1] of its flight, for the spark wake.
        public Func<float, Vector3> course;
        public int sparks;
        public Mote spark = Mote.Spark;
        public bool star = true;
        /// Flowing light (2026-10-03, user: 过程要有流光): motes riding the course behind
        /// the head, a glow riding with an element that has no bright head of its own
        /// (size in s), and four-point glints popping along the course as it passes.
        public int stream, twinkles;
        public float glow;
        /// Seconds after the cast when this element leaves; negative: timed to land on the contact.
        public float at = -1f;
        /// A leg that runs after the contact (a dash cutting a further target).
        public bool chained;
        /// Ground marks that light up as the runner passes: position, seconds after leaving, heading.
        public readonly List<(Vector3 at, float when, float heading)> prints = new List<(Vector3, float, float)>();
    }

    /// Two strands winding round a course in opposite phase, closing in on the target,
    /// so a launch reads as braided coloured matter rather than one thin line.
    static IEnumerable<Path> Strands(Func<float, Vector3> pos, float radius, float width, float turns, int n)
    {
        for (int k = 0; k < 2; k++)
        {
            float phase = k * Mathf.PI;
            Func<float, Vector3> sp = u =>
            {
                var tangent = pos(Mathf.Min(1, u + .01f)) - pos(Mathf.Max(0, u - .01f));
                tangent = tangent.sqrMagnitude > 1e-8f ? tangent.normalized : Vector3.forward;
                var side = Vector3.Cross(tangent, Vector3.up);
                side = side.sqrMagnitude > 1e-6f ? side.normalized : Vector3.right;
                var lift = Vector3.Cross(side, tangent);
                float a = phase + turns * 2f * Mathf.PI * u;
                float r = radius * Mathf.Lerp(1f, .3f, u);
                return pos(u) + (side * Mathf.Cos(a) + lift * Mathf.Sin(a)) * r;
            };
            var strand = Make(n, sp, FacingAcross(sp, Vector3.up), u => width * (.6f + .4f * u), Vector3.up);
            strand.solidStart = true; strand.rampShift = k == 0 ? .28f : -.22f; strand.coreAmt = 1.3f; strand.tile = 3f;
            yield return strand;
        }
    }

    /// Arc from 'from' that lands on 'to' after 'time' seconds and rises 'height' above the chord.
    static (Vector3 vel, float g) Ballistic(Vector3 from, Vector3 to, float time, float height)
    {
        float g = 8f * height / (time * time);
        return ((to - from) / time + Vector3.up * (.5f * g * time), g);
    }

    static Vector3 BallisticAt(Vector3 from, Vector3 vel, float g, float t) => from + vel * t + Vector3.down * (.5f * g * t * t);

    List<Shot> LaunchShots(Form form, Frame f, float travel, float contact, System.Random rng, int chainIndex = 0)
    {
        var list = new List<Shot>();
        float s = f.s;
        var lateral = Vector3.Cross(Vector3.up, f.dir).normalized;
        switch (form)
        {
            case Form.Throw:
            {
                // The wax seal leaves the raised card hand on a low arc, dragging a
                // thick red streak braided with two brighter strands and an ember wake.
                // Low: with the camera far behind, height pushes the arc onto the enemy.
                var from = f.caster + f.right * .2f * s + f.up * .04f * s;
                var to = f.target + f.up * .05f * s;
                var (vel, g) = Ballistic(from, to, travel, .16f * s);
                Func<float, Vector3> pos = u => BallisticAt(from, vel, g, u * travel);
                var trail = Make(48, pos, FacingAcross(pos, f.toCam), u => s * (.16f + .1f * u), f.toCam);
                // Kept to the bright half of the wax ramp: the dark reds vanish over the floor.
                trail.pivot = to; trail.coreAmt = 2f; trail.tile = 2.2f; trail.holdScale = .45f; trail.rampShift = .35f; trail.rampSpan = .65f;
                var shot = new Shot { path = trail, from = from, vel = vel, gravity = g, time = travel, headSize = .34f * s, head = Mote.Ember, stretch = .03f, course = pos, sparks = 28, spark = Mote.Ember, stream = 26, twinkles = 4 };
                foreach (var strand in Strands(pos, .15f * s, .045f * s, .45f, 48)) { strand.pivot = to; shot.strands.Add(strand); }
                list.Add(shot);
                break;
            }
            case Form.Hunt:
            {
                // Two hero-shaped shadows (HeroArcanaTheatreVFX) run at the target; each
                // leaves a flat smoke wake under its own course, revealed at its own pace
                // (they leave at .14 s and .24 s and accelerate in, like the shadows do).
                var flatRight = f.right; flatRight.y = 0; flatRight = flatRight.sqrMagnitude > 1e-6f ? flatRight.normalized : lateral;
                var from = new Vector3(f.caster.x, .04f * s, f.caster.z);
                var to = new Vector3(f.target.x, .04f * s, f.target.z);
                for (int k = 0; k < 2; k++)
                {
                    float swing = k == 0 ? -.64f : .53f, leave = .14f + k * .1f, time = Mathf.Max(.12f, contact - leave);
                    Func<float, Vector3> pos = u => Vector3.Lerp(from, to, u) + flatRight * swing * Mathf.Sin(Mathf.PI * Mathf.Pow(u, 1f / 2.4f));
                    var wake = Make(44, pos, FacingAcross(pos, Vector3.up), u => s * (.07f + .06f * u) * (1 - .6f * Mathf.Pow(u, 6f)), Vector3.up);
                    wake.pivot = to; wake.coreAmt = 1.1f; wake.tile = 1.6f; wake.holdScale = .35f; wake.rampShift = .15f * k; wake.opacity = .9f; wake.revealEase = 2.4f;
                    Func<float, Vector3> chest = u => pos(Mathf.Pow(u, 2.4f)) + Vector3.up * .9f * s;
                    var shot = new Shot { path = wake, from = chest(0), vel = Vector3.zero, gravity = 0f, time = time, at = leave, headSize = 0f, head = Mote.Wisp, course = chest, sparks = 22, spark = Mote.Spark, star = false,
                        stream = 16, glow = .55f, twinkles = 2 };
                    list.Add(shot);
                }
                break;
            }
            case Form.Flick:
            {
                // The basic attack's flying tarot (FoolBasicTarotVFX) leaves the hand at .16 s and
                // lands at the .58 s contact on a slight bow; a gold-violet streak and sparks
                // follow it so the beat reads from the low camera.
                var from = f.caster + f.right * .12f * s;
                var to = f.target;
                var bow = -f.right * .24f + Vector3.up * .16f;
                float leave = .16f, time = Mathf.Max(.15f, contact - leave);
                Func<float, Vector3> pos = u => Vector3.Lerp(from, to, u) + bow * Mathf.Sin(Mathf.PI * u);
                var streak = Make(32, pos, FacingAcross(pos, f.toCam), u => s * (.06f + .06f * u), f.toCam);
                streak.pivot = to; streak.coreAmt = 2.4f; streak.tile = 2f; streak.holdScale = .3f; streak.rampShift = .3f;
                // Flowing light behind the card: two bright strands braided round the streak,
                // a glow riding with the card, a stream of motes and glints along the way.
                var shot = new Shot { path = streak, from = from, time = time, at = leave, headSize = 0f, star = false, course = pos, sparks = 14, spark = Mote.Spark,
                    stream = 26, glow = .6f, twinkles = 4 };
                foreach (var strand in Strands(pos, .1f * s, .028f * s, .45f, 32)) { strand.pivot = to; strand.coreAmt = 2f; shot.strands.Add(strand); }
                list.Add(shot);
                break;
            }
            case Form.Dash:
            {
                // 错步穿行: the hero's afterimage dashes in (HeroArcanaTheatreVFX, lead target
                // only). Here staggered mirror footprints light up under its course as it
                // passes, a low mirror glint skims the floor and shards are shed. A further
                // target is cut on the way through: the leg turns from the previous target.
                bool chained = chainIndex > 0;
                var from = new Vector3(f.caster.x, .03f * s, f.caster.z);
                var to = new Vector3(f.target.x, .03f * s, f.target.z);
                var along = to - from; along.y = 0;
                var flat = along.sqrMagnitude > 1e-4f ? along.normalized : f.dir;
                var side = Vector3.Cross(Vector3.up, flat);
                // The lead leg keeps the afterimage's small sidestep; a turn bends either way.
                float bend = chained ? R(rng, -.3f, .3f) * s : -.16f * s;
                Func<float, Vector3> pos = u => Vector3.Lerp(from, to, u) + side * bend * Mathf.Sin(Mathf.PI * u);
                float leave = chained ? contact + (chainIndex - 1) * DashChainStep : .05f;
                float time = chained ? DashChainStep : Mathf.Max(.15f, contact - .05f);
                // The afterimage covers distance as (t/T)^1.5; the glint and prints keep its pace.
                float ease = chained ? 1f : 1.5f;
                var glint = Make(40, pos, FacingAcross(pos, Vector3.up), u => s * (.035f + .03f * u), Vector3.up);
                glint.pivot = to; glint.coreAmt = 2f; glint.tile = 2.4f; glint.holdScale = .25f; glint.opacity = .9f; glint.revealEase = ease;
                var shot = new Shot { path = glint, from = from, time = time, at = leave, headSize = 0f, star = false,
                    course = u => pos(Mathf.Pow(u, ease)) + Vector3.up * .25f * s, sparks = chained ? 8 : 16, spark = Mote.Shard, chained = chained,
                    stream = chained ? 5 : 14, glow = chained ? .35f : .5f, twinkles = chained ? 1 : 3 };
                int prints = chained ? 3 : 10;
                float heading = Mathf.Atan2(flat.z, flat.x) * Mathf.Rad2Deg;
                for (int k = 0; k < prints; k++)
                {
                    float u = (k + .6f) / (prints + .4f);
                    // Left, right, left: a mirror-step gait, a little uneven.
                    var at = pos(u) + side * (k % 2 == 0 ? 1f : -1f) * R(rng, .07f, .11f) * s;
                    shot.prints.Add((at, time * Mathf.Pow(u, 1f / ease), heading + R(rng, -14f, 14f)));
                }
                list.Add(shot);
                break;
            }
            case Form.Rain:
            {
                // Stage props leave from beside the hero at chest height in a volley and come
                // down on the target on low arcs, every other one braided, all with a spark wake.
                for (int i = 0; i < 6; i++)
                {
                    float side = i % 2 == 0 ? -1f : 1f;
                    var from = f.caster + f.up * R(rng, -.05f, .08f) * s + lateral * side * R(rng, .15f, .38f) * s;
                    var to = f.Foot + Vector3.up * R(rng, .25f, .75f) * s + lateral * R(rng, -.5f, .5f) * s + f.Depth * R(rng, -.3f, .3f) * s;
                    float time = travel * R(rng, .9f, 1.05f);
                    var (vel, g) = Ballistic(from, to, time, R(rng, .12f, .26f) * s);
                    Func<float, Vector3> pos = u => BallisticAt(from, vel, g, u * time);
                    var prop = Make(40, pos, FacingAcross(pos, f.toCam), u => s * (.09f + .07f * u), f.toCam);
                    // Fades as soon as its prop lands, so the volley never stands as parallel bars.
                    prop.pivot = to; prop.coreAmt = 1.5f; prop.tile = 1.4f; prop.holdScale = .05f; prop.rampShift = R(rng, -.3f, .3f);
                    var shot = new Shot { path = prop, from = from, vel = vel, gravity = g, time = time, delay = i * .04f, headSize = .26f * s, head = Mote.Card, stretch = 0f, spin = R(rng, 400f, 720f) * side, course = pos, sparks = 14, spark = i % 2 == 0 ? Mote.Spark : Mote.Petal, star = i % 2 == 0,
                        stream = i % 2 == 0 ? 8 : 0, twinkles = i % 2 == 0 ? 1 : 0 };
                    if (i % 2 == 0) foreach (var strand in Strands(pos, .12f * s, .035f * s, 2f, 40)) { strand.pivot = to; shot.strands.Add(strand); }
                    list.Add(shot);
                }
                break;
            }
        }
        return list;
    }

    /// The landing of a hero form: compact, around the target, opening forward
    /// (away from the hero) instead of a screen-wide bloom.
    void FormImpact(Cue cue, Camera cam, Vector3 caster, List<Vector3> points)
    {
        var p = cue.profile;
        var ramp = Ramp(p);
        for (int i = 0; i < points.Count; i++)
        {
            var rng = new System.Random(cue.seeds[i] * 31 + cue.cast * 7 + 11);
            float half = Vector3.Distance(cam.transform.position, points[i]) * Mathf.Tan(cam.fieldOfView * .5f * Mathf.Deg2Rad);
            // A flicked basic card lands small: it is the steady beat between cards, not a spell.
            // On the phone .55 read too small (2026-10-03): landings open to .8, a basic to .55.
            var frame = new Frame(cam, caster, points[i], half / 4.5f * p.scale * (p.form == Form.Flick ? .55f : .8f), rng);
            // A dash cuts its targets one after another; other forms land together.
            float delay = i * (p.form == Form.Dash ? DashChainStep : .035f);
            if (Diagnostics) Debug.Log($"SPELLFORM impact {p.id} t={Time.unscaledTime:F3} at={points[i]:F2} s={frame.s:F2}");
            // One layer of the identity's own form keeps the old layered brilliance around
            // the main target. A thrown seal has none: its family falls from over the top.
            // A basic has none either: on the phone that wave read as one solid lump landing
            // on the enemy (2026-10-03); its contact bursts open instead (below).
            // Bystanders of a group card get only the landing itself.
            // The dash's crossed cut is kept small so the afterimage, not the blades, carries it.
            var familyFrame = p.form == Form.Dash ? new Frame(cam, caster, points[i], frame.s * .75f, rng) : frame;
            var family = p.form == Form.Throw || p.form == Form.Flick || i > 0 ? new List<Path>() : Paths(p.family, familyFrame, 1, rng);
            for (int k = 0; k < family.Count; k++)
            {
                var body = Body.Create(root, sweepMaterial, this);
                // A cut of light drifts a little, thins and breaks into motes; pushed like the
                // other bodies it writhed into wavy ribbons (169.62-169.63).
                bool cut = p.family == Family.MirrorCut;
                body.Setup(Dispersing(family[k], frame.s, 1f, cut ? .2f : .55f, cut ? .02f : .35f, cut), frame.target, ramp, p, cue.style, delay + .03f + family[k].delay, (float)rng.NextDouble() * 10f, k);
            }
            if (p.family == Family.MirrorCut && family.Count > 0)
            {
                var glints = Flares.Create(root, flareMaterial, this);
                foreach (var cut in family)
                    glints.AlongCut(p, cut.points, delay + .03f + cut.delay, BaseReveal(cue.style) * cut.revealScale, familyFrame.s, rng);
            }
            var accents = AccentPaths(p.accent, frame, cue.style, rng);
            for (int k = 0; k < accents.Count; k++)
            {
                var body = Body.Create(root, sweepMaterial, this);
                body.Setup(Dispersing(accents[k], frame.s), accents[k].pivot ?? frame.target, ramp, p, cue.style, delay + accents[k].delay, (float)rng.NextDouble() * 10f, 10 + k);
            }
            foreach (var path in ImpactPaths(p.form, frame, rng))
            {
                var body = Body.Create(root, sweepMaterial, this);
                body.Setup(Dispersing(path, frame.s), path.pivot ?? frame.target, ramp, p, cue.style, delay + path.delay, (float)rng.NextDouble() * 10f, 30);
                if (path.impactAt is Vector3 at)
                {
                    var landing = Flares.Create(root, flareMaterial, this);
                    landing.Impact(p, at, frame, delay + path.delay + BaseReveal(cue.style) * path.revealScale, rng, false);
                }
            }
            var flares = Flares.Create(root, flareMaterial, this);
            flares.Build(p, cue.style, frame, rng, delay, true, true);
            // Every contact bursts open (2026-10-03, user on the phone: 所有这种击中也要有一定的
            // 炸裂开，不需要全屏，半屏): spikes of the identity's matter and light thrown out
            // across the screen plane to about half the screen width (a basic a little less,
            // the finale a little less as its rainbow arc already spans wide; in a group each
            // target less, so three never fill the screen), expanding at once and gone within
            // about half a second. Sizes from the Simulator frames of 169.48, where .5 opened
            // only to about 40% of the width.
            float halfWidth = half * cam.aspect;
            // In the tower a group card's three bursts at .7/.45 still spanned the screen (169.49).
            float reach = halfWidth * (p.form == Form.Flick ? .5f : p.form == Form.Rain ? .55f : .62f) * (points.Count > 1 ? (i == 0 ? .6f : .4f) : 1f);
            foreach (var spike in BurstSpikes(p, frame, reach, i == 0, rng))
                // Thin spikes drift out calmly: pulled like the bodies they curled into tentacles (169.67).
                Body.Create(root, sweepMaterial, this).Setup(Dispersing(spike, frame.s, 1f, .55f, .02f, true), spike.pivot ?? frame.target, ramp, p, cue.style, delay + spike.delay, (float)rng.NextDouble() * 10f, 50);
            Flares.Create(root, flareMaterial, this).Explode(p, frame, reach, delay, i == 0, rng);
        }
    }

    /// The bursting silhouette of a contact: tapered spikes of the identity's matter
    /// thrown out from the target across the screen plane, at uneven angles and lengths
    /// (never a regular star). Crystal stays straight, flame and smoke curl, a rainbow
    /// identity gives each spike its own hue; a basic throws fewer and slimmer ones.
    List<Path> BurstSpikes(Profile p, Frame f, float reach, bool lead, System.Random rng)
    {
        var list = new List<Path>();
        int n = p.form == Form.Rain ? 10 : p.form == Form.Flick || p.form == Form.Dash ? 6 : 8;
        if (!lead) n = Mathf.Max(4, n / 2);
        if (ReducedMotion) n = Mathf.Max(3, n * 2 / 3);
        // The dash's spikes are slim, slightly curved rays of light (silk look), not crystal wedges (169.60).
        bool rays = p.form == Form.Dash;
        // Near-straight for every matter: flame and smoke spikes bent by .32 read as curls (169.68 seal).
        float curl = rays ? .05f : p.matter == Matter.Crystal ? .02f : .06f;
        float slim = p.form == Form.Flick ? .75f : rays ? .55f : 1f;
        var centre = f.target + f.toCam * .25f * f.s;
        float a0 = R(rng, 0f, 6.283f);
        for (int k = 0; k < n; k++)
        {
            float ang = a0 + 6.283f * (k + R(rng, -.32f, .32f)) / n;
            var d = Mathf.Cos(ang) * f.right + Mathf.Sin(ang) * f.up;
            var side = Vector3.Cross(d, f.toCam).normalized;
            float len = reach * R(rng, .55f, .98f) * (k % 3 == 1 ? .78f : 1f);
            float w = reach * R(rng, .055f, .1f) * slim, bend = R(rng, -curl, curl) * len;
            var a = centre + d * .08f * reach;
            Func<float, Vector3> pos = t => a + d * (len * t) + side * (bend * t * t);
            var spike = Make(16, pos, FacingAcross(pos, f.toCam), t => w * Mathf.Pow(1f - t, 1.25f) * Mathf.Min(1f, .35f + t * 7f), f.toCam);
            spike.pivot = centre; spike.rigid = true; spike.solidStart = true;
            spike.revealScale = .55f; spike.holdScale = .55f; spike.coreAmt = 1.7f; spike.tile = 1.3f;
            spike.delay = R(rng, 0f, .03f);
            spike.rampShift = p.ramp.Length > 5 ? R(rng, -.45f, .45f) : R(rng, 0f, .3f);
            if (rays) { spike.look = Matter.Silk; spike.coreAmt = 2.2f; spike.opacity = .7f; }
            list.Add(spike);
        }
        return list;
    }

    List<Path> ImpactPaths(Form form, Frame f, System.Random rng)
    {
        var list = new List<Path>();
        float s = f.s;
        var foot = f.Foot;
        var lateral = Vector3.Cross(Vector3.up, f.dir).normalized;
        switch (form)
        {
            case Form.Throw:
            {
                // The seal slams down on the target from above.
                var top = f.target + f.up * 1.6f * s - f.dir * .15f * s;
                var bottom = f.target - f.up * .25f * s;
                var slam = Make(24, t => Vector3.Lerp(top, bottom, t), _ => f.right, t => s * (.18f + .3f * Mathf.Pow(t, 1.8f)), f.toCam);
                slam.pivot = bottom; slam.offset = f.up * 1.2f * s; slam.rigid = true; slam.revealScale = .7f; slam.holdScale = .6f; slam.coreAmt = 1.6f; slam.impactAt = foot;
                list.Add(slam);
                // Wax splashes forward, away from the hero, in an uneven fan.
                for (int i = 0; i < 5; i++)
                {
                    float ang = Mathf.Lerp(-38f, 38f, (i + R(rng, -.3f, .3f)) / 4f) * Mathf.Deg2Rad;
                    var d = (Mathf.Cos(ang) * f.dir + Mathf.Sin(ang) * lateral).normalized;
                    float len = R(rng, .7f, 1.25f) * s, w = R(rng, .14f, .22f) * s;
                    var a = foot + d * .15f * s; var b = foot + d * len;
                    var across = Vector3.Cross(Vector3.up, d);
                    var splash = Make(20, t => Vector3.Lerp(a, b, t) + Vector3.up * .06f * s * Swell(t, 1f), _ => across, t => w * Swell(t, .5f) * (1 - .4f * t), Vector3.up);
                    splash.pivot = a; splash.delay = .04f + i * .012f; splash.rigid = true; splash.revealScale = .9f; splash.holdScale = 2.5f; splash.coreAmt = .4f; splash.tile = 1.2f;
                    list.Add(splash);
                }
                // The imprint stays on the ground in broken arcs, never a full ring.
                var gz = f.Depth;
                for (int k = 0; k < 3; k++)
                {
                    float r = R(rng, .5f, .72f) * s, a0 = (k * 120 + R(rng, 0, 30)) * Mathf.Deg2Rad, span = R(rng, 70, 100) * Mathf.Deg2Rad;
                    Func<float, Vector3> pos = t => { float a = a0 + span * t; return foot + (Mathf.Cos(a) * f.right + Mathf.Sin(a) * gz) * r + Vector3.up * .02f; };
                    var mark = Make(30, pos, t => { float a = a0 + span * t; return Mathf.Cos(a) * f.right + Mathf.Sin(a) * gz; }, t => s * .06f * Swell(t, .4f), Vector3.up);
                    mark.pivot = foot; mark.delay = .08f; mark.rigid = true; mark.revealScale = 1.4f; mark.holdScale = 6f; mark.coreAmt = .9f; mark.opacity = .9f;
                    list.Add(mark);
                }
                break;
            }
            case Form.Hunt:
            {
                // The first shadow grazes across the target; the second bites in a cross.
                var c = f.target;
                var g0 = c - lateral * .9f * s + f.up * .5f * s; var g1 = c + lateral * .9f * s - f.up * .35f * s;
                var gacross = Vector3.Cross(g1 - g0, f.toCam);
                var graze = Make(26, t => Vector3.Lerp(g0, g1, t) + f.toCam * .2f * s * Swell(t, 1f), _ => gacross, t => s * .1f * Swell(t, .6f), f.toCam);
                graze.pivot = c; graze.rigid = true; graze.revealScale = .7f; graze.holdScale = .5f; graze.coreAmt = 1.2f;
                list.Add(graze);
                for (int k = 0; k < 2; k++)
                {
                    float sx = k == 0 ? 1 : -1;
                    var a = c + lateral * sx * .75f * s + f.up * .7f * s; var b = c - lateral * sx * .55f * s - f.up * .45f * s;
                    var bend = f.toCam * .35f * s;
                    Func<float, Vector3> pos = t => Vector3.Lerp(a, b, t) + bend * Swell(t, 1f);
                    var bite = Make(28, pos, FacingAcross(pos, f.toCam), t => s * .2f * Swell(t, .55f), f.toCam);
                    bite.pivot = c; bite.delay = .09f + k * .035f; bite.rigid = true; bite.revealScale = .65f; bite.holdScale = .7f; bite.coreAmt = 1.4f; bite.rampShift = .15f;
                    list.Add(bite);
                }
                break;
            }
            case Form.Dash:
            {
                // The runner cuts past and out the far side: a mirror scuff on the floor
                // continuing beyond the target, bending a little as it slows.
                var a = foot - f.dir * .2f * s;
                var b = foot + f.dir * 1.25f * s + lateral * R(rng, -.25f, .25f) * s;
                Func<float, Vector3> pos = t => Vector3.Lerp(a, b, t) + Vector3.up * .02f;
                var scuff = Make(28, pos, FacingAcross(pos, Vector3.up), t => s * .09f * Swell(t, .5f) * (1 - .5f * t), Vector3.up);
                scuff.pivot = foot; scuff.rigid = true; scuff.revealScale = .7f; scuff.holdScale = 2.2f; scuff.coreAmt = 1.6f; scuff.tile = 2f;
                list.Add(scuff);
                break;
            }
            case Form.Flick:
            {
                // The flicked card's nick: one short bright cut across the target, nothing more.
                var a = f.target - lateral * .35f * s + f.up * .2f * s;
                var b = f.target + lateral * .35f * s - f.up * .15f * s;
                Func<float, Vector3> pos = t => Vector3.Lerp(a, b, t) + f.toCam * .1f * s * Swell(t, 1f);
                var nick = Make(18, pos, FacingAcross(pos, f.toCam), t => s * .07f * Swell(t, .6f), f.toCam);
                nick.pivot = f.target; nick.rigid = true; nick.revealScale = .6f; nick.holdScale = .6f; nick.coreAmt = 1.8f;
                list.Add(nick);
                break;
            }
            case Form.Rain:
            {
                // A spotlight rises from the target's feet: a narrow column, not a dome.
                var top = foot + Vector3.up * 3.4f * s;
                var beam = Make(30, t => Vector3.Lerp(foot, top, t), _ => f.right, t => s * (.42f - .16f * t) * Swell(Mathf.Min(1f, t * 1.1f), .3f), f.toCam);
                beam.pivot = foot; beam.rigid = true; beam.revealScale = 1.2f; beam.holdScale = 1.4f; beam.coreAmt = 1.1f; beam.opacity = .8f; beam.tile = 1.5f;
                list.Add(beam);
                // Two curtains swing shut at the target's sides.
                for (int k = 0; k < 2; k++)
                {
                    float sx = k == 0 ? -1 : 1;
                    var hang = foot + lateral * sx * .95f * s + Vector3.up * 2.4f * s;
                    var hem = foot + lateral * sx * .75f * s + Vector3.up * .05f * s;
                    float wave = R(rng, 0f, 3f);
                    Func<float, Vector3> pos = t => Vector3.Lerp(hang, hem, t);
                    var drape = Make(26, pos, _ => lateral * -sx, t => s * (.34f + .12f * t), f.toCam);
                    drape.anchored = true; drape.pivot = hang; drape.swing = sx * 35f; drape.swingAxis = Vector3.up; drape.delay = .05f;
                    drape.revealScale = 1.3f; drape.holdScale = 1.2f; drape.coreAmt = .5f; drape.rampShift = .3f * k; drape.tile = 1.3f;
                    list.Add(drape);
                }
                break;
            }
        }
        return list;
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
        // The coiling dragon is the subject; keep only one light companion body.
        bool dragon = p.accent == Accent.Dragon;
        if (dragon) layers = 1;
        var ramp = Ramp(p);
        // A lotus bloom is the whole support body; tongues would hide the petals.
        var paths = p.accent == Accent.Lotus ? new List<Path>() : Paths(family, frame, layers, rng);
        for (int k = 0; k < paths.Count; k++)
        {
            paths[k].wobble = p.wobble * frame.s;
            var body = Body.Create(root, sweepMaterial, this);
            float bodyDelay = delay + paths[k].delay;
            body.Setup(paths[k], frame.target, ramp, p, style, bodyDelay, (float)rng.NextDouble() * 10f, k);
        }
        // Strike and heavy casts also open one body of the identity's second
        // form, so a hit reads as layered matter rather than a single sweep.
        if (!dragon && (style == Style.Strike || style == Style.Heavy) && p.familyAlt != family)
        {
            var extra = Paths(p.familyAlt, frame, 1, rng);
            for (int k = 0; k < Mathf.Min(2, extra.Count); k++)
            {
                var body = Body.Create(root, sweepMaterial, this);
                extra[k].rampShift += .18f;
                body.Setup(extra[k], frame.target, ramp, p, style, delay + .045f + extra[k].delay, (float)rng.NextDouble() * 10f, 4 + k);
            }
        }
        if (!dragon && p.column && style != Style.Light)
        {
            var col = Column(frame, rng);
            var body = Body.Create(root, sweepMaterial, this);
            body.Setup(col, frame.target, ramp, p, style == Style.Support ? Style.Support : Style.Heavy, delay + .02f, (float)rng.NextDouble() * 10f, 7);
        }
        // The identity's signature element (bolts, ground cracks, vortex, wings).
        var accentPaths = AccentPaths(p.accent, frame, style, rng);
        Flares impacts = null;
        for (int k = 0; k < accentPaths.Count; k++)
        {
            var body = Body.Create(root, sweepMaterial, this);
            body.Setup(accentPaths[k], accentPaths[k].pivot ?? frame.target, ramp, p, style, delay + accentPaths[k].delay, (float)rng.NextDouble() * 10f, 10 + k);
            if (accentPaths[k].impactAt is Vector3 at)
            {
                if (!impacts) impacts = Flares.Create(root, flareMaterial, this);
                impacts.Impact(p, at, frame, delay + accentPaths[k].delay + BaseReveal(style) * accentPaths[k].revealScale, rng, p.accent == Accent.Meteor || p.accent == Accent.Dragon);
            }
        }
    }

    static float BaseReveal(Style style) => style switch
    {
        Style.Heavy => .15f, Style.Strike => .12f, Style.Light => .10f, Style.Support => .30f, _ => .16f
    };

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
        /// Ground point under the target and the horizontal axis pointing into the screen.
        public Vector3 Foot => new Vector3(target.x, .03f, target.z);
        public Vector3 Depth { get { var d = Vector3.Cross(right, Vector3.up); d.y = 0; return d.sqrMagnitude > 1e-6f ? d.normalized : Vector3.forward; } }
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
        // Motion and look overrides used by the signature elements.
        public Vector3? pivot;               // rotation/scale centre (wing shoulder, vortex eye)
        public Vector3 offset;               // starts displaced, settles at contact
        public Vector3 spinAxis, swingAxis;
        public float spin, swing;            // deg/s continuous spin; deg folded -> open swing
        public float revealScale = 1f, holdScale = 1f, flicker, coreAmt = -1f, wobble, opacity = -1f;
        public bool shrink;                  // pulled inward while it lives
        public bool rigid;                   // keeps its size: blades, meteors, spikes
        public Vector3 drift;                // keeps travelling after it arrives (sword qi)
        public Vector3? impactAt;            // flare + debris when it arrives (landing blade, meteor)
        public bool solidStart;              // no fade-in at the first 12%: a launch must be seen leaving the hero
        public float revealEase;             // 0: fast ease-out; otherwise grow^revealEase (1 keeps pace with a flying head)
        public bool disperseCalm;            // drifts out with little push and swirl (a cut of light thins, it does not writhe)
        public Matter? look;                 // drawn with this matter's look instead of the identity's (light, not material)
        public bool disperse;                // spreads out, lifts and breaks into drifting motes as it fades
        public float disperseSize;           // world size of the effect (s), for the spread and the motes
        public float disperseDensity;        // share of the full mote count
        public float disperseGrowth;         // how much larger it grows while fading
        public float disperseStretch;        // share of its own extent each vertex is pulled apart by
    }

    /// Landing and cast-light bodies spread out and break into drifting motes as they fade,
    /// instead of standing whole and vanishing in place (2026-10-03, user on the phone,
    /// pointing at a basic attack's landing: 我要的是这类效果散开，消散，才够自然; then:
    /// at the end of the fade the whole shape must be gone, not still readable).
    /// The hero's cast light disperses smaller, sparser and closer: at full strength its
    /// motes filled the Q4 corridor between the hero and the hound (169.53).
    static Path Dispersing(Path path, float size, float density = 1f, float growth = .55f, float stretch = .35f, bool calm = false)
    {
        path.disperse = true; path.disperseSize = size; path.disperseDensity = density; path.disperseGrowth = growth; path.disperseStretch = stretch;
        path.disperseCalm = calm;
        return path;
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
                        t => width * Swell(t, .45f), f.toCam);
                    path.delay = k * .03f; path.rampShift = -.1f * k; path.rampSpan = 1.05f; path.tile = 3.2f;
                    list.Add(path);
                }
                break;
            }
            case Family.Rising:
            {
                // Tongues that shoot straight up from the recipient and taper, fanned out at
                // uneven angles and heights, broad side to camera. They used to climb in
                // S-curves, which read on the phone as wavy streamers (2026-10-03, user on the phone: 你很多都设置成这样弯弯的，都改掉吧).
                int tongues = layers + 1;
                for (int k = 0; k < tongues; k++)
                {
                    float x0 = (k - (tongues - 1) * .5f) * R(rng, .55f, .8f) * s;
                    // Fanned wide: at .25-.45 they still stood near-parallel (169.67 emerald on the hero).
                    float lean = x0 * R(rng, .7f, 1.1f) + R(rng, -.6f, .6f) * s;
                    float height = R(rng, 3.4f, 4.6f) * s * (k == tongues / 2 ? 1.15f : 1f), depth = R(rng, -.4f, .4f) * s;
                    float width = R(rng, .5f, .72f) * s;
                    var t2 = f.target;
                    Func<float, Vector3> pos = t => t2 + f.right * (x0 * (1 - .3f * t) + lean * t) + f.up * (-.9f * s + height * t) + f.toCam * depth;
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
                    // A shallow arc: bent by .28-.5 of their length the cuts read as curls (2026-10-03).
                    float length = (k == 0 ? 4.1f : k == 1 ? 3.2f : 3.6f) * s, bend = R(rng, .08f, .16f) * (k % 2 == 0 ? 1 : -1);
                    var centre = f.target + f.up * .45f * s + f.toCam * .2f * s * k;
                    Func<float, Vector3> pos = t => centre + (t - .5f) * length * d + perp * bend * length * .5f * (1 - Mathf.Pow(2 * t - 1, 2));
                    var path = Make(56, pos, _ => perp, t => s * (.58f - .08f * k) * Swell(t, .55f) * (1 + .45f * Mathf.Exp(-Mathf.Pow((t - .6f) / .16f, 2))), f.toCam);
                    path.delay = k * .055f; path.rampShift = .12f * k; path.tile = 3.6f; path.revealScale = .45f;
                    list.Add(path);
                }
                break;
            }
            case Family.MirrorCut:
            {
                // Mirror cuts (错步): two long, slender crescents of light crossing in an X
                // through the target and a short third across them, each a hot core thinning
                // to needle points, drawn in one fast stroke. Light, not glass: Twin's crossed
                // crystal slabs read on the phone as panels of cracked glass (169.60, user:
                // 我不喜欢这2个的样子).
                float tilt = R(rng, 34f, 48f);
                for (int k = 0; k < 3; k++)
                {
                    float deg = k == 0 ? tilt : k == 1 ? -tilt - R(rng, 4f, 12f) : R(rng, -14f, 14f);
                    float ang = deg * Mathf.Deg2Rad * f.side;
                    var d = (Mathf.Cos(ang) * f.right + Mathf.Sin(ang) * f.up).normalized;
                    var perp = Vector3.Cross(d, f.toCam).normalized;
                    float length = (k == 0 ? R(rng, 3.8f, 4.4f) : k == 1 ? R(rng, 3.4f, 3.9f) : R(rng, 2.2f, 2.6f)) * s;
                    float bend = R(rng, .05f, .1f) * (k % 2 == 0 ? 1 : -1), thick = (k == 2 ? .1f : .17f) * s;
                    var centre = f.target + f.up * .4f * s + f.toCam * (.15f + .1f * k) * s + d * R(rng, -.2f, .2f) * s;
                    Func<float, Vector3> pos = t => centre + (t - .5f) * length * d + perp * bend * length * .5f * (1 - Mathf.Pow(2 * t - 1, 2));
                    var cut = Make(48, pos, _ => perp, t => thick * Mathf.Pow(Swell(t, 1f), 1.6f) * (1 + .5f * Mathf.Exp(-Mathf.Pow((t - .55f) / .12f, 2))), f.toCam);
                    cut.look = Matter.Silk; cut.rigid = true; cut.coreAmt = 3f; cut.tile = 2.2f;
                    cut.revealScale = .35f; cut.holdScale = .7f;
                    cut.delay = k == 2 ? .09f : k * .05f; cut.rampShift = R(rng, .05f, .3f) + .1f * k;
                    list.Add(cut);
                }
                break;
            }
            case Family.Curtain:
            {
                int folds = 2 + layers;
                for (int k = 0; k < folds; k++)
                {
                    float x = (k - (folds - 1) * .5f) * R(rng, .8f, 1.15f) * s + R(rng, -.2f, .2f) * s;
                    // Straight drapes, each with its own slant and twist (no sine sway: 2026-10-03, user on the phone: 你很多都设置成这样弯弯的，都改掉吧).
                    float top = R(rng, 3.4f, 5.2f) * s, slant = R(rng, -.9f, .9f) * s, twist = R(rng, -.5f, .5f), depth = R(rng, -.6f, .6f) * s, width = R(rng, .55f, .8f) * s;
                    var t2 = f.target;
                    Func<float, Vector3> pos = t => t2 + f.right * (x + slant * t) + f.up * (top * (1 - t) - .8f * s) + f.toCam * depth;
                    var path = Make(48, pos, t => f.right + f.toCam * twist, t => width * Swell(t, .35f) * (1 + .35f * t), f.toCam);
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
        // Straight, leaning (no sine sway or rolling twist: 2026-10-03, user on the phone: 你很多都设置成这样弯弯的，都改掉吧).
        Func<float, Vector3> pos = t => t2 + f.up * (-.85f * s + height * t) + f.right * (lean * t);
        var path = Make(40, pos, t => f.right * Mathf.Cos(phase) + f.toCam * Mathf.Sin(phase) * .6f,
            t => s * .5f * (1 - .6f * t) * (.55f + .45f * Mathf.Sin(Mathf.PI * Mathf.Pow(t, .35f))), f.toCam);
        path.tile = 1.3f; path.rampShift = .25f; path.rampSpan = .6f;
        return path;
    }

    // ------------------------------------------------------------ signature elements

    static Path Polyline(List<Vector3> pts, Vector3 toCam, float h0, float h1, Func<float, Vector3> across = null)
    {
        int n = pts.Count;
        Func<float, Vector3> pos = t =>
        {
            float x = Mathf.Clamp01(t) * (n - 1);
            int i = Mathf.Min((int)x, n - 2);
            return Vector3.Lerp(pts[i], pts[i + 1], x - i);
        };
        return Make(Mathf.Max(24, n * 3), pos, across ?? FacingAcross(pos, toCam), t => Mathf.Lerp(h0, h1, t) * (.35f + .65f * Swell(Mathf.Pow(t, .25f), .5f)), toCam);
    }

    // Midpoint displacement in the camera plane: a jagged bolt, never a straight bar.
    static List<Vector3> Jag(Vector3 a, Vector3 b, Vector3 toCam, System.Random rng, int levels, float disp)
    {
        var pts = new List<Vector3> { a, b };
        float amount = disp;
        for (int l = 0; l < levels; l++)
        {
            var next = new List<Vector3>();
            for (int i = 0; i < pts.Count - 1; i++)
            {
                var seg = pts[i + 1] - pts[i];
                var perp = Vector3.Cross(seg, toCam).normalized;
                next.Add(pts[i]);
                next.Add((pts[i] + pts[i + 1]) * .5f + perp * seg.magnitude * amount * R(rng, -1, 1));
            }
            next.Add(pts[pts.Count - 1]);
            pts = next;
            amount *= .58f;
        }
        return pts;
    }

    List<Path> AccentPaths(Accent accent, Frame f, Style style, System.Random rng)
    {
        var list = new List<Path>();
        float s = f.s;
        bool light = style == Style.Light;
        switch (accent)
        {
            case Accent.Lightning:
            {
                int bolts = style == Style.Heavy ? 4 : light ? 2 : 3;
                for (int b = 0; b < bolts; b++)
                {
                    var start = b == 0 && Vector3.Distance(f.caster, f.target) > 2f * s
                        ? Vector3.Lerp(f.caster, f.target, .12f) + f.up * .3f * s
                        : f.target + f.up * R(rng, 3.8f, 5.4f) * s + f.right * R(rng, -2.4f, 2.4f) * s + f.toCam * R(rng, 0, .4f) * s;
                    var end = f.target + f.right * R(rng, -.35f, .35f) * s + f.up * R(rng, -.45f, .25f) * s;
                    var pts = Jag(start, end, f.toCam, rng, 5, .24f);
                    var bolt = Polyline(pts, f.toCam, .3f * s, .2f * s);
                    bolt.coreAmt = 4.5f; bolt.revealScale = .4f; bolt.holdScale = 1.1f; bolt.flicker = .6f; bolt.tile = 3f; bolt.opacity = .55f;
                    bolt.delay = b * .04f + R(rng, 0, .03f);
                    list.Add(bolt);
                    for (int k = 0; k < 2; k++)
                    {
                        int at = Mathf.Clamp((int)(pts.Count * R(rng, .3f, .8f)), 1, pts.Count - 2);
                        var dir = (pts[at + 1] - pts[at - 1]).normalized;
                        var side = Vector3.Cross(dir, f.toCam).normalized * (k == 0 ? 1 : -1);
                        var tip = pts[at] + (dir * .6f + side * .8f).normalized * R(rng, .8f, 1.7f) * s;
                        var branch = Polyline(Jag(pts[at], tip, f.toCam, rng, 4, .3f), f.toCam, .14f * s, .05f * s);
                        branch.coreAmt = 4f; branch.revealScale = .4f; branch.holdScale = .9f; branch.flicker = .6f; branch.opacity = .55f;
                        branch.delay = bolt.delay + .025f;
                        list.Add(branch);
                    }
                }
                break;
            }
            case Accent.Cracks:
            {
                // Fissures run outward over the ground from the recipient's feet,
                // at uneven angles and lengths, some forking.
                var foot = new Vector3(f.target.x, .03f, f.target.z);
                var gx = f.right; gx.y = 0; gx.Normalize();
                var gz = Vector3.Cross(gx, Vector3.up);
                int rays = style == Style.Heavy ? 7 : light ? 3 : 5;
                float heading = R(rng, 0, 6.28f);
                for (int r = 0; r < rays; r++)
                {
                    heading += R(rng, .6f, 1.4f);
                    float len = R(rng, 1.5f, 3.4f) * s, h = heading;
                    var pts = new List<Vector3> { foot };
                    var pnt = foot;
                    for (int k = 0; k < 10; k++)
                    {
                        h += R(rng, -.45f, .45f);
                        pnt += (Mathf.Cos(h) * gx + Mathf.Sin(h) * gz) * len / 10f * R(rng, .7f, 1.3f);
                        pts.Add(pnt);
                    }
                    var crack = Polyline(pts, f.toCam, .15f * s, .03f * s, null);
                    FlattenAcross(crack);
                    crack.coreAmt = 1.6f; crack.revealScale = 1.5f; crack.holdScale = 2f; crack.tile = 1.6f;
                    crack.delay = r * .018f;
                    list.Add(crack);
                    if (rng.NextDouble() < .55)
                    {
                        int at = rng.Next(3, 7);
                        float bh = h + (rng.NextDouble() < .5 ? -1 : 1) * R(rng, .5f, .9f);
                        var bpts = new List<Vector3> { pts[at] };
                        var bp = pts[at];
                        for (int k = 0; k < 4; k++) { bh += R(rng, -.4f, .4f); bp += (Mathf.Cos(bh) * gx + Mathf.Sin(bh) * gz) * len / 12f; bpts.Add(bp); }
                        var fork = Polyline(bpts, f.toCam, .06f * s, .02f * s);
                        FlattenAcross(fork);
                        fork.coreAmt = 1.4f; fork.revealScale = 1.2f; fork.holdScale = 2f; fork.delay = crack.delay + .08f;
                        list.Add(fork);
                    }
                }
                break;
            }
            case Accent.Vortex:
            {
                // Arms spiral into the recipient and keep turning while pulled inward.
                var sUp = Vector3.Cross(f.right, f.toCam).normalized;
                int arms = style == Style.Heavy ? 4 : 3;
                // Well under one turn per arm so it never reads as nested rings.
                float a0 = R(rng, 0, 6.28f), turn = (rng.NextDouble() < .5 ? -1 : 1) * R(rng, .5f, .72f) * 6.283f;
                var eye = f.target + f.up * .1f * s;
                for (int k = 0; k < arms; k++)
                {
                    float th0 = a0 + 6.283f * k / arms + R(rng, -.5f, .5f), rOut = R(rng, 2.1f, 2.9f) * s;
                    Func<float, Vector3> pos = t =>
                    {
                        float th = th0 + turn * t, r = Mathf.Lerp(rOut, .18f * s, Mathf.Pow(t, .7f));
                        return eye + r * (Mathf.Cos(th) * f.right + Mathf.Sin(th) * sUp) + f.toCam * (.3f * s * (1 - t));
                    };
                    float w0 = R(rng, .55f, .8f);
                    var arm = Make(56, pos, FacingAcross(pos, f.toCam), t => s * (w0 * Mathf.Pow(1 - t, 1.3f) + .03f) * Swell(Mathf.Pow(t, .3f), .5f), f.toCam);
                    arm.pivot = eye; arm.spinAxis = f.toCam; arm.spin = -Mathf.Sign(turn) * 120f; arm.shrink = true; arm.opacity = .85f;
                    arm.revealScale = 1.2f; arm.holdScale = 1.1f; arm.tile = 2.2f; arm.delay = k * .03f;
                    list.Add(arm);
                }
                break;
            }
            case Accent.Wings:
            {
                // Two swept wings unfold from the recipient's shoulders.
                var shoulder = f.target + f.up * .3f * s - f.toCam * .2f * s;
                int feathers = style == Style.Heavy ? 6 : 5;
                for (int side = -1; side <= 1; side += 2)
                    for (int k = 0; k < feathers; k++)
                    {
                        float fr = k / (feathers - 1f), th = Mathf.Lerp(-18f, 72f, fr) * Mathf.Deg2Rad + R(rng, -.08f, .08f);
                        float len = s * (3.7f - 1.3f * fr) * R(rng, .9f, 1.08f), sd = side;
                        var dir = sd * Mathf.Cos(th) * f.right + Mathf.Sin(th) * f.up;
                        Func<float, Vector3> pos = t => shoulder + dir * len * t - f.up * (.4f * s * Mathf.Sin(Mathf.PI * t) * (1 - fr))
                            + f.right * sd * .3f * s * t * t - f.toCam * .25f * s * t;
                        var feather = Make(40, pos, FacingAcross(pos, f.toCam), t => s * (.34f + .14f * (1 - fr)) * Swell(Mathf.Pow(t, .45f), .7f) * (1 - .3f * t), f.toCam);
                        feather.pivot = shoulder; feather.swingAxis = f.toCam; feather.swing = -sd * 68f;
                        feather.revealScale = 1.5f; feather.holdScale = 1.5f; feather.tile = 1.8f;
                        feather.delay = fr * .025f; feather.rampShift = R(rng, -.15f, .2f);
                        list.Add(feather);
                    }
                break;
            }
            case Accent.Tornado:
            {
                // Wind bands wrap a funnel that widens upward and spins as one.
                var foot = f.Foot; var gz = f.Depth;
                int bands = style == Style.Heavy ? 7 : light ? 4 : 6;
                float height = R(rng, 4.8f, 5.8f) * s, spinSign = rng.NextDouble() < .5 ? -1 : 1;
                for (int k = 0; k < bands; k++)
                {
                    float a0 = 6.283f * k / bands + R(rng, -.35f, .35f), turns = spinSign * R(rng, 1.1f, 1.7f) * 6.283f;
                    float h0 = R(rng, 0f, .22f), h1 = R(rng, .72f, 1f), wBand = R(rng, .45f, .72f) * s;
                    Func<float, Vector3> pos = t =>
                    {
                        float hh = Mathf.Lerp(h0, h1, t), r = Mathf.Lerp(.28f, 2.3f, hh * hh) * s * (1 + .08f * Mathf.Sin(t * 9 + a0));
                        float a = a0 + turns * t;
                        return foot + Vector3.up * height * hh + r * (Mathf.Cos(a) * f.right + Mathf.Sin(a) * gz);
                    };
                    var band = Make(72, pos, t => Vector3.up + .25f * f.right, t => wBand * Swell(t, .5f) * (.55f + .8f * Mathf.Lerp(h0, h1, t)), f.toCam);
                    band.pivot = foot; band.spinAxis = Vector3.up; band.spin = spinSign * R(rng, 380f, 520f);
                    band.revealScale = 1.3f; band.holdScale = 2.4f; band.tile = 2f; band.delay = k * .02f; band.rampShift = R(rng, -.15f, .2f);
                    list.Add(band);
                }
                break;
            }
            case Accent.SwordQi:
            {
                // Crescent sword waves sweep through the target and fly on.
                int n = style == Style.Heavy ? 4 : light ? 2 : 3;
                for (int k = 0; k < n; k++)
                {
                    float ang = (k == 0 ? R(rng, -12, 12) : k == 1 ? R(rng, 32, 52) : k == 2 ? R(rng, -52, -32) : R(rng, 70, 80)) * Mathf.Deg2Rad;
                    var d = (Mathf.Cos(ang) * f.right * f.side * (k % 2 == 0 ? 1 : -1) + Mathf.Sin(ang) * f.up).normalized;
                    var perp = Vector3.Cross(d, f.toCam).normalized;
                    float radius = R(rng, 1.9f, 2.7f) * s, span = R(rng, 105, 140) * Mathf.Deg2Rad, thick = R(rng, .3f, .42f) * s;
                    var c = f.target - d * radius * .55f + f.toCam * .15f * s * k;
                    Func<float, Vector3> radial = t => { float ph = Mathf.Lerp(-span * .5f, span * .5f, t); return Mathf.Cos(ph) * d + Mathf.Sin(ph) * perp; };
                    var wave = Make(56, t => c + radial(t) * radius, radial, t => thick * Mathf.Pow(Swell(t, 1f), 1.25f), f.toCam);
                    wave.pivot = f.target; wave.offset = -d * R(rng, 2.6f, 3.4f) * s; wave.drift = d * R(rng, 5f, 8f) * s;
                    wave.rigid = true; wave.revealScale = .75f; wave.holdScale = .6f; wave.coreAmt = 1.8f; wave.tile = 3f;
                    wave.delay = k * .07f; wave.rampShift = .1f * k;
                    list.Add(wave);
                }
                break;
            }
            case Accent.SwordRain:
            {
                // Blades drop from the sky and stake the ground around the target.
                var foot = f.Foot; var gz = f.Depth;
                int n = style == Style.Heavy ? 10 : light ? 4 : 7;
                for (int i = 0; i < n; i++)
                {
                    var land = foot + (f.right * R(rng, -1.7f, 1.7f) + gz * R(rng, -1.1f, 1.1f)) * s;
                    var tilt = (Vector3.down + f.right * R(rng, -.35f, .35f) + gz * R(rng, -.2f, .2f)).normalized;
                    float L = R(rng, 2.4f, 3.3f) * s, bw = R(rng, .2f, .27f) * s;
                    var tip = land + tilt * .25f * s; var top = tip - tilt * L;
                    var blade = Make(28, t => Vector3.Lerp(top, tip, t), _ => Vector3.Cross(tilt, f.toCam), t =>
                        t < .12f ? bw * 1.9f * Swell(t / .12f, .6f) : bw * (1 - Mathf.Pow((t - .12f) / .88f, 1.7f)) + .005f * s, f.toCam);
                    blade.pivot = tip; blade.offset = -tilt * R(rng, 4.5f, 6f) * s; blade.rigid = true;
                    blade.revealScale = .6f; blade.holdScale = 2.2f; blade.coreAmt = 1.4f; blade.tile = 1.2f;
                    blade.delay = i * .045f + R(rng, 0, .03f); blade.impactAt = land;
                    list.Add(blade);
                }
                break;
            }
            case Accent.Meteor:
            {
                // Burning stones fall on a slant with long tails and burst on landing.
                var foot = f.Foot; var gz = f.Depth;
                int n = style == Style.Heavy ? 6 : light ? 2 : 4;
                var inc = (Vector3.down + f.right * -f.side * R(rng, .5f, .8f) + gz * R(rng, -.2f, .2f)).normalized;
                for (int i = 0; i < n; i++)
                {
                    var land = foot + (f.right * R(rng, -1.6f, 1.6f) + gz * R(rng, -.8f, .8f)) * s + Vector3.up * .15f * s;
                    float Lt = R(rng, 3.4f, 5f) * s, bend = R(rng, -.3f, .3f) * s, head = R(rng, .45f, .62f) * s;
                    var tail = land - inc * Lt; var perp = Vector3.Cross(inc, f.toCam).normalized;
                    var met = Make(40, t => Vector3.Lerp(tail, land, t) + perp * bend * Mathf.Sin(Mathf.PI * t), _ => perp, t => .04f * s + head * Mathf.Pow(t, 2.2f), f.toCam);
                    met.pivot = land; met.offset = -inc * R(rng, 3f, 4.5f) * s; met.rigid = true;
                    met.revealScale = 1f; met.holdScale = .5f; met.coreAmt = 2.2f; met.tile = 1.6f;
                    met.delay = i * .085f + R(rng, 0, .04f); met.impactAt = land;
                    list.Add(met);
                }
                break;
            }
            case Accent.Spikes:
            {
                // Crystal or bone spikes burst out of the ground around the target.
                var foot = f.Foot; var gz = f.Depth;
                int n = style == Style.Heavy ? 12 : light ? 5 : 9;
                for (int i = 0; i < n; i++)
                {
                    float ang = i * 2.39996f + R(rng, -.3f, .3f), rr = R(rng, .25f, 2f) * s;
                    var radial = Mathf.Cos(ang) * f.right + Mathf.Sin(ang) * gz;
                    var bottom = foot + radial * rr - Vector3.up * .1f * s;
                    var tilt = (Vector3.up + radial * R(rng, .15f, .6f)).normalized;
                    float h = s * R(rng, 1.3f, 2.9f) * Mathf.Clamp(1.25f - rr / (2.4f * s), .45f, 1.2f), w = h * R(rng, .13f, .19f);
                    var a1 = Vector3.Cross(tilt, f.toCam).normalized; var a2 = Vector3.Cross(tilt, a1).normalized;
                    foreach (var across in new[] { a1, a2 })
                    {
                        var ax = across;
                        var spike = Make(20, t => bottom + tilt * h * t, _ => ax, t => w * Mathf.Pow(1 - t, 1.1f), f.toCam);
                        spike.pivot = bottom; spike.offset = -tilt * h * .9f; spike.rigid = true;
                        spike.revealScale = .55f; spike.holdScale = 2.4f; spike.coreAmt = .9f; spike.tile = .9f;
                        spike.delay = rr / s * .035f + R(rng, 0, .02f);
                        list.Add(spike);
                    }
                }
                break;
            }
            case Accent.Dragon:
            {
                // A serpent body coils up around the target, head last, with whiskers.
                var foot = f.Foot; var gz = f.Depth;
                float turns = (rng.NextDouble() < .5 ? -1 : 1) * R(rng, 1.7f, 2f) * 6.283f, a0 = R(rng, 0, 6.28f), height = R(rng, 3.9f, 4.4f) * s;
                Func<float, Vector3> pos = t =>
                {
                    float a = a0 + turns * t, r = s * (1.05f - .3f * t + .08f * Mathf.Sin(t * 15f));
                    return foot + Vector3.up * (.2f * s + height * Mathf.Pow(t, .9f)) + r * (Mathf.Cos(a) * f.right + Mathf.Sin(a) * gz);
                };
                Func<float, float> girth = t => s * (.05f + .26f * Swell(Mathf.Pow(t, .6f), .7f) + .3f * Mathf.Exp(-Mathf.Pow((t - .95f) / .045f, 2)));
                foreach (var across in new Func<float, Vector3>[] { _ => Vector3.up, FacingAcross(pos, f.toCam) })
                {
                    var body = Make(96, pos, across, girth, f.toCam);
                    body.bulgeAmount = .9f; body.pivot = foot; body.spinAxis = Vector3.up; body.spin = -Mathf.Sign(turns) * 40f; body.opacity = 1f;
                    body.revealScale = 2.4f; body.holdScale = 1.7f; body.tile = 5f; body.coreAmt = .7f;
                    list.Add(body);
                }
                var headPt = pos(1f); var headDir = (pos(1f) - pos(.97f)).normalized;
                for (int k = -1; k <= 1; k += 2)
                {
                    var side = Vector3.Cross(headDir, f.toCam).normalized * k;
                    var w1 = headPt + (-headDir * .8f + side * .9f + Vector3.up * .3f) * s; var w2 = headPt + (-headDir * 1.9f + side * 1.3f - Vector3.up * .2f) * s;
                    var whisker = Make(28, t => Bezier(headPt, w1, w2, w2 + side * .4f * s, t), FacingAcross(t => Bezier(headPt, w1, w2, w2 + side * .4f * s, t), f.toCam), t => s * .07f * (1 - t), f.toCam);
                    whisker.pivot = foot; whisker.spinAxis = Vector3.up; whisker.spin = -Mathf.Sign(turns) * 40f;
                    whisker.revealScale = 1.2f; whisker.holdScale = 2f; whisker.coreAmt = 1.6f; whisker.delay = BaseReveal(style) * 2.1f;
                    list.Add(whisker);
                }
                list[0].impactAt = headPt;
                break;
            }
            case Accent.Lotus:
            {
                // Petals open outward from the recipient's feet: a bloom, never a blast.
                var foot = f.Foot + Vector3.up * .06f * s; var gz = f.Depth;
                for (int ring = 0; ring < 2; ring++)
                {
                    int petals = ring == 0 ? 8 : 6;
                    float open = (ring == 0 ? 60f : 32f) * Mathf.Deg2Rad, L = (ring == 0 ? 2.7f : 2.1f) * s, off = ring * .5f;
                    for (int j = 0; j < petals; j++)
                    {
                        float ang = 6.283f * (j + off) / petals + R(rng, -.1f, .1f);
                        var radial = Mathf.Cos(ang) * f.right + Mathf.Sin(ang) * gz;
                        var tangent = Vector3.Cross(Vector3.up, radial).normalized;
                        var tilt = Vector3.up * Mathf.Cos(open) + radial * Mathf.Sin(open);
                        var bottom = foot + radial * (ring == 0 ? .45f : .2f) * s;
                        var petal = Make(30, t => bottom + tilt * L * t + radial * .18f * s * Mathf.Sin(Mathf.PI * t), _ => tangent,
                            t => s * (ring == 0 ? .66f : .56f) * Mathf.Pow(Mathf.Max(0f, Mathf.Sin(Mathf.PI * Mathf.Pow(t, .75f))), .7f), -radial);
                        petal.bulgeAmount = .4f; petal.pivot = bottom; petal.swingAxis = tangent; petal.swing = -40f;
                        petal.revealScale = 1.2f; petal.holdScale = 1.6f; petal.tile = 1.1f; petal.coreAmt = .8f;
                        petal.delay = ring * .06f + j * .012f; petal.rampShift = ring * .2f;
                        list.Add(petal);
                    }
                }
                break;
            }
        }
        return list;
    }

    static void FlattenAcross(Path path)
    {
        int n = path.points.Length;
        for (int i = 0; i < n; i++)
        {
            var tangent = path.points[Mathf.Min(n - 1, i + 1)] - path.points[Mathf.Max(0, i - 1)];
            var a = Vector3.Cross(tangent, Vector3.up);
            path.across[i] = a.sqrMagnitude > 1e-8f ? a.normalized : Vector3.right;
        }
        path.bulge = Vector3.up; path.bulgeAmount = .15f;
    }

    static (float tear, float soft, float facet, float ink, float distort, float flicker, float flow, float tile) MatterLook(Matter m) => m switch
    {
        Matter.Flame => (1.25f, .045f, 0f, 0f, .12f, 0f, 2.4f, .8f),
        Matter.Water => (.7f, .11f, 0f, 0f, .05f, 0f, 1f, 1f),
        Matter.Crystal => (1f, .012f, 1f, 0f, 0f, 0f, .12f, 1.2f),
        Matter.Silk => (.32f, .05f, 0f, 0f, .03f, 0f, .75f, .9f),
        Matter.Ink => (1.35f, .03f, 0f, .85f, .02f, 0f, .25f, .8f),
        Matter.Electric => (.85f, .05f, 0f, 0f, .06f, .5f, 1.6f, 1.3f),
        Matter.Smoke => (.6f, .22f, 0f, 0f, .08f, 0f, .5f, .8f),
        _ => (1f, .07f, 0f, 0f, 0f, 0f, .55f, 1f),
    };

    // ------------------------------------------------------------ body

    sealed class Body : MonoBehaviour
    {
        SpellSpectacle20260926 owner;
        MeshRenderer meshRenderer;
        Mesh mesh;
        MaterialPropertyBlock block;
        Vector3 pivot, offset, spinAxis, swingAxis, drift;
        float age, delay, reveal, hold, fade, intensity, seed, dir, spin, swing, flow, revealEase, disperseSize, disperseDensity, disperseGrowth, disperseStretch;
        bool shrink, rigid, disperse, dispersed, disperseCalm;
        Profile profile;
        Style style;
        // A dispersing body unravels when it starts to fade: each vertex has its own heading.
        Vector3[] restVerts, heading, liveVerts;
        bool unravelled;

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
            offset = path.offset; spin = path.spin; spinAxis = path.spinAxis; swing = path.swing; swingAxis = path.swingAxis; shrink = path.shrink;
            rigid = path.rigid; drift = path.drift; revealEase = path.revealEase;
            disperse = path.disperse; disperseSize = path.disperseSize; disperseDensity = path.disperseDensity; disperseGrowth = path.disperseGrowth;
            disperseCalm = path.disperseCalm; disperseStretch = path.disperseStretch;
            profile = p; dispersed = false;
            (reveal, hold, fade, intensity) = style switch
            {
                Style.Heavy => (.15f, .16f, .50f, 1.16f),
                Style.Strike => (.12f, .12f, .42f, 1.1f),
                Style.Light => (.10f, .08f, .34f, 1.06f),
                Style.Support => (.30f, .26f, .54f, 1.06f),
                _ => (.16f, .14f, .44f, 1.06f),
            };
            reveal *= path.revealScale; hold *= path.holdScale;
            // A dispersing body takes longer to go: it spreads and thins rather than snapping off
            // (169.52: at 1.5x a basic's landing was gone .3 s after its peak).
            if (disperse) fade *= 1.9f;
            var matter = path.look ?? p.matter;
            var look = MatterLook(matter);
            flow = look.flow;
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
            block.SetFloat("_Tile", path.tile * look.tile);
            block.SetFloat("_Tear", look.tear * (style == Style.Support ? .75f : 1f));
            block.SetFloat("_Row", (int)matter);
            block.SetFloat("_EdgeSoft", look.soft);
            block.SetFloat("_Facet", look.facet);
            block.SetFloat("_Ink", look.ink);
            block.SetFloat("_Distort", look.distort);
            block.SetFloat("_Flicker", Mathf.Max(look.flicker * (layer >= 10 ? 1f : .4f), path.flicker));
            block.SetFloat("_Wobble", path.wobble);
            block.SetFloat("_WobbleFreq", 2.2f);
            block.SetFloat("_CoreAmt", path.coreAmt >= 0 ? path.coreAmt : style == Style.Support ? .4f : style == Style.Control ? .45f : .6f);
            block.SetFloat("_Opacity", path.opacity >= 0 ? path.opacity : p.matter == Matter.Ink ? 1f : style == Style.Support ? .95f : .97f);
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
                float tailFade = path.solidStart ? 1f : Mathf.SmoothStep(0, 1, i / (n - 1f) / .12f);
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

        /// As the body starts to fade it unravels (see <see cref="Unravel"/>) and sheds motes:
        /// a third come off at once, the rest keep coming off its pulled-apart surface while it
        /// erodes, so the last of it is motes drifting away, not the shape.
        void Disperse()
        {
            if (!owner || !owner.root || !owner.flareMaterial || !mesh || profile == null) return;
            var rest = mesh.vertices;
            if (rest.Length == 0) return;
            if (!ReducedMotion) Unravel(rest);
            var rng = new System.Random(Mathf.RoundToInt(seed * 1000f) + 17);
            int n = Mathf.Max(3, Mathf.RoundToInt(Mathf.Clamp(rest.Length / 8, 12, 26) * disperseDensity));
            if (ReducedMotion) n = Mathf.Max(3, n / 2);
            var points = new Vector3[n];
            var delays = new float[n];
            for (int i = 0; i < n; i++)
            {
                int k = rng.Next(rest.Length);
                float d = i < n / 3 ? 0f : (float)rng.NextDouble() * fade * .6f;
                points[i] = transform.TransformPoint(heading != null ? rest[k] + heading[k] * Pulled(d) : rest[k]);
                delays[i] = d;
            }
            Flares.Create(owner.root, owner.flareMaterial, owner).Scatter(profile, points, delays, pivot, Mathf.Max(.05f, disperseSize), rng);
        }

        /// Gives every vertex its own heading: out from the impact and from the body's middle,
        /// a turbulent drift that varies smoothly over the surface, and a rise. Pushed along
        /// those headings the shape pulls apart like blown smoke while it erodes; the mesh
        /// stays whole, so there are no cut seams or straight-edged pieces (169.56-169.57:
        /// flakes cut from the strip left dark seams and read as small panels).
        void Unravel(Vector3[] rest)
        {
            var rng = new System.Random(Mathf.RoundToInt(seed * 1000f) + 29);
            float R(float a, float b) => a + (float)rng.NextDouble() * (b - a);
            float s = Mathf.Max(.05f, disperseSize), f = 1.6f / s;
            float ox = R(0, 100), oy = R(0, 100), oz = R(0, 100);
            var middle = mesh.bounds.center;
            // The push grows with the body's own size: a crossed dash cut or the finale's rainbow
            // fan spans a few metres, and pushed by s alone it only warped before it eroded (169.58).
            float reach = s * 1.1f + mesh.bounds.extents.magnitude * disperseStretch;
            // A calm body (the dash's cuts and rays) drifts mostly straight out: a smaller push and
            // less swirl at the same noise scale; a smaller size instead raised the noise scale and
            // kinked the thin cuts like lightning (169.64).
            // Less swirl than at first (1.1): thin bodies writhed into squiggles (2026-10-03, user on the phone: 你很多都设置成这样弯弯的，都改掉吧).
            float swirlWeight = disperseCalm ? .2f : .3f;
            if (disperseCalm) reach *= .35f;
            restVerts = rest;
            heading = new Vector3[rest.Length];
            liveVerts = new Vector3[rest.Length];
            for (int i = 0; i < rest.Length; i++)
            {
                var p = rest[i];
                var swirl = new Vector3(
                    Mathf.PerlinNoise(p.y * f + ox, p.z * f + oy) * 2 - 1,
                    Mathf.PerlinNoise(p.z * f + oz, p.x * f + ox) * 2 - 1,
                    Mathf.PerlinNoise(p.x * f + oy, p.y * f + oz) * 2 - 1);
                var radial = p.sqrMagnitude > 1e-6f ? p.normalized : Vector3.up;
                var fromMiddle = p - middle; fromMiddle = fromMiddle.sqrMagnitude > 1e-6f ? fromMiddle.normalized : radial;
                float push = .7f + Mathf.PerlinNoise(p.x * f * .7f + oz, p.z * f * .7f + oy);
                heading[i] = (radial * .5f + fromMiddle * .4f + swirl * swirlWeight + Vector3.up * .35f) * (push * reach);
            }
            mesh.MarkDynamic();
            unravelled = true;
        }

        // How far along its heading a vertex has gone this long after the fade began: it leaves
        // fast and eases out, so the spread shows while the body is still bright.
        static float Pulled(float into) => (1f - Mathf.Exp(-3.5f * Mathf.Max(0f, into))) * (1.6f / 3.5f);

        void MoveUnravel(float into)
        {
            float k = Pulled(into);
            for (int i = 0; i < restVerts.Length; i++) liveVerts[i] = restVerts[i] + heading[i] * k;
            mesh.vertices = liveVerts;
            mesh.RecalculateBounds();
        }

        void Update()
        {
            age += Time.deltaTime;
            Apply(age - delay);
            if (age - delay > reveal + hold + fade + .02f) Destroy(gameObject);
        }

        /// Finish the reveal within <paramref name="window"/> seconds from now while
        /// keeping its current progress (the contact arrived before the travel ended).
        public void Hasten(float window)
        {
            float t = age - delay;
            if (t >= reveal) return;
            float grow = t <= 0 ? 0 : Mathf.Clamp01(t / reveal);
            reveal = Mathf.Max(.02f, window);
            delay = age - grow * reveal;
        }

        void Apply(float t)
        {
            if (!meshRenderer) return;
            meshRenderer.enabled = t >= 0;
            if (t < 0) return;
            float grow = Mathf.Clamp01(t / reveal);
            float eased = revealEase > 0 ? Mathf.Pow(grow, revealEase) : 1 - Mathf.Pow(1 - grow, 3);
            // Fast expansion that overshoots, settles, then drifts outward as it tears apart.
            float scale = Mathf.Lerp(.5f, 1.07f, eased);
            if (t > reveal) scale = Mathf.Lerp(1.07f, 1f, Mathf.Clamp01((t - reveal) / .1f));
            float out01 = Mathf.Clamp01((t - reveal - hold) / fade);
            // As it fades a dispersing body spreads out (rigid ones a little less) and lifts; once
            // unravelled its vertices carry the spread, so the whole only grows a little.
            float spread = out01 * (2f - out01);
            float growth = unravelled ? disperseGrowth * .3f : disperseGrowth;
            scale += disperse ? spread * growth : out01 * .10f;
            if (rigid) scale = disperse ? 1f + spread * growth * .64f : 1f;
            if (shrink) scale *= Mathf.Lerp(1.12f, .5f, Mathf.Clamp01(t / (reveal + hold + fade)));
            transform.localScale = Vector3.one * scale;
            var rot = Quaternion.identity;
            if (spin != 0) rot = Quaternion.AngleAxis(spin * t, spinAxis);
            if (swing != 0)
            {
                // Folded -> open with a slight overshoot, like wings snapping out.
                float sw = Mathf.Clamp01(t / (reveal * 1.4f)), e = 1 - Mathf.Pow(1 - sw, 3);
                rot = rot * Quaternion.AngleAxis(swing * (1 - e) - swing * .12f * Mathf.Sin(Mathf.PI * e), swingAxis);
            }
            var lift = disperse && !unravelled ? Vector3.up * (disperseSize * .3f * spread) : Vector3.zero;
            transform.SetPositionAndRotation(pivot + offset * (1 - eased) + drift * t + lift, rot);
            if (disperse && !dispersed && out01 > 0f) { dispersed = true; Disperse(); }
            if (unravelled) MoveUnravel(t - reveal - hold);
            float flash = 1 + 1.3f * Mathf.Exp(-t / .07f);
            block.SetFloat("_Reveal", Mathf.Lerp(-.05f, 1.12f, eased));
            // A dispersing body erodes faster and is gone by four fifths of its fade; its motes finish it.
            float erode = disperse ? Mathf.Clamp01(out01 / .75f) : out01;
            block.SetFloat("_Dissolve", Mathf.Lerp(-.25f, 1.05f, erode * erode * (3 - 2 * erode)));
            block.SetFloat("_Alpha", disperse ? 1 - Mathf.SmoothStep(.35f, .8f, out01) : 1 - Mathf.SmoothStep(.55f, 1f, out01));
            block.SetFloat("_Intensity", intensity * (1 + .12f * Mathf.Exp(-t / .07f)));
            block.SetFloat("_Glow", flash);
            block.SetFloat("_Head", grow < 1 ? 1.4f : Mathf.Lerp(1.4f, .2f, Mathf.Clamp01((t - reveal) / .12f)));
            block.SetFloat("_Scroll", t * flow * dir);
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
            public bool flat, pop, orbit;
            // Orbit: circles an axis through oc while its radius eases r0 -> r1.
            public Vector3 oc, oax, ou, ov;
            public float r0, r1, a0, w, rise;
            // Rides a launch course (u 0..1 over 'travel' seconds) at offset 'lag', then drifts on.
            public Func<float, Vector3> course;
            public float travel;
            public Vector3 lag;
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

        public void Build(Profile p, Style style, Frame f, System.Random rng, float delay, bool group, bool forward = false)
        {
            float s = f.s;
            bool support = style == Style.Support;
            bool damage = style == Style.Light || style == Style.Strike || style == Style.Heavy;
            float tier = style == Style.Heavy ? 1.2f : style == Style.Strike ? 1f : style == Style.Light ? .62f : .7f;
            var hotSpot = f.target + f.toCam * .35f * s;
            if (damage || style == Style.Control) Heart(p, style, f, rng, delay, group, tier, hotSpot);
            if (support)
            {
                // A soft tinted bloom on the recipient: warmth and reception, no splash or white core.
                Add(new Mark { pos = hotSpot, cell = Star(rng.Next(4)), color = Pick(p, rng, .35f, .7f), size = 1.2f * s, sizeEnd = 3.2f * s, rot = R(rng, 0, 360), spin = R(rng, -20, 20), life = .7f, delay = delay + .12f, peak = .35f, pop = true, opacity = .25f, hot = .2f });
            }
            AccentMarks(p, style, f, rng, delay, group, tier, hotSpot);
            int count = style switch { Style.Heavy => 112, Style.Strike => 82, Style.Light => 52, Style.Support => 64, _ => 52 };
            if (group) count = Mathf.RoundToInt(count * .6f);
            // Hero forms spray their matter forward, away from the hero, and less of it.
            if (forward) count = Mathf.RoundToInt(count * .75f);
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
                    var outDir = forward ? (f.dir * 1.15f + Random3(rng) * .55f + f.up * .3f).normalized
                        : (Random3(rng) + f.toCam * .35f + f.up * .25f).normalized;
                    float speed = R(rng, 3.5f, 10.5f) * s * tier * (forward ? .7f : 1f);
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

        // Each matter answers the contact with its own heart instead of one shared star.
        void Heart(Profile p, Style style, Frame f, System.Random rng, float delay, bool group, float tier, Vector3 hot)
        {
            float s = f.s;
            var rim = Pick(p, rng, .45f, .85f);
            bool energy = p.matter == Matter.Filigree || p.matter == Matter.Electric;
            if (energy)
            {
                if (!group)
                    Add(new Mark { pos = hot, cell = Star(rng.Next(4)), color = Color.Lerp(rim, p.core, .45f), size = 1.1f * s * tier, sizeEnd = 2.8f * s * tier, rot = R(rng, 0, 360), spin = R(rng, -40, 40), life = .26f, delay = delay, peak = .14f, pop = true, opacity = .35f, hot = 1f });
                Add(new Mark { pos = hot + f.toCam * .05f, cell = Star(rng.Next(4)), color = rim, size = (group ? 1.3f : 1.7f) * s * tier, sizeEnd = (group ? 3.1f : 4.1f) * s * tier, rot = R(rng, 0, 360), spin = R(rng, -25, 25), life = .38f, delay = delay + .02f, peak = .18f, pop = true, opacity = .6f, hot = group ? .35f : .8f });
                Add(new Mark { pos = hot - f.toCam * .1f, cell = Splash(rng.Next(4)), color = Pick(p, rng, .15f, .6f), size = 1.5f * s * tier, sizeEnd = 5f * s * tier, rot = R(rng, 0, 360), spin = R(rng, -30, 30), life = .48f, delay = delay, peak = .2f, opacity = .92f, hot = .15f });
            }
            else switch (p.matter)
            {
                case Matter.Flame:
                    Add(new Mark { pos = hot, cell = Star(rng.Next(4)), color = rim, size = 1.2f * s * tier, sizeEnd = 3f * s * tier, rot = R(rng, 0, 360), life = .3f, delay = delay, peak = .16f, pop = true, opacity = .5f, hot = .55f });
                    for (int i = 0; i < 9; i++)
                    {
                        var d = Random3(rng); d.y = Mathf.Abs(d.y) * .6f + .2f;
                        Add(new Mark { pos = hot, vel = d.normalized * R(rng, 4f, 8f) * s, drag = 4f, gravity = -3f * s, cell = MoteCell(Mote.Puff), color = Pick(p, rng, .35f, .9f), size = .5f * s * tier, sizeEnd = 1.6f * s * tier, rot = R(rng, 0, 360), spin = R(rng, -200, 200), life = R(rng, .4f, .6f), delay = delay, peak = .2f, opacity = .85f, hot = .35f });
                    }
                    break;
                case Matter.Crystal:
                    Add(new Mark { pos = hot, cell = Star(rng.Next(4)), color = Color.Lerp(rim, Color.white, .5f), size = .7f * s * tier, sizeEnd = 2f * s * tier, rot = R(rng, 0, 360), life = .22f, delay = delay, peak = .12f, pop = true, opacity = .4f, hot = 1f });
                    for (int i = 0; i < 11; i++)
                    {
                        var d = Random3(rng) + f.toCam * .3f;
                        Add(new Mark { pos = hot, vel = d.normalized * R(rng, 8f, 14f) * s * tier, drag = 3.2f, gravity = 3f * s, cell = MoteCell(Mote.Shard), color = Pick(p, rng, .45f, 1f), size = R(rng, .45f, .85f) * s * tier, sizeEnd = .25f * s, rot = R(rng, 0, 360), spin = R(rng, -700, 700), life = R(rng, .4f, .6f), delay = delay, peak = .15f, opacity = .95f, hot = .25f });
                    }
                    break;
                case Matter.Water:
                    for (int i = 0; i < 2; i++)
                        Add(new Mark { pos = hot - f.toCam * .1f * i, cell = Splash(rng.Next(4)), color = Pick(p, rng, .55f, 1f), size = 1.2f * s * tier, sizeEnd = R(rng, 3.6f, 4.8f) * s * tier, rot = R(rng, 0, 360), spin = R(rng, -40, 40), life = .5f, delay = delay + i * .04f, peak = .2f, pop = true, opacity = .85f, hot = .35f });
                    for (int i = 0; i < 12; i++)
                    {
                        var d = Random3(rng); d.y = Mathf.Abs(d.y);
                        Add(new Mark { pos = hot, vel = d * R(rng, 3f, 7f) * s, drag = 2.5f, gravity = 5f * s, cell = MoteCell(Mote.Puff), color = Pick(p, rng, .7f, 1f), size = .4f * s, sizeEnd = 1.1f * s, rot = R(rng, 0, 360), life = R(rng, .45f, .7f), delay = delay, peak = .2f, opacity = .75f, hot = .3f });
                    }
                    break;
                case Matter.Silk:
                    Add(new Mark { pos = hot, cell = Star(rng.Next(4)), color = rim, size = .9f * s * tier, sizeEnd = 2.4f * s * tier, rot = R(rng, 0, 360), life = .28f, delay = delay, peak = .15f, pop = true, opacity = .45f, hot = .5f });
                    for (int i = 0; i < 16; i++)
                    {
                        var d = Random3(rng) + f.toCam * .2f;
                        Add(new Mark { pos = hot, vel = d.normalized * R(rng, 5f, 9f) * s, drag = 3.8f, gravity = 1.2f * s, cell = MoteCell(Mote.Petal), color = Pick(p, rng, .3f, 1f), size = R(rng, .35f, .6f) * s * tier, sizeEnd = .3f * s, rot = R(rng, 0, 360), spin = R(rng, -420, 420), life = R(rng, .55f, .85f), delay = delay, peak = .2f, opacity = .92f, hot = .1f });
                    }
                    break;
                case Matter.Ink:
                    for (int i = 0; i < 2; i++)
                        Add(new Mark { pos = hot - f.toCam * .1f * i, cell = Splash(rng.Next(4)), color = Pick(p, rng, 0f, .25f), size = 1.2f * s * tier, sizeEnd = R(rng, 3.6f, 4.6f) * s * tier, rot = R(rng, 0, 360), spin = R(rng, -20, 20), life = .6f, delay = delay + i * .03f, peak = .35f, pop = true, opacity = .95f, hot = 0f });
                    Add(new Mark { pos = hot + f.toCam * .1f, cell = Star(rng.Next(4)), color = p.line, size = .6f * s * tier, sizeEnd = 1.8f * s * tier, rot = R(rng, 0, 360), life = .24f, delay = delay, peak = .12f, pop = true, opacity = .4f, hot = .6f });
                    break;
                case Matter.Smoke:
                    Add(new Mark { pos = hot, cell = Star(rng.Next(4)), color = rim, size = 1f * s * tier, sizeEnd = 2.6f * s * tier, rot = R(rng, 0, 360), life = .35f, delay = delay, peak = .2f, pop = true, opacity = .3f, hot = .2f });
                    for (int i = 0; i < 7; i++)
                    {
                        var d = Random3(rng);
                        Add(new Mark { pos = hot, vel = d * R(rng, 2.5f, 5f) * s, drag = 3f, gravity = -1f * s, cell = MoteCell(Mote.Puff), color = Pick(p, rng, .25f, .8f), size = .8f * s * tier, sizeEnd = 2.4f * s * tier, rot = R(rng, 0, 360), spin = R(rng, -90, 90), life = R(rng, .6f, .9f), delay = delay, peak = .3f, opacity = .72f, hot = .1f });
                    }
                    break;
            }
            bool groundBurst = p.matter == Matter.Filigree || p.matter == Matter.Flame || p.matter == Matter.Crystal || p.matter == Matter.Electric;
            if (style == Style.Heavy && !group && groundBurst && p.accent != Accent.Cracks)
                Add(new Mark { pos = new Vector3(f.target.x, .04f, f.target.z), cell = Splash(rng.Next(4)), color = Pick(p, rng, .1f, .5f), size = 2.4f * s, sizeEnd = 8.4f * s, rot = R(rng, 0, 360), spin = R(rng, -15, 15), life = .65f, delay = delay + .02f, peak = .22f, flat = true, opacity = .9f, hot = .1f });
        }

        void AccentMarks(Profile p, Style style, Frame f, System.Random rng, float delay, bool group, float tier, Vector3 hot)
        {
            float s = f.s, scale = group ? .6f : 1f;
            switch (p.accent)
            {
                case Accent.Orbit:
                {
                    // Petals, cards, embers or bubbles circle the recipient and spread.
                    int n = Mathf.RoundToInt((style == Style.Heavy ? 48 : 36) * scale);
                    float dirSign = rng.NextDouble() < .5 ? -1 : 1;
                    for (int i = 0; i < n; i++)
                    {
                        var ax = (Vector3.up + Random3(rng) * .3f).normalized;
                        var ou = Vector3.Cross(ax, f.right).normalized; if (ou.sqrMagnitude < .1f) ou = f.toCam;
                        var ov = Vector3.Cross(ax, ou);
                        var type = i % 3 == 2 ? p.mote2 : p.mote;
                        Add(new Mark { orbit = true, oc = f.target + f.up * R(rng, -.7f, .4f) * s, oax = ax, ou = ou, ov = ov,
                            r0 = R(rng, .3f, .9f) * s, r1 = R(rng, 1.8f, 3.1f) * s, a0 = R(rng, 0, 6.28f), w = dirSign * R(rng, 3.5f, 7f) * (rng.NextDouble() < .15 ? -1 : 1), rise = R(rng, -.3f, 2.2f) * s,
                            cell = MoteCell(type), color = Pick(p, rng, .25f, 1f), size = R(rng, .22f, .42f) * s * tier, sizeEnd = .18f * s, rot = R(rng, 0, 360), spin = R(rng, -300, 300),
                            life = R(rng, .8f, 1.25f), delay = delay + R(rng, 0, .12f), peak = .3f, opacity = type == Mote.Ember || type == Mote.Spark ? .35f : .9f, hot = type == Mote.Ember || type == Mote.Spark ? .6f : .05f });
                    }
                    break;
                }
                case Accent.Vortex:
                {
                    // Matter drawn in along the spiral toward the eye.
                    int n = Mathf.RoundToInt(34 * scale);
                    var sUp = Vector3.Cross(f.right, f.toCam).normalized;
                    for (int i = 0; i < n; i++)
                        Add(new Mark { orbit = true, oc = f.target + f.up * .1f * s, oax = f.toCam, ou = f.right, ov = sUp,
                            r0 = R(rng, 2.2f, 3.4f) * s, r1 = .15f * s, a0 = R(rng, 0, 6.28f), w = R(rng, 5f, 8f), rise = 0,
                            cell = MoteCell(p.mote), color = Pick(p, rng, .3f, 1f), size = R(rng, .18f, .34f) * s, sizeEnd = .06f * s, rot = R(rng, 0, 360), spin = R(rng, -400, 400),
                            life = R(rng, .7f, 1f), delay = delay + R(rng, 0, .1f), peak = .25f, opacity = .85f, hot = .2f });
                    break;
                }
                case Accent.Shards:
                {
                    int n = Mathf.RoundToInt((style == Style.Heavy ? 24 : 16) * scale);
                    for (int i = 0; i < n; i++)
                    {
                        var d = (Random3(rng) + f.up * .5f + f.toCam * .3f).normalized;
                        Add(new Mark { pos = hot, vel = d * R(rng, 6f, 12f) * s * tier, drag = 1.1f, gravity = 9f * s, cell = MoteCell(Mote.Shard), color = Pick(p, rng, .4f, 1f),
                            size = R(rng, .3f, .7f) * s * tier, sizeEnd = .2f * s, rot = R(rng, 0, 360), spin = R(rng, -800, 800), life = R(rng, .6f, .9f), delay = delay, peak = .15f, opacity = .95f, hot = .15f });
                    }
                    for (int i = 0; i < 6 * scale; i++)
                        Add(new Mark { pos = hot + Random3(rng) * R(rng, .5f, 2f) * s, cell = Star(rng.Next(4)), color = Color.white, size = .1f * s, sizeEnd = .9f * s, rot = R(rng, 0, 360), life = .2f, delay = delay + R(rng, .05f, .3f), peak = .3f, pop = true, opacity = .3f, hot = 1f });
                    break;
                }
                case Accent.Splatter:
                {
                    var foot = new Vector3(f.target.x, .04f, f.target.z);
                    for (int i = 0; i < 4 * scale + 1; i++)
                        Add(new Mark { pos = foot + (f.right * R(rng, -1.6f, 1.6f) + Vector3.Cross(f.right, Vector3.up) * R(rng, -1f, 1f)) * s, cell = Splash(rng.Next(4)), color = Pick(p, rng, 0f, .3f),
                            size = 1f * s, sizeEnd = R(rng, 2.5f, 4.5f) * s, rot = R(rng, 0, 360), life = 1f, delay = delay + R(rng, .02f, .12f), peak = .55f, pop = true, flat = true, opacity = .95f, hot = 0f });
                    for (int i = 0; i < 28 * scale; i++)
                    {
                        var d = (Random3(rng) + f.up * .6f).normalized;
                        Add(new Mark { pos = hot, vel = d * R(rng, 5f, 11f) * s, drag = .9f, gravity = 11f * s, stretch = .03f, cell = MoteCell(Mote.Ink), color = i % 4 == 0 ? p.line : Pick(p, rng, 0f, .35f),
                            size = R(rng, .14f, .3f) * s, sizeEnd = .1f * s, rot = R(rng, 0, 360), life = R(rng, .55f, .85f), delay = delay, peak = .15f, opacity = .95f, hot = i % 4 == 0 ? .5f : 0f });
                    }
                    break;
                }
                case Accent.Foam:
                {
                    for (int i = 0; i < 38 * scale; i++)
                    {
                        var d = (f.right * f.side * R(rng, .2f, 1f) + f.up * R(rng, .5f, 1.2f) + f.toCam * R(rng, -.3f, .5f)).normalized;
                        Add(new Mark { pos = hot + f.right * R(rng, -1f, 1f) * s - f.up * .5f * s, vel = d * R(rng, 4f, 8.5f) * s, drag = 1.6f, gravity = 7f * s, cell = MoteCell(Mote.Puff), color = Pick(p, rng, .6f, 1f),
                            size = R(rng, .3f, .6f) * s, sizeEnd = R(rng, .7f, 1.1f) * s, rot = R(rng, 0, 360), spin = R(rng, -120, 120), life = R(rng, .6f, .95f), delay = delay + R(rng, 0, .08f), peak = .25f, opacity = .8f, hot = .25f });
                    }
                    for (int i = 0; i < 26 * scale; i++)
                    {
                        var d = (Random3(rng) + f.up).normalized;
                        Add(new Mark { pos = hot, vel = d * R(rng, 6f, 11f) * s, drag = 1.2f, gravity = 10f * s, stretch = .04f, cell = MoteCell(Mote.Spark), color = Pick(p, rng, .75f, 1f),
                            size = R(rng, .1f, .2f) * s, sizeEnd = .06f * s, life = R(rng, .45f, .7f), delay = delay, peak = .15f, opacity = .5f, hot = .7f });
                    }
                    break;
                }
                case Accent.Cracks:
                {
                    // Debris and dust thrown up along the fissures.
                    var foot = new Vector3(f.target.x, .04f, f.target.z);
                    var gz = Vector3.Cross(f.right, Vector3.up).normalized;
                    for (int i = 0; i < 18 * scale; i++)
                    {
                        float a = R(rng, 0, 6.28f), r = R(rng, .4f, 2.6f) * s;
                        var at = foot + (Mathf.Cos(a) * f.right + Mathf.Sin(a) * gz) * r;
                        Add(new Mark { pos = at, vel = (Vector3.up * R(rng, 4f, 8f) + (at - foot).normalized * R(rng, .5f, 2f)) * s, drag = .8f, gravity = 12f * s, cell = MoteCell(Mote.Shard), color = Pick(p, rng, .15f, .7f),
                            size = R(rng, .16f, .38f) * s, sizeEnd = .12f * s, rot = R(rng, 0, 360), spin = R(rng, -600, 600), life = R(rng, .6f, .9f), delay = delay + R(rng, .02f, .15f), peak = .15f, opacity = .95f, hot = .1f });
                    }
                    for (int i = 0; i < 8 * scale; i++)
                        Add(new Mark { pos = foot + (f.right * R(rng, -2f, 2f) + gz * R(rng, -1f, 1f)) * s + Vector3.up * .3f * s, vel = Vector3.up * R(rng, .5f, 1.5f) * s, drag = 2f,
                            cell = MoteCell(Mote.Puff), color = Pick(p, rng, .1f, .45f), size = .9f * s, sizeEnd = 2.4f * s, rot = R(rng, 0, 360), spin = R(rng, -60, 60), life = R(rng, .8f, 1.1f), delay = delay + .05f, peak = .35f, opacity = .55f, hot = 0f });
                    break;
                }
                case Accent.Wings:
                {
                    // Loose feathers shed from the wing tips.
                    for (int i = 0; i < 22 * scale; i++)
                    {
                        float sd = i % 2 == 0 ? -1 : 1;
                        var at = f.target + f.right * sd * R(rng, 1.4f, 3.2f) * s + f.up * R(rng, .4f, 2.8f) * s;
                        Add(new Mark { pos = at, vel = (f.right * sd * R(rng, .5f, 2f) + Vector3.down * R(rng, .2f, 1f)) * s, drag = 2f, gravity = 1.5f * s, cell = MoteCell(p.mote2 == Mote.Spark ? Mote.Wisp : p.mote2), color = Pick(p, rng, .3f, 1f),
                            size = R(rng, .25f, .45f) * s, sizeEnd = .15f * s, rot = R(rng, 0, 360), spin = R(rng, -240, 240), life = R(rng, .7f, 1.1f), delay = delay + R(rng, .08f, .25f), peak = .3f, opacity = .85f, hot = .2f });
                    }
                    break;
                }
                case Accent.Tornado:
                {
                    // Debris and dust dragged round and up the funnel.
                    var foot = f.Foot; var gz = f.Depth;
                    float w = rng.NextDouble() < .5 ? -1 : 1;
                    for (int i = 0; i < 46 * scale; i++)
                    {
                        var type = i % 3 == 0 ? p.mote2 : p.mote;
                        Add(new Mark { orbit = true, oc = foot, oax = Vector3.up, ou = f.right, ov = gz, r0 = R(rng, .25f, .8f) * s, r1 = R(rng, 1.4f, 2.6f) * s, a0 = R(rng, 0, 6.28f),
                            w = w * R(rng, 7f, 11f), rise = R(rng, 2.5f, 5.5f) * s, cell = MoteCell(type), color = Pick(p, rng, .25f, 1f), size = R(rng, .16f, .34f) * s, sizeEnd = .1f * s,
                            rot = R(rng, 0, 360), spin = R(rng, -500, 500), life = R(rng, .9f, 1.3f), delay = delay + R(rng, 0, .15f), peak = .3f, opacity = type == Mote.Spark || type == Mote.Ember ? .35f : .85f, hot = .3f });
                    }
                    break;
                }
                case Accent.SwordQi:
                {
                    for (int i = 0; i < 26 * scale; i++)
                    {
                        var d = (f.right * f.side * R(rng, -1f, 1f) + f.up * R(rng, -.5f, .8f)).normalized;
                        Add(new Mark { pos = hot, vel = d * R(rng, 9f, 16f) * s, drag = 3.5f, stretch = .06f, cell = MoteCell(Mote.Spark), color = Pick(p, rng, .5f, 1f),
                            size = R(rng, .1f, .2f) * s, sizeEnd = .04f * s, life = R(rng, .25f, .45f), delay = delay + R(rng, 0, .2f), peak = .12f, opacity = .35f, hot = .9f });
                    }
                    break;
                }
                case Accent.Meteor:
                {
                    for (int i = 0; i < 30 * scale; i++)
                    {
                        var at = f.Foot + (f.right * R(rng, -2f, 2f) + f.Depth * R(rng, -1f, 1f)) * s + Vector3.up * R(rng, 3f, 5.5f) * s;
                        Add(new Mark { pos = at, vel = (Vector3.down * R(rng, 6f, 10f) + f.right * -f.side * R(rng, 3f, 5f)) * s, drag = .3f, stretch = .03f, cell = MoteCell(Mote.Ember), color = Pick(p, rng, .4f, 1f),
                            size = R(rng, .12f, .24f) * s, sizeEnd = .08f * s, life = R(rng, .5f, .8f), delay = delay + R(rng, 0, .35f), peak = .2f, opacity = .4f, hot = .7f });
                    }
                    break;
                }
                case Accent.Spikes:
                {
                    for (int i = 0; i < 24 * scale; i++)
                    {
                        var d = (Random3(rng) + Vector3.up * 1.2f).normalized;
                        Add(new Mark { pos = f.Foot + (f.right * R(rng, -1.5f, 1.5f) + f.Depth * R(rng, -1f, 1f)) * s, vel = d * R(rng, 4f, 8f) * s, drag = 1f, gravity = 10f * s, cell = MoteCell(Mote.Shard), color = Pick(p, rng, .5f, 1f),
                            size = R(rng, .14f, .3f) * s, sizeEnd = .08f * s, rot = R(rng, 0, 360), spin = R(rng, -700, 700), life = R(rng, .5f, .8f), delay = delay + R(rng, 0, .1f), peak = .15f, opacity = .95f, hot = .2f });
                    }
                    break;
                }
                case Accent.Dragon:
                {
                    var gz = f.Depth;
                    for (int i = 0; i < 40 * scale; i++)
                        Add(new Mark { orbit = true, oc = f.Foot, oax = Vector3.up, ou = f.right, ov = gz, r0 = R(rng, 1.4f, 2.2f) * s, r1 = R(rng, 1.8f, 2.8f) * s, a0 = R(rng, 0, 6.28f),
                            w = R(rng, -3f, 3f), rise = R(rng, 2f, 5.5f) * s, cell = MoteCell(i % 2 == 0 ? Mote.Spark : p.mote), color = Pick(p, rng, .5f, 1f), size = R(rng, .1f, .24f) * s, sizeEnd = .06f * s,
                            rot = R(rng, 0, 360), life = R(rng, .9f, 1.4f), delay = delay + R(rng, .1f, .5f), peak = .3f, opacity = .4f, hot = .7f });
                    break;
                }
                case Accent.Lotus:
                {
                    for (int i = 0; i < 26 * scale; i++)
                    {
                        var at = f.Foot + (f.right * R(rng, -1.4f, 1.4f) + f.Depth * R(rng, -.8f, .8f)) * s;
                        Add(new Mark { pos = at, vel = Vector3.up * R(rng, 1.5f, 3.5f) * s, drag = 1.2f, gravity = -.5f * s, cell = MoteCell(i % 2 == 0 ? Mote.Petal : Mote.Spark), color = Pick(p, rng, .4f, 1f),
                            size = R(rng, .14f, .3f) * s, sizeEnd = .08f * s, rot = R(rng, 0, 360), spin = R(rng, -200, 200), life = R(rng, .9f, 1.3f), delay = delay + R(rng, .15f, .5f), peak = .35f, opacity = .8f, hot = .3f });
                    }
                    break;
                }
                case Accent.Lightning:
                {
                    for (int i = 0; i < 22 * scale; i++)
                    {
                        var d = Random3(rng);
                        Add(new Mark { pos = hot, vel = d * R(rng, 8f, 15f) * s, drag = 3f, stretch = .05f, cell = MoteCell(Mote.Spark), color = Pick(p, rng, .5f, 1f),
                            size = R(rng, .1f, .22f) * s, sizeEnd = .05f * s, life = R(rng, .25f, .45f), delay = delay + R(rng, 0, .15f), peak = .12f, opacity = .35f, hot = .9f });
                    }
                    break;
                }
            }
        }

        /// Landing burst for a blade, meteor or dragon pearl at its arrival time.
        public void Impact(Profile p, Vector3 at, Frame f, float delay, System.Random rng, bool big)
        {
            float s = f.s * (big ? 1.2f : .75f);
            var rim = Pick(p, rng, .45f, .9f);
            Add(new Mark { pos = at + f.toCam * .2f * s, cell = Star(rng.Next(4)), color = Color.Lerp(rim, p.core, .35f), size = .5f * s, sizeEnd = 2f * s, rot = R(rng, 0, 360), spin = R(rng, -60, 60), life = .3f, delay = delay, peak = .15f, pop = true, opacity = .45f, hot = .9f });
            Add(new Mark { pos = new Vector3(at.x, .04f, at.z), cell = Splash(rng.Next(4)), color = Pick(p, rng, .1f, .6f), size = .6f * s, sizeEnd = 2.6f * s, rot = R(rng, 0, 360), life = .55f, delay = delay, peak = .25f, pop = true, flat = true, opacity = .9f, hot = .1f });
            int n = big ? 14 : 8;
            for (int i = 0; i < n; i++)
            {
                var d = (Random3(rng) + Vector3.up * .9f).normalized;
                var type = i % 2 == 0 ? p.mote : Mote.Spark;
                Add(new Mark { pos = at, vel = d * R(rng, 3f, 7f) * s, drag = 1.6f, gravity = 8f * s, stretch = type == Mote.Spark ? .04f : 0f, cell = MoteCell(type), color = Pick(p, rng, .4f, 1f),
                    size = R(rng, .12f, .26f) * s, sizeEnd = .06f * s, rot = R(rng, 0, 360), spin = R(rng, -500, 500), life = R(rng, .35f, .6f), delay = delay, peak = .15f, opacity = type == Mote.Spark ? .35f : .9f, hot = type == Mote.Spark ? .8f : .1f });
            }
        }

        static Vector3 Random3(System.Random rng)
        {
            var v = new Vector3(R(rng, -1, 1), R(rng, -1, 1), R(rng, -1, 1));
            return v.sqrMagnitude > 1e-4f ? v.normalized : Vector3.up;
        }

        void Add(Mark m) => marks.Add(m);

        /// A soft starburst halo riding with a launch head.
        public void ProjectileStar(Vector3 from, Vector3 velocity, float gravity, float delay, float time, float size, Color color, System.Random rng)
        {
            Add(new Mark { pos = from, vel = velocity, gravity = gravity, drag = 0f, cell = Star(rng.Next(4)), color = color, size = size, sizeEnd = size * 1.15f,
                rot = R(rng, 0, 360), spin = R(rng, -90, 90), life = time + .03f, delay = delay, peak = .08f, opacity = .75f, hot = .9f });
        }

        /// Sparks shed along a launch course as the head passes, drifting and fading.
        public void Wake(Profile p, Func<float, Vector3> course, float delay, float time, float s, int count, Mote mote, System.Random rng)
        {
            for (int i = 0; i < count; i++)
            {
                float u = (i + R(rng, 0f, .8f)) / count;
                var at = course(u);
                var vel = Random3(rng) * R(rng, .3f, 1.1f) * s + Vector3.up * R(rng, 0f, .6f) * s;
                float size = R(rng, .1f, .24f) * s;
                Add(new Mark { pos = at, vel = vel, gravity = .6f * s, drag = 2.5f, cell = MoteCell(mote), color = Pick(p, rng, .3f, 1f), size = size, sizeEnd = size * .3f,
                    rot = R(rng, 0, 360), spin = R(rng, -220, 220), life = R(rng, .28f, .55f), delay = delay + u * time, peak = .12f, opacity = 1f, hot = R(rng, .4f, .9f) });
            }
        }

        /// Motes shed from a fading body at the given points and times: soft puffs that swell and
        /// thin as they drift out and up, and a few bright sparks, so the body dissipates into the air.
        public void Scatter(Profile p, Vector3[] points, float[] delays, Vector3 centre, float s, System.Random rng)
        {
            for (int i = 0; i < points.Length; i++)
            {
                var at = points[i];
                var outward = at - centre;
                outward = outward.sqrMagnitude > 1e-4f ? outward.normalized : Random3(rng);
                bool soft = i % 3 != 0;
                var vel = (outward * R(rng, .5f, 1.3f) + Vector3.up * R(rng, .15f, .5f) + Random3(rng) * .25f) * s;
                float size = (soft ? R(rng, .2f, .34f) : R(rng, .07f, .14f)) * s;
                // Drift slowly and linger: the body is seen to thin into the air, not blink out.
                Add(new Mark { pos = at, vel = vel, drag = soft ? 1.2f : .9f, gravity = soft ? -.35f * s : .3f * s,
                    cell = MoteCell(soft ? Mote.Puff : Mote.Spark), color = Pick(p, rng, .35f, 1f), size = size, sizeEnd = soft ? size * 2.6f : size * .3f,
                    rot = R(rng, 0, 360), spin = R(rng, -120, 120), life = R(rng, .8f, 1.3f), delay = delays[i], peak = .12f,
                    opacity = soft ? .6f : 1f, hot = soft ? .2f : .8f });
            }
        }

        /// A mirror footprint flat on the floor that flashes as the runner passes and fades.
        public void Footprint(Profile p, Vector3 at, float delay, float heading, float s, System.Random rng)
        {
            // Large enough to read on the floor from the low camera (it is seen at a grazing
            // angle), with a short upright glint so each step flashes as the runner passes.
            float size = R(rng, .36f, .46f) * s;
            Add(new Mark { pos = at, cell = MoteCell(Mote.Shard), color = Pick(p, rng, .6f, 1f), size = size * 1.3f, sizeEnd = size,
                rot = heading, life = R(rng, .75f, .95f), delay = delay, peak = .08f, flat = true, opacity = 1f, hot = .9f });
            Add(new Mark { pos = at + Vector3.up * .08f * s, cell = Star(rng.Next(4)), color = Color.Lerp(p.hot, Color.white, .4f), size = .1f * s, sizeEnd = .55f * s,
                rot = R(rng, 0, 360), life = .22f, delay = delay, peak = .25f, pop = true, opacity = .7f, hot = 1f });
        }

        /// A bright head flying the same ballistic course as a launch trail (no drag).
        public void Projectile(Vector3 from, Vector3 velocity, float gravity, float delay, float time, float size, Mote mote, Color color, float stretch, float spin)
        {
            Add(new Mark { pos = from, vel = velocity, gravity = gravity, drag = 0f, cell = MoteCell(mote), color = color, size = size, sizeEnd = size * .85f,
                rot = 0f, spin = spin, life = time + .03f, delay = delay, peak = .06f, opacity = 1f, hot = .85f, stretch = stretch });
        }

        /// Flowing light: motes that ride the course a little behind the head, each on its
        /// own small offset, so a stream of light pours along the course into the target.
        public void Stream(Profile p, Func<float, Vector3> course, float delay, float time, float s, int count, Mote mote, System.Random rng)
        {
            if (ReducedMotion) count = Mathf.RoundToInt(count * .6f);
            var white = Color.Lerp(p.hot, Color.white, .3f);
            for (int i = 0; i < count; i++)
            {
                float lag = R(rng, .02f, .4f) * time;
                var offset = Random3(rng) * R(rng, .03f, .16f) * s;
                var type = i % 3 == 0 ? mote : Mote.Spark;
                float size = R(rng, .07f, .15f) * s * (type == Mote.Spark ? 1f : 1.3f);
                Add(new Mark { course = course, travel = time, lag = offset, pos = course(0) + offset, drag = 6f, cell = MoteCell(type),
                    color = i % 4 == 0 ? white : Pick(p, rng, .45f, 1f), size = size, sizeEnd = size * .55f, rot = R(rng, 0, 360), spin = R(rng, -300, 300),
                    stretch = type == Mote.Spark ? .006f : 0f, life = time + .06f, delay = delay + lag, peak = .7f, opacity = type == Mote.Spark ? .15f : .5f, hot = .85f });
            }
        }

        /// A soft glow and a four-point glint riding a course with the flying element (the
        /// basic's tarot, a running shadow, the dash), which has no bright head of its own.
        public void Follow(Func<float, Vector3> course, float delay, float time, float size, Color color, System.Random rng)
        {
            Add(new Mark { course = course, travel = time, pos = course(0), drag = 40f, cell = Star(rng.Next(4)), color = color, size = size * .7f, sizeEnd = size,
                rot = R(rng, 0, 360), spin = R(rng, -120, 120), life = time + .02f, delay = delay, peak = .85f, opacity = .3f, hot = .9f });
            Add(new Mark { course = course, travel = time, pos = course(0), drag = 40f, cell = MoteCell(Mote.Glint), color = Color.Lerp(color, Color.white, .5f), size = size * .5f, sizeEnd = size * .75f,
                rot = R(rng, -10, 10), spin = R(rng, -30, 30), life = time + .02f, delay = delay, peak = .85f, opacity = .15f, hot = 1f });
        }

        /// Four-point glints popping along a course as the head passes.
        public void Twinkles(Profile p, Func<float, Vector3> course, float delay, float time, float s, int count, System.Random rng)
        {
            var white = Color.Lerp(p.hot, Color.white, .6f);
            for (int i = 0; i < count; i++)
            {
                float u = (i + R(rng, .2f, .8f)) / count, size = R(rng, .3f, .5f) * s;
                Add(new Mark { pos = course(u) + Random3(rng) * .12f * s, cell = MoteCell(i % 2 == 0 ? Mote.Glint : Mote.Twinkle), color = white, size = size * .2f, sizeEnd = size,
                    rot = R(rng, -15, 15), spin = R(rng, -80, 80), life = R(rng, .18f, .28f), delay = delay + u * time, peak = .3f, pop = true, opacity = .15f, hot = 1f });
            }
        }

        /// The contact bursting open, lit: a white flash, a starburst and a torn splash in the
        /// identity's colours opening to 'reach', light thrown out in every direction across
        /// the screen plane (fast at first, then slowing, so it opens at once and settles),
        /// the identity's matter flung after it, and on the floor a splash under the target.
        /// All of it is gone within about .6 s.
        public void Explode(Profile p, Frame f, float reach, float delay, bool lead, System.Random rng)
        {
            float s = f.s;
            var hot = f.target + f.toCam * .35f * s;
            var white = Color.Lerp(p.hot, Color.white, .6f);
            Add(new Mark { pos = hot + f.toCam * .1f * s, cell = MoteCell(Mote.Glint), color = white, size = .2f * reach, sizeEnd = (lead ? .9f : .6f) * reach,
                rot = R(rng, -10, 10), spin = R(rng, -60, 60), life = .17f, delay = delay, peak = .2f, pop = true, opacity = .25f, hot = 1f });
            Add(new Mark { pos = hot, cell = Star(rng.Next(4)), color = Color.Lerp(Pick(p, rng, .55f, .95f), p.core, .2f), size = .45f * reach, sizeEnd = 2.1f * reach,
                rot = R(rng, 0, 360), spin = R(rng, -40, 40), life = .34f, delay = delay + .01f, peak = .18f, pop = true, opacity = .45f, hot = .7f });
            if (lead)
            {
                Add(new Mark { pos = hot - f.toCam * .1f * s, cell = Splash(rng.Next(4)), color = Pick(p, rng, .3f, .75f), size = .45f * reach, sizeEnd = 1.8f * reach,
                    rot = R(rng, 0, 360), spin = R(rng, -50, 50), life = .42f, delay = delay + .02f, peak = .2f, pop = true, opacity = .85f, hot = .2f });
                Add(new Mark { pos = new Vector3(f.target.x, .04f, f.target.z), cell = Splash(rng.Next(4)), color = Pick(p, rng, .2f, .6f), size = .4f * reach, sizeEnd = 1.5f * reach,
                    rot = R(rng, 0, 360), spin = R(rng, -20, 20), life = .5f, delay = delay + .02f, peak = .22f, pop = true, flat = true, opacity = .8f, hot = .1f });
            }
            // Light thrown out across the screen plane: v0/drag is how far each ray can go.
            int rays = lead ? 20 : 11, debris = lead ? 22 : 10;
            if (ReducedMotion) { rays = rays * 3 / 5; debris = debris * 3 / 5; }
            float a0 = R(rng, 0f, 6.283f);
            for (int i = 0; i < rays; i++)
            {
                float ang = a0 + 6.283f * (i + R(rng, -.4f, .4f)) / rays;
                var d = (Mathf.Cos(ang) * f.right + Mathf.Sin(ang) * f.up + f.toCam * R(rng, -.15f, .3f)).normalized;
                Add(new Mark { pos = hot, vel = d * reach * 6f * R(rng, .7f, 1.1f), drag = 6f, stretch = .02f, cell = MoteCell(Mote.Spark),
                    color = i % 3 == 0 ? white : Color.Lerp(Pick(p, rng, .5f, 1f), p.hot, .3f), size = R(rng, .05f, .09f) * reach, sizeEnd = .02f * reach,
                    life = R(rng, .3f, .46f), delay = delay + R(rng, 0f, .03f), peak = .15f, opacity = .25f, hot = .9f });
            }
            // The identity's matter flung out after the light.
            for (int i = 0; i < debris; i++)
            {
                var type = i % 3 == 2 ? p.mote2 : p.mote;
                var d = (Random3(rng) * .5f + (Mathf.Cos(a0 + i * 2.4f) * f.right + Mathf.Sin(a0 + i * 2.4f) * f.up)).normalized;
                float size = R(rng, .06f, .12f) * reach * (type == Mote.Card || type == Mote.Petal ? 1.4f : type == Mote.Spark ? .8f : 1f);
                Add(new Mark { pos = hot + d * .05f * reach, vel = d * reach * 4f * R(rng, .5f, 1f), drag = 4f,
                    gravity = type == Mote.Ember || type == Mote.Wisp || type == Mote.Puff ? -.8f * reach : type == Mote.Shard || type == Mote.Card ? 1.6f * reach : .4f * reach,
                    stretch = type == Mote.Spark ? .015f : 0f, cell = MoteCell(type), color = Pick(p, rng, .35f, 1f), size = size, sizeEnd = size * .45f,
                    rot = R(rng, 0, 360), spin = R(rng, -540, 540), life = R(rng, .4f, .65f), delay = delay + R(rng, .01f, .05f), peak = .2f,
                    opacity = type == Mote.Spark || type == Mote.Ember || type == Mote.Wisp ? .3f : .85f, hot = type == Mote.Spark ? .8f : .3f });
            }
        }

        /// The glow behind a casting hero: soft blooms of the identity's colours round the
        /// figure (centre, either side, above the head) that swell to the release and fade
        /// after it, a glow on the floor round the feet, and a star that opens behind the
        /// chest at the release. Drawn before the hero (under material), so the figure stays
        /// clear and the light shows round its outline.
        public void Aura(Profile p, Vector3 centre, Vector3 floor, Vector3 right, float h, float release, bool basic, System.Random rng)
        {
            float life = release + (basic ? .25f : .45f), peak = Mathf.Clamp(release / life, .2f, .8f);
            int layers = basic ? 2 : 4;
            for (int i = 0; i < layers; i++)
            {
                var at = centre + (i == 1 ? right * .3f * h : i == 2 ? -right * .3f * h : i == 3 ? Vector3.up * .45f * h : Vector3.zero);
                float size = (basic ? .95f : 1.35f) * h * (i == 0 ? 1.25f : .9f);
                var c = Pick(p, rng, .55f, .95f) * 1.35f; c.a = 1f;
                Add(new Mark { pos = at, cell = MoteCell(Mote.Puff), color = c, size = size * .5f, sizeEnd = size, rot = R(rng, 0, 360), spin = R(rng, -25, 25),
                    life = life, delay = i * .03f, peak = peak, opacity = .22f, hot = .35f });
            }
            if (basic) return;
            Add(new Mark { pos = floor, cell = MoteCell(Mote.Puff), color = Pick(p, rng, .5f, .9f), size = .9f * h, sizeEnd = 2.4f * h, rot = R(rng, 0, 360),
                life = life, delay = 0f, peak = peak, flat = true, opacity = .25f, hot = .3f });
            Add(new Mark { pos = centre + Vector3.up * .15f * h, cell = Star(rng.Next(4)), color = Pick(p, rng, .6f, 1f), size = .6f * h, sizeEnd = 2.4f * h,
                rot = R(rng, 0, 360), spin = R(rng, -30, 30), life = .4f, delay = Mathf.Max(0f, release - .05f), peak = .25f, pop = true, opacity = .25f, hot = .6f });
        }

        /// Light on and around the casting hero, in front of it: the identity's matter rising
        /// off the body, four-point glints popping on its outline, the flash at the hand when
        /// the card leaves, and light thrown out from the chest at that moment.
        /// Mirror glints that flash along a cut as its stroke passes.
        public void AlongCut(Profile p, Vector3[] points, float delay, float sweep, float s, System.Random rng)
        {
            if (points == null || points.Length < 2) return;
            var white = Color.Lerp(p.hot, Color.white, .6f);
            const int n = 4;
            for (int i = 0; i < n; i++)
            {
                float u = (i + R(rng, .2f, .8f)) / n, size = R(rng, .35f, .6f) * s;
                var at = points[Mathf.Clamp(Mathf.RoundToInt(u * (points.Length - 1)), 0, points.Length - 1)];
                Add(new Mark { pos = at, cell = MoteCell(i % 2 == 0 ? Mote.Glint : Mote.Twinkle), color = white, size = size * .15f, sizeEnd = size,
                    rot = R(rng, -15, 15), spin = R(rng, -90, 90), life = R(rng, .22f, .32f), delay = delay + u * sweep, peak = .25f, pop = true, opacity = .2f, hot = 1f });
            }
        }

        public void CastSparkle(Profile p, Vector3 feet, Vector3 chest, Vector3 hand, Vector3 right, Vector3 up, Vector3 toCam, float h, float release, bool basic, System.Random rng)
        {
            var white = Color.Lerp(p.hot, Color.white, .55f);
            // Light rising off the figure: fine sparks and star glints with a touch of the
            // identity's mote (in place of the broad tongues of 169.50-169.60, so more of them).
            int rise = basic ? 4 : 26;
            for (int i = 0; i < rise; i++)
            {
                var type = basic ? (i % 3 == 2 ? Mote.Spark : p.mote) : i % 4 == 0 ? Mote.Glint : i % 4 == 1 ? p.mote : Mote.Spark;
                var at = feet + up * R(rng, .05f, .95f) * h + right * R(rng, -.36f, .36f) * h + toCam * .15f * h;
                float size = R(rng, .04f, .09f) * h * (type == Mote.Spark ? .8f : type == Mote.Glint ? 1.3f : 1.1f);
                Add(new Mark { pos = at, vel = up * R(rng, .5f, 1.3f) * h + right * R(rng, -.25f, .25f) * h, gravity = -.4f * h, drag = 1.2f,
                    cell = MoteCell(type), color = Pick(p, rng, .45f, 1f), size = size, sizeEnd = size * .4f, rot = R(rng, 0, 360), spin = R(rng, -200, 200),
                    stretch = type == Mote.Spark ? .01f : 0f, life = R(rng, .4f, .7f), delay = R(rng, 0f, release + .05f), peak = .3f,
                    opacity = type == Mote.Spark ? .2f : .6f, hot = .7f });
            }
            int glints = basic ? 3 : 8;
            for (int i = 0; i < glints; i++)
            {
                float u = (i + R(rng, .1f, .9f)) / glints, size = R(rng, .26f, .44f) * h;
                var at = feet + up * R(rng, .25f, 1.05f) * h + right * R(rng, .18f, .42f) * h * (i % 2 == 0 ? 1f : -1f) + toCam * .2f * h;
                Add(new Mark { pos = at, cell = MoteCell(i % 2 == 0 ? Mote.Glint : Mote.Twinkle), color = white, size = size * .2f, sizeEnd = size,
                    rot = R(rng, -12, 12), spin = R(rng, -60, 60), life = R(rng, .2f, .3f), delay = u * (release + .1f), peak = .3f, pop = true, opacity = .15f, hot = 1f });
            }
            // The flash at the hand as the card leaves.
            Add(new Mark { pos = hand + toCam * .2f * h, cell = MoteCell(Mote.Glint), color = white, size = .12f * h, sizeEnd = (basic ? .55f : .85f) * h,
                rot = R(rng, -8, 8), spin = R(rng, -40, 40), life = .24f, delay = Mathf.Max(0f, release - .04f), peak = .25f, pop = true, opacity = .2f, hot = 1f });
            Add(new Mark { pos = hand + toCam * .15f * h, cell = Star(rng.Next(4)), color = Pick(p, rng, .6f, 1f), size = .2f * h, sizeEnd = (basic ? .5f : .9f) * h,
                rot = R(rng, 0, 360), spin = R(rng, -60, 60), life = .3f, delay = Mathf.Max(0f, release - .03f), peak = .2f, pop = true, opacity = .3f, hot = .8f });
            if (basic) return;
            // At the release the figure itself lights up (pure additive over the body)...
            Add(new Mark { pos = chest + toCam * .1f * h, cell = MoteCell(Mote.Puff), color = Pick(p, rng, .6f, 1f), size = .5f * h, sizeEnd = 1.2f * h,
                life = .28f, delay = Mathf.Max(0f, release - .04f), peak = .3f, pop = true, opacity = 0f, hot = .5f });
            // ...and light is thrown out from the chest, upward and to the sides.
            for (int i = 0; i < 14; i++)
            {
                float ang = Mathf.Lerp(-35f, 215f, (i + R(rng, .1f, .9f)) / 14f) * Mathf.Deg2Rad;
                var d = (Mathf.Cos(ang) * right + Mathf.Sin(ang) * up + toCam * R(rng, -.1f, .2f)).normalized;
                Add(new Mark { pos = chest + toCam * .2f * h, vel = d * R(rng, 4f, 7f) * h, drag = 5.5f, stretch = .018f, cell = MoteCell(Mote.Spark),
                    color = Color.Lerp(Pick(p, rng, .6f, 1f), white, .3f), size = R(rng, .07f, .11f) * h, sizeEnd = .03f * h,
                    life = R(rng, .3f, .45f), delay = release + R(rng, -.03f, .03f), peak = .15f, opacity = .2f, hot = .9f });
            }
        }

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
                if (t >= 0 && m.orbit)
                {
                    float k = Mathf.Clamp01(t / m.life), e = 1 - (1 - k) * (1 - k);
                    float a = m.a0 + m.w * t, r = Mathf.Lerp(m.r0, m.r1, e);
                    m.pos = m.oc + (Mathf.Cos(a) * m.ou + Mathf.Sin(a) * m.ov) * r + m.oax * m.rise * k;
                    m.rot += m.spin * dt;
                }
                else if (t >= 0 && m.course != null && t < m.travel)
                {
                    // Velocity follows the motion so a stretched mote streaks along the course.
                    var next = m.course(Mathf.Clamp01(t / m.travel)) + m.lag;
                    if (dt > 1e-5f) m.vel = (next - m.pos) / dt;
                    m.pos = next;
                    m.rot += m.spin * dt;
                }
                else if (t >= 0)
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

    static Profile P(string id, Family family, Family alt, Style style, string[] ramp, string line, string core, string wash, string hot, Mote mote, Mote mote2, Matter matter, Accent accent, bool column = false, float scale = 1f, float wobble = 0f, Form form = Form.Bloom)
    {
        var colors = new Color[ramp.Length];
        for (int i = 0; i < ramp.Length; i++) colors[i] = C(ramp[i]);
        return new Profile { id = id, family = family, familyAlt = alt, style = style, ramp = colors, line = C(line), core = C(core), wash = C(wash), hot = C(hot), mote = mote, mote2 = mote2, matter = matter, accent = accent, column = column, scale = scale, wobble = wobble, form = form };
    }

    static readonly string[] Rainbow = { "#ff2a3c", "#ff7a1a", "#ffd21f", "#3ddc6a", "#28c8ff", "#4c6bff", "#b44cff" };

    static readonly Dictionary<string, Profile> Profiles = new Dictionary<string, Profile>
    {
        // Hero: the Fool's tarot light is prismatic; each card keeps its own form.
        // Basic attack: the flicked tarot (FoolBasicTarotVFX) flies; the landing is a small nick and sparks.
        ["paper"] = P("paper", Family.Surge, Family.Surge, Style.Light, new[] { "#5a1bd6", "#b04cff", "#ff5fd0", "#ffc94a", "#7fe8ff" }, "#ffd76a", "#fff4d8", "#7a2cff", "#ffe2a8", Mote.Card, Mote.Spark, Matter.Filigree, Accent.None, false, 1f, 0f, Form.Flick),
        // Sidestep strike: the hero's afterimage dashes through on mirror footprints and leaves a crossed mirror cut.
        ["sidestep"] = P("sidestep", Family.MirrorCut, Family.MirrorCut, Style.Strike, new[] { "#3a0f8f", "#8a3dff", "#ff58c8", "#ffb22e", "#fff0b0" }, "#ffd35a", "#fff6e0", "#8c2bff", "#ffd9a0", Mote.Shard, Mote.Card, Matter.Crystal, Accent.None, false, 1f, 0f, Form.Dash),
        ["mask"] = P("mask", Family.Fan, Family.Fan, Style.Control, new[] { "#0a3a66", "#1f8ad6", "#3ad6e8", "#a57bff", "#f0f4ff" }, "#dff8ff", "#ffffff", "#2aa6c8", "#e8fbff", Mote.Shard, Mote.Wisp, Matter.Crystal, Accent.Shards),
        ["identity"] = P("identity", Family.Fan, Family.Fan, Style.Control, new[] { "#1a4dff", "#46b8ff", "#f4f1ff", "#ffb04a", "#ff6a1f" }, "#ffe0a0", "#ffffff", "#3b6cff", "#ffe6c2", Mote.Card, Mote.Wisp, Matter.Smoke, Accent.Vortex),
        // Forged evidence: a red wax seal thrown on a low arc, slammed onto the target, splashing forward.
        ["seal"] = P("seal", Family.Falling, Family.Falling, Style.Strike, new[] { "#1a0306", "#5a0a12", "#a3141f", "#e0392b", "#ffb36b" }, "#ffcf8a", "#fff0d8", "#a3141f", "#ffd0a0", Mote.Ember, Mote.Ink, Matter.Flame, Accent.Cracks, false, 1f, 0f, Form.Throw),
        // Twin pursuit: two violet shadows run low at the target; the second bites.
        ["chase"] = P("chase", Family.Twin, Family.Twin, Style.Strike, new[] { "#1d0b33", "#43186e", "#8a3dff", "#c77dff", "#f3e0ff" }, "#d6a8ff", "#f6e8ff", "#43186e", "#e6c2ff", Mote.Wisp, Mote.Spark, Matter.Smoke, Accent.None, false, 1f, 0f, Form.Hunt),
        // Absurd finale: a volley of stage props rains onto the target, a spotlight rises, curtains close.
        ["climax"] = P("climax", Family.Crescent, Family.Crescent, Style.Heavy, Rainbow, "#ffd24a", "#fff8e0", "#ff4a14", "#ffe39a", Mote.Card, Mote.Spark, Matter.Filigree, Accent.None, false, 1f, 0f, Form.Rain),
        ["reversal"] = P("reversal", Family.Curtain, Family.Curtain, Style.Strike, new[] { "#3a0640", "#a81f86", "#ff4fae", "#ffb04a", "#6a3cff" }, "#ffd07a", "#ffe6f4", "#c2289a", "#ffd4ec", Mote.Petal, Mote.Spark, Matter.Silk, Accent.Orbit),
        ["ward"] = P("ward", Family.Rising, Family.Rising, Style.Support, new[] { "#0b5a8a", "#39c6ff", "#8ae0ff", "#ffd66b", "#ffffff" }, "#fff0b0", "#ffffff", "#2a9fe0", "#e6f8ff", Mote.Wisp, Mote.Spark, Matter.Water, Accent.None, false, 1f, 0.04f),
        ["declaration"] = P("declaration", Family.Rising, Family.Rising, Style.Heavy, new[] { "#2b1466", "#6a3cff", "#c07aff", "#ffcf6a", "#fff4dc" }, "#ffd76a", "#fffaf0", "#6f3cff", "#fff0cc", Mote.Card, Mote.Shard, Matter.Filigree, Accent.Vortex, true),

        // Mainline enemies.
        ["guard"] = P("guard", Family.Twin, Family.Twin, Style.Strike, new[] { "#4a0610", "#c01a24", "#ff5a1e", "#ffc23a", "#fff0c0" }, "#ffcf6a", "#fff1d6", "#d8341c", "#ffd9a8", Mote.Spark, Mote.Ember, Matter.Flame, Accent.SwordQi),
        ["archivist"] = P("archivist", Family.Falling, Family.Twin, Style.Strike, new[] { "#081a3a", "#1a4fb8", "#2a9aff", "#ffb02a", "#fff0c0" }, "#ffd27a", "#f4fbff", "#2f86e0", "#dff4ff", Mote.Spark, Mote.Shard, Matter.Electric, Accent.Lightning),
        ["fog-ghost"] = P("fog-ghost", Family.Tide, Family.Surge, Style.Strike, new[] { "#0a1f4f", "#1f66c8", "#2fc8ff", "#8a7bff", "#e6fdff" }, "#bff6ff", "#f2feff", "#1d6fd8", "#dcfbff", Mote.Wisp, Mote.Puff, Matter.Water, Accent.Foam, false, 1f, 0.06f),
        ["crimson-ghost"] = P("crimson-ghost", Family.Surge, Family.Tide, Style.Strike, new[] { "#3a0620", "#b0124a", "#ff4f7a", "#a04cff", "#ffd0dc" }, "#ffc0cf", "#fff0f4", "#c01848", "#ffd6e0", Mote.Wisp, Mote.Puff, Matter.Smoke, Accent.Vortex),
        ["early-hound"] = P("early-hound", Family.Rising, Family.Surge, Style.Light, new[] { "#3a0602", "#c41a06", "#ff6a0a", "#ffb81f", "#fff0a0" }, "#ffd35a", "#fff3d0", "#ff4a0c", "#ffd08a", Mote.Ember, Mote.Spark, Matter.Flame, Accent.Orbit),
        ["hound"] = P("hound", Family.Surge, Family.Tide, Style.Strike, new[] { "#4a0a04", "#d62a0a", "#ff7a14", "#ffc93a", "#fff2b0" }, "#ffd35a", "#fff3d0", "#ff4a0c", "#ffd08a", Mote.Ember, Mote.Spark, Matter.Flame, Accent.Wings),
        ["magma"] = P("magma", Family.Tide, Family.Falling, Style.Heavy, new[] { "#1a0402", "#8a1206", "#ff4a0a", "#ffa21f", "#fff0a0" }, "#ffc24a", "#fff0c8", "#ff3a08", "#ffc070", Mote.Ember, Mote.Shard, Matter.Flame, Accent.Cracks),
        // Smaller (.7): its straight spires landing on the hero, close to the camera, filled the whole screen (169.70).
        ["emerald"] = P("emerald", Family.Rising, Family.Fan, Style.Heavy, new[] { "#032a1a", "#0e8a4a", "#3cff8a", "#c8ff5a", "#fff6b0" }, "#d8ff7a", "#f4ffe0", "#16c85a", "#e2ffc0", Mote.Ember, Mote.Puff, Matter.Flame, Accent.Spikes, false, .7f),
        ["mind"] = P("mind", Family.Fan, Family.Fan, Style.Strike, new[] { "#06202a", "#127a8a", "#5ae0e8", "#e0f8ff", "#ffd88a" }, "#ffe6a8", "#ffffff", "#1a9aaa", "#e0fbff", Mote.Card, Mote.Wisp, Matter.Smoke, Accent.Orbit),
        ["leech"] = P("leech", Family.Surge, Family.Rising, Style.Strike, new[] { "#200a3a", "#7a1fae", "#d85cff", "#ffd0f4", "#9fe8ff" }, "#f2c6ff", "#fff0ff", "#8a28c8", "#f6dcff", Mote.Card, Mote.Ink, Matter.Ink, Accent.Vortex),
        ["scribe"] = P("scribe", Family.Surge, Family.Twin, Style.Strike, new[] { "#12041f", "#4a148a", "#a33cff", "#ff5fb0", "#ffd36a" }, "#ffcf5a", "#f8e8ff", "#7a22d0", "#f0d4ff", Mote.Ink, Mote.Spark, Matter.Ink, Accent.Splatter),
        ["executor"] = P("executor", Family.Twin, Family.Surge, Style.Heavy, new[] { "#120a04", "#5a3208", "#d68a14", "#ffd24a", "#fff6d0" }, "#ffe08a", "#fff8e8", "#d87a10", "#ffe2a8", Mote.Ink, Mote.Spark, Matter.Ink, Accent.Splatter),
        ["chronarch"] = P("chronarch", Family.Falling, Family.Fan, Style.Heavy, new[] { "#1a0e04", "#8a4a12", "#e8a02e", "#3ad6c0", "#e8fff8" }, "#ffd76a", "#fff4d8", "#e0821a", "#ffe4a8", Mote.Shard, Mote.Card, Matter.Filigree, Accent.Dragon, true, 1.08f),
        ["matriarch"] = P("matriarch", Family.Curtain, Family.Twin, Style.Strike, new[] { "#3a0412", "#c0142e", "#ff4f6a", "#ff9ab0", "#f4f6ff" }, "#f4f6ff", "#ffffff", "#d01a3a", "#ffd8e0", Mote.Petal, Mote.Shard, Matter.Silk, Accent.Orbit),
        ["rescue"] = P("rescue", Family.Fan, Family.Falling, Style.Strike, new[] { "#3a1a04", "#b86a14", "#ffb23a", "#ffd86a", "#ffffff" }, "#ffe08a", "#fff8e8", "#e08a1a", "#ffe6b8", Mote.Puff, Mote.Spark, Matter.Smoke, Accent.Cracks),
        ["adjudicator"] = P("adjudicator", Family.Falling, Family.Falling, Style.Heavy, new[] { "#0a1426", "#2a4a7a", "#6aa0e0", "#e8f0ff", "#ffd36a" }, "#ffd36a", "#f4f8ff", "#2a5ab0", "#dce8ff", Mote.Shard, Mote.Puff, Matter.Crystal, Accent.Cracks, false, 1.08f),
        ["convoy"] = P("convoy", Family.Tide, Family.Tide, Style.Heavy, new[] { "#1a0a06", "#5a2410", "#b8501a", "#ff8a3a", "#ffd8a0" }, "#ffb86a", "#fff0dc", "#b84a14", "#ffd0a0", Mote.Shard, Mote.Puff, Matter.Smoke, Accent.Shards, false, 1.08f),
        ["elite"] = P("elite", Family.Twin, Family.Falling, Style.Heavy, new[] { "#3a0608", "#b81a1a", "#ff6a2a", "#ffd24a", "#fff8e0" }, "#ffd35a", "#fff6e0", "#e0301a", "#ffd4a0", Mote.Spark, Mote.Shard, Matter.Crystal, Accent.SwordRain, true),

        // Church tower beasts.
        ["stonehide"] = P("stonehide", Family.Falling, Family.Falling, Style.Heavy, new[] { "#1a1006", "#6a4a1a", "#d69a3a", "#ffe08a", "#fff8e0" }, "#ffd87a", "#fff6e0", "#c87a2a", "#ffe0b0", Mote.Shard, Mote.Puff, Matter.Crystal, Accent.Cracks),
        ["saltmaw"] = P("saltmaw", Family.Rising, Family.Fan, Style.Strike, new[] { "#0a2a3a", "#2ab8d6", "#e8ffff", "#ff9ad6", "#b58cff" }, "#ffffff", "#ffffff", "#2ab0d0", "#eaffff", Mote.Shard, Mote.Spark, Matter.Crystal, Accent.Spikes),
        ["salt-poison"] = P("salt-poison", Family.Tide, Family.Tide, Style.Strike, new[] { "#062a1a", "#1a8a5a", "#6affb0", "#e8ffd0", "#c8ffff" }, "#e0fff0", "#ffffff", "#1aa86a", "#e0ffe8", Mote.Puff, Mote.Ember, Matter.Smoke, Accent.Orbit, false, 1f, 0.04f),
        ["shellback"] = P("shellback", Family.Twin, Family.Surge, Style.Strike, new[] { "#2a0a06", "#8a2a12", "#e86a2a", "#ffc24a", "#fff0c8" }, "#ffd06a", "#fff2dc", "#d8501a", "#ffd8a8", Mote.Spark, Mote.Shard, Matter.Smoke, Accent.Shards),
        ["ironclaw"] = P("ironclaw", Family.Twin, Family.Twin, Style.Strike, new[] { "#0a1a2a", "#2a6ab8", "#5ad0ff", "#ffc24a", "#ffffff" }, "#ffe08a", "#ffffff", "#3a8ad0", "#e6f8ff", Mote.Spark, Mote.Shard, Matter.Crystal, Accent.SwordQi),
        ["frilled-naga"] = P("frilled-naga", Family.Fan, Family.Surge, Style.Strike, new[] { "#2a1a04", "#b8861a", "#ffd24a", "#fff6c0", "#4ae0c0" }, "#fff0a0", "#fffbe8", "#e0a01a", "#fff0b8", Mote.Wisp, Mote.Spark, Matter.Electric, Accent.None, true, 1f, 0.1f),
        ["boneclaw"] = P("boneclaw", Family.Crescent, Family.Twin, Style.Strike, new[] { "#0a2a2a", "#1aa8a0", "#7ae0c8", "#c8b0ff", "#ffffff" }, "#f4f0d8", "#ffffff", "#18a09a", "#eafff8", Mote.Shard, Mote.Spark, Matter.Crystal, Accent.Spikes),
        ["copperback"] = P("copperback", Family.Tide, Family.Falling, Style.Strike, new[] { "#1a0a04", "#8a3a12", "#e8782a", "#ffc86a", "#4ad6b8" }, "#ffd07a", "#fff2dc", "#d86a1a", "#ffdcaa", Mote.Shard, Mote.Spark, Matter.Crystal, Accent.Cracks),
        ["crimson-brute"] = P("crimson-brute", Family.Falling, Family.Surge, Style.Heavy, new[] { "#2a0404", "#b80c0c", "#ff4a14", "#ffb22a", "#fff0b0" }, "#ffcf4a", "#fff2d0", "#ff300c", "#ffc890", Mote.Ember, Mote.Spark, Matter.Flame, Accent.Meteor),
        ["veil-oracle"] = P("veil-oracle", Family.Curtain, Family.Twin, Style.Strike, new[] { "#2a0418", "#a0124a", "#ff3a6a", "#ffb0c8", "#ffe0a0" }, "#ffd8a0", "#fff0f4", "#c8124a", "#ffd0dc", Mote.Petal, Mote.Wisp, Matter.Silk, Accent.Vortex),
        ["golden-throat"] = P("golden-throat", Family.Fan, Family.Tide, Style.Strike, new[] { "#2a2a04", "#8ab81a", "#e8ff4a", "#ffd24a", "#fff8d0" }, "#fff0a0", "#fffbe0", "#b8d01a", "#fff4b0", Mote.Puff, Mote.Wisp, Matter.Smoke, Accent.Orbit, false, 1f, 0.12f),
        ["moonfang"] = P("moonfang", Family.Crescent, Family.Twin, Style.Strike, new[] { "#0a0a2a", "#3a4ab8", "#7a9cff", "#ffe08a", "#ffffff" }, "#f4f6ff", "#ffffff", "#4a5ad0", "#eef2ff", Mote.Spark, Mote.Shard, Matter.Smoke, Accent.Tornado),

        // Wanted bosses.
        ["bounty-b01"] = P("bounty-b01", Family.Twin, Family.Twin, Style.Heavy, new[] { "#2a0408", "#9a1020", "#e8484a", "#9ab0d0", "#ffffff" }, "#f0f4ff", "#ffffff", "#c01a24", "#ffd8d8", Mote.Spark, Mote.Shard, Matter.Crystal, Accent.SwordQi),
        ["bounty-b02"] = P("bounty-b02", Family.Rising, Family.Falling, Style.Heavy, new[] { "#2a1804", "#a8741a", "#ffc83a", "#fff2b0", "#ffffff" }, "#ffe08a", "#fffbe8", "#e0a01a", "#fff0c0", Mote.Card, Mote.Spark, Matter.Filigree, Accent.Orbit, true),
        ["bounty-b03"] = P("bounty-b03", Family.Tide, Family.Surge, Style.Heavy, new[] { "#041a3a", "#0a5aa0", "#1fc8e0", "#6ae8ff", "#ffffff" }, "#e0ffff", "#ffffff", "#0a7ac8", "#dcfaff", Mote.Puff, Mote.Spark, Matter.Water, Accent.Foam, false, 1f, 0.05f),
        ["bounty-b04"] = P("bounty-b04", Family.Fan, Family.Surge, Style.Heavy, new[] { "#0e0418", "#3a148a", "#8a3cff", "#ff8a3a", "#ffe08a" }, "#ffcf6a", "#f8ecff", "#6a22d0", "#f0dcff", Mote.Ink, Mote.Card, Matter.Ink, Accent.Orbit),
        ["bounty-b05"] = P("bounty-b05", Family.Twin, Family.Curtain, Style.Strike, new[] { "#2a0206", "#b00a1e", "#ff3a4a", "#ffc0c8", "#ffe8a0" }, "#ffd0a0", "#fff0f0", "#d0101e", "#ffd0d4", Mote.Petal, Mote.Spark, Matter.Silk, Accent.Orbit),
        ["bounty-b06"] = P("bounty-b06", Family.Falling, Family.Tide, Style.Heavy, new[] { "#040e1f", "#12386a", "#3a8ab8", "#bfe8f8", "#ffffff" }, "#dff4ff", "#ffffff", "#1a5a9a", "#dcefff", Mote.Shard, Mote.Puff, Matter.Water, Accent.Cracks, false, 1.08f),
        ["bounty-b07"] = P("bounty-b07", Family.Fan, Family.Tide, Style.Strike, new[] { "#2a1a02", "#c8861a", "#ffc83a", "#9aff5a", "#fff8d0" }, "#fff0a0", "#fffbe0", "#e0a01a", "#fff0b8", Mote.Wisp, Mote.Puff, Matter.Electric, Accent.Orbit, true, 1f, 0.1f),
        ["bounty-b08"] = P("bounty-b08", Family.Twin, Family.Twin, Style.Heavy, new[] { "#5a6aa8", "#ff7ac0", "#7ad0ff", "#c89cff", "#ffffff" }, "#ffffff", "#ffffff", "#8a9ac8", "#f4f8ff", Mote.Shard, Mote.Spark, Matter.Crystal, Accent.SwordRain),
        ["bounty-b09"] = P("bounty-b09", Family.Crescent, Family.Surge, Style.Heavy, new[] { "#1a0804", "#7a2a0a", "#d8661a", "#ffc24a", "#fff0c0" }, "#ffd06a", "#fff4e0", "#c8501a", "#ffd8a0", Mote.Shard, Mote.Ember, Matter.Flame, Accent.Shards),
        ["bounty-b10"] = P("bounty-b10", Family.Curtain, Family.Crescent, Style.Heavy, new[] { "#2a0212", "#a00a3a", "#ff2a5a", "#ff9ab8", "#ffe0a0" }, "#ffd0a0", "#fff0f4", "#d0103a", "#ffd0dc", Mote.Petal, Mote.Wisp, Matter.Silk, Accent.Wings, false, 1.08f),

        // Support semantics.
        ["heal"] = P("heal", Family.Rising, Family.Rising, Style.Support, new[] { "#0a4a3a", "#1ac89a", "#6affc8", "#ffe08a", "#ffffff" }, "#fff0b0", "#ffffff", "#18b88a", "#e0fff4", Mote.Petal, Mote.Spark, Matter.Water, Accent.Lotus, false, 1f, 0.04f),
        ["heal-crimson"] = P("heal-crimson", Family.Rising, Family.Rising, Style.Support, new[] { "#4a0a1a", "#d03a6a", "#ffb0c8", "#ffffff", "#ffe08a" }, "#ffe0b0", "#ffffff", "#d03a6a", "#ffe4ec", Mote.Petal, Mote.Wisp, Matter.Silk, Accent.Lotus),
        ["enemy-ward"] = P("enemy-ward", Family.Rising, Family.Rising, Style.Support, new[] { "#0a1640", "#1f4fc8", "#3aa8ff", "#ffb83a", "#fff2c8" }, "#ffe0a0", "#ffffff", "#3a7ad0", "#e4f2ff", Mote.Shard, Mote.Wisp, Matter.Crystal, Accent.None),
        ["relic-mask"] = P("relic-mask", Family.Rising, Family.Rising, Style.Support, new[] { "#1a0f3a", "#5a3cc8", "#9a8cff", "#e8e4ff", "#ffd88a" }, "#ffe6a8", "#ffffff", "#5a4ad0", "#eeeaff", Mote.Card, Mote.Wisp, Matter.Smoke, Accent.Orbit),
        ["stone-ward"] = P("stone-ward", Family.Rising, Family.Rising, Style.Support, new[] { "#1a1006", "#6a4a1a", "#d69a3a", "#ffe08a", "#fff8e0" }, "#ffd87a", "#fff6e0", "#c87a2a", "#ffe0b0", Mote.Shard, Mote.Spark, Matter.Crystal, Accent.None),
        ["anchor-ward"] = P("anchor-ward", Family.Rising, Family.Rising, Style.Support, new[] { "#040e1f", "#12386a", "#2a7ac8", "#8ad8ff", "#ffffff" }, "#dff4ff", "#ffffff", "#1a5a9a", "#dcefff", Mote.Shard, Mote.Wisp, Matter.Water, Accent.None, false, 1f, 0.04f),
        ["poison-field"] = P("poison-field", Family.Rising, Family.Rising, Style.Support, new[] { "#022414", "#0a7a3a", "#2ae86a", "#b8ff4a", "#f0ffb0" }, "#d8ff7a", "#f4ffe0", "#16b04a", "#d8ffb0", Mote.Puff, Mote.Ember, Matter.Smoke, Accent.None),
        ["escort-ward"] = P("escort-ward", Family.Rising, Family.Rising, Style.Support, new[] { "#041a3a", "#0a5aa0", "#1fc8e0", "#6ae8ff", "#ffffff" }, "#e0ffff", "#ffffff", "#0a7ac8", "#dcfaff", Mote.Wisp, Mote.Spark, Matter.Water, Accent.None, false, 1f, 0.05f),
        ["empower"] = P("empower", Family.Rising, Family.Rising, Style.Support, new[] { "#3a1a04", "#d8861a", "#ffd24a", "#fff6d0", "#ff6a3a" }, "#fff0a0", "#ffffff", "#e0901a", "#fff0c8", Mote.Ember, Mote.Spark, Matter.Flame, Accent.Orbit),
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
