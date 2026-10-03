#if UNITY_EDITOR || UNITY_STANDALONE
using System;
using System.Collections;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using UnityEngine;

// Runtime evidence from the real scene/command path; never claims phone approval.
public sealed class AIHeroCapture : MonoBehaviour {
    string output,error; int contacts,completions; readonly List<string> report=new List<string>();
    [RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.AfterSceneLoad)]
    static void Boot() {
        if(Environment.GetCommandLineArgs().Contains("--verify-ai-hero")) new GameObject("AI hero runtime verification").AddComponent<AIHeroCapture>();
    }
    void Observe(string message,string stack,LogType type) {
        if(type==LogType.Exception || type==LogType.Assert || message.Contains("AI_HERO_")) error=message;
        if(message.Contains("\"eventName\":\"combat-contact\",\"value\":\"player\"")) contacts++;
        if(message.Contains("\"eventName\":\"presentation-complete\"")) completions++;
    }
    IEnumerator Start() {
        output=Environment.GetEnvironmentVariable("MISTPORT_AI_HERO_CAPTURE");
        if(string.IsNullOrEmpty(output)) {Application.Quit(2);yield break;}
        Directory.CreateDirectory(output); Application.logMessageReceived+=Observe;
        AudioListener.volume=0; // Automated desktop probe must not leave background game audio playing.
        Screen.SetResolution(720,1080,false);yield return new WaitForSeconds(2);
        var battle=FindFirstObjectByType<BattlePrototype>();battle.SetNativeCombatEnabled(true);
        battle.RequestWaveInstances("clock-guard-primary@stonehide");yield return new WaitForSeconds(.5f);
        battle.SetTempoSample("church_tower_001");yield return new WaitForSeconds(.4f);
        var presentation=CombatTempoPresentation.Get(battle);
        var body=battle.TempoSamplePlayer.GetComponentInChildren<AIHeroAnimatedBody>();
        if(!body || !body.Surface.enabled || error!=null) {Fail("AI plane not installed: "+error);yield break;}
        var camera=Camera.main;var originalPos=camera.transform.position;var originalRot=camera.transform.rotation;var originalFov=camera.fieldOfView;
        foreach(var outfit in new[]{"mistport-night","starlight-magician","midnight-carnival"}) {
            presentation.SetOutfit(outfit);yield return null;
            if(body.Outfit!=outfit || body.LoadedAtlasCount!=5 || camera.transform.position!=originalPos || camera.transform.rotation!=originalRot) {Fail("Outfit/atlas count/camera mismatch");yield break;}
            yield return new WaitForEndOfFrame();Shot(outfit+"-production.png");
        }
        report.Add("Three native outfit IDs, five atlases each; production camera unchanged.");
        // Labelled close inspection of the actual runtime plane against the actual arena.
        var bounds=body.Surface.bounds;var center=body.transform.position+Vector3.up*bounds.size.y*.42f;
        var rear=camera.transform.position-center;rear.y=0;rear.Normalize();
        camera.transform.position=center+rear*bounds.size.y*1.9f;
        camera.transform.rotation=Quaternion.LookRotation(center-camera.transform.position);camera.fieldOfView=45;
        Time.captureFramerate=30;
        foreach(var outfit in new[]{"mistport-night","starlight-magician","midnight-carnival"}) {
            presentation.SetOutfit(outfit);yield return null;
            foreach(var action in AIHeroAnimatedBody.Actions) {
                var dir=outfit+"-"+action;Directory.CreateDirectory(Path.Combine(output,dir));
                body.PlayAction(action,.7f);
                for(int i=0;i<48;i++) {yield return new WaitForEndOfFrame();Shot(dir+"/"+i.ToString("D4")+".png");}
                if(body.IsActing || error!=null) {Fail("Unsettled/error "+action+" "+error);yield break;}
                report.Add(outfit+"/"+action+": rendered 48 runtime frames; returned to rest.");
            }
        }
        Time.captureFramerate=0;camera.transform.position=originalPos;camera.transform.rotation=originalRot;camera.fieldOfView=originalFov;
        // Production rules still own exactly one contact/completion; visuals own none.
        foreach(var outfit in new[]{"mistport-night","starlight-magician","midnight-carnival"}) {
            presentation.SetOutfit(outfit);
            foreach(int speed in new[]{1,2}) {
                battle.SetCombatSpeed(speed.ToString());
                foreach(var skill in new[]{"basic","fool_skill_01","fool_skill_02","fool_skill_04","fool_skill_05","fool_skill_06","fool_skill_07"}) {
                    contacts=0;completions=0;
                    if(skill=="basic") battle.PresentPlayerBasic("clock-guard-primary");
                    else battle.PresentPlayerSkill(skill+":clock-guard-primary");
                    yield return null;
                    if(body.CurrentAction!=AIHeroAnimatedBody.ActionFor(skill)) {Fail("Wrong animation mapping "+skill+" "+body.CurrentAction);yield break;}
                    yield return new WaitForSeconds(2.5f);
                    if(contacts!=1 || completions!=1 || error!=null) {Fail("Callbacks "+outfit+" "+skill+" x"+speed+" = "+contacts+"/"+completions+" "+error);yield break;}
                    report.Add(outfit+" "+skill+" x"+speed+": one contact, one completion.");
                }
            }
        }
        battle.SetCombatSpeed("1");contacts=0;
        battle.PresentPlayerSkill("fool_skill_07:clock-guard-primary");yield return new WaitForSeconds(.12f);
        float age=body.ActionAge;string active=body.CurrentAction;
        presentation.SetOutfit("starlight-magician");
        if(body.ActionAge!=age || body.CurrentAction!=active) {Fail("Wardrobe restarted action");yield break;}
        battle.SetNativeCombatEnabled(false);battle.SetTempoSample("off");yield return new WaitForSeconds(1.2f);
        if(contacts!=0 || battle.TempoSamplePlayer.GetComponentInChildren<AIHeroAnimatedBody>()) {Fail("Exit left delayed callback or AI plane");yield break;}
        report.Add("Mid-cast outfit switch preserves clock; exiting before impact cancels receipt and removes plane.");
        // Unity destroys the previous actor at end of frame. Its texture bank
        // must not unload the textures acquired by the immediately following actor.
        battle.SetNativeCombatEnabled(true);battle.SetTempoSample("chapter01_q04_encounter");
        battle.SetTempoSample("church_bounty_b01");yield return null;
        var switched=battle.TempoSamplePlayer.GetComponentInChildren<AIHeroAnimatedBody>();
        if(!switched || !switched.Surface.sharedMaterial.GetTexture("_MainTex")) {Fail("Same-frame sample transition unloaded active atlas");yield break;}
        switched.PlayAction(AIHeroAnimatedBody.Actions[2],.7f);yield return new WaitForSeconds(.1f);
        float pausedAge=switched.ActionAge;Time.timeScale=0;yield return new WaitForSecondsRealtime(.15f);
        if(switched.ActionAge!=pausedAge) {Fail("Animation ran while battle was paused");yield break;}
        Time.timeScale=1;battle.SetTempoSample("off");yield return null;
        report.Add("Same-frame encounter replacement retains live textures; paused battle freezes animation clock.");
        foreach(var encounter in new[]{"chapter01_q04_encounter","church_bounty_b01","church_tower_001"}) {
            battle.SetTempoSample(encounter);yield return new WaitForSeconds(.1f);
            if(!battle.TempoSamplePlayer.GetComponentInChildren<AIHeroAnimatedBody>()) {Fail("Missing in "+encounter);yield break;}
            battle.SetTempoSample("off");yield return null;
        }
        battle.SetTempoSample("chapter01_q03_encounter");yield return null;
        if(battle.TempoSamplePlayer.GetComponentInChildren<AIHeroAnimatedBody>()) {Fail("AI leaked to non-sample Q3");yield break;}
        report.Add("AI enabled only in Q4/D01/B01; Q3 retains original hero. No phone or saved game touched.");
        File.WriteAllLines(Path.Combine(output,"passed.txt"),report);Application.Quit(0);
    }
    void Shot(string name) {var tex=ScreenCapture.CaptureScreenshotAsTexture();File.WriteAllBytes(Path.Combine(output,name),tex.EncodeToPNG());Destroy(tex);}
    void Fail(string message) {File.WriteAllText(Path.Combine(output,"failed.txt"),message);Debug.LogError(message);Application.Quit(2);}
}
#endif
