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
[DefaultExecutionOrder(10000)]
public sealed partial class SpellSpectacle20260926 : MonoBehaviour
{
    public enum Family { Crescent, Rising, Falling, Surge, Fan, Twin, Curtain, Tide, MirrorCut }
    public enum Style { Light, Strike, Heavy, Support, Control }
    /// Row in SpectacleMatter; each matter has its own edge, darkness, flow and flicker.
    public enum Matter { Filigree = 0, Flame = 1, Water = 2, Crystal = 3, Silk = 4, Ink = 5, Electric = 6, Smoke = 7 }
    /// Signature element that belongs to one identity, on top of its body.
    public enum Accent { None, Lightning, Cracks, Vortex, Wings, Orbit, Shards, Splatter, Foam,
        // Signature moves: whirlwind, sword qi, sword rain, meteor shower, ground spikes, coiling dragon, lotus bloom.
        Tornado, SwordQi, SwordRain, Meteor, Spikes, Dragon, Lotus,
        // Named moves (2026-10-03, user on the phone, boxing four enemy hits that had shrunk into lumps: 我不要这样的一团的东西，另外，改前的绚丽是值得要的，但要有差异，比如旋风忽大忽小？，飞剑形状？凤凰冲击碎裂开？):
        // a phoenix that charges in and shatters, a formation of flying swords, a great sword of judgment.
        Phoenix, FlyingSwords, JudgmentSword,
        // More named moves so no two enemies of a chapter land the same way:
        // clock hands that close like shears, chains that bind and snap, a beast's claw rake.
        ClockHands, Chains, ClawRake,
        // An executioner's axe chopping down; a fan of long hairpin needles; a great hammer slamming down.
        ExecutionAxe, Needles, Hammer }
    /// Glint and Twinkle are the four-point star glints (tools/vfx-spectacle-20260926/glints.py).
    enum Mote { Spark = 0, Ember = 1, Shard = 2, Ink = 3, Petal = 4, Card = 5, Wisp = 6, Puff = 7, Glint = 8, Twinkle = 9 }
    /// Cells of SpectacleProps (tools/vfx-spectacle-20260926/props.py).
    enum PropCell
    {
        TarotFront = 0, TarotBack = 1, WaxSeal = 2, WaxSplash = 3, WaxDrop = 4, ShardA = 5, ShardB = 6, NameFront = 7, NameBack = 8,
        CrystalA = 9, CrystalB = 10, Spike = 11, InkSplat = 12, InkDrop = 13, WaterSplash = 14, WaterDrop = 15, Bubble = 16,
        Feather = 17, Petal = 18, Sword = 19, Axe = 20, Hammer = 21, ClockHand = 22, ChainLink = 23, Needle = 24, Meteor = 25,
        Coin = 26, BoltA = 27, BoltB = 28, Paw = 29, DragonHead = 30, DragonScale = 31, Mask = 32, RockA = 33, RockB = 34,
        Crater = 35, Phoenix = 36, Page = 37, Qi = 38, Splash = 39,
        // SpectaclePaint.png (tools/vfx-spectacle-20260926/paint_atlas.py): the user's painted
        // props (2026-10-07, after 这些都还不够精细). 4x4 grid; drawn by a second mesh.
        PSword = 100, PAxe = 101, PHammer = 102, PChain = 103, PCoin = 104, PPetal = 105, PLotus = 106,
        PSmokeA = 107, PSmokeB = 108, PSmokeC = 109, PSmokeB2 = 110, PSmokeC2 = 111,
        PClaw = 112, PQi = 113, PFire = 114, PCopperHand = 115,   // 115 was an undrawn fire burst
    }
    /// How a hero card reaches its target. Bloom is the original contact-only
    /// burst; the others leave the hero during the cast, travel the corridor to
    /// the target and land on the contact receipt (2026-10-03: attacks must read
    /// as aimed at the enemy, each card with its own form, not a screen-wide bloom).
    public enum Form { Bloom, Throw, Hunt, Rain, Dash, Flick, Edict, Swap, Reverse, Rewrite, Proclaim }
    /// Signature moves that are the subject of the hit (the heart and spray stay small).
    static bool NamedMove(Accent a) => a is Accent.Phoenix or Accent.FlyingSwords or Accent.JudgmentSword or Accent.Tornado
        or Accent.Dragon or Accent.Meteor or Accent.SwordRain or Accent.ClockHands or Accent.Chains or Accent.ClawRake or Accent.ExecutionAxe or Accent.Needles
        or Accent.Wings or Accent.Hammer;

    /// Forms whose landing has no layer of the identity's broad family bodies.
    static bool Formless(Form form) => form is Form.Throw or Form.Flick or Form.Edict or Form.Swap or Form.Reverse or Form.Rewrite or Form.Proclaim;
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
        /// Game-clock expiry as well (2026-10-09): a cue lapses only when both clocks have run
        /// out, so slow frames (a loaded machine, the review recorder's capture clock) never drop
        /// a contact that is still on its way in game time.
        public float expiresGame = float.PositiveInfinity;
        public bool Expired => Time.unscaledTime > expiresAt && Time.time > expiresGame;
        public int cast;
        public bool player;
        public string intent;
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
    Material sweepMaterial, washMaterial, flareMaterial, propMaterial, paintMaterial, dimMaterial;
    /// Drawn after the battle backdrop (queue 1000) and before the illustrated hero
    /// (Transparent, 3000): light behind the figure and the sigil under its feet,
    /// so the hero stands in front of its own glow.
    Material sweepUnderMaterial, flareUnderMaterial;
    Texture2D matterAtlas, noise, atlas, propAtlas, paintAtlas, paintAtlas2, paintAtlas3;
    Material piecesMaterial;
    readonly Dictionary<string, Material> flipbooks = new Dictionary<string, Material>();
    Transform root;
    Wash wash;
    Dim dim;
    int live, bursts;
    Material inkMaterial, tarotMaterial, paintFlipMaterial, paintFlipMaterial2, paintFlipMaterial3, paintFlipMaterial4, paintFlipMaterial5;

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
        // 后手改写 works on the hero itself: its landing is on the hero, not the enemy.
        if (profile.form == Form.Rewrite && caster != null) { targets = new List<Func<Vector3>> { caster }; targetSeeds = new List<int> { 9 }; }
        // 抢拍开幕 lands on the hero first and nicks its target as well (2026-10-14).
        else if (profile.id == "tempo" && caster != null)
        {
            var self = new List<Func<Vector3>> { caster }; var selfSeeds = new List<int> { 9 };
            for (int i = 0; i < targets.Count; i++) { self.Add(targets[i]); selfSeeds.Add(targetSeeds != null && i < targetSeeds.Count ? targetSeeds[i] : i * 7919); }
            targets = self; targetSeeds = selfSeeds;
        }
        var cue = director.Register("player", profile, profile.style, caster, targets, targetSeeds);
        if (cue == null) return;
        cue.player = true;
        // The ordered loop's three cards draw themselves (SpellSpectacle20260926.Cards1113.cs).
        if (IsOrderedCard(profile.id)) { if (!Suppressed) director.CardLaunch(cue, expectedContact); return; }
        if (profile.form != Form.Bloom && !Suppressed) director.Launch(cue, expectedContact);
    }

    /// True when the hero card has its own travelling form; the tempo samples then
    /// show only this layer for it, without the older full-stage theatre bodies.
    // A delayed contract may explode during another cast. It never replaces that cast's cue.
    public static void OrderedImpact(Component battle, string skillID, Func<Vector3> caster, IList<Func<Vector3>> targets)
    {
        var director = Ensure(battle);
        if (!director || targets == null || targets.Count == 0 || Suppressed) return;
        var profile = PlayerProfile(skillID);
        var cue = director.Register("ordered-impact", profile, profile.style, caster, targets, null);
        if (cue == null) return;
        cue.player = true; cue.intent = "ordered";
        director.Burst(cue);
        director.pending.Remove("ordered-impact");
    }

    public static bool HasForm(string skillID) { var p = PlayerProfile(skillID); return p.form != Form.Bloom || IsOrderedCard(p.id); }

    /// Light coming off the hero while it casts (2026-10-03, user, with the reference
    /// battles: 出技能时主角本身就要冒出各种光). Built once at the cast from the figure
    /// as drawn: <paramref name="chest"/> and <paramref name="feet"/> of the hero.
    public static void CastLight(Component battle, string skillID, Func<Vector3> chest, Func<Vector3> feet, float expectedContact = -1f)
    {
        var director = Ensure(battle);
        if (!director || Suppressed || chest == null || feet == null) return;
        // The ordered loop's quick cards keep the basic's small light: their full cast light
        // washed the hero white (probe8) and their own hits carry the show.
        var profile = PlayerProfile(skillID);
        director.HeroLight(profile, skillID == "basic" || IsOrderedCard(profile.id), SafeEval(chest), SafeEval(feet), expectedContact);
    }

    /// Logs launch and impact geometry (SPELLFORM lines) for Simulator review builds.
    public static bool Diagnostics = Debug.isDebugBuild;

    public static void BeginEnemy(Component battle, EnemyHandle actor, string intent, Func<Vector3> playerTarget, EnemyHandle supportRecipient)
    {
        var director = Ensure(battle);
        if (!director || !actor) return;
        if (HidesLegacyBands) director.hideLegacyUntil = Time.unscaledTime + 4.5f;
        intent = intent ?? "strike";
        string key = "enemy:" + actor.BattleEnemyId;
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
        // 翠焰亡灵's move arrives as emerald-spell:mist / burst just before the plain attack.
        if (model == "emerald" && intent == "strike" && battle is BattlePrototype revenantBattle)
            intent = revenantBattle.EmeraldVariant == 1 ? "emerald_burst" : "memory_breath";
        if (intent == "recover" || IsPreparation(intent))
        {
            director.pending.Remove(key);
            // Body outline trial (2026-10-09): a wind-up turn lights the band in the strike's colours.
            if (intent == "recover") EnemyOutline20261009.Stop(key);
            else { var prep = EnemyProfile(actor.BattleEnemyId, "strike", model); EnemyOutline20261009.Charge(actor, key, prep.line, prep.core, OutlineDeep(prep)); }
            return;
        }
        var profile = EnemyProfile(actor.BattleEnemyId, intent, model);
        var style = EnemyStyle(profile, intent, model);
        if (style != Style.Support) EnemyOutline20261009.Charge(actor, key, profile.line, profile.core, OutlineDeep(profile));
        // The whole body acts in the attack (2026-10-09, user: 敌人的动作都要和守卫的转身攻击一样生动).
        var bodyMove = style == Style.Support ? null : EnemyWholeBody20261009.StyleFor(profile.id, intent);
        // Light gathers at its weapon or hand while it winds up, and fires at the contact.
        if (style != Style.Support && InkStrokes && director.Load() && director.inkMaterial && Camera.main)
        {
            var gk = InkKindFor(profile.id, intent);
            if (gk != null && !SupportKind(gk))
            {
                var hand = HandOf(actor);
                var cam = Camera.main;
                float half = Vector3.Distance(cam.transform.position, hand()) * Mathf.Tan(cam.fieldOfView * .5f * Mathf.Deg2Rad);
                if (director.gathers.TryGetValue(key, out var old) && old) old.Release();
                var gather = Ink2D.CreateGather(director.root, director.inkMaterial, director, cam, hand, .09f * half, StableHash(key) + director.castCount.Count, gk);
                gather.stillActing = () => actor && actor.gameObject.activeInHierarchy && actor.VisualRoot && actor.VisualRoot.gameObject.activeInHierarchy;
                director.gathers[key] = gather;
            }
        }
        if (bodyMove.HasValue && playerTarget != null)
            EnemyWholeBody20261009.Begin(actor, key, bodyMove.Value, SafeEval(playerTarget),
                profile.ramp != null && profile.ramp.Length > 1 ? profile.ramp[1] : profile.line, profile.line, profile.core);
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
        if (style == Style.Support && profile.id == "enemy-ward")
        {
            // Guard / fortify / calibrate: one oval light shield round the body, not bands.
            var who = supportRecipient ? supportRecipient : actor;
            if (who && who.EnemyRoot) OvalLightShield.Flash(who.EnemyRoot, OvalLightShield.Preset.Fortify, 2.2f);
            return;
        }
        var registered = director.Register(key, profile, style, caster, targets, seeds);
        if (registered != null) registered.intent = intent;
    }

    /// Immediate enveloping burst for a state that has no contact callback
    /// (armour lock, manual mask). Support style only: gather, wrap, rise.
    public static void PlayState(Component battle, string profileKey, Func<Vector3> anchor, int seed)
    {
        var director = Ensure(battle);
        if (!director || anchor == null || !Profiles.TryGetValue(profileKey, out var profile)) return;
        // 翠毒漫天's fog thickening: smoke in the fog's green curls up from the poison pool
        // (2026-10-10, user: 这两种绿颜色要一致 - the generic uprising read teal by the bubbles).
        if (profileKey == "poison-field" && DrawsBreath && director.Load() && director.paintFlipMaterial)
        {
            director.PoisonTick(SafeEval(anchor) - Vector3.up * .85f, seed);
            return;
        }
        var cue = new Cue { profile = profile, style = Style.Support, caster = anchor, expiresAt = Time.unscaledTime + 1f };
        director.castCount.TryGetValue("state" + profileKey, out int n);
        director.castCount["state" + profileKey] = n + 1;
        cue.cast = n;
        cue.targets.Add(anchor); cue.seeds.Add(seed);
        director.Burst(cue);
    }

    // ------------------------------------------------------------ Q30 angel intro (2026-10-10)
    // User: 玛拉不出场，教会的天使出现，带走了更强的boss，我们3个打这个小boss; of v4: 进度太快，
    // 反派一般死于多话 … 天使出现后2个人笼罩在一个光团里，看不清，只能看到隐约有剧烈的战斗.
    // ~27 s, paced by the lines (the app's dialogue box carries them): Sevian presses his seal and
    // talks; a rift opens beside him and the outside pursuer - a faceless giant of black mist and
    // salt - rises and casts a cold tether onto the hero's chest; Sevian hands the hero over; a
    // lamp lights in the sky, the lamp-keeping angel Elaia comes down, plants her staff in the rift
    // and the tether snaps; she and the giant vanish into one great ball of light where only
    // shapes and flashes of a fierce fight show; it shrinks into the rift, the rift closes, Sevian
    // has the last word. Painted figures (SpectacleCast 49 the pursuer, 50/51 Elaia descending /
    // sealing), the ink light (Ink2D "angelintro") and a held backdrop dim; the chain, the rift
    // and the tears in the air wait for their paintings. As the two leave, each throws a gift
    // (GiftPos). Times below are real seconds from the command.
    const float AngelIntroSeconds = 28.5f;
    const float AiRiftOpen = 6.6f, AiRise = 7.4f, AiBind = 10.6f, AiLamp = 14f, AiDescend = 14.4f, AiLand = 16.4f,
        AiPlant = 17.4f, AiBall = 18.1f, AiBallEnd = 24.1f, AiClose = 25.1f;   // the ball holds the six-second fight clip (10-11)
    /// The rift's centre from the boss's feet (world units): off to his side, so neither the giant
    /// nor the angel covers him (painted sprites always draw over the bodies).
    static readonly Vector2 AngelRift = new Vector2(1.8f, -.15f);
    /// Where the ball of light hangs: over the rift, round both of them.
    static readonly Vector2 AngelBall = new Vector2(1.6f, 2.3f);
    const float AngelHeight = 3.2f, PursuerHeight = 5.6f;

    /// Elaia's feet in the boss's camera plane at real time r: high above, coming down to hover
    /// over the rift, standing on it while she seals it, darting about inside the ball, sinking
    /// into the rift with it.
    static Vector2 AngelFeet(float r)
    {
        float down = Eout(Iv(AiDescend, AiLand, r)), land = Eout(Iv(AiLand, AiLand + .25f, r)), sink = Ein(Iv(AiBallEnd, AiClose, r));
        float y = Mathf.Lerp(8f, 1.1f, down) - 1.1f * land - 1.6f * sink + .08f * Mathf.Sin(r * 2.2f) * (1f - land);
        return new Vector2(AngelRift.x - .2f, AngelRift.y + .15f + y);
    }
    /// The fight inside the ball (user 10-10: 天使的激战如果你有办法做得更逼真就更好了; 10-11 on the
    /// cut-out version: 本质还是两个几何块状的东西在碰): the user's image-to-video take of the two
    /// of them fighting (SpectacleFight, tools/vfx-spectacle-20260926/fight_atlas.py: 64 frames over
    /// FightClipSeconds), a darkened flipbook inside the light from FightStart, FightFrameWidth
    /// wide round AngelBall. Its blows, read off the clip: clip time, kind (0 she hits him, 1 he
    /// hits her, 4 the grapple bursts apart), power (1 = a big one); FightBlowAt is where in the
    /// frame (u from the left, v from the top). They place the flash, the bulge, the debris, the jolt.
    const float FightStart = AiBall - .2f, FightClipSeconds = 6.08f, FightFrameWidth = 6.8f;
    static readonly Vector3[] FightBlows =
    {
        new Vector3(.8f, 0f, .8f),     // her staff into his chest
        new Vector3(1.85f, 1f, .9f),   // his chain whips down onto her
        new Vector3(2.25f, 1f, .7f),   // his claw throws her back
        new Vector3(3.5f, 0f, 1f),     // down from above, her staff planted on him
        new Vector3(5.05f, 4f, .9f),   // the grapple bursts apart
    };
    static readonly Vector2[] FightBlowAt = { new Vector2(.5f, .42f), new Vector2(.27f, .45f), new Vector2(.35f, .62f), new Vector2(.55f, .33f), new Vector2(.42f, .45f) };
    /// The grapple (clip time) and where it is.
    const float LockFrom = 3.65f, LockTo = 4.95f;
    static readonly Vector2 LockAt = new Vector2(.45f, .35f);
    static float LockAmount(float c) => Iv(LockFrom, LockFrom + .2f, c) * (1f - Iv(LockTo - .05f, LockTo + .05f, c));
    /// A point of the clip's frame in the boss's camera plane (the frame fills 236 of the cell's 256 px).
    static Vector2 FightPoint(Vector2 uv) => FightCentre + new Vector2((uv.x - .5f) * FightFrameWidth * 236f / 256f, (.5f - uv.y) * FightFrameWidth * .5f);
    /// The clip's centre: a little left of the ball's, as the fight happens in the left half of its frame.
    static readonly Vector2 FightCentre = AngelBall + new Vector2(-.45f, 0f);
    /// Which way a blow drives: she is on the left, he on the right.
    static Vector2 BlowDir(float kind) => kind == 0f ? new Vector2(1f, -.15f).normalized : kind == 1f ? new Vector2(-1f, .1f).normalized : Vector2.zero;
    static float Hash01(int n) => Mathf.Repeat(Mathf.Sin(n * 127.1f + 311.7f) * 43758.5453f, 1f);
    /// The light of the latest blow (1 at a big one, fading over half a second), and the grapple's glow.
    static float FightFlash(float r)
    {
        float c = r - FightStart, f = 0f;
        foreach (var e in FightBlows) if (c >= e.x) f = Mathf.Max(f, e.z * Mathf.Pow(1f - Iv(e.x, e.x + .45f, c), 1.6f));
        return Mathf.Max(f, .6f * LockAmount(c));
    }
    /// How clear the fighters are inside the ball: backlit by each blow, then sinking back into the light.
    static float FightShow(float r) => Mathf.Min(.95f, .65f + .3f * FightFlash(r));
    /// The ball pushed by each blow: it bulges out the way the blow drives (for the burst it swells, BallSwell).
    static Vector2 BallPush(float r)
    {
        float c = r - FightStart; var p = Vector2.zero;
        foreach (var e in FightBlows) if (c >= e.x) p += BlowDir(e.y) * (e.z * .45f * Mathf.Exp(-(c - e.x) / .22f) * Mathf.Min(1f, (c - e.x) / .04f));
        return p;
    }
    static float BallSwell(float r)
    {
        float c = r - FightStart, s = 0f;
        foreach (var e in FightBlows) if (c >= e.x && e.z >= .69f) s += e.z * .12f * Mathf.Exp(-(c - e.x) / .2f) * Mathf.Min(1f, (c - e.x) / .04f);
        return s + LockAmount(c) * (.04f + .03f * Mathf.Sin(c * 23f));
    }
    /// The spread-wing paintings fill their cells with the wings, so the figure in them is drawn
    /// smaller: scale up so her body matches the standing painting (measured in the cast atlas).
    const float AngelDescendK = 1.14f, AngelSealK = 1.13f;
    /// Her lantern relative to her feet (the lamp at the top of her staff): raised high on her
    /// right while she comes down, planted in front of her while she seals.
    static Vector2 AngelLampOffset(float r) => r < AiLand - .25f
        ? new Vector2(-.139f, .86f) * (AngelHeight * 1.024f * AngelDescendK)
        : new Vector2(-.045f, .80f) * (AngelHeight * 1.024f * AngelSealK);

    /// The farewell gifts (user 10-10: 2人离开时分别会随机给予主角和小boss一个祝福 - which blessing is
    /// the rules' roll, the picture is the same): out of the light's collapse a flame of her lamp
    /// leaps up and arcs down onto the hero's chest, and a shard of the giant's black salt sinks
    /// into Sevian's. who 0 = hers, 1 = his; target is the chest it lands on.
    const float AiGift = AiClose + .1f;
    static float GiftArrive(int who) => AiGift + (who == 0 ? 1.7f : 1.5f);
    static Vector2 GiftPos(int who, float r, Vector2 target)
    {
        // Up out of the flash, a moment hanging there so they read, then the flight.
        float rise = Eout(Iv(AiGift, AiGift + .45f, r)), fly = Smooth01(Iv(AiGift + .7f, GiftArrive(who), r));
        var from = AngelRift + new Vector2(who == 0 ? -.35f : .35f, .2f + .9f * rise + .06f * Mathf.Sin(r * 6f + who));
        var ctrl = (from + target) * .5f + new Vector2(0f, who == 0 ? 1.8f : 1.1f);
        float e = 1f - fly;
        return e * e * from + 2f * e * fly * ctrl + fly * fly * target;
    }

    /// The tears in the air: centre x, y (world units from the boss's feet), angle, the moment it
    /// rips open (w); length from the table below.
    static readonly Vector4[] AngelTears =
    {
        new Vector4(-2.4f, 3.9f, 24f, 6.9f), new Vector4(3.6f, 4.3f, -18f, 7.4f), new Vector4(.4f, 4.9f, 8f, 8.1f),
        new Vector4(4.2f, 2.2f, 64f, AiBind + .2f), new Vector4(-3.1f, 1.8f, -52f, AiBall + .3f), new Vector4(1.6f, 4.6f, -32f, AiBall + 1.6f),
    };
    /// The tears wait for the user's painted space_tear (the smoke stand-in read as fake, v5).
    const bool AngelTearsPainted = false;
    /// The tether and the rift on the ground wait for the painted chain and tear as well (their
    /// smoke stand-ins still read as fake, v6: 这2团还是有些假): meanwhile the giant looms up out
    /// of the gloom where he stands, and the glow on the hero's chest alone shows him caught.
    const bool AngelChainPainted = false, AngelRiftPainted = false;
    static float Smooth01(float u) { u = Mathf.Clamp01(u); return u * u * (3f - 2f * u); }
    static float TearLen(Vector4 tear) => 3.2f + 1.4f * Mathf.Repeat(tear.x * 1.7f + tear.y, 1f);

    /// How hard the screen shakes at real time r of the intro (1 = a big jolt): a thump as he
    /// presses the seal, a rumble as the rift opens and the giant rises, a jolt as the tether
    /// binds, a big jolt as the staff lands, a rolling rumble with a kick at every clash in the
    /// ball, a last jolt as the rift closes.
    static float AngelTrauma(float r)
    {
        float Jolt(float at, float k, float decay) => r < at ? 0f : k * Mathf.Exp(-(r - at) / decay);
        float v = Jolt(.2f, .25f, .2f) + Jolt(AiBind + .3f, .5f, .25f) + Jolt(AiPlant, 1f, .35f) + Jolt(AiClose, .8f, .4f);
        v += .45f * Iv(AiRiftOpen, AiRiftOpen + .6f, r) * (1f - Iv(AiRise + 1.4f, AiRise + 2.6f, r));
        if (r > AiBall && r < AiBallEnd + .3f)
        {
            // A rolling rumble, a kick at every blow by its power, a straining rumble in the lock.
            float c = r - FightStart, f = .22f + .45f * LockAmount(c);
            foreach (var e in FightBlows) if (c >= e.x) f += e.z * .9f * Mathf.Exp(-(c - e.x) / .16f);
            v += f * Iv(AiBall, AiBall + .4f, r) * (1f - Iv(AiBallEnd, AiBallEnd + .3f, r));
        }
        return Mathf.Min(v, 1.2f);
    }

    /// The camera pushed off its place and rolled a little, before the frame is drawn (30800: ahead
    /// of the review recorder's own render at 31000), and put back first thing next frame by
    /// AngelShakeRestore (-20000, only if nobody else moved it meanwhile) - so the camera rig
    /// never bakes the shake in, and the shake shows in recordings and on the device alike.
    [DefaultExecutionOrder(30800)]
    sealed class AngelShake : MonoBehaviour
    {
        float age; int epoch; public Vector3 basePos, appliedPos; public Quaternion baseRot, appliedRot; public bool written;
        public static void Begin(Camera cam)
        {
            var s = cam.GetComponent<AngelShake>() ?? cam.gameObject.AddComponent<AngelShake>();
            var r = cam.GetComponent<AngelShakeRestore>() ?? cam.gameObject.AddComponent<AngelShakeRestore>();
            r.shake = s; s.age = 0f; s.enabled = true; s.epoch = angelIntroEpoch;
        }
        void LateUpdate()
        {
            age += Time.deltaTime;
            if (age > AngelIntroSeconds || epoch != angelIntroEpoch) { enabled = false; return; }
            float k = AngelTrauma(age) * (ReducedMotion ? .35f : 1f);
            var cam = GetComponent<Camera>();
            float half = cam ? Mathf.Tan(cam.fieldOfView * .5f * Mathf.Deg2Rad) * 8f : 3f;
            float n1 = Mathf.PerlinNoise(age * 19f, 3.1f) - .5f, n2 = Mathf.PerlinNoise(7.7f, age * 21f) - .5f, n3 = Mathf.PerlinNoise(age * 11f, 9.3f) - .5f;
            basePos = transform.position; baseRot = transform.rotation;
            transform.position = basePos + (transform.right * n1 + transform.up * n2) * (k * k * .06f * half);
            transform.rotation = baseRot * Quaternion.Euler(0f, 0f, n3 * k * k * 2.2f);
            appliedPos = transform.position; appliedRot = transform.rotation; written = true;
        }
    }
    [DefaultExecutionOrder(-20000)]
    sealed class AngelShakeRestore : MonoBehaviour
    {
        public AngelShake shake;
        void Update()
        {
            if (!shake || !shake.written) return;
            shake.written = false;
            if (transform.position == shake.appliedPos) transform.position = shake.basePos;
            if (transform.rotation == shake.appliedRot) transform.rotation = shake.baseRot;
        }
    }

    /// Bumped by every intro and by a skip: everything an intro made checks it and goes when it
    /// changes (the app's 跳过 sends angel-intro-skip, 2026-10-11).
    static int angelIntroEpoch;
    public static void SkipAngelIntro() => angelIntroEpoch++;
    public static void AngelIntro(Component battle, Vector3 bossFeet, Func<Vector3> heroChest, Func<Vector3> bossChest = null)
    {
        var director = Ensure(battle);
        if (!director || !director.Load() || !director.paintFlipMaterial4 || !director.inkMaterial || !Camera.main) return;
        director.PlayAngelIntro(bossFeet, SafeEval(heroChest), bossChest != null ? SafeEval(bossChest) : bossFeet + Vector3.up * 1.5f);
    }

    void PlayAngelIntro(Vector3 at, Vector3 chest, Vector3 bossChest)
    {
        int epoch = ++angelIntroEpoch;
        var cam = Camera.main; var ct = cam.transform;
        // Sevian's chest in his own plane (the black salt lands there).
        var bd = bossChest - at; var boss = new Vector2(Vector3.Dot(bd, ct.right), Vector3.Dot(bd, ct.up));
        // The hero's chest seen from the camera, carried to the boss's depth (like BreathStream).
        var hs = cam.WorldToScreenPoint(chest); float depth = cam.WorldToScreenPoint(at).z;
        Vector2 hero = Vector2.zero;
        if (hs.z > 0f && depth > 0f) { var d3 = cam.ScreenToWorldPoint(new Vector3(hs.x, hs.y, depth)) - at; hero = new Vector2(Vector3.Dot(d3, ct.right), Vector3.Dot(d3, ct.up)); }
        float S(float sec) => sec * HitPace;   // PaintSprite clocks run at HitPace
        Pose2 P(Vector2 off, float roll, float scale, float alpha, Color tint, float z) => new Pose2 { off = off, roll = roll, scale = scale, alpha = alpha, tint = tint, z = z };
        // A figure standing with its feet at `feet` (cells keep the feet on the bottom edge, 12 px up).
        Vector2 Stand(Vector2 feet, float height) { float q = height * 1024f / 1000f; return feet + new Vector2(0f, q * .5f - q * 12f / 1024f); }
        // Every painted part of the intro goes at once when it is skipped (or another intro starts).
        void Paint(float end, int cell, Func<float, Pose2> script) =>
            PaintSprite.Create(root, paintFlipMaterial, this, at, 0f, end, cell, t => epoch != angelIntroEpoch ? new Pose2 { scale = -1f } : script(t));

        var light = Ink2D.Create(root, inkMaterial, this, cam, at + Vector3.up, at, 1f, 0f, 9301, "angelintro");
        light.heroOff = hero; light.bossOff = boss; light.stillActing = () => epoch == angelIntroEpoch;
        AngelDim.Create(root, dimMaterial, at + Vector3.up * 1.2f);
        // The whole screen shakes with it (user 10-10: 要整个屏幕都震动，空间撕裂，一片昏暗).
        AngelShake.Begin(cam);
        // Space tearing: black ragged gashes open in the air one after another - with the rift,
        // as the tether binds, through the fight - their edges leaking cold light (AngelLight),
        // all closing with the rift. Painted smoke stretched thin and darkened; never over Sevian.
        for (int k_ = 0; k_ < (AngelTearsPainted ? AngelTears.Length : 0); k_++)
        {
            int k = k_;   // a fresh copy per pass: lambdas below capture it
            var tear = AngelTears[k];
            for (int layer_ = 0; layer_ < 2; layer_++)
            {
                int layer = layer_;
                Paint(S(AiClose + .6f), layer == 0 ? 10 : 8, t =>
                {
                    float r = t / HitPace, rip = Eout(Iv(tear.w, tear.w + .35f, r)) * (1f - Ein(Iv(AiClose - .2f, AiClose + .3f, r)));
                    float jag = 1f + .08f * Mathf.Sin(r * 13f + k) + .05f * Mathf.Sin(r * 29f + k * 2f);
                    var pose = P(new Vector2(tear.x, tear.y), tear.z + layer * 180f + 1.5f * Mathf.Sin(r * 7f + k), TearLen(tear) * (.3f + .7f * rip),
                        (layer == 0 ? .95f : .7f) * Iv(0f, .15f, rip), layer == 0 ? new Color(.02f, .025f, .05f) : new Color(.05f, .09f, .16f), -1.4f + .01f * k);
                    pose.sy = (layer == 0 ? .1f : .16f) * rip * jag; pose.curl = .5f * Mathf.Sin(r * .9f + k); return pose;
                });
            }
        }

        // The rift: dark mist torn open flat on the ground beside him.
        for (int k_ = 0; k_ < (AngelRiftPainted ? 2 : 0); k_++)
        {
            int k = k_;   // a fresh copy per pass: lambdas below capture it
            Paint(S(AiClose + .8f), k == 0 ? 8 : 10, t =>
            {
                float r = t / HitPace, open = Eout(Iv(AiRiftOpen, AiRiftOpen + .9f, r)) * (1f - Ein(Iv(AiClose - .3f, AiClose + .5f, r)));
                var pose = P(AngelRift, k * 180f + 3f * Mathf.Sin(r * 1.3f + k), (4.4f - 1.2f * k) * open, (k == 0 ? .85f : .6f) * Iv(0f, .2f, open), k == 0 ? new Color(.12f, .22f, .3f) : new Color(.35f, .75f, .9f), -2.4f - .1f * k);
                pose.sy = .26f; return pose;
            });
        }
        // The pursuer rises out of it beside the boss, sways while Sevian talks, recoils as the staff
        // lands, then fights inside the ball (a shape in the light) and is dragged down with it.
        Vector2 PursuerFeet(float r)
        {
            float rise = Eout(Iv(AiRise, AiRise + 2f, r)), drag = Ein(Iv(AiBallEnd, AiClose, r)), recoil = Back(Iv(AiPlant, AiPlant + .3f, r)) * (1f - Iv(AiPlant + .3f, AiBall, r));
            float sunk = AngelRiftPainted ? PursuerHeight * .55f : .3f;   // with no rift drawn he stands up out of the gloom
            var p = new Vector2(AngelRift.x + .3f + .4f * recoil, AngelRift.y - sunk * (1f - rise) - PursuerHeight * .7f * drag + .12f * Mathf.Sin(r * 1.1f));
            return p;
        }
        Paint(S(AiClose + .2f), 49, t =>
        {
            float r = t / HitPace;
            // Gone into the light as the ball forms (the fight clip takes over, FightStart).
            float a = Iv(AiRise, AiRise + (AngelRiftPainted ? .6f : 1.8f), r) * (1f - Iv(AiBall - .3f, AiBall + .3f, r));
            // Out of the dark: black at first, his cold greys coming up as he stands.
            var lit = Color.Lerp(new Color(.08f, .1f, .14f), new Color(.56f, .62f, .74f), AngelRiftPainted ? 1f : Iv(AiRise, AiRise + 2.6f, r));
            return P(Stand(PursuerFeet(r), PursuerHeight), 2f * Mathf.Sin(r * .9f) - 4f * Back(Iv(AiPlant, AiPlant + .3f, r)) * (1f - Iv(AiPlant + .3f, AiBall, r)),
                PursuerHeight * 1024f / 1000f, a, lit, -2f);
        });
        // The tether (stand-in until the painted chain arrives): cold mist pours from his hand to the
        // hero's chest in drifting puffs, holds tight, and tears apart when the staff lands.
        var hand = Stand(PursuerFeet(AiBind), PursuerHeight) + new Vector2(-.17f, .2f) * (PursuerHeight * 1024f / 1000f);
        var span = hero - hand; float len = span.magnitude;
        float ang = Mathf.Atan2(span.y, span.x) * Mathf.Rad2Deg;
        var rng = new System.Random(9302);
        int puffs = AngelChainPainted ? Mathf.Clamp(Mathf.RoundToInt(len / .7f), 4, 12) : 0;
        for (int i_ = 0; i_ < puffs; i_++)
        {
            int i = i_;   // a fresh copy per pass: lambdas below capture it
            float u = (i + .5f) / puffs, born = AiBind + .5f * u, sc = .9f + .4f * (float)rng.NextDouble(), ph = (float)rng.NextDouble() * 6f;
            var basePos = hand + span * u + new Vector2(0f, -.3f * Mathf.Sin(u * Mathf.PI));
            var tearV = new Vector2(((float)rng.NextDouble() - .5f) * 1.4f, .3f + .8f * (float)rng.NextDouble());
            Paint(S(AiPlant + 1.2f), i % 2 == 0 ? 9 : 11, t =>
            {
                float r = t / HitPace;
                if (r < born) return P(Vector2.zero, 0f, 0f, 0f, Color.white, 0f);
                float tear = Mathf.Max(0f, r - AiPlant);
                var off = basePos + new Vector2(.06f * Mathf.Sin(r * 3f + ph), .06f * Mathf.Cos(r * 2.6f + ph)) + tearV * tear;
                var pose = P(off, ang + 90f + 20f * Mathf.Sin(r * 1.4f + ph) + 120f * tear, sc * (.5f + .5f * Eout(Iv(born, born + .3f, r))) * (1f + .6f * tear),
                    .7f * Iv(born, born + .2f, r) * (1f - Ein(Iv(AiPlant, AiPlant + .9f, r))), new Color(.35f, .75f, 1f), .1f);
                pose.sy = .55f; pose.curl = .4f * Mathf.Sin(r * .8f + ph); return pose;
            });
        }
        // The ball of light round the two fighters (user 10-10: 2个人笼罩在一个光团里，看不清，只能看到
        // 隐约有剧烈的战斗): thick churning layers of painted mist, warm white and gold with a cold
        // swirl, drawn over both of them so only their shapes show through; the clash flashes
        // (AngelLight) burst on top. It swells, churns and shrinks down into the rift.
        for (int m_ = 0; m_ < 4; m_++)
        {
            int m = m_;   // a fresh copy per pass: lambdas below capture it
            var tint = m == 3 ? new Color(.55f, .8f, 1f) : m == 0 ? new Color(1f, .93f, .78f) : new Color(1f, .86f, .55f);
            float spin = (m % 2 == 0 ? 1f : -1f) * (30f + 12f * m), size0 = m == 3 ? 5.4f : 6.6f - .5f * m;
            Paint(S(AiClose + .3f), m == 1 ? 11 : 7, t =>
            {
                float r = t / HitPace;
                float grow = Smooth01(Iv(AiBall - .4f, AiBall + .5f, r)), shrink = Smooth01(Iv(AiBallEnd, AiClose, r));
                // Each blow shoves the mist out on the far side; big ones and the lock swell it.
                var c = Vector2.Lerp(AngelBall, AngelRift, shrink) + new Vector2(.2f * Mathf.Sin(r * 1.7f + m), .15f * Mathf.Cos(r * 2.1f + m))
                    + BallPush(r) * ((.5f + .25f * m) * (1f - shrink));
                float throb = (1f + .05f * Mathf.Sin(r * 9f + m * 1.3f)) * (1f + BallSwell(r) * (1f - shrink));
                var pose = P(c, m * 70f + spin * r, size0 * (.35f + .65f * grow) * (1f - .88f * shrink) * throb,
                    (m == 3 ? .45f : .7f) * grow * (1f - Iv(AiClose - .3f, AiClose, r)), tint * new Color(.9f, .86f, .8f), .55f + .02f * m);
                pose.curl = .8f * Mathf.Sin(r * .7f + m); return pose;
            });
        }
        // The fight itself: the clip as a darkened flipbook in the light (FightStart), the figures
        // most visible as each blow lights them from behind; they fade into the light at its ends.
        Paint(S(AiBallEnd + .3f), 100, t =>
        {
            float r = t / HitPace, c = r - FightStart;
            float show = Iv(FightStart, FightStart + .5f, r) * (1f - Iv(AiBallEnd - .5f, AiBallEnd, r));
            if (show <= .003f) return P(Vector2.zero, 0f, 0f, 0f, Color.white, 0f);
            // Darkened well below the light (angel21: at .42 her white robe vanished into it).
            var pose = P(FightCentre, 0f, FightFrameWidth, show * FightShow(r), new Color(.24f, .21f, .18f), 1.42f);
            pose.sy = .5f; pose.soft = true; pose.frameAdd = Mathf.Clamp(Mathf.Floor(c / FightClipSeconds * 64f), 0f, 63f);
            return pose;
        });
        // Debris thrown out of the light by the blows (FightBlows): feathers torn from her wings
        // when she is hit (the user's painted feather, cast cell 48), shreds of his black mist when he is.
        for (int k_ = 0; k_ < FightBlows.Length; k_++)
        {
            var blow = FightBlows[k_]; int kind = (int)blow.y; float when = FightStart + blow.x;
            var src = FightPoint(FightBlowAt[k_]); var drive = BlowDir(blow.y);
            bool herHit = kind != 0, hisHit = kind != 1;
            for (int j_ = 0; j_ < 7; j_++)
            {
                int j = j_, seed = k_ * 7 + j_;   // fresh copies per pass: lambdas below capture them
                bool feather = j < 3;
                if (feather ? !herHit : !hisHit) continue;
                if (blow.z < .75f && (feather ? j > 1 : j > 4)) continue;   // fewer from a lighter blow
                Paint(S(when + (feather ? 2.8f : 1.7f)), feather ? 48 : (j % 2 == 0 ? 9 : 11), t =>
                {
                    float r = t / HitPace, du = r - when;
                    if (du < 0f) return P(Vector2.zero, 0f, 0f, 0f, Color.white, 0f);
                    // Thrown the way the blow drives (a burst: every way), each its own way.
                    float fa = (drive.sqrMagnitude > 0f ? Mathf.Atan2(drive.y, drive.x) : Hash01(seed * 5) * 6.283f) + (Hash01(seed * 3 + 1) - .5f) * 2.4f;
                    float sp = (1.4f + 1.6f * Hash01(seed * 3 + 2)) * blow.z;
                    var dir = new Vector2(Mathf.Cos(fa), Mathf.Sin(fa));
                    if (feather)
                    {
                        // Flung out past the edge of the light (white on white reads as nothing,
                        // angel19), then drifting down over the dark, swaying and turning over.
                        var pos = src + dir * (sp * (1f - Mathf.Exp(-3f * du)) / 3f * 3.6f) + new Vector2(.25f * Mathf.Sin(du * 3f + seed), -.4f * du);
                        return P(pos, Hash01(seed) * 360f + 140f * du * (Hash01(seed + 5) > .5f ? 1f : -1f), .42f + .12f * Hash01(seed + 7),
                            Iv(0f, .05f, du) * (1f - Iv(1.6f, 2.7f, du)), Color.white, 1.5f);
                    }
                    var mp = src + dir * (sp * (1f - Mathf.Exp(-5f * du)) / 5f * 2.6f);
                    var pose = P(mp, Hash01(seed) * 360f + 260f * du, (.45f + .25f * Hash01(seed + 3)) * (1f + 1.2f * du), .75f * Iv(0f, .04f, du) * (1f - Iv(.1f, .65f, du)), new Color(.1f, .13f, .2f), 1.5f);
                    pose.curl = .5f; return pose;
                });
            }
        }
        // Elaia: down from the sky with her wings spread, then her sealing pose on the rift; inside
        // the ball only a faint, darting shape of her shows.
        Paint(S(AiLand + .1f), 50, t =>
        {
            float r = t / HitPace;
            return P(Stand(AngelFeet(r), AngelHeight * AngelDescendK), 1.5f * Mathf.Sin(r * 1.7f), AngelHeight * AngelDescendK * 1024f / 1000f * (1f + .015f * Mathf.Sin(r * 2.4f)),
                Iv(AiDescend, AiDescend + .5f, r) * (1f - Iv(AiLand - .2f, AiLand, r)), new Color(.86f, .84f, .8f), .4f);
        });
        Paint(S(AiClose + .2f), 51, t =>
        {
            float r = t / HitPace;
            float inBall = Iv(AiBall - .2f, AiBall + .4f, r) * (1f - Iv(AiBallEnd - .2f, AiBallEnd + .3f, r));
            float a = Iv(AiLand - .2f, AiLand, r) * (1f - Iv(AiBall, AiBall + .35f, r));
            var pose = P(Stand(AngelFeet(r), AngelHeight * AngelSealK), -8f * inBall * Mathf.Sin(r * 5.7f), AngelHeight * AngelSealK * 1024f / 1000f * (1f - .2f * inBall), a,
                Color.Lerp(new Color(.86f, .84f, .8f), new Color(.2f, .15f, .1f), inBall), inBall > .5f ? .63f : .4f);
            pose.sy = 1f - .05f * Iv(AiPlant - .2f, AiPlant - .12f, r) * (1f - Iv(AiPlant - .12f, AiPlant + .1f, r)); return pose;
        });
        // The farewell gifts (GiftPos): a flame of her lamp (painted fire, pale gold) for the hero,
        // a shard of his black salt (painted crystals, darkened) for Sevian; each melts in on landing.
        for (int g_ = 0; g_ < 2; g_++)
        {
            int g = g_;   // a fresh copy per pass: lambdas below capture it
            var target = g == 0 ? hero : boss;
            Paint(S(GiftArrive(g) + .5f), g == 0 ? 14 : 17, t =>
            {
                float r = t / HitPace;
                if (r < AiGift) return P(Vector2.zero, 0f, 0f, 0f, Color.white, 0f);
                float born = Eout(Iv(AiGift, AiGift + .3f, r)), land = Iv(GiftArrive(g), GiftArrive(g) + .35f, r);
                return g == 0
                    ? P(GiftPos(0, r, target), 6f * Mathf.Sin(r * 9f), .8f * born * (1f + .08f * Mathf.Sin(r * 17f)) * (1f - .6f * land), born * (1f - land), new Color(1f, .9f, .62f), 1.5f)
                    : P(GiftPos(1, r, target), 40f * r, .66f * born * (1f - .7f * land), born * (1f - land), new Color(.3f, .4f, .58f), 1.5f);
            });
        }
    }

    /// The backdrop held dark through the angel intro: in over a second, held, out at the end.
    sealed class AngelDim : MonoBehaviour
    {
        Mesh mesh; MeshRenderer view; MaterialPropertyBlock block; Vector3 centre; float age; int epoch;
        public static void Create(Transform parent, Material material, Vector3 centre)
        {
            if (!material) return;
            var go = new GameObject("SpectacleAngelDim"); go.transform.SetParent(parent, false);
            var d = go.AddComponent<AngelDim>(); d.centre = centre; d.epoch = angelIntroEpoch;
            d.mesh = new Mesh { name = "SpectacleAngelDimQuad" };
            d.mesh.vertices = new[] { new Vector3(0, 0, 0), new Vector3(0, 1, 0), new Vector3(1, 1, 0), new Vector3(1, 0, 0) };
            d.mesh.uv = new[] { new Vector2(0, 0), new Vector2(0, 1), new Vector2(1, 1), new Vector2(1, 0) };
            d.mesh.triangles = new[] { 0, 1, 2, 0, 2, 3 };
            d.mesh.bounds = new Bounds(Vector3.zero, Vector3.one * 100000f);
            go.AddComponent<MeshFilter>().sharedMesh = d.mesh;
            d.view = go.AddComponent<MeshRenderer>(); d.view.sharedMaterial = material;
            d.view.shadowCastingMode = UnityEngine.Rendering.ShadowCastingMode.Off; d.view.receiveShadows = false;
            d.block = new MaterialPropertyBlock();
        }
        void LateUpdate()
        {
            age += Time.deltaTime;
            if (age > AngelIntroSeconds || epoch != angelIntroEpoch) { Destroy(gameObject); return; }
            // Darker still once the tether binds the hero, until the ball of light is gone.
            // A gloom falls once the rift opens - nearly dark, a little light left round him - and
            // lifts after the rift closes (user 10-10: 一片昏暗).
            // Held until the farewell gifts have landed, so their light reads in the dark (angel14).
            float gloom = Iv(AiRiftOpen, AiRiftOpen + 1.2f, age) * (1f - Iv(AiClose + 1.4f, AiClose + 2.6f, age));
            float amount = Mathf.SmoothStep(0f, 1f, Iv(0f, 1.1f, age)) * (.55f + .33f * gloom)
                * (1f - Mathf.SmoothStep(0f, 1f, Iv(AngelIntroSeconds - 1.6f, AngelIntroSeconds - .2f, age)));
            block.SetVector("_Center", centre); block.SetFloat("_Amount", amount); block.SetFloat("_Radius", Mathf.Lerp(.45f, .3f, gloom));
            view.SetPropertyBlock(block);
        }
        void OnDestroy() { if (mesh) Destroy(mesh); }
    }

    Ink2D poisonPool;
    /// 翠毒漫天's floor of poison bubbles: shown from the first authoritative fog level and kept
    /// to the end of the fight; level 0 clears it.
    public static void PoisonPool(Component battle, Func<Vector3> feet, int level)
    {
        var director = Ensure(battle);
        if (!director) return;
        if (level <= 0 || !DrawsBreath || feet == null)
        {
            if (director.poisonPool) director.poisonPool.EndPool();
            director.poisonPool = null;
            return;
        }
        if (!director.Load() || !director.inkMaterial || !Camera.main) return;
        if (!director.poisonPool)
        {
            var cam = Camera.main; var at = SafeEval(feet);
            float half = Vector3.Distance(cam.transform.position, at) * Mathf.Tan(cam.fieldOfView * .5f * Mathf.Deg2Rad);
            var ink = Ink2D.CreatePool(director.root, director.inkMaterial, director, cam, at, .3f * half, 7311);
            ink.follow = feet;
            director.poisonPool = ink;
            // The bubbles: the user's painted ones (cut from emerald_burst), on the pool's clock.
            if (director.paintFlipMaterial)
                for (int i_ = 0; i_ < 24; i_++)
                {
                    int i = i_;   // a fresh copy per pass: lambdas below capture it
                    PaintSprite.Create(director.root, director.paintFlipMaterial, director, at, 0f, 1e6f, 42 + i % 3, t =>
                    {
                        if (!ink) return new Pose2 { scale = -1f };
                        ink.PoolBubble(i, out var p, out var r, out var a, out var pop);
                        return new Pose2 { off = p, scale = 2.5f * r * (1f + .35f * pop), alpha = a, tint = Color.white, z = .015f };
                    });
                }
        }
        director.poisonPool.SetPoolLevel(level);
    }

    /// The green of 翠焰亡灵's painted fog (hue of emerald_fog.png), for the smoke tinted to match it
    /// (2026-10-10, user: 这两种绿颜色要一致).
    static readonly Color PoisonGreen = new Color(.3f, 1f, .42f);

    void PoisonTick(Vector3 feet, int seed)
    {
        var cam = Camera.main;
        if (!cam) return;
        float s = .3f * Vector3.Distance(cam.transform.position, feet) * Mathf.Tan(cam.fieldOfView * .5f * Mathf.Deg2Rad);
        var rng = new System.Random(seed * 31 + 7);
        for (int k_ = 0; k_ < 3; k_++)
        {
            int k = k_;   // a fresh copy per pass: lambdas below capture it
            float x = ((float)rng.NextDouble() - .5f) * 1.6f * s, born = .06f * k, life = .9f + .3f * (float)rng.NextDouble(), spin = ((float)rng.NextDouble() - .5f) * 60f;
            PaintSprite.Create(root, paintFlipMaterial, this, feet, 0f, born + life, 7, t =>
            {
                float u = Iv(born, born + life, t);
                return new Pose2 { off = new Vector2(x, .1f * s + 1.1f * s * Eout(u)), roll = spin * u, scale = s * (.5f + .7f * Eout(u)), sy = 1.2f,
                    alpha = .4f * Iv(0f, .12f, u) * (1f - Ein(Iv(.4f, 1f, u))), tint = PoisonGreen, z = .01f + .003f * k };
            });
        }
    }

    /// Whether this layer draws the hound's and the revenant's breaths (their old bodies then stay out).
    public static bool DrawsBreath => InkStrokes && !Suppressed;

    /// A breath that leaves the mouth before it lands (2026-10-10, the user's painted 猎犬冥火喷吐
    /// hellfire_breath and 翠焰亡灵 翠毒漫天 emerald_fog / 返场毒爆 emerald_burst). The breath turns
    /// call this when their old body would have set off, with the seconds left to the contact; the
    /// stream reaches the target then and the contact's painted landing (PaintedSubject) takes over.
    public static void EnemyBreath(EnemyHandle actor, Func<Vector3> mouth, Func<Vector3> target, float lead)
    {
        var director = instance;
        if (!director || !DrawsBreath || !actor || mouth == null || target == null || !director.Load() || !director.paintFlipMaterial || !Camera.main) return;
        string key = "enemy:" + actor.BattleEnemyId;
        if (!director.pending.TryGetValue(key, out var cue) || cue == null || cue.Expired) return;
        string kind = InkKindFor(cue.profile.id, cue.intent);
        if (kind != "hellbreath" && kind != "emeraldfog" && kind != "emeraldburst") return;
        director.BreathStream(kind, SafeEval(mouth), SafeEval(target), Mathf.Max(.1f, lead), StableHash(key) + cue.cast * 7);
    }

    void BreathStream(string kind, Vector3 mouth, Vector3 target, float lead, int seed)
    {
        var cam = Camera.main; var ct = cam.transform;
        float half = Vector3.Distance(ct.position, target) * Mathf.Tan(cam.fieldOfView * .5f * Mathf.Deg2Rad);
        float s = .3f * half;
        // The mouth as seen on screen, carried to the target's depth, so the stream starts at it.
        var ms = cam.WorldToScreenPoint(mouth);
        float depth = cam.WorldToScreenPoint(target).z;
        if (ms.z <= 0f || depth <= 0f) return;
        var d3 = cam.ScreenToWorldPoint(new Vector3(ms.x, ms.y, depth)) - target;
        var m = new Vector2(Vector3.Dot(d3, ct.right), Vector3.Dot(d3, ct.up));
        float len = m.magnitude;
        if (len < .05f * s) return;
        var dir = -m / len;
        var across = new Vector2(-dir.y, dir.x);
        // The paintings flow to the right; a leftward breath is mirrored instead of turned over.
        bool flip = dir.x < 0f;
        float roll = flip ? Mathf.Atan2(-dir.y, -dir.x) * Mathf.Rad2Deg : Mathf.Atan2(dir.y, dir.x) * Mathf.Rad2Deg;
        float T = lead * HitPace;
        var rng = new System.Random(seed);
        float Rn(float a, float b) => a + (b - a) * (float)rng.NextDouble();
        Pose2 P(Vector2 off, float r, float scale, float alpha) => new Pose2 { off = off, roll = r, scale = scale, alpha = alpha, tint = Color.white, mirror = flip };
        if (kind == "hellbreath")
        {
            // 冥火喷吐: a flare at the mouth, then the painted hellfire pours out narrow end first
            // and lengthens until it reaches the target at the contact; flames lick up along it as
            // its head passes; after the hit its tail sweeps in after the head and it breaks into
            // rising fire.
            float L = len * 1.12f;
            Pose2 Stream(float t)
            {
                float g = Eout(Iv(0f, T, t)), tail = Ein(Iv(T + .04f, T + .3f, t));
                float a0 = L * .75f * tail, a1 = L * (.2f + .8f * g);
                var pose = P(m + dir * ((a0 + a1) * .5f), roll + Mathf.Sin(t * 31f) * 1.5f, Mathf.Max(.25f * s, a1 - a0) / .96f,
                    Iv(0f, .03f, t) * (1f - Ein(Iv(T + .14f, T + .3f, t))));
                pose.sy = .7f + .06f * Mathf.Sin(t * 43f); pose.z = .02f;
                return pose;
            }
            PaintSprite.Create(root, paintFlipMaterial, this, target, 0f, .3f, 14, t =>
            {
                var pose = P(m + dir * (.1f * s) + Vector2.up * (.05f * s), 0f, s * (.18f + .2f * Back(Iv(0f, .08f, t))), Iv(0f, .02f, t) * (1f - Iv(.14f, .3f, t)));
                pose.mirror = false; return pose;
            });
            PaintSprite.Create(root, paintFlipMaterial, this, target, 0f, T + .3f, 39, Stream);
            PaintPieces.Create(root, this, target, (T + .16f) / HitPace, 39, Stream(T + .16f), Scatter.Rise, 1.8f * s, .45f, seed + 51);
            for (int i_ = 0; i_ < 4; i_++)
            {
                int i = i_;   // a fresh copy per pass: lambdas below capture it
                float f = .3f + .18f * i, born = T * Mathf.Clamp01(f - .1f), life = Rn(.22f, .32f), sc = Rn(.28f, .4f);
                var c = m + dir * (L * f) + across * (Rn(-.2f, .2f) * s);
                PaintSprite.Create(root, paintFlipMaterial, this, target, 0f, born + life, 14, t =>
                {
                    float u = Iv(born, born + life, t);
                    var pose = P(c + Vector2.up * (.6f * s * Eout(u)), Mathf.Sin(t * 9f + i) * 8f, s * sc * (.6f + .5f * Mathf.Sin(u * Mathf.PI)), Mathf.Sin(u * Mathf.PI) * .9f);
                    pose.mirror = false; pose.z = .025f; return pose;
                });
            }
        }
        else if (kind == "emeraldfog")
        {
            // 翠毒漫天 (redo 2026-10-10, user of the single rolling cloud: 这团东西不好看): the
            // ghost fog pours from the mouth as six wisps of the painted fog, each on its own bowed
            // path with its narrow tail trailing; they reach the target's legs together at the
            // contact, wind round them and tear into swirling shreds.
            var legs = new Vector2(0f, -.55f * s);
            for (int k_ = 0; k_ < 6; k_++)
            {
                int k = k_;   // a fresh copy per pass: lambdas below capture it
                float born = T * .12f * k, arrive = T + Rn(-.04f, .06f), bow = Rn(-.45f, .45f) * s, sc = s * Rn(.75f, 1.05f);
                var goal = legs + new Vector2(Rn(-.9f, .9f) * s, Rn(-.15f, .25f) * s);
                float orbit = Rn(0f, 6.283f), spin = (k % 2 == 0 ? 1f : -1f) * Rn(4f, 6f);
                Vector2 Where(float t)
                {
                    float u = Iv(born, arrive, t);
                    var at0 = Vector2.Lerp(m, goal, Eout(u)) + across * (Mathf.Sin(u * Mathf.PI) * bow);
                    float w = Mathf.Max(0f, t - arrive);   // arrived: winding round the legs
                    if (w > 0f) at0 += new Vector2(Mathf.Cos(orbit + w * spin) - Mathf.Cos(orbit), (Mathf.Sin(orbit + w * spin) - Mathf.Sin(orbit)) * .3f) * (.45f * s);
                    return at0;
                }
                Pose2 Wisp(float t)
                {
                    var p0 = Where(t); var v = Where(t + .02f) - p0;
                    bool back_ = v.x < 0f;
                    float facing = v.sqrMagnitude > 1e-8f ? (back_ ? Mathf.Atan2(-v.y, -v.x) : Mathf.Atan2(v.y, v.x)) * Mathf.Rad2Deg : 0f;
                    var pose = P(p0, Mathf.Clamp(Mathf.DeltaAngle(0f, facing), -50f, 50f), sc * (.45f + .55f * Eout(Iv(born, arrive, t))),
                        .9f * Iv(born, born + .05f, t) * (1f - Ein(Iv(arrive + .1f, arrive + .24f, t))));
                    pose.mirror = back_; pose.sy = .7f; pose.curl = .25f + .7f * Iv(born, arrive + .2f, t); pose.z = .02f + .004f * k;
                    return pose;
                }
                PaintSprite.Create(root, paintFlipMaterial, this, target, 0f, arrive + .26f, 40, Wisp);
                PaintPieces.Create(root, this, target, (arrive + .16f) / HitPace, 40, Wisp(arrive + .16f), Scatter.Swirl, 1.2f * s, .5f, seed + 60 + k);
            }
        }
        else
        {
            // 返场毒爆: a clot of the painted toxic flame gathers at the mouth, spinning and
            // throbbing, then shoots at the target and arrives at the contact, where it bursts.
            for (int k_ = 0; k_ < 3; k_++)
            {
                int k = k_;   // a fresh copy per pass: lambdas below capture it
                float lag = .025f * k;
                PaintSprite.Create(root, paintFlipMaterial, this, target, 0f, T + .05f, 41, t =>
                {
                    float hold = T * .45f, g = Ein(Iv(hold, T, t - lag));
                    var pose = P(Vector2.Lerp(m, Vector2.zero, g), t * 520f + 40f * k, s * (.3f + .25f * Iv(0f, hold, t)) * (1f + .12f * Mathf.Sin(t * 34f)) * (1f - .25f * k),
                        (1f - .35f * k) * Iv(0f, .05f, t) * (1f - Iv(T, T + .05f, t)));
                    pose.mirror = false; pose.z = .02f + .005f * k; return pose;
                });
            }
        }
    }

    /// The outer, deeper colour of an enemy's outline glow: the third step of its ramp.
    static Color OutlineDeep(Profile p) => p.ramp != null && p.ramp.Length > 2 ? p.ramp[2] : p.line;

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
        if (string.IsNullOrEmpty(actor)) return;
        EnemyWholeBody20261009.Contact(actor);
        EnemyOutline20261009.Contact(actor);
        if (!instance) return;
        if (instance.gathers.TryGetValue(actor, out var g)) { if (g) g.Release(); instance.gathers.Remove(actor); }
        if (Suppressed || !instance.pending.TryGetValue(actor, out var cue) || cue.Expired) return;
        // Same-frame duplicate callbacks are one contact; a legal second hit
        // of a multi-projectile attack still gets its own burst.
        if (Time.unscaledTime - cue.lastContact < .085f) return;
        cue.lastContact = Time.unscaledTime;
        if (Diagnostics) Debug.Log($"SPELLFORM contact {actor} {cue.profile.id} t={Time.unscaledTime:F3} launched={cue.launch.Count}");
        // A hero card's cue serves its own hits only: a multi-hit card lands within a
        // fraction of a second, while a later basic attack (tempo samples register no
        // cue for it) must not replay the card's landing.
        if (cue.player) { cue.expiresAt = Mathf.Min(cue.expiresAt, Time.unscaledTime + .45f); cue.expiresGame = Mathf.Min(cue.expiresGame, Time.time + .45f); }
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
        instance.hasteUntil = -1f;
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
        if (propMaterial) Destroy(propMaterial);
        if (paintMaterial) Destroy(paintMaterial);
        if (dimMaterial) Destroy(dimMaterial);
        foreach (var m in flipbooks.Values) if (m) Destroy(m);
        if (cardMaterial) Destroy(cardMaterial);
        if (sweepUnderMaterial) Destroy(sweepUnderMaterial);
        if (flareUnderMaterial) Destroy(flareUnderMaterial);
    }

    // ------------------------------------------------------------ setup

    Cue Register(string key, Profile profile, Style style, Func<Vector3> caster, IList<Func<Vector3>> targets, IList<int> seeds)
    {
        castCount.TryGetValue(key + profile.id, out int n);
        castCount[key + profile.id] = n + 1;
        var cue = new Cue { profile = profile, style = style, caster = caster, expiresAt = Time.unscaledTime + 6f, expiresGame = Time.time + 6f, cast = n };
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
        var prop = Resources.Load<Shader>("SpellSpectacle20260926/SpectacleProp");
        var dimShader = Resources.Load<Shader>("SpellSpectacle20260926/SpectacleDim");
        var inkShader = Resources.Load<Shader>("SpellSpectacle20260926/SpectacleInk20261008");
        if (inkShader) inkMaterial = new Material(inkShader) { name = "SpectacleInk" };
        // The hero's flying cards use the authored tarot flipbook (2026-10-09, user: 这几个卡牌
        // 需要用现有的2D图片的卡牌 / 就这些效果): FoolTarotVFXAtlas, converted to light alpha.
        var flipShader = Resources.Load<Shader>("SpellSpectacle20260926/SpectacleFlipbook");
        var tarotSheet = Resources.Load<Texture2D>("SpellSpectacle20260926/TarotFlight");
        if (flipShader && tarotSheet) { tarotMaterial = new Material(flipShader) { name = "SpectacleTarotFlight" }; tarotMaterial.SetTexture("_MainTex", tarotSheet); }
        propAtlas = Resources.Load<Texture2D>("SpellSpectacle20260926/SpectacleProps");
        paintAtlas = Resources.Load<Texture2D>("SpellSpectacle20260926/SpectaclePaint");
        if (flipShader && paintAtlas)
        {
            paintFlipMaterial = new Material(flipShader) { name = "SpectaclePaintSprite" };
            paintFlipMaterial.SetTexture("_MainTex", paintAtlas); paintFlipMaterial.SetFloat("_Bright", 1.08f); paintFlipMaterial.SetTexture("_Noise", noise);
            var paint2 = Resources.Load<Texture2D>("SpellSpectacle20260926/SpectaclePaint2");
            if (paint2) { paintAtlas2 = paint2; paintFlipMaterial2 = new Material(flipShader) { name = "SpectaclePaintSprite2" }; paintFlipMaterial2.SetTexture("_MainTex", paint2); paintFlipMaterial2.SetFloat("_Bright", .9f); paintFlipMaterial2.SetTexture("_Noise", noise); }
            var paint3 = Resources.Load<Texture2D>("SpellSpectacle20260926/SpectaclePaint3");
            if (paint3) { paintAtlas3 = paint3; paintFlipMaterial3 = new Material(flipShader) { name = "SpectaclePaintSprite3" }; paintFlipMaterial3.SetTexture("_MainTex", paint3); paintFlipMaterial3.SetFloat("_Bright", .9f); paintFlipMaterial3.SetTexture("_Noise", noise); }
            // The final-boss cast (2026-10-10, Q30 angel intro): a 2x2 sheet of full figures, cells 48+.
            var cast = Resources.Load<Texture2D>("SpellSpectacle20260926/SpectacleCast");
            if (cast) { paintFlipMaterial4 = new Material(flipShader) { name = "SpectacleCastSprite" }; paintFlipMaterial4.SetTexture("_MainTex", cast); paintFlipMaterial4.SetFloat("_Bright", 1f); paintFlipMaterial4.SetFloat("_Cols", 2f); paintFlipMaterial4.SetFloat("_Rows", 2f); paintFlipMaterial4.SetTexture("_Noise", noise); }
            // The angel intro's fight clip (2026-10-11): 64 frames, 8x8 (cells 100+).
            var fight = Resources.Load<Texture2D>("SpellSpectacle20260926/SpectacleFight");
            if (fight) { paintFlipMaterial5 = new Material(flipShader) { name = "SpectacleFightSprite" }; paintFlipMaterial5.SetTexture("_MainTex", fight); paintFlipMaterial5.SetFloat("_Bright", 1f); paintFlipMaterial5.SetFloat("_Cols", 8f); paintFlipMaterial5.SetFloat("_Rows", 8f); paintFlipMaterial5.SetTexture("_Noise", noise); }
            // The ordered loop's three cards (2026-10-14): hourglass, gold sand, mirror shards, letter bomb (cells 200+).
            var paint4 = Resources.Load<Texture2D>("SpellSpectacle20260926/SpectaclePaint4");
            if (paint4) { paintAtlas4 = paint4; paintFlipMaterial6 = new Material(flipShader) { name = "SpectaclePaintSprite4" }; paintFlipMaterial6.SetTexture("_MainTex", paint4); paintFlipMaterial6.SetFloat("_Bright", .9f); paintFlipMaterial6.SetTexture("_Noise", noise); }
            var piecesShader = Resources.Load<Shader>("SpellSpectacle20260926/SpectaclePieces20261009");
            if (piecesShader) { piecesMaterial = new Material(piecesShader) { name = "SpectaclePaintPieces" }; piecesMaterial.SetTexture("_Noise", noise); }
        }
        if (!sweep || !washShader || !flare || !matterAtlas || !noise || !atlas || !prop || !propAtlas || !paintAtlas || !dimShader)
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
        propMaterial = new Material(prop) { name = "SpectacleProp" };
        dimMaterial = new Material(dimShader) { name = "SpectacleDim" };
        propMaterial.SetTexture("_MainTex", propAtlas);
        paintMaterial = new Material(prop) { name = "SpectaclePaint" };
        paintMaterial.SetTexture("_MainTex", paintAtlas);
        paintMaterial.SetTexture("_Noise", noise); paintMaterial.SetFloat("_CellSize", .25f);
        propMaterial.SetTexture("_Noise", noise); propMaterial.SetFloat("_CellSize", .125f);
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
        if (cue.player && IsOrderedCard(p.id)) { CardImpact(cue, cam, caster, points); return; }
        // The backdrop darkens a little at the hit (2026-10-07, user: 可以在命中的瞬间把背景压暗一点):
        // hero cards and an enemy's real blows, not the basic beat or support.
        float darken = cue.player
            ? (p.form == Form.Flick ? .22f : p.id == "climax" || p.id == "declaration" ? .4f : .26f)
            : style == Style.Heavy ? .3f : style == Style.Strike ? .2f : .18f;
        if (darken > 0f)
        {
            if (!dim) dim = Dim.Create(root, dimMaterial, this);
            dim.Trigger(mean, ReducedMotion ? darken * .5f : darken);
        }
        if (p.form != Form.Bloom && cue.player)
        {
            FormImpact(cue, cam, caster, points);
            return;
        }
        // Enemy casts keep their full size: shrunk to .62 they collapsed into lumps round the hero
        // (2026-10-03, user on the phone, boxing four enemy hits that had shrunk into lumps: 我不要这样的一团的东西，另外，改前的绚丽是值得要的，但要有差异，比如旋风忽大忽小？，飞剑形状？凤凰冲击碎裂开？).
        float castScale = 1f;
        if (group)
        {
            float spread = 0;
            foreach (var v in points) spread = Mathf.Max(spread, Vector3.Distance(v, mean));
            var rng = new System.Random(StableHash(p.id) + cue.cast * 7);
            float half = Vector3.Distance(cam.transform.position, mean) * Mathf.Tan(cam.fieldOfView * .5f * Mathf.Deg2Rad);
            float s = half / 4.5f * p.scale * TierScale(style) * 1.12f * castScale;
            SpawnBodies(cue, style, caster, mean, s, rng, 0f, cam);
        }
        for (int i = 0; i < points.Count; i++)
        {
            var rng = new System.Random(cue.seeds[i] * 31 + cue.cast * 7 + p.id.Length);
            float half = Vector3.Distance(cam.transform.position, points[i]) * Mathf.Tan(cam.fieldOfView * .5f * Mathf.Deg2Rad);
            float s = half / 4.5f * p.scale * TierScale(style) * (group ? .78f : 1f) * castScale;
            float delay = i * .035f;
            // A hand-drawn, frame-by-frame impact carries the whole hit by itself.
            if (!group && !cue.player && (EnemyInkHit(cue, style, caster, points[i], delay, cam) || ClawHit(cue, style, caster, points[i], delay, cam) || EffekseerHit(cue, style, caster, points[i], s, delay, cam) || HandDrawnHit(cue, style, caster, points[i], s, rng, delay, cam))) continue;
            if (!group) SpawnBodies(cue, style, caster, points[i], s, rng, delay, cam);
            var flares = Flares.Create(root, flareMaterial, this);
            flares.Build(p, style, new Frame(cam, caster, points[i], s, rng), rng, delay, group, false, NamedMove(p.accent));
        }
        float amount = style switch
        {
            Style.Heavy => .52f, Style.Strike => .38f, Style.Light => .28f, Style.Control => .22f, _ => .2f
        };
        if (group) amount *= .7f;
        if (ReducedMotion) amount *= .35f;
        // A hit on the hero tints the screen a little more softly than before.
        if (!cue.player) amount *= .85f;
        // Only the ultimate may tint the whole screen; hero cards stay on their target.
        if (cue.player && p.id != "declaration") return;
        if (!wash) wash = Wash.Create(root, washMaterial, this);
        wash.Trigger(mean, p.wash, p.hot, amount, style == Style.Support ? .2f : style == Style.Light ? .18f : style == Style.Heavy ? .34f : .26f, style == Style.Support ? .6f : .46f);
    }

    // ------------------------------------------------------------ hand-drawn impacts

    /// Identities whose hit is a hand-drawn, frame-by-frame animation instead of built
    /// bodies (2026-10-08, user on 2D hand-drawn cartoon VFX: 我要的就是这种感觉). The sheets
    /// are generated by tools/vfx-handdrawn-20261008: every frame is redrawn, hard-edged
    /// colour bands, dark thorny strokes against glowing fire, drops taking over at the end.
    // The generated HoundPounce sheet was rejected (2026-10-08, user: 太粗糙了，完全不像法术，是平面图);
    // the player stays for real frame sequences, no identity uses it for now.
    static string HandDrawnSheet(Profile p) => null;

    /// Seconds each drawing is held: a quick dark gather, the burst held on threes, the
    /// rest on twos (12-15 drawings a second, the rhythm of hand-drawn effects).
    static readonly float[] HoundPounceHold =
        { 1 / 30f, 1 / 30f, 2 / 30f, 3 / 30f, 2 / 30f, 2 / 30f, 2 / 30f, 2 / 30f, 2 / 30f, 2 / 30f, 2 / 30f, 2 / 30f, 2 / 30f, 2 / 30f };

    Material Flipbook(string sheet)
    {
        if (flipbooks.TryGetValue(sheet, out var m)) return m;
        var shader = Resources.Load<Shader>("SpellSpectacle20260926/SpectacleFlipbook");
        var tex = Resources.Load<Texture2D>("SpellSpectacle20260926/HandDrawn/" + sheet);
        if (!shader || !tex)
        {
            Debug.LogWarning("SPELL_SPECTACLE_MISSING_FLIPBOOK " + sheet);
            flipbooks[sheet] = null;
            return null;
        }
        m = new Material(shader) { name = "Flipbook-" + sheet };
        m.SetTexture("_MainTex", tex);
        flipbooks[sheet] = m;
        return m;
    }

    bool HandDrawnHit(Cue cue, Style style, Vector3 caster, Vector3 target, float s, System.Random rng, float delay, Camera cam)
    {
        var sheet = HandDrawnSheet(cue.profile);
        if (sheet == null) return false;
        var mat = Flipbook(sheet);
        if (!mat) return false;
        var f = new Frame(cam, caster, target, s, rng);
        // The drawing rakes from upper left to lower right: mirrored when the attacker stands
        // to the right of the one it hits, so the claws always come from the attacker's side.
        bool mirror = f.side < 0f;
        float size = s * 3.1f * (style == Style.Heavy ? 1.15f : style == Style.Light ? .92f : 1f);
        if (ReducedMotion) size *= .85f;
        float roll = R(rng, -9f, 9f);
        if (Diagnostics) Debug.Log($"SPELLFORM handdrawn {cue.profile.id} sheet={sheet} at={target:F2} size={size:F2} mirror={mirror}");
        FlipbookPlayer.Create(root, mat, this, target + f.toCam * .2f * s, size, roll, mirror, delay, HoundPounceHold);
        return true;
    }

    /// Identities whose hit is a real-time Effekseer effect from the official CC0 sample
    /// packs (2026-10-08: the user looked at eight of them on the hero and said 这些都不错).
    /// Each layer: resource name, start delay (s), when it starts fading, when it is gone,
    /// and its size as a share of the visible half-height at the hit.
    static (string fx, float at, float fadeFrom, float end, float size)[] EffekseerLayers(Profile p) => p.id switch
    {
        // 猎犬扑咬: the red claw rake (tktk02 Claw1) tears across, then a burst of fire
        // (tktk02 Fire5) blooms on the chest. Claw1's red wash is cut short.
        // 170.19 on the simulator: at .085/.075 of the half-height a pink-white bloom covered both
        // the hero and the hound and the hero stayed red too long; smaller, red cut sooner.
        // (猎犬扑咬 is the painted claw alone, ClawHit; 错步穿行 is the card hit, CardHit.)
        _ => null,
    };

    readonly Dictionary<string, Effekseer.EffekseerEffectAsset> effekseerAssets = new Dictionary<string, Effekseer.EffekseerEffectAsset>();

    bool EffekseerHit(Cue cue, Style style, Vector3 caster, Vector3 target, float s, float delay, Camera cam)
    {
        var layers = EffekseerLayers(cue.profile);
        if (layers == null) return false;
        var assets = new Effekseer.EffekseerEffectAsset[layers.Length];
        for (int i = 0; i < layers.Length; i++)
        {
            if (!effekseerAssets.TryGetValue(layers[i].fx, out var a))
            {
                a = Resources.Load<Effekseer.EffekseerEffectAsset>("SpellSpectacle20260926/Effekseer/" + layers[i].fx);
                if (!a) Debug.LogWarning("SPELL_SPECTACLE_MISSING_EFFEKSEER " + layers[i].fx);
                effekseerAssets[layers[i].fx] = a;
            }
            if (!a) return false;
            assets[i] = a;
        }
        float half = Vector3.Distance(cam.transform.position, target) * Mathf.Tan(cam.fieldOfView * .5f * Mathf.Deg2Rad);
        float tier = style == Style.Heavy ? 1.15f : style == Style.Light ? .9f : 1f;
        var at = target - cam.transform.forward * .25f * s;
        if (Diagnostics) Debug.Log($"SPELLFORM effekseer {cue.profile.id} at={at:F2} half={half:F2}");
        EffekseerBurst.Create(root, this, at, half * tier, delay, layers, assets);
        return true;
    }

    /// 猎犬扑咬 is the user's painted claw alone (2026-10-08, user: 抓痕可以了 … 去掉火团).
    bool ClawHit(Cue cue, Style style, Vector3 caster, Vector3 target, float delay, Camera cam)
    {
        if (cue.profile.id != "early-hound" || (cue.intent ?? "strike") != "bite") return false;
        float half = Vector3.Distance(cam.transform.position, target) * Mathf.Tan(cam.fieldOfView * .5f * Mathf.Deg2Rad);
        float tier = style == Style.Heavy ? 1.15f : style == Style.Light ? .9f : 1f;
        // The user's painted claw is the subject (the drawn crescents read as rough, 2026-10-08:
        // 这3片粗糙了); Ink2D adds only the light round it: glow, hit spark, shock ring, dashes.
        PaintedClaw(cam, caster, target, half * tier, delay);
        if (InkStrokes && inkMaterial) Ink2D.Create(root, inkMaterial, this, cam, caster, target, .33f * half * tier, delay, cue.seeds.Count > 0 ? cue.seeds[0] * 31 + cue.cast * 7 : cue.cast, "clawfx");
        return true;
    }

    /// 猎犬扑咬: the user's painted claw marks (three glowing tears with sparks) rake open
    /// across the hero's chest in fire colours, glow, and are gone within half a second. They
    /// rake from the hound's side of the screen.
    /// Hard colour bands on the painted claw (2XKO reference, 2026-10-08); 0 restores the smooth look.
    const float RimBands = 0f;
    /// Hand-drawn strokes (Ink2D) replace the painted claw and the basic card's landing (2026-10-08).
    const bool InkStrokes = true;
    /// Whether enemy hits are drawn by this layer's ink and painted props (their old
    /// presentations then leave out their own travelling / impact effects).
    public static bool EnemyInkActive => InkStrokes;
    /// The painterly ink material, for other presentation layers' strokes (weapon trails).
    public static Material SharedInk => instance ? instance.inkMaterial : null;
    /// The bounties whose attacks this layer draws with painted props.
    public static bool DrawsBounty(string species) => InkStrokes && species is "b01" or "b02" or "b03" or "b04" or "b05" or "b06"
        or "b07" or "b08" or "b08-echo" or "b09" or "b10" or "b10-vessel";

    /// Enemy hits in the Ink2D look (2026-10-09, user: 不错的，继续 - after the hero's cards),
    /// a few identities at a time, each shown before the next batch.
    /// The Ink2D kind (and painted subject) of an enemy identity's attack; null when it has none.
    static string InkKindFor(string profileId, string intent)
    {
        string kind = profileId switch
        {
            "guard" => "clock", "fog-ghost" => "ghost", "crimson-ghost" => "ghostred", "hound" => "bite", "scribe" => "ink",
            "archivist" => "bolt", "leech" => "drain", "mind" => "pin", "heal" => "mend",
            "matriarch" => "silk", "executor" => "sign", "chronarch" => "sovereign", "adjudicator" => "verdict",
            "convoy" => "chain", "rescue" => "meteor", "elite" => "toll", "emerald" => "emerald",
            "stonehide" => "geyser", "saltmaw" => "salt", "salt-poison" => "spit", "ironclaw" => "steel", "frilled-naga" => "sonic",
            "boneclaw" => "bonerake", "copperback" => "ram", "crimson-brute" => "fist", "veil-oracle" => "veil", "golden-throat" => "bubbles", "moonfang" => "moonwind",
            "shellback" => "pounce", "heal-tower" => "lotusmend", "heal-crimson" => "crimsonmend",
            _ => null,
        };
        // Bounties (2026-10-09, painted props): the move picks the art where a boss has two.
        if (kind == null && profileId != null && profileId.StartsWith("bounty-b"))
        {
            string it = intent ?? "";
            kind = profileId switch
            {
                "bounty-b01" => "b01slash",
                "bounty-b02" => "b02straps",
                "bounty-b03" => it.Contains("heavy") ? "b03bell" : "b03wave",
                "bounty-b04" => "b04quill",
                "bounty-b05" => it.Contains("silk_bind") ? "b05threads" : "b05needles",
                "bounty-b06" => "b06anchor",
                "bounty-b07" => it.Contains("spittle") ? "b07spit" : "b07knock",
                "bounty-b08" => it.Contains("true_stab") ? "b08stab" : "b08echo",
                "bounty-b09" => "b09rend",
                "bounty-b10" => "b10veil",
                _ => null,
            };
        }
        // 猎犬冥火喷吐 (2026-10-10, the user's painted hellfire breath): every hound turn but the
        // bite is its breath (the rules carry only bite and charge intents for hounds).
        string move = intent ?? "strike";
        if ((profileId == "early-hound" || profileId == "hound") && move != "bite" && !move.Contains("pounce")) kind = "hellbreath";
        // 瑟维安 in the party fight (2026-10-10): 镇钟重砸 hits the whole party, 夺名代签 seals one member.
        if (profileId == "chronarch" && move == "slam") kind = "bronzeslam";
        if (profileId == "chronarch" && move == "name_seal") kind = "nameseal";
        // 翠焰亡灵: 翠毒漫天 rolls its ghost fog in, 返场毒爆 bursts (BeginEnemy reads which).
        if (profileId == "emerald") kind = move == "emerald_burst" ? "emeraldburst" : "emeraldfog";
        return kind;
    }

    static bool SupportKind(string kind) => kind is "mend" or "lotusmend" or "crimsonmend";

    /// Where an enemy's attack starts on its visible body: a weapon bone, else its right hand,
    /// else its effect anchor (chest).
    static Func<Vector3> HandOf(EnemyHandle actor)
    {
        // 瑟维安's illustrated body: the gauntlet in the video frame, not the hidden rig's hand (2026-10-11).
        var video = actor.GetComponentInChildren<SevianVideoBody20261009>();
        if (video && video.HandPoint(out _)) return () => video && video.HandPoint(out var p) ? p : Vector3.zero;
        Transform best = null; int rank = 9;
        var root = actor.VisualRoot ? actor.VisualRoot : actor.EnemyRoot;
        if (root)
            foreach (var t in root.GetComponentsInChildren<Transform>(false))
            {
                var n = t.name.ToLowerInvariant();
                int r = n.Contains("weapon") || n.Contains("sword") || n.Contains("axe") || n.Contains("hammer") ? 0
                    : n == "pen.r" || n.Contains("righthand") || n == "hand.r" || n == "hand_r" || n == "r_hand" || n == "handr" ? 1 : 9;
                if (r < rank) { rank = r; best = t; }
            }
        var anchor = actor.EffectAnchor ? actor.EffectAnchor : actor.EnemyRoot;
        if (!best) return () => anchor ? anchor.position : Vector3.zero;
        var bone = best;
        return () => bone ? bone.position : anchor ? anchor.position : Vector3.zero;
    }

    readonly Dictionary<string, Ink2D> gathers = new Dictionary<string, Ink2D>();


    bool EnemyInkHit(Cue cue, Style style, Vector3 caster, Vector3 target, float delay, Camera cam)
    {
        if (!InkStrokes || !inkMaterial) return false;
        string kind = InkKindFor(cue.profile.id, cue.intent);
        if (kind == null) return false;
        float half = Vector3.Distance(cam.transform.position, target) * Mathf.Tan(cam.fieldOfView * .5f * Mathf.Deg2Rad);
        float tier = style == Style.Heavy ? 1.15f : style == Style.Light ? .9f : 1f;
        if (kind == "sovereign") tier *= 1.2f;   // the chapter boss hits bigger than anyone
        int seed = cue.seeds.Count > 0 ? cue.seeds[0] * 31 + cue.cast * 7 : cue.cast;
        var ink = Ink2D.Create(root, inkMaterial, this, cam, caster, target, .3f * half * tier, delay, seed, kind);
        ink.enemyHit = !SupportKind(kind) && style != Style.Support;
        PaintedSubject(kind, cam, caster, target, .3f * half * tier, delay, seed);
        return true;
    }

    /// The hero's cards in the Ink2D look (2026-10-09, user: 先把主角的做完, one card at a time,
    /// each shown before the next). Returns true when the ink hit replaces the old landing;
    /// 错步穿行 keeps the card shatter the user asked for and only gets the ink cuts over it.
    bool InkHit(Cue cue, Vector3 caster, Vector3 target, float half, float delay, Camera cam, int index)
    {
        if (!InkStrokes || !inkMaterial) return false;
        string kind; float k; bool replaces = true;
        switch (cue.profile.id)
        {
            case "paper": kind = "burst"; k = .24f; break;
            case "sidestep": kind = "cut"; k = .2f; replaces = false; break;
            case "seal": kind = "seal"; k = .28f; break;
            case "identity": kind = "swap"; k = .26f; break;
            case "chase": kind = "shadow"; k = .28f; break;
            case "reversal": kind = "reverse"; k = .23f; break;
            case "declaration": kind = "edict"; k = .3f; break;
            // 荒谬归结 is the named finisher: half the screen on its main target (approved
            // 2026-10-07), a small echo on the others.
            case "climax": kind = "finale"; k = index == 0 ? .42f : .16f; break;
            case "mask": kind = "mask"; k = .24f; break;
            // 后手改写 lands on the hero himself (its target list is the caster).
            case "ward": kind = "rewrite"; k = .3f; break;
            default: return false;
        }
        if (index > 0 && kind != "burst" && kind != "finale") k *= .75f;
        Ink2D.Create(root, inkMaterial, this, cam, caster, target, half * k, delay, cue.seeds[index] * 31 + cue.cast * 7 + 5, kind);
        return replaces;
    }
    void PaintedClaw(Camera cam, Vector3 caster, Vector3 target, float half, float delay)
    {
        var props = Props.Create(root, propMaterial, this);
        float side = Vector3.Dot(target - caster, cam.transform.right);
        var it = Props.New(PropCell.PClaw, PropCell.PClaw, target - cam.transform.forward * .06f * half + Vector3.up * .04f * half, .5f * half, delay, .62f);
        it.faceCam = true; it.rollStart = side >= 0f ? 0f : 90f;
        // Glow .4: with the spell bloom at 1 the painted marks washed out white (ink16).
        // Deeper orange-red and less glow: at (1,.58,.22)/.4 the marks read yellow on the marble
        // and the bloom laid a warm cast over the screen (ink17).
        it.tint = new Color(1f, .4f, .12f); it.glow = .25f; it.glowDecay = .12f; it.rim = RimBands;
        it.grow = .3f; it.growTime = .055f; it.endScale = 1.1f; it.peak = .02f; it.fadeFrom = .5f;
        props.Add(it);
    }

    Material cardMaterial;

    /// 错步穿行: the tarot card itself strikes (2026-10-08, user of the blue starbursts that
    /// replaced paper shards: 纸片重新设计，强调卡牌击中，从卡牌形状开始炸裂，消散 … 可以调成紫粉).
    bool CardHit(Cue cue, Vector3 caster, Vector3 target, float half, float delay, Camera cam, int index)
    {
        if (cue.profile.id != "sidestep") return false;
        if (!cardMaterial)
        {
            var shader = Resources.Load<Shader>("SpellSpectacle20260926/SpectacleCardShard");
            var face = Resources.Load<Texture2D>("Effects/Fool/HeavyTarotFace");
            if (!shader || !face) { Debug.LogWarning("SPELL_SPECTACLE_MISSING_CARD"); return false; }
            cardMaterial = new Material(shader) { name = "SpectacleCardShard" };
            cardMaterial.SetTexture("_MainTex", face);
            cardMaterial.SetTexture("_Noise", noise);
        }
        float height = half * (index == 0 ? .34f : .26f);
        var at = target - cam.transform.forward * .12f * height;
        if (Diagnostics) Debug.Log($"SPELLFORM card {cue.profile.id} at={at:F2} height={height:F2}");
        CardShatter.Create(root, cardMaterial, this, cam, caster, at, height, delay, StableHash(cue.profile.id) + cue.cast * 31 + index);
        return true;
    }

    /// Playback speed of every hit once it has landed (user 2026-10-09: 所有法术都要统一放慢到
    /// 0.7 倍): the ink strokes, the card shatter, the hand-drawn flipbooks and the Effekseer
    /// bursts all play at this rate, so each hit lasts about 1.4x longer. The flight before
    /// the impact keeps game time, so hits still land on the game's beat.
    const float HitPace = .7f;

    sealed class CardShatter : MonoBehaviour
    {
        const float Aspect = 972f / 1619f;            // HeavyTarotFace
        const float Slam = .07f, CrackFrom = .1f, BurstAt = .15f, End = .78f;
        sealed class Shard { public List<Vector2> poly = new List<Vector2>(); public List<bool> seam = new List<bool>(); public Vector2 c, dir; public float speed, spin, tilt, tiltAxis, dissolveAt, shrink; }
        sealed class Spark { public Vector2 p, v; public float born, life, size; public Color col; }
        static readonly Color[] SparkColors = { new Color(1f, .45f, .88f), new Color(.78f, .45f, 1f), new Color(1f, .82f, .95f), new Color(1f, .78f, .5f) };
        SpellSpectacle20260926 owner;
        Mesh mesh;
        readonly List<Shard> shards = new List<Shard>();
        readonly List<Spark> sparks = new List<Spark>();
        readonly List<Vector3> vs = new List<Vector3>(); readonly List<Color> cs = new List<Color>();
        readonly List<Vector2> u0 = new List<Vector2>(), u1 = new List<Vector2>(), u2 = new List<Vector2>();
        readonly List<int> tris = new List<int>();
        Vector3 at; Vector2 from; float h, w, delay, age, roll; System.Random rng; bool burst;

        float Rn(float a, float b) => a + (b - a) * (float)rng.NextDouble();

        public static void Create(Transform parent, Material material, SpellSpectacle20260926 owner, Camera cam, Vector3 caster, Vector3 at, float height, float delay, int seed)
        {
            var go = new GameObject("SpectacleCardShatter");
            go.transform.SetParent(parent, false);
            var c = go.AddComponent<CardShatter>();
            c.owner = owner; c.at = at; c.h = height; c.w = height * Aspect; c.delay = delay;
            c.rng = new System.Random(seed);
            var d = at - caster;
            var d2 = new Vector2(Vector3.Dot(d, cam.transform.right), Vector3.Dot(d, cam.transform.up));
            c.from = d2.sqrMagnitude > 1e-6f ? -d2.normalized : Vector2.down;
            c.roll = c.Rn(-9f, 9f);
            c.mesh = new Mesh { name = "CardShatter" }; c.mesh.MarkDynamic();
            go.AddComponent<MeshFilter>().sharedMesh = c.mesh;
            var r = go.AddComponent<MeshRenderer>(); r.sharedMaterial = material;
            r.shadowCastingMode = UnityEngine.Rendering.ShadowCastingMode.Off; r.receiveShadows = false;
            c.Cut();
            owner.live++;
        }

        /// Voronoi cells of jittered seeds, smaller ones round the strike point; each cell is
        /// the card rect clipped by the bisectors to every other seed.
        void Cut()
        {
            var seeds = new List<Vector2>();
            for (int y = 0; y < 5; y++)
                for (int x = 0; x < 3; x++)
                    seeds.Add(new Vector2(((x + Rn(.2f, .8f)) / 3f - .5f) * w, ((y + Rn(.2f, .8f)) / 5f - .5f) * h));
            for (int k = 0; k < 4; k++) seeds.Add(new Vector2(Rn(-.18f, .18f) * w, Rn(-.12f, .12f) * h));
            for (int i = 0; i < seeds.Count; i++)
            {
                var poly = new List<Vector2> { new Vector2(-w / 2, -h / 2), new Vector2(w / 2, -h / 2), new Vector2(w / 2, h / 2), new Vector2(-w / 2, h / 2) };
                for (int j = 0; j < seeds.Count && poly.Count >= 3; j++)
                {
                    if (i == j) continue;
                    var n = seeds[j] - seeds[i]; var m = (seeds[i] + seeds[j]) * .5f;
                    poly = Clip(poly, n, Vector2.Dot(m, n));
                }
                if (poly.Count < 3) continue;
                var sh = new Shard { poly = poly };
                foreach (var v in poly) sh.c += v;
                sh.c /= poly.Count;
                for (int k = 0; k < poly.Count; k++)
                {
                    var a = poly[k]; var b = poly[(k + 1) % poly.Count];
                    bool border = (Mathf.Abs(Mathf.Abs(a.x) - w / 2) < 1e-4f && Mathf.Abs(Mathf.Abs(b.x) - w / 2) < 1e-4f && Mathf.Sign(a.x) == Mathf.Sign(b.x))
                               || (Mathf.Abs(Mathf.Abs(a.y) - h / 2) < 1e-4f && Mathf.Abs(Mathf.Abs(b.y) - h / 2) < 1e-4f && Mathf.Sign(a.y) == Mathf.Sign(b.y));
                    sh.seam.Add(!border);
                }
                var outward = sh.c.sqrMagnitude > 1e-8f ? sh.c.normalized : Vector2.up;
                sh.dir = (outward - from * .35f + new Vector2(Rn(-.25f, .25f), Rn(-.1f, .35f))).normalized;
                float nearCentre = 1f - Mathf.Clamp01(sh.c.magnitude / (h * .5f));
                sh.speed = h * Rn(1.1f, 2f) * (1f + .5f * nearCentre);
                sh.spin = Rn(-420f, 420f); sh.tilt = Rn(300f, 720f) * (rng.NextDouble() < .5 ? -1f : 1f); sh.tiltAxis = Rn(0f, 180f);
                sh.dissolveAt = Rn(.12f, .26f); sh.shrink = Rn(.15f, .35f);
                shards.Add(sh);
            }
        }

        static List<Vector2> Clip(List<Vector2> poly, Vector2 n, float d)
        {
            var o = new List<Vector2>();
            for (int k = 0; k < poly.Count; k++)
            {
                var a = poly[k]; var b = poly[(k + 1) % poly.Count];
                float da = Vector2.Dot(a, n) - d, db = Vector2.Dot(b, n) - d;
                if (da <= 0) o.Add(a);
                if ((da < 0 && db > 0) || (da > 0 && db < 0)) o.Add(a + (b - a) * (da / (da - db)));
            }
            return o;
        }

        void LateUpdate()
        {
            age += Time.deltaTime;
            float t = age - delay;
            if (t > 0f) t *= HitPace;
            if (t > End) { Destroy(gameObject); return; }
            var cam = Camera.main;
            vs.Clear(); cs.Clear(); u0.Clear(); u1.Clear(); u2.Clear(); tris.Clear();
            if (cam && t >= 0f) Draw(cam, t);
            mesh.Clear();
            mesh.SetVertices(vs); mesh.SetColors(cs); mesh.SetUVs(0, u0); mesh.SetUVs(1, u1); mesh.SetUVs(2, u2);
            mesh.SetTriangles(tris, 0);
            mesh.bounds = new Bounds(at, Vector3.one * h * 12f);
        }

        void Draw(Camera cam, float t)
        {
            var R = cam.transform.right; var U = cam.transform.up;
            float rr = roll * Mathf.Deg2Rad;
            Vector2 Rot(Vector2 v, float a) { float c = Mathf.Cos(a), s = Mathf.Sin(a); return new Vector2(v.x * c - v.y * s, v.x * s + v.y * c); }
            Vector3 W(Vector2 p) => at + R * p.x + U * p.y;
            bool reduced = ReducedMotion;
            if (!burst && t >= BurstAt)
            {
                burst = true;
                int n = reduced ? 10 : 24;
                for (int i = 0; i < n; i++)
                {
                    var p = new Vector2(Rn(-.4f, .4f) * w, Rn(-.4f, .4f) * h);
                    var dir = (p.sqrMagnitude > 1e-6f ? p.normalized : Vector2.up) + new Vector2(Rn(-.4f, .4f), Rn(-.2f, .5f));
                    sparks.Add(new Spark { p = p, v = dir.normalized * h * Rn(1.4f, 3.4f), born = t, life = Rn(.3f, .6f), size = h * Rn(.06f, .12f), col = SparkColors[rng.Next(SparkColors.Length)] });
                }
            }
            // Arrival: the card flies in from the caster's side and lands with a flash.
            float slam = Mathf.Clamp01(t / Slam), e = 1f - Mathf.Pow(1f - slam, 3f);
            Vector2 offset = from * h * .6f * (1f - e);
            float scale = Mathf.Lerp(1.25f, 1f, e);
            float rollNow = rr + (1f - e) * .26f;
            float crack = Mathf.Clamp01((t - CrackFrom) / (BurstAt - CrackFrom));
            float tb = Mathf.Max(0f, t - BurstAt);
            float flashLand = t < .16f ? Mathf.Exp(-Mathf.Max(0f, t - Slam) / .05f) * slam : 0f;
            if (flashLand > .01f) Quad(W(offset), h * 1.25f, new Color(1f, .7f, .95f, flashLand * .8f), 2f, rollNow, R, U);
            if (tb > 0f)
            {
                float f = tb < .04f ? tb / .04f : Mathf.Exp(-(tb - .04f) / .14f);
                Quad(W(Vector2.zero), h * 1.9f, new Color(.86f, .38f, 1f, f), 2f, 0f, R, U);
            }
            foreach (var sh in shards)
            {
                Vector2 pos = Rot(sh.c * scale, rollNow) + offset;
                float spin = rollNow, sx = 1f, size = scale, fade = slam, dissolve = 0f;
                float seam = crack;
                if (tb > 0f)
                {
                    const float k = 4.2f;
                    pos += sh.dir * sh.speed * (1f - Mathf.Exp(-k * tb)) / k + Vector2.down * (.55f * h * tb * tb);
                    spin += sh.spin * Mathf.Deg2Rad * tb;
                    sx = Mathf.Cos(sh.tilt * Mathf.Deg2Rad * tb);
                    size *= 1f - sh.shrink * Mathf.Clamp01(tb / .5f);
                    seam = Mathf.Max(.35f, 1f - tb * 1.4f);
                    dissolve = Mathf.Clamp01((tb - sh.dissolveAt) / .3f);
                    fade *= 1f - Mathf.Clamp01((tb - .5f) / .13f);
                }
                if (fade <= .002f || dissolve >= .999f) continue;
                // Lit from inside once it bursts: a magenta glow fading as it flies.
                float lit = tb > 0f ? .3f * Mathf.Exp(-tb / .25f) + .1f : .06f * crack;
                var col = new Color(.95f * lit, .3f * lit, .85f * lit, fade);
                var dissolveUv = new Vector2(seam, dissolve * .95f);
                var centre = W(pos);
                for (int k = 0; k < sh.poly.Count; k++)
                {
                    var a = sh.poly[k]; var b = sh.poly[(k + 1) % sh.poly.Count];
                    float g = sh.seam[k] ? 1f : 0f;
                    int i0 = vs.Count;
                    Add(centre, col, new Vector2(sh.c.x / w + .5f, sh.c.y / h + .5f), new Vector2(0f, 0f), dissolveUv);
                    Add(W(pos + Local(a - sh.c, spin, sx, size)), col, new Vector2(a.x / w + .5f, a.y / h + .5f), new Vector2(g, 0f), dissolveUv);
                    Add(W(pos + Local(b - sh.c, spin, sx, size)), col, new Vector2(b.x / w + .5f, b.y / h + .5f), new Vector2(g, 0f), dissolveUv);
                    tris.Add(i0); tris.Add(i0 + 1); tris.Add(i0 + 2);
                }
            }
            for (int i = sparks.Count - 1; i >= 0; i--)
            {
                var sp = sparks[i]; float a = t - sp.born;
                if (a > sp.life) { sparks.RemoveAt(i); continue; }
                var p = sp.p + sp.v * (1f - Mathf.Exp(-3f * a)) / 3f + Vector2.down * (.4f * h * a * a);
                float k = a / sp.life, al = Mathf.Clamp01(k / .1f) * (1f - Mathf.SmoothStep(.5f, 1f, k));
                Quad(W(p), sp.size * (1f - .4f * k) * 2f, new Color(sp.col.r, sp.col.g, sp.col.b, al), 1f, 0f, R, U);
            }
        }

        static Vector2 Local(Vector2 v, float spin, float sx, float size)
        {
            v = new Vector2(v.x * sx, v.y) * size;
            float c = Mathf.Cos(spin), s = Mathf.Sin(spin);
            return new Vector2(v.x * c - v.y * s, v.x * s + v.y * c);
        }

        void Quad(Vector3 c, float size, Color col, float mode, float roll, Vector3 R, Vector3 U)
        {
            float cr = Mathf.Cos(roll), sr = Mathf.Sin(roll);
            var r = (R * cr + U * sr) * size * .5f; var u = (U * cr - R * sr) * size * .5f;
            int i0 = vs.Count; var m = new Vector2(0f, mode);
            Add(c - r - u, col, new Vector2(0, 0), m, Vector2.zero); Add(c + r - u, col, new Vector2(1, 0), m, Vector2.zero);
            Add(c + r + u, col, new Vector2(1, 1), m, Vector2.zero); Add(c - r + u, col, new Vector2(0, 1), m, Vector2.zero);
            tris.Add(i0); tris.Add(i0 + 1); tris.Add(i0 + 2); tris.Add(i0); tris.Add(i0 + 2); tris.Add(i0 + 3);
        }

        void Add(Vector3 p, Color c, Vector2 a, Vector2 b, Vector2 d) { vs.Add(p); cs.Add(c); u0.Add(a); u1.Add(b); u2.Add(d); }

        void OnDestroy()
        {
            if (owner) owner.live--;
            if (mesh) Destroy(mesh);
        }
    }


    /// One flying tarot card from the authored FoolTarotVFXAtlas (4x4, rows top to bottom:
    /// the card gathering out of light, the card streaking away, a star burst, sparkle dust).
    /// Row 1 plays at the launch point, row 2 along the course with the quad turned so the
    /// sheet's baked flight direction (to the upper right) follows the card on screen.
    /// Where a painted sprite is at hit time t: offset from the target in the camera plane
    /// (camera right/up units), roll in degrees, quad size, alpha and tint.
    struct Pose2 { public Vector2 off; public float roll, scale, alpha, sy, z, curl, frameAdd; public bool mirror, soft; public Color tint; }   // soft: fade as one picture (no _Erode wisps); frameAdd: a flipbook's frame past the cell
    /// Where a painted cell's picture rolls round when it curls (Pose2.curl): its hollow, and how far out the curl reaches.
    static Vector4 CurlCentre(int cell) => cell == 27 ? new Vector4(.64f, .52f, .62f, 0f) : new Vector4(.5f, .5f, .5f, 0f);

    /// One cell of the user's painted prop sheet (SpectaclePaint, 4x4) moved by a script over
    /// the hit (2026-10-09, user on batch 3 drawn as shapes: 不够游戏化，像是几何图形): the
    /// real painted hammer, axe, seal, lotus, petals and smoke carry the subject; Ink2D adds
    /// only the light round them. Plays at HitPace after the contact like the ink strokes.
    sealed class PaintSprite : MonoBehaviour
    {
        static Mesh quad;
        static readonly int FrameID = Shader.PropertyToID("_Frame"), AlphaID = Shader.PropertyToID("_Alpha"), TintID = Shader.PropertyToID("_Tint"),
            FlowID = Shader.PropertyToID("_Flow"), SeedID = Shader.PropertyToID("_Seed"), ErodeID = Shader.PropertyToID("_Erode"),
            CurlID = Shader.PropertyToID("_Curl"), CurlCID = Shader.PropertyToID("_CurlC");
        /// How each painted cell moves inside itself (SpectacleFlipbook _Flow): smoke and cloth
        /// billow, fire and the tornado lick upward, liquids and bubbles wobble, light shimmers;
        /// solid objects (weapons, hand, seal, crystals, rocks, horn, fist) stay rigid.
        static float FlowFor(int cell) => cell switch
        {
            7 or 8 or 9 or 10 or 11 or 24 or 28 => 1f,
            14 or 23 => 2f,
            5 or 6 or 18 or 19 or 25 or 27 or 31 => 3f,
            12 or 13 or 30 or 34 => 4f,
            37 => 2f,
            38 => 1f,
            39 or 41 => 2f,
            40 => 1f,
            42 or 43 or 44 => 3f,
            49 => 1f,   // the pursuer's mist billows; the angel's figures (50, 51) stay rigid
            48 => 4f,   // her feather shimmers
            201 => 4f,  // the gold sand glitters; the hourglass, shards and letter (200, 202-205) stay rigid
            _ => 0f,
        };
        float flow, seed; int globalCell;
        SpellSpectacle20260926 owner; MeshRenderer view; MaterialPropertyBlock block;
        Func<float, Pose2> script; Vector3 at; float delay, age, end; int cell;

        public static void Create(Transform parent, Material material, SpellSpectacle20260926 owner, Vector3 at, float delay, float end, int cell, Func<float, Pose2> script)
        {
            if (!quad)
            {
                quad = new Mesh { name = "PaintSpriteQuad" };
                quad.vertices = new[] { new Vector3(-.5f, -.5f, 0), new Vector3(.5f, -.5f, 0), new Vector3(-.5f, .5f, 0), new Vector3(.5f, .5f, 0) };
                quad.uv = new[] { Vector2.zero, Vector2.right, Vector2.up, Vector2.one };
                quad.triangles = new[] { 0, 2, 1, 2, 3, 1 };
                quad.bounds = new Bounds(Vector3.zero, Vector3.one * 4f);
            }
            // Cells 16+ are on the second sheet (rock burst, salt crystals, venom glob / splash).
            // Cells 16+ are on the second sheet, 32+ on the third (tower demons, bounties).
            int global = cell;
            if (cell >= 200) { if (!owner.paintFlipMaterial6) return; material = owner.paintFlipMaterial6; cell -= 200; }
            else if (cell >= 100) { if (!owner.paintFlipMaterial5) return; material = owner.paintFlipMaterial5; cell -= 100; }
            else if (cell >= 48) { if (!owner.paintFlipMaterial4) return; material = owner.paintFlipMaterial4; cell -= 48; }
            else if (cell >= 32) { if (!owner.paintFlipMaterial3) return; material = owner.paintFlipMaterial3; cell -= 32; }
            else if (cell >= 16) { if (!owner.paintFlipMaterial2) return; material = owner.paintFlipMaterial2; cell -= 16; }
            var go = new GameObject("SpectaclePaintSprite");
            go.transform.SetParent(parent, false);
            go.AddComponent<MeshFilter>().sharedMesh = quad;
            var p = go.AddComponent<PaintSprite>();
            p.view = go.AddComponent<MeshRenderer>(); p.view.sharedMaterial = material;
            p.view.shadowCastingMode = UnityEngine.Rendering.ShadowCastingMode.Off; p.view.receiveShadows = false; p.view.enabled = false;
            p.block = new MaterialPropertyBlock();
            p.owner = owner; p.at = at; p.delay = delay; p.end = end; p.cell = cell; p.script = script;
            p.flow = FlowFor(global); p.globalCell = global; p.seed = (p.GetInstanceID() & 255) * .0137f;
            owner.live++;
        }

        void LateUpdate()
        {
            age += Time.deltaTime;
            float t = age - delay;
            if (t > 0f) t *= HitPace;
            if (t > end) { Destroy(gameObject); return; }
            var cam = Camera.main;
            if (t < 0f || !cam) { view.enabled = false; return; }
            var p = script(t);
            if (p.scale < 0f) { Destroy(gameObject); return; }   // the script's owner is gone
            if (p.alpha <= .003f || p.scale <= .0001f) { view.enabled = false; return; }
            view.enabled = true;
            var ct = cam.transform;
            transform.SetPositionAndRotation(at + ct.right * p.off.x + ct.up * p.off.y - ct.forward * (.02f + p.z), ct.rotation * Quaternion.Euler(0f, 0f, p.roll));
            transform.localScale = new Vector3(p.mirror ? -p.scale : p.scale, p.scale * (p.sy > 0f ? p.sy : 1f), 1f);
            block.SetFloat(FrameID, cell + p.frameAdd); block.SetFloat(AlphaID, p.alpha); block.SetColor(TintID, p.tint);
            block.SetFloat(FlowID, flow); block.SetFloat(SeedID, seed); block.SetFloat(ErodeID, p.soft ? 0f : 1f);
            block.SetFloat(CurlID, p.curl); block.SetVector(CurlCID, CurlCentre(globalCell));
            view.SetPropertyBlock(block);
        }

        void OnDestroy() { if (owner) owner.live--; }
    }

    static float Ein(float u) { u = Mathf.Clamp01(u); return u * u * u; }
    static float Eout(float u) { u = Mathf.Clamp01(u); return 1f - Mathf.Pow(1f - u, 3f); }
    static float Iv(float a, float b, float x) => b == a ? 0f : Mathf.Clamp01((x - a) / (b - a));
    static Vector2 Rot2(Vector2 v, float a) { float c = Mathf.Cos(a), s = Mathf.Sin(a); return new Vector2(v.x * c - v.y * s, v.x * s + v.y * c); }
    static float Back(float x) { const float c1 = 1.70158f, c3 = c1 + 1f; x = Mathf.Clamp01(x) - 1f; return 1f + c3 * x * x * x + c1 * x * x; }

    /// The painted subject of each batch-3 enemy hit (cells: 1 axe, 2 hammer, 4 seal, 5 petal,
    /// 6 lotus, 7 round smoke, 8 sideways smoke burst, 10 veil smoke, 11 smoke column, 12 claw marks,
    /// 14 fire, 15 the boss's copper hand; 0 sword, 3 chain link; second sheet 16 rock burst, 17 salt
    /// crystals, 18 venom glob, 19 venom splash, 20 bone claws, 21 flame fist, 22 copper horn,
    /// 23 moon tornado, 24 crimson veil, 25 golden bubbles). s is the ink hit's size unit,
    /// dir the caster-to-target direction on screen; all times match the Ink2D script.
    void PaintedSubject(string kind, Camera cam, Vector3 caster, Vector3 at, float s, float delay, int seed)
    {
        if (!paintFlipMaterial) return;
        var d3 = at - caster;
        var dir = new Vector2(Vector3.Dot(d3, cam.transform.right), Vector3.Dot(d3, cam.transform.up));
        dir = dir.sqrMagnitude > 1e-6f ? dir.normalized : Vector2.down;
        var back = -dir; var side = new Vector2(-back.y, back.x);
        var rng = new System.Random(seed);
        float Rn(float a, float b) => a + (b - a) * (float)rng.NextDouble();
        Pose2 P(Vector2 off, float roll, float scale, float alpha, Color tint) => new Pose2 { off = off, roll = roll, scale = scale, alpha = alpha, tint = tint };
        // Fire that lives (user 2026-10-09: 这个太静态): the painted fire pops for a beat, then
        // breaks into tongues that rise, flicker and burn out, while small flames keep licking up.
        // Water surging out either side of an impact (user 2026-10-09: the side splashes held
        // still too long): on each side a big wave swells and rolls outward, a smaller one a beat
        // later further out, and each breaks into falling pieces almost at once.
        void Surge(Vector2 c, float at0, Color tint, int sd)
        {
            for (int side_ = 0; side_ < 2; side_++)
                for (int w_ = 0; w_ < 2; w_++)
                {
                    int side = side_, w = w_;
                    float sx = side == 0 ? -1f : 1f, born = at0 + .05f * w, brk = born + .13f, sc = w == 0 ? 1.25f : .85f, out0 = w == 0 ? .45f : 1.05f;
                    PaintSprite.Create(root, paintFlipMaterial, this, at, delay, brk + .03f, 27, t =>
                    {
                        float g = Back(Iv(born, brk, t)), roll = -sx * 26f * Iv(born, brk + .03f, t);
                        var pose = P(c + new Vector2(sx * (out0 + .35f * g) * s, .15f * s * g), roll, s * sc * (.35f + .65f * g), Iv(born, born + .02f, t) * (1f - Iv(brk, brk + .03f, t)), tint);
                        pose.mirror = side == 0; pose.z = .03f; pose.curl = 1.5f * 6.283f * Mathf.Pow(Iv(born, brk, t), 1.3f); return pose;
                    });
                    var end = P(c + new Vector2(sx * (out0 + .35f) * s, .15f * s), -sx * 26f * .75f, s * sc, 1f, tint); end.mirror = side == 0; end.z = .03f; end.curl = 1.5f * 6.283f;
                    PaintPieces.Create(root, this, at, delay + brk / HitPace, 27, end, Scatter.Burst, 1.9f * s, .42f, seed + sd + side * 2 + w);
                }
        }

        void FireBurst(Vector2 c, float sz, float dly)
        {
            PaintSprite.Create(root, paintFlipMaterial, this, at, dly, .2f, 14, t =>
                P(c, 0f, sz * (.45f + .55f * Back(Iv(0f, .1f, t))), Iv(0f, .02f, t) * (1f - Iv(.13f, .17f, t)), Color.white));
            PaintPieces.Create(root, this, at, dly + .13f / HitPace, 14, P(c, 0f, sz, 1f, Color.white), Scatter.Rise, 2.4f * s, .5f, seed + 31);
            for (int i_ = 0; i_ < 6; i_++)
            {
                int i = i_;   // a fresh copy per pass: lambdas below capture it
                float born = Rn(.04f, .32f), life = Rn(.22f, .32f), x = Rn(-.35f, .35f), roll = Rn(-14f, 14f), sc = Rn(.3f, .45f); int ii = i;
                PaintSprite.Create(root, paintFlipMaterial, this, at, dly, born + life + .02f, 14, t =>
                {
                    if (t < born) return P(Vector2.zero, 0f, 0f, 0f, Color.white);
                    float k = Iv(born, born + life, t);
                    return P(c + new Vector2(x * sz, -.15f * sz + .7f * sz * k), roll + 10f * Mathf.Sin(t * 14f + ii), sz * sc * (1f - .45f * k), Mathf.Sin(k * Mathf.PI), Color.white);
                });
            }
        }
        switch (kind)
        {
            case "verdict":
            {
                // The painted gold hammer swings down over the head onto the target.
                var pivot = back * (1.3f * s) + new Vector2(back.x >= 0f ? -.8f : .8f, 0f) * s;
                float L = 2.2f * s, endA = Mathf.Atan2(-pivot.y, -pivot.x), sg = pivot.x < 0f ? 1f : -1f;
                PaintSprite.Create(root, paintFlipMaterial, this, at, delay, .62f, 2, t =>
                {
                    float sw = Ein(Iv(0f, .2f, t)), up = Eout(Iv(.26f, .5f, t));
                    float a = endA + sg * (1f - sw) * 1.9f + sg * up * .3f;
                    var hd = new Vector2(Mathf.Cos(a), Mathf.Sin(a));
                    float al = Iv(0f, .04f, t) * (1f - Ein(Iv(.4f, .6f, t)));
                    return P(pivot + hd * (L * .5f), a * Mathf.Rad2Deg - 90f, L, al, Color.white);
                });
                PaintSprite.Create(root, paintFlipMaterial, this, at, delay + .2f / HitPace, .7f, 8, t =>
                    P(new Vector2(0f, -.75f * s), 0f, s * (1.6f + 1.6f * Eout(Iv(0f, .5f, t))), .85f * (1f - Ein(Iv(.1f, .7f, t))), new Color(.8f, .88f, 1f)));
                break;
            }
            case "sign":
            {
                // The painted fire-edged executioner's axe chops down from the other side.
                var pivot = back * (1.2f * s) + new Vector2(back.x >= 0f ? .9f : -.9f, 0f) * s;
                float L = 2.1f * s, endA = Mathf.Atan2(-pivot.y, -pivot.x), sg = pivot.x < 0f ? 1f : -1f;
                PaintSprite.Create(root, paintFlipMaterial, this, at, delay, .55f, 1, t =>
                {
                    float sw = Ein(Iv(0f, .18f, t));
                    float a = endA + sg * (1f - sw) * 2.1f;
                    var hd = new Vector2(Mathf.Cos(a), Mathf.Sin(a));
                    float al = Iv(0f, .04f, t) * (1f - Ein(Iv(.3f, .5f, t)));
                    return P(pivot + hd * (L * .5f), a * Mathf.Rad2Deg - 90f, L, al, Color.white);
                });
                FireBurst(new Vector2(0f, -.2f * s), 2.4f * s, delay + .18f / HitPace);
                PaintSprite.Create(root, paintFlipMaterial, this, at, delay + .18f / HitPace, .7f, 8, t =>
                    P(new Vector2(0f, -.75f * s), 0f, s * (1.4f + 1.4f * Eout(Iv(0f, .5f, t))), .6f * (1f - Ein(Iv(.1f, .7f, t))), new Color(.55f, .42f, .32f)));
                break;
            }
            case "sovereign":
            {
                // His giant copper hand (the user's painted copper_hand, cell 15) comes down out
                // of the sky, fingers first, and slams flat onto the target; it holds a beat and
                // lifts away. Where it struck, the seal from its palm (the painted seal, cell 4)
                // is left pressed into the ground under the target, glowing, then fading.
                float roll0 = Rn(-12f, 12f);
                var hd = Rot2(-back, .2f);
                PaintSprite.Create(root, paintFlipMaterial, this, at, delay, .75f, 15, t =>
                {
                    float dn = Ein(Iv(.02f, .24f, t)), lift = Ein(Iv(.36f, .6f, t));
                    float squash = t > .24f ? .1f * Mathf.Sin((t - .24f) * 45f) * Mathf.Exp(-(t - .24f) * 16f) : 0f;
                    // Smaller (2026-10-09, simulator 170.31: in the game camera the hand covered the hero).
                    var off = Vector2.Lerp(back * (2.6f * s), new Vector2(0f, .45f * s), dn) + back * (1.2f * s * lift);
                    float sc = Mathf.Lerp(1.9f, 1.35f, dn) * s * (1f + squash);
                    float al = Iv(.02f, .07f, t) * (1f - Ein(Iv(.38f, .6f, t)));
                    var pose = P(off, Mathf.Atan2(hd.y, hd.x) * Mathf.Rad2Deg - 90f + roll0 * (1f - dn), sc, al, Color.white);
                    pose.sy = 1f - squash;
                    pose.z = .06f;
                    return pose;
                });
                PaintSprite.Create(root, paintFlipMaterial, this, at, delay + .24f / HitPace, .7f, 4, t =>
                {
                    var pose = P(new Vector2(0f, -.68f * s), 0f, s * (1f + .3f * Eout(Iv(0f, .3f, t))), Eout(Iv(0f, .05f, t)) * (1f - Ein(Iv(.3f, .66f, t))), Color.white);
                    pose.sy = .4f; pose.z = .03f;
                    return pose;
                });
                PaintSprite.Create(root, paintFlipMaterial, this, at, delay + .24f / HitPace, .8f, 8, t =>
                    P(new Vector2(0f, -.75f * s), 0f, s * (1.8f + 2f * Eout(Iv(0f, .55f, t))), .45f * (1f - Ein(Iv(.1f, .75f, t))), new Color(1f, .85f, .55f)));
                break;
            }
            case "silk":
            {
                // A crimson lotus (the painted lotus, tinted) blooms open on the target behind a
                // burst of rose-silk veil smoke; its painted petals come loose and drift down.
                var rose = new Color(1f, .32f, .42f);
                PaintSprite.Create(root, paintFlipMaterial, this, at, delay + .14f / HitPace, .8f, 10, t =>
                    P(Vector2.zero, 0f, s * (1.6f + 1.8f * Eout(Iv(0f, .4f, t))), .55f * (1f - Ein(Iv(.1f, .6f, t))), new Color(1f, .55f, .62f)));
                PaintSprite.Create(root, paintFlipMaterial, this, at, delay + .16f / HitPace, .75f, 6, t =>
                    P(new Vector2(0f, .1f * s), t * 40f, s * 1.7f * Back(Iv(0f, .2f, t)) * (1f + .1f * Iv(.2f, .6f, t)), 1f - Ein(Iv(.35f, .6f, t)), rose));
                for (int i_ = 0; i_ < 7; i_++)
                {
                    int i = i_;   // a fresh copy per pass: lambdas below capture it
                    float ang = (i + Rn(-.3f, .3f)) * 6.283f / 7f, spin = Rn(-300f, 300f), t0 = Rn(.28f, .36f), drift = Rn(.6f, 1.1f);
                    var dv = new Vector2(Mathf.Cos(ang), Mathf.Sin(ang));
                    PaintSprite.Create(root, paintFlipMaterial, this, at, delay + .16f / HitPace, 1f, 5, t =>
                    {
                        float k = Iv(t0 - .16f, t0 - .16f + .6f, t);
                        var off = dv * (s * (.3f + drift * Eout(k))) + Vector2.down * (1.3f * s * k * k) + new Vector2(Mathf.Sin(t * 8f + ang) * .15f * s * k, 0f);
                        float al = Iv(t0 - .2f, t0 - .14f, t) * (1f - Ein(Iv(.35f, .8f, k)));
                        return P(off, ang * Mathf.Rad2Deg - 90f + spin * k, s * .5f, al, rose);
                    });
                }
                break;
            }
            case "chain":
            {
                // 押运: it pounds the ground in front of itself and a wave of rust dust (the
                // painted smoke, tinted) rolls along the floor toward the target, growing, and
                // breaks over it in a big burst.
                var floor0 = back * (2.6f * s) + new Vector2(0f, -.6f * s);
                var floor1 = new Vector2(0f, -.6f * s);
                for (int k_ = 0; k_ < 5; k_++)
                {
                    int k = k_;   // a fresh copy per pass: lambdas below capture it
                    float born = .03f * k, life = .42f;
                    float x0 = (k % 2 == 0 ? -1f : 1f) * Rn(.1f, .35f) * s;
                    PaintSprite.Create(root, paintFlipMaterial, this, at, delay, .75f, 8, t =>
                    {
                        float mv = Eout(Iv(born, born + .22f, t)), k2 = Iv(born, born + life, t);
                        var off = Vector2.Lerp(floor0, floor1, mv) + new Vector2(x0, .1f * s * k2);
                        float al = Iv(born, born + .04f, t) * (1f - Ein(Iv(born + .18f, born + life, t))) * .6f;
                        var pose = P(off, 0f, s * (.55f + .55f * mv + .3f * k2), al, new Color(.8f, .52f, .34f));
                        pose.sy = .7f;
                        return pose;
                    });
                }
                PaintSprite.Create(root, paintFlipMaterial, this, at, delay + .22f / HitPace, .75f, 11, t =>
                    P(new Vector2(0f, -.35f * s + .35f * s * Eout(Iv(0f, .5f, t))), 0f, s * (1.1f + .7f * Eout(Iv(0f, .4f, t))), .55f * Iv(0f, .06f, t) * (1f - Ein(Iv(.15f, .6f, t))), new Color(.85f, .55f, .36f)));
                break;
            }
            case "meteor":
            {
                // 救援: a blazing meteor (the painted fire, its flames trailing) falls in from the
                // side and bursts on the target in fire and smoke.
                var start = back * (3f * s) + new Vector2(back.x >= 0f ? 1.4f : -1.4f, 1.2f) * s;
                var vdir = (Vector2.zero - start).normalized;
                float roll = Mathf.Atan2(-vdir.y, -vdir.x) * Mathf.Rad2Deg - 90f;
                PaintSprite.Create(root, paintFlipMaterial, this, at, delay, .24f, 14, t =>
                {
                    float mv = Ein(Iv(0f, .2f, t));
                    var off = Vector2.Lerp(start, Vector2.zero, mv) - vdir * (.45f * s);
                    float al = Iv(0f, .04f, t) * (1f - Iv(.19f, .23f, t));
                    return P(off, roll + Mathf.Sin(t * 40f) * 4f, s * (1.1f + .5f * mv), al, Color.white);
                });
                FireBurst(new Vector2(0f, -.1f * s), 2.3f * s, delay + .2f / HitPace);
                PaintSprite.Create(root, paintFlipMaterial, this, at, delay + .2f / HitPace, .8f, 8, t =>
                    P(new Vector2(0f, -.6f * s), 0f, s * (1.7f + 2f * Eout(Iv(0f, .55f, t))), .7f * (1f - Ein(Iv(.1f, .75f, t))), new Color(.85f, .6f, .4f)));
                break;
            }
            case "toll":
            {
                // 第十三响: the thirteenth bell - painted swords rain down round the target one
                // after another and stick, then a giant sword falls on the target itself.
                for (int i_ = 0; i_ < 6; i_++)
                {
                    int i = i_;   // a fresh copy per pass: lambdas below capture it
                    float land = .05f + .035f * i;
                    var spot = new Vector2((i % 2 == 0 ? -1f : 1f) * Rn(.5f, 1.2f), Rn(-.75f, .1f)) * s;
                    float tilt = Rn(-14f, 14f);
                    var fromV = new Vector2(Mathf.Sin(tilt * Mathf.Deg2Rad), Mathf.Cos(tilt * Mathf.Deg2Rad));
                    PaintSprite.Create(root, paintFlipMaterial, this, at, delay, .8f, 0, t =>
                    {
                        float mv = Ein(Iv(land - .1f, land, t));
                        var off = spot + fromV * (3f * s * (1f - mv)) + fromV * (.42f * s);
                        float al = Iv(land - .1f, land - .07f, t) * (1f - Ein(Iv(.5f, .72f, t)));
                        return P(off, -tilt, s * .95f, al, new Color(1f, .88f, .85f));
                    });
                }
                PaintSprite.Create(root, paintFlipMaterial, this, at, delay, .9f, 0, t =>
                {
                    float mv = Ein(Iv(.18f, .3f, t));
                    var off = new Vector2(0f, .5f * s) + Vector2.up * (4f * s * (1f - mv));
                    float al = Iv(.18f, .21f, t) * (1f - Ein(Iv(.55f, .8f, t)));
                    return P(off, 0f, s * 2.3f, al, Color.white);
                });
                PaintSprite.Create(root, paintFlipMaterial, this, at, delay + .3f / HitPace, .7f, 8, t =>
                    P(new Vector2(0f, -.6f * s), 0f, s * (1.6f + 1.8f * Eout(Iv(0f, .5f, t))), .7f * (1f - Ein(Iv(.1f, .7f, t))), new Color(1f, .6f, .5f)));
                break;
            }
            case "emerald":
            {
                // 翡翠亡魂: emerald claw marks (the painted claws, tinted) rake the target and
                // a toxic green cloud boils up round it (the painted smoke, tinted).
                bool right = back.x < 0f;
                PaintSprite.Create(root, paintFlipMaterial, this, at, delay, .55f, 12, t =>
                    P(new Vector2(0f, .15f * s), right ? 0f : 90f, s * (1.7f + .5f * Eout(Iv(0f, .08f, t))), Iv(0f, .03f, t) * (1f - Ein(Iv(.28f, .5f, t))), new Color(.5f, 1f, .6f)));
                PaintSprite.Create(root, paintFlipMaterial, this, at, delay + .06f / HitPace, .9f, 11, t =>
                    P(new Vector2(0f, -.2f * s + .5f * s * Eout(Iv(0f, .6f, t))), 0f, s * (1.4f + 1f * Eout(Iv(0f, .5f, t))), .65f * Iv(0f, .08f, t) * (1f - Ein(Iv(.25f, .75f, t))), new Color(.3f, .95f, .45f)));
                PaintSprite.Create(root, paintFlipMaterial, this, at, delay + .04f / HitPace, .8f, 7, t =>
                    P(new Vector2(0f, -.55f * s), 0f, s * (1.3f + 1.4f * Eout(Iv(0f, .5f, t))), .55f * (1f - Ein(Iv(.15f, .7f, t))), new Color(.35f, .9f, .5f)));
                break;
            }
            case "nameseal":
            {
                // 夺名代签 (瑟维安, 2026-10-10 redo, user of the ribbons: 没什么关系，招数名字和样式要有
                // 关联；他是boss，法术效果范围要大): the target's NAME - the project's painted blank name
                // plate - is torn out of its chest and flies up over the party, huge; his SIGNATURE -
                // two strokes of the painted gold contract ink - is written across it one after the
                // other; his SEAL (the approved gold seal) stamps it; then the signed plate slams back
                // down onto the target and dissolves upward.
                Vector2 Plate(float t)
                {
                    float up = Eout(Iv(0f, .14f, t)), down = Ein(Iv(.62f, .74f, t));
                    var chest = new Vector2(0f, .2f * s); var hang = new Vector2(0f, 1.6f * s + .06f * s * Mathf.Sin(t * 7f));
                    return Vector2.Lerp(Vector2.Lerp(chest, hang, up), chest, down);
                }
                // Pulled into the target at the end rather than broken into flying bits (v3's pieces
                // read like the rejected scattered shards).
                float PlateSize(float t) => s * Mathf.Lerp(Mathf.Lerp(.3f, 2.2f, Eout(Iv(0f, .14f, t))), .15f, Ein(Iv(.62f, .8f, t)));
                Pose2 PlatePose(float t)
                {
                    // A shade darker: the cream parchment bloomed to a white board (v4).
                    var pose = P(Plate(t), 4f * Mathf.Sin(t * 5f), PlateSize(t), Iv(0f, .03f, t) * (1f - Iv(.74f, .82f, t)), new Color(.8f, .76f, .68f));
                    pose.z = .02f; return pose;
                }
                PaintSprite.Create(root, paintFlipMaterial, this, at, delay, .84f, 45, PlatePose);
                for (int k_ = 0; k_ < 2; k_++)
                {
                    int k = k_;   // a fresh copy per pass: lambdas below capture it
                    float b0 = .16f + .1f * k, roll = k == 0 ? -18f : 158f, len = k == 0 ? .78f : .62f, lift = k == 0 ? .05f : -.12f;
                    PaintSprite.Create(root, paintFlipMaterial, this, at, delay, .84f, 46, t =>
                    {
                        float draw = Eout(Iv(b0, b0 + .14f, t)), share = PlateSize(t) / (2.2f * s);
                        var pose = P(Plate(t) + new Vector2(0f, lift * s * share), roll + 4f * Mathf.Sin(t * 5f), PlateSize(t) * len * (.35f + .65f * draw), draw * (1f - Iv(.74f, .82f, t)), Color.white);
                        pose.sy = .7f; pose.curl = .3f * (1f - draw); pose.z = .03f + .005f * k; return pose;
                    });
                }
                PaintSprite.Create(root, paintFlipMaterial, this, at, delay, .84f, 4, t =>
                {
                    float fall = Eout(Iv(.4f, .46f, t)), pop = Back(Iv(.46f, .54f, t)), share = PlateSize(t) / (2.2f * s);
                    var pose = P(Plate(t) + new Vector2(0f, Mathf.Lerp(1.4f, 0f, fall) * s * share), 200f * (1f - fall), PlateSize(t) * (.32f + .22f * pop), Iv(.4f, .43f, t) * (1f - Iv(.74f, .82f, t)), Color.white);
                    pose.sy = 1f - .12f * Iv(.46f, .5f, t) * (1f - Iv(.5f, .56f, t)); pose.z = .04f; return pose;
                });
                break;
            }
            case "bronzeslam":
            {
                // 镇钟重砸 (瑟维安, 2026-10-10 redo with the user's painted bronze clock-bell, user of the
                // rock bursts alone: 不好看 … 招数名字和样式要有关联；他是boss，法术效果范围要大): the
                // bell drops out of the sky onto the middle of the party, slams down mouth-first with a
                // squash and keeps shuddering with its toll; a low wall of dust rolls out across all
                // three, and the bell lifts away and fades in gold mist.
                const float Hit = .12f;
                Pose2 Bell(float t)
                {
                    float fall = Ein(Iv(0f, Hit, t)), lift = Eout(Iv(.4f, .62f, t));   // lifts sooner: the hero hid under it too long
                    float squash = Iv(Hit, Hit + .04f, t) * (1f - Iv(Hit + .04f, Hit + .14f, t));
                    float shake = t > Hit ? Mathf.Sin((t - Hit) * 70f) * 3f * (1f - Iv(Hit, .5f, t)) : 0f;
                    var pose = P(new Vector2(0f, Mathf.Lerp(4.6f, .8f, fall) * s + .9f * s * lift), shake, 2.4f * s, Iv(0f, .03f, t) * (1f - Iv(.46f, .62f, t)), Color.white);
                    pose.sy = 1f - .12f * squash; pose.z = .05f; return pose;
                }
                PaintSprite.Create(root, paintFlipMaterial, this, at, delay, .74f, 47, Bell);
                // The dust wall rolling out both ways along the floor from under the bell.
                for (int way_ = 0; way_ < 2; way_++)
                {
                    int way = way_;   // a fresh copy per pass: lambdas below capture it
                    PaintSprite.Create(root, paintFlipMaterial, this, at, delay + Hit / HitPace, .7f, 8, t =>
                    {
                        float g = Eout(Iv(0f, .45f, t));
                        var pose = P(new Vector2((way == 0 ? -1f : 1f) * (.4f + 1.6f * g) * s, -.7f * s), 0f, s * (1.2f + 2.4f * g), .62f * Iv(0f, .04f, t) * (1f - Ein(Iv(.25f, .75f, t))), new Color(.86f, .72f, .48f));
                        pose.sy = .32f; pose.mirror = way == 0; pose.z = .06f; return pose;
                    });
                }
                // No rock bursts under the party any more (user 10-10: 这三团屎可以去掉了).
                // Thick gold mist (user 10-10: 金色尘雾可以浓一些): it billows out of the bell's mouth at
                // the slam, two layers swelling and rising, and is still hanging as the bell lifts away.
                for (int m_ = 0; m_ < 3; m_++)
                {
                    int m = m_;   // a fresh copy per pass: lambdas below capture it
                    float b0 = Hit + .03f * m, x = (m - 1) * .7f * s, spin = (m == 1 ? 1f : -1f) * 22f;
                    PaintSprite.Create(root, paintFlipMaterial, this, at, delay + b0 / HitPace, 1f, m == 1 ? 11 : 7, t =>
                    {
                        float g = Eout(Iv(0f, .7f, t));
                        var pose = P(new Vector2(x * (1f + .6f * g), -.5f * s + 1.2f * s * g), t * spin, s * (1.3f + 1.6f * g), .62f * Iv(0f, .08f, t) * (1f - Ein(Iv(.45f, 1f, t))), new Color(1f, .84f, .5f));
                        pose.z = .06f + .005f * m; return pose;
                    });
                }
                break;
            }
            case "hellbreath":
            {
                // 猎犬冥火喷吐 lands (its painted stream arrived just before, BreathStream): the
                // hellfire splashes over the target as fire that pops and breaks into rising
                // tongues, and dark red smoke rolls up as it burns out.
                FireBurst(new Vector2(0f, .15f * s), 1.8f * s, delay);
                PaintSprite.Create(root, paintFlipMaterial, this, at, delay + .1f / HitPace, .95f, 7, t =>
                    P(new Vector2(0f, .1f * s + .8f * s * Eout(Iv(0f, .8f, t))), t * 20f, s * (1.1f + 1.3f * Eout(Iv(0f, .6f, t))), .4f * Iv(0f, .1f, t) * (1f - Ein(Iv(.35f, .85f, t))), new Color(.6f, .28f, .22f)));
                break;
            }
            case "emeraldfog":
            {
                // 翠毒漫天 lands: its wisps (BreathStream) wind round the target's legs and tear
                // apart; here only a little smoke in the fog's own green climbing where they meet.
                PaintSprite.Create(root, paintFlipMaterial, this, at, delay + .12f / HitPace, 1f, 7, t =>
                    P(new Vector2(0f, -.35f * s + .9f * s * Eout(Iv(0f, .8f, t))), t * 25f, s * (.8f + .9f * Eout(Iv(0f, .6f, t))), .3f * Iv(0f, .1f, t) * (1f - Ein(Iv(.35f, .9f, t))), PoisonGreen));
                break;
            }
            case "emeraldburst":
            {
                // 返场毒爆 lands: the clot (BreathStream) bursts - the painted toxic flame is squeezed
                // small for a beat, then blows out past its size, twisting round its bright core
                // (low left in the painting, kept on the target), and its tongues tear off and rise
                // as it burns out; a yellow-green fume climbs behind.
                float rb = Rn(-25f, 25f);
                Pose2 Blast(float t)
                {
                    float pop = Back(Iv(.03f, .15f, t)), sc = s * (.5f + 2.8f * pop), roll = rb + 25f * Iv(0f, .5f, t);
                    var pose = P(new Vector2(0f, .2f * s) + Rot2(new Vector2(.2f, .1f), roll * Mathf.Deg2Rad) * sc, roll, sc, Iv(0f, .02f, t) * (1f - Iv(.34f, .38f, t)), Color.white);
                    pose.curl = .8f * Eout(Iv(.05f, .4f, t)); return pose;
                }
                PaintSprite.Create(root, paintFlipMaterial, this, at, delay, .4f, 41, Blast);
                var endB = Blast(.34f); endB.alpha = 1f;
                PaintPieces.Create(root, this, at, delay + .34f / HitPace, 41, endB, Scatter.Rise, 2.4f * s, .55f, seed + 43);
                PaintSprite.Create(root, paintFlipMaterial, this, at, delay + .12f / HitPace, .95f, 7, t =>
                    P(new Vector2(0f, .1f * s + .9f * s * Eout(Iv(0f, .8f, t))), -t * 30f, s * (1f + 1f * Eout(Iv(0f, .6f, t))), .22f * Iv(0f, .1f, t) * (1f - Ein(Iv(.35f, .9f, t))), new Color(.45f, .85f, .3f)));
                break;
            }
            case "geyser":
            {
                // 石皮 (stonehide) slams the floor (2026-10-09 redo, user: 太简单): low amber dust
                // shoots out along the floor, then the painted rock burst erupts at the target's
                // feet with an overshoot, three of its chunks are flung off spinning, and the
                // rubble sinks back as the dust thins.
                PaintSprite.Create(root, paintFlipMaterial, this, at, delay, .8f, 8, t =>
                {
                    var pose = P(new Vector2(0f, -.75f * s), 0f, s * (1.1f + 1.5f * Eout(Iv(0f, .4f, t))), .45f * (1f - Ein(Iv(.15f, .6f, t))), new Color(.62f, .46f, .3f));
                    pose.sy = .45f; return pose;
                });
                PaintSprite.Create(root, paintFlipMaterial, this, at, delay, .85f, 16, t =>
                {
                    float pop = Back(Iv(0f, .13f, t)), sink = Ein(Iv(.38f, .72f, t));
                    // It holds less long now: it breaks up into the falling rubble below.
                    var pose = P(new Vector2(0f, -.3f * s + .15f * s * pop - .35f * s * sink), Mathf.Sin(t * 30f) * 2f * (1f - Iv(0f, .2f, t)) + 8f * t, s * (.4f + 1.15f * pop + .25f * Iv(.13f, .6f, t)), Iv(0f, .03f, t) * (1f - Ein(Iv(.34f, .48f, t))), new Color(.68f, .6f, .52f));
                    pose.sy = .9f; pose.z = .04f; return pose;
                });
                // Rubble (user 2026-10-09: 石头消散得更碎): as the burst breaks up, a dozen small
                // pieces of it scatter from where it stood, tumble, fall and shrink away.
                for (int k_ = 0; k_ < 12; k_++)
                {
                    int k = k_;   // a fresh copy per pass: lambdas below capture it
                    var from = new Vector2(Rn(-.75f, .75f), Rn(-.55f, .45f)) * s;
                    float born = Rn(.33f, .42f), spin = Rn(-700f, 700f), r0 = Rn(0f, 360f), size = Rn(.14f, .3f);
                    var v = new Vector2(from.x * Rn(1.2f, 2.2f) / s, Rn(.4f, 1.6f));
                    PaintSprite.Create(root, paintFlipMaterial, this, at, delay, .85f, 16, t =>
                    {
                        float dt = t - born; if (dt < 0f) return P(Vector2.zero, 0f, 0f, 0f, Color.white);
                        var off = new Vector2(0f, -.3f * s) + from + v * (s * dt) + Vector2.down * (5.5f * s * dt * dt);
                        var pose = P(off, r0 + spin * dt, s * size * (1f - .5f * Iv(.15f, .4f, dt)), Iv(0f, .03f, dt) * (1f - Ein(Iv(.2f, .42f, dt))), new Color(.7f, .62f, .54f));
                        pose.z = .05f; return pose;
                    });
                }
                for (int k_ = 0; k_ < 3; k_++)
                {
                    int k = k_;   // a fresh copy per pass: lambdas below capture it
                    float ang = (k == 0 ? 120f : k == 1 ? 60f : 92f) * Mathf.Deg2Rad + Rn(-.15f, .15f), sp = Rn(2.6f, 3.4f), spin = Rn(-500f, 500f), r0 = Rn(0f, 360f);
                    var v = new Vector2(Mathf.Cos(ang), Mathf.Sin(ang)) * sp;
                    PaintSprite.Create(root, paintFlipMaterial, this, at, delay + .05f / HitPace, .7f, 16, t =>
                    {
                        var off = new Vector2(0f, -.3f * s) + v * (s * t) + Vector2.down * (6f * s * t * t);
                        var pose = P(off, r0 + spin * t, s * .42f, Iv(0f, .03f, t) * (1f - Ein(Iv(.35f, .6f, t))), new Color(.7f, .62f, .54f));
                        pose.z = .05f; return pose;
                    });
                }
                break;
            }
            case "salt":
            {
                // 盐喉 (saltmaw) salt spike (redo, user: 丑): the painted salt crystal cluster
                // thrusts up out of the floor under the target (grows from its base with an
                // overshoot), a smaller cluster bursts up beside it a beat later, salt dust
                // puffs out low; they hold, then sink and fade into the dust.
                var foot = new Vector2(0f, -.85f * s);
                void Cluster(float born, float x, float size, float roll, float dly)
                {
                    PaintSprite.Create(root, paintFlipMaterial, this, at, delay + dly / HitPace, .9f, 17, t =>
                    {
                        float g = Back(Iv(born, born + .1f, t)), sink = Ein(Iv(.4f, .7f, t));
                        float h = size * s * Mathf.Max(.02f, g);
                        var pose = P(foot + new Vector2(x * s, h * .5f - .4f * s * sink), roll, size * s, Iv(born, born + .02f, t) * (1f - Ein(Iv(.48f, .75f, t))), new Color(.86f, .86f, .9f));
                        pose.sy = Mathf.Max(.02f, g); pose.z = .04f; return pose;
                    });
                }
                Cluster(0f, 0f, 1.7f, 0f, 0f);
                Cluster(0f, -.85f, 1f, 14f, .07f);
                Cluster(0f, .8f, .85f, -16f, .12f);
                PaintSprite.Create(root, paintFlipMaterial, this, at, delay + .03f / HitPace, .8f, 7, t =>
                {
                    var pose = P(foot + new Vector2(0f, .1f * s), 0f, s * (1.3f + 1.4f * Eout(Iv(0f, .45f, t))), .35f * (1f - Ein(Iv(.15f, .6f, t))), new Color(.8f, .9f, .95f));
                    pose.sy = .4f; return pose;
                });
                break;
            }
            case "spit":
            {
                // 盐喉吐毒 (salt poison, redo, user: 丑又简单): the painted venom glob flies from its
                // mouth to the target, head first and wobbling; it bursts into the painted venom
                // splash, which sags and drips, and a sickly green mist boils up behind it.
                var start = back * (2.6f * s) + Vector2.up * (.7f * s);
                PaintSprite.Create(root, paintFlipMaterial, this, at, delay, .2f, 18, t =>
                {
                    float mv = Iv(0f, .18f, t);
                    var off = Vector2.Lerp(start, new Vector2(0f, .1f * s), mv) + Vector2.up * (1f * s * mv * (1f - mv));
                    var vel = (new Vector2(0f, .1f * s) - start) + Vector2.up * (1f * s * (1f - 2f * mv));
                    float roll = Mathf.Atan2(vel.y, vel.x) * Mathf.Rad2Deg - 45f;
                    var pose = P(off, roll, s * (1.1f + .4f * mv), Iv(0f, .03f, t) * (1f - Iv(.17f, .2f, t)), Color.white);
                    pose.sy = 1f + .1f * Mathf.Sin(t * 50f); return pose;
                });
                PaintSprite.Create(root, paintFlipMaterial, this, at, delay + .18f / HitPace, .85f, 19, t =>
                {
                    float pop = Back(Iv(0f, .12f, t)), sag = Ein(Iv(.2f, .65f, t));
                    var pose = P(new Vector2(0f, .05f * s - .5f * s * sag), Mathf.Sin(t * 6f) * 4f, s * (.5f + 1.5f * pop), Iv(0f, .03f, t) * (1f - Ein(Iv(.4f, .75f, t))), Color.white);
                    pose.sy = 1f + .25f * sag; pose.z = .04f; return pose;
                });
                PaintSprite.Create(root, paintFlipMaterial, this, at, delay + .24f / HitPace, .9f, 7, t =>
                    P(new Vector2(0f, -.2f * s + .7f * s * Eout(Iv(0f, .7f, t))), t * 25f, s * (1.1f + 1.2f * Eout(Iv(0f, .5f, t))), .5f * Iv(0f, .08f, t) * (1f - Ein(Iv(.3f, .8f, t))), new Color(.45f, 1f, .55f)));
                break;
            }
            case "steel":
            {
                // 铁爪 (ironclaw): two painted steel sword-qi crescents slash across the target
                // in an X, the second a beat after the first; a heavy cut adds a third, larger.
                bool heavyCut = s > .0f && seed % 3 == 0;
                int cuts = 2;
                for (int k_ = 0; k_ < cuts; k_++)
                {
                    int k = k_;   // a fresh copy per pass: lambdas below capture it
                    float born = .07f * k, ang = (k == 0 ? 35f : -35f) + Rn(-8f, 8f);
                    var dv = new Vector2(Mathf.Cos(ang * Mathf.Deg2Rad), Mathf.Sin(ang * Mathf.Deg2Rad)) * (k == 0 ? 1f : -1f);
                    PaintSprite.Create(root, paintFlipMaterial, this, at, delay, .5f, 13, t =>
                    {
                        float mv = Eout(Iv(born, born + .1f, t));
                        var off = Vector2.Lerp(-dv * (1.4f * s), dv * (.5f * s), mv);
                        float al = Iv(born, born + .02f, t) * (1f - Ein(Iv(born + .1f, born + .26f, t)));
                        var pose = P(off, Mathf.Atan2(dv.y, dv.x) * Mathf.Rad2Deg, s * (2f + .3f * mv), al, new Color(.6f, .85f, 1f));
                        pose.sy = 1.15f; return pose;
                    });
                }
                break;
            }
            case "sonic":
            {
                // 鳍蛇 (frilled naga) sound arrow: a painted golden sword-qi crescent flies in like
                // a sonic arrowhead, convex side first; it bursts on the target in gold smoke.
                var start = back * (2.8f * s);
                var vdir = (Vector2.zero - start).normalized;
                PaintSprite.Create(root, paintFlipMaterial, this, at, delay, .2f, 13, t =>
                {
                    float mv = Iv(0f, .16f, t);
                    var off = Vector2.Lerp(start, Vector2.zero, mv);
                    var pose = P(off, Mathf.Atan2(vdir.y, vdir.x) * Mathf.Rad2Deg + 180f, s * (1.2f + .5f * mv), Iv(0f, .03f, t) * (1f - Iv(.15f, .19f, t)), new Color(1f, .9f, .45f));
                    pose.sy = 1.3f; return pose;
                });
                PaintSprite.Create(root, paintFlipMaterial, this, at, delay + .16f / HitPace, .7f, 8, t =>
                    P(new Vector2(0f, 0f), 0f, s * (1.3f + 1.5f * Eout(Iv(0f, .4f, t))), .6f * (1f - Ein(Iv(.1f, .6f, t))), new Color(1f, .9f, .55f)));
                break;
            }
            case "bonerake":
            {
                // 骨爪 (boneclaw): the painted bone claws rake down across the target from its
                // side (alternating sides between casts), leaving three teal claw tears that hang
                // for a moment.
                bool m = (seed & 1) == 1;
                float sx = m ? -1f : 1f;
                PaintSprite.Create(root, paintFlipMaterial, this, at, delay, .4f, 20, t =>
                {
                    float mv = Ein(Iv(0f, .13f, t));
                    var off = Vector2.Lerp(new Vector2(-1.1f * sx, .9f) * s, new Vector2(.55f * sx, -.45f) * s, mv);
                    var pose = P(off, sx * (12f - 28f * mv), s * 2f, Iv(0f, .03f, t) * (1f - Ein(Iv(.14f, .3f, t))), Color.white);
                    pose.mirror = m; pose.z = .05f; return pose;
                });
                PaintSprite.Create(root, paintFlipMaterial, this, at, delay + .1f / HitPace, .6f, 12, t =>
                {
                    var pose = P(new Vector2(0f, .1f * s), m ? 90f : 0f, s * (1.5f + .3f * Eout(Iv(0f, .08f, t))), Iv(0f, .03f, t) * (1f - Ein(Iv(.22f, .45f, t))), new Color(.45f, 1f, .9f));
                    return pose;
                });
                break;
            }
            case "ram":
            {
                // 铜背 (copperback): its painted copper horn charges in from its side, tip first,
                // rams the target with a jolt, recoils and is gone; copper dust bursts out low.
                var start = back * (2.2f * s) + Vector2.up * (.2f * s);
                var vd = (Vector2.zero - start).normalized;
                float ang = Mathf.Atan2(vd.y, vd.x) * Mathf.Rad2Deg;
                bool m = vd.x < 0f;
                PaintSprite.Create(root, paintFlipMaterial, this, at, delay, .5f, 22, t =>
                {
                    float mv = Ein(Iv(0f, .16f, t)), rec = Eout(Iv(.16f, .3f, t));
                    var off = Vector2.Lerp(start, Vector2.zero, mv) - vd * (.55f * s) - vd * (.45f * s * rec);
                    var pose = P(off, m ? ang + 180f : ang, s * 1.4f, Iv(0f, .03f, t) * (1f - Ein(Iv(.3f, .44f, t))), Color.white);
                    float jolt = t > .16f ? Mathf.Exp(-(t - .16f) * 25f) : 0f;
                    pose.sy = 1f + .18f * jolt; pose.scale *= 1f - .12f * jolt;
                    pose.mirror = m; pose.z = .05f; return pose;
                });
                PaintSprite.Create(root, paintFlipMaterial, this, at, delay + .16f / HitPace, .75f, 8, t =>
                {
                    var pose = P(new Vector2(0f, -.6f * s), 0f, s * (1.2f + 1.5f * Eout(Iv(0f, .45f, t))), .55f * (1f - Ein(Iv(.12f, .65f, t))), new Color(.82f, .52f, .32f));
                    pose.sy = .55f; return pose;
                });
                break;
            }
            case "fist":
            {
                // 赤魔 (crimson brute): its painted flaming fist comes from its side straight at the
                // camera, growing as it closes, slams the target with a shudder, then breaks apart
                // into burning pieces as living fire and dark smoke burst up.
                var start = back * (2.4f * s) + Vector2.up * (.5f * s);
                PaintSprite.Create(root, paintFlipMaterial, this, at, delay, .36f, 21, t =>
                {
                    float mv = Ein(Iv(0f, .2f, t)), hit = t > .2f ? Mathf.Exp(-(t - .2f) * 14f) : 0f;
                    var off = Vector2.Lerp(start, new Vector2(0f, .15f * s), mv) + new Vector2(Mathf.Sin(t * 90f) * .06f * s * hit, 0f);
                    var pose = P(off, Mathf.Sin(t * 70f) * 4f * hit, s * (.45f + 1.2f * mv + .15f * Iv(.2f, .5f, t)), Iv(0f, .03f, t) * (1f - Iv(.3f, .33f, t)), Color.white);
                    pose.z = .06f; return pose;
                });
                var broke = P(new Vector2(0f, .15f * s), 0f, s * (.45f + 1.2f + .15f * .33f), 1f, Color.white); broke.z = .06f;
                PaintPieces.Create(root, this, at, delay + .3f / HitPace, 21, broke, Scatter.Burst, 2.2f * s, .45f, seed + 17);
                FireBurst(new Vector2(0f, -.05f * s), 2.4f * s, delay + .2f / HitPace);
                PaintSprite.Create(root, paintFlipMaterial, this, at, delay + .22f / HitPace, .85f, 7, t =>
                    P(new Vector2(0f, -.1f * s + .6f * s * Eout(Iv(0f, .7f, t))), t * 20f, s * (1.2f + 1.3f * Eout(Iv(0f, .5f, t))), .5f * Iv(0f, .06f, t) * (1f - Ein(Iv(.25f, .75f, t))), new Color(.45f, .3f, .26f)));
                break;
            }
            case "veil":
            {
                // 帷幕先知 (veil oracle): three layers of the painted crimson veil whirl in round
                // the target one after another, billowing (cloth flow) and turning at different
                // speeds; then each tears apart into pieces that swirl out, with petals.
                for (int k_ = 0; k_ < 3; k_++)
                {
                    int k = k_;   // a fresh copy per pass: lambdas below capture it
                    float sp = k == 0 ? -430f : k == 1 ? -300f : -520f, r0 = k * 70f, sc = k == 0 ? 1.8f : k == 1 ? 1.45f : 1.15f, born = .04f * k, br = .32f + .03f * k;
                    var off0 = new Vector2(k == 1 ? -.18f : k == 2 ? .2f : 0f, .1f * s + (k == 2 ? .15f * s : 0f));
                    float aMax = k == 0 ? 1f : .75f;
                    PaintSprite.Create(root, paintFlipMaterial, this, at, delay, br + .05f, 24, t =>
                    {
                        float g = Back(Iv(born, born + .2f, t));
                        var pose = P(off0 * (k == 0 ? 1f : s), r0 + sp * t, s * sc * (.3f + .7f * g), aMax * Iv(born, born + .04f, t) * (1f - Iv(br, br + .04f, t)), Color.white);
                        pose.mirror = k == 1; pose.z = .04f; return pose;
                    });
                    var at0 = P(off0 * (k == 0 ? 1f : s), r0 + sp * br, s * sc, aMax, Color.white); at0.mirror = k == 1; at0.z = .04f;
                    PaintPieces.Create(root, this, at, delay + br / HitPace, 24, at0, Scatter.Swirl, 1.6f * s, .55f, seed + 40 + k);
                }
                var rose = new Color(1f, .3f, .42f);
                for (int i_ = 0; i_ < 9; i_++)
                {
                    int i = i_;   // a fresh copy per pass: lambdas below capture it
                    float a0 = (i + Rn(-.3f, .3f)) * 6.283f / 9f, spin = Rn(-400f, 400f), born = Rn(.34f, .44f), dist = Rn(1.2f, 2f);
                    PaintSprite.Create(root, paintFlipMaterial, this, at, delay, 1.1f, 5, t =>
                    {
                        float k = Iv(born, born + .55f, t); if (t < born) return P(Vector2.zero, 0f, 0f, 0f, rose);
                        float a = a0 - 2.4f * k;
                        var off = new Vector2(Mathf.Cos(a), Mathf.Sin(a) * .8f) * (s * (.5f + dist * Eout(k))) + Vector2.down * (.8f * s * k * k);
                        return P(off, a * Mathf.Rad2Deg + spin * k, s * .42f, Iv(born, born + .04f, t) * (1f - Ein(Iv(.4f, 1f, k))), rose);
                    });
                }
                break;
            }
            case "bubbles":
            {
                // 金喉 (golden throat): a stream of small painted golden bubble clusters wobbles out
                // of its throat to the target; there several clusters bloom one after another
                // round the target, quiver, and each bursts apart into bubbles flying off.
                var start = back * (2.5f * s) + Vector2.up * (.6f * s);
                var gold = new Color(.78f, .72f, .5f);
                for (int i_ = 0; i_ < 7; i_++)
                {
                    int i = i_;   // a fresh copy per pass: lambdas below capture it
                    float born = .03f * i, roll = Rn(0f, 360f), sz = Rn(.25f, .42f);
                    PaintSprite.Create(root, paintFlipMaterial, this, at, delay, .3f, 25, t =>
                    {
                        float mv = Iv(born, born + .17f, t);
                        var off = Vector2.Lerp(start, Vector2.zero, mv) + new Vector2(Mathf.Sin(t * 30f + i) * .18f * s, Mathf.Sin(mv * Mathf.PI) * .4f * s);
                        return P(off, roll + t * 200f, s * sz, Iv(born, born + .03f, t) * (1f - Iv(born + .15f, born + .19f, t)), gold);
                    });
                }
                for (int c_ = 0; c_ < 5; c_++)
                {
                    int c = c_;   // a fresh copy per pass: lambdas below capture it
                    float born = .18f + .035f * c, br = born + .13f, sz = c == 0 ? 1.15f : Rn(.6f, .85f), roll = Rn(0f, 360f);
                    var off0 = c == 0 ? new Vector2(0f, .1f * s) : new Vector2(Rn(-.7f, .7f), Rn(-.5f, .7f)) * s;
                    PaintSprite.Create(root, paintFlipMaterial, this, at, delay, br + .05f, 25, t =>
                    {
                        float g = Back(Iv(born, born + .1f, t));
                        var pose = P(off0, roll + Mathf.Sin(t * 12f + c) * 6f, s * sz * (.3f + .7f * g), Iv(born, born + .03f, t) * (1f - Iv(br, br + .03f, t)), gold);
                        pose.sy = 1f + .07f * Mathf.Sin(t * 40f + c); pose.z = .04f; return pose;
                    });
                    var at0 = P(off0, roll, s * sz, 1f, gold); at0.z = .04f;
                    PaintPieces.Create(root, this, at, delay + br / HitPace, 25, at0, Scatter.Burst, 2.6f * s, .42f, seed + 60 + c);
                }
                break;
            }
            case "moonwind":
            {
                // 月牙 (moonfang): a painted moon-blade tornado spins up out of the floor round the
                // target (two layers, one mirrored, shimmering into each other so it reads as
                // turning), three painted silver crescent blades circle in it, then it lifts away.
                var foot = new Vector2(0f, -.9f * s);
                for (int k_ = 0; k_ < 2; k_++)
                {
                    int k = k_;   // a fresh copy per pass: lambdas below capture it
                    PaintSprite.Create(root, paintFlipMaterial, this, at, delay, .95f, 23, t =>
                    {
                        float g = Eout(Iv(0f, .2f, t)), lift = Ein(Iv(.5f, .85f, t));
                        float h = 2.6f * s, sy = .25f + .75f * g;
                        float shimmer = .5f + .5f * Mathf.Sin(t * 16f + k * Mathf.PI);
                        var pose = P(foot + new Vector2(0f, h * .5f * sy + .8f * s * lift), Mathf.Sin(t * 7f + k) * 4f, h * (.7f + .3f * g), (.55f + .45f * shimmer) * Iv(0f, .04f, t) * (1f - Ein(Iv(.55f, .85f, t))), new Color(.85f, .92f, 1f));
                        pose.sy = sy; pose.mirror = k == 1; pose.z = .03f; return pose;
                    });
                }
                for (int k_ = 0; k_ < 3; k_++)
                {
                    int k = k_;   // a fresh copy per pass: lambdas below capture it
                    PaintSprite.Create(root, paintFlipMaterial, this, at, delay + .06f / HitPace, .8f, 13, t =>
                    {
                        float a = t * 10f + k * 2.094f, rise = .2f + .6f * k / 2f;
                        var off = new Vector2(Mathf.Cos(a) * .9f * s, (rise + Mathf.Sin(a) * .18f) * s);
                        float roll = (Mathf.Sin(a) > 0f ? 180f : 0f) + Mathf.Cos(a) * 20f;
                        var pose = P(off, roll, s * .9f, Iv(0f, .05f, t) * (1f - Ein(Iv(.45f, .7f, t))), new Color(.7f, .82f, 1f));
                        pose.sy = .7f; pose.z = Mathf.Sin(a) < 0f ? .06f : 0f; return pose;
                    });
                }
                break;
            }
            case "pounce":
            {
                // 甲背 (shellback) short pounce: it lands on the target - two orange claw tears
                // cross over it, dust bursts out low and a spray of rubble breaks off and falls.
                for (int k_ = 0; k_ < 2; k_++)
                {
                    int k = k_;   // a fresh copy per pass: lambdas below capture it
                    float born = .05f * k;
                    PaintSprite.Create(root, paintFlipMaterial, this, at, delay, .55f, 12, t =>
                    {
                        var pose = P(new Vector2(0f, .05f * s), 0f, s * (1.3f + .3f * Eout(Iv(born, born + .08f, t))), Iv(born, born + .03f, t) * (1f - Ein(Iv(born + .2f, born + .4f, t))), new Color(1f, .62f, .32f));
                        pose.mirror = k == 1; return pose;
                    });
                }
                PaintSprite.Create(root, paintFlipMaterial, this, at, delay, .75f, 8, t =>
                {
                    var pose = P(new Vector2(0f, -.65f * s), 0f, s * (1.1f + 1.4f * Eout(Iv(0f, .45f, t))), .55f * (1f - Ein(Iv(.12f, .6f, t))), new Color(.8f, .55f, .38f));
                    pose.sy = .5f; return pose;
                });
                var rub = P(new Vector2(0f, -.45f * s), 0f, s * 1.1f, 1f, new Color(.7f, .6f, .52f)); rub.sy = .7f; rub.z = .04f;
                PaintPieces.Create(root, this, at, delay + .03f / HitPace, 16, rub, Scatter.Burst, 2.6f * s, .45f, seed + 80);
                break;
            }
            case "lotusmend":
            {
                // 甲背回血 (tower mend on an ally): a painted lotus opens at the ally's feet in pale
                // jade and gold, turning slowly; petals lift off and rise round it, then the lotus
                // itself breaks up and rises away in pieces.
                var foot = new Vector2(0f, -.7f * s); var jade = new Color(.5f, .9f, .66f);
                PaintSprite.Create(root, paintFlipMaterial, this, at, delay, .5f, 6, t =>
                {
                    float g = Back(Iv(0f, .22f, t));
                    var pose = P(foot + Vector2.up * (.25f * s * g), t * 25f, s * 1.5f * (.3f + .7f * g), Iv(0f, .04f, t) * (1f - Iv(.44f, .48f, t)), jade);
                    pose.sy = .6f; pose.z = .03f; return pose;
                });
                var lot = P(foot + Vector2.up * (.25f * s), .44f * 25f, s * 1.5f, 1f, jade); lot.sy = .6f; lot.z = .03f;
                PaintPieces.Create(root, this, at, delay + .44f / HitPace, 6, lot, Scatter.Rise, 1.8f * s, .5f, seed + 90);
                for (int i_ = 0; i_ < 8; i_++)
                {
                    int i = i_;   // a fresh copy per pass: lambdas below capture it
                    float born = Rn(.12f, .42f), x = Rn(-.8f, .8f), spin = Rn(-300f, 300f), sway = Rn(0f, 6f);
                    PaintSprite.Create(root, paintFlipMaterial, this, at, delay, 1f, 5, t =>
                    {
                        if (t < born) return P(Vector2.zero, 0f, 0f, 0f, jade);
                        float k = Iv(born, born + .5f, t);
                        return P(foot + new Vector2(x * s + Mathf.Sin(t * 6f + sway) * .2f * s, .3f * s + 2f * s * k), spin * k, s * .38f, Mathf.Sin(k * Mathf.PI), new Color(.85f, 1f, .7f));
                    });
                }
                break;
            }
            case "b01slash":
            {
                // B01 第七号空壳: the hollow executioner's painted sword cuts down the left diagonal
                // in one sudden swing; a red sword-qi crescent tears off the blade across the target
                // and bursts apart.
                var pivot = new Vector2(-.25f, 1.45f) * s;
                float L = 2.3f * s, a0 = 150f * Mathf.Deg2Rad, a1 = -62f * Mathf.Deg2Rad;
                PaintSprite.Create(root, paintFlipMaterial, this, at, delay, .5f, 0, t =>
                {
                    float sw = Ein(Iv(0f, .16f, t)), a = Mathf.Lerp(a0, a1, sw) + .08f * Eout(Iv(.16f, .35f, t));
                    var hd = new Vector2(Mathf.Cos(a), Mathf.Sin(a));
                    var pose = P(pivot + hd * (L * .5f), a * Mathf.Rad2Deg + 90f, L, Iv(0f, .03f, t) * (1f - Ein(Iv(.28f, .46f, t))), new Color(1f, .92f, .92f));
                    pose.z = .05f; return pose;
                });
                var cut = new Vector2(Mathf.Cos(-35f * Mathf.Deg2Rad), Mathf.Sin(-35f * Mathf.Deg2Rad));
                var qiTint = new Color(1f, .5f, .5f);
                PaintSprite.Create(root, paintFlipMaterial, this, at, delay + .12f / HitPace, .2f, 13, t =>
                {
                    float mv = Eout(Iv(0f, .14f, t));
                    var pose = P(-cut * (1.1f * s) + cut * (1.6f * s * mv), Mathf.Atan2(cut.y, cut.x) * Mathf.Rad2Deg + 180f, s * (2.2f + .8f * mv), Iv(0f, .02f, t), qiTint);
                    pose.sy = 1.3f; return pose;
                });
                var qiEnd = P(cut * (.5f * s), Mathf.Atan2(cut.y, cut.x) * Mathf.Rad2Deg + 180f, s * 3f, 1f, qiTint); qiEnd.sy = 1.3f;
                PaintPieces.Create(root, this, at, delay + .26f / HitPace, 13, qiEnd, Scatter.Burst, 2.4f * s, .4f, seed + 101);
                break;
            }
            case "b02straps":
            {
                // B02 背架收尸人: three rusted harness straps whip round the target on shrinking
                // orbits, twisting, until they cinch tight on it with a squeeze; then they snap and
                // fly apart.
                for (int k_ = 0; k_ < 3; k_++)
                {
                    int k = k_;
                    float a0 = k * 2.094f + Rn(-.3f, .3f), spin = (k % 2 == 0 ? 1f : -1f) * Rn(380f, 520f), sc = Rn(.95f, 1.15f), snap = .36f + .025f * k;
                    PaintSprite.Create(root, paintFlipMaterial, this, at, delay, snap + .04f, 28, t =>
                    {
                        float cin = Eout(Iv(0f, .26f, t)), sq = t > .26f ? Mathf.Exp(-(t - .26f) * 12f) * Mathf.Sin((t - .26f) * 44f) : 0f;
                        float a = a0 + 9f * t * (1f - .5f * cin);
                        var off = new Vector2(Mathf.Cos(a), Mathf.Sin(a) * .7f) * (s * (1.5f - 1.25f * cin)) + Vector2.up * (.1f * s);
                        var pose = P(off, spin * t * (1f - .7f * cin), s * sc * (1f - .1f * sq), Iv(0f, .04f, t) * (1f - Iv(snap, snap + .03f, t)), new Color(.82f, .7f, .62f));
                        pose.sy = 1f + .14f * sq; pose.mirror = k == 1; pose.z = .04f; return pose;
                    });
                    float aEnd = a0 + 9f * snap * .5f;
                    var tight = P(new Vector2(Mathf.Cos(aEnd), Mathf.Sin(aEnd) * .7f) * (.25f * s) + Vector2.up * (.1f * s), spin * snap * .3f, s * sc, 1f, new Color(.82f, .7f, .62f));
                    tight.mirror = k == 1; tight.z = .04f;
                    PaintPieces.Create(root, this, at, delay + snap / HitPace, 28, tight, Scatter.Burst, 2.6f * s, .42f, seed + 110 + k);
                }
                break;
            }
            case "b03wave":
            {
                // B03 溺钟海盗: two ghost waves rush in from the pirate's side one behind the other,
                // rearing up and tipping forward over the target as they come (never held still),
                // and each breaks apart into falling water and foam as it crashes.
                bool m = back.x > 0f;
                for (int k_ = 0; k_ < 2; k_++)
                {
                    int k = k_;
                    float born = .05f * k, sc = k == 0 ? 2.2f : 1.6f, crash = born + .34f, al0 = k == 0 ? 1f : .7f;
                    // Three turns at the hollow by the crash (user 2026-10-09: 转几圈看看).
                    float Curl(float t) => 3f * 6.283f * Mathf.Pow(Iv(born, crash, t), 1.4f);
                    var start = back * (2.4f * s) + Vector2.up * ((.3f + .35f * k) * s);
                    var end = new Vector2((m ? .25f : -.25f) * k * s, (.25f + .25f * k) * s);
                    float Roll(float t) => (m ? 1f : -1f) * (-10f * (1f - Eout(Iv(born, crash, t))) + 34f * Ein(Iv(born + .1f, crash + .02f, t)));
                    PaintSprite.Create(root, paintFlipMaterial, this, at, delay, crash + .03f, 27, t =>
                    {
                        float mv = Eout(Iv(born, crash, t));
                        var pose = P(Vector2.Lerp(start, end, mv) + Vector2.down * (.4f * s * Ein(Iv(born + .1f, crash, t))), Roll(t), s * sc * (.4f + .6f * mv), al0 * Iv(born, born + .03f, t) * (1f - Iv(crash, crash + .03f, t)), Color.white);
                        pose.mirror = m; pose.z = .05f - .01f * k; pose.curl = Curl(t); return pose;
                    });
                    var crest = P(end + Vector2.down * (.4f * s), Roll(crash), s * sc, al0, Color.white); crest.mirror = m; crest.z = .05f - .01f * k; crest.curl = Curl(crash);
                    PaintPieces.Create(root, this, at, delay + crash / HitPace, 27, crest, Scatter.Burst, 2f * s, .45f, seed + 120 + k);
                }
                PaintSprite.Create(root, paintFlipMaterial, this, at, delay + .2f / HitPace, .7f, 7, t =>
                {
                    var pose = P(new Vector2(0f, -.65f * s), 0f, s * (1.2f + 1.5f * Eout(Iv(0f, .45f, t))), .5f * (1f - Ein(Iv(.12f, .6f, t))), new Color(.8f, 1f, 1f));
                    pose.sy = .5f; return pose;
                });
                break;
            }
            case "b03bell":
            {
                // B03 溺钟海盗 heavy: the drowned bell drops out of the sky onto the target and
                // tolls - it lands with a squash and swings; water surges out either side, rolling
                // outward and breaking apart at once; then the bell lifts away into the mist.
                PaintSprite.Create(root, paintFlipMaterial, this, at, delay, .75f, 26, t =>
                {
                    float dn = Ein(Iv(0f, .2f, t)), up = Ein(Iv(.48f, .72f, t)), dt = t - .2f;
                    float swing = dt > 0f ? 14f * Mathf.Sin(dt * 18f) * Mathf.Exp(-dt * 5f) : 0f;
                    float sq = dt > 0f ? Mathf.Exp(-dt * 16f) : 0f;
                    var off = Vector2.Lerp(new Vector2(0f, 4f * s), new Vector2(0f, .45f * s), dn) + Vector2.up * (1.6f * s * up);
                    var pose = P(off, swing, s * 1.7f * (1f + .1f * sq), Iv(0f, .03f, t) * (1f - Ein(Iv(.5f, .74f, t))), Color.white);
                    pose.sy = 1f - .14f * sq; pose.z = .05f; return pose;
                });
                Surge(new Vector2(0f, -.45f * s), .2f, new Color(.85f, 1f, 1f), 130);
                PaintSprite.Create(root, paintFlipMaterial, this, at, delay + .3f / HitPace, .8f, 10, t =>
                    P(new Vector2(0f, .3f * s + .6f * s * Eout(Iv(0f, .7f, t))), 0f, s * (1.2f + 1.2f * Eout(Iv(0f, .6f, t))), .45f * Iv(0f, .08f, t) * (1f - Ein(Iv(.25f, .75f, t))), new Color(.55f, 1f, .85f)));
                break;
            }
            case "b04quill":
            {
                // B04 铜笔伪造者: the giant copper pen nib writes a forged line across the target
                // in three quick strokes, stabs down, and a violet ink splash with gold forged
                // script bursts out, sags and flies apart.
                Vector2[] path = { new Vector2(-1.1f, .9f), new Vector2(.2f, .3f), new Vector2(-.4f, .1f), new Vector2(1f, -.3f), new Vector2(0f, .15f) };
                PaintSprite.Create(root, paintFlipMaterial, this, at, delay, .46f, 33, t =>
                {
                    float w = Iv(0f, .2f, t) * 3f, st = Ein(Iv(.2f, .25f, t));
                    int seg = Mathf.Min(2, (int)w); float f = Mathf.Clamp01(w - seg);
                    var tip = Vector2.Lerp(path[seg], path[seg + 1], f) * s;
                    if (t >= .2f) tip = Vector2.Lerp(path[3] * s, path[4] * s, st);
                    float lift = st > 0f ? 0f : .25f;
                    var pose = P(tip + Vector2.up * (.95f * s + lift * s * Mathf.Sin(w * Mathf.PI)), -12f + 6f * Mathf.Sin(t * 30f), s * 1.9f, Iv(0f, .04f, t) * (1f - Ein(Iv(.3f, .46f, t))), Color.white);
                    pose.z = .06f; return pose;
                });
                PaintSprite.Create(root, paintFlipMaterial, this, at, delay + .25f / HitPace, .3f, 31, t =>
                {
                    float pop = Back(Iv(0f, .12f, t)), sag = Ein(Iv(.12f, .3f, t));
                    var pose = P(new Vector2(0f, .05f * s - .2f * s * sag), t * 30f, s * (.4f + 1.7f * pop), Iv(0f, .02f, t) * (1f - Iv(.24f, .27f, t)), Color.white);
                    pose.sy = 1f + .12f * sag; pose.z = .03f; return pose;
                });
                var ink = P(new Vector2(0f, -.15f * s), 7.5f, s * 2.1f, 1f, Color.white); ink.sy = 1.1f; ink.z = .03f;
                PaintPieces.Create(root, this, at, delay + .5f / HitPace, 31, ink, Scatter.Burst, 2.4f * s, .45f, seed + 140);
                break;
            }
            case "b05needles":
            {
                // B05 赤丝裁衣人: three volleys of silver needles trailing crimson thread shoot in from
                // her side one after another, each from a slightly different line; each sticks with
                // a quiver and at once breaks apart into glinting pieces.
                bool m = dir.x < 0f;
                float ang = Mathf.Atan2(dir.y, dir.x) * Mathf.Rad2Deg;
                var nrm = new Vector2(-dir.y, dir.x);
                for (int k_ = 0; k_ < 3; k_++)
                {
                    int k = k_;
                    float born = .05f * k, hit = born + .12f, tilt = (k - 1) * 9f, sc = k == 1 ? 1.5f : 1.2f;
                    var lateral = nrm * ((k - 1) * .35f * s);
                    var start = back * (2.6f * s) + lateral * 2f;
                    var stuck = -dir * (.45f * s) + lateral;
                    PaintSprite.Create(root, paintFlipMaterial, this, at, delay, hit + .07f, 29, t =>
                    {
                        float mv = Ein(Iv(born, hit, t)), j = t > hit ? Mathf.Sin((t - hit) * 70f) * Mathf.Exp(-(t - hit) * 20f) : 0f;
                        var pose = P(Vector2.Lerp(start, stuck, mv) + dir * (.08f * s * j), (m ? ang - 180f : ang) + tilt + 4f * j, s * sc, Iv(born, born + .03f, t) * (1f - Iv(hit + .05f, hit + .07f, t)), Color.white);
                        pose.mirror = m; pose.z = .05f; return pose;
                    });
                    var at0 = P(stuck, (m ? ang - 180f : ang) + tilt, s * sc, 1f, Color.white); at0.mirror = m; at0.z = .05f;
                    PaintPieces.Create(root, this, at, delay + (hit + .05f) / HitPace, 29, at0, Scatter.Burst, 1.8f * s, .38f, seed + 145 + k);
                }
                break;
            }
            case "b05threads":
            {
                // B05 赤丝裁衣人 silk bind: a quick needle volley that breaks on contact, then a web of
                // crimson thread closes in round the target, turning, pulls tight with a pulse, and
                // snaps apart.
                bool m = dir.x < 0f;
                float ang = Mathf.Atan2(dir.y, dir.x) * Mathf.Rad2Deg;
                var start = back * (2.6f * s);
                PaintSprite.Create(root, paintFlipMaterial, this, at, delay, .17f, 29, t =>
                {
                    float mv = Ein(Iv(0f, .12f, t));
                    var pose = P(Vector2.Lerp(start, -dir * (.4f * s), mv), m ? ang - 180f : ang, s * 1.4f, Iv(0f, .03f, t) * (1f - Iv(.14f, .17f, t)), Color.white);
                    pose.mirror = m; pose.z = .05f; return pose;
                });
                var vol = P(-dir * (.4f * s), m ? ang - 180f : ang, s * 1.4f, 1f, Color.white); vol.mirror = m; vol.z = .05f;
                PaintPieces.Create(root, this, at, delay + .14f / HitPace, 29, vol, Scatter.Burst, 1.6f * s, .35f, seed + 149);
                PaintSprite.Create(root, paintFlipMaterial, this, at, delay + .1f / HitPace, .48f, 30, t =>
                {
                    float cin = Eout(Iv(0f, .26f, t)), pulse = t > .26f ? Mathf.Exp(-(t - .26f) * 9f) * Mathf.Sin((t - .26f) * 36f) : 0f;
                    var pose = P(new Vector2(0f, .1f * s), 40f * (1f - cin) + 30f * t, s * (2.5f - 1.1f * cin) * (1f - .06f * pulse), Iv(0f, .05f, t) * (1f - Iv(.4f, .43f, t)), new Color(.85f, .7f, .72f));
                    pose.z = .04f; return pose;
                });
                var web = P(new Vector2(0f, .1f * s), 30f * .4f, s * 1.4f, 1f, new Color(.85f, .7f, .72f)); web.z = .04f;
                PaintPieces.Create(root, this, at, delay + .5f / HitPace, 30, web, Scatter.Swirl, 1.8f * s, .5f, seed + 150);
                break;
            }
            case "b06anchor":
            {
                // B06 无灯押船人: a huge black anchor swings down on its chain from high above like a
                // pendulum, slams onto the target with a squash; cold water surges out either side,
                // rolling outward and breaking apart at once; then the anchor is hauled back up.
                float swingSide = back.x >= 0f ? 1f : -1f;
                var pivot = new Vector2(0f, 4.6f * s); float rope = 4.2f * s;
                PaintSprite.Create(root, paintFlipMaterial, this, at, delay, .75f, 32, t =>
                {
                    float sw = Ein(Iv(0f, .22f, t)), dt = t - .22f, up = Ein(Iv(.45f, .7f, t));
                    float a = (1f - sw) * 70f * swingSide + (dt > 0f ? -8f * swingSide * Mathf.Sin(dt * 14f) * Mathf.Exp(-dt * 6f) : 0f);
                    float ar = (a - 90f) * Mathf.Deg2Rad;
                    var off = pivot + new Vector2(Mathf.Cos(ar), Mathf.Sin(ar)) * (rope * (1f - .4f * up));
                    float sq = dt > 0f ? Mathf.Exp(-dt * 16f) : 0f;
                    var pose = P(off, a, s * 1.9f * (1f + .08f * sq), Iv(0f, .03f, t) * (1f - Ein(Iv(.5f, .74f, t))), Color.white);
                    pose.sy = 1f - .12f * sq; pose.z = .05f; return pose;
                });
                Surge(new Vector2(0f, -.5f * s), .22f, new Color(.7f, .85f, 1f), 160);
                PaintSprite.Create(root, paintFlipMaterial, this, at, delay + .22f / HitPace, .75f, 8, t =>
                {
                    var pose = P(new Vector2(0f, -.7f * s), 0f, s * (1.2f + 1.6f * Eout(Iv(0f, .45f, t))), .5f * (1f - Ein(Iv(.12f, .6f, t))), new Color(.6f, .68f, .8f));
                    pose.sy = .5f; return pose;
                });
                break;
            }
            case "b07knock":
            {
                // B07 金囊蛙 knock: the golden-sac frog's electric shock - the painted shockwave pops
                // open on the target, flickering and jerking round like live current, a second
                // smaller burst crackles over it, and both shatter into sparks.
                for (int k_ = 0; k_ < 2; k_++)
                {
                    int k = k_;
                    float born = .06f * k, brk = born + .2f, sc = k == 0 ? 1.8f : 1.2f, r0 = k * 37f;
                    PaintSprite.Create(root, paintFlipMaterial, this, at, delay, brk + .03f, 34, t =>
                    {
                        float g = Back(Iv(born, born + .08f, t));
                        float jerk = Mathf.Floor(t * 22f), flick = .65f + .35f * Mathf.Abs(Mathf.Sin(jerk * 2.7f + k));
                        var pose = P(new Vector2(0f, .1f * s), r0 + 13f * Mathf.Sin(jerk * 1.9f + k * 3f), s * sc * (.3f + .7f * g) * (.95f + .1f * flick), .75f * flick * Iv(born, born + .02f, t) * (1f - Iv(brk, brk + .03f, t)), new Color(.8f, .8f, .55f));
                        pose.z = .04f; return pose;
                    });
                    var end = P(new Vector2(0f, .1f * s), r0, s * sc, .75f, new Color(.8f, .8f, .55f)); end.z = .04f;
                    PaintPieces.Create(root, this, at, delay + brk / HitPace, 34, end, Scatter.Burst, 2.6f * s, .35f, seed + 170 + k);
                }
                break;
            }
            case "b07spit":
            {
                // B07 金囊蛙 spittle: a sickly yellow-green venom glob arcs out of its sac, wobbling,
                // bursts on the target into a splash that sags and breaks apart, toxic mist rising.
                var start = back * (2.4f * s) + Vector2.up * (.4f * s);
                var bile = new Color(.85f, .92f, .5f);
                PaintSprite.Create(root, paintFlipMaterial, this, at, delay, .2f, 18, t =>
                {
                    float mv = Iv(0f, .18f, t);
                    var off = Vector2.Lerp(start, new Vector2(0f, .1f * s), mv) + Vector2.up * (1.1f * s * mv * (1f - mv));
                    var vel = (new Vector2(0f, .1f * s) - start) + Vector2.up * (1.1f * s * (1f - 2f * mv));
                    var pose = P(off, Mathf.Atan2(vel.y, vel.x) * Mathf.Rad2Deg - 45f, s * (.9f + .4f * mv), Iv(0f, .03f, t) * (1f - Iv(.17f, .2f, t)), bile);
                    pose.sy = 1f + .12f * Mathf.Sin(t * 50f); return pose;
                });
                PaintSprite.Create(root, paintFlipMaterial, this, at, delay + .18f / HitPace, .25f, 19, t =>
                {
                    float pop = Back(Iv(0f, .1f, t));
                    var pose = P(new Vector2(0f, .05f * s), t * 40f, s * (.5f + 1.4f * pop), Iv(0f, .03f, t) * (1f - Iv(.2f, .23f, t)), bile);
                    pose.z = .04f; return pose;
                });
                var sp = P(new Vector2(0f, .05f * s), 8f, s * 1.9f, 1f, bile); sp.z = .04f;
                PaintPieces.Create(root, this, at, delay + .38f / HitPace, 19, sp, Scatter.Burst, 2f * s, .45f, seed + 175);
                PaintSprite.Create(root, paintFlipMaterial, this, at, delay + .22f / HitPace, .85f, 7, t =>
                    P(new Vector2(0f, -.2f * s + .7f * s * Eout(Iv(0f, .7f, t))), t * 25f, s * (1f + 1.2f * Eout(Iv(0f, .5f, t))), .45f * Iv(0f, .08f, t) * (1f - Ein(Iv(.3f, .8f, t))), new Color(.75f, 1f, .45f)));
                break;
            }
            case "b08stab":
            {
                // B08 镜像分身 true stab: a cracked magic mirror flashes up between them; the crystal
                // rapier thrusts out through it straight at the target - the mirror shatters behind
                // it - and the blade runs the target through with a jolt, then breaks into glints.
                bool m = dir.x < 0f;
                float ang = Mathf.Atan2(dir.y, dir.x) * Mathf.Rad2Deg;
                var mirrorAt = back * (1.3f * s) + Vector2.up * (.35f * s);
                PaintSprite.Create(root, paintFlipMaterial, this, at, delay, .19f, 35, t =>
                {
                    float g = Back(Iv(0f, .1f, t)), shake = t > .12f ? Mathf.Sin(t * 90f) * 2f : 0f;
                    var pose = P(mirrorAt, shake, s * 1.5f * (.3f + .7f * g), Iv(0f, .03f, t) * (1f - Iv(.16f, .19f, t)), new Color(.85f, .85f, .92f));
                    pose.z = .02f; return pose;
                });
                var mir = P(mirrorAt, 0f, s * 1.5f, 1f, new Color(.85f, .85f, .92f)); mir.z = .02f;
                PaintPieces.Create(root, this, at, delay + .16f / HitPace, 35, mir, Scatter.Burst, 2.2f * s, .45f, seed + 180);
                PaintSprite.Create(root, paintFlipMaterial, this, at, delay + .12f / HitPace, .24f, 36, t =>
                {
                    float mv = Ein(Iv(0f, .08f, t)), j = t > .08f ? Mathf.Sin((t - .08f) * 80f) * Mathf.Exp(-(t - .08f) * 18f) : 0f;
                    var tipAt = Vector2.Lerp(mirrorAt, dir * (.35f * s), mv) + dir * (.1f * s * j);
                    var pose = P(tipAt - dir * (1.1f * s), m ? ang - 180f : ang, s * 2.4f, Iv(0f, .02f, t) * (1f - Iv(.2f, .24f, t)), Color.white);
                    pose.mirror = m; pose.z = .05f; return pose;
                });
                var bl = P(dir * (.35f * s) - dir * (1.1f * s), m ? ang - 180f : ang, s * 2.4f, 1f, Color.white); bl.mirror = m; bl.z = .05f;
                PaintPieces.Create(root, this, at, delay + .32f / HitPace, 36, bl, Scatter.Burst, 1.8f * s, .4f, seed + 181);
                break;
            }
            case "b08echo":
            {
                // B08 镜像分身 echo strike: a ghostly copy of the rapier, half transparent, lunges at
                // the target and shatters on it.
                bool m = dir.x < 0f;
                float ang = Mathf.Atan2(dir.y, dir.x) * Mathf.Rad2Deg;
                var start = back * (2.2f * s);
                var ghost = new Color(.75f, .82f, 1f);
                PaintSprite.Create(root, paintFlipMaterial, this, at, delay, .22f, 36, t =>
                {
                    float mv = Ein(Iv(0f, .12f, t));
                    var pose = P(Vector2.Lerp(start, dir * (.3f * s), mv) - dir * (.9f * s), m ? ang - 180f : ang, s * 1.9f, .7f * Iv(0f, .03f, t) * (1f - Iv(.18f, .22f, t)), ghost);
                    pose.mirror = m; pose.z = .05f; return pose;
                });
                var bl = P(dir * (.3f * s) - dir * (.9f * s), m ? ang - 180f : ang, s * 1.9f, .7f, ghost); bl.mirror = m; bl.z = .05f;
                PaintPieces.Create(root, this, at, delay + .18f / HitPace, 36, bl, Scatter.Burst, 2.2f * s, .4f, seed + 185);
                break;
            }
            case "b09rend":
            {
                // B09 铠虎 rend: three burning claw tears rake down across the target from upper side
                // to lower side, growing along the rake, and break up at once into rising flames.
                bool m = (seed & 1) == 1;
                float sx = m ? -1f : 1f;
                PaintSprite.Create(root, paintFlipMaterial, this, at, delay, .2f, 37, t =>
                {
                    float mv = Eout(Iv(0f, .12f, t));
                    var off = Vector2.Lerp(new Vector2(.8f * sx, .8f) * s, new Vector2(-.1f * sx, -.05f) * s, mv);
                    var pose = P(off, 0f, s * (1f + 1.1f * mv), Iv(0f, .02f, t) * (1f - Iv(.17f, .2f, t)), Color.white);
                    pose.mirror = m; pose.z = .05f; return pose;
                });
                var cl = P(new Vector2(-.1f * sx, -.05f) * s, 0f, s * 2.1f, 1f, Color.white); cl.mirror = m; cl.z = .05f;
                PaintPieces.Create(root, this, at, delay + .17f / HitPace, 37, cl, Scatter.Rise, 2f * s, .5f, seed + 190);
                FireBurst(new Vector2(0f, -.2f * s), 1.5f * s, delay + .12f / HitPace);
                break;
            }
            case "b10veil":
            {
                // B10 换寿恶魔 veil: crimson demon wings snap open behind the target and beat hard
                // twice - narrowing and lifting on each downstroke, never held still - then tear
                // apart into swirling pieces and drifting petals.
                const float Tear = .34f;
                float Span(float t) => Mathf.Max(.15f, Back(Iv(0f, .12f, t)) * (1f - .38f * Mathf.Max(0f, Mathf.Sin(Iv(.12f, Tear, t) * Mathf.PI * 2f))));
                PaintSprite.Create(root, paintFlipMaterial, this, at, delay, Tear + .03f, 38, t =>
                {
                    float w = Span(t), lift = Mathf.Max(0f, Mathf.Sin(Iv(.12f, Tear, t) * Mathf.PI * 2f));
                    var pose = P(new Vector2(0f, .35f * s + .25f * s * lift), Mathf.Sin(t * 18f) * 2f, s * 2.6f * w, Iv(0f, .03f, t) * (1f - Iv(Tear, Tear + .03f, t)), new Color(.9f, .82f, .85f));
                    pose.sy = Mathf.Min(3f, (.8f + .2f * Iv(0f, .12f, t)) / w * (1f + .12f * lift)); pose.z = .02f; return pose;
                });
                var wg = P(new Vector2(0f, .35f * s), 0f, s * 2.6f, 1f, new Color(.9f, .82f, .85f)); wg.z = .02f;
                PaintPieces.Create(root, this, at, delay + Tear / HitPace, 38, wg, Scatter.Swirl, 1.8f * s, .55f, seed + 200);
                var rose = new Color(1f, .3f, .42f);
                for (int i_ = 0; i_ < 10; i_++)
                {
                    int i = i_;
                    float a0 = Rn(0f, 6.283f), born = Rn(.15f, .5f), dist = Rn(1f, 2f), spin = Rn(-400f, 400f);
                    PaintSprite.Create(root, paintFlipMaterial, this, at, delay, 1.1f, 5, t =>
                    {
                        if (t < born) return P(Vector2.zero, 0f, 0f, 0f, rose);
                        float k = Iv(born, born + .55f, t);
                        var off = new Vector2(Mathf.Cos(a0), Mathf.Sin(a0) * .7f) * (s * (.4f + dist * Eout(k))) + Vector2.down * (.9f * s * k * k);
                        return P(off, spin * k, s * .38f, Iv(born, born + .04f, t) * (1f - Ein(Iv(.4f, 1f, k))), rose);
                    });
                }
                break;
            }
            case "crimsonmend":
            {
                // B10's vessel feeding it life: small crimson wings fold round the ally, pulse, and
                // rise away in pieces while petals and motes drift up.
                PaintSprite.Create(root, paintFlipMaterial, this, at, delay, .33f, 38, t =>
                {
                    float fold = Eout(Iv(0f, .2f, t)), beat = Mathf.Max(0f, Mathf.Sin(t * 22f));
                    var pose = P(new Vector2(0f, .3f * s + .1f * s * beat), 0f, s * (1.8f - .55f * fold) * (1f - .15f * beat), .8f * Iv(0f, .04f, t) * (1f - Iv(.3f, .33f, t)), new Color(.9f, .7f, .76f));
                    pose.sy = 1f + .15f * beat; pose.z = .02f; return pose;
                });
                var wg = P(new Vector2(0f, .3f * s), 0f, s * 1.25f, .8f, new Color(.9f, .7f, .76f)); wg.z = .02f;
                PaintPieces.Create(root, this, at, delay + .3f / HitPace, 38, wg, Scatter.Rise, 1.6f * s, .5f, seed + 210);
                for (int i_ = 0; i_ < 8; i_++)
                {
                    int i = i_;
                    float born = Rn(.1f, .45f), x = Rn(-.8f, .8f), spin = Rn(-300f, 300f);
                    PaintSprite.Create(root, paintFlipMaterial, this, at, delay, 1f, 5, t =>
                    {
                        if (t < born) return P(Vector2.zero, 0f, 0f, 0f, Color.white);
                        float k = Iv(born, born + .5f, t);
                        return P(new Vector2(x * s + Mathf.Sin(t * 6f + i) * .2f * s, -.3f * s + 2f * s * k), spin * k, s * .34f, Mathf.Sin(k * Mathf.PI), new Color(1f, .5f, .6f));
                    });
                }
                break;
            }
        }
    }

    enum Scatter { Burst, Rise, Swirl }

    /// A painted prop breaking apart instead of fading as one picture (2026-10-09, user: 这几个
    /// 东西都要动起来，散开或者怎样，不能一整块过来): the cell is cut into 6x6 overlapping soft
    /// tiles with ragged edges (SpectaclePieces shader); from `delay` each tile flies off on its
    /// own - bursting outward, rising like flame tongues, or swirling out - turning, shrinking
    /// and eroding into wisps. `pose` is where the whole prop stood when it broke.
    sealed class PaintPieces : MonoBehaviour
    {
        const int N = 6;
        SpellSpectacle20260926 owner; Mesh mesh;
        readonly List<Vector3> vs = new List<Vector3>(); readonly List<Color> cs = new List<Color>();
        readonly List<Vector2> u0 = new List<Vector2>(), u1 = new List<Vector2>(); readonly List<Vector4> u2 = new List<Vector4>();
        readonly List<int> tris = new List<int>();
        Vector3 at; float delay, age, life, speed; Pose2 pose; Scatter mode; float[] jit;

        public static void Create(Transform parent, SpellSpectacle20260926 owner, Vector3 at, float delay, int cell, Pose2 pose, Scatter mode, float speed, float life, int seed)
        {
            var tex = cell >= 200 ? owner.paintAtlas4 : cell >= 32 ? owner.paintAtlas3 : cell >= 16 ? owner.paintAtlas2 : owner.paintAtlas;
            if (!owner.piecesMaterial || !tex) return;
            int c = cell >= 200 ? cell - 200 : cell % 16;
            var go = new GameObject("SpectaclePaintPieces");
            go.transform.SetParent(parent, false);
            var p = go.AddComponent<PaintPieces>();
            p.mesh = new Mesh { name = "PaintPieces" }; p.mesh.MarkDynamic();
            go.AddComponent<MeshFilter>().sharedMesh = p.mesh;
            var view = go.AddComponent<MeshRenderer>(); view.sharedMaterial = owner.piecesMaterial;
            view.shadowCastingMode = UnityEngine.Rendering.ShadowCastingMode.Off; view.receiveShadows = false;
            var block = new MaterialPropertyBlock();
            block.SetTexture("_MainTex", tex);
            block.SetVector("_CellRect", new Vector4((c % 4) * .25f, 1f - (c / 4 + 1) * .25f, .25f, .25f));
            block.SetFloat("_Bright", cell >= 16 ? .9f : 1.08f);
            block.SetFloat("_Curl", pose.curl); block.SetVector("_CurlC", CurlCentre(cell));
            view.SetPropertyBlock(block);
            p.owner = owner; p.at = at; p.delay = delay; p.pose = pose; p.mode = mode; p.speed = speed; p.life = life;
            var rng = new System.Random(seed); p.jit = new float[N * N * 4];
            for (int i = 0; i < p.jit.Length; i++) p.jit[i] = (float)rng.NextDouble();
            owner.live++;
        }

        void LateUpdate()
        {
            age += Time.deltaTime;
            float k = age - delay;
            if (k > 0f) k *= HitPace;
            if (k > life + .08f) { Destroy(gameObject); return; }
            mesh.Clear();
            var cam = Camera.main;
            if (k < 0f || !cam) return;
            Vector3 R = cam.transform.right, U = cam.transform.up, F = cam.transform.forward;
            float s = pose.scale, sy = pose.sy > 0f ? pose.sy : 1f, mir = pose.mirror ? -1f : 1f, roll = pose.roll * Mathf.Deg2Rad;
            vs.Clear(); cs.Clear(); u0.Clear(); u1.Clear(); u2.Clear(); tris.Clear();
            const float Tile = 1f / N, Ext = Tile * 1.6f;
            for (int iy = 0; iy < N; iy++)
                for (int ix = 0; ix < N; ix++)
                {
                    int i = iy * N + ix;
                    float r0 = jit[i * 4], r1 = jit[i * 4 + 1], r2 = jit[i * 4 + 2], r3 = jit[i * 4 + 3];
                    var lc = new Vector2((ix + .5f) * Tile, (iy + .5f) * Tile);
                    var o = Rot2(new Vector2((lc.x - .5f) * mir, (lc.y - .5f) * sy) * s, roll);
                    float kk = Mathf.Max(0f, k - r3 * .05f), u = kk / life;
                    var dir = o.sqrMagnitude > 1e-6f ? o.normalized : new Vector2(r0 - .5f, r1 - .5f).normalized;
                    Vector2 d; float spin;
                    switch (mode)
                    {
                        case Scatter.Burst:
                            d = dir * (speed * (.6f + .8f * r0) * (1f - Mathf.Exp(-3f * kk)) / 3f) + Vector2.down * (.9f * speed * kk * kk);
                            spin = (r1 - .5f) * 7f * kk; break;
                        case Scatter.Rise:
                            d = Vector2.up * (speed * (.5f + .9f * r0) * kk) + dir * (.3f * speed * kk) + Vector2.right * (Mathf.Sin(kk * 10f + r2 * 6f) * .06f * s);
                            spin = (r1 - .5f) * 2.5f * kk; break;
                        default:
                        {
                            float ang = (3f + 2.5f * r0) * kk;
                            d = Rot2(o, ang) * (1f + speed * kk / Mathf.Max(.01f, s) * (.6f + .6f * r2)) - o + Vector2.down * (.4f * speed * kk * kk);
                            spin = ang; break;
                        }
                    }
                    var centre = pose.off + o + d;
                    float scl = 1f - .6f * Mathf.Clamp01(u * (.8f + .4f * r2));
                    float a = pose.alpha * (1f - Ein(Mathf.Clamp01(u * (.85f + .3f * r1)))) * Mathf.Clamp01(k / .03f);
                    if (a <= .003f) continue;
                    float rot = roll + spin, hx = Ext * .5f * s * scl, hy = Ext * .5f * s * sy * scl;
                    var ax = new Vector2(Mathf.Cos(rot), Mathf.Sin(rot)); var ay = new Vector2(-ax.y, ax.x);
                    int v0 = vs.Count;
                    for (int q = 0; q < 4; q++)
                    {
                        float qx = (q & 1) == 0 ? -1f : 1f, qy = q < 2 ? -1f : 1f;
                        var p2 = centre + ax * (qx * hx * mir) + ay * (qy * hy);
                        vs.Add(at + R * p2.x + U * p2.y - F * (.02f + pose.z));
                        cs.Add(new Color(pose.tint.r, pose.tint.g, pose.tint.b, a));
                        u0.Add(new Vector2(lc.x + qx * Ext * .5f, lc.y + qy * Ext * .5f));
                        u1.Add(new Vector2(qx, qy));
                        u2.Add(new Vector4(r0 * 7f + i * .13f, 0f, 0f, 0f));
                    }
                    tris.Add(v0); tris.Add(v0 + 2); tris.Add(v0 + 1); tris.Add(v0 + 2); tris.Add(v0 + 3); tris.Add(v0 + 1);
                }
            if (vs.Count == 0) return;
            mesh.SetVertices(vs); mesh.SetColors(cs); mesh.SetUVs(0, u0); mesh.SetUVs(1, u1); mesh.SetUVs(2, u2);
            mesh.SetTriangles(tris, 0);
            mesh.bounds = new Bounds(at, Vector3.one * Mathf.Max(1f, pose.scale) * 20f);
        }

        void OnDestroy() { if (owner) owner.live--; if (mesh) Destroy(mesh); }
    }

    sealed class TarotFlight : MonoBehaviour
    {
        const float Gather = .09f, BakedAngle = 38f;
        SpellSpectacle20260926 owner;
        Func<float, Vector3> course;
        float travel, delay, age, size, wobble;
        MeshRenderer surface; Mesh mesh; MaterialPropertyBlock block;
        static readonly int FrameID = Shader.PropertyToID("_Frame"), AlphaID = Shader.PropertyToID("_Alpha"), BrightID = Shader.PropertyToID("_Bright");

        public static void Create(Transform parent, Material material, SpellSpectacle20260926 owner, Func<float, Vector3> course, float travel, float delay, float size, int seed)
        {
            var go = new GameObject("SpectacleTarotFlight");
            go.transform.SetParent(parent, false);
            var f = go.AddComponent<TarotFlight>();
            f.owner = owner; f.course = course; f.travel = Mathf.Max(.12f, travel); f.delay = delay; f.size = size;
            f.wobble = ((seed * 37) % 11 - 5) * 1.5f;
            f.mesh = new Mesh { name = "TarotFlightQuad" };
            f.mesh.vertices = new[] { new Vector3(-.5f, -.5f, 0), new Vector3(.5f, -.5f, 0), new Vector3(-.5f, .5f, 0), new Vector3(.5f, .5f, 0) };
            f.mesh.uv = new[] { Vector2.zero, Vector2.right, Vector2.up, Vector2.one };
            f.mesh.triangles = new[] { 0, 2, 1, 2, 3, 1 };
            f.mesh.bounds = new Bounds(Vector3.zero, Vector3.one * 4f);
            go.AddComponent<MeshFilter>().sharedMesh = f.mesh;
            f.surface = go.AddComponent<MeshRenderer>(); f.surface.sharedMaterial = material;
            f.surface.shadowCastingMode = UnityEngine.Rendering.ShadowCastingMode.Off; f.surface.receiveShadows = false;
            f.surface.enabled = false;
            f.block = new MaterialPropertyBlock();
            owner.live++;
        }

        void LateUpdate()
        {
            age += Time.deltaTime;
            float t = age - delay;
            if (t > travel + .04f) { Destroy(gameObject); return; }
            var cam = Camera.main;
            if (t < 0f || !cam) { surface.enabled = false; return; }
            surface.enabled = true;
            float frame, roll = wobble, alpha = 1f;
            Vector3 pos;
            if (t < Gather)
            {
                frame = Mathf.Min(3f, Mathf.Floor(t / Gather * 4f));
                pos = course(0f);
            }
            else
            {
                float u = Mathf.Clamp01((t - Gather) / Mathf.Max(.05f, travel - Gather));
                frame = 4f + Mathf.Min(3f, Mathf.Floor(u * 3.4f));
                pos = course(Mathf.Min(t, travel));
                var a = cam.WorldToScreenPoint(course(Mathf.Min(t, travel)));
                var b = cam.WorldToScreenPoint(course(Mathf.Min(t + .02f, travel + .02f)));
                var v = new Vector2(b.x - a.x, b.y - a.y);
                if (v.sqrMagnitude > 1e-4f) roll = Mathf.Atan2(v.y, v.x) * Mathf.Rad2Deg - BakedAngle;
                alpha = 1f - Mathf.Clamp01((t - travel + .05f) / .09f);
            }
            transform.SetPositionAndRotation(pos, cam.transform.rotation * Quaternion.Euler(0f, 0f, roll));
            transform.localScale = Vector3.one * size;
            block.SetFloat(FrameID, frame); block.SetFloat(AlphaID, alpha); block.SetFloat(BrightID, 1.05f);
            surface.SetPropertyBlock(block);
        }

        void OnDestroy()
        {
            if (owner) owner.live--;
            if (mesh) Destroy(mesh);
        }
    }

    /// Hand-drawn 2D strokes (2026-10-08, user: 我要类似这样的效果 - the 2XKO concept sheets):
    /// filled shapes in the camera plane - crescents, teardrops, four-point stars, dots, ink
    /// smudges - coloured in three hard steps by the Ink shader, and redrawn with a different
    /// silhouette every beat (12 a second) like a flipbook. Nothing scales or fades as one
    /// picture: strokes overshoot, thin, split at the tips into drops, break into fragments,
    /// and the last beats are a few dots. Each kind is a short script over beats.
    /// Hand-drawn 2D strokes (2026-10-08, user: 我要类似这样的效果). Filled shapes in the camera
    /// plane, cel-banded by the Ink shader (four flat steps from a dark saturated outer band
    /// to a cream core, following the silhouette), with additive glows, sparkles, radial
    /// impact spikes, rings, flame tongues, bolts and flat smoke discs - the recipe of the
    /// user's reference short (yao_vs_ting: Skia vector + cel bands + bloom). Continuous time
    /// with eased envelopes; the hand feel comes from fbm wobble on widths and spines, not
    /// from stepping. Every kind is a short script over u = t / duration.
    sealed partial class Ink2D : MonoBehaviour
    {
        SpellSpectacle20260926 owner;
        Mesh mesh;
        readonly List<Vector3> vs = new List<Vector3>(); readonly List<Color> cs = new List<Color>();
        readonly List<Vector4> u0 = new List<Vector4>(), u1 = new List<Vector4>(), u2 = new List<Vector4>(), u3 = new List<Vector4>();
        readonly List<int> tris = new List<int>();
        Vector3 at, R, U; Vector2 dir; float size, delay, age, duration; string kind;
        Color outer, band2, band3, core, hot; float[] jit;
        float now;

        public static Ink2D Create(Transform parent, Material material, SpellSpectacle20260926 owner, Camera cam, Vector3 caster, Vector3 at, float size, float delay, int seed, string kind)
        {
            var go = new GameObject("SpectacleInk " + kind);
            go.transform.SetParent(parent, false);
            var k = go.AddComponent<Ink2D>();
            k.owner = owner; k.at = at; k.size = size; k.delay = delay; k.kind = kind;
            k.R = cam.transform.right; k.U = cam.transform.up;
            var d = at - caster;
            var d2 = new Vector2(Vector3.Dot(d, k.R), Vector3.Dot(d, k.U));
            k.dir = d2.sqrMagnitude > 1e-6f ? d2.normalized : Vector2.down;
            var rng = new System.Random(seed);
            k.jit = new float[64]; for (int i = 0; i < 64; i++) k.jit[i] = (float)rng.NextDouble();
            // Palettes as in the reference: FIRE = crimson / orange / amber / cream; the hero's
            // ROSE = deep violet / orchid / pink / cream.
            if (kind == "claw" || kind == "clawfx") { k.outer = Hex("A80F2A"); k.band2 = Hex("FF4D1A"); k.band3 = Hex("FFAA33"); k.core = Hex("FFF3CF"); k.hot = Hex("FFC447"); k.duration = .62f; }
            // A bright violet rim: the deep 4A1F9E read as a dark sticker over the target (ink14).
            // Core a pale pink, not white (ink17: the white centre left the colour only at the rim).
            // 错步穿行: violet / pink / gold, the card's own colours.
            else if (kind == "cut") { k.outer = Hex("7A2CFF"); k.band2 = Hex("FF58C8"); k.band3 = Hex("FFB22E"); k.core = Hex("FFF0C8"); k.hot = Hex("FFD9A0"); k.duration = .62f; }
            // 伪证烙印: hot wax and a branding iron - crimson / red / orange / pale amber.
            else if (kind == "seal") { k.outer = Hex("A3141F"); k.band2 = Hex("E0392B"); k.band3 = Hex("FF7A3A"); k.core = Hex("FFD8A8"); k.hot = Hex("FFB36B"); k.duration = .72f; }
            // 张冠李戴: two names, blue and orange, trading places (base palette = the blue one).
            else if (kind == "swap") { k.outer = Hex("1A4DFF"); k.band2 = Hex("46B8FF"); k.band3 = Hex("9AD8FF"); k.core = Hex("F4F1FF"); k.hot = Hex("CFE8FF"); k.duration = .8f; }
            // 双影: shadow violet - near-black violet rim, deep violet, lilac, a pale lavender core.
            else if (kind == "shadow") { k.outer = Hex("14062B"); k.band2 = Hex("3F1A8A"); k.band3 = Hex("6E36D6"); k.core = Hex("B88CFF"); k.hot = Hex("C99BFF"); k.duration = .62f; }
            // 反客为主: magenta silk and petals, gold sparks.
            else if (kind == "reverse") { k.outer = Hex("7A1060"); k.band2 = Hex("E0359E"); k.band3 = Hex("FF6FBE"); k.core = Hex("FFE3F2"); k.hot = Hex("FFC060"); k.duration = .72f; }
            // 无名宣告: a golden edict on violet.
            else if (kind == "edict") { k.outer = Hex("5A2CD0"); k.band2 = Hex("B07AFF"); k.band3 = Hex("FFCF6A"); k.core = Hex("FFF6DC"); k.hot = Hex("FFE08A"); k.duration = .82f; }
            // 荒谬归结: the rainbow finisher - gold body, pink and violet rims, rainbow filaments.
            // Enemies (batch 1): 钟卫 brass clock hand, 雾灵 cold fog / crimson, 猎犬 fire bite, 书记员 ink.
            else if (kind == "clock") { k.outer = Hex("8A2A10"); k.band2 = Hex("E0561A"); k.band3 = Hex("FFC23A"); k.core = Hex("FFF1D0"); k.hot = Hex("FFD98A"); k.duration = .7f; }
            else if (kind == "ghost") { k.outer = Hex("1F66C8"); k.band2 = Hex("2FC8FF"); k.band3 = Hex("9FE8FF"); k.core = Hex("F2FEFF"); k.hot = Hex("BFF6FF"); k.duration = .75f; }
            else if (kind == "ghostred") { k.outer = Hex("B0124A"); k.band2 = Hex("FF4F7A"); k.band3 = Hex("FF9AB6"); k.core = Hex("FFF0F4"); k.hot = Hex("FFC0CF"); k.duration = .75f; }
            else if (kind == "bite") { k.outer = Hex("C2200A"); k.band2 = Hex("FF5A14"); k.band3 = Hex("FFB03A"); k.core = Hex("FFF2C8"); k.hot = Hex("FFD35A"); k.duration = .7f; }
            else if (kind == "ink") { k.outer = Hex("08020F"); k.band2 = Hex("1E0838"); k.band3 = Hex("3A1270"); k.core = Hex("7A4AC0"); k.hot = Hex("FFD36A"); k.duration = .75f; }
            // Enemies (batch 2): 档案馆馆员 lightning, 记忆水蛭 violet drain, 时钟核心 teal hands, repair green.
            else if (kind == "bolt") { k.outer = Hex("1A4FB8"); k.band2 = Hex("2A9AFF"); k.band3 = Hex("9FD8FF"); k.core = Hex("F4FBFF"); k.hot = Hex("FFD27A"); k.duration = .7f; }
            else if (kind == "drain") { k.outer = Hex("4A1278"); k.band2 = Hex("B04CFF"); k.band3 = Hex("E58CFF"); k.core = Hex("FFE8FF"); k.hot = Hex("9FE8FF"); k.duration = .8f; }
            else if (kind == "pin") { k.outer = Hex("127A8A"); k.band2 = Hex("2EC8D8"); k.band3 = Hex("8AF0F0"); k.core = Hex("F0FFFF"); k.hot = Hex("FFD88A"); k.duration = .72f; }
            else if (kind == "silk") { k.outer = Hex("8A0A24"); k.band2 = Hex("E0284A"); k.band3 = Hex("FF8FA8"); k.core = Hex("FFF4F6"); k.hot = Hex("FFE6B0"); k.duration = .85f; }
            else if (kind == "sign") { k.outer = Hex("2A1404"); k.band2 = Hex("8A5212"); k.band3 = Hex("E8A82E"); k.core = Hex("FFF2C8"); k.hot = Hex("FFE08A"); k.duration = .8f; }
            else if (kind == "sovereign") { k.outer = Hex("4A2208"); k.band2 = Hex("B8661C"); k.band3 = Hex("F2B44A"); k.core = Hex("FFF4DC"); k.hot = Hex("5FE8D8"); k.duration = 1f; }
            else if (kind == "verdict") { k.outer = Hex("0E2A5A"); k.band2 = Hex("2F6FD0"); k.band3 = Hex("9CC8FF"); k.core = Hex("F4F8FF"); k.hot = Hex("FFD36A"); k.duration = .85f; }
            else if (kind == "chain") { k.outer = Hex("3A1206"); k.band2 = Hex("B8501A"); k.band3 = Hex("FF8A3A"); k.core = Hex("FFE0B0"); k.hot = Hex("FFC060"); k.duration = .85f; }
            else if (kind == "meteor") { k.outer = Hex("4A1A04"); k.band2 = Hex("E07A14"); k.band3 = Hex("FFB23A"); k.core = Hex("FFF4D0"); k.hot = Hex("FFE08A"); k.duration = .85f; }
            else if (kind == "toll") { k.outer = Hex("5A0A10"); k.band2 = Hex("D0262A"); k.band3 = Hex("FF7A3A"); k.core = Hex("FFF0D8"); k.hot = Hex("FFD35A"); k.duration = .95f; }
            else if (kind == "emerald" || kind == "emeraldfog" || kind == "emeraldburst") { k.outer = Hex("063A20"); k.band2 = Hex("16B85A"); k.band3 = Hex("6CFF9A"); k.core = Hex("F0FFE8"); k.hot = Hex("D8FF7A"); k.duration = .9f; }
            else if (kind == "angelintro") { k.outer = Hex("0A3A4A"); k.band2 = Hex("E8B84A"); k.band3 = Hex("FFE6A8"); k.core = Hex("FFFCF0"); k.hot = Hex("7AE8FF"); k.duration = AngelIntroSeconds * HitPace; }
            else if (kind == "nameseal") { k.outer = Hex("5A3A08"); k.band2 = Hex("D8A030"); k.band3 = Hex("FFE08A"); k.core = Hex("FFF8E0"); k.hot = Hex("5FE8D8"); k.duration = 1.2f; }
            else if (kind == "bronzeslam") { k.outer = Hex("3A2206"); k.band2 = Hex("B8761A"); k.band3 = Hex("F2B44A"); k.core = Hex("FFF4D8"); k.hot = Hex("5FE8D8"); k.duration = .9f; }
            else if (kind == "hellbreath") { k.outer = Hex("5A0A04"); k.band2 = Hex("E0360C"); k.band3 = Hex("FF8E24"); k.core = Hex("FFF0B8"); k.hot = Hex("FFD45A"); k.duration = .9f; }
            else if (kind == "geyser") { k.outer = Hex("3A2006"); k.band2 = Hex("B8761A"); k.band3 = Hex("F2B44A"); k.core = Hex("FFF4D8"); k.hot = Hex("FFD87A"); k.duration = .85f; }
            else if (kind == "salt") { k.outer = Hex("1A6A8A"); k.band2 = Hex("7AD8EA"); k.band3 = Hex("E8FFFF"); k.core = Hex("FFFFFF"); k.hot = Hex("FF9AD6"); k.duration = .85f; }
            else if (kind == "spit") { k.outer = Hex("064A2A"); k.band2 = Hex("1AB86A"); k.band3 = Hex("7AFFB8"); k.core = Hex("F0FFE8"); k.hot = Hex("E8FFD0"); k.duration = .9f; }
            else if (kind == "steel") { k.outer = Hex("0E2A5A"); k.band2 = Hex("2A6AB8"); k.band3 = Hex("8AD8FF"); k.core = Hex("FFFFFF"); k.hot = Hex("FFE08A"); k.duration = .7f; }
            else if (kind == "sonic") { k.outer = Hex("4A3006"); k.band2 = Hex("D8A01A"); k.band3 = Hex("FFE68A"); k.core = Hex("FFFBE8"); k.hot = Hex("6AF0D0"); k.duration = .8f; }
            else if (kind == "bonerake") { k.outer = Hex("0A3A3A"); k.band2 = Hex("1AB8A8"); k.band3 = Hex("7AF0D8"); k.core = Hex("F0FFFC"); k.hot = Hex("C8A0FF"); k.duration = .8f; }
            else if (kind == "ram") { k.outer = Hex("3A1206"); k.band2 = Hex("C8601A"); k.band3 = Hex("FFA040"); k.core = Hex("FFF0D0"); k.hot = Hex("4AD6B8"); k.duration = .85f; }
            else if (kind == "fist") { k.outer = Hex("4A0606"); k.band2 = Hex("E0300C"); k.band3 = Hex("FF8A2A"); k.core = Hex("FFF0C0"); k.hot = Hex("FFD24A"); k.duration = .9f; }
            else if (kind == "veil") { k.outer = Hex("5A0420"); k.band2 = Hex("D01A50"); k.band3 = Hex("FF7AA0"); k.core = Hex("FFF0F4"); k.hot = Hex("FFD8A0"); k.duration = .95f; }
            else if (kind == "bubbles") { k.outer = Hex("4A4206"); k.band2 = Hex("C8B81A"); k.band3 = Hex("FFF06A"); k.core = Hex("FFFFF0"); k.hot = Hex("FFFFFF"); k.duration = .9f; }
            else if (kind == "moonwind") { k.outer = Hex("1A1A5A"); k.band2 = Hex("4A6AD8"); k.band3 = Hex("A8C8FF"); k.core = Hex("FFFFFF"); k.hot = Hex("FFE08A"); k.duration = 1f; }
            else if (kind == "pounce") { k.outer = Hex("3A0A06"); k.band2 = Hex("D8501A"); k.band3 = Hex("FFA040"); k.core = Hex("FFF0D0"); k.hot = Hex("FFD06A"); k.duration = .8f; }
            else if (kind == "lotusmend") { k.outer = Hex("0A4A3A"); k.band2 = Hex("1AC89A"); k.band3 = Hex("8AF5C8"); k.core = Hex("FFFBE6"); k.hot = Hex("FFE08A"); k.duration = 1f; }
            else if (kind == "b01slash") { k.outer = Hex("4A0610"); k.band2 = Hex("C01A24"); k.band3 = Hex("FF6A6A"); k.core = Hex("FFF0F0"); k.hot = Hex("FFE0D0"); k.duration = .75f; }
            else if (kind == "b02straps") { k.outer = Hex("3A1404"); k.band2 = Hex("C8601A"); k.band3 = Hex("FFA040"); k.core = Hex("FFF0D0"); k.hot = Hex("FFC060"); k.duration = .9f; }
            else if (kind == "b03wave") { k.outer = Hex("063A4A"); k.band2 = Hex("1AA8B8"); k.band3 = Hex("7AF0F0"); k.core = Hex("F0FFFF"); k.hot = Hex("C8FFFF"); k.duration = .85f; }
            else if (kind == "b03bell") { k.outer = Hex("063A2A"); k.band2 = Hex("1AB88A"); k.band3 = Hex("6AFFC8"); k.core = Hex("F0FFF8"); k.hot = Hex("C8FFE8"); k.duration = 1f; }
            else if (kind == "b04quill") { k.outer = Hex("1E0838"); k.band2 = Hex("6A2AD0"); k.band3 = Hex("B07AFF"); k.core = Hex("F4E8FF"); k.hot = Hex("FFD36A"); k.duration = .9f; }
            else if (kind == "b05needles") { k.outer = Hex("4A0410"); k.band2 = Hex("D0142A"); k.band3 = Hex("FF5A6A"); k.core = Hex("FFF0F2"); k.hot = Hex("FFD0D8"); k.duration = .75f; }
            else if (kind == "b05threads") { k.outer = Hex("4A0410"); k.band2 = Hex("D0142A"); k.band3 = Hex("FF5A6A"); k.core = Hex("FFF0F2"); k.hot = Hex("FFD0D8"); k.duration = 1f; }
            else if (kind == "b06anchor") { k.outer = Hex("0A1A3A"); k.band2 = Hex("2A5AA0"); k.band3 = Hex("8AC8FF"); k.core = Hex("F4FAFF"); k.hot = Hex("DCEFFF"); k.duration = 1f; }
            else if (kind == "b07knock") { k.outer = Hex("3A3A04"); k.band2 = Hex("C8D81A"); k.band3 = Hex("F4FF6A"); k.core = Hex("FFFFF0"); k.hot = Hex("FFF08A"); k.duration = .8f; }
            else if (kind == "b07spit") { k.outer = Hex("2A3A06"); k.band2 = Hex("9AC81A"); k.band3 = Hex("D8FF6A"); k.core = Hex("F8FFE8"); k.hot = Hex("FFFFC0"); k.duration = .9f; }
            else if (kind == "b08stab") { k.outer = Hex("1A1A5A"); k.band2 = Hex("5A6AD8"); k.band3 = Hex("B8C8FF"); k.core = Hex("FFFFFF"); k.hot = Hex("E8D8FF"); k.duration = .85f; }
            else if (kind == "b08echo") { k.outer = Hex("1A1A5A"); k.band2 = Hex("5A6AD8"); k.band3 = Hex("B8C8FF"); k.core = Hex("FFFFFF"); k.hot = Hex("E8D8FF"); k.duration = .7f; }
            else if (kind == "b09rend") { k.outer = Hex("4A1004"); k.band2 = Hex("E0501A"); k.band3 = Hex("FFA040"); k.core = Hex("FFF0C8"); k.hot = Hex("FFD24A"); k.duration = .85f; }
            else if (kind == "b10veil") { k.outer = Hex("4A0418"); k.band2 = Hex("D01A4A"); k.band3 = Hex("FF7AA0"); k.core = Hex("FFF0F4"); k.hot = Hex("FFD8A0"); k.duration = 1f; }
            else if (kind == "crimsonmend") { k.outer = Hex("4A0418"); k.band2 = Hex("D03A6A"); k.band3 = Hex("FFB0C8"); k.core = Hex("FFF8FA"); k.hot = Hex("FFE0B0"); k.duration = 1f; }
            else if (kind == "mend") { k.outer = Hex("12886A"); k.band2 = Hex("1AC89A"); k.band3 = Hex("8AF5C8"); k.core = Hex("FFFBE6"); k.hot = Hex("FFE08A"); k.duration = 1f; }
            // 假面谕令: a pale cyan mask of light; 后手改写: water blue with a gold glint.
            else if (kind == "mask") { k.outer = Hex("1F6FD6"); k.band2 = Hex("3AD6E8"); k.band3 = Hex("BFF2FF"); k.core = Hex("F4FCFF"); k.hot = Hex("CFF4FF"); k.duration = .8f; }
            else if (kind == "rewrite") { k.outer = Hex("2A9FE0"); k.band2 = Hex("39C6FF"); k.band3 = Hex("8AE0FF"); k.core = Hex("F2FCFF"); k.hot = Hex("FFE7A0"); k.duration = 1f; }
            else if (kind == "finale") { k.outer = Hex("6A3CFF"); k.band2 = Hex("FF5FD0"); k.band3 = Hex("FFC23A"); k.core = Hex("FFF8E0"); k.hot = Hex("FFE39A"); k.duration = 1.05f; }
            else if (k.CardPalette(kind)) { }
            else { k.outer = Hex("9A2EF0"); k.band2 = Hex("D45CFF"); k.band3 = Hex("FF6AD0"); k.core = Hex("FFC4EE"); k.hot = Hex("F4B0FF"); k.duration = .62f; }
            k.mesh = new Mesh { name = "SpectacleInk" }; k.mesh.MarkDynamic();
            go.AddComponent<MeshFilter>().sharedMesh = k.mesh;
            var r = go.AddComponent<MeshRenderer>(); r.sharedMaterial = material;
            r.shadowCastingMode = UnityEngine.Rendering.ShadowCastingMode.Off; r.receiveShadows = false;
            owner.live++;
            return k;
        }

        /// An enemy hit (gets ImpactLayer). A gather follows the caster's hand (see Gather).
        public bool enemyHit;
        /// The hero's and the boss's chests in this ink's plane (the angel intro: where the chain
        /// and her gift land on the hero, where his gift sinks into Sevian).
        public Vector2 heroOff, bossOff;
        public Func<Vector3> follow;
        bool gather; float released = -1f;
        /// The caster still stands and acts; a gather whose actor is replaced or hidden before
        /// its contact lets go at once instead of hanging on for MaxGather (2026-10-10, the
        /// recorder's wave-replacement check found it still alive 1.6 s later).
        public Func<bool> stillActing;
        const float MaxGather = 3.4f;
        public static Ink2D CreateGather(Transform parent, Material material, SpellSpectacle20260926 owner, Camera cam, Func<Vector3> hand, float size, int seed, string paletteKind)
        {
            var at = hand();
            var k = Create(parent, material, owner, cam, at, at, size, 0f, seed, paletteKind);
            k.gather = true; k.follow = hand; k.gameObject.name = "SpectacleGather " + paletteKind;
            return k;
        }
        public void Release() { if (gather && released < 0f) released = age; }

        /// 翠毒漫天's poison bubbles lying round the hero's feet for the whole fight (2026-10-10,
        /// user: 地面要一直保持毒泡吧 - the fog lasts to the end of the battle and thickens every
        /// 3 s): more of them as the fog thickens, all throbbing at each tick; when it thins back
        /// (recover, the hero's cleanse) the extra ones pop. Lives until EndPool.
        bool pool; int poolLevel; float poolTick = -9f, poolEnd = -1f, poolShown;
        public bool PoolEnded => poolEnd >= 0f;

        /// Bubble i of the pool now: where it lies, its radius, opacity and how far it has popped.
        /// Each lives a few seconds - swells in, sits throbbing, pops - then comes back elsewhere.
        public void PoolBubble(int i, out Vector2 p, out float r, out float a, out float pop)
        {
            float t = age, s = size;
            float H(int x) => Mathf.Repeat(Mathf.Sin(x * 127.1f + 311.7f) * 43758.5453f, 1f);
            float show = Smooth(Inv(0f, .6f, t)) * (poolEnd >= 0f ? 1f - Inv(poolEnd, poolEnd + .5f, t) : 1f);
            float tick = 1f - Inv(0f, .45f, t - poolTick);
            float spread = Mathf.Min(1.5f, 1f + .06f * poolLevel);
            float vis = Mathf.Clamp01(poolShown - i) * show;
            float period = 3f + 3f * H(i * 7 + 1), phase = H(i * 7 + 2) * period;
            int cycle = Mathf.FloorToInt((t + phase) / period);
            float u = (t + phase) / period - cycle;
            int key = i * 131 + cycle * 17;
            p = new Vector2((H(key + 3) - .5f) * 2.4f * s * spread, (H(key + 4) - .5f) * .38f * s * spread);
            r = s * (.07f + .08f * H(key + 5)) * (1f + .2f * tick) * (1f + .06f * Mathf.Sin(t * 6f + i * 1.7f));
            float grow = Smooth(Inv(0f, .08f, u));
            pop = Inv(.93f, 1f, u);
            r *= .5f + .5f * grow;
            a = vis * grow * (1f - pop);
            if (vis <= .01f) pop = 0f;
        }
        public static Ink2D CreatePool(Transform parent, Material material, SpellSpectacle20260926 owner, Camera cam, Vector3 feet, float size, int seed)
        {
            var k = Create(parent, material, owner, cam, feet + Vector3.up, feet, size, 0f, seed, "emeraldfog");
            k.pool = true; k.gameObject.name = "SpectaclePoisonPool";
            return k;
        }
        public void SetPoolLevel(int level) { if (level != poolLevel) { poolTick = age; poolLevel = level; } }
        public void EndPool() { if (pool && poolEnd < 0f) poolEnd = age; }

        static Color Hex(string h) { ColorUtility.TryParseHtmlString("#" + h, out var c); return c; }

        /// Seconds of afterglow past the script's own end (2026-10-09, user: 每个法术持续时间都要
        /// 略长一点点 … 前一个法术消散时，后一个法术已经到了): the hit itself keeps its
        /// approved timing; only slow motes and a fading glow stay on, long enough to still be
        /// dissolving when the next spell lands (the hero and the enemy alternate ~1-1.5 s).
        float Linger => kind == "finale" ? .95f : kind == "rewrite" ? .8f : kind == "mirror" || kind == "tempotick" ? .25f : .75f;
        const float Pace = HitPace;

        void LateUpdate()
        {
            age += Time.deltaTime;
            if (mark) { MarkFrame(); return; }
            // A non-gather ink whose owner says it is over (a skipped angel intro) goes at once.
            if (!gather && stillActing != null && !stillActing()) { Destroy(gameObject); return; }
            if (gather)
            {
                if (released < 0f && stillActing != null && !stillActing()) Release();
                if (released >= 0f ? age - released > .45f : age > MaxGather) { Destroy(gameObject); return; }
                if (follow != null) { try { at = follow(); } catch { follow = null; } }
                vs.Clear(); cs.Clear(); u0.Clear(); u1.Clear(); u2.Clear(); u3.Clear(); tris.Clear();
                now = age; Gather(age);
                mesh.Clear();
                if (vs.Count == 0) return;
                mesh.SetVertices(vs); mesh.SetColors(cs); mesh.SetUVs(0, u0); mesh.SetUVs(1, u1); mesh.SetUVs(2, u2); mesh.SetUVs(3, u3);
                mesh.SetTriangles(tris, 0);
                mesh.bounds = new Bounds(at, Vector3.one * size * 12f);
                return;
            }
            if (pool)
            {
                if (poolEnd >= 0f && age - poolEnd > .6f) { Destroy(gameObject); return; }
                if (follow != null) { try { at = follow(); } catch { follow = null; } }
                poolShown = Mathf.MoveTowards(poolShown, Mathf.Clamp(5 + 2 * poolLevel, 5, 24), Time.deltaTime * 6f);
                vs.Clear(); cs.Clear(); u0.Clear(); u1.Clear(); u2.Clear(); u3.Clear(); tris.Clear();
                now = age; PoisonPool(age);
                mesh.Clear();
                if (vs.Count == 0) return;
                mesh.SetVertices(vs); mesh.SetColors(cs); mesh.SetUVs(0, u0); mesh.SetUVs(1, u1); mesh.SetUVs(2, u2); mesh.SetUVs(3, u3);
                mesh.SetTriangles(tris, 0);
                mesh.bounds = new Bounds(at, Vector3.one * size * 12f);
                return;
            }
            float t = age - delay;
            if (t > 0f) t *= Pace;
            if (t > Mathf.Max(duration + Linger, enemyHit ? 1.45f : 0f)) { Destroy(gameObject); return; }
            vs.Clear(); cs.Clear(); u0.Clear(); u1.Clear(); u2.Clear(); u3.Clear(); tris.Clear();
            now = t;
            if (enemyHit) ImpactLayer(t);
            // 抢拍开幕 lands on the hero himself: the afterglow's glows washed him gold (probe10),
            // and its haste mark carries the glitter on.
            if (t >= duration * .4f && kind != "angelintro" && kind != "tempo") Afterglow(t);
            if (t >= 0f && t <= duration)
                switch (kind)
                {
                    case "claw": case "clawfx": Claw(t, kind == "claw"); break;
                    case "cut": Cut(t); break;
                    case "seal": Seal(t); break;
                    case "swap": Swap(t); break;
                    case "shadow": Shadow(t); break;
                    case "reverse": Reverse(t); break;
                    case "edict": Edict(t); break;
                    case "finale": Finale(t); break;
                    case "mask": Mask(t); break;
                    case "rewrite": Rewrite(t); break;
                    case "clock": Clock(t); break;
                    case "ghost": Ghost(t); break;
                    case "ghostred": Bind(t); break;
                    case "bite": Bite(t); break;
                    case "ink": InkSlash(t); break;
                    case "bolt": BoltStrike(t); break;
                    case "drain": Drain(t); break;
                    case "pin": Pin(t); break;
                    case "mend": Mend(t); break;
                    case "silk": Silk(t); break;
                    case "sign": Sign(t); break;
                    case "sovereign": Sovereign(t); break;
                    case "verdict": Verdict(t); break;
                    case "chain": Chain(t); break;
                    case "meteor": Meteor(t); break;
                    case "toll": Toll(t); break;
                    case "emerald": case "emeraldfog": case "emeraldburst": Emerald(t); break;
                    case "hellbreath": BreathLight(t); break;
                    case "nameseal": NameSeal(t); break;
                    case "angelintro": AngelLight(t); break;
                    case "bronzeslam": BellSlam(t); break;
                    case "geyser": Geyser(t); break;
                    case "salt": SaltSpike(t); break;
                    case "spit": Spit(t); break;
                    case "steel": Steel(t); break;
                    case "sonic": Sonic(t); break;
                    case "bonerake": BoneRake(t); break;
                    case "ram": Ram(t); break;
                    case "fist": Fist(t); break;
                    case "veil": Veil(t); break;
                    case "bubbles": Bubbles(t); break;
                    case "moonwind": MoonWind(t); break;
                    case "pounce": Pounce(t); break;
                    case "lotusmend": LotusMend(t); break;
                    case "b01slash": B01Slash(t); break;
                    case "b02straps": B02Straps(t); break;
                    case "b03wave": B03Wave(t); break;
                    case "b03bell": B03Bell(t); break;
                    case "b04quill": B04Quill(t); break;
                    case "b05needles": B05Needles(t); break;
                    case "b05threads": B05Threads(t); break;
                    case "b06anchor": B06Anchor(t); break;
                    case "b07knock": B07Knock(t); break;
                    case "b07spit": B07Spit(t); break;
                    case "b08stab": B08Stab(t); break;
                    case "b08echo": B08Echo(t); break;
                    case "b09rend": B09Rend(t); break;
                    case "b10veil": B10Veil(t); break;
                    case "crimsonmend": CrimsonMend(t); break;
                    default: if (!CardKind(t)) Burst(t); break;
                }
            mesh.Clear();
            // An empty vertex list makes Unity compute an invalid bounding box (MinMaxAABB).
            if (vs.Count == 0) return;
            mesh.SetVertices(vs); mesh.SetColors(cs); mesh.SetUVs(0, u0); mesh.SetUVs(1, u1); mesh.SetUVs(2, u2); mesh.SetUVs(3, u3);
            mesh.SetTriangles(tris, 0);
            mesh.bounds = new Bounds(at, Vector3.one * size * 12f);
        }

        /// The dissolving remains of a hit: a soft glow fading out, a few slow curling wisps of
        /// light, and motes of the spell's own colours drifting outward (rising for the self
        /// buff), twinkling, the brightest as small sparkles. Starts at 40 % of the hit and runs
        /// Linger past it. (linger1: small faint motes vanished on the bright marble.)
        void Afterglow(float t)
        {
            float s = size;
            float a0 = duration * .4f, a1 = duration + Linger;
            float v = Inv(a0, a1, t), inA = Inv(a0, a0 + .1f, t);
            float fade = inA * (1f - v * v);
            if (fade <= .005f) return;
            var c = kind == "mask" ? new Vector2(0f, .55f * s) : Vector2.zero;
            // 碎镜连弹's six landings stacked these glows into a blue sheen on the target (probe10).
            float gk = kind == "mirror" ? .3f : 1f;
            Glow(c, (1.5f + .5f * v) * s, band2, .3f * gk * fade * (1f - v));
            Glow(c, (2.5f + .7f * v) * s, outer, .16f * gk * fade * (1f - v));
            bool rise = kind == "rewrite";
            float age = t - a0;
            // Wisps: slow curling ribbons of light drifting up and out, thinning away.
            for (int i = 0; i < 5; i++)
            {
                float ang = (i + .5f * J(i + 210)) * 6.283f / 5f + .4f;
                var d = new Vector2(Mathf.Cos(ang), Mathf.Sin(ang) * .6f + .5f).normalized;
                var b = c + d * (.35f * s + age * .4f * s);
                float L = s * (.45f + .3f * J(i + 211)) * (1f - .5f * v);
                Flame(b, d, L, .14f * s * (1f - .6f * v), t, 210 + i, .5f, .4f * fade, (J(i + 212) - .5f) * 2.4f, 3f, i % 2 == 0 ? band2 : band3);
            }
            int n = kind == "finale" ? 30 : 22;
            for (int i = 0; i < n; i++)
            {
                float ang = J(i + 200) * 6.283f, r0 = (.3f + 1f * J(i + 201)) * s;
                var d = new Vector2(Mathf.Cos(ang), Mathf.Sin(ang));
                float drift = age * s * (.35f + .45f * J(i + 202));
                var p = c + d * (r0 + (rise ? .2f : 1f) * drift) + Vector2.up * (drift * (rise ? 1.6f : .5f))
                        + new Vector2(Mathf.Sin(t * 2.3f + i) * .07f * s, 0f);
                float tw = .6f + .4f * Mathf.Sin(t * (8f + 5f * J(i + 203)) + i * 1.9f);
                float a = fade * tw;
                var col = kind == "finale" ? RainbowInk[i % RainbowInk.Length] : i % 3 == 0 ? core : i % 3 == 1 ? band3 : band2;
                if (i % 3 == 0) Sparkle(p, s * (.12f + .08f * J(i + 204)) * (1f - .4f * v), col, a, 15f + t * 60f);
                else { Glow(p, s * .14f, col, .35f * a); Dot(p, s * (.04f + .03f * J(i + 205)) * (1f - .3f * v), col, 3f, a); }
            }
        }

        // ---- easing / noise (the reference's vfx.py)
        static float Inv(float a, float b, float x) => b == a ? 0f : Mathf.Clamp01((x - a) / (b - a));
        static float EOut(float u) { u = Mathf.Clamp01(u); return 1f - Mathf.Pow(1f - u, 3f); }
        static float EIn(float u) { u = Mathf.Clamp01(u); return u * u * u; }
        static float Smooth(float u) { u = Mathf.Clamp01(u); return u * u * (3f - 2f * u); }
        static float EBack(float u, float s = 1.7f) { u = Mathf.Clamp01(u) - 1f; return u * u * ((s + 1f) * u + s) + 1f; }
        static float Hash(float a, float b) { float x = Mathf.Sin(a * 12.9898f + b * 25.9796f + 78.233f) * 43758.5453f; return x - Mathf.Floor(x); }
        static float VNoise(float x, float seed) { float i = Mathf.Floor(x), f = x - i; float a = Hash(i, seed) * 2f - 1f, b = Hash(i + 1f, seed) * 2f - 1f; return Mathf.Lerp(a, b, f * f * (3f - 2f * f)); }
        static float Fbm(float x, float seed) => VNoise(x, seed) * .6f + VNoise(x * 2.1f, seed + 7f) * .3f + VNoise(x * 4.3f, seed + 13f) * .1f;

        // ---- scripts (lengths in units of `size`)

        /// 猎犬扑咬 (FIRE): the hit spark (radial spikes, sparkle, ring, glow) on contact, three
        /// crescent tears that snap open and burn - flame tongues licking off their outer
        /// edge - then thin and fade from the trailing end while sparks fly and dark smoke
        /// discs drift up.
        void Claw(float t, bool strokes)
        {
            float s = size, u = t / duration;
            var ax = Rot(dir, dir.x >= 0f ? -.6f : .6f);
            var side = new Vector2(-ax.y, ax.x);
            float Rc = 1.6f * s; float baseA = Mathf.Atan2(side.y, side.x);
            float grow = EBack(Inv(0f, .09f, t));
            // The strokes start leaving at .2 s, like the reference's hits (ink9 still full at .6 s).
            float fade = 1f - EIn(Inv(.2f, .58f, t));
            float span = 1.15f * grow;
            // Glow and the hit spark first (behind the strokes).
            float live = 1f - EIn(Inv(.05f, .5f, t));
            Glow(Vector2.zero, 2.6f * s, outer, (strokes ? .45f : .06f) * live);
            Glow(Vector2.zero, 1.6f * s, band2, (strokes ? .65f : .1f) * live);
            ImpactStar(ax * (.05f * s), s * 1.1f, t, 60);
            // A small fire blast where the rake bites (the reference's FireExplosion core).
            float br = .38f * s * EOut(Inv(0f, .08f, t)) * (1f - Inv(.08f, .32f, t));
            if (strokes && br > .01f * s) Dot(ax * (.05f * s), br, band3, 0f, 1f, t * 2.5f, .26f);
            for (int i = 0; i < 18; i++)
            {
                float ang = J(i + 100) * 6.283f; var d = new Vector2(Mathf.Cos(ang), Mathf.Sin(ang));
                float k = Inv(0f, .4f, t);
                float r0 = s * (.35f + .2f * J(i + 101)) + s * 1.4f * EOut(k * 1.5f) * (.5f + .7f * J(i + 102));
                float len = s * (.1f + .12f * J(i + 103)) * (1f - k);
                if (len > .005f * s) Taper(d * r0, d * (r0 + len), s * .03f, s * .02f, i % 3 == 0 ? Color.white : hot, 1f - k);
            }
            for (int k = -1; k <= 1 && strokes; k++)
            {
                var c = side * (k * .27f * s) + ax * ((J(k + 5) - .5f) * .18f * s) - side * Rc;
                // The stroke burns away from its trailing end: the arc shortens from one side.
                float eat = EIn(Inv(.16f, .5f, t)) * span;
                float a0 = baseA - span * .5f + eat, a1 = baseA + span * .5f;
                if (a1 - a0 < .05f) continue;
                float thick = .2f * s * grow * (1f - .45f * Inv(.15f, .5f, t));
                // Flame tongues lick off the outer edge once it is open.
                float lick = Inv(.08f, .22f, t) * fade;
                if (lick > 0f)
                    for (int i = 0; i < 5; i++)
                    {
                        float ua = (i + .5f) / 5f; float a = Mathf.Lerp(a0, a1, ua);
                        var n = new Vector2(Mathf.Cos(a), Mathf.Sin(a));
                        var b = c + n * (Rc + thick * .5f);
                        float len = (.35f + .25f * J(i + 10 + k * 7)) * s * lick * (1f - .6f * Inv(.2f, .5f, t));
                        Flame(b, n * .6f + ax * (.4f * (J(i + 3) - .5f)), len, .13f * s * lick, t, i + k * 9, .25f, fade);
                    }
                Crescent(c, Rc, a0, a1, thick, fade, .35f, t * .7f + k);
            }
            // Sparks: short bright streaks thrown along the rake, falling.
            Sparks(ax * (.1f * s), t, 22, 50, 1.4f * s, ax, fade);
            // Embers drifting up, then dark smoke discs.
            for (int i = 0; i < 8; i++)
            {
                float born = .05f + .25f * J(i + 70); float a = Inv(born, born + .55f, t); if (a <= 0f || a >= 1f) continue;
                float ang = J(i + 20) * 6.283f; float rr = (.3f + .5f * J(i + 30)) * s;
                var p = new Vector2(Mathf.Cos(ang), Mathf.Sin(ang)) * rr + Vector2.up * (.5f * s * a) + ax * (.2f * s * a);
                Dot(p, (.045f - .02f * a) * s, Color.Lerp(core, band2, a), 3f, (1f - a) * .9f);
            }
            // (No smoke discs: flat grey discs read as plates laid over the hero, ink9.)
        }

        /// 主角普攻命中 (ROSE), built like the reference's FireExplosion (original version,
        /// 2026-10-08 user: 拿原始版当法术参考): a white pop, ten cel-banded tongues thrown out
        /// and shrinking back, a banded core blob that snaps open and shrinks, two open arcs
        /// running out (never closed rings), the hit spark, sparks and shards. No lightning:
        /// that is the storm caster's, not the hero's.
        void Burst(float t)
        {
            float s = size, u = t / duration; var c = Vector2.zero;
            float fade = 1f - EIn(u), live = 1f - u;
            // The reference's glow comes from a full-screen bloom; here three stacked soft
            // glows of falling size do that job round the hit.
            // With the spell bloom on, these only need to seed the light (ink16 blew out white).
            Glow(c, 3.4f * s, outer, .22f * Mathf.Pow(live, 1.2f));
            Glow(c, 2.1f * s, band2, .3f * Mathf.Pow(live, 1.5f));
            Glow(c, 1.15f * s, band3, .22f * Mathf.Pow(live, 2f));
            // Broad translucent rays behind, each its own length and width, turning slowly.
            for (int k = 0; k < 9; k++)
            {
                float ang = J(k + 30) * 6.283f + t * .6f; var d = new Vector2(Mathf.Cos(ang), Mathf.Sin(ang));
                float L = s * (1.5f + 1.1f * J(k + 31)) * EOut(u * 3f);
                Taper(c, c + d * L, s * (.26f + .18f * J(k + 32)) * live, 0f, band3, .26f * live);
            }
            // One shock ring running out and thinning within .3 s, as in the reference.
            float ru = Inv(0f, .3f, t);
            if (ru < 1f) ShockRing(c, s * (.4f + 1.5f * EOut(ru)), s * .2f * (1f - ru) * (1f - ru), core, 1f - ru, J(50) * 10f);
            // Corona: sixteen thin curling wisps of light off the blob's edge, a soft wide
            // stroke under a narrow bright one (fat flat cones read as cartoon, 2026-10-08).
            // The blob pops open and is gone by 60 % of the life (held longer it hid the target).
            float R = .85f * s * EOut(u * 3.2f) * (1f - EIn(Inv(.15f, .6f, u)));
            for (int k = 0; k < 16; k++)
            {
                float ang = (k + .7f * J(k + 2)) * 6.283f / 16f; var d = new Vector2(Mathf.Cos(ang), Mathf.Sin(ang));
                float L = s * (.5f + .75f * J(k + 12)) * EOut(u * 2.6f) * Mathf.Pow(live, .7f);
                if (L < .02f * s) continue;
                float curl = (J(k + 60) - .5f) * 1.8f, wid = s * (.16f + .1f * J(k + 70)) * (1f - u * .4f);
                Flame(c + d * (R * .75f), d, L, wid * 1.9f, t, k + 3, .18f, .3f * fade, curl, 3f, band2);
                Flame(c + d * (R * .75f), d, L * .92f, wid * .7f, t, k + 3, .18f, .6f * fade, curl, 3f, hot);
            }
            // Core: one big wobbling blob, cel-banded outline -> cream centre.
            if (R > .01f * s) Dot(c, R, band3, 0f, fade, t * 2.2f, .24f);
            if (u < .1f) Glow(c, .9f * s, Color.white, .5f * (1f - u / .1f));
            // Dashes flying out, sparks and shards.
            for (int i = 0; i < 28; i++)
            {
                float ang = J(i + 100) * 6.283f; var d = new Vector2(Mathf.Cos(ang), Mathf.Sin(ang));
                float r0 = s * (.55f + .3f * J(i + 101)) + s * 1.7f * EOut(u * 1.5f) * (.5f + .7f * J(i + 102));
                float len = s * (.12f + .14f * J(i + 103)) * live;
                if (len > .005f * s) Taper(c + d * r0, c + d * (r0 + len), s * .035f, s * .025f, i % 3 == 0 ? Color.white : hot, live);
            }
            Sparks(c, t, 22, 50, 2f * s, Vector2.zero, fade);
            Shards(c, t, 10, 90, 1.6f * s, fade);
        }

        /// 错步穿行 (over the card shatter): two long curved cuts cross the card a beat before
        /// it bursts (CardShatter.BurstAt = .15 s) - each drawn end to end in .06 s as a
        /// painterly blade under a wide soft and a narrow bright stroke of light - then the hit
        /// spark, one shock ring, gold dashes along the cuts and a few mirror glints.
        void Cut(float t)
        {
            float s = size, u = t / duration, live = 1f - u;
            const float Hit = .11f;
            float tc = t - Hit;
            Glow(Vector2.zero, 3.2f * s, outer, .12f * Mathf.Pow(live, 1.2f));
            Glow(Vector2.zero, 1.9f * s, band2, .14f * Mathf.Pow(live, 1.6f));
            float baseAng = Mathf.Atan2(dir.y, dir.x);
            for (int k = 0; k < 2; k++)
            {
                // A long, gently curved cut through the target: an arc of a big circle whose
                // centre sits off to one side, crossing the other cut at the target.
                float cutAng = baseAng + (k == 0 ? .7f : -.7f) + (J(k + 7) - .5f) * .25f;
                var along = new Vector2(Mathf.Cos(cutAng), Mathf.Sin(cutAng));
                var n = new Vector2(-along.y, along.x) * (k == 0 ? 1f : -1f);
                float Rc = 3.4f * s, half = 1.5f * s / Rc;
                var cc = -n * Rc;
                float mid = Mathf.Atan2(n.y, n.x);
                float start = t - k * .035f;
                float draw = EOut(Inv(0f, .07f, start));
                if (draw <= 0f) continue;
                float leave = EIn(Inv(.2f, .5f, start));
                float a0 = mid - half + leave * 2f * half, a1 = mid - half + draw * 2f * half;
                if (a1 - a0 < .02f) continue;
                float thick = .11f * s * (1f - .5f * Inv(.12f, .5f, start));
                float f = 1f - EIn(Inv(.25f, .55f, start));
                Crescent(cc, Rc, a0, a1, thick, f, .2f, start * 1.3f + k);
                Arc(cc, Rc, .4f * s * (1f - .5f * leave), a0 * Mathf.Rad2Deg, (a1 - a0) * Mathf.Rad2Deg, band2, .16f * f);
                Arc(cc, Rc, .07f * s, a0 * Mathf.Rad2Deg, (a1 - a0) * Mathf.Rad2Deg, core, .7f * f);
                // Gold dashes thrown along the cut.
                for (int i = 0; i < 9; i++)
                {
                    float uu = Inv(.02f, .4f, start); if (uu <= 0f || uu >= 1f) break;
                    float along0 = (J(i + 20 + k * 9) - .5f) * 2.6f * s;
                    var p0 = along * along0 + n * ((J(i + 40) - .5f) * .3f * s) + along * Mathf.Sign(along0 + .01f) * (1.2f * s * EOut(uu));
                    float len = s * (.12f + .12f * J(i + 30)) * (1f - uu);
                    Taper(p0, p0 + along * Mathf.Sign(along0 + .01f) * len, s * .03f, s * .015f, i % 3 == 0 ? Color.white : hot, 1f - uu);
                }
            }
            if (tc >= 0f)
            {
                // (The impact star carries the one shock ring; a second made a concentric pair.)
                ImpactStar(Vector2.zero, s * 1.05f, tc, 61);
                for (int i = 0; i < 5; i++)
                {
                    float gu = Inv(.02f * i, .25f + .03f * i, tc); if (gu <= 0f || gu >= 1f) continue;
                    float ang = J(i + 80) * 6.283f; var p = new Vector2(Mathf.Cos(ang), Mathf.Sin(ang)) * (.5f + .7f * J(i + 81)) * s;
                    Sparkle(p, s * (.16f + .1f * J(i + 82)) * (1f - gu * .5f), i % 2 == 0 ? band2 : hot, 1f - gu, 15f + t * 200f);
                }
                Sparks(Vector2.zero, tc, 16, 70, 1.8f * s, Vector2.zero, 1f - EIn(Inv(0f, .45f, tc)));
            }
        }

        /// 伪证烙印: a branding seal slams onto the target - a heavy banded blob squashed flat on
        /// impact and springing round - hot cracks run out underneath (dark scorched lines with
        /// a glowing seam), thick wax tongues splash out sideways and curl down, wax drops fall,
        /// embers rise, one shock ring.
        void Seal(float t)
        {
            float s = size, u = t / duration, live = 1f - u, fade = 1f - EIn(u);
            var c = Vector2.zero;
            Glow(c, 3.2f * s, outer, .24f * Mathf.Pow(live, 1.2f));
            Glow(c, 2f * s, band2, .3f * Mathf.Pow(live, 1.5f));
            Glow(c, 1.1f * s, band3, .2f * Mathf.Pow(live, 2f));
            // Scorched cracks, below and beside the stamp.
            float cr = EOut(Inv(0f, .1f, t)), cf = 1f - EIn(Inv(.32f, .72f, t));
            cf = 1f - EIn(Inv(.22f, .55f, t));
            for (int k = 0; k < 9; k++)
            {
                float ang = (k + .6f * J(k + 90)) * 6.283f / 9f;
                var d = new Vector2(Mathf.Cos(ang), Mathf.Sin(ang));
                float len = s * (.35f + .35f * J(k + 91)) * cr;
                Crack(c + d * (.55f * s), d, len, s * .055f, 120 + k * 11, new Color(.2f, .04f, .05f), .8f * cf, .9f * cf * (1f - Inv(.08f, .35f, t)));
            }
            ImpactStar(c, s * 1.1f, t, 63);
            // Wax tongues: fat, short, thrown sideways, curling down (painterly bands = wax).
            for (int k = 0; k < 10; k++)
            {
                float side = k % 2 == 0 ? 1f : -1f;
                float ang = (side > 0 ? 0f : 180f) + side * (-35f + 80f * J(k + 60)) ;
                var d = new Vector2(Mathf.Cos(ang * Mathf.Deg2Rad), Mathf.Sin(ang * Mathf.Deg2Rad));
                float L = s * (.55f + .5f * J(k + 61)) * EOut(u * 3.4f) * Mathf.Pow(live, .8f);
                if (L < .02f * s) continue;
                float wid = s * (.26f + .14f * J(k + 62)) * (1f - u * .5f);
                Flame(c + d * (.35f * s), d, L, wid, t, k + 30, .14f, fade, -side * .9f, 0f, band3);
                Flame(c + d * (.35f * s), d, L * .85f, wid * .45f, t, k + 30, .14f, .5f * fade, -side * .9f, 3f, hot);
            }
            // The seal itself: squashed on impact (x wide, y flat), springing back round, then
            // sinking away by 60 % of the life.
            float sq = Inv(.0f, .2f, t);
            float sy = .5f + .5f * EBack(sq, 2.2f), sx = 1f / Mathf.Sqrt(Mathf.Max(.3f, sy));
            float R = .7f * s * EOut(u * 5f) * (1f - EIn(Inv(.18f, .62f, u)));
            if (R > .01f * s) Dot(c, R, band3, 0f, fade, t * 1.6f, .16f, sx, sy);
            if (u < .08f) Glow(c, .9f * s, Color.white, .55f * (1f - u / .08f));
            Drips(c, t, 14, 140, 1.6f * s, fade);
            for (int i = 0; i < 10; i++)
            {
                float born = .05f + .3f * J(i + 70); float a = Inv(born, born + .45f, t); if (a <= 0f || a >= 1f) continue;
                float ang = J(i + 20) * 6.283f; float rr = (.3f + .6f * J(i + 30)) * s;
                var p = new Vector2(Mathf.Cos(ang), Mathf.Sin(ang)) * rr + Vector2.up * (.7f * s * a);
                Dot(p, (.04f - .02f * a) * s, Color.Lerp(core, band2, a), 3f, (1f - a) * .9f);
            }
            Sparks(c, t, 14, 50, 1.6f * s, Vector2.up * .3f, fade);
        }

        /// 张冠李戴: two comets - a blue name and an orange one - spiral in round the target,
        /// meet in a pale burst, and fly out again on each other's side, their tails curling.
        void Swap(float t)
        {
            float s = size, u = t / duration, live = 1f - u;
            const float Meet = .2f;
            var keep = (outer, band2, band3, core, hot);
            var blue = keep;
            var orange = (Hex("C2410C"), Hex("FF7A1F"), Hex("FF9A3C"), Hex("FFE6C8"), Hex("FFB46A"));
            Glow(Vector2.zero, 3f * s, Hex("7A6CFF"), .2f * Mathf.Pow(live, 1.3f));
            for (int k = 0; k < 2; k++)
            {
                var pal = k == 0 ? blue : orange;
                (outer, band2, band3, core, hot) = pal;
                var p = Comet(k, t); var pPrev = Comet(k, t - .025f);
                var v = p - pPrev; if (v.sqrMagnitude < 1e-8f) v = Vector2.up * 1e-4f;
                float f = 1f - EIn(Inv(.45f, .8f, t));
                float head = s * (.28f + .06f * Mathf.Sin(t * 30f + k)) * (t < Meet ? 1f : 1f - .5f * Inv(Meet, .7f, t));
                float tail = Mathf.Min(1.4f * s, v.magnitude / .025f * .12f);
                Glow(p, head * 3.2f, band2, .35f * f);
                Flame(p, -v, tail * 1.6f, head * 2.4f, t, 10 + k, .2f, .3f * f, k == 0 ? .9f : -.9f, 3f, band2);
                Flame(p, -v, tail * 1.4f, head * 1.1f, t, 10 + k, .2f, .7f * f, k == 0 ? .9f : -.9f, 3f, hot);
                Dot(p, head, band3, 0f, f, t * 3f + k, .18f);
            }
            (outer, band2, band3, core, hot) = keep;
            float tm = t - Meet;
            if (tm >= 0f)
            {
                float mu = Inv(0f, .35f, tm);
                float R = .6f * s * EOut(mu * 3f) * (1f - EIn(mu));
                if (R > .01f * s) Dot(Vector2.zero, R, Hex("E8E4FF"), 0f, 1f - mu, tm * 2f, .22f);
                if (tm < .06f) Glow(Vector2.zero, 1f * s, Color.white, .6f * (1f - tm / .06f));
                ImpactStar(Vector2.zero, s * .95f, tm, 62);
                for (int i = 0; i < 22; i++)
                {
                    float ang = J(i + 100) * 6.283f; var d = new Vector2(Mathf.Cos(ang), Mathf.Sin(ang));
                    float r0 = s * (.45f + .25f * J(i + 101)) + s * 1.5f * EOut(mu * 1.5f) * (.5f + .7f * J(i + 102));
                    float len = s * (.12f + .12f * J(i + 103)) * (1f - mu);
                    if (len > .005f * s) Taper(d * r0, d * (r0 + len), s * .032f, s * .022f, i % 2 == 0 ? Hex("9AD8FF") : Hex("FFC878"), 1f - mu);
                }
                Shards(Vector2.zero, tm, 10, 91, 1.5f * s, 1f - mu);
            }
        }

        /// 双影: two shadows strike from both sides at once - two thick dark-violet jaws ")("
        /// swing in and close on the target, a violet burst where they meet, a pair of eyes
        /// flashes in it, smoky dark wisps curl off the jaw tips as they slide past and fade.
        void Shadow(float t)
        {
            float s = size, u = t / duration, live = 1f - u, fade = 1f - EIn(u);
            const float Meet = .1f;
            Glow(Vector2.zero, 3f * s, outer, .22f * Mathf.Pow(live, 1.2f));
            Glow(Vector2.zero, 1.8f * s, band2, .26f * Mathf.Pow(live, 1.6f));
            float close = EOut(Inv(0f, Meet, t)), pass = EOut(Inv(Meet, .35f, t));
            float f = 1f - EIn(Inv(.14f, .36f, t));
            for (int k = 0; k < 2; k++)
            {
                float side = k == 0 ? -1f : 1f;
                float Rj = 1.05f * s;
                // The jaw's circle sits beside the target so its arc passes through it; after
                // they meet the jaws keep sliding on past each other.
                // They bite in (the arc tightens) and dissolve, rather than sliding on past each
                // other into a pair of brackets round the target (b3).
                var cc = new Vector2(side * Rj * (1f + .5f * (1f - close)), side * .08f * s);
                float mid = side < 0f ? 0f : Mathf.PI;
                float hs = (.35f + .6f * close) * (1f - .55f * pass);
                float thick = .24f * s * (1f - .45f * pass);
                if (f <= .01f) continue;
                Arc(cc, Rj, .5f * s, (mid - hs) * Mathf.Rad2Deg, 2f * hs * Mathf.Rad2Deg, band2, .28f * f);
                Crescent(cc, Rj, mid - hs, mid + hs, thick, f, -.3f, t * 1.4f + k);
                Arc(cc, Rj - thick * .3f, .07f * s, (mid - hs * .8f) * Mathf.Rad2Deg, 1.6f * hs * Mathf.Rad2Deg, hot, .75f * f);
                // Dark smoky wisps off both tips.
                for (int e = 0; e < 2; e++)
                {
                    float a = mid + (e == 0 ? -hs : hs);
                    var tip = cc + new Vector2(Mathf.Cos(a), Mathf.Sin(a)) * Rj;
                    var d = new Vector2(Mathf.Cos(a), Mathf.Sin(a)) * .3f + new Vector2(side, e == 0 ? -.4f : .4f);
                    float L = s * (.4f + .3f * J(k * 3 + e)) * Inv(.03f, .2f, t) * (1f - .5f * pass);
                    if (L > .02f * s) Flame(tip, d, L, .16f * s, t, 40 + k * 2 + e, .3f, .8f * f, side * (e == 0 ? -1f : 1f), 0f, band2);
                }
            }
            float tm = t - Meet;
            if (tm >= 0f)
            {
                ImpactStar(Vector2.zero, s * 1f, tm, 64);
                float R = .5f * s * EOut(Inv(0f, .06f, tm)) * (1f - EIn(Inv(.05f, .35f, tm)));
                if (R > .01f * s) Dot(Vector2.zero, R, band3, 0f, 1f, tm * 2.5f, .22f);
                // A pair of eyes flashes in the burst.
                float eye = Inv(.02f, .06f, tm) * (1f - Inv(.18f, .3f, tm));
                if (eye > .01f)
                    for (int e = 0; e < 2; e++)
                        Sparkle(new Vector2((e == 0 ? -.2f : .2f) * s, .18f * s), .28f * s * eye, Hex("FFE7A0"), eye, 0f);
                Sparks(Vector2.zero, tm, 16, 72, 1.7f * s, Vector2.zero, 1f - EIn(Inv(0f, .45f, tm)));
            }
        }

        /// 反客为主: the strike comes from behind - a broad silk sweep whips round the target
        /// from its far side (an open spiral, never a closed ring), petals peel off it and
        /// swirl outward, gold sparks, the hit spark at the moment it wraps the front.
        void Reverse(float t)
        {
            float s = size, u = t / duration, live = 1f - u, fade = 1f - EIn(u);
            Glow(Vector2.zero, 3f * s, outer, .2f * Mathf.Pow(live, 1.2f));
            Glow(Vector2.zero, 1.8f * s, band2, .26f * Mathf.Pow(live, 1.6f));
            float behind = Mathf.Atan2(dir.y, dir.x);      // from the far side of the target
            float grow = EOut(Inv(0f, .14f, t)), leave = EIn(Inv(.16f, .48f, t));
            float a0 = behind + leave * 3.3f, a1 = behind + 3.8f * grow;
            float f = 1f - EIn(Inv(.22f, .5f, t));
            if (a1 - a0 > .05f && f > .01f) Spiral(a0, a1, behind, s * 1.15f, s * .5f, s * .26f * (1f - .4f * leave), f, t);
            // Petals peeling off along the sweep, thrown outward and curling.
            for (int i = 0; i < 16; i++)
            {
                float born = .03f + .14f * J(i + 110); float pu = Inv(born, born + .5f, t); if (pu <= 0f || pu >= 1f) continue;
                float a = behind + 3.8f * Mathf.Clamp01((born - .03f) / .14f) + (J(i + 111) - .5f) * .4f;
                var n = new Vector2(Mathf.Cos(a), Mathf.Sin(a)); var tng = new Vector2(-n.y, n.x);
                var p = n * (s * (1f + 1.2f * EOut(pu))) + tng * (s * .4f * pu);
                float L = s * (.34f + .16f * J(i + 112)) * (1f - .5f * pu);
                Flame(p, Rot(tng, (J(i + 113) - .5f) * 1.2f + pu * 2f), L, L * .75f, t, 60 + i, .2f, (1f - pu), (J(i + 114) - .5f) * 2f, 0f, band3);
            }
            if (t >= .08f) ImpactStar(Vector2.zero, s * 1f, t - .08f, 65);
            float R = .45f * s * EOut(Inv(.06f, .14f, t)) * (1f - EIn(Inv(.14f, .42f, t)));
            if (R > .01f * s) Dot(Vector2.zero, R, band3, 0f, 1f, t * 2.5f, .22f);
            Sparks(Vector2.zero, t - .06f, 16, 74, 1.7f * s, Vector2.zero, fade);
        }

        /// 无名宣告: a golden edict drives down from above onto the target - a tapering lance of
        /// light - bursts into a fan of gold rays rising like a crown, a banded gold blob, the
        /// hit spark, gold coins tossed up and tumbling down.
        void Edict(float t)
        {
            float s = size, u = t / duration, live = 1f - u, fade = 1f - EIn(u);
            const float Strike = .08f;
            Glow(Vector2.zero, 3.4f * s, outer, .22f * Mathf.Pow(live, 1.2f));
            Glow(Vector2.zero, 2f * s, band3, .26f * Mathf.Pow(live, 1.6f));
            // The lance: drives down in .08 s, then thins and fades.
            float down = EOut(Inv(0f, Strike, t)), lf = 1f - EIn(Inv(Strike, .3f, t));
            if (lf > .01f)
            {
                // A short spear of light falling onto the target (a column joined to the sky
                // read as the pillars the user disliked on 2026-10-07).
                var tip = Vector2.Lerp(new Vector2(0f, 2.6f * s), Vector2.zero, down);
                var tail = tip + new Vector2(0f, (1.1f - .7f * Inv(Strike, .3f, t)) * s);
                Taper(tail, tip, .1f * s * lf, .34f * s * lf, band2, .32f * lf);
                Taper(tail, tip, .03f * s * lf, .12f * s * lf, core, .9f * lf);
            }
            float tm = t - Strike;
            if (tm < 0f) return;
            float mu = tm / (duration - Strike);
            // A crown of gold rays fanning upward, each its own length.
            for (int k = 0; k < 7; k++)
            {
                float ang = (90f + (k - 3f) * 22f + (J(k + 120) - .5f) * 8f) * Mathf.Deg2Rad;
                var d = new Vector2(Mathf.Cos(ang), Mathf.Sin(ang));
                float L = s * (1.3f + 1.2f * J(k + 121)) * EOut(mu * 3f) * (1f - EIn(mu));
                Taper(Vector2.zero, d * L, s * (.22f + .12f * J(k + 122)) * (1f - mu), 0f, band3, .3f * (1f - mu));
                Taper(Vector2.zero, d * L * .8f, s * .06f * (1f - mu), 0f, core, .7f * (1f - mu));
            }
            ImpactStar(Vector2.zero, s * 1.15f, tm, 66);
            float R = .62f * s * EOut(mu * 4f) * (1f - EIn(Inv(.12f, .55f, mu)));
            if (R > .01f * s) Dot(Vector2.zero, R, band3, 0f, 1f - mu, tm * 2f, .2f, 1.15f, .9f);
            if (tm < .06f) Glow(Vector2.zero, 1f * s, Color.white, .6f * (1f - tm / .06f));
            // Gold coins: tossed up and out, tumbling down (a sparkle that turns as it falls).
            for (int i = 0; i < 14; i++)
            {
                float ang = (30f + 120f * J(i + 130)) * Mathf.Deg2Rad; float sp = s * (1.2f + 1.4f * J(i + 131)); float life = .45f + .25f * J(i + 132);
                if (tm > life) continue;
                float cu = tm / life, e = Mathf.Exp(-2f * tm), disp = (1f - e) / 2f;
                var p = new Vector2(Mathf.Cos(ang), Mathf.Sin(ang)) * sp * disp + Vector2.down * (3.4f * s * tm * tm);
                float flip = Mathf.Abs(Mathf.Cos(tm * 14f + i));
                Dot(p, s * (.07f + .03f * J(i + 133)), band3, 0f, 1f - cu * cu, tm + i, .05f, .35f + .65f * flip, 1f);
                if (flip > .9f) Sparkle(p, s * .12f, hot, (1f - cu) * .8f, 15f);
            }
            Sparks(Vector2.zero, tm, 14, 76, 1.8f * s, Vector2.up * .4f, 1f - EIn(mu));
        }

        /// An open spiral stroke from angle a0 to a1 (radians), radius shrinking from r0 at
        /// `start` to r1 one full turn later: a painterly ribbon under a soft glow. Never closes.
        void Spiral(float a0, float a1, float start, float r0, float r1, float thick, float fade, float t)
        {
            const int N = 30;
            int i0 = vs.Count; seedNow = J(i0 + 7);
            float RAt(float a) => Mathf.Lerp(r0, r1, Mathf.Clamp01((a - start) / 6.283f));
            for (int i = 0; i <= N; i++)
            {
                float u = (float)i / N; float a = Mathf.Lerp(a0, a1, u);
                float w = thick * Mathf.Pow(Mathf.Max(0f, Mathf.Sin(u * Mathf.PI)), .6f) * (1f + .15f * Fbm(u * 3f + t, 4f));
                var n = new Vector2(Mathf.Cos(a), Mathf.Sin(a)); var mid = n * RAt(a);
                V(mid + n * w * 1.2f, 0f, 0f, band3, u, fade, 1f); V(mid, 1f, 0f, band3, u, fade, 0f); V(mid - n * w * .8f, 0f, 0f, band3, u, fade, -1f);
                if (i > 0)
                {
                    int p = i0 + (i - 1) * 3, q = i0 + i * 3;
                    tris.Add(p); tris.Add(q); tris.Add(p + 1); tris.Add(q); tris.Add(q + 1); tris.Add(p + 1);
                    tris.Add(p + 1); tris.Add(q + 1); tris.Add(p + 2); tris.Add(q + 1); tris.Add(q + 2); tris.Add(p + 2);
                }
            }
            for (int i = 0; i < 6; i++)
            {
                float b0 = Mathf.Lerp(a0, a1, i / 6f), b1 = Mathf.Lerp(a0, a1, (i + 1) / 6f);
                Arc(Vector2.zero, RAt((b0 + b1) * .5f), thick * 2.2f, b0 * Mathf.Rad2Deg, (b1 - b0) * Mathf.Rad2Deg, band2, .18f * fade);
            }
        }

        static readonly Color[] RainbowInk = { Hex("FF3A4C"), Hex("FF8A2A"), Hex("FFD84A"), Hex("5CEB8A"), Hex("3CD2FF"), Hex("6A84FF"), Hex("C46CFF") };

        /// 荒谬归结 (finisher, half the screen): a rainbow sun bursts on the target - broad
        /// turning rays in every colour, a corona of rainbow filaments curling off a wobbling
        /// gold blob, the hit spark and its one ring, then an aftershock a beat later, rainbow
        /// dashes and a slow rain of glints.
        void Finale(float t)
        {
            float s = size, u = t / duration, live = 1f - u, fade = 1f - EIn(u);
            var c = Vector2.zero;
            Glow(c, 3.6f * s, outer, .2f * Mathf.Pow(live, 1.6f));
            Glow(c, 2.3f * s, band2, .2f * Mathf.Pow(live, 2.2f));
            Glow(c, 1.3f * s, band3, .16f * Mathf.Pow(live, 3f));
            // Broad translucent rays, one colour each, turning slowly.
            for (int k = 0; k < 14; k++)
            {
                float ang = (k + .6f * J(k + 30)) * 6.283f / 14f + t * .5f; var d = new Vector2(Mathf.Cos(ang), Mathf.Sin(ang));
                // Rays start on a ring, not at the centre: fourteen additive rays meeting in one
                // point stacked into a white flare over the target at .3-.45 s (b6-b9).
                float rl = 1f - EIn(Inv(.2f, .55f, u));
                float r0 = .45f * s * EOut(u * 4f);
                float L = s * (1.6f + 1.4f * J(k + 31)) * EOut(u * 3f) * rl;
                var col = RainbowInk[k % RainbowInk.Length];
                Taper(c + d * r0, c + d * (r0 + L), s * (.22f + .14f * J(k + 32)) * live, 0f, col, .2f * rl);
                Taper(c + d * r0, c + d * (r0 + L * .75f), s * .045f * live, 0f, Color.Lerp(col, Color.white, .3f), .28f * rl);
            }
            ImpactStar(c, s * 1.2f, t, 67);
            // Corona of rainbow filaments off the blob's edge.
            // The blob is smaller and gone sooner than the plain burst's: at half the screen it
            // hid the target for .4 s (b5); the filaments and rays carry the finisher.
            float R = .6f * s * EOut(u * 3.4f) * (1f - EIn(Inv(.12f, .42f, u)));
            for (int k = 0; k < 21; k++)
            {
                float ang = (k + .7f * J(k + 2)) * 6.283f / 21f; var d = new Vector2(Mathf.Cos(ang), Mathf.Sin(ang));
                float cf = 1f - EIn(Inv(.28f, .6f, u));
                float L = s * (.55f + .8f * J(k + 12)) * EOut(u * 2.4f) * cf;
                if (L < .02f * s) continue;
                var col = RainbowInk[k % RainbowInk.Length];
                float curl = (J(k + 60) - .5f) * 1.8f, wid = s * (.15f + .1f * J(k + 70)) * (1f - u * .4f);
                // The roots stay on a ring instead of following the shrinking blob into the
                // centre, where 21 additive cores stacked into a white flare (b6-b8).
                float root = Mathf.Max(R * .75f, .42f * s * EOut(u * 3f));
                Flame(c + d * root, d, L, wid * 1.9f, t, k + 3, .18f, .28f * cf, curl, 3f, col);
                Flame(c + d * root, d, L * .9f, wid * .65f, t, k + 3, .18f, .45f * cf, curl, 3f, Color.Lerp(col, Color.white, .3f));
            }
            if (R > .01f * s) Dot(c, R, band3, 0f, fade, t * 2f, .22f);
            if (u < .07f) Glow(c, 1f * s, Color.white, .55f * (1f - u / .07f));
            // (No aftershock spark: its white spikes under the bloom washed the target white, b6/b7.)
            for (int i = 0; i < 36; i++)
            {
                float ang = J(i + 100) * 6.283f; var d = new Vector2(Mathf.Cos(ang), Mathf.Sin(ang));
                float r0 = s * (.6f + .3f * J(i + 101)) + s * 2f * EOut(u * 1.4f) * (.5f + .7f * J(i + 102));
                float len = s * (.12f + .16f * J(i + 103)) * live;
                if (len > .005f * s) Taper(c + d * r0, c + d * (r0 + len), s * .035f, s * .025f, i % 4 == 0 ? Color.white : RainbowInk[i % RainbowInk.Length], live);
            }
            // A slow rain of glints after the burst.
            for (int i = 0; i < 12; i++)
            {
                float born = .12f + .35f * J(i + 140); float gu = Inv(born, born + .5f, t); if (gu <= 0f || gu >= 1f) continue;
                var p = new Vector2((J(i + 141) - .5f) * 3.2f * s, (1.4f + .6f * J(i + 142)) * s - 2.2f * s * gu);
                Sparkle(p, s * (.12f + .08f * J(i + 143)), RainbowInk[i % RainbowInk.Length], (1f - gu) * Mathf.Sin(gu * Mathf.PI) * 1.5f, 15f + gu * 120f);
            }
            Sparks(c, t, 26, 78, 2.2f * s, Vector2.zero, fade);
            Shards(c, t, 12, 92, 1.8f * s, fade);
        }

        /// 假面谕令: a decree eye opens at the target's head - a heavy upper lid whose ends sweep
        /// out into long thin wings (never meeting the lower lid: an open shape, not a lens
        /// frame), a shorter lower lid, a faint sclera, an iris with a slit pupil that looks
        /// round, a fan of short lashes of light above - then it blinks shut and breaks into
        /// filaments. Control, not damage: no impact star. (b7: a wide closed almond read as
        /// a glass lens over the target.)
        void Mask(float t)
        {
            float s = size, u = t / duration, live = 1f - u;
            var c = new Vector2(0f, .55f * s);
            Glow(c, 2f * s, outer, .18f * Mathf.Pow(live, 1.3f));
            Glow(c, 1.1f * s, band2, .22f * Mathf.Pow(live, 1.7f));
            const float Shut = .36f;
            float open = EOut(Inv(0f, .1f, t)) * (1f - EIn(Inv(Shut - .05f, Shut, t)));
            if (t < Shut + .02f)
            {
                float W = .6f * s;                                   // half width of the eye
                float gap = .03f * s + .24f * s * open;              // half height of the opening
                float Rl = (W * W + gap * gap) / (2f * Mathf.Max(gap, .001f));
                float half = Mathf.Asin(Mathf.Clamp(W / Rl, -1f, 1f));
                var up = c + new Vector2(0f, gap - Rl);
                var dn = c + new Vector2(0f, Rl - gap);
                // Faint sclera inside the opening.
                if (open > .15f) Dot(c + new Vector2(0f, .03f * s), W * .8f, core, 2f, .2f * open, t, .03f, 1f, Mathf.Max(.05f, (.3f * s + .28f * s * open) * .62f / W));
                // The lids are hand-drawn curves, not arcs of a circle (c2/c3: 太几何、太简单、
                // 没有变化): the upper lid peaks off centre toward the inner corner and flicks up
                // into a wing past the outer corner, drawn as three overlapping brush strokes that
                // swell, thin and drift every frame, with flickering tongues of light licking up
                // off its top edge. The lower lid is two short strokes with a gap.
                float lift = .3f * s + .28f * s * open;              // how high the upper lid arches
                float side = dir.x >= 0f ? 1f : -1f;                 // outer corner away from the caster
                Vector2 P(float x, float y) => c + new Vector2(x * side, y);
                var u0 = P(-W, -.02f * s); var u1 = P(-.55f * W, lift * 1.15f); var u2 = P(.45f * W, lift * 1.05f); var u3 = P(1.05f * W, .04f * s);
                var w1 = P(1.25f * W, .1f * s); var w2 = P(1.38f * W, .2f * s + .1f * s * open); var w3 = P(1.55f * W, .34f * s * open + .1f * s);
                BrushCurve(u0, u1, u2, u3, 0f, .45f, .1f * s, open, t, 11, .03f * s);
                BrushCurve(u0, u1, u2, u3, .3f, .78f, .14f * s, open, t, 23, .025f * s);
                BrushCurve(u0, u1, u2, u3, .62f, 1f, .11f * s, open, t, 37, .03f * s);
                BrushCurve(u3, w1, w2, w3, 0f, 1f, .07f * s, open, t, 47, .02f * s);
                for (int i = 0; i < 12; i++)
                {
                    float uu = (i + .5f + (J(i + 160) - .5f) * .7f) / 12f;
                    var q = Bez(u0, u1, u2, u3, uu); var dq = Bez(u0, u1, u2, u3, Mathf.Min(1f, uu + .02f)) - Bez(u0, u1, u2, u3, Mathf.Max(0f, uu - .02f));
                    var n = new Vector2(-dq.y, dq.x).normalized; if (n.y < 0f) n = -n;
                    float centre = Mathf.Sin(uu * Mathf.PI);
                    float L = s * (.05f + .2f * centre * (.4f + .6f * J(i + 161))) * (.55f + .45f * Mathf.Sin(t * 24f + i * 2.3f)) * open;
                    if (L > .01f * s) Flame(q + n * (.06f * s), Rot(n, (uu - .5f) * .9f * side), L, .07f * s * (.6f + centre * .6f), t, 160 + i, .4f, .55f * open, (J(i + 162) - .5f) * 1.8f, 3f, i % 3 == 0 ? core : band2);
                }
                Flame(w3, (w3 - w2).normalized, s * (.18f + .06f * Mathf.Sin(t * 18f)) * open, .06f * s, t, 171, .45f, .7f * open, side * 1.2f, 3f, band2);
                Flame(u0, new Vector2(-side, .2f), s * (.12f + .04f * Mathf.Sin(t * 20f + 1f)) * open, .05f * s, t, 172, .45f, .6f * open, -side, 3f, band2);
                var l0 = P(-.85f * W, -.04f * s); var l1 = P(-.35f * W, -lift * .75f); var l2 = P(.4f * W, -lift * .7f); var l3 = P(.92f * W, -.01f * s);
                BrushCurve(l0, l1, l2, l3, .04f, .5f, .05f * s, .9f * open, t + 3f, 41, .012f * s);
                BrushCurve(l0, l1, l2, l3, .58f, .97f, .045f * s, .9f * open, t + 5f, 53, .012f * s);
                // Iris with a slit pupil, glancing to one side and back.
                if (open > .25f)
                {
                    var iris = c + new Vector2(.14f * s * Mathf.Sin(t * 11f), 0f);
                    float ir = Mathf.Min(gap * .95f, .2f * s);
                    Glow(iris, ir * 3f, band2, .45f * open);
                    Dot(iris, ir, band2, 0f, open, t * 2f, .04f);
                    Dot(iris, ir * .62f, band3, 0f, open, t * 2f + 3f, .04f);
                    Dot(iris, ir * .5f, new Color(.04f, .1f, .22f), 1f, open, 0f, .01f, .28f, 1.15f);
                    Sparkle(iris + new Vector2(-.35f, .4f) * ir, ir * .9f, core, open, 15f);
                }
            }
            float tb = t - Shut;
            if (tb >= 0f)
            {
                float bu = Inv(0f, .4f, tb);
                for (int k = 0; k < 12; k++)
                {
                    float ang = (k + .6f * J(k + 2)) * 6.283f / 12f; var d = new Vector2(Mathf.Cos(ang) * 1.4f, Mathf.Sin(ang) * .7f).normalized;
                    float L = s * (.4f + .45f * J(k + 12)) * EOut(bu * 2.5f) * (1f - bu);
                    if (L < .02f * s) continue;
                    float curl = (J(k + 60) - .5f) * 1.6f, wid = s * (.1f + .06f * J(k + 70));
                    Flame(c + d * (.2f * s), d, L, wid * 1.8f, t, k + 7, .18f, .26f * (1f - bu), curl, 3f, band2);
                    Flame(c + d * (.2f * s), d, L * .9f, wid * .6f, t, k + 7, .18f, .5f * (1f - bu), curl, 3f, core);
                }
                Shards(c, tb, 6, 93, 1.1f * s, 1f - bu);
                if (tb < .05f) Glow(c, .6f * s, Color.white, .35f * (1f - tb / .05f));
            }
        }

        /// 后手改写 (on the hero): three ribbons of water light climb round him in a loose
        /// helix, bubbles and a few glints rise, a soft droplet swells at his chest and fades.
        /// A support card: it gathers and rises, never bursts.
        void Rewrite(float t)
        {
            float s = size, u = t / duration, live = 1f - u;
            float swell = EOut(Inv(0f, .25f, t)) * (1f - EIn(Inv(.45f, 1f, u)));
            Glow(new Vector2(0f, .3f * s), 2.4f * s, outer, .14f * swell);
            Glow(new Vector2(0f, .3f * s), 1.3f * s, band2, .14f * swell);
            for (int k = 0; k < 3; k++)
            {
                float ph = k * 2.094f + J(k) * .4f;
                float head = Inv(.02f + .06f * k, .7f + .06f * k, t);
                if (head <= 0f) continue;
                float f = 1f - EIn(Inv(.55f, 1f, u));
                // Sample the helix from the head back down its tail.
                const int Segs = 14;
                Vector2 prev = Vector2.zero;
                for (int i = 0; i <= Segs; i++)
                {
                    float hu = head - .35f * i / Segs; if (hu < 0f) break;
                    float y = -1.3f * s + 2.9f * s * EOut(hu);
                    float x = Mathf.Sin(ph + hu * 7f) * .55f * s * (1f - .3f * hu);
                    var p = new Vector2(x, y);
                    if (i > 0)
                    {
                        float a = f * (1f - i / (float)Segs);
                        Taper(prev, p, s * .26f * a, s * .26f * a * .8f, band2, .3f * a);
                        Taper(prev, p, s * .07f * a, s * .055f * a, core, .9f * a);
                    }
                    prev = p;
                }
            }
            float dr = .2f * s * swell;
            if (dr > .01f * s) Dot(new Vector2(0f, .35f * s), dr, band3, 0f, .7f * swell, t * 1.5f, .1f);
            for (int i = 0; i < 10; i++)
            {
                float born = .08f + .5f * J(i + 150); float bu = Inv(born, born + .45f, t); if (bu <= 0f || bu >= 1f) continue;
                var p = new Vector2((J(i + 151) - .5f) * 1.6f * s, -.9f * s + 2.2f * s * bu);
                if (i % 3 == 0) Sparkle(p, s * .12f, hot, Mathf.Sin(bu * Mathf.PI), 15f + bu * 90f);
                else Dot(p, s * (.04f + .03f * J(i + 152)), band3, 0f, Mathf.Sin(bu * Mathf.PI) * .9f, bu * 3f, .05f);
            }
        }

        /// A brush stroke along an arc: its width swells and thins with flowing noise, its
        /// centre line drifts off the circle (wobble), both change every frame, the ends are
        /// needle tips. Painterly cel bands like Crescent.
        void BrushArc(Vector2 c, float r, float a0, float a1, float thick, float fade, float t, int seed, float wobble)
        {
            if (a1 - a0 < .01f || fade <= .01f) return;
            const int N = 26;
            int i0 = vs.Count; seedNow = J(seed);
            for (int i = 0; i <= N; i++)
            {
                float u = (float)i / N; float a = Mathf.Lerp(a0, a1, u);
                float taper = Mathf.Pow(Mathf.Max(0f, Mathf.Sin(u * Mathf.PI)), .55f);
                float w = thick * taper * (.55f + .45f * (Fbm(u * 3.2f + t * 2.6f + seed, seed) * .5f + .5f) * 1.6f);
                var n = new Vector2(Mathf.Cos(a), Mathf.Sin(a));
                var mid = c + n * (r + wobble * Fbm(u * 2.4f - t * 1.8f + seed * .7f, seed + 3f) * 2f);
                V(mid + n * w * 1.15f, 0f, 0f, band3, u, fade, 1f);
                V(mid, 1f, 0f, band3, u, fade, 0f);
                V(mid - n * w * .85f, 0f, 0f, band3, u, fade, -1f);
                if (i > 0)
                {
                    int p = i0 + (i - 1) * 3, q = i0 + i * 3;
                    tris.Add(p); tris.Add(q); tris.Add(p + 1); tris.Add(q); tris.Add(q + 1); tris.Add(p + 1);
                    tris.Add(p + 1); tris.Add(q + 1); tris.Add(p + 2); tris.Add(q + 1); tris.Add(q + 2); tris.Add(p + 2);
                }
            }
            // A soft glow under the stroke, also uneven.
            for (int k = 0; k < 4; k++)
            {
                float k0 = Mathf.Lerp(a0, a1, k / 4f), k1 = Mathf.Lerp(a0, a1, (k + 1) / 4f);
                float g = .5f + .5f * Mathf.Sin(t * 9f + k * 1.7f + seed);
                Arc(c, r, thick * (2.2f + 1.2f * g), k0 * Mathf.Rad2Deg, (k1 - k0) * Mathf.Rad2Deg, band2, (.12f + .1f * g) * fade);
            }
        }

        static Vector2 Bez(Vector2 a, Vector2 b, Vector2 c, Vector2 d, float u)
        {
            float v = 1f - u;
            return v * v * v * a + 3f * v * v * u * b + 3f * v * u * u * c + u * u * u * d;
        }

        /// A brush stroke along the part [s0, s1] of a cubic Bezier: needle ends, width
        /// swelling and thinning with flowing noise, the centre line drifting off the curve,
        /// both changing every frame, and an uneven soft glow under it.
        void BrushCurve(Vector2 a, Vector2 b, Vector2 c, Vector2 d, float s0, float s1, float thick, float fade, float t, int seed, float wobble)
        {
            if (s1 - s0 < .01f || fade <= .01f) return;
            const int N = 24;
            int i0 = vs.Count; seedNow = J(seed);
            for (int i = 0; i <= N; i++)
            {
                float u = (float)i / N, cu = Mathf.Lerp(s0, s1, u);
                var q = Bez(a, b, c, d, cu);
                var dq = Bez(a, b, c, d, Mathf.Min(1f, cu + .01f)) - Bez(a, b, c, d, Mathf.Max(0f, cu - .01f));
                var n = new Vector2(-dq.y, dq.x).normalized;
                float taper = Mathf.Pow(Mathf.Max(0f, Mathf.Sin(u * Mathf.PI)), .55f);
                float w = thick * taper * (.55f + .45f * (Fbm(u * 3.2f + t * 2.6f + seed, seed) * .5f + .5f) * 1.6f);
                var mid = q + n * (wobble * Fbm(u * 2.4f - t * 1.8f + seed * .7f, seed + 3f) * 2f);
                V(mid + n * w * 1.1f, 0f, 0f, band3, u, fade, 1f);
                V(mid, 1f, 0f, band3, u, fade, 0f);
                V(mid - n * w * .9f, 0f, 0f, band3, u, fade, -1f);
                if (i > 0)
                {
                    int p = i0 + (i - 1) * 3, r = i0 + i * 3;
                    tris.Add(p); tris.Add(r); tris.Add(p + 1); tris.Add(r); tris.Add(r + 1); tris.Add(p + 1);
                    tris.Add(p + 1); tris.Add(r + 1); tris.Add(p + 2); tris.Add(r + 1); tris.Add(r + 2); tris.Add(p + 2);
                }
            }
            for (int k = 0; k < 5; k++)
            {
                float k0 = Mathf.Lerp(s0, s1, k / 5f), k1 = Mathf.Lerp(s0, s1, (k + 1) / 5f);
                float g = .5f + .5f * Mathf.Sin(t * 9f + k * 1.7f + seed);
                Taper(Bez(a, b, c, d, k0), Bez(a, b, c, d, k1), thick * (2.4f + 1.2f * g), thick * (2.4f + 1.2f * g), band2, (.1f + .08f * g) * fade);
            }
        }

        /// 钟卫 (clock guard): a great brass clock hand sweeps through the target from the
        /// guard's side in a tenth of a second, leaving a burning smear; at the hit clock ticks
        /// burst outward as short thick dashes (each its own speed: never a ring), gear-tooth
        /// chips fly, the hit spark, brass sparks.
        void Clock(float t)
        {
            float s = size, u = t / duration, live = 1f - u, fade = 1f - EIn(u);
            Glow(Vector2.zero, 2.8f * s, outer, .2f * Mathf.Pow(live, 1.3f));
            Glow(Vector2.zero, 1.6f * s, band2, .24f * Mathf.Pow(live, 1.7f));
            // The hand turns on a hub just above and to the caster's side of the target, so
            // its blade sweeps across the target like a clock's minute hand (e1: a far pivot
            // made a long needle and a bow-shaped smear).
            float side = dir.x >= 0f ? -1f : 1f;
            var pivot = new Vector2(side * .55f * s, .75f * s);
            float L = 1.55f * s;
            float mid = Mathf.Atan2(-pivot.y, -pivot.x);
            float sw = EOut(Inv(0f, .14f, t));
            float a = mid + side * (.95f - 1.9f * sw);
            float hf = 1f - EIn(Inv(.2f, .34f, t));
            if (hf > .01f)
            {
                float aStart = mid + side * .95f;
                float a0 = Mathf.Min(aStart, a), a1 = Mathf.Max(aStart, a);
                // Short burning smear behind the blade's outer half only.
                Arc(pivot, L * .78f, L * .3f, a0 * Mathf.Rad2Deg, (a1 - a0) * Mathf.Rad2Deg, band2, .2f * hf);
                var d = new Vector2(Mathf.Cos(a), Mathf.Sin(a)); var nn = new Vector2(-d.y, d.x);
                // Blade: a cel-banded spear from the hub (Taper's flat e made it a white streak,
                // e2) with a diamond swell near its point and a tail behind the hub.
                Flame(pivot, d, L, .34f * s, t, 7, .02f, hf, 0f, 0f, band3);
                Flame(pivot, -d, .3f * s, .26f * s, t, 8, .02f, hf, 0f, 0f, band3);
                var dia = pivot + d * (L * .68f);
                Flame(dia, d, .32f * s, .3f * s, t, 9, .01f, hf, 0f, 0f, band3);
                Flame(dia, -d, .2f * s, .3f * s, t, 10, .01f, hf, 0f, 0f, band3);
                Gear(pivot, .17f * s, t * 4f, band2, hf);
                Dot(pivot, .08f * s, core, 0f, hf, t, .02f);
            }
            float tc = t - .09f;
            if (tc < 0f) return;
            // The hit is the hand's own cut, not a shared burst (b1: 前4个太像): a hot slash
            // along the sweep through the target, a clock face of ticks flashing out round it,
            // cracks of light like a struck dial's glass, gear chips and brass sparks.
            float cu0 = Inv(0f, .2f, tc);
            if (cu0 < 1f)
            {
                float ta = mid; float span = .55f * (1f - .4f * cu0);
                Crescent(pivot, L * .93f, ta - span, ta + span, .22f * s * (1f - cu0), 1f - cu0, .3f, tc * 3f);
                Arc(pivot, L * .93f, .6f * s * (1f - cu0), (ta - span) * Mathf.Rad2Deg, 2f * span * Mathf.Rad2Deg, band2, .3f * (1f - cu0));
            }
            for (int i = 0; i < 12; i++)
            {
                float ang = i * 6.283f / 12f + (J(i + 220) - .5f) * .2f; var d = new Vector2(Mathf.Cos(ang), Mathf.Sin(ang));
                float k = Inv(0f, .45f, tc);
                float r0 = s * (.55f + 1.1f * EOut(k * 1.3f) * (.6f + .6f * J(i + 221)));
                float len = s * (i % 3 == 0 ? .3f : .16f) * (1f - k);
                if (len > .005f * s) Taper(d * r0, d * (r0 + len), s * (i % 3 == 0 ? .08f : .055f), s * .035f, i % 3 == 0 ? core : hot, 1f - k);
            }
            float cr = Inv(0f, .06f, tc), cf = 1f - EIn(Inv(.12f, .4f, tc));
            Sparkle(Vector2.zero, s * .35f * (1f - cu0), hot, 1f - cu0, 15f);
            for (int i = 0; i < 9; i++)
            {
                float ang = J(i + 230) * 6.283f, sp = s * (1.2f + 1.2f * J(i + 231)), life = .35f + .25f * J(i + 232);
                if (tc > life) continue;
                float cu = tc / life, e = Mathf.Exp(-2.4f * tc), disp = (1f - e) / 2.4f;
                var p = new Vector2(Mathf.Cos(ang), Mathf.Sin(ang)) * sp * disp + Vector2.down * (2.6f * s * tc * tc);
                Gear(p, s * (.07f + .05f * J(i + 233)) * (1f - .5f * cu), tc * (6f + 6f * J(i + 234)), i % 2 == 0 ? band3 : band2, 1f - cu);
            }
            Sparks(Vector2.zero, tc, 18, 79, 1.8f * s, Vector2.zero, fade);
        }

        /// A small gear chip: a disc with five uneven teeth, turning.
        void Gear(Vector2 c, float r, float rot, Color col, float a)
        {
            if (a <= .01f || r <= .001f) return;
            const int Teeth = 5, N = Teeth * 4;
            int i0 = vs.Count; seedNow = 0f; V(c, 1f, 0f, col, .5f, a);
            for (int i = 0; i < N; i++)
            {
                float ang = rot + i * 6.283f / N; float rr = (i % 4 < 2) ? r * 1.35f : r;
                V(c + new Vector2(Mathf.Cos(ang), Mathf.Sin(ang)) * rr, 0f, 0f, col, .5f, a, Mathf.Cos(ang - 2.3f));
            }
            for (int i = 0; i < N; i++) { tris.Add(i0); tris.Add(i0 + 1 + i); tris.Add(i0 + 1 + (i + 1) % N); }
        }

        /// 雾灵 (fog ghost, crimson for the red one): three ghostly tendrils reach round from
        /// behind the target and clutch it, a cold burst where they meet, mist wisps swirl out
        /// and away, frost motes.
        void Ghost(float t)
        {
            float s = size, u = t / duration, live = 1f - u, fade = 1f - EIn(u);
            Glow(Vector2.zero, 2.8f * s, outer, .22f * Mathf.Pow(live, 1.2f));
            Glow(Vector2.zero, 1.6f * s, band2, .26f * Mathf.Pow(live, 1.6f));
            // The strike (user 2026-10-09: 上面几条不像冰): three faceted ice lances dive in from
            // above and both sides, each dragging a trail of white frost mist that thins out
            // behind it; they shatter into chips where they land, and the spikes burst from there.
            for (int k = 0; k < 3; k++)
            {
                float ang = (k == 0 ? 150f : k == 1 ? 98f : 35f) * Mathf.Deg2Rad + (J(k + 240) - .5f) * .2f;
                var start = new Vector2(Mathf.Cos(ang), Mathf.Sin(ang)) * (2.5f * s);
                var end = new Vector2((k - 1) * .3f * s, -.35f * s + (J(k + 241) - .5f) * .2f * s);
                var d = (end - start).normalized;
                float born = .04f * Mathf.Abs(k - 1) + .01f * J(k + 242), arrive = born + .13f;
                float mv = Inv(born, arrive, t); if (mv <= 0f) continue;
                var tip = Vector2.Lerp(start, end, Mathf.Pow(mv, 1.5f));
                if (mv < 1f)
                {
                    float L = s * (.95f + .25f * J(k + 243));
                    Crystal(tip - d * L, d, L, s * (.2f + .05f * J(k + 244)), 1f);
                    Glow(tip, .45f * s, core, .5f);
                }
                // Frost trail: puffs laid down as the lance passed, swelling and thinning.
                for (int m = 0; m < 9; m++)
                {
                    float at = m / 8f * Mathf.Min(mv, 1f);
                    float passed = born + .13f * Mathf.Pow(at, 1f / 1.5f);
                    float age = (t - passed) / .38f; if (age < 0f || age >= 1f) continue;
                    var pp = Vector2.Lerp(start, end, Mathf.Pow(at, 1.5f)) + new Vector2(0f, .15f * s * age) + new Vector2(-d.y, d.x) * ((J(k * 9 + m + 300) - .5f) * .2f * s);
                    float r = s * (.12f + .1f * J(k * 9 + m + 301)) * (1f + 1.4f * EOut(age)) * (.5f + .5f * at);
                    Dot(pp, r, Color.Lerp(core, Color.white, .45f), 2f, .38f * (1f - EIn(age)) * (.4f + .6f * at), t + m, .3f, 1.25f, .8f);
                }
                // Shatter on landing: chips kick back up the way the lance came.
                float st = t - arrive;
                if (st > 0f)
                    for (int c = 0; c < 5; c++)
                    {
                        float life = .25f + .15f * J(k * 5 + c + 320); if (st > life) continue;
                        float cu = st / life, ca = Mathf.Atan2(-d.y, -d.x) + (J(k * 5 + c + 321) - .5f) * 2.2f;
                        var cv = new Vector2(Mathf.Cos(ca), Mathf.Sin(ca));
                        var cp = end + cv * (s * (.9f + .8f * J(k * 5 + c + 322)) * (1f - Mathf.Exp(-3f * st)) / 3f * 3f) + Vector2.down * (2.2f * s * st * st);
                        Crystal(cp, Rot(cv, st * 8f), s * (.13f + .08f * J(k * 5 + c + 323)) * (1f - .3f * cu), s * .08f, 1f - EIn(cu));
                    }
            }
            float tc = t - .12f;
            if (tc < 0f) return;
            // The hit: frost (UE reference, 2026-10-09): a cluster of faceted ice crystals bursts
            // up out of a low snow cloud at the target's feet - lit and shadow faces, bright
            // ridges - snowflakes and small ice chips fly, the mist is sucked in on a spiral.
            float gu = Inv(0f, .1f, tc), gf = 1f - EIn(Inv(.22f, .52f, tc));
            var foot = new Vector2(0f, -.8f * s);
            SnowCloud(foot, 1.15f * s, tc, 1f - EIn(Inv(.2f, .62f, tc)));
            // Spikes burst up in three uneven clumps at the feet (left, centre, right), each clump
            // radiating from its own root with the middle spike longest; the clumps lean out so
            // the target stays readable between them. Then they sink a little as they shatter.
            float sink = EIn(Inv(.24f, .5f, tc));
            int q = 0;
            for (int g = 0; g < 3; g++)
            {
                float gx = (g - 1) * .8f * s + (J(g + 290) - .5f) * .25f * s;
                int count = g == 1 ? 3 : 4 + (J(g + 291) > .5f ? 1 : 0);
                float lean = (g - 1) * (24f + 10f * J(g + 292));
                float born0 = g == 1 ? 0f : .02f + .03f * J(g + 293);
                float scale = g == 1 ? .7f : 1f + .25f * J(g + 294);
                for (int c = 0; c < count; c++, q++)
                {
                    float sf = count == 1 ? 0f : (c / (count - 1f) - .5f) * 2f;
                    float ang = (90f - lean - sf * (26f + 12f * J(q + 262)) + (J(q + 263) - .5f) * 10f) * Mathf.Deg2Rad;
                    var d = new Vector2(Mathf.Cos(ang), Mathf.Sin(ang));
                    float born = born0 + .015f * Mathf.Abs(sf) + .012f * J(q + 266);
                    float tall = scale * (1.25f - .7f * Mathf.Abs(sf)) * (.7f + .45f * J(q + 264));
                    float L = s * tall * EOut(Inv(born, born + .07f, tc)) * (1f - .35f * sink);
                    var b = foot + new Vector2(gx + sf * .12f * s, (J(q + 265) - .5f) * .1f * s - .2f * s * sink);
                    Crystal(b, d, L, s * (.24f + .16f * J(q + 267)) * (1.1f - .3f * Mathf.Abs(sf)), gf);
                }
            }
            for (int i = 0; i < 16; i++)
            {
                bool late = i >= 6; float t0 = late ? .26f + .04f * J(i + 279) : 0f;
                float tt = tc - t0; if (tt < 0f) continue;
                float ang = (25f + 130f * J(i + 270)) * Mathf.Deg2Rad, sp = s * (late ? 1f : 1.6f) * (.8f + .9f * J(i + 271)), life = .3f + .25f * J(i + 272);
                if (tt > life) continue;
                float cu = tt / life, e = Mathf.Exp(-2.4f * tt), disp = (1f - e) / 2.4f;
                var o = late ? foot + new Vector2((J(i + 280) - .5f) * 1.7f * s, (.3f + .9f * J(i + 281)) * s) : foot;
                var p = o + new Vector2(Mathf.Cos(ang), Mathf.Sin(ang)) * sp * disp + Vector2.down * (2.4f * s * tt * tt);
                Crystal(p, new Vector2(Mathf.Cos(ang + tt * 7f), Mathf.Sin(ang + tt * 7f)), s * (.1f + .1f * J(i + 273)) * (1f - .3f * cu), s * .08f, 1f - EIn(cu));
            }
            for (int i = 0; i < 9; i++)
            {
                float born = .03f + .25f * J(i + 275); float a = Inv(born, born + .5f, tc); if (a <= 0f || a >= 1f) continue;
                var p = new Vector2((J(i + 276) - .5f) * 2.4f * s, (J(i + 277) * 1.6f - .2f) * s) + Vector2.down * (.4f * s * a);
                Snowflake(p, s * (.1f + .07f * J(i + 278)), a * 2f + i, Mathf.Sin(a * Mathf.PI));
            }
            for (int i = 0; i < 9; i++)
            {
                float mu = Inv(0f, .55f, tc); if (mu >= 1f) break;
                float ang = i * 6.283f / 9f - tc * 4f + J(i + 260) * .6f;
                float r = s * (1.6f - 1.1f * EOut(mu)) * (.85f + .3f * J(i + 261));
                var p = new Vector2(Mathf.Cos(ang), Mathf.Sin(ang) * .8f) * r;
                Dot(p, s * (.16f + .1f * J(i + 262)) * (1f - .4f * mu), Color.Lerp(core, Color.white, .4f), 2f, .3f * (1f - EIn(mu)), tc + i, .3f, 1.3f, .8f);
            }
            Glow(Vector2.zero, .9f * s, core, .25f * gf * (1f - gu * .5f));
            for (int i = 0; i < 10; i++)
            {
                float born = .05f + .3f * J(i + 265); float a = Inv(born, born + .45f, tc); if (a <= 0f || a >= 1f) continue;
                var p = new Vector2((J(i + 266) - .5f) * 2f * s, (J(i + 267) - .3f) * 1.6f * s) + Vector2.down * (.3f * s * a);
                Sparkle(p, s * (.1f + .06f * J(i + 268)), core, Mathf.Sin(a * Mathf.PI), 15f + a * 90f);
            }
        }

        /// 红雾灵 (crimson ghost): crimson ribbons wind round the target in loose loops and
        /// pull tight like binding chains (never a closed ring: open spirals that tighten),
        /// then snap into torn crimson shreds and petals.
        void Bind(float t)
        {
            float s = size, u = t / duration, live = 1f - u, fade = 1f - EIn(u);
            Glow(Vector2.zero, 2.8f * s, outer, .22f * Mathf.Pow(live, 1.2f));
            Glow(Vector2.zero, 1.6f * s, band2, .26f * Mathf.Pow(live, 1.6f));
            float wind = EOut(Inv(0f, .14f, t)), tight = EOut(Inv(.08f, .24f, t));
            const float Snap = .3f;
            float f = 1f - EIn(Inv(Snap - .04f, Snap + .04f, t));
            for (int k = 0; k < 3 && f > .01f; k++)
            {
                float y = (k - 1) * .42f * s;
                float r = s * (1.15f - .55f * tight) * (k == 1 ? 1f : .85f);
                float a0 = k * 2.1f + J(k + 340) * .5f;
                float a1 = a0 + 5.2f * wind;
                // Each loop is an ellipse squashed to read as wrapping round the body.
                const int N = 30; int i0 = vs.Count; seedNow = J(k + 341);
                for (int i = 0; i <= N; i++)
                {
                    float uu = (float)i / N, a = Mathf.Lerp(a0, a1, uu);
                    var n = new Vector2(Mathf.Cos(a), Mathf.Sin(a) * .35f);
                    var mid = n * r + new Vector2(0f, y + (uu - .5f) * .3f * s);
                    float w = .11f * s * Mathf.Pow(Mathf.Max(0f, Mathf.Sin(uu * Mathf.PI)), .5f) * (1f + .3f * Fbm(uu * 4f + t * 3f, k));
                    float front = Mathf.Sin(a) < 0f ? 1f : .55f;      // the back half of each loop dimmer
                    V(mid + new Vector2(0f, w), 0f, 0f, band3, uu, f * front, 1f); V(mid, 1f, 0f, band3, uu, f * front, 0f); V(mid - new Vector2(0f, w), 0f, 0f, band3, uu, f * front, -1f);
                    if (i > 0)
                    {
                        int p = i0 + (i - 1) * 3, q = i0 + i * 3;
                        tris.Add(p); tris.Add(q); tris.Add(p + 1); tris.Add(q); tris.Add(q + 1); tris.Add(p + 1);
                        tris.Add(p + 1); tris.Add(q + 1); tris.Add(p + 2); tris.Add(q + 1); tris.Add(q + 2); tris.Add(p + 2);
                    }
                }
            }
            float ts = t - Snap;
            if (ts < 0f) return;
            // Snap: torn shreds and petals thrown outward, spinning.
            for (int i = 0; i < 16; i++)
            {
                float ang = J(i + 350) * 6.283f, sp = s * (1.3f + 1.4f * J(i + 351)), life = .4f + .3f * J(i + 352);
                if (ts > life) continue;
                float cu = ts / life, e = Mathf.Exp(-2.2f * ts), disp = (1f - e) / 2.2f;
                var d = new Vector2(Mathf.Cos(ang), Mathf.Sin(ang) * .7f);
                var p = d * sp * disp + new Vector2(0f, (J(i + 353) - .5f) * .8f * s) + Vector2.down * (1.6f * s * ts * ts);
                float L = s * (.2f + .14f * J(i + 354)) * (1f - .5f * cu);
                Flame(p, Rot(d, ts * (6f + 4f * J(i + 355))), L, L * .55f, ts, 350 + i, .2f, 1f - cu, (J(i + 356) - .5f) * 2f, 0f, i % 3 == 0 ? core : band3);
            }
            if (ts < .08f) Glow(Vector2.zero, 1.2f * s, band2, .5f * (1f - ts / .08f));
            Sparks(Vector2.zero, ts, 14, 85, 1.6f * s, Vector2.zero, fade);
        }

        /// 猎犬 (fire hound, not the early claw): a bite - an upper and a lower jaw of flame
        /// fangs snap shut on the target, a fire burst between them, flame tongues thrown out,
        /// embers rising.
        void Bite(float t)
        {
            float s = size, u = t / duration, live = 1f - u, fade = 1f - EIn(u);
            Glow(Vector2.zero, 2.8f * s, outer, .22f * Mathf.Pow(live, 1.2f));
            Glow(Vector2.zero, 1.6f * s, band2, .28f * Mathf.Pow(live, 1.6f));
            // A mouth: two strongly curved jaws (upper concave down, lower concave up) that
            // open wide and snap shut on the target, four curved fangs on each, the lower jaw
            // shorter (e1: shallow jaws read as a toothed box).
            float close = EOut(Inv(0f, .09f, t)), f = 1f - EIn(Inv(.15f, .38f, t));
            for (int k = 0; k < 2 && f > .01f; k++)
            {
                float side = k == 0 ? 1f : -1f;                 // upper, lower
                float open = s * (.75f - .62f * close);
                float Rj = .85f * s;
                var cc = new Vector2(0f, side * (open - Rj * .35f));
                float midA = side * Mathf.PI * .5f;               // the jaw arcs over the top / under the bottom
                float hs = k == 0 ? 1.15f : .95f;
                Arc(cc, Rj, .45f * s, (midA - hs) * Mathf.Rad2Deg, 2f * hs * Mathf.Rad2Deg, band2, .25f * f);
                Crescent(cc, Rj, midA - hs, midA + hs, (k == 0 ? .26f : .2f) * s, f, .3f, t * 2f + k);
                for (int i = 0; i < 4; i++)
                {
                    float a = midA + (i - 1.5f) / 1.5f * hs * .78f;
                    var n = new Vector2(Mathf.Cos(a), Mathf.Sin(a));
                    var root = cc + n * (Rj - .1f * s);
                    float L = s * ((i == 0 || i == 3) ? .42f : .3f) * (k == 0 ? 1f : .8f);
                    // Fangs point inward to the mouth's middle and curve toward its centre line.
                    Flame(root, -n, L, .17f * s, t, 270 + i + k * 4, .06f, f, (i < 2 ? 1f : -1f) * side * .5f, 0f, core);
                }
            }
            float tc = t - .09f;
            if (tc < 0f) return;
            // The hit: where the jaws met - a hot bite line, fang punctures glowing in two rows,
            // fire spurting out sideways from the bite, embers (b1: no shared burst).
            float bu = Inv(0f, .2f, tc), bf = 1f - EIn(Inv(.15f, .45f, tc));
            if (bu < 1f) Crescent(new Vector2(0f, 2.4f * s), 2.4f * s, -Mathf.PI * .5f - .32f, -Mathf.PI * .5f + .32f, .12f * s * (1f - bu), 1f - bu, 0f, tc * 3f);
            for (int r = 0; r < 2; r++)
                for (int i = 0; i < 4; i++)
                {
                    var p = new Vector2((i - 1.5f) * .28f * s, (r == 0 ? .14f : -.14f) * s);
                    if (bf > .01f) Drop(p, new Vector2(0f, r == 0 ? 1f : -1f), s * .22f * bf, s * .07f, core, 0f);
                    Glow(p, .16f * s, band2, .35f * bf);
                }
            for (int k = 0; k < 6; k++)
            {
                float side = k % 2 == 0 ? 1f : -1f;
                var d = new Vector2(side, (J(k + 285) - .5f) * .9f).normalized;
                float L = s * (.55f + .45f * J(k + 286)) * EOut(Inv(0f, .12f, tc)) * (1f - EIn(Inv(.12f, .45f, tc)));
                if (L > .02f * s) Flame(new Vector2(side * .45f * s, (J(k + 287) - .5f) * .2f * s), d, L, .24f * s, tc, 285 + k, .25f, bf, side * (J(k + 288) - .3f), 0f, band3);
            }
            for (int i = 0; i < 12; i++)
            {
                float born = .02f + .2f * J(i + 290); float a = Inv(born, born + .5f, tc); if (a <= 0f || a >= 1f) continue;
                float ang = J(i + 291) * 6.283f; var p = new Vector2(Mathf.Cos(ang), Mathf.Sin(ang)) * (.3f + .5f * J(i + 292)) * s + Vector2.up * (.8f * s * a);
                Dot(p, (.05f - .02f * a) * s, Color.Lerp(core, band2, a), 3f, (1f - a) * .9f);
            }
            Sparks(Vector2.zero, tc, 18, 81, 1.8f * s, Vector2.up * .3f, fade);
        }

        /// 书记员 (scribe): one thick calligraphy stroke of glossy ink slashes across the target
        /// in .08 s - dark violet ink with a gold edge light - ink drops fling off its end, gold
        /// leaf flecks glint, a small gold hit spark.
        void InkSlash(float t)
        {
            // A thrown ink splash, deliberately irregular (e5: 太规整 - seven even tongues and
            // droplets spaced on an arc). The ink is flung from the scribe's side: a flick
            // streak arrives, a lopsided splat lands, tongues burst mostly away from the
            // scribe - a few long, many short, each its own width and curl, some forked - and
            // pinch off droplets of every size at different moments; tiny satellite dots spray
            // further; an uneven puddle splat on the floor; gold leaf glints.
            float s = size, u = t / duration, live = 1f - u, fade = 1f - EIn(u);
            Glow(Vector2.zero, 2.2f * s, Hex("7A22D0"), .12f * Mathf.Pow(live, 1.3f));
            Glow(Vector2.zero, 1.2f * s, hot, .1f * Mathf.Pow(live, 2f));
            float away = Mathf.Atan2(dir.y, dir.x);              // from the scribe toward and past the target
            float up = Mathf.PI * .5f, bias = Mathf.LerpAngle(up * Mathf.Rad2Deg, away * Mathf.Rad2Deg, .55f) * Mathf.Deg2Rad;
            // The flick: a thin streak arriving from the scribe in the first .07 s.
            float fl = EOut(Inv(0f, .07f, t)), ff = 1f - EIn(Inv(.07f, .2f, t));
            if (ff > .01f)
            {
                var from = -dir * (1.8f * s) + new Vector2(0f, .5f * s);
                BrushCurve(from, Vector2.Lerp(from, Vector2.zero, .35f) + new Vector2(0f, .35f * s), Vector2.Lerp(from, Vector2.zero, .75f) + new Vector2(0f, .15f * s), Vector2.zero, Mathf.Max(0f, fl - .45f), fl, .12f * s, ff, t, 309, .02f * s);
            }
            float tc = t - .06f;
            if (tc < 0f) return;
            float cf = 1f - EIn(Inv(.16f, .44f, tc));
            // A lopsided splat body, stretched along the throw.
            float R = .38f * s * EOut(Inv(0f, .05f, tc)) * (1f - EIn(Inv(.05f, .26f, tc)));
            if (R > .01f * s) Dot(dir * (.12f * s), R, band3, 0f, 1f, tc * 2f + 1.7f, .38f, 1.25f + .25f * Mathf.Abs(dir.x), .85f);
            for (int k = 0; k < 10; k++)
            {
                float spread = (J(k + 300) - .5f) * 2f;               // -1..1
                float ang = bias + spread * 1.35f + (J(k + 307) - .5f) * .3f;
                var d = new Vector2(Mathf.Cos(ang), Mathf.Sin(ang));
                if (d.y < -.25f) d = new Vector2(d.x, -.25f).normalized;   // nothing dives into the floor
                float longness = Mathf.Pow(J(k + 301), 1.8f);
                float L = s * (.22f + 1.25f * longness) * (1f - .35f * Mathf.Abs(spread)) * EOut(Inv(0f, .1f + .06f * J(k + 302), tc)) * (1f - .45f * Inv(.16f, .44f, tc));
                float w = s * (.12f + .26f * J(k + 303)) * (.6f + .6f * longness);
                if (L < .02f * s || cf < .01f) continue;
                float curl = (J(k + 304) - .5f) * 1.8f;
                var b = d * (.12f * s);
                Flame(b, d, L, w, tc, 300 + k, .16f, cf, curl, 0f, band3);
                // A long tongue may fork near its tip.
                if (longness > .45f)
                    Flame(b + Rot(d, curl * .2f) * (L * .55f), Rot(d, (J(k + 308) > .5f ? .55f : -.55f)), L * .4f, w * .45f, tc, 320 + k, .2f, cf, -curl, 0f, band3);
                // The droplet it pinches off: each tongue at its own moment, its own size.
                float born = .05f + .14f * J(k + 305), fly = Inv(born, born + .45f + .2f * J(k + 306), tc);
                if (fly > 0f && fly < 1f)
                {
                    var tip = b + Rot(d, curl * .25f) * (L * .95f);
                    var v = Rot(d, curl * .3f) * (s * (.9f + 1.3f * longness));
                    var p = tip + v * fly + Vector2.down * (2.4f * s * fly * fly);
                    float ds = s * (.05f + .16f * J(k + 309));
                    Drop(p, -(v + Vector2.down * (4.8f * s * fly)).normalized, ds * 2.1f * (1f - .3f * fly), ds, band3, 0f);
                }
            }
            // Satellite dots: tiny, many sizes, sprayed further along the throw.
            for (int i = 0; i < 16; i++)
            {
                float ang = bias + (J(i + 340) - .5f) * 2.6f; var d = new Vector2(Mathf.Cos(ang), Mathf.Max(-.2f, Mathf.Sin(ang)));
                float sp = s * (1.2f + 2f * J(i + 341)), life = .3f + .35f * J(i + 342), age = tc - .02f * J(i + 343);
                if (age < 0f || age > life) continue;
                float e = Mathf.Exp(-2f * age), disp = (1f - e) / 2f;
                var p = d * sp * disp + Vector2.down * (2.6f * s * age * age);
                Dot(p, s * (.015f + .04f * J(i + 344) * J(i + 345)), band3, 0f, 1f - age / life, age * 3f, .2f);
            }
            // An uneven floor splat under the target: a flattened irregular puddle and short runs.
            float pu = EOut(Inv(.02f, .14f, tc)), pf = 1f - EIn(Inv(.3f, .6f, tc));
            if (pf > .01f)
            {
                var c = new Vector2(dir.x * .15f * s, -.85f * s);
                Dot(c, .4f * s * pu, band3, 0f, pf, 3.1f, .42f, 1.9f, .32f);
                for (int k = 0; k < 4; k++)
                {
                    float side = (J(k + 350) > .4f ? 1f : -1f) * Mathf.Sign(dir.x == 0f ? 1f : dir.x);
                    float L = s * (.2f + .45f * J(k + 351)) * pu;
                    Flame(c + new Vector2(side * .3f * s, (J(k + 352) - .5f) * .08f * s), new Vector2(side, (J(k + 353) - .5f) * .25f), L, .1f * s, tc, 350 + k, .1f, pf, 0f, 0f, band3);
                }
            }
            for (int i = 0; i < 9; i++)
            {
                float gu = Inv(.03f + .03f * J(i + 330) * 4f, .28f + .05f * i, tc); if (gu <= 0f || gu >= 1f) continue;
                float ang = bias + (J(i + 331) - .5f) * 2.4f; var p = new Vector2(Mathf.Cos(ang), Mathf.Sin(ang)) * s * (.4f + 1.1f * J(i + 332)) + Vector2.down * (.4f * s * gu);
                Sparkle(p, s * (.07f + .1f * J(i + 333)) * (1f - .5f * gu), hot, 1f - gu, 15f + t * 200f);
            }
        }

        /// A lightning bolt from a to b by midpoint displacement, re-struck 24 times a second
        /// (seed changes), drawn in additive layers: wide coloured glow, coloured body, white
        /// core. Branches fork off part way.
        void Lightning(Vector2 a, Vector2 b, int seed, float width, float alpha, int branches)
        {
            if (alpha <= .01f) return;
            var pts = new List<Vector2> { a, b };
            float disp = (b - a).magnitude * .22f;
            for (int it = 0; it < 4; it++)
            {
                var next = new List<Vector2> { pts[0] };
                for (int i = 0; i < pts.Count - 1; i++)
                {
                    var p = pts[i]; var q = pts[i + 1]; var d = q - p; var nn = new Vector2(-d.y, d.x).normalized;
                    next.Add((p + q) * .5f + nn * ((Hash(seed * 13 + it * 31 + i, seed) - .5f) * 2f * disp)); next.Add(q);
                }
                pts = next; disp *= .52f;
            }
            for (int i = 0; i < pts.Count - 1; i++)
            {
                Taper(pts[i], pts[i + 1], width * 2.2f, width * 2.2f, band2, .22f * alpha);
                Taper(pts[i], pts[i + 1], width, width, band3, .9f * alpha);
                Taper(pts[i], pts[i + 1], width * .4f, width * .4f, core, alpha);
            }
            for (int k = 0; k < branches; k++)
            {
                int i = 3 + (int)(Hash(seed + k * 7, 3f) * (pts.Count - 6));
                var main = (b - a).normalized;
                var bd = Rot(main, (Hash(seed + k * 11, 5f) > .5f ? 1f : -1f) * (.4f + .5f * Hash(seed + k, 9f)));
                Lightning(pts[i], pts[i] + bd * ((b - a).magnitude * (.2f + .2f * Hash(seed + k * 3, 4f))), seed * 7 + k + 1, width * .55f, alpha * .85f, 0);
            }
        }

        /// 档案馆馆员 (archivist): a lightning bolt drops out of the sky onto the target and
        /// flickers there, then crackling arcs run over the body and along the floor, gold
        /// sparks spit, a cold flash.
        void BoltStrike(float t)
        {
            float s = size, u = t / duration, live = 1f - u, fade = 1f - EIn(u);
            int fr = Mathf.FloorToInt(t * 24f);
            float drop = EOut(Inv(0f, .05f, t)), bf = 1f - EIn(Inv(.12f, .3f, t));
            var top = new Vector2((dir.x >= 0f ? -.6f : .6f) * s, 4.2f * s);
            if (bf > .01f) Lightning(top, Vector2.Lerp(top, Vector2.zero, drop), fr, .11f * s, bf * (.75f + .25f * Hash(fr, 2f)), 3);
            float tc = t - .05f;
            if (tc < 0f) return;
            float cl = Inv(0f, .08f, tc), cf = 1f - EIn(Inv(.1f, .45f, tc));
            Glow(Vector2.zero, 2.6f * s, outer, .22f * cf);
            Glow(Vector2.zero, 1f * s, core, .2f * (1f - cl) + .08f * cf);
            // Crackle arcs: short bolts jumping over the body, re-struck each frame.
            for (int k = 0; k < 5 && cf > .01f; k++)
            {
                float ang = (k * 1.3f + Hash(fr + k, 8f) * 1.2f);
                var d = new Vector2(Mathf.Cos(ang), Mathf.Sin(ang));
                Lightning(d * (.15f * s), d * (s * (.6f + .5f * Hash(fr * 3 + k, 6f))), fr * 5 + k, .06f * s, cf * .9f, 1);
            }
            // Arcs running along the floor line to both sides.
            for (int k = 0; k < 2 && cf > .01f; k++)
            {
                float side = k == 0 ? -1f : 1f;
                var a = new Vector2(0f, -.8f * s); var b = a + new Vector2(side * s * (.8f + .9f * EOut(cl)), (Hash(fr + k * 9, 2f) - .5f) * .2f * s);
                Lightning(a, b, fr * 11 + k, .07f * s, cf, 1);
            }
            for (int i = 0; i < 14; i++)
            {
                float ang = J(i + 360) * 6.283f, sp = s * (1.3f + 1.5f * J(i + 361)), life = .25f + .25f * J(i + 362);
                if (tc > life) continue;
                float e = Mathf.Exp(-2.4f * tc), disp = (1f - e) / 2.4f;
                var p = new Vector2(Mathf.Cos(ang), Mathf.Sin(ang)) * sp * disp + Vector2.down * (2.4f * s * tc * tc);
                Taper(p, p - new Vector2(Mathf.Cos(ang), Mathf.Sin(ang)) * (.14f * s * (1f - tc / life)), .04f * s, 0f, hot, 1f - tc / life);
            }
        }

        /// 记忆水蛭 (memory leech): it drinks - a twisting stream of violet light is pulled out
        /// of the target back toward the leech, carrying little glowing memory motes, and a
        /// dark hollow opens and closes in the target where it was drained.
        void Drain(float t)
        {
            float s = size, u = t / duration, live = 1f - u;
            var back = -dir;                                          // toward the leech
            var side = new Vector2(-back.y, back.x);
            float pull = EOut(Inv(0f, .15f, t)), pf = 1f - EIn(Inv(.42f, .8f, t));
            Glow(Vector2.zero, 2.4f * s, outer, .22f * pf);
            // The hollow: a dark irregular wound in the target, rimmed with light.
            float hu = Inv(.02f, .12f, t), hf = 1f - EIn(Inv(.35f, .7f, t));
            if (hf > .01f)
            {
                // The wound is a vortex being drawn in (e: a black disc read as a sticker): two
                // open spirals turning inward, a small hot centre.
                float spin = t * 9f;
                for (int k = 0; k < 3; k++)
                {
                    float a0 = spin + k * 2.094f + J(k + 375) * .8f, len = (2.4f + 2.2f * J(k + 376)) * EOut(hu);
                    Spiral(a0, a0 + len, a0, (.42f + .3f * J(k + 377)) * s, .06f * s, (.07f + .06f * J(k + 378)) * s, hf, t + k);
                }
                Glow(Vector2.zero, .6f * s, band2, .4f * hf);
                Dot(Vector2.zero, .1f * s * EOut(hu), core, 0f, hf, t, .1f);
            }
            // Three twisting strands, each a chain of soft additive segments, pulled away.
            for (int k = 0; k < 3; k++)
            {
                const int Segs = 18; Vector2 prev = Vector2.zero;
                for (int i = 0; i <= Segs; i++)
                {
                    float uu = i / (float)Segs;
                    float along = uu * 2.4f * s * pull;
                    float wob = Mathf.Sin(uu * 9f - t * 18f + k * 2.1f) * .3f * s * Mathf.Sin(uu * Mathf.PI);
                    var p = back * along + side * wob;
                    if (i > 0)
                    {
                        float a = pf * (1f - uu * .7f);
                        Taper(prev, p, s * .3f * (1f - uu * .6f), s * .3f * (1f - uu * .6f), band2, .22f * a);
                        Taper(prev, p, s * .08f * (1f - uu * .5f), s * .08f * (1f - uu * .5f), band3, .8f * a);
                    }
                    prev = p;
                }
            }
            // Memory motes riding the stream away, each its own speed.
            for (int i = 0; i < 12; i++)
            {
                float born = .05f + .4f * J(i + 370), mu = Inv(born, born + .35f, t); if (mu <= 0f || mu >= 1f) continue;
                var p = back * (2.4f * s * mu) + side * (Mathf.Sin(mu * 9f + i) * .3f * s);
                Sparkle(p, s * (.09f + .06f * J(i + 371)), i % 3 == 0 ? hot : core, Mathf.Sin(mu * Mathf.PI), 15f + mu * 200f);
            }
        }

        static readonly Color BrassDark = new Color(.36f, .2f, .06f), Brass = new Color(.86f, .56f, .16f), BrassBody = new Color(1f, .78f, .32f), BrassCore = new Color(1f, .96f, .82f);
        Color pO, pB2, pB3, pC;
        /// Draw the next shapes in another palette (brass parts inside a teal or green spell).
        void PushPal(Color o, Color b2, Color b3, Color c) { pO = outer; pB2 = band2; pB3 = band3; pC = core; outer = o; band2 = b2; band3 = b3; core = c; }
        void PopPal() { outer = pO; band2 = pB2; band3 = pB3; core = pC; }

        void Disc(Vector2 c, float r, Color col, float a)
        {
            const int N = 24; int i0 = vs.Count; seedNow = 0f; V(c, 1f, 1f, col, .5f, a);
            for (int i = 0; i < N; i++) { float ang = i * 6.283f / N; V(c + new Vector2(Mathf.Cos(ang), Mathf.Sin(ang)) * r, 1f, 1f, col, .5f, a); }
            for (int i = 0; i < N; i++) { tris.Add(i0); tris.Add(i0 + 1 + i); tris.Add(i0 + 1 + (i + 1) % N); }
        }

        /// A small glowing brass cog in the painterly bands (dark bronze rim on the teeth, gold
        /// body, cream heart), with four dark windows between its spokes so it reads as a
        /// turning wheel, and a dark hub.
        void Cog(Vector2 c, float r, float rot, int teeth, float a)
        {
            if (a <= .01f || r <= .001f) return;
            PushPal(BrassDark, Brass, BrassBody, BrassCore);
            int N = teeth * 4; int i0 = vs.Count; seedNow = J(teeth + 7);
            V(c, 1f, 0f, band3, .5f, a);
            for (int i = 0; i < N; i++)
            {
                float ang = rot + i * 6.283f / N; float rr = (i % 4 == 1 || i % 4 == 2) ? r * 1.2f : r;
                V(c + new Vector2(Mathf.Cos(ang), Mathf.Sin(ang)) * rr, 0f, 0f, band3, .5f, a, Mathf.Cos(ang - 2.3f));
            }
            for (int i = 0; i < N; i++) { tris.Add(i0); tris.Add(i0 + 1 + i); tris.Add(i0 + 1 + (i + 1) % N); }
            Disc(c, r * .26f, BrassDark, a);
            Dot(c, r * .08f, BrassCore, 3f, a);
            PopPal();
        }

        /// The sweep of a clock hand: a painterly stroke along an arc that swells toward its
        /// head and ends in a point there, thin at the tail (tail and head are angles; the
        /// head may be either side of the tail).
        void Swoosh(Vector2 c, float r, float tail, float head, float thick, float fade, float t, int seed)
        {
            if (Mathf.Abs(head - tail) < .01f || fade <= .01f) return;
            const int N = 26; int i0 = vs.Count; seedNow = J(seed);
            for (int i = 0; i <= N; i++)
            {
                float u = (float)i / N, a = Mathf.Lerp(tail, head, u);
                float prof = Mathf.Pow(u, .9f) * Mathf.Sqrt(Mathf.Max(0f, 1f - Mathf.Pow(u, 6f)));
                float w = thick * prof * (.75f + .5f * (Fbm(u * 3f + t * 2.6f + seed, seed) * .5f + .5f));
                var n = new Vector2(Mathf.Cos(a), Mathf.Sin(a));
                var mid = c + n * (r + .06f * thick * Fbm(u * 4f - t * 2f, seed + 3f));
                V(mid + n * w, 0f, 0f, band3, u, fade, 1f); V(mid, 1f, 0f, band3, u, fade, 0f); V(mid - n * w * .8f, 0f, 0f, band3, u, fade, -1f);
                if (i > 0)
                {
                    int p = i0 + (i - 1) * 3, q = i0 + i * 3;
                    tris.Add(p); tris.Add(q); tris.Add(p + 1); tris.Add(q); tris.Add(q + 1); tris.Add(p + 1);
                    tris.Add(p + 1); tris.Add(q + 1); tris.Add(p + 2); tris.Add(q + 1); tris.Add(q + 2); tris.Add(p + 2);
                }
            }
        }

        /// A brass clock hand on the circle at angle ang: a needle shaft from the pivot and a spade tip pointing out.
        void HandTip(Vector2 c, float r, float ang, float dir, float len, float a)
        {
            if (a <= .01f) return;
            var n = new Vector2(Mathf.Cos(ang), Mathf.Sin(ang)); var tg = new Vector2(-n.y, n.x) * dir;
            var p = c + n * r;
            PushPal(BrassDark, Brass, BrassBody, BrassCore);
            // The shaft from the pivot (a long thin faceted needle), then the spade tip.
            Crystal(c + n * (r * .1f), n, r * .78f, len * .26f, .85f * a);
            Crystal(p - n * (len * .55f), n, len * .9f, len * .6f, a);
            PopPal();
            Glow(p, len * 1.2f, BrassCore, .45f * a);
        }

        /// 时钟核心 (clock core; user 2026-10-09: 时钟不行 - three teal sticks with blobs):
        /// two clock hands whirl round the target - painterly cyan sweeps with brass spade
        /// tips - and both slam onto twelve: time freezes, space cracks like glass round the
        /// target in a cyan flash, then the glass bursts outward with a few small cogs.
        void Pin(float t)
        {
            float s = size, u = t / duration, live = 1f - u;
            var c = new Vector2(0f, .15f * s);
            Glow(c, 2.4f * s, outer, .2f * Mathf.Pow(live, 1.3f));
            const float Stop = .2f;
            float spin = Inv(0f, Stop, t), p = 1f - Mathf.Pow(1f - spin, 1.5f);
            float jolt = t > Stop ? Mathf.Sin((t - Stop) * 70f) * Mathf.Exp(-(t - Stop) * 18f) * .1f : 0f;
            float appear = EOut(Inv(0f, .05f, t)), hf = 1f - EIn(Inv(.3f, .46f, t)), tf = 1f - EIn(Inv(Stop, Stop + .1f, t));
            float mHead = Mathf.PI * .5f + 7.2f * (1f - p) + jolt, hHead = Mathf.PI * .5f + 3.6f * (1f - p) - jolt * .6f;
            float speed = 1f - spin * .6f;
            Swoosh(c, 1.15f * s * appear, mHead + 2.2f * speed, mHead, .42f * s, .95f * tf, t, 400);
            Swoosh(c, .72f * s * appear, hHead + 1.3f * speed, hHead, .36f * s, .85f * tf, t, 401);
            HandTip(c, 1.15f * s * appear, mHead, -1f, .5f * s, hf);
            HandTip(c, .72f * s * appear, hHead, -1f, .44f * s, hf);
            float tc = t - Stop;
            if (tc < 0f) return;
            // The freeze: a hard cyan flash at twelve, glass cracks shoot out round the target.
            var top = c + Vector2.up * (.9f * s);
            Glow(c, 1.6f * s, band3, .8f * (1f - EOut(Inv(0f, .25f, tc))));
            ImpactStar(top, .7f * s, tc, 402);
            float cg = EOut(Inv(0f, .05f, tc)), cf = 1f - EIn(Inv(.1f, .22f, tc));
            for (int k = 0; k < 7; k++)
            {
                float ang = (k + (J(k + 403) - .5f) * .9f) * 6.283f / 7f; var d = new Vector2(Mathf.Cos(ang), Mathf.Sin(ang));
                Crack(c + d * (.15f * s), d, s * (.7f + .8f * J(k + 404)) * cg, s * .065f, 405 + k * 7, core, .9f * cf, .8f * cf);
            }
            ShockRing(c, s * (.5f + 2f * EOut(Inv(0f, .3f, tc))), .1f * s, band3, .45f * (1f - Inv(0f, .3f, tc)), t);
            // The burst (user 2026-10-09: the scattered glass flakes 不行): time snaps back into
            // motion - broad cyan tongues burst out of the cracked moment, all curling the same
            // way like a clock running again, droplets and glints thrown off them, a few cogs.
            float bt = tc - .1f;
            if (bt < 0f) return;
            float grow = EOut(Inv(0f, .12f, bt)), ff = 1f - EIn(Inv(.14f, .45f, bt)), push = EOut(Inv(0f, .45f, bt));
            for (int i = 0; i < 7; i++)
            {
                float ang = (i + (J(i + 411) - .5f) * .7f) * 6.283f / 7f - push * .5f;
                var dv = new Vector2(Mathf.Cos(ang), Mathf.Sin(ang));
                float L = s * (.55f + .5f * J(i + 412)) * grow * (1f - .3f * EIn(Inv(.2f, .45f, bt)));
                var b = c + dv * (s * (.25f + .5f * push));
                Flame(b, dv, L * 1.15f, (.7f + .2f * J(i + 413)) * s, bt, 410 + i, .2f, .3f * ff, -.7f, 3f, band2);
                Flame(b, dv, L, (.42f + .14f * J(i + 413)) * s, bt, 410 + i, .2f, ff, -.7f, 0f, i % 3 == 0 ? hot : band3);
            }
            for (int i = 0; i < 14; i++)
            {
                float born = .03f * J(i + 417), life = .3f + .25f * J(i + 418), dt = bt - born;
                if (dt < 0f || dt > life) continue;
                float cu = dt / life, ang = (i + J(i + 419)) * 6.283f / 14f - push * .6f;
                var dv = new Vector2(Mathf.Cos(ang), Mathf.Sin(ang));
                var pp = c + dv * (s * (1f + 1.4f * J(i + 425)) * EOut(cu)) + Vector2.down * (.8f * s * dt * dt);
                if (i % 3 == 0) Sparkle(pp, s * (.14f + .08f * J(i + 426)) * (1f - cu), core, 1f - cu, 15f + i * 25f);
                else Dot(pp, s * (.06f + .05f * J(i + 426)) * (1f - .5f * cu), band3, 0f, 1f - EIn(cu), dt + i, .15f);
            }
            for (int g = 0; g < 3; g++)
            {
                float life = .45f + .15f * J(g + 420); if (bt > life) continue;
                float cu = bt / life, ang = (50f + g * 110f + 40f * J(g + 421)) * Mathf.Deg2Rad;
                var dv = new Vector2(Mathf.Cos(ang), Mathf.Sin(ang));
                float disp = (1f - Mathf.Exp(-2.6f * bt)) / 2.6f;
                var pp = c + dv * (s * (1.8f + 1f * J(g + 422)) * disp) + Vector2.down * (2.2f * s * bt * bt);
                Cog(pp, s * (.1f + .05f * J(g + 423)), bt * (9f + 5f * J(g + 424)) * (g % 2 == 0 ? 1f : -1f), 10, 1f - EIn(cu));
            }
            Sparks(c, bt, 14, 87, 1.6f * s, Vector2.zero, 1f - EIn(Inv(0f, .4f, bt)));
        }

        /// 时钟核心回血 (clock core mending an ally; user 2026-10-09: 时钟不行 - a spiky fan):
        /// time runs backwards on the ally - two green clock-hand sweeps spiral in round it
        /// anticlockwise, shards of time-glass fly back in from where they were scattered and
        /// fuse into it, two small brass cogs turn backwards at its shoulders; a warm pulse
        /// when it is whole, then gold motes rise.
        void Mend(float t)
        {
            float s = size, u = t / duration;
            var c = new Vector2(0f, .1f * s);
            float whole = EOut(Inv(.26f, .4f, t)) * (1f - EIn(Inv(.5f, 1f, u)));
            Glow(c, 2.3f * s, outer, .12f + .1f * whole);
            Glow(c, 1.2f * s, band2, .25f * whole);
            float sw = EOut(Inv(0f, .42f, t)), tf = 1f - EIn(Inv(.36f, .56f, t)), hf = 1f - EIn(Inv(.4f, .56f, t));
            for (int k = 0; k < 2; k++)
            {
                float r = s * (1.6f - .85f * sw) * (k == 0 ? 1f : .8f);
                float head = -1.2f + k * Mathf.PI + 5.6f * sw;
                Swoosh(c, r, head - 2f * (1f - .5f * sw), head, .38f * s, .9f * tf, t, 430 + k);
                HandTip(c, r, head, 1f, .3f * s, hf);
            }
            float cf = EOut(Inv(.06f, .18f, t)) * (1f - EIn(Inv(.7f, .92f, t)));
            Cog(c + new Vector2(-.6f, .55f) * s, .17f * s, t * 6f, 11, cf);
            Cog(c + new Vector2(-.33f, .78f) * s, .11f * s, -t * 9.3f + .3f, 8, cf);
            // Time flowing back: comets of green light stream in from all round and sink into
            // the ally, curling anticlockwise, a small glint where each lands.
            for (int i = 0; i < 11; i++)
            {
                float born = .02f + .16f * J(i + 440), mv = Inv(born, born + .22f, t);
                if (mv <= 0f) continue;
                float ang = (i + J(i + 441)) * 6.283f / 11f + .9f * (1f - EIn(mv));
                var dv = new Vector2(Mathf.Cos(ang), Mathf.Sin(ang));
                var pp = c + dv * (s * (.2f + (1.4f + .8f * J(i + 442)) * (1f - EIn(mv))));
                if (mv < 1f)
                {
                    float L = s * (.35f + .3f * J(i + 443)) * (.5f + mv);
                    Flame(pp, Rot(dv, -.5f), L * 1.2f, .3f * s, t, 440 + i, .2f, .3f, .8f, 3f, band2);
                    Flame(pp, Rot(dv, -.5f), L, (.13f + .06f * J(i + 444)) * s, t, 440 + i, .2f, 1f, .8f, 0f, band3);
                }
                else
                {
                    float g2 = Inv(born + .22f, born + .34f, t);
                    if (g2 < 1f) Sparkle(c + dv * (.2f * s), s * .2f * (1f - g2), core, 1f - g2, 15f + i * 20f);
                }
            }
            // Whole again: a warm bloom of light, then gold motes and green specks rise.
            float pulse = Inv(.3f, .55f, t);
            if (pulse > 0f && pulse < 1f) { Glow(c, 1.6f * s * (.6f + .6f * EOut(pulse)), hot, .55f * (1f - pulse)); Sparkle(c, s * .8f * (1f - pulse), core, 1f - pulse, 15f); }
            for (int i = 0; i < 14; i++)
            {
                float born = .35f + .4f * J(i + 390), mu = Inv(born, born + .5f, t); if (mu <= 0f || mu >= 1f) continue;
                var pm = c + new Vector2((J(i + 391) - .5f) * 1.8f * s, 1.1f * J(i + 392) * s + 1.2f * s * mu);
                if (i % 2 == 0) Sparkle(pm, s * (.1f + .06f * J(i + 393)), hot, Mathf.Sin(mu * Mathf.PI), 15f + mu * 90f);
                else Dot(pm, s * .05f, core, 3f, Mathf.Sin(mu * Mathf.PI));
            }
        }

        /// 族母 (matriarch), light round the painted lotus (PaintedSubject): a fan of gold
        /// needles stabs in from her side with a crimson spark each, then a crimson flash and
        /// glints as the lotus opens.
        void Silk(float t)
        {
            float s = size, u = t / duration, live = 1f - u;
            Glow(Vector2.zero, 2.4f * s, outer, .2f * Mathf.Pow(live, 1.3f));
            var back = -dir;
            for (int i = 0; i < 7; i++)
            {
                float born = .03f + .02f * i, mv = Inv(born, born + .09f, t);
                if (mv <= 0f) continue;
                float fa = (i / 6f - .5f) * 1.5f + (J(i + 452) - .5f) * .2f;
                var dv = Rot(-back, fa);
                var hit = new Vector2((J(i + 453) - .5f) * .9f * s, (J(i + 454) - .4f) * .9f * s);
                var tip = Vector2.Lerp(hit - dv * (2.6f * s), hit + dv * (.12f * s), EIn(mv));
                float nf = 1f - EIn(Inv(born + .2f, born + .36f, t));
                PushPal(Hex("6A3A08"), Hex("D8A02A"), Hex("FFE6A0"), Hex("FFFDF0"));
                Crystal(tip - dv * (.85f * s), dv, .85f * s, .075f * s, nf);
                PopPal();
                float sp = Inv(born + .09f, born + .2f, t);
                if (sp > 0f && sp < 1f) { Sparkle(hit, s * .3f * (1f - sp), core, 1f - sp, 15f + i * 20f); Glow(hit, .4f * s, band2, .5f * (1f - sp)); }
            }
            float bt = t - .16f;
            if (bt < 0f) return;
            Glow(Vector2.zero, 1.6f * s, band3, .6f * (1f - EOut(Inv(0f, .3f, bt))));
            ImpactStar(Vector2.zero, .8f * s, bt, 455);
            for (int i = 0; i < 10; i++)
            {
                float born = .02f + .3f * J(i + 475), mu = Inv(born, born + .45f, bt); if (mu <= 0f || mu >= 1f) continue;
                var pp = new Vector2((J(i + 476) - .5f) * 2.2f * s, (J(i + 477) - .3f) * 1.8f * s + .4f * s * mu);
                Sparkle(pp, s * (.12f + .07f * J(i + 478)), i % 3 == 0 ? hot : core, Mathf.Sin(mu * Mathf.PI), 15f + mu * 90f);
            }
        }

        /// 自动签发执行者 (codex executor), light round the painted axe (PaintedSubject): a
        /// fiery sweep follows the blade down; where it chops, the painted fire bursts with a
        /// flash, sparks and dark ink drops thrown.
        void Sign(float t)
        {
            float s = size, u = t / duration, live = 1f - u;
            Glow(Vector2.zero, 2.2f * s, outer, .2f * Mathf.Pow(live, 1.3f));
            const float Chop = .18f;
            var back = -dir;
            var pivot = back * (1.2f * s) + new Vector2(back.x >= 0f ? .9f : -.9f, 0f) * s;
            float endA = Mathf.Atan2(-pivot.y, -pivot.x), sg = pivot.x < 0f ? 1f : -1f;
            float sw = EIn(Inv(0f, Chop, t)), ang = endA + sg * (1f - sw) * 2.1f;
            if (t < Chop + .1f)
                Swoosh(pivot, 1.75f * s, ang + sg * 1.6f * (.35f + .65f * (1f - sw)), ang, .7f * s, .9f * (1f - Inv(Chop, Chop + .1f, t)), t, 480);
            float tc = t - Chop;
            if (tc < 0f) return;
            ImpactStar(Vector2.zero, 1f * s, tc, 485);
            Glow(Vector2.zero, 1.8f * s, hot, .6f * (1f - EOut(Inv(0f, .3f, tc))));
            for (int i = 0; i < 12; i++)
            {
                float life = .3f + .25f * J(i + 490); if (tc > life) continue;
                float cu = tc / life, a = (i + J(i + 491)) * 6.283f / 12f;
                var dv = new Vector2(Mathf.Cos(a), Mathf.Sin(a));
                var pp = dv * (s * (1.1f + 1.3f * J(i + 492)) * EOut(cu)) + Vector2.down * (2f * s * tc * tc);
                if (i % 3 == 0) Sparkle(pp, s * (.16f + .06f * J(i + 493)) * (1f - cu), hot, 1f - cu, 15f + i * 30f);
                else Dot(pp, s * (.07f + .06f * J(i + 493)) * (1f - .4f * cu), outer, 0f, 1f - EIn(cu), tc + i, .2f);
            }
        }

        /// 瑟维安 · 总签官 (the chapter boss), light round his painted seal (PaintedSubject):
        /// when it slams, a gold and teal blast, cracks, a passing ring, then rising embers.
        void Sovereign(float t)
        {
            float s = size, u = t / duration, live = 1f - u;
            Glow(Vector2.zero, 2.4f * s, outer, .16f * Mathf.Pow(live, 1.2f));
            const float Slam = .24f;
            float tc = t - Slam;
            if (tc < 0f) return;
            ImpactStar(Vector2.zero, 1.1f * s, tc, 515);
            Glow(Vector2.zero, 1.8f * s, hot, .6f * (1f - EOut(Inv(0f, .3f, tc))));
            ShockRing(new Vector2(0f, -.6f * s), s * (.5f + 1.9f * EOut(Inv(0f, .35f, tc))), .1f * s, hot, .5f * (1f - Inv(0f, .35f, tc)), t);
            float cg = EOut(Inv(0f, .06f, tc)), cf = 1f - EIn(Inv(.3f, .55f, tc));
            for (int i = 0; i < 14; i++)
            {
                float born = .03f + .4f * J(i + 535), mu = Inv(born, born + .5f, tc); if (mu <= 0f || mu >= 1f) continue;
                var pp = new Vector2((J(i + 536) - .5f) * 1.8f * s, -.4f * s + 1.6f * s * mu);
                if (i % 3 == 0) Sparkle(pp, s * (.12f + .06f * J(i + 537)), hot, Mathf.Sin(mu * Mathf.PI), 15f + mu * 90f);
                else Dot(pp, s * .06f, band3, 3f, Mathf.Sin(mu * Mathf.PI));
            }
        }

        /// 押运 (archive convoy), light round its rolling dust wave: grit and sparks kick up at
        /// the wave front as it rolls to the target; where it breaks, a flash, cracks, embers.
        void Chain(float t)
        {
            float s = size, u = t / duration, live = 1f - u;
            Glow(Vector2.zero, 2.2f * s, outer, .18f * Mathf.Pow(live, 1.3f));
            var back = -dir;
            var f0 = back * (2.6f * s) + new Vector2(0f, -.6f * s); var f1 = new Vector2(0f, -.65f * s);
            // A glowing crack races over the floor ahead of the dust wave.
            float run = EOut(Inv(0f, .2f, t)), cf = 1f - EIn(Inv(.35f, .6f, t));
            var seg = (f1 - f0); float len = seg.magnitude * run;
            for (int k = 0; k < 6; k++)
            {
                // Rocks and grit kicked up at the wave front as it rolls.
                var fp = Vector2.Lerp(f0, f1, run) + new Vector2((J(k + 559) - .5f) * .8f * s, 0f);
                float hop = Mathf.Abs(Mathf.Sin((t * 9f + k) * 1.7f)) * .35f * s * (1f - run * .6f);
                if (run < 1f) Dot(fp + Vector2.up * hop, s * (.05f + .04f * J(k + 558)), band2, 0f, .9f, t + k, .3f);
            }
            Sparks(Vector2.Lerp(f0, f1, run), t, 10, 89, 1f * s, Vector2.up * .5f, (1f - run) * .8f + .2f);
            const float Hit = .22f;
            float tc = t - Hit;
            if (tc < 0f) return;
            ImpactStar(new Vector2(0f, -.2f * s), 1f * s, tc, 561);
            Glow(Vector2.zero, 1.7f * s, hot, .55f * (1f - EOut(Inv(0f, .3f, tc))));
            float cg = EOut(Inv(0f, .06f, tc)), cf2 = 1f - EIn(Inv(.3f, .55f, tc));
            Sparks(Vector2.zero, tc, 16, 91, 1.8f * s, Vector2.up * .3f, 1f - EIn(Inv(0f, .45f, tc)));
            for (int i = 0; i < 10; i++)
            {
                float born = .03f + .35f * J(i + 568), mu = Inv(born, born + .45f, tc); if (mu <= 0f || mu >= 1f) continue;
                var pp = new Vector2((J(i + 569) - .5f) * 1.8f * s, -.4f * s + 1.4f * s * mu);
                Dot(pp, s * .06f, band3, 3f, Mathf.Sin(mu * Mathf.PI));
            }
        }

        /// 救援 (rescue chaser), light round its painted meteor: a blazing head and an ember
        /// trail as it falls, then a big flash, one passing ring, cracks and rising embers.
        void Meteor(float t)
        {
            float s = size, u = t / duration, live = 1f - u;
            Glow(Vector2.zero, 2.2f * s, outer, .18f * Mathf.Pow(live, 1.3f));
            const float Hit = .2f;
            var back = -dir;
            var start = back * (3f * s) + new Vector2(back.x >= 0f ? 1.4f : -1.4f, 1.2f) * s;
            if (t < Hit)
            {
                float mv = EIn(Inv(0f, Hit, t));
                var head = Vector2.Lerp(start, Vector2.zero, mv);
                Glow(head, .9f * s, hot, .8f);
                Dot(head, .22f * s, core, 3f, 1f);
                for (int i = 0; i < 8; i++)
                {
                    float lag = i * .025f, m2 = EIn(Inv(0f, Hit, t - lag)); if (t - lag < 0f) continue;
                    var p = Vector2.Lerp(start, Vector2.zero, m2) + new Vector2(J(i + 570) - .5f, J(i + 571) - .5f) * (.3f * s);
                    Dot(p, s * (.1f - .01f * i), band3, 3f, 1f - i / 8f);
                }
            }
            float tc = t - Hit;
            if (tc < 0f) return;
            ImpactStar(Vector2.zero, 1.2f * s, tc, 572);
            Glow(Vector2.zero, 2f * s, hot, .7f * (1f - EOut(Inv(0f, .3f, tc))));
            ShockRing(new Vector2(0f, -.6f * s), s * (.5f + 1.8f * EOut(Inv(0f, .35f, tc))), .1f * s, band3, .5f * (1f - Inv(0f, .35f, tc)), t);
            float cg = EOut(Inv(0f, .06f, tc)), cf = 1f - EIn(Inv(.3f, .55f, tc));
            for (int i = 0; i < 12; i++)
            {
                float born = .03f + .35f * J(i + 580), mu = Inv(born, born + .5f, tc); if (mu <= 0f || mu >= 1f) continue;
                var pp = new Vector2((J(i + 581) - .5f) * 2f * s, -.3f * s + 1.6f * s * mu);
                if (i % 3 == 0) Sparkle(pp, s * (.12f + .06f * J(i + 582)), hot, Mathf.Sin(mu * Mathf.PI), 15f + mu * 90f);
                else Dot(pp, s * .06f, band3, 3f, Mathf.Sin(mu * Mathf.PI));
            }
        }

        /// 第十三响 (the clock family's charged strike), light round the painted sword rain: a
        /// spark and glint where each sword sticks, then the great sword's bell-toll - a big
        /// flash, one passing ring, cracks and sparks.
        void Toll(float t)
        {
            float s = size, u = t / duration, live = 1f - u;
            Glow(Vector2.zero, 2.6f * s, outer, .2f * Mathf.Pow(live, 1.2f));
            for (int i = 0; i < 6; i++)
            {
                float land = .05f + .035f * i, k = Inv(land, land + .12f, t);
                if (k <= 0f || k >= 1f) continue;
                var spot = new Vector2((i % 2 == 0 ? -1f : 1f) * (.5f + .7f * J(i + 590)), -.75f + .85f * J(i + 591)) * s;
                Sparkle(spot, s * .35f * (1f - k), core, 1f - k, 15f + i * 25f);
                Glow(spot, .5f * s, band3, .5f * (1f - k));
            }
            const float Big = .3f;
            float tc = t - Big;
            if (tc < 0f) return;
            ImpactStar(Vector2.zero, 1.3f * s, tc, 592);
            Glow(Vector2.zero, 2.2f * s, hot, .75f * (1f - EOut(Inv(0f, .3f, tc))));
            ShockRing(new Vector2(0f, -.5f * s), s * (.5f + 2.2f * EOut(Inv(0f, .38f, tc))), .12f * s, hot, .55f * (1f - Inv(0f, .38f, tc)), t);
            float cg = EOut(Inv(0f, .06f, tc)), cf = 1f - EIn(Inv(.3f, .55f, tc));
            Sparks(Vector2.zero, tc, 18, 93, 2f * s, Vector2.up * .2f, 1f - EIn(Inv(0f, .45f, tc)));
        }

        /// Light of the Q30 angel intro (see AngelIntro): the gold flash of his seal, the cold glow
        /// of the rift, the hero's chest caught by the tether, the lamp coming down with the angel,
        /// the blaze when her staff lands (one passing toll wave as accent), then the great ball of
        /// light round the two fighters - gold and cold flashes bursting inside it at each clash,
        /// streaks where they pass - shrinking into the rift, the rift closing. Times are real
        /// seconds; offsets are world units round the boss's feet.
        void AngelLight(float t)
        {
            float r = t / HitPace;
            float open = Smooth(Inv(AiRiftOpen, AiRiftOpen + .8f, r)) * (1f - Smooth(Inv(AiClose - .2f, AiClose + .4f, r)));
            var rift = AngelRift;
            if (r >= .15f && r < 1f) { float f = Inv(.15f, .3f, r) * (1f - Inv(.5f, 1f, r)); Glow(new Vector2(0f, .4f), 1.6f, band2, .6f * f); ImpactStar(new Vector2(0f, .3f), 1f, (r - .15f) * HitPace, 950); }
            if (open > .01f && AngelRiftPainted)
            {
                Glow(rift, 2.6f * open, outer, .25f * open);
                Glow(rift, 1.6f * open, hot, (.2f + .04f * Mathf.Sin(r * 5f)) * open);
            }
            // No rift drawn yet: only a faint cold light round the giant as he stands up.
            else if (open > .01f) Glow(rift + new Vector2(0f, .8f), 2.6f * open, outer, .14f * open);
            float bound = Inv(AiBind + .3f, AiBind + .7f, r) * (1f - Inv(AiPlant, AiPlant + .3f, r));
            if (bound > .01f) { Glow(heroOff, 1.1f, hot, .5f * bound * (.75f + .25f * Mathf.Sin(r * 7f))); Sparkle(heroOff, .32f * bound, core, bound, r * 60f); }
            var lamp = AngelFeet(r) + AngelLampOffset(r);
            float lampOn = Inv(AiLamp, AiLamp + .4f, r) * (1f - Inv(AiBall - .3f, AiBall, r));
            if (lampOn > .01f)
            {
                // Small and soft: a big glow washed the spread-wing painting out to a white disc.
                Glow(lamp, .7f, band3, .3f * lampOn); Glow(lamp, .3f, core, .55f * lampOn);
                Sparkle(lamp, .3f * lampOn, core, lampOn, r * 30f);
            }
            // Motes drifting down with her.
            for (int i = 0; i < 18; i++)
            {
                float born = AiDescend - .2f + 2f * J(i + 951), mu = Inv(born, born + 1.4f, r); if (mu <= 0f || mu >= 1f) continue;
                var pp = AngelFeet(born) + new Vector2((J(i + 952) - .5f) * 3f, 2.5f + J(i + 953) * 2f - 3.2f * mu);
                Dot(pp, .05f + .03f * J(i + 954), band3, 0f, Mathf.Sin(mu * Mathf.PI), r + i, .15f);
            }
            // Cold light leaking from the tears' edges, flaring as each rips open.
            for (int k = 0; k < (AngelTearsPainted ? AngelTears.Length : 0); k++)
            {
                var tr = AngelTears[k];
                float rip = Smooth(Inv(tr.w, tr.w + .35f, r)) * (1f - Smooth(Inv(AiClose - .2f, AiClose + .3f, r)));
                if (rip <= .01f) continue;
                // Stand-in until the painted tear arrives: no outline (thin lines read as wireframe,
                // angel6) - soft cold light puffing out along a ragged line over the dark gash.
                float a = tr.z * Mathf.Deg2Rad, l = TearLen(tr) * (.3f + .7f * rip) * .5f;
                var ax = new Vector2(Mathf.Cos(a), Mathf.Sin(a)); var nm = new Vector2(-ax.y, ax.x); var c = new Vector2(tr.x, tr.y);
                float flare = 1f - Inv(tr.w, tr.w + .5f, r);
                for (int j = 0; j < 7; j++)
                {
                    float u = (j + .5f) / 7f, w = Mathf.Sin(u * Mathf.PI);
                    var pp = c + ax * (l * (2f * u - 1f)) + nm * ((J(k * 31 + j) - .5f) * .35f * w);
                    Glow(pp, (.25f + .35f * w) * rip, hot, (.22f + .3f * flare) * w * rip * (.8f + .2f * Mathf.Sin(r * 7f + j)));
                }
                Glow(c, l * .8f, outer, .18f * rip);
                if (flare > 0f) Glow(c, l * .6f, hot, .45f * flare);
            }
            float tp = r - AiPlant;
            if (tp >= 0f && tp < 1.2f)
            {
                ImpactStar(rift + new Vector2(0f, .3f), 1.5f, tp * HitPace, 960);
                Glow(rift, 2f, core, .4f * (1f - EOut(Inv(0f, .35f, tp))));
                ShockRing(rift, .8f + 3.6f * EOut(Inv(0f, .7f, tp)), .12f * (1f - Inv(0f, .7f, tp)), band3, .5f * (1f - Inv(.05f, .7f, tp)), tp);
            }
            // The ball of light: swells round them, churns, throbs with every clash, then shrinks
            // down into the rift.
            float grow = Smooth(Inv(AiBall - .3f, AiBall + .5f, r)), shrink = Smooth(Inv(AiBallEnd, AiClose, r));
            float ball = grow * (1f - shrink);
            if (ball > .01f)
            {
                // Pushed out on the far side of each blow, swelling with the big ones (BallPush).
                var push = BallPush(r) * (1f - shrink);
                var c = Vector2.Lerp(AngelBall, rift, shrink) + push * .6f;
                float rad = (3.3f + .18f * Mathf.Sin(r * 3.1f)) * (1f - .85f * shrink) * (.4f + .6f * grow) * (1f + BallSwell(r) * (1f - shrink));
                float flash = FightFlash(r);
                Glow(c, rad * 1.55f, outer, .3f * ball);
                Glow(c, rad * 1.1f, band3, (.14f + .2f * flash) * ball);
                Glow(c, rad * .6f, core, (.07f + .3f * flash) * ball);   // dimmer between blows so the shapes and swings read
                if (push.sqrMagnitude > 1e-4f) Glow(c + push * 2.4f, rad * .55f, band3, Mathf.Min(.35f, push.magnitude * .7f) * ball);
                if (r > FightStart && r < AiBallEnd + .3f) FightLight(r - FightStart, ball);
                for (int i = 0; i < 14; i++)
                {
                    float born = AiBall + 4.5f * J(i + 970), mu = Inv(born, born + .7f, r); if (mu <= 0f || mu >= 1f) continue;
                    float aa = J(i + 971) * 6.283f;
                    var pp = c + new Vector2(Mathf.Cos(aa), Mathf.Sin(aa)) * rad * (.9f + .9f * mu);
                    Sparkle(pp, .14f + .08f * J(i + 972), i % 2 == 0 ? core : hot, Mathf.Sin(mu * Mathf.PI) * ball, mu * 120f);
                }
            }
            float tc = r - AiClose;
            if (tc >= 0f && tc < .8f) { Glow(rift, 2.4f, core, .6f * (1f - EOut(Inv(0f, .6f, tc)))); ImpactStar(rift, 1.2f, tc * HitPace, 970, false); }   // no ring (angel14)
            // The farewell gifts (GiftPos): warm light round her flame with a soft tail of light behind
            // it, cold light round his salt; each blooms where it lands.
            for (int g = 0; g < 2; g++)
            {
                var target = g == 0 ? heroOff : bossOff;
                Color lit = g == 0 ? band3 : hot, deep = g == 0 ? band2 : outer;
                float arrive = GiftArrive(g);
                if (r > AiGift && r < arrive)
                {
                    float born = Inv(AiGift, AiGift + .3f, r);
                    var gp = GiftPos(g, r, target);
                    Glow(gp, .9f, deep, .35f * born);
                    Glow(gp, .45f, lit, .55f * born);
                    // The tail: glows overlapping back along its path, fading - one soft streak, never beads.
                    for (int k = 1; k <= 8; k++)
                    {
                        float rk = r - .035f * k; if (rk < AiGift) break;
                        Glow(GiftPos(g, rk, target), .42f * (1f - k / 10f), lit, .3f * born * (1f - k / 9f));
                    }
                    if (g == 0) Sparkle(gp, .22f, core, born, r * 90f);
                    // Motes shed on the way: hers drift up, his sink.
                    for (int i = 0; i < 6; i++)
                    {
                        float shed = AiGift + .7f + (arrive - AiGift - .7f) * J(i + 990 + g * 7), mu = Inv(shed, shed + .6f, r); if (mu <= 0f || mu >= 1f) continue;
                        var mp = GiftPos(g, shed, target) + new Vector2((J(i + 991 + g * 7) - .5f) * .3f, (g == 0 ? .35f : -.35f) * mu);
                        Dot(mp, .04f + .02f * J(i + 992), lit, 0f, Mathf.Sin(mu * Mathf.PI), r + i, .15f);
                    }
                }
                float landed = r - arrive;
                if (landed >= 0f && landed < 1.4f)
                {
                    Glow(target, 1.4f, deep, .4f * (1f - EOut(Inv(0f, 1.2f, landed))));
                    Glow(target, .8f, lit, .6f * (1f - EOut(Inv(0f, .5f, landed))));
                    if (g == 0) ImpactStar(target, .9f, landed * HitPace, 985, false);
                    else Sparkle(target, .4f * (1f - Inv(0f, .5f, landed)), hot, 1f - Inv(0f, .5f, landed), 20f);
                    // A few motes settling round (hers, rising) or drawn into (his) the one it was given to.
                    for (int i = 0; i < 8; i++)
                    {
                        float mu = Inv(.05f * i, .05f * i + .9f, landed); if (mu <= 0f || mu >= 1f) continue;
                        float aa = J(i + 995 + g * 9) * 6.283f;
                        var mp = target + new Vector2(Mathf.Cos(aa), Mathf.Sin(aa)) * (g == 0 ? .3f + .5f * mu : .8f * (1f - mu)) + new Vector2(0f, g == 0 ? .6f * mu : 0f);
                        Dot(mp, .045f, lit, 0f, Mathf.Sin(mu * Mathf.PI), r + i, .15f);
                    }
                }
            }
        }

        /// The blows of the fight clip (FightBlows, c = clip time): the impact flash where it lands,
        /// a big one lighting the whole ball, embers flung out of the light; the grapple's straining
        /// glow and crackle. The weapons' swings are the clip's own.
        void FightLight(float c, float ball)
        {
            for (int k = 0; k < FightBlows.Length; k++)
            {
                var e = FightBlows[k]; float du = c - e.x; if (du < 0f || du > .9f) continue;
                int kind = (int)e.y; float pw = e.z;
                var cp = FightPoint(FightBlowAt[k]);
                float big = kind == 4 ? 1.5f : 1f;
                ImpactStar(cp, (.5f + .7f * pw) * big, du * HitPace, 1100 + k * 7, false);
                Glow(cp, 1.3f * pw * big, kind == 1 ? hot : core, .75f * pw * (1f - EOut(Inv(0f, .25f, du))) * ball);
                if (pw >= .9f) Glow(cp, 3.4f * big, band3, .4f * (1f - EOut(Inv(0f, .35f, du))) * ball);
                // Embers flung out, each its own speed and way (never a ring), falling as they fade.
                int n = pw >= .9f ? 11 : 5;
                for (int i = 0; i < n; i++)
                {
                    float a = J(k * 13 + i * 5 + 1) * 6.283f, sp = (2f + 3f * J(k * 13 + i * 5 + 2)) * pw * big, life = .45f + .4f * J(k * 13 + i * 5 + 3);
                    if (du > life) continue;
                    float q = du / life;
                    var pp = cp + new Vector2(Mathf.Cos(a), Mathf.Sin(a)) * (sp * (1f - Mathf.Exp(-3.5f * du)) / 3.5f) + Vector2.down * (1.4f * du * du);
                    Dot(pp, .05f + .03f * J(k * 13 + i * 5 + 4), (kind == 1 || (kind == 4 && i % 2 == 1)) ? hot : band3, 0f, Mathf.Pow(1f - q, .8f) * ball, c + i, .15f);
                }
            }
            // The grapple: the light between them swelling and swinging from her gold to his
            // cold as one gains and gives, crackling.
            float lk = LockAmount(c);
            if (lk > .01f)
            {
                var m = FightPoint(LockAt);
                float sway = Mathf.Sin(c * 6.1f), grow = Iv(LockFrom, LockTo, c);
                Glow(m, .8f + .7f * grow, core, (.4f + .15f * Mathf.Sin(c * 31f)) * lk * ball);
                Glow(m + new Vector2(.25f * sway, 0f), .7f + .4f * grow, sway > 0f ? band3 : hot, .45f * lk * ball);
                Sparkle(m + new Vector2(.08f * Mathf.Sin(c * 53f), .06f * Mathf.Sin(c * 41f)), .3f + .2f * grow, core, lk, c * 220f);
                int burst = Mathf.FloorToInt(c / .18f);
                Sparks(m, c - burst * .18f, 4, 1200 + burst * 5, 1.6f + grow, Vector2.zero, lk * .9f);
            }
        }

        /// 镇钟重砸 (瑟维安, 2026-10-10), light round the painted bell: a glow coming down with it, then
        /// at the slam a flash on the floor, one toll wave passing out over the party (accent only)
        /// and embers rising while the bell shudders.
        void BellSlam(float t)
        {
            float s = size; const float Hit = .12f;
            var ground = new Vector2(0f, -.6f * s);
            if (t < Hit) { Glow(new Vector2(0f, (3.2f - 2.4f * Inv(0f, Hit, t)) * s), 1.6f * s, band3, .25f * Inv(0f, Hit, t)); return; }
            float th = t - Hit, live = 1f - Inv(0f, .7f, th);
            Glow(ground, 3.2f * s, outer, .3f * live);
            ImpactStar(ground + new Vector2(0f, .4f * s), 1.6f * s, th, 940);
            Glow(ground, 2.4f * s, hot, .5f * (1f - EOut(Inv(0f, .25f, th))));
            ShockRing(ground, s * (.6f + 4f * EOut(Inv(0f, .45f, th))), .12f * s * (1f - Inv(0f, .45f, th)), band3, .55f * (1f - Inv(.05f, .45f, th)), th);
            for (int i = 0; i < 14; i++)
            {
                float born = .03f + .35f * J(i + 941), mu = Inv(born, born + .45f, th); if (mu <= 0f || mu >= 1f) continue;
                var pp = new Vector2((J(i + 942) - .5f) * 3.2f * s, -.6f * s + 1.6f * s * mu);
                if (i % 3 == 0) Sparkle(pp, s * (.11f + .05f * J(i + 943)), core, Mathf.Sin(mu * Mathf.PI), 15f + mu * 90f);
                else Dot(pp, s * (.05f + .03f * J(i + 944)), band3, 0f, Mathf.Sin(mu * Mathf.PI), th + i, .15f);
            }
        }

        /// 夺名代签 (瑟维安, 2026-10-10 redo), light round the painted name plate: a bright trail as
        /// the name is torn up out of the target's chest to the plate over the party, a flash as his
        /// seal stamps it, and a second flash with gold motes when the signed plate slams back down.
        void NameSeal(float t)
        {
            float s = size;
            var chest = new Vector2(0f, .2f * s); var plate = new Vector2(0f, 1.6f * s);
            Glow(plate, 2.2f * s, outer, .1f * Inv(0f, .15f, t) * (1f - Inv(.6f, .8f, t)));
            if (t < .22f) Taper(chest, Vector2.Lerp(chest, plate, EOut(Inv(0f, .14f, t))), .18f * s, .04f * s, band3, .5f * (1f - Inv(.12f, .22f, t)));
            float ts = t - .46f;
            if (ts >= 0f)
            {
                ImpactStar(plate, 1.4f * s, ts, 920);
                Glow(plate, 2f * s, hot, .5f * (1f - EOut(Inv(0f, .3f, ts))));
            }
            float th = t - .74f; if (th < 0f) return;
            ImpactStar(chest, 1.2f * s, th, 930);
            Glow(chest, 1.8f * s, band3, .55f * (1f - EOut(Inv(0f, .3f, th))));
            for (int i = 0; i < 14; i++)
            {
                float born = .03f + .3f * J(i + 931), mu = Inv(born, born + .45f, th); if (mu <= 0f || mu >= 1f) continue;
                var pp = new Vector2((J(i + 932) - .5f) * 2.2f * s, -.2f * s + 1.8f * s * mu);
                if (i % 3 == 0) Sparkle(pp, s * (.11f + .05f * J(i + 933)), core, Mathf.Sin(mu * Mathf.PI), 15f + mu * 90f);
                else Dot(pp, s * (.05f + .03f * J(i + 934)), band3, 0f, Mathf.Sin(mu * Mathf.PI), th + i, .15f);
            }
        }

        /// 猎犬冥火喷吐, light round the painted hellfire where it lands (the stream itself arrives
        /// before the contact): a flash, a hot core, embers and sparks rising.
        void BreathLight(float t)
        {
            float s = size, u = t / duration, live = 1f - u;
            Glow(Vector2.zero, 2.4f * s, outer, .22f * Mathf.Pow(live, 1.2f));
            ImpactStar(Vector2.zero, 1f * s, t, 720);
            Glow(Vector2.zero, 1.7f * s, hot, .5f * (1f - EOut(Inv(0f, .3f, t))));
            for (int i = 0; i < 14; i++)
            {
                float born = .03f + .4f * J(i + 721), mu = Inv(born, born + .45f, t); if (mu <= 0f || mu >= 1f) continue;
                var pp = new Vector2((J(i + 722) - .5f) * 2f * s, -.4f * s + 1.8f * s * mu);
                if (i % 3 == 0) Sparkle(pp, s * (.1f + .05f * J(i + 723)), hot, Mathf.Sin(mu * Mathf.PI), 15f + mu * 90f);
                else Dot(pp, s * (.05f + .03f * J(i + 724)), band3, 0f, Mathf.Sin(mu * Mathf.PI), t + i, .15f);
            }
        }

        /// 翡翠亡魂 (emerald revenant), light round its painted claws and toxic cloud: a
        /// green flash, goo dripping, bubbles and glints rising.
        void Emerald(float t)
        {
            float s = size, u = t / duration, live = 1f - u;
            Glow(Vector2.zero, 2.4f * s, outer, .22f * Mathf.Pow(live, 1.2f));
            ImpactStar(Vector2.zero, .9f * s, t, 600);
            Glow(Vector2.zero, 1.6f * s, band3, .6f * (1f - EOut(Inv(0f, .3f, t))));
            Drips(new Vector2(0f, .2f * s), t, 8, 606, 1.4f * s, 1f - EIn(Inv(.35f, .7f, t)));
            for (int i = 0; i < 12; i++)
            {
                float born = .05f + .45f * J(i + 610), mu = Inv(born, born + .5f, t); if (mu <= 0f || mu >= 1f) continue;
                var pp = new Vector2((J(i + 611) - .5f) * 1.8f * s, -.5f * s + 1.6f * s * mu);
                if (i % 3 == 0) Sparkle(pp, s * (.1f + .05f * J(i + 612)), hot, Mathf.Sin(mu * Mathf.PI), 15f + mu * 90f);
                else Dot(pp, s * (.05f + .03f * J(i + 613)), band3, 0f, Mathf.Sin(mu * Mathf.PI), t + i, .15f);
            }
        }

        /// 石皮 (stonehide) earth geyser, light round the painted dust column: an amber flash,
        /// sparks thrown up, embers rising in the column.
        void Geyser(float t)
        {
            float s = size, u = t / duration, live = 1f - u;
            Glow(Vector2.zero, 2.2f * s, outer, .12f * Mathf.Pow(live, 1.2f));
            ImpactStar(new Vector2(0f, -.3f * s), .8f * s, t, 620);
            Glow(new Vector2(0f, -.4f * s), 1.4f * s, hot, .3f * (1f - EOut(Inv(0f, .2f, t))));
            Sparks(new Vector2(0f, -.5f * s), t, 16, 99, 2.2f * s, Vector2.up * .6f, 1f - EIn(Inv(0f, .45f, t)));
            for (int i = 0; i < 12; i++)
            {
                float born = .05f + .35f * J(i + 626), mu = Inv(born, born + .45f, t); if (mu <= 0f || mu >= 1f) continue;
                var pp = new Vector2((J(i + 627) - .5f) * 1.2f * s, -.4f * s + 2f * s * mu);
                if (i % 3 == 0) Sparkle(pp, s * (.12f + .06f * J(i + 628)), hot, Mathf.Sin(mu * Mathf.PI), 15f + mu * 90f);
                else Dot(pp, s * .06f, band3, 3f, Mathf.Sin(mu * Mathf.PI));
            }
        }

        /// 盐喉 (saltmaw) salt spike, light round the painted crystal clusters: a cyan flash at
        /// their base, pink glints at the tips while they stand, salt grains falling.
        void SaltSpike(float t)
        {
            float s = size, u = t / duration, live = 1f - u;
            Glow(Vector2.zero, 2.2f * s, outer, .18f * Mathf.Pow(live, 1.2f));
            var foot = new Vector2(0f, -.85f * s);
            ImpactStar(foot + Vector2.up * (.4f * s), .7f * s, t, 634);
            Glow(foot + Vector2.up * (.5f * s), 1.1f * s, band3, .25f * (1f - EOut(Inv(0f, .2f, t))));
            // Pink glints flare at the crystal tips while they stand.
            Vector2[] tips = { new Vector2(0f, 1.62f), new Vector2(-.45f, 1.1f), new Vector2(.48f, 1.12f), new Vector2(-1.05f, .85f), new Vector2(1f, .72f) };
            float hold = Inv(.08f, .14f, t) * (1f - Inv(.4f, .55f, t));
            for (int k = 0; k < tips.Length; k++)
            {
                float tw = .5f + .5f * Mathf.Sin(t * 26f + k * 1.9f);
                Sparkle(foot + tips[k] * s, s * (.22f + .1f * tw), hot, hold * tw, 15f + k * 20f);
            }
            for (int i = 0; i < 14; i++)
            {
                float born = .3f + .2f * J(i + 630), life = .4f, dt = t - born; if (dt < 0f || dt > life) continue;
                float cu = dt / life;
                var pp = foot + new Vector2((J(i + 631) - .5f) * 2.2f * s, (.2f + 1.6f * J(i + 632)) * s) + Vector2.down * (2.5f * s * dt * dt);
                Dot(pp, s * (.04f + .03f * J(i + 633)), core, 3f, 1f - cu);
            }
        }

        /// 盐喉吐毒 (salt poison), light round the painted venom glob and splash: a green flash
        /// where it bursts, drips, bubbles rising.
        void Spit(float t)
        {
            float s = size, u = t / duration, live = 1f - u;
            Glow(Vector2.zero, 2.2f * s, outer, .18f * Mathf.Pow(live, 1.2f));
            const float Hit = .18f;
            var back = -dir; var start = back * (2.8f * s) + Vector2.up * (.6f * s);
            float tc = t - Hit;
            if (tc < 0f) return;
            ImpactStar(Vector2.zero, .9f * s, tc, 640);
            Glow(Vector2.zero, 1.6f * s, band3, .55f * (1f - EOut(Inv(0f, .3f, tc))));
            Drips(new Vector2(0f, .1f * s), tc, 7, 645, 1.3f * s, 1f - EIn(Inv(.35f, .7f, tc)));
            for (int i = 0; i < 10; i++)
            {
                float born = .1f + .4f * J(i + 646), mu = Inv(born, born + .5f, tc); if (mu <= 0f || mu >= 1f) continue;
                var pp = new Vector2((J(i + 647) - .5f) * 1.6f * s, -.3f * s + 1.4f * s * mu);
                Dot(pp, s * (.05f + .03f * J(i + 648)), band3, 0f, Mathf.Sin(mu * Mathf.PI), tc + i, .15f);
            }
        }

        /// 铁爪 (ironclaw), light round the two painted steel slashes: where each cut crosses
        /// the target, a white-blue flash and a spray of steel sparks along the cut.
        void Steel(float t)
        {
            float s = size, u = t / duration, live = 1f - u;
            Glow(Vector2.zero, 2f * s, outer, .16f * Mathf.Pow(live, 1.2f));
            for (int k = 0; k < 2; k++)
            {
                float tk = t - (.06f + .07f * k); if (tk < 0f) continue;
                float ang = (k == 0 ? 35f : -35f) * Mathf.Deg2Rad;
                var dv = new Vector2(Mathf.Cos(ang), Mathf.Sin(ang)) * (k == 0 ? 1f : -1f);
                ImpactStar(Vector2.zero, .7f * s, tk, 650 + k);
                Glow(Vector2.zero, 1.2f * s, band3, .5f * (1f - EOut(Inv(0f, .2f, tk))));
                Sparks(Vector2.zero, tk, 12, 97 + k, 1.8f * s, dv * .8f, 1f - EIn(Inv(0f, .35f, tk)));
            }
        }

        /// 鳍蛇 (frilled naga) sound arrow, light round the painted sonic arrowhead: open arcs
        /// of sound ripple out behind it as it flies (short, offset, never closed rings), and
        /// on the hit a gold flash with crackling electric sparks.
        void Sonic(float t)
        {
            float s = size, u = t / duration, live = 1f - u;
            Glow(Vector2.zero, 2.2f * s, outer, .18f * Mathf.Pow(live, 1.2f));
            const float Hit = .16f;
            var back = -dir; var start = back * (2.8f * s);
            float travel = Mathf.Atan2(dir.y, dir.x) * Mathf.Rad2Deg;
            for (int k = 0; k < 4; k++)
            {
                float born = .03f * k, age = t - born; if (age < 0f || age > .32f) continue;
                var c = Vector2.Lerp(start, Vector2.zero, Mathf.Clamp01(born / Hit));
                float r = s * (.25f + 1.4f * EOut(age / .32f));
                Arc(c, r, .07f * s, travel - 55f, 110f, band3, .7f * (1f - age / .32f));
            }
            float tc = t - Hit;
            if (tc < 0f) return;
            ImpactStar(Vector2.zero, 1f * s, tc, 655);
            Glow(Vector2.zero, 1.7f * s, hot, .55f * (1f - EOut(Inv(0f, .3f, tc))));
            float lf = 1f - EIn(Inv(.05f, .3f, tc));
            for (int k = 0; k < 4; k++)
            {
                float a = (k * 90f + 45f + (J(k + 656) - .5f) * 40f) * Mathf.Deg2Rad;
                Lightning(Vector2.zero, new Vector2(Mathf.Cos(a), Mathf.Sin(a)) * (s * (1f + .5f * J(k + 657))), 658 + k + (int)(tc * 12f), .06f * s, lf, 1);
            }
            for (int i = 0; i < 10; i++)
            {
                float born = .03f + .3f * J(i + 660), mu = Inv(born, born + .45f, tc); if (mu <= 0f || mu >= 1f) continue;
                var pp = new Vector2((J(i + 661) - .5f) * 1.8f * s, (J(i + 662) - .3f) * 1.6f * s + .4f * s * mu);
                Sparkle(pp, s * (.1f + .06f * J(i + 663)), i % 3 == 0 ? hot : core, Mathf.Sin(mu * Mathf.PI), 15f + mu * 90f);
            }
        }

        /// 骨爪 (boneclaw), light round the painted bone rake: a teal flash where it crosses,
        /// teal sparks thrown along the rake, violet glints.
        void BoneRake(float t)
        {
            float s = size, u = t / duration, live = 1f - u;
            Glow(Vector2.zero, 2f * s, outer, .16f * Mathf.Pow(live, 1.2f));
            float tc = t - .08f; if (tc < 0f) return;
            ImpactStar(Vector2.zero, .8f * s, tc, 670);
            Glow(Vector2.zero, 1.3f * s, band3, .45f * (1f - EOut(Inv(0f, .25f, tc))));
            Sparks(Vector2.zero, tc, 16, 101, 2f * s, new Vector2(.6f, -.5f), 1f - EIn(Inv(0f, .4f, tc)));
            for (int i = 0; i < 10; i++)
            {
                float born = .03f + .3f * J(i + 671), mu = Inv(born, born + .45f, tc); if (mu <= 0f || mu >= 1f) continue;
                var pp = new Vector2((J(i + 672) - .5f) * 1.8f * s, (J(i + 673) - .3f) * 1.6f * s);
                Sparkle(pp, s * (.1f + .06f * J(i + 674)), i % 2 == 0 ? hot : core, Mathf.Sin(mu * Mathf.PI), 15f + mu * 90f);
            }
        }

        /// 铜背 (copperback), light round the painted horn: an orange streak behind it as it
        /// charges, then a hot flash, one passing ring, sparks and embers on the ram.
        void Ram(float t)
        {
            float s = size, u = t / duration, live = 1f - u;
            Glow(Vector2.zero, 2f * s, outer, .16f * Mathf.Pow(live, 1.2f));
            const float Hit = .16f;
            var start = -dir * (2.2f * s) + Vector2.up * (.2f * s);
            if (t < Hit + .06f)
            {
                float mv = EIn(Inv(0f, Hit, t)), back = EIn(Inv(0f, Hit, t - .07f));
                var head = Vector2.Lerp(start, Vector2.zero, mv); var tail = Vector2.Lerp(start, Vector2.zero, back);
                Taper(tail, head, .02f * s, .3f * s, band3, .7f * (1f - Inv(Hit, Hit + .06f, t)));
            }
            float tc = t - Hit; if (tc < 0f) return;
            ImpactStar(Vector2.zero, .9f * s, tc, 680);
            Glow(Vector2.zero, 1.4f * s, band3, .35f * (1f - EOut(Inv(0f, .25f, tc))));
            Sparks(Vector2.zero, tc, 18, 103, 2.2f * s, dir * .7f, 1f - EIn(Inv(0f, .45f, tc)));
        }

        /// 赤魔 (crimson brute), light round the painted flaming fist: embers streaming off it
        /// as it comes, then a huge hot flash, a passing ring and embers rising from the fire.
        void Fist(float t)
        {
            float s = size, u = t / duration, live = 1f - u;
            Glow(Vector2.zero, 2.4f * s, outer, .2f * Mathf.Pow(live, 1.2f));
            const float Hit = .2f;
            var start = -dir * (2.4f * s) + Vector2.up * (.5f * s);
            if (t < Hit)
            {
                var head = Vector2.Lerp(start, Vector2.zero, EIn(Inv(0f, Hit, t)));
                for (int i = 0; i < 6; i++) { float lag = .02f * i; if (t - lag < 0f) continue; Dot(Vector2.Lerp(start, Vector2.zero, EIn(Inv(0f, Hit, t - lag))) + new Vector2(J(i + 690) - .5f, J(i + 691) - .5f) * (.4f * s), s * (.08f - .008f * i), band3, 3f, 1f - i / 6f); }
                Glow(head, .9f * s, hot, .5f);
            }
            float tc = t - Hit; if (tc < 0f) return;
            ImpactStar(Vector2.zero, 1.1f * s, tc, 692);
            Glow(Vector2.zero, 1.7f * s, hot, .45f * (1f - EOut(Inv(0f, .3f, tc))));
            for (int i = 0; i < 14; i++)
            {
                float born = .03f + .4f * J(i + 693), mu = Inv(born, born + .5f, tc); if (mu <= 0f || mu >= 1f) continue;
                var pp = new Vector2((J(i + 694) - .5f) * 1.8f * s, -.3f * s + 1.7f * s * mu);
                if (i % 3 == 0) Sparkle(pp, s * (.12f + .06f * J(i + 695)), hot, Mathf.Sin(mu * Mathf.PI), 15f + mu * 90f);
                else Dot(pp, s * .06f, band3, 3f, Mathf.Sin(mu * Mathf.PI));
            }
        }

        /// 帷幕先知 (veil oracle), light round the painted veil: a rose glow swelling at its
        /// heart, glints orbiting with it, a gold flash as it tears away.
        void Veil(float t)
        {
            float s = size, u = t / duration, live = 1f - u;
            Glow(Vector2.zero, 2.4f * s, outer, .2f * Mathf.Pow(live, 1.2f));
            Glow(Vector2.zero, 1.4f * s, band3, .35f * EOut(Inv(0f, .2f, t)) * (1f - EIn(Inv(.4f, .7f, t))));
            for (int i = 0; i < 8; i++)
            {
                float a = -t * 6f + i * .785f, r = s * (.9f + .4f * J(i + 700)) * EOut(Inv(0f, .25f, t));
                float f = Inv(0f, .1f, t) * (1f - EIn(Inv(.4f, .65f, t)));
                Sparkle(new Vector2(Mathf.Cos(a) * r, Mathf.Sin(a) * r * .8f + .1f * s), s * (.1f + .05f * J(i + 701)), i % 2 == 0 ? hot : core, f * (.6f + .4f * Mathf.Sin(t * 20f + i)), 15f + i * 30f);
            }
            float tc = t - .4f; if (tc < 0f) return;
            ImpactStar(Vector2.zero, .9f * s, tc, 702);
            Glow(Vector2.zero, 1.5f * s, hot, .45f * (1f - EOut(Inv(0f, .3f, tc))));
        }

        /// 金喉 (golden throat), light round the painted bubbles: a soft gold glow under the big
        /// cluster, glints over it while it quivers, then the pop - a burst of glints and gold
        /// droplets falling.
        void Bubbles(float t)
        {
            float s = size, u = t / duration, live = 1f - u;
            Glow(Vector2.zero, 2f * s, outer, .15f * Mathf.Pow(live, 1.2f));
            float tc = t - .2f; if (tc < 0f) return;
            Glow(Vector2.zero, 1.2f * s, band3, .15f * EOut(Inv(0f, .12f, tc)) * (1f - Inv(.3f, .4f, tc)));
            for (int i = 0; i < 6; i++)
            {
                float tw = .5f + .5f * Mathf.Sin(tc * 22f + i * 1.7f);
                Sparkle(new Vector2((J(i + 710) - .5f) * 1.6f * s, (J(i + 711) - .4f) * 1.4f * s), s * .14f, core, Inv(.05f, .1f, tc) * (1f - Inv(.28f, .32f, tc)) * tw, 15f);
            }
            float pt = tc - .3f; if (pt < 0f) return;
            for (int i = 0; i < 10; i++)
            {
                float a = (i + J(i + 712)) * 6.283f / 10f, k = Inv(0f, .3f, pt); if (k >= 1f) continue;
                Sparkle(new Vector2(Mathf.Cos(a), Mathf.Sin(a)) * (s * (.6f + 1f * EOut(k))), s * .2f * (1f - k), i % 2 == 0 ? hot : band3, 1f - k, 15f + i * 20f);
            }
            for (int i = 0; i < 14; i++)
            {
                float life = .4f + .2f * J(i + 713); if (pt > life) continue;
                float cu = pt / life, a = (i + J(i + 714)) * 6.283f / 14f;
                var pp = new Vector2(Mathf.Cos(a), Mathf.Sin(a)) * (s * (.5f + 1.1f * J(i + 715))) * EOut(Mathf.Min(1f, cu * 2f)) + Vector2.down * (3f * s * pt * pt);
                Dot(pp, s * (.05f + .04f * J(i + 716)), band3, 0f, 1f - EIn(cu), pt + i, .15f);
            }
        }

        /// 月牙 (moonfang), light round the painted moon tornado: a blue flash at its foot,
        /// glints drawn up the funnel, dust spiralling in at the floor.
        void MoonWind(float t)
        {
            float s = size, u = t / duration, live = 1f - u;
            Glow(Vector2.zero, 2.2f * s, outer, .18f * Mathf.Pow(live, 1.2f));
            var foot = new Vector2(0f, -.9f * s);
            ImpactStar(foot + Vector2.up * (.4f * s), .8f * s, t, 720);
            Glow(foot + Vector2.up * (.8f * s), 1.4f * s, band3, .4f * (1f - EOut(Inv(0f, .3f, t))));
            for (int i = 0; i < 12; i++)
            {
                float born = .03f + .4f * J(i + 721), mu = Inv(born, born + .45f, t); if (mu <= 0f || mu >= 1f) continue;
                float a = mu * 9f + i, r = s * (.3f + .6f * mu);
                var pp = foot + new Vector2(Mathf.Cos(a) * r, .2f * s + 2.2f * s * mu);
                Sparkle(pp, s * (.09f + .05f * J(i + 722)), i % 3 == 0 ? hot : core, Mathf.Sin(mu * Mathf.PI), 15f + mu * 120f);
            }
            for (int i = 0; i < 10; i++)
            {
                float k = Inv(0f, .55f, t); if (k >= 1f) break;
                float a = i * .628f + t * 8f, r = s * (1.5f - 1f * k) * (.8f + .4f * J(i + 723));
                Dot(foot + new Vector2(Mathf.Cos(a) * r, Mathf.Sin(a) * r * .3f), s * (.06f + .04f * J(i + 724)), band2, 3f, .6f * (1f - k));
            }
        }

        /// 甲背 (shellback) pounce, light round the painted claw tears and rubble: a hot flash on
        /// landing and sparks kicked up.
        void Pounce(float t)
        {
            float s = size, u = t / duration, live = 1f - u;
            Glow(Vector2.zero, 2f * s, outer, .16f * Mathf.Pow(live, 1.2f));
            ImpactStar(Vector2.zero, .9f * s, t, 730);
            Glow(Vector2.zero, 1.3f * s, band3, .4f * (1f - EOut(Inv(0f, .25f, t))));
            Sparks(new Vector2(0f, -.4f * s), t, 16, 107, 2f * s, Vector2.up * .4f, 1f - EIn(Inv(0f, .45f, t)));
        }

        /// 甲背回血 (tower mend), light round the painted lotus: a soft jade glow swelling under
        /// the ally, gold motes and glints rising, a warm pulse when it opens fully.
        void LotusMend(float t)
        {
            float s = size, u = t / duration;
            var foot = new Vector2(0f, -.6f * s);
            float swell = EOut(Inv(0f, .25f, t)) * (1f - EIn(Inv(.5f, 1f, u)));
            Glow(foot + Vector2.up * (.4f * s), 2f * s, outer, .14f * swell);
            Glow(foot + Vector2.up * (.4f * s), 1.1f * s, band3, .3f * swell);
            float pulse = Inv(.2f, .45f, t);
            if (pulse > 0f && pulse < 1f) Glow(Vector2.up * (.2f * s), 1.5f * s * (.6f + .6f * EOut(pulse)), hot, .4f * (1f - pulse));
            for (int i = 0; i < 16; i++)
            {
                float born = .15f + .5f * J(i + 740), mu = Inv(born, born + .55f, t); if (mu <= 0f || mu >= 1f) continue;
                var pp = foot + new Vector2((J(i + 741) - .5f) * 1.8f * s, .2f * s + 2.2f * s * mu);
                if (i % 2 == 0) Sparkle(pp, s * (.1f + .06f * J(i + 742)), hot, Mathf.Sin(mu * Mathf.PI), 15f + mu * 90f);
                else Dot(pp, s * .05f, core, 3f, Mathf.Sin(mu * Mathf.PI));
            }
        }

        /// B01 第七号空壳, light round the painted sword: a red trail behind the blade, then a
        /// hot flash where it cuts, sparks thrown along the diagonal, red glints.
        void B01Slash(float t)
        {
            float s = size, u = t / duration, live = 1f - u;
            Glow(Vector2.zero, 2f * s, outer, .16f * Mathf.Pow(live, 1.2f));
            var pivot = new Vector2(-.25f, 1.45f) * s;
            float a0 = 150f * Mathf.Deg2Rad, a1 = -62f * Mathf.Deg2Rad, sw = EIn(Inv(0f, .16f, t)), a = Mathf.Lerp(a0, a1, sw);
            if (t < .26f) Swoosh(pivot, 2.1f * s, a + 1.4f * (.3f + .7f * (1f - sw)), a, .55f * s, .85f * (1f - Inv(.16f, .26f, t)), t, 760);
            float tc = t - .14f; if (tc < 0f) return;
            ImpactStar(Vector2.zero, 1f * s, tc, 761);
            Glow(Vector2.zero, 1.5f * s, band3, .45f * (1f - EOut(Inv(0f, .25f, tc))));
            Sparks(Vector2.zero, tc, 16, 111, 2.2f * s, new Vector2(.8f, -.6f), 1f - EIn(Inv(0f, .4f, tc)));
        }

        /// B02 背架收尸人, light round the painted straps: a curse glow swelling as they cinch,
        /// sparks at the buckles while they squeeze, a flash when they snap.
        void B02Straps(float t)
        {
            float s = size, u = t / duration, live = 1f - u;
            Glow(Vector2.zero, 2f * s, outer, .16f * Mathf.Pow(live, 1.2f));
            Glow(Vector2.zero, 1.1f * s, band2, .15f * EOut(Inv(0f, .22f, t)) * (1f - Inv(.36f, .45f, t)));
            for (int i = 0; i < 6; i++)
            {
                float a = i * 1.047f + J(i + 770) * .5f, tw = Mathf.Sin(t * 24f + i * 1.7f);
                var p = new Vector2(Mathf.Cos(a), Mathf.Sin(a)) * (s * (.7f + .3f * J(i + 771)));
                Sparkle(p, s * .14f, hot, Inv(.18f, .24f, t) * (1f - Inv(.34f, .38f, t)) * (.5f + .5f * tw), 15f + i * 20f);
            }
            float tc = t - .36f; if (tc < 0f) return;
            ImpactStar(Vector2.zero, .9f * s, tc, 772);
            Sparks(Vector2.zero, tc, 16, 113, 2f * s, Vector2.zero, 1f - EIn(Inv(0f, .4f, tc)));
        }

        /// B03 溺钟海盗 wave, light round the painted wave: a teal flash as it crashes, droplets
        /// thrown and falling, ghost wisps rising.
        void B03Wave(float t)
        {
            float s = size, u = t / duration, live = 1f - u;
            Glow(Vector2.zero, 2f * s, outer, .16f * Mathf.Pow(live, 1.2f));
            // Spray flung off the spinning vortex: drops and foam leave its rim along the spin
            // (clockwise as drawn, mirrored when the wave travels left) and fly out, falling.
            var back = -dir; bool m = back.x > 0f; float spinDir = m ? 1f : -1f;
            var c0 = back * (2.4f * s) + Vector2.up * (.3f * s); var c1 = new Vector2(0f, .25f * s);
            for (int i = 0; i < 28; i++)
            {
                float born = .04f + .3f * J(i + 900), life = .22f + .12f * J(i + 901), dt = t - born;
                if (dt < 0f || dt > life) continue;
                float mvb = EOut(Inv(0f, .34f, born));
                var cen = Vector2.Lerp(c0, c1, mvb);
                float a0 = J(i + 902) * 6.283f, rr = s * (.55f + .4f * mvb) * (.8f + .4f * J(i + 903));
                var radial = new Vector2(Mathf.Cos(a0), Mathf.Sin(a0)); var tang = new Vector2(-radial.y, radial.x) * spinDir;
                var v = (tang * 2.6f + radial * 1.1f) * s;
                var pp = cen + radial * rr + v * dt + Vector2.down * (2.4f * s * dt * dt);
                float cu = dt / life;
                if (i % 4 == 0) Sparkle(pp, s * .12f * (1f - cu), core, 1f - cu, 15f + i * 20f);
                else Dot(pp, s * (.05f + .05f * J(i + 904)) * (1f - .5f * cu), i % 3 == 0 ? core : band3, 0f, 1f - EIn(cu), dt + i, .25f, 1.4f, .8f);
            }
            float tc = t - .34f; if (tc < 0f) return;
            ImpactStar(Vector2.zero, .9f * s, tc, 780);
            Glow(Vector2.zero, 1.4f * s, band3, .4f * (1f - EOut(Inv(0f, .25f, tc))));
            Drips(new Vector2(0f, .3f * s), tc, 10, 781, 1.6f * s, 1f - EIn(Inv(.3f, .6f, tc)));
            for (int i = 0; i < 8; i++)
            {
                float born = .05f + .35f * J(i + 782), mu = Inv(born, born + .5f, tc); if (mu <= 0f || mu >= 1f) continue;
                var p = new Vector2((J(i + 783) - .5f) * 1.8f * s + Mathf.Sin(mu * 6f + i) * .2f * s, -.3f * s + 1.8f * s * mu);
                Dot(p, s * (.1f + .06f * J(i + 784)), band3, 3f, .7f * Mathf.Sin(mu * Mathf.PI));
            }
        }

        /// B03 溺钟海盗 bell, light round the painted bell: ghost-fire glow under it, toll ripples
        /// (open arcs either side, never closed rings) when it lands, glints.
        void B03Bell(float t)
        {
            float s = size, u = t / duration, live = 1f - u;
            Glow(Vector2.zero, 2.2f * s, outer, .18f * Mathf.Pow(live, 1.2f));
            float tc = t - .2f; if (tc < 0f) return;
            ImpactStar(new Vector2(0f, -.1f * s), 1.1f * s, tc, 790);
            Glow(new Vector2(0f, -.1f * s), 1.5f * s, band3, .5f * (1f - EOut(Inv(0f, .3f, tc))));
            for (int k = 0; k < 3; k++)
            {
                float born = .06f * k, age = tc - born; if (age < 0f || age > .4f) continue;
                float r = s * (.6f + 1.6f * EOut(age / .4f)), a = .7f * (1f - age / .4f);
                Arc(new Vector2(0f, .3f * s), r, .07f * s, 140f, 80f, band3, a);
                Arc(new Vector2(0f, .3f * s), r, .07f * s, -40f, 80f, band3, a);
            }
            for (int i = 0; i < 10; i++)
            {
                float born = .05f + .4f * J(i + 791), mu = Inv(born, born + .45f, tc); if (mu <= 0f || mu >= 1f) continue;
                var p = new Vector2((J(i + 792) - .5f) * 1.8f * s, -.2f * s + 1.6f * s * mu);
                Sparkle(p, s * (.1f + .05f * J(i + 793)), i % 2 == 0 ? hot : core, Mathf.Sin(mu * Mathf.PI), 15f + mu * 90f);
            }
        }

        /// B04 铜笔伪造者, light round the painted quill and ink: the forged line drawn in violet
        /// ink behind the nib, a flash when it stabs, gold glints in the splash.
        void B04Quill(float t)
        {
            float s = size, u = t / duration, live = 1f - u;
            Glow(Vector2.zero, 2f * s, outer, .16f * Mathf.Pow(live, 1.2f));
            // Ink drops flicked off the nib as it writes, falling (no drawn line: a glowing
            // stroke read as a light bar).
            Vector2[] path = { new Vector2(-1.1f, .9f), new Vector2(.2f, .3f), new Vector2(-.4f, .1f), new Vector2(1f, -.3f) };
            for (int i = 0; i < 16; i++)
            {
                float born = .2f * i / 16f, dt = t - born; if (dt < 0f || dt > .45f) continue;
                float w = born / .2f * 3f; int seg = Mathf.Min(2, (int)w);
                var p0 = Vector2.Lerp(path[seg], path[seg + 1], w - seg) * s;
                var pp = p0 + new Vector2((J(i + 800) - .5f) * .3f * s, -.1f * s) + Vector2.down * (3f * s * dt * dt);
                Dot(pp, s * (.05f + .04f * J(i + 801)) * (1f - dt / .45f * .5f), i % 3 == 0 ? band3 : band2, 0f, 1f - EIn(dt / .45f), dt + i, .2f);
            }
            float tc = t - .25f; if (tc < 0f) return;
            ImpactStar(Vector2.zero, 1f * s, tc, 803);
            Glow(Vector2.zero, 1.5f * s, hot, .4f * (1f - EOut(Inv(0f, .3f, tc))));
            for (int i = 0; i < 10; i++)
            {
                float born = .03f + .35f * J(i + 804), mu = Inv(born, born + .45f, tc); if (mu <= 0f || mu >= 1f) continue;
                var p = new Vector2((J(i + 805) - .5f) * 1.8f * s, (J(i + 806) - .4f) * 1.6f * s);
                Sparkle(p, s * (.1f + .06f * J(i + 807)), hot, Mathf.Sin(mu * Mathf.PI), 15f + mu * 90f);
            }
        }

        /// B05 赤丝裁衣人 needles, light round the painted needles: crimson streaks behind them,
        /// a flash and red sparks where they stick.
        void B05Needles(float t)
        {
            float s = size, u = t / duration, live = 1f - u;
            Glow(Vector2.zero, 1.8f * s, outer, .16f * Mathf.Pow(live, 1.2f));
            var start = -dir * (2.6f * s);
            if (t < .18f)
            {
                float mv = EIn(Inv(0f, .14f, t)), bk = EIn(Inv(0f, .14f, t - .06f));
                for (int k = -1; k <= 1; k++)
                {
                    var n = new Vector2(-dir.y, dir.x) * (k * .45f * s);
                    Taper(Vector2.Lerp(start, Vector2.zero, bk) + n, Vector2.Lerp(start, Vector2.zero, mv) + n, .01f * s, .09f * s, band3, .6f * (1f - Inv(.14f, .18f, t)));
                }
            }
            float tc = t - .14f; if (tc < 0f) return;
            ImpactStar(Vector2.zero, .8f * s, tc, 810);
            Sparks(Vector2.zero, tc, 14, 117, 1.8f * s, dir * .6f, 1f - EIn(Inv(0f, .35f, tc)));
        }

        /// B05 赤丝裁衣人 silk bind, light round the painted web: a crimson glow tightening at
        /// its heart, glints on the beads, a flash when it snaps.
        void B05Threads(float t)
        {
            float s = size, u = t / duration, live = 1f - u;
            Glow(Vector2.zero, 2.2f * s, outer, .18f * Mathf.Pow(live, 1.2f));
            Glow(Vector2.zero, 1f * s, band3, .2f * EOut(Inv(.1f, .36f, t)) * (1f - Inv(.5f, .56f, t)));
            for (int i = 0; i < 8; i++)
            {
                float a = i * .785f + t * .6f, r = s * (1.6f - .7f * EOut(Inv(.1f, .36f, t)));
                Sparkle(new Vector2(Mathf.Cos(a), Mathf.Sin(a)) * r + Vector2.up * (.1f * s), s * .12f, hot, Inv(.12f, .2f, t) * (1f - Inv(.52f, .56f, t)) * (.5f + .5f * Mathf.Sin(t * 22f + i)), 15f);
            }
            float tc = t - .5f; if (tc < 0f) return;
            ImpactStar(Vector2.zero, .9f * s, tc, 820);
            Sparks(Vector2.zero, tc, 16, 119, 2f * s, Vector2.zero, 1f - EIn(Inv(0f, .4f, tc)));
        }

        /// B06 无灯押船人, light round the painted anchor: a cold blue flash when it slams,
        /// spray thrown up and falling, sparks.
        void B06Anchor(float t)
        {
            float s = size, u = t / duration, live = 1f - u;
            Glow(Vector2.zero, 2.2f * s, outer, .18f * Mathf.Pow(live, 1.2f));
            float tc = t - .22f; if (tc < 0f) return;
            ImpactStar(new Vector2(0f, -.2f * s), 1.1f * s, tc, 830);
            Glow(Vector2.zero, 1.6f * s, band3, .45f * (1f - EOut(Inv(0f, .3f, tc))));
            Drips(new Vector2(0f, -.2f * s), tc, 12, 831, 2f * s, 1f - EIn(Inv(.3f, .6f, tc)));
            Sparks(new Vector2(0f, -.4f * s), tc, 14, 121, 2f * s, Vector2.up * .3f, 1f - EIn(Inv(0f, .4f, tc)));
        }

        /// B07 金囊蛙 knock, light round the painted shock: forked lightning snapping out from the
        /// target, a white-gold flash, crackling sparks.
        void B07Knock(float t)
        {
            float s = size, u = t / duration, live = 1f - u;
            Glow(Vector2.zero, 1.8f * s, outer, .1f * Mathf.Pow(live, 1.2f));
            ImpactStar(new Vector2(0f, .1f * s), .6f * s, t, 840);
            float lf = 1f - EIn(Inv(.05f, .32f, t));
            for (int k = 0; k < 5; k++)
            {
                float a = (k * 72f + 20f + (J(k + 841) - .5f) * 40f) * Mathf.Deg2Rad;
                Lightning(new Vector2(0f, .1f * s), new Vector2(Mathf.Cos(a), Mathf.Sin(a)) * (s * (1.2f + .6f * J(k + 842))), 843 + k + (int)(t * 14f), .05f * s, .7f * lf, 1);
            }
            Sparks(Vector2.zero, t, 16, 125, 2f * s, Vector2.zero, 1f - EIn(Inv(0f, .4f, t)));
        }

        /// B07 金囊蛙 spittle, light round the painted venom: a sick green flash, drips, bubbles.
        void B07Spit(float t)
        {
            float s = size, u = t / duration, live = 1f - u;
            Glow(Vector2.zero, 2f * s, outer, .16f * Mathf.Pow(live, 1.2f));
            float tc = t - .18f; if (tc < 0f) return;
            ImpactStar(Vector2.zero, .8f * s, tc, 850);
            Drips(new Vector2(0f, .1f * s), tc, 8, 851, 1.4f * s, 1f - EIn(Inv(.35f, .7f, tc)));
            for (int i = 0; i < 10; i++)
            {
                float born = .1f + .4f * J(i + 852), mu = Inv(born, born + .5f, tc); if (mu <= 0f || mu >= 1f) continue;
                Dot(new Vector2((J(i + 853) - .5f) * 1.6f * s, -.3f * s + 1.4f * s * mu), s * (.05f + .03f * J(i + 854)), band3, 0f, Mathf.Sin(mu * Mathf.PI), tc + i, .15f);
            }
        }

        /// B08 镜像分身, light round the painted mirror and rapier: a white flash as the mirror
        /// bursts, a piercing glint where the blade runs the target through, blue sparks.
        void B08Stab(float t)
        {
            float s = size, u = t / duration, live = 1f - u;
            Glow(Vector2.zero, 2f * s, outer, .16f * Mathf.Pow(live, 1.2f));
            var mirrorAt = -dir * (1.3f * s) + Vector2.up * (.35f * s);
            float mt = t - .16f;
            if (mt >= 0f) { ImpactStar(mirrorAt, .6f * s, mt, 860); }
            float tc = t - .2f; if (tc < 0f) return;
            Sparkle(Vector2.zero, s * .6f * (1f - Inv(0f, .25f, tc)), core, .8f * (1f - Inv(0f, .25f, tc)), 15f);
            Glow(Vector2.zero, 1.1f * s, band3, .2f * (1f - EOut(Inv(0f, .25f, tc))));
            Sparks(Vector2.zero, tc, 14, 127, 1.8f * s, dir * .7f, 1f - EIn(Inv(0f, .35f, tc)));
        }

        /// B08 镜像分身 echo, light round the ghost rapier: a pale flash and glints where it shatters.
        void B08Echo(float t)
        {
            float s = size, u = t / duration, live = 1f - u;
            Glow(Vector2.zero, 1.8f * s, outer, .14f * Mathf.Pow(live, 1.2f));
            float tc = t - .12f; if (tc < 0f) return;
            ImpactStar(Vector2.zero, .7f * s, tc, 865);
            for (int i = 0; i < 8; i++)
            {
                float born = .02f + .25f * J(i + 866), mu = Inv(born, born + .4f, tc); if (mu <= 0f || mu >= 1f) continue;
                Sparkle(new Vector2((J(i + 867) - .5f) * 1.6f * s, (J(i + 868) - .4f) * 1.4f * s), s * .12f, core, Mathf.Sin(mu * Mathf.PI), 15f + mu * 90f);
            }
        }

        /// B09 铠虎 rend, light round the painted burning claws: an orange streak along the rake,
        /// a hot flash, embers.
        void B09Rend(float t)
        {
            float s = size, u = t / duration, live = 1f - u;
            Glow(Vector2.zero, 2f * s, outer, .18f * Mathf.Pow(live, 1.2f));
            float tc = t - .1f; if (tc < 0f) return;
            ImpactStar(Vector2.zero, .9f * s, tc, 870);
            Glow(Vector2.zero, 1.5f * s, hot, .4f * (1f - EOut(Inv(0f, .3f, tc))));
            Sparks(Vector2.zero, tc, 16, 129, 2f * s, new Vector2(-.6f, -.6f), 1f - EIn(Inv(0f, .4f, tc)));
        }

        /// B10 换寿恶魔 veil, light round the painted wings: a rose glow swelling behind the
        /// target, glints on each wingbeat, a flash as the wings tear.
        void B10Veil(float t)
        {
            float s = size, u = t / duration, live = 1f - u;
            Glow(new Vector2(0f, .3f * s), 2.2f * s, outer, .1f * Mathf.Pow(live, 1.2f));
            Glow(new Vector2(0f, .3f * s), 1.2f * s, band3, .15f * EOut(Inv(0f, .2f, t)) * (1f - Inv(.34f, .45f, t)));
            for (int i = 0; i < 8; i++)
            {
                float side = i % 2 == 0 ? -1f : 1f, a = J(i + 880);
                var p = new Vector2(side * (.6f + 1f * a) * s, (.1f + .9f * J(i + 881)) * s);
                Sparkle(p, s * .13f, hot, Inv(.15f, .2f, t) * (1f - Inv(.32f, .36f, t)) * (.5f + .5f * Mathf.Sin(t * 20f + i)), 15f);
            }
            float tc = t - .34f; if (tc < 0f) return;
            ImpactStar(new Vector2(0f, .3f * s), .9f * s, tc, 882);
        }

        /// B10 vessel's mend, light round the folding wings: a warm rose glow, motes rising.
        void CrimsonMend(float t)
        {
            float s = size, u = t / duration;
            float swell = EOut(Inv(0f, .25f, t)) * (1f - EIn(Inv(.5f, 1f, u)));
            Glow(new Vector2(0f, .2f * s), 2f * s, outer, .14f * swell);
            Glow(new Vector2(0f, .2f * s), 1.1f * s, band3, .3f * swell);
            for (int i = 0; i < 14; i++)
            {
                float born = .15f + .5f * J(i + 890), mu = Inv(born, born + .55f, t); if (mu <= 0f || mu >= 1f) continue;
                var pp = new Vector2((J(i + 891) - .5f) * 1.8f * s, -.4f * s + 2.2f * s * mu);
                if (i % 2 == 0) Sparkle(pp, s * (.1f + .06f * J(i + 892)), hot, Mathf.Sin(mu * Mathf.PI), 15f + mu * 90f);
                else Dot(pp, s * .05f, core, 3f, Mathf.Sin(mu * Mathf.PI));
            }
        }

        /// The weight of an enemy hit (2026-10-09, after the UE reference reel, user: 可以，按你建议
        /// 的做): a white flash for the first frames, the floor lit in an uneven pool under the
        /// target, a scorch that lingers, and chunks and sparks thrown up that fall back and bounce
        /// on the floor. Under every enemy attack (not support casts).
        void ImpactLayer(float t)
        {
            // 翠毒漫天's bubbles are the user's painted ones lying in its pool (PoisonPool, 2026-10-10,
            // user of these flat blobs: 这些泡泡有些假), so its hit throws no blobs of its own.
            bool pool_ = kind == "emeraldfog";
            if (t < 0f || t > 1.4f) return;
            float s = size;
            var foot = new Vector2(0f, -.88f * s);
            // A hot white pop at the contact, small and brief (two or three frames).
            float flash = 1f - Inv(0f, .05f, t);
            if (flash > 0f)
            {
                // In the spell's own colours (user 2026-10-09: 光要和法术颜色和谐，比如紫色绿色等).
                Glow(Vector2.zero, 1.2f * s, band3, .5f * flash);
                Dot(Vector2.zero, s * (.35f + .35f * (1f - flash)), Color.Lerp(core, band3, .35f), 2f, .7f * flash, t, .3f);
            }
            // The floor lit under the hit: a modest uneven pool, quickly gone (never a band).
            float pool = Inv(0f, .04f, t) * (1f - Smooth(Inv(.08f, .6f, t)));
            if (pool > .01f)
            {
                float spread = .75f + .3f * EOut(Inv(0f, .25f, t));
                Dot(foot, .75f * s * spread, Color.Lerp(band2, band3, .5f), 3f, .32f * pool, t * .6f, .3f, 1.3f, .42f);
            }
            float scorch = Inv(.04f, .12f, t) * (1f - Smooth(Inv(.5f, 1.2f, t)));
            if (scorch > .01f)
            {
                Dot(foot + new Vector2(0f, -.02f * s), .62f * s, new Color(.07f, .045f, .035f), 2f, .4f * scorch, 1.7f, .35f, 1.4f, .38f);
                for (int i = 0; i < 6; i++)
                {
                    float tw = .5f + .5f * Mathf.Sin(t * (11f + 3f * J(i + 950)) + i * 2.1f);
                    var p = foot + new Vector2((J(i + 951) - .5f) * 1.0f * s, (J(i + 952) - .5f) * .22f * s);
                    Dot(p, s * (.03f + .02f * J(i + 953)), band3, 3f, scorch * tw * (1f - Inv(.3f, 1.1f, t)));
                }
            }
            // Thrown chunks and sparks: integrated under gravity, bouncing on the floor line.
            for (int i = 0; i < 12; i++)
            {
                float ang = (25f + 130f * J(i + 960)) * Mathf.Deg2Rad, sp = s * (2.2f + 2.4f * J(i + 961));
                var v = new Vector2(Mathf.Cos(ang), Mathf.Sin(ang)) * sp;
                var p = new Vector2((J(i + 962) - .5f) * .4f * s, -.35f * s);
                if ((pool_ || kind == "nameseal" || kind == "bronzeslam") && i % 3 == 2) continue;   // flat blobs read fake (user 10-10)
                float g = 11f * s, dt = 1f / 90f, life = .7f + .35f * J(i + 963);
                if (t > life) continue;
                for (float u = 0f; u < t; u += dt)
                {
                    v.y -= g * dt; p += v * dt;
                    if (p.y < foot.y && v.y < 0f) { p.y = foot.y; v.y = -v.y * .38f; v.x *= .7f; }
                }
                float a = 1f - Smooth(Inv(life * .6f, life, t));
                if (i % 3 == 0) Sparkle(p, s * (.1f + .05f * J(i + 964)) * a, core, a, 15f + i * 30f);
                else if (i % 3 == 1) Dot(p, s * (.06f + .05f * J(i + 965)), band3, 3f, a);
                else Dot(p, s * (.07f + .05f * J(i + 966)), Color.Lerp(outer, band2, .4f), 0f, a, t + i, .35f, 1.2f, .9f);
            }
        }

        /// The floor of poison bubbles (see CreatePool). Each bubble lives a few seconds - swells
        /// in, sits throbbing, pops with a small green puff - and comes back somewhere else.
        void PoisonPool(float t)
        {
            float s = size;
            float show = Smooth(Inv(0f, .6f, t)) * (poolEnd >= 0f ? 1f - Inv(poolEnd, poolEnd + .5f, t) : 1f);
            if (show <= 0f) return;
            float tick = 1f - Inv(0f, .45f, t - poolTick);
            float spread = Mathf.Min(1.5f, 1f + .06f * poolLevel);
            // A faint sheen of poison on the floor under them, brighter for a moment at each tick.
            Dot(Vector2.zero, .95f * s * spread, Color.Lerp(outer, band2, .35f), 3f, (.1f + .12f * tick) * show, t * .3f, .3f, 1.6f, .38f);
            // The bubbles themselves are the user's painted ones (sprites, see SpellSpectacle20260926.PoisonPool);
            // here only a soft glow under each and a green puff as it pops.
            for (int i = 0; i < 24; i++)
            {
                PoolBubble(i, out var p, out var r, out var a, out var pop);
                if (a > .01f) Dot(p + new Vector2(0f, -.4f * r), r * 1.3f, band2, 3f, .18f * a, 0f, .12f, 1.4f, .5f);
                if (pop > 0f) Dot(p, r * (1.3f + 1.8f * pop), band3, 3f, .5f * (1f - pop) * show);
            }
        }

        /// The enemy charging its attack (2026-10-09): light gathers at its weapon or hand from
        /// the cast - a glow that swells and pulses, motes spiralling in, small tongues of its
        /// colour licking inward, a flickering star - and when the attack lands it fires: a flash
        /// at the hand and the motes burst outward.
        void Gather(float t)
        {
            float s = size;
            if (released < 0f)
            {
                float grow = Smooth(t / .45f), pulse = .85f + .15f * Mathf.Sin(t * 15f), fade = 1f - Inv(MaxGather - .3f, MaxGather, t);
                grow *= fade;
                Glow(Vector2.zero, 1.7f * s * grow, outer, .35f * grow);
                Glow(Vector2.zero, .85f * s * grow * pulse, band3, .55f * grow);
                Dot(Vector2.zero, .17f * s * grow * pulse, core, 3f, grow);
                for (int i = 0; i < 11; i++)
                {
                    float ph = Mathf.Repeat(t * (1.3f + .5f * J(i + 970)) + J(i + 971), 1f);
                    float r = s * (1.6f - 1.45f * ph), ang = i * .57f + ph * 4.5f;
                    var p = new Vector2(Mathf.Cos(ang), Mathf.Sin(ang)) * r;
                    Dot(p, s * (.05f + .04f * J(i + 972)) * (.6f + .6f * ph), i % 3 == 0 ? core : band3, 3f, Mathf.Sin(ph * Mathf.PI) * grow);
                }
                for (int k = 0; k < 4; k++)
                {
                    float ang = k * 1.571f + t * 3f + J(k + 975), ph = Mathf.Repeat(t * 2.2f + k * .25f, 1f);
                    var d = new Vector2(Mathf.Cos(ang), Mathf.Sin(ang));
                    Flame(d * (s * (1.1f - .5f * ph)), -d, s * (.45f + .2f * ph), .22f * s, t, 975 + k, .25f, .7f * grow * Mathf.Sin(ph * Mathf.PI), .6f, 0f, band3);
                }
                Sparkle(Vector2.zero, s * .5f * grow * pulse, core, .85f * grow, t * 70f);
                return;
            }
            float rel = age - released;
            float rf = 1f - Inv(0f, .25f, rel);
            Glow(Vector2.zero, 1.5f * s, band3, .75f * rf);
            Sparkle(Vector2.zero, s * .9f * rf, core, rf, 15f + rel * 120f);
            for (int i = 0; i < 12; i++)
            {
                float ang = i * .52f + J(i + 981), k = Inv(0f, .3f + .1f * J(i + 982), rel);
                if (k >= 1f) continue;
                var p = new Vector2(Mathf.Cos(ang), Mathf.Sin(ang)) * (s * (.2f + 1.8f * EOut(k)));
                Dot(p, s * (.06f + .04f * J(i + 983)) * (1f - .5f * k), i % 3 == 0 ? core : band3, 3f, 1f - k);
            }
        }

        /// A hammer head in the painterly bands: a bevelled box across ax filled from a bright
        /// heart out to a dark rim (like every other drawn shape), lit edges on top.
        void Block(Vector2 c, Vector2 ax, float w, float d, float a)
        {
            if (a <= .01f) return;
            ax = ax.normalized; var ay = new Vector2(-ax.y, ax.x); if (ay.y < 0f) ay = -ay;
            float bw = w * .5f, bd = d * .5f, bv = d * .22f;
            Vector2 Pt(float x, float y) => c + ax * x + ay * y;
            Vector2[] o = { Pt(-bw + bv, bd), Pt(bw - bv, bd), Pt(bw, bd - bv), Pt(bw, -bd + bv), Pt(bw - bv, -bd), Pt(-bw + bv, -bd), Pt(-bw, -bd + bv), Pt(-bw, bd - bv) };
            // A spine across the box (not a point) so the bands follow the box shape.
            int i0 = vs.Count; seedNow = J(i0 + 9);
            var l = Pt(-bw * .7f, 0f); var r = Pt(bw * .7f, 0f);
            V(l, 1f, 0f, band3, .5f, a); V(r, 1f, 0f, band3, .5f, a);
            for (int k = 0; k < 8; k++) V(o[k], 0f, 0f, band3, .5f, a);
            // top: o0,o1 with r,l ; right: o1,o2,o3 to r ; bottom: o4,o5 ; left: o6,o7,o0 to l
            int L0 = i0, R0 = i0 + 1; int O(int k) => i0 + 2 + k;
            tris.Add(L0); tris.Add(O(0)); tris.Add(O(1)); tris.Add(L0); tris.Add(O(1)); tris.Add(R0);
            tris.Add(R0); tris.Add(O(1)); tris.Add(O(2)); tris.Add(R0); tris.Add(O(2)); tris.Add(O(3)); tris.Add(R0); tris.Add(O(3)); tris.Add(O(4));
            tris.Add(R0); tris.Add(O(4)); tris.Add(O(5)); tris.Add(R0); tris.Add(O(5)); tris.Add(L0);
            tris.Add(L0); tris.Add(O(5)); tris.Add(O(6)); tris.Add(L0); tris.Add(O(6)); tris.Add(O(7)); tris.Add(L0); tris.Add(O(7)); tris.Add(O(0));
            Taper(o[0], o[1], d * .05f, d * .05f, core, .7f * a);
            Taper(o[7], o[0], d * .04f, d * .04f, core, .5f * a);
        }

        void FlatTri(Vector2 a1, Vector2 a2, Vector2 a3, Color c, float a)
        {
            int i0 = vs.Count; seedNow = 0f;
            V(a1, 1f, 1f, c, .5f, a); V(a2, 1f, 1f, c, .5f, a); V(a3, 1f, 1f, c, .5f, a);
            tris.Add(i0); tris.Add(i0 + 1); tris.Add(i0 + 2);
        }

        /// 裁定锤卫 (archive adjudicator): a huge spectral warhammer of blue crystal bound in
        /// gold swings down over its head onto the target with a broad trail - a gold verdict
        /// flash, the ground cracks blue and gold, dust billows out low, then the hammer
        /// lifts and dissolves into motes.
        void Verdict(float t)
        {
            float s = size, u = t / duration, live = 1f - u;
            Glow(Vector2.zero, 2.6f * s, outer, .22f * Mathf.Pow(live, 1.2f));
            const float Hit = .2f;
            var back = -dir;
            var pivot = back * (1.3f * s) + new Vector2(back.x >= 0f ? -.8f : .8f, 0f) * s;
            float sw = EIn(Inv(0f, Hit, t)), up = EOut(Inv(Hit + .06f, Hit + .3f, t));
            float hf = Inv(0f, .05f, t) * (1f - EIn(Inv(Hit + .2f, Hit + .38f, t)));
            var toT = (Vector2.zero - pivot); float L = 1.85f * s; float endA = Mathf.Atan2(toT.y, toT.x);
            float sgn = pivot.x < 0f ? 1f : -1f;
            float ang = endA + sgn * (1f - sw) * 1.9f + sgn * up * .25f;
            var hd = new Vector2(Mathf.Cos(ang), Mathf.Sin(ang));
            var head = pivot + hd * L;
            if (t < Hit + .1f)
            {
                float tf = 1f - Inv(Hit, Hit + .1f, t);
                Swoosh(pivot, L, ang + sgn * 1.5f * (.4f + .6f * (1f - sw)), ang, .65f * s, .85f * tf, t, 540);
            }
            float tc = t - Hit;
            if (tc < 0f) return;
            var floor = new Vector2(0f, -.7f * s);
            ImpactStar(Vector2.zero, 1.2f * s, tc, 545);
            Glow(Vector2.zero, 2f * s, hot, .75f * (1f - EOut(Inv(0f, .25f, tc))));
            ShockRing(floor, s * (.5f + 2.4f * EOut(Inv(0f, .32f, tc))), .12f * s, band3, .5f * (1f - Inv(0f, .32f, tc)), t);
            float cg = EOut(Inv(0f, .05f, tc)), cf = 1f - EIn(Inv(.28f, .5f, tc));
            float grow = EOut(Inv(0f, .1f, tc)), ff = 1f - EIn(Inv(.14f, .4f, tc));
            for (int i = 0; i < 6; i++)
            {
                float sg = i % 2 == 0 ? 1f : -1f, aa = (sg > 0f ? 0f : Mathf.PI) + sg * (.15f + .35f * (i / 2) / 2f) + (J(i + 550) - .5f) * .2f;
                var dv = new Vector2(Mathf.Cos(aa), Mathf.Sin(aa));
                float Lt = s * (.8f + .6f * J(i + 551)) * grow;
                Flame(floor + dv * (.3f * s), dv, Lt, (.4f + .12f * J(i + 552)) * s, tc, 550 + i, .2f, ff, sg * .4f, 0f, i % 3 == 0 ? hot : band3);
            }
            for (int i = 0; i < 12; i++)
            {
                float born = .05f + .35f * J(i + 555), mu = Inv(born, born + .45f, tc); if (mu <= 0f || mu >= 1f) continue;
                var pp = head + new Vector2((J(i + 556) - .5f) * 1.6f * s, (J(i + 557) - .5f) * .8f * s + 1.2f * s * mu);
                if (i % 3 == 0) Sparkle(pp, s * (.12f + .06f * J(i + 558)), hot, Mathf.Sin(mu * Mathf.PI), 15f + mu * 90f);
                else Dot(pp, s * .06f, band3, 3f, Mathf.Sin(mu * Mathf.PI));
            }
        }

        /// A faceted crystal: a long pointed shard split along its spine into a shadow face, a
        /// narrow mid facet and a lit face (flat colours, so it reads as a solid with volume),
        /// a bright ridge along the spine, a lit outer edge and a hot glint at the tip.
        void Crystal(Vector2 b, Vector2 d, float len, float wid, float fade)
        {
            if (len <= .001f || fade <= .01f) return;
            d = d.normalized; var n = new Vector2(-d.y, d.x);
            if (n.x > 0f) n = -n; // n always points left on screen: the left face is the shadow
            var tip = b + d * len; var sh = b + d * (len * .58f);
            var l = sh + n * (wid * .5f); var r = sh - n * (wid * .56f);
            var m = sh - n * (wid * .12f);
            var bl = b + n * (wid * .3f); var br = b - n * (wid * .34f);
            var lit = Color.Lerp(band3, core, .45f); var mid = Color.Lerp(band2, band3, .35f); var shade = Color.Lerp(outer, band2, .15f);
            void Tri(Vector2 a1, Vector2 a2, Vector2 a3, Color c) { int i0 = vs.Count; seedNow = 0f; V(a1, 1f, 1f, c, .5f, fade); V(a2, 1f, 1f, c, .5f, fade); V(a3, 1f, 1f, c, .5f, fade); tris.Add(i0); tris.Add(i0 + 1); tris.Add(i0 + 2); }
            Tri(b, bl, l, shade); Tri(b, l, tip, shade);
            Tri(b, tip, m, mid);
            Tri(b, m, r, lit); Tri(m, tip, r, lit); Tri(b, r, br, lit);
            Taper(b + d * (len * .04f), tip, wid * .07f, wid * .015f, core, .85f * fade);
            Taper(r, tip, wid * .07f, wid * .01f, core, .7f * fade);
            Taper(br, r, wid * .06f, wid * .05f, core, .5f * fade);
            Glow(tip, wid * .7f, core, .35f * fade);
        }

        /// A six-armed snowflake glyph, small, additive, turning.
        void Snowflake(Vector2 c, float r, float rot, float a)
        {
            if (a <= .01f || r <= .001f) return;
            for (int k = 0; k < 6; k++)
            {
                float ang = rot + k * Mathf.PI / 3f; var d = new Vector2(Mathf.Cos(ang), Mathf.Sin(ang));
                Taper(c, c + d * r, r * .16f, r * .06f, core, a);
                var m = c + d * (r * .55f);
                Taper(m, m + Rot(d, .7f) * (r * .3f), r * .1f, r * .03f, core, a * .8f);
                Taper(m, m + Rot(d, -.7f) * (r * .3f), r * .1f, r * .03f, core, a * .8f);
            }
            Glow(c, r * 1.2f, band3, .35f * a);
        }

        /// A low snow cloud: soft white puffs of different sizes swelling out along the floor
        /// line, the lower ones tinted blue, drifting up a little and thinning out.
        void SnowCloud(Vector2 c, float w, float t, float a)
        {
            if (a <= .01f) return;
            for (int i = 0; i < 13; i++)
            {
                float u = J(i + 410), side = (u - .5f) * 2f;
                float grow = EOut(t * 2.6f);
                float x = side * w * (.35f + .65f * grow);
                float r = w * (.1f + .12f * J(i + 411)) * (.55f + .6f * grow) * (1f - .45f * Mathf.Abs(side));
                float y = (J(i + 412) - .3f) * .25f * w + .25f * w * t * J(i + 413);
                var col = i % 3 == 0 ? Color.Lerp(band3, core, .3f) : Color.Lerp(core, Color.white, .4f);
                Dot(c + new Vector2(x, y + r * .3f), r, col, 2f, a * (.32f + .2f * J(i + 414)), t + i, .3f, 1.35f, .75f);
            }
        }

        /// A teardrop: round head at c, tail pointing along d (its direction of travel's back).
        void Drop(Vector2 c, Vector2 d, float len, float wid, Color col, float mode)
        {
            d = d.normalized; var side = new Vector2(-d.y, d.x);
            const int N = 12;
            int i0 = vs.Count; seedNow = J(i0 + 5); V(c - d * (wid * .2f), 1f, mode, col, .8f);
            for (int i = 0; i < N; i++)
            {
                float a = Mathf.PI * (i / (float)(N - 1)) + Mathf.PI * .5f;   // the round back half, away from d
                V(c + (d * Mathf.Cos(a) + side * Mathf.Sin(a)) * wid, 0f, mode, col, .8f, 1f, Mathf.Sin(a));
            }
            V(c + d * len, 0f, mode, col, 0f);
            int n = N + 1;
            for (int i = 0; i < n; i++) { tris.Add(i0); tris.Add(i0 + 1 + i); tris.Add(i0 + 1 + (i + 1) % n); }
        }

        /// The swap comets' path: in on a tightening spiral until they meet at the target, then
        /// out on the other one's side.
        Vector2 Comet(int k, float t)
        {
            const float Meet = .2f;
            float th0 = (k == 0 ? .6f : .6f + Mathf.PI) + Mathf.Atan2(dir.y, dir.x);
            if (t < Meet)
            {
                float e = EOut(Mathf.Max(0f, t) / Meet);
                float r = size * (1.5f * (1f - e) + .05f);
                float th = th0 + 4.2f * e;
                return new Vector2(Mathf.Cos(th), Mathf.Sin(th)) * r;
            }
            float o = EOut((t - Meet) / .45f);
            float th2 = th0 + 4.2f + Mathf.PI + 1.8f * o;
            float r2 = size * (.05f + 1.1f * o);
            return new Vector2(Mathf.Cos(th2), Mathf.Sin(th2)) * r2;
        }

        /// A scorched crack: a jagged dark line tapering away from c, with a thin glowing
        /// seam along it while it is hot, and a short branch.
        void Crack(Vector2 c, Vector2 d, float len, float w, int seed, Color dark, float a, float heat)
        {
            if (len <= .001f || a <= .01f) return;
            var p = c; float ang = Mathf.Atan2(d.y, d.x);
            const int Segs = 6;
            for (int i = 0; i < Segs; i++)
            {
                ang += (J(seed + i) - .5f) * .9f;
                var q = p + new Vector2(Mathf.Cos(ang), Mathf.Sin(ang)) * (len / Segs);
                float w0 = w * (1f - i / (float)Segs), w1 = w * (1f - (i + 1) / (float)Segs);
                Taper(p, q, w0, w1, dark, a, 1f);
                if (heat > .01f) Taper(p, q, w0 * .3f, w1 * .3f, hot, heat);
                if (i == 2 && J(seed + 9) > .35f)
                {
                    float bang = ang + (J(seed + 10) > .5f ? .8f : -.8f);
                    var bq = p + new Vector2(Mathf.Cos(bang), Mathf.Sin(bang)) * (len * .3f);
                    Taper(p, bq, w0 * .6f, 0f, dark, a, 1f);
                }
                p = q;
            }
        }

        /// Wax drops thrown up and out from c, falling back under gravity.
        void Drips(Vector2 c, float t, int n, int seed, float speed, float fade)
        {
            for (int i = 0; i < n; i++)
            {
                float ang = (-15f + 210f * J(seed + i)) * Mathf.Deg2Rad; float sp = speed * (.35f + .65f * J(seed + i + 1)); float life = .35f + .3f * J(seed + i + 2);
                float age = t - .03f; if (age < 0f || age > life) continue;
                float uu = age / life, e = Mathf.Exp(-2.2f * age), disp = (1f - e) / 2.2f;
                var v = new Vector2(Mathf.Cos(ang), Mathf.Sin(ang)) * sp;
                var p = c + v * disp + Vector2.down * (3.2f * size * age * age);
                float r = size * (.035f + .045f * J(seed + i + 3)) * (1f - uu * .5f);
                Dot(p, r, band3, 0f, fade * Mathf.Pow(1f - uu, .6f), age * 3f, .1f);
            }
        }

        // ---- shapes: polygons whose uv.x is 0 on the outline and 1 on the core line

        Vector3 W(Vector2 p) => at + R * p.x + U * p.y;
        float J(int i) => jit[(i & 0x7fffffff) & 63];
        static Vector2 Rot(Vector2 v, float a) { float c = Mathf.Cos(a), s = Mathf.Sin(a); return new Vector2(v.x * c - v.y * s, v.x * s + v.y * c); }

        float seedNow;
        /// Streaked strokes (shader flag seed >= 2): only the kinds trying the textured look.
        bool Streaky => kind == "clock";
        /// mode 0: cel bands (outer / band2 / band3 / core by edge distance); 1: flat colour c;
        /// 2: soft alpha disc; 3: additive glow. fade: alpha. side: -1 inner .. +1 outer edge.
        void V(Vector2 p, float e, float mode, Color c, float along = .5f, float fade = 1f, float side = 0f)
        {
            vs.Add(W(p)); cs.Add(new Color(c.r, c.g, c.b, fade)); u0.Add(new Vector4(e, mode, along, Streaky ? seedNow + 2f : seedNow));
            // u2.w / u3.w: position in units of size, for the shader's painterly noise.
            u1.Add(new Vector4(core.r, core.g, core.b, side)); u2.Add(new Vector4(band2.r, band2.g, band2.b, p.x / size)); u3.Add(new Vector4(outer.r, outer.g, outer.b, p.y / size));
        }

        /// An arc of a circle, fat in the middle, needle-pointed, its width wobbling slowly
        /// with fbm; tipBias puts more width outside the curve.
        void Crescent(Vector2 c, float r, float a0, float a1, float thick, float fade, float tipBias, float phase)
        {
            const int N = 22;
            int i0 = vs.Count; seedNow = J(i0 + 3);
            for (int i = 0; i <= N; i++)
            {
                float u = (float)i / N; float a = Mathf.Lerp(a0, a1, u);
                float w = thick * Mathf.Pow(Mathf.Max(0f, Mathf.Sin(u * Mathf.PI)), .75f) * (1f + .18f * Fbm(u * 3f + phase, 4f));
                var n = new Vector2(Mathf.Cos(a), Mathf.Sin(a));
                var mid = c + n * (r + .03f * thick * Fbm(u * 5f - phase, 9f));
                V(mid + n * w * (1f + tipBias), 0f, 0f, band3, u, fade, 1f);
                V(mid, 1f, 0f, band3, u, fade, 0f);
                V(mid - n * w * (1f - tipBias), 0f, 0f, band3, u, fade, -1f);
                if (i > 0)
                {
                    int p = i0 + (i - 1) * 3, q = i0 + i * 3;
                    tris.Add(p); tris.Add(q); tris.Add(p + 1); tris.Add(q); tris.Add(q + 1); tris.Add(p + 1);
                    tris.Add(p + 1); tris.Add(q + 1); tris.Add(p + 2); tris.Add(q + 1); tris.Add(q + 2); tris.Add(p + 2);
                }
            }
        }

        /// A flame tongue: a teardrop along a wobbling spine (the reference's flame_path).
        void Flame(Vector2 b, Vector2 d, float len, float wid, float t, int seed, float wob, float fade, float curl = 0f, float mode = 0f, Color? tint = null)
        {
            var col = tint ?? band3;
            d = d.normalized; var nrm = new Vector2(-d.y, d.x);
            const int N = 12;
            int i0 = vs.Count; seedNow = J(seed);
            for (int i = 0; i < N; i++)
            {
                float u = i / (float)(N - 1);
                // curl bends the tip sideways like the reference's corona tongues.
                float off = Fbm(u * 2.5f - t * 4f + seed, seed) * wob * len * u + curl * len * u * u * .5f;
                var p = b + d * (len * u) + nrm * off;
                float w = wid * Mathf.Pow(1f - u, .85f) * (.55f + .45f * Mathf.Sin(Mathf.PI * Mathf.Min(1f, u * 2.2f + .25f)));
                // An additive wisp also dims toward its tip.
                float f = mode > 2.5f ? fade * (1f - .75f * u) : fade;
                V(p + nrm * w * .5f, 0f, mode, col, u, f, 1f); V(p, 1f, mode, col, u, f, 0f); V(p - nrm * w * .5f, 0f, mode, col, u, f, -1f);
                if (i > 0)
                {
                    int q0 = i0 + (i - 1) * 3, q1 = i0 + i * 3;
                    tris.Add(q0); tris.Add(q1); tris.Add(q0 + 1); tris.Add(q1); tris.Add(q1 + 1); tris.Add(q0 + 1);
                    tris.Add(q0 + 1); tris.Add(q1 + 1); tris.Add(q0 + 2); tris.Add(q1 + 1); tris.Add(q1 + 2); tris.Add(q0 + 2);
                }
            }
        }

        /// The reference's hit spark: 12 tapered radial spikes with white inner spikes, a
        /// sparkle, an expanding ring and a glow, over .22 s.
        void ImpactStar(Vector2 c, float sz, float t, int seed, bool ring = true)
        {
            const float Dur = .22f;
            float u = t / Dur; if (u < 0f || u > 1f) return;
            float a = 1f - u;
            for (int k = 0; k < 12; k++)
            {
                float ang = J(seed + k) * 6.283f;
                float L = sz * (.5f + .7f * J(seed + k + 12)) * EOut(u * 2.5f);
                float w = sz * (.04f + .05f * J(seed + k + 24)) * a;
                var d = new Vector2(Mathf.Cos(ang), Mathf.Sin(ang));
                float r0 = sz * .13f * u;
                Taper(c + d * r0, c + d * (r0 + L), w, 0f, hot, a);
                Taper(c + d * r0, c + d * (r0 + L * .6f), w * .45f, 0f, Color.white, a);
            }
            Sparkle(c, sz * .65f * (1f - u * .6f), hot, a, 15f);
            if (ring) ShockRing(c, sz * (.15f + .95f * EOut(u)), sz * .1f * a, core, a, J(seed + 40) * 10f);
            Glow(c, sz, band2, .4f * a);
        }

        /// A tapered additive sliver from p0 (width w0) to p1 (width w1).
        void Taper(Vector2 p0, Vector2 p1, float w0, float w1, Color col, float a, float mode = 3f)
        {
            var d = (p1 - p0).normalized; var n = new Vector2(-d.y, d.x);
            int i0 = vs.Count; seedNow = 0f;
            V(p0 + n * (w0 * .5f), 1f, mode, col, 0f, a); V(p1 + n * (w1 * .5f), 1f, mode, col, 1f, a); V(p1 - n * (w1 * .5f), 1f, mode, col, 1f, a); V(p0 - n * (w0 * .5f), 1f, mode, col, 0f, a);
            tris.Add(i0); tris.Add(i0 + 1); tris.Add(i0 + 2); tris.Add(i0); tris.Add(i0 + 2); tris.Add(i0 + 3);
        }

        /// The reference's anime sparkle: eight points (thin waist, shorter vertical), a white
        /// half-size copy, a glow. Additive.
        void Sparkle(Vector2 c, float size, Color col, float a, float rotDeg)
        {
            if (size < .001f || a <= .01f) return;
            for (int pass = 0; pass < 2; pass++)
            {
                float sc = pass == 0 ? 1f : .5f; var cc = pass == 0 ? col : Color.white;
                int i0 = vs.Count; seedNow = 0f; V(c, 1f, 3f, cc, .5f, a);
                for (int k = 0; k < 8; k++)
                {
                    float ang = (rotDeg + k * 45f) * Mathf.Deg2Rad;
                    float rr = k % 2 == 0 ? size : size * .11f;
                    if (k % 4 == 2) rr = size * .72f;
                    V(c + new Vector2(Mathf.Cos(ang), Mathf.Sin(ang)) * (rr * sc), .35f, 3f, cc, .5f, a);
                }
                for (int k = 0; k < 8; k++) { tris.Add(i0); tris.Add(i0 + 1 + k); tris.Add(i0 + 1 + (k + 1) % 8); }
            }
            Glow(c, size * .9f, col, a * .5f);
        }

        /// An open additive arc (never a closed ring: banned geometry) of radius r and width w,
        /// sweeping `sweepDeg` from `startDeg`, tapering to points at both ends.
        void Arc(Vector2 c, float r, float w, float startDeg, float sweepDeg, Color col, float a)
        {
            if (r <= 0f || w <= .0005f || a <= .003f) return;
            const int N = 32; int i0 = vs.Count; seedNow = 0f;
            for (int i = 0; i <= N; i++)
            {
                float uu = (float)i / N;
                float ang = (startDeg + sweepDeg * uu) * Mathf.Deg2Rad; var n = new Vector2(Mathf.Cos(ang), Mathf.Sin(ang));
                float ww = w * Mathf.Pow(Mathf.Max(0f, Mathf.Sin(uu * Mathf.PI)), .6f);
                V(c + n * (r + ww * .5f), .2f, 3f, col, uu, a); V(c + n * r, 1f, 3f, col, uu, a); V(c + n * (r - ww * .5f), .2f, 3f, col, uu, a);
                if (i > 0)
                {
                    int p = i0 + (i - 1) * 3, q = i0 + i * 3;
                    tris.Add(p); tris.Add(q); tris.Add(p + 1); tris.Add(q); tris.Add(q + 1); tris.Add(p + 1);
                    tris.Add(p + 1); tris.Add(q + 1); tris.Add(p + 2); tris.Add(q + 1); tris.Add(q + 2); tris.Add(p + 2);
                }
            }
        }

        /// One expanding shock ring, its width uneven round the circle (allowed as a passing
        /// accent since 2026-10-08: 一闪而过、扩散变淡、不当主体、不多层同心).
        void ShockRing(Vector2 c, float r, float w, Color col, float a, float phase)
        {
            if (r <= 0f || w <= .0005f || a <= .003f) return;
            const int N = 48; int i0 = vs.Count; seedNow = 0f;
            for (int i = 0; i <= N; i++)
            {
                float uu = (float)i / N, ang = uu * Mathf.PI * 2f; var n = new Vector2(Mathf.Cos(ang), Mathf.Sin(ang));
                float ww = w * (.55f + .45f * (Fbm(uu * 6f + phase, 21f) * .5f + .5f) * 2f);
                V(c + n * (r + ww * .5f), .15f, 3f, col, uu, a); V(c + n * r, 1f, 3f, col, uu, a); V(c + n * (r - ww * .5f), .15f, 3f, col, uu, a);
                if (i > 0)
                {
                    int p = i0 + (i - 1) * 3, q = i0 + i * 3;
                    tris.Add(p); tris.Add(q); tris.Add(p + 1); tris.Add(q); tris.Add(q + 1); tris.Add(p + 1);
                    tris.Add(p + 1); tris.Add(q + 1); tris.Add(p + 2); tris.Add(q + 1); tris.Add(q + 2); tris.Add(p + 2);
                }
            }
        }

        /// A cel-banded disc (mode 0) or additive/soft disc; slightly uneven (blob_path).
        void Dot(Vector2 c, float r, Color col, float mode, float fade, float phase = 0f, float amp = .12f, float sx = 1f, float sy = 1f)
        {
            int i0 = vs.Count; seedNow = J(i0 + 11); V(c + new Vector2(-.25f * sx, .22f * sy) * r, 1f, mode, col, .5f, fade);
            const int N = 40;
            for (int i = 0; i < N; i++)
            {
                float ang = i * Mathf.PI * 2f / N;
                float rr = r * (1f + amp * Fbm(Mathf.Cos(ang) * 3f + phase * 2f, 2f) + amp * .6f * VNoise(Mathf.Sin(ang) * 5.1f - phase * 3f, 5f));
                V(c + new Vector2(Mathf.Cos(ang) * sx, Mathf.Sin(ang) * sy) * rr, 0f, mode, col, .5f, fade, Mathf.Cos(ang - 2.3f));
            }
            for (int i = 0; i < N; i++) { tris.Add(i0); tris.Add(i0 + 1 + i); tris.Add(i0 + 1 + (i + 1) % N); }
        }

        /// A soft additive glow: full at the centre, .32 at 30 %, zero at the rim.
        void Glow(Vector2 c, float r, Color col, float strength)
        {
            if (r <= .001f || strength <= .002f) return;
            const int N = 20; int i0 = vs.Count; seedNow = 0f;
            V(c, 1f, 3f, col, .5f, strength);
            for (int i = 0; i < N; i++) { float a = i * Mathf.PI * 2f / N; V(c + new Vector2(Mathf.Cos(a), Mathf.Sin(a)) * (r * .3f), .32f, 3f, col, .5f, strength); }
            for (int i = 0; i < N; i++) { float a = i * Mathf.PI * 2f / N; V(c + new Vector2(Mathf.Cos(a), Mathf.Sin(a)) * r, 0f, 3f, col, .5f, strength); }
            for (int i = 0; i < N; i++)
            {
                int a = i0 + 1 + i, b = i0 + 1 + (i + 1) % N, a2 = a + N, b2 = b + N;
                tris.Add(i0); tris.Add(a); tris.Add(b);
                tris.Add(a); tris.Add(a2); tris.Add(b2); tris.Add(a); tris.Add(b2); tris.Add(b);
            }
        }

        /// Deterministic spark streaks: thrown from c, falling, fading, additive.
        void Sparks(Vector2 c, float t, int n, int seed, float speed, Vector2 bias, float fade)
        {
            for (int i = 0; i < n; i++)
            {
                float ang = J(seed + i) * 6.283f; float sp = speed * (.4f + .6f * J(seed + i + 1)); float life = .3f + .35f * J(seed + i + 2);
                float age = t - .02f * J(seed + i + 3); if (age < 0f || age > life) continue;
                float uu = age / life, e = Mathf.Exp(-2.5f * age), disp = (1f - e) / 2.5f;
                var v = (new Vector2(Mathf.Cos(ang), Mathf.Sin(ang)) + bias * .6f) * sp;
                var p = c + v * disp + Vector2.down * (1.6f * size * age * age);
                var vel = v * e + Vector2.down * (3.2f * size * age);
                float a = Mathf.Pow(1f - uu, .7f) * fade, w = size * (.018f + .014f * J(seed + i + 4)) * (1f - uu * .6f);
                Taper(p - vel * .03f, p, w, w, Color.Lerp(core, band2, uu), a);
            }
        }

        /// Shard particles (StormBurst): small kites flying out, cel-coloured.
        void Shards(Vector2 c, float t, int n, int seed, float speed, float fade)
        {
            for (int i = 0; i < n; i++)
            {
                float ang = J(seed + i) * 6.283f; float sp = speed * (.3f + .7f * J(seed + i + 1)); float life = .3f + .3f * J(seed + i + 2);
                if (t < 0f || t > life) continue;
                float uu = t / life, e = Mathf.Exp(-2.5f * t), disp = (1f - e) / 2.5f;
                var v = new Vector2(Mathf.Cos(ang), Mathf.Sin(ang)) * sp;
                var p = c + v * disp + Vector2.down * (1.2f * size * t * t);
                var d = (v * e + Vector2.down * (2.4f * size * t)).normalized; var nn = new Vector2(-d.y, d.x);
                float sz = size * (.03f + .04f * J(seed + i + 3)) * (1f - uu * .6f);
                var col = Color.Lerp(core, band2, uu); float a = Mathf.Pow(1f - uu, .7f) * fade;
                int i0 = vs.Count; seedNow = 0f;
                V(p + d * sz * 3f, 1f, 1f, col, .5f, a); V(p + nn * sz * 1.1f, 1f, 1f, col, .5f, a); V(p - d * sz * 2f, 1f, 1f, col, .5f, a); V(p - nn * sz * .6f, 1f, 1f, col, .5f, a);
                tris.Add(i0); tris.Add(i0 + 1); tris.Add(i0 + 2); tris.Add(i0); tris.Add(i0 + 2); tris.Add(i0 + 3);
            }
        }

        void OnDestroy()
        {
            if (owner) owner.live--;
            if (mesh) Destroy(mesh);
        }
    }

    sealed class EffekseerBurst : MonoBehaviour
    {
        SpellSpectacle20260926 owner;
        (string fx, float at, float fadeFrom, float end, float size)[] layers;
        Effekseer.EffekseerEffectAsset[] assets;
        Effekseer.EffekseerHandle[] handles;
        bool[] started;
        Vector3 at;
        float half, delay, age;

        public static void Create(Transform parent, SpellSpectacle20260926 owner, Vector3 at, float half, float delay,
            (string fx, float at, float fadeFrom, float end, float size)[] layers, Effekseer.EffekseerEffectAsset[] assets)
        {
            var go = new GameObject("SpectacleEffekseer");
            go.transform.SetParent(parent, false);
            var b = go.AddComponent<EffekseerBurst>();
            b.owner = owner; b.at = at; b.half = half; b.delay = delay; b.layers = layers; b.assets = assets;
            b.handles = new Effekseer.EffekseerHandle[layers.Length];
            b.started = new bool[layers.Length];
            owner.live++;
        }

        void Update()
        {
            age += Time.deltaTime;
            float t = age - delay;
            if (t > 0f) t *= HitPace;
            bool any = false;
            for (int i = 0; i < layers.Length; i++)
            {
                var L = layers[i];
                float lt = t - L.at;
                if (lt < 0f) { any = true; continue; }
                if (!started[i])
                {
                    started[i] = true;
                    var p = Effekseer.EffekseerPlayEffectParameters.Create(at);
                    p.SetScale(Vector3.one * half * L.size * (ReducedMotion ? .85f : 1f));
                    handles[i] = Effekseer.EffekseerSystem.PlayEffect(assets[i], p);
                    if (handles[i].exists) handles[i].speed = HitPace;
                }
                if (lt >= L.end) { if (handles[i].exists) handles[i].Stop(); continue; }
                any = true;
                if (handles[i].exists)
                {
                    float fade = 1f - Mathf.Clamp01((lt - L.fadeFrom) / Mathf.Max(.01f, L.end - L.fadeFrom));
                    handles[i].SetAllColor(new Color(1f, 1f, 1f, fade));
                }
            }
            if (!any) Destroy(gameObject);
        }

        void OnDestroy()
        {
            if (handles != null)
                foreach (var h in handles) if (h.exists) h.Stop();
            if (owner) owner.live--;
        }
    }

    sealed class FlipbookPlayer : MonoBehaviour
    {
        static Mesh quad;
        SpellSpectacle20260926 owner;
        MeshRenderer view;
        MaterialPropertyBlock block;
        Vector3 at;
        float size, roll, delay, age;
        float[] hold;
        bool mirror;

        public static FlipbookPlayer Create(Transform parent, Material material, SpellSpectacle20260926 owner, Vector3 at, float size, float roll, bool mirror, float delay, float[] hold)
        {
            if (!quad)
            {
                quad = new Mesh { name = "FlipbookQuad" };
                quad.vertices = new[] { new Vector3(-.5f, -.5f, 0), new Vector3(.5f, -.5f, 0), new Vector3(.5f, .5f, 0), new Vector3(-.5f, .5f, 0) };
                quad.uv = new[] { new Vector2(0, 0), new Vector2(1, 0), new Vector2(1, 1), new Vector2(0, 1) };
                quad.triangles = new[] { 0, 2, 1, 0, 3, 2 };
                quad.RecalculateBounds();
            }
            var go = new GameObject("SpectacleFlipbook");
            go.transform.SetParent(parent, false);
            go.AddComponent<MeshFilter>().sharedMesh = quad;
            var p = go.AddComponent<FlipbookPlayer>();
            p.view = go.AddComponent<MeshRenderer>();
            p.view.sharedMaterial = material;
            p.view.shadowCastingMode = UnityEngine.Rendering.ShadowCastingMode.Off;
            p.view.receiveShadows = false;
            p.view.enabled = false;
            p.block = new MaterialPropertyBlock();
            p.owner = owner; p.at = at; p.size = size; p.roll = roll; p.mirror = mirror; p.delay = delay; p.hold = hold;
            owner.live++;
            p.Place();
            return p;
        }

        void Place()
        {
            var cam = Camera.main;
            if (cam) transform.rotation = Quaternion.LookRotation(cam.transform.forward, cam.transform.up) * Quaternion.Euler(0, 0, roll);
            transform.position = at;
            transform.localScale = Vector3.one * size;
        }

        void LateUpdate()
        {
            age += Time.deltaTime;
            float t = age - delay;
            if (t > 0f) t *= HitPace;
            int frame = 0;
            float end = 0f;
            for (; frame < hold.Length; frame++)
            {
                end += hold[frame];
                if (t < end) break;
            }
            if (frame >= hold.Length) { Destroy(gameObject); return; }
            view.enabled = t >= 0f;
            Place();
            block.SetFloat("_Frame", frame);
            block.SetFloat("_Flip", mirror ? 1f : 0f);
            view.SetPropertyBlock(block);
        }

        void OnDestroy()
        {
            if (owner) owner.live--;
        }
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
        // The ordered loop's cards have no aura: in their pale gold and ice it read as a white
        // haze over the hero (probe9).
        if (!IsOrderedCard(p.id)) Flares.Create(root, flareUnderMaterial, this).Aura(p, feet + up * .55f * h, floor, right, h, release, basic, rng);
        Flares.Create(root, flareMaterial, this).CastSparkle(p, feet, chest, hand, right, up, toCam, h, release, basic, rng);
        if (basic) return;
        // A solid card keeps only the glow and the motes: its rising rays and floor arcs were
        // more lines round the hero (2026-10-07, user: 你很多这些一条条的).
        // The ordered loop's cards too: in gold the four rays read as bars aimed at the enemy (2026-10-14).
        if (Solid(p.form) || IsOrderedCard(p.id)) return;
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
            bool solid = Solid(p.form);
            Props props = null;
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
                if (solid)
                {
                    // Objects and smoke on the course, no band (SolidShot); sparks, stream,
                    // glints and footprints below are kept.
                    if (!props) props = Props.Create(root, propMaterial, this);
                    SolidShot(p, shot, at, frame, props, trail, rng, n);
                    if (shot.star && shot.headSize > 0 && p.form == Form.Throw) heads.ProjectileStar(shot.from, shot.vel, shot.gravity, at, shot.time, shot.headSize * 1.6f, Color.Lerp(p.hot, p.line, .4f), rng);
                }
                var path = shot.path;
                path.rigid = true;
                path.revealScale = shot.time / BaseReveal(cue.style);
                path.solidStart = true;
                if (path.revealEase <= 0) path.revealEase = 1f;
                if (Diagnostics) Debug.Log($"SPELLFORM shot {p.id} at={at:F3} time={shot.time:F3} from={shot.from:F2} end={path.points[path.points.Length - 1]:F2}");
                if (!solid)
                {
                    var body = Body.Create(root, behind ? sweepUnderMaterial : sweepMaterial, this);
                    body.Setup(path, path.pivot ?? frame.target, ramp, p, cue.style, at, (float)rng.NextDouble() * 10f, 20 + cue.launch.Count);
                    // A chained leg runs after the contact; hastening it would cut the whole chain at once.
                    if (!shot.chained) cue.launch.Add(body);
                }
                foreach (var strand in solid ? new List<Path>() : shot.strands)
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
                if (!solid && shot.star && shot.headSize > 0) heads.ProjectileStar(shot.from, shot.vel, shot.gravity, at, shot.time, shot.headSize * 2.2f, Color.Lerp(p.hot, p.line, .4f), rng);
                if (!solid && shot.headSize > 0) heads.Projectile(shot.from, shot.vel, shot.gravity, at, shot.time, shot.headSize, shot.head, headColor, shot.stretch, shot.spin);
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
                var bow = -f.right * .12f + Vector3.up * .08f;
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
            case Form.Edict:
            {
                // 假面谕令: a white mask glides straight from the hand to the target's face, a
                // cool streak widening behind it, a half-twisted pair of strands, glints and motes.
                var from = f.caster + f.right * .14f * s + f.up * .05f * s;
                var to = f.target + f.up * .25f * s;
                Func<float, Vector3> pos = u => Vector3.Lerp(from, to, u);
                var streak = Make(32, pos, FacingAcross(pos, f.toCam), u => s * (.04f + .1f * u), f.toCam);
                streak.pivot = to; streak.coreAmt = 2.4f; streak.tile = 2f; streak.holdScale = .3f; streak.rampShift = .3f; streak.look = Matter.Silk;
                var shot = new Shot { path = streak, from = from, vel = (to - from) / travel, gravity = 0f, time = travel, headSize = .3f * s, head = Mote.Card, stretch = 0f, spin = 90f,
                    course = pos, sparks = 12, spark = Mote.Shard, stream = 20, glow = .45f, twinkles = 4 };
                foreach (var strand in Strands(pos, .12f * s, .03f * s, .45f, 32)) { strand.pivot = to; strand.coreAmt = 2f; strand.look = Matter.Silk; shot.strands.Add(strand); }
                list.Add(shot);
                break;
            }
            case Form.Swap:
            {
                // 张冠李戴: two cards leave from either side of the hero and cross mid-corridor,
                // each landing on the other side of the target: the swap.
                for (int k = 0; k < 2; k++)
                {
                    float side = k == 0 ? -1f : 1f, time = travel * (k == 0 ? 1f : .94f);
                    var from = f.caster + lateral * side * .35f * s + f.up * R(rng, -.02f, .08f) * s;
                    var to = f.target - lateral * side * .3f * s + f.up * (k == 0 ? .35f : -.05f) * s;
                    Func<float, Vector3> pos = u => Vector3.Lerp(from, to, u);
                    var streak = Make(28, pos, FacingAcross(pos, f.toCam), u => s * (.04f + .06f * u), f.toCam);
                    streak.pivot = to; streak.coreAmt = 2.2f; streak.tile = 2f; streak.holdScale = .3f; streak.rampShift = k == 0 ? .1f : .45f; streak.look = Matter.Silk;
                    list.Add(new Shot { path = streak, from = from, vel = (to - from) / time, gravity = 0f, time = time, delay = k * .04f, headSize = .24f * s, head = Mote.Card, stretch = 0f,
                        spin = side * 540f, course = pos, sparks = 10, spark = Mote.Card, stream = 12, glow = .35f, twinkles = 2 });
                }
                break;
            }
            case Form.Reverse:
            {
                // 反客为主: a streak shoots past the target to a point behind it; the strike then
                // comes back from behind (ImpactPaths).
                var from = f.caster + f.right * .1f * s;
                var to = f.target + f.dir * 1.1f * s + f.up * .55f * s;
                float time = travel * .9f;
                Func<float, Vector3> pos = u => Vector3.Lerp(from, to, u);
                var streak = Make(32, pos, FacingAcross(pos, f.toCam), u => s * (.03f + .07f * u), f.toCam);
                streak.pivot = to; streak.coreAmt = 2.4f; streak.tile = 2f; streak.holdScale = .25f; streak.rampShift = .25f; streak.look = Matter.Silk;
                list.Add(new Shot { path = streak, from = from, time = time, at = Mathf.Max(0f, contact - .1f - time), headSize = 0f, star = false, course = pos,
                    sparks = 10, spark = Mote.Petal, stream = 18, glow = .45f, twinkles = 3 });
                break;
            }
            case Form.Rewrite:
                // A self card: its light is on the hero (cast light, and the landing on the hero).
                break;
            case Form.Proclaim:
            {
                // 无名宣告: a golden decree card rises straight from the hero to above the target;
                // the beam then comes straight down onto it (ImpactPaths).
                var from = f.caster + f.up * .1f * s;
                var to = f.target + f.up * 2.6f * s - f.dir * .3f * s;
                Func<float, Vector3> pos = u => Vector3.Lerp(from, to, u);
                var streak = Make(32, pos, FacingAcross(pos, f.toCam), u => s * (.05f + .08f * u), f.toCam);
                streak.pivot = to; streak.coreAmt = 2.4f; streak.tile = 2f; streak.holdScale = .35f; streak.rampShift = .3f; streak.look = Matter.Silk;
                var shot = new Shot { path = streak, from = from, vel = (to - from) / travel, gravity = 0f, time = travel, headSize = .42f * s, head = Mote.Card, stretch = 0f, spin = 240f,
                    course = pos, sparks = 16, spark = Mote.Card, stream = 24, glow = .6f, twinkles = 5 };
                foreach (var strand in Strands(pos, .14f * s, .035f * s, .45f, 32)) { strand.pivot = to; strand.coreAmt = 2f; strand.look = Matter.Silk; shot.strands.Add(strand); }
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
            // A self card lands on the hero: its frame looks into the screen from the camera side.
            var from = p.form == Form.Rewrite ? points[i] - cam.transform.forward : caster;
            float sizeK = p.form == Form.Flick ? .55f : p.form == Form.Rewrite ? .5f : .8f;
            var frame = new Frame(cam, from, points[i], half / 4.5f * p.scale * sizeK, rng);
            float halfWidth = half * cam.aspect;
            // 荒谬归结 is the named finisher: on its main target the landing is a stage
            // spanning most of the screen (FinaleStage) instead of the usual rainbow arc.
            bool stage = p.form == Form.Rain && i == 0;
            // A dash cuts its targets one after another; other forms land together.
            float delay = i * (p.form == Form.Dash ? DashChainStep : .035f);
            if (Diagnostics) Debug.Log($"SPELLFORM impact {p.id} t={Time.unscaledTime:F3} at={points[i]:F2} s={frame.s:F2}");
            // A real-time Effekseer landing replaces the built landing, shards and burst.
            if (InkHit(cue, caster, points[i], half, delay, cam, i) || CardHit(cue, caster, points[i], half, delay, cam, i) || EffekseerHit(cue, cue.style, caster, points[i], frame.s, delay, cam)) continue;
            // One layer of the identity's own form keeps the old layered brilliance around
            // the main target. A thrown seal has none: its family falls from over the top.
            // A basic has none either: on the phone that wave read as one solid lump landing
            // on the enemy (2026-10-03); its contact bursts open instead (below).
            // Bystanders of a group card get only the landing itself.
            // The dash's crossed cut is kept small so the afterimage, not the blades, carries it.
            var familyFrame = p.form == Form.Dash ? new Frame(cam, from, points[i], frame.s * .75f, rng) : frame;
            bool solid = Solid(p.form);
            float archA = 0f, archB = 0f;
            var family = Formless(p.form) || i > 0 || stage || solid ? new List<Path>() : Paths(p.family, familyFrame, 1, rng);
            if (stage)
            {
                foreach (var part in FinaleStage(frame, half, rng, out archA, out archB))
                    // Calm and barely stretched: pushed like a normal body by its own extent the
                    // screen-wide arch would be flung across the whole screen as it fades.
                    Body.Create(root, sweepMaterial, this).Setup(Dispersing(part, frame.s, 1.2f, .25f, .06f, true), part.pivot ?? frame.target, ramp, p, cue.style, delay + part.delay, (float)rng.NextDouble() * 10f, 20);
                if (Diagnostics) Debug.Log($"SPELLFORM stage {p.id} t={Time.unscaledTime:F3} half={half:F2} aspect={cam.aspect:F2}");
            }
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
            var accents = solid ? new List<Path>() : AccentPaths(p.accent, frame, cue.style, rng);
            for (int k = 0; k < accents.Count; k++)
            {
                var body = Body.Create(root, sweepMaterial, this);
                body.Setup(Dispersing(accents[k], frame.s), accents[k].pivot ?? frame.target, ramp, p, cue.style, delay + accents[k].delay, (float)rng.NextDouble() * 10f, 10 + k);
            }
            foreach (var path in solid ? new List<Path>() : ImpactPaths(p.form, frame, rng, stage))
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
            // In the tower a group card's three bursts at .7/.45 still spanned the screen (169.49).
            float reach = halfWidth * (p.form == Form.Flick ? .5f : p.form == Form.Rain ? .55f : p.form is Form.Edict or Form.Swap ? .5f : .62f) * (points.Count > 1 ? (i == 0 ? .6f : .4f) : 1f);
            // A self card does not burst on the hero: its rays and stroke are the landing.
            if (p.form == Form.Rewrite) continue;
            if (solid) SolidImpact(p, frame, reach, delay, i == 0, stage, archA, archB, rng);
            foreach (var spike in solid ? new List<Path>() : BurstSpikes(p, frame, reach, i == 0, rng))
                // Thin spikes drift out calmly: pulled like the bodies they curled into tentacles (169.67).
                Body.Create(root, sweepMaterial, this).Setup(Dispersing(spike, frame.s, 1f, .55f, .02f, true), spike.pivot ?? frame.target, ramp, p, cue.style, delay + spike.delay, (float)rng.NextDouble() * 10f, 50);
            Flares.Create(root, flareMaterial, this).Explode(p, frame, reach, delay, i == 0, rng, solid);
        }
    }

    // ------------------------------------------------------------ solid spells (all identities)

    /// Every identity is drawn with objects, smoke and light instead of bands (2026-10-07
    /// night, user: 你很多这些一条条的 ... 做完所有98组). The five things that set an identity
    /// apart are kept: the family now decides how its matter moves (falls, rises, sweeps,
    /// fans, crosses, arcs over, drifts down, rolls along the floor), the matter decides what
    /// the objects are, the accent adds the named move as an object, and style and colours
    /// stay. The old band builders (Paths, AccentPaths, Column) are kept but no longer called.
    const bool SolidAll = true;
    /// While this layer draws spells as objects, the older scripts' ribbons are hidden
    /// (StraightLines20261003). The recorder's --spectacle-off baseline shows them again.
    public static bool HidesLegacyBands => SolidAll && !Suppressed;

    /// The older enemy spell scripts that draw their own bodies (ribbons, sheets, tubes,
    /// slabs). While this layer draws the spell as objects their renderers are switched off
    /// for a few seconds after each enemy cast; their timing, contacts, sounds and the
    /// enemies' own gestures keep running. Persistent states (ambient tells, bindings, the
    /// archive's armour) are left alone.
    static readonly Type[] LegacySpellTypes =
    {
        typeof(ChurchSpellVisual20260917), typeof(ChurchFinalVfx20260917), typeof(ChurchSpellFragments20260917),
        typeof(IronclawSpell20260918), typeof(BoneclawDistinctVfx20260920), typeof(ChurchMinionVfx20260921),
        typeof(TowerSaltVfxRound2), typeof(SaltmawSpell20260919), typeof(TowerSupportRound2),
        typeof(BountySpellRound2), typeof(BountyForgedSpell20260921), typeof(BountySurfaceRound2),
        typeof(ArchivistMechanicalSpell), typeof(EmeraldRevenantSpell), typeof(MainlineSilkRound2),
        typeof(AuthoredNeedleImpact20260925), typeof(MainlineSpellMeshRound2), typeof(MainlineLeechGlobRound2),
        // The leech's green contact rupture and devour strands (2026-10-09, under the new drain).
        typeof(EnemyAuthoredBurstTier20260919), typeof(MainlineDistinct20260925),
    };
    float hideLegacyUntil = -1f, nextLegacyScan;
    // Each root with its renderers, gathered at the scan, not every frame (2026-10-17, iPhone 13: 好卡).
    readonly List<(GameObject go, Renderer[] renderers)> legacyRoots = new List<(GameObject, Renderer[])>();
    readonly List<GameObject> sceneRoots = new List<GameObject>();

    // Late (DefaultExecutionOrder on the class): some of those scripts switch their own
    // renderers on every frame, so they are switched off again every frame.
    void LateUpdate()
    {
        // The spell-layer bloom follows whichever camera is the main one.
        if (root && live > 0) SpellBloom20261008.Ensure(Camera.main, root);
        if (!HidesLegacyBands || Time.unscaledTime > hideLegacyUntil) { legacyRoots.Clear(); return; }
        if (Time.unscaledTime >= nextLegacyScan)
        {
            nextLegacyScan = Time.unscaledTime + .1f;
            legacyRoots.Clear();
            foreach (var type in LegacySpellTypes)
                foreach (var o in FindObjectsByType(type, FindObjectsSortMode.None))
                    if (o is Component c && c && IsLegacySpell(c.gameObject)) legacyRoots.Add((c.gameObject, c.gameObject.GetComponentsInChildren<Renderer>()));
            // The signature enemies' own effect roots (EnemySignatureSpellVFX) sit at the top of
            // the scene: look at the scene roots only, not at every transform in it.
            for (int i = 0; i < UnityEngine.SceneManagement.SceneManager.sceneCount; i++)
            {
                var scene = UnityEngine.SceneManagement.SceneManager.GetSceneAt(i);
                if (!scene.isLoaded) continue;
                scene.GetRootGameObjects(sceneRoots);
                foreach (var go in sceneRoots)
                    if (go && go.name.StartsWith("Enemy signature", StringComparison.Ordinal) && IsLegacySpell(go))
                        legacyRoots.Add((go, go.GetComponentsInChildren<Renderer>()));
            }
        }
        foreach (var item in legacyRoots)
        {
            if (!item.go) continue;
            foreach (var r in item.renderers)
                if (r && r.enabled && !(r is SkinnedMeshRenderer)) r.enabled = false;
        }
    }

    static bool IsLegacySpell(GameObject go)
    {
        // Never a body or the battle itself; never a persistent state.
        if (go.GetComponent<BattlePrototype>() || go.GetComponent<EnemyHandle>() || go.GetComponentInChildren<SkinnedMeshRenderer>(true)) return false;
        if (go.GetComponentInParent<ArchiveEncounterPresentation>() || go.GetComponentInChildren<OvalLightShield>(true)) return false;
        var church = go.GetComponent<ChurchSpellVisual20260917>();
        return !(church && church.ambient);
    }

    static Color RampAt(Profile p, float t)
    {
        t = Mathf.Clamp01(t) * (p.ramp.Length - 1);
        int a = Mathf.Min((int)t, p.ramp.Length - 2);
        return Color.Lerp(p.ramp[a], p.ramp[a + 1], t - a);
    }

    static Color Tint(Profile p, System.Random rng, float lo, float hi, float lift = .25f)
    {
        var c = Color.Lerp(RampAt(p, R(rng, lo, hi)), Color.white, lift); c.a = 1f; return c;
    }

    /// Screen-plane roll (degrees) that turns a cell's top toward 'dir' as seen by the camera.
    static float RollToward(Frame f, Vector3 dir)
    {
        float y = Vector3.Dot(dir, Camera.main ? Camera.main.transform.up : Vector3.up);
        float x = Vector3.Dot(dir, Camera.main ? Camera.main.transform.right : f.right);
        return Mathf.Atan2(y, x) * Mathf.Rad2Deg - 90f;
    }

    static PropCell MatterCell(Matter m, int i) => m switch
    {
        Matter.Crystal => i % 2 == 0 ? PropCell.CrystalA : PropCell.CrystalB,
        Matter.Water => i % 3 == 2 ? PropCell.Bubble : PropCell.WaterDrop,
        Matter.Ink => PropCell.InkDrop,
        Matter.Filigree => PropCell.Coin,
        Matter.Silk => i % 2 == 0 ? PropCell.Petal : PropCell.Feather,
        Matter.Electric => i % 2 == 0 ? PropCell.BoltA : PropCell.BoltB,
        _ => PropCell.CrystalA,
    };

    static float MatterSize(Matter m) => m switch
    {
        Matter.Crystal => .75f, Matter.Water => .45f, Matter.Ink => .45f, Matter.Filigree => .55f,
        Matter.Silk => .75f, Matter.Electric => 1.1f, _ => .65f,
    };

    /// A painted smoke cloud (the user's art) facing the camera: swells and thins as it drifts.
    /// variant 0 round, 1 thrown out to both sides, 2 rising column; tint colours it (light
    /// grey art, so a dark tint makes shadow and a bright one glowing mist).
    static Props.Item SmokeSheet(Vector3 at, Vector3 vel, float size, Color tint, float when, float life, int variant, System.Random rng)
    {
        var cell = variant == 1 ? (rng.NextDouble() < .5 ? PropCell.PSmokeB2 : PropCell.PSmokeB)
                 : variant == 2 ? (rng.NextDouble() < .5 ? PropCell.PSmokeC2 : PropCell.PSmokeC) : PropCell.PSmokeA;
        var it = Props.New(cell, cell, at, size, when, life);
        it.vel = vel; it.drag = 2.2f; it.faceCam = true;
        it.rollStart = variant == 0 ? R(rng, 0f, 360f) : R(rng, -12f, 12f); it.spin = variant == 0 ? R(rng, -25f, 25f) : 0f;
        it.grow = .55f; it.growTime = .18f; it.endScale = 1.3f; it.peak = .08f; it.fadeFrom = .45f; it.tint = tint;
        return it;
    }

    /// The user's painted fire, rising (roll 0) or thrown out along a direction (a burst).
    static Props.Item FireSheet(Vector3 at, Vector3 vel, float size, float roll, float when, float life)
    {
        var it = Props.New(PropCell.PFire, PropCell.PFire, at, size, when, life);
        it.vel = vel; it.drag = 2.6f; it.gravity = 0f; it.faceCam = true; it.rollStart = roll;
        it.grow = .35f; it.growTime = .1f; it.endScale = 1.25f; it.peak = .04f; it.fadeFrom = .4f; it.glow = .3f; it.glowDecay = .15f;
        return it;
    }

    /// A burst of painted fire: flames thrown out round a hot centre at uneven angles.
    static void FireBurst(Props props, Vector3 at, float s, float when, int flames, System.Random rng)
    {
        float a0 = R(rng, 0f, 360f);
        var cam = Camera.main;
        Vector3 camR = cam ? cam.transform.right : Vector3.right, camU = cam ? cam.transform.up : Vector3.up;
        // Flames always rise (turned past about 30 degrees they read as fire icons): they are
        // thrown out sideways round the hit and lean away from it.
        for (int k = 0; k < flames; k++)
        {
            float x = Mathf.Lerp(-1f, 1f, (k + R(rng, .2f, .8f)) / flames);
            var at2 = at + camR * x * .9f * s + camU * R(rng, -.35f, .25f) * s;
            props.Add(FireSheet(at2, (camR * x * 1.6f + camU * R(rng, .4f, 1f)) * s, R(rng, .75f, 1.05f) * s, -x * 22f + R(rng, -6f, 6f), when + R(rng, 0f, .04f), R(rng, .45f, .6f)));
        }
        props.Add(FireSheet(at, Vector3.up * .5f * s, 1.25f * s, R(rng, -8f, 8f), when, .55f));
    }

    void SolidEnemy(Cue cue, Style style, Vector3 caster, Vector3 target, float s, System.Random rng, float delay, Camera cam)
    {
        var p = cue.profile;
        var f = new Frame(cam, caster, target, s, rng);
        var props = Props.Create(root, propMaterial, this);
        var flares = Flares.Create(root, flareMaterial, this);
        var family = cue.cast % 2 == 1 ? p.familyAlt : p.family;
        bool support = style == Style.Support;
        if (support) family = Family.Rising;
        int count = style switch { Style.Heavy => 14, Style.Strike => 11, Style.Light => 7, Style.Support => 10, _ => 8 };
        // A named move is the subject: its matter is a lighter accompaniment.
        bool named = NamedMove(p.accent) || p.accent == Accent.Dragon || p.accent == Accent.Lotus;
        if (named) count = Mathf.Max(4, count / 2);
        if (ReducedMotion) count = Mathf.Max(3, count * 2 / 3);
        if (Diagnostics) Debug.Log($"SPELLFORM solid {p.id} family={family} matter={p.matter} accent={p.accent} style={style} n={count}");
        MatterMotion(p, style, f, family, count, delay, props, flares, rng);
        if (!support) MatterImpact(p, style, f, delay, props, flares, rng, named);
        AccentSolid(p, style, f, delay, props, flares, rng);
    }

    /// The identity's matter, moving as its family moves.
    void MatterMotion(Profile p, Style style, Frame f, Family family, int count, float delay, Props props, Flares flares, System.Random rng)
    {
        float s = f.s;
        var T = f.target; var U = Vector3.up; var Rt = f.right; var C = f.toCam; var D = f.Depth;
        var foot = f.Foot; float floor = foot.y + .01f;
        float sd = f.side;
        bool support = style == Style.Support;
        bool puffs = p.matter == Matter.Smoke || p.matter == Matter.Flame;
        float pace = support ? .45f : 1f;
        for (int i = 0; i < count; i++)
        {
            float when = delay + (support ? R(rng, 0f, .35f) : R(rng, 0f, .08f)) + i * (support ? .02f : .006f);
            Vector3 pos, vel; float gravity = 0f, drag = 1.2f, sway = 0f;
            Func<float, Vector3> course = null; float travel = 0f;
            switch (family)
            {
                case Family.Falling:
                    pos = T + U * R(rng, 2.2f, 3.4f) * s + Rt * R(rng, -1.3f, 1.3f) * s + C * R(rng, -.2f, .4f) * s;
                    vel = ((T + Rt * R(rng, -.6f, .6f) * s) - pos).normalized * R(rng, 7f, 10f) * s; gravity = 4f * s; drag = .4f; break;
                case Family.Rising:
                {
                    float a = R(rng, 0f, 6.283f);
                    var outward = Mathf.Cos(a) * Rt + Mathf.Sin(a) * D;
                    pos = foot + outward * R(rng, .3f, 1.2f) * s + U * R(rng, 0f, .5f) * s + C * .2f * s;
                    vel = U * R(rng, 3f, 6f) * s * pace + outward * R(rng, .4f, 1.4f) * s * pace; gravity = -.8f * s; drag = 1.6f; break;
                }
                case Family.Surge:
                    pos = T - Rt * sd * R(rng, 2f, 2.9f) * s + U * R(rng, -.7f, 1.1f) * s + C * R(rng, .1f, .5f) * s;
                    vel = Rt * sd * R(rng, 7f, 10f) * s + U * R(rng, -.8f, 1.2f) * s; drag = 1.3f; gravity = 1f * s; break;
                case Family.Fan:
                {
                    float a = Mathf.Lerp(18f, 162f, (i + R(rng, .1f, .9f)) / count) * Mathf.Deg2Rad;
                    var d = Mathf.Cos(a) * Rt + Mathf.Sin(a) * U;
                    pos = T + C * .35f * s + d * .3f * s;
                    vel = (d + C * R(rng, -.1f, .3f)) * R(rng, 5f, 8f) * s; drag = 3f; gravity = 2f * s; break;
                }
                case Family.Twin:
                {
                    var d = (i % 2 == 0 ? (Rt * sd + U * .8f) : (-Rt * sd + U * .9f)).normalized;
                    pos = T - d * R(rng, 2f, 2.6f) * s + C * .3f * s + Rt * R(rng, -.2f, .2f) * s;
                    vel = d * R(rng, 7f, 9.5f) * s; drag = 1.1f; gravity = 1f * s; break;
                }
                case Family.Crescent:
                {
                    var centre = T - U * .3f * s + C * .3f * s;
                    float radius = R(rng, 1.5f, 2.2f) * s;
                    float a0 = (sd > 0 ? 170f : 10f) * Mathf.Deg2Rad, a1 = (sd > 0 ? 10f : 170f) * Mathf.Deg2Rad;
                    float off = R(rng, -.25f, .25f);
                    course = u => { float a = Mathf.Lerp(a0, a1, Mathf.Clamp01(u + off * (1 - u))); return centre + (Mathf.Cos(a) * Rt + Mathf.Sin(a) * U) * radius; };
                    travel = R(rng, .28f, .4f);
                    pos = course(0f); vel = Vector3.zero; drag = 2f; gravity = 2f * s; break;
                }
                case Family.Curtain:
                    pos = T + U * R(rng, 1.4f, 2.5f) * s + Rt * R(rng, -1.7f, 1.7f) * s + C * R(rng, 0f, .4f) * s;
                    vel = Vector3.down * R(rng, .4f, 1.4f) * s; gravity = 3.2f * s; drag = 1.6f; sway = R(rng, .4f, .9f) * s; break;
                default: // Tide
                    pos = foot - Rt * sd * R(rng, 1.4f, 2.6f) * s + D * R(rng, -.6f, .6f) * s + U * .15f * s;
                    vel = Rt * sd * R(rng, 5f, 7.5f) * s + U * R(rng, 1f, 2.6f) * s; gravity = 8f * s; drag = .6f; break;
            }
            if (puffs)
            {
                // The user's painted smoke and fire (2026-10-07), every other one: a whole cloud per
                // piece reads better than many small puffs.
                var flow = course != null ? (course(.05f) - pos) / .05f / travel * .9f : vel * .8f;
                if (i % 3 == 0)
                {
                    float size = R(rng, .8f, 1.2f) * s * (support ? .8f : 1f);
                    if (p.matter == Matter.Flame)
                        props.Add(FireSheet(pos, flow * .6f + U * .6f * s, size, R(rng, -14f, 14f), when, R(rng, .5f, .7f)));
                    else
                    {
                        bool lit = i % 4 == 2;
                        var col = lit ? Tint(p, rng, .6f, 1f, .3f) : Color.Lerp(RampAt(p, R(rng, .3f, .6f)), Color.white, .25f);
                        props.Add(SmokeSheet(pos, flow * .6f, size, col, when, R(rng, .6f, .85f) * (support ? 1.3f : 1f), support ? 2 : 0, rng));
                    }
                }
                if (p.matter == Matter.Flame && i % 2 == 0)
                    flares.Mote1(pos, vel * .6f + Dir3(rng) * s, Mote.Ember, R(rng, .12f, .22f) * s, Tint(p, rng, .6f, 1f, .2f), R(rng, .4f, .7f), when, 1.5f, -.5f * s, rng);
                continue;
            }
            if (p.matter == Matter.Electric && i % 3 != 0)
            {
                // Mostly crackling sparks and glints; a nest of bolts read as scribbles.
                flares.Mote1(pos, vel * .7f, Mote.Spark, R(rng, .14f, .24f) * s, Tint(p, rng, .5f, 1f, .4f), R(rng, .3f, .5f), when, drag + 1f, 0f, rng, .9f);
                if (i % 3 == 1) flares.Glint(pos, s * .9f, when + .05f, Color.Lerp(p.hot, Color.white, .5f), i);
                continue;
            }
            var cell = MatterCell(p.matter, i);
            bool bolt = p.matter == Matter.Electric;
            var it = Props.New(cell, cell, pos, MatterSize(p.matter) * R(rng, .75f, 1.25f) * s * (support ? .8f : 1f), when, bolt ? R(rng, .16f, .26f) : R(rng, .6f, .95f) * (support ? 1.4f : 1f));
            it.vel = vel; it.gravity = gravity; it.drag = drag; it.sway = sway; it.course = course; it.travel = travel;
            it.floor = family == Family.Tide || family == Family.Falling || family == Family.Curtain ? floor : float.NaN;
            it.tint = cell == PropCell.Coin ? Color.white : Tint(p, rng, .35f, 1f, cell == PropCell.InkDrop ? .05f : .25f);
            it.sheen = R(rng, 0f, 1f); it.fadeFrom = .6f; it.grow = .5f; it.growTime = .08f;
            if (bolt)
            {
                // Bolts are light: held square to the camera, flickering on and off where they strike.
                it.faceCam = true; it.rollStart = R(rng, -40f, 40f) + (i % 2 == 0 ? 180f : 0f); it.vel = Vector3.zero; it.course = null; it.gravity = 0f;
                it.pos = T + Rt * R(rng, -1.4f, 1.4f) * s + U * R(rng, -.6f, 1.6f) * s + C * .4f * s;
                it.glow = .9f; it.glowDecay = 1f; it.peak = .01f; it.fadeFrom = .4f; it.growTime = 0f;
            }
            else
            {
                it.axis = Dir3(rng); it.spin = R(rng, 240f, 720f) * (i % 2 == 0 ? 1f : -1f); it.rot = AnyTurn(rng);
                it.glow = p.matter == Matter.Crystal || p.matter == Matter.Filigree ? .3f : 0f; it.glowDecay = .2f;
            }
            props.Add(it);
        }
    }

    /// The hit itself: the matter bursting on the recipient.
    void MatterImpact(Profile p, Style style, Frame f, float delay, Props props, Flares flares, System.Random rng, bool named)
    {
        float s = f.s;
        float k = (style == Style.Heavy ? 1.25f : style == Style.Light ? .75f : 1f) * (named ? .7f : 1f);
        var hit = f.target + f.toCam * .35f * s;
        float floor = f.Foot.y + .01f;
        int burst = Mathf.RoundToInt((named ? 7 : 12) * k);
        if (ReducedMotion) burst = Mathf.Max(3, burst * 2 / 3);
        void Sheet(PropCell cell, float size, Color tint)
        {
            var it = Props.New(cell, cell, hit - f.toCam * .05f * s, size * 1.3f * k * s, delay + .01f, .6f);
            it.faceCam = true; it.rollStart = R(rng, 0f, 360f); it.spin = R(rng, -20f, 20f); it.grow = .25f; it.growTime = .12f; it.fadeFrom = .35f; it.endScale = 1.15f; it.tint = tint;
            props.Add(it);
        }
        void Fling(PropCell cell, float size, float speed, bool lands)
        {
            for (int i = 0; i < burst; i++)
            {
                var d = (Dir3(rng) * .6f + f.toCam * .3f + Vector3.up * .5f).normalized;
                var it = Props.New(cell, cell, hit, size * 1.4f * R(rng, .7f, 1.2f) * s, delay + R(rng, 0f, .04f), R(rng, .6f, .9f));
                it.vel = d * speed * R(rng, .6f, 1.1f) * s; it.drag = 1.6f; it.gravity = 7f * s; it.floor = lands ? floor : float.NaN;
                it.axis = Dir3(rng); it.spin = R(rng, 400f, 900f); it.rot = AnyTurn(rng); it.fadeFrom = .55f;
                it.tint = cell == PropCell.Coin ? Color.white : Tint(p, rng, .4f, 1f, cell == PropCell.InkDrop ? .05f : .25f);
                it.glow = .35f; it.glowDecay = .12f; it.grow = .4f; it.growTime = .06f; it.sheen = R(rng, 0f, 1f);
                props.Add(it);
            }
        }
        switch (p.matter)
        {
            case Matter.Water:
                Sheet(PropCell.WaterSplash, 2.3f, Tint(p, rng, .5f, .9f, .35f));
                Fling(PropCell.WaterDrop, .26f, 5f, true);
                break;
            case Matter.Ink:
                Sheet(PropCell.InkSplat, 2.4f, Color.Lerp(RampAt(p, R(rng, .3f, .6f)), Color.white, .5f));
                Fling(PropCell.InkDrop, .28f, 5f, true);
                break;
            case Matter.Crystal:
                Fling(rng.NextDouble() < .5 ? PropCell.CrystalA : PropCell.CrystalB, .48f, 6f, true);
                for (int i = 0; i < 3; i++) flares.Glint(hit + Dir3(rng) * .5f * s, s * 1.2f, delay + i * .03f, Color.Lerp(p.hot, Color.white, .5f), i);
                break;
            case Matter.Filigree:
                Fling(PropCell.Coin, .36f, 6f, true);
                for (int i = 0; i < 4; i++) flares.Glint(hit + Dir3(rng) * .6f * s, s * 1.2f, delay + i * .03f, Color.Lerp(p.hot, Color.white, .5f), i);
                break;
            case Matter.Silk:
                Fling(PropCell.Petal, .5f, 4f, false);
                props.Add(SmokeSheet(hit, Vector3.up * .4f * s, 1.6f * s * k, Tint(p, rng, .5f, .9f, .35f), delay, .7f, 0, rng));
                break;
            case Matter.Electric:
                for (int i = 0; i < Mathf.RoundToInt(2 * k); i++)
                {
                    var cell = i % 2 == 0 ? PropCell.BoltA : PropCell.BoltB;
                    var it = Props.New(cell, cell, hit + Dir3(rng) * .5f * s, R(rng, 1.2f, 1.8f) * k * s, delay + (i % 2) * .08f, .14f);
                    it.faceCam = true; it.rollStart = R(rng, 0f, 360f); it.glow = 1f; it.glowDecay = 1f; it.peak = .01f; it.fadeFrom = .3f; it.growTime = 0f;
                    it.tint = Tint(p, rng, .5f, 1f, .4f);
                    props.Add(it);
                }
                flares.Puff(hit, Vector3.zero, 1.2f * s * k, 1.8f, Tint(p, rng, .5f, 1f, .3f), true, .3f, delay, 2f, 0f, rng);
                break;
            case Matter.Flame:
                FireBurst(props, hit, s * k, delay, Mathf.RoundToInt(4 * k), rng);
                props.Add(SmokeSheet(hit - f.toCam * .1f * s + Vector3.up * .7f * s, Vector3.up * .8f * s, 1.6f * s * k, new Color(.62f, .52f, .48f), delay + .14f, .75f, 2, rng));
                for (int i = 0; i < burst; i++) flares.Mote1(hit, (Dir3(rng) + Vector3.up * .6f) * R(rng, 3f, 6f) * s, Mote.Ember, R(rng, .12f, .22f) * s, Tint(p, rng, .6f, 1f, .2f), R(rng, .4f, .7f), delay, 2f, -.5f * s, rng);
                break;
            default: // Smoke
                // A cloud thrown out to both sides of the recipient, and a darker one behind it.
                props.Add(SmokeSheet(hit - f.toCam * .05f * s, Vector3.zero, 2.6f * s * k, Color.Lerp(RampAt(p, .55f), Color.white, .3f), delay, .8f, 1, rng));
                props.Add(SmokeSheet(hit - f.toCam * .2f * s, Vector3.up * .3f * s, 1.8f * s * k, Tint(p, rng, .5f, .9f, .25f), delay + .03f, .85f, 0, rng));
                break;
        }
    }

    /// The named move, as objects.
    void AccentSolid(Profile p, Style style, Frame f, float delay, Props props, Flares flares, System.Random rng)
    {
        float s = f.s;
        var T = f.target; var U = Vector3.up; var Rt = f.right; var C = f.toCam; var D = f.Depth;
        // An attack lands on the hero, whose feet are at the bottom edge of the screen: its
        // ground pieces (swords, spikes, craters) stand a little beyond, toward the attacker.
        var foot = f.Foot + (style != Style.Support ? D * .9f * s : Vector3.zero); float floor = f.Foot.y + .01f;
        bool heavy = style == Style.Heavy, light = style == Style.Light;
        var white = Color.Lerp(p.hot, Color.white, .5f);
        Props.Item Item(PropCell cell, Vector3 at, float size, float when, float life)
        {
            var it = Props.New(cell, cell, at, size, when, life);
            it.sheen = R(rng, 0f, 1f); return it;
        }
        void Rubble(Vector3 at, int n, float when)
        {
            var crater = Item(PropCell.Crater, new Vector3(at.x, floor + .005f, at.z), (heavy ? 3.2f : 2.4f) * s, when, 1.3f);
            crater.rot = Quaternion.LookRotation(Vector3.down, D); crater.grow = .2f; crater.growTime = .1f; crater.fadeFrom = .6f; crater.tint = Color.Lerp(RampAt(p, .2f), Color.white, .5f);
            props.Add(crater);
            for (int i = 0; i < n; i++)
            {
                var it = Item(i % 2 == 0 ? PropCell.RockA : PropCell.RockB, at + U * .1f * s, R(rng, .25f, .5f) * s, when + R(rng, 0f, .03f), R(rng, .8f, 1.1f));
                it.vel = (Dir3(rng) * .6f + U * 1.2f).normalized * R(rng, 4f, 7f) * s; it.gravity = 10f * s; it.drag = .5f; it.floor = floor;
                it.axis = Dir3(rng); it.spin = R(rng, 300f, 700f); it.rot = AnyTurn(rng); it.fadeFrom = .7f; it.tint = Color.Lerp(RampAt(p, R(rng, .1f, .5f)), Color.white, .55f);
                props.Add(it);
            }
            props.Add(SmokeSheet(at + U * .45f * s, U * .6f * s, (heavy ? 2f : 1.6f) * s, new Color(.86f, .82f, .78f), when + .02f, .8f, 1, rng));
        }
        switch (p.accent)
        {
            case Accent.Lightning:
            {
                // Bolts out of the sky onto the recipient, struck twice.
                int bolts = heavy ? 3 : 2;
                for (int b = 0; b < bolts; b++)
                {
                    var top = T + U * R(rng, 3f, 4.2f) * s + Rt * R(rng, -1.6f, 1.6f) * s;
                    var end = T + Rt * R(rng, -.3f, .3f) * s;
                    for (int strike = 0; strike < (b == 0 ? 2 : 1); strike++)
                    {
                        var cell = (b + strike) % 2 == 0 ? PropCell.BoltA : PropCell.BoltB;
                        var it = Item(cell, Vector3.Lerp(top, end, .5f) + C * .4f * s, (top - end).magnitude * 1.05f, delay + b * .04f + strike * .1f, .13f);
                        it.faceCam = true; it.rollStart = RollToward(f, top - end); it.glow = 1.2f; it.glowDecay = 1f; it.peak = .01f; it.fadeFrom = .35f; it.growTime = 0f;
                        it.tint = Tint(p, rng, .6f, 1f, .45f);
                        props.Add(it);
                    }
                }
                break;
            }
            case Accent.Cracks:
                Rubble(T, heavy ? 10 : light ? 4 : 7, delay + .02f);
                break;
            case Accent.Vortex:
                flares.Swirl(T, C, Rt, Vector3.Cross(C, Rt).normalized, s, delay, heavy ? 18 : 13, Color.Lerp(RampAt(p, .1f), Color.black, .4f), Tint(p, rng, .5f, 1f, .2f), 2.4f * s, .25f * s, 0f, .7f, 7f * (f.side > 0 ? 1 : -1), rng);
                break;
            case Accent.Wings:
            {
                // Feathers fan out from the shoulders into two wings, hold, then drift away.
                var shoulder = T + U * .35f * s - C * .1f * s;
                int feathers = heavy ? 7 : 5;
                for (int side = -1; side <= 1; side += 2)
                    for (int k = 0; k < feathers; k++)
                    {
                        float fr = k / (feathers - 1f), th = Mathf.Lerp(-15f, 75f, fr) * Mathf.Deg2Rad;
                        var dir = side * Mathf.Cos(th) * Rt + Mathf.Sin(th) * U;
                        float len = s * (2.4f - .9f * fr);
                        var end = shoulder + dir * len * .55f;
                        var it = Item(PropCell.Feather, shoulder, len * .9f, delay + fr * .03f, 1.1f);
                        it.course = u => Vector3.Lerp(shoulder, end, 1f - (1f - u) * (1f - u)); it.travel = .22f;
                        it.faceCam = true; it.rollCourse = u => RollToward(f, dir) + side * 30f * (1f - u);
                        it.gravity = -.6f * s; it.drag = 2f; it.fadeFrom = .6f; it.grow = .3f; it.growTime = .2f; it.tint = Tint(p, rng, .5f, 1f, .3f);
                        props.Add(it);
                    }
                break;
            }
            case Accent.Tornado:
            {
                // A funnel of rolling smoke rising round the recipient, with its matter whirled in it.
                // A painted column of whirling smoke (the user's art), breathing as it turns.
                for (int k = 0; k < 2; k++)
                {
                    var col = SmokeSheet(foot + U * 2.1f * s + C * (.2f - .3f * k) * s, Vector3.zero, (heavy ? 4.6f : 3.8f) * s * (k == 0 ? 1f : .8f),
                        k == 0 ? Color.Lerp(RampAt(p, .35f), Color.white, .25f) : Tint(p, rng, .55f, 1f, .3f), delay + k * .06f, 1.15f, 2, rng);
                    col.grow = .3f; col.growTime = .25f; col.endScale = 1.12f; col.rollStart = k == 0 ? -4f : 6f; col.fadeFrom = .6f;
                    props.Add(col);
                }
                int debris = heavy ? 14 : 9;
                for (int i = 0; i < debris; i++)
                {
                    float a0 = R(rng, 0f, 6.283f), h0 = R(rng, .2f, 1f), spinDir = f.side > 0 ? 1 : -1;
                    var cell = p.matter == Matter.Silk ? PropCell.Petal : p.matter == Matter.Crystal ? PropCell.CrystalA : PropCell.Feather;
                    var it = Item(cell, foot, R(rng, .5f, .8f) * s, delay + R(rng, 0f, .1f), .95f);
                    it.course = u => { float a = a0 + spinDir * 9f * u; float h = h0 + u * 1.5f; float r = Mathf.Lerp(.5f, 1.6f, h * .5f) * s; return foot + U * h * 2.6f * s + (Mathf.Cos(a) * Rt + Mathf.Sin(a) * D) * r; };
                    it.travel = .95f; it.axis = Dir3(rng); it.spin = 600f; it.rot = AnyTurn(rng); it.fadeFrom = .7f; it.tint = Tint(p, rng, .4f, 1f, .3f);
                    props.Add(it);
                }
                break;
            }
            case Accent.Phoenix:
            {
                // 凤凰冲击: a phoenix dives out of the attacker's side onto the recipient and bursts
                // into burning feathers.
                float sx = f.side;
                var c = T + U * .6f * s + C * .3f * s;
                var from = c + (U * 3.2f + Rt * sx * 1.1f) * s;
                var bird = Item(PropCell.Phoenix, from, 2.6f * s, delay, .55f);
                bird.course = u => Vector3.Lerp(from, c, u * u); bird.travel = .28f;
                bird.faceCam = true; bird.rollStart = RollToward(f, c - from); bird.rollCourse = u => RollToward(f, c - from);
                bird.fadeFrom = .55f; bird.glow = .4f; bird.glowDecay = .3f; bird.endScale = 1.3f; bird.growTime = .1f; bird.grow = .7f;
                props.Add(bird);
                for (int i = 0; i < (heavy ? 12 : 9); i++)
                {
                    var it = Item(PropCell.Feather, c, R(rng, .5f, .9f) * s, delay + .28f, R(rng, .7f, 1f));
                    it.vel = (Dir3(rng) + U * .5f).normalized * R(rng, 3f, 6f) * s; it.drag = 2.5f; it.gravity = -.4f * s;
                    it.axis = Dir3(rng); it.spin = R(rng, 300f, 600f); it.rot = AnyTurn(rng); it.glow = .5f; it.glowDecay = .25f; it.tint = Tint(p, rng, .5f, 1f, .2f);
                    props.Add(it);
                }
                FireBurst(props, c, s * 1.2f, delay + .26f, 6, rng);
                break;
            }
            case Accent.FlyingSwords:
            case Accent.Needles:
            {
                // 飞剑 / 簪刺: a formation flies in from the attacker's side and stabs into the
                // ground round the recipient, one after another, then each one shatters.
                bool needles = p.accent == Accent.Needles;
                var away = f.caster - f.target; away.y = 0; away = away.sqrMagnitude > 1e-4f ? away.normalized : D;
                int n = needles ? (heavy ? 11 : 9) : heavy ? 7 : light ? 3 : 5;
                for (int i = 0; i < n; i++)
                {
                    float u0 = n == 1 ? .5f : i / (n - 1f);
                    var land = foot + Rt * Mathf.Lerp(-1.3f, 1.3f, u0) * s * R(rng, .85f, 1.1f) + D * (R(rng, -.15f, .5f) - .4f * Mathf.Abs(u0 - .5f)) * s;
                    var tilt = (-away * R(rng, .55f, .8f) + Vector3.down * R(rng, .55f, .8f) + Rt * (u0 - .5f) * .25f).normalized;
                    float L = (needles ? R(rng, 2f, 2.5f) : R(rng, 2.2f, 2.6f)) * s;
                    var stuck = land - tilt * L * .38f;
                    var start = stuck - tilt * R(rng, 3.5f, 4.5f) * s;
                    var it = Item(needles ? PropCell.Needle : PropCell.Sword, start, L, delay + i * .045f, .9f);
                    it.course = u => Vector3.Lerp(start, stuck, u); it.travel = .16f;
                    it.faceCam = true; it.rollStart = RollToward(f, -tilt); it.fadeFrom = .7f; it.peak = .03f; it.growTime = 0f; it.glow = .25f; it.glowDecay = .4f;
                    props.Add(it);
                    flares.Glint(land + C * .1f * s, s, delay + i * .045f + .16f, white, i);
                }
                break;
            }
            case Accent.JudgmentSword:
            {
                // 审判之剑: one great sword drops point first just in front of the recipient,
                // cracks the ground open, stands a moment and fades.
                var land = foot + D * .4f * s;
                float L = 4.2f * s;
                var stand = land + U * L * .4f;
                var start = stand + U * 6f * s;
                var it = Item(PropCell.Sword, start, L, delay, 1.1f);
                it.course = u => Vector3.Lerp(start, stand, u * u); it.travel = .14f;
                it.faceCam = true; it.rollStart = RollToward(f, Vector3.up); it.fadeFrom = .7f; it.growTime = 0f; it.glow = .25f; it.glowDecay = .12f;
                props.Add(it);
                Rubble(land, heavy ? 10 : 7, delay + .14f);
                break;
            }
            case Accent.ClockHands:
            {
                // 钟针合剪: great clock hands pivot on a hub above the recipient and sweep shut on
                // it from either side like shears.
                var hub = T + U * .25f * s + C * .3f * s;
                int hands = heavy ? 3 : 2;
                for (int k = 0; k < hands; k++)
                {
                    float sign = k == 0 ? 1f : -1f;
                    float a0 = k == 2 ? 200f : 90f + sign * R(rng, 62f, 78f);
                    float sweep = k == 2 ? -150f : -sign * R(rng, 50f, 62f);
                    float len = s * (k == 0 ? 2.1f : k == 1 ? 2.9f : 3.1f);
                    Func<float, float> ang = u => (a0 + sweep * (1f - (1f - u) * (1f - u))) * Mathf.Deg2Rad;
                    var camR = Camera.main ? Camera.main.transform.right : Rt; var camU = Camera.main ? Camera.main.transform.up : U;
                    Func<float, Vector3> dirOf = u => Mathf.Cos(ang(u)) * camR + Mathf.Sin(ang(u)) * camU;
                    var it = Item(PropCell.ClockHand, hub, len * 1.1f, delay + k * .02f, 1f);
                    it.course = u => hub + dirOf(u) * len * .42f; it.travel = .4f;
                    it.faceCam = true; it.rollCourse = u => ang(u) * Mathf.Rad2Deg - 90f; it.fadeFrom = .7f; it.growTime = .1f; it.grow = .5f; it.glow = .3f; it.glowDecay = .5f;
                    props.Add(it);
                }
                flares.Glint(hub, s * 1.5f, delay + .4f, white, 0);
                break;
            }
            case Accent.Chains:
            {
                // 锁链缚身: chains of real links shoot in from the sides and hook into the
                // recipient at different heights, pull tight, then the links fly apart.
                int chains = heavy ? 4 : 3;
                float[] heights = { .75f, .3f, -.2f, -.6f };
                var camR = Camera.main ? Camera.main.transform.right : Rt; var camU = Camera.main ? Camera.main.transform.up : U;
                for (int k = 0; k < chains; k++)
                {
                    var hook = T + U * heights[k] * s + Rt * R(rng, -.25f, .25f) * s + C * .2f * s;
                    float lr = k % 2 == 0 ? 1f : -1f, deg = R(rng, 12f, 48f) * Mathf.Deg2Rad;
                    var dir = (camR * lr * Mathf.Cos(deg) + camU * Mathf.Sin(deg)).normalized;
                    float length = R(rng, 2.5f, 3.2f) * s, step = .32f * s;
                    int links = Mathf.RoundToInt(length / step);
                    for (int j = 0; j < links; j++)
                    {
                        var at = hook + dir * step * (j + .5f);
                        var start = at + dir * length;
                        float when = delay + k * .05f;
                        var it = Item(PropCell.ChainLink, start, .42f * s, when, 1f);
                        it.course = u => Vector3.Lerp(start, at, u); it.travel = .18f;
                        it.faceCam = true; it.rollStart = RollToward(f, dir) + (j % 2 == 0 ? 0f : 0f); it.growTime = 0f; it.peak = .02f;
                        // Alternate links stand edge-on: drawn narrower across.
                        if (j % 2 == 1) { it.size *= .9f; it.tint = new Color(.8f, .82f, .86f); }
                        it.wait = .55f; it.kick = (Dir3(rng) + C * .5f) * R(rng, 2f, 4f) * s; it.gravity = 6f * s; it.drag = 1f;
                        it.fadeFrom = .7f;
                        props.Add(it);
                    }
                }
                break;
            }
            case Accent.ClawRake:
            {
                // 兽爪撕裂: claw marks tear open across the recipient in the identity's colour (the
                // user's painted marks; a flying paw read as four white spikes, 2026-10-07: 尤其怪),
                // a second rake crossing the other way when heavy.
                int strokes = heavy ? 2 : 1;
                for (int st = 0; st < strokes; st++)
                {
                    float sd = (st == 0 ? 1f : -1f) * f.side;
                    var a = T + U * 1.3f * s - Rt * sd * 1f * s + C * .5f * s;
                    var b = T - U * .5f * s + Rt * sd * .9f * s + C * .5f * s;
                    var mark = Item(PropCell.PClaw, T + U * .4f * s + C * .5f * s, 2.8f * s, delay + st * .14f, .5f);
                    // The art rakes top-left to bottom-right; a quarter turn makes it rake the other way.
                    mark.faceCam = true; mark.rollStart = (sd > 0 ? 0f : 90f) + R(rng, -8f, 8f);
                    mark.tint = Tint(p, rng, .55f, .95f, .1f); mark.glow = .5f; mark.glowDecay = .12f;
                    mark.grow = .55f; mark.growTime = .07f; mark.endScale = 1.08f; mark.peak = .02f; mark.fadeFrom = .45f;
                    props.Add(mark);
                    for (int i = 0; i < 8; i++) flares.Mote1(Vector3.Lerp(a, b, (i + .5f) / 8), Dir3(rng) * 2f * s, i % 2 == 0 ? p.mote : Mote.Spark, R(rng, .12f, .22f) * s, Tint(p, rng, .5f, 1f, .2f), .45f, delay + st * .14f + (i + .5f) / 8 * .2f, 2f, 3f * s, rng);
                }
                break;
            }
            case Accent.ExecutionAxe:
            case Accent.Hammer:
            {
                // 断头斧 / 押运锤: raised high on the attacker's side, it swings down onto the
                // recipient in one blow and splits the ground.
                bool hammer = p.accent == Accent.Hammer;
                float sx = -f.side;
                // Lands in front of the hero, toward the attacker: on the hero's feet it struck
                // the bottom edge of the screen and swung in from off screen (all4).
                var strike = foot + U * .35f * s;
                float L = 2.9f * s;
                var grip = strike + (U * 1f + Rt * sx * .22f).normalized * L * .9f;
                float aEnd = Mathf.Atan2(Vector3.Dot(strike - grip, Camera.main ? Camera.main.transform.up : U), Vector3.Dot(strike - grip, Camera.main ? Camera.main.transform.right : Rt)) * Mathf.Rad2Deg;
                float aStart = aEnd + sx * 75f;
                var camR = Camera.main ? Camera.main.transform.right : Rt; var camU = Camera.main ? Camera.main.transform.up : U;
                Func<float, float> ang = u => Mathf.Lerp(aStart, aEnd, u * u);
                var it = Item(hammer ? PropCell.Hammer : PropCell.Axe, grip, L, delay, 1f);
                it.course = u => grip + (Mathf.Cos(ang(u) * Mathf.Deg2Rad) * camR + Mathf.Sin(ang(u) * Mathf.Deg2Rad) * camU) * L * .46f; it.travel = .2f;
                it.faceCam = true; it.rollCourse = u => ang(u) - 90f; it.fadeFrom = .7f; it.growTime = .08f; it.grow = .6f; it.glow = .15f; it.glowDecay = .2f;
                props.Add(it);
                Rubble(new Vector3(strike.x, floor, strike.z), heavy ? 10 : 7, delay + .2f);
                break;
            }
            case Accent.SwordQi:
            {
                // Crescent waves of sword energy cut through the recipient and fly on.
                int n = heavy ? 3 : 2;
                for (int k = 0; k < n; k++)
                {
                    float ang = (k == 0 ? R(rng, -12, 12) : k == 1 ? R(rng, 32, 52) : R(rng, -52, -32)) * Mathf.Deg2Rad;
                    var d = (Mathf.Cos(ang) * Rt * f.side * (k % 2 == 0 ? 1 : -1) + Mathf.Sin(ang) * U).normalized;
                    var a = T - d * 2.8f * s + C * .3f * s; var b = T + d * 3.4f * s + C * .3f * s;
                    var it = Item(PropCell.Qi, a, 2.1f * s, delay + k * .07f, .4f);
                    it.course = u => Vector3.Lerp(a, b, u); it.travel = .4f; it.carry = true;
                    it.faceCam = true; it.rollStart = RollToward(f, d) + 90f; it.rollCourse = u => RollToward(f, d) - 90f;
                    it.tint = Tint(p, rng, .55f, .95f, .05f); it.glow = .35f; it.glowDecay = .3f; it.peak = .03f; it.fadeFrom = .6f; it.growTime = .05f; it.grow = .5f;
                    props.Add(it);
                }
                break;
            }
            case Accent.SwordRain:
            {
                // Swords drop from the sky and stake the ground round the recipient.
                int n = heavy ? 10 : light ? 4 : 7;
                for (int i = 0; i < n; i++)
                {
                    var land = foot + (Rt * R(rng, -1.7f, 1.7f) + D * R(rng, -.6f, 1.2f)) * s;
                    var tilt = (Vector3.down + Rt * R(rng, -.3f, .3f)).normalized;
                    float L = R(rng, 2.2f, 3f) * s;
                    var stuck = land - tilt * L * .38f;
                    var start = stuck - tilt * R(rng, 4.5f, 6f) * s;
                    var it = Item(PropCell.Sword, start, L, delay + i * .045f + R(rng, 0f, .03f), .9f);
                    it.course = u => Vector3.Lerp(start, stuck, u * u); it.travel = .16f;
                    it.faceCam = true; it.rollStart = RollToward(f, -tilt); it.fadeFrom = .7f; it.peak = .02f; it.growTime = 0f; it.tint = Tint(p, rng, .6f, 1f, .6f);
                    props.Add(it);
                }
                break;
            }
            case Accent.Meteor:
            {
                // Burning stones fall on a slant, trailing fire, and burst on landing.
                int n = heavy ? 6 : light ? 2 : 4;
                var inc = (Vector3.down + Rt * -f.side * R(rng, .5f, .8f)).normalized;
                for (int i = 0; i < n; i++)
                {
                    var land = foot + (Rt * R(rng, -1.6f, 1.6f) + D * R(rng, -.8f, .8f)) * s + U * .2f * s;
                    var start = land - inc * R(rng, 4f, 5.5f) * s;
                    float when = delay + i * .085f + R(rng, 0f, .04f), size = R(rng, .7f, 1f) * s;
                    // The user's painted fire, flames streaming back along the fall.
                    var it = Item(PropCell.PFire, start, size * 2.2f, when, .3f);
                    it.course = u => Vector3.Lerp(start, land, u); it.travel = .26f;
                    it.faceCam = true; it.rollStart = RollToward(f, -inc); it.rollCourse = u => RollToward(f, -inc);
                    it.glow = .5f; it.glowDecay = 1f; it.fadeFrom = .85f; it.growTime = 0f;
                    props.Add(it);
                    flares.SmokeWake(u => Vector3.Lerp(start, land, u), Vector3.zero, when, .26f, s * .8f, 8, Color.Lerp(RampAt(p, .1f), Color.black, .5f), Tint(p, rng, .6f, 1f, .1f), rng);
                    FireBurst(props, land + U * .2f * s, s * .8f, when + .26f, 4, rng);
                    if (i == 0) Rubble(new Vector3(land.x, floor, land.z), 5, when + .26f);
                }
                break;
            }
            case Accent.Spikes:
            {
                // Crystal or bone spikes burst up out of the ground round the recipient.
                int n = heavy ? 12 : light ? 5 : 9;
                for (int i = 0; i < n; i++)
                {
                    float ang = i * 2.39996f + R(rng, -.3f, .3f), rr = R(rng, .25f, 2f) * s;
                    var radial = Mathf.Cos(ang) * Rt + Mathf.Sin(ang) * D;
                    float h = s * R(rng, 1.3f, 2.8f) * Mathf.Clamp(1.25f - rr / (2.4f * s), .45f, 1.2f);
                    var stand = foot + radial * rr + U * h * .45f;
                    var below = stand - U * h;
                    var it = Item(PropCell.Spike, below, h, delay + rr / s * .035f, .95f);
                    it.course = u => Vector3.Lerp(below, stand, 1f - (1f - u) * (1f - u)); it.travel = .1f;
                    it.upright = true; it.rollStart = R(rng, -12f, 12f) + Vector3.Dot(radial, Rt) * 14f; it.fadeFrom = .7f; it.growTime = 0f;
                    it.tint = Tint(p, rng, .4f, 1f, .3f); it.glow = .3f; it.glowDecay = .2f;
                    props.Add(it);
                }
                break;
            }
            case Accent.Dragon:
            {
                // A dragon of scaled segments coils up round the recipient, head last.
                float turns = (rng.NextDouble() < .5 ? -1 : 1) * R(rng, 1.4f, 1.7f) * 6.283f, a0 = R(rng, 0, 6.28f), height = R(rng, 3.6f, 4.1f) * s;
                Func<float, Vector3> coil = t =>
                {
                    float a = a0 + turns * t, r = s * (1.05f - .3f * t);
                    return foot + U * (.2f * s + height * Mathf.Pow(Mathf.Clamp01(t), .9f)) + r * (Mathf.Cos(a) * Rt + Mathf.Sin(a) * D) + C * .2f * s;
                };
                int segs = 16;
                const float lag = .045f, travel = .6f;
                for (int k = 0; k < segs; k++)
                {
                    float back = k * lag;
                    float size = s * Mathf.Lerp(.85f, .45f, k / (float)segs);
                    var it = Item(PropCell.DragonScale, coil(0f), size, delay, 1.3f);
                    it.course = u => coil(Mathf.Max(0f, u * (1f + segs * lag) - back)); it.travel = travel;
                    it.faceCam = true; it.rollStart = R(rng, -20f, 20f); it.fadeFrom = .7f; it.growTime = .1f; it.grow = .4f; it.glow = .2f; it.glowDecay = .5f;
                    props.Add(it);
                }
                var head = Item(PropCell.DragonHead, coil(0f), 1.6f * s, delay, 1.3f);
                head.course = u => coil(u * (1f + segs * lag)) + U * .2f * s; head.travel = travel;
                head.faceCam = true; head.rollCourse = u => { var a = coil(Mathf.Min(1f, u + .02f)) - coil(Mathf.Max(0f, u - .02f)); return RollToward(f, a) + 90f; };
                head.fadeFrom = .7f; head.growTime = .1f; head.grow = .5f; head.glow = .3f; head.glowDecay = .5f;
                props.Add(head);
                break;
            }
            case Accent.Lotus:
            {
                // A lotus opens at the recipient: two layers of petals unfold round a bright
                // heart, then lift away. A bloom, never a blast.
                var heart = T - U * .2f * s + C * .5f * s;
                // The user's painted lotus opens on the recipient, and loose petals lift off it.
                var bloom = Item(PropCell.PLotus, heart + U * .1f * s, 2.8f * s, delay, 1.3f);
                bloom.faceCam = true; bloom.grow = .2f; bloom.growTime = .4f; bloom.endScale = 1.1f; bloom.peak = .1f; bloom.fadeFrom = .6f;
                bloom.tint = Tint(p, rng, .55f, .9f, .35f); bloom.glow = .4f; bloom.glowDecay = .4f; bloom.gravity = -.15f * s;
                props.Add(bloom);
                for (int ring = 0; ring < 1; ring++)
                {
                    int petals = 6;
                    for (int j = 0; j < petals; j++)
                    {
                        float ang = Mathf.Lerp(-80f, 80f, (j + .5f) / petals) + R(rng, -4f, 4f);
                        var camR = Camera.main ? Camera.main.transform.right : Rt; var camU = Camera.main ? Camera.main.transform.up : U;
                        var dir = Mathf.Sin(ang * Mathf.Deg2Rad) * camR + Mathf.Cos(ang * Mathf.Deg2Rad) * camU;
                        float L = (ring == 0 ? 1.6f : 1.2f) * s;
                        var it = Item(PropCell.Petal, heart, L, delay + ring * .08f + j * .015f, 1.3f);
                        it.course = u => heart + dir * L * .45f * (1f - (1f - u) * (1f - u)) - C * .02f * ring; it.travel = .35f;
                        it.faceCam = true; it.rollStart = -ang; it.rollCourse = u => -ang * (.4f + .6f * u);
                        it.gravity = -.5f * s; it.drag = 1.5f; it.fadeFrom = .65f; it.grow = .3f; it.growTime = .3f;
                        it.tint = Tint(p, rng, ring == 0 ? .3f : .6f, ring == 0 ? .7f : 1f, .35f);
                        props.Add(it);
                    }
                }
                flares.Puff(heart, Vector3.up * .3f * s, 1f * s, 1.8f, Tint(p, rng, .6f, 1f, .4f), true, .9f, delay + .2f, 1.5f, 0f, rng);
                break;
            }
            case Accent.Shards:
            case Accent.Splatter:
            case Accent.Foam:
            {
                var hit = T + C * .35f * s;
                var cell = p.accent == Accent.Shards ? PropCell.CrystalA : p.accent == Accent.Splatter ? PropCell.InkSplat : PropCell.Bubble;
                int n = p.accent == Accent.Splatter ? 3 : heavy ? 10 : 7;
                for (int i = 0; i < n; i++)
                {
                    var it = Item(cell, hit + Dir3(rng) * .3f * s, (p.accent == Accent.Splatter ? R(rng, 1f, 1.6f) : R(rng, .3f, .55f)) * s, delay + R(rng, 0f, .05f), R(rng, .6f, .9f));
                    if (p.accent == Accent.Splatter) { it.faceCam = true; it.rollStart = R(rng, 0f, 360f); it.grow = .2f; it.growTime = .1f; it.pos += Dir3(rng) * .8f * s; it.tint = Color.Lerp(RampAt(p, R(rng, .3f, .7f)), Color.white, .5f); }
                    else
                    {
                        it.vel = (Dir3(rng) + U * (p.accent == Accent.Foam ? 1f : .3f)).normalized * R(rng, 2f, 5f) * s; it.drag = 2f;
                        it.gravity = p.accent == Accent.Foam ? -1.5f * s : 5f * s; it.axis = Dir3(rng); it.spin = R(rng, 200f, 600f); it.rot = AnyTurn(rng);
                        it.tint = Tint(p, rng, .4f, 1f, .3f);
                    }
                    it.fadeFrom = .55f;
                    props.Add(it);
                }
                break;
            }
        }
    }

    // ------------------------------------------------------------ solid hero cards

    /// Hero cards whose travel and landing are objects and smoke, not bands (2026-10-07,
    /// user on 170.14: 你很多这些一条条的, after the finale's curtains read as pillars).
    /// Their trails, strands, landing bands and burst spikes are dropped; SolidShot flies
    /// the object and SolidImpact draws the landing. The light thrown out (Explode) stays.
    static bool Solid(Form form) => SolidAll ? form != Form.Bloom : form is Form.Throw or Form.Hunt or Form.Dash or Form.Swap or Form.Rain;

    static Vector3 Dir3(System.Random rng)
    {
        var v = new Vector3(R(rng, -1, 1), R(rng, -1, 1), R(rng, -1, 1));
        return v.sqrMagnitude > 1e-4f ? v.normalized : Vector3.up;
    }

    static Quaternion AnyTurn(System.Random rng) => Quaternion.Euler(R(rng, 0, 360), R(rng, 0, 360), R(rng, 0, 360));

    /// The flying object of a solid card, on the shot's own course.
    void SolidShot(Profile p, Shot shot, float at, Frame f, Props props, Flares trail, System.Random rng, int n)
    {
        if (shot.course == null) return;
        float s = f.s;
        // Cards fly as the authored tarot flipbook: it gathers out of light (row 1 of the
        // sheet), then streaks on its course turned to its flight (row 2).
        // 假面谕令 throws a card too (the drawn white mask prop read as clip art).
        if (tarotMaterial && p.form is Form.Rain or Form.Flick or Form.Reverse or Form.Proclaim or Form.Swap or Form.Edict)
        {
            float k = p.form == Form.Proclaim ? 1.7f : p.form == Form.Flick ? .85f : p.form == Form.Swap ? 1.3f : 1.05f;
            TarotFlight.Create(root, tarotMaterial, this, shot.course, shot.time, at, k * s, n);
            return;
        }
        // Front shown to the camera at the start: the quad faces away from it (see Props).
        var showFront = Quaternion.LookRotation(-f.toCam, Vector3.up);
        switch (p.form)
        {
            case Form.Throw:
            {
                // 伪证烙印: the wax seal itself, flipping edge over edge like a tossed coin, hot.
                var it = Props.New(PropCell.WaxSeal, PropCell.WaxSeal, shot.course(0), .62f * s, at, shot.time + .03f);
                it.course = shot.course; it.travel = shot.time; it.carry = true; it.axis = (f.right + Vector3.up * .3f).normalized; it.spin = 900f;
                it.rot = showFront; it.glow = .45f; it.glowDecay = 1f; it.peak = .03f; it.fadeFrom = .97f; it.growTime = 0f;
                props.Add(it);
                break;
            }
            case Form.Swap:
            {
                // 张冠李戴: each name card turns over and over as it flies, showing face and back.
                var it = Props.New(PropCell.NameFront, PropCell.NameBack, shot.course(0), .6f * s, at, shot.time + .03f);
                it.course = shot.course; it.travel = shot.time; it.axis = Vector3.up; it.spin = (n % 2 == 0 ? 1f : -1f) * 620f; it.size = .6f * s;
                it.rot = showFront; it.peak = .03f; it.fadeFrom = .97f; it.growTime = 0f;
                props.Add(it);
                break;
            }
            case Form.Rain:
            {
                // 荒谬归结: the volley is real tarot cards, tumbling on their arcs.
                var it = Props.New(PropCell.TarotFront, PropCell.TarotBack, shot.course(0), .42f * s, at, shot.time + .03f);
                it.course = shot.course; it.travel = shot.time; it.axis = Dir3(rng); it.spin = R(rng, 520f, 820f) * (n % 2 == 0 ? 1f : -1f);
                it.rot = showFront * Quaternion.AngleAxis(R(rng, -30f, 30f), Vector3.forward); it.peak = .03f; it.fadeFrom = .97f; it.growTime = 0f;
                it.glow = .15f; it.glowDecay = 1f; it.sheen = R(rng, 0f, 1f);
                props.Add(it);
                break;
            }
            case Form.Flick:
            case Form.Reverse:
            case Form.Proclaim:
            {
                // The basic's flicked tarot, 反客为主's card shooting past, 无名宣告's golden decree.
                bool decree = p.form == Form.Proclaim;
                var it = Props.New(PropCell.TarotFront, PropCell.TarotBack, shot.course(0), (decree ? .7f : p.form == Form.Flick ? .34f : .42f) * s, at, shot.time + .03f);
                it.course = shot.course; it.travel = shot.time; it.axis = decree ? Vector3.up : Dir3(rng); it.spin = decree ? 360f : R(rng, 600f, 900f);
                it.rot = showFront; it.peak = .03f; it.fadeFrom = .97f; it.growTime = 0f; it.glow = decree ? .5f : .2f; it.glowDecay = 1f; it.sheen = R(rng, 0f, 1f);
                if (decree) it.tint = new Color(1f, .9f, .6f);
                props.Add(it);
                break;
            }
            case Form.Edict:
            {
                // 假面谕令: the white mask glides to the target's face, turning a little.
                var it = Props.New(PropCell.Mask, PropCell.Mask, shot.course(0), .5f * s, at, shot.time + .03f);
                it.course = shot.course; it.travel = shot.time; it.faceCam = true; it.rollStart = R(rng, -25f, 25f); it.spin = R(rng, -60f, 60f);
                it.peak = .03f; it.fadeFrom = .97f; it.growTime = 0f;
                props.Add(it);
                break;
            }
            case Form.Hunt:
            {
                // 双影追猎: smoke shed low behind each running shadow, not a flat band on the floor.
                var dark = Color.Lerp(p.ramp[0], Color.black, .25f);
                var lit = Color.Lerp(p.ramp[2], p.ramp[3], .5f);
                trail.SmokeWake(shot.course, Vector3.down * .55f * s, at, shot.time, s, 14, dark, lit, rng);
                break;
            }
        }
    }

    /// The landing of a solid card at the contact: objects and smoke, no bands.
    void SolidImpact(Profile p, Frame f, float reach, float delay, bool lead, bool stage, float archA, float archB, System.Random rng)
    {
        var props = Props.Create(root, propMaterial, this);
        var flares = Flares.Create(root, flareMaterial, this);
        float s = f.s;
        var front = f.target + f.toCam * .35f * s;
        float floor = f.Foot.y + .01f;
        var showFront = Quaternion.LookRotation(-f.toCam, Vector3.up);
        var white = Color.Lerp(p.hot, Color.white, .6f);
        bool fewer = ReducedMotion;
        switch (p.form)
        {
            case Form.Rain:
            {
                // 荒谬归结: the props come down. Tarot cards are thrown off the target at the
                // hit; on the main target a shower of cards then falls inside the stage arch,
                // fluttering and turning to catch the light, and settles on the floor.
                int burst = lead ? 7 : 4;
                float a0 = R(rng, 0f, 6.283f);
                for (int k = 0; k < burst; k++)
                {
                    float ang = a0 + (k + R(rng, -.3f, .3f)) / burst * 6.283f;
                    var d = (Mathf.Cos(ang) * f.right + Mathf.Sin(ang) * f.up + f.toCam * R(rng, -.2f, .4f)).normalized;
                    var it = Props.New(PropCell.TarotFront, PropCell.TarotBack, front, R(rng, .55f, .75f) * s, delay + R(rng, 0f, .03f), R(rng, .75f, 1f));
                    it.vel = d * reach * R(rng, 2.4f, 3.4f); it.drag = 3.2f; it.gravity = 2.5f * s; it.floor = floor;
                    it.axis = Dir3(rng); it.spin = R(rng, 500f, 900f) * (k % 2 == 0 ? 1f : -1f); it.rot = AnyTurn(rng);
                    it.grow = .4f; it.growTime = .12f; it.glow = .6f; it.glowDecay = .15f; it.fadeFrom = .6f; it.sheen = R(rng, 0f, 1f);
                    props.Add(it);
                }
                if (stage && archA > 0f)
                {
                    int rain = fewer ? 9 : 15;
                    for (int k = 0; k < rain; k++)
                    {
                        float x = Mathf.Lerp(-archA * .78f, archA * .78f, (k + R(rng, .1f, .9f)) / rain);
                        float top = archB * Mathf.Sqrt(Mathf.Max(0f, 1f - (x / archA) * (x / archA)));
                        var start = f.Foot + f.right * x + Vector3.up * top * R(rng, .7f, .95f) + f.toCam * R(rng, -.2f, .5f) * s;
                        var it = Props.New(PropCell.TarotFront, PropCell.TarotBack, start, R(rng, .55f, .78f) * s, delay + .05f + R(rng, 0f, .4f), R(rng, 1.5f, 1.9f));
                        it.vel = Vector3.down * R(rng, .3f, .8f) * s; it.gravity = R(rng, 4.5f, 6f) * s; it.drag = 1.6f; it.floor = floor;
                        it.sway = R(rng, .5f, 1f) * s; it.swayFreq = R(rng, 5f, 8f);
                        it.axis = Dir3(rng); it.spin = R(rng, 180f, 420f) * (k % 2 == 0 ? 1f : -1f); it.rot = AnyTurn(rng);
                        it.grow = .6f; it.growTime = .15f; it.peak = .08f; it.fadeFrom = .74f; it.glow = .25f; it.glowDecay = .4f; it.sheen = R(rng, 0f, 1f);
                        props.Add(it);
                    }
                }
                break;
            }
            case Form.Throw:
            {
                // 伪证烙印: the forged seal slams onto the target, glowing hot, molten wax
                // splashes out behind it, and drops are flung forward onto the floor where a
                // splash spreads.
                var splash = Props.New(PropCell.WaxSplash, PropCell.WaxSplash, front - f.toCam * .05f * s, (lead ? 2.5f : 1.7f) * s, delay + .015f, .8f);
                splash.faceCam = true; splash.spin = R(rng, -15f, 15f); splash.grow = .25f; splash.growTime = .14f; splash.fadeFrom = .4f; splash.endScale = 1.12f;
                splash.tint = new Color(.85f, .85f, .85f);
                props.Add(splash);
                var seal = Props.New(PropCell.WaxSeal, PropCell.WaxSeal, front + f.toCam * .1f * s, (lead ? 1.5f : 1f) * s, delay, .85f);
                seal.faceCam = true; seal.spin = R(rng, -20f, 20f); seal.grow = 1.9f; seal.growTime = .1f; seal.glow = .5f; seal.glowDecay = .1f;
                seal.peak = .02f; seal.fadeFrom = .55f; seal.endScale = 1.06f;
                props.Add(seal);
                var pool = Props.New(PropCell.WaxSplash, PropCell.WaxSplash, new Vector3(f.target.x, floor, f.target.z) + f.dir * .3f * s, (lead ? 2.6f : 1.8f) * s, delay + .03f, 1.1f);
                pool.rot = Quaternion.LookRotation(Vector3.down, f.dir); pool.grow = .3f; pool.growTime = .16f; pool.fadeFrom = .5f;
                props.Add(pool);
                int drops = (lead ? 12 : 6) * (fewer ? 2 : 3) / 3;
                var lateral = Vector3.Cross(Vector3.up, f.dir).normalized;
                for (int k = 0; k < drops; k++)
                {
                    var d = (f.dir * R(rng, .3f, 1f) + lateral * R(rng, -1f, 1f) + Vector3.up * R(rng, .5f, 1.3f) + f.toCam * R(rng, 0f, .4f)).normalized;
                    var it = Props.New(PropCell.WaxDrop, PropCell.WaxDrop, front, R(rng, .18f, .34f) * s, delay + R(rng, 0f, .04f), R(rng, .85f, 1.15f));
                    it.vel = d * R(rng, 2.5f, 4.5f) * s; it.gravity = 9f * s; it.drag = .8f; it.floor = floor;
                    it.axis = Dir3(rng); it.spin = R(rng, 400f, 900f); it.rot = AnyTurn(rng);
                    it.glow = .4f; it.glowDecay = .2f; it.fadeFrom = .65f; it.grow = .5f; it.growTime = .06f;
                    props.Add(it);
                }
                break;
            }
            case Form.Hunt:
            {
                // 双影追猎: the two shadows close on the target as rolling smoke from either side
                // and swallow it; a pair of eyes opens in the smoke as the second one bites.
                // Dark enough to read as shadow over bright marble, centred on the chest.
                var dark = Color.Lerp(p.ramp[0], Color.black, .55f);
                var lit = Color.Lerp(p.ramp[2], p.ramp[3], .5f);
                int count = lead ? 22 : 11;
                float size = lead ? 1.35f : .9f;
                var chest = f.target + f.up * .35f * s;
                // The user's painted two-sided smoke, wide at first and closing in on the target,
                // a darker one behind and a lit one in front.
                for (int k = 0; k < 2; k++)
                {
                    var cloud = SmokeSheet(chest + f.toCam * (k == 0 ? -.1f : .3f) * s, Vector3.zero, (lead ? 3.4f : 2.4f) * s * (k == 0 ? 1f : .85f),
                        k == 0 ? Color.Lerp(dark, Color.white, .1f) : Color.Lerp(lit, Color.white, .1f), delay + k * .09f, 1f, 1, rng);
                    cloud.grow = 1.5f; cloud.growTime = .3f; cloud.endScale = .9f; cloud.fadeFrom = .55f;
                    props.Add(cloud);
                }
                if (lead) flares.Eyes(chest + f.up * .45f * s + f.toCam * .7f * s, f.right, s * 1.6f, delay + .14f, Color.Lerp(lit, Color.white, .55f));
                break;
            }
            case Form.Dash:
            {
                // 错步穿行: the cut cracks the air like a mirror. Two crossing strokes of mirror
                // shards appear along the cut, each with a glint, hang for a beat, then burst
                // outward tumbling and fall.
                int per = lead ? 5 : 3;
                float len = (lead ? 1.3f : .9f) * s;
                for (int stroke = 0; stroke < 2; stroke++)
                {
                    float ang = ((stroke == 0 ? 35f : 145f) + R(rng, -10f, 10f)) * Mathf.Deg2Rad;
                    var d = Mathf.Cos(ang) * f.right + Mathf.Sin(ang) * f.up;
                    for (int k = 0; k < per; k++)
                    {
                        float u = (k + R(rng, .2f, .8f)) / per;
                        var at = front + d * Mathf.Lerp(-len, len, u) + Dir3(rng) * .05f * s;
                        float when = delay + stroke * .06f + u * .07f;
                        var it = Props.New(k % 2 == 0 ? PropCell.ShardA : PropCell.ShardB, k % 2 == 0 ? PropCell.ShardA : PropCell.ShardB, at, R(rng, .45f, .7f) * s, when, R(rng, .75f, .95f));
                        it.rot = showFront * Quaternion.AngleAxis(R(rng, 0f, 360f), Vector3.forward) * Quaternion.AngleAxis(R(rng, -25f, 25f), Vector3.right);
                        it.wait = .14f; it.kick = ((at - front).normalized * .8f + Dir3(rng) * .4f + f.toCam * .3f).normalized * R(rng, 2.5f, 4f) * s;
                        it.drag = 2f; it.gravity = 4f * s; it.floor = floor; it.axis = Dir3(rng); it.spin = R(rng, 500f, 1000f);
                        it.glow = .3f; it.glowDecay = .08f; it.grow = .3f; it.growTime = .06f; it.fadeFrom = .55f; it.sheen = R(rng, 0f, 1f);
                        props.Add(it);
                        flares.Glint(at + f.toCam * .1f * s, s, when, white, k);
                    }
                }
                break;
            }
            case Form.Flick:
            {
                // The basic: the flicked card nicks the target and a few cards spin off it.
                for (int k = 0; k < (lead ? 3 : 2); k++)
                {
                    var d = (Dir3(rng) + Vector3.up * .5f + f.toCam * .3f).normalized;
                    var it = Props.New(PropCell.TarotFront, PropCell.TarotBack, front, R(rng, .3f, .4f) * s, delay + k * .02f, .55f);
                    it.vel = d * R(rng, 2.5f, 4f) * s; it.drag = 3f; it.gravity = 3f * s; it.axis = Dir3(rng); it.spin = R(rng, 600f, 900f); it.rot = AnyTurn(rng);
                    it.glow = .5f; it.glowDecay = .1f; it.fadeFrom = .5f; it.grow = .5f; it.growTime = .06f;
                    props.Add(it);
                }
                flares.Glint(front, s * 1.3f, delay, white, 0);
                break;
            }
            case Form.Edict:
            {
                // 假面谕令: the mask settles on the target's face, holds, then cracks into shards.
                var face = f.target + f.up * .25f * s + f.toCam * .5f * s;
                var mask = Props.New(PropCell.Mask, PropCell.Mask, face, (lead ? 1.3f : .9f) * s, delay, .55f);
                mask.faceCam = true; mask.rollStart = R(rng, -8f, 8f); mask.grow = 1.5f; mask.growTime = .1f; mask.glow = .6f; mask.glowDecay = .15f; mask.fadeFrom = .8f;
                props.Add(mask);
                for (int k = 0; k < (lead ? 8 : 5); k++)
                {
                    var it = Props.New(k % 2 == 0 ? PropCell.CrystalA : PropCell.CrystalB, PropCell.CrystalA, face + Dir3(rng) * .25f * s, R(rng, .25f, .4f) * s, delay + .44f, .5f);
                    it.vel = (Dir3(rng) + f.toCam * .4f).normalized * R(rng, 2.5f, 4.5f) * s; it.drag = 2f; it.gravity = 4f * s; it.axis = Dir3(rng); it.spin = R(rng, 500f, 900f);
                    it.rot = AnyTurn(rng); it.tint = Color.Lerp(RampAt(p, R(rng, .5f, 1f)), Color.white, .4f); it.glow = .5f; it.glowDecay = .1f; it.fadeFrom = .5f;
                    props.Add(it);
                }
                break;
            }
            case Form.Reverse:
            {
                // 反客为主: the card comes back from behind the target, through it, toward the
                // hero, shedding petals.
                var a = f.target + f.dir * 1.1f * s + f.up * .55f * s;
                var b = f.target - f.dir * 1.2f * s - f.up * .3f * s + f.toCam * .3f * s;
                var it = Props.New(PropCell.TarotFront, PropCell.TarotBack, a, (lead ? .75f : .5f) * s, delay, .45f);
                it.course = u => Vector3.Lerp(a, b, u); it.travel = .22f; it.axis = Dir3(rng); it.spin = 900f; it.rot = AnyTurn(rng); it.glow = .5f; it.glowDecay = .2f; it.fadeFrom = .7f;
                props.Add(it);
                for (int k = 0; k < (lead ? 9 : 5); k++)
                {
                    var pt = Props.New(PropCell.Petal, PropCell.Petal, f.target + f.toCam * .3f * s, R(rng, .35f, .55f) * s, delay + .1f + R(rng, 0f, .06f), R(rng, .6f, .9f));
                    pt.vel = (-f.dir + Dir3(rng) * .7f + Vector3.up * .3f).normalized * R(rng, 2f, 4f) * s; pt.drag = 2.5f; pt.gravity = 1f * s; pt.sway = .5f * s;
                    pt.axis = Dir3(rng); pt.spin = R(rng, 200f, 500f); pt.rot = AnyTurn(rng); pt.tint = Tint(p, rng, .3f, 1f, .3f); pt.fadeFrom = .55f;
                    props.Add(pt);
                }
                break;
            }
            case Form.Rewrite:
            {
                // 后手改写 (on the hero): three cards rise round the figure, turning to catch the
                // light, with bubbles of the ward's water.
                for (int k = 0; k < 3; k++)
                {
                    var at = f.target + f.right * (k - 1) * .8f * s - f.up * .4f * s;
                    var it = Props.New(PropCell.TarotFront, PropCell.TarotBack, at, .7f * s, delay + k * .05f, .8f);
                    it.vel = Vector3.up * R(rng, 2f, 3f) * s; it.drag = 2.5f; it.axis = Vector3.up; it.spin = (k - 1) * 300f + 200f; it.rot = showFront;
                    it.glow = .6f; it.glowDecay = .3f; it.fadeFrom = .55f; it.grow = .3f; it.growTime = .12f;
                    props.Add(it);
                }
                for (int k = 0; k < 6; k++)
                {
                    var b = Props.New(PropCell.Bubble, PropCell.Bubble, f.target + Dir3(rng) * .6f * s, R(rng, .2f, .35f) * s, delay + R(rng, 0f, .15f), R(rng, .6f, .9f));
                    b.vel = Vector3.up * R(rng, 1f, 2f) * s; b.drag = 1f; b.faceCam = true; b.tint = Tint(p, rng, .4f, 1f, .4f); b.fadeFrom = .5f;
                    props.Add(b);
                }
                break;
            }
            case Form.Proclaim:
            {
                // 无名宣告: the golden decree comes down from above onto the target and a shower
                // of gold coins rains round it.
                var stand = f.target + f.up * .4f * s + f.toCam * .4f * s;
                var top = stand + f.up * 4f * s;
                var card = Props.New(PropCell.TarotFront, PropCell.TarotBack, top, (lead ? 2.4f : 1.4f) * s, delay, 1f);
                card.course = u => Vector3.Lerp(top, stand, u * u); card.travel = .16f; card.faceCam = true; card.rollStart = R(rng, -6f, 6f);
                card.tint = new Color(1f, .88f, .55f); card.glow = 1f; card.glowDecay = .2f; card.fadeFrom = .7f; card.growTime = 0f;
                props.Add(card);
                int coins = lead ? 16 : 8;
                for (int k = 0; k < coins; k++)
                {
                    var start = f.target + f.up * R(rng, 2.5f, 3.5f) * s + f.right * R(rng, -1.8f, 1.8f) * s + f.toCam * R(rng, 0f, .5f) * s;
                    var c = Props.New(PropCell.Coin, PropCell.Coin, start, R(rng, .35f, .5f) * s, delay + .1f + R(rng, 0f, .4f), R(rng, 1f, 1.3f));
                    c.vel = Vector3.down * R(rng, 1f, 2f) * s; c.gravity = 6f * s; c.drag = 1f; c.floor = floor; c.axis = Dir3(rng); c.spin = R(rng, 500f, 900f); c.rot = AnyTurn(rng);
                    c.fadeFrom = .7f; c.glow = .3f; c.glowDecay = .4f;
                    props.Add(c);
                }
                props.Add(SmokeSheet(stand - f.up * .3f * s, Vector3.up * .4f * s, 2.6f * s, new Color(1f, .86f, .55f), delay + .14f, .8f, 1, rng));
                break;
            }
            case Form.Swap:
            {
                // 张冠李戴: the two name cards meet on the target, flip over each other and
                // change places, one passing in front and one behind, in a puff of smoke.
                for (int k = 0; k < 2; k++)
                {
                    float side = k == 0 ? -1f : 1f;
                    var a = front + f.right * side * .75f * s + f.up * (k == 0 ? .55f : .05f) * s;
                    var b = front - f.right * side * 1.25f * s + f.up * (k == 0 ? .05f : .55f) * s;
                    var arc = (f.toCam * (k == 0 ? .4f : -.25f) + f.up * .2f) * s;
                    Func<float, Vector3> course = u => Vector3.Lerp(a, b, u) + arc * Mathf.Sin(Mathf.PI * u);
                    var it = Props.New(PropCell.NameFront, PropCell.NameBack, a, (lead ? 1.35f : .85f) * s, delay + k * .03f, .95f);
                    it.course = course; it.travel = .42f; it.carry = true; it.axis = Vector3.up; it.spin = side * 860f; it.rot = showFront;
                    it.grow = .6f; it.growTime = .08f; it.fadeFrom = .7f; it.glow = .5f; it.glowDecay = .15f; it.drag = 6f;
                    props.Add(it);
                }
                var puff = Color.Lerp(p.ramp[1], p.ramp[2], .5f);
                props.Add(SmokeSheet(front, Vector3.up * .3f * s, (lead ? 1.7f : 1.2f) * s, Color.Lerp(puff, Color.white, .3f), delay + .12f, .7f, 0, rng));
                break;
            }
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
            float ang = BurstAngle(p.form, k, n, a0, R(rng, -.32f, .32f));
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
            spike.rampShift = p.ramp.Length > 5 ? R(rng, -.45f, .45f) : p.form == Form.Swap ? (k % 2 == 0 ? .05f : .45f) : R(rng, 0f, .3f);
            if (rays) { spike.look = Matter.Silk; spike.coreAmt = 2.2f; spike.opacity = .7f; }
            list.Add(spike);
        }
        return list;
    }

    /// The named finisher's peak (荒谬归结, 2026-10-07; after comparing with other games, user
    /// agreed: 名招命中峰值放大到半屏). The hero's last act turns the battlefield into a stage:
    /// a torn rainbow proscenium arch springs from the floor on both sides of the target to well
    /// above its head, with a smaller off-centre arc torn across it. The arch frames the target
    /// rather than covering it; tarot cards rain down inside it (SolidImpact). The curtains and
    /// spotlight that hung in it read as pillars (user on 170.14: 这种线条，柱子，是有什么特殊
    /// 含义吗 / 你很多这些一条条的) and are gone. It opens at once, holds about a quarter of a second,
    /// then disperses. Half an ellipse with tapered, torn ends and a second arc of another centre
    /// and span, so never a ring or frame.
    /// Sized from the visible half-height at the target (<paramref name="half"/>), not the width:
    /// the editor camera's aspect is not the phone's, and sized from it the arch left the screen.
    /// Taller than wide so it clears the head yet spans about four fifths of a portrait screen.
    List<Path> FinaleStage(Frame f, float half, System.Random rng, out float archA, out float archB)
    {
        var list = new List<Path>();
        float s = f.s;
        var right = f.right; var up = Vector3.up;
        // Just in front of the target, so the arch passes round it and not through it.
        var floor = f.Foot + f.toCam * .35f * s;
        float a = half * R(rng, .34f, .38f);
        float b = half * R(rng, .56f, .62f);
        archA = a; archB = b;
        float a0 = R(rng, 172f, 179f) * Mathf.Deg2Rad, a1 = R(rng, 2f, 9f) * Mathf.Deg2Rad;
        float width = a * R(rng, .12f, .15f);
        Func<float, Vector3> archPos = t => { float an = Mathf.Lerp(a0, a1, t); return floor + Mathf.Cos(an) * a * right + Mathf.Sin(an) * b * up; };
        // Across the band = the ellipse's outward normal (b cos, a sin), so the band keeps its width round the top.
        var arch = Make(96, archPos, t => { float an = Mathf.Lerp(a0, a1, t); return Mathf.Cos(an) * b * right + Mathf.Sin(an) * a * up; },
            t => width * Swell(t, .35f), f.toCam);
        arch.pivot = floor; arch.revealScale = .6f; arch.holdScale = 1.6f; arch.coreAmt = .9f;
        arch.rampSpan = 1.05f; arch.tile = 5.5f; arch.solidStart = true;
        list.Add(arch);
        // A short arc of its own centre and span slashed across one shoulder of the arch. Spanning
        // the top too, it sat inside the arch like a second ring (a signal icon, probe 1).
        float side = f.side;
        // From inside the arch low on one side, out across its shoulder to above it, so it
        // crosses the arch instead of nesting in it, and keeps clear of the target's body.
        var c2 = floor + right * side * a * R(rng, .4f, .5f) + up * b * R(rng, .4f, .5f);
        float a2 = a * R(rng, .46f, .54f), b2 = b * R(rng, .46f, .54f);
        float s0 = R(rng, -20f, -10f) * Mathf.Deg2Rad, s1 = R(rng, 80f, 90f) * Mathf.Deg2Rad;
        if (side < 0) { float t0 = s0; s0 = Mathf.PI - s1; s1 = Mathf.PI - t0; }
        float w2 = a * R(rng, .07f, .09f);
        Func<float, Vector3> tearPos = t => { float an = Mathf.Lerp(s0, s1, t); return c2 + Mathf.Cos(an) * a2 * right + Mathf.Sin(an) * b2 * up; };
        var tear = Make(64, tearPos, t => { float an = Mathf.Lerp(s0, s1, t); return Mathf.Cos(an) * b2 * right + Mathf.Sin(an) * a2 * up; },
            t => w2 * Swell(t, .45f), f.toCam);
        tear.pivot = floor; tear.delay = .04f; tear.revealScale = .7f; tear.holdScale = 1.3f; tear.coreAmt = 1.1f;
        tear.rampShift = -.18f; tear.rampSpan = 1.05f; tear.tile = 3.6f;
        list.Add(tear);
        return list;
    }

    /// <paramref name="stage"/>: the finale's main target, whose curtains hang from the stage arch instead.
    List<Path> ImpactPaths(Form form, Frame f, System.Random rng, bool stage = false)
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
            case Form.Edict:
            {
                // The mask lands: a cool sheen sweeps straight across the target's face and a
                // short one down it, both thin, gone in a breath.
                var face = f.target + f.up * .25f * s + f.toCam * .2f * s;
                var a = face - lateral * .9f * s; var b = face + lateral * .9f * s;
                var sheen = Make(20, t => Vector3.Lerp(a, b, t), _ => f.up, t => s * .05f * Swell(t, .6f), f.toCam);
                sheen.pivot = face; sheen.rigid = true; sheen.offset = -lateral * .5f * s; sheen.drift = lateral * 1.2f * s;
                sheen.revealScale = .5f; sheen.holdScale = .6f; sheen.coreAmt = 2.4f; sheen.look = Matter.Silk;
                list.Add(sheen);
                var c = face + f.up * .55f * s; var d = face - f.up * .7f * s;
                var drop = Make(16, t => Vector3.Lerp(c, d, t), _ => lateral, t => s * .04f * Swell(t, .6f), f.toCam);
                drop.pivot = face; drop.rigid = true; drop.delay = .05f; drop.revealScale = .45f; drop.holdScale = .5f; drop.coreAmt = 2.4f; drop.look = Matter.Silk;
                list.Add(drop);
                break;
            }
            case Form.Swap:
            {
                // The two name tags meet on the target and slide past each other the wrong way.
                for (int k = 0; k < 2; k++)
                {
                    float side = k == 0 ? 1f : -1f, h = k == 0 ? .45f : 0f;
                    var mid = f.target + f.up * h * s + f.toCam * .25f * s;
                    var a = mid - lateral * .55f * s; var b = mid + lateral * .55f * s;
                    var tag = Make(16, t => Vector3.Lerp(a, b, t), _ => f.up, t => s * .09f * Mathf.Pow(Swell(t, 1f), .5f), f.toCam);
                    tag.pivot = mid; tag.rigid = true; tag.offset = -lateral * side * .8f * s; tag.drift = lateral * side * 1.4f * s; tag.delay = k * .04f;
                    tag.revealScale = .6f; tag.holdScale = .8f; tag.coreAmt = 1.8f; tag.rampShift = k == 0 ? .1f : .45f; tag.look = Matter.Silk;
                    list.Add(tag);
                }
                break;
            }
            case Form.Reverse:
            {
                // The strike comes back from behind the target, through it, toward the hero.
                var a = f.target + f.dir * 1.1f * s + f.up * .55f * s;
                var b = f.target - f.dir * .7f * s - f.up * .45f * s + lateral * .25f * s;
                Func<float, Vector3> pos = t => Vector3.Lerp(a, b, t);
                var back = Make(28, pos, FacingAcross(pos, f.toCam), t => s * .16f * Mathf.Pow(Swell(t, 1f), 1.2f), f.toCam);
                back.pivot = f.target; back.rigid = true; back.revealScale = .4f; back.holdScale = .6f; back.coreAmt = 2.6f; back.look = Matter.Silk;
                list.Add(back);
                var c = f.target + lateral * .7f * s + f.up * .2f * s; var d = f.target - lateral * .6f * s + f.up * .05f * s;
                Func<float, Vector3> across = t => Vector3.Lerp(c, d, t);
                var cross = Make(20, across, FacingAcross(across, f.toCam), t => s * .08f * Mathf.Pow(Swell(t, 1f), 1.2f), f.toCam);
                cross.pivot = f.target; cross.rigid = true; cross.delay = .06f; cross.revealScale = .35f; cross.holdScale = .5f; cross.coreAmt = 2.4f; cross.look = Matter.Silk;
                list.Add(cross);
                break;
            }
            case Form.Rewrite:
            {
                // On the hero: one bright stroke crosses out the line (划去), and three thin rays
                // rise behind the figure at uneven angles.
                var c = f.target;
                var a = c - lateral * .45f * s + f.up * .35f * s; var b = c + lateral * .5f * s - f.up * .3f * s;
                Func<float, Vector3> line = t => Vector3.Lerp(a, b, t);
                var strike = Make(18, line, FacingAcross(line, f.toCam), t => s * .05f * Mathf.Pow(Swell(t, 1f), 1.2f), f.toCam);
                strike.pivot = c; strike.rigid = true; strike.revealScale = .4f; strike.holdScale = .7f; strike.coreAmt = 2.6f; strike.look = Matter.Silk;
                list.Add(strike);
                for (int k = 0; k < 3; k++)
                {
                    var root = c - f.up * .5f * s - f.toCam * .2f * s + lateral * (k - 1) * .3f * s;
                    var dir = (Vector3.up + lateral * ((k - 1) * R(rng, .25f, .45f) + R(rng, -.1f, .1f))).normalized;
                    float len = R(rng, 1.1f, 1.7f) * s;
                    Func<float, Vector3> pos = t => root + dir * len * t;
                    var ray = Make(18, pos, FacingAcross(pos, f.toCam), t => s * .035f * Mathf.Min(1f, t * 6f) * Mathf.Pow(1f - t, .8f), f.toCam);
                    ray.pivot = root; ray.rigid = true; ray.delay = .03f + k * .04f; ray.revealScale = .8f; ray.holdScale = .8f; ray.coreAmt = 2.2f; ray.opacity = .8f; ray.look = Matter.Silk;
                    list.Add(ray);
                }
                break;
            }
            case Form.Proclaim:
            {
                // The decree comes down: a narrow beam straight down onto the target from above,
                // and four thin stage lights fanned down onto it at uneven angles.
                var top = f.target + f.up * 3.2f * s;
                var beam = Make(24, t => Vector3.Lerp(top, foot, t), _ => f.right, t => s * (.2f + .12f * t) * Swell(Mathf.Min(1f, t * 1.15f), .3f), f.toCam);
                beam.pivot = foot; beam.rigid = true; beam.revealScale = .6f; beam.holdScale = 1.1f; beam.coreAmt = 2.2f; beam.opacity = .85f; beam.look = Matter.Silk;
                list.Add(beam);
                for (int k = 0; k < 4; k++)
                {
                    float side = k % 2 == 0 ? 1f : -1f;
                    var from = top + lateral * side * R(rng, .6f, 1.6f) * s + f.up * R(rng, -.3f, .4f) * s;
                    var to = f.target + lateral * R(rng, -.25f, .25f) * s;
                    Func<float, Vector3> pos = t => Vector3.Lerp(from, to, t);
                    var light = Make(20, pos, FacingAcross(pos, f.toCam), t => s * .045f * Mathf.Min(1f, t * 4f), f.toCam);
                    light.pivot = to; light.rigid = true; light.delay = .02f + k * .03f; light.revealScale = .5f; light.holdScale = .9f; light.coreAmt = 2.2f;
                    light.opacity = .75f; light.look = Matter.Silk; light.rampShift = R(rng, 0f, .3f);
                    list.Add(light);
                }
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
                for (int k = 0; k < (stage ? 0 : 2); k++)
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
        if (SolidAll) { SolidEnemy(cue, style, caster, target, s, rng, delay, cam); return; }
        var p = cue.profile;
        var frame = new Frame(cam, caster, target, s, rng);
        var family = cue.cast % 2 == 1 ? p.familyAlt : p.family;
        if (style == Style.Support) family = Family.Rising;
        // Strike casts open two layers, not three: three broad bands stacked into a wall (2026-10-04).
        int layers = style switch { Style.Heavy => 3, Style.Strike => 2, Style.Light => 2, Style.Support => 3, _ => 2 };
        // The coiling dragon is the subject; keep only one light companion body.
        bool dragon = p.accent == Accent.Dragon;
        if (dragon) layers = 1;
        // The new named moves are the whole hit: no broad family bodies round the hero.
        bool named = p.accent is Accent.Phoenix or Accent.FlyingSwords or Accent.JudgmentSword or Accent.Tornado
            or Accent.ClockHands or Accent.Chains or Accent.ClawRake or Accent.ExecutionAxe or Accent.Needles or Accent.Wings or Accent.Hammer
            // A meteor shower or sword rain is the hit too: their broad crossed bodies made a lump (M22, M25, N08).
            or Accent.Meteor or Accent.SwordRain;
        var ramp = Ramp(p);
        // A lotus bloom is the whole support body; tongues would hide the petals.
        var paths = p.accent == Accent.Lotus || named ? new List<Path>() : Paths(family, frame, layers, rng);
        // Every enemy and support body thins, drifts a little and breaks into motes as it
        // fades (散开消散), calmly so thin bodies never writhe; crystal bodies are drawn
        // slimmer, as broad crystal bands read as panels of cracked glass (169.60).
        // Every enemy body is a little slimmer (crystal most), so gaps open between the bands and a hit
        // never reads as one solid lump (2026-10-04, user: 我不要这样的一团的东西).
        Path Finish(Path path) { if (style != Style.Support) Slim(path, p.matter == Matter.Crystal ? .6f : .75f); return Dispersing(path, frame.s, .8f, .3f, .12f, true); }
        for (int k = 0; k < paths.Count; k++)
        {
            paths[k].wobble = p.wobble * frame.s;
            var body = Body.Create(root, sweepMaterial, this);
            float bodyDelay = delay + paths[k].delay;
            body.Setup(Finish(paths[k]), frame.target, ramp, p, style, bodyDelay, (float)rng.NextDouble() * 10f, k);
        }
        // Strike and heavy casts also open one body of the identity's second
        // form, so a hit reads as layered matter rather than a single sweep.
        if (!dragon && !named && (style == Style.Strike || style == Style.Heavy) && p.familyAlt != family)
        {
            var extra = Paths(p.familyAlt, frame, 1, rng);
            for (int k = 0; k < Mathf.Min(2, extra.Count); k++)
            {
                var body = Body.Create(root, sweepMaterial, this);
                extra[k].rampShift += .18f;
                body.Setup(Finish(extra[k]), frame.target, ramp, p, style, delay + .045f + extra[k].delay, (float)rng.NextDouble() * 10f, 4 + k);
            }
        }
        if (!dragon && !named && p.column && style != Style.Light)
        {
            var col = Column(frame, rng);
            var body = Body.Create(root, sweepMaterial, this);
            body.Setup(Finish(col), frame.target, ramp, p, style == Style.Support ? Style.Support : Style.Heavy, delay + .02f, (float)rng.NextDouble() * 10f, 7);
        }
        // The identity's signature element (bolts, ground cracks, vortex, wings).
        var accentPaths = AccentPaths(p.accent, frame, style, rng);
        Flares impacts = null;
        if (p.accent == Accent.Phoenix)
        {
            // A glowing core leads the phoenix in along its dive.
            var (from, to, time, size) = phoenixDive;
            var glow = Flares.Create(root, flareMaterial, this);
            var hotColor = Color.Lerp(p.hot, Color.white, .35f);
            glow.Projectile(from, (to - from) / Mathf.Max(.05f, time), 0f, delay, time, size * .9f, Mote.Puff, hotColor, 0f, 0f);
            glow.Projectile(from, (to - from) / Mathf.Max(.05f, time), 0f, delay, time, size * .45f, Mote.Glint, Color.white, 0f, 90f);
        }
        for (int k = 0; k < accentPaths.Count; k++)
        {
            var body = Body.Create(root, sweepMaterial, this);
            body.Setup(Finish(accentPaths[k]), accentPaths[k].pivot ?? frame.target, ramp, p, style, delay + accentPaths[k].delay, (float)rng.NextDouble() * 10f, 10 + k);
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
        public float pulse, pulsePeriod = .45f;  // breathes larger and smaller while it lives (a whirlwind)
        public bool shatter;                 // bursts into flying shards and feathers as it starts to fade
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

    /// Direction (radians, in the screen plane) of the k-th of n burst rays. Most cards burst
    /// all round; three cards burst in their own shape so their landings are told apart (the
    /// first pass of all three read as the same coloured star): the mask's light fans upward,
    /// the swap throws two fans out to either side, the reversal sprays back toward the hero.
    static float BurstAngle(Form form, int k, int n, float a0, float jitter)
    {
        float u = (k + jitter) / Mathf.Max(1, n);
        switch (form)
        {
            case Form.Edict: return Mathf.Lerp(35f, 145f, u) * Mathf.Deg2Rad;
            case Form.Swap:
            {
                float v = (k / 2 + jitter * .5f + .25f) / Mathf.Max(1, (n + 1) / 2);
                return (k % 2 == 0 ? Mathf.Lerp(-32f, 32f, v) : Mathf.Lerp(148f, 212f, v)) * Mathf.Deg2Rad;
            }
            case Form.Reverse: return Mathf.Lerp(205f, 335f, u) * Mathf.Deg2Rad;
            default: return a0 + 6.283f * u;
        }
    }

    /// Narrows a body along its whole length.
    static void Slim(Path path, float k) { for (int i = 0; i < path.half.Length; i++) path.half[i] *= k; }

    /// Pulls the inner control points of a cubic toward its chord, keeping <paramref name="kept"/>
    /// of the bend (2026-10-03: 你很多都设置成这样弯弯的，都改掉吧).
    static void Flatten(Vector3 a, ref Vector3 b, ref Vector3 c, Vector3 d, float kept)
    {
        b = Vector3.Lerp(Vector3.Lerp(a, d, 1f / 3f), b, kept);
        c = Vector3.Lerp(Vector3.Lerp(a, d, 2f / 3f), c, kept);
    }

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
                // Off-centre arcs of unequal span: a torn rainbow dome. At most two, the second a
                // separate, smaller slash off to one side: three stacked arcs read as a signal icon
                // (the tower's bone claw, 2026-10-03).
                for (int k = 0; k < Mathf.Min(layers, 2); k++)
                {
                    // Each layer has its own centre, radius step and span, so stacked arcs never read
                    // as nested rings (the tower's bone claw showed three like a signal icon).
                    var centre = f.target - f.up * (.1f - .3f * k) * s + f.right * (k == 0 ? f.side * R(rng, -.3f, .3f) : -f.side * R(rng, .9f, 1.3f)) * s - f.toCam * (.2f * k) * s;
                    float radius = (1.55f * (k == 0 ? 1f : R(rng, .55f, .7f)) + R(rng, -.1f, .15f)) * s;
                    float a0 = (k == 0 ? R(rng, 165, 205) : R(rng, 130, 160)) * Mathf.Deg2Rad, a1 = (k == 0 ? R(rng, -25, 15) : R(rng, 20, 50)) * Mathf.Deg2Rad;
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
                    float lean = x0 * R(rng, 1.3f, 1.9f) + R(rng, -.7f, .7f) * s;
                    float height = R(rng, 2.6f, 4.6f) * s * (k == tongues / 2 ? 1.15f : 1f), depth = R(rng, -.4f, .4f) * s;
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
                    // Shorter: straightened, the old span (5.4 s up, 2.6 s out) crossed the whole screen (M28).
                    var p0 = f.target + f.up * (3.1f + .3f * k) * s - f.right * sd * R(rng, 1f, 1.4f) * s + f.toCam * .3f * s;
                    var p1 = f.target + f.up * 2.8f * s - f.right * sd * .5f * s;
                    var p2 = f.target + f.up * .1f * s - f.right * sd * .15f * s;
                    var p3 = f.target + f.right * sd * R(rng, .9f, 1.3f) * s + f.up * .05f * s + f.toCam * .8f * s;
                    Flatten(p0, ref p1, ref p2, p3, .3f);
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
                    // A straight rising slash rather than a curling surf wave.
                    Flatten(p0, ref p1, ref p2, p3, .25f);
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
                    float length = R(rng, 1.9f, 3.5f) * s, curl = R(rng, -.1f, .1f), depth = R(rng, -.5f, .5f) * s, width = R(rng, .46f, .66f) * s;
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
                    // Slim cuts (.3 of s, was .58): broad crossed bands read as slabs (169.60, M22/M28/M30).
                    var path = Make(56, pos, _ => perp, t => s * (.3f - .04f * k) * Mathf.Pow(Swell(t, 1f), 1.2f) * (1 + .45f * Mathf.Exp(-Mathf.Pow((t - .6f) / .16f, 2))), f.toCam);
                    path.delay = k * .055f; path.rampShift = .12f * k; path.tile = 3.6f; path.revealScale = .45f; path.coreAmt = 1.6f;
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
                // Fewer drapes (was 2 + layers): five veils side by side were a wall (N09, B10).
                int folds = 1 + layers;
                for (int k = 0; k < folds; k++)
                {
                    float x = (k - (folds - 1) * .5f) * R(rng, .8f, 1.15f) * s + R(rng, -.2f, .2f) * s;
                    // Straight drapes, each with its own slant and twist (no sine sway: 2026-10-03, user on the phone: 你很多都设置成这样弯弯的，都改掉吧).
                    // Narrower veils (.35-.5 s, were .55-.8): side by side they made a pink wall (N09).
                    float top = R(rng, 3.4f, 5.2f) * s, slant = R(rng, -.9f, .9f) * s, twist = R(rng, -.5f, .5f), depth = R(rng, -.6f, .6f) * s, width = R(rng, .35f, .5f) * s;
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
                    float reach = R(rng, 2.6f, 3.4f) * s, depth = (.8f - .5f * k) * s * .35f;
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
        Func<float, Vector3> pos = t => t2 + f.right * Mathf.Lerp(-reach, reach, t) + f.toCam * Mathf.Sin(t * Mathf.PI) * .3f * s;
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

    /// Where the last phoenix built by AccentPaths dives from and to, its dive time and size,
    /// for the glowing core that leads it in.
    (Vector3 from, Vector3 to, float time, float size) phoenixDive;

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
                // Streaks drawn in toward the recipient from around it: straight, at uneven
                // angles and lengths, each sliding inward as it appears and stopping short of
                // the centre. They used to be spiral arms (2026-10-03, the user's taste for every spell: 往前打, 炸开半屏不要全屏, 散开消散, 不要弯弯的, 不要规则形状).
                var sUp = Vector3.Cross(f.right, f.toCam).normalized;
                int arms = style == Style.Heavy ? 5 : 4;
                float a0 = R(rng, 0, 6.28f);
                var eye = f.target + f.up * .1f * s;
                for (int k = 0; k < arms; k++)
                {
                    float th = a0 + 6.283f * k / arms + R(rng, -.45f, .45f), rOut = R(rng, 1.9f, 2.8f) * s, rIn = R(rng, .25f, .55f) * s;
                    var dir = Mathf.Cos(th) * f.right + Mathf.Sin(th) * sUp;
                    Func<float, Vector3> pos = t => eye + dir * Mathf.Lerp(rOut, rIn, t) + f.toCam * (.25f * s * (1 - t));
                    float w0 = R(rng, .3f, .45f);
                    var arm = Make(24, pos, FacingAcross(pos, f.toCam), t => s * (w0 * Mathf.Pow(1 - t, 1.1f) + .03f) * Swell(Mathf.Pow(t, .3f), .5f), f.toCam);
                    arm.pivot = eye; arm.rigid = true; arm.offset = dir * R(rng, .4f, .7f) * s; arm.shrink = true; arm.opacity = .85f;
                    arm.revealScale = 1.1f; arm.holdScale = 1.1f; arm.tile = 2.2f; arm.delay = k * .03f + R(rng, 0f, .03f);
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
                        float len = s * (2.7f - 1f * fr) * R(rng, .9f, 1.08f), sd = side;
                        var dir = sd * Mathf.Cos(th) * f.right + Mathf.Sin(th) * f.up;
                        // Straight blades (they drooped in an arc: 弯弯的).
                        Func<float, Vector3> pos = t => shoulder + dir * len * t - f.toCam * .25f * s * t;
                        var feather = Make(40, pos, FacingAcross(pos, f.toCam), t => s * (.2f + .08f * (1 - fr)) * Swell(Mathf.Pow(t, .45f), .7f) * (1 - .3f * t), f.toCam);
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
                float height = R(rng, 4f, 4.8f) * s, spinSign = rng.NextDouble() < .5 ? -1 : 1, breath = R(rng, .4f, .5f);
                for (int k = 0; k < bands; k++)
                {
                    float a0 = 6.283f * k / bands + R(rng, -.35f, .35f), turns = spinSign * R(rng, 1.1f, 1.7f) * 6.283f;
                    float h0 = R(rng, 0f, .22f), h1 = R(rng, .72f, 1f), wBand = R(rng, .45f, .72f) * s;
                    Func<float, Vector3> pos = t =>
                    {
                        float hh = Mathf.Lerp(h0, h1, t), r = Mathf.Lerp(.28f, 1.8f, hh * hh) * s * (1 + .08f * Mathf.Sin(t * 9 + a0));
                        float a = a0 + turns * t;
                        return foot + Vector3.up * height * hh + r * (Mathf.Cos(a) * f.right + Mathf.Sin(a) * gz);
                    };
                    var band = Make(72, pos, t => Vector3.up + .25f * f.right, t => wBand * Swell(t, .5f) * (.55f + .8f * Mathf.Lerp(h0, h1, t)), f.toCam);
                    band.pivot = foot; band.spinAxis = Vector3.up; band.spin = spinSign * R(rng, 380f, 520f);
                    band.revealScale = 1.3f; band.holdScale = 3.4f; band.tile = 2f; band.delay = k * .02f; band.rampShift = R(rng, -.15f, .2f);
                    // The whole funnel breathes in and out together (旋风忽大忽小).
                    band.pulse = .26f; band.pulsePeriod = breath;
                    list.Add(band);
                }
                break;
            }
            case Accent.Phoenix:
            {
                // 凤凰冲击: a phoenix dives out of the attacker's side onto the recipient, seen from
                // the side so it reads as a bird: a bright body along its line of flight with a
                // crested head, two broad wings raised over it (feathers rooted along each wing's
                // leading edge, swept back, longest at the tip) and a fan of long tail plumes. It
                // is drawn large, above the recipient's head so the figure does not hide it, and
                // takes about .3 s to dive in (a glowing core leads it), then slams in and
                // shatters into feathers and embers. Every feather is straight; the shape comes
                // from the layout (the first pass, one radial fan of thin feathers, read as rays).
                float u = s * 1.5f, sx = f.side;
                var d = (-f.up * 1f + f.right * sx * .6f - f.toCam * .1f).normalized;        // line of flight, diving in
                var n = Vector3.Cross(f.toCam, d).normalized;                                  // across the flight, in the screen plane
                if (Vector3.Dot(n, f.up) < 0) n = -n;                                           // wings rise above the body
                var c = f.target + f.up * .55f * u;
                var charge = -d * 3.2f * u;
                const float rev = 2.6f, holdK = .7f, ease = 1.4f;
                phoenixDive = (c + charge, c, BaseReveal(style) * rev, u);
                Path Part(Path part, float delay, float shift, bool shatter)
                {
                    part.pivot = c; part.offset = charge; part.revealScale = rev; part.revealEase = ease; part.holdScale = holdK; part.solidStart = true;
                    part.delay = delay; part.rampShift = shift; part.shatter = shatter; part.tile = 1.4f;
                    return part;
                }
                var tailRoot = c - d * .55f * u; var head = c + d * .6f * u + n * .06f * u;
                {
                    Func<float, Vector3> bp = t => Vector3.Lerp(tailRoot, head, t);
                    var body = Make(18, bp, _ => n, t => u * .26f * Mathf.Pow(Swell(Mathf.Pow(t, .75f), 1f), .7f), f.toCam);
                    body.coreAmt = 2.8f; body.impactAt = c;
                    list.Add(Part(body, 0f, .45f, true));
                    for (int k = 0; k < 3; k++)
                    {
                        var dir = (-d * .75f + n * (.5f + .3f * k)).normalized;
                        var root = head - d * .08f * u;
                        float len = u * (k == 1 ? .7f : .5f);
                        Func<float, Vector3> cp = t => root + dir * len * t;
                        var crest = Make(10, cp, FacingAcross(cp, f.toCam), t => u * .07f * Mathf.Pow(1f - t, .7f), f.toCam);
                        crest.coreAmt = 2.2f;
                        list.Add(Part(crest, .01f, .5f, false));
                    }
                }
                for (int w = 0; w < 2; w++)
                {
                    float wk = w == 0 ? 1f : .8f;
                    var shoulder = c + d * .1f * u + n * .12f * u - f.toCam * .1f * w * u;
                    var edge = (n * 1f - d * (w == 0 ? .3f : .55f) + f.right * sx * (w == 0 ? -.2f : .25f)).normalized;
                    float span = u * 2f * wk;
                    int feathers = style == Style.Heavy ? 7 : 6;
                    for (int k = 0; k < feathers; k++)
                    {
                        float q = (k + .5f) / feathers;
                        var root = shoulder + edge * span * q;
                        var dir = (-d * 1f + edge * (.3f + .3f * q) - n * .2f).normalized;
                        float len = u * Mathf.Lerp(.6f, 1.7f, Mathf.Pow(q, 1.2f)) * wk * R(rng, .92f, 1.06f);
                        float wd = u * Mathf.Lerp(.2f, .28f, q) * wk;
                        Func<float, Vector3> fp = t => root + dir * len * t;
                        var feather = Make(14, fp, FacingAcross(fp, f.toCam), t => wd * Mathf.Min(1f, t * 5f) * Mathf.Pow(1f - t, .55f), f.toCam);
                        feather.coreAmt = 1.9f;
                        list.Add(Part(feather, .01f * k + .02f * w, Mathf.Lerp(.42f, -.05f, q), k % 2 == 1));
                    }
                    var e0 = shoulder; var e1 = shoulder + edge * span;
                    var spar = Make(12, t => Vector3.Lerp(e0, e1, t), _ => -d, t => u * .09f * wk * (1f - .6f * t), f.toCam);
                    spar.coreAmt = 2.6f;
                    list.Add(Part(spar, .02f * w, .5f, false));
                }
                for (int k = 0; k < 5; k++)
                {
                    float ang = (k - 2) * R(rng, 9f, 13f) + R(rng, -3f, 3f);
                    var dir = Quaternion.AngleAxis(ang, f.toCam) * -d;
                    float len = u * (k == 2 ? 3f : R(rng, 2.1f, 2.7f));
                    Func<float, Vector3> tp = t => tailRoot + dir * len * t;
                    var plume = Make(18, tp, FacingAcross(tp, f.toCam), t => u * .13f * Mathf.Min(1f, t * 3f) * Mathf.Pow(1f - t, .45f) * (1f + .7f * Mathf.Exp(-Mathf.Pow((t - .85f) / .07f, 2))), f.toCam);
                    plume.coreAmt = 1.7f;
                    list.Add(Part(plume, .015f * k, R(rng, -.1f, .3f), k == 2));
                }
                break;
            }
            case Accent.FlyingSwords:
            case Accent.Needles:
            {
                // Needles (簪刺): long thin hairpins with no guard, more of them, in a tighter fan.
                bool needles = accent == Accent.Needles;
                // 飞剑: a formation of swords flies in from the attacker's side, each pointing at
                // the recipient along its own line, and they stab into the ground round it one
                // after another; then each sword shatters. A sword is a pointed blade, a cross
                // guard and a short grip, with a thin trail along the line it flew.
                var foot = f.Foot; var gz = f.Depth;
                var away = f.caster - f.target; away.y = 0; away = away.sqrMagnitude > 1e-4f ? away.normalized : gz;
                int n = needles ? (style == Style.Heavy ? 11 : 9) : style == Style.Heavy ? 7 : light ? 3 : 5;
                for (int i = 0; i < n; i++)
                {
                    float u = n == 1 ? .5f : i / (n - 1f);
                    var land = foot + f.right * Mathf.Lerp(-1.25f, 1.25f, u) * s * R(rng, .85f, 1.1f) + gz * (R(rng, -.15f, .55f) - .4f * Mathf.Abs(u - .5f)) * s;
                    // Each flies down from above the attacker's side toward its landing point.
                    var tilt = (-away * R(rng, .55f, .8f) + Vector3.down * R(rng, .55f, .8f) + f.right * (u - .5f) * .25f).normalized;
                    float L = (needles ? R(rng, 2.3f, 2.9f) : R(rng, 2.1f, 2.5f)) * s, blade = L * (needles ? .92f : .74f), w = (needles ? R(rng, .06f, .08f) : R(rng, .17f, .21f)) * s;
                    var tip = land + tilt * .12f * s;
                    var guard = tip - tilt * blade;
                    var across = Vector3.Cross(tilt, f.toCam).normalized;
                    if (across.sqrMagnitude < .5f) across = f.right;
                    var fly = -tilt * R(rng, 3.8f, 4.8f) * s;
                    float delay = i * .045f + R(rng, 0f, .03f), rev = .45f;
                    // Blade: widest just past the guard, a long point.
                    Func<float, Vector3> bp = t => Vector3.Lerp(guard, tip, t);
                    var b = Make(22, bp, _ => across, t => w * (t < .06f ? Mathf.Lerp(.75f, 1f, t / .06f) : 1f - Mathf.Pow((t - .06f) / .94f, 1.8f)) + .003f * s, f.toCam);
                    b.pivot = tip; b.offset = fly; b.rigid = true; b.solidStart = true; b.revealScale = rev; b.holdScale = 2.2f; b.coreAmt = 2.4f;
                    b.delay = delay; b.impactAt = land; b.shatter = true; b.look = Matter.Silk; b.rampShift = .3f;
                    list.Add(b);
                    if (needles)
                    {
                        // A pearl head instead of a guard.
                        var pearl = Make(6, t => guard - tilt * (.1f * s * t), _ => across, t => s * .1f * Swell(t, .5f), f.toCam);
                        pearl.pivot = tip; pearl.offset = fly; pearl.rigid = true; pearl.solidStart = true; pearl.revealScale = rev; pearl.holdScale = 2.2f; pearl.coreAmt = 2.6f;
                        pearl.delay = delay; pearl.rampShift = .5f;
                        list.Add(pearl);
                        continue;
                    }
                    // Cross guard and grip.
                    var g0 = guard - across * .48f * s; var g1 = guard + across * .48f * s;
                    var gd = Make(10, t => Vector3.Lerp(g0, g1, t), _ => tilt, t => s * .07f, f.toCam);
                    gd.pivot = tip; gd.offset = fly; gd.rigid = true; gd.solidStart = true; gd.revealScale = rev; gd.holdScale = 2.2f; gd.coreAmt = 1.6f;
                    gd.delay = delay; gd.look = Matter.Filigree; gd.rampShift = .45f;
                    list.Add(gd);
                    var h1 = guard - tilt * L * .26f;
                    var grip = Make(8, t => Vector3.Lerp(guard, h1, t), _ => across, t => s * (t > .85f ? .08f : .05f), f.toCam);
                    grip.pivot = tip; grip.offset = fly; grip.rigid = true; grip.solidStart = true; grip.revealScale = rev; grip.holdScale = 2.2f; grip.coreAmt = 1.2f;
                    grip.delay = delay; grip.look = Matter.Filigree; grip.rampShift = .15f;
                    list.Add(grip);
                    // The line it flew: thin, fading fast.
                    var t0 = h1 + fly * .9f;
                    Func<float, Vector3> tp = t => Vector3.Lerp(t0, h1, t);
                    var trail = Make(16, tp, FacingAcross(tp, f.toCam), t => s * .06f * t, f.toCam);
                    trail.pivot = h1; trail.rigid = true; trail.revealScale = rev; trail.holdScale = .25f; trail.coreAmt = 2f; trail.opacity = .7f;
                    trail.delay = delay; trail.look = Matter.Silk; trail.rampShift = .35f;
                    list.Add(trail);
                }
                break;
            }
            case Accent.JudgmentSword:
            {
                // 审判之剑: one great sword drops point first out of the sky just in front of the
                // recipient, cracks the ground open round it, stands a moment and shatters.
                var foot = f.Foot; var gz = f.Depth;
                var land = foot + gz * .45f * s;
                var tilt = (Vector3.down + f.right * R(rng, -.12f, .12f) + gz * .1f).normalized;
                float L = R(rng, 4.2f, 4.6f) * s, blade = L * .76f, w = .52f * s;
                var tip = land + tilt * .15f * s;
                var guard = tip - tilt * blade;
                var across = Vector3.Cross(tilt, f.toCam).normalized;
                if (across.sqrMagnitude < .5f) across = f.right;
                var fall = -tilt * 6f * s;
                const float rev = .8f;
                Func<float, Vector3> bp = t => Vector3.Lerp(guard, tip, t);
                var b = Make(26, bp, _ => across, t => w * (t < .05f ? Mathf.Lerp(.8f, 1f, t / .05f) : 1f - Mathf.Pow((t - .05f) / .95f, 2f)) + .005f * s, f.toCam);
                b.pivot = tip; b.offset = fall; b.rigid = true; b.solidStart = true; b.revealScale = rev; b.holdScale = 2.6f; b.coreAmt = 2.4f; b.revealEase = 2f;
                b.impactAt = land; b.shatter = true; b.rampShift = .3f; b.look = Matter.Filigree;
                list.Add(b);
                var g0 = guard - across * .95f * s; var g1 = guard + across * .95f * s;
                var gd = Make(12, t => Vector3.Lerp(g0, g1, t), _ => tilt, t => s * .15f * (1f - .3f * Mathf.Abs(t * 2f - 1f)), f.toCam);
                gd.pivot = tip; gd.offset = fall; gd.rigid = true; gd.solidStart = true; gd.revealScale = rev; gd.holdScale = 2.6f; gd.coreAmt = 1.8f; gd.revealEase = 2f;
                gd.look = Matter.Filigree; gd.rampShift = .45f; gd.shatter = true;
                list.Add(gd);
                var h1 = guard - tilt * L * .24f;
                var grip = Make(10, t => Vector3.Lerp(guard, h1, t), _ => across, t => s * (t > .85f ? .17f : .11f), f.toCam);
                grip.pivot = tip; grip.offset = fall; grip.rigid = true; grip.solidStart = true; grip.revealScale = rev; grip.holdScale = 2.6f; grip.coreAmt = 1.4f; grip.revealEase = 2f;
                grip.look = Matter.Filigree; grip.rampShift = .15f;
                list.Add(grip);
                // The ground cracks open round it when it lands.
                float landTime = BaseReveal(style) * rev;
                var crackFrame = f; crackFrame.target = land + Vector3.up * f.up.y * 0f;
                foreach (var crack in AccentPaths(Accent.Cracks, crackFrame, style, rng)) { crack.delay += landTime; list.Add(crack); }
                break;
            }
            case Accent.ClockHands:
            {
                // 钟针合剪: two great clock hands (three when heavy: a thin second hand) pivot on a
                // brass hub just above the recipient and sweep shut on it from either side like
                // shears, then shatter. Straight tapered blades with a diamond tip; no dial ring.
                var c = f.target + f.up * .25f * s;
                int hands = style == Style.Heavy ? 3 : 2;
                for (int k = 0; k < hands; k++)
                {
                    float sign = k == 0 ? 1f : -1f;
                    float startDeg = k == 2 ? 200f : 90f + sign * R(rng, 62f, 78f);
                    float sweep = k == 2 ? -150f : -sign * R(rng, 50f, 62f);
                    float len = s * (k == 0 ? 2.1f : k == 1 ? 2.9f : 3.1f), w = s * (k == 0 ? .42f : k == 1 ? .32f : .09f);
                    var dir = Mathf.Cos(startDeg * Mathf.Deg2Rad) * f.right + Mathf.Sin(startDeg * Mathf.Deg2Rad) * f.up;
                    Func<float, Vector3> hp = t => c + dir * len * t;
                    // Tail stub behind the hub, the long body, a diamond widening near the tip.
                    var hand = Make(24, hp, FacingAcross(hp, f.toCam), t => w * (t < .08f ? .6f : .45f + .55f * Mathf.Exp(-Mathf.Pow((t - .78f) / .1f, 2))) * (1f - Mathf.Pow(t, 6f)) + .003f * s, f.toCam);
                    hand.pivot = c; hand.spinAxis = f.toCam; hand.rigid = true; hand.solidStart = true;
                    float rev = 1.6f, holdK = 1.6f, life = BaseReveal(style) * (rev + holdK);
                    // AngleAxis about the axis toward the camera turns the other way from the screen's
                    // angle (the first pass swung the hands down instead of shut above the target).
                    hand.spin = -sweep / Mathf.Max(.1f, life);
                    hand.revealScale = rev; hand.holdScale = holdK; hand.coreAmt = 2.4f; hand.look = Matter.Filigree;
                    hand.delay = k * .02f; hand.rampShift = k == 2 ? .5f : .3f; hand.shatter = true;
                    if (k == 0) hand.impactAt = c;
                    list.Add(hand);
                }
                // The hub: a short brass spindle across the pivot.
                var h0 = c - f.right * .22f * s; var h1 = c + f.right * .22f * s;
                var hub = Make(8, t => Vector3.Lerp(h0, h1, t), _ => f.up, t => s * .16f * Swell(t, .5f), f.toCam);
                hub.pivot = c; hub.rigid = true; hub.solidStart = true; hub.revealScale = 1f; hub.holdScale = 2.6f; hub.coreAmt = 2f; hub.look = Matter.Filigree; hub.rampShift = .45f;
                list.Add(hub);
                break;
            }
            case Accent.Chains:
            {
                // 锁链缚身: three or four chains shoot in from the attacker's side, fanned, and hook
                // into the recipient at different heights (shoulder, chest, waist, knee), pull
                // tight, then snap into flying links. They never meet in one point (the first pass
                // crossed them all at the chest and read as a star). Each chain is a straight run
                // of links: face-on links wide, edge-on links thin, alternating.
                // From the sides of the screen: from the attacker's own side they were foreshortened
                // into a short streak up the corridor (probe 7).
                int chains = style == Style.Heavy ? 4 : 3;
                float[] heights = { .75f, .3f, -.2f, -.6f };
                for (int k = 0; k < chains; k++)
                {
                    var hook = f.target + f.up * heights[k] * s + f.right * R(rng, -.25f, .25f) * s + f.toCam * .2f * s;
                    float lr = k % 2 == 0 ? 1f : -1f, deg = R(rng, 12f, 48f);
                    var dir = (f.right * lr * Mathf.Cos(deg * Mathf.Deg2Rad) + f.up * Mathf.Sin(deg * Mathf.Deg2Rad)).normalized;
                    var start = hook + dir * R(rng, 2.5f, 3.2f) * s;
                    float len = (hook - start).magnitude, w = s * R(rng, .14f, .17f), links = len / (.3f * s);
                    Func<float, Vector3> cp = t => Vector3.Lerp(start, hook, t);
                    var chain = Make(Mathf.Clamp(Mathf.RoundToInt(links * 6), 32, 96), cp, FacingAcross(cp, f.toCam),
                        t => w * (Mathf.Repeat(t * links, 2f) < 1f ? .95f : .38f) * Mathf.Min(1f, (1f - t) * 30f + .3f), f.toCam);
                    chain.pivot = hook; chain.rigid = true; chain.solidStart = true; chain.revealEase = 1f;
                    chain.revealScale = 1.1f; chain.holdScale = 2f; chain.coreAmt = 1.7f; chain.look = Matter.Filigree; chain.tile = 4f;
                    chain.delay = k * .05f; chain.rampShift = R(rng, .1f, .4f); chain.shatter = true;
                    if (k == 0) chain.impactAt = hook;
                    list.Add(chain);
                    // The hook: a short bar across the chain's end, biting into the body.
                    var side = Vector3.Cross(dir, f.toCam).normalized;
                    var h0 = hook - side * .22f * s; var h1 = hook + side * .22f * s;
                    var bite = Make(8, t => Vector3.Lerp(h0, h1, t), _ => dir, t => s * .09f, f.toCam);
                    bite.pivot = hook; bite.rigid = true; bite.revealScale = .4f; bite.holdScale = 3f; bite.coreAmt = 2.2f; bite.look = Matter.Filigree;
                    bite.delay = k * .05f + BaseReveal(style) * 1.1f; bite.rampShift = .45f;
                    list.Add(bite);
                }
                break;
            }
            case Accent.ClawRake:
            {
                // 兽爪撕裂: a paw rakes down across the recipient: three or four long claw cuts that
                // fan out from where the paw starts (never parallel), one quick stroke after
                // another; a heavy rake answers from the other side. Each cut tapers to points.
                int strokes = style == Style.Heavy ? 2 : 1;
                for (int st = 0; st < strokes; st++)
                {
                    float sd = (st == 0 ? 1f : -1f) * f.side;
                    int claws = style == Style.Heavy ? 4 : 3;
                    var start = f.target + f.up * 1.25f * s - f.right * sd * .95f * s + f.toCam * .25f * s;
                    var end = f.target - f.up * .85f * s + f.right * sd * .85f * s + f.toCam * .25f * s;
                    var along = (end - start).normalized;
                    var spread = Vector3.Cross(along, f.toCam).normalized;
                    for (int k = 0; k < claws; k++)
                    {
                        float o = (k - (claws - 1) * .5f);
                        var a = start + spread * o * .16f * s;
                        var b = end + spread * o * .45f * s + along * R(rng, -.15f, .15f) * s;
                        Func<float, Vector3> cp = t => Vector3.Lerp(a, b, t);
                        var cut = Make(28, cp, FacingAcross(cp, f.toCam), t => s * .16f * Mathf.Pow(Swell(t, 1f), 1.3f) * (1f + .35f * Mathf.Exp(-Mathf.Pow((t - .45f) / .18f, 2))), f.toCam);
                        cut.pivot = f.target; cut.rigid = true; cut.revealScale = .5f; cut.holdScale = .9f; cut.coreAmt = 2.6f;
                        cut.delay = st * .14f + k * .025f; cut.rampShift = .25f + .05f * k; cut.shatter = k == 1;
                        if (k == 0 && st == 0) cut.impactAt = f.target;
                        list.Add(cut);
                    }
                }
                break;
            }
            case Accent.ExecutionAxe:
            case Accent.Hammer:
            {
                // 押运锤 (Hammer): the same swing, with a heavy block of a head square across the haft.
                bool hammer = accent == Accent.Hammer;
                // 断头斧: a huge executioner's axe, raised high on the attacker's side, chops down
                // onto the recipient in one swing, splits the ground, stands a beat and shatters.
                // A long straight haft and a broad wedge of a head, widest at its cutting edge.
                float sx = -f.side;
                var grip = f.target + f.up * 2.9f * s + f.right * sx * 1.6f * s + f.toCam * .3f * s;
                var strike = f.target - f.up * .35f * s + f.right * -sx * .15f * s + f.toCam * .3f * s;
                var shaft = (strike - grip).normalized;
                float haftLen = (strike - grip).magnitude;
                var across = Vector3.Cross(shaft, f.toCam).normalized;
                if (Vector3.Dot(across, f.right * -sx) < 0) across = -across;       // the edge faces away from the attacker
                const float rev = 1.1f;
                Func<float, Vector3> hp = t => Vector3.Lerp(grip, strike, t);
                var haft = Make(16, hp, _ => across, t => s * .11f, f.toCam);
                haft.pivot = grip; haft.swing = sx * 75f; haft.swingAxis = f.toCam; haft.rigid = true; haft.solidStart = true;
                haft.revealScale = rev; haft.holdScale = 2.2f; haft.coreAmt = 1.4f; haft.look = Matter.Filigree; haft.rampShift = .1f;
                list.Add(haft);
                // Head: a wedge across the haft near its end, growing toward the cutting edge.
                var h0 = strike - shaft * (hammer ? .75f : 1.3f) * s; var h1 = strike + shaft * .1f * s;
                Func<float, Vector3> headPath = t => Vector3.Lerp(h0, h1, t);
                // Anchored: the head spans 2 x half from the haft (.7-1.2 s); at .9-1.6 half it was a 3 s slab.
                // The hammer's head runs across the haft on both sides, the same width all along.
                var head = hammer
                    // A chunky block (1.1 x .7 s): longer and thinner it read as a crossbar (probe 11).
                    ? Make(14, t => strike - shaft * .35f * s + across * Mathf.Lerp(-.55f, .55f, t) * s, _ => shaft, t => s * .35f * (1f - .12f * Mathf.Abs(t * 2f - 1f)), f.toCam)
                    : Make(18, headPath, _ => across, t => s * (.35f + .25f * t), f.toCam);
                head.anchored = !hammer; head.bulgeAmount = 0f;
                head.pivot = grip; head.swing = sx * 75f; head.swingAxis = f.toCam; head.rigid = true; head.solidStart = true;
                head.revealScale = rev; head.holdScale = 2.2f; head.coreAmt = 2.4f; head.rampShift = .35f; head.shatter = true; head.impactAt = strike;
                list.Add(head);
                float landTime = BaseReveal(style) * rev;
                var crackFrame = f; crackFrame.target = new Vector3(strike.x, f.target.y, strike.z);
                foreach (var crack in AccentPaths(Accent.Cracks, crackFrame, style, rng)) { crack.delay += landTime; list.Add(crack); }
                break;
            }
            case Accent.SwordQi:
            {
                // Shallow crescent sword waves sweep through the target and fly on: two or three,
                // flat arcs of a wide circle, so together they never close into a ring (the
                // tower's iron claw read as a circle crossed by an X).
                int n = style == Style.Heavy ? 3 : 2;
                for (int k = 0; k < n; k++)
                {
                    float ang = (k == 0 ? R(rng, -12, 12) : k == 1 ? R(rng, 32, 52) : k == 2 ? R(rng, -52, -32) : R(rng, 70, 80)) * Mathf.Deg2Rad;
                    var d = (Mathf.Cos(ang) * f.right * f.side * (k % 2 == 0 ? 1 : -1) + Mathf.Sin(ang) * f.up).normalized;
                    var perp = Vector3.Cross(d, f.toCam).normalized;
                    float radius = R(rng, 2.6f, 3.6f) * s, span = R(rng, 50, 68) * Mathf.Deg2Rad, thick = R(rng, .22f, .3f) * s;
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
                    float Lt = R(rng, 3.4f, 5f) * s, bend = 0f, head = R(rng, .45f, .62f) * s;
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
        bool shrink, rigid, disperse, dispersed, disperseCalm, shatter;
        float pulse, pulsePeriod;
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
            pulse = path.pulse; pulsePeriod = Mathf.Max(.1f, path.pulsePeriod); shatter = path.shatter;
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
            var flares = Flares.Create(owner.root, owner.flareMaterial, owner);
            flares.Scatter(profile, points, delays, pivot, Mathf.Max(.05f, disperseSize), rng);
            if (shatter)
            {
                // 碎裂开: the body bursts into shards and feathers flung out from its own surface.
                int m = ReducedMotion ? 8 : 18;
                var at = new Vector3[m];
                for (int i = 0; i < m; i++) at[i] = transform.TransformPoint(rest[rng.Next(rest.Length)]);
                flares.Shatter(profile, at, transform.TransformPoint(mesh.bounds.center), Mathf.Max(.05f, disperseSize), rng);
            }
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
            if (pulse > 0) scale *= 1f + pulse * Mathf.Sin(t * 6.2832f / pulsePeriod);
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

        public void Build(Profile p, Style style, Frame f, System.Random rng, float delay, bool group, bool forward = false, bool quiet = false)
        {
            float s = f.s;
            bool support = style == Style.Support;
            bool damage = style == Style.Light || style == Style.Strike || style == Style.Heavy;
            float tier = style == Style.Heavy ? 1.2f : style == Style.Strike ? 1f : style == Style.Light ? .62f : .7f;
            // Under a named move the heart and the spray are small: the move is the subject, and a
            // big heart round the hero is what read as a lump.
            if (quiet) tier *= .55f;
            var hotSpot = f.target + f.toCam * .35f * s;
            if (damage || style == Style.Control) Heart(p, style, f, rng, delay, group, tier, hotSpot, quiet);
            if (support)
            {
                // A soft tinted bloom on the recipient: warmth and reception, no splash or white core.
                Add(new Mark { pos = hotSpot, cell = Star(rng.Next(4)), color = Pick(p, rng, .35f, .7f), size = 1.2f * s, sizeEnd = 3.2f * s, rot = R(rng, 0, 360), spin = R(rng, -20, 20), life = .7f, delay = delay + .12f, peak = .35f, pop = true, opacity = .25f, hot = .2f });
            }
            // Solid spells draw their signature as objects (AccentSolid); the old accent marks
            // threw stretched ember and spark streaks across the screen (more lines).
            if (!SolidAll) AccentMarks(p, style, f, rng, delay, group, tier, hotSpot);
            int count = style switch { Style.Heavy => 112, Style.Strike => 82, Style.Light => 52, Style.Support => 64, _ => 52 };
            if (SolidAll) count = count * 2 / 5;
            if (group) count = Mathf.RoundToInt(count * .6f);
            // Hero forms spray their matter forward, away from the hero, and less of it.
            if (forward) count = Mathf.RoundToInt(count * .75f);
            if (quiet) count = Mathf.RoundToInt(count * .4f);
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
                        case Mote.Spark: m.stretch = SolidAll ? 0f : .045f; m.drag = 2.6f; m.size *= .9f; break;
                        case Mote.Ember: m.gravity = -2.4f * s; m.drag = 1.8f; break;
                        case Mote.Shard: m.gravity = 9f * s; m.drag = .9f; m.size *= 1.3f; break;
                        case Mote.Ink: m.gravity = 7f * s; m.drag = 1.2f; m.stretch = SolidAll ? 0f : .02f; break;
                        case Mote.Petal: m.gravity = 1.4f * s; m.drag = 3f; m.size *= 1.4f; m.life *= 1.3f; break;
                        case Mote.Card: m.gravity = 2.2f * s; m.drag = 2.6f; m.size *= 1.5f; m.life *= 1.2f; break;
                        case Mote.Wisp: m.gravity = -1.2f * s; m.drag = 2.8f; m.size *= 2.2f; m.stretch = SolidAll ? 0f : .012f; break;
                        case Mote.Puff: m.gravity = -.6f * s; m.drag = 3.4f; m.size *= 3.2f; m.sizeEnd = m.size * 1.8f; m.life *= 1.1f; break;
                    }
                }
                Add(m);
            }
        }

        // Each matter answers the contact with its own heart instead of one shared star.
        void Heart(Profile p, Style style, Frame f, System.Random rng, float delay, bool group, float tier, Vector3 hot, bool quiet = false)
        {
            float s = f.s;
            if (quiet)
            {
                // Under a named move: one small flash; the matter's own heart (splashes, puffs) made the lump.
                Add(new Mark { pos = hot, cell = Star(rng.Next(4)), color = Color.Lerp(Pick(p, rng, .45f, .85f), p.core, .4f), size = .5f * s, sizeEnd = 1.4f * s,
                    rot = R(rng, 0, 360), spin = R(rng, -40, 40), life = .26f, delay = delay, peak = .15f, pop = true, opacity = .45f, hot = .8f });
                return;
            }
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

        /// Shards, feathers and sparks flung out fast from a body breaking apart, with a flash.
        public void Shatter(Profile p, Vector3[] points, Vector3 centre, float s, System.Random rng)
        {
            var white = Color.Lerp(p.hot, Color.white, .55f);
            Add(new Mark { pos = centre, cell = MoteCell(Mote.Glint), color = white, size = .3f * s, sizeEnd = 1.4f * s, rot = R(rng, -10, 10), spin = R(rng, -40, 40),
                life = .2f, delay = 0f, peak = .2f, pop = true, opacity = .2f, hot = 1f });
            for (int i = 0; i < points.Length; i++)
            {
                var outward = points[i] - centre;
                outward = outward.sqrMagnitude > 1e-4f ? outward.normalized : Random3(rng);
                var type = i % 3 == 0 ? Mote.Spark : i % 3 == 1 ? p.mote : p.mote2;
                var vel = (outward * R(rng, 1f, 1.6f) + Random3(rng) * .4f + Vector3.up * R(rng, .1f, .5f)).normalized * R(rng, 3.5f, 7f) * s;
                float size = R(rng, .09f, .2f) * s * (type == Mote.Spark ? .7f : 1f);
                Add(new Mark { pos = points[i], vel = vel, drag = 2.4f, gravity = (type == Mote.Ember || type == Mote.Puff || type == Mote.Wisp ? -1.2f : 3.5f) * s,
                    stretch = type == Mote.Spark ? .03f : 0f, cell = MoteCell(type), color = Pick(p, rng, .35f, 1f), size = size, sizeEnd = size * .3f,
                    rot = R(rng, 0, 360), spin = R(rng, -600, 600), life = R(rng, .45f, .8f), delay = R(rng, 0f, .04f), peak = .12f,
                    opacity = type == Mote.Spark ? .35f : .9f, hot = type == Mote.Spark ? .8f : .3f });
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
        /// <paramref name="fewRays"/>: a solid card throws fewer and shorter rays; at full count
        /// the thin streaks read as lines again (user: 你很多这些一条条的).
        public void Explode(Profile p, Frame f, float reach, float delay, bool lead, System.Random rng, bool fewRays = false)
        {
            float s = f.s;
            var hot = f.target + f.toCam * .35f * s;
            var white = Color.Lerp(p.hot, Color.white, .6f);
            Add(new Mark { pos = hot + f.toCam * .1f * s, cell = MoteCell(Mote.Glint), color = white, size = .2f * reach, sizeEnd = (lead ? .9f : .6f) * reach,
                rot = R(rng, -10, 10), spin = R(rng, -60, 60), life = .17f, delay = delay, peak = .2f, pop = true, opacity = .25f, hot = 1f });
            Add(new Mark { pos = hot, cell = Star(rng.Next(4)), color = Color.Lerp(Pick(p, rng, .55f, .95f), p.core, .2f), size = .45f * reach, sizeEnd = 2.1f * reach,
                rot = R(rng, 0, 360), spin = R(rng, -40, 40), life = .34f, delay = delay + .01f, peak = .18f, pop = true, opacity = .45f, hot = .7f });
            // A solid card's object is the body; the torn splash, as wide as the burst, crossed
            // the screen as a broad translucent band (2026-10-07).
            if (lead && !fewRays)
            {
                Add(new Mark { pos = hot - f.toCam * .1f * s, cell = Splash(rng.Next(4)), color = Pick(p, rng, .3f, .75f), size = .45f * reach, sizeEnd = 1.8f * reach,
                    rot = R(rng, 0, 360), spin = R(rng, -50, 50), life = .42f, delay = delay + .02f, peak = .2f, pop = true, opacity = .85f, hot = .2f });
                Add(new Mark { pos = new Vector3(f.target.x, .04f, f.target.z), cell = Splash(rng.Next(4)), color = Pick(p, rng, .2f, .6f), size = .4f * reach, sizeEnd = 1.5f * reach,
                    rot = R(rng, 0, 360), spin = R(rng, -20, 20), life = .5f, delay = delay + .02f, peak = .22f, pop = true, flat = true, opacity = .8f, hot = .1f });
            }
            // Light thrown out across the screen plane: v0/drag is how far each ray can go.
            int rays = fewRays ? (lead ? 7 : 4) : lead ? 20 : 11, debris = lead ? 22 : 10;
            if (ReducedMotion) { rays = rays * 3 / 5; debris = debris * 3 / 5; }
            float a0 = R(rng, 0f, 6.283f);
            for (int i = 0; i < rays; i++)
            {
                float ang = BurstAngle(p.form, i, rays, a0, R(rng, -.4f, .4f));
                var d = (Mathf.Cos(ang) * f.right + Mathf.Sin(ang) * f.up + f.toCam * R(rng, -.15f, .3f)).normalized;
                Add(new Mark { pos = hot, vel = d * reach * 6f * R(rng, .7f, 1.1f), drag = 6f, stretch = fewRays ? .006f : .02f, cell = MoteCell(Mote.Spark),
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

        /// A billowing mass of smoke closing on 'centre' from 'from': overlapping soft puffs that
        /// swell and roll, most of them dark and alpha-blended (they darken what is behind) and
        /// a few lit in the identity's colour, so it reads as a volume, not a line.
        public void Billow(Vector3 centre, Vector3 from, float s, float delay, int count, Color dark, Color lit, float life, Vector3 toCam, System.Random rng, float litShare = .34f)
        {
            if (ReducedMotion) count = Mathf.Max(4, count * 3 / 5);
            for (int i = 0; i < count; i++)
            {
                bool glow = (i + .5f) / count % 1f < litShare || R(rng, 0f, 1f) < litShare * .3f;
                var start = Vector3.Lerp(from, centre, R(rng, 0f, .45f)) + Random3(rng) * R(rng, .1f, .35f) * s + toCam * R(rng, -.1f, .3f) * s;
                var vel = (centre - start) * R(rng, 2.4f, 3.6f) + Random3(rng) * .5f * s + Vector3.up * R(rng, 0f, .5f) * s;
                float size = R(rng, .55f, .95f) * s * (glow ? .8f : 1f);
                Add(new Mark { pos = start, vel = vel, drag = 3.2f, gravity = -.35f * s, cell = MoteCell(Mote.Puff), color = glow ? lit : dark,
                    size = size, sizeEnd = size * R(rng, 1.9f, 2.6f), rot = R(rng, 0, 360), spin = R(rng, -70, 70),
                    life = life * R(rng, .75f, 1.05f), delay = delay + R(rng, 0f, .06f), peak = .22f, opacity = glow ? .2f : 1f, hot = glow ? .3f : 0f });
            }
        }

        /// Smoke shed along a running course: puffs left behind a runner that swell and thin.
        public void SmokeWake(Func<float, Vector3> course, Vector3 drop, float delay, float time, float s, int count, Color dark, Color lit, System.Random rng)
        {
            if (ReducedMotion) count = Mathf.Max(3, count * 3 / 5);
            for (int i = 0; i < count; i++)
            {
                float u = (i + R(rng, 0f, .8f)) / count;
                bool glow = i % 4 == 3;
                float size = R(rng, .35f, .6f) * s;
                Add(new Mark { pos = course(u) + drop + Random3(rng) * .12f * s, vel = Random3(rng) * .3f * s + Vector3.up * R(rng, .1f, .4f) * s, drag = 2f, gravity = -.2f * s,
                    cell = MoteCell(Mote.Puff), color = glow ? lit : dark, size = size, sizeEnd = size * 2.2f, rot = R(rng, 0, 360), spin = R(rng, -60, 60),
                    life = R(rng, .45f, .7f), delay = delay + u * time, peak = .2f, opacity = glow ? .2f : .85f, hot = glow ? .3f : 0f });
            }
        }

        /// One soft puff of smoke, fire or mist moving on its own (a solid spell's matter
        /// when it has no object: smoke and flame). Lit puffs add light; dark ones shade.
        public void Puff(Vector3 pos, Vector3 vel, float size, float grow, Color color, bool lit, float life, float delay, float drag, float gravity, System.Random rng)
        {
            Add(new Mark { pos = pos, vel = vel, drag = drag, gravity = gravity, cell = MoteCell(Mote.Puff), color = color, size = size, sizeEnd = size * grow,
                rot = R(rng, 0, 360), spin = R(rng, -80, 80), life = life, delay = delay, peak = .2f, opacity = lit ? .22f : 1f, hot = lit ? .35f : 0f });
        }

        /// A spark, ember or other mote flung on its own.
        public void Mote1(Vector3 pos, Vector3 vel, Mote mote, float size, Color color, float life, float delay, float drag, float gravity, System.Random rng, float hot = .7f)
        {
            Add(new Mark { pos = pos, vel = vel, drag = drag, gravity = gravity, stretch = mote == Mote.Spark ? .012f : 0f, cell = MoteCell(mote), color = color,
                size = size, sizeEnd = size * .35f, rot = R(rng, 0, 360), spin = R(rng, -400, 400), life = life, delay = delay, peak = .15f,
                opacity = mote == Mote.Spark || mote == Mote.Ember ? .3f : .85f, hot = hot });
        }

        /// Puffs circling an axis: a funnel when they rise along it (tornado), a whirlpool
        /// when their radius closes in (vortex). Never a drawn ring: each puff has its own
        /// height, radius, speed and life.
        public void Swirl(Vector3 centre, Vector3 axis, Vector3 u, Vector3 v, float s, float delay, int count, Color dark, Color lit, float r0, float r1, float rise, float life, float speed, System.Random rng)
        {
            if (ReducedMotion) count = Mathf.Max(5, count * 3 / 5);
            for (int i = 0; i < count; i++)
            {
                bool glow = i % 3 == 2;
                float h = R(rng, 0f, 1f);
                float size = R(rng, .45f, .8f) * s * (glow ? .8f : 1f);
                Add(new Mark { orbit = true, oc = centre + axis * rise * h * .35f, oax = axis, ou = u, ov = v, r0 = r0 * R(rng, .7f, 1.2f) * (1f + h), r1 = r1 * R(rng, .7f, 1.2f) * (1f + h),
                    a0 = R(rng, 0f, 6.283f), w = speed * R(rng, .75f, 1.25f), rise = rise * R(rng, .5f, 1f), cell = MoteCell(Mote.Puff), color = glow ? lit : dark,
                    size = size, sizeEnd = size * R(rng, 1.4f, 2f), rot = R(rng, 0, 360), spin = R(rng, -90, 90), life = life * R(rng, .75f, 1.05f),
                    delay = delay + R(rng, 0f, .12f), peak = .2f, opacity = glow ? .2f : .95f, hot = glow ? .3f : 0f });
            }
        }

        /// A pair of glints: the eyes of a shadow opening in its smoke.
        public void Eyes(Vector3 at, Vector3 right, float s, float delay, Color color)
        {
            for (int k = 0; k < 2; k++)
                Add(new Mark { pos = at + right * (k == 0 ? -.12f : .12f) * s, cell = MoteCell(Mote.Glint), color = color, size = .1f * s, sizeEnd = .32f * s,
                    rot = 0f, life = .45f, delay = delay + k * .02f, peak = .3f, pop = true, opacity = .15f, hot = 1f });
        }

        /// One four-point glint popping at a point.
        public void Glint(Vector3 at, float s, float delay, Color color, int kind)
        {
            Add(new Mark { pos = at, cell = MoteCell(kind % 2 == 0 ? Mote.Glint : Mote.Twinkle), color = color, size = .12f * s, sizeEnd = .55f * s,
                rot = 0f, life = .24f, delay = delay, peak = .25f, pop = true, opacity = .2f, hot = 1f });
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

    // ------------------------------------------------------------ props

    /// Solid objects (2026-10-07, user on 170.14: 你很多这些一条条的): tarot cards, wax seals
    /// and drops, mirror shards and name cards that fly, tumble, fall and settle on the floor,
    /// drawn in colour from SpectacleProps (SpectacleProp shader) instead of bands of light.
    /// Built on the CPU each frame like Flares. A quad shows its front cell when its forward
    /// axis points away from the camera, its back cell (mirrored to read true) otherwise.
    sealed class Props : MonoBehaviour
    {
        public struct Item
        {
            public Vector3 pos, vel, axis, kick;
            public Quaternion rot;
            public float spin, size, grow, growTime, endScale;
            public float delay, life, age, peak, fadeFrom, wait;
            public float drag, gravity, sway, swayFreq, glow, glowDecay, sheen;
            public PropCell front, back;
            public Color tint;
            /// Keeps facing the camera; spin then rolls it in the screen plane from rollStart
            /// (degrees; 0 keeps the cell's top up), or rollCourse(u) while it flies its course.
            public bool faceCam;
            public float rollStart;
            public Func<float, float> rollCourse;
            /// Stands upright facing the camera (world up stays up): spikes out of the ground.
            public bool upright;
            /// Seconds it keeps spinning once free (0: for its whole life).
            public float spinFor;
            public bool kicked, landed;
            /// Lies on the floor at this height once it falls to it (NaN: falls through).
            public float floor;
            /// Flies this course first (u 0..1 over 'travel' seconds), then stops where it ends
            /// (carry: flies on with the course's last velocity instead).
            public Func<float, Vector3> course;
            public float travel;
            public bool carry, arrived;
            /// Inner flow (SpectacleProp shader): 0 none, 1 smoke, 2 fire, 3 light streak, 4 petals.
            /// Set from the cell when the item is added unless already given.
            public int flow;
            /// 1: the shader cuts the painted light into hard colour bands (2XKO look, 2026-10-08).
            public float rim;
        }

        SpellSpectacle20260926 owner;
        bool reported;
        readonly List<Item> items = new List<Item>();
        /// One dynamic mesh per atlas: the drawn props (8x8) and the painted ones (4x4).
        sealed class Buffer
        {
            public Mesh mesh;
            public readonly List<Vector3> verts = new List<Vector3>(), normals = new List<Vector3>();
            public readonly List<Vector2> uvA = new List<Vector2>(), uvB = new List<Vector2>();
            public readonly List<Vector4> uvC = new List<Vector4>(), uvD = new List<Vector4>();
            public readonly List<Color> cols = new List<Color>();
            public readonly List<int> tris = new List<int>();
            public void Clear() { verts.Clear(); normals.Clear(); uvA.Clear(); uvB.Clear(); uvC.Clear(); uvD.Clear(); cols.Clear(); tris.Clear(); }
            public void Upload()
            {
                mesh.Clear();
                mesh.SetVertices(verts); mesh.SetNormals(normals); mesh.SetColors(cols);
                mesh.SetUVs(0, uvA); mesh.SetUVs(1, uvB); mesh.SetUVs(2, uvC); mesh.SetUVs(3, uvD);
                mesh.SetTriangles(tris, 0);
                mesh.bounds = new Bounds(Vector3.zero, Vector3.one * 200f);
            }
        }
        readonly Buffer drawn = new Buffer(), painted = new Buffer();

        static Mesh Layer(GameObject go, string name, Material material)
        {
            var mesh = new Mesh { name = name };
            mesh.MarkDynamic();
            go.AddComponent<MeshFilter>().sharedMesh = mesh;
            var r = go.AddComponent<MeshRenderer>();
            r.sharedMaterial = material;
            r.shadowCastingMode = UnityEngine.Rendering.ShadowCastingMode.Off;
            r.receiveShadows = false;
            return mesh;
        }

        public static Props Create(Transform parent, Material material, SpellSpectacle20260926 owner)
        {
            var go = new GameObject("SpectacleProps");
            go.transform.SetParent(parent, false);
            var p = go.AddComponent<Props>();
            p.owner = owner;
            owner.live++;
            p.drawn.mesh = Layer(go, "SpectaclePropMesh", material);
            var paint = new GameObject("painted");
            paint.transform.SetParent(go.transform, false);
            p.painted.mesh = Layer(paint, "SpectaclePaintMesh", owner.paintMaterial);
            return p;
        }

        public static Item New(PropCell front, PropCell back, Vector3 pos, float size, float delay, float life) => new Item
        {
            front = front, back = back, pos = pos, size = size, delay = delay, life = life, rot = Quaternion.identity, axis = Vector3.up,
            grow = 1f, growTime = .1f, endScale = 1f, peak = .05f, fadeFrom = .6f, tint = Color.white, floor = float.NaN, glowDecay = .2f, swayFreq = 7f,
        };

        /// Drawn props that have a painted version are drawn with it (the painted sword, axe,
        /// hammer, chain link, coin, petal and sword qi replace the clip-art ones everywhere).
        public void Add(Item item)
        {
            item.front = Painted(item.front); item.back = Painted(item.back);
            if (item.flow == 0) item.flow = Flow(item.front);
            items.Add(item);
        }

        /// Painted matter that must never read as a still picture flows from within.
        static int Flow(PropCell c) => c switch
        {
            PropCell.PSmokeA or PropCell.PSmokeB or PropCell.PSmokeC or PropCell.PSmokeB2 or PropCell.PSmokeC2 => 1,
            PropCell.PFire => 2,
            PropCell.PClaw or PropCell.PQi => 3,
            PropCell.PLotus or PropCell.PPetal => 4,
            _ => 0,
        };

        static PropCell Painted(PropCell c) => c switch
        {
            PropCell.Sword => PropCell.PSword, PropCell.Axe => PropCell.PAxe, PropCell.Hammer => PropCell.PHammer,
            PropCell.ChainLink => PropCell.PChain, PropCell.Coin => PropCell.PCoin, PropCell.Petal => PropCell.PPetal,
            PropCell.Qi => PropCell.PQi, _ => c,
        };

        static Rect Cell(PropCell c)
        {
            int i = (int)c;
            if (i >= 100) { i -= 100; return new Rect((i % 4) * .25f, 1f - (i / 4 + 1) * .25f, .25f, .25f); }
            return new Rect((i % 8) * .125f, 1f - (i / 8 + 1) * .125f, .125f, .125f);
        }

        static float EaseOutBack(float x) { const float c1 = 1.70158f, c3 = c1 + 1f; x -= 1f; return 1f + c3 * x * x * x + c1 * x * x; }

        void LateUpdate()
        {
            float dt = Time.deltaTime;
            var cam = Camera.main;
            if (!cam) return;
            Vector3 camF = cam.transform.forward, camU = cam.transform.up, camR = cam.transform.right;
            int alive = 0;
            drawn.Clear(); painted.Clear();
            var origin = transform.position;
            for (int i = 0; i < items.Count; i++)
            {
                var m = items[i];
                m.age += dt;
                float t = m.age - m.delay;
                if (t >= m.life) { items[i] = m; continue; }
                alive++;
                if (t < 0) { items[i] = m; continue; }
                bool flying = m.course != null && t < m.travel;
                if (flying)
                {
                    var next = m.course(Mathf.Clamp01(t / m.travel));
                    if (dt > 1e-5f) m.vel = (next - m.pos) / dt;
                    m.pos = next;
                }
                else if (t >= m.wait && !m.landed)
                {
                    if (m.course != null && !m.arrived) { m.arrived = true; if (!m.carry) m.vel = Vector3.zero; }
                    if (!m.kicked) { m.kicked = true; m.vel += m.kick; }
                    m.vel *= Mathf.Exp(-m.drag * dt);
                    m.vel += Vector3.down * m.gravity * dt;
                    // A falling card flutters from side to side.
                    m.pos += (m.vel + camR * (Mathf.Sin(t * m.swayFreq + m.sheen * 6f) * m.sway)) * dt;
                    if (!float.IsNaN(m.floor) && m.pos.y <= m.floor) { m.pos.y = m.floor; m.vel = Vector3.zero; m.landed = true; }
                }
                if (m.faceCam)
                {
                    float roll = m.rollCourse != null ? m.rollCourse(Mathf.Clamp01(m.travel > 0 ? t / m.travel : 1f)) + (m.travel > 0 && t > m.travel ? m.spin * (t - m.travel) : 0f)
                                                      : m.rollStart + m.spin * t;
                    m.rot = Quaternion.LookRotation(camF, camU) * Quaternion.AngleAxis(roll, Vector3.forward);
                }
                else if (m.upright)
                {
                    var flat = camF; flat.y = 0f;
                    m.rot = Quaternion.LookRotation(flat.sqrMagnitude > 1e-4f ? flat.normalized : Vector3.forward, Vector3.up) * Quaternion.AngleAxis(m.rollStart, Vector3.forward);
                }
                else if (m.landed)
                {
                    // Settles flat on the floor, keeping whichever side it shows.
                    var n = m.rot * Vector3.forward;
                    var flat = Quaternion.FromToRotation(n, n.y > 0 ? Vector3.up : Vector3.down) * m.rot;
                    m.rot = Quaternion.Slerp(m.rot, flat, 1f - Mathf.Exp(-14f * dt));
                }
                else if (m.spin != 0f && (flying || t >= m.wait) && (m.spinFor <= 0f || t < m.wait + m.spinFor)) m.rot = Quaternion.AngleAxis(m.spin * dt, m.axis) * m.rot;
                items[i] = m;

                float k = t / m.life;
                float scale = (m.growTime > 0 ? Mathf.LerpUnclamped(m.grow, 1f, EaseOutBack(Mathf.Clamp01(t / m.growTime))) : 1f) * Mathf.Lerp(1f, m.endScale, k);
                // Fades over the last (1 - fadeFrom) of its life. (Mathf.SmoothStep interpolates
                // between its first two arguments; it is not a smoothstep of k.)
                float fade = Mathf.Clamp01((k - m.fadeFrom) / Mathf.Max(.001f, 1f - m.fadeFrom));
                float alpha = Mathf.Clamp01(t / Mathf.Max(.01f, m.peak)) * (1f - fade * fade * (3f - 2f * fade));
                if (alpha <= .002f || scale <= 0f) continue;
                float half = m.size * scale * .5f;
                // A tumbling flat object is never drawn fully edge-on: edge-on it is a sliver, and
                // a shower of slivers reads as lines again. It is turned part way to face the camera.
                var drawRot = m.rot;
                if (!m.faceCam && !m.upright)
                {
                    var n0 = m.rot * Vector3.forward;
                    var face = Quaternion.LookRotation(Vector3.Dot(n0, camF) >= 0f ? camF : -camF, m.rot * Vector3.up);
                    drawRot = Quaternion.Slerp(m.rot, face, .45f);
                }
                Vector3 ax = drawRot * Vector3.right * half, ay = drawRot * Vector3.up * half, nrm = drawRot * Vector3.forward;
                var c = m.pos - origin;
                var col = m.tint; col.a = alpha;
                float glow = m.glow * Mathf.Exp(-t / Mathf.Max(.02f, m.glowDecay));
                Rect f = Cell(m.front), b = Cell(m.back);
                var buf = (int)m.front >= 100 ? painted : drawn;
                int v0 = buf.verts.Count;
                buf.verts.Add(c - ax - ay); buf.verts.Add(c - ax + ay); buf.verts.Add(c + ax + ay); buf.verts.Add(c + ax - ay);
                for (int q = 0; q < 4; q++) { buf.normals.Add(nrm); buf.cols.Add(col); }
                buf.uvA.Add(new Vector2(f.xMin, f.yMin)); buf.uvA.Add(new Vector2(f.xMin, f.yMax)); buf.uvA.Add(new Vector2(f.xMax, f.yMax)); buf.uvA.Add(new Vector2(f.xMax, f.yMin));
                buf.uvB.Add(new Vector2(b.xMax, b.yMin)); buf.uvB.Add(new Vector2(b.xMax, b.yMax)); buf.uvB.Add(new Vector2(b.xMin, b.yMax)); buf.uvB.Add(new Vector2(b.xMin, b.yMin));
                float sh = m.sheen + t * 1.6f;
                buf.uvC.Add(new Vector4(glow, sh, 0, 0)); buf.uvC.Add(new Vector4(glow, sh, 0, 1)); buf.uvC.Add(new Vector4(glow, sh, 1, 1)); buf.uvC.Add(new Vector4(glow, sh, 1, 0));
                // Flow mode with a per-item seed in its fraction, so no two clouds move alike.
                var flash = new Vector4(m.faceCam || m.upright ? 0f : 1f, m.flow + Mathf.Repeat(i * .6180339f + m.sheen, .999f), m.rim, 0f);
                buf.uvD.Add(flash); buf.uvD.Add(flash); buf.uvD.Add(flash); buf.uvD.Add(flash);
                buf.tris.Add(v0); buf.tris.Add(v0 + 1); buf.tris.Add(v0 + 2); buf.tris.Add(v0); buf.tris.Add(v0 + 2); buf.tris.Add(v0 + 3);
            }
            if (alive == 0) { Destroy(gameObject); return; }
            if (Diagnostics && !reported && drawn.verts.Count + painted.verts.Count > 0) { reported = true; Debug.Log($"SPELLPROPS t={Time.unscaledTime:F3} items={items.Count} drawn={drawn.verts.Count / 4} painted={painted.verts.Count / 4}"); }
            drawn.Upload(); painted.Upload();
        }

        void OnDestroy()
        {
            if (owner) owner.live--;
            if (drawn.mesh) Destroy(drawn.mesh);
            if (painted.mesh) Destroy(painted.mesh);
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

    /// Full-screen darkening of the backdrop only (SpectacleDim, queue 1500): in fast, holds a
    /// beat, eases back over about 0.4 s. A new hit inside the tail keeps the darker value.
    sealed class Dim : MonoBehaviour
    {
        SpellSpectacle20260926 owner;
        MeshRenderer meshRenderer;
        MaterialPropertyBlock block;
        Mesh mesh;
        float age = 99, amount;
        Vector3 centre;

        public static Dim Create(Transform parent, Material material, SpellSpectacle20260926 owner)
        {
            var go = new GameObject("SpectacleDim");
            go.transform.SetParent(parent, false);
            var d = go.AddComponent<Dim>();
            d.owner = owner;
            d.mesh = new Mesh { name = "SpectacleDimQuad" };
            d.mesh.vertices = new[] { new Vector3(0, 0, 0), new Vector3(0, 1, 0), new Vector3(1, 1, 0), new Vector3(1, 0, 0) };
            d.mesh.uv = new[] { new Vector2(0, 0), new Vector2(0, 1), new Vector2(1, 1), new Vector2(1, 0) };
            d.mesh.triangles = new[] { 0, 1, 2, 0, 2, 3 };
            d.mesh.bounds = new Bounds(Vector3.zero, Vector3.one * 100000f);
            go.AddComponent<MeshFilter>().sharedMesh = d.mesh;
            d.meshRenderer = go.AddComponent<MeshRenderer>();
            d.meshRenderer.sharedMaterial = material;
            d.meshRenderer.shadowCastingMode = UnityEngine.Rendering.ShadowCastingMode.Off;
            d.meshRenderer.receiveShadows = false;
            d.meshRenderer.enabled = false;
            d.block = new MaterialPropertyBlock();
            return d;
        }

        static float Envelope(float t) => t < .04f ? t / .04f : t < .14f ? 1f : Mathf.Exp(-(t - .14f) / .16f);

        public void Trigger(Vector3 at, float value)
        {
            float current = age > 2f ? 0f : amount * Envelope(age);
            amount = Mathf.Max(value, current);
            // Re-triggered while the backdrop is still dark: restart at the hold (Envelope = 1)
            // rather than the 40 ms climb from 0, or a combo brightens it for a frame or two
            // before pressing down again. Once the quad is off again, climb as before.
            age = current > 0f && meshRenderer.enabled ? .04f : 0f;
            centre = at; meshRenderer.enabled = true;
        }

        void LateUpdate()
        {
            age += Time.deltaTime;
            if (age > .9f) { meshRenderer.enabled = false; return; }
            block.SetVector("_Center", centre);
            block.SetFloat("_Amount", amount * Envelope(age));
            block.SetFloat("_Radius", .34f);
            meshRenderer.SetPropertyBlock(block);
        }

        void OnDestroy()
        {
            if (owner && owner.dim == this) owner.dim = null;
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
        ["mask"] = P("mask", Family.Fan, Family.Fan, Style.Control, new[] { "#0a3a66", "#1f8ad6", "#3ad6e8", "#a57bff", "#f0f4ff" }, "#dff8ff", "#ffffff", "#2aa6c8", "#e8fbff", Mote.Shard, Mote.Wisp, Matter.Crystal, Accent.None, false, 1f, 0f, Form.Edict),
        ["identity"] = P("identity", Family.Fan, Family.Fan, Style.Control, new[] { "#1a4dff", "#46b8ff", "#f4f1ff", "#ffb04a", "#ff6a1f" }, "#ffe0a0", "#ffffff", "#3b6cff", "#ffe6c2", Mote.Card, Mote.Wisp, Matter.Smoke, Accent.None, false, 1f, 0f, Form.Swap),
        // Forged evidence: a red wax seal thrown on a low arc, slammed onto the target, splashing forward.
        ["seal"] = P("seal", Family.Falling, Family.Falling, Style.Strike, new[] { "#1a0306", "#5a0a12", "#a3141f", "#e0392b", "#ffb36b" }, "#ffcf8a", "#fff0d8", "#a3141f", "#ffd0a0", Mote.Ember, Mote.Ink, Matter.Flame, Accent.Cracks, false, 1f, 0f, Form.Throw),
        // Twin pursuit: two violet shadows run low at the target; the second bites.
        ["chase"] = P("chase", Family.Twin, Family.Twin, Style.Strike, new[] { "#1d0b33", "#43186e", "#8a3dff", "#c77dff", "#f3e0ff" }, "#d6a8ff", "#f6e8ff", "#43186e", "#e6c2ff", Mote.Wisp, Mote.Spark, Matter.Smoke, Accent.None, false, 1f, 0f, Form.Hunt),
        // Absurd finale: a volley of stage props rains onto the target, a spotlight rises, curtains close.
        ["climax"] = P("climax", Family.Crescent, Family.Crescent, Style.Heavy, Rainbow, "#ffd24a", "#fff8e0", "#ff4a14", "#ffe39a", Mote.Card, Mote.Spark, Matter.Filigree, Accent.None, false, 1f, 0f, Form.Rain),
        ["reversal"] = P("reversal", Family.Curtain, Family.Curtain, Style.Strike, new[] { "#3a0640", "#a81f86", "#ff4fae", "#ffb04a", "#6a3cff" }, "#ffd07a", "#ffe6f4", "#c2289a", "#ffd4ec", Mote.Petal, Mote.Spark, Matter.Silk, Accent.None, false, 1f, 0f, Form.Reverse),
        ["ward"] = P("ward", Family.Rising, Family.Rising, Style.Support, new[] { "#0b5a8a", "#39c6ff", "#8ae0ff", "#ffd66b", "#ffffff" }, "#fff0b0", "#ffffff", "#2a9fe0", "#e6f8ff", Mote.Wisp, Mote.Spark, Matter.Water, Accent.None, false, 1f, 0f, Form.Rewrite),
        // The hero's defend keeps the old ward bloom; the ward card (后手改写) now lands on the hero as a form.
        ["defend"] = P("defend", Family.Rising, Family.Rising, Style.Support, new[] { "#0b5a8a", "#39c6ff", "#8ae0ff", "#ffd66b", "#ffffff" }, "#fff0b0", "#ffffff", "#2a9fe0", "#e6f8ff", Mote.Wisp, Mote.Spark, Matter.Water, Accent.None, false, 1f, 0.04f),
        ["declaration"] = P("declaration", Family.Rising, Family.Rising, Style.Heavy, new[] { "#2b1466", "#6a3cff", "#c07aff", "#ffcf6a", "#fff4dc" }, "#ffd76a", "#fffaf0", "#6f3cff", "#fff0cc", Mote.Card, Mote.Shard, Matter.Filigree, Accent.None, false, 1f, 0f, Form.Proclaim),

        // Ramps end saturated (2026-10-14): the cast light multiplies their light end by 1.35, and the
        // cream / white ends Codex gave these three blew the hero out white at the cast.
        ["tempo"] = P("tempo", Family.Fan, Family.Rising, Style.Support, new[] { "#4a2004", "#a85a0a", "#e8860e", "#ffaa22", "#ffc040" }, "#ffcb59", "#fff1c2", "#a76a13", "#ffe7a0", Mote.Glint, Mote.Spark, Matter.Filigree, Accent.ClockHands, false, .75f, 0f),
        ["barrage"] = P("barrage", Family.MirrorCut, Family.Fan, Style.Strike, new[] { "#0a2f5a", "#1a6ab8", "#2ecbf5", "#7fe4ff", "#bdf4ff" }, "#aef4ff", "#ffffff", "#448b9b", "#defbff", Mote.Shard, Mote.Glint, Matter.Crystal, Accent.Needles, false, .6f, 0f),
        ["signature"] = P("signature", Family.Falling, Family.Surge, Style.Heavy, new[] { "#1a0e10", "#4a1a0e", "#b8400c", "#ff7a1e", "#ffb648" }, "#e4c99b", "#fff0cb", "#5f4f48", "#ffc074", Mote.Ink, Mote.Ember, Matter.Ink, Accent.Cracks, false, .8f, 0f, Form.Flick),

        // Mainline enemies.
        ["guard"] = P("guard", Family.Twin, Family.Twin, Style.Strike, new[] { "#4a0610", "#c01a24", "#ff5a1e", "#ffc23a", "#fff0c0" }, "#ffcf6a", "#fff1d6", "#d8341c", "#ffd9a8", Mote.Spark, Mote.Ember, Matter.Flame, Accent.FlyingSwords),
        ["archivist"] = P("archivist", Family.Falling, Family.Twin, Style.Strike, new[] { "#081a3a", "#1a4fb8", "#2a9aff", "#ffb02a", "#fff0c0" }, "#ffd27a", "#f4fbff", "#2f86e0", "#dff4ff", Mote.Spark, Mote.Shard, Matter.Electric, Accent.Lightning),
        ["fog-ghost"] = P("fog-ghost", Family.Tide, Family.Surge, Style.Strike, new[] { "#0a1f4f", "#1f66c8", "#2fc8ff", "#8a7bff", "#e6fdff" }, "#bff6ff", "#f2feff", "#1d6fd8", "#dcfbff", Mote.Wisp, Mote.Puff, Matter.Water, Accent.Foam, false, 1f, 0.06f),
        ["crimson-ghost"] = P("crimson-ghost", Family.Surge, Family.Tide, Style.Strike, new[] { "#3a0620", "#b0124a", "#ff4f7a", "#a04cff", "#ffd0dc" }, "#ffc0cf", "#fff0f4", "#c01848", "#ffd6e0", Mote.Wisp, Mote.Puff, Matter.Smoke, Accent.Chains),
        ["early-hound"] = P("early-hound", Family.Rising, Family.Surge, Style.Light, new[] { "#3a0602", "#c41a06", "#ff6a0a", "#ffb81f", "#fff0a0" }, "#ffd35a", "#fff3d0", "#ff4a0c", "#ffd08a", Mote.Ember, Mote.Spark, Matter.Flame, Accent.ClawRake),
        ["hound"] = P("hound", Family.Surge, Family.Tide, Style.Strike, new[] { "#4a0a04", "#d62a0a", "#ff7a14", "#ffc93a", "#fff2b0" }, "#ffd35a", "#fff3d0", "#ff4a0c", "#ffd08a", Mote.Ember, Mote.Spark, Matter.Flame, Accent.Phoenix),
        ["magma"] = P("magma", Family.Tide, Family.Falling, Style.Heavy, new[] { "#1a0402", "#8a1206", "#ff4a0a", "#ffa21f", "#fff0a0" }, "#ffc24a", "#fff0c8", "#ff3a08", "#ffc070", Mote.Ember, Mote.Shard, Matter.Flame, Accent.Cracks),
        // Smaller (.7): its straight spires landing on the hero, close to the camera, filled the whole screen (169.70).
        ["emerald"] = P("emerald", Family.Rising, Family.Fan, Style.Heavy, new[] { "#032a1a", "#0e8a4a", "#3cff8a", "#c8ff5a", "#fff6b0" }, "#d8ff7a", "#f4ffe0", "#16c85a", "#e2ffc0", Mote.Ember, Mote.Puff, Matter.Flame, Accent.Spikes, false, .7f),
        ["mind"] = P("mind", Family.Fan, Family.Fan, Style.Strike, new[] { "#06202a", "#127a8a", "#5ae0e8", "#e0f8ff", "#ffd88a" }, "#ffe6a8", "#ffffff", "#1a9aaa", "#e0fbff", Mote.Card, Mote.Wisp, Matter.Smoke, Accent.ClockHands),
        ["leech"] = P("leech", Family.Surge, Family.Rising, Style.Strike, new[] { "#200a3a", "#7a1fae", "#d85cff", "#ffd0f4", "#9fe8ff" }, "#f2c6ff", "#fff0ff", "#8a28c8", "#f6dcff", Mote.Card, Mote.Ink, Matter.Ink, Accent.Vortex),
        ["scribe"] = P("scribe", Family.Surge, Family.Twin, Style.Strike, new[] { "#12041f", "#4a148a", "#a33cff", "#ff5fb0", "#ffd36a" }, "#ffcf5a", "#f8e8ff", "#7a22d0", "#f0d4ff", Mote.Ink, Mote.Spark, Matter.Ink, Accent.Splatter),
        ["executor"] = P("executor", Family.Twin, Family.Surge, Style.Heavy, new[] { "#120a04", "#5a3208", "#d68a14", "#ffd24a", "#fff6d0" }, "#ffe08a", "#fff8e8", "#d87a10", "#ffe2a8", Mote.Ink, Mote.Spark, Matter.Ink, Accent.ExecutionAxe),
        ["chronarch"] = P("chronarch", Family.Falling, Family.Fan, Style.Heavy, new[] { "#1a0e04", "#8a4a12", "#e8a02e", "#3ad6c0", "#e8fff8" }, "#ffd76a", "#fff4d8", "#e0821a", "#ffe4a8", Mote.Shard, Mote.Card, Matter.Filigree, Accent.Dragon, true, 1.08f),
        ["matriarch"] = P("matriarch", Family.Curtain, Family.Twin, Style.Strike, new[] { "#3a0412", "#c0142e", "#ff4f6a", "#ff9ab0", "#f4f6ff" }, "#f4f6ff", "#ffffff", "#d01a3a", "#ffd8e0", Mote.Petal, Mote.Shard, Matter.Silk, Accent.Needles),
        ["rescue"] = P("rescue", Family.Fan, Family.Falling, Style.Strike, new[] { "#3a1a04", "#b86a14", "#ffb23a", "#ffd86a", "#ffffff" }, "#ffe08a", "#fff8e8", "#e08a1a", "#ffe6b8", Mote.Puff, Mote.Spark, Matter.Smoke, Accent.Meteor),
        ["adjudicator"] = P("adjudicator", Family.Falling, Family.Falling, Style.Heavy, new[] { "#0a1426", "#2a4a7a", "#6aa0e0", "#e8f0ff", "#ffd36a" }, "#ffd36a", "#f4f8ff", "#2a5ab0", "#dce8ff", Mote.Shard, Mote.Puff, Matter.Crystal, Accent.JudgmentSword, false, 1.08f),
        ["convoy"] = P("convoy", Family.Tide, Family.Tide, Style.Heavy, new[] { "#1a0a06", "#5a2410", "#b8501a", "#ff8a3a", "#ffd8a0" }, "#ffb86a", "#fff0dc", "#b84a14", "#ffd0a0", Mote.Shard, Mote.Puff, Matter.Smoke, Accent.Hammer, false, 1.08f),
        ["elite"] = P("elite", Family.Twin, Family.Falling, Style.Heavy, new[] { "#3a0608", "#b81a1a", "#ff6a2a", "#ffd24a", "#fff8e0" }, "#ffd35a", "#fff6e0", "#e0301a", "#ffd4a0", Mote.Spark, Mote.Shard, Matter.Crystal, Accent.SwordRain, true),

        // Church tower beasts.
        ["stonehide"] = P("stonehide", Family.Falling, Family.Falling, Style.Heavy, new[] { "#1a1006", "#6a4a1a", "#d69a3a", "#ffe08a", "#fff8e0" }, "#ffd87a", "#fff6e0", "#c87a2a", "#ffe0b0", Mote.Shard, Mote.Puff, Matter.Crystal, Accent.Cracks),
        ["saltmaw"] = P("saltmaw", Family.Rising, Family.Fan, Style.Strike, new[] { "#0a2a3a", "#2ab8d6", "#e8ffff", "#ff9ad6", "#b58cff" }, "#ffffff", "#ffffff", "#2ab0d0", "#eaffff", Mote.Shard, Mote.Spark, Matter.Crystal, Accent.Spikes),
        ["salt-poison"] = P("salt-poison", Family.Tide, Family.Tide, Style.Strike, new[] { "#062a1a", "#1a8a5a", "#6affb0", "#e8ffd0", "#c8ffff" }, "#e0fff0", "#ffffff", "#1aa86a", "#e0ffe8", Mote.Puff, Mote.Ember, Matter.Smoke, Accent.Orbit, false, 1f, 0.04f),
        ["shellback"] = P("shellback", Family.Twin, Family.Surge, Style.Strike, new[] { "#2a0a06", "#8a2a12", "#e86a2a", "#ffc24a", "#fff0c8" }, "#ffd06a", "#fff2dc", "#d8501a", "#ffd8a8", Mote.Spark, Mote.Shard, Matter.Smoke, Accent.Shards),
        ["ironclaw"] = P("ironclaw", Family.Twin, Family.Twin, Style.Strike, new[] { "#0a1a2a", "#2a6ab8", "#5ad0ff", "#ffc24a", "#ffffff" }, "#ffe08a", "#ffffff", "#3a8ad0", "#e6f8ff", Mote.Spark, Mote.Shard, Matter.Crystal, Accent.SwordQi),
        ["frilled-naga"] = P("frilled-naga", Family.Fan, Family.Surge, Style.Strike, new[] { "#2a1a04", "#b8861a", "#ffd24a", "#fff6c0", "#4ae0c0" }, "#fff0a0", "#fffbe8", "#e0a01a", "#fff0b8", Mote.Wisp, Mote.Spark, Matter.Electric, Accent.None, true, 1f, 0.1f),
        ["boneclaw"] = P("boneclaw", Family.Crescent, Family.Twin, Style.Strike, new[] { "#0a2a2a", "#1aa8a0", "#7ae0c8", "#c8b0ff", "#ffffff" }, "#f4f0d8", "#ffffff", "#18a09a", "#eafff8", Mote.Shard, Mote.Spark, Matter.Crystal, Accent.ClawRake),
        ["copperback"] = P("copperback", Family.Tide, Family.Falling, Style.Strike, new[] { "#1a0a04", "#8a3a12", "#e8782a", "#ffc86a", "#4ad6b8" }, "#ffd07a", "#fff2dc", "#d86a1a", "#ffdcaa", Mote.Shard, Mote.Spark, Matter.Crystal, Accent.Cracks),
        ["crimson-brute"] = P("crimson-brute", Family.Falling, Family.Surge, Style.Heavy, new[] { "#2a0404", "#b80c0c", "#ff4a14", "#ffb22a", "#fff0b0" }, "#ffcf4a", "#fff2d0", "#ff300c", "#ffc890", Mote.Ember, Mote.Spark, Matter.Flame, Accent.Meteor),
        ["veil-oracle"] = P("veil-oracle", Family.Curtain, Family.Twin, Style.Strike, new[] { "#2a0418", "#a0124a", "#ff3a6a", "#ffb0c8", "#ffe0a0" }, "#ffd8a0", "#fff0f4", "#c8124a", "#ffd0dc", Mote.Petal, Mote.Wisp, Matter.Silk, Accent.Vortex),
        ["golden-throat"] = P("golden-throat", Family.Fan, Family.Tide, Style.Strike, new[] { "#2a2a04", "#8ab81a", "#e8ff4a", "#ffd24a", "#fff8d0" }, "#fff0a0", "#fffbe0", "#b8d01a", "#fff4b0", Mote.Puff, Mote.Wisp, Matter.Smoke, Accent.Orbit, false, 1f, 0.12f),
        ["moonfang"] = P("moonfang", Family.Crescent, Family.Twin, Style.Strike, new[] { "#0a0a2a", "#3a4ab8", "#7a9cff", "#ffe08a", "#ffffff" }, "#f4f6ff", "#ffffff", "#4a5ad0", "#eef2ff", Mote.Spark, Mote.Shard, Matter.Smoke, Accent.Tornado),

        // Wanted bosses.
        ["bounty-b01"] = P("bounty-b01", Family.Twin, Family.Twin, Style.Heavy, new[] { "#2a0408", "#9a1020", "#e8484a", "#9ab0d0", "#ffffff" }, "#f0f4ff", "#ffffff", "#c01a24", "#ffd8d8", Mote.Spark, Mote.Shard, Matter.Crystal, Accent.SwordQi),
        ["bounty-b02"] = P("bounty-b02", Family.Rising, Family.Falling, Style.Heavy, new[] { "#2a1804", "#a8741a", "#ffc83a", "#fff2b0", "#ffffff" }, "#ffe08a", "#fffbe8", "#e0a01a", "#fff0c0", Mote.Card, Mote.Spark, Matter.Filigree, Accent.Chains, true),
        ["bounty-b03"] = P("bounty-b03", Family.Tide, Family.Surge, Style.Heavy, new[] { "#041a3a", "#0a5aa0", "#1fc8e0", "#6ae8ff", "#ffffff" }, "#e0ffff", "#ffffff", "#0a7ac8", "#dcfaff", Mote.Puff, Mote.Spark, Matter.Water, Accent.Foam, false, 1f, 0.05f),
        ["bounty-b04"] = P("bounty-b04", Family.Fan, Family.Surge, Style.Heavy, new[] { "#0e0418", "#3a148a", "#8a3cff", "#ff8a3a", "#ffe08a" }, "#ffcf6a", "#f8ecff", "#6a22d0", "#f0dcff", Mote.Ink, Mote.Card, Matter.Ink, Accent.Orbit),
        ["bounty-b05"] = P("bounty-b05", Family.Twin, Family.Curtain, Style.Strike, new[] { "#2a0206", "#b00a1e", "#ff3a4a", "#ffc0c8", "#ffe8a0" }, "#ffd0a0", "#fff0f0", "#d0101e", "#ffd0d4", Mote.Petal, Mote.Spark, Matter.Silk, Accent.Tornado),
        ["bounty-b06"] = P("bounty-b06", Family.Falling, Family.Tide, Style.Heavy, new[] { "#040e1f", "#12386a", "#3a8ab8", "#bfe8f8", "#ffffff" }, "#dff4ff", "#ffffff", "#1a5a9a", "#dcefff", Mote.Shard, Mote.Puff, Matter.Water, Accent.Cracks, false, 1.08f),
        ["bounty-b07"] = P("bounty-b07", Family.Fan, Family.Tide, Style.Strike, new[] { "#2a1a02", "#c8861a", "#ffc83a", "#9aff5a", "#fff8d0" }, "#fff0a0", "#fffbe0", "#e0a01a", "#fff0b8", Mote.Wisp, Mote.Puff, Matter.Electric, Accent.Lightning, true, 1f, 0.1f),
        ["bounty-b08"] = P("bounty-b08", Family.Twin, Family.Twin, Style.Heavy, new[] { "#5a6aa8", "#ff7ac0", "#7ad0ff", "#c89cff", "#ffffff" }, "#ffffff", "#ffffff", "#8a9ac8", "#f4f8ff", Mote.Shard, Mote.Spark, Matter.Crystal, Accent.SwordRain),
        ["bounty-b09"] = P("bounty-b09", Family.Crescent, Family.Surge, Style.Heavy, new[] { "#1a0804", "#7a2a0a", "#d8661a", "#ffc24a", "#fff0c0" }, "#ffd06a", "#fff4e0", "#c8501a", "#ffd8a0", Mote.Shard, Mote.Ember, Matter.Flame, Accent.ClawRake),
        ["bounty-b10"] = P("bounty-b10", Family.Curtain, Family.Crescent, Style.Heavy, new[] { "#2a0212", "#a00a3a", "#ff2a5a", "#ff9ab8", "#ffe0a0" }, "#ffd0a0", "#fff0f4", "#d0103a", "#ffd0dc", Mote.Petal, Mote.Wisp, Matter.Silk, Accent.Wings, false, 1.08f),

        // Support semantics.
        ["heal"] = P("heal", Family.Rising, Family.Rising, Style.Support, new[] { "#0a4a3a", "#1ac89a", "#6affc8", "#ffe08a", "#ffffff" }, "#fff0b0", "#ffffff", "#18b88a", "#e0fff4", Mote.Petal, Mote.Spark, Matter.Water, Accent.Lotus, false, 1f, 0.04f),
        ["heal-tower"] = P("heal-tower", Family.Rising, Family.Rising, Style.Support, new[] { "#0a4a3a", "#1ac89a", "#6affc8", "#ffe08a", "#ffffff" }, "#fff0b0", "#ffffff", "#18b88a", "#e0fff4", Mote.Petal, Mote.Spark, Matter.Water, Accent.Lotus, false, 1f, 0.04f),
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
            "defend" => "defend",
            "fool_skill_01" => "sidestep",
            "fool_skill_02" => "mask",
            "fool_skill_04" => "identity",
            "fool_skill_05" => "seal",
            "fool_skill_06" => "chase",
            "fool_skill_07" => "climax",
            "fool_skill_08" => "reversal",
            "fool_skill_09" => "ward",
            "fool_skill_10" => "declaration",
            "fool_skill_11" => "tempo",
            "fool_skill_12" => "barrage",
            "fool_skill_13" => "signature",
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
        if (intent == "tower_mend" && !crimsonBoss) return Profiles["heal-tower"];
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
