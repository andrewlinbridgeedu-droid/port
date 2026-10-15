using System;
using System.Collections.Generic;
using UnityEngine;

// The three cards of the ordered loop (2026-10-14, user: 做三张新牌的命中设计), each drawn from
// its own card art: 抢拍开幕 (fool_skill_11, "tempo") is the shattered golden hourglass - gold
// sand thrown up over the hero and falling away to both sides like a curtain drawn open, then
// sifting off the figure for the 3.2 s haste; 碎镜连弹 (fool_skill_12, "barrage") is the broken
// mirror - every shot a shard streaking in, a hard cyan flash and its light split into prism
// colours; 延时落款 (fool_skill_13, "signature") is the letter bomb - a stain of black ink left on
// the target with a fuse burning down for the rules' 2.6 s, then the stain tears apart in fire and
// smoke, smaller on the two it splashes. Ink, fire and smoke are the user's painted cells (31 ink
// splash inked black, 14 fire, 7 smoke); the hourglass, shards and letter are to be the user's
// paintings too (docs/development/SPELL_CARDS_11_13_ART_REQUEST_20261014.md) - until they exist
// only the light is drawn for those. Hits come only from contact receipts: the cast's own
// contact, then the rules' later shots and the blast (BattlePrototype.PresentOrderedImpact).
public sealed partial class SpellSpectacle20260926
{
    static bool IsOrderedCard(string id) => id is "tempo" or "barrage" or "signature";

    readonly List<Ink2D> fuses = new List<Ink2D>();
    Texture2D paintAtlas4; Material paintFlipMaterial6;
    /// Cells of SpectaclePaint4 (tools/vfx-spectacle-20260926/paint_atlas.py CELLS4).
    const int CellHourglass = 200, CellGoldSand = 201, CellShardA = 202;
    bool HasCardArt => paintFlipMaterial6 != null;
    Ink2D tempoAura;

    /// At the cast: 延时落款 throws its card like the basic; 碎镜连弹 fans out its shards.
    void CardLaunch(Cue cue, float expectedContact)
    {
        if (cue.profile.id == "signature") Launch(cue, expectedContact);
        if (cue.profile.id == "barrage" && HasCardArt && expectedContact > 0f) BarrageShards(cue, expectedContact);
    }

    /// 抢拍开幕 in the user's paintings: the golden hourglass pops up beside the hero's left
    /// shoulder, flips end over end (the beat stolen) and bursts apart; its gold sand pours out
    /// down both sides and crumbles into grains. Beside him, not above: with the low camera
    /// anything over his head lands on the enemy row (probe8). Times in HitPace.
    void TempoPaint(Camera cam, Vector3 chest, float s, int seed)
    {
        var at = new Vector2(-.62f * s, .22f * s);
        float sign = (seed & 1) == 0 ? 1f : -1f, size = .75f * s;
        PaintSprite.Create(root, paintFlipMaterial, this, chest, 0f, .3f, CellHourglass, t =>
        {
            float rise = EoutSmooth(Iv(0f, .08f, t)), flip = Smooth01(Iv(.08f, .22f, t));
            return new Pose2 { off = at + new Vector2(.25f * s * (1f - rise), -.2f * s * (1f - rise)), roll = sign * 180f * flip, scale = size * (.55f + .45f * rise),
                alpha = Iv(0f, .02f, t), tint = Color.white, soft = true };
        });
        var burst = new Pose2 { off = at, roll = sign * 180f, scale = size, alpha = 1f, tint = Color.white };
        PaintPieces.Create(root, this, chest, .27f / HitPace, CellHourglass, burst, Scatter.Burst, 1.3f * s, .5f, seed + 7);
        // Three sprays (user 10-14: 沙漏的沙可以多一些): steeply down, down-left, out to the left.
        for (int side_ = 0; side_ < 3; side_++)
        {
            int side = side_;
            // The painting sprays from its lower left corner up to the right; mirrored and turned
            // both pour away from the hero (he stands to the right): one steeply down, one out to
            // the left. Pouring across him, one gilded his legs (probe9).
            float roll = side == 0 ? 118f : side == 1 ? 92f : 62f, sz = (side == 0 ? 1.3f : side == 1 ? 1.15f : 1f) * s;
            var corner = Rot2(new Vector2(.42f, -.42f) * sz, roll * Mathf.Deg2Rad);
            PaintSprite.Create(root, paintFlipMaterial, this, chest, (.24f + .04f * side) / HitPace, 1.05f, CellGoldSand, t =>
            {
                float g = EoutSmooth(Iv(0f, .2f, t)), fall = Iv(.15f, 1.05f, t);
                // Fades by crumbling into grains (_Erode), never as one picture.
                return new Pose2 { off = at - corner * (.6f + .4f * g) + Vector2.down * (.5f * s * fall * fall), roll = roll + 10f * fall,
                    scale = sz * (.6f + .4f * g), mirror = true, alpha = Iv(0f, .03f, t) * (1f - Smooth01(Iv(.35f, 1.05f, t))), tint = Color.white };
            });
        }
    }

