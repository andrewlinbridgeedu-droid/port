#if UNITY_EDITOR || UNITY_STANDALONE
using System;
using System.Collections;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using UnityEngine;

/// <summary>Development capture through the public native-combat skill route.
/// Does not call a VFX component directly or manufacture a contact callback.</summary>
public sealed class HeroSpellCapture : MonoBehaviour
{
    string output;
    int contacts, completions;
    string currentSkill;
    string runtimeFailure;
    readonly List<string> results = new List<string>();
    readonly List<float> contactTimes = new List<float>();
    float skillStart;
    bool listening;

    [RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.AfterSceneLoad)]
    static void Bootstrap()
    {
        if (!Environment.GetCommandLineArgs().Contains("--preview-hero-spells")) return;
        new GameObject("Hero Spell Capture").AddComponent<HeroSpellCapture>();
    }
    IEnumerator Start()
    {
        var arg = Environment.GetCommandLineArgs().FirstOrDefault(a => a.StartsWith("--hero-capture="));
        output = arg == null ? "/tmp/mistport-hero-spell-capture" : arg.Substring("--hero-capture=".Length);
        Directory.CreateDirectory(output);
        string complete = Path.Combine(output, "capture-complete.txt");
        if (File.Exists(complete)) File.Delete(complete);
        string failed = Path.Combine(output, "capture-failed.txt");
        if (File.Exists(failed)) File.Delete(failed);
        Screen.SetResolution(720, 1024, false);
        Application.logMessageReceived += Observe;
        listening = true;
        yield return new WaitForSeconds(2);
        Time.captureFramerate = 30;
        var battle = FindFirstObjectByType<BattlePrototype>();
        if (!battle) { Fail("Battle runtime missing"); yield break; }
        battle.SetNativeCombatEnabled(false);
        battle.SetEncoreRevenant(false);
        battle.ConfigureWaveInstances("clock-guard-primary@archivist");
        yield return null;

        foreach (int number in new[] { 1, 2, 4, 5, 6, 7, 8, 9, 10 })
        {
            currentSkill = "fool_skill_" + number.ToString("D2");
            string folder = Path.Combine(output, currentSkill);
            Directory.CreateDirectory(folder);
            foreach (string old in Directory.GetFiles(folder, "frame-*.png")) File.Delete(old);
            battle.SetNativeCombatEnabled(false);
            yield return null;
            battle.SetNativeCombatEnabled(true);
            int beforeContacts = contacts, beforeCompletions = completions;
            contactTimes.Clear(); skillStart = Time.time;
            battle.PresentPlayerSkill(currentSkill + ":clock-guard-primary");
            if (currentSkill != "fool_skill_10" && GameObject.Find("Arcane dust flow runtime"))
            { Fail("Unexpected common particle layer on " + currentSkill); yield break; }
            int frame = 0;
            while (Time.time - skillStart < 2.9f)
            {
                yield return new WaitForEndOfFrame();
                if (frame % 2 == 0) Capture(Path.Combine(folder, "frame-" + (frame / 2).ToString("D3") + ".png"));
                frame++;
                yield return null;
            }
            if (runtimeFailure != null || contacts != beforeContacts + 1 || completions != beforeCompletions + 1)
            {
                Fail($"{currentSkill} contacts={contacts-beforeContacts} completions={completions-beforeCompletions}; {runtimeFailure}");
                battle.SetNativeCombatEnabled(false); yield break;
            }
            string times = string.Join(",", contactTimes.Select(t => t.ToString("F3")).ToArray());
            string result = $"HERO_CAPTURE_OK {currentSkill} contacts=1 completions=1 contactSeconds={times} frames={frame}";
            results.Add(result); Debug.Log(result);
            battle.SetNativeCombatEnabled(false);
            yield return null;
        }

        // Stop native combat while these two spells are in their wind-up. The
        // public stop route must invalidate callbacks AND destroy hidden roots.
        foreach (string id in new[] { "fool_skill_06", "fool_skill_10" })
        {
            currentSkill = id;
            battle.SetNativeCombatEnabled(false);
            yield return null;
            var beforeMeshes = new HashSet<int>(Resources.FindObjectsOfTypeAll<Mesh>().Select(m => m.GetInstanceID()));
            battle.SetNativeCombatEnabled(true);
            int beforeContacts = contacts, beforeCompletions = completions;
            skillStart = Time.time;
            battle.PresentPlayerSkill(id + ":clock-guard-primary");
            yield return new WaitForSeconds(.35f);
            yield return new WaitForEndOfFrame();
            Capture(Path.Combine(output, id + "-before-cancel.png"));
            battle.SetNativeCombatEnabled(false);
            yield return new WaitForSeconds(1.8f);
            yield return new WaitForEndOfFrame();
            Capture(Path.Combine(output, id + "-after-cancel.png"));
            var roots = FindObjectsByType<Transform>(FindObjectsInactive.Include, FindObjectsSortMode.None)
                .Where(t => t.name.StartsWith("Hero arcana theatre", StringComparison.Ordinal)
                    || t.name.StartsWith("Nameless declaration runtime", StringComparison.Ordinal)
                    || t.name.StartsWith("True hero hunting shadow", StringComparison.Ordinal)
                    || t.name.StartsWith("Porcelain memory", StringComparison.Ordinal)
                    || t.name.StartsWith("Spatial spell energy ",StringComparison.Ordinal) || t.name=="Spell surface light (temporary)" || t.name=="Fool tarot strike runtime" || t.name=="Arcane dust flow runtime" || t.name=="Arcane impact bloom runtime").Select(t => t.name).ToArray();
            var meshes = Resources.FindObjectsOfTypeAll<Mesh>()
                .Where(m => !beforeMeshes.Contains(m.GetInstanceID()) && IsOwnedMeshName(m.name))
                .Select(m => m.name).ToArray();
            if (runtimeFailure != null || contacts != beforeContacts || completions != beforeCompletions || roots.Length > 0 || meshes.Length > 0)
            {
                Fail($"{id} cancellation contacts={contacts-beforeContacts} completions={completions-beforeCompletions} roots={string.Join(",",roots)} meshes={string.Join(",",meshes)}; {runtimeFailure}");
                yield break;
            }
            string result = $"HERO_CANCEL_OK {id} contacts=0 completions=0 transientRoots=0 ownedMeshes=0";
            results.Add(result); Debug.Log(result);
        }
        battle.SetNativeCombatEnabled(false);
        File.WriteAllLines(complete, results);
        StopListening();
        Debug.Log("HERO_CAPTURE_COMPLETE nine-native-skills two-cancellations");
        Application.Quit(0);
    }
    static bool IsOwnedMeshName(string name)
    {
        return name=="Spell volume sheet" || name.StartsWith("Arcane impact bloom",StringComparison.Ordinal) || name.StartsWith("Arcane dust ",StringComparison.Ordinal) || name=="Dust stage veil" || name == "Hero world skin snapshot" || name == "Tarot original art"
            || name == "Folded stage fabric" || name == "Organic aftermath"
            || name == "Organic soul mist" || name == "Memory curtains";
    }
    void Observe(string message, string stack, LogType type)
    {
        if (type == LogType.Exception || type == LogType.Assert)
            runtimeFailure = message;
        if (type == LogType.Error && (message.Contains("HeroArcanaTheatreVFX") || message.Contains("NamelessDeclarationVFX")))
            runtimeFailure = message;
        if (message.Contains("\"eventName\":\"combat-contact\",\"value\":\"player\""))
        {
            contacts++; contactTimes.Add(Time.time - skillStart);
        }
        if (currentSkill != null && message.Contains("\"eventName\":\"presentation-complete\",\"value\":\"" + currentSkill + "\""))
            completions++;
    }
    void Fail(string reason)
    {
        File.WriteAllText(Path.Combine(output, "capture-failed.txt"), reason + "\n" + string.Join("\n", results));
        StopListening();
        Debug.LogError("HERO_CAPTURE_FAILED " + reason);
        Application.Quit(1);
    }
    static void Capture(string path)
    {
        Texture2D texture = ScreenCapture.CaptureScreenshotAsTexture();
        try { File.WriteAllBytes(path, texture.EncodeToPNG()); }
        finally { Destroy(texture); }
    }
    void StopListening()
    {
        if (listening) Application.logMessageReceived -= Observe;
        listening = false; Time.captureFramerate = 0;
    }
    void OnDestroy() { StopListening(); }
}
#endif
