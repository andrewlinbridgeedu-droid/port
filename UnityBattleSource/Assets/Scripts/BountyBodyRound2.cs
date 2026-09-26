using System;
using System.Collections.Generic;
using UnityEngine;

// Local rig acting, composed before confirmed-hit feedback. Never moves EnemyRoot.
[DefaultExecutionOrder(1050), DisallowMultipleComponent]
public sealed class BountyBodyRound2 : MonoBehaviour
{
    sealed class Joint
    {
        public Transform bone;
        public Quaternion before, applied;
        public bool written;
        public int restoreMisses;
        public Vector3 beforePosition, appliedPosition;
        public bool positionWritten;
        public int positionRestoreMisses;
    }
    readonly Dictionary<string, Joint> joints = new Dictionary<string, Joint>();
    EnemyHandle handle;
    Transform actor;
    EarlyEnemyIdlePresence idle;
    FogGhostActor ghost;
    bool ownsIdlePause, preparedCarry, active, preparing, hit;
    string species, intent;
    bool authoredAnimation;
    int variation;
    float began, contact, hitAt;
    float lastPreparationAge, carriedPreparationAge;
    Vector3 visualBefore, visualApplied;
    bool moved;
    float rightUpper, rightLower, leftUpper, leftLower;
    Vector3 rightGripAxis = Vector3.up, leftGripAxis = Vector3.up;
    public int MappedJointCount => joints.Count;
    public bool IsPreparing => active && preparing;
    public bool IsPlaying => active;
    public bool HasWeaponGripRig
    {
        get
        {
            var weapon = Bone("weapon"); var right = Bone("rh"); var left = Bone("lh");
            return weapon && right && left && right.IsChildOf(weapon) && left.IsChildOf(weapon);
        }
    }
    public float MaximumWeaponGripError => HasWeaponGripRig
        ? Mathf.Max(GripError("re", "rh", rightLower, rightGripAxis), GripError("le", "lh", leftLower, leftGripAxis)) : 0;
    public Animator Animator => actor ? actor.GetComponentInChildren<Animator>() : null;
    public Vector3 TorsoPoint => Bone("chest") ? Bone("chest").position
        : handle ? handle.EnemyRoot.position + Vector3.up * .9f : transform.position;
    public Vector3 SourcePoint
    {
        get
        {
            if (species == "b03" && (intent == "heavy_strike" || preparing && intent == "charge"))
            {
                var left = Bone("lh"); var right = Bone("rh");
                if (left && right) return (left.position + right.position) * .5f;
            }
            return SourceBone ? SourceBone.position : handle.EnemyRoot.position + Vector3.up * 1.4f;
        }
    }
    Transform SourceBone
    {
        get
        {
            string key = intent == "guard" ? "chest" : species == "b05" && variation % 2 == 1 ? "lh" : "rh";
            return joints.TryGetValue(key, out var j) ? j.bone : joints.TryGetValue("chest", out j) ? j.bone : null;
        }
    }

    public void Configure(EnemyHandle owner, string kind)
    {
        handle = owner; species = kind;
        authoredAnimation = owner.ProfileEnemyId != null && owner.ProfileEnemyId.StartsWith("bounty-b", StringComparison.Ordinal);
        var restore = GetComponent<BountyPoseRestoreRound2>();
        if (!restore) restore = gameObject.AddComponent<BountyPoseRestoreRound2>();
        restore.owner = this;
    }

