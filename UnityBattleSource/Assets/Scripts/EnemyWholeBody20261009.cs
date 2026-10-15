using System;
using System.Collections.Generic;
using UnityEngine;

/// The whole enemy body acts in its attacks (2026-10-09, user: 敌人的动作都要和守卫的转身攻击
/// 一样生动，不能只是动动手，身体晃一下，整个呆板好像木偶; then: 动作再自然一点). Only the clock
/// guard plays a full-body mocap clip; every other attack moved arms and chest on a body planted
/// in place. This adds a whole-body move on top of each enemy's own clip and bone layer:
///   Spin  - turns away on the windup, then whirls round a full turn through the blow, the
///           upper body whipping ahead of the hips, sinking and rising, stepping in;
///   Lunge - sinks, draws back and coils the torso, then steps in with a bob as the torso
///           uncoils and leans into the blow, overshooting and settling;
///   Slam  - rises up and arches back, then drops its weight into the blow, the torso folding
///           forward, a squash and a bounce.
/// Two layers so it does not move like a plank: the body root (VisualRoot: turn, step, rise,
/// squash, almost no lean) and the spine chain (twist and lean, split over the spine bones so
/// the bend runs up the back). Motion follows eased curves and damped springs.
/// The windup starts at the cast (SpellSpectacle20260926.BeginEnemy) and keeps building and
/// breathing; the strike fires at the actual contact (SpellSpectacle20260926.Contact) so it
/// always lands on the rules' hit; then the body settles back home.
///
/// Ownership: the same two-phase pattern as HitShake20261007 - applied late (30900, before the
/// review recorder renders at 31000) on top of every other writer, removed first thing next
/// frame by EnemyWholeBodyRestore20261009 (-20500, equality-gated), so nobody bakes it in.
[DisallowMultipleComponent, DefaultExecutionOrder(30900)]
public sealed class EnemyWholeBody20261009 : MonoBehaviour
{
    public enum Style { Spin, Lunge, Slam }
    static readonly Dictionary<string, EnemyWholeBody20261009> byKey = new Dictionary<string, EnemyWholeBody20261009>();
    static readonly string[] SpineNames = { "hips", "pelvis", "spine", "spine1", "spine01", "spine2", "spine02", "spine3", "spine03", "chest", "upperchest", "neck" };

    Transform target;
    Style style;
    Vector3 toward;               // world, flat: from the enemy to the hero
    float height = 2.5f, began = -100f, struck = -100f, spinSign = 1f;
    int casts;
    // Root state for the equality-gated restore.
    Vector3 basePos, baseScale, appliedPos, appliedScale;
    Quaternion baseRot, appliedRot;
    bool written;
    // Spine chain (root to neck), its share of the bend and what was written on it.
    Transform[] spine = new Transform[0];
    float[] spineShare = new float[0];
    Quaternion[] spineBase = new Quaternion[0], spineApplied = new Quaternion[0];
    bool spineWritten;

    const float MaxWait = 3.2f, StrikeEnd = 1.0f;

    /// The move for an enemy identity (SpellSpectacle20260926 profile id), or null when its
    /// own presentation already moves the whole body (the guard's mocap, the hounds' lunges,
    /// the clock core's flip, the boss's illustrated body) or it is a support cast.
    public static Style? StyleFor(string profile, string intent)
    {
        intent = intent ?? "";
        switch (profile)
        {
            case "guard": case "elite": case "hound": case "early-hound": case "magma": case "mind": case "chronarch":
            case "heal": case "heal-crimson": case "heal-tower": case "enemy-ward": case "empower":
                return null;
            case "shellback": return intent.Contains("pounce") ? (Style?)null : Style.Lunge;
            case "stonehide": case "adjudicator": case "convoy": case "copperback": case "crimson-brute": case "bounty-b06":
                return Style.Slam;
            case "executor": case "matriarch": case "ironclaw": case "boneclaw": case "moonfang": case "bounty-b01": case "bounty-b09":
                return Style.Spin;
            default:
                return Style.Lunge;
        }
    }

    public static void Begin(EnemyHandle handle, string key, Style style, Vector3 heroPosition, Color trailOuter, Color trailBody, Color trailCore)
    {
        if (!handle || !handle.VisualRoot || !handle.VisualRoot.gameObject.activeInHierarchy) return;
        var body = handle.VisualRoot.GetComponent<EnemyWholeBody20261009>();
        if (!body) body = handle.VisualRoot.gameObject.AddComponent<EnemyWholeBody20261009>();
        var restore = handle.VisualRoot.GetComponent<EnemyWholeBodyRestore20261009>();
        if (!restore) restore = handle.VisualRoot.gameObject.AddComponent<EnemyWholeBodyRestore20261009>();
        restore.body = body;
        body.Arm(style, heroPosition);
        body.trailOuter = trailOuter; body.trailBody = trailBody; body.trailCore = trailCore;
        byKey[key] = body;
    }

