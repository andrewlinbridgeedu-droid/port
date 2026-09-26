#if UNITY_EDITOR || UNITY_STANDALONE
using System;
using System.Collections;
using System.IO;
using System.Linq;
using UnityEngine;
public sealed class ProgressionRosterCapture:MonoBehaviour {
 string dir;int contacts;float began;
 [RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.AfterSceneLoad)]static void Boot(){if(Environment.GetCommandLineArgs().Contains("--verify-progression-rosters"))new GameObject("Progression roster audit").AddComponent<ProgressionRosterCapture>();}
 IEnumerator Start(){
 dir=Environment.GetEnvironmentVariable("MISTPORT_PROGRESSION_CAPTURE")??"/tmp/progression-rosters";Directory.CreateDirectory(dir);File.Delete(Path.Combine(dir,"passed.txt"));Screen.SetResolution(720,1280,false);Time.captureFramerate=30;Application.logMessageReceived+=Count;
 yield return new WaitForSeconds(3);var b=FindFirstObjectByType<BattlePrototype>();
 string[] waves={"clock-guard-primary,clock-core-primary","hell-hound-primary,clock-guard-primary@archivist","memory-leech-primary,memory-leech-secondary,clock-guard-primary","clock-guard-primary,clock-guard-secondary","clock-guard-primary,clock-core-primary","memory-leech-primary,clock-guard-primary","clock-guard-primary@matriarch,clock-core-primary,clock-core-secondary"};
 for(int n=9;n<=15;n++){
 b.SetNativeCombatEnabled(false);b.ConfigureWaveInstances(waves[n-9]);b.SetEarlyBattlePresence(n.ToString());b.SetNativeCombatEnabled(true);yield return new WaitForSeconds(.5f);
 var actors=FindObjectsByType<EnemyHandle>(FindObjectsSortMode.None).Where(h=>b.BelongsToCurrentEncounter(h)).OrderBy(h=>h.BattleEnemyId).ToArray();
 if(actors.Length!=waves[n-9].Split(',').Length)throw new Exception("Roster mismatch Q"+n);
 yield return new WaitForEndOfFrame();var tex=ScreenCapture.CaptureScreenshotAsTexture();File.WriteAllBytes(Path.Combine(dir,"q"+n+".png"),tex.EncodeToPNG());Destroy(tex);
 foreach(var actor in actors){contacts=0;began=Time.time;b.PresentEnemyAttack(actor.BattleEnemyId+(n==13&&actor.BattleEnemyId.StartsWith("clock-guard-")?":thirteenth_charge":""));yield return new WaitForSeconds(4);if(contacts!=1)throw new Exception("Q"+n+" "+actor.BattleEnemyId+" contacts "+contacts);}
 if(n==15){
 contacts=0;began=Time.time;
 b.PresentEnemyAttack("clock-core-primary:repair_guard:clock-guard-primary");yield return new WaitForSeconds(.2f);
 b.PresentEnemyAttack("clock-core-secondary:repair_guard:clock-guard-primary");yield return new WaitForSeconds(1.1f);
 if(contacts!=2)throw new Exception("Concurrent repair lost contact: "+contacts);
 contacts=0;b.PresentEnemyAttack("clock-core-primary:repair_guard:clock-guard-primary");b.PresentEnemyAttack("clock-core-secondary:repair_guard:clock-guard-primary");b.SetNativeCombatEnabled(false);yield return new WaitForSeconds(1.1f);
 if(contacts!=0)throw new Exception("Repair survived cancellation");
 }
 b.SetNativeCombatEnabled(false);yield return null;
 }
 File.WriteAllText(Path.Combine(dir,"passed.txt"),"Q9–15 actual roster count and each actor attack exactly one contact; screenshots and Unity contact timing only, not native full victories.");Application.Quit(0);
 }
 void Count(string m,string s,LogType t){if(m.Contains("\"eventName\":\"combat-contact\"")&&m.Contains("enemy:")){contacts++;File.AppendAllText(Path.Combine(dir,"timing.txt"),(Time.time-began).ToString("F3")+" "+m+"\n");}}
 void OnDestroy(){Application.logMessageReceived-=Count;Time.captureFramerate=0;}
}
#endif