    /// 碎镜连弹's shards, from the cast: as many as the rules will fire (three, or six inside
    /// 抢拍开幕's haste - the first contact comes after one shot's work, .6 s or .3 s, and the
    /// channel lasts 1.8 s), fanned over the hero's casting shoulder, each pointing at the
    /// target; one by one they streak in, landing on the predicted beats. The landing itself
    /// (the shard bursting, the flash) is drawn on each contact receipt.
    void BarrageShards(Cue cue, float first)
    {
        var cam = Camera.main;
        if (!cam || cue.targets.Count == 0) return;
        var chest = SafeEval(cue.caster); var target = SafeEval(cue.targets[0]);
        float half = Vector3.Distance(cam.transform.position, chest) * Mathf.Tan(cam.fieldOfView * .5f * Mathf.Deg2Rad), s = half * .13f;
        // The target as seen, carried onto the hero's depth (offsets live in the hero's plane).
        var sp = cam.WorldToScreenPoint(target); float heroDepth = cam.WorldToScreenPoint(chest).z;
        var onPlane = cam.ScreenToWorldPoint(new Vector3(sp.x, sp.y, heroDepth)) - chest;
        var tOff = new Vector2(Vector3.Dot(onPlane, cam.transform.right), Vector3.Dot(onPlane, cam.transform.up));
        float far = Mathf.Clamp(heroDepth / Mathf.Max(.1f, sp.z), .2f, 1f);   // the shard shrinks as it flies off
        int n = Mathf.Clamp(Mathf.FloorToInt((1.8f - first) / first + 1e-3f) + 1, 1, 6);
        const float Travel = .14f;
        for (int k_ = 0; k_ < n; k_++)
        {
            int k = k_;
            float arrive = first + k * first, appear = .04f * k, launch = Mathf.Max(appear + .08f, arrive - Travel);
            float fan = n == 1 ? 0f : k / (float)(n - 1);
            // A fan round the casting (right) shoulder, close to the figure: higher up they sat
            // at the enemy's feet in one slanted line (probe8).
            float a = Mathf.Lerp(15f, 80f, fan) * Mathf.Deg2Rad;
            Vector2 shoulder = new Vector2(.35f * s, .45f * s), hand = new Vector2(.45f * s, -.1f * s);
            var hover = shoulder + new Vector2(Mathf.Cos(a), Mathf.Sin(a)) * (1.4f + .25f * (k % 2)) * s;
            int cell = CellShardA + k % 3;
            float spin = (k % 2 == 0 ? 1f : -1f) * 8f;
            PaintSprite.Create(root, paintFlipMaterial, this, chest, 0f, (arrive + .02f) * HitPace, cell, t =>
            {
                float tr = t / HitPace;
                if (tr >= arrive) return new Pose2 { scale = 0f };
                // It flies out of the hand to its place in the fan (growing as it goes), hovers, then streaks in.
                float o = EoutSmooth(Iv(appear, appear + .12f, tr)), pop = .45f + .55f * o, u = Iv(launch, arrive, tr);
                var aim = tOff - hover;
                var place = Vector2.Lerp(hand, hover, o) + Vector2.up * .05f * s * Mathf.Sin(tr * 9f + k);
                var pos = Vector2.Lerp(place, tOff, u * u);
                float roll = Mathf.Atan2(aim.y, aim.x) * Mathf.Rad2Deg - 90f + spin * Mathf.Sin(tr * 6f + k) * (1f - u);
                // 1.5x (user 10-14: 镜片有点小).
                return new Pose2 { off = pos, roll = roll, scale = s * 1.5f * pop * Mathf.Lerp(1f, far, u), alpha = Iv(appear, appear + .03f, tr),
                    tint = Color.white, soft = true };
            });
        }
    }

    void CardDim(Vector3 at, float amount)
    {
        if (amount <= 0f) return;
        if (!dim) dim = Dim.Create(root, dimMaterial, this);
        dim.Trigger(at, ReducedMotion ? amount * .5f : amount);
    }