    public static void Contact(string key)
    {
        if (key != null && byKey.TryGetValue(key, out var body) && body && body.began > 0f && body.struck < body.began)
            body.struck = Time.time;
    }

    void Arm(Style value, Vector3 heroPosition)
    {
        RestoreOwned();
        target = transform;
        style = value;
        var d = heroPosition - target.position; d.y = 0f;
        toward = d.sqrMagnitude > 1e-4f ? d.normalized : -target.forward;
        bool any = false; var b = new Bounds(target.position, Vector3.zero);
        foreach (var r in target.GetComponentsInChildren<Renderer>(false))
        {
            if (!(r is SkinnedMeshRenderer || r is MeshRenderer)) continue;
            if (!any) { b = r.bounds; any = true; } else b.Encapsulate(r.bounds);
        }
        height = any ? Mathf.Clamp(b.size.y, .6f, 6f) : 2.2f;
        FindSpine();
        FindHand();
        trail.Clear();
        spinSign = (casts++ & 1) == 0 ? 1f : -1f;
        began = Time.time; struck = -100f;
    }

    /// The visible body's spine chain: active bones named like a spine, kept only when each
    /// is an ancestor of the next (one chain, root first). Hidden bodies (the guard model kept
    /// under a ghost or revenant) are skipped because they are inactive. The hips take a small
    /// share of the bend (they carry the legs), the neck half, the rest a full share.
    void FindSpine()
    {
        var found = new List<Transform>();
        foreach (var t in target.GetComponentsInChildren<Transform>(false))
        {
            var n = t.name.ToLowerInvariant().Replace("_", "").Replace(" ", "").Replace(".", "").Replace("mixamorig:", "");
            if (Array.IndexOf(SpineNames, n) >= 0) found.Add(t);
        }
        found.Sort((a, c) => Depth(a).CompareTo(Depth(c)));
        var chain = new List<Transform>();
        foreach (var t in found)
            if (chain.Count == 0 || t.IsChildOf(chain[chain.Count - 1])) chain.Add(t);
        spine = chain.ToArray();
        spineShare = new float[spine.Length];
        float total = 0f;
        for (int i = 0; i < spine.Length; i++)
        {
            var n = spine[i].name.ToLowerInvariant();
            spineShare[i] = n.Contains("hip") || n.Contains("pelvis") ? .35f : n.Contains("neck") ? .5f : 1f;
            total += spineShare[i];
        }
        for (int i = 0; i < spine.Length; i++) spineShare[i] /= Mathf.Max(.01f, total);
        spineBase = new Quaternion[spine.Length]; spineApplied = new Quaternion[spine.Length];
        spineWritten = false;
    }

    // ---------------------------------------------------------------- weapon trail
    // The weapon's path through the spin and the slam (2026-10-09, after the UE reel: 刀光沿
    // 挥砍轨迹拖出来): a painterly ribbon in the enemy's colours following the weapon tip over
    // the last ~0.16 s, widest at the head, tapering and fading behind.
    Transform hand, forearm;
    Color trailOuter = Color.red, trailBody = Color.yellow, trailCore = Color.white;
    readonly List<Vector4> trail = new List<Vector4>();      // xyz world tip, w time
    GameObject trailObject; Mesh trailMesh;

    void FindHand()
    {
        hand = null; int rank = 9;
        foreach (var t in target.GetComponentsInChildren<Transform>(false))
        {
            var n = t.name.ToLowerInvariant();
            int r = n.Contains("weapon") || n.Contains("sword") || n.Contains("axe") || n.Contains("hammer") ? 0
                : n == "hand.r" || n.Contains("righthand") || n == "hand_r" || n == "r_hand" || n == "pen.r" ? 1 : 9;
            if (r < rank) { rank = r; hand = t; }
        }
        forearm = hand ? hand.parent : null;
    }

    Vector3 Tip()
    {
        var p = hand.position;
        var d = forearm ? p - forearm.position : Vector3.up;
        return p + (d.sqrMagnitude > 1e-6f ? d.normalized : Vector3.up) * (height * .28f);
    }

