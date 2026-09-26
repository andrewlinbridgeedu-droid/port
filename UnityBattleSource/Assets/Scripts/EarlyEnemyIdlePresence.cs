using System;
using System.Collections.Generic;
using UnityEngine;

/// Adds rig-specific presence to every enemy during pre-battle and combat idle.
///
/// This component owns only local bone rotations below an EnemyHandle's
/// VisualRoot. It never moves EnemyRoot/MotionRoot, changes an Animator, or
/// creates combat/VFX callbacks. BattlePrototype can install it after an
/// EnemyHandle is presented and suspend it around an action or death.
[DisallowMultipleComponent]
[DefaultExecutionOrder(1000)]
public sealed class EarlyEnemyIdlePresence : MonoBehaviour
{
    public static bool ArtPolishEnabled = true;
    public enum IdleArchetype
    {
        Auto,
        Humanoid,
        Hound,
        FogGhost,
        Revenant,
        MechanicalGuard,
        Threadweaver,
        MemoryLeech,
        LivingCore
    }

    [Serializable]
    struct BoneOffset
    {
        public string role;
        public Transform bone;
        public Quaternion baseRotation;
        public Quaternion lastResult;
        public bool hasBase;

        public BoneOffset(string name, Transform transform)
        {
            role = name;
            bone = transform;
            baseRotation = Quaternion.identity;
            lastResult = Quaternion.identity;
            hasBase = false;
        }
    }

    [SerializeField] IdleArchetype archetype = IdleArchetype.Auto;
    [SerializeField, Min(0.1f)] float cycleSeconds = 3.8f;
    [SerializeField, Range(0f, 1f)] float intensity = 0.72f;

    EnemyHandle handle;
    Transform explicitVisual;
    Transform visualActor;
    Animator animator;
    Animation legacyAnimation;
    FogGhostActor ghostActor;
    ClockCoreIdlePresence corePresence;
    bool bonesCached;
    struct PlantedBone
    {
        public Transform bone;
        public Quaternion restRotation, previousRotation;
        public Vector3 restPosition, previousPosition;
    }
    readonly List<PlantedBone> plantedBones = new List<PlantedBone>();
    bool plantedApplied;
    int missionNumber;
    Transform gaitGroundWrapper, gaitGroundActor, gaitOriginalParent;
    public float GaitGroundOffset { get; private set; }
    public float ContinuousGroundCorrection => GaitGroundOffset;
    public float GaitSampleMinimumY { get; private set; }
    public float GaitSampleMaximumY { get; private set; }
    public void SetMission(int number)
    {
        if (missionNumber == number) return;
        RestoreBoneOffsets();
        ReleaseGaitGround();
        missionNumber = number;
        CalibrateContinuousGaitGround();
    }
    public bool UsesContinuousEarlyHoundGait => handle != null
        && handle.ProfileEnemyId == "early-hell-hound" && (missionNumber == 3 || missionNumber == 4);
    public float PlantedSkinBeforeY { get; private set; }
    public float PlantedSkinAfterY { get; private set; }
    public float PlantedGroundCorrection { get; private set; }
    Quaternion visualBaseRotation;
    Quaternion visualLastRotation;
    Vector3 visualBaseScale;
    Vector3 visualLastScale;
    bool visualPoseCached;
    readonly List<BoneOffset> bones = new List<BoneOffset>();
    float phase;
    bool suspended;
    bool dead;
    bool speaking;
    bool configured;
    bool archetypeWasAuto;

    /// The installed handle, for diagnostics and callers that need to verify
    /// that a recycled actor has a live presence component.
    public EnemyHandle Handle => handle;
    public Transform VisibleActor => visualActor;
    public bool IsSuspended => suspended || dead;
    public bool IsSpeaking => speaking;
    public bool IsConfigured => configured && handle != null;
    public IdleArchetype Archetype => archetype;
    public int MappedBoneCount => bones.Count;
    public int AnimatedVertexCount => corePresence != null ? corePresence.AnimatedVertexCount : 0;
    public float MaximumVertexOffset => corePresence != null ? corePresence.MaximumVertexOffset : 0;
    public bool IsAnimatingIdle => CanAnimateIdle();
    public string MappedRoles => string.Join(",", bones.ConvertAll(b => b.role));
    float blend;

    /// Install the component on the EnemyHandle root. This is the intended
    /// BattlePrototype entry point for an early encounter.
    public static EarlyEnemyIdlePresence Install(EnemyHandle enemyHandle)
    {
        return Install(enemyHandle, IdleArchetype.Auto, null);
    }

    /// Install with an explicit visual archetype when profile IDs are not
    /// stable (for example, a legacy FogGhost instance).
    public static EarlyEnemyIdlePresence Install(
        EnemyHandle enemyHandle,
        IdleArchetype requestedArchetype,
        Transform visibleVisual = null)
    {
        if (enemyHandle == null)
            return null;

        var presence = enemyHandle.GetComponent<EarlyEnemyIdlePresence>();
        if (presence == null)
            presence = enemyHandle.gameObject.AddComponent<EarlyEnemyIdlePresence>();
        presence.Configure(enemyHandle, requestedArchetype, visibleVisual);
        return presence;
    }

    /// Rebind after EnemyPresenter has recycled a handle or swapped its model.
    /// Rebinding restores the old local rotations before inspecting the new
    /// model, so an inactive variant cannot inherit a previous idle pose.
    public void Configure(
        EnemyHandle enemyHandle,
        IdleArchetype requestedArchetype = IdleArchetype.Auto,
        Transform visibleVisual = null)
    {
        RestoreBoneOffsets();
        ReleaseGaitGround();
        handle = enemyHandle;
        explicitVisual = visibleVisual;
        archetypeWasAuto = requestedArchetype == IdleArchetype.Auto;
        archetype = requestedArchetype == IdleArchetype.Auto
            ? InferArchetype(enemyHandle)
            : requestedArchetype;
        visualActor = ResolveVisibleActor();
        ApplyVisibleActorArchetype();
        CacheVisualPose();
        animator = visualActor != null
            ? visualActor.GetComponentInChildren<Animator>(true)
            : null;
        CacheSecondaryPlayers();
        phase = StablePhase(handle);
        suspended = false;
        dead = false;
        speaking = false;
        configured = handle != null;
        CacheBones();
    }

    /// Pause before an authored cast/attack/reaction. The current Animator
    /// pose is preserved because only this component's previous offsets are
    /// removed. ResumeIdle may be called after the action has returned to Idle.
    public void SuspendForAction() => SetSuspended(true);
    public void ResumeIdle() => SetSuspended(false);

    /// Optional mouth/head beat for a short line owned by BattlePrototype.
    /// This changes pose only; the component deliberately owns no text/audio.
    public void SetSpeaking(bool value)
    {
        speaking = value;
        if (!value && !CanAnimateIdle()) RestoreBoneOffsets();
    }

