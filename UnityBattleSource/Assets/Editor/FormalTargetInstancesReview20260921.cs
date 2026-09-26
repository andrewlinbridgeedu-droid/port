using System;
using System.Collections;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEngine;

public static class FormalTargetInstancesReview20260921 {
 const string Key="FormalTargetInstancesReview20260921";
 public static void Begin() { SessionState.SetBool(Key,true); EditorSceneManager.OpenScene("Assets/Scenes/BattlePrototype.unity"); EditorApplication.isPlaying=true; }
 [InitializeOnLoadMethod] static void Init() { EditorApplication.playModeStateChanged += s => {
  if(!SessionState.GetBool(Key,false))return;
  if(s==PlayModeStateChange.EnteredPlayMode)new GameObject(Key).AddComponent<FormalTargetInstancesRunner20260921>();
  if(s==PlayModeStateChange.EnteredEditMode) { SessionState.SetBool(Key,false); EditorApplication.Exit(0); }
 }; }
}
public sealed class FormalTargetInstancesRunner20260921 : MonoBehaviour {
 readonly List<string> checks=new(); string output; bool errors;
 void Check(bool yes,string text) { if(!yes) { File.WriteAllText(output+"/formal-failed.txt",text); Debug.LogError(text); EditorApplication.Exit(3); } checks.Add(text); }
 void Log(string text,string stack,LogType type) { if(type==LogType.Exception||type==LogType.Error)errors=true; }
 IEnumerator Start() {
  output=Path.GetFullPath("../output/target-instances-20260921");Directory.CreateDirectory(output);Application.logMessageReceived+=Log;
  yield return new WaitForSeconds(3);
  var bridge=FindFirstObjectByType<UnityBattleBridge>();var battle=FindFirstObjectByType<BattlePrototype>();
  bridge.ApplyCommand("{\"action\":\"combat-stop\"}");
  bridge.ApplyCommand("{\"action\":\"church-tower:clock-guard-primary@stonehide,clock-guard-secondary@ironclaw,clock-guard-tertiary@boneclaw,clock-guard-fourth@stonehide\"}");
  yield return new WaitForSeconds(.3f);
  var targets=FindObjectsByType<EnemyHandle>(FindObjectsSortMode.None).Where(battle.BelongsToCurrentEncounter).OrderBy(h=>h.BattleEnemyId).ToArray();
  Check(targets.Length==4,"four distinct enemy handles available");
  var host=new GameObject("Formal instance verification host");var vfx=host.AddComponent<FoolEffekseerSkillVFX>();
  foreach(var skill in new[]{"fool_skill_01","fool_skill_10"})foreach(var n in (skill=="fool_skill_01"?new[]{1,2}:new[]{1,2,4})) {
   int contacts=0; bool complete=false;
   StartCoroutine(Run(vfx.PlayTargetInstances(skill,()=>new Vector3(0,1.2f,-3.8f),targets.Take(n).ToArray(),()=>contacts++),()=>complete=true));
   yield return new WaitForSeconds(.36f);
   var owners=host.transform.Cast<Transform>().Where(t=>t.name.StartsWith(skill+" target [")).ToArray();
   Check(owners.Length==n,skill+" "+n+" stable target owners");
   Check(owners.All(t=>t.GetComponentsInChildren<Renderer>().Length>0),skill+" "+n+" independently owned renderers");
   while(!complete)yield return null;
   yield return null;
   Check(contacts==1,skill+" "+n+" one public contact");
   Check(host.transform.childCount==0,skill+" "+n+" complete cleanup");
  }
  foreach(var skill in new[]{"fool_skill_01","fool_skill_10"}) {
   int contacts=0;bool complete=false;
   StartCoroutine(Run(vfx.PlayTargetInstances(skill,()=>new Vector3(0,1.2f,-3.8f),targets.Take(2).ToArray(),()=>contacts++),()=>complete=true));
   yield return new WaitForSeconds(.25f);targets[0].gameObject.SetActive(false);yield return null;yield return null;
   var retired=host.transform.Cast<Transform>().First(t=>t.name.Contains(targets[0].BattleEnemyId));
   var survivor=host.transform.Cast<Transform>().First(t=>t.name.Contains(targets[1].BattleEnemyId));
   Check(!retired.GetComponentsInChildren<Renderer>().Any(r=>r.gameObject.activeInHierarchy),skill+" departing target clears only its visuals");
   Check(survivor.GetComponentsInChildren<Renderer>().Any(r=>r.gameObject.activeInHierarchy),skill+" surviving target continues");
   while(!complete)yield return null;
   Check(contacts==1,skill+" departure keeps one public contact");targets[0].gameObject.SetActive(true);
   contacts=0;complete=false;
   StartCoroutine(Run(vfx.PlayTargetInstances(skill,()=>Vector3.zero,targets.Take(2).ToArray(),()=>contacts++),()=>complete=true));
   yield return new WaitForSeconds(.1f);vfx.StopActiveEffects();yield return null;yield return null;
   Check(contacts==0 && host.transform.childCount==0,skill+" cancellation clears and suppresses late contact");
  }
  Check(!errors,"no runtime exceptions or errors");File.WriteAllLines(output+"/formal-passed.txt",checks);Destroy(host);Application.logMessageReceived-=Log;EditorApplication.isPlaying=false;
 }
 IEnumerator Run(IEnumerator body,Action completed) { yield return body;completed(); }
}