    void UpdateTrail()
    {
        float now = Time.time, s = struck >= began ? now - struck : -1f;
        bool on = hand && s >= 0f && (style == Style.Spin ? s < .5f : style == Style.Slam ? s < .2f : false);
        if (on) trail.Add(new Vector4(Tip().x, Tip().y, Tip().z, now));
        trail.RemoveAll(q => now - q.w > .16f);
        var mat = SpellSpectacle20260926.SharedInk;
        if (trail.Count < 2 || !mat || !Camera.main) { if (trailMesh) trailMesh.Clear(); return; }
        if (!trailObject)
        {
            trailObject = new GameObject("Enemy weapon trail");
            trailMesh = new Mesh { name = "EnemyWeaponTrail" }; trailMesh.MarkDynamic();
            trailObject.AddComponent<MeshFilter>().sharedMesh = trailMesh;
            var r = trailObject.AddComponent<MeshRenderer>(); r.sharedMaterial = mat;
            r.shadowCastingMode = UnityEngine.Rendering.ShadowCastingMode.Off; r.receiveShadows = false;
        }
        var camF = Camera.main.transform.forward;
        var vs = new List<Vector3>(); var cs = new List<Color>(); var u0 = new List<Vector4>(); var u1 = new List<Vector4>(); var u2 = new List<Vector4>(); var u3 = new List<Vector4>(); var tris = new List<int>();
        int n = trail.Count; float w0 = height * .16f;
        for (int i = 0; i < n; i++)
        {
            var p = (Vector3)trail[i];
            var d = (i < n - 1 ? (Vector3)trail[i + 1] - p : p - (Vector3)trail[i - 1]);
            var side = Vector3.Cross(camF, d); side = side.sqrMagnitude > 1e-8f ? side.normalized : Vector3.up;
            float along = (float)i / (n - 1), age = Mathf.Clamp01((now - trail[i].w) / .16f);
            float w = w0 * Mathf.Pow(along, .7f) * (1f - .3f * age), fade = (1f - age) * (1f - age);
            var body = new Color(trailBody.r, trailBody.g, trailBody.b, fade);
            for (int k = -1; k <= 1; k++)
            {
                vs.Add(p + side * (w * .5f * k)); cs.Add(body);
                u0.Add(new Vector4(k == 0 ? 1f : 0f, 0f, along, .37f));
                u1.Add(new Vector4(trailCore.r, trailCore.g, trailCore.b, k));
                u2.Add(new Vector4(trailBody.r, trailBody.g, trailBody.b, along * 3f));
                u3.Add(new Vector4(trailOuter.r, trailOuter.g, trailOuter.b, k * .5f));
            }
            if (i > 0)
            {
                int a = (i - 1) * 3, b = i * 3;
                tris.AddRange(new[] { a, b, a + 1, b, b + 1, a + 1, a + 1, b + 1, a + 2, b + 1, b + 2, a + 2 });
            }
        }
        trailMesh.Clear();
        trailMesh.SetVertices(vs); trailMesh.SetColors(cs); trailMesh.SetUVs(0, u0); trailMesh.SetUVs(1, u1); trailMesh.SetUVs(2, u2); trailMesh.SetUVs(3, u3);
        trailMesh.SetTriangles(tris, 0);
        trailMesh.bounds = new Bounds((Vector3)trail[n - 1], Vector3.one * height * 4f);
    }

    void OnDestroy() { if (trailObject) Destroy(trailObject); if (trailMesh) Destroy(trailMesh); }

    static int Depth(Transform t) { int d = 0; while (t.parent) { d++; t = t.parent; } return d; }
    static float Smooth(float u) { u = Mathf.Clamp01(u); return u * u * (3f - 2f * u); }
    static float Accel(float u) { u = Mathf.Clamp01(u); return u * u; }
    /// A damped spring settling from 1 toward 0 (with a slight overshoot below 0).
    static float Spring(float t, float freq, float damp) => t <= 0f ? 1f : Mathf.Exp(-damp * t) * Mathf.Cos(freq * t);

    struct Pose { public float yaw, step, lift, squash, rootLean, twist, lean; }