    /// Mark a defeated actor. This is separate from GameObject.SetActive so a
    /// caller can clear the motion on the contact frame before pooled disable.
    public void SetDead(bool value)
    {
        dead = value;
        if (value) RestoreBoneOffsets();
    }

    /// Explicit alias for pooled encounter teardown. It is safe to call more
    /// than once and does not destroy the component or the EnemyHandle.
    public void Clear()
    {
        RestoreBoneOffsets();
        ReleaseGaitGround();
        handle = null;
        explicitVisual = null;
        visualActor = null;
        animator = null;
        legacyAnimation = null;
        ghostActor = null;
        visualPoseCached = false;
        bones.Clear();
        bonesCached = false;
        if (corePresence != null) corePresence.Release();
        configured = false;
        archetypeWasAuto = false;
        suspended = false;
        dead = false;
        speaking = false;
    }

    void Awake()
    {
        var existingHandle = GetComponent<EnemyHandle>();
        if (existingHandle != null && !configured)
            Configure(existingHandle, IdleArchetype.Auto);
    }

    void OnEnable()
    {
        // An EnemyHandle can be pooled and enabled after its model has been
        // rebound. Refresh references without touching the formation root.
        if (handle == null)
        {
            var existingHandle = GetComponent<EnemyHandle>();
            if (existingHandle != null)
                Configure(existingHandle, IdleArchetype.Auto);
        }
        else
        {
            RestoreBoneOffsets();
            visualActor = ResolveVisibleActor();
            ApplyVisibleActorArchetype();
            CacheVisualPose();
            animator = visualActor != null
                ? visualActor.GetComponentInChildren<Animator>(true)
                : null;
            CacheSecondaryPlayers();
            CacheBones();
        }
    }

    void OnDisable() => RestoreBoneOffsets();

    void LateUpdate()
    {
        RefreshVisibleActor();
        if (!CanAnimateIdle())
        {
            RestoreBoneOffsets();
            blend = 0f;
            return;
        }

        if (BonesNeedRefresh())
            CacheBones();

        ApplyPlantedHoundPose();
        PrepareFrame();
        // Never write the actor transform: authored floating and formation own it.

        var time = Time.time + phase;
        var breath = Mathf.Sin(time * Mathf.PI * 2f / Mathf.Max(0.1f, cycleSeconds));
        var sway = Mathf.Sin(time * Mathf.PI * 2f / Mathf.Max(0.1f, cycleSeconds * 1.73f));
        blend = Mathf.MoveTowards(blend, 1f, Time.deltaTime * 3.5f);
        var accent = intensity * Mathf.SmoothStep(0f, 1f, blend);
        var glance = Mathf.Sin(time * .47f) * Mathf.Sin(time * .19f);
        var settle = 0f;
        if (ArtPolishEnabled) {
            // Inhale, brief hold, longer exhale: avoid identical metronomic motion.
            var breathingPhase = Mathf.Repeat(time / Mathf.Max(.1f,cycleSeconds),1);
            breath = breathingPhase < .38f
                ? Mathf.Lerp(-1,1,Mathf.SmoothStep(0,1,breathingPhase/.38f))
                : Mathf.Lerp(1,-1,Mathf.SmoothStep(0,1,(breathingPhase-.38f)/.62f));
            // An intentional look has a turn, hold and return, separated by rest.
            glance = Gesture(time,12.6f,1.2f,4.7f)-.65f*Gesture(time,12.6f,7.1f,10.3f);
            settle = Gesture(time,9.7f,3.1f,5.6f);
        }

        if (ArtPolishEnabled)
        {
            ApplyCharacterPerformance(time, breath, glance, settle, accent);
            return;
        }

        // Keep the root and hips untouched. The actor stays on its authored
        // floor/formation anchor while only the silhouette breathes.
        switch (archetype)
        {
            case IdleArchetype.LivingCore:
                if (corePresence != null) corePresence.Evaluate(time, accent);
                break;
            case IdleArchetype.Hound:
                Apply("chest", new Vector3(-1.8f * breath, 0f, 0.9f * sway) * accent);
                Apply("neck", new Vector3(0.5f * breath, 1.8f * sway, 0f) * accent);
                Apply("head", new Vector3(1.2f * breath, 2.5f * sway + 2f * glance, 0f) * accent);
                Apply("jaw", new Vector3(1.8f + 1.0f * breath, 0f, 0f) * accent);
                ApplyTail(time, accent);
                // Paws remain planted; chest/neck counter-motion shifts the silhouette.
                Apply("leftEar", new Vector3(2f * breath, 4f * glance, 0) * accent);
                Apply("rightEar", new Vector3(-1.5f * breath, -3f * glance, 0) * accent);
                break;

            case IdleArchetype.FogGhost:
                Apply("chest", new Vector3(-1.2f * breath, 1.4f * sway, 0.6f * breath) * accent);
                Apply("head", new Vector3(1.0f * breath, 3.2f * sway + 3f * glance, 0f) * accent);
                // Add only while FogGhostActor is idle. Its cast pose is exclusive.
                Apply("leftUpperArm", new Vector3(2.4f * Mathf.Sin(time * .93f), 1.8f * sway, 3f * breath) * accent);
                Apply("rightUpperArm", new Vector3(-2.1f * Mathf.Sin(time * .93f + 1.1f), -1.8f * sway, -3f * breath) * accent);
                break;

            case IdleArchetype.Revenant:
                Apply("chest", new Vector3(-2f * breath, 1.7f * sway, .7f * breath) * accent);
                Apply("head", new Vector3(1.3f * breath, 5f * glance, 1f * sway) * accent);
                Apply("leftUpperArm", new Vector3(1.7f * breath, 0, 1.8f * sway) * accent);
                Apply("rightUpperArm", new Vector3(-1.3f * breath, 0, -2.4f * sway) * accent);
                Apply("leftHand", new Vector3(1.4f * sway, 2f * breath, 0) * accent);
                Apply("rightHand", new Vector3(-1.7f * sway, -2f * breath, 0) * accent);
                ApplyCloth(time, accent);
                break;
            case IdleArchetype.MechanicalGuard:
                // Deliberate scan, torso pressure and wrist servo settling.
                Apply("chest", new Vector3(-.9f * breath, 1.3f * sway, .5f * breath) * accent);
                Apply("head", new Vector3(.8f * breath, 6f * glance, 0) * accent);
                Apply("leftUpperArm", new Vector3(1.4f * breath + 2f * settle, .7f * sway, .8f * breath) * accent);
                Apply("rightUpperArm", new Vector3(-.8f * breath, -.8f * sway, -.6f * breath) * accent);
                Apply("leftHand", new Vector3(0, 2.6f * Mathf.Sin(time * .61f), 1.2f * breath) * accent);
                Apply("rightHand", new Vector3(0, -2.1f * Mathf.Sin(time * .61f + .8f), -1.2f * breath) * accent);
                break;
            case IdleArchetype.Threadweaver:
                Apply("chest", new Vector3(-1.2f * breath, 1.6f * sway, .7f * breath) * accent);
                Apply("neck", new Vector3(.5f * breath, 1f * glance, 0) * accent);
                Apply("head", new Vector3(1.1f * breath, 3.5f * glance, 1.2f * sway) * accent);
                Apply("leftUpperArm", new Vector3(1f * breath, 1.2f * sway, 1.6f * breath) * accent);
                Apply("rightUpperArm", new Vector3(-.8f * breath, -1f * sway, -1.3f * breath) * accent);
                Apply("leftHand", new Vector3(3f * Mathf.Sin(time * .8f) + 3f * settle, 2f * sway, 0) * accent);
                Apply("rightHand", new Vector3(3f * Mathf.Sin(time * .8f + 1.4f), -2f * sway, 0) * accent);
                ApplyCloth(time, accent);
                break;
            case IdleArchetype.MemoryLeech:
                for (var segment = 0; segment < 7; segment++)
                    Apply("segment" + segment, new Vector3(1.8f * Mathf.Sin(time * 1.1f - segment * .6f), 3.8f * Mathf.Sin(time * .79f - segment * .5f) + (ArtPolishEnabled ? 1.7f * Gesture(time - segment * .16f,8.8f,2,4.9f) : 0), 1.2f * Mathf.Sin(time * .63f + segment)) * accent);
                break;
            default:
                Apply("chest", new Vector3(-1.4f * breath, 1.6f * sway, 0.8f * breath) * accent);
                Apply("neck", new Vector3(0.7f * breath, 1.2f * sway, 0f) * accent);
                Apply("head", new Vector3(1.1f * breath, 3.0f * sway, 0f) * accent);
                if (speaking)
                    Apply("jaw", new Vector3(3.2f + 2.2f * Mathf.Sin(time * 8.5f), 0f, 0f) * accent);
                ApplyShoulders(breath, sway, accent);
                break;
        }
    }

