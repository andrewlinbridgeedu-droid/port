using System.Collections.Generic;
using UnityEngine;
[DefaultExecutionOrder(1800)]
public sealed class StonehideGesture20260920:MonoBehaviour {
 readonly Dictionary<string,Transform> joints=new Dictionary<string,Transform>();
 readonly Dictionary<string,Quaternion> rest=new Dictionary<string,Quaternion>();
 string action;float age,contact;
 readonly List<LineRenderer> seams=new List<LineRenderer>(); Material seamMaterial;
 public static StonehideGesture20260920 Create(EnemyHandle actor,string action,float contact,Transform owner){
  var g=new GameObject("D01 weighted double slam");g.transform.SetParent(owner,false);
  var v=g.AddComponent<StonehideGesture20260920>();v.action=action;v.contact=contact;
  foreach(var t in actor.VisualRoot.GetComponentsInChildren<Transform>(true))
   if(t.name=="Chest"||t.name=="Head"||t.name.StartsWith("UpperArm.")||t.name.StartsWith("Forearm.")||t.name.StartsWith("Hand.")||t.name.StartsWith("Tail")){v.joints[t.name]=t;v.rest[t.name]=t.localRotation;}
  v.BuildSeams();
  Debug.Log("D01_GESTURE "+action+" joints="+v.joints.Count);return v;
 }
 public void Tick(float t){age=t;}
 void Update(){if(action=="guard"||action=="charge")age+=Time.deltaTime;}
 void Pose(string n,Vector3 a){if(joints.TryGetValue(n,out var t)&&t)t.localRotation=rest[n]*Quaternion.Euler(a);}
 void LateUpdate(){
  float load=Mathf.SmoothStep(0,1,age/(contact*.55f));
  float strike=Mathf.SmoothStep(0,1,(age-contact*.70f)/(contact*.30f));
  float recover=1-Mathf.SmoothStep(0,1,(age-contact-.14f)/.41f);
  if(action=="guard"){
   float close=Mathf.SmoothStep(0,1,age/.25f);
   Pose("Chest",new Vector3(10,0,0)*close);
   Pose("Head",new Vector3(25,0,0)*close);
   foreach(string side in new[]{"L","R"}){float sign=side=="L"?1:-1;
    Pose("UpperArm."+side,new Vector3(-35,sign*22,sign*24)*close);
    Pose("Forearm."+side,new Vector3(55,sign*12,0)*close);
   }
  }else if(action=="charge"){
   float lift=Mathf.SmoothStep(0,1,age/.45f);
   Pose("Chest",new Vector3(-18*lift,0,0));Pose("Head",new Vector3(-10*lift,0,0));
   foreach(string side in new[]{"L","R"}){float sign=side=="L"?1:-1;
    Pose("UpperArm."+side,new Vector3(-110*lift,0,sign*18*lift));
    Pose("Forearm."+side,new Vector3(-20*lift,0,0));
   }
  }else{
   Pose("Chest",new Vector3(-18*load+50*strike,0,0)*recover);
   Pose("Head",new Vector3(-10*load+28*strike,0,0)*recover);
   foreach(string side in new[]{"L","R"}){float sign=side=="L"?1:-1;
    Pose("UpperArm."+side,new Vector3(-125*load+125*strike,0,sign*18*(load-strike))*recover);
    Pose("Forearm."+side,new Vector3(-20*load+20*strike,0,0)*recover);
    Pose("Hand."+side,new Vector3(18*load-36*strike,0,0)*recover);
   }
  }
  DrawSeams();
 }
 void BuildSeams(){
  seamMaterial=new Material(Shader.Find("Sprites/Default"));
  for(int i=0;i<8;i++){var go=new GameObject("D01 arm plate glow");go.transform.SetParent(transform,false);var line=go.AddComponent<LineRenderer>();line.sharedMaterial=seamMaterial;line.useWorldSpace=true;line.positionCount=7;line.numCapVertices=3;line.widthMultiplier=i%2==0?.065f:.024f;line.widthCurve=new AnimationCurve(new Keyframe(0,0),new Keyframe(.2f,1),new Keyframe(.8f,.8f),new Keyframe(1,0));seams.Add(line);}
 }
 void DrawSeams(){
  float life=action=="guard"?.6f:action=="charge"?1:1-Mathf.Clamp01((age-contact+.08f)/.2f);
  Vector3 front=Camera.main?-Camera.main.transform.forward:Vector3.back;
  for(int i=0;i<8;i++){
   string side=i<4?"L":"R";int segment=(i%4)/2;
   if(!joints.TryGetValue((segment==0?"UpperArm.":"Forearm.")+side,out var a)||!joints.TryGetValue((segment==0?"Forearm.":"Hand.")+side,out var b))continue;
   var line=seams[i];Color c=i%2==0?new Color(1,.46f,.08f):new Color(1,.92f,.65f);c.a=life*(.65f+.2f*Mathf.Sin(age*8+segment));line.startColor=c;var tip=Color.Lerp(c,new Color(1,.98f,.78f,c.a),.65f);tip.a=c.a*(.55f+.45f*Mathf.Pow(Mathf.Max(0,Mathf.Sin(age*5-segment*.9f)),2));line.endColor=tip;
   line.widthMultiplier=(i%2==0?.082f:.022f)*(1+.15f*Mathf.Sin(age*5.5f-segment));
   for(int j=0;j<7;j++){float q=j/6f;Vector3 pos=Vector3.Lerp(a.position,b.position,.12f+q*.76f)+front*.23f;pos+=Vector3.right*(Mathf.Sin(q*9+segment*1.7f)*.025f);line.SetPosition(j,pos);}
  }
 }
 bool restored;
 public void Restore(){if(restored)return;restored=true;foreach(var line in seams)if(line)line.enabled=false;foreach(var p in joints)if(p.Value)p.Value.localRotation=rest[p.Key];}
 void OnDisable(){Restore();}
 void OnDestroy(){Restore();if(seamMaterial)Destroy(seamMaterial);}
}
