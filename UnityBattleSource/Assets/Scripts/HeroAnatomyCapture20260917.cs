#if UNITY_EDITOR || UNITY_STANDALONE
using System;
using System.IO;
using System.Linq;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public sealed class HeroAnatomyCapture20260917 : MonoBehaviour
{
    string folder; readonly List<string> report=new List<string>();
    [RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.AfterSceneLoad)]
    static void Boot(){if(Environment.GetCommandLineArgs().Contains("--verify-hero-anatomy"))new GameObject("Hero anatomy verification").AddComponent<HeroAnatomyCapture20260917>();}
    void Awake(){Application.logMessageReceived+=Error;}
    void OnDestroy(){Application.logMessageReceived-=Error;}
    void Error(string message,string trace,LogType type){if(type!=LogType.Exception)return;if(folder!=null)File.WriteAllText(Path.Combine(folder,"failed.txt"),message+"\n"+trace);Application.Quit(1);}
    static void Require(bool value,string message){if(!value)throw new Exception(message);}
    IEnumerator Start(){
        folder=Environment.GetEnvironmentVariable("MISTPORT_HERO_ANATOMY")??"/tmp/hero-anatomy";
        Directory.CreateDirectory(folder);File.Delete(Path.Combine(folder,"passed.txt"));File.Delete(Path.Combine(folder,"failed.txt"));
        Screen.SetResolution(720,1280,false);yield return new WaitForSeconds(3);Time.captureFramerate=12;
        var battle=FindFirstObjectByType<BattlePrototype>();Require(battle,"Battle missing");
        battle.UseEarlyHellHoundModel();battle.SetEarlyBattlePresence("4");battle.SetNativeCombatEnabled(true);
        var hero=GameObject.Find("Fool_Imported");Require(hero,"Hero missing");
        var controller=hero.GetComponent<HeroFingerArticulation20260917>();Require(controller,"Finger controller missing");
        Require(controller.BoneCount==30&&controller.FingerCount==10,"Expected 30 weighted phalanges and 10 fingers");
        var bones=hero.GetComponentsInChildren<Transform>(true).Where(b=>b.name.StartsWith("MP_Left_")||b.name.StartsWith("MP_Right_")).ToArray();
        Require(bones.Length==30&&bones.Select(b=>b.name).Distinct().Count()==30,"Duplicate/missing extra bones");
        var hands=new[]{"PremiumLeftHand","PremiumRightHand"}.Select(name=>hero.GetComponentsInChildren<SkinnedMeshRenderer>(true).FirstOrDefault(r=>r.name==name)).ToArray();
        Require(hands.All(h=>h),"Premium hand renderers missing");
        var animator=hero.GetComponentInChildren<Animator>();var idle=hero.GetComponent<HeroLivingIdle20260916>();var choreography=hero.GetComponent<FoolSkillChoreography>();
        var camera=Camera.main;Vector3 cameraOrigin=camera.transform.position;Quaternion cameraRotation=camera.transform.rotation;float originalFov=camera.fieldOfView;
        Vector3 faceDirection=Vector3.ProjectOnPlane(hero.transform.position-cameraOrigin,Vector3.up).normalized;
        foreach(string mode in new[]{"idle","bind","fool_skill_04","fool_skill_07"}){
            foreach(var hand in hands){
                choreography.Clear();controller.enabled=mode!="bind";
                if(mode.StartsWith("fool"))battle.PresentPlayerSkill(mode);
                string path=mode+"-"+hand.name;Directory.CreateDirectory(Path.Combine(folder,path));
                for(int n=0;n<12;n++){
                    // Wait until Animator, IK, choreography and camera effects have
                    // all finished. Render this inspection camera explicitly from
                    // the same final pose; next-frame LateUpdate cannot reframe it.
                    yield return null;yield return new WaitForEndOfFrame();
                    bool left=hand.name=="PremiumLeftHand";
                    var wrist=animator.GetBoneTransform(left?HumanBodyBones.LeftHand:HumanBodyBones.RightHand);
                    var forearm=animator.GetBoneTransform(left?HumanBodyBones.LeftLowerArm:HumanBodyBones.RightLowerArm);
                    Vector3 palm=wrist.position+(wrist.position-forearm.position).normalized*.065f;
                    var points=Bake(hand);var bounds=new Bounds(points[0],Vector3.zero);foreach(var v in points)bounds.Encapsulate(v);
                    camera.transform.position=bounds.center+faceDirection*.66f+Vector3.up*.04f;camera.transform.LookAt(bounds.center);camera.fieldOfView=45;
                    string name=path+"/frame-"+n.ToString("D3");
                    CaptureCamera(camera,name);
                    File.AppendAllText(Path.Combine(folder,"camera-diagnostics.txt"),name+" wrist="+wrist.position.ToString("F5")+" palm="+palm.ToString("F5")
                        +" boundsCenter="+bounds.center.ToString("F5")+" boundsSize="+bounds.size.ToString("F5")
                        +" rendererScale="+hand.transform.lossyScale.ToString("F5")+" camera="+camera.transform.position.ToString("F5")
                        +" wristViewport="+camera.WorldToViewportPoint(wrist.position).ToString("F5")+"\n");
                }
                if(mode=="bind")Require(bones.All(b=>Quaternion.Angle(b.localRotation,Quaternion.identity)<.001f),"Disabled fingers did not return to identity bind");
                yield return new WaitForSeconds(1);
            }
        }
        choreography.Clear();controller.enabled=true;yield return new WaitForSeconds(.8f);
        // Freeze all original pose authors before the differential BakeMesh pair.
        // Restore their enabled states in finally even if an assertion fails.
        bool aEnabled=animator.enabled,iEnabled=idle&&idle.enabled,cEnabled=choreography.enabled;
        try{
            animator.enabled=false;if(idle)idle.enabled=false;choreography.enabled=false;
            yield return null;yield return new WaitForEndOfFrame();
            var curled=hands.Select(Bake).ToArray();
            controller.enabled=false;
            var uncurled=hands.Select(Bake).ToArray();
            for(int h=0;h<hands.Length;h++){
                Require(curled[h].Length==uncurled[h].Length,"Vertex count changed");float maximum=0;int moved=0;
                for(int v=0;v<curled[h].Length;v++){float distance=Vector3.Distance(curled[h][v],uncurled[h][v]);maximum=Mathf.Max(maximum,distance);if(distance>.0002f)moved++;}
                Require(maximum>.0002f&&maximum<.04f,"Finger skin delta outside 0.2mm–4cm: "+maximum);
                report.Add(hands[h].name+": maximum finger-only vertex displacement="+maximum.ToString("F7")+" m; vertices over 0.2mm="+moved);
            }
            Require(bones.All(b=>Quaternion.Angle(b.localRotation,Quaternion.identity)<.001f),"Bind reset after frozen comparison failed");
        }finally{animator.enabled=aEnabled;if(idle)idle.enabled=iEnabled;choreography.enabled=cEnabled;controller.enabled=true;}
        hero.SetActive(false);Require(bones.All(b=>Quaternion.Angle(b.localRotation,Quaternion.identity)<.001f),"Deactivate did not reset phalanges");
        hero.SetActive(true);yield return new WaitForSeconds(.7f);
        Require(controller.BoneCount==30&&controller.FingerCount==10,"Reopen lost finger rig");
        Require(hero.GetComponentsInChildren<Transform>(true).Count(b=>b.name.StartsWith("MP_Left_")||b.name.StartsWith("MP_Right_"))==30,"Reopen duplicated finger rig");
        choreography.Begin("fool_skill_07");yield return new WaitForSeconds(.3f);choreography.Clear();yield return new WaitForSeconds(.8f);
        Require(!choreography.IsPlaying&&controller.MaxAppliedAngle>0&&controller.MaxAppliedAngle<=9,"Cancel failed to return bounded finger motion");
        var facial=hero.GetComponent<HeroFacialMotion20260917>();Require(facial&&facial.ShapeCount==1,"Continuous face Blink shape missing");
        var face=hero.GetComponentsInChildren<SkinnedMeshRenderer>().First(r=>r.name=="PremiumFace");int blink=face.sharedMesh.GetBlendShapeIndex("Blink");
        facial.enabled=false;face.SetBlendShapeWeight(blink,0);var open=Bake(face);face.SetBlendShapeWeight(blink,100);var closed=Bake(face);
        float maxLid=0;for(int n=0;n<open.Length;n++)maxLid=Mathf.Max(maxLid,Vector3.Distance(open[n],closed[n]));
        Require(maxLid>.001f&&maxLid<.03f,"Blink must deform real eyelid vertices within 1mm–3cm");
        foreach(float weight in new[]{0f,50f,100f}){
            face.SetBlendShapeWeight(blink,weight);yield return null;yield return new WaitForEndOfFrame();
            AimFace(camera,animator,hero,faceDirection);CaptureCamera(camera,"face-blink-"+weight);
        }
        // A readable procedural face must retain its active shape in skill 06's snapshot.
        var sourceFace=Bake(face);var theatreObject=new GameObject("Anatomy shadow verification");var theatre=theatreObject.AddComponent<HeroArcanaTheatreVFX>();var shadowOrigin=hero.transform.position;
        var performance=theatre.Play("fool_skill_06",hero.transform,()=>shadowOrigin,()=>shadowOrigin+Vector3.forward*3,()=>{});
        Require(performance.MoveNext(),"Shadow effect did not start");
        var echo=FindObjectsByType<MeshFilter>(FindObjectsSortMode.None).FirstOrDefault(m=>m.name=="PremiumFace echo");Require(echo,"Face missing from shadow snapshot");
        var snapshot=echo.sharedMesh.vertices;Require(snapshot.Length==sourceFace.Length,"Shadow face vertex count mismatch");float shadowError=0;
        for(int n=0;n<snapshot.Length;n++)shadowError=Mathf.Max(shadowError,Vector3.Distance(snapshot[n]+shadowOrigin,sourceFace[n]));
        theatre.Clear();(performance as IDisposable)?.Dispose();Destroy(theatreObject);Require(shadowError<.00002f,"Shadow dropped active eyelid shape: "+shadowError);
        report.Add("Skill 06 closed-eye snapshot maximum world-space error="+shadowError.ToString("F8")+" m.");
        face.SetBlendShapeWeight(blink,0);facial.enabled=true;int priorBlinks=facial.CompletedBlinks;float maxBlinkWeight=0;
        Directory.CreateDirectory(Path.Combine(folder,"face-motion"));
        for(int n=0;n<96;n++){
            yield return null;yield return new WaitForEndOfFrame();AimFace(camera,animator,hero,faceDirection);CaptureCamera(camera,"face-motion/frame-"+n.ToString("D3"));
            maxBlinkWeight=Mathf.Max(maxBlinkWeight,facial.CurrentWeight);
        }
        Require(facial.CompletedBlinks-priorBlinks>=2&&maxBlinkWeight>90,"Automatic blink did not close and reopen twice");
        facial.enabled=false;Require(face.GetBlendShapeWeight(blink)==0,"Disabling blink left closed eyelids");facial.enabled=true;
        report.Add("Real eyelid maximum displacement="+maxLid.ToString("F7")+" m; automatic blinks="+(facial.CompletedBlinks-priorBlinks)+"; peak closure="+maxBlinkWeight+"; disable reset verified.");
        camera.transform.SetPositionAndRotation(cameraOrigin,cameraRotation);camera.fieldOfView=originalFov;
        report.Add("30 bones / 10 fingers; identity bind on disable and actor close; reopen no duplicates; choreography cancel returns bounded idle; frames="+controller.TotalAnimatedFrames);
        report.Add("Actual Unity skin deformation and camera captures; not phone or artistic acceptance.");
        File.WriteAllLines(Path.Combine(folder,"passed.txt"),report);Application.Quit(0);
    }
    static Vector3[] Bake(SkinnedMeshRenderer renderer){var mesh=new Mesh();renderer.BakeMesh(mesh);var vertices=mesh.vertices;for(int n=0;n<vertices.Length;n++)vertices[n]=renderer.transform.TransformPoint(vertices[n]);Destroy(mesh);return vertices;}
    static void AimFace(Camera camera,Animator animator,GameObject hero,Vector3 direction){
        var eyes=hero.GetComponentsInChildren<SkinnedMeshRenderer>().Where(r=>r.name.StartsWith("Eyeball_")).ToArray();
        Vector3 center=Vector3.zero;foreach(var eye in eyes){var points=Bake(eye);var bounds=new Bounds(points[0],Vector3.zero);foreach(var p in points)bounds.Encapsulate(p);center+=bounds.center;}
        center=eyes.Length>0?center/eyes.Length-hero.transform.up*.015f:animator.GetBoneTransform(HumanBodyBones.Head).position;
        camera.transform.position=center+direction*.62f;camera.transform.LookAt(center);camera.fieldOfView=40;
    }
    void CaptureCamera(Camera camera,string path){
        var previous=camera.targetTexture;var active=RenderTexture.active;
        var render=new RenderTexture(720,1280,24,RenderTextureFormat.ARGB32);
        var texture=new Texture2D(720,1280,TextureFormat.RGB24,false);
        try{camera.targetTexture=render;camera.Render();RenderTexture.active=render;
            texture.ReadPixels(new Rect(0,0,720,1280),0,0);texture.Apply();
            File.WriteAllBytes(Path.Combine(folder,path+".png"),texture.EncodeToPNG());
        }finally{camera.targetTexture=previous;RenderTexture.active=active;render.Release();Destroy(render);Destroy(texture);}
    }
    void Capture(string path){var texture=ScreenCapture.CaptureScreenshotAsTexture();File.WriteAllBytes(Path.Combine(folder,path+".png"),texture.EncodeToPNG());Destroy(texture);}
}
#endif
