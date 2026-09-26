using System;
using System.Collections;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEngine;
public static class ChurchAllModelsPreview20260917 {
 const string Key="Mistport.ChurchAllModelsPreview";
 public static void Begin(){SessionState.SetBool(Key,true);EditorSceneManager.OpenScene("Assets/Scenes/BattlePrototype.unity");EditorApplication.isPlaying=true;}
 [InitializeOnLoadMethod]static void Restore(){EditorApplication.playModeStateChanged+=s=>{if(!SessionState.GetBool(Key,false))return;if(s==PlayModeStateChange.EnteredPlayMode)new GameObject("Church model verification").AddComponent<ChurchAllModelsRunner20260917>();if(s==PlayModeStateChange.EnteredEditMode){SessionState.SetBool(Key,false);EditorApplication.Exit(0);}};}
}
public sealed class ChurchAllModelsRunner20260917:MonoBehaviour {
 BattlePrototype battle;UnityBattleBridge bridge;string output;
 readonly Dictionary<string,int> contacts=new Dictionary<string,int>();
 int Count(string id)=>contacts.TryGetValue(id,out int n)?n:0;
 void Observe(string message,string trace,LogType type){if(!message.Contains("combat-contact"))return;foreach(var id in new[]{"hell-hound-primary","clock-guard-primary","clock-guard-secondary","clock-guard-instance-3","clock-guard-instance-4"})if(message.Contains("enemy:"+id))contacts[id]=Count(id)+1;}
 IEnumerator Start(){
  output=Path.GetFullPath("../output/church-demons-combat-20260917/unity");Directory.CreateDirectory(output);File.Delete(output+"/passed.txt");
  Application.logMessageReceived+=Observe;yield return new WaitForSeconds(3);battle=FindFirstObjectByType<BattlePrototype>();bridge=FindFirstObjectByType<UnityBattleBridge>();
  bridge.ApplyCommand("{\"action\":\"church-tower:hell-hound-primary@early-hell-hound,clock-guard-primary@stonehide\"}");yield return new WaitForSeconds(.8f);battle.SetNativeCombatEnabled(true);
  var hound=FindObjectsByType<EnemyHandle>(FindObjectsSortMode.None).Single(h=>battle.BelongsToCurrentEncounter(h)&&h.BattleEnemyId=="hell-hound-primary");var home=hound.EnemyRoot.position;int pounceBefore=Count(hound.BattleEnemyId);
  battle.PresentEnemyAttack(hound.BattleEnemyId+":tower_pounce_charge");yield return new WaitForSeconds(.4f);Require(Count(hound.BattleEnemyId)==pounceBefore,"pounce preparation silent");
  battle.PresentEnemyAttack(hound.BattleEnemyId+":tower_hound_pounce");yield return new WaitForSeconds(1.3f);Require(Count(hound.BattleEnemyId)==pounceBefore+1 && Vector3.Distance(home,hound.EnemyRoot.position)<.01f,"pounce once and returns");
  pounceBefore=Count(hound.BattleEnemyId);battle.PresentEnemyAttack(hound.BattleEnemyId+":tower_hound_pounce");yield return new WaitForSeconds(.1f);battle.SetNativeCombatEnabled(false);yield return new WaitForSeconds(.8f);Require(Count(hound.BattleEnemyId)==pounceBefore&&Vector3.Distance(home,hound.EnemyRoot.position)<.01f,"pounce cancel restores home");
  string[] species={"saltmaw","shellback","ironclaw","frilled-naga","boneclaw"};
  string[][] actions={new[]{"tower_sac_charge","tower_poison","tower_salt_spike"},new[]{"tower_mend_charge","tower_mend:clock-guard-secondary","tower_short_pounce"},new[]{"tower_blade_charge","tower_cut_first","tower_cut_second","tower_raised_blade","tower_heavy_cut"},new[]{"tower_crown_charge","tower_empower:clock-guard-secondary","tower_sound_arrow"},new[]{"tower_claw_charge","tower_piercing_claw","tower_tail_sweep","tower_claw_charge","tower_heavy_claw"}};
  for(int k=0;k<species.Length;k++){
   bridge.ApplyCommand("{\"action\":\"church-tower:clock-guard-primary@"+species[k]+",clock-guard-secondary@stonehide\"}");yield return new WaitForSeconds(.8f);battle.SetNativeCombatEnabled(true);
   var actors=FindObjectsByType<EnemyHandle>(FindObjectsSortMode.None).Where(h=>battle.BelongsToCurrentEncounter(h)).ToArray();Require(actors.Length==2,"two actual actors "+species[k]);
   var actor=actors.Single(h=>h.BattleEnemyId=="clock-guard-primary");Require(actor.ProfileEnemyId==species[k],"exact species "+species[k]);Require(actor.GetComponentsInChildren<SkinnedMeshRenderer>().Any(s=>s.bones.Length>=16),"real skin "+species[k]);
   var animation=actor.GetComponentInChildren<Animator>();var bone=actor.GetComponentsInChildren<Transform>().First(t=>t.name=="Head");var prior=bone.rotation;yield return new WaitForSeconds(.8f);Require(Quaternion.Angle(prior,bone.rotation)>.01f,"authored moving idle "+species[k]);Capture(species[k]+"-idle");
   foreach(var action in actions[k]){
    int before=Count(actor.BattleEnemyId);battle.PresentEnemyAttack(actor.BattleEnemyId+":"+action);
    bool preparing=ChurchDemonPresentation20260917.IsPreparation(action);yield return new WaitForSeconds(preparing?.3f:1.45f);Require(Count(actor.BattleEnemyId)==before+(preparing?0:1),"contact count "+species[k]+" "+action);
   }
   int old=Count(actor.BattleEnemyId);string attack=actions[k].First(x=>!ChurchDemonPresentation20260917.IsPreparation(x));
   battle.PresentEnemyAttack(actor.BattleEnemyId+":"+attack);yield return new WaitForSeconds(.1f);battle.SetNativeCombatEnabled(false);yield return new WaitForSeconds(1.1f);Require(Count(actor.BattleEnemyId)==old,"cancel "+species[k]);
   battle.SetNativeCombatEnabled(true);
   if(species[k]=="shellback"||species[k]=="frilled-naga"){
    var recipient=actors.Single(h=>h.BattleEnemyId=="clock-guard-secondary");old=Count(actor.BattleEnemyId);battle.PresentEnemyAttack(actor.BattleEnemyId+":"+attack);yield return new WaitForSeconds(.1f);bridge.SetEnemyVisibility(recipient.BattleEnemyId+"=hidden");yield return new WaitForSeconds(1.1f);Require(Count(actor.BattleEnemyId)==old,"frozen recipient death must cancel "+species[k]);bridge.SetEnemyVisibility(recipient.BattleEnemyId+"=visible");yield return new WaitForSeconds(.2f);
   }
   // One short raw RGB strip per model; converted to GIF and raw removed after validation.
   using(var stream=File.Create(output+"/"+species[k]+".rgb")){
    battle.PresentEnemyAttack(actor.BattleEnemyId+":"+actions[k][0]);
    for(int f=0;f<24;f++){if(f==9)battle.PresentEnemyAttack(actor.BattleEnemyId+":"+attack);yield return new WaitForSeconds(.1f);Frame(stream,270,480);}
   }
   battle.SetNativeCombatEnabled(false);bridge.SetEnemyVisibility(actor.BattleEnemyId+"=hidden");yield return new WaitForSeconds(1.2f);Require(!actor.gameObject.activeSelf,"fade "+species[k]);bridge.SetEnemyVisibility(actor.BattleEnemyId+"=visible");yield return new WaitForSeconds(.3f);Require(actor.gameObject.activeInHierarchy&&animation.speed>0,"retry "+species[k]);
  }
  bridge.ApplyCommand("{\"action\":\"church-tower:clock-guard-primary@ironclaw,clock-guard-secondary@stonehide,clock-guard-instance-3@shellback,clock-guard-instance-4@frilled-naga\"}");yield return new WaitForSeconds(.8f);
  var four=FindObjectsByType<EnemyHandle>(FindObjectsSortMode.None).Where(h=>battle.BelongsToCurrentEncounter(h)).ToArray();Require(four.Length==4,"four species");Require(four.Select(h=>h.EnemyRoot.position).Distinct().Count()==4,"four non-overlapping formation points");Capture("four-species");
  for(int n=1;n<=6;n++){
   string id="b0"+n;bridge.ApplyCommand("{\"action\":\"wave-instances:clock-guard-primary@bounty-"+id+"\"}");yield return new WaitForSeconds(.8f);
   var a=FindObjectsByType<EnemyHandle>(FindObjectsSortMode.None).Single(h=>battle.BelongsToCurrentEncounter(h));Require(a.GetComponent<BountyIdentityPresentation20260917>().bountyID==id,"bounty identity "+id);
   if(n==1)Require(!a.GetComponentInChildren<FogGhostActor>(),"B01 must not be ghost");if(n==3)Require(a.GetComponentInChildren<FogGhostActor>(),"B03 must be ghost");
   Capture("bounty-"+id);Portrait(a,id);
   bridge.SetEnemyVisibility(a.BattleEnemyId+"=hidden");yield return new WaitForSeconds(.35f);
   var fade=a.GetComponentsInChildren<SkinnedMeshRenderer>().SelectMany(r=>r.sharedMaterials).First(m=>m.shader.name=="Mistport/BountyIdentityFade");Require(fade.GetFloat("_ExitOpacity")>0&&fade.GetFloat("_ExitOpacity")<1,"bounty material actually fades "+id);yield return new WaitForSeconds(.9f);Require(!a.gameObject.activeSelf,"bounty hidden "+id);bridge.SetEnemyVisibility(a.BattleEnemyId+"=visible");yield return new WaitForSeconds(.2f);Require(a.gameObject.activeInHierarchy,"bounty retry "+id);
  }
  File.WriteAllText(output+"/passed.txt","Five independent real skinned species, moving idle, every authored intent contact/preparation count, cancellation, support recipient death cancellation, death fade/retry, four distinct formation points, six bounty identities including B01 guard/B03 ghost. No phone verification.");EditorApplication.isPlaying=false;
 }
 void Portrait(EnemyHandle actor,string id){
  var camera=Camera.main;var old=camera.targetTexture;var active=RenderTexture.active;var pos=camera.transform.position;var rotation=camera.transform.rotation;bool ortho=camera.orthographic;float size=camera.orthographicSize,aspect=camera.aspect;int mask=camera.cullingMask;var flags=camera.clearFlags;var color=camera.backgroundColor;
  var objects=actor.EnemyRoot.GetComponentsInChildren<Transform>(true);var layers=objects.Select(t=>t.gameObject.layer).ToArray();
  var rt=new RenderTexture(320,400,24);var image=new Texture2D(320,400,TextureFormat.RGBA32,false);
  try{
   foreach(var t in objects)t.gameObject.layer=30;camera.cullingMask=1<<30;camera.clearFlags=CameraClearFlags.SolidColor;camera.backgroundColor=new Color(.045f,.05f,.065f,1);camera.orthographic=true;camera.orthographicSize=1.45f;camera.aspect=.8f;
   var body=actor.EnemyRoot.GetComponentsInChildren<SkinnedMeshRenderer>();var bounds=body[0].bounds;foreach(var skin in body)bounds.Encapsulate(skin.bounds);camera.orthographicSize=Mathf.Clamp(bounds.size.y*.5f,1.1f,2.3f);var center=new Vector3(bounds.center.x,bounds.min.y+bounds.size.y*.58f,bounds.center.z);camera.transform.position=center+Vector3.back*6;camera.transform.LookAt(center);camera.targetTexture=rt;camera.Render();RenderTexture.active=rt;image.ReadPixels(new Rect(0,0,320,400),0,0);image.Apply();string dir=Path.GetFullPath("../output/church-bounty-portraits");Directory.CreateDirectory(dir);File.WriteAllBytes(dir+"/"+id+".png",image.EncodeToPNG());
  }finally{for(int i=0;i<objects.Length;i++)objects[i].gameObject.layer=layers[i];camera.targetTexture=old;camera.transform.position=pos;camera.transform.rotation=rotation;camera.orthographic=ortho;camera.orthographicSize=size;camera.aspect=aspect;camera.cullingMask=mask;camera.clearFlags=flags;camera.backgroundColor=color;RenderTexture.active=active;Destroy(rt);Destroy(image);}
 }
 static void Require(bool ok,string why){if(!ok){Debug.LogError("CHURCH_MODELS_FAILED "+why);EditorApplication.Exit(3);throw new Exception(why);}}
 void Capture(string name){var camera=Camera.main;var old=camera.targetTexture;var active=RenderTexture.active;float aspect=camera.aspect;var rt=new RenderTexture(540,960,24);var image=new Texture2D(540,960,TextureFormat.RGB24,false);try{camera.aspect=540f/960;camera.targetTexture=rt;camera.Render();RenderTexture.active=rt;image.ReadPixels(new Rect(0,0,540,960),0,0);image.Apply();File.WriteAllBytes(output+"/"+name+".png",image.EncodeToPNG());}finally{camera.targetTexture=old;camera.aspect=aspect;RenderTexture.active=active;Destroy(rt);Destroy(image);}}
 void Frame(Stream stream,int w,int h){var camera=Camera.main;var old=camera.targetTexture;var active=RenderTexture.active;float aspect=camera.aspect;var rt=new RenderTexture(w,h,24);var image=new Texture2D(w,h,TextureFormat.RGB24,false);try{camera.aspect=(float)w/h;camera.targetTexture=rt;camera.Render();RenderTexture.active=rt;image.ReadPixels(new Rect(0,0,w,h),0,0);image.Apply();var bytes=image.GetRawTextureData<byte>().ToArray();stream.Write(bytes,0,bytes.Length);}finally{camera.targetTexture=old;camera.aspect=aspect;RenderTexture.active=active;Destroy(rt);Destroy(image);}}
 void OnDestroy(){Application.logMessageReceived-=Observe;}
}
