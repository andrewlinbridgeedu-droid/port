using System;
using System.Collections;
using System.IO;
using System.Linq;
using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEngine;
public static class ChronarchPreview20260916 {
 const string Key="Mistport.ChronarchPreview";
 public static void Begin(){SessionState.SetBool(Key,true);EditorSceneManager.NewScene(NewSceneSetup.EmptyScene,NewSceneMode.Single);EditorApplication.isPlaying=true;}
 [InitializeOnLoadMethod]static void Restore(){EditorApplication.playModeStateChanged+=s=>{if(!SessionState.GetBool(Key,false))return;if(s==PlayModeStateChange.EnteredPlayMode)new GameObject("Chronarch QA").AddComponent<ChronarchPreviewRunner>();if(s==PlayModeStateChange.EnteredEditMode){SessionState.SetBool(Key,false);EditorApplication.Exit(0);}};}
}
public sealed class ChronarchPreviewRunner:MonoBehaviour {
 string dir;Camera camera;
 IEnumerator Start(){
  dir=Path.GetFullPath("../output/chronarch-delivery-20260916/unity");Directory.CreateDirectory(dir);
  var profile=Resources.Load<EnemyVisualProfile>("Enemies/Signature/Chronarch/VisualProfile");
  var formation=AssetDatabase.LoadAssetAtPath<EnemyFormationProfile>(Install3DAssets.FormationAssetPath);
  var actor=EnemyPresenter.Present(new EnemyPresentationRequest{Profile=profile,Formation=formation,SlotId=EnemyFormationSlotIds.FrontCenter,BattleEnemyId="chronarch-test",EnableMotion=false});
  var presentation=actor.gameObject.AddComponent<ChronarchPresentation20260916>();presentation.FitRestPose();
  var cam=new GameObject("Camera");camera=cam.AddComponent<Camera>();camera.backgroundColor=new Color(.055f,.065f,.09f);camera.clearFlags=CameraClearFlags.SolidColor;
  var center=actor.transform.position+Vector3.up*1.45f;cam.transform.position=center+new Vector3(0,.0f,-6);cam.transform.LookAt(center);camera.orthographic=true;camera.orthographicSize=1.8f;
  RenderSettings.ambientLight=new Color(.5f,.52f,.58f);
  var light=new GameObject("Key").AddComponent<Light>();light.type=LightType.Directional;light.intensity=.8f;light.transform.rotation=Quaternion.Euler(35,-25,0);
  yield return new WaitForSeconds(1f);
  foreach(var other in FindObjectsByType<Light>(FindObjectsSortMode.None))if(other!=light)other.enabled=false;
  Require(actor.GetComponentsInChildren<SkinnedMeshRenderer>().Any(s=>s.bones.Length>=20),"missing actual skin");
  for(int i=0;i<8;i++){yield return new WaitForSeconds(.25f);Capture("idle-"+i);}
  var target=new GameObject("ContactTarget");target.transform.position=actor.transform.position+Vector3.back*2.8f;
  int hits=0;bool valid=true;
  for(int variant=0;variant<2;variant++){
   int old=hits;StartCoroutine(presentation.Strike(actor,target.transform,()=>hits++,()=>valid));
   for(int i=0;i<10;i++){yield return new WaitForSeconds(.27f);Capture("cast-"+variant+"-"+i);}
   Require(hits==old+1,"exactly one contact per authored attack");
  }
  int before=hits;StartCoroutine(presentation.Strike(actor,target.transform,()=>hits++,()=>valid));yield return new WaitForSeconds(.2f);presentation.Cancel();yield return new WaitForSeconds(1.1f);Require(hits==before,"cancel contact leak");
  var animator=actor.GetComponentInChildren<Animator>();presentation.BeginRetreat();yield return new WaitForSeconds(.6f);Capture("alive-retreat");Require(animator.GetCurrentAnimatorStateInfo(0).IsName("Retreat"),"retreat must not be death");animator.Play("Death",0,0);
  for(int i=0;i<5;i++){yield return new WaitForSeconds(.2f);Capture("death-"+i);}
  animator.Play("Meshy · Idle",0,0);yield return new WaitForSeconds(.3f);Capture("restored");
  Require(animator.GetCurrentAnimatorStateInfo(0).IsName("Meshy · Idle"),"retry not Idle");
  File.WriteAllText(dir+"/passed.txt","Independent Unity PlayMode: actual skinned model, idle time samples, two cast variants each contact exactly once, cancel no contact, nonlethal Retreat, death clip and restore. Does not validate chapter routing, full fade or phone.\n");EditorApplication.isPlaying=false;
 }
 static void Require(bool ok,string message){if(!ok){Debug.LogError(message);EditorApplication.Exit(3);throw new Exception(message);}}
 void Capture(string name){var prev=camera.targetTexture;var active=RenderTexture.active;var rt=new RenderTexture(640,800,24);var image=new Texture2D(640,800,TextureFormat.RGB24,false);try{camera.aspect=.8f;camera.targetTexture=rt;camera.Render();RenderTexture.active=rt;image.ReadPixels(new Rect(0,0,640,800),0,0);image.Apply();File.WriteAllBytes(dir+"/"+name+".png",image.EncodeToPNG());}finally{camera.targetTexture=prev;RenderTexture.active=active;Destroy(rt);Destroy(image);}}
}
