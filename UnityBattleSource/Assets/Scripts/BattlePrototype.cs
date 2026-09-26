using System;
using System.Collections;
using System.Collections.Generic;
using System.Globalization;
using Mindstone.VFXV1;
using UnityEngine;
using UnityEngine.UI;

public sealed class BattlePrototype : MonoBehaviour
{
    // Axe_Spin_Attack is a 150-frame, 60 fps authored turn-and-strike take.
    // Play it forward without pose sampling; only pin the actor to its slot so
    // extracted root movement cannot turn the attack into a run-in.
    const float ClockGuardStrikeDuration = 150f / 60f;
    const float ClockGuardTrailStartProgress = 0.14f;
    const float ClockGuardImpactProgress = 0.40f;
    const float ClockGuardTrailEndProgress = 0.56f;
    // The Fool FBX is authored north-facing at identity. In the portrait
    // battlefield the camera sits south of the player row, so identity shows
    // the character from behind while he casts toward the enemy. A -90 degree
    // correction turned that authored back view into the side-on silhouette
    // seen in the simulator.
    const float PlayerBattleFacingDegrees = 0f;
    static readonly int ClockGuardAttackState = Animator.StringToHash("Base Layer.Meshy · Attack");
    static readonly int PlayerAttackState = Animator.StringToHash("Base Layer.Meshy · Attack");
    // The normal front-row lanes are intentionally compact. Two Clock Guards
    // need a little more separation so both silhouettes remain readable on a
    // portrait screen while their feet stay on the shared grounded row.
    const float DualClockGuardLaneExpansion = 0.35f;

    enum EncounterModel
    {
        ClockGuard,
        DualClockGuard,
        ClockCore,
        CoreEscort,
        LeechEscort,
        HellHound
    }

    GameObject player;
    GameObject enemy;
    GameObject clockGuard;
    GameObject clockCore;
    GameObject hellHound;
    EnemyHandle clockGuardHandle;
    EnemyHandle secondaryClockGuardHandle;
    readonly List<EnemyHandle> q2SplitGhosts = new List<EnemyHandle>();
    EnemyHandle clockCoreHandle;
    EnemyHandle hellHoundHandle;
    EnemyHandle earlyHellHoundHandle;
    EnemyHandle armoredHellHoundHandle;
    EnemyHandle memoryLeechHandle;
    EnemyHandle archivistTemplate;
    EnemyHandle matriarchTemplate;
    EnemyHandle scribeTemplate, rescueTemplate, executorTemplate;
    EnemyHandle copperbackTemplate, crimsonBruteTemplate, veilOracleTemplate, goldenThroatTemplate, moonfangTemplate;
    readonly Dictionary<string,EnemyHandle> bountyArtTemplates=new Dictionary<string,EnemyHandle>();
    EnemyHandle chronarchTemplate, adjudicatorTemplate, convoyTemplate, stonehideTemplate, saltmawTemplate, shellbackTemplate, ironclawTemplate, nagaTemplate, boneclawTemplate;
    bool usingProfileEnemyPipeline;
    Animator playerAnimator;
    FoolSkillChoreography playerChoreography;
    PlayerImpactFeedback20260925 playerImpactFeedback;
    Animator enemyAnimator;
    HellHoundEffekseerFireball hellHoundFireball;
    Q4HoundPresentation q4Hound;
    ClockHoundReverseTideVFX reverseTideVFX;
    MistportSpellShowcaseVFX spellShowcaseVFX;
    SpellBridge spellV1Bridge;
    TrailRenderer enemyWeaponTrail;
    Light enemyWeaponLight;
    readonly List<LineRenderer> enemyBladeGlowLines = new();
    readonly List<Material> enemyBladeGlowMaterials = new();
    Text status;
    Text enemyHpText;
    Text playerHpText;
    readonly List<Transform> rings = new();

    Vector3 playerHome;
    Vector3 playerBaseScale;
    Vector3 enemyHome;
    int enemyHp = 1000;
    int playerHp = 1000;
    bool playerDefending;
    bool actionRunning;
    bool playerDefeatPresentationActive;
    EncounterModel encounterModel = EncounterModel.ClockGuard;
    bool hellHoundUsesFireBreath = true;
    bool hellHoundIsEnraged;
    bool hasHellHoundBaseScale;
    Vector3 hellHoundBaseScale;
    Light hellHoundRageLight;
    ParticleSystem hellHoundRageAura;
    Coroutine hellHoundRagePulse;
    Coroutine playerDefeatRoutine;
    FoolEffekseerSkillVFX foolSkillVFX;
    ArcaneDustFlow heroDust;
    Coroutine heroDustRoutine;
    FoolBasicTarotVFX foolBasicTarotVFX;
    FoolDefenseVFX foolDefenseVFX;
    EncoreBellPresentation encoreBellPresentation;
    readonly List<GameObject> playerDefeatShardObjects = new();
    readonly Dictionary<Renderer, bool> paperHiddenRendererStates = new();
    bool playerHiddenByPaper;
    GUIStyle actionButtonStyle;
    Transform runtimeBackground;
    Texture2D runtimeBackgroundTexture;
    bool previewPresentation;

    // The native SpriteKit overlay queries this through UnityBattleBridge so
    // the fire effect can meet the same moving target as the 3D animation.
    HeroManualMaskRound2 masquerade;
    Vector3 EnemyPlayerTarget => masquerade && masquerade.IsActive ? masquerade.Impact : player.transform.position + Vector3.up * .85f;
    public Vector3 PlayerFireBreathImpactAnchor => player != null
        ? EnemyPlayerTarget
        : Vector3.zero;

    // Native health UI must follow the live animated mesh rather than the
    // old SpriteKit stand-in. Renderer bounds keep the bar above the head
    // while the authored idle/cast clips change the character's silhouette.
    public Vector3 PlayerHealthAnchor => player != null
        ? GetPlayerHealthAnchor()
        : Vector3.zero;

    // Showcase-only spell effects should meet the rendered protagonist, not
    // the imported actor root. The bounds center remains attached when the
    // model or its animation changes proportions.
    public Vector3 PlayerSpellImpactAnchor => player != null
        ? GetPaperDoubleAnchor()
        : Vector3.zero;

    Vector3 GetPaperDoubleAnchor()
    {
        if (player == null)
            return Vector3.zero;

        return TryGetPlayerVisualBounds(out var visualBounds)
            ? visualBounds.center
            : player.transform.position + Vector3.up * 1.05f;
    }

    Vector3 GetPlayerHealthAnchor()
    {
        if (!TryGetPlayerVisualBounds(out var visualBounds))
            return player.transform.position + Vector3.up * 1.30f;

        return new Vector3(
            visualBounds.center.x,
            visualBounds.max.y + 0.10f,
            visualBounds.center.z);
    }

    bool TryGetPlayerVisualBounds(out Bounds visualBounds)
    {
        var renderers = player.GetComponentsInChildren<Renderer>(true);
        var hasBounds = false;
        visualBounds = default;
        for (var index = 0; index < renderers.Length; index++)
        {
            var renderer = renderers[index];
            if (renderer == null || !renderer.enabled)
                continue;
            if (renderer is ParticleSystemRenderer)
                continue;

            if (!hasBounds)
            {
                visualBounds = renderer.bounds;
                hasBounds = true;
            }
            else
            {
                visualBounds.Encapsulate(renderer.bounds);
            }
        }

        return hasBounds;
    }

    public void PresentPaperRelicProtection()
    {
        if (player == null || foolDefenseVFX == null) return;
        foolDefenseVFX.Deploy(GetPaperDoubleAnchor);
        foolDefenseVFX.Consume();
    }

    public void ArmPaperDouble()
    {
        if (player == null || foolDefenseVFX == null)
            return;

        foolDefenseVFX.Arm();
    }

    Transform earlyHoundMuzzleVisual, earlyHoundMuzzleHead, earlyHoundMuzzleEnd;
    bool TryEarlyHoundMuzzle(out Vector3 position)
    {
        position=Vector3.zero;
        if(!hellHoundHandle||hellHoundHandle.ProfileEnemyId!="early-hell-hound"||!hellHoundHandle.VisualRoot)return false;
        if(earlyHoundMuzzleVisual!=hellHoundHandle.VisualRoot){
            earlyHoundMuzzleVisual=hellHoundHandle.VisualRoot;
            var bones=earlyHoundMuzzleVisual.GetComponentsInChildren<Transform>(true);
            earlyHoundMuzzleHead=Array.Find(bones,t=>string.Equals(t.name,"head",StringComparison.OrdinalIgnoreCase));
            earlyHoundMuzzleEnd=Array.Find(bones,t=>string.Equals(t.name,"headend",StringComparison.OrdinalIgnoreCase));
        }
        if(!earlyHoundMuzzleHead)return false;
        // The actual animated bones already include the gait's ground wrapper.
        // Adding its correction again to a fixed profile anchor put the Q4
        // stored flames at the feet. Keep the source on the visible muzzle.
        position=earlyHoundMuzzleEnd?Vector3.Lerp(earlyHoundMuzzleHead.position,earlyHoundMuzzleEnd.position,.86f):earlyHoundMuzzleHead.position;
        return true;
    }

    /// The hound's profile provides a stable height for effects, while the
    /// rendered bounds and current facing determine the actual forward-most
    /// point. This keeps a native overlay attached to its mouth as the hound
    /// pounces or a replacement model changes proportions.
    public Vector3 HellHoundFireBreathSourceAnchor
    {
        get
        {
            if (hellHoundHandle == null || hellHoundHandle.EffectAnchor == null)
                return Vector3.zero;

            if (emeraldRevenant != null && emeraldRevenant.IsInstalled) return emeraldRevenant.CastAnchor;
            if(TryEarlyHoundMuzzle(out var muzzle))return muzzle;
            var signature = hellHoundHandle.GetComponent<SignatureEnemyPresentation>();
            if (signature) return signature.SourceAnchor;
            var anchor = hellHoundHandle.EffectAnchor.position;
            var idle = hellHoundHandle.GetComponent<EarlyEnemyIdlePresence>();
            if (idle != null && idle.UsesContinuousEarlyHoundGait) anchor.y += idle.ContinuousGroundCorrection;
            if (hellHound == null || hellHoundHandle.VisualRoot == null)
                return anchor;

            var facing = hellHound.transform.TransformDirection(Vector3.back);
            facing.y = 0f;
            if (facing.sqrMagnitude < 0.0001f)
                return anchor;
            facing.Normalize();

            var foremostProjection = float.NegativeInfinity;
            var renderers = hellHoundHandle.VisualRoot.GetComponentsInChildren<Renderer>(true);
            for (var index = 0; index < renderers.Length; index++)
            {
                var renderer = renderers[index];
                if (renderer == null || !renderer.enabled) continue;
                var bounds = renderer.bounds;
                var projectedFront = Vector3.Dot(bounds.center, facing)
                    + Mathf.Abs(facing.x) * bounds.extents.x
                    + Mathf.Abs(facing.z) * bounds.extents.z;
                foremostProjection = Mathf.Max(foremostProjection, projectedFront);
            }

            if (float.IsNegativeInfinity(foremostProjection))
                return anchor;

            var anchorProjection = Vector3.Dot(anchor, facing);
            var forwardOffset = Mathf.Max(0.20f, (foremostProjection - anchorProjection) * 0.92f);
            return anchor + facing * forwardOffset;
        }
    }

    [RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.AfterSceneLoad)]
    static void Bootstrap()
    {
        // The Dunhuang attack candidate owns its own preview scene and
        // combatants. Keep the normal battle bootstrap out of that capture so
        // the candidate is not contaminated by the legacy showcase board.
        if (System.Array.Exists(
                System.Environment.GetCommandLineArgs(),
                value => value == "--preview-dunhuang-attack"))
            return;
        if (FindFirstObjectByType<BattlePrototype>() == null)
            new GameObject("Battle Prototype Runtime").AddComponent<BattlePrototype>();
    }

    public bool IsPresentationReady { get; private set; }

    void Start()
    {
        Application.targetFrameRate = 60;
        var runtimePreview = IsRuntimePreviewRequested();
        previewPresentation = runtimePreview;
        hellHoundFireball = gameObject.AddComponent<HellHoundEffekseerFireball>();
        reverseTideVFX = gameObject.AddComponent<ClockHoundReverseTideVFX>();
        spellShowcaseVFX = gameObject.AddComponent<MistportSpellShowcaseVFX>();
        spellV1Bridge = gameObject.AddComponent<SpellBridge>();
        foolSkillVFX = gameObject.AddComponent<FoolEffekseerSkillVFX>();
        foolBasicTarotVFX = gameObject.AddComponent<FoolBasicTarotVFX>();
        foolDefenseVFX = gameObject.AddComponent<FoolDefenseVFX>();
        BuildArena();
        gameObject.AddComponent<BattleRain>();
        if (runtimePreview)
        {
            var previewFloor = GameObject.Find("Clock Arena");
            if (previewFloor != null) previewFloor.SetActive(false);
            for (var i = 0; i < rings.Count; i++)
                if (rings[i] != null) rings[i].gameObject.SetActive(false);
        }
        BuildCombatants();
        ApplyEncounterModelSelection();
        // Native ready may precede expensive scene/texture installation. Preserve
        // the requested Q5 skin until its actual handle exists.
        if (encoreRevenantRequested) SetEncoreRevenant(true);
        if (encounterModel == EncounterModel.ClockGuard && clockGuard && !clockGuard.GetComponentInChildren<Mindstone.VFXV1.GuardianWard>(true))
            Mindstone.VFXV1.GuardianWard.Attach(clockGuard.transform);
#if UNITY_EDITOR || UNITY_STANDALONE
        if (!runtimePreview)
            BuildHud();
#endif
        SetStatus("请选择行动 · 当前模型与动作均来自 Meshy 资产");
        IsPresentationReady = true;
#if UNITY_EDITOR || UNITY_STANDALONE
        StartCoroutine(RunCommandLinePreviewIfRequested());
#endif
    }

    static bool IsRuntimePreviewRequested()
    {
#if UNITY_EDITOR || UNITY_STANDALONE
        var arguments = System.Environment.GetCommandLineArgs();
        return !string.IsNullOrEmpty(GetBuiltInVFXBoardPreviewEffect())
            || System.Array.Exists(arguments, value =>
            value == "--verify-hero-anatomy" || value == "--verify-hero-quality" || value == "--capture-character-closeups" || value == "--verify-story-models" || value == "--verify-character-polish" || value == "--verify-progression-rosters" || value == "--verify-q678-redesign" || value == "--verify-hero-choreography" || value == "--verify-enemy-impact" || value == "--verify-enemy-idle" || value == "--verify-hero-back-art" || value == "--verify-q4-two-flame" || value == "--verify-sidestep-cinematic" || value == "--verify-q2-split" || value == "--verify-enemy-death-fade" || value == "--verify-emerald-escalation" || value == "--verify-early-battle" || value == "--verify-sidestep-hounds" || value == "--preview-hero-spells" || value == "--preview-signatures" || value == "--preview-hound-fire" || value == "--preview-clock-core"
            || value == "--preview-dual-clock-guard"
            || value == "--preview-reverse-tide"
            || value == "--preview-defense"
            || value == "--preview-paper-double-hit"
            || value == "--preview-player-defeat"
            || value.StartsWith("--preview-vfx=")
            || value.StartsWith("--preview-vfx-board=")
            || value.StartsWith("--preview-skill="));
#else
        return false;
#endif
    }

    static string GetBuiltInVFXBoardPreviewEffect()
    {
#if MISTPORT_AUTO_VFX_BOARD_WILDWARDEN
        return "wildwarden";
#elif UNITY_STANDALONE_OSX
        const string prefix = "Mindstone VFX Preview - ";
        return Application.productName.StartsWith(prefix, System.StringComparison.Ordinal)
            ? Application.productName.Substring(prefix.Length)
            : null;
#else
        return null;
#endif
    }