    // Gestures are separated by stillness and propagated down the body with
    // a delay. No root/hip translation, Animator speed or combat event is owned here.
    void ApplyCharacterPerformance(float time, float breath, float glance, float settle, float amount)
    {
        float delayed = Gesture(time - .32f, 9.7f, 3.1f, 5.6f);
        float release = Gesture(time - .65f, 9.7f, 3.1f, 5.6f);
        if (archetype == IdleArchetype.LivingCore)
        {
            if (corePresence != null) corePresence.Evaluate(time, amount);
            return;
        }
        // These two rigs carry story-specific props. The loaded arm stays firm;
        // the free elbow and gaze do the acting, rather than waving both arms.
        if (bones.Exists(b => b.role == "pen"))
        {
            // Once per sixteen seconds: notice, raise the pen, inspect its nib,
            // then lower it. The loaded left arm/ledger stays close to the chest.
            float notice = Gesture(time, 16f, 2f, 7.5f);
            float penLift = Gesture(time - .55f, 16f, 2f, 7.5f);
            float wrist = Gesture(time - .85f, 16f, 2f, 7.5f);
            Apply("chest", new Vector3(-1.5f * breath, 3.2f * notice, 0) * amount);
            Apply("head", new Vector3(7f * penLift + .8f * breath, 11f * notice - 4f * glance, -2f * notice) * amount);
            Apply("rightUpperArm", new Vector3(-12f * penLift, 0, 1.5f * breath) * amount);
            Apply("rightForearm", new Vector3(-9f * wrist, 0, 0) * amount);
            Apply("pen", new Vector3(0, 0, 5f * wrist) * amount);
            Apply("leftUpperArm", new Vector3(.7f * breath, 0, 0) * amount);
            Apply("leftForearm", new Vector3(-.7f * breath, 0, 0) * amount);
            Apply("leftHand", new Vector3(0, 1f * notice, 0) * amount);
            return;
        }
        if (bones.Exists(b => b.role == "backFrame"))
        {
            // A restrained load adjustment: straighten the chest, look up,
            // release one elbow, then settle back under the burden. Feet and
            // pelvis never move; the frame remains attached to the torso.
            float brace = Gesture(time, 17f, 2.8f, 8.4f);
            float unload = Gesture(time - .55f, 17f, 2.8f, 8.4f);
            float hand = Gesture(time - .9f, 17f, 2.8f, 8.4f);
            Apply("chest", new Vector3(-2.4f * breath - 4.5f * brace, 0, 2.2f * brace) * amount);
            Apply("head", new Vector3(1.6f * breath - 8f * unload, 8f * glance, -2f * brace) * amount);
            Apply("backFrame", new Vector3(.45f * breath, 0, -.6f * unload) * amount);
            Apply("leftUpperArm", new Vector3(2f * breath - 6f * brace, 0, 3f * unload) * amount);
            Apply("rightUpperArm", new Vector3(1.8f * breath + 3f * unload, 0, -2f * brace) * amount);
            Apply("leftForearm", new Vector3(-2f * breath + 9f * unload, 0, 0) * amount);
            Apply("rightForearm", new Vector3(-1.5f * breath - 4f * hand, 0, 0) * amount);
            Apply("leftHand", new Vector3(6f * hand, 0, 0) * amount);
            Apply("rightHand", new Vector3(-3f * hand, 0, 0) * amount);
            return;
        }
        switch (archetype)
        {
            case IdleArchetype.Hound:
                // In the authored walk, rotating chest moves its child paws.
                // Keep that chain intact: the visible acting is neck/ears/tail.
                if (!UsesContinuousEarlyHoundGait)
                    Apply("chest", new Vector3(-1.4f * breath, 0, .6f * settle) * amount);
                Apply("neck", new Vector3(.9f * breath - 2f * settle, 3.5f * glance, 0) * amount);
                Apply("head", new Vector3(1.7f * breath + 2f * delayed, 4.5f * glance, -.8f * settle) * amount);
                Apply("jaw", new Vector3(2f + 1.3f * breath, 0, 0) * amount);
                float earBeat = Gesture(time, 7.9f, 2.2f, 2.9f);
                Apply("leftEar", new Vector3(7f * earBeat, 5f * glance, 0) * amount);
                Apply("rightEar", new Vector3(-5f * Gesture(time - .23f, 7.9f, 2.2f, 2.9f), -4f * glance, 0) * amount);
                Apply("tail", new Vector3(0, 7f * Mathf.Sin(time * .92f) * (.4f + .6f * settle), 2f * breath) * amount);
                Apply("tailTip", new Vector3(0, 10f * Mathf.Sin(time * .92f - .6f) * (.4f + .6f * delayed), 3f * breath) * amount);
                break;
            case IdleArchetype.FogGhost:
                // FogGhostActor authors +/-18 degrees of permanent arm lift.
                // Cancel part of that only during idle; its casts keep exclusive ownership.
                Apply("chest", new Vector3(-2f * breath, 2f * settle, 1f * breath) * amount);
                Apply("head", new Vector3(1.6f * breath, 7f * glance, 1.8f * delayed) * amount);
                Apply("leftUpperArm", new Vector3(3f * Mathf.Sin(time * .8f), 0, -11f + 3f * breath) * amount);
                Apply("rightUpperArm", new Vector3(-3f * Mathf.Sin(time * .8f - 1.1f), 0, 11f - 3f * breath) * amount);
                Apply("leftForearm", new Vector3(3f * delayed, 0, 0) * amount);
                Apply("rightForearm", new Vector3(-3f * release, 0, 0) * amount);
                break;
            case IdleArchetype.MemoryLeech:
                for (int segment = 0; segment < 7; segment++)
                {
                    float reach = Gesture(time - segment * .2f, 8.8f, 1.8f, 5.7f);
                    Apply("segment" + segment, new Vector3(2.3f * Mathf.Sin(time * 1.05f - segment * .65f),
                        3.5f * Mathf.Sin(time * .65f - segment * .55f) + 3f * reach,
                        1.1f * Mathf.Sin(time * .7f - segment * .5f)) * amount);
                }
                break;
            case IdleArchetype.MechanicalGuard:
                Apply("chest", new Vector3(-1.3f * breath, 2.5f * settle, .8f * settle) * amount);
                Apply("head", new Vector3(.8f * breath, 9f * glance, 0) * amount);
                Apply("leftUpperArm", new Vector3(2f * breath + 3f * delayed, 0, 1f * settle) * amount);
                Apply("rightUpperArm", new Vector3(1.2f * breath, 0, -1.5f * delayed) * amount);
                Apply("leftForearm", new Vector3(-3f * delayed, 0, 0) * amount);
                Apply("rightForearm", new Vector3(2f * release, 0, 0) * amount);
                Apply("leftHand", new Vector3(0, 5f * release, 0) * amount);
                Apply("rightHand", new Vector3(0, -3f * delayed, 0) * amount);
                break;
            case IdleArchetype.Threadweaver:
                // Follow the raised thread hand with the eyes before a small
                // wrist turn. The support structure is not animated separately.
                float inspectThread = Gesture(time, 15.8f, 2.2f, 7.8f);
                float drawThread = Gesture(time - .5f, 15.8f, 2.2f, 7.8f);
                float threadWrist = Gesture(time - .85f, 15.8f, 2.2f, 7.8f);
                Apply("chest", new Vector3(-1.6f * breath, 4f * inspectThread, .7f * settle) * amount);
                Apply("neck", new Vector3(.6f * breath, 2f * inspectThread, 0) * amount);
                Apply("head", new Vector3(-3f * drawThread + breath, 10f * inspectThread, 2.5f * drawThread) * amount);
                Apply("rightUpperArm", new Vector3(-4f * drawThread, 0, 4f * drawThread) * amount);
                Apply("rightForearm", new Vector3(0, 4f * threadWrist, 6f * drawThread) * amount);
                Apply("rightHand", new Vector3(0, -10f * threadWrist, 4f * threadWrist) * amount);
                Apply("leftUpperArm", new Vector3(1.8f * breath, 0, 1.2f * delayed) * amount);
                Apply("leftForearm", new Vector3(2f * delayed, 0, 0) * amount);
                Apply("leftHand", new Vector3(3f * release, 2f * breath, 0) * amount);
                Apply("leftSleeve", new Vector3(-2f * delayed, 0, -2f * release) * amount);
                Apply("rightSleeve", new Vector3(2.5f * threadWrist, 0, -2f * threadWrist) * amount);
                ApplyCloth(time, amount * 1.6f);
                break;
            case IdleArchetype.Revenant:
                Apply("chest", new Vector3(-1.9f * breath, 2f * settle, .9f * settle) * amount);
                Apply("neck", new Vector3(.7f * breath, 2f * glance, 0) * amount);
                Apply("head", new Vector3(1.4f * breath, 6f * glance, 1.8f * delayed) * amount);
                Apply("leftUpperArm", new Vector3(2f * breath + 3f * settle, 0, 2f * delayed) * amount);
                Apply("rightUpperArm", new Vector3(1.5f * breath - 2f * delayed, 0, -2f * release) * amount);
                Apply("leftForearm", new Vector3(3f * delayed, 0, 0) * amount);
                Apply("rightForearm", new Vector3(-3f * release, 0, 0) * amount);
                Apply("leftHand", new Vector3(5f * release, 3f * breath, 0) * amount);
                Apply("rightHand", new Vector3(-4f * delayed, -2f * breath, 0) * amount);
                Apply("leftSleeve", new Vector3(-2f * delayed, 0, -2f * release) * amount);
                Apply("rightSleeve", new Vector3(1.5f * release, 0, 1.5f * delayed) * amount);
                ApplyCloth(time, amount * 1.6f);
                break;
            default:
                Apply("chest", new Vector3(-2f * breath, 2f * settle, 1.3f * settle) * amount);
                Apply("neck", new Vector3(.8f * breath, 2f * glance, 0) * amount);
                Apply("head", new Vector3(1.3f * breath, 6f * glance, -.8f * delayed) * amount);
                ApplyShoulders(breath, settle, amount * 1.8f);
                Apply("leftForearm", new Vector3(3f * delayed, 0, 0) * amount);
                Apply("rightForearm", new Vector3(-2f * release, 0, 0) * amount);
                Apply("leftHand", new Vector3(3f * release, 0, 0) * amount);
                Apply("rightHand", new Vector3(-2f * delayed, 0, 0) * amount);
                if (speaking) Apply("jaw", new Vector3(3.2f + 2.2f * Mathf.Sin(time * 8.5f), 0, 0) * amount);
                break;
        }
    }

