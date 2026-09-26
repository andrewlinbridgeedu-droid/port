using System;using System.Collections;using System.IO;using System.Linq;using UnityEditor;using UnityEditor.SceneManagement;using UnityEngine;
public static class ChurchSpellsPreview20260917 {
 const string Key="ChurchSpellReview";
 public static void BeginDyehouse(){SessionState.SetBool("ChurchOnlyDyehouse",true);Begin();}
 public static void Begin(){SessionState.SetBool(Key,true);EditorSceneManager.OpenScene("Assets/Scenes/BattlePrototype.unity");EditorApplication.isPlaying=true;}
 [InitializeOnLoadMethod]static void Restore(){EditorApplication.playModeStateChanged+=s=>{if(!SessionState.GetBool(Key,false))return;if(s==PlayModeStateChange.EnteredPlayMode)new GameObject("Spell review").AddComponent<ChurchSpellsRunner20260917>();if(s==PlayModeStateChange.EnteredEditMode){SessionState.SetBool(Key,false);EditorApplication.Exit(0);}};}
}
public sealed class ChurchSpellsRunner20260917:MonoBehaviour{
 string output; UnityBattleBridge bridge;
 IEnumerator Start(){output=Path.GetFullPath("../output/church-spells-20260917");Directory.CreateDirectory(output);yield return new WaitForSeconds(3);bridge=FindFirstObjectByType<UnityBattleBridge>();
 string[] rows={"saltmaw|tower_poison|tower_salt_spike","shellback|tower_mend|tower_short_pounce","ironclaw|tower_cut_first|tower_heavy_cut","frilled-naga|tower_empower|tower_sound_arrow","boneclaw|tower_piercing_claw|tower_tail_sweep|tower_heavy_claw","stonehide|guard|archive_slam","bounty-b01|ambush","bounty-b02|bind","bounty-b03|heavy_strike","bounty-b04|overwrite","bounty-b05|silk_bind","bounty-b06|guard|heavy_strike"};
 foreach(var row in rows){if(SessionState.GetBool("ChurchOnlyDyehouse",false)&&!row.StartsWith("bounty-b05"))continue;var r=row.Split('|');Send((r[0].StartsWith("bounty")?"wave-instances:":"church-tower:")+"clock-guard-primary@"+r[0]+(r[0].StartsWith("bounty")?"":",clock-guard-secondary@stonehide"));yield return new WaitForSeconds(.5f);Send("combat-start");
 for(int i=1;i<r.Length;i++){Send("enemy:clock-guard-primary:"+r[i]+((r[i]=="tower_mend"||r[i]=="tower_empower")?":clock-guard-secondary":""));yield return new WaitForSeconds(.38f);Capture(r[0]+"-"+r[i]+"-flight");yield return new WaitForSeconds(.35f);Capture(r[0]+"-"+r[i]+"-impact");yield return new WaitForSeconds(.7f);}
 Send("combat-stop");}
 Send("church-tower:clock-guard-primary@frilled-naga,clock-guard-secondary@stonehide");yield return new WaitForSeconds(.5f);Send("combat-start");Send("church-status:empowered:clock-guard-secondary");Send("church-status:poison:1");yield return new WaitForSeconds(.5f);Capture("persistent-poison-crown");Send("combat-stop");yield return null;if(FindObjectsByType<ChurchSpellVisual20260917>(FindObjectsSortMode.None).Length!=0)throw new Exception("status cleanup leaked");
 SessionState.SetBool("ChurchOnlyDyehouse",false);File.WriteAllText(output+"/passed.txt","Unity actual spell frames and persistent stop cleanup passed. Not phone verification.");EditorApplication.isPlaying=false;}
 void Send(string s){bridge.ApplyCommand("{\"action\":\""+s+"\"}");}
 void Capture(string name){var camera=Camera.main;var old=camera.targetTexture;var active=RenderTexture.active;float aspect=camera.aspect;var rt=new RenderTexture(540,960,24);var image=new Texture2D(540,960,TextureFormat.RGB24,false);try{camera.aspect=540f/960;var b=FindFirstObjectByType<BattlePrototype>();typeof(BattlePrototype).GetMethod("FitRuntimeBackground",System.Reflection.BindingFlags.Instance|System.Reflection.BindingFlags.NonPublic).Invoke(b,new object[]{camera});camera.targetTexture=rt;camera.Render();RenderTexture.active=rt;image.ReadPixels(new Rect(0,0,540,960),0,0);image.Apply();File.WriteAllBytes(output+"/"+name+".png",image.EncodeToPNG());}finally{camera.targetTexture=old;camera.aspect=aspect;RenderTexture.active=active;Destroy(rt);Destroy(image);}}

}
