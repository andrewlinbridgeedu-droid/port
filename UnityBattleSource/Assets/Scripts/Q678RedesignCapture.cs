#if UNITY_EDITOR || UNITY_STANDALONE
using System;
using System.Collections;
using System.IO;
using System.Linq;
using UnityEngine;
public sealed class Q678RedesignCapture:MonoBehaviour
{
 string dir;int contacts;
 [RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.AfterSceneLoad)]
 static void Boot(){if(Environment.GetCommandLineArgs().Contains("--verify-q678-redesign"))new GameObject("Q678 redesign capture").AddComponent<Q678RedesignCapture>();}
 IEnumerator Start(){
  dir=Environment.GetEnvironmentVariable("MISTPORT_Q678_CAPTURE")??"/tmp/q678-redesign";Directory.CreateDirectory(dir);File.Delete(Path.Combine(dir,"passed.txt"));
  Screen.SetResolution(720,1280,false);Application.logMessageReceived+=Count;Time.captureFramerate=30;
  yield return new WaitForSeconds(3);var b=FindFirstObjectByType<BattlePrototype>();b.SetNativeCombatEnabled(false);
  b.ConfigureWaveInstances("clock-guard-primary@archivist");b.SetNativeCombatEnabled(true);CheckRoster(b,1);
  b.SetArchivePhase("guard");yield return new WaitForSeconds(.3f);yield return Shot("q6-guard");
  b.PresentEnemyAttack("clock-guard-primary:archive_slam");yield return new WaitForSeconds(.7f);yield return Shot("q6-slam");yield return new WaitForSeconds(1f);yield return Shot("q6-flight");yield return new WaitForSeconds(.22f);yield return Shot("q6-auger-flight");yield return new WaitForSeconds(.28f);yield return Shot("q6-impact");yield return new WaitForSeconds(5);
  if(contacts!=1)throw new Exception("Q6 contacts "+contacts);b.SetArchivePhase("open");yield return new WaitForSeconds(.3f);yield return Shot("q6-open");
  b.SetNativeCombatEnabled(false);b.UseP1Escort(false);b.SetNativeCombatEnabled(true);CheckRoster(b,3);
  var core=FindObjectsByType<EnemyHandle>(FindObjectsSortMode.None).Single(h=>h.BattleEnemyId=="clock-core-primary");
  if(!core.GetComponentsInChildren<Renderer>().Any(r=>r.enabled))throw new Exception("Core missing renderers");
  yield return new WaitForSeconds(.4f);yield return Shot("q7-three-enemies");
  b.PresentEnemyAttack("clock-core-primary:repair_guard:clock-guard-secondary");yield return new WaitForSeconds(.45f);yield return Shot("q7-repair");yield return new WaitForSeconds(.6f);
  if(contacts!=2)throw new Exception("Repair contacts "+contacts);
  b.PresentEnemyHealing("clock-guard-secondary");yield return new WaitForSeconds(.3f);yield return Shot("q7-heal-confirmed");yield return new WaitForSeconds(.7f);
  // Missing and dead frozen recipients must acknowledge the committed cast,
  // without selecting a different guard or leaving native pending forever.
  b.PresentEnemyAttack("clock-core-primary:repair_guard:none");yield return new WaitForSeconds(1);
  if(contacts!=3)throw new Exception("No-recipient repair contacts "+contacts);
  var guard=FindObjectsByType<EnemyHandle>(FindObjectsSortMode.None).Single(h=>h.BattleEnemyId=="clock-guard-secondary");
  b.PresentEnemyAttack("clock-core-primary:repair_guard:clock-guard-secondary");yield return new WaitForSeconds(.2f);
  guard.gameObject.SetActive(false);yield return new WaitForSeconds(.9f);
  if(contacts!=4)throw new Exception("Dead-recipient repair contacts "+contacts);guard.gameObject.SetActive(true);
  b.PresentEnemyAttack("clock-core-primary:repair_guard:clock-guard-secondary");yield return new WaitForSeconds(.2f);
  core.gameObject.SetActive(false);yield return new WaitForSeconds(.9f);
  if(contacts!=5)throw new Exception("Missing-source repair contacts "+contacts);core.gameObject.SetActive(true);

  b.SetNativeCombatEnabled(false);b.ConfigureWaveInstances("memory-leech-primary");b.SetNativeCombatEnabled(true);CheckRoster(b,1);
  b.SetLeechCharge("on");yield return new WaitForSeconds(1.4f);yield return Shot("q8-charge");
  b.SetLeechCharge("restrained");yield return new WaitForSeconds(.3f);yield return Shot("q8-restrained");
  b.PresentEnemyAttack("memory-leech-primary:name_devour");yield return new WaitForSeconds(.7f);yield return Shot("q8-devour");yield return new WaitForSeconds(1);
  if(contacts!=6)throw new Exception("Devour contacts "+contacts);
  b.SetLeechCharge("on");b.SetNativeCombatEnabled(false);yield return null;
  if(FindFirstObjectByType<ArchiveEncounterPresentation>().HasPresentation)throw new Exception("Phase survived stop");
  b.UseP1Escort(false);b.SetNativeCombatEnabled(true);b.PresentEnemyAttack("clock-core-primary:repair_guard:clock-guard-primary");yield return new WaitForSeconds(.2f);b.SetNativeCombatEnabled(false);yield return new WaitForSeconds(1);
  if(contacts!=6)throw new Exception("Cancelled repair emitted contact");
  File.WriteAllText(Path.Combine(dir,"passed.txt"),"Q6 single archivist, Q7 3 active actors including core, Q8 solo leech. Archive attack, targeted repair and devour each contact once; missing/dead recipient and missing source each acknowledge once; phase/repair cancellation clean. Screenshots are standalone presentation evidence, not native combat acceptance.\n");Application.Quit(0);
 }
 void CheckRoster(BattlePrototype b,int count){var active=FindObjectsByType<EnemyHandle>(FindObjectsSortMode.None).Where(h=>b.BelongsToCurrentEncounter(h)).ToArray();if(active.Length!=count)throw new Exception("Roster "+active.Length+" expected "+count+": "+string.Join(",",active.Select(h=>h.BattleEnemyId)));}
 void Count(string m,string s,LogType t){if(m.Contains("\"eventName\":\"combat-contact\"")&&m.Contains("enemy:"))contacts++;}
 IEnumerator Shot(string n){yield return new WaitForEndOfFrame();var t=ScreenCapture.CaptureScreenshotAsTexture();File.WriteAllBytes(Path.Combine(dir,n+".png"),t.EncodeToPNG());Destroy(t);}
 void OnDestroy(){Application.logMessageReceived-=Count;Time.captureFramerate=0;}
}
#endif
