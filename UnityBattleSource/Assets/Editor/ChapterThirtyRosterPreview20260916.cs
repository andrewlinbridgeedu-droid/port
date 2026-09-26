using System;
using System.Collections;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEngine;

public static class ChapterThirtyRosterPreview20260916 {
    const string Key = "Mistport.ChapterThirtyRosterPreview";
    public static void Begin() { SessionState.SetBool(Key, true); EditorSceneManager.OpenScene("Assets/Scenes/BattlePrototype.unity"); EditorApplication.isPlaying = true; }
    [InitializeOnLoadMethod] static void Restore() {
        EditorApplication.playModeStateChanged += state => {
            if (!SessionState.GetBool(Key, false)) return;
            if (state == PlayModeStateChange.EnteredPlayMode) new GameObject("Chapter thirty roster audit").AddComponent<ChapterThirtyRosterRunner20260916>();
            if (state == PlayModeStateChange.EnteredEditMode) { SessionState.SetBool(Key, false); EditorApplication.Exit(0); }
        };
    }
}

public sealed class ChapterThirtyRosterRunner20260916 : MonoBehaviour {
    string output;
    BattlePrototype battle;
    UnityBattleBridge bridge;
    int pendingModels;
    readonly Dictionary<string, int> contacts = new Dictionary<string, int>();
    int Count(string id) => contacts.TryGetValue(id, out var value) ? value : 0;
    void Observe(string message, string trace, LogType type) {
        if (!message.Contains("combat-contact")) return;
        foreach (var id in new[] { "hell-hound-primary", "clock-guard-primary", "clock-guard-secondary", "clock-guard-instance-3", "clock-core-primary" })
            if (message.Contains("enemy:" + id)) contacts[id] = Count(id) + 1;
    }
    IEnumerator Start() {
        output = Path.GetFullPath(Path.Combine(Application.dataPath, "../../output/chapter30-rosters-20260916"));
        Directory.CreateDirectory(output);
        bool captureOnly = Environment.GetEnvironmentVariable("MISTPORT_CHAPTER30_CAPTURE_ONLY") == "1";
        if (!captureOnly) { File.Delete(output + "/passed.txt"); File.WriteAllText(output + "/checks.txt", ""); }
        Application.logMessageReceived += Observe;
        yield return new WaitForSeconds(3);
        battle = FindFirstObjectByType<BattlePrototype>(); bridge = FindFirstObjectByType<UnityBattleBridge>();
        foreach (var ring in FindObjectsByType<Transform>(FindObjectsSortMode.None))
            if (ring.name.StartsWith("Arena Rune Ring")) ring.gameObject.SetActive(false);
        for (int mission = 16; mission <= 30; mission++) {
            string required = mission == 18 || mission == 23 ? "ArchiveAdjudicator" : mission == 20 || mission == 26 ? "ArchiveConvoy" : null;
            if (required != null && !Resources.Load<EnemyVisualProfile>("Enemies/Signature/" + required + "/VisualProfile")) {
                pendingModels++; File.AppendAllText(output + "/checks.txt", "Q" + mission + " PENDING real model import " + required + "\n"); continue;
            }
            bridge.ResetEnemyExitPresentation();
            battle.ConfigureChapterThirtyMission(mission.ToString());
            yield return new WaitForSeconds(.7f);
            var actors = FindObjectsByType<EnemyHandle>(FindObjectsSortMode.None).Where(h => battle.BelongsToCurrentEncounter(h)).OrderBy(h => h.BattleEnemyId).ToArray();
            int expected = mission == 29 ? 3 : new[] {21,24,27}.Contains(mission) ? 2 : 1;
            Require(actors.Length == expected, "Q" + mission + " roster count " + actors.Length);
            Require(actors.Select(a => a.BattleEnemyId).Distinct().Count() == expected, "duplicate actor identity");
            if (mission == 17) Require(actors.Single().ProfileEnemyId == "executor", "Q17 wrong executor");
            if (mission == 18 || mission == 23) Require(actors.Single().GetComponent<HeavyArchivePresentation20260916>() && !actors.Single().GetComponent<HeavyArchivePresentation20260916>().isConvoy, "wrong adjudicator");
            if (mission == 20 || mission == 26) Require(actors.Single().GetComponent<HeavyArchivePresentation20260916>() && actors.Single().GetComponent<HeavyArchivePresentation20260916>().isConvoy, "wrong convoy");
            if (mission >= 28) Require(actors.Single(a => a.BattleEnemyId == "clock-guard-primary").GetComponent<ChronarchPresentation20260916>(), "wrong Boss body");
            if (mission == 24) Require(actors.Any(a => a.GetComponentInChildren<FogGhostActor>()), "Q24 ghost replaced by guard");
            Capture("q" + mission + "-idle");
            if (captureOnly) continue;
            battle.SetNativeCombatEnabled(true);
            foreach (var actor in actors) {
                int before = Count(actor.BattleEnemyId);
                battle.PresentEnemyAttack(actor.BattleEnemyId);
                yield return new WaitForSeconds(4);
                Require(Count(actor.BattleEnemyId) == before + 1, "Q" + mission + " contact once " + actor.BattleEnemyId + " actual=" + (Count(actor.BattleEnemyId)-before));
            }
            int prior = contacts.Values.Sum();
            foreach (var actor in actors) battle.PresentEnemyAttack(actor.BattleEnemyId);
            yield return new WaitForSeconds(.12f); battle.SetNativeCombatEnabled(false);
            yield return new WaitForSeconds(1.4f);
            Require(contacts.Values.Sum() == prior, "Q" + mission + " contact survived cancellation");
            if (new[] {21,22,25}.Contains(mission)) {
                var actor = actors.Single(a => a.BattleEnemyId == "clock-guard-primary");
                bridge.SetEnemyVisibility(actor.BattleEnemyId + "=subdued"); yield return new WaitForSeconds(1.2f);
                Require(actor.gameObject.activeInHierarchy && actor.GetComponent<EnemySubduedPresentation>().IsSubdued, "nonlethal model disappeared");
                Capture("q" + mission + "-subdued");
                bridge.SetEnemyVisibility(actor.BattleEnemyId + "=visible"); yield return new WaitForSeconds(.2f);
                Require(!actor.GetComponent<EnemySubduedPresentation>().IsSubdued, "nonlethal restore failed");
            }
            if (mission == 20 || mission >= 28) {
                var actor = actors.Single(a => a.BattleEnemyId == "clock-guard-primary");
                bridge.SetEnemyVisibility(actor.BattleEnemyId + (mission == 30 ? "=hidden" : "=retreat"));
                yield return new WaitForSeconds(.25f); Capture("q" + mission + "-exit");
                var animator = actor.GetComponentInChildren<Animator>();
                if (mission != 30 && animator) Require(!animator.GetCurrentAnimatorStateInfo(0).IsName("Death"), "retreat entered death");
                if (mission == 30 && animator) Require(animator.GetCurrentAnimatorStateInfo(0).IsName("Death"), "Boss true kill failed to play Death");
                yield return new WaitForSeconds(1.05f); Require(!actor.gameObject.activeSelf, "exit not complete");
                bridge.SetEnemyVisibility(actor.BattleEnemyId + "=visible"); yield return new WaitForSeconds(.3f);
                Require(actor.gameObject.activeInHierarchy, "retry model did not return");
            }
            File.AppendAllText(output + "/checks.txt", "Q" + mission + " roster, actual actor contacts once, cancellation, scoped exit: PASS\n");
        }
        if (captureOnly) {
            File.WriteAllText(output + "/clean-visual-capture.txt", "Q16-30 freshly rendered with debug geometry disabled by default in source. Earlier actual contact/cancel tests retained.\n");
            EditorApplication.isPlaying = false; yield break;
        }
        foreach (int mission in new[] {3,4,10,13,15}) {
            battle.SetNativeCombatEnabled(false); bridge.ResetEnemyExitPresentation();
            if (mission <= 4) battle.UseEarlyHellHoundModel();
            else if (mission == 10) battle.ConfigureWaveInstances("hell-hound-primary,clock-guard-primary@archivist");
            else if (mission == 13) battle.ConfigureWaveInstances("clock-guard-primary@rescue,clock-core-primary");
            else battle.ConfigureWaveInstances("clock-guard-primary@matriarch,clock-core-primary,clock-core-secondary");
            battle.SetEarlyBattlePresence(mission.ToString()); yield return new WaitForSeconds(.5f);
            string identity = mission <= 10 ? "hell-hound-primary" : "clock-guard-primary";
            var actor = FindObjectsByType<EnemyHandle>(FindObjectsSortMode.None).Single(h => battle.BelongsToCurrentEncounter(h) && h.BattleEnemyId == identity);
            bridge.SetEnemyVisibility(identity + (mission <= 10 ? "=retreat" : "=subdued"));
            yield return new WaitForSeconds(.25f); Capture("q" + mission + "-nonlethal-exit");
            var animator = actor.GetComponentInChildren<Animator>();
            if (animator) Require(!animator.GetCurrentAnimatorStateInfo(0).IsName("Death"), "Q" + mission + " falsely died");
            yield return new WaitForSeconds(1);
            Require(actor.gameObject.activeSelf == (mission > 10), "Q" + mission + " wrong exit visibility");
            bridge.SetEnemyVisibility(identity + "=visible"); yield return new WaitForSeconds(.3f);
            Require(actor.gameObject.activeInHierarchy, "Q" + mission + " exit retry failed");
            File.AppendAllText(output + "/checks.txt", "Q" + mission + " retreat/subdued without Death and retry: PASS\n");
        }
        File.WriteAllText(output + (pendingModels == 0 ? "/passed.txt" : "/partial-passed.txt"), "Available Q16-30 actual Editor Play Mode art roster and callbacks/cancellation verified; pending model missions=" + pendingModels + ". Nonlethal/retreat/death cleanup checked. No native balance, unlocking or phone acceptance asserted.\n");
        EditorApplication.isPlaying = false;
    }
    static void Require(bool ok, string message) { if (!ok) { Debug.LogError("CHAPTER30_ROSTER_FAILED " + message); EditorApplication.Exit(3); throw new Exception(message); } }
    void Capture(string name) {
        var camera = Camera.main; var old = camera.targetTexture; var active = RenderTexture.active; float aspect = camera.aspect;
        var rt = new RenderTexture(540,960,24); var image = new Texture2D(540,960,TextureFormat.RGB24,false);
        try { camera.aspect = 540f/960; camera.targetTexture = rt; camera.Render(); RenderTexture.active = rt; image.ReadPixels(new Rect(0,0,540,960),0,0); image.Apply(); File.WriteAllBytes(output + "/" + name + ".png", image.EncodeToPNG()); }
        finally { camera.targetTexture = old; camera.aspect = aspect; RenderTexture.active = active; Destroy(rt); Destroy(image); }
    }
    void OnDestroy() { Application.logMessageReceived -= Observe; }
}