    /// A contact of one of the three cards; cue.intent "ordered" marks the rules' later hits.
    void CardImpact(Cue cue, Camera cam, Vector3 caster, List<Vector3> points)
    {
        if (!InkStrokes || !inkMaterial) return;
        bool ordered = cue.intent == "ordered";
        float Half(Vector3 at) => Vector3.Distance(cam.transform.position, at) * Mathf.Tan(cam.fieldOfView * .5f * Mathf.Deg2Rad);
        int Seed(int i) => (i < cue.seeds.Count ? cue.seeds[i] : i * 7919) * 31 + cue.cast * 7 + 5;
        switch (cue.profile.id)
        {
            case "tempo":
            {
                // The hero comes first in the targets (BeginPlayer), then the enemy it nicks.
                var chest = points[0];
                float s = Half(chest) * .28f;
                Ink2D.Create(root, inkMaterial, this, cam, chest - cam.transform.forward, chest, s, 0f, Seed(0), "tempo");
                if (HasCardArt) TempoPaint(cam, chest, s, Seed(0));
                if (tempoAura) tempoAura.EndMark();
                tempoAura = Ink2D.CreateMark(root, inkMaterial, this, cam, cue.caster, s, Seed(0) + 3, "tempoaura", Ink2D.TempoLife);
                for (int i = 1; i < points.Count; i++)
                    Ink2D.Create(root, inkMaterial, this, cam, caster, points[i], Half(points[i]) * .16f, .03f * i, Seed(i), "tempotick");
                break;
            }
            case "barrage":
            {
                for (int i = 0; i < points.Count; i++)
                {
                    var ink = Ink2D.Create(root, inkMaterial, this, cam, caster, points[i], Half(points[i]) * (i == 0 ? .2f : .15f), .03f * i, Seed(i), "mirror");
                    ink.SetHero(caster);
                    if (HasCardArt)
                    {
                        // The shard that just struck bursts into pieces on the target.
                        float hs = Half(points[i]) * .13f;
                        var d = caster - points[i]; float ang = Mathf.Atan2(Vector3.Dot(d, cam.transform.up), Vector3.Dot(d, cam.transform.right)) * Mathf.Rad2Deg + 90f;
                        PaintPieces.Create(root, this, points[i], 0f, CellShardA + (cue.cast + i) % 3,
                            new Pose2 { roll = ang, scale = hs * 1.6f, alpha = 1f, tint = Color.white }, Scatter.Burst, 1.3f * hs * 4f, .45f, Seed(i) + 9);
                    }
                }
                CardDim(points[0], .1f);
                break;
            }
            case "signature":
            {
                if (!ordered)
                {
                    for (int i = 0; i < points.Count && i < cue.targets.Count; i++)
                    {
                        // A new signature on the same target replaces the old one (the rules drop its blast).
                        EndFuses(points[i], false);
                        float s = Half(points[i]) * .2f;
                        Ink2D.Create(root, inkMaterial, this, cam, caster, points[i], s, 0f, Seed(i), "fusestamp");
                        var fuse = Ink2D.CreateMark(root, inkMaterial, this, cam, cue.targets[i], s, Seed(i) + 3, "fuse", Ink2D.FuseLife);
                        fuses.Add(fuse);
                        SignatureStain(points[i], s, Seed(i), fuse);
                    }
                    CardDim(points[0], .18f);
                }
                else
                {
                    // The rules' blast: the main target first, then the two it splashes.
                    for (int i = 0; i < points.Count; i++)
                    {
                        EndFuses(points[i], true);
                        float s = Half(points[i]) * (i == 0 ? .22f : .15f), delay = i == 0 ? 0f : .06f + .04f * i;
                        Ink2D.Create(root, inkMaterial, this, cam, caster, points[i], s, delay, Seed(i), i == 0 ? "fuseblast" : "fusesplash");
                        SignatureBlast(points[i], s, delay, i == 0, Seed(i));
                    }
                    CardDim(points[0], .36f);
                }
                break;
            }
        }
    }

    // The violet painted splash (cell 31) tinted to black ink; the round smoke (7) to soot.
    static readonly Color SignInk = new Color(.12f, .1f, .15f), SignSmoke = new Color(.36f, .33f, .37f);

    /// The ink stain sits this far (in stain sizes) above the hit point, on the body.
    const float StainLift = .2f;

    /// The ink stain 延时落款 leaves on its target, alive (user 10-14, boxing the still stain:
    /// 这团东西要蠕动): three copies of the painted splash inked black turn slowly against each
    /// other, swell and squash out of step and twist, so the outline never holds still; as the
    /// fuse burns down they writhe faster and the stain shakes; tendrils of the same ink reach out
    /// of its rim (below). Ink2D "fuse" draws only the fuse. Gone the moment the fuse ends.
    void SignatureStain(Vector3 at, float s, int seed, Ink2D fuse)
    {
        if (!paintFlipMaterial || !paintFlipMaterial2) return;
        for (int layer_ = 0; layer_ < 3; layer_++)
        {
            int layer = layer_;
            float roll0 = seed % 360 + layer * 127f, spin = (layer % 2 == 0 ? 1f : -1f) * (14f + 9f * layer);
            float ph = layer * 2.1f + seed % 7, sc0 = layer == 0 ? 1f : .82f - .08f * layer;
            PaintSprite.Create(root, paintFlipMaterial, this, at, 0f, (Ink2D.FuseLife + 1.2f) * HitPace, 31, t =>
            {
                if (!fuse || !fuse.MarkLive) return new Pose2 { scale = -1f };
                float pop = Back(Iv(0f, .1f + .03f * layer, t)), b = fuse.Burnt, w = t * (1f + 1.8f * b * b);
                float breathe = 1f + .1f * Mathf.Sin(w * (4.1f + .7f * layer) + ph);
                float squash = 1f + .14f * Mathf.Sin(w * (3.3f + .9f * layer) + ph * 1.7f);
                var drift = new Vector2(Mathf.Sin(w * 2.3f + ph), Mathf.Cos(w * 1.9f + ph * .6f)) * .07f * s;
                float shake = b * b * .05f * s;
                return new Pose2 { off = new Vector2(0f, StainLift * s) + drift + new Vector2(Mathf.Sin(t * 61f) * shake, Mathf.Cos(t * 53f) * shake),
                    roll = roll0 + spin * t + 8f * Mathf.Sin(w * 2f + ph), scale = s * sc0 * breathe * (.3f + .7f * pop), sy = squash,
                    curl = .7f * Mathf.Sin(w * 1.6f + ph), alpha = Iv(0f, .02f, t) * (layer == 0 ? 1f : .9f), tint = SignInk, soft = true };
            });
        }
        // Tendrils of the same painted ink (user 10-14: 里面像真墨水，外面有点假 - the drawn
        // strokes round the painted core read as fake): a small copy of the splash stretched
        // along its heading, its root on the stain's rim, reaching out and drawing back in on
        // its own beat with a new heading and mirror each time; quicker as the fuse nears.
        for (int i_ = 0; i_ < 6; i_++)
        {
            int i = i_;
            float h1 = Mathf.Repeat(Mathf.Sin(seed * .37f + i * 12.9898f) * 43758.5453f, 1f), h2 = Mathf.Repeat(h1 * 7.31f + .17f, 1f), h3 = Mathf.Repeat(h2 * 5.77f + .41f, 1f);
            PaintSprite.Create(root, paintFlipMaterial, this, at, 0f, (Ink2D.FuseLife + 1.2f) * HitPace, 31, t =>
            {
                if (!fuse || !fuse.MarkLive) return new Pose2 { scale = -1f };
                float b = fuse.Burnt, agit = 1f + 1.6f * b * b, period = (.8f + .5f * h1) / agit;
                float cyc = t / period + h2; int n = Mathf.FloorToInt(cyc); float cu = cyc - n;
                float reach = Mathf.Sin(cu * Mathf.PI) * Iv(.08f, .2f, t);
                float ang = h3 * 6.283f + n * 1.9f + .3f * Mathf.Sin(t * 1.3f + i);
                float L = (.3f + .25f * Mathf.Repeat(h1 + n * .618f, 1f)) * s * reach * Mathf.Min(1.25f, .2f + .8f * agit);
                if (L < .04f * s) return new Pose2 { scale = 0f };
                float width = .2f * s * (.7f + .3f * reach);
                var dv = new Vector2(Mathf.Cos(ang), Mathf.Sin(ang));
                return new Pose2 { off = new Vector2(0f, StainLift * s) + dv * (.3f * s + L * .45f), roll = ang * Mathf.Rad2Deg - 90f + 6f * Mathf.Sin(t * 4f * agit + i),
                    scale = width, sy = Mathf.Max(1f, L / width), mirror = (n & 1) == 1, curl = .5f * Mathf.Sin(t * 2.2f + i), alpha = 1f, tint = SignInk, soft = true };
            });
        }
    }

