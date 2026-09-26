using System;
using System.Collections;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEngine;
public static class ChurchVisualFinalPreview20260917 {
 const string Key="Mistport.ChurchVisualFinalPreview";
 public static void Begin(){SessionState.SetBool(Key,true);EditorSceneManager.OpenScene("Assets/Scenes/BattlePrototype.unity");EditorApplication.isPlaying=true;}
 [InitializeOnLoadMethod]static void Restore(){EditorApplication.playModeStateChanged+=s=>{if(!SessionState.GetBool(Key,false))return;if(s==PlayModeStateChange.EnteredPlayMode)new GameObject("Church model verification").AddComponent<ChurchVisualFinalRunner20260917>();if(s==PlayModeStateChange.EnteredEditMode){SessionState.SetBool(Key,false);EditorApplication.Exit(0);}};}
}
public sealed class ChurchVisualFinalRunner20260917:MonoBehaviour {
 BattlePrototype battle;UnityBattleBridge bridge;string output;
 readonly Dictionary<string,int> contacts=new Dictionary<string,int>();
 int Count(string id)=>contacts.TryGetValue(id,out int n)?n:0;
 void Observe(string message,string trace,LogType type){if(!message.Contains("combat-contact"))return;foreach(var id in new[]{"hell-hound-primary","clock-guard-primary","clock-guard-secondary","clock-guard-instance-3","clock-guard-instance-4"})if(message.Contains("enemy:"+id))contacts[id]=Count(id)+1;}
 IEnumerator Start(){
  output=Path.GetFullPath("../output/church-demons-combat-20260917/unity");Directory.CreateDirectory(output);
  Application.logMessageReceived+=Observe;yield return new WaitForSeconds(3);battle=FindFirstObjectByType<BattlePrototype>();bridge=FindFirstObjectByType<UnityBattleBridge>();
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
  File.WriteAllText(output+"/visual-passed.txt","Final four-species staggered layout and six bounty portraits/fade/retry. No phone verification.");EditorApplication.isPlaying=false;
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