#if UNITY_EDITOR || UNITY_STANDALONE
    IEnumerator RunCommandLinePreviewIfRequested()
    {
        var arguments = System.Environment.GetCommandLineArgs();
        var previewHound = System.Array.Exists(arguments, value => value == "--preview-hound-fire");
        var previewClockCore = System.Array.Exists(arguments, value => value == "--preview-clock-core");
        var previewDualClockGuard = System.Array.Exists(arguments, value => value == "--preview-dual-clock-guard");
        var previewReverseTide = System.Array.Exists(arguments, value => value == "--preview-reverse-tide");
        var previewDefense = System.Array.Exists(arguments, value => value == "--preview-defense");
        var previewPaperDoubleHit = System.Array.Exists(arguments, value => value == "--preview-paper-double-hit");
        var previewPlayerDefeat = System.Array.Exists(arguments, value => value == "--preview-player-defeat");
        var captureDefeatFrames = System.Array.Exists(arguments, value => value == "--capture-defeat-frames");
        var captureSkillFrames = System.Array.Exists(arguments, value => value == "--capture-skill-frames");
        var capturePaperDoubleHitFrames = System.Array.Exists(arguments, value => value == "--capture-paper-double-hit-frames");
        var vfxArgument = System.Array.Find(arguments, value => value.StartsWith("--preview-vfx="));
        var vfxBoardArgument = System.Array.Find(arguments, value => value.StartsWith("--preview-vfx-board="));
        var builtInVFXBoardEffect = GetBuiltInVFXBoardPreviewEffect();
        var skillArgument = System.Array.Find(arguments, value => value.StartsWith("--preview-skill="));
        if (!previewHound && !previewClockCore && !previewDualClockGuard && !previewReverseTide
            && !previewDefense && !previewPaperDoubleHit && !previewPlayerDefeat && string.IsNullOrEmpty(vfxArgument)
            && string.IsNullOrEmpty(vfxBoardArgument) && string.IsNullOrEmpty(builtInVFXBoardEffect)
            && string.IsNullOrEmpty(skillArgument)) yield break;

        // Give automated desktop preview capture enough time to focus the
        // player window before the short skill animation starts.
        yield return new WaitForSeconds(
            captureSkillFrames || capturePaperDoubleHitFrames || previewDualClockGuard
                || previewReverseTide || !string.IsNullOrEmpty(vfxArgument)
                || !string.IsNullOrEmpty(vfxBoardArgument) || !string.IsNullOrEmpty(builtInVFXBoardEffect)
                ? 0.75f
                : 12.0f);
        if (!string.IsNullOrEmpty(vfxBoardArgument) || !string.IsNullOrEmpty(builtInVFXBoardEffect))
        {
            var board = gameObject.AddComponent<MistportVFXShowcaseBoard>();
            yield return board.Play(
                this,
                !string.IsNullOrEmpty(vfxBoardArgument)
                    ? vfxBoardArgument.Substring("--preview-vfx-board=".Length)
                    : builtInVFXBoardEffect);
            yield break;
        }
        if (!string.IsNullOrEmpty(vfxArgument))
        {
            yield return RunSpellShowcasePreview(vfxArgument.Substring("--preview-vfx=".Length));
            yield break;
        }
        if (previewReverseTide)
        {
            UseHellHoundPounceModel();
            SetStatus("失秒巡猎犬 · 逆潮咬合");
            yield return new WaitForSeconds(0.30f);
            StartCoroutine(reverseTideVFX.Play(
                () => HellHoundFireBreathSourceAnchor,
                () => PlayerFireBreathImpactAnchor
            ));

            var reverseCaptureTimes = new[] { 0.16f, 0.40f, 0.68f };
            var reversePreviousTime = 0f;
            for (var index = 0; index < reverseCaptureTimes.Length; index++)
            {
                yield return new WaitForSeconds(reverseCaptureTimes[index] - reversePreviousTime);
                yield return new WaitForEndOfFrame();
                CapturePreviewFrame($"/private/tmp/mindstone-reverse-tide-stage-{index + 1}.bmp");
                reversePreviousTime = reverseCaptureTimes[index];
            }
            yield return new WaitForSeconds(0.45f);
            reverseTideVFX.StopRoot();
            yield break;
        }
        if (previewHound)
        {
            UseHellHoundModel();
            yield return new WaitForSeconds(0.35f);
            // Preview the approved terminal beat directly. The production
            // choreography still runs charge -> instant detonation, while a
            // deterministic direct impact makes review screenshots reliable.
            yield return hellHoundFireball.PlayImpact(
                () => PlayerFireBreathImpactAnchor);
            yield break;
        }

        if (previewClockCore)
        {
            UseClockCoreModel();
            yield break;
        }

        if (previewDualClockGuard)
        {
            UseDualClockGuardModel();
            yield break;
        }

        if (previewDefense)
        {
            var paperAnchor = GetPaperDoubleAnchor();
            StartCoroutine(foolDefenseVFX.Play(
                () => paperAnchor,
                true
            ));
            var defenseCaptureTimes = new[] { 0.12f, 0.34f, 0.76f, 1.04f };
            var previousDefenseTime = 0f;
            for (var index = 0; index < defenseCaptureTimes.Length; index++)
            {
                yield return new WaitForSeconds(defenseCaptureTimes[index] - previousDefenseTime);
                yield return new WaitForEndOfFrame();
                CapturePreviewFrame($"/private/tmp/mindstone-defense-stage-{index + 1}.bmp");
                previousDefenseTime = defenseCaptureTimes[index];
            }
            yield break;
        }

        if (previewPaperDoubleHit)
        {
            UseHellHoundPounceModel();
            var paperAnchor = GetPaperDoubleAnchor();
            foolDefenseVFX.Deploy(() => paperAnchor);
            yield return new WaitForSeconds(0.68f);
            yield return new WaitForEndOfFrame();
            CapturePreviewFrame("/private/tmp/mindstone-paper-double-hit-stage-1.bmp");

            SetStatus("纸人代身 · 承接扑击");
            SetPlayerVisualVisible(false);
            foolDefenseVFX.Consume();
            var paperHitCaptureTimes = new[] { 0.10f, 0.42f, 0.92f };
            var previousPaperHitTime = 0f;
            for (var index = 0; index < paperHitCaptureTimes.Length; index++)
            {
                yield return new WaitForSeconds(paperHitCaptureTimes[index] - previousPaperHitTime);
                yield return new WaitForEndOfFrame();
                CapturePreviewFrame($"/private/tmp/mindstone-paper-double-hit-stage-{index + 2}.bmp");
                previousPaperHitTime = paperHitCaptureTimes[index];
            }
            yield return foolDefenseVFX.WaitForCompletion();
            SetPlayerVisualVisible(true);
            yield break;
        }

        if (previewPlayerDefeat)
        {
            StartCoroutine(PresentPlayerDefeatSequence());
            if (!captureDefeatFrames) yield break;
            var defeatCaptureTimes = new[] { 0.12f, 0.32f, 0.58f, 0.82f };
            var previousDefeatTime = 0f;
            for (var index = 0; index < defeatCaptureTimes.Length; index++)
            {
                yield return new WaitForSeconds(defeatCaptureTimes[index] - previousDefeatTime);
                yield return new WaitForEndOfFrame();
                CapturePreviewFrame($"/private/tmp/mindstone-defeat-stage-{index + 1}.bmp");
                previousDefeatTime = defeatCaptureTimes[index];
            }
            yield break;
        }

        UseClockGuardModel();
        var skillID = skillArgument.Substring("--preview-skill=".Length);
        PresentPlayerSkill(skillID);
        if (!captureSkillFrames) yield break;

        var captureTimes = new[] { 0.10f, 0.27f, 0.45f, 0.72f };
        var previousTime = 0f;
        for (var index = 0; index < captureTimes.Length; index++)
        {
            yield return new WaitForSeconds(captureTimes[index] - previousTime);
            yield return new WaitForEndOfFrame();
            CapturePreviewFrame($"/private/tmp/mindstone-skill-stage-{index + 1}.bmp");
            previousTime = captureTimes[index];
        }
    }

    IEnumerator RunSpellShowcasePreview(string effectID)
    {
        var captureTimes = effectID switch
        {
            "sword" => new[] { 0.18f, 0.52f, 0.82f, 1.18f, 1.62f },
            "fireball" => new[]
            {
                0.12f, 0.36f, 0.60f, 0.84f, 1.28f
            },
            "tornado" => new[] { 0.16f, 0.38f, 0.62f, 0.82f, 1.04f },
            "hound" => new[] { 0.18f, 0.52f, 0.82f, 1.18f, 1.62f },
            "cheetah" => new[] { 0.22f, 0.60f, 1.02f, 1.42f, 1.82f },
            _ => System.Array.Empty<float>()
        };
        if (captureTimes.Length == 0) yield break;

        // Capture the live visual anchor before the effect layers build over
        // the actor. The actor stays rendered throughout this preview: the
        // spell itself must create the occlusion, not a hidden renderer.
        var showcaseTargetAnchor = PlayerSpellImpactAnchor;
        System.Func<Vector3> target = () => showcaseTargetAnchor;
        SetPlayerVisualVisible(true);
        if (effectID == "sword")
        {
            UseClockGuardModel();
            SetStatus("剑气 · 破空斩");
            enemyAnimator?.SetTrigger("Attack");
            System.Func<Vector3> source = () => enemy != null
                ? enemy.transform.position + Vector3.up * 1.15f
                : target();
            StartCoroutine(spellShowcaseVFX.PlaySwordQi(source, target));
        }
        else if (effectID == "fireball")
        {
            UseHellHoundPounceModel();
            SetStatus("火球 · 冥焰爆燃");
            enemyAnimator?.SetTrigger("Attack");
            StartCoroutine(PlayShowcaseFireball(target));
        }
        else if (effectID == "hound")
        {
            UseClockGuardModel();
            SetStatus("剑气 · 破空斩");
            System.Func<Vector3> source = () => enemy != null
                ? enemy.transform.position + Vector3.up * 1.08f
                : target();
            enemyAnimator?.SetTrigger("Attack");
            StartCoroutine(spellShowcaseVFX.PlaySwordQi(source, target));
        }
        else if (effectID == "cheetah")
        {
            UseClockGuardModel();
            SetStatus("幽冥猎豹 · 扑击爆发");
            System.Func<Vector3> source = () => enemy != null
                ? enemy.transform.position + Vector3.up * 1.08f
                : target();
            enemyAnimator?.SetTrigger("Attack");
            StartCoroutine(spellShowcaseVFX.PlaySpectralHound(source, target));
        }
        else
        {
            UseClockGuardModel();
            SetStatus("旋风 · 失序回流");
            StartCoroutine(spellShowcaseVFX.PlayTornado(target));
        }

        var previousTime = 0f;
        for (var index = 0; index < captureTimes.Length; index++)
        {
            yield return new WaitForSeconds(captureTimes[index] - previousTime);
            yield return new WaitForEndOfFrame();
            CapturePreviewFrame($"/private/tmp/mindstone-showcase-{effectID}-stage-{index + 1}.bmp");
            previousTime = captureTimes[index];
        }
        yield return new WaitForSeconds(0.45f);
        SetPlayerVisualVisible(true);
        spellShowcaseVFX.Stop();
    }

    IEnumerator PlayShowcaseFireball(System.Func<Vector3> target)
    {
        System.Func<Vector3> source = () => HellHoundFireBreathSourceAnchor;
        // Use the target-bound showcase choreography here. The native hound
        // presentation keeps its own FireBall path; this preview needs the
        // full projectile-to-impact composition to land on the protagonist.
        yield return spellShowcaseVFX.PlayFireball(source, target);
    }

    public void PrepareVFXShowcaseActors(string effectID, float xPosition)
    {
        if (player == null || enemy == null)
            return;

        var useHellHound = string.Equals(effectID, "fireball", StringComparison.OrdinalIgnoreCase)
            || SpellBridge.TryGetShowcase(effectID, out var v1Showcase)
                && string.Equals(v1Showcase.sourceActor, "hellhound", StringComparison.OrdinalIgnoreCase);
        if (useHellHound)
            UseHellHoundPounceModel();
        else
            UseClockGuardModel();

        SetPlayerVisualVisible(true);
        playerHome = GroundedAt(
            player,
            new Vector3(xPosition, 0f, -3.8f));
        player.transform.position = playerHome;

        var enemyPosition = enemyHome;
        enemyPosition.x = xPosition;
        // The normal Clock Plaza formation keeps enemies at Z=12. That is
        // correct for the battle camera, but it would place the actor behind
        // the showcase panel at Z=4.5. The board owns its own shallow depth
        // composition so the enemy silhouette remains visible beside the
        // protagonist and the effect can still resolve from live anchors.
        enemyPosition.z = 1.60f;
        enemy.transform.position = enemyPosition;
        enemyHome = enemyPosition;
        enemy.transform.rotation = Quaternion.identity;

        if (useHellHound)
            FaceHellHoundAt(player.transform.position);

        playerAnimator?.SetBool("Running", false);
        playerAnimator?.Play("Meshy · Idle", 0, 0f);
        playerAnimator?.Update(0f);
        enemyAnimator?.SetBool("Running", false);
        enemyAnimator?.Play("Meshy · Idle", 0, 0f);
        enemyAnimator?.Update(0f);

    }

    public Vector3 VFXShowcaseEnemySourceAnchor => enemy != null
        ? enemy.transform.position + Vector3.up * 1.15f
        : Vector3.zero;

    public void TriggerVFXShowcaseAttack()
    {
        enemyAnimator?.SetTrigger("Attack");
    }

    public IEnumerator PlayVFXShowcaseEffect(string effectID)
    {
        var target = (System.Func<Vector3>)(() => PlayerSpellImpactAnchor);
        if (spellV1Bridge != null && spellV1Bridge.CanPlay(effectID))
        {
            var source = (System.Func<Vector3>)(() =>
            {
                SpellBridge.TryGetShowcase(effectID, out var showcase);
                if (string.Equals(showcase?.sourceActor, "hellhound", StringComparison.OrdinalIgnoreCase))
                    return HellHoundFireBreathSourceAnchor;
                if (string.Equals(showcase?.sourceActor, "player", StringComparison.OrdinalIgnoreCase))
                    return PlayerSpellImpactAnchor;
                return VFXShowcaseEnemySourceAnchor;
            });
            yield return spellV1Bridge.Play(
                effectID,
                source,
                target,
                mouth: source,
                impact: target,
                ground: target);
        }
        else if (string.Equals(effectID, "fireball", StringComparison.OrdinalIgnoreCase))
        {
            yield return spellShowcaseVFX.PlayFireball(
                () => HellHoundFireBreathSourceAnchor,
                target);
        }
        else if (string.Equals(effectID, "wildwarden", StringComparison.OrdinalIgnoreCase))
        {
            yield return spellShowcaseVFX.PlayWildWarden(target);
        }
        else if (string.Equals(effectID, "fireelementalist", StringComparison.OrdinalIgnoreCase))
        {
            yield return spellShowcaseVFX.PlayFireElementalist(
                () => VFXShowcaseEnemySourceAnchor,
                target);
        }
        else
        {
            yield return spellShowcaseVFX.PlaySwordQi(
                () => VFXShowcaseEnemySourceAnchor,
                target);
        }
    }

    public void StopVFXShowcaseEffect()
    {
        spellV1Bridge?.Stop();
        spellShowcaseVFX?.Stop();
    }

    public static void CapturePreviewFrame(string path)
    {
        var texture = new Texture2D(Screen.width, Screen.height, TextureFormat.RGB24, false);
        texture.ReadPixels(new Rect(0f, 0f, Screen.width, Screen.height), 0, 0);
        texture.Apply(false);
        var pixels = texture.GetPixels32();
        var rowBytes = Screen.width * 3;
        var paddedRowBytes = (rowBytes + 3) & ~3;
        var pixelBytes = paddedRowBytes * Screen.height;
        using (var stream = System.IO.File.Create(path))
        using (var writer = new System.IO.BinaryWriter(stream))
        {
            writer.Write((byte)'B');
            writer.Write((byte)'M');
            writer.Write(54 + pixelBytes);
            writer.Write(0);
            writer.Write(54);
            writer.Write(40);
            writer.Write(Screen.width);
            writer.Write(Screen.height);
            writer.Write((short)1);
            writer.Write((short)24);
            writer.Write(0);
            writer.Write(pixelBytes);
            writer.Write(2835);
            writer.Write(2835);
            writer.Write(0);
            writer.Write(0);
            var padding = paddedRowBytes - rowBytes;
            for (var y = 0; y < Screen.height; y++)
            {
                for (var x = 0; x < Screen.width; x++)
                {
                    var pixel = pixels[y * Screen.width + x];
                    writer.Write(pixel.b);
                    writer.Write(pixel.g);
                    writer.Write(pixel.r);
                }
                for (var pad = 0; pad < padding; pad++) writer.Write((byte)0);
            }
        }
        Destroy(texture);
    }

