using System;using System.Collections;using System.IO;using UnityEngine;using UnityEditor;using UnityEditor.SceneManagement;
public static class ChapterOverviewCapture20260919 {
 const string Key="ChapterOverviewCapture20260919";
 public static void Begin(){SessionState.SetBool(Key,true);EditorSceneManager.OpenScene("Assets/Scenes/BattlePrototype.unity");EditorApplication.isPlaying=true;}
 [InitializeOnLoadMethod]static void Hook(){EditorApplication.playModeStateChanged+=s=>{if(!SessionState.GetBool(Key,false))return;if(s==PlayModeStateChange.EnteredPlayMode)new GameObject("Chapter overview capture").AddComponent<ChapterOverviewCaptureRunner20260919>();if(s==PlayModeStateChange.EnteredEditMode){SessionState.SetBool(Key,false);EditorApplication.Exit(0);}};}
}
public sealed class ChapterOverviewCaptureRunner20260919:MonoBehaviour {
 UnityBattleBridge bridge;BattlePrototype battle;string output,capture,error;int hits;
 void Observe(string s,string stack,LogType type){if(type==LogType.Exception||type==LogType.Assert)error=s;if(s.Contains("\"eventName\":\"combat-contact\"")&&!s.Contains("enemy-cancel:"))hits++;}
 void Send(string s){bridge.ApplyCommand("{\"action\":\""+s+"\"}");}
 IEnumerator Record(string dir,int count){Directory.CreateDirectory(dir);for(int i=0;i<count;i++){capture=dir+"/frame-"+i.ToString("D3")+".png";yield return null;}}
 IEnumerator Start(){output=Path.GetFullPath("../output/chapter-one-overview-20260919/boss-captures");Directory.CreateDirectory(output);Application.logMessageReceived+=Observe;Time.captureFramerate=30;yield return new WaitForSeconds(3);bridge=FindFirstObjectByType<UnityBattleBridge>();battle=FindFirstObjectByType<BattlePrototype>();
 foreach(int q in new[]{28,29,30}){Send("combat-stop");yield return null;Send("chapter-thirty:"+q);yield return new WaitForSeconds(.5f);Send("combat-start");
 for(int v=1;v<=2;v++){int before=hits;Send("enemy:clock-guard-primary");yield return Record(output+"/q"+q+"-spell-"+v,105);if(hits!=before+1||error!=null)throw new Exception("Boss contact failed Q"+q+" hits="+(hits-before)+" "+error);}
 if(q==29){Send("enemy:clock-guard-secondary");yield return Record(output+"/q29-executor",105);}
 bridge.SetEnemyVisibility("clock-guard-primary="+(q==30?"hidden":"retreat"));yield return Record(output+"/q"+q+"-exit",48);
 Send("combat-stop");yield return null;}
 File.WriteAllText(output+"/passed.txt","Q28/29/30 production rosters; two boss spells each exactly one contact. Q29 executor; actual retreat Q28/29 and death fade Q30. Presentation-only routing, not Swift five-cycle or whole-battle verification.");EditorApplication.isPlaying=false;}
 void LateUpdate(){if(capture==null)return;string path=capture;capture=null;var cam=Camera.main;var old=cam.targetTexture;var active=RenderTexture.active;float aspect=cam.aspect;var rt=new RenderTexture(540,960,24);var tex=new Texture2D(540,960,TextureFormat.RGB24,false);try{cam.aspect=540f/960;typeof(BattlePrototype).GetMethod("FitRuntimeBackground",System.Reflection.BindingFlags.Instance|System.Reflection.BindingFlags.NonPublic).Invoke(battle,new object[]{cam});cam.targetTexture=rt;cam.Render();RenderTexture.active=rt;tex.ReadPixels(new Rect(0,0,540,960),0,0);tex.Apply();File.WriteAllBytes(path,tex.EncodeToPNG());}finally{cam.targetTexture=old;cam.aspect=aspect;RenderTexture.active=active;Destroy(rt);Destroy(tex);}}
 void OnDestroy(){Application.logMessageReceived-=Observe;}
}