    /// 延时落款 goes off in the painted art: the ink slams open and tears apart, the painted fire
    /// pops and splits into rising tongues with small flames licking after, and a cloud of soot
    /// rolls up out of it. Ink2D "fuseblast" adds the flash, embers and ink drops.
    void SignatureBlast(Vector3 at, float s, float delay, bool main, int seed)
    {
        if (!paintFlipMaterial) return;
        var rng = new System.Random(seed);
        float Rn(float a, float b) => a + (b - a) * (float)rng.NextDouble();
        Pose2 P(Vector2 off, float roll, float scale, float alpha, Color tint) => new Pose2 { off = off, roll = roll, scale = scale, alpha = alpha, tint = tint };
        float k = main ? .85f : .6f;
        if (paintFlipMaterial2)
        {
            float inkRoll = Rn(0f, 360f), inkS = 1.9f * s * k;
            PaintSprite.Create(root, paintFlipMaterial, this, at, delay, .14f, 31, t =>
            {
                var p = P(Vector2.zero, inkRoll, inkS * (.4f + .6f * Back(Iv(0f, .1f, t))), Iv(0f, .015f, t), SignInk); p.soft = true; return p;
            });
            PaintPieces.Create(root, this, at, delay + .12f / HitPace, 31, P(Vector2.zero, inkRoll, inkS, 1f, SignInk), Scatter.Burst, 2.6f * s * k, .55f, seed + 11);
        }
        float fz = 2f * s * k; var fc = new Vector2(0f, .15f * s);
        PaintSprite.Create(root, paintFlipMaterial, this, at, delay + .02f, .2f, 14, t =>
            P(fc, 0f, fz * (.4f + .6f * Back(Iv(0f, .1f, t))), Iv(0f, .02f, t) * (1f - Iv(.14f, .18f, t)), Color.white));
        PaintPieces.Create(root, this, at, delay + .02f + .14f / HitPace, 14, P(fc, 0f, fz, 1f, Color.white), Scatter.Rise, 2.4f * s * k, .5f, seed + 31);
        for (int i_ = 0; i_ < (main ? 6 : 3); i_++)
        {
            float born = Rn(.06f, .34f), life = Rn(.22f, .32f), x = Rn(-.4f, .4f), roll = Rn(-14f, 14f), sc = Rn(.3f, .45f), ph = Rn(0f, 6f);
            PaintSprite.Create(root, paintFlipMaterial, this, at, delay, born + life + .02f, 14, t =>
            {
                if (t < born) return P(Vector2.zero, 0f, 0f, 0f, Color.white);
                float u = Iv(born, born + life, t);
                return P(fc + new Vector2(x * fz, -.1f * fz + .7f * fz * u), roll + 10f * Mathf.Sin(t * 14f + ph), fz * sc * (1f - .45f * u), Mathf.Sin(u * Mathf.PI), Color.white);
            });
        }
        float smokeRoll = Rn(0f, 360f);
        PaintSprite.Create(root, paintFlipMaterial, this, at, delay + .1f / HitPace, .75f, 7, t =>
        {
            float u = Iv(0f, .75f, t);
            var p = P(new Vector2(0f, .2f * s + 1.3f * s * k * EoutSmooth(u)), smokeRoll + 25f * u, s * k * (1.3f + 1.6f * EoutSmooth(u)), .8f * Iv(0f, .08f, t) * (1f - Smooth01(Iv(.25f, 1f, u))), SignSmoke);
            p.soft = true; return p;   // eroding at low alpha, the smoke read as grain noise (probe2)
        });
    }
    static float EoutSmooth(float u) { u = Mathf.Clamp01(u); return 1f - (1f - u) * (1f - u); }

