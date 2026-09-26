#if UNITY_EDITOR || UNITY_STANDALONE
using System;
using System.Collections;
using System.IO;
using System.Linq;
using UnityEngine;
public sealed class StoryModelCapture20260916 : MonoBehaviour {
 string dir;int contacts;BattlePrototype battle;
 [RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.AfterSceneLoad)]
 static void Boot(){if(Environment.GetCommandLineArgs().Contains("--verify-story-models"))new GameObject("Story model verification").AddComponent<StoryModelCapture20260916>();}
 IEnumerator Start(){
  dir=Environment.GetEnvironmentVariable("MISTPORT_STORY_CAPTURE")??"/tmp/story-models";Directory.CreateDirectory(dir);
  Screen.SetResolution(540,960,false);Time.captureFramerate=12;Application.logMessageReceived+=Count;
  yield return new WaitForSeconds(3);battle=FindFirstObjectByType<BattlePrototype>();
  foreach(var model in new[]{"scribe","rescue"}){
   battle.SetNativeCombatEnabled(false);battle.ConfigureWaveInstances("clock-guard-primary@"+model);battle.SetEarlyBattlePresence(model=="scribe"?"9":"13");
   yield return new WaitForSeconds(.5f);
   var h=FindObjectsByType<EnemyHandle>(FindObjectsSortMode.None).Single(x=>battle.BelongsToCurrentEncounter(x));
   if(h.ProfileEnemyId!=model)throw new Exception("Wrong story model "+h.ProfileEnemyId);
   var skin=h.GetComponentInChildren<SkinnedMeshRenderer>();if(!skin||skin.bones.Length<16)throw new Exception("Missing rig");
   Directory.CreateDirectory(Path.Combine(dir,model));
   for(int f=0;f<36;f++){yield return Shot(model+"/frame-"+f.ToString("D3"));}
   battle.SetNativeCombatEnabled(true);int prior=contacts;battle.PresentEnemyAttack(h.BattleEnemyId);
   for(int f=36;f<78;f++){yield return Shot(model+"/frame-"+f.ToString("D3"));}
   if(contacts!=prior+1)throw new Exception(model+" contact count "+(contacts-prior));
   prior=contacts;battle.PresentEnemyAttack(h.BattleEnemyId);yield return new WaitForSeconds(.2f);battle.SetNativeCombatEnabled(false);yield return new WaitForSeconds(1.5f);
   if(contacts!=prior)throw new Exception(model+" cancelled contact");
  }
  foreach(var wave in new[]{"clock-guard-primary@scribe,clock-core-primary","clock-guard-primary@scribe,clock-guard-secondary@scribe","clock-guard-primary@rescue,clock-core-primary","memory-leech-primary,clock-guard-primary@scribe"}){
   battle.SetNativeCombatEnabled(false);battle.ConfigureWaveInstances(wave);yield return new WaitForSeconds(.5f);
   if(FindObjectsByType<EnemyHandle>(FindObjectsSortMode.None).Count(x=>battle.BelongsToCurrentEncounter(x))!=2)throw new Exception("Wrong story roster "+wave);
   yield return Shot("roster-"+(wave.Contains("rescue")?"13":wave.StartsWith("memory")?"14":wave.Contains("secondary")?"12":"9"));
  }
  File.WriteAllText(Path.Combine(dir,"passed.txt"),"Scribe and rescue independent rigs, actual animation frames, one contact, cancelled casts no contact. Q9/12/13/14 exact two-actor rosters. Not native progression or phone acceptance.");Application.Quit(0);
 }
 IEnumerator Shot(string n){yield return null;yield return new WaitForEndOfFrame();var t=ScreenCapture.CaptureScreenshotAsTexture();File.WriteAllBytes(Path.Combine(dir,n+".png"),t.EncodeToPNG());Destroy(t);}
 void Count(string m,string s,LogType t){if(m.Contains("\"eventName\":\"combat-contact\"")&&m.Contains("enemy:"))contacts++;}
 void OnDestroy(){Application.logMessageReceived-=Count;Time.captureFramerate=0;}
}
#endif
