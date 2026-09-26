#if UNITY_EDITOR || UNITY_STANDALONE
using System;
using System.Collections;
using System.IO;
using System.Linq;
using UnityEngine;
public sealed class Q4TwoFlameCapture:MonoBehaviour
{
 string dir;int contacts;
 [RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.AfterSceneLoad)]
 static void Boot(){if(Environment.GetCommandLineArgs().Contains("--verify-q4-two-flame"))new GameObject("Q4 two-flame capture").AddComponent<Q4TwoFlameCapture>();}
 IEnumerator Start()
 {
  dir=Environment.GetEnvironmentVariable("MISTPORT_Q4_CAPTURE")??"/tmp/q4-two-flame";Directory.CreateDirectory(dir);File.Delete(Path.Combine(dir,"passed.txt"));
  Screen.SetResolution(720,1280,false);Application.logMessageReceived+=Count;Time.captureFramerate=30;
  yield return new WaitForSeconds(2);
  var b=FindFirstObjectByType<BattlePrototype>();b.SetNativeCombatEnabled(false);b.UseEarlyHellHoundModel();b.SetNativeCombatEnabled(true);
  b.SetQ4HoundPhase("probe");b.PresentEnemyAttack("hell-hound-primary");yield return new WaitForSeconds(.25f);yield return new WaitForEndOfFrame();Shot("01-probe");yield return new WaitForSeconds(.8f);
  if(contacts!=1)throw new Exception("Probe contact count "+contacts);
  b.SetQ4HoundPhase("charge");yield return new WaitForSeconds(1.7f);yield return new WaitForEndOfFrame();Shot("02-paired-charge");
  b.SetMasquerade(2,false);yield return new WaitForSeconds(.3f);
  b.SetQ4HoundPhase("first");b.PresentEnemyAttack("hell-hound-primary");yield return new WaitForSeconds(.25f);yield return new WaitForEndOfFrame();Shot("03-heavy-first-flight");yield return new WaitForSeconds(.23f);yield return new WaitForEndOfFrame();Shot("04-heavy-first-impact");b.SetMasquerade(1,true);
  yield return new WaitForSeconds(.17f);b.SetQ4HoundPhase("second");b.PresentEnemyAttack("hell-hound-primary");yield return new WaitForSeconds(.25f);yield return new WaitForEndOfFrame();Shot("05-heavy-second-flight");yield return new WaitForSeconds(.23f);yield return new WaitForEndOfFrame();Shot("06-heavy-second-impact");b.SetMasquerade(0,true);b.SetQ4HoundPhase("opening");
  yield return new WaitForSeconds(.6f);if(contacts!=3)throw new Exception("Two flame contacts "+contacts);yield return new WaitForEndOfFrame();Shot("07-opening");
  b.SetQ4HoundPhase("charge");yield return new WaitForSeconds(.2f);b.SetNativeCombatEnabled(false);yield return null;
  if(GameObject.Find("Q4 paired mouth fire warning"))throw new Exception("Charge survived stop");
  b.SetNativeCombatEnabled(true);b.SetQ4HoundPhase("first");b.PresentEnemyAttack("hell-hound-primary");yield return new WaitForSeconds(.15f);b.SetNativeCombatEnabled(false);yield return new WaitForSeconds(.7f);
  if(contacts!=3||GameObject.Find("Q4 heavy pursuit fireball"))throw new Exception("Cancelled shot survived");
  File.WriteAllText(Path.Combine(dir,"passed.txt"),"Probe and two heavy fireballs each contact once; 0.65s stagger captured; charge/flight cancellation clean. Visual-only mask updates; actual block/opening contracts covered in Swift core tests.\n");Application.Quit(0);
 }
 void Count(string m,string s,LogType t){if(m.Contains("\"eventName\":\"combat-contact\"")&&m.Contains("enemy:hell-hound-primary"))contacts++;}
 void Shot(string n){var t=ScreenCapture.CaptureScreenshotAsTexture();File.WriteAllBytes(Path.Combine(dir,n+".png"),t.EncodeToPNG());Destroy(t);}
 void OnDestroy(){Application.logMessageReceived-=Count;Time.captureFramerate=0;}
}
#endif
