using System;using System.Collections;using System.IO;using System.Linq;using UnityEditor;using UnityEditor.SceneManagement;using UnityEngine;
public static class ChurchGrotesquePreview20260917 {
 const string Key="ChurchGrotesqueReview";
 public static void BeginDyehouse(){SessionState.SetBool("ChurchOnlyDyehouse",true);Begin();}
 public static void Begin(){SessionState.SetBool(Key,true);EditorSceneManager.OpenScene("Assets/Scenes/BattlePrototype.unity");EditorApplication.isPlaying=true;}
 [InitializeOnLoadMethod]static void Restore(){EditorApplication.playModeStateChanged+=s=>{if(!SessionState.GetBool(Key,false))return;if(s==PlayModeStateChange.EnteredPlayMode)new GameObject("Spell review").AddComponent<ChurchGrotesqueRunner20260917>();if(s==PlayModeStateChange.EnteredEditMode){SessionState.SetBool(Key,false);EditorApplication.Exit(0);}};}
}
public sealed class ChurchGrotesqueRunner20260917:MonoBehaviour{
 string output; UnityBattleBridge bridge;
 IEnumerator Start(){Time.captureFramerate=30;output=Path.GetFullPath("../output/church-grotesque-20260917");Directory.CreateDirectory(output);yield return new WaitForSeconds(3);bridge=FindFirstObjectByType<UnityBattleBridge>();
 string[] rows={"saltmaw|tower_poison|tower_salt_spike","shellback|tower_mend|tower_short_pounce","ironclaw|tower_cut_first|tower_cut_second|tower_heavy_cut","frilled-naga|tower_empower|tower_sound_arrow","boneclaw|tower_piercing_claw|tower_tail_sweep|tower_heavy_claw","stonehide|guard|archive_slam"};
 foreach(var row in rows){if(SessionState.GetBool("ChurchOnlyDyehouse",false)&&!row.StartsWith("bounty-b05"))continue;var r=row.Split('|');Send((r[0].StartsWith("bounty")?"wave-instances:":"church-tower:")+"clock-guard-primary@"+r[0]+(r[0].StartsWith("bounty")?"":",clock-guard-secondary@stonehide"));yield return new WaitForSeconds(.5f);Send("combat-start");
 for(int i=1;i<r.Length;i++){Send("enemy:clock-guard-primary:"+r[i]+((r[i]=="tower_mend"||r[i]=="tower_empower")?":clock-guard-secondary":""));for(int frame=0;frame<48;frame++){yield return null;Capture(r[0]+"-"+r[i]+"-"+frame.ToString("D2"));}yield return new WaitForSeconds(.3f);}
 Send("combat-stop");}
 Send("church-tower:clock-guard-primary@frilled-naga,clock-guard-secondary@stonehide");yield return new WaitForSeconds(.5f);Send("combat-start");Send("church-status:empowered:clock-guard-secondary");Send("church-status:poison:1");yield return new WaitForSeconds(.5f);Capture("persistent-poison-crown");Send("combat-stop");yield return null;if(FindObjectsByType<ChurchSpellVisual20260917>(FindObjectsSortMode.None).Length!=0)throw new Exception("status cleanup leaked");
 SessionState.SetBool("ChurchOnlyDyehouse",false);File.WriteAllText(output+"/passed.txt","Unity actual spell frames and persistent stop cleanup passed. Not phone verification.");EditorApplication.isPlaying=false;}
 void Send(string s){bridge.ApplyCommand("{\"action\":\""+s+"\"}");}
 void Capture(string name){var camera=Camera.main;var old=camera.targetTexture;var active=RenderTexture.active;float aspect=camera.aspect;var rt=new RenderTexture(720,1280,24);var image=new Texture2D(720,1280,TextureFormat.RGB24,false);try{camera.aspect=540f/960;var b=FindFirstObjectByType<BattlePrototype>();typeof(BattlePrototype).GetMethod("FitRuntimeBackground",System.Reflection.BindingFlags.Instance|System.Reflection.BindingFlags.NonPublic).Invoke(b,new object[]{camera});camera.targetTexture=rt;camera.Render();RenderTexture.active=rt;image.ReadPixels(new Rect(0,0,720,1280),0,0);image.Apply();File.WriteAllBytes(output+"/"+name+".png",image.EncodeToPNG());}finally{camera.targetTexture=old;camera.aspect=aspect;RenderTexture.active=active;Destroy(rt);Destroy(image);}}

}
