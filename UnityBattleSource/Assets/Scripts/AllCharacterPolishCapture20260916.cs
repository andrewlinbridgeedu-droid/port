#if UNITY_EDITOR || UNITY_STANDALONE
using UnityEngine;
using System;
using System.Collections;
using System.IO;
using System.Linq;
using System.Reflection;
using System.Collections.Generic;
public sealed class AllCharacterPolishCapture20260916:MonoBehaviour {
    string dir;BattlePrototype battle; readonly List<string> report=new List<string>();
    [RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.AfterSceneLoad)]
    static void Boot(){if(Environment.GetCommandLineArgs().Contains("--verify-character-polish"))new GameObject("Character polish capture").AddComponent<AllCharacterPolishCapture20260916>();}
    static void Surfaces(bool on){
        var type=typeof(BattlePrototype).Assembly.GetType("CharacterSurfaceRefinement20260916");
        if(type==null)throw new Exception("Material refinement component missing");
        var method=type.GetMethod("ShowAll",BindingFlags.Static|BindingFlags.Public);
        if(method==null)throw new Exception("ShowAll material switch missing");method.Invoke(null,new object[]{on});
    }
    IEnumerator Start(){
        dir=Environment.GetEnvironmentVariable("MISTPORT_CHARACTER_CAPTURE")??"/tmp/character-polish";Directory.CreateDirectory(dir);
        Screen.SetResolution(540,960,false);yield return new WaitForSeconds(3);Time.captureFramerate=12;
        battle=FindFirstObjectByType<BattlePrototype>();
        string[] cases={"guard","ghost","red-ghosts","early-hound","armored-hound","emerald","core","leech","archivist","matriarch","scribe","rescue"};
        var requested=Environment.GetEnvironmentVariable("MISTPORT_CHARACTER_CASES");
        if(!string.IsNullOrEmpty(requested))cases=cases.Where(x=>requested.Split(',').Contains(x)).ToArray();
        int frames=72;int parsed;if(int.TryParse(Environment.GetEnvironmentVariable("MISTPORT_CHARACTER_FRAMES"),out parsed))frames=Mathf.Clamp(parsed,72,360);
        foreach(var name in cases){
            battle.SetNativeCombatEnabled(false);battle.SetEncoreRevenant(false);
            switch(name){
                case "guard":battle.UseClockGuardModel();break;
                case "ghost":case "red-ghosts":battle.UseDualClockGuardModel();break;
                case "early-hound":battle.UseEarlyHellHoundModel();break;
                case "armored-hound":battle.UseHellHoundModel();break;
                case "emerald":battle.UseHellHoundModel();battle.SetEncoreRevenant(true);break;
                case "core":battle.UseClockCoreModel();break;
                case "leech":battle.UseP1Escort(true);break;
                case "archivist":battle.ConfigureWaveInstances("clock-guard-primary@archivist");break;
                case "scribe":battle.ConfigureWaveInstances("clock-guard-primary@scribe");break;
                case "rescue":battle.ConfigureWaveInstances("clock-guard-primary@rescue");break;
                case "matriarch":battle.ConfigureWaveInstances("clock-guard-primary@matriarch");break;
            }
            battle.SetEarlyBattlePresence((name=="ghost"||name=="red-ghosts")?"2":name=="early-hound"?"4":name=="emerald"?"5":"15");
            if(name=="red-ghosts"){
                var bridge=FindFirstObjectByType<UnityBattleBridge>();
                bridge.SetEnemyVisibility("clock-guard-primary=hidden;clock-guard-secondary=hidden");
                yield return new WaitForSeconds(1.3f);
                bridge.SetEnemyVisibility("clock-guard-instance-3=visible;clock-guard-instance-4=visible;clock-guard-instance-5=visible;clock-guard-instance-6=visible");
            }
            yield return new WaitForSeconds(.6f);
            CharacterSurfaceRefinement20260916.InstallAllVisible(GameObject.Find("Fool_Imported"));
            var actors=FindObjectsByType<EnemyHandle>(FindObjectsSortMode.None).Where(h=>battle.BelongsToCurrentEncounter(h)&&h.GetComponentsInChildren<Renderer>().Any(r=>r.enabled)).ToArray();
            if(actors.Length==0)throw new Exception("Missing actor "+name);
            Time.timeScale=0;Surfaces(false);EarlyEnemyIdlePresence.ArtPolishEnabled=false;HeroLivingIdle20260916.PolishEnabled=false;
            yield return null;yield return new WaitForEndOfFrame();Shot(name+"-before.png");
            Surfaces(true);EarlyEnemyIdlePresence.ArtPolishEnabled=true;HeroLivingIdle20260916.PolishEnabled=true;
            yield return null;yield return new WaitForEndOfFrame();Shot(name+"-after.png");Time.timeScale=1;
            var transforms=actors.SelectMany(h=>h.GetComponentsInChildren<Transform>()).ToArray();
            var initial=transforms.Select(t=>t.localRotation).ToArray();float maxMotion=0;
            Directory.CreateDirectory(Path.Combine(dir,name));
            for(int frame=0;frame<frames;frame++){
                yield return null;yield return new WaitForEndOfFrame();Shot(name+"/frame-"+frame.ToString("D3")+".png");
                for(int i=0;i<transforms.Length;i++)if(transforms[i])maxMotion=Mathf.Max(maxMotion,Quaternion.Angle(initial[i],transforms[i].localRotation));
            }
            report.Add(name+" actors="+actors.Length+" sampledLocalRotation="+maxMotion.ToString("F3"));
            File.WriteAllLines(Path.Combine(dir,"report.txt"),report);
        }
        File.WriteAllText(Path.Combine(dir,"passed.txt"),"Actual runtime stills and 12fps clips. The before switch disables historical refinements too; use the archived previous build for revision comparison. Not phone performance or visual acceptance.\n");Application.Quit(0);
    }
    void Shot(string name){var image=new Texture2D(Screen.width,Screen.height,TextureFormat.RGB24,false);image.ReadPixels(new Rect(0,0,Screen.width,Screen.height),0,0);image.Apply();File.WriteAllBytes(Path.Combine(dir,name),image.EncodeToPNG());Destroy(image);}
}
#endif
