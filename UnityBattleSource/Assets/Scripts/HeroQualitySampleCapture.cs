#if UNITY_EDITOR || UNITY_STANDALONE
using System;using System.IO;using System.Linq;using System.Collections;using UnityEngine;
public sealed class HeroQualitySampleCapture:MonoBehaviour {
 string folder;float maxFoot,maxFinger;int fingerChains;Vector3 origin;
 [RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.AfterSceneLoad)]static void Boot(){if(Environment.GetCommandLineArgs().Contains("--verify-hero-quality"))new GameObject("Hero quality sample capture").AddComponent<HeroQualitySampleCapture>();}
 void Awake(){Application.logMessageReceived+=Error;}
 void Error(string message,string trace,LogType type){if(type!=LogType.Exception)return;if(folder!=null)File.WriteAllText(Path.Combine(folder,"failed.txt"),message+"\n"+trace);Application.Quit(1);}
 void OnDestroy(){Application.logMessageReceived-=Error;}
 IEnumerator Start(){
  folder=Environment.GetEnvironmentVariable("MISTPORT_HERO_SAMPLE")??"/tmp/hero-quality";Directory.CreateDirectory(folder);File.Delete(Path.Combine(folder,"passed.txt"));
  Screen.SetResolution(540,960,false);yield return new WaitForSeconds(3);Time.captureFramerate=12;
  var b=FindFirstObjectByType<BattlePrototype>();b.UseEarlyHellHoundModel();b.SetEarlyBattlePresence("4");b.SetNativeCombatEnabled(true);
  var hero=GameObject.Find("Fool_Imported");var idle=hero.GetComponent<HeroLivingIdle20260916>();var a=hero.GetComponentInChildren<Animator>();origin=hero.transform.position;
  if(!hero.GetComponentsInChildren<SkinnedMeshRenderer>().Any(r=>r.name=="Hero garment collar and cuff welts"))throw new Exception("Tailoring geometry was not installed");
  var c=Camera.main;var p=c.transform.position;var q=c.transform.rotation;var f=c.fieldOfView;
  Directory.CreateDirectory(Path.Combine(folder,"battle"));
  for(int n=0;n<240;n++){yield return null;yield return new WaitForEndOfFrame();maxFoot=Mathf.Max(maxFoot,idle.LastFootError);maxFinger=Mathf.Max(maxFinger,idle.LastFingerAddedAngle);fingerChains=Mathf.Max(fingerChains,idle.LastFingerChainCount);Capture("battle/frame-"+n.ToString("D3"));if(Vector3.Distance(origin,hero.transform.position)>.001f)throw new Exception("Hero root drift");}
  Capture("battle");
  Screen.SetResolution(720,1280,false);yield return null;yield return null;
  foreach(string view in new[]{"back","front","three-quarter"}){
   var chest=a.GetBoneTransform(HumanBodyBones.Chest).position;var direction=(p-chest).normalized;
   if(view=="front")direction=-direction;if(view=="three-quarter")direction=Quaternion.AngleAxis(45,Vector3.up)*-direction;
   c.transform.position=chest+direction*2.3f;c.transform.LookAt(chest);c.fieldOfView=40;
   yield return null;yield return new WaitForEndOfFrame();Capture(view);
  }
  var head=a.GetBoneTransform(HumanBodyBones.Head).position+hero.transform.up*.07f;
  var eyes=hero.GetComponentsInChildren<SkinnedMeshRenderer>().Where(r=>r.name.StartsWith("Eyeball_")).ToArray();
  if(eyes.Length>0){head=Vector3.zero;foreach(var eye in eyes){var mesh=new Mesh();eye.BakeMesh(mesh);head+=eye.transform.TransformPoint(mesh.bounds.center);Destroy(mesh);}head=head/eyes.Length-hero.transform.up*.015f;}
  var faceDirection=Vector3.ProjectOnPlane(head-p,Vector3.up).normalized;
  foreach(var angle in new[]{0f,45f,-45f}) {
   var direction=Quaternion.AngleAxis(angle,Vector3.up)*faceDirection;
   c.transform.position=head+direction*.7f;c.transform.LookAt(head);c.fieldOfView=40;
   yield return null;yield return new WaitForEndOfFrame();Capture(angle==0?"face":angle>0?"face-right":"face-left");
  }
  var lh=a.GetBoneTransform(HumanBodyBones.LeftHand);var rh=a.GetBoneTransform(HumanBodyBones.RightHand);
  foreach(var hand in new[]{lh,rh})if(hand){
   var forearm=hand==lh?a.GetBoneTransform(HumanBodyBones.LeftLowerArm):a.GetBoneTransform(HumanBodyBones.RightLowerArm);var palm=hand.position+(hand.position-forearm.position).normalized*.075f;
   c.transform.position=palm+faceDirection*.85f+Vector3.up*.10f;c.transform.LookAt(palm);c.fieldOfView=40;
   yield return null;yield return new WaitForEndOfFrame();Capture(hand==lh?"hand-left":"hand-right");
  }
  c.transform.position=p;c.transform.rotation=q;c.fieldOfView=f;
  File.WriteAllText(Path.Combine(folder,"metrics.txt"),"20 seconds 12fps; maximum foot solve error="+maxFoot.ToString("F7")+"; root unchanged; finger chains="+fingerChains+"; max added curl="+maxFinger+"; mapped finger chains="+idle.MappedFingerChainCount+"; gaze pitch="+idle.LastGazePitchBefore+" -> "+idle.LastGazePitchAfter+"\n");
  var fingers=hero.GetComponent<HeroFingerArticulation20260917>();var facial=hero.GetComponent<HeroFacialMotion20260917>();
  if(fingers)File.AppendAllText(Path.Combine(folder,"metrics.txt"),"Custom finger rig: bones="+fingers.BoneCount+"; digits="+fingers.FingerCount+"; current max curl="+fingers.MaxAppliedAngle+"; animated frames="+fingers.TotalAnimatedFrames+"\n");
  if(facial)File.AppendAllText(Path.Combine(folder,"metrics.txt"),"Real eyelid shape: count="+facial.ShapeCount+"; completed blinks="+facial.CompletedBlinks+"\n");
  if(maxFoot>.002f)throw new Exception("Foot solve exceeded 2mm: "+maxFoot);
  File.WriteAllText(Path.Combine(folder,"passed.txt"),"Actual battle and inspection-camera capture; 20s planted-foot IK, fixed root. Not phone or artistic acceptance.");Application.Quit(0);
 }
 void Capture(string name){var t=ScreenCapture.CaptureScreenshotAsTexture();File.WriteAllBytes(Path.Combine(folder,name+".png"),t.EncodeToPNG());Destroy(t);}
}
#endif
