#if UNITY_EDITOR || UNITY_STANDALONE
using System;
using System.Collections;
using System.Collections.Generic;
using System.Globalization;
using System.IO;
using System.Linq;
using UnityEngine;

// Production presentation/callback verification. Does not simulate native damage,
// and screenshots are standalone evidence rather than device acceptance.
[DefaultExecutionOrder(3000)]
public sealed class HeroSkillChoreographyCapture : MonoBehaviour
{
    Action afterLate;
    void LateUpdate(){var action=afterLate;afterLate=null;action?.Invoke();}
    BattlePrototype battle;
    Transform hero;
    Component choreography;
    string output, error;
    int contacts, completions;
    bool listen;
    readonly List<string> report = new List<string>();
    readonly string[] skills = { "01", "02", "04", "05", "06", "07", "08", "09", "10" };

    [RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.AfterSceneLoad)]
    static void Boot()
    {
        if (Environment.GetCommandLineArgs().Contains("--verify-hero-choreography"))
            new GameObject("Hero choreography verification").AddComponent<HeroSkillChoreographyCapture>();
    }

    void Observe(string message, string stack, LogType type)
    {
        if (type == LogType.Exception || type == LogType.Assert) error = message;
        if (!listen) return;
        if (message.Contains("\"eventName\":\"combat-contact\",\"value\":\"player\"")) contacts++;
        if (message.Contains("\"eventName\":\"presentation-complete\"")) completions++;
    }

    bool Playing => choreography != null && (bool)choreography.GetType().GetProperty("IsPlaying").GetValue(choreography);
    int Joints => choreography == null ? 0 : Convert.ToInt32(choreography.GetType().GetProperty("MappedJointCount").GetValue(choreography));

    IEnumerator Start()
    {
        output = Environment.GetEnvironmentVariable("MISTPORT_HERO_CAPTURE") ?? "/tmp/mistport-hero-choreography";
        Directory.CreateDirectory(output);
        File.Delete(Path.Combine(output, "passed.txt")); File.Delete(Path.Combine(output, "failed.txt"));
        Application.logMessageReceived += Observe;
        Screen.SetResolution(720, 1024, false);
        yield return new WaitForSeconds(2);
        Time.captureFramerate = 60;
        battle = FindFirstObjectByType<BattlePrototype>();
        var actor = GameObject.Find("Fool_Imported");
        if (!battle || !actor) { Fail("Production battle/hero missing"); yield break; }
        hero = actor.transform;
        battle.SetNativeCombatEnabled(false); battle.UseClockGuardModel();
        yield return new WaitForSeconds(.4f);
        choreography = hero.GetComponentsInChildren<MonoBehaviour>(true).FirstOrDefault(c => c && c.GetType().Name == "FoolSkillChoreography");
        if (!choreography || Joints < 10) { Fail("Choreography missing or insufficient mapped joints: " + Joints); yield break; }
        report.Add("Mapped hero joints=" + Joints);
        foreach (var number in skills)
        {
            yield return Exercise("fool_skill_" + number);
            if (error != null) { Fail(error); yield break; }
        }
        // Cancel during windup: no late callbacks or residual additive pose lifetime.
        battle.SetNativeCombatEnabled(true);
        contacts = completions = 0; listen = true;
        battle.PresentPlayerSkill("fool_skill_07");
        yield return new WaitForSeconds(.12f);
        if (!Playing) { Fail("Cancellation fixture never entered choreography"); yield break; }
        battle.SetNativeCombatEnabled(false);
        yield return new WaitForSeconds(1.2f);
        if (Playing || contacts != 0 || completions != 0) { Fail("Stop retained choreography or late callback"); yield break; }
        listen = false;
        report.Add("Windup cancellation: cleared; no late player contact/completion.");
        battle.SetNativeCombatEnabled(true);
        battle.PresentPlayerSkill("fool_skill_10");
        yield return new WaitForSeconds(.12f);
        battle.PresentPlayerDefeat();
        yield return new WaitForSeconds(.15f);
        if (Playing) { Fail("Defeat retained choreography"); yield break; }
        battle.SetNativeCombatEnabled(false);
        yield return new WaitForSeconds(.3f);
        if (Playing || !hero.gameObject.activeInHierarchy) { Fail("Retry failed to restore hero"); yield break; }
        report.Add("Defeat clears choreography; combat reset restores active hero.");
        yield return Exercise("fool_skill_04");
        if (error != null) { Fail(error); yield break; }
        report.Add("Retry casts and returns to idle successfully.");
        report.Add("Scope: real Unity presentation callbacks and visible bone/root capture; not native damage-engine or iPhone visual acceptance.");
        File.WriteAllLines(Path.Combine(output, "passed.txt"), report);
        Application.Quit(0);
    }

    IEnumerator Exercise(string skill)
    {
        battle.SetNativeCombatEnabled(true);
        yield return new WaitForSeconds(.25f);
        var bones = hero.GetComponentsInChildren<SkinnedMeshRenderer>(true).SelectMany(r => r.bones).Where(t => t).Distinct().ToArray();
        var baseline = bones.Select(b => b.localRotation).ToArray();
        Vector3 root = hero.position, scale = hero.localScale;
        Quaternion rotation = hero.rotation;
        string folder = Path.Combine(output, skill); Directory.CreateDirectory(folder);
        File.WriteAllText(Path.Combine(folder, "bones.csv"), "time,phase,bone,angle_from_baseline,local_x,local_y,local_z,local_w\n");
        contacts = completions = 0; listen = true;
        float start = Time.time, maxAngle = 0, maxRoot = 0, maxRootAngle = 0, maxScale = 0;
        int shots = 0, changed = 0; bool active = false;
        battle.PresentPlayerSkill(skill);
        while (Time.time - start < 4.2f)
        {
            yield return null;
            afterLate = () => {
            active |= Playing;
            maxRoot = Mathf.Max(maxRoot, Vector3.Distance(hero.position, root));
            maxRootAngle = Mathf.Max(maxRootAngle, Quaternion.Angle(hero.rotation, rotation));
            maxScale = Mathf.Max(maxScale, Vector3.Distance(hero.localScale, scale));
            int moving = 0;
            for (int i = 0; i < bones.Length; i++)
            {
                float angle = Quaternion.Angle(baseline[i], bones[i].localRotation);
                maxAngle = Mathf.Max(maxAngle, angle); if (angle > 2f) moving++;
            }
            changed = Mathf.Max(changed, moving);
            if (shots < 24 && Time.time - start >= shots / 6f)
            {
                Snapshot(folder, shots++, Time.time - start, bones, baseline, contacts == 0 ? "windup" : completions == 0 ? "contact" : "recovery");
            }
            };
            yield return null;
        }
        listen = false;
        if (contacts != 1 || completions != 1) { error = skill + " contacts=" + contacts + " completions=" + completions; yield break; }
        if (!active || Playing || changed < 6 || maxAngle < 6f) { error = skill + " inactive/unsettled/insufficient bone movement: changed=" + changed + " maxAngle=" + maxAngle; yield break; }
        if (maxRoot > .002f || maxRootAngle > .1f || maxScale > .002f) { error = skill + " root drift: position=" + maxRoot + " angle=" + maxRootAngle + " scale=" + maxScale; yield break; }
        report.Add(skill + ": contact=1; completion=1; active then settled; moving bones=" + changed + "; peak angle=" + maxAngle.ToString("F2", CultureInfo.InvariantCulture) + "; anchored root unchanged.");
        File.WriteAllLines(Path.Combine(output, "progress.txt"), report);
    }

    void Snapshot(string folder, int frame, float elapsed, Transform[] bones, Quaternion[] baseline, string phase)
    {
        var lines = new List<string>();
        for (int i = 0; i < bones.Length; i++)
        {
            var q = bones[i].localRotation;
            lines.Add(string.Join(",", elapsed.ToString("F4", CultureInfo.InvariantCulture), phase, bones[i].name.Replace(',', '_'), Quaternion.Angle(baseline[i], q).ToString("F3", CultureInfo.InvariantCulture), q.x.ToString(CultureInfo.InvariantCulture), q.y.ToString(CultureInfo.InvariantCulture), q.z.ToString(CultureInfo.InvariantCulture), q.w.ToString(CultureInfo.InvariantCulture)));
        }
        File.AppendAllLines(Path.Combine(folder, "bones.csv"), lines);
        var camera = Camera.main;
        var old = camera.targetTexture; var activeRT = RenderTexture.active;
        var rt = new RenderTexture(720, 1024, 24);
        var image = new Texture2D(720, 1024, TextureFormat.RGB24, false);
        camera.targetTexture = rt; camera.Render(); RenderTexture.active = rt;
        image.ReadPixels(new Rect(0,0,720,1024),0,0); image.Apply();
        camera.targetTexture = old; RenderTexture.active = activeRT; Destroy(rt);
        File.WriteAllBytes(Path.Combine(folder, $"frame-{frame:D3}.png"), image.EncodeToPNG());
        Destroy(image);
    }
    void Fail(string reason) { File.WriteAllLines(Path.Combine(output, "failed.txt"), report.Concat(new[] { reason })); Debug.LogError("HERO_CHOREOGRAPHY_FAILED " + reason); Application.Quit(1); }
    void OnDestroy() { Application.logMessageReceived -= Observe; Time.captureFramerate = 0; }
}
#endif
