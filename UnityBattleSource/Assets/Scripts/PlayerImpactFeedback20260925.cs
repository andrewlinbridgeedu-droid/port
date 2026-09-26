using System;
using System.Collections.Generic;
using System.Globalization;
using UnityEngine;

/// Confirmed native loss only. An additive torso reaction, never a combat stun.
/// Restore runs in a separate early Update; this component applies after the
/// existing idle (800) and skill choreography (900) LateUpdates.
[DisallowMultipleComponent, DefaultExecutionOrder(1100)]
public sealed class PlayerImpactFeedback20260925 : MonoBehaviour
{
    sealed class Joint
    {
        public Transform bone;
        public Vector3 degrees;
        public Quaternion before, applied;
        public bool written;
    }
    readonly List<Joint> joints = new List<Joint>();
    BattlePrototype battle;
    FoolSkillChoreography choreography;
    string context = "";
    long lastSequence;
    float started, strength;
    bool playing;
    public const float Duration = .30f;
    public bool IsPlaying => playing;
    public int PlayCount { get; private set; }
    public int RejectedCount { get; private set; }
    public int MappedJointCount => joints.Count;
    public float LastPoseWeight { get; private set; }
    public float PeakAppliedDegrees { get; private set; }
    public bool LastWasShieldOnly { get; private set; }
    public long LastSequence => lastSequence;

    public static PlayerImpactFeedback20260925 Install(GameObject actor, BattlePrototype owner)
    {
        if (!actor) return null;
        var feedback = actor.GetComponent<PlayerImpactFeedback20260925>();
        if (!feedback) feedback = actor.AddComponent<PlayerImpactFeedback20260925>();
        feedback.battle = owner;
        feedback.choreography = actor.GetComponent<FoolSkillChoreography>();
        feedback.Map();
        var restore = actor.GetComponent<PlayerImpactRestore20260925>();
        if (!restore) restore = actor.AddComponent<PlayerImpactRestore20260925>();
        restore.feedback = feedback;
        return feedback;
    }

    void Map()
    {
        if (joints.Count > 0) return;
        var animator = GetComponentInChildren<Animator>(true);
        Add(animator, HumanBodyBones.Spine, new Vector3(-7f, 0, 1.5f), "Spine");
        Add(animator, HumanBodyBones.Chest, new Vector3(-6f, 0, -1f), "Spine1", "Chest");
        Add(animator, HumanBodyBones.Head, new Vector3(4f, 0, .5f), "Head");
    }

    void Add(Animator animator, HumanBodyBones id, Vector3 degrees, params string[] aliases)
    {
        Transform bone = animator && animator.isHuman ? animator.GetBoneTransform(id) : null;
        if (!bone)
            foreach (var candidate in GetComponentsInChildren<Transform>(true))
            {
                string name = candidate.name;
                int colon = name.LastIndexOf(':');
                if (colon >= 0) name = name.Substring(colon + 1);
                if (Array.IndexOf(aliases, name) >= 0) { bone = candidate; break; }
            }
        if (bone && !joints.Exists(j => j.bone == bone))
            joints.Add(new Joint { bone = bone, degrees = degrees });
    }

    public void BeginContext(string token)
    {
        if (token == context && !string.IsNullOrEmpty(context)) return;
        Clear(true);
        if (!string.IsNullOrWhiteSpace(token) && token.Length <= 80 && token.IndexOf(';') < 0)
            context = token;
    }