    Pose Windup(float t)
    {
        // Builds over ~0.5 s with an ease-in-out, then keeps deepening slowly and breathing.
        float w = Smooth(t / .5f), creep = Mathf.Clamp01((t - .5f) / 1.6f), breathe = Mathf.Sin(t * 6.5f) * w;
        var p = new Pose();
        switch (style)
        {
            case Style.Spin:
                p.yaw = -(42f + 10f * creep) * w * spinSign; p.twist = -(34f + 8f * creep) * w * spinSign;
                p.lift = -(.035f + .015f * creep) * w + .005f * breathe; p.lean = -(5f + 3f * creep) * w; p.step = -.03f * w;
                break;
            case Style.Lunge:
                p.yaw = -(12f + 4f * creep) * w * spinSign; p.twist = -(26f + 8f * creep) * w * spinSign;
                p.lift = -(.03f + .012f * creep) * w + .004f * breathe; p.lean = -(9f + 4f * creep) * w + 1.2f * breathe; p.step = -(.07f + .03f * creep) * w;
                break;
            case Style.Slam:
                p.yaw = -(7f + 3f * creep) * w * spinSign; p.twist = -(12f + 4f * creep) * w * spinSign;
                p.lift = (.07f + .03f * creep) * w + .004f * breathe; p.lean = -(14f + 6f * creep) * w + 1.5f * breathe; p.step = -.03f * w;
                p.rootLean = -2f * w;
                break;
        }
        return p;
    }

    Pose Strike(float s, Pose w)
    {
        var p = new Pose();
        float settle = Smooth((s - .3f) / (StrikeEnd - .3f));   // final glide home
        switch (style)
        {
            case Style.Spin:
            {
                // The hips turn a full circle in ~0.42 s (ease in-out); the upper body leads,
                // whipping ahead early, then springs back as the hips catch up.
                float turn = Smooth(s / .42f);
                p.yaw = w.yaw + (360f * spinSign - w.yaw) * turn;
                if (turn >= 1f) p.yaw -= 360f * spinSign;
                float lead = Smooth(s / .14f);
                p.twist = s < .14f ? Mathf.Lerp(w.twist, 28f * spinSign, lead) : 28f * spinSign * Spring(s - .14f, 8f, 4.5f);
                p.step = Mathf.Lerp(w.step, .24f, Smooth(s / .36f)) * (1f - settle);
                // Sinks through the spin and rises after; a bob as each foot plants.
                p.lift = Mathf.Lerp(w.lift, -.05f, Smooth(s / .2f)) * (1f - Smooth((s - .3f) / .35f)) + .015f * Mathf.Sin(Mathf.Clamp01(s / .42f) * Mathf.PI * 2f);
                p.lean = Mathf.Lerp(w.lean, 10f, Smooth(s / .2f)) * (1f - settle);
                p.squash = -.03f * Smooth(s / .4f) * (s < .4f ? 1f : Mathf.Exp(-(s - .4f) * 10f));
                break;
            }
            case Style.Lunge:
            {
                // Hips drive first (a step with a bob); the torso uncoils a beat later and overshoots.
                float stepIn = Smooth(s / .17f);
                p.step = Mathf.Lerp(w.step, .26f, stepIn) * (1f - settle);
                p.lift = Mathf.Lerp(w.lift, -.035f, stepIn) * (1f - settle) + .02f * Mathf.Sin(Mathf.Clamp01(s / .17f) * Mathf.PI);
                p.yaw = Mathf.Lerp(w.yaw, 6f * spinSign, stepIn) * (1f - settle);
                float uncoil = Smooth((s - .03f) / .16f);
                p.twist = s < .19f ? Mathf.Lerp(w.twist, 24f * spinSign, uncoil) : 24f * spinSign * Spring(s - .19f, 7f, 4f);
                p.lean = s < .19f ? Mathf.Lerp(w.lean, 17f, uncoil) : 17f * (1f - settle) + 4f * Mathf.Sin((s - .19f) * 9f) * Mathf.Exp(-(s - .19f) * 5f);
                p.squash = -.04f * stepIn * Mathf.Exp(-Mathf.Max(0f, s - .15f) * 8f);
                break;
            }
            case Style.Slam:
            {
                // The weight drops (accelerating), the torso folds a beat later, a bounce on landing.
                float drop = Accel(s / .12f), land = Mathf.Max(0f, s - .12f);
                p.lift = Mathf.Lerp(w.lift, -.06f, drop) * (s < .12f ? 1f : Spring(land, 10f, 5f));
                p.step = Mathf.Lerp(w.step, .14f, Smooth(s / .14f)) * (1f - settle);
                p.yaw = Mathf.Lerp(w.yaw, 4f * spinSign, drop) * (1f - settle);
                p.twist = Mathf.Lerp(w.twist, 6f * spinSign, drop) * (1f - settle);
                float fold = Smooth((s - .03f) / .13f);
                p.lean = s < .16f ? Mathf.Lerp(w.lean, 24f, fold) : 24f * Spring(s - .16f, 6.5f, 3.6f);
                p.rootLean = Mathf.Lerp(w.rootLean, 3f, drop) * (1f - settle);
                p.squash = -.08f * (s < .12f ? drop : Spring(land, 14f, 7f));
                break;
            }
        }
        return p;
    }