    /// Ends the burning signatures on the target at `at` (blast: its blast is being drawn).
    void EndFuses(Vector3 at, bool blast)
    {
        for (int i = fuses.Count - 1; i >= 0; i--)
        {
            var f = fuses[i];
            if (!f || !f.MarkLive) { fuses.RemoveAt(i); continue; }
            if (Vector3.Distance(f.Anchor, at) > 1.2f) continue;
            f.EndMark(blast);
            fuses.RemoveAt(i);
        }
    }

    sealed partial class Ink2D
    {
        /// The rules' windows: 抢拍开幕's haste (MPCOrderedSkillRules.hasteDuration) and
        /// 延时落款's delay (signatureDelay).
        public const float TempoLife = 3.2f, FuseLife = 2.6f;
        // Black ink with a burning rim: rim, ember, ink body, ink core (outer .. core bands).
        static readonly Color InkRim = Hex("FF6A1A"), InkEmber = Hex("5A1206"), InkBody = Hex("16090C"), InkCore = Hex("07040A");
        static readonly Color PrismGold = Hex("FFE16A"), PrismViolet = Hex("9A7CFF");
        static readonly Color FuseCord = Hex("140C08"), FuseTwist = Hex("3A2A1E");

        bool mark; float markLife, markEnd = -1f; bool markBlast;
        public Vector3 Anchor => at;
        public bool MarkLive => mark && markEnd < 0f;
        /// How far the fuse has burnt, 0..1 over its life.
        public float Burnt => markLife > 0f ? Mathf.Clamp01(age / markLife) : 0f;

        /// A mark that stays on a moving anchor for real seconds (the haste, the fuse).
        public static Ink2D CreateMark(Transform parent, Material material, SpellSpectacle20260926 owner, Camera cam, Func<Vector3> follow, float size, int seed, string kind, float life)
        {
            var at = SafeEval(follow);
            var k = Create(parent, material, owner, cam, at - cam.transform.forward, at, size, 0f, seed, kind);
            k.mark = true; k.follow = follow; k.markLife = life; k.gameObject.name = "SpectacleMark " + kind;
            return k;
        }
        /// blast: the fuse reached its blast (drawn separately), so it goes at once.
        public void EndMark(bool blast = false) { if (mark && markEnd < 0f) { markEnd = age; markBlast = blast; } }
        /// Where the hero stands in this ink's plane (the barrage's trail streaks in from there).
        public void SetHero(Vector3 hero) { var d = hero - at; heroOff = new Vector2(Vector3.Dot(d, R), Vector3.Dot(d, U)); }

        bool CardPalette(string kind)
        {
            switch (kind)
            {
                // 抢拍开幕: the card's hourglass gold - amber rim, gold, pale gold, cream.
                case "tempo": case "tempotick": case "tempoaura":
                    outer = Hex("8A4A08"); band2 = Hex("F0A21E"); band3 = Hex("FFD45A"); core = Hex("FFF6DA"); hot = Hex("FFE7A0");
                    duration = kind == "tempotick" ? .55f : 1f; return true;
                // 碎镜连弹: the card's ice-blue mirror - deep sea blue, cyan, ice, white; prism pink glints.
                case "mirror":
                    outer = Hex("0A3E66"); band2 = Hex("2ECBF5"); band3 = Hex("BDF4FF"); core = Hex("FFFFFF"); hot = Hex("FF8FE6");
                    duration = .55f; return true;
                // 延时落款: the letter bomb's fuse fire (the ink is pushed over it where it is drawn).
                case "fuse": case "fusestamp": case "fuseblast": case "fusesplash":
                    outer = Hex("B8360C"); band2 = Hex("FF7A1E"); band3 = Hex("FFB648"); core = Hex("FFF1CC"); hot = Hex("FFD45A");
                    duration = kind == "fuseblast" ? 1.05f : kind == "fusesplash" ? .8f : kind == "fusestamp" ? .6f : 1f; return true;
            }
            return false;
        }

        bool CardKind(float t)
        {
            switch (kind)
            {
                case "tempo": Tempo(t); return true;
                case "tempotick": TempoTick(t); return true;
                case "mirror": Mirror(t); return true;
                case "fusestamp": FuseStamp(t); return true;
                case "fuseblast": FuseBlast(t, true); return true;
                case "fusesplash": FuseBlast(t, false); return true;
            }
            return false;
        }

        /// A mark's frame, in real seconds (not HitPace: the rules' windows are real time).
        void MarkFrame()
        {
            float end = markEnd >= 0f ? markEnd : markLife + (kind == "fuse" ? .6f : 0f);
            float tail = markBlast ? 0f : .35f;
            if (age > end + tail) { Destroy(gameObject); return; }
            if (follow != null) { try { at = follow(); } catch { follow = null; } }
            vs.Clear(); cs.Clear(); u0.Clear(); u1.Clear(); u2.Clear(); u3.Clear(); tris.Clear();
            now = age;
            if (kind == "fuse") FuseMark(age); else TempoAura(age, end);
            mesh.Clear();
            if (vs.Count == 0) return;
            mesh.SetVertices(vs); mesh.SetColors(cs); mesh.SetUVs(0, u0); mesh.SetUVs(1, u1); mesh.SetUVs(2, u2); mesh.SetUVs(3, u3);
            mesh.SetTriangles(tris, 0);
            mesh.bounds = new Bounds(at, Vector3.one * size * 12f);
        }

