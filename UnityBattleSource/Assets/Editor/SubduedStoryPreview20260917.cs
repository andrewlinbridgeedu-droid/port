using System;
using System.Collections;
using System.IO;
using System.Linq;
using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEngine;

public static class SubduedStoryPreview20260917
{
    const string Key = "Mistport.SubduedStoryPreview";
    public static void Begin() {
        SessionState.SetBool(Key, true);
        EditorSceneManager.OpenScene("Assets/Scenes/BattlePrototype.unity");
        EditorApplication.isPlaying = true;
    }
    [InitializeOnLoadMethod] static void Restore() {
        EditorApplication.playModeStateChanged += state => {
            if (!SessionState.GetBool(Key, false)) return;
            if (state == PlayModeStateChange.EnteredPlayMode) new GameObject("Subdued real actors QA").AddComponent<SubduedStoryPreviewRunner>();
            if (state == PlayModeStateChange.EnteredEditMode) { SessionState.SetBool(Key, false); EditorApplication.Exit(0); }
        };
    }
}
public sealed class SubduedStoryPreviewRunner : MonoBehaviour
{
    int contacts;
    void Count(string m, string trace, LogType type) { if (m.Contains("combat-contact") && m.Contains("enemy:")) contacts++; }
    IEnumerator Start() {
        Application.logMessageReceived += Count;
        yield return new WaitForSeconds(3);
        string dir = Path.GetFullPath("../output/claim-story-20260916"); Directory.CreateDirectory(dir);
        var battle = FindFirstObjectByType<BattlePrototype>();
        var bridge = FindFirstObjectByType<UnityBattleBridge>();
        var floor = GameObject.Find("Clock Arena"); if (floor) floor.SetActive(false);
        foreach (var ring in FindObjectsByType<Transform>(FindObjectsSortMode.None)) if (ring.name.StartsWith("Arena Rune Ring")) ring.gameObject.SetActive(false);
        foreach (var model in new[]{"rescue", "matriarch"}) {
            int mission = model == "rescue" ? 13 : 15;
            battle.SetNativeCombatEnabled(false);
            battle.ConfigureWaveInstances("clock-guard-primary@" + model + ",clock-core-primary" + (mission == 15 ? ",clock-core-secondary" : ""));
            battle.SetEarlyBattlePresence(mission.ToString());
            yield return new WaitForSeconds(.7f);
            var actor = FindObjectsByType<EnemyHandle>(FindObjectsSortMode.None).Single(h => h.BattleEnemyId == "clock-guard-primary" && battle.BelongsToCurrentEncounter(h));
            Capture(dir + "/q" + mission + "-before.png");
            bridge.SetEnemyVisibility("clock-guard-primary=subdued");
            battle.SetNativeCombatEnabled(true);
            int prior = contacts;
            battle.PresentEnemyAttack("clock-guard-primary");
            for (int frame = 0; frame < 3; frame++) {
                yield return new WaitForSeconds(.7f);
                Capture(dir + "/q" + mission + "-subdued-" + frame + ".png");
                Require(actor.gameObject.activeInHierarchy, "subdued actor disappeared");
                Require(actor.GetComponent<EnemySubduedPresentation>().IsSubdued, "subdued flag absent");
                foreach (var animator in actor.GetComponentsInChildren<Animator>()) Require(!animator.GetCurrentAnimatorStateInfo(0).IsName("Death"), "death clip played");
            }
            Require(contacts == prior, "subdued actor made attack contact");
            bridge.SetEnemyVisibility("clock-guard-primary=visible");
            yield return new WaitForSeconds(.7f);
            Require(!actor.GetComponent<EnemySubduedPresentation>().IsSubdued, "retry did not restore actor");
            Capture(dir + "/q" + mission + "-restored.png");
            prior = contacts;
            battle.PresentEnemyAttack("clock-guard-primary");
            yield return new WaitForSeconds(5);
            Require(contacts == prior + 1, "restored actor did not produce exactly one attack contact");
            bridge.SetEnemyVisibility("clock-guard-primary=subdued");
            bridge.SetEnemyVisibility("clock-guard-primary=subdued");
            bridge.SetEnemyVisibility("clock-guard-primary=visible");
            Require(!actor.GetComponent<EnemySubduedPresentation>().IsSubdued, "repeated subdued restore failed");
            battle.SetNativeCombatEnabled(false);
        }
        File.WriteAllText(dir + "/subdued-runtime-passed.txt", "Q13 RescueBearer and Q15 Crimson Threadweaver actual Play Mode models: remain visible, no Death state, subdued attack suppressed, visible restores and next attack contacts exactly once; repeated subdued/visible restores. Screenshots at 0.7/1.4/2.1 seconds. Not native or phone acceptance.\n");
        EditorApplication.isPlaying = false;
    }
    static void Require(bool ok, string message) { if (!ok) { Debug.LogError(message); EditorApplication.Exit(3); throw new Exception(message); } }
    static void Capture(string path) {
        var camera = Camera.main; float aspect = camera.aspect;
        var target = camera.targetTexture; var active = RenderTexture.active;
        var rt = new RenderTexture(540, 960, 24); var image = new Texture2D(540, 960, TextureFormat.RGB24, false);
        try {
            camera.aspect = 540f / 960; camera.targetTexture = rt; camera.Render(); RenderTexture.active = rt;
            image.ReadPixels(new Rect(0, 0, 540, 960), 0, 0); image.Apply(); File.WriteAllBytes(path, image.EncodeToPNG());
        } finally { camera.aspect = aspect; camera.targetTexture = target; RenderTexture.active = active; Destroy(rt); Destroy(image); }
    }
    void OnDestroy() { Application.logMessageReceived -= Count; }
}