    void Map()
    {
        idle = handle.GetComponent<EarlyEnemyIdlePresence>();
        Transform visible = idle && idle.VisibleActor ? idle.VisibleActor : handle.Model;
        ghost = null;
        foreach (var candidate in handle.EnemyRoot.GetComponentsInChildren<FogGhostActor>())
            if (candidate.gameObject.activeInHierarchy) { ghost = candidate; visible = candidate.transform; break; }
        if (!visible) visible = handle.VisualRoot;
        if (actor == visible && joints.Count > 0) return;
        RestoreFrame(); actor = visible; joints.Clear();
        if (!actor) return;
        Add("hips", "Hips", "Pelvis", "pelvis");
        if (species == "b03") Add("chest", "Spine02", "Spine2", "Chest", "Spine01", "Spine", "UpperBody");
        else Add("chest", "Chest", "Belly", "ChestCore", "Cabinet", "Spine2", "Spine", "UpperBody");
        Add("head", "Head", "head");
        Add("ls", "Shoulder.L", "LeftShoulder", "L_Shoulder");
        Add("rs", "Shoulder.R", "RightShoulder", "R_Shoulder");
        Add("la", "UpperArm.L", "LeftArm", "LeftUpperArm", "L_UpperArm");
        Add("ra", "UpperArm.R", "RightArm", "RightUpperArm", "R_UpperArm");
        Add("le", "Forearm.L", "LeftForeArm", "LeftLowerArm", "L_Forearm");
        Add("re", "Forearm.R", "RightForeArm", "RightLowerArm", "R_Forearm");
        Add("lh", "Hand.L", "LeftHand"); Add("rh", "Hand.R", "RightHand", "Pen.R", "Valve");
        Add("lt", "Thigh.L", "LeftUpLeg", "UpperLeg.L"); Add("rt", "Thigh.R", "RightUpLeg", "UpperLeg.R");
        Add("lk", "Shin.L", "LeftLeg", "LowerLeg.L", "Calf.L"); Add("rk", "Shin.R", "RightLeg", "LowerLeg.R", "Calf.R");
        Add("back", "BackFrame", "Backpack"); Add("cloth", "CoatR", "SkirtFront2", "Veil", "Cape1.R");
        if (species == "b06")
        {
            Add("weapon", "Weapon");
            rightUpper = Distance("ra", "re"); rightLower = Distance("re", "rh");
            leftUpper = Distance("la", "le"); leftLower = Distance("le", "lh");
            rightGripAxis = GripAxis("re", "rh"); leftGripAxis = GripAxis("le", "lh");
        }
    }

    void Add(string key, params string[] aliases)
    {
        var all = actor.GetComponentsInChildren<Transform>(true);
        foreach (string alias in aliases) foreach (var bone in all)
        {
            if (!bone.gameObject.activeInHierarchy) continue;
            if (!bone.name.Equals(alias, StringComparison.OrdinalIgnoreCase) && !bone.name.EndsWith(":" + alias, StringComparison.OrdinalIgnoreCase)) continue;
            foreach (var existing in joints.Values) if (existing.bone == bone) return;
            joints[key] = new Joint { bone = bone }; return;
        }
    }

    public void Begin(string action, float contactTime, bool preparation, int alternate, bool carried = false)
    {
        // Identity clears the old owner before Begin, but explicitly tells us
        // whether this cast inherited its preparation. Never infer a new timer.
        float preparedAge = carried ? lastPreparationAge : 0;
        Clear(); Map(); if (!actor) return;
        intent = action.StartsWith("bounty_") ? action.Substring(7) : action;
        variation = alternate; contact = contactTime; preparing = preparation;
        preparedCarry = carried; began = Time.time; hit = false; active = true;
        carriedPreparationAge = preparedAge; lastPreparationAge = 0;
        if (idle && !idle.IsSuspended) { idle.SuspendForAction(); ownsIdlePause = true; }
    }
    public void Contact() { if (active && !preparing && !hit) { hit = true; hitAt = Time.time; } }