        /// 抢拍开幕 on the hero: two quick beats flash over the head (tick-tick, the stolen
        /// tempo), then the hourglass's gold sand fountains up from there and falls away to
        /// both sides like a curtain parting - a spray of glittering grains, no bands - while
        /// glitter keeps sifting down round the figure.
        void Tempo(float t)
        {
            float s = size, u = t / duration;
            var top = new Vector2(0f, .8f * s);
            float swell = EOut(Inv(0f, .18f, t)) * (1f - EIn(Inv(.35f, 1f, u)));
            Glow(new Vector2(0f, .4f * s), 1.8f * s, outer, .07f * swell);
            Glow(top, 1f * s, band2, .14f * swell);
            for (int b = 0; b < 2; b++)
            {
                float bt = t - b * .11f, bu = Inv(0f, .2f, bt);
                if (bt < 0f || bu >= 1f) continue;
                var bc = top + new Vector2(b == 0 ? -.12f * s : .16f * s, b * .1f * s);
                Sparkle(bc, s * (b == 0 ? .6f : .42f) * (1f - .5f * bu), hot, 1f - bu, 15f + b * 22f);
                Glow(bc, s * .6f, band3, .3f * (1f - bu));
            }
            for (int side = -1; side <= 1; side += 2)
                for (int i = 0; i < 70; i++)
                {
                    int k = i + (side > 0 ? 100 : 0);
                    float born = .02f + .28f * J(k) * J(k + 5), age_ = t - born, life = .5f + .45f * J(k + 1);
                    if (age_ < 0f || age_ > life) continue;
                    // Up and out, the later ones lower and wider: the fountain opens sideways.
                    // Fine glitter kept round the hero: screen-up is toward the enemy row, so a tall
                    // fountain read as gold balls thrown at the enemy (probe2).
                    float spread = .45f + 1.1f * J(k + 2) + 1.6f * (born - .02f);
                    var v = new Vector2(side * spread, 1.1f - .7f * J(k + 3)) * s * 1.6f;
                    var p = top + new Vector2(side * .1f * s, 0f) + v * age_ + Vector2.down * (4.6f * s * age_ * age_);
                    float gu = age_ / life, r = s * (.012f + .02f * J(k + 4)) * (1f - .3f * gu), a = Mathf.Pow(1f - gu, .7f);
                    if (k % 7 == 0) Sparkle(p, r * 5f, hot, a * .9f, 15f + t * 300f);
                    else Dot(p, r, Color.Lerp(band3, band2, Mathf.Clamp01(gu * 1.4f)), 3f, a, age_ * 3f, .05f);
                }
            for (int i = 0; i < 16; i++)
            {
                float born = .2f + .5f * J(i + 200), gu = Inv(born, born + .5f, t);
                if (gu <= 0f || gu >= 1f) continue;
                var p = new Vector2((J(i + 201) - .5f) * 2.2f * s, 1.2f * s - 2.4f * s * gu);
                if (i % 3 == 0) Sparkle(p, s * .1f, hot, Mathf.Sin(gu * Mathf.PI), 15f + gu * 120f);
                else Dot(p, s * .03f, band3, 0f, Mathf.Sin(gu * Mathf.PI) * .8f, gu * 3f, .05f);
            }
        }

        /// 抢拍开幕's nick on the enemy: one bright tick and a puff of the same gold sand.
        void TempoTick(float t)
        {
            float s = size, u = t / duration, live = 1f - u;
            ImpactStar(Vector2.zero, s * .8f, t, 41, false);
            Glow(Vector2.zero, 1.4f * s, band2, .16f * Mathf.Pow(live, 1.5f));
            float baseAng = Mathf.Atan2(dir.y, dir.x);
            for (int i = 0; i < 24; i++)
            {
                float ang = baseAng + (J(i) - .5f) * 2.2f, life = .3f + .25f * J(i + 1), age_ = t - .02f * J(i + 2);
                if (age_ < 0f || age_ > life) continue;
                var d = new Vector2(Mathf.Cos(ang), Mathf.Sin(ang));
                float gu = age_ / life;
                var p = d * s * (1.4f + 1.6f * J(i + 3)) * age_ * (1f - .4f * gu) + Vector2.down * (2f * s * age_ * age_);
                if (i % 6 == 0) Sparkle(p, s * .12f, hot, 1f - gu, 15f + t * 300f);
                else Dot(p, s * (.03f + .03f * J(i + 4)), Color.Lerp(band3, band2, gu), 0f, 1f - gu, age_ * 3f, .05f);
            }
        }

