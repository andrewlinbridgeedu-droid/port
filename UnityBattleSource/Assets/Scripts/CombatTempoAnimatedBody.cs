using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Animations.Rigging;

// Sample-only Blender clips. Formation roots never receive root motion.
[DefaultExecutionOrder(21000)]
public sealed class CombatTempoAnimatedBody : MonoBehaviour
{
    public string Kind { get; private set; }
    public bool WalkingBetweenActions;
    public bool IsActing => action != null;
    Animator animator;
    Vector3 homePosition;
    Quaternion homeRotation;
    int epoch;
    float hitAge = -1, freezeUntil;
    float actionEnds, actionBegan;
    bool moves, held;
    string action;
    RigBuilder builder;
    readonly List<TwoBoneIKConstraint> feet = new List<TwoBoneIKConstraint>();
    readonly List<Transform> footTargets = new List<Transform>();
    readonly List<Spring> springs = new List<Spring>();
    MultiAimConstraint headAim;
    Transform aimTarget;
    Transform externalTarget;
    sealed class Spring { public Transform bone; public Quaternion before, applied; public bool changed; public Vector3 displacement, velocity; public float phase; }

    public static CombatTempoAnimatedBody Install(GameObject model, string kind, Transform target)
    {
        var body = model.GetComponent<CombatTempoAnimatedBody>() ?? model.AddComponent<CombatTempoAnimatedBody>();
        body.Kind = kind; body.externalTarget = target;
        body.animator = model.GetComponent<Animator>() ?? model.AddComponent<Animator>();
        body.animator.runtimeAnimatorController = Resources.Load<RuntimeAnimatorController>("CombatTempo/Animation/" + kind);
        body.animator.cullingMode = AnimatorCullingMode.AlwaysAnimate;
        body.animator.applyRootMotion = true;
        body.homePosition = body.transform.localPosition; body.homeRotation = body.transform.localRotation;
        body.MakeRig(); body.Idle();
        return body;
    }

    Transform Bone(string name) {
        foreach (var t in GetComponentsInChildren<Transform>(true)) if (t.name == name) return t;
        return null;
    }
    void MakeRig()
    {
        builder = gameObject.AddComponent<RigBuilder>();
        var rigRoot = new GameObject("Sample foot planting and target gaze"); rigRoot.transform.SetParent(transform, false);
        var rig = rigRoot.AddComponent<Rig>();
        builder.layers.Add(new RigLayer(rig));
        if (Kind == "Hound") {
            foreach (var leg in new[] { "frontleg", "R_frontleg", "backleg", "R_backleg" })
                Foot(rigRoot.transform, leg + "0", leg + "1", leg + "2");
        } else if (Kind == "Hero") {
            foreach (var side in new[] { "Left", "Right" }) Foot(rigRoot.transform, side + "UpLeg", side + "Leg", side + "Foot");
        } else {
            foreach (var side in new[] { "L", "R" }) Foot(rigRoot.transform, "Thigh." + side, "Shin." + side, "Foot." + side);
        }
        var head = Bone(Kind == "Hound" ? "head" : "Head");
        if (head && externalTarget) {
            var constraint = new GameObject("Target gaze"); constraint.transform.SetParent(rigRoot.transform, false);
            headAim = constraint.AddComponent<MultiAimConstraint>();
            var data = headAim.data; data.constrainedObject = head;
            aimTarget = new GameObject("Gaze target").transform; aimTarget.SetParent(transform.parent, false);
            aimTarget.position = externalTarget.position + Vector3.up;
            var sources = new WeightedTransformArray(); sources.Add(new WeightedTransform(aimTarget, 1));
            data.sourceObjects = sources; data.maintainOffset = true;
            data.aimAxis = MultiAimConstraintData.Axis.Z; data.upAxis = MultiAimConstraintData.Axis.Y;
            data.limits = new Vector2(-12, 12); headAim.data = data; headAim.weight = .24f;
        }
        builder.Build();
        foreach (var name in Kind == "Hound" ? new[] { "tail1", "tail2", "tail3", "earend", "R_earend" } : Kind == "Hero" ? new[] { "Coat.L", "Coat.R" } : Array.Empty<string>()) {
            var bone = Bone(name); if (bone) springs.Add(new Spring { bone = bone, phase = springs.Count * .7f });
        }
    }
    void Foot(Transform rig, string root, string middle, string tip)
    {
        var a = Bone(root); var b = Bone(middle); var c = Bone(tip);
        if (!a || !b || !c || !c.IsChildOf(b) || !b.IsChildOf(a)) { Debug.LogError("TEMPO_FOOT_CHAIN_MISSING " + Kind + " " + tip); return; }
        var go = new GameObject("Plant " + tip); go.transform.SetParent(rig, false);
        var target = new GameObject("Pinned " + tip).transform; target.SetParent(transform.parent, false);
        target.position = c.position; target.rotation = c.rotation;
        var ik = go.AddComponent<TwoBoneIKConstraint>();
        var data = ik.data; data.root = a; data.mid = b; data.tip = c; data.target = target;
        data.targetPositionWeight = 1; data.targetRotationWeight = .5f; ik.data = data;
        feet.Add(ik); footTargets.Add(target);
    }

