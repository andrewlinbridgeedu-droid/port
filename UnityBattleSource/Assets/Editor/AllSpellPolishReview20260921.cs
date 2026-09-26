using System;using System.Collections;using System.Collections.Generic;using System.IO;using UnityEditor;using UnityEditor.SceneManagement;using UnityEngine;
public static class AllSpellPolishReview20260921 {
 const string Key="AllSpellPolishReview20260921";
 public static void Begin(){SessionState.SetBool(Key,true);EditorSceneManager.OpenScene("Assets/Scenes/BattlePrototype.unity");EditorApplication.isPlaying=true;}
 [InitializeOnLoadMethod]static void Hook(){EditorApplication.playModeStateChanged+=s=>{if(!SessionState.GetBool(Key,false))return;if(s==PlayModeStateChange.EnteredPlayMode)new GameObject("All spell tier review").AddComponent<AllSpellPolishRunner20260921>();if(s==PlayModeStateChange.EnteredEditMode){SessionState.SetBool(Key,false);EditorApplication.Exit(0);}};}
}
[DefaultExecutionOrder(4000)] public sealed class AllSpellPolishRunner20260921:MonoBehaviour {
 UnityBattleBridge bridge;BattlePrototype battle;string output,capture,error;bool safety;string filter;int hits;readonly List<string> report=new List<string>();
 void Observe(string s,string stack,LogType kind){if(kind==LogType.Exception||kind==LogType.Assert)error=s;if(s.Contains("\"eventName\":\"combat-contact\"")&&!s.Contains("enemy-cancel:"))hits++;}
 void Send(string s){bridge.ApplyCommand("{\"action\":\""+s+"\"}");}
 void Check(bool ok,string s){if(!ok){File.WriteAllText(output+"/failed.txt",s+"\n"+error);Debug.LogError("TIER_FAIL "+s);EditorApplication.Exit(3);throw new Exception(s);}report.Add(s);Debug.Log("TIER_PASS "+s);}
 IEnumerator Setup(string command){Send("combat-stop");yield return null;Send(command);yield return new WaitForSeconds(.45f);Send("combat-start");}
 IEnumerator Clip(string name,string command,float seconds=3,int expected=1){
 if(filter!=null&&!Array.Exists(filter.Split(','),x=>name.StartsWith(x)))yield break;
 if(safety){
 if(name=="bounty-bindings-state"){
  Send(command);yield return new WaitForSeconds(.4f);
  var binding=FindFirstObjectByType<BindingRibbon20260921>();
  Check(binding&&BindingEffekseerAccent20260921.ActiveHandles>0,"binding state creates actual Effekseer handles");
  var mesh=binding.GetComponent<MeshFilter>().sharedMesh;var first=mesh.vertices[300];
  yield return new WaitForSeconds(.45f);
  Check((mesh.vertices[300]-first).sqrMagnitude>.001f,"binding state surface continues moving");
  yield return new WaitForSeconds(2.4f);
  Check(BindingEffekseerAccent20260921.ActiveHandles>0&&BindingEffekseerAccent20260921.ActiveHandles<=3,"binding renewal has bounded live handles");
  Check(binding.GetComponent<BindingEffekseerAccent20260921>().ReleasePlayCount==0&&binding.GetComponent<BindingImpact20260921>().VisibleSurfaceCount==0,"persistent bindings do not replay a hit explosion");
  Send("combat-stop");yield return null;yield return null;
  Check(!FindFirstObjectByType<BindingRibbon20260921>()&&BindingEffekseerAccent20260921.ActiveHandles==0,"binding state stop cleans mesh and handles");
  Send("combat-start");Send(command);yield return new WaitForSeconds(.4f);
  Check(FindObjectsByType<BindingRibbon20260921>(FindObjectsSortMode.None).Length==1&&BindingEffekseerAccent20260921.ActiveHandles>0,"binding state retry creates one owner");
  Send("combat-stop");yield return null;yield return null;
  Check(BindingEffekseerAccent20260921.ActiveHandles==0,"binding retry stop clears handles");
  yield break;
 }
 if(expected!=1){Send(command);yield return new WaitForSeconds(seconds);yield break;}int initial=hits;Send(command);yield return new WaitForSeconds(.06f);Send("combat-stop");yield return new WaitForSeconds(seconds);Check(hits==initial,name+" cancel zero late contacts");Check(FindObjectsByType<BountyContactBurst20260919>(FindObjectsSortMode.None).Length==0&&FindObjectsByType<EnemyAuthoredBurstTier20260919>(FindObjectsSortMode.None).Length==0&&FindObjectsByType<SaltmawSpell20260919>(FindObjectsSortMode.None).Length==0&&FindObjectsByType<IronclawSpell20260918>(FindObjectsSortMode.None).Length==0&&FindObjectsByType<BindingRibbon20260921>(FindObjectsSortMode.None).Length==0&&BindingEffekseerAccent20260921.ActiveHandles==0,name+" owned roots cleaned");Send("combat-start");Send(command);yield return new WaitForSeconds(seconds);Check(hits==initial+1,name+" retry exactly once");
 if(name=="bounty-b02-bind"){
  int beforeContact=hits;Send(command);yield return new WaitForSeconds(.74f);
  Check(hits==beforeContact+1,"binding actual contact fires once before stop");
  Check(BindingEffekseerAccent20260921.ActiveHandles>0,"binding contact owns Effekseer pulse");
  Send("combat-stop");yield return null;yield return null;yield return new WaitForSeconds(.7f);
  Check(hits==beforeContact+1&&BindingEffekseerAccent20260921.ActiveHandles==0,"binding after-contact stop has no late hit or handles");
  Send("combat-start");int beforeRelease=hits;Send(command);yield return new WaitForSeconds(.94f);
  var releaseOwner=FindFirstObjectByType<BindingEffekseerAccent20260921>();
  Check(releaseOwner&&releaseOwner.ReleaseIsAlive&&releaseOwner.ReleasePlayCount==1,"binding release bursts exactly once with live Effekseer");
  Send("combat-stop");yield return null;yield return null;yield return new WaitForSeconds(.7f);
  Check(hits==beforeRelease+1&&BindingEffekseerAccent20260921.ActiveHandles==0&&!FindFirstObjectByType<BindingImpact20260921>(),"binding peak cancellation clears flares and particles without another hit");
  Send("combat-start");
 }
 yield break;}
 string dir=output+"/"+name;Directory.CreateDirectory(dir);int before=hits;Send(command);
 var timing=new List<string>();float lastClock=-1,holdWidth=0,peakWidth=0;int equalClocks=0,maxEqualClocks=0;
 for(int f=0;f<Mathf.CeilToInt(seconds*30);f++){capture=dir+"/frame-"+f.ToString("D3")+".png";yield return null;
  if(name=="bounty-b02-bind"){
   var v=FindFirstObjectByType<BindingRibbon20260921>();if(v){
    float c=v.GetComponent<MeshRenderer>().sharedMaterial.GetFloat("_Age"),w=v.GetComponent<MeshFilter>().sharedMesh.bounds.size.x;
    if(Mathf.Abs(c-lastClock)<.00001f){equalClocks++;holdWidth=w;}else equalClocks=1;
    maxEqualClocks=Mathf.Max(maxEqualClocks,equalClocks);lastClock=c;if(holdWidth>0)peakWidth=Mathf.Max(peakWidth,w);
    timing.Add(f+","+c.ToString("F6",System.Globalization.CultureInfo.InvariantCulture)+","+w.ToString("F6",System.Globalization.CultureInfo.InvariantCulture));
   }
  }}
 if(name=="bounty-b02-bind"){
  timing.Insert(0,"recorded_frame,visual_clock,world_mesh_width");File.WriteAllLines(output+"/binding-impact-timing.csv",timing);
  Check(maxEqualClocks>=5,"binding rendered contact holds at least five frames");
  Check(holdWidth>0&&peakWidth>holdWidth*2.4f,"binding rendered release expands over 2.4x its held width");
 }
 Check(error==null,name+" no runtime exceptions");if(expected>=0)Check(hits-before==expected,name+" contacts="+(hits-before));
 }
 IEnumerator Start(){output=Path.GetFullPath("../output/all-spells-polish-20260921");foreach(var arg in Environment.GetCommandLineArgs())if(arg.StartsWith("--tier-output="))output=Path.GetFullPath(arg.Substring(14));Directory.CreateDirectory(output);safety=Array.Exists(Environment.GetCommandLineArgs(),x=>x=="--tier-safety");foreach(var arg in Environment.GetCommandLineArgs())if(arg.StartsWith("--tier-only="))filter=arg.Substring(12);Application.logMessageReceived+=Observe;Time.captureFramerate=30;if(safety)Time.timeScale=filter!=null&&filter.Contains("bounty-b02")?1:4;yield return new WaitForSeconds(3);bridge=FindFirstObjectByType<UnityBattleBridge>();battle=FindFirstObjectByType<BattlePrototype>();
 yield return Setup("wave-instances:clock-guard-primary@archivist");
 yield return Clip("hero-basic","basic:clock-guard-primary",2);
 foreach(string n in new[]{"01","02","04","05","06","07","08","09","10"}){yield return Clip("hero-"+n,"skill:fool_skill_"+n+":clock-guard-primary",3.4f);Send("combat-stop");yield return null;Send("combat-start");}
 // Two target sidestep uses production target list.
 yield return Setup("wave-instances:clock-guard-primary@archivist,clock-guard-secondary@archivist");Send("skill-targets:clock-guard-primary|clock-guard-secondary");yield return Clip("hero-01-dual","skill:fool_skill_01:clock-guard-primary",3.4f,1);
 yield return Setup("wave-instances:clock-guard-primary@archivist,clock-guard-secondary@archivist,clock-guard-third@archivist,clock-guard-fourth@archivist");Send("skill-targets:clock-guard-primary|clock-guard-secondary|clock-guard-third|clock-guard-fourth");yield return Clip("hero-10-all-four","skill:fool_skill_10:clock-guard-primary",3.4f);
 yield return Clip("manual-mask","masquerade:2",.8f,0);yield return Clip("manual-mask-hit","masquerade-hit:1",.8f,0);yield return Clip("manual-mask-break","masquerade-hit:0",1,0);
 foreach(string skin in new[]{"default","archivist","matriarch","scribe","rescue","executor","adjudicator","convoy","chronarch","fog-ghost","crimson-ghost"}){
 yield return Setup("wave-instances:clock-guard-primary"+(skin=="default"?"":"@"+skin));
 for(int v=1;v<=2;v++)yield return Clip("enemy-"+skin+"-"+v,"enemy:clock-guard-primary",4);
 }
 yield return Setup("wave-instances:clock-guard-primary@fog-ghost,clock-guard-secondary@crimson-ghost");yield return Clip("ghost-wisp-secondary","enemy:clock-guard-secondary",4);
 yield return Setup("wave-instances:memory-leech-primary");yield return Clip("leech-charge","leech-charge:charge",1,0);yield return Clip("enemy-leech","enemy:memory-leech-primary",5);
 yield return Setup("wave-instances:clock-core-primary,clock-guard-primary");yield return Clip("core-memory-strike","enemy:clock-core-primary",2);yield return Clip("core-repair","enemy:clock-core-primary:repair_guard:clock-guard-primary",3);yield return Clip("guard-heal","enemy-heal:clock-guard-primary",1,0);
 yield return Setup("wave-instances:clock-guard-primary@archivist");yield return Clip("archive-shield","archive-state:guard",5,0);Send("archive-state:recover");
 yield return Setup("wave-instances:hell-hound-primary@early-hell-hound");Send("early-presence:3");yield return Clip("early-hound","enemy:hell-hound-primary",4);
 Send("early-presence:4");yield return Clip("q4-charge","q4-hound:charge",2,0);foreach(string shot in new[]{"probe","first","second"}){Send("q4-hound:"+shot);yield return Clip("q4-"+shot,"enemy:hell-hound-primary",4);}
 yield return Setup("wave-instances:hell-hound-primary");for(int v=1;v<=2;v++)yield return Clip("armored-hound-"+v,"enemy:hell-hound-primary",4);
 yield return Setup("chapter-thirty:19");yield return Clip("emerald-poison-field","emerald-poison:3",2,0);yield return Clip("emerald-charge","encore-charge",1.4f,0);yield return Clip("encore-bell","encore-bell",1,0);Send("emerald-spell:burst");yield return Clip("emerald-burst","enemy:hell-hound-primary",4);
 string[] rows={"saltmaw|tower_poison|tower_salt_spike","shellback|tower_mend|tower_short_pounce","ironclaw|tower_cut_first|tower_cut_second|tower_heavy_cut","frilled-naga|tower_empower|tower_sound_arrow","boneclaw|tower_piercing_claw|tower_tail_sweep|tower_heavy_claw","stonehide|guard|archive_slam","bounty-b01|ambush","bounty-b02|bind","bounty-b03|heavy_strike","bounty-b04|overwrite","bounty-b05|silk_bind","bounty-b06|guard|heavy_strike"};
 foreach(string row in rows){var r=row.Split('|');bool bounty=r[0].StartsWith("bounty");yield return Setup((bounty?"wave-instances:":"church-tower:")+"clock-guard-primary@"+r[0]+(bounty?"":",clock-guard-secondary@stonehide"));
 if(!bounty&&r[0]!="stonehide"){string prep=r[0]=="saltmaw"?"tower_sac_charge":r[0]=="shellback"?"tower_mend_charge":r[0]=="ironclaw"?"tower_blade_charge":r[0]=="frilled-naga"?"tower_crown_charge":"tower_claw_charge";yield return Clip(r[0]+"-charge","enemy:clock-guard-primary:"+prep,.8f,0);}
 for(int i=1;i<r.Length;i++){bool support=r[i]=="tower_mend"||r[i]=="tower_empower";yield return Clip(r[0]+"-"+r[i],"enemy:clock-guard-primary:"+r[i]+(support?":clock-guard-secondary":""),2,r[i]=="guard"?0:1);}
 }
 yield return Setup("wave-instances:clock-guard-primary@bounty-b02");yield return Clip("bounty-bindings-state","church-status:bindings:clock-guard-primary",5f,0);
 yield return Setup("wave-instances:clock-guard-primary@ghost");yield return Clip("bounty-escort-state","church-status:escorted:clock-guard-primary",1.3f,0);yield return Clip("bounty-escort-attack","enemy:clock-guard-primary",3);
 yield return Setup("church-tower:clock-guard-primary@frilled-naga,clock-guard-secondary@stonehide");Send("church-status:empowered:clock-guard-secondary");yield return Clip("tower-persistent-status","church-status:poison:1",1.5f,0);Send("combat-stop");yield return null;Check(FindObjectsByType<ChurchSpellVisual20260917>(FindObjectsSortMode.None).Length==0,"church status stop cleanup");
 Check(BindingEffekseerAccent20260921.ActiveHandles==0,"binding Effekseer handles zero after stop");
 File.WriteAllLines(output+(safety?"/safety-passed.txt":filter!=null?"/polish-passed.txt":"/passed.txt"),report);EditorApplication.isPlaying=false;
 }
 void LateUpdate(){if(capture==null)return;var path=capture;capture=null;var cam=Camera.main;var old=cam.targetTexture;var active=RenderTexture.active;float aspect=cam.aspect;var rt=new RenderTexture(540,960,24);var image=new Texture2D(540,960,TextureFormat.RGB24,false);try{cam.aspect=540f/960;typeof(BattlePrototype).GetMethod("FitRuntimeBackground",System.Reflection.BindingFlags.Instance|System.Reflection.BindingFlags.NonPublic).Invoke(battle,new object[]{cam});cam.targetTexture=rt;cam.Render();RenderTexture.active=rt;image.ReadPixels(new Rect(0,0,540,960),0,0);image.Apply();File.WriteAllBytes(path,image.EncodeToPNG());}finally{cam.targetTexture=old;cam.aspect=aspect;RenderTexture.active=active;Destroy(rt);Destroy(image);}}
 void OnDestroy(){Application.logMessageReceived-=Observe;}
}
