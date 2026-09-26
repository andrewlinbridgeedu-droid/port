#if UNITY_EDITOR || UNITY_STANDALONE
using System;
using System.Collections;
using System.IO;
using System.Linq;
using UnityEngine;

public sealed class SidestepHoundFixCapture : MonoBehaviour
{
    string output; int contacts, enemyContacts, completions; string error;
    [RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.AfterSceneLoad)]
    static void Boot() {
        if(Environment.GetCommandLineArgs().Contains("--verify-sidestep-hounds"))
            new GameObject("Sidestep and hound verification").AddComponent<SidestepHoundFixCapture>();
    }
    void Observe(string message,string stack,LogType type) {
        if(type==LogType.Exception || type==LogType.Assert) error=message;
        if(message.Contains("\"eventName\":\"combat-contact\",\"value\":\"player\"")) contacts++;
        if(message.Contains("\"eventName\":\"combat-contact\",\"value\":\"enemy:hell-hound-primary\"")) enemyContacts++;
        if(message.Contains("\"eventName\":\"presentation-complete\",\"value\":\"fool_skill_01\"")) completions++;
    }
    IEnumerator Start() {
        output=Environment.GetEnvironmentVariable("MISTPORT_FIX_CAPTURE") ?? "/tmp/mistport-fix-capture";
        Directory.CreateDirectory(output);Application.logMessageReceived+=Observe;
        Screen.SetResolution(720,1024,false);yield return new WaitForSeconds(2);Time.captureFramerate=30;
        var battle=FindFirstObjectByType<BattlePrototype>();
        battle.SetNativeCombatEnabled(false);battle.SetEncoreRevenant(false);
        battle.UseEarlyHellHoundModel();yield return null;
        if(!CheckHound(true))yield break;
        yield return new WaitForEndOfFrame();Capture("early-hound");
        battle.SetNativeCombatEnabled(true);int ec=enemyContacts;battle.PresentEnemyAttack();
        yield return new WaitForSeconds(.7f);yield return new WaitForEndOfFrame();Capture("early-hound-fireball");
        yield return new WaitForSeconds(4);
        if(enemyContacts!=ec+1){Fail("early fireball contact count "+(enemyContacts-ec));yield break;}
        battle.SetNativeCombatEnabled(false);
        battle.ConfigureWaveInstances("hell-hound-primary");yield return null;
        if(!CheckHound(false))yield break;
        yield return new WaitForEndOfFrame();Capture("late-armored-hound");
        battle.UseEarlyHellHoundModel();yield return null;if(!CheckHound(true))yield break;
        var bridge=FindFirstObjectByType<UnityBattleBridge>();
        bridge.SetEnemyVisibility("hell-hound-primary=hidden");yield return new WaitForSeconds(1.3f);
        bridge.SetEnemyVisibility("hell-hound-primary=visible");yield return null;
        if(!CheckHound(true))yield break;
        battle.ConfigureWaveInstances("clock-guard-primary@archivist");yield return null;
        battle.SetNativeCombatEnabled(true);int before=contacts;battle.PresentPlayerBasic("clock-guard-primary");
        yield return CaptureSequence("basic");
        if(contacts!=before+1){Fail("basic contact count");yield break;}
        battle.SetNativeCombatEnabled(false);yield return null;battle.SetNativeCombatEnabled(true);
        before=contacts;int completeBefore=completions;battle.PresentPlayerSkill("fool_skill_01:clock-guard-primary");
        yield return CaptureSequence("sidestep");
        if(contacts!=before+1 || completions!=completeBefore+1){Fail("sidestep contact/completion count");yield break;}
        battle.SetNativeCombatEnabled(false);yield return null;battle.SetNativeCombatEnabled(true);
        before=contacts;completeBefore=completions;battle.PresentPlayerSkill("fool_skill_01:clock-guard-primary");
        yield return new WaitForSeconds(.3f);battle.SetNativeCombatEnabled(false);yield return new WaitForSeconds(2);
        if(contacts!=before || completions!=completeBefore || GameObject.Find("Fool tarot strike runtime")){Fail("cancel leaked effect/contact");yield break;}
        if(error!=null){Fail(error);yield break;}
        File.WriteAllText(Path.Combine(output,"passed.txt"),"Original early hound / later signature hound / return to original: passed\nEarly fireball contact: exactly one\nBasic and sidestep contact: exactly one each\nSidestep completion: exactly one\nPre-contact cancellation: no damage/completion/effect root\n");
        Debug.Log("SIDESTEP_HOUND_FIX_PASSED");Application.Quit(0);
    }
    bool CheckHound(bool early) {
        var handles=FindObjectsByType<EnemyHandle>(FindObjectsInactive.Include,FindObjectsSortMode.None).Where(h=>h.BattleEnemyId=="hell-hound-primary").ToArray();
        if(handles.Length!=1){Fail("visible hound count "+handles.Length);return false;}
        bool signature=handles[0].GetComponent<SignatureEnemyPresentation>()!=null;
        if(signature==early || (early && handles[0].ProfileEnemyId!="early-hell-hound")){Fail("hound identity mismatch");return false;}
        Debug.Log("HOUND_ROUTE_CHECK "+handles[0].ProfileEnemyId+" signature="+signature);return true;
    }
    IEnumerator CaptureSequence(string prefix) {
        float start=Time.time;int frame=0;
        while(Time.time-start<2.2f){yield return new WaitForEndOfFrame();if(frame%3==0)Capture(prefix+"-"+(frame/3).ToString("D2"));frame++;yield return null;}
    }
    void Capture(string name){var t=ScreenCapture.CaptureScreenshotAsTexture();File.WriteAllBytes(Path.Combine(output,name+".png"),t.EncodeToPNG());Destroy(t);}
    void Fail(string reason){File.WriteAllText(Path.Combine(output,"failed.txt"),reason);Debug.LogError("FIX_FAILED "+reason);Application.Quit(1);}
    void OnDestroy(){Application.logMessageReceived-=Observe;Time.captureFramerate=0;}
}
#endif