    bool Sample(out Pose p)
    {
        p = default;
        float t = Time.time - began;
        if (began < 0f || t < 0f) return false;
        bool hasStruck = struck >= began;
        if (!hasStruck && t > MaxWait) { began = -100f; return false; }
        if (!hasStruck) { p = Windup(t); return true; }
        float s = Time.time - struck;
        if (s > StrikeEnd) { began = -100f; return false; }
        p = Strike(s, Windup(struck - began));
        return true;
    }

    /// Early-frame removal (EnemyWholeBodyRestore20261009); also run before each new write.
    public void RestoreOwned()
    {
        if (written && target
            && (target.localPosition - appliedPos).sqrMagnitude < 1e-10f && Quaternion.Angle(target.localRotation, appliedRot) < .01f && (target.localScale - appliedScale).sqrMagnitude < 1e-10f)
        { target.localPosition = basePos; target.localRotation = baseRot; target.localScale = baseScale; }
        written = false;
        if (spineWritten)
            for (int i = spine.Length - 1; i >= 0; i--)
                if (spine[i] && Quaternion.Angle(spine[i].localRotation, spineApplied[i]) < .01f) spine[i].localRotation = spineBase[i];
        spineWritten = false;
    }

    void LateUpdate()
    {
        if (!target) return;
        RestoreOwned();
        bool active = Sample(out var p);
        if (!active) { trail.Clear(); if (trailMesh) trailMesh.Clear(); return; }
        float k = SpellSpectacle20260926.ReducedMotion ? .35f : 1f;
        var side = Vector3.Cross(Vector3.up, toward);
        // Root: turn, step, rise, squash; almost no lean (a body leans from the hips, not the feet).
        basePos = target.localPosition; baseRot = target.localRotation; baseScale = target.localScale;
        var parent = target.parent;
        var world = Quaternion.AngleAxis(p.yaw * k, Vector3.up) * Quaternion.AngleAxis(p.rootLean * k, side) * target.rotation;
        var offset = (toward * p.step + Vector3.up * p.lift) * height * k;
        target.localRotation = parent ? Quaternion.Inverse(parent.rotation) * world : world;
        target.localPosition = basePos + (parent ? parent.InverseTransformVector(offset) : offset);
        float sq = p.squash * k;
        target.localScale = new Vector3(baseScale.x * (1f - .5f * sq), baseScale.y * (1f + sq), baseScale.z * (1f - .5f * sq));
        appliedPos = target.localPosition; appliedRot = target.localRotation; appliedScale = target.localScale;
        written = true;
        // Spine: twist and lean split up the chain so the bend runs up the back. Without a
        // spine (odd rigs), the root carries a third of the lean instead.
        if (spine.Length == 0)
        {
            target.rotation = Quaternion.AngleAxis(p.lean * .33f * k, side) * target.rotation;
            appliedRot = target.localRotation;
            UpdateTrail();
            return;
        }
        var turnedSide = Quaternion.AngleAxis(p.yaw * k, Vector3.up) * side;
        for (int i = 0; i < spine.Length; i++)
        {
            if (!spine[i]) continue;
            spineBase[i] = spine[i].localRotation;
            float f = spineShare[i];
            spine[i].rotation = Quaternion.AngleAxis(p.twist * f * k, Vector3.up) * Quaternion.AngleAxis(p.lean * f * k, turnedSide) * spine[i].rotation;
            spineApplied[i] = spine[i].localRotation;
        }
        spineWritten = true;
        UpdateTrail();
    }

    void OnDisable() { RestoreOwned(); began = -100f; trail.Clear(); if (trailMesh) trailMesh.Clear(); }
}

/// Early phase of EnemyWholeBody20261009: removes its offset before any other writer runs.
[DisallowMultipleComponent, DefaultExecutionOrder(-20500)]
public sealed class EnemyWholeBodyRestore20261009 : MonoBehaviour
{
    [NonSerialized] public EnemyWholeBody20261009 body;
    void Update() { if (body) body.RestoreOwned(); }
}
