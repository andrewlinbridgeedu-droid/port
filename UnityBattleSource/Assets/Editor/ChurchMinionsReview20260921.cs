using System;
using System.Collections;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEngine;
public static class ChurchMinionsReview20260921 {
 const string Key="ChurchMinionsReview20260921";
 public static void Begin(){SessionState.SetBool(Key,true);EditorSceneManager.OpenScene("Assets/Scenes/BattlePrototype.unity");EditorApplication.isPlaying=true;}
 [InitializeOnLoadMethod]static void Restore(){EditorApplication.playModeStateChanged+=s=>{if(!SessionState.GetBool(Key,false))return;if(s==PlayModeStateChange.EnteredPlayMode)new GameObject(Key).AddComponent<ChurchMinionsRunner20260921>();if(s==PlayModeStateChange.EnteredEditMode){SessionState.SetBool(Key,false);EditorApplication.Exit(0);}};}
}
[DefaultExecutionOrder(3100)]
public sealed class ChurchMinionsRunner20260921:MonoBehaviour {
 readonly string[] rows={"copperback|tower_copperback_charge,tower_copperback_charge2|tower_copperback_first,tower_copperback_second","golden-throat|tower_throat_charge,tower_throat_charge2|tower_throat_first,tower_throat_second","crimson-brute|tower_brute_charge,tower_brute_charge2|tower_brute_first,tower_brute_second","moonfang|tower_moonfang_charge,tower_moonfang_charge2|tower_moonfang_first,tower_moonfang_second","veil-oracle|tower_veil_charge,tower_veil_charge2|tower_veil_first,tower_veil_second"};
 UnityBattleBridge bridge;BattlePrototype battle;EnemyHandle actor;int hits,cancels,secondaryHits;string output,pending,error;readonly List<string> report=new List<string>();
 void Observe(string text,string stack,LogType type){if(text.Contains("combat-contact")&&text.Contains("enemy:clock-guard-secondary"))secondaryHits++;if(type==LogType.Exception||type==LogType.Assert||type==LogType.Error)error=text;if(text.Contains("combat-contact")&&text.Contains("enemy:clock-guard-primary"))hits++;if(text.Contains("combat-contact")&&text.Contains("enemy-cancel:clock-guard-primary"))cancels++;}
 void Send(string s){bridge.ApplyCommand("{\"action\":\""+s+"\"}");}
 void Check(bool ok,string why){if(!ok){File.WriteAllText(output+"/failed.txt",why);Debug.LogError("TOWER_BATCH_FAIL "+why);EditorApplication.Exit(3);throw new Exception(why);}report.Add(why);Debug.Log("TOWER_BATCH_PASS "+why);}
 IEnumerator Clip(string name,int count){Directory.CreateDirectory(output+"/"+name);Directory.CreateDirectory(output+"/"+name+"/close");for(int i=0;i<count;i++){pending=name+"/frame-"+i.ToString("D3");yield return null;}}
 IEnumerator Setup(string skin){Send("combat-stop");Send("church-tower:clock-guard-primary@"+skin+",clock-guard-secondary@stonehide");yield return new WaitForSeconds(.3f);Send("combat-start");actor=FindObjectsByType<EnemyHandle>(FindObjectsSortMode.None).Single(h=>battle.BelongsToCurrentEncounter(h)&&h.BattleEnemyId=="clock-guard-primary");}
 IEnumerator Start(){
  output=Path.GetFullPath("../output/church-minions-20260921/runtime");Directory.CreateDirectory(output);Application.logMessageReceived+=Observe;Time.captureFramerate=30;
  yield return new WaitForSeconds(3);bridge=FindFirstObjectByType<UnityBattleBridge>();battle=FindFirstObjectByType<BattlePrototype>();
  string filter=Environment.GetCommandLineArgs().FirstOrDefault(a=>a.StartsWith("--tower-species="));
  foreach(var row in rows){if(filter!=null&&!filter.Substring(16).Split(',').Contains(row.Split('|')[0]))continue;var fields=row.Split('|');string skin=fields[0];yield return Setup(skin);
   yield return Clip(skin+"--idle",60);
   foreach(var prep in fields[1].Split(',')){int before=hits;Send("enemy:clock-guard-primary:"+prep);yield return Clip(skin+"--"+prep,72);Check(hits==before,skin+" "+prep+" no damage contact");Send("enemy:clock-guard-primary:recover");yield return new WaitForSeconds(.2f);}
   foreach(var prep in fields[1].Split(',')){
    int before=hits;Send("enemy:clock-guard-primary:"+prep);yield return new WaitForSeconds(.2f);Send("combat-stop");yield return new WaitForSeconds(.2f);
    var animator=actor.GetComponentInChildren<Animator>(true);Check(hits==before,skin+" "+prep+" cancel no contact");
    Check(animator&&animator.GetCurrentAnimatorStateInfo(0).IsName("Meshy · Idle"),skin+" "+prep+" cancel restores idle");
    Check(!FindObjectsByType<ChurchMinionVfx20260921>(FindObjectsSortMode.None).Any(),skin+" "+prep+" cancel clears organs");Send("combat-start");
   }
   Send("enemy:clock-guard-primary:recover");yield return Clip(skin+"--recover",24);
   foreach(var action in fields[2].Split(',')){
    bool support=action=="tower_mend"||action=="tower_empower";string command="enemy:clock-guard-primary:"+action+(support?":clock-guard-secondary":"");
    int before=hits;Vector3 home=actor.EnemyRoot.position;Send(command);yield return Clip(skin+"--"+action,60);
    Check(hits==before+1,skin+" "+action+" exactly one contact");Check(Vector3.Distance(home,actor.EnemyRoot.position)<.01f,skin+" "+action+" returns home");
    before=hits;Send(command);yield return new WaitForSeconds(.1f);Send("combat-stop");yield return new WaitForSeconds(1.1f);Check(hits==before,skin+" "+action+" stop zero late contact");
    Check(!FindObjectsByType<MonoBehaviour>(FindObjectsSortMode.None).Any(v=>v is ChurchMinionVfx20260921||v is ChurchFinalVfx20260917||v is SaltmawSpell20260919||v is TowerSupportPolish20260920||v is IronclawSpell20260918||v is BoneclawGesture20260920||v is StonehideGesture20260920),skin+" stop no final VFX");Send("combat-start");
    before=hits;Send(command);yield return new WaitForSeconds(.1f);bridge.SetEnemyVisibility("clock-guard-primary=hidden");yield return new WaitForSeconds(1.2f);Check(hits==before,skin+" "+action+" death zero late contact");bridge.SetEnemyVisibility("clock-guard-primary=visible");yield return new WaitForSeconds(.2f);Send("combat-start");
    if(support){before=hits;int c=cancels;Send(command);yield return new WaitForSeconds(.1f);bridge.SetEnemyVisibility("clock-guard-secondary=hidden");yield return new WaitForSeconds(1.2f);Check(hits==before&&cancels==c+1,skin+" recipient death cancels once");bridge.SetEnemyVisibility("clock-guard-secondary=visible");yield return new WaitForSeconds(.2f);}
    before=hits;Send(command);yield return new WaitForSeconds(2.7f);Check(hits==before+1,skin+" "+action+" retry once");
   }
   if(skin=="shellback"){Send("enemy-heal:clock-guard-secondary");yield return Clip(skin+"--recipient-heal",36);}
   if(skin=="frilled-naga"){Send("church-status:empowered:clock-guard-secondary");yield return Clip(skin+"--recipient-crown",36);Send("church-status:empowered:");}
   if(skin=="saltmaw"){Send("church-status:poison:1");yield return Clip(skin+"--poison-status",36);Send("church-status:poison:0");}
   Send("enemy-impact:heavy:clock-guard-primary");yield return Clip(skin+"--hit",24);
   bridge.SetEnemyVisibility("clock-guard-primary=hidden");yield return Clip(skin+"--death",45);Check(!actor.gameObject.activeInHierarchy,skin+" death exits");
   Send("combat-stop");yield return null;Check(error==null,error??"no exceptions");
  }
  if(filter==null){
   foreach(var primary in new[]{"copperback","moonfang"}){
    Send("combat-stop");Send("church-tower:clock-guard-primary@"+primary+",clock-guard-secondary@crimson-brute,clock-guard-instance-3@golden-throat,clock-guard-instance-4@veil-oracle");yield return new WaitForSeconds(.4f);Send("combat-start");
    var roster=FindObjectsByType<EnemyHandle>(FindObjectsSortMode.None).Where(h=>battle.BelongsToCurrentEncounter(h)&&h.gameObject.activeInHierarchy).ToArray();
    Check(roster.Length==4,primary+" mixed roster has four independent actors");actor=roster.Single(h=>h.BattleEnemyId=="clock-guard-primary");yield return Clip("mixed-four-"+primary,45);
    var secondary=roster.Single(h=>h.BattleEnemyId=="clock-guard-secondary");int count=secondaryHits;
    Send("enemy:clock-guard-secondary:tower_brute_charge2");yield return new WaitForSeconds(.3f);Send("combat-stop");yield return new WaitForSeconds(.2f);
    Check(secondary.GetComponentInChildren<Animator>(true).GetCurrentAnimatorStateInfo(0).IsName("Meshy · Idle"),primary+" secondary charge cancel restores idle");
    Send("combat-start");Send("enemy:clock-guard-secondary:tower_brute_first");yield return new WaitForSeconds(.15f);
    Send("church-tower:clock-guard-primary@moonfang");yield return new WaitForSeconds(1.2f);
    Check(secondaryHits==count,primary+" wave replacement no stale secondary contact");
    Check(!FindObjectsByType<ChurchMinionVfx20260921>(FindObjectsSortMode.None).Any(),primary+" wave replacement clears spell instances");
   }
   Send("combat-stop");Check(error==null,error??"mixed rosters no exceptions");
  }
  File.WriteAllLines(output+(filter==null?"/passed.txt":"/targeted-"+filter.Substring(16)+"-passed.txt"),report);EditorApplication.isPlaying=false;
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
