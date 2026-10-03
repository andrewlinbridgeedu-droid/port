using System;
using System.Collections;
using System.Collections.Generic;
using System.Globalization;
using System.Runtime.InteropServices;
using UnityEngine;

/// Receives commands from the native Mistport app. Combat rules and final
/// damage continue to live in MistportCombatCore; this object only selects the
/// corresponding Meshy animation inside Unity.
public sealed class UnityBattleBridge : MonoBehaviour
{
    readonly Dictionary<Transform, ExitMaterials> exitMaterials = new Dictionary<Transform, ExitMaterials>();
    readonly Dictionary<Transform, Coroutine> exits = new Dictionary<Transform, Coroutine>();
    readonly Dictionary<Transform, Vector3> originalPositions = new Dictionary<Transform, Vector3>();
    readonly Dictionary<Transform, Quaternion> originalRotations = new Dictionary<Transform, Quaternion>();
    readonly Queue<string> pendingActions = new Queue<string>();
    public bool IsEnemyExiting(EnemyHandle actor) => actor && actor.EnemyRoot && exits.ContainsKey(actor.EnemyRoot);
    string pendingTargetPayload;
    string pendingVisibilityPayload;
    const float AnchorReportInterval = 0.12f;
    float nextAnchorReportTime;
    [RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.AfterSceneLoad)]
    static void Bootstrap()
    {
        if (FindFirstObjectByType<UnityBattleBridge>() == null)
            new GameObject("Mistport Unity Battle Bridge").AddComponent<UnityBattleBridge>();
    }

    // Called by UnityFramework.SendMessage("Mistport Unity Battle Bridge",
    // "ApplyCommand", json).
    public void ApplyCommand(string json)
    {
        var action = ExtractAction(json);
        var battle = FindFirstObjectByType<BattlePrototype>();
        if (battle == null || !battle.IsPresentationReady)
        {
            // Transient contact cannot be replayed after a cold scene/actor replacement.
            if (action.StartsWith("player-impact:", StringComparison.Ordinal)) return;
            pendingActions.Enqueue(action);
            return;
        }

        Apply(action, battle);
    }

    // Called directly by native presentation code with entries such as
    // "clock-core-primary=pending;clock-guard-primary=selected".
    // Selection is visual only; MistportCombatCore remains authoritative.
    public void SetTargetSigils(string payload)
    {
        var battle = FindFirstObjectByType<BattlePrototype>();
        if (battle == null || !battle.IsPresentationReady) { pendingTargetPayload = payload; return; }
        var handles = FindObjectsByType<EnemyHandle>(
            FindObjectsInactive.Include,
            FindObjectsSortMode.None);
        for (var index = 0; index < handles.Length; index++)
        {
            var sigil = handles[index].TargetAnchor != null
                ? handles[index].TargetAnchor.GetComponent<EnemyTargetSigil>()
                : null;
            sigil?.SetState(EnemyTargetSigilState.Hidden);
        }

        if (string.IsNullOrWhiteSpace(payload))
            return;
        var entries = payload.Split(';');
        for (var entryIndex = 0; entryIndex < entries.Length; entryIndex++)
        {
            var pair = entries[entryIndex].Split('=');
            if (pair.Length != 2)
                continue;
            var handle = FindPresentedHandle(handles, pair[0], battle);
            var sigil = handle != null && handle.TargetAnchor != null
                ? handle.TargetAnchor.GetComponent<EnemyTargetSigil>()
                : null;
            if (sigil == null)
                continue;
            // Candidates remain tappable through the native hit areas, but only
            // the current target receives a marker. This prevents a two-enemy
            // encounter from looking as if both enemies were selected.
            var state = pair[1] == "selected"
                ? EnemyTargetSigilState.Selected
                : EnemyTargetSigilState.Hidden;
            sigil.SetState(state);
        }
    }

    // Mirrors authoritative native combat life state into Unity's visual-only
    // actors. Entries use "battle-enemy-id=visible|hidden|retreat|subdued".
    public void SetChapterThirtyMission(string number)
    {
        if (!int.TryParse(number, out int mission) || mission < 16 || mission > 30) throw new ArgumentException("Invalid late chapter mission");
        var battle = FindFirstObjectByType<BattlePrototype>();
        if (!battle || !battle.IsPresentationReady) { pendingActions.Enqueue("chapter-thirty:" + number); return; }
        Apply("chapter-thirty:" + number, battle);
    }

    public void SetEnemyVisibility(string payload)
    {
        var battle = FindFirstObjectByType<BattlePrototype>();
        if (battle == null || !battle.IsPresentationReady) { pendingVisibilityPayload = payload; return; }
        if (string.IsNullOrWhiteSpace(payload))
            return;

        var handles = FindObjectsByType<EnemyHandle>(
            FindObjectsInactive.Include,
            FindObjectsSortMode.None);
        var entries = payload.Split(';');
        for (var entryIndex = 0; entryIndex < entries.Length; entryIndex++)
        {
            var pair = entries[entryIndex].Split('=');
            if (pair.Length != 2)
                continue;
            var handle = FindPresentedHandle(handles, pair[0], battle);
            if (handle == null || handle.EnemyRoot == null || !battle.BelongsToCurrentEncounter(handle))
                continue;
            var subdued = handle.EnemyRoot.GetComponent<EnemySubduedPresentation>();
            if (pair[1] == "subdued")
            {
                var aliveRoot = handle.EnemyRoot;
                if (exits.TryGetValue(aliveRoot, out var pendingExit)) { StopCoroutine(pendingExit); exits.Remove(aliveRoot); }
                RestoreExitMaterials(aliveRoot);
                aliveRoot.gameObject.SetActive(true);
                if (!subdued) subdued = aliveRoot.gameObject.AddComponent<EnemySubduedPresentation>();
                if (!subdued.IsSubdued)
                {
                    battle.CancelDepartingEnemy(handle);
                    battle.GetComponent<ArchiveEncounterPresentation>()?.ClearActor(aliveRoot);
                    aliveRoot.GetComponent<ChronarchPresentation20260916>()?.Cancel();
                    aliveRoot.GetComponent<HeavyArchivePresentation20260916>()?.Cancel();
                aliveRoot.GetComponent<StonehidePresentation20260917>()?.Cancel();
                aliveRoot.GetComponent<ChurchDemonPresentation20260917>()?.Cancel();
                aliveRoot.GetComponent<BountyIdentityPresentation20260917>()?.Cancel();
                aliveRoot.GetComponent<TowerHoundPresentation20260917>()?.Cancel();
                    aliveRoot.GetComponent<StoryEnemyPresentation20260916>()?.Cancel();
                    aliveRoot.GetComponent<SignatureEnemyPresentation>()?.Cancel();
                    RestoreEnemyIdle(aliveRoot);
                    handle.GetComponent<EarlyEnemyIdlePresence>()?.SetDead(false);
                    subdued.Begin();
                }
                handle.TargetAnchor?.GetComponent<EnemyTargetSigil>()?.SetState(EnemyTargetSigilState.Hidden);
                continue;
            }
            bool returningFromSubdued = subdued && subdued.IsSubdued;
            if (subdued) subdued.Clear();
            var shouldShow = pair[1] == "visible";
            handle.GetComponent<EarlyEnemyIdlePresence>()?.SetDead(!shouldShow);
            if (!shouldShow)
            {
                battle.CancelDepartingEnemy(handle);
                battle.GetComponent<ArchiveEncounterPresentation>()?.ClearActor(handle.EnemyRoot);
                handle.GetComponent<EnemyImpactFeedback>()?.BeginDeath();
                handle.GetComponent<StoryEnemyPresentation20260916>()?.Cancel();
                handle.GetComponent<ChronarchPresentation20260916>()?.Cancel();
                handle.GetComponent<HeavyArchivePresentation20260916>()?.Cancel();
                handle.GetComponent<StonehidePresentation20260917>()?.Cancel();
                handle.GetComponent<ChurchDemonPresentation20260917>()?.Cancel();
                handle.GetComponent<BountyIdentityPresentation20260917>()?.Cancel();
                handle.GetComponent<TowerHoundPresentation20260917>()?.Cancel();
                FindFirstObjectByType<BattlePrototype>()?.ClearEncorePresentation();
                handle.TargetAnchor?.GetComponent<EnemyTargetSigil>()
                    ?.SetState(EnemyTargetSigilState.Hidden);
            }
            var root = handle.EnemyRoot;
            if (shouldShow)
            {
                bool returningFromExit = returningFromSubdued || exits.ContainsKey(root) || !root.gameObject.activeSelf;
                if (exits.TryGetValue(root, out var exit)) { StopCoroutine(exit); exits.Remove(root); }
                RestoreExitMaterials(root);
                if (originalPositions.TryGetValue(root, out var position)) root.localPosition = position;
                if (originalRotations.TryGetValue(root, out var rotation)) root.localRotation = rotation;
                root.gameObject.SetActive(true);
                if (returningFromExit) RestoreEnemyIdle(root);
            }
            else if (root.gameObject.activeSelf && !exits.ContainsKey(root))
            {
                originalPositions[root] = root.localPosition;
                originalRotations[root] = root.localRotation;
                exits[root] = StartCoroutine(PresentExit(root, pair[1] == "retreat"));
            }
        }
    }

    static void RestoreEnemyIdle(Transform root)
    {
        root.GetComponent<EnemyImpactFeedback>()?.Clear();
        root.GetComponent<SignatureEnemyPresentation>()?.Cancel();
        root.GetComponent<StoryEnemyPresentation20260916>()?.Cancel();
        root.GetComponent<ChronarchPresentation20260916>()?.Cancel();
        root.GetComponent<HeavyArchivePresentation20260916>()?.Cancel();
                root.GetComponent<StonehidePresentation20260917>()?.Cancel();
                root.GetComponent<ChurchDemonPresentation20260917>()?.Cancel();
                root.GetComponent<BountyIdentityPresentation20260917>()?.Cancel();
                root.GetComponent<TowerHoundPresentation20260917>()?.Cancel();
        foreach (var leech in root.GetComponentsInChildren<MemoryLeechPresentation>()) leech.RestoreIdle();
        foreach (var animator in root.GetComponentsInChildren<Animator>())
        {
            if (animator.runtimeAnimatorController == null) continue;
            foreach (var parameter in animator.parameters)
                if (parameter.type == AnimatorControllerParameterType.Trigger) animator.ResetTrigger(parameter.name);
            foreach (var state in new[] { "EmeraldIdle", "Meshy · Idle", "Idle", "Walking Hold" })
                if (animator.HasState(0, Animator.StringToHash(state)))
                { animator.speed = 1; animator.CrossFadeInFixedTime(state, .12f); break; }
        }
    }

    static EnemyHandle FindPresentedHandle(EnemyHandle[] handles, string identity, BattlePrototype battle)
    {
        // A reused secondary identity may also exist on a hidden template.
        // Visibility commands must address the current wave's active clone.
        return Array.Find(handles, h => h.BattleEnemyId == identity && battle.BelongsToCurrentEncounter(h) && h.gameObject.activeInHierarchy)
            ?? Array.Find(handles, h => h.BattleEnemyId == identity && battle.BelongsToCurrentEncounter(h));
    }

    IEnumerator PresentExit(Transform root, bool retreat)
    {
        var signature = root.GetComponent<SignatureEnemyPresentation>();
        if (signature) { signature.Cancel(); signature.PlayState(retreat ? "Meshy \u00b7 Idle" : "Death"); }
        var chronarch = root.GetComponent<ChronarchPresentation20260916>();
        var heavy = root.GetComponent<HeavyArchivePresentation20260916>();
        if (retreat) { chronarch?.BeginRetreat(); heavy?.BeginRetreat(); }
        var leech = root.GetComponentInChildren<MemoryLeechPresentation>();
        if (leech != null && !retreat) {
            yield return leech.Die();

        }
        var start = root.localPosition;
        var direction = -root.forward;
        var animator = root.GetComponentInChildren<Animator>();
        // Authored generic controllers expose Death as a state, not necessarily a trigger.
        if (!retreat && animator && animator.HasState(0, Animator.StringToHash("Death")))
            animator.CrossFadeInFixedTime("Death", .06f, 0, 0);
        if (animator != null)
            foreach (var parameter in animator.parameters)
                if (parameter.type == AnimatorControllerParameterType.Trigger && parameter.name == (retreat ? "Walk" : "Death"))
                    animator.SetTrigger(parameter.name);
        if (retreat && !chronarch) root.Rotate(0, 180, 0);
        // Use compiled transparent variants, rather than enabling Standard keywords
        // that may have been stripped from a device build.
        var state = new ExitMaterials(root);
        exitMaterials[root] = state;
        try {
            float elapsed = 0;
            while (elapsed < 1f && root && root.gameObject.activeInHierarchy) {
                elapsed += Time.deltaTime;
                state.SetOpacity(1f - Mathf.Clamp01(elapsed));
                if (leech == null && retreat)
                    root.localPosition = start + direction * 1.6f * Mathf.SmoothStep(0, 1, elapsed);
                yield return null;
            }
            if (root) root.gameObject.SetActive(false);
        } finally {
            RestoreExitMaterials(root);
        }
        exits.Remove(root);
    }

    void RestoreExitMaterials(Transform root)
    {
        if (exitMaterials.TryGetValue(root, out var materials)) {
            materials.Restore(); exitMaterials.Remove(root);
        }
    }

    sealed class ExitMaterials
    {
        readonly Dictionary<Renderer, Material[]> originals = new Dictionary<Renderer, Material[]>();
        readonly List<Material> copies = new List<Material>();
        readonly List<Color> colors = new List<Color>();
        readonly List<float> opacities = new List<float>();
        public ExitMaterials(Transform root)
        {
            foreach (var renderer in root.GetComponentsInChildren<Renderer>()) {
                if (!renderer.enabled) continue;
                var source = renderer.sharedMaterials;
                originals[renderer] = source;
                var replacements = new Material[source.Length];
                for (int i = 0; i < source.Length; i++) {
                    if (!source[i]) continue;
                    var material = new Material(source[i]);
                    string shaderName = material.shader ? material.shader.name : "";
                    if (shaderName == "Mistport/Character Surface 20260916") {
                        material.shader = Resources.Load<Shader>("Shaders/CharacterSurfaceRefinement20260916Fade");
                        material.SetFloat("_ExitOpacity", 1);
                    } else if (shaderName == "Mistport/BountyIdentity") {
                        material.shader=Resources.Load<Shader>("Shaders/BountyIdentityFade");material.SetFloat("_ExitOpacity",1);
                    } else if (shaderName == "Standard") {
                        bool metallic = material.IsKeywordEnabled("_METALLICGLOSSMAP");
                        bool emission = material.IsKeywordEnabled("_EMISSION");
                        bool normal = material.IsKeywordEnabled("_NORMALMAP");
                        bool cutout = material.IsKeywordEnabled("_ALPHATEST_ON");
                        material.shader = Resources.Load<Shader>("Shaders/EnemyStandardFade");
                        material.SetFloat("_ExitMetallicMap", metallic ? 1 : 0);
                        material.SetFloat("_ExitEmission", emission ? 1 : 0);
                        material.SetFloat("_ExitNormal", normal ? 1 : 0);
                        material.SetFloat("_ExitCutout", cutout ? 1 : 0);
                        material.SetFloat("_ExitOpacity", 1);
                    } else if (shaderName == "Mindstone/Memory Leech GLTF") {
                        material.shader = Resources.Load<Shader>("Shaders/MemoryLeechGLTFFade");
                    }
                    replacements[i] = material;
                    copies.Add(material);
                    colors.Add(material.HasProperty("_Color") ? material.GetColor("_Color") : Color.white);
                    opacities.Add(material.HasProperty("_Opacity") ? material.GetFloat("_Opacity") : 1f);
                    Debug.Log($"ENEMY_EXIT_MATERIAL {root.name} {shaderName} -> {material.shader.name}");
                }
                renderer.sharedMaterials = replacements;
            }
        }
        public void SetOpacity(float opacity)
        {
            for (int i = 0; i < copies.Count; i++) {
                var material = copies[i];
                if (!material) continue;
                if (material.HasProperty("_ExitOpacity")) material.SetFloat("_ExitOpacity", opacity);
                else if (material.HasProperty("_Opacity")) material.SetFloat("_Opacity", opacities[i] * opacity);
                else if (material.HasProperty("_Color")) {
                    var color = colors[i]; color.a *= opacity; material.SetColor("_Color", color);
                }
            }
        }
        public void Restore()
        {
            foreach (var pair in originals) if (pair.Key) pair.Key.sharedMaterials = pair.Value;
            foreach (var material in copies) if (material) UnityEngine.Object.Destroy(material);
            originals.Clear(); copies.Clear(); colors.Clear(); opacities.Clear();
        }
    }

    void Update()
    {
        var battle = FindFirstObjectByType<BattlePrototype>();
        if (battle == null || !battle.IsPresentationReady) return;
        // Framework attachment is earlier than scene installation on a cold
        // device. Replay controls in order, including the final stop/start.
        while (pendingActions.Count > 0) Apply(pendingActions.Dequeue(), battle);
        if (pendingTargetPayload != null) {
            var payload = pendingTargetPayload; pendingTargetPayload = null;
            SetTargetSigils(payload);
        }
        if (pendingVisibilityPayload != null) {
            var payload = pendingVisibilityPayload; pendingVisibilityPayload = null;
            SetEnemyVisibility(payload);
        }

        if (Time.unscaledTime >= nextAnchorReportTime)
        {
            nextAnchorReportTime = Time.unscaledTime + AnchorReportInterval;
            ReportEnemyHealthAnchors();
            ReportBattleEffectAnchors();
        }
    }

    void ReportEnemyHealthAnchors()
    {
        var camera = Camera.main;
        if (camera == null) return;

        var handles = FindObjectsByType<EnemyHandle>(
            FindObjectsInactive.Exclude,
            FindObjectsSortMode.None);
        var entries = new List<string>();
        for (var index = 0; index < handles.Length; index++)
        {
            var handle = handles[index];
            if (handle == null
                || string.IsNullOrEmpty(handle.BattleEnemyId)
                || handle.HealthBarAnchor == null
                || !handle.EnemyRoot.gameObject.activeInHierarchy)
                continue;

            var viewport = camera.WorldToViewportPoint(handle.HealthBarAnchor.position);
            if (viewport.z <= 0f) continue;
            entries.Add(
                $"{handle.BattleEnemyId},{viewport.x.ToString("F4", CultureInfo.InvariantCulture)},{viewport.y.ToString("F4", CultureInfo.InvariantCulture)}");
        }

        if (entries.Count > 0)
            Report("enemy-health-anchors", string.Join(";", entries));
    }

    // Native SpriteKit VFX is composited over Unity on iOS. Report the actual
    // rig anchors every frame interval so a mouth-origin effect follows a
    // moving model rather than depending on hand-tuned screen coordinates.
    void ReportBattleEffectAnchors()
    {
        var camera = Camera.main;
        var battle = FindFirstObjectByType<BattlePrototype>();
        if (camera == null || battle == null) return;

        var entries = new List<string>();
        var handles = FindObjectsByType<EnemyHandle>(
            FindObjectsInactive.Exclude,
            FindObjectsSortMode.None);
        for (var index = 0; index < handles.Length; index++)
        {
            var handle = handles[index];
            if (handle == null
                || string.IsNullOrEmpty(handle.BattleEnemyId)
                || handle.EnemyRoot == null
                || handle.EffectAnchor == null
                || !handle.EnemyRoot.gameObject.activeInHierarchy)
                continue;

            var effectPosition = handle.BattleEnemyId == EnemyBattleIds.HellHoundPrimary
                ? battle.HellHoundFireBreathSourceAnchor
                : handle.EffectAnchor.position;
            var viewport = camera.WorldToViewportPoint(effectPosition);
            if (viewport.z <= 0f) continue;
            entries.Add(
                $"{handle.BattleEnemyId},{viewport.x.ToString("F4", CultureInfo.InvariantCulture)},{viewport.y.ToString("F4", CultureInfo.InvariantCulture)}");
        }

        var playerViewport = camera.WorldToViewportPoint(battle.PlayerFireBreathImpactAnchor);
        if (playerViewport.z > 0f)
        {
            entries.Add(
                $"player-primary,{playerViewport.x.ToString("F4", CultureInfo.InvariantCulture)},{playerViewport.y.ToString("F4", CultureInfo.InvariantCulture)}");
        }

        var playerHealthViewport = camera.WorldToViewportPoint(battle.PlayerHealthAnchor);
        if (playerHealthViewport.z > 0f)
        {
            entries.Add(
                $"player-health,{playerHealthViewport.x.ToString("F4", CultureInfo.InvariantCulture)},{playerHealthViewport.y.ToString("F4", CultureInfo.InvariantCulture)}");
        }

        if (entries.Count > 0)
            Report("battle-effect-anchors", string.Join(";", entries));
    }

    public void ResetEnemyExitPresentation()
    {
        FindFirstObjectByType<BattlePrototype>()?.ClearPlayerImpact(true);
        foreach (var impact in FindObjectsByType<EnemyImpactFeedback>(FindObjectsInactive.Include, FindObjectsSortMode.None)) impact.Clear();
        // Exit poses belong to the previous encounter. Restore them before
        // the next formation places actors, then discard the old baselines.
        foreach (var routine in exits.Values) StopCoroutine(routine);
        exits.Clear();
        foreach (var materials in exitMaterials.Values) materials.Restore();
        exitMaterials.Clear();
        foreach (var pair in originalPositions) if (pair.Key) pair.Key.localPosition = pair.Value;
        foreach (var pair in originalRotations) if (pair.Key) pair.Key.localRotation = pair.Value;
        originalPositions.Clear();
        originalRotations.Clear();
        foreach (var idle in FindObjectsByType<EarlyEnemyIdlePresence>(FindObjectsInactive.Include, FindObjectsSortMode.None))
            idle.SetDead(false);
    }

    void OnDisable() => ResetEnemyExitPresentation();

    void Apply(string action, BattlePrototype battle)
    {
        if (action.StartsWith("player-impact-context:", StringComparison.Ordinal)) { battle.BeginPlayerImpactContext(action.Substring("player-impact-context:".Length)); return; }
        if (action.StartsWith("player-impact:", StringComparison.Ordinal)) { battle.PresentPlayerImpact(action.Substring("player-impact:".Length)); return; }
        if (action.StartsWith("audio-volume:", StringComparison.Ordinal)) {
            if (float.TryParse(action.Substring("audio-volume:".Length), NumberStyles.Float, CultureInfo.InvariantCulture, out var volume))
            {
                SpellAudioDirector20260924.SetVolume(volume);
                // Zero means silent everywhere: enemy, hit and Effekseer sounds do not
                // go through the spell director (a muted review still played them).
                AudioListener.volume = volume <= 0f ? 0f : 1f;
            }
            return;
        }
        if(action.StartsWith("church-status:")){ChurchStatusPresentation20260917.Get(battle).Apply(action.Substring("church-status:".Length));return;}
        if (action.StartsWith("church-tower:")) {
            ChurchStatusPresentation20260917.Get(battle).Clear();
            ResetEnemyExitPresentation();
            battle.SetChurchTowerBackground(true);
            battle.RequestWaveInstances(action.Substring("church-tower:".Length));
            return;
        }
        if (action.StartsWith("chapter-thirty:")) { battle.ClearPlayerImpact(true); battle.SetChurchTowerBackground(false); }
        if (action.StartsWith("wave-instances:") || action == "puppet-core" || action == "hound-escort"
            || action == "core-escort" || action == "leech-escort" || action == "clock-core"
            || action == "clock-guard" || action == "dual-clock-guard"
            || action == "hell-hound" || action == "early-hell-hound" || action == "hell-hound-pounce")
        {
            ResetEnemyExitPresentation();
            battle.SetChurchTowerBackground(false);
        }
        if (action.StartsWith("wave-instances:")) { ChurchStatusPresentation20260917.Get(battle).Clear(); battle.RequestWaveInstances(action.Substring("wave-instances:".Length)); return; }
        if (action.StartsWith("archive-state:")) { battle.SetArchivePhase(action.Substring("archive-state:".Length)); return; }
        if (action.StartsWith("leech-charge:")) { battle.SetLeechCharge(action.Substring("leech-charge:".Length)); return; }
        if (action.StartsWith("skill-targets:")) { battle.SetSkillTargets(action.Substring("skill-targets:".Length)); return; }
        if (action.StartsWith("sidestep-secondary:")) { battle.SetSidestepSecondary(action.Substring("sidestep-secondary:".Length)); return; }
        if (action.StartsWith("enemy-heal:")) { battle.PresentEnemyHealing(action.Substring("enemy-heal:".Length)); return; }
        if (action.StartsWith("enemy-impact:")) { battle.PresentEnemyImpact(action.Substring("enemy-impact:".Length)); return; }
        if (action.StartsWith("q4-hound:")) { battle.SetQ4HoundPhase(action.Substring("q4-hound:".Length)); return; }
        if (action == "tempo-mask") { CombatTempoPresentation.Get(battle).MaskCast(); return; }
        if (action.StartsWith("combat-speed:")) { battle.SetCombatSpeed(action.Substring("combat-speed:".Length)); return; }
        if (action.StartsWith("tempo-sample:")) { battle.SetTempoSample(action.Substring("tempo-sample:".Length)); return; }
        if (action.StartsWith("hero-outfit:")) { CombatTempoPresentation.Get(battle).SetOutfit(action.Substring("hero-outfit:".Length)); return; }
        if (action.StartsWith("enemy-light:")) { CombatTempoPresentation.Get(battle).Light(action.Substring("enemy-light:".Length)); return; }
        if (action.StartsWith("light-contact:")) { CombatTempoPresentation.Get(battle).LightContact(action.Substring("light-contact:".Length)); return; }
        if (action.StartsWith("light-cancel:")) { CombatTempoPresentation.Get(battle).CancelLight(action.Substring("light-cancel:".Length)); return; }
        if (action == "combat-start") { battle.SetNativeCombatEnabled(true); return; }
        if (action == "combat-stop") { ChurchStatusPresentation20260917.Get(battle).Clear(); battle.SetNativeCombatEnabled(false); return; }
        if (!battle.NativeCombatEnabled &&
            (action == "basic" || action.StartsWith("basic:") || action == "skill" || action.StartsWith("skill:") ||
             action == "defend" || action == "enemy" || action.StartsWith("enemy:"))) return;
        if (action.StartsWith("chapter-thirty:")) { battle.ConfigureChapterThirtyMission(action.Substring("chapter-thirty:".Length)); return; }
        if (action.StartsWith("early-presence:")) { battle.SetEarlyBattlePresence(action.Substring("early-presence:".Length)); return; }
        switch (action)
        {
            case "puppet-core": battle.UseLateEscort(false); break;
            case "hound-escort": battle.UseLateEscort(true); break;
            case "core-escort": battle.UseP1Escort(false); break;
            case "leech-escort": battle.UseP1Escort(true); break;
            case "clock-core":
                battle.UseClockCoreModel();
                break;
            case "clock-guard":
                battle.UseClockGuardModel();
                break;
            case "dual-clock-guard":
                battle.UseDualClockGuardModel();
                break;
            case "early-hell-hound":
                battle.UseEarlyHellHoundModel();
                break;
            case "hell-hound":
                battle.UseHellHoundModel();
                break;
            case "hell-hound-pounce":
                battle.UseHellHoundPounceModel();
                break;
            case "clock-core-cast":
                battle.PresentClockCoreCast();
                break;
            case "basic":
                battle.PresentPlayerBasic();
                break;
            case "skill":
                battle.PresentPlayerSkill();
                break;
            case "defend":
                battle.PresentPlayerDefense();
                break;
            case "enemy":
                battle.PresentEnemyAttack();
                break;
            case "player-defeated":
                battle.PresentPlayerDefeat();
                break;
            case "player-reset":
                battle.ClearEncorePresentation();
                battle.ResetPlayerPresentation();
                break;
            case "guardian-ward-break":
                foreach (var ward in UnityEngine.Object.FindObjectsByType<Mindstone.VFXV1.GuardianWard>(FindObjectsSortMode.None)) ward.Break();
                break;
            case "paper-double-break":
                battle.PresentPaperRelicProtection();
                break;
            case "paper-double-ready":
                battle.ArmPaperDouble();
                break;
            case "encore-model-on":
                battle.SetEncoreRevenant(true);
                break;
            case "encore-model-off":
                battle.SetEncoreRevenant(false);
                break;
            case "encore-charge":
                battle.PresentEncoreCharge();
                break;
            case "encore-bell":
                battle.PresentEncoreBell();
                break;
            case "encore-release":
                battle.PresentEncoreRelease();
                break;
            case "encore-clear":
                battle.ClearEncorePresentation();
                break;
            default:
                if(action.StartsWith("emerald-spell:", StringComparison.Ordinal)) { battle.SetEmeraldSpell(action.Substring(14)); break; }
                if(action.StartsWith("emerald-poison:", StringComparison.Ordinal) && int.TryParse(action.Substring(15), out var poisonRemaining)) { battle.SetEmeraldPoison(poisonRemaining); break; }
                if (action.StartsWith("masquerade:", StringComparison.Ordinal) && int.TryParse(action.Substring(11), out var charges)) {
                    battle.SetMasquerade(charges, false); break;
                }
                if (action.StartsWith("masquerade-hit:", StringComparison.Ordinal) && int.TryParse(action.Substring(15), out var remaining)) {
                    battle.SetMasquerade(remaining, true); break;
                }
                if (action.StartsWith("player-position:", StringComparison.Ordinal))
                {
                    battle.SetPlayerScreenPlacement(action.Substring("player-position:".Length));
                    break;
                }
                if (action.StartsWith("enemy:", StringComparison.Ordinal))
                {
                    battle.PresentEnemyAttack(action.Substring("enemy:".Length));
                    break;
                }
                if (action.StartsWith("basic:", StringComparison.Ordinal))
                {
                    battle.PresentPlayerBasic(action.Substring("basic:".Length));
                    break;
                }
                if (action.StartsWith("skill:", StringComparison.Ordinal))
                {
                    battle.PresentPlayerSkill(action.Substring("skill:".Length));
                    break;
                }
                Report("error", $"unknown-action:{action}");
                return;
        }
        Report("accepted", action);
    }

    static void Report(string eventName, string value)
    {
        var json = $"{{\"eventName\":\"{Escape(eventName)}\",\"value\":\"{Escape(value)}\"}}";
#if UNITY_IOS && !UNITY_EDITOR
        MistportUnityBattleEvent(json);
#else
        Debug.Log($"Mistport bridge: {json}");
#endif
    }

    /// Signals that a presentation coroutine has reached its final pose.
    /// Native code uses this event only for visual sequencing; combat state
    /// remains authoritative in MistportCombatCore.
    public static void ReportCombatContact(string actor)
    {
        if (actor != null && !actor.StartsWith("enemy-cancel:", StringComparison.Ordinal))
        {
            SpellAudioDirector20260924.Contact(actor);
            SpellSpectacle20260926.Contact(actor);
        }
        Report("combat-contact", actor);
    }

    public static void ReportPresentationComplete(string action) =>
        Report("presentation-complete", action);

    /// Emits authored contact beats for native VFX composited over Unity.
    /// Native code must react to these markers instead of estimating where
    /// the moving 3D actor is from wall-clock delays.
    public static void ReportPresentationPhase(string phase) =>
        Report("presentation-phase", phase);

    static string ExtractAction(string json)
    {
        if (string.IsNullOrEmpty(json)) return "";

        // Native sends a JSON action such as
        // {"action":"enemy:hell-hound-primary"}. Parse the action field
        // before looking for model names. The old substring fallback saw
        // "hell-hound" inside the enemy battle ID and converted an enemy
        // attack into a model-selection command, so no attack coroutine (or
        // presentation-complete event) ever ran.
        const string actionKey = "\"action\":\"";
        var actionStart = json.IndexOf(actionKey, StringComparison.Ordinal);
        if (actionStart >= 0)
        {
            var valueStart = actionStart + actionKey.Length;
            var valueEnd = json.IndexOf('"', valueStart);
            if (valueEnd > valueStart)
                return json.Substring(valueStart, valueEnd - valueStart);
        }

        if (json.Contains("player-defeated")) return "player-defeated";
        if (json.Contains("player-reset")) return "player-reset";
        if (json.Contains("encore-model-on")) return "encore-model-on";
        if (json.Contains("encore-model-off")) return "encore-model-off";
        if (json.Contains("encore-charge")) return "encore-charge";
        if (json.Contains("encore-bell")) return "encore-bell";
        if (json.Contains("encore-release")) return "encore-release";
        if (json.Contains("encore-clear")) return "encore-clear";
        if (json.Contains("clock-core-cast")) return "clock-core-cast";
        if (json.Contains("clock-core") || json.Contains("clockCore")) return "clock-core";
        if (json.Contains("dual-clock-guard")) return "dual-clock-guard";
        if (json.Contains("clock-guard") || json.Contains("clockGuard")) return "clock-guard";
        if (json.Contains("hell-hound-pounce")) return "hell-hound-pounce";
        if (json.Contains("hell-hound") || json.Contains("hellHound")) return "hell-hound";
        if (json.Contains("\"basic\"")) return "basic";
        var skillPrefix = json.IndexOf("skill:", StringComparison.Ordinal);
        if (skillPrefix >= 0)
        {
            var skillEnd = json.IndexOf('"', skillPrefix);
            return skillEnd > skillPrefix
                ? json.Substring(skillPrefix, skillEnd - skillPrefix)
                : json.Substring(skillPrefix).Trim().Trim('"', '}');
        }
        if (json.Contains("\"skill\"")) return "skill";
        if (json.Contains("\"defend\"")) return "defend";
        if (json.Contains("\"enemy\"")) return "enemy";
        return json.Trim().Trim('"');
    }

    static string Escape(string value) =>
        (value ?? "").Replace("\\", "\\\\").Replace("\"", "\\\"");

#if UNITY_IOS && !UNITY_EDITOR
    [DllImport("__Internal")]
    static extern void MistportUnityBattleEvent(string json);
#endif
}
