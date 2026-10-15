using System;
using System.Collections;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Reflection;
using System.Security.Cryptography;
using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEngine;

public static class WholeSpellRound2Review20260922
{
    const string Key="WholeSpellRound2Review20260922";
    public static void Begin(){SessionState.SetBool(Key,true);EditorSceneManager.OpenScene("Assets/Scenes/BattlePrototype.unity");EditorApplication.isPlaying=true;}
    [InitializeOnLoadMethod] static void Hook(){EditorApplication.playModeStateChanged+=s=>{
        if(!SessionState.GetBool(Key,false))return;
        if(s==PlayModeStateChange.EnteredPlayMode)new GameObject(Key).AddComponent<WholeSpellRound2Runner20260922>();
        if(s==PlayModeStateChange.EnteredEditMode){SessionState.SetBool(Key,false);EditorApplication.Exit(0);}
    };}
}

[DefaultExecutionOrder(31000)]
public sealed class WholeSpellRound2Runner20260922:MonoBehaviour
{
    [Serializable] public class Cue {public int frame;public string command;}
    [Serializable] public class Row {public string id,key,setup,actor,focus,attack,trial;public int frames,expected;public bool safety;public string[] warm;public Cue[] cues;}
    [Serializable] public class Plan {public Row[] rows;}
    sealed class Movie : IDisposable
    {
        readonly System.Diagnostics.Process process;
        readonly RenderTexture rt;
        readonly Texture2D texture;
        public Movie(string path,int width,int height){
            rt=new RenderTexture(width,height,24,RenderTextureFormat.ARGBHalf);
            texture=new Texture2D(width,height,TextureFormat.RGB24,false);
            var info=new System.Diagnostics.ProcessStartInfo {
                FileName="/tmp/mistport-vfx-encode/imageio_ffmpeg/binaries/ffmpeg-macos-aarch64-v7.1",
                Arguments="-y -loglevel error -f rawvideo -pixel_format rgb24 -video_size "+width+"x"+height+" -framerate 30 -i pipe:0 -vf vflip -an -c:v libx264 -preset veryfast -crf 16 -threads 2 -pix_fmt yuv420p -movflags +faststart \""+path+"\"",
                UseShellExecute=false,RedirectStandardInput=true,RedirectStandardError=true,CreateNoWindow=true
            };
            process=System.Diagnostics.Process.Start(info);
        }
        public void Frame(Camera camera){
            var old=camera.targetTexture;var active=RenderTexture.active;
            try{camera.targetTexture=rt;camera.Render();RenderTexture.active=rt;texture.ReadPixels(new Rect(0,0,rt.width,rt.height),0,0);texture.Apply();var bytes=texture.GetRawTextureData();process.StandardInput.BaseStream.Write(bytes,0,bytes.Length);}
            finally{camera.targetTexture=old;RenderTexture.active=active;}
        }
        public void Dispose(){
            process.StandardInput.Close();string error=process.StandardError.ReadToEnd();process.WaitForExit();
            int code=process.ExitCode;process.Dispose();Destroy(rt);Destroy(texture);
            if(code!=0)throw new Exception("Recording encoder exited "+code+": "+error);
        }
    }
    UnityBattleBridge bridge;BattlePrototype battle;Camera camera;GameObject player;
    EnemyHandle actor,closeActor;Movie full,close;Row current;string output,tag,error;bool pending,safety;
    bool playerImpactFixture,recordingFixture;string fixtureContext;int fixtureSequence,recordFrame,fixtureInitialCount;
    readonly List<string> fixtureEvidence=new List<string>{"key\tframe\tseconds\tsequence\thpLoss\tshieldLoss\tmaxHP\tboundary"};
    static readonly HashSet<string> PlayerDamageIDs=new HashSet<string>{"M03","M04","M15","M18","M21","M24","M25","M26","M27","M28","M29","M30","M31","N09B"};
    int hits,cancels;float maxLift,trialVisual,closeDistance=4.15f,maxGripError,maxHeroLift,maxHeroFootError,maxProjectionError;bool weaponMapped;Vector3 closeOffset;TargetSpellTrial trial;SpellContactTrial.CasterMotion trialPose;TrialBloom bloom;
    readonly List<string> checks=new List<string>();readonly List<string> completed=new List<string>();
    static readonly BindingFlags Private=BindingFlags.Instance|BindingFlags.NonPublic;
    void Send(string command){if(!string.IsNullOrEmpty(command))bridge.ApplyCommand("{\"action\":\""+command+"\"}");}
    void Log(string text,string stack,LogType kind){
        if(kind==LogType.Exception||kind==LogType.Assert||kind==LogType.Error)error=text;
        if(text.Contains("\"eventName\":\"combat-contact\"")&&!text.Contains("enemy-cancel:")){
            hits++;
            // Editor-only visual fixture: native battle supplies actual settled
            // HP/shield deltas. This recorder supplies a labelled fixed loss at
            // the original contact; it never calculates or commits damage.
            if(recordingFixture && text.Contains("\"value\":\"enemy:")){
                fixtureSequence++;
                Send("player-impact:"+fixtureContext+";"+fixtureSequence+";90;0;1000;0;0");
                fixtureEvidence.Add(current.key+"\t"+recordFrame+"\t"+(recordFrame/30f).ToString("F3",System.Globalization.CultureInfo.InvariantCulture)+"\t"+fixtureSequence+"\t90\t0\t1000\tUnity bridge visual fixture, not Swift battle");
                File.WriteAllLines(output+"/"+tag+"-player-impact-fixture.tsv",fixtureEvidence);
            }
        }
        if(text.Contains("\"eventName\":\"combat-contact\"")&&text.Contains("enemy-cancel:"))cancels++;
    }
    void Check(bool ok,string label){
        if(!ok){File.WriteAllText(output+"/"+tag+"-failed.txt",label+"\n"+error);Debug.LogError("ROUND2_FAIL "+label);EditorApplication.Exit(3);throw new Exception(label);}
        checks.Add(label);File.WriteAllLines(output+"/"+tag+"-progress.txt",checks);Debug.Log("ROUND2_PASS "+label);
    }
    IEnumerator Setup(Row row){
        Send("combat-stop");yield return null;yield return null;Send(row.setup);yield return new WaitForSeconds(.5f);Send("combat-start");
        actor=FindObjectsByType<EnemyHandle>(FindObjectsSortMode.None).FirstOrDefault(h=>battle.BelongsToCurrentEncounter(h)&&h.BattleEnemyId==row.actor&&h.gameObject.activeInHierarchy);
        Check(actor!=null,row.key+" current actor "+row.actor);
        foreach(string warm in row.warm??Array.Empty<string>()){
            if(warm.StartsWith("@advance-enemy:")){Send("enemy:"+warm.Substring(15));yield return new WaitForSeconds(4.6f);}
            else Send(warm);
        }
        yield return new WaitForSeconds(.15f);
        closeActor=actor;
        if(row.focus!="player"&&row.focus!="enemy"){
            closeActor=FindObjectsByType<EnemyHandle>(FindObjectsSortMode.None).FirstOrDefault(h=>battle.BelongsToCurrentEncounter(h)&&h.BattleEnemyId==row.focus&&h.gameObject.activeInHierarchy);
            Check(closeActor!=null,row.key+" recipient camera bound to "+row.focus);
        }
        closeOffset=Vector3.up*1.4f;closeDistance=4.15f;
        if(row.id.StartsWith("N")||row.id.StartsWith("B")||row.id.StartsWith("M")||row.key=="T51-recipient"){
            var skins=closeActor.VisualRoot.GetComponentsInChildren<SkinnedMeshRenderer>();
            if(skins.Length>0){var bounds=skins[0].bounds;foreach(var skin in skins)bounds.Encapsulate(skin.bounds);
                closeOffset=bounds.center-closeActor.EnemyRoot.position;closeOffset.y+=.12f;
                if(!row.id.StartsWith("N"))closeDistance=Mathf.Max(4.15f,bounds.size.y*1.65f,bounds.size.x*1.35f);}
        }
        // These additional cameras inspect the complete recipient-side mask group,
        // not only the enemy torso. Keep the full-game camera entirely unchanged.
        if(row.key=="H04-recipient"||row.key=="H10-recipient"){
            closeOffset=Vector3.up*2.15f;closeDistance=row.id=="H10"?8.2f:7.0f;
        }
    }
    void BuildTrial(Row row){
        if(string.IsNullOrEmpty(row.trial))return;
        var recipients=FindObjectsByType<EnemyHandle>(FindObjectsSortMode.None).Where(h=>battle.BelongsToCurrentEncounter(h)&&h.gameObject.activeInHierarchy).OrderBy(h=>h.BattleEnemyId).ToArray();
        // Independent deterministic trial, not formal skill hookup or native damage.
        for(int i=0;i<recipients.Length;i++)recipients[i].EnemyRoot.position=new Vector3((i-1)*2.1f,0,3.7f+(i==1?1:0));
        var root=new GameObject("Round2 reference "+row.trial);trial=root.AddComponent<TargetSpellTrial>();
        var style=(TargetSpellTrial.Style)Enum.Parse(typeof(TargetSpellTrial.Style),row.trial);
        string tex=style==TargetSpellTrial.Style.Phoenix?"PhoenixWing.png":style==TargetSpellTrial.Style.Rift?"GoldenRiftContinuous.png":"IceFlower.png";
        var art=AssetDatabase.LoadAssetAtPath<Texture2D>("Assets/VFX_Trials/Textures/"+tex);
        var wing=AssetDatabase.LoadAssetAtPath<GameObject>("Assets/VFX_Trials/Meshes/PhoenixWing.fbx").GetComponentInChildren<MeshFilter>().sharedMesh;
        trial.Build(style,new Vector3(player.transform.position.x,.04f,player.transform.position.z+.65f),recipients.Select(h=>h.EnemyRoot).ToArray(),recipients.Select(h=>h.BattleEnemyId).ToArray(),art,wing);
        Check(trial.LiveCount==3,row.key+" three independent trial targets");
        bloom=camera.gameObject.AddComponent<TrialBloom>();camera.allowHDR=true;
        trialPose=new SpellContactTrial.CasterMotion(player.transform,(SpellContactTrial.CasterMotion.Style)Enum.Parse(typeof(SpellContactTrial.CasterMotion.Style),row.trial));
        Check(trialPose.MappedJointCount==11,row.key+" trial acting maps eleven joints");
    }
    IEnumerator Record(Row row){
        current=row;maxLift=0;maxGripError=0;maxHeroLift=0;maxHeroFootError=0;maxProjectionError=0;weaponMapped=false;BuildTrial(row);int before=hits;var home=actor.EnemyRoot.position;var visualHome=actor.VisualRoot.localPosition;var playerHome=player.transform.position;
        fixtureSequence=0;recordingFixture=playerImpactFixture && PlayerDamageIDs.Contains(row.id);
        if(recordingFixture){fixtureContext="review-"+row.key+"-"+Guid.NewGuid().ToString("N");Send("player-impact-context:"+fixtureContext);fixtureInitialCount=battle.PlayerImpactFeedback.PlayCount;}
        full=new Movie(output+"/after/"+row.key+".mp4",540,960);close=new Movie(output+"/after/"+row.key+"-close.mp4",512,512);
        for(int frame=0;frame<row.frames;frame++){
            recordFrame=frame;
            foreach(var cue in row.cues.Where(c=>c.frame==frame).OrderBy(c=>c.command.StartsWith("enemy:")?1:0))Send(cue.command);
            if(trial){
                float t=Mathf.Max(0,frame/30f-.2f),contact=row.trial=="Phoenix"?.72f:.5f,hold=row.trial=="Phoenix"?.166667f:.2f;
                float visual=t;if(row.trial!="Rift"&&t>=contact)visual=t<contact+hold?contact+.018f:contact+.018f+(t-contact-hold)*1.6f;
                trial.Sample(visual);trialVisual=visual;
            }
            pending=true;yield return null;
            if(row.id=="H00"&&frame==18){
                var hero=player.GetComponent<FoolSkillChoreography>();
                var animation=player.GetComponentInChildren<Animator>();
                Check(hero&&!hero.IsPlaying,row.key+" wrist acting released within 0.4 seconds");
                Check(animation&&animation.GetCurrentAnimatorStateInfo(0).IsName("Meshy · Idle"),row.key+" no long embedded attack take");
                Check(hits==before,row.key+" early body recovery does not report early contact");
            }
            if(row.key=="H00-followup-skill"&&(frame==25||frame==57)){
                var hero=player.GetComponent<FoolSkillChoreography>();
                Check(hero&&hero.IsPlaying&&hero.CurrentSkill=="fool_skill_07",
                    row.key+(frame==25?" next skill begins immediately":" previous basic expiry does not clear next skill"));
            }
        }
        full.Dispose();full=null;close.Dispose();close=null;
        if(recordingFixture){
            Check(fixtureSequence==row.expected,row.key+" visual fixture follows original damage contacts "+fixtureSequence);
            Check(battle.PlayerImpactFeedback.PlayCount-fixtureInitialCount==row.expected,row.key+" formal player impact API accepted each fixture exactly once");
            Check(!battle.PlayerImpactFeedback.IsPlaying,row.key+" player impact overlay returns before clip end");
            Check(Vector3.Distance(playerHome,player.transform.position)<.005f,row.key+" player impact preserves encounter root");
        }
        recordingFixture=false;
        Check(hits-before==row.expected,row.key+" contact acknowledgments "+(hits-before)+" expected "+row.expected);
        Check(error==null,row.key+" no runtime errors");
        Check(maxProjectionError<.001f,row.key+" full and close automatic projection restored "+maxProjectionError.ToString("F6"));
        if(row.id=="H00")Check(Vector3.Distance(playerHome,player.transform.position)<.005f,row.key+" player encounter root unchanged");
        if(row.id=="H07"){
            Check(maxHeroLift>.08f,row.key+" both solved feet lift "+maxHeroLift.ToString("F4"));
            Check(maxHeroFootError<.10f,row.key+" maximum solved foot gap "+maxHeroFootError.ToString("F4"));
            Check(Vector3.Distance(playerHome,player.transform.position)<.005f,row.key+" player encounter root unchanged");
        }
        if(row.id=="R01")Check(!FindObjectsByType<HeroManualMaskRound2>(FindObjectsSortMode.None).Any(m=>m.IsActive),row.key+" authoritative break or expiration clears echo");
        if(row.id.StartsWith("B06")){Check(weaponMapped,row.key+" real two-hand weapon rig mapped");Check(maxGripError<.16f,row.key+" maximum weapon grip gap "+maxGripError.ToString("F4"));}
        if(row.id.StartsWith("N")){
            Check(Vector3.Distance(home,actor.EnemyRoot.position)<.005f,row.key+" stable encounter slot");
            Check(Vector3.Distance(visualHome,actor.VisualRoot.localPosition)<.005f,row.key+" visual lift restored");
            Check(!FindFirstObjectByType<MinionActingRound220260922>(),row.key+" acting owner released");
            if(row.id=="N08B")Check(maxLift>.20f,row.key+" airborne visual lift "+maxLift.ToString("F3"));
        }
        if(trial){
            trial.Sample(4);Check(!trial.GetComponentsInChildren<Renderer>().Any(r=>r.enabled&&r.gameObject.activeInHierarchy),row.key+" completed trial empty");
            trial.Sample(.8f);Check(trial.LiveCount==3,row.key+" replay preserves recipient count");
            var recipient=FindObjectsByType<EnemyHandle>(FindObjectsSortMode.None).First(h=>battle.BelongsToCurrentEncounter(h)&&h.gameObject.activeInHierarchy);
            recipient.gameObject.SetActive(false);trial.Sample(.8f);yield return null;Check(trial.LiveCount==2,row.key+" departing recipient removes only own instance");
            Destroy(trial.gameObject);trial=null;trialPose.Dispose();trialPose=null;Destroy(bloom);bloom=null;
        }
        completed.Add(row.key);File.WriteAllLines(output+"/"+tag+"-recorded.txt",completed);
    }
    IEnumerator Safety(Row row){
        if(row.id=="B03S"){
            int before=hits;Send("church-status:escorted:"+row.actor);yield return new WaitForSeconds(.25f);
            Check(HasEscort(),row.key+" original actor owns ambient escort");
            bridge.SetEnemyVisibility(row.actor+"=hidden");yield return new WaitForSeconds(.25f);
            Check(!HasEscort(),row.key+" actor departure clears ambient escort");
            Send(row.setup);yield return new WaitForSeconds(.5f);Send("combat-start");yield return null;
            Check(!HasEscort(),row.key+" replacement with reused ID does not inherit escort");
            Send("church-status:escorted:"+row.actor);yield return new WaitForSeconds(.2f);
            Check(HasEscort(),row.key+" explicit new status owns replacement actor");
            Send("church-status:escorted:");yield return new WaitForSeconds(.2f);
            Check(!HasEscort(),row.key+" empty authoritative status releases escort");
            Send("combat-stop");yield return new WaitForSeconds(.2f);
            Check(hits==before,row.key+" escort lifecycle adds no damage contact");CheckStopped(row);yield break;
        }
        if(row.id=="R01"){
            int before=hits;Send("masquerade:2");yield return new WaitForSeconds(.35f);
            var mask=FindFirstObjectByType<HeroManualMaskRound2>();Check(mask&&mask.IsActive,row.key+" manual echo deployed");
            Send("masquerade-hit:1");yield return new WaitForSeconds(.65f);Check(mask&&mask.IsActive,row.key+" first interception preserves remaining echo");
            Send("masquerade-hit:0");yield return new WaitForSeconds(.75f);Check(mask&&!mask.IsActive,row.key+" final interception releases echo");
            Send("masquerade:1");yield return new WaitForSeconds(4.4f);Check(mask&&!mask.IsActive,row.key+" timed echo expires after four seconds");
            Send("masquerade:2");yield return new WaitForSeconds(.1f);Send("combat-stop");yield return new WaitForSeconds(.3f);
            Check(mask&&!mask.IsActive,row.key+" stop clears manual echo");Check(hits==before,row.key+" manual defence adds no contact");CheckStopped(row);yield break;
        }
        if(!row.safety){int before=hits;foreach(var cue in row.cues.OrderBy(c=>c.frame)){Send(cue.command);yield return null;}Send("combat-stop");yield return new WaitForSeconds(1.5f);Check(hits==before,row.key+" state stop no late contact");CheckStopped(row);yield break;}
        int initial=hits;Send(row.attack);yield return new WaitForSeconds(.08f);Send("combat-stop");yield return new WaitForSeconds(Mathf.Max(1.5f,row.frames/30f));
        Check(hits==initial,row.key+" cancellation zero late acknowledgments");
        CheckStopped(row);
        Send("combat-start");Send(row.attack);yield return new WaitForSeconds(Mathf.Max(3,row.frames/30f));Check(hits==initial+1,row.key+" retry exactly once");
        if(row.id=="T31"||row.id=="T51"){
            initial=hits;int oldCancel=cancels;Send(row.attack);yield return new WaitForSeconds(.1f);
            bridge.SetEnemyVisibility("clock-guard-secondary=hidden");yield return new WaitForSeconds(1.4f);
            Check(hits==initial&&cancels==oldCancel+1,row.key+" supplied beneficiary departure cancels once without retargeting");
            Check(!FindFirstObjectByType<TowerSupportRound2>(),row.key+" departed beneficiary delivery owner released");
            bridge.SetEnemyVisibility("clock-guard-secondary=visible");yield return new WaitForSeconds(.2f);
        }
        if(row.attack.StartsWith("enemy:")){
            initial=hits;Send(row.attack);yield return new WaitForSeconds(.1f);bridge.SetEnemyVisibility(row.actor+"=hidden");yield return new WaitForSeconds(1.6f);
            if(row.id=="M16"){
                // Existing native repair contract: acknowledge the committed
                // scheduled repair even if its caster/recipient departs. Native
                // resolves it as no-op; this is not a damage hit or new heal.
                Check(hits==initial+1,row.key+" departed repair caster retains one committed non-damage acknowledgement");
                Check(!FindObjectsByType<ArchiveEncounterPresentation>(FindObjectsSortMode.None).Any(p=>p.HasPresentation),row.key+" no unconfirmed heal visual after repair caster departure");
            }else Check(hits==initial,row.key+" death before contact has no late hit");
            initial=hits;
            Send(row.setup);yield return new WaitForSeconds(.5f);Send("combat-start");Send(row.attack);yield return new WaitForSeconds(.1f);
            Send("church-tower:clock-guard-primary@stonehide");yield return new WaitForSeconds(1.6f);
            Check(hits==initial,row.key+" wave replacement no stale hit");CheckStopped(row);
        }
    }
    static bool HasEscort()=>FindObjectsByType<ChurchSpellVisual20260917>(FindObjectsSortMode.None).Any(v=>v.name=="ChurchSpell_b03_escorted"&&v.gameObject.activeInHierarchy);
    void CheckStopped(Row row){
        Check(SpellSpectacle20260926.LiveEffects==0,row.key+" contact spectacle transients released");
        Check(!FindFirstObjectByType<AuthoredNeedleImpact20260925>(),row.key+" authored needle child released");
        if(row.id=="H10"){
            var f=typeof(HeroSpellVolume).GetField("liveDeclarations",BindingFlags.Static|BindingFlags.NonPublic);
            Check(f!=null&&(int)f.GetValue(null)==0,row.key+" declaration exposure ownership released");
        }
        Check(!FindFirstObjectByType<MinionActingRound220260922>()&&!FindFirstObjectByType<ChurchMinionVfx20260921>(),row.key+" minion owned components cleared");
        Check(!FindFirstObjectByType<BountySpellRound2>()&&!FindFirstObjectByType<BountySurfaceRound2>()&&!FindObjectsByType<BountyBodyRound2>(FindObjectsSortMode.None).Any(b=>b.IsPlaying),row.key+" bounty effects and acting cleared");
        Check(!FindFirstObjectByType<TowerBodyRound2>()&&!FindFirstObjectByType<TowerSupportRound2>()&&!FindFirstObjectByType<SaltmawSpell20260919>()&&!FindFirstObjectByType<IronclawSpell20260918>(),row.key+" tower transient acting released");
        Check(!FindObjectsByType<FoolSkillChoreography>(FindObjectsSortMode.None).Any(c=>c.IsPlaying),row.key+" hero acting released");
        Check(!FindObjectsByType<MainlineSpellMeshRound2>(FindObjectsSortMode.None).Any(v=>!v.GetComponentInParent<Mindstone.VFXV1.GuardianWard>()),row.key+" mainline transient surfaces released");
    }
    IEnumerator Start(){
        string requestedOutput=Environment.GetCommandLineArgs().FirstOrDefault(a=>a.StartsWith("--round2-output="))?.Substring(16);
        output=Path.GetFullPath(string.IsNullOrEmpty(requestedOutput)?"../output/whole-spell-round2-20260922":requestedOutput);Directory.CreateDirectory(output+"/after");
        Application.SetStackTraceLogType(LogType.Log,StackTraceLogType.None);
        string filter=Environment.GetCommandLineArgs().FirstOrDefault(a=>a.StartsWith("--round2-only="))?.Substring(14);
        playerImpactFixture=Environment.GetCommandLineArgs().Contains("--round2-player-impact-fixture");
        safety=Environment.GetCommandLineArgs().Contains("--round2-safety");
        SpellSpectacle20260926.Suppressed=Environment.GetCommandLineArgs().Contains("--spectacle-off");
        // Tower minions walk in from beyond their slots (2026-10-03); the rows check that every
        // actor stays in its encounter slot, so the recorder starts them already arrived.
        TowerMinionApproach20261003.Disabled=true;tag=(safety?"safety-":"record-")+(filter??"all").Replace(",","_");
        using(var sha=SHA256.Create()){
            var sourceFiles=Directory.EnumerateFiles(Application.dataPath,"*",SearchOption.AllDirectories).Where(p=>p.EndsWith(".cs")||p.EndsWith(".shader")).OrderBy(p=>p);
            File.WriteAllLines(output+"/"+tag+"-source-sha256.txt",sourceFiles.Select(p=>BitConverter.ToString(sha.ComputeHash(File.ReadAllBytes(p))).Replace("-","").ToLowerInvariant()+"  Assets/"+p.Substring(Application.dataPath.Length+1)));
        }
        QualitySettings.vSyncCount=0;Application.targetFrameRate=240;
        Application.logMessageReceived+=Log;Time.captureFramerate=30;Time.timeScale=1;yield return new WaitForSeconds(3);
        bridge=FindFirstObjectByType<UnityBattleBridge>();battle=FindFirstObjectByType<BattlePrototype>();camera=Camera.main;player=(GameObject)typeof(BattlePrototype).GetField("player",Private).GetValue(battle);
        var plan=JsonUtility.FromJson<Plan>(File.ReadAllText(output+"/capture-plan.json"));
        foreach(var row in plan.rows){if(filter!=null&&!filter.Split(',').Any(p=>row.key.StartsWith(p)))continue;yield return Setup(row);if(safety)yield return Safety(row);else yield return Record(row);Send("combat-stop");yield return null;yield return null;}
        Check(error==null,"no runtime errors at end");Check(Time.timeScale==1,"global combat time scale untouched");
        File.WriteAllLines(output+"/"+tag+"-passed.txt",checks);EditorApplication.isPlaying=false;
    }
    void Fit(){typeof(BattlePrototype).GetMethod("FitRuntimeBackground",Private).Invoke(battle,new object[]{camera});}
    void Update(){trialPose?.Restore();}
    void LateUpdate(){
        if(!pending||full==null)return;pending=false;var position=camera.transform.position;var rotation=camera.transform.rotation;float fov=camera.fieldOfView,aspect=camera.aspect;
        var acting=FindFirstObjectByType<MinionActingRound220260922>();if(acting)maxLift=Mathf.Max(maxLift,acting.CurrentLift);
        if(current.id=="H07"){
            var hero=player.GetComponent<FoolSkillChoreography>();
            if(hero&&hero.IsPlaying){maxHeroLift=Mathf.Max(maxHeroLift,hero.LastHopFootLift);maxHeroFootError=Mathf.Max(maxHeroFootError,hero.LastFootError);}
        }
        var bounty=actor?actor.GetComponent<BountyBodyRound2>():null;
        if(bounty&&bounty.IsPlaying&&current.id.StartsWith("B06")){weaponMapped|=bounty.HasWeaponGripRig;maxGripError=Mathf.Max(maxGripError,bounty.MaximumWeaponGripError);}
        trialPose?.Sample(trialVisual);
        try{
            camera.aspect=540f/960;Fit();full.Frame(camera);CheckProjectionState();
            Vector3 focus=current.focus=="player"?player.transform.position+Vector3.up*1.2f:closeActor.EnemyRoot.position+closeOffset;
            camera.aspect=1;camera.fieldOfView=43;camera.transform.position=focus-camera.transform.forward*(current.focus=="player"?4.15f:closeDistance);Fit();close.Frame(camera);CheckProjectionState();
        }finally{camera.transform.SetPositionAndRotation(position,rotation);camera.fieldOfView=fov;camera.aspect=aspect;Fit();}
    }
    void CheckProjectionState(){
        var expected=Matrix4x4.Perspective(camera.fieldOfView,camera.aspect,camera.nearClipPlane,camera.farClipPlane);
        var actual=camera.projectionMatrix;
        for(int i=0;i<16;i++)maxProjectionError=Mathf.Max(maxProjectionError,Mathf.Abs(expected[i]-actual[i]));
    }
    void OnDestroy(){Application.logMessageReceived-=Log;trialPose?.Dispose();full?.Dispose();close?.Dispose();}
}
