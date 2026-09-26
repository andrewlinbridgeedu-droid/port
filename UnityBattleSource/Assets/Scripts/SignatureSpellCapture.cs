#if UNITY_EDITOR || UNITY_STANDALONE
using System;
using System.Collections;
using System.IO;
using System.Linq;
using UnityEngine;

/// Development-only capture runs the same actor, VFX and contact routes as native combat.
public sealed class SignatureSpellCapture : MonoBehaviour
{
    string output;
    int contacts;
    int allEnemyContacts;
    int completions;
    [RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.AfterSceneLoad)]
    static void Bootstrap()
    {
        if (!Environment.GetCommandLineArgs().Contains("--preview-signatures")) return;
        new GameObject("Signature Spell Capture").AddComponent<SignatureSpellCapture>();
    }
    IEnumerator Start()
    {
        var arg = Environment.GetCommandLineArgs().FirstOrDefault(a => a.StartsWith("--signature-capture="));
        output = arg == null ? "/tmp/mistport-signature-capture" : arg.Substring("--signature-capture=".Length);
        Directory.CreateDirectory(output); File.Delete(Path.Combine(output,"capture-complete.txt")); Screen.SetResolution(720, 1024, false);
        Application.logMessageReceived += CountContacts;
        yield return new WaitForSeconds(2);
        Time.captureFramerate = 30;
        var battle = FindFirstObjectByType<BattlePrototype>();
        if (!battle) throw new Exception("Battle runtime missing");
        var selection=Environment.GetCommandLineArgs().FirstOrDefault(a=>a.StartsWith("--signature-kinds="));
        var kinds=selection==null?new[] { "Hound", "Archivist", "Matriarch", "Emerald" }:selection.Substring("--signature-kinds=".Length).Split(',');
        foreach (var kind in kinds)
        for (int variant = 0; variant < 2; variant++)
        {
            var before = contacts;
            var folder = Path.Combine(output, kind + "-" + (variant+1)); Directory.CreateDirectory(folder);
            bool finished = false;
            StartCoroutine(Run(battle.PreviewSignatureSpell(kind,variant), () => finished = true));
            for (int frame = 0; frame < 104; frame++)
            {
                yield return new WaitForEndOfFrame();
                if (frame % 2 == 0) Capture(Path.Combine(folder,$"frame-{frame/2:D3}.png"));
                yield return null;
            }
            if (!finished || contacts != before+1) throw new Exception($"Bad signature completion {kind}/{variant} finished={finished} contacts={contacts-before}");
            battle.SetNativeCombatEnabled(false); yield return null;
            if(GameObject.Find("Spell surface light (temporary)") || GameObject.Find("Enemy world anchored energy") || GameObject.Find("Hound continuous fire volume") || GameObject.Find("Crimson stage spell projection")) throw new Exception("Spell light survived cancellation");
            if (FindObjectsByType<EnemySignatureSpellVFX>(FindObjectsSortMode.None).Any(v=>v.IsPlaying)) throw new Exception("VFX remained playing after combat-stop");
            Debug.Log($"SIGNATURE_CAPTURE_OK {kind}/{variant} contacts=1");
        }
        if(kinds.Contains("Hound")) {
            int baseline=contacts;
            battle.StartCoroutine(battle.PreviewSignatureSpell("Hound",1));
            yield return new WaitForSeconds(.6f);
            battle.SetNativeCombatEnabled(false);yield return new WaitForSeconds(2f);
            if(contacts!=baseline || GameObject.Find("Hound continuous fire volume")) throw new Exception("Cancelled ground fracture delivered late effect/contact");
            Debug.Log("SIGNATURE_HOUND_GROUND_CANCEL_OK contacts=0");
        }
        if(Environment.GetCommandLineArgs().Contains("--signature-capture-only")) {
            File.WriteAllText(Path.Combine(output,"capture-complete.txt"),"Selected spells captured and stopped successfully.\n");
            Application.logMessageReceived-=CountContacts;Time.captureFramerate=0;Application.Quit(0);yield break;
        }
        // Exercise the same native poison messages: continuous field and
        // three visible pulses, then explicit combat-stop cleanup.
        var poisonBridge = FindFirstObjectByType<UnityBattleBridge>();
        battle.SetEncoreRevenant(true); battle.SetNativeCombatEnabled(true);
        var poisonFolder=Path.Combine(output,"Emerald-persistent"); Directory.CreateDirectory(poisonFolder);
        battle.SetEmeraldPoison(3);
        for(int frame=0;frame<144;frame++) {
            if(frame==48) battle.SetEmeraldPoison(2);
            if(frame==96) battle.SetEmeraldPoison(1);
            yield return new WaitForEndOfFrame();
            if(frame%4==0) Capture(Path.Combine(poisonFolder,$"frame-{frame/4:D3}.png"));
            yield return null;
        }
        battle.SetNativeCombatEnabled(false);yield return null;
        if(GameObject.Find("Emerald persistent poison field")) throw new Exception("Poison field survived combat-stop");
        Debug.Log("SIGNATURE_POISON_FIELD_CLEAR_OK");
        // Cancel while the detached arm is in flight: restore source skin and suppress damage.
        int armBaseline = contacts;
        battle.StartCoroutine(battle.PreviewSignatureSpell("Archivist",0));
        yield return new WaitForSeconds(1.65f);
        battle.SetNativeCombatEnabled(false);
        yield return new WaitForSeconds(1f);
        if(contacts != armBaseline) throw new Exception("Cancelled arm delivered late contact");
        if(GameObject.Find("Iron Vault flying forearm and palm")) throw new Exception("Cancelled arm mesh survived");
        if(FindObjectsByType<SkinnedMeshRenderer>(FindObjectsSortMode.None).Any(r=>r.name=="IronVaultLaunchArm" && !r.enabled))
            throw new Exception("Cancelled arm source renderer remained hidden");
        Debug.Log("SIGNATURE_ARM_CANCEL_OK restored=true contacts=0");
        battle.SetEncoreRevenant(false);
        // Interrupt during wind-up: no late callback, transient root or mesh is allowed.
        int cancellationBaseline = contacts;
        battle.StartCoroutine(battle.PreviewSignatureSpell("Matriarch",1));
        yield return new WaitForSeconds(.7f); battle.SetNativeCombatEnabled(false);
        yield return new WaitForSeconds(2.5f);
        if (contacts != cancellationBaseline) throw new Exception("Cancelled spell delivered a late contact");
        if (FindObjectsByType<EnemySignatureSpellVFX>(FindObjectsSortMode.None).Any(v=>v.IsPlaying)) throw new Exception("Cancelled spell still active");
        Debug.Log("SIGNATURE_CANCEL_OK");
        var bridge = FindFirstObjectByType<UnityBattleBridge>();
        if (!bridge) throw new Exception("Native bridge missing");
        battle.ConfigureWaveInstances("clock-guard-primary@archivist,clock-guard-secondary@matriarch");
        battle.SetNativeCombatEnabled(true);
        int contactBaseline = allEnemyContacts, completionBaseline = completions;
        battle.PresentEnemyAttack("clock-guard-primary"); battle.PresentEnemyAttack("clock-guard-secondary");
        yield return new WaitForSeconds(.6f);
        bridge.SetEnemyVisibility("clock-guard-primary=hidden");
        yield return new WaitForSeconds(3.2f);
        if (allEnemyContacts != contactBaseline+1 || completions != completionBaseline+1)
            throw new Exception($"Concurrent death cancellation failed contacts={allEnemyContacts-contactBaseline} completions={completions-completionBaseline}");
        Debug.Log("SIGNATURE_CONCURRENT_DEATH_OK contacts=1 completions=1");
        battle.SetNativeCombatEnabled(false); bridge.ResetEnemyExitPresentation();
        battle.ConfigureWaveInstances("clock-guard-primary@archivist"); battle.SetNativeCombatEnabled(true);
        contactBaseline=allEnemyContacts; completionBaseline=completions;
        battle.PresentEnemyAttack("clock-guard-primary:fortify"); yield return new WaitForSeconds(.2f);
        bridge.SetEnemyVisibility("clock-guard-primary=hidden"); yield return new WaitForSeconds(1.2f);
        if (allEnemyContacts != contactBaseline || completions != completionBaseline) throw new Exception("Dead preparation delivered a late callback");
        Debug.Log("SIGNATURE_PREPARATION_DEATH_OK contacts=0 completions=0");
        battle.SetNativeCombatEnabled(false); bridge.ResetEnemyExitPresentation();
        battle.ConfigureWaveInstances("hell-hound-primary,clock-guard-primary@archivist");
        yield return new WaitForEndOfFrame(); Capture(Path.Combine(output,"q10-formation.png"));
        battle.ConfigureWaveInstances("clock-guard-primary@matriarch,clock-core-primary,clock-core-secondary");
        yield return new WaitForEndOfFrame(); Capture(Path.Combine(output,"q15-formation.png"));
        File.WriteAllText(Path.Combine(output,"capture-complete.txt"),"Eight spells: one contact each. Wind-up cancellation: zero late contacts.\n");
        Application.logMessageReceived -= CountContacts; Time.captureFramerate=0; Application.Quit(0);
    }
    static IEnumerator Run(IEnumerator routine, Action complete) { yield return routine; complete(); }
    void CountContacts(string message,string stack,LogType type) {
        if (message.StartsWith("SIGNATURE_CONTACT ")) contacts++;
        if (message.Contains("\"eventName\":\"combat-contact\",\"value\":\"enemy:")) allEnemyContacts++;
        if (message.Contains("\"eventName\":\"presentation-complete\",\"value\":\"enemy\"")) completions++;
    }
    static void Capture(string path)
    {
        var texture=ScreenCapture.CaptureScreenshotAsTexture();
        File.WriteAllBytes(path,texture.EncodeToPNG()); Destroy(texture);
    }
}
#endif
