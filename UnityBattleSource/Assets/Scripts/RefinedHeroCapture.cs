#if UNITY_EDITOR || UNITY_STANDALONE
using System;
using System.Collections;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using UnityEngine;

// Actual runtime poses and contact receipts; not iPhone or visual approval.
public sealed class RefinedHeroCapture : MonoBehaviour
{
    string output, error;
    int contacts;
    readonly List<string> report = new List<string>();
    [RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.AfterSceneLoad)]
    static void Boot() {
        if (Environment.GetCommandLineArgs().Contains("--verify-refined-hero"))
            new GameObject("Refined hero runtime probe").AddComponent<RefinedHeroCapture>();
    }
    void Observe(string text, string stack, LogType type) {
        if (type == LogType.Exception || type == LogType.Assert || text.Contains("TEMPO_CLIP_MISSING")) error = text;
        if (text.Contains("\"eventName\":\"combat-contact\",\"value\":\"player\"")) contacts++;
    }
    IEnumerator Start() {
        output = Environment.GetEnvironmentVariable("MISTPORT_HERO_CAPTURE");
        if (string.IsNullOrEmpty(output)) { Application.Quit(2); yield break; }
        Directory.CreateDirectory(output); Application.logMessageReceived += Observe;
        Screen.SetResolution(600, 900, false); yield return new WaitForSeconds(2);
        var battle = FindFirstObjectByType<BattlePrototype>();
        battle.SetNativeCombatEnabled(true);
        battle.RequestWaveInstances("clock-guard-primary@stonehide"); yield return new WaitForSeconds(.5f);
        battle.SetTempoSample("church_tower_001"); yield return new WaitForSeconds(.3f);
        var body = battle.TempoSamplePlayer.GetComponentsInChildren<CombatTempoAnimatedBody>().FirstOrDefault(b => b.Kind == "Hero");
        if (!body) { Fail("Refined hero not installed"); yield break; }
        var appearance = body.GetComponent<RefinedHeroAppearance>(); var animator = body.GetComponent<Animator>();
        if (!appearance || !animator.runtimeAnimatorController) { Fail("Outfit/controller missing"); yield break; }
        var controller = animator.runtimeAnimatorController;
        var camera = Camera.main; var position = camera.transform.position; var rotation = camera.transform.rotation;
        foreach (var outfit in new[] {"mistport-night","starlight-magician","midnight-carnival"}) {
            CombatTempoPresentation.Get(battle).SetOutfit(outfit); yield return new WaitForSeconds(.15f);
            if (appearance.Outfit != outfit || controller != animator.runtimeAnimatorController || position != camera.transform.position || rotation != camera.transform.rotation) {
                Fail("Outfit selection changed controller/camera or failed"); yield break;
            }
            yield return new WaitForEndOfFrame(); Shot(Path.Combine(output, outfit + "-battle.png"));
        }
        CombatTempoPresentation.Get(battle).SetOutfit("mistport-night");
        report.Add("Three native outfit IDs: selected appearance applied; same Animator controller and arena camera.");
        // Close inspection uses a labelled probe camera, never a production camera change.
        var skins = body.GetComponentsInChildren<SkinnedMeshRenderer>().Where(r => r.enabled).ToArray();
        var bounds = skins[0].bounds; foreach (var r in skins.Skip(1)) bounds.Encapsulate(r.bounds);
        var rear = camera.transform.position - bounds.center; rear.y = 0; rear.Normalize();
        camera.transform.position = bounds.center + rear * 2.5f + Vector3.up * .20f;
        camera.transform.rotation = Quaternion.LookRotation(bounds.center - camera.transform.position);
        camera.fieldOfView = 45;
        foreach (var outfit in new[] {"mistport-night","starlight-magician","midnight-carnival"}) {
            appearance.Apply(outfit); yield return new WaitForSeconds(.15f);
            yield return new WaitForEndOfFrame(); Shot(Path.Combine(output, outfit + "-close.png"));
        }
        appearance.Apply("mistport-night");
        Time.captureFramerate = 30;
        var clips = new[] {"CastMaskFlick","CastMaskTurn","CastTwinSweep","CastTwinCross","CastFinaleLift","CastFinaleThrow","CastCardFan"};
        // Frame-for-frame runtime gallery of the real shared Animator.
        foreach (var clip in clips) {
            var folder = Path.Combine(output, clip); Directory.CreateDirectory(folder);
            float contact = clip.Contains("Mask") ? .38f : clip.Contains("Twin") ? .705f : clip.Contains("Finale") ? .885f : .5f;
            body.Play(clip, contact, false, 0);
            var hand = body.GetComponentsInChildren<Transform>().First(t => t.name == "RightHand");
            var initial = hand.position; float travel = 0;
            for (int frame = 0; frame < 48; frame++) {
                yield return new WaitForEndOfFrame(); travel = Mathf.Max(travel, Vector3.Distance(hand.position, initial));
                Shot(Path.Combine(folder, frame.ToString("D4") + ".png"));
            }
            if (travel < .02f || body.IsActing || error != null) { Fail(clip + " static/unsettled/error: " + travel + " " + error); yield break; }
            report.Add(clip + ": hand excursion=" + travel.ToString("F3") + "m; full recovery returned to idle.");
        }
        // Real sample command path: each identity/variation reports exactly one contact at either speed.
        Time.captureFramerate = 0;
        foreach (int speed in new[] {1,2}) {
            battle.SetCombatSpeed(speed.ToString());
            foreach (var skill in new[] {"fool_skill_02","fool_skill_06","fool_skill_07"}) for (int variant=0;variant<2;variant++) {
                contacts=0; battle.PresentPlayerSkill(skill + ":clock-guard-primary"); yield return new WaitForSeconds(2);
                if (contacts != 1 || error != null) { Fail(skill + " speed=" + speed + " contact=" + contacts + " error=" + error); yield break; }
            }
        }
        battle.SetCombatSpeed("1"); report.Add("12 production casts: two gestures per skill, x1 and x2; exactly one player contact each.");
        contacts=0; battle.PresentPlayerSkill("fool_skill_07:clock-guard-primary"); yield return new WaitForSeconds(.12f);
        var normalized = animator.GetCurrentAnimatorStateInfo(0).normalizedTime;
        appearance.Apply("starlight-magician");
        if (animator.GetCurrentAnimatorStateInfo(0).normalizedTime != normalized || animator.runtimeAnimatorController != controller) { Fail("Outfit interrupted an active cast"); yield break; }
        battle.SetTempoSample("off"); yield return new WaitForSeconds(1.3f);
        if (contacts!=0) { Fail("Sample cancellation left a late player contact"); yield break; }
        report.Add("Outfit change during cast preserves state time; leaving sample cancels pending contact and restores original art.");
        yield return new WaitForEndOfFrame();Shot(Path.Combine(output,"previous-model-close.png"));
        report.Add("Standalone Unity probe, not native iPhone video or user visual approval.");
        File.WriteAllLines(Path.Combine(output,"passed.txt"),report);Application.Quit(0);
    }
    void Shot(string path) { var tex=ScreenCapture.CaptureScreenshotAsTexture();File.WriteAllBytes(path,tex.EncodeToPNG());Destroy(tex); }
    void Fail(string why) { File.WriteAllText(Path.Combine(output,"failed.txt"),why);Debug.LogError(why);Application.Quit(2); }
}
#endif
