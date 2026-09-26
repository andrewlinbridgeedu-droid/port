using System;
using System.Collections;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEngine;
public static class TowerCompleteReview20260920 {
 const string Key="TowerCompleteReview20260920";
 public static void Begin(){SessionState.SetBool(Key,true);EditorSceneManager.OpenScene("Assets/Scenes/BattlePrototype.unity");EditorApplication.isPlaying=true;}
 [InitializeOnLoadMethod]static void Restore(){EditorApplication.playModeStateChanged+=s=>{if(!SessionState.GetBool(Key,false))return;if(s==PlayModeStateChange.EnteredPlayMode)new GameObject(Key).AddComponent<TowerCompleteRunner20260920>();if(s==PlayModeStateChange.EnteredEditMode){SessionState.SetBool(Key,false);EditorApplication.Exit(0);}};}
}
[DefaultExecutionOrder(3100)]
public sealed class TowerCompleteRunner20260920:MonoBehaviour {
 readonly string[] rows={"stonehide|guard,charge|archive_slam","saltmaw|tower_sac_charge|tower_poison,tower_salt_spike","shellback|tower_mend_charge|tower_mend,tower_short_pounce","ironclaw|tower_blade_charge,tower_raised_blade|tower_cut_first,tower_cut_second,tower_heavy_cut","frilled-naga|tower_crown_charge|tower_empower,tower_sound_arrow","boneclaw|tower_claw_charge|tower_piercing_claw,tower_tail_sweep,tower_heavy_claw"};
 UnityBattleBridge bridge;BattlePrototype battle;EnemyHandle actor;int hits,cancels;string output,pending,error;readonly List<string> report=new List<string>();
 void Observe(string text,string stack,LogType type){if(type==LogType.Exception||type==LogType.Assert||type==LogType.Error)error=text;if(text.Contains("combat-contact")&&text.Contains("enemy:clock-guard-primary"))hits++;if(text.Contains("combat-contact")&&text.Contains("enemy-cancel:clock-guard-primary"))cancels++;}
 void Send(string s){bridge.ApplyCommand("{\"action\":\""+s+"\"}");}
 void Check(bool ok,string why){if(!ok){File.WriteAllText(output+"/failed.txt",why);Debug.LogError("TOWER_BATCH_FAIL "+why);EditorApplication.Exit(3);throw new Exception(why);}report.Add(why);Debug.Log("TOWER_BATCH_PASS "+why);}
 IEnumerator Clip(string name,int count){Directory.CreateDirectory(output+"/"+name);Directory.CreateDirectory(output+"/"+name+"/close");for(int i=0;i<count;i++){pending=name+"/frame-"+i.ToString("D3");yield return null;}}
 IEnumerator Setup(string skin){Send("combat-stop");Send("church-tower:clock-guard-primary@"+skin+",clock-guard-secondary@stonehide");yield return new WaitForSeconds(.3f);Send("combat-start");actor=FindObjectsByType<EnemyHandle>(FindObjectsSortMode.None).Single(h=>battle.BelongsToCurrentEncounter(h)&&h.BattleEnemyId=="clock-guard-primary");}
 IEnumerator Start(){
  output=Path.GetFullPath("../output/tower-complete-20260920/runtime");Directory.CreateDirectory(output);Application.logMessageReceived+=Observe;Time.captureFramerate=24;
  yield return new WaitForSeconds(3);bridge=FindFirstObjectByType<UnityBattleBridge>();battle=FindFirstObjectByType<BattlePrototype>();
  string filter=Environment.GetCommandLineArgs().FirstOrDefault(a=>a.StartsWith("--tower-species="));
  foreach(var row in rows){if(filter!=null&&!filter.Substring(16).Split(',').Contains(row.Split('|')[0]))continue;var fields=row.Split('|');string skin=fields[0];yield return Setup(skin);
   yield return Clip(skin+"--idle",24);
   foreach(var prep in fields[1].Split(',')){int before=hits;Send("enemy:clock-guard-primary:"+prep);yield return Clip(skin+"--"+prep,36);Check(hits==before,skin+" "+prep+" no damage contact");Send("enemy:clock-guard-primary:recover");yield return new WaitForSeconds(.2f);}
   Send("enemy:clock-guard-primary:recover");yield return Clip(skin+"--recover",24);
   foreach(var action in fields[2].Split(',')){
    bool support=action=="tower_mend"||action=="tower_empower";string command="enemy:clock-guard-primary:"+action+(support?":clock-guard-secondary":"");
    int before=hits;Vector3 home=actor.EnemyRoot.position;Send(command);yield return Clip(skin+"--"+action,72);
    Check(hits==before+1,skin+" "+action+" exactly one contact");Check(Vector3.Distance(home,actor.EnemyRoot.position)<.01f,skin+" "+action+" returns home");
    before=hits;Send(command);yield return new WaitForSeconds(.1f);Send("combat-stop");yield return new WaitForSeconds(1.1f);Check(hits==before,skin+" "+action+" stop zero late contact");
    Check(!FindObjectsByType<MonoBehaviour>(FindObjectsSortMode.None).Any(v=>v is ChurchFinalVfx20260917||v is SaltmawSpell20260919||v is TowerSupportPolish20260920||v is IronclawSpell20260918||v is BoneclawGesture20260920||v is StonehideGesture20260920),skin+" stop no final VFX");Send("combat-start");
    before=hits;Send(command);yield return new WaitForSeconds(.1f);bridge.SetEnemyVisibility("clock-guard-primary=hidden");yield return new WaitForSeconds(1.2f);Check(hits==before,skin+" "+action+" death zero late contact");bridge.SetEnemyVisibility("clock-guard-primary=visible");yield return new WaitForSeconds(.2f);Send("combat-start");
    if(support){before=hits;int c=cancels;Send(command);yield return new WaitForSeconds(.1f);bridge.SetEnemyVisibility("clock-guard-secondary=hidden");yield return new WaitForSeconds(1.2f);Check(hits==before&&cancels==c+1,skin+" recipient death cancels once");bridge.SetEnemyVisibility("clock-guard-secondary=visible");yield return new WaitForSeconds(.2f);}
    before=hits;Send(command);yield return new WaitForSeconds(2.7f);Check(hits==before+1,skin+" "+action+" retry once");
   }
   if(skin=="shellback"){Send("enemy-heal:clock-guard-secondary");yield return Clip(skin+"--recipient-heal",36);}
   if(skin=="frilled-naga"){Send("church-status:empowered:clock-guard-secondary");yield return Clip(skin+"--recipient-crown",36);Send("church-status:empowered:");}
   if(skin=="saltmaw"){Send("church-status:poison:1");yield return Clip(skin+"--poison-status",36);Send("church-status:poison:0");}
   Send("enemy-impact:heavy:clock-guard-primary");yield return Clip(skin+"--hit",24);
   bridge.SetEnemyVisibility("clock-guard-primary=hidden");yield return Clip(skin+"--death",36);Check(!actor.gameObject.activeInHierarchy,skin+" death exits");
   Send("combat-stop");yield return null;Check(error==null,error??"no exceptions");
  }
  File.WriteAllLines(output+(filter==null?"/passed.txt":"/targeted-passed.txt"),report);EditorApplication.isPlaying=false;
 }
 void LateUpdate(){if(pending==null)return;Capture(pending);pending=null;}
 void Capture(string name){var cam=Camera.main;var old=cam.targetTexture;var active=RenderTexture.active;float aspect=cam.aspect;var rt=new RenderTexture(540,960,24);var image=new Texture2D(540,960,TextureFormat.RGB24,false);try{cam.aspect=540f/960;typeof(BattlePrototype).GetMethod("FitRuntimeBackground",System.Reflection.BindingFlags.Instance|System.Reflection.BindingFlags.NonPublic).Invoke(battle,new object[]{cam});cam.targetTexture=rt;cam.Render();RenderTexture.active=rt;image.ReadPixels(new Rect(0,0,540,960),0,0);image.Apply();File.WriteAllBytes(output+"/"+name+".png",image.EncodeToPNG());CaptureClose(cam,name);}finally{cam.targetTexture=old;cam.aspect=aspect;RenderTexture.active=active;Destroy(rt);Destroy(image);}}
 void CaptureClose(Camera cam,string name){
  if(!actor)return;var previous=cam.targetTexture;var active=RenderTexture.active;var pos=cam.transform.position;var rot=cam.transform.rotation;float fov=cam.fieldOfView,aspect=cam.aspect;
  var rt=new RenderTexture(384,384,24);var img=new Texture2D(384,384,TextureFormat.RGB24,false);
  try{cam.aspect=1;cam.fieldOfView=42;cam.transform.position=actor.EnemyRoot.position+Vector3.up*1.45f-cam.transform.forward*5.4f;typeof(BattlePrototype).GetMethod("FitRuntimeBackground",System.Reflection.BindingFlags.Instance|System.Reflection.BindingFlags.NonPublic).Invoke(battle,new object[]{cam});cam.targetTexture=rt;cam.Render();RenderTexture.active=rt;img.ReadPixels(new Rect(0,0,384,384),0,0);img.Apply();string folder=Path.GetDirectoryName(name);File.WriteAllBytes(Path.Combine(output,folder,"close",Path.GetFileName(name)+".png"),img.EncodeToPNG());}
  finally{cam.targetTexture=previous;RenderTexture.active=active;cam.transform.SetPositionAndRotation(pos,rot);cam.fieldOfView=fov;cam.aspect=aspect;typeof(BattlePrototype).GetMethod("FitRuntimeBackground",System.Reflection.BindingFlags.Instance|System.Reflection.BindingFlags.NonPublic).Invoke(battle,new object[]{cam});Destroy(rt);Destroy(img);}
 }
 void OnDestroy(){Application.logMessageReceived-=Observe;}
}
