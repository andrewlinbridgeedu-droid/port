#if UNITY_EDITOR || UNITY_STANDALONE
using System;
using System.Collections;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using UnityEngine;
public sealed class EarlyBattleFixCapture : MonoBehaviour
{
    string dir; readonly List<string> results = new List<string>();
    [RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.AfterSceneLoad)]
    static void Boot(){if(Environment.GetCommandLineArgs().Contains("--verify-early-battle"))new GameObject("Early battle verification").AddComponent<EarlyBattleFixCapture>();}
    IEnumerator Start(){
        dir=Environment.GetEnvironmentVariable("MISTPORT_FIX_CAPTURE")??"/tmp/mistport-early-battle";Directory.CreateDirectory(dir);
        File.Delete(Path.Combine(dir,"passed.txt"));File.Delete(Path.Combine(dir,"failed.txt"));
        Screen.SetResolution(720,1024,false);yield return new WaitForSeconds(2);Time.captureFramerate=30;
        var b=FindFirstObjectByType<BattlePrototype>();
        for(int stage=1;stage<=6;stage++){
            b.SetNativeCombatEnabled(false);b.SetEncoreRevenant(false);
            if(stage==1)b.UseClockGuardModel();else if(stage==2)b.UseDualClockGuardModel();else if(stage==5){b.UseHellHoundModel();b.SetEncoreRevenant(true);}else b.UseEarlyHellHoundModel();
            b.SetEarlyBattlePresence(stage.ToString());yield return new WaitForSeconds(.3f);
            var handles=FindObjectsByType<EnemyHandle>(FindObjectsSortMode.None);
            var rootPositions=handles.Select(h=>h.transform.position).ToArray();
            var actorTransforms=handles.Select(h=>h.GetComponent<EarlyEnemyIdlePresence>().VisibleActor.GetComponentsInChildren<Transform>()).ToArray();
            var rotations=actorTransforms.Select(ts=>ts.Select(t=>t.localRotation).ToArray()).ToArray();
            yield return new WaitForEndOfFrame();Shot("q"+stage+"-idle-a");
            yield return new WaitForSeconds(1.3f);
            yield return new WaitForEndOfFrame();Shot("q"+stage+"-idle-b");
            for(int i=0;i<handles.Length;i++)if(Vector3.Distance(rootPositions[i],handles[i].transform.position)>.001f){Fail("stage root drift "+stage);yield break;}
            for(int actor=0;actor<handles.Length;actor++) {
                float changed=0;for(int i=0;i<actorTransforms[actor].Length;i++)changed=Mathf.Max(changed,Quaternion.Angle(rotations[actor][i],actorTransforms[actor][i].localRotation));
                if(changed<.05f){Fail("no visible idle Q"+stage+" "+handles[actor].BattleEnemyId);yield break;}
                results.Add("Q"+stage+" "+handles[actor].BattleEnemyId+" visible idle rotation delta="+changed+" root drift=0");
            }
            b.SetNativeCombatEnabled(true);
            if(FindObjectsByType<EarlyEnemyIdlePresence>(FindObjectsSortMode.None).Any(p=>!p.IsSuspended)){Fail("presence not suspended for combat");yield break;}
        }
        b.SetNativeCombatEnabled(false);b.SetEncoreRevenant(false);b.UseP1Escort(false);b.SetEarlyBattlePresence("7");
        FindFirstObjectByType<UnityBattleBridge>().SetEnemyVisibility("hell-hound-primary=visible");yield return null;
        var current=FindObjectsByType<EnemyHandle>(FindObjectsSortMode.None);
        if(current.Length!=3 || current.Any(h=>h.BattleEnemyId=="hell-hound-primary")){Fail("Q7 stale hound visibility");yield break;}
        yield return new WaitForEndOfFrame();Shot("q7-correct-roster");results.Add("Q7 two guards and core; stale hound visibility rejected");
        File.WriteAllLines(Path.Combine(dir,"passed.txt"),results);Debug.Log("EARLY_BATTLE_FIX_PASSED");Application.Quit(0);
    }
    void Shot(string name){var t=ScreenCapture.CaptureScreenshotAsTexture();File.WriteAllBytes(Path.Combine(dir,name+".png"),t.EncodeToPNG());Destroy(t);}
    void Fail(string message){File.WriteAllText(Path.Combine(dir,"failed.txt"),message);Debug.LogError("EARLY_BATTLE_FIX_FAILED "+message);Application.Quit(1);}
    void OnDestroy(){Time.captureFramerate=0;}
}
#endif
