using System;
using System.Collections;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEngine;

public static class TowerRosterPreview20260917 {
    const string Key = "Mistport.TowerRosterPreview";
    public static void Begin() { SessionState.SetBool(Key, true); EditorSceneManager.OpenScene("Assets/Scenes/BattlePrototype.unity"); EditorApplication.isPlaying = true; }
    [InitializeOnLoadMethod] static void Restore() {
        EditorApplication.playModeStateChanged += state => {
            if (!SessionState.GetBool(Key, false)) return;
            if (state == PlayModeStateChange.EnteredPlayMode) new GameObject("Chapter thirty roster audit").AddComponent<TowerRosterRunner20260917>();
            if (state == PlayModeStateChange.EnteredEditMode) { SessionState.SetBool(Key, false); EditorApplication.Exit(0); }
        };
    }
}

public sealed class TowerRosterRunner20260917 : MonoBehaviour {
    string output;
    BattlePrototype battle;
    UnityBattleBridge bridge;
    Texture2D mainlineBackground;
    Texture2D CurrentBackground() => (Texture2D)typeof(BattlePrototype).GetField("runtimeBackgroundTexture",System.Reflection.BindingFlags.Instance|System.Reflection.BindingFlags.NonPublic).GetValue(battle);
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
        Application.logMessageReceived += Observe;
        yield return new WaitForSeconds(3);
        battle=FindFirstObjectByType<BattlePrototype>();bridge=FindFirstObjectByType<UnityBattleBridge>();
        output=Path.GetFullPath("../output/stonehide-delivery-20260917/tower");Directory.CreateDirectory(output);
        mainlineBackground=CurrentBackground();Require(mainlineBackground!=null,"mainline background installed");
        for(int variant=0;variant<2;variant++) {
            bridge.ResetEnemyExitPresentation();
            string roster=variant==0?"hell-hound-primary@early-hell-hound,clock-guard-primary@stonehide":"clock-guard-primary@stonehide,clock-guard-secondary@stonehide";
            bridge.ApplyCommand("{\"action\":\"church-tower:"+roster+"\"}");
            yield return new WaitForSeconds(.7f);battle.SetNativeCombatEnabled(true);
            Require(CurrentBackground()!=null && CurrentBackground()!=mainlineBackground,"tower must use independent background");
            Require(!battle.GetComponent<BattleRain>().WeatherVisible,"indoor tower must disable rainfall");
            var actors=FindObjectsByType<EnemyHandle>(FindObjectsSortMode.None).Where(h=>battle.BelongsToCurrentEncounter(h)).ToArray();
            Require(actors.Length==2,"two actual tower actors");Capture("roster-"+variant);
            foreach(var actor in actors) {
                if(actor.GetComponent<StonehidePresentation20260917>()) {
                    foreach(var phase in new[]{"guard","charge","recover"}) {
                        int before=Count(actor.BattleEnemyId);battle.PresentEnemyAttack(actor.BattleEnemyId+":"+phase);yield return new WaitForSeconds(.4f);
                        Require(Count(actor.BattleEnemyId)==before,"defensive phase leaked contact "+phase);Capture("phase-"+variant+"-"+phase);
                    }
                    int old=Count(actor.BattleEnemyId);battle.PresentEnemyAttack(actor.BattleEnemyId+":archive_slam");yield return new WaitForSeconds(2.9f);Require(Count(actor.BattleEnemyId)==old+1,"slam once");
                } else {
                    foreach(var phase in new[]{"tower_flame_first","tower_flame_second"}) {
                        int old=Count(actor.BattleEnemyId);battle.PresentEnemyAttack(actor.BattleEnemyId+":"+phase);yield return new WaitForSeconds(.2f);Capture(phase);yield return new WaitForSeconds(1);Require(Count(actor.BattleEnemyId)==old+1,"tower flame once");
                    }
                }
            }
            int prior=contacts.Values.Sum();foreach(var actor in actors)battle.PresentEnemyAttack(actor.BattleEnemyId+(actor.GetComponent<StonehidePresentation20260917>()?":archive_slam":":tower_flame_first"));
            yield return new WaitForSeconds(.1f);battle.SetNativeCombatEnabled(false);yield return new WaitForSeconds(1.4f);Require(contacts.Values.Sum()==prior,"cancellation leak");
            foreach(var actor in actors){bridge.SetEnemyVisibility(actor.BattleEnemyId+"=hidden");}
            yield return new WaitForSeconds(1.2f);Require(actors.All(a=>!a.gameObject.activeSelf),"death fade complete");
            foreach(var actor in actors)bridge.SetEnemyVisibility(actor.BattleEnemyId+"=visible");yield return new WaitForSeconds(.3f);Require(actors.All(a=>a.gameObject.activeInHierarchy),"retry restores");
        }
        bridge.ApplyCommand("{\"action\":\"wave-instances:clock-guard-primary\"}");
        yield return new WaitForSeconds(.7f);Require(CurrentBackground()==mainlineBackground,"return to mainline must restore background");Require(battle.GetComponent<BattleRain>().WeatherVisible,"mainline must restore rainfall");Capture("mainline-restored");
        File.WriteAllText(output+"/passed.txt","Actual D00+D01 and D01+D01 roster; guard/charge/recover zero contact; archive_slam once; two early tower fireballs each once; cancellation no contact; death fade and retry pass. Tower independent background/no indoor rain and mainline background/rain restoration verified. Not phone verification.");
        EditorApplication.isPlaying=false;
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