    static float Gesture(float time,float period,float start,float end) {
        float x=Mathf.Repeat(time,period);
        if(x<start || x>end)return 0;
        float u=(x-start)/(end-start);
        if(u<.32f)return Mathf.SmoothStep(0,1,u/.32f);
        if(u<.62f)return 1;
        return 1-Mathf.SmoothStep(0,1,(u-.62f)/.38f);
    }

    void PrepareFrame()
    {
        for (var i = 0; i < bones.Count; i++)
        {
            var entry = bones[i];
            if (entry.bone == null || !entry.hasBase) continue;

            // If Animator did not write this bone since our last LateUpdate,
            // remove the previous additive result first. If it did write a
            // new clip pose, treat that pose as the new additive baseline.
            if (entry.lastResult != Quaternion.identity
                && Quaternion.Angle(entry.bone.localRotation, entry.lastResult) < 0.001f)
                entry.bone.localRotation = entry.baseRotation;
            else
                entry.baseRotation = entry.bone.localRotation;
            entry.lastResult = Quaternion.identity;
            bones[i] = entry;
        }
    }

    void RefreshVisibleActor()
    {
        if (handle == null) return;
        var resolved = ResolveVisibleActor();
        if (resolved == visualActor) return;

        RestoreBoneOffsets();
        ReleaseGaitGround();
        visualActor = resolved;
        ApplyVisibleActorArchetype();
        animator = visualActor != null
            ? visualActor.GetComponentInChildren<Animator>(true)
            : null;
        CacheSecondaryPlayers();
        CacheVisualPose();
        CacheBones();
    }

