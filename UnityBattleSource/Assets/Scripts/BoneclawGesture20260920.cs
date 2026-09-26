using System.Collections.Generic;
using UnityEngine;
[DefaultExecutionOrder(1800)]
public sealed class BoneclawGesture20260920:MonoBehaviour {
 readonly Dictionary<string,Transform> joints=new Dictionary<string,Transform>();
 readonly Dictionary<string,Quaternion> rest=new Dictionary<string,Quaternion>();
 string action;float age,contact;
 public static BoneclawGesture20260920 Create(EnemyHandle actor,string action,float contact,Transform owner){
  var g=new GameObject("D06 distinct gesture");g.transform.SetParent(owner,false);
  var v=g.AddComponent<BoneclawGesture20260920>();v.action=action;v.contact=contact;
  foreach(var t in actor.VisualRoot.GetComponentsInChildren<Transform>(true))
   if(t.name=="Chest"||t.name=="Head"||t.name.StartsWith("UpperArm.")||t.name.StartsWith("Forearm.")||t.name.StartsWith("Hand.")||t.name.StartsWith("Tail")){v.joints[t.name]=t;v.rest[t.name]=t.localRotation;}
  Debug.Log("D06_GESTURE "+action+" joints="+v.joints.Count);return v;
 }
 public void Tick(float t){age=t;}
 void Update(){if(action=="tower_claw_charge")age+=Time.deltaTime;}
 void Pose(string n,Vector3 a){if(joints.TryGetValue(n,out var t)&&t)t.localRotation=rest[n]*Quaternion.Euler(a);}
 void LateUpdate(){
  float load=Mathf.SmoothStep(0,1,age/(contact*.55f));
  float strike=Mathf.SmoothStep(0,1,(age-contact*.70f)/(contact*.30f));
  float recover=1-Mathf.SmoothStep(0,1,(age-contact-.14f)/.41f);
  if(action=="tower_claw_charge"){
   float lift=Mathf.SmoothStep(0,1,age/.45f);
   Pose("Chest",new Vector3(-12*lift,18*lift,0));
   Pose("UpperArm.R",new Vector3(-75*lift,-22*lift,12*lift));
   Pose("Forearm.R",new Vector3(-40*lift,0,0));
   Pose("UpperArm.L",new Vector3(-25*lift,0,-20*lift));
   Pose("TailBase",new Vector3(0,-20*lift,0));
  }else if(action=="tower_heavy_claw"){
   Pose("Chest",new Vector3(-18*load+46*strike,0,0)*recover);
   Pose("Head",new Vector3(-12*load+24*strike,0,0)*recover);
   foreach(string side in new[]{"L","R"}){float s=side=="L"?1:-1;
    Pose("UpperArm."+side,new Vector3(-125*load+175*strike,0,s*12*load)*recover);
    Pose("Forearm."+side,new Vector3(-28*load+65*strike,0,0)*recover);
    Pose("Hand."+side,new Vector3(25*load-50*strike,0,0)*recover);
   }
  }else if(action=="tower_piercing_claw"){
   Pose("Chest",new Vector3(-8*load+25*strike,28*load-52*strike,0)*recover);
   Pose("UpperArm.R",new Vector3(-70*load+115*strike,-30*load+55*strike,18*load)*recover);
   Pose("Forearm.R",new Vector3(-55*load+95*strike,0,0)*recover);
   Pose("Hand.R",new Vector3(18*load-36*strike,0,0)*recover);
   Pose("UpperArm.L",new Vector3(-18*load,0,-20*load)*recover);
  }else{
   float turn=(-38*load+90*strike)*recover;
   Pose("Chest",new Vector3(8*load,turn,0)*recover);
   Pose("Head",new Vector3(0,-turn*.45f,0));
   Pose("UpperArm.L",new Vector3(-28*load,0,-32*load)*recover);
   Pose("UpperArm.R",new Vector3(-28*load,0,32*load)*recover);
   Pose("TailBase",new Vector3(0,turn*1.2f,0));
   Pose("Tail1",new Vector3(0,(-28*load+82*strike)*recover,0));
   Pose("TailTip",new Vector3(0,(-18*load+65*strike)*recover,0));
  }
 }
 bool restored;
 public void Restore(){if(restored)return;restored=true;foreach(var p in joints)if(p.Value)p.Value.localRotation=rest[p.Key];}
 void OnDisable(){Restore();}
 void OnDestroy(){Restore();}
}
