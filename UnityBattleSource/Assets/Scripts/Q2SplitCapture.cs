#if UNITY_EDITOR || UNITY_STANDALONE
using System;
using System.Collections;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using UnityEngine;
public sealed class Q2SplitCapture : MonoBehaviour
{
 string dir; readonly Dictionary<string,int> hits=new Dictionary<string,int>();
 [RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.AfterSceneLoad)]
 static void Boot(){if(Environment.GetCommandLineArgs().Contains("--verify-q2-split"))new GameObject("Q2 split verification").AddComponent<Q2SplitCapture>();}
 IEnumerator Start(){
  dir=Environment.GetEnvironmentVariable("MISTPORT_Q2_CAPTURE")??"/tmp/mistport-q2-split";Directory.CreateDirectory(dir);
  File.Delete(Path.Combine(dir,"passed.txt"));File.Delete(Path.Combine(dir,"failed.txt"));
  Screen.SetResolution(720,1024,false);yield return new WaitForSeconds(2);Time.captureFramerate=30;
  Application.logMessageReceived+=OnLog;
  var b=FindFirstObjectByType<BattlePrototype>();var bridge=FindFirstObjectByType<UnityBattleBridge>();
  bridge.ResetEnemyExitPresentation();b.SetNativeCombatEnabled(false);b.UseDualClockGuardModel();
  yield return new WaitForSeconds(.3f);
  var children=FindObjectsByType<EnemyHandle>(FindObjectsInactive.Include,FindObjectsSortMode.None).Where(h=>h.BattleEnemyId.StartsWith("clock-guard-instance-")&&b.BelongsToCurrentEncounter(h)).OrderBy(h=>h.BattleEnemyId).ToArray();
  if(children.Length!=4||children.Any(h=>h.gameObject.activeSelf)){Fail("Children not four dormant registered actors");yield break;}
  yield return new WaitForEndOfFrame();Shot("01-two-original-ghosts");
  bridge.SetEnemyVisibility("clock-guard-primary=hidden");yield return new WaitForSeconds(.5f);yield return new WaitForEndOfFrame();Shot("02-first-parent-fading");
  yield return new WaitForSeconds(.6f);bridge.SetEnemyVisibility("clock-guard-instance-3=visible;clock-guard-instance-4=visible");
  yield return new WaitForSeconds(.3f);yield return new WaitForEndOfFrame();Shot("03-one-parent-two-children");
  bridge.SetEnemyVisibility("clock-guard-secondary=hidden");yield return new WaitForSeconds(1.1f);
  bridge.SetEnemyVisibility("clock-guard-instance-5=visible;clock-guard-instance-6=visible");yield return new WaitForSeconds(.3f);yield return new WaitForEndOfFrame();Shot("04-four-red-ghosts");
  if(children.Any(h=>!h.gameObject.activeSelf||!h.GetComponentInChildren<FogGhostActor>().IsSplit)){Fail("Missing red children");yield break;}
  b.SetNativeCombatEnabled(true);
  foreach(var child in children){b.PresentEnemyAttack(child.BattleEnemyId);yield return new WaitForSeconds(4);if(!hits.TryGetValue(child.BattleEnemyId,out int n)||n!=1){Fail("Contact count "+child.BattleEnemyId+"="+n);yield break;}}
  bridge.SetEnemyVisibility(string.Join(";",children.Select(h=>h.BattleEnemyId+"=hidden")));yield return new WaitForSeconds(.5f);yield return new WaitForEndOfFrame();Shot("05-children-death-fade");
  yield return new WaitForSeconds(.7f);if(children.Any(h=>h.gameObject.activeSelf)){Fail("Children death not hidden");yield break;}
  bridge.ResetEnemyExitPresentation();b.SetNativeCombatEnabled(false);b.UseDualClockGuardModel();
  if(children.Any(h=>h.gameObject.activeSelf)){Fail("Children persisted across retry");yield break;}
  b.UseEarlyHellHoundModel();if(children.Any(h=>b.BelongsToCurrentEncounter(h))){Fail("Children remain in next encounter roster");yield break;}
  File.WriteAllText(Path.Combine(dir,"passed.txt"),"Two originals, per-parent fade/reveal, four red staggered children, four exact-once contacts, child fades, retry and encounter cleanup passed. Native reveal delay is separately owned by Swift.");Application.Quit(0);
 }
 void OnLog(string message,string stack,LogType type){if(!message.Contains("combat-contact"))return;for(int i=3;i<=6;i++){string id="clock-guard-instance-"+i;if(message.Contains("enemy:"+id))hits[id]=hits.TryGetValue(id,out int n)?n+1:1;}}
 void Shot(string name){var t=ScreenCapture.CaptureScreenshotAsTexture();File.WriteAllBytes(Path.Combine(dir,name+".png"),t.EncodeToPNG());Destroy(t);}
 void Fail(string s){File.WriteAllText(Path.Combine(dir,"failed.txt"),s);Debug.LogError("Q2_SPLIT_FAILED "+s);Application.Quit(1);}
 void OnDestroy(){Application.logMessageReceived-=OnLog;Time.captureFramerate=0;}
}
#endif