    void CacheSecondaryPlayers()
    {
        legacyAnimation = visualActor != null ? visualActor.GetComponentInChildren<Animation>(true) : null;
        ghostActor = visualActor != null ? visualActor.GetComponent<FogGhostActor>() : null;
        CachePlantedHoundPose();
        CalibrateContinuousGaitGround();
        if (corePresence != null) corePresence.Release();
        if (archetype == IdleArchetype.LivingCore)
        {
            if (corePresence == null) corePresence = GetComponent<ClockCoreIdlePresence>();
            if (corePresence == null) corePresence = gameObject.AddComponent<ClockCoreIdlePresence>();
            corePresence.Configure(visualActor);
        }
    }

    void ApplyVisibleActorArchetype()
    {
        if (!archetypeWasAuto || visualActor == null) return;
        archetype = InferArchetype(handle);
        if (visualActor.name.IndexOf("Emerald", StringComparison.OrdinalIgnoreCase) >= 0)
            archetype = IdleArchetype.Revenant;
        else if (visualActor.GetComponent<FogGhostActor>() != null)
            archetype = IdleArchetype.FogGhost;
        else if (archetype == IdleArchetype.FogGhost)
            archetype = InferArchetype(handle);
    }

    void CacheVisualPose()
    {
        visualPoseCached = visualActor != null;
        if (!visualPoseCached) return;
        visualBaseRotation = visualActor.localRotation;
        visualLastRotation = Quaternion.identity;
        visualBaseScale = visualActor.localScale;
        visualLastScale = Vector3.zero;
    }

    Transform ResolveVisibleActor()
    {
        if (handle == null)
            return explicitVisual;

        var visualRoot = handle.VisualRoot != null ? handle.VisualRoot : handle.EnemyRoot;
        if (visualRoot == null)
            return explicitVisual != null ? explicitVisual : handle.Model;

        var explicitIsPresentationChild = explicitVisual != null
            && (explicitVisual.IsChildOf(visualRoot)
                || handle.EnemyRoot != null && explicitVisual.IsChildOf(handle.EnemyRoot));
        if (explicitIsPresentationChild
            && explicitVisual.gameObject.activeInHierarchy && HasVisibleRenderer(explicitVisual))
            return explicitVisual;

        // EmeraldRevenantPresentation keeps handle.Model pointing at the
        // hidden early hound. Its replacement actor has a stable prefab root
        // name, so resolve it before inspecting the legacy model.
        var emeraldActor = FindDirectOrNestedNamed(visualRoot,
            "EmeraldRevenantActor");
        if (emeraldActor != null && emeraldActor.gameObject.activeInHierarchy
            && HasVisibleRenderer(emeraldActor))
            return emeraldActor;

        // FogGhostActor is attached to the actual visible ghost child in
        // legacy scenes. Prefer that child over a hidden/recycled model.
        // SetFogGhostModel instantiates this actor below EnemyRoot rather than
        // VisualRoot, so search the complete presentation branch.
        var ghostActors = handle.EnemyRoot != null
            ? handle.EnemyRoot.GetComponentsInChildren<FogGhostActor>(true)
            : visualRoot.GetComponentsInChildren<FogGhostActor>(true);
        for (var i = 0; i < ghostActors.Length; i++)
        {
            var ghost = ghostActors[i];
            if (ghost != null && ghost.gameObject.activeInHierarchy
                && HasVisibleRenderer(ghost.transform))
                return ghost.transform;
        }

        if (handle.Model != null && handle.Model.gameObject.activeInHierarchy
            && HasVisibleRenderer(handle.Model))
            return handle.Model;
        if (HasVisibleRenderer(visualRoot))
            return visualRoot;
        // A hidden recycled model must never become the procedural target.
        // Returning null also makes CanAnimateIdle() skip until a visible
        // replacement actor is present again.
        return null;
    }

    static Transform FindDirectOrNestedNamed(Transform root, string wantedName)
    {
        if (root == null) return null;
        var all = root.GetComponentsInChildren<Transform>(true);
        for (var i = 0; i < all.Length; i++)
            if (string.Equals(all[i].name, wantedName, StringComparison.OrdinalIgnoreCase)
                || string.Equals(all[i].name, wantedName + "(Clone)", StringComparison.OrdinalIgnoreCase))
                return all[i];
        return null;
    }

    static bool HasVisibleRenderer(Transform root)
    {
        if (root == null || !root.gameObject.activeInHierarchy) return false;
        var renderers = root.GetComponentsInChildren<Renderer>(true);
        for (var i = 0; i < renderers.Length; i++)
        {
            var renderer = renderers[i];
            if (renderer != null && renderer.enabled && renderer.gameObject.activeInHierarchy
                && !(renderer is ParticleSystemRenderer))
                return true;
        }
        return false;
    }

    bool CanAnimateIdle()
    {
        if (!isActiveAndEnabled || !configured || handle == null
            || !handle.gameObject.activeInHierarchy || suspended || dead)
            return false;
        if (visualActor == null || !visualActor.gameObject.activeInHierarchy)
            return false;

        if (ghostActor != null && ghostActor.IsCasting) return false;
        if (legacyAnimation != null && legacyAnimation.isActiveAndEnabled
            && !legacyAnimation.IsPlaying("Idle")) return false;

        var signature = GetComponent<SignatureEnemyPresentation>();
        if (signature != null && signature.IsCasting)
            return false;

        if (animator == null || !animator.isActiveAndEnabled || animator.runtimeAnimatorController == null)
            return true;

        // Do not guess that a non-idle authored state is safe. This keeps
        // local offsets out of attack, charge, hit and death clips, including
        // imported controllers whose state names are not known to this file.
        if (animator.IsInTransition(0)) return false;
        var state = animator.GetCurrentAnimatorStateInfo(0);
        return state.IsName("Idle")
            || state.IsName("Meshy · Idle")
            || state.IsName("EmeraldIdle")
            || state.IsName("Walking Hold")
            || state.IsName("Base Layer.Idle")
            || state.IsName("Base Layer.Meshy · Idle")
            || state.IsName("Base Layer.EmeraldIdle")
            || state.IsName("Base Layer.Walking Hold")
            || state.IsName("Walk")
            || state.IsName("Base Layer.Walk");
    }

    bool BonesNeedRefresh()
    {
        if (!bonesCached) return true;
        if (bones.Count == 0) return false;
        for (var i = 0; i < bones.Count; i++)
            if (bones[i].bone == null) return true;
        return handle == null || visualActor == null
            || bones[0].bone == null || !bones[0].bone.IsChildOf(visualActor);
    }

