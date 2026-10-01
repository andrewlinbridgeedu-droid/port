using System;
using System.Collections;
using System.Collections.Generic;
using System.Globalization;
using UnityEngine;

// Opted in by the native encounter ID, never by a model name alone.
[DefaultExecutionOrder(30000)]
public sealed class CombatTempoPresentation : MonoBehaviour
{
    public bool Enabled { get; private set; }
    public bool HoundBodyOnly { get; private set; }
    BattlePrototype battle;
    int generation, basicVariation;
    string encounter;
    Entry hero;
    readonly Dictionary<string, Entry> enemies = new Dictionary<string, Entry>();
    sealed class Entry {
        public Transform original;
        public EnemyHandle handle;
        public Transform previousModel, replacement;
        public CombatTempoAnimatedBody body;
        public Animator oldAnimator;
        public bool animatorEnabled;
        public EarlyEnemyIdlePresence oldIdle;
        public bool idleEnabled;
        public int epoch;
        public CombatTempoVFX warning;
        public readonly List<(Renderer renderer, bool enabled)> renderers = new List<(Renderer, bool)>();
        public bool retainHeroArt;
        public HeroLivingIdle20260916 oldHeroIdle;
        public bool heroIdleEnabled;
        public readonly List<Renderer> driverRenderers = new List<Renderer>();
        public readonly List<(Transform original, Transform driver, Vector3 position, Quaternion rotation, Vector3 scale)> heroBones = new List<(Transform, Transform, Vector3, Quaternion, Vector3)>();
    }
    public static CombatTempoPresentation Get(BattlePrototype battle)
    {
        var p = battle.GetComponent<CombatTempoPresentation>() ?? battle.gameObject.AddComponent<CombatTempoPresentation>();
        p.battle = battle; return p;
    }
    public void Configure(string id)
    {
        if (encounter == id) { InstallBodies(); return; }
        Clear(); encounter = id;
        Enabled = id == "chapter01_q04_encounter" || id == "church_tower_001" || id == "church_bounty_b01";
        HoundBodyOnly = id == "chapter01_q03_encounter";
        InstallBodies();
    }
    void LateUpdate() {
        if (!(Enabled || HoundBodyOnly)) return;
        InstallBodies();
        // Legacy reset paths can restore their cached Renderer flags mid-fight.
        // The Blender rig owns poses. The hero keeps the original tailored
        // mesh, face and cloth skins, driven by those poses rather than replaced.
        foreach (var e in enemies.Values) HideOriginal(e);
        HideOriginal(hero);
    }
    static void HideOriginal(Entry e) {
        if (e == null || !e.body) return;
        if (e.retainHeroArt) {
            foreach (var r in e.driverRenderers) if (r) r.enabled = false;
            foreach (var pair in e.heroBones) if (pair.original && pair.driver) {
                pair.original.SetPositionAndRotation(pair.driver.position, pair.driver.rotation);
            }
        } else foreach (var item in e.renderers) if (item.renderer) item.renderer.enabled = false;
        if (e.oldAnimator) e.oldAnimator.enabled = false;
    }
    void InstallBodies()
    {
        if (!battle || !(Enabled || HoundBodyOnly)) return;
        if (hero != null && !hero.body) { Restore(hero); hero = null; }
        foreach (var key in new List<string>(enemies.Keys)) {
            var e = enemies[key]; if (!e.body || !e.handle || !e.handle.gameObject.activeInHierarchy || e.handle.Model != e.replacement) { Restore(e); enemies.Remove(key); }
        }
        foreach (var h in battle.TempoSampleEnemies) {
            if (!h || !h.gameObject.activeInHierarchy || enemies.ContainsKey(h.BattleEnemyId)) continue;
            var kind = h.ProfileEnemyId == "early-hell-hound" ? "Hound" : h.ProfileEnemyId == "stonehide" ? "Stonejaw" : h.ProfileEnemyId == "bounty-b01" ? "Hollow" : null;
            if (kind == null || HoundBodyOnly && kind != "Hound") continue;
            var e = Replace(h.Model, kind, battle.TempoSamplePlayer, h);
            if (e != null) {
                enemies[h.BattleEnemyId] = e;
                e.body.WalkingBetweenActions = kind == "Hound";
                e.body.Idle();
                e.oldIdle = h.GetComponent<EarlyEnemyIdlePresence>();
                if (e.oldIdle) { e.idleEnabled = e.oldIdle.enabled; e.oldIdle.SuspendForAction(); e.oldIdle.enabled = false; }
                h.GetComponent<MainlineBodyRound2>()?.Stop();
            }
        }
        if (Enabled && hero == null && battle.TempoSamplePlayer) {
            var a = battle.TempoSamplePlayer.GetComponentInChildren<Animator>(true);
            if (a) hero = Replace(battle.TempoSamplePlayer, "Hero", FirstEnemy(), null);
        }
    }
    Transform FirstEnemy() { foreach (var h in battle.TempoSampleEnemies) if (h && h.gameObject.activeInHierarchy) return h.EnemyRoot; return null; }
    static bool BoundsOf(Transform root, out Bounds bounds) {
        bounds = default; bool found = false;
        foreach (var r in root.GetComponentsInChildren<Renderer>(false)) {
            if (!r.enabled || r is ParticleSystemRenderer || r is LineRenderer) continue;
            if (!found) { bounds = r.bounds; found = true; } else bounds.Encapsulate(r.bounds);
        }
        return found;
    }
    Entry Replace(Transform original, string kind, Transform target, EnemyHandle handle)
    {
        var prefab = Resources.Load<GameObject>("CombatTempo/Animation/" + kind);
        if (!original || !prefab || !BoundsOf(original, out var before)) return null;
        var e = new Entry { original = original, handle = handle, previousModel = handle ? handle.Model : null };
        var skins = original.GetComponentsInChildren<SkinnedMeshRenderer>(false);
        var originalBones = new HashSet<Transform>();
        foreach (var skin in skins) foreach (var bone in skin.bones) if (bone) originalBones.Add(bone);
        var materials = skins.Length > 0 ? skins[0].sharedMaterials : Array.Empty<Material>();
        foreach (var r in original.GetComponentsInChildren<Renderer>(false)) {
            if (r is ParticleSystemRenderer || r is LineRenderer) continue;
            e.renderers.Add((r, r.enabled)); r.enabled = false;
        }
        e.oldAnimator = original.GetComponentInChildren<Animator>(true);
        if (e.oldAnimator) { e.animatorEnabled = e.oldAnimator.enabled; e.oldAnimator.enabled = false; }
        var model = Instantiate(prefab, original, false); model.name = "Blender " + kind + " sample";
        // Imported FBX remains an intact skin/rig, including the new jaw and coat.
        foreach (var skin in model.GetComponentsInChildren<SkinnedMeshRenderer>()) if (materials.Length > 0) skin.sharedMaterials = materials;
        if (BoundsOf(model.transform, out var after) && after.size.y > .001f) {
            model.transform.localScale *= before.size.y / after.size.y;
            BoundsOf(model.transform, out after);
            model.transform.position += new Vector3(before.center.x - after.center.x, before.min.y - after.min.y, before.center.z - after.center.z);
        }
        if (kind == "Hero" && e.oldAnimator) {
            // Preserve every authored costume/head renderer and its original
            // bind poses. Transfer the exported action to the existing rig;
            // the imported body skin is hidden, preventing a duplicate body.
            e.retainHeroArt = true;
            e.driverRenderers.AddRange(model.GetComponentsInChildren<Renderer>(true));
            var drivers = model.GetComponentsInChildren<Transform>(true);
            var orderedBones = new List<Transform>(originalBones);
            orderedBones.Sort((a, b) => BoneDepth(a).CompareTo(BoneDepth(b)));
            foreach (var bone in orderedBones) {
                foreach (var driver in drivers) if (driver.name == bone.name) {
                    e.heroBones.Add((bone, driver, bone.localPosition, bone.localRotation, bone.localScale)); break;
                }
            }
            foreach (var item in e.renderers) if (item.renderer) item.renderer.enabled = item.enabled;
            foreach (var r in e.driverRenderers) if (r) r.enabled = false;
            e.oldHeroIdle = original.GetComponentInChildren<HeroLivingIdle20260916>();
            if (e.oldHeroIdle) { e.heroIdleEnabled = e.oldHeroIdle.enabled; e.oldHeroIdle.enabled = false; }
        } else CloneAccessories(e.renderers, model.transform, before.size.y);
        e.replacement = model.transform;
        e.body = CombatTempoAnimatedBody.Install(model, kind, target);
        if (handle) handle.SetTempoPresentationModel(model.transform);
        return e;
    }
    static int BoneDepth(Transform bone) { int depth = 0; for (var p = bone.parent; p; p = p.parent) depth++; return depth; }
    static void CloneAccessories(List<(Renderer renderer, bool enabled)> source, Transform model, float bodyHeight)
    {
        var bones = model.GetComponentsInChildren<Transform>(true);
        foreach (var item in source) {
            if (!item.enabled || !(item.renderer is MeshRenderer r) || r.bounds.size.y > bodyHeight * .65f) continue;
            var filter = r.GetComponent<MeshFilter>(); if (!filter || !filter.sharedMesh) continue;
            Transform parent = r.transform.parent, target = null;
            while (parent && !target) { foreach (var b in bones) if (b.name == parent.name) { target = b; break; } if (!target) parent = parent.parent; }
            if (!target) continue;
            var go = new GameObject("Retained " + r.name); go.transform.SetParent(target, false);
            go.transform.position = r.transform.position; go.transform.rotation = r.transform.rotation;
            var parentScale = target.lossyScale; var scale = r.transform.lossyScale;
            go.transform.localScale = new Vector3(scale.x / parentScale.x, scale.y / parentScale.y, scale.z / parentScale.z);
            go.AddComponent<MeshFilter>().sharedMesh = filter.sharedMesh;
            go.AddComponent<MeshRenderer>().sharedMaterials = r.sharedMaterials;
        }
    }
    public void Light(string payload)
    {
        if (!Enabled || !battle.NativeCombatEnabled) return;
        var parts = payload.Split(':'); if (parts.Length != 2 || !enemies.TryGetValue(parts[0], out var e)) return;
        if (!float.TryParse(parts[1], NumberStyles.Float, CultureInfo.InvariantCulture, out var contact) || contact <= 0 || contact > 1) return;
        e.body.Play("Light", contact);
        var echo = battle.GetComponent<HeroManualMaskRound2>();
        if (echo && echo.IsActive && hero != null && hero.body) hero.body.Play("Parry", contact);
    }
    public void LightContact(string payload)
    {
        if (!Enabled || !battle.NativeCombatEnabled) return;
        var parts = payload.Split(':'); if (parts.Length != 2 || !enemies.TryGetValue(parts[0], out var e)) return;
        bool parried = parts[1] == "1";
        CombatTempoVFX.LightContact(battle.PlayerFireBreathImpactAnchor, e.body.Kind, parried);
        if (parried) { battle.GetComponent<HeroManualMaskRound2>()?.Parry(); }
        else if (hero != null && hero.body) hero.body.ConfirmedHit(false);
    }
    public void CancelActor(EnemyHandle h) {
        foreach (var e in enemies.Values) if (e.handle == h) {
            e.epoch++; if (e.body) e.body.Cancel();
            if (e.warning) { e.warning.gameObject.SetActive(false); Destroy(e.warning.gameObject); e.warning = null; }
        }
    }
    public void CancelLight(string id) { if (enemies.TryGetValue(id, out var e)) e.body.Cancel(); }
    public void Q4Phase(string phase)
    {
        if (!Enabled) return;
        foreach (var e in enemies.Values) if (e.body.Kind == "Hound") {
            if (phase == "clear" || phase == "recover") e.body.Idle();
            else if (phase == "charge") { e.body.Play("HeavyPrepare", 2, true, 0); e.warning = CombatTempoVFX.Telegraph(battle.PlayerFireBreathImpactAnchor, "Hound", 2); }
            else if (phase == "opening") e.body.Play("Opening", 0, false, 0);
            else if (phase == "probe") e.body.Play("Probe", .45f);
            else if (phase == "first" || phase == "second") e.body.Play(phase == "second" ? "HeavyReleaseSecond" : "HeavyRelease", .45f);
        }
    }
    public bool EnemyAction(string payload)
    {
        if (!Enabled || !battle.NativeCombatEnabled) return false;
        var parts = payload.Split(':'); if (!enemies.TryGetValue(parts[0], out var e) || e.body.Kind == "Hound") return false;
        string intent = parts.Length > 1 ? parts[1] : "strike";
        if (intent == "recover") { e.body.Idle(); return true; }
        if (intent.Contains("charge") || intent == "guard") {
            e.body.Play("HeavyPrepare", .65f, true, 0);
            if (intent.Contains("charge")) e.warning = CombatTempoVFX.Telegraph(battle.PlayerFireBreathImpactAnchor, e.body.Kind, 2);
            return true;
        }
        float contact = e.body.Kind == "Stonejaw" ? 1 : .65f;
        StartCoroutine(EnemyStrike(parts[0], e, contact, generation, e.epoch)); return true;
    }
    IEnumerator EnemyStrike(string id, Entry e, float contact, int token, int actorToken)
    {
        e.body.Play("HeavyRelease", contact);
        e.warning = CombatTempoVFX.Telegraph(battle.PlayerFireBreathImpactAnchor, e.body.Kind, contact);
        float elapsed = 0;
        while (elapsed < contact) {
            if (token != generation || actorToken != e.epoch || !e.body || !e.handle || !battle.CanTempoEnemyAct(e.handle) || !battle.NativeCombatEnabled) yield break;
            elapsed += Time.deltaTime; yield return null;
        }
        if (token != generation || actorToken != e.epoch || !e.body || !e.handle || !battle.CanTempoEnemyAct(e.handle) || !battle.NativeCombatEnabled) yield break;
        CombatTempoVFX.HeavyContact(battle.PlayerFireBreathImpactAnchor, e.body.Kind);
        UnityBattleBridge.ReportCombatContact("enemy:" + id);
    }
    public bool PlayerAction(string payload, bool basic)
    {
        if (!Enabled || !battle.NativeCombatEnabled || hero == null) return false;
        var parts = payload.Split(':'); var skill = basic ? "basic" : parts[0];
        if (!basic && skill != "fool_skill_02" && skill != "fool_skill_06" && skill != "fool_skill_07") return false;
        Transform target = parts.Length > 1 && enemies.TryGetValue(parts[1], out var e) ? e.handle.EffectAnchor : FirstEnemy();
        if (!target) return true;
        float contact = basic ? .58f : skill == "fool_skill_02" ? .38f : skill == "fool_skill_06" ? .705f : .885f;
        string clip = basic ? new[] { "BasicSlash", "Thrust", "Card" }[basicVariation++ % 3] : "CastPrepare";
        hero.body.Play(clip, contact, false, 0);
        SpellAudioDirector20260924.BeginPlayer(battle, skill);
        StartCoroutine(PlayerStrike(skill, target, contact, generation)); return true;
    }
    IEnumerator PlayerStrike(string skill, Transform target, float contact, int token)
    {
        var start = battle.TempoSamplePlayer.position + Vector3.up * 1.1f;
        CombatTempoVFX.PlayerSpell(start, target.position, skill, contact, hero?.original);
        for (float t = 0; t < contact; t += Time.deltaTime) { if (token != generation || !battle.NativeCombatEnabled) yield break; yield return null; }
        if (token != generation || !battle.NativeCombatEnabled) yield break;
        UnityBattleBridge.ReportCombatContact("player");
        UnityBattleBridge.ReportPresentationComplete(skill);
    }
    public void MaskCast() {
        if (!Enabled || !battle.NativeCombatEnabled || hero == null || !hero.body) return;
        if (!hero.body.IsActing) hero.body.Play("CastPrepare", .38f, false, 0);
        var target = FirstEnemy(); if (!target) return;
        CombatTempoVFX.PlayerSpell(battle.TempoSamplePlayer.position + Vector3.up * 1.1f,
            target.position + Vector3.up * 1.1f, "fool_skill_02", .38f, hero.body.transform);
        // The native manual defence already settled. No player contact receipt.
    }
    public void HeroCast() { if (Enabled && hero != null) hero.body.Play("CastPrepare", .5f); }
    public bool EnemyHit(EnemyHandle h, string skill) {
        if (!Enabled || !enemies.TryGetValue(h.BattleEnemyId, out var e)) return false;
        e.body.ConfirmedHit(skill == "fool_skill_07" || skill == "fool_skill_10"); return true;
    }
    public void PlayerHit() { if (Enabled) hero?.body.ConfirmedHit(false); }
    static void Restore(Entry e) {
        if (e == null) return;
        foreach (var pair in e.heroBones) if (pair.original) {
            pair.original.localPosition = pair.position; pair.original.localRotation = pair.rotation; pair.original.localScale = pair.scale;
        }
        if (e.body) { e.body.Cancel(); e.body.gameObject.SetActive(false); Destroy(e.body.gameObject); }
        foreach (var item in e.renderers) if (item.renderer) item.renderer.enabled = item.enabled;
        if (e.oldAnimator) e.oldAnimator.enabled = e.animatorEnabled;
        if (e.oldHeroIdle) e.oldHeroIdle.enabled = e.heroIdleEnabled;
        if (e.handle) { if (e.handle.Model == e.replacement) e.handle.SetTempoPresentationModel(e.previousModel); if (e.oldIdle) { e.oldIdle.enabled = e.idleEnabled; e.oldIdle.ResumeIdle(); } }
    }
    public void Cancel()
    {
        generation++; StopAllCoroutines(); foreach (var e in enemies.Values) if (e.body) e.body.Cancel();
        if (hero != null && hero.body) hero.body.Cancel(); CombatTempoVFX.Clear();
    }
    public void Clear() { Cancel(); foreach (var e in enemies.Values) Restore(e); enemies.Clear(); Restore(hero); hero = null; Enabled = false; HoundBodyOnly = false; encounter = null; }
    void OnDisable() => Clear();
}