        /// 碎镜连弹, one shard landing: its trail still streaking in from the hero's side, a
        /// short cyan flash, a few prism-coloured glints thrown just past it and mirror glints
        /// winking on. Small and quick: six of them land within a second and a half, each a
        /// little off the last, and must read as six blows, not one white lump.
        void Mirror(float t)
        {
            float s = size, u = t / duration, live = 1f - u;
            var c = new Vector2((J(1) - .5f) * .8f * s, (J(2) - .5f) * .7f * s);
            float ang = Mathf.Atan2(dir.y, dir.x) + (J(3) - .5f) * .45f;
            var d = new Vector2(Mathf.Cos(ang), Mathf.Sin(ang));
            float tu = Inv(0f, .09f, t);
            if (tu < 1f)
            {
                float reach = heroOff.sqrMagnitude > 1e-6f ? heroOff.magnitude * .6f : 3f * s;
                float L = Mathf.Min(reach, 4f * s) * (1f - EOut(tu));
                Taper(c - d * L, c, s * .03f, s * .14f, band2, .6f * (1f - tu));
                Taper(c - d * L * .8f, c, s * .012f, s * .05f, band3, .9f * (1f - tu));
            }
            // Small: six of these land in 1.5 s and their glows stacked into a blue lump (probe8).
            ImpactStar(c, s * .55f, t, 43, false);
            Glow(c, 1.2f * s, outer, .07f * Mathf.Pow(live, 1.3f));
            Glow(c, .7f * s, band2, .1f * Mathf.Pow(live, 1.6f));
            for (int k = 0; k < 5; k++)
            {
                float a2 = ang + (k / 4f - .5f) * 1.2f + (J(k + 10) - .5f) * .3f;
                float su = Inv(.01f + .015f * k, .2f + .02f * k, t);
                if (su <= 0f || su >= 1f) continue;
                var dk = new Vector2(Mathf.Cos(a2), Mathf.Sin(a2));
                float r0 = s * .2f + s * .7f * EOut(su) * (.6f + .5f * J(k + 11)), len = s * (.3f + .25f * J(k + 12)) * (1f - su);
                var col = (k % 4) switch { 0 => band2, 1 => hot, 2 => PrismGold, _ => PrismViolet };
                Taper(c + dk * r0, c + dk * (r0 + len), s * .08f * (1f - su * .5f), 0f, col, .85f * (1f - su));
            }
            for (int i = 0; i < 3; i++)
            {
                float gu = Inv(.03f + .05f * i, .2f + .05f * i, t);
                if (gu <= 0f || gu >= 1f) continue;
                float ga = J(i + 30) * 6.283f, w = Mathf.Sin(gu * Mathf.PI);
                var gp = c + new Vector2(Mathf.Cos(ga), Mathf.Sin(ga)) * (.4f + .5f * J(i + 31)) * s;
                Sparkle(gp, s * (.16f + .08f * J(i + 32)) * w, i % 2 == 0 ? band3 : hot, w, 15f + 45f * J(i + 33));
            }
            Sparks(c, t, 8, 60, 1.2f * s, d * .6f, 1f - EIn(u));
        }

        /// 延时落款 lands: the ink stain slaps on (SignatureStain, painted), with a burst of
        /// embers and a few ink drops here; the fuse sticking out of it is the mark (FuseMark).
        void FuseStamp(float t)
        {
            float s = size, u = t / duration, live = 1f - u, fade = 1f - EIn(u);
            Glow(Vector2.zero, 1.6f * s, outer, .14f * Mathf.Pow(live, 1.4f));
            ImpactStar(Vector2.zero, s * .75f, t, 47, false);
            PushPal(InkRim, InkEmber, InkBody, InkCore);
            Drips(Vector2.zero, t, 8, 150, 1.3f * s, fade);
            PopPal();
            Sparks(Vector2.zero, t, 12, 80, 1.4f * s, Vector2.up * .3f, fade);
        }

        /// The fuse: a short cord curling up out of the stain's shoulder, burning down from its
        /// tip toward the stain over the rules' 2.6 s - a spitting spark at the burning end, its
        /// sparks coming quicker and a warning glow on the stain beating faster as it nears.
        /// The blast receipt ends it; with none (the target fell and the rules dropped the
        /// blast) it fizzles out in a puff of smoke.
        void FuseMark(float t)
        {
            float s = size;
            float gone = markEnd >= 0f ? Inv(markEnd, markEnd + .25f, t) : Inv(markLife + .6f, markLife + .95f, t);
            float vis = Smooth(Inv(.04f, .16f, t)) * (1f - gone);
            var lift = new Vector2(0f, StainLift * s);
            var a = new Vector2(.36f, .3f) * s + lift; var b = new Vector2(.52f, .52f) * s + lift;
            var c = new Vector2(.4f, .7f) * s + lift; var d = new Vector2(.6f, .86f) * s + lift;
            float burnt = Mathf.Clamp01(t / markLife), left = 1f - burnt;
            if (vis > .01f && left > .02f)
            {
                // A dark twisted cord (flat colour: the brush stroke's glow read as a lit stick).
                const int Segs = 10;
                var prev = Bez(a, b, c, d, 0f);
                for (int i = 1; i <= Segs; i++)
                {
                    float cu = left * i / Segs; var q = Bez(a, b, c, d, cu);
                    Taper(prev, q, .055f * s, .05f * s, FuseCord, vis, 1f);
                    if (i % 2 == 0) Taper(Vector2.Lerp(prev, q, .3f), Vector2.Lerp(prev, q, .7f), .03f * s, .03f * s, FuseTwist, vis, 1f);
                    prev = q;
                }
            }
            if (markEnd < 0f && t < markLife + .05f && vis > .01f)
            {
                var e = Bez(a, b, c, d, left);
                float rate = 3f + 9f * burnt, pulse = .5f + .5f * Mathf.Sin(t * rate * 6.283f);
                Glow(Vector2.zero, 1.1f * s, band2, (.03f + .1f * burnt) * pulse * vis);
                Glow(e, (.3f + .12f * pulse) * s, band2, (.22f + .14f * pulse) * vis);
                Sparkle(e, s * (.3f + .12f * pulse), core, vis, 15f + t * 400f);
                Sparkle(e, s * (.18f + .08f * pulse), hot, vis, 40f - t * 300f);
                float beat = 1f / rate; int bi = Mathf.FloorToInt(t / beat); float bt = t - bi * beat;
                Sparks(e, bt, 7, 120 + (bi & 7) * 7, 1.2f * s, Vector2.up * .5f, vis);
                if (bi > 0) Sparks(e, bt + beat, 7, 120 + ((bi - 1) & 7) * 7, 1.2f * s, Vector2.up * .5f, vis);
                for (int i = 0; i < 4; i++)
                {
                    float gu = Mathf.Repeat(t * 1.4f + i * .25f, 1f);
                    PushPal(Hex("6A6470"), Hex("8A8490"), Hex("A8A2AE"), Hex("C8C2CC"));
                    Dot(e + new Vector2(.15f * s * Mathf.Sin(gu * 5f + i), .9f * s * gu), s * (.05f + .1f * gu), band3, 0f, .35f * vis * (1f - gu), t + i, .2f);
                    PopPal();
                }
            }
            if (markEnd < 0f && t > markLife + .6f)
            {
                float fu = Inv(markLife + .6f, markLife + .95f, t);
                PushPal(Hex("5A5560"), Hex("8A8590"), Hex("B8B4BC"), Hex("E0DCE4"));
                Dot(a + Vector2.up * .4f * s * fu, s * (.15f + .35f * EOut(fu)), band3, 0f, .6f * (1f - fu), t * 2f, .25f);
                PopPal();
            }
        }