    void CacheBones()
    {
        RestoreBoneOffsets();
        bones.Clear();
        bonesCached = true;
        if (handle == null || visualActor == null) return;

        var root = visualActor;
        AddBone("chest", FindBone(root, "Chest", "Cabinet", "Spine2", "Spine", "UpperBody"));
        AddBone("neck", FindBone(root, "Neck"));
        AddBone("head", FindBone(root, "Head", "head"));
        AddBone("jaw", FindBone(root, "Jaw", "jaw", "Mouth"));
        AddBone("leftShoulder", FindBone(root, "LeftShoulder", "Shoulder.L", "L_Shoulder"));
        AddBone("rightShoulder", FindBone(root, "RightShoulder", "Shoulder.R", "R_Shoulder"));
        AddBone("leftUpperArm", FindBone(root, "UpperArm.L", "LeftUpperArm", "L_UpperArm", "LeftArm"));
        AddBone("rightUpperArm", FindBone(root, "UpperArm.R", "RightUpperArm", "R_UpperArm", "RightArm"));
        AddBone("leftForearm", FindBone(root, "Forearm.L", "LeftForeArm", "LeftLowerArm", "L_Forearm"));
        AddBone("rightForearm", FindBone(root, "Forearm.R", "RightForeArm", "RightLowerArm", "R_Forearm"));
        AddBone("pen", FindBone(root, "Pen.R"));
        AddBone("backFrame", FindBone(root, "BackFrame"));
        AddBone("tail", FindBone(root, "Tail1", "tailstart", "Tail", "tail", "TailBase"));
        AddBone("tailTip", FindBone(root, "Tail3", "tail2", "TailTip", "tailend", "Tail_End"));
        AddBone("leftHand", FindBone(root, "Hand.L", "LeftHand"));
        AddBone("rightHand", FindBone(root, "Hand.R", "RightHand"));
        AddBone("leftEar", FindBone(root, "Ear.L", "earend"));
        AddBone("rightEar", FindBone(root, "Ear.R", "R_earend"));
        AddBone("leftCloth", FindBone(root, "CoatL", "Cape1.L"));
        AddBone("rightCloth", FindBone(root, "CoatR", "Cape1.R"));
        AddBone("leftClothTip", FindBone(root, "CoatTipL", "Cape3.L"));
        AddBone("rightClothTip", FindBone(root, "CoatTipR", "Cape3.R"));
        AddBone("leftSleeve", FindBone(root, "Sleeve.L"));
        AddBone("rightSleeve", FindBone(root, "Sleeve.R"));
        AddBone("veil", FindBone(root, "Veil"));
        AddBone("skirt", FindBone(root, "SkirtFront2"));
        for (var segment = 0; segment < 7; segment++)
            AddBone("segment" + segment, FindBone(root, "segment_" + segment.ToString("00")));
        AddBone("leftFrontLeg", FindBone(root, "L_frontleg1", "LeftFrontLeg", "FrontLeg.L"));
        AddBone("rightFrontLeg", FindBone(root, "R_frontleg1", "RightFrontLeg", "FrontLeg.R"));
        AddBone("leftBackLeg", FindBone(root, "L_backleg1", "LeftBackLeg", "BackLeg.L"));
        AddBone("rightBackLeg", FindBone(root, "R_backleg1", "RightBackLeg", "BackLeg.R"));
    }

    void AddBone(string role, Transform bone)
    {
        if (bone == null) return;
        if (bones.Exists(b => b.bone == bone)) return;
        var entry = new BoneOffset(role, bone);
        entry.baseRotation = bone.localRotation;
        entry.lastResult = Quaternion.identity;
        entry.hasBase = true;
        bones.Add(entry);
    }

    void Apply(string role, Vector3 euler)
    {
        for (var i = 0; i < bones.Count; i++)
        {
            var entry = bones[i];
            if (entry.bone == null || !entry.hasBase || !string.Equals(entry.role, role, StringComparison.Ordinal))
                continue;
            entry.bone.localRotation = entry.baseRotation * Quaternion.Euler(euler);
            entry.lastResult = entry.bone.localRotation;
            bones[i] = entry;
            return;
        }
    }

    void ApplyTail(float time, float amount)
    {
        Apply("tail", new Vector3(0f, 4.5f * Mathf.Sin(time * 1.7f), 1.8f * Mathf.Sin(time * 1.25f)) * amount);
        Apply("tailTip", new Vector3(0f, 6f * Mathf.Sin(time * 1.7f + 0.6f), 2.6f * Mathf.Sin(time * 1.25f + 0.4f)) * amount);
    }

    void ApplyShoulders(float breath, float sway, float amount)
    {
        var left = new Vector3(0.7f * breath, 0f, 1.0f * sway) * amount;
        var right = new Vector3(0.7f * breath, 0f, -1.0f * sway) * amount;
        Apply("leftShoulder", left);
        Apply("rightShoulder", right);
        Apply("leftUpperArm", left * 0.65f);
        Apply("rightUpperArm", right * 0.65f);
    }

    void RestoreBoneOffsets()
    {
        RestoreVisualPose();
        if (corePresence != null) corePresence.RestorePose();
        for (var i = 0; i < bones.Count; i++)
        {
            var entry = bones[i];
            if (entry.bone == null || !entry.hasBase) continue;
            // Animator may have replaced our previous result with an attack,
            // hit, or death pose. In that case leave the current authored pose
            // alone; restoring the old idle rotation would corrupt the clip.
            if (Quaternion.Angle(entry.bone.localRotation, entry.lastResult) < 0.001f)
                entry.bone.localRotation = entry.baseRotation;
            entry.lastResult = Quaternion.identity;
            bones[i] = entry;
        }
        RestorePlantedHoundPose();
    }

    void RestoreVisualPose()
    {
        if (!visualPoseCached || visualActor == null) return;
        if (Quaternion.Angle(visualActor.localRotation, visualLastRotation) < 0.001f)
            visualActor.localRotation = visualBaseRotation;
        if ((visualActor.localScale - visualLastScale).sqrMagnitude < 0.000001f)
            visualActor.localScale = visualBaseScale;
        visualLastRotation = Quaternion.identity;
        visualLastScale = Vector3.zero;
    }

    void SetSuspended(bool value)
    {
        suspended = value;
        if (value) RestoreBoneOffsets();
    }

    static Transform FindBone(Transform root, params string[] names)
    {
        if (root == null) return null;
        var all = root.GetComponentsInChildren<Transform>(true);
        for (var n = 0; n < names.Length; n++)
            for (var i = 0; i < all.Length; i++)
                if (string.Equals(all[i].name, names[n], StringComparison.OrdinalIgnoreCase)
                    || all[i].name.EndsWith(":" + names[n], StringComparison.OrdinalIgnoreCase))
                    return all[i];
        return null;
    }

