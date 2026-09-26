#if UNITY_EDITOR || UNITY_STANDALONE
using System;
using System.Collections;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using UnityEngine;

/// Exercises production model selection and visibility routes, never installs idle itself.
public sealed class EnemyIdleCapture : MonoBehaviour
{
    string directory;
    readonly List<string> report = new List<string>();
    BattlePrototype battle;
    UnityBattleBridge bridge;
    bool failed;
    [RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.AfterSceneLoad)]
    static void Boot()
    {
        if (Environment.GetCommandLineArgs().Contains("--verify-enemy-idle"))
            new GameObject("All enemy idle verification").AddComponent<EnemyIdleCapture>();
    }
    IEnumerator Start()
    {
        directory = Environment.GetEnvironmentVariable("MISTPORT_IDLE_CAPTURE") ?? "/tmp/mistport-enemy-idle";
        Directory.CreateDirectory(directory);
        File.Delete(Path.Combine(directory, "passed.txt")); File.Delete(Path.Combine(directory, "failed.txt"));
        Screen.SetResolution(720,1024,false);
        yield return new WaitForSeconds(2); Time.captureFramerate=30;
        battle=FindFirstObjectByType<BattlePrototype>(); bridge=FindFirstObjectByType<UnityBattleBridge>();
        string[] cases={"guard","ghost","red-ghosts","early-hound","armored-hound","emerald","core","leech","archivist","matriarch","scribe","rescue","mixed-clones"};
        var filter=Environment.GetCommandLineArgs().FirstOrDefault(a=>a.StartsWith("--idle-cases="));
        if(filter!=null) cases=filter.Substring("--idle-cases=".Length).Split(',');
        foreach(var name in cases)
        {
            bridge.ResetEnemyExitPresentation(); battle.SetNativeCombatEnabled(false); battle.SetEncoreRevenant(false);
            switch(name)
            {
                case "guard": battle.UseClockGuardModel(); break;
                case "ghost": case "red-ghosts": battle.UseDualClockGuardModel(); break;
                case "early-hound": battle.UseEarlyHellHoundModel(); break;
                case "armored-hound": battle.UseHellHoundModel(); break;
                case "emerald": battle.UseHellHoundModel(); battle.SetEncoreRevenant(true); break;
                case "core": battle.UseClockCoreModel(); break;
                case "leech": battle.UseP1Escort(true); break;
                case "archivist": battle.ConfigureWaveInstances("clock-guard-primary@archivist"); break;
                case "scribe":battle.ConfigureWaveInstances("clock-guard-primary@scribe");break;
                case "rescue":battle.ConfigureWaveInstances("clock-guard-primary@rescue");break;
                case "matriarch": battle.ConfigureWaveInstances("clock-guard-primary@matriarch"); break;
                case "mixed-clones": battle.ConfigureWaveInstances("clock-guard-instance-7@archivist,clock-guard-instance-8@matriarch,memory-leech-instance-9"); break;
            }
            battle.SetEarlyBattlePresence(name=="ghost"||name=="red-ghosts"?"2":name=="early-hound"?"4":name=="emerald"?"5":"15");
            if(name=="red-ghosts")
            {
                bridge.SetEnemyVisibility("clock-guard-primary=hidden;clock-guard-secondary=hidden");
                yield return new WaitForSeconds(1.3f);
                bridge.SetEnemyVisibility("clock-guard-instance-3=visible;clock-guard-instance-4=visible;clock-guard-instance-5=visible;clock-guard-instance-6=visible");
            }
            yield return new WaitForSeconds(.4f);
            var handles=FindObjectsByType<EnemyHandle>(FindObjectsSortMode.None).Where(h=>battle.BelongsToCurrentEncounter(h)&&h.GetComponentsInChildren<Renderer>().Any(r=>r.enabled)).ToArray();
            if(handles.Length==0 || name=="red-ghosts" && handles.Length!=4) { Fail(name+" missing actors "+handles.Length); yield break; }
            foreach(var h in handles)
            {
                var idle=h.GetComponent<EarlyEnemyIdlePresence>();
                if(!idle || !idle.IsConfigured || !idle.VisibleActor) { Fail(name+" missing production idle binding "+h.BattleEnemyId); yield break; }
                if(name=="emerald" && idle.Archetype!=EarlyEnemyIdlePresence.IdleArchetype.Revenant) { Fail("Emerald visible actor not bound as Revenant: "+idle.VisibleActor.name); yield break; }
                report.Add(name+" / "+h.BattleEnemyId+" visual="+idle.VisibleActor.name+" archetype="+idle.Archetype);
            }
            yield return Measure(name,"precombat",handles); if(failed) yield break;
            battle.SetNativeCombatEnabled(true);
            yield return Measure(name,"combat-rest",handles); if(failed) yield break;
            // Exercise a real attack, then its return to idle, followed by a real player hit.
            var target=(name=="leech"||name=="mixed-clones")?handles.First(h=>h.GetComponentInChildren<MemoryLeechPresentation>()):name=="core"?handles.First(h=>h.BattleEnemyId==EnemyBattleIds.ClockCorePrimary):handles.First();
            battle.PresentEnemyAttack(target.BattleEnemyId);
            yield return new WaitForSeconds(.3f); yield return new WaitForEndOfFrame(); Shot(name,"attack",0);
            yield return new WaitForSeconds(6);
            yield return Measure(name,"after-attack",handles); if(failed) yield break;
            battle.PresentPlayerBasic(target.BattleEnemyId);
            yield return new WaitForSeconds(.8f); yield return new WaitForEndOfFrame(); Shot(name,"hit",0);
            yield return new WaitForSeconds(2);
            yield return Measure(name,"after-hit",handles); if(failed) yield break;
            bridge.SetEnemyVisibility(target.BattleEnemyId+"=hidden");
            yield return new WaitForSeconds(.35f); yield return new WaitForEndOfFrame(); Shot(name,"death-cancel",0);
            bridge.SetEnemyVisibility(target.BattleEnemyId+"=visible");
            yield return new WaitForSeconds(.4f);
            yield return Measure(name,"after-cancel",new[]{target}); if(failed) yield break;
            bridge.SetEnemyVisibility(target.BattleEnemyId+"=hidden");
            yield return new WaitForSeconds(target.GetComponentInChildren<MemoryLeechPresentation>()?6:1.4f);
            if(target.gameObject.activeInHierarchy) { Fail(name+" death did not hide actor"); yield break; }
            bridge.SetEnemyVisibility(target.BattleEnemyId+"=visible");
            battle.SetNativeCombatEnabled(false);
            yield return new WaitForSeconds(.4f);
            yield return Measure(name,"after-retry",new[]{target}); if(failed) yield break;
            File.WriteAllLines(Path.Combine(directory,"progress.txt"),report);
        }
        battle.SetNativeCombatEnabled(false); bridge.ResetEnemyExitPresentation();
        battle.UseHellHoundModel(); battle.SetEncoreRevenant(true); yield return new WaitForSeconds(.4f);
        foreach(bool early in new[]{true,false}) {
            battle.SetEncoreRevenant(false);
            if(early) battle.UseEarlyHellHoundModel(); else battle.UseHellHoundModel();
            yield return new WaitForSeconds(.4f);
            var h=FindObjectsByType<EnemyHandle>(FindObjectsSortMode.None).First(x=>x.BattleEnemyId==EnemyBattleIds.HellHoundPrimary);
            var idle=h.GetComponent<EarlyEnemyIdlePresence>();
            if(!idle || !idle.IsAnimatingIdle || idle.Archetype!=EarlyEnemyIdlePresence.IdleArchetype.Hound) { Fail("Emerald to "+(early?"early":"armored")+" hound recycled wrong archetype"); yield break; }
            report.Add("Recycled Emerald to "+(early?"early":"armored")+" hound: Hound classification and idle active");
        }
        File.WriteAllLines(Path.Combine(directory,"passed.txt"),report);
        Debug.Log("ALL_ENEMY_IDLE_PASSED"); Application.Quit(0);
    }
    IEnumerator Measure(string name,string stage,EnemyHandle[] handles)
    {
        foreach(var h in handles) {
            var idle=h.GetComponent<EarlyEnemyIdlePresence>();
            if(!idle || !idle.IsAnimatingIdle) { Diagnose(h); Fail(name+" "+stage+" new idle layer not running "+h.BattleEnemyId); yield break; }
        }
        var roots=handles.Select(h=>h.EnemyRoot.position).ToArray();
        var skeletons=handles.Select(h=>h.GetComponent<EarlyEnemyIdlePresence>().VisibleActor.GetComponentsInChildren<Transform>().Where(t=>t.gameObject.activeInHierarchy && !t.GetComponent<Renderer>()).ToArray()).ToArray();
        var rotations=skeletons.Select(s=>s.Select(t=>t.localRotation).ToArray()).ToArray();
        var positions=skeletons.Select(s=>s.Select(t=>t.localPosition).ToArray()).ToArray();
        if(name=="early-hound") {
            for(int a=0;a<handles.Length;a++) {
                report.Add(name+" "+stage+" roots enemy="+handles[a].EnemyRoot.position+" motion="+handles[a].MotionRoot.position);
                foreach(var t in skeletons[a].Where(t=>new[]{"frontleg2","R_frontleg2","backleg2","R_backleg2"}.Contains(t.name)||t.name.IndexOf("paw",StringComparison.OrdinalIgnoreCase)>=0)) report.Add("foot "+t.name+" world="+t.position);
            }
        }
        var maximum=skeletons.Select(s=>new float[s.Length]).ToArray();
        var meshes=handles.Select(h=>h.GetComponent<EarlyEnemyIdlePresence>().VisibleActor.GetComponentsInChildren<MeshFilter>().FirstOrDefault(m=>m.sharedMesh && m.sharedMesh.isReadable)).ToArray();
        var vertices=meshes.Select(m=>m?m.sharedMesh.vertices:null).ToArray();
        var vertexMotion=new float[handles.Length];
        for(int f=0;f<60;f++)
        {
            yield return new WaitForEndOfFrame();
            for(int a=0;a<handles.Length;a++)
            {
                if(Vector3.Distance(handles[a].EnemyRoot.position,roots[a])>.025f) { Fail(name+" "+stage+" formation drift "+handles[a].BattleEnemyId); yield break; }
                if(meshes[a] && vertices[a]!=null && handles[a].BattleEnemyId.StartsWith("clock-core-"))
                {
                    var current=meshes[a].sharedMesh.vertices;
                    for(int v=0;v<Mathf.Min(vertices[a].Length,current.Length);v++) vertexMotion[a]=Mathf.Max(vertexMotion[a],Vector3.Distance(vertices[a][v],current[v]));
                }
                for(int j=0;j<skeletons[a].Length;j++)
                    maximum[a][j]=Mathf.Max(maximum[a][j],Quaternion.Angle(rotations[a][j],skeletons[a][j].localRotation)+Vector3.Distance(positions[a][j],skeletons[a][j].localPosition)*100);
            }
            if(f%(Environment.GetCommandLineArgs().Contains("--idle-dense")?2:10)==0 && (stage=="precombat"||stage=="combat-rest")) Shot(name,stage,f/(Environment.GetCommandLineArgs().Contains("--idle-dense")?2:10));
            yield return null;
        }
        for(int a=0;a<handles.Length;a++)
        {
            var moving=Enumerable.Range(0,maximum[a].Length).Where(j=>maximum[a][j]>.15f).ToArray();
            if(moving.Length<2 && !(handles[a].BattleEnemyId.StartsWith("clock-core-") && vertexMotion[a]>.00005f)) { Fail(name+" "+stage+" insufficient articulated movement "+handles[a].BattleEnemyId+" count="+moving.Length); yield break; }
            report.Add(name+" "+stage+" "+handles[a].BattleEnemyId+" moving="+string.Join(",",moving.Select(j=>skeletons[a][j].name+":"+maximum[a][j].ToString("F2")))+"; vertex motion="+vertexMotion[a].ToString("F6")+"; formation fixed");
        }
    }
    void Diagnose(EnemyHandle h)
    {
        var idle=h.GetComponent<EarlyEnemyIdlePresence>();
        report.Add("DIAG "+h.BattleEnemyId+" configured="+(idle&&idle.IsConfigured)+" suspended="+(idle&&idle.IsSuspended)+" archetype="+(idle?idle.Archetype.ToString():"none")+" actor="+(idle&&idle.VisibleActor?idle.VisibleActor.name:"none")+" bones="+(idle?idle.MappedBoneCount:0));
        foreach(var a in h.GetComponentsInChildren<Animator>(true)) {
            var state=a.GetCurrentAnimatorStateInfo(0); var next=a.GetNextAnimatorStateInfo(0);
            report.Add("ANIM "+a.name+" enabled="+a.enabled+" active="+a.gameObject.activeInHierarchy+" ctrl="+(a.runtimeAnimatorController?a.runtimeAnimatorController.name:"none")+" state="+state.shortNameHash+" full="+state.fullPathHash+" next="+next.shortNameHash+" transition="+a.IsInTransition(0)+" norm="+state.normalizedTime);
        }
        foreach(var a in h.GetComponentsInChildren<Animation>(true)) report.Add("LEGACY "+a.name+" enabled="+a.enabled+" idle="+a.IsPlaying("Idle"));
        var signature=h.GetComponent<SignatureEnemyPresentation>(); report.Add("SIGNATURE casting="+(signature&&signature.IsCasting));
    }
    void Shot(string name,string stage,int frame)
    {
        var folder=Path.Combine(directory,name,stage); Directory.CreateDirectory(folder);
        File.AppendAllText(Path.Combine(folder,"timestamps.csv"),frame+","+Time.time.ToString("F6",System.Globalization.CultureInfo.InvariantCulture)+"\n");
        var texture=ScreenCapture.CaptureScreenshotAsTexture(); File.WriteAllBytes(Path.Combine(folder,$"frame-{frame:D3}.png"),texture.EncodeToPNG()); Destroy(texture);
    }
    void Fail(string message) { failed=true; File.WriteAllLines(Path.Combine(directory,"failed.txt"),report.Concat(new[]{message})); Debug.LogError("ALL_ENEMY_IDLE_FAILED "+message); Application.Quit(1); }
    void OnDestroy() { Time.captureFramerate=0; }
}
#endif
