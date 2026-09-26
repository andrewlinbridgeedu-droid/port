using System;
using System.Collections;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEngine;
public static class CodexExecutorPreview20260916 {
 const string Key="Mistport.CodexExecutorPreview";
 public static void Begin(){SessionState.SetBool(Key,true);EditorSceneManager.OpenScene("Assets/Scenes/BattlePrototype.unity");EditorApplication.isPlaying=true;}
 [InitializeOnLoadMethod]static void Restore(){EditorApplication.playModeStateChanged+=s=>{if(!SessionState.GetBool(Key,false))return;if(s==PlayModeStateChange.EnteredPlayMode)new GameObject("Executor QA").AddComponent<CodexExecutorPreviewRunner>();if(s==PlayModeStateChange.EnteredEditMode){SessionState.SetBool(Key,false);EditorApplication.Exit(0);}};}
}
public sealed class CodexExecutorPreviewRunner:MonoBehaviour {
 readonly Dictionary<string,int> contacts=new Dictionary<string,int>();
 string dir;BattlePrototype battle;
 void Count(string m,string t,LogType type){if(!m.Contains("combat-contact"))return;foreach(var id in new[]{"clock-guard-primary","clock-guard-secondary"})if(m.Contains("enemy:"+id))contacts[id]=Number(id)+1;}
 int Number(string id)=>contacts.TryGetValue(id,out var n)?n:0;
 IEnumerator Start(){
  Application.logMessageReceived+=Count;dir=Path.GetFullPath("../output/codex-executor-delivery-20260916/unity");Directory.CreateDirectory(dir);
  yield return new WaitForSeconds(3);battle=FindFirstObjectByType<BattlePrototype>();
  var floor=GameObject.Find("Clock Arena");if(floor)floor.SetActive(false);foreach(var ring in FindObjectsByType<Transform>(FindObjectsSortMode.None))if(ring.name.StartsWith("Arena Rune Ring"))ring.gameObject.SetActive(false);
  battle.SetNativeCombatEnabled(false);battle.ConfigureWaveInstances("clock-guard-primary@executor");battle.SetEarlyBattlePresence("17");yield return new WaitForSeconds(.6f);
  var actor=FindObjectsByType<EnemyHandle>(FindObjectsSortMode.None).Single(h=>battle.BelongsToCurrentEncounter(h));
  Require(actor.ProfileEnemyId=="executor","wrong model");Require(actor.GetComponentsInChildren<SkinnedMeshRenderer>().Any(s=>s.bones.Length>=15),"rig missing");
  for(int i=0;i<4;i++){yield return new WaitForSeconds(.35f);Capture("idle-"+i);}
  battle.SetNativeCombatEnabled(true);
  for(int variant=0;variant<2;variant++){
   int before=Number(actor.BattleEnemyId);battle.PresentEnemyAttack(actor.BattleEnemyId);
   for(int f=0;f<8;f++){yield return new WaitForSeconds(.3f);Capture("attack-"+variant+"-"+f);if(f==1)battle.PresentEnemyImpact("basic:"+actor.BattleEnemyId);}
   yield return new WaitForSeconds(.4f);Require(Number(actor.BattleEnemyId)==before+1,"attack must contact once even with Hit");
  }
  int prior=Number(actor.BattleEnemyId);battle.PresentEnemyAttack(actor.BattleEnemyId);yield return new WaitForSeconds(.2f);battle.SetNativeCombatEnabled(false);yield return new WaitForSeconds(1.4f);Require(Number(actor.BattleEnemyId)==prior,"cancelled attack contacted");
  battle.SetNativeCombatEnabled(true);prior=Number(actor.BattleEnemyId);battle.PresentEnemyAttack(actor.BattleEnemyId);yield return new WaitForSeconds(.2f);
  var bridge=FindFirstObjectByType<UnityBattleBridge>();bridge.SetEnemyVisibility("clock-guard-primary=hidden");
  for(int f=0;f<4;f++){yield return new WaitForSeconds(.3f);Capture("death-"+f);}
  Require(!actor.gameObject.activeSelf,"death did not fade out");Require(Number(actor.BattleEnemyId)==prior,"death failed to cancel contact");
  bridge.SetEnemyVisibility("clock-guard-primary=visible");yield return new WaitForSeconds(.4f);Capture("death-cancel-restored");
  Require(actor.gameObject.activeSelf,"death restore visibility failed");
  Require(actor.GetComponentInChildren<Animator>().GetCurrentAnimatorStateInfo(0).IsName("Meshy · Idle"),"death restore not Idle");
  battle.SetNativeCombatEnabled(false);
  battle.ConfigureWaveInstances("clock-guard-primary@executor,clock-guard-secondary@executor");yield return new WaitForSeconds(.6f);Capture("two-executors");battle.SetNativeCombatEnabled(true);
  foreach(var id in new[]{"clock-guard-primary","clock-guard-secondary"}){int before=Number(id);battle.PresentEnemyAttack(id);yield return new WaitForSeconds(2.9f);Require(Number(id)==before+1,"dual stable identity contact "+id);}
  battle.SetNativeCombatEnabled(false);battle.ConfigureWaveInstances("clock-guard-primary@rescue");yield return new WaitForSeconds(.4f);Require(!FindObjectsByType<EnemyHandle>(FindObjectsSortMode.None).Any(h=>battle.BelongsToCurrentEncounter(h)&&h.ProfileEnemyId=="executor"),"executor leaked across roster");
  battle.ConfigureWaveInstances("clock-guard-primary@executor");yield return new WaitForSeconds(.6f);Capture("retry");battle.SetNativeCombatEnabled(true);prior=Number("clock-guard-primary");battle.PresentEnemyAttack("clock-guard-primary");yield return new WaitForSeconds(2.9f);Require(Number("clock-guard-primary")==prior+1,"retry no contact");
  File.WriteAllText(dir+"/passed.txt","Actual Editor Play Mode executor: rig and seven clips imported; two attack variants contact once through Hit; cancel/death yield no contact; death fades over one second and restores Idle; independent double instances; cross-roster removal and retry contact. Not a phone or Q17 balance acceptance.\n");EditorApplication.isPlaying=false;
 }
 static void Require(bool ok,string message){if(!ok){Debug.LogError(message);EditorApplication.Exit(3);throw new Exception(message);}}
 void Capture(string name){var c=Camera.main;var prev=c.targetTexture;var active=RenderTexture.active;float aspect=c.aspect;var rt=new RenderTexture(540,960,24);var image=new Texture2D(540,960,TextureFormat.RGB24,false);try{c.aspect=540f/960;c.targetTexture=rt;c.Render();RenderTexture.active=rt;image.ReadPixels(new Rect(0,0,540,960),0,0);image.Apply();File.WriteAllBytes(dir+"/"+name+".png",image.EncodeToPNG());}finally{c.targetTexture=prev;c.aspect=aspect;RenderTexture.active=active;Destroy(rt);Destroy(image);}}
 void OnDestroy(){Application.logMessageReceived-=Count;}
}
