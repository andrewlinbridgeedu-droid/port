using System;
using System.Collections;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEngine;

public static class TowerSixFullPresentation20260917 {
 const string Key="TowerSixFullPresentation20260917";
 public static void Begin(){SessionState.SetBool(Key,true);EditorSceneManager.OpenScene("Assets/Scenes/BattlePrototype.unity");EditorApplication.isPlaying=true;}
 [InitializeOnLoadMethod] static void Restore(){EditorApplication.playModeStateChanged+=s=>{if(!SessionState.GetBool(Key,false))return;if(s==PlayModeStateChange.EnteredPlayMode)new GameObject("Six demon tower full presentation audit").AddComponent<TowerSixFullPresentationRunner20260917>();if(s==PlayModeStateChange.EnteredEditMode){SessionState.SetBool(Key,false);EditorApplication.Exit(0);}};}
}
public sealed class TowerSixFullPresentationRunner20260917:MonoBehaviour {
 string output; BattlePrototype battle; UnityBattleBridge bridge; int contacts,completions; string error;
 readonly List<string> report=new List<string>();
 readonly string[] skins={"stonehide","saltmaw","shellback","ironclaw","frilled-naga","boneclaw"};
 void Observe(string text,string stack,LogType type){if(type==LogType.Exception||type==LogType.Assert)error=text;if(text.Contains("\"eventName\":\"combat-contact\",\"value\":\"player\""))contacts++;if(text.Contains("\"eventName\":\"presentation-complete\""))completions++;}
 void Send(string action){bridge.ApplyCommand("{\"action\":\""+action+"\"}");}
 IEnumerator Start(){
  output=Path.GetFullPath("../output/tower-six-finish-20260917");Directory.CreateDirectory(output);Application.logMessageReceived+=Observe;
  yield return new WaitForSeconds(3);battle=FindFirstObjectByType<BattlePrototype>();bridge=FindFirstObjectByType<UnityBattleBridge>();
  var lines=File.ReadAllLines(output+"/rosters.tsv");var floors=new HashSet<int>();int waves=0;
  foreach(var line in lines){var r=line.Split('\t');if(r.Length!=3||!int.TryParse(r[0],out int floor))continue;
   var descriptors=r[2].Split(',');Require(descriptors.All(d=>d.Split('@').Length==2&&skins.Contains(d.Split('@')[1])),"non demon descriptor "+line);
   Send("combat-stop");Send("church-tower:"+r[2]);yield return new WaitForSeconds(.10f);
   var actors=FindObjectsByType<EnemyHandle>(FindObjectsSortMode.None).Where(a=>battle.BelongsToCurrentEncounter(a)).ToArray();
   Require(actors.Length==descriptors.Length,"actor count "+line);Require(actors.Select(a=>a.EnemyRoot.position).Distinct().Count()==actors.Length,"overlap "+line);
   foreach(var actor in actors){Require(actor.GetComponentsInChildren<SkinnedMeshRenderer>().Any(s=>s.enabled&&s.sharedMesh&&s.sharedMesh.vertexCount>0),"missing visible mesh "+line);Require(actor.GetComponentsInChildren<Renderer>().SelectMany(a=>a.sharedMaterials).Where(m=>m).All(m=>m.shader&&m.shader.isSupported),"unsupported material "+line);}
   Require(!battle.GetComponent<BattleRain>().WeatherVisible,"tower rain "+line);Require(error==null,error??"runtime");
   if(floor%10==0&&r[1]=="0")Capture("floor-"+floor.ToString("D3"));floors.Add(floor);waves++;
  }
  Require(floors.Count==100,"100 floors required");report.Add("All 100 floors / "+waves+" waves instantiated through production church-tower bridge: only six bodies, matching count, unique positions, visible supported meshes, indoor background.");
  Send("church-tower:clock-guard-primary@boneclaw,clock-guard-secondary@frilled-naga");yield return new WaitForSeconds(.4f);
  foreach(var number in new[]{"01","04","05","06","07","08","10"}){
   Send("combat-start");int c=contacts,p=completions;string skill="fool_skill_"+number;
   Send("skill:"+skill+":clock-guard-primary");yield return new WaitForSeconds(.65f);Capture("hero-"+number+"-windup");yield return new WaitForSeconds(.55f);Capture("hero-"+number+"-impact");yield return new WaitForSeconds(3);
   Require(contacts==c+1&&completions==p+1,"hero "+skill+" contacts="+(contacts-c)+" complete="+(completions-p));Require(error==null,error??"runtime");report.Add(skill+": actual contact once, completion once on tower demon roster.");Send("combat-stop");yield return null;
  }
  Send("combat-start");int old=contacts;Send("skill:fool_skill_07:clock-guard-primary");yield return new WaitForSeconds(.05f);Send("combat-stop");yield return new WaitForSeconds(2);Require(contacts==old,"cancelled hero delivered late contact");
  Send("wave-instances:clock-guard-primary");yield return new WaitForSeconds(.2f);Require(battle.GetComponent<BattleRain>().WeatherVisible,"mainline rain not restored");
  report.Add("Hero windup cancellation: zero late contact. Mainline background/rain restored. This is presentation verification, not a phone playthrough or damage simulation.");File.WriteAllLines(output+"/unity-presentation-passed.txt",report);EditorApplication.isPlaying=false;
 }
 void Require(bool ok,string reason){if(ok)return;File.WriteAllText(output+"/unity-presentation-failed.txt",reason);Debug.LogError(reason);EditorApplication.Exit(3);throw new Exception(reason);}
 void Capture(string name){var camera=Camera.main;var old=camera.targetTexture;var active=RenderTexture.active;float aspect=camera.aspect;var rt=new RenderTexture(540,960,24);var image=new Texture2D(540,960,TextureFormat.RGB24,false);try{camera.aspect=540f/960;typeof(BattlePrototype).GetMethod("FitRuntimeBackground",System.Reflection.BindingFlags.Instance|System.Reflection.BindingFlags.NonPublic).Invoke(battle,new object[]{camera});camera.targetTexture=rt;camera.Render();RenderTexture.active=rt;image.ReadPixels(new Rect(0,0,540,960),0,0);image.Apply();File.WriteAllBytes(output+"/"+name+".png",image.EncodeToPNG());}finally{camera.targetTexture=old;camera.aspect=aspect;RenderTexture.active=active;Destroy(rt);Destroy(image);}}
 void OnDestroy(){Application.logMessageReceived-=Observe;}
}