    void LateUpdate()
    {
        if (!active || !actor || !actor.gameObject.activeInHierarchy || !handle || !handle.gameObject.activeInHierarchy) { if (active) Clear(); return; }
        float age = Mathf.Max(0, Time.time - began);
        if (preparing) lastPreparationAge = age;
        if (!preparing && age > contact + .58f) { Clear(); return; }
        // The new eight actors have their own skinned Charge/Cast clips. Their
        // authored poses must not be overwritten by the legacy procedural layer.
        if (authoredAnimation) return;
        float f = Mathf.Clamp01(age / Mathf.Max(.01f, contact));
        float strike = preparing ? 0 : Mathf.SmoothStep(0, 1, (f - .44f) / .51f);
        if (hit) strike = 1;
        float enter = preparedCarry ? 1 : Mathf.SmoothStep(0, 1, age / .13f);
        float hold = species == "b02" ? BindingImpact20260921.Hold : species == "b06" ? .08f : .04f;
        float after = hit ? Time.time - hitAt : age - contact;
        float recover = preparing ? 1 : 1 - Mathf.SmoothStep(0, 1, (after - hold) / .34f);
        float energy = enter * recover;
        float breath = preparing ? Mathf.Sin(age * 3.6f) * .025f : 0;
        float turn = species == "b05" && variation % 2 == 1 ? -1 : 1;

        if (species == "b01")
        {
            // Existing sword animation remains; counter-twist and shoulder weight
            // clarify its diagonal release instead of adding a root spin.
            Pose("hips", V(5, -9, 2), V(-2, 8, -2), strike, energy);
            Pose("chest", V(11, -22, 6), V(5, 24, -9), strike, energy);
            Pose("ra", V(-20, -12, 19), V(24, 16, -28), strike, energy);
            Pose("re", V(-26, 0, 5), V(9, 0, -12), strike, energy);
            Pose("la", V(12, 0, -12), V(-16, 0, -20), strike, energy);
            Pose("head", V(5, 14, -3), V(-3, -12, 3), strike, energy);
        }
        else if (species == "b02")
        {
            Pose("hips", V(8, -8, 2), V(-3, 9, -2), strike, energy);
            Pose("chest", V(15, -15, 4), V(-7, 14, -6), strike, energy);
            Pose("back", V(-7, 3, 0), V(9, -3, 0), strike, energy);
            Pose("ls", V(4, -8, -7), V(-7, 10, 8), strike, energy);
            Pose("rs", V(4, 8, 7), V(-7, -10, -8), strike, energy);
            Pose("la", V(18, -15, -30), V(-35, 8, -12), strike, energy);
            Pose("ra", V(23, 12, 28), V(-42, -12, 16), strike, energy);
            Pose("le", V(-40, 0, -9), V(-9, 0, 10), strike, energy);
            Pose("re", V(-47, 0, 9), V(-8, 0, -13), strike, energy);
            Pose("rh", V(8, 15, -12), V(-16, -9, 16), strike, energy);
            Legs(strike, energy, 10);
        }
        else if (species.StartsWith("b03"))
        {
            bool heavy = intent == "heavy_strike" || species == "b03" && preparing && intent == "charge";
            bool escort = species == "b03-escort";
            if (!escort && ghost && !preparing)
            {
                // FogGhost's common cast opens both arms even for an ordinary
                // attack. Remove only that known arm overlay in this bounty's
                // own layer; keep its breathing/float and leave escorts untouched.
                float common = Mathf.Sin(Mathf.Clamp01(age * (ghost.IsSplit ? 1.5f : 1) / 1.1f) * Mathf.PI);
                PoseLocal("la", V(0, 0, -28 * common), Vector3.zero, 0, 1);
                PoseLocal("ra", V(0, 0, 40 * common), Vector3.zero, 0, 1);
            }
            if (escort)
            {
                // Keep the independently re-recorded escort gesture unchanged.
                float strength = heavy ? 1 : .52f;
                Pose("chest", V(10, -15, 7), V(-11, 13, -5), strike, energy * strength);
                Pose("head", V(10, 8, 0), V(-8, -10, 2), strike, energy * strength);
                Pose("la", V(18, -16, -22), V(-26, 10, 17), strike, energy * (heavy ? 1 : .35f));
                Pose("ra", V(20, 15, 29), V(-39, -8, -23), strike, energy * strength);
                Pose("le", V(-22, 0, 0), V(12, 0, -10), strike, energy * strength);
                Pose("re", V(-29, 0, 12), V(15, 0, -12), strike, energy * strength);
                Pose("cloth", V(-7, 0, 8), V(10, 0, -10), strike, energy * strength);
                MoveVisual((-Mathf.Sin(f * Mathf.PI) * .11f + strike * .10f) * energy * strength);
            }
            else if (heavy)
            {
                float arms = preparing ? 0 : Mathf.SmoothStep(0, 1, (f - .24f) / .70f);
                if (hit) arms = 1;
                Pose("chest", V(12, -6, 2), V(-13, 8, -5), strike, energy);
                Pose("head", V(9, 5, 0), V(-7, -7, 2), strike, energy);
                Pose("ls", V(2, -7, -8), V(-5, 9, 7), arms, energy);
                Pose("rs", V(2, 8, 8), V(-6, -11, -9), arms, energy);
                Pose("la", V(8, -26, -33), V(-30, 18, 29), arms, energy);
                Pose("ra", V(11, 28, 34), V(-40, -20, -31), arms, energy);
                Pose("le", V(-47, -12, -8), V(14, 13, 11), arms, energy);
                Pose("re", V(-51, 14, 9), V(20, -16, -13), arms, energy);
                Pose("lh", V(8, -12, -9), V(-10, 18, 13), arms, energy);
                Pose("rh", V(11, 15, 11), V(-13, -21, -16), arms, energy);
                Pose("cloth", V(-7, 0, 8), V(10, 0, -10), strike, energy);
                MoveVisual((-Mathf.Sin(f * Mathf.PI) * .11f + strike * .10f) * energy);
            }
            else
            {
                // Single forearm leads the short water edge; the other hand
                // counterbalances instead of joining the heavy two-arm gather.
                Pose("chest", V(4, -13, 2), V(3, 14, -5), strike, energy);
                Pose("head", V(4, 8, 0), V(-3, -8, 1), strike, energy);
                Pose("ra", V(7, 20, 18), V(-30, -12, -31), strike, energy);
                Pose("re", V(-25, 0, 8), V(8, -12, -17), strike, energy);
                Pose("rh", V(12, 8, -9), V(-15, -12, 19), strike, energy);
                Pose("la", V(4, -4, -5), V(-6, 7, 8), strike, energy);
                Pose("le", V(-7, 0, -3), V(-3, 0, 5), strike, energy);
                Pose("cloth", V(-3, 0, 4), V(4, 0, -5), strike, energy);
                MoveVisual((-Mathf.Sin(f * Mathf.PI) * .05f + strike * .035f) * energy);
            }
        }
        else if (species == "b04")
        {
            Pose("hips", V(3, -11, 1), V(1, 12, -2), strike, energy);
            Pose("chest", V(7, -25, 8), V(5, 29, -12), strike, energy);
            Pose("rs", V(0, -14, 13), V(0, 18, -12), strike, energy);
            Pose("ra", V(-25, -20, 35), V(12, 31, -28), strike, energy);
            Pose("re", V(-42, 4, 15), V(-4, -15, -24), strike, energy);
            Pose("rh", V(12, 16, -25), V(-17, -25, 19), strike, energy);
            Pose("la", V(12, 7, -17), V(-8, -13, -26), strike, energy);
            Pose("head", V(4, 17, -2), V(-3, -19, 4), strike, energy);
        }
        else if (species == "b05")
        {
            bool basic = intent == "strike"; float strength = basic ? .55f : 1;
            Pose("hips", V(3, -10 * turn, 2), V(1, 12 * turn, -2), strike, energy * strength);
            Pose("chest", V(-2, -24 * turn, 9), V(9, 27 * turn, -10), strike, energy * strength);
            if (basic)
            {
                bool left = variation % 2 == 1;
                Pose(left ? "la" : "ra", V(-14, -16 * turn, 21 * turn), V(-34, 18 * turn, -24 * turn), strike, energy);
                Pose(left ? "le" : "re", V(-29, 8 * turn, 12 * turn), V(-5, -13 * turn, -14 * turn), strike, energy);
                Pose(left ? "lh" : "rh", V(7, -12 * turn, 18 * turn), V(-9, 18 * turn, -24 * turn), strike, energy);
                Pose(left ? "ra" : "la", V(6, 6 * turn, -9 * turn), V(11, -9 * turn, 13 * turn), strike, energy);
            }
            else
            {
                Pose("la", V(-23, -14, -32), V(13, 20, -12), strike, energy);
                Pose("ra", V(14, 20, 14), V(-38, -18, 34), strike, energy);
                Pose("le", V(-26, 0, -12), V(-8, 9, 15), strike, energy);
                Pose("re", V(-37, 4, 16), V(-8, -12, -22), strike, energy);
                Pose("lh", V(8, 10, -18), V(-9, -12, 22), strike, energy);
                Pose("rh", V(13, -9, 18), V(-12, 18, -24), strike, energy);
            }
            Pose("cloth", V(0, 6 * turn, -5), V(0, -12 * turn, 8), strike, energy);
        }
        else if (species == "b06")
        {
            bool guarded = intent == "guard";
            Pose("hips", V(9, -3, 0), V(5, 5, 0), strike, energy);
            Pose("chest", guarded ? V(12, -4, 2) : V(-12, -9, 3), V(21, 9, -4), strike, energy);
            if (HasWeaponGripRig)
            {
                // This exported rig parents both hands to Weapon, not to the
                // forearms. Move the real hammer first, then close both arms onto
                // its existing grip points; arm-only rotations detach the hands.
                PoseLocal("weapon", guarded ? V(-13, 0, 9) : V(-43, -7, -4), V(31, 8, -2), strike, energy);
                if (!guarded) FitWeaponToArmReach();
                SolveGrip("ra", "re", "rh", rightUpper, rightLower, rightGripAxis, 1);
                SolveGrip("la", "le", "lh", leftUpper, leftLower, leftGripAxis, -1);
            }
            else
            {
                Pose("la", guarded ? V(-18, 24, 27) : V(-58, -13, -14), V(27, 8, -8), strike, energy);
                Pose("ra", guarded ? V(-18, -24, -27) : V(-64, 16, 19), V(33, -8, 12), strike, energy);
                Pose("le", V(-38, 0, 7), V(-5, 0, -8), strike, energy);
                Pose("re", V(-44, 0, -7), V(-9, 0, 8), strike, energy);
            }
            Pose("head", V(-5, 4, 0), V(10, -4, 0), strike, energy);
            Legs(strike, energy, guarded ? 7 : 14);
        }
        ApplyPreparationProgress(age, strike, energy);
        if (preparing) Pose("head", V(breath * 24, breath * 16, 0), Vector3.zero, 0, 1);
    }

