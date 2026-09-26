#if UNITY_EDITOR || UNITY_STANDALONE
using System;
using System.Collections;
using System.IO;
using System.Linq;
using UnityEngine;
public sealed class SidestepCinematicCapture:MonoBehaviour {
 string output;int contacts,completions;string error;
 [RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.AfterSceneLoad)] static void Boot(){if(Environment.GetCommandLineArgs().Contains("--verify-sidestep-cinematic"))new GameObject("Sidestep cinematic capture").AddComponent<SidestepCinematicCapture>();}
 void Observe(string message,string stack,LogType type){if(type==LogType.Exception||type==LogType.Assert)error=message;if(message.Contains("\"eventName\":\"combat-contact\",\"value\":\"player\""))contacts++;if(message.Contains("\"eventName\":\"presentation-complete\",\"value\":\"fool_skill_01\""))completions++;}
 IEnumerator Start(){output=Environment.GetEnvironmentVariable("MISTPORT_SIDESTEP_CAPTURE")??"/tmp/sidestep-cinematic";Directory.CreateDirectory(output);Application.logMessageReceived+=Observe;Screen.SetResolution(720,1280,false);yield return new WaitForSeconds(2);Time.captureFramerate=30;
 var battle=FindFirstObjectByType<BattlePrototype>();battle.SetNativeCombatEnabled(false);battle.UseDualClockGuardModel();yield return new WaitForSeconds(.4f);var bridge=FindFirstObjectByType<UnityBattleBridge>();bridge.SetEnemyVisibility("clock-guard-primary=hidden;clock-guard-secondary=hidden");yield return new WaitForSeconds(1.1f);bridge.SetEnemyVisibility("clock-guard-instance-3=visible;clock-guard-instance-4=visible;clock-guard-instance-5=visible;clock-guard-instance-6=visible");yield return new WaitForSeconds(.3f);battle.SetNativeCombatEnabled(true);battle.SetSidestepSecondary("clock-guard-instance-5");battle.PresentPlayerSkill("fool_skill_01:clock-guard-instance-3");yield return CaptureSequence("dual");if(contacts!=1||completions!=1){Fail("dual callback "+contacts+" "+completions);yield break;}
 bridge.SetEnemyVisibility("clock-guard-instance-4=hidden;clock-guard-instance-5=hidden;clock-guard-instance-6=hidden");yield return new WaitForSeconds(1.1f);battle.SetSidestepSecondary("");battle.PresentPlayerSkill("fool_skill_01:clock-guard-instance-3");yield return CaptureSequence("single");if(contacts!=2||completions!=2){Fail("single callback");yield break;}
 bridge.SetEnemyVisibility("clock-guard-instance-5=visible");battle.SetSidestepSecondary("clock-guard-instance-5");battle.PresentPlayerSkill("fool_skill_01:clock-guard-instance-3");yield return new WaitForSeconds(.3f);battle.SetNativeCombatEnabled(false);yield return new WaitForSeconds(2);if(contacts!=2||completions!=2||GameObject.Find("Fool tarot strike runtime")){Fail("cancel leaked");yield break;}if(error!=null){Fail(error);yield break;}File.WriteAllText(Path.Combine(output,"passed.txt"),"Dual 4 complete silhouettes in distinct lanes; single 2 silhouettes with other enemies hidden. Dual and single each exactly one contact/completion. Precontact cancel no callbacks, no effect root.\n");Application.Quit(0);}
 IEnumerator CaptureSequence(string prefix){float start=Time.time;int frame=0;bool checkedCopies=false;while(Time.time-start<2.2f){yield return new WaitForEndOfFrame();
 if(!checkedCopies && Time.time-start>.28f) {
 checkedCopies=true;
 var effect=GameObject.Find("Fool tarot strike runtime");
 var clones=effect.GetComponentsInChildren<Transform>().Where(x=>x.name.StartsWith("Sidestep hero clone lane ")).ToArray();
 int expected=prefix=="dual"?4:2;
 if(clones.Length!=expected || clones.Any(x=>x.GetComponentsInChildren<MeshRenderer>().Length==0)) {Fail(prefix+" logical clone count "+clones.Length);yield break;}
 if(expected==4 && Vector3.Distance((clones[0].position+clones[1].position)*.5f,(clones[2].position+clones[3].position)*.5f)<.1f) {Fail("dual routes collapsed");yield break;}
 File.AppendAllText(Path.Combine(output,"clone-counts.txt"),prefix+" logical clones="+clones.Length+" positions="+string.Join(";",clones.Select(x=>x.name+":"+x.position))+"\n");
 }
 if(frame%3==0){var t=ScreenCapture.CaptureScreenshotAsTexture();File.WriteAllBytes(Path.Combine(output,prefix+"-"+(frame/3).ToString("D2")+".png"),t.EncodeToPNG());Destroy(t);}frame++;yield return null;}}
 void Fail(string why){File.WriteAllText(Path.Combine(output,"failed.txt"),why);Debug.LogError(why);Application.Quit(1);}void OnDestroy(){Application.logMessageReceived-=Observe;Time.captureFramerate=0;}
}
#endif