    void CalibrateContinuousGaitGround()
    {
        if (!UsesContinuousEarlyHoundGait || gaitGroundWrapper != null || visualActor == null
            || animator == null || animator.runtimeAnimatorController == null) return;
        AnimationClip walk = null;
        foreach (var clip in animator.runtimeAnimatorController.animationClips)
            if (clip != null && (walk == null || clip.name.IndexOf("Walk", StringComparison.OrdinalIgnoreCase) >= 0)) walk = clip;
        if (walk == null) return;
        // Sample the actual authored stride on the rig, then restore every
        // transform. No Animator.Play/Update, time, speed or parameter changes.
        var transforms = animator.GetComponentsInChildren<Transform>(true);
        var positions = new Vector3[transforms.Length]; var rotations = new Quaternion[transforms.Length];
        var scales = new Vector3[transforms.Length];
        for (int i = 0; i < transforms.Length; i++)
        { positions[i] = transforms[i].localPosition; rotations[i] = transforms[i].localRotation; scales[i] = transforms[i].localScale; }
        var samples = new List<float>();
        try
        {
            for (int sample = 0; sample < 16; sample++)
            {
                walk.SampleAnimation(animator.gameObject, walk.length * sample / 16f);
                if (!TrySkinMinimumWorldY(out var minimum))
                { Debug.LogError("EARLY_HOUND_GAIT_GROUND cannot read actual skin.", this); return; }
                samples.Add(minimum);
            }
        }
        finally
        {
            for (int i = 0; i < transforms.Length; i++)
            { transforms[i].localPosition = positions[i]; transforms[i].localRotation = rotations[i]; transforms[i].localScale = scales[i]; }
        }
        samples.Sort();
        GaitSampleMinimumY = samples[0]; GaitSampleMaximumY = samples[samples.Count - 1];
        // Lowest support contact across a full stride defines a stable floor.
        // Unlike frame-by-frame foot chasing, this cannot introduce bobbing.
        GaitGroundOffset = handle.EnemyRoot.position.y - GaitSampleMinimumY;
        gaitGroundActor = visualActor; gaitOriginalParent = visualActor.parent;
        gaitGroundWrapper = new GameObject("EarlyHoundStrideGround").transform;
        gaitGroundWrapper.SetParent(gaitOriginalParent, false);
        visualActor.SetParent(gaitGroundWrapper, false);
        gaitGroundWrapper.localPosition = gaitOriginalParent != null
            ? gaitOriginalParent.InverseTransformVector(Vector3.up * GaitGroundOffset)
            : Vector3.up * GaitGroundOffset;
        Debug.Log($"EARLY_HOUND_GAIT_GROUND samples={string.Join(",", samples.ConvertAll(v => v.ToString("F5")))} offset={GaitGroundOffset:F5} correctedMin={GaitSampleMinimumY + GaitGroundOffset:F5} correctedMax={GaitSampleMaximumY + GaitGroundOffset:F5}", this);
    }

    void ReleaseGaitGround()
    {
        if (gaitGroundWrapper == null) return;
        if (gaitGroundActor != null) gaitGroundActor.SetParent(gaitOriginalParent, false);
        Destroy(gaitGroundWrapper.gameObject);
        gaitGroundWrapper = null; gaitGroundActor = null; gaitOriginalParent = null;
        GaitGroundOffset = 0;
    }

    void CachePlantedHoundPose()
    {
        RestorePlantedHoundPose();
        plantedBones.Clear();
        if (handle == null || handle.ProfileEnemyId != "early-hell-hound" || visualActor == null
            || archetype != IdleArchetype.Hound) return;
        // This legacy controller reuses a walking clip for Idle. Recover the
        // authored skin bind stance rather than freezing an arbitrary raised paw.
        foreach (var skin in visualActor.GetComponentsInChildren<SkinnedMeshRenderer>(true))
        {
            if (skin.sharedMesh == null) continue;
            var meshBones = skin.bones; var binds = skin.sharedMesh.bindposes;
            var world = new Dictionary<Transform, Matrix4x4>();
            for (var i = 0; i < meshBones.Length && i < binds.Length; i++)
                if (meshBones[i] != null) world[meshBones[i]] = skin.transform.localToWorldMatrix * binds[i].inverse;
            foreach (var pair in world)
            {
                if (plantedBones.Exists(b => b.bone == pair.Key)) continue;
                var parentWorld = pair.Key.parent != null ? pair.Key.parent.localToWorldMatrix : Matrix4x4.identity;
                if (pair.Key.parent != null && world.TryGetValue(pair.Key.parent, out var restParent)) parentWorld = restParent;
                var local = parentWorld.inverse * pair.Value;
                plantedBones.Add(new PlantedBone { bone = pair.Key, restRotation = local.rotation,
                    restPosition = local.GetColumn(3) });
            }
        }
        CalibratePlantedGround();
    }

    void CalibratePlantedGround()
    {
        if (plantedBones.Count == 0) return;
        var previousRotations = new Quaternion[plantedBones.Count];
        var previousPositions = new Vector3[plantedBones.Count];
        var originalRestPositions = new Vector3[plantedBones.Count];
        for (int i = 0; i < plantedBones.Count; i++)
        {
            var b = plantedBones[i];
            previousRotations[i] = b.bone.localRotation; previousPositions[i] = b.bone.localPosition;
            originalRestPositions[i] = b.restPosition;
            b.bone.localRotation = b.restRotation; b.bone.localPosition = b.restPosition;
        }
        try
        {
            if (!TrySkinMinimumWorldY(out var before))
            { Debug.LogError("EARLY_HOUND_GROUND missing readable skin data; cannot calibrate.", this); return; }
            PlantedSkinBeforeY = before;
            var bakedMinimum = float.PositiveInfinity;
            foreach (var skin in visualActor.GetComponentsInChildren<SkinnedMeshRenderer>(true))
            {
                if (!skin.enabled || skin.sharedMesh == null) continue;
                var baked = new Mesh();
                skin.BakeMesh(baked, false);
                foreach (var vertex in baked.vertices) bakedMinimum = Mathf.Min(bakedMinimum, skin.transform.TransformPoint(vertex).y);
                Destroy(baked);
            }
            Debug.Log($"EARLY_HOUND_GROUND_DIAGNOSTIC skinMatrixMin={before:F5} bakeTransformMin={bakedMinimum:F5}", this);
            var ground = handle.EnemyRoot.position.y;
            var delta = ground - before;
            var roots = new HashSet<Transform>();
            foreach (var b in plantedBones) roots.Add(b.bone);
            for (int i = 0; i < plantedBones.Count; i++)
            {
                var b = plantedBones[i];
                if (b.bone.parent != null && roots.Contains(b.bone.parent)) continue;
                var localDelta = b.bone.parent != null ? b.bone.parent.InverseTransformVector(Vector3.up * delta) : Vector3.up * delta;
                b.restPosition += localDelta; b.bone.localPosition = b.restPosition;
                plantedBones[i] = b;
            }
            if (!TrySkinMinimumWorldY(out var after) || Mathf.Abs(after - ground) > .015f)
            {
                for (int i = 0; i < plantedBones.Count; i++) { var b = plantedBones[i]; b.restPosition = originalRestPositions[i]; plantedBones[i] = b; }
                Debug.LogError($"EARLY_HOUND_GROUND calibration failed before={before:F5} after={after:F5} ground={ground:F5}", this);
                return;
            }
            PlantedSkinAfterY = after; PlantedGroundCorrection = delta;
            Debug.Log($"EARLY_HOUND_GROUND before={before:F5} correction={delta:F5} after={after:F5} target={ground:F5}", this);
        }
        finally
        {
            for (int i = 0; i < plantedBones.Count; i++)
            { plantedBones[i].bone.localRotation = previousRotations[i]; plantedBones[i].bone.localPosition = previousPositions[i]; }
        }
    }

