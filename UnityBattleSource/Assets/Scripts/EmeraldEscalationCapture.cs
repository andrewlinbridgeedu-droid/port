#if UNITY_EDITOR || UNITY_STANDALONE
using System;
using System.Collections;
using System.IO;
using System.Linq;
using UnityEngine;
public sealed class EmeraldEscalationCapture : MonoBehaviour
{
    string dir; int contacts;
    [RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.AfterSceneLoad)]
    static void Boot() { if(Environment.GetCommandLineArgs().Contains("--verify-emerald-escalation")) new GameObject("Emerald escalation verification").AddComponent<EmeraldEscalationCapture>(); }
    IEnumerator Start() {
        dir=Environment.GetEnvironmentVariable("MISTPORT_FIX_CAPTURE")??"/tmp/emerald-escalation";Directory.CreateDirectory(dir);
        File.Delete(Path.Combine(dir,"passed.txt"));Screen.SetResolution(720,1280,false);
        Application.logMessageReceived+=Count;yield return new WaitForSeconds(2);Time.captureFramerate=30;
        var b=FindFirstObjectByType<BattlePrototype>();var bridge=FindFirstObjectByType<UnityBattleBridge>();
        b.SetNativeCombatEnabled(false);b.UseHellHoundModel();b.SetEncoreRevenant(true);b.SetNativeCombatEnabled(true);b.SetEmeraldSpell("mist");
        bridge.ApplyCommand("{\"action\":\"enemy:hell-hound-primary\"}");
        yield return new WaitForSeconds(1.0f);yield return new WaitForEndOfFrame();Shot("01-opening-poison-cast");
        yield return new WaitForSeconds(1.5f);if(contacts!=1)throw new Exception("Mist must contact once: "+contacts);
        b.SetEmeraldPoison(1);yield return new WaitForSeconds(1);yield return new WaitForEndOfFrame();Shot("02-thin-persistent-mist");
        yield return new WaitForSeconds(.75f);yield return new WaitForEndOfFrame();Shot("02b-thin-mist-motion");
        b.PresentEncoreCharge();yield return new WaitForSeconds(1.1f);yield return new WaitForEndOfFrame();Shot("03-green-body-heavy-warning");
        if(!GameObject.Find("Encore Full Body Fire"))throw new Exception("No body green flame telegraph");
        b.SetMasquerade(2,false);yield return new WaitForSeconds(.8f);yield return new WaitForEndOfFrame();Shot("04-mask-held-for-heavy");
        b.PresentEncoreRelease();b.SetEmeraldSpell("burst");bridge.ApplyCommand("{\"action\":\"enemy:hell-hound-primary\"}");
        yield return new WaitForSeconds(1.1f);yield return new WaitForEndOfFrame();Shot("05-heavy-release");
        yield return new WaitForSeconds(1.5f);if(contacts!=2)throw new Exception("Burst must contact once: "+contacts);
        b.SetMasquerade(1,true);
        for(int level=2;level<=8;level++){b.SetEmeraldPoison(level);yield return new WaitForSeconds(3);if(level==4||level==8){yield return new WaitForEndOfFrame();Shot("06-mist-level-"+level);yield return new WaitForSeconds(.75f);yield return new WaitForEndOfFrame();Shot("06b-mist-motion-level-"+level);}}
        for(int frame=0;frame<16;frame++){yield return new WaitForSeconds(.12f);yield return new WaitForEndOfFrame();Shot("07-high-motion-"+frame.ToString("D2"));}
        var field=b.GetComponent<EmeraldPoisonField>();if(!field.IsActive||field.IntensityLevel!=8)throw new Exception("Poison did not persist/escalate");
        b.PresentEncoreCharge();yield return new WaitForSeconds(.3f);b.SetNativeCombatEnabled(false);yield return null;
        if(field.IsActive||GameObject.Find("Encore Full Body Fire"))throw new Exception("Poison/flame survived exit");
        b.SetNativeCombatEnabled(true);b.SetEmeraldPoison(1);yield return new WaitForSeconds(.4f);if(field.IntensityLevel!=1)throw new Exception("Retry retained density level");b.SetNativeCombatEnabled(false);yield return null;
        File.WriteAllText(Path.Combine(dir,"passed.txt"),"Initial mist and heavy attack each contact once. Levels 1/4/8 persist and increase. Body flame and mask captured. Stop clears mist/flame; retry starts level1. Presentation-only sequence; combat numbers verified separately.\n");Debug.Log("EMERALD_ESCALATION_PASSED");Application.Quit(0);
    }
    void Count(string message,string stack,LogType type){if(message.Contains("\"eventName\":\"combat-contact\"")&&message.Contains("enemy:hell-hound-primary"))contacts++;}
    void Shot(string name){var t=ScreenCapture.CaptureScreenshotAsTexture();File.WriteAllBytes(Path.Combine(dir,name+".png"),t.EncodeToPNG());Destroy(t);}
    void OnDestroy(){Application.logMessageReceived-=Count;Time.captureFramerate=0;}
}
#endif