        /// 延时落款 goes off (with SignatureBlast's painted ink, fire and smoke): a white-hot
        /// flash, one passing shock ring on the main target, embers flying and falling, ink drops.
        void FuseBlast(float t, bool main)
        {
            float s = size, u = t / duration, live = 1f - u, fade = 1f - EIn(u);
            var c = Vector2.zero;
            if (t < .06f) Glow(c, 2f * s, core, .5f * (1f - t / .06f));
            Glow(c, 2.8f * s, outer, .18f * Mathf.Pow(live, 1.2f));
            Glow(c, 1.6f * s, band2, .24f * Mathf.Pow(live, 1.5f));
            ImpactStar(c, s * 1.1f, t, 71, main);
            PushPal(InkRim, InkEmber, InkBody, InkCore);
            Drips(c, t, main ? 14 : 8, 160, 1.8f * s, fade);
            PopPal();
            for (int i = 0; i < (main ? 14 : 8); i++)
            {
                float born = .05f + .25f * J(i + 70), a = Inv(born, born + .5f, t);
                if (a <= 0f || a >= 1f) continue;
                float ang = J(i + 20) * 6.283f, rr = (.4f + .8f * J(i + 30)) * s;
                var p = new Vector2(Mathf.Cos(ang), Mathf.Sin(ang)) * rr * (.5f + a) + Vector2.up * (.9f * s * a);
                Dot(p, (.05f - .025f * a) * s, Color.Lerp(core, band2, a), 3f, (1f - a) * .9f);
            }
            Sparks(c, t, main ? 22 : 12, 50, 2f * s, Vector2.up * .25f, fade);
        }

        /// 抢拍开幕's haste on the hero (3.2 s): gold sand sifting off the shoulders, a faint
        /// glow at the feet and a glint ticking somewhere on the figure on every doubled beat.
        void TempoAura(float t, float end)
        {
            float s = size;
            float vis = Smooth(Inv(0f, .25f, t)) * (1f - Smooth(Inv(end, end + .35f, t)));
            if (vis <= .01f) return;
            int beat = Mathf.FloorToInt(t / .3f); float bt = (t - beat * .3f) / .3f;
            float pulse = 1f - Smooth(bt);
            Glow(new Vector2(0f, -1.15f * s), 1f * s, band2, (.04f + .04f * pulse) * vis);
            for (int i = 0; i < 44; i++)
            {
                float period = .7f + .5f * J(i), ph = J(i + 1) * period;
                float gu = Mathf.Repeat(t + ph, period) / period;
                float sx = J(i + 2) > .5f ? 1f : -1f, x0 = sx * (.18f + .2f * J(i + 3)) * s;
                var p = new Vector2(x0 + sx * .25f * s * gu, .55f * s - 1.8f * s * gu * gu);
                Dot(p, s * (.016f + .02f * J(i + 4)), i % 2 == 0 ? band3 : band2, 0f, vis * Mathf.Sin(gu * Mathf.PI) * .9f, gu * 3f, .05f);
            }
            if (t < end)
            {
                float h1 = Hash(beat, 3f), h2 = Hash(beat, 7f);
                var gp = new Vector2((h1 - .5f) * 1.1f * s, (-1f + 1.9f * h2) * s);
                Sparkle(gp, s * .14f * Mathf.Sin(Mathf.Min(1f, bt * 1.6f) * Mathf.PI), hot, vis, 15f + 30f * h1);
            }
        }
    }
}