    public void Play(string clip, float contactAfter, bool hold = false, float tail = .22f)
    {
        epoch++; RestoreSprings();
        action = clip; held = hold; moves = clip == "Light" || clip == "Pounce" || clip == "HeavyRelease" || clip == "HeavyReleaseSecond" || clip == "Probe" || clip == "Thrust";
        actionBegan = Time.time;
        var length = ClipLength(clip);
        var speed = contactAfter > 0 ? length * .58f / contactAfter : 1;
        if (hold) speed = length / Mathf.Max(.1f, contactAfter);
        animator.SetFloat("ActionSpeed", speed);
        animator.CrossFadeInFixedTime(clip, .06f, 0, 0);
        actionEnds = Time.time + (hold ? contactAfter : Mathf.Min(length / Mathf.Max(.01f, speed), contactAfter > 0 ? contactAfter + .22f : length)) + tail;
        if (headAim) headAim.weight = clip == "Opening" ? 0 : .15f;
    }
    float ClipLength(string clip) {
        foreach (var c in animator.runtimeAnimatorController.animationClips) if (c.name == clip) return c.length;
        Debug.LogError("TEMPO_CLIP_MISSING " + Kind + " " + clip); return .6f;
    }
    public void ConfirmedHit(bool heavy)
    {
        hitAge = 0; animator.SetLayerWeight(1, 1); animator.Play("Hit", 1, 0);
        if (heavy) freezeUntil = Time.unscaledTime + .05f;
    }
    public void Idle()
    {
        moves = false; held = false; action = null;
        transform.localPosition = homePosition; transform.localRotation = homeRotation;
        if (animator && animator.isActiveAndEnabled && animator.runtimeAnimatorController) {
            animator.speed = 1; animator.SetFloat("ActionSpeed", 1);
            animator.CrossFadeInFixedTime(WalkingBetweenActions ? "Walking" : "BattleIdle", .08f, 0, 0);
        }
        if (headAim) headAim.weight = .24f;
    }
    void Update()
    {
        RestoreSprings();
        if (aimTarget && externalTarget) aimTarget.position = externalTarget.position + Vector3.up;
        // Only the Animator freezes; rule ticks, contact clocks and particles continue.
        animator.speed = Time.unscaledTime < freezeUntil ? 0 : 1;
        if (action != null && Time.time >= actionEnds) {
            if (held) { animator.speed = 0; } else Idle();
        }
        if (hitAge >= 0) {
            hitAge += Time.deltaTime;
            animator.SetLayerWeight(1, Mathf.Clamp01(1 - hitAge / .42f));
            if (hitAge >= .42f) hitAge = -1;
        }
        foreach (var foot in feet) foot.weight = WalkingBetweenActions && action == null || action == "Pounce" ? 0 : 1;
    }
    void OnAnimatorMove()
    {
        if (!moves || animator.speed == 0) return;
        var desired = transform.position + animator.deltaPosition;
        var local = transform.parent ? transform.parent.InverseTransformPoint(desired) : desired;
        transform.localPosition = homePosition + Vector3.ClampMagnitude(local - homePosition, .8f);
        // No delta rotation on the actor: the authored torso carries the turn.
    }
    void LateUpdate()
    {
        float dt = Mathf.Min(Time.deltaTime, .04f);
        foreach (var s in springs) {
            if (!s.bone) continue;
            s.before = s.bone.localRotation;
            var target = new Vector3(Mathf.Sin(Time.time * 2.6f - s.phase) * 2, 0, Mathf.Sin(Time.time * 3 - s.phase) * 1.2f);
            s.velocity += ((target - s.displacement) * 58 - s.velocity * 13) * dt;
            s.displacement = Vector3.ClampMagnitude(s.displacement + s.velocity * dt, 5);
            s.applied = s.before * Quaternion.Euler(s.displacement); s.bone.localRotation = s.applied; s.changed = true;
        }
    }
    void RestoreSprings() { foreach (var s in springs) if (s.changed) { if (s.bone && Quaternion.Angle(s.bone.localRotation, s.applied) < .001f) s.bone.localRotation = s.before; s.changed = false; } }
    public void Cancel() { epoch++; StopAllCoroutines(); RestoreSprings(); hitAge = -1; if (animator) animator.SetLayerWeight(1, 0); Idle(); }
    void OnDisable() => Cancel();
    void OnDestroy() { if (builder) builder.Clear(); foreach (var t in footTargets) if (t) Destroy(t.gameObject); if (aimTarget) Destroy(aimTarget.gameObject); }
}
