using System.Collections.Generic;
using UnityEngine;

// Additive acting over each authored creature clip. Only the visual hierarchy
// moves: encounter slots, anchors, native timing, and damage remain untouched.
[DefaultExecutionOrder(1150)]
public sealed class MinionActingRound220260922 : MonoBehaviour
{
    sealed class Joint { public Transform bone; public Quaternion rotation; public Vector3 position; public bool applied; }
    readonly Dictionary<string,Joint> joints = new Dictionary<string,Joint>();
    EnemyHandle actor; Transform visual; string species; bool second, held;
    float contact, clock, began;
    Vector3 rootPosition, forward, right; Quaternion rootRotation; bool rootApplied;
    public int MappedJointCount => joints.Count;
    public float CurrentLift { get; private set; }

    public static MinionActingRound220260922 Create(EnemyHandle actor,string species,string intent,float contact,Transform owner)
    {
        var go=new GameObject("Minion round2 acting "+species+" "+intent);go.transform.SetParent(owner,false);
        var m=go.AddComponent<MinionActingRound220260922>();m.actor=actor;m.visual=actor.VisualRoot;
        m.species=species;m.second=intent.EndsWith("second")||intent.EndsWith("charge2");m.held=intent.Contains("charge");
        m.contact=contact;m.began=Time.time;
        m.forward=actor.EnemyRoot.forward;m.forward.y=0;if(m.forward.sqrMagnitude<.01f)m.forward=Vector3.forward;m.forward.Normalize();
        m.right=Vector3.Cross(Vector3.up,m.forward).normalized;
        foreach(var bone in m.visual.GetComponentsInChildren<Transform>(true))
            if(bone.name=="Pelvis"||bone.name=="Chest"||bone.name=="Head"||bone.name=="Throat"||bone.name.StartsWith("UpperArm.")||bone.name.StartsWith("Forearm.")||bone.name.StartsWith("Hand.")||bone.name.StartsWith("Thigh.")||bone.name.StartsWith("Shin.")||bone.name.StartsWith("Foot.")||bone.name.StartsWith("Armor.")||bone.name.StartsWith("Cloth.")||bone.name.StartsWith("Tail")||bone.name.StartsWith("Ear."))
                m.joints[bone.name]=new Joint{bone=bone};
        return m;
    }
    public void Tick(float time){clock=Mathf.Max(0,time);}
    void Update(){Restore();}
    static float Ease(float t)=>Mathf.SmoothStep(0,1,Mathf.Clamp01(t));
    void LateUpdate()
    {
        if(!actor||!visual||!actor.gameObject.activeInHierarchy)return;
        float t=held?Time.time-began:clock;
        float release=species=="crimson-brute"&&second?contact:second?.23f:.18f;
        float load=held?Ease(t/.62f):1-Ease(t/release);
        float drive=held?0:Ease(t/release)*(1-Ease((t-release-.035f)/.42f));
        float recoil=held?0:Mathf.Sin(Mathf.PI*Mathf.Clamp01((t-contact)/.38f));
        if(held)load*=.92f+.08f*Mathf.Sin(t*4.1f);
        float lift=0,yaw=0;
        if(species=="crimson-brute"&&second&&!held){
            float jump=Mathf.Clamp01((t-.11f)/(contact-.11f));
            lift=.33f*Mathf.Pow(Mathf.Max(0,Mathf.Sin(jump*Mathf.PI)),1.1f);
        }
        if(species=="veil-oracle")yaw=second?-18*load+32*drive:-9*load+15*drive;
        if(species=="moonfang"&&second)yaw=-12*load+29*drive;
        rootPosition=visual.localPosition;rootRotation=visual.localRotation;rootApplied=true;
        visual.position+=Vector3.up*lift;
        visual.rotation=Quaternion.AngleAxis(yaw,Vector3.up)*visual.rotation;
        CurrentLift=lift;
        foreach(var j in joints.Values){if(!j.bone)continue;j.rotation=j.bone.localRotation;j.position=j.bone.localPosition;j.applied=true;}
        if(species=="copperback"){
            Turn("Pelvis",second?-3*load+4*drive:3*load-3*drive);
            Turn("Chest",second?-5*load+11*drive:5*load-12*drive,second?-7*load+9*drive:0);
            Turn("Head",second?5*load-10*drive:-3*load+8*drive);
            Shift("Chest",Vector3.up*(second?.07f*load:.035f*load));
            for(int n=0;n<2;n++){string side=n==0?"L":"R";float sign=n==0?1:-1;
                Turn("Armor."+side,0,0,sign*(second?8*load-5*drive:2*load+5*drive));
                Turn("UpperArm."+side,-6*load+10*drive);Turn("Forearm."+side,8*load-7*drive);
                if(second)Shift("Hand."+side,Vector3.up*(n==0?.11f:.065f)*load);
            }
        }else if(species=="crimson-brute"){
            Turn("Pelvis",-3*load+6*drive,second?0:12*load-14*drive);
            Turn("Chest",second?-12*load+17*drive:-5*load+10*drive,second?0:-22*load+27*drive);
            Turn("Head",7*load-9*drive);
            if(second){
                foreach(string side in new[]{"L","R"}){Turn("UpperArm."+side,-12*load+17*drive);Turn("Forearm."+side,-8*load+12*drive);Turn("Thigh."+side,-16*load+8*drive);Turn("Shin."+side,20*load-10*drive);}
                Shift("Pelvis",Vector3.down*(.07f*load+.03f*recoil));
            }else{
                Turn("UpperArm.R",9*load-21*drive,0,-5*drive);Turn("Forearm.R",-14*load+17*drive);Turn("Hand.R",-8*drive);
                Turn("UpperArm.L",-13*load+9*drive);Turn("Forearm.L",-9*load);Turn("Foot.L",0,-9*load+10*drive);
            }
        }else if(species=="veil-oracle"){
            Turn("Pelvis",0,8*load-11*drive);Turn("Chest",-6*load+5*drive,second?-10*load+17*drive:7*load-12*drive);
            Turn("Head",-4*load,7*load-9*drive);
            Turn("UpperArm.R",-15*load+18*drive,second?12*drive:-18*drive);Turn("Forearm.R",-9*load+14*drive);Turn("Hand.R",-12*drive,10*drive);
            Turn("UpperArm.L",second?-13*load+17*drive:-8*load,second?-21*drive:7*drive);Turn("Forearm.L",second?12*drive:0);
            Turn("Cloth.L",0,6*load-16*drive,4*recoil);Turn("Cloth.R",0,-5*load+11*drive,-7*recoil);
        }else if(species=="golden-throat"){
            Turn("Pelvis",-5*load+8*drive);Shift("Pelvis",Vector3.down*(second?.09f:.045f)*load);
            Turn("Chest",-10*load+(second?17:13)*drive);Turn("Head",-7*load+12*drive);Turn("Throat",6*load-8*drive);
            foreach(string side in new[]{"L","R"}){float sign=side=="L"?1:-1;
                Turn("UpperArm."+side,-5*load+8*drive,sign*(second?16*load-23*drive:7*load));
                Turn("Forearm."+side,-9*load+12*drive);Turn("Thigh."+side,-9*load+5*drive);Turn("Shin."+side,11*load-6*drive);
            }
        }else{
            Turn("Pelvis",3*load-4*drive,second?8*load-10*drive:0);
            Turn("Chest",second?-4*load+5*drive:9*load-12*drive,second?-12*load+17*drive:0);
            Turn("Head",second?5*load-8*drive:5*load-14*drive,second?12*load-15*drive:0);
            Turn("TailBase",0,second?24*load-36*drive:6*load);Turn("Tail1",0,second?17*load-29*drive:5*drive);
            Turn("TailTip",0,second?11*load-24*drive:8*drive);Turn("Ear.L",0,0,5*load-4*drive);Turn("Ear.R",0,0,-4*load+7*drive);
            foreach(string side in new[]{"L","R"}){Turn("UpperArm."+side,-7*load+9*drive);Turn("Forearm."+side,7*load-10*drive);}
        }
    }
    void Turn(string name,float pitch,float yaw=0,float roll=0)
    {
        if(!joints.TryGetValue(name,out var j)||!j.bone||!j.bone.parent)return;
        var p=j.bone.parent;
        j.bone.localRotation=Quaternion.AngleAxis(yaw,p.InverseTransformDirection(Vector3.up))*Quaternion.AngleAxis(pitch,p.InverseTransformDirection(right))*Quaternion.AngleAxis(roll,p.InverseTransformDirection(forward))*j.rotation;
    }
    void Shift(string name,Vector3 worldDelta){if(joints.TryGetValue(name,out var j)&&j.bone&&j.bone.parent)j.bone.localPosition=j.position+j.bone.parent.InverseTransformVector(worldDelta);}
    public void Restore()
    {
        foreach(var j in joints.Values)if(j.applied){if(j.bone){j.bone.localRotation=j.rotation;j.bone.localPosition=j.position;}j.applied=false;}
        if(rootApplied&&visual){visual.localPosition=rootPosition;visual.localRotation=rootRotation;}rootApplied=false;CurrentLift=0;
    }
    void OnDisable(){Restore();}void OnDestroy(){Restore();}
}
