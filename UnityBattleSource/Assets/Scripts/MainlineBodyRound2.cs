using System.Collections.Generic;
using UnityEngine;

// Bone-only presentation layer. The caller supplies its existing release/contact
// clock; this component never moves the actor root or advances a combat action.
[DefaultExecutionOrder(20000)]
public sealed class MainlineBodyRound2 : MonoBehaviour
{
    public enum Pose { Executor, Scribe, Bearer, Hammer, Convoy, Chronarch, Hound, Archivist, Silk, Emerald, Ghost, Guard, EarlyHound, Leech, GuardBrace, ScribeFortify, ScribeCalibrate, LeechCharge }
    sealed class Bone {
        public Transform t; public Quaternion before, applied; public bool changed;
        public Vector3 beforePosition,appliedPosition;public bool moved;
    }
    readonly Dictionary<string,Bone> bones=new Dictionary<string,Bone>(System.StringComparer.OrdinalIgnoreCase);
    Pose pose; bool alternate, playing; float age, release, contact, end;
    float rightUpper,rightLower,leftUpper,leftLower;
    Vector3 rightGripAxis=Vector3.up,leftGripAxis=Vector3.up;
    float bodyUnit=1;Vector3 weaponHeadLocal;
    public Vector3 WeaponHeadWorld {get{var weapon=Find("Weapon");return weapon?weapon.TransformPoint(weaponHeadLocal):transform.position+Vector3.up*1.8f;}}
    public static MainlineBodyRound2 Get(GameObject actor) {
        var layer=actor.GetComponent<MainlineBodyRound2>();
        return layer?layer:actor.AddComponent<MainlineBodyRound2>();
    }
    public void Begin(Pose value,bool second,float releaseTime,float contactTime,float endTime) {
        Stop();bones.Clear();
        foreach(var t in GetComponentsInChildren<Transform>(true)){
            if(!bones.ContainsKey(t.name))bones.Add(t.name,new Bone{t=t});
            int colon=t.name.LastIndexOf(':');
            if(colon>=0){string shortName=t.name.Substring(colon+1);if(!bones.ContainsKey(shortName))bones.Add(shortName,bones[t.name]);}
        }
        pose=value;alternate=second;release=releaseTime;contact=contactTime;end=endTime;age=0;playing=true;
        rightUpper=Distance("UpperArm.R","Forearm.R");rightLower=Distance("Forearm.R","Hand.R");
        leftUpper=Distance("UpperArm.L","Forearm.L");leftLower=Distance("Forearm.L","Hand.L");
        rightGripAxis=GripAxis("R");leftGripAxis=GripAxis("L");
        if(value==Pose.Hammer||value==Pose.Convoy){
            bodyUnit=Mathf.Clamp(Distance("Pelvis","Head")/.70f,.25f,4f);
            // The approved rigs' Weapon tail is the actual hammer-head centre
            // (rig.py wb), not the Weapon head/grip pivot used by the old VFX.
            var weapon=Find("Weapon");float headLength=(value==Pose.Convoy?.682f:.662f)*bodyUnit;
            if(weapon)weaponHeadLocal=Vector3.up*weapon.InverseTransformVector(weapon.up*headLength).magnitude;
        }
    }
    public void Sample(float elapsed){age=Mathf.Max(0,elapsed);}
    Transform Find(string n){return bones.TryGetValue(n,out var b)?b.t:null;}
    float Distance(string a,string b){var x=Find(a);var y=Find(b);return x&&y?Vector3.Distance(x.position,y.position):0;}
    Vector3 GripAxis(string side){var elbow=Find("Forearm."+side);var hand=Find("Hand."+side);return elbow&&hand?elbow.InverseTransformDirection(hand.position-elbow.position).normalized:Vector3.up;}
    void Undo(){foreach(var b in bones.Values){
        if(b.changed){if(b.t&&Quaternion.Angle(b.t.localRotation,b.applied)<.01f)b.t.localRotation=b.before;b.changed=false;}
        if(b.moved){if(b.t&&(b.t.localPosition-b.appliedPosition).sqrMagnitude<.00000001f)b.t.localPosition=b.beforePosition;b.moved=false;}
    }}
    void Save(Bone b){if(!b.changed){b.before=b.t.localRotation;b.changed=true;}}
    void Turn(string name,Vector3 euler){if(!bones.TryGetValue(name,out var b)||!b.t)return;Save(b);b.t.localRotation*=Quaternion.Euler(euler);b.applied=b.t.localRotation;}
    void Alias(Vector3 euler,params string[] names){foreach(var n in names)if(Find(n)){Turn(n,euler);return;}}
    void WorldTurn(Transform t,Quaternion delta){if(!t||!bones.TryGetValue(t.name,out var b))return;Save(b);t.rotation=delta*t.rotation;b.applied=t.localRotation;}
    void WorldMove(Transform t,Vector3 position){
        if(!t||!bones.TryGetValue(t.name,out var b))return;
        if(!b.moved){b.beforePosition=t.localPosition;b.moved=true;}
        t.position=position;b.appliedPosition=t.localPosition;
    }
    void BraceLeg(string side,Vector3 drop){
        var thigh=Find("Thigh."+side);var knee=Find("Shin."+side);var foot=Find("Foot."+side);
        if(!thigh||!knee||!foot)return;
        float upper=Vector3.Distance(thigh.position,knee.position),lower=Vector3.Distance(knee.position,foot.position);
        Vector3 shinAxis=knee.InverseTransformDirection(foot.position-knee.position).normalized;
        WorldMove(thigh,thigh.position+drop);
        Vector3 axis=foot.position-thigh.position;float distance=axis.magnitude;
        if(distance<.001f||upper<.001f||lower<.001f)return;axis/=distance;
        float reach=Mathf.Clamp(distance,Mathf.Abs(upper-lower)+.001f,upper+lower-.001f);
        Vector3 pole=Vector3.ProjectOnPlane(knee.position-thigh.position,axis).normalized;
        if(pole.sqrMagnitude<.1f)pole=Vector3.Cross(axis,transform.right).normalized;
        float along=(upper*upper-lower*lower+reach*reach)/(2*reach);
        Vector3 bend=thigh.position+axis*along+pole*Mathf.Sqrt(Mathf.Max(0,upper*upper-along*along));
        WorldTurn(thigh,Quaternion.FromToRotation(knee.position-thigh.position,bend-thigh.position));
        WorldTurn(knee,Quaternion.FromToRotation(knee.rotation*shinAxis,foot.position-knee.position));
    }
    void HeavyWeapon(bool convoy,float wind,float strike){
        var weapon=Find("Weapon");var chest=Find("Chest");if(!weapon||!chest)return;
        Vector3 forward=Camera.main?Vector3.ProjectOnPlane(Camera.main.transform.position-transform.position,Vector3.up).normalized:transform.forward;
        Vector3 side=Vector3.Cross(Vector3.up,forward).normalized;
        float weight=Mathf.Clamp01(wind+strike),blend=strike/Mathf.Max(.001f,wind+strike);
        Vector3 lift=chest.position+Vector3.up*(convoy?.11f:.35f)*bodyUnit+forward*.13f*bodyUnit;
        Vector3 press=chest.position-Vector3.up*(convoy?.17f:.28f)*bodyUnit+forward*(convoy?.38f:.27f)*bodyUnit;
        Vector3 raised=(Vector3.up*(convoy?.53f:1f)-side*(convoy?.76f:.10f)-forward*.10f).normalized;
        Vector3 driven=(forward*(convoy?.91f:.68f)-Vector3.up*(convoy?.32f:.74f)+side*(convoy?.20f:0)).normalized;
        Vector3 aim=Vector3.Slerp(raised,driven,blend);
        WorldMove(weapon,Vector3.Lerp(weapon.position,Vector3.Lerp(lift,press,blend),weight));
        WorldTurn(weapon,Quaternion.Slerp(Quaternion.identity,Quaternion.FromToRotation(weapon.up,aim),weight));
        // Both hand bones belong to Weapon. Keep its grip within both arm
        // reaches before solving elbows; do not stretch arms or detach hands.
        for(int pass=0;pass<4;pass++)foreach(var sideName in new[]{"R","L"}){
            var shoulder=Find("UpperArm."+sideName);var hand=Find("Hand."+sideName);if(!shoulder||!hand)continue;
            Vector3 delta=hand.position-shoulder.position;float maximum=(sideName=="R"?rightUpper+rightLower:leftUpper+leftLower)*.98f;
            if(maximum>.001f&&delta.magnitude>maximum)WorldMove(weapon,weapon.position-delta.normalized*(delta.magnitude-maximum));
        }
        SolveArm("R",rightUpper,rightLower);SolveArm("L",leftUpper,leftLower);
    }
    void SolveArm(string side,float upperLength,float lowerLength) {
        var shoulder=Find("UpperArm."+side);var elbow=Find("Forearm."+side);var hand=Find("Hand."+side);
        if(!shoulder||!elbow||!hand||upperLength<.001f||lowerLength<.001f)return;
        Vector3 axis=hand.position-shoulder.position;float distance=axis.magnitude;
        if(distance<.001f)return;axis/=distance;
        float reach=Mathf.Clamp(distance,Mathf.Abs(upperLength-lowerLength)+.001f,upperLength+lowerLength-.001f);
        Vector3 pole=Vector3.ProjectOnPlane(elbow.position-shoulder.position,axis).normalized;
        if(pole.sqrMagnitude<.1f)pole=Vector3.Cross(axis,transform.forward).normalized;
        float along=(upperLength*upperLength-lowerLength*lowerLength+reach*reach)/(2*reach);
        Vector3 bend=shoulder.position+axis*along+pole*Mathf.Sqrt(Mathf.Max(0,upperLength*upperLength-along*along));
        WorldTurn(shoulder,Quaternion.FromToRotation(elbow.position-shoulder.position,bend-shoulder.position));
        // The exported hands are weapon children. Aim the forearm's own local
        // length axis at that real grip, not at a separately animated fake hand.
        Vector3 oldAim=elbow.rotation*(side=="R"?rightGripAxis:leftGripAxis);
        Vector3 grip=hand.position-elbow.position;
        if(grip.sqrMagnitude>.0001f)WorldTurn(elbow,Quaternion.FromToRotation(oldAim,grip));
    }
    void Update(){Undo();}
    void LateUpdate(){
        Undo();if(!playing||age>=end)return;
        float drive=pose==Pose.Hammer||pose==Pose.Convoy?contact-.19f:release;
        float wind=age<drive?Mathf.SmoothStep(0,1,age/Mathf.Max(.01f,release)):1-Mathf.SmoothStep(0,1,(age-drive)/.16f);
        float strike=age<drive?0:Mathf.SmoothStep(0,1,(age-drive)/.17f)*(1-Mathf.SmoothStep(0,1,(age-contact)/Mathf.Max(.2f,end-contact)));
        float settle=age>contact?Mathf.Sin(Mathf.Clamp01((age-contact)/(end-contact))*Mathf.PI):0;
        float s=alternate?-1:1;
        switch(pose){
        case Pose.GuardBrace: case Pose.ScribeFortify: case Pose.ScribeCalibrate:
            float stateProgress=Mathf.Clamp01(age/Mathf.Max(.01f,contact));
            // Keep the authored brace through the state, then release. Using
            // .78 as SmoothStep's output floor had reduced the pose to ~17%.
            float hold=Mathf.SmoothStep(0,1,stateProgress/.34f)*(1-Mathf.SmoothStep(0,1,Mathf.InverseLerp(.78f,1,stateProgress)));
            bool calibrating=pose==Pose.ScribeCalibrate,fortifying=pose==Pose.ScribeFortify;
            Alias(new Vector3((calibrating?3:7)*hold,(calibrating?12:fortifying?-7:4)*hold,0),"Chest","Spine02","Spine2","Spine01","Spine","UpperBody");
            Alias(new Vector3(0,(calibrating?-5:3)*hold,0),"Pelvis","Hips");
            Alias(new Vector3((calibrating?-29:-39)*hold,calibrating?13*hold:0,(calibrating?-19:-12)*hold),"UpperArm.R","RightUpperArm","RightArm");
            Alias(new Vector3(-38*hold,0,calibrating?19*hold:0),"Forearm.R","RightForeArm","RightLowerArm");
            Alias(new Vector3((calibrating?-9:-31)*hold,0,(calibrating?8:25)*hold),"UpperArm.L","LeftUpperArm","LeftArm");
            Alias(new Vector3((calibrating?-11:-32)*hold,0,0),"Forearm.L","LeftForeArm","LeftLowerArm");
            if(calibrating)Alias(new Vector3(8*hold,(-24+Mathf.Sin(stateProgress*5)*31)*hold,-19*hold),"Pen.R","Hand.R");
            Alias(new Vector3((calibrating?8:5)*hold,calibrating?-9*hold:0,0),"Head");break;
        case Pose.Executor:
            Turn("Pelvis",new Vector3(0,-7*s*wind+5*s*strike,0));Turn("Chest",new Vector3(-5*wind+11*strike,24*s*wind-29*s*strike,-4*strike));
            Turn("UpperArm.R",new Vector3(-28*wind+(alternate?-7:30)*strike,12*wind,alternate?22*strike:-8*strike));
            Turn("Forearm.R",new Vector3(-23*wind+31*strike,0,0));Turn("Pen.R",new Vector3(0,-19*wind+32*s*strike,alternate?-35*strike:6*strike));
            Turn("UpperArm.L",new Vector3(-8*wind,0,17*wind-12*strike));Turn("Head",new Vector3(4*wind,-12*s*wind+8*s*strike,0));break;
        case Pose.Scribe:
            Turn("Chest",new Vector3(-7*wind+7*strike,17*s*wind-23*s*strike,0));Turn("Pelvis",new Vector3(0,-5*s*wind,0));
            Turn("UpperArm.R",new Vector3(-22*wind+15*strike,12*wind,-16*wind+26*strike));Turn("Forearm.R",new Vector3(-25*wind+18*strike,0,0));
            Alias(new Vector3(0,32*s*strike,-18*wind),"Pen.R","Hand.R");Turn("UpperArm.L",new Vector3(-12*wind,0,14*wind-5*strike));break;
        case Pose.Bearer:
            Turn("Pelvis",new Vector3(0,-8*s*wind+6*s*strike,0));Turn("Chest",new Vector3(-8*wind+16*strike,21*s*wind-26*s*strike,0));
            Turn("UpperArm.R",new Vector3(-32*wind+26*strike,0,-15*wind+19*strike));Turn("Forearm.R",new Vector3(-38*wind+39*strike,0,0));
            Turn("Hand.R",new Vector3(-14*wind+25*strike,17*strike,0));Turn("UpperArm.L",new Vector3(-9*wind,0,15*wind-21*strike));break;
        case Pose.Hammer: case Pose.Convoy:
            bool convoy=pose==Pose.Convoy;
            Vector3 drop=Vector3.down*(.045f*wind+.075f*strike)*bodyUnit;
            var pelvis=Find("Pelvis");if(pelvis)WorldMove(pelvis,pelvis.position+drop);
            BraceLeg("R",drop);BraceLeg("L",drop);
            Turn("Pelvis",new Vector3(-3*wind+5*strike,convoy?-8*wind+11*strike:0,0));
            Turn("Chest",new Vector3(-12*wind+21*strike,convoy?19*wind-24*strike:5*s*wind,0));
            Turn("Head",new Vector3(7*wind-9*strike,0,0));Turn("Tabard",new Vector3(-12*strike+7*settle,0,4*s*settle));
            HeavyWeapon(convoy,wind,strike);break;
        case Pose.Chronarch:
            Turn("Pelvis",new Vector3(0,-5*s*wind+4*s*strike,0));Turn("Chest",new Vector3(-8*wind+13*strike,(alternate?9:22)*wind-(alternate?5:28)*strike,0));
            Turn("UpperArm.R",new Vector3(-31*wind+34*strike,0,(alternate?-11:19)*wind-14*strike));Turn("Forearm.R",new Vector3(-19*wind+16*strike,0,0));
            Turn("Hand.R",new Vector3(-16*wind+28*strike,(alternate?-25:31)*strike,0));
            Turn("UpperArm.L",new Vector3((alternate?-32:-8)*wind+(alternate?26:0)*strike,0,alternate?18*wind-22*strike:0));
            Turn("Forearm.L",new Vector3(-20*wind+19*strike,0,0));Turn("Coat.R",new Vector3(-8*strike,0,3*settle));Turn("Coat.L",new Vector3(-5*strike,0,-5*settle));break;
        case Pose.Hound:
            Turn("Spine",new Vector3(3*wind-4*strike,0,alternate?4*wind-6*strike:0));Turn("Chest",new Vector3(5*wind-7*strike,0,0));
            Turn("Neck",new Vector3(-12*wind+16*strike,0,alternate?12*wind-18*strike:0));Turn("Head",new Vector3(-5*wind+8*strike,0,0));
            Turn("Jaw",new Vector3(10*wind+8*strike,0,0));Turn("Tail1",new Vector3(0,0,-10*s*wind+15*s*strike));Turn("Tail3",new Vector3(0,0,13*s*settle));break;
        case Pose.Archivist:
            Turn("Chest",new Vector3(-7*wind+10*strike,alternate?-9*wind:14*wind,0));Turn("Cabinet",new Vector3(-3*wind+6*strike,0,0));
            Turn("UpperArm.L",new Vector3(-27*wind+25*strike,0,alternate?23*wind:0));
            // Forearm.L is the real detachable projectile: never animate it here.
            Turn("UpperArm.R",new Vector3((alternate?-29:-8)*wind+11*strike,0,alternate?-20*wind:0));Turn("Head",new Vector3(4*wind-4*strike,0,0));break;
        case Pose.Silk:
            Turn("Hips",new Vector3(0,-5*s*wind+4*s*strike,0));Turn("Chest",new Vector3(-8*wind+9*strike,22*s*wind-27*s*strike,0));
            Turn("UpperArm.R",new Vector3((alternate?-42:-21)*wind+25*strike,0,-19*wind+31*strike));Turn("Forearm.R",new Vector3(-17*wind,13*wind-24*strike,11*strike));
            Turn("UpperArm.L",new Vector3((alternate?-34:-12)*wind+12*strike,0,28*wind-35*strike));Turn("Forearm.L",new Vector3(-21*wind+19*strike,-17*wind,0));
            Turn("Hand.R",new Vector3(0,24*strike,-19*wind+28*strike));Turn("Hand.L",new Vector3(0,-22*strike,14*wind-26*strike));
            Turn("Sleeve.R",new Vector3(-10*strike+7*settle,0,9*settle));Turn("Sleeve.L",new Vector3(-6*strike,0,-12*settle));break;
        case Pose.Emerald:
            Turn("Spine",new Vector3(-6*wind+9*strike,0,0));Turn("Chest",new Vector3(-9*wind+12*strike,13*wind-23*strike,0));
            Turn("RightUpperArm",new Vector3(-23*wind+30*strike,10*wind,-12*wind));Turn("RightForeArm",new Vector3(-28*wind+24*strike,0,0));
            Turn("LeftUpperArm",new Vector3(-17*wind+13*strike,-9*wind,14*wind));Turn("LeftForeArm",new Vector3(-13*wind,0,8*strike));
            Turn("CoatL",new Vector3(-8*strike,0,8*settle));Turn("CoatR",new Vector3(-5*strike,0,-10*settle));break;
        case Pose.Ghost:
            Turn("LeftArm",new Vector3(-10*wind+14*strike,alternate?22*wind:0,alternate?34*wind-38*strike:12*wind));
            Turn("RightArm",new Vector3(-18*wind+21*strike,0,alternate?-9*wind:-27*wind+32*strike));break;
        case Pose.EarlyHound:
            // Only the neck/muzzle layer: the continuous four-leg gait is untouched.
            Alias(new Vector3(-5*wind+7*strike,0,0),"Neck","Head");Alias(new Vector3(7*wind+6*strike,0,0),"Jaw","Mouth");break;
        case Pose.Leech:
            // Seven independent controls: front coils first and rear segments
            // take up the slack, rather than rotating the entire wet creature.
            for(int i=0;i<7;i++){
                float front=1-i/7f;
                Turn("segment_"+i.ToString("00"),new Vector3((-15*wind+22*strike)*front,Mathf.Sin(i*.8f)*wind*7,(-7*wind+9*strike)*front));
            }
            break;
        case Pose.LeechCharge:
            for(int i=0;i<7;i++){
                float gather=Mathf.SmoothStep(0,1,Mathf.Clamp01((age-i*.075f)/.75f));
                float pulse=Mathf.Sin(age*3.6f-i*.70f)*gather;
                Turn("segment_"+i.ToString("00"),new Vector3((-12*(1-i/8f)+pulse*3)*gather,Mathf.Sin(i*.8f)*4*gather,(-5+2*pulse)*(1-i/8f)*gather));
            }
            break;
        case Pose.Guard:
            Alias(new Vector3(-6*wind+8*strike,12*s*wind-16*s*strike,0),"Chest","Spine2","Spine","UpperBody");
            Alias(new Vector3(-19*wind+25*strike,0,-12*wind),"UpperArm.R","RightUpperArm","RightArm");Alias(new Vector3(-16*wind+20*strike,0,0),"Forearm.R","RightForeArm","RightLowerArm");
            Alias(new Vector3(-7*wind,0,14*wind-10*strike),"UpperArm.L","LeftUpperArm","LeftArm");break;
        }
    }
    public void Stop(){Undo();playing=false;}
    void OnDisable(){Stop();}
    void OnDestroy(){Stop();}
}
