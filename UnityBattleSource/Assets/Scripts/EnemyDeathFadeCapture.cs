#if UNITY_EDITOR || UNITY_STANDALONE
using System;
using System.Collections;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using UnityEngine;
public sealed class EnemyDeathFadeCapture : MonoBehaviour
{
 string dir; readonly List<string> results=new List<string>();
 [RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.AfterSceneLoad)]
 static void Boot(){if(Environment.GetCommandLineArgs().Contains("--verify-enemy-death-fade"))new GameObject("Enemy death fade verification").AddComponent<EnemyDeathFadeCapture>();}
 IEnumerator Start(){
  dir=Environment.GetEnvironmentVariable("MISTPORT_FADE_CAPTURE")??"/tmp/mistport-death-fade";Directory.CreateDirectory(dir);
  File.Delete(Path.Combine(dir,"passed.txt"));File.Delete(Path.Combine(dir,"failed.txt"));
  Screen.SetResolution(720,1024,false);yield return new WaitForSeconds(2);Time.captureFramerate=30;
  var b=FindFirstObjectByType<BattlePrototype>();var bridge=FindFirstObjectByType<UnityBattleBridge>();
  string[] names={"guard","ghost","early-hound","armored-hound","emerald","core","leech","archivist","matriarch"};
  for(int test=0;test<names.Length;test++){
   bridge.ResetEnemyExitPresentation();b.SetNativeCombatEnabled(false);b.SetEncoreRevenant(false);
   if(test==0)b.UseClockGuardModel();else if(test==1)b.UseDualClockGuardModel();else if(test==2)b.UseEarlyHellHoundModel();
   else if(test==3||test==4){b.UseHellHoundModel();if(test==4)b.SetEncoreRevenant(true);}
   else if(test==5)b.UseClockCoreModel();else if(test==6)b.UseP1Escort(true);
   else b.ConfigureWaveInstances("clock-guard-primary@"+(test==7?"archivist":"matriarch"));
   yield return new WaitForSeconds(.25f);
   var handles=FindObjectsByType<EnemyHandle>(FindObjectsSortMode.None);
   var h=test==6?handles.First(x=>x.GetComponentInChildren<MemoryLeechPresentation>()):test==5?handles.First(x=>x.BattleEnemyId==EnemyBattleIds.ClockCorePrimary):handles.First();
   var renderers=h.GetComponentsInChildren<Renderer>().Where(r=>r.enabled).ToArray();
   var original=renderers.Select(r=>r.sharedMaterials).ToArray();
   foreach(var material in original.SelectMany(ms=>ms).Where(m=>m)) {
    string shader=material.shader.name;
    if(shader!="Standard" && shader!="Mistport/Character Surface 20260916" && shader!="Mindstone/Memory Leech GLTF" && !(material.renderQueue>=3000&&(material.HasProperty("_Color")||material.HasProperty("_Opacity")))) {
     Fail(names[test]+" unsupported live material "+shader);yield break;
    }
    results.Add(names[test]+" source shader: "+shader);
   }
   yield return new WaitForEndOfFrame();Shot(names[test]+"-before");
   bridge.SetEnemyVisibility(h.BattleEnemyId+"=hidden");
   float wait=0;
   while(!renderers.Any(r=>r.sharedMaterials.Any(m=>m&&m.shader.name.Contains("Fade")))&&wait<10){wait+=Time.deltaTime;yield return null;}
   if(wait>=10){Fail(names[test]+" did not enter fade");yield break;}
   yield return new WaitForSeconds(.45f);yield return new WaitForEndOfFrame();Shot(names[test]+"-middle");
   if(!h.gameObject.activeSelf){Fail(names[test]+" hidden before fade completed");yield break;}
   var fading=renderers.SelectMany(r=>r.sharedMaterials).Where(m=>m&&m.shader.name.Contains("Fade")).ToArray();
   if(fading.Length==0||fading.Any(m=>{float a=m.HasProperty("_ExitOpacity")?m.GetFloat("_ExitOpacity"):m.color.a;return a<=0||a>=.9f;})){Fail(names[test]+" missing fractional fade");yield break;}
   // Mid-fade reappearance must immediately restore source materials.
   bridge.SetEnemyVisibility(h.BattleEnemyId+"=visible");
   if(renderers.Where((r,i)=>!r.sharedMaterials.SequenceEqual(original[i])).Any()){Fail(names[test]+" cancel material restore");yield break;}
   bridge.SetEnemyVisibility(h.BattleEnemyId+"=hidden");
   yield return new WaitForSeconds(test==6?6:1.2f);yield return new WaitForEndOfFrame();Shot(names[test]+"-after");
   if(h.gameObject.activeSelf){Fail(names[test]+" still active after death");yield break;}
   if(renderers.Where((r,i)=>!r.sharedMaterials.SequenceEqual(original[i])).Any()){Fail(names[test]+" final material restore");yield break;}
   bridge.SetEnemyVisibility(h.BattleEnemyId+"=visible");
   results.Add(names[test]+": fractional fade, 1 second fade completion, mid-fade cancellation and final source restoration passed");
  }
  File.WriteAllLines(Path.Combine(dir,"passed.txt"),results);Debug.Log("ENEMY_DEATH_FADE_PASSED");Application.Quit(0);
 }
 void Shot(string name){var t=ScreenCapture.CaptureScreenshotAsTexture();File.WriteAllBytes(Path.Combine(dir,name+".png"),t.EncodeToPNG());Destroy(t);}
 void Fail(string s){File.WriteAllText(Path.Combine(dir,"failed.txt"),s);Debug.LogError("ENEMY_DEATH_FADE_FAILED "+s);Application.Quit(1);}
 void OnDestroy(){Time.captureFramerate=0;}
}
#endif
