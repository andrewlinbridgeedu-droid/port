using System;using System.Collections;using System.Collections.Generic;using System.IO;using System.Linq;using System.Reflection;using UnityEngine;using UnityEditor;using UnityEditor.SceneManagement;
public static class ReferenceSpellsReview20260921{
 const string Key="ReferenceSpellsReview20260921";
 public static void Begin(){SessionState.SetBool(Key,true);EditorSceneManager.OpenScene("Assets/Scenes/BattlePrototype.unity");EditorApplication.isPlaying=true;}
 [InitializeOnLoadMethod]static void Init(){EditorApplication.playModeStateChanged+=s=>{if(!SessionState.GetBool(Key,false))return;if(s==PlayModeStateChange.EnteredPlayMode)new GameObject(Key).AddComponent<ReferenceSpellsRunner20260921>();if(s==PlayModeStateChange.EnteredEditMode){SessionState.SetBool(Key,false);EditorApplication.Exit(0);}};}
}
[DefaultExecutionOrder(3500)]public sealed class ReferenceSpellsRunner20260921:MonoBehaviour{
 string output;BattlePrototype battle;UnityBattleBridge bridge;Camera cam;GameObject player;FoolSkillChoreography gesture;string pending;bool errors;TrialBloom bloom;
 readonly List<string> checks=new List<string>();
 void Send(string a){bridge.ApplyCommand("{\"action\":\""+a+"\"}");}
 void Check(bool ok,string what){if(!ok){Debug.LogError(what);File.WriteAllText(output+"/failed.txt",what);EditorApplication.Exit(3);}checks.Add(what);}
 void Log(string s,string st,LogType t){if(t==LogType.Error||t==LogType.Exception)errors=true;}
 IEnumerator Start(){output=Path.GetFullPath("../output/target-instances-20260921");Directory.CreateDirectory(output);Application.logMessageReceived+=Log;Time.captureFramerate=30;yield return new WaitForSeconds(3);
 battle=FindFirstObjectByType<BattlePrototype>();bridge=FindFirstObjectByType<UnityBattleBridge>();cam=Camera.main;cam.allowHDR=true;bloom=cam.gameObject.AddComponent<TrialBloom>();
 Send("combat-stop");Send("church-tower:clock-guard-primary@stonehide,clock-guard-secondary@ironclaw,clock-guard-tertiary@boneclaw");yield return new WaitForSeconds(.3f);Send("combat-start");yield return new WaitForSeconds(.2f);
 player=(GameObject)typeof(BattlePrototype).GetField("player",BindingFlags.Instance|BindingFlags.NonPublic).GetValue(battle);gesture=FoolSkillChoreography.Install(player.transform);
 var enemies=FindObjectsByType<EnemyHandle>(FindObjectsSortMode.None).Where(h=>battle.BelongsToCurrentEncounter(h)).OrderBy(h=>h.BattleEnemyId).ToArray();
 Debug.Log("TRIAL player="+player.transform.position+" enemyCount="+enemies.Length);
 Vector3[] targets=new Vector3[enemies.Length];for(int i=0;i<enemies.Length;i++){var e=enemies[i];var pos=e.EnemyRoot.position;pos.x=(i-(enemies.Length-1)*.5f)*2.1f;pos.z=3.7f+(i==1?1f:0);e.EnemyRoot.position=pos;targets[i]=new Vector3(pos.x,.04f,pos.z);Debug.Log("TRIAL target="+targets[i]);}
 var cameraPosition=cam.transform.position;
 var baseRot=enemies.Select(e=>e.EnemyRoot.rotation).ToArray();
 var origin=new Vector3(player.transform.position.x,.04f,player.transform.position.z+.65f);var target=new Vector3(0,.04f,4.3f);
 var art=AssetDatabase.LoadAssetAtPath<Texture2D>("Assets/VFX_Trials/Textures/PhoenixWing.png");var wingAsset=AssetDatabase.LoadAssetAtPath<GameObject>("Assets/VFX_Trials/Meshes/PhoenixWing.fbx");Mesh wingMesh=wingAsset.GetComponentInChildren<MeshFilter>().sharedMesh;Debug.Log("TRIAL wing bounds="+wingMesh.bounds);
 string filter=Environment.GetCommandLineArgs().FirstOrDefault(a=>a.StartsWith("--trial="));
 for(int kind=0;kind<3;kind++){string id=new[]{"phoenix","rift","thunder"}[kind];if(filter!=null&&filter.Substring(8)!=id)continue;
 var root=new GameObject("Reference trial "+id);Action<float> sample;
 int count=3;var countArg=Environment.GetCommandLineArgs().FirstOrDefault(a=>a.StartsWith("--targets="));if(countArg!=null)count=int.Parse(countArg.Substring(10));
 var selected=enemies.Take(count).Select(e=>e.EnemyRoot).ToArray();var selectedIds=enemies.Take(count).Select(e=>e.BattleEnemyId).ToArray();
 var instance=root.AddComponent<TargetSpellTrial>();var texture=kind==0?art:AssetDatabase.LoadAssetAtPath<Texture2D>(kind==1?"Assets/VFX_Trials/Textures/GoldenRiftContinuous.png":"Assets/VFX_Trials/Textures/IceFlower.png");
 instance.Build((TargetSpellTrial.Style)kind,origin,selected,selectedIds,texture,wingMesh);sample=instance.Sample;
 Check(instance.LiveCount==selected.Length,id+" exact target instance count");
 id+="-"+count;

 Directory.CreateDirectory(output+"/frames/"+id);gesture.Begin(kind==0?"fool_skill_07":kind==1?"fool_skill_03":"fool_skill_08");
 for(int frame=0;frame<96;frame++){float t=frame/30f-.25f;float contact=kind==0?.72f:.50f;float hold=kind==0?.166667f:.20f;bool stop=kind!=1&&t>=contact&&t<contact+hold;
 float visual=t;if(kind!=1&&t>=contact)visual=stop?contact+.018f:contact+.018f+(t-contact-hold)*1.6f;
 float shakeAge=t-contact-hold;float shake=kind==1||shakeAge<0?0:Mathf.Exp(-shakeAge*14)*.13f;cam.transform.position=cameraPosition+new Vector3(Mathf.Sin(frame*2.7f)*shake,Mathf.Cos(frame*3.9f)*shake*.65f,0);
 Time.timeScale=stop?0:1;sample(Mathf.Max(0,visual));
 if(kind!=1){float age=t-contact-hold;float recoil=age<0?0:Mathf.Sin(Mathf.Clamp01(age/.24f)*Mathf.PI);for(int q=0;q<selected.Length;q++)selected[q].rotation=Quaternion.AngleAxis(-24*recoil,Vector3.right)*baseRot[q];}
 if(frame==(kind==0?29:kind==1?35:23))gesture.Contact();if(frame==58)gesture.Finish();if(!Environment.GetCommandLineArgs().Contains("--keyframes")||frame==32||frame==38||frame==47)pending=id+"/frame-"+frame.ToString("D3")+".png";yield return null;}
 Time.timeScale=1;cam.transform.position=cameraPosition;sample(2.5f);yield return null;Check(!root.GetComponentsInChildren<Renderer>().Any(r=>r.enabled&&r.gameObject.activeInHierarchy),id+" completely clear at 2.5s");
 // Scrub/replay must work without rebuilding or stale animation state.
 sample(.80f);Check(root.GetComponentsInChildren<Renderer>().Any(r=>r.enabled&&r.gameObject.activeInHierarchy),id+" replay after completed sample");bloom.enabled=false;Capture(output+"/"+id+"-no-bloom.png");bloom.enabled=true;
 sample(.8f);var moved=selected[0].position;selected[0].position+=Vector3.right*.6f;sample(.8f);Check(instance.LiveCount==selected.Length,id+" moving recipient retains identity");selected[0].position=moved;
 selected[0].gameObject.SetActive(false);sample(.8f);yield return null;Check(instance.LiveCount==selected.Length-1,id+" departed recipient removes only its instance");selected[0].gameObject.SetActive(true);
 sample(2.5f);Destroy(root);gesture.Clear();yield return null;Check(!root,id+" cancellation destroys instance");yield return new WaitForSeconds(.15f);
 }
 Check(!errors,"no runtime errors");File.WriteAllLines(output+"/passed.txt",checks);Application.logMessageReceived-=Log;EditorApplication.isPlaying=false;
 }
 void LateUpdate(){if(pending==null)return;Capture(output+"/frames/"+pending);pending=null;}
 void Capture(string file){var old=cam.targetTexture;var active=RenderTexture.active;float aspect=cam.aspect;var rt=new RenderTexture(720,1280,24,RenderTextureFormat.ARGBHalf);var tex=new Texture2D(720,1280,TextureFormat.RGB24,false);try{cam.aspect=720f/1280;typeof(BattlePrototype).GetMethod("FitRuntimeBackground",BindingFlags.Instance|BindingFlags.NonPublic).Invoke(battle,new object[]{cam});cam.targetTexture=rt;cam.Render();RenderTexture.active=rt;tex.ReadPixels(new Rect(0,0,720,1280),0,0);tex.Apply();File.WriteAllBytes(file,tex.EncodeToPNG());}finally{cam.targetTexture=old;cam.aspect=aspect;RenderTexture.active=active;Destroy(rt);Destroy(tex);}}
}