    void ApplyPreparationProgress(float age, float strike, float energy)
    {
        if (species != "b01" && species != "b02" && species != "b03") return;
        float weight = energy * (preparing ? 1 : preparedCarry ? 1 - strike : 0);
        if (weight <= .0001f) return;
        float poseAge = preparing ? age : carriedPreparationAge;
        float shoulder = Mathf.SmoothStep(0, 1, (poseAge - .15f) / 1.55f);
        float elbow = Mathf.SmoothStep(0, 1, (poseAge - .80f) / 2.25f);
        float draw = Mathf.SmoothStep(0, 1, poseAge / 3.15f);
        float breath = Mathf.Sin(poseAge * 2.6f) * .8f;
        if (species == "b01")
        {
            Pose("hips", V(1.5f * draw, 2 * draw, 0), Vector3.zero, 0, weight);
            Pose("chest", V(3 * draw + breath, -7 * draw, 2 * shoulder), Vector3.zero, 0, weight);
            Pose("rs", V(-2 * shoulder, -3 * shoulder, 4 * shoulder), Vector3.zero, 0, weight);
            Pose("ra", V(-4 * shoulder, -4 * draw, 5 * shoulder), Vector3.zero, 0, weight);
            Pose("re", V(-9 * elbow, 0, 3 * elbow), Vector3.zero, 0, weight);
            Pose("la", V(2 * draw, 0, -3 * shoulder), Vector3.zero, 0, weight);
            Pose("head", V(-1.5f * draw, 3 * draw, 0), Vector3.zero, 0, weight);
        }
        else if (species == "b02")
        {
            Pose("chest", V(5 * draw + breath, -4 * shoulder, 1.5f * draw), Vector3.zero, 0, weight);
            Pose("back", V(-4 * draw, 1.5f * shoulder, 0), Vector3.zero, 0, weight);
            Pose("ls", V(2 * shoulder, -3 * shoulder, -3 * draw), Vector3.zero, 0, weight);
            Pose("rs", V(3 * shoulder, 4 * shoulder, 4 * draw), Vector3.zero, 0, weight);
            Pose("la", V(3 * shoulder, -2 * draw, -3 * elbow), Vector3.zero, 0, weight);
            Pose("ra", V(5 * shoulder, 3 * draw, 4 * elbow), Vector3.zero, 0, weight);
            Pose("le", V(-6.5f * elbow, 0, -2 * elbow), Vector3.zero, 0, weight);
            Pose("re", V(-10 * elbow, 0, 3 * elbow), Vector3.zero, 0, weight);
            Pose("head", V(-2 * draw, 2 * shoulder, 0), Vector3.zero, 0, weight);
        }
        else
        {
            Pose("chest", V(4 * draw + breath, -3 * draw, 0), Vector3.zero, 0, weight);
            Pose("ls", V(2 * shoulder, -4 * draw, -2 * shoulder), Vector3.zero, 0, weight);
            Pose("rs", V(3 * shoulder, 5 * draw, 3 * shoulder), Vector3.zero, 0, weight);
            Pose("la", V(3 * shoulder, -5 * elbow, -3 * elbow), Vector3.zero, 0, weight);
            Pose("ra", V(4 * shoulder, 6 * elbow, 4 * elbow), Vector3.zero, 0, weight);
            Pose("le", V(-8 * elbow, -3 * elbow, 0), Vector3.zero, 0, weight);
            Pose("re", V(-10 * elbow, 4 * elbow, 0), Vector3.zero, 0, weight);
            Pose("head", V(-2 * draw, 2 * draw, 0), Vector3.zero, 0, weight);
        }
    }

