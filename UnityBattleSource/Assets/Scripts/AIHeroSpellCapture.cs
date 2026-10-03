#if UNITY_EDITOR || UNITY_STANDALONE
using System;
using System.Collections;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using UnityEngine;

// Probe the real spell entry alongside the illustrated body; no phone save access.
public sealed class AIHeroSpellCapture : MonoBehaviour {
    string output,error; int contacts,completions; float contactAt,begin;
    readonly List<string> report=new List<string>();
    [RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.AfterSceneLoad)]
    static void Boot() {
        if(Environment.GetCommandLineArgs().Contains("--verify-ai-hero-spells"))
            new GameObject("AI hero full spell verification").AddComponent<AIHeroSpellCapture>();
    }
    void Observe(string message,string stack,LogType type) {
        if(type==LogType.Exception || type==LogType.Assert || type==LogType.Error) error=message;
        if(message.Contains("\"eventName\":\"combat-contact\",\"value\":\"player\"")) {contacts++;contactAt=Time.time-begin;}
        if(message.Contains("\"eventName\":\"presentation-complete\"")) completions++;
    }
    IEnumerator Start() {
        output=Environment.GetEnvironmentVariable("MISTPORT_AI_HERO_CAPTURE");
        if(string.IsNullOrEmpty(output)) {Application.Quit(2);yield break;}
        Directory.CreateDirectory(output);Application.logMessageReceived+=Observe;AudioListener.volume=0;
        Screen.SetResolution(720,1080,false);yield return new WaitForSeconds(2);
        var battle=FindFirstObjectByType<BattlePrototype>();battle.SetNativeCombatEnabled(true);
        battle.RequestWaveInstances("clock-guard-primary@stonehide");yield return new WaitForSeconds(.5f);
        battle.SetTempoSample("church_tower_001");yield return new WaitForSeconds(.4f);
        var presentation=CombatTempoPresentation.Get(battle);
        var body=battle.TempoSamplePlayer.GetComponentInChildren<AIHeroAnimatedBody>();
        if(!body) {Fail("Missing illustrated hero");yield break;}
        foreach(var outfit in new[]{"mistport-night","starlight-magician","midnight-carnival"}) {
            presentation.SetOutfit(outfit);
            foreach(int speed in new[]{1,2}) {
                battle.SetCombatSpeed(speed.ToString());
                foreach(var skill in new[]{"basic","fool_skill_01","fool_skill_02","fool_skill_04","fool_skill_05","fool_skill_06","fool_skill_07","fool_skill_08","fool_skill_09","fool_skill_10"}) {
                    int bursts=SpellSpectacle20260926.ContactBursts;contacts=0;completions=0;begin=Time.time;
                    float expected=skill=="basic"?.58f:FoolSkillChoreography.ExpectedContact(skill);
                    if(skill=="basic")battle.PresentPlayerBasic("clock-guard-primary");
                    else battle.PresentPlayerSkill(skill+":clock-guard-primary");
                    yield return null;
                    if(body.CurrentAction!=AIHeroAnimatedBody.ActionFor(skill)) {Fail("Wrong body "+skill);yield break;}
                    yield return new WaitForSeconds(expected+.10f);
                    if(skill=="fool_skill_06" && FindObjectsByType<MeshRenderer>(FindObjectsSortMode.None).Count(r=>r.name=="Illustrated costume echo" && r.enabled && r.sharedMaterial.GetColor("_Color").a>.01f)!=2) {
                        Fail("Missing two visible illustrated pursuit copies");yield break;
                    }
                    yield return new WaitForEndOfFrame();Shot(outfit+"-"+skill+"-x"+speed+".png");
                    yield return new WaitForSeconds(2.5f);
                    if(contacts!=1 || completions!=1 || SpellSpectacle20260926.ContactBursts-bursts!=1 || Mathf.Abs(contactAt-expected)>.10f || error!=null) {
                        Fail(outfit+" "+skill+" x"+speed+" receipts="+contacts+"/"+completions+" bursts="+(SpellSpectacle20260926.ContactBursts-bursts)+" contact="+contactAt+" expected="+expected+" error="+error);yield break;
                    }
                    report.Add(outfit+" "+skill+" x"+speed+": original full VFX, one contact, one completion, one spectacle burst; contact="+contactAt.ToString("F3"));
                }
            }
        }
        battle.SetCombatSpeed("1");
        battle.SetMasquerade(3,false);yield return new WaitForSeconds(.4f);
        if(!FindObjectsByType<MeshRenderer>(FindObjectsSortMode.None).Any(r=>r.name=="Illustrated costume echo" && r.enabled && r.sharedMaterial.GetColor("_Color").a>.01f)) {Fail("Missing illustrated manual mask guard");yield break;}
        yield return new WaitForEndOfFrame();Shot("manual-mask-illustrated.png");battle.SetMasquerade(0,false);
        var frozen=body.CreateEcho(transform,body.transform.position,Color.cyan);
        var texture=frozen.Material.GetTexture("_MainTex");presentation.SetOutfit("mistport-night");yield return null;
        if(!texture || frozen.Material.GetTexture("_MainTex")!=texture) {Fail("Outfit unloaded frozen echo frame");yield break;}
        frozen.Dispose();report.Add("Manual guard uses visible illustrated silhouette; frozen pursuit retains sampled outfit textures.");
        contacts=0;completions=0;battle.PresentPlayerSkill("fool_skill_07:clock-guard-primary");yield return new WaitForSeconds(.12f);
        battle.SetNativeCombatEnabled(false);battle.SetTempoSample("off");yield return new WaitForSeconds(2);
        if(contacts!=0 || completions!=0 || SpellSpectacle20260926.LiveEffects!=0 || battle.TempoSamplePlayer.GetComponentInChildren<AIHeroAnimatedBody>() || error!=null) {
            Fail("Exit failed to cancel spell/echo/body: "+error);yield break;
        }
        report.Add("Production exit before contact cancels original full spell callbacks and clears spectacle/illustrated body.");
        File.WriteAllLines(Path.Combine(output,"passed.txt"),report);Application.Quit(0);
    }
    void Shot(string file) {var image=ScreenCapture.CaptureScreenshotAsTexture();File.WriteAllBytes(Path.Combine(output,file),image.EncodeToPNG());Destroy(image);}
    void Fail(string message) {File.WriteAllText(Path.Combine(output,"failed.txt"),message);Debug.LogError(message);Application.Quit(2);}
}
#endif
