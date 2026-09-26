using System.IO;using UnityEditor;using UnityEditor.SceneManagement;using UnityEngine;
public static class HeroCompactCheck20260918 {
 const string Key="HeroCompactCheck20260918";
 const string Output="/tmp/mistport-hero-compact";
 public static void Begin(){Directory.CreateDirectory(Output);File.Delete(Output+"/passed.txt");File.Delete(Output+"/failed.txt");System.Environment.SetEnvironmentVariable("MISTPORT_HERO_CAPTURE",Output);SessionState.SetBool(Key,true);EditorSceneManager.OpenScene("Assets/Scenes/BattlePrototype.unity");EditorApplication.isPlaying=true;}
 [InitializeOnLoadMethod]static void Hook(){
 EditorApplication.playModeStateChanged+=s=>{if(SessionState.GetBool(Key,false)&&s==PlayModeStateChange.EnteredPlayMode)new GameObject("Compact cast verification").AddComponent<HeroSkillChoreographyCapture>();};
 EditorApplication.update+=()=>{if(!SessionState.GetBool(Key,false))return;bool fail=File.Exists(Output+"/failed.txt");if(fail||File.Exists(Output+"/passed.txt")){SessionState.SetBool(Key,false);EditorApplication.Exit(fail?1:0);}};
 }
}
