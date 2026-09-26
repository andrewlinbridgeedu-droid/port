using UnityEngine;
using System.Collections.Generic;

// Actor-space alert stance. Feet retain the animation's exact world targets; the
// chest and two hands act independently rather than rocking the entire character.
[DefaultExecutionOrder(800)]
public sealed class HeroLivingIdle20260916 : MonoBehaviour {
    public static bool PolishEnabled=true;
    sealed class Joint { public Transform bone; public Quaternion rotation; public Vector3 position; }
    readonly Dictionary<HumanBodyBones,Joint> joints=new Dictionary<HumanBodyBones,Joint>();
    Animator animator; FoolSkillChoreography choreography; bool applied; float idleSince=-1;
    public float LastFootError {get;private set;}
    public int LastFingerChainCount {get;private set;}
    public int MappedFingerChainCount => fingers.Count;
    public float LastGazePitchBefore {get;private set;}
    public float LastGazePitchAfter {get;private set;}
    Transform faceDirectionMarker;
    public float LastFingerAddedAngle {get;private set;}
    sealed class Finger { public Transform first,second,third; public float curl; }
    readonly List<Finger> fingers=new List<Finger>();
    public static void Install(GameObject actor){if(actor&&!actor.GetComponent<HeroLivingIdle20260916>())actor.AddComponent<HeroLivingIdle20260916>();}
    void Awake(){
        animator=GetComponentInChildren<Animator>();choreography=GetComponent<FoolSkillChoreography>();
        if(!animator||!animator.isHuman)return;
        foreach(var candidate in animator.GetComponentsInChildren<Transform>(true))
            if(candidate.name=="headfront"||candidate.name.EndsWith(":headfront")){faceDirectionMarker=candidate;break;}
        foreach(var id in new[]{HumanBodyBones.Hips,HumanBodyBones.Spine,HumanBodyBones.Chest,HumanBodyBones.Neck,HumanBodyBones.Head,
            HumanBodyBones.LeftShoulder,HumanBodyBones.RightShoulder,HumanBodyBones.LeftUpperArm,HumanBodyBones.RightUpperArm,
            HumanBodyBones.LeftLowerArm,HumanBodyBones.RightLowerArm,HumanBodyBones.LeftHand,HumanBodyBones.RightHand,
            HumanBodyBones.LeftUpperLeg,HumanBodyBones.RightUpperLeg,HumanBodyBones.LeftLowerLeg,HumanBodyBones.RightLowerLeg,
            HumanBodyBones.LeftFoot,HumanBodyBones.RightFoot}){
            var bone=animator.GetBoneTransform(id);if(bone)joints[id]=new Joint{bone=bone};
        }
    }
    void MapFinger(HumanBodyBones first,HumanBodyBones second,HumanBodyBones third,float curl){
        foreach(var id in new[]{first,second,third})if(!joints.ContainsKey(id)){
            var bone=animator.GetBoneTransform(id);if(bone)joints[id]=new Joint{bone=bone};
        }
        var a=Bone(first);var b=Bone(second);var c=Bone(third);
        if(a&&b&&c)fingers.Add(new Finger{first=a,second=b,third=c,curl=curl});
    }
    void Start(){
        if(!animator||!animator.isHuman)return;
        MapFinger(HumanBodyBones.LeftIndexProximal,HumanBodyBones.LeftIndexIntermediate,HumanBodyBones.LeftIndexDistal,2.5f);
        MapFinger(HumanBodyBones.LeftMiddleProximal,HumanBodyBones.LeftMiddleIntermediate,HumanBodyBones.LeftMiddleDistal,3.5f);
        MapFinger(HumanBodyBones.LeftRingProximal,HumanBodyBones.LeftRingIntermediate,HumanBodyBones.LeftRingDistal,4.5f);
        MapFinger(HumanBodyBones.LeftLittleProximal,HumanBodyBones.LeftLittleIntermediate,HumanBodyBones.LeftLittleDistal,5f);
        MapFinger(HumanBodyBones.RightIndexProximal,HumanBodyBones.RightIndexIntermediate,HumanBodyBones.RightIndexDistal,1.5f);
        MapFinger(HumanBodyBones.RightMiddleProximal,HumanBodyBones.RightMiddleIntermediate,HumanBodyBones.RightMiddleDistal,2.5f);
        MapFinger(HumanBodyBones.RightRingProximal,HumanBodyBones.RightRingIntermediate,HumanBodyBones.RightRingDistal,3.5f);
        MapFinger(HumanBodyBones.RightLittleProximal,HumanBodyBones.RightLittleIntermediate,HumanBodyBones.RightLittleDistal,4f);
    }
    Transform Bone(HumanBodyBones id){return joints.TryGetValue(id,out var j)?j.bone:null;}
    void Save(){foreach(var j in joints.Values){j.rotation=j.bone.localRotation;j.position=j.bone.localPosition;}applied=true;}
    void Restore(){if(!applied)return;foreach(var j in joints.Values)if(j.bone){j.bone.localRotation=j.rotation;j.bone.localPosition=j.position;}applied=false;}
    void Update(){Restore();}
    // Turn, observe, return, then genuinely rest: no perpetual sinusoidal head shake.
    static float Gesture(float t,float start,float turn,float hold,float back){
        t-=start;if(t<0)return 0;if(t<turn)return Mathf.SmoothStep(0,1,t/turn);
        t-=turn;if(t<hold)return 1;t-=hold;return 1-Mathf.SmoothStep(0,1,t/back);
    }
    void Turn(HumanBodyBones id,Vector3 degrees,float weight){
        var b=Bone(id);if(!b)return;
        var q=transform.rotation*Quaternion.Euler(degrees*weight)*Quaternion.Inverse(transform.rotation);
        b.rotation=q*b.rotation;
    }
    void LateUpdate(){
        if(!PolishEnabled||!animator||!animator.runtimeAnimatorController||animator.IsInTransition(0)){idleSince=-1;return;}
        if(!choreography)choreography=GetComponent<FoolSkillChoreography>();
        var state=animator.GetCurrentAnimatorStateInfo(0);
        if((choreography&&choreography.IsPlaying)||(!state.IsName("Meshy · Idle")&&!state.IsName("Idle"))){idleSince=-1;return;}
        if(idleSince<0)idleSince=Time.time;
        float age=Time.time-idleSince,weight=Mathf.SmoothStep(0,1,age/.55f),t=Time.time;
        float breath=Mathf.Sin(t*1.22f),phase=age%17f;
        float glance=Gesture(phase,3.3f,.75f,1.1f,1.2f)-.65f*Gesture(phase,11.2f,.9f,.75f,1.15f);
        float settle=Gesture(phase,7f,1.6f,2f,1.8f);
        Save();
        var lf=Bone(HumanBodyBones.LeftFoot);var rf=Bone(HumanBodyBones.RightFoot);
        var hips=Bone(HumanBodyBones.Hips);
        Vector3 lp=lf?lf.position:Vector3.zero,rp=rf?rf.position:Vector3.zero;
        Quaternion lr=lf?lf.rotation:Quaternion.identity,rr=rf?rf.rotation:Quaternion.identity;
        // Lift the compressed pelvis modestly and settle onto one leg. Two-bone
        // solves below pin both feet, including their original world orientations.
        if(hips&&lf&&rf){
            float leg=Vector3.Distance(hips.position,(lp+rp)*.5f);
            hips.position+=transform.up*(leg*.023f*weight)+transform.right*(leg*.009f*settle*weight);
            SolveLimb(HumanBodyBones.LeftUpperLeg,HumanBodyBones.LeftLowerLeg,HumanBodyBones.LeftFoot,lp,transform.forward,1);
            SolveLimb(HumanBodyBones.RightUpperLeg,HumanBodyBones.RightLowerLeg,HumanBodyBones.RightFoot,rp,transform.forward,1);
            lf.rotation=lr;rf.rotation=rr;
            LastFootError=Mathf.Max(Vector3.Distance(lf.position,lp),Vector3.Distance(rf.position,rp));
        }
        Turn(HumanBodyBones.Spine,new Vector3(-1.5f,-1.5f*settle,.5f*settle),weight);
        Turn(HumanBodyBones.Chest,new Vector3(.8f*breath,1.8f*glance,-.55f*settle),weight);
        Turn(HumanBodyBones.Neck,new Vector3(-.25f*breath,2.1f*glance,0),weight);
        Turn(HumanBodyBones.Head,new Vector3(0,3.2f*glance,.4f*glance),weight);
        FocusForward(weight);
        RelaxArm(true,breath,settle,weight);
        RelaxArm(false,breath,settle,weight);
        RelaxFingers(settle,weight);
    }
    void RelaxArm(bool left,float breath,float settle,float weight){
        var upper=left?HumanBodyBones.LeftUpperArm:HumanBodyBones.RightUpperArm;
        var lower=left?HumanBodyBones.LeftLowerArm:HumanBodyBones.RightLowerArm;
        var hand=left?HumanBodyBones.LeftHand:HumanBodyBones.RightHand;
        var a=Bone(upper);var b=Bone(lower);var h=Bone(hand);if(!a||!b||!h)return;
        float length=Vector3.Distance(a.position,b.position)+Vector3.Distance(b.position,h.position),side=left?-1:1;
        // Off hand hangs lower; casting hand remains ready, with an open elbow.
        // All targets scale with the actual rig, independent of FBX roll axes.
        Vector3 target=a.position+transform.up*(length*(left?-.60f:-.45f)+length*.008f*breath)
            +transform.forward*(length*(left?.39f:.49f))
            +transform.right*(side*length*(.11f+.013f*settle));
        Quaternion wrist=h.rotation;
        SolveLimb(upper,lower,hand,target,-transform.up+transform.right*(side*.12f)-transform.forward*.15f,weight*.94f);
        // Keep the animated palm orientation; the elbow solve must not twist fingers.
        h.rotation=wrist;
        Turn(hand,new Vector3(.8f*breath,side*1.3f*settle,side*.8f*breath),weight);
    }
    void FocusForward(float weight){
        var head=Bone(HumanBodyBones.Head);if(!head||!faceDirectionMarker)return;
        Vector3 gaze=(faceDirectionMarker.position-head.position).normalized;
        Vector3 level=Vector3.ProjectOnPlane(gaze,transform.up).normalized;
        if(level.sqrMagnitude<.5f)return;
        LastGazePitchBefore=Mathf.Asin(Mathf.Clamp(Vector3.Dot(gaze,transform.up),-1f,1f))*Mathf.Rad2Deg;
        // Direct the anatomical face ray toward the opponent, with a slight alert chin tuck.
        // Share a large correction between neck and head rather than bending one joint sharply.
        if(LastGazePitchBefore< -4f){
            Vector3 axis=Vector3.Cross(gaze,level).normalized;
            float correction=Mathf.Min(24f,-4f-LastGazePitchBefore)*weight;
            var neck=Bone(HumanBodyBones.Neck);
            if(neck)neck.rotation=Quaternion.AngleAxis(correction*.28f,axis)*neck.rotation;
            head.rotation=Quaternion.AngleAxis(correction*(neck ? .72f : 1f),axis)*head.rotation;
        }
        gaze=(faceDirectionMarker.position-head.position).normalized;
        LastGazePitchAfter=Mathf.Asin(Mathf.Clamp(Vector3.Dot(gaze,transform.up),-1f,1f))*Mathf.Rad2Deg;
    }
    void RelaxFingers(float settle,float weight){
        LastFingerChainCount=0;LastFingerAddedAngle=0;
        foreach(var finger in fingers){
            Vector3 proximal=finger.second.position-finger.first.position;
            Vector3 middle=finger.third.position-finger.second.position;
            if(proximal.sqrMagnitude<1e-10f||middle.sqrMagnitude<1e-10f)continue;
            float existing=Vector3.Angle(proximal,middle);
            // Derive the flexion plane from the actual animated phalanges. Import
            // bone-roll and mirrored hand axes cannot reverse this direction.
            // Straight chains have no trustworthy bend plane: leave them alone.
            if(existing<2f||existing>65f)continue;
            Vector3 axis=Vector3.Cross(proximal,middle).normalized;
            float degrees=finger.curl*(1f-.20f*settle)*weight;
            finger.first.rotation=Quaternion.AngleAxis(degrees*.40f,axis)*finger.first.rotation;
            finger.second.rotation=Quaternion.AngleAxis(degrees*.60f,axis)*finger.second.rotation;
            LastFingerChainCount++;
            LastFingerAddedAngle=Mathf.Max(LastFingerAddedAngle,degrees);
        }
    }
    void SolveLimb(HumanBodyBones upper,HumanBodyBones lower,HumanBodyBones end,Vector3 target,Vector3 pole,float weight){
        var a=Bone(upper);var b=Bone(lower);var c=Bone(end);if(!a||!b||!c)return;
        Vector3 origin=a.position;float l1=Vector3.Distance(origin,b.position),l2=Vector3.Distance(b.position,c.position);
        if(l1<.0001f||l2<.0001f)return;
        Vector3 delta=target-origin;float distance=Mathf.Clamp(delta.magnitude,Mathf.Abs(l1-l2)+.0001f,l1+l2-.0001f);
        Vector3 axis=delta.normalized;target=origin+axis*distance;
        Vector3 bend=Vector3.ProjectOnPlane(b.position-origin,axis);
        // Preserve the animation's knee plane; arm poles deliberately lower elbows.
        bool leg=upper==HumanBodyBones.LeftUpperLeg||upper==HumanBodyBones.RightUpperLeg;
        if(!leg||bend.sqrMagnitude<.000001f)bend=Vector3.ProjectOnPlane(pole,axis);
        if(bend.sqrMagnitude<.000001f)return;bend.Normalize();
        float along=(l1*l1-l2*l2+distance*distance)/(2*distance);
        Vector3 elbow=origin+axis*along+bend*Mathf.Sqrt(Mathf.Max(0,l1*l1-along*along));
        Quaternion qa=a.localRotation,qb=b.localRotation;
        a.rotation=Quaternion.FromToRotation(b.position-origin,elbow-origin)*a.rotation;
        b.rotation=Quaternion.FromToRotation(c.position-b.position,target-b.position)*b.rotation;
        Quaternion solvedA=a.localRotation,solvedB=b.localRotation;
        a.localRotation=Quaternion.Slerp(qa,solvedA,weight);b.localRotation=Quaternion.Slerp(qb,solvedB,weight);
    }
    void OnDisable(){Restore();idleSince=-1;}void OnDestroy(){Restore();}
}
