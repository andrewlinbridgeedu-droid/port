#if UNITY_EDITOR || UNITY_STANDALONE
using System;
using System.Collections;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using UnityEngine;

// Runs production contact callbacks, then a fixture's settled-positive-damage
// notification. This is presentation integration, not the Swift damage engine.
public sealed class EnemyImpactCapture : MonoBehaviour
{
    BattlePrototype battle; UnityBattleBridge bridge;
    string output, skill, targets, error; int contacts, completions, enemyContacts; bool listen;
    readonly List<string> report = new List<string>();
    [RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.AfterSceneLoad)]
    static void Boot() { if(Environment.GetCommandLineArgs().Contains("--verify-enemy-impact")) new GameObject("Enemy impact verification").AddComponent<EnemyImpactCapture>(); }
    void Observe(string message,string stack,LogType type) {
        if(type==LogType.Exception || type==LogType.Assert) error=message;
        if(message.Contains("\"eventName\":\"combat-contact\",\"value\":\"enemy:")) enemyContacts++;
        if(!listen) return;
        if(message.Contains("\"eventName\":\"combat-contact\",\"value\":\"player\"")) {
            contacts++;
            if(!string.IsNullOrEmpty(targets)) Send("enemy-impact:"+skill+":"+targets);
        }
        if(message.Contains("\"eventName\":\"presentation-complete\"")) completions++;
    }
    void Send(string action) { bridge.ApplyCommand("{\"action\":\""+action+"\"}"); }
    Component Feedback(EnemyHandle h) { return h.GetComponent("EnemyImpactFeedback"); }
    int Count(EnemyHandle h) { var c=Feedback(h); return c==null?0:Convert.ToInt32(c.GetType().GetProperty("PlayCount").GetValue(c)); }
    bool Playing(EnemyHandle h) { var c=Feedback(h); return c!=null && (bool)c.GetType().GetProperty("IsPlaying").GetValue(c); }
    EnemyHandle[] Actors() { return FindObjectsByType<EnemyHandle>(FindObjectsSortMode.None).Where(h=>battle.BelongsToCurrentEncounter(h)&&h.gameObject.activeInHierarchy&&h.GetComponentsInChildren<Renderer>().Any(r=>r.enabled)).ToArray(); }
    IEnumerator Start() {
        output=Environment.GetEnvironmentVariable("MISTPORT_IMPACT_CAPTURE")??"/tmp/mistport-enemy-impact";
        Directory.CreateDirectory(output); File.Delete(Path.Combine(output,"passed.txt")); File.Delete(Path.Combine(output,"failed.txt"));
        Application.logMessageReceived+=Observe; Screen.SetResolution(720,1024,false);
        yield return new WaitForSeconds(2); Time.captureFramerate=60;
        battle=FindFirstObjectByType<BattlePrototype>(); bridge=FindFirstObjectByType<UnityBattleBridge>();
        battle.SetNativeCombatEnabled(false); battle.UseClockGuardModel(); yield return new WaitForSeconds(.4f);
        var skillFilter=Environment.GetCommandLineArgs().FirstOrDefault(a=>a.StartsWith("--impact-skills="));
        foreach(var s in (skillFilter!=null?skillFilter.Substring("--impact-skills=".Length).Split(','):new[]{"basic","fool_skill_01","fool_skill_02","fool_skill_04","fool_skill_05","fool_skill_06","fool_skill_07","fool_skill_08","fool_skill_09","fool_skill_10"})) {
            yield return Exercise("skills/"+s,s,new[]{Actors().First()},s!="fool_skill_09"); if(error!=null) { Fail(error); yield break; }
        }
        foreach(var model in new[]{"ghost","early-hound","armored-hound","emerald","core","leech","archivist","matriarch"}) {
            battle.SetNativeCombatEnabled(false); bridge.ResetEnemyExitPresentation(); battle.SetEncoreRevenant(false);
            switch(model) {
                case "ghost":battle.UseDualClockGuardModel();break;
                case "early-hound":battle.UseEarlyHellHoundModel();break;
                case "armored-hound":battle.UseHellHoundModel();break;
                case "emerald":battle.UseHellHoundModel();battle.SetEncoreRevenant(true);break;
                case "core":battle.UseClockCoreModel();break;
                case "leech":battle.UseP1Escort(true);break;
                case "archivist":battle.ConfigureWaveInstances("clock-guard-primary@archivist");break;
                case "matriarch":battle.ConfigureWaveInstances("clock-guard-primary@matriarch");break;
            }
            yield return new WaitForSeconds(.5f);
            var actor=Actors().FirstOrDefault(h=>model=="core"?h.BattleEnemyId==EnemyBattleIds.ClockCorePrimary:model=="leech"?h.GetComponentInChildren<MemoryLeechPresentation>()!=null:true);
            if(!actor) { Fail("Missing "+model); yield break; }
            yield return Exercise("models/"+model,"basic",new[]{actor},true); if(error!=null) { Fail(error); yield break; }
        }
        battle.SetNativeCombatEnabled(false); battle.SetEncoreRevenant(false); battle.UseDualClockGuardModel();
        bridge.SetEnemyVisibility("clock-guard-primary=hidden;clock-guard-secondary=hidden"); yield return new WaitForSeconds(1.2f);
        bridge.SetEnemyVisibility("clock-guard-instance-3=visible;clock-guard-instance-4=visible;clock-guard-instance-5=visible;clock-guard-instance-6=visible"); yield return new WaitForSeconds(.4f);
        var four=Actors(); if(four.Length!=4) { Fail("Split actor count "+four.Length); yield break; }
        battle.SetSidestepSecondary(four[2].BattleEnemyId);
        yield return Exercise("split/dual","fool_skill_01",new[]{four[0],four[2]},true); if(error!=null) { Fail(error); yield break; }
        battle.SetSidestepSecondary(""); yield return Exercise("split/single","fool_skill_01",new[]{four[1]},true); if(error!=null) { Fail(error); yield break; }
        // Incoming cast runs concurrently; feedback must not cancel its impact callback.
        battle.SetNativeCombatEnabled(true); skill="fool_skill_07";targets=four[0].BattleEnemyId;listen=true;
        int beforeEnemy=enemyContacts;
        battle.PresentEnemyAttack(four[0].BattleEnemyId); yield return new WaitForSeconds(.15f);
        Send("enemy-impact:"+skill+":"+targets); yield return new WaitForSeconds(4);
        if(enemyContacts!=beforeEnemy+1) { Fail("Concurrent reaction swallowed/duplicated enemy contact "+(enemyContacts-beforeEnemy)); yield break; }
        report.Add("Enemy cast survives overlapping impact: exactly one real enemy contact.");
        Send("enemy-impact:"+skill+":"+targets); yield return new WaitForSeconds(.06f);
        bridge.SetEnemyVisibility(four[0].BattleEnemyId+"=hidden"); yield return new WaitForSeconds(1.3f);
        if(Playing(four[0])) { Fail("Death retained impact"); yield break; }
        bridge.SetEnemyVisibility(four[0].BattleEnemyId+"=visible"); yield return new WaitForSeconds(.1f);
        Send("enemy-impact:"+skill+":"+targets); yield return new WaitForSeconds(.05f); battle.SetNativeCombatEnabled(false); yield return null;
        if(Actors().Any(Playing)) { Fail("Combat stop retained impact"); yield break; }
        report.Add("Death/hide and combat stop clear active impact; retry visible actor restored.");
        report.Add("Scope: actual Unity contact callbacks + fixture positive-damage notifications; Swift/native integration is independently tested, not claimed here.");
        File.WriteAllLines(Path.Combine(output,"passed.txt"),report); Application.Quit(0);
    }
    IEnumerator Exercise(string folder,string id,EnemyHandle[] hit,bool damage) {
        battle.SetNativeCombatEnabled(true); yield return null;
        var all=Actors(); var before=all.ToDictionary(h=>h.GetInstanceID(),Count);
        skill=id;targets=damage?string.Join(",",hit.Select(h=>h.BattleEnemyId)):null;contacts=0;completions=0;listen=true;
        float start=Time.time; int frame=0; bool observed=false;
        if(id=="basic") battle.PresentPlayerBasic(hit[0].BattleEnemyId); else battle.PresentPlayerSkill(id+":"+hit[0].BattleEnemyId);
        while(Time.time-start<3.2f) {
            yield return new WaitForEndOfFrame();
            if(hit.Any(Playing)) observed=true;
            if(frame%3==0 && Time.time-start<2.2f) Shot(folder,frame/3);
            frame++; yield return null;
        }
        listen=false;
        if(contacts!=1 || id!="basic"&&completions!=1) {error=id+" callbacks contacts="+contacts+" completes="+completions;yield break;}
        foreach(var h in all) {
            int expected=damage&&hit.Contains(h)?1:0;
            if(Count(h)-before[h.GetInstanceID()]!=expected) {error=id+" wrong target feedback "+h.BattleEnemyId;yield break;}
        }
        foreach(var h in hit) { var c=Feedback(h); if(c!=null) report.Add(folder+" "+h.BattleEnemyId+" joints="+c.GetType().GetProperty("MappedJointCount").GetValue(c)); }
        if(damage&&!observed) {error=id+" no active impact observed";yield break;}
        if(all.Any(Playing)) {error=id+" feedback not restored";yield break;}
        report.Add(folder+": contact=1; damage recipients="+(targets??"none")+"; exactly-once target feedback and recovery passed.");
        File.WriteAllLines(Path.Combine(output,"progress.txt"),report);
    }
    void Shot(string folder,int frame) {var path=Path.Combine(output,folder);Directory.CreateDirectory(path);File.AppendAllText(Path.Combine(path,"timestamps.csv"),frame+","+Time.time.ToString("F6",System.Globalization.CultureInfo.InvariantCulture)+"\n");var t=ScreenCapture.CaptureScreenshotAsTexture();File.WriteAllBytes(Path.Combine(path,$"frame-{frame:D3}.png"),t.EncodeToPNG());Destroy(t);}
    void Fail(string why) {File.WriteAllLines(Path.Combine(output,"failed.txt"),report.Concat(new[]{why}));Debug.LogError("ENEMY_IMPACT_FAILED "+why);Application.Quit(1);}
    void OnDestroy() {Application.logMessageReceived-=Observe;Time.captureFramerate=0;}
}
#endif