    void Legs(float strike, float energy, float amount)
    {
        Pose("lt", V(-amount, 0, -2), V(amount * .35f, 0, 1), strike, energy);
        Pose("rt", V(-amount * .7f, 0, 2), V(amount * .25f, 0, -1), strike, energy);
        Pose("lk", V(amount * 1.4f, 0, 0), V(-amount * .2f, 0, 0), strike, energy);
        Pose("rk", V(amount, 0, 0), V(-amount * .1f, 0, 0), strike, energy);
    }
    static Vector3 V(float x, float y, float z) => new Vector3(x, y, z);
    Transform Bone(string key) => joints.TryGetValue(key, out var joint) ? joint.bone : null;
    float Distance(string a, string b)
    {
        var first = Bone(a); var second = Bone(b);
        return first && second ? Vector3.Distance(first.position, second.position) : 0;
    }
    Vector3 GripAxis(string elbow, string hand)
    {
        var e = Bone(elbow); var h = Bone(hand);
        return e && h ? e.InverseTransformDirection(h.position - e.position).normalized : Vector3.up;
    }
    float GripError(string elbow, string hand, float length, Vector3 axis)
    {
        var e = Bone(elbow); var h = Bone(hand);
        return e && h ? Vector3.Distance(e.position + e.rotation * axis * length, h.position) : 0;
    }
    static void Save(Joint j)
    {
        if (j.written) return;
        j.before = j.bone.localRotation; j.written = true; j.restoreMisses = 0;
    }
    void PoseLocal(string key, Vector3 windup, Vector3 strike, float blend, float weight)
    {
        if (!joints.TryGetValue(key, out var j) || !j.bone || weight <= .0001f) return;
        Save(j); j.bone.localRotation *= Quaternion.Euler(Vector3.Lerp(windup, strike, blend) * weight);
        j.applied = j.bone.localRotation;
    }
    void TurnWorld(string key, Quaternion delta)
    {
        if (!joints.TryGetValue(key, out var j) || !j.bone) return;
        Save(j); j.bone.rotation = delta * j.bone.rotation; j.applied = j.bone.localRotation;
    }
    void FitWeaponToArmReach()
    {
        if (!joints.TryGetValue("weapon", out var weapon) || !weapon.bone) return;
        // The authored Charge plus our local hammer rotation can put a real
        // grip beyond its shoulder's two-bone reach. Move the rigid weapon and
        // BOTH attached hands together before solving elbows; keep bone lengths.
        // Alternating the two reach constraints avoids fixing one hand by
        // pushing the other out. Guard already fits and does not enter here.
        for (int pass = 0; pass < 10; pass++)
        {
            bool right = FitWeaponGrip(weapon, "ra", "rh", rightUpper + rightLower);
            bool left = FitWeaponGrip(weapon, "la", "lh", leftUpper + leftLower);
            if (!right && !left) break;
        }
    }
    bool FitWeaponGrip(Joint weapon, string shoulderKey, string handKey, float armLength)
    {
        var shoulder = Bone(shoulderKey); var hand = Bone(handKey);
        if (!shoulder || !hand || armLength <= .002f) return false;
        Vector3 delta = hand.position - shoulder.position;
        float distance = delta.magnitude, maximum = armLength * .98f;
        if (distance <= maximum + .00001f) return false;
        if (!weapon.positionWritten)
        {
            weapon.beforePosition = weapon.bone.localPosition;
            weapon.positionWritten = true; weapon.positionRestoreMisses = 0;
        }
        weapon.bone.position -= delta * ((distance - maximum) / distance);
        weapon.appliedPosition = weapon.bone.localPosition;
        return true;
    }
    void SolveGrip(string upperKey, string elbowKey, string handKey, float upperLength, float lowerLength, Vector3 gripAxis, float side)
    {
        var shoulder = Bone(upperKey); var elbow = Bone(elbowKey); var hand = Bone(handKey);
        if (!shoulder || !elbow || !hand || upperLength <= .001f || lowerLength <= .001f) return;
        Vector3 axis = hand.position - shoulder.position; float distance = axis.magnitude;
        if (distance <= .001f) return;
        axis /= distance;
        float reach = Mathf.Clamp(distance, Mathf.Abs(upperLength - lowerLength) + .001f, upperLength + lowerLength - .001f);
        Vector3 pole = Vector3.ProjectOnPlane(elbow.position - shoulder.position, axis).normalized;
        if (pole.sqrMagnitude < .1f) pole = Vector3.ProjectOnPlane(actor.right * side + actor.up * .15f, axis).normalized;
        if (pole.sqrMagnitude < .1f) return;
        float along = (upperLength * upperLength - lowerLength * lowerLength + reach * reach) / (2 * reach);
        Vector3 bend = shoulder.position + axis * along + pole * Mathf.Sqrt(Mathf.Max(0, upperLength * upperLength - along * along));
        TurnWorld(upperKey, Quaternion.FromToRotation(elbow.position - shoulder.position, bend - shoulder.position));
        Vector3 aim = elbow.rotation * gripAxis, grip = hand.position - elbow.position;
        if (aim.sqrMagnitude > .0001f && grip.sqrMagnitude > .0001f)
            TurnWorld(elbowKey, Quaternion.FromToRotation(aim, grip));
    }
    void Pose(string key, Vector3 windup, Vector3 strike, float blend, float weight)
    {
        if (!joints.TryGetValue(key, out var j) || !j.bone || weight <= .0001f) return;
        Save(j);
        Vector3 angles = Vector3.Lerp(windup, strike, blend) * weight;
        Quaternion delta = actor.rotation * Quaternion.Euler(angles) * Quaternion.Inverse(actor.rotation);
        j.bone.rotation = delta * j.bone.rotation; j.applied = j.bone.localRotation;
    }
    void MoveVisual(float worldY)
    {
        if (!actor || actor == handle.EnemyRoot || actor == handle.transform) return;
        visualBefore = actor.localPosition;
        Vector3 shift = actor.parent ? actor.parent.InverseTransformVector(Vector3.up * worldY) : Vector3.up * worldY;
        visualApplied = visualBefore + shift; actor.localPosition = visualApplied; moved = true;
    }

    // Called after confirmed-impact Update has removed its own previous offset.
    // Keep a one-frame deferred restoration when another active owner is on top.
    public void RestoreFrame()
    {
        foreach (var j in joints.Values)
        {
            if (!j.bone) continue;
            if (j.written)
            {
                if (Quaternion.Angle(j.bone.localRotation, j.applied) < .003f) { j.bone.localRotation = j.before; j.written = false; }
                else if (++j.restoreMisses > 1) j.written = false;
            }
            if (j.positionWritten)
            {
                if ((j.bone.localPosition - j.appliedPosition).sqrMagnitude < 1e-12f) { j.bone.localPosition = j.beforePosition; j.positionWritten = false; }
                else if (++j.positionRestoreMisses > 1) j.positionWritten = false;
            }
        }
        if (moved && actor) { if ((actor.localPosition - visualApplied).sqrMagnitude < .000001f) actor.localPosition = visualBefore; moved = false; }
    }
    public void Clear()
    {
        active = false; preparing = false; RestoreFrame();
        if (ownsIdlePause && idle) idle.ResumeIdle(); ownsIdlePause = false;
    }
    void OnDisable() { Clear(); }
    void OnDestroy() { Clear(); }
}
