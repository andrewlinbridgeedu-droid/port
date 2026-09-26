using System;
using System.Collections;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEngine;

public static class FormalRound2TargetReview20260922 {
 const string Key="FormalRound2TargetReview20260922";
 public static void Begin() { SessionState.SetBool(Key,true); EditorSceneManager.OpenScene("Assets/Scenes/BattlePrototype.unity"); EditorApplication.isPlaying=true; }
 [InitializeOnLoadMethod] static void Init() { EditorApplication.playModeStateChanged += s => {
  if(!SessionState.GetBool(Key,false))return;
  if(s==PlayModeStateChange.EnteredPlayMode)new GameObject(Key).AddComponent<FormalRound2TargetRunner20260922>();
  if(s==PlayModeStateChange.EnteredEditMode) { SessionState.SetBool(Key,false); EditorApplication.Exit(0); }
 }; }
}
public sealed class FormalRound2TargetRunner20260922 : MonoBehaviour {
 readonly List<string> checks=new(); string output; bool errors;
 void Check(bool yes,string text) { if(!yes) { File.WriteAllText(output+"/formal-failed.txt",text); Debug.LogError(text); EditorApplication.Exit(3); } checks.Add(text); }
 void Log(string text,string stack,LogType type) { if(type==LogType.Exception||type==LogType.Error)errors=true; }
 IEnumerator Start() {
  output=Path.GetFullPath("../output/whole-spell-round2-20260922/targets");Directory.CreateDirectory(output);Application.logMessageReceived+=Log;
  yield return new WaitForSeconds(3);
  var bridge=FindFirstObjectByType<UnityBattleBridge>();var battle=FindFirstObjectByType<BattlePrototype>();
  bridge.ApplyCommand("{\"action\":\"combat-stop\"}");
  bridge.ApplyCommand("{\"action\":\"church-tower:clock-guard-primary@stonehide,clock-guard-secondary@ironclaw,clock-guard-tertiary@boneclaw,clock-guard-fourth@stonehide\"}");
  yield return new WaitForSeconds(.3f);
  var targets=FindObjectsByType<EnemyHandle>(FindObjectsSortMode.None).Where(battle.BelongsToCurrentEncounter).OrderBy(h=>h.BattleEnemyId).ToArray();
  Check(targets.Length==4,"four distinct enemy handles available");
  var host=new GameObject("Formal instance verification host");var vfx=host.AddComponent<FoolEffekseerSkillVFX>();
  vfx.HeroActor=((GameObject)typeof(BattlePrototype).GetField("player",System.Reflection.BindingFlags.Instance|System.Reflection.BindingFlags.NonPublic).GetValue(battle)).transform;
  foreach(var skill in new[]{"fool_skill_01","fool_skill_10"})foreach(var n in (skill=="fool_skill_01"?new[]{1,2}:new[]{1,2,3,4})) {
   int contacts=0; bool complete=false;
   StartCoroutine(Run(vfx.PlayTargetInstances(skill,()=>new Vector3(0,1.2f,-3.8f),targets.Take(n).ToArray(),()=>contacts++),()=>complete=true));
   yield return new WaitForSeconds(.36f);
   var owners=host.transform.Cast<Transform>().Where(t=>t.name.StartsWith(skill+" target [")).ToArray();
   Check(owners.Length==n,skill+" "+n+" stable target owners");
   Check(owners.All(t=>t.GetComponentsInChildren<Renderer>().Length>0),skill+" "+n+" independently owned renderers");
   if(skill=="fool_skill_01")Check(owners.All(t=>t.GetComponentsInChildren<Transform>().Count(c=>c.name.StartsWith("Sidestep hero clone lane"))==2),skill+" "+n+" exactly two complete hero roots per target");
   while(!complete)yield return null;
   yield return null;
   Check(contacts==1,skill+" "+n+" one public contact");
   Check(host.transform.childCount==0,skill+" "+n+" complete cleanup");
  }
  foreach(var skill in new[]{"fool_skill_01","fool_skill_10"}) {
   int contacts=0;bool complete=false;
   StartCoroutine(Run(vfx.PlayTargetInstances(skill,()=>new Vector3(0,1.2f,-3.8f),targets.Take(2).ToArray(),()=>contacts++),()=>complete=true));
   yield return new WaitForSeconds(.25f);targets[0].gameObject.SetActive(false);yield return null;yield return null;
   var retired=host.transform.Cast<Transform>().First(t=>t.name.Contains(targets[0].BattleEnemyId));
   var survivor=host.transform.Cast<Transform>().First(t=>t.name.Contains(targets[1].BattleEnemyId));
   Check(!retired.GetComponentsInChildren<Renderer>().Any(r=>r.gameObject.activeInHierarchy),skill+" departing target clears only its visuals");
   Check(survivor.GetComponentsInChildren<Renderer>().Any(r=>r.gameObject.activeInHierarchy),skill+" surviving target continues");
   while(!complete)yield return null;
   Check(contacts==1,skill+" departure keeps one public contact");targets[0].gameObject.SetActive(true);
   contacts=0;complete=false;
   StartCoroutine(Run(vfx.PlayTargetInstances(skill,()=>Vector3.zero,targets.Take(2).ToArray(),()=>contacts++),()=>complete=true));
   yield return new WaitForSeconds(.1f);vfx.StopActiveEffects();yield return null;yield return null;
   Check(contacts==0 && host.transform.childCount==0,skill+" cancellation clears and suppresses late contact");
  }
  var trialHero=vfx.HeroActor;Destroy(host);yield return null;
  yield return TrialTargets(trialHero);
  Check(!errors,"no runtime exceptions or errors");File.WriteAllLines(output+"/formal-passed.txt",checks);Application.logMessageReceived-=Log;EditorApplication.isPlaying=false;
 }
 IEnumerator TrialTargets(Transform hero) {
  var receivers=Enumerable.Range(0,4).Select(i=>new GameObject("Trial diagnostic recipient "+i)).ToArray();
  for(int i=0;i<receivers.Length;i++)receivers[i].transform.position=new Vector3((i-1.5f)*2,0,3.7f);
  var wing=AssetDatabase.LoadAssetAtPath<GameObject>("Assets/VFX_Trials/Meshes/PhoenixWing.fbx").GetComponentInChildren<MeshFilter>().sharedMesh;
  foreach(TargetSpellTrial.Style style in Enum.GetValues(typeof(TargetSpellTrial.Style))) {
   string artName=style==TargetSpellTrial.Style.Phoenix?"PhoenixWing.png":style==TargetSpellTrial.Style.Rift?"GoldenRiftContinuous.png":"IceFlower.png";
   var art=AssetDatabase.LoadAssetAtPath<Texture2D>("Assets/VFX_Trials/Textures/"+artName);
   var obj=new GameObject("Round2 trial ownership "+style);var fx=obj.AddComponent<TargetSpellTrial>();
   Vector3[] firstThunder=null;
   for(int n=1;n<=4;n++) {
    fx.Build(style,new Vector3(0,0,-3),receivers.Take(n).Select(r=>r.transform).ToArray(),Enumerable.Range(0,n).Select(i=>"stable-"+i).ToArray(),art,wing);yield return null;
    Check(fx.LiveCount==n&&obj.transform.childCount==n,style+" "+n+" rebuild owns exactly requested target count");
    fx.Sample(-.25f);Check(!LiveRenderer(obj),style+" "+n+" negative sample has no visible effect");
    fx.Sample(.8f);Check(obj.transform.Cast<Transform>().All(t=>LiveRenderer(t.gameObject)),style+" "+n+" independent complete target visuals");
    var meshes=obj.GetComponentsInChildren<MeshFilter>(true).Where(m=>m.sharedMesh).Select(m=>m.sharedMesh).Distinct().ToDictionary(m=>m,m=>m.vertices);
    Check(meshes.Values.SelectMany(v=>v).All(Finite),style+" "+n+" mesh coordinates finite");
    if(style==TargetSpellTrial.Style.Thunder) {
     var bolts=obj.GetComponentsInChildren<IceThunderTrial>(true).Select(t=>t.GetComponentInChildren<MeshFilter>(true).sharedMesh.vertices).ToArray();
     if(firstThunder==null)firstThunder=bolts[0];
     Check(SameVertices(firstThunder,bolts[0]),style+" "+n+" stable identity keeps shape across target-count rebuilds");
     Check(!bolts.SelectMany((a,i)=>bolts.Skip(i+1).Select(b=>SameVertices(a,b))).Any(x=>x),style+" "+n+" distinct identities have distinct bolt geometry");
    }
    fx.Sample(2.5f);Check(!LiveRenderer(obj),style+" "+n+" tail empty at 2.5 seconds");
    fx.Sample(-.25f);fx.Sample(.8f);
    Check(meshes.All(p=>p.Key.vertices.Zip(p.Value,(a,b)=>(a-b).sqrMagnitude<.000001f).All(x=>x)),style+" "+n+" deterministic replay mesh");
   }
   var roots=obj.transform.Cast<Transform>().ToArray();var positions=roots.Select(t=>t.position).ToArray();
   receivers[0].transform.position+=Vector3.right*.4f;fx.Sample(.8f);
   Check(Vector3.Distance(roots[0].position,positions[0]+Vector3.right*.4f)<.001f&&roots.Skip(1).Select((t,i)=>Vector3.Distance(t.position,positions[i+1])<.001f).All(x=>x),style+" moved recipient affects only own instance");
   receivers[0].SetActive(false);fx.Sample(.8f);yield return null;
   Check(fx.LiveCount==3&&obj.transform.childCount==3,style+" departing fourth target leaves three survivors");
   receivers[0].SetActive(true);receivers[0].transform.position-=Vector3.right*.4f;
   obj.SetActive(false);yield return null;Check(fx.LiveCount==0&&obj.transform.childCount==0,style+" disable releases all instances");Destroy(obj);
   var bones=hero.GetComponentsInChildren<Transform>(true);var pos=bones.Select(t=>t.localPosition).ToArray();var rot=bones.Select(t=>t.localRotation).ToArray();
   var motion=new SpellContactTrial.CasterMotion(hero,(SpellContactTrial.CasterMotion.Style)Enum.Parse(typeof(SpellContactTrial.CasterMotion.Style),style.ToString()));
   Check(motion.MappedJointCount==11,style+" caster maps eleven joints once per cast");motion.Sample(.45f);motion.Dispose();
   Check(bones.Select((t,i)=>Vector3.Distance(t.localPosition,pos[i])<.00001f&&Quaternion.Angle(t.localRotation,rot[i])<.03f).All(x=>x),style+" caster disposal restores every local transform");
  }
  foreach(var receiver in receivers)Destroy(receiver);yield return null;
 }
 static bool LiveRenderer(GameObject obj)=>obj.GetComponentsInChildren<Renderer>(true).Any(r=>r.enabled&&r.gameObject.activeInHierarchy);
 static bool SameVertices(Vector3[] a,Vector3[] b)=>a.Length==b.Length&&a.Zip(b,(p,q)=>(p-q).sqrMagnitude<.000001f).All(x=>x);
 static bool Finite(Vector3 p)=>!float.IsNaN(p.x)&&!float.IsNaN(p.y)&&!float.IsNaN(p.z)&&!float.IsInfinity(p.x)&&!float.IsInfinity(p.y)&&!float.IsInfinity(p.z);
 IEnumerator Run(IEnumerator body,Action completed) { yield return body;completed(); }
}