#endif

    void Update()
    {
        // The embedded iOS root view can be resized after Unity starts. Keep
        // the authored background covering the current camera viewport rather
        // than preserving the old launch-time portrait rectangle.
        FitRuntimeBackground(Camera.main);

        for (var i = 0; i < rings.Count; i++)
            rings[i].Rotate(Vector3.up, (i % 2 == 0 ? 1f : -1f) * (8f + i * 5f) * Time.deltaTime, Space.World);
        var weaponPulse = 0.72f + Mathf.Sin(Time.time * 6.8f) * 0.18f
            + Mathf.Sin(Time.time * 13.7f) * 0.07f;
        for (var i = 0; i < enemyBladeGlowLines.Count; i++)
        {
            var line = enemyBladeGlowLines[i];
            var core = i == enemyBladeGlowLines.Count - 1;
            line.startWidth = (core ? 0.035f : 0.11f) * (0.90f + weaponPulse * 0.18f);
            line.endWidth = (core ? 0.012f : 0.028f) * (0.88f + weaponPulse * 0.15f);
            var color = core
                ? new Color(1f, 0.90f, 0.78f, 0.92f)
                : new Color(1f, 0.03f + weaponPulse * 0.05f, 0.02f, 0.62f + weaponPulse * 0.18f);
            line.startColor = color;
            line.endColor = new Color(color.r, color.g, color.b, color.a * 0.18f);
            if (i < enemyBladeGlowMaterials.Count
                && enemyBladeGlowMaterials[i].HasProperty("_EmissionColor"))
                enemyBladeGlowMaterials[i].SetColor("_EmissionColor", color * (2.4f + weaponPulse));
        }
    }

    void OnGUI()
    {
#if UNITY_EDITOR || UNITY_STANDALONE
        if (previewPresentation) return;
        if (actionButtonStyle == null)
        {
            actionButtonStyle = new GUIStyle(GUI.skin.button)
            {
                fontSize = 22,
                fontStyle = FontStyle.Bold
            };
            actionButtonStyle.normal.textColor = Color.white;
        }

        GUI.enabled = !actionRunning && enemyHp > 0 && playerHp > 0;
        var width = Mathf.Min(210f, Screen.width * 0.27f);
        var gap = 12f;
        var total = width * 3f + gap * 2f;
        var x = (Screen.width - total) * 0.5f;
        var y = Screen.height - 92f;
        if (GUI.Button(new Rect(x, y, width, 64f), "普攻", actionButtonStyle))
            StartPlayerAction(PlayerAction.Basic);
        if (GUI.Button(new Rect(x + width + gap, y, width, 64f), "错步穿行", actionButtonStyle))
            StartPlayerAction(PlayerAction.Skill);
        if (GUI.Button(new Rect(x + (width + gap) * 2f, y, width, 64f), "防御", actionButtonStyle))
            StartPlayerAction(PlayerAction.Defend);
        GUI.enabled = true;
#endif
    }

    void BuildArena()
    {
#if UNITY_EDITOR || UNITY_STANDALONE
        if (Array.Exists(Environment.GetCommandLineArgs(), argument => argument == "--show-debug-arena-rings")) {
        var floor = GameObject.CreatePrimitive(PrimitiveType.Cylinder);
        floor.name = "Clock Arena";
        floor.transform.position = Vector3.zero;
        floor.transform.localScale = new Vector3(8f, 0.08f, 8f);
        floor.GetComponent<Renderer>().material.color = new Color(0.025f, 0.035f, 0.07f);
        }
#endif

        var camera = Camera.main;
        if (camera == null)
        {
            var cameraObject = new GameObject("Main Camera");
            cameraObject.tag = "MainCamera";
            camera = cameraObject.AddComponent<Camera>();
        }
        // A low, nearly ground-parallel camera makes the encounter read as
        // two fighters facing each other instead of figures viewed from above.
        camera.transform.position = new Vector3(0f, 4.2f, -17.5f);
        camera.transform.rotation = Quaternion.Euler(9f, 0f, 0f);
        camera.fieldOfView = 28f;
        camera.clearFlags = CameraClearFlags.SolidColor;
        camera.backgroundColor = new Color(0.025f, 0.035f, 0.055f);

        var backgroundTexture = Resources.Load<Texture2D>("RuntimeModels/Backgrounds/ClockPlaza");
        if (backgroundTexture)
        {
            var background = GameObject.CreatePrimitive(PrimitiveType.Quad);
            background.name = "Clock Plaza Background";
            // Keep the 2D backdrop safely behind the full enemy formation.
            // Its scale is derived from this distance, so moving it back does
            // not change the visible composition.
            background.transform.SetParent(camera.transform, false);
            background.transform.localPosition = new Vector3(0f, 0f, 80f);
            // The quad is viewed from its front face; rotating it 180 degrees
            // mirrors the harbor artwork on iOS.
            background.transform.localRotation = Quaternion.identity;
            runtimeBackground = background.transform;
            runtimeBackgroundTexture = backgroundTexture;
            FitRuntimeBackground(camera);
            var backgroundShader = Shader.Find("Unlit/Texture")
                ?? Shader.Find("Sprites/Default")
                ?? Shader.Find("UI/Default")
                ?? Shader.Find("Standard");
            if (backgroundShader != null)
            {
                var material = new Material(backgroundShader) { mainTexture = backgroundTexture, renderQueue = 1000 };
                if (material.HasProperty("_Cull")) material.SetInt("_Cull", 0);
                background.GetComponent<Renderer>().material = material;
            }
            else
            {
                Debug.LogWarning("Mindstone: no compatible unlit shader was included; background material was left unchanged.");
            }
        }

#if UNITY_EDITOR || UNITY_STANDALONE
        if (Array.Exists(Environment.GetCommandLineArgs(), argument => argument == "--show-debug-arena-rings"))
        for (var i = 0; i < 3; i++)
        {
            var ring = GameObject.CreatePrimitive(PrimitiveType.Cylinder);
            ring.name = $"Arena Rune Ring {i + 1}";
            ring.transform.position = new Vector3(0f, 0.08f + i * 0.02f, 0f);
            ring.transform.localScale = new Vector3(6.2f - i * 1.2f, 0.02f, 6.2f - i * 1.2f);
            ring.GetComponent<Renderer>().material.color = new Color(0.04f, 0.11f, 0.25f);
            rings.Add(ring.transform);
        }
#endif

        var lightObject = new GameObject("Arena Light");
        var light = lightObject.AddComponent<Light>();
        light.type = LightType.Directional;
        light.intensity = 1.3f;
        lightObject.transform.rotation = Quaternion.Euler(50f, -30f, 0f);
    }

    const float ChurchTowerHeroScale = .60f;
    const float ChurchTowerMajorScale = .65f;
    const float ChurchTowerMinionScale = .54f;
    bool churchTowerFormation;

    void ApplyPlayerEncounterScale()
    {
        if (player != null)
            player.transform.localScale = playerBaseScale * (churchTowerFormation ? ChurchTowerHeroScale : 1f);
    }

    public void SetChurchTowerBackground(bool tower)
    {
        bool formationChanged = churchTowerFormation != tower;
        churchTowerFormation = tower;
        ApplyPlayerEncounterScale();
        if (formationChanged && player != null)
            ResetPlayerScreenPlacement();
        GetComponent<BattleRain>()?.SetWeatherVisible(!tower);
        if (!runtimeBackground) return;
        var texture = Resources.Load<Texture2D>("RuntimeModels/Backgrounds/" + (tower ? "ChurchSealingWell" : "ClockPlaza"));
        if (!texture) return;
        runtimeBackgroundTexture = texture;
        runtimeBackground.GetComponent<Renderer>().material.mainTexture = texture;
        FitRuntimeBackground(Camera.main);
    }

    void SetBountyBackground(string name)
    {
        GetComponent<BattleRain>()?.SetWeatherVisible(false);
        if (!runtimeBackground) return;
        var texture = Resources.Load<Texture2D>("RuntimeModels/Backgrounds/" + name);
        if (!texture) return;
        runtimeBackgroundTexture = texture;
        runtimeBackground.GetComponent<Renderer>().material.mainTexture = texture;
        FitRuntimeBackground(Camera.main);
    }

    void FitRuntimeBackground(Camera camera)
    {
        if (camera == null || runtimeBackground == null || runtimeBackgroundTexture == null)
            return;

        const float backgroundDistance = 80f;
        var viewportHeight = 2f * backgroundDistance
            * Mathf.Tan(camera.fieldOfView * Mathf.Deg2Rad * 0.5f);
        var viewportWidth = viewportHeight * Mathf.Max(0.1f, camera.aspect);
        var sourceAspect = (float)runtimeBackgroundTexture.width
            / Mathf.Max(1, runtimeBackgroundTexture.height);

        // Cover both axes. The previous width-fit made the portrait artwork
        // smaller than the embedded battle viewport and exposed the camera's
        // dark clear color as a frame around the scene.
        var coveredWidth = Mathf.Max(viewportWidth, viewportHeight * sourceAspect);
        var coveredHeight = coveredWidth / sourceAspect;
        runtimeBackground.localScale = new Vector3(coveredWidth, coveredHeight, 1f);
    }

    void BuildCombatants()
    {
        player = GameObject.Find("Fool_Imported");
        clockGuardHandle = FindInstalledEnemyHandle(EnemyBattleIds.ClockGuardPrimary);
        secondaryClockGuardHandle = FindInstalledEnemyHandle(EnemyBattleIds.ClockGuardSecondary);
        clockCoreHandle = FindInstalledEnemyHandle(EnemyBattleIds.ClockCorePrimary);
        hellHoundHandle = FindInstalledEnemyHandle(EnemyBattleIds.HellHoundPrimary);
        memoryLeechHandle = FindInstalledEnemyHandle("memory-leech-primary");
        archivistTemplate = FindInstalledEnemyHandle("archivist-template");
        matriarchTemplate = FindInstalledEnemyHandle("matriarch-template");
        scribeTemplate=FindInstalledEnemyHandle("scribe-template");
        rescueTemplate=FindInstalledEnemyHandle("rescue-template");
        executorTemplate=FindInstalledEnemyHandle("executor-template");
        usingProfileEnemyPipeline = clockGuardHandle != null;

        if (usingProfileEnemyPipeline)
        {
            clockGuard = clockGuardHandle.EnemyRoot.gameObject;
            clockCore = clockCoreHandle != null ? clockCoreHandle.EnemyRoot.gameObject : null;
            hellHound = hellHoundHandle != null ? hellHoundHandle.EnemyRoot.gameObject : null;
        }
        else
        {
            // Compatibility is deliberately isolated; newly installed scenes
            // resolve stable profile IDs and never guess an enemy by object name.
            LegacyEnemyPresentationFallback.FindLegacyEnemies(out clockGuard, out clockCore);
            hellHound = null;
        }

        enemy = clockGuard;
        if (!player || !enemy)
        {
            Debug.LogError("Mindstone: Meshy combatants are not installed. Run Mindstone > Install 3D Battle Assets.");
            return;
        }

        HeroBackArtRefinement.Install(player);
        HeroLivingIdle20260916.Install(player);
        CharacterSurfaceRefinement20260916.Install(player, CharacterSurfaceRefinement20260916.Family.Hero);
        playerAnimator = player.GetComponentInChildren<Animator>(true);
        playerChoreography = FoolSkillChoreography.Install(player.transform);
        playerImpactFeedback = PlayerImpactFeedback20260925.Install(player, this);
        enemyAnimator = enemy.GetComponentInChildren<Animator>(true);
        player.transform.position = GroundedAt(player, new Vector3(0f, 0f, -3.8f));
        playerHome = player.transform.position;
        playerBaseScale = player.transform.localScale;
        ApplyPlayerEncounterScale();
        enemyHome = enemy.transform.position;
        // The Meshy source faces across the stage at identity. Turn it toward
        // the enemy row so the player reads from behind, as in the approved
        // portrait combat composition, while retaining the embedded rig clips.
        player.transform.rotation = Quaternion.Euler(0f, PlayerBattleFacingDegrees, 0f);
        if (!usingProfileEnemyPipeline)
        {
            enemyHome = LegacyEnemyPresentationFallback.ApplyGuardOnly(enemy);
            enemy.transform.position = enemyHome;
        }
        playerAnimator?.SetBool("Running", false);
        playerAnimator?.Play("Meshy · Idle", 0, 0f);
        playerAnimator?.Update(0f);
        enemyAnimator?.SetBool("Running", false);
        enemyAnimator?.Play("Meshy · Idle", 0, 0f);
        enemyAnimator?.Update(0f);
        // The physical blade is skinned into the character mesh, so a hand-bone
        // glow drifts away during the attack clip. Keep attack VFX target-centred.
    }

    static EnemyHandle FindInstalledEnemyHandle(string battleEnemyId)
    {
        var handles = FindObjectsByType<EnemyHandle>(
            FindObjectsInactive.Include,
            FindObjectsSortMode.None);
        EnemyHandle inactiveMatch = null;
        for (var i = 0; i < handles.Length; i++)
        {
            if (handles[i].BattleEnemyId != battleEnemyId) continue;
            if (handles[i].gameObject.activeInHierarchy) return handles[i];
            inactiveMatch = handles[i];
        }
        return inactiveMatch;
    }

    void BuildHud()
    {
        var canvasObject = new GameObject("Combat HUD");
        var canvas = canvasObject.AddComponent<Canvas>();
        canvas.renderMode = RenderMode.ScreenSpaceOverlay;
        var scaler = canvasObject.AddComponent<CanvasScaler>();
        scaler.uiScaleMode = CanvasScaler.ScaleMode.ScaleWithScreenSize;
        scaler.referenceResolution = new Vector2(844f, 1190f);
        canvasObject.AddComponent<GraphicRaycaster>();

        status = Label(canvasObject.transform, "", 25, new Vector2(0f, 410f), new Vector2(760f, 74f));
        enemyHpText = Label(canvasObject.transform, "", 22, new Vector2(0f, 355f), new Vector2(760f, 52f));
        playerHpText = Label(canvasObject.transform, "", 22, new Vector2(0f, -355f), new Vector2(760f, 52f));

        RefreshHud();
    }

    enum PlayerAction
    {
        Basic,
        Skill,
        Defend
    }

    void StartPlayerAction(PlayerAction action)
    {
        if (actionRunning || enemyHp <= 0 || playerHp <= 0) return;
        StartCoroutine(ResolveRound(action));
    }

    // Stable entry points used by the native game bridge. The Swift combat
    // engine remains authoritative; Unity only presents the matching action.
    public void PlayBasicAttack() => StartPlayerAction(PlayerAction.Basic);
    public void PlaySkillAttack() => StartPlayerAction(PlayerAction.Skill);
    public void PlayDefense() => StartPlayerAction(PlayerAction.Defend);

    // Native-game presentation entry points. Unlike the standalone prototype
    // buttons these never calculate a full round: MistportCombatCore owns the
    // rules and explicitly asks Unity for the enemy action after the queued
    // player actions have resolved.
    public bool CanPresentPlayerImpact => NativeCombatEnabled && player && player.activeInHierarchy
        && !playerDefeatPresentationActive && !playerHiddenByPaper;
    public PlayerImpactFeedback20260925 PlayerImpactFeedback => playerImpactFeedback;
    public void BeginPlayerImpactContext(string token) => playerImpactFeedback?.BeginContext(token);
    public void PresentPlayerImpact(string payload) => playerImpactFeedback?.Present(payload);
    public void ClearPlayerImpact(bool invalidateContext = false) => playerImpactFeedback?.Clear(invalidateContext);

    public void PresentEnemyImpact(string payload)
    {
        if (!NativeCombatEnabled || string.IsNullOrWhiteSpace(payload)) return;
        var parts = payload.Split(':');
        if (parts.Length != 2) return;
        var visited = new HashSet<string>();
        foreach (var id in parts[1].Split(','))
        {
            if (!visited.Add(id)) continue;
            EnemyHandle victim = null;
            foreach (var candidate in encounterRoster)
                if (candidate && candidate.BattleEnemyId == id && candidate.gameObject.activeInHierarchy) { victim = candidate; break; }
            if (victim) EnemyImpactFeedback.Install(victim).Play(parts[0]);
        }
    }

    public void PresentPlayerBasic() => StartPresentation(PlayerAction.Basic);
    public void PresentPlayerBasic(string targetID) { if(NativeCombatEnabled)StartCoroutine(PresentPlayerAction(PlayerAction.Basic,targetID)); }
    public void PresentPlayerSkill() => StartPresentation(PlayerAction.Skill);
    string pendingSidestepSecondary;
    string[] pendingSkillTargets;
    public void SetSkillTargets(string ids) { pendingSkillTargets = ids.Split(new[] { '|' }, StringSplitOptions.RemoveEmptyEntries); }
    public void SetSidestepSecondary(string id) { pendingSidestepSecondary = id; }
    public void PresentPlayerSkill(string skillID)
    {
        if (!NativeCombatEnabled || enemy == null || player == null) return;
        var separator = skillID.IndexOf(':');
        var resolvedSkillID = separator >= 0
            ? skillID.Substring(0, separator)
            : skillID;
        var targetBattleEnemyID = separator >= 0
            ? skillID.Substring(separator + 1)
            : null;
        var secondary = pendingSidestepSecondary; pendingSidestepSecondary = null;
        var resolvedTargets = pendingSkillTargets; pendingSkillTargets = null;
        StartCoroutine(PresentPlayerSkillAction(resolvedSkillID, targetBattleEnemyID, secondary, resolvedTargets));
    }
    public void PresentPlayerDefense() => StartPresentation(PlayerAction.Defend);

    public void PresentEnemyAttack()
    {
        if (!NativeCombatEnabled || enemy == null || player == null) return;
        if (encounterModel == EncounterModel.HellHound)
        {
            StartCoroutine(PresentHellHoundFireBreathTurn());
            return;
        }
        StartCoroutine(PresentEnemyTurn());
    }

    public void SetQ4HoundPhase(string phase)
    {
        var idle = hellHoundHandle ? hellHoundHandle.GetComponent<EarlyEnemyIdlePresence>() : null;
        if (idle) {
            if (phase == "charge" || phase == "first" || phase == "second" || phase == "opening") idle.SuspendForAction();
            else idle.ResumeIdle();
        }
        if (!q4Hound) q4Hound = gameObject.AddComponent<Q4HoundPresentation>();
        if (phase == "clear") { q4Hound.Clear(); return; }
        q4Hound.Configure(hellHoundHandle ? hellHoundHandle.EnemyRoot : null,
            () => HellHoundFireBreathSourceAnchor + Vector3.up * (hellHoundHandle&&hellHoundHandle.ProfileEnemyId=="early-hell-hound"?0:.45f), () => PlayerFireBreathImpactAnchor);
        if ((phase == "first" || phase == "second") && IsActiveEnemyHandle(hellHoundHandle))
            SpellSpectacle20260926.BeginEnemy(this, hellHoundHandle, "q4_" + phase, () => PlayerFireBreathImpactAnchor, null);
        q4Hound.SetPhase(phase);
    }

    ArchiveEncounterPresentation archivePresentation;
    readonly Dictionary<string,ArchiveEncounterPresentation> repairPresentations=new Dictionary<string,ArchiveEncounterPresentation>();
    void ClearRepairPresentations(){foreach(var effect in repairPresentations.Values)if(effect)effect.Clear();}
    ArchiveEncounterPresentation RepairPresentation(string actorID){
        if(!repairPresentations.TryGetValue(actorID,out var effect)||!effect){effect=gameObject.AddComponent<ArchiveEncounterPresentation>();repairPresentations[actorID]=effect;}
        return effect;
    }
    ArchiveEncounterPresentation ArchivePresentation {
        get { if (!archivePresentation) archivePresentation=gameObject.AddComponent<ArchiveEncounterPresentation>(); return archivePresentation; }
    }
    public void PresentEnemyHealing(string actorID) {
        var handle=FindInstalledEnemyHandle(actorID);
        if(!NativeCombatEnabled || !IsActiveEnemyHandle(handle))return;
        var effect=RepairPresentation("heal-"+actorID);effect.Clear();
        Color? tint=handle.ProfileEnemyId=="bounty-b10"?new Color(.94f,.38f,.52f):null;
        effect.StartCoroutine(effect.HealConfirmed(handle.EnemyRoot,tint));
    }
    public void SetArchivePhase(string phase) {
        var handle=FindInstalledEnemyHandle("clock-guard-primary");
        ArchivePresentation.SetArchive(handle ? handle.EnemyRoot : null,phase);
    }
    public void SetLeechCharge(string phase) {
        var handle=FindInstalledEnemyHandle("memory-leech-primary");
        ArchivePresentation.SetLeech(handle ? handle.EnemyRoot : null,phase);
    }

    public void PresentEnemyAttack(string battleEnemyId)
    {
        if (!NativeCombatEnabled || player == null) return;
        var intentParts = battleEnemyId.Split(':');
        bool nameDevour = intentParts.Length == 2 && intentParts[1] == "name_devour";
        var actingHandle = FindInstalledEnemyHandle(intentParts[0]);
        if (actingHandle && actingHandle.EnemyRoot && actingHandle.EnemyRoot.GetComponent<EnemySubduedPresentation>() is EnemySubduedPresentation subdued && subdued.IsSubdued) return;
        if (IsActiveEnemyHandle(actingHandle)) {
            SpellAudioDirector20260924.BeginEnemy(this, intentParts[0], intentParts.Length > 1 ? intentParts[1] : "strike", actingHandle.ProfileEnemyId);
            SpellSpectacle20260926.BeginEnemy(this, actingHandle, intentParts.Length > 1 ? intentParts[1] : "strike", () => PlayerFireBreathImpactAnchor,
                intentParts.Length > 2 ? FindInstalledEnemyHandle(intentParts[2]) : null);
        }
        var bounty=actingHandle?actingHandle.GetComponent<BountyIdentityPresentation20260917>():null;
        if(bounty && IsActiveEnemyHandle(actingHandle)) {
            string intent=intentParts.Length>1?intentParts[1]:"strike";
            if(intent=="guard"||intent=="charge"||intent=="recover"||intent=="bounty_bind_charge"||intent=="bounty_copy_charge"||intent=="bounty_knock_charge"||intent=="bounty_veil_charge"||intent=="bounty_armor"||intent=="bounty_mirror"){
                bounty.Prepare(intent);
                if(intent=="guard"||intent=="bounty_armor"){var h=actingHandle;SpellSpectacle20260926.PlayState(this,bounty.bountyID=="b06"?"anchor-ward":"stone-ward",()=>SpellSpectacle20260926.AnchorOf(h),SpellSpectacle20260926.StableHash(h.BattleEnemyId));}
                return;}
            StartCoroutine(bounty.Strike(actingHandle,()=>PlayerFireBreathImpactAnchor,intent,()=>UnityBattleBridge.ReportCombatContact("enemy:"+actingHandle.BattleEnemyId),()=>NativeCombatEnabled&&IsActiveEnemyHandle(actingHandle)));return;
        }
        var churchDemon=actingHandle?actingHandle.GetComponent<ChurchDemonPresentation20260917>():null;
        if(churchDemon && intentParts.Length>=2 && IsActiveEnemyHandle(actingHandle)) {
            string intent=intentParts[1];
            if(ChurchDemonPresentation20260917.IsPreparation(intent)){churchDemon.Prepare(intent);return;}
            if(intent.StartsWith("tower_")) {
                var recipient=intentParts.Length>=3?FindInstalledEnemyHandle(intentParts[2]):null;
                bool support=intent=="tower_mend"||intent=="tower_empower";
                var presentationBridge=FindFirstObjectByType<UnityBattleBridge>();
                if(support&&(!IsActiveEnemyHandle(recipient)||(presentationBridge&&presentationBridge.IsEnemyExiting(recipient)))){UnityBattleBridge.ReportCombatContact("enemy-cancel:"+actingHandle.BattleEnemyId);return;}
                StartCoroutine(churchDemon.Act(actingHandle,()=>support?recipient.EffectAnchor.position:PlayerFireBreathImpactAnchor,intent,
                    ()=>UnityBattleBridge.ReportCombatContact("enemy:"+actingHandle.BattleEnemyId),
                    ()=>NativeCombatEnabled&&IsActiveEnemyHandle(actingHandle)&&(!support||(IsActiveEnemyHandle(recipient)&&(!presentationBridge||!presentationBridge.IsEnemyExiting(recipient)))),
                    ()=>{if(NativeCombatEnabled&&IsActiveEnemyHandle(actingHandle))UnityBattleBridge.ReportCombatContact("enemy-cancel:"+actingHandle.BattleEnemyId);}));return;
            }
        }
        if(intentParts.Length==2 && IsActiveEnemyHandle(actingHandle)) {
            var stone=actingHandle.GetComponent<StonehidePresentation20260917>();
            if(stone && (intentParts[1]=="guard" || intentParts[1]=="charge" || intentParts[1]=="recover")) {
                stone.SetDefensivePhase(intentParts[1]);
                if(intentParts[1]=="guard"){var h=actingHandle;SpellSpectacle20260926.PlayState(this,"stone-ward",()=>SpellSpectacle20260926.AnchorOf(h),SpellSpectacle20260926.StableHash(h.BattleEnemyId));}
                return; }
            if(intentParts[1]=="tower_pounce_charge" || intentParts[1]=="tower_hound_pounce" || (intentParts[1]=="recover"&&actingHandle.GetComponent<TowerHoundPresentation20260917>())) {
                var tower=actingHandle.GetComponent<TowerHoundPresentation20260917>();if(!tower)tower=actingHandle.gameObject.AddComponent<TowerHoundPresentation20260917>();
                if(intentParts[1]=="tower_pounce_charge")tower.PreparePounce(actingHandle);
                else if(intentParts[1]=="recover")tower.Cancel();
                else StartCoroutine(tower.Pounce(actingHandle,()=>PlayerFireBreathImpactAnchor,()=>{if(NativeCombatEnabled&&IsActiveEnemyHandle(actingHandle))UnityBattleBridge.ReportCombatContact("enemy:"+actingHandle.BattleEnemyId);}));return;
            }
            if(intentParts[1]=="tower_flame_first" || intentParts[1]=="tower_flame_second") {
                var tower=actingHandle.GetComponent<TowerHoundPresentation20260917>();
                if(!tower)tower=actingHandle.gameObject.AddComponent<TowerHoundPresentation20260917>();
                StartCoroutine(tower.Shot(actingHandle,()=>PlayerFireBreathImpactAnchor,intentParts[1].EndsWith("second"),
                    ()=>{if(NativeCombatEnabled && IsActiveEnemyHandle(actingHandle))UnityBattleBridge.ReportCombatContact("enemy:"+actingHandle.BattleEnemyId);})); return;
            }
        }
        if (intentParts.Length == 3 && intentParts[1] == "repair_guard") {
            var source=FindInstalledEnemyHandle(intentParts[0]); var recipient=FindInstalledEnemyHandle(intentParts[2]);
            var repair=RepairPresentation(intentParts[0]); repair.Clear();
            var committedActorID=intentParts[0];
            repair.StartCoroutine(repair.Repair(source ? source.EnemyRoot : null,recipient ? recipient.EnemyRoot : null,
                () => { if(NativeCombatEnabled) UnityBattleBridge.ReportCombatContact("enemy:"+committedActorID); }));
            return;
        }
        if(intentParts.Length==2 && (intentParts[1]=="archive_slam" || intentParts[1]=="name_devour")) {
            archivePresentation?.Clear(); battleEnemyId=intentParts[0];
        }
        if(intentParts.Length==2 && intentParts[1]=="thirteenth_charge") {
            var elite=FindInstalledEnemyHandle(intentParts[0]);
            if(IsActiveEnemyHandle(elite))StartCoroutine(PresentEliteChargedStrike(elite));
            return;
        }
        // Defensive/preparation beats still acknowledge the actor's contact,
        // but must not swing at the player or consume the phantom hit VFX.
        var intentSeparator = battleEnemyId.LastIndexOf(':');
        if (intentSeparator > 0 && battleEnemyId.StartsWith("clock-guard-"))
        {
            var intent = battleEnemyId.Substring(intentSeparator + 1);
            if (intent == "guard" || intent == "fortify" || intent == "calibrate" || intent == "calibration" || intent == "recover")
            {
                var actorId = battleEnemyId.Substring(0, intentSeparator);
                var preparingActor = FindInstalledEnemyHandle(actorId);
                if (IsActiveEnemyHandle(preparingActor))
                    StartCoroutine(PresentClockGuardPreparation(preparingActor, intent));
                return;
            }
        }
        if (battleEnemyId == EnemyBattleIds.HellHoundPrimary && q4Hound && q4Hound.Enabled)
        {
            StartCoroutine(q4Hound.Shot(
                () => { if (NativeCombatEnabled) UnityBattleBridge.ReportCombatContact("enemy:" + battleEnemyId); },
                () => { if (NativeCombatEnabled) UnityBattleBridge.ReportPresentationComplete("enemy"); }));
            return;
        }
        var instance = FindInstalledEnemyHandle(battleEnemyId);
        if (IsActiveEnemyHandle(instance) && instance.GetComponent<SignatureEnemyPresentation>()
            && !(instance == hellHoundHandle && emeraldRevenant && emeraldRevenant.IsInstalled)) {
            StartCoroutine(PresentSignatureEnemyTurn(instance)); return;
        }
        if (IsActiveEnemyHandle(instance) && battleEnemyId.StartsWith("memory-leech-")) {
            StartCoroutine(PresentMemoryLeechCast(instance,nameDevour)); return;
        }
        if (IsActiveEnemyHandle(instance) && battleEnemyId.StartsWith("clock-core-")) {
            StartCoroutine(RotateClockCoreCast(instance)); return;
        }
        if (IsActiveEnemyHandle(instance) && battleEnemyId.StartsWith("clock-guard-")) {
            StartCoroutine(PresentSingleClockGuardTurn(instance)); return;
        }
        if (battleEnemyId == "hell-hound-primary:bite") { StartCoroutine(PresentHellHoundPounceTurn()); return; }
        if (battleEnemyId == "hell-hound-primary:charge") { return; }
        if (battleEnemyId == EnemyBattleIds.HellHoundPrimary) {
            StartCoroutine(PresentHellHoundFireBreathTurn()); return;
        }
        if (battleEnemyId == "memory-leech-primary") {
            StartCoroutine(PresentMemoryLeechCast(memoryLeechHandle,nameDevour)); return;
        }
        if (battleEnemyId == EnemyBattleIds.ClockGuardPrimary)
            StartCoroutine(PresentSingleClockGuardTurn(clockGuardHandle));
        else if (battleEnemyId == EnemyBattleIds.ClockGuardSecondary)
            StartCoroutine(PresentSingleClockGuardTurn(secondaryClockGuardHandle));
        else
            PresentEnemyAttack();
    }

    IEnumerator PresentMemoryLeechCast(EnemyHandle handle,bool nameDevour=false)
    {
        var leech = handle?.GetComponentInChildren<MemoryLeechPresentation>();
        if (leech == null) yield break;
        yield return leech.Cast(handle.EffectAnchor.position,
            () => player.transform.position + Vector3.up,
            () => UnityBattleBridge.ReportCombatContact("enemy:" + handle.BattleEnemyId),nameDevour);
    }

    readonly List<EnemyHandle> additionalWaveEnemies = new List<EnemyHandle>();

    // Reuses installed art only for the same enemy family. Unknown families
    // fail visibly rather than substituting a guard for a missing elite.
    Coroutine pendingWaveSetup;
    public void RequestWaveInstances(string payload)
    {
        if (payload.Contains("@bounty-b05")) SetBountyBackground("BountyDyehouse");
        else if (payload.Contains("@bounty-b03") || payload.Contains("@bounty-b06")) SetBountyBackground("ClockHarbor");
        if (pendingWaveSetup != null) StopCoroutine(pendingWaveSetup);
        pendingWaveSetup = StartCoroutine(ConfigureWaveWhenInstalled(payload));
    }
    IEnumerator ConfigureWaveWhenInstalled(string payload)
    {
        while (clockGuardHandle == null || memoryLeechHandle == null || clockCoreHandle == null)
            yield return null;
        ConfigureWaveInstances(payload);
        pendingWaveSetup = null;
    }

    public void ConfigureWaveInstances(string payload)
    {
        archivePresentation?.Clear(); ClearRepairPresentations();
        ParkQ2SplitGhosts();
        SetEncoreRevenant(false);
        SelectHellHoundVariant(payload.Contains("@early-hell-hound"));
        var descriptors = payload.Split(',');
        var ids = Array.ConvertAll(descriptors, d => d.Split('@')[0]);
        if (ids.Length == 0 || ids.Length > 4) throw new System.ArgumentException("Wave must contain 1–4 enemies.");
        var unique = new HashSet<string>();
        var sources = new List<EnemyHandle>();
        for (int sourceIndex = 0; sourceIndex < ids.Length; sourceIndex++) {
            var id = ids[sourceIndex];
            var parts = descriptors[sourceIndex].Split('@');
            var skin = parts.Length == 2 ? parts[1] : "";
            if (Array.IndexOf(new[] { "", "copperback", "crimson-brute", "veil-oracle", "golden-throat", "moonfang", "ghost", "bounty-b01", "bounty-b02", "bounty-b03", "bounty-b04", "bounty-b05", "bounty-b06", "bounty-b07", "bounty-b08", "bounty-b08-echo", "bounty-b09", "bounty-b10", "bounty-b10-vessel", "saltmaw", "shellback", "ironclaw", "frilled-naga", "boneclaw", "stonehide", "chronarch", "adjudicator", "convoy", "early-hell-hound", "executor", "scribe", "rescue", "archivist", "matriarch", "fog-ghost", "crimson-ghost" }, skin) < 0)
                throw new ArgumentException("Unknown enemy model descriptor: " + skin);
            if (!unique.Add(id)) throw new System.ArgumentException("Duplicate enemy identity: " + id);
            var source = skin == "ghost" ? clockGuardHandle
                : skin == "bounty-b01" ? ResolveBountyArtTemplate("b01")
                : skin == "bounty-b02" ? ResolveBountyArtTemplate("b02")
                : skin == "bounty-b03" ? ResolveBountyArtTemplate("b03")
                : skin == "bounty-b04" ? executorTemplate
                : skin == "bounty-b05" ? ResolveBountyArtTemplate("b05")
                : skin == "bounty-b06" ? ResolveChapterThirtyTemplate(ref adjudicatorTemplate,"adjudicator","ArchiveAdjudicator")
                : skin == "bounty-b07" ? ResolveBountyArtTemplate("b07")
                : skin == "bounty-b08" || skin == "bounty-b08-echo" ? ResolveBountyArtTemplate("b08")
                : skin == "bounty-b09" ? ResolveBountyArtTemplate("b09")
                : skin == "bounty-b10" ? ResolveBountyArtTemplate("b10")
                : skin == "bounty-b10-vessel" ? ResolveBountyArtTemplate("b10-vessel")
                : skin == "copperback" ? ResolveChapterThirtyTemplate(ref copperbackTemplate, "copperback", "Copperback")
                : skin == "crimson-brute" ? ResolveChapterThirtyTemplate(ref crimsonBruteTemplate, "crimson-brute", "CrimsonBrute")
                : skin == "veil-oracle" ? ResolveChapterThirtyTemplate(ref veilOracleTemplate, "veil-oracle", "VeilOracle")
                : skin == "golden-throat" ? ResolveChapterThirtyTemplate(ref goldenThroatTemplate, "golden-throat", "GoldenThroat")
                : skin == "moonfang" ? ResolveChapterThirtyTemplate(ref moonfangTemplate, "moonfang", "Moonfang")
                : skin == "saltmaw" ? ResolveChapterThirtyTemplate(ref saltmawTemplate, "saltmaw", "Saltmaw")
                : skin == "shellback" ? ResolveChapterThirtyTemplate(ref shellbackTemplate, "shellback", "Shellback")
                : skin == "ironclaw" ? ResolveChapterThirtyTemplate(ref ironclawTemplate, "ironclaw", "Ironclaw")
                : skin == "frilled-naga" ? ResolveChapterThirtyTemplate(ref nagaTemplate, "frilled-naga", "FrilledNaga")
                : skin == "boneclaw" ? ResolveChapterThirtyTemplate(ref boneclawTemplate, "boneclaw", "Boneclaw")
                : skin == "stonehide" ? ResolveChapterThirtyTemplate(ref stonehideTemplate, "stonehide", "Stonehide")
                : skin == "chronarch" ? ResolveChapterThirtyTemplate(ref chronarchTemplate, "chronarch", "Chronarch")
                : skin == "adjudicator" ? ResolveChapterThirtyTemplate(ref adjudicatorTemplate, "adjudicator", "ArchiveAdjudicator")
                : skin == "convoy" ? ResolveChapterThirtyTemplate(ref convoyTemplate, "convoy", "ArchiveConvoy")
                : skin == "early-hell-hound" ? hellHoundHandle
                : skin == "executor" ? executorTemplate : skin == "scribe" ? scribeTemplate : skin == "rescue" ? rescueTemplate : skin == "archivist" ? archivistTemplate : skin == "matriarch" ? matriarchTemplate
                : id.StartsWith("memory-leech-") ? memoryLeechHandle
                : id.StartsWith("clock-core-") ? clockCoreHandle
                : id.StartsWith("clock-guard-") ? clockGuardHandle
                : id == EnemyBattleIds.HellHoundPrimary ? hellHoundHandle : null;
            if (source == null) throw new System.ArgumentException("Missing installed enemy family: " + id);
            sources.Add(source);
        }
        encounterModel = EncounterModel.ClockGuard;
        DisableHellHoundRagePresentation();
        foreach (var old in additionalWaveEnemies) if (old != null) { old.gameObject.SetActive(false); Destroy(old.gameObject); }
        additionalWaveEnemies.Clear();
        foreach (var handle in new[] { clockGuardHandle, secondaryClockGuardHandle, clockCoreHandle, memoryLeechHandle, hellHoundHandle })
            if (handle != null) handle.gameObject.SetActive(false);
        EnemyHandle primaryPresented = null;
        for (var index = 0; index < ids.Length; index++) {
            var source = sources[index];
            // Escort palette/body also belongs to a disposable bounty instance.
            // Reusing the mainline template accumulated body owners on retry.
            bool isolatedBounty=descriptors[index].Contains("@bounty-")||descriptors[index].EndsWith("@ghost");
            var handle = source.BattleEnemyId == ids[index] && !isolatedBounty ? source : source.CloneForBattle(ids[index]);
            if (handle != source) additionalWaveEnemies.Add(handle);
            if (index == 0) primaryPresented = handle;
            if (handle.GetComponent<SignatureEnemyPresentation>()) handle.EnemyRoot.localScale = Vector3.one;
            handle.gameObject.SetActive(true);
            var slot = ids.Length == 1 ? EnemyFormationSlotIds.FrontCenter
                : index == 0 ? EnemyFormationSlotIds.FrontLeft
                : index == 1 ? EnemyFormationSlotIds.FrontRight : ids.Length==4 ? (index==2?EnemyFormationSlotIds.RearLeft:EnemyFormationSlotIds.RearRight) : EnemyFormationSlotIds.RearCenter;
            EnemyPresenter.Reposition(handle, slot, ids[index].StartsWith("clock-core-"));
            // Four large silhouettes: front inside, rear outside so perspective does not stack pairs.
            if(ids.Length==4)handle.EnemyRoot.position=new Vector3(index==0?-1.05f:index==1?1.05f:index==2?-2.65f:2.65f,0,index<2?11.6f:15.5f);
            // Keep the tower formation in the marked upper arena, opposite the
            // hero's lower mark. The attendants flank rather than hide the boss.
            // Absolute scale prevents repeated waves and retries shrinking it.
            var churchDemon = handle.GetComponent<ChurchDemonPresentation20260917>();
            if (handle.GetComponent<StonehidePresentation20260917>() || churchDemon) {
                bool isTowerMinion = churchDemon && ChurchMinionVfx20260921.Handles(churchDemon.species);
                handle.EnemyRoot.localScale = Vector3.one * (churchTowerFormation
                    ? (isTowerMinion ? ChurchTowerMinionScale : ChurchTowerMajorScale) : 1f);
                if (churchTowerFormation) {
                    float x = ids.Length == 1 ? 0f : ids.Length == 3
                        ? (index == 0 ? 0f : index == 1 ? -1.55f : 1.55f)
                        : (index == 0 ? -.75f : index == 1 ? .75f : index == 2 ? -1.75f : 1.75f);
                    bool escort = ids.Length == 3 ? index > 0 : ids.Length == 4 && index > 1;
                    handle.EnemyRoot.position = new Vector3(x, 0f, escort ? 8.9f : 8.1f);
                }
            }
            handle.GetComponent<SignatureEnemyPresentation>()?.CalibrateRestPose();
            if (ids[index].StartsWith("clock-guard-") && !descriptors[index].Contains("@bounty-") && !handle.GetComponent<SignatureEnemyPresentation>() && !handle.GetComponent<StoryEnemyPresentation20260916>() && !handle.GetComponent<ChronarchPresentation20260916>() && !handle.GetComponent<HeavyArchivePresentation20260916>() && !handle.GetComponent<StonehidePresentation20260917>() && !handle.GetComponent<ChurchDemonPresentation20260917>())
                SetFogGhostModel(handle, descriptors[index].EndsWith("@ghost") || descriptors[index].EndsWith("@fog-ghost") || descriptors[index].EndsWith("@crimson-ghost"), descriptors[index].EndsWith("@crimson-ghost") ? index + 2 : index);
            var bountyParts=descriptors[index].Split('@');var bountySkin=bountyParts[bountyParts.Length-1];
            if(bountySkin.StartsWith("bounty-"))handle.gameObject.AddComponent<BountyIdentityPresentation20260917>().Configure(handle,bountySkin.Substring(7));
            else if(bountySkin=="ghost")handle.gameObject.AddComponent<BountyIdentityPresentation20260917>().Configure(handle,"b03-escort");
        }
        RecordEncounterRoster();
        enemy = primaryPresented.EnemyRoot.gameObject;
        enemyAnimator = enemy.GetComponentInChildren<Animator>(true);
        enemyHome = enemy.transform.position;

    }

    EnemyHandle ResolveChapterThirtyTemplate(ref EnemyHandle cache, string identity, string folder)
    {
        if (cache) return cache;
        cache = FindInstalledEnemyHandle(identity + "-template");
        if (cache) return cache;
        var profile = Resources.Load<EnemyVisualProfile>("Enemies/Signature/" + folder + "/VisualProfile");
        if (!profile) throw new InvalidOperationException("Pending chapter model: " + identity + ". No fallback is allowed.");
        cache = EnemyPresenter.Present(new EnemyPresentationRequest {
            Profile = profile, Formation = clockGuardHandle.Formation,
            SlotId = EnemyFormationSlotIds.FrontCenter, BattleEnemyId = identity + "-template",
            Parent = clockGuardHandle.EnemyRoot.parent, EnableMotion = false
        });
        if (ChurchMinionVfx20260921.Handles(identity) || Array.IndexOf(new[]{"saltmaw","shellback","ironclaw","frilled-naga","boneclaw"},identity)>=0) {
            var demon=cache.gameObject.AddComponent<ChurchDemonPresentation20260917>();demon.species=identity;demon.targetWorldHeight=identity=="copperback"?1.65f:identity=="moonfang"?1.5f:identity=="golden-throat"?2.1f:identity=="veil-oracle"?2.5f:identity=="crimson-brute"?2.4f:identity=="shellback"?2.35f:identity=="frilled-naga"?2.8f:2.65f;demon.FitRestPose();
        } else if (identity == "stonehide") {
            var presentation = cache.gameObject.AddComponent<StonehidePresentation20260917>(); presentation.FitRestPose();
        } else if (identity == "chronarch") {
            var presentation = cache.GetComponent<ChronarchPresentation20260916>();
            if (!presentation) presentation = cache.gameObject.AddComponent<ChronarchPresentation20260916>();
            presentation.FitRestPose();
        } else {
            var presentation = cache.GetComponent<HeavyArchivePresentation20260916>();
            if (!presentation) presentation = cache.gameObject.AddComponent<HeavyArchivePresentation20260916>();
            presentation.isConvoy = identity == "convoy"; presentation.FitRestPose();
        }
        cache.gameObject.SetActive(false);
        return cache;
    }

    EnemyHandle ResolveBountyArtTemplate(string caseID)
    {
        if (bountyArtTemplates.TryGetValue(caseID,out var cached)&&cached)return cached;
        string folder=caseID=="b10-vessel"?"BountyB10Vessel":"Bounty"+caseID.ToUpperInvariant();
        var profile=Resources.Load<EnemyVisualProfile>("Enemies/Signature/"+folder+"/VisualProfile");
        if(!profile)throw new InvalidOperationException("Missing independent bounty actor "+caseID);
        var handle=EnemyPresenter.Present(new EnemyPresentationRequest{
            Profile=profile,Formation=clockGuardHandle.Formation,
            SlotId=EnemyFormationSlotIds.FrontCenter,BattleEnemyId="bounty-"+caseID+"-template",
            Parent=clockGuardHandle.EnemyRoot.parent,EnableMotion=false
        });
        handle.gameObject.SetActive(false);
        bountyArtTemplates[caseID]=handle;
        return handle;
    }

    // Explicit art routing for the authored late chapter. Native still owns unlocks and victories.
    public void ConfigureChapterThirtyMission(string value)
    {
        if (!int.TryParse(value, out int mission) || mission < 16 || mission > 30)
            throw new ArgumentException("Late chapter mission must be 16 through 30.");
        bool wasEnabled = NativeCombatEnabled;
        SetNativeCombatEnabled(false);
        string descriptors;
        switch (mission) {
            case 16: descriptors = "hell-hound-primary@early-hell-hound"; break;
            case 17: descriptors = "clock-guard-primary@executor"; break;
            case 18: case 23: descriptors = "clock-guard-primary@adjudicator"; break;
            case 19: descriptors = "hell-hound-primary"; break;
            case 20: case 26: descriptors = "clock-guard-primary@convoy"; break;
            case 21: descriptors = "clock-guard-primary@rescue,clock-core-primary"; break;
            case 22: case 25: descriptors = "clock-guard-primary@matriarch"; break;
            case 24: descriptors = "hell-hound-primary,clock-guard-primary@fog-ghost"; break;
            case 27: descriptors = "clock-guard-primary@archivist,hell-hound-primary"; break;
            case 28: case 30: descriptors = "clock-guard-primary@chronarch"; break;
            default: descriptors = "clock-guard-primary@chronarch,clock-guard-secondary@executor,clock-guard-instance-3"; break;
        }
        ConfigureWaveInstances(descriptors);
        if (mission == 16) hellHoundUsesFireBreath = true;
        if (mission == 19) { SetEncoreRevenant(true); hellHoundUsesFireBreath = true; }
        if (mission == 29) {
            var boss = FindInstalledEnemyHandle("clock-guard-primary");
            var left = FindInstalledEnemyHandle("clock-guard-secondary");
            var right = FindInstalledEnemyHandle("clock-guard-instance-3");
            EnemyPresenter.Reposition(boss, EnemyFormationSlotIds.RearCenter, false);
            EnemyPresenter.Reposition(left, EnemyFormationSlotIds.FrontLeft, false);
            EnemyPresenter.Reposition(right, EnemyFormationSlotIds.FrontRight, false);
            // The leader keeps the central silhouette; escorts screen either side.
            boss.EnemyRoot.localScale = Vector3.one * 1.13f;
            left.EnemyRoot.position += Vector3.back * .18f;
            right.EnemyRoot.position += Vector3.forward * .15f;
            enemyHome = boss.EnemyRoot.position;
        }
        SetEarlyBattlePresence(value);
        if (wasEnabled) SetNativeCombatEnabled(true);
    }

    public void UseLateEscort(bool hound)
    {
        if (hound) {
            UseHellHoundPounceModel();
            clockGuard.SetActive(true);
            SetFogGhostModel(clockGuardHandle, false, 0);
            EnemyPresenter.Reposition(clockGuardHandle, EnemyFormationSlotIds.FrontLeft, false);
            EnemyPresenter.Reposition(hellHoundHandle, EnemyFormationSlotIds.FrontRight, false);
            enemyHome = hellHoundHandle.EnemyRoot.position;
        } else {
            UseP1Escort(false);
            secondaryClockGuardHandle.gameObject.SetActive(false);
            EnemyPresenter.Reposition(clockCoreHandle, EnemyFormationSlotIds.FrontRight, true);
        }
        RecordEncounterRoster();
    }

    public void UseP1Escort(bool leech)
    {
        encounterModel = leech ? EncounterModel.LeechEscort : EncounterModel.CoreEscort;
        ApplyEncounterModelSelection();
    }

    IEnumerator PresentSingleClockGuardTurn(EnemyHandle handle,bool eliteCharged=false)
    {
        if(encounterModel==EncounterModel.DualClockGuard || handle.GetComponentInChildren<FogGhostActor>()) {
            yield return PresentFogGhostCast(handle);
            yield break;
        }
        actionRunning = true;
        yield return PresentClockGuardStrike(handle,eliteCharged);
        if(!CanPresentEnemy(handle)){actionRunning=false;yield break;}
        playerDefending = false;
        actionRunning = false;
        UnityBattleBridge.ReportPresentationComplete("enemy");
    }

    IEnumerator PresentEliteChargedStrike(EnemyHandle handle) {
        var light=handle.GetComponent<SpellSceneLighting>();if(!light)light=handle.gameObject.AddComponent<SpellSceneLighting>();
        var round2=MainlineStateRound2.Attach(handle,"thirteenth_charge",1.1f);
        try {
            for(float t=0;t<1.1f;t+=Time.deltaTime){
                if(!CanPresentEnemy(handle))yield break;
                round2.Sample(t);
                light.Draw(handle.EnemyRoot.position+Vector3.up*1.8f,new Color(1,.55f,.16f),1.2f+t*3,3);
                yield return null;
            }
            light.Clear();
            round2.Dispose();
            if(CanPresentEnemy(handle))yield return PresentSingleClockGuardTurn(handle,true);
        } finally {round2.Dispose();if(light)light.Clear();}
    }

    IEnumerator PresentClockGuardPreparation(EnemyHandle handle, string intent)
    {
        var signature = handle.GetComponent<SignatureEnemyPresentation>();
        var epoch = signature ? signature.Epoch : 0;
        SetStatus(intent == "guard" || intent == "fortify" ? "重甲架势" : "准备校正");
        SetClockGuardWeaponTrail(handle.EnemyRoot, false);
        var animator = handle.EnemyRoot.GetComponentInChildren<Animator>(true);
        animator?.SetBool("Running", false);
        animator?.ResetTrigger("Attack");
        yield return MainlineStateRound2.Play(handle,intent,.65f,()=>CanPresentEnemy(handle));
        if (!CanPresentEnemy(handle) || (signature && signature.Epoch != epoch)) yield break;
        // Use the unqualified instance ID expected by native pending impacts.
        UnityBattleBridge.ReportCombatContact("enemy:" + handle.BattleEnemyId);
        UnityBattleBridge.ReportPresentationComplete("enemy");
    }

    /// The native combat runtime decides defeat. Unity only receives this
    /// presentation cue after the hostile turn has resolved.
    public void PresentPlayerDefeat()
    {
        if (playerDefeatPresentationActive || player == null) return;
        playerDefeatRoutine = StartCoroutine(PresentPlayerDefeatSequence());
    }

    void SetPlayerVisualVisible(bool visible)
    {
        if (player == null)
            return;

        if (!visible)
        {
            ClearPlayerImpact();
            if (playerHiddenByPaper)
                return;

            paperHiddenRendererStates.Clear();
            foreach (var renderer in player.GetComponentsInChildren<Renderer>(true))
            {
                if (renderer == null)
                    continue;
                // The presentation owns the temporary hide. Record a visible
                // state so a renderer that was already disabled by the defeat
                // pass cannot make the protagonist stay invisible after Mara.
                paperHiddenRendererStates[renderer] = true;
                renderer.enabled = false;
            }
            playerHiddenByPaper = true;
            return;
        }

        player.SetActive(true);
        foreach (var renderer in player.GetComponentsInChildren<Renderer>(true))
        {
            if (renderer == null) continue;
            renderer.gameObject.SetActive(true);
            renderer.enabled = true;
        }
        paperHiddenRendererStates.Clear();
        playerHiddenByPaper = false;
    }

    /// A retry can reuse the embedded Unity scene, so restore the hidden
    /// renderers instead of requiring a Unity process restart.
    public void ResetPlayerPresentation()
    {
        if (playerDefeatRoutine != null)
        {
            StopCoroutine(playerDefeatRoutine);
            playerDefeatRoutine = null;
        }
        foolDefenseVFX?.ResetPresentation();
        ClearPlayerDefeatShards();
        if (player == null) return;
        RestorePlayerPresentationState();
    }

    // Paper interception and Mara's rewind both end at the same visual
    // boundary. Re-activate every child node and renderer here so the
    // protagonist can never remain replaced by the temporary paper body.
    public void RestorePlayerPresentation()
    {
        if (playerDefeatRoutine != null)
        {
            StopCoroutine(playerDefeatRoutine);
            playerDefeatRoutine = null;
        }
        foolDefenseVFX?.ResetPresentation();
        ClearPlayerDefeatShards();
        if (player == null) return;
        RestorePlayerPresentationState();
    }

    void ClearPlayerDefeatShards()
    {
        for (var index = 0; index < playerDefeatShardObjects.Count; index++)
        {
            var shard = playerDefeatShardObjects[index];
            if (shard != null)
                Destroy(shard);
        }
        playerDefeatShardObjects.Clear();
    }

    void RestorePlayerPresentationState()
    {
        ClearPlayerImpact();
        playerChoreography?.Clear();
        playerDefeatPresentationActive = false;
        player.SetActive(true);
        SetPlayerVisualVisible(true);
        player.transform.position = playerHome;
        ApplyPlayerEncounterScale();
        foreach (var renderer in player.GetComponentsInChildren<Renderer>(true))
            renderer.enabled = true;
        playerAnimator?.SetBool("Running", false);
        playerAnimator?.Play("Meshy · Idle", 0, 0f);
        playerAnimator?.Update(0f);
    }

    void OnDisable()
    {
        ClearPlayerImpact(true);
        playerChoreography?.Clear();
        CancelSignatureSpells();
        if (playerDefeatRoutine != null)
        {
            StopCoroutine(playerDefeatRoutine);
            playerDefeatRoutine = null;
        }
        ClearPlayerDefeatShards();
        SetPlayerVisualVisible(true);
    }

    /// Adds the unrigged Crimson-Eyed Egg beside the guard for encounter two.
    /// The guard remains the animated attacker while the core supplies its
    /// own ambient transform animation.
    public void UseClockCoreModel()
    {
        encounterModel = EncounterModel.ClockCore;
        ApplyEncounterModelSelection();
    }

    public void UseClockGuardModel()
    {
        hellHoundIsEnraged = false;
        encounterModel = EncounterModel.ClockGuard;
        ApplyEncounterModelSelection();
    }

    public void UseDualClockGuardModel()
    {
        hellHoundIsEnraged = false;
        encounterModel = EncounterModel.DualClockGuard;
        ApplyEncounterModelSelection();
    }

    // Early encounters retain the original Emberwolf; signature imports only
    // supply the later armored hound. Each owns its own model and spell lifetime.
    public void UseEarlyHellHoundModel()
    {
        SelectHellHoundVariant(true);
        hellHoundUsesFireBreath = true;
        hellHoundIsEnraged = false;
        encounterModel = EncounterModel.HellHound;
        ApplyEncounterModelSelection();
    }

    void SelectHellHoundVariant(bool early)
    {
        if (!hellHoundHandle) return;
        if (!armoredHellHoundHandle) armoredHellHoundHandle = hellHoundHandle;
        if (early && !earlyHellHoundHandle)
        {
            var profile = Resources.Load<EnemyVisualProfile>("Enemies/EarlyHellHound/VisualProfile");
            if (!profile) throw new InvalidOperationException("Original early Hell Hound profile missing");
            earlyHellHoundHandle = EnemyPresenter.Present(new EnemyPresentationRequest {
                Profile = profile, Formation = armoredHellHoundHandle.Formation,
                SlotId = EnemyFormationSlotIds.FrontCenter,
                BattleEnemyId = "early-hound-template",
                Parent = armoredHellHoundHandle.EnemyRoot.parent, EnableMotion = false
            });
            earlyHellHoundHandle.gameObject.name = "EarlyHellHound_Original";
            earlyHellHoundHandle.gameObject.SetActive(false);
        }
        var selected = early ? earlyHellHoundHandle : armoredHellHoundHandle;
        if (selected == hellHoundHandle) return;
        SetEncoreRevenant(false);
        DisableHellHoundRagePresentation();
        hellHoundHandle.GetComponent<SignatureEnemyPresentation>()?.Cancel();
        hellHoundHandle.gameObject.SetActive(false);
        hellHoundHandle.SetInactiveBattleIdentity(hellHoundHandle == earlyHellHoundHandle ? "early-hound-template" : "armored-hound-template");
        selected.SetInactiveBattleIdentity(EnemyBattleIds.HellHoundPrimary);
        hellHoundHandle = selected;
        hellHound = selected.EnemyRoot.gameObject;
        hasHellHoundBaseScale = false;
        hellHoundRageLight = null;
        hellHoundRageAura = null;
        Debug.Log("HOUND_VARIANT " + (early ? "early-original-fireball" : "late-armored-signature"));
    }

    public void UseHellHoundModel()
    {
        SelectHellHoundVariant(false);
        hellHoundUsesFireBreath = true;
        hellHoundIsEnraged = true;
        encounterModel = EncounterModel.HellHound;
        ApplyEncounterModelSelection();
    }

    public void UseHellHoundPounceModel()
    {
        SelectHellHoundVariant(false);
        hellHoundUsesFireBreath = true;
        hellHoundIsEnraged = false;
        encounterModel = EncounterModel.HellHound;
        ApplyEncounterModelSelection();
    }

    /// Applies a Debug test-table placement in normalized portrait viewport
    /// coordinates. yFromTop is converted to a ray on the painted ground so
    /// the Unity actor follows the same visible screen position as SpriteKit.
    public void SetPlayerScreenPlacement(string payload)
    {
        if (player == null)
            return;

        if (string.Equals(payload, "default", StringComparison.OrdinalIgnoreCase))
        {
            ResetPlayerScreenPlacement();
            return;
        }

        var values = payload.Split(',');
        if (values.Length != 2
            || !float.TryParse(values[0], NumberStyles.Float, CultureInfo.InvariantCulture, out var x)
            || !float.TryParse(values[1], NumberStyles.Float, CultureInfo.InvariantCulture, out var yFromTop))
            return;

        var camera = Camera.main;
        if (camera == null)
            return;

        x = Mathf.Clamp(x, 0.20f, 0.80f);
        yFromTop = Mathf.Clamp(yFromTop, 0.42f, 0.90f);
        var ray = camera.ViewportPointToRay(new Vector3(x, 1f - yFromTop, 0f));
        var ground = new Plane(Vector3.up, Vector3.zero);
        if (!ground.Raycast(ray, out var distance))
            return;

        var hit = ray.GetPoint(distance);
        playerHome = GroundedAt(player, new Vector3(hit.x, 0f, hit.z));
        player.transform.position = playerHome;
    }

    public void ResetPlayerScreenPlacement()
    {
        if (player == null)
            return;
        playerHome = GroundedAt(player, new Vector3(0f, 0f, churchTowerFormation ? -2.1f : -3.8f));
        player.transform.position = playerHome;
    }

    public void PresentClockCoreCast()
    {
        if ((encounterModel != EncounterModel.ClockCore && encounterModel != EncounterModel.CoreEscort) || !clockCore || clockCoreHandle == null)
            return;
        StartCoroutine(RotateClockCoreCast(clockCoreHandle));
    }

    IEnumerator RotateClockCoreCast(EnemyHandle handle)
    {
        // Rotate only the model. MotionRoot also owns the health/target
        // anchors, so rotating it made HUD anchors orbit with the core.
        var visualRoot = handle.VisualRoot;
        if (visualRoot == null)
            yield break;

        var idle = handle.GetComponent<EarlyEnemyIdlePresence>();
        idle?.SuspendForAction();
        var baseline = visualRoot.localRotation;
        MainlineMemoryTransitRound2 memoryPage=null;
        try {
        const float duration = 0.82f;
        var elapsed = 0f;
        while (elapsed < duration)
        {
            if(!CanPresentEnemy(handle))yield break;
            elapsed += Time.deltaTime;
            var progress = Mathf.Clamp01(elapsed / duration);
            var eased = progress * progress * (3f - 2f * progress);
            if(memoryPage==null&&progress>=.54f&&player)
                memoryPage=MainlineMemoryTransitRound2.Create(handle.EffectAnchor?handle.EffectAnchor:visualRoot,player.transform);
            // A forward somersault reads as a deliberate floating cast while
            // returning to the approved frontal resting pose at completion.
            visualRoot.localRotation = baseline * Quaternion.AngleAxis(-eased * 360f, Vector3.right);
            yield return null;
        }
        } finally {
            if (visualRoot) visualRoot.localRotation = baseline;
            if (idle) idle.ResumeIdle();
            if(!CanPresentEnemy(handle)&&memoryPage)memoryPage.Clear();
        }
        if(!CanPresentEnemy(handle)){if(memoryPage)memoryPage.Clear();yield break;}
        UnityBattleBridge.ReportCombatContact("enemy:" + handle.BattleEnemyId);
        MainlineContactRound2.Play(player.transform,true);
        UnityBattleBridge.ReportPresentationComplete("clock-core-cast");
    }

    readonly HashSet<EnemyHandle> encounterRoster = new HashSet<EnemyHandle>();
    public bool BelongsToCurrentEncounter(EnemyHandle handle) => encounterRoster.Contains(handle);
    void RecordEncounterRoster()
    {
        encounterRoster.Clear();
        if (encounterModel == EncounterModel.DualClockGuard)
            foreach (var child in q2SplitGhosts) if (child) encounterRoster.Add(child);
        foreach(var handle in FindObjectsByType<EnemyHandle>(FindObjectsSortMode.None))
            encounterRoster.Add(handle);
        RefreshEnemyIdlePresence();
    }
    void ApplyEncounterModelSelection()
    {
        archivePresentation?.Clear(); ClearRepairPresentations();
        pendingSidestepSecondary = null; pendingSkillTargets = null;
        ApplyEncounterModelSelectionCore();
        RecordEncounterRoster();
    }
    void ApplyEncounterModelSelectionCore()
    {
        ParkQ2SplitGhosts();
        foreach (var extra in additionalWaveEnemies) if (extra != null) extra.gameObject.SetActive(false);
        if (memoryLeechHandle != null) memoryLeechHandle.gameObject.SetActive(false);
        if (encounterModel == EncounterModel.CoreEscort || encounterModel == EncounterModel.LeechEscort)
        {
            DisableHellHoundRagePresentation();
            if (hellHound) hellHound.SetActive(false);
            clockGuard.SetActive(true);
            SetFogGhostModel(clockGuardHandle, false, 0);
            EnemyPresenter.Reposition(clockGuardHandle, EnemyFormationSlotIds.FrontLeft, false);
            if (secondaryClockGuardHandle == null)
                secondaryClockGuardHandle = EnemyPresenter.Present(new EnemyPresentationRequest {
                    Profile=clockGuardHandle.Profile, Formation=clockGuardHandle.Formation,
                    SlotId=EnemyFormationSlotIds.FrontRight, BattleEnemyId=EnemyBattleIds.ClockGuardSecondary,
                    Parent=clockGuardHandle.EnemyRoot.parent, EnableMotion=false
                });
            bool core = encounterModel == EncounterModel.CoreEscort;
            secondaryClockGuardHandle.gameObject.SetActive(core);
            if (core) {
                SetFogGhostModel(secondaryClockGuardHandle, false, 1);
                EnemyPresenter.Reposition(secondaryClockGuardHandle,EnemyFormationSlotIds.FrontRight,false);
            }
            clockCore.SetActive(core);
            if (core) EnemyPresenter.Reposition(clockCoreHandle,EnemyFormationSlotIds.RearCenter,true);
            if (!core && memoryLeechHandle != null) {
                memoryLeechHandle.gameObject.SetActive(true);
                EnemyPresenter.Reposition(memoryLeechHandle,EnemyFormationSlotIds.RearLeft,false);
                EnemyPresenter.Reposition(clockGuardHandle,EnemyFormationSlotIds.FrontCenter,false);
            }
            enemy=clockGuard; enemyAnimator=enemy.GetComponentInChildren<Animator>(true);
            enemyHome=clockGuardHandle.EnemyRoot.position;
            return;
        }

        if (!clockGuard && !hellHound) return;
        if (usingProfileEnemyPipeline)
        {
            ApplyProfileEncounterModelSelection();
            return;
        }

        ApplyLegacyEncounterModelSelection();
    }

    void ApplyProfileEncounterModelSelection()
    {
        if (encounterModel == EncounterModel.HellHound)
        {
            if (secondaryClockGuardHandle != null)
                secondaryClockGuardHandle.EnemyRoot.gameObject.SetActive(false);
            if (clockCoreHandle?.HoverMotion != null)
                clockCoreHandle.HoverMotion.StopAndReset();
            if (clockCore) clockCore.SetActive(false);
            if (clockGuard) clockGuard.SetActive(false);
            if (!hellHound || hellHoundHandle == null)
            {
                Debug.LogError("Mindstone: Hell Hound is not installed. Run Mindstone > Install 3D Battle Assets.");
                return;
            }

            hellHound.SetActive(true);
            EnemyPresenter.Reposition(hellHoundHandle, EnemyFormationSlotIds.FrontCenter, false);
            ApplyHellHoundRagePresentation();
            // Keep the quadruped readable in the portrait camera without
            // changing its combat reach or restoring the old red rage tint.
            hellHoundHandle.EnemyRoot.localScale = Vector3.one * (hellHoundHandle == earlyHellHoundHandle ? 1f : 1.32f);
            hellHoundHandle.GetComponent<SignatureEnemyPresentation>()?.CalibrateRestPose();
            var fill = hellHoundHandle.EnemyRoot.Find("PortraitFill");
            if (fill == null) {
                var lightObject = new GameObject("PortraitFill");
                lightObject.transform.SetParent(hellHoundHandle.EnemyRoot, false);
                lightObject.transform.localPosition = new Vector3(0, 2.2f, -2f);
                var light = lightObject.AddComponent<Light>();
                light.type = LightType.Point;
                light.color = new Color(.86f, .9f, 1f);
                light.intensity = 2.5f;
                light.range = 5f;
                light.shadows = LightShadows.None;
            }
            enemy = hellHound;
            enemyAnimator = enemy.GetComponentInChildren<Animator>(true);
            enemyHome = hellHoundHandle.EnemyRoot.position;
            playerHome = player ? player.transform.position : playerHome;
            return;
        }

        if (encounterModel == EncounterModel.ClockGuard || encounterModel == EncounterModel.DualClockGuard)
        {
            DisableHellHoundRagePresentation();
            if (clockCoreHandle?.HoverMotion != null)
                clockCoreHandle.HoverMotion.StopAndReset();
            if (clockCore) clockCore.SetActive(false);
            if (hellHound) hellHound.SetActive(false);
            clockGuard.SetActive(true);
            var usesDualFormation = encounterModel == EncounterModel.DualClockGuard;
            SetFogGhostModel(clockGuardHandle, usesDualFormation, 0);
            if (usesDualFormation)
            {
                // The authored primary guard used to occupy the middle/right
                // lane. Move it left and place the secondary on its right so
                // the encounter reads as one stable, side-by-side formation.
                PositionDualClockGuard(
                    clockGuardHandle,
                    EnemyFormationSlotIds.FrontLeft,
                    -DualClockGuardLaneExpansion);
            }
            else
            {
                EnemyPresenter.Reposition(
                    clockGuardHandle,
                    EnemyFormationSlotIds.FrontCenter,
                    false);
            }
            if (usesDualFormation)
            {
                if (secondaryClockGuardHandle == null)
                {
                    secondaryClockGuardHandle = EnemyPresenter.Present(new EnemyPresentationRequest
                    {
                        Profile = clockGuardHandle.Profile,
                        Formation = clockGuardHandle.Formation,
                        SlotId = EnemyFormationSlotIds.FrontRight,
                        BattleEnemyId = EnemyBattleIds.ClockGuardSecondary,
                        Parent = clockGuardHandle.EnemyRoot.parent,
                        EnableMotion = false
                    });
                }
                if (secondaryClockGuardHandle == null)
                {
                    Debug.LogError("Mindstone: failed to present the secondary Clock Guard.");
                    return;
                }
                secondaryClockGuardHandle.EnemyRoot.gameObject.SetActive(true);
                SetFogGhostModel(secondaryClockGuardHandle, true, 1);
                PositionDualClockGuard(
                    secondaryClockGuardHandle,
                    EnemyFormationSlotIds.FrontRight,
                    DualClockGuardLaneExpansion);
            }
            else if (secondaryClockGuardHandle != null)
            {
                secondaryClockGuardHandle.EnemyRoot.gameObject.SetActive(false);
            }
            if (usesDualFormation) PrepareQ2SplitGhosts();
            enemy = clockGuard;
            enemyAnimator = enemy.GetComponentInChildren<Animator>(true);
            enemyHome = clockGuardHandle.EnemyRoot.position;
            return;
        }
        if (secondaryClockGuardHandle != null)
            secondaryClockGuardHandle.EnemyRoot.gameObject.SetActive(false);
        DisableHellHoundRagePresentation();
        if (!clockCore || clockCoreHandle == null) return;

        if (hellHound) hellHound.SetActive(false);
        clockGuard.SetActive(true);
        EnemyPresenter.Reposition(clockGuardHandle, EnemyFormationSlotIds.FrontCenter, false);
        enemy = clockGuard;
        enemyAnimator = clockGuard.GetComponentInChildren<Animator>(true);
        playerHome = player ? player.transform.position : playerHome;
        enemyHome = clockGuardHandle.EnemyRoot.position;

        clockCore.SetActive(false);
        EnemyPresenter.Reposition(clockCoreHandle, EnemyFormationSlotIds.AirRearLeft, true);
        clockCore.SetActive(true);
    }

    void ApplyHellHoundRagePresentation()
    {
        // Rage is conveyed through attacks; do not obscure the model with
        // an untextured red particle cloud or a red point light.
        DisableHellHoundRagePresentation();
    }

    IEnumerator PulseHellHoundRage()
    {
        while (hellHoundIsEnraged && hellHound != null && hellHound.activeInHierarchy)
        {
            var pulse = (Mathf.Sin(Time.time * 3.1f) + 1f) * 0.5f;
            hellHound.transform.localScale = hellHoundBaseScale * Mathf.Lerp(1.10f, 1.14f, pulse);
            if (hellHoundRageLight != null)
                hellHoundRageLight.intensity = Mathf.Lerp(2.8f, 5.4f, pulse);
            yield return null;
        }
    }

    void DisableHellHoundRagePresentation()
    {
        if (hellHoundRagePulse != null)
        {
            StopCoroutine(hellHoundRagePulse);
            hellHoundRagePulse = null;
        }
        if (hasHellHoundBaseScale && hellHound != null)
            hellHound.transform.localScale = hellHoundBaseScale;
        if (hellHoundRageLight != null)
            hellHoundRageLight.gameObject.SetActive(false);
        if (hellHoundRageAura != null)
        {
            hellHoundRageAura.Stop(true, ParticleSystemStopBehavior.StopEmittingAndClear);
            hellHoundRageAura.gameObject.SetActive(false);
        }
    }

    void ParkQ2SplitGhosts()
    {
        for (int i=0;i<q2SplitGhosts.Count;i++) if(q2SplitGhosts[i]) {
            q2SplitGhosts[i].gameObject.SetActive(false);
            q2SplitGhosts[i].SetInactiveBattleIdentity("q2-dormant-ghost-"+i);
        }
    }

    void PrepareQ2SplitGhosts()
    {
        // Four distinct handles are reserved while dormant. Their native life state
        // alone reveals them after each parent's one-second death fade.
        for (int index = 0; index < 4; index++) {
            if (q2SplitGhosts.Count <= index) {
                var child = EnemyPresenter.Present(new EnemyPresentationRequest {
                    Profile = clockGuardHandle.Profile, Formation = clockGuardHandle.Formation,
                    SlotId = EnemyFormationSlotIds.FrontCenter,
                    BattleEnemyId = "clock-guard-instance-" + (index + 3),
                    Parent = clockGuardHandle.EnemyRoot.parent, EnableMotion = false
                });
                if (!child) { Debug.LogError("Unable to create Q2 split ghost"); return; }
                q2SplitGhosts.Add(child);
            }
            var actor = q2SplitGhosts[index];
            actor.gameObject.SetActive(false);
            actor.SetInactiveBattleIdentity("clock-guard-instance-" + (index + 3));
            SetFogGhostModel(actor, true, index + 2);
            EnemyPresenter.Reposition(actor, EnemyFormationSlotIds.FrontCenter, false);
            var center = actor.EnemyRoot.position;
            // Two loose diagonals, with rear ghosts visible between front shoulders.
            float[] lanes = { -1.58f, -.66f, .64f, 1.67f };
            float[] depths = { -.3f, 2.2f, -.65f, 1.85f };
            var splitVisual = actor.EnemyRoot.GetComponentInChildren<FogGhostActor>(true);
            if(splitVisual) splitVisual.transform.localScale = Vector3.one * (index % 2 == 1 ? 1.32f : 1.45f);
            actor.EnemyRoot.position = center + new Vector3(lanes[index], 0, depths[index]);
            actor.gameObject.SetActive(false);
        }
    }

    void SetFogGhostModel(EnemyHandle handle, bool enabled, int variant)
    {
        if(handle==null)return;
        var ghost=handle.EnemyRoot.GetComponentInChildren<FogGhostActor>(true);
        if(enabled && ghost==null) {
            var prefab=Resources.Load<GameObject>("RuntimeModels/FogGhost/Ghost");
            if(!prefab){Debug.LogError("Missing FogGhost prefab");return;}
            ghost=Instantiate(prefab,handle.EnemyRoot,false).GetComponent<FogGhostActor>();
            ghost.transform.localScale=Vector3.one*1.45f;
        }
        if(handle.Model)handle.Model.gameObject.SetActive(!enabled);
        if(ghost) { if(enabled) ghost.Configure(variant); ghost.gameObject.SetActive(enabled); }
        var ward=handle.EnemyRoot.GetComponentInChildren<Mindstone.VFXV1.GuardianWard>(true);
        if(!ward && !enabled)ward=Mindstone.VFXV1.GuardianWard.Attach(handle.EnemyRoot);
        if(ward)ward.gameObject.SetActive(!enabled);
    }

    IEnumerator PresentFogGhostCast(EnemyHandle handle)
    {
        if(handle==null || !handle.EnemyRoot.gameObject.activeInHierarchy)yield break;
        var ghost=handle.EnemyRoot.GetComponentInChildren<FogGhostActor>();
        if(ghost)ghost.Cast();
        // Wave-instance clones keep a stable battle identity but are not the
        // legacy secondary template. Model colour must never choose the spell.
        bool violet=ReferenceEquals(handle,secondaryClockGuardHandle)||handle.BattleEnemyId=="clock-guard-secondary";
        yield return MainlineGhostRound2.Get(handle.gameObject).Play(violet,
            ()=>handle.EnemyRoot.position+Vector3.up*1.8f,
            ()=>EnemyPlayerTarget,
            ()=>UnityBattleBridge.ReportCombatContact("enemy:"+handle.BattleEnemyId),
            ()=>CanPresentEnemy(handle));
        UnityBattleBridge.ReportPresentationComplete("enemy");
    }

    static void PositionDualClockGuard(EnemyHandle handle, string slotId, float laneExpansion)
    {
        if (handle == null || handle.EnemyRoot == null)
            return;

        if (!EnemyPresenter.Reposition(handle, slotId, false))
            return;

        // Expand only the horizontal lane after the profile has grounded and
        // normalized the actor. Health, target and effect anchors are children
        // of EnemyRoot, so they remain attached to the correct guard.
        var position = handle.EnemyRoot.position;
        position.x += laneExpansion;
        handle.EnemyRoot.position = position;
    }

    void ApplyLegacyEncounterModelSelection()
    {
        if (encounterModel == EncounterModel.HellHound)
        {
            Debug.LogWarning("Mindstone: Legacy enemy fallback has no Hell Hound; using Clock Guard.");
            encounterModel = EncounterModel.ClockGuard;
        }

        if (encounterModel == EncounterModel.ClockGuard)
        {
            if (clockCore) clockCore.SetActive(false);
            clockGuard.SetActive(true);
            enemy = clockGuard;
            enemyAnimator = enemy.GetComponentInChildren<Animator>(true);
            enemyHome = LegacyEnemyPresentationFallback.ApplyGuardOnly(enemy);
            return;
        }
        if (!clockCore) return;

        clockGuard.SetActive(true);
        enemy = clockGuard;
        enemyAnimator = clockGuard.GetComponentInChildren<Animator>(true);
        playerHome = player ? player.transform.position : playerHome;
        enemyHome = LegacyEnemyPresentationFallback.ApplyGuardAndCore(clockGuard, clockCore);
    }

    public void SetMasquerade(int charges, bool hit) {
        if (!masquerade) masquerade = gameObject.AddComponent<HeroManualMaskRound2>();
        if (hit) {
            masquerade.Hit(charges);
        } else if (charges > 0 && NativeCombatEnabled) {
            bool wasActive = masquerade.IsActive;
            masquerade.Deploy(player.transform); if (charges == 1) masquerade.SetLifetime(4f);
            if (!wasActive) SpellSpectacle20260926.PlayState(this, "relic-mask", () => masquerade && masquerade.IsActive ? masquerade.Impact : player.transform.position + Vector3.up * .9f, charges);
        }
        else masquerade.Clear();
    }

    EncoreBellPresentation EncoreBell => encoreBellPresentation != null
        ? encoreBellPresentation
        : (encoreBellPresentation = gameObject.AddComponent<EncoreBellPresentation>());

    // Encore beats are presentation-only. They deliberately use the hound's
    // visual child hierarchy and never touch combat timing or actor roots.
    EmeraldRevenantPresentation emeraldRevenant;
    EmeraldRevenantSpell emeraldSpell;
    int emeraldRequestedVariant;
    EmeraldPoisonField emeraldPoisonField;
    public void SetEmeraldSpell(string value) { emeraldRequestedVariant = value == "burst" ? 1 : 0; }
    public void SetEmeraldPoison(int remaining) {
        if (remaining <= 0) { if(emeraldPoisonField) emeraldPoisonField.Clear(); return; }
        if (!NativeCombatEnabled || !player) return;
        if(!emeraldPoisonField) emeraldPoisonField = gameObject.AddComponent<EmeraldPoisonField>();
        // Ambient mist remains on the battlefield; a phantom redirects only the heavy attack.
        emeraldPoisonField.SetIntensity(remaining, () => playerHome + Vector3.up * .85f);
        // Visible toxic uprising on each authoritative poison update; no explosion.
        SpellSpectacle20260926.PlayState(this, "poison-field", () => playerHome + Vector3.up * .85f, remaining);
    }
    bool encoreRevenantRequested;
    public void SetEncoreRevenant(bool enabled)
    {
        encoreRevenantRequested = enabled;
        if (enabled && hellHoundHandle == null) return;
        if (enabled && emeraldRevenant != null && emeraldRevenant.IsInstalled) return;
        Debug.Log("Encore model request " + enabled + " handle=" + (hellHoundHandle != null));
        ClearEncorePresentation();
        emeraldRequestedVariant = 0;
        if (!enabled) { emeraldSpell?.StopRoot(); emeraldRevenant?.Restore(); return; }
        if (emeraldRevenant == null) emeraldRevenant = gameObject.AddComponent<EmeraldRevenantPresentation>();
        emeraldRevenant.Install(hellHoundHandle);
        if (emeraldSpell == null) emeraldSpell = gameObject.AddComponent<EmeraldRevenantSpell>();
    }
    public void PresentEncoreCharge() { EncoreBell.Charge(hellHoundHandle); emeraldRevenant?.Charge(); }
    public void PresentEncoreBell() { EncoreBell.Bell(hellHoundHandle); }
    public void PresentEncoreRelease() { encoreBellPresentation?.Release(); emeraldRevenant?.Release(); }
    public void ClearEncorePresentation() { emeraldPoisonField?.Clear(); encoreBellPresentation?.Clear(); emeraldRevenant?.Release(); emeraldSpell?.StopRoot(); }

    int earlyPresenceMission;
    public void SetEarlyBattlePresence(string value)
    {
        int.TryParse(value, out earlyPresenceMission);
        RefreshEnemyIdlePresence();
    }

    void RefreshEnemyIdlePresence()
    {
        foreach (var handle in FindObjectsByType<EnemyHandle>(FindObjectsInactive.Include, FindObjectsSortMode.None))
        {
            var idle = handle.GetComponent<EarlyEnemyIdlePresence>();
            if (encounterRoster.Contains(handle))
            {
                if (idle == null || !idle.IsConfigured) idle = EarlyEnemyIdlePresence.Install(handle);
                idle.SetMission(earlyPresenceMission);
                CharacterSurfaceRefinement20260916.Install(handle);
                idle.ResumeIdle();
                idle.SetSpeaking(!NativeCombatEnabled && (earlyPresenceMission == 1 || earlyPresenceMission == 5));
            }
            else if (idle) idle.Clear();
        }
    }

    public bool NativeCombatEnabled { get; private set; }
    public void SetNativeCombatEnabled(bool enabled)
    {
        ClearPlayerImpact(true);
        NativeCombatEnabled = enabled;
        if (!enabled) {
            SpellAudioDirector20260924.StopAll();
            SpellSpectacle20260926.StopAll();
            archivePresentation?.Clear(); ClearRepairPresentations();
            foreach(var fx in FindObjectsByType<EarlyContactPolish20260921>(FindObjectsSortMode.None)) Destroy(fx.gameObject);
            foreach(var fx in FindObjectsByType<MainlineContactRound2>(FindObjectsSortMode.None)) Destroy(fx.gameObject);
            foreach(var body in FindObjectsByType<MainlineBodyRound2>(FindObjectsSortMode.None)) body.Stop();
            foreach(var ghost in FindObjectsByType<MainlineGhostRound2>(FindObjectsSortMode.None)) ghost.Cancel();
            MainlineStateRound2.ClearAll();
            foreach(var light in FindObjectsByType<SpellSceneLighting>(FindObjectsSortMode.None)) light.Clear();
            playerChoreography?.Clear();
            foreach (var impact in FindObjectsByType<EnemyImpactFeedback>(FindObjectsInactive.Include, FindObjectsSortMode.None)) impact.Clear();
            pendingSidestepSecondary = null; pendingSkillTargets = null;
        }
        foreach(var idle in FindObjectsByType<EarlyEnemyIdlePresence>(FindObjectsSortMode.None))
            { idle.ResumeIdle(); idle.SetSpeaking(!enabled && (earlyPresenceMission == 1 || earlyPresenceMission == 5)); }
        if (!enabled) { ClearEncorePresentation(); q4Hound?.Clear(); hellHoundFireball?.Clear(); }
        if (enabled) return;
        StopAllCoroutines();
        CancelSignatureSpells();
        spellV1Bridge?.Stop();
        foolSkillVFX?.StopActiveEffects();
        foolBasicTarotVFX?.Clear();
        heroDust?.Clear();
        heroDustRoutine = null;
        if (masquerade) masquerade.Clear();
        // Leaving a fight can interrupt the paper sequence before its normal
        // cleanup. Restore the real actor before the next encounter is shown.
        playerDefeatRoutine = null;
        foolDefenseVFX?.ResetPresentation();
        ClearPlayerDefeatShards();
        if (player) RestorePlayerPresentationState();
        actionRunning = false;
        playerAnimator?.ResetTrigger("Attack");
        enemyAnimator?.ResetTrigger("Attack");
        playerAnimator?.Play("Meshy · Idle", 0, 0f);
        enemyAnimator?.Play("Meshy · Idle", 0, 0f);
        if (player) player.transform.position = playerHome;
        if (enemy) enemy.transform.position = enemyHome;
    }

    void StartPresentation(PlayerAction action)
    {
        if (!NativeCombatEnabled || enemy == null || player == null) return;
        StartCoroutine(PresentPlayerAction(action));
    }

    IEnumerator PresentPlayerAction(PlayerAction action, string targetID = null)
    {
        actionRunning = true;
        playerDefending = action == PlayerAction.Defend;
        switch (action)
        {
            case PlayerAction.Basic:
                var basicHandle=ResolvePlayerSkillTarget(targetID);
                var basicTarget=basicHandle!=null?basicHandle.EnemyRoot:(enemy?enemy.transform:null);
                if(!basicTarget){actionRunning=false;yield break;}
                SetStatus("愚者 · 秘仪飞牌");
                SpellAudioDirector20260924.BeginPlayer(this, "basic");
                BeginPlayerSpectacle("basic", basicHandle != null ? new List<EnemyHandle> { basicHandle } : null, basicTarget);
                PrepareCompactPlayerBasic();
                foolBasicTarotVFX.Play(Camera.main, player.transform, basicTarget);
                basicTarget.GetComponentInChildren<Mindstone.VFXV1.GuardianWard>()?.ImpactAfter(.58f);
                yield return new WaitForSeconds(0.58f);
                break;
            case PlayerAction.Skill:
                SetStatus("愚者 · 错步穿行");
                SpellAudioDirector20260924.BeginPlayer(this, "fool_skill_01");
                PlayEmbeddedPlayerCast();
                yield return new WaitForSeconds(0.72f);
                break;
            case PlayerAction.Defend:
                SetStatus("愚者 · 防御");
                SpellAudioDirector20260924.BeginPlayer(this, "defend");
                yield return foolDefenseVFX.Play(
                    () => player.transform.position + Vector3.up * 1.05f
                );
                break;
        }
        actionRunning = false;
    }

    void PrepareCompactPlayerBasic()
    {
        if (!player || !playerAnimator) return;
        playerChoreography = FoolSkillChoreography.Install(player.transform);
        playerChoreography.Clear();
        player.transform.position = playerHome;
        player.transform.rotation = Quaternion.Euler(0f, PlayerBattleFacingDegrees, 0f);
        playerAnimator.SetBool("Running", false);
        playerAnimator.ResetTrigger("Attack");
        // Basic is only a wrist cast over idle, not the long full-body FBX take.
        // FoolBasicTarotVFX owns Begin and the unchanged .58 s contact callback.
        playerAnimator.CrossFadeInFixedTime("Meshy · Idle", .045f, 0);
    }

    void PlayEmbeddedPlayerCast()
    {
        playerChoreography?.Clear();
        if (playerAnimator == null || player == null)
            return;

        // Play the FBX take directly. No translation or synthetic run-up is
        // added by gameplay code; applyRootMotion remains disabled so the
        // protagonist never leaves the player formation slot.
        player.transform.position = playerHome;
        player.transform.rotation = Quaternion.Euler(0f, PlayerBattleFacingDegrees, 0f);
        playerAnimator.SetBool("Running", false);
        playerAnimator.ResetTrigger("Attack");
        if (playerAnimator.HasState(0, PlayerAttackState))
            playerAnimator.CrossFadeInFixedTime(PlayerAttackState, 0.04f, 0, 0f);
        else
            playerAnimator.SetTrigger("Attack");
    }

    void BeginDistinctPlayerCast(string skillID)
    {
        if (!player || !playerAnimator) return;
        // Every official skill uses its own authored pose, including the quick wrist cast.
        playerChoreography = FoolSkillChoreography.Install(player.transform);
        playerChoreography.Clear();
        player.transform.position = playerHome;
        player.transform.rotation = Quaternion.Euler(0f, PlayerBattleFacingDegrees, 0f);
        playerAnimator.SetBool("Running", false);
        playerAnimator.ResetTrigger("Attack");
        playerAnimator.CrossFadeInFixedTime("Meshy · Idle", .10f, 0);
        playerChoreography.Begin(skillID);
    }

    // Registers the contact spectacle for the hero cast. Each recipient keeps
    // its own last-known point so a target that exits before contact never
    // redirects the burst onto another enemy or the hero.
    void BeginPlayerSpectacle(string skillID, List<EnemyHandle> handles, Transform legacyTarget)
    {
        var points = new List<System.Func<Vector3>>();
        var seeds = new List<int>();
        if (handles != null)
            foreach (var handle in handles)
            {
                if (!IsActiveEnemyHandle(handle)) continue;
                var h = handle; var last = PlayerSkillTargetPoint(h);
                points.Add(() => { if (IsActiveEnemyHandle(h)) last = PlayerSkillTargetPoint(h); return last; });
                seeds.Add(SpellSpectacle20260926.StableHash(h.BattleEnemyId));
            }
        if (points.Count == 0 && legacyTarget)
        {
            var t = legacyTarget; var last = t.position + Vector3.up * 1.05f;
            points.Add(() => { if (t) last = t.position + Vector3.up * 1.05f; return last; });
            seeds.Add(SpellSpectacle20260926.StableHash(t.name));
        }
        SpellSpectacle20260926.BeginPlayer(this, skillID, () => player ? player.transform.position + Vector3.up * 1.15f : Vector3.zero, points, seeds);
    }

    static bool IsActiveEnemyHandle(EnemyHandle handle) =>
        handle != null
            && handle.EnemyRoot != null
            && handle.EnemyRoot.gameObject.activeInHierarchy;

    UnityBattleBridge enemyLifeBridge;
    bool CanPresentEnemy(EnemyHandle handle)
    {
        if(!NativeCombatEnabled||!IsActiveEnemyHandle(handle)||!BelongsToCurrentEncounter(handle))return false;
        if(!enemyLifeBridge)enemyLifeBridge=FindFirstObjectByType<UnityBattleBridge>();
        return !(enemyLifeBridge&&enemyLifeBridge.IsEnemyExiting(handle))
            && !(handle.GetComponent<EnemySubduedPresentation>()?.IsSubdued??false);
    }

    public void CancelDepartingEnemy(EnemyHandle handle)
    {
        if(!handle)return;
        handle.GetComponent<MainlineBodyRound2>()?.Stop();
        handle.GetComponent<MainlineGhostRound2>()?.Cancel();
        if(handle==hellHoundHandle){hellHoundFireball?.Clear();q4Hound?.Clear();}
    }

    EnemyHandle ResolvePlayerSkillTarget(string battleEnemyID)
    {
        if (!string.IsNullOrEmpty(battleEnemyID))
        {
            var exact = FindInstalledEnemyHandle(battleEnemyID);
            if (IsActiveEnemyHandle(exact)) return exact;
            if (battleEnemyID == "memory-leech-primary" && IsActiveEnemyHandle(memoryLeechHandle)) return memoryLeechHandle;
            if (battleEnemyID == EnemyBattleIds.ClockGuardPrimary
                && IsActiveEnemyHandle(clockGuardHandle))
                return clockGuardHandle;
            if (battleEnemyID == EnemyBattleIds.ClockGuardSecondary
                && IsActiveEnemyHandle(secondaryClockGuardHandle))
                return secondaryClockGuardHandle;
            if (battleEnemyID == EnemyBattleIds.ClockCorePrimary
                && IsActiveEnemyHandle(clockCoreHandle))
                return clockCoreHandle;
            if (battleEnemyID == EnemyBattleIds.HellHoundPrimary
                && IsActiveEnemyHandle(hellHoundHandle))
                return hellHoundHandle;
        }

        if (!string.IsNullOrEmpty(battleEnemyID)) return null;

        // Legacy calls without a target ID select a visible enemy.
        // A target can disappear between the native resolution and Unity's
        // presentation command. Retarget only to another visible enemy; the
        // protagonist is deliberately never a valid spell impact fallback.
        var candidates = new[] {
            memoryLeechHandle,
            clockCoreHandle,
            secondaryClockGuardHandle,
            clockGuardHandle,
            hellHoundHandle
        };
        for (var index = 0; index < candidates.Length; index++)
        {
            if (IsActiveEnemyHandle(candidates[index]))
                return candidates[index];
        }
        foreach (var extra in additionalWaveEnemies)
            if (IsActiveEnemyHandle(extra)) return extra;
        return null;
    }

    Vector3 PlayerSkillTargetPoint(EnemyHandle target)
    {
        if (target != null)
        {
            if (target.EffectAnchor != null)
                return target.EffectAnchor.position;
            if (target.EnemyRoot != null)
                return target.EnemyRoot.position + Vector3.up * 1.05f;
        }

        // Legacy scenes do not have EnemyHandle metadata. Keep their fallback
        // on the current enemy actor rather than ever using the player model.
        return enemy != null
            ? enemy.transform.position + Vector3.up * 1.05f
            : Vector3.zero;
    }

    IEnumerator PresentPlayerSkillAction(string skillID, string targetBattleEnemyID, string secondaryID = null, string[] resolvedTargetIDs = null)
    {
        var requestedSkillID = skillID;
        actionRunning = true;
        playerDefending = false;
        var displayName = SpellRegistry.TryGet(skillID, out var v1Spec)
            ? v1Spec.displayName
            : FoolEffekseerSkillVFX.DisplayName(skillID);
        SetStatus($"愚者 · {displayName}");
        SpellAudioDirector20260924.BeginPlayer(this, skillID);
        var targetHandle = ResolvePlayerSkillTarget(targetBattleEnemyID);
        var secondaryHandle = !string.IsNullOrEmpty(secondaryID) ? FindInstalledEnemyHandle(secondaryID) : null;
        if (!IsActiveEnemyHandle(secondaryHandle) || secondaryHandle == targetHandle) secondaryHandle = null;
        {
            var spectacleTargets = new List<EnemyHandle>();
            if (IsActiveEnemyHandle(targetHandle)) spectacleTargets.Add(targetHandle);
            if (IsActiveEnemyHandle(secondaryHandle)) spectacleTargets.Add(secondaryHandle);
            BeginPlayerSpectacle(skillID, spectacleTargets, null);
        }
        var targetAnimator = targetHandle != null && targetHandle.EnemyRoot != null
            ? targetHandle.EnemyRoot.GetComponentInChildren<Animator>(true)
            : enemyAnimator;
        System.Func<Vector3> targetPoint = () => PlayerSkillTargetPoint(targetHandle);
        if (skillID is "fool_skill_01" or "fool_skill_10")
        {
            var recipients = new List<EnemyHandle>();
            void AddRecipient(EnemyHandle handle) {
                if (IsActiveEnemyHandle(handle) && encounterRoster.Contains(handle) && !recipients.Contains(handle)) recipients.Add(handle);
            }
            if (resolvedTargetIDs != null) {
                foreach (var id in resolvedTargetIDs) AddRecipient(FindInstalledEnemyHandle(id));
            } else if (skillID == "fool_skill_10") {
                foreach (var handle in encounterRoster) AddRecipient(handle);
            } else {
                AddRecipient(targetHandle); AddRecipient(secondaryHandle);
            }
            if (skillID == "fool_skill_01" && recipients.Count > 2) recipients.RemoveRange(2, recipients.Count - 2);
            BeginPlayerSpectacle(skillID, recipients, null);
            BeginDistinctPlayerCast(skillID);
            foolSkillVFX.HeroActor = player.transform;
            yield return foolSkillVFX.PlayTargetInstances(skillID,
                () => player.transform.position + Vector3.up * 1.15f, recipients,
                () => { playerChoreography?.Contact(); UnityBattleBridge.ReportCombatContact("player"); });
            playerChoreography?.Finish(); actionRunning = false;
            UnityBattleBridge.ReportPresentationComplete(requestedSkillID);
            yield break;
        }
        if (skillID == "fool_skill_03")
        {
            // Paper Double is now a relic handoff from Mara, not an equipped
            // skill. Keep the legacy card presentation harmless if an old
            // save still references it, but never leave a paper person in the
            // battlefield after the card animation finishes.
            yield return foolSkillVFX.Play(
                skillID,
                () => player.transform.position + Vector3.up * 1.15f,
                targetPoint
            );
            playerChoreography?.Finish();
            actionRunning = false;
            UnityBattleBridge.ReportPresentationComplete(requestedSkillID);
            yield break;
        }
        if (skillID != "fool_skill_01" && spellV1Bridge != null && spellV1Bridge.CanPlay(skillID))
        {
            BeginDistinctPlayerCast(skillID);
            if (requestedSkillID == "fool_skill_01" && targetHandle?.EnemyRoot != null)
                StartCoroutine(ShakeArcanaImpact(targetHandle.EnemyRoot));
            yield return spellV1Bridge.Play(
                skillID,
                () => player.transform.position + Vector3.up * 1.15f,
                targetPoint,
                weapon: () => player.transform.position + Vector3.up * 1.15f,
                impact: targetPoint,
                ground: targetPoint,
                onContact: () => { playerChoreography?.Contact(); UnityBattleBridge.ReportCombatContact("player"); },
                // ArcanaSeal's explosion begins at 43% of its 1.44s sample.
                contactTime: requestedSkillID == "fool_skill_01" ? .6192f : (float?)null);
            playerChoreography?.Finish();
            actionRunning = false;
            UnityBattleBridge.ReportPresentationComplete(requestedSkillID);
            yield break;
        }
        BeginDistinctPlayerCast(skillID);
        if (heroDustRoutine != null) StopCoroutine(heroDustRoutine);
        heroDust?.Clear();heroDustRoutine=null;
        if (requestedSkillID == "fool_skill_10") {
            if (!heroDust) heroDust = gameObject.AddComponent<ArcaneDustFlow>();
            heroDustRoutine = StartCoroutine(PresentHeroDust(requestedSkillID, targetPoint));
        }
        foolSkillVFX.HeroActor = player.transform;
        var distinctSkill = requestedSkillID is "fool_skill_01" or "fool_skill_02" or "fool_skill_04" or "fool_skill_05" or "fool_skill_06" or "fool_skill_07" or "fool_skill_08" or "fool_skill_09" or "fool_skill_10";
        yield return foolSkillVFX.Play(
            skillID,
            () => player.transform.position + Vector3.up * 1.15f,
            targetPoint,
            onContact: distinctSkill ? () => {
                playerChoreography?.Contact();
                UnityBattleBridge.ReportCombatContact("player");
            } : null,
            secondary: secondaryHandle != null ? () => PlayerSkillTargetPoint(secondaryHandle) : (System.Func<Vector3>)null
        );
        if (!distinctSkill)
            UnityBattleBridge.ReportCombatContact("player");
        playerChoreography?.Finish();
        actionRunning = false;
        UnityBattleBridge.ReportPresentationComplete(requestedSkillID);
    }

    IEnumerator PresentHeroDust(string skill, System.Func<Vector3> target)
    {
        int number=int.TryParse(skill.Substring(skill.Length-2),out var parsed)?parsed:1;
        float contact=number==1?.6192f:number==2?.38f:number==4?.441f:number==5?.55f:number==7?.885f:number==8?.63f:number==10?.96f:.705f;
        float end=number==1?1.7617655f:number==2?1.45f:number==4?1.25f:number==10?1.7f:1.3f;
        Color gold=number==6||number==9?new Color(.5f,.92f,.82f):new Color(1f,.69f,.30f);
        Color deep=number==6||number==9?new Color(.025f,.09f,.105f):new Color(.12f,.025f,.055f);
        float age=0;
        while(age<end && NativeCombatEnabled && player) {
            Vector3 source=player.transform.position+Vector3.up*1.15f;
            Vector3 destination=number==2||number==9?source+Vector3.up*.4f:target();
            heroDust.Draw(source,destination,age,contact,end,gold,deep,number);
            yield return null;age+=Time.deltaTime;
        }
        heroDust.Clear();heroDustRoutine=null;
    }

    IEnumerator ShakeArcanaImpact(Transform actor)
    {
        yield return new WaitForSeconds(.62f);
        if (!actor || !NativeCombatEnabled) yield break;
        var home = actor.localPosition;
        var rotation = actor.localRotation;
        var animator = actor.GetComponentInChildren<Animator>(true);
        animator?.SetTrigger("Hit");
        try {
            for(float t=0;t<.78f;t+=Time.deltaTime) {
                if(!actor || !NativeCombatEnabled) yield break;
                float decay=Mathf.Pow(1-t/.78f,1.5f);
                actor.localPosition=home+new Vector3(Mathf.Sin(t*67)*.32f, Mathf.Abs(Mathf.Sin(t*43))*.06f,0)*decay;
                actor.localRotation=rotation*Quaternion.Euler(Mathf.Sin(t*38)*7*decay,0,Mathf.Sin(t*56)*13*decay);
                yield return null;
            }
        } finally {
            if(actor) { actor.localPosition=home; actor.localRotation=rotation; }
        }
    }

    IEnumerator PresentEnemyTurn()
    {
        actionRunning = true;
        if (encounterModel == EncounterModel.DualClockGuard)
        {
            StartCoroutine(PresentFogGhostCast(clockGuardHandle));
            yield return new WaitForSeconds(.35f);
            yield return PresentFogGhostCast(secondaryClockGuardHandle);
        }
        else
        {
            yield return PresentClockGuardStrike(clockGuardHandle);
        }
        playerDefending = false;
        actionRunning = false;
        UnityBattleBridge.ReportPresentationComplete("enemy");
    }

    IEnumerator PresentClockGuardStrike(EnemyHandle handle,bool eliteCharged=false)
    {
        if (!CanPresentEnemy(handle))
            yield break;

        var chronarch = handle.GetComponent<ChronarchPresentation20260916>();
        if (chronarch) {
            yield return chronarch.Strike(handle, player.transform,
                () => { UnityBattleBridge.ReportCombatContact("enemy:" + handle.BattleEnemyId); foolDefenseVFX?.Consume(); },
                () => NativeCombatEnabled && IsActiveEnemyHandle(handle) && !(handle.GetComponent<EnemySubduedPresentation>()?.IsSubdued ?? false));
            yield break;
        }
        var stonehide = handle.GetComponent<StonehidePresentation20260917>();
        if (stonehide) {
            yield return stonehide.Strike(handle, player.transform,
                () => { UnityBattleBridge.ReportCombatContact("enemy:" + handle.BattleEnemyId); foolDefenseVFX?.Consume(); },
                () => NativeCombatEnabled && IsActiveEnemyHandle(handle));
            yield break;
        }
        var heavy = handle.GetComponent<HeavyArchivePresentation20260916>();
        if (heavy) {
            yield return heavy.Strike(handle, player.transform,
                () => { UnityBattleBridge.ReportCombatContact("enemy:" + handle.BattleEnemyId); foolDefenseVFX?.Consume(); },
                () => NativeCombatEnabled && IsActiveEnemyHandle(handle) && !(handle.GetComponent<EnemySubduedPresentation>()?.IsSubdued ?? false));
            yield break;
        }
        var story=handle.GetComponent<StoryEnemyPresentation20260916>();
        if(story) {
            yield return story.Strike(handle,player.transform,()=>{ UnityBattleBridge.ReportCombatContact("enemy:"+handle.BattleEnemyId); foolDefenseVFX?.Consume(); },()=>NativeCombatEnabled&&IsActiveEnemyHandle(handle));
            yield break;
        }
        var actor = handle.EnemyRoot;
        var partner = ReferenceEquals(handle, clockGuardHandle)
            ? secondaryClockGuardHandle
            : clockGuardHandle;
        var partnerWasVisible = partner != null
            && partner.EnemyRoot != null
            && partner.EnemyRoot.gameObject.activeSelf;
        var animator = actor.GetComponentInChildren<Animator>(true);
        var home = actor.position;

        SetStatus("空壳守卫 · 赤弧斩");
        // Clock Guard combat is a continuous formation loop: the actor never
        // leaves its slot or runs toward the protagonist.
        actor.position = home;
        animator?.SetBool("Running", false);
        if (partnerWasVisible && partner.EnemyRoot != null)
            partner.EnemyRoot.gameObject.SetActive(true);
        SetClockGuardWeaponTrail(actor, false);
        var round2Body=MainlineBodyRound2.Get(handle.gameObject);
        if (animator == null || !animator.HasState(0, ClockGuardAttackState))
        {
            round2Body.Begin(MainlineBodyRound2.Pose.Guard,false,.22f,.58f,.72f);
            animator?.SetTrigger("Attack");
            for(float t=0;t<.58f;t+=Time.deltaTime){if(!CanPresentEnemy(handle)){round2Body.Stop();yield break;}round2Body.Sample(t);yield return null;}
            if(!CanPresentEnemy(handle)){round2Body.Stop();yield break;}
            MainlineContactRound2.Play(player.transform,false,eliteCharged);
                    UnityBattleBridge.ReportCombatContact("enemy:" + handle.BattleEnemyId);
            foolDefenseVFX?.Consume();
            round2Body.Stop();
        }
        else
        {
            var previousSpeed = animator.speed;
            var elapsed = 0f;
            var trailStarted = false;
            var trailActive = false;
            var impactPresented = false;
            animator.ResetTrigger("Attack");
            animator.speed = 1f;
            animator.CrossFadeInFixedTime(ClockGuardAttackState, 0.04f, 0, 0f);
            round2Body.Begin(MainlineBodyRound2.Pose.Guard,false,ClockGuardStrikeDuration*ClockGuardTrailStartProgress,ClockGuardStrikeDuration*ClockGuardImpactProgress,ClockGuardStrikeDuration);

            while (elapsed < ClockGuardStrikeDuration)
            {
                elapsed += Time.deltaTime;
                if(!CanPresentEnemy(handle)){round2Body.Stop();SetClockGuardWeaponTrail(actor,false);animator.speed=previousSpeed;yield break;}
                round2Body.Sample(elapsed);
                var progress = Mathf.Clamp01(elapsed / ClockGuardStrikeDuration);
                actor.position = home;

                if (!trailStarted && progress >= ClockGuardTrailStartProgress)
                {
                    trailStarted = true;
                    trailActive = true;
                    SetClockGuardWeaponTrail(actor, true);
                }
                if (!impactPresented && progress >= ClockGuardImpactProgress)
                {
                    impactPresented = true;
                    MainlineContactRound2.Play(player.transform,false,eliteCharged);
                    UnityBattleBridge.ReportCombatContact("enemy:" + handle.BattleEnemyId);
                    foolDefenseVFX?.Consume();
                }
                if (trailActive && progress >= ClockGuardTrailEndProgress)
                {
                    trailActive = false;
                    SetClockGuardWeaponTrail(actor, false);
                }
                yield return null;
            }

            if (!impactPresented) {
                MainlineContactRound2.Play(player.transform,false,eliteCharged);
                    UnityBattleBridge.ReportCombatContact("enemy:" + handle.BattleEnemyId);
                foolDefenseVFX?.Consume();
            }
            SetClockGuardWeaponTrail(actor, false);
            round2Body.Stop();
            animator.speed = previousSpeed;
            animator.Play("Meshy · Idle", 0, 0f);
            animator.Update(0f);
            actor.position = home;
            yield return new WaitForSeconds(0.10f);
        }
        // A guard's presentation must never own the lifetime of its partner.
        // Reassert the partner after the complete strike as well, because an
        // animation event can toggle render roots late in the attack clip.
        if (partnerWasVisible && partner.EnemyRoot != null)
            partner.EnemyRoot.gameObject.SetActive(true);
    }

    void CancelSignatureSpells()
    {
        foreach (var presentation in FindObjectsByType<ChronarchPresentation20260916>(FindObjectsInactive.Include, FindObjectsSortMode.None)) presentation.Cancel();
        foreach (var presentation in FindObjectsByType<TowerHoundPresentation20260917>(FindObjectsInactive.Include, FindObjectsSortMode.None)) presentation.Cancel();
        foreach (var presentation in FindObjectsByType<BountyIdentityPresentation20260917>(FindObjectsInactive.Include, FindObjectsSortMode.None)) presentation.Cancel();
        foreach (var presentation in FindObjectsByType<ChurchDemonPresentation20260917>(FindObjectsInactive.Include, FindObjectsSortMode.None)) presentation.Cancel();
        foreach (var presentation in FindObjectsByType<StonehidePresentation20260917>(FindObjectsInactive.Include, FindObjectsSortMode.None)) presentation.Cancel();
        foreach (var presentation in FindObjectsByType<HeavyArchivePresentation20260916>(FindObjectsInactive.Include, FindObjectsSortMode.None)) presentation.Cancel();
        foreach (var presentation in FindObjectsByType<StoryEnemyPresentation20260916>(FindObjectsInactive.Include, FindObjectsSortMode.None)) presentation.Cancel();
        foreach (var presentation in FindObjectsByType<SignatureEnemyPresentation>(FindObjectsInactive.Include, FindObjectsSortMode.None))
            presentation.Cancel();
    }

    public IEnumerator PreviewSignatureSpell(string kind, int variant)
    {
        if(kind == "Emerald") {
            ConfigureWaveInstances(EnemyBattleIds.HellHoundPrimary);
            SetEncoreRevenant(true); emeraldRequestedVariant = variant;
            SetNativeCombatEnabled(true);
            yield return PresentHellHoundFireBreathTurn();
            yield break;
        }
        SetEncoreRevenant(false);
        ConfigureWaveInstances(kind == "Hound" ? EnemyBattleIds.HellHoundPrimary
            : "clock-guard-primary@" + (kind == "Archivist" ? "archivist" : "matriarch"));
        SetNativeCombatEnabled(true);
        var handle = FindInstalledEnemyHandle(kind == "Hound" ? EnemyBattleIds.HellHoundPrimary : EnemyBattleIds.ClockGuardPrimary);
        yield return PresentSignatureEnemyTurn(handle, variant);
    }

    IEnumerator PresentSignatureEnemyTurn(EnemyHandle handle, int forcedVariant = -1)
    {
        var signature = handle ? handle.GetComponent<SignatureEnemyPresentation>() : null;
        if (!signature || !handle.gameObject.activeInHierarchy || !player) yield break;
        var title = signature.kind == EnemySignatureSpellVFX.Kind.Hound ? "失名猎犬"
            : signature.kind == EnemySignatureSpellVFX.Kind.Archivist ? "档案守卫" : "织幕女主";
        SetStatus(title + " · 蓄力");
        UnityBattleBridge.ReportPresentationPhase("signature-charge");
        bool intercepted = false;
        bool completed = false;
        yield return signature.Cast(() => PlayerFireBreathImpactAnchor,
            () => UnityBattleBridge.ReportPresentationPhase("signature-release"),
            () => {
                if (!CanPresentEnemy(handle)) return;
                UnityBattleBridge.ReportPresentationPhase("signature-impact");
                intercepted = !(masquerade && masquerade.IsActive) && (foolDefenseVFX.IsDeployed || foolDefenseVFX.IsArmed);
                if (intercepted) {
                    if (foolDefenseVFX.IsArmed) foolDefenseVFX.Deploy(GetPaperDoubleAnchor);
                    SetPlayerVisualVisible(false); foolDefenseVFX.Consume();
                }
                UnityBattleBridge.ReportCombatContact("enemy:" + handle.BattleEnemyId);
                Debug.Log($"SIGNATURE_CONTACT kind={signature.kind} variant={signature.LastVariant} id={handle.BattleEnemyId}");
            }, forcedVariant, () => completed = true);
        if (!completed || !CanPresentEnemy(handle)) yield break;
        if (intercepted) { yield return foolDefenseVFX.WaitForCompletion(); RestorePlayerPresentation(); }
        UnityBattleBridge.ReportPresentationPhase("signature-clear");
        UnityBattleBridge.ReportPresentationComplete("enemy");
    }

    IEnumerator PresentHellHoundFireBreathTurn()
    {
        if (hellHoundHandle && hellHoundHandle.GetComponent<SignatureEnemyPresentation>()
            && !(emeraldRevenant && emeraldRevenant.IsInstalled)) {
            yield return PresentSignatureEnemyTurn(hellHoundHandle); yield break;
        }
        var committedHound=hellHoundHandle;
        var actor = committedHound != null ? committedHound.EnemyRoot : null;
        if (actor == null || !actor.gameObject.activeInHierarchy || player == null) yield break;
        var home = actor.position;
        var animator = actor.GetComponentInChildren<Animator>(true);
        actionRunning = true;
        var isRevenant = emeraldRevenant != null && emeraldRevenant.IsInstalled;
        if(isRevenant) emeraldSpell.SetVariant(emeraldRequestedVariant);
        SetStatus(isRevenant ? (emeraldSpell.Variant == 0 ? "翠焰亡灵 · 翠毒漫天" : "翠焰亡灵 · 返场毒爆") : "失名猎犬 · 冥火喷吐");
        hellHoundHandle?.TargetAnchor.GetComponent<EnemyTargetSigil>()
            ?.SetState(EnemyTargetSigilState.Hidden);
        // Fire breath is a ranged action. Keep the hound on its authored
        // enemy-row anchor so attacks never destroy the front/back formation
        // or hide the projectile origin behind the player model.
        actor.position = home;
        actor.rotation = Quaternion.identity;
        if (emeraldRevenant != null && emeraldRevenant.IsInstalled) { animator = null; emeraldRevenant.Cast(); }
        animator?.SetBool("Running", false);
        // The model's attack state is part of the 3D cast beat. Trigger it
        // before the charge so the mouth/torso motion leads the authored
        // fireball instead of leaving a static model beside the VFX.
        animator?.ResetTrigger("Attack");
        animator?.SetTrigger("Attack");
        FaceHellHoundAt(player.transform.position);
        yield return new WaitForSeconds(0.08f);

        if(!CanPresentEnemy(committedHound))yield break;

        UnityBattleBridge.ReportPresentationPhase("hell-hound-charge");
        yield return isRevenant ? emeraldSpell.PlayCharge(
            () => HellHoundFireBreathSourceAnchor,
            () => PlayerFireBreathImpactAnchor) : hellHoundFireball.PlayCharge(
            () => HellHoundFireBreathSourceAnchor,
            () => PlayerFireBreathImpactAnchor);
        if(!CanPresentEnemy(committedHound))yield break;
        UnityBattleBridge.ReportPresentationPhase("hell-hound-breath");
        yield return isRevenant ? emeraldSpell.Fly(
            () => HellHoundFireBreathSourceAnchor,
            () => PlayerFireBreathImpactAnchor) : hellHoundFireball.Fly(
            () => HellHoundFireBreathSourceAnchor,
            () => PlayerFireBreathImpactAnchor);
        if(!CanPresentEnemy(committedHound))yield break;
        // Contact matches the native 1.1-second damage deadline.

        UnityBattleBridge.ReportPresentationPhase("hell-hound-impact");
        var paperDoubleIntercepted = !(masquerade && masquerade.IsActive)
            && (foolDefenseVFX.IsDeployed || foolDefenseVFX.IsArmed);
        if (paperDoubleIntercepted)
        {
            SetStatus("纸人代身 · 承接冥火");
            if (foolDefenseVFX.IsArmed)
                foolDefenseVFX.Deploy(GetPaperDoubleAnchor);
            // Hide the actor on the authored contact frame. The paper break
            // then owns the silhouette until its last shard has drifted away.
            SetPlayerVisualVisible(false);
            foolDefenseVFX.Consume();
        }
        var contact = PlayerFireBreathImpactAnchor;
        if (isRevenant) {
            yield return emeraldSpell.PlayImpact(() => contact, () => {
                if(!CanPresentEnemy(committedHound))return;
                UnityBattleBridge.ReportCombatContact("enemy:" + EnemyBattleIds.HellHoundPrimary);
                Debug.Log($"SIGNATURE_CONTACT kind=Emerald variant={emeraldSpell.Variant} id={EnemyBattleIds.HellHoundPrimary}");
            });
        } else {
            // FireBall already includes its authored terminal detonation.
            // Layering a second burst here obscures the player at contact.
            yield return hellHoundFireball.PlayImpact(() => contact, () => {
                if(CanPresentEnemy(committedHound))UnityBattleBridge.ReportCombatContact("enemy:" + EnemyBattleIds.HellHoundPrimary);
            });
        }
        if (paperDoubleIntercepted)
        {
            yield return foolDefenseVFX.WaitForCompletion();
            RestorePlayerPresentation();
        }
        UnityBattleBridge.ReportPresentationPhase("hell-hound-clear");
        yield return new WaitForSeconds(0.10f);
        actor.position = home;
        actor.rotation = Quaternion.identity;
        playerDefending = false;
        actionRunning = false;
        UnityBattleBridge.ReportPresentationComplete("enemy");
    }

    IEnumerator PresentHellHoundPounceTurn()
    {
        var actor = hellHoundHandle != null ? hellHoundHandle.EnemyRoot : null;
        if (actor == null || !actor.gameObject.activeInHierarchy || player == null) yield break;
        var home = actor.position;
        var animator = actor.GetComponentInChildren<Animator>(true);
        animator?.SetTrigger("Attack");
        var target = Vector3.Lerp(home, player.transform.position, .65f);
        float elapsed = 0;
        while (elapsed < 1.1f) {
            elapsed += Time.deltaTime;
            float t = Mathf.Clamp01(elapsed / 1.1f);
            actor.position = Vector3.Lerp(home, target, t) + Vector3.up * Mathf.Sin(t * Mathf.PI) * .5f;
            yield return null;
        }
        UnityBattleBridge.ReportCombatContact("enemy:hell-hound-primary");
        elapsed = 0;
        while (elapsed < .45f) {
            elapsed += Time.deltaTime;
            actor.position = Vector3.Lerp(target, home, Mathf.Clamp01(elapsed / .45f));
            yield return null;
        }
        actor.position = home;
        UnityBattleBridge.ReportPresentationComplete("enemy");
    }

    public void CreateHellHoundAttackPosePreview()
    {
        if (encounterModel != EncounterModel.HellHound || hellHoundHandle == null || player == null)
            return;
        hellHoundHandle.EnemyRoot.position = hellHoundUsesFireBreath
            ? enemyHome
            : GetHellHoundStrikePosition();
        FaceHellHoundAt(player.transform.position);
        hellHoundHandle.TargetAnchor.GetComponent<EnemyTargetSigil>()
            ?.SetState(EnemyTargetSigilState.Hidden);
    }

    Vector3 GetHellHoundStrikePosition()
    {
        // Stop directly in front of the player. The previous side offset made
        // the hound look as if it ran past its target before breathing fire.
        return new Vector3(
            playerHome.x,
            enemyHome.y,
            playerHome.z + 1.95f
        );
    }

    void FaceHellHoundAt(Vector3 target)
    {
        var actor = hellHoundHandle != null ? hellHoundHandle.EnemyRoot : null;
        if (actor == null) return;
        var direction = target - actor.position;
        direction.y = 0f;
        if (direction.sqrMagnitude < 0.0001f) return;

        // The profile's visual correction makes the authored hound face -Z
        // at the identity root rotation. Rotate that presentation forward
        // vector toward the player only for the breath beat.
        actor.rotation = Quaternion.FromToRotation(
            Vector3.back,
            direction.normalized
        );
    }

    IEnumerator PresentPlayerDefeatSequence()
    {
        ClearPlayerImpact(true);
        playerChoreography?.Clear();
        playerDefeatPresentationActive = true;
        yield return new WaitForSeconds(0.08f);

        var shatterCenter = player.transform.position + Vector3.up * 0.92f;
        var shards = BakePlayerIntoShards(shatterCenter, 42);
        SetPlayerVisualVisible(false);

        if (foolSkillVFX != null)
            StartCoroutine(foolSkillVFX.PlayPlayerDefeat(shatterCenter));

        yield return AnimatePlayerShards(shards, shatterCenter, 0.86f);
        ApplyPlayerEncounterScale();
        playerDefeatRoutine = null;
        UnityBattleBridge.ReportPresentationComplete("player-defeated");
    }

    sealed class PlayerMeshShard
    {
        public GameObject GameObject;
        public MeshRenderer Renderer;
        public Vector3 Velocity;
        public Vector3 AngularVelocity;
        public Vector3 BaseScale;
        public MaterialPropertyBlock MaterialBlock;
    }

    List<PlayerMeshShard> BakePlayerIntoShards(Vector3 worldCenter, int desiredCount)
    {
        var result = new List<PlayerMeshShard>();
        var skinnedRenderers = player.GetComponentsInChildren<SkinnedMeshRenderer>(true);
        if (skinnedRenderers.Length == 0) return result;

            // Divide the baked pose into contiguous body-space cells instead
            // of hashing disconnected triangles together. 4 x 6 x 2 yields
            // at most 48 readable chunks (head/torso/limbs remain visibly
            // coherent for the first half of the defeat beat).
            const int xCells = 4;
            const int yCells = 6;
            const int zCells = 2;
            const int piecesPerRenderer = xCells * yCells * zCells;
        foreach (var source in skinnedRenderers)
        {
            if (source.sharedMesh == null || !source.enabled) continue;
            var baked = new Mesh { name = $"{source.name} · Defeat Snapshot" };
            source.BakeMesh(baked);
            var vertices = baked.vertices;
            var normals = baked.normals;
            var uvs = baked.uv;
            var buckets = new List<int[]>[piecesPerRenderer];
            for (var i = 0; i < buckets.Length; i++) buckets[i] = new List<int[]>();

            for (var submesh = 0; submesh < baked.subMeshCount; submesh++)
            {
                var triangles = baked.GetTriangles(submesh);
                for (var index = 0; index + 2 < triangles.Length; index += 3)
                {
                    var a = triangles[index];
                    var b = triangles[index + 1];
                    var c = triangles[index + 2];
                    var centroid = (vertices[a] + vertices[b] + vertices[c]) / 3f;
                    var bounds = baked.bounds;
                    var normalized = new Vector3(
                        Mathf.InverseLerp(bounds.min.x, bounds.max.x, centroid.x),
                        Mathf.InverseLerp(bounds.min.y, bounds.max.y, centroid.y),
                        Mathf.InverseLerp(bounds.min.z, bounds.max.z, centroid.z)
                    );
                    var cellX = Mathf.Min(xCells - 1, Mathf.FloorToInt(normalized.x * xCells));
                    var cellY = Mathf.Min(yCells - 1, Mathf.FloorToInt(normalized.y * yCells));
                    var cellZ = Mathf.Min(zCells - 1, Mathf.FloorToInt(normalized.z * zCells));
                    var bucketIndex = cellX + cellY * xCells + cellZ * xCells * yCells;
                    buckets[bucketIndex].Add(new[] { submesh, a, b, c });
                }
            }

            for (var bucketIndex = 0; bucketIndex < buckets.Length; bucketIndex++)
            {
                var triangles = buckets[bucketIndex];
                if (triangles.Count == 0) continue;
                var shardVertices = new List<Vector3>(triangles.Count * 3);
                var shardNormals = new List<Vector3>(triangles.Count * 3);
                var shardUVs = new List<Vector2>(triangles.Count * 3);
                var shardSubmeshes = new List<int>[baked.subMeshCount];
                for (var i = 0; i < shardSubmeshes.Length; i++) shardSubmeshes[i] = new List<int>();

                foreach (var triangle in triangles)
                {
                    var submesh = triangle[0];
                    for (var corner = 1; corner <= 3; corner++)
                    {
                        var sourceIndex = triangle[corner];
                        shardSubmeshes[submesh].Add(shardVertices.Count);
                        shardVertices.Add(vertices[sourceIndex]);
                        shardNormals.Add(normals.Length == vertices.Length ? normals[sourceIndex] : Vector3.up);
                        shardUVs.Add(uvs.Length == vertices.Length ? uvs[sourceIndex] : Vector2.zero);
                    }
                }

                var shardMesh = new Mesh { name = $"Memory Shard {bucketIndex + 1}" };
                shardMesh.SetVertices(shardVertices);
                shardMesh.SetNormals(shardNormals);
                shardMesh.SetUVs(0, shardUVs);
                shardMesh.subMeshCount = shardSubmeshes.Length;
                for (var submesh = 0; submesh < shardSubmeshes.Length; submesh++)
                    shardMesh.SetTriangles(shardSubmeshes[submesh], submesh);
                shardMesh.RecalculateBounds();

                var shardObject = new GameObject($"愚者碎片 {result.Count + 1}");
                shardObject.transform.SetPositionAndRotation(source.transform.position, source.transform.rotation);
                shardObject.transform.localScale = source.transform.lossyScale;
                shardObject.AddComponent<MeshFilter>().sharedMesh = shardMesh;
                var shardRenderer = shardObject.AddComponent<MeshRenderer>();
                shardRenderer.sharedMaterials = source.sharedMaterials;
                shardRenderer.shadowCastingMode = source.shadowCastingMode;
                shardRenderer.receiveShadows = source.receiveShadows;
                playerDefeatShardObjects.Add(shardObject);

                var shardWorldCenter = shardRenderer.bounds.center;
                var direction = shardWorldCenter - worldCenter;
                if (direction.sqrMagnitude < 0.001f)
                    direction = new Vector3(
                        Mathf.Sin(bucketIndex * 2.17f),
                        0.25f + (bucketIndex % 4) * 0.09f,
                        Mathf.Cos(bucketIndex * 1.73f)
                    );
                direction.Normalize();
                var speed = 0.58f + (bucketIndex % 7) * 0.085f;
                result.Add(new PlayerMeshShard
                {
                    GameObject = shardObject,
                    Renderer = shardRenderer,
                    Velocity = direction * speed + Vector3.up * (0.18f + (bucketIndex % 5) * 0.06f),
                    AngularVelocity = new Vector3(
                        90f + (bucketIndex % 6) * 31f,
                        120f + (bucketIndex % 5) * 37f,
                        80f + (bucketIndex % 7) * 29f
                    ) * (bucketIndex % 2 == 0 ? 1f : -1f),
                    BaseScale = shardObject.transform.localScale,
                    MaterialBlock = new MaterialPropertyBlock()
                });
            }
            Destroy(baked);
        }
        return result;
    }

    IEnumerator AnimatePlayerShards(List<PlayerMeshShard> shards, Vector3 worldCenter, float duration)
    {
        var elapsed = 0f;
        while (elapsed < duration)
        {
            var delta = Time.deltaTime;
            elapsed += delta;
            var progress = Mathf.Clamp01(elapsed / duration);
            var drag = Mathf.Lerp(1f, 0.32f, progress);
            var scale = Mathf.Lerp(1f, 0.04f, Mathf.SmoothStep(0f, 1f, progress));
            var ashTint = Color.Lerp(Color.white, new Color(0.055f, 0.025f, 0.07f, 1f), Mathf.SmoothStep(0.12f, 0.92f, progress));
            foreach (var shard in shards)
            {
                if (shard.GameObject == null) continue;
                shard.Velocity += Vector3.down * (0.48f * delta);
                shard.GameObject.transform.position += shard.Velocity * drag * delta;
                shard.GameObject.transform.Rotate(shard.AngularVelocity * delta, Space.Self);
                shard.GameObject.transform.localScale = shard.BaseScale * scale;
                if (shard.Renderer != null)
                {
                    shard.Renderer.GetPropertyBlock(shard.MaterialBlock);
                    shard.MaterialBlock.SetColor("_BaseColor", ashTint);
                    shard.MaterialBlock.SetColor("_Color", ashTint);
                    shard.Renderer.SetPropertyBlock(shard.MaterialBlock);
                }
            }
            yield return null;
        }

        foreach (var shard in shards)
        {
            if (shard.GameObject == null) continue;
            var filter = shard.GameObject.GetComponent<MeshFilter>();
            if (filter != null && filter.sharedMesh != null) Destroy(filter.sharedMesh);
            Destroy(shard.GameObject);
            playerDefeatShardObjects.Remove(shard.GameObject);
        }
    }

    IEnumerator ResolveRound(PlayerAction action)
    {
        actionRunning = true;
        playerDefending = action == PlayerAction.Defend;

        switch (action)
        {
            case PlayerAction.Basic:
                SetStatus("愚者 · 秘仪飞牌");
                PrepareCompactPlayerBasic();
                foolBasicTarotVFX.Play(Camera.main, player.transform, enemy.transform);
                enemy.GetComponentInChildren<Mindstone.VFXV1.GuardianWard>()?.ImpactAfter(.58f);
                yield return new WaitForSeconds(0.58f);
                enemyAnimator?.SetTrigger("Hit");
                DamageEnemy(60);
                yield return new WaitForSeconds(1.1f);
                break;

            case PlayerAction.Skill:
                SetStatus("愚者 · 错步穿行");
                playerAnimator?.SetTrigger("Attack");
                yield return new WaitForSeconds(0.72f);
                enemyAnimator?.SetTrigger("Hit");
                DamageEnemy(120);
                yield return new WaitForSeconds(1.15f);
                break;

            case PlayerAction.Defend:
                SetStatus("愚者 · Meshy 格挡姿态");
                yield return new WaitForSeconds(0.65f);
                break;
        }

        if (enemyHp > 0)
            yield return EnemyTurn();

        if (enemyHp > 0 && playerHp > 0)
        {
            playerDefending = false;
            SetStatus("请选择下一行动");
        }
        actionRunning = false;
    }

    IEnumerator EnemyTurn()
    {
        SetStatus("空壳守卫 · 校正重击");
        enemy.transform.position = enemyHome;
        enemyAnimator?.SetBool("Running", false);
        SetEnemyWeaponTrail(true);
        enemyAnimator?.SetTrigger("Attack");
        yield return new WaitForSeconds(0.30f);
        SetEnemyWeaponTrail(false);

        var damage = playerDefending ? 30 : 60;
        playerHp = Mathf.Max(0, playerHp - damage);
        SetStatus(playerDefending ? "防御成功 · 普通攻击伤害降低 50%" : $"愚者受到 {damage} 点伤害");
        RefreshHud();
        yield return new WaitForSeconds(0.16f);

        if (playerHp == 0) SetStatus("战斗失败");
    }

    static IEnumerator MoveCharacter(Transform character, Vector3 start, Vector3 end, float duration)
    {
        var elapsed = 0f;
        while (elapsed < duration)
        {
            elapsed += Time.deltaTime;
            var amount = Mathf.SmoothStep(0f, 1f, Mathf.Clamp01(elapsed / duration));
            character.position = Vector3.Lerp(start, end, amount);
            yield return null;
        }
        character.position = end;
    }

    void BuildEnemyWeaponEffects()
    {
        if (!enemy || enemyAnimator == null) return;
        var anchor = enemyAnimator.GetBoneTransform(HumanBodyBones.RightHand) ?? enemy.transform;
        var bladeTipLocal = DetectBladeTipLocal(anchor);
        var bladeEnergy = new GameObject("Clock Guard Living Blade Energy");
        bladeEnergy.transform.SetParent(anchor, false);
        bladeEnergy.transform.localPosition = Vector3.zero;
        bladeEnergy.transform.localRotation = Quaternion.identity;

        for (var layer = 0; layer < 3; layer++)
        {
            var lineObject = new GameObject($"Blade Energy Layer {layer + 1}");
            lineObject.transform.SetParent(bladeEnergy.transform, false);
            var line = lineObject.AddComponent<LineRenderer>();
            line.useWorldSpace = false;
            line.positionCount = 7;
            line.numCornerVertices = 4;
            line.numCapVertices = 5;
            line.textureMode = LineTextureMode.Stretch;
            var isCore = layer == 2;
            var offset = (layer - 1) * 0.025f;
            for (var point = 0; point < line.positionCount; point++)
            {
                var t = point / (float)(line.positionCount - 1);
                line.SetPosition(
                    point,
                    bladeTipLocal * Mathf.Lerp(0.08f, 0.98f, t)
                    + Vector3.right * (
                        offset + Mathf.Sin(t * Mathf.PI * 2f + layer) * 0.008f
                    )
                );
            }
            line.startWidth = isCore ? 0.035f : 0.11f;
            line.endWidth = isCore ? 0.012f : 0.028f;
            var bladeColor = isCore
                ? new Color(1f, 0.92f, 0.78f, 0.98f)
                : new Color(1f, 0.02f, 0.01f, layer == 0 ? 0.34f : 0.72f);
            var material = EffectMaterial(bladeColor);
            material.renderQueue = 3150 + layer;
            line.material = material;
            line.startColor = bladeColor;
            line.endColor = new Color(bladeColor.r, bladeColor.g, bladeColor.b, 0.08f);
            enemyBladeGlowLines.Add(line);
            enemyBladeGlowMaterials.Add(material);
        }

        var glow = new GameObject("Clock Guard Sword Tip Glow");
        glow.transform.SetParent(bladeEnergy.transform, false);
        glow.transform.localPosition = bladeTipLocal * 0.98f;

        enemyWeaponLight = glow.AddComponent<Light>();
        enemyWeaponLight.type = LightType.Point;
        enemyWeaponLight.color = new Color(1f, 0.12f, 0.03f);
        enemyWeaponLight.range = 3.8f;
        enemyWeaponLight.intensity = 3.0f;

        enemyWeaponTrail = glow.AddComponent<TrailRenderer>();
        enemyWeaponTrail.time = 0.32f;
        enemyWeaponTrail.startWidth = 0.34f;
        enemyWeaponTrail.endWidth = 0.02f;
        enemyWeaponTrail.minVertexDistance = 0.025f;
        enemyWeaponTrail.material = EffectMaterial(new Color(1f, 0.02f, 0.01f, 0.9f));
        enemyWeaponTrail.startColor = new Color(1f, 0.08f, 0.02f, 0.95f);
        enemyWeaponTrail.endColor = new Color(0.45f, 0f, 0f, 0f);
        enemyWeaponTrail.emitting = false;
    }

    Vector3 DetectBladeTipLocal(Transform hand)
    {
        var bestDistance = 0f;
        var bestWorldPoint = Vector3.zero;
        var renderers = enemy.GetComponentsInChildren<SkinnedMeshRenderer>(true);
        for (var rendererIndex = 0; rendererIndex < renderers.Length; rendererIndex++)
        {
            var renderer = renderers[rendererIndex];
            if (!renderer.sharedMesh) continue;
            var handBoneIndex = System.Array.IndexOf(renderer.bones, hand);
            if (handBoneIndex < 0) continue;

            var weights = renderer.sharedMesh.boneWeights;
            var baked = new Mesh();
            renderer.BakeMesh(baked);
            var vertices = baked.vertices;
            var count = Mathf.Min(vertices.Length, weights.Length);
            for (var vertexIndex = 0; vertexIndex < count; vertexIndex++)
            {
                var weight = weights[vertexIndex];
                var handWeight =
                    (weight.boneIndex0 == handBoneIndex ? weight.weight0 : 0f)
                    + (weight.boneIndex1 == handBoneIndex ? weight.weight1 : 0f)
                    + (weight.boneIndex2 == handBoneIndex ? weight.weight2 : 0f)
                    + (weight.boneIndex3 == handBoneIndex ? weight.weight3 : 0f);
                if (handWeight < 0.45f) continue;
                var worldPoint = renderer.transform.TransformPoint(vertices[vertexIndex]);
                var distance = Vector3.Distance(hand.position, worldPoint);
                if (distance <= bestDistance) continue;
                bestDistance = distance;
                bestWorldPoint = worldPoint;
            }
            Destroy(baked);
        }

        if (bestDistance > 0.45f)
        {
            var detected = hand.InverseTransformPoint(bestWorldPoint);
            Debug.Log($"Mindstone: detected Clock Guard blade tip {detected} at {bestDistance:F2}m.");
            return detected;
        }

        Debug.LogWarning("Mindstone: could not detect blade vertices; using calibrated fallback axis.");
        return new Vector3(0f, -1.72f, 0f);
    }

    void SetEnemyWeaponTrail(bool active)
    {
        if (enemyWeaponTrail)
        {
            if (active) enemyWeaponTrail.Clear();
            enemyWeaponTrail.emitting = active;
        }
        if (enemyWeaponLight) enemyWeaponLight.intensity = active ? 5.5f : 2.4f;
    }

    static void SetClockGuardWeaponTrail(Transform actor, bool active)
    {
        if (actor == null) return;
        var trails = actor.GetComponentsInChildren<TrailRenderer>(true);
        for (var index = 0; index < trails.Length; index++)
        {
            var trail = trails[index];
            if (trail == null || trail.gameObject.name != "Clock Guard Sword Tip Glow")
                continue;
            if (active) trail.Clear();
            trail.emitting = active;
            var light = trail.GetComponent<Light>();
            if (light != null) light.intensity = active ? 5.5f : 2.4f;
        }
    }

    static Material EffectMaterial(Color color)
    {
        var shader = Shader.Find("Sprites/Default")
            ?? Shader.Find("Unlit/Color")
            ?? Shader.Find("Standard");
        var material = new Material(shader) { color = color };
        if (material.HasProperty("_EmissionColor"))
        {
            material.EnableKeyword("_EMISSION");
            material.SetColor("_EmissionColor", color * 3f);
        }
        return material;
    }

    IEnumerator PlaySwordFormationVFX(Vector3 center, float duration)
    {
        yield return new WaitForSeconds(0.04f);
        const int swordCount = 3;
        var formation = new GameObject("Clock Guard Golden Sword Orbit");
        formation.transform.position = center;
        var swordGlows = new List<LineRenderer>();
        var swordCores = new List<LineRenderer>();
        var swordGuards = new List<LineRenderer>();
        var orbitTrails = new List<LineRenderer>();
        var swordMeshes = new List<Mesh>();
        var swordMeshMaterials = new List<Material>();
        var effectMaterials = new List<Material>();

        for (var i = 0; i < swordCount; i++)
        {
            var swordObject = new GameObject($"Converging Energy Sword {i + 1}");
            swordObject.transform.SetParent(formation.transform, false);

            var glow = swordObject.AddComponent<LineRenderer>();
            glow.useWorldSpace = true;
            glow.loop = false;
            glow.positionCount = 3;
            glow.numCornerVertices = 8;
            glow.numCapVertices = 8;
            glow.startWidth = 0.18f;
            glow.endWidth = 0.025f;
            glow.alignment = LineAlignment.View;
            var glowMaterial = EffectMaterial(new Color(1f, 0.58f, 0.08f, 0.72f));
            glowMaterial.renderQueue = 3260 + i;
            glow.material = glowMaterial;
            swordGlows.Add(glow);
            effectMaterials.Add(glowMaterial);

            var coreObject = new GameObject("White-Gold Sword Core");
            coreObject.transform.SetParent(swordObject.transform, false);
            var core = coreObject.AddComponent<LineRenderer>();
            core.useWorldSpace = true;
            core.loop = false;
            core.positionCount = 3;
            core.numCornerVertices = 7;
            core.numCapVertices = 7;
            core.startWidth = 0.045f;
            core.endWidth = 0.008f;
            core.alignment = LineAlignment.View;
            var coreMaterial = EffectMaterial(new Color(1f, 0.96f, 0.70f, 0.98f));
            coreMaterial.renderQueue = 3290 + i;
            core.material = coreMaterial;
            swordCores.Add(core);
            effectMaterials.Add(coreMaterial);

            var guardObject = new GameObject("Sword Crossguard");
            guardObject.transform.SetParent(swordObject.transform, false);
            var guard = guardObject.AddComponent<LineRenderer>();
            guard.useWorldSpace = true;
            guard.loop = false;
            guard.positionCount = 3;
            guard.numCornerVertices = 7;
            guard.numCapVertices = 7;
            guard.startWidth = 0.055f;
            guard.endWidth = 0.055f;
            guard.alignment = LineAlignment.View;
            var guardMaterial = EffectMaterial(new Color(1f, 0.82f, 0.26f, 0.92f));
            guardMaterial.renderQueue = 3300 + i;
            guard.material = guardMaterial;
            swordGuards.Add(guard);
            effectMaterials.Add(guardMaterial);

            var silhouetteObject = new GameObject("Energy Sword Silhouette");
            silhouetteObject.transform.SetParent(swordObject.transform, false);
            var mesh = new Mesh { name = $"Energy Sword Mesh {i + 1}" };
            mesh.vertices = new Vector3[11];
            mesh.triangles = new[]
            {
                0, 1, 2,
                3, 4, 5, 3, 5, 6,
                7, 8, 10, 7, 10, 9
            };
            silhouetteObject.AddComponent<MeshFilter>().mesh = mesh;
            var meshRenderer = silhouetteObject.AddComponent<MeshRenderer>();
            var meshMaterial = EffectMaterial(new Color(1f, 0.74f, 0.16f, 0f));
            meshMaterial.renderQueue = 3295 + i;
            meshRenderer.material = meshMaterial;
            swordMeshes.Add(mesh);
            swordMeshMaterials.Add(meshMaterial);
            effectMaterials.Add(meshMaterial);

            var trailObject = new GameObject("Crescent Wind Blade Trail");
            trailObject.transform.SetParent(swordObject.transform, false);
            var orbitTrail = trailObject.AddComponent<LineRenderer>();
            orbitTrail.useWorldSpace = true;
            orbitTrail.loop = false;
            orbitTrail.positionCount = 12;
            orbitTrail.numCornerVertices = 8;
            orbitTrail.numCapVertices = 8;
            orbitTrail.widthMultiplier = 0.22f;
            orbitTrail.widthCurve = new AnimationCurve(
                new Keyframe(0f, 0f),
                new Keyframe(0.58f, 0.74f),
                new Keyframe(1f, 0.06f)
            );
            orbitTrail.alignment = LineAlignment.View;
            var trailMaterial = EffectMaterial(new Color(1f, 0.91f, 0.58f, 0f));
            trailMaterial.renderQueue = 3270 + i;
            orbitTrail.material = trailMaterial;
            orbitTrails.Add(orbitTrail);
            effectMaterials.Add(trailMaterial);
        }

        var impactRings = new List<LineRenderer>();
        for (var ringIndex = 0; ringIndex < 2; ringIndex++)
        {
            var ringObject = new GameObject($"Sword Impact Ring {ringIndex + 1}");
            ringObject.transform.SetParent(formation.transform, false);
            var ring = ringObject.AddComponent<LineRenderer>();
            ring.useWorldSpace = true;
            ring.loop = true;
            ring.positionCount = 64;
            ring.numCornerVertices = 6;
            ring.startWidth = ringIndex == 0 ? 0.16f : 0.075f;
            ring.endWidth = ring.startWidth;
            ring.alignment = LineAlignment.View;
            var ringMaterial = EffectMaterial(
                ringIndex == 0
                    ? new Color(1f, 0.92f, 0.64f, 0f)
                    : new Color(0.94f, 0.97f, 1f, 0f)
            );
            ringMaterial.renderQueue = 3310 + ringIndex;
            ring.material = ringMaterial;
            ring.startColor = Color.clear;
            ring.endColor = Color.clear;
            impactRings.Add(ring);
            effectMaterials.Add(ringMaterial);
        }

        var elapsed = 0f;
        var impactPlayed = false;
        while (elapsed < duration)
        {
            elapsed += Time.deltaTime;
            var t = Mathf.Clamp01(elapsed / duration);
            var cameraRight = Camera.main ? Camera.main.transform.right : Vector3.right;
            var cameraUp = Camera.main ? Camera.main.transform.up : Vector3.up;
            var cameraForward = Camera.main ? Camera.main.transform.forward : Vector3.forward;

            for (var i = 0; i < swordGlows.Count; i++)
            {
                var stagger = i * 0.055f;
                var flight = Mathf.Clamp01((t - stagger) / (0.80f - stagger));
                var angle = -0.72f + flight * 4.35f + i * Mathf.PI * 2f / swordCount;
                var radial = cameraRight * Mathf.Cos(angle) * 2.05f
                    + cameraUp * Mathf.Sin(angle) * 0.62f;
                var tangent = (
                    cameraRight * -Mathf.Sin(angle)
                    + cameraUp * Mathf.Cos(angle) * 0.62f
                ).normalized;
                var swordCenter = center + radial - cameraForward * (0.02f + i * 0.015f);
                var length = 1.55f + Mathf.Sin(flight * Mathf.PI) * 0.24f;
                var tailPoint = swordCenter - tangent * length * 0.46f;
                var midPoint = swordCenter + tangent * length * 0.12f;
                var tipPoint = swordCenter + tangent * length * 0.54f;
                var visibility = Mathf.SmoothStep(0f, 1f, Mathf.Clamp01(flight / 0.12f))
                    * (1f - Mathf.SmoothStep(0.72f, 0.96f, flight));
                var flicker = 0.90f + Mathf.Sin(elapsed * 24f + i * 1.9f) * 0.10f;
                var alpha = visibility * flicker;

                var glow = swordGlows[i];
                glow.SetPosition(0, tailPoint);
                glow.SetPosition(1, midPoint);
                glow.SetPosition(2, tipPoint);
                glow.startColor = new Color(1f, 0.38f, 0.025f, alpha * 0.46f);
                glow.endColor = new Color(1f, 0.88f, 0.36f, alpha * 0.86f);

                var core = swordCores[i];
                core.SetPosition(0, Vector3.Lerp(tailPoint, midPoint, 0.18f));
                core.SetPosition(1, midPoint);
                core.SetPosition(2, tipPoint);
                core.startColor = new Color(1f, 0.68f, 0.12f, alpha * 0.72f);
                core.endColor = new Color(1f, 1f, 0.90f, alpha);

                var guardCenter = Vector3.Lerp(tailPoint, midPoint, 0.22f);
                var guardHalfWidth = 0.24f + Mathf.Sin(elapsed * 19f + i) * 0.025f;
                var guard = swordGuards[i];
                guard.SetPosition(0, guardCenter - tangent * guardHalfWidth);
                guard.SetPosition(1, guardCenter);
                guard.SetPosition(2, guardCenter + tangent * guardHalfWidth);
                guard.startColor = new Color(1f, 0.48f, 0.04f, alpha * 0.68f);
                guard.endColor = new Color(1f, 0.96f, 0.65f, alpha);

                UpdateEnergySwordMesh(
                    swordMeshes[i],
                    tailPoint - center,
                    tipPoint - center,
                    tangent,
                    alpha
                );
                var meshColor = new Color(1f, 0.72f, 0.12f, alpha * 0.88f);
                swordMeshMaterials[i].color = meshColor;
                if (swordMeshMaterials[i].HasProperty("_EmissionColor"))
                    swordMeshMaterials[i].SetColor("_EmissionColor", meshColor * 5.2f);

                var orbitTrail = orbitTrails[i];
                for (var trailPoint = 0; trailPoint < orbitTrail.positionCount; trailPoint++)
                {
                    var trailProgress = trailPoint / (float)(orbitTrail.positionCount - 1);
                    var trailAngle = angle - (1f - trailProgress) * 0.68f;
                    orbitTrail.SetPosition(
                        trailPoint,
                        center
                        + cameraRight * Mathf.Cos(trailAngle) * 2.05f
                        + cameraUp * Mathf.Sin(trailAngle) * 0.62f
                        - cameraForward * (0.025f + i * 0.015f)
                    );
                }
                orbitTrail.startColor = new Color(1f, 0.62f, 0.10f, 0f);
                orbitTrail.endColor = new Color(1f, 0.98f, 0.78f, alpha * 0.50f);
            }

            if (!impactPlayed && t >= 0.48f)
            {
                impactPlayed = true;
                EmitSwordImpact(center);
            }

            var impactT = Mathf.Clamp01((t - 0.46f) / 0.54f);
            for (var ringIndex = 0; ringIndex < impactRings.Count; ringIndex++)
            {
                var ring = impactRings[ringIndex];
                var delayed = Mathf.Clamp01(impactT * 1.35f - ringIndex * 0.22f);
                var ringRadius = Mathf.Lerp(0.08f, 2.05f + ringIndex * 0.45f, delayed);
                for (var point = 0; point < ring.positionCount; point++)
                {
                    var angle = point * Mathf.PI * 2f / ring.positionCount;
                    var ripple = 1f + Mathf.Sin(angle * 5f + elapsed * 20f) * 0.025f;
                    ring.SetPosition(
                        point,
                        center
                        + cameraRight * Mathf.Cos(angle) * ringRadius * ripple
                        + cameraUp * Mathf.Sin(angle) * ringRadius * 0.55f * ripple
                    );
                }
                var ringAlpha = Mathf.Sin(delayed * Mathf.PI);
                var ringColor = ringIndex == 0
                    ? new Color(1f, 0.80f, 0.26f, ringAlpha * 0.78f)
                    : new Color(0.94f, 0.97f, 1f, ringAlpha * 0.66f);
                ring.startColor = ringColor;
                ring.endColor = new Color(1f, 0.98f, 0.78f, ringAlpha * 0.22f);
            }
            yield return null;
        }

        for (var i = 0; i < effectMaterials.Count; i++) Destroy(effectMaterials[i]);
        for (var i = 0; i < swordMeshes.Count; i++) Destroy(swordMeshes[i]);
        Destroy(formation);
    }

    static void UpdateEnergySwordMesh(
        Mesh mesh,
        Vector3 tail,
        Vector3 tip,
        Vector3 side,
        float alpha
    )
    {
        if (alpha <= 0.002f)
        {
            mesh.Clear(false);
            return;
        }

        var axis = tip - tail;
        var guardCenter = tail + axis * 0.30f;
        var bladeBase = tail + axis * 0.39f;
        var guardDepth = axis.normalized * 0.035f;
        var vertices = new[]
        {
            tip,
            bladeBase - side * 0.085f,
            bladeBase + side * 0.085f,
            guardCenter - side * 0.28f - guardDepth,
            guardCenter + side * 0.28f - guardDepth,
            guardCenter + side * 0.28f + guardDepth,
            guardCenter - side * 0.28f + guardDepth,
            tail - side * 0.055f,
            tail + side * 0.055f,
            guardCenter - side * 0.055f,
            guardCenter + side * 0.055f
        };
        mesh.vertices = vertices;
        mesh.triangles = new[]
        {
            0, 1, 2,
            3, 4, 5, 3, 5, 6,
            7, 8, 10, 7, 10, 9
        };
        mesh.RecalculateBounds();
    }

    void EmitSwordImpact(Vector3 center)
    {
        var burstObject = new GameObject("Clock Guard Sword Impact Sparks");
        burstObject.transform.position = center;
        var particles = burstObject.AddComponent<ParticleSystem>();
        var main = particles.main;
        main.duration = 0.42f;
        main.loop = false;
        main.playOnAwake = false;
        main.startLifetime = new ParticleSystem.MinMaxCurve(0.30f, 0.66f);
        main.startSpeed = new ParticleSystem.MinMaxCurve(2.2f, 5.6f);
        main.startSize = new ParticleSystem.MinMaxCurve(0.055f, 0.22f);
        main.startRotation = new ParticleSystem.MinMaxCurve(0f, Mathf.PI * 2f);
        main.simulationSpace = ParticleSystemSimulationSpace.World;
        main.maxParticles = 96;

        var emission = particles.emission;
        emission.enabled = true;
        emission.SetBursts(new[] { new ParticleSystem.Burst(0f, 72) });

        var shape = particles.shape;
        shape.enabled = true;
        shape.shapeType = ParticleSystemShapeType.Sphere;
        shape.radius = 0.16f;

        var colorOverLifetime = particles.colorOverLifetime;
        colorOverLifetime.enabled = true;
        var gradient = new Gradient();
        gradient.SetKeys(
            new[]
            {
                new GradientColorKey(new Color(1f, 1f, 0.82f), 0f),
                new GradientColorKey(new Color(1f, 0.74f, 0.18f), 0.42f),
                new GradientColorKey(new Color(0.62f, 0.24f, 0.02f), 1f)
            },
            new[]
            {
                new GradientAlphaKey(1f, 0f),
                new GradientAlphaKey(0.92f, 0.42f),
                new GradientAlphaKey(0f, 1f)
            }
        );
        colorOverLifetime.color = gradient;

        var sizeOverLifetime = particles.sizeOverLifetime;
        sizeOverLifetime.enabled = true;
        sizeOverLifetime.size = new ParticleSystem.MinMaxCurve(
            1f,
            AnimationCurve.EaseInOut(0f, 0.18f, 1f, 1f)
        );

        var particleRenderer = burstObject.GetComponent<ParticleSystemRenderer>();
        particleRenderer.renderMode = ParticleSystemRenderMode.Stretch;
        particleRenderer.velocityScale = 0.16f;
        particleRenderer.lengthScale = 2.8f;
        particleRenderer.material = EffectMaterial(new Color(1f, 0.78f, 0.22f, 0.96f));
        particleRenderer.material.renderQueue = 3340;

        particles.Play();
        Destroy(particleRenderer.material, 1.2f);
        Destroy(burstObject, 1.2f);
    }

    void EmitPlayerShatter(Vector3 center)
    {
        var burstObject = new GameObject("Fool Defeat Memory Shards");
        burstObject.transform.position = center;
        var particles = burstObject.AddComponent<ParticleSystem>();
        var main = particles.main;
        main.duration = 0.62f;
        main.loop = false;
        main.playOnAwake = false;
        main.startLifetime = new ParticleSystem.MinMaxCurve(0.38f, 0.82f);
        main.startSpeed = new ParticleSystem.MinMaxCurve(1.8f, 4.6f);
        main.startSize = new ParticleSystem.MinMaxCurve(0.05f, 0.16f);
        main.startRotation = new ParticleSystem.MinMaxCurve(0f, Mathf.PI * 2f);
        main.startColor = new ParticleSystem.MinMaxGradient(
            new Color(0.96f, 0.76f, 0.30f, 0.96f),
            new Color(0.48f, 0.17f, 0.88f, 0.92f)
        );
        main.simulationSpace = ParticleSystemSimulationSpace.World;
        main.maxParticles = 72;

        var emission = particles.emission;
        emission.enabled = true;
        emission.SetBursts(new[] { new ParticleSystem.Burst(0f, 56) });

        var shape = particles.shape;
        shape.enabled = true;
        shape.shapeType = ParticleSystemShapeType.Sphere;
        shape.radius = 0.22f;

        var velocity = particles.velocityOverLifetime;
        velocity.enabled = true;
        velocity.space = ParticleSystemSimulationSpace.World;
        velocity.y = new ParticleSystem.MinMaxCurve(-1.25f, 1.85f);

        var colorOverLifetime = particles.colorOverLifetime;
        colorOverLifetime.enabled = true;
        var gradient = new Gradient();
        gradient.SetKeys(
            new[]
            {
                new GradientColorKey(new Color(1f, 0.85f, 0.44f), 0f),
                new GradientColorKey(new Color(0.58f, 0.22f, 0.98f), 0.42f),
                new GradientColorKey(new Color(0.09f, 0.02f, 0.18f), 1f)
            },
            new[]
            {
                new GradientAlphaKey(0f, 0f),
                new GradientAlphaKey(0.94f, 0.10f),
                new GradientAlphaKey(0.78f, 0.62f),
                new GradientAlphaKey(0f, 1f)
            }
        );
        colorOverLifetime.color = gradient;

        var particleRenderer = burstObject.GetComponent<ParticleSystemRenderer>();
        particleRenderer.renderMode = ParticleSystemRenderMode.Stretch;
        particleRenderer.velocityScale = 0.18f;
        particleRenderer.lengthScale = 1.65f;
        particleRenderer.material = EffectMaterial(new Color(0.74f, 0.30f, 1f, 0.94f));
        particleRenderer.material.renderQueue = 3342;

        particles.Play();
        Destroy(particleRenderer.material, 1.3f);
        Destroy(burstObject, 1.3f);
    }

    static Vector3 GroundedAt(GameObject character, Vector3 position)
    {
        character.transform.position = position;
        var renderers = character.GetComponentsInChildren<Renderer>(true);
        if (renderers.Length == 0) return position;
        var bounds = renderers[0].bounds;
        for (var i = 1; i < renderers.Length; i++)
            bounds.Encapsulate(renderers[i].bounds);
        return position + Vector3.up * (position.y - bounds.min.y);
    }

    void DamageEnemy(int amount)
    {
        enemyHp = Mathf.Max(0, enemyHp - amount);
        RefreshHud();
        if (enemyHp == 0)
        {
            SetStatus("空壳守卫已击败");
            enemyAnimator?.SetTrigger("Hit");
        }
    }

    void RefreshHud()
    {
        if (enemyHpText) enemyHpText.text = $"空壳守卫   {enemyHp} / 1000";
        if (playerHpText) playerHpText.text = $"愚者   {playerHp} / 1000";
    }

    void SetStatus(string value)
    {
        if (status) status.text = value;
    }

    static Text Label(Transform parent, string value, int size, Vector2 position, Vector2 dimensions)
    {
        var labelObject = new GameObject("Label");
        labelObject.transform.SetParent(parent, false);
        var label = labelObject.AddComponent<Text>();
        label.text = value;
        label.font = Resources.GetBuiltinResource<Font>("LegacyRuntime.ttf");
        label.fontSize = size;
        label.fontStyle = FontStyle.Bold;
        label.alignment = TextAnchor.MiddleCenter;
        label.color = Color.white;
        label.horizontalOverflow = HorizontalWrapMode.Wrap;
        label.verticalOverflow = VerticalWrapMode.Truncate;
        var rect = label.rectTransform;
        rect.sizeDelta = dimensions;
        rect.anchoredPosition = position;
        return label;
    }

}