    bool TrySkinMinimumWorldY(out float minimum)
    {
        minimum = float.PositiveInfinity;
        foreach (var skin in visualActor.GetComponentsInChildren<SkinnedMeshRenderer>(true))
        {
            if (!skin.enabled || skin.sharedMesh == null || !skin.sharedMesh.isReadable) continue;
            var mesh = skin.sharedMesh; var skinBones = skin.bones; var binds = mesh.bindposes;
            var vertices = mesh.vertices; var weights = mesh.boneWeights;
            if (weights.Length != vertices.Length || skinBones.Length != binds.Length) continue;
            var matrices = new Matrix4x4[skinBones.Length];
            for (int b = 0; b < matrices.Length; b++) matrices[b] = skinBones[b].localToWorldMatrix * binds[b];
            for (int i = 0; i < vertices.Length; i++)
            {
                var w = weights[i]; var v = vertices[i];
                var point = matrices[w.boneIndex0].MultiplyPoint3x4(v) * w.weight0
                    + matrices[w.boneIndex1].MultiplyPoint3x4(v) * w.weight1
                    + matrices[w.boneIndex2].MultiplyPoint3x4(v) * w.weight2
                    + matrices[w.boneIndex3].MultiplyPoint3x4(v) * w.weight3;
                if (!float.IsNaN(point.y) && !float.IsInfinity(point.y)) minimum = Mathf.Min(minimum, point.y);
            }
        }
        return !float.IsInfinity(minimum);
    }

    void ApplyPlantedHoundPose()
    {
        if (UsesContinuousEarlyHoundGait) return;
        if (plantedBones.Count == 0 || animator == null) return;
        var state = animator.GetCurrentAnimatorStateInfo(0);
        // Real walking/running, attacks, hits and all transitions remain owned
        // by the Animator. Only its mislabeled stationary idle is corrected.
        if (!(state.IsName("Meshy · Idle") || state.IsName("Idle") || state.IsName("Walking Hold"))) return;
        RestoreBoneOffsets();
        for (var i = 0; i < plantedBones.Count; i++)
        {
            var b = plantedBones[i]; if (b.bone == null) continue;
            b.previousRotation = b.bone.localRotation; b.previousPosition = b.bone.localPosition;
            b.bone.localRotation = b.restRotation; b.bone.localPosition = b.restPosition;
            plantedBones[i] = b;
        }
        plantedApplied = true;
    }

    void RestorePlantedHoundPose()
    {
        if (!plantedApplied) return;
        foreach (var b in plantedBones)
        {
            if (b.bone == null) continue;
            if (Quaternion.Angle(b.bone.localRotation, b.restRotation) < .001f) b.bone.localRotation = b.previousRotation;
            if ((b.bone.localPosition - b.restPosition).sqrMagnitude < .00000001f) b.bone.localPosition = b.previousPosition;
        }
        plantedApplied = false;
    }

    void ApplyCloth(float time, float amount)
    {
        if(ArtPolishEnabled) amount *= .72f + .28f * Mathf.Sin(time*.39f);
        Apply("leftCloth", new Vector3(2f * Mathf.Sin(time * 1.05f), 1f * Mathf.Sin(time * .7f), 1.3f * Mathf.Sin(time * .8f)) * amount);
        Apply("rightCloth", new Vector3(2f * Mathf.Sin(time * 1.05f + .8f), -1f * Mathf.Sin(time * .7f), -1.3f * Mathf.Sin(time * .8f + .5f)) * amount);
        Apply("leftClothTip", new Vector3(2.6f * Mathf.Sin(time * 1.05f - .6f), 0, 1.5f * Mathf.Sin(time * .8f - .4f)) * amount);
        Apply("rightClothTip", new Vector3(2.6f * Mathf.Sin(time * 1.05f + .2f), 0, -1.5f * Mathf.Sin(time * .8f + .1f)) * amount);
        Apply("veil", new Vector3(1.8f * Mathf.Sin(time * .86f - .7f), 1.2f * Mathf.Sin(time * .57f), 0) * amount);
        Apply("skirt", new Vector3(1.2f * Mathf.Sin(time * .93f), 0, .6f * Mathf.Sin(time * .71f)) * amount);
    }

    static IdleArchetype InferArchetype(EnemyHandle enemyHandle)
    {
        var id = enemyHandle != null ? enemyHandle.ProfileEnemyId : string.Empty;
        if (string.IsNullOrEmpty(id) && enemyHandle != null && enemyHandle.Model != null)
            id = enemyHandle.Model.name;
        id = id ?? string.Empty;
        if (id.IndexOf("clock-core", StringComparison.OrdinalIgnoreCase) >= 0) return IdleArchetype.LivingCore;
        if (id.IndexOf("leech", StringComparison.OrdinalIgnoreCase) >= 0) return IdleArchetype.MemoryLeech;
        if (id.IndexOf("matriarch", StringComparison.OrdinalIgnoreCase) >= 0 || id.IndexOf("veil", StringComparison.OrdinalIgnoreCase) >= 0) return IdleArchetype.Threadweaver;
        if (id.IndexOf("archiv", StringComparison.OrdinalIgnoreCase) >= 0 || id.IndexOf("clock", StringComparison.OrdinalIgnoreCase) >= 0 || id.IndexOf("guard", StringComparison.OrdinalIgnoreCase) >= 0) return IdleArchetype.MechanicalGuard;
        if (id.IndexOf("revenant", StringComparison.OrdinalIgnoreCase) >= 0) return IdleArchetype.Revenant;
        if (id.IndexOf("hound", StringComparison.OrdinalIgnoreCase) >= 0
            || id.IndexOf("wolf", StringComparison.OrdinalIgnoreCase) >= 0
            || id.IndexOf("ember", StringComparison.OrdinalIgnoreCase) >= 0)
            return IdleArchetype.Hound;
        if (id.IndexOf("ghost", StringComparison.OrdinalIgnoreCase) >= 0
            || id.IndexOf("fog", StringComparison.OrdinalIgnoreCase) >= 0)
            return IdleArchetype.FogGhost;
        return IdleArchetype.Humanoid;
    }

    static float StablePhase(EnemyHandle enemyHandle)
    {
        var identity = enemyHandle != null ? enemyHandle.BattleEnemyId : string.Empty;
        var hash = string.IsNullOrEmpty(identity) ? (enemyHandle != null ? enemyHandle.GetInstanceID() : 0) : identity.GetHashCode();
        return Mathf.Abs(hash % 1000) * 0.0137f;
    }
}