    // token;sequence;hpLoss;shieldLoss;maxHP;defeated(0/1);reduceMotion(0/1)
    // Sequence belongs to a visual context; retries/waves cannot accept its old packets.
    public bool Present(string payload)
    {
        var fields = (payload ?? "").Split(';');
        if (fields.Length != 7 || string.IsNullOrEmpty(context) || fields[0] != context
            || !long.TryParse(fields[1], NumberStyles.None, CultureInfo.InvariantCulture, out var sequence)
            || sequence <= lastSequence
            || !int.TryParse(fields[2], NumberStyles.None, CultureInfo.InvariantCulture, out var hpLoss)
            || !int.TryParse(fields[3], NumberStyles.None, CultureInfo.InvariantCulture, out var shieldLoss)
            || !int.TryParse(fields[4], NumberStyles.None, CultureInfo.InvariantCulture, out var maxHP)
            || hpLoss < 0 || shieldLoss < 0 || maxHP <= 0 || (hpLoss == 0 && shieldLoss == 0)
            || (fields[5] != "0" && fields[5] != "1") || (fields[6] != "0" && fields[6] != "1")
            || !battle || !battle.CanPresentPlayerImpact || !isActiveAndEnabled)
        { RejectedCount++; return false; }

        lastSequence = sequence;
        SpellSpectacle20260926.ReducedMotion = fields[6] == "1";
        // The authoritative defeat cue takes ownership immediately. Never fight
        // paper/shatter presentation with a late recoil, even in the same frame.
        if (fields[5] == "1") { Clear(true); return true; }
        Clear(false);
        LastWasShieldOnly = hpLoss == 0;
        float fraction = Mathf.Clamp01(((float)hpLoss + shieldLoss * .45f) / maxHP);
        strength = Mathf.Lerp(.65f, 1.15f, Mathf.Clamp01(fraction / .22f));
        if (LastWasShieldOnly) strength *= .50f;
        if (fields[6] == "1") strength *= .35f;
        started = Time.time;
        playing = true;
        PeakAppliedDegrees = 0;
        PlayCount++;
        return true;
    }

    public static float Envelope(float age)
    {
        if (float.IsNaN(age) || float.IsInfinity(age) || age < 0 || age >= Duration) return 0;
        if (age < .025f) return Mathf.SmoothStep(0, 1, age / .025f);
        if (age < .060f) return 1f;
        // A single small counter-settle, not indefinite vibration or hit stun.
        float t = (age - .060f) / (Duration - .060f);
        return Mathf.Cos(t * Mathf.PI * 1.15f) * (1f - t) * (1f - t);
    }

    void LateUpdate()
    {
        if (!playing) return;
        if (!battle || !battle.CanPresentPlayerImpact) { Clear(true); return; }
        float age = Time.time - started;
        if (age >= Duration) { Clear(false); return; }
        // A live cast keeps its authored wrist/arm/leg pose and timing. Torso
        // movement is attenuated; this layer never calls Begin/Clear on the cast.
        float castWeight = choreography && choreography.IsPlaying ? .42f : 1f;
        float pose = Envelope(age) * strength * castWeight;
        LastPoseWeight = pose;
        Quaternion actorSpace = transform.rotation;
        foreach (var joint in joints)
        {
            if (!joint.bone) continue;
            joint.before = joint.bone.localRotation;
            Quaternion delta = actorSpace * Quaternion.Euler(joint.degrees * pose) * Quaternion.Inverse(actorSpace);
            joint.bone.rotation = delta * joint.bone.rotation;
            joint.applied = joint.bone.localRotation;
            joint.written = true;
            PeakAppliedDegrees = Mathf.Max(PeakAppliedDegrees, Quaternion.Angle(joint.before, joint.applied));
        }
    }

    // Never inverse-multiply a possibly newer writer's pose. Early Update is
    // before idle/choreography restoration and Animator evaluation; equality
    // additionally protects synchronous cancel/replace calls between frames.
    public void RestoreOwnedPose()
    {
        foreach (var joint in joints)
        {
            if (joint.written && joint.bone && Quaternion.Angle(joint.bone.localRotation, joint.applied) < .001f)
                joint.bone.localRotation = joint.before;
            joint.written = false;
        }
    }

    public void Clear(bool invalidateContext = false)
    {
        RestoreOwnedPose(); playing = false; LastPoseWeight = 0;
        if (invalidateContext) { context = ""; lastSequence = 0; }
    }
    void OnDisable() => Clear(true);
    void OnDestroy() => Clear(true);
}

// Separate execution phase is intentional: DefaultExecutionOrder governs both
// Update and LateUpdate, so one component cannot be early in one and late in the other.
[DisallowMultipleComponent, DefaultExecutionOrder(-10000)]
public sealed class PlayerImpactRestore20260925 : MonoBehaviour
{
    [NonSerialized] public PlayerImpactFeedback20260925 feedback;
    void Update() { if (feedback) feedback.RestoreOwnedPose(); }
    void OnDisable() { if (feedback) feedback.Clear(true); }
}
